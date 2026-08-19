--- Tests for draft history and the 10% rule.
---
---   lua tests/draft_spec.lua
---
--- Only the pure decisions are covered: which session counts as the previous
--- one, what gets discarded, how the key is derived. Load and save are three
--- lines of io each and need Hammerspoon's json, so they are exercised by
--- running the pet rather than here.

package.path = table.concat({
  "hammerspoon/?.lua",
  "hammerspoon/?/init.lua",
  package.path,
}, ";")

local Draft = require("mochi.draft")

local passed, failed = 0, 0

local function check(name, got, want)
  if got == want then
    passed = passed + 1
    print(string.format("  ok    %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s\n          got %s, wanted %s",
      name, tostring(got), tostring(want)))
  end
end

--- Write a whole session in one call: begin, record `words`, finish.
local function session(history, url, words, at)
  history = Draft.begin(history, url, at)
  Draft.record(history, { words = words, title = "t" }, at)
  return Draft.finish(history, at + 60)
end

print("draft")

-- keys ------------------------------------------------------------------------

check("keys on the post id, not the title",
  Draft.key("https://mattypark.substack.com/publish/post/12345"), "post-12345")

check("the same post keeps its key after a rename",
  Draft.key("https://mattypark.substack.com/publish/post/12345?title=whatever"),
  "post-12345")

check("falls back to a slug when there is no post id",
  Draft.key("https://example.com/some/page"), "example-com-some-page")

check("survives a missing url", Draft.key(nil), "unknown")

-- the previous draft ----------------------------------------------------------

check("no history means nothing to compare against",
  Draft.previousWords(nil), nil)

local h = Draft.begin(nil, "u", 100)
Draft.record(h, { words = 900 }, 100)
check("an open session is not its own predecessor",
  Draft.previousWords(h), nil)

h = session(nil, "u", 1000, 100)
check("a finished session becomes the thing to beat",
  Draft.previousWords(h), 1000)

h = session(h, "u", 900, 300)
check("the most recent finished session wins",
  Draft.previousWords(h), 900)

-- what counts as a draft ------------------------------------------------------

h = session(nil, "u", 40, 100)
check("a session under the floor is discarded",
  #h.sessions, 0)

check("...and leaves nothing to compare against",
  Draft.previousWords(h), nil)

h = session(nil, "u", 1000, 100)
h = session(h, "u", 30, 300)
check("a typo fix does not become the new baseline",
  Draft.previousWords(h), 1000)

-- the final count, not the peak -----------------------------------------------

h = Draft.begin(nil, "u", 100)
Draft.record(h, { words = 2000 }, 100)
Draft.record(h, { words = 1500 }, 200)   -- he cut it back
h = Draft.finish(h, 300)
check("a session that grew then shrank counts as what it ended at",
  Draft.previousWords(h), 1500)

check("...though the peak is still recorded",
  h.sessions[1].peak, 2000)

-- numbering -------------------------------------------------------------------

check("the first session is draft 1", Draft.number(nil), 1)

h = session(nil, "u", 1000, 100)
check("after one finished session, the next is draft 2", Draft.number(h), 2)

-- the rule itself -------------------------------------------------------------

local Rules = require("mochi.rules")

local function firesTenPercent(words, previous)
  local findings = Rules.check(
    { title = "", blocks = {}, body = "", words = words },
    { previousWords = previous }
  )
  for _, item in ipairs(findings) do
    if item.rule == "tenpercent" then return true end
  end
  return false
end

check("a draft that grew is flagged", firesTenPercent(1200, 1000), true)
check("a draft down 3% is still nagged", firesTenPercent(970, 1000), true)
check("a draft down 10% is left alone", firesTenPercent(900, 1000), false)
check("a draft down 20% is left alone", firesTenPercent(800, 1000), false)
check("with no previous draft it stays quiet", firesTenPercent(1200, nil), false)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
