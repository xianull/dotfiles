local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local color_schemes = require("helpers.color_schemes")

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

local apple = sbar.add("item", "apple", {
  icon = {
    font = { size = 15.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 10,
  },
  label = { drawing = false },
  -- 背景交给 bg_left 统一胶囊，避免双重底
  background = { drawing = false },
  padding_left = 1,
  padding_right = 1,
})

-- Bracket for apple (for popup support)
local apple_bracket = sbar.add("bracket", { apple.name }, {
  background = { color = colors.transparent },
  popup = { align = "left", height = 24 }
})

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

-- Get theme lists
local dark_themes, light_themes = color_schemes.get_scheme_names()
local current_scheme = color_schemes.get_current_scheme()
local current_scheme_data = color_schemes.schemes[current_scheme]
local is_light_mode = current_scheme_data and current_scheme_data.light or false

-- Save mode preference
local function save_mode_preference(is_light)
  local file = io.open(os.getenv("HOME") .. "/.config/sketchybar/.theme_mode", "w")
  if file then
    file:write(is_light and "light" or "dark")
    file:close()
  end
end

local function get_mode_preference()
  local file = io.open(os.getenv("HOME") .. "/.config/sketchybar/.theme_mode", "r")
  if file then
    local mode = file:read("*l")
    file:close()
    return mode == "light"
  end
  return is_light_mode
end

-- Current mode state
local show_light_mode = get_mode_preference()

-- 方案（布局）：点一下轮换，等同于命令行 sbar-layout。配色在下面单独切
local layout_row = sbar.add("item", "theme.layout", {
  position = "popup." .. apple_bracket.name,
  icon = { string = "Layout", color = colors.white, font = { size = 13.0 }, padding_left = 8 },
  label = {
    string = require("helpers.layout").name .. "  ⇄",
    color = colors.grey,
    font = { size = 11.0 },
    padding_right = 8,
  },
})
layout_row:subscribe("mouse.clicked", function()
  apple_bracket:set({ popup = { drawing = false } })
  sbar.exec(os.getenv("HOME") .. "/.config/sketchybar/scripts/sbar-layout")
end)

-- AI 用量：哪些订阅显示在栏上（设置页由 items/widgets/ai_usage.lua 提供，这里只负责打开它）
local ai_usage_row = sbar.add("item", "theme.ai_usage", {
  position = "popup." .. apple_bracket.name,
  icon = { string = "AI 用量", color = colors.white, font = { size = 13.0 }, padding_left = 8 },
  label = {
    string = "设置  ⚙",
    color = colors.grey,
    font = { size = 11.0 },
    padding_right = 8,
  },
})
ai_usage_row:subscribe("mouse.clicked", function()
  apple_bracket:set({ popup = { drawing = false } })
  sbar.exec("sketchybar --trigger ai_usage_settings")
end)

-- Popup header with mode toggle
local header = sbar.add("item", "theme.header", {
  position = "popup." .. apple_bracket.name,
  icon = { string = "Themes", color = colors.white, font = { size = 13.0 }, padding_left = 8 },
  label = { drawing = false },
})

-- Mode toggle button
local mode_toggle = sbar.add("item", "theme.mode_toggle", {
  position = "popup." .. apple_bracket.name,
  icon = {
    string = show_light_mode and "Light" or "Dark",
    color = show_light_mode and colors.yellow or colors.blue,
    font = { size = 13.0 },
    padding_left = 8,
  },
  label = {
    string = "toggle",
    color = colors.grey,
    font = { size = 11.0 },
    padding_right = 8,
  },
})

-- Divider
sbar.add("item", "theme.divider", {
  position = "popup." .. apple_bracket.name,
  icon = { drawing = false },
  label = { drawing = false },
  background = { color = colors.with_alpha(colors.grey, 0.2), height = 1 },
})

-- Wallpaper：跟壁纸顶部取色（深浅也跟壁纸走，所以亮 / 暗模式下都显示）
local wallpaper_row = sbar.add("item", "theme.wallpaper", {
  position = "popup." .. apple_bracket.name,
  icon = {
    string = current_scheme == "wallpaper" and "●" or "○",
    color = colors.yellow,
    font = { size = 9.0 },
    padding_left = 10,
    padding_right = 0,
  },
  label = {
    string = "Wallpaper（跟壁纸取色）",
    color = current_scheme == "wallpaper" and colors.white or colors.grey,
    font = { size = 13.0 },
    padding_left = 4,
  },
})
wallpaper_row:subscribe("mouse.clicked", function()
  color_schemes.save_current_scheme("wallpaper")
  apple_bracket:set({ popup = { drawing = false } })
  sbar.exec("sketchybar --reload")
end)

-- 选了 Wallpaper 才盯着壁纸：路径或修改时间变了就重载，重新取色（--key 不解码图片，很便宜）
if current_scheme == "wallpaper" and colors.wallpaper_key then
  local watcher = sbar.add("item", "theme.wallpaper_watch", { drawing = false, updates = true, update_freq = 30 })
  watcher:subscribe({ "routine", "space_change", "system_woke" }, function()
    sbar.exec(color_schemes.WALLPAPER_HELPER .. " --key", function(key)
      key = tostring(key or ""):gsub("%s+$", "")
      if key ~= "" and key ~= colors.wallpaper_key then
        sbar.exec("sketchybar --reload")
      end
    end)
  end)
end

-- Create theme item
local function create_theme_item(key)
  local scheme = color_schemes.schemes[key]
  local is_selected = (key == current_scheme)
  local dot_color = scheme.light and scheme.orange or scheme.blue

  local item = sbar.add("item", "theme." .. key, {
    position = "popup." .. apple_bracket.name,
    icon = {
      string = is_selected and "●" or "○",
      color = dot_color,
      font = { size = 9.0 },
      padding_left = 10,
      padding_right = 0,
    },
    label = {
      string = scheme.name,
      color = is_selected and colors.white or colors.grey,
      font = { size = 13.0 },
      padding_left = 4,
    },
    drawing = (scheme.light == show_light_mode),
  })

  local theme_key = key
  item:subscribe("mouse.clicked", function()
    color_schemes.save_current_scheme(theme_key)
    apple_bracket:set({ popup = { drawing = false } })
    sbar.exec("sketchybar --reload")
  end)

  return item
end

-- Create all theme items
for _, key in ipairs(dark_themes) do
  create_theme_item(key)
end
for _, key in ipairs(light_themes) do
  create_theme_item(key)
end

-- Update visibility based on mode
local function update_theme_visibility()
  for _, key in ipairs(dark_themes) do
    local scheme = color_schemes.schemes[key]
    sbar.set("theme." .. key, { drawing = not show_light_mode })
  end
  for _, key in ipairs(light_themes) do
    local scheme = color_schemes.schemes[key]
    sbar.set("theme." .. key, { drawing = show_light_mode })
  end
end

-- Mode toggle click handler
mode_toggle:subscribe("mouse.clicked", function()
  show_light_mode = not show_light_mode
  save_mode_preference(show_light_mode)

  mode_toggle:set({
    icon = {
      string = show_light_mode and "Light" or "Dark",
      color = show_light_mode and colors.yellow or colors.blue,
    },
  })

  update_theme_visibility()
end)

-- Left click: Apple menu
apple:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    -- Update current selection
    local new_current = color_schemes.get_current_scheme()
    local all_themes = {}
    for _, k in ipairs(dark_themes) do table.insert(all_themes, k) end
    for _, k in ipairs(light_themes) do table.insert(all_themes, k) end

    for _, k in ipairs(all_themes) do
      local scheme = color_schemes.schemes[k]
      sbar.set("theme." .. k, {
        icon = { string = k == new_current and "●" or "○", color = scheme.light and scheme.orange or scheme.blue },
        label = { color = k == new_current and colors.white or colors.grey }
      })
    end
    wallpaper_row:set({
      icon = { string = new_current == "wallpaper" and "●" or "○" },
      label = { color = new_current == "wallpaper" and colors.white or colors.grey },
    })

    -- Update visibility
    update_theme_visibility()

    apple_bracket:set({ popup = { drawing = "toggle" } })
  else
    sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
  end
end)

-- Close popup when mouse exits
apple:subscribe("mouse.exited.global", function()
  apple_bracket:set({ popup = { drawing = false } })
end)
