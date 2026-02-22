local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local M = {}

-- Pomodoro settings (can be changed via popup)
local work_duration = 25 * 60  -- 25 minutes in seconds
local break_duration = 5 * 60  -- 5 minutes in seconds

-- State
local state = {
  is_running = false,
  is_break = false,
  remaining_seconds = work_duration,
}

-- Format time as MM:SS
local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

-- Update the display
local function update_display()
  local icon = state.is_break and icons.pomodoro["break"] or icons.pomodoro.work
  local color = state.is_break and colors.green or colors.orange

  if not state.is_running then
    icon = icons.pomodoro.paused
    color = colors.grey
  end

  M.pomodoro:set({
    icon = {
      string = icon,
      color = color,
    },
    label = {
      string = format_time(state.remaining_seconds),
      drawing = true,
    },
  })
end

-- Reset timer
local function reset_timer()
  state.is_running = false
  state.is_break = false
  state.remaining_seconds = work_duration
  update_display()
end

-- Timer tick
local function tick()
  if not state.is_running then
    return
  end

  state.remaining_seconds = state.remaining_seconds - 1

  if state.remaining_seconds <= 0 then
    -- Switch between work and break
    state.is_break = not state.is_break
    state.remaining_seconds = state.is_break and break_duration or work_duration

    -- Send notification
    local title = "Pomodoro"
    local message = state.is_break and "Time for a break!" or "Back to work!"
    sbar.exec(string.format(
      [[osascript -e 'display notification "%s" with title "%s" sound name "Glass"']],
      message, title
    ))
  end

  update_display()
end

-- Create the pomodoro item
M.pomodoro = sbar.add("item", "widgets.pomodoro", {
  position = "right",
  icon = {
    string = icons.pomodoro.paused,
    color = colors.grey,
  },
  label = {
    string = format_time(work_duration),
    font = { family = settings.font.numbers },
    drawing = true,
  },
  update_freq = 1,
})

-- Background bracket for styling (also used for popup)
M.bracket = sbar.add("bracket", "widgets.pomodoro.bracket", {
  M.pomodoro.name,
}, {
  background = { color = colors.bg1 },
  popup = { align = "center" }
})

-- Spacing after the group
sbar.add("item", "widgets.pomodoro.padding", {
  position = "right",
  width = settings.group_paddings,
})

-- Subscribe to timer updates
M.pomodoro:subscribe({ "routine", "system_woke" }, tick)

-- Popup header
sbar.add("item", "widgets.pomodoro.header", {
  position = "popup." .. M.bracket.name,
  icon = { string = "Pomodoro Settings", color = colors.white },
  label = { drawing = false },
  background = { color = colors.bg2 },
})

-- Work duration options
local work_times = { 15, 25, 30, 45, 60 }
for _, mins in ipairs(work_times) do
  local item = sbar.add("item", "widgets.pomodoro.work." .. mins, {
    position = "popup." .. M.bracket.name,
    icon = { string = "Work: " .. mins .. " min", color = colors.orange },
    label = { drawing = false },
  })
  item:subscribe("mouse.clicked", function()
    work_duration = mins * 60
    if not state.is_running and not state.is_break then
      state.remaining_seconds = work_duration
    end
    update_display()
    M.bracket:set({ popup = { drawing = false } })
    sbar.exec(string.format(
      [[osascript -e 'display notification "Work time set to %d minutes" with title "Pomodoro"']],
      mins
    ))
  end)
end

-- Break duration options
local break_times = { 5, 10, 15, 20 }
for _, mins in ipairs(break_times) do
  local item = sbar.add("item", "widgets.pomodoro.break." .. mins, {
    position = "popup." .. M.bracket.name,
    icon = { string = "Break: " .. mins .. " min", color = colors.green },
    label = { drawing = false },
  })
  item:subscribe("mouse.clicked", function()
    break_duration = mins * 60
    if not state.is_running and state.is_break then
      state.remaining_seconds = break_duration
    end
    update_display()
    M.bracket:set({ popup = { drawing = false } })
    sbar.exec(string.format(
      [[osascript -e 'display notification "Break time set to %d minutes" with title "Pomodoro"']],
      mins
    ))
  end)
end

-- Reset option
local reset_item = sbar.add("item", "widgets.pomodoro.reset", {
  position = "popup." .. M.bracket.name,
  icon = { string = "Reset Timer", color = colors.red },
  label = { drawing = false },
})
reset_item:subscribe("mouse.clicked", function()
  reset_timer()
  M.bracket:set({ popup = { drawing = false } })
end)

-- Click: left = toggle, right = show popup
M.pomodoro:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    M.bracket:set({ popup = { drawing = "toggle" } })
  else
    state.is_running = not state.is_running
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
