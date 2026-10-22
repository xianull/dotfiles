"""python3 helpers/test_ai_usage.py —— 着色规则和仪表图文件名稳定性的最小自检。"""
import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone

os.environ["XDG_CACHE_HOME"] = tempfile.mkdtemp()  # 别碰真实缓存
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ai_usage as au

BASE = au.BAR_FILLS["cursor"]
assert au.pace_rgb("cursor", 79, 15) == au.RED  # 花得比时间快 5 倍
assert au.pace_rgb("cursor", 20, 15) == au.ORANGE  # 1.33 倍
assert au.pace_rgb("cursor", 11, 10) == BASE  # 1.1 倍，在容忍范围内
assert au.pace_rgb("cursor", 5, 1) == BASE  # 10% 以下不报警
assert au.pace_rgb("cursor", 7, 15) == BASE  # 花得比时间慢
assert au.pace_rgb("grok", 92, None) == au.ORANGE and au.pace_rgb("grok", 96, None) == au.RED
assert au.pace_rgb("grok", None, 10) == au.BAR_FILLS["grok"]

now = datetime.now(timezone.utc)
row = {
    "id": "cursor",
    "used": 7.0,
    "period_start": (now - timedelta(days=5)).isoformat(),
    "period_end": (now + timedelta(days=25)).isoformat(),
    "windows": [{"name": "Total", "used": 7.0}, {"name": "API", "used": 79.0, "expected": 15.0}],
}
path = au.render_mini(row)
assert path and os.path.exists(path)
assert au.render_mini(row) == path  # 画面没变，文件名不变
row["used"] = 40.0
assert au.render_mini(row) != path  # 画面变了，换文件名（SketchyBar 才会重画）

# Grok：只有共享分项，没有独立子额度；抓取失败（used=None）也不能抛
au.render_mini(dict(row, id="grok", windows=[{"name": "Build", "used": 17.0, "shared": True}]))
au.render_mini({"id": "grok", "used": None, "windows": []})

# CodexBar 来源：窗口条 / 余额型 / 报错 三种形状
def parse(item):
    row = au.empty_provider("x")
    au.parse_codexbar_usage(row, item, "X")
    return row


reset = (now + timedelta(days=3)).isoformat()
r = parse({"usage": {"loginMethod": "pro", "secondary": {"usedPercent": 44, "windowMinutes": 10080, "resetsAt": reset}},
           "rateWindowLabels": {"secondary": "Weekly"}, "credits": {"remaining": 1234.5}})
assert r["status"] == "ok" and r["used"] == 44 and r["plan"] == "X Pro" and r["windows"][0]["head"]
assert r["share"] == "Credits 1,234", r["share"]  # :,.0f 对 .5 取偶
r = parse({"usage": {"primary": {"usedPercent": 0, "resetDescription": "¥7.74 (Paid: ¥3.72)"}}})
assert r["status"] == "ok" and r["used"] is None and r["label"] == "¥7.74" and not r["windows"]
assert au.render_mini(dict(r, id="x")) == ""  # 余额型不画仪表
assert parse({"usage": {}})["status"] == "missing"
assert au.two_lines("Could not parse Claude usage: " + "word " * 30)[0].startswith("word")  # 去前缀、按词换行

# 配置：文件在但全注释 = 全关；文件不存在 = 默认
conf = os.path.join(tempfile.mkdtemp(), "ai_usage.conf")
au.CONFIG = type(au.CONFIG)(conf)
assert au.enabled_providers() == list(au.DEFAULT_ORDER)
open(conf, "w").write("# cursor\n# grok\n")
assert au.enabled_providers() == []
open(conf, "w").write("codex\ncursor # 注释\nnope\n")
assert au.enabled_providers() == ["codex", "cursor"]

# Claude：读 OMC HUD 缓存。新鲜 / 过期 / 窗口翻篇 / 无缓存
import json

hud = os.path.join(tempfile.mkdtemp(), "usage.json")
au.CLAUDE_HUD_CACHE = type(au.CONFIG)(hud)
assert au.claude_hud_usage() is None  # 文件不存在 → 让调用方退回 CodexBar


def write_hud(age_s, five=84, five_reset=timedelta(hours=1), weekly=64, weekly_reset=timedelta(days=2)):
    iso = lambda d: (now + d).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    json.dump({"lastSuccessAt": (now.timestamp() - age_s) * 1000,
               "data": {"fiveHourPercent": five, "fiveHourResetsAt": iso(five_reset),
                        "weeklyPercent": weekly, "weeklyResetsAt": iso(weekly_reset)}}, open(hud, "w"))


write_hud(30)
c = au.claude_hud_usage()
assert c["status"] == "ok" and c["used"] == 84 and [w["name"] for w in c["windows"]] == ["Session", "Weekly"]
assert c["windows"][0]["head"] and not c["windows"][1].get("head")
write_hud(3600)
c = au.claude_hud_usage()
assert c["status"] == "stale" and "OMC HUD" in c["hint"] and c["used"] == 84
write_hud(30, five_reset=-timedelta(minutes=5))  # 5 小时窗口已翻篇：只剩周窗口，且它成为主读数
c = au.claude_hud_usage()
assert [w["name"] for w in c["windows"]] == ["Weekly"] and c["used"] == 64
write_hud(30, five_reset=-timedelta(minutes=5), weekly_reset=-timedelta(minutes=5))
c = au.claude_hud_usage()
assert c["used"] is None and c["status"] == "stale"
json.dump({"data": {}}, open(hud, "w"))
assert au.claude_hud_usage() is None

# OpenCode Go：真实返回的形状 / 没有 usage / 某个窗口缺 percent
iso = lambda d: (now + d).strftime("%Y-%m-%dT%H:%M:%S.000Z")
w, start, reset = au.opencodego_windows({"usage": {"rolling": {"status": "ok", "percent": 15, "resetsAt": iso(timedelta(hours=3))},
                                                   "weekly": {"status": "ok", "percent": 34, "resetsAt": iso(timedelta(days=3))},
                                                   "monthly": {"status": "ok", "percent": 26, "resetsAt": iso(timedelta(days=20))}}})
assert [(x["name"], x["used"]) for x in w] == [("Rolling", 15), ("Weekly", 34), ("Monthly", 26)]
assert w[0]["head"] and not w[1]["head"] and reset == iso(timedelta(hours=3))
assert au.opencodego_windows({"usage": {"weekly": {"status": "ok"}}})[0] == []
assert au.opencodego_windows({"error": "nope"})[0] == [] and au.opencodego_windows(None)[0] == []
print("ok")
