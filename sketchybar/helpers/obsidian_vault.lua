-- Pure-Lua Obsidian vault resolver for SketchyBar widgets.
-- IMPORTANT: do NOT use io.popen here — pclose can block the whole
-- sketchybarrc load (begin_config never flushes → bar has 0 items).
--
-- Resolution order:
--   1) $OBSIDIAN_VAULT
--   2) currently open vault in Obsidian's obsidian.json
--   3) highest-score existing candidate path
--
-- Vault *name* for obsidian:// URIs is always the folder basename.

local M = {}

local function is_dir_probe(path)
  -- Lua has no isdir; treat "can open a known child" as existence.
  if not path or path == "" then
    return false
  end
  local probes = {
    path .. "/Settings/Scripts/focus_ctl.py",
    path .. "/Settings/cache",
    path .. "/.obsidian",
    path .. "/Settings",
  }
  for i = 1, #probes do
    local f = io.open(probes[i], "r")
    if f then
      f:close()
      return true
    end
  end
  return false
end

local function score_path(path, open_, ts)
  local s = 0
  if open_ then
    s = s + 1000000
  end
  if io.open(path .. "/Settings/Scripts/focus_ctl.py", "r") then
    s = s + 100000
  end
  if io.open(path .. "/Settings/cache/today-focus.json", "r") then
    s = s + 50000
  end
  if io.open(path .. "/Settings", "r") then
    s = s + 10000
  end
  if io.open(path .. "/.obsidian", "r") then
    s = s + 1000
  end
  s = s + math.min((tonumber(ts) or 0), 1e15) / 1e15
  return s
end

local function basename(path)
  return (path:match("([^/]+)/?$") or path)
end

local function from_env()
  local env = os.getenv("OBSIDIAN_VAULT")
  if env and env ~= "" and is_dir_probe(env) then
    return env
  end
  return nil
end

local function from_obsidian_json()
  local cfg = (os.getenv("HOME") or "")
    .. "/Library/Application Support/obsidian/obsidian.json"
  local f = io.open(cfg, "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then
    return nil
  end

  local best_path, best_score = nil, -1
  -- Each vault entry looks like:
  --   "id":{"path":"/Users/.../vault","ts":123,"open":true}
  for raw_path, rest in raw:gmatch('"path"%s*:%s*"(.-)"([^}]*)') do
    -- JSON may escape solidus; normalize
    -- Lua 5.5 for-loop variables are const — do not assign to raw_path.
    local path = raw_path:gsub("\\/", "/")
    if is_dir_probe(path) then
      local open_ = rest:find('"open"%s*:%s*true') ~= nil
      local ts = tonumber(rest:match('"ts"%s*:%s*(%d+)')) or 0
      local sc = score_path(path, open_, ts)
      if sc > best_score then
        best_score = sc
        best_path = path
      end
    end
  end
  return best_path
end

local function from_candidates()
  local home = os.getenv("HOME") or ""
  local list = {
    home .. "/obsidian/元亨利贞",
    home .. "/Documents/obsidian/元亨利贞",
    home .. "/obsidian/元亨利贞2.0",
    home .. "/Documents/obsidian/元亨利贞2.0",
  }
  local best_path, best_score = nil, -1
  for i = 1, #list do
    local path = list[i]
    if is_dir_probe(path) then
      local sc = score_path(path, false, 0)
      if sc > best_score then
        best_score = sc
        best_path = path
      end
    end
  end
  return best_path
end

function M.path()
  return from_env()
    or from_obsidian_json()
    or from_candidates()
    or ((os.getenv("HOME") or "") .. "/obsidian/元亨利贞")
end

function M.name()
  return basename(M.path())
end

return M
