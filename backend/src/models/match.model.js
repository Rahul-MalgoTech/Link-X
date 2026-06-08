import mongoose from 'mongoose';

const matchSchema = new mongoose.Schema(
  {
    users: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      required: true,
      validate: {
        validator: (users) => users.length === 2,
        message: 'A match must have exactly two users',
      },
    },
    participantKey: { type: String, required: true, unique: true, index: true },
    status: {
      type: String,
      enum: ['active', 'unmatched'],
      default: 'active',
      index: true,
    },
    matchedAt: { type: Date, default: Date.now },
    unmatchedAt: Date,
    unmatchedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

matchSchema.index({ users: 1, status: 1, matchedAt: -1 });

export const Match = mongoose.model('Match', matchSchema);
