#!/bin/bash
# ASCII-only entry so SketchyBar exec never sees 元亨利贞 in argv.
# Chinese vault path stays inside this script.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

HOME_DIR="${HOME:-/Users/xianull}"
if [[ -n "${OBSIDIAN_VAULT:-}" && -d "${OBSIDIAN_VAULT}" ]]; then
  VAULT="${OBSIDIAN_VAULT}"
elif [[ -d "${HOME_DIR}/obsidian/元亨利贞" ]]; then
  VAULT="${HOME_DIR}/obsidian/元亨利贞"
else
  echo '{"ok":false,"error":"vault not found"}' >&2
  exit 1
fi

CTL="${VAULT}/Settings/Scripts/focus_ctl.py"
if [[ ! -f "${CTL}" ]]; then
  echo '{"ok":false,"error":"focus_ctl.py missing"}' >&2
  exit 1
fi

exec python3 "${CTL}" --vault "${VAULT}" "$@"
