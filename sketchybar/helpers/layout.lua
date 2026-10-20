-- 方案（布局）切换。当前方案名在 .layout 里，`sbar-layout` 命令改它再 reload。
-- 一个方案只是一组覆盖：settings 深合并、bar 参数、加载哪些组件。
-- 配色（.theme / .theme_mode，苹果菜单里切）和方案互相独立，任意组合。
-- 必须在任何组件 require 之前加载：组件在加载时就读 settings 里的字体和胶囊参数。
local M = {}

local FILE = (os.getenv("HOME") or "") .. "/.config/sketchybar/.layout"
local DEFAULT = "islands"

local function read_name()
  local f = io.open(FILE, "r")
  if not f then return DEFAULT end
  local name = (f:read("*l") or ""):match("^%s*([%w_%-]+)%s*$")
  f:close()
  return name or DEFAULT
end

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

M.name = read_name()
local ok, spec = pcall(require, "layouts." .. M.name)
if not ok or type(spec) ~= "table" then
  M.name, spec = DEFAULT, require("layouts." .. DEFAULT)
end
M.spec = spec

if spec.settings then merge(require("settings"), spec.settings) end

-- 方案给了列表就用方案的，否则用调用方的默认列表（= islands 原样）
function M.list(key, default)
  return spec[key] or default
end

function M.bar(base)
  return spec.bar and merge(base, spec.bar) or base
end

return M
