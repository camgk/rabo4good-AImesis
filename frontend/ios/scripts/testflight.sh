#!/usr/bin/env bash
# Build the AImesis family app and upload it to App Store Connect / TestFlight.
# Run on the Mac, from frontend/ios:
#
#   API_URL=https://mock-api-xxxx.europe-west1.run.app TEAM_ID=ABCDE12345 scripts/testflight.sh
#   scripts/testflight.sh <API_URL> <TEAM_ID> [BUILD_NUMBER]
#
# Needs: Xcode signed in to an Apple ID of team TEAM_ID (Xcode > Settings > Accounts),
#        an App Store Connect app record for bundle id be.hackingforgood.aimesis.family.
# Optional (headless upload with an App Store Connect API key instead of the Xcode account):
#        ASC_KEY_PATH=/path/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER_ID=uuid
set -euo pipefail

cd "$(dirname "$0")/.."   # frontend/ios

API_URL="${1:-${API_URL:-}}"
TEAM_ID="${2:-${TEAM_ID:-}}"
BUILD_NUMBER="${3:-${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}}"
FLUTTER="${FLUTTER:-flutter}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -z "$API_URL" || -z "$TEAM_ID" ]]; then
  echo "usage: API_URL=https://... TEAM_ID=XXXXXXXXXX $0   (or: $0 <API_URL> <TEAM_ID> [BUILD_NUMBER])" >&2
  exit 64
fi
if [[ "$API_URL" != https://* ]]; then
  echo "warning: API_URL is not https — iOS App Transport Security will block it on a real phone." >&2
fi

echo "==> AImesis family app"
echo "    API_URL      $API_URL"
echo "    TEAM_ID      $TEAM_ID"
echo "    BUILD_NUMBER $BUILD_NUMBER"
echo "    Xcode        $DEVELOPER_DIR"

# 1. Put the team into the Xcode project (Runner target, all configurations) so
#    Xcode and `flutter` both see it. Idempotent.
PBX=ios/Runner.xcodeproj/project.pbxproj
if grep -q "DEVELOPMENT_TEAM = " "$PBX"; then
  sed -i '' -E "s/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$PBX"
else
  sed -i '' -E "s/^([[:space:]]*)PRODUCT_BUNDLE_IDENTIFIER = be\.hackingforgood\.aimesis\.family;/\1DEVELOPMENT_TEAM = $TEAM_ID;\\
\1PRODUCT_BUNDLE_IDENTIFIER = be.hackingforgood.aimesis.family;/" "$PBX"
fi

# 2. Flutter build (Dart AOT + SPM plugin package + Generated.xcconfig with the
#    dart-defines and build number). No signing here.
"$FLUTTER" config --enable-swift-package-manager >/dev/null
"$FLUTTER" pub get
"$FLUTTER" build ios --release --no-codesign \
  --dart-define=API_URL="$API_URL" \
  --build-number="$BUILD_NUMBER"

# 3. Archive with automatic signing (lets Xcode create the App ID / profiles).
if [[ -d ios/Runner.xcworkspace ]]; then
  CONTAINER=(-workspace ios/Runner.xcworkspace)
else
  CONTAINER=(-project ios/Runner.xcodeproj)
fi

AUTH=()
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

ARCHIVE=build/ios/Runner.xcarchive
rm -rf "$ARCHIVE" build/ios/export
xcodebuild "${CONTAINER[@]}" \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  archive

# 4. Export + upload straight to App Store Connect (destination=upload).
EXPORT_PLIST=build/ios/ExportOptions.plist
sed "s/__TEAM_ID__/$TEAM_ID/" scripts/ExportOptions.plist > "$EXPORT_PLIST"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath build/ios/export \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

echo
echo "==> Uploaded build $BUILD_NUMBER of be.hackingforgood.aimesis.family."
echo "    It shows up in App Store Connect > TestFlight after processing (usually 5–15 min)."
