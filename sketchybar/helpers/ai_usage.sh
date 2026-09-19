#!/usr/bin/env bash
# Cursor + Grok usage for SketchyBar.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

HERE="$(cd "$(dirname "$0")" && pwd)"
PYTHON3=""
for c in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if [ -x "$c" ]; then PYTHON3="$c"; break; fi
done
if [ -z "$PYTHON3" ] && command -v python3 >/dev/null 2>&1; then
  PYTHON3="$(command -v python3)"
fi

if [ -z "$PYTHON3" ]; then
  echo -e "P\tcursor\terror\t\t\t--\t\t\t\t"
  echo -e "P\tgrok\terror\t\t\t--\t\t\t\t"
  exit 0
fi

exec "$PYTHON3" "$HERE/ai_usage.py" "${1:-all}"
