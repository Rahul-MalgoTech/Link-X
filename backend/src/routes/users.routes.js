import express from 'express';
import mongoose from 'mongoose';
import multer from 'multer';
import { z } from 'zod';

import { Block } from '../models/block.model.js';
import { Conversation } from '../models/conversation.model.js';
import { Match } from '../models/match.model.js';
import { Message } from '../models/message.model.js';
import { Notification } from '../models/notification.model.js';
import { Otp } from '../models/otp.model.js';
import { Payment } from '../models/payment.model.js';
import { Reaction } from '../models/reaction.model.js';
import { Report } from '../models/report.model.js';
import { Room } from '../models/room.model.js';
import { Subscription } from '../models/subscription.model.js';
import { SupportRequest } from '../models/support-request.model.js';
import { isAdminUser, requireAdmin, requireAuth } from '../middleware/auth.js';
import { User } from '../models/user.model.js';
import {
  assertCloudinaryConfigured,
  deleteCloudinaryAsset,
  uploadBufferToCloudinary,
} from '../config/cloudinary.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';

const router = express.Router();
const photoUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 6 * 1024 * 1024, files: 6 },
});

const profileSchema = z.object({
  firstName: z.string().trim().min(1).max(60).optional(),
  bio: z.string().trim().max(500).optional(),
  identity: z.enum(['Him', 'Her', 'Other']).optional(),
  birthDate: z.coerce.date().optional(),
  heightCm: z.number().int().min(120).max(240).nullable().optional(),
  educationLevel: z.string().trim().max(80).optional(),
  lookingFor: z.string().trim().max(120).optional(),
  happiness: z.array(z.string().trim().min(1).max(80)).max(12).optional(),
  children: z.string().trim().max(80).optional(),
  smoking: z.string().trim().max(80).optional(),
});

const settingsSchema = z.object({
  privacySettings: z
    .object({
      discoverable: z.boolean().optional(),
      showOnlineStatus: z.boolean().optional(),
      showDistance: z.boolean().optional(),
      showAge: z.boolean().optional(),
    })
    .optional(),
  notificationSettings: z
    .object({
      newMatches: z.boolean().optional(),
      messages: z.boolean().optional(),
      likes: z.boolean().optional(),
      calls: z.boolean().optional(),
    })
    .optional(),
});

const supportSchema = z.object({
  subject: z.string().trim().min(3).max(120),
  message: z.string().trim().min(10).max(2000),
});

const nullableText = (maximum) =>
  z.string().trim().max(maximum).nullable().optional();

const adminUserUpdateSchema = z
  .object({
    countryCode: z.string().trim().min(1).max(8).optional(),
    phoneNumber: z.string().trim().min(5).max(20).optional(),
    role: z.enum(['user', 'admin']).optional(),
    accountStatus: z.enum(['active', 'suspended']).optional(),
    isPhoneVerified: z.boolean().optional(),
    firstName: nullableText(60),
    bio: nullableText(500),
    identity: z.enum(['Him', 'Her', 'Other']).nullable().optional(),
    birthDate: z.coerce.date().nullable().optional(),
    showStarOnProfile: z.boolean().optional(),
    heightCm: z.number().int().min(120).max(240).nullable().optional(),
    educationLevel: nullableText(80),
    lookingFor: nullableText(120),
    happiness: z.array(z.string().trim().min(1).max(80)).max(12).optional(),
    children: nullableText(80),
    smoking: nullableText(80),
    location: z
      .object({
        label: nullableText(180),
        latitude: z.number().min(-90).max(90).nullable().optional(),
        longitude: z.number().min(-180).max(180).nullable().optional(),
      })
      .nullable()
      .optional(),
    privacySettings: settingsSchema.shape.privacySettings,
    notificationSettings: settingsSchema.shape.notificationSettings,
    onboardingStep: z.string().trim().max(80).optional(),
    onboardingComplete: z.boolean().optional(),
  })
  .strict();

router.use(requireAuth);

router.get(
  '/admin-users',
  requireAdmin,
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 100);
    const search =
      typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const role = ['user', 'admin'].includes(req.query.role)
      ? req.query.role
      : null;
    const accountStatus = ['active', 'suspended'].includes(
      req.query.accountStatus,
    )
      ? req.query.accountStatus
      : null;
    const onboardingComplete =
      req.query.onboardingComplete === 'true'
        ? true
        : req.query.onboardingComplete === 'false'
          ? false
          : null;
    const query = {
      ...(search
        ? {
            $or: [
              { firstName: { $regex: escapeRegex(search), $options: 'i' } },
              { phoneNumber: { $regex: escapeRegex(search), $options: 'i' } },
              { countryCode: { $regex: escapeRegex(search), $options: 'i' } },
            ],
          }
        : {}),
      ...(role ? { role } : {}),
      ...(accountStatus ? { accountStatus } : {}),
      ...(onboardingComplete == null ? {} : { onboardingComplete }),
    };

    const [users, total, active, suspended, onboarded] = await Promise.all([
      User.find(query)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      User.countDocuments(query),
      User.countDocuments({ accountStatus: { $ne: 'suspended' } }),
      User.countDocuments({ accountStatus: 'suspended' }),
      User.countDocuments({ onboardingComplete: true }),
    ]);

    res.json({
      users: users.map(toAdminUser),
      pagination: { page, limit, total, hasMore: page * limit < total },
      summary: {
        total: await User.countDocuments(),
        active,
        suspended,
        onboarded,
      },
    });
  }),
);

router.get(
  '/admin-users/:userId',
  requireAdmin,
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({ user: toAdminUser(user) });
  }),
);

router.patch(
  '/admin-users/:userId',
  requireAdmin,
  validate(adminUserUpdateSchema),
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const editingSelf = user._id.toString() === req.user._id.toString();
    const proposedUser = { ...user.toObject(), ...req.body };
    if (
      editingSelf &&
      (!isAdminUser(proposedUser) ||
        req.body.accountStatus === 'suspended')
    ) {
      return res.status(409).json({
        message:
          'You cannot remove administrator access from or suspend your own account',
      });
    }

    const { privacySettings, notificationSettings, location, ...fields } =
      req.body;
    Object.assign(user, fields);
    if (privacySettings) {
      user.privacySettings = {
        ...(user.privacySettings?.toObject?.() || {}),
        ...privacySettings,
      };
    }
    if (notificationSettings) {
      user.notificationSettings = {
        ...(user.notificationSettings?.toObject?.() || {}),
        ...notificationSettings,
      };
    }
    if (location === null) {
      user.location = undefined;
    } else if (location) {
      user.location = {
        ...(user.location?.toObject?.() || {}),
        ...location,
      };
    }

    try {
      await user.save();
    } catch (error) {
      if (error?.code === 11000) {
        return res.status(409).json({
          message: 'That phone number is already used by another account',
        });
      }
      throw error;
    }

    if (user.accountStatus === 'suspended') {
      req.app.get('io')?.in(`user:${user._id}`).disconnectSockets(true);
    }
    res.json({ message: 'User updated', user: toAdminUser(user) });
  }),
);

router.post(
  '/admin-users/:userId/photos',
  requireAdmin,
  photoUpload.array('photos', 6),
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    assertCloudinaryConfigured();
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const files = req.files || [];
    if (files.length === 0) {
      return res.status(400).json({ message: 'Select at least one image' });
    }
    const availableSlots = Math.max(0, 6 - user.photos.length);
    if (availableSlots === 0 || files.length > availableSlots) {
      return res.status(409).json({
        message: `This profile can accept ${availableSlots} more photo${availableSlots === 1 ? '' : 's'}`,
      });
    }

    const uploadedPhotos = [];
    try {
      for (const file of files) {
        const result = await uploadBufferToCloudinary(file.buffer, {
          folder: `linkx/profiles/${user._id}`,
          resource_type: 'image',
          timeout: 60000,
          transformation: [
            { width: 1200, height: 1200, crop: 'limit' },
            { quality: 'auto', fetch_format: 'auto' },
          ],
        });
        uploadedPhotos.push({
          url: result.secure_url,
          publicId: result.public_id,
          originalName: file.originalname,
          mimeType: file.mimetype,
          size: file.size,
        });
      }
      user.photos.push(...uploadedPhotos);
      await user.save();
    } catch (error) {
      await Promise.all(
        uploadedPhotos.map((photo) =>
          deleteCloudinaryAsset(photo.publicId).catch(() => {}),
        ),
      );
      throw error;
    }

    res.status(201).json({
      message: 'Profile photos uploaded',
      user: toAdminUser(user),
    });
  }),
);

router.patch(
  '/admin-users/:userId/photos/:photoIndex/primary',
  requireAdmin,
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const photoIndex = validPhotoIndex(req.params.photoIndex, user.photos);
    if (photoIndex > 0) {
      const photos = [...user.photos];
      const [primaryPhoto] = photos.splice(photoIndex, 1);
      photos.unshift(primaryPhoto);
      user.photos = photos;
      await user.save();
    }
    res.json({ message: 'Primary photo updated', user: toAdminUser(user) });
  }),
);

router.delete(
  '/admin-users/:userId/photos/:photoIndex',
  requireAdmin,
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    const photoIndex = validPhotoIndex(req.params.photoIndex, user.photos);
    const [removedPhoto] = user.photos.splice(photoIndex, 1);
    await user.save();
    if (removedPhoto.publicId) {
      await deleteCloudinaryAsset(removedPhoto.publicId).catch((error) => {
        console.warn(
          `Unable to delete admin-removed photo ${removedPhoto.publicId}: ${error.message}`,
        );
      });
    }
    res.json({ message: 'Profile photo removed', user: toAdminUser(user) });
  }),
);

router.delete(
  '/admin-users/:userId',
  requireAdmin,
  asyncRoute(async (req, res) => {
    assertUserId(req.params.userId);
    if (req.params.userId === req.user._id.toString()) {
      return res.status(409).json({
        message: 'You cannot delete your own administrator account',
      });
    }
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    await deleteUserAccount(user, req.app.get('io'));
    res.json({ message: 'User account deleted' });
  }),
);

router.get(
  '/me',
  asyncRoute(async (req, res) => {
    res.json({
      user: {
        ...req.user.toObject(),
        isAdmin: isAdminUser(req.user),
      },
    });
  }),
);

router.patch(
  '/me',
  validate(profileSchema),
  asyncRoute(async (req, res) => {
    Object.assign(req.user, req.body);
    await req.user.save();
    res.json({ message: 'Profile updated', user: req.user });
  }),
);

router.patch(
  '/me/settings',
  validate(settingsSchema),
  asyncRoute(async (req, res) => {
    const hideOnlineStatus =
      req.body.privacySettings?.showOnlineStatus === false &&
      req.user.privacySettings?.showOnlineStatus !== false;
    if (req.body.privacySettings) {
      req.user.privacySettings = {
        ...(req.user.privacySettings?.toObject?.() || {}),
        ...req.body.privacySettings,
      };
    }
    if (req.body.notificationSettings) {
      req.user.notificationSettings = {
        ...(req.user.notificationSettings?.toObject?.() || {}),
        ...req.body.notificationSettings,
      };
    }
    await req.user.save();
    if (hideOnlineStatus) {
      const matches = await Match.find({
        users: req.user._id,
        status: 'active',
      })
        .select('users')
        .lean();
      for (const match of matches) {
        for (const userId of match.users) {
          if (userId.toString() !== req.user._id.toString()) {
            req.app.get('io')?.to(`user:${userId}`).emit('chat:presence', {
              userId: req.user._id.toString(),
              isOnline: false,
            });
          }
        }
      }
    }
    res.json({
      message: 'Settings updated',
      privacySettings: req.user.privacySettings,
      notificationSettings: req.user.notificationSettings,
    });
  }),
);

router.post(
  '/me/support',
  validate(supportSchema),
  asyncRoute(async (req, res) => {
    const request = await SupportRequest.create({
      user: req.user._id,
      subject: req.body.subject,
      message: req.body.message,
    });
    res.status(201).json({
      message: 'Support request submitted',
      requestId: request._id.toString(),
    });
  }),
);

router.delete(
  '/me',
  asyncRoute(async (req, res) => {
    await deleteUserAccount(req.user, req.app.get('io'));
    res.json({ message: 'Account deleted' });
  }),
);

router.get(
  '/explore',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const minAge = boundedInteger(req.query.minAge, 18, 100, 18);
    const maxAge = boundedInteger(req.query.maxAge, minAge, 100, 80);
    const maxDistance = boundedInteger(
      req.query.maxDistance,
      1,
      5000,
      5000,
    );
    const identity = normalizeIdentity(req.query.identity);
    const search =
      typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const lookingFor =
      typeof req.query.lookingFor === 'string'
        ? req.query.lookingFor.trim()
        : '';
    const interests = parseStringList(req.query.interests);
    const excludeReacted = req.query.excludeReacted === 'true';

    const [blocks, reactions, activeMatches] = await Promise.all([
      Block.find({
        $or: [{ blocker: req.user._id }, { blocked: req.user._id }],
      }).lean(),
      excludeReacted
        ? Reaction.find({ actor: req.user._id }).select('target').lean()
        : [],
      Match.find({ users: req.user._id, status: 'active' })
        .select('users')
        .lean(),
    ]);

    const excludedIds = new Set([req.user._id.toString()]);
    for (const block of blocks) {
      excludedIds.add(
        block.blocker.toString() === req.user._id.toString()
          ? block.blocked.toString()
          : block.blocker.toString(),
      );
    }
    for (const reaction of reactions) excludedIds.add(reaction.target.toString());
    if (excludeReacted) {
      for (const match of activeMatches) {
        for (const userId of match.users) {
          if (userId.toString() !== req.user._id.toString()) {
            excludedIds.add(userId.toString());
          }
        }
      }
    }

    const query = {
      _id: { $nin: [...excludedIds] },
      accountStatus: { $ne: 'suspended' },
      onboardingComplete: true,
      isPhoneVerified: true,
      'privacySettings.discoverable': { $ne: false },
      birthDate: {
        $lte: yearsAgo(minAge),
        $gt: yearsAgo(maxAge + 1),
      },
      'photos.0.url': { $exists: true, $ne: '' },
      ...(identity ? { identity } : {}),
      ...(search
        ? { firstName: { $regex: escapeRegex(search), $options: 'i' } }
        : {}),
      ...(lookingFor
        ? { lookingFor: { $regex: escapeRegex(lookingFor), $options: 'i' } }
        : {}),
      ...(interests.length > 0
        ? {
            happiness: {
              $in: interests.map((interest) => new RegExp(`^${escapeRegex(interest)}$`, 'i')),
            },
          }
        : {}),
    };

    const candidates = await User.find(query).sort({ updatedAt: -1 }).lean();
    const filtered = candidates.filter((user) => {
      const age = ageFromBirthDate(user.birthDate);
      if (age == null || age < minAge || age > maxAge) return false;
      const distance = distanceMiles(req.user.location, user.location);
      if (!hasCoordinates(req.user.location)) return true;
      return distance != null && distance <= maxDistance;
    });

    const total = filtered.length;
    const start = (page - 1) * limit;
    const pageUsers = filtered.slice(start, start + limit);
    const pageUserIds = pageUsers.map((user) => user._id);
    const [pageReactions, pageMatches] = await Promise.all([
      Reaction.find({
        actor: req.user._id,
        target: { $in: pageUserIds },
      }).lean(),
      pageUserIds.length === 0
        ? Promise.resolve([])
        : Match.find({
            status: 'active',
            $and: [
              { users: req.user._id },
              { users: { $in: pageUserIds } },
            ],
          }).lean(),
    ]);
    const reactionByTarget = new Map(
      pageReactions.map((reaction) => [
        reaction.target.toString(),
        reaction.action,
      ]),
    );
    const matchedUserIds = new Set();
    for (const match of pageMatches) {
      for (const userId of match.users) {
        if (userId.toString() !== req.user._id.toString()) {
          matchedUserIds.add(userId.toString());
        }
      }
    }

    res.json({
      users: pageUsers.map((user) =>
        toExploreUser(user, req.user, {
          reaction: reactionByTarget.get(user._id.toString()) || null,
          matched: matchedUserIds.has(user._id.toString()),
        }),
      ),
      pagination: {
        page,
        limit,
        total,
        hasMore: start + pageUsers.length < total,
      },
      filters: {
        identity,
        minAge,
        maxAge,
        maxDistance,
        search,
        lookingFor,
        interests,
        excludeReacted,
      },
    });
  }),
);

function toExploreUser(user, currentUser, relationship) {
  return {
    id: user._id.toString(),
    name: user.firstName || 'Linkx User',
    age:
      user.privacySettings?.showAge === false
        ? null
        : ageFromBirthDate(user.birthDate),
    imageUrl: user.photos?.[0]?.url || '',
    location: user.location?.label || 'Nearby',
    distanceMiles:
      user.privacySettings?.showDistance === false
        ? null
        : distanceMiles(currentUser.location, user.location),
    lookingFor: user.lookingFor || '',
    interests: user.happiness || [],
    identity: user.identity || '',
    relationshipStatus: relationship.matched
      ? 'matched'
      : relationship.reaction || 'none',
  };
}

function toAdminUser(user) {
  const value = user.toObject ? user.toObject() : user;
  return {
    id: value._id.toString(),
    countryCode: value.countryCode || '',
    phoneNumber: value.phoneNumber || '',
    role: value.role || 'user',
    isAdmin: isAdminUser(value),
    accountStatus: value.accountStatus || 'active',
    isPhoneVerified: value.isPhoneVerified === true,
    firstName: value.firstName || '',
    bio: value.bio || '',
    identity: value.identity || null,
    birthDate: value.birthDate || null,
    showStarOnProfile: value.showStarOnProfile !== false,
    heightCm: value.heightCm ?? null,
    educationLevel: value.educationLevel || '',
    lookingFor: value.lookingFor || '',
    happiness: value.happiness || [],
    children: value.children || '',
    smoking: value.smoking || '',
    location: value.location || {},
    photos: value.photos || [],
    privacySettings: value.privacySettings || {},
    notificationSettings: value.notificationSettings || {},
    onboardingStep: value.onboardingStep || '',
    onboardingComplete: value.onboardingComplete === true,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  };
}

async function deleteUserAccount(user, io) {
  const userId = user._id;
  const matchedUsers = await Match.find({ users: userId })
    .select('users')
    .lean();
  const conversations = await Conversation.find({
    participants: userId,
  }).select('_id');
  const conversationIds = conversations.map(({ _id }) => _id);
  const hostedRooms = await Room.find({ host: userId }).select('_id');
  const hostedRoomIds = hostedRooms.map(({ _id }) => _id);

  await Promise.all(
    user.photos
      .filter((photo) => photo.publicId)
      .map((photo) =>
        deleteCloudinaryAsset(photo.publicId).catch((error) => {
          console.warn(
            `Unable to delete photo ${photo.publicId}: ${error.message}`,
          );
        }),
      ),
  );

  await Promise.all([
    Message.deleteMany({ conversation: { $in: conversationIds } }),
    Conversation.deleteMany({ _id: { $in: conversationIds } }),
    Match.deleteMany({ users: userId }),
    Reaction.deleteMany({ $or: [{ actor: userId }, { target: userId }] }),
    Block.deleteMany({ $or: [{ blocker: userId }, { blocked: userId }] }),
    Report.deleteMany({ $or: [{ reporter: userId }, { reported: userId }] }),
    SupportRequest.deleteMany({ user: userId }),
    Notification.deleteMany({ user: userId }),
    Payment.deleteMany({ user: userId }),
    Subscription.deleteMany({ user: userId }),
    Room.deleteMany({ _id: { $in: hostedRoomIds } }),
    Room.updateMany(
      { host: { $ne: userId }, 'members.user': userId },
      { $pull: { members: { user: userId } } },
    ),
    Otp.deleteMany({
      countryCode: user.countryCode,
      phoneNumber: user.phoneNumber,
    }),
  ]);
  await User.deleteOne({ _id: userId });

  for (const match of matchedUsers) {
    for (const otherUserId of match.users) {
      if (otherUserId.toString() !== userId.toString()) {
        io?.to(`user:${otherUserId}`).emit('match:removed', {
          userIds: [userId.toString(), otherUserId.toString()],
        });
      }
    }
  }
  io?.in(`user:${userId}`).disconnectSockets(true);
}

function assertUserId(userId) {
  if (mongoose.isValidObjectId(userId)) return;
  const error = new Error('Invalid user id');
  error.status = 400;
  throw error;
}

function validPhotoIndex(value, photos) {
  const index = Number.parseInt(value, 10);
  if (Number.isInteger(index) && index >= 0 && index < photos.length) {
    return index;
  }
  const error = new Error('Invalid profile photo');
  error.status = 400;
  throw error;
}

function ageFromBirthDate(birthDate) {
  if (!birthDate) return null;
  const date = new Date(birthDate);
  if (Number.isNaN(date.getTime())) return null;

  const now = new Date();
  let age = now.getFullYear() - date.getFullYear();
  const hasBirthdayPassed =
    now.getMonth() > date.getMonth() ||
    (now.getMonth() === date.getMonth() && now.getDate() >= date.getDate());
  if (!hasBirthdayPassed) age -= 1;
  return age > 0 ? age : null;
}

function distanceMiles(from, to) {
  if (!hasCoordinates(from) || !hasCoordinates(to)) return null;

  const earthRadiusMiles = 3958.8;
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);

  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(fromLatitude) *
      Math.cos(toLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.max(1, Math.round(earthRadiusMiles * c));
}

function hasCoordinates(location) {
  return (
    location &&
    typeof location.latitude === 'number' &&
    Number.isFinite(location.latitude) &&
    typeof location.longitude === 'number' &&
    Number.isFinite(location.longitude)
  );
}

function normalizeIdentity(value) {
  if (value === 'Him' || value === 'Her' || value === 'Other') return value;
  return null;
}

function parseStringList(value) {
  if (Array.isArray(value)) {
    return value
      .flatMap((item) => parseStringList(item))
      .filter((item, index, items) => items.indexOf(item) === index);
  }
  if (typeof value !== 'string') return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 12);
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function boundedInteger(value, minimum, maximum, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed)) return fallback;
  return Math.min(Math.max(parsed, minimum), maximum);
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function yearsAgo(years) {
  const date = new Date();
  date.setFullYear(date.getFullYear() - years);
  return date;
}

function toRadians(value) {
  return (value * Math.PI) / 180;
}

export default router;
