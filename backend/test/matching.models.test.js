import assert from 'node:assert/strict';
import test from 'node:test';
import mongoose from 'mongoose';

import { Match } from '../src/models/match.model.js';
import { Reaction } from '../src/models/reaction.model.js';
import { Report } from '../src/models/report.model.js';
import { matchingPairKey } from '../src/services/matching.service.js';

test('matchingPairKey is stable regardless of user order', () => {
  const first = new mongoose.Types.ObjectId();
  const second = new mongoose.Types.ObjectId();

  assert.equal(
    matchingPairKey(first, second),
    matchingPairKey(second, first),
  );
});

test('reaction only accepts like or pass', () => {
  const reaction = new Reaction({
    actor: new mongoose.Types.ObjectId(),
    target: new mongoose.Types.ObjectId(),
    action: 'wave',
  });

  assert.ok(reaction.validateSync()?.errors.action);
});

test('match requires exactly two users', () => {
  const match = new Match({
    users: [new mongoose.Types.ObjectId()],
    participantKey: 'invalid',
  });

  assert.ok(match.validateSync()?.errors.users);
});

test('report rejects unsupported reasons', () => {
  const report = new Report({
    reporter: new mongoose.Types.ObjectId(),
    reported: new mongoose.Types.ObjectId(),
    reason: 'dislike',
  });

  assert.ok(report.validateSync()?.errors.reason);
});
