local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local M = {}

-- Pomodoro settings (defaults; overridden by shared vault config)
local work_duration = 25 * 60
local break_duration = 5 * 60
local long_break_duration = 15 * 60
local SESSIONS_PER_LONG_BREAK = 4

-- Persistence file (legacy local) + vault focus-state (shared with Obsidian)
local STATE_FILE = os.getenv("HOME") .. "/.cache/sketchybar/pomodoro_state.lua"
-- Pure Lua resolver — never io.popen during load (pclose blocks sketchybarrc)
local vault_res = require("helpers.obsidian_vault")
local VAULT = vault_res.path()
local FOCUS_CTL = VAULT .. "/Settings/Scripts/focus_ctl.py"
-- SketchyBar exec 会把中文路径拆坏；走纯 ASCII 包装脚本
local FOCUS_WRAP = (os.getenv("HOME") or "") .. "/.config/sketchybar/helpers/focus_ctl.sh"
local FOCUS_STATE = VAULT .. "/Settings/cache/focus-state.json"
-- 与 focus_ctl / Home 看板共用：工作时长、休息时长
local CONFIG_FILE = VAULT .. "/Settings/cache/pomodoro-config.json"

local function focus_ctl_cmd(args)
  return string.format(
    "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; %q %s 2>/dev/null",
    FOCUS_WRAP,
    args
  )
end

local function load_config()
  local f = io.open(CONFIG_FILE, "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return end
  local w = tonumber(raw:match('"work_sec"%s*:%s*(%d+)'))
  local b = tonumber(raw:match('"break_sec"%s*:%s*(%d+)'))
  local lb = tonumber(raw:match('"long_break_sec"%s*:%s*(%d+)'))
  local s = tonumber(raw:match('"sessions_per_long_break"%s*:%s*(%d+)'))
  if w and w >= 60 then work_duration = w end
  if b and b >= 60 then break_duration = b end
  if lb and lb >= 60 then long_break_duration = lb end
  if s and s >= 1 then SESSIONS_PER_LONG_BREAK = s end
end

local function save_config()
  os.execute(string.format("mkdir -p %q", VAULT .. "/Settings/cache"))
  local f = io.open(CONFIG_FILE, "w")
  if not f then return end
  f:write(string.format(
    '{\n  "v": 1,\n  "work_sec": %d,\n  "break_sec": %d,\n  "long_break_sec": %d,\n  "sessions_per_long_break": %d,\n  "updated_at": %d\n}\n',
    work_duration,
    break_duration,
    long_break_duration,
    SESSIONS_PER_LONG_BREAK,
    os.time()
  ))
  f:close()
end

-- 启动时读共享配置（SketchyBar 弹窗改的时长在这里持久化）
load_config()

-- State
local state = {
  is_running = false,
  is_break = false,
  is_long_break = false,
  remaining_seconds = work_duration,
  total_seconds = work_duration,
  completed_sessions = 0,
  dnd_enabled = false,  -- Track DND state
  -- shared focus fields
  mode = "idle",          -- idle | task | mindfulness | pomodoro
  label = nil,
  task_path = nil,
  task_title = nil,
}

-- Toggle Do Not Disturb mode via Shortcuts
local function set_dnd(enabled)
  if state.dnd_enabled == enabled then return end

  -- Use "DND On" or "DND Off" shortcut
  local shortcut = enabled and "DND On" or "DND Off"
  sbar.exec("shortcuts run '" .. shortcut .. "' 2>/dev/null &", function()
    state.dnd_enabled = enabled
  end)
end

-- Format time as MM:SS
local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

-- Persistence: write state as plain lua so we can dofile it back
local function save_state()
  os.execute("mkdir -p " .. STATE_FILE:match("(.*)/"))
  local f = io.open(STATE_FILE, "w")
  if not f then return end
  -- If running, persist phase_end_time so reload preserves the actual elapsed time
  local phase_end = state.is_running and (os.time() + state.remaining_seconds) or nil
  f:write(string.format(
    "return { is_running=%s, is_break=%s, is_long_break=%s, remaining=%d, total=%d, completed=%d, phase_end=%s, mode=%q, label=%s }\n",
    tostring(state.is_running),
    tostring(state.is_break),
    tostring(state.is_long_break),
    state.remaining_seconds,
    state.total_seconds,
    state.completed_sessions,
    phase_end and tostring(phase_end) or "nil",
    state.mode or "idle",
    state.label and string.format("%q", state.label) or "nil"
  ))
  f:close()
end

-- sbar.exec JSON-decodes focus_ctl output into a table. Never call :match
-- on that payload — a nil/table :match used to tight-loop the lua runtime
-- and fill sketchybar.out.log (gigabytes).
local function apply_focus_fields(mode, running, is_break, is_long, rem, total, phase_end, label, task_title, task_path, completed)
  mode = mode or "idle"
  if mode == "idle" then
    state.mode = "idle"
    state.is_running = false
    state.is_break = false
    state.is_long_break = false
    state.label = nil
    state.task_path = nil
    state.task_title = nil
    state.remaining_seconds = work_duration
    state.total_seconds = work_duration
    return true
  end

  state.mode = mode
  state.is_running = not not running
  state.is_break = not not is_break
  state.is_long_break = not not is_long
  if phase_end and running then
    local r = phase_end - os.time()
    state.remaining_seconds = r > 0 and r or 0
  elseif rem then
    state.remaining_seconds = math.max(0, rem)
  end
  if total and total > 0 then
    state.total_seconds = total
  end
  if completed then state.completed_sessions = completed end
  state.label = label
  state.task_title = task_title or label
  state.task_path = task_path
  return true
end

local function apply_focus_json(raw)
  if type(raw) == "table" then
    local t = type(raw.state) == "table" and raw.state or raw
    local task = type(t.task) == "table" and t.task or {}
    return apply_focus_fields(
      t.mode,
      t.is_running == true,
      t.is_break == true,
      t.is_long_break == true,
      tonumber(t.remaining_sec),
      tonumber(t.total_sec) or tonumber(t.duration_sec),
      tonumber(t.phase_end),
      t.label,
      task.title or t.title,
      task.path,
      tonumber(t.completed_sessions)
    )
  end
  if type(raw) ~= "string" or raw == "" then return false end
  -- Prefer nested "state":{...} when present (phase-complete / stop wrappers)
  local payload = raw:match('"state"%s*:%s*(%b{})') or raw

  local task_blob = payload:match('"task"%s*:%s*(%b{})') or ""
  return apply_focus_fields(
    payload:match('"mode"%s*:%s*"(.-)"') or "idle",
    payload:match('"is_running"%s*:%s*true') ~= nil,
    payload:match('"is_break"%s*:%s*true') ~= nil,
    payload:match('"is_long_break"%s*:%s*true') ~= nil,
    tonumber(payload:match('"remaining_sec"%s*:%s*(%-?%d+)')),
    tonumber(payload:match('"total_sec"%s*:%s*(%-?%d+)'))
      or tonumber(payload:match('"duration_sec"%s*:%s*(%-?%d+)')),
    tonumber(payload:match('"phase_end"%s*:%s*(%d+)')),
    payload:match('"label"%s*:%s*"(.-)"'),
    task_blob:match('"title"%s*:%s*"(.-)"') or payload:match('"title"%s*:%s*"(.-)"'),
    task_blob:match('"path"%s*:%s*"(.-)"'),
    tonumber(payload:match('"completed_sessions"%s*:%s*(%d+)'))
  )
end

-- Read vault focus-state.json directly (sketchybar env may lack python3 on PATH)
local function pull_focus_state(cb)
  local f = io.open(FOCUS_STATE, "r")
  local ok = false
  if f then
    local raw = f:read("*a")
    f:close()
    ok = apply_focus_json(raw or "")
  end
  if cb then cb(ok) end
  return ok
end

local function load_state()
  -- Prefer vault focus-state whenever present and not idle
  local f = io.open(FOCUS_STATE, "r")
  if f then
    local raw = f:read("*a")
    f:close()
    if raw and raw:match('"mode"%s*:%s*"(task|mindfulness|pomodoro)"') then
      if apply_focus_json(raw) then return end
    elseif raw and raw:match('"mode"%s*:%s*"idle"') then
      apply_focus_json(raw)
      -- fall through to local if idle — keep pure pomodoro local state
    end
  end

  local ok, data = pcall(dofile, STATE_FILE)
  if not ok or type(data) ~= "table" then return end
  state.is_running       = data.is_running or false
  state.is_break         = data.is_break or false
  state.is_long_break    = data.is_long_break or false
  state.total_seconds    = data.total or work_duration
  state.completed_sessions = data.completed or 0
  state.mode             = data.mode or "pomodoro"
  state.label            = data.label
  if state.is_running and data.phase_end then
    local remaining = data.phase_end - os.time()
    state.remaining_seconds = remaining > 0 and remaining or 0
  else
    state.remaining_seconds = data.remaining or state.total_seconds
  end
end

-- ============================================================================
-- Layout (position=right → add order is reverse of visual L→R):
--   visual:  [ ring | label | MM:SS ]
--   add:     time, then label/main, then ring
-- Progress bars removed — circular ring image instead.
local RING_SCRIPT = os.getenv("HOME") .. "/dotfiles/sketchybar/helpers/focus_ring.py"
local RING_PNG = "/tmp/sbar_focus_ring.png"
local last_ring_key = ""
local last_ring_ts = 0

-- Time label (rightmost) — wide enough for "MM:SS" with Maple Mono CN
M.time = sbar.add("item", "widgets.pomodoro.time", {
  position = "right",
  icon = { drawing = false },
  label = {
    string = format_time(work_duration),
    font = { family = settings.font.numbers, size = 12.0 },
    color = colors.grey,
    width = 52,
    align = "right",
    padding_left = 4,
    padding_right = 10,
  },
  update_freq = 1,
})

-- Mode chip (Mind / Break only — task title lives in todos popup)
M.pomodoro = sbar.add("item", "widgets.pomodoro", {
  position = "right",
  padding_left = 0,
  padding_right = 2,
  icon = { drawing = false },
  label = {
    string = "",
    drawing = false,
    font = { family = settings.font.text, size = 10.5 },
    color = colors.grey,
    padding_left = 0,
    padding_right = 2,
    max_chars = 6,
  },
})

-- Circular progress ring (balanced size: not huge, not tiny)
M.ring = sbar.add("item", "widgets.pomodoro.ring", {
  position = "right",
  width = 26,
  padding_left = 8,
  padding_right = 2,
  icon = { drawing = false },
  label = { drawing = false },
  background = {
    color = colors.transparent,
    height = 24,
    image = {
      string = RING_PNG,
      scale = 0.78,
    },
  },
})

-- Popup host (visual capsule is unified in focus_bracket.lua with todos)
M.bracket = sbar.add("bracket", "widgets.pomodoro.bracket", {
  M.ring.name,
  M.pomodoro.name,
  M.time.name,
}, {
  background = { drawing = false },
  popup = { align = "center", height = 24 },
})

-- 色板：运行蓝 · 休息绿 · 长休青 · 末段红 · 空闲灰（贴 Anu / 系统强调）
local function color_hex(mode_running, is_break, is_long, mode, progress)
  if not mode_running then return "8E8E93" end
  if is_break then
    return is_long and "64D2FF" or "30D158"
  end
  if mode == "mindfulness" then return "5B8DEF" end
  -- 剩余越少越偏红（分阶，避免一秒跳色）
  if progress < 0.12 then return "FF453A" end
  if progress < 0.28 then return "FF9F0A" end
  return "0A84FF"
end

local function update_ring(percent, hex)
  -- 量化到 2% + 同色 2s 内不重绘，减少每秒 PNG 抖动
  local pct_q = math.floor((percent or 0) / 2 + 0.5) * 2
  if pct_q > 100 then pct_q = 100 end
  local now = os.time()
  local key = string.format("%d_%s", pct_q, hex)
  if key == last_ring_key then return end
  if last_ring_key ~= "" and hex == (last_ring_key:match("_(.+)$") or "") then
    local prev = tonumber(last_ring_key:match("^(%d+)") or "-1") or -1
    if math.abs(pct_q - prev) < 2 and (now - last_ring_ts) < 2 then
      return
    end
  end
  last_ring_key = key
  last_ring_ts = now
  local cmd = string.format(
    [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; python3 %q %s %s %q 2>/dev/null]],
    RING_SCRIPT,
    tostring(pct_q),
    hex,
    RING_PNG
  )
  sbar.exec(cmd, function()
    M.ring:set({
      background = {
        image = {
          string = RING_PNG,
          scale = 0.78,
        },
      },
    })
  end)
end

-- Update the display
local function update_display()
  local total = state.total_seconds > 0 and state.total_seconds or work_duration
  local progress = state.remaining_seconds / total
  if progress < 0 then progress = 0 end
  if progress > 1 then progress = 1 end
  -- ring fill = elapsed portion
  local percent = (1 - progress) * 100
  local label_color

  if not state.is_running then
    label_color = colors.grey
  elseif state.is_break then
    label_color = state.is_long_break and colors.blue or colors.green
  elseif state.mode == "mindfulness" then
    label_color = colors.blue or colors.white
  else
    -- 工作：蓝；末段橙/红
    if progress < 0.12 then
      label_color = colors.red
    elseif progress < 0.28 then
      label_color = colors.orange or colors.yellow or colors.white
    else
      label_color = colors.blue or colors.white
    end
  end

  -- Only mode chip on the bar (no task title — see todos right-click popup)
  local tag = ""
  local show_tag = false
  if state.is_break then
    tag, show_tag = "休", true
  elseif state.mode == "mindfulness" then
    tag, show_tag = "念", true
  elseif not state.is_running and state.mode ~= "idle" then
    tag, show_tag = "‖", true -- paused marker
  end

  local hex = color_hex(state.is_running, state.is_break, state.is_long_break, state.mode, progress)
  update_ring(percent, hex)

  M.pomodoro:set({
    label = {
      string = tag,
      drawing = show_tag,
      color = label_color,
    },
  })
  M.time:set({
    label = {
      string = format_time(math.max(0, state.remaining_seconds)),
      color = label_color,
    },
  })
end

-- Advance to the next phase. Called when timer hits 0 or when user skips.
-- Returns true if a notification should fire.
local function advance_cycle(notify)
  if state.is_break then
    -- Break → Work
    state.is_break = false
    state.is_long_break = false
    state.remaining_seconds = work_duration
  else
    -- Work → Break (count this completed work session first)
    state.completed_sessions = state.completed_sessions + 1
    state.is_break = true
    state.is_long_break = (state.completed_sessions % SESSIONS_PER_LONG_BREAK == 0)
    state.remaining_seconds = state.is_long_break and long_break_duration or break_duration
  end
  state.total_seconds = state.remaining_seconds

  if notify then
    local message
    if state.is_long_break then
      message = "Long break! You earned it."
    elseif state.is_break then
      message = "Time for a break!"
    else
      message = "Back to work!"
    end
    sbar.exec(string.format(
      [[osascript -e 'display notification "%s" with title "Pomodoro" sound name "Glass"']],
      message
    ))
  end

  set_dnd(not state.is_break)
end

-- Reset timer
local function reset_timer()
  state.is_running = false
  state.is_break = false
  state.is_long_break = false
  state.remaining_seconds = work_duration
  state.total_seconds = work_duration
  state.completed_sessions = 0
  set_dnd(false)  -- Disable DND when resetting
  save_state()
  update_display()
end

-- Timer tick
local function tick()
  if not state.is_running then return end

  state.remaining_seconds = state.remaining_seconds - 1

  if state.remaining_seconds <= 0 then
    -- Obsidian-linked sessions: settle via focus_ctl then adopt result
    if state.mode == "task" or state.mode == "mindfulness" then
      if not state.is_break then
        local py = focus_ctl_cmd("phase-complete")
        sbar.exec(py, function(out)
          if out and out ~= "" then
            apply_focus_json(out)
          end
          -- re-read file as source of truth
          pull_focus_state()
          if state.mode == "idle" then
            state.remaining_seconds = work_duration
            state.total_seconds = work_duration
            state.is_running = false
            state.is_break = false
          end
          save_state()
          update_display()
          sbar.exec([[osascript -e 'display notification "Session complete" with title "Focus" sound name "Glass"']])
        end)
        state.remaining_seconds = 0
        update_display()
        return
      else
        -- break finished → idle for linked sessions
        local py = focus_ctl_cmd("stop --reason complete")
        sbar.exec(py, function()
          pull_focus_state()
          state.mode = "idle"
          state.is_running = false
          state.is_break = false
          state.label = nil
          state.remaining_seconds = work_duration
          state.total_seconds = work_duration
          save_state()
          update_display()
        end)
        return
      end
    end
    advance_cycle(true)
    save_state()
  end

  update_display()
end

-- Drive ticks from the time item (which has update_freq=1)
M.time:subscribe({ "routine", "system_woke" }, function()
  tick()
end)

-- Explicit focus_sync event from Obsidian / focus_ctl writers
sbar.add("event", "focus_sync")
local function on_focus_sync()
  pull_focus_state()
  save_state()
  update_display()
  if state.is_running and not state.is_break then
    set_dnd(true)
  elseif not state.is_running then
    set_dnd(false)
  end
end
M.time:subscribe("focus_sync", on_focus_sync)
M.pomodoro:subscribe("focus_sync", on_focus_sync)

-- Popup items
local popup_width = 150

-- Status row
M.status = sbar.add("item", "widgets.pomodoro.status", {
  position = "popup." .. M.bracket.name,
  icon = {
    string = icons.pomodoro.paused,
    color = colors.grey,
    font = { size = 14.0 },
    padding_left = 8,
    padding_right = 0,
  },
  label = {
    string = "Paused",
    font = { family = settings.font.text, size = 13.0 },
    color = colors.grey,
    padding_left = 4,
    padding_right = 8,
  },
  width = popup_width,
})

-- Divider
sbar.add("item", {
  position = "popup." .. M.bracket.name,
  icon = { drawing = false },
  label = { string = "Work", color = colors.orange, font = { size = 11.0 }, padding_left = 8 },
  width = popup_width,
})

-- Work duration options（选中态跟 shared config 对齐）
local work_times = { 15, 25, 30, 45, 60 }
for _, mins in ipairs(work_times) do
  local is_selected = (mins * 60 == work_duration)
  local item = sbar.add("item", "widgets.pomodoro.work." .. mins, {
    position = "popup." .. M.bracket.name,
    icon = {
      string = is_selected and "●" or "○",
      color = colors.orange,
      font = { size = 9.0 },
      padding_left = 12,
      padding_right = 0,
    },
    label = {
      string = mins .. " min",
      font = { size = 13.0 },
      color = is_selected and colors.white or colors.grey,
      padding_left = 4,
    },
    width = popup_width,
  })
  item:subscribe("mouse.clicked", function()
    work_duration = mins * 60
    save_config()
    if not state.is_running and not state.is_break then
      state.remaining_seconds = work_duration
      state.total_seconds = work_duration
    end
    for _, m in ipairs(work_times) do
      sbar.set("widgets.pomodoro.work." .. m, {
        icon = { string = m == mins and "●" or "○" },
        label = { color = m == mins and colors.white or colors.grey },
      })
    end
    update_display()
    M.bracket:set({ popup = { drawing = false } })
  end)
end

-- Divider
sbar.add("item", {
  position = "popup." .. M.bracket.name,
  icon = { drawing = false },
  label = { string = "Break", color = colors.green, font = { size = 11.0 }, padding_left = 8 },
  width = popup_width,
})

-- Break duration options
local break_times = { 5, 10, 15, 20 }
for _, mins in ipairs(break_times) do
  local is_selected = (mins * 60 == break_duration)
  local item = sbar.add("item", "widgets.pomodoro.break." .. mins, {
    position = "popup." .. M.bracket.name,
    icon = {
      string = is_selected and "●" or "○",
      color = colors.green,
      font = { size = 9.0 },
      padding_left = 12,
      padding_right = 0,
    },
    label = {
      string = mins .. " min",
      font = { size = 13.0 },
      color = is_selected and colors.white or colors.grey,
      padding_left = 4,
    },
    width = popup_width,
  })
  item:subscribe("mouse.clicked", function()
    break_duration = mins * 60
    save_config()
    if not state.is_running and state.is_break then
      state.remaining_seconds = break_duration
      state.total_seconds = break_duration
    end
    for _, m in ipairs(break_times) do
      sbar.set("widgets.pomodoro.break." .. m, {
        icon = { string = m == mins and "●" or "○" },
        label = { color = m == mins and colors.white or colors.grey },
      })
    end
    update_display()
    M.bracket:set({ popup = { drawing = false } })
  end)
end

-- Skip option (jumps to next phase immediately)
sbar.add("item", "widgets.pomodoro.skip", {
  position = "popup." .. M.bracket.name,
  icon = { drawing = false },
  label = {
    string = "Skip",
    color = colors.yellow,
    font = { size = 13.0 },
    padding_left = 12,
  },
  width = popup_width,
}):subscribe("mouse.clicked", function()
  -- Linked Obsidian sessions: settle + write diary, don't just skip locally
  if state.mode == "task" or state.mode == "mindfulness" then
    local py = focus_ctl_cmd("stop --reason complete")
    sbar.exec(py, function(out)
      if out and out ~= "" then apply_focus_json(out) end
      pull_focus_state()
      reset_timer()
      update_display()
      M.bracket:set({ popup = { drawing = false } })
    end)
    return
  end
  advance_cycle(false)
  save_state()
  update_display()
  M.bracket:set({ popup = { drawing = false } })
end)

-- Reset option at bottom
sbar.add("item", "widgets.pomodoro.reset", {
  position = "popup." .. M.bracket.name,
  icon = { drawing = false },
  label = {
    string = "Reset",
    color = colors.red,
    font = { size = 13.0 },
    padding_left = 12,
  },
  width = popup_width,
}):subscribe("mouse.clicked", function()
  if state.mode == "task" or state.mode == "mindfulness" then
    local py = focus_ctl_cmd("stop --reason complete")
    sbar.exec(py, function(out)
      if out and out ~= "" then apply_focus_json(out) end
      pull_focus_state()
      reset_timer()
      M.bracket:set({ popup = { drawing = false } })
    end)
    return
  end
  reset_timer()
  M.bracket:set({ popup = { drawing = false } })
end)

-- Build the session dots string: "●●●○" with `done` filled out of N.
local function session_dots()
  local done = state.completed_sessions % SESSIONS_PER_LONG_BREAK
  -- If we just finished a multiple of N, treat as a fresh cycle (all empty).
  if done == 0 and state.completed_sessions > 0 and state.is_long_break then
    done = SESSIONS_PER_LONG_BREAK
  end
  local dots = ""
  for i = 1, SESSIONS_PER_LONG_BREAK do
    dots = dots .. (i <= done and "●" or "○")
  end
  return dots
end

-- Click handler shared by icon, cells, and time
local function handle_click(env)
  if env.BUTTON == "right" then
    -- Update status row
    local status_text, status_icon, status_color
    if not state.is_running then
      status_text = "Paused"
      status_icon = icons.pomodoro.paused
      status_color = colors.grey
    elseif state.is_long_break then
      status_text = "Long Break"
      status_icon = icons.pomodoro["break"]
      status_color = colors.blue
    elseif state.is_break then
      status_text = "On Break"
      status_icon = icons.pomodoro["break"]
      status_color = colors.green
    else
      status_text = "Working"
      status_icon = icons.pomodoro.work
      status_color = colors.orange
    end
    M.status:set({
      icon = { string = status_icon, color = status_color },
      label = {
        string = status_text .. "  " .. session_dots(),
        color = status_color,
      },
    })
    M.bracket:set({ popup = { drawing = "toggle" } })
  else
    local will_run = not state.is_running
    -- Linked Obsidian sessions: pause/resume through focus_ctl
    if state.mode == "task" or state.mode == "mindfulness" then
      local sub = will_run and "resume" or "pause"
      -- Use env -i path fallbacks; write-side needs python (Obsidian already uses it)
      local py = focus_ctl_cmd(sub)
      sbar.exec(py, function(out)
        if out and out ~= "" then
          apply_focus_json(out)
        else
          -- local fallback toggle if python unavailable
          state.is_running = will_run
          if will_run then
            -- phase_end is managed in JSON; approximate locally
            state.remaining_seconds = state.remaining_seconds
          end
        end
        if will_run then set_dnd(not state.is_break) else set_dnd(false) end
        save_state()
        update_display()
      end)
      return
    end

    state.is_running = will_run
    if state.is_running and state.mode == "idle" then
      state.mode = "pomodoro"
    end
    -- Toggle DND: enable when starting work, disable when pausing or on break
    if state.is_running then
      set_dnd(not state.is_break)
    else
      set_dnd(false)
    end
    save_state()
    update_display()
  end
end

M.pomodoro:subscribe("mouse.clicked", handle_click)
M.time:subscribe("mouse.clicked", handle_click)
M.ring:subscribe("mouse.clicked", handle_click)

-- Close popup when mouse exits
local function close_popup()
  M.bracket:set({ popup = { drawing = false } })
end
M.pomodoro:subscribe("mouse.exited.global", close_popup)
M.time:subscribe("mouse.exited.global", close_popup)
M.ring:subscribe("mouse.exited.global", close_popup)

-- Restore previous state (counter, phase, running/paused, elapsed-while-down)
load_state()
-- If a phase ended while sketchybar was down, advance once silently so the
-- timer continues from the right place instead of sitting at 0:00.
if state.is_running and state.remaining_seconds <= 0 then
  advance_cycle(false)
  save_state()
end
-- Re-sync DND to match the loaded state.
if state.is_running and not state.is_break then
  set_dnd(true)
else
  set_dnd(false)
end

-- Initialize display
update_display()

return M
