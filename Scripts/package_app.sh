#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="AIUsageBar"
BIN_NAME="ai-usage-bar"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
BUILD_DIR="${PROJECT_DIR}/.build/release"

echo "Building ${APP_NAME} (release)..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary (renamed to match app bundle convention)
cp "${BUILD_DIR}/${BIN_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

# Copy app icon
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "App icon bundled."
fi

# Ad-hoc code sign
SIGNING="${CODEXBAR_SIGNING:-adhoc}"
if [ "$SIGNING" = "adhoc" ]; then
    echo "Ad-hoc signing..."
    codesign --force --sign - --entitlements /dev/stdin "$APP_BUNDLE" <<'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS
else
    echo "Signing with identity: ${SIGNING}"
    codesign --force --sign "$SIGNING" "$APP_BUNDLE"
fi

echo ""
echo "Done! App bundle created at:"
echo "  ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "To create a distributable zip:"
echo "  cd ${PROJECT_DIR} && zip -r ${APP_NAME}.app.zip ${APP_NAME}.app"
