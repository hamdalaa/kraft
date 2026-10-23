#!/bin/bash
# Renders every snapshot in English and Arabic (right to left), light and dark:
# snapshots/en/, snapshots/ar/, snapshots/en-dark/, snapshots/ar-dark/.
# Extra arguments go to the app, e.g. `./scripts/snapshots.sh -KraftDigits arabic`.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/Kraft.app/Contents/MacOS/Kraft
[ -x "$APP" ] || CONFIG=debug ./scripts/bundle.sh
for appearance in light dark; do
  for lang in en ar; do
    dir=$lang
    [ "$appearance" = dark ] && dir=$lang-dark
    rm -rf "snapshots/$dir"
    KRAFT_SNAPSHOT="$PWD/snapshots/$dir" "$APP" -ApplePersistenceIgnoreState YES -AppleLanguages "($lang)" \
      -KraftDigits western -KraftAppearance "$appearance" "$@" > /dev/null
    echo "snapshots/$dir: $(ls "snapshots/$dir" | wc -l | tr -d ' ') shots"
  done
done
