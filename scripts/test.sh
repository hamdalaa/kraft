#!/bin/bash
# Swift Testing with Command Line Tools only (no Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."
CLT=/Library/Developer/CommandLineTools
FW=$CLT/Library/Developer/Frameworks
LIB=$CLT/Library/Developer/usr/lib
swift test \
  -Xswiftc -F -Xswiftc "$FW" \
  -Xlinker -F -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$LIB" \
  "$@"
