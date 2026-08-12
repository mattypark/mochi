--- The floating sprite: draws it, bobs it, drags it, remembers where it sat.
---
--- Forked from cost/pet.lua rather than shared with it. Two pets that cannot
--- break each other is worth two hundred duplicated lines — and mochi's states
--- diverge anyway: it has a writing mode that cost has no concept of.
---
--- mochi is on screen whenever Hammerspoon is running. Writing mode gates what
--- it *reads*, never whether it exists. A pet that vanishes when it isn't
--- working is a pet you forget you own.

local Pet = {}
Pet.__index = Pet

local ASSET_DIR = hs.configdir .. "/mochi/assets"
local DEFAULT_WIDTH = 96
local BOB_PERIOD = 3.4     -- seconds per full bob cycle
local BOB_AMPLITUDE = 3    -- pixels
local BOB_FPS = 20
local DRAG_SLOP = 4        -- movement under this counts as a click, not a drag

-- Asleep is not hidden: the sprite stays put and dims, so "mochi is here but
-- not reading" is one glance rather than a menu bar trip.
local AWAKE_ALPHA = 1.0
local ASLEEP_ALPHA = 0.55

--- @param opts table {state=..., onClick=fn, onDragEnd=fn(x,y)}
function Pet.new(opts)
  local self = setmetatable({}, Pet)

  self.state = opts.state or {}
  self.onClick = opts.onClick
  self.onDragEnd = opts.onDragEnd
  self.awake = false

  local path = ASSET_DIR .. "/pet.png"
  local image = hs.image.imageFromPath(path)
  if not image then
    hs.alert.show("mochi: missing sprite at " .. path)
    return nil
  end

  local size = image:size()
  self.w = self.state.petWidth or DEFAULT_WIDTH
  self.h = math.floor(self.w * (size.h / size.w) + 0.5)

  local x, y = self:defaultPosition()
  self.baseX = self.state.x or x
  self.baseY = self.state.y or y

  self.canvas = hs.canvas.new({ x = self.baseX, y = self.baseY, w = self.w, h = self.h })
  self.canvas:level(hs.canvas.windowLevels.floating)
  -- canJoinAllSpaces so he follows between desktops; stationary so he doesn't
  -- slide around during a Space switch.
  self.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
                     | hs.canvas.windowBehaviors.stationary)
  self.canvas:clickActivating(false)
  self.canvas[1] = {
    type = "image",
    image = image,
    imageScaling = "scaleProportionally",
    imageAlignment = "center",
    frame = { x = 0, y = 0, w = self.w, h = self.h },
  }

  self:wireMouse()
  self:startBob()
  self.canvas:alpha(ASLEEP_ALPHA)

  if not self.state.hidden then self.canvas:show() end
  return self
end

--- Bottom-right on a fresh install, clear of where cost parks itself so the two
--- don't land on top of each other.
function Pet:defaultPosition()
  local frame = hs.screen.mainScreen():frame()
  return frame.x + frame.w - self.w - 32,
         frame.y + frame.h - self.h - 96
end

function Pet:frame()
  return { x = self.baseX, y = self.baseY, w = self.w, h = self.h }
end

--- Writing mode, expressed on the sprite itself.
function Pet:setAwake(awake)
  self.awake = awake and true or false
  if self.busyTimer then return end
  self.canvas:alpha(self.awake and AWAKE_ALPHA or ASLEEP_ALPHA)
end

function Pet:isAwake()
  return self.awake
end

function Pet:startBob()
  local t = 0
  self.bobTimer = hs.timer.doEvery(1 / BOB_FPS, function()
    if self.dragging or self.state.hidden then return end
    t = t + (1 / BOB_FPS)
    -- Asleep breathes at half depth rather than freezing: a motionless sprite
    -- reads as a crash.
    local depth = self.awake and BOB_AMPLITUDE or (BOB_AMPLITUDE / 2)
    local offset = math.sin((t / BOB_PERIOD) * 2 * math.pi) * depth
    self.canvas:topLeft({ x = self.baseX, y = self.baseY + offset })
  end)
end

function Pet:wireMouse()
  self.canvas:canvasMouseEvents(true, true, false, false)
  self.canvas:mouseCallback(function(_, event)
    if event == "mouseDown" then self:beginDrag() end
  end)
end

--- Click-and-hold drag.
--- Polls the mouse rather than using hs.eventtap, so this works with no
--- Accessibility permission granted — eventtap:start() fails outright without
--- it, and Hammerspoon is not granted Accessibility on this machine.
function Pet:beginDrag()
  local origin = hs.mouse.absolutePosition()
  local startX, startY = self.baseX, self.baseY
  local moved = 0
  self.dragging = true

  if self.dragTimer then self.dragTimer:stop() end

  self.dragTimer = hs.timer.doEvery(1 / 60, function()
    local buttons = hs.eventtap.checkMouseButtons()
    local held = buttons.left or buttons[1]

    if held then
      local now = hs.mouse.absolutePosition()
      local dx, dy = now.x - origin.x, now.y - origin.y
      moved = math.max(moved, math.abs(dx) + math.abs(dy))
      self.baseX, self.baseY = self:clamp(startX + dx, startY + dy)
      self.canvas:topLeft({ x = self.baseX, y = self.baseY })
      return
    end

    self:endDrag(moved)
  end)
end

function Pet:endDrag(moved)
  self.dragging = false
  if self.dragTimer then self.dragTimer:stop(); self.dragTimer = nil end

  if moved < DRAG_SLOP then
    if self.onClick then self.onClick() end
  else
    self.state.x, self.state.y = self.baseX, self.baseY
    if self.onDragEnd then self.onDragEnd(self.baseX, self.baseY) end
  end
end

--- Keep the sprite fully on whichever screen it was dropped nearest.
function Pet:clamp(x, y)
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local f = screen:frame()
  x = math.max(f.x, math.min(x, f.x + f.w - self.w))
  y = math.max(f.y, math.min(y, f.y + f.h - self.h))
  return x, y
end

function Pet:show()
  self.state.hidden = false
  self.canvas:show()
end

function Pet:hide()
  self.state.hidden = true
  self.canvas:hide()
end

function Pet:isHidden()
  return self.state.hidden and true or false
end

--- Quick hop, so a new critique is visible out of the corner of your eye.
function Pet:nudge()
  if self.state.hidden then return end

  local hops, i = { -10, 0, -6, 0, -2, 0 }, 0
  local timer
  timer = hs.timer.doEvery(0.07, function()
    i = i + 1
    if i > #hops then timer:stop(); return end
    self.canvas:topLeft({ x = self.baseX, y = self.baseY + hops[i] })
  end)
end

--- Slow pulse while the judgement tier is thinking, so a 10-second wait doesn't
--- read as a dead click.
function Pet:setBusy(busy)
  if self.busyTimer then self.busyTimer:stop(); self.busyTimer = nil end

  if not busy then
    self.canvas:alpha(self.awake and AWAKE_ALPHA or ASLEEP_ALPHA)
    return
  end

  local t = 0
  self.busyTimer = hs.timer.doEvery(1 / 20, function()
    t = t + (1 / 20)
    self.canvas:alpha(0.72 + 0.28 * ((math.sin(t * 3.2) + 1) / 2))
  end)
end

function Pet:delete()
  if self.bobTimer then self.bobTimer:stop() end
  if self.dragTimer then self.dragTimer:stop() end
  if self.busyTimer then self.busyTimer:stop() end
  if self.canvas then self.canvas:delete() end
end

return Pet
