#!/bin/sh
# Universal Release build and zip, signed ad hoc as the family's downloads
# are (no Developer ID yet, so no notarisation). Writes
# build/release/sPaste.app and build/release/sPaste-<version>.zip.
set -eu
VERSION=$(cat VERSION)
BUILD_NUMBER=$(git rev-list --count HEAD)
OUT=build/release

# A tag on HEAD must match VERSION, so a release never ships a stale number.
TAG=$(git tag --points-at HEAD | grep '^v' | head -1 || true)
if [ -n "$TAG" ] && [ "$TAG" != "v$VERSION" ]; then
    echo "release: HEAD is tagged $TAG but VERSION says $VERSION" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
APP="$OUT/sPaste.app" CONFIG=release FLAGS="--arch arm64 --arch x86_64" \
    VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" scripts/bundle.sh
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$OUT/sPaste.app" "$OUT/sPaste-$VERSION.zip"
echo "release: $(lipo -archs "$OUT/sPaste.app/Contents/MacOS/sPaste") $VERSION ($BUILD_NUMBER)"
shasum -a 256 "$OUT/sPaste-$VERSION.zip"
