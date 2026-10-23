#!/bin/bash
# Build Kraft.app: compile, assemble bundle, Info.plist, fonts, ad-hoc sign.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-release}
APP=build/Kraft.app

swift build -c "$CONFIG" --product Kraft
BIN=$(swift build -c "$CONFIG" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"
cp "$BIN/Kraft" "$APP/Contents/MacOS/Kraft"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"

# Molhim's licence forbids redistribution: it lives git-ignored and is only copied into local builds.
# KRAFT_PUBLIC=1 builds a redistributable app without it.
if [ -z "${KRAFT_PUBLIC:-}" ] && [ -f Resources/PrivateFonts/Molhim.ttf ]; then
  cp Resources/PrivateFonts/Molhim.ttf "$APP/Contents/Resources/Fonts/"
else
  echo "warning: Resources/PrivateFonts/Molhim.ttf missing — Arabic handwriting falls back to Playpen" >&2
fi

# Localizations (*.lproj) and the app icon, when present.
for l in Resources/Localization/*.lproj; do [ -d "$l" ] && cp -R "$l" "$APP/Contents/Resources/"; done
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

SHORT_VERSION=$(cat VERSION 2>/dev/null || echo 0.1)   # what the updater compares with GitHub releases (vX.Y.Z)
VERSION=$(git describe --tags --always 2>/dev/null || echo "$SHORT_VERSION")
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.hamdalaa.kraft</string>
  <key>CFBundleName</key><string>Kraft</string>
  <key>CFBundleDisplayName</key><string>Kraft</string>
  <key>CFBundleExecutable</key><string>Kraft</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${SHORT_VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ar</string></array>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Kraft — MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc signature with the hardened runtime.
codesign --force --deep --options runtime --sign - "$APP"
echo "built $APP"
