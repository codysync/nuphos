#!/bin/bash
# Runs on the MacBook: clone/update codysync/nuphos@oracle, archive apps/ios with automatic signing
# (team K5AYLYH9GW, ASC key from ~/.config/t3josh/ios.env, key file never printed), export an ad hoc
# (release-testing) IPA, check the device UDID is in every embedded profile.
# Usage: ios-build-mac.sh UDID   -> prints IPA path last.
set -euo pipefail
UDID="${1:?udid}"
ROOT="$HOME/nuphos-build"; SRC="$ROOT/src"; OUT="$ROOT/out/$(date -u +%Y%m%d%H%M)"
mkdir -p "$ROOT" "$OUT"
if [ -d "$SRC/.git" ]; then git -C "$SRC" fetch -q origin oracle && git -C "$SRC" reset -q --hard origin/oracle
else git clone -q --depth 1 -b oracle https://github.com/codysync/nuphos "$SRC"; fi
ENV_FILE="$HOME/.config/t3josh/ios.env"
KID="$(sed -n 's/^ASC_KEY_ID=["'\'']*\([A-Z0-9]*\).*/\1/p' "$ENV_FILE")"
ISS="$(sed -n 's/^ASC_ISSUER_ID=["'\'']*\([0-9a-f-]*\).*/\1/p' "$ENV_FILE")"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KID}.p8"
[ -n "$KID" ] && [ -n "$ISS" ] && [ -f "$KEY" ] || { echo "ASC key missing"; exit 2; }
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID "$KID" -authenticationKeyIssuerID "$ISS")
BUILD="$(date -u +%Y%m%d%H%M)"
cd "$SRC/apps/ios"
xcodebuild -project nuphos-ios.xcodeproj -scheme nuphos-ios -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/OracleBots.xcarchive" \
  -derivedDataPath "$ROOT/DerivedData" "${AUTH[@]}" \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=K5AYLYH9GW PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_IDENTITY="Apple Development" \
  CURRENT_PROJECT_VERSION="$BUILD" archive >"$OUT/archive.log" 2>&1 || { tail -60 "$OUT/archive.log"; exit 3; }
cat >"$OUT/ExportOptions.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>release-testing</string>
<key>destination</key><string>export</string>
<key>teamID</key><string>K5AYLYH9GW</string>
<key>signingStyle</key><string>automatic</string>
<key>thinning</key><string>&lt;none&gt;</string>
</dict></plist>
PL
xcodebuild -exportArchive -archivePath "$OUT/OracleBots.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" "${AUTH[@]}" >"$OUT/export.log" 2>&1 || { tail -60 "$OUT/export.log"; exit 4; }
IPA="$(find "$OUT/export" -maxdepth 1 -name '*.ipa' -print -quit)"
CHK="$OUT/check"; mkdir -p "$CHK"; unzip -q "$IPA" 'Payload/*' -d "$CHK"
APP="$(find "$CHK/Payload" -maxdepth 1 -name '*.app' -print -quit)"
for p in "$APP/embedded.mobileprovision" "$APP"/PlugIns/*.appex/embedded.mobileprovision; do
  security cms -D -i "$p" 2>/dev/null | grep -q "$UDID" || { echo "UDID missing from $p"; exit 5; }
  echo "profile ok: ${p#$CHK/}"
done
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"
echo "IPA=$IPA"
