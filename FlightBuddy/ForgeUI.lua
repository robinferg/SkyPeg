-- Flight Buddy :: ForgeUI.lua
-- The Great Forge: the screen. A stone anvil of metal bars in front of the Great Forge of
-- Ironforge, the smelting ladder underneath, and the animation that plays back each move the
-- engine (Forge.lua) resolves. Slide with the arrow keys or WASD, by dragging across the anvil,
-- or by clicking near one of its edges.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Forge = NS.Forge
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

local UI = {}
NS.ForgeUI = UI

local GEMART = W.MEDIA .. "gems\\"
local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local N = Forge.N
local BX, BY = 24, 10                       -- board offset inside the 480x560 holder
local BW = 432
local CELL = BW / N                         -- 108
local TILE = 98
local SLIDE_T, POP_T, DROP_T = 0.10, 0.22, 0.16
local TINT = { 1.0, 0.62, 0.25 }            -- forge orange, for titles and panels

local KEYDIR = { UP = "up", DOWN = "down", LEFT = "left", RIGHT = "right", W = "up", S = "down", A = "left", D = "right" }
local VEC = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, 1 }, down = { 0, -1 } }

local function Today() return NS.Social.Today() end

-- the game's own picture of a bar, by item; the named icon is the fallback
local iconCache = {}
function UI.BarIcon(tier)
    local bar = Forge.Bar(tier)
    local tex = iconCache[bar.key]
    if tex then return tex end
    if C_Item and C_Item.GetItemIconByID then tex = C_Item.GetItemIconByID(bar.item) end
    if not tex and GetItemIcon then tex = GetItemIcon(bar.item) end
    if not tex or tex == 0 or tex == 134400 then tex = "Interface\\Icons\\" .. bar.icon end   -- 134400 is the red question mark
    iconCache[bar.key] = tex
    return tex
end

local function BarName(tier) return Forge.Bar(tier).name end

function UI:Init(db)
    self.db = db
    db.best = db.best or 0                -- best free forge score
    db.bestBar = db.bestBar or 0          -- highest bar ever smelted
    db.games = db.games or 0
    db.arcanite = db.arcanite or 0        -- forges that reached Arcanite
    db.daily = db.daily or {}
    db.dailies = db.dailies or 0
    if db.keys == nil then db.keys = true end
end

function UI:Daily()
    local d = self.db.daily
    if d.date ~= Today() then d.date, d.best, d.tries, d.run, d.bar = Today(), 0, 0, nil, 0 end
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

    -- HUD: what you're playing, the score, and your best
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

    -- the forge hall behind, the anvil top in front
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(480, 560)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    self.holder = holder
    local hall = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    hall:SetTexture(W.MEDIA .. "pbg_forge_anvil")
    hall:SetAllPoints()
    hall:SetTexCoord(0.03, 0.97, 0, 1)
    hall:SetVertexColor(0.62, 0.56, 0.56)
    local trayFrame = CreateFrame("Frame", nil, holder)
    trayFrame:SetSize(BW + 20, BW + 16)
    trayFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", BX - 10, -BY + 8)
    W.Nine(trayFrame, "wood", 16, "BACKGROUND", -6)

    local board = CreateFrame("Frame", nil, holder)
    board:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    board:SetSize(BW, BW)
    board:SetFrameLevel(holder:GetFrameLevel() + 2)
    self.board = board
    -- the anvil top: dark stone with a warm glow from the forge behind it
    local slab = W.Solid(board, "BACKGROUND", 0.085, 0.07, 0.07, 0.96, 0)
    slab:SetAllPoints()
    local ember = board:CreateTexture(nil, "BACKGROUND", nil, 0)
    ember:SetTexture(W.MEDIA .. "glow")
    ember:SetBlendMode("ADD")
    ember:SetVertexColor(1, 0.42, 0.12, 0.16)
    ember:SetPoint("CENTER", board, "CENTER", 0, 0)
    ember:SetSize(BW * 1.5, BW * 1.5)
    for r = 1, N do
        for c = 1, N do
            local s = board:CreateTexture(nil, "BACKGROUND", nil, 1)
            s:SetTexture(W.MEDIA .. "tile")
            s:SetSize(TILE, TILE)
            s:SetVertexColor(0.21, 0.185, 0.18, 0.9)
            s:SetPoint("CENTER", board, "TOPLEFT", (c - 0.5) * CELL, -(r - 0.5) * CELL)
        end
    end
    self.pool, self.live = {}, {}

    -- effects above the bars
    local fx = CreateFrame("Frame", nil, holder)
    fx:SetAllPoints(board)
    fx:SetFrameLevel(board:GetFrameLevel() + 6)
    fx:EnableMouse(false)
    self.fx = fx
    self.parts = {}
    for i = 1, 90 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(W.MEDIA .. "sparkle")
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.floats = {}
    for i = 1, 8 do
        local t = W.Text(fx, 20, FONT_SHOUT, "OUTLINE")
        t:Hide()
        self.floats[i] = { t = t, life = 0 }
    end
    self.flash = W.Solid(fx, "OVERLAY", 1, 1, 1, 0, 6)
    self.flash:SetAllPoints(board)
    self.shout = W.Text(fx, 34, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", board, "CENTER", 0, 30)
    self.shout:SetTextColor(1, 0.86, 0.4)
    self.shout:Hide()
    self.shoutT = 0

    -- the smelting ladder under the anvil
    local tray = CreateFrame("Frame", nil, holder)
    tray:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 10, 6)
    tray:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -10, 6)
    tray:SetHeight(100)
    tray:SetFrameLevel(holder:GetFrameLevel() + 3)
    W.Nine(tray, "parch", 16, "BACKGROUND", -4)
    self.tray = tray
    self.ladderTitle = W.Text(tray, 14, W.FONT_TITLE)
    self.ladderTitle:SetPoint("TOPLEFT", 18, -12)
    self.ladderTitle:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
    self.ladderTitle:SetShadowColor(0, 0, 0, 0)
    self.ladderSub = W.Text(tray, 10, W.FONT)
    self.ladderSub:SetPoint("BOTTOMLEFT", 18, 12)
    self.ladderSub:SetTextColor(0.42, 0.3, 0.18)
    self.ladderSub:SetShadowColor(0, 0, 0, 0)
    self.ladder = {}
    for i = 1, Forge.GOAL do
        local b = CreateFrame("Button", nil, tray)
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 31, -34)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(UI.BarIcon(i))
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.ring = b:CreateTexture(nil, "OVERLAY")
        b.ring:SetTexture(GEMART .. "gem_select")
        b.ring:SetPoint("CENTER")
        b.ring:SetSize(36, 36)
        b.ring:Hide()
        b:SetScript("OnEnter", function(btn)
            if not GameTooltip then return end
            GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
            GameTooltip:SetText(BarName(i) .. " Bar", 1, 0.82, 0.38)
            GameTooltip:AddLine(i == 1 and "Drops onto the anvil after every move." or ("Smelted from two " .. BarName(i - 1) .. " Bars."), 1, 1, 1, true)
            GameTooltip:AddLine(("Worth %s points when smelted."):format(W.Commas(Forge.Value(i))), 0.62, 0.88, 0.54)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.ladder[i] = b
    end
    self.movesLabel = W.Text(tray, 11, W.FONT)
    self.movesLabel:SetPoint("TOPRIGHT", -20, -12)
    self.movesLabel:SetTextColor(0.42, 0.3, 0.18)
    self.movesLabel:SetShadowColor(0, 0, 0, 0)
    self.movesValue = W.Text(tray, 38, FONT_SHOUT)
    self.movesValue:SetPoint("TOP", self.movesLabel, "BOTTOM", 0, -4)
    self.movesValue:SetTextColor(0.55, 0.18, 0.08)
    self.movesValue:SetShadowColor(0, 0, 0, 0)

    -- input: drag across the anvil, or click near an edge
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function(_, button) W.Guard("Forge", self.MouseDown, self, button) end)
    board:SetScript("OnMouseUp", function(_, button) W.Guard("Forge", self.MouseUp, self, button) end)

    -- bottom bar
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
    self.undoButton = W.Button(bar, 100, 26, "Reheat", "ghost")
    self.undoButton:SetPoint("LEFT", self.restartButton, "RIGHT", 6, 0)
    self.undoButton:SetScript("OnClick", function() self:Reheat() end)
    self.undoButton:HookScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetText("Reheat", 1, 0.82, 0.38)
        GameTooltip:AddLine(("Take back your last move. %d to a forge."):format(Forge.UNDOS), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.undoButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.boardPanel = NS.NewBoardPanel(f, holder)

    self.game = Forge.New()
    f:SetScript("OnUpdate", function(_, el) W.Guard("Forge", self.OnUpdate, self, el) end)
    -- pick the forge up where it was left
    if not (self.db.run and self.game:Restore(self.db.run) and self.game.state == "play") then
        self.db.run = nil
        self.game = Forge.New()
    end
    self.shownBest = self.game.best or 0
    self:SyncAll()
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Bars on the anvil
---------------------------------------------------------------------------
local function CellXY(r, c) return (c - 0.5) * CELL, -(r - 0.5) * CELL end

function UI:Sprite(id, tier)
    local s = self.live[id]
    if not s then
        s = table.remove(self.pool)
        if not s then
            local b = self.board
            s = {}
            s.glow = b:CreateTexture(nil, "ARTWORK", nil, 0)
            s.glow:SetTexture(W.MEDIA .. "glow")
            s.glow:SetBlendMode("ADD")
            s.plate = b:CreateTexture(nil, "ARTWORK", nil, 1)
            s.plate:SetTexture(W.MEDIA .. "tile")
            s.icon = b:CreateTexture(nil, "ARTWORK", nil, 3)
            s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            s.rim = b:CreateTexture(nil, "ARTWORK", nil, 4)
            s.rim:SetTexture(GEMART .. "gem_select")
            s.name = W.Text(b, 11, W.FONT, nil, "OVERLAY")
            s.val = W.Text(b, 11, W.FONT_NUM, nil, "OVERLAY")
        end
        s.id = id
        s.scaleK, s.alpha, s.pop, s.drop, s.wait = 1, 1, 0, 0, 0
        s.fx, s.fy, s.tx, s.ty, s.into = nil, nil, nil, nil, nil
        self.live[id] = s
    end
    if tier and s.tier ~= tier then
        s.tier = tier
        local bar = Forge.Bar(tier)
        local c = bar.color
        s.plate:SetVertexColor(c[1] * 0.60 + 0.03, c[2] * 0.60 + 0.03, c[3] * 0.60 + 0.03)
        s.rim:SetVertexColor(min(1, c[1] * 0.7 + 0.35), min(1, c[2] * 0.7 + 0.35), min(1, c[3] * 0.7 + 0.35))
        s.glow:SetVertexColor(c[1], c[2], c[3])
        s.icon:SetTexture(UI.BarIcon(tier))
        s.name:SetText(bar.short or bar.name)
        s.val:SetText(("%d"):format(Forge.Value(tier)))
        s.val:SetTextColor(1, 0.95, 0.82, 0.8)
    end
    s.plate:Show(); s.icon:Show(); s.rim:Show(); s.name:Show(); s.val:Show()
    s.glow:SetShown((s.tier or 0) >= 8)
    return s
end

function UI:Release(id)
    local s = self.live[id]
    if not s then return end
    s.plate:Hide(); s.icon:Hide(); s.rim:Hide(); s.name:Hide(); s.val:Hide(); s.glow:Hide()
    s.tier = nil
    self.live[id] = nil
    self.pool[#self.pool + 1] = s
end

-- put every bar exactly where the engine says it is
function UI:SyncAll()
    local present = {}
    for _, t in ipairs(self.game:Tiles()) do
        present[t.id] = true
        local s = self:Sprite(t.id, t.t)
        s.x, s.y = CellXY(t.r, t.c)
        s.fx, s.tx, s.into = nil, nil, nil
        s.scaleK, s.alpha, s.pop, s.drop, s.wait = 1, 1, 0, 0, 0
    end
    for id in pairs(self.live) do if not present[id] then self:Release(id) end end
end

function UI:DrawSprites(el)
    local t = self.rt or 0
    local ox, oy = 0, 0
    local nd = self.nudge
    if nd then
        nd.t = nd.t - el
        if nd.t <= 0 then self.nudge = nil
        else
            local k = sin(pi * nd.t / nd.dur) * 7
            ox, oy = nd.dx * k, nd.dy * k
        end
    end
    for _, s in pairs(self.live) do
        local k = 1
        if s.wait > 0 then
            s.wait = s.wait - el
            k = 0
        elseif s.drop > 0 then
            s.drop = max(0, s.drop - el)
            local u = 1 - s.drop / DROP_T
            k = 0.25 + 0.75 * (1 - (1 - u) * (1 - u)) + 0.10 * sin(pi * u)
        elseif s.pop > 0 then
            s.pop = max(0, s.pop - el)
            k = 1 + 0.17 * sin(pi * (1 - s.pop / POP_T))
        end
        local size = TILE * k
        local x, y = s.x + ox, s.y + oy
        if k <= 0 then
            s.plate:SetAlpha(0); s.icon:SetAlpha(0); s.rim:SetAlpha(0); s.name:SetAlpha(0); s.val:SetAlpha(0); s.glow:SetAlpha(0)
        else
            s.plate:ClearAllPoints(); s.plate:SetPoint("CENTER", self.board, "TOPLEFT", x, y); s.plate:SetSize(size, size); s.plate:SetAlpha(1)
            s.rim:ClearAllPoints(); s.rim:SetPoint("CENTER", self.board, "TOPLEFT", x, y); s.rim:SetSize(size - 4, size - 4); s.rim:SetAlpha(0.55)
            s.icon:ClearAllPoints(); s.icon:SetPoint("CENTER", self.board, "TOPLEFT", x, y + 7 * k); s.icon:SetSize(50 * k, 50 * k); s.icon:SetAlpha(1)
            s.name:ClearAllPoints(); s.name:SetPoint("CENTER", self.board, "TOPLEFT", x, y - 33 * k); s.name:SetAlpha(k >= 0.9 and 1 or 0)
            s.val:ClearAllPoints(); s.val:SetPoint("TOPRIGHT", self.board, "TOPLEFT", x + 41 * k, y + 44 * k); s.val:SetAlpha(k >= 0.9 and 0.8 or 0)
            if (s.tier or 0) >= 8 then
                s.glow:ClearAllPoints(); s.glow:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
                local g = size * (1.45 + 0.06 * sin(t * 2.4 + s.id))
                s.glow:SetSize(g, g)
                s.glow:SetAlpha(min(0.55, 0.16 + 0.07 * (s.tier - 8)) * (0.8 + 0.2 * sin(t * 2.4 + s.id)))
            end
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
        p.life = 0.45 + math.random() * 0.35
        p.max = p.life
        p.size = 8 + math.random() * 10
        p.t:SetVertexColor(col[1], col[2], col[3])
        p.t:Show()
    end
end

function UI:Float(x, y, text, col)
    for _, f in ipairs(self.floats) do
        if f.life <= 0 then
            f.x, f.y, f.life = x, y, 0.9
            f.t:SetText(text)
            f.t:SetTextColor(col[1], col[2], col[3])
            f.t:Show()
            return
        end
    end
end

function UI:Shout(text)
    self.shout:SetText(text)
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
                p.vy = p.vy - 260 * el
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local k = p.life / p.max
                p.t:ClearAllPoints()
                p.t:SetPoint("CENTER", self.board, "TOPLEFT", p.x, p.y)
                p.t:SetSize(p.size * (0.5 + k), p.size * (0.5 + k))
                p.t:SetAlpha(k)
            end
        end
    end
    for _, f in ipairs(self.floats) do
        if f.life > 0 then
            f.life = f.life - el
            if f.life <= 0 then f.t:Hide()
            else
                f.y = f.y + 46 * el
                f.t:ClearAllPoints()
                f.t:SetPoint("CENTER", self.board, "TOPLEFT", f.x, f.y)
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
        local k = self.shoutT
        self.shout:SetAlpha(min(1, k * 2.5))
        self.shout:SetScale(1 + max(0, (k - 1.1)) * 2)
        if k <= 0 then self.shout:Hide() end
    end
end

---------------------------------------------------------------------------
-- Playing back a move
---------------------------------------------------------------------------
function UI:IsBusy() return self.anim ~= nil end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.boardPanel:IsShown()
end

function UI:PlayMove(res)
    for _, m in ipairs(res.slides) do
        local s = self.live[m.id]
        if s then
            s.fx, s.fy = s.x, s.y
            s.tx, s.ty = CellXY(m.tr, m.tc)
            s.into = m.into
        end
    end
    self.anim = { res = res, t = 0, stage = "slide" }
    W.SFX("pop1", 0.04)
end

-- the bars have arrived: smelt the pairs and drop the new bar in
function UI:Land(res)
    for _, m in ipairs(res.slides) do
        local s = self.live[m.id]
        if s then
            s.x, s.y = s.tx or s.x, s.ty or s.y
            s.fx, s.tx = nil, nil
            if m.into then self:Release(m.id) end
        end
    end
    local top = 0
    for _, m in ipairs(res.smelts) do
        local s = self:Sprite(m.id, m.t)
        s.x, s.y = CellXY(m.r, m.c)
        s.pop = POP_T
        local bar = Forge.Bar(m.t)
        local c = bar.color
        local bright = { min(1, c[1] * 0.6 + 0.4), min(1, c[2] * 0.6 + 0.4), min(1, c[3] * 0.6 + 0.4) }
        self:Burst(s.x, s.y, bright, 6 + m.t * 2, 130 + m.t * 14)
        self:Float(s.x, s.y + 18, "+" .. W.Commas(Forge.Value(m.t)), bright)
        if m.t > top then top = m.t end
    end
    if top > 0 then
        W.SFX(("peg%02d"):format(min(25, 2 + top * 2)), 0.03)
        if top >= 6 then W.SFX("power", 0.2) end
        -- the first time a metal is reached in this forge, say so
        if top > (self.shownBest or 0) then
            self.shownBest = top
            if top >= 5 then
                local c = Forge.Bar(top).color
                self:Shout(BarName(top) .. "!")
                self.shout:SetTextColor(min(1, c[1] * 0.5 + 0.5), min(1, c[2] * 0.5 + 0.5), min(1, c[3] * 0.5 + 0.5))
                self:Flash(c[1], c[2], c[3], top >= Forge.GOAL and 0.5 or 0.22)
                if top >= 8 then W.SFX("multiplier", 0.2) end
            end
        end
    end
    local sp = res.spawn
    if sp then
        local s = self:Sprite(sp.id, sp.t)
        s.x, s.y = CellXY(sp.r, sp.c)
        s.drop = DROP_T
    end
    self:RefreshHUD()
end

function UI:StepAnim(el)
    local a = self.anim
    if not a then return end
    a.t = a.t + el
    if a.stage == "slide" then
        local k = min(1, a.t / SLIDE_T)
        local e = 1 - (1 - k) * (1 - k)
        for _, m in ipairs(a.res.slides) do
            local s = self.live[m.id]
            if s and s.fx then s.x, s.y = s.fx + (s.tx - s.fx) * e, s.fy + (s.ty - s.fy) * e end
        end
        if k >= 1 then
            self:Land(a.res)
            a.stage, a.t = "settle", 0
        end
    elseif a.t >= POP_T then
        self.anim = nil
        self:AfterMove(a.res)
    end
end

-- finish whatever is still moving at once (the next move is already on its way)
function UI:Settle()
    local a = self.anim
    if not a then return end
    self.anim = nil
    if a.stage == "slide" then self:Land(a.res) end
    for _, s in pairs(self.live) do s.pop, s.drop, s.wait = 0, 0, 0 end
    self:AfterMove(a.res)
end

function UI:AfterMove(res)
    if res.over then
        self:ShowResult()
    elseif res.won then
        self:ShowArcanite()
    end
end

function UI:Save()
    local g = self.game
    if g.mode == "forge" then
        self.db.run = g.state == "play" and g:Serialize() or nil
    elseif g.mode == "daily" then
        local d = self:Daily()
        if g.day == d.date then d.run = g.state == "play" and g:Serialize() or nil end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function UI:TryMove(dir)
    if self.anim then self:Settle() end
    if self:Paused() or self.game.state ~= "play" then return false end
    local res = self.game:Move(dir)
    if not res then
        -- nothing can slide that way: the bars lean into the wall and settle back
        local v = VEC[dir]
        if not NS.db.settings.reducedMotion then self.nudge = { dx = v[1], dy = v[2], t = 0.14, dur = 0.14 } end
        W.SFX("knock", 0.15)
        return true
    end
    -- saved the moment the move is made, so closing the window mid-slide loses nothing
    self:Save()
    self:PlayMove(res)
    return true
end

function UI:OnKey(key)
    local dir = KEYDIR[key]
    if not dir or self.db.keys == false then return false end
    if self:Paused() or self.game.state ~= "play" then return false end
    -- on the ground the keys only belong to the forge while the pointer is on the window, so
    -- you can still walk; on a flight there is nowhere to walk to
    local shell = NS.Shell and NS.Shell.frame
    if not ((UnitOnTaxi and UnitOnTaxi("player")) or (shell and shell.IsMouseOver and shell:IsMouseOver())) then return false end
    self:TryMove(dir)
    return true
end

function UI:Cursor()
    local x, y = GetCursorPosition()
    local s = self.board:GetEffectiveScale()
    local l, t = self.board:GetLeft(), self.board:GetTop()
    if not (l and t) then return end
    return x / s - l, t - y / s
end

function UI:MouseDown(button)
    if button ~= "LeftButton" or self:Paused() or self.game.state ~= "play" then return end
    local bx, by = self:Cursor()
    if not bx then return end
    self.down = { x = bx, y = by }
end

-- a click with no drag: near an edge of the anvil, push the bars that way
function UI:MouseUp()
    local d = self.down
    self.down = nil
    if not d then return end
    local dx, dy = d.x - BW / 2, d.y - BW / 2
    if max(abs(dx), abs(dy)) < BW * 0.24 then return end
    if abs(dx) > abs(dy) then self:TryMove(dx > 0 and "right" or "left") else self:TryMove(dy > 0 and "down" or "up") end
end

function UI:CheckDrag()
    local d = self.down
    if not d then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then return end
    local bx, by = self:Cursor()
    if not bx then return end
    local dx, dy = bx - d.x, by - d.y
    if max(abs(dx), abs(dy)) < 26 then return end
    self.down = nil
    if abs(dx) > abs(dy) then self:TryMove(dx > 0 and "right" or "left") else self:TryMove(dy > 0 and "down" or "up") end
end

function UI:Reheat()
    if self.anim then self:Settle() end
    if self.menu:IsShown() or self.boardPanel:IsShown() then return end
    local g = self.game
    if not g:CanUndo() then return end
    if self.card:IsShown() then self.card:Hide() end
    g:Undo()
    self.shownBest = g.best
    self:Save()
    self:SyncAll()
    for _, s in pairs(self.live) do s.pop = POP_T end
    self:Flash(1, 0.5, 0.15, 0.3)
    W.SFX("rb_stomp", 0.1)
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Frame update, HUD
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    self:StepAnim(el)
    if not self:Paused() then self:CheckDrag() end
    self:DrawSprites(el)
    self:UpdateFX(el)
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.25; self:RefreshHUD() end
end

function UI:RefreshHUD()
    local g = self.game
    if not g or not self.scoreText then return end
    local playing = g.state ~= "idle"
    self.scoreText:SetText(playing and W.Commas(g.score or 0) or "")
    local best = playing and (g.best or 0) or 0
    if g.mode == "daily" and playing then
        local d = self:Daily()
        self.modeText:SetText("DAILY SMELT")
        self.nameText:SetText("Same bars for all")
        self.rightLabel:SetText("TODAY'S BEST")
        self.rightValue:SetText((d.best or 0) > 0 and W.Short(d.best) or "-")
        self.movesLabel:SetText("STRIKES LEFT")
        self.movesValue:SetText(tostring(g.movesLeft or 0))
        self.movesValue:SetTextColor((g.movesLeft or 99) <= 10 and 0.8 or 0.55, (g.movesLeft or 99) <= 10 and 0.1 or 0.18, 0.08)
    elseif playing then
        self.modeText:SetText("THE GREAT FORGE")
        self.nameText:SetText(best >= Forge.GOAL and "Arcanite smelted!" or ("Next: " .. BarName(max(2, best + 1))))
        self.rightLabel:SetText("BEST")
        local top = max(self.db.best, g.score or 0)
        self.rightValue:SetText(top > 0 and W.Short(top) or "-")
        self.movesLabel:SetText("STRIKES")
        self.movesValue:SetText(tostring(g.moves or 0))
        self.movesValue:SetTextColor(0.55, 0.18, 0.08)
    else
        self.modeText:SetText("THE GREAT FORGE")
        self.nameText:SetText("Light the forge")
        self.rightLabel:SetText("BEST")
        self.rightValue:SetText(self.db.best > 0 and W.Short(self.db.best) or "-")
        self.movesLabel:SetText("")
        self.movesValue:SetText("")
    end
    -- the ladder: every metal reached in this forge is lit
    for i, b in ipairs(self.ladder) do
        local lit = i <= best
        if b.icon.SetDesaturated then b.icon:SetDesaturated(not lit) end
        b.icon:SetAlpha(lit and 1 or 0.4)
        b.ring:SetShown(i == min(best, Forge.GOAL) and best > 0)
    end
    if best > Forge.GOAL then
        self.ladderTitle:SetText("Beyond Arcanite: " .. BarName(best))
    elseif best >= Forge.GOAL then
        self.ladderTitle:SetText("Arcanite!")
    elseif best > 0 then
        self.ladderTitle:SetText(("Best bar: %s"):format(BarName(best)))
    else
        self.ladderTitle:SetText("The smelting ladder")
    end
    self.ladderSub:SetText(best > 0 and best < Forge.GOAL and ("Two %s make %s"):format(BarName(best), BarName(best + 1)) or "Two bars of the same metal smelt into the next")
    self.restartButton:SetShown(playing)
    local undo = g.mode == "forge" and playing
    self.undoButton:SetShown(undo)
    if undo then
        self.undoButton.text:SetText(("Reheat (%d)"):format(g.undosLeft or 0))
        self.undoButton:SetAlpha(g:CanUndo() and 1 or 0.45)
    end
end

---------------------------------------------------------------------------
-- Starting, ending
---------------------------------------------------------------------------
local function NewSeed()
    local t = (time and time() or 0) % 1000000
    local ms = floor(((GetTime and GetTime() or 0) % 1000) * 1000)
    return t * 97 + ms + 1
end

-- mode "daily" carries on today's smelt if one is under way; "forge" with opts.continue carries
-- on the saved forge
function UI:Begin(mode, opts)
    opts = opts or {}
    self.anim, self.down, self.nudge = nil, nil, nil
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    local g = self.game
    local fresh = true
    if mode == "daily" then
        local d = self:Daily()
        if not opts.restart and d.run and g:Restore(d.run) and g.state == "play" and g.day == d.date then
            fresh = false
        else
            g:Start("daily", { day = d.date })
            d.tries = (d.tries or 0) + 1
        end
    elseif opts.continue and self.db.run and g:Restore(self.db.run) and g.state == "play" then
        fresh = false
    else
        g:Start("forge", { seed = NewSeed() })
    end
    self.counted = false
    self.shownBest = g.best
    self:Save()
    self:SyncAll()
    -- the bars drop onto the anvil one after another
    local i = 0
    for _, t in ipairs(g:Tiles()) do
        local s = self.live[t.id]
        s.drop, s.wait = DROP_T, fresh and i * 0.07 or i * 0.02
        i = i + 1
    end
    W.SFX("launch")
    self:RefreshHUD()
end

function UI:Confirm(title, body, yes, fn)
    self.card:Open({
        title = title, color = TINT, center = true, body = body,
        buttons = { { yes, fn }, { "Keep going", function() if self.game.state ~= "play" then self:ShowMenu() end end, "ghost" } },
    })
end

function UI:NewForge()
    if self.menu:IsShown() then self.menu:Hide() end
    local run = self.db.run
    if run and (run.score or 0) > 0 then
        self:Confirm("Light a new forge?", ("The forge you have going (|cffffffff%s|r points) will be put out."):format(W.Commas(run.score)),
            "New forge", function() self:Begin("forge") end)
    else
        self:Begin("forge")
    end
end

function UI:Restart()
    local g = self.game
    if g.state == "idle" then return end
    if g.mode == "daily" then
        self:Confirm("Start today's smelt again?", "The same bars drop in the same order. Your best score of the day is the one that counts.",
            "Start again", function() self:Begin("daily", { restart = true }) end)
    elseif (g.score or 0) > 0 and g.state == "play" then
        self:Confirm("Light a new forge?", ("This forge (|cffffffff%s|r points) will be put out."):format(W.Commas(g.score)),
            "New forge", function() self:Begin("forge") end)
    else
        self:Begin("forge")
    end
end

-- the first Arcanite of a forge: a moment, then carry on
function UI:ShowArcanite()
    local db = self.db
    db.arcanite = (db.arcanite or 0) + 1
    if (self.game.best or 0) > db.bestBar then db.bestBar = self.game.best end
    W.SFX("win")
    self.card:Open({
        title = "Arcanite!", color = { 0.7, 0.62, 1 }, center = true,
        body = ("You smelted an |cffb39bffArcanite Bar|r in %d strikes.\n\nThe forge is still hot: keep going for a bigger score, and see what lies past Arcanite."):format(self.game.moves or 0),
        buttons = { { "Keep forging", function() end }, { "Menu", function() self:ShowMenu() end, "ghost" } },
    })
end

function UI:ShowResult()
    local g = self.game
    local db = self.db
    local barName = BarName(max(1, g.best or 1))
    if (g.best or 0) > db.bestBar then db.bestBar = g.best end
    if g.mode == "daily" then
        local d = self:Daily()
        local today = g.day == d.date
        local newBest = today and g.score > (d.best or 0)
        if newBest then d.best, d.bar = g.score, g.best end
        if today then d.run = nil end
        if not self.counted then
            self.counted = true
            db.games = db.games + 1
            if today and (d.tries or 0) <= 1 then db.dailies = db.dailies + 1 end
        end
        if today then NS.Social:Submit("fgd", d.date, d.best, BarName(max(1, d.bar or g.best or 1))) end
        W.SFX(newBest and "win" or "coin_win")
        local rk, n = NS.Social:Rank("fgd", d.date, "realm")
        self.card:Open({
            title = (g.movesLeft or 0) <= 0 and "The last strike" or "The forge goes cold", color = COLORS.gold, center = true,
            body = ("|cffffffff%s|r points%s\nBest bar: |cffffcc40%s|r\n\nToday's best: %s%s"):format(W.Commas(g.score), newBest and "  |cff80ff80(new best!)|r" or "",
                barName, W.Commas(d.best or 0), (rk and n > 1) and ("\nRank #%d of %d"):format(rk, n) or ""),
            buttons = {
                { "Again", function() self:Begin("daily", { restart = true }) end },
                { "Leaderboard", function() self:ShowBoard("fgd") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    else
        local newBest = g.score > db.best
        if newBest then db.best = g.score end
        db.run = nil
        if not self.counted then self.counted = true; db.games = db.games + 1 end
        NS.Social:SubmitBest("fg", db.best, BarName(max(1, db.bestBar)))
        W.SFX(newBest and "win" or "lose")
        local buttons = {}
        if g:CanUndo() then buttons[#buttons + 1] = { ("Reheat (%d)"):format(g.undosLeft), function() self:Reheat() end } end
        buttons[#buttons + 1] = { "New forge", function() self:Begin("forge") end }
        buttons[#buttons + 1] = { "Leaderboard", function() self:ShowBoard("fg") end }
        buttons[#buttons + 1] = { "Menu", function() self:ShowMenu() end, "ghost" }
        self.card:Open({
            title = "The forge goes cold", color = newBest and COLORS.gold or TINT, center = true,
            body = ("The anvil is full and nothing will smelt.\n\n|cffffffff%s|r points%s\nBest bar: |cffffcc40%s|r in %d strikes%s"):format(W.Commas(g.score),
                newBest and "  |cff80ff80(new best!)|r" or "", barName, g.moves or 0,
                g:CanUndo() and "\n\nA |cffffcc40Reheat|r takes back the last move." or ""),
            buttons = buttons,
        })
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Menu, boards, help
---------------------------------------------------------------------------
function UI:OnShow()
    self:RefreshHUD()
    if self.game.state ~= "play" and not self.card:IsShown() and not self.boardPanel:IsShown() then self:ShowMenu() end
end

function UI:OnHide()
    self.down = nil
    if self.anim then self:Settle() end
end

function UI:ShowMenu()
    if self.anim then self:Settle() end
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local g = self.game
    local d = self:Daily()
    local playing = g.state == "play"
    local run = db.run
    local lines = {
        ("Best forge |cffffffff%s|r     Best bar |cffffcc40%s|r"):format(db.best > 0 and W.Commas(db.best) or "-", db.bestBar > 0 and BarName(db.bestBar) or "-"),
        ("Today's Daily Smelt: %s"):format((d.best or 0) > 0 and ("best |cffffffff" .. W.Commas(d.best) .. "|r") or (d.run and "under way" or "not played yet")),
    }
    if run and not (playing and g.mode == "forge") then
        lines[#lines + 1] = ("A forge is waiting: |cffffffff%s|r points"):format(W.Commas(run.score or 0))
    end
    if (db.arcanite or 0) > 0 then lines[#lines + 1] = ("Arcanite smelted |cffb39bff%d|r time%s"):format(db.arcanite, db.arcanite == 1 and "" or "s") end
    local rl = NS.Social:RankLine("fgd", d.date)
    if rl then lines[#lines + 1] = "Daily: " .. rl end
    local buttons = {}
    if playing then buttons[#buttons + 1] = { "Resume", function() end } end
    if run and not (playing and g.mode == "forge") then
        buttons[#buttons + 1] = { "Continue forge", function() self:Begin("forge", { continue = true }) end }
    end
    buttons[#buttons + 1] = { "New forge", function() self:NewForge() end, (playing or run) and "ghost" or nil }
    if not (playing and g.mode == "daily") then
        buttons[#buttons + 1] = { d.run and "Continue daily" or "Daily Smelt", function() self:Begin("daily") end }
    end
    buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end }
    local options = NS.CommonOptions()
    table.insert(options, 1, { "Arrow keys and WASD slide the bars", function() return db.keys ~= false end, function(v) db.keys = v end })
    self.menu:Open({
        title = "The Great Forge", sub = "Smelt your way to Arcanite", icon = "Interface\\Icons\\Trade_BlackSmithing",
        color = TINT, lines = lines, buttons = buttons, options = options,
    })
end

function UI:ShowBoard(which)
    if self.anim then self:Settle() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    local views = {
        { label = "Forge", game = "fg", periods = true, title = "The Great Forge", sub = "Best scores from a single forge" },
        { label = "Daily", game = "fgd", periods = false, period = "day", title = "Daily Smelt", sub = "Today's bars are the same for everyone" },
    }
    self.boardPanel:Open({
        views = views, view = which == "fgd" and 2 or 1,
        empty = "No scores here yet.",
        fmt = function(e) return W.Commas(e.s), e.d or "" end,
        onClose = function() if self.game.state ~= "play" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    if self.anim then self:Settle() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.card:Open({
        title = "The Great Forge", color = TINT,
        body = table.concat({
            "|cffffcc40Slide|r every bar on the anvil one way: arrow keys or WASD, drag across the anvil, or click near one of its edges.",
            "",
            "Two bars of the |cffffcc40same metal|r that meet smelt into one bar of the next: Copper, Tin, Bronze, Silver, Iron, Gold, Steel, Mithril, Truesilver, Thorium and at last |cffb39bffArcanite|r.",
            "",
            "A new Copper bar (now and then Tin) drops in after every move. When the anvil is full and nothing will smelt, the forge goes cold.",
            "",
            ("|cffffcc40Reheat|r takes back your last move, %d times to a forge. Your forge is saved after every move: close the window whenever you land."):format(Forge.UNDOS),
            "",
            ("|cffffcc40Daily Smelt|r: the same bars for everyone, %d strikes, highest score wins."):format(Forge.DAILY_MOVES),
        }, "\n"),
        buttons = { { "To the anvil", function() if self.game.state ~= "play" then self:ShowMenu() end end } },
    })
end

function UI:Banner() end
