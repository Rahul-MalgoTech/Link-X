import jwt from 'jsonwebtoken';
import { User } from '../models/user.model.js';

export async function requireAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      const error = new Error('Missing bearer token');
      error.status = 401;
      throw error;
    }

    const payload = jwt.verify(token, process.env.JWT_SECRET || 'dev-secret');
    const user = await User.findById(payload.sub);
    if (!user) {
      const error = new Error('User not found');
      error.status = 401;
      throw error;
    }

    req.user = user;
    next();
  } catch (error) {
    error.status = error.status || 401;
    next(error);
  }
}

export function isAdminUser(user) {
  if (user?.role === 'admin') return true;
  const configuredPhones = (process.env.ADMIN_PHONE_NUMBERS || '')
    .split(',')
    .map((phone) => phone.replace(/[^\d+]/g, '').trim())
    .filter(Boolean);
  const phone = String(user?.phoneNumber || '').replace(/[^\d+]/g, '');
  const fullPhone = `${user?.countryCode || ''}${phone}`.replace(
    /[^\d+]/g,
    '',
  );
  return configuredPhones.includes(phone) || configuredPhones.includes(fullPhone);
}

export function requireAdmin(req, _res, next) {
  if (isAdminUser(req.user)) return next();
  const error = new Error('Admin access required');
  error.status = 403;
  next(error);
}
