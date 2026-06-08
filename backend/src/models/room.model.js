import mongoose from 'mongoose';

const roomMemberSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    role: {
      type: String,
      enum: ['host', 'speaker', 'listener'],
      default: 'speaker',
    },
    joinedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const roomSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 80 },
    topic: { type: String, trim: true, maxlength: 180, default: '' },
    privacy: {
      type: String,
      enum: ['public', 'private'],
      required: true,
      index: true,
    },
    inviteCode: {
      type: String,
      trim: true,
      uppercase: true,
      minlength: 6,
      maxlength: 6,
      sparse: true,
      unique: true,
      index: true,
    },
    host: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    members: {
      type: [roomMemberSchema],
      default: [],
      validate: {
        validator(members) {
          const ids = members.map((member) => member.user.toString());
          return ids.length === new Set(ids).size;
        },
        message: 'Room members must be unique',
      },
    },
    maxParticipants: {
      type: Number,
      min: 2,
      max: 50,
      default: 12,
    },
    status: {
      type: String,
      enum: ['live', 'ended'],
      default: 'live',
      index: true,
    },
    zegoRoomId: { type: String, required: true, unique: true },
    endedAt: Date,
  },
  { timestamps: true },
);

roomSchema.index({ privacy: 1, status: 1, updatedAt: -1 });
roomSchema.index({ 'members.user': 1, status: 1 });

export const Room = mongoose.model('Room', roomSchema);
