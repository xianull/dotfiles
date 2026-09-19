local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local coerce = require("helpers.coerce")

-- Memory used % ≈ 100 − free% from memory_pressure (system-reported).
-- Falls back to vm_stat (active + wired + compressor) / total if needed.
local memory = sbar.add("graph", "widgets.memory", 42, {
  position = "right",
  graph = { color = colors.blue },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.memory },
  label = {
    string = "mem ??%",
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
        memory:set({
          graph = { color = colors.grey },
          label = "mem ??%",
        })
        return
      end

      memory:push({ load / 100. })

      local color = colors.blue
      if load > 60 then
        if load < 75 then
          color = colors.yellow
        elseif load < 90 then
          color = colors.orange
        else
          color = colors.red
        end
      end

      memory:set({
        graph = { color = color },
        label = "mem " .. load .. "%",
      })
    end
  )
end

memory:subscribe({ "routine", "system_woke", "forced" }, refresh)
memory:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

refresh()

return memory
