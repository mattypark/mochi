--- Word lists for the deterministic tier.
---
--- Kept apart from rules.lua because these change for editorial reasons and the
--- matching logic changes for engineering reasons, and mixing the two makes both
--- harder to review. Nothing in here executes.

local Lexicon = {}

--- Words ending in -ly that are not adverbs. Without this list every "family",
--- "reply" and "supply" is reported as an adverb, and a checker that cries wolf
--- gets switched off within a day.
Lexicon.notAdverbs = {
  ally = true, anomaly = true, apply = true, assembly = true, belly = true,
  bully = true, comply = true, cheaply = true, curly = true, daily = true,
  dolly = true, duly = true, early = true, family = true, folly = true,
  gully = true, holy = true, hilly = true, imply = true, italy = true,
  jelly = true, jolly = true, july = true, lily = true, lonely = true,
  lovely = true, melancholy = true, monopoly = true, multiply = true,
  only = true, panoply = true, rally = true, rely = true, reply = true,
  silly = true, sly = true, supply = true, tally = true, ugly = true,
  wally = true, weekly = true, monthly = true, yearly = true, ply = true,
}

--- verb + adverb → the heavier verb that replaces both. The playbook's advice is
--- "cut it, use a heavier verb", which is far more useful with the verb attached.
Lexicon.heavierVerbs = {
  ["run quickly"] = "sprint",
  ["ran quickly"] = "sprinted",
  ["walk slowly"] = "amble",
  ["walked slowly"] = "ambled",
  ["say loudly"] = "shout",
  ["said loudly"] = "shouted",
  ["say quietly"] = "murmur",
  ["said quietly"] = "murmured",
  ["look quickly"] = "glance",
  ["looked quickly"] = "glanced",
  ["eat quickly"] = "devour",
  ["ate quickly"] = "devoured",
  ["laugh loudly"] = "roar",
  ["laughed loudly"] = "roared",
  ["cry loudly"] = "wail",
  ["cried loudly"] = "wailed",
  ["move slowly"] = "crawl",
  ["moved slowly"] = "crawled",
  ["hit hard"] = "slam",
  ["hit hard"] = "slammed",
  ["completely destroy"] = "raze",
  ["completely destroyed"] = "razed",
  ["very big"] = "vast",
  ["very small"] = "tiny",
  ["very tired"] = "exhausted",
  ["very angry"] = "furious",
  ["very happy"] = "elated",
  ["very important"] = "vital",
}

--- Writing to a stadium instead of to one person. The playbook is emphatic that
--- one reader is the whole posture, and these openers give the game away.
Lexicon.stadium = {
  { pattern = "hey guys",                 fix = "write to one person — drop the crowd" },
  { pattern = "hi guys",                  fix = "write to one person — drop the crowd" },
  { pattern = "hey everyone",             fix = "write to one person — drop the crowd" },
  { pattern = "hi everyone",              fix = "write to one person — drop the crowd" },
  { pattern = "hello everyone",           fix = "write to one person — drop the crowd" },
  { pattern = "welcome back",             fix = "they never left. start with the story" },
  { pattern = "as many of you know",      fix = "you're talking to a crowd again" },
  { pattern = "as you all know",          fix = "you're talking to a crowd again" },
  { pattern = "for those of you who",     fix = "one reader. use \"you\"" },
  { pattern = "all of you",               fix = "one reader. use \"you\"" },
  { pattern = "my readers",               fix = "say \"you\"" },
  { pattern = "thanks for tuning in",     fix = "this is a newsletter, not a broadcast" },
  { pattern = "without further ado",      fix = "cut it — you were already going" },
  { pattern = "in today's post",          fix = "they know where they are" },
  { pattern = "in this article",          fix = "they know where they are" },
  { pattern = "i wanted to write about",  fix = "warm-up fluff. start at the story" },
  { pattern = "i've been thinking about", fix = "warm-up fluff. start at the story" },
}

--- Inflated words and the plain ones that mean the same thing.
Lexicon.inflated = {
  ["utilize"] = "use",
  ["utilizing"] = "using",
  ["utilise"] = "use",
  ["leverage"] = "use",
  ["leveraging"] = "using",
  ["in order to"] = "to",
  ["due to the fact that"] = "because",
  ["at this point in time"] = "now",
  ["in the event that"] = "if",
  ["for the purpose of"] = "to",
  ["with regard to"] = "about",
  ["in terms of"] = "in",
  ["a large number of"] = "many",
  ["the vast majority of"] = "most",
  ["it is important to note that"] = "cut it",
  ["needless to say"] = "cut it",
  ["basically"] = "cut it",
  ["essentially"] = "cut it",
  ["actually"] = "cut it",
  ["really"] = "cut it",
  ["very"] = "cut it — use a heavier word",
  ["quite"] = "cut it",
  ["somewhat"] = "cut it",
  ["arguably"] = "cut it",
  ["delve into"] = "dig into",
  ["myriad of"] = "many",
  ["plethora of"] = "plenty of",
  ["commence"] = "start",
  ["endeavour"] = "try",
  ["endeavor"] = "try",
  ["facilitate"] = "help",
  ["subsequently"] = "then",
  ["prior to"] = "before",
  ["additionally"] = "and",
  ["furthermore"] = "and",
  ["moreover"] = "and",
}

--- Past participles that a form of "to be" turns into passive voice. Irregular
--- ones only — the regular "-ed" case is handled by pattern in rules.lua.
Lexicon.irregularParticiples = {
  begun = true, broken = true, brought = true, built = true, bought = true,
  caught = true, chosen = true, done = true, driven = true, drawn = true,
  eaten = true, fallen = true, felt = true, forgotten = true, found = true,
  given = true, gone = true, grown = true, heard = true, held = true,
  hidden = true, kept = true, known = true, laid = true, led = true,
  left = true, lost = true, made = true, meant = true, met = true,
  paid = true, put = true, read = true, ridden = true, run = true,
  said = true, seen = true, sent = true, set = true, shown = true,
  sold = true, sought = true, spoken = true, spent = true, stolen = true,
  taken = true, taught = true, told = true, thrown = true, understood = true,
  won = true, worn = true, written = true,
}

Lexicon.beVerbs = {
  ["is"] = true, ["are"] = true, ["was"] = true, ["were"] = true,
  ["be"] = true, ["been"] = true, ["being"] = true, ["am"] = true,
  ["get"] = true, ["got"] = true, ["gets"] = true, ["getting"] = true,
}

--- Title shapes the playbook rules out.
Lexicon.titlePoetic = {
  "sifting through", "through the noise", "a meditation on", "reflections on",
  "musings on", "thoughts on", "the art of", "in praise of", "an ode to",
  "letters from", "notes from", "on being", "the beauty of", "chasing ",
}

Lexicon.titleAcademic = {
  "an analysis of", "a study of", "an examination of", "an exploration of",
  "an overview of", "an introduction to", "a review of", "towards a",
  "toward a", "a framework for", "understanding the", "the role of",
  "a case study", "considerations for", "perspectives on",
}

--- Words that make a title read as an outcome rather than a topic.
Lexicon.titleOutcome = {
  "how ", "why ", "what ", "get ", "got ", "grew ", "grow ", "build ",
  "built ", "make ", "made ", "stop ", "start ", "fix ", "learn ", "steal ",
  "everything ", "here's ", "i ", "you ", "your ", "days", "months", "weeks",
  "hours", "minutes", "subscribers", "in ",
}

return Lexicon
