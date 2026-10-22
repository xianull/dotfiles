-- 硬件监控（cpu / gpu / 内存 / 温度 / 网速）共用的样式，和 AI 用量仪表同一套语言：
-- 平时全用主题前景色（曲线淡一点、数字实色），只有高负载才变橙 / 红。
-- 之前 cpu / gpu / memory 是三份复制粘贴的代码，样式改一次要改三遍，现在收在这里。
local colors = require("colors")
local settings = require("settings")

local M = {}

local LINE = colors.with_alpha(colors.white, 0.6) -- 平时的曲线色

-- value 到 orange 变橙、到 red 变红；返回 数字色, 曲线色
function M.tint(value, orange, red)
  if value >= red then
    return colors.red, colors.red
  elseif value >= orange then
    return colors.orange, colors.orange
  end
  return colors.white, LINE
end

-- cpu / gpu / memory 共用的小曲线：图标 + 曲线 + 数字，三者同一行、垂直居中（和温度、音量的数字在一条线上）
function M.graph(name, icon, extra)
  local props = {
    position = "right",
    graph = { color = LINE, fill_color = colors.with_alpha(colors.white, 0.1), line_width = 1.0 },
    -- 数字在曲线右边、不再叠在上面，所以曲线可以做高一点
    background = { height = 12, color = { alpha = 0 }, border_color = { alpha = 0 }, drawing = true },
    icon = { string = icon, color = colors.grey, font = extra and extra.icon_font or { size = 14.0 } },
    label = {
      string = "--%",
      font = { family = settings.font.numbers, size = 11.0 },
      align = "right",
      padding_left = 4,
      padding_right = 0,
      width = 30, -- 定宽右对齐：数字位数变化时整组不抖；够放 "100%"
    },
    padding_right = settings.paddings + 6,
  }
  for k, v in pairs(extra or {}) do
    if k ~= "icon_font" then
      props[k] = v
    end
  end
  return sbar.add("graph", name, 42, props)
end

function M.show(item, value, orange, red)
  local text, line = M.tint(value, orange, red)
  item:push({ value / 100. })
  item:set({
    graph = { color = line, fill_color = colors.with_alpha(line, 0.12) },
    label = { string = string.format("%d%%", math.floor(value + 0.5)), color = text },
  })
end

function M.idle(item)
  item:set({ graph = { color = colors.grey }, label = { string = "--%", color = colors.grey } })
end

return M
