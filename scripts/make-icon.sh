#!/bin/bash
# Turn the 1024 px app icon PNG into Resources/AppIcon.icns.
# Usage: ./scripts/make-icon.sh            (uses Resources/AppIcon-1024.png, the designer's artwork)
#        ./scripts/make-icon.sh icon.png   (use another 1024 px PNG)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SRC=${1:-Resources/AppIcon-1024.png}

[ "$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/ {print $2}')" = 1024 ] || { echo "error: $SRC is not 1024 px wide" >&2; exit 1; }

SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$SRC" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
