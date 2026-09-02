#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/Verbatim.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp ".build/release/VerbatimMac" "$CONTENTS_DIR/MacOS/Verbatim"
cp "$PROJECT_DIR/scripts/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
