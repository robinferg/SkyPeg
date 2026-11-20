-- Flight Buddy :: GemsUI.lua
-- Jewelcrafter's Bench: the screen. A velvet tray of gems on the jeweler's workbench, a goals tray
-- underneath, and the animation that plays back each move the engine (Gems.lua) resolves.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Gems = NS.Gems
local floor, min, max, abs, sin, cos, sqrt, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.sqrt, math.pi

local UI = {}
NS.GemsUI = UI

local GEMART = W.MEDIA .. "gems\\"
local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local CELL, GEM = 54, 50
local BX, BY = 24, 10                      -- board offset inside the 480x560 holder
local BW = CELL * Gems.COLS                 -- 432
local SWAP_T, CLEAR_T = 0.15, 0.26
local GRAV = 2600                           -- px/s^2 for falling gems
local STAR = "|T" .. W.MEDIA .. "star:%d|t"

-- bench cloths (cosmetic): velvet colours for the tray
UI.CLOTHS = {
    { key = "royal",   name = "Royal Velvet",   tint = { 0.20, 0.24, 0.52 } },
    { key = "crimson", name = "Crimson Velvet", tint = { 0.46, 0.12, 0.16 }, stars = 9 },
    { key = "forest",  name = "Forest Felt",    tint = { 0.14, 0.34, 0.20 }, stars = 18 },
    { key = "onyx",    name = "Black Silk",     tint = { 0.12, 0.11, 0.14 }, stars = 30 },
    { key = "amber",   name = "Amber Suede",    tint = { 0.50, 0.32, 0.12 }, rush = 30000 },
    { key = "arcane",  name = "Arcane Weave",   tint = { 0.36, 0.18, 0.50 }, dailies = 10 },
}

local SHOUTS = { [2] = "Nice cut!", [3] = "Brilliant!", [4] = "Flawless!", [5] = "Masterwork!", [6] = "Legendary!" }
local BLAST_SFX = { row = "rb_zap", col = "rb_zap", area = "rb_stomp", color = "rb_arcane", cross = "rb_zap", all = "rb_rumble" }

local function Today() return NS.Social.Today() end

function UI:Init(db)
    self.db = db
    db.level = db.level or 1              -- highest Work Order unlocked
    db.stars = db.stars or {}             -- [level] = best stars
    db.best = db.best or 0                -- Gem Rush best
    db.games = db.games or 0
    db.daily = db.daily or {}
    db.dailies = db.dailies or 0
    db.cloth = db.cloth or "royal"
    if db.hints == nil then db.hints = true end
end

function UI:TotalStars()
    local n = 0
    for _, s in pairs(self.db.stars) do n = n + s end
    return n
end

function UI:Daily()
    local d = self.db.daily
    if d.date ~= Today() then d.date, d.best, d.tries = Today(), 0, 0 end
    return d
end

function UI:DailyPending() return (self:Daily().tries or 0) == 0 end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetAllPoints(parent)
    f:Hide()

    -- HUD: what you're playing, the score, and moves or time
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

    -- the bench
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(480, 560)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    self.holder = holder
    local bench = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    bench:SetTexture(W.TAVERN .. "wall_planks")
    bench:SetAllPoints()
    -- the velvet tray in a brass-edged frame
    local trayFrame = CreateFrame("Frame", nil, holder)
    trayFrame:SetPoint("TOPLEFT", BX - 10, -(BY - 6) + 0)
    trayFrame:SetSize(BW + 20, BW + 16)
    trayFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", BX - 10, -BY + 8)
    W.Nine(trayFrame, "wood", 16, "BACKGROUND", -6)
    local velvet = holder:CreateTexture(nil, "BACKGROUND", nil, -4)
    velvet:SetTexture(GEMART .. "gem_velvet")
    velvet:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    velvet:SetSize(BW, BW)
    self.velvet = velvet

    -- gems live on a clipped board so new ones slide in from the top edge
    local board = CreateFrame("Frame", nil, holder)
    board:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    board:SetSize(BW, BW)
    board:SetClipsChildren(true)
    board:SetFrameLevel(holder:GetFrameLevel() + 2)
    self.board = board
    -- cell slots and ore veins
    self.slots, self.veinTex = {}, {}
    for r = 1, Gems.ROWS do
        self.veinTex[r] = {}
        for c = 1, Gems.COLS do
            local s = board:CreateTexture(nil, "BACKGROUND", nil, 1)
            s:SetTexture(GEMART .. "gem_slot")
            s:SetSize(CELL, CELL)
            s:SetPoint("CENTER", board, "TOPLEFT", (c - 0.5) * CELL, -(r - 0.5) * CELL)
            self.slots[#self.slots + 1] = s
            local v = board:CreateTexture(nil, "BACKGROUND", nil, 3)
            v:SetTexture(GEMART .. "gem_vein")
            v:SetSize(CELL - 2, CELL - 2)
            v:SetPoint("CENTER", board, "TOPLEFT", (c - 0.5) * CELL, -(r - 0.5) * CELL)
            v:Hide()
            self.veinTex[r][c] = v
        end
    end
    -- sprite pool
    self.pool, self.live = {}, {}
    -- effects layer above the gems (not clipped, so bursts can spill a little)
    local fx = CreateFrame("Frame", nil, holder)
    fx:SetAllPoints(board)
    fx:SetFrameLevel(board:GetFrameLevel() + 6)
    fx:EnableMouse(false)
    self.fx = fx
    self.select = fx:CreateTexture(nil, "ARTWORK", nil, 2)
    self.select:SetTexture(GEMART .. "gem_select")
    self.select:SetSize(CELL + 4, CELL + 4)
    self.select:SetBlendMode("ADD")
    self.select:Hide()
    self.hint = {}
    for i = 1, 2 do
        local h = fx:CreateTexture(nil, "ARTWORK", nil, 1)
        h:SetTexture(GEMART .. "gem_select")
        h:SetSize(CELL, CELL)
        h:SetBlendMode("ADD")
        h:Hide()
        self.hint[i] = h
    end
    self.beams = {}
    for i = 1, 12 do
        local b = fx:CreateTexture(nil, "OVERLAY", nil, 1)
        b:SetTexture(GEMART .. "gem_beam")
        b:SetBlendMode("ADD")
        b:Hide()
        self.beams[i] = { t = b, life = 0 }
    end
    self.parts = {}
    for i = 1, 140 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(W.MEDIA .. "sparkle")
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.floats = {}
    for i = 1, 8 do
        local t = W.Text(fx, 18, FONT_SHOUT, "OUTLINE")
        t:Hide()
        self.floats[i] = { t = t, life = 0 }
    end
    self.flash = W.Solid(fx, "OVERLAY", 1, 1, 1, 0, 6)
    self.flash:SetAllPoints(board)
    self.shout = W.Text(fx, 30, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", board, "CENTER", 0, 40)
    self.shout:SetTextColor(1, 0.86, 0.4)
    self.shout:Hide()
    self.shoutT = 0

    -- the goals tray under the bench
    local tray = CreateFrame("Frame", nil, holder)
    tray:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 10, 6)
    tray:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -10, 6)
    tray:SetHeight(100)
    tray:SetFrameLevel(holder:GetFrameLevel() + 3)
    W.Nine(tray, "parch", 16, "BACKGROUND", -4)
    self.tray = tray
    self.goalTitle = W.Text(tray, 14, W.FONT_TITLE)
    self.goalTitle:SetPoint("TOPLEFT", 18, -12)
    self.goalTitle:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
    self.goalTitle:SetShadowColor(0, 0, 0, 0)
    self.goals = {}
    for i = 1, 2 do
        local g = CreateFrame("Frame", nil, tray)
        g:SetSize(150, 40)
        g:SetPoint("TOPLEFT", 16 + (i - 1) * 156, -34)
        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetSize(34, 34)
        g.icon:SetPoint("LEFT", 0, 0)
        g.text = W.Text(g, 16, FONT_SHOUT)
        g.text:SetPoint("LEFT", g.icon, "RIGHT", 6, 4)
        g.text:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
        g.text:SetShadowColor(0, 0, 0, 0)
        g.sub = W.Text(g, 10, W.FONT)
        g.sub:SetPoint("TOPLEFT", g.text, "BOTTOMLEFT", 0, -1)
        g.sub:SetTextColor(0.42, 0.3, 0.18)
        g.sub:SetShadowColor(0, 0, 0, 0)
        g.check = g:CreateTexture(nil, "OVERLAY")
        g.check:SetTexture(W.MEDIA .. "star")
        g.check:SetSize(20, 20)
        g.check:SetPoint("CENTER", g.icon, "BOTTOMRIGHT", -2, 4)
        g.check:Hide()
        self.goals[i] = g
    end
    -- star meter: a brass bar with three star marks
    local meterBg = W.Solid(tray, "ARTWORK", 0.28, 0.18, 0.09, 1)
    meterBg:SetPoint("BOTTOMLEFT", 18, 14)
    meterBg:SetSize(290, 8)
    self.meterBg = meterBg
    self.meter = W.Solid(tray, "OVERLAY", COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
    self.meter:SetPoint("LEFT", meterBg, "LEFT", 0, 0)
    self.meter:SetHeight(8)
    self.meterStars = {}
    for i = 1, 3 do
        local s = tray:CreateTexture(nil, "OVERLAY", nil, 2)
        s:SetTexture(W.MEDIA .. "star")
        s:SetSize(20, 20)
        self.meterStars[i] = s
    end
    self.movesLabel = W.Text(tray, 11, W.FONT)
    self.movesLabel:SetPoint("TOPRIGHT", -22, -12)
    self.movesLabel:SetTextColor(0.42, 0.3, 0.18)
    self.movesLabel:SetShadowColor(0, 0, 0, 0)
    self.movesValue = W.Text(tray, 40, FONT_SHOUT)
    self.movesValue:SetPoint("TOP", self.movesLabel, "BOTTOM", 0, -2)
    self.movesValue:SetTextColor(0.55, 0.18, 0.08)
    self.movesValue:SetShadowColor(0, 0, 0, 0)

    -- input
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function(_, button) W.Guard("Jewelcrafter", self.MouseDown, self, button) end)
    board:SetScript("OnMouseUp", function(_, button) W.Guard("Jewelcrafter", self.MouseUp, self, button) end)

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

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.boardPanel = NS.NewBoardPanel(f, holder)
    self.picker = NS.NewPickerPanel(f, holder)
    self.picker:HookScript("OnHide", function() if self.game.state ~= "play" and not self.boardPanel:IsShown() and not self.card:IsShown() then self:ShowMenu() end end)

    self.game = Gems.New({ owner = self, over = UI.OnOver })
    self.queue = {}
    f:SetScript("OnUpdate", function(_, el) W.Guard("Jewelcrafter", self.OnUpdate, self, el) end)
    self:ApplyCloth()
    -- pick up a Work Order where you left it
    if not (self.db.run and self.game:Restore(self.db.run)) then
        self.db.run = nil
    end
    self:SyncAll(true)
    self:RefreshHUD()
end

function UI:Cloth()
    for _, c in ipairs(UI.CLOTHS) do if c.key == self.db.cloth and self:ClothUnlocked(c) then return c end end
    return UI.CLOTHS[1]
end

function UI:ClothUnlocked(c)
    local db = self.db
    if c.stars and self:TotalStars() < c.stars then return false end
    if c.rush and (db.best or 0) < c.rush then return false end
    if c.dailies and (db.dailies or 0) < c.dailies then return false end
    return true
end

function UI:ApplyCloth()
    local t = self:Cloth().tint
    self.velvet:SetVertexColor(t[1], t[2], t[3])
end

---------------------------------------------------------------------------
-- Sprites
---------------------------------------------------------------------------
local function CellXY(r, c) return (c - 0.5) * CELL, -(r - 0.5) * CELL end

function UI:Sprite(gem)
    local s = self.live[gem.id]
    if s then return s end
    s = table.remove(self.pool)
    if not s then
        s = {}
        s.burst = self.board:CreateTexture(nil, "ARTWORK", nil, 0)
        s.burst:SetTexture(GEMART .. "gem_burst")
        s.burst:SetBlendMode("ADD")
        s.body = self.board:CreateTexture(nil, "ARTWORK", nil, 2)
        s.line = self.board:CreateTexture(nil, "ARTWORK", nil, 4)
        s.line:SetTexture(GEMART .. "gem_line")
        s.line:SetBlendMode("ADD")
        s.crust = self.board:CreateTexture(nil, "ARTWORK", nil, 5)
        s.crust:SetTexture(GEMART .. "gem_crust")
    end
    s.gem = gem
    s.alpha, s.scale, s.vy = 1, 1, 0
    s.fade = nil
    self.live[gem.id] = s
    self:StyleSprite(s)
    return s
end

function UI:StyleSprite(s)
    local g = s.gem
    if g.k == 0 then
        s.body:SetTexture(GEMART .. "gem_prism")
    else
        s.body:SetTexture(GEMART .. "gem_" .. Gems.GEM[g.k].key)
    end
    s.body:Show()
    s.burst:SetShown(g.sp == "bomb")
    if g.sp == "bomb" then
        local c = Gems.GEM[g.k] and Gems.GEM[g.k].color or { 1, 1, 1 }
        s.burst:SetVertexColor(c[1] * 0.6 + 0.4, c[2] * 0.6 + 0.4, c[3] * 0.6 + 0.4, 0.9)
    end
    s.line:SetShown(g.sp == "h" or g.sp == "v")
    if g.sp == "v" then s.line:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0) else s.line:SetTexCoord(0, 1, 0, 1) end
    s.crust:SetShown((g.crust or 0) > 0)
end

function UI:Release(id)
    local s = self.live[id]
    if not s then return end
    s.body:Hide(); s.burst:Hide(); s.line:Hide(); s.crust:Hide()
    self.live[id] = nil
    self.pool[#self.pool + 1] = s
end

-- put every gem exactly where the engine says it is (after a load, restore or shuffle)
function UI:SyncAll(snap)
    local present = {}
    local grid = self.game.grid
    if not grid then return end
    for r = 1, Gems.ROWS do
        for c = 1, Gems.COLS do
            local g = grid[r][c]
            if g then
                present[g.id] = true
                local s = self:Sprite(g)
                s.x, s.y = CellXY(r, c)
                s.tx, s.ty = s.x, s.y
                self:StyleSprite(s)
            end
            local vein = self.game.vein and self.game.vein[r] and self.game.vein[r][c]
            self.veinTex[r][c]:SetShown(vein and true or false)
        end
    end
    for id in pairs(self.live) do if not present[id] then self:Release(id) end end
end

function UI:DrawSprites(el)
    local t = self.rt or 0
    for id, s in pairs(self.live) do
        local size = GEM * (s.scale or 1)
        s.body:ClearAllPoints()
        s.body:SetPoint("CENTER", self.board, "TOPLEFT", s.x, s.y)
        s.body:SetSize(size, size)
        s.body:SetAlpha(s.alpha)
        local g = s.gem
        if g.sp == "bomb" then
            s.burst:ClearAllPoints()
            s.burst:SetPoint("CENTER", self.board, "TOPLEFT", s.x, s.y)
            s.burst:SetSize(size * 1.25, size * 1.25)
            if s.burst.SetRotation then s.burst:SetRotation(t * 0.8) end
            s.burst:SetAlpha(s.alpha * (0.65 + 0.25 * sin(t * 4)))
        end
        if g.sp == "h" or g.sp == "v" then
            s.line:ClearAllPoints()
            s.line:SetPoint("CENTER", self.board, "TOPLEFT", s.x, s.y)
            s.line:SetSize(size, size)
            s.line:SetAlpha(s.alpha * (0.55 + 0.35 * sin(t * 6 + id)))
        end
        if g.k == 0 and s.body.SetRotation then s.body:SetRotation(t * 0.6) end
        if (g.crust or 0) > 0 then
            s.crust:ClearAllPoints()
            s.crust:SetPoint("CENTER", self.board, "TOPLEFT", s.x, s.y)
            s.crust:SetSize(size * 1.06, size * 1.06)
            s.crust:SetAlpha(s.alpha)
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
        p.life, p.max = 0.45 + math.random() * 0.35, 0
        p.max = p.life
        p.size = 8 + math.random() * 10
        p.t:SetVertexColor(col[1], col[2], col[3])
        p.t:Show()
    end
end

function UI:Beam(kind, r, c, w)
    for _, b in ipairs(self.beams) do
        if b.life <= 0 then
            local t = b.t
            t:ClearAllPoints()
            if kind == "row" then
                t:SetTexCoord(0, 1, 0, 1)
                t:SetSize(BW + 40, CELL * (1 + 2 * (w or 0)) + 10)
                t:SetPoint("CENTER", self.board, "TOPLEFT", BW / 2, -(r - 0.5) * CELL)
            else
                t:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
                t:SetSize(CELL * (1 + 2 * (w or 0)) + 10, BW + 40)
                t:SetPoint("CENTER", self.board, "TOPLEFT", (c - 0.5) * CELL, -BW / 2)
            end
            t:SetVertexColor(1, 0.92, 0.7)
            t:Show()
            b.life, b.max = 0.35, 0.35
            return
        end
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
    self.shoutT = 1.1
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
    for _, b in ipairs(self.beams) do
        if b.life > 0 then
            b.life = b.life - el
            if b.life <= 0 then b.t:Hide() else b.t:SetAlpha(b.life / b.max) end
        end
    end
    for _, f in ipairs(self.floats) do
        if f.life > 0 then
            f.life = f.life - el
            if f.life <= 0 then f.t:Hide()
            else
                f.y = f.y + 40 * el
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
        self.shout:SetScale(1 + max(0, (k - 0.9)) * 2)
        if k <= 0 then self.shout:Hide() end
    end
end

---------------------------------------------------------------------------
-- Playing back a move
---------------------------------------------------------------------------
function UI:IsBusy() return (#self.queue > 0) or self.phase ~= nil end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.boardPanel:IsShown()
        or (self.picker and self.picker:IsShown())
end

function UI:Play(phases, a, b)
    self.swapA, self.swapB = a, b
    for _, p in ipairs(phases) do self.queue[#self.queue + 1] = p end
    self.idleT = 0
    self:HideHint()
end

function UI:StartPhase(p)
    self.phase, self.pt = p, 0
    if p.t == "swap" then
        local ar, ac, br, bc = p.a[1], p.a[2], p.b[1], p.b[2]
        p.sa, p.sb = self.live[self.swapA and self.swapA.id or -1], self.live[self.swapB and self.swapB.id or -1]
        p.ax, p.ay = CellXY(ar, ac)
        p.bx, p.by = CellXY(br, bc)
        p.dur = p.ok and SWAP_T or SWAP_T * 2
        if not p.ok then W.SFX("knock") else W.SFX("pop" .. math.random(1, 3)) end
    elseif p.t == "clear" then
        p.dur = CLEAR_T
        local cx, cy, n = 0, 0, 0
        for _, cl in ipairs(p.cleared) do
            local s = self.live[cl.gem.id]
            if s then s.fade = true end
            local x, y = CellXY(cl.r, cl.c)
            cx, cy, n = cx + x, cy + y, n + 1
            local col = Gems.GEM[cl.gem.k] and Gems.GEM[cl.gem.k].color or { 1, 1, 1 }
            self:Burst(x, y, col, cl.why == "blast" and 4 or 6, cl.why == "blast" and 220 or 150)
        end
        for _, cr in ipairs(p.crust) do
            local s = self.live[cr.gem.id]
            if s then self:StyleSprite(s) end
            local x, y = CellXY(cr.r, cr.c)
            self:Burst(x, y, { 0.75, 0.72, 0.8 }, 10, 180)
            W.SFX("snow_crate", 0.05)
        end
        for _, v in ipairs(p.veins) do
            self.veinTex[v[1]][v[2]]:Hide()
            local x, y = CellXY(v[1], v[2])
            self:Burst(x, y, { 1, 0.82, 0.3 }, 8, 120)
        end
        for _, bl in ipairs(p.blasts) do
            if bl.kind == "row" then self:Beam("row", bl.r)
            elseif bl.kind == "col" then self:Beam("col", nil, bl.c)
            elseif bl.kind == "cross" then self:Beam("row", bl.r, nil, bl.w); self:Beam("col", nil, bl.c, bl.w)
            elseif bl.kind == "area" then
                local x, y = CellXY(bl.r, bl.c)
                self:Burst(x, y, { 1, 0.9, 0.6 }, 26, 300)
                self:Flash(1, 0.85, 0.5, 0.18)
            elseif bl.kind == "color" then
                local col = Gems.GEM[bl.k] and Gems.GEM[bl.k].color or { 1, 1, 1 }
                self:Flash(col[1], col[2], col[3], 0.28)
            elseif bl.kind == "all" then
                self:Flash(1, 1, 1, 0.5)
            end
            W.SFX(BLAST_SFX[bl.kind] or "rb_zap", 0.08)
        end
        for _, cr in ipairs(p.created) do
            if not cr.lost then
                local s = self:Sprite(cr.gem)
                s.x, s.y = CellXY(cr.r, cr.c)
                s.tx, s.ty = s.x, s.y
                s.scale, s.popIn = 0.2, true
                self:Burst(s.x, s.y, { 1, 0.95, 0.7 }, 14, 200)
            end
        end
        if #p.created > 0 then W.SFX("power", 0.1) end
        W.SFX(("peg%02d"):format(min(25, 2 + p.cascade * 3 + math.random(0, 2))))
        if n > 0 then
            self:Float(cx / n, cy / n, ("+%s"):format(W.Commas(p.points)) .. (p.cascade > 1 and ("  x" .. p.cascade) or ""),
                p.cascade > 1 and { 1, 0.85, 0.35 } or { 1, 1, 1 })
        end
        if SHOUTS[min(6, p.cascade)] and p.cascade >= 2 then self:Shout(SHOUTS[min(6, p.cascade)]) end
        if (p.count or 0) >= 15 and p.cascade < 2 then self:Shout("Masterwork!") end
        self:RefreshHUD()
    elseif p.t == "fall" then
        local longest = 0
        for _, m in ipairs(p.moves) do
            local s = self.live[m.gem.id]
            if s then
                s.tx, s.ty = CellXY(m.r1, m.c)
                s.vy = 0
                longest = max(longest, (m.r1 - m.r0) * CELL)
            end
        end
        for _, sp in ipairs(p.spawns) do
            local s = self:Sprite(sp.gem)
            s.x, s.y = CellXY(sp.r0, sp.c)
            s.tx, s.ty = CellXY(sp.r1, sp.c)
            s.vy = 0
            longest = max(longest, (sp.r1 - sp.r0) * CELL)
        end
        p.dur = sqrt(2 * longest / GRAV) + 0.05
    elseif p.t == "shuffle" then
        p.dur = 0.6
        self:Shout("Reshuffled")
        W.SFX("style")
    elseif p.t == "done" then
        p.dur = 0.5
        if p.bonus and p.bonus > 0 then
            self:Float(BW / 2, -BW / 2, ("Polish bonus +%s"):format(W.Commas(p.bonus)), { 1, 0.9, 0.5 })
        end
    end
end

function UI:EndPhase(p)
    if p.t == "swap" then
        if p.sa then p.sa.x, p.sa.y = p.ok and p.bx or p.ax, p.ok and p.by or p.ay end
        if p.sb then p.sb.x, p.sb.y = p.ok and p.ax or p.bx, p.ok and p.ay or p.by end
    elseif p.t == "clear" then
        for _, cl in ipairs(p.cleared) do self:Release(cl.gem.id) end
        for _, cr in ipairs(p.created) do local s = self.live[cr.gem.id]; if s then s.scale, s.popIn = 1, nil end end
    elseif p.t == "fall" then
        for _, s in pairs(self.live) do if s.tx then s.x, s.y = s.tx, s.ty end end
        W.SFX("pop" .. math.random(4, 8), 0.05)
    elseif p.t == "shuffle" then
        self:SyncAll()
    elseif p.t == "done" then
        self:ShowResult()
    end
end

function UI:StepPhase(el)
    local p = self.phase
    if not p then
        if #self.queue == 0 then return end
        self:StartPhase(table.remove(self.queue, 1))
        p = self.phase
    end
    self.pt = self.pt + el
    local k = min(1, self.pt / max(0.01, p.dur or 0.1))
    if p.t == "swap" then
        local e = k
        if not p.ok then e = (k < 0.5) and (k * 2) or (2 - k * 2) end
        e = e * e * (3 - 2 * e)
        if p.sa then p.sa.x, p.sa.y = p.ax + (p.bx - p.ax) * e, p.ay + (p.by - p.ay) * e end
        if p.sb then p.sb.x, p.sb.y = p.bx + (p.ax - p.bx) * e, p.by + (p.ay - p.by) * e end
    elseif p.t == "clear" then
        for _, cl in ipairs(p.cleared) do
            local s = self.live[cl.gem.id]
            if s then s.scale = 1 + 0.35 * k; s.alpha = 1 - k end
        end
        for _, cr in ipairs(p.created) do
            local s = self.live[cr.gem.id]
            if s and s.popIn then s.scale = 0.2 + 1.0 * min(1, k * 1.4) - 0.2 * max(0, k * 1.4 - 1) end
        end
    elseif p.t == "fall" then
        for _, s in pairs(self.live) do
            if s.ty and s.y > s.ty + 0.5 then
                s.vy = s.vy + GRAV * el
                s.y = max(s.ty, s.y - s.vy * el)
            end
        end
    elseif p.t == "shuffle" then
        for _, s in pairs(self.live) do s.alpha = abs(1 - 2 * k); if k >= 0.5 and not p.synced then p.synced = true; self:SyncAll() end end
    end
    if self.pt >= (p.dur or 0) then
        self:EndPhase(p)
        self.phase = nil
        if #self.queue == 0 then self:Settled() end
    end
end

-- the bench is still: save, refresh, check for the end
function UI:Settled()
    for _, s in pairs(self.live) do s.alpha, s.scale = 1, 1 end
    self:SyncAll()
    if self.game.state == "play" and self.game.mode == "orders" then
        self.db.run = self.game:Serialize()
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function UI:CursorCell()
    local x, y = GetCursorPosition()
    local s = self.board:GetEffectiveScale()
    local l, t = self.board:GetLeft(), self.board:GetTop()
    if not (l and t) then return end
    local bx, by = x / s - l, t - y / s
    local c, r = floor(bx / CELL) + 1, floor(by / CELL) + 1
    return r, c, bx, by
end

function UI:MouseDown(button)
    if self:Paused() or self:IsBusy() or self.game.state ~= "play" then return end
    if button ~= "LeftButton" then self:Select(nil); return end
    local r, c, bx, by = self:CursorCell()
    if not r or r < 1 or c < 1 or r > Gems.ROWS or c > Gems.COLS then return end
    self.down = { r = r, c = c, x = bx, y = by }
    if self.sel and self.game:Adjacent(self.sel.r, self.sel.c, r, c) then
        self:TrySwap(self.sel.r, self.sel.c, r, c)
        self.down = nil
        return
    end
    self:Select(r, c)
end

function UI:MouseUp() self.down = nil end

-- dragging a gem past a third of a cell swaps it that way
function UI:CheckDrag()
    local d = self.down
    if not d then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self.down = nil return end
    local _, _, bx, by = self:CursorCell()
    if not bx then return end
    local dx, dy = bx - d.x, by - d.y
    if max(abs(dx), abs(dy)) < CELL * 0.33 then return end
    local r2, c2 = d.r, d.c
    if abs(dx) > abs(dy) then c2 = c2 + (dx > 0 and 1 or -1) else r2 = r2 + (dy > 0 and 1 or -1) end
    self.down = nil
    if r2 >= 1 and c2 >= 1 and r2 <= Gems.ROWS and c2 <= Gems.COLS then self:TrySwap(d.r, d.c, r2, c2) end
end

function UI:Select(r, c)
    if not r then self.sel = nil; self.select:Hide(); return end
    self.sel = { r = r, c = c }
    local x, y = CellXY(r, c)
    self.select:ClearAllPoints()
    self.select:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
    self.select:Show()
    W.SFX("pop1", 0.05)
end

function UI:TrySwap(r1, c1, r2, c2)
    self:Select(nil)
    local a, b = self.game.grid[r1][c1], self.game.grid[r2][c2]
    local phases = self.game:Swap(r1, c1, r2, c2)
    if phases then
        -- save the moment the move is made, so a reload mid-animation loses nothing
        if self.game.mode == "orders" then self.db.run = self.game:Serialize() end
        self:Play(phases, a, b)
    end
end

function UI:OnKey(key) return false end

---------------------------------------------------------------------------
-- Hints
---------------------------------------------------------------------------
function UI:ShowHint()
    local r1, c1, r2, c2 = self.game:FindMove()
    if not r1 then return end
    for i, p in ipairs({ { r1, c1 }, { r2, c2 } }) do
        local x, y = CellXY(p[1], p[2])
        self.hint[i]:ClearAllPoints()
        self.hint[i]:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
        self.hint[i]:Show()
    end
    self.hinting = true
end

function UI:HideHint()
    self.hinting = false
    for _, h in ipairs(self.hint) do h:Hide() end
end

---------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    if not self:Paused() then
        self:StepPhase(el)
        self:CheckDrag()
        if not self:IsBusy() and self.game.state == "play" then
            if self.game.timeLeft then
                self.game:Tick(el)
                if self.game.state ~= "play" then self:ShowResult() end
            end
            self.idleT = (self.idleT or 0) + el
            if self.db.hints and self.idleT > 7 and not self.hinting then self:ShowHint() end
        end
    end
    if self.hinting then
        local a = 0.35 + 0.35 * sin(self.rt * 6)
        for _, h in ipairs(self.hint) do h:SetAlpha(a) end
    end
    if self.sel then self.select:SetAlpha(0.7 + 0.3 * sin(self.rt * 8)) end
    self:DrawSprites(el)
    self:UpdateFX(el)
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.2; self:RefreshHUD() end
end

---------------------------------------------------------------------------
-- HUD and goals
---------------------------------------------------------------------------
local function GoalIcon(goal)
    if goal.kind == "collect" then return GEMART .. "gem_" .. Gems.GEM[goal.gem].key end
    if goal.kind == "veins" then return GEMART .. "gem_vein" end
    if goal.kind == "geodes" then return GEMART .. "gem_crust" end
    return W.MEDIA .. "star"
end

local function GoalLabel(goal)
    if goal.kind == "collect" then return "Cut " .. Gems.GEM[goal.gem].name .. "s" end
    if goal.kind == "veins" then return "Clear the ore veins" end
    if goal.kind == "geodes" then return "Crack geode crusts" end
    return "Score"
end

function UI:RefreshHUD()
    local g = self.game
    if not g or not self.scoreText then return end
    self.scoreText:SetText(W.Commas(g.score or 0))
    local mode = g.mode
    for _, gl in ipairs(self.goals) do gl:Hide() end
    for _, s in ipairs(self.meterStars) do s:Hide() end
    self.meterBg:Hide(); self.meter:Hide()
    if mode == "orders" and g.order then
        local o = g.order
        self.modeText:SetText(("WORK ORDER %d"):format(o.level))
        self.nameText:SetText(o.name)
        local stars = self.db.stars[o.level]
        self.rightLabel:SetText("BEST")
        self.rightValue:SetText(stars and (STAR:format(18):rep(stars)) or "-")
        self.goalTitle:SetText("The order")
        for i, goal in ipairs(o.goals) do
            local gl = self.goals[i]
            local have = min(goal.need, g:GoalProgress(goal))
            gl.icon:SetTexture(GoalIcon(goal))
            gl.text:SetText(goal.kind == "score" and (W.Short(have) .. " / " .. W.Short(goal.need)) or (have .. " / " .. goal.need))
            gl.sub:SetText(GoalLabel(goal))
            gl.check:SetShown(have >= goal.need)
            gl:Show()
        end
        -- star meter, scaled to the three-star score
        local top = o.stars[3] * 1.1
        self.meterBg:Show(); self.meter:Show()
        self.meter:SetWidth(max(1, 290 * min(1, (g.score or 0) / top)))
        for i, s in ipairs(self.meterStars) do
            s:ClearAllPoints()
            local at = i == 1 and 0.12 or (o.stars[i] / top)
            s:SetPoint("CENTER", self.meterBg, "LEFT", 290 * at, 0)
            local lit = (i == 1 and g:GoalsDone()) or (i > 1 and g:GoalsDone() and (g.score or 0) >= o.stars[i])
            s:SetVertexColor(lit and 1 or 0.35, lit and 0.9 or 0.3, lit and 0.4 or 0.25)
            s:Show()
        end
        self.movesLabel:SetText("MOVES")
        self.movesValue:SetText(tostring(g.moves or 0))
    elseif mode == "daily" then
        self.modeText:SetText("DAILY COMMISSION")
        self.nameText:SetText("The same bench for everyone today")
        local d = self:Daily()
        self.rightLabel:SetText("TODAY'S BEST")
        self.rightValue:SetText((d.best or 0) > 0 and W.Short(d.best) or "-")
        self.goalTitle:SetText("Score as much as you can in " .. Gems.DAILY_MOVES .. " moves")
        self.movesLabel:SetText("MOVES")
        self.movesValue:SetText(tostring(g.moves or 0))
    elseif mode == "rush" then
        self.modeText:SetText("GEM RUSH")
        self.nameText:SetText("Ninety seconds on the clock")
        self.rightLabel:SetText("BEST")
        self.rightValue:SetText(self.db.best > 0 and W.Short(self.db.best) or "-")
        self.goalTitle:SetText("Cut as many gems as you can before time runs out")
        self.movesLabel:SetText("TIME")
        local t = math.ceil(g.timeLeft or 0)
        self.movesValue:SetText(("%d:%02d"):format(floor(t / 60), t % 60))
        self.movesValue:SetTextColor(t <= 10 and 0.8 or 0.55, t <= 10 and 0.1 or 0.18, 0.08)
    else
        self.modeText:SetText("JEWELCRAFTER'S BENCH")
        self.nameText:SetText("Pick a commission")
        self.rightLabel:SetText("")
        self.rightValue:SetText("")
        self.goalTitle:SetText("")
        self.movesLabel:SetText("")
        self.movesValue:SetText("")
    end
    if mode ~= "rush" then self.movesValue:SetTextColor((g.moves or 9) <= 3 and 0.8 or 0.55, 0.18, 0.08) end
    self.restartButton:SetShown(g.state == "play")
end

---------------------------------------------------------------------------
-- Starting, ending
---------------------------------------------------------------------------
function UI:Begin(mode, opts)
    self.queue, self.phase = {}, nil
    self:Select(nil)
    self:HideHint()
    self.game:Start(mode, opts)
    self.idleT = 0
    if mode == "orders" then self.db.run = self.game:Serialize() end
    if mode == "daily" then local d = self:Daily(); d.tries = (d.tries or 0) + 1 end
    self:SyncAll()
    -- deal the gems in from above
    for id, s in pairs(self.live) do
        s.ty = s.y
        s.y = s.y + BW + 40 + (Gems.ROWS * CELL + s.y) * 0.3
        s.vy = 0
    end
    self.queue[1] = { t = "fall", moves = {}, spawns = {} }
    self:StartPhase(self.queue[1]); table.remove(self.queue, 1)
    self.phase.dur = 0.55
    W.SFX("launch")
    self:RefreshHUD()
end

function UI:StartOrder(level) self:Begin("orders", { level = level or self.db.level }) end

function UI:Restart()
    local g = self.game
    if g.mode == "orders" and g.order then self:StartOrder(g.order.level)
    elseif g.mode == "daily" then self:Begin("daily", { day = Today() })
    else self:Begin("rush", { seed = floor((self.rt or 0) * 1000) + 1 }) end
end

function UI:OnOver(won) end

function UI:ShowResult()
    local g = self.game
    local db = self.db
    db.games = db.games + 1
    if g.mode == "orders" then
        db.run = nil
        local o = g.order
        if g.won then
            local stars = g:Stars()
            if stars > (db.stars[o.level] or 0) then db.stars[o.level] = stars end
            if o.level >= db.level then db.level = o.level + 1 end
            NS.Social:SubmitBest("gemw", self:TotalStars(), ("order %d"):format(db.level - 1))
            W.SFX("win")
            self.card:Open({
                title = "Order complete!", color = COLORS.gold, center = true,
                body = ("%s\n\n|cffffffff%s|r points%s"):format(STAR:format(28):rep(stars) .. ("|cff555555" .. STAR:format(28):rep(3 - stars) .. "|r"),
                    W.Commas(g.score), stars == 3 and "\nA flawless commission!" or ""),
                buttons = {
                    { "Next order", function() self:StartOrder(o.level + 1) end },
                    { "Replay", function() self:StartOrder(o.level) end },
                    { "Menu", function() self:ShowMenu() end, "ghost" },
                },
            })
        else
            W.SFX("lose")
            local miss = {}
            for _, goal in ipairs(o.goals) do
                local have = g:GoalProgress(goal)
                if have < goal.need then miss[#miss + 1] = ("%s: %s / %s"):format(GoalLabel(goal), W.Commas(have), W.Commas(goal.need)) end
            end
            self.card:Open({
                title = "Out of moves", color = COLORS.red, center = true,
                body = "So close. The order still needs:\n\n" .. table.concat(miss, "\n"),
                buttons = {
                    { "Try again", function() self:StartOrder(o.level) end },
                    { "Menu", function() self:ShowMenu() end, "ghost" },
                },
            })
        end
    elseif g.mode == "daily" then
        local d = self:Daily()
        local newBest = g.score > (d.best or 0)
        if newBest then d.best = g.score end
        if (d.tries or 0) <= 1 then db.dailies = db.dailies + 1 end
        NS.Social:Submit("gemd", Today(), d.best, ("%d tries"):format(d.tries or 1))
        W.SFX(newBest and "win" or "coin_win")
        local rk, n = NS.Social:Rank("gemd", Today(), "realm")
        self.card:Open({
            title = "Commission delivered", color = COLORS.gold, center = true,
            body = ("|cffffffff%s|r points%s\n\nToday's best: %s%s"):format(W.Commas(g.score), newBest and "  |cff80ff80(new best!)|r" or "",
                W.Commas(d.best), (rk and n > 1) and ("\nRank #%d of %d"):format(rk, n) or ""),
            buttons = {
                { "Again", function() self:Begin("daily", { day = Today() }) end },
                { "Leaderboard", function() self:ShowBoard("gemd") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    else
        local newBest = g.score > db.best
        if newBest then db.best = g.score end
        NS.Social:SubmitBest("gem", g.score, ("%d specials"):format(g.specialsMade or 0))
        W.SFX(newBest and "win" or "coin_win")
        self.card:Open({
            title = "Time!", color = COLORS.gold, center = true,
            body = ("|cffffffff%s|r points%s\n\nBest chain %d  -  specials cut %d"):format(W.Commas(g.score),
                newBest and "  |cff80ff80(new best!)|r" or "", g.cascadeBest or 0, g.specialsMade or 0),
            buttons = {
                { "Again", function() self:Begin("rush", { seed = floor((self.rt or 0) * 1000) + 1 }) end },
                { "Leaderboard", function() self:ShowBoard("gem") end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Menu, pickers, boards, help
---------------------------------------------------------------------------
function UI:OnShow()
    self:RefreshHUD()
    if self.game.state ~= "play" and not self.card:IsShown() then self:ShowMenu() end
end

function UI:OnHide() end

function UI:ShowMenu()
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local g = self.game
    local inOrder = g.state == "play" and g.mode == "orders"
    local o = Gems.Order(db.level)
    local d = self:Daily()
    local lines = {
        ("Next Work Order: |cffffcc40#%d  %s|r"):format(db.level, o.name),
        ("Stars earned |cffffffff%d|r     Gem Rush best |cffffffff%s|r"):format(self:TotalStars(), W.Commas(db.best)),
        ("Today's Daily Commission: %s"):format((d.best or 0) > 0 and ("best |cffffffff" .. W.Commas(d.best) .. "|r") or "not played yet"),
        ("Bench cloth: |cffffcc40%s|r"):format(self:Cloth().name),
    }
    local rl = NS.Social:RankLine("gemd", Today())
    if rl then lines[#lines + 1] = "Daily: " .. rl end
    local buttons = {}
    if g.state == "play" then buttons[#buttons + 1] = { "Resume", function() end } end
    buttons[#buttons + 1] = { inOrder and ("Order #" .. db.level) or ("Work Order #" .. db.level), function() self:StartOrder(db.level) end, g.state == "play" and "ghost" or nil }
    buttons[#buttons + 1] = { "Daily Commission", function() self:Begin("daily", { day = Today() }) end }
    buttons[#buttons + 1] = { "Gem Rush", function() self:Begin("rush", { seed = floor((self.rt or 0) * 1000) + 1 }) end }
    buttons[#buttons + 1] = { "Order book", function() self:ShowOrders() end }
    buttons[#buttons + 1] = { "Bench cloth", function() self:ShowCloths() end }
    if #buttons < 6 then buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end } end
    local options = NS.CommonOptions()
    table.insert(options, 1, { "Show a hint after a few seconds", function() return db.hints end, function(v) db.hints = v end })
    self.menu:Open({
        title = "Jewelcrafter's Bench", sub = "Cut gems three in a row", icon = "Interface\\Icons\\INV_Misc_Gem_01",
        color = { 0.75, 0.85, 1 }, lines = lines, buttons = buttons, options = options,
    })
end

-- the order book: the last nine orders you've unlocked, with your stars
function UI:ShowOrders()
    if self.menu:IsShown() then self.menu:Hide() end
    local db = self.db
    local last = db.level
    local first = max(1, last - 8)
    local items = {}
    for lv = first, first + 8 do
        local o = Gems.Order(lv)
        local goal = o.goals[1]
        local stars = db.stars[lv] or 0
        items[#items + 1] = {
            key = lv, name = ("#%d %s"):format(lv, o.name), icon = GoalIcon(goal), round = false,
            line = stars > 0 and (STAR:format(12):rep(stars) .. ("|cff555555" .. STAR:format(12):rep(3 - stars) .. "|r")) or (lv == last and "Next up" or ""),
            desc = GoalLabel(goal) .. ": " .. W.Commas(goal.need) .. " in " .. o.moves .. " moves",
            locked = lv > last, lockText = "Finish the order before",
        }
    end
    self.picker:Open({
        title = "Order book", color = { 0.75, 0.85, 1 },
        sub = "Replay any order you've unlocked for more stars.",
        items = items, selected = nil,
        onPick = function(lv) self.picker:Hide(); self:StartOrder(lv) end,
    })
end

function UI:ShowCloths()
    if self.menu:IsShown() then self.menu:Hide() end
    local items = {}
    for _, c in ipairs(UI.CLOTHS) do
        local lock = c.stars and ("Earn %d stars"):format(c.stars) or (c.rush and ("Score %s in Gem Rush"):format(W.Short(c.rush)))
            or (c.dailies and ("Play %d Daily Commissions"):format(c.dailies)) or nil
        items[#items + 1] = { key = c.key, name = c.name, line = "Bench cloth", icon = GEMART .. "gem_velvet", tint = c.tint,
            locked = not self:ClothUnlocked(c), lockText = lock }
    end
    self.picker:Open({
        title = "Bench cloth", color = { 0.75, 0.85, 1 }, sub = "The velvet your gems sit on. Purely for looks.",
        items = items, selected = self:Cloth().key,
        onPick = function(key) self.db.cloth = key; self:ApplyCloth() end,
    })
end

function UI:ShowBoard(which)
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    local views = {
        { label = "Gem Rush", game = "gem", periods = true, title = "Gem Rush", sub = "Ninety-second best scores" },
        { label = "Daily", game = "gemd", periods = false, period = "day", title = "Daily Commission", sub = "Today's bench is the same for everyone" },
        { label = "Work Orders", game = "gemw", periods = false, period = "all", title = "Work Orders", sub = "Most stars earned" },
    }
    local start = (which == "gemd" and 2) or (which == "gemw" and 3) or 1
    self.boardPanel:Open({
        views = views, view = start,
        empty = "No scores here yet.",
        fmt = function(e) return W.Commas(e.s), e.d or "" end,
        onClose = function() if self.game.state ~= "play" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    if self.menu:IsShown() then self.menu:Hide() end
    self.card:Open({
        title = "Jewelcrafter's Bench", color = { 0.75, 0.85, 1 },
        body = table.concat({
            "|cffffcc40Swap|r two neighbouring gems (click one then the other, or drag) to line up three or more of a kind.",
            "",
            "|cffffcc404 in a row|r cuts a |cff99ddffFaceted|r gem: it clears its row or column.",
            "|cffffcc40An L or T|r cuts a |cff99ddffBrilliant|r gem: it bursts everything around it.",
            "|cffffcc405 in a row|r cuts a |cff99ddffPrismatic|r gem: swap it with any gem to clear that colour.",
            "Swap two specials together for a bigger blast.",
            "",
            "|cffffcc40Work Orders|r have goals: cut certain gems, clear the gold |cffffcc40ore veins|r under the gems, or crack |cffffcc40geode crusts|r (a crusted gem can't be moved: match it to crack the crust).",
            "|cffffcc40Daily Commission|r: the same bench for everyone today. |cffffcc40Gem Rush|r: 90 seconds.",
        }, "\n"),
        buttons = { { "Let's cut", function() if self.game.state ~= "play" then self:ShowMenu() end end } },
    })
end

function UI:Banner() end
