#!/usr/bin/env bash
# usage: shots.sh <udid> <app path> <out dir> <label>
set -euo pipefail
udid=$1 app=$2 out=$3 label=$4 fx=$GITHUB_WORKSPACE/apps/ios/tests/fixtures
bid=ai.nuphos.ios
mkdir -p "$out"
xcrun simctl uninstall "$udid" "$bid" || true
xcrun simctl install "$udid" "$app"
shot() { xcrun simctl io "$udid" screenshot "$out/$1-$label.png"; }
run() { xcrun simctl terminate "$udid" "$bid" 2>/dev/null || true; xcrun simctl launch "$udid" "$bid" "$@"; }

SIMCTL_CHILD_NUPHOS_PREVIEW_RESPONSES=$fx/login-responses.json run -preview-login -preview-no-push
sleep 8; shot sign-in

run -shot-splash -preview-no-push
sleep 6; shot splash

run -clear-preview -preview-home -preview-consent -preview-no-push
sleep 8; shot ai-consent

SIMCTL_CHILD_NUPHOS_PREVIEW_RESPONSES=$GITHUB_WORKSPACE/scripts/scratch-4044/empty-team.json run -preview-home -preview-no-push
sleep 12; shot empty-state

SIMCTL_CHILD_NUPHOS_PREVIEW_RESPONSES=$GITHUB_WORKSPACE/scripts/scratch-4044/empty-team.json run -preview-home -preview-no-push -shot-activity
sleep 8
xcrun simctl launch "$udid" com.apple.Preferences
sleep 6; shot live-activity
xcrun simctl terminate "$udid" com.apple.Preferences || true
ls -la "$out"
