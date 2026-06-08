import mongoose from 'mongoose';

const attendeeSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    status: {
      type: String,
      enum: ['going', 'cancelled'],
      default: 'going',
    },
    rsvpedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const eventSchema = new mongoose.Schema(
  {
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, trim: true, maxlength: 2000, default: '' },
    venue: { type: String, trim: true, maxlength: 180, default: '' },
    coverImageUrl: { type: String, trim: true, default: '' },
    startAt: { type: Date, required: true, index: true },
    endAt: Date,
    capacity: { type: Number, min: 1, max: 100000, default: 100 },
    priceCents: { type: Number, min: 0, default: 0 },
    currency: { type: String, trim: true, uppercase: true, default: 'INR' },
    status: {
      type: String,
      enum: ['published', 'cancelled'],
      default: 'published',
      index: true,
    },
    attendees: {
      type: [attendeeSchema],
      default: [],
      validate: {
        validator(attendees) {
          const active = attendees
            .filter((attendee) => attendee.status === 'going')
            .map((attendee) => attendee.user.toString());
          return active.length === new Set(active).size;
        },
        message: 'Event attendees must be unique',
      },
    },
  },
  { timestamps: true },
);

eventSchema.index({ status: 1, startAt: 1 });
eventSchema.index({ 'attendees.user': 1, status: 1 });

export const Event = mongoose.model('Event', eventSchema);
