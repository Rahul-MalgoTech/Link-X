import express from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';

import { requireAuth } from '../middleware/auth.js';
import { Room } from '../models/room.model.js';
import {
  assertRoomId,
  isRoomMember,
  roomError,
  serializeRoom,
  uniqueInviteCode,
} from '../services/room.service.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';
import { createNotification } from '../services/notification.service.js';

const router = express.Router();

const createRoomSchema = z.object({
  title: z.string().trim().min(3).max(80),
  topic: z.string().trim().max(180).default(''),
  privacy: z.enum(['public', 'private']),
  maxParticipants: z.number().int().min(2).max(50).default(12),
});

const joinRoomSchema = z.object({
  inviteCode: z.string().trim().toUpperCase().length(6).optional(),
});

router.use(requireAuth);

router.get(
  '/',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const privacy = req.query.privacy;
    if (privacy && privacy !== 'public' && privacy !== 'private') {
      throw roomError('Invalid room privacy filter', 400);
    }

    const query = {
      status: 'live',
      ...(privacy === 'private'
        ? { privacy: 'private', 'members.user': req.user._id }
        : privacy === 'public'
          ? { privacy: 'public' }
          : {
              $or: [
                { privacy: 'public' },
                { privacy: 'private', 'members.user': req.user._id },
              ],
            }),
    };
    const [rooms, total] = await Promise.all([
      Room.find(query)
        .sort({ updatedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .populate('host', 'firstName photos')
        .populate('members.user', 'firstName photos'),
      Room.countDocuments(query),
    ]);
    res.json({
      rooms: rooms.map((room) => serializeRoom(room, req.user._id)),
      pagination: {
        page,
        limit,
        total,
        hasMore: page * limit < total,
      },
    });
  }),
);

router.post(
  '/',
  validate(createRoomSchema),
  asyncRoute(async (req, res) => {
    const inviteCode =
      req.body.privacy === 'private' ? await uniqueInviteCode() : undefined;
    const room = await Room.create({
      ...req.body,
      inviteCode,
      host: req.user._id,
      members: [{ user: req.user._id, role: 'host' }],
      zegoRoomId: `linkx_room_${new mongoose.Types.ObjectId()}`,
    });
    await room.populate('host', 'firstName photos');
    await room.populate('members.user', 'firstName photos');
    req.app.get('io')?.emit('room:list:updated', {
      roomId: room._id.toString(),
      action: 'created',
      privacy: room.privacy,
    });
    res.status(201).json({
      room: serializeRoom(room, req.user._id, { includeCode: true }),
    });
  }),
);

router.post(
  '/join-by-code',
  validate(z.object({ inviteCode: z.string().trim().toUpperCase().length(6) })),
  asyncRoute(async (req, res) => {
    const room = await Room.findOne({
      inviteCode: req.body.inviteCode,
      privacy: 'private',
      status: 'live',
    });
    if (!room) throw roomError('Private room not found', 404);
    await joinRoom(room, req.user._id);
    await populateRoom(room);
    emitRoomUpdate(req.app.get('io'), room);
    res.json({
      room: serializeRoom(room, req.user._id, { includeCode: true }),
    });
  }),
);

router.get(
  '/:roomId',
  asyncRoute(async (req, res) => {
    assertRoomId(req.params.roomId);
    const room = await Room.findById(req.params.roomId);
    if (!room || room.status !== 'live') throw roomError('Room not found', 404);
    if (room.privacy === 'private' && !isRoomMember(room, req.user._id)) {
      throw roomError('This private room requires an invite code', 403);
    }
    await populateRoom(room);
    res.json({ room: serializeRoom(room, req.user._id) });
  }),
);

router.post(
  '/:roomId/join',
  validate(joinRoomSchema),
  asyncRoute(async (req, res) => {
    assertRoomId(req.params.roomId);
    const room = await Room.findById(req.params.roomId);
    if (!room || room.status !== 'live') throw roomError('Room not found', 404);
    if (
      room.privacy === 'private' &&
      !isRoomMember(room, req.user._id) &&
      req.body.inviteCode !== room.inviteCode
    ) {
      throw roomError('Invalid private room invite code', 403);
    }
    await joinRoom(room, req.user._id);
    await populateRoom(room);
    emitRoomUpdate(req.app.get('io'), room);
    res.json({
      room: serializeRoom(room, req.user._id, { includeCode: true }),
    });
  }),
);

router.post(
  '/:roomId/leave',
  asyncRoute(async (req, res) => {
    assertRoomId(req.params.roomId);
    const room = await Room.findById(req.params.roomId);
    if (!room || room.status !== 'live') throw roomError('Room not found', 404);
    if (room.host.toString() === req.user._id.toString()) {
      throw roomError('The host must end the room', 409);
    }
    room.members = room.members.filter(
      (member) => member.user.toString() !== req.user._id.toString(),
    );
    await room.save();
    await populateRoom(room);
    emitRoomUpdate(req.app.get('io'), room);
    res.json({ message: 'Left room' });
  }),
);

router.post(
  '/:roomId/end',
  asyncRoute(async (req, res) => {
    assertRoomId(req.params.roomId);
    const room = await Room.findById(req.params.roomId);
    if (!room || room.status !== 'live') throw roomError('Room not found', 404);
    assertHost(room, req.user._id);
    room.status = 'ended';
    room.endedAt = new Date();
    await room.save();
    req.app.get('io')?.to(`room:${room._id}`).emit('room:ended', {
      roomId: room._id.toString(),
    });
    req.app.get('io')?.emit('room:list:updated', {
      roomId: room._id.toString(),
      action: 'ended',
      privacy: room.privacy,
    });
    res.json({ message: 'Room ended' });
  }),
);

router.delete(
  '/:roomId/members/:userId',
  asyncRoute(async (req, res) => {
    assertRoomId(req.params.roomId);
    if (!mongoose.isValidObjectId(req.params.userId)) {
      throw roomError('Invalid member ID', 400);
    }
    const room = await Room.findById(req.params.roomId);
    if (!room || room.status !== 'live') throw roomError('Room not found', 404);
    assertHost(room, req.user._id);
    if (room.host.toString() === req.params.userId) {
      throw roomError('The host cannot be removed', 409);
    }
    room.members = room.members.filter(
      (member) => member.user.toString() !== req.params.userId,
    );
    await room.save();
    await populateRoom(room);
    req.app.get('io')?.to(`user:${req.params.userId}`).emit('room:removed', {
      roomId: room._id.toString(),
    });
    await createNotification({
      io: req.app.get('io'),
      userId: req.params.userId,
      type: 'room',
      title: 'Removed from room',
      body: `${req.user.firstName || 'The host'} removed you from ${room.title}.`,
      data: { roomId: room._id.toString() },
    });
    emitRoomUpdate(req.app.get('io'), room);
    res.json({ message: 'Member removed' });
  }),
);

async function joinRoom(room, userId) {
  if (isRoomMember(room, userId)) return;
  if (room.members.length >= room.maxParticipants) {
    throw roomError('This room is full', 409);
  }
  room.members.push({ user: userId, role: 'speaker' });
  await room.save();
}

async function populateRoom(room) {
  await room.populate('host', 'firstName photos');
  await room.populate('members.user', 'firstName photos');
}

function assertHost(room, userId) {
  if (room.host.toString() !== userId.toString()) {
    throw roomError('Only the room host can do this', 403);
  }
}

function emitRoomUpdate(io, room) {
  io?.to(`room:${room._id}`).emit('room:updated', {
    roomId: room._id.toString(),
  });
  io?.emit('room:list:updated', {
    roomId: room._id.toString(),
    action: 'updated',
    privacy: room.privacy,
  });
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export default router;
