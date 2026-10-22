#!/bin/bash
# Fetch current track's album artwork into /tmp/sbar_art_*.jpg.
# Usage: get_artwork.sh APP [TITLE]
# Output: absolute path on success, "NONE" on failure.
#
# Strategy (first success wins):
#   1. App-native artwork (Spotify URL / Music embedded)
#   2. nowplaying-cli artworkData (~0.1s; only used when its title matches TITLE)
#   3. iTunes Search API (multi-region + multi-query, capped by a time budget)
#   4. NetEase Cloud Music search (strong for Chinese catalog)
#
# nowplaying-cli used to be last ("often broken on Sequoia+"), but it works here
# and is the only fast source for streamed Apple Music tracks (0 embedded artworks).
# Behind it, iTunes search runs ~1.9s/request through the proxy and loops over
# 8 queries, so the 8s watchdog killed the script before anything was printed.

app="$1"
want_title="$2"

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
mkdir -p "$CACHE"
LOCKDIR="$CACHE/get_artwork.lockdir"
holder_alive() {
  local old="$1"
  [ -n "$old" ] && kill -0 "$old" 2>/dev/null || return 1
  ps -p "$old" -o command= 2>/dev/null | grep -q 'get_artwork.sh'
}
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  old=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
  if holder_alive "$old"; then
    echo NONE
    exit 0
  fi
  rm -rf "$LOCKDIR"
  mkdir "$LOCKDIR" 2>/dev/null || { echo NONE; exit 0; }
fi
echo $$ >"$LOCKDIR/pid"
# iTunes fan-out / hung Apple Events can run for minutes. Hard-stop the
# whole fetch so the next track is not stuck behind a dead helper.
# Detach from our stdout/stderr: otherwise the background `sleep` keeps the
# pipe open and every caller ($(...) / sbar.exec) waits the full 8s for EOF.
(
  sleep 8
  kill -TERM $$ 2>/dev/null
) >/dev/null 2>&1 &
WATCHDOG=$!
disown "$WATCHDOG" 2>/dev/null # no "Terminated" job notice when cleanup kills it
cleanup() {
  kill "$WATCHDOG" 2>/dev/null || true
  rm -rf "$LOCKDIR"
}
trap cleanup EXIT

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

# Unique filename per fetch so sketchybar re-reads the file instead of
# serving a stale cached image at the same path.
# BSD date has no %N; same-second names made SketchyBar keep a stale cover.
out="/tmp/sbar_art_$(date +%s)_${RANDOM}.jpg"

# Clean up stale artwork files (older than 2 minutes) to avoid /tmp pollution
find /tmp -maxdepth 1 -name 'sbar_art_*.jpg' -mmin +2 -delete 2>/dev/null

fetch_spotify() {
  local url
  url=$(run_to 2 osascript -e 'tell application "Spotify" to if it is running then artwork url of current track' 2>/dev/null)
  [ -z "$url" ] && return 1
  curl -sSfL --max-time 5 -o "$out" "$url" 2>/dev/null
  [ -s "$out" ]
}

fetch_music() {
  # Only attempt embedded artwork if the track actually has one
  # (some streamed Apple Music tracks report 0 artworks).
  run_to 2 osascript <<EOF >/dev/null 2>&1
tell application "Music"
  if it is running then
    try
      if (count of artworks of current track) > 0 then
        set artData to raw data of artwork 1 of current track
        set f to open for access POSIX file "$out" with write permission
        set eof of f to 0
        write artData to f
        close access f
      end if
    end try
  end if
end tell
EOF
  [ -s "$out" ]
}

# Generic fetcher for any nowplaying-cli source.
# Note: can be broken on macOS Sequoia 15+ where Apple restricted MediaRemote.
fetch_npc() {
  command -v nowplaying-cli >/dev/null 2>&1 || return 1
  local raw title data
  raw=$(run_to 2 nowplaying-cli get title artworkData 2>/dev/null) || return 1
  title=$(printf '%s\n' "$raw" | sed -n '1p')
  data=$(printf '%s\n' "$raw" | sed -n '2p')
  # System "now playing" may be another app; don't show its cover for this track.
  [ -n "$want_title" ] && [ "$title" != "$want_title" ] && return 1
  [ -z "$data" ] || [ "$data" = "null" ] && return 1
  printf '%s' "$data" | base64 -d > "$out" 2>/dev/null
  [ -s "$out" ]
}

# Download a remote image URL into $out.
download_url() {
  local url="$1"
  [ -z "$url" ] && return 1
  # NetEase sometimes returns http:// — force https when possible
  case "$url" in
    http://*) url="https://${url#http://}" ;;
  esac
  curl -sSfL --max-time 6 -A "Mozilla/5.0" -o "$out" "$url" 2>/dev/null
  [ -s "$out" ]
}

# Query iTunes Search API for a 600px album cover.
# Tries multiple countries and query shapes; prefers exact-ish title matches.
fetch_itunes_search() {
  local title="$1" artist="$2" album="$3"
  [ -z "$title" ] && [ -z "$album" ] && return 1

  local country term url
  # cn storefront currently returns resultCount=0 for everything (even top hits);
  # us covers both English and most Chinese catalog. Keep cn as a fallback.
  for country in us cn; do
    for term in \
      "${artist} ${title}" \
      "${title} ${artist}" \
      "${album} ${artist}" \
      "${title}"
    do
      [ -z "$(echo "$term" | tr -d '[:space:]')" ] && continue
      # Leave time for NetEase and the download before the 8s watchdog fires.
      [ "$SECONDS" -ge 5 ] && return 1
      url=$(curl -sSfL --max-time 3 -G "https://itunes.apple.com/search" \
            --data-urlencode "term=${term}" \
            --data-urlencode "entity=song" \
            --data-urlencode "country=${country}" \
            --data-urlencode "limit=5" 2>/dev/null \
            | TITLE="$title" ARTIST="$artist" python3 -c '
import json, os, sys, re
title = (os.environ.get("TITLE") or "").strip().lower()
artist = (os.environ.get("ARTIST") or "").strip().lower()
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
results = data.get("results") or []

def score(r):
    t = (r.get("trackName") or "").lower()
    a = (r.get("artistName") or "").lower()
    s = 0
    if title and title in t:
        s += 3
    if title and t in title:
        s += 2
    if artist and artist in a:
        s += 3
    if artist and a in artist:
        s += 2
    # prefer first token overlap for CJK/English mix
    if title:
        tok = title.split()[0]
        if tok and tok in t:
            s += 1
    return s

if not results:
    sys.exit(0)
ranked = sorted(results, key=score, reverse=True)
best = ranked[0]
# reject totally unrelated results when we have a title
if title and score(best) == 0:
    # still allow first hit as last resort only if term was specific
    pass
art = best.get("artworkUrl100") or best.get("artworkUrl60") or ""
if art:
    art = re.sub(r"\d+x\d+bb", "600x600bb", art)
    print(art)
' 2>/dev/null)
      if [ -n "$url" ] && download_url "$url"; then
        return 0
      fi
    done
  done
  return 1
}

# NetEase Cloud Music cloudsearch — works well for Chinese indie/rap catalog.
fetch_netease_search() {
  local title="$1" artist="$2" album="$3"
  [ -z "$title" ] && [ -z "$album" ] && return 1

  local term url
  for term in \
    "${artist} ${title}" \
    "${title} ${artist}" \
    "${album} ${artist}" \
    "${title}"
  do
    [ -z "$(echo "$term" | tr -d '[:space:]')" ] && continue
    url=$(curl -sS --max-time 5 -X POST "https://music.163.com/api/cloudsearch/pc" \
          -H "User-Agent: Mozilla/5.0" \
          -H "Referer: https://music.163.com" \
          --data-urlencode "s=${term}" \
          --data "type=1&limit=5&offset=0" 2>/dev/null \
          | TITLE="$title" ARTIST="$artist" python3 -c '
import json, os, sys
title = (os.environ.get("TITLE") or "").strip().lower()
artist = (os.environ.get("ARTIST") or "").strip().lower()
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
songs = (data.get("result") or {}).get("songs") or []
if not songs:
    sys.exit(0)

def score(s):
    t = (s.get("name") or "").lower()
    arts = ",".join((a.get("name") or "") for a in (s.get("ar") or s.get("artists") or [])).lower()
    sc = 0
    if title and title in t: sc += 3
    if title and t in title: sc += 2
    if artist and artist in arts: sc += 3
    return sc

ranked = sorted(songs, key=score, reverse=True)
best = ranked[0]
al = best.get("al") or best.get("album") or {}
pic = al.get("picUrl") or al.get("blurPicUrl") or ""
if pic:
    print(pic)
' 2>/dev/null)
    if [ -n "$url" ] && download_url "$url"; then
      return 0
    fi
  done
  return 1
}

# Resolve current track metadata from the relevant app.
get_meta() {
  local app="$1"
  case "$app" in
    Music)
      run_to 2 osascript <<'EOF' 2>/dev/null
tell application "Music"
  if it is running then
    try
      set t to current track
      return (name of t) & linefeed & (artist of t) & linefeed & (album of t)
    end try
  end if
end tell
EOF
      ;;
    Spotify)
      run_to 2 osascript <<'EOF' 2>/dev/null
tell application "Spotify"
  if it is running then
    try
      set t to current track
      return (name of t) & linefeed & (artist of t) & linefeed & (album of t)
    end try
  end if
end tell
EOF
      ;;
    *)
      if command -v nowplaying-cli >/dev/null 2>&1; then
        local raw t a al
        raw=$(run_to 2 nowplaying-cli get title artist album 2>/dev/null) || raw=""
        t=$(printf '%s\n' "$raw" | sed -n '1p')
        a=$(printf '%s\n' "$raw" | sed -n '2p')
        al=$(printf '%s\n' "$raw" | sed -n '3p')
        [ "$t" = "null" ] && t=""
        [ "$a" = "null" ] && a=""
        [ "$al" = "null" ] && al=""
        printf '%s\n%s\n%s\n' "$t" "$a" "$al"
      fi
      ;;
  esac
}

fetch_search_for() {
  local app="$1" title artist album meta
  meta=$(get_meta "$app")
  title=$(printf '%s' "$meta" | sed -n '1p')
  artist=$(printf '%s' "$meta" | sed -n '2p')
  album=$(printf '%s' "$meta" | sed -n '3p')
  # Strip CR (osascript sometimes includes it)
  title=${title//$'\r'/}
  artist=${artist//$'\r'/}
  album=${album//$'\r'/}
  [ -z "$title" ] && [ -z "$album" ] && return 1

  fetch_itunes_search "$title" "$artist" "$album" \
    || fetch_netease_search "$title" "$artist" "$album"
}

case "$app" in
  Spotify)  fetch_spotify || fetch_npc || fetch_search_for Spotify ;;
  Music)    fetch_music   || fetch_npc || fetch_search_for Music ;;
  *)        fetch_npc     || fetch_search_for "$app" ;;
esac

if [ -s "$out" ]; then
  # Normalize to ~96x96 so a 0.28–0.42 scale stays sharp on retina.
  sips -s format jpeg -Z 96 "$out" --out "$out" >/dev/null 2>&1 || sips -Z 96 "$out" >/dev/null 2>&1
  echo "$out"
else
  rm -f "$out"
  echo "NONE"
fi
