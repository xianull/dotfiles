-- 番茄钟和 Obsidian 专注联动的逻辑测试（假 sbar + 可控时钟，不碰真实 bar / vault）
-- 用法：lua ~/dotfiles/sketchybar/helpers/test_pomodoro.lua
local root = arg[0]:match("^(.*)/helpers/[^/]+$") or "."
local vault = os.tmpname()
os.remove(vault)
os.execute("mkdir -p '" .. vault .. "/Settings/cache'")
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local NOW = 1000000
local real_time = os.time
os.time = function(t) if t then return real_time(t) end return NOW end
package.preload["icons"] = function() return { pomodoro = { paused = "P", work = "W", ["break"] = "B" } } end
package.preload["colors"] = function() return setmetatable({}, { __index = function() return 0 end }) end
package.preload["settings"] = function() return { font = { numbers = "x", text = "x" }, paddings = 1 } end
package.preload["helpers.obsidian_vault"] = function() return { path = function() return vault end } end
local items, execs, subs = {}, {}, {}
local function mk(name)
  local it = { name = name, props = {} }
  function it:set(p) for k, v in pairs(p) do self.props[k] = v end end
  function it:subscribe(ev, fn)
    local evs = type(ev) == "table" and ev or { ev }
    for _, e in ipairs(evs) do subs[name .. ":" .. e] = fn end
    return self
  end
  items[name] = it
  return it
end
sbar = {
  add = function(kind, name, props) if type(name) ~= "string" then name = kind .. #execs .. math.random() end local it = mk(name); if type(props) == "table" then it:set(props) end; return it end,
  exec = function(cmd, cb) table.insert(execs, { cmd = cmd, cb = cb }) end,
  set = function() end,
}
local f = io.open(vault .. "/Settings/cache/focus-state.json", "w")
f:write(string.format('{"mode": "task", "is_running": true, "is_break": false, "remaining_sec": 600, "total_sec": 1500, "phase_end": %d, "label": "写论文", "task": {"title": "写论文", "path": "a.md"}}', NOW + 600))
f:close()
local M = dofile(root .. "/items/widgets/pomodoro.lua")
local function shown() return items["widgets.pomodoro.time"].props.label.string end
local tick = subs["widgets.pomodoro.time:routine"]
local ok = true
local function check(name, cond, extra) print((cond and "PASS " or "FAIL ") .. name .. (extra and ("  " .. extra) or "")); ok = ok and cond end
check("restart adopts Obsidian task focus", shown() == "10:00", "shows " .. shown())
NOW = NOW + 1; tick()
check("1s later", shown() == "09:59", shown())
NOW = NOW + 300; subs["widgets.pomodoro.time:system_woke"]()
check("after 5 min sleep, single wake tick", shown() == "04:59", shown())
check("update_freq on while running", items["widgets.pomodoro.time"].props.update_freq == 1)
local function count(pat) local n = 0; for _, e in ipairs(execs) do if e.cmd:match(pat) then n = n + 1 end end; return n end
local function last(pat) local r; for _, e in ipairs(execs) do if e.cmd:match(pat) then r = e end end; return r end
NOW = NOW + 400; tick(); NOW = NOW + 1; tick(); NOW = NOW + 1; subs["widgets.pomodoro.time:system_woke"]()
check("phase-complete fired once across 3 ticks", count("phase%-complete") == 1, "count " .. count("phase%-complete"))
local g = io.open(vault .. "/Settings/cache/focus-state.json", "w"); g:write('{"mode": "idle", "is_running": false}'); g:close()
last("phase%-complete").cb({ ok = true, next = "idle", state = { mode = "idle", is_running = false } })
check("idle after settle", shown() == "25:00", shown())
check("completion notification sent", count("display notification \"Session complete\"") == 1)
check("update_freq off when idle", items["widgets.pomodoro.time"].props.update_freq == 0)
subs["widgets.pomodoro.time:mouse.clicked"]({ BUTTON = "left" })
check("click when idle → start pomodoro via focus_ctl", count("start %-%-mode pomodoro") == 1)
last("start %-%-mode pomodoro").cb({ mode = "pomodoro", is_running = true, is_break = false, remaining_sec = 1500, total_sec = 1500, phase_end = NOW + 1500 })
check("running after start", shown() == "25:00" and items["widgets.pomodoro.time"].props.update_freq == 1)
subs["widgets.pomodoro.time:mouse.clicked"]({ BUTTON = "left" })
check("click when running → pause", count("focus_ctl.sh%S* pause") == 1)
local h = io.open(vault .. "/Settings/cache/focus-state.json", "w")
h:write(string.format('{"mode": "mindfulness", "is_running": true, "remaining_sec": 300, "total_sec": 300, "phase_end": %d}', NOW + 300)); h:close()
last("pause").cb(nil)
subs["widgets.pomodoro.time:focus_sync"]()
check("focus_sync adopts file written by Home", shown() == "05:00" and items["widgets.pomodoro"].props.label.string == "念", shown())
os.execute("rm -rf '" .. vault .. "'")
os.exit(ok and 0 or 1)
