#!/bin/bash
# Synced lyrics for the playing track.
#
#   get_lyrics.sh dump TITLE ARTIST  →  TSV "seconds<TAB>text" or MISS
#   get_lyrics.sh pos APP            →  player position seconds, or EMPTY
#   get_lyrics.sh APP TITLE ARTIST   →  current line (legacy)
#
# Timed LRC is fetched once per track (lrclib, then NetEase) and parsed
# into a sidecar .idx. The hot path is only an AppleScript position query.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
LYRIC_DIR="$CACHE/lyrics"
MISS_TTL=21600

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

get_pos() {
  local app="$1"
  case "$app" in
    Music)
      run_to 2 osascript -e 'tell application "Music" to if it is running then player position' 2>/dev/null
      ;;
    Spotify)
      run_to 2 osascript -e 'tell application "Spotify" to if it is running then player position' 2>/dev/null
      ;;
    *)
      ;;
  esac
}

track_key() {
  printf '%s' "$1|$2" | /usr/bin/shasum -a 256 | awk '{print $1}'
}

# 0 saved, 1 no usable lyrics, 2 another fetch already running
fetch_lrc() {
  local title="$1" artist="$2" lrc="$3" key="$4"
  local lockdir="$LYRIC_DIR/$key.lockdir"
  if ! mkdir "$lockdir" 2>/dev/null; then
    return 2
  fi
  TITLE="$title" ARTIST="$artist" OUT="$lrc" python3 - <<'PY'
import json, os, re, sys, urllib.parse, urllib.request

title = os.environ.get("TITLE") or ""
artist = os.environ.get("ARTIST") or ""
out = os.environ.get("OUT") or ""

def get(url, data=None, headers=None, timeout=6):
    h = {"User-Agent": "Mozilla/5.0", "Referer": "https://music.163.com"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data, headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()

def timed_enough(lrc):
    return len(re.findall(r"\[\d+:\d+", lrc or "")) >= 3

def save(lrc):
    if not timed_enough(lrc):
        return False
    with open(out, "w", encoding="utf-8") as f:
        f.write(lrc)
    return True

ua = {"User-Agent": "sketchybar-lyrics/1.0"}

try:
    q = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    data = json.loads(get("https://lrclib.net/api/get?" + q, headers=ua))
    if save(data.get("syncedLyrics") or ""):
        sys.exit(0)
except Exception:
    pass

try:
    q = urllib.parse.urlencode({"q": f"{artist} {title}".strip()})
    arr = json.loads(get("https://lrclib.net/api/search?" + q, headers=ua))
    for row in arr or []:
        if save(row.get("syncedLyrics") or ""):
            sys.exit(0)
except Exception:
    pass

try:
    body = urllib.parse.urlencode(
        {"s": f"{artist} {title}".strip(), "type": 1, "limit": 5, "offset": 0}
    ).encode()
    data = json.loads(get("https://music.163.com/api/cloudsearch/pc", data=body))
    songs = (data.get("result") or {}).get("songs") or []
    want_t = title.strip().lower()
    want_a = artist.strip().lower()

    def score(song):
        t = (song.get("name") or "").lower()
        arts = ",".join((a.get("name") or "") for a in (song.get("ar") or [])).lower()
        s = 0
        if want_t and want_t in t:
            s += 3
        if want_a and want_a in arts:
            s += 3
        return s

    songs = sorted(songs, key=score, reverse=True)
    for song in songs:
        sid = song.get("id")
        if not sid:
            continue
        lyr = json.loads(get(f"https://music.163.com/api/song/lyric?id={sid}&lv=1&kv=1&tv=1"))
        lrc = ((lyr.get("lrc") or {}).get("lyric") or "")
        if save(lrc):
            sys.exit(0)
except Exception:
    pass

sys.exit(1)
PY
  local rc=$?
  rmdir "$lockdir" 2>/dev/null || true
  return $rc
}

build_idx() {
  local lrc="$1" idx="$2"
  LRC="$lrc" IDX="$idx" python3 - <<'PY'
import os, re, sys

path = os.environ.get("LRC") or ""
idx_path = os.environ.get("IDX") or ""
credit = re.compile(
    r"^(作词|作曲|编曲|制作|录音|混音|出品|词\s*[:：]|曲\s*[:：]|编\s*[:：])"
)

rows = []
with open(path, encoding="utf-8", errors="replace") as f:
    for line in f:
        times = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", line)
        text = re.sub(r"\[\d+:\d+(?:\.\d+)?\]", "", line)
        text = re.sub(r"<\d+:\d+(?:\.\d+)?>", "", text)
        text = re.sub(r"\s+", " ", text).strip()
        text = re.sub(r"^['\"]|['\"]$", "", text).strip()
        if not text or credit.match(text):
            continue
        for m, s in times:
            rows.append((int(m) * 60 + float(s), text))

if not rows:
    sys.exit(1)

rows.sort()
with open(idx_path, "w", encoding="utf-8") as out:
    for when, text in rows:
        text = text.replace("\t", " ").replace("\n", " ")
        out.write(f"{when:.3f}\t{text}\n")
PY
}

miss_fresh() {
  local miss="$1"
  [ -f "$miss" ] || return 1
  local age
  age=$(($(date +%s) - $(stat -f %m "$miss" 2>/dev/null || echo 0)))
  [ "$age" -ge 0 ] && [ "$age" -lt "$MISS_TTL" ]
}

ensure_idx() {
  local title="$1" artist="$2"
  mkdir -p "$LYRIC_DIR"
  local key lrc idx miss
  key=$(track_key "$title" "$artist")
  lrc="$LYRIC_DIR/$key.lrc"
  idx="$LYRIC_DIR/$key.idx"
  miss="$LYRIC_DIR/$key.miss"

  if [ ! -s "$lrc" ]; then
    if miss_fresh "$miss"; then
      return 1
    fi
    fetch_lrc "$title" "$artist" "$lrc" "$key"
    local rc=$?
    if [ -s "$lrc" ]; then
      rm -f "$miss"
    elif [ "$rc" -eq 1 ]; then
      : >"$miss"
      return 1
    else
      return 1
    fi
  fi

  if [ ! -s "$idx" ] || [ "$lrc" -nt "$idx" ]; then
    if ! build_idx "$lrc" "$idx"; then
      rm -f "$idx"
      return 1
    fi
  fi
  printf '%s' "$idx"
}

pick_legacy() {
  local pos="$1" idx="$2"
  POS="$pos" IDX="$idx" python3 - <<'PY'
import os
pos = float(os.environ.get("POS") or 0) + 0.12
cur = ""
with open(os.environ["IDX"], encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.rstrip("\n")
        if "\t" not in line:
            continue
        when_s, text = line.split("\t", 1)
        try:
            when = float(when_s)
        except ValueError:
            continue
        if when <= pos:
            cur = text
        else:
            break
print(cur if cur else "EMPTY")
PY
}

cmd="$1"
case "$cmd" in
  pos)
    pos=$(get_pos "$2" | tr -d '[:space:]')
    case "$pos" in
      ""|missing*|null|"?")
        echo EMPTY
        ;;
      *)
        echo "$pos"
        ;;
    esac
    ;;
  dump)
    title="$2"
    artist="$3"
    if [ -z "$title" ] && [ -z "$artist" ]; then
      echo MISS
      exit 0
    fi
    idx=$(ensure_idx "$title" "$artist") || { echo MISS; exit 0; }
    cat "$idx"
    ;;
  *)
    app="$1"
    title="$2"
    artist="$3"
    if [ -z "$title" ] && [ -z "$artist" ]; then
      echo EMPTY
      exit 0
    fi
    idx=$(ensure_idx "$title" "$artist") || { echo EMPTY; exit 0; }
    pos=$(get_pos "$app" | tr -d '[:space:]')
    case "$pos" in
      ""|missing*|null|"?")
        echo EMPTY
        exit 0
        ;;
    esac
    pick_legacy "$pos" "$idx"
    ;;
esac
