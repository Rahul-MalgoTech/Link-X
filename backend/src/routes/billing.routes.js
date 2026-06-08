import express from 'express';
import { customAlphabet } from 'nanoid';

import { requireAuth } from '../middleware/auth.js';
import { Payment } from '../models/payment.model.js';
import { Subscription } from '../models/subscription.model.js';
import { asyncRoute } from '../utils/async-route.js';
import {
  billingPlans,
  freePlan,
  paidPlan,
  planExpiresAt,
} from '../services/billing.service.js';
import { createNotification } from '../services/notification.service.js';

const router = express.Router();
const createReference = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 12);

router.use(requireAuth);

router.get(
  '/plans',
  asyncRoute(async (_req, res) => {
    res.json({ plans: billingPlans });
  }),
);

router.get(
  '/me',
  asyncRoute(async (req, res) => {
    const subscription = await activeSubscription(req.user._id);
    const plan = subscription
      ? billingPlans.find((item) => item.id === subscription.planId)
      : freePlan();
    res.json({ plan, subscription });
  }),
);

router.post(
  '/checkout/:planId',
  asyncRoute(async (req, res) => {
    const plan = paidPlan(req.params.planId);
    if (!plan) return res.status(404).json({ message: 'Plan not found' });
    const reference = `mock_${createReference()}`;
    const payment = await Payment.create({
      user: req.user._id,
      planId: plan.id,
      amountCents: plan.priceCents,
      currency: plan.currency,
      provider: 'mock',
      providerReference: reference,
      status: 'succeeded',
    });
    await Subscription.updateMany(
      { user: req.user._id, status: 'active' },
      { $set: { status: 'cancelled' } },
    );
    const subscription = await Subscription.create({
      user: req.user._id,
      planId: plan.id,
      status: 'active',
      expiresAt: planExpiresAt(plan),
      provider: 'mock',
      providerReference: reference,
    });
    await createNotification({
      io: req.app.get('io'),
      userId: req.user._id,
      type: 'billing',
      title: `${plan.name} activated`,
      body: 'Your premium benefits are now active.',
      data: { planId: plan.id, paymentId: payment._id.toString() },
    });
    res.status(201).json({ payment, subscription, plan });
  }),
);

async function activeSubscription(userId) {
  const now = new Date();
  return Subscription.findOne({
    user: userId,
    status: 'active',
    $or: [{ expiresAt: null }, { expiresAt: { $gt: now } }],
  })
    .sort({ createdAt: -1 })
    .lean();
}

export default router;
