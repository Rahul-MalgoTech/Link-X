import mongoose from 'mongoose';

const hostApplicationMediaSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    publicId: String,
    resourceType: {
      type: String,
      enum: ['image', 'video'],
      required: true,
    },
    originalName: String,
    mimeType: String,
    size: Number,
  },
  { _id: false },
);

const hostApplicationSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 80,
    },
    bio: {
      type: String,
      required: true,
      trim: true,
      maxlength: 800,
    },
    topics: [{ type: String, trim: true, maxlength: 80 }],
    languages: [{ type: String, trim: true, maxlength: 60 }],
    experience: {
      type: String,
      trim: true,
      maxlength: 1200,
      default: '',
    },
    media: hostApplicationMediaSchema,
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
      index: true,
    },
    adminNote: { type: String, trim: true, maxlength: 500, default: '' },
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    reviewedAt: Date,
  },
  { timestamps: true },
);

hostApplicationSchema.index({ user: 1, createdAt: -1 });
hostApplicationSchema.index({ status: 1, createdAt: -1 });

export const HostApplication = mongoose.model(
  'HostApplication',
  hostApplicationSchema,
);
