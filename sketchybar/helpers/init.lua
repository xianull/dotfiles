-- Add the sketchybar module to the package cpath.
-- Rebuild SbarLua after Homebrew lua upgrades: a stale .so segfaults
-- (lua 5.4 .so + lua 5.5 → empty bar, drawing off).
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

-- Sidecar reconnect can restart the bar. Full `make` is synchronous and
-- `swiftc` for cpu_temp can stall sketchybarrc with 0 items on screen.
-- Resolve from CONFIG_DIR: brew services often start with cwd != config.
local root = os.getenv("CONFIG_DIR")
  or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
local bins = {
  root .. "/helpers/event_providers/cpu_load/bin/cpu_load",
  root .. "/helpers/event_providers/network_load/bin/network_load",
  root .. "/helpers/menus/bin/menus",
  root .. "/helpers/cpu_temp/bin/cpu_temp",
}
local missing = false
for i = 1, #bins do
  local f = io.open(bins[i], "rb")
  if f then
    f:close()
  else
    missing = true
    break
  end
end
if missing then
  os.execute(string.format("(cd %q && make)", root .. "/helpers"))
end
