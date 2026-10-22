local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local sysmon = require("helpers.sysmon")
local island = require("items.widgets.sys_island")

-- GPU utilization from IOAccelerator "Device Utilization %" (no root).
-- SF Symbols 里 cpu 和 gpu 的图标几乎一样（都是芯片），去掉文字前缀后分不清；
-- GPU 用 Nerd Font 的显卡图标（󰢮）
local gpu = sysmon.graph("widgets.gpu", "󰢮", {
  drawing = island.expanded,
  update_freq = 2,
  icon_font = { family = settings.font.icons, size = 17.0 },
})

local inflight = false
local function refresh()
  if inflight then return end
  inflight = true
  sbar.exec(
    [[
      # Max Device Utilization % across GPU accelerators (Apple Silicon / discrete)
      util=$(ioreg -c IOAccelerator -r -d 1 2>/dev/null \
        | sed -n 's/.*"Device Utilization %"=\([0-9][0-9]*\).*/\1/p' \
        | sort -n | tail -1)
      if [ -n "$util" ]; then
        echo "$util"
      else
        echo ""
      fi
    ]],
    function(result)
      inflight = false
      local load = tonumber((result or ""):match("(%d+)"))
      if not load then
        sysmon.idle(gpu)
        return
      end
      sysmon.show(gpu, load, 60, 80)
    end
  )
end

gpu:subscribe({ "routine", "system_woke", "forced" }, refresh)
gpu:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

refresh()

return gpu
