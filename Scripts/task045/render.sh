#!/bin/sh
# Task 045: draw the eight-thread tube as the app draws it, at fixed turns, and
# keep the screenshots. Reproduces the A/B/C comparison images.
#
#   sh Scripts/task045/render.sh <UDID> <app path> <out dir> <label>
#
# For each braid (s, z), colouring (plain, book, eight) and turn (0 30 60 90
# 180 270 degrees) it launches the app with the debug-only launch arguments of
# `YatsuKongoComparisonPreview.swift` and screenshots the simulator. Also the
# card, once per braid and colouring. Nothing here changes the device's
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
for recipe in ${RECIPES:-s z}; do
  for colouring in ${COLOURINGS:-plain book eight}; do
    for roll in ${ROLLS:-0 30 60 90 180 270}; do
      shot "$recipe-$colouring-roll$roll" --ui-testing-yatsu-kongo-solid \
        "--yatsu-kongo-recipe=$recipe" "--yatsu-kongo-colouring=$colouring" \
        "--yatsu-kongo-roll=$roll"
    done
    shot "$recipe-$colouring-card" --ui-testing-yatsu-kongo-card \
      "--yatsu-kongo-recipe=$recipe" "--yatsu-kongo-colouring=$colouring"
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
