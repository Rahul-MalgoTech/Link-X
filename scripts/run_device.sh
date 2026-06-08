#!/usr/bin/env bash
set -euo pipefail

PORT="${LINKX_BACKEND_PORT:-4001}"

if command -v ipconfig >/dev/null 2>&1; then
  LAN_IP="$(ipconfig getifaddr en0 || true)"
  if [ -z "${LAN_IP}" ]; then
    LAN_IP="$(ipconfig getifaddr en1 || true)"
  fi
else
  LAN_IP=""
fi

if [ -z "${LAN_IP}" ]; then
  LAN_IP="$(ifconfig | awk '/inet / && $2 !~ /^127\\./ { print $2; exit }')"
fi

if [ -z "${LAN_IP}" ]; then
  echo "Could not detect your Mac LAN IP. Set LINKX_API_BASE_URL manually."
  exit 1
fi

API_URL="http://${LAN_IP}:${PORT}/api"
echo "Running Linkx with backend: ${API_URL}"
flutter run --dart-define="LINKX_API_BASE_URL=${API_URL}" "$@"
