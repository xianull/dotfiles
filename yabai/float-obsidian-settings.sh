#!/usr/bin/env bash
# Float Obsidian settings windows after Electron sets the title.
# Wired from yabai window_title_changed (app=Obsidian).

YABAI="${YABAI:-/opt/homebrew/bin/yabai}"
JQ="${JQ:-/opt/homebrew/bin/jq}"
WID="${YABAI_WINDOW_ID:-$1}"
GRID="${GRID:-6:6:1:1:4:4}"

[ -n "$WID" ] || exit 0

win="$("$YABAI" -m query --windows --window "$WID" 2>/dev/null)" || exit 0

if echo "$win" | "$JQ" -e \
  'select((.title | test("^(Settings|设置|設定) - ")) and (."is-floating" | not)) | .id' \
  >/dev/null; then
  "$YABAI" -m window "$WID" --toggle float --grid "$GRID"
fi
exit 0
