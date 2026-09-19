local settings = require("settings")
local colors = require("colors")

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", "calendar", {
  icon = { drawing = false },
  label = {
    color = colors.white,
    padding_right = 10,
    padding_left = 10,
    align = "right",
    font = { family = settings.font.numbers, size = 12.0 },
  },
  position = "right",
  update_freq = 30,
  padding_left = 1,
  padding_right = 1,
  -- 背景交给 items/init.lua 的 bg_cal 胶囊，避免双重底
  background = { drawing = false },
  click_script = "open -a 'Calendar'"
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set({ label = os.date("%b.%d %H:%M") })
end)
