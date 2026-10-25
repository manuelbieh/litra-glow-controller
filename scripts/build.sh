#!/usr/bin/env bash
# Build, bundle, ad-hoc sign, and package the Litra Glow Controller as a DMG.
# Usage: scripts/build.sh [version] [--install]   (default version: 0.1.0)
# --install also copies the app to /Applications (or ~/Applications when /Applications isn't
# writable) and starts it.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="0.1.0"
INSTALL=false
for arg in "$@"; do
  case "${arg}" in
    --install) INSTALL=true ;;
    *) VERSION="${arg}" ;;
  esac
done
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP_NAME="LitraMenuBar"
BUNDLE_NAME="Litra Glow Controller"
BUNDLE="build/${APP_NAME}.app"
DMG="dist/LitraGlowController-${VERSION}.dmg"

echo "→ Building ${APP_NAME} ${VERSION} (build ${BUILD_NUMBER})"

rm -rf build dist
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources" dist

swift build -c release --arch arm64 --arch x86_64
cp ".build/apple/Products/Release/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"

sed \
  -e "s/__VERSION__/${VERSION}/g" \
  -e "s/__BUILD__/${BUILD_NUMBER}/g" \
  Resources/Info.plist.template > "${BUNDLE}/Contents/Info.plist"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "${BUNDLE}"

echo "→ Creating DMG"
STAGE="build/dmg"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp -R "${BUNDLE}" "${STAGE}/${BUNDLE_NAME}.app"
ln -s /Applications "${STAGE}/Applications"
hdiutil create -volname "${BUNDLE_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}" >/dev/null

echo "✓ ${DMG}"

if [[ "${INSTALL}" == true ]]; then
  # macOS 27 identifies the menu bar item of an app outside /Applications by its binary path,
  # and menu bar managers such as Bartender can't show or move such an item.
  DEST="/Applications"
  [[ -w "${DEST}" ]] || DEST="${HOME}/Applications"
  echo "→ Installing to ${DEST}"
  pkill -x "${APP_NAME}" || true
  mkdir -p "${DEST}"
  rm -rf "${DEST}/${BUNDLE_NAME}.app"
  cp -R "${BUNDLE}" "${DEST}/${BUNDLE_NAME}.app"
  open "${DEST}/${BUNDLE_NAME}.app"
  echo "✓ ${DEST}/${BUNDLE_NAME}.app"
fi
