require("items.apple")
require("items.menus")
require("items.spaces")
-- Media widgets
-- require("items.media") -- simple media widget (disabled in favor of cava version)
--require("items.media_cava")
require("items.front_app")
require("items.calendar")

require("items.widgets")

-- Capsule backgrounds
local colors = require("colors")

-- Left capsule
sbar.add("bracket", "bg_left", {
  "apple", '/space\\..*/', '/menu\\..*/', "front_app",
}, {
  background = {
    color = colors.transparent,
    corner_radius = 15,
    height = 34,
    border_width = 0,
  }
})

-- Right capsule
sbar.add("bracket", "bg_right", {
  "calendar", '/widgets\\..*/',
}, {
  background = {
    color = colors.transparent,
    corner_radius = 15,
    height = 34,
    border_width = 0,
  }
})

