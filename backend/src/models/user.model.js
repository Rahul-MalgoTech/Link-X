import mongoose from 'mongoose';

const photoSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    publicId: String,
    originalName: String,
    mimeType: String,
    size: Number,
  },
  { _id: false },
);

const userSchema = new mongoose.Schema(
  {
    countryCode: { type: String, default: '+91' },
    phoneNumber: { type: String, required: true, unique: true, index: true },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
      index: true,
    },
    isPhoneVerified: { type: Boolean, default: false },
    firstName: String,
    bio: { type: String, trim: true, maxlength: 500, default: '' },
    identity: { type: String, enum: ['Him', 'Her', 'Other', null], default: null },
    birthDate: Date,
    showStarOnProfile: { type: Boolean, default: true },
    heightCm: Number,
    educationLevel: String,
    lookingFor: String,
    happiness: [String],
    children: String,
    smoking: String,
    location: {
      label: String,
      latitude: Number,
      longitude: Number,
    },
    photos: [photoSchema],
    privacySettings: {
      discoverable: { type: Boolean, default: true },
      showOnlineStatus: { type: Boolean, default: true },
      showDistance: { type: Boolean, default: true },
      showAge: { type: Boolean, default: true },
    },
    notificationSettings: {
      newMatches: { type: Boolean, default: true },
      messages: { type: Boolean, default: true },
      likes: { type: Boolean, default: true },
      calls: { type: Boolean, default: true },
    },
    onboardingStep: { type: String, default: 'phone' },
    onboardingComplete: { type: Boolean, default: false },
  },
  { timestamps: true },
);

export const User = mongoose.model('User', userSchema);
