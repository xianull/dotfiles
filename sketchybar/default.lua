local settings = require("settings")
local colors = require("colors")

local cap = settings.capsule or {}
local r = cap.corner_radius or 12

-- Equivalent to the --default domain
sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      size = 14.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = r } },
  },
  label = {
    font = {
      family = settings.font.text,
      size = 13.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    height = 26,
    corner_radius = r,
    border_width = 0,
    border_color = colors.transparent,
    image = {
      corner_radius = 8,
      border_color = colors.grey,
      border_width = 0,
    }
  },
  popup = {
    background = {
      border_width = 0,
      corner_radius = r,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 50,
  },
  padding_left = 5,
  padding_right = 5,
  scroll_texts = true,
})
