#!/usr/bin/env bash
# Summon WeChat on the current space; hide it back to space 6.
# Native --toggle leaves the window on whatever space it was shown.

LABEL="wechat"
HOME_SPACE=6
GRID="6:6:1:1:4:4"

wechat_json() {
  yabai -m query --windows | jq -c '
    [.[] | select(.scratchpad == "wechat" or .app == "微信" or .app == "WeChat")]
    | sort_by(if .scratchpad == "wechat" then 0 elif .title == "微信" or .title == "WeChat" then 1 else 2 end)
    | .[0] // empty
  '
}

launch_wechat() {
  open -a 微信 2>/dev/null || open -a WeChat
  i=0
  while [ "$i" -lt 8 ]; do
    sleep 0.25
    json="$(wechat_json)"
    [ -n "$json" ] && [ "$json" != "null" ] && return 0
    i=$((i + 1))
  done
  return 1
}

json="$(wechat_json)"
if [ -z "$json" ] || [ "$json" = "null" ]; then
  launch_wechat || exit 1
  json="$(wechat_json)"
fi

wid="$(echo "$json" | jq -r '.id')"
visible="$(echo "$json" | jq -r '."is-visible"')"
pad="$(echo "$json" | jq -r '.scratchpad')"
[ -n "$wid" ] && [ "$wid" != "null" ] || exit 1

if [ "$pad" != "$LABEL" ]; then
  yabai -m window "$wid" --scratchpad "$LABEL"
fi

current="$(yabai -m query --spaces --space | jq -r '.index')"

if [ "$visible" = "true" ]; then
  yabai -m window --toggle "$LABEL" 2>/dev/null || yabai -m window "$wid" --toggle "$LABEL"
  yabai -m window "$wid" --space "$HOME_SPACE"
  exit 0
fi

if [ "$current" != "$HOME_SPACE" ]; then
  yabai -m window "$wid" --space "$current"
fi
yabai -m window --toggle "$LABEL" 2>/dev/null || yabai -m window "$wid" --toggle "$LABEL"
yabai -m window "$wid" --grid "$GRID"
