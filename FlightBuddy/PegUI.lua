-- Flight Buddy :: PegUI.lua
-- SkyPeg tab: rendering, effects, input and result cards.
local ADDON, NS = ...

local UI = {}
NS.Peg = UI

local W = NS.W
local Game = NS.Game
local C = Game.C
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"
local FONT_SHOUT = "Fonts\\SKURRI.TTF"   -- WoW's chunky combat-number font
local FONT_TITLE = "Fonts\\MORPHEUS.TTF" -- WoW's quest-title font

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local atan2 = math.atan2

local WIN_W, WIN_H = 520, 712
local CANVAS_X, CANVAS_Y = 20, -110

local COLORS = {
    blue      = { 0.25, 0.58, 1.00 }, blueLit   = { 0.70, 0.90, 1.00 },
    orange    = { 1.00, 0.50, 0.10 }, orangeLit = { 1.00, 0.86, 0.45 },
    green     = { 0.22, 0.90, 0.42 }, greenLit  = { 0.72, 1.00, 0.78 },
    purple    = { 0.76, 0.36, 1.00 }, purpleLit = { 0.95, 0.78, 1.00 },
    gold      = { 1.00, 0.80, 0.25 },
    accent    = { 1.00, 0.62, 0.18 },
    text      = { 0.92, 0.93, 0.96 },
    dim       = { 0.58, 0.61, 0.70 },
    panel     = { 0.055, 0.060, 0.085 },
}
UI.COLORS = COLORS
local HEX = {
    orange = "ff8a1f", blue = "4c99ff", purple = "c25cff", green = "3be870", gold = "ffcc40", dim = "9499b3",
}

local FEVER_COLORS = {
    { 0.25, 0.58, 1.00 }, { 0.30, 0.90, 0.45 }, { 1.00, 0.80, 0.20 }, { 0.30, 0.90, 0.45 }, { 0.25, 0.58, 1.00 },
}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Commas(n)
    n = floor(n + 0.5)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end
UI.Commas = Commas

local function Tex(parent, layer, file, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(MEDIA .. file) end
    return t
end

local function Solid(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function Text(parent, size, font, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or FONT, size, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.75)
    fs:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    return fs
end

local function Border(f, a)
    local r, g, b = 1, 1, 1
    local top = Solid(f, "BORDER", r, g, b, a); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    local bot = Solid(f, "BORDER", r, g, b, a); bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    local lft = Solid(f, "BORDER", r, g, b, a); lft:SetPoint("TOPLEFT"); lft:SetPoint("BOTTOMLEFT"); lft:SetWidth(1)
    local rgt = Solid(f, "BORDER", r, g, b, a); rgt:SetPoint("TOPRIGHT"); rgt:SetPoint("BOTTOMRIGHT"); rgt:SetWidth(1)
end

-- the shared tavern button (brass plate / oak plank)
local function Button(parent, w, h, label, style) return W.Button(parent, w, h, label, style) end

local lastPegSound = 0
local function Sound(name, throttle)
    local db = NS.db
    if not db or not db.settings.sound then return end
    if throttle then
        local now = GetTime()
        if now - lastPegSound < throttle then return end
        lastPegSound = now
    end
    local id = SOUNDKIT and SOUNDKIT[name]
    if id then pcall(PlaySound, id, "SFX") end
end
UI.Sound = Sound
local SFX = function(...) return NS.W.SFX(...) end

---------------------------------------------------------------------------
-- Init / open / close
---------------------------------------------------------------------------
function UI:Init(db)
    self.db = db
    local handlers = {}
    for ev, fn in pairs(self.Events) do
        handlers[ev] = function(...) if self.frame then fn(self, ...) end end
    end
    self.game = Game.New(handlers)
    db.cleared = db.cleared or 0
    if not (db.hero and Game.HERO[db.hero] and self:HeroUnlocked(db.hero)) then db.hero = "thrall" end
    self.game.hero = db.hero
    db.stats = db.stats or {}
    if not (db.ball and self:BallUnlocked(db.ball)) then db.ball = "steel" end
    self.skin = UI.BALL[db.ball]
    self:CheckBallUnlocks(db.ballsWon == nil)   -- feats already met before skins existed unlock silently
    if not (db.run and self.game:Restore(db.run)) then
        self.game:NewRun(time())
    end
    self.aim = pi / 2
end

local function ShellModal() return NS.Shell and NS.Shell:IsModal() end

function UI:IsBusy()
    local st = self.game and self.game.state
    return st == "shot" or st == "clearing"
end

function UI:OnShow()
    if not self.db.seenHelp then
        self.db.seenHelp = true
        self:ShowHelp()
    elseif not self.overlay:IsShown() then
        if self.game.state == "won" or self.game.state == "lost" then self:ShowStateCard()
        elseif (self.game.turn or 0) == 0 then self:ShowMenu() end
    end
end

function UI:OnHide()
    self:SaveRun()
end

function UI:OnKey(key)
    if key == "SPACE" and self.db.settings.space and self.game.state == "aim" and not self.modal then
        self:Fire()
        return true
    end
    return false
end

function UI:HeroUnlocked(key)
    if Game.HERO_START[key] then return true end
    local need = Game.HERO_UNLOCK[key]
    return need ~= nil and (self.db.cleared or 0) >= need
end

-- Ball skins: won by feats, never bought. tex is the 64px sprite, trail/glow the colour it leaves behind.
UI.BALLS = {
    { key = "steel",   name = "Steel Ball",       tex = "ball2",        trail = { 0.75, 0.85, 1.00 }, feat = "Yours from the start" },
    { key = "hearth",  name = "Hearthstone",      tex = "ball_hearth",  trail = { 0.35, 0.85, 1.00 }, feat = "Clear your first stage",              stat = "cleared",   need = 1 },
    { key = "snow",    name = "Snowball",         tex = "ball_snow",    trail = { 0.85, 0.93, 1.00 }, feat = "Clear Dun Morogh Peaks (stage 3)",    stat = "cleared",   need = 3 },
    { key = "gear",    name = "Gnomish Gearball", tex = "ball_gear",    trail = { 1.00, 0.75, 0.30 }, feat = "Fire 200 shots",                      stat = "shots",     need = 200 },
    { key = "bomb",    name = "Goblin Bomb",      tex = "ball_bomb",    trail = { 1.00, 0.35, 0.20 }, feat = "Break 15 runes with one shot",        stat = "bestCombo", need = 15 },
    { key = "pumpkin", name = "Hallow's Pumpkin", tex = "ball_pumpkin", trail = { 1.00, 0.60, 0.15 }, feat = "Land in the gryphon's catch 13 times", stat = "catches",  need = 13 },
    { key = "pearl",   name = "Mana Pearl",       tex = "ball_pearl",   trail = { 0.60, 1.00, 0.95 }, feat = "Clear a stage with 5 balls to spare", stat = "bestSpare", need = 5 },
    { key = "lava",    name = "Lava Core",        tex = "ball_lava",    trail = { 1.00, 0.45, 0.10 }, feat = "Break 500 fire crystals",             stat = "crystals",  need = 500 },
    { key = "arcane",  name = "Arcane Orb",       tex = "ball_arcane",  trail = { 0.85, 0.45, 1.00 }, feat = "Clear 8 stages in one run",           stat = "cleared",   need = 8 },
    { key = "egg",     name = "Gryphon Egg",      tex = "ball_egg",     trail = { 1.00, 0.85, 0.35 }, feat = "Land the 100,000 chest 3 times",      stat = "goldChest", need = 3 },
    { key = "fel",     name = "Fel Orb",          tex = "ball_fel",     trail = { 0.45, 1.00, 0.20 }, feat = "Clear all 16 stages in one run",      stat = "cleared",   need = 16 },
}
UI.BALL = {}
for _, b in ipairs(UI.BALLS) do UI.BALL[b.key] = b end

function UI:BallStat(stat)
    if stat == "cleared" then return self.db.cleared or 0 end
    return self.db.stats[stat] or 0
end

function UI:BallUnlocked(key)
    local b = UI.BALL[key]
    if not b then return false end
    return not b.stat or self:BallStat(b.stat) >= b.need
end

function UI:ApplyBall()
    local skin = UI.BALL[self.db.ball] or UI.BALLS[1]
    self.skin = skin
    if not self.loaded then return end
    local file = MEDIA .. skin.tex
    self.loaded:SetTexture(file)
    for _, s in ipairs(self.ballSprites) do s.body:SetTexture(file) end
    for _, t in ipairs(self.pips) do t:SetTexture(skin.key == "steel" and (MEDIA .. "ball") or file) end
end

function UI:SetBall(key)
    if not self:BallUnlocked(key) then return end
    self.db.ball = key
    self:ApplyBall()
end

-- bump a best-of stat; returns nothing, unlock banners come from CheckBallUnlocks
function UI:StatMax(stat, v) if v > (self.db.stats[stat] or 0) then self.db.stats[stat] = v end end
function UI:StatAdd(stat, n) self.db.stats[stat] = (self.db.stats[stat] or 0) + (n or 1) end

-- announce any skin whose feat has just been met
function UI:CheckBallUnlocks(quiet)
    local db = self.db
    db.ballsWon = db.ballsWon or {}
    local new
    for _, b in ipairs(UI.BALLS) do
        if b.stat and not db.ballsWon[b.key] and self:BallUnlocked(b.key) then
            db.ballsWon[b.key] = true
            new = b
        end
    end
    if new and not quiet and self.banner then
        self.ballNews = { title = "New ball: " .. new.name, sub = new.feat .. " - pick it under Ball skins in the menu" }
        self.ballNewsT = 2.4   -- let the shot or level banner play first
    end
end

function UI:SetHero(key)
    self.db.hero = key
    local g = self.game
    -- swap now if the level hasn't started (or is over); otherwise from the next level
    if (g.turn or 0) == 0 or g.state == "won" or g.state == "lost" then
        g.hero = key
        self:RestyleAll()
    end
    self:RefreshHUD(true)
end

function UI:NewRun()
    if self.overlay then self:HideCard() end
    self.game:NewRun(time())
    self:SaveRun()
end

function UI:RestyleAll()
    if not self.frame then return end
    for _, peg in ipairs(self.game.pegs) do if peg.alive and peg.sprite then self:StylePeg(peg) end end
end

function UI:SaveRun()
    local g = self.game
    if not g then return end
    if g.state == "won" then
        self.db.run = { v = 1, seed = g.runSeed, level = g.level + 1, score = 0,
                        levelStartScore = 0, balls = C.BALLS, bestShot = g.bestShot }
    elseif g.state == "lost" then
        self.db.run = { v = 1, seed = g.runSeed, level = g.level, score = 0,
                        levelStartScore = 0, balls = C.BALLS, bestShot = g.bestShot }
    else
        self.db.run = g:Serialize()
    end
    self:RecordLevelScore()
end

-- best score per level (and the best on any level)
function UI:RecordLevelScore()
    local g, db = self.game, self.db
    db.levelBest = db.levelBest or {}
    local key = tostring(g.level)
    if g.score > (db.levelBest[key] or 0) then db.levelBest[key] = g.score; return true end
end

function UI:LevelBest()
    local db = self.db
    return (db.levelBest and db.levelBest[tostring(self.game.level)]) or 0
end

---------------------------------------------------------------------------
-- Build the window
---------------------------------------------------------------------------
function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetAllPoints(parent)
    f:Hide()
    self.headerTint = Tex(f, "BACKGROUND", "gradient", -7)
    self.headerTint:SetPoint("TOPLEFT", 1, -34); self.headerTint:SetPoint("TOPRIGHT", -1, -34); self.headerTint:SetHeight(130)

    self:BuildHUD(f)
    self:BuildCanvas(f)
    self:BuildBottomBar(f)
    self:BuildCard(f)

    f:SetScript("OnUpdate", function(_, el) NS.W.Guard("SkyPeg", self.OnUpdate, self, el) end)
    self:ApplyBall()
    self:OnLevelVisuals()
end

function UI:BuildHUD(f)
    local hud = CreateFrame("Frame", nil, f)
    hud:SetPoint("TOPLEFT", 20, -38)
    hud:SetPoint("TOPRIGHT", -20, -38)
    hud:SetHeight(66)

    self.levelLabel = Text(hud, 11, FONT_NUM)
    self.levelLabel:SetPoint("TOPLEFT", 2, -8)
    self.levelLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.zoneLabel = Text(hud, 14)
    self.zoneLabel:SetPoint("TOPLEFT", self.levelLabel, "BOTTOMLEFT", 0, -4)
    self.zoneLabel:SetWidth(170)
    self.zoneLabel:SetJustifyH("LEFT")
    self.bestLabel = Text(hud, 11, FONT_NUM)
    self.bestLabel:SetPoint("TOPLEFT", self.zoneLabel, "BOTTOMLEFT", 0, -4)
    self.bestLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    self.scoreText = Text(hud, 28, FONT_NUM)
    self.scoreText:SetPoint("TOP", 0, -6)
    self.scoreText:SetTextColor(1, 1, 1)
    self.shotText = Text(hud, 13, FONT_NUM)
    self.shotText:SetPoint("TOP", self.scoreText, "BOTTOM", 0, -2)
    self.shotText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local bl = Text(hud, 11, FONT_NUM)
    bl:SetPoint("TOPRIGHT", -2, -8)
    bl:SetText("BALLS")
    bl:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.ballsText = Text(hud, 24, FONT_NUM)
    self.ballsText:SetPoint("TOPRIGHT", bl, "BOTTOMRIGHT", 0, -1)
    self.pips = {}
    for i = 1, 12 do
        local t = Tex(hud, "ARTWORK", "ball")
        t:SetSize(9, 9)
        t:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -2 - (i - 1) * 11, -52)
        self.pips[i] = t
    end
    self.pipMore = Text(hud, 10, FONT_NUM)
    self.pipMore:SetPoint("RIGHT", self.pips[12], "LEFT", -3, 0)
end

function UI:BuildCanvas(f)
    -- clicking anywhere on the SkyPeg screen fires, not just on the board
    local catcher = CreateFrame("Frame", nil, f)
    catcher:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    catcher:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then self:Fire() end end)

    local view = CreateFrame("Frame", nil, f)
    self.view = view
    view:SetSize(C.W, C.H)
    view:SetPoint("TOPLEFT", f, "TOPLEFT", CANVAS_X, CANVAS_Y)
    if view.SetClipsChildren then view:SetClipsChildren(true) end
    local cv = CreateFrame("Frame", nil, view)
    self.canvas = cv
    cv:SetSize(C.W, C.H)
    cv:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
    cv:EnableMouse(true)
    if cv.EnableMouseWheel then cv:EnableMouseWheel(true) end

    self.bgTop = Solid(cv, "BACKGROUND", 0.1, 0.1, 0.2, 1, -8)
    self.bgTop:SetAllPoints()
    self.bgGrad = Tex(cv, "BACKGROUND", "gradient", -7)
    self.bgGrad:SetAllPoints()
    if self.bgGrad.SetTexCoord then self.bgGrad:SetTexCoord(0, 1, 1, 0) end -- flip: tint grows toward the bottom
    self.bgArt = cv:CreateTexture(nil, "BACKGROUND", nil, -6)
    self.bgArt:SetAllPoints()
    self.bgArt:SetTexCoord(0.03, 0.97, 0, 1) -- 512x512 art onto a 480x560 board
    self.bgDim = Solid(cv, "BACKGROUND", 0, 0, 0, 0.3, -4)
    self.bgDim:SetAllPoints()
    self.vignette = Tex(cv, "BACKGROUND", "vignette", 5)
    self.vignette:SetAllPoints()
    self.vignette:SetAlpha(0.55)
    Border(cv, 0.07)

    -- drifting clouds (you're flying, after all)
    self.clouds = {}
    for i = 1, 6 do
        local t = Tex(cv, "BACKGROUND", "cloud", -3)
        local w = 150 + (i * 37) % 90
        t:SetSize(w, w * 0.5)
        t:SetAlpha(0.05 + (i % 3) * 0.015)
        self.clouds[i] = { t = t, x = (i * 97) % (C.W + 200) - 100, y = 90 + (i * 83) % 420, spd = 8 + (i * 5) % 14, w = w }
    end

    -- launcher
    -- dwarven rune cannon hanging from a gryphon crest; the ball sits in its muzzle
    self.barrel = Tex(cv, "ARTWORK", "rb_cannon", 5)
    self.barrel:SetSize(66, 66)
    self.barrel:SetPoint("CENTER", cv, "TOPLEFT", C.LX, -C.LY)
    self.launchBase = Tex(cv, "ARTWORK", "rb_mount", 6)
    self.launchBase:SetSize(46, 46)
    self.launchBase:SetPoint("CENTER", cv, "TOPLEFT", C.LX, -C.LY + 9)
    self.loaded = Tex(cv, "OVERLAY", "ball2", 1)
    self.loaded:SetSize(C.BALL_R * 2 + 2, C.BALL_R * 2 + 2)

    -- aim preview
    self.dots = {}
    for i = 1, 161 do
        local t = Tex(cv, "ARTWORK", "circle", 4)
        t:SetSize(5, 5)
        t:Hide()
        self.dots[i] = t
    end
    self.target = Tex(cv, "OVERLAY", "ring", 0)
    self.target:SetSize(30, 30)
    self.target:Hide()
    self.previewBuf = {}

    -- bucket
    self.bucketGlow = Tex(cv, "ARTWORK", "glow", -2)
    self.bucketGlow:SetBlendMode("ADD")
    self.bucketGlow:SetSize(120, 50)
    self.bucketGlow:SetVertexColor(1, 0.75, 0.25, 0.35)
    self.bucketTex = Tex(cv, "ARTWORK", "rb_nest", 3)
    self.bucketTex:SetSize(C.BUCKET_W + C.RIM_R * 2 + 14, 26)
    -- the gryphon: wings either side of the basket
    self.wingL = Tex(cv, "ARTWORK", "rb_wing", 2)
    self.wingR = Tex(cv, "ARTWORK", "rb_wing", 2)
    self.wingL:SetTexCoord(1, 0, 0, 1)
    self.wingL:SetSize(54, 32); self.wingR:SetSize(54, 32)

    -- Bloodlust payout: WoW's own reward chests (your faction's), dim for 10K, bright for 50K,
    -- glowing for 100K, with stone pillars between them
    self.slots = {}
    local n = #Game.FEVER_SLOTS
    local sw = C.W / n
    local TIER = { [10000] = "iron", [50000] = "silver", [100000] = "gold" }
    local LABEL = { [10000] = "rb_num_10k", [50000] = "rb_num_50k", [100000] = "rb_num_100k" }
    local faction = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "horde" or "alliance"
    local top = Game.FEVER_TOP
    for i = 1, n do
        local s = {}
        local cx = (i - 0.5) * sw
        local col = FEVER_COLORS[i]
        local v = Game.FEVER_SLOTS[i]
        s.glow = Tex(cv, "ARTWORK", "glow", 1)
        s.glow:SetBlendMode("ADD")
        s.glow:SetSize(sw + 20, 90)
        s.glow:SetPoint("CENTER", cv, "TOPLEFT", cx, -(top + 22))
        s.glow:SetVertexColor(col[1], col[2], col[3], 0.5)
        -- the chest body is 140 px tall in a 300 px frame: size it to fill the chest row
        s.bg = Tex(cv, "ARTWORK", "rb_chest_" .. faction .. "_" .. TIER[v], 2)
        local size = (C.H - top + 2) * 300 / 140
        s.bg:SetSize(size, size)
        s.bg:SetPoint("CENTER", cv, "TOPLEFT", cx, -((top + C.H) / 2 + 1))
        -- the value: pre-rendered gold numerals, laid across the front of the chest
        s.text = Tex(cv, "OVERLAY", LABEL[v], 1)
        local big = v >= 100000
        s.text:SetSize(big and 104 or 92, big and 26 or 23)
        s.text:SetPoint("CENTER", cv, "TOPLEFT", cx, -(C.H - 13))
        s.shadow = s.text  -- (the shadow is baked into the numerals)
        s.cx = cx
        s.bg:Hide(); s.glow:Hide(); s.text:Hide()
        self.slots[i] = s
    end
    self.pillars = {}
    for k = 1, n - 1 do
        local p = Tex(cv, "ARTWORK", "rb_post", 3)
        p:SetSize(10, C.H - top + 4)
        p:SetPoint("TOP", cv, "TOPLEFT", k * sw, -top)
        p:Hide()
        self.pillars[k] = p
    end
    -- prize medallions on brass posts between the chests (bronze on the walls, silver, gold by the 100K chest)
    self.bumpers = {}
    local MEDAL = { [0] = "bronze", "silver", "gold", "gold", "silver", "bronze" }
    for k = 0, n do
        local d = Game.BUMPER_R * 2 + 6
        local bmp = Tex(cv, "OVERLAY", "rb_medal_" .. (MEDAL[k] or "silver"), 1)
        bmp:SetSize(d, d)
        bmp:SetPoint("CENTER", cv, "TOPLEFT", k * sw, -(top - 4))
        bmp.flash = Tex(cv, "OVERLAY", "glow", 0)
        bmp.flash:SetBlendMode("ADD")
        bmp.flash:SetSize(d * 1.9, d * 1.9)
        bmp.flash:SetPoint("CENTER", bmp, "CENTER")
        bmp.flash:SetVertexColor(1, 0.8, 0.45)
        bmp.flash:SetAlpha(0.25)
        bmp:Hide(); bmp.flash:Hide()
        bmp.d, bmp.pop = d, 0
        self.bumpers[k] = bmp
    end
    -- gold coins that burst out of a chest when a ball drops in
    self.coins = {}
    for i = 1, 24 do
        local t = cv:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t:Hide()
        self.coins[i] = { t = t, life = 0 }
    end
    self.coinIdx = 0
    -- the payout callout: big pre-rendered gold numerals and a line in quest-title lettering
    self.payout = CreateFrame("Frame", nil, cv)
    self.payout:SetSize(320, 80)
    self.payout:SetPoint("CENTER", cv, "TOPLEFT", C.W / 2, -(C.H - 150))
    self.payout:SetFrameLevel(cv:GetFrameLevel() + 8)
    self.payout.rays = Tex(self.payout, "BACKGROUND", "glow", 0)
    self.payout.rays:SetBlendMode("ADD")
    self.payout.rays:SetPoint("CENTER")
    self.payout.rays:SetSize(380, 150)
    self.payout.rays:SetVertexColor(1, 0.7, 0.25, 0.55)
    self.payout.num = Tex(self.payout, "ARTWORK", "rb_pay_100k", 0)
    self.payout.num:SetAllPoints()
    self.payout.sub = Text(self.payout, 18, FONT_TITLE, "OUTLINE")
    self.payout.sub:SetPoint("TOP", self.payout, "BOTTOM", 0, 6)
    self.payout.sub:SetTextColor(1, 0.93, 0.76)
    self.payout:Hide()

    -- balls
    self.ballSprites = {}
    for i = 1, 6 do
        local s = {}
        s.glow = Tex(cv, "OVERLAY", "glow", -2)
        s.glow:SetBlendMode("ADD")
        s.body = Tex(cv, "OVERLAY", "ball2", 2)
        s.body:SetSize(C.BALL_R * 2 + 2, C.BALL_R * 2 + 2)
        s.glow:Hide(); s.body:Hide()
        self.ballSprites[i] = s
    end

    -- particles
    self.parts = {}
    self.partIdx = 0
    for i = 1, 180 do
        local t = Tex(cv, "OVERLAY", "glow", 3)
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end

    self.sparks, self.sparkIdx = {}, 0
    for i = 1, 24 do
        local t = Tex(cv, "OVERLAY", "sparkle", 4)
        t:SetBlendMode("ADD"); t:Hide()
        self.sparks[i] = { t = t, life = 0 }
    end
    -- spell lines: lightning bolts, earthquake cracks, arrows (each a jagged run of segments)
    self.lines = {}
    self.segs = {}
    for i = 1, 160 do
        local t = cv:CreateTexture(nil, "OVERLAY", nil, 5)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:Hide()
        self.segs[i] = t
    end
    self.misha = Tex(cv, "OVERLAY", "rb_misha", 6)
    self.misha:SetSize(84, 84)
    self.misha:Hide()
    self.shocks, self.shockIdx = {}, 0
    for i = 1, 10 do
        local t = Tex(cv, "OVERLAY", "shock", 4)
        t:SetBlendMode("ADD"); t:Hide()
        self.shocks[i] = { t = t, life = 0 }
    end

    -- foreground layer for text effects (does not zoom with the board)
    local fx = CreateFrame("Frame", nil, view)
    fx:SetAllPoints()
    fx:SetFrameLevel(cv:GetFrameLevel() + 8)
    self.fx = fx
    self.floats = {}
    for i = 1, 28 do
        local fs = Text(fx, 14, FONT_SHOUT, "THICKOUTLINE")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(2, -2)
        fs:Hide()
        self.floats[i] = { fs = fs, life = 0 }
    end
    self.floatIdx = 0
    -- shouts: WoW's chunky combat font with a heavy drop shadow, the line under it in quest-title lettering
    -- a dark ribbon behind the shout so it reads on any board, like WoW's raid warnings
    self.bannerRibbon = Solid(fx, "BACKGROUND", 0.03, 0.02, 0.01, 0.82)
    self.bannerEdgeT = Solid(fx, "BORDER", 1, 0.8, 0.3, 0.9); self.bannerEdgeB = Solid(fx, "BORDER", 1, 0.8, 0.3, 0.9)
    self.bannerEdgeT:SetHeight(2); self.bannerEdgeB:SetHeight(2)
    self.bannerEdgeT:SetPoint("BOTTOMLEFT", self.bannerRibbon, "TOPLEFT"); self.bannerEdgeT:SetPoint("BOTTOMRIGHT", self.bannerRibbon, "TOPRIGHT")
    self.bannerEdgeB:SetPoint("TOPLEFT", self.bannerRibbon, "BOTTOMLEFT"); self.bannerEdgeB:SetPoint("TOPRIGHT", self.bannerRibbon, "BOTTOMRIGHT")
    self.bannerEdgeT:Hide(); self.bannerEdgeB:Hide()
    self.bannerRibbon:SetPoint("LEFT", fx, "LEFT", 0, 58)
    self.bannerRibbon:SetPoint("RIGHT", fx, "RIGHT", 0, 58)
    self.bannerRibbon:SetHeight(78)
    -- hero splash: the hero leans in over the ribbon when their power fires
    self.splashGlow = Tex(fx, "ARTWORK", "glow", 0)
    self.splashGlow:SetBlendMode("ADD")
    self.splashGlow:SetSize(250, 250)
    self.splash = fx:CreateTexture(nil, "ARTWORK", nil, 2)
    self.splash:SetSize(176, 176)
    self.splashGlow:SetPoint("CENTER", self.splash, "CENTER")
    self.splash:Hide(); self.splashGlow:Hide()
    self.splashT = 0
    self.bannerShadow = Text(fx, 12, FONT_TITLE)     -- kept for older code paths; never shown
    self.banner = Text(fx, 30, FONT_TITLE, "OUTLINE")
    self.banner:SetPoint("CENTER", fx, "CENTER", 0, 70)
    self.banner:SetShadowColor(0, 0, 0, 0)
    self.banner:SetShadowOffset(0, 0)
    self.bannerSub = Text(fx, 15, FONT_TITLE, "OUTLINE")
    self.bannerSub:SetPoint("TOP", self.banner, "BOTTOM", 0, -6)
    self.bannerSub:SetTextColor(1, 1, 1)
    self.bannerSub:SetShadowColor(0, 0, 0, 0)
    self.banner:Hide(); self.bannerSub:Hide(); self.bannerShadow:Hide(); self.bannerRibbon:Hide()
    self.bannerT = 0

    -- hero chip (top-left of board): who you're playing, what their power is doing; click to change hero
    local chip = CreateFrame("Button", nil, self.view or fx)
    chip:SetSize(186, 40)
    chip:SetPoint("TOPLEFT", cv, "TOPLEFT", 6, -6)
    chip:SetFrameLevel((self.view or fx):GetFrameLevel() + 8)
    chip.bg = Tex(chip, "BACKGROUND", "pill")
    chip.bg:SetAllPoints()
    chip.bg:SetVertexColor(0, 0, 0, 0.6)
    chip.portrait = Tex(chip, "ARTWORK", "rb_heroes", 1)
    chip.portrait:SetSize(44, 44)
    chip.portrait:SetPoint("LEFT", -4, 2)
    chip.icon = chip:CreateTexture(nil, "ARTWORK", nil, 2)
    chip.icon:SetSize(16, 16)
    chip.icon:SetPoint("BOTTOMLEFT", chip.portrait, "BOTTOMRIGHT", -12, 4)
    chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    chip.name = Text(chip, 12)
    chip.name:SetPoint("TOPLEFT", chip.portrait, "TOPRIGHT", 2, -6)
    chip.text = Text(chip, 11, FONT_NUM)
    chip.text:SetPoint("TOPLEFT", chip.name, "BOTTOMLEFT", 0, -2)
    chip.text:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    chip:SetScript("OnClick", function() self:ShowHeroes() end)
    chip:SetScript("OnEnter", function(b)
        local h = Game.HERO[self.game.hero or ""]
        if GameTooltip and h then
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText(h.name)
            GameTooltip:AddLine(h.power .. ": " .. h.desc, 0.4, 1, 0.5, true)
            GameTooltip:AddLine("Click to change hero", 0.6, 0.6, 0.7)
            GameTooltip:Show()
        end
    end)
    chip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.powerChip = chip

    -- input
    cv:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then self:Fire() end
    end)
    cv:SetScript("OnMouseWheel", function(_, delta)
        local step = (IsShiftKeyDown and IsShiftKeyDown()) and 0.1 or 0.6
        self.aimOffset = (self.aimOffset or 0) + math.rad(step) * delta
        self.wheelX, self.wheelY = self.cursorX, self.cursorY
    end)

    self.pegSprites = {}
    self.pops = {}
    self.animPegs = {}
end

function UI:BuildBottomBar(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10)
    bar:SetPoint("BOTTOMRIGHT", -20, 10)
    bar:SetHeight(30)

    self.orangeLabel = Text(bar, 12, FONT_NUM)
    self.orangeLabel:SetPoint("LEFT", 0, 0)
    self.orangeLabel:SetWidth(96)
    self.orangeLabel:SetJustifyH("LEFT")

    local track = CreateFrame("Frame", nil, bar)
    track:SetPoint("LEFT", 100, 0)
    track:SetSize(170, 10)
    self.track = track
    local tbg = Tex(track, "BACKGROUND", "pill")
    tbg:SetAllPoints()
    tbg:SetVertexColor(1, 1, 1, 0.08)
    self.trackFill = Tex(track, "ARTWORK", "pill")
    self.trackFill:SetPoint("LEFT")
    self.trackFill:SetHeight(10)
    self.trackFill:SetVertexColor(COLORS.orange[1], COLORS.orange[2], COLORS.orange[3])
    for i = 2, #Game.MULT do
        local frac, m = Game.MULT[i][1], Game.MULT[i][2]
        local tick = Solid(track, "OVERLAY", 1, 1, 1, 0.35)
        tick:SetSize(1, 14)
        tick:SetPoint("CENTER", track, "LEFT", frac * 170, 0)
        local lbl = Text(track, 9, FONT_NUM)
        lbl:SetPoint("BOTTOM", tick, "TOP", 0, 1)
        lbl:SetText("x" .. m)
        lbl:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    end

    local mc = CreateFrame("Frame", nil, bar)
    mc:SetSize(54, 24)
    mc:SetPoint("RIGHT", 0, 0)
    mc.bg = Tex(mc, "BACKGROUND", "pill")
    mc.bg:SetAllPoints()
    mc.text = Text(mc, 14, FONT_NUM)
    mc.text:SetPoint("CENTER")
    self.multChip = mc
    local menu = NS.W.Button(bar, 50, 24, "Menu", "ghost")
    menu:SetPoint("LEFT", 276, 0)
    menu:SetScript("OnClick", function() self:ShowMenu() end)
    self.menuButton = menu
    local scores = NS.W.Button(bar, 52, 24, "Scores", "ghost")
    scores:SetPoint("LEFT", 330, 0)
    scores:SetScript("OnClick", function() self:ShowBoard() end)
    self.scoresButton = scores
end

---------------------------------------------------------------------------
-- Level visuals
---------------------------------------------------------------------------
function UI:OnLevelVisuals()
    local g = self.game
    local info = g.info
    if not info then return end
    local tp, bt = info.top, info.bottom
    self.bgTop:SetColorTexture(tp[1], tp[2], tp[3], 1)
    if info.bg then
        -- painted stage backdrop (512x512 stretched back to the board's shape)
        self.bgArt:SetTexture(MEDIA .. info.bg)
        self.bgArt:SetTexCoord(0, 1, 0, 1)
    elseif info.art then
        self.bgArt:SetTexture(MEDIA .. "bg_" .. info.art)
        self.bgArt:SetTexCoord(0.03, 0.97, 0, 1)
    end
    self.bgDim:SetColorTexture(0, 0, 0, info.dim or 0.3)
    self.bgGrad:SetVertexColor(bt[1], bt[2], bt[3], 1)
    self.headerTint:SetVertexColor(bt[1], bt[2], bt[3], 0.30)
    self:BuildPegSprites()
    self:SetFeverSlots(g.fever)
    self.vignette:SetAlpha(0.55)
    self:RefreshHUD(true)
end

function UI:NewPegSprite()
    local cv = self.canvas
    local s = {}
    s.drop = Tex(cv, "ARTWORK", "circle", -3) -- soft drop shadow so pegs pop off any painting
    s.drop:SetVertexColor(0, 0, 0, 0.5)
    s.glow = Tex(cv, "ARTWORK", "glow", -1)
    s.glow:SetBlendMode("ADD")
    s.body = Tex(cv, "ARTWORK", "circle", 0)
    s.shade = Tex(cv, "ARTWORK", "shade", 1)
    s.sym = Tex(cv, "ARTWORK", "ring", 2)
    s.icon = cv:CreateTexture(nil, "ARTWORK", nil, 3)
    s.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    if cv.CreateMaskTexture and s.icon.AddMaskTexture then
        s.mask = cv:CreateMaskTexture()
        s.mask:SetTexture(MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        s.icon:AddMaskTexture(s.mask)
    end
    return s
end

local function ShowSprite(s, show)
    s.glow:SetShown(show); s.body:SetShown(show); s.shade:SetShown(show)
    if s.drop then s.drop:SetShown(show); s.drop:SetAlpha(1) end
    if not show then s.sym:Hide(); s.icon:Hide() end
    s.body:SetAlpha(1); s.shade:SetAlpha(1); s.sym:SetAlpha(1); s.icon:SetAlpha(1); s.glow:SetAlpha(1)
end

function UI:BuildPegSprites()
    local pegs = self.game.pegs
    for i = 1, max(#pegs, #self.pegSprites) do
        local s = self.pegSprites[i]
        local p = pegs[i]
        if p and not s then
            s = self:NewPegSprite()
            self.pegSprites[i] = s
        end
        if s then
            if p and p.alive then
                p.sprite = s
                s.peg = p
                s.alpha = 1
                ShowSprite(s, true)
                self:StylePeg(p)
                self:PlacePeg(p, 1)
            else
                if p then p.sprite = nil end
                s.peg = nil
                ShowSprite(s, false)
            end
        end
    end
    wipe(self.pops)
    for _, p in ipairs(self.animPegs) do p.animT = nil end
    wipe(self.animPegs)
end

function UI:StylePeg(p)
    local s = p.sprite
    if not s then return end
    local key = p.lit and (p.kind .. "Lit") or p.kind
    local c = COLORS[key] or COLORS.blue
    s.body:SetTexture(MEDIA .. (p.brick and "rb_brick_" or "rb_") .. p.kind .. (p.lit and "_lit" or ""))
    if s.drop then s.drop:SetTexture(MEDIA .. (p.brick and ("rb_brick_" .. p.kind) or "circle")) end
    s.body:SetVertexColor(1, 1, 1)
    s.shade:Hide()
    s.glow:SetVertexColor(c[1], c[2], c[3], p.lit and 0.75 or (p.kind == "purple" and 0.55 or 0))
    s.glow:SetShown(p.lit or p.kind == "purple" or p.kind == "green")
    if p.kind == "green" and not p.lit then s.glow:SetVertexColor(c[1], c[2], c[3], 0.35) end

    local symbols = self.db.settings.symbols
    local symFile = nil -- runes and crystals already differ in shape
    local hero = Game.HERO[self.game.hero or ""]
    if p.kind == "green" and hero then
        s.icon:SetTexture(hero.icon)
        s.icon:SetShown(true)
        s.icon:SetAlpha(p.lit and 0.5 or 1)
    elseif p.frog then
        s.icon:SetTexture("Interface\\Icons\\Spell_Shaman_Hex")
        s.icon:SetShown(true)
        s.icon:SetAlpha(p.lit and 0.5 or 1)
    else
        s.icon:Hide()
    end
    if symbols and symFile then
        s.sym:SetTexture(MEDIA .. symFile)
        if p.lit then s.sym:SetVertexColor(1, 1, 1, 0.55) else s.sym:SetVertexColor(0, 0, 0, 0.38) end
        s.sym:Show()
    else
        s.sym:Hide()
    end
end

function UI:PlacePeg(p, scale)
    local s = p.sprite
    if not s then return end
    local cv = self.canvas
    local x, y = p.x, -p.y
    local br = p.brick
    if br then
        -- a rune-stone bar: length along its angle, a little thicker than its collision radius
        local len, th = (br.len * 2 + p.r * 2 + 2) * scale, (p.r * 2 + 3) * scale
        local rot = -br.ang
        s.body:SetSize(len, th); s.body:SetPoint("CENTER", cv, "TOPLEFT", x, y)
        if s.drop then s.drop:SetSize(len + 2, th + 2); s.drop:SetPoint("CENTER", cv, "TOPLEFT", x + 1.5, y - 2.5) end
        s.shade:SetSize(len, th); s.shade:SetPoint("CENTER", cv, "TOPLEFT", x, y)
        s.glow:SetSize(len * 1.5, th * (p.lit and 3.2 or 2.4)); s.glow:SetPoint("CENTER", cv, "TOPLEFT", x, y)
        for _, t in ipairs({ s.body, s.drop, s.shade, s.glow }) do
            if t and t.SetRotation then t:SetRotation(rot) end
        end
        s.isBrick = true
        return
    elseif s.isBrick then
        for _, t in ipairs({ s.body, s.drop, s.shade, s.glow }) do
            if t and t.SetRotation then t:SetRotation(0) end
        end
        s.isBrick = nil
    end
    local size = (p.r * 2 + 2) * scale
    s.body:SetSize(size, size); s.body:SetPoint("CENTER", cv, "TOPLEFT", x, y)
    if s.drop then s.drop:SetSize(size + 2, size + 2); s.drop:SetPoint("CENTER", cv, "TOPLEFT", x + 1.5, y - 2.5) end
    s.shade:SetSize(size, size); s.shade:SetPoint("CENTER", cv, "TOPLEFT", x, y)
    s.sym:SetSize(size * 0.8, size * 0.8); s.sym:SetPoint("CENTER", cv, "TOPLEFT", x, y)
    local gs = size * (p.lit and 2.6 or 2.0)
    s.glow:SetSize(gs, gs); s.glow:SetPoint("CENTER", cv, "TOPLEFT", x, y)
    if s.icon:IsShown() then
        local is = size * 0.6
        s.icon:SetSize(is, is); s.icon:SetPoint("CENTER", cv, "TOPLEFT", x, y)
        if s.mask then s.mask:SetSize(is, is); s.mask:SetPoint("CENTER", cv, "TOPLEFT", x, y) end
    end
end

function UI:SetFeverSlots(on)
    for _, s in ipairs(self.slots) do
        s.bg:SetShown(on); s.glow:SetShown(on); s.text:SetShown(on)
    end
    for _, p in ipairs(self.pillars or {}) do p:SetShown(on) end
    for k = 0, #(self.bumpers or {}) do
        local b = self.bumpers[k]
        if b then b:SetShown(on); b.flash:SetShown(on) end
    end
    if not on and self.payout then self.payout:Hide() end
    self.bucketTex:SetShown(not on)
    self.bucketGlow:SetShown(not on)
    if self.wingL then self.wingL:SetShown(not on); self.wingR:SetShown(not on) end
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
function UI:Particle(x, y, vx, vy, life, size, r, g, b, a)
    self.partIdx = self.partIdx % #self.parts + 1
    local p = self.parts[self.partIdx]
    p.x, p.y, p.vx, p.vy = x, y, vx, vy
    p.life, p.max, p.size = life, life, size
    p.r, p.g, p.b, p.a = r, g, b, a or 1
    p.t:SetVertexColor(r, g, b)
    p.t:Show()
end

function UI:Burst(x, y, c, n, speed)
    if self.db.settings.reducedMotion then n = floor(n / 3) end
    for i = 1, n do
        local a = math.random() * pi * 2
        local sp = (0.3 + math.random()) * (speed or 120)
        self:Particle(x, y, cos(a) * sp, sin(a) * sp, 0.35 + math.random() * 0.35, 6 + math.random() * 8, c[1], c[2], c[3], 1)
    end
end

function UI:Float(text, x, y, c, size, life)
    self.floatIdx = self.floatIdx % #self.floats + 1
    local f = self.floats[self.floatIdx]
    -- WoW's combat font, thick black outline and shadow, colour lifted toward white so it reads on any board
    f.fs:SetFont(FONT_SHOUT, floor((size or 14) * 1.2 + 0.5), "THICKOUTLINE")
    f.fs:SetText(text)
    f.fs:SetTextColor(c[1] * 0.3 + 0.7, c[2] * 0.3 + 0.7, c[3] * 0.3 + 0.7)
    f.x, f.y = max(30, min(C.W - 30, x)), y
    f.life, f.max = life or 0.9, life or 0.9
    f.fs:Show()
end

function UI:Banner(title, sub, c, dur)
    c = c or COLORS.gold
    self.banner:SetText(title)
    self.bannerShadow:SetText(title)
    -- a touch lighter than the theme colour so it reads as lit metal
    -- pale, bright fill so it reads over any board; the colour is only a tint
    self.banner:SetTextColor(c[1] * 0.35 + 0.65, c[2] * 0.35 + 0.65, c[3] * 0.35 + 0.65)
    self.bannerSub:SetText(sub or "")
    self.banner:Show(); self.bannerSub:Show(); self.bannerRibbon:Show(); self.bannerEdgeT:Show(); self.bannerEdgeB:Show()
    self.bannerRibbon:SetHeight((sub and sub ~= "") and 78 or 54)
    self.bannerT, self.bannerMax = dur or 1.8, dur or 1.8
end

function UI:Payout(pts, sub)
    local p = self.payout
    local file = pts >= 100000 and "rb_pay_100k" or (pts >= 50000 and "rb_pay_50k" or "rb_pay_10k")
    p.num:SetTexture(MEDIA .. file)
    p.sub:SetText(sub or "")
    p.t, p.max = 2.4, 2.4
    p:Show()
end

function UI:CoinBurst(x, y, n)
    if self.db.settings.reducedMotion then n = floor(n / 2) end
    for _ = 1, n do
        self.coinIdx = self.coinIdx % #self.coins + 1
        local c = self.coins[self.coinIdx]
        c.x, c.y = x + (math.random() - 0.5) * 30, y
        c.vx, c.vy = (math.random() - 0.5) * 220, -(220 + math.random() * 260)
        c.life, c.max, c.spin = 1.2, 1.2, (math.random() - 0.5) * 14
        c.size = 9 + math.random() * 5
        c.t:Show()
    end
end

function UI:UpdatePayout(el)
    for _, c in ipairs(self.coins or {}) do
        if c.life > 0 then
            c.life = c.life - el
            if c.life <= 0 then c.t:Hide() else
                c.vy = c.vy + 700 * el
                c.x, c.y = c.x + c.vx * el, c.y + c.vy * el
                -- a spinning coin: squash its width
                local w = c.size * abs(cos(c.life * c.spin))
                c.t:SetSize(max(1.5, w), c.size)
                c.t:SetPoint("CENTER", self.canvas, "TOPLEFT", c.x, -c.y)
                c.t:SetAlpha(min(1, c.life / 0.3))
            end
        end
    end
    local p = self.payout
    if p and p:IsShown() then
        p.t = p.t - el
        if p.t <= 0 then p:Hide() else
            local age = p.max - p.t
            local s = age < 0.18 and (0.4 + 0.8 * age / 0.18) or (age < 0.3 and 1.2 - (age - 0.18) / 0.12 * 0.2 or 1)
            p:SetScale(max(0.1, s))
            p:SetAlpha(min(1, p.t / 0.4))
        end
    end
    for k = 0, #(self.bumpers or {}) do
        local b = self.bumpers[k]
        if b and b:IsShown() then
            -- struck medallions flip like a spun coin and flare
            if b.pop > 0 then
                b.pop = max(0, b.pop - el)
                local q = b.pop / 0.45
                local w = abs(cos((1 - q) * pi * 2))
                b:SetSize(b.d * max(0.08, w) * (1 + 0.15 * q), b.d * (1 + 0.15 * q))
                b.flash:SetAlpha(0.25 + 0.75 * q)
                if b.pop == 0 then b:SetSize(b.d, b.d) end
            else
                b.flash:SetAlpha(0.22 + 0.08 * sin((self.rt or 0) * 3 + k))
            end
        end
    end
    for si, s in ipairs(self.slots or {}) do
        if s.pop and s.pop > 0 then
            s.pop = s.pop - el
            local k = 1 + 0.35 * sin(max(0, s.pop) / 0.5 * pi)
            local big = Game.FEVER_SLOTS[si] >= 100000
            s.text:SetSize((big and 104 or 92) * k, (big and 26 or 23) * k)
            s.glow:SetAlpha(1)
        end
    end
end

function UI:Spark(x, y, c)
    self.sparkIdx = self.sparkIdx % #self.sparks + 1
    local sp = self.sparks[self.sparkIdx]
    sp.x, sp.y, sp.life, sp.max = x, y, 0.28, 0.28
    sp.t:SetVertexColor(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5)
    sp.t:Show()
end

function UI:Shock(x, y, c, size)
    if self.db.settings.reducedMotion then return end
    self.shockIdx = self.shockIdx % #self.shocks + 1
    local sh = self.shocks[self.shockIdx]
    sh.x, sh.y, sh.life, sh.max, sh.size = x, y, 0.4, 0.4, size or 60
    sh.t:SetVertexColor(c[1], c[2], c[3])
    sh.t:Show()
end

-- A spell line from (x1, y1) to (x2, y2): jagged (lightning), cracked (quake) or straight (arrow).
-- o = { color, width, life, jag, glow, blend, segs, flicker }
function UI:SpellLine(x1, y1, x2, y2, o)
    if self.db.settings.reducedMotion then o.jag = (o.jag or 0) * 0.4 end
    local ln = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, o = o, life = o.life or 0.3, max = o.life or 0.3, t = 0, pts = nil }
    self:Jag(ln)
    self.lines[#self.lines + 1] = ln
    return ln
end

function UI:Jag(ln)
    local o = ln.o
    local n = o.segs or 7
    local dx, dy = ln.x2 - ln.x1, ln.y2 - ln.y1
    local len = sqrt(dx * dx + dy * dy)
    local nx, ny = len > 0 and -dy / len or 0, len > 0 and dx / len or 0
    local pts = { ln.x1, ln.y1 }
    for k = 1, n - 1 do
        local f = k / n
        local off = (math.random() - 0.5) * 2 * (o.jag or 0) * sin(f * pi)
        pts[#pts + 1] = ln.x1 + dx * f + nx * off
        pts[#pts + 1] = ln.y1 + dy * f + ny * off
    end
    pts[#pts + 1], pts[#pts + 2] = ln.x2, ln.y2
    ln.pts = pts
end

function UI:DrawLines(el)
    local cv = self.canvas
    local used = 0
    local keep = {}
    for _, ln in ipairs(self.lines) do
        ln.life = ln.life - el
        if ln.life > 0 then
            keep[#keep + 1] = ln
            local o = ln.o
            if o.flicker then
                ln.t = ln.t + el
                if ln.t > o.flicker then ln.t = 0; self:Jag(ln) end
            end
            local k = ln.life / ln.max
            local c = o.color
            local grow = o.grow and min(1, (1 - k) / o.grow) or 1   -- cracks race out from the start
            local pts = ln.pts
            local nseg = (#pts / 2) - 1
            local upto = grow * nseg
            for pass = 1, o.glow and 2 or 1 do
                for si = 1, nseg do
                    if si - 1 < upto then
                        used = used + 1
                        local t = self.segs[used]
                        if not t then break end
                        local ax, ay, bx, by = pts[si * 2 - 1], pts[si * 2], pts[si * 2 + 1], pts[si * 2 + 2]
                        local part = min(1, upto - (si - 1))
                        bx, by = ax + (bx - ax) * part, ay + (by - ay) * part
                        local mx, my = (ax + bx) / 2, (ay + by) / 2
                        local sl = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + 1.5
                        local w = (pass == 2) and (o.width or 2) * 3.2 or (o.width or 2)
                        t:ClearAllPoints()
                        t:SetPoint("CENTER", cv, "TOPLEFT", mx, -my)
                        t:SetSize(sl, w)
                        if t.SetRotation then t:SetRotation(-math.atan2(by - ay, bx - ax)) end
                        t:SetBlendMode(o.blend or "ADD")
                        if pass == 2 then t:SetVertexColor(c[1], c[2], c[3], 0.28 * k)
                        else t:SetVertexColor(min(1, c[1] + (o.core or 0)), min(1, c[2] + (o.core or 0)), min(1, c[3] + (o.core or 0)), min(1, 1.4 * k)) end
                        t:Show()
                    end
                end
            end
        end
    end
    self.lines = keep
    for i = used + 1, #self.segs do
        local t = self.segs[i]
        if t:IsShown() then t:Hide() else break end
    end
    -- Misha leaping up to swat the ball
    if self.mishaT then
        self.mishaT = self.mishaT - el
        if self.mishaT <= 0 then self.misha:Hide(); self.mishaT = nil else
            local k = 1 - self.mishaT / 0.8
            local rise = sin(min(1, k * 1.6) * pi * 0.5)
            self.misha:SetPoint("BOTTOM", cv, "TOPLEFT", self.mishaX, -(C.H + 30 - rise * 90))
            self.misha:SetAlpha(min(1, self.mishaT / 0.25))
            if self.misha.SetRotation then self.misha:SetRotation((self.mishaFlip and -0.25 or 0.25) * sin(k * pi * 3)) end
        end
    end
    -- Consecration: holy light rising off the widened bucket
    local g = self.game
    if g and (g.wideShots or 0) > 0 and not self.db.settings.reducedMotion then
        self.holyT = (self.holyT or 0) - el
        if self.holyT <= 0 then
            self.holyT = 0.05
            local bw = g:BucketW()
            self:Particle(g.bucket.x + (math.random() - 0.5) * bw, C.BUCKET_Y + 4, 0, -50 - math.random() * 40, 0.7, 8, 1, 0.85, 0.35, 0.8)
        end
    end
end

function UI:Shake(amount, dur)
    if self.db.settings.reducedMotion then return end
    self.shakeAmt = max(self.shakeAmt or 0, amount)
    self.shakeT = max(self.shakeT or 0, dur or 0.2)
end

---------------------------------------------------------------------------
-- Game event handlers (called with self = UI)
---------------------------------------------------------------------------
UI.Events = {}
local E = UI.Events

function E:levelStart(level, info)
    self.game.hero = self.db.hero or self.game.hero
    self:OnLevelVisuals()
    self:Banner("Level " .. level, info.name, COLORS.gold, 2.2)
    self:SaveRun()
end

function E:fire(angle)
    self.db.stats.shots = (self.db.stats.shots or 0) + 1
    SFX("launch")
    self.popCount = 0
    self:Burst(C.LX + cos(angle) * C.BARREL, C.LY + sin(angle) * C.BARREL, COLORS.gold, 10, 90)
    self:RefreshHUD()
end

function E:hit(p, hits)
    self:StylePeg(p)
    p.animT = 0
    self.animPegs[#self.animPegs + 1] = p
    local c = COLORS[p.kind] or COLORS.blue
    self:Burst(p.x, p.y, c, 6, 70)
    self:Spark(p.x, p.y, c)
    -- Peggle's signature: every peg in a shot rings one note higher
    SFX(("peg%02d"):format(min(25, hits)))
    if p.kind == "purple" then SFX("purple"); self:Shake(3, 0.15); self:Shock(p.x, p.y, c, 70)
    elseif p.kind == "orange" then self:Shock(p.x, p.y, c, 40) end
    if p.kind == "orange" and self.game:OrangeLeft() == 1 and not self.game.fever then
        local last = self.game:FindLastOrange()
        if last then self:Float("Last one!", last.x, last.y - 22, COLORS.orange, 13, 1.4) end
    end
end

function E:points(pts, x, y, kind)
    local c = COLORS[kind] or COLORS.gold
    if kind == "bonus" then c = COLORS.gold end
    self:Float(Commas(pts), x, y - 14, c, kind == "purple" and 18 or (pts >= 100 and 14 or 12), 0.8)
end

function E:bounce(p, speed)
    if speed > 380 then self:Shake(1.5, 0.08) end
end

function E:multiplier(m)
    self:Float("x" .. m .. " multiplier!", C.W / 2, C.H - 70, COLORS.orange, 20, 1.4)
    self.multPulse = 0.5
    SFX("multiplier")
end

function E:callout(text, x, y)
    self:Float(text, x, y - 32, COLORS.gold, 16, 1.3)
end

function E:style(name, pts, x, y)
    self:Float(name .. "!", x, y - 40, COLORS.gold, 20, 1.6)
    self:Float("+" .. Commas(pts), x, y - 18, COLORS.gold, 15, 1.6)
    self:Shock(x, y, COLORS.gold, 90)
    SFX("style")
end

function E:coin(win)
    if win then
        self:Banner("FREE BALL!", "The coin landed your way", COLORS.green, 1.6)
        SFX("coin_win")
    else
        self:Banner("No luck", "Missed every peg - the coin flipped tails", COLORS.dim, 1.4)
        SFX("coin_lose")
    end
end

function E:freeball(kind, x, y)
    self:Banner("FREE BALL!", kind == "style" and "Huge shot" or nil, COLORS.green, 1.4)
    self:Burst(x, y, COLORS.green, 24, 160)
    SFX("freeball")
end

function E:bucket(x, y)
    self:StatAdd("catches"); self:CheckBallUnlocks()
    self:Banner("FREE BALL!", "The gryphon caught it", COLORS.green, 1.4)
    self:Burst(x, y, COLORS.gold, 30, 180)
    self:Shake(3, 0.2)
    SFX("freeball")
end

function E:power(kind, p, hero)
    if hero then
        self:Banner(hero.power, hero.name, COLORS.green, 1.8)
        self.splash:SetTexture(MEDIA .. "hero_" .. hero.key)
        self.splashRight = (p.x < C.W / 2)      -- lean in from the side away from the rune
        self.splash:SetTexCoord(self.splashRight and 1 or 0, self.splashRight and 0 or 1, 0, 1)
        self.splashT, self.splashMax = 1.8, 1.8
        self.splash:Show(); self.splashGlow:Show()
    else
        local pw = Game.POWERS[kind]
        if pw then self:Banner(pw.name, pw.desc, COLORS.green, 1.6) end
    end
    self:Burst(p.x, p.y, COLORS.green, 30, 200)
    self:Shake(3, 0.2)
    SFX("power")
end

-- Thrall: Chain Lightning crackles at the hero rune, then each bolt (event "bolt")
-- leaps to the next rune and breaks it as it lands.
local LIGHTNING = { 0.55, 0.8, 1.0 }
function E:chain(from, hits)
    self:Burst(from.x, from.y, LIGHTNING, 18, 140)
    self:Shock(from.x, from.y, LIGHTNING, 80)
    for _ = 1, 3 do
        local a = math.random() * pi * 2
        self:SpellLine(from.x, from.y, from.x + cos(a) * 26, from.y + sin(a) * 26,
            { color = LIGHTNING, width = 1.6, life = 0.18, jag = 6, segs = 4, flicker = 0.04, core = 0.4 })
    end
    SFX("rb_zap")
end

function E:bolt(from, q, i)
    self:SpellLine(from.x, from.y, q.x, q.y,
        { color = LIGHTNING, width = 2.6, life = 0.32, jag = 13, segs = 8, glow = true, flicker = 0.045, core = 0.45 })
    self:Burst(q.x, q.y, LIGHTNING, 10, 110)
    self:Spark(q.x, q.y, LIGHTNING)
    self:Shake(1.5, 0.08)
    SFX("rb_zap", 0.04)
end

-- Magni: the ground splits from the hero rune out to each rune it shatters
local EARTH = { 0.55, 0.36, 0.2 }
function E:quake(picks, from)
    self:Shake(9, 0.7)
    if from then self:Shock(from.x, from.y, { 0.9, 0.6, 0.3 }, 120) end
    SFX("rb_rumble")
end

function E:crack(from, q, i)
    self:SpellLine(from.x, from.y, q.x, q.y,
        { color = { 0.18, 0.11, 0.07 }, width = 4, life = 1.0, jag = 9, segs = 9, blend = "BLEND", grow = 0.15 })
    self:SpellLine(from.x, from.y, q.x, q.y,
        { color = { 1, 0.55, 0.15 }, width = 1.4, life = 0.7, jag = 0, segs = 1, grow = 0.15 })
    self:Burst(q.x, q.y, EARTH, 14, 120)
    self:Burst(q.x, q.y, { 1, 0.7, 0.3 }, 6, 80)
    self:Shake(4, 0.15)
end

-- Vol'jin: voodoo smoke curls round each rune as it turns into a frog
function E:hex(frogs)
    SFX("rb_hex")
    for _, q in ipairs(frogs) do
        for k = 1, 8 do
            local a = k / 8 * pi * 2
            self:Particle(q.x + cos(a) * 12, q.y + sin(a) * 12, -sin(a) * 60, cos(a) * 60 - 20, 0.5, 11, 0.35, 0.9, 0.3, 0.85)
        end
        self:Spark(q.x, q.y, { 0.5, 1, 0.4 })
        if q.sprite then self:StylePeg(q) end
    end
end

function E:hop(from, to)
    for k = 1, 5 do
        local f = k / 6
        self:Particle(from.x + (to.x - from.x) * f, from.y + (to.y - from.y) * f - sin(f * pi) * 22, 0, 0, 0.4, 8, 0.4, 0.9, 0.3, 0.9)
    end
end

-- Cairne: War Stomp rolls out in a dust ring; runes break as it reaches them ("stompHit")
function E:stomp(p, hits)
    self:Shock(p.x, p.y, { 0.85, 0.65, 0.35 }, 220)
    for k = 1, 28 do
        local a = k / 28 * pi * 2
        self:Particle(p.x, p.y, cos(a) * 340, sin(a) * 340, 0.3, 14, 0.75, 0.58, 0.36, 0.8)
    end
    self:Shake(8, 0.4)
    SFX("rb_stomp")
end

function E:stompHit(q)
    self:Burst(q.x, q.y, { 0.8, 0.62, 0.38 }, 8, 90)
end

-- Tyrande: shooting stars streak down from the top of the board
function E:starfall()
    for i = 1, 2 do self:Burst(140 + (i - 1) * 200, 20, { 1, 0.95, 0.6 }, 16, 120) end
    for _ = 1, 5 do
        local x = math.random() * C.W
        self:SpellLine(x, -10, x + 60, 120, { color = { 1, 0.95, 0.7 }, width = 1.6, life = 0.5, segs = 1, glow = true, grow = 0.4, core = 0.3 })
    end
    SFX("rb_arcane")
end

-- Jaina: an arcane flare as the missiles split off (their trails are drawn with the balls)
function E:arcane(p)
    self:Shock(p.x, p.y, { 0.8, 0.5, 1 }, 110)
    for k = 1, 16 do
        local a = k / 16 * pi * 2
        self:Particle(p.x, p.y, cos(a) * 160, sin(a) * 160, 0.4, 10, 0.85, 0.5, 1, 0.9)
    end
    SFX("rb_arcane")
end

-- Sylvanas: a black arrow streaks from the launcher to the rune, trailing shadow
function E:blackArrow(p)
    self:SpellLine(C.LX, C.LY, p.x, p.y, { color = { 0.45, 0.2, 0.6 }, width = 2.4, life = 0.6, segs = 1, glow = true, grow = 0.25 })
    for k = 1, 12 do
        local f = k / 12
        self:Particle(C.LX + (p.x - C.LX) * f, C.LY + (p.y - C.LY) * f, (math.random() - 0.5) * 30, (math.random() - 0.5) * 30, 0.6, 12, 0.35, 0.15, 0.5, 0.8)
    end
    self:Burst(p.x, p.y, { 0.6, 0.3, 0.8 }, 16, 140)
end

-- Bolvar: holy light pours over the bucket (motes keep rising while it lasts)
function E:consecrate()
    local g = self.game
    self:Burst(g.bucket.x, C.BUCKET_Y, COLORS.gold, 30, 160)
    self:Shock(g.bucket.x, C.BUCKET_Y, { 1, 0.85, 0.4 }, 160)
    SFX("rb_holy")
end

-- Rexxar: Misha answers the call, then leaps up to bat the ball back
function E:mishaCall(p)
    self.mishaX, self.mishaT, self.mishaFlip = C.W / 2, 0.8, false
    self.misha:Show()
end

function E:misha(x, y)
    self:Banner("Misha!", "Batted back into play", COLORS.gold, 1.2)
    self:Burst(x, y, { 0.6, 0.4, 0.25 }, 20, 160)
    self:Shake(4, 0.25)
    self.mishaX, self.mishaT, self.mishaFlip = x, 0.8, x > C.W / 2
    self.misha:SetTexCoord(self.mishaFlip and 1 or 0, self.mishaFlip and 0 or 1, 0, 1)
    self.misha:Show()
    SFX("bucket")
end

function E:fever(p)
    self:Banner("BLOODLUST!", "Last fire crystal shattered!", COLORS.orange, 2.8)
    for i = 1, 3 do self:Burst(p.x, p.y, FEVER_COLORS[i * 2 - 1], 30, 260) end
    self:Shock(p.x, p.y, COLORS.orange, 160)
    self.zoomFocus = { x = p.x, y = p.y }
    self:Shake(6, 0.5)
    self:SetFeverSlots(true)
    SFX("fever")
end

function E:feverSlot(slot, pts, x)
    local s = self.slots[slot]
    if pts >= 100000 then self:StatAdd("goldChest"); self:CheckBallUnlocks() end
    self:Payout(pts, pts >= 100000 and "Into the golden hoard!" or (pts >= 50000 and "Silver strongbox!" or "Iron coffer!"))
    self:CoinBurst(s and s.cx or x, Game.FEVER_TOP + 10, pts >= 100000 and 24 or (pts >= 50000 and 16 or 10))
    self:Burst(x, C.H - 16, FEVER_COLORS[slot], 40, 260)
    if s then s.pop = 0.5 end
    self:Shake(5, 0.3)
    if self.game.ultra then self:Banner("HEROISM!", "Every rune broken", COLORS.purpleLit, 2.6) end
    SFX("fever_bin")
end

function E:feverBump(k, x, y)
    local b = self.bumpers[k]
    if b then b.pop = 0.45 end
    self:Burst(x, y - 6, { 1, 0.85, 0.4 }, 10, 150)
    self:Spark(x, y, { 1, 0.95, 0.7 })
    SFX("pop", 0.03)
end

function E:clutch(on, p)
    self.clutchTarget = on and 1 or 0
    if on and p then self.zoomFocus = { x = p.x, y = p.y } end
end

function E:pop(p)
    local s = p.sprite
    if s then
        self.pops[#self.pops + 1] = { s = s, t = 0, x = p.x, y = p.y, r = p.r }
        p.sprite = nil
        s.peg = nil
    end
    local c = COLORS[p.kind .. "Lit"] or COLORS.blueLit
    if p.kind == "orange" then self:StatAdd("crystals") end
    self:Burst(p.x, p.y, c, 4, 60)
    self.popCount = (self.popCount or 0) + 1
    SFX("pop" .. min(8, 1 + floor(self.popCount / 3)), 0.025)
end

function E:purple(newP, oldP)
    if oldP and oldP.alive then self:StylePeg(oldP) end
    if newP then self:StylePeg(newP) end
end

function E:shotEnd(score, hits)
    if score > (self.db.stats.bestShot or 0) then self.db.stats.bestShot = score end
    self:StatMax("bestCombo", hits)
    self:CheckBallUnlocks()
    if hits >= 12 then
        self:Float(hits .. "-peg combo!", C.W / 2, C.H / 2 + 40, COLORS.purpleLit, 18, 1.5)
    end
    if score >= 1000 then
        self:Float("+" .. Commas(score) .. " shot", C.W / 2, C.H / 2 + 70, COLORS.gold, 22, 1.6)
    end
end

function E:turn()
    self:SaveRun()
    self:RefreshHUD()
    local g = self.game
    if g:OrangeLeft() == 1 then self:Float("1 fire crystal left!", C.W / 2, 90, COLORS.orange, 15, 1.6) end
end

function E:levelWin(bonus, balls)
    local db = self.db
    db.stats.levels = (db.stats.levels or 0) + 1
    self.prevLevelBest = self:LevelBest()
    if self:RecordLevelScore() and self.prevLevelBest > 0 then self.newBest = true end
    if self.game.score > (db.bestLevelScore or 0) then db.bestLevelScore = self.game.score end
    self:CheckHeroUnlocks(self.game.level)
    self:StatMax("bestSpare", balls or 0)
    self:CheckBallUnlocks()
    self:SaveRun()
    local hero = Game.HERO[self.game.hero or "thrall"]
    NS.Social:SubmitBest("rb", self.game.score, ("Lvl %d %s"):format(self.game.level, hero and hero.name:match("^(%S+)") or ""))
    SFX("win")
    self:ShowStateCard()
end

function E:gameOver()
    self:SaveRun()
    SFX("lose")
    self:ShowStateCard()
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function UI:Fire()
    if self.modal or ShellModal() or not self.game then return end
    self.game:Fire(self.aim)
end

---------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    local g = self.game
    g.noSlowMo = self.db.settings.reducedMotion
    if not (self.modal or ShellModal()) then g:Update(el) end
    self.rt = (self.rt or 0) + el

    self:UpdateAim(el)
    self:UpdateBalls(el)
    self:UpdatePegs(el)
    self:UpdateWorld(el)
    self:UpdateFX(el)
    self:RefreshHUD()
    self:UpdateCard(el)
end

function UI:UpdateAim(el)
    local g, cv = self.game, self.canvas
    local x, y = GetCursorPosition()
    local s = cv:GetEffectiveScale()
    local l, t = cv:GetLeft(), cv:GetTop()
    local inside = false
    if l and t then
        local cx, cy = x / s - l, t - y / s
        self.cursorX, self.cursorY = cx, cy
        -- aim follows the cursor anywhere (even off the board): above the
        -- launcher it clamps to the flattest shot on that side
        inside = true
        if g.state == "aim" and not self.modal and not ShellModal() then
            if self.wheelX and (abs(cx - self.wheelX) + abs(cy - self.wheelY) > 4) then
                self.aimOffset, self.wheelX = 0, nil
            end
            self.aim = Game.ClampAngle(atan2(cy - C.LY, cx - C.LX) + (self.aimOffset or 0))
        end
    end

    local a = self.aim
    if self.barrel.SetRotation then self.barrel:SetRotation(pi / 2 - a) end

    local aiming = g.state == "aim" and not self.modal and not ShellModal()
    if aiming then
        self.loaded:SetPoint("CENTER", cv, "TOPLEFT", C.LX + cos(a) * C.BARREL, -(C.LY + sin(a) * C.BARREL))
        self.loaded:Show()
    else
        self.loaded:Hide()
    end

    -- recompute the preview when the aim changes (or periodically for moving pegs)
    self.previewTimer = (self.previewTimer or 0) - el
    local full = g.sightShots > 0
    if aiming and (a ~= self.lastPreviewAim or full ~= self.lastFull or self.previewTimer <= 0) then
        -- Mind Vision follows the moving pegs and bucket every frame
        self.lastPreviewAim, self.lastFull, self.previewTimer = a, full, full and 0 or 0.06
        local n, peg = g:Predict(a, full, self.previewBuf)
        self.previewN, self.previewPeg = n, peg
        local buf = self.previewBuf
        local count = min(n, #self.dots)
        local c = full and COLORS.purpleLit or COLORS.text
        for i = 1, #self.dots do
            local d = self.dots[i]
            if i <= count then
                local fade = 1 - (i / (count + 1)) * 0.75
                d:SetPoint("CENTER", cv, "TOPLEFT", buf[i * 2 - 1], -buf[i * 2])
                d:SetVertexColor(c[1], c[2], c[3], 0.85 * fade)
                local sz = i == count and 7 or 5
                d:SetSize(sz, sz)
                d:Show()
            else
                d:Hide()
            end
        end
    elseif not aiming and self.dots[1]:IsShown() then
        for i = 1, #self.dots do self.dots[i]:Hide() end
        self.lastPreviewAim = nil
    end

    local tp = aiming and self.previewPeg
    if tp and tp.alive then
        local pulse = 1 + sin(self.rt * 8) * 0.08
        self.target:SetSize(30 * pulse, 30 * pulse)
        self.target:SetPoint("CENTER", cv, "TOPLEFT", tp.x, -tp.y)
        local c = COLORS[tp.kind] or COLORS.text
        self.target:SetVertexColor(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5, 0.8)
        self.target:Show()
    else
        self.target:Hide()
    end
end

function UI:UpdateBalls(el)
    local g, cv = self.game, self.canvas
    local reduced = self.db.settings.reducedMotion
    for i, s in ipairs(self.ballSprites) do
        local b = g.balls[i]
        if b and b.alive and g.state == "shot" then
            s.body:SetPoint("CENTER", cv, "TOPLEFT", b.x, -b.y)
            s.body:Show()
            local skin = self.skin or UI.BALLS[1]
            local reduced = self.db.settings.reducedMotion
            local tc = skin.trail
            if skin.key ~= "steel" and not reduced then
                -- skinned balls roll with their sideways speed
                b.rot = (b.rot or 0) - (b.vx or 0) * el / (C.BALL_R * 1.6)
                s.body:SetRotation(b.rot)
            elseif s.rotated ~= false then
                s.body:SetRotation(0)
            end
            s.rotated = skin.key ~= "steel" and not reduced
            local fire = b.fire > 0
            local gs = (fire or b.star or b.missile) and 40 or 26
            s.glow:SetSize(gs, gs)
            s.glow:SetPoint("CENTER", cv, "TOPLEFT", b.x, -b.y)
            if fire then s.glow:SetVertexColor(1, 0.45, 0.1, 0.9)
            elseif b.missile then s.glow:SetVertexColor(0.8, 0.45, 1, 0.9)
            elseif b.star then s.glow:SetVertexColor(1, 0.95, 0.6, 0.9)
            else s.glow:SetVertexColor(tc[1], tc[2], tc[3], skin.key == "steel" and 0.3 or 0.45) end
            s.glow:Show()
            if not reduced then
                b.trailT = (b.trailT or 0) - el
                if b.trailT <= 0 then
                    b.trailT = 0.016
                    if fire then
                        self:Particle(b.x, b.y, (math.random() - 0.5) * 40, -20, 0.35, 12, 1, 0.5, 0.1, 0.9)
                    elseif b.missile then
                        -- Arcane Missiles: a pink-violet comet tail with sparkles
                        self:Particle(b.x, b.y, (math.random() - 0.5) * 30, (math.random() - 0.5) * 30, 0.4, 13, 0.85, 0.45, 1, 0.9)
                        if math.random() < 0.3 then self:Spark(b.x, b.y, { 0.9, 0.6, 1 }) end
                    elseif b.star then
                        -- Starfall: a shooting star, gold and white
                        self:Particle(b.x, b.y, (math.random() - 0.5) * 20, -30, 0.55, 14, 1, 0.93, 0.6, 0.95)
                        if math.random() < 0.35 then self:Spark(b.x + (math.random() - 0.5) * 10, b.y, { 1, 1, 0.8 }) end
                    elseif skin.key == "steel" then
                        self:Particle(b.x, b.y, 0, 0, 0.22, 9, 0.75, 0.85, 1, 0.45)
                    else
                        self:Particle(b.x, b.y, (math.random() - 0.5) * 14, (math.random() - 0.5) * 14, 0.32, 10, tc[1], tc[2], tc[3], 0.6)
                        if math.random() < 0.12 then self:Spark(b.x, b.y, tc) end
                    end
                end
            end
        else
            s.body:Hide(); s.glow:Hide()
        end
    end
end

function UI:UpdatePegs(el)
    local g = self.game
    -- orbiting pegs move every frame
    for _, p in ipairs(g.pegs) do
        if (p.orbit or p.slide or (p.brick and p.brick.spin)) and p.alive and p.sprite and not p.animT then self:PlacePeg(p, 1) end
    end
    -- hit bounce animation
    local anim = self.animPegs
    for i = #anim, 1, -1 do
        local p = anim[i]
        p.animT = (p.animT or 0) + el
        local f = p.animT / 0.2
        if f >= 1 or not p.sprite then
            p.animT = nil
            if p.sprite then self:PlacePeg(p, 1) end
            table.remove(anim, i)
        else
            self:PlacePeg(p, 1 + sin(f * pi) * 0.35)
        end
    end
    -- pop animation
    local cv = self.canvas
    for i = #self.pops, 1, -1 do
        local q = self.pops[i]
        q.t = q.t + el
        local f = q.t / 0.22
        local s = q.s
        if f >= 1 then
            ShowSprite(s, false)
            table.remove(self.pops, i)
        else
            local size = (q.r * 2 + 2) * (1 + f * 0.8)
            local a = 1 - f
            if s.drop then s.drop:SetAlpha(0) end
            for _, tex in ipairs({ s.body, s.shade, s.sym, s.icon }) do
                tex:SetSize(size, size)
                tex:SetPoint("CENTER", cv, "TOPLEFT", q.x, -q.y)
                tex:SetAlpha(a)
            end
            s.glow:SetAlpha(a)
        end
    end
end

function UI:UpdateWorld(el)
    local g, cv = self.game, self.canvas
    -- bucket
    local bx = g.bucket.x
    local bw = g:BucketW()
    self.bucketTex:SetSize(bw + C.RIM_R * 2 + 14, 26)
    self.bucketTex:SetPoint("TOP", cv, "TOPLEFT", bx, -(C.BUCKET_Y - 5))
    self.bucketGlow:SetPoint("CENTER", cv, "TOPLEFT", bx, -(C.BUCKET_Y + 6))
    self.bucketGlow:SetSize(bw + 44, 50)
    if (g.wideShots or 0) > 0 then self.bucketGlow:SetVertexColor(1, 0.9, 0.4, 0.6 + 0.2 * sin(self.rt * 5))
    else self.bucketGlow:SetVertexColor(1, 0.75, 0.25, 0.35) end
    local flap = sin(self.rt * 7) * 6
    local half = bw / 2 + 12
    self.wingL:SetPoint("RIGHT", cv, "TOPLEFT", bx - half + 14, -(C.BUCKET_Y + 2) + flap)
    self.wingR:SetPoint("LEFT", cv, "TOPLEFT", bx + half - 14, -(C.BUCKET_Y + 2) + flap)
    if self.wingL.SetRotation then self.wingL:SetRotation(flap * 0.03); self.wingR:SetRotation(-flap * 0.03) end
    -- fever slot shimmer
    if g.fever then
        for i, s in ipairs(self.slots) do
            s.glow:SetAlpha(0.4 + 0.3 * sin(self.rt * 6 + i))
        end
    end
    -- clouds
    for _, c in ipairs(self.clouds) do
        c.x = c.x - c.spd * el
        if c.x < -c.w then c.x = C.W + c.w * 0.5 end
        c.t:SetPoint("CENTER", cv, "TOPLEFT", c.x, -c.y)
    end
    -- clutch vignette
    local target = (self.clutchTarget or 0) > 0 and 1 or 0.55
    local cur = self.vignette:GetAlpha()
    self.vignette:SetAlpha(cur + (target - cur) * min(1, el * 6))
    -- camera: Peggle's slow-motion zoom on the last orange peg, and screen shake
    local reduced = self.db.settings.reducedMotion
    local wantZoom = (not reduced and self.zoomFocus and (g.clutch or (g.feverSlow or 0) > 0)) and 1.7 or 1
    local z = self.zoom or 1
    z = z + (wantZoom - z) * min(1, el * (wantZoom > z and 5 or 3))
    if abs(z - wantZoom) < 0.002 then z = wantZoom end
    self.zoom = z
    local sx, sy = 0, 0
    if (self.shakeT or 0) > 0 then
        self.shakeT = self.shakeT - el
        local a = self.shakeAmt * max(0, self.shakeT) / 0.2
        sx, sy = (math.random() - 0.5) * a * 2, (math.random() - 0.5) * a * 2
        if self.shakeT <= 0 then self.shakeAmt = 0 end
    end
    if z ~= 1 or sx ~= 0 or sy ~= 0 or self.camDirty then
        local fx, fy = 0, 0
        if self.zoomFocus then fx, fy = self.zoomFocus.x, self.zoomFocus.y end
        cv:SetScale(z)
        cv:SetPoint("TOPLEFT", self.view, "TOPLEFT", (fx * (1 - z) + sx) / z, -(fy * (1 - z) + sy) / z)
        self.camDirty = (z ~= 1 or sx ~= 0 or sy ~= 0)
    end
end

function UI:UpdateFX(el)
    local cv, fx = self.canvas, self.fx
    for _, sp in ipairs(self.sparks) do
        if sp.life > 0 then
            sp.life = sp.life - el
            if sp.life <= 0 then sp.t:Hide() else
                local k = sp.life / sp.max
                local sz = 34 * (1.2 - k * 0.6)
                sp.t:SetSize(sz, sz)
                sp.t:SetPoint("CENTER", cv, "TOPLEFT", sp.x, -sp.y)
                sp.t:SetAlpha(k)
            end
        end
    end
    for _, sh in ipairs(self.shocks) do
        if sh.life > 0 then
            sh.life = sh.life - el
            if sh.life <= 0 then sh.t:Hide() else
                local k = sh.life / sh.max
                local sz = sh.size * (1.1 - k)
                sh.t:SetSize(sz, sz)
                sh.t:SetPoint("CENTER", cv, "TOPLEFT", sh.x, -sh.y)
                sh.t:SetAlpha(k * 0.9)
            end
        end
    end
    self:DrawLines(el)
    self:UpdatePayout(el)
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then
                p.t:Hide()
            else
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                p.vx, p.vy = p.vx * 0.94, p.vy * 0.94 + 60 * el
                local f = p.life / p.max
                local sz = p.size * (0.4 + 0.6 * f)
                p.t:SetSize(sz, sz)
                p.t:SetPoint("CENTER", cv, "TOPLEFT", p.x, -p.y)
                p.t:SetAlpha(p.a * f)
            end
        end
    end
    for _, f in ipairs(self.floats) do
        if f.life > 0 then
            f.life = f.life - el
            if f.life <= 0 then
                f.fs:Hide()
            else
                local k = f.life / f.max
                f.fs:SetPoint("CENTER", fx, "TOPLEFT", f.x, -(f.y - (1 - k) * 26))
                f.fs:SetAlpha(min(1, k * 4))
            end
        end
    end
    if self.ballNews then
        self.ballNewsT = self.ballNewsT - el
        if self.ballNewsT <= 0 and self.bannerT <= 0 then
            self:Banner(self.ballNews.title, self.ballNews.sub, COLORS.gold, 3.2)
            SFX("freeball")
            self.ballNews = nil
        end
    end
    if self.splashT > 0 then
        self.splashT = self.splashT - el
        local t, age = self.splashT, self.splashMax - self.splashT
        local inn = min(1, age / 0.22); inn = 1 - (1 - inn) * (1 - inn) * (1 - inn)   -- ease out
        local out = min(1, t / 0.25)
        local off = self.db.settings.reducedMotion and 0 or ((1 - inn) * 220 + (1 - out) * 60)
        local bob = self.db.settings.reducedMotion and 0 or sin(age * 5) * 2
        self.splash:ClearAllPoints()
        if self.splashRight then self.splash:SetPoint("BOTTOMRIGHT", self.bannerRibbon, "TOPRIGHT", off + 4, -22 + bob)
        else self.splash:SetPoint("BOTTOMLEFT", self.bannerRibbon, "TOPLEFT", -off - 4, -22 + bob) end
        local a = min(1, inn * 1.5) * out
        self.splash:SetAlpha(a)
        self.splashGlow:SetVertexColor(0.5, 1, 0.55, 0.35 * a)
        if self.splashT <= 0 then self.splash:Hide(); self.splashGlow:Hide() end
    end
    if self.bannerT > 0 then
        self.bannerT = self.bannerT - el
        -- fully solid for almost the whole time: a quick 0.1 s fade in and 0.25 s fade out
        local a = max(0, min(1, self.bannerT / 0.25, (self.bannerMax - self.bannerT) / 0.1))
        self.banner:SetAlpha(a); self.bannerSub:SetAlpha(a); self.bannerRibbon:SetAlpha(a)
        self.bannerEdgeT:SetAlpha(a); self.bannerEdgeB:SetAlpha(a)
        if self.bannerT <= 0 then self.banner:Hide(); self.bannerSub:Hide(); self.bannerRibbon:Hide(); self.bannerEdgeT:Hide(); self.bannerEdgeB:Hide() end
    end
end

function UI:RefreshHUD(force)
    local g = self.game
    if not self.scoreText then return end
    -- smooth score count-up
    local target = g.score
    local shown = self.shownScore or target
    if force then shown = target end
    shown = shown + (target - shown) * 0.18
    if abs(target - shown) < 1 then shown = target end
    self.shownScore = shown
    local ss = Commas(shown)
    if ss ~= self.lastScoreStr then self.scoreText:SetText(ss); self.lastScoreStr = ss end

    local shotStr = ""
    if (g.state == "shot" or g.state == "clearing") and (g.shotScore or 0) > 0 then shotStr = "+" .. Commas(g.shotScore) end
    if shotStr ~= self.lastShotStr then self.shotText:SetText(shotStr); self.lastShotStr = shotStr end

    local key = g.level .. ":" .. g.ballsLeft .. ":" .. g.orangeLit .. ":" .. g:Multiplier() .. ":" .. self:LevelBest()
    if key ~= self.hudKey or force then
        self.hudKey = key
        self.levelLabel:SetText("LEVEL " .. g.level)
        self.zoneLabel:SetText(g.info and g.info.name or "")
        local lb = self:LevelBest()
        self.bestLabel:SetText(lb > 0 and ("Level best " .. Commas(lb)) or "First time here")
        self.ballsText:SetText(g.ballsLeft)
        for i, t in ipairs(self.pips) do t:SetShown(i <= g.ballsLeft) end
        self.pipMore:SetText(g.ballsLeft > #self.pips and ("+" .. (g.ballsLeft - #self.pips)) or "")
        local left = g:OrangeLeft()
        self.orangeLabel:SetText(("|cff%sCRYSTALS|r  %d left"):format(HEX.orange, left))
        local frac = g.orangeTotal > 0 and g.orangeLit / g.orangeTotal or 0
        self.trackFill:SetWidth(max(1, frac * 300))
        self.trackFill:SetShown(frac > 0)
        local m = g:Multiplier()
        self.multChip.text:SetText("x" .. m)
        local heat = ({ [1] = 0, [2] = 0.35, [3] = 0.6, [5] = 0.85, [10] = 1 })[m] or 0
        self.multChip.bg:SetVertexColor(0.2 + 0.8 * heat, 0.23 + 0.3 * heat, 0.32 - 0.2 * heat, 1)
    end
    if (self.multPulse or 0) > 0 then
        self.multPulse = self.multPulse - 0.016
        self.multChip:SetScale(1 + self.multPulse * 0.5)
    elseif self.multChip:GetScale() ~= 1 then
        self.multChip:SetScale(1)
    end

    -- hero chip
    local chip = self.powerChip
    local hero = Game.HERO[g.hero or ""]
    if hero then
        local i = hero.order - 1
        chip.portrait:SetTexCoord((i % 4) * 0.25, (i % 4) * 0.25 + 0.25, floor(i / 4) * 0.25, floor(i / 4) * 0.25 + 0.25)
        chip.icon:SetTexture(hero.icon)
        chip.name:SetText(hero.name)
        local status = hero.power
        local function n(k, word) return ("%s  %d %s%s"):format(hero.power, k, word, k == 1 and "" or "s") end
        if g.sightShots > 0 then status = n(g.sightShots, "shot")
        elseif (g.mishaShots or 0) > 0 then status = g.mishaUsed and "Misha: used this shot" or n(g.mishaShots, "shot")
        elseif (g.wideShots or 0) > 0 then status = n(g.wideShots, "shot") end
        chip.text:SetText(status)
        chip:Show()
    else
        chip:Hide()
    end
end

---------------------------------------------------------------------------
-- Modal card (help, results, landing)
---------------------------------------------------------------------------
function UI:BuildCard(f)
    local ov = CreateFrame("Frame", nil, f)
    ov:SetPoint("TOPLEFT", self.view, "TOPLEFT")
    ov:SetPoint("BOTTOMRIGHT", self.view, "BOTTOMRIGHT")
    ov:SetFrameLevel(self.view:GetFrameLevel() + 20)
    ov:EnableMouse(true)
    local dim = Solid(ov, "BACKGROUND", 0.04, 0.02, 0.01, 0.62)
    dim:SetAllPoints()
    ov:Hide()

    local card = CreateFrame("Frame", nil, ov)
    card:SetWidth(360)
    card:SetPoint("CENTER", 0, 10)
    W.Panel(card, "wood")
    card.accent = Solid(card, "ARTWORK", COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0)
    card.accent:SetPoint("TOPLEFT"); card.accent:SetPoint("TOPRIGHT"); card.accent:SetHeight(1)
    card.title = Text(card, 22, W.FONT_TITLE)
    card.title:SetPoint("TOP", 0, -24)
    card.body = Text(card, 13)
    card.body:SetPoint("TOP", card.title, "BOTTOM", 0, -12)
    card.body:SetWidth(310)
    card.body:SetJustifyH("LEFT")
    if card.body.SetSpacing then card.body:SetSpacing(3) end
    card.buttons = {}
    for i = 1, 2 do
        local b = Button(card, 140, 30, "")
        card.buttons[i] = b
    end
    self.overlay, self.card = ov, card
end

-- opts = { title=, body=, color=, center=bool, buttons = { {label, fn, style}, ... }, autoClose=seconds }
function UI:ShowCard(opts)
    local card = self.card
    local c = opts.color or COLORS.gold
    card.title:SetText(opts.title)
    card.title:SetTextColor(c[1], c[2], c[3])
    card.accent:SetColorTexture(c[1], c[2], c[3], 0)
    card.body:SetJustifyH(opts.center and "CENTER" or "LEFT")
    card.body:SetText(opts.body or "")
    local bh = max(40, card.body:GetStringHeight() or 0)
    local btns = opts.buttons or {}
    for i, b in ipairs(card.buttons) do
        local spec = btns[i]
        b:ClearAllPoints()
        if spec then
            b.text:SetText(spec[1])
            b:SetStyle(spec[3] or (i == 1 and "primary" or nil))
            b:SetScript("OnClick", function() self:HideCard(); if spec[2] then spec[2]() end end)
            b:Show()
        else
            b:Hide()
        end
    end
    if #btns == 1 then
        card.buttons[1]:SetPoint("BOTTOM", 0, 18)
    elseif #btns >= 2 then
        card.buttons[1]:SetPoint("BOTTOMRIGHT", card, "BOTTOM", -6, 18)
        card.buttons[2]:SetPoint("BOTTOMLEFT", card, "BOTTOM", 6, 18)
    end
    card:SetHeight(22 + 24 + 12 + bh + (#btns > 0 and 70 or 30))
    self.cardOpts = opts
    self.cardTimer = opts.autoClose
    self.overlay:Show()
    self.modal = true
end

function UI:HideCard()
    self.overlay:Hide()
    self.cardOpts, self.cardTimer = nil, nil
    self.modal = false
end

function UI:UpdateCard(el)
    if self.cardTimer then
        self.cardTimer = self.cardTimer - el
        local o = self.cardOpts
        if o and o.countdown then
            self.card.body:SetText(o.body .. ("\n\n|cff%sClosing in %d...|r"):format(HEX.dim, max(0, math.ceil(self.cardTimer))))
        end
        if self.cardTimer <= 0 then
            self:HideCard()
            if o and o.onTimeout then o.onTimeout() end
        end
    end
end

---------------------------------------------------------------------------
-- Hero picker
---------------------------------------------------------------------------
function UI:BuildHeroPanel()
    local f = self.frame
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", self.view, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", self.view, "BOTTOMRIGHT")
    p:SetFrameLevel(self.view:GetFrameLevel() + 30)
    p:EnableMouse(true)
    local dim = Solid(p, "BACKGROUND", 0.03, 0.035, 0.05, 0.94)
    dim:SetAllPoints()
    local title = Text(p, 22)
    title:SetPoint("TOP", 0, -16)
    title:SetText("Choose your hero")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    p.sub = Text(p, 12, FONT_NUM)
    p.sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    p.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    p.tiles = {}
    for i, h in ipairs(Game.HEROES) do
        local col, row = (i - 1) % 3, floor((i - 1) / 3)
        local t = CreateFrame("Button", nil, p)
        t:SetSize(148, 150)
        t:SetPoint("TOPLEFT", p, "TOPLEFT", 12 + col * 154, -64 - row * 158)
        t.bg = Solid(t, "BACKGROUND", 0.10, 0.11, 0.15, 1)
        t.bg:SetAllPoints()
        t.edge = Solid(t, "BORDER", 1, 1, 1, 0.08)
        t.edge:SetPoint("TOPLEFT"); t.edge:SetPoint("TOPRIGHT"); t.edge:SetHeight(2)
        t.portrait = Tex(t, "ARTWORK", "rb_heroes", 1)
        t.portrait:SetSize(96, 96)
        t.portrait:SetPoint("TOP", 0, 2)
        local c = i - 1
        t.portrait:SetTexCoord((c % 4) * 0.25, (c % 4) * 0.25 + 0.25, floor(c / 4) * 0.25, floor(c / 4) * 0.25 + 0.25)
        t.name = Text(t, 12)
        t.name:SetPoint("TOP", t.portrait, "BOTTOM", 0, 6)
        t.name:SetWidth(140)
        t.power = Text(t, 11, FONT_NUM)
        t.power:SetPoint("TOP", t.name, "BOTTOM", 0, -3)
        t.power:SetWidth(140)
        t.icon = t:CreateTexture(nil, "ARTWORK", nil, 2)
        t.icon:SetSize(22, 22)
        t.icon:SetPoint("TOPRIGHT", -6, -6)
        t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t.icon:SetTexture(h.icon)
        t.hero = h
        t:SetScript("OnClick", function()
            if not self:HeroUnlocked(h.key) then return end
            self:SetHero(h.key)
            self:HideHeroes()
        end)
        t:SetScript("OnEnter", function(b)
            if GameTooltip then
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(h.name)
                GameTooltip:AddLine(h.title, 0.7, 0.7, 0.8)
                GameTooltip:AddLine(h.power .. ": " .. h.desc, 0.4, 1, 0.5, true)
                if not self:HeroUnlocked(h.key) then
                    GameTooltip:AddLine(("Clear %d stage%s to unlock"):format(Game.HERO_UNLOCK[h.key], Game.HERO_UNLOCK[h.key] == 1 and "" or "s"), 1, 0.4, 0.3)
                end
                GameTooltip:Show()
            end
        end)
        t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        p.tiles[i] = t
    end
    local close = Button(p, 140, 28, "Back", "primary")
    close:SetPoint("BOTTOM", 0, 12)
    close:SetScript("OnClick", function() self:HideHeroes() end)
    p:Hide()
    self.heroPanel = p
end

function UI:ShowHeroes()
    if not self.heroPanel then self:BuildHeroPanel() end
    local p = self.heroPanel
    local g = self.game
    local midLevel = (g.turn or 0) > 0 and g.state ~= "won" and g.state ~= "lost"
    p.sub:SetText(midLevel and "Your new hero joins at the start of the next level" or "Every Hero Rune you hit fires your hero's power")
    for _, t in ipairs(p.tiles) do
        local h = t.hero
        local open = self:HeroUnlocked(h.key)
        local mine = (self.db.hero == h.key)
        t.name:SetText(open and h.name or "Locked")
        t.power:SetText(open and h.power or ("Clear %d stage%s"):format(Game.HERO_UNLOCK[h.key], Game.HERO_UNLOCK[h.key] == 1 and "" or "s"))
        t.power:SetTextColor(open and COLORS.green[1] or COLORS.dim[1], open and COLORS.green[2] or COLORS.dim[2], open and COLORS.green[3] or COLORS.dim[3])
        t.portrait:SetVertexColor(open and 1 or 0.18, open and 1 or 0.18, open and 1 or 0.22)
        t.icon:SetDesaturated(not open)
        if mine then t.bg:SetColorTexture(0.24, 0.20, 0.08, 1); t.edge:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
        else t.bg:SetColorTexture(0.10, 0.11, 0.15, 1); t.edge:SetColorTexture(1, 1, 1, 0.08) end
    end
    p:Show()
    self.modal = true
end

function UI:HideHeroes()
    if self.heroPanel then self.heroPanel:Hide() end
    self.modal = self.overlay and self.overlay:IsShown() or false
end

-- Ball skins: a trophy shelf. Won skins show in colour, the rest as shadows with the feat and your progress.
function UI:BuildBallPanel()
    local f = self.frame
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", self.view, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", self.view, "BOTTOMRIGHT")
    p:SetFrameLevel(self.view:GetFrameLevel() + 30)
    p:EnableMouse(true)
    NS.W.Panel(p, "wood")
    local title = Text(p, 22)
    title:SetPoint("TOP", 0, -16)
    title:SetText("Ball skins")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    p.sub = Text(p, 12, FONT_NUM)
    p.sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    p.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    p.tiles = {}
    for i, b in ipairs(UI.BALLS) do
        local col, row = (i - 1) % 4, floor((i - 1) / 4)
        local t = CreateFrame("Button", nil, p)
        t:SetSize(112, 132)
        t:SetPoint("TOPLEFT", p, "TOPLEFT", 10 + col * 116, -62 - row * 138)
        -- no tile boxes: each ball sits on a brass-rimmed coaster on the wood
        t.coaster = t:CreateTexture(nil, "BORDER")
        t.coaster:SetTexture(NS.W.TAVERN .. "coaster")
        t.coaster:SetSize(74, 74)
        t.coaster:SetPoint("TOP", 0, -3)
        t.hl = Tex(t, "HIGHLIGHT", "glow")
        t.hl:SetBlendMode("ADD")
        t.hl:SetSize(96, 96)
        t.hl:SetPoint("TOP", 0, 8)
        t.hl:SetVertexColor(1, 0.85, 0.5, 0.25)
        t.glow = Tex(t, "ARTWORK", "glow", 0)
        t.glow:SetBlendMode("ADD")
        t.glow:SetSize(104, 104)
        t.glow:SetPoint("TOP", 0, 12)
        t.icon = Tex(t, "ARTWORK", b.tex, 1)
        t.icon:SetSize(46, 46)
        t.icon:SetPoint("CENTER", t.coaster, "CENTER")
        t.name = Text(t, 11)
        t.name:SetPoint("TOP", t.coaster, "BOTTOM", 0, -2)
        t.name:SetWidth(108)
        t.line = Text(t, 10, FONT_NUM)
        t.line:SetPoint("TOP", t.name, "BOTTOM", 0, -3)
        t.line:SetWidth(106)
        t.bar = Solid(t, "ARTWORK", 1, 1, 1, 0.10)
        t.bar:SetPoint("BOTTOMLEFT", 8, 4); t.bar:SetSize(96, 3)
        t.fill = Solid(t, "ARTWORK", COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.9, 1)
        t.fill:SetPoint("BOTTOMLEFT", 8, 4); t.fill:SetHeight(3)
        t.ball = b
        t:SetScript("OnClick", function()
            if not self:BallUnlocked(b.key) then SFX("knock"); return end
            self:SetBall(b.key)
            self:ShowBalls()
        end)
        t:SetScript("OnEnter", function(btn)
            if GameTooltip then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetText(b.name, 1, 0.82, 0.25)
                GameTooltip:AddLine(b.feat, 1, 1, 1, true)
                if b.stat and not self:BallUnlocked(b.key) then
                    GameTooltip:AddLine(("Progress: %s of %s"):format(Commas(min(self:BallStat(b.stat), b.need)), Commas(b.need)), 0.6, 0.6, 0.7)
                end
                GameTooltip:Show()
            end
        end)
        t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        p.tiles[i] = t
    end
    local close = Button(p, 140, 28, "Back", "primary")
    close:SetPoint("BOTTOM", 0, 12)
    close:SetScript("OnClick", function() self:HideBalls() end)
    p:Hide()
    self.ballPanel = p
end

function UI:ShowBalls()
    if not self.ballPanel then self:BuildBallPanel() end
    local p = self.ballPanel
    local won = 0
    for _, t in ipairs(p.tiles) do
        local b = t.ball
        local open = self:BallUnlocked(b.key)
        local mine = (self.db.ball == b.key)
        if open then won = won + 1 end
        t.name:SetText(mine and ("|cffffcc40" .. b.name .. "|r") or (open and b.name or ("|cff8a8d99" .. b.name .. "|r")))
        t.line:SetText(mine and "|cffffcc40IN USE|r" or b.feat)
        t.line:SetTextColor(open and COLORS.green[1] or COLORS.dim[1], open and COLORS.green[2] or COLORS.dim[2], open and COLORS.green[3] or COLORS.dim[3])
        t.icon:SetVertexColor(open and 1 or 0.10, open and 1 or 0.10, open and 1 or 0.13)
        t.icon:SetDesaturated(not open)
        t.glow:SetVertexColor(b.trail[1], b.trail[2], b.trail[3], mine and 0.8 or 0)
        local frac = (not b.stat or open) and 1 or min(1, self:BallStat(b.stat) / b.need)
        t.bar:SetShown(not open); t.fill:SetShown(not open and frac > 0)
        t.fill:SetWidth(max(1, 96 * frac))
        t.coaster:SetVertexColor(open and 1 or 0.55, open and 1 or 0.55, open and 1 or 0.55)
    end
    p.sub:SetText(("Won by feats, never bought  -  %d of %d collected"):format(won, #UI.BALLS))
    p:Show()
    self.modal = true
end

function UI:HideBalls()
    if self.ballPanel then self.ballPanel:Hide() end
    self.modal = self.overlay and self.overlay:IsShown() or false
end

-- clearing stages unlocks heroes
function UI:CheckHeroUnlocks(level)
    local db = self.db
    local before = db.cleared or 0
    if level <= before then return end
    db.cleared = level
    for _, h in ipairs(Game.HEROES) do
        local need = Game.HERO_UNLOCK[h.key]
        if need and need > before and need <= level then
            self:Banner("New hero: " .. h.name, h.power .. " - pick them from the hero button", COLORS.gold, 3.0)
        end
    end
end

function UI:ShowHelp()
    local body = table.concat({
        "|cffffcc40Aim|r with your mouse. The dotted line shows the ball's path, and the ring marks the first rune it will hit.",
        "|cffffcc40Shoot|r with a click or Space. Mouse wheel fine-tunes your aim (hold Shift for tiny steps).",
        "",
        ("|cff%sFire crystals|r  shatter every one to clear the stage"):format(HEX.orange),
        ("|cff%sRunes|r  points, and they clear the way"):format(HEX.blue),
        ("|cff%sTitan rune|r  big bonus, moves every turn"):format(HEX.purple),
        ("|cff%sHero runes|r  fire your hero's power"):format(HEX.green),
        "",
        "Pick your hero from the portrait at the top-left: Thrall, Jaina and more as you clear stages.",
        "More crystals broken means a bigger multiplier. Land the ball on the gryphon, or score big in one shot, for a free ball.",
        "Break the last crystal for Bloodlust!",
        "",
        ("|cff%sYour run is saved and picks up again on your next flight.|r"):format(HEX.dim),
    }, "\n")
    self:ShowCard({ title = "Rune Breaker", body = body, buttons = { { "Let's fly", function() self:ShowStateCard() end } } })
end

function UI:ShowStateCard()
    local g = self.game
    if g.state == "won" then
        local bonus = g.ballsLeft * Game.WIN_BALL_BONUS
        local lines = {
            ("Level score  |cffffcc40%s|r%s"):format(Commas(g.score), self.newBest and "  |cff3be870NEW BEST|r" or ""),
            ("Unused balls  |cffffffff%d|r  (+%s)"):format(g.ballsLeft, Commas(bonus)),
            ("Best on this level  |cffffffff%s|r"):format(Commas(max(self:LevelBest(), g.score))),
            ("Best shot  |cffffffff%s|r"):format(Commas(g.bestShot or 0)),
        }
        self.newBest = false
        self:ShowCard({
            title = "Level " .. g.level .. " clear!", color = COLORS.green, center = true,
            body = table.concat(lines, "\n"),
            buttons = { { "Next level", function() g:NextLevel() end } },
        })
    elseif g.state == "lost" then
        local left = g:OrangeLeft()
        self:ShowCard({
            title = "Out of balls", color = COLORS.orange, center = true,
            body = ("So close - %d fire crystal%s left.\nRetry starts this level fresh."):format(left, left == 1 and "" or "s"),
            buttons = {
                { "Retry level", function() g:RetryLevel() end },
                { "New run", function() g:NewRun(time()) end },
            },
        })
    end
end

---------------------------------------------------------------------------
-- Menu and leaderboards
---------------------------------------------------------------------------
function UI:MenuPanels()
    if not self.menu then
        self.menu = NS.NewMenuPanel(self.frame, self.view)
        self.board = NS.NewBoardPanel(self.frame, self.view)
        local function sync() self.modal = (self.menu:IsShown() or self.board:IsShown() or (self.overlay and self.overlay:IsShown())
            or (self.heroPanel and self.heroPanel:IsShown()) or (self.ballPanel and self.ballPanel:IsShown())) and true or false end
        self.menu:HookScript("OnHide", sync)
        self.board:HookScript("OnHide", sync)
    end
end

function UI:ShowMenu()
    self:MenuPanels()
    if self.overlay and self.overlay:IsShown() then self:HideCard() end
    if self.board:IsShown() then self.board:Hide() end
    local g, db = self.game, self.db
    local hero = Game.HERO[db.hero] or Game.HERO.thrall
    local stage = NS.Levels.STAGES and NS.Levels.STAGES[((g.level - 1) % #NS.Levels.STAGES) + 1]
    local lines = {
        ("Level |cffffffff%d|r%s   -   ball %d of %d left"):format(g.level, stage and ("  " .. stage.name) or "", g.ballsLeft or 0, C.BALLS),
        ("Hero: |cffffcc40%s|r  -  %s     Ball: |cffffcc40%s|r"):format(hero.name, hero.power, (UI.BALL[db.ball] or UI.BALLS[1]).name),
        ("Best level score |cffffffff%s|r     Levels cleared %s     Stages unlocked %d"):format(Commas(db.bestLevelScore or 0), Commas(db.stats.levels or 0), db.cleared or 0),
    }
    local rl = NS.Social:RankLine("rb", "all")
    if rl then lines[#lines + 1] = rl end
    local midLevel = (g.turn or 0) > 0 and g.state ~= "won" and g.state ~= "lost"
    local st = db.settings
    local options = NS.CommonOptions()
    table.insert(options, 1, { "Rune symbols on pegs", function() return st.symbols end, function(v) st.symbols = v; self:RestyleAll() end })
    table.insert(options, 2, { "Space bar shoots", function() return st.space end, function(v) st.space = v end })
    self.menu:Open({
        title = "Rune Breaker", sub = "Shatter the fire crystals with Warcraft's heroes", icon = "Interface\\Icons\\INV_Misc_Rune_01",
        color = { 1, 0.6, 0.2 }, lines = lines,
        buttons = {
            { midLevel and "Resume" or "Play", function() if g.state == "won" or g.state == "lost" then self:ShowStateCard() end end },
            { "Choose hero", function() self:ShowHeroes() end },
            { "Ball skins", function() self:ShowBalls() end },
            { "Leaderboards", function() self:ShowBoard() end },
            { "New run", function() self:NewRun(); self:OnLevelVisuals() end, "ghost" },
            { "How to play", function() self:ShowHelp() end, "ghost" },
        },
        options = options,
    })
    self.modal = true
end

function UI:ShowBoard()
    self:MenuPanels()
    if self.menu:IsShown() then self.menu:Hide() end
    self.board:Open({
        game = "rb", periods = true,
        title = "Rune Breaker leaderboard", sub = "Best score on a single level",
        empty = "No scores here yet. Clear a level to post one!",
        fmt = function(e) return Commas(e.s), e.d or "" end,
        onPost = function()
            if (self.db.bestLevelScore or 0) > 0 then SendChatMessage(("[Flight Buddy] Rune Breaker best level: %s"):format(Commas(self.db.bestLevelScore)), "GUILD") end
        end,
    })
    self.modal = true
end
