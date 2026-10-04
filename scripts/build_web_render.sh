#!/usr/bin/env bash
# Build Flutter Web for Render (or any static host).
# Requires public Supabase compile-time defines only.
#
# Render Dashboard must use THIS script as Build Command:
#   bash scripts/build_web_render.sh
# Do NOT use an inline `git clone ... flutter` one-liner — cached SDK dirs break it.
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

# Resolve Flutter SDK (reuse cache when present).
ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return 0
  fi

  local candidates=(
    "${FLUTTER_ROOT:-}"
    "${HOME}/flutter"
    "/opt/render/flutter"
    "${HOME}/.flutter"
  )

  local dir
  for dir in "${candidates[@]}"; do
    if [[ -n "$dir" && -x "${dir}/bin/flutter" ]]; then
      export PATH="${dir}/bin:${PATH}"
      return 0
    fi
  done

  local install_dir="${FLUTTER_ROOT:-${HOME}/flutter}"
  if [[ -d "$install_dir" && ! -x "${install_dir}/bin/flutter" ]]; then
    echo "Removing incomplete Flutter directory at ${install_dir}"
    rm -rf "$install_dir"
  fi
  if [[ ! -x "${install_dir}/bin/flutter" ]]; then
    echo "Cloning Flutter stable into ${install_dir}"
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$install_dir"
  fi
  export PATH="${install_dir}/bin:${PATH}"
}

ensure_flutter

flutter --version
flutter config --no-analytics
flutter config --enable-web
flutter pub get

flutter build web --release --no-pub \
  --dart-define="APP_ENV=${APP_ENV_VALUE}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${PUBLISHABLE_KEY}"

cp -f build/web/index.html build/web/404.html

echo "Web build complete: build/web (APP_ENV=${APP_ENV_VALUE})"
