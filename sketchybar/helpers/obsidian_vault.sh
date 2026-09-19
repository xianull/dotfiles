#!/usr/bin/env bash
# Resolve the active Obsidian vault for SketchyBar widgets.
#
# Usage:
#   obsidian_vault.sh path   # absolute vault root (default)
#   obsidian_vault.sh name   # folder name for obsidian:// ?vault=
#
# Resolution order:
#   1) $OBSIDIAN_VAULT (if it exists)
#   2) currently open vault from Obsidian's obsidian.json
#   3) most recent vault that looks like the Home/focus stack
#   4) common candidate paths
#
# Vault *name* is always basename(path) — matches Obsidian URI convention.

set -euo pipefail

MODE="${1:-path}"

PYTHON3=""
for c in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if [ -x "$c" ]; then PYTHON3="$c"; break; fi
done
if [ -z "$PYTHON3" ] && command -v python3 >/dev/null 2>&1; then
  PYTHON3="$(command -v python3)"
fi

if [ -z "$PYTHON3" ]; then
  # last-resort static fallbacks without python
  for c in \
    "${OBSIDIAN_VAULT:-}" \
    "$HOME/obsidian/元亨利贞" \
    "$HOME/Documents/obsidian/元亨利贞" \
    "$HOME/obsidian/元亨利贞2.0" \
    "$HOME/Documents/obsidian/元亨利贞2.0"
  do
    [ -n "$c" ] && [ -d "$c" ] || continue
    case "$MODE" in
      name) basename "$c" ;;
      *) printf '%s\n' "$c" ;;
    esac
    exit 0
  done
  echo "obsidian_vault.sh: python3 not found and no vault candidate" >&2
  exit 1
fi

export OBSIDIAN_VAULT_MODE="$MODE"
exec "$PYTHON3" - <<'PY'
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

mode = os.environ.get("OBSIDIAN_VAULT_MODE", "path")


def looks_like_vault(p: Path) -> bool:
    if not p.is_dir():
        return False
    # Prefer our Home/focus stack; accept any real Obsidian vault as fallback.
    if (p / "Settings" / "Scripts" / "focus_ctl.py").is_file():
        return True
    if (p / "Settings" / "cache").is_dir():
        return True
    if (p / ".obsidian").is_dir():
        return True
    return False


def score(p: Path, *, open_: bool = False, ts: float = 0) -> float:
    s = 0.0
    if open_:
        s += 1_000_000
    if (p / "Settings" / "Scripts" / "focus_ctl.py").is_file():
        s += 100_000
    if (p / "Settings" / "cache" / "today-focus.json").is_file():
        s += 50_000
    if (p / "Settings" / "🏠Home.md").is_file() or (p / "Settings").is_dir():
        s += 10_000
    if (p / ".obsidian").is_dir():
        s += 1_000
    # newer ts wins among equals (Obsidian stores ms)
    try:
        s += min(float(ts), 1e15) / 1e15
    except (TypeError, ValueError):
        pass
    return s


def emit(p: Path) -> None:
    p = p.expanduser().resolve()
    if mode == "name":
        print(p.name)
    else:
        print(str(p))


def main() -> int:
    env = os.environ.get("OBSIDIAN_VAULT", "").strip()
    if env:
        p = Path(env).expanduser()
        if looks_like_vault(p):
            emit(p)
            return 0

    ranked: list[tuple[float, Path]] = []

    cfg = Path.home() / "Library/Application Support/obsidian/obsidian.json"
    if cfg.is_file():
        try:
            data = json.loads(cfg.read_text(encoding="utf-8"))
            for meta in (data.get("vaults") or {}).values():
                if not isinstance(meta, dict):
                    continue
                raw = meta.get("path")
                if not raw:
                    continue
                p = Path(str(raw)).expanduser()
                if not looks_like_vault(p):
                    continue
                ranked.append(
                    (
                        score(
                            p,
                            open_=bool(meta.get("open")),
                            ts=meta.get("ts") or 0,
                        ),
                        p,
                    )
                )
        except Exception:
            pass

    for raw in (
        Path.home() / "obsidian" / "元亨利贞",
        Path.home() / "Documents" / "obsidian" / "元亨利贞",
        Path.home() / "obsidian" / "元亨利贞2.0",
        Path.home() / "Documents" / "obsidian" / "元亨利贞2.0",
    ):
        if looks_like_vault(raw):
            ranked.append((score(raw), raw))

    if not ranked:
        print("obsidian_vault.sh: no Obsidian vault found", file=sys.stderr)
        return 1

    ranked.sort(key=lambda t: t[0], reverse=True)
    emit(ranked[0][1])
    return 0


raise SystemExit(main())
PY
