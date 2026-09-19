#!/usr/bin/env bash
# SketchyBar Obsidian todos — count | label | lines | json
# Prefer Home-exported cache; fall back to a full Python vault scan
# (never use the old bash fallback that only printed overdue count).

set -eu

HELPER_DIR="$(cd "$(dirname "$0")" && pwd)"
# Dynamic vault: $OBSIDIAN_VAULT → Obsidian open vault → focus-stack heuristic
if [ -n "${OBSIDIAN_VAULT:-}" ] && [ -d "$OBSIDIAN_VAULT" ]; then
  VAULT="$OBSIDIAN_VAULT"
else
  VAULT="$("$HELPER_DIR/obsidian_vault.sh" path)"
fi
CMD="${1:-count}"
LIMIT="${2:-10}"
CACHE="$VAULT/Settings/cache/today-focus.json"
FOCUS_STATE="$VAULT/Settings/cache/focus-state.json"

PYTHON3=""
for c in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if [ -x "$c" ]; then PYTHON3="$c"; break; fi
done
if [ -z "$PYTHON3" ] && command -v python3 >/dev/null 2>&1; then
  PYTHON3="$(command -v python3)"
fi

if [ -z "$PYTHON3" ]; then
  case "$CMD" in
    label) echo "·" ;;
    json) echo '{"today":0,"overdue":0,"open":0,"items":[]}' ;;
    lines) echo -e "META\t0\t0" ;;
    *) echo "0" ;;
  esac
  exit 0
fi

export OBSIDIAN_VAULT="$VAULT"
exec "$PYTHON3" - "$VAULT" "$CACHE" "$FOCUS_STATE" "$CMD" "$LIMIT" <<'PY'
from __future__ import annotations

import json
import re
import sys
import time
from datetime import date
from pathlib import Path

vault = Path(sys.argv[1]).expanduser()
cache_path = Path(sys.argv[2])
focus_path = Path(sys.argv[3])
cmd = sys.argv[4]
limit = int(sys.argv[5])
today = date.today().isoformat()

TASK_RE = re.compile(r"^(\s*)[-*+] \[[ ]\] (.+)$")
DATE_RE = re.compile(r"([⏳📅])\s*(\d{4}-\d{2}-\d{2})")
TIME_RE = re.compile(
    r"(?:^|[\s　])(\d{1,2}):(\d{2})\s*[-–—~～]\s*(\d{1,2}):(\d{2})"
)
SKIP_DIR = {".obsidian", "attachments", "Settings", "node_modules", ".git", "Banners"}


def clean_md(s: str) -> str:
    s = s or ""

    def _wiki(m: re.Match) -> str:
        return (m.group(2) or m.group(1).split("/")[-1]).strip()

    s = re.sub(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]", _wiki, s)
    s = re.sub(r"==([^=]+)==", r"\1", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"\1", s)
    s = re.sub(r"\*([^*]+)\*", r"\1", s)
    s = re.sub(r"`([^`]+)`", r"\1", s)
    s = re.sub(r"~~([^~]+)~~", r"\1", s)
    s = re.sub(r"[📅⏳🛫✅➕🔁⏫🔼🔽🆔⛔].*", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def parse_time_range(text: str) -> str:
    m = TIME_RE.search(text or "")
    if not m:
        return ""
    sh, sm, eh, em = map(int, m.groups())
    if sh > 23 or eh > 23 or sm > 59 or em > 59:
        return ""
    return f"{sh:02d}:{sm:02d}–{eh:02d}:{em:02d}"


def project_of(rel: str) -> str:
    if rel.startswith("Projects/"):
        return Path(rel).stem
    if "/Diary/" in rel.replace("\\", "/"):
        return "日常/日记"
    return ""


def load_focus() -> dict:
    if not focus_path.exists():
        return {}
    try:
        st = json.loads(focus_path.read_text(encoding="utf-8"))
        return st if isinstance(st, dict) else {}
    except Exception:
        return {}


def from_cache() -> dict | None:
    """Use Home cache if same calendar day. Stale same-day cache is OK (> wrong fallback)."""
    if not cache_path.exists():
        return None
    try:
        data = json.loads(cache_path.read_text(encoding="utf-8"))
    except Exception:
        return None
    if not isinstance(data, dict):
        return None
    if str(data.get("date") or "") != today:
        return None  # yesterday's export — rescan
    # Prefer live focus-state over snapshot in cache
    live = load_focus()
    if live:
        data["focus"] = live
    data.setdefault("items", [])
    data.setdefault("today", 0)
    data.setdefault("overdue", 0)
    data.setdefault("open", 0)
    return data


def scan_vault() -> dict:
    """Lightweight scan: incomplete Tasks lines + diary-of-today."""
    today_items: list[dict] = []
    overdue_items: list[dict] = []
    open_n = 0

    if not vault.is_dir():
        return {"date": today, "today": 0, "overdue": 0, "open": 0, "items": [], "focus": load_focus()}

    for path in vault.rglob("*.md"):
        try:
            rel = path.relative_to(vault).as_posix()
        except ValueError:
            continue
        parts = set(rel.split("/"))
        if parts & SKIP_DIR:
            continue
        # skip deep archives lightly
        if "/Archived/" in f"/{rel}":
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue

        is_today_diary = rel == f"Periodic/Diary/{today}.md" or rel.endswith(
            f"/Diary/{today}.md"
        )
        for i, line in enumerate(text.splitlines()):
            m = TASK_RE.match(line)
            if not m:
                continue
            body = m.group(2).strip()
            open_n += 1
            sched = due = None
            for mark, d in DATE_RE.findall(body):
                if mark == "⏳" and not sched:
                    sched = d
                elif mark == "📅" and not due:
                    due = d
            when = sched or due
            kind = None
            if when and when < today:
                kind = "overdue"
            elif when == today or is_today_diary:
                kind = "today"
            else:
                continue  # not for bar list

            rng = parse_time_range(body)
            disp = clean_md(body)
            if rng:
                disp = re.sub(
                    r"^\d{1,2}:\d{2}\s*[-–—~～]\s*\d{1,2}:\d{2}\s*",
                    "",
                    disp,
                ).strip()
            item = {
                "kind": kind,
                "text": disp or body[:40],
                "path": rel,
                "line": i,
                "project": project_of(rel),
                "when": when or (today if is_today_diary else ""),
                "time_range": rng,
                "is_focus": False,
            }
            if kind == "overdue":
                overdue_items.append(item)
            else:
                today_items.append(item)

    def sort_key(it: dict):
        rng = it.get("time_range") or "99:99"
        return (rng, it.get("text") or "")

    overdue_items.sort(key=sort_key)
    today_items.sort(key=sort_key)
    items = (overdue_items + today_items)[: max(limit, 12)]
    return {
        "date": today,
        "today": len(today_items),
        "overdue": len(overdue_items),
        "open": open_n,
        "items": items,
        "focus": load_focus(),
        "updated_at": int(time.time() * 1000),
        "source": "scan",
    }


def label_of(today_n: int, overdue_n: int) -> str:
    """Unified label:
    - overdue>0 → !!{today}·{overdue}  (red in lua after stripping !!)
    - today>0   → {today}
    - else      → ·
    Never print only overdue count (that showed as bare '1').
    """
    if overdue_n > 0:
        return f"!!{today_n}·{overdue_n}"
    if today_n > 0:
        return str(today_n)
    return "·"


def emit_lines(data: dict) -> None:
    today_n = int(data.get("today") or 0)
    overdue_n = int(data.get("overdue") or 0)
    print(f"META\t{today_n}\t{overdue_n}")
    focus = data.get("focus") or {}
    if isinstance(focus, dict):
        mode = focus.get("mode") or "idle"
        # only show live focus if running, or paused recently (<10 min)
        show = False
        if mode and mode != "idle":
            if focus.get("is_running"):
                show = True
            else:
                paused = focus.get("paused_at") or focus.get("updated_at") or 0
                try:
                    paused = int(paused)
                    if paused > 1e12:
                        paused //= 1000
                    if paused and time.time() - paused < 600:
                        show = True
                except Exception:
                    show = False
        if show:
            running = "1" if focus.get("is_running") else "0"
            rem = int(focus.get("remaining_sec") or 0)
            label = clean_md(
                str(
                    focus.get("label")
                    or (focus.get("task") or {}).get("title")
                    or mode
                )
            )
            print(f"FOCUS\t{mode}\t{running}\t{rem}\t{label}")
    for it in (data.get("items") or [])[:limit]:
        kind = str(it.get("kind") or "today").replace("\t", " ")
        path = str(it.get("path") or "").replace("\t", " ")
        text = clean_md(str(it.get("text") or "")).replace("\t", " ").replace("\n", " ")
        rng = str(it.get("time_range") or "").replace("\t", " ")
        if not rng:
            m = TIME_RE.search(str(it.get("text") or ""))
            if m:
                sh, sm, eh, em = map(int, m.groups())
                rng = f"{sh:02d}:{sm:02d}–{eh:02d}:{em:02d}"
        if rng:
            text = re.sub(
                r"^\d{1,2}:\d{2}\s*[-–—~～]\s*\d{1,2}:\d{2}\s*",
                "",
                text,
            ).strip()
        focus_f = "1" if it.get("is_focus") else "0"
        print(f"ITEM\t{kind}\t{focus_f}\t{path}\t{rng}\t{text}")


def main() -> int:
    data = from_cache()
    if data is None:
        data = scan_vault()
        # write soft cache so next tick is fast even without Home
        try:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            # don't clobber a fresher Home export mid-write; only if missing/wrong day
            write = True
            if cache_path.exists():
                try:
                    old = json.loads(cache_path.read_text(encoding="utf-8"))
                    if str(old.get("date") or "") == today:
                        u = float(old.get("updated_at") or 0)
                        if u > 1e12:
                            u /= 1000.0
                        if u and time.time() - u < 120:
                            write = False  # Home just refreshed
                except Exception:
                    pass
            if write:
                cache_path.write_text(
                    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )
        except Exception:
            pass

    today_n = int(data.get("today") or 0)
    overdue_n = int(data.get("overdue") or 0)

    if cmd == "count":
        print(today_n + overdue_n)
        return 0
    if cmd == "label":
        print(label_of(today_n, overdue_n))
        return 0
    if cmd == "json":
        print(
            json.dumps(
                {
                    "today": today_n,
                    "overdue": overdue_n,
                    "open": int(data.get("open") or 0),
                    "focus": data.get("focus") or {},
                    "items": (data.get("items") or [])[:limit],
                },
                ensure_ascii=False,
            )
        )
        return 0
    if cmd == "lines":
        emit_lines(data)
        return 0
    print("usage: obsidian_todos.sh count|label|lines|json [limit]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
PY
