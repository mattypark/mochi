--- mochi — a Substack writing coach that lives on the desktop.
---
---   require("mochi")
---
--- What exists at this stage: the pet, its menu, and writing mode. The pet is on
--- screen whenever Hammerspoon is running; writing mode gates only whether the
--- draft is read. Turning mode on with no browser extension connected is not an
--- error — it means nothing is arriving yet, and the menu says so rather than
--- pretending to work.

local Pet = require("mochi.pet")
local State = require("mochi.state")

local Mochi = {}

local NAG_MODES = {
  { id = "live",  label = "Nag live, as I type" },
  { id = "pause", label = "Nag when I pause" },
  { id = "ask",   label = "Only when I ask" },
}

local state = State.load()
local pet, menu
local writing = false

-- ------------------------------------------------------------------ writing

--- Writing mode. Off is a real off: Stage 2 closes the bridge socket rather than
--- ignoring what arrives on it, so "not reading" is verifiable from outside
--- rather than a promise made in a callback.
local function setWriting(on)
  writing = on and true or false
  if pet then pet:setAwake(writing) end
  if Mochi.onWritingChanged then Mochi.onWritingChanged(writing) end
  if menu then Mochi.refreshMenu() end
end

function Mochi.toggleWriting()
  setWriting(not writing)
end

-- --------------------------------------------------------------------- menu

local function nagLabel()
  for _, mode in ipairs(NAG_MODES) do
    if mode.id == state.nagMode then return mode.label end
  end
  return state.nagMode
end

--- The menu bar title carries the mode, so writing mode is legible without
--- opening anything. The menu items themselves are built on demand by
--- `setMenu(fn)` and need no refreshing.
function Mochi.refreshMenu()
  if not menu then return end
  menu:setTitle(writing and "mochi ●" or "mochi")
end

local function buildMenu()
  local items = {
    {
      title = writing and "Writing mode: on" or "Writing mode: off",
      fn = Mochi.toggleWriting,
      checked = writing,
    },
    { title = "-" },
  }

  for _, mode in ipairs(NAG_MODES) do
    items[#items + 1] = {
      title = mode.label,
      checked = state.nagMode == mode.id,
      -- Greyed out until mode is on, because choosing how mochi interrupts is
      -- meaningless while it isn't reading anything.
      disabled = not writing,
      fn = function()
        state.nagMode = mode.id
        State.save(state)
      end,
    }
  end

  items[#items + 1] = { title = "-" }
  items[#items + 1] = {
    title = pet and pet:isHidden() and "Show mochi" or "Hide mochi",
    fn = function()
      if not pet then return end
      if pet:isHidden() then pet:show() else pet:hide() end
      State.save(state)
    end,
  }
  items[#items + 1] = { title = "Quit mochi", fn = function() Mochi.quit() end }

  return items
end

-- --------------------------------------------------------------------- life

function Mochi.start()
  pet = Pet.new({
    state = state,
    onClick = function() Mochi.toggleWriting() end,
    onDragEnd = function() State.save(state) end,
  })

  menu = hs.menubar.new()
  if menu then
    menu:setTitle("mochi")
    menu:setMenu(buildMenu)
  end

  -- The bus contract: write our own handle, never read another pet's.
  _G.PETS = _G.PETS or {}
  _G.PETS.mochi = {
    name = "mochi",
    label = "mochi",
    api = 1,
    show = function() if pet then pet:show() end end,
    hide = function() if pet then pet:hide() end end,
    isHidden = function() return pet and pet:isHidden() or false end,
    quit = function() Mochi.quit() end,
  }

  return Mochi
end

function Mochi.quit()
  setWriting(false)
  if pet then pet:delete(); pet = nil end
  if menu then menu:delete(); menu = nil end
  if _G.PETS then _G.PETS.mochi = nil end
end

function Mochi.isWriting() return writing end
function Mochi.nagMode() return state.nagMode end
function Mochi.nagLabel() return nagLabel() end

return Mochi.start()
