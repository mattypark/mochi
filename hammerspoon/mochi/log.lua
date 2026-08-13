--- A log file, because a pet has nowhere to print.
---
--- Hammerspoon's Console shows hs.printf output, but only if it happens to be
--- open at the moment something goes wrong — which it never is. Anything worth
--- diagnosing later goes to disk as well.
---
--- ~/.hammerspoon/mochi.log, deliberately outside the mochi/ directory: the
--- config pathwatcher reloads on any .lua change under ~/.hammerspoon, and a log
--- file that triggered reloads would be a loop.

local Log = {}

local PATH = os.getenv("HOME") .. "/.hammerspoon/mochi.log"
local MAX_BYTES = 256 * 1024

local function rotate()
  local size = hs.fs.attributes(PATH, "size")
  if not size or size < MAX_BYTES then return end
  os.remove(PATH .. ".1")
  os.rename(PATH, PATH .. ".1")
end

function Log.write(format, ...)
  local ok, line = pcall(string.format, format, ...)
  if not ok then line = tostring(format) end

  hs.printf("mochi: %s", line)

  rotate()
  local file = io.open(PATH, "a")
  if not file then return end
  file:write(os.date("%Y-%m-%d %H:%M:%S "), line, "\n")
  file:close()
end

function Log.path() return PATH end

return Log
