import mongoose from 'mongoose';

import { Block } from '../models/block.model.js';
import { Match } from '../models/match.model.js';
import { User } from '../models/user.model.js';

export function matchingPairKey(firstUserId, secondUserId) {
  return [firstUserId.toString(), secondUserId.toString()].sort().join(':');
}

export async function assertTargetUser(actorId, targetId) {
  if (!mongoose.isValidObjectId(targetId)) {
    throw matchingError('Invalid user ID', 400);
  }
  if (actorId.toString() === targetId.toString()) {
    throw matchingError('You cannot perform this action on yourself', 400);
  }

  const target = await User.findById(targetId).select(
    '_id firstName photos onboardingComplete isPhoneVerified',
  );
  if (!target || !target.onboardingComplete || !target.isPhoneVerified) {
    throw matchingError('User not found', 404);
  }
  return target;
}

export async function isBlockedBetween(firstUserId, secondUserId) {
  return Boolean(
    await Block.exists({
      $or: [
        { blocker: firstUserId, blocked: secondUserId },
        { blocker: secondUserId, blocked: firstUserId },
      ],
    }),
  );
}

export async function findActiveMatch(firstUserId, secondUserId) {
  return Match.findOne({
    participantKey: matchingPairKey(firstUserId, secondUserId),
    status: 'active',
  });
}

export async function assertActiveMatch(firstUserId, secondUserId) {
  if (!mongoose.isValidObjectId(secondUserId)) {
    throw matchingError('Invalid user ID', 400);
  }
  if (firstUserId.toString() === secondUserId.toString()) {
    throw matchingError('You cannot contact yourself', 400);
  }
  if (await isBlockedBetween(firstUserId, secondUserId)) {
    throw matchingError('This interaction is not available', 403);
  }

  const match = await findActiveMatch(firstUserId, secondUserId);
  if (!match) {
    throw matchingError('You can only contact matched users', 403);
  }
  return match;
}

export function matchingError(message, status) {
  const error = new Error(message);
  error.status = status;
  return error;
}
