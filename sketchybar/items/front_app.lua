local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local YABAI = "/opt/homebrew/bin/yabai"
local CONFIG = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
local QUERY = CONFIG .. "/helpers/yabai_front.sh"

sbar.add("event", "window_focus")

local front_app

local function parse_win(json)
  -- sbar.exec may pass decoded JSON as a table, or the raw string.
  if type(json) == "table" then
    return {
      idx = tonumber(json.i) or 0,
      total = tonumber(json.n) or 0,
      app = tostring(json.a or ""),
    }
  end
  if type(json) ~= "string" or not json:find("{", 1, true) then
    return nil
  end
  local app = json:match('"a"%s*:%s*"(.-)"') or ""
  app = app:gsub('\\"', '"'):gsub("\\\\", "\\")
  return {
    idx = tonumber(json:match('"i"%s*:%s*(%-?%d+)')) or 0,
    total = tonumber(json:match('"n"%s*:%s*(%-?%d+)')) or 0,
    app = app,
  }
end

-- Hidden unless the focused window is in a yabai stack.
local stack = sbar.add("item", "front_app.stack", {
  display = "active",
  drawing = false,
  padding_left = 8,
  padding_right = 2,
  icon = { drawing = false },
  label = {
    font = { family = settings.font.numbers, size = 11.0 },
    color = colors.grey,
    padding_left = 0,
    padding_right = 0,
    string = "",
  },
  background = { drawing = false },
})

front_app = sbar.add("item", "front_app", {
  display = "active",
  padding_left = 8,
  padding_right = 10,
  icon = {
    font = "sketchybar-app-font:Regular:15.0",
    string = app_icons["Default"],
    color = colors.white,
    padding_left = 4,
    padding_right = 6,
    y_offset = -1,
  },
  label = {
    font = { family = settings.font.text, size = 12.0 },
    color = colors.white,
    padding_right = 4,
    max_chars = 18,
  },
  updates = true,
  background = { drawing = false },
})

local last_app = ""
local last_env_app = ""
local gen = 0
local chrome = true

local function apply_app(app, animate)
  app = app or last_env_app or ""
  local icon = app_icons[app] or app_icons["Default"]
  local changed = app ~= last_app
  last_app = app

  if not chrome then
    front_app:set({
      icon = { string = icon },
      label = { string = app },
    })
    return
  end

  if animate and changed then
    front_app:set({
      icon = { string = icon, color = colors.with_alpha(colors.white, 0.4) },
      label = { string = app, color = colors.with_alpha(colors.white, 0.4) },
    })
    sbar.animate("tanh", 10, function()
      front_app:set({
        icon = { color = colors.white },
        label = { color = colors.white },
      })
    end)
  else
    front_app:set({
      icon = { string = icon, color = colors.white },
      label = { string = app, color = colors.white },
    })
  end
end

local function apply_stack(idx, total)
  local stacked = (idx or 0) > 0 and (total or 0) > 1
  stack:set({
    drawing = chrome and stacked,
    label = { string = stacked and (tostring(idx) .. "/" .. tostring(total)) or "" },
  })
end

local function refresh(env)
  if env and env.INFO and env.INFO ~= "" and env.SENDER == "front_app_switched" then
    last_env_app = env.INFO
    apply_app(last_env_app, true)
  end
  gen = gen + 1
  local my = gen
  sbar.exec(QUERY, function(out)
    if my ~= gen then return end
    local w = parse_win(out)
    if not w then
      apply_stack(0, 0)
      if last_app == "" then apply_app(last_env_app, false) end
      return
    end
    if w.app ~= "" then
      last_env_app = w.app
      apply_app(w.app, false)
    end
    apply_stack(w.idx, w.total)
  end)
end

front_app:subscribe(
  { "front_app_switched", "window_focus", "space_change", "forced", "system_woke" },
  refresh
)

front_app:subscribe("mouse.clicked", function(_)
  sbar.trigger("swap_menus_and_spaces")
end)

stack:subscribe("mouse.clicked", function(env)
  local dir = (env.BUTTON == "right") and "stack.prev" or "stack.next"
  sbar.exec(YABAI .. " -m window --focus " .. dir)
end)

local M = {}
function M.set_chrome(on)
  chrome = not not on
  front_app:set({ drawing = chrome })
  if chrome then
    refresh({ SENDER = "window_focus" })
  else
    stack:set({ drawing = false })
  end
end
return M
