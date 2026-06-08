import mongoose from 'mongoose';

const reportSchema = new mongoose.Schema(
  {
    reporter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    reported: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    reason: {
      type: String,
      enum: [
        'fake_profile',
        'harassment',
        'inappropriate_content',
        'spam',
        'underage',
        'other',
      ],
      required: true,
    },
    details: { type: String, trim: true, maxlength: 1000, default: '' },
    status: {
      type: String,
      enum: ['pending', 'reviewed', 'dismissed'],
      default: 'pending',
      index: true,
    },
  },
  { timestamps: true },
);

reportSchema.index({ reporter: 1, reported: 1, createdAt: -1 });

export const Report = mongoose.model('Report', reportSchema);
