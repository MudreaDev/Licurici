#!/usr/bin/env bash
# Build-ul pe Vercel: instalează Flutter (aceeași versiune ca local), construiește panoul web
# (apps/dashboard) cu API-ul pe aceeași adresă (/api/v1) și îl pune în public/.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SDK="${FLUTTER_HOME:-$HOME/flutter-$FLUTTER_VERSION}"

# Imaginea de build Vercel (Amazon Linux 2023) poate să nu aibă unzip/xz, de care are nevoie Flutter.
for tool in unzip xz which; do
  if ! command -v "$tool" >/dev/null 2>&1 && command -v dnf >/dev/null 2>&1; then
    dnf install -y "$tool" >/dev/null 2>&1 || true
  fi
done

if [ ! -x "$SDK/bin/flutter" ]; then
  echo "Instalez Flutter $FLUTTER_VERSION…"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK"
fi
export PATH="$SDK/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter precache --web

cd "$ROOT/apps/dashboard"
flutter pub get
flutter build web --release \
  --dart-define=API_URL=/api/v1 \
  --dart-define=LIVE_POLL=true \
  --dart-define=THERAPIST_CHILDREN=true

# Panoul + paginile statice ale versiunii de test (legătura pentru părinte).
rm -rf "$HERE/public"
mkdir -p "$HERE/public"
cp -r build/web/. "$HERE/public/"
cp "$HERE/static/c.html" "$HERE/public/c.html"
# Vocea și muzica nu sunt folosite de panou (doar de aplicația copilului): build mai mic.
rm -rf "$HERE/public/assets/packages/game_content/audio"
echo "Gata: $(du -sh "$HERE/public" | cut -f1)"
