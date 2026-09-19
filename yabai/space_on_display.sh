#!/usr/bin/env bash
# Focus next/prev space on the focused display only (does not jump monitors).
# Usage: space_on_display.sh next|prev

dir="${1:-next}"
spaces="$(yabai -m query --spaces --display | jq '[.[] | select(."is-native-fullscreen" == false)]')"
len="$(echo "$spaces" | jq 'length')"
[ "$len" -gt 0 ] || exit 1

cur="$(echo "$spaces" | jq 'map(."has-focus") | index(true)')"
[ "$cur" != "null" ] && [ -n "$cur" ] || exit 1

if [ "$dir" = "prev" ]; then
  next=$(( (cur - 1 + len) % len ))
else
  next=$(( (cur + 1) % len ))
fi

yabai -m space --focus "$(echo "$spaces" | jq -r ".[$next].index")"
