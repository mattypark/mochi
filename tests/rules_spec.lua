--- Tests for the deterministic tier.
---
---   lua tests/rules_spec.lua              from the repo root
---   dofile(".../rules_spec.lua")          from the Hammerspoon console
---
--- No test framework: the tier has no dependencies, and neither should its
--- tests. A failure prints the rule that was expected and the findings that
--- actually came back, which is the only thing worth knowing here.

package.path = table.concat({
  "hammerspoon/?.lua",
  "hammerspoon/?/init.lua",
  (...) and "" or "",
  package.path,
}, ";")

local Rules = require("mochi.rules")

local passed, failed = 0, 0

--- `paragraphs` is the shorthand for a body of plain <p>; `blocks` is the long
--- form, for the cases where the tag itself is what's under test.
local function draft(spec)
  local blocks = spec.blocks or {}
  local texts = {}

  if not spec.blocks then
    for _, text in ipairs(spec.paragraphs or {}) do
      blocks[#blocks + 1] = { tag = "p", text = text }
    end
  end

  for _, block in ipairs(blocks) do texts[#texts + 1] = block.text end

  local body = table.concat(texts, "\n\n")
  local count = 0
  for _ in body:gmatch("[%a'][%a'-]*") do count = count + 1 end

  return {
    title = spec.title or "",
    subtitle = spec.subtitle or "",
    blocks = blocks,
    body = body,
    words = spec.words or count,
  }
end

local function ruleFired(findings, rule)
  for _, item in ipairs(findings) do
    if item.rule == rule then return item end
  end
  return nil
end

local function describe(findings)
  local lines = {}
  for _, item in ipairs(findings) do
    lines[#lines + 1] = string.format("      [%s/%s] %s", item.rule, item.severity, item.message)
  end
  if #lines == 0 then lines[1] = "      (nothing)" end
  return table.concat(lines, "\n")
end

--- @param expect boolean  whether `rule` should have fired
local function test(name, spec, rule, expect, opts)
  local findings = Rules.check(draft(spec), opts)
  local hit = ruleFired(findings, rule)

  if (hit ~= nil) == expect then
    passed = passed + 1
    print(string.format("  ok    %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s\n    expected %s to %sfire. findings:\n%s",
      name, rule, expect and "" or "not ", describe(findings)))
  end
end

print("rules")

-- adverbs ---------------------------------------------------------------------

test("flags an -ly adverb",
  { paragraphs = { "He quickly opened the door and left." } },
  "adverb", true)

test("offers the heavier verb for a known pair",
  { paragraphs = { "She ran quickly to the station." } },
  "adverb", true)

test("does not flag -ly words that are not adverbs",
  { paragraphs = { "The family sent a reply about the supply." } },
  "adverb", false)

test("does not critique text inside a blockquote",
  { blocks = {
      { tag = "blockquote", text = "If you've got an idea, start today. There's honestly no better time than now." },
      { tag = "p", text = "I never knew what I wanted to do in life." },
    } },
  "adverb", false)

-- passive ---------------------------------------------------------------------

test("flags a regular passive",
  { paragraphs = { "The article was written by a stranger." } },
  "passive", true)

test("flags an agentless passive",
  { paragraphs = { "Mistakes were made that season." } },
  "passive", true)

test("leaves active voice alone",
  { paragraphs = { "A stranger wrote the article that season." } },
  "passive", false)

-- stadium ---------------------------------------------------------------------

test("flags stadium-talk",
  { paragraphs = { "Hey guys, welcome back to the newsletter." } },
  "stadium", true)

test("leaves one-reader address alone",
  { paragraphs = { "You have been here before, and you know how this goes." } },
  "stadium", false)

-- inflated --------------------------------------------------------------------

test("flags an inflated word",
  { paragraphs = { "We utilize the platform in order to reach people." } },
  "inflated", true)

test("does not fire on 'every' for 'very'",
  { paragraphs = { "Every morning the same thing happens again." } },
  "inflated", false)

-- length ----------------------------------------------------------------------

test("flags a draft over the ceiling",
  { paragraphs = { "word" }, words = 2400 },
  "length", true)

test("accepts a draft inside the band",
  { paragraphs = { "word" }, words = 1750 },
  "length", false)

-- rhythm ----------------------------------------------------------------------

test("flags a wall of text",
  { paragraphs = { "One. Two. Three. Four. Five. Six. Seven." } },
  "wall", true)

test("flags LinkedIn-robot formatting",
  { paragraphs = {
      "This is one line.", "So is this one.", "And this one.",
      "Every line stands alone.", "Nothing connects.", "It reads like a robot.",
    } },
  "robot", true)

test("accepts varied paragraphs",
  { paragraphs = {
      "This paragraph carries two sentences. The second one continues the thought properly.",
      "A short one.",
      "Then a longer one again, which runs on for a while. It carries a second clause too.",
      "Another short beat.",
      "And a closing paragraph that takes its time. It earns the space it uses.",
      "Done.",
    } },
  "robot", false)

-- title -----------------------------------------------------------------------

test("flags a poetic title",
  { title = "Sifting Through the Noise", paragraphs = { "Body." } },
  "title", true)

test("flags an academic title",
  { title = "An Analysis of Newsletter Growth", paragraphs = { "Body." } },
  "title", true)

test("accepts an outcome title with a number",
  { title = "How I Got 20,585 Subscribers in 90 Days", paragraphs = { "Body." } },
  "title", false)

test("nags an outcome title with no number",
  { title = "How I Grew My Newsletter", paragraphs = { "Body." } },
  "title", true)

-- ten percent -----------------------------------------------------------------

test("flags a second draft that grew",
  { paragraphs = { "word" }, words = 1200 },
  "tenpercent", true, { previousWords = 1000 })

test("stays quiet once 10% is cut",
  { paragraphs = { "word" }, words = 890 },
  "tenpercent", false, { previousWords = 1000 })

test("stays quiet with no previous draft",
  { paragraphs = { "word" }, words = 1200 },
  "tenpercent", false)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
