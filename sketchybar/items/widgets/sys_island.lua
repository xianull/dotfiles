-- System island expand/collapse. Default: memory only.
-- Hidden: cpu_temp, cpu, gpu, wifi. State persists across reloads.
local icons = require("icons")

local M = {}
local STATE = (os.getenv("HOME") or "") .. "/.cache/sketchybar/sys_island_expanded"

M.expanded = false
local fh = io.open(STATE, "r")
if fh then
  local line = fh:read("*l")
  fh:close()
  M.expanded = line == "1"
end

M.hidden = {
  "widgets.cpu_temp",
  "widgets.cpu",
  "widgets.gpu",
  "widgets.wifi1",
  "widgets.wifi2",
  "widgets.wifi.padding",
}

local function persist()
  local dir = STATE:match("^(.*)/")
  if dir then
    os.execute("mkdir -p '" .. dir:gsub("'", "'\\''") .. "'")
  end
  local out = io.open(STATE, "w")
  if out then
    out:write(M.expanded and "1" or "0")
    out:close()
  end
end

function M.apply()
  for _, name in ipairs(M.hidden) do
    sbar.set(name, { drawing = M.expanded })
  end
  if M.toggle then
    M.toggle:set({
      icon = {
        string = M.expanded and icons.chevron.right or icons.chevron.left,
      },
    })
  end
end

function M.set_expanded(on)
  M.expanded = not not on
  persist()
  M.apply()
end

function M.toggle_expanded()
  M.set_expanded(not M.expanded)
end

return M
