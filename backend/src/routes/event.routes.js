import express from 'express';
import mongoose from 'mongoose';
import { z } from 'zod';

import { requireAdmin, requireAuth } from '../middleware/auth.js';
import { Event } from '../models/event.model.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';
import { createNotification } from '../services/notification.service.js';

const router = express.Router();

const eventSchema = z.object({
  title: z.string().trim().min(3).max(120),
  description: z.string().trim().max(2000).default(''),
  venue: z.string().trim().max(180).default(''),
  coverImageUrl: z.string().trim().url().optional().or(z.literal('')),
  startAt: z.coerce.date(),
  endAt: z.coerce.date().optional(),
  capacity: z.number().int().min(1).max(100000).default(100),
  priceCents: z.number().int().min(0).default(0),
  currency: z.string().trim().length(3).default('INR'),
});

const eventUpdateSchema = eventSchema.partial().extend({
  endAt: z.coerce.date().nullable().optional(),
  status: z.enum(['published', 'cancelled']).optional(),
});

router.use(requireAuth);

router.get(
  '/admin',
  requireAdmin,
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const [events, total] = await Promise.all([
      Event.find()
        .sort({ startAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      Event.countDocuments(),
    ]);
    res.json({
      events: events.map((event) => serializeEvent(event, req.user._id)),
      pagination: { page, limit, total, hasMore: page * limit < total },
    });
  }),
);

router.get(
  '/',
  asyncRoute(async (req, res) => {
    const page = positiveInteger(req.query.page, 1);
    const limit = Math.min(positiveInteger(req.query.limit, 20), 50);
    const query = { status: 'published', startAt: { $gte: startOfToday() } };
    const [events, total] = await Promise.all([
      Event.find(query)
        .sort({ startAt: 1 })
        .skip((page - 1) * limit)
        .limit(limit),
      Event.countDocuments(query),
    ]);
    res.json({
      events: events.map((event) => serializeEvent(event, req.user._id)),
      pagination: { page, limit, total, hasMore: page * limit < total },
    });
  }),
);

router.post(
  '/',
  requireAdmin,
  validate(eventSchema),
  asyncRoute(async (req, res) => {
    const event = await Event.create({
      ...req.body,
      createdBy: req.user._id,
    });
    res.status(201).json({ event: serializeEvent(event, req.user._id) });
  }),
);

router.patch(
  '/:eventId',
  requireAdmin,
  validate(eventUpdateSchema),
  asyncRoute(async (req, res) => {
    assertEventId(req.params.eventId);
    const event = await Event.findById(req.params.eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    Object.assign(event, req.body);
    await event.save();
    res.json({ event: serializeEvent(event, req.user._id) });
  }),
);

router.delete(
  '/:eventId',
  requireAdmin,
  asyncRoute(async (req, res) => {
    assertEventId(req.params.eventId);
    const event = await Event.findById(req.params.eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    event.status = 'cancelled';
    await event.save();
    res.json({ event: serializeEvent(event, req.user._id) });
  }),
);

router.get(
  '/:eventId',
  asyncRoute(async (req, res) => {
    assertEventId(req.params.eventId);
    const event = await Event.findById(req.params.eventId);
    if (!event || event.status !== 'published') {
      return res.status(404).json({ message: 'Event not found' });
    }
    res.json({ event: serializeEvent(event, req.user._id) });
  }),
);

router.post(
  '/:eventId/rsvp',
  asyncRoute(async (req, res) => {
    assertEventId(req.params.eventId);
    const event = await Event.findById(req.params.eventId);
    if (!event || event.status !== 'published') {
      return res.status(404).json({ message: 'Event not found' });
    }
    const attendee = event.attendees.find(
      (item) => item.user.toString() === req.user._id.toString(),
    );
    if (attendee) {
      attendee.status = 'going';
      attendee.rsvpedAt = new Date();
    } else {
      const goingCount = event.attendees.filter(
        (item) => item.status === 'going',
      ).length;
      if (goingCount >= event.capacity) {
        return res.status(409).json({ message: 'Event is full' });
      }
      event.attendees.push({ user: req.user._id, status: 'going' });
    }
    await event.save();
    await createNotification({
      io: req.app.get('io'),
      userId: req.user._id,
      type: 'event',
      title: 'RSVP confirmed',
      body: `You're going to ${event.title}.`,
      data: { eventId: event._id.toString() },
    });
    res.json({ event: serializeEvent(event, req.user._id) });
  }),
);

router.delete(
  '/:eventId/rsvp',
  asyncRoute(async (req, res) => {
    assertEventId(req.params.eventId);
    const event = await Event.findById(req.params.eventId);
    if (!event || event.status !== 'published') {
      return res.status(404).json({ message: 'Event not found' });
    }
    const attendee = event.attendees.find(
      (item) => item.user.toString() === req.user._id.toString(),
    );
    if (attendee) attendee.status = 'cancelled';
    await event.save();
    res.json({ event: serializeEvent(event, req.user._id) });
  }),
);

function serializeEvent(event, userId) {
  const going = event.attendees.filter((item) => item.status === 'going');
  return {
    id: event._id.toString(),
    title: event.title,
    description: event.description,
    venue: event.venue,
    coverImageUrl: event.coverImageUrl,
    startAt: event.startAt,
    endAt: event.endAt || null,
    capacity: event.capacity,
    priceCents: event.priceCents,
    currency: event.currency,
    status: event.status,
    attendeeCount: going.length,
    isGoing: going.some((item) => item.user.toString() === userId.toString()),
  };
}

function assertEventId(eventId) {
  if (!mongoose.isValidObjectId(eventId)) {
    const error = new Error('Invalid event ID');
    error.status = 400;
    throw error;
  }
}

function startOfToday() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date;
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export default router;
