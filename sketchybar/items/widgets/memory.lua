local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local sysmon = require("helpers.sysmon")
local coerce = require("helpers.coerce")

-- Memory used % ≈ 100 − free% from memory_pressure (system-reported).
-- Falls back to vm_stat (active + wired + compressor) / total if needed.
local memory = sysmon.graph("widgets.memory", icons.memory, { update_freq = 2 })

local inflight = false
local function refresh()
  if inflight then return end
  inflight = true
  sbar.exec(
    [[
      free=$(memory_pressure 2>/dev/null | awk -F': *' '/System-wide memory free percentage/{gsub(/%/,"",$2); print $2; exit}')
      if [ -n "$free" ]; then
        used=$((100 - free))
        echo "$used"
        exit 0
      fi
      page=$(pagesize)
      total=$(sysctl -n hw.memsize)
      stats=$(vm_stat)
      active=$(echo "$stats" | awk '/Pages active/{gsub(/\./,""); print $3}')
      wired=$(echo "$stats" | awk '/Pages wired/{gsub(/\./,""); print $4}')
      compressed=$(echo "$stats" | awk '/compressor/{gsub(/\./,""); print $NF; exit}')
      active=${active:-0}; wired=${wired:-0}; compressed=${compressed:-0}
      used_bytes=$(( (active + wired + compressed) * page ))
      if [ "$total" -gt 0 ]; then
        echo $(( used_bytes * 100 / total ))
      else
        echo 0
      fi
    ]],
    function(result)
      inflight = false
      local load = coerce.number(result)
      if not load then
        sysmon.idle(memory)
        return
      end
      sysmon.show(memory, load, 75, 90)
    end
  )
end

memory:subscribe({ "routine", "system_woke", "forced" }, refresh)
memory:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

refresh()

return memory
