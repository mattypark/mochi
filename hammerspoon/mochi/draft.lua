--- Draft history, so the 10% rule has something real to measure against.
---
--- "The second draft is the first draft minus 10%" is the one playbook rule that
--- cannot be checked by looking at the text in front of you. It needs to know
--- what the text used to be.
---
--- What counts as a draft, concretely: **one writing-mode session**. Turning
--- writing mode on starts a draft; turning it off ends it. That is a decision
--- rather than a discovery — there is no natural boundary in a stream of
--- keystrokes — but it is the one boundary the writer controls deliberately,
--- which makes it the only one that can mean anything to them.
---
--- The comparison is against the *last completed* session, never the current
--- one. Comparing a draft to itself would report 0% forever.
---
--- Everything here except load/save is pure, so the decisions are testable
--- outside Hammerspoon. The I/O is the thin part on purpose.

local Draft = {}

local DIR = os.getenv("HOME") .. "/.hammerspoon/mochi/drafts"
local MAX_SESSIONS = 40    -- plenty of history; keeps a file from growing forever
local MIN_WORDS = 120      -- below this a "session" is a false start, not a draft

-- ----------------------------------------------------------------------- keys

--- A filename-safe key for a post, derived from its URL.
---
--- Substack's editor URL carries the post id (…/publish/post/12345), which is
--- stable across renames — the title is not, and keying on it would start a new
--- history every time a headline changed.
function Draft.key(url)
  if type(url) ~= "string" or url == "" then return "unknown" end

  local id = url:match("/publish/post/(%d+)")
  if id then return "post-" .. id end

  local slug = url:gsub("^https?://", ""):gsub("[^%w%-]", "-"):gsub("%-+", "-")
  slug = slug:sub(1, 60):gsub("^%-", ""):gsub("%-$", "")
  return slug ~= "" and slug or "unknown"
end

-- ------------------------------------------------------------------- sessions

local function emptyHistory(url)
  return { url = url, sessions = {} }
end

--- Start a new session. Called when writing mode goes on.
function Draft.begin(history, url, now)
  history = history or emptyHistory(url)
  history.url = url or history.url

  history.current = {
    started = now,
    words = 0,
    peak = 0,
    title = nil,
  }

  return history
end

--- Fold a snapshot into the open session.
function Draft.record(history, snapshot, now)
  if not history or not history.current then return history end

  local words = snapshot.words or 0
  history.current.words = words
  history.current.peak = math.max(history.current.peak or 0, words)
  history.current.title = snapshot.title
  history.current.touched = now

  return history
end

--- Close the open session and file it, if it amounted to anything.
---
--- A session under MIN_WORDS is dropped rather than recorded: opening the editor
--- to fix a typo would otherwise become "draft 4", and the next real draft would
--- be measured against 12 words and told it grew by 4000%.
function Draft.finish(history, now)
  if not history or not history.current then return history end

  local session = history.current
  history.current = nil

  if (session.peak or 0) < MIN_WORDS then return history end

  session.ended = now
  history.sessions[#history.sessions + 1] = session

  while #history.sessions > MAX_SESSIONS do
    table.remove(history.sessions, 1)
  end

  return history
end

--- The word count the current draft should be measured against: the final size
--- of the last completed session.
function Draft.previousWords(history)
  if not history then return nil end

  local last = history.sessions[#history.sessions]
  if not last then return nil end

  -- The final count, not the peak. The rule is about what the draft ended up
  -- as, and a session that wrote 2000 words then cut to 1500 finished at 1500.
  local words = last.words or 0
  return words > 0 and words or nil
end

--- Which draft this is, counting from one. Only used for wording.
function Draft.number(history)
  if not history then return 1 end
  return #history.sessions + 1
end

-- ------------------------------------------------------------------------ I/O

local function path(key)
  return DIR .. "/" .. key .. ".json"
end

function Draft.load(key)
  local file = io.open(path(key), "r")
  if not file then return nil end

  local raw = file:read("*a")
  file:close()

  local ok, decoded = pcall(hs.json.decode, raw)
  if not ok or type(decoded) ~= "table" then return nil end

  decoded.sessions = type(decoded.sessions) == "table" and decoded.sessions or {}
  -- A session left open by a crash is not resumable: its end is unknown, so it
  -- can never be compared against honestly.
  decoded.current = nil

  return decoded
end

function Draft.save(key, history)
  if not history then return false end

  hs.fs.mkdir(DIR)

  local file = io.open(path(key), "w")
  if not file then return false end

  file:write(hs.json.encode(history, true))
  file:close()
  return true
end

Draft.MIN_WORDS = MIN_WORDS

return Draft
