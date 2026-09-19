local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local coerce = require("helpers.coerce")

local M = {}

local HELPERS = os.getenv("HOME") .. "/dotfiles/sketchybar/helpers"
local SCRIPT = HELPERS .. "/obsidian_todos.sh"
local POPUP_WIDTH = 320
local MAX_ITEMS = 10

local popup_open = false

-- Pure Lua resolver — never io.popen during load (pclose blocks sketchybarrc)
local vault_res = require("helpers.obsidian_vault")
local VAULT_NAME = vault_res.name()

local function open_home()
  local cmd = string.format(
    [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; python3 -c 'import subprocess,urllib.parse,sys; v=sys.argv[1]; uri="obsidian://open?vault="+urllib.parse.quote(v)+"&file="+urllib.parse.quote("Settings/🏠Home.md"); subprocess.run(["open", uri])' %q]],
    VAULT_NAME
  )
  sbar.exec(cmd)
end

local function open_note(path)
  if not path or path == "" then
    open_home()
    return
  end
  local cmd = string.format(
    [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; python3 -c 'import subprocess,urllib.parse,sys; v,p=sys.argv[1],sys.argv[2]; uri="obsidian://open?vault="+urllib.parse.quote(v)+"&file="+urllib.parse.quote(p); subprocess.run(["open", uri])' %q %q]],
    VAULT_NAME,
    path
  )
  sbar.exec(cmd)
end

local function fmt_mmss(sec)
  sec = tonumber(sec) or 0
  if sec < 0 then sec = 0 end
  local m = math.floor(sec / 60)
  local s = sec % 60
  return string.format("%02d:%02d", m, s)
end

local popup_items = {}

-- Popup on the ITEM (battery pattern)
M.todo = sbar.add("item", "widgets.obsidian_todos", {
  position = "right",
  icon = {
    string = icons.clipboard or "􀉄",
    font = { size = 14.0 },
    color = colors.blue or colors.white,
    padding_left = 8,
    padding_right = 2,
  },
  label = {
    string = "·",
    font = { family = settings.font.numbers, size = 12.0 },
    color = colors.blue or colors.white,
    padding_left = 2,
    padding_right = 8,
  },
  update_freq = 60,
  popup = {
    align = "center",
    height = 30,
  },
})

M.bracket = sbar.add("bracket", "widgets.obsidian_todos.bracket", {
  M.todo.name,
}, {
  background = { drawing = false },
})

local POP = "popup." .. M.todo.name

-- Current focus session (shown only when active)
local cap = settings.capsule or {}
M.focus_row = sbar.add("item", "widgets.obsidian_todos.focus", {
  position = POP,
  drawing = false,
  icon = {
    string = "▶",
    font = { size = 11.0 },
    color = colors.blue or colors.white,
    padding_left = 12,
    padding_right = 6,
    width = 18,
  },
  label = {
    string = "",
    font = { family = settings.font.text, size = 12.0 },
    color = colors.blue or colors.white,
    padding_right = 12,
    max_chars = 40,
  },
  width = POPUP_WIDTH,
  background = {
    color = colors.with_alpha(colors.bg1 or colors.grey, 0.35),
    corner_radius = cap.corner_radius or 12,
    height = 26,
  },
})

M.header = sbar.add("item", "widgets.obsidian_todos.header", {
  position = POP,
  icon = { drawing = false },
  label = {
    string = "今日待办",
    font = { family = settings.font.text, size = 11.0 },
    color = colors.grey,
    padding_left = 12,
    padding_right = 12,
  },
  width = POPUP_WIDTH,
})

for i = 1, MAX_ITEMS do
  local item = sbar.add("item", "widgets.obsidian_todos.item." .. i, {
    position = POP,
    drawing = false,
    -- status glyph only (time goes into label to avoid overlap)
    icon = {
      string = "•",
      font = { size = 10.0 },
      color = colors.grey,
      padding_left = 12,
      padding_right = 8,
      width = 16,
      align = "center",
    },
    label = {
      string = "",
      font = { family = settings.font.text, size = 12.0 },
      color = colors.white,
      padding_left = 0,
      padding_right = 12,
      max_chars = 42,
      align = "left",
    },
    width = POPUP_WIDTH,
  })
  popup_items[i] = item
  item:subscribe("mouse.clicked", function()
    open_note(item._obs_path)
    popup_open = false
    M.todo:set({ popup = { drawing = false } })
  end)
end

M.footer = sbar.add("item", "widgets.obsidian_todos.footer", {
  position = POP,
  icon = { drawing = false },
  label = {
    string = "打开主页 ↗",
    font = { family = settings.font.text, size = 12.0 },
    color = colors.blue or colors.grey,
    padding_left = 12,
    padding_right = 12,
  },
  width = POPUP_WIDTH,
})
M.footer:subscribe("mouse.clicked", function()
  open_note(nil)
  popup_open = false
  M.todo:set({ popup = { drawing = false } })
end)

local function set_empty_popup(msg)
  M.focus_row:set({ drawing = false })
  M.header:set({
    label = {
      string = msg or "No todos today",
      color = colors.grey,
    },
  })
  for i = 1, MAX_ITEMS do
    popup_items[i]:set({ drawing = false })
    popup_items[i]._obs_path = nil
  end
end

local function apply_lines(raw)
  raw = coerce.text(raw)
  if raw == "" then
    set_empty_popup("No data — open Home once")
    return 0
  end

  local today, overdue = 0, 0
  local i = 1
  local has_focus = false

  for line in (raw .. "\n"):gmatch("(.-)\n") do
    if line == "" then goto continue end

    if line:match("^META\t") then
      today = tonumber(line:match("^META\t(%d+)")) or 0
      overdue = tonumber(line:match("^META\t%d+\t(%d+)")) or 0
      M.header:set({
        label = {
          string = string.format("今日 %d · 过期 %d", today, overdue),
          color = overdue > 0 and colors.red or colors.grey,
        },
      })
    elseif line:match("^FOCUS\t") then
      -- FOCUS\tmode\trunning\trem\tlabel
      local mode, running, rem, label =
        line:match("^FOCUS\t(.-)\t(.-)\t(.-)\t(.*)$")
      if mode and mode ~= "idle" then
        has_focus = true
        local run = running == "1"
        local kind = mode == "mindfulness" and "正念"
          or (mode == "break" and "休息" or "专注")
        local prefix = run and "▶" or "⏸"
        local title = (label and label ~= "" and label) or kind
        local time_s = fmt_mmss(tonumber(rem) or 0)
        local ic = (mode == "mindfulness" or mode == "task")
          and (colors.blue or colors.white)
          or (colors.green or colors.white)
        M.focus_row:set({
          drawing = true,
          icon = {
            string = prefix,
            color = ic,
          },
          label = {
            string = string.format("%s · %s · %s", kind, title, time_s),
            color = colors.white,
          },
        })
      end
    elseif line:match("^ITEM\t") and i <= MAX_ITEMS then
      -- ITEM\tkind\tfocus\tpath\trange\ttext
      local kind, focus, path, rng, text =
        line:match("^ITEM\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
      if kind and text then
        local is_focus = focus == "1"
        local icon, icolor = "•", colors.grey
        if kind == "overdue" then
          icon, icolor = "!", colors.red
        elseif is_focus then
          icon, icolor = "▶", colors.blue or colors.white
        elseif kind == "today" then
          icon, icolor = "•", colors.blue or colors.white
        end

        -- Single-line layout: "22:30–23:00  更新 evergreen" (no icon/label collision)
        local display = text or ""
        if rng and rng ~= "" then
          display = string.format("%s  %s", rng, display)
        end

        popup_items[i]:set({
          drawing = true,
          icon = {
            string = icon,
            color = icolor,
            width = 16,
            font = { size = 10.0 },
          },
          label = {
            string = display,
            color = is_focus and (colors.orange or colors.white) or colors.white,
            max_chars = 42,
          },
        })
        popup_items[i]._obs_path = path
        i = i + 1
      end
    end
    ::continue::
  end

  if not has_focus then
    M.focus_row:set({ drawing = false })
  end

  local count = i - 1
  while i <= MAX_ITEMS do
    popup_items[i]:set({ drawing = false })
    popup_items[i]._obs_path = nil
    i = i + 1
  end
  if count == 0 and not has_focus then
    set_empty_popup((today == 0 and overdue == 0) and "No todos today" or "List empty — open Home")
  end
  return count
end

local function refresh_label()
  -- label formats from helper:
  --   !!7·1  → 有过期：今日7 · 过期1（红色）
  --   7      → 仅今日
  --   ·      → 空
  -- 注意：旧 fallback 曾输出 !!1（只有过期数），会显示成裸 "1"
  sbar.exec(string.format("%q label", SCRIPT), function(label)
    label = coerce.text(label):gsub("%s+$", ""):gsub("^\n+", ""):gsub("\n.*", "")
    local color = colors.white
    local overdue_only = false
    if label:match("^!!") then
      color = colors.red
      label = label:gsub("^!!", "")
      -- 规范化：若只有数字且像「仅过期」旧格式，加标记避免误解
      if label:match("^%d+$") then
        overdue_only = true
        label = "0·" .. label
      end
    elseif label == "·" or label == "0" or label == "" then
      color = colors.grey
      if label == "" or label == "0" then label = "·" end
    else
      color = colors.blue or colors.white
    end
    M.todo:set({
      label = {
        string = label,
        color = color,
        -- 今日·过期 略宽一点，避免 7·1 被裁切
        max_chars = 8,
      },
      icon = { color = color },
    })
  end)
end

local function close_popup()
  popup_open = false
  M.todo:set({ popup = { drawing = false } })
end

local function show_today_popup()
  refresh_label()
  sbar.exec(string.format("%q lines %d", SCRIPT, MAX_ITEMS), function(raw)
    apply_lines(raw or "")
    popup_open = true
    M.todo:set({ popup = { drawing = true } })
  end)
end

local function toggle_popup()
  if popup_open then
    close_popup()
  else
    show_today_popup()
  end
end

local function refresh()
  refresh_label()
  -- if popup open, keep list fresh (e.g. focus remaining)
  if popup_open then
    sbar.exec(string.format("%q lines %d", SCRIPT, MAX_ITEMS), function(raw)
      apply_lines(raw or "")
    end)
  end
end

M.todo:subscribe({ "routine", "system_woke", "forced", "focus_sync" }, refresh)

M.todo:subscribe("mouse.clicked", function(env)
  local btn = tostring(env.BUTTON or "left")
  if btn == "right" or env.MODIFIER == "ctrl" then
    toggle_popup()
  else
    open_note(nil)
    close_popup()
  end
end)

refresh()

return M
