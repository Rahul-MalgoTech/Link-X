import express from 'express';

import { requireAuth } from '../middleware/auth.js';
import { Notification } from '../models/notification.model.js';
import { asyncRoute } from '../utils/async-route.js';
import { serializeNotification } from '../services/notification.service.js';

const router = express.Router();

router.use(requireAuth);

router.get(
  '/',
  asyncRoute(async (req, res) => {
    const limit = Math.min(positiveInteger(req.query.limit, 50), 100);
    const notifications = await Notification.find({ user: req.user._id })
      .sort({ createdAt: -1 })
      .limit(limit);
    const unreadCount = await Notification.countDocuments({
      user: req.user._id,
      readAt: null,
    });
    res.json({
      notifications: notifications.map(serializeNotification),
      unreadCount,
    });
  }),
);

router.patch(
  '/read',
  asyncRoute(async (req, res) => {
    await Notification.updateMany(
      { user: req.user._id, readAt: null },
      { $set: { readAt: new Date() } },
    );
    res.json({ message: 'Notifications marked as read' });
  }),
);

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export default router;
