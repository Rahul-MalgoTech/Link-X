import assert from 'node:assert/strict';
import test from 'node:test';
import mongoose from 'mongoose';

import { Room } from '../src/models/room.model.js';
import {
  isRoomMember,
  serializeRoom,
} from '../src/services/room.service.js';

test('private room requires a six-character invite code', () => {
  const host = new mongoose.Types.ObjectId();
  const room = new Room({
    title: 'Private conversation',
    privacy: 'private',
    inviteCode: 'ABC',
    host,
    members: [{ user: host, role: 'host' }],
    zegoRoomId: 'room_1',
  });

  assert.ok(room.validateSync()?.errors.inviteCode);
});

test('room rejects duplicate members', () => {
  const host = new mongoose.Types.ObjectId();
  const room = new Room({
    title: 'Public conversation',
    privacy: 'public',
    host,
    members: [
      { user: host, role: 'host' },
      { user: host, role: 'speaker' },
    ],
    zegoRoomId: 'room_2',
  });

  assert.ok(room.validateSync()?.errors.members);
});

test('room capacity stays between 2 and 50', () => {
  const host = new mongoose.Types.ObjectId();
  const room = new Room({
    title: 'Large room',
    privacy: 'public',
    host,
    members: [{ user: host, role: 'host' }],
    maxParticipants: 51,
    zegoRoomId: 'room_3',
  });

  assert.ok(room.validateSync()?.errors.maxParticipants);
});

test('isRoomMember detects existing participants', () => {
  const host = new mongoose.Types.ObjectId();
  const room = new Room({
    title: 'Membership room',
    privacy: 'public',
    host,
    members: [{ user: host, role: 'host' }],
    zegoRoomId: 'room_4',
  });

  assert.equal(isRoomMember(room, host), true);
});

test('media room ID is hidden from users who have not joined', () => {
  const host = new mongoose.Types.ObjectId();
  const visitor = new mongoose.Types.ObjectId();
  const room = new Room({
    title: 'Protected media room',
    privacy: 'public',
    host,
    members: [{ user: host, role: 'host' }],
    zegoRoomId: 'secret_media_room',
  });

  assert.equal(serializeRoom(room, visitor).zegoRoomId, null);
  assert.equal(serializeRoom(room, host).zegoRoomId, 'secret_media_room');
});
