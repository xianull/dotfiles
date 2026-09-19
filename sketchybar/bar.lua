local colors = require("colors")

-- 主屏 + 笔记本都要栏；Sidecar/iPad 不要。
-- 用 arrangement id 列表，不用 all。接入 iPad 时才不会整栏克隆上去。
-- 不要在 display_change 里改 blur，否则会和窗口 backing 互相触发、整栏闪。
sbar.bar({
  position = "top",
  height = 40,
  color = colors.transparent,
  border_color = colors.transparent,
  border_width = 0,
  corner_radius = 0,
  padding_right = 8,
  padding_left = 8,
  margin = 0,
  y_offset = 0,
  shadow = false,
  sticky = true,
  display = "1,2",
  blur_radius = 30,
})

local YABAI = "/opt/homebrew/bin/yabai"
local current_spec = "1,2"

-- iPad Sidecar 点尺寸（11" = 1194×834，13" ≈ 1376×1032）。
-- 5K 缩放桌面和本机 Retina 至少有一条边更大。
local function is_sidecar(w, h)
  return math.max(w, h) <= 1400 and math.min(w, h) <= 1100
end

local function spec_from_list(list)
  local ids = {}
  for _, d in ipairs(list) do
    if type(d) == "table" then
      local f = d.frame or {}
      local i, wf, hf = tonumber(d.index), tonumber(f.w), tonumber(f.h)
      if i and wf and hf and not is_sidecar(wf, hf) then
        ids[#ids + 1] = i
      end
    end
  end
  table.sort(ids)
  if #ids == 0 then
    return "main"
  end
  return table.concat(ids, ",")
end

local function spec_from_json(json)
  -- sbar.exec JSON-decodes yabai --query --displays into a table.
  if type(json) == "table" then
    if json.index and json.frame then
      return spec_from_list({ json })
    end
    return spec_from_list(json)
  end
  if type(json) ~= "string" or not json:match("%S") then
    return current_spec
  end
  local ids = {}
  -- JSON 是多行的；Lua 的 `.` 不匹配换行。
  for idx, w, h in json:gmatch(
    '"index":%s*(%d+)[%s%S]-"frame":%s*{[^}]*"w":%s*([%d%.]+)[^}]*"h":%s*([%d%.]+)'
  ) do
    local i, wf, hf = tonumber(idx), tonumber(w), tonumber(h)
    if i and wf and hf and not is_sidecar(wf, hf) then
      ids[#ids + 1] = i
    end
  end
  table.sort(ids)
  if #ids == 0 then
    return "main"
  end
  return table.concat(ids, ",")
end

local function apply_displays(json)
  local spec = spec_from_json(json)
  if spec == current_spec then
    return
  end
  current_spec = spec
  sbar.bar({ display = spec })
end

local function refresh_displays()
  -- 不要在栏进程里 --query displays，启动/重载时会和自己抢锁。
  sbar.exec(YABAI .. " -m query --displays", apply_displays)
end

refresh_displays()

local guard = sbar.add("item", "display_guard", {
  drawing = false,
  updates = true,
  width = 0,
})
guard:subscribe({ "display_change", "system_woke" }, refresh_displays)
