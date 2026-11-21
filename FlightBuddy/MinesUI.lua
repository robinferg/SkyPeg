-- Flight Buddy :: MinesUI.lua
-- Goblin Minefield: the screen. A patch of mined desert, the clock, the count of mines left and
-- the playback of what the engine (Mines.lua) says each dig did.
--   left click  = dig (on a number: dig round it once its flags are down)
--   right click = plant or pull up a flag (Shift-click, or the Flags button, for one-button mice)
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Mines = NS.Mines
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

local UI = {}
NS.MinesUI = UI

local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local BX, BY = 24, 10                       -- board offset inside the 480x560 holder
local BW = 432
local TINT = { 0.62, 0.92, 0.40 }           -- goblin green, for titles and panels
local RETRY_COST = 30                       -- seconds on the clock for each time the daily blew up
local NUM = {
    { 0.45, 0.70, 1.00 }, { 0.45, 0.90, 0.45 }, { 1.00, 0.42, 0.38 }, { 0.80, 0.55, 1.00 },
    { 1.00, 0.62, 0.25 }, { 0.35, 0.90, 0.90 }, { 1.00, 1.00, 1.00 }, { 0.75, 0.75, 0.75 },
}
local SAND = { { 0.84, 0.69, 0.43 }, { 0.78, 0.63, 0.39 } }
local DIRT = { { 0.235, 0.175, 0.125 }, { 0.205, 0.150, 0.105 } }

local function Today() return NS.Social.Today() end

local function Clock(sec)
    sec = max(0, sec or 0)
    local m = floor(sec / 60)
    return ("%d:%04.1f"):format(m, sec - m * 60)
end
UI.Clock = Clock

local function Ordinal(n)
    local t = n % 100
    if t >= 11 and t <= 13 then return n .. "th" end
    local l = n % 10
    return n .. (l == 1 and "st" or l == 2 and "nd" or l == 3 and "rd" or "th")
end

function UI:Init(db)
    self.db = db
    db.best = db.best or {}               -- [size key] = best time
    db.wins = db.wins or 0
    db.games = db.games or 0
    db.daily = db.daily or {}
    db.dailies = db.dailies or 0          -- Daily Sweeps cleared
    db.size = db.size or "small"
    if db.flagMode == nil then db.flagMode = false end
end

function UI:Daily()
    local d = self.db.daily
    if d.date ~= Today() then d.date, d.best, d.tries, d.fails, d.done, d.open = Today(), nil, 0, 0, false, false end
    return d
end

function UI:DailyPending() return not self:Daily().done end

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
    self.timeText = W.Text(hud, 30, FONT_SHOUT, "OUTLINE")
    self.timeText:SetPoint("TOP", 0, -10)
    self.timeText:SetTextColor(1, 0.9, 0.6)
    self.rightLabel = W.Text(hud, 11, W.FONT)
    self.rightLabel:SetPoint("TOPRIGHT", -2, -8)
    self.rightLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.rightValue = W.Text(hud, 24, FONT_SHOUT, "OUTLINE")
    self.rightValue:SetPoint("TOPRIGHT", self.rightLabel, "BOTTOMRIGHT", 0, -2)

    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(480, 560)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    self.holder = holder
    local desert = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    desert:SetTexture(W.MEDIA .. "pbg_steppe_road")
    desert:SetAllPoints()
    desert:SetTexCoord(0.03, 0.97, 0, 1)
    desert:SetVertexColor(0.7, 0.66, 0.62)
    local trayFrame = CreateFrame("Frame", nil, holder)
    trayFrame:SetSize(BW + 20, BW + 16)
    trayFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", BX - 10, -BY + 8)
    W.Nine(trayFrame, "wood", 16, "BACKGROUND", -6)

    local board = CreateFrame("Frame", nil, holder)
    board:SetPoint("TOPLEFT", holder, "TOPLEFT", BX, -BY)
    board:SetSize(BW, BW)
    board:SetFrameLevel(holder:GetFrameLevel() + 2)
    self.board = board
    local ground = W.Solid(board, "BACKGROUND", 0.11, 0.08, 0.055, 1, 0)
    ground:SetAllPoints()
    self.cells = {}
    self.flagPool, self.minePool, self.crossPool = {}, {}, {}
    self.hover = W.Solid(board, "OVERLAY", 1, 1, 1, 0.14, 1)
    self.hover:Hide()
    self.hintRing = board:CreateTexture(nil, "OVERLAY", nil, 2)
    self.hintRing:SetTexture(W.MEDIA .. "ring")
    self.hintRing:SetVertexColor(0.45, 1, 0.45)
    self.hintRing:Hide()
    self.startRing = board:CreateTexture(nil, "OVERLAY", nil, 2)
    self.startRing:SetTexture(W.MEDIA .. "ring")
    self.startRing:SetVertexColor(1, 0.85, 0.4)
    self.startRing:Hide()

    local fx = CreateFrame("Frame", nil, holder)
    fx:SetAllPoints(board)
    fx:SetFrameLevel(board:GetFrameLevel() + 6)
    fx:EnableMouse(false)
    self.fx = fx
    self.parts = {}
    for i = 1, 110 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(W.MEDIA .. "sparkle")
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.rings = {}
    for i = 1, 6 do
        local t = fx:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture(W.MEDIA .. "shock")
        t:SetBlendMode("ADD")
        t:Hide()
        self.rings[i] = { t = t, life = 0 }
    end
    self.flash = W.Solid(fx, "OVERLAY", 1, 1, 1, 0, 6)
    self.flash:SetAllPoints(board)
    self.shout = W.Text(fx, 34, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", board, "CENTER", 0, 30)
    self.shout:Hide()
    self.shoutT = 0

    -- under the field: what you're digging, how far along, and the mines left
    local tray = CreateFrame("Frame", nil, holder)
    tray:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 10, 6)
    tray:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -10, 6)
    tray:SetHeight(100)
    tray:SetFrameLevel(holder:GetFrameLevel() + 3)
    W.Nine(tray, "parch", 16, "BACKGROUND", -4)
    self.tray = tray
    self.trayTitle = W.Text(tray, 14, W.FONT_TITLE)
    self.trayTitle:SetPoint("TOPLEFT", 18, -12)
    self.trayTitle:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
    self.trayTitle:SetShadowColor(0, 0, 0, 0)
    self.trayLine = W.Text(tray, 12, W.FONT)
    self.trayLine:SetPoint("TOPLEFT", self.trayTitle, "BOTTOMLEFT", 0, -6)
    self.trayLine:SetTextColor(0.30, 0.20, 0.10)
    self.trayLine:SetShadowColor(0, 0, 0, 0)
    local barBg = W.Solid(tray, "ARTWORK", 0.28, 0.18, 0.09, 1)
    barBg:SetPoint("BOTTOMLEFT", 18, 30)
    barBg:SetSize(300, 8)
    self.barBg = barBg
    self.bar = W.Solid(tray, "OVERLAY", 0.45, 0.72, 0.25, 1)
    self.bar:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    self.bar:SetHeight(8)
    self.traySub = W.Text(tray, 10, W.FONT)
    self.traySub:SetPoint("BOTTOMLEFT", 18, 12)
    self.traySub:SetTextColor(0.42, 0.3, 0.18)
    self.traySub:SetShadowColor(0, 0, 0, 0)
    self.traySub:SetText("Left click digs. Right click (or Shift-click) plants a flag.")
    self.minesLabel = W.Text(tray, 11, W.FONT)
    self.minesLabel:SetPoint("TOPRIGHT", -20, -12)
    self.minesLabel:SetTextColor(0.42, 0.3, 0.18)
    self.minesLabel:SetShadowColor(0, 0, 0, 0)
    self.minesLabel:SetText("MINES LEFT")
    self.minesValue = W.Text(tray, 38, FONT_SHOUT)
    self.minesValue:SetPoint("TOP", self.minesLabel, "BOTTOM", 0, -4)
    self.minesValue:SetTextColor(0.55, 0.18, 0.08)
    self.minesValue:SetShadowColor(0, 0, 0, 0)

    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function(_, button) W.Guard("Minefield", self.MouseDown, self, button) end)
    board:SetScript("OnMouseUp", function(_, button) W.Guard("Minefield", self.MouseUp, self, button) end)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10); bar:SetPoint("BOTTOMRIGHT", -20, 10); bar:SetHeight(30)
    bar:SetFrameLevel(f:GetFrameLevel() + 4)
    local menu = W.Button(bar, 60, 26, "Menu", "ghost")
    menu:SetPoint("LEFT", 0, 0)
    menu:SetScript("OnClick", function() self:ShowMenu() end)
    local help = W.Button(bar, 52, 26, "Help", "ghost")
    help:SetPoint("RIGHT", 0, 0)
    help:SetScript("OnClick", function() self:ShowHelp() end)
    local scores = W.Button(bar, 64, 26, "Scores", "ghost")
    scores:SetPoint("RIGHT", help, "LEFT", -6, 0)
    scores:SetScript("OnClick", function() self:ShowBoard() end)
    self.restartButton = W.Button(bar, 70, 26, "Restart", "ghost")
    self.restartButton:SetPoint("LEFT", menu, "RIGHT", 6, 0)
    self.restartButton:SetScript("OnClick", function() self:Restart() end)
    self.detectButton = W.Button(bar, 100, 26, "Detector", "ghost")
    self.detectButton:SetPoint("LEFT", self.restartButton, "RIGHT", 6, 0)
    self.detectButton:SetScript("OnClick", function() self:Detect() end)
    self.detectButton:HookScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetText("Gnomish Mine Detector", 1, 0.82, 0.38)
        GameTooltip:AddLine(("Rings one square that is safe to dig. One a field, and it puts %d seconds on your clock."):format(Mines.DETECT_COST), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.detectButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.flagButton = W.Button(bar, 84, 26, "Flags: off", "ghost")
    self.flagButton:SetPoint("LEFT", self.detectButton, "RIGHT", 6, 0)
    self.flagButton:SetScript("OnClick", function() self.db.flagMode = not self.db.flagMode; W.SFX("pop1"); self:RefreshHUD() end)
    self.flagButton:HookScript("OnEnter", function(btn)
        if not GameTooltip then return end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP", 0, 4)
        GameTooltip:SetText("Flag mode", 1, 0.82, 0.38)
        GameTooltip:AddLine("While this is on, a left click plants a flag instead of digging. For one-button mice and trackpads.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.flagButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.boardPanel = NS.NewBoardPanel(f, holder)

    self.game = Mines.New()
    self.fades, self.queue = {}, {}
    f:SetScript("OnUpdate", function(_, el) W.Guard("Minefield", self.OnUpdate, self, el) end)
    -- pick the field up where it was left
    local run = self.db.run
    if run and (run.mode ~= "daily" or run.day == Today()) and self.game:Restore(run) and self.game.state == "play" then
        self:Layout()
        self:SyncAll()
    else
        self.db.run = nil
        self.game = Mines.New()
    end
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- The field
---------------------------------------------------------------------------
function UI:CellXY(r, c) return (c - 0.5) * self.cell, -(r - 0.5) * self.cell end

function UI:Cell(r, c)
    local n = self.game.n
    local i = (r - 1) * n + c
    local cell = self.cells[i]
    if not cell then
        local b = self.board
        cell = {}
        cell.floor = W.Solid(b, "BACKGROUND", 1, 1, 1, 1, 1)
        cell.cover = b:CreateTexture(nil, "ARTWORK", nil, 1)
        cell.cover:SetTexture(W.MEDIA .. "tile")
        cell.num = W.Text(b, 14, W.FONT_NUM, "OUTLINE", "ARTWORK")
        self.cells[i] = cell
    end
    return cell
end

-- size and place every square for the field being played
function UI:Layout()
    local g = self.game
    local n = g.n
    if n <= 0 then return end
    self.cell = BW / n
    local size = self.cell
    local fs = max(10, floor(size * 0.60))
    for r = 1, n do
        for c = 1, n do
            local cell = self:Cell(r, c)
            local x, y = self:CellXY(r, c)
            local k = (r + c) % 2 + 1
            cell.floor:ClearAllPoints()
            cell.floor:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
            cell.floor:SetSize(size - 1.5, size - 1.5)
            cell.floor:SetColorTexture(DIRT[k][1], DIRT[k][2], DIRT[k][3], 1)
            cell.floor:Show()
            cell.cover:ClearAllPoints()
            cell.cover:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
            cell.cover:SetSize(size + 1, size + 1)
            cell.cover:SetVertexColor(SAND[k][1], SAND[k][2], SAND[k][3])
            cell.num:ClearAllPoints()
            cell.num:SetPoint("CENTER", self.board, "TOPLEFT", x, y - 0.5)
            cell.num:SetFont(W.FONT_NUM, fs, "OUTLINE")
        end
    end
    for i = n * n + 1, #self.cells do
        local cell = self.cells[i]
        cell.floor:Hide(); cell.cover:Hide(); cell.num:Hide()
    end
    self.laidFor = n
end

local function Take(pool, make)
    for _, o in ipairs(pool) do if not o.used then o.used = true; return o end end
    local o = make()
    o.used = true
    pool[#pool + 1] = o
    return o
end

local function Free(pool)
    for _, o in ipairs(pool) do
        o.used = false
        for _, t in ipairs(o.parts) do t:Hide() end
    end
end

function UI:FlagAt(r, c)
    local o = Take(self.flagPool, function()
        local b = self.board
        local pole = W.Solid(b, "ARTWORK", 0.25, 0.16, 0.08, 1, 3)
        local cloth = b:CreateTexture(nil, "ARTWORK", nil, 4)
        cloth:SetTexture(W.MEDIA .. "pennant")
        cloth:SetVertexColor(0.92, 0.16, 0.12)
        return { pole = pole, cloth = cloth, parts = { pole, cloth } }
    end)
    local x, y = self:CellXY(r, c)
    local s = self.cell
    o.pole:ClearAllPoints()
    o.pole:SetPoint("CENTER", self.board, "TOPLEFT", x - s * 0.16, y)
    o.pole:SetSize(max(2, s * 0.07), s * 0.62)
    o.cloth:ClearAllPoints()
    o.cloth:SetPoint("TOPLEFT", self.board, "TOPLEFT", x - s * 0.13, y + s * 0.31)
    o.cloth:SetSize(s * 0.46, s * 0.34)
    o.pole:Show(); o.cloth:Show()
    o.r, o.c = r, c
    return o
end

function UI:MineAt(r, c, scale)
    local o = Take(self.minePool, function()
        local t = self.board:CreateTexture(nil, "ARTWORK", nil, 5)
        t:SetTexture(W.MEDIA .. "ball_bomb")
        return { t = t, parts = { t } }
    end)
    local x, y = self:CellXY(r, c)
    o.t:ClearAllPoints()
    o.t:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
    o.t:SetSize(self.cell * 0.78 * (scale or 1), self.cell * 0.78 * (scale or 1))
    o.t:Show()
    return o
end

function UI:CrossAt(r, c)
    local o = Take(self.crossPool, function()
        local t = self.board:CreateTexture(nil, "ARTWORK", nil, 6)
        t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_7")
        return { t = t, parts = { t } }
    end)
    local x, y = self:CellXY(r, c)
    o.t:ClearAllPoints()
    o.t:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
    o.t:SetSize(self.cell * 0.8, self.cell * 0.8)
    o.t:Show()
    return o
end

function UI:ShowOpen(cell, data)
    cell.cover:Hide()
    if data.n > 0 then
        local col = NUM[data.n]
        cell.num:SetText(tostring(data.n))
        cell.num:SetTextColor(col[1], col[2], col[3])
        cell.num:SetAlpha(1)
        cell.num:Show()
    else
        cell.num:Hide()
    end
end

-- draw the whole field exactly as the engine has it
function UI:SyncAll()
    local g = self.game
    if g.n <= 0 then return end
    if self.laidFor ~= g.n then self:Layout() end
    self.fades, self.queue = {}, {}
    Free(self.flagPool); Free(self.minePool); Free(self.crossPool)
    for r = 1, g.n do
        for c = 1, g.n do
            local data = g.grid[r][c]
            local cell = self:Cell(r, c)
            if data.open then
                self:ShowOpen(cell, data)
            else
                cell.cover:SetAlpha(1)
                cell.cover:Show()
                cell.num:Hide()
                if data.flag then self:FlagAt(r, c) end
            end
        end
    end
    if g.state == "lost" then
        local mines, wrong = g:Reveal()
        for _, m in ipairs(mines) do
            self:Cell(m.r, m.c).cover:Hide()
            self:MineAt(m.r, m.c, (g.boom and g.boom.r == m.r and g.boom.c == m.c) and 1.25 or 1)
        end
        for _, w in ipairs(wrong) do self:CrossAt(w.r, w.c) end
    end
    self:PlaceMarks()
end

function UI:RedrawFlags()
    local g = self.game
    Free(self.flagPool)
    for r = 1, g.n do for c = 1, g.n do if g.grid[r][c].flag and not g.grid[r][c].open then self:FlagAt(r, c) end end end
end

function UI:PlaceMarks()
    local g = self.game
    local h = g.state == "play" and g.hint
    if h then
        local x, y = self:CellXY(h.r, h.c)
        self.hintRing:ClearAllPoints()
        self.hintRing:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
        self.hintRing:Show()
    else
        self.hintRing:Hide()
    end
    self.startRing:Hide()
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

function UI:Ring(x, y, size, col)
    if NS.db.settings.reducedMotion then return end
    for _, r in ipairs(self.rings) do
        if r.life <= 0 then
            r.x, r.y, r.size, r.life, r.max = x, y, size, 0.45, 0.45
            r.t:SetVertexColor(col[1], col[2], col[3])
            r.t:Show()
            return
        end
    end
end

function UI:Shout(text, col)
    self.shout:SetText(text)
    self.shout:SetTextColor(col[1], col[2], col[3])
    self.shout:Show()
    self.shoutT = 1.4
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
    for _, r in ipairs(self.rings) do
        if r.life > 0 then
            r.life = r.life - el
            if r.life <= 0 then r.t:Hide()
            else
                local k = 1 - r.life / r.max
                local s = r.size * (0.3 + 1.1 * k)
                r.t:ClearAllPoints()
                r.t:SetPoint("CENTER", self.board, "TOPLEFT", r.x, r.y)
                r.t:SetSize(s, s)
                r.t:SetAlpha(1 - k)
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
        if k <= 0 then self.shout:Hide() end
    end
end

---------------------------------------------------------------------------
-- Playing back a dig
---------------------------------------------------------------------------
function UI:IsBusy() return #self.queue > 0 end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.boardPanel:IsShown()
end

-- the sand blows off the dug squares, rippling out from where the spade went in
function UI:PlayOpen(opened)
    local still = NS.db.settings.reducedMotion
    for _, o in ipairs(opened) do
        local cell = self:Cell(o.r, o.c)
        local data = self.game.grid[o.r][o.c]
        if still then
            self:ShowOpen(cell, data)
        else
            self.fades[#self.fades + 1] = { cell = cell, data = data, wait = o.d * 0.022, t = 0 }
        end
    end
    if #opened > 0 then
        W.SFX(#opened > 6 and "rb_rumble" or ("pop" .. (1 + (#opened % 4))), 0.03)
    end
end

function UI:StepFades(el)
    local fades = self.fades
    if #fades == 0 then return end
    local keep = {}
    for _, fd in ipairs(fades) do
        if fd.wait > 0 then
            fd.wait = fd.wait - el
            keep[#keep + 1] = fd
        else
            fd.t = fd.t + el
            local k = fd.t / 0.13
            if k >= 1 then
                self:ShowOpen(fd.cell, fd.data)
            else
                if not fd.begun then
                    -- the number is there under the sand as it thins
                    fd.begun = true
                    self:ShowOpen(fd.cell, fd.data)
                    fd.cell.cover:Show()
                end
                fd.cell.cover:SetAlpha(1 - k)
                keep[#keep + 1] = fd
            end
        end
    end
    self.fades = keep
end

-- timed steps after a win or a loss (mines going off one by one, flags going in)
function UI:StepQueue(el)
    local q = self.queue
    if #q == 0 then return end
    local i = 1
    while i <= #q do
        local it = q[i]
        it.wait = it.wait - el
        if it.wait <= 0 then
            table.remove(q, i)
            it.fn()
        else
            i = i + 1
        end
    end
end

function UI:FinishFx()
    for _, fd in ipairs(self.fades) do self:ShowOpen(fd.cell, fd.data) end
    self.fades = {}
    local q = self.queue
    self.queue = {}
    for _, it in ipairs(q) do it.fn() end
end

function UI:Apply(res)
    if not res then return end
    self:PlayOpen(res.opened or {})
    self:RedrawFlags()
    self:PlaceMarks()
    if res.lost then
        self:Lose(res)
    elseif res.won then
        self:Win()
    else
        self:Save()
    end
    self:RefreshHUD()
end

function UI:Save()
    local g = self.game
    self.db.run = g.state == "play" and g:Serialize() or nil
end

function UI:Lose(res)
    local g = self.game
    local db = self.db
    db.run = nil
    db.games = db.games + 1
    local d
    if g.mode == "daily" and g.day == Today() then
        d = self:Daily()
        d.fails = (d.fails or 0) + 1
        d.open = false
    end
    local bx, by = self:CellXY(res.boom.r, res.boom.c)
    self:MineAt(res.boom.r, res.boom.c, 1.25)
    self:Burst(bx, by, { 1, 0.6, 0.2 }, 40, 260)
    self:Ring(bx, by, self.cell * 5, { 1, 0.7, 0.3 })
    self:Flash(1, 0.35, 0.1, 0.55)
    self:Shout("BOOM!", { 1, 0.45, 0.2 })
    W.SFX("rb_stomp")
    W.SFX("lose", 0.2)
    local mines, wrong = g:Reveal()
    -- the rest go off outwards from the first
    table.sort(mines, function(a, b)
        return (a.r - res.boom.r) ^ 2 + (a.c - res.boom.c) ^ 2 < (b.r - res.boom.r) ^ 2 + (b.c - res.boom.c) ^ 2
    end)
    local t = 0.25
    for _, m in ipairs(mines) do
        if not (m.r == res.boom.r and m.c == res.boom.c) then
            local mr, mc = m.r, m.c
            self.queue[#self.queue + 1] = { wait = t, fn = function()
                local cell = self:Cell(mr, mc)
                cell.cover:Hide()
                self:MineAt(mr, mc)
                local x, y = self:CellXY(mr, mc)
                self:Burst(x, y, { 1, 0.65, 0.3 }, 5, 110)
                W.SFX("pop" .. (1 + (mr + mc) % 8), 0.05)
            end }
            t = t + min(0.05, 1.2 / max(1, #mines))
        end
    end
    for _, w in ipairs(wrong) do
        local wr, wc = w.r, w.c
        self.queue[#self.queue + 1] = { wait = t, fn = function() self:CrossAt(wr, wc) end }
    end
    local safe = g:Safe()
    local pct = floor(100 * g.opened / max(1, safe))
    self.queue[#self.queue + 1] = { wait = t + 0.6, fn = function()
        local body = ("You dug |cffffffff%d|r of %d safe squares (%d%%) in %s."):format(g.opened, safe, pct, Clock(g:Time()))
        if d and not d.done then
            body = body .. ("\n\nThe Daily Sweep can be tried again: each time it blows up puts |cffffcc40%d seconds|r on the next try's clock."):format(RETRY_COST)
        end
        self.card:Open({
            title = "Boom!", color = COLORS.red, center = true, body = body,
            buttons = {
                { "Try again", function() self:Restart() end },
                { "Menu", function() self:ShowMenu() end, "ghost" },
            },
        })
    end }
end

function UI:Win()
    local g = self.game
    local db = self.db
    db.run = nil
    db.games = db.games + 1
    db.wins = db.wins + 1
    local time = floor(g:Time() * 10 + 0.5) / 10
    self:RedrawFlags()
    self:Flash(0.5, 1, 0.4, 0.35)
    self:Shout("Field cleared!", { 0.7, 1, 0.5 })
    W.SFX("win")
    for i = 1, 6 do
        self.queue[#self.queue + 1] = { wait = i * 0.12, fn = function()
            self:Burst(40 + math.random() * (BW - 80), -(40 + math.random() * (BW - 80)), { 0.8, 1, 0.5 }, 12, 200)
        end }
    end
    local body, buttons
    if g.mode == "daily" then
        local d = self:Daily()
        local today = g.day == d.date
        if today then d.open = false end
        if today and not d.done then
            d.done, d.best = true, time
            db.dailies = db.dailies + 1
            NS.Social:Submit("msd", d.date, time, Ordinal(max(1, d.tries or 1)) .. " try")
        end
        local rk, n = NS.Social:Rank("msd", d.date, "realm")
        body = ("Cleared in |cffffffff%s|r%s%s"):format(Clock(time),
            (g.penalty or 0) > 0 and ("\n(including %d seconds for earlier tries and the detector)"):format(g.penalty) or "",
            (rk and n > 1) and ("\n\nRank #%d of %d today"):format(rk, n) or "\n\nThat is your time for today.")
        buttons = {
            { "Leaderboard", function() self:ShowBoard("msd") end },
            { "Menu", function() self:ShowMenu() end, "ghost" },
        }
    else
        local size = Mines.Size(g.size)
        local old = db.best[size.key]
        local newBest = not old or time < old
        if newBest then db.best[size.key] = time end
        NS.Social:SubmitBest(size.board, time, ("%d cleared"):format(db.wins))
        body = ("%s cleared in |cffffffff%s|r%s%s"):format(size.name, Clock(time), newBest and "  |cff80ff80(new best!)|r" or "",
            (not newBest and old) and ("\nBest: " .. Clock(old)) or "")
        buttons = {
            { "Again", function() self:Begin("field", { size = size.key }) end },
            { "Leaderboard", function() self:ShowBoard(size.board) end },
            { "Menu", function() self:ShowMenu() end, "ghost" },
        }
    end
    self.queue[#self.queue + 1] = { wait = 1.1, fn = function()
        self.card:Open({ title = "Field cleared!", color = COLORS.gold, center = true, body = body, buttons = buttons })
    end }
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function UI:CursorCell()
    local x, y = GetCursorPosition()
    local s = self.board:GetEffectiveScale()
    local l, t = self.board:GetLeft(), self.board:GetTop()
    if not (l and t) or not self.cell then return end
    local bx, by = x / s - l, t - y / s
    local c, r = floor(bx / self.cell) + 1, floor(by / self.cell) + 1
    local n = self.game.n
    if r < 1 or c < 1 or r > n or c > n then return end
    return r, c
end

function UI:MouseDown(button)
    if self:Paused() or self.game.state ~= "play" then return end
    local r, c = self:CursorCell()
    self.down = r and { r = r, c = c, button = button } or nil
end

function UI:MouseUp(button)
    local d = self.down
    self.down = nil
    if not d or self:Paused() or self.game.state ~= "play" then return end
    local r, c = self:CursorCell()
    if r ~= d.r or c ~= d.c or button ~= d.button then return end
    local g = self.game
    local data = g.grid[r][c]
    local flagging = button == "RightButton" or (button == "LeftButton" and (self.db.flagMode or (IsShiftKeyDown and IsShiftKeyDown())))
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    if data.open then
        self:Apply(g:Chord(r, c))
    elseif flagging then
        if g:Flag(r, c) then
            W.SFX(data.flag and "knock" or "pop2", 0.03)
            self:RedrawFlags()
            self:Save()
            self:RefreshHUD()
        end
    else
        self:Apply(g:Dig(r, c))
    end
end

function UI:OnKey(key) return false end

function UI:Detect()
    if self:Paused() then return end
    local g = self.game
    local h = g:Detect()
    if not h then return end
    W.SFX("rb_arcane", 0.1)
    local x, y = self:CellXY(h.r, h.c)
    self:Ring(x, y, self.cell * 4, { 0.5, 1, 0.5 })
    self:PlaceMarks()
    self:Save()
    self:RefreshHUD()
end

---------------------------------------------------------------------------
-- Frame update, HUD
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    local g = self.game
    local paused = self:Paused()
    if not paused then
        g:Tick(el)
        self:StepQueue(el)
    end
    self:StepFades(el)
    self:UpdateFX(el)
    -- the square under the pointer
    local r, c
    if not paused and g.state == "play" and self.board:IsMouseOver() then r, c = self:CursorCell() end
    if r and not g.grid[r][c].open then
        local x, y = self:CellXY(r, c)
        self.hover:ClearAllPoints()
        self.hover:SetPoint("CENTER", self.board, "TOPLEFT", x, y)
        self.hover:SetSize(self.cell - 3, self.cell - 3)
        self.hover:Show()
    else
        self.hover:Hide()
    end
    if self.hintRing:IsShown() then
        local s = self.cell * (1.15 + 0.12 * sin(self.rt * 6))
        self.hintRing:SetSize(s, s)
        self.hintRing:SetAlpha(0.75 + 0.25 * sin(self.rt * 6))
    end
    if g.state == "play" then self.timeText:SetText(Clock(g:Time())) end
    -- the clock is part of the save, so it is written down now and then as it runs
    self.saveT = (self.saveT or 0) + el
    if self.saveT >= 5 then
        self.saveT = 0
        if g.state == "play" and self.db.run then self.db.run.elapsed = floor(g.elapsed * 10) / 10 end
    end
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.3; self:RefreshHUD() end
end

function UI:RefreshHUD()
    local g = self.game
    if not g or not self.timeText then return end
    local playing = g.state ~= "idle"
    if not playing then
        self.modeText:SetText("GOBLIN MINEFIELD")
        self.nameText:SetText("Pick a field")
        self.timeText:SetText("")
        self.rightLabel:SetText("")
        self.rightValue:SetText("")
        self.trayTitle:SetText("")
        self.trayLine:SetText("")
        self.minesValue:SetText("")
        self.minesLabel:SetText("")
        self.barBg:Hide(); self.bar:Hide(); self.traySub:Hide()
    else
        local spec = g.mode == "daily" and Mines.DAILY or Mines.Size(g.size)
        self.timeText:SetText(Clock(g:Time()))
        if g.mode == "daily" then
            local d = self:Daily()
            self.modeText:SetText("DAILY SWEEP")
            self.nameText:SetText("Same field for all")
            self.rightLabel:SetText("TODAY")
            self.rightValue:SetText(d.best and Clock(d.best) or "-")
        else
            self.modeText:SetText("GOBLIN MINEFIELD")
            self.nameText:SetText(spec.name)
            self.rightLabel:SetText("BEST")
            local best = self.db.best[spec.key]
            self.rightValue:SetText(best and Clock(best) or "-")
        end
        self.trayTitle:SetText(("%s  -  %d x %d"):format(spec.name, spec.n, spec.n))
        local safe = g:Safe()
        self.trayLine:SetText(("Dug %d of %d safe squares"):format(g.opened, safe))
        self.barBg:Show(); self.bar:Show(); self.traySub:Show()
        self.bar:SetWidth(max(1, 300 * min(1, g.opened / max(1, safe))))
        self.minesLabel:SetText("MINES LEFT")
        self.minesValue:SetText(tostring(g:MinesLeft()))
    end
    self.restartButton:SetShown(playing)
    self.detectButton:SetShown(playing)
    self.flagButton:SetShown(playing)
    if playing then
        local can = g.state == "play" and g.laid and (g.detectors or 0) > 0
        self.detectButton.text:SetText(("Detector (%d)"):format(g.detectors or 0))
        self.detectButton:SetAlpha(can and 1 or 0.45)
        self.flagButton.text:SetText(self.db.flagMode and "Flags: ON" or "Flags: off")
        self.flagButton:SetStyle(self.db.flagMode and "primary" or "ghost")
    end
end

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------
local function NewSeed()
    local t = (time and time() or 0) % 1000000
    local ms = floor(((GetTime and GetTime() or 0) % 1000) * 1000)
    return t * 89 + ms + 1
end

function UI:Begin(mode, opts)
    opts = opts or {}
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.fades, self.queue, self.down = {}, {}, nil
    self.shoutT = 0; self.shout:Hide()
    local g = self.game
    local opening
    if mode == "daily" then
        local d = self:Daily()
        if d.done then self:ShowBoard("msd"); return end
        -- a try that was walked away from (to restart it, or to play something else) is a failed
        -- try like any other: otherwise the opening could be studied with the clock stopped
        if d.open then d.fails = (d.fails or 0) + 1 end
        d.open = true
        d.tries = (d.tries or 0) + 1
        opening = g:Start("daily", { day = d.date, penalty = RETRY_COST * (d.fails or 0) })
    else
        local size = Mines.Size(opts.size or self.db.size)
        self.db.size = size.key
        g:Start("field", { size = size.key, seed = NewSeed() })
    end
    self:Layout()
    self:SyncAll()
    if opening and opening.opened and not NS.db.settings.reducedMotion then
        -- the day's opening blows clear as the field comes up
        for _, o in ipairs(opening.opened) do
            local cell = self:Cell(o.r, o.c)
            cell.cover:SetAlpha(1); cell.cover:Show(); cell.num:Hide()
            self.fades[#self.fades + 1] = { cell = cell, data = g.grid[o.r][o.c], wait = 0.2 + o.d * 0.03, t = 0 }
        end
    end
    self:Save()
    W.SFX("launch")
    self:RefreshHUD()
end

function UI:Restart()
    local g = self.game
    if g.state == "idle" then return end
    if g.mode == "daily" then
        local d = self:Daily()
        if g.state == "play" and d.open and not d.done then
            -- starting over is a failed try: say what it costs before it happens
            self.card:Open({
                title = "Start the Daily Sweep again?", color = TINT, center = true,
                body = ("Walking away from a try counts as blowing up: your next one starts with |cffffcc40%d seconds|r more on the clock."):format(RETRY_COST),
                buttons = { { "Start again", function() self:Begin("daily") end }, { "Keep digging", function() end, "ghost" } },
            })
        else
            self:Begin("daily")
        end
    else
        self:Begin("field", { size = g.size })
    end
end

---------------------------------------------------------------------------
-- Menu, boards, help
---------------------------------------------------------------------------
function UI:OnShow()
    self:RefreshHUD()
    -- the first visit starts with how to play (its button leads on to the menu)
    if not self.db.seenHelp then
        self.db.seenHelp = true
        if self.game.state ~= "play" then self:ShowHelp(); return end
    end
    if self.game.state ~= "play" and not self.card:IsShown() and not self.boardPanel:IsShown() and #self.queue == 0 then self:ShowMenu() end
end

function UI:OnHide()
    self.down = nil
    self:FinishFx()
    local g = self.game
    if g.state == "play" then self:Save() end
end

function UI:ShowMenu()
    self:FinishFx()
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local g = self.game
    local d = self:Daily()
    local playing = g.state == "play"
    local bests = {}
    for _, s in ipairs(Mines.SIZES) do
        bests[#bests + 1] = ("%s |cffffffff%s|r"):format(s.name, db.best[s.key] and Clock(db.best[s.key]) or "-")
    end
    local lines = {
        "Best times:  " .. table.concat(bests, "    "),
        ("Fields cleared |cffffffff%d|r of %d"):format(db.wins, db.games),
        ("Today's Daily Sweep: %s"):format(d.done and ("cleared in |cffffffff" .. Clock(d.best) .. "|r")
            or ((d.fails or 0) > 0 and ("blown up %d time%s"):format(d.fails, d.fails == 1 and "" or "s") or "not swept yet")),
    }
    local rl = NS.Social:RankLine("msd", d.date)
    if rl then lines[#lines + 1] = "Daily: " .. rl end
    local buttons = {}
    if playing then buttons[#buttons + 1] = { "Resume", function() end } end
    for _, s in ipairs(Mines.SIZES) do
        buttons[#buttons + 1] = { ("%s  %dx%d"):format(s.name, s.n, s.n), function() self:Begin("field", { size = s.key }) end, playing and "ghost" or nil }
    end
    if not (playing and g.mode == "daily") then
        -- a try left half done will cost its 30 seconds when the next one starts
        local owed = RETRY_COST * ((d.fails or 0) + (d.open and 1 or 0))
        buttons[#buttons + 1] = { d.done and "Daily: cleared" or (owed > 0 and ("Daily Sweep  +%ds"):format(owed) or "Daily Sweep"), function() self:Begin("daily") end }
    end
    if #buttons < 6 then buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end } end
    local options = NS.CommonOptions()
    table.insert(options, 1, { "Flag mode: left click plants flags (for trackpads)", function() return db.flagMode end, function(v) db.flagMode = v; self:RefreshHUD() end })
    self.menu:Open({
        title = "Goblin Minefield", sub = "Dig everything but the mines", icon = "Interface\\Icons\\INV_Misc_Bomb_04",
        color = TINT, lines = lines, buttons = buttons, options = options,
    })
end

function UI:ShowBoard(which)
    self:FinishFx()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    local views = {}
    local start = 1
    for i, s in ipairs(Mines.SIZES) do
        views[i] = { label = s.name, game = s.board, periods = true, title = s.name, sub = ("Fastest clears, %d x %d with %d mines"):format(s.n, s.n, s.mines) }
        if which == s.board or (not which and s.key == self.db.size) then start = i end
    end
    views[#views + 1] = { label = "Daily Sweep", game = "msd", periods = false, period = "day", title = "Daily Sweep", sub = "Today's field is the same for everyone" }
    if which == "msd" then start = #views end
    self.boardPanel:Open({
        views = views, view = start,
        empty = "Nobody has cleared this one yet.",
        fmt = function(e) return Clock(e.s), e.d or "" end,
        onClose = function() if self.game.state ~= "play" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    self:FinishFx()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.boardPanel:IsShown() then self.boardPanel:Hide() end
    self.card:Open({
        title = "Goblin Minefield", color = TINT,
        body = table.concat({
            "The goblins have mined the field. |cffffcc40Dig|r every square that has no mine under it, as fast as you can.",
            "",
            "A dug square shows how many of the eight squares round it are mined. A blank one opens everything round it. Your first dig is always safe.",
            "",
            "|cffffcc40Left click|r digs. |cffffcc40Right click|r plants a flag (so does Shift-click, or the Flags button). Click a |cffffcc40number|r with that many flags round it to dig the rest at once.",
            "",
            ("The |cffffcc40Detector|r rings one safe square, once a field, for %d seconds on your clock."):format(Mines.DETECT_COST),
            "",
            ("|cffffcc40Daily Sweep|r: one field for everyone. Each time it blows up adds %d seconds to your next try; your first clear is your time for the day."):format(RETRY_COST),
        }, "\n"),
        buttons = { { "Start digging", function() if self.game.state ~= "play" then self:ShowMenu() end end } },
    })
end

function UI:Banner() end
