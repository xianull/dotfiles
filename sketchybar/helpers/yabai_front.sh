#!/bin/sh
# Focused window for SketchyBar: app, title, stack index / length.
# Always prints one JSON object. Empty desktop -> zeros / empty strings.
# yabai aborts if USER is unset (socket is /tmp/yabai_$USER.socket).
export USER="${USER:-$(id -un)}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
YABAI="${YABAI:-/opt/homebrew/bin/yabai}"
JQ="${JQ:-/opt/homebrew/bin/jq}"

W=$("$YABAI" -m query --windows --window 2>/dev/null)
if [ -z "$W" ]; then
  printf '%s\n' '{"i":0,"n":0,"a":"","t":""}'
  exit 0
fi

IDX=$(printf '%s\n' "$W" | "$JQ" -r '."stack-index" // 0')
LAST=0
case "$IDX" in
  ''|0) ;;
  *)
    LAST=$("$YABAI" -m query --windows --window stack.last 2>/dev/null | "$JQ" -r '."stack-index" // 0')
    LAST=${LAST:-0}
    ;;
esac

printf '%s\n' "$W" | "$JQ" -c --argjson n "$LAST" \
  '{i:(."stack-index" // 0),n:$n,a:(.app // ""),t:(.title // "")}'
