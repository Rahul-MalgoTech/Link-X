import assert from 'node:assert/strict';
import test from 'node:test';
import mongoose from 'mongoose';

import { SupportRequest } from '../src/models/support-request.model.js';
import { User } from '../src/models/user.model.js';

test('new users receive privacy and notification defaults', () => {
  const user = new User({ phoneNumber: '9999999999' });

  assert.equal(user.privacySettings.discoverable, true);
  assert.equal(user.privacySettings.showOnlineStatus, true);
  assert.equal(user.notificationSettings.messages, true);
  assert.equal(user.notificationSettings.calls, true);
});

test('profile bio cannot exceed 500 characters', () => {
  const user = new User({
    phoneNumber: '8888888888',
    bio: 'x'.repeat(501),
  });

  assert.ok(user.validateSync()?.errors.bio);
});

test('support requests require a user, subject, and message', () => {
  const request = new SupportRequest({
    user: new mongoose.Types.ObjectId(),
    subject: '',
    message: '',
  });
  const errors = request.validateSync()?.errors;

  assert.ok(errors?.subject);
  assert.ok(errors?.message);
});
