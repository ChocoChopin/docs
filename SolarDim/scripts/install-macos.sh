#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/build-macos.sh"
mkdir -p "$HOME/Applications"
DEST="$HOME/Applications/SolarDim.app"
if [[ -d "$DEST" ]]; then
    osascript -e 'tell application "SolarDim" to quit' 2>/dev/null || true
    rm -rf "$DEST"
fi
ditto "$ROOT/dist/SolarDim.app" "$DEST"
open "$DEST"
echo "Installed and launched $DEST"
echo "Choose 'Start at Login' in the SolarDim menu if desired."
