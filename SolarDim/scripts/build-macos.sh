#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release

APP="$ROOT/dist/SolarDim.app"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/release/SolarDim" "$APP/Contents/MacOS/SolarDim"
chmod +x "$APP/Contents/MacOS/SolarDim"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
# Ad-hoc sign for local use. No developer account required.
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
