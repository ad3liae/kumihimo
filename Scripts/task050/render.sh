#!/bin/sh
# Task 050: draw the sixteen-thread flat braid as the app draws it, at fixed
# turns, and keep the screenshots.
#
#   sh Scripts/task050/render.sh <UDID> <app path> <out dir> <label>
#
# Uses the debug-only launch arguments of `YatsuKongoComparisonPreview.swift`
# (`--yatsu-kongo-recipe=hira`). Same camera, lights and material as the editor.
# COLOURINGS and ROLLS narrow the run. ZOOM (default 1) zooms in as a pinch
# would; NODETAIL=1 draws without the stripe and shading maps, to read the shape
# alone. CARD=1 draws the list's card instead of the solid. The file name carries
# the lot: <label>-<colouring>-roll<deg>[-zoom<z>][-nodetail][-card].png.
#
# **The roll is what shows the edge.** 0 is the broad face square on; 60 turns
# the braid until one edge stands out against the background, which is the angle
# Task 050 asks for the edge to be read at. Nothing here changes the device's
# environment.
set -eu
UDID=$1; APP=$2; OUT=$3; LABEL=$4
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
ZOOM=${ZOOM:-1}
SUFFIX=""; EXTRA=""
[ "$ZOOM" != "1" ] && SUFFIX="$SUFFIX-zoom$ZOOM"
[ "${NODETAIL:-0}" = "1" ] && SUFFIX="$SUFFIX-nodetail" && EXTRA="--yatsu-kongo-no-detail"
SCREEN="--ui-testing-yatsu-kongo-solid"
[ "${CARD:-0}" = "1" ] && SCREEN="--ui-testing-yatsu-kongo-card" && SUFFIX="$SUFFIX-card"
mkdir -p "$OUT"
xcrun simctl install "$UDID" "$APP"
shot() {
  name=$1; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep "${WAIT:-5}"
  xcrun simctl io "$UDID" screenshot "$OUT/$LABEL-$name.png" >/dev/null 2>&1
}
for colouring in ${COLOURINGS:-plain weft arrow}; do
  for roll in ${ROLLS:-0 60}; do
    shot "$colouring-roll$roll$SUFFIX" "$SCREEN" \
      --yatsu-kongo-recipe=hira "--yatsu-kongo-colouring=$colouring" \
      "--yatsu-kongo-roll=$roll" "--yatsu-kongo-zoom=$ZOOM" $EXTRA
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
