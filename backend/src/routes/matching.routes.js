import express from 'express';
import { z } from 'zod';

import { Block } from '../models/block.model.js';
import { Match } from '../models/match.model.js';
import { Reaction } from '../models/reaction.model.js';
import { Report } from '../models/report.model.js';
import { requireAuth } from '../middleware/auth.js';
import {
  assertActiveMatch,
  assertTargetUser,
  findActiveMatch,
  isBlockedBetween,
  matchingPairKey,
} from '../services/matching.service.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';
import { createNotification } from '../services/notification.service.js';

const router = express.Router();

const reportSchema = z.object({
  reason: z.enum([
    'fake_profile',
    'harassment',
    'inappropriate_content',
    'spam',
    'underage',
    'other',
  ]),
  details: z.string().trim().max(1000).default(''),
});

router.use(requireAuth);

router.post(
  '/like/:userId',
  asyncRoute(async (req, res) => {
    const target = await assertTargetUser(req.user._id, req.params.userId);
    if (await isBlockedBetween(req.user._id, target._id)) {
      return res.status(403).json({ message: 'This profile is unavailable' });
    }

    await Reaction.findOneAndUpdate(
      { actor: req.user._id, target: target._id },
      { $set: { action: 'like' } },
      { upsert: true, new: true },
    );

    const reciprocalLike = await Reaction.exists({
      actor: target._id,
      target: req.user._id,
      action: 'like',
    });

    let match = null;
    if (reciprocalLike) {
      try {
        match = await Match.findOneAndUpdate(
          { participantKey: matchingPairKey(req.user._id, target._id) },
          {
            $setOnInsert: {
              users: [req.user._id, target._id],
              participantKey: matchingPairKey(req.user._id, target._id),
            },
            $set: {
              status: 'active',
              matchedAt: new Date(),
            },
            $unset: {
              unmatchedAt: 1,
              unmatchedBy: 1,
            },
          },
          { upsert: true, new: true },
        );
      } catch (error) {
        if (error.code !== 11000) throw error;
        match = await Match.findOne({
          participantKey: matchingPairKey(req.user._id, target._id),
        });
      }
      const matchEvent = {
        userIds: [req.user._id.toString(), target._id.toString()],
        matchedAt: match.matchedAt,
      };
      req.app
        .get('io')
        ?.to(`user:${req.user._id}`)
        .to(`user:${target._id}`)
        .emit('match:created', matchEvent);
      await Promise.all([
        createNotification({
          io: req.app.get('io'),
          userId: req.user._id,
          type: 'match',
          title: "It's a match!",
          body: `You and ${target.firstName || 'a Linkx user'} liked each other.`,
          data: { userId: target._id.toString() },
        }),
        createNotification({
          io: req.app.get('io'),
          userId: target._id,
          type: 'match',
          title: "It's a match!",
          body: `You and ${req.user.firstName || 'a Linkx user'} liked each other.`,
          data: { userId: req.user._id.toString() },
        }),
      ]);
    }

    res.json({
      action: 'like',
      matched: Boolean(match),
      match: match ? serializeMatch(match, req.user._id, target) : null,
    });
  }),
);

router.post(
  '/pass/:userId',
  asyncRoute(async (req, res) => {
    const target = await assertTargetUser(req.user._id, req.params.userId);
    if (await findActiveMatch(req.user._id, target._id)) {
      return res.status(409).json({
        message: 'Unmatch this user before passing their profile',
      });
    }

    await Reaction.findOneAndUpdate(
      { actor: req.user._id, target: target._id },
      { $set: { action: 'pass' } },
      { upsert: true, new: true },
    );
    res.json({ action: 'pass', matched: false });
  }),
);

router.get(
  '/likes',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const blocks = await Block.find({
      $or: [{ blocker: req.user._id }, { blocked: req.user._id }],
    }).lean();
    const blockedUserIds = blocks.map((block) =>
      block.blocker.toString() === req.user._id.toString()
        ? block.blocked
        : block.blocker,
    );
    const query = {
      target: req.user._id,
      action: 'like',
      actor: { $nin: blockedUserIds },
    };
    const reactions = await Reaction.find(query)
      .sort({ updatedAt: -1 })
      .populate(
        'actor',
        'firstName photos location birthDate lookingFor happiness identity accountStatus onboardingComplete isPhoneVerified',
      )
      .lean();
    const allVisibleReactions = reactions.filter(
      (reaction) =>
        reaction.actor &&
        reaction.actor.accountStatus !== 'suspended' &&
        reaction.actor.onboardingComplete &&
        reaction.actor.isPhoneVerified,
    );
    const total = allVisibleReactions.length;
    const start = (page - 1) * limit;
    const visibleReactions = allVisibleReactions.slice(start, start + limit);
    const actorIds = visibleReactions.map((reaction) => reaction.actor._id);
    const matches =
      actorIds.length === 0
        ? []
        : await Match.find({
            status: 'active',
            $and: [
              { users: req.user._id },
              { users: { $in: actorIds } },
            ],
          }).lean();
    const matchedUserIds = new Set();
    for (const match of matches) {
      for (const userId of match.users) {
        if (userId.toString() !== req.user._id.toString()) {
          matchedUserIds.add(userId.toString());
        }
      }
    }

    res.json({
      likes: visibleReactions.map((reaction) => ({
        id: reaction._id.toString(),
        likedAt: reaction.updatedAt,
        matched: matchedUserIds.has(reaction.actor._id.toString()),
        user: serializeUser(reaction.actor),
      })),
      pagination: {
        page,
        limit,
        total,
        hasMore: page * limit < total,
      },
    });
  }),
);

router.get(
  '/matches',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const query = { users: req.user._id, status: 'active' };
    const [matches, total] = await Promise.all([
      Match.find(query)
        .sort({ matchedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .populate('users', 'firstName photos location birthDate lookingFor happiness')
        .lean(),
      Match.countDocuments(query),
    ]);

    const items = matches
      .map((match) => {
        const otherUser = match.users.find(
          (user) => user._id.toString() !== req.user._id.toString(),
        );
        return otherUser
          ? {
              id: match._id.toString(),
              matchedAt: match.matchedAt,
              user: serializeUser(otherUser),
            }
          : null;
      })
      .filter(Boolean);

    res.json({
      matches: items,
      pagination: {
        page,
        limit,
        total,
        hasMore: page * limit < total,
      },
    });
  }),
);

router.get(
  '/status/:userId',
  asyncRoute(async (req, res) => {
    const target = await assertTargetUser(req.user._id, req.params.userId);
    const [match, blocked, reaction, likedByTarget] = await Promise.all([
      findActiveMatch(req.user._id, target._id),
      isBlockedBetween(req.user._id, target._id),
      Reaction.findOne({ actor: req.user._id, target: target._id }).lean(),
      Reaction.exists({
        actor: target._id,
        target: req.user._id,
        action: 'like',
      }),
    ]);
    res.json({
      matched: Boolean(match),
      blocked,
      reaction: reaction?.action || null,
      likedByTarget: Boolean(likedByTarget),
    });
  }),
);

router.post(
  '/call-authorize/:userId',
  asyncRoute(async (req, res) => {
    await assertActiveMatch(req.user._id, req.params.userId);
    res.json({ allowed: true });
  }),
);

router.delete(
  '/matches/:userId',
  asyncRoute(async (req, res) => {
    await assertTargetUser(req.user._id, req.params.userId);
    const match = await Match.findOneAndUpdate(
      {
        participantKey: matchingPairKey(req.user._id, req.params.userId),
        status: 'active',
      },
      {
        $set: {
          status: 'unmatched',
          unmatchedAt: new Date(),
          unmatchedBy: req.user._id,
        },
      },
      { new: true },
    );
    if (!match) return res.status(404).json({ message: 'Active match not found' });

    await Reaction.deleteMany({
      $or: [
        { actor: req.user._id, target: req.params.userId },
        { actor: req.params.userId, target: req.user._id },
      ],
    });
    req.app
      .get('io')
      ?.to(`user:${req.user._id}`)
      .to(`user:${req.params.userId}`)
      .emit('match:removed', { userIds: [req.user._id, req.params.userId] });
    res.json({ message: 'User unmatched' });
  }),
);

router.post(
  '/block/:userId',
  asyncRoute(async (req, res) => {
    const target = await assertTargetUser(req.user._id, req.params.userId);
    await Promise.all([
      Block.findOneAndUpdate(
        { blocker: req.user._id, blocked: target._id },
        { $setOnInsert: { blocker: req.user._id, blocked: target._id } },
        { upsert: true, new: true },
      ),
      Match.updateOne(
        { participantKey: matchingPairKey(req.user._id, target._id) },
        {
          $set: {
            status: 'unmatched',
            unmatchedAt: new Date(),
            unmatchedBy: req.user._id,
          },
        },
      ),
      Reaction.deleteMany({
        $or: [
          { actor: req.user._id, target: target._id },
          { actor: target._id, target: req.user._id },
        ],
      }),
    ]);
    req.app
      .get('io')
      ?.to(`user:${req.user._id}`)
      .to(`user:${target._id}`)
      .emit('match:removed', {
        userIds: [req.user._id.toString(), target._id.toString()],
      });
    res.json({ message: 'User blocked' });
  }),
);

router.delete(
  '/block/:userId',
  asyncRoute(async (req, res) => {
    await assertTargetUser(req.user._id, req.params.userId);
    await Block.deleteOne({
      blocker: req.user._id,
      blocked: req.params.userId,
    });
    res.json({ message: 'User unblocked' });
  }),
);

router.post(
  '/report/:userId',
  validate(reportSchema),
  asyncRoute(async (req, res) => {
    const target = await assertTargetUser(req.user._id, req.params.userId);
    const report = await Report.create({
      reporter: req.user._id,
      reported: target._id,
      reason: req.body.reason,
      details: req.body.details,
    });
    res.status(201).json({
      message: 'Report submitted',
      reportId: report._id.toString(),
    });
  }),
);

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function serializeMatch(match, currentUserId, target) {
  return {
    id: match._id.toString(),
    matchedAt: match.matchedAt,
    user:
      target._id.toString() === currentUserId.toString()
        ? null
        : serializeUser(target),
  };
}

function serializeUser(user) {
  return {
    id: user._id.toString(),
    name: user.firstName || 'Linkx User',
    age: ageFromBirthDate(user.birthDate),
    imageUrl: user.photos?.[0]?.url || '',
    location: user.location?.label || 'Nearby',
    lookingFor: user.lookingFor || '',
    interests: user.happiness || [],
    identity: user.identity || '',
  };
}

function ageFromBirthDate(birthDate) {
  if (!birthDate) return null;
  const date = new Date(birthDate);
  if (Number.isNaN(date.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - date.getFullYear();
  const birthdayPassed =
    now.getMonth() > date.getMonth() ||
    (now.getMonth() === date.getMonth() && now.getDate() >= date.getDate());
  if (!birthdayPassed) age -= 1;
  return age > 0 ? age : null;
}

export default router;
