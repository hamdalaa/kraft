#!/bin/bash
# Render the app icon (snapshot shot `appicon-1024`) and turn it into Resources/AppIcon.icns.
# Usage: ./scripts/make-icon.sh            (builds a debug bundle first)
#        ./scripts/make-icon.sh icon.png   (use an existing 1024 px PNG)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  SRC=$1
else
  CONFIG=debug ./scripts/bundle.sh >/dev/null
  KRAFT_SNAPSHOT="$WORK/shots" build/Kraft.app/Contents/MacOS/Kraft -ApplePersistenceIgnoreState YES >/dev/null
  SRC="$WORK/shots/appicon-1024.png"
fi

[ "$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')" = 1024 ] || { echo "error: $SRC is not 1024 px wide" >&2; exit 1; }

SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$SRC" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
