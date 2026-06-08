import mongoose from 'mongoose';

const paymentSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    planId: {
      type: String,
      enum: ['premium', 'plus', 'linkx'],
      required: true,
    },
    amountCents: { type: Number, required: true, min: 0 },
    currency: { type: String, uppercase: true, default: 'INR' },
    provider: { type: String, default: 'mock' },
    providerReference: String,
    status: {
      type: String,
      enum: ['created', 'succeeded', 'failed', 'refunded'],
      default: 'created',
      index: true,
    },
  },
  { timestamps: true },
);

paymentSchema.index({ user: 1, createdAt: -1 });

export const Payment = mongoose.model('Payment', paymentSchema);
