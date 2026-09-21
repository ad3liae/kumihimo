#!/bin/sh
# Task 051: draw the eight-thread tube as the app draws it, at fixed turns, and
# keep the screenshots.
#
#   sh Scripts/task051/render.sh <UDID> <app path> <out dir> <label>
#
# Task 045's script with Task 050's switches: the debug-only launch arguments
# of `YatsuKongoComparisonPreview.swift`. RECIPES (s z), COLOURINGS (plain book
# author) and ROLLS (0 30) narrow the run. ZOOM zooms in as a pinch would;
# NODETAIL=1 draws without the stripe and shading maps, to read the shape
# alone. The card is drawn once per braid and colouring unless NOCARD=1.
# File names: <label>-<recipe>-<colouring>-roll<deg>[-zoom<z>][-nodetail].png
# and <label>-<recipe>-<colouring>-card.png. Nothing here changes the device's
# environment.
set -eu
UDID=$1; APP=$2; OUT=$3; LABEL=$4
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
ZOOM=${ZOOM:-1}
SUFFIX=""; EXTRA=""
[ "$ZOOM" != "1" ] && SUFFIX="$SUFFIX-zoom$ZOOM"
[ "${NODETAIL:-0}" = "1" ] && SUFFIX="$SUFFIX-nodetail" && EXTRA="--yatsu-kongo-no-detail"
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
for recipe in ${RECIPES:-s}; do
  for colouring in ${COLOURINGS:-plain book author}; do
    for roll in ${ROLLS:-0 30}; do
      shot "$recipe-$colouring-roll$roll$SUFFIX" --ui-testing-yatsu-kongo-solid \
        "--yatsu-kongo-recipe=$recipe" "--yatsu-kongo-colouring=$colouring" \
        "--yatsu-kongo-roll=$roll" "--yatsu-kongo-zoom=$ZOOM" $EXTRA
    done
    if [ "${NOCARD:-0}" != "1" ]; then
      shot "$recipe-$colouring-card" --ui-testing-yatsu-kongo-card \
        "--yatsu-kongo-recipe=$recipe" "--yatsu-kongo-colouring=$colouring"
    fi
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
