local colors = require("colors")
local settings = require("settings")
local coerce = require("helpers.coerce")

local HOME = os.getenv("HOME") or ""
local ICON_DIR = HOME .. "/.config/sketchybar/helpers/ai_icons"
-- AI_USAGE_FG：主题前景色，脚本画仪表时用它当“没事”的颜色（和栏上图标同色）；换主题会重载，这里跟着变
local SCRIPT = string.format(
  [[export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"; AI_USAGE_FG=%06x "$CONFIG_DIR/helpers/ai_usage.sh"]],
  colors.white & 0xffffff
)

-- CodexBar menu card: 280pt. Insets live in the PNGs / column widths
-- so SketchyBar padding cannot widen the popup and leave an empty gutter.
local POPUP_W = 280
local PAD = 18
-- 两列各占一半（140）。注意：显式设了 width 的 icon / label，padding 是包含在 width 里的，
-- 不会另外再加；所以两列 140 + 140 = 280 才等于进度条图片宽度，文字行的右端才和进度条右端对齐。
-- （之前按 (280 - 2*18) / 2 = 122 算，实际只有 244，右边短了 36pt。）
local COL = POPUP_W / 2
-- Grok 的统一计费有 4 个产品，再加 On-demand，所以槽位要留够
local MAX_WINDOWS = 6
local MAX_COSTS = 4
local BAR_H = 14
local CHART_H = 36
local GAP_H = 8

local CONFIG_DIR = HOME .. "/.config/sketchybar"
local CONF = CONFIG_DIR .. "/ai_usage.conf"

-- helpers/ai_providers.tsv：id <TAB> 显示名 <TAB> 来源 <TAB> 用量页网址。helpers/ai_usage.py 读同一份。
local CATALOG, PROVIDERS = {}, {}
local function add_provider(id, title, url)
  CATALOG[#CATALOG + 1] = id
  PROVIDERS[id] = { name = "widgets." .. id, icon = ICON_DIR .. "/" .. id .. "_bar.png", url = url, title = title }
end
local catalog_file = io.open(CONFIG_DIR .. "/helpers/ai_providers.tsv", "r")
if catalog_file then
  for line in catalog_file:lines() do
    local id, title, _, url = line:match("^([^#\t][^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
    if id then
      add_provider(id, title, url)
    end
  end
  catalog_file:close()
end
if #CATALOG == 0 then -- 目录文件丢了也别让整条栏起不来
  add_provider("cursor", "Cursor", "https://cursor.com/dashboard?tab=usage")
  add_provider("grok", "Grok", "https://grok.com/?_s=usage")
end
local DEFAULT_ORDER = { "cursor", "grok" }

-- ai_usage.conf：每行一个 id，从上到下 = 栏内从左到右。helpers/ai_usage.py 读同一份。
-- 没有这个文件才用默认；文件在但全注释 = 设置页里全关了。
local function read_order()
  local file = io.open(CONF, "r")
  local order, seen = {}, {}
  local function take(id)
    if id and PROVIDERS[id] and not seen[id] then
      seen[id] = true
      order[#order + 1] = id
    end
  end
  if not file then
    for _, id in ipairs(DEFAULT_ORDER) do
      take(id)
    end
    return order
  end
  for line in file:lines() do
    take((line:gsub("#.*$", ""):match("^%s*(.-)%s*$") or ""):lower())
  end
  file:close()
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

local function age_text(ts)
  if not ts then
    return ""
  end
  local d = os.time() - ts
  if d < 45 then
    return "刚刚已更新"
  elseif d < 3600 then
    return string.format("%d 分钟前已更新", math.max(1, math.floor(d / 60 + 0.5)))
  elseif d < 86400 then
    return string.format("%d 小时前已更新", math.floor(d / 3600))
  end
  return string.format("%d 天前已更新", math.floor(d / 86400))
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
local open_settings
local force_refresh

local function pop_item(parent, id, opts)
  opts = opts or {}
  local extra = opts.top_extra or 0
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
      y_offset = -extra / 2,
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
      y_offset = -extra / 2,
    },
    drawing = opts.drawing ~= false,
    background = extra > 0 and { drawing = true, color = { alpha = 0 }, height = 16 + extra }
      or { drawing = false, height = opts.height or 22 },
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
local GAUGE = (settings.ai_usage or {}).gauge
local ICON_PX = GAUGE and 18 or 24
local ICON_SCALE = ICON_PX / 64
local ICON_PAD = GAUGE and 6 or 8
-- 双线微型仪表（zen 方案开启，见 layouts/zen.lua）：数字换成 helpers/ai_usage.py 画的上粗下细两条。
-- 图片贴在 label 背景上，宽度必须等于 label 宽度（padding 清零），否则图片会在 padding 区里居中而偏位；
-- 所以右侧留白用 tail 占位 item，左侧 icon 自带 8pt padding，inset 只补 4。
local MINI_W, MINI_H = 42, 12 -- 与 ai_usage.py 的 MINI_W / MINI_H 一致
local INSET_LEFT = GAUGE and 6 or 12
local INSET_RIGHT = 18
local MID_GAP = 6
-- Maple Mono 12 下 "100%" 大约 36–40pt，30pt 会被胶囊圆角裁掉
local PCT_W = 44

-- 最先添加 → position=right 下位于最右
local tail = GAUGE and sbar.add("item", "widgets.ai_usage.tail", {
  position = "right",
  width = 8,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = { drawing = false },
  background = { drawing = false },
})

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
      width = GAUGE and MINI_W or PCT_W,
      padding_left = 0,
      padding_right = (GAUGE and 0) or (is_right and INSET_RIGHT or MID_GAP),
      y_offset = 0,
      background = {
        drawing = false,
        color = colors.transparent,
        height = MINI_H,
        corner_radius = 0,
        image = { string = "", scale = 0.5 },
      },
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

  pop_gap(spec.name, spec.name .. ".gap_top"):set({ drawing = true })
  local rows = {
    header = pop_item(spec.name, spec.name .. ".header", {
      icon = spec.title,
      icon_size = 13.0,
      label = "↻",
      size = 13.0,
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
        top_extra = (i > 1) and 8 or 0, -- 第一个窗口前已有 gap_head；后面的窗口之间留出分组的空白
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
  -- 页脚：左边打开用量页，右边是“xx 前已更新”
  rows.open = pop_item(spec.name, spec.name .. ".open", {
    icon = "打开用量页  ↗",
    icon_color = colors.blue,
    icon_size = 12.0,
    label = "",
    size = 11.0,
    height = 22,
  })
  pop_gap(spec.name, spec.name .. ".gap_end"):set({ drawing = true })
  rows.header:subscribe("mouse.clicked", function()
    force_refresh(id)
  end)
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

-- 一家都没开时胶囊里只剩一个入口，不然设置页没地方点出来
local stub
if #ORDER == 0 then
  stub = sbar.add("item", "widgets.ai_usage.stub", {
    position = "right",
    padding_left = 0,
    padding_right = 0,
    icon = { string = "AI", color = colors.grey, font = { family = settings.font.text, size = 12.0 }, padding_left = 8, padding_right = 4 },
    label = { string = "＋", color = colors.grey, font = { family = settings.font.text, size = 12.0 }, padding_left = 0, padding_right = 10 },
  })
  stub:subscribe("mouse.clicked", function()
    open_settings()
  end)
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
if tail then
  members[#members + 1] = tail.name
end
if stub then
  members[#members + 1] = stub.name
end

local capset = settings.capsule or {}
local bracket = sbar.add("bracket", "widgets.ai_usage.bracket", members, {
  padding_left = 0,
  padding_right = 0,
  background = {
    color = colors.with_alpha(colors.bg1, capset.bg_alpha or 0.32),
    border_width = 1,
    border_color = colors.with_alpha(colors.white, capset.border_alpha or 0.08),
    corner_radius = capset.corner_radius or 12,
    height = capset.height or 30,
  },
  popup = {
    align = "center",
    height = 24,
    blur_radius = 50,
    y_offset = 8,
    background = {
      color = colors.popup.bg,
      border_color = colors.with_alpha(colors.white, 0.08),
      border_width = 1,
      corner_radius = 16,
    },
  },
})

-- 设置页（对应 CodexBar 设置里的 Providers 一栏）：右键用量胶囊，或苹果菜单右键 → AI 用量。
-- 点一下开 / 关一家订阅 → 改写 ai_usage.conf → 稍等一下重启 SketchyBar。
-- 重启走 launchd，和 sbar-layout 一样：组件数量变化大时原地 --reload 会段错误。连点几下只重启一次。
sbar.add("event", "ai_usage_settings")
local enabled, order = {}, {}
for _, id in ipairs(ORDER) do
  enabled[id] = true
  order[#order + 1] = id
end

local function write_conf()
  local file = io.open(CONF, "w")
  if not file then
    return false
  end
  file:write("# SketchyBar AI 订阅用量 —— 设置页（右键用量胶囊 / 苹果菜单右键 → AI 用量）生成，也可以手改。\n")
  file:write("# 每行一个 provider id，从上到下 = 栏内从左到右；行首加 # = 隐藏。\n")
  file:write("# 可选项和来源见 helpers/ai_providers.tsv。\n\n")
  for _, id in ipairs(order) do
    file:write(id, "\n")
  end
  for _, id in ipairs(CATALOG) do
    if not enabled[id] then
      file:write("# ", id, "\n")
    end
  end
  file:close()
  return true
end

local settings_header = sbar.add("item", "widgets.ai_usage.set.header", {
  position = "popup." .. bracket.name,
  icon = { string = "AI 用量", color = colors.white, font = { size = 13.0 }, padding_left = 12 },
  label = { string = "点击开关 · 自动重载", color = colors.grey, font = { size = 11.0 }, padding_right = 12 },
})
settings_header:subscribe("mouse.clicked", function()
  bracket:set({ popup = { drawing = false } })
end)

local restarts = 0
local function schedule_restart()
  restarts = restarts + 1
  local mine = restarts
  settings_header:set({ label = { string = "即将重载…", color = colors.yellow } })
  sbar.exec("sleep 1.5", function()
    if mine ~= restarts then
      return
    end
    sbar.exec([[launchctl kickstart -k "gui/$(id -u)/sh.brew.sketchybar" 2>/dev/null || /opt/homebrew/bin/sketchybar --reload]])
  end)
end

local function paint_row(id)
  local on = enabled[id]
  sbar.set("widgets.ai_usage.set." .. id, {
    icon = { string = on and "●" or "○", color = on and colors.green or colors.grey },
    label = { color = on and colors.white or colors.grey },
  })
end

for _, id in ipairs(CATALOG) do
  local on = enabled[id]
  local row = sbar.add("item", "widgets.ai_usage.set." .. id, {
    position = "popup." .. bracket.name,
    icon = {
      string = on and "●" or "○",
      color = on and colors.green or colors.grey,
      font = { size = 9.0 },
      padding_left = 12,
      padding_right = 0,
    },
    label = {
      string = PROVIDERS[id].title,
      color = on and colors.white or colors.grey,
      font = { size = 13.0 },
      padding_left = 6,
      padding_right = 12,
    },
  })
  row:subscribe("mouse.clicked", function()
    if enabled[id] then
      enabled[id] = nil
      for i, v in ipairs(order) do
        if v == id then
          table.remove(order, i)
          break
        end
      end
    else
      enabled[id] = true
      order[#order + 1] = id -- 新开的排在最右
    end
    paint_row(id)
    if write_conf() then
      schedule_restart()
    end
  end)
end

open_settings = function()
  for _, other in pairs(items) do
    other:set({ popup = { drawing = false } })
  end
  bracket:set({ popup = { drawing = "toggle" } })
end
bracket:subscribe("mouse.exited.global", function()
  bracket:set({ popup = { drawing = false } })
end)
inset:subscribe("ai_usage_settings", function() -- 苹果菜单里的入口
  open_settings()
end)

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

  -- 仪表只在有数据时画；没抓到就退回文字 "--"，免得空轨道被当成“用了 0%”
  if GAUGE and (row.mini or "") ~= "" and (row.status == "ok" or row.status == "stale") then
    item:set({ label = { string = " ", background = { drawing = true, image = { string = row.mini } } } })
  else
    item:set({
      label = {
        string = row.label or "--",
        color = label_color(row.used, row.status),
        background = { drawing = false },
      },
    })
  end

  local p = popups[row.id]
  local plan = row.plan or ""
  local prefix = spec.title .. " "
  if plan:sub(1, #prefix) == prefix then
    plan = plan:sub(#prefix + 1)
  elseif plan == spec.title then
    plan = ""
  end
  p.header:set({
    icon = { string = spec.title, color = colors.grey },
    label = { string = (plan ~= "" and (plan .. "   ↻")) or "↻", color = colors.grey },
  })

  p.hero:set({
    icon = {
      string = row.label or "--",
      color = label_color(row.used, row.status),
    },
    label = {
      string = ((row.reset or "") ~= "" and (row.reset .. " 后重置")) or "",
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
  p.open:set({ label = { string = age_text(row.fetched) } })
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
    elseif f[1] == "U" and rows[f[2]] then
      rows[f[2]].fetched = tonumber_or_nil(f[3])
    elseif f[1] == "M" and rows[f[2]] then
      rows[f[2]].mini = f[3] or ""
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
      -- status = "auth"（key 过期 / 无效）不是临时故障：照样覆盖旧读数，把报错亮出来
      if row and row.seen and row.status ~= "error" and row.status ~= "missing" then
        apply(row)
      elseif row and row.seen and not latest[id] then
        apply(row)
      end
    end
  end)
end

-- 卡片右上角的刷新：只刷这一家，绕过缓存 TTL（ai_usage.py --force，会等别的刷新跑完）
local forcing = {}
force_refresh = function(id)
  if forcing[id] then
    return
  end
  forcing[id] = true
  popups[id].header:set({ label = { string = "刷新中…" } })
  sbar.exec(SCRIPT .. " " .. id .. " --force", function(result)
    forcing[id] = nil
    local row = parse_output(result)[id]
    if row and row.seen and (row.status ~= "error" or not latest[id]) then
      apply(row)
    elseif latest[id] then
      apply(latest[id]) -- 没抓到：恢复原来的读数和按钮
    end
  end)
end

local function toggle_popup(id)
  local item = items[id]
  local drawing = item:query().popup.drawing == "off"
  item:set({ popup = { drawing = drawing } })
  if drawing then
    if latest[id] then -- 打开时先把“xx 前已更新”算到现在，刷新结果回来再覆盖
      popups[id].open:set({ label = { string = age_text(latest[id].fetched) } })
    end
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
  item:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
      open_settings()
    else
      toggle_popup(id)
    end
  end)
  item:subscribe("mouse.exited.global", function()
    item:set({ popup = { drawing = false } })
  end)
end

if ORDER[1] then
  items[ORDER[1]]:subscribe({ "routine", "system_woke", "forced" }, refresh)
end

-- 源 PNG 是纯白，按当前主题重新着色后落到 /tmp，切主题时跟着变
local TINT_DIR = "/tmp/sbar_ai_icons"
local function tint_bar_icons()
  if #ORDER == 0 then
    return
  end
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
