import assert from 'node:assert/strict';
import test from 'node:test';
import mongoose from 'mongoose';

import { Message } from '../src/models/message.model.js';
import {
  participantKey,
  serializeMessage,
} from '../src/services/chat.service.js';

test('participantKey is stable regardless of user order', () => {
  const first = new mongoose.Types.ObjectId();
  const second = new mongoose.Types.ObjectId();

  assert.equal(participantKey(first, second), participantKey(second, first));
});

test('message rejects text longer than 2000 characters', () => {
  const message = new Message({
    conversation: new mongoose.Types.ObjectId(),
    sender: new mongoose.Types.ObjectId(),
    recipient: new mongoose.Types.ObjectId(),
    text: 'x'.repeat(2001),
  });

  assert.ok(message.validateSync()?.errors.text);
});

test('serialized messages include read receipt timestamps', () => {
  const readAt = new Date('2026-06-06T10:00:00.000Z');
  const message = {
    _id: new mongoose.Types.ObjectId(),
    conversation: new mongoose.Types.ObjectId(),
    sender: new mongoose.Types.ObjectId(),
    recipient: new mongoose.Types.ObjectId(),
    text: 'hello',
    createdAt: new Date('2026-06-06T09:59:00.000Z'),
    readAt,
  };

  assert.equal(serializeMessage(message).readAt, readAt);
});
