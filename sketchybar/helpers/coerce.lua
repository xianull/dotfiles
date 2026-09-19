-- Coerce sbar.exec callback payloads.
-- SbarLua JSON-decodes command output, so callbacks often get a table or
-- number instead of the raw string that :match expects.
local M = {}

function M.text(x)
  local tx = type(x)
  if tx == "string" then
    return x
  end
  if tx == "number" or tx == "boolean" then
    return tostring(x)
  end
  return ""
end

function M.number(x)
  local tx = type(x)
  if tx == "number" then
    return x
  end
  if tx == "string" then
    return tonumber(x:match("([%-%d%.]+)"))
  end
  return nil
end

return M

