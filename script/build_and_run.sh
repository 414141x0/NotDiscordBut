#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PREVIEW_DATA="${2:-}"
APP_NAME="NotDiscordButMac"
BUNDLE_ID="disc.notdiscordbut.mac"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE_DIR="$ROOT_DIR/.build/ModuleCache.noindex"

swift_build() {
  env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swift build \
    --package-path "$ROOT_DIR" \
    --cache-path "$ROOT_DIR/.swiftpm/cache" \
    --config-path "$ROOT_DIR/.swiftpm/config" \
    --security-path "$ROOT_DIR/.swiftpm/security" \
    --scratch-path "$ROOT_DIR/.build" \
    "$@"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift_build --product "$APP_NAME"
BUILD_BINARY="$(swift_build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  if [[ "$PREVIEW_DATA" == "--preview-data" ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args --preview-data
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify] [--preview-data]" >&2
    exit 2
    ;;
esac
