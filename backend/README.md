# Linkx Backend

Node.js + Express + MongoDB backend for the Linkx login/onboarding flow.

## Setup

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

The API runs on `http://localhost:4001` with the current `.env`.

## MongoDB Setup

Local connection string:

```env
MONGODB_URI=mongodb://127.0.0.1:27017/linkx
```

If `npm run dev` shows `ECONNREFUSED 127.0.0.1:27017`, MongoDB is not running.

On macOS with Homebrew:

```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

If Homebrew says your Command Line Tools are outdated, update them first:

```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

Then run the MongoDB install commands again.

Alternative: use MongoDB Atlas and set:

```env
MONGODB_URI=mongodb+srv://USERNAME:PASSWORD@CLUSTER_NAME.mongodb.net/linkx?retryWrites=true&w=majority
```

For Android emulator use `http://10.0.2.2:4001/api`.
For a real Android device, use your computer LAN IP, for example `http://192.168.1.10:4001/api`.

## Login Flow APIs

- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`
- `GET /api/onboarding/me`
- `PATCH /api/onboarding/me`
- `POST /api/onboarding/photos`
- `POST /api/onboarding/complete`

## Real-Time Chat

Chat uses the same JWT returned by `POST /api/auth/verify-otp`.

- Socket.IO URL: `http://localhost:4001`
- Socket auth: `{ "token": "JWT_TOKEN" }`
- Send event: `chat:send`
- Receive event: `chat:message`
- `GET /api/chat/conversations`
- `GET /api/chat/messages/:userId`
- `POST /api/chat/messages` (HTTP fallback)

Messages and conversation summaries are stored in MongoDB. Run two signed-in
clients with different phone numbers to test real-user messaging.

Chat and calls are available only while an active match exists.

## Matching APIs

- `POST /api/matching/like/:userId`
- `POST /api/matching/pass/:userId`
- `GET /api/matching/matches`
- `GET /api/matching/status/:userId`
- `DELETE /api/matching/matches/:userId`
- `POST /api/matching/block/:userId`
- `DELETE /api/matching/block/:userId`
- `POST /api/matching/report/:userId`
- `POST /api/matching/call-authorize/:userId`

Discovery supports `page`, `limit`, `identity`, `minAge`, `maxAge`,
`maxDistance`, `search`, `lookingFor`, and `excludeReacted` query parameters.

## Dummy OTP Login

Right now the backend uses a dummy OTP only. No SMTP/SMS provider is connected yet.

Default OTP:

```text
123456
```

Configured in `.env`:

```env
DEV_OTP=123456
```

`POST /api/auth/request-otp` creates an OTP record and returns `devOtp` in the response. Later, when SMTP/SMS is added, replace this dummy generation inside `backend/src/routes/auth.routes.js`.

## Admin Event Panel

Add one or more admin phone numbers to `backend/.env`:

```env
ADMIN_PHONE_NUMBERS=9876543210
```

Multiple numbers can be comma-separated. Restart the backend, then open:

```text
http://localhost:4001/admin/
```

Sign in using a configured admin phone number and the development OTP.
Admins can create, edit, republish, and cancel events. Event-management API
routes return `403` for normal users.

## Cloudinary Profile Photos

Profile photo upload uses Cloudinary. Add these values in `backend/.env`:

```env
CLOUDINARY_CLOUD_NAME=dpsm1o46c
CLOUDINARY_API_KEY=h8Tnpf_y-L3eVW31cjRpKNARBB0
CLOUDINARY_API_SECRET=your-cloudinary-api-secret
```

Do not put the API secret in Flutter. The Flutter app uploads profile images to the backend, and the backend uploads them to Cloudinary and stores the returned `secure_url` in MongoDB.
