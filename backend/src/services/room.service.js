import mongoose from 'mongoose';
import { customAlphabet } from 'nanoid';

import { Room } from '../models/room.model.js';

const createInviteCode = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 6);

export async function uniqueInviteCode() {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = createInviteCode();
    if (!(await Room.exists({ inviteCode: code }))) return code;
  }
  throw roomError('Unable to create an invite code', 503);
}

export function assertRoomId(roomId) {
  if (!mongoose.isValidObjectId(roomId)) {
    throw roomError('Invalid room ID', 400);
  }
}

export function isRoomMember(room, userId) {
  return room.members.some(
    (member) => member.user.toString() === userId.toString(),
  );
}

export function serializeRoom(room, currentUserId, { includeCode = false } = {}) {
  const raw = room.toObject ? room.toObject() : room;
  const members = raw.members || [];
  const hostId = raw.host?._id?.toString() || raw.host?.toString();
  const currentMember = members.find(
    (member) =>
      (member.user?._id?.toString() || member.user?.toString()) ===
      currentUserId.toString(),
  );

  return {
    id: raw._id.toString(),
    title: raw.title,
    topic: raw.topic || '',
    privacy: raw.privacy,
    status: raw.status,
    maxParticipants: raw.maxParticipants,
    participantCount: members.length,
    zegoRoomId:
      currentMember || hostId === currentUserId.toString()
        ? raw.zegoRoomId
        : null,
    inviteCode:
      includeCode || currentMember || hostId === currentUserId.toString()
        ? raw.inviteCode || null
        : null,
    isHost: hostId === currentUserId.toString(),
    isJoined: Boolean(currentMember),
    currentRole: currentMember?.role || null,
    host: serializeRoomUser(raw.host),
    members: members.map((member) => ({
      role: member.role,
      joinedAt: member.joinedAt,
      user: serializeRoomUser(member.user),
    })),
    createdAt: raw.createdAt,
    updatedAt: raw.updatedAt,
  };
}

function serializeRoomUser(user) {
  if (!user) return null;
  return {
    id: user._id?.toString() || user.toString(),
    name: user.firstName || 'Linkx User',
    imageUrl: user.photos?.[0]?.url || '',
  };
}

export function roomError(message, status) {
  const error = new Error(message);
  error.status = status;
  return error;
}
