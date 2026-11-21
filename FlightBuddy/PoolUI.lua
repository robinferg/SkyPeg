-- Flight Buddy :: PoolUI.lua
-- Tavern Pool: the screen. The table stands the long way up; you shoot from the bottom.
--   Aim: point at where the cue ball should go (the mouse wheel nudges the aim a hair).
--   Shoot: press, draw the pointer back for power, let go. A short pull is a soft shot.
--   Ball in hand: the cue ball follows the pointer; click to set it down.
-- The engine (Pool.lua) owns the balls and the rules; this draws them and plays the opponent's
-- turns at a human pace.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Pool = NS.Pool
local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local UI = {}
NS.PoolUI = UI

local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local BX, BY = 24, 10                       -- field offset inside the 480x560 holder
local FW, FH = 432, 530
local TW, TH, R = Pool.TW, Pool.TH, Pool.R
local OX, OY = (FW - TW) / 2, (FH - TH) / 2 -- the cloth's top left corner inside the field
local RAIL = 20
local PULL = 130                            -- pixels of pull for full power
local TINT = { 0.35, 0.85, 0.55 }
local FELT = { 0.06, 0.34, 0.22 }

local function Today() return NS.Social.Today() end
local function Foe(i) return Pool.FOES[i or 1] end

function UI:Init(db)
    self.db = db
    db.foes = db.foes or {}               -- [key] = { w =, l = }
    db.frames = db.frames or 0
    db.bestSolo = db.bestSolo or 0        -- fewest shots to clear a full rack (0 = never)
    db.daily = db.daily or {}
    db.dailies = db.dailies or 0
end

function UI:Daily()
    local d = self.db.daily
    if d.date ~= Today() then d.date, d.best, d.tries, d.run = Today(), 0, 0, nil end
    return d
end

function UI:DailyPending() return (self:Daily().best or 0) == 0 end

function UI:Record(i)
    local k = Foe(i).key
    self.db.foes[k] = self.db.foes[k] or { w = 0, l = 0 }
    return self.db.foes[k]
end

---------------------------------------------------------------------------
-- A ball, drawn from plain discs: solids are a full colour with a pale spot, stripes are white
-- with a band of colour round the middle, the eight is black, the cue ball white
---------------------------------------------------------------------------
local function NewBall(parent, size, layer, sub)
    local b = { size = size }
    b.shadow = parent:CreateTexture(nil, layer, nil, sub)
    b.shadow:SetTexture(W.MEDIA .. "circle"); b.shadow:SetVertexColor(0, 0, 0, 0.35)
    b.base = parent:CreateTexture(nil, layer, nil, sub + 1)
    b.base:SetTexture(W.MEDIA .. "circle")
    b.mid = parent:CreateTexture(nil, layer, nil, sub + 2)
    b.mid:SetTexture(W.MEDIA .. "circle")
    b.shine = parent:CreateTexture(nil, layer, nil, sub + 3)
    b.shine:SetTexture(W.MEDIA .. "circle"); b.shine:SetVertexColor(1, 1, 1, 0.55)
    b.all = { b.shadow, b.base, b.mid, b.shine }
    function b:Set(id)
        if self.id == id then return end
        self.id = id
        local c = Pool.Color(id)
        local kind = Pool.Kind(id)
        if kind == "stripe" then
            self.base:SetVertexColor(0.96, 0.95, 0.90)
            self.mid:SetVertexColor(c[1], c[2], c[3])
            self.midK = 0.66
        elseif kind == "cue" then
            self.base:SetVertexColor(c[1], c[2], c[3])
            self.mid:SetVertexColor(1, 1, 1)
            self.midK = 0.5
        else
            self.base:SetVertexColor(c[1], c[2], c[3])
            self.mid:SetVertexColor(0.96, 0.95, 0.90)
            self.midK = 0.36
        end
    end
    function b:Put(anchor, x, y, scale, alpha)
        local s = self.size * (scale or 1)
        for _, t in ipairs(self.all) do t:ClearAllPoints(); t:SetAlpha(alpha or 1); t:Show() end
        self.shadow:SetPoint("CENTER", anchor, "TOPLEFT", x + 1.5, -(y + 2)); self.shadow:SetSize(s, s); self.shadow:SetAlpha(0.35 * (alpha or 1))
        self.base:SetPoint("CENTER", anchor, "TOPLEFT", x, -y); self.base:SetSize(s, s)
        self.mid:SetPoint("CENTER", anchor, "TOPLEFT", x, -y); self.mid:SetSize(s * self.midK, s * self.midK)
        self.shine:SetPoint("CENTER", anchor, "TOPLEFT", x - s * 0.2, -(y - s * 0.22)); self.shine:SetSize(s * 0.2, s * 0.2); self.shine:SetAlpha(0.55 * (alpha or 1))
    end
    function b:Hide() for _, t in ipairs(self.all) do t:Hide() end end
    return b
end

-- a straight line between two points, from a stretched pill
local function Line(t, anchor, ax, ay, bx, by, thick)
    local len = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    if len < 0.5 then t:Hide(); return end
    t:ClearAllPoints()
    t:SetPoint("CENTER", anchor, "TOPLEFT", (ax + bx) / 2, -(ay + by) / 2)
    t:SetSize(len, thick)
    if t.SetRotation then t:SetRotation(-atan2(by - ay, bx - ax)) end
    t:Show()
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetAllPoints(parent)
    f:Hide()

    local hud = CreateFrame("Frame", nil, f)
    hud:SetPoint("TOPLEFT", 20, -38); hud:SetPoint("TOPRIGHT", -20, -38); hud:SetHeight(66)
    self.modeText = W.Text(hud, 11, W.FONT)
    self.modeText:SetPoint("TOPLEFT", 2, -8)
    self.modeText:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.nameText = W.Text(hud, 14, W.FONT_TITLE)
    self.nameText:SetPoint("TOPLEFT", self.modeText, "BOTTOMLEFT", 0, -4)
    self.nameText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.scoreText = W.Text(hud, 30, FONT_SHOUT, "OUTLINE")
    self.scoreText:SetPoint("TOP", 0, -10)
    self.scoreText:SetTextColor(1, 0.9, 0.6)
    self.rightLabel = W.Text(hud, 11, W.FONT)
    self.rightLabel:SetPoint("TOPRIGHT", -2, -8)
    self.rightLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.rightValue = W.Text(hud, 24, FONT_SHOUT, "OUTLINE")
    self.rightValue:SetPoint("TOPRIGHT", self.rightLabel, "BOTTOMRIGHT", 0, -2)

    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(480, 560)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    self.holder = holder
    local frame = CreateFrame("Frame", nil, holder)
    frame:SetSize(FW + 20, FH + 16)
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", BX - 10, -BY + 8)
    W.Nine(frame, "wood", 16, "BACKGROUND", -6)

    local board = CreateFrame("Frame", nil, holder)
    board:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    board:SetSize(FW, FH)
    board:SetFrameLevel(holder:GetFrameLevel() + 2)
    self.board = board
    local room = W.Solid(board, "BACKGROUND", 0.07, 0.05, 0.045, 1, 0)
    room:SetAllPoints()
    local lamp = board:CreateTexture(nil, "BACKGROUND", nil, 1)
    lamp:SetTexture(W.MEDIA .. "glow"); lamp:SetBlendMode("ADD"); lamp:SetVertexColor(1, 0.75, 0.4, 0.16)
    lamp:SetPoint("CENTER"); lamp:SetSize(FW * 1.6, FH * 1.3)
    -- rails, cloth, pockets
    local rail = W.Solid(board, "BACKGROUND", 0.33, 0.18, 0.08, 1, 2)
    rail:SetPoint("TOPLEFT", board, "TOPLEFT", OX - RAIL, -(OY - RAIL)); rail:SetSize(TW + 2 * RAIL, TH + 2 * RAIL)
    local lip = W.Solid(board, "BACKGROUND", 0.20, 0.10, 0.04, 1, 3)
    lip:SetPoint("TOPLEFT", board, "TOPLEFT", OX - 5, -(OY - 5)); lip:SetSize(TW + 10, TH + 10)
    local cushion = W.Solid(board, "BACKGROUND", FELT[1] * 0.72, FELT[2] * 0.72, FELT[3] * 0.72, 1, 4)
    cushion:SetPoint("TOPLEFT", board, "TOPLEFT", OX - 3, -(OY - 3)); cushion:SetSize(TW + 6, TH + 6)
    local cloth = W.Solid(board, "BACKGROUND", FELT[1], FELT[2], FELT[3], 1, 5)
    cloth:SetPoint("TOPLEFT", board, "TOPLEFT", OX, -OY); cloth:SetSize(TW, TH)
    local sheen = board:CreateTexture(nil, "BACKGROUND", nil, 6)
    sheen:SetTexture(W.MEDIA .. "glow"); sheen:SetBlendMode("ADD"); sheen:SetVertexColor(0.5, 1, 0.7, 0.10)
    sheen:SetPoint("CENTER", board, "TOPLEFT", OX + TW / 2, -(OY + TH / 2)); sheen:SetSize(TW * 1.5, TH * 1.1)
    for i = 0, 8 do
        if i ~= 4 then
            for _, sx in ipairs({ OX - RAIL / 2 - 2, OX + TW + RAIL / 2 + 2 }) do
                local dmd = board:CreateTexture(nil, "BORDER")
                dmd:SetTexture(W.MEDIA .. "circle"); dmd:SetVertexColor(0.95, 0.85, 0.6, 0.8); dmd:SetSize(4, 4)
                dmd:SetPoint("CENTER", board, "TOPLEFT", sx, -(OY + TH * i / 8))
            end
        end
    end
    for _, p in ipairs(Pool.POCKETS) do
        local t = board:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(W.MEDIA .. "circle"); t:SetVertexColor(0.02, 0.02, 0.02)
        t:SetSize(27, 27)
        t:SetPoint("CENTER", board, "TOPLEFT", OX + p.x, -(OY + p.y))
    end

    -- the balls, the sight line, the cue
    self.sprites = {}
    for i = 1, 16 do self.sprites[i] = NewBall(board, 2 * R, "ARTWORK", -4) end
    local function pill(layer, sub)
        local t = board:CreateTexture(nil, layer or "ARTWORK", nil, sub or 2)
        t:SetTexture(W.MEDIA .. "pill")
        t:Hide()
        return t
    end
    self.sight, self.objLine, self.cueLine = pill(), pill(), pill()
    self.ghost = board:CreateTexture(nil, "ARTWORK", nil, 3)
    self.ghost:SetTexture(W.MEDIA .. "ring"); self.ghost:SetSize(2 * R * 2.45, 2 * R * 2.45); self.ghost:Hide()      -- (the ring fills about two fifths of its texture)
    self.stick, self.stickTip = pill("OVERLAY", 1), pill("OVERLAY", 2)
    self.stick:SetVertexColor(0.80, 0.62, 0.36)
    self.stickTip:SetVertexColor(0.92, 0.92, 0.95)
    -- power
    self.powerBg = W.Solid(board, "ARTWORK", 0, 0, 0, 0.55)
    self.powerBg:SetSize(12, 150)
    self.powerBg:SetPoint("BOTTOM", board, "BOTTOMRIGHT", -36, 34)
    self.powerFill = W.Solid(board, "OVERLAY", 1, 0.8, 0.2, 1)
    self.powerFill:SetPoint("BOTTOM", self.powerBg, "BOTTOM", 0, 0)
    self.powerFill:SetWidth(8)
    self.powerText = W.Text(board, 10, W.FONT)
    self.powerText:SetPoint("TOP", self.powerBg, "BOTTOM", 0, -4)
    self.powerText:SetTextColor(0.8, 0.8, 0.85)
    self.powerText:SetText("POWER")

    -- either side of the table: who is on which balls, and what each still has to pot
    self.cols = {}
    for side = 1, 2 do
        local c = {}
        local cx = side == 1 and 37 or FW - 37
        c.name = W.Text(board, 11, W.FONT_TITLE)
        c.name:SetPoint("TOP", board, "TOPLEFT", cx, -14)
        c.name:SetWidth(70)
        c.sub = W.Text(board, 10, W.FONT)
        c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -3)
        c.sub:SetWidth(70)
        c.sub:SetTextColor(0.75, 0.78, 0.9)
        c.turn = board:CreateTexture(nil, "BACKGROUND", nil, 2)
        c.turn:SetTexture(W.MEDIA .. "glow"); c.turn:SetBlendMode("ADD"); c.turn:SetVertexColor(1, 0.82, 0.38)
        c.turn:SetPoint("CENTER", board, "TOPLEFT", cx, -40); c.turn:SetSize(120, 110)
        c.minis = {}
        for i = 1, 15 do c.minis[i] = NewBall(board, 14, "ARTWORK", -4) end
        c.x = cx
        c.big = W.Text(board, 30, FONT_SHOUT, "OUTLINE")
        c.big:SetPoint("TOP", board, "TOPLEFT", cx, -62)
        self.cols[side] = c
    end
    self.banner = W.Text(board, 15, W.FONT_TITLE, "OUTLINE")
    self.banner:SetPoint("CENTER", board, "TOPLEFT", OX + TW / 2, -(OY + TH * 0.52))
    self.banner:SetWidth(TW - 20)
    self.banner:Hide()
    self.bannerT = 0

    local fx = CreateFrame("Frame", nil, holder)
    fx:SetAllPoints(board)
    fx:SetFrameLevel(board:GetFrameLevel() + 6)
    fx:EnableMouse(false)
    self.fx = fx
    self.parts = {}
    for i = 1, 60 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(W.MEDIA .. "sparkle"); t:SetBlendMode("ADD"); t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0

    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function(_, button) W.Guard("Pool", self.MouseDown, self, button) end)
    board:SetScript("OnMouseUp", function(_, button) W.Guard("Pool", self.MouseUp, self, button) end)
    if board.EnableMouseWheel then
        board:EnableMouseWheel(true)
        board:SetScript("OnMouseWheel", function(_, delta) W.Guard("Pool", self.Wheel, self, delta) end)
    end

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10); bar:SetPoint("BOTTOMRIGHT", -20, 10); bar:SetHeight(30)
    bar:SetFrameLevel(f:GetFrameLevel() + 4)
    local menu = W.Button(bar, 70, 26, "Menu", "ghost")
    menu:SetPoint("LEFT", 0, 0)
    menu:SetScript("OnClick", function() self:ShowMenu() end)
    local help = W.Button(bar, 60, 26, "Help", "ghost")
    help:SetPoint("RIGHT", 0, 0)
    help:SetScript("OnClick", function() self:ShowHelp() end)
    local scores = W.Button(bar, 70, 26, "Scores", "ghost")
    scores:SetPoint("RIGHT", help, "LEFT", -6, 0)
    scores:SetScript("OnClick", function() self:ShowBoard() end)
    self.restartButton = W.Button(bar, 80, 26, "Restart", "ghost")
    self.restartButton:SetPoint("LEFT", menu, "RIGHT", 6, 0)
    self.restartButton:SetScript("OnClick", function() self:Restart() end)

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.boardPanel = NS.NewBoardPanel(f, holder)

    self.game = Pool.New()
    self.angle, self.power = pi / 2, 0
    f:SetScript("OnUpdate", function(_, el) W.Guard("Pool", self.OnUpdate, self, el) end)
    local run = self.db.run
    if run and (run.mode ~= "daily" or run.day == Today()) and self.game:Restore(run) then
        if self.game.phase == "over" then self.finishPending = true end
        self.placing = self.game.phase == "aim" and self.game.inHand and self.game.turn == "you"
    else
        self.db.run = nil
        self.game = Pool.New()
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function UI:Burst(x, y, col, n)
    if NS.db.settings.reducedMotion then n = floor(n / 3) end
    for _ = 1, n do
        self.partIdx = self.partIdx % #self.parts + 1
        local p = self.parts[self.partIdx]
        local a = math.random() * 2 * pi
        local v = 40 + math.random() * 110
        p.x, p.y, p.vx, p.vy = x, y, cos(a) * v, sin(a) * v
        p.life = 0.3 + math.random() * 0.3
        p.max = p.life
        p.size = 6 + math.random() * 8
        p.t:SetVertexColor(col[1], col[2], col[3])
        p.t:Show()
    end
end

function UI:Say(text, col, secs)
    col = col or COLORS.gold
    self.banner:SetText(text)
    self.banner:SetTextColor(col[1], col[2], col[3])
    self.banner:Show()
    self.bannerT = secs or 2.2
end

function UI:DrawBalls()
    local g = self.game
    for i, s in ipairs(self.sprites) do
        local b = g.balls[i]
        if b and b.on then
            s:Set(b.id)
            s:Put(self.board, OX + b.x, OY + b.y)
        else
            s:Hide()
        end
    end
end

-- the sight line, the ghost ball and the cue for a shot along `angle` with `pull` (0..1) on it
function UI:DrawAim(angle, pull, mine)
    local g = self.game
    local c = g:Cue()
    local s = g:Sight(angle)
    local dx, dy = cos(angle), -sin(angle)
    local x0, y0 = OX + c.x, OY + c.y
    local gx, gy = OX + s.x, OY + s.y
    if mine then
        local legal = not s.ball or g:Legal(s.ball, "you")
        Line(self.sight, self.board, x0 + dx * (R + 2), y0 + dy * (R + 2), gx, gy, 1.5)
        self.sight:SetVertexColor(1, 1, 1, 0.55)
        self.ghost:ClearAllPoints()
        self.ghost:SetPoint("CENTER", self.board, "TOPLEFT", gx, -gy)
        if legal then self.ghost:SetVertexColor(1, 1, 1, 0.8) else self.ghost:SetVertexColor(1, 0.3, 0.25, 0.9) end
        self.ghost:Show()
        if s.ball then
            -- which way the struck ball sets off (longer the fuller the hit), and the cue ball after it
            local b = g:Get(s.ball)
            local col = Pool.Color(s.ball)
            local len = 18 + 44 * (s.full or 1)
            Line(self.objLine, self.board, OX + b.x + s.ox * R, OY + b.y + s.oy * R, OX + b.x + s.ox * (R + len), OY + b.y + s.oy * (R + len), 2)
            self.objLine:SetVertexColor(min(1, col[1] + 0.25), min(1, col[2] + 0.25), min(1, col[3] + 0.25), legal and 0.9 or 0.35)
            local cl = 26 * (1 - (s.full or 1)) + 4
            Line(self.cueLine, self.board, gx + s.cx * R, gy + s.cy * R, gx + s.cx * (R + cl), gy + s.cy * (R + cl), 1.5)
            self.cueLine:SetVertexColor(1, 1, 1, 0.4)
        else
            self.objLine:Hide(); self.cueLine:Hide()
        end
    else
        self.sight:Hide(); self.ghost:Hide(); self.objLine:Hide(); self.cueLine:Hide()
    end
    -- the cue, drawn back by the pull
    local back = R + 5 + pull * 46
    Line(self.stick, self.board, x0 - dx * (back + 8), y0 - dy * (back + 8), x0 - dx * (back + 170), y0 - dy * (back + 170), 4)
    Line(self.stickTip, self.board, x0 - dx * back, y0 - dy * back, x0 - dx * (back + 9), y0 - dy * (back + 9), 3)
end

function UI:HideAim()
    self.sight:Hide(); self.ghost:Hide(); self.objLine:Hide(); self.cueLine:Hide(); self.stick:Hide(); self.stickTip:Hide()
end

function UI:UpdateFX(el)
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then p.t:Hide()
            else
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local k = p.life / p.max
                p.t:ClearAllPoints()
                p.t:SetPoint("CENTER", self.board, "TOPLEFT", p.x, -p.y)
                p.t:SetSize(p.size * (0.5 + k), p.size * (0.5 + k))
                p.t:SetAlpha(k)
            end
        end
    end
    if self.bannerT > 0 then
        self.bannerT = self.bannerT - el
        self.banner:SetAlpha(min(1, self.bannerT * 2))
        if self.bannerT <= 0 then self.banner:Hide() end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function UI:IsBusy() return self.game.phase == "roll" end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.boardPanel:IsShown()
end

-- the pointer in table units
function UI:Cursor()
    local x, y = GetCursorPosition()
    local s = self.board:GetEffectiveScale()
    local l, t = self.board:GetLeft(), self.board:GetTop()
    if not (l and t) then return end
    return x / s - l - OX, t - y / s - OY
end

function UI:MyShot()
    local g = self.game
    return g.phase == "aim" and g.turn == "you" and not self:Paused()
end

function UI:MouseDown(button)
    if not self:MyShot() then return end
    if button == "RightButton" then self.drag = nil; self.power = 0; return end
    if button ~= "LeftButton" or self.placing then return end
    local mx, my = self:Cursor()
    if not mx then return end
    self.drag = { x = mx, y = my }
    self.power = 0
end

function UI:MouseUp(button)
    if button ~= "LeftButton" then return end
    if not self:MyShot() then self.drag = nil; return end
    if self.placing then
        -- set the cue ball down where it is
        self.placing = false
        self.lock = nil
        W.SFX("knock", 0.05)
        self:Save()
        return
    end
    local d = self.drag
    self.drag = nil
    if not d then return end
    if self.power >= 0.04 then
        self:Shoot(self.angle, self.power)
    end
    self.power = 0
end

-- the wheel turns the aim a hair at a time, and holds it until the pointer moves away
function UI:Wheel(delta)
    if not self:MyShot() or self.placing then return end
    self.angle = self.angle + (delta > 0 and 1 or -1) * ((IsShiftKeyDown and IsShiftKeyDown()) and 0.0008 or 0.004)
    local mx, my = self:Cursor()
    self.lock = { x = mx or 0, y = my or 0 }
end

function UI:OnKey(key) return false end

function UI:UpdateMine()
    local g = self.game
    local c = g:Cue()
    local mx, my = self:Cursor()
    local over = mx and self.board:IsMouseOver()
    if self.placing then
        if over then g:PlaceCue(mx, my) end
        self:HideAim()
        return
    end
    if self.drag then
        if mx then
            -- how far the pointer has been drawn from where it was pressed, whichever way
            local pull = sqrt((mx - self.drag.x) ^ 2 + (my - self.drag.y) ^ 2)
            self.power = max(0, min(1, pull / PULL))
        end
    elseif over then
        if self.lock and (abs(mx - self.lock.x) > 8 or abs(my - self.lock.y) > 8) then self.lock = nil end
        if not self.lock and (mx - c.x) ^ 2 + (my - c.y) ^ 2 > 36 then
            self.angle = atan2(-(my - c.y), mx - c.x)
        end
    end
    self:DrawAim(self.angle, self.drag and self.power or 0, true)
end

function UI:Shoot(angle, power)
    local g = self.game
    if not g:Shoot(angle, power) then return end
    -- saved with the shot on it, so a window closed while the balls roll loses nothing
    self:Save()
    self:HideAim()
    W.SFX("putt", 0.05)
    self.lock = nil
end

function UI:Save()
    local g = self.game
    local snap = g:Serialize()
    if g.mode == "daily" then
        local d = self:Daily()
        if g.day == d.date then d.run = snap end
        self.db.run = snap
    else
        self.db.run = snap
    end
end

---------------------------------------------------------------------------
-- The opponent's turn, at a human pace
---------------------------------------------------------------------------
function UI:UpdateFoe(el)
    local g = self.game
    local ai = self.ai
    if not ai then
        ai = { stage = "wait", t = 0.7 }
        self.ai = ai
    end
    ai.t = ai.t - el
    if ai.stage == "wait" then
        self:HideAim()
        if ai.t <= 0 then
            ai.plan = g:Think()
            if ai.plan.place then g:PlaceCue(ai.plan.place.x, ai.plan.place.y) end
            ai.stage, ai.t = "aim", 1.0
        end
    elseif ai.stage == "aim" then
        local k = 1 - max(0, ai.t) / 1.0
        self:DrawAim(ai.plan.angle, ai.plan.power * min(1, k * 1.4), false)
        if ai.t <= 0 then
            self.ai = nil
            self:Shoot(ai.plan.angle, ai.plan.power)
        end
    end
end

---------------------------------------------------------------------------
-- After the balls stop
---------------------------------------------------------------------------
local FOULS = { scratch = "Scratch!", nothing = "No ball struck", wrong = "Wrong ball first", eight = "The eight first" }

function UI:AfterShot(res)
    local g = self.game
    self.ai = nil
    self:Save()
    if g.phase == "over" then
        self:ShowResult()
        return
    end
    local you = res.who == "you"
    local name = g.mode == "match" and Foe(g.foe).name or nil
    if g.mode ~= "match" then
        if res.foul then self:Say(FOULS[res.foul] .. "  (+1 shot)", COLORS.red); W.SFX("lose", 0.3) end
    else
        if res.foul then
            self:Say(("%s\nBall in hand for %s"):format(FOULS[res.foul], you and name or "you"), COLORS.red, 2.6)
            W.SFX("lose", 0.3)
        elseif res.assigned then
            local mine = g.group.you
            self:Say(("You are on %s"):format(mine == "solid" and "solids" or "stripes"), COLORS.gold, 2.6)
            W.SFX("multiplier", 0.3)
        elseif res.passed then
            self:Say(you and (name .. " to shoot") or "Your shot", you and { 0.8, 0.8, 0.9 } or COLORS.gold, 1.6)
        end
    end
    self.placing = g.inHand and g.turn == "you"
    self.angle = pi / 2
    self:RefreshHUD()
end

function UI:ShowResult()
    local g = self.game
    local db = self.db
    self.db.run = nil
    self:HideAim()
    if g.mode == "match" then
        local won = g.winner == "you"
        local rec = self:Record(g.foe)
        if not self.counted then
            self.counted = true
            db.frames = db.frames + 1
            if won then rec.w = rec.w + 1 else rec.l = rec.l + 1 end
        end
        W.SFX(won and "win" or "lose")
        local name = Foe(g.foe).name
        local buttons = { { "Rematch", function() self:Begin("match", { foe = g.foe }) end } }
        if won and g.foe < #Pool.FOES then
            buttons[#buttons + 1] = { "Play " .. Foe(g.foe + 1).name, function() self:Begin("match", { foe = g.foe + 1 }) end }
        end
        buttons[#buttons + 1] = { "Menu", function() self:ShowMenu() end, "ghost" }
        local how = g.last and g.last.eight and ((g.winner == g.last.who) and "The eight is down." or "The eight went down too soon.") or ""
        self.card:Open({
            title = won and "You win the frame!" or (name .. " wins"), color = won and COLORS.gold or TINT, center = true,
            body = ("%s\n\nAgainst %s: |cffffffff%d|r won, |cffffffff%d|r lost"):format(how, name, rec.w, rec.l),
            buttons = buttons,
        })
    else
        local score = g:Score()
        local daily = g.mode == "daily"
        local newBest, best
        if daily then
            local d = self:Daily()
            local today = g.day == d.date
            newBest = today and ((d.best or 0) == 0 or score < d.best)
            if newBest then d.best = score end
            if today then d.run = nil end
            if not self.counted then self.counted = true; if today and (d.tries or 0) <= 1 then db.dailies = db.dailies + 1 end end
            if today then NS.Social:Submit("pld", d.date, d.best, g.fouls > 0 and (g.fouls .. " foul" .. (g.fouls == 1 and "" or "s")) or "clean") end
            best = d.best
        else
            newBest = db.bestSolo == 0 or score < db.bestSolo
            if newBest then db.bestSolo = score end
            NS.Social:SubmitBest("pl", db.bestSolo, "full rack")
            best = db.bestSolo
        end
        W.SFX("win")
        local rk, n
        if daily then rk, n = NS.Social:Rank("pld", self:Daily().date, "realm") end
        self.card:Open({
            title = "Table cleared!", color = COLORS.gold, center = true,
            body = ("|cffffffff%d|r shots%s%s\n\n%s: %d%s"):format(score, g.fouls > 0 and (" (%d from fouls)"):format(g.fouls) or "",
                newBest and "  |cff80ff80(new best!)|r" or "", daily and "Today's best" or "Your best", best or score,
                (rk and n > 1) and ("\nRank #%d of %d"):format(rk, n) or ""),
            buttons = {
                { "Again", function() if daily then self:Begin("daily", { restart = true }) else self:Begin("solo") end end },
                { "Leaderboard", function() self:ShowBoard(daily and "pld" or "pl") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Frame update, HUD
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    local g = self.game
    if self.finishPending and not self:Paused() then
        self.finishPending = nil
        self:ShowResult()
    end
    if not self:Paused() then
        if g.phase == "roll" then
            local ev, done = g:Step(el)
            if ev.hit > 25 then W.SFX("knock", 0.035) end
            if ev.rail > 60 then W.SFX("pop3", 0.06) end
            for _, p in ipairs(ev.pots) do
                self:Burst(OX + p.x, OY + p.y, p.id == 0 and { 1, 0.4, 0.3 } or { 1, 0.9, 0.6 }, 10)
                W.SFX(p.id == 0 and "lose" or ("pop" .. (4 + p.id % 4)), 0.04)
            end
            self:HideAim()
            if #ev.pots > 0 then self:RefreshHUD() end
            if done then self:AfterShot(g.last) end
        elseif g.phase == "aim" then
            if g.turn == "you" then self:UpdateMine() else self:UpdateFoe(el) end
        else
            self:HideAim()
        end
    elseif g.phase ~= "roll" then
        self:HideAim()
    end
    self:DrawBalls()
    self:UpdateFX(el)
    -- power bar
    local showPower = g.phase == "aim" and g.turn == "you" and not self.placing
    self.powerBg:SetShown(showPower); self.powerFill:SetShown(showPower and self.power > 0); self.powerText:SetShown(showPower)
    if showPower and self.power > 0 then
        self.powerFill:SetHeight(max(1, 146 * self.power))
        self.powerFill:SetColorTexture(1, 0.85 - 0.6 * self.power, 0.2, 1)
    end
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.25; self:RefreshHUD() end
end

function UI:FillColumn(c, title, sub, ids, lit)
    c.name:SetText(title or "")
    c.sub:SetText(sub or "")
    c.turn:SetAlpha(lit and (0.22 + 0.08 * sin((self.rt or 0) * 4)) or 0)
    c.name:SetTextColor(lit and 1 or 0.7, lit and 0.82 or 0.7, lit and 0.38 or 0.75)
    for i, m in ipairs(c.minis) do
        local id = ids and ids[i]
        if id then
            m:Set(id)
            m:Put(self.board, c.x - 9 + ((i - 1) % 2) * 18, 104 + floor((i - 1) / 2) * 18)
        else
            m:Hide()
        end
    end
end

function UI:RefreshHUD()
    local g = self.game
    if not g or not self.scoreText then return end
    local playing = g.phase ~= "idle"
    local left, right = self.cols[1], self.cols[2]
    left.big:SetText(""); right.big:SetText("")
    if not playing then
        self.modeText:SetText("TAVERN POOL")
        self.nameText:SetText("Chalk your cue")
        self.scoreText:SetText("")
        self.rightLabel:SetText(""); self.rightValue:SetText("")
        self:FillColumn(left); self:FillColumn(right)
    elseif g.mode == "match" then
        local foe = Foe(g.foe)
        local rec = self:Record(g.foe)
        self.modeText:SetText("EIGHT-BALL")
        self.nameText:SetText(g.phase == "over" and "Frame over" or (g.turn == "you" and (self.placing and "Ball in hand" or "Your shot") or (foe.name .. " to shoot")))
        self.scoreText:SetText(("%d - %d"):format(rec.w, rec.l))
        self.rightLabel:SetText("AGAINST")
        self.rightValue:SetText((foe.name:gsub("^The ", "")))
        local function todo(who)
            local kind = g.group[who]
            if not kind then return nil, "Open table" end
            local ids = {}
            for _, b in ipairs(g.balls) do if b.on and Pool.Kind(b.id) == kind then ids[#ids + 1] = b.id end end
            table.sort(ids)
            if #ids == 0 and g:Get(8).on then ids[1] = 8 end
            return ids, kind == "solid" and "Solids" or "Stripes"
        end
        local ids, sub = todo("you")
        self:FillColumn(left, "YOU", sub, ids, g.turn == "you" and g.phase ~= "over")
        ids, sub = todo("foe")
        self:FillColumn(right, foe.name:gsub("^The ", ""):upper(), sub, ids, g.turn == "foe" and g.phase ~= "over")
    else
        local daily = g.mode == "daily"
        self.modeText:SetText(daily and "DAILY TABLE" or "SOLO TABLE")
        self.nameText:SetText(self.placing and "Ball in hand" or "Clear the table")
        self.scoreText:SetText("")
        self.rightLabel:SetText(daily and "TODAY'S BEST" or "BEST")
        local best = daily and (self:Daily().best or 0) or self.db.bestSolo
        self.rightValue:SetText(best > 0 and tostring(best) or "-")
        self:FillColumn(left, "SHOTS", g.fouls > 0 and ("%d from fouls"):format(g.fouls) or "", nil, false)
        left.big:SetText(tostring(g:Score()))
        local ids = {}
        for _, b in ipairs(g.balls) do if b.on and b.id ~= 0 then ids[#ids + 1] = b.id end end
        table.sort(ids)
        self:FillColumn(right, "LEFT", "", ids, false)
    end
    self.restartButton:SetShown(playing)
end

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------
local function NewSeed()
    local t = (time and time() or 0) % 1000000
    local ms = floor(((GetTime and GetTime() or 0) % 1000) * 1000)
    return t * 79 + ms + 1
end

function UI:Begin(mode, opts)
    opts = opts or {}
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    local g = self.game
    self.ai, self.drag, self.lock, self.finishPending = nil, nil, nil, nil
    self.power = 0
    if mode == "daily" then
        local d = self:Daily()
        if not (not opts.restart and d.run and g:Restore(d.run) and g.day == d.date and g.phase ~= "over") then
            g:Start("daily", { day = d.date })
            d.tries = (d.tries or 0) + 1
        end
    elseif mode == "match" then
        g:Start("match", { foe = opts.foe or 1, seed = NewSeed() })
    else
        g:Start("solo", { seed = NewSeed() })
    end
    self.counted = false
    self.placing = g.inHand and g.turn == "you"
    self.angle = pi / 2
    self:Save()
    W.SFX("launch")
    if g.mode == "match" then self:Say("Your break", COLORS.gold, 1.8)
    elseif g.shots == 0 then self:Say(g.mode == "daily" and "Today's table" or "Your break", COLORS.gold, 1.8) end
    self:RefreshHUD()
end

function UI:Restart()
    local g = self.game
    if g.phase == "idle" then return end
    if g.mode == "match" then self:Begin("match", { foe = g.foe })
    elseif g.mode == "daily" then self:Begin("daily", { restart = true })
    else self:Begin("solo") end
end

---------------------------------------------------------------------------
-- Menu, boards, help
---------------------------------------------------------------------------
function UI:OnShow()
    self:RefreshHUD()
    if not self.db.seenHelp then
        self.db.seenHelp = true
        if self.game.phase == "idle" then self:ShowHelp(); return end
    end
    if (self.game.phase == "idle" or self.game.phase == "over") and not self.card:IsShown() and not self.boardPanel:IsShown() and not self.finishPending then self:ShowMenu() end
end

-- the window is closing: a shot still rolling is played out, so the table is at rest in the save
function UI:OnHide()
    self.drag, self.power = nil, 0
    local g = self.game
    if g.phase == "roll" then
        g:Run()
        self:AfterShot(g.last)
    end
end

function UI:ShowMenu()
    local g = self.game
    if g.phase == "roll" then g:Run(); self:AfterShot(g.last) end
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local d = self:Daily()
    local playing = g.phase == "aim"
    local recs = {}
    for i, foe in ipairs(Pool.FOES) do
        local r = self:Record(i)
        recs[#recs + 1] = ("%s |cffffffff%d-%d|r"):format(foe.name:gsub("^The ", ""), r.w, r.l)
    end
    local lines = {
        "Frames won and lost:  " .. table.concat(recs, "    "),
        ("Solo table best: |cffffffff%s|r"):format(db.bestSolo > 0 and (db.bestSolo .. " shots") or "-"),
        ("Today's Daily Table: %s"):format((d.best or 0) > 0 and ("cleared in |cffffffff" .. d.best .. "|r shots") or (d.run and "under way" or "not played yet")),
    }
    local rl = NS.Social:RankLine("pld", d.date)
    if rl then lines[#lines + 1] = "Daily: " .. rl end
    local buttons = {}
    if playing then buttons[#buttons + 1] = { "Resume", function() end } end
    for i, foe in ipairs(Pool.FOES) do
        buttons[#buttons + 1] = { "Play " .. foe.name, function() self:Begin("match", { foe = i }) end, playing and "ghost" or nil }
    end
    buttons[#buttons + 1] = { "Solo table", function() self:Begin("solo") end, "ghost" }
    if #buttons < 6 and not (playing and g.mode == "daily") then
        buttons[#buttons + 1] = { d.run and "Continue daily" or "Daily Table", function() self:Begin("daily") end }
    elseif not (playing and g.mode == "daily") then
        -- six is all the menu holds: while a frame is going, the daily takes the solo table's place
        buttons[#buttons] = { d.run and "Continue daily" or "Daily Table", function() self:Begin("daily") end }
    end
    self.menu:Open({
        title = "Tavern Pool", sub = "Eight-ball against the regulars", icon = W.MEDIA .. "ball_bomb",
        color = TINT, lines = lines, buttons = buttons, options = NS.CommonOptions(),
    })
end

function UI:ShowBoard(which)
    local g = self.game
    if g.phase == "roll" then g:Run(); self:AfterShot(g.last) end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    self.boardPanel:Open({
        views = {
            { label = "Daily", game = "pld", periods = false, period = "day", title = "Daily Table", sub = "Fewest shots to clear today's table" },
            { label = "Solo", game = "pl", periods = true, title = "Solo Table", sub = "Fewest shots to clear a full rack" },
        },
        view = which == "pl" and 2 or 1,
        empty = "Nobody has cleared this one yet.",
        fmt = function(e) return ("%d shots"):format(e.s), e.d or "" end,
        onClose = function() if self.game.phase ~= "aim" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.card:Open({
        title = "Tavern Pool", color = TINT,
        body = table.concat({
            "|cffffcc40Aim|r by pointing where the cue ball should go. The line shows what it will strike and which way that ball sets off. The mouse wheel turns the aim a hair (Shift for a finer hair).",
            "",
            "|cffffcc40Shoot|r: press and hold, draw the pointer back for power (the further, the harder), and let go. Right-click lets the cue down without shooting.",
            "",
            "|cffffcc40Eight-ball|r: the first ball you pot after the break makes you solids or stripes. Pot all seven of yours, then the black eight, to win. Pot one of yours and you shoot again.",
            "",
            "A |cffffcc40foul|r (the cue ball down a pocket, nothing struck, or the wrong ball struck first) gives the other player the cue ball in hand: it goes wherever they like. The eight down too soon loses the frame.",
            "",
            "|cffffcc40Solo|r and the |cffffcc40Daily Table|r: clear every ball in as few shots as you can. The daily table is the same for everyone.",
        }, "\n"),
        buttons = { { "Chalk up", function() if self.game.phase ~= "aim" then self:ShowMenu() end end } },
    })
end

function UI:Banner() end
