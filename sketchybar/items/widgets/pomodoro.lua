local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local M = {}

-- Pomodoro settings
local work_duration = 25 * 60
local break_duration = 5 * 60

-- State
local state = {
  is_running = false,
  is_break = false,
  remaining_seconds = work_duration,
  total_seconds = work_duration,
  dnd_enabled = false,  -- Track DND state
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

-- Main pomodoro item (icon + time label)
M.pomodoro = sbar.add("item", "widgets.pomodoro", {
  position = "right",
  icon = {
    string = icons.pomodoro.paused,
    color = colors.grey,
    font = { size = 16.0 },
    padding_left = 6,
    padding_right = 4,
  },
  label = {
    string = format_time(work_duration),
    font = { family = settings.font.numbers, size = 13.0 },
    color = colors.grey,
    padding_right = 6,
  },
  update_freq = 1,
})

-- Background bracket
M.bracket = sbar.add("bracket", "widgets.pomodoro.bracket", {
  M.pomodoro.name,
}, {
  background = {
    color = colors.with_alpha(colors.bg1, 0.8),
    border_color = colors.with_alpha(colors.bg2, 0.8),
    border_width = 2,
    corner_radius = 9,
  },
  popup = { align = "center", height = 24 },
})

-- Spacing after the group
sbar.add("item", "widgets.pomodoro.padding", {
  position = "right",
  width = settings.group_paddings,
})

-- Update the display
local function update_display()
  local progress = state.remaining_seconds / state.total_seconds
  local icon, icon_color, label_color

  if not state.is_running then
    icon = icons.pomodoro.paused
    icon_color = colors.grey
    label_color = colors.grey
  elseif state.is_break then
    icon = icons.pomodoro["break"]
    icon_color = colors.green
    label_color = colors.green
  else
    icon = icons.pomodoro.work
    icon_color = colors.orange
    label_color = colors.white
    -- Urgency coloring in last quarter
    if progress < 0.25 then
      label_color = colors.red
    end
  end

  sbar.animate("tanh", 10, function()
    M.pomodoro:set({
      icon = { string = icon, color = icon_color },
      label = {
        string = format_time(state.remaining_seconds),
        color = label_color,
      },
    })
  end)
end

-- Reset timer
local function reset_timer()
  state.is_running = false
  state.is_break = false
  state.remaining_seconds = work_duration
  state.total_seconds = work_duration
  set_dnd(false)  -- Disable DND when resetting
  update_display()
end

-- Timer tick
local function tick()
  if not state.is_running then return end

  state.remaining_seconds = state.remaining_seconds - 1

  if state.remaining_seconds <= 0 then
    state.is_break = not state.is_break
    state.remaining_seconds = state.is_break and break_duration or work_duration
    state.total_seconds = state.remaining_seconds

    local title = "Pomodoro"
    local message = state.is_break and "Time for a break!" or "Back to work!"
    sbar.exec(string.format(
      [[osascript -e 'display notification "%s" with title "%s" sound name "Glass"']],
      message, title
    ))

    -- Toggle DND based on work/break state
    set_dnd(not state.is_break)
  end

  update_display()
end

-- Subscribe to timer updates
M.pomodoro:subscribe({ "routine", "system_woke" }, tick)

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

-- Work duration options
local work_times = { 15, 25, 30, 45, 60 }
for _, mins in ipairs(work_times) do
  local is_selected = (mins == 25)
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
  local is_selected = (mins == 5)
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
  reset_timer()
  M.bracket:set({ popup = { drawing = false } })
end)

-- Click handlers
M.pomodoro:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    -- Update status row
    local status_text, status_icon, status_color
    if not state.is_running then
      status_text = "Paused"
      status_icon = icons.pomodoro.paused
      status_color = colors.grey
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
      label = { string = status_text, color = status_color },
    })
    M.bracket:set({ popup = { drawing = "toggle" } })
  else
    state.is_running = not state.is_running
    -- Toggle DND: enable when starting work, disable when pausing or on break
    if state.is_running then
      set_dnd(not state.is_break)
    else
      set_dnd(false)
    end
    update_display()
  end
end)

-- Close popup when mouse exits
M.pomodoro:subscribe("mouse.exited.global", function()
  M.bracket:set({ popup = { drawing = false } })
end)

-- Initialize display
update_display()

return M
