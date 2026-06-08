import mongoose from 'mongoose';

import { Conversation } from '../models/conversation.model.js';
import { Message } from '../models/message.model.js';
import { User } from '../models/user.model.js';
import { assertActiveMatch } from './matching.service.js';

export function participantKey(firstUserId, secondUserId) {
  return [firstUserId.toString(), secondUserId.toString()].sort().join(':');
}

export async function createChatMessage({ senderId, recipientId, text }) {
  const cleanText = typeof text === 'string' ? text.trim() : '';
  if (!cleanText) throw chatError('Message cannot be empty', 400);
  if (cleanText.length > 2000) {
    throw chatError('Message cannot exceed 2000 characters', 400);
  }
  if (!mongoose.isValidObjectId(recipientId)) {
    throw chatError('Invalid recipient', 400);
  }
  if (senderId.toString() === recipientId.toString()) {
    throw chatError('You cannot message yourself', 400);
  }

  await assertActiveMatch(senderId, recipientId);
  const recipient = await User.findById(recipientId).select('_id');
  if (!recipient) throw chatError('Recipient not found', 404);

  const key = participantKey(senderId, recipientId);
  const conversation = await Conversation.findOneAndUpdate(
    { participantKey: key },
    {
      $setOnInsert: {
        participants: [senderId, recipientId],
        participantKey: key,
      },
    },
    { new: true, upsert: true },
  );

  const message = await Message.create({
    conversation: conversation._id,
    sender: senderId,
    recipient: recipientId,
    text: cleanText,
  });

  await Conversation.updateOne(
    {
      _id: conversation._id,
      $or: [
        { lastMessageAt: { $exists: false } },
        { lastMessageAt: null },
        { lastMessageAt: { $lte: message.createdAt } },
      ],
    },
    {
      $set: {
        lastMessageText: message.text,
        lastMessageAt: message.createdAt,
        lastMessageSender: message.sender,
      },
    },
  );

  return serializeMessage(message);
}

export async function markConversationRead({ readerId, otherUserId }) {
  await assertActiveMatch(readerId, otherUserId);
  const conversation = await Conversation.findOne({
    participantKey: participantKey(readerId, otherUserId),
  }).select('_id');
  if (!conversation) return null;

  const readAt = new Date();
  const result = await Message.updateMany(
    {
      conversation: conversation._id,
      recipient: readerId,
      readAt: null,
    },
    { $set: { readAt } },
  );

  return {
    conversationId: conversation._id.toString(),
    readerId: readerId.toString(),
    otherUserId: otherUserId.toString(),
    readAt,
    updatedCount: result.modifiedCount,
  };
}

export function serializeMessage(message) {
  return {
    id: message._id.toString(),
    conversationId: message.conversation.toString(),
    senderId: message.sender.toString(),
    recipientId: message.recipient.toString(),
    text: message.text,
    createdAt: message.createdAt,
    readAt: message.readAt || null,
  };
}

function chatError(message, status) {
  const error = new Error(message);
  error.status = status;
  return error;
}
