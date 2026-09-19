#!/usr/bin/env python3
"""AI subscription usage for SketchyBar.

Talks to each vendor's own API with credentials already on this machine — no
CodexBar dependency. Which providers are shown (and in what order) comes from
ai_usage.conf; see enabled_providers().

Stdout protocol (tab-separated):
  P  id  status  plan  used  label  reset  spend  spend_limit  period  reset_at  period_range  _  hint
  E  id  extra_pct  extra_bar  hint
  W  id  name  used  label  reset  reset_at  bar  hint
  S  id  share
  C  id  key   cost  tokens  title
  H  id  days  chart
status: ok | stale | error | missing
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

KNOWN_PROVIDERS = ("cursor", "grok")
DEFAULT_ORDER = ("cursor", "grok")
CONFIG = Path(os.environ.get("SKETCHYBAR_CONFIG_DIR") or (Path.home() / ".config" / "sketchybar")) / "ai_usage.conf"
TTL = int(os.environ.get("AI_USAGE_TTL", "90"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sketchybar" / "ai_usage.json"
LOCK = CACHE.with_suffix(".lock")
BAR_DIR = CACHE.parent / "ai_bars"
BAR_FILLS = {
    "cursor": (0, 191, 165),
    "grok": (16, 163, 127),
}


def enabled_providers():
    """Provider ids in bar order (left to right), one per line, '#' comments."""
    try:
        lines = CONFIG.read_text().splitlines()
    except OSError:
        return list(DEFAULT_ORDER)
    out = []
    for line in lines:
        pid = line.split("#", 1)[0].strip().lower()
        if pid in KNOWN_PROVIDERS and pid not in out:
            out.append(pid)
    return out or list(DEFAULT_ORDER)


PROVIDERS = tuple(enabled_providers())


def fmt_pct(value):
    if value is None:
        return "--"
    try:
        n = float(value)
    except (TypeError, ValueError):
        return "--"
    if n <= 0:
        return "0%"
    if n < 1:
        return "<1%"
    return f"{int(round(n))}%"


def parse_iso(iso):
    if not iso:
        return None
    try:
        dt = datetime.fromisoformat(str(iso).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def fmt_countdown(seconds):
    """CodexBar-style countdown: '2d 18h', '5h 12m', '8m'."""
    if seconds is None:
        return ""
    if seconds < 1:
        return "now"
    total_minutes = max(1, int((seconds + 59) // 60))
    days = total_minutes // (24 * 60)
    hours = (total_minutes // 60) % 24
    minutes = total_minutes % 60
    if days > 0:
        if hours > 0:
            return f"{days}d {hours}h"
        if minutes > 0:
            return f"{days}d {minutes}m"
        return f"{days}d"
    if hours > 0:
        if minutes > 0:
            return f"{hours}h {minutes}m"
        return f"{hours}h"
    return f"{total_minutes}m"


def fmt_reset(iso):
    dt = parse_iso(iso)
    if not dt:
        return ""
    return fmt_countdown(max(0, (dt - datetime.now(timezone.utc)).total_seconds()))


def fmt_reset_at(iso):
    dt = parse_iso(iso)
    if not dt:
        return ""
    local = dt.astimezone()
    return f"{local.month}月{local.day}日 {local:%H:%M}"


def fmt_day(iso):
    dt = parse_iso(iso)
    if not dt:
        return ""
    local = dt.astimezone()
    return f"{local.month}月{local.day}日"


def fmt_period_range(start_iso, end_iso):
    start, end = fmt_day(start_iso), fmt_day(end_iso)
    if start and end:
        return f"{start} – {end}"
    return end or start


def usage_pace(used, start_iso, end_iso, min_expected=3.0):
    """CodexBar UsagePace.weekly: linear budget vs actual used.

    expected = elapsed / period * 100
    delta = used - expected
    delta < 0 → reserve (余量); delta > 0 → deficit (超额)
    """
    start, end = parse_iso(start_iso), parse_iso(end_iso)
    if start is None or end is None or used is None:
        return None
    try:
        actual = max(0.0, min(100.0, float(used)))
    except (TypeError, ValueError):
        return None
    if actual >= 100:
        return None
    now = datetime.now(timezone.utc)
    duration = (end - start).total_seconds()
    time_until = (end - now).total_seconds()
    if duration <= 0 or time_until <= 0 or time_until > duration:
        return None
    elapsed = max(0.0, min(duration, duration - time_until))
    if elapsed == 0 and actual > 0:
        return None
    expected = (elapsed / duration) * 100.0
    if expected < min_expected:
        return None
    delta = actual - expected
    will_last = False
    eta_seconds = None
    if elapsed > 0 and actual > 0:
        rate = actual / elapsed
        candidate = (100.0 - actual) / rate
        if candidate >= time_until:
            will_last = True
        else:
            eta_seconds = candidate
    elif elapsed > 0 and actual == 0:
        will_last = True
    projected = (actual * time_until / elapsed) if elapsed > 0 else 0.0
    remaining_cap = 100.0 - actual
    speed = None
    if remaining_cap > 0 and projected > 0:
        speed = remaining_cap / projected
    return {
        "expected": expected,
        "actual": actual,
        "delta": delta,
        "will_last": will_last,
        "eta_seconds": eta_seconds,
        "speed": speed,
    }


def fmt_pace_hint(pace):
    """CodexBar UsagePaceText.weeklyDetail, zh-Hans copy."""
    if not pace:
        return ""
    delta_abs = int(round(abs(pace["delta"])))
    if delta_abs <= 2:
        left = "节奏正常"
    elif pace["delta"] > 0:
        left = f"超额 {delta_abs}%"
    else:
        left = f"余量 {delta_abs}%"
    if pace["will_last"]:
        right = "持续到重置"
        if pace["delta"] < -15 and pace.get("speed") and pace["speed"] >= 1.5:
            right = "持续到重置 · 1.5 倍余量"
    elif pace.get("eta_seconds") is not None:
        eta = fmt_countdown(pace["eta_seconds"])
        right = "即将耗尽" if eta == "now" else f"预计 {eta} 后耗尽"
    else:
        right = ""
    if left and right:
        return f"{left}  ·  {right}"
    return left or right


def make_window(name, used, reset_iso, start_iso=None, shared=False):
    pace = None if shared else usage_pace(used, start_iso, reset_iso)
    return {
        "name": name,
        "used": used,
        "label": fmt_pct(used),
        "hint": "" if shared else fmt_pace_hint(pace),
        "expected": None if shared or pace is None else pace["expected"],
        "reset": fmt_reset(reset_iso),
        "reset_at": fmt_reset_at(reset_iso),
    }


def empty_provider(pid, status="error"):
    return {
        "id": pid,
        "status": status,
        "plan": "",
        "used": None,
        "label": "--",
        "reset": "",
        "spend": None,
        "spend_limit": None,
        "period": "",
        "reset_at": "",
        "period_range": "",
        "hint": "",
        "share": "",
        "spend_hint": "",
        "windows": [],
        "costs": [],
        "cost_charts": {},
    }


# Popup card is 280pt; bake 18pt insets into the PNG so SketchyBar
# padding does not widen the popup and leave an empty right gutter.
POPUP_PT = 280
PAD_PT = 18
INNER_PT = POPUP_PT - PAD_PT * 2


def render_bar(pid, idx, percent, expected=None):
    """8pt capsule: fill = used; optional tick = CodexBar expected-pace mark."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return ""
    BAR_DIR.mkdir(parents=True, exist_ok=True)
    path = BAR_DIR / f"{pid}_{idx}.png"
    scale = 2
    width, height = POPUP_PT * scale, 8 * scale
    inset = PAD_PT * scale
    inner_w = INNER_PT * scale
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = height / 2
    left, right = inset, inset + inner_w - 1
    draw.rounded_rectangle((left, 0, right, height - 1), radius=radius, fill=(255, 255, 255, 40))
    try:
        pct = max(0.0, min(100.0, float(percent)))
    except (TypeError, ValueError):
        pct = 0.0
    fill_w = int(round((inner_w - 1) * pct / 100.0))
    if pct >= 0.5 and fill_w > 0:
        fill_w = max(fill_w, height)
        fill_w = min(fill_w, inner_w - 1)
        rgb = BAR_FILLS.get(pid, (16, 163, 127))
        if pct >= 95:
            rgb = (251, 73, 52)
        elif pct >= 90:
            rgb = (254, 128, 25)
        draw.rounded_rectangle((left, 0, left + fill_w, height - 1), radius=radius, fill=rgb + (255,))
    if expected is not None:
        try:
            exp = max(0.0, min(100.0, float(expected)))
        except (TypeError, ValueError):
            exp = None
        else:
            x = left + int(round((inner_w - 1) * exp / 100.0))
            tick = max(2, scale)
            draw.rectangle((x - tick, 0, x + tick, height - 1), fill=(235, 219, 178, 220))
    img.save(path)
    return str(path)


def render_cost_chart(pid, days, values):
    """CodexBar MiniUsageBars: daily cost columns for the selected window."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return ""
    if not values:
        return ""
    BAR_DIR.mkdir(parents=True, exist_ok=True)
    path = BAR_DIR / f"{pid}_cost_{days}.png"
    scale = 2
    width, height = POPUP_PT * scale, 36 * scale
    inset = PAD_PT * scale
    inner_w = INNER_PT * scale
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    baseline_y = height - 3
    draw.rectangle((inset, baseline_y, inset + inner_w - 1, baseline_y + 1), fill=(255, 255, 255, 40))
    n = len(values)
    gap = 4 if n <= 10 else 2
    bar_w = max(6, (inner_w - gap * (n + 1)) // n)
    total = n * bar_w + (n - 1) * gap
    x0 = inset + max(0, (inner_w - total) // 2)
    mx = max(values) or 1.0
    rgb = BAR_FILLS.get(pid, (16, 163, 127))
    usable = height - 10
    for i, v in enumerate(values):
        x = x0 + i * (bar_w + gap)
        if v <= 0:
            h = 2
            alpha = 70
        else:
            h = max(6, int(round(usable * (v / mx))))
            alpha = int(130 + 125 * (v / mx))
        y = baseline_y - h
        draw.rounded_rectangle((x, y, x + bar_w - 1, baseline_y - 1), radius=3, fill=rgb + (alpha,))
    img.save(path)
    return str(path)


def cell(v):
    if v is None:
        return ""
    return str(v).replace("\t", " ").replace("\n", " ")


def emit(row):
    print(
        "\t".join(
            cell(x)
            for x in (
                "P",
                row["id"],
                row.get("status") or "error",
                row.get("plan") or "",
                row.get("used"),
                row.get("label") or "--",
                row.get("reset") or "",
                row.get("spend"),
                row.get("spend_limit"),
                row.get("period") or "",
                row.get("reset_at") or "",
                row.get("period_range") or "",
                "",
                row.get("hint") or "",
            )
        )
    )
    spend = row.get("spend")
    limit = row.get("spend_limit")
    extra_bar = ""
    extra_pct = ""
    extra_hint = row.get("spend_hint") or ""
    extra_expected = row.get("spend_expected")
    if spend is not None and limit:
        try:
            extra_pct = max(0.0, min(100.0, float(spend) / float(limit) * 100.0))
            extra_bar = render_bar(row["id"], "x", extra_pct, extra_expected)
        except (TypeError, ValueError, ZeroDivisionError):
            extra_pct = ""
            extra_bar = ""
    print(
        "\t".join(
            cell(x)
            for x in (
                "E",
                row["id"],
                extra_pct,
                extra_bar,
                extra_hint,
            )
        )
    )
    for idx, win in enumerate(row.get("windows") or []):
        bar_path = render_bar(row["id"], idx, win.get("used"), win.get("expected"))
        print(
            "\t".join(
                cell(x)
                for x in (
                    "W",
                    row["id"],
                    win.get("name") or "",
                    win.get("used"),
                    win.get("label") or fmt_pct(win.get("used")),
                    win.get("reset") or "",
                    win.get("reset_at") or "",
                    bar_path,
                    win.get("hint") or "",
                )
            )
        )
    if row.get("share"):
        print("\t".join(cell(x) for x in ("S", row["id"], row["share"])))
    for cost in row.get("costs") or []:
        print(
            "\t".join(
                cell(x)
                for x in (
                    "C",
                    row["id"],
                    cost.get("key") or "",
                    cost.get("cost"),
                    cost.get("tokens"),
                    cost.get("title") or "",
                )
            )
        )
    charts = row.get("cost_charts") or {}
    for days in (7, 30):
        path = charts.get(str(days)) or charts.get(days) or ""
        if path:
            print("\t".join(cell(x) for x in ("H", row["id"], days, path)))
    sys.stdout.flush()


def load_cache():
    try:
        data = json.loads(CACHE.read_text())
        if isinstance(data, dict) and isinstance(data.get("rows"), dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"ts": 0, "rows": {}}


def save_cache(data):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False))
    tmp.replace(CACHE)


def acquire_lock():
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(LOCK), os.O_CREAT | os.O_RDWR, 0o644)
    except OSError:
        return None
    try:
        import fcntl

        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fd
    except OSError:
        os.close(fd)
        return None


GROK_AUTH = Path.home() / ".grok" / "auth.json"
GROK_REFRESH_SKEW = 120


def _grok_exp(exp_raw):
    if not exp_raw:
        return None
    try:
        return datetime.fromisoformat(str(exp_raw).replace("Z", "+00:00"))
    except ValueError:
        return None


def grok_refresh_oidc(store, scope, entry):
    """Refresh the grok CLI OIDC token and write it back to ~/.grok/auth.json."""
    issuer = (entry.get("oidc_issuer") or "").rstrip("/")
    client_id = entry.get("oidc_client_id")
    refresh = entry.get("refresh_token")
    if not issuer or not client_id or not refresh:
        return None
    try:
        with urllib.request.urlopen(f"{issuer}/.well-known/openid-configuration", timeout=8) as resp:
            conf = json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError):
        return None
    token_url = conf.get("token_endpoint")
    if not token_url:
        return None
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": client_id,
        }
    ).encode()
    req = urllib.request.Request(
        token_url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            tok = json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError):
        return None
    access = tok.get("access_token")
    if not access:
        return None
    updated = dict(entry)
    updated["key"] = access
    if tok.get("refresh_token"):
        updated["refresh_token"] = tok["refresh_token"]
    now = datetime.now(timezone.utc)
    updated["create_time"] = now.isoformat().replace("+00:00", "Z")
    try:
        expires_in = int(tok.get("expires_in") or 0)
    except (TypeError, ValueError):
        expires_in = 0
    if expires_in > 0:
        updated["expires_at"] = (now + timedelta(seconds=expires_in)).isoformat().replace("+00:00", "Z")
    store[scope] = updated
    tmp = GROK_AUTH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(store, ensure_ascii=False, indent=2))
    tmp.replace(GROK_AUTH)
    try:
        os.chmod(GROK_AUTH, 0o600)
    except OSError:
        pass
    return access


def grok_auth_token():
    try:
        store = json.loads(GROK_AUTH.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(store, dict):
        return None
    now = datetime.now(timezone.utc)
    best_scope = best = best_exp = None
    expired = None
    for scope, entry in store.items():
        if not isinstance(entry, dict) or not entry.get("key"):
            continue
        exp = _grok_exp(entry.get("expires_at"))
        if exp and exp <= now:
            if expired is None:
                expired = (scope, entry)
            continue
        if best is None or (exp and (best_exp is None or exp > best_exp)):
            best_scope, best, best_exp = scope, entry, exp
    if best is not None:
        if best_exp is None or (best_exp - now).total_seconds() > GROK_REFRESH_SKEW:
            return best.get("key")
        refreshed = grok_refresh_oidc(store, best_scope, best)
        if refreshed:
            return refreshed
        return best.get("key")
    if expired is not None:
        return grok_refresh_oidc(store, expired[0], expired[1])
    return None


def http_json(url, token, timeout=12):
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "x-xai-token-auth": "xai-grok-cli",
            "Accept": "application/json",
            "User-Agent": "GrokCLI/1.0",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        if exc.code == 401:
            return "unauthorized"
        return None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError):
        return None


GROK_PRODUCTS = {
    "GrokBuild": "Build",
    "GrokAppBuilder": "App Builder",
    "GrokChat": "Chat",
    "GrokImagine": "Imagine",
}


def fetch_grok():
    row = empty_provider("grok", "error")
    token = grok_auth_token()
    credits = http_json("https://cli-chat-proxy.grok.com/v1/billing?format=credits", token) if token else None
    if credits == "unauthorized":
        token = grok_auth_token()
        credits = http_json("https://cli-chat-proxy.grok.com/v1/billing?format=credits", token) if token else None
    if credits == "unauthorized":
        credits = None
    settings = http_json("https://cli-chat-proxy.grok.com/v1/settings", token) if token else None
    if settings == "unauthorized":
        settings = None

    cfg = (credits or {}).get("config") or {}
    period = cfg.get("currentPeriod") or {}
    reset_iso = period.get("end") or cfg.get("billingPeriodEnd")
    start_iso = period.get("start") or cfg.get("billingPeriodStart")
    period_type = str(period.get("type") or "")
    period_label = "weekly" if "WEEKLY" in period_type else ("monthly" if "MONTHLY" in period_type else "")
    # After a weekly reset the API omits creditUsagePercent / productUsage
    # until something is spent. That is 0%, not an error.
    used = cfg.get("creditUsagePercent")
    if used is None and (reset_iso or start_iso):
        used = 0.0

    # Unified weekly pool is the hero total. Product rows are a breakdown
    # of that same pool — bars stay, but they are not independent quotas.
    windows = []
    products = cfg.get("productUsage")
    if products:
        for item in products:
            product = item.get("product") or "Usage"
            value = item.get("usagePercent")
            windows.append(
                make_window(
                    GROK_PRODUCTS.get(product, product),
                    0.0 if value is None else value,
                    reset_iso,
                    start_iso,
                    shared=True,
                )
            )
    elif used is not None:
        if float(used) == 0:
            for name in GROK_PRODUCTS.values():
                windows.append(make_window(name, 0.0, reset_iso, start_iso, shared=True))
        else:
            windows.append(make_window("Credits", used, reset_iso, start_iso))

    cap = (cfg.get("onDemandCap") or {}).get("val")
    od_used = (cfg.get("onDemandUsed") or {}).get("val")
    try:
        cap_n = float(cap) if cap is not None else 0.0
        od_n = float(od_used) if od_used is not None else 0.0
    except (TypeError, ValueError):
        cap_n, od_n = 0.0, 0.0
    if cap_n > 0:
        windows.append(make_window("On-demand", (od_n / cap_n) * 100.0, reset_iso, start_iso))

    plan = ""
    if isinstance(settings, dict):
        plan = settings.get("subscription_tier_display") or ""

    prepaid = ((cfg.get("prepaidBalance") or {}).get("val"))
    if prepaid is not None:
        try:
            row["spend"] = round(float(prepaid) / 100.0, 2)
            row["spend_limit"] = None
        except (TypeError, ValueError):
            pass

    if used is None:
        return row
    row.update(
        {
            "status": "ok",
            "plan": plan or "SuperGrok",
            "used": used,
            "label": fmt_pct(used),
            "reset": fmt_reset(reset_iso),
            "reset_at": fmt_reset_at(reset_iso),
            "period": period_label,
            "period_range": fmt_period_range(start_iso, reset_iso),
            "hint": fmt_pace_hint(usage_pace(used, start_iso, reset_iso)),
            "share": "",
            "period_end": reset_iso or "",
            "windows": windows,
        }
    )
    return row


def _day_key(value):
    text = str(value or "")
    return text[:10] if len(text) >= 10 else ""


def _window_sum(daily, days, today):
    """Totals for the window, plus one chart column per day so a 30d chart
    really spans 30 days instead of only the days that had spend."""
    from datetime import timedelta

    by_day = {}
    for entry in daily or []:
        key = _day_key(entry.get("date"))
        if key:
            by_day[key] = entry

    cost_total = 0.0
    token_total = 0
    has_cost = False
    has_tokens = False
    values = []
    for offset in range(days - 1, -1, -1):
        entry = by_day.get((today - timedelta(days=offset)).isoformat())
        if entry is None:
            values.append(0.0)
            continue
        raw_cost = entry.get("totalCost")
        if raw_cost is None:
            raw_cost = entry.get("costUSD")
        try:
            cost_n = float(raw_cost) if raw_cost is not None else 0.0
        except (TypeError, ValueError):
            cost_n = 0.0
        else:
            if raw_cost is not None:
                has_cost = True
        raw_tokens = entry.get("totalTokens")
        try:
            tok_n = int(raw_tokens) if raw_tokens is not None else 0
        except (TypeError, ValueError):
            tok_n = 0
        else:
            if raw_tokens is not None:
                has_tokens = True
        cost_total += cost_n
        token_total += tok_n
        values.append(cost_n)
    return {
        "cost": cost_total if has_cost else None,
        "tokens": token_total if has_tokens else None,
        "values": values,
    }


CURSOR_API = "https://api2.cursor.sh/aiserver.v1.DashboardService/"
CURSOR_DB = Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
CURSOR_TOKEN_FIELDS = ("inputTokens", "outputTokens", "cacheWriteTokens", "cacheReadTokens")
_cursor_state = None


def cursor_state():
    """Cursor's own globalStorage sqlite, opened read-only. Cached per run."""
    global _cursor_state
    if _cursor_state is not None:
        return _cursor_state
    _cursor_state = {}
    if not CURSOR_DB.exists():
        return _cursor_state
    try:
        con = sqlite3.connect(f"file:{CURSOR_DB}?mode=ro", uri=True)
    except sqlite3.Error:
        return _cursor_state
    try:
        for key in ("cursorAuth/accessToken", "cursorAuth/stripeMembershipType"):
            row = con.execute("select value from ItemTable where key=?", (key,)).fetchone()
            if row and row[0] is not None:
                raw = row[0]
                _cursor_state[key] = raw.decode() if isinstance(raw, bytes) else str(raw)
    except sqlite3.Error:
        pass
    finally:
        con.close()
    return _cursor_state


def cursor_post(endpoint, body=None, timeout=20):
    token = cursor_state().get("cursorAuth/accessToken")
    if not token:
        return None
    req = urllib.request.Request(
        CURSOR_API + endpoint,
        data=json.dumps(body or {}).encode(),
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Connect-Protocol-Version": "1",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError):
        return None


def ms_to_iso(ms):
    try:
        return datetime.fromtimestamp(int(ms) / 1000.0, timezone.utc).isoformat().replace("+00:00", "Z")
    except (TypeError, ValueError, OSError):
        return ""


def cursor_plan_label():
    kind = (cursor_state().get("cursorAuth/stripeMembershipType") or "").strip()
    if not kind or kind == "free":
        return "Cursor"
    return "Cursor " + kind[:1].upper() + kind[1:]


def cursor_events(days=30, deadline=None):
    """Individual usage events. Stop early so a large history cannot block Grok."""
    now_ms = int(time.time() * 1000)
    start_ms = now_ms - days * 86400 * 1000
    events = []
    for page in range(1, 21):
        remain = 8.0 if deadline is None else deadline - time.time()
        if remain <= 0.4:
            break
        data = cursor_post(
            "GetFilteredUsageEvents",
            {"startDate": str(start_ms), "endDate": str(now_ms), "page": page, "pageSize": 500},
            timeout=min(8.0, max(1.0, remain)),
        )
        if not data:
            break
        batch = data.get("usageEventsDisplay") or []
        events.extend(batch)
        try:
            total = int(data.get("totalUsageEventsCount") or 0)
        except (TypeError, ValueError):
            total = 0
        if not batch or len(events) >= total:
            break
    return events


def cursor_daily(events):
    """Bucket events into per-day cost/token rows, keyed by local date."""
    buckets = {}
    for ev in events:
        try:
            ts = int(ev.get("timestamp") or 0) / 1000.0
        except (TypeError, ValueError):
            continue
        if ts <= 0:
            continue
        try:
            day = datetime.fromtimestamp(ts).astimezone().date().isoformat()
        except (OverflowError, OSError, ValueError):
            continue
        usage = ev.get("tokenUsage") or {}
        try:
            cents = float(usage.get("totalCents") or 0.0)
        except (TypeError, ValueError):
            cents = 0.0
        tokens = 0
        for field in CURSOR_TOKEN_FIELDS:
            try:
                tokens += int(usage.get(field) or 0)
            except (TypeError, ValueError):
                pass
        bucket = buckets.setdefault(day, {"date": day, "totalCost": 0.0, "totalTokens": 0})
        bucket["totalCost"] += cents / 100.0
        bucket["totalTokens"] += tokens
    return [buckets[key] for key in sorted(buckets)]


def attach_cursor_cost(row, deadline=None):
    daily = cursor_daily(cursor_events(30, deadline=deadline))
    if not daily:
        return
    today = datetime.now().astimezone().date()
    win1 = _window_sum(daily, 1, today)
    win7 = _window_sum(daily, 7, today)
    win30 = _window_sum(daily, 30, today)
    row["costs"] = [
        {"key": "today", "title": "Today", "cost": win1["cost"], "tokens": win1["tokens"]},
        {"key": "7d", "title": "Last 7 days", "cost": win7["cost"], "tokens": win7["tokens"]},
        {"key": "30d", "title": "Last 30 days", "cost": win30["cost"], "tokens": win30["tokens"]},
    ]
    charts = {}
    chart7 = render_cost_chart("cursor", 7, win7["values"])
    chart30 = render_cost_chart("cursor", 30, win30["values"])
    if chart7:
        charts["7"] = chart7
    if chart30:
        charts["30"] = chart30
    row["cost_charts"] = charts
    row["daily7"] = win7.get("values") or []


def fetch_cursor():
    row = empty_provider("cursor", "error")
    data = cursor_post("GetCurrentPeriodUsage")
    plan_usage = (data or {}).get("planUsage") or {}
    used = plan_usage.get("totalPercentUsed")
    if used is None:
        return row

    reset_iso = ms_to_iso((data or {}).get("billingCycleEnd"))
    start_iso = ms_to_iso((data or {}).get("billingCycleStart"))
    windows = []
    for name, key in (
        ("Total", "totalPercentUsed"),
        ("Auto + Composer", "autoPercentUsed"),
        ("API", "apiPercentUsed"),
    ):
        value = plan_usage.get(key)
        if value is None:
            continue
        windows.append(make_window(name, value, reset_iso, start_iso))

    row.update(
        {
            "status": "ok",
            "plan": cursor_plan_label(),
            "used": used,
            "label": fmt_pct(used),
            "hint": fmt_pace_hint(usage_pace(used, start_iso, reset_iso)),
            "reset": fmt_reset(reset_iso),
            "reset_at": fmt_reset_at(reset_iso),
            "period": "monthly",
            "period_range": fmt_period_range(start_iso, reset_iso),
            "period_end": reset_iso or "",
            "windows": windows,
        }
    )

    # Dollar fields are a retail-price estimate, not the kill switch.
    # Enforcement is autoPercentUsed / apiPercentUsed (100% = actually limited).
    # totalSpend = includedSpend + bonusSpend; bonus is "list $ above the
    # advertised $400 still billed as INCLUDED_IN_ULTRA", not a leftover gift.
    def _cents(key):
        raw = plan_usage.get(key)
        if raw is None:
            return None
        try:
            return float(raw)
        except (TypeError, ValueError):
            return None

    total, included, limit, bonus = (
        _cents("totalSpend"),
        _cents("includedSpend"),
        _cents("limit"),
        _cents("bonusSpend"),
    )
    if total is not None:
        row["spend"] = round(total / 100.0, 2)
        row["spend_limit"] = None
    hints = []
    if included is not None and limit:
        hints.append(f"套餐标价 ${limit / 100.0:.0f} 已计满")
    if bonus and bonus > 0:
        hints.append(f"超出部分 ${bonus / 100.0:.2f} 仍算 included，未按量扣费")
    hints.append("第三方能不能用看 API 百分比")
    row["spend_hint"] = " · ".join(hints)

    try:
        attach_cursor_cost(row, deadline=time.time() + 10)
    except Exception:
        pass
    return row


FETCHERS = {"cursor": fetch_cursor, "grok": fetch_grok}


def cache_row_ready(cached, pid):
    row = (cached.get("rows") or {}).get(pid)
    if not row:
        return False
    if row.get("status") != "ok":
        return False
    end = parse_iso(row.get("period_end"))
    if end and datetime.now(timezone.utc) >= end:
        return False
    return True


def main():
    want = sys.argv[1] if len(sys.argv) > 1 else "all"
    requested = PROVIDERS if want in ("", "all") else (want,)
    cached = load_cache()
    now = time.time()
    fresh = now - float(cached.get("ts") or 0) < TTL
    need = [p for p in requested if not cache_row_ready(cached, p) or not fresh]

    if need:
        fd = acquire_lock()
        if fd is None:
            for pid in requested:
                row = cached.get("rows", {}).get(pid) or empty_provider(pid, "stale")
                if row.get("status") == "ok":
                    row = dict(row)
                    row["status"] = "stale"
                emit(row)
            return
        try:
            cached = load_cache()
            now = time.time()
            fresh = now - float(cached.get("ts") or 0) < TTL
            need = [p for p in requested if not cache_row_ready(cached, p) or not fresh]
            rows = dict(cached.get("rows") or {})
            from concurrent.futures import ThreadPoolExecutor, as_completed

            fetched_rows = {}
            timeouts = {"cursor": 18, "grok": 12}

            def keep(pid, fetched):
                if fetched.get("status") != "ok" and rows.get(pid, {}).get("status") == "ok":
                    old = dict(rows[pid])
                    old["status"] = "stale"
                    rows[pid] = old
                else:
                    rows[pid] = fetched
                save_cache({"ts": time.time(), "rows": rows})

            with ThreadPoolExecutor(max_workers=max(1, len(need))) as pool:
                futs = {pool.submit(FETCHERS[pid]): pid for pid in need}
                pending = dict(futs)
                try:
                    for fut in as_completed(futs, timeout=22):
                        pid = pending.pop(fut, None)
                        if pid is None:
                            continue
                        try:
                            fetched_rows[pid] = fut.result(timeout=timeouts.get(pid, 15))
                        except Exception:
                            fetched_rows[pid] = empty_provider(pid, "error")
                        keep(pid, fetched_rows[pid])
                except TimeoutError:
                    for fut, pid in list(pending.items()):
                        fut.cancel()
                        if pid not in fetched_rows:
                            keep(pid, empty_provider(pid, "error"))
            cached = {"ts": time.time(), "rows": rows}
        finally:
            import fcntl

            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    for pid in requested:
        emit(cached.get("rows", {}).get(pid) or empty_provider(pid, "error"))


if __name__ == "__main__":
    main()
