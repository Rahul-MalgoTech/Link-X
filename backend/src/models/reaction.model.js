import mongoose from 'mongoose';

const reactionSchema = new mongoose.Schema(
  {
    actor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    target: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    action: {
      type: String,
      enum: ['like', 'pass'],
      required: true,
    },
  },
  { timestamps: true },
);

reactionSchema.index({ actor: 1, target: 1 }, { unique: true });

export const Reaction = mongoose.model('Reaction', reactionSchema);
