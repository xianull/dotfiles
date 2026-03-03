local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local slider_width = 100

local function get_volume_icon(volume)
  if volume >= 60 then
    return icons.volume._100
  elseif volume >= 30 then
    return icons.volume._66
  elseif volume >= 10 then
    return icons.volume._33
  elseif volume > 0 then
    return icons.volume._10
  else
    return icons.volume._0
  end
end

-- Inline slider (track starts at width 0, expands on volume change)
local volume_slider = sbar.add("slider", slider_width, {
  position = "right",
  slider = {
    highlight_color = colors.blue,
    width = 0,
    background = {
      height = 5,
      corner_radius = 3,
      color = colors.bg2,
    },
    knob = {
      string = "􀀁",
      drawing = false,
    },
  },
  icon = { drawing = false },
  label = { drawing = false },
  click_script = 'osascript -e "set volume output volume $PERCENTAGE"',
})

-- Volume icon (changes with volume level)
local volume_icon = sbar.add("item", "widgets.volume_icon", {
  position = "right",
  padding_left = 10,
  padding_right = 0,
  icon = {
    string = icons.volume._100,
    color = colors.grey,
    width = 0,
    align = "left",
    font = { size = 14.0 },
  },
  label = {
    string = icons.volume._100,
    width = 25,
    align = "left",
    font = { size = 14.0 },
  },
})

-- Shared bracket: volume + battery
sbar.add("bracket", "widgets.volume_battery.bracket", {
  "widgets.battery",
  volume_icon.name,
  volume_slider.name,
}, {
  background = {
    color = colors.with_alpha(colors.bg1, 0.8),
    border_color = colors.with_alpha(colors.bg2, 0.8),
    border_width = 2,
    corner_radius = 9,
  },
})

sbar.add("item", "widgets.volume_battery.padding", {
  position = "right",
  width = settings.group_paddings,
})

-- Collapse guard: only the latest timer can collapse the slider
local collapse_id = 0

volume_slider:subscribe("volume_change", function(env)
  local volume = tonumber(env.INFO)
  if not volume then return end

  volume_icon:set({ label = get_volume_icon(volume) })
  volume_slider:set({ slider = { percentage = volume } })

  -- Expand slider track
  sbar.animate("tanh", 10, function()
    volume_slider:set({ slider = { width = slider_width } })
  end)

  -- Auto-collapse after 2s if no newer volume change
  collapse_id = collapse_id + 1
  local my_id = collapse_id

  sbar.exec("sleep 2", function()
    if my_id == collapse_id then
      sbar.animate("tanh", 10, function()
        volume_slider:set({ slider = { width = 0 } })
      end)
    end
  end)
end)

-- Show knob on hover
volume_slider:subscribe("mouse.entered", function()
  volume_slider:set({ slider = { knob = { drawing = true } } })
end)

volume_slider:subscribe("mouse.exited", function()
  volume_slider:set({ slider = { knob = { drawing = false } } })
end)

-- Scroll to adjust volume
local function volume_scroll(env)
  local delta = tonumber(env.INFO.delta) or 0
  local modifier = env.INFO.modifier

  local step = 2
  if modifier == "ctrl" then
    step = 1
  elseif modifier == "shift" then
    step = 5
  end

  local change = delta * step
  sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. change .. ')"')
end

volume_icon:subscribe("mouse.scrolled", volume_scroll)
volume_slider:subscribe("mouse.scrolled", volume_scroll)

-- Right-click to open Sound preferences
volume_icon:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open /System/Library/PreferencePanes/Sound.prefPane")
  end
end)
