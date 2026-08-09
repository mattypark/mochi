--- The deterministic tier: everything in the playbook that can be checked
--- without asking a model anything.
---
--- This is the foundation, not the cheap version. It is instant, it costs
--- nothing, and — unlike the judgement tier — it cannot be wrong about the text,
--- only about whether the text matters. Every finding says which rule produced
--- it, so a critique is always attributable to a line in this file.
---
--- Plain Lua on purpose: no `hs.*` anywhere, so the whole tier is testable
--- outside Hammerspoon.
---
--- Severity decides interruption, and nothing else:
---   "structural"  worth breaking concentration for — shape problems that only
---                 get more expensive the longer they go unnoticed
---   "nag"         accumulates quietly; nag.lua decides when it surfaces

local Lexicon = require("mochi.lexicon")

local Rules = {}

local WORD_MIN = 800
local WORD_MAX = 2000
local WORD_TARGET = 1800
local WALL_SENTENCES = 5     -- a paragraph longer than this is a wall
local ROBOT_RATIO = 0.7      -- share of one-sentence paragraphs that reads as LinkedIn
local ROBOT_MIN_BLOCKS = 6   -- below this the ratio means nothing

-- --------------------------------------------------------------------- text

--- Curly punctuation normalised to ASCII. Lua patterns match bytes, and a
--- smart apostrophe is three of them — without this, "don't" and "don’t" behave
--- differently, which is a bug nobody would ever think to look for.
local function normalise(text)
  return (text or "")
    :gsub("\226\128\153", "'")   -- ’
    :gsub("\226\128\152", "'")   -- ‘
    :gsub("\226\128\156", '"')   -- “
    :gsub("\226\128\157", '"')   -- ”
    :gsub("\226\128\148", " - ") -- —
    :gsub("\226\128\147", " - ") -- –
end

local function lower(text)
  return normalise(text):lower()
end

--- Sentence count. Abbreviations and decimals would each need their own
--- exception; terminators followed by a space is close enough for a rule whose
--- only job is "is this paragraph too long".
local function countSentences(text)
  local count = 0
  for _ in normalise(text):gmatch("[%.!%?]+[%s\"']*") do count = count + 1 end
  if count == 0 and #text > 0 then count = 1 end
  return count
end

local function words(text)
  local out = {}
  for word in normalise(text):gmatch("[%a'][%a'-]*") do out[#out + 1] = word end
  return out
end

local function trim(text, limit)
  text = normalise(text):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if limit and #text > limit then text = text:sub(1, limit - 1) .. "…" end
  return text
end

--- Blocks whose prose is his. A quotation is someone else's sentence: flagging
--- its adverbs is a false positive, and false positives are how a checker earns
--- being switched off. Headings are his, but they are titles rather than prose,
--- so the sentence-level rules leave them alone too.
local SKIP = { blockquote = true, pre = true, figcaption = true }

local function ownProse(block)
  return block and block.text and block.text ~= "" and not SKIP[block.tag]
end

--- Iterate only the blocks a sentence-level rule should judge, keeping the
--- original index so a finding still points at the right paragraph.
local function proseBlocks(draft)
  local blocks = draft.blocks or {}
  local index = 0

  return function()
    while true do
      index = index + 1
      local block = blocks[index]
      if block == nil then return nil end
      if ownProse(block) then return index, block end
    end
  end
end

-- ------------------------------------------------------------------ findings

local function finding(list, item)
  list[#list + 1] = {
    rule = item.rule,
    severity = item.severity or "nag",
    message = item.message,
    block = item.block,
    sample = item.sample,
    engine = "rules",
  }
end

-- -------------------------------------------------------------------- adverbs

--- "-ly" words, minus the ones that only look like adverbs. Where a heavier verb
--- is known for the exact pair, it is offered — that is the actual advice.
function Rules.adverbs(draft, out)
  for index, block in proseBlocks(draft) do
    local text = lower(block.text)

    for pair, heavier in pairs(Lexicon.heavierVerbs) do
      if text:find(pair, 1, true) then
        finding(out, {
          rule = "adverb",
          message = string.format('"%s" → "%s"', pair, heavier),
          block = index,
          sample = pair,
        })
      end
    end

    for _, word in ipairs(words(block.text)) do
      local lowered = word:lower()
      if #lowered > 4 and lowered:sub(-2) == "ly" and not Lexicon.notAdverbs[lowered] then
        finding(out, {
          rule = "adverb",
          message = string.format('"%s" — cut it, use a heavier verb', lowered),
          block = index,
          sample = lowered,
        })
      end
    end
  end
end

-- -------------------------------------------------------------------- passive

--- A form of "to be" followed by a past participle. "by" is not required: the
--- agentless passive ("mistakes were made") is the one worth catching, and
--- requiring "by" would miss exactly those.
function Rules.passive(draft, out)
  for index, block in proseBlocks(draft) do
    local list = words(block.text)

    for i = 1, #list - 1 do
      local first = list[i]:lower()
      local second = list[i + 1]:lower()

      if Lexicon.beVerbs[first] then
        local participle = Lexicon.irregularParticiples[second]
          or (#second > 4 and second:sub(-2) == "ed")

        if participle then
          local agent = list[i + 2] and list[i + 2]:lower() == "by"
          finding(out, {
            rule = "passive",
            message = string.format('"%s %s%s" — make it active', first, second,
                                    agent and " by" or ""),
            block = index,
            sample = first .. " " .. second,
          })
        end
      end
    end
  end
end

-- -------------------------------------------------------------------- stadium

function Rules.stadium(draft, out)
  for index, block in proseBlocks(draft) do
    local text = lower(block.text)
    for _, entry in ipairs(Lexicon.stadium) do
      if text:find(entry.pattern, 1, true) then
        finding(out, {
          rule = "stadium",
          -- Structural: this is a posture problem, not a word choice. Left
          -- alone it sets the voice for the whole piece.
          severity = "structural",
          message = string.format('"%s" — %s', entry.pattern, entry.fix),
          block = index,
          sample = entry.pattern,
        })
      end
    end
  end
end

-- ------------------------------------------------------------------- inflated

function Rules.inflated(draft, out)
  for index, block in proseBlocks(draft) do
    local text = " " .. lower(block.text) .. " "

    for bloated, plain in pairs(Lexicon.inflated) do
      -- Bounded by non-letters so "very" doesn't fire inside "every".
      local found = text:find("[^%a]" .. bloated:gsub("%-", "%%-") .. "[^%a]")
      if found then
        finding(out, {
          rule = "inflated",
          message = string.format('"%s" → %s', bloated, plain),
          block = index,
          sample = bloated,
        })
      end
    end
  end
end

-- ----------------------------------------------------------------- word count

function Rules.length(draft, out)
  local count = draft.words or 0
  if count == 0 then return end

  if count > WORD_MAX then
    finding(out, {
      rule = "length",
      severity = "structural",
      message = string.format("%d words — over the 2000 ceiling, start cutting", count),
    })
  elseif count < WORD_MIN then
    -- Not structural: every draft passes through "too short" on its way to
    -- finished, and interrupting for that would fire on an empty page.
    finding(out, {
      rule = "length",
      message = string.format("%d words — the band is 800–2000, aim at %d", count, WORD_TARGET),
    })
  end
end

-- ---------------------------------------------------------------- paragraphs

--- Two opposite failures, one rule: paragraphs that never break, and paragraphs
--- that break after every sentence.
function Rules.rhythm(draft, out)
  local blocks = draft.blocks or {}
  local prose, single = 0, 0

  for index, block in ipairs(blocks) do
    if block.tag == "p" and #block.text > 0 then
      prose = prose + 1
      local sentences = countSentences(block.text)
      if sentences == 1 then single = single + 1 end

      if sentences > WALL_SENTENCES then
        finding(out, {
          rule = "wall",
          severity = "structural",
          message = string.format("paragraph %d runs %d sentences — break it up",
                                  index, sentences),
          block = index,
          sample = trim(block.text, 60),
        })
      end
    end
  end

  if prose >= ROBOT_MIN_BLOCKS and (single / prose) >= ROBOT_RATIO then
    finding(out, {
      rule = "robot",
      severity = "structural",
      message = string.format("%d of %d paragraphs are one sentence — this reads like LinkedIn",
                              single, prose),
    })
  end
end

-- --------------------------------------------------------------------- title

--- Outcome-driven, ideally with a number; never poetic, never academic.
function Rules.title(draft, out)
  local title = trim(draft.title or "")
  if title == "" then return end

  local lowered = title:lower()

  for _, phrase in ipairs(Lexicon.titlePoetic) do
    if lowered:find(phrase, 1, true) then
      finding(out, {
        rule = "title",
        severity = "structural",
        message = string.format('title is poetic ("%s") — promise an outcome instead', phrase),
        sample = title,
      })
      return
    end
  end

  for _, phrase in ipairs(Lexicon.titleAcademic) do
    if lowered:find(phrase, 1, true) then
      finding(out, {
        rule = "title",
        severity = "structural",
        message = string.format('title is academic ("%s") — promise an outcome instead', phrase),
        sample = title,
      })
      return
    end
  end

  local hasNumber = lowered:find("%d") ~= nil

  local outcome = false
  for _, phrase in ipairs(Lexicon.titleOutcome) do
    if lowered:find(phrase, 1, true) then outcome = true; break end
  end

  if not outcome then
    finding(out, {
      rule = "title",
      message = "title names a topic, not an outcome — what does the reader get?",
      sample = title,
    })
  elseif not hasNumber then
    finding(out, {
      rule = "title",
      message = "no number in the title — a concrete one earns the click",
      sample = title,
    })
  end
end

-- ------------------------------------------------------------------- ten percent

--- The second draft should be about 10% shorter than the first. `previous` is
--- the earlier snapshot's word count; without one there is nothing to compare
--- and the rule stays quiet rather than guessing.
function Rules.tenPercent(draft, previous, out)
  if not previous or previous <= 0 then return end

  local count = draft.words or 0
  if count == 0 then return end

  local delta = (count - previous) / previous

  if delta > 0.02 then
    finding(out, {
      rule = "tenpercent",
      message = string.format("draft is %d%% longer than the last one — the second pass cuts 10%%",
                              math.floor(delta * 100 + 0.5)),
    })
  elseif delta > -0.10 then
    finding(out, {
      rule = "tenpercent",
      message = string.format("down %d%% so far — 10%% is the target",
                              math.floor(-delta * 100 + 0.5)),
    })
  end
end

-- ---------------------------------------------------------------------- all

--- @param draft table     { title, subtitle, blocks, body, words }
--- @param opts table|nil  { previousWords = n }
--- @return table findings, table counts
function Rules.check(draft, opts)
  opts = opts or {}

  local out = {}
  if type(draft) ~= "table" then return out, { structural = 0, nag = 0 } end

  Rules.title(draft, out)
  Rules.length(draft, out)
  Rules.rhythm(draft, out)
  Rules.stadium(draft, out)
  Rules.adverbs(draft, out)
  Rules.passive(draft, out)
  Rules.inflated(draft, out)
  Rules.tenPercent(draft, opts.previousWords, out)

  local counts = { structural = 0, nag = 0 }
  for _, item in ipairs(out) do
    counts[item.severity] = (counts[item.severity] or 0) + 1
  end

  return out, counts
end

return Rules
