local colors = require("colors")
local settings = require("settings")
local coerce = require("helpers.coerce")

local HOME = os.getenv("HOME") or ""
local ICON_DIR = HOME .. "/.config/sketchybar/helpers/ai_icons"
local SCRIPT = [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; "$CONFIG_DIR/helpers/ai_usage.sh"]]

-- CodexBar menu card: 280pt. Insets live in the PNGs / column widths
-- so SketchyBar padding cannot widen the popup and leave an empty gutter.
local POPUP_W = 280
local PAD = 18
-- 两列必须凑满 POPUP_W - 2*PAD，文字行总宽才等于进度条图片宽度（280），
-- 否则文字行比图片宽 36pt，进度条看起来相对文字向内缩。
local COL = (POPUP_W - PAD * 2) / 2
-- Grok 的统一计费有 4 个产品，再加 On-demand，所以槽位要留够
local MAX_WINDOWS = 6
local MAX_COSTS = 4
local BAR_H = 14
local CHART_H = 36
local GAP_H = 8

local PROVIDERS = {
  grok = {
    name = "widgets.grok",
    icon = ICON_DIR .. "/grok_bar.png",
    url = "https://grok.com/?_s=usage",
    title = "Grok",
  },
  cursor = {
    name = "widgets.cursor",
    icon = ICON_DIR .. "/cursor_bar.png",
    url = "https://cursor.com/dashboard?tab=usage",
    title = "Cursor",
  },
}
local DEFAULT_ORDER = { "cursor", "grok" }

-- ai_usage.conf：每行一个 id，从上到下 = 栏内从左到右。helpers/ai_usage.py 读同一份。
local function read_order()
  local order, seen = {}, {}
  local file = io.open(HOME .. "/.config/sketchybar/ai_usage.conf", "r")
  if file then
    for line in file:lines() do
      local id = line:gsub("#.*$", ""):match("^%s*(.-)%s*$")
      if id and PROVIDERS[id] and not seen[id] then
        seen[id] = true
        order[#order + 1] = id
      end
    end
    file:close()
  end
  if #order == 0 then
    return DEFAULT_ORDER
  end
  return order
end

local ORDER = read_order()

-- 弹窗文案按「用量仪表」而不是后台字段名来写
local WIN_NAMES = {
  ["Total"] = false, -- 总量就是顶部大数字，明细里不再重复
  ["Auto + Composer"] = "Auto",
  ["API"] = "API",
  ["Cursor"] = "Auto", -- 旧缓存字段名
  ["Third Party"] = "API",
  ["Build"] = "Build",
  ["App Builder"] = "App Builder",
  ["Chat"] = "Chat",
  ["Imagine"] = "Imagine",
  ["On-demand"] = "On-demand",
  ["Credits"] = false, -- 总量就是顶部大数字
}
local COST_TITLES = {
  today = "今日",
  ["7d"] = "近 7 天",
  ["30d"] = "近 30 天",
  metered = "按量",
}

local function label_color(pct, status)
  if status == "missing" or status == "error" or not pct then
    return colors.grey
  end
  if pct >= 95 then
    return colors.red
  end
  if pct >= 90 then
    return colors.orange
  end
  return colors.white
end

local function tonumber_or_nil(s)
  if not s or s == "" then
    return nil
  end
  return tonumber(s)
end

local function split_tabs(line)
  local f = {}
  local i = 1
  for part in (line .. "\t"):gmatch("(.-)\t") do
    f[i] = part
    i = i + 1
  end
  return f
end

local function fmt_money(n)
  if n == nil then
    return "—"
  end
  return string.format("$%.2f", n)
end

local function compact_num(n, div, suffix)
  local scaled = math.abs(n) / div
  local text
  if scaled >= 10 then
    text = string.format("%.0f", scaled)
  else
    text = string.format("%.1f", scaled)
    if text:sub(-2) == ".0" then
      text = text:sub(1, -3)
    end
  end
  if n < 0 then
    text = "-" .. text
  end
  return text .. suffix
end

local function fmt_tokens(n)
  if n == nil then
    return nil
  end
  local abs = math.abs(n)
  if abs >= 1000000000 then
    return compact_num(n, 1000000000, "B")
  end
  if abs >= 1000000 then
    return compact_num(n, 1000000, "M")
  end
  if abs >= 1000 then
    return compact_num(n, 1000, "K")
  end
  return tostring(math.floor(n + (n >= 0 and 0.5 or -0.5)))
end

local function fmt_cost_line(cost, tokens)
  local money = fmt_money(cost)
  local tok = fmt_tokens(tokens)
  if tok then
    return money .. " · " .. tok .. " tokens"
  end
  return money
end

local items = {}
local popups = {}
local latest = {}
local cost_days = {}
for _, id in ipairs(ORDER) do
  cost_days[id] = 30
end
local apply

local function pop_item(parent, id, opts)
  opts = opts or {}
  local left_only = opts.label_drawing == false
  return sbar.add("item", id, {
    position = "popup." .. parent,
    padding_left = 0,
    padding_right = 0,
    icon = {
      string = opts.icon or "",
      drawing = opts.icon_drawing ~= false,
      color = opts.icon_color or colors.white,
      font = {
        family = opts.icon_font or settings.font.text,
        size = opts.icon_size or 13.0,
      },
      width = opts.icon_width or (left_only and POPUP_W or COL),
      align = "left",
      padding_left = PAD,
      padding_right = 0,
    },
    label = {
      string = opts.label or "",
      drawing = opts.label_drawing ~= false,
      color = opts.color or colors.grey,
      font = {
        family = opts.font or settings.font.text,
        size = opts.size or 11.0,
      },
      width = opts.label_width or (left_only and 0 or COL),
      align = opts.align or "right",
      padding_left = 0,
      padding_right = PAD,
    },
    drawing = opts.drawing ~= false,
    background = { drawing = false, height = opts.height or 22 },
  })
end

local function pop_bar(parent, id)
  return sbar.add("item", id, {
    position = "popup." .. parent,
    drawing = false,
    padding_left = 0,
    padding_right = 0,
    width = POPUP_W,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
      drawing = true,
      color = { alpha = 0 },
      height = BAR_H,
      image = { string = "", scale = 0.5 },
    },
  })
end

local function pop_gap(parent, id)
  return sbar.add("item", id, {
    position = "popup." .. parent,
    drawing = false,
    width = POPUP_W,
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = { drawing = false },
    background = { drawing = false, height = GAP_H },
  })
end

-- position=right 添加顺序与视觉相反，所以倒着遍历 ORDER：先加最右、最后加最左
-- 胶囊高 30 / 圆角 12。
-- 图标走 icon.background.image，而 background 会连 padding 区域一起覆盖、图片在其中
-- 居中，所以 icon 的左右 padding 只决定总宽：给 22/8 时两侧实际各是 (22+8)/2=15，
-- 左边距会被匀走一半。因此 icon padding 必须对称，左侧留白改用独立 spacer item。
-- 视觉：[ 12 spacer | 8 | 24px icon | 8 | % | 6+8 | 24px icon | 8 | % | 16 ]
local ICON_PX = 24
local ICON_SCALE = ICON_PX / 64
local ICON_PAD = 8
local INSET_LEFT = 12
local INSET_RIGHT = 18
local MID_GAP = 6
-- Maple Mono 12 下 "100%" 大约 36–40pt，30pt 会被胶囊圆角裁掉
local PCT_W = 44

for idx = #ORDER, 1, -1 do
  local id = ORDER[idx]
  local spec = PROVIDERS[id]
  local is_right = (idx == #ORDER)
  local item = sbar.add("item", spec.name, {
    position = "right",
    padding_left = 0,
    padding_right = 0,
    y_offset = 0,
    icon = {
      string = " ",
      drawing = true,
      width = ICON_PX,
      align = "center",
      padding_left = ICON_PAD,
      padding_right = ICON_PAD,
      y_offset = 0,
      font = { family = settings.font.text, style = "Regular", size = 1.0 },
      background = {
        drawing = true,
        color = colors.transparent,
        height = ICON_PX,
        corner_radius = 0,
        image = {
          string = spec.icon,
          scale = ICON_SCALE,
          corner_radius = 0,
          drawing = true,
        },
      },
    },
    label = {
      string = "--",
      font = { family = settings.font.numbers, size = 12.0 },
      color = colors.grey,
      align = "left",
      width = PCT_W,
      padding_left = 0,
      padding_right = is_right and INSET_RIGHT or MID_GAP,
      y_offset = 0,
    },
    -- 一次 refresh 就会刷新所有 provider，所以只让第一个定时驱动
    update_freq = (idx == 1) and 120 or 0,
    popup = {
      align = "center",
      height = 16,
      blur_radius = 50,
      y_offset = 8,
      horizontal = false,
      background = {
        color = colors.popup.bg,
        border_color = colors.with_alpha(colors.white, 0.08),
        border_width = 1,
        corner_radius = 16,
      },
    },
  })

  local rows = {
    header = pop_item(spec.name, spec.name .. ".header", {
      icon = spec.title,
      icon_size = 13.0,
      label = "",
      size = 11.0,
      height = 22,
    }),
    -- 签名读数：大号百分比 + 倒计时，这是整张卡片唯一放大的元素
    hero = pop_item(spec.name, spec.name .. ".hero", {
      icon = "--",
      icon_font = settings.font.numbers,
      icon_size = 22.0,
      label = "",
      size = 12.0,
      height = 28,
    }),
    subtitle = pop_item(spec.name, spec.name .. ".subtitle", {
      icon = "",
      icon_color = colors.grey,
      icon_size = 11.0,
      label_drawing = false,
      drawing = false,
      height = 16,
    }),
    pace = pop_item(spec.name, spec.name .. ".pace", {
      icon = "",
      icon_color = colors.grey,
      icon_size = 11.0,
      label_drawing = false,
      drawing = false,
      height = 16,
    }),
    share = pop_item(spec.name, spec.name .. ".share", {
      icon = "",
      icon_color = colors.grey,
      icon_size = 11.0,
      label_drawing = false,
      drawing = false,
      height = 16,
    }),
    gap_head = pop_gap(spec.name, spec.name .. ".gap_head"),
    windows = {},
    costs = {},
  }

  for i = 1, MAX_WINDOWS do
    local prefix = spec.name .. ".w" .. i
    rows.windows[i] = {
      title = pop_item(spec.name, prefix .. ".title", {
        icon = "Session",
        icon_size = 12.5,
        label = "",
        size = 11.0,
        drawing = false,
        height = 18,
      }),
      bar = pop_bar(spec.name, prefix .. ".bar"),
      hint = pop_item(spec.name, prefix .. ".hint", {
        icon = "",
        icon_color = colors.grey,
        icon_size = 11.0,
        label_drawing = false,
        drawing = false,
        height = 16,
      }),
    }
  end

  rows.gap_extra = pop_gap(spec.name, spec.name .. ".gap_extra")
  rows.extra_title = pop_item(spec.name, spec.name .. ".extra_title", {
    icon = "$0.00",
    icon_font = settings.font.numbers,
    icon_size = 13.0,
    label = "",
    size = 11.0,
    drawing = false,
    height = 20,
  })
  rows.extra_bar = pop_bar(spec.name, spec.name .. ".extra_bar")
  rows.extra_meta = pop_item(spec.name, spec.name .. ".extra_meta", {
    icon = "",
    icon_color = colors.grey,
    icon_size = 11.0,
    label_drawing = false,
    drawing = false,
    height = 16,
  })

  rows.gap_cost = pop_gap(spec.name, spec.name .. ".gap_cost")
  rows.cost_title = pop_item(spec.name, spec.name .. ".cost_title", {
    icon = "花费",
    icon_size = 13.0,
    label = "30d",
    size = 11.0,
    drawing = false,
    height = 20,
  })
  rows.cost_chart = sbar.add("item", spec.name .. ".cost_chart", {
    position = "popup." .. spec.name,
    drawing = false,
    padding_left = 0,
    padding_right = 0,
    width = POPUP_W,
    icon = { drawing = false },
    label = { drawing = false },
    background = {
      drawing = true,
      color = { alpha = 0 },
      height = CHART_H,
      image = { string = "", scale = 0.5 },
    },
  })
  for i = 1, MAX_COSTS do
    rows.costs[i] = pop_item(spec.name, spec.name .. ".cost" .. i, {
      icon = "Today",
      icon_color = colors.grey,
      icon_size = 11.0,
      label = "",
      size = 11.0,
      drawing = false,
      height = 18,
    })
  end

  rows.gap_open = pop_gap(spec.name, spec.name .. ".gap_open")
  rows.open = pop_item(spec.name, spec.name .. ".open", {
    icon = "打开用量页  ↗",
    icon_color = colors.blue,
    icon_size = 12.0,
    label_drawing = false,
    height = 22,
  })
  rows.open:subscribe("mouse.clicked", function()
    sbar.exec("open " .. spec.url)
    item:set({ popup = { drawing = false } })
  end)

  local function cycle_cost()
    cost_days[id] = (cost_days[id] == 30) and 7 or 30
    if latest[id] then
      apply(latest[id])
    end
  end
  rows.cost_title:subscribe("mouse.clicked", cycle_cost)
  rows.cost_chart:subscribe("mouse.clicked", cycle_cost)

  items[id] = item
  popups[id] = rows
end

-- 最后添加 → position=right 下位于最左，撑出胶囊左侧留白（default.lua 的 5/5 要清零）
local inset = sbar.add("item", "widgets.ai_usage.inset", {
  position = "right",
  width = INSET_LEFT,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

local members = { inset.name }
for _, id in ipairs(ORDER) do
  members[#members + 1] = items[id].name
end

local capset = settings.capsule or {}
sbar.add("bracket", "widgets.ai_usage.bracket", members, {
  padding_left = 0,
  padding_right = 0,
  background = {
    color = colors.with_alpha(colors.bg1, capset.bg_alpha or 0.32),
    border_width = 1,
    border_color = colors.with_alpha(colors.white, capset.border_alpha or 0.08),
    corner_radius = capset.corner_radius or 12,
    height = capset.height or 30,
  },
})

sbar.add("item", "widgets.ai_usage.padding", {
  position = "right",
  width = settings.group_paddings,
})

local function set_bar(slot, img, height)
  height = height or BAR_H
  slot:set({
    drawing = img ~= "",
    background = {
      drawing = img ~= "",
      color = { alpha = 0 },
      height = height,
      image = { string = img or "", scale = 0.5 },
    },
  })
end

apply = function(row)
  local spec = PROVIDERS[row.id]
  local item = items[row.id]
  if not spec or not item then
    return
  end
  latest[row.id] = row

  item:set({
    label = {
      string = row.label or "--",
      color = label_color(row.used, row.status),
    },
  })

  local p = popups[row.id]
  p.header:set({
    icon = { string = spec.title, color = colors.grey },
    label = { string = (row.plan ~= "" and row.plan) or "—", color = colors.grey },
  })

  p.hero:set({
    icon = {
      string = row.label or "--",
      color = label_color(row.used, row.status),
    },
    label = {
      string = row.reset or "",
      color = colors.grey,
    },
  })

  local range = row.period_range or ""
  if range ~= "" then
    p.subtitle:set({
      drawing = true,
      icon = { string = range, color = colors.grey },
    })
  else
    p.subtitle:set({ drawing = false })
  end

  local pace = row.hint or ""
  if pace ~= "" then
    p.pace:set({
      drawing = true,
      icon = { string = pace, color = colors.grey },
    })
  else
    p.pace:set({ drawing = false })
  end

  local share = row.share or ""
  if share ~= "" then
    p.share:set({
      drawing = true,
      icon = { string = share, color = colors.grey },
    })
  else
    p.share:set({ drawing = false })
  end

  local shown = {}
  for _, win in ipairs(row.windows or {}) do
    local mapped = WIN_NAMES[win.name]
    if mapped ~= false then
      shown[#shown + 1] = {
        name = mapped or win.name,
        used = win.used,
        label = win.label,
        bar = win.bar,
        hint = win.hint,
      }
    end
  end
  p.gap_head:set({ drawing = #shown > 0 })
  for i = 1, MAX_WINDOWS do
    local win = shown[i]
    local slot = p.windows[i]
    if win then
      slot.title:set({
        drawing = true,
        icon = { string = win.name, drawing = true, color = colors.white },
        label = { string = win.label or "--", color = label_color(win.used, row.status) },
      })
      set_bar(slot.bar, win.bar or "")
      if win.hint and win.hint ~= "" and (win.used or 0) > 0 then
        slot.hint:set({
          drawing = true,
          icon = { string = win.hint, color = colors.grey },
        })
      else
        slot.hint:set({ drawing = false })
      end
    else
      slot.title:set({ drawing = false })
      slot.bar:set({ drawing = false })
      slot.hint:set({ drawing = false })
    end
  end

  -- 没有额度上限且余额为 0 时整行无意义（Grok 未充值就是这种情况），直接隐藏
  local has_spend = row.spend ~= nil
    and (row.spend_limit ~= nil or (tonumber(row.spend) or 0) > 0)
  if has_spend then
    local money = fmt_money(row.spend)
    if row.spend_limit then
      money = money .. " / " .. fmt_money(row.spend_limit)
    end
    local extra_pct = row.extra_pct
    local extra_label = ""
    if extra_pct ~= nil then
      extra_label = string.format("%d%%", math.floor((extra_pct or 0) + 0.5))
    end
    p.extra_title:set({
      drawing = true,
      icon = { string = money, color = colors.white },
      label = { string = extra_label, color = label_color(extra_pct, row.status) },
    })
    set_bar(p.extra_bar, row.extra_bar or "")
    if row.spend_hint and row.spend_hint ~= "" then
      p.extra_meta:set({
        drawing = true,
        icon = { string = row.spend_hint, drawing = true, color = colors.grey },
        label = { drawing = false },
      })
    else
      p.extra_meta:set({ drawing = false })
    end
    p.gap_extra:set({ drawing = true })
  else
    p.extra_title:set({ drawing = false })
    p.extra_bar:set({ drawing = false })
    p.extra_meta:set({ drawing = false })
    p.gap_extra:set({ drawing = false })
  end

  local costs = row.costs or {}
  local days = cost_days[row.id] or 30
  if #costs > 0 then
    p.gap_cost:set({ drawing = true })
    p.cost_title:set({
      drawing = true,
      icon = { string = "花费", color = colors.white },
      label = { string = (days == 7) and "7d  ↔  30d" or "30d  ↔  7d", color = colors.blue },
    })
    local charts = row.charts or {}
    local img = charts[tostring(days)] or charts[days] or ""
    p.cost_chart:set({
      drawing = img ~= "",
      background = {
        drawing = img ~= "",
        color = { alpha = 0 },
        height = CHART_H,
        image = { string = img, scale = 0.5 },
      },
    })
    for i = 1, MAX_COSTS do
      local cost = costs[i]
      local slot = p.costs[i]
      if cost then
        local active = cost.key == "today"
          or (days == 7 and cost.key == "7d")
          or (days == 30 and cost.key == "30d")
        slot:set({
          drawing = true,
          icon = {
            string = COST_TITLES[cost.key] or cost.title or "",
            color = active and colors.white or colors.grey,
          },
          label = {
            string = fmt_cost_line(cost.cost, cost.tokens),
            color = active and colors.white or colors.grey,
          },
        })
      else
        slot:set({ drawing = false })
      end
    end
  else
    p.gap_cost:set({ drawing = false })
    p.cost_title:set({ drawing = false })
    p.cost_chart:set({ drawing = false })
    for i = 1, MAX_COSTS do
      p.costs[i]:set({ drawing = false })
    end
  end

  p.gap_open:set({ drawing = true })
end

local function parse_output(result)
  local rows = {}
  for _, id in ipairs(ORDER) do
    rows[id] = { id = id, windows = {}, costs = {}, charts = {}, status = "error", label = "--", plan = "", reset = "", seen = false }
  end
  for line in (coerce.text(result) .. "\n"):gmatch("(.-)\n") do
    local f = split_tabs(line)
    if f[1] == "P" and rows[f[2]] then
      local r = rows[f[2]]
      r.seen = true
      r.status = f[3] or "error"
      r.plan = f[4] or ""
      r.used = tonumber_or_nil(f[5])
      r.label = (f[6] ~= "" and f[6]) or "--"
      r.reset = f[7] or ""
      r.spend = tonumber_or_nil(f[8])
      r.spend_limit = tonumber_or_nil(f[9])
      r.period = f[10] or ""
      r.reset_at = f[11] or ""
      r.period_range = f[12] or ""
      r.remain_label = (f[13] ~= "" and f[13]) or "--"
      r.hint = f[14] or ""
    elseif f[1] == "E" and rows[f[2]] then
      rows[f[2]].extra_pct = tonumber_or_nil(f[3])
      rows[f[2]].extra_bar = f[4] or ""
      rows[f[2]].spend_hint = f[5] or ""
    elseif f[1] == "W" and rows[f[2]] then
      table.insert(rows[f[2]].windows, {
        name = f[3] or "Pool",
        used = tonumber_or_nil(f[4]),
        label = f[5] or "--",
        reset = f[6] or "",
        reset_at = f[7] or "",
        bar = f[8] or "",
        hint = f[9] or "",
      })
    elseif f[1] == "S" and rows[f[2]] then
      rows[f[2]].share = f[3] or ""
    elseif f[1] == "C" and rows[f[2]] then
      table.insert(rows[f[2]].costs, {
        key = f[3] or "",
        cost = tonumber_or_nil(f[4]),
        tokens = tonumber_or_nil(f[5]),
        title = f[6] or "",
      })
    elseif f[1] == "H" and rows[f[2]] then
      rows[f[2]].charts[f[3] or ""] = f[4] or ""
    end
  end
  return rows
end

local inflight = false
local inflight_at = 0
local function refresh()
  -- 脚本若卡住，callback 不会回来；超过 75s 允许下一轮，避免 Grok 被 Cursor 拖死
  local now = os.time()
  if inflight and (now - inflight_at) < 75 then
    return
  end
  inflight = true
  inflight_at = now
  sbar.exec(SCRIPT, function(result)
    inflight = false
    -- 空输出或某一家没出现在结果里时，保留上次读数，避免把 Grok 刷成 --
    if coerce.text(result) == "" then
      return
    end
    local parsed = parse_output(result)
    for _, id in ipairs(ORDER) do
      local row = parsed[id]
      if row and row.seen and row.status ~= "error" and row.status ~= "missing" then
        apply(row)
      elseif row and row.seen and not latest[id] then
        apply(row)
      end
    end
  end)
end

local function toggle_popup(id)
  local item = items[id]
  local drawing = item:query().popup.drawing == "off"
  item:set({ popup = { drawing = drawing } })
  if drawing then
    for other, other_item in pairs(items) do
      if other ~= id then
        other_item:set({ popup = { drawing = false } })
      end
    end
    refresh()
  end
end

for _, id in ipairs(ORDER) do
  local item = items[id]
  item:subscribe("mouse.clicked", function()
    toggle_popup(id)
  end)
  item:subscribe("mouse.exited.global", function()
    item:set({ popup = { drawing = false } })
  end)
end

items[ORDER[1]]:subscribe({ "routine", "system_woke", "forced" }, refresh)

-- 源 PNG 是纯白，按当前主题重新着色后落到 /tmp，切主题时跟着变
local TINT_DIR = "/tmp/sbar_ai_icons"
local function tint_bar_icons()
  local c = colors.white
  local r = (c >> 16) & 0xff
  local g = (c >> 8) & 0xff
  local b = c & 0xff
  local names = {}
  for _, id in ipairs(ORDER) do
    names[#names + 1] = string.format("%q", id .. "_bar.png")
  end
  local cmd = string.format(
    [[mkdir -p '%s' && python3 -c 'from PIL import Image; rgb=(%d,%d,%d)
for n in (%s,):
 im=Image.open("%s/"+n).convert("RGBA"); px=im.load(); w,h=im.size
 for y in range(h):
  for x in range(w):
   a=px[x,y][3]
   if a: px[x,y]=rgb+(a,)
 im.save("%s/"+n)']],
    TINT_DIR,
    r,
    g,
    b,
    table.concat(names, ","),
    ICON_DIR,
    TINT_DIR
  )
  sbar.exec(cmd, function()
    for _, id in ipairs(ORDER) do
      items[id]:set({ icon = { background = { image = { string = TINT_DIR .. "/" .. id .. "_bar.png" } } } })
    end
  end)
end

tint_bar_icons()
refresh()

return items
