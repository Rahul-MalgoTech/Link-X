import jwt from 'jsonwebtoken';

import { Match } from '../models/match.model.js';
import { Room } from '../models/room.model.js';
import { User } from '../models/user.model.js';
import {
  createChatMessage,
  markConversationRead,
} from '../services/chat.service.js';
import { assertActiveMatch } from '../services/matching.service.js';
import { createNotification } from '../services/notification.service.js';

export function registerChatSocket(io) {
  const connectionCounts = new Map();

  io.use(async (socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        bearerToken(socket.handshake.headers.authorization);
      if (!token) throw new Error('Missing authentication token');

      const payload = jwt.verify(
        token,
        process.env.JWT_SECRET || 'dev-secret',
      );
      const user = await User.findById(payload.sub).select('_id');
      if (!user) throw new Error('User not found');

      socket.userId = user._id.toString();
      next();
    } catch (error) {
      next(new Error(error.message || 'Authentication failed'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);
    const previousCount = connectionCounts.get(socket.userId) || 0;
    connectionCounts.set(socket.userId, previousCount + 1);
    sendPresenceSnapshot(socket, connectionCounts);
    if (previousCount === 0) {
      broadcastPresence(io, socket.userId, true);
    }

    socket.on('chat:send', async (payload, acknowledge) => {
      try {
        const message = await createChatMessage({
          senderId: socket.userId,
          recipientId: payload?.recipientId,
          text: payload?.text,
        });

        io.to(`user:${message.senderId}`)
          .to(`user:${message.recipientId}`)
          .emit('chat:message', message);
        const sender = await User.findById(socket.userId).select('firstName');
        await createNotification({
          io,
          userId: message.recipientId,
          type: 'message',
          title: sender?.firstName || 'New message',
          body: message.text,
          data: {
            senderId: message.senderId,
            conversationId: message.conversationId,
          },
        });
        acknowledge?.({ ok: true, message });
      } catch (error) {
        acknowledge?.({
          ok: false,
          message: error.message || 'Unable to send message',
        });
      }
    });

    socket.on('chat:read', async (payload, acknowledge) => {
      try {
        const receipt = await markConversationRead({
          readerId: socket.userId,
          otherUserId: payload?.userId,
        });
        if (receipt?.updatedCount) {
          io.to(`user:${receipt.readerId}`)
            .to(`user:${receipt.otherUserId}`)
            .emit('chat:read', receipt);
        }
        acknowledge?.({ ok: true, receipt });
      } catch (error) {
        acknowledge?.({
          ok: false,
          message: error.message || 'Unable to mark messages as read',
        });
      }
    });

    socket.on('chat:typing', async (payload, acknowledge) => {
      try {
        const recipientId = payload?.recipientId;
        await assertActiveMatch(socket.userId, recipientId);
        io.to(`user:${recipientId}`).emit('chat:typing', {
          userId: socket.userId,
          isTyping: payload?.isTyping === true,
        });
        acknowledge?.({ ok: true });
      } catch (error) {
        acknowledge?.({
          ok: false,
          message: error.message || 'Unable to update typing status',
        });
      }
    });

    socket.on('chat:presence:request', () => {
      sendPresenceSnapshot(socket, connectionCounts);
    });

    socket.on('room:subscribe', async (payload, acknowledge) => {
      try {
        const room = await Room.findOne({
          _id: payload?.roomId,
          status: 'live',
        }).select('privacy members.user');
        if (!room) throw new Error('Room not found');
        const isMember = room.members.some(
          (member) => member.user.toString() === socket.userId,
        );
        if (room.privacy === 'private' && !isMember) {
          throw new Error('Private room access denied');
        }
        socket.join(`room:${room._id}`);
        acknowledge?.({ ok: true });
      } catch (error) {
        acknowledge?.({ ok: false, message: error.message });
      }
    });

    socket.on('room:unsubscribe', (payload) => {
      if (payload?.roomId) socket.leave(`room:${payload.roomId}`);
    });

    socket.on('disconnect', () => {
      const nextCount = Math.max(
        (connectionCounts.get(socket.userId) || 1) - 1,
        0,
      );
      if (nextCount === 0) {
        connectionCounts.delete(socket.userId);
        broadcastPresence(io, socket.userId, false);
      } else {
        connectionCounts.set(socket.userId, nextCount);
      }
    });
  });
}

async function matchedUserIds(userId) {
  const matches = await Match.find({ users: userId, status: 'active' })
    .select('users')
    .lean();
  return matches.flatMap((match) =>
    match.users
      .map((id) => id.toString())
      .filter((id) => id !== userId.toString()),
  );
}

async function sendPresenceSnapshot(socket, connectionCounts) {
  try {
    const userIds = await matchedUserIds(socket.userId);
    const visibleUsers = await User.find({
      _id: { $in: userIds },
      'privacySettings.showOnlineStatus': { $ne: false },
    })
      .select('_id')
      .lean();
    const visibleUserIds = new Set(
      visibleUsers.map((user) => user._id.toString()),
    );
    socket.emit('chat:presence:snapshot', {
      onlineUserIds: userIds.filter(
        (userId) =>
          visibleUserIds.has(userId) &&
          (connectionCounts.get(userId) || 0) > 0,
      ),
    });
  } catch {
    // Presence is best-effort and must not interrupt an authenticated socket.
  }
}

async function broadcastPresence(io, userId, isOnline) {
  try {
    const user = await User.findById(userId)
      .select('privacySettings.showOnlineStatus')
      .lean();
    if (user?.privacySettings?.showOnlineStatus === false) return;
    const userIds = await matchedUserIds(userId);
    for (const matchedUserId of userIds) {
      io.to(`user:${matchedUserId}`).emit('chat:presence', {
        userId,
        isOnline,
      });
    }
  } catch {
    // Presence is best-effort and must not interrupt chat delivery.
  }
}

function bearerToken(header = '') {
  return header.startsWith('Bearer ') ? header.slice(7) : null;
}
