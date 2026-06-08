# bossy

## Run on a real phone

Start the backend first:

```bash
cd backend
npm run dev
```

Then run the app on a physical device with your Mac LAN IP:

```bash
bash scripts/run_device.sh
```

Your phone and Mac must be on the same WiFi, and macOS Firewall must allow
incoming connections to port `4001`.

For an Android emulator, use:

```bash
flutter run --dart-define=LINKX_API_BASE_URL=http://10.0.2.2:4001/api
```

The checked-in development default currently points to
`http://192.168.1.35:4001/api` for physical-device testing on this WiFi.
If your Mac IP changes, run `bash scripts/run_device.sh` or update
`LINKX_API_BASE_URL`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
