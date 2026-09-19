local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local coerce = require("helpers.coerce")

local SAS = "/opt/homebrew/bin/SwitchAudioSource"
local slider_width = 100
local MAX_DEVICES = 8
local POPUP_W = 220

local function get_volume_icon(volume, muted)
  if muted then return icons.volume._0 end
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

local function short_name(name)
  if not name or name == "" then return "扬声器" end
  -- 缩短过长设备名
  local s = name
  s = s:gsub("^MacBook Air", "MBA")
  s = s:gsub("^MacBook Pro", "MBP")
  s = s:gsub("扬声器$", "扬声器")
  if #s > 28 then
    s = s:sub(1, 26) .. "…"
  end
  return s
end

-- SF Symbols：按设备名匹配（icons.audio 已是苹果 SF）
local function device_sf_icon(name)
  local n = string.lower(name or "")
  local a = icons.audio or {}
  -- AirPods / Beats
  if n:find("airpods max", 1, true) or n:find("airpodsmax", 1, true) then
    return a.airpods_max or "􀪶"
  end
  if n:find("airpods", 1, true) or n:find("beats", 1, true) then
    -- Pro / 普通共用 airpods pro 形
    return a.airpods_pro or a.airpods or "􀪷"
  end
  if n:find("homepod", 1, true) then
    return "􀄥" -- homepod
  end
  -- 内置扬声器 / Mac
  if n:find("macbook", 1, true) or n:find("扬声器", 1, true) or n:find("speakers", 1, true)
    or n:find("内建", 1, true) or n:find("built%-in", 1, true) then
    return a.macbook or "􀟛"
  end
  if n:find("imac", 1, true) or n:find("mac mini", 1, true) or n:find("mac studio", 1, true)
    or n:find("mac pro", 1, true) then
    return a.macbook or "􀙗"
  end
  -- 显示器 / HDMI / DP / USB‑C 外放
  if n:find("display", 1, true) or n:find("hdmi", 1, true) or n:find("displayport", 1, true)
    or n:find("mpg", 1, true) or n:find("dell", 1, true) or n:find("lg ", 1, true)
    or n:find("monitor", 1, true) or n:find(" benq", 1, true) or n:find("msi", 1, true)
    or n:find("qd", 1, true) then
    return a.display or "􀢹"
  end
  if n:find("apple tv", 1, true) or n:find("appletv", 1, true) then
    return "􀡴"
  end
  -- 手机 / 平板（接力）
  if n:find("iphone", 1, true) or n:find("电话", 1, true) then
    return a.iphone or "􀟜"
  end
  if n:find("ipad", 1, true) then
    return a.ipad or "􀟠"
  end
  -- 耳机 / USB / 声卡
  if n:find("headphone", 1, true) or n:find("headset", 1, true) or n:find("耳机", 1, true) then
    return a.headphones or "􀑈"
  end
  if n:find("usb", 1, true) or n:find("realtek", 1, true) or n:find("dac", 1, true)
    or n:find("audio", 1, true) then
    return "􀟓" -- cable.connector / usb-ish
  end
  if n:find("bluetooth", 1, true) or n:find("bt ", 1, true) then
    return "􀂯"
  end
  return a.speaker or a.default or icons.volume._100 or "􀊠"
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

-- Volume icon + popup host
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
    color = colors.white,
  },
  popup = {
    align = "center",
    height = 28,
  },
})

local POP = "popup." .. volume_icon.name

-- Header
local header = sbar.add("item", "widgets.volume.header", {
  position = POP,
  icon = { drawing = false },
  label = {
    string = "输出设备",
    font = { family = settings.font.text, size = 11.0 },
    color = colors.grey,
    padding_left = 12,
    padding_right = 12,
  },
  width = POPUP_W,
})

local device_items = {}
for i = 1, MAX_DEVICES do
  local item = sbar.add("item", "widgets.volume.device." .. i, {
    position = POP,
    drawing = false,
    icon = {
      string = "􀊠",
      -- SF Symbols 用系统字体渲染（与 volume 图标一致）
      font = { style = "Regular", size = 14.0 },
      color = colors.grey,
      padding_left = 12,
      padding_right = 8,
      width = 22,
    },
    label = {
      string = "",
      font = { family = settings.font.text, size = 12.0 },
      color = colors.white,
      padding_right = 12,
      max_chars = 24,
      align = "left",
    },
    width = POPUP_W,
  })
  device_items[i] = item
  item:subscribe("mouse.clicked", function()
    local name = item._device_name
    if not name or name == "" then return end
    -- -s 按名称切换输出
    local cmd = string.format(
      [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; %q -t output -s %q 2>/dev/null; %q -c -t output 2>/dev/null]],
      SAS, name, SAS
    )
    sbar.exec(cmd, function(out)
      volume_icon:set({ popup = { drawing = false } })
      refresh_device_popup()
    end)
  end)
end

local footer = sbar.add("item", "widgets.volume.footer", {
  position = POP,
  icon = { drawing = false },
  label = {
    string = "系统声音设置 ↗",
    font = { family = settings.font.text, size = 12.0 },
    color = colors.blue or colors.grey,
    padding_left = 12,
    padding_right = 12,
  },
  width = POPUP_W,
})
footer:subscribe("mouse.clicked", function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.Sound-Settings.extension' 2>/dev/null || open /System/Library/PreferencePanes/Sound.prefPane")
  volume_icon:set({ popup = { drawing = false } })
end)

local cycle = sbar.add("item", "widgets.volume.cycle", {
  position = POP,
  icon = {
    string = "􀄫",
    font = { size = 11.0 },
    color = colors.grey,
    padding_left = 12,
    padding_right = 6,
  },
  label = {
    string = "下一个输出设备",
    font = { family = settings.font.text, size = 12.0 },
    color = colors.white,
    padding_right = 12,
  },
  width = POPUP_W,
})
cycle:subscribe("mouse.clicked", function()
  sbar.exec(
    string.format(
      [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; %q -t output -n 2>/dev/null]],
      SAS
    ),
    function()
      volume_icon:set({ popup = { drawing = false } })
      refresh_device_popup()
    end
  )
end)

function refresh_device_popup()
  local cmd = string.format(
    [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
if [ ! -x %q ]; then echo "ERR|no-switchaudio"; exit 0; fi
cur=$(%q -c -t output 2>/dev/null || true)
echo "CUR|$cur"
%q -a -t output 2>/dev/null | while IFS= read -r line; do
  [ -n "$line" ] && echo "DEV|$line"
done
]],
    SAS, SAS, SAS
  )
  sbar.exec(cmd, function(raw)
    raw = coerce.text(raw)
    local current = ""
    local devices = {}
    for line in (raw .. "\n"):gmatch("(.-)\n") do
      local cur = line:match("^CUR%|(.*)$")
      if cur then
        current = cur
      else
        local dev = line:match("^DEV%|(.*)$")
        if dev and dev ~= "" then
          devices[#devices + 1] = dev
        end
      end
      if line:match("^ERR%|") then
        header:set({
          label = { string = "未安装 SwitchAudioSource", color = colors.red },
        })
      end
    end

    if current ~= "" then
      header:set({
        label = {
          string = "输出 · " .. short_name(current),
          color = colors.grey,
        },
      })
    else
      header:set({ label = { string = "输出设备", color = colors.grey } })
    end

    for i = 1, MAX_DEVICES do
      local name = devices[i]
      if name then
        local selected = (name == current)
        local sf = device_sf_icon(name)
        device_items[i]._device_name = name
        device_items[i]:set({
          drawing = true,
          icon = {
            string = sf,
            font = { style = "Regular", size = 14.0 },
            color = selected and (colors.blue or colors.white) or colors.grey,
          },
          label = {
            -- 当前设备加轻标记，图标已用 SF 区分类型
            string = short_name(name) .. (selected and "  ✓" or ""),
            color = selected and colors.white or colors.with_alpha(colors.white, 0.78),
          },
        })
      else
        device_items[i]._device_name = nil
        device_items[i]:set({ drawing = false })
      end
    end
  end)
end

-- Shared bracket: volume + battery（系统岛）
local cap = settings.capsule or {}
sbar.add("bracket", "widgets.volume_battery.bracket", {
  "widgets.battery",
  volume_icon.name,
  volume_slider.name,
}, {
  background = {
    color = colors.with_alpha(colors.bg1, cap.bg_alpha or 0.32),
    border_width = 1,
    border_color = colors.with_alpha(colors.white, cap.border_alpha or 0.08),
    corner_radius = cap.corner_radius or 12,
    height = cap.height or 30,
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

  volume_icon:set({
    label = {
      string = get_volume_icon(volume, false),
      color = colors.white,
    },
  })
  volume_slider:set({ slider = { percentage = volume } })

  sbar.animate("sin", 10, function()
    volume_slider:set({ slider = { width = slider_width } })
  end)

  collapse_id = collapse_id + 1
  local my_id = collapse_id
  sbar.exec("sleep 2", function()
    if my_id == collapse_id then
      sbar.animate("sin", 10, function()
        volume_slider:set({ slider = { width = 0 } })
      end)
    end
  end)
end)

volume_slider:subscribe("mouse.entered", function()
  volume_slider:set({ slider = { knob = { drawing = true } } })
end)

volume_slider:subscribe("mouse.exited", function()
  volume_slider:set({ slider = { knob = { drawing = false } } })
end)

-- Scroll to adjust volume
local function volume_scroll(env)
  local delta = tonumber((env.INFO or {}).delta) or 0
  local modifier = (env.INFO or {}).modifier

  local step = 2
  if modifier == "ctrl" then
    step = 1
  elseif modifier == "shift" then
    step = 5
  end

  local change = delta * step
  sbar.exec(
    'osascript -e "set volume output volume (output volume of (get volume settings) + '
      .. change
      .. ')"'
  )
end

volume_icon:subscribe("mouse.scrolled", volume_scroll)
volume_slider:subscribe("mouse.scrolled", volume_scroll)

-- 左键：输出设备列表；右键：系统声音；中键：下一个设备
volume_icon:subscribe("mouse.clicked", function(env)
  local btn = tostring(env.BUTTON or "left")
  if btn == "right" then
    sbar.exec("open 'x-apple.systempreferences:com.apple.Sound-Settings.extension' 2>/dev/null || open /System/Library/PreferencePanes/Sound.prefPane")
    volume_icon:set({ popup = { drawing = false } })
    return
  end
  if btn == "other" then
    sbar.exec(
      string.format(
        [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; %q -t output -n 2>/dev/null]],
        SAS
      )
    )
    return
  end
  -- left: toggle device popup
  local drawing = volume_icon:query().popup.drawing
  if drawing == "on" then
    volume_icon:set({ popup = { drawing = false } })
  else
    refresh_device_popup()
    volume_icon:set({ popup = { drawing = true } })
  end
end)

volume_icon:subscribe("mouse.exited.global", function()
  volume_icon:set({ popup = { drawing = false } })
end)

-- 初始音量图标
sbar.exec(
  'osascript -e "output volume of (get volume settings)"',
  function(out)
    local v = coerce.number(out) or 50
    volume_icon:set({
      label = { string = get_volume_icon(v, false), color = colors.white },
    })
    volume_slider:set({ slider = { percentage = v } })
  end
)
