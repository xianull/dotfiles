local icons = require("icons")
local island = require("items.widgets.sys_island")
local sysmon = require("helpers.sysmon")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local cpu = sysmon.graph("widgets.cpu", icons.cpu, { drawing = island.expanded })

cpu:subscribe("cpu_update", function(env)
  -- Also available: env.user_load, env.sys_load
  local load = tonumber(env.total_load)
  if load then
    sysmon.show(cpu, load, 60, 80)
  else
    sysmon.idle(cpu)
  end
end)

cpu:subscribe("mouse.clicked", function(env)
  sbar.exec("open -a 'Activity Monitor'")
end)

-- Bracket and padding managed by wifi.lua (shared cpu+wifi bracket)
