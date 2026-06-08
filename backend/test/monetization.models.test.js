import assert from 'node:assert/strict';
import test from 'node:test';
import mongoose from 'mongoose';

import { Event } from '../src/models/event.model.js';
import { Notification } from '../src/models/notification.model.js';
import { Payment } from '../src/models/payment.model.js';
import { Subscription } from '../src/models/subscription.model.js';
import { paidPlan } from '../src/services/billing.service.js';

test('notification requires a supported type', () => {
  const notification = new Notification({
    user: new mongoose.Types.ObjectId(),
    type: 'unknown',
    title: 'Hello',
    body: 'World',
  });

  assert.ok(notification.validateSync()?.errors.type);
});

test('event rejects duplicate active attendees', () => {
  const user = new mongoose.Types.ObjectId();
  const event = new Event({
    title: 'Concert',
    startAt: new Date(Date.now() + 86400000),
    attendees: [
      { user, status: 'going' },
      { user, status: 'going' },
    ],
  });

  assert.ok(event.validateSync()?.errors.attendees);
});

test('subscription only allows known plan ids', () => {
  const subscription = new Subscription({
    user: new mongoose.Types.ObjectId(),
    planId: 'gold',
  });

  assert.ok(subscription.validateSync()?.errors.planId);
});

test('payment amount cannot be negative', () => {
  const payment = new Payment({
    user: new mongoose.Types.ObjectId(),
    planId: 'premium',
    amountCents: -1,
  });

  assert.ok(payment.validateSync()?.errors.amountCents);
});

test('paidPlan excludes free and returns purchasable plans', () => {
  assert.equal(paidPlan('free'), undefined);
  assert.equal(paidPlan('premium')?.id, 'premium');
});
