local settings = require("settings")
local colors = require("colors")

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", "calendar", {
  icon = { drawing = false },
  label = {
    color = colors.white,
    padding_right = 8,
    padding_left = 8,
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  update_freq = 30,
  padding_left = 1,
  padding_right = 1,
  background = {
    color = colors.with_alpha(colors.bg1, 0.8),
    border_color = colors.with_alpha(colors.bg2, 0.8),
    border_width = 2,
    corner_radius = 9,
  },
  click_script = "open -a 'Calendar'"
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set({ label = os.date("%b.%d %H:%M") })
end)
