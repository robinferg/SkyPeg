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
-- A ball. It is a coloured disc carrying marks that sit on a sphere and turn with it: a solid
-- has one pale spot, a stripe has a white cap at each pole (so its band shows between them), the
-- eight has a white spot, and the cue ball two small red dots that give its spin away. The marks
-- are cut to the ball's outline, so they slide round the edge and out of sight as it rolls.
---------------------------------------------------------------------------
local function NewBall(parent, size, layer, sub)
    local b = { size = size, px = 0, py = 0, pz = 1, qx = 1, qy = 0, qz = 0 }
    local function disc(s2, r, g, bl, a)
        local t = parent:CreateTexture(nil, layer, nil, s2)
        t:SetTexture(W.MEDIA .. "circle")
        if r then t:SetVertexColor(r, g, bl, a or 1) end
        return t
    end
    b.shadow = disc(sub, 0, 0, 0, 0.35)
    b.base = disc(sub + 1)
    b.m1, b.m2 = disc(sub + 2), disc(sub + 2)
    b.shine = parent:CreateTexture(nil, layer, nil, sub + 3)
    b.shine:SetTexture(W.MEDIA .. "pool\\ball_over")
    if parent.CreateMaskTexture and b.m1.AddMaskTexture then
        b.mask = parent:CreateMaskTexture()
        b.mask:SetTexture(W.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        b.m1:AddMaskTexture(b.mask); b.m2:AddMaskTexture(b.mask)
    end
    b.all = { b.shadow, b.base, b.m1, b.m2, b.shine }
    function b:Set(id)
        if self.id == id then return end
        self.id = id
        local c = Pool.Color(id)
        local kind = Pool.Kind(id)
        self.base:SetVertexColor(c[1], c[2], c[3])
        self.kind = kind
        if kind == "stripe" then
            self.m1:SetVertexColor(0.96, 0.95, 0.90); self.m2:SetVertexColor(0.96, 0.95, 0.90)
            self.markK = 0.64
        elseif kind == "cue" then
            self.m1:SetVertexColor(0.85, 0.12, 0.10); self.m2:SetVertexColor(0.85, 0.12, 0.10)
            self.markK = 0.17
        else
            self.m1:SetVertexColor(0.96, 0.95, 0.90)
            self.markK = 0.40
        end
    end
    -- which way up the ball lies: p is the first mark, q a second axis at right angles to it
    function b:Face(px, py, pz, qx, qy, qz)
        self.px, self.py, self.pz = px, py, pz
        if qx then self.qx, self.qy, self.qz = qx, qy, qz end
    end
    local function mark(self, t, anchor, x, y, s, mx, my, mz, alpha, dim)
        -- a mark at (mx, my, mz) on the unit ball (z towards the eye): seen while it faces us,
        -- and a little longer for a big cap, whose edge is still in view past the rim
        local big = self.markK > 0.5
        if mz < (big and -0.62 or 0.02) or (not self.mask and mz < 0.45) then t:Hide(); return end
        local k = self.markK * (big and 1 or (0.55 + 0.45 * mz))
        t:ClearAllPoints()
        t:SetPoint("CENTER", anchor, "TOPLEFT", x + mx * s * 0.5, -(y + my * s * 0.5))
        t:SetSize(s * k, s * k)
        t:SetAlpha(alpha)
        t:Show()
    end
    function b:Put(anchor, x, y, scale, alpha, dim)
        local s = self.size * (scale or 1)
        alpha = alpha or 1
        self.shadow:ClearAllPoints(); self.shadow:SetPoint("CENTER", anchor, "TOPLEFT", x + 1.5, -(y + 2)); self.shadow:SetSize(s, s)
        self.shadow:SetAlpha(0.35 * alpha); self.shadow:Show()
        self.base:ClearAllPoints(); self.base:SetPoint("CENTER", anchor, "TOPLEFT", x, -y); self.base:SetSize(s, s); self.base:SetAlpha(alpha); self.base:Show()
        if dim then
            local c = Pool.Color(self.id)
            self.base:SetVertexColor(c[1] * dim, c[2] * dim, c[3] * dim)
            self.dimmed = true
        elseif self.dimmed then
            local c = Pool.Color(self.id)
            self.base:SetVertexColor(c[1], c[2], c[3])
            self.dimmed = nil
        end
        if self.mask then self.mask:ClearAllPoints(); self.mask:SetPoint("CENTER", anchor, "TOPLEFT", x, -y); self.mask:SetSize(s, s) end
        mark(self, self.m1, anchor, x, y, s, self.px, self.py, self.pz, alpha)
        if self.kind == "stripe" then mark(self, self.m2, anchor, x, y, s, -self.px, -self.py, -self.pz, alpha)
        elseif self.kind == "cue" then mark(self, self.m2, anchor, x, y, s, self.qx, self.qy, self.qz, alpha)
        else self.m2:Hide() end
        self.shine:ClearAllPoints(); self.shine:SetPoint("CENTER", anchor, "TOPLEFT", x, -y); self.shine:SetSize(s * 1.06, s * 1.06)
        self.shine:SetAlpha(alpha); self.shine:Show()
    end
    function b:Hide() for _, t in ipairs(self.all) do t:Hide() end end
    -- roll the ball: (ux, uy) is its surface speed over the cloth in screen units, e its side spin
    function b:Turn(ux, uy, e, dt, R)
        local sp = sqrt(ux * ux + uy * uy)
        if sp > 0.5 then
            local th = sp * dt / R
            local c, sn = cos(th), sin(th)
            local dx, dy = ux / sp, uy / sp
            for _, v in ipairs({ "p", "q" }) do
                local x, y, z = self[v .. "x"], self[v .. "y"], self[v .. "z"]
                local along = x * dx + y * dy
                local a2, z2 = along * c + z * sn, z * c - along * sn
                self[v .. "x"], self[v .. "y"], self[v .. "z"] = x + (a2 - along) * dx, y + (a2 - along) * dy, z2
            end
        end
        if e ~= 0 then
            local ph = e * dt / R
            local c, sn = cos(ph), sin(ph)
            self.px, self.py = self.px * c + self.py * sn, -self.px * sn + self.py * c
            self.qx, self.qy = self.qx * c + self.qy * sn, -self.qx * sn + self.qy * c
        end
    end
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
    local ART = W.MEDIA .. "pool\\"
    -- the tavern floor, lit by the lamp over the table
    local room = board:CreateTexture(nil, "BACKGROUND", nil, 0)
    room:SetTexture(ART .. "floor"); room:SetAllPoints(); room:SetVertexColor(0.50, 0.46, 0.44)
    local lamp = board:CreateTexture(nil, "BACKGROUND", nil, 1)
    lamp:SetTexture(W.MEDIA .. "glow"); lamp:SetBlendMode("ADD"); lamp:SetVertexColor(1, 0.75, 0.4, 0.14)
    lamp:SetPoint("CENTER"); lamp:SetSize(FW * 1.6, FH * 1.3)
    local under = W.Solid(board, "BACKGROUND", 0, 0, 0, 0.45, 2)      -- the table's shadow on the floor
    under:SetPoint("TOPLEFT", board, "TOPLEFT", OX - RAIL + 4, -(OY - RAIL + 6)); under:SetSize(TW + 2 * RAIL, TH + 2 * RAIL)
    -- cushions (a darker strip of cloth) and the cloth itself, laid as two mirrored halves
    local cushion = W.Solid(board, "BACKGROUND", FELT[1] * 0.6, FELT[2] * 0.6, FELT[3] * 0.6, 1, 3)
    cushion:SetPoint("TOPLEFT", board, "TOPLEFT", OX - 4, -(OY - 4)); cushion:SetSize(TW + 8, TH + 8)
    for half = 0, 1 do
        local cloth = board:CreateTexture(nil, "BACKGROUND", nil, 4)
        cloth:SetTexture(ART .. "felt")
        cloth:SetPoint("TOPLEFT", board, "TOPLEFT", OX, -(OY + half * TH / 2)); cloth:SetSize(TW, TH / 2)
        if half == 1 then cloth:SetTexCoord(0, 1, 1, 0) end
        cloth:SetVertexColor(0.86, 0.92, 0.88)
    end
    local sheen = board:CreateTexture(nil, "BACKGROUND", nil, 5)
    sheen:SetTexture(W.MEDIA .. "glow"); sheen:SetBlendMode("ADD"); sheen:SetVertexColor(1, 0.95, 0.7, 0.10)
    sheen:SetPoint("CENTER", board, "TOPLEFT", OX + TW / 2, -(OY + TH / 2)); sheen:SetSize(TW * 1.5, TH * 1.1)
    -- rails: one plank, turned and mirrored so its brass edge always faces the cloth
    local function rail(file, x, y, w, h, l, r, t, b2)
        local tx = board:CreateTexture(nil, "BACKGROUND", nil, 6)
        tx:SetTexture(ART .. file)
        tx:SetPoint("TOPLEFT", board, "TOPLEFT", x, -y); tx:SetSize(w, h)
        tx:SetTexCoord(l, r, t, b2)
    end
    rail("rail_h", OX - RAIL, OY - RAIL, TW + 2 * RAIL, RAIL, 0, 1, 0, 1)
    rail("rail_h", OX - RAIL, OY + TH, TW + 2 * RAIL, RAIL, 0, 1, 1, 0)
    -- (the long rails are laid as two lengths each, mirrored at the middle pocket, so the plank
    -- keeps its proportions and each half carries its three diamonds)
    local half = TH / 2 + RAIL
    rail("rail_v", OX - RAIL, OY - RAIL, RAIL, half, 0, 1, 0, 0.84)
    rail("rail_v", OX - RAIL, OY - RAIL + half, RAIL, half, 0, 1, 0.84, 0)
    rail("rail_v", OX + TW, OY - RAIL, RAIL, half, 1, 0, 0, 0.84)
    rail("rail_v", OX + TW, OY - RAIL + half, RAIL, half, 1, 0, 0.84, 0)
    for _, p in ipairs(Pool.POCKETS) do
        local t = board:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(ART .. "pocket")
        t:SetSize(46, 46)
        -- (the leather and brass sit back over the rail; the hole is where the balls drop)
        local ox = p.x < TW / 2 and -5 or 5
        local oy = (p.y < 10 and -5) or (p.y > TH - 10 and 5) or 0
        t:SetPoint("CENTER", board, "TOPLEFT", OX + p.x + ox, -(OY + p.y + oy))
    end

    -- the balls, the sight line, the cue
    self.sprites = {}
    for i = 1, 16 do self.sprites[i] = NewBall(board, 2 * R, "ARTWORK", -4) end
    self.sinkers, self.sinks = {}, {}       -- balls on their way down a pocket
    for i = 1, 6 do self.sinkers[i] = NewBall(board, 2 * R, "BORDER", 2) end
    local function pill(layer, sub)
        local t = board:CreateTexture(nil, layer or "ARTWORK", nil, sub or 2)
        t:SetTexture(W.MEDIA .. "pill")
        t:Hide()
        return t
    end
    self.sight, self.objLine, self.cueLine = pill(), pill(), pill()
    self.ghost = board:CreateTexture(nil, "ARTWORK", nil, 3)
    self.ghost:SetTexture(W.MEDIA .. "ring"); self.ghost:SetSize(2 * R * 2.45, 2 * R * 2.45); self.ghost:Hide()      -- (the ring fills about two fifths of its texture)
    self.stick = board:CreateTexture(nil, "OVERLAY", nil, 1)
    self.stick:SetTexture(ART .. "cue")
    self.stick:Hide()
    self.stickTip = pill("OVERLAY", 2)       -- (the painted cue has its own tip; this stays hidden)
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
        c.face = board:CreateTexture(nil, "ARTWORK", nil, 0)
        c.face:SetSize(54, 54)
        c.face:SetPoint("CENTER", board, "TOPLEFT", cx, -42)
        c.face:SetTexCoord(0.08, 0.92, 0.04, 0.88)
        if board.CreateMaskTexture and c.face.AddMaskTexture then
            local mask = board:CreateMaskTexture()
            mask:SetTexture(W.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(c.face)
            c.face:AddMaskTexture(mask)
        end
        c.ring = board:CreateTexture(nil, "ARTWORK", nil, 1)
        c.ring:SetTexture(W.TAVERN .. "tav_ring")
        c.ring:SetSize(66, 66)
        c.ring:SetPoint("CENTER", c.face, "CENTER")
        c.name = W.Text(board, 11, W.FONT_TITLE)
        c.name:SetPoint("TOP", board, "TOPLEFT", cx, -80)
        c.name:SetWidth(70)
        c.sub = W.Text(board, 10, W.FONT)
        c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -3)
        c.sub:SetWidth(70)
        c.sub:SetTextColor(0.75, 0.78, 0.9)
        c.turn = board:CreateTexture(nil, "BACKGROUND", nil, 2)
        c.turn:SetTexture(W.MEDIA .. "glow"); c.turn:SetBlendMode("ADD"); c.turn:SetVertexColor(1, 0.82, 0.38)
        c.turn:SetPoint("CENTER", board, "TOPLEFT", cx, -42); c.turn:SetSize(130, 130)
        c.minis = {}
        for i = 1, 15 do c.minis[i] = NewBall(board, 14, "ARTWORK", -4) end
        c.x = cx
        c.big = W.Text(board, 30, FONT_SHOUT, "OUTLINE")
        c.big:SetPoint("TOP", board, "TOPLEFT", cx, -118)
        self.cols[side] = c
    end
    -- where the tip strikes the cue ball: drag the dot (right-click puts it back in the middle)
    local sp = CreateFrame("Button", nil, board)
    sp:SetSize(58, 58)
    sp:SetPoint("CENTER", board, "TOPLEFT", 37, -(FH - 76))
    sp:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sp.ball = sp:CreateTexture(nil, "ARTWORK"); sp.ball:SetTexture(ART .. "ball"); sp.ball:SetAllPoints()
    sp.h = W.Solid(sp, "OVERLAY", 0, 0, 0, 0.18); sp.h:SetSize(50, 1); sp.h:SetPoint("CENTER")
    sp.v = W.Solid(sp, "OVERLAY", 0, 0, 0, 0.18); sp.v:SetSize(1, 50); sp.v:SetPoint("CENTER")
    sp.dot = sp:CreateTexture(nil, "OVERLAY", nil, 2); sp.dot:SetTexture(W.MEDIA .. "circle"); sp.dot:SetVertexColor(0.9, 0.12, 0.1); sp.dot:SetSize(12, 12)
    sp:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then self.spinDrag = true end end)
    sp:SetScript("OnMouseUp", function() self.spinDrag = nil end)
    sp:SetScript("OnClick", function(_, button) if button == "RightButton" then self.top, self.side = 0, 0 end end)
    sp:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetText("Spin", 1, 0.82, 0.38)
        GameTooltip:AddLine("Drag the dot to where the cue tip should strike. High: the cue ball runs on after it hits (follow). Low: it stops or comes back (draw). Left or right: it comes off the cushions that way.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click to go back to the middle.", 0.62, 0.88, 0.54)
        GameTooltip:Show()
    end)
    sp:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.spin = sp
    self.spinLabel = W.Text(board, 10, W.FONT)
    self.spinLabel:SetPoint("TOP", sp, "BOTTOM", 0, -4)
    self.spinLabel:SetTextColor(0.8, 0.8, 0.85)
    self.top, self.side = 0, 0

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
        self:FaceBalls()
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

-- how the balls lie when the table is set: each a little differently, so a rack looks like a rack
function UI:FaceBalls()
    for i, s in ipairs(self.sprites) do
        local b = self.game.balls[i]
        if b then
            local a1, a2 = (b.id * 2.399) % (2 * pi), 0.5 + (b.id * 0.731) % 1.0
            local px, py, pz = sin(a2) * cos(a1), sin(a2) * sin(a1), cos(a2)
            -- a second axis square to the first
            local qx, qy, qz = -sin(a1), cos(a1), 0
            s:Face(px, py, pz, qx, qy, qz)
        end
    end
    self.sinks = {}
    for _, s in ipairs(self.sinkers) do s:Hide(); s.busy = nil end
end

function UI:DrawBalls(el)
    local g = self.game
    local rolling = g.phase == "roll"
    for i, s in ipairs(self.sprites) do
        local b = g.balls[i]
        if b and b.on then
            s:Set(b.id)
            if rolling and el and (b.ux ~= 0 or b.uy ~= 0 or b.e ~= 0) then s:Turn(b.ux, b.uy, b.e, el, R) end
            s:Put(self.board, OX + b.x, OY + b.y)
        else
            s:Hide()
        end
    end
    -- balls going down: drawn into the pocket, shrinking and darkening as they drop out of sight
    local i = 1
    while i <= #self.sinks do
        local k = self.sinks[i]
        k.t = k.t + (el or 0)
        local u = k.t / 0.30
        if u >= 1 then
            k.s:Hide(); k.s.busy = nil
            table.remove(self.sinks, i)
        else
            local e = u * (2 - u)
            k.s:Turn(k.vx, k.vy, 0, el or 0, R)
            k.s:Put(self.board, OX + k.x + (k.px - k.x) * e, OY + k.y + (k.py - k.y) * e, 1 - 0.42 * e, 1 - u * u, 1 - 0.75 * e)
            i = i + 1
        end
    end
end

function UI:Sink(p)
    local s
    for _, c in ipairs(self.sinkers) do if not c.busy then s = c; break end end
    if not s then return end
    s.busy = true
    s:Set(p.id)
    -- it keeps the face it had on the table
    for i, b in ipairs(self.game.balls) do
        if b.id == p.id then local o = self.sprites[i]; s:Face(o.px, o.py, o.pz, o.qx, o.qy, o.qz) end
    end
    local pk = Pool.POCKETS[p.pocket]
    local dx, dy = pk.x - p.x, pk.y - p.y
    local d = sqrt(dx * dx + dy * dy)
    self.sinks[#self.sinks + 1] = { s = s, t = 0, x = p.x, y = p.y, px = pk.x, py = pk.y, vx = d > 0 and dx / d * 160 or 0, vy = d > 0 and dy / d * 160 or 0 }
end

-- the sight line, the ghost ball and the cue for a shot along `angle` with `pull` (0..1) on it
function UI:DrawAim(angle, pull, mine, power, top)
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
            -- and where the cue ball goes afterwards, with whatever spin is on it
            local fx, fy, fs = g:After(s, angle, power or 0.5, top or 0)
            if fs and fs > 12 then
                local cl = min(64, 10 + fs * 0.16)
                Line(self.cueLine, self.board, gx + fx * R, gy + fy * R, gx + fx * (R + cl), gy + fy * (R + cl), 1.5)
                self.cueLine:SetVertexColor(1, 1, 1, 0.45)
            else
                self.cueLine:Hide()
            end
        else
            self.objLine:Hide(); self.cueLine:Hide()
        end
    else
        self.sight:Hide(); self.ghost:Hide(); self.objLine:Hide(); self.cueLine:Hide()
    end
    -- the cue, drawn back by the pull
    local back = R + 4 + pull * 46
    self.stick:SetAlpha(1); self.stickTip:SetAlpha(1)
    -- (the cue is painted tip to the right, eight times as long as its picture is tall)
    Line(self.stick, self.board, x0 - dx * (back + 200), y0 - dy * (back + 200), x0 - dx * back, y0 - dy * back, 25)
    self.stickTip:Hide()
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
function UI:IsBusy() return self.game.phase == "roll" or self.strike ~= nil or #self.sinks > 0 end

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
    return g.phase == "aim" and g.turn == "you" and not self.strike and not self:Paused()
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
        self:Shoot(self.angle, self.power, self.top, self.side)
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
    self:DrawAim(self.angle, self.drag and self.power or 0, true, self.drag and self.power or 0.5, self.top)
end

-- the cue comes through the ball (a tenth of a second), then the shot is on its way
function UI:Shoot(angle, power, top, side)
    if self.strike or self.game.phase ~= "aim" then return end
    self.strike = { angle = angle, power = power, top = top or 0, side = side or 0, t = 0 }
    self.lock, self.drag = nil, nil
end

function UI:StepStrike(el)
    local k = self.strike
    k.t = k.t + el
    local u = min(1, k.t / 0.09)
    self:DrawAim(k.angle, k.power * (1 - u) - 0.1 * u, false)
    if u >= 1 then
        self.strike = nil
        self:Fire(k.angle, k.power, k.top, k.side)
    end
end

function UI:Fire(angle, power, top, side)
    local g = self.game
    if not g:Shoot(angle, power, top, side) then return end
    -- saved with the shot on it, so a window closed while the balls roll loses nothing
    self:Save()
    self.sight:Hide(); self.ghost:Hide(); self.objLine:Hide(); self.cueLine:Hide()
    self.stickFade = 0.35
    W.SFX("putt", 0.05)
    self.top, self.side = 0, 0
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
        ai = { stage = "wait", t = 0.6 }
        self.ai = ai
    end
    ai.t = ai.t - el
    if ai.stage == "wait" then
        self:HideAim()
        if ai.t <= 0 then ai.stage, ai.think = "think", g:ThinkBegin() end
    elseif ai.stage == "think" then
        -- one imagined shot a frame, so the screen never waits on them
        ai.plan = g:ThinkStep(ai.think)
        if ai.plan then
            if ai.plan.place then g:PlaceCue(ai.plan.place.x, ai.plan.place.y) end
            ai.stage, ai.t = "aim", 1.0
        end
    elseif ai.stage == "aim" then
        local k = 1 - max(0, ai.t) / 1.0
        self:DrawAim(ai.plan.angle, ai.plan.power * min(1, k * 1.4), false)
        if ai.t <= 0 then
            self.ai = nil
            self:Shoot(ai.plan.angle, ai.plan.power, ai.plan.top, ai.plan.side)
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
                self:Sink(p)
                W.SFX("cup", 0.05)
            end
            if #ev.pots > 0 then self:RefreshHUD() end
            if done then self:AfterShot(g.last) end
        elseif self.strike then
            self:StepStrike(el)
        elseif g.phase == "aim" then
            if g.turn == "you" then self:UpdateMine() else self:UpdateFoe(el) end
        else
            self:HideAim()
        end
    elseif g.phase ~= "roll" then
        self:HideAim()
    end
    self:DrawBalls(self:Paused() and 0 or el)
    self:UpdateFX(el)
    -- the cue lifts away after the stroke
    if g.phase == "roll" then
        self.stickFade = (self.stickFade or 0) - el
        if self.stickFade > 0 then
            self.stick:SetAlpha(self.stickFade / 0.35); self.stickTip:SetAlpha(self.stickFade / 0.35)
        else
            self.stick:Hide(); self.stickTip:Hide()
        end
    end
    -- the spin picker
    local mine = g.phase == "aim" and g.turn == "you" and not self.placing
    self.spin:SetShown(mine); self.spinLabel:SetShown(mine)
    if mine then
        if self.spinDrag and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.spinDrag = nil end
        if self.spinDrag then
            local x, y = GetCursorPosition()
            local sc = self.spin:GetEffectiveScale()
            local cx, cy = self.spin:GetCenter()
            if cx then
                local sx, sy = (x / sc - cx) / 22, (y / sc - cy) / 22
                local l = sqrt(sx * sx + sy * sy)
                if l > 1 then sx, sy = sx / l, sy / l end
                self.side, self.top = sx, sy
            end
        end
        self.spin.dot:ClearAllPoints()
        self.spin.dot:SetPoint("CENTER", self.spin, "CENTER", self.side * 22, self.top * 22)
        local t, sd = self.top, self.side
        self.spinLabel:SetText((abs(t) < 0.12 and abs(sd) < 0.12) and "SPIN" or ((t > 0.3 and "FOLLOW" or (t < -0.3 and "DRAW" or "")) .. ((abs(sd) > 0.3 and (t > 0.3 or t < -0.3)) and " + " or "") .. (sd > 0.3 and "RIGHT" or (sd < -0.3 and "LEFT" or ""))))
    end
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

-- face: "player" for your own portrait, a regular's key for theirs, nil for none
function UI:FillColumn(c, title, sub, ids, lit, face)
    if c.shown ~= (face or false) then
        c.shown = face or false
        local ok = false
        if face == "player" then
            if SetPortraitTexture then ok = pcall(SetPortraitTexture, c.face, "player"); c.face:SetTexCoord(0, 1, 0, 1) end
        elseif face then
            c.face:SetTexture(W.MEDIA .. "pool\\foe_" .. face); c.face:SetTexCoord(0.08, 0.92, 0.04, 0.88)
            ok = true
        end
        c.face:SetShown(ok); c.ring:SetShown(ok)
    end
    c.name:SetText(title or "")
    c.sub:SetText(sub or "")
    c.turn:SetAlpha(lit and (0.22 + 0.08 * sin((self.rt or 0) * 4)) or 0)
    c.name:SetTextColor(lit and 1 or 0.7, lit and 0.82 or 0.7, lit and 0.38 or 0.75)
    for i, m in ipairs(c.minis) do
        local id = ids and ids[i]
        if id then
            m:Set(id)
            m:Put(self.board, c.x - 9 + ((i - 1) % 2) * 18, 130 + floor((i - 1) / 2) * 18)
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
        self:FillColumn(left, "YOU", sub, ids, g.turn == "you" and g.phase ~= "over", "player")
        ids, sub = todo("foe")
        self:FillColumn(right, foe.name:gsub("^The ", ""):upper(), sub, ids, g.turn == "foe" and g.phase ~= "over", foe.key)
    else
        local daily = g.mode == "daily"
        self.modeText:SetText(daily and "DAILY TABLE" or "SOLO TABLE")
        self.nameText:SetText(self.placing and "Ball in hand" or "Clear the table")
        self.scoreText:SetText("")
        self.rightLabel:SetText(daily and "TODAY'S BEST" or "BEST")
        local best = daily and (self:Daily().best or 0) or self.db.bestSolo
        self.rightValue:SetText(best > 0 and tostring(best) or "-")
        self:FillColumn(left, "SHOTS", g.fouls > 0 and ("%d from fouls"):format(g.fouls) or "", nil, false, "player")
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
    self.strike, self.top, self.side = nil, 0, 0
    self:FaceBalls()
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
    self.drag, self.power, self.spinDrag = nil, 0, nil
    local g = self.game
    if self.strike then local k = self.strike; self.strike = nil; self:Fire(k.angle, k.power, k.top, k.side) end
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
        title = "Tavern Pool", sub = "Eight-ball against the regulars", icon = W.TAVERN .. "tok_pool",
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
            "|cffffcc40Spin|r: drag the red dot on the cue ball (bottom left) to where the tip should strike. High makes the cue ball run on after it hits, low stops it or brings it back, left and right change how it comes off the cushions.",
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
