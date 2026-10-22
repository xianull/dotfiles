local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local island = require("items.widgets.sys_island")

-- Execute the event provider binary which provides the event "network_update"
-- for the network interface "en0", which is fired every 2.0 seconds.
sbar.exec("killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0")

local popup_width = 200

local wifi_up = sbar.add("item", "widgets.wifi1", {
  position = "right",
  drawing = island.expanded,
  padding_left = -5,
  width = 0,
  icon = {
    padding_right = 0,
    font = {
      size = 9.0,
    },
    string = icons.wifi.upload,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 9.0,
    },
    color = colors.grey,
    string = "??? Bps",
    -- 定宽右对齐：去掉前导 0 后字数会变，不定宽的话整组胶囊会跟着网速左右抖。
    -- 44 = 7 个字 × 5.4pt + 左右 padding 各 3，和原来三位数时的自然宽度一样
    width = 44,
    align = "right",
  },
  y_offset = 4,
})

local wifi_down = sbar.add("item", "widgets.wifi2", {
  position = "right",
  drawing = island.expanded,
  padding_left = -5,
  icon = {
    padding_right = 0,
    font = {
      size = 9.0,
    },
    string = icons.wifi.download,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 9.0,
    },
    color = colors.grey,
    string = "??? Bps",
    width = 44,
    align = "right",
  },
  y_offset = -4,
})

local wifi = sbar.add("item", "widgets.wifi.padding", {
  position = "right",
  drawing = island.expanded,
  label = { drawing = false },
})

local toggle = sbar.add("item", "widgets.sys_toggle", {
  position = "right",
  icon = {
    string = island.expanded and icons.chevron.right or icons.chevron.left,
    font = { size = 12.0 },
    color = colors.grey,
    padding_left = 8,
    padding_right = 8,
  },
  label = { drawing = false },
})
island.toggle = toggle

-- Shared bracket: cpu_temp + cpu + memory + gpu + wifi + toggle（系统岛）
local cap = settings.capsule or {}
local wifi_bracket = sbar.add("bracket", "widgets.cpu_wifi.bracket", {
  "widgets.cpu_temp",
  "widgets.cpu",
  "widgets.memory",
  "widgets.gpu",
  wifi.name,
  wifi_up.name,
  wifi_down.name,
  toggle.name,
}, {
  background = {
    color = colors.with_alpha(colors.bg1, cap.bg_alpha or 0.32),
    border_width = 1,
    border_color = colors.with_alpha(colors.white, cap.border_alpha or 0.08),
    corner_radius = cap.corner_radius or 12,
    height = cap.height or 30,
  },
  popup = { align = "center", height = 24 }
})

local ssid = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    font = { size = 14 },
    string = icons.wifi.router,
    padding_left = 8,
  },
  width = popup_width,
  label = {
    font = { size = 13 },
    max_chars = 18,
    string = "...",
    padding_right = 8,
  },
})

local hostname = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Hostname",
    color = colors.grey,
    font = { size = 11.0 },
    width = popup_width / 2,
    padding_left = 8,
  },
  label = {
    max_chars = 20,
    string = "...",
    width = popup_width / 2,
    align = "right",
    font = { size = 11.0 },
    padding_right = 8,
  },
})

local ip = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "IP",
    color = colors.grey,
    font = { size = 11.0 },
    width = popup_width / 2,
    padding_left = 8,
  },
  label = {
    string = "...",
    width = popup_width / 2,
    align = "right",
    font = { size = 11.0 },
    padding_right = 8,
  },
})

local mask = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Subnet",
    color = colors.grey,
    font = { size = 11.0 },
    width = popup_width / 2,
    padding_left = 8,
  },
  label = {
    string = "...",
    width = popup_width / 2,
    align = "right",
    font = { size = 11.0 },
    padding_right = 8,
  },
})

local router = sbar.add("item", {
  position = "popup." .. wifi_bracket.name,
  icon = {
    align = "left",
    string = "Router",
    color = colors.grey,
    font = { size = 11.0 },
    width = popup_width / 2,
    padding_left = 8,
  },
  label = {
    string = "...",
    width = popup_width / 2,
    align = "right",
    font = { size = 11.0 },
    padding_right = 8,
  },
})

sbar.add("item", "widgets.cpu_wifi.padding", { position = "right", width = settings.group_paddings })

-- provider 输出补零定宽的 "001MBps"：去掉前导 0（"1MBps"），宽度由上面的定宽右对齐兜住。
-- 换成空格不行：SketchyBar 量宽度时不算前导空白，末字会被裁掉
local function unpad(s)
  return ((s or ""):gsub("^0+(%d)", "%1"))
end

wifi_up:subscribe("network_update", function(env)
  -- 有流量用前景色，空闲变暗（方向看箭头，不再靠红 / 蓝区分）
  local up_color = (env.upload == "000 Bps") and colors.grey or colors.white
  local down_color = (env.download == "000 Bps") and colors.grey or colors.white
  wifi_up:set({
    icon = { color = up_color },
    label = {
      string = unpad(env.upload),
      color = up_color
    }
  })
  wifi_down:set({
    icon = { color = down_color },
    label = {
      string = unpad(env.download),
      color = down_color
    }
  })
end)

wifi:subscribe({"wifi_change", "system_woke"}, function(env)
  sbar.exec("ipconfig getifaddr en0", function(ip)
    local connected = not (ip == "")
    wifi:set({
      icon = {
        string = connected and icons.wifi.connected or icons.wifi.disconnected,
        color = connected and colors.white or colors.red,
      },
    })
  end)
end)

local function hide_details()
  wifi_bracket:set({ popup = { drawing = false } })
end

local function toggle_details()
  local should_draw = wifi_bracket:query().popup.drawing == "off"
  if should_draw then
    wifi_bracket:set({ popup = { drawing = true }})
    sbar.exec("networksetup -getcomputername", function(result)
      hostname:set({ label = result })
    end)
    sbar.exec("ipconfig getifaddr en0", function(result)
      ip:set({ label = result })
    end)
    sbar.exec("ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}'", function(result)
      ssid:set({ label = result })
    end)
    sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'", function(result)
      mask:set({ label = result })
    end)
    sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'", function(result)
      router:set({ label = result })
    end)
  else
    hide_details()
  end
end

wifi_up:subscribe("mouse.clicked", toggle_details)
wifi_down:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.exited.global", hide_details)

toggle:subscribe("mouse.clicked", function()
  hide_details()
  island.toggle_expanded()
end)

local function copy_label_to_clipboard(env)
  local label = sbar.query(env.NAME).label.value
  sbar.exec("echo \"" .. label .. "\" | pbcopy")
  sbar.set(env.NAME, { label = { string = icons.clipboard, align="center" } })
  sbar.delay(1, function()
    sbar.set(env.NAME, { label = { string = label, align = "right" } })
  end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
