import express from 'express';
import mongoose from 'mongoose';
import multer from 'multer';
import { z } from 'zod';

import {
  assertCloudinaryConfigured,
  deleteCloudinaryAsset,
  uploadBufferToCloudinary,
} from '../config/cloudinary.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';
import { HostApplication } from '../models/host-application.model.js';
import { User } from '../models/user.model.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';

const router = express.Router();
const hostMediaUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 30 * 1024 * 1024, files: 1 },
});

const applicationSchema = z.object({
  displayName: z.string().trim().min(2).max(80),
  bio: z.string().trim().min(20).max(800),
  topics: z.array(z.string().trim().min(1).max(80)).min(1).max(12),
  languages: z.array(z.string().trim().min(1).max(60)).min(1).max(8),
  experience: z.string().trim().max(1200).default(''),
});

const reviewSchema = z.object({
  status: z.enum(['approved', 'rejected']),
  adminNote: z.string().trim().max(500).default(''),
});

router.use(requireAuth);

router.get(
  '/me',
  asyncRoute(async (req, res) => {
    const application = await HostApplication.findOne({ user: req.user._id })
      .sort({ createdAt: -1 })
      .lean();
    res.json({
      application: application ? serializeApplication(application) : null,
      hostProfile: serializeHostProfile(req.user),
    });
  }),
);

router.post(
  '/apply',
  hostMediaUpload.single('media'),
  asyncRoute(async (req, res) => {
    assertCloudinaryConfigured();
    const body = parseApplicationBody(req.body);
    const parsed = applicationSchema.safeParse(body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Validation failed',
        details: parsed.error.flatten(),
      });
    }

    const existingPending = await HostApplication.findOne({
      user: req.user._id,
      status: 'pending',
    }).lean();
    if (existingPending) {
      return res.status(409).json({
        message:
          'Your host application is already pending. Please wait for admin review.',
      });
    }

    const file = req.file;
    let uploaded = null;
    let resourceType = null;
    if (file) {
      const isImage = file.mimetype.startsWith('image/');
      const isVideo = file.mimetype.startsWith('video/');
      if (!isImage && !isVideo) {
        return res.status(400).json({
          message: 'Host media must be an image or video.',
        });
      }

      resourceType = isVideo ? 'video' : 'image';
      uploaded = await uploadBufferToCloudinary(file.buffer, {
        folder: `linkx/hosts/${req.user._id}`,
        resource_type: resourceType,
        timeout: 90000,
        ...(isImage
          ? {
              transformation: [
                { width: 1400, height: 1400, crop: 'limit' },
                { quality: 'auto', fetch_format: 'auto' },
              ],
            }
          : {}),
      });
    }

    try {
      const application = await HostApplication.create({
        user: req.user._id,
        ...parsed.data,
        status: 'pending',
        ...(uploaded
          ? {
              media: {
                url: uploaded.secure_url,
                publicId: uploaded.public_id,
                resourceType,
                originalName: file.originalname,
                mimeType: file.mimetype,
                size: file.size,
              },
            }
          : {}),
      });
      res.status(201).json({
        message: 'Host application submitted',
        application: serializeApplication(application),
        hostProfile: serializeHostProfile(req.user),
      });
    } catch (error) {
      if (uploaded) {
        await deleteCloudinaryAsset(uploaded.public_id, resourceType).catch(
          () => {},
        );
      }
      throw error;
    }
  }),
);

router.get(
  '/approved',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 12), 50);
    const query = {
      _id: { $ne: req.user._id },
      accountStatus: { $ne: 'suspended' },
      'hostProfile.approved': true,
    };
    const [hosts, total] = await Promise.all([
      User.find(query)
        .sort({ 'hostProfile.approvedAt': -1, updatedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      User.countDocuments(query),
    ]);
    res.json({
      hosts: hosts.map(serializeApprovedHost),
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
  '/admin/applications',
  requireAdmin,
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 50), 100);
    const status = ['pending', 'approved', 'rejected'].includes(
      req.query.status,
    )
      ? req.query.status
      : null;
    const query = status ? { status } : {};
    const [applications, total, pending, approved, rejected] =
      await Promise.all([
        HostApplication.find(query)
          .populate('user', 'firstName countryCode phoneNumber photos')
          .sort({ createdAt: -1 })
          .skip((page - 1) * limit)
          .limit(limit),
        HostApplication.countDocuments(query),
        HostApplication.countDocuments({ status: 'pending' }),
        HostApplication.countDocuments({ status: 'approved' }),
        HostApplication.countDocuments({ status: 'rejected' }),
      ]);

    res.json({
      applications: applications.map(serializeApplication),
      pagination: {
        page,
        limit,
        total,
        hasMore: page * limit < total,
      },
      summary: { pending, approved, rejected },
    });
  }),
);

router.patch(
  '/admin/applications/:applicationId',
  requireAdmin,
  validate(reviewSchema),
  asyncRoute(async (req, res) => {
    assertApplicationId(req.params.applicationId);
    const application = await HostApplication.findById(
      req.params.applicationId,
    );
    if (!application) {
      return res.status(404).json({ message: 'Host application not found' });
    }
    const user = await User.findById(application.user);
    if (!user) return res.status(404).json({ message: 'Applicant not found' });

    application.status = req.body.status;
    application.adminNote = req.body.adminNote || '';
    application.reviewedBy = req.user._id;
    application.reviewedAt = new Date();
    await application.save();

    if (req.body.status === 'approved') {
      user.hostProfile = {
        approved: true,
        displayName: application.displayName,
        bio: application.bio,
        topics: application.topics,
        languages: application.languages,
        experience: application.experience,
        media: application.media,
        application: application._id,
        approvedAt: application.reviewedAt,
      };
    } else if (
      user.hostProfile?.application?.toString?.() === application._id.toString()
    ) {
      user.hostProfile = {
        ...(user.hostProfile?.toObject?.() || {}),
        approved: false,
      };
    }
    await user.save();

    await application.populate(
      'user',
      'firstName countryCode phoneNumber photos',
    );
    res.json({
      message:
        req.body.status === 'approved'
          ? 'Host approved'
          : 'Host application rejected',
      application: serializeApplication(application),
    });
  }),
);

function parseApplicationBody(body) {
  return {
    displayName: typeof body.displayName === 'string' ? body.displayName : '',
    bio: typeof body.bio === 'string' ? body.bio : '',
    topics: parseStringList(body.topics),
    languages: parseStringList(body.languages),
    experience: typeof body.experience === 'string' ? body.experience : '',
  };
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

function serializeApplication(application) {
  const value = application.toObject ? application.toObject() : application;
  return {
    id: value._id.toString(),
    user: serializeApplicant(value.user),
    displayName: value.displayName || '',
    bio: value.bio || '',
    topics: value.topics || [],
    languages: value.languages || [],
    experience: value.experience || '',
    media: value.media || null,
    status: value.status || 'pending',
    adminNote: value.adminNote || '',
    reviewedAt: value.reviewedAt || null,
    createdAt: value.createdAt || null,
    updatedAt: value.updatedAt || null,
  };
}

function serializeApplicant(user) {
  if (!user || !user._id) return null;
  return {
    id: user._id.toString(),
    name: user.firstName || 'Linkx User',
    countryCode: user.countryCode || '',
    phoneNumber: user.phoneNumber || '',
    avatarUrl: user.photos?.[0]?.url || '',
  };
}

function serializeHostProfile(user) {
  const profile = user.hostProfile;
  if (!profile?.approved) {
    return { approved: false };
  }
  return {
    approved: true,
    displayName: profile.displayName || user.firstName || 'Linkx Host',
    bio: profile.bio || '',
    topics: profile.topics || [],
    languages: profile.languages || [],
    experience: profile.experience || '',
    media: profile.media || null,
    approvedAt: profile.approvedAt || null,
  };
}

function serializeApprovedHost(user) {
  const profile = user.hostProfile || {};
  return {
    id: user._id.toString(),
    displayName: profile.displayName || user.firstName || 'Linkx Host',
    bio: profile.bio || '',
    topics: profile.topics || [],
    languages: profile.languages || [],
    experience: profile.experience || '',
    avatarUrl: user.photos?.[0]?.url || profile.media?.url || '',
    media: profile.media || null,
    approvedAt: profile.approvedAt || null,
  };
}

function assertApplicationId(applicationId) {
  if (mongoose.isValidObjectId(applicationId)) return;
  const error = new Error('Invalid host application id');
  error.status = 400;
  throw error;
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export default router;
