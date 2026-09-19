#!/bin/bash
# Route a media control command (prev | next | toggle) to the active player.
# Priority: whichever app currently has a non-stopped state.

cmd="$1"

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

spotify_state() {
  pgrep -x "Spotify" >/dev/null 2>&1 || { echo ""; return; }
  run_to 2 osascript -e 'tell application "Spotify" to if it is running then player state as string' 2>/dev/null
}

music_state() {
  pgrep -x "Music" >/dev/null 2>&1 || { echo ""; return; }
  run_to 2 osascript -e 'tell application "Music" to if it is running then player state as string' 2>/dev/null
}

spotify_do() {
  case "$1" in
    prev)   run_to 2 osascript -e 'tell application "Spotify" to previous track' ;;
    next)   run_to 2 osascript -e 'tell application "Spotify" to next track' ;;
    toggle) run_to 2 osascript -e 'tell application "Spotify" to playpause' ;;
  esac
}

music_do() {
  case "$1" in
    prev)   run_to 2 osascript -e 'tell application "Music" to previous track' ;;
    next)   run_to 2 osascript -e 'tell application "Music" to next track' ;;
    toggle) run_to 2 osascript -e 'tell application "Music" to playpause' ;;
  esac
}

npc_do() {
  command -v nowplaying-cli >/dev/null 2>&1 || return
  case "$1" in
    prev)   run_to 2 nowplaying-cli previous ;;
    next)   run_to 2 nowplaying-cli next ;;
    toggle) run_to 2 nowplaying-cli togglePlayPause ;;
  esac
}

sp=$(spotify_state)
mu=$(music_state)

if [ -n "$sp" ] && [ "$sp" != "stopped" ]; then
  spotify_do "$cmd"
elif [ -n "$mu" ] && [ "$mu" != "stopped" ]; then
  music_do "$cmd"
else
  npc_do "$cmd"
fi
