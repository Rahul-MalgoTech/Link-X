import express from 'express';
import mongoose from 'mongoose';

import { requireAuth } from '../middleware/auth.js';
import { Conversation } from '../models/conversation.model.js';
import { Message } from '../models/message.model.js';
import { Match } from '../models/match.model.js';
import { User } from '../models/user.model.js';
import {
  createChatMessage,
  markConversationRead,
  participantKey,
  serializeMessage,
} from '../services/chat.service.js';
import { asyncRoute } from '../utils/async-route.js';
import { assertActiveMatch } from '../services/matching.service.js';
import { createNotification } from '../services/notification.service.js';

const router = express.Router();

router.use(requireAuth);

router.get(
  '/conversations',
  asyncRoute(async (req, res) => {
    const activeMatches = await Match.find({
      users: req.user._id,
      status: 'active',
    })
      .select('users matchedAt')
      .populate('users', 'firstName photos')
      .lean();
    const matchedUsers = new Map();
    for (const match of activeMatches) {
      const otherUser = match.users.find(
        (user) => user._id.toString() !== req.user._id.toString(),
      );
      if (otherUser) {
        matchedUsers.set(otherUser._id.toString(), {
          matchId: match._id.toString(),
          matchedAt: match.matchedAt,
          user: otherUser,
        });
      }
    }
    const conversations = await Conversation.find({
      participants: req.user._id,
    })
      .populate('participants', 'firstName photos')
      .lean();

    const latestMessages = await Message.aggregate([
      {
        $match: {
          conversation: {
            $in: conversations.map((conversation) => conversation._id),
          },
        },
      },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: '$conversation',
          message: { $first: '$$ROOT' },
        },
      },
    ]);
    const latestMessageByConversation = new Map(
      latestMessages.map(({ _id, message }) => [_id.toString(), message]),
    );
    const unreadCounts = await Message.aggregate([
      {
        $match: {
          conversation: {
            $in: conversations.map((conversation) => conversation._id),
          },
          recipient: req.user._id,
          readAt: null,
        },
      },
      { $group: { _id: '$conversation', count: { $sum: 1 } } },
    ]);
    const unreadCountByConversation = new Map(
      unreadCounts.map(({ _id, count }) => [_id.toString(), count]),
    );

    const items = conversations
      .map((conversation) => {
        const otherUser = conversation.participants.find(
          (participant) => participant._id.toString() !== req.user._id.toString(),
        );
        if (!otherUser || !matchedUsers.has(otherUser._id.toString())) {
          return null;
        }
        const latestMessage = latestMessageByConversation.get(
          conversation._id.toString(),
        );

        return {
          id: conversation._id.toString(),
          user: toChatUser(otherUser),
          lastMessage:
            latestMessage?.text || conversation.lastMessageText || '',
          lastMessageAt:
            latestMessage?.createdAt ||
            conversation.lastMessageAt ||
            conversation.updatedAt ||
            null,
          lastMessageSenderId:
            latestMessage?.sender?.toString() ||
            conversation.lastMessageSender?.toString() ||
            null,
          unreadCount:
            unreadCountByConversation.get(conversation._id.toString()) || 0,
        };
      })
      .filter(Boolean);

    const conversationUserIds = new Set(
      items.map((item) => item.user.id),
    );
    for (const [userId, match] of matchedUsers) {
      if (conversationUserIds.has(userId)) continue;
      items.push({
        id: `match:${match.matchId}`,
        user: toChatUser(match.user),
        lastMessage: 'Start a conversation',
        lastMessageAt: match.matchedAt,
        lastMessageSenderId: null,
        unreadCount: 0,
      });
    }

    items.sort(
        (first, second) =>
          new Date(second.lastMessageAt || 0) -
          new Date(first.lastMessageAt || 0),
      );

    res.json({ conversations: items });
  }),
);

router.get(
  '/messages/:userId',
  asyncRoute(async (req, res) => {
    const { userId } = req.params;
    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({ message: 'Invalid user ID' });
    }

    await assertActiveMatch(req.user._id, userId);
    const otherUser = await User.findById(userId).select('firstName photos').lean();
    if (!otherUser) return res.status(404).json({ message: 'User not found' });
    const limit = parseMessageLimit(req.query.limit);
    const before = req.query.before?.toString();
    if (before && !mongoose.isValidObjectId(before)) {
      return res.status(400).json({ message: 'Invalid message cursor' });
    }

    const conversation = await Conversation.findOne({
      participantKey: participantKey(req.user._id, userId),
    });
    if (!conversation) {
      return res.json({
        user: toChatUser(otherUser),
        messages: [],
        pagination: { limit, hasMore: false, nextCursor: null },
      });
    }

    const query = { conversation: conversation._id };
    if (before) query._id = { $lt: before };
    const messages = await Message.find(query)
      .sort({ _id: -1 })
      .limit(limit + 1)
      .lean();
    const hasMore = messages.length > limit;
    if (hasMore) messages.pop();
    messages.reverse();

    const receipt = await markConversationRead({
      readerId: req.user._id,
      otherUserId: userId,
    });
    if (receipt?.updatedCount) {
      for (const message of messages) {
        if (
          message.recipient.toString() === req.user._id.toString() &&
          !message.readAt
        ) {
          message.readAt = receipt.readAt;
        }
      }
      emitReadReceipt(req.app.get('io'), receipt);
    }

    res.json({
      user: toChatUser(otherUser),
      messages: messages.map(serializeMessage),
      pagination: {
        limit,
        hasMore,
        nextCursor: hasMore ? messages[0]?._id.toString() || null : null,
      },
    });
  }),
);

router.post(
  '/messages/:userId/read',
  asyncRoute(async (req, res) => {
    const receipt = await markConversationRead({
      readerId: req.user._id,
      otherUserId: req.params.userId,
    });
    if (receipt?.updatedCount) emitReadReceipt(req.app.get('io'), receipt);
    res.json({ receipt });
  }),
);

router.post(
  '/messages',
  asyncRoute(async (req, res) => {
    const message = await createChatMessage({
      senderId: req.user._id,
      recipientId: req.body.recipientId,
      text: req.body.text,
    });
    req.app.get('io')?.to(`user:${req.body.recipientId}`).emit('chat:message', message);
    req.app.get('io')?.to(`user:${req.user._id}`).emit('chat:message', message);
    await createNotification({
      io: req.app.get('io'),
      userId: req.body.recipientId,
      type: 'message',
      title: req.user.firstName || 'New message',
      body: message.text,
      data: {
        senderId: req.user._id.toString(),
        conversationId: message.conversationId,
      },
    });
    res.status(201).json({ message });
  }),
);

function toChatUser(user) {
  return {
    id: user._id.toString(),
    name: user.firstName || 'Linkx User',
    imageUrl: user.photos?.[0]?.url || '',
  };
}

function parseMessageLimit(value) {
  const parsed = Number.parseInt(value?.toString() || '200', 10);
  if (!Number.isFinite(parsed)) return 200;
  return Math.min(Math.max(parsed, 1), 200);
}

function emitReadReceipt(io, receipt) {
  io?.to(`user:${receipt.readerId}`)
    .to(`user:${receipt.otherUserId}`)
    .emit('chat:read', receipt);
}

export default router;
