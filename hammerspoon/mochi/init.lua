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
local Log = require("mochi.log")

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
local askedTwice = false    -- second click on a stuck mode turns it off
local latest = nil          -- the last draft that arrived
local previousWords = nil   -- for the 10% rule; Stage 4 makes this durable

-- -------------------------------------------------------------------- speaking

local function say(headline, detail, footer)
  Log.write("say: %s", headline)
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

--- @return table marks  where the page should draw, sent back in the reply
local function onDraft(draft)
  latest = draft
  Log.write("draft received: %d words, %d blocks", draft.words, #draft.blocks)

  local findings = Rules.check(draft, { previousWords = previousWords })
  Log.write("%d findings, nag mode %s", #findings, state.nagMode)
  Nag.consider(findings, state.nagMode, speak)

  -- Only findings that belong to a paragraph can be pointed at. Word count and
  -- title findings have no block, and marking the whole document for them would
  -- be worse than not marking at all.
  local marks = {}
  for _, item in ipairs(findings) do
    if item.block then
      marks[#marks + 1] = {
        block = item.block,
        rule = item.rule,
        text = item.sample,
        severity = item.severity,
      }
    end
  end

  return marks
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
  Log.write("writing mode %s", writing and "ON" or "off")

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

--- Clicking the pet is the primary control, not a shortcut for one.
---
--- The menu bar cannot be relied on: menu-bar space is finite, macOS drops items
--- silently when it runs out, and menu-bar managers hide them on purpose. A pet
--- whose only switch lives up there is a pet that appears broken through no
--- fault of its own. The sprite is always on screen, so the sprite is the switch.
local function onPetClick()
  -- The menu opens at the pointer rather than in the menu bar, because the menu
  -- bar item is routinely evicted by macOS when the app menus are wide — which
  -- is what made mochi look broken in the first place. The same menu is served
  -- from both places; only the anchor differs.
  if menu then
    menu:popupMenu(hs.mouse.absolutePosition())
    return
  end

  -- No menu object at all: fall back to the single most useful action rather
  -- than doing nothing.
  Mochi.toggleWriting()
end

--- What the menu's "What's wrong with this draft?" item does.
local function showFindings()
  if not writing then
    say("I'm asleep.", "Turn writing mode on and I'll start reading your draft.", "mochi · off")
    return
  end

  if not connected then
    say("Nothing's reaching me yet.",
        "Writing mode is on, but no Substack tab has connected.\nReload the draft tab (⌘R).",
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
    -- Status first and unclickable: the top line of the menu answers "what is
    -- mochi doing right now" before offering to change it.
    {
      title = writing
        and (connected and "Reading your draft" or "Waiting for a draft tab")
        or "Asleep — not reading anything",
      disabled = true,
    },
    { title = "-" },
    {
      title = writing and "Turn writing mode off" or "Turn writing mode on",
      fn = Mochi.toggleWriting,
    },
    {
      title = "What's wrong with this draft?",
      disabled = not writing,
      fn = showFindings,
    },
    { title = "-" },
    {
      title = "When to interrupt me",
      menu = (function()
        local modes = {}
        for _, mode in ipairs(NAG_MODES) do
          modes[#modes + 1] = {
            title = mode.label,
            checked = state.nagMode == mode.id,
            fn = function()
              state.nagMode = mode.id
              State.save(state)
            end,
          }
        end
        return modes
      end)(),
    },
    {
      title = "Playbooks",
      menu = {
        { title = "The Write Path — craft", disabled = true },
        { title = "Slay with Finances — strategy (Stage 8)", disabled = true },
      },
    },
    { title = "-" },
    {
      title = pet and pet:isHidden() and "Show mochi" or "Hide mochi",
      fn = function()
        if not pet then return end
        if pet:isHidden() then pet:show() else pet:hide() end
        State.save(state)
      end,
    },
    { title = "Quit mochi", fn = function() Mochi.quit() end },
  }

  return items
end

-- --------------------------------------------------------------------- life

function Mochi.start()
  Log.write("starting")
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
    Log.write("menu bar item created")
  else
    -- Not fatal, and not silent. macOS refuses new menu-bar items when the bar
    -- is full, which looks identical to the pet being broken.
    Log.write("MENU BAR ITEM FAILED — the bar is probably full. Click the pet instead.")
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

    -- Capabilities beyond the base contract, so a hotkey in petcommands.lua has
    -- something to dispatch to. `toggle` is writing mode, not visibility: the
    -- sprite staying put is the whole point of it.
    toggle = function() Mochi.toggleWriting() end,
    speak = function() onPetClick() end,
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
