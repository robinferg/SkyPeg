-- Flight Buddy :: FlapUI.lua
-- Featherbeard tab: Warcraft Rumble's Gryphon Rider, threading the pillars of Dun Morogh.
-- Free flights and a Daily Ironforge Run (same pillars for everyone, with a ghost of your best),
-- Close Shaves, Stoneform runes, a quest board with Gryphon Rider ranks, and instant restarts.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Flap = NS.Flap
local C = Flap.C

local UI = {}
NS.FlapUI = UI

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local MEDIA = "flap\\"
local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local STONE_ICON = "Interface\\Icons\\Spell_Shadow_UnholyStrength"
local GHOST_STEP = 6                       -- the ghost records the gryphon's height every 6 units flown
local RESTART_DELAY = 0.35                 -- after a crash, the next flap starts a new flight this soon
local MEDAL_TINT = { platinum = { 0.78, 0.92, 1 } }
local MEDAL_FILE = { platinum = "gold" }

-- the realm's game day (turns over at the daily reset), shown as YYYY-MM-DD
local function Today()
    local d = NS.Social and NS.Social.Today() or (date and date("%Y%m%d")) or "20260101"
    return d:sub(1, 4) .. "-" .. d:sub(5, 6) .. "-" .. d:sub(7, 8)
end

-- Gryphons to fly: cosmetic only (every gryphon flies the same, so the leaderboards stay fair).
-- Until each has its own painting they share the Wildhammer art in a new colour.
UI.GRYPHONS = {
    { key = "wildhammer", name = "Wildhammer Gryphon", line = "Featherbeard's own mount", tint = { 1, 1, 1 } },
    { key = "aerie",      name = "Aerie Peak Ember",   line = "Sunset-feathered", tint = { 1, 0.72, 0.5 },   best = 10 },
    { key = "frost",      name = "Frostwing",          line = "Bred in the Dun Morogh snows", tint = { 0.68, 0.84, 1 }, best = 25 },
    { key = "ebon",       name = "Ebonwing",           line = "Night-flight courier", tint = { 0.5, 0.46, 0.62 }, best = 50 },
    { key = "golden",     name = "Thane's Gold",       line = "For the very best riders", tint = { 1, 0.86, 0.38 }, best = 75 },
    { key = "spectral",   name = "Spectral Gryphon",   line = "Finish 30 daily runs", tint = { 0.6, 1, 0.85 }, dailies = 30 },
}
UI.GRYPHON = {}
for _, gr in ipairs(UI.GRYPHONS) do UI.GRYPHON[gr.key] = gr end

function UI:Init(db)
    self.db = db -- FlightBuddyDB.flap
    db.best = db.best or 0
    db.games = db.games or 0
    db.medals = db.medals or {}
    db.coinsTotal = db.coinsTotal or 0
    db.quests = db.quests or {}
    db.daily = db.daily or {}
    db.mode = db.mode or "free"
    db.gryphon = db.gryphon or "wildhammer"
    db.dailyRuns = db.dailyRuns or 0
    Flap.FillQuests(db.quests)
end

local function Tex(parent, file, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(W.MEDIA .. MEDIA .. file) end
    return t
end

local function MedalTex(t, medal)
    t:SetTexture(W.MEDIA .. "rb_medal_" .. (MEDAL_FILE[medal] or medal))
    local c = MEDAL_TINT[medal]
    if c then t:SetVertexColor(c[1], c[2], c[3]) else t:SetVertexColor(1, 1, 1) end
end

local function Cap(s) return s:sub(1, 1):upper() .. s:sub(2) end

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
    self.title = W.Text(hud, 22, FONT_TITLE, "OUTLINE")
    self.title:SetPoint("TOP", 0, -4)
    self.title:SetText("Featherbeard")
    self.title:SetTextColor(1, 0.85, 0.45)
    self.sub = W.Text(hud, 11, W.FONT)
    self.sub:SetPoint("TOP", self.title, "BOTTOM", 0, -3)
    self.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.bestText = W.Text(hud, 12, W.FONT_NUM)
    self.bestText:SetPoint("TOPRIGHT", -2, -8)
    self.bestText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.rankText = W.Text(hud, 11, W.FONT)
    self.rankText:SetPoint("TOPLEFT", 2, -8)
    self.rankText:SetWidth(156)          -- two short lines, clear of the title in the middle
    self.rankText:SetJustifyH("LEFT")
    self.rankText:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    -- the sky
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(C.W, C.H)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    holder:SetClipsChildren(true)
    self.holder = holder
    local area = CreateFrame("Frame", nil, holder)  -- shakes inside the clipped holder
    area:SetSize(C.W, C.H)
    area:SetPoint("TOPLEFT")
    self.area = area
    -- far scenery: the painting twice, the second mirrored, so it scrolls without a seam
    self.far = {}
    local farH = C.GROUND
    local farW = farH * 2
    for i = 1, 3 do
        local t = Tex(area, "bg_far", "BACKGROUND", -8)
        t:SetSize(farW, farH)
        if i % 2 == 0 then t:SetTexCoord(1, 0, 0, 1) end
        self.far[i] = t
    end
    self.farW = farW
    self.ground = {}
    for i = 1, 4 do
        local t = Tex(area, "ground", "ARTWORK", 5)
        t:SetSize(160, 48)
        self.ground[i] = t
    end
    self.spires = {}
    self.shadow = W.Tex(area, "ARTWORK", "glow", 1)
    self.shadow:SetVertexColor(0, 0, 0, 0.45)
    -- today's best, flying alongside you on the Daily Run
    self.ghost = Tex(area, "flyer_2", "OVERLAY", 0)
    self.ghost:SetSize(92, 92)
    self.ghost:SetVertexColor(0.75, 0.85, 1)
    self.ghost:SetAlpha(0.32)
    self.ghost:Hide()
    self.stoneGlow = W.Tex(area, "OVERLAY", "glow", 1)
    self.stoneGlow:SetSize(120, 120)
    self.stoneGlow:SetBlendMode("ADD")
    self.stoneGlow:SetVertexColor(0.75, 0.8, 0.95)
    self.stoneGlow:Hide()
    self.bird = Tex(area, "flyer_2", "OVERLAY", 2)
    self.bird:SetSize(92, 92)
    self.frameT, self.frame_ = 0, 2
    self.coins, self.runes = {}, {}
    -- big score
    self.scoreShadow = W.Text(area, 46, FONT_SHOUT, "THICKOUTLINE")
    self.scoreShadow:SetPoint("TOP", area, "TOP", 3, -27)
    self.scoreShadow:SetTextColor(0.1, 0.05, 0.02, 0.8)
    self.scoreText = W.Text(area, 46, FONT_SHOUT, "THICKOUTLINE")
    self.scoreText:SetPoint("TOP", area, "TOP", 0, -24)
    self.scoreText:SetTextColor(1, 0.9, 0.5)
    self.coinText = W.Text(area, 14, W.FONT_NUM, "OUTLINE")
    self.coinText:SetPoint("TOPLEFT", area, "TOPLEFT", 12, -12)
    self.stoneIcon = area:CreateTexture(nil, "OVERLAY", nil, 4)
    self.stoneIcon:SetTexture(STONE_ICON)
    self.stoneIcon:SetSize(30, 30)
    self.stoneIcon:SetPoint("TOPRIGHT", area, "TOPRIGHT", -12, -12)
    self.stoneIcon:Hide()
    -- the prompt and the shout line
    self.prompt = W.Text(area, 18, FONT_TITLE, "OUTLINE")
    self.prompt:SetPoint("CENTER", area, "CENTER", 0, -80)
    self.prompt:SetTextColor(1, 0.95, 0.8)
    self.promptSub = W.Text(area, 12, W.FONT, "OUTLINE")
    self.promptSub:SetPoint("TOP", self.prompt, "BOTTOM", 0, -8)
    self.promptSub:SetTextColor(0.9, 0.86, 0.76)
    self.shout = W.Text(area, 30, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", area, "CENTER", 0, 120)
    self.shout:SetShadowColor(0, 0, 0, 1); self.shout:SetShadowOffset(2, -2)
    self.shoutSub = W.Text(area, 15, FONT_TITLE, "OUTLINE")
    self.shoutSub:SetPoint("TOP", self.shout, "BOTTOM", 0, -4)
    self.shoutT = 0
    -- particles (feathers, sparkles, stone chips)
    self.parts = {}
    for i = 1, 80 do
        local t = W.Tex(area, "OVERLAY", "glow", 3)
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.flash = W.Solid(area, "OVERLAY", 1, 1, 1, 0, 7)
    self.flash:SetAllPoints()

    self:BuildResult(holder)

    -- input: click anywhere in the sky to flap
    local function down(_, button)
        if self:Paused() or button ~= "LeftButton" then return end
        self:DoFlap()
    end
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", down)
    local catcher = CreateFrame("Frame", nil, f)
    catcher:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    catcher:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 44)
    catcher:SetFrameLevel(f:GetFrameLevel())
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", down)
    self.catcher = catcher

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10); bar:SetPoint("BOTTOMRIGHT", -20, 10); bar:SetHeight(30)
    bar:SetFrameLevel(f:GetFrameLevel() + 4)
    self.modeFree = W.Button(bar, 84, 26, "Free flight")
    self.modeFree:SetPoint("LEFT", 0, 0)
    self.modeFree:SetScript("OnClick", function() self:SetMode("free") end)
    self.modeDaily = W.Button(bar, 84, 26, "Daily run")
    self.modeDaily:SetPoint("LEFT", self.modeFree, "RIGHT", 6, 0)
    self.modeDaily:SetScript("OnClick", function() self:SetMode("daily") end)
    local help = W.Button(bar, 60, 26, "Help", "ghost")
    help:SetPoint("RIGHT", 0, 0)
    help:SetScript("OnClick", function() self:ShowHelp() end)
    local quests = W.Button(bar, 70, 26, "Quests", "ghost")
    quests:SetPoint("RIGHT", help, "LEFT", -6, 0)
    quests:SetScript("OnClick", function() self:ShowQuests() end)
    self.questsButton = quests
    local scores = W.Button(bar, 70, 26, "Scores", "ghost")
    scores:SetPoint("RIGHT", quests, "LEFT", -6, 0)
    scores:SetScript("OnClick", function() self:ShowBoard() end)
    self.scoresButton = scores
    local menu = W.Button(bar, 60, 26, "Menu", "ghost")
    menu:SetPoint("RIGHT", scores, "LEFT", -6, 0)
    menu:SetScript("OnClick", function() self:ShowMenu() end)
    self.menuButton = menu

    self.card = W.Card(f, holder)
    self.menu = NS.NewMenuPanel(f, holder)
    self.board = NS.NewBoardPanel(f, holder)
    self.picker = NS.NewPickerPanel(f, holder)
    self.picker:HookScript("OnHide", function() if self.game and self.game.state == "ready" and not self.board:IsShown() then self:ShowMenu() end end)
    self.game = Flap.New({ owner = self, flap = UI.OnFlap, score = UI.OnScore, coin = UI.OnCoin, hit = UI.OnHit,
                           over = UI.OnOver, start = UI.OnStart, shave = UI.OnShave, stoneform = UI.OnStoneform,
                           shrug = UI.OnShrug })
    f:SetScript("OnUpdate", function(_, el) W.Guard("Featherbeard", self.OnUpdate, self, el) end)
    self:SetMode(self.db.mode, true)
end

-- the end-of-flight panel: not a modal card, so a flap goes straight back into the air
function UI:BuildResult(holder)
    local r = CreateFrame("Frame", nil, holder)
    r:SetSize(330, 248)
    r:SetPoint("CENTER", 0, 30)
    r:SetFrameLevel(holder:GetFrameLevel() + 10)
    local bg = W.Solid(r, "BACKGROUND", 0.07, 0.05, 0.035, 0.9)
    bg:SetAllPoints()
    W.Border(r, 0.1)
    r.title = W.Text(r, 22, FONT_TITLE, "OUTLINE")
    r.title:SetPoint("TOP", 0, -14)
    r.medal = r:CreateTexture(nil, "ARTWORK")
    r.medal:SetSize(84, 84)
    r.medal:SetPoint("TOPLEFT", 26, -50)
    r.medalLabel = W.Text(r, 12, W.FONT)
    r.medalLabel:SetPoint("TOP", r.medal, "BOTTOM", 0, -2)
    r.scoreLabel = W.Text(r, 11, W.FONT)
    r.scoreLabel:SetPoint("TOPRIGHT", -48, -54)
    r.scoreLabel:SetText("SCORE")
    r.scoreLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    r.score = W.Text(r, 40, FONT_SHOUT, "THICKOUTLINE")
    r.score:SetPoint("TOP", r.scoreLabel, "BOTTOM", 0, -2)
    r.best = W.Text(r, 13, W.FONT_NUM)
    r.best:SetPoint("TOP", r.score, "BOTTOM", 0, -4)
    r.lines = W.Text(r, 12, W.FONT)
    r.lines:SetPoint("TOP", 0, -158)
    r.lines:SetWidth(300)
    if r.lines.SetSpacing then r.lines:SetSpacing(3) end
    r.again = W.Text(r, 13, W.FONT, "OUTLINE")
    r.again:SetPoint("BOTTOM", 0, 10)
    r.again:SetTextColor(1, 0.95, 0.8)
    r:Hide()
    self.result = r
end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.board:IsShown()
        or (self.picker and self.picker:IsShown())
end

function UI:IsBusy() return self.game and self.game.state == "play" end

function UI:GryphonUnlocked(gr)
    local db = self.db
    if gr.best and (db.best or 0) < gr.best then return false end
    if gr.dailies and (db.dailyRuns or 0) < gr.dailies then return false end
    return true
end

function UI:Gryphon()
    local gr = UI.GRYPHON[self.db.gryphon]
    if not gr or not self:GryphonUnlocked(gr) then gr = UI.GRYPHONS[1] end
    return gr
end

function UI:ShowGryphons()
    if self.menu:IsShown() then self.menu:Hide() end
    local items = {}
    for _, gr in ipairs(UI.GRYPHONS) do
        local open = self:GryphonUnlocked(gr)
        items[#items + 1] = {
            key = gr.key, name = gr.name, line = gr.line, desc = gr.line, tint = gr.tint,
            icon = W.MEDIA .. MEDIA .. "flyer_2", locked = not open,
            lockText = gr.best and ("Best flight %d  (yours %d)"):format(gr.best, self.db.best or 0)
                or ("%d daily runs  (%d so far)"):format(gr.dailies or 0, self.db.dailyRuns or 0),
        }
    end
    self.picker:Open({
        title = "Choose your gryphon", color = { 1, 0.82, 0.4 },
        sub = "Every gryphon flies the same. Fly further to unlock more.",
        items = items, selected = self:Gryphon().key,
        onPick = function(key) self.db.gryphon = key; self:Refresh() end,
    })
end

function UI:OnShow()
    if not self.db.seenHelp then
        self.db.seenHelp = true
        self:ShowHelp()
    elseif self.game.state == "ready" then
        self:ShowMenu()
    end
    self:Refresh()
end

function UI:OnHide()
    -- a run in progress can't sensibly resume mid-air, so it ends
    if self.game and (self.game.state == "play" or self.game.state == "dead") then
        self:ResetRun()
    end
end

function UI:OnKey(key)
    if self:Paused() then return false end
    if key == "SPACE" or key == "W" or key == "UP" then self:DoFlap(); return true end
    return false
end

---------------------------------------------------------------------------
-- Modes, runs
---------------------------------------------------------------------------
function UI:Daily()
    local d = self.db.daily
    local today = Today()
    if d.date ~= today then
        d.date, d.best, d.ghost, d.tries = today, 0, nil, 0
    end
    return d
end

function UI:SetMode(mode, quiet)
    if self.game and (self.game.state == "play" or self.game.state == "dead") then return end
    self.db.mode = (mode == "daily") and "daily" or "free"
    self.modeFree:SetStyle(self.db.mode == "free" and "primary" or "ghost")
    self.modeDaily:SetStyle(self.db.mode == "daily" and "primary" or "ghost")
    self:ResetRun()
    if not quiet then W.SFX("pop1") end
end

function UI:Seed()
    if self.db.mode == "daily" then return Flap.DailySeed(self:Daily().date) end
    return floor((time() % 100000) * 7 + ((GetTime and GetTime() or 0) * 100) % 97) + 1
end

function UI:ResetRun()
    local g = self.game
    g.seedNext = self:Seed()
    g:Reset(g.seedNext)
    self.result:Hide()
    self.ghostRec = {}
    self.ghostRun = nil
    if self.db.mode == "daily" then
        local d = self:Daily()
        self.ghostRun = d.ghost
    end
    self.medalSeen = nil
    self:Refresh()
end

function UI:DoFlap()
    local g = self.game
    if g.state == "dead" then return end
    if g.state == "over" then
        if (self.overT or 0) < RESTART_DELAY then return end
        self:ResetRun()
    end
    if g.state == "ready" then g.seedNext = self:Seed() end
    g:Flap()
end

function UI:Refresh()
    local db = self.db
    local g = self.game
    if db.mode == "daily" then
        local d = self:Daily()
        self.sub:SetText("Daily Ironforge Run  -  " .. d.date .. "  -  the same pillars for everyone today")
        self.bestText:SetText("Today's best " .. (d.best or 0))
    else
        self.sub:SetText("A gryphon's flight over Dun Morogh")
        self.bestText:SetText("Best " .. db.best)
    end
    local stars = db.quests.stars or 0
    local rank, nextAt = Flap.Rank(stars)
    self.rankText:SetText(("%s\n|cffffcc40%d|r stars%s"):format(rank, stars, nextAt and ("  (next rank at " .. nextAt .. ")") or ""))
    local playing = g and g.state ~= "ready"
    self.scoreText:SetText(playing and g.score or "")
    self.scoreShadow:SetText(playing and g.score or "")
    self.coinText:SetText(playing and ("|TInterface\\AddOns\\FlightBuddy\\Media\\flap\\coin:16|t " .. g.coins) or "")
    local ready = g and g.state == "ready"
    self.prompt:SetText(ready and "Click or press Space to fly" or "")
    if ready then
        local q = {}
        for _, id in ipairs(db.quests.active or {}) do
            local qq = Flap.QUEST[id]
            if qq then q[#q + 1] = "- " .. qq.text end
        end
        self.promptSub:SetText(#q > 0 and ("Quests\n" .. table.concat(q, "\n")) or "")
    else
        self.promptSub:SetText("")
    end
    self.stoneIcon:SetShown(g and g.stoneform)
end

function UI:Shout(text, sub, c, dur)
    c = c or { 1, 0.85, 0.4 }
    self.shout:SetText(text)
    self.shout:SetTextColor(c[1], c[2], c[3])
    self.shoutSub:SetText(sub or "")
    self.shoutT, self.shoutMax = dur or 1.1, dur or 1.1
    self.shout:Show(); self.shoutSub:Show()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
function UI:Spire(i)
    local s = self.spires[i]
    if s then return s end
    s = {}
    local a = self.area
    s.top = Tex(a, nil, "ARTWORK", 0)
    s.top:SetTexture(W.MEDIA .. MEDIA .. "column", "REPEAT", "REPEAT")
    s.bot = Tex(a, nil, "ARTWORK", 0)
    s.bot:SetTexture(W.MEDIA .. MEDIA .. "column", "REPEAT", "REPEAT")
    s.capTop = Tex(a, "cap_down", "ARTWORK", 1)
    s.capBot = Tex(a, "cap_up", "ARTWORK", 1)
    s.capTop:SetSize(C.PILLAR_W + 28, 36)
    s.capBot:SetSize(C.PILLAR_W + 28, 36)
    self.spires[i] = s
    return s
end

function UI:Coin(i)
    local c = self.coins[i]
    if c then return c end
    c = Tex(self.area, "coin", "OVERLAY", 1)
    c:SetSize(22, 22)
    self.coins[i] = c
    return c
end

function UI:Rune(i)
    local r = self.runes[i]
    if r then return r end
    r = {}
    r.glow = W.Tex(self.area, "OVERLAY", "glow", 0)
    r.glow:SetBlendMode("ADD")
    r.glow:SetVertexColor(0.8, 0.85, 1)
    r.glow:SetSize(64, 64)
    r.icon = self.area:CreateTexture(nil, "OVERLAY", nil, 1)
    r.icon:SetTexture(STONE_ICON)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icon:SetSize(28, 28)
    self.runes[i] = r
    return r
end

function UI:Draw(el)
    local g, a = self.game, self.area
    local dist = g.dist or 0
    local farOff = (dist * 0.25) % (self.farW * 2)
    for i, t in ipairs(self.far) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", a, "TOPLEFT", (i - 1) * self.farW - farOff, 0)
    end
    local gOff = dist % 160
    for i, t in ipairs(self.ground) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", a, "TOPLEFT", (i - 1) * 160 - gOff, -(C.GROUND - 8))
    end
    local n, cn, rn = 0, 0, 0
    for _, p in ipairs(g.pillars) do
        n = n + 1
        local s = self:Spire(n)
        local top, bot = p.gapY - p.gap / 2, p.gapY + p.gap / 2
        local x = p.x
        if p.broken then
            for _, t in ipairs({ s.top, s.bot, s.capTop, s.capBot }) do t:Hide() end
        else
            s.top:ClearAllPoints(); s.top:SetPoint("TOPLEFT", a, "TOPLEFT", x, 0)
            s.top:SetSize(C.PILLAR_W, max(1, top - 18))
            s.top:SetTexCoord(0, 1, 0, max(0.01, (top - 18) / 128))
            s.bot:ClearAllPoints(); s.bot:SetPoint("TOPLEFT", a, "TOPLEFT", x, -(bot + 18))
            s.bot:SetSize(C.PILLAR_W, max(1, C.GROUND - bot - 18))
            s.bot:SetTexCoord(0, 1, 0, max(0.01, (C.GROUND - bot - 18) / 128))
            s.capTop:ClearAllPoints(); s.capTop:SetPoint("BOTTOM", a, "TOPLEFT", x + C.PILLAR_W / 2, -top)
            s.capBot:ClearAllPoints(); s.capBot:SetPoint("TOP", a, "TOPLEFT", x + C.PILLAR_W / 2, -bot)
            for _, t in ipairs({ s.top, s.bot, s.capTop, s.capBot }) do t:Show() end
            -- moving spires carry a faint blue rune-light on their caps
            local tint = p.amp and 0.82 or 1
            s.capTop:SetVertexColor(tint, tint + 0.05, 1); s.capBot:SetVertexColor(tint, tint + 0.05, 1)
        end
        if p.coin and not p.coin.taken then
            cn = cn + 1
            local c = self:Coin(cn)
            local spin = abs(cos((self.rt or 0) * 4 + p.x * 0.02))
            c:SetSize(22 * max(0.15, spin), 22)
            c:ClearAllPoints(); c:SetPoint("CENTER", a, "TOPLEFT", p.coin.x, -p.coin.y)
            c:Show()
        end
        if p.rune and not p.rune.taken then
            rn = rn + 1
            local r = self:Rune(rn)
            local bob = sin((self.rt or 0) * 3) * 3
            r.glow:ClearAllPoints(); r.glow:SetPoint("CENTER", a, "TOPLEFT", p.rune.x, -(p.rune.y + bob))
            r.icon:ClearAllPoints(); r.icon:SetPoint("CENTER", a, "TOPLEFT", p.rune.x, -(p.rune.y + bob))
            r.glow:SetAlpha(0.55 + 0.25 * sin((self.rt or 0) * 5))
            r.glow:Show(); r.icon:Show()
        end
    end
    for i = n + 1, #self.spires do
        local s = self.spires[i]
        for _, t in ipairs({ s.top, s.bot, s.capTop, s.capBot }) do t:Hide() end
    end
    for i = cn + 1, #self.coins do self.coins[i]:Hide() end
    for i = rn + 1, #self.runes do self.runes[i].glow:Hide(); self.runes[i].icon:Hide() end
    -- wings beat after a flap, glide otherwise; tilt with speed
    self.frameT = self.frameT - el
    if self.frameT <= 0 then
        if g.state == "ready" or self.beat then
            self.frame_ = self.frame_ % 3 + 1
            self.frameT = 0.07
            if self.frame_ == 2 then self.beat = (self.beat or 1) - 1; if self.beat <= 0 then self.beat = nil end end
        elseif g.state == "play" then
            self.frame_ = 2
        end
        -- a gryphon with its own painting uses flyer_<key>_1..3; the rest recolour the Wildhammer art
        local gr = self:Gryphon()
        self.bird:SetTexture(W.MEDIA .. MEDIA .. (gr.art and ("flyer_" .. gr.key .. "_") or "flyer_") .. self.frame_)
    end
    local tilt = (g.state == "ready") and 0 or max(-0.45, min(1.2, g.vy / 600))
    if g.state == "over" then tilt = 1.3 end
    self.bird:ClearAllPoints()
    self.bird:SetPoint("CENTER", a, "TOPLEFT", C.X, -g.y)
    if self.bird.SetRotation then self.bird:SetRotation(-tilt * 0.6) end
    -- Stoneform: the gryphon turns to grey stone and glows; blinks while passing through a spire
    if g.stoneform then self.bird:SetVertexColor(0.72, 0.74, 0.82)
    else
        local gr = self:Gryphon()
        local tint = gr.art and { 1, 1, 1 } or gr.tint
        self.bird:SetVertexColor(tint[1], tint[2], tint[3])
    end
    self.bird:SetAlpha((g.ghostT or 0) > 0 and (0.5 + 0.5 * abs(sin((self.rt or 0) * 30))) or 1)
    self.stoneGlow:SetShown(g.stoneform)
    if g.stoneform then
        self.stoneGlow:ClearAllPoints(); self.stoneGlow:SetPoint("CENTER", a, "TOPLEFT", C.X, -g.y)
        self.stoneGlow:SetAlpha(0.45 + 0.2 * sin((self.rt or 0) * 4))
    end
    -- the ghost of today's best Daily Run
    local gr = self.ghostRun
    if gr and g.state == "play" and not self.db.hideGhost then
        local i = floor(dist / GHOST_STEP) + 1
        local gy = gr[i]
        if gy then
            self.ghost:ClearAllPoints()
            self.ghost:SetPoint("CENTER", a, "TOPLEFT", C.X, -gy)
            self.ghost:Show()
        else
            self.ghost:Hide()
        end
    else
        self.ghost:Hide()
    end
    local h = (C.GROUND - g.y) / C.GROUND
    self.shadow:SetSize(50 * (1 - h * 0.5), 8)
    self.shadow:SetAlpha(0.35 * (1 - h))
    self.shadow:ClearAllPoints(); self.shadow:SetPoint("CENTER", a, "TOPLEFT", C.X, -(C.GROUND + 2))
end

function UI:Particle(x, y, vx, vy, life, size, c, gravity)
    self.partIdx = self.partIdx % #self.parts + 1
    local p = self.parts[self.partIdx]
    p.x, p.y, p.vx, p.vy, p.life, p.max, p.size, p.g = x, y, vx, vy, life, life, size, gravity or 300
    p.t:SetVertexColor(c[1], c[2], c[3])
    p.t:Show()
end

function UI:Burst(x, y, c, n, sp, life, size, grav)
    if NS.db.settings.reducedMotion then n = floor(n / 3) end
    for k = 1, n do
        local a = k / n * 2 * pi + math.random() * 0.4
        local s = sp * (0.5 + math.random() * 0.7)
        self:Particle(x, y, cos(a) * s, sin(a) * s, life or 0.45, size or 9, c, grav or 0)
    end
end

function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    local g = self.game
    -- hit-stop: freeze for a couple of frames when you crash
    if (self.freeze or 0) > 0 then
        self.freeze = self.freeze - el
    elseif not self:Paused() then
        g:Update(el)
    end
    -- record the flight for the Daily Run ghost
    if g.state == "play" and self.ghostRec then
        local i = floor((g.dist or 0) / GHOST_STEP) + 1
        if not self.ghostRec[i] then self.ghostRec[i] = floor(g.y + 0.5) end
    end
    if g.state == "over" then self.overT = (self.overT or 0) + el end
    self:Draw(el)
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then p.t:Hide() else
                p.vy = p.vy + p.g * el
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local k = p.life / p.max
                p.t:SetSize(p.size * (0.4 + 0.6 * k), p.size * (0.4 + 0.6 * k))
                p.t:SetPoint("CENTER", self.area, "TOPLEFT", p.x, -p.y)
                p.t:SetAlpha(k)
            end
        end
    end
    local fa = self.flash:GetAlpha()
    if fa > 0 then self.flash:SetAlpha(max(0, fa - el * 3)) end
    -- screen shake
    if (self.shakeT or 0) > 0 and not NS.db.settings.reducedMotion then
        self.shakeT = self.shakeT - el
        local k = max(0, self.shakeT) / 0.3 * (self.shakeAmp or 7)
        self.area:ClearAllPoints()
        self.area:SetPoint("TOPLEFT", (math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k)
    elseif self.shakeT then
        self.shakeT = nil
        self.area:ClearAllPoints(); self.area:SetPoint("TOPLEFT")
    end
    if self.shoutT > 0 then
        self.shoutT = self.shoutT - el
        local a = min(1, self.shoutT * 4, (self.shoutMax - self.shoutT) * 10 + 0.3)
        self.shout:SetAlpha(a); self.shoutSub:SetAlpha(a)
        if self.shoutT <= 0 then self.shout:Hide(); self.shoutSub:Hide() end
    end
    if self.result:IsShown() then
        self.result.again:SetText((self.overT or 0) >= RESTART_DELAY and "Flap to fly again" or "")
    end
end

function UI:Shake(t, amp)
    self.shakeT, self.shakeAmp = t, amp
end

---------------------------------------------------------------------------
-- Engine events
---------------------------------------------------------------------------
function UI:OnStart()
    self.result:Hide()
    self.overT = 0
    if self.db.mode == "daily" then
        local d = self:Daily()
        d.tries = (d.tries or 0) + 1
    end
    self:Refresh()
end

function UI:OnFlap()
    self.beat = 2
    self.frame_ = 1
    self.frameT = 0
    W.SFX("flap_wing", 0.04)
    if not NS.db.settings.reducedMotion then
        for _ = 1, 3 do
            self:Particle(C.X - 22, self.game.y + 8, -60 - math.random() * 50, 10 + math.random() * 50, 0.5, 7, { 0.95, 0.85, 0.7 }, 120)
        end
    end
end

function UI:OnScore(score, shave)
    self:Refresh()
    if not shave then W.SFX("coin_win", 0.05) end
    -- medal milestones, the moment you reach them
    local medal = Flap.Medal(score)
    if medal and medal ~= self.medalSeen then
        local first = not self.medalSeen
        self.medalSeen = medal
        if score < 76 or first then
            self:Shout(Cap(medal) .. " medal!", "Huzzah!", { 1, 0.86, 0.4 }, 1.3)
            self.flash:SetAlpha(0.35)
            W.SFX("win")
        end
    end
end

local SHAVE_WORDS = { "Close Shave!", "Whisker close!", "Beard-trimmer!", "Hair's breadth!", "Thane-level flying!" }
function UI:OnShave(chain, bonus)
    W.SFX("style", 0.05)
    self:Shout(SHAVE_WORDS[min(chain, #SHAVE_WORDS)], chain > 1 and ("x" .. chain .. " in a row  +" .. bonus) or ("+" .. bonus), { 0.55, 0.9, 1 }, 0.9)
    self:Burst(C.X + 10, self.game.y, { 0.6, 0.9, 1 }, 10, 140, 0.4, 7)
end

function UI:OnCoin(x, y, score)
    self:Refresh()
    W.SFX("pop3", 0.05)
    self:Burst(x, y, { 1, 0.85, 0.3 }, 10, 120)
end

function UI:OnStoneform(x, y)
    W.SFX("power")
    self:Shout("Stoneform!", "Your next crash just chips the stone", { 0.8, 0.85, 1 }, 1.2)
    self:Burst(x, y, { 0.8, 0.85, 1 }, 16, 150)
    self:Refresh()
end

function UI:OnShrug(x, y)
    W.SFX("knock")
    self:Shake(0.25, 6)
    self.freeze = 0.05
    self:Burst(x, y, { 0.75, 0.7, 0.62 }, 22, 220, 0.7, 10, 500)
    self:Shout("Shrugged it off!", nil, { 0.85, 0.85, 0.95 }, 0.9)
    self:Refresh()
end

function UI:OnHit(why)
    self.flash:SetAlpha(0.7)
    self.freeze = 0.07
    self:Shake(0.3, 8)
    W.SFX("knock")
    for _ = 1, 14 do
        self:Particle(C.X, self.game.y, (math.random() - 0.5) * 260, -math.random() * 220, 0.8, 8, { 0.95, 0.88, 0.75 }, 500)
    end
end

function UI:OnOver(score, coins)
    local db, g = self.db, self.game
    db.games = db.games + 1
    db.coinsTotal = db.coinsTotal + coins
    local daily = db.mode == "daily"
    local newBest
    if daily then
        local d = self:Daily()
        newBest = score > (d.best or 0)
        if newBest then
            d.best = score
            local rec = {}
            for i, v in ipairs(self.ghostRec or {}) do rec[i] = v end
            d.ghost = rec
        end
    end
    local allBest = score > db.best
    if allBest then db.best = score end
    if not daily then newBest = allBest end
    local medal = Flap.Medal(score)
    if medal then db.medals[medal] = (db.medals[medal] or 0) + 1 end
    -- quests
    local run = { passed = g.passed, coins = coins, shaves = g.shaves, chain = g.bestChain, stone = g.stoneUsed,
                  daily = daily and 1 or 0, score = score, flights = 1 }
    local done = Flap.ApplyRun(db.quests, run)
    local rank = Flap.Rank(db.quests.stars or 0)
    if daily then self.db.dailyRuns = (self.db.dailyRuns or 0) + 1 end
    if daily then NS.Social:Submit("flapd", NS.Social.Today(), score, rank)
    else NS.Social:SubmitBest("flap", score, rank) end
    -- the panel
    local r = self.result
    r.title:SetText(score >= 75 and "Falstad would weep!" or (score >= 50 and "Ironforge legend!" or (score >= 10 and "Nice flying!" or "Grounded!")))
    r.title:SetTextColor(1, 0.85, 0.45)
    if medal then
        MedalTex(r.medal, medal); r.medal:SetDesaturated(false); r.medal:SetAlpha(1)
        r.medalLabel:SetText(Cap(medal) .. " medal")
    else
        MedalTex(r.medal, "bronze"); r.medal:SetDesaturated(true); r.medal:SetAlpha(0.35)
        r.medalLabel:SetText("Bronze at 10")
    end
    r.score:SetText(score)
    r.score:SetTextColor(1, 0.9, 0.5)
    local bestLine = daily and ("Today's best " .. (self:Daily().best or 0)) or ("Best " .. db.best)
    r.best:SetText(newBest and "|cff3be870New best!|r" or bestLine)
    local lines = {}
    lines[#lines + 1] = ("Pillars %d   Coins %d   Close Shaves %d%s"):format(g.passed, coins, g.shaves,
        g.bestChain > 1 and ("  (best chain " .. g.bestChain .. ")") or "")
    local nm, at = Flap.NextMedal(score)
    if nm then lines[#lines + 1] = "|cff9499b3Next: " .. nm .. " at " .. at .. "|r" end
    for _, q in ipairs(done) do
        lines[#lines + 1] = ("|cffffcc40Quest complete:|r %s  |cffffcc40+%d star%s|r"):format(q.text, q.stars, q.stars == 1 and "" or "s")
    end
    r.lines:SetText(table.concat(lines, "\n"))
    r:SetHeight(200 + #done * 18)
    self.overT = 0
    r:Show()
    if #done > 0 then W.SFX("freeball") end
    self:Refresh()
end

function UI:ShowQuests()
    local db = self.db
    local qs = db.quests
    Flap.FillQuests(qs)
    local lines = {}
    local stars = qs.stars or 0
    local rank, nextAt = Flap.Rank(stars)
    lines[#lines + 1] = ("|cffffcc40%s|r  -  %d stars%s"):format(rank, stars, nextAt and ("  (next rank at " .. nextAt .. ")") or "")
    lines[#lines + 1] = ""
    for _, id in ipairs(qs.active) do
        local q = Flap.QUEST[id]
        if q then
            local p = qs.progress[id] or 0
            lines[#lines + 1] = ("%s\n|cff9499b3%s%d / %d   reward %d star%s|r"):format(q.text, q.total and "total " or "best ",
                min(p, q.goal), q.goal, q.stars, q.stars == 1 and "" or "s")
            lines[#lines + 1] = ""
        end
    end
    local m = db.medals
    lines[#lines + 1] = ("Medals  |cffbfe6ffplatinum %d|r  |cffffcc40gold %d|r  |cffd8d8e8silver %d|r  |cffd08a50bronze %d|r"):format(
        m.platinum or 0, m.gold or 0, m.silver or 0, m.bronze or 0)
    lines[#lines + 1] = ("Flights %d   Coins collected %d"):format(db.games, db.coinsTotal or 0)
    self.card:Open({
        title = "Aerie Quest Board", color = { 1, 0.8, 0.4 }, body = table.concat(lines, "\n"),
        buttons = { { "Back to the skies", function() self:Refresh() end } },
    })
end

function UI:ShowHelp()
    self.card:Open({
        title = "Featherbeard", color = { 1, 0.8, 0.4 },
        body = table.concat({
            "Fly a Wildhammer gryphon rider between the pillars of Dun Morogh.",
            "",
            "|cffffcc40Click|r anywhere in the sky, or press |cffffcc40Space|r, to flap.",
            "Each pillar you pass is a point. Grab the |cffffcc40gold coins|r for more.",
            "Skim a pillar without touching it for a |cff8fd8ffClose Shave|r: chain them for up to +3 each.",
            "Grab a |cffc8d0ffStoneform rune|r and your next crash just chips the stone.",
            "",
            "|cffffcc40Daily run|r: today's pillars are the same for everyone, and your best flies beside you as a ghost.",
            "Finish quests for stars and climb the Gryphon Rider ranks.",
            "Medals: |cffd08a50bronze|r 10   |cffd8d8e8silver|r 25   |cffffcc40gold|r 50   |cffbfe6ffplatinum|r 75",
        }, "\n"),
        buttons = { { "Let's fly", function() self:Refresh() end } },
    })
end

---------------------------------------------------------------------------
-- Menu and leaderboards
---------------------------------------------------------------------------
function UI:ShowMenu()
    if self.board:IsShown() then self.board:Hide() end
    local db = self.db
    local stars = db.quests.stars or 0
    local rank, nextAt = Flap.Rank(stars)
    local d = self:Daily()
    local m = db.medals
    local lines = {
        ("|cffffcc40%s|r  -  %d stars%s     Gryphon: |cffffcc40%s|r"):format(rank, stars, nextAt and ("  (next rank at " .. nextAt .. ")") or "", self:Gryphon().name),
        ("Best flight |cffffffff%d|r     Flights %d     Coins %d"):format(db.best, db.games, db.coinsTotal or 0),
        ("Today's Daily Ironforge Run: %s"):format((d.best or 0) > 0 and ("best |cffffffff" .. d.best .. "|r in " .. (d.tries or 0) .. " tries") or "not flown yet"),
        ("Medals  |cffbfe6ffplatinum %d|r  |cffffcc40gold %d|r  |cffd8d8e8silver %d|r  |cffd08a50bronze %d|r"):format(m.platinum or 0, m.gold or 0, m.silver or 0, m.bronze or 0),
    }
    local rl = NS.Social:RankLine("flap", "all")
    if rl then lines[#lines + 1] = "Best flight: " .. rl end
    local options = NS.CommonOptions()
    table.insert(options, 1, { "Show the ghost of your best on the daily run", function() return not db.hideGhost end, function(v) db.hideGhost = not v end })
    self.menu:Open({
        title = "Featherbeard", sub = "A gryphon's flight over Dun Morogh", icon = "Interface\\Icons\\Ability_Mount_Gryphon_01",
        color = { 1, 0.82, 0.4 }, lines = lines,
        buttons = {
            { "Free flight", function() self:SetMode("free") end },
            { "Daily run", function() self:SetMode("daily") end },
            { "Choose gryphon", function() self:ShowGryphons() end },
            { "Leaderboards", function() self:ShowBoard() end },
            { "Quest board", function() self:ShowQuests() end },
            { "How to play", function() self:ShowHelp() end, "ghost" },
        },
        options = options,
    })
end

function UI:ShowBoard()
    if self.menu:IsShown() then self.menu:Hide() end
    local daily = self.db.mode == "daily"
    local function post(game, label)
        return function()
            local mine = NS.Social:Mine(game, game == "flapd" and NS.Social.Today() or "all")
            if mine then SendChatMessage(("[Flight Buddy] Featherbeard %s: %d"):format(label, mine.s), "GUILD") end
        end
    end
    self.board:Open({
        empty = "No flights here yet. Go set the bar!",
        fmt = function(e) return tostring(e.s), e.d or "" end,
        views = {
            { label = "Free flight", game = "flap", periods = true, title = "Featherbeard leaderboard", sub = "Best flights",
              onPost = post("flap", "best flight") },
            { label = "Daily run", game = "flapd", periods = false, period = "day", title = "Daily Ironforge Run",
              sub = "Today's pillars are the same for everyone", onPost = post("flapd", "daily run") },
        },
        view = daily and 2 or 1,
        onClose = function() self:Refresh() end,
    })
end
