import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

import { Otp } from '../models/otp.model.js';
import { User } from '../models/user.model.js';
import { asyncRoute } from '../utils/async-route.js';
import { validate } from '../utils/validate.js';

const router = express.Router();

const phoneSchema = z.object({
  countryCode: z.string().default('+91'),
  phoneNumber: z.string().trim().min(6).max(16),
});

const verifySchema = phoneSchema.extend({
  otp: z.string().trim().min(4).max(8),
});

router.post(
  '/request-otp',
  validate(phoneSchema),
  asyncRoute(async (req, res) => {
    const { countryCode, phoneNumber } = req.body;
    const code = process.env.DEV_OTP || '123456';
    const ttl = Number(process.env.OTP_TTL_MINUTES || 10);
    const codeHash = await bcrypt.hash(code, 10);

    await Otp.create({
      countryCode,
      phoneNumber,
      codeHash,
      expiresAt: new Date(Date.now() + ttl * 60 * 1000),
    });

    res.status(201).json({
      message: 'Dummy OTP generated',
      phoneNumber,
      countryCode,
      devOtp: code,
    });
  }),
);

router.post(
  '/verify-otp',
  validate(verifySchema),
  asyncRoute(async (req, res) => {
    const { countryCode, phoneNumber, otp } = req.body;
    const dummyOtp = process.env.DEV_OTP || '123456';

    if (otp !== dummyOtp) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    const record = await Otp.findOne({
      phoneNumber,
      consumedAt: null,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    if (record) {
      record.attempts += 1;
      const valid = await bcrypt.compare(otp, record.codeHash);
      if (!valid) {
        await record.save();
        return res.status(400).json({ message: 'Invalid OTP' });
      }

      record.consumedAt = new Date();
      await record.save();
    }

    const user = await User.findOneAndUpdate(
      { phoneNumber },
      {
        $setOnInsert: { countryCode, phoneNumber, onboardingStep: 'name' },
        $set: { isPhoneVerified: true },
      },
      { new: true, upsert: true },
    );

    const token = jwt.sign(
      { sub: user._id.toString(), phoneNumber },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: '30d' },
    );

    res.json({
      message: 'OTP verified',
      token,
      user,
      nextStep: user.onboardingComplete ? 'home' : user.onboardingStep,
    });
  }),
);

export default router;
