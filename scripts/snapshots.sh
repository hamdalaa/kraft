#!/bin/bash
# Renders every snapshot in English (snapshots/en/) and Arabic, right to left (snapshots/ar/).
# Extra arguments go to the app, e.g. `./scripts/snapshots.sh -KraftDigits arabic`.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/Kraft.app/Contents/MacOS/Kraft
[ -x "$APP" ] || CONFIG=debug ./scripts/bundle.sh
for lang in en ar; do
  rm -rf "snapshots/$lang"
  KRAFT_SNAPSHOT="$PWD/snapshots/$lang" "$APP" -ApplePersistenceIgnoreState YES -AppleLanguages "($lang)" \
    -KraftDigits western "$@" > /dev/null
  echo "snapshots/$lang: $(ls "snapshots/$lang" | wc -l | tr -d ' ') shots"
done
