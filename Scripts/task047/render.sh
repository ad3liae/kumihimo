#!/bin/sh
# Task 047: draw the sixteen-thread maru-genji as the app draws it, at fixed
# turns, and keep the screenshots.
#
#   sh Scripts/task047/render.sh <UDID> <app path> <out dir> <label>
#
# Uses the debug-only launch arguments of `YatsuKongoComparisonPreview.swift`
# (`--yatsu-kongo-recipe=maru`). Same camera, lights and material as the editor.
# COLOURINGS and ROLLS narrow the run. Nothing here changes the device's
# environment.
set -eu
UDID=$1; APP=$2; OUT=$3; LABEL=$4
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
mkdir -p "$OUT"
xcrun simctl install "$UDID" "$APP"
shot() {
  name=$1; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep "${WAIT:-4}"
  xcrun simctl io "$UDID" screenshot "$OUT/$LABEL-$name.png" >/dev/null 2>&1
}
for colouring in ${COLOURINGS:-plain blue fixture1}; do
  for roll in ${ROLLS:-0 45 90 180 270}; do
    shot "$colouring-roll$roll" --ui-testing-yatsu-kongo-solid \
      --yatsu-kongo-recipe=maru "--yatsu-kongo-colouring=$colouring" \
      "--yatsu-kongo-roll=$roll"
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
