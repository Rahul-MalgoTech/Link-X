import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import mongoose from 'mongoose';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from 'socket.io';

import authRoutes from './routes/auth.routes.js';
import billingRoutes from './routes/billing.routes.js';
import chatRoutes from './routes/chat.routes.js';
import eventRoutes from './routes/event.routes.js';
import matchingRoutes from './routes/matching.routes.js';
import notificationRoutes from './routes/notification.routes.js';
import onboardingRoutes from './routes/onboarding.routes.js';
import roomRoutes from './routes/room.routes.js';
import usersRoutes from './routes/users.routes.js';
import { registerChatSocket } from './socket/chat.socket.js';

const app = express();
const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' },
});
const port = process.env.PORT || 4000;
const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/linkx';
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsDir = path.join(__dirname, '..', 'uploads', 'profile');
const adminDir = path.join(__dirname, '..', 'admin');

fs.mkdirSync(uploadsDir, { recursive: true });

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: {
      directives: {
        imgSrc: ["'self'", 'data:', 'https:'],
      },
    },
  }),
);
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('dev'));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
app.use('/admin', express.static(adminDir));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'linkx-backend' });
});

app.use('/api/auth', authRoutes);
app.use('/api/billing', billingRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/matching', matchingRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/onboarding', onboardingRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/users', usersRoutes);
app.set('io', io);
registerChatSocket(io);

app.use((req, res) => {
  res.status(404).json({ message: `Route not found: ${req.method} ${req.path}` });
});

app.use((error, _req, res, _next) => {
  const status = error.status || 500;
  res.status(status).json({
    message: error.message || 'Internal server error',
    details: error.details,
  });
});

try {
  await mongoose.connect(mongoUri);
  console.log(`MongoDB connected: ${mongoose.connection.name}`);
} catch (error) {
  console.error('\nMongoDB connection failed.');
  console.error(`Tried: ${mongoUri}`);
  console.error(
    'Start MongoDB locally, or set MONGODB_URI in backend/.env to a MongoDB Atlas connection string.\n',
  );
  throw error;
}

httpServer.listen(port, () => {
  console.log(`Linkx backend listening on http://localhost:${port}`);
});
