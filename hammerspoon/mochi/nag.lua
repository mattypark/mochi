--- When mochi speaks. Never *what* — that is rules.lua's job — only when.
---
--- Timing is deterministic on purpose. The single most expensive mistake the
--- cost pet made was letting a model decide when to interrupt: it was
--- unpredictable, unreproducible, and impossible to tune. A clock and a counter
--- can be reasoned about at 2am.
---
--- Three modes, chosen from the menu:
---   live   speak as findings appear (Matthew's default)
---   pause  accumulate silently, speak after a lull in typing
---   ask    never volunteer; speak only when the pet is clicked
---
--- One rule survives every mode: the same finding is never said twice in a row.
--- A checker that repeats itself gets tuned out, and a tuned-out checker is off.

local Nag = {}

local PAUSE_SECONDS = 20     -- a lull long enough to mean "thinking", not "typing"
local LIVE_COOLDOWN = 6      -- floor between spoken findings in live mode
local MAX_LINES = 4          -- more than this in one bubble is a wall, not a nag

local lastSpokenAt = 0
local lastSignature = nil
local pending = nil
local pauseTimer = nil

--- Findings collapse to one line each, most severe first, capped. Two adverbs in
--- one paragraph is one problem to a writer, even though it is two findings to
--- the checker.
local function summarise(findings)
  local structural, nags = {}, {}

  for _, item in ipairs(findings) do
    local line = item.message
    if item.severity == "structural" then
      structural[#structural + 1] = line
    else
      nags[#nags + 1] = line
    end
  end

  local lines = {}
  for _, line in ipairs(structural) do
    if #lines >= MAX_LINES then break end
    lines[#lines + 1] = line
  end
  for _, line in ipairs(nags) do
    if #lines >= MAX_LINES then break end
    lines[#lines + 1] = line
  end

  local hidden = (#structural + #nags) - #lines

  return {
    lines = lines,
    hidden = hidden,
    structural = #structural,
    total = #structural + #nags,
    signature = table.concat(lines, "|"),
  }
end

--- @param findings table   from Rules.check
--- @param mode string      live | pause | ask
--- @param speak function(summary)  called when it is time to say something
function Nag.consider(findings, mode, speak)
  if #findings == 0 then
    pending = nil
    return
  end

  local summary = summarise(findings)
  pending = summary

  if mode == "ask" then return end

  if mode == "pause" then
    -- Every keystroke pushes the deadline out, so the bubble lands in a gap
    -- rather than mid-sentence.
    if pauseTimer then pauseTimer:stop() end
    pauseTimer = hs.timer.doAfter(PAUSE_SECONDS, function()
      Nag.flush(speak)
    end)
    return
  end

  -- live
  local now = os.time()
  local quiet = (now - lastSpokenAt) >= LIVE_COOLDOWN

  -- Structural findings jump the cooldown. A wall of text or a stadium opener
  -- gets more expensive to fix the longer it sits there; an adverb does not.
  if summary.structural > 0 or quiet then
    Nag.flush(speak)
  end
end

--- Say whatever is pending, if it isn't what was just said.
function Nag.flush(speak)
  if not pending then return false end
  if pending.signature == lastSignature then return false end

  lastSpokenAt = os.time()
  lastSignature = pending.signature
  speak(pending)
  return true
end

--- The click path: says the current state even if it was just said, because the
--- click is a direct question and silence would read as broken.
function Nag.onDemand(speak)
  if not pending then
    speak(nil)
    return
  end

  lastSpokenAt = os.time()
  lastSignature = pending.signature
  speak(pending)
end

function Nag.reset()
  pending = nil
  lastSignature = nil
  lastSpokenAt = 0
  if pauseTimer then pauseTimer:stop(); pauseTimer = nil end
end

return Nag
