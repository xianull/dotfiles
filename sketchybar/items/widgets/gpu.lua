local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local island = require("items.widgets.sys_island")

-- GPU utilization from IOAccelerator "Device Utilization %" (no root).
local gpu = sbar.add("graph", "widgets.gpu", 42, {
  position = "right",
  drawing = island.expanded,
  graph = { color = colors.blue },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.gpu },
  label = {
    string = "gpu ??%",
    font = {
      family = settings.font.numbers,
      size = 9.0,
    },
    align = "right",
    padding_right = 0,
    width = 0,
    y_offset = 4,
  },
  update_freq = 2,
  padding_right = settings.paddings + 6,
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
        gpu:set({
          graph = { color = colors.grey },
          label = "gpu ??%",
        })
        return
      end

      gpu:push({ load / 100. })

      -- Same thresholds as CPU: utilization spikes under graphics load
      local color = colors.blue
      if load > 30 then
        if load < 60 then
          color = colors.yellow
        elseif load < 80 then
          color = colors.orange
        else
          color = colors.red
        end
      end

      gpu:set({
        graph = { color = color },
        label = "gpu " .. load .. "%",
      })
    end
  )
end

gpu:subscribe({ "routine", "system_woke", "forced" }, refresh)
gpu:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

refresh()

return gpu
