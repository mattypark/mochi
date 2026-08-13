--- mochi — a Substack writing coach that lives on the desktop.
---
---   require("mochi")
---
--- The pet is on screen whenever Hammerspoon is running. Writing mode gates only
--- whether the draft is read — and it gates it by opening and closing the bridge
--- socket, not by checking a flag, so "not reading" is verifiable from outside.
---
--- The flow, end to end:
---
---   browser extension → bridge.lua → rules.lua → nag.lua → bubble.lua
---   (reads the DOM)     (websocket)  (findings)  (timing)  (says it)
---
--- Nothing in that chain asks a model anything. The judgement tier is Stage 6
--- and sits alongside, never in front.

local Pet = require("mochi.pet")
local Bubble = require("mochi.bubble")
local Bridge = require("mochi.bridge")
local Rules = require("mochi.rules")
local Nag = require("mochi.nag")
local State = require("mochi.state")

local Mochi = {}

local NAG_MODES = {
  { id = "live",  label = "Nag live, as I type" },
  { id = "pause", label = "Nag when I pause" },
  { id = "ask",   label = "Only when I ask" },
}

local state = State.load()
local pet, bubble, menu
local writing = false
local connected = false
local latest = nil          -- the last draft that arrived
local previousWords = nil   -- for the 10% rule; Stage 4 makes this durable

-- -------------------------------------------------------------------- speaking

local function say(headline, detail, footer)
  if not bubble then return end
  bubble:setAnchor(pet and pet:frame() or nil)
  bubble:show(headline, detail, footer)
end

--- Turn a Nag summary into a bubble. The footer always names the engine.
local function speak(summary)
  if not summary then
    say("Nothing to flag.", nil, "rules · deterministic")
    return
  end

  local headline
  if summary.total == 1 then
    headline = "One thing:"
  else
    headline = string.format("%d things:", summary.total)
  end

  local detail = "· " .. table.concat(summary.lines, "\n· ")
  if summary.hidden > 0 then
    detail = detail .. string.format("\n  (+%d more)", summary.hidden)
  end

  say(headline, detail, "rules · deterministic")
  if pet then pet:nudge() end
end

-- ---------------------------------------------------------------------- drafts

local function onDraft(draft)
  latest = draft

  local findings = Rules.check(draft, { previousWords = previousWords })
  Nag.consider(findings, state.nagMode, speak)
end

local function onStatus(isConnected)
  local was = connected
  connected = isConnected and true or false

  -- Only announced on the transition, and only when he switched writing on —
  -- otherwise this fires on every message.
  if connected and not was and writing then
    say("Reading your draft.", nil, "bridge · connected")
  end
end

-- -------------------------------------------------------------------- writing

--- Writing mode. On starts the bridge; off stops it, which drops the extension's
--- connection rather than leaving a socket open that we promise not to read.
local function setWriting(on)
  writing = on and true or false

  if writing then
    local ok, err = Bridge.start()
    if not ok then
      writing = false
      say("Couldn't open the bridge.", tostring(err), "bridge · failed")
    else
      say("Writing mode on.", "Open a Substack draft and start typing.", "bridge · listening")
    end
  else
    Bridge.stop()
    Nag.reset()
    connected = false
    if bubble then bubble:hide() end
  end

  if pet then pet:setAwake(writing) end
  Mochi.refreshMenu()
end

function Mochi.toggleWriting()
  setWriting(not writing)
end

--- Clicking the pet asks it a direct question, and a direct question always gets
--- an answer — including "I'm not reading anything", which is the answer that
--- was missing when the fade was the only signal.
local function onPetClick()
  if not writing then
    say("I'm asleep.", "Click the menu bar → Writing mode: on, and I'll start reading your draft.",
        "mochi · off")
    return
  end

  if not connected then
    say("Nothing's reaching me yet.",
        "Writing mode is on, but no Substack tab has connected. Reload the draft tab.",
        "bridge · waiting")
    return
  end

  if not latest then
    say("Connected, but the draft is empty.", nil, "bridge · connected")
    return
  end

  Nag.onDemand(speak)
end

-- --------------------------------------------------------------------- menu

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
    {
      title = writing
        and (connected and "  a draft is connected" or "  waiting for a draft tab")
        or "  not reading anything",
      disabled = true,
    },
    { title = "-" },
  }

  for _, mode in ipairs(NAG_MODES) do
    items[#items + 1] = {
      title = mode.label,
      checked = state.nagMode == mode.id,
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
  bubble = Bubble.new()

  pet = Pet.new({
    state = state,
    onClick = onPetClick,
    onDragEnd = function()
      State.save(state)
      if bubble then bubble:setAnchor(pet:frame()) end
    end,
  })

  Bridge.configure({
    onDraft = onDraft,
    onStatus = onStatus,
    onLost = function()
      latest = nil
      say("I can't find the editor on that page.",
          "Substack may have changed its markup — the selector needs updating.",
          "bridge · selector failed")
    end,
  })

  menu = hs.menubar.new()
  if menu then
    menu:setTitle("mochi")
    menu:setMenu(buildMenu)
  end

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
  if bubble then bubble:delete(); bubble = nil end
  if pet then pet:delete(); pet = nil end
  if menu then menu:delete(); menu = nil end
  if _G.PETS then _G.PETS.mochi = nil end
end

function Mochi.isWriting() return writing end
function Mochi.isConnected() return connected end
function Mochi.bridgeUrl() return Bridge.url() end

return Mochi.start()
