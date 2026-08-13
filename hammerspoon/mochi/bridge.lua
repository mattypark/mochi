--- The bridge: drafts arrive here from the browser extension.
---
--- A WebSocket on 127.0.0.1 rather than anything cleverer. The extension is the
--- only client, both ends are on this machine, and a socket the OS refuses to
--- route off-box is the strongest privacy claim available — stronger than a
--- promise made in a callback.
---
--- Writing mode STOPS THE SERVER rather than ignoring messages. "mochi is not
--- reading" is then verifiable from outside the program: the port is closed and
--- the extension's connection drops. A flag checked at the top of a handler is
--- a claim; a closed socket is a fact.

local Bridge = {}

local PORT = 27852       -- arbitrary, high, and not in the ephemeral range
local PATH = "/mochi"

local server
local onDraft, onStatus, handlersLost

-- ------------------------------------------------------------------ decoding

--- Everything arriving here is untrusted input from a browser tab. It is shaped
--- by our own extension today, but the port is open to anything on this machine
--- that can speak WebSocket, so every field is checked before it reaches the
--- rules.
local function decode(message)
  if type(message) ~= "string" or message == "" then return nil, "empty" end
  if #message > 1024 * 512 then return nil, "oversized" end

  local ok, raw = pcall(hs.json.decode, message)
  if not ok or type(raw) ~= "table" then return nil, "not JSON" end

  -- The extension says so explicitly when it cannot find the editor, rather than
  -- sending an empty draft. Those two states look identical downstream and mean
  -- opposite things: one is a blank page, the other is a broken selector.
  if raw.kind == "lost" then return nil, "lost" end

  if raw.kind ~= "draft" then return nil, "unknown kind" end

  local blocks = {}
  if type(raw.blocks) == "table" then
    for _, block in ipairs(raw.blocks) do
      if type(block) == "table" and type(block.text) == "string" then
        blocks[#blocks + 1] = {
          tag = type(block.tag) == "string" and block.tag or "p",
          text = block.text,
        }
      end
    end
  end

  return {
    title = type(raw.title) == "string" and raw.title or "",
    subtitle = type(raw.subtitle) == "string" and raw.subtitle or "",
    blocks = blocks,
    body = type(raw.body) == "string" and raw.body or "",
    words = type(raw.words) == "number" and math.floor(raw.words) or 0,
    caret = type(raw.caret) == "number" and raw.caret or nil,
    url = type(raw.url) == "string" and raw.url or nil,
    at = os.time(),
  }
end

-- -------------------------------------------------------------------- server

--- @param handlers table { onDraft = fn(draft), onStatus = fn(connected), onLost = fn() }
function Bridge.configure(handlers)
  onDraft = handlers.onDraft
  onStatus = handlers.onStatus
  handlersLost = handlers.onLost
end

function Bridge.start()
  if server then return true end

  server = hs.httpserver.new(false, false)
  if not server then return false, "could not create the server" end

  server:setPort(PORT)
  server:setInterface("localhost")

  server:websocket(PATH, function(message)
    -- A first message from a new connection is also the "connected" signal:
    -- hs.httpserver has no open/close callback to hang that off.
    if onStatus then onStatus(true) end

    local draft, err = decode(message)

    if err == "lost" then
      if handlersLost then handlersLost() end
      return hs.json.encode({ ok = true, lost = true })
    end

    if not draft then
      -- Reply rather than drop it. A malformed frame is a bug in the extension,
      -- and a silent drop is how that bug survives.
      return hs.json.encode({ ok = false, error = err })
    end

    if onDraft then onDraft(draft) end
    return hs.json.encode({ ok = true, words = draft.words })
  end)

  -- Only the websocket path is served; there is no document root, so an
  -- ordinary GET gets nothing useful.
  server:setCallback(function()
    return "mochi", 404, {}
  end)

  server:start()
  return true
end

function Bridge.stop()
  if not server then return end
  server:stop()
  server = nil
  if onStatus then onStatus(false) end
end

function Bridge.isRunning()
  return server ~= nil
end

function Bridge.url()
  return string.format("ws://127.0.0.1:%d%s", PORT, PATH)
end

return Bridge
