local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}

local cap = settings.capsule or {}
local pill_r = 8
-- 方案可选：没有窗口的桌面不显示（当前所在的除外）。islands 不开，zen 开
local hide_empty = (settings.spaces or {}).hide_empty
-- 当前桌面的高亮底色：方案可改（zen 用 gruvbox 暖黄），默认半透明蓝
local active_bg = colors.with_alpha(
  (settings.spaces or {}).active_color or colors.blue or colors.bg2,
  (settings.spaces or {}).active_alpha or 0.35
)
local seen = {} -- [i] = { selected = bool, empty = bool }

local function sync_visible(i)
  if not hide_empty then return end
  local st = seen[i] or {}
  local show = st.selected or not st.empty
  sbar.set("space." .. i, { drawing = show })
  sbar.set("space.padding." .. i, { drawing = show })
end

for i = 1, 10, 1 do
  local space = sbar.add("space", "space." .. i, {
    space = i,
    icon = {
      font = { family = settings.font.numbers, size = 12.0 },
      string = i,
      padding_left = 10,
      padding_right = 6,
      color = colors.grey,
      highlight_color = colors.white,
    },
    label = {
      padding_right = 10,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:14.0",
      y_offset = -1,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.transparent,
      border_width = 0,
      height = 22,
      corner_radius = pill_r,
    },
    popup = { background = { border_width = 0, corner_radius = cap.corner_radius or 12 } }
  })

  spaces[i] = space

  -- 空间间距略收，减少左栏「稀」
  sbar.add("space", "space.padding." .. i, {
    space = i,
    script = "",
    width = math.max(2, (settings.group_paddings or 5) - 2),
  })

  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left= 5,
    padding_right= 0,
    background = {
      drawing = true,
      image = {
        corner_radius = 9,
        scale = 0.2
      }
    }
  })

  space:subscribe("space_change", function(env)
    local selected = env.SELECTED == "true"
    seen[i] = seen[i] or {}
    seen[i].selected = selected
    sync_visible(i)
    -- 选中：轻蓝底 + 白字（贴系统强调）；动画更短更稳
    sbar.animate("tanh", 8, function()
      space:set({
        icon = {
          highlight = selected,
          color = selected and colors.white or colors.grey,
        },
        label = {
          highlight = selected,
          color = selected and colors.white or colors.grey,
        },
        background = {
          color = selected and active_bg or colors.transparent,
          corner_radius = pill_r,
        },
      })
    end)
  end)

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "other" then
      space_popup:set({ background = { image = "space." .. env.SID } })
      space:set({ popup = { drawing = "toggle" } })
    else
      local op = (env.BUTTON == "right") and "--destroy" or "--focus"
      sbar.exec("yabai -m space " .. op .. " " .. env.SID)
    end
  end)

  space:subscribe("mouse.exited", function(_)
    space:set({ popup = { drawing = false } })
  end)
end

local space_window_observer = sbar.add("item", {
  drawing = false,
  updates = true,
})

space_window_observer:subscribe("space_windows_change", function(env)
  local icon_line = ""
  local no_app = true
  for app, count in pairs(env.INFO.apps) do
    if app ~= "Dropover" then
      no_app = false
      local lookup = app_icons[app]
      local icon = ((lookup == nil) and app_icons["Default"] or lookup)
      icon_line = icon_line .. icon
    end
  end

  if (no_app) then
    icon_line = hide_empty and "" or " —"
  end
  local sp = spaces[env.INFO.space]
  if not sp then return end
  local idx = tonumber(env.INFO.space)
  seen[idx] = seen[idx] or {}
  seen[idx].empty = no_app
  sync_visible(idx)
  sbar.animate("tanh", 8, function()
    sp:set({ label = { string = icon_line } })
  end)
end)

-- spaces 背景由 bg_left 统一提供
sbar.add("bracket", "spaces.bracket", {
  '/space\\..*/',
}, {
  background = {
    drawing = false,
  },
})
