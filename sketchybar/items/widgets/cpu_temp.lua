local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local island = require("items.widgets.sys_island")
local coerce = require("helpers.coerce")

-- 与其它 widget 一致：把 $CONFIG_DIR 留给 sketchybar 在 exec 时展开。
-- 不要在 require 时 os.getenv("CONFIG_DIR")——lua 主进程里经常是 nil，
-- 一 concatenate 就会炸掉整个 items 加载链（media 等都加载不到）。
local TEMP_BIN = "$CONFIG_DIR/helpers/cpu_temp/bin/cpu_temp"

local cpu_temp = sbar.add("item", "widgets.cpu_temp", {
  position = "right",
  drawing = island.expanded,
  icon = {
    string = icons.temperature._0,
    color = colors.green,
    font = { size = 14.0 },
    padding_left = 4,
    padding_right = 2,
  },
  label = {
    string = "--°",
    font = { family = settings.font.numbers, size = 11.0 },
    color = colors.white,
    width = 32,
    align = "right",
    padding_right = 4,
  },
  update_freq = 5,
})

local inflight = false
local function refresh()
  if inflight then return end
  inflight = true
  sbar.exec(TEMP_BIN, function(result)
    inflight = false
    local t = coerce.number(result)
    if not t then
      cpu_temp:set({
        icon = { string = icons.temperature._0, color = colors.grey },
        label = { string = "--°", color = colors.grey },
      })
      return
    end

    -- Thresholds tuned for hottest-sensor readings on Apple Silicon
    -- (cores can sit at 60-65°C on idle yet jump to 90+ under load).
    local icon, color
    if t >= 95 then
      icon, color = icons.temperature._66, colors.red
    elseif t >= 80 then
      icon, color = icons.temperature._66, colors.orange
    elseif t >= 65 then
      icon, color = icons.temperature._33, colors.yellow
    else
      icon, color = icons.temperature._0, colors.green
    end

    cpu_temp:set({
      icon = { string = icon, color = color },
      label = { string = t .. "°", color = color },
    })
  end)
end

cpu_temp:subscribe({ "routine", "system_woke" }, refresh)
cpu_temp:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

refresh()

return cpu_temp
