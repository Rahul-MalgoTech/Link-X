import mongoose from 'mongoose';

const conversationSchema = new mongoose.Schema(
  {
    participants: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      required: true,
      validate: {
        validator: (participants) => participants.length === 2,
        message: 'A conversation must have exactly two participants',
      },
    },
    participantKey: { type: String, required: true, unique: true, index: true },
    lastMessageText: { type: String, default: '' },
    lastMessageAt: Date,
    lastMessageSender: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

conversationSchema.index({ participants: 1, lastMessageAt: -1 });

export const Conversation = mongoose.model('Conversation', conversationSchema);
