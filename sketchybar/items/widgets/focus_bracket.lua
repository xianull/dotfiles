-- Unified Focus group: Pomodoro + Obsidian todos share one capsule
local colors = require("colors")
local settings = require("settings")
local cap = settings.capsule or {}

-- Members are created by pomodoro.lua and obsidian_todos.lua (loaded first).

sbar.add("bracket", "widgets.focus.bracket", {
  "widgets.pomodoro.ring",
  "widgets.pomodoro",
  "widgets.pomodoro.time",
  "widgets.obsidian_todos",
}, {
  background = {
    color = colors.with_alpha(colors.bg1, cap.bg_alpha or 0.32),
    border_width = 1,
    border_color = colors.with_alpha(colors.white, cap.border_alpha or 0.08),
    corner_radius = cap.corner_radius or 12,
    height = cap.height or 30,
  },
})

sbar.add("item", "widgets.focus.padding", {
  position = "right",
  width = settings.group_paddings,
})
