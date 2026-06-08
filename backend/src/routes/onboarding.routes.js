import express from 'express';
import multer from 'multer';
import { z } from 'zod';

import {
  assertCloudinaryConfigured,
  deleteCloudinaryAsset,
  uploadBufferToCloudinary,
} from '../config/cloudinary.js';
import { requireAuth } from '../middleware/auth.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 6 * 1024 * 1024, files: 6 },
});

const patchSchema = z.object({
  firstName: z.string().trim().min(1).max(60).optional(),
  identity: z.enum(['Him', 'Her', 'Other']).optional(),
  birthDate: z.coerce.date().optional(),
  showStarOnProfile: z.boolean().optional(),
  heightCm: z.number().int().min(120).max(240).optional(),
  educationLevel: z.string().trim().min(1).max(80).optional(),
  lookingFor: z.string().trim().min(1).max(120).optional(),
  happiness: z.array(z.string().trim().min(1).max(80)).max(12).optional(),
  children: z.string().trim().max(80).optional(),
  smoking: z.string().trim().max(80).optional(),
  location: z
    .object({
      label: z.string().trim().max(160).optional(),
      latitude: z.number().min(-90).max(90).optional(),
      longitude: z.number().min(-180).max(180).optional(),
    })
    .optional(),
  onboardingStep: z.string().trim().max(80).optional(),
  onboardingComplete: z.boolean().optional(),
});

router.use(requireAuth);

router.get(
  '/me',
  asyncRoute(async (req, res) => {
    res.json({ user: req.user });
  }),
);

router.get(
  '/photos',
  asyncRoute(async (req, res) => {
    res.json({ photos: req.user.photos });
  }),
);

router.patch(
  '/me',
  validate(patchSchema),
  asyncRoute(async (req, res) => {
    if (req.body.location) {
      req.body.location = await normalizeLocation(req.body.location);
    }

    Object.assign(req.user, req.body);
    await req.user.save();
    res.json({ message: 'Onboarding updated', user: req.user });
  }),
);

router.post(
  '/photos',
  upload.array('photos', 6),
  asyncRoute(async (req, res) => {
    assertCloudinaryConfigured();
    const files = req.files || [];
    const photos = await Promise.all(
      files.map(async (file) => {
        const result = await uploadBufferToCloudinary(file.buffer, {
          folder: `linkx/profiles/${req.user._id}`,
          resource_type: 'image',
          timeout: 60000,
          transformation: [
            { width: 1200, height: 1200, crop: 'limit' },
            { quality: 'auto', fetch_format: 'auto' },
          ],
        });

        return {
          url: result.secure_url,
          publicId: result.public_id,
          originalName: file.originalname,
          mimeType: file.mimetype,
          size: file.size,
        };
      }),
    );

    const previousPhotos = [...req.user.photos];
    req.user.photos = photos.slice(0, 6);
    req.user.onboardingStep = 'start';
    await req.user.save();
    await Promise.all(
      previousPhotos
        .filter((photo) => photo.publicId)
        .map((photo) =>
          deleteCloudinaryAsset(photo.publicId).catch((error) => {
            console.warn(
              `Unable to delete replaced photo ${photo.publicId}: ${error.message}`,
            );
          }),
        ),
    );

    res.status(201).json({ message: 'Photos uploaded', photos: req.user.photos });
  }),
);

router.post(
  '/complete',
  asyncRoute(async (req, res) => {
    req.user.onboardingComplete = true;
    req.user.onboardingStep = 'home';
    await req.user.save();
    res.json({ message: 'Onboarding complete', user: req.user });
  }),
);

async function normalizeLocation(location) {
  if (!hasCoordinates(location)) return location;
  if (hasReadableLabel(location.label)) return location;

  const label = await reverseGeocodeLocation(
    location.latitude,
    location.longitude,
  );

  return {
    ...location,
    label: label || 'Location detected',
  };
}

function hasCoordinates(location) {
  return (
    typeof location.latitude === 'number' &&
    Number.isFinite(location.latitude) &&
    typeof location.longitude === 'number' &&
    Number.isFinite(location.longitude)
  );
}

function hasReadableLabel(label) {
  if (!label || typeof label !== 'string') return false;
  const trimmed = label.trim();
  if (!trimmed || trimmed === 'Current location') return false;
  return !/^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$/.test(trimmed);
}

async function reverseGeocodeLocation(latitude, longitude) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 6000);

  try {
    const url = new URL('https://nominatim.openstreetmap.org/reverse');
    url.searchParams.set('format', 'jsonv2');
    url.searchParams.set('lat', latitude.toString());
    url.searchParams.set('lon', longitude.toString());
    url.searchParams.set('zoom', '18');
    url.searchParams.set('addressdetails', '1');

    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'LinkxBackend/1.0 (local development)',
        Accept: 'application/json',
      },
    });

    if (!response.ok) return null;
    const data = await response.json();
    return locationLabelFromAddress(data.address) || data.display_name || null;
  } catch (error) {
    console.warn(`Reverse geocoding failed: ${error.message}`);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function locationLabelFromAddress(address = {}) {
  const parts = [
    address.neighbourhood,
    address.suburb,
    address.quarter,
    address.hamlet,
    address.village,
    address.town,
    address.city,
    address.county,
    address.state_district,
    address.state,
  ].filter(Boolean);

  const uniqueParts = [];
  for (const part of parts) {
    const cleaned = String(part).trim();
    const exists = uniqueParts.some(
      (saved) => saved.toLowerCase() === cleaned.toLowerCase(),
    );
    if (cleaned && !exists) uniqueParts.push(cleaned);
  }

  return uniqueParts.slice(0, 3).join(', ');
}

export default router;
