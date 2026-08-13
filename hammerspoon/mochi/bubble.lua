--- A speech bubble beside the pet.
---
--- Forked from cost/bubble.lua and cut down: mochi's bubble never asks a
--- question, so there are no action buttons. What it keeps is the hard-won part
--- — the wrapping.
---
--- hs.drawing.getTextDrawingSize takes a *style* as its second argument, not a
--- width. There is nothing to constrain against, so it reports every block as a
--- single line and wrapped text gets clipped to one. The font is monospace, so
--- the honest fix is to wrap by character count, where the advance width is a
--- fixed fraction of the point size.

local Bubble = {}
Bubble.__index = Bubble

local W = 320
local PAD = 13
local GAP = 10          -- pet ↔ bubble
local RADIUS = 12
local SIZE = 12.5
local FONT = "Menlo"
local BOLD = "Menlo-Bold"

local INK = { white = 0.16, alpha = 1 }
local PAPER = { red = 0.98, green = 0.97, blue = 0.94, alpha = 0.98 }
local EDGE = { white = 0, alpha = 0.10 }
local DIM = { white = 0.16, alpha = 0.5 }

function Bubble.new()
  return setmetatable({ anchor = { x = 0, y = 0, w = 0, h = 0 } }, Bubble)
end

local function styled(text, color, size, bold)
  return hs.styledtext.new(text, {
    font = { name = bold and BOLD or FONT, size = size or SIZE },
    color = color,
    paragraphStyle = { lineBreak = "wordWrap", alignment = "left" },
  })
end

--- Bold the quoted fragments, and nothing else.
---
--- Every rule names the exact words it is complaining about, and it names them
--- in double quotes. Those are the only part of a critique worth scanning for —
--- the rest is the reason. Bolding them turns a paragraph of advice into
--- something readable at a glance while still typing.
---
--- Built by concatenating styled runs: hs.styledtext supports per-range
--- attributes, but composing runs is far easier to follow than computing byte
--- offsets into wrapped text.
local function emphasise(text, color, size)
  local result = nil

  local function append(chunk, bold)
    if chunk == "" then return end
    local piece = styled(chunk, color, size, bold)
    result = result and (result .. piece) or piece
  end

  local position = 1
  while true do
    local openQuote, closeQuote = text:find('"[^"]*"', position)
    if not openQuote then break end

    append(text:sub(position, openQuote - 1), false)
    append(text:sub(openQuote, closeQuote), true)
    position = closeQuote + 1
  end

  append(text:sub(position), false)
  return result or styled(text, color, size, false)
end

--- Wrap to a pixel width, returning the wrapped text and its line count.
local function wrap(text, width, size)
  size = size or SIZE
  local perLine = math.max(8, math.floor(width / (size * 0.6)))
  local lines = {}

  for paragraph in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      lines[#lines + 1] = ""
    else
      local line = ""
      for word in paragraph:gmatch("%S+") do
        if line == "" then
          line = word
        elseif #line + 1 + #word <= perLine then
          line = line .. " " .. word
        else
          lines[#lines + 1] = line
          line = word
        end

        while #line > perLine do
          lines[#lines + 1] = line:sub(1, perLine)
          line = line:sub(perLine + 1)
        end
      end
      if line ~= "" then lines[#lines + 1] = line end
    end
  end

  if #lines == 0 then lines[1] = "" end
  return table.concat(lines, "\n"), #lines
end

local function lineHeight(size)
  return math.ceil((size or SIZE) * 1.42)
end

function Bubble:setAnchor(frame)
  if frame then self.anchor = frame end
  if self.canvas then self:place() end
end

--- Above the pet, on whichever side has room, so it reads as coming from the pet
--- rather than sitting on top of it.
function Bubble:place()
  local screen = (hs.mouse.getCurrentScreen() or hs.screen.mainScreen()):frame()
  local pet = self.anchor

  local onLeft = (pet.x + pet.w / 2) > (screen.x + screen.w / 2)
  local x = onLeft and (pet.x - W + pet.w * 0.25) or (pet.x + pet.w * 0.75)
  local y = pet.y - (self.height or 60) - GAP

  if y < screen.y + 8 then y = pet.y + pet.h + GAP end

  x = math.max(screen.x + 8, math.min(x, screen.x + screen.w - W - 8))
  y = math.max(screen.y + 8, math.min(y, screen.y + screen.h - (self.height or 60) - 8))

  if self.canvas then self.canvas:frame({ x = x, y = y, w = W, h = self.height }) end
end

--- @param headline string   one line, never wrapped away
--- @param detail string|nil  the findings, one per line
--- @param footer string|nil  which engine produced this
function Bubble:show(headline, detail, footer)
  local innerW = W - PAD * 2

  -- The headline wraps to the narrower column it is actually drawn in, or a long
  -- one would be measured at one height and rendered at another.
  local headText, headLines = wrap(headline, innerW - 18)
  local bodyText, bodyLines = nil, 0
  if detail then bodyText, bodyLines = wrap(detail, innerW) end

  local height = PAD
    + headLines * lineHeight()
    + (detail and (6 + bodyLines * lineHeight()) or 0)
    + (footer and (6 + lineHeight(11)) or 0)
    + PAD

  self.height = height

  if not self.canvas then
    self.canvas = hs.canvas.new({ x = 0, y = 0, w = W, h = height })
    self.canvas:level(hs.canvas.windowLevels.floating)
    self.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
                       | hs.canvas.windowBehaviors.stationary)
    self.canvas:clickActivating(false)
    self.canvas:canvasMouseEvents(true, false, false, false)
    self.canvas:mouseCallback(function() self:hide() end)
  end

  self.canvas:replaceElements({
    type = "rectangle",
    action = "fill",
    fillColor = PAPER,
    roundedRectRadii = { xRadius = RADIUS, yRadius = RADIUS },
    frame = { x = 0, y = 0, w = W, h = height },
  }, {
    -- Top left, where nothing else ever sits. The whole bubble dismisses on
    -- click too, but a bubble covering the sentence you are trying to read needs
    -- an obvious way out, not a discovered one.
    type = "text",
    text = styled("✕", DIM, 12),
    frame = { x = PAD - 4, y = PAD - 5, w = 16, h = 18 },
  }, {
    type = "rectangle",
    action = "stroke",
    strokeColor = EDGE,
    strokeWidth = 1,
    roundedRectRadii = { xRadius = RADIUS, yRadius = RADIUS },
    frame = { x = 0.5, y = 0.5, w = W - 1, h = height - 1 },
  }, {
    type = "text",
    text = styled(headText, INK, SIZE, true),
    -- Indented past the ✕ so the first line never collides with it.
    frame = { x = PAD + 18, y = PAD, w = innerW - 18, h = headLines * lineHeight() },
  })

  local y = PAD + headLines * lineHeight()

  if detail then
    y = y + 6
    self.canvas:appendElements({
      type = "text",
      text = emphasise(bodyText, INK),
      frame = { x = PAD, y = y, w = innerW, h = bodyLines * lineHeight() },
    })
    y = y + bodyLines * lineHeight()
  end

  if footer then
    y = y + 6
    self.canvas:appendElements({
      type = "text",
      -- Which engine spoke is never optional. Silent degradation from the
      -- judgement tier to the rules would otherwise look like a working feature.
      text = styled(footer, DIM, 11),
      frame = { x = PAD, y = y, w = innerW, h = lineHeight(11) },
    })
  end

  self:place()
  self.canvas:show()
end

function Bubble:hide()
  if self.canvas then self.canvas:hide() end
end

function Bubble:isVisible()
  return self.canvas ~= nil and self.canvas:isShowing()
end

function Bubble:delete()
  if self.canvas then self.canvas:delete(); self.canvas = nil end
end

return Bubble
