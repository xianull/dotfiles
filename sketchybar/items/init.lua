require("items.apple")
require("items.menus")
require("items.spaces")
require("items.front_app")
require("items.calendar")
require("items.widgets")
-- Media last: no capsule; cover stays right, text grows left
require("items.media")

-- Capsule backgrounds — 左栏统一；日历单独；媒体无胶囊
local colors = require("colors")
local settings = require("settings")
local cap = settings.capsule or {}
local r = cap.corner_radius or 12
local h = cap.height or 30
local ba = cap.bg_alpha or 0.32
local boa = cap.border_alpha or 0.08

local glass = {
  color = colors.with_alpha(colors.bg1, ba),
  corner_radius = r,
  height = h,
  border_width = 1,
  border_color = colors.with_alpha(colors.white, boa),
}

-- Left: Apple + spaces + menus + stack + front_app
sbar.add("bracket", "bg_left", {
  "apple",
  '/space\\..*/',
  '/menu\\..*/',
  "front_app.stack",
  "front_app",
}, {
  background = glass,
  padding_right = 0,
})

-- Calendar alone
sbar.add("bracket", "bg_cal", {
  "calendar",
}, {
  background = glass,
})
