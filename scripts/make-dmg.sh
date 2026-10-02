#!/bin/bash
# make-dmg.sh
#
# Packages the installed Plic.app into a notarized, stapled disk image.
#
# The app must already be installed by scripts/install-release.sh — this
# packages what was verified there rather than building its own copy, so what
# ships is what was checked.
#
# Order matters. The app is notarized and stapled FIRST, then sealed into the
# image, then the image is notarized and stapled in turn. Notarizing only the
# image leaves the ticket on the container: Gatekeeper accepts the download,
# but once the app is dragged out it has no ticket of its own and has to ask
# Apple over the network. Stapling both makes the app verifiable offline,
# which is the state it will spend most of its life in.
#
# Credentials: the `notarytool` keychain profile named below, or the one in
# NOTARY_PROFILE. Create it once with `xcrun notarytool store-credentials`,
# from an App Store Connect API key; the key then lives in the Keychain.

set -euo pipefail

PROFILE="${NOTARY_PROFILE:-dfmg}"
IDENTITY="Developer ID Application: Denis Florent Media Group SRL (7SM2WF75M4)"
APP="/Applications/Plic.app"

[ -d "$APP" ] || { echo "FAIL: $APP not installed — run scripts/install-release.sh first"; exit 1; }
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
  || { echo "FAIL: no working notarytool profile \"$PROFILE\" — create it with: xcrun notarytool store-credentials \"$PROFILE\""; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
BUILD=$(/usr/bin/plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")
OUT="${1:-$REPO/.dist/Plic.dmg}"
mkdir -p "$(dirname "$OUT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; hdiutil detach "/Volumes/Plic" -quiet 2>/dev/null || true' EXIT

echo "==> Plic $VERSION ($BUILD)"

STAGE="$WORK/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"

echo "==> Notarizing the app"
ditto -c -k --keepParent "$STAGE/Plic.app" "$WORK/Plic.zip"
xcrun notarytool submit "$WORK/Plic.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$STAGE/Plic.app"
xcrun stapler validate "$STAGE/Plic.app"

# The link is the whole instruction the window needs to give.
ln -s /Applications "$STAGE/Applications"

echo "==> Building the image"
hdiutil create -quiet -srcfolder "$STAGE" -volname "Plic" -fs HFS+ \
    -format UDZO -imagekey zlib-level=9 -ov "$OUT"

# Signing the image too: a signed app inside an unsigned container is judged
# by the container first.
codesign --sign "$IDENTITY" --timestamp "$OUT"

echo "==> Notarizing the image"
xcrun notarytool submit "$OUT" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$OUT"

echo "==> Verifying what will actually be downloaded"
spctl --assess --type open --context context:primary-signature "$OUT" \
  || { echo "FAIL: Gatekeeper rejects the image"; exit 1; }
MOUNT="$(hdiutil attach -nobrowse -readonly "$OUT" | grep -o '/Volumes/.*' | head -1)"
spctl --assess --type execute "$MOUNT/Plic.app" || { echo "FAIL: Gatekeeper rejects the app"; exit 1; }
xcrun stapler validate "$MOUNT/Plic.app" || { echo "FAIL: app inside carries no ticket"; exit 1; }
INNER=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$MOUNT/Plic.app/Contents/Info.plist")
hdiutil detach "$MOUNT" -quiet
[ "$INNER" = "$VERSION" ] || { echo "FAIL: image holds $INNER, expected $VERSION"; exit 1; }

# The copy in /Applications is byte-identical to the one just notarized, so
# the same ticket applies to it. install-release.sh cannot staple on its own —
# nothing is notarized at that point — which left the installed app asking
# Apple over the network on every launch. Stapling here is free and makes the
# build you actually use verifiable offline, like the one being shipped.
xcrun stapler staple "$APP" >/dev/null 2>&1 \
  && codesign --verify --strict "$APP" \
  && echo "==> Stapled the installed copy too" \
  || echo "WARN: could not staple $APP — it will verify online instead"

echo "==> $OUT  ($(du -h "$OUT" | cut -f1))  notarized, stapled, Gatekeeper-clean"
