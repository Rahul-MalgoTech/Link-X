import mongoose from 'mongoose';

const subscriptionSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    planId: {
      type: String,
      enum: ['free', 'premium', 'plus', 'linkx'],
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['active', 'cancelled', 'expired'],
      default: 'active',
      index: true,
    },
    startedAt: { type: Date, default: Date.now },
    expiresAt: Date,
    provider: { type: String, default: 'mock' },
    providerReference: String,
  },
  { timestamps: true },
);

subscriptionSchema.index({ user: 1, status: 1, expiresAt: -1 });

export const Subscription = mongoose.model(
  'Subscription',
  subscriptionSchema,
);
