local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local color_schemes = require("helpers.color_schemes")

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

local apple = sbar.add("item", "apple", {
  icon = {
    font = { size = 16.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 8,
  },
  label = { drawing = false },
  background = {
    color = colors.with_alpha(colors.bg1, 0.8),
    border_color = colors.with_alpha(colors.bg2, 0.8),
    border_width = 2,
    corner_radius = 9,
  },
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
