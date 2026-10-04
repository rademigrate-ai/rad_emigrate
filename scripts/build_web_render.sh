#!/usr/bin/env bash
# Build Flutter Web for Render (or any static host).
# Requires public Supabase compile-time defines only.
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "ERROR: SUPABASE_URL is required (public project URL)." >&2
  exit 1
fi
if [[ -z "${SUPABASE_PUBLISHABLE_KEY:-}${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: SUPABASE_PUBLISHABLE_KEY (or legacy SUPABASE_ANON_KEY) is required." >&2
  exit 1
fi

PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-$SUPABASE_ANON_KEY}"
APP_ENV_VALUE="${APP_ENV:-staging}"

# Install Flutter if not already on PATH (Render static build environment).
if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="${FLUTTER_ROOT:-$HOME/flutter}"
  if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter --version
flutter config --no-analytics
flutter pub get

flutter build web --release --no-pub \
  --dart-define="APP_ENV=${APP_ENV_VALUE}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${PUBLISHABLE_KEY}"

# SPA fallback helpers for hosts that serve 404.html on unknown paths.
cp -f build/web/index.html build/web/404.html

echo "Web build complete: build/web (APP_ENV=${APP_ENV_VALUE})"
