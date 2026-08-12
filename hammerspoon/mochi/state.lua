--- Everything mochi remembers between reloads.
---
--- hs.settings rather than a file: this is small, it is not worth a pathwatcher,
--- and it survives hs.reload() without a save race. Draft history is the
--- exception and goes to disk — see draft.lua, Stage 4.

local State = {}

local KEY = "mochi.state"

local DEFAULTS = {
  x = nil,            -- nil means "work it out from the screen"
  y = nil,
  petWidth = 96,
  hidden = false,
  -- Writing mode is deliberately NOT persisted as on. Reopening Hammerspoon
  -- should never silently resume reading a draft; that has to be an act.
  nagMode = "live",   -- live | pause | ask
}

function State.load()
  local stored = hs.settings.get(KEY)
  if type(stored) ~= "table" then stored = {} end

  local state = {}
  for key, value in pairs(DEFAULTS) do
    if stored[key] ~= nil then state[key] = stored[key] else state[key] = value end
  end

  return state
end

function State.save(state)
  hs.settings.set(KEY, {
    x = state.x,
    y = state.y,
    petWidth = state.petWidth,
    hidden = state.hidden,
    nagMode = state.nagMode,
  })
end

return State
