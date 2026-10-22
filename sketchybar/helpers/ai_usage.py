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
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

CATALOG_FILE = Path(__file__).with_name("ai_providers.tsv")


def load_catalog():
    """id → {title, kind, url}。Lua 读同一份（items/widgets/ai_usage.lua）。"""
    cat = {}
    try:
        for line in CATALOG_FILE.read_text(encoding="utf-8").splitlines():
            parts = line.split("\t")
            if line.startswith("#") or len(parts) < 3:
                continue
            cat[parts[0]] = {"title": parts[1], "kind": parts[2], "url": parts[3] if len(parts) > 3 else ""}
    except OSError:
        pass
    return cat


CATALOG = load_catalog() or {"cursor": {"title": "Cursor", "kind": "native"}, "grok": {"title": "Grok", "kind": "native"}}
KNOWN_PROVIDERS = tuple(CATALOG)
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
        return list(DEFAULT_ORDER)  # 没有配置文件才用默认；文件在但全注释 = 设置页里全关了
    out = []
    for line in lines:
        pid = line.split("#", 1)[0].strip().lower()
        if pid in KNOWN_PROVIDERS and pid not in out:
            out.append(pid)
    return out


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


def make_window(name, used, reset_iso, start_iso=None, shared=False, paced=True):
    pace = None if shared or not paced else usage_pace(used, start_iso, reset_iso)
    return {
        "name": name,
        "used": used,
        "shared": shared,
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
    """弹窗里的进度条，和栏上的仪表同一套画法：主题前景色填充，超前消耗才变橙 / 红，
    细线刻度 = 按时间该用到哪儿。6pt 圆头。"""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return ""
    BAR_DIR.mkdir(parents=True, exist_ok=True)
    path = BAR_DIR / f"{pid}_{idx}.png"
    scale = 2
    width, height = POPUP_PT * scale, 6 * scale
    inset = PAD_PT * scale
    inner_w = INNER_PT * scale
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = height / 2
    left, right = inset, inset + inner_w - 1
    draw.rounded_rectangle((left, 0, right, height - 1), radius=radius, fill=FG + (38,))
    try:
        pct = max(0.0, min(100.0, float(percent)))
    except (TypeError, ValueError):
        pct = 0.0
    fill_w = 0
    if pct >= 0.5:
        fill_w = min(max(int(round((inner_w - 1) * pct / 100.0)), height), inner_w - 1)
        draw.rounded_rectangle(
            (left, 0, left + fill_w, height - 1), radius=radius, fill=pace_rgb(pid, pct, expected, FG) + (235,)
        )
    if expected is not None:
        try:
            x = left + int(round((inner_w - 1) * max(0.0, min(100.0, float(expected))) / 100.0))
        except (TypeError, ValueError):
            x = None
        if x is not None:  # 压在填充上是暗线，落在空轨道上是亮线
            draw.line((x, 0, x, height - 1), fill=(0, 0, 0, 150) if x <= left + fill_w and fill_w else FG + (190,), width=1)
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
    draw.rectangle((inset, baseline_y, inset + inner_w - 1, baseline_y + 1), fill=FG + (38,))
    n = len(values)
    gap = 4 if n <= 10 else 2
    bar_w = max(6, (inner_w - gap * (n + 1)) // n)
    total = n * bar_w + (n - 1) * gap
    x0 = inset + max(0, (inner_w - total) // 2)
    mx = max(values) or 1.0
    rgb = FG
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


MINI_W, MINI_H = 42, 12  # pt；items/widgets/ai_usage.lua 里的 label 宽度要和这里一致
try:  # 主题前景色（Lua 通过环境变量传进来），栏上图标也是这个颜色
    FG = tuple(int(os.environ.get("AI_USAGE_FG", "")[i : i + 2], 16) for i in (0, 2, 4))
except ValueError:
    FG = (235, 219, 178)
RED, ORANGE = (251, 73, 52), (254, 128, 25)


def pace_rgb(pid, used, expected, normal=None):
    """按“花得是不是比时间快”着色，不只看百分比：used/expected 就是到重置时预计会用掉的倍数。
    normal：没事时的颜色，默认各家的品牌色；栏上的仪表传主题前景色，只在有事时才变橙 / 红。"""
    if used is not None:
        if used >= 95:
            return RED
        if used >= 90:
            return ORANGE
        if expected and used >= 10:  # 10% 以下别报警，周期刚开始时比值抖得厉害
            ratio = used / expected
            if ratio >= 1.6:
                return RED
            if ratio >= 1.2:
                return ORANGE
    return normal or BAR_FILLS.get(pid, (16, 163, 127))


def render_mini(row):
    """CodexBar 菜单栏图标的搬运：上粗下细两条。上 = 主额度；下 = 最紧的独立子额度
    （Cursor 的 API / Auto）。Grok 的产品分项只是同一个池的拆分，没有独立子额度，
    就用“周期已过去多少”顶上，两条一比就知道有没有超前。条上的刻度 = 按时间该用到哪儿。
    文件名带内容哈希：SketchyBar 对同一路径不一定重读图，换名才保证重画。"""
    used = row.get("used")
    if used is None:  # 没读数（失败 / 余额型）：不画空轨道，Lua 退回文字
        return ""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return ""
    import hashlib

    pid = row["id"]
    pace = usage_pace(used, row.get("period_start"), row.get("period_end"))
    expected = pace["expected"] if pace else None
    subs = [
        w
        for w in row.get("windows") or []
        if not w.get("shared")
        and not w.get("head")  # 主读数自己的窗口已经是上条
        and w.get("name") not in ("Total", "Credits")
        and w.get("used") is not None
    ]
    sub = max(subs, key=lambda w: w["used"], default=None)
    top = (used, expected, pace_rgb(pid, used, expected, FG) + (235,))
    if sub:
        low = (sub["used"], sub.get("expected"), pace_rgb(pid, sub["used"], sub.get("expected"), FG) + (235,))
    else:
        low = (expected, None, FG + (110,))

    scale = 2
    W, H = MINI_W * scale, MINI_H * scale

    def px(pct):
        return None if pct is None else int(round((W - 1) * min(max(float(pct), 0.0), 100.0) / 100.0))

    # 先落到像素再哈希：expected 随时间每秒都在变，用原始浮点数文件名会天天换
    bars = [(px(p) if p is not None and p >= 0.5 else None, px(e), rgba) for p, e, rgba in (top, low)]
    key = hashlib.md5(repr((bars, pid, FG, MINI_W, MINI_H)).encode()).hexdigest()[:8]
    BAR_DIR.mkdir(parents=True, exist_ok=True)
    for old in BAR_DIR.glob(f"{pid}_mini_*.png"):
        if key not in old.name:
            old.unlink(missing_ok=True)
    path = BAR_DIR / f"{pid}_mini_{key}.png"
    if path.exists():
        return str(path)

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for (fill_x, tick_x, rgba), y, h in zip(bars, (0, 9 * scale), (6 * scale, 3 * scale)):
        draw.rounded_rectangle((0, y, W - 1, y + h - 1), radius=h / 2, fill=FG + (38,))
        if fill_x is not None:
            fill_x = max(h, fill_x)
            draw.rounded_rectangle((0, y, fill_x, y + h - 1), radius=h / 2, fill=rgba)
        if tick_x is not None:  # 细线刻度：压在填充上是暗线，落在空轨道上是亮线，都不抢眼
            over = fill_x is not None and tick_x <= fill_x
            draw.line((tick_x, y, tick_x, y + h - 1), fill=(0, 0, 0, 150) if over else FG + (190,), width=1)
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
    print("\t".join(("M", row["id"], render_mini(row))))
    stamp = row.get("data_ts") or row.get("fetched")
    if stamp and row.get("status") in ("ok", "stale", "partial"):
        print("\t".join(("U", row["id"], str(int(stamp)))))
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


def acquire_lock(wait=0.0):
    """拿不到锁（别的刷新在跑）就返回 None；wait>0 时最多等这么多秒（手动刷新用）。"""
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(LOCK), os.O_CREAT | os.O_RDWR, 0o644)
    except OSError:
        return None
    import fcntl

    deadline = time.time() + wait
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return fd
        except OSError:
            if time.time() >= deadline:
                os.close(fd)
                return None
            time.sleep(0.2)


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
            "period_start": start_iso or "",
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


def set_costs(row, pid, daily):
    """daily：[{date, totalCost, totalTokens}]（Cursor 逐日聚合、`codexbar cost` 的 daily 都是这个形状）
    → 弹窗里的 今日 / 近 7 天 / 近 30 天 + 两张柱状图。"""
    if not daily:
        return
    today = datetime.now().astimezone().date()
    wins = {n: _window_sum(daily, n, today) for n in (1, 7, 30)}
    row["costs"] = [
        {"key": key, "title": title, "cost": wins[n]["cost"], "tokens": wins[n]["tokens"]}
        for key, title, n in (("today", "Today", 1), ("7d", "Last 7 days", 7), ("30d", "Last 30 days", 30))
    ]
    row["cost_charts"] = {
        str(n): path for n in (7, 30) if (path := render_cost_chart(pid, n, wins[n]["values"]))
    }


COST_TTL = 300  # 今天的花费 5 分钟刷一次；过去的日子收完一次就不再请求
COST_GRACE = 3600  # Cursor 入账有延迟：一天结束后再留 1 小时才算定稿
DAYS_CACHE = CACHE.with_name("cursor_days.json")


def cursor_day_cost(day_start, day_end):
    """一天的聚合花费。别改回分页拉事件：一个月 3.6 万条，每页 5 秒，拉不完就被截断，
    而且翻页时新事件会让页错位、重复计数。"""
    data = cursor_post(
        "GetAggregatedUsageEvents",
        {"startDate": str(int(day_start.timestamp() * 1000)), "endDate": str(int(day_end.timestamp() * 1000))},
        timeout=12,
    )
    if data is None:  # 失败；没有花费的日子返回的是空对象（protobuf JSON 省略零值）
        return None
    try:
        tokens = sum(
            int(data.get(k) or 0)
            for k in ("totalInputTokens", "totalOutputTokens", "totalCacheWriteTokens", "totalCacheReadTokens")
        )
        cost = float(data.get("totalCostCents") or 0.0) / 100.0
    except (TypeError, ValueError):
        return None
    return {"date": day_start.date().isoformat(), "totalCost": cost, "totalTokens": tokens}


def attach_cursor_cost(row, deadline=None):
    from concurrent.futures import ThreadPoolExecutor, wait

    cursor_state()  # 先在本线程读好 token：它先置 {} 再填充，线程池里并发读会拿到半成品
    now = time.time()
    today0 = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
    try:
        days = json.loads(DAYS_CACHE.read_text())
    except (OSError, ValueError):
        days = {}
    todo = []
    for back in range(30):  # 新的先收，7 天的图先完整
        start = today0 - timedelta(days=back)
        end = start + timedelta(days=1)
        entry = days.get(start.date().isoformat())
        # 收于「当天结束 + 宽限」之前的记录（今天，或昨天刚结束的）按 TTL 重收；之后收的才是定稿
        if entry is None or (entry["ts"] < end.timestamp() + COST_GRACE and now - entry["ts"] > (0 if FORCE else COST_TTL)):
            todo.append((start, end))
    if todo:
        pool = ThreadPoolExecutor(max_workers=8)
        futs = [pool.submit(cursor_day_cost, s, e) for s, e in todo]
        done, _ = wait(futs, timeout=max(1.0, (deadline or now + 10) - time.time()))
        pool.shutdown(wait=False, cancel_futures=True)
        for fut in done:
            try:
                rec = fut.result()
            except Exception:
                rec = None
            if rec:
                days[rec["date"]] = dict(rec, ts=now)  # 用请求发出前的时间，别用收到时的
        keep = {(today0 - timedelta(days=n)).date().isoformat() for n in range(45)}
        days = {k: v for k, v in days.items() if k in keep}
        DAYS_CACHE.parent.mkdir(parents=True, exist_ok=True)
        tmp = DAYS_CACHE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(days))
        tmp.replace(DAYS_CACHE)
    set_costs(row, "cursor", list(days.values()))


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
        # API（第三方模型）额度只展示接口返回的百分比：不画时间刻度，不推算耗尽时间
        windows.append(make_window(name, value, reset_iso, start_iso, paced=(key != "apiPercentUsed")))

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
            "period_start": start_iso or "",
            "period_end": reset_iso or "",
            "windows": windows,
        }
    )

    # 美元行只用接口返回的数：totalSpend / limit / remaining（单位：分），不加评语
    def _cents(key):
        try:
            return float(plan_usage[key])
        except (KeyError, TypeError, ValueError):
            return None

    total, limit, remaining = _cents("totalSpend"), _cents("limit"), _cents("remaining")
    if total is not None:
        row["spend"] = round(total / 100.0, 2)
        row["spend_limit"] = round(limit / 100.0, 2) if limit else None
    if remaining is not None:
        row["spend_hint"] = f"套餐额度 · 剩余 ${remaining / 100.0:,.2f}"

    try:
        attach_cursor_cost(row, deadline=time.time() + 10)
    except Exception:
        pass
    return row


FORCE = "--force" in sys.argv  # 卡片右上角的刷新按钮：绕过所有缓存 TTL
CB_TTL = 300  # CodexBar CLI 慢（Claude / Antigravity 要 10 秒），5 分钟一次够了
CB_COST = ("codex", "claude", "antigravity")  # `codexbar cost` 读这几家的本地日志
WINDOW_NAMES = {"primary": "Session", "secondary": "Weekly", "tertiary": "Monthly"}


def codexbar_json(*args, timeout=14):
    exe = shutil.which("codexbar")
    if not exe:
        return None
    try:
        out = subprocess.run(
            [exe, *args, "--format", "json", "--no-color"], capture_output=True, text=True, timeout=timeout,
            stdin=subprocess.DEVNULL
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    start, end = out.find("["), out.rfind("]")  # 日志行可能混在 stdout 里
    try:
        data = json.loads(out[start : end + 1])
    except ValueError:
        return None
    return data[0] if isinstance(data, list) and data else None


def two_lines(text, width=44):
    """弹窗一行放不下 44 个字符宽；错误信息按词拆成 hint + share 两行。"""
    import re
    import textwrap

    text = re.sub(r"^Could not parse \S+ usage:\s*", "", " ".join(str(text or "").split()))
    lines = (textwrap.wrap(text, width) + ["", ""])[:2]
    return lines[0], lines[1]


def fill_windows(row, windows, head_start, head_reset):
    """第一个窗口当主读数（和 CodexBar 菜单栏图标上条一致），其余留在弹窗的窗口条里。"""
    head = windows[0]
    start, end = parse_iso(head_start), parse_iso(head_reset)
    short = start is not None and end is not None and end - start < timedelta(days=1)  # 5 小时窗口写日期没意义
    row.update(
        status="ok",
        used=head["used"],
        label=head["label"],
        reset=head["reset"],
        reset_at=head["reset_at"],
        period=head["name"].lower(),
        period_range="" if short else fmt_period_range(head_start, head_reset),
        hint="",  # 主读数窗口的条下面已经有同一句节奏提示，顶部不再重复
        period_start=head_start,
        period_end=head_reset,
        windows=windows,
    )


def parse_codexbar_usage(row, item, title):
    """`codexbar usage --json` 的 primary / secondary / tertiary → 弹窗的窗口条。
    第一个有额度的窗口当主读数（和 CodexBar 菜单栏图标上条一致）。"""
    usage = item.get("usage") or {}
    labels = item.get("rateWindowLabels") or {}
    windows, balance, head_start, head_reset = [], "", "", ""
    for key in ("primary", "secondary", "tertiary"):
        w = usage.get(key)
        if not w:
            continue
        reset, mins, used = w.get("resetsAt") or "", w.get("windowMinutes"), w.get("usedPercent")
        if used is None or (not reset and not mins):  # 没有额度窗口：余额型（DeepSeek 的 ¥ 余额）
            balance = balance or w.get("resetDescription") or ""
            continue
        end = parse_iso(reset)
        start = (end - timedelta(minutes=mins)).isoformat() if end and mins else ""
        win = make_window(labels.get(key) or WINDOW_NAMES[key], used, reset, start)
        win["head"] = not windows
        if win["head"]:
            head_start, head_reset = start, reset
        windows.append(win)

    login = (usage.get("loginMethod") or (usage.get("identity") or {}).get("loginMethod") or "").strip()
    row["plan"] = f"{title} {login.title()}" if login and login.lower() != "offline" else title
    bits = [balance] if balance else []
    credits = (item.get("credits") or {}).get("remaining")
    if credits:
        bits.append(f"Credits {credits:,.0f}")
    resets = (usage.get("codexResetCredits") or {}).get("availableCount")
    if resets:
        bits.append(f"可用重置券 {resets} 张")
    row["share"] = "  ·  ".join(bits)
    if windows:
        fill_windows(row, windows, head_start, head_reset)
    elif balance:
        row.update(status="ok", label=balance.split()[0])
    else:
        row.update(status="missing", hint="没有额度数据" + (f"（{login}）" if login else ""))


def fetch_codexbar(pid):
    row = empty_provider(pid, "error")
    item = codexbar_json("usage", "--provider", pid)
    if item is None:
        row["hint"] = "codexbar 没有响应（没装或超时）"
    elif item.get("error"):
        row["hint"], row["share"] = two_lines((item["error"] or {}).get("message"))
        row["plan"] = CATALOG.get(pid, {}).get("title", pid)
    else:
        parse_codexbar_usage(row, item, CATALOG.get(pid, {}).get("title", pid))
    if pid in CB_COST:
        try:
            set_costs(row, pid, (codexbar_json("cost", "--provider", pid, timeout=6) or {}).get("daily"))
        except Exception:
            pass
        if row["status"] == "error" and row.get("costs"):
            row["status"] = "partial"  # 额度抓不到，本地花费照样能看
    return row


CLAUDE_HUD_CACHE = (
    Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
    / "plugins/oh-my-claudecode/.usage-cache-anthropic.json"
)
HUD_FRESH = 600  # HUD 只在 Claude Code 运行时刷新；超过 10 分钟标成 stale


def claude_hud_usage():
    """Claude 的 5 小时 / 周额度。CodexBar 在新版 claude CLI 上取不到：/usage 不再输出额度条，
    钥匙串里的 OAuth 它也没读。OMC HUD 已经用 OAuth 取好并缓存了，直接读缓存——
    不碰令牌，也不和 HUD 抢那个会限流的接口。没有缓存返回 None。"""
    try:
        cache = json.loads(CLAUDE_HUD_CACHE.read_text())
    except (OSError, ValueError):
        return None
    data = cache.get("data") or {}
    if data.get("fiveHourPercent") is None and data.get("weeklyPercent") is None:
        return None
    now = datetime.now(timezone.utc)
    windows, head_start, head_reset = [], "", ""
    for name, key, span in (
        ("Session", "fiveHour", timedelta(hours=5)),
        ("Weekly", "weekly", timedelta(days=7)),
        ("Sonnet", "sonnetWeekly", timedelta(days=7)),
    ):
        used, reset = data.get(key + "Percent"), data.get(key + "ResetsAt")
        end = parse_iso(reset)
        if used is None or end is None or end <= now:  # 窗口已翻篇：缓存里的百分比不再作数
            continue
        start = (end - span).isoformat()
        win = make_window(name, used, reset, start)
        win["head"] = not windows
        if win["head"]:
            head_start, head_reset = start, reset
        windows.append(win)

    row = empty_provider("claude", "stale")
    row["plan"] = "Claude"
    stamp = float(cache.get("lastSuccessAt") or cache.get("timestamp") or 0) / 1000.0
    row["data_ts"] = stamp
    age = time.time() - stamp
    if not windows:
        row["hint"] = "额度缓存已过期（OMC HUD 只在 Claude Code 运行时刷新）"
        return row
    fill_windows(row, windows, head_start, head_reset)
    if age >= HUD_FRESH:
        row["status"] = "stale"
        row["hint"] = "来自 OMC HUD 缓存，Claude Code 运行时才刷新"
    return row


def fetch_claude():
    row = claude_hud_usage()
    if row is None:
        return fetch_codexbar("claude")  # 没装 OMC：退回 CodexBar（新版 CLI 上通常只剩本地花费）
    try:
        set_costs(row, "claude", (codexbar_json("cost", "--provider", "claude", timeout=6) or {}).get("daily"))
    except Exception:
        pass
    return row


OPENCODE_AUTH = Path.home() / ".local" / "share" / "opencode" / "auth.json"
OPENCODE_GO_URL = "https://opencode.ai/zen/go/v1/usage"
# 返回形如 {"usage": {"rolling": {"status": "ok", "percent": 15, "resetsAt": ISO}, "weekly": {…}, "monthly": {…}}}
OCG_WINDOWS = (("Rolling", "rolling", timedelta(hours=5)), ("Weekly", "weekly", timedelta(days=7)), ("Monthly", "monthly", timedelta(days=30)))


def opencodego_keys():
    """和 OpenCode CLI 用同一份 auth.json。opencode-go 和 opencode（Zen）的 key 都能查 Go 用量，挨个试、过期的跳过。"""
    try:
        auth = json.loads(OPENCODE_AUTH.read_text())
    except (OSError, ValueError):
        auth = {}
    keys = [os.environ.get("OPENCODE_API_KEY")] + [(auth.get(k) or {}).get("key") for k in ("opencode-go", "opencode")]
    return list(dict.fromkeys(k for k in keys if k))


def opencodego_windows(data):
    """`zen/go/v1/usage` → (窗口条, 主窗口起点, 主窗口重置)。"""
    usage = data.get("usage") if isinstance(data, dict) else None
    windows, head_start, head_reset = [], "", ""
    for name, key, span in OCG_WINDOWS:
        w = usage.get(key) if isinstance(usage, dict) else None
        if not isinstance(w, dict) or w.get("percent") is None:
            continue
        reset = w.get("resetsAt") or ""
        end = parse_iso(reset)
        start = (end - span).isoformat() if end else ""  # ponytail: 月度按 30 天估起点，只影响节奏提示
        win = make_window(name, float(w["percent"]), reset, start or None)
        win["head"] = not windows
        if win["head"]:
            head_start, head_reset = start, reset
        windows.append(win)
    return windows, head_start, head_reset


def fetch_opencodego():
    row = empty_provider("opencodego", "error")
    row["plan"] = CATALOG.get("opencodego", {}).get("title", "OpenCode Go")
    row["status"] = "auth"  # 没有 key 或全部 401 时保持这个状态
    row["hint"], row["share"] = "没找到 OpenCode Go 的 API key", "终端运行 opencode auth login"
    data = None
    for key in opencodego_keys():
        req = urllib.request.Request(
            OPENCODE_GO_URL, headers={"Authorization": f"Bearer {key}", "Accept": "application/json", "User-Agent": "sketchybar-ai-usage"}
        )
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                data = json.loads(resp.read().decode())
            break
        except urllib.error.HTTPError as exc:
            if exc.code != 401:
                row.update(status="error", hint=f"opencode.ai 返回 {exc.code}", share="")
                return row
            expired = "expired" in exc.read().decode(errors="ignore")
            row["hint"], row["share"] = ("API key 已过期" if expired else "API key 无效"), "Console 新建 key → opencode auth login"
        except (urllib.error.URLError, TimeoutError, ValueError):
            row.update(status="error", hint="连不上 opencode.ai", share="")
            return row
    if data is None:
        return row
    row.update(status="error", hint="", share="")
    windows, head_start, head_reset = opencodego_windows(data)
    if not windows:
        row.update(status="missing", hint="接口没返回额度数据")
        return row
    fill_windows(row, windows, head_start, head_reset)
    return row


FETCHERS = {"cursor": fetch_cursor, "grok": fetch_grok, "claude": fetch_claude, "opencodego": fetch_opencodego}


def row_fresh(cached, pid):
    """缓存行还能不能直接用。原生源失败要尽快重试；CodexBar 那几家慢，成败都按 CB_TTL 隔开。"""
    row = (cached.get("rows") or {}).get(pid)
    if not row:
        return False
    codexbar = CATALOG.get(pid, {}).get("kind") == "codexbar"
    if not codexbar and row.get("status") != "ok":
        return False
    end = parse_iso(row.get("period_end"))
    if end and datetime.now(timezone.utc) >= end:
        return False
    return time.time() - float(row.get("attempted") or row.get("fetched") or 0) < (CB_TTL if codexbar else TTL)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    want = args[0] if args else "all"
    requested = PROVIDERS if want in ("", "all") else (want,)
    cached = load_cache()
    need = [p for p in requested if FORCE or not row_fresh(cached, p)]

    if need:
        fd = acquire_lock(wait=20.0 if FORCE else 0.0)
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
            need = [p for p in requested if FORCE or not row_fresh(cached, p)]
            rows = dict(cached.get("rows") or {})
            from concurrent.futures import ThreadPoolExecutor, as_completed
            from functools import partial

            fetched_rows = {}
            timeouts = {"cursor": 18, "grok": 12}

            def keep(pid, fetched):
                if fetched.get("status") not in ("ok", "auth") and rows.get(pid, {}).get("status") in ("ok", "stale"):
                    # 这次没抓到：留着上次的读数和它的数据时间，只记下“试过了”；
                    # key 过期 / 无效不是临时故障，不留旧读数，直接报错
                    rows[pid] = dict(rows[pid], status="stale", attempted=time.time())
                else:
                    rows[pid] = dict(fetched, fetched=time.time(), attempted=time.time())
                save_cache({"ts": time.time(), "rows": rows})

            with ThreadPoolExecutor(max_workers=max(1, len(need))) as pool:
                futs = {pool.submit(FETCHERS.get(pid) or partial(fetch_codexbar, pid)): pid for pid in need}
                pending = dict(futs)
                try:
                    for fut in as_completed(futs, timeout=32):
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
    try:
        main()
    except BrokenPipeError:
        # SketchyBar 重载 / 超时后不再读输出：安静退出，别往 err.log 里刷整段堆栈
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
