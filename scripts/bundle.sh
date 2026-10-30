#!/bin/sh
# Wrap the SPM-built sPaste executable into build/sPaste.app with an ad hoc
# signature.
set -eu

SWIFT=${SWIFT:-swift}
VERSION=${VERSION:-0.0.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
CONFIG=${CONFIG:-debug}
APP=${APP:-build/sPaste.app}
# extra build flags, such as the two --arch flags of a universal release
FLAGS=${FLAGS:-}

sh -c "$SWIFT build -c $CONFIG $FLAGS --product sPaste"
BIN_DIR=$(sh -c "$SWIFT build -c $CONFIG $FLAGS --show-bin-path")

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/sPaste" "$APP/Contents/MacOS/sPaste"
sed \
    -e "s/\$(EXECUTABLE_NAME)/sPaste/" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/io.github.usuite.spaste/" \
    -e "s/\$(MARKETING_VERSION)/$VERSION/" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD_NUMBER/" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP" >/dev/null
echo "built $APP $VERSION ($BUILD_NUMBER)"
