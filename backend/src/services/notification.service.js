import { Notification } from '../models/notification.model.js';
import { User } from '../models/user.model.js';

const settingByType = {
  match: 'newMatches',
  message: 'messages',
  like: 'likes',
  call: 'calls',
};

export async function createNotification({
  io,
  userId,
  type,
  title,
  body,
  data = {},
}) {
  const user = await User.findById(userId).select('notificationSettings').lean();
  if (!user) return null;
  const setting = settingByType[type];
  if (setting && user.notificationSettings?.[setting] === false) return null;

  const notification = await Notification.create({
    user: userId,
    type,
    title,
    body,
    data,
  });
  const payload = serializeNotification(notification);
  io?.to(`user:${userId}`).emit('notification:new', payload);
  return payload;
}

export function serializeNotification(notification) {
  return {
    id: notification._id.toString(),
    type: notification.type,
    title: notification.title,
    body: notification.body,
    data: notification.data || {},
    readAt: notification.readAt || null,
    createdAt: notification.createdAt,
  };
}
