-- Flight Buddy :: OrbsUI.lua
-- Orb Cannon: the screen. Aim with the pointer, click to fire, right-click (or click the waiting
-- orb) to swap. The engine (Orbs.lua) resolves each shot at once; this plays it back: the orb's
-- flight, the bursts rippling out from where it landed, and the loose orbs falling.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Orbs = NS.Orbs
local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt

local UI = {}
NS.OrbsUI = UI

local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local BX, BY = 24, 10                       -- field offset inside the 480x560 holder
local FW, FH = Orbs.W, 530
local D, ROWH = Orbs.D, Orbs.ROWH
local CX, CY = Orbs.CX, Orbs.CY
local LINE_Y = Orbs.R * 2 + (Orbs.MAXROW - 1) * ROWH + 6     -- the line the orbs must not cross
local FLY_SPEED = 1250
local TINT = { 0.72, 0.52, 1.0 }

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function Today() return NS.Social.Today() end
local function Tex(color) return W.MEDIA .. "ball_" .. Orbs.KINDS[color].key end

function UI:Init(db)
    self.db = db
    db.best = db.best or 0
    db.bestWave = db.bestWave or 0
    db.bestDrop = db.bestDrop or 0
    db.games = db.games or 0
    db.daily = db.daily or {}
    db.dailies = db.dailies or 0
end

function UI:Daily()
    local d = self.db.daily
    if d.date ~= Today() then d.date, d.best, d.tries, d.run, d.cleared = Today(), 0, 0, nil, false end
    return d
end

function UI:DailyPending() return (self:Daily().best or 0) == 0 end

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
    local back = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetTexture(W.MEDIA .. "pbg_frost_peaks")
    back:SetAllPoints()
    back:SetTexCoord(0.03, 0.97, 0, 1)
    local frame = CreateFrame("Frame", nil, holder)
    frame:SetSize(FW + 20, FH + 16)
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", BX - 10, -BY + 8)
    W.Nine(frame, "wood", 16, "BACKGROUND", -6)

    local board = CreateFrame("Frame", nil, holder)
    board:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    board:SetSize(FW, FH)
    board:SetFrameLevel(holder:GetFrameLevel() + 2)
    self.board = board
    local sky = board:CreateTexture(nil, "BACKGROUND", nil, 0)
    sky:SetTexture(W.MEDIA .. "pbg_frost_peaks")
    sky:SetAllPoints()
    sky:SetTexCoord(0.1, 0.9, 0, 1)
    sky:SetVertexColor(0.42, 0.44, 0.58)
    local shade = W.Solid(board, "BACKGROUND", 0.03, 0.03, 0.08, 0.45, 1)
    shade:SetAllPoints()
    -- the line: dashes right across, glowing redder as the orbs come down to it
    self.dashes = {}
    for i = 1, 18 do
        local t = W.Solid(board, "BACKGROUND", 1, 0.3, 0.22, 0.5, 2)
        t:SetSize(14, 2)
        t:SetPoint("CENTER", board, "TOPLEFT", (i - 0.5) * 24, -LINE_Y)
        self.dashes[i] = t
    end
    -- the floor the cannon stands on
    local floorBand = W.Solid(board, "BACKGROUND", 0.05, 0.04, 0.07, 0.72, 2)
    floorBand:SetPoint("BOTTOMLEFT"); floorBand:SetPoint("BOTTOMRIGHT")
    floorBand:SetHeight(FH - LINE_Y - 14)

    -- aim guide
    self.dots = {}
    for i = 1, 36 do
        local t = board:CreateTexture(nil, "ARTWORK", nil, 0)
        t:SetTexture(W.MEDIA .. "circle")
        t:Hide()
        self.dots[i] = t
    end
    -- cannon
    local base = board:CreateTexture(nil, "ARTWORK", nil, 1)
    base:SetTexture(W.MEDIA .. "circle")
    base:SetVertexColor(0.16, 0.12, 0.10)
    base:SetSize(64, 64)
    base:SetPoint("CENTER", board, "TOPLEFT", CX, -(CY + 14))
    self.barrel = board:CreateTexture(nil, "ARTWORK", nil, 2)
    self.barrel:SetTexture(W.MEDIA .. "rb_cannon")
    self.barrel:SetSize(92, 92)
    self.barrel:SetPoint("CENTER", board, "TOPLEFT", CX, -(CY + 2))
    self.loaded = board:CreateTexture(nil, "ARTWORK", nil, 4)
    self.loaded:SetSize(D, D)
    self.loaded:SetPoint("CENTER", board, "TOPLEFT", CX, -CY)
    self.loadedGlow = board:CreateTexture(nil, "ARTWORK", nil, 3)
    self.loadedGlow:SetTexture(W.MEDIA .. "glow")
    self.loadedGlow:SetBlendMode("ADD")
    self.loadedGlow:SetSize(D * 2.2, D * 2.2)
    self.loadedGlow:SetPoint("CENTER", board, "TOPLEFT", CX, -CY)
    -- the orb waiting its turn: click it to swap
    local nb = CreateFrame("Button", nil, board)
    nb:SetSize(40, 40)
    nb:SetPoint("CENTER", board, "TOPLEFT", CX - 92, -(CY + 2))
    nb.ring = nb:CreateTexture(nil, "BACKGROUND")
    nb.ring:SetTexture(W.MEDIA .. "circle")
    nb.ring:SetVertexColor(0, 0, 0, 0.5)
    nb.ring:SetAllPoints()
    nb.icon = nb:CreateTexture(nil, "ARTWORK")
    nb.icon:SetSize(28, 28)
    nb.icon:SetPoint("CENTER")
    nb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nb:SetScript("OnClick", function() W.Guard("Orbs", self.Swap, self) end)
    nb:SetScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetText("Next orb", 1, 0.82, 0.38)
        GameTooltip:AddLine("Click here, or right-click anywhere, to swap it with the one in the cannon.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    nb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.nextButton = nb
    self.nextLabel = W.Text(board, 10, W.FONT)
    self.nextLabel:SetPoint("TOP", nb, "BOTTOM", 0, 0)
    self.nextLabel:SetTextColor(0.75, 0.78, 0.9)
    self.nextLabel:SetText("NEXT")
    -- misses left before the ceiling comes down
    self.pips = {}
    for i = 1, 9 do
        local t = board:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetTexture(W.MEDIA .. "circle")
        t:SetSize(11, 11)
        self.pips[i] = t
    end
    self.pipLabel = W.Text(board, 10, W.FONT)
    self.pipLabel:SetTextColor(0.75, 0.78, 0.9)
    self.pipLabel:SetPoint("TOP", board, "TOPLEFT", CX + 104, -(CY + 14))
    self.streakText = W.Text(board, 12, W.FONT_TITLE)
    self.streakText:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -10, 78)
    self.streakText:SetTextColor(1, 0.82, 0.38)

    -- sprites
    self.sprites, self.spritePool = {}, {}
    self.loose, self.loosePool = {}, {}       -- orbs bursting, falling or flying
    local fx = CreateFrame("Frame", nil, holder)
    fx:SetAllPoints(board)
    fx:SetFrameLevel(board:GetFrameLevel() + 6)
    fx:EnableMouse(false)
    self.fx = fx
    self.parts = {}
    for i = 1, 120 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(W.MEDIA .. "sparkle")
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.floats = {}
    for i = 1, 6 do
        local t = W.Text(fx, 20, FONT_SHOUT, "OUTLINE")
        t:Hide()
        self.floats[i] = { t = t, life = 0 }
    end
    self.flash = W.Solid(fx, "OVERLAY", 1, 1, 1, 0, 6)
    self.flash:SetAllPoints(board)
    self.shout = W.Text(fx, 34, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", board, "TOPLEFT", FW / 2, -250)
    self.shout:Hide()
    self.shoutT = 0

    board:EnableMouse(true)
    board:SetScript("OnMouseUp", function(_, button) W.Guard("Orbs", self.MouseUp, self, button) end)

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
    self.swapButton = W.Button(bar, 70, 26, "Swap", "ghost")
    self.swapButton:SetPoint("LEFT", self.restartButton, "RIGHT", 6, 0)
    self.swapButton:SetScript("OnClick", function() self:Swap() end)

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.boardPanel = NS.NewBoardPanel(f, holder)

    self.game = Orbs.New()
    self.angle = pi / 2
    self.slide = 0
    self.queue = {}
    f:SetScript("OnUpdate", function(_, el) W.Guard("Orbs", self.OnUpdate, self, el) end)
    if not (self.db.run and self.game:Restore(self.db.run)) then
        self.db.run = nil
        self.game = Orbs.New()
    end
    self.lastShift = self.game.shift
    self:SyncAll()
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Orbs on the board
---------------------------------------------------------------------------
function UI:Place(t, x, y, size, alpha)
    t:ClearAllPoints()
    t:SetPoint("CENTER", self.board, "TOPLEFT", x, -y)
    t:SetSize(size, size)
    t:SetAlpha(alpha or 1)
end

-- make the board show exactly what the engine holds
function UI:SyncAll()
    local g = self.game
    local seen = {}
    for _, o in ipairs(g:Cells()) do
        local k = o.r * 100 + o.c
        seen[k] = true
        local s = self.sprites[k]
        if not s then
            s = table.remove(self.spritePool)
            if not s then s = { t = self.board:CreateTexture(nil, "ARTWORK", nil, 5) } end
            self.sprites[k] = s
        end
        if s.color ~= o.color then s.color = o.color; s.t:SetTexture(Tex(o.color)) end
        s.x, s.y = g:XY(o.r, o.c)
        s.t:Show()
    end
    for k, s in pairs(self.sprites) do
        if not seen[k] then
            s.t:Hide(); s.color = nil
            self.sprites[k] = nil
            self.spritePool[#self.spritePool + 1] = s
        end
    end
    self.traceKey = nil
end

-- a free-moving orb (flying, bursting or falling)
function UI:Loose(color, x, y)
    local o = table.remove(self.loosePool)
    if not o then o = { t = self.fx:CreateTexture(nil, "ARTWORK", nil, 2) } end
    o.t:SetTexture(Tex(color))
    o.color, o.x, o.y, o.vx, o.vy, o.wait, o.life, o.kind, o.scale, o.alpha = color, x, y, 0, 0, 0, 0, nil, 1, 1
    o.t:Show()
    self.loose[#self.loose + 1] = o
    return o
end

function UI:DrawOrbs(el)
    if self.slide ~= 0 then
        self.slide = self.slide * max(0, 1 - el * 9)
        if abs(self.slide) < 0.5 then self.slide = 0 end
    end
    local shake = 0
    if (self.shakeT or 0) > 0 then
        self.shakeT = self.shakeT - el
        shake = sin(self.shakeT * 70) * 3 * min(1, self.shakeT * 4)
    end
    for _, s in pairs(self.sprites) do
        -- (a row still above the ceiling is not drawn: it slides in from under the frame)
        local y = s.y + self.slide
        self:Place(s.t, s.x + shake, y, D, y < Orbs.R - 3 and 0 or 1)
    end
    local i = 1
    while i <= #self.loose do
        local o = self.loose[i]
        local done = false
        if o.wait > 0 then
            o.wait = o.wait - el
        elseif o.kind == "pop" then
            o.life = o.life + el
            local k = o.life / 0.16
            o.scale, o.alpha = 1 + 0.5 * k, 1 - k
            if not o.burst then
                o.burst = true
                self:Burst(o.x, o.y, Orbs.KINDS[o.color].color, 7, 150)
                W.SFX("pop" .. (1 + (o.n or 0) % 8), 0.02)
            end
            done = k >= 1
        elseif o.kind == "fall" then
            o.vy = o.vy + 1500 * el
            o.x, o.y = o.x + o.vx * el, o.y + o.vy * el
            if o.x < Orbs.R then o.x = Orbs.R; o.vx = -o.vx * 0.6 elseif o.x > FW - Orbs.R then o.x = FW - Orbs.R; o.vx = -o.vx * 0.6 end
            if o.y > FH - 30 then
                self:Burst(o.x, FH - 30, Orbs.KINDS[o.color].color, 5, 120)
                W.SFX(("peg%02d"):format(min(25, 4 + (o.n or 0) * 2)), 0.03)
                done = true
            end
        end
        if done then
            o.t:Hide(); o.burst = nil
            table.remove(self.loose, i)
            self.loosePool[#self.loosePool + 1] = o
        else
            self:Place(o.t, o.x, o.y, D * o.scale, o.alpha)
            i = i + 1
        end
    end
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
function UI:Burst(x, y, col, n, speed)
    if NS.db.settings.reducedMotion then n = floor(n / 3) end
    for _ = 1, n do
        self.partIdx = self.partIdx % #self.parts + 1
        local p = self.parts[self.partIdx]
        local a = math.random() * 2 * pi
        local v = (0.3 + math.random() * 0.7) * (speed or 160)
        p.x, p.y = x, y
        p.vx, p.vy = cos(a) * v, sin(a) * v
        p.life = 0.35 + math.random() * 0.3
        p.max = p.life
        p.size = 8 + math.random() * 10
        p.t:SetVertexColor(col[1], col[2], col[3])
        p.t:Show()
    end
end

function UI:Float(x, y, text, col)
    for _, f in ipairs(self.floats) do
        if f.life <= 0 then
            f.x, f.y, f.life = x, y, 1.0
            f.t:SetText(text)
            f.t:SetTextColor(col[1], col[2], col[3])
            f.t:Show()
            return
        end
    end
end

function UI:Shout(text, col)
    self.shout:SetText(text)
    self.shout:SetTextColor(col[1], col[2], col[3])
    self.shout:Show()
    self.shoutT = 1.3
end

function UI:Flash(r, g, b, a)
    if NS.db.settings.reducedMotion then a = a * 0.4 end
    self.flash:SetColorTexture(r, g, b, a)
    self.flashA = a
end

function UI:UpdateFX(el)
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then p.t:Hide()
            else
                p.vy = p.vy + 300 * el
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local k = p.life / p.max
                self:Place(p.t, p.x, p.y, p.size * (0.5 + k), k)
            end
        end
    end
    for _, f in ipairs(self.floats) do
        if f.life > 0 then
            f.life = f.life - el
            if f.life <= 0 then f.t:Hide()
            else
                f.y = f.y - 40 * el
                f.t:ClearAllPoints()
                f.t:SetPoint("CENTER", self.board, "TOPLEFT", f.x, -f.y)
                f.t:SetAlpha(min(1, f.life * 2))
            end
        end
    end
    if self.flashA and self.flashA > 0 then
        self.flashA = max(0, self.flashA - el * 1.6)
        self.flash:SetAlpha(self.flashA)
    end
    if self.shoutT > 0 then
        self.shoutT = self.shoutT - el
        self.shout:SetAlpha(min(1, self.shoutT * 2.5))
        if self.shoutT <= 0 then self.shout:Hide() end
    end
end

---------------------------------------------------------------------------
-- Aiming and firing
---------------------------------------------------------------------------
function UI:IsBusy() return self.fly ~= nil or #self.queue > 0 end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.boardPanel:IsShown()
end

function UI:Cursor()
    local x, y = GetCursorPosition()
    local s = self.board:GetEffectiveScale()
    local l, t = self.board:GetLeft(), self.board:GetTop()
    if not (l and t) then return end
    return x / s - l, t - y / s
end

function UI:UpdateAim()
    local g = self.game
    local aiming = g.state == "aim" and not self.fly and not self:Paused()
    if aiming and self.board:IsMouseOver() then
        local mx, my = self:Cursor()
        if mx and my < CY - 6 then self.angle = Orbs.ClampAim(atan2(CY - my, mx - CX)) end
    end
    -- (the cannon is painted muzzle down; it sits behind the orb and swings to the aim)
    if self.barrel.SetRotation then self.barrel:SetRotation(self.angle + pi / 2) end
    self.barrel:ClearAllPoints()
    self.barrel:SetPoint("CENTER", self.board, "TOPLEFT", CX - cos(self.angle) * 30, -(CY + sin(self.angle) * 30))
    if not aiming then
        for _, t in ipairs(self.dots) do t:Hide() end
        return
    end
    local key = floor(self.angle * 2000)
    if key ~= self.traceKey then
        self.traceKey = key
        self.trace = g:Trace(self.angle)
    end
    -- dots along the first leg and a short way past the first bank: the rest is yours to judge
    local pts = self.trace.pts
    local col = Orbs.KINDS[g.cur].color
    local first = sqrt((pts[2][1] - pts[1][1]) ^ 2 + (pts[2][2] - pts[1][2]) ^ 2)
    local reach = #pts > 2 and first + 96 or first - 12
    local n = 0
    local d = 28 + ((self.rt or 0) * 30) % 20
    local seg, base = 1, 0
    local segLen = first
    while d < reach and n < #self.dots do
        while d > base + segLen and seg < #pts - 1 do
            base = base + segLen
            seg = seg + 1
            segLen = sqrt((pts[seg + 1][1] - pts[seg][1]) ^ 2 + (pts[seg + 1][2] - pts[seg][2]) ^ 2)
        end
        if d > base + segLen then break end
        local k = (d - base) / max(1, segLen)
        n = n + 1
        local dot = self.dots[n]
        dot:SetVertexColor(col[1], col[2], col[3])
        local past = d - first
        self:Place(dot, pts[seg][1] + (pts[seg + 1][1] - pts[seg][1]) * k, pts[seg][2] + (pts[seg + 1][2] - pts[seg][2]) * k,
            past > 0 and 5 or 6, past > 0 and 0.6 * (1 - past / 100) or 0.85)
        dot:Show()
        d = d + 20
    end
    for i = n + 1, #self.dots do self.dots[i]:Hide() end
end

function UI:Save()
    local g = self.game
    if g.mode == "daily" then
        local d = self:Daily()
        if g.day == d.date then d.run = g:Serialize() end
    else
        self.db.run = g:Serialize()
    end
end

function UI:Fire()
    local g = self.game
    if self.fly or self:Paused() or g.state ~= "aim" then return end
    self:FinishQueue()
    local color = g.cur
    local res = g:Fire(self.angle)
    if not res then return end
    -- saved the moment the shot is made: closing the window mid-flight loses nothing
    self:Save()
    local o = self:Loose(color, CX, CY)
    o.kind = "fly"
    self.fly = { res = res, orb = o, seg = 1, shot = color }
    self.loaded:Hide(); self.loadedGlow:Hide()
    W.SFX("launch", 0.05)
end

function UI:StepFly(el)
    local f = self.fly
    if not f then return end
    local move = FLY_SPEED * el
    local pts = f.res.pts
    local o = f.orb
    while move > 0 and f.seg < #pts do
        local tx, ty = pts[f.seg + 1][1], pts[f.seg + 1][2]
        local dx, dy = tx - o.x, ty - o.y
        local len = sqrt(dx * dx + dy * dy)
        if len <= move then
            o.x, o.y = tx, ty
            move = move - len
            f.seg = f.seg + 1
            if f.seg < #pts then W.SFX("knock", 0.03) end
        else
            o.x, o.y = o.x + dx / len * move, o.y + dy / len * move
            move = 0
        end
    end
    if f.seg >= #pts then self:Land() end
end

-- the shot has arrived: burst, drop, and bring the board up to date
function UI:Land()
    local f = self.fly
    self.fly = nil
    local res, g = f.res, self.game
    -- the flying orb is done with
    for i, o in ipairs(self.loose) do
        if o == f.orb then
            o.t:Hide()
            table.remove(self.loose, i)
            self.loosePool[#self.loosePool + 1] = o
            break
        end
    end
    -- where things were when the shot was fired (a new row or a new wave moves the cells)
    local shift0 = self.lastShift or g.shift
    local function XY0(r, c) return (((r + shift0) % 2 == 1) and Orbs.R or D) + (c - 1) * D, Orbs.R + (r - 1) * ROWH end
    local lx, ly = XY0(res.r, res.c)
    local maxWait = 0
    for i, p in ipairs(res.popped) do
        local x, y = XY0(p.r, p.c)
        local o = self:Loose(p.color, x, y)
        o.kind, o.wait, o.n = "pop", p.d * 0.045, i
        if o.wait > maxWait then maxWait = o.wait end
    end
    if res.kind == "bomb" then
        self:Burst(lx, ly, { 1, 0.6, 0.2 }, 36, 300)
        self:Flash(1, 0.5, 0.2, 0.4)
        self.shakeT = 0.3
        W.SFX("rb_stomp")
    end
    for i, p in ipairs(res.dropped) do
        local x, y = XY0(p.r, p.c)
        local o = self:Loose(p.color, x, y)
        o.kind, o.wait, o.n = "fall", maxWait + 0.08 + i * 0.012, i
        o.vx, o.vy = (x - lx) * 0.8 + (math.random() - 0.5) * 60, -60 - math.random() * 80
    end
    if res.gained > 0 then
        local text = "+" .. W.Commas(res.gained)
        if (res.mult or 1) > 1 then text = text .. ("  x%.1f"):format(res.mult) end
        self:Float(lx, max(40, ly - 8), text, { 1, 0.92, 0.6 })
    else
        W.SFX("knock", 0.05)
    end
    if #res.dropped >= 10 then self:Shout("AVALANCHE!", { 0.7, 0.9, 1 })
    elseif #res.dropped >= 5 then self:Shout(#res.dropped .. " down!", { 0.7, 0.9, 1 }) end
    if res.award == "bomb" then
        self.queue[#self.queue + 1] = { wait = 0.5, fn = function() self:Shout("Goblin Bomb loaded!", { 1, 0.6, 0.3 }); W.SFX("power") end }
    elseif res.award == "pearl" then
        self.queue[#self.queue + 1] = { wait = 0.5, fn = function() self:Shout("Prismatic Orb loaded!", { 0.7, 1, 0.95 }); W.SFX("multiplier") end }
    end
    self:SyncAll()
    self.lastShift = g.shift
    if res.rowAdded then
        self.slide = -ROWH
        self.shakeT = 0.25
        W.SFX("rb_rumble")
    end
    if res.cleared then
        self:Flash(0.7, 0.9, 1, 0.4)
        W.SFX("win")
        if res.wave then
            self:Shout(("Wave %d!"):format(g.level), { 1, 0.86, 0.4 })
            self.slide = -g:Rows() * ROWH
        end
    end
    if g.state ~= "aim" then
        self.queue[#self.queue + 1] = { wait = maxWait + 0.9, fn = function() self:ShowResult() end }
    end
    self:RefreshHUD()
end

function UI:StepQueue(el)
    local q = self.queue
    local i = 1
    while i <= #q do
        q[i].wait = q[i].wait - el
        if q[i].wait <= 0 then
            local it = table.remove(q, i)
            it.fn()
        else
            i = i + 1
        end
    end
end

function UI:FinishQueue()
    local q = self.queue
    self.queue = {}
    for _, it in ipairs(q) do it.fn() end
end

-- settle everything at once (the window is closing, or a panel is opening)
function UI:Settle()
    if self.fly then self:Land() end
    for _, o in ipairs(self.loose) do
        o.t:Hide(); o.burst = nil
        self.loosePool[#self.loosePool + 1] = o
    end
    self.loose = {}
    self.slide, self.shakeT = 0, 0
    self:FinishQueue()
end

function UI:Swap()
    if self.fly or self:Paused() then return end
    if self.game:Swap() then
        W.SFX("pop2", 0.05)
        self.traceKey = nil
        self:Save()
        self:RefreshHUD()
    end
end

function UI:MouseUp(button)
    if self:Paused() or self.game.state ~= "aim" then return end
    if button == "RightButton" then self:Swap(); return end
    if button ~= "LeftButton" then return end
    local mx, my = self:Cursor()
    if not mx or my >= CY - 6 then return end
    self.angle = Orbs.ClampAim(atan2(CY - my, mx - CX))
    self:Fire()
end

function UI:OnKey(key) return false end

---------------------------------------------------------------------------
-- Frame update, HUD
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    if not self:Paused() then
        self:StepFly(el)
        self:StepQueue(el)
    end
    self:UpdateAim()
    self:DrawOrbs(el)
    self:UpdateFX(el)
    local g = self.game
    -- the line glows as the orbs come down to it
    local danger = g.state == "aim" and max(0, g:Rows() - (Orbs.MAXROW - 3)) / 3 or 0
    local a = 0.4 + danger * (0.35 + 0.25 * sin(self.rt * 6))
    for _, t in ipairs(self.dashes) do t:SetAlpha(a) end
    if self.loaded:IsShown() then
        self.loadedGlow:SetAlpha(0.35 + 0.15 * sin(self.rt * 4))
    end
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.25; self:RefreshHUD() end
end

function UI:RefreshHUD()
    local g = self.game
    if not g or not self.scoreText then return end
    local playing = g.state ~= "idle"
    self.scoreText:SetText(playing and W.Commas(g.score or 0) or "")
    if not playing then
        self.modeText:SetText("ORB CANNON")
        self.nameText:SetText("Load the cannon")
        self.rightLabel:SetText("BEST")
        self.rightValue:SetText(self.db.best > 0 and W.Short(self.db.best) or "-")
    elseif g.mode == "daily" then
        local d = self:Daily()
        self.modeText:SetText("DAILY SALVO")
        self.nameText:SetText(("Shot %d"):format((g.shots or 0) + (g.state == "aim" and 1 or 0)))
        self.rightLabel:SetText("TODAY'S BEST")
        self.rightValue:SetText((d.best or 0) > 0 and W.Short(d.best) or "-")
    else
        self.modeText:SetText("ORB CANNON")
        self.nameText:SetText(("Wave %d"):format(g.level or 1))
        self.rightLabel:SetText("BEST")
        local top = max(self.db.best, g.score or 0)
        self.rightValue:SetText(top > 0 and W.Short(top) or "-")
    end
    local aim = g.state == "aim"
    self.loaded:SetShown(aim and not self.fly)
    self.loadedGlow:SetShown(aim and not self.fly)
    self.nextButton:SetShown(aim)
    self.nextLabel:SetShown(aim)
    self.pipLabel:SetShown(aim)
    if aim then
        self.loaded:SetTexture(Tex(g.cur))
        local c = Orbs.KINDS[g.cur].color
        self.loadedGlow:SetVertexColor(c[1], c[2], c[3])
        self.nextButton.icon:SetTexture(Tex(g.nxt))
        local left = g.limit - g.misses
        self.pipLabel:SetText(left == 1 and "LAST MISS" or (left .. " MISSES LEFT"))
        self.pipLabel:SetTextColor(left == 1 and 1 or 0.75, left == 1 and 0.4 or 0.78, left == 1 and 0.3 or 0.9)
        local x0 = CX + 104 - (g.limit - 1) * 7
        for i, t in ipairs(self.pips) do
            if i <= g.limit then
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.board, "TOPLEFT", x0 + (i - 1) * 14, -(CY + 2))
                if i <= left then t:SetVertexColor(0.55, 0.85, 1, 1) else t:SetVertexColor(0.9, 0.25, 0.2, 0.55) end
                t:Show()
            else
                t:Hide()
            end
        end
        self.streakText:SetText((g.streak or 0) >= 2 and ("Streak %d  x%.1f"):format(g.streak, 1 + 0.1 * min(10, g.streak)) or "")
    else
        for _, t in ipairs(self.pips) do t:Hide() end
        self.streakText:SetText("")
    end
    self.restartButton:SetShown(playing)
    self.swapButton:SetShown(aim)
end

---------------------------------------------------------------------------
-- Starting, ending
---------------------------------------------------------------------------
local function NewSeed()
    local t = (time and time() or 0) % 1000000
    local ms = floor(((GetTime and GetTime() or 0) % 1000) * 1000)
    return t * 83 + ms + 1
end

function UI:Begin(mode, opts)
    opts = opts or {}
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.queue = {}
    self:Settle()
    local g = self.game
    if mode == "daily" then
        local d = self:Daily()
        if not (not opts.restart and d.run and g:Restore(d.run) and g.day == d.date) then
            g:Start("daily", { day = d.date })
            d.tries = (d.tries or 0) + 1
        end
    elseif not (opts.continue and self.db.run and g:Restore(self.db.run)) then
        g:Start("barrage", { seed = NewSeed() })
    end
    self.counted = false
    self.angle = pi / 2
    self.lastShift = g.shift
    self:Save()
    self:SyncAll()
    self.slide = -g:Rows() * ROWH
    W.SFX("launch")
    self:RefreshHUD()
end

-- a new game from the menu: ask first if a good one is still going
function UI:NewGame()
    if self.menu:IsShown() then self.menu:Hide() end
    local run = self.db.run
    if run and (run.score or 0) > 0 then
        self.card:Open({
            title = "Start a new game?", color = TINT, center = true,
            body = ("The game you have going (|cffffffff%s|r points, wave %d) will be over."):format(W.Commas(run.score), run.level or 1),
            buttons = { { "New game", function() self:Begin("barrage") end }, { "Keep it", function() if self.game.state ~= "aim" then self:ShowMenu() end end, "ghost" } },
        })
    else
        self:Begin("barrage")
    end
end

function UI:Restart()
    local g = self.game
    if g.state == "idle" then return end
    local again = function() if g.mode == "daily" then self:Begin("daily", { restart = true }) else self:Begin("barrage") end end
    if g.state == "aim" and (g.score or 0) > 0 then
        self.card:Open({
            title = "Start again?", color = TINT, center = true,
            body = g.mode == "daily" and "Today's board comes back as it started. Your best score of the day is the one that counts."
                or ("This game (|cffffffff%s|r points) will be over."):format(W.Commas(g.score)),
            buttons = { { "Start again", again }, { "Keep playing", function() end, "ghost" } },
        })
    else
        again()
    end
end

function UI:ShowResult()
    local g = self.game
    local db = self.db
    if (g.bestDrop or 0) > db.bestDrop then db.bestDrop = g.bestDrop end
    if g.mode == "daily" then
        local d = self:Daily()
        local today = g.day == d.date
        local won = g.state == "won"
        local newBest = today and g.score > (d.best or 0)
        if newBest then d.best, d.detail = g.score, won and (g.shots .. " shots") or "not cleared" end
        if today then
            d.run = nil
            if won then d.cleared = true end
        end
        if not self.counted then
            self.counted = true
            db.games = db.games + 1
            if today and (d.tries or 0) <= 1 then db.dailies = db.dailies + 1 end
        end
        if today and (d.best or 0) > 0 then NS.Social:Submit("obd", d.date, d.best, d.detail or "") end
        if not won then W.SFX("lose") end
        local rk, n = NS.Social:Rank("obd", d.date, "realm")
        self.card:Open({
            title = won and "Board cleared!" or "The orbs reached the line", color = won and COLORS.gold or TINT, center = true,
            body = ("|cffffffff%s|r points in %d shots%s\n\nToday's best: %s%s"):format(W.Commas(g.score), g.shots,
                newBest and "  |cff80ff80(new best!)|r" or "", W.Commas(d.best or 0), (rk and n > 1) and ("\nRank #%d of %d"):format(rk, n) or ""),
            buttons = {
                { "Again", function() self:Begin("daily", { restart = true }) end },
                { "Leaderboard", function() self:ShowBoard("obd") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    else
        local newBest = g.score > db.best
        if newBest then db.best = g.score end
        if (g.level or 1) > db.bestWave then db.bestWave = g.level end
        db.run = nil
        if not self.counted then self.counted = true; db.games = db.games + 1 end
        NS.Social:SubmitBest("ob", db.best, ("Wave %d"):format(db.bestWave))
        W.SFX(newBest and "win" or "lose")
        self.card:Open({
            title = "The orbs reached the line", color = newBest and COLORS.gold or TINT, center = true,
            body = ("|cffffffff%s|r points%s\nWave %d, %d shots\nBiggest drop: %d orbs"):format(W.Commas(g.score),
                newBest and "  |cff80ff80(new best!)|r" or "", g.level or 1, g.shots or 0, g.bestDrop or 0),
            buttons = {
                { "Again", function() self:Begin("barrage") end },
                { "Leaderboard", function() self:ShowBoard("ob") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Menu, boards, help
---------------------------------------------------------------------------
function UI:OnShow()
    self:RefreshHUD()
    if not self.db.seenHelp then
        self.db.seenHelp = true
        if self.game.state ~= "aim" then self:ShowHelp(); return end
    end
    if self.game.state ~= "aim" and not self.card:IsShown() and not self.boardPanel:IsShown() and #self.queue == 0 then self:ShowMenu() end
end

function UI:OnHide()
    self:Settle()
end

function UI:ShowMenu()
    self:Settle()
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local g = self.game
    local d = self:Daily()
    local playing = g.state == "aim"
    local run = db.run
    local lines = {
        ("Best |cffffffff%s|r     Furthest wave |cffffcc40%s|r     Biggest drop |cffffcc40%s|r"):format(db.best > 0 and W.Commas(db.best) or "-",
            db.bestWave > 0 and db.bestWave or "-", db.bestDrop > 0 and db.bestDrop or "-"),
        ("Today's Daily Salvo: %s"):format((d.best or 0) > 0 and ("best |cffffffff" .. W.Commas(d.best) .. "|r" .. (d.cleared and " (cleared)" or "")) or (d.run and "under way" or "not played yet")),
    }
    if run and not (playing and g.mode == "barrage") then
        lines[#lines + 1] = ("A game is waiting: |cffffffff%s|r points, wave %d"):format(W.Commas(run.score or 0), run.level or 1)
    end
    local rl = NS.Social:RankLine("obd", d.date)
    if rl then lines[#lines + 1] = "Daily: " .. rl end
    local buttons = {}
    if playing then buttons[#buttons + 1] = { "Resume", function() end } end
    if run and not (playing and g.mode == "barrage") then
        buttons[#buttons + 1] = { "Continue game", function() self:Begin("barrage", { continue = true }) end }
    end
    buttons[#buttons + 1] = { "New game", function() self:NewGame() end, (playing or run) and "ghost" or nil }
    if not (playing and g.mode == "daily") then
        buttons[#buttons + 1] = { d.run and "Continue daily" or "Daily Salvo", function() self:Begin("daily") end }
    end
    buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end }
    self.menu:Open({
        title = "Orb Cannon", sub = "Fire, match three, bring them down", icon = W.MEDIA .. "ball_arcane",
        color = TINT, lines = lines, buttons = buttons, options = NS.CommonOptions(),
    })
end

function UI:ShowBoard(which)
    self:Settle()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    self.boardPanel:Open({
        views = {
            { label = "Orb Cannon", game = "ob", periods = true, title = "Orb Cannon", sub = "Best scores from a single game" },
            { label = "Daily", game = "obd", periods = false, period = "day", title = "Daily Salvo", sub = "Today's board is the same for everyone" },
        },
        view = which == "obd" and 2 or 1,
        empty = "No scores here yet.",
        fmt = function(e) return W.Commas(e.s), e.d or "" end,
        onClose = function() if self.game.state ~= "aim" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    self:Settle()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.card:Open({
        title = "Orb Cannon", color = TINT,
        body = table.concat({
            "|cffffcc40Aim|r with the pointer and |cffffcc40click|r to fire. Orbs bank off the side walls.",
            "",
            "|cffffcc40Three or more|r of a kind that touch burst. Anything left hanging from nothing |cffffcc40falls|r, and falling orbs are worth far more: cut a big cluster off at the top.",
            "",
            "|cffffcc40Right-click|r (or click the waiting orb) to swap it into the cannon.",
            "",
            "A shot that bursts nothing is a |cffffcc40miss|r. Run out of misses and the ceiling comes down a row. It is over when the orbs reach the red line.",
            "",
            "Bursting shots in a row build a |cffffcc40streak|r multiplier. Four in a row loads a |cffb3fff2Prismatic Orb|r (matches anything); dropping six at once loads a |cffff9a4dGoblin Bomb|r.",
            "",
            "|cffffcc40Daily Salvo|r: one board for everyone. Clear it in as few shots as you can.",
        }, "\n"),
        buttons = { { "Load the cannon", function() if self.game.state ~= "aim" then self:ShowMenu() end end } },
    })
end

function UI:Banner() end
