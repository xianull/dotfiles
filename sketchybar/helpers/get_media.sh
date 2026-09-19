#!/bin/bash
# Multi-source media info scraper.
# Output: STATE|APP|TITLE|ARTIST  (single line)
# STATE: playing | paused | stopped
#
# Sidecar/AirPlay can make nowplaying-cli and Apple Events hang. Only one
# instance may run, and each query is hard-killed after a few seconds.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
mkdir -p "$CACHE"
LOCKDIR="$CACHE/get_media.lockdir"
holder_alive() {
  local old="$1"
  [ -n "$old" ] && kill -0 "$old" 2>/dev/null || return 1
  ps -p "$old" -o command= 2>/dev/null | grep -q 'get_media.sh'
}
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  old=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
  if holder_alive "$old"; then
    exit 0
  fi
  rm -rf "$LOCKDIR"
  mkdir "$LOCKDIR" 2>/dev/null || exit 0
fi
echo $$ >"$LOCKDIR/pid"
trap 'rm -rf "$LOCKDIR"' EXIT

run_to() {
  local secs=$1
  shift
  perl -e '
    my $secs = shift;
    my $pid = fork();
    exit 127 unless defined $pid;
    if ($pid == 0) { exec @ARGV; exit 127; }
    $SIG{ALRM} = sub {
      kill "TERM", $pid;
      select undef, undef, undef, 0.2;
      kill "KILL", $pid;
      exit 124;
    };
    alarm $secs;
    waitpid $pid, 0;
    alarm 0;
    exit($? >> 8);
  ' "$secs" "$@"
}

get_spotify() {
  pgrep -x "Spotify" >/dev/null 2>&1 || return
  run_to 2 osascript <<'EOF' 2>/dev/null
tell application "Spotify"
  if it is running then
    try
      set s to (player state as string)
      if s is "playing" or s is "paused" then
        set t to name of current track
        set a to artist of current track
        return s & "|Spotify|" & t & "|" & a
      end if
    end try
  end if
  return ""
end tell
EOF
}

get_music() {
  pgrep -x "Music" >/dev/null 2>&1 || return
  run_to 2 osascript <<'EOF' 2>/dev/null
tell application "Music"
  if it is running then
    try
      set s to (player state as string)
      if s is "playing" or s is "paused" then
        set t to name of current track
        set a to artist of current track
        return s & "|Music|" & t & "|" & a
      end if
    end try
  end if
  return ""
end tell
EOF
}

get_npc() {
  command -v nowplaying-cli >/dev/null 2>&1 || return
  local raw title artist rate bundle app state
  raw=$(run_to 2 nowplaying-cli get title artist playbackRate bundleIdentifier 2>/dev/null) || return
  title=$(printf '%s\n' "$raw" | sed -n '1p')
  artist=$(printf '%s\n' "$raw" | sed -n '2p')
  rate=$(printf '%s\n' "$raw" | sed -n '3p')
  bundle=$(printf '%s\n' "$raw" | sed -n '4p')
  [ "$title" = "null" ] || [ -z "$title" ] && return
  state="paused"
  if [ "$rate" != "0" ] && [ "$rate" != "null" ] && [ -n "$rate" ]; then
    state="playing"
  fi
  app="${bundle##*.}"
  [ -n "$app" ] && [ "$app" != "null" ] || app="Media"
  echo "$state|$app|$title|$artist"
}

# Query cheapest-first and stop as soon as something is playing.
# nowplaying-cli is ~110ms even when it returns nulls; skip it if Music/Spotify
# already reports playing.
sp=$(get_spotify)
if [ -n "$sp" ] && [ "${sp%%|*}" = "playing" ]; then
  echo "$sp"
  exit 0
fi
mu=$(get_music)
if [ -n "$mu" ] && [ "${mu%%|*}" = "playing" ]; then
  echo "$mu"
  exit 0
fi
np=$(get_npc)
if [ -n "$np" ] && [ "${np%%|*}" = "playing" ]; then
  echo "$np"
  exit 0
fi

# Fall back to any non-empty (paused)
for s in "$sp" "$mu" "$np"; do
  if [ -n "$s" ]; then
    echo "$s"
    exit 0
  fi
done

echo "stopped|||"
