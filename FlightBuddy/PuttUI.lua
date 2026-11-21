-- Flight Buddy :: PuttUI.lua
-- Gryphon Greens tab: board rendering, drag-to-putt, time-trial HUD, menu, locker, leaderboard.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Putt = NS.Putt
local P = Putt.C
local V = NS.Versus

local UI = {}
NS.PuttUI = UI

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local atan2 = math.atan2
local CANVAS_X, CANVAS_Y = 20, -110
local DRAG_FULL = 110 -- pixels of pull for a full-power putt (pulling further stays at full)
local PATROL_RIDERS = { gnoll = "gnoll", alliance = "footman", dwarf = "dwarf", wolf = "prowler", gnome = "gnome", nelf = "maiev", orc = "grommash", troll = "darkspear", undead = "stitches", turtle = "turtle", syndicate = "defias", raider = "troll", ram = "ram", ghoul = "ghoul", kodo = "kodo", harpy = "harpy", murloc = "murloc", murlocb = "murloc_blue", raptor = "strider",
    kobold = "kobold", golem = "golem", yeti = "yeti", sheep = "sheep", elemental = "earthele" }
local RIDER_TINT = { ghoul = { 0.45, 0.60, 0.40 }, kodo = { 0.55, 0.42, 0.30 }, harpy = { 0.60, 0.30, 0.55 }, ram = { 0.55, 0.62, 0.75 }, turtle = { 0.35, 0.55, 0.25 }, syndicate = { 0.70, 0.35, 0.10 }, raider = { 0.80, 0.22, 0.16 }, gnoll = { 0.62, 0.42, 0.22 }, dwarf = { 0.75, 0.55, 0.25 }, wolf = { 0.55, 0.30, 0.18 }, gnome = { 0.85, 0.55, 0.20 }, nelf = { 0.55, 0.35, 0.80 }, orc = { 0.75, 0.20, 0.15 }, troll = { 0.20, 0.65, 0.60 }, undead = { 0.40, 0.55, 0.25 },
    kobold = { 0.60, 0.45, 0.25 }, golem = { 0.70, 0.50, 0.20 }, yeti = { 0.70, 0.80, 0.90 }, sheep = { 0.45, 0.60, 0.35 }, elemental = { 0.55, 0.40, 0.28 } } -- little figures that ride the patrol tokens

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
local THEMES = {
    elwynn     = { grass = { 0.31, 0.56, 0.26 }, void = { 0.10, 0.16, 0.09 }, wall = { 0.55, 0.40, 0.23 }, bump = { 0.22, 0.42, 0.16 } },
    inn        = { grass = { 0.20, 0.44, 0.30 }, void = { 0.21, 0.13, 0.08 }, wall = { 0.58, 0.38, 0.19 }, bump = { 0.52, 0.33, 0.16 } },
    canal      = { grass = { 0.33, 0.53, 0.31 }, void = { 0.30, 0.31, 0.34 }, wall = { 0.72, 0.70, 0.64 }, bump = { 0.62, 0.62, 0.60 } },
    forge      = { grass = { 0.38, 0.35, 0.33 }, void = { 0.10, 0.08, 0.07 }, wall = { 0.50, 0.33, 0.20 }, bump = { 0.32, 0.32, 0.35 } },
    needles    = { grass = { 0.64, 0.47, 0.29 }, void = { 0.30, 0.18, 0.10 }, wall = { 0.78, 0.58, 0.36 }, bump = { 0.88, 0.80, 0.60 } },
    barrens    = { grass = { 0.54, 0.53, 0.26 }, void = { 0.34, 0.24, 0.12 }, wall = { 0.58, 0.42, 0.22 }, bump = { 0.38, 0.50, 0.20 } },
    dalaran    = { grass = { 0.36, 0.27, 0.56 }, void = { 0.10, 0.07, 0.18 }, wall = { 0.78, 0.68, 0.98 }, bump = { 0.56, 0.42, 0.86 } },
    winter     = { grass = { 0.44, 0.62, 0.56 }, void = { 0.17, 0.21, 0.30 }, wall = { 0.78, 0.88, 0.98 }, bump = { 0.60, 0.76, 0.92 } },
    gnome      = { grass = { 0.34, 0.45, 0.42 }, void = { 0.12, 0.14, 0.16 }, wall = { 0.80, 0.63, 0.26 }, bump = { 0.62, 0.62, 0.68 } },
    sewer      = { grass = { 0.35, 0.37, 0.31 }, void = { 0.08, 0.10, 0.07 }, wall = { 0.42, 0.44, 0.37 }, bump = { 0.30, 0.36, 0.25 } },
    teldrassil = { grass = { 0.24, 0.43, 0.31 }, void = { 0.07, 0.09, 0.17 }, wall = { 0.44, 0.33, 0.50 }, bump = { 0.48, 0.34, 0.26 } },
    bootybay   = { grass = { 0.64, 0.47, 0.27 }, void = { 0.09, 0.28, 0.36 }, wall = { 0.42, 0.28, 0.15 }, bump = { 0.36, 0.25, 0.13 } },
    orgrimmar  = { grass = { 0.46, 0.55, 0.24 }, void = { 0.30, 0.14, 0.08 }, wall = { 0.55, 0.22, 0.12 }, bump = { 0.40, 0.20, 0.12 } },
    thunderbluff = { grass = { 0.42, 0.58, 0.28 }, void = { 0.26, 0.18, 0.12 }, wall = { 0.62, 0.44, 0.28 }, bump = { 0.55, 0.40, 0.25 } },
    stormwind  = { grass = { 0.30, 0.56, 0.28 }, void = { 0.20, 0.22, 0.28 }, wall = { 0.74, 0.72, 0.68 }, bump = { 0.60, 0.60, 0.62 } },
}
local TERRAIN_TEX = { sand = "t_sand", snow = "t_snow", ice = "t_ice", water = "t_water", lava = "t_lava", slime = "t_slime", boost = "t_boost" }
local LIQUID = { water = 0.05, lava = 0.025, slime = 0.035 }

-- Real Azeroth maps under each hole. Classic uiMapIDs first, then retail IDs, then classic
-- WorldMap file paths (yes, Blizzard's folders really say "Ogrimmar" and "Darnassis").
local ZONES = {
    elwynn = { 1429, 37, "Elwynn" },           stormwind = { 1453, 84, "Stormwind" },
    ironforge = { 1455, 87, "Ironforge" },     needles = { 1441, 64, "ThousandNeedles" },
    barrens = { 1413, 10, "Barrens" },         alterac = { 1416, nil, "Alterac" },
    winterspring = { 1452, 83, "Winterspring" }, dunmorogh = { 1426, 27, "DunMorogh" },
    undercity = { 1458, 90, "Undercity" },     darnassus = { 1457, 89, "Darnassis" },
    stranglethorn = { 1434, 224, "Stranglethorn" }, orgrimmar = { 1454, 85, "Ogrimmar" },
    thunderbluff = { 1456, 88, "ThunderBluff" },
}
local mapCache = {}
local function ResolveMap(key)
    if mapCache[key] ~= nil then return mapCache[key] or nil end
    local z = ZONES[key]
    local found = false
    if z and C_Map and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayers then
        for i = 1, 2 do
            local id = z[i]
            if id then
                local okL, layers = pcall(C_Map.GetMapArtLayers, id)
                local okT, tex = pcall(C_Map.GetMapArtLayerTextures, id, 1)
                if okL and okT and layers and layers[1] and tex and #tex > 0 then
                    local L = layers[1]
                    found = { tiles = tex, cols = math.ceil(L.layerWidth / L.tileWidth), tw = L.tileWidth, th = L.tileHeight,
                              w = L.layerWidth, h = L.layerHeight }
                    break
                end
            end
        end
    end
    if not found and z then
        local tiles = {}
        for i = 1, 12 do tiles[i] = "Interface\\WorldMap\\" .. z[3] .. "\\" .. z[3] .. i end
        found = { tiles = tiles, cols = 4, tw = 256, th = 256, w = 1002, h = 668, paths = true }
    end
    mapCache[key] = found or false
    return found or nil
end
UI.ResolveMap = ResolveMap
local TERRAIN_COLOR = {
    sand = { 0.87, 0.77, 0.49 }, snow = { 0.93, 0.96, 0.99 }, ice = { 0.64, 0.86, 0.96 },
    water = { 0.15, 0.42, 0.72 }, lava = { 0.96, 0.40, 0.08 }, slime = { 0.43, 0.86, 0.21 },
    boost = { 1.00, 0.76, 0.26 },
}

UI.BALLS = {
    { id = "pebble",  name = "Peasant's Pebble",   color = { 0.96, 0.96, 0.96 }, req = nil },
    { id = "murloc",  name = "Murloc Egg",         color = { 0.45, 0.88, 0.58 }, req = { "holes", 10, "Finish 10 holes" } },
    { id = "molten",  name = "Molten Core",        color = { 1.00, 0.52, 0.15 }, glow = true, req = { "holes", 40, "Finish 40 holes" } },
    { id = "arcane",  name = "Arcane Orb",         color = { 0.78, 0.48, 1.00 }, glow = true, req = { "dailies", 3, "Finish 3 daily courses" } },
    { id = "frost",   name = "Frostmourne Shard",  color = { 0.55, 0.86, 1.00 }, glow = true, req = { "aces", 1, "Make a hole-in-one" } },
    { id = "gold",    name = "Goblin Gold",        color = { 1.00, 0.82, 0.25 }, glow = true, req = { "underPar", 3, "Finish 3 rounds under par" } },
}
UI.CLUBS = {
    { id = "training",    name = "Training Putter",             icon = "Interface\\Icons\\INV_Mace_01",                  aim = { 0.95, 0.95, 0.95 }, req = nil },
    { id = "hearth",      name = "Hearthputter",                icon = "Interface\\Icons\\INV_Misc_Rune_01",             aim = { 0.45, 0.70, 1.00 }, req = { "holes", 20, "Finish 20 holes" } },
    { id = "thunderfury", name = "Thunderfury, Blessed Putter", icon = "Interface\\Icons\\INV_Sword_39",                 aim = { 0.50, 0.85, 1.00 }, req = { "dailies", 5, "Finish 5 daily courses" } },
    { id = "sulfuras",    name = "Sulfuras, Hand of Ragnaputt", icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras",   aim = { 1.00, 0.55, 0.15 }, req = { "aces", 3, "Make 3 holes-in-one" } },
    { id = "atiesh",      name = "Atiesh, Greatputter",         icon = "Interface\\Icons\\INV_Staff_Medivh",             aim = { 0.80, 0.50, 1.00 }, req = { "holes", 100, "Finish 100 holes" } },
}

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
function UI:Init(db)
    self.db = db -- FlightBuddyDB.putt
    db.daily = db.daily or {}        -- [day] = { best = seconds, tries = n, strokes = n, par = n }
    db.locker = db.locker or { ball = "pebble", club = "training" }
    db.holes, db.aces, db.dailies, db.underPar = db.holes or 0, db.aces or 0, db.dailies or 0, db.underPar or 0
    -- Progress is never reset by an update. The one exception, long past: best times set before
    -- 2.2 came from holes with no scoring floor (whole flight routes in 0 seconds), which nobody
    -- could ever beat, so those were retired once. Anything set since then stays, whatever changes.
    if (db.rev or 0) < 2 then
        db.quickBest, db.courseBest, db.round = nil, nil, nil
        local d = db.daily[NS.Social.Today()]
        if d and d.best then d.best, d.strokes, d.par = nil, nil, nil; db.dailies = math.max(0, db.dailies - 1) end
        for _, e in pairs((NS.db and NS.db.routes) or {}) do
            if type(e) == "table" then e.best, e.strokes = nil, nil end
        end
    end
    db.rev = 3
    local handlers = {}
    for ev, fn in pairs(self.Events) do
        handlers[ev] = function(...) if self.frame then fn(self, ...) end end
    end
    self.game = Putt.New(handlers)
    -- Versus: the match runs in NS.Versus; this screen shows it
    V.onChange = function() if self.frame then self:VersusChanged() end end
    V.onJoin = function()
        if NS.Shell then NS.Shell:Open(nil, "putt") end
        if self.frame then self:ShowVersus() end
    end
    V.onCount = function(m)
        if NS.Shell and not (self.frame and self.frame:IsVisible()) then NS.Shell:Open(nil, "putt") end
        if not self.frame then return end
        if self.menu:IsShown() then self.menu:Hide() end
        if self.card:IsShown() then self.card:Hide() end
        local names = {}
        for _, name in ipairs(m.order) do if name ~= m.me then names[#names + 1] = m.players[name].short end end
        local c = NS.PuttCourses[m.key]
        self:Banner("Get ready", ("%s, %d holes\nagainst %s"):format(c and c.name or "Mini golf", m.len, table.concat(names, ", ")), COLORS.gold, 3.3)
        W.SFX("freeball")
    end
    V.onStart = function(m) if self.frame then self:StartVersus(m) end end
    V.onRival = function(p, what)
        if not (self.frame and self.frame:IsVisible()) then return end
        if what == "finish" then self:Hint(("%s finished in %s"):format(p.short, Putt.FormatTime(p.final)))
        elseif what == "left" then self:Hint(p.short .. " left the match") end
    end
    V.onOver = function() if self.frame and self.card:IsShown() and self.card.opts and self.card.opts.vs == "results" then self:ShowVersusResults() end end
end

local function Today() return NS.Social.Today() end
local function DayNum(day) return tonumber(day) end

function UI:DailyPending()
    return not (self.db.daily[Today()] and self.db.daily[Today()].best)
end

local function Unlocked(db, item)
    if not item.req then return true end
    return (db[item.req[1]] or 0) >= item.req[2]
end

function UI:Ball()
    for _, b in ipairs(UI.BALLS) do if b.id == self.db.locker.ball and Unlocked(self.db, b) then return b end end
    return UI.BALLS[1]
end
function UI:Club()
    for _, c in ipairs(UI.CLUBS) do if c.id == self.db.locker.club and Unlocked(self.db, c) then return c end end
    return UI.CLUBS[1]
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetAllPoints(parent)
    f:Hide()
    self.tint = W.Tex(f, "BACKGROUND", "gradient", -7)
    self.tint:SetPoint("TOPLEFT", 1, -34); self.tint:SetPoint("TOPRIGHT", -1, -34); self.tint:SetHeight(130)
    self.tint:SetVertexColor(1, 0.7, 0.35, 0.12)

    -- HUD
    local hud = CreateFrame("Frame", nil, f)
    hud:SetPoint("TOPLEFT", 20, -38); hud:SetPoint("TOPRIGHT", -20, -38); hud:SetHeight(66)
    self.holeLabel = W.Text(hud, 11, W.FONT_NUM)
    self.holeLabel:SetPoint("TOPLEFT", 2, -8)
    self.holeLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.nameLabel = W.Text(hud, 14)
    self.nameLabel:SetPoint("TOPLEFT", self.holeLabel, "BOTTOMLEFT", 0, -4)
    self.nameLabel:SetWidth(170); self.nameLabel:SetJustifyH("LEFT")
    self.parLabel = W.Text(hud, 11, W.FONT_NUM)
    self.parLabel:SetPoint("TOPLEFT", self.nameLabel, "BOTTOMLEFT", 0, -4)
    self.parLabel:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    local cl = W.Text(hud, 10, W.FONT_NUM)
    cl:SetPoint("TOP", 0, -2)
    cl:SetText("ROUND TIME")
    cl:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.clock = W.Text(hud, 26, W.FONT_NUM)
    self.clock:SetPoint("TOP", cl, "BOTTOM", 0, -1)
    self.adjText = W.Text(hud, 13, W.FONT_NUM)
    self.adjText:SetPoint("TOP", self.clock, "BOTTOM", 0, -2)

    local sl = W.Text(hud, 11, W.FONT_NUM)
    sl:SetPoint("TOPRIGHT", -2, -8)
    sl:SetText("STROKES")
    sl:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.strokeText = W.Text(hud, 24, W.FONT_NUM)
    self.strokeText:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", 0, -1)
    self.clubIcon = hud:CreateTexture(nil, "ARTWORK")
    self.clubIcon:SetSize(18, 18)
    self.clubIcon:SetPoint("TOPRIGHT", -2, -48)
    self.clubIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- board
    local cv = CreateFrame("Frame", nil, f)
    self.canvas = cv
    cv:SetSize(P.W, P.H)
    cv:SetPoint("TOPLEFT", f, "TOPLEFT", CANVAS_X, CANVAS_Y)
    if cv.SetClipsChildren then cv:SetClipsChildren(true) end
    cv:EnableMouse(true)
    self.voidBg = W.Solid(cv, "BACKGROUND", 0.1, 0.1, 0.1, 1, -8)
    self.voidBg:SetAllPoints()
    -- painted hole art (courseart/build.py): the whole hole in one picture
    self.art = cv:CreateTexture(nil, "BACKGROUND", nil, -6)
    self.art:SetAllPoints()
    self.art:Hide()
    self.sails = {}
    self.figTex = {}
    -- zone map tiles (behind everything), then a dimmer so the course pops
    self.mapTiles = {}
    for i = 1, 24 do
        local t = cv:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:Hide()
        self.mapTiles[i] = t
    end
    self.mapDim = W.Solid(cv, "BACKGROUND", 0, 0, 0, 0.45, -7)
    self.mapDim:SetAllPoints()
    W.Border(cv, 0.07)
    self.cells, self.cellShadows = {}, {}
    for i = 1, P.COLS * P.ROWS do
        local col, row = (i - 1) % P.COLS, floor((i - 1) / P.COLS)
        local sh = W.Solid(cv, "BACKGROUND", 0, 0, 0, 0.5, -6)
        sh:SetSize(P.CELL, P.CELL)
        sh:SetPoint("TOPLEFT", cv, "TOPLEFT", col * P.CELL + 6, -row * P.CELL - 7)
        self.cellShadows[i] = sh
        local t = cv:CreateTexture(nil, "BACKGROUND", nil, -5)
        t:SetSize(P.CELL, P.CELL)
        t:SetPoint("TOPLEFT", cv, "TOPLEFT", col * P.CELL, -row * P.CELL)
        self.cells[i] = t
    end
    self.arrows, self.wallTex, self.bumpTex, self.moverDots = {}, {}, {}, {}
    self.wallShadows, self.fanTex, self.patrolTex, self.streaks = {}, {}, {}, {}
    self.portalTex = {}
    self.vignette = W.Tex(cv, "BACKGROUND", "vignette", 5)
    self.vignette:SetAllPoints(); self.vignette:SetAlpha(0.45)

    self.cupShadow = W.Tex(cv, "ARTWORK", "glow", 1)
    self.cupShadow:SetSize(P.CUP_R * 2 + 18, P.CUP_R * 2 + 18)
    self.cupShadow:SetVertexColor(0, 0, 0, 0.35)
    self.cup = W.Tex(cv, "ARTWORK", "cup", 2)
    self.cup:SetSize(P.CUP_R * 2 + 4, P.CUP_R * 2 + 4)
    self.pole = W.Solid(cv, "ARTWORK", 0.92, 0.92, 0.9, 1, 3)
    self.pole:SetSize(2, 34)
    self.poleShadow = W.Solid(cv, "ARTWORK", 0, 0, 0, 0.3, 0)
    self.poleShadow:SetSize(2, 26)
    self.flag = W.Tex(cv, "ARTWORK", "pennant", 3)
    self.flag:SetSize(18, 11)
    self.flag:SetVertexColor(0.95, 0.25, 0.2)
    self.tee = W.Solid(cv, "ARTWORK", 1, 1, 1, 0.25, 0)
    self.tee:SetSize(18, 18)

    self.slider = W.Tex(cv, "ARTWORK", "pill", 4)
    self.slider:Hide()

    -- aim
    self.dots = {}
    for i = 1, 70 do
        local t = W.Tex(cv, "OVERLAY", "circle", 0)
        t:SetSize(5, 5); t:Hide()
        self.dots[i] = t
    end
    self.pull = W.Tex(cv, "OVERLAY", "ring", 0)
    self.pull:SetSize(26, 26); self.pull:Hide()
    local meter = CreateFrame("Frame", nil, cv)
    meter:SetSize(14, 120)
    meter:SetPoint("BOTTOMLEFT", 10, 10)
    meter.bg = W.Tex(meter, "BACKGROUND", "pill"); meter.bg:SetAllPoints(); meter.bg:SetVertexColor(0, 0, 0, 0.45)
    meter.fill = W.Tex(meter, "ARTWORK", "pill"); meter.fill:SetPoint("BOTTOM"); meter.fill:SetWidth(14)
    meter:Hide()
    self.meter = meter

    -- ball
    self.ballShadow = W.Tex(cv, "OVERLAY", "circle", -3)
    self.ballShadow:SetSize(P.BALL_R * 2 + 2, P.BALL_R * 2 + 2)
    self.ballShadow:SetVertexColor(0, 0, 0, 0.35)
    self.ballGlow = W.Tex(cv, "OVERLAY", "glow", -2)
    self.ballGlow:SetBlendMode("ADD")
    self.ballGlow:SetSize(34, 34)
    self.ballTex = W.Tex(cv, "OVERLAY", "ball", 2)
    self.ballTex:SetSize(P.BALL_R * 2 + 2, P.BALL_R * 2 + 2)

    -- particles + floating text
    self.parts = {}
    for i = 1, 90 do
        local t = W.Tex(cv, "OVERLAY", "glow", 3)
        t:SetBlendMode("ADD"); t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    local fx = CreateFrame("Frame", nil, cv)
    fx:SetAllPoints()
    fx:SetFrameLevel(cv:GetFrameLevel() + 5)
    self.fx = fx
    self.banner = W.Text(fx, 26, W.FONT, "OUTLINE")
    self.banner:SetPoint("CENTER", fx, "CENTER", 0, 60)
    self.bannerSub = W.Text(fx, 13)
    self.bannerSub:SetPoint("TOP", self.banner, "BOTTOM", 0, -6)
    self.bannerSub:SetWidth(400)
    self.banner:Hide(); self.bannerSub:Hide()
    self.bannerT = 0

    -- input
    -- a drag can start anywhere in the game window (course, HUD, scorecard strip),
    -- and the release is caught even if the cursor has wandered off the window
    local function down(_, button)
        if button == "RightButton" then self.drag = nil; return end
        if button ~= "LeftButton" or self.game.state ~= "aim" or self:Paused() then return end
        self.drag = { x = self.cx or 0, y = self.cy or 0 }
    end
    local function up(_, button)
        if button == "LeftButton" then self:Release() end
    end
    cv:SetScript("OnMouseDown", down)
    cv:SetScript("OnMouseUp", up)
    -- the catch area starts below the game tabs (which sit over the top of this frame)
    -- and sits under the HUD and scorecard buttons, so those stay clickable
    local catcher = CreateFrame("Frame", nil, f)
    catcher:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -34)
    catcher:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    catcher:SetFrameLevel(f:GetFrameLevel())
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", down)
    catcher:SetScript("OnMouseUp", up)
    self.catcher = catcher

    -- bottom bar: scorecard + buttons
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10); bar:SetPoint("BOTTOMRIGHT", -20, 10); bar:SetHeight(30)
    self.cardBoxes = {}
    self.cardBar = bar
    for i = 1, 12 do
        local b = CreateFrame("Frame", nil, bar)
        b:SetSize(30, 26)
        b:SetPoint("LEFT", (i - 1) * 34, 0)
        b.bg = W.Tex(b, "BACKGROUND", "pill"); b.bg:SetAllPoints()
        b.text = W.Text(b, 13, W.FONT_NUM); b.text:SetPoint("CENTER")
        self.cardBoxes[i] = b
    end
    self.menuBtn = W.Button(bar, 74, 26, "Menu", "ghost")
    self.menuBtn:SetPoint("RIGHT", 0, 0)
    self.menuBtn:SetScript("OnClick", function() self:ShowMenu() end)
    self.boardBtn = W.Button(bar, 92, 26, "Leaderboard")
    self.boardBtn:SetPoint("RIGHT", self.menuBtn, "LEFT", -6, 0)
    self.boardBtn:SetScript("OnClick", function() self:ShowBoard() end)
    self.lockerBtn = W.Button(bar, 66, 26, "Locker")
    self.lockerBtn:SetPoint("RIGHT", self.boardBtn, "LEFT", -6, 0)
    self.lockerBtn:SetScript("OnClick", function() self:ShowLocker() end)

    self.card = W.Card(f, cv)
    self.board = NS.NewBoardPanel(f, cv)
    self.menu = NS.NewMenuPanel(f, cv)
    self:BuildLocker(f)

    f:SetScript("OnUpdate", function(_, el) W.Guard("Greens", self.OnUpdate, self, el) end)

    -- resume a round in progress after a reload
    local r = self.db.round
    if r and r.kind and r.seed then
        local ok, course
        if r.kind == "route" then
            ok, course = pcall(NS.Route.Course, r.route)
            if ok and course then course.live = r.live end
        else
            ok, course = pcall(Putt.MakeCourse, r.kind, r.seed, r.key)
        end
        if ok and course and (r.kind ~= "daily" or tostring(r.seed) == Today()) then
            self.game:Start(course, r)
        end
        self.db.round = nil
    end
    self:RenderHole()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.board:IsShown() or self.locker:IsShown()
        or (self.menu and self.menu:IsShown())
end

function UI:IsBusy() return self.game.state == "roll" or self.game.state == "sunk" end

function UI:OnShow()
    local g = self.game
    if not self.db.seenHelp then
        self.db.seenHelp = true
        self:ShowHelp()
    elseif g.state == "idle" or g.state == "done" then
        self:ShowMenu()
    end
end

function UI:OnHide()
    self.drag = nil
    local g = self.game
    if g.state == "aim" or g.state == "roll" or g.state == "sunk" then
        self.db.round = g.course.kind ~= "versus" and g:Snapshot() or nil
        if self.db.round and g.course.kind == "route" then
            self.db.round.route, self.db.round.live = g.course.route, g.course.live
        end
    else
        self.db.round = nil
    end
end

function UI:OnKey(key)
    if key == "ESCAPE" and self.drag then self.drag = nil; return true end
    return false
end

function UI:StartCourse(kind, key)
    if V:Busy() then V:Leave() end
    local seed = kind == "daily" and DayNum(Today()) or ((time() % 100000) * 7 + floor(GetTime() * 100) % 97)
    local course = Putt.MakeCourse(kind, seed, kind ~= "daily" and key or nil)
    self.db.lastQuick = kind ~= "daily" and key or self.db.lastQuick
    self.game:Start(course)
    self:RenderHole()
    W.Sound("IG_QUEST_LIST_OPEN")
end

-- the round for a flight path route. live = you started it while flying that route (counts for the record)
function UI:StartRoute(spec, live)
    local course = NS.Route.Course(spec)
    if not course then return end
    course.live = live and true or false
    if V:Busy() then V:Leave() end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    self.game:Start(course)
    self:RenderHole()
    W.Sound("IG_QUEST_LIST_OPEN")
end

-- start (or carry on with) the round for the flight you're on
function UI:PlayFlight()
    local spec = NS.Route.Flying()
    local g = self.game
    local playing = g.state == "aim" or g.state == "roll" or g.state == "sunk"
    if playing and g.course and g.course.kind == "route" and spec and g.course.route.key == spec.key then
        if self.menu:IsShown() then self.menu:Hide() end
        return
    end
    if spec then self:StartRoute(spec, true) else
        local last = NS.Route.Last()
        if last then self:StartRoute(last, false) end
    end
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
end

---------------------------------------------------------------------------
-- Rendering a hole
---------------------------------------------------------------------------
function UI:RenderMap(h)
    for _, t in ipairs(self.mapTiles) do t:Hide() end
    local z = h.zone
    local m = z and ResolveMap(z[1])
    if not m then self.mapDim:SetAlpha(0); return end
    self.mapDim:SetAlpha(1)
    local scale = (P.H / m.h) * (z[4] or 1.3)
    local vw, vh = P.W / scale, P.H / scale
    local x0 = max(0, min(m.w - vw, (z[2] or 0.5) * m.w - vw / 2))
    local y0 = max(0, min(m.h - vh, (z[3] or 0.5) * m.h - vh / 2))
    local cv = self.canvas
    for i, file in ipairs(m.tiles) do
        local t = self.mapTiles[i]
        if not t then break end
        local col, row = (i - 1) % m.cols, floor((i - 1) / m.cols)
        local px, py = col * m.tw, row * m.th
        local sx, sy = (px - x0) * scale, (py - y0) * scale
        local size = m.tw * scale
        if sx < P.W and sy < P.H and sx + size > 0 and sy + size > 0 then
            local ok = t:SetTexture(file)
            if ok ~= false then
                t:ClearAllPoints()
                t:SetSize(size, m.th * scale)
                t:SetPoint("TOPLEFT", cv, "TOPLEFT", sx, -sy)
                t:Show()
            end
        end
    end
end

function UI:RenderHole()
    self.cannonRot = nil
    local g, cv = self.game, self.canvas
    local h = g.hole
    for _, t in ipairs(self.arrows) do t:Hide() end
    for _, t in ipairs(self.wallTex) do t:Hide() end
    for _, t in ipairs(self.wallShadows) do t:Hide() end
    for _, b in ipairs(self.bumpTex) do b.body:Hide(); b.shade:Hide() end
    for _, t in ipairs(self.moverDots) do t:Hide() end
    for _, t in ipairs(self.sails) do t.sail:Hide(); t.shadow:Hide() end
    for _, t in ipairs(self.portalTex) do t:Hide() end
    for _, f in ipairs(self.fanTex) do f.base:Hide(); f.blades:Hide(); if f.band then f.band:Hide() end end
    for _, p in ipairs(self.patrolTex) do p.token:Hide(); p.emblem:Hide(); p.shadow:Hide() end
    self:HideFigures()
    for _, st in ipairs(self.streaks) do st.t:Hide() end
    self.slider:Hide()
    self:HzBegin(); self:HzEnd()
    if not h then
        for i, t in ipairs(self.cells) do t:Hide(); self.cellShadows[i]:Hide() end
        for _, t in ipairs(self.mapTiles) do t:Hide() end
        self.cup:Hide(); self.cupShadow:Hide(); self.pole:Hide(); self.poleShadow:Hide(); self.flag:Hide(); self.tee:Hide()
        self.ballTex:Hide(); self.ballGlow:Hide(); self.ballShadow:Hide()
        self.voidBg:SetColorTexture(0.08, 0.12, 0.10, 1)
        self:RenderSurface(nil)
        self:RefreshHUD(true)
        return
    end
    local th = THEMES[h.theme] or THEMES.elwynn
    self.voidBg:SetColorTexture(th.void[1], th.void[2], th.void[3], 1)
    self.mapDim:SetColorTexture(th.void[1] * 0.4, th.void[2] * 0.4, th.void[3] * 0.4, 0.5)
    self.tint:SetVertexColor(th.grass[1], th.grass[2], th.grass[3], 0.25)
    self.liquids = {}
    local painted = h.art ~= nil
    if painted then
        self.art:SetTexture(W.MEDIA .. h.art)
        if h.mirror then self.art:SetTexCoord(1, 0, 0, 1) else self.art:SetTexCoord(0, 1, 0, 1) end
        self.art:Show()
        self:ShowFigures(h)
        for _, t in ipairs(self.mapTiles) do t:Hide() end
        self.mapDim:SetAlpha(0)
    else
        self.art:Hide()
        self:RenderMap(h)
    end
    local arrowN = 0
    for i, t in ipairs(painted and {} or self.cells) do
        local ch = h.cells[i]
        local col, row = (i - 1) % P.COLS, floor((i - 1) / P.COLS)
        if ch then
            local ter = Putt.TERRAIN[ch]
            local file = TERRAIN_TEX[ter.name] or ((row % 2 == 0) and "t_grass1" or "t_grass2")
            t:SetTexture(W.MEDIA .. file, "REPEAT", "REPEAT")
            t:SetTexCoord(0, 1, 0, 1)
            if TERRAIN_TEX[ter.name] then t:SetVertexColor(1, 1, 1) else t:SetVertexColor(th.grass[1] * 1.15, th.grass[2] * 1.15, th.grass[3] * 1.15) end
            t:Show()
            self.cellShadows[i]:Show()
            if LIQUID[ter.name] then self.liquids[#self.liquids + 1] = { t = t, spd = LIQUID[ter.name], ph = (col * 0.37 + row * 0.21) % 1 } end
            local dir = ter.slope or ter.boost
            if dir then
                arrowN = arrowN + 1
                local a = self.arrows[arrowN]
                if not a then a = cv:CreateTexture(nil, "BACKGROUND", nil, -4); self.arrows[arrowN] = a end
                a:SetSize(ter.boost and 40 or 34, ter.boost and 40 or 34)
                a:SetPoint("CENTER", cv, "TOPLEFT", (col + 0.5) * P.CELL, -(row + 0.5) * P.CELL)
                -- art points "up" (-y); rotate toward the push direction
                if a.SetRotation then a:SetRotation(-atan2(dir[1], -dir[2])) end
                if ter.boost then
                    a:SetTexture(W.MEDIA .. "t_boost"); a:SetVertexColor(1, 1, 1, 1)
                    t:SetVertexColor(th.grass[1], th.grass[2], th.grass[3])
                    t:SetTexture(W.MEDIA .. "t_grass1")
                else
                    a:SetTexture(W.MEDIA .. "t_chevron"); a:SetVertexColor(0, 0, 0, 0.28)
                end
                a:Show()
            end
        else
            t:Hide()
            self.cellShadows[i]:Hide()
        end
    end
    if painted then
        for i, t in ipairs(self.cells) do t:Hide(); self.cellShadows[i]:Hide() end
        -- slopes and boost pads are only faintly painted: mark them with arrows so nothing pushes
        -- the ball around invisibly
        self.flow = {}
        for y = 15, P.H - 15, 26 do
            for x = 15, P.W - 15, 26 do
                local ch = Putt.Cell(h, x, y)
                local ter = ch and Putt.TERRAIN[ch]
                local dir = ter and (ter.slope or ter.boost)
                for _, q in ipairs(h.patches or {}) do
                    if x >= q.x1 and x <= q.x2 and y >= q.y1 and y <= q.y2 then dir = nil end
                end
                if dir and Putt.Cell(h, x - 9, y - 9) == ch and Putt.Cell(h, x + 9, y + 9) == ch
                    and Putt.Cell(h, x + 9, y - 9) == ch and Putt.Cell(h, x - 9, y + 9) == ch then
                    arrowN = arrowN + 1
                    local a = self.arrows[arrowN]
                    if not a then a = cv:CreateTexture(nil, "BACKGROUND", nil, -4); self.arrows[arrowN] = a end
                    a:SetDrawLayer("ARTWORK", -2)
                    a:ClearAllPoints()
                    a:SetSize(ter.boost and 22 or 20, ter.boost and 22 or 20)
                    a:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                    if a.SetRotation then a:SetRotation(-atan2(dir[1], -dir[2])) end
                    if ter.boost then
                        a:SetTexture(W.MEDIA .. "t_boost"); a:SetVertexColor(1, 0.9, 0.4, 0.85)
                    else
                        a:SetTexture(W.MEDIA .. "t_chevron"); a:SetVertexColor(1, 1, 1, 1)
                    end
                    a:Show()
                    self.flow[#self.flow + 1] = { t = a, x = x, y = y, ph = (x * dir[1] + y * dir[2]) / 26, boost = ter.boost }
                end
            end
        end
        -- a strip narrower than that lattice would get no arrows at all and read as a blank patch:
        -- walk it on a fine grid and drop arrows wherever none is near
        for y = 9, P.H - 9, 4 do
            for x = 9, P.W - 9, 4 do
                local ch = Putt.Cell(h, x, y)
                local ter = ch and Putt.TERRAIN[ch]
                local dir = ter and (ter.slope or ter.boost)
                if dir and Putt.Cell(h, x - 7, y - 7) == ch and Putt.Cell(h, x + 7, y + 7) == ch
                    and Putt.Cell(h, x + 7, y - 7) == ch and Putt.Cell(h, x - 7, y + 7) == ch then
                    local free = true
                    for _, q in ipairs(h.patches or {}) do
                        if x >= q.x1 and x <= q.x2 and y >= q.y1 and y <= q.y2 then free = false end
                    end
                    for _, f in ipairs(self.flow) do
                        if abs(f.x - x) < 22 and abs(f.y - y) < 22 then free = false; break end
                    end
                    if free then
                        arrowN = arrowN + 1
                        local a = self.arrows[arrowN]
                        if not a then a = cv:CreateTexture(nil, "BACKGROUND", nil, -4); self.arrows[arrowN] = a end
                        a:SetDrawLayer("ARTWORK", -2)
                        a:ClearAllPoints()
                        a:SetSize(ter.boost and 20 or 18, ter.boost and 20 or 18)
                        a:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                        if a.SetRotation then a:SetRotation(-atan2(dir[1], -dir[2])) end
                        if ter.boost then
                            a:SetTexture(W.MEDIA .. "t_boost"); a:SetVertexColor(1, 0.9, 0.4, 0.85)
                        else
                            a:SetTexture(W.MEDIA .. "t_chevron"); a:SetVertexColor(1, 1, 1, 1)
                        end
                        a:Show()
                        self.flow[#self.flow + 1] = { t = a, x = x, y = y, ph = (x * dir[1] + y * dir[2]) / 26, boost = ter.boost }
                    end
                end
            end
        end
    else
        self.flow = nil
    end
    -- rails with drop shadows (vertical rails reuse the texture rotated 90 degrees)
    for i, w in ipairs(painted and {} or h.walls) do
        local t = self.wallTex[i]
        if not t then
            t = W.Tex(cv, "ARTWORK", "rail", -2)
            self.wallTex[i] = t
            self.wallShadows[i] = W.Solid(cv, "ARTWORK", 0, 0, 0, 0.4, -3)
        end
        local sh = self.wallShadows[i]
        local x1, y1, x2, y2 = w[1], w[2], w[3], w[4]
        local thick = w.interior and 8 or 7
        t:ClearAllPoints(); sh:ClearAllPoints()
        if t.SetRotation then t:SetRotation(0) end
        if sh.SetRotation then sh:SetRotation(0) end
        if abs(x1 - x2) >= 0.5 and abs(y1 - y2) >= 0.5 then
            -- corner bevel: a short angled rail
            local len = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
            local ang = atan2(-(y2 - y1), x2 - x1)
            t:SetSize(len + 4, thick)
            t:SetTexCoord(0, 1, 0, 1)
            if t.SetRotation then t:SetRotation(ang) end
            if sh.SetRotation then sh:SetRotation(ang) end
        elseif abs(x1 - x2) < 0.5 then
            t:SetSize(thick, abs(y2 - y1) + thick)
            t:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
        else
            t:SetSize(abs(x2 - x1) + thick, thick)
            t:SetTexCoord(0, 1, 0, 1)
        end
        sh:SetSize(t:GetWidth() + 2, t:GetHeight() + 2)
        local cx, cy = (x1 + x2) / 2, -(y1 + y2) / 2
        t:SetPoint("CENTER", cv, "TOPLEFT", cx, cy)
        sh:SetPoint("CENTER", cv, "TOPLEFT", cx + 3, cy - 4)
        t:SetVertexColor(th.wall[1] * 1.2, th.wall[2] * 1.2, th.wall[3] * 1.2)
        t:Show(); sh:Show()
    end
    -- bumpers (fan housings are drawn by the fans)
    for i, b in ipairs(h.bumpers) do
        local s2 = self.bumpTex[i]
        if not s2 then
            s2 = { body = W.Tex(cv, "ARTWORK", "circle", 1), shade = W.Tex(cv, "ARTWORK", "shade", 2) }
            self.bumpTex[i] = s2
        end
        if not b.fan and not b.baked then
            if b.style then
                -- extra obstacles on painted holes: a themed post sprite with its own drop shadow
                -- the base is a solid dark disc the size of the post (from art that always loads),
                -- so the obstacle is visible even before the sprite file is picked up
                local size = b.r * 2 + 4
                s2.body:SetTexture(W.MEDIA .. "greens\\post_" .. b.style)
                s2.body:SetVertexColor(1, 1, 1)
                s2.body:SetSize(size, size)
                s2.body:SetDrawLayer("ARTWORK", 3)
                s2.body:SetTexCoord(0, 1, 0, 1)
                s2.shade:SetTexture(W.MEDIA .. "circle")
                s2.shade:SetVertexColor(0.1, 0.09, 0.08, 0.9)
                s2.shade:SetSize(b.r * 2 + 4, b.r * 2 + 4)
                s2.shade:SetDrawLayer("ARTWORK", 0)
                s2.body:SetPoint("CENTER", cv, "TOPLEFT", b.x, -b.y)
                s2.shade:SetPoint("CENTER", cv, "TOPLEFT", b.x + 2, -b.y - 3)
                s2.styled = true
            else
                if s2.styled then
                    s2.body:SetTexture(W.MEDIA .. "circle"); s2.shade:SetTexture(W.MEDIA .. "shade")
                    s2.shade:SetVertexColor(1, 1, 1, 1); s2.styled = nil
                    s2.body:SetDrawLayer("ARTWORK", 1); s2.shade:SetDrawLayer("ARTWORK", 2)
                end
                local size = b.r * 2 + 2
                s2.body:SetSize(size, size); s2.shade:SetSize(size, size)
                s2.body:SetPoint("CENTER", cv, "TOPLEFT", b.x, -b.y); s2.shade:SetPoint("CENTER", cv, "TOPLEFT", b.x, -b.y)
                s2.body:SetVertexColor(th.bump[1], th.bump[2], th.bump[3])
            end
            s2.body:Show(); s2.shade:Show()
        end
    end
    -- fans
    for i, fan in ipairs(h.fans) do
        local f = self.fanTex[i]
        if not f then
            f = { base = W.Tex(cv, "ARTWORK", "fan_base", 3), blades = W.Tex(cv, "ARTWORK", "fan_blades", 4),
                  band = W.Tex(cv, "ARTWORK", "greens\\fx_wind", -3) }
            f.band:SetBlendMode("ADD")
            self.fanTex[i] = f
        end
        f.base:SetSize(34, 34); f.blades:SetSize(30, 30)
        -- the airflow: a faint band over exactly the area the wind pushes, fading with distance
        local cx, cy = fan.x + fan.dx * fan.len / 2, fan.y + fan.dy * fan.len / 2
        f.band:ClearAllPoints()
        if abs(fan.dx) > 0.5 then
            f.band:SetSize(fan.len, fan.width)
            if fan.dx > 0 then f.band:SetTexCoord(0, 1, 0, 1) else f.band:SetTexCoord(1, 0, 0, 1) end
        else
            f.band:SetSize(fan.width, fan.len)
            -- gradient runs left to right; turn it to run along the wind
            if fan.dy > 0 then f.band:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) else f.band:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) end
        end
        f.band:SetPoint("CENTER", cv, "TOPLEFT", cx, -cy)
        f.band:SetVertexColor(0.6, 0.85, 1, 0.3)
        f.band:Show()
        f.base:SetPoint("CENTER", cv, "TOPLEFT", fan.x, -fan.y)
        f.blades:SetPoint("CENTER", cv, "TOPLEFT", fan.x, -fan.y)
        f.base:Show(); f.blades:Show()
        if fan.tide then f.base:Hide(); f.blades:Hide(); f.band:SetVertexColor(0.3, 0.75, 1, 0.5) end
    end
    -- portals
    for i, pt in ipairs(painted and {} or h.portals) do
        for k = 1, 2 do
            local idx = (i - 1) * 2 + k
            local t = self.portalTex[idx]
            if not t then t = W.Tex(cv, "ARTWORK", "ring", 3); self.portalTex[idx] = t end
            t:SetSize(pt.r * 2 + 8, pt.r * 2 + 8)
            if k == 1 then
                t:SetPoint("CENTER", cv, "TOPLEFT", pt.ax, -pt.ay); t:SetVertexColor(0.75, 0.45, 1)
            else
                t:SetPoint("CENTER", cv, "TOPLEFT", pt.bx, -pt.by); t:SetVertexColor(0.35, 0.75, 1)
            end
            t:Show()
        end
    end
    -- cup, flag, tee
    local cup = h.cup
    self.cupShadow:SetPoint("CENTER", cv, "TOPLEFT", cup.x, -cup.y)
    self.cup:SetPoint("CENTER", cv, "TOPLEFT", cup.x, -cup.y)
    self.pole:SetPoint("BOTTOM", cv, "TOPLEFT", cup.x, -cup.y)
    self.poleShadow:SetPoint("BOTTOMLEFT", cv, "TOPLEFT", cup.x + 2, -cup.y - 2)
    if self.poleShadow.SetRotation then self.poleShadow:SetRotation(-0.6) end
    self.flag:SetPoint("TOPLEFT", self.pole, "TOPRIGHT", 0, 0)
    self.tee:SetPoint("CENTER", cv, "TOPLEFT", h.tee.x, -h.tee.y)
    self.pole:Show(); self.poleShadow:Show(); self.flag:Show()
    if painted then
        self.cup:Hide(); self.cupShadow:Hide(); self.tee:Hide() -- painted into the art
    else
        self.cup:Show(); self.cupShadow:Show(); self.tee:Show()
    end
    local ball = self:Ball()
    self.ballTex:SetVertexColor(ball.color[1], ball.color[2], ball.color[3])
    self.ballGlow:SetVertexColor(ball.color[1], ball.color[2], ball.color[3], ball.glow and 0.55 or 0.18)
    self.clubIcon:SetTexture(self:Club().icon)
    self:RenderSurface(h)
    self:RefreshHUD(true)
end

---------------------------------------------------------------------------
-- The shape of the green (PuttHard.lua "surface"), drawn once per hole: ground that faces the
-- light from the top left is brightened and ground that faces away is shaded, like a relief map,
-- and high ground is a touch paler than low. The beads that run downhill are laid out here too
-- and moved every frame in DrawHazards.
---------------------------------------------------------------------------
function UI:RenderSurface(h)
    self.surfPool = self.surfPool or {}
    self.linePool = self.linePool or {}
    local pool, used = self.surfPool, 0
    local lines, nl = self.linePool, 0
    self.beads = nil
    local cv = self.canvas
    local g = h and h.surf
    if g then
        local TERR = Putt.TERRAIN
        local PW, PH = Putt.C.W, Putt.C.H
        local function ground(x, y)
            local t = TERR[Putt.Cell(h, x, y) or " "]
            return t and not t.hazard and not t.pit
        end
        local function inside(x, y, m)
            return ground(x, y) and ground(x - m, y) and ground(x + m, y) and ground(x, y - m) and ground(x, y + m)
        end
        local Height, Lie = Putt.Height, Putt.Lie
        -- relief: one soft patch per sample, light or dark
        local span = max(1, g.hi - g.lo)
        local mid = (g.hi + g.lo) / 2
        local tallK = min(1, span / 5000)
        local STEP = 12
        for y = STEP / 2, PH, STEP do
            for x = STEP / 2, PW, STEP do
                if inside(x, y, 8) then
                    local ax, ay = Lie(h, x, y)
                    -- downhill towards the top left = facing the light
                    local lit = -(ax + ay) * 0.7071 / 140
                    local al = abs(lit)
                    if al > 1 then al = 1 end
                    al = al ^ 0.7
                    local v = (lit < 0 and -al or al) * 0.9 + (Height(h, x, y) - mid) / span * tallK * 0.6
                    if v > 0.05 or v < -0.05 then
                        used = used + 1
                        local t = pool[used]
                        if not t then t = W.Tex(cv, "ARTWORK", "glow", -5); pool[used] = t end
                        t:ClearAllPoints()
                        t:SetSize(STEP * 3.4, STEP * 3.4); t:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                        if v > 0 then
                            t:SetBlendMode("ADD"); t:SetVertexColor(0.8, 1, 0.5, 0.2 * min(1, v))
                        else
                            t:SetBlendMode("BLEND"); t:SetVertexColor(0, 0.07, 0.02, 0.55 * min(1, -v))
                        end
                        t:Show()
                    end
                end
            end
        end
        -- contour lines, as on a map: every line is the same step in height, so lines crowd
        -- together where the green is steep and spread out where it is gentle
        local EVERY, M = 1500, 12
        local SH, list = Putt.SurfaceHeight, h.surface
        local function line(x1, y1, x2, y2)
            local dx, dy = x2 - x1, y2 - y1
            local len = sqrt(dx * dx + dy * dy)
            if len < 0.5 then return end
            nl = nl + 1
            local t = lines[nl]
            if not t then t = W.Tex(cv, "ARTWORK", "pill", -4); lines[nl] = t end
            t:ClearAllPoints()
            t:SetSize(len + 1.4, 1.3)
            t:SetPoint("CENTER", cv, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
            if t.SetRotation then t:SetRotation(atan2(-dy, dx)) end
            t:SetVertexColor(0.02, 0.22, 0.05, 0.27)
            t:Show()
        end
        for y = 0, PH - M, M do
            for x = 0, PW - M, M do
                if ground(x + M / 2, y + M / 2) and inside(x + M / 2, y + M / 2, 5) then
                    local a, b = SH(list, x, y), SH(list, x + M, y)
                    local c, d = SH(list, x + M, y + M), SH(list, x, y + M)
                    local lo, hi = min(a, b, c, d), max(a, b, c, d)
                    if hi - lo > 1 then
                        for lv = math.ceil(lo / EVERY), floor(hi / EVERY) do
                            local L = lv * EVERY + 0.37   -- a hair off round heights, so a level green on a line draws nothing
                            local px, py, n = {}, {}, 0
                            if (a < L) ~= (b < L) then n = n + 1; px[n], py[n] = x + M * (L - a) / (b - a), y end
                            if (b < L) ~= (c < L) then n = n + 1; px[n], py[n] = x + M, y + M * (L - b) / (c - b) end
                            if (d < L) ~= (c < L) then n = n + 1; px[n], py[n] = x + M * (L - d) / (c - d), y + M end
                            if (a < L) ~= (d < L) then n = n + 1; px[n], py[n] = x, y + M * (L - a) / (d - a) end
                            if n >= 2 then line(px[1], py[1], px[2], py[2]) end
                            if n == 4 then line(px[3], py[3], px[4], py[4]) end
                        end
                    end
                end
            end
        end
        -- beads: a staggered lattice over the green, wherever it leans enough to move a putt.
        -- Each is a small round bead with a dark twin just behind it (so it reads on the palest
        -- felt), sized and coloured here once; DrawHazards only slides and fades them. With reduced
        -- motion they stand still, so they are little chevrons that point downhill instead.
        local beads, row = {}, 0
        local GAP = 24
        local decel = Putt.C.DECEL
        local still = NS.db.settings.reducedMotion
        self.beadPool = self.beadPool or {}
        local bp = self.beadPool
        for y = GAP / 2, PH, GAP * 0.87 do
            row = row + 1
            for x = (row % 2 == 0) and GAP or GAP / 2, PW, GAP do
                if inside(x, y, 7) then
                    local ax, ay = Lie(h, x, y)
                    local m = sqrt(ax * ax + ay * ay)
                    if m >= 9 then
                        local dx, dy = ax / m, ay / m
                        local hot = min(1.3, m / decel)
                        local n = #beads + 1
                        local t = bp[n]
                        if not t then
                            t = { sh = W.Tex(cv, "ARTWORK", "circle", -3), ch = W.Tex(cv, "ARTWORK", "circle", -2) }
                            bp[n] = t
                        end
                        if still then
                            local sz, rot = 15 + 4 * min(1, hot), -atan2(dx, -dy)
                            t.sh:SetTexture(W.MEDIA .. "t_chevron"); t.ch:SetTexture(W.MEDIA .. "t_chevron")
                            t.sh:SetSize(sz, sz); t.ch:SetSize(sz, sz)
                            if t.ch.SetRotation then t.sh:SetRotation(rot); t.ch:SetRotation(rot) end
                        else
                            local sz = 4.2 + 1.6 * min(1, hot)
                            t.sh:SetTexture(W.MEDIA .. "circle"); t.ch:SetTexture(W.MEDIA .. "circle")
                            t.sh:SetSize(sz + 1.8, sz + 1.8); t.ch:SetSize(sz, sz)
                            if t.ch.SetRotation then t.sh:SetRotation(0); t.ch:SetRotation(0) end
                        end
                        t.sh:SetVertexColor(0, 0.14, 0.03)
                        if hot >= 1 then t.ch:SetVertexColor(1, 0.45, 0.22)
                        else t.ch:SetVertexColor(1, 1 - 0.3 * hot, 0.88 - 0.6 * hot) end
                        t.sh:ClearAllPoints(); t.ch:ClearAllPoints()
                        t.sh:SetPoint("CENTER", cv, "TOPLEFT", x + 0.6, -(y + 0.6)); t.ch:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                        t.sh:SetAlpha(0); t.ch:SetAlpha(0)
                        t.sh:Show(); t.ch:Show()
                        beads[n] = { x = x, y = y, dx = dx, dy = dy, len = 18, sh = t.sh, ch = t.ch,
                            spd = 0.3 + 0.6 * hot, al = 0.8 + 0.2 * min(1, hot), ph = ((x * 0.137 + y * 0.291) % 1) }
                    end
                end
            end
        end
        self.beads = beads
        self.beadsHidden, self.beadAcc, self.readFade = nil, 1, 0
    end
    for i = #(self.beads or {}) + 1, #(self.beadPool or {}) do self.beadPool[i].sh:Hide(); self.beadPool[i].ch:Hide() end
    for i = used + 1, #pool do pool[i]:Hide() end
    for i = nl + 1, #lines do lines[i]:Hide() end
end

---------------------------------------------------------------------------
-- Moving hazards: one pooled texture set, redrawn every frame from the engine state
---------------------------------------------------------------------------
function UI:HzBegin() self.hzUsed = {} end
function UI:Hz(key, file, layer, sub, blend)
    self.hzPools = self.hzPools or {}
    local pool = self.hzPools[key]
    if not pool then pool = {}; self.hzPools[key] = pool end
    local n = (self.hzUsed[key] or 0) + 1
    self.hzUsed[key] = n
    local t = pool[n]
    if not t then
        t = W.Tex(self.canvas, layer or "ARTWORK", file, sub or 0)
        if blend then t:SetBlendMode(blend) end
        pool[n] = t
    end
    t:ClearAllPoints()
    t:SetAlpha(1)
    t:SetVertexColor(1, 1, 1, 1)
    if t.SetRotation then t:SetRotation(0) end
    t:Show()
    return t
end
function UI:HzEnd()
    for key, pool in pairs(self.hzPools or {}) do
        local n = self.hzUsed[key] or 0
        for i = n + 1, #pool do pool[i]:Hide() end
    end
end

-- a texture stretched along a segment (bars, gates, slider pills)
local function Bar(t, cv, x1, y1, x2, y2, thick)
    local dx, dy = x2 - x1, y2 - y1
    local len = sqrt(dx * dx + dy * dy)
    t:SetSize(len, thick)
    t:SetPoint("CENTER", cv, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    if t.SetRotation then t:SetRotation(atan2(-dy, dx)) end
end

local GOO = { default = { 0.55, 0.95, 0.2 }, voodoo = { 0.75, 0.35, 1 } }
local CURB = { 0.74, 0.71, 0.66 }   -- an added wall's colour when the hole doesn't say (PuttHard.lua "curb")

function UI:DrawHazards(el)
    local g, cv = self.game, self.canvas
    local h = g.hole
    self:HzBegin()
    if not h then return self:HzEnd() end
    local clock, rt = h.clock or 0, self.rt or 0
    local calm = NS.db.settings.reducedMotion
    -- patches: sand traps, ice sheets and boost lanes laid over the painted grass
    for _, q in ipairs(h.patches or {}) do
        local ter = Putt.TERRAIN[q.t]
        local w, hh = q.x2 - q.x1, q.y2 - q.y1
        local cx, cy = (q.x1 + q.x2) / 2, (q.y1 + q.y2) / 2
        if q.shape == "circle" then
            local rim = self:Hz("prim", "circle", "ARTWORK", -3)
            rim:SetSize(w + 5, hh + 5); rim:SetPoint("CENTER", cv, "TOPLEFT", cx, -cy)
            local d = self:Hz("pdisc", "circle", "ARTWORK", -2)
            d:SetSize(w, hh); d:SetPoint("CENTER", cv, "TOPLEFT", cx, -cy)
            if ter and ter.name == "ice" then
                rim:SetVertexColor(0.55, 0.75, 0.9, 0.9); d:SetVertexColor(0.8, 0.93, 1, 0.92)
                local sh = self:Hz("pice", "glow", "ARTWORK", -1, "ADD")
                sh:SetSize(w * 0.6, hh * 0.35); sh:SetPoint("CENTER", cv, "TOPLEFT", cx - w * 0.12, -(cy - hh * 0.18))
                sh:SetVertexColor(1, 1, 1, 0.5)
            else
                rim:SetVertexColor(0.55, 0.42, 0.2, 0.9); d:SetVertexColor(0.93, 0.82, 0.55, 0.96)
                -- a few darker dimples so it reads as sand, not a spotlight
                for k = 1, 5 do
                    local an = k * 1.257 + q.x * 0.1
                    local dm = self:Hz("pdim", "circle", "ARTWORK", -1)
                    dm:SetSize(5, 4); dm:SetPoint("CENTER", cv, "TOPLEFT", cx + cos(an) * w * 0.26, -(cy + sin(an) * hh * 0.26))
                    dm:SetVertexColor(0.72, 0.6, 0.36, 0.8)
                end
            end
        elseif ter and ter.boost then
            local horiz = abs(ter.boost[1]) > 0.5
            local bed = self:Hz("pbedb", "pill", "ARTWORK", -3)
            if horiz then Bar(bed, cv, q.x1 + 4, cy, q.x2 - 4, cy, hh) else Bar(bed, cv, cx, q.y1 + 4, cx, q.y2 - 4, w) end
            bed:SetVertexColor(0.16, 0.12, 0.05, 0.55)
            local len = horiz and w or hh
            local n = max(2, floor(len / 22))
            for k = 1, n do
                local u = (k - 0.5) / n
                local ax, ay = horiz and (q.x1 + w * u) or cx, horiz and cy or (q.y1 + hh * u)
                local a = self:Hz("parrow", "t_boost", "ARTWORK", -2)
                a:SetSize(20, 20); a:SetPoint("CENTER", cv, "TOPLEFT", ax, -ay)
                if a.SetRotation then a:SetRotation(-atan2(ter.boost[1], -ter.boost[2])) end
                local ph = (ax * ter.boost[1] + ay * ter.boost[2]) / 22
                a:SetVertexColor(1, 0.9, 0.4, calm and 0.85 or (0.5 + 0.5 * (0.5 + 0.5 * sin(ph * 1.6 - rt * 6))))
            end
        end
    end
    -- lucky coins: a bonus for the brave line
    for _, c in ipairs(h.coins or {}) do
        if not c.got then
            local bob = calm and 0 or sin(rt * 3 + c.x) * 2
            local sh = self:Hz("cshadow", "circle", "ARTWORK", 0)
            sh:SetSize(14, 7); sh:SetPoint("CENTER", cv, "TOPLEFT", c.x, -(c.y + 9))
            sh:SetVertexColor(0, 0, 0, 0.35)
            local gl = self:Hz("cglow", "glow", "ARTWORK", 5, "ADD")
            gl:SetSize(34, 34); gl:SetPoint("CENTER", cv, "TOPLEFT", c.x, -(c.y + bob))
            gl:SetVertexColor(1, 0.85, 0.3, 0.55)
            local t = self:Hz("coin", "flap\\coin", "ARTWORK", 6)
            local sq = calm and 1 or (0.55 + 0.45 * abs(cos(rt * 2.4 + c.y)))
            t:SetSize(18 * sq, 18); t:SetPoint("CENTER", cv, "TOPLEFT", c.x, -(c.y + bob))
        end
    end
    -- reading the green: while you are pulling back to putt (and for a moment when a hole opens)
    -- small beads drift downhill all over it, slow and pale where it barely leans, quick and amber
    -- where it is steep, red where it is too steep for a ball to stop. The rest of the time the
    -- green is left alone. Their textures are made once per hole (RenderSurface); here they are
    -- only moved, 30 times a second.
    local beads = self.beads
    if beads then
        local want = ((self.drag and g.state == "aim") and 1) or ((self.readUntil and rt < self.readUntil) and 0.85) or 0
        local fade = self.readFade or 0
        if fade < want then fade = min(want, fade + (el or 0.034) * 5) elseif fade > want then fade = max(want, fade - (el or 0.034) * 2.2) end
        self.readFade = fade
        if fade <= 0 then
            if not self.beadsHidden then
                for k = 1, #beads do beads[k].sh:SetAlpha(0); beads[k].ch:SetAlpha(0) end
                self.beadsHidden = true
            end
        else
            self.beadsHidden = nil
            self.beadAcc = (self.beadAcc or 1) + (el or 0.034)
            if self.beadAcc >= 0.033 then
                self.beadAcc = 0
                for k = 1, #beads do
                    local bd = beads[k]
                    local ph = calm and 0.5 or ((rt * bd.spd + bd.ph) % 1)
                    local off = (ph - 0.5) * bd.len
                    local bx, by = bd.x + bd.dx * off, bd.y + bd.dy * off
                    local al = (calm and 0.85 or sin(ph * pi)) * bd.al * fade
                    bd.sh:SetPoint("CENTER", cv, "TOPLEFT", bx + 0.6, -(by + 0.6))
                    bd.sh:SetAlpha(al * 0.5)
                    bd.ch:SetPoint("CENTER", cv, "TOPLEFT", bx, -by)
                    bd.ch:SetAlpha(al)
                end
            end
        end
    end
    -- a tunnel mouth the painting does not show (the far side of a doorway): a dark arch in the wall
    for _, pt in ipairs(h.portals or {}) do
        if pt.markB then
            local cb = h.curb or CURB
            -- tucked back against the wall it comes out of, rimmed in the wall's own stone
            local mx, my = pt.bx - (pt.dx or 0) * 6, pt.by - (pt.dy or 0) * 6
            local rim = self:Hz("tmrim", "circle", "ARTWORK", -3)
            rim:SetSize(pt.r * 2 + 6, pt.r * 2 + 6); rim:SetPoint("CENTER", cv, "TOPLEFT", mx, -my)
            rim:SetVertexColor(cb[1] * 0.95, cb[2] * 0.93, cb[3] * 0.9)
            local edge = self:Hz("tmedge", "circle", "ARTWORK", -2)
            edge:SetSize(pt.r * 2 + 1, pt.r * 2 + 1); edge:SetPoint("CENTER", cv, "TOPLEFT", mx, -my)
            edge:SetVertexColor(cb[1] * 0.45, cb[2] * 0.42, cb[3] * 0.4)
            local hole = self:Hz("tmhole", "circle", "ARTWORK", -1)
            hole:SetSize(pt.r * 2 - 3, pt.r * 2 - 3); hole:SetPoint("CENTER", cv, "TOPLEFT", mx, -my)
            hole:SetVertexColor(0.16, 0.11, 0.08)
        end
    end
    -- added walls (PuttHard.lua): a course of stone blocks in the colour of the hole's own curb
    if h.fences and #h.fences > 0 then
        local cb = h.curb or CURB
        local T = Putt.C.FENCE_T
        for _, f in ipairs(h.fences) do
            local x1, y1, x2, y2 = f[1], f[2], f[3], f[4]
            local dx, dy = x2 - x1, y2 - y1
            local len = sqrt(dx * dx + dy * dy)
            local ux, uy = dx / len, dy / len
            local sh = self:Hz("fsh", "pill", "ARTWORK", 1)
            Bar(sh, cv, x1 + 2, y1 + 3.5, x2 + 2 + ux, y2 + 3.5 + uy, T * 2 + 3)
            sh:SetVertexColor(0, 0, 0, 0.32)
            local n = max(2, floor(len / 10 + 0.5))
            local step = len / n
            for k = 0, n - 1 do
                local ax, ay = x1 + ux * step * k, y1 + uy * step * k
                local bx, by = x1 + ux * step * (k + 1), y1 + uy * step * (k + 1)
                local edge = self:Hz("fedge", "pill", "ARTWORK", 2)
                Bar(edge, cv, ax - ux * 0.4, ay - uy * 0.4, bx + ux * 0.4, by + uy * 0.4, T * 2 + 1.6)
                edge:SetVertexColor(cb[1] * 0.42, cb[2] * 0.40, cb[3] * 0.40)
                -- every other block a shade lighter, like laid stone
                local m = (k % 2 == 0) and 1 or 0.93
                local body = self:Hz("fbody", "pill", "ARTWORK", 3)
                Bar(body, cv, ax + ux * 0.7, ay + uy * 0.7, bx - ux * 0.7, by - uy * 0.7, T * 2 - 0.6)
                body:SetVertexColor(cb[1] * m, cb[2] * m, cb[3] * m)
                local hi = self:Hz("fhi", "pill", "ARTWORK", 4)
                Bar(hi, cv, ax + ux * 1.6, ay + uy * 1.6 - 1.4, bx - ux * 1.6, by - uy * 1.6 - 1.4, 2.2)
                hi:SetVertexColor(min(1, cb[1] * 1.16), min(1, cb[2] * 1.16), min(1, cb[3] * 1.16), 0.85)
            end
        end
    end
    -- sliders (mine carts, assembly arms): a pill along the bar's own line, wherever it points
    for _, m in ipairs(h.movers) do
        if m.kind == "slider" then
            local ox, oy = m.ox or 0, m.oy or 0
            local sh = self:Hz("slsh", "pill", "ARTWORK", 3)
            Bar(sh, cv, m.x1 + ox + 2, m.y1 + oy + 3, m.x2 + ox + 2, m.y2 + oy + 3, 11)
            sh:SetVertexColor(0, 0, 0, 0.4)
            local t = self:Hz("slider", "pill", "ARTWORK", 4)
            local dx, dy = m.x2 - m.x1, m.y2 - m.y1
            local l = sqrt(dx * dx + dy * dy)
            local ex, ey = dx / l * 4, dy / l * 4
            Bar(t, cv, m.x1 + ox - ex, m.y1 + oy - ey, m.x2 + ox + ex, m.y2 + oy + ey, 11)
            t:SetVertexColor(0.9, 0.72, 0.32)
        elseif m.kind == "gate" then
            -- the slot it slides along is always marked; the bar itself is iron
            local slot = self:Hz("gslot", "pill", "ARTWORK", 0)
            Bar(slot, cv, m.x1, m.y1, m.x2, m.y2, 6)
            if m.warn and not calm and (rt * 8) % 1 < 0.5 then slot:SetVertexColor(0.9, 0.25, 0.15, 0.7)
            else slot:SetVertexColor(0.1, 0.08, 0.06, 0.45) end
            local c = m.closed or 0
            if c > 0.02 then
                local ex, ey = m.x1 + (m.x2 - m.x1) * c, m.y1 + (m.y2 - m.y1) * c
                local shd = self:Hz("gsh", "pill", "ARTWORK", 3)
                Bar(shd, cv, m.x1 + 2, m.y1 + 4, ex + 2, ey + 4, 12)
                shd:SetVertexColor(0, 0, 0, 0.45)
                local bar = self:Hz("gate", "greens\\fx_gate", "ARTWORK", 4)
                Bar(bar, cv, m.x1, m.y1, ex, ey, 12)
            end
            local post = self:Hz("gpost", "circle", "ARTWORK", 5)
            post:SetSize(12, 12); post:SetPoint("CENTER", cv, "TOPLEFT", m.x1, -m.y1)
            post:SetVertexColor(0.35, 0.33, 0.32)
        elseif m.kind == "tram" and m.x then
            local sh = self:Hz("tramsh", "pill", "ARTWORK", 0)
            sh:SetSize(m.hw * 2 + 6, m.hh * 2 + 6); sh:SetPoint("CENTER", cv, "TOPLEFT", m.x + 3, -m.y - 5)
            sh:SetVertexColor(0, 0, 0, 0.5)
            local car = self:Hz("tram", "greens\\" .. (m.tex or "fig_tram"), "ARTWORK", 1)
            car:SetSize(m.hw * 2 + 12, m.hh * 2 + 8); car:SetPoint("CENTER", cv, "TOPLEFT", m.x, -m.y)
            car:SetVertexColor(1, 1, 1, 1)
        elseif m.kind == "orbit" then
            for k, pt in ipairs(m.pts or {}) do
                local gl = self:Hz("wglow", "glow", "ARTWORK", 5, "ADD")
                local pulse = calm and 1 or (1 + 0.12 * sin(rt * 6 + k))
                gl:SetSize(m.r * 4.2 * pulse, m.r * 4.2 * pulse)
                gl:SetPoint("CENTER", cv, "TOPLEFT", pt.x, -pt.y)
                gl:SetVertexColor(0.45, 0.9, 1, 0.8)
                local core = self:Hz("wcore", "circle", "ARTWORK", 6)
                core:SetSize(m.r * 2 + 1, m.r * 2 + 1)
                core:SetPoint("CENTER", cv, "TOPLEFT", pt.x, -pt.y)
                core:SetVertexColor(0.85, 1, 1, 0.95)
                if not calm and (k + floor(rt * 20)) % 6 == 0 then
                    self:Particle(pt.x, pt.y, (math.random() - 0.5) * 20, (math.random() - 0.5) * 20, 0.5, 6, { 0.5, 0.95, 1 }, 0.5)
                end
            end
        end
    end
    for _, a in ipairs(h.actors or {}) do
        local k = a.kind
        if k == "pool" then
            local f = Putt.PoolFill(a, clock)
            local _, u = Putt.Cycle(a, clock)
            -- the pool's bed is always visible, so you know where the water will come
            local bed = self:Hz("pbed", "circle", "ARTWORK", -1)
            bed:SetSize(a.r * 2, a.r * 2); bed:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
            bed:SetVertexColor(0.45, 0.4, 0.28, 0.35)
            local edge = self:Hz("pedge", "greens\\fx_dashring", "ARTWORK", 0)
            edge:SetSize(a.r * 2 + 4, a.r * 2 + 4); edge:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
            local warn = u > a.period - 0.9
            if warn and not calm then
                edge:SetVertexColor(0.6, 0.85, 1, 0.5 + 0.5 * abs(sin(rt * 10)))
            else
                edge:SetVertexColor(0.85, 0.75, 0.5, 0.6)
            end
            if f > 0.01 then
                local w = self:Hz("pwater", "circle", "ARTWORK", 1)
                local r = a.r * f
                w:SetSize(r * 2, r * 2); w:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
                w:SetVertexColor(0.16, 0.45, 0.85, 0.88)
                local foam = self:Hz("pfoam", "greens\\fx_ring", "ARTWORK", 2)
                foam:SetSize(r * 2 + 2, r * 2 + 2); foam:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
                foam:SetVertexColor(0.85, 0.95, 1, 0.75)
                local sh = self:Hz("pshine", "glow", "ARTWORK", 2, "ADD")
                sh:SetSize(r, r * 0.6); sh:SetPoint("CENTER", cv, "TOPLEFT", a.x - r * 0.3, -(a.y - r * 0.35))
                sh:SetVertexColor(0.6, 0.85, 1, 0.35)
            end
        elseif k == "ghoul" then
            local col = GOO[a.color or "default"] or GOO.default
            local tx, ty, st, v = Putt.Goo(a, clock)
            if st == "fly" then
                local fig = a.figure
                local hx, hy = (fig and fig.x or a.x), (fig and (fig.y - fig.h * 0.75) or a.y)
                local x, y = hx + (tx - hx) * v, hy + (ty - hy) * v - sin(v * pi) * 70
                -- the landing spot darkens as the blob comes down: read it and steer clear
                local sh = self:Hz("gshadow", "circle", "ARTWORK", 0)
                local sz = 8 + (a.r or 18) * 1.6 * v
                sh:SetSize(sz, sz); sh:SetPoint("CENTER", cv, "TOPLEFT", tx, -ty)
                sh:SetVertexColor(0, 0, 0, 0.15 + 0.35 * v)
                local mk = self:Hz("gmark", "greens\\fx_dashring", "ARTWORK", 1)
                mk:SetSize((a.r or 18) * 2 + 4, (a.r or 18) * 2 + 4); mk:SetPoint("CENTER", cv, "TOPLEFT", tx, -ty)
                mk:SetVertexColor(col[1], col[2], col[3], 0.25 + 0.5 * v)
                local gl = self:Hz("gblob", "glow", "OVERLAY", 1, "ADD")
                local bs = 16 + sin(v * pi) * 10
                gl:SetSize(bs * 1.8, bs * 1.8); gl:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                gl:SetVertexColor(col[1], col[2], col[3], 0.8)
                local core = self:Hz("gcore", "circle", "OVERLAY", 2)
                core:SetSize(bs * 0.6, bs * 0.6); core:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                core:SetVertexColor(col[1] * 0.8, col[2] * 0.8, col[3] * 0.8, 1)
            elseif v > 1 then
                local t = self:Hz("goo", "greens\\fx_goo", "ARTWORK", 0)
                t:SetSize(v * 2.4, v * 2.4); t:SetPoint("CENTER", cv, "TOPLEFT", tx, -ty)
                t:SetVertexColor(col[1], col[2], col[3], 0.95)
                if t.SetRotation then t:SetRotation((tx * 0.37 + ty * 0.11) % 6.28) end
                if not calm and (floor(rt * 12) % 5 == 0) then
                    self:Particle(tx + (math.random() - 0.5) * v, ty + (math.random() - 0.5) * v, 0, -14, 0.5, 5, col, 0.45)
                end
            end
        elseif k == "drum" then
            local R = Putt.DrumRing(a, clock)
            local _, u = Putt.Cycle(a, clock)
            -- reach: a faint ring so the shove zone can be read before you putt
            local zone = self:Hz("dzone", "greens\\fx_dashring", "ARTWORK", 0)
            zone:SetSize(a.reach * 2, a.reach * 2); zone:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
            zone:SetVertexColor(1, 0.6, 0.25, 0.35)
            local d = self:Hz("drum", "greens\\fx_drum", "ARTWORK", 6)
            local beat = (u < 0.15) and (1 + 0.15 * (1 - u / 0.15)) or 1
            d:SetSize(30 * beat, 30 * beat); d:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
            if R then
                local k2 = R / a.reach
                local ring = self:Hz("dring", "greens\\fx_wave", "ARTWORK", 6, "ADD")
                ring:SetSize(R * 2, R * 2); ring:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
                ring:SetVertexColor(1, 0.65, 0.25, 0.95 * (1 - k2))
                local r2 = self:Hz("dring", "greens\\fx_wave", "ARTWORK", 6, "ADD")
                r2:SetSize(R * 1.7, R * 1.7); r2:SetPoint("CENTER", cv, "TOPLEFT", a.x, -a.y)
                r2:SetVertexColor(1, 0.85, 0.5, 0.5 * (1 - k2))
            end
        elseif k == "whirl" then
            local wx, wy = Putt.WhirlPos(a, clock)
            -- a funnel: narrow at the ground, wider as it climbs. It swells while it has the ball.
            local tw = g.ball and g.ball.twist
            local held = tw and tw.a == a
            local sc = held and (1.25 + 0.2 * sin(rt * 18)) or 1
            local base = self:Hz("wshadow", "circle", "ARTWORK", 0)
            base:SetSize(a.r * 1.8 * sc, a.r * 1.2 * sc); base:SetPoint("CENTER", cv, "TOPLEFT", wx + 3, -wy - 4)
            base:SetVertexColor(0.2, 0.14, 0.06, 0.38)
            local sw = self:Hz("whirl", "greens\\fx_whirl", "ARTWORK", 5)
            sw:SetSize(a.r * 2.4 * sc, a.r * 1.5 * sc); sw:SetPoint("CENTER", cv, "TOPLEFT", wx, -wy - 2)
            sw:SetVertexColor(0.95, 0.85, 0.62, 0.8)
            if sw.SetRotation then sw:SetRotation(rt * 9) end
            -- the funnel itself: it sways, and flips several times a second so it reads as spinning
            local fn = self:Hz("tornado", "greens\\fx_tornado", "ARTWORK", 6)
            local hgt = a.r * 2.7 * sc
            local sway = calm and 0 or sin(rt * 4.5) * 3
            fn:SetSize(hgt * (0.94 + 0.06 * sin(rt * 23)), hgt)
            fn:SetPoint("BOTTOM", cv, "TOPLEFT", wx + sway, -(wy + 7))
            local flip = (not calm) and (floor(rt * 11) % 2 == 0)
            fn:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
            fn:SetVertexColor(1, 1, 1, 0.95)
            if held and not calm then
                for _ = 1, 2 do
                    local an = math.random() * 6.28
                    self:Particle(wx + cos(an) * a.r * 0.5, wy - math.random() * 28, -sin(an) * 120, cos(an) * 120 - 40, 0.45, 8, { 0.9, 0.78, 0.5 }, 0.6)
                end
            end
            if not calm and math.random() < 0.3 then
                local an = math.random() * 6.28
                self:Particle(wx + cos(an) * a.r * 0.8, wy + sin(an) * a.r * 0.8, -sin(an) * 60, cos(an) * 60, 0.6, 7, { 0.85, 0.7, 0.45 }, 0.4)
            end
        elseif k == "mage" then
            local hx, hy = a.x, a.y - 18
            local zone = self:Hz("mzone", "greens\\fx_dashring", "ARTWORK", 0)
            zone:SetSize(a.range * 2, a.range * 2); zone:SetPoint("CENTER", cv, "TOPLEFT", hx, -hy)
            zone:SetVertexColor(1, 0.45, 0.2, 0.35)
            if a.wind or a.rwind then
                local w = a.wind and (1 - a.wind / (a.windup or 0.45)) or (1 - a.rwind)
                local gl = self:Hz("mcast", "glow", "OVERLAY", 1, "ADD")
                gl:SetSize(12 + 26 * w, 12 + 26 * w)
                gl:SetPoint("CENTER", cv, "TOPLEFT", a.figure and a.figure.x or a.x, -((a.figure and a.figure.y or a.y) - (a.figH or 44) * 0.8))
                gl:SetVertexColor(1, 0.55, 0.15, 0.9)
            end
        end
    end
    -- fireballs in flight
    for _, sh in ipairs(g.shots or {}) do
        local gl = self:Hz("fball", "glow", "OVERLAY", 1, "ADD")
        gl:SetSize(30, 30); gl:SetPoint("CENTER", cv, "TOPLEFT", sh.x, -sh.y)
        gl:SetVertexColor(1, 0.5, 0.1, 0.95)
        local core = self:Hz("fcore", "circle", "OVERLAY", 2)
        core:SetSize(11, 11); core:SetPoint("CENTER", cv, "TOPLEFT", sh.x, -sh.y)
        core:SetVertexColor(1, 0.9, 0.5, 1)
        if not calm then self:Particle(sh.x, sh.y, -sh.vx * 0.1, -sh.vy * 0.1, 0.35, 12, { 1, 0.45, 0.1 }, 0.6) end
    end
    self:HzEnd()
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
-- the tunnel's route lights up as a dashed line under the course while the
-- ball rolls through, then fades once it pops out
function UI:UpdateTunnel(el, b)
    local fx = self.tunnelFx
    self.tunnelDots = self.tunnelDots or {}
    local dots = self.tunnelDots
    if not fx then
        for _, d in ipairs(dots) do d:Hide() end
        return
    end
    fx.t = fx.t + el
    local alpha
    if fx.out then
        fx.out = fx.out + el
        alpha = max(0, 0.5 - fx.out * 1.2)
        if alpha <= 0 then self.tunnelFx = nil end
    else
        alpha = min(0.5, fx.t * 3)
    end
    local pt = { ax = fx.fx, ay = fx.fy, bx = fx.tx, by = fx.ty }
    local len = sqrt((pt.bx - pt.ax) ^ 2 + (pt.by - pt.ay) ^ 2)
    local n = max(2, floor(len / 14))
    local reach = fx.out and 1 or min(1, fx.t / fx.dur)
    for i = 1, n do
        local d = dots[i]
        if not d then d = W.Tex(self.canvas, "ARTWORK", "circle", 1); d:SetSize(5, 5); dots[i] = d end
        local k = (i - 0.5) / n
        if k <= reach and alpha > 0 then
            d:SetPoint("CENTER", self.canvas, "TOPLEFT", pt.ax + (pt.bx - pt.ax) * k, -(pt.ay + (pt.by - pt.ay) * k))
            d:SetVertexColor(0.1, 0.07, 0.05, alpha)
            d:Show()
        else
            d:Hide()
        end
    end
    for i = n + 1, #dots do dots[i]:Hide() end
end

function UI:Particle(x, y, vx, vy, life, size, c, a)
    self.partIdx = self.partIdx % #self.parts + 1
    local p = self.parts[self.partIdx]
    p.x, p.y, p.vx, p.vy, p.life, p.max, p.size, p.a = x, y, vx, vy, life, life, size, a or 1
    p.t:SetVertexColor(c[1], c[2], c[3])
    p.t:Show()
end

function UI:Burst(x, y, c, n, speed)
    if NS.db.settings.reducedMotion then n = floor(n / 3) end
    for _ = 1, n do
        local a = math.random() * pi * 2
        local sp = (0.3 + math.random()) * (speed or 100)
        self:Particle(x, y, cos(a) * sp, sin(a) * sp, 0.35 + math.random() * 0.35, 6 + math.random() * 8, c, 1)
    end
end

function UI:Streak(fan)
    local cv = self.canvas
    local st
    for _, s2 in ipairs(self.streaks) do if s2.life <= 0 then st = s2; break end end
    if not st then
        if #self.streaks >= 90 then return end
        st = { t = W.Tex(cv, "ARTWORK", "streak", 5), life = 0 }
        st.t:SetBlendMode("ADD")
        self.streaks[#self.streaks + 1] = st
    end
    st.fan = fan
    st.along = 10 + math.random() * 20
    st.perp = (math.random() - 0.5) * fan.width * 0.8
    st.life, st.max = 1, 1
    st.speed = 260 + math.random() * 180
    if abs(fan.dx) > 0.5 then
        st.t:SetSize(42, 7); st.t:SetTexCoord(0, 1, 0, 1)
    else
        st.t:SetSize(7, 42); st.t:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    end
    st.t:Show()
end

function UI:UpdateStreaks(el)
    local cv = self.canvas
    for _, st in ipairs(self.streaks) do
        if st.life > 0 then
            local f = st.fan
            st.along = st.along + st.speed * el
            if st.along > f.len then st.life = 0; st.t:Hide() else
                local k = st.along / f.len
                local x = f.x + f.dx * st.along - f.dy * st.perp
                local y = f.y + f.dy * st.along + f.dx * st.perp
                st.t:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
                st.t:SetAlpha(0.85 * (1 - 0.6 * k) * min(1, st.along / 30))
            end
        end
    end
end

function UI:Banner(title, sub, c, dur)
    c = c or COLORS.gold
    self.banner:SetText(title)
    self.banner:SetTextColor(c[1], c[2], c[3])
    self.bannerSub:SetText(sub or "")
    self.banner:Show(); self.bannerSub:Show()
    self.bannerT, self.bannerMax = dur or 1.8, dur or 1.8
end

---------------------------------------------------------------------------
-- Engine events
---------------------------------------------------------------------------
UI.Events = {}
local E = UI.Events

function E:hole(index, h)
    self.readUntil = (self.rt or 0) + 3.6   -- show the lie of the new green for a moment
    self.ride = nil
    self.tunnelFx = nil
    self:RenderHole()
    local c = self.game.course
    local over = c and c.lands and c.lands[index]
    -- the big line stays short enough for the board; the land you are flying over goes on the line below
    local title = over and ("Hole %d of %d  -  Par %d"):format(index, #c.holes, h.par) or ("Hole %d  -  Par %d"):format(index, h.par)
    local name = over and ("Over %s:  %s"):format(over, h.name) or h.name
    self:Banner(title, name .. "\n|cff9499b3" .. (h.tip or "") .. "|r", COLORS.gold, 2.2)
end

function E:shot(n, power)
    W.SFX("putt")
    V:OnShot(self.game)
end

function E:wall(imp)
    W.SFX("knock", 0.06)
end

function E:bumper(b, imp)
    self:Burst(b.x, b.y, COLORS.gold, 5, 60)
    W.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 0.08)
end

function E:patrol(m, imp)
    self:Burst(m.x, m.y, m.faction == "horde" and { 1, 0.35, 0.25 } or { 0.4, 0.6, 1 }, 10, 90)
    W.SFX("knock", 0.06)
end

function E:grab(m)
    self:Burst(m.x, m.y, { 1, 0.9, 0.5 }, 10, 80)
    W.SFX("pop1")
end

function E:drop(m)
    self:Burst(m.x, m.y, { 1, 0.9, 0.5 }, 6, 60)
end

function E:launch(rp, air)
    if air.cannon then
        -- the barrel swings round to the line of the shot
        self.cannonRot = -math.atan2(air.tx - air.fx, -(air.ty - air.fy))
        -- muzzle flash and smoke
        self:Burst(air.fx, air.fy - 14, { 1, 0.75, 0.3 }, 14, 150)
        self:Burst(air.fx, air.fy - 8, { 0.6, 0.6, 0.6 }, 10, 60)
        W.SFX("knock")
    end
    self:Burst(air.fx, air.fy, { 0.85, 0.8, 0.7 }, 8, 70)
    W.Sound("IG_SPELLBOOK_OPEN", 0.3)
end

function E:hex(sheep)
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.7, 0.3, 0.9 }, 16, 120)
    W.Sound("IG_SPELLBOOK_OPEN", 0.3)
    self:Banner(sheep and "Polymorphed!" or "Hexed!", sheep and "Baaa." or "Ribbit.", { 0.7, 0.4, 0.95 }, 1.2)
end

function E:hexEnd()
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.7, 0.3, 0.9 }, 10, 90)
end

function E:hearth(fx, fy)
    self:Burst(fx, fy, { 0.4, 0.8, 1 }, 18, 130)
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.4, 0.8, 1 }, 12, 90)
    W.Sound("IG_SPELLBOOK_OPEN", 0.3)
    self:Banner("Hearthstone!", "Back to the tee. No stroke lost.", { 0.4, 0.8, 1 }, 1.6)
end

function E:bless()
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.55, 0.8, 1 }, 16, 110)
    W.Sound("IG_SPELLBOOK_OPEN", 0.3)
    self:Banner("Moonwell blessing", "Your next shot goes further.", { 0.55, 0.8, 1 }, 1.4)
end

function E:blessUsed()
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.55, 0.8, 1 }, 10, 140)
end

function E:land(air)
    self:Burst(air.tx, air.ty, { 0.9, 0.95, 0.8 }, 10, 80)
    W.SFX("pop1")
end

function E:rampShort()
    self:Banner("Not enough pace", "Hit the ramp harder to fly over.", COLORS.dim, 1.2)
end

function E:boost()
    local b = self.game.ball
    self:Burst(b.x, b.y, TERRAIN_COLOR.boost, 10, 90)
    W.Sound("IG_SPELLBOOK_OPEN", 0.3)
end

function E:portal(pt, dur, tu)
    if pt.lift then
        -- a lift: the ball rides the platform in plain sight (see the ball drawing in OnUpdate)
        W.SFX("launch")
        return
    end
    if pt.baked then
        -- into the tunnel: a puff of dust, then its shadow rolls along underground
        local fx, fy, tx, ty = pt.ax, pt.ay, pt.bx, pt.by
        if tu then fx, fy, tx, ty = tu.fx, tu.fy, tu.tx, tu.ty end
        self.tunnelFx = { pt = pt, t = 0, dur = dur or 0.6, fx = fx, fy = fy, tx = tx, ty = ty }
        self:Burst(fx, fy, { 0.55, 0.45, 0.35 }, 8, 60)
        W.SFX("tunnel")
        return
    end
    self:Burst(pt.ax, pt.ay, { 0.75, 0.45, 1 }, 14, 120)
    self:Burst(pt.bx, pt.by, { 0.35, 0.75, 1 }, 14, 120)
    W.Sound("IG_SPELLBOOK_OPEN")
end

function E:tunnelOut(pt, tu)
    if pt.lift then W.SFX("knock", 0.05); return end
    local x, y = pt.bx, pt.by
    if tu then x, y = tu.tx, tu.ty end
    self:Burst(x, y, { 0.6, 0.5, 0.38 }, 12, 90)
    W.SFX("knock", 0.05)
    if self.tunnelFx then self.tunnelFx.out = 0 end
end

function E:relief(x0, y0, x, y)
    -- ball eased off the rail: a soft puff where it lands so the nudge reads as intentional
    self:Burst(x, y, { 1, 1, 1 }, 6, 40)
end

function E:lip()
    self:Banner("Lipped out!", nil, COLORS.dim, 1.0)
end

function E:hazard(text, x, y, free)
    local ch = Putt.Cell(self.game.hole, x, y)
    local ter = ch and Putt.TERRAIN[ch]
    self:Burst(x, y, (ter and TERRAIN_COLOR[ter.name]) or COLORS.blue, 22, 140)
    if free then
        self:Banner(text, "Knocked in - no penalty. Back to your spot.", COLORS.gold, 1.5)
    else
        self:Banner(text, "+1 stroke. Back to your last spot.", COLORS.red, 1.5)
    end
    W.SFX("splash")
end

function E:knocked()
    -- something walked into the resting ball: drop any half-drawn putt
    self.drag = nil
    local b = self.game.ball
    self:Burst(b.x, b.y, { 1, 0.9, 0.6 }, 8, 70)
    W.SFX("knock", 0.05)
end

function E:windup(a)
    W.Sound("IG_SPELLBOOK_OPEN", 0.2)
end

function E:cast(a)
    W.SFX("knock", 0.1)
end

function E:fireball(x, y)
    self:Burst(x, y, { 1, 0.5, 0.1 }, 18, 130)
    self:Hint("Fireball! Keep your distance from the mage.")
    W.SFX("splash", 0.2)
end

function E:fizzle(x, y)
    self:Burst(x, y, { 1, 0.6, 0.2 }, 5, 40)
end

function E:goo(x, y)
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.55, 0.95, 0.2 }, 10, 60)
    W.SFX("splash", 0.3)
end

function E:drumhit(a, x, y)
    self:Burst(x, y, { 1, 0.65, 0.25 }, 10, 90)
    W.SFX("knock", 0.08)
end

function E:whirl(a)
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.85, 0.7, 0.45 }, 8, 70)
end

-- the tornado has the ball
function E:twister(a)
    self.drag = nil
    local b = self.game.ball
    self:Burst(b.x, b.y, { 0.9, 0.78, 0.5 }, 18, 140)
    W.SFX("rb_rumble", 0.2)
    self:Hint("The dust devil has your ball!")
end

-- ...and throws it
function E:twistThrow(a, air)
    self:Burst(air.fx, air.fy - 20, { 0.95, 0.85, 0.6 }, 26, 220)
    W.SFX("launch", 0.1)
end

function E:washed(a)
    self:Burst(a.x, a.y, { 0.45, 0.75, 1 }, 18, 130)
    W.SFX("splash", 0.2)
    self:Hint("The tide washed your ball out")
end

function E:gust(f)
    self:Hint("The fan blew your ball away")
end

function E:wisp(p, imp)
    self:Burst(p.x, p.y, { 0.5, 0.95, 1 }, 10, 90)
    W.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 0.08)
end

function E:coin(c)
    self:Burst(c.x, c.y, { 1, 0.85, 0.3 }, 16, 120)
    self:Hint(("Lucky coin! -%ds if you finish the hole."):format(P.COIN_SEC))
    W.SFX("coin_win", 0.1)
end

function E:pickup()
    self:Banner("Picked up", "Max strokes reached - on to the next hole", COLORS.dim, 1.6)
end

local NAMES = { [-3] = "Albatross!", [-2] = "Eagle!", [-1] = "Birdie!", [0] = "Par", [1] = "Bogey", [2] = "Double bogey" }
function E:sunk(strokes, par, adj, sunk)
    local db = self.db
    db.holes = db.holes + 1
    V:OnHole(self.game, strokes, sunk)
    local cup = self.game.hole.cup
    if sunk then
        local diff = strokes - par
        local name = strokes == 1 and "HOLE IN ONE!" or NAMES[diff] or ("+" .. diff)
        local c = diff < 0 and COLORS.green or (diff == 0 and COLORS.gold or COLORS.dim)
        self:Banner(name, Putt.FormatAdj(adj) .. " on your time", c, 1.6)
        self:Burst(cup.x, cup.y, c, diff < 0 and 40 or 18, diff < 0 and 220 or 120)
        self:CheerFigures(diff <= 0)
        W.SFX("cup")
        if strokes == 1 then
            db.aces = db.aces + 1
            W.SFX("fever_bin")
        elseif diff < 0 then
            W.SFX("freeball")
        end
    end
    self:CheckUnlocks()
end

function E:done(final, elapsed, adj, strokes, par)
    local db = self.db
    local kind = self.game.course.kind
    db.round = nil
    if strokes < par then db.underPar = db.underPar + 1 end
    local newBest = false
    local landedIt
    if kind == "versus" then
        -- a match is scored on the wall clock and stays off the leaderboards
        local vfinal = V:OnFinish(self.game, adj, strokes, par)
        if vfinal then self.game.final = vfinal end
        self:CheckUnlocks()
        W.Sound("IG_QUEST_LIST_COMPLETE")
        return self:ShowVersusResults()
    end
    if kind == "route" then
        local c = self.game.course
        local spec = c.route
        -- finished before the wheels touch down: the flight's own bonus
        landedIt = c.live and UnitOnTaxi and UnitOnTaxi("player") and true or false
        if landedIt then final = Putt.FinalTime(elapsed, adj - 5) end
        -- a route's record counts wherever you play it; only a round in the air can earn the landing bonus
        local e = NS.Route.Note(spec)
        e.par = par
        e.plays = (e.plays or 0) + 1
        if landedIt then e.landed = (e.landed or 0) + 1 end
        if not e.best or final < e.best then e.best, e.strokes = final, strokes; newBest = true end
        NS.Social:SubmitBest(NS.Route.Board(spec), final, ("%d:%d"):format(strokes, par))
        self:CheckUnlocks()
        if NS.Shell then NS.Shell:RefreshDots() end
        W.Sound("IG_QUEST_LIST_COMPLETE")
        return self:ShowResults(final, elapsed, adj, strokes, par, newBest, landedIt)
    end
    if kind == "daily" then
        local day = Today()
        local d = db.daily[day] or { tries = 0 }
        db.daily[day] = d
        if not d.best then db.dailies = db.dailies + 1 end
        d.tries = (d.tries or 0) + 1
        if not d.best or final < d.best then
            d.best, d.strokes, d.par = final, strokes, par
            newBest = true
            if NS.db.settings.share then
                NS.Social:Submit("putt", day, final, ("%d:%d"):format(strokes, par))
            end
        end
    else
        if not db.quickBest or final < db.quickBest then db.quickBest = final end
        local key = self.game.course.key or "human"
        db.courseBest = db.courseBest or {}
        if not db.courseBest[key] or final < db.courseBest[key] then db.courseBest[key] = final; newBest = true end
        if NS.Social.GAMES["pq_" .. key] then
            NS.Social:SubmitBest("pq_" .. key, final, ("%d:%d"):format(strokes, par))
        end
    end
    self:CheckUnlocks()
    if NS.Shell then NS.Shell:RefreshDots() end
    W.Sound("IG_QUEST_LIST_COMPLETE")
    self:ShowResults(final, elapsed, adj, strokes, par, newBest)
end

function UI:CheckUnlocks()
    self.seenUnlocks = self.seenUnlocks or {}
    local db = self.db
    db.unlockSeen = db.unlockSeen or {}
    for _, list in ipairs({ UI.BALLS, UI.CLUBS }) do
        for _, item in ipairs(list) do
            if item.req and Unlocked(db, item) and not db.unlockSeen[item.id] then
                db.unlockSeen[item.id] = true
                self:Banner("Unlocked: " .. item.name, "Equip it in the Locker", COLORS.green, 2.4)
                W.Sound("IG_PLAYER_INVITE")
            end
        end
    end
end

---------------------------------------------------------------------------
-- Scenery figures: Warcraft locals watching your round
---------------------------------------------------------------------------
local FIG_LINES = {
    murloc = { "Mrrglglglgl!", "Mrgl mrgl!", "Aaaaughibbrgubugbugrguburgle!" },
    murloc_blue = { "Mrrglglglgl!", "Mrgl?" },
    kobold = { "You no take candle!", "Yiieee!" },
    hogger = { "Grrr... fresh meat!", "More bones to gnaw on..." },
    gnoll = { "Yip yip!", "Grrr!" },
    defias = { "The Brotherhood shall prevail!", "Hand over the gold!" },
    footman = { "Light be with you.", "Keep that ball in line, citizen." },
    turtle = { "*SNAP*", "*hissss*" },
    priest = { "Light bless your swing!" },
    warrior = { "Nice shot!", "For the Alliance!" },
    mage = { "Careful with that thing!", "Fireball!", "Too close!" },
    golem = { "*whirr* *clank*" },
    worgen = { "Awoooo!", "Grrrr..." },
    raven = { "Caw!" },
    ghoul = { "Braaains... and putts.", "Have some slime!", "Hrrrnngh!" },
    grommash = { "Lok'tar!", "Feel the drums!", "Blood and thunder!" },
    troll = { "Ya feel da voodoo, mon?", "Hexed!", "Stay away from da Voodoo." },
}

function UI:HideFigures()
    for _, f in ipairs(self.figTex or {}) do f.tex:Hide(); f.shadow:Hide() end
    if self.bubble then self.bubble:Hide(); self.bubbleT = nil end
    self.figN = 0
end

function UI:ShowFigures(h)
    self:HideFigures()
    local cv = self.canvas
    for i, fig in ipairs(h.figures or {}) do
        local f = self.figTex[i]
        if not f then
            f = { shadow = W.Tex(cv, "BACKGROUND", "glow", -4), tex = cv:CreateTexture(nil, "BACKGROUND", nil, -3) }
            f.shadow:SetVertexColor(0, 0, 0, 0.55)
            self.figTex[i] = f
        end
        f.fig = fig
        f.tex:SetTexture(W.MEDIA .. "greens\\fig_" .. fig.name)
        f.tex:SetTexCoord(fig.flip and 1 or 0, fig.flip and 0 or 1, 0, 1)
        f.tex:SetSize(fig.h, fig.h)
        f.shadow:SetSize(fig.h * 0.62, fig.h * 0.16)
        f.shadow:SetPoint("CENTER", self.canvas, "TOPLEFT", fig.x, -(fig.y - fig.h * 0.02))
        f.jump, f.near = 0, false
        -- the same prop in another land's colours (the Undercity's elevator is the lift in cold iron)
        if f.tex.SetDesaturated then f.tex:SetDesaturated(fig.gray and true or false) end
        local tint = fig.tint
        f.tex:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1)
        f.tex:SetAlpha(1)
        f.tex:Show(); f.shadow:Show()
    end
    self.figN = #(h.figures or {})
    self.figTalk = 1.5 -- nobody pipes up the instant a hole starts
end

function UI:Say(f, text)
    if not self.bubble then
        local b = CreateFrame("Frame", nil, self.canvas, BackdropTemplateMixin and "BackdropTemplate" or nil)
        b:SetFrameLevel(self.canvas:GetFrameLevel() + 6)
        if b.SetBackdrop then
            b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            b:SetBackdropColor(1, 0.97, 0.88, 0.95)
            b:SetBackdropBorderColor(0.18, 0.12, 0.08, 1)
        end
        b.text = W.Text(b, 11)
        b.text:SetTextColor(0.18, 0.12, 0.08)
        b.text:SetShadowOffset(0, 0)
        b.text:SetPoint("CENTER")
        self.bubble = b
    end
    local b, fig = self.bubble, f.fig
    b.text:SetText(text)
    b:SetSize(b.text:GetStringWidth() + 14, 20)
    -- keep the bubble on the canvas
    local x = max(b:GetWidth() / 2 + 4, min(Putt.C.W - b:GetWidth() / 2 - 4, fig.x))
    local y = max(14, fig.y - fig.h - 10)
    b:ClearAllPoints()
    b:SetPoint("CENTER", self.canvas, "TOPLEFT", x, -y)
    b:SetAlpha(1)
    b:Show()
    self.bubbleT = 2.4
end

function UI:CheerFigures(happy)
    for i = 1, self.figN or 0 do
        local f = self.figTex[i]
        if f and f.fig.anim ~= "still" and f.fig.anim ~= "sway" then f.jump = happy and 0.55 or 0.3 end
    end
end

function UI:UpdateFigures(el)
    -- a tide washes in and out: its band shows only while it is pushing
    local hh = self.game and self.game.hole
    for i, fan in ipairs(hh and hh.fans or {}) do
        local f = self.fanTex[i]
        if fan.period and f and f.band then
            local on = (((self.game.hole and self.game.hole.clock) or 0) % fan.period) <= fan.period * 0.45
            f.band:SetAlpha(on and 0.55 or 0.06)
        end
    end
    local n = self.figN or 0
    if n == 0 then return end
    local g, cv, t = self.game, self.canvas, self.rt or 0
    local calm = NS.db.settings.reducedMotion
    local b = g.ball
    local rolling = g.state == "roll" and b and not b.tunnel
    self.figTalk = (self.figTalk or 0) - el
    for i = 1, n do
        local f = self.figTex[i]
        local fig = f.fig
        local x, y, h = fig.x, fig.y, fig.h
        local dy, sx, sy, rot = 0, 1, 1, 0
        local dx, hurt = 0, 0
        if fig.name == "mortar" or fig.name == "gcannon" then rot = self.cannonRot or 0 end
        local ph = t + fig.phase
        if not calm then
            -- the ball rolling past makes them jump (and maybe say something)
            if rolling and fig.anim ~= "still" then
                local d = sqrt((b.x - x) ^ 2 + (b.y - (y - h * 0.4)) ^ 2)
                local near = d < h * 0.6 + 34
                if near and not f.near then
                    if fig.anim ~= "sway" then f.jump = 0.45 end
                    local lines = FIG_LINES[fig.name]
                    if lines and self.figTalk <= 0 then
                        self:Say(f, lines[math.random(#lines)])
                        self.figTalk = 5
                    end
                end
                f.near = near
            else
                f.near = false
            end
            local a = fig.anim
            if f.jump > 0 then
                f.jump = f.jump - el
                local k = max(0, f.jump) / 0.45
                dy = sin(min(1, k) * pi) * h * 0.22
            elseif a == "breathe" then
                local s = sin(ph * 2.2)
                sy, sx = 1 + 0.025 * s, 1 - 0.012 * s
            elseif a == "bob" then
                dy = abs(sin(ph * 3.2)) * h * 0.05
                sy = 1 - 0.03 * (1 - abs(sin(ph * 3.2)))
            elseif a == "hop" then
                local k = (ph * 0.45) % 1 -- one little hop every ~2.2s
                if k < 0.16 then dy = sin(k / 0.16 * pi) * h * 0.16 else sy, sx = 1 + 0.03 * sin(ph * 4), 1 end
            elseif a == "fight" then
                -- two figures trading blows: lunge at the other one, then flinch when it lunges back (fig.beat = 0 or 0.5)
                local k = (t * 0.75 + (fig.beat or 0)) % 1
                local dir = fig.dir or 1
                if k < 0.2 then
                    local p = sin(k / 0.2 * pi)
                    dx, rot, dy = dir * p * h * 0.30, -dir * p * 0.16, p * h * 0.05
                elseif k > 0.56 and k < 0.72 then
                    local p = sin((k - 0.56) / 0.16 * pi)
                    dx, hurt = -dir * p * h * 0.09, p
                else
                    local sb = sin(t * 5 + (fig.beat or 0) * 6)
                    sy, sx = 1 + 0.02 * sb, 1 - 0.01 * sb
                end
            elseif a == "sway" then
                rot = sin(ph * 1.5) * 0.06
            elseif a == "peck" then
                local k = (ph * 0.6) % 1
                if k < 0.12 then rot = (fig.flip and 1 or -1) * sin(k / 0.12 * pi) * 0.35 end
            end
        end
        -- a lift platform carrying the ball rises or sinks with it (the ride is worked out with the ball)
        local rs, ra = 1, 1
        local rd = self.ride
        if rd and (fig.name == "lift" or fig.lift) then
            local cy = y - h / 2
            if (x - rd.x) ^ 2 + (cy - rd.y) ^ 2 < 400 then rs, ra = rd.s, rd.a
            elseif (x - rd.fx) ^ 2 + (cy - rd.fy) ^ 2 < 400 then ra = max(0, (rd.k - 0.5) / 0.5) end
        end
        f.tex:SetAlpha(ra)
        f.tex:SetSize(h * sx * rs, h * sy * rs)
        f.tex:SetPoint("BOTTOM", cv, "TOPLEFT", x + dx, -(y + h * (rs - 1) / 2 - dy))
        if f.tex.SetRotation then f.tex:SetRotation(rot) end
        if fig.anim == "fight" then f.tex:SetVertexColor(1, 1 - 0.55 * hurt, 1 - 0.55 * hurt) end
        f.shadow:SetAlpha(1 - min(0.5, dy / h * 2))
    end
    if self.bubbleT then
        self.bubbleT = self.bubbleT - el
        if self.bubbleT <= 0 then self.bubble:Hide(); self.bubbleT = nil
        else self.bubble:SetAlpha(min(1, self.bubbleT / 0.4)) end
    end
end

---------------------------------------------------------------------------
-- Aiming
---------------------------------------------------------------------------
function UI:AimVector()
    local d = self.drag
    if not d or not self.cx then return end
    local dx, dy = d.x - self.cx, d.y - self.cy
    local len = sqrt(dx * dx + dy * dy)
    if len < 4 then return end
    return atan2(dy, dx), min(1, len / DRAG_FULL)
end

function UI:Release()
    if not self.drag then return end
    local a, power = self:AimVector()
    -- shoot what the guide shows (the eased aim), so the putt matches the line on screen
    if a and self.aimA then a = self.aimA end
    self.drag = nil
    self.aimA, self.aimP = nil, nil
    if self:Paused() then return end
    if a and power and power > 0.03 then
        self.game:Shoot(a, power)
    elseif self.game.state == "aim" then
        self:Hint("Pull back further, then let go to putt")
    end
end

-- a small line under the course that fades out
function UI:Hint(text)
    if not self.hint then
        self.hint = W.Text(self.frame, 12)
        self.hint:SetPoint("BOTTOM", self.canvas, "BOTTOM", 0, 10)
        self.hint:SetTextColor(1, 0.85, 0.4)
    end
    self.hint:SetText(text)
    self.hint:SetAlpha(1)
    self.hint:Show()
    self.hintT = 2.2
end

---------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    local g, cv = self.game, self.canvas
    self.rt = (self.rt or 0) + el
    if not self:Paused() then g:Update(el) end

    local x, y = GetCursorPosition()
    local s = cv:GetEffectiveScale()
    local l, t = cv:GetLeft(), cv:GetTop()
    if l and t then self.cx, self.cy = x / s - l, t - y / s end
    if self.drag and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then self:Release() end
    if self.hintT then
        self.hintT = self.hintT - el
        if self.hintT <= 0 then self.hint:Hide(); self.hintT = nil else self.hint:SetAlpha(min(1, self.hintT / 0.6)) end
    end

    local h = g.hole
    if h then
        -- ball
        local b = g.ball
        local show = g.state ~= "sunk" and g.state ~= "done"
        -- underground (tunnel) or under a roof (the windmill): only a shadow shows
        -- on a lift it stays in sight and rides the platform
        local ride = b.tunnel and b.tunnel.pt.lift
        local hidden = b.tunnel ~= nil and not ride
        local covered = false
        if not hidden and h.covers then
            for _, c in ipairs(h.covers) do
                if b.x > c[1] and b.x < c[3] and b.y > c[2] and b.y < c[4] then covered = true end
            end
        end
        self.ballTex:SetShown(show and not hidden and not covered)
        self.ballGlow:SetShown(show and not hidden and not covered)
        self.ballShadow:SetShown(show)
        self:UpdateTunnel(el, b)
        if show and ride then
            -- the platform carries the ball out of sight at one end (rising towards you, or sinking
            -- away) and brings it into sight at the other; the platforms themselves follow in UpdateFigures
            local tu = b.tunnel
            local k = min(1, tu.t / tu.dur)
            local up = (ride == "up") == (tu.toB and true or false)
            local far, near = up and 1.5 or 0.55, up and 0.55 or 1.5
            local s, al, x, y
            if k < 0.5 then
                local q = k / 0.5
                s, al, x, y = 1 + (far - 1) * q, 1 - max(0, (q - 0.45) / 0.55), tu.fx, tu.fy
            else
                local q = (k - 0.5) / 0.5
                s, al, x, y = near + (1 - near) * q, min(1, q / 0.55), tu.tx, tu.ty
            end
            self.ride = { x = x, y = y, s = s, a = al, fx = tu.fx, fy = tu.fy, k = k }
            local bs = (P.BALL_R * 2 + 2) * s
            self.ballTex:SetSize(bs, bs)
            self.ballTex:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
            self.ballGlow:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
            self.ballTex:SetAlpha(al); self.ballGlow:SetAlpha(al)
            self.ballShadow:SetPoint("CENTER", cv, "TOPLEFT", x + 2, -y - 2)
            self.ballShadow:SetAlpha(al * 0.6)
        elseif show and hidden then
            local tu = b.tunnel
            local k = min(1, tu.t / tu.dur)
            local sx, sy = tu.fx + (tu.tx - tu.fx) * k, tu.fy + (tu.ty - tu.fy) * k
            self.ballShadow:SetPoint("CENTER", cv, "TOPLEFT", sx, -sy)
            self.ballShadow:SetAlpha(0.55 + 0.25 * sin(self.rt * 30))
        elseif show then
            if self.ride then self.ride = nil; self.ballTex:SetAlpha(1); self.ballGlow:SetAlpha(1) end
            -- off a ramp the ball rises toward you: bigger, lifted, its shadow left on the ground
            local z = b.z or 0
            local bs = (P.BALL_R * 2 + 2) * (1 + 0.75 * z)
            self.ballTex:SetSize(bs, bs)
            self.ballShadow:SetAlpha(1 - 0.45 * z)
            local lift = (b.lift or 16) * z
            self.ballTex:SetPoint("CENTER", cv, "TOPLEFT", b.x, -(b.y - lift))
            self.ballGlow:SetPoint("CENTER", cv, "TOPLEFT", b.x, -(b.y - lift))
            self.ballShadow:SetPoint("CENTER", cv, "TOPLEFT", b.x + 2 + 5 * z, -b.y - 2 - 5 * z)
            -- hexed: the ball is a frog until the brew wears off
            if b.hexT then
                if not self.frogTex then self.frogTex = cv:CreateTexture(nil, "ARTWORK", nil, 6) end
                self.frogTex:SetTexture(W.MEDIA .. "greens\\" .. (b.hexSheep and "fig_sheep" or "fig_frog"))
                local hop = abs(sin((self.rt or 0) * 14)) * 5
                self.frogTex:SetSize(24, 24); self.frogTex:ClearAllPoints()
                self.frogTex:SetPoint("CENTER", cv, "TOPLEFT", b.x, -(b.y - 4 - hop))
                self.frogTex:SetTexCoord((b.vx or 0) > 0 and 1 or 0, (b.vx or 0) > 0 and 0 or 1, 0, 1)
                self.frogTex:Show(); self.ballTex:SetAlpha(0); self.ballGlow:SetAlpha(0)
                self.frogOn = true
            elseif self.frogOn then
                self.frogTex:Hide(); self.ballTex:SetAlpha(1); self.ballGlow:SetAlpha(1); self.frogOn = nil
            end
            if g.state == "roll" and not NS.db.settings.reducedMotion then
                self.trailT = (self.trailT or 0) - el
                if self.trailT <= 0 then
                    self.trailT = 0.03
                    local c = self:Ball().color
                    self:Particle(b.x, b.y, 0, 0, 0.25, 8, c, 0.35)
                end
            end
        end
        -- movers
        local dotN = 0
        self.patrolN = 0
        local sailN = 0
        for _, m in ipairs(h.movers) do
            if m.kind == "spinner" and m.sails then
                -- windmill sails: one painted sail per arm, turning with the physics
                for k = 0, m.arms - 1 do
                    local a = (m.a or 0) + k * 2 * pi / m.arms
                    sailN = sailN + 1
                    local t = self.sails[sailN]
                    if not t then
                        t = { sail = W.Tex(cv, "ARTWORK", "sail", 5), shadow = W.Tex(cv, "ARTWORK", "sail", 3) }
                        t.shadow:SetVertexColor(0, 0, 0, 0.35)
                        self.sails[sailN] = t
                    end
                    if t.gear then t.sail:SetTexture(W.MEDIA .. "sail"); t.shadow:SetTexture(W.MEDIA .. "sail"); t.gear = nil end
                    local cx, cy = m.cx + cos(a) * m.len / 2, m.cy + sin(a) * m.len / 2
                    t.sail:SetSize(m.len + 4, 18); t.shadow:SetSize(m.len + 4, 18)
                    t.sail:SetPoint("CENTER", cv, "TOPLEFT", cx, -cy)
                    t.shadow:SetPoint("CENTER", cv, "TOPLEFT", cx + 5, -cy - 7)
                    if t.sail.SetRotation then t.sail:SetRotation(-a); t.shadow:SetRotation(-a) end
                    t.sail:Show(); t.shadow:Show()
                end
            elseif m.kind == "spinner" and m.gear then
                -- Gnomeregan: a big brass gear turning with the physics (its teeth are the arms)
                sailN = sailN + 1
                local t = self.sails[sailN]
                if not t then
                    t = { sail = W.Tex(cv, "ARTWORK", "sail", 5), shadow = W.Tex(cv, "ARTWORK", "sail", 3) }
                    t.shadow:SetVertexColor(0, 0, 0, 0.35)
                    self.sails[sailN] = t
                end
                local size = m.len * 2 + 6
                t.sail:SetTexture(W.MEDIA .. "greens\\fig_gear"); t.shadow:SetTexture(W.MEDIA .. "greens\\fig_gear")
                t.sail:SetSize(size, size); t.shadow:SetSize(size, size)
                t.sail:SetPoint("CENTER", cv, "TOPLEFT", m.cx, -m.cy)
                t.shadow:SetPoint("CENTER", cv, "TOPLEFT", m.cx + 5, -m.cy - 7)
                if t.sail.SetRotation then t.sail:SetRotation(-(m.a or 0)); t.shadow:SetRotation(-(m.a or 0)) end
                t.sail:Show(); t.shadow:Show()
                t.gear = true
            elseif m.kind == "spinner" then
                for k = 0, m.arms - 1 do
                    local a = (m.a or 0) + k * 2 * pi / m.arms
                    for j = 0, 7 do
                        dotN = dotN + 1
                        local d = self.moverDots[dotN]
                        if not d then d = W.Tex(cv, "ARTWORK", "circle", 4); self.moverDots[dotN] = d end
                        local r = 6 + j * (m.len - 6) / 7
                        d:SetSize(9, 9)
                        d:SetVertexColor(0.85, 0.68, 0.3)
                        d:SetPoint("CENTER", cv, "TOPLEFT", m.cx + cos(a) * r, -(m.cy + sin(a) * r))
                        d:Show()
                    end
                end
            elseif m.kind == "patrol" and m.x then
                local pi_ = #self.patrolTex
                dotN = dotN -- (patrols use their own pool)
                self.patrolN = (self.patrolN or 0) + 1
                local p = self.patrolTex[self.patrolN]
                if not p then
                    p = { shadow = W.Tex(cv, "ARTWORK", "glow", 2), token = W.Tex(cv, "ARTWORK", "token", 4),
                          emblem = cv:CreateTexture(nil, "ARTWORK", nil, 5) }
                    p.emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    if cv.CreateMaskTexture and p.emblem.AddMaskTexture then
                        p.mask = cv:CreateMaskTexture()
                        p.mask:SetTexture(W.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                        p.emblem:AddMaskTexture(p.mask)
                        p.masked = true
                    end
                    self.patrolTex[self.patrolN] = p
                end
                local horde = m.faction == "horde"
                local rider = PATROL_RIDERS[m.faction]
                if rider then
                    -- a little figure riding the token, like a board-game piece
                    if p.mask and p.masked and p.emblem.RemoveMaskTexture then p.emblem:RemoveMaskTexture(p.mask); p.masked = false end
                    p.emblem:SetTexCoord((m.dx or 1) < 0 and 1 or 0, (m.dx or 1) < 0 and 0 or 1, 0, 1)
                    p.emblem:SetTexture(W.MEDIA .. "greens\\fig_" .. rider)
                    local tc = RIDER_TINT[m.faction] or { 0.25, 0.45, 0.95 }
                    p.token:SetVertexColor(tc[1], tc[2], tc[3])
                else
                    if p.mask and not p.masked then p.emblem:AddMaskTexture(p.mask); p.masked = true end
                    p.emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    p.emblem:SetTexture(horde and "Interface\\Icons\\INV_BannerPVP_01" or "Interface\\Icons\\INV_BannerPVP_02")
                    p.token:SetVertexColor(horde and 0.85 or 0.25, horde and 0.2 or 0.45, horde and 0.15 or 0.95)
                end
                local size = m.r * 2 + 4
                p.shadow:SetSize(size + 14, size + 14); p.shadow:SetVertexColor(0, 0, 0, 0.5)
                p.token:SetSize(size, size)
                p.shadow:SetPoint("CENTER", cv, "TOPLEFT", m.x + 3, -m.y - 4)
                p.token:SetPoint("CENTER", cv, "TOPLEFT", m.x, -m.y)
                if rider then
                    local step = abs(sin((self.rt or 0) * 9)) * 1.5
                    p.emblem:SetSize(size * 1.05, size * 1.05)
                    p.emblem:SetPoint("CENTER", cv, "TOPLEFT", m.x, -m.y + 2 + step)
                else
                    p.emblem:SetSize(size * 0.62, size * 0.62)
                    p.emblem:SetPoint("CENTER", cv, "TOPLEFT", m.x, -m.y)
                end
                if p.mask then p.mask:SetSize(size * 0.62, size * 0.62); p.mask:SetPoint("CENTER", cv, "TOPLEFT", m.x, -m.y) end
                p.shadow:Show(); p.token:Show(); p.emblem:Show()
            end
        end
        -- sliders, gates, wisps and every signature hazard (mages, ghouls, drums, whirlwinds, tide pools)
        self:DrawHazards(el)
        if self.flow and not NS.db.settings.reducedMotion then
            for _, f in ipairs(self.flow) do
                local w = 0.5 + 0.5 * sin(f.ph * 1.6 - self.rt * 5)
                f.t:SetAlpha(f.boost and (0.55 + 0.45 * w) or (0.35 + 0.4 * w))
            end
        end
        -- flowing water / lava / slime
        local still = NS.db.settings.reducedMotion
        if self.liquids and not still then
            for _, lq in ipairs(self.liquids) do
                local u = (self.rt * lq.spd + lq.ph) % 1
                local v = (self.rt * lq.spd * 0.6) % 1
                lq.t:SetTexCoord(u, u + 1, v, v + 1)
            end
        end
        -- spinning fans and their wind
        for i, fan in ipairs(h.fans) do
            local f = self.fanTex[i]
            if f and f.blades.SetRotation then f.blades:SetRotation(-self.rt * 14) end
            if not still then
                fan.streakT = (fan.streakT or 0) - el
                if fan.streakT <= 0 then
                    fan.streakT = 0.045
                    self:Streak(fan)
                end
            end
        end
        self:UpdateStreaks(el)
        for _, pt in ipairs(self.portalTex) do
            if pt:IsShown() then pt:SetAlpha(0.6 + 0.4 * sin(self.rt * 5)) end
        end
        self.flag:SetWidth(18 + sin(self.rt * 6) * 3)
    end

    self:UpdateAim(el)
    self:UpdateFigures(el)
    self:UpdateGhosts(el)
    self:UpdateFX(el)
    self:RefreshHUD()
end

function UI:UpdateAim(el)
    local g, cv = self.game, self.canvas
    local a, power
    if self.drag and g.state == "aim" and not self:Paused() then a, power = self:AimVector() end
    if a then
        -- ease the line toward the mouse so it glides instead of jittering pixel to pixel
        if not self.aimA then
            self.aimA, self.aimP = a, power
        else
            local k = 1 - math.exp(-(el or 0.016) * 22)
            local da = (a - self.aimA + math.pi) % (2 * math.pi) - math.pi
            self.aimA = self.aimA + da * k
            self.aimP = self.aimP + (power - self.aimP) * k
        end
        a, power = self.aimA, self.aimP
    else
        self.aimA, self.aimP = nil, nil
    end
    if not a then
        if self.dotsShown then
            for _, d in ipairs(self.dots) do d:Hide() end
            self.dotsShown = false
        end
        self.meter:Hide(); self.pull:Hide()
        return
    end
    local club = self:Club()
    -- the aim line: direction and power, bending with the lie of the green over its first stretch
    -- (the break is read for you; rails, bounces and anything that moves are still yours to judge)
    local len = 40 + power * 170
    local pts = g:Preview(a, power, len)
    -- lay dots along the polyline
    local n, spacing = 0, 9
    local carry = 0
    for i = 1, #pts - 3, 2 do
        local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        local seg = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local d = carry
        while d < seg and n < #self.dots do
            n = n + 1
            local f = seg > 0 and d / seg or 0
            local dot = self.dots[n]
            dot:SetPoint("CENTER", cv, "TOPLEFT", x1 + (x2 - x1) * f, -(y1 + (y2 - y1) * f))
            dot:SetVertexColor(club.aim[1], club.aim[2], club.aim[3], 0.9 - n * 0.008)
            dot:Show()
            d = d + spacing
        end
        carry = d - seg
    end
    for i = n + 1, #self.dots do self.dots[i]:Hide() end
    self.dotsShown = true
    -- pull handle and power meter
    self.pull:SetPoint("CENTER", cv, "TOPLEFT", self.cx, -self.cy)
    self.pull:SetVertexColor(1, 1, 1, 0.35)
    self.pull:Show()
    self.meter:Show()
    self.meter.fill:SetHeight(max(2, 120 * power))
    if power > P.WOBBLE_FROM then
        -- amber -> red as accuracy drops off with power
        local k = (power - P.WOBBLE_FROM) / (1 - P.WOBBLE_FROM)
        self.meter.fill:SetVertexColor(1.0, 0.75 - 0.5 * k, 0.2)
        self.pull:SetVertexColor(1, 0.75 - 0.45 * k, 0.25, 0.4 + 0.3 * k)
    else
        local r = min(1, power * 1.6)
        self.meter.fill:SetVertexColor(0.3 + 0.7 * r, 0.9 - 0.5 * power, 0.3)
    end
end

function UI:UpdateFX(el)
    local cv = self.canvas
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then p.t:Hide() else
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                p.vx, p.vy = p.vx * 0.92, p.vy * 0.92
                local f = p.life / p.max
                local sz = p.size * (0.4 + 0.6 * f)
                p.t:SetSize(sz, sz)
                p.t:SetPoint("CENTER", cv, "TOPLEFT", p.x, -p.y)
                p.t:SetAlpha(p.a * f)
            end
        end
    end
    if self.bannerT > 0 then
        self.bannerT = self.bannerT - el
        local k = self.bannerT / self.bannerMax
        local a = min(1, k * 4, (1 - k) * 10)
        self.banner:SetAlpha(a); self.bannerSub:SetAlpha(a)
        if self.bannerT <= 0 then self.banner:Hide(); self.bannerSub:Hide() end
    end
end

function UI:RefreshHUD(force)
    local g = self.game
    if not self.clock then return end
    local h = g.hole
    local strokes, par, adj = 0, 0, 0
    if g.card then strokes, par, adj = g:Totals() end
    local liveAdj = adj
    if h and g.state ~= "sunk" and g.state ~= "done" then
        liveAdj = adj + (g.strokes - h.par) * P.STROKE_SEC
    end
    local vs = g.course and g.course.kind == "versus"
    local clockStr = (g.state == "done" and g.final) and Putt.FormatTime(g.final) or Putt.FormatTime((vs and V:Playing(g)) and V:Elapsed() or (g.elapsed or 0))
    if clockStr ~= self.lastClock then self.clock:SetText(clockStr); self.lastClock = clockStr end
    local key = table.concat({ g.state, g.index or 0, g.strokes or 0, floor(liveAdj) }, ":")
    if key == self.hudKey and not force then return end
    self.hudKey = key
    if h then
        local kind = vs and "VERSUS" or g.course.kind == "daily" and "DAILY" or (g.course.kind == "route" and (g.course.live and "THIS FLIGHT" or "FLIGHT ROUTE"))
            or (g.course.key == Putt.TOUR and "GRAND TOUR" or "QUICK ROUND")
        self.holeLabel:SetText(("%s  -  HOLE %d / %d"):format(kind, math.min(g.index, #g.course.holes), #g.course.holes))
        self.nameLabel:SetText(h.name)
        self.parLabel:SetText(vs and self:VersusLine() or ("Par %d   Course par %d"):format(h.par, g.course.par))
        self.strokeText:SetText(g.state == "sunk" and (g.card[g.index] and g.card[g.index].strokes or g.strokes) or g.strokes)
        if g.state == "done" then
            self.adjText:SetText("final time")
            self.adjText:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        else
            local c = liveAdj < 0 and COLORS.green or (liveAdj > 0 and COLORS.red or COLORS.dim)
            self.adjText:SetText(("strokes %s"):format(Putt.FormatAdj(liveAdj)))
            self.adjText:SetTextColor(c[1], c[2], c[3])
        end
    else
        self.holeLabel:SetText("GRYPHON GREENS")
        self.nameLabel:SetText("Mini golf time trial")
        self.parLabel:SetText("")
        self.strokeText:SetText("-")
        self.adjText:SetText("")
    end
    local nHoles = (g.course and #g.course.holes) or P.HOLES
    if nHoles ~= self.cardN then
        self.cardN = nHoles
        local wide = nHoles <= 6
        for i, box in ipairs(self.cardBoxes) do
            box:SetSize(wide and 30 or 19, 26)
            box:ClearAllPoints()
            box:SetPoint("LEFT", self.cardBar, "LEFT", (i - 1) * (wide and 34 or 22), 0)
            box.text:SetFont(W.FONT_NUM, wide and 13 or 11, "")
            box:SetShown(i <= nHoles)
        end
    end
    for i, box in ipairs(self.cardBoxes) do
        local c = g.card and g.card[i]
        if c then
            box.text:SetText(c.strokes)
            local d = c.strokes - c.par
            local col = d < 0 and COLORS.green or (d == 0 and { 0.3, 0.33, 0.42 } or { 0.55, 0.25, 0.22 })
            box.bg:SetVertexColor(col[1], col[2], col[3], 1)
        elseif g.index == i and h and g.state ~= "done" then
            box.text:SetText(g.strokes > 0 and g.strokes or "-")
            box.bg:SetVertexColor(COLORS.accent[1] * 0.6, COLORS.accent[2] * 0.6, COLORS.accent[3] * 0.4, 1)
        else
            box.text:SetText("")
            box.bg:SetVertexColor(1, 1, 1, 0.06)
        end
    end
end

---------------------------------------------------------------------------
-- Menus and cards
---------------------------------------------------------------------------
function UI:ShowHelp()
    self.card:Open({
        title = "Gryphon Greens", color = COLORS.green,
        body = table.concat({
            "|cffffcc40Putt|r: click and drag |cffffcc40back|r from anywhere, like a slingshot, and let go. The dotted line shows your aim, and bends the way the green will take the ball. Right-click cancels.",
            "",
            "Past three quarters power the meter turns |cffffb030amber|r then |cffff5040red|r and your aim gets shaky. The ball must reach the cup gently to drop.",
            "",
            "It's a |cffffcc40time trial|r, first putt to last cup. Every stroke under par takes 5s off, every stroke over adds 5s, and a hole-in-one takes off 5s more. Bonuses can take off at most half your time.",
            "",
            "|cffffcc40Read the green|r: the whole green rolls. Light and shadow show its shape, and contour lines crowd together where it is steep. Pull back to putt and beads drift downhill: pale and slow on a gentle lean, amber on a steep one, red where a ball cannot stop.",
            "",
            "Water, lava and slime cost a stroke. A ball that stops against a rail is moved a club-head off it.",
            "",
            "|cff9499b3One daily course a day, the same for everyone. Your best time goes on the leaderboard.|r",
        }, "\n"),
        buttons = { { "Let's play", function() self:ShowMenu() end } },
    })
end

function UI:ShowCoursePicker()
    local function info(k)
        local c = Putt.CourseInfo(k)
        local par = 0
        for _, h in ipairs(c and c.holes or {}) do par = par + ((h.extra and h.extra.par) or h.par or 3) end
        local best = self.db.courseBest and self.db.courseBest[k]
        return c and ("|cffffcc40%s|r  -  %d holes, par %d%s"):format(c.name, #c.holes, par,
            best and ("  -  best |cffffffff" .. Putt.FormatTime(best) .. "|r") or "") or ""
    end
    self.card:Open({
        title = "Quick round", color = COLORS.green, center = true,
        body = table.concat({ info("human"), info("dwarf"), info("gnome"), info("nelf"), info("orc"), info("troll"), info("undead"), info("mulgore"), info("arathi"), info(Putt.TOUR), "",
            "|cff9499b3The Grand Tour plays nine holes drawn from every course. A round in progress is kept between flights.|r" }, "\n"),
        buttons = {
            { "Elwynn", function() self:StartCourse("quick", "human") end },
            { "Dun Morogh", function() self:StartCourse("quick", "dwarf") end },
            { "Tinker Town", function() self:StartCourse("quick", "gnome") end },
            { "Teldrassil", function() self:StartCourse("quick", "nelf") end },
            { "Durotar", function() self:StartCourse("quick", "orc") end },
            { "Echo Isles", function() self:StartCourse("quick", "troll") end },
            { "Tirisfal", function() self:StartCourse("quick", "undead") end },
            { "Mulgore", function() self:StartCourse("quick", "mulgore") end },
            { "Arathi", function() self:StartCourse("quick", "arathi") end },
            { "Grand Tour", function() self:StartCourse("quick", Putt.TOUR) end },
        },
    })
end

-- every route you've flown, playable any time (in a city, at the anvil, wherever)
function UI:ShowFlightLog()
    local list = NS.Route.List(9)
    local lines, buttons = {}, {}
    for i, it in ipairs(list) do
        local spec, e = it.spec, it.e
        lines[#lines + 1] = ("|cffffcc40%d.|r |cffffffff%s|r  -  %d hole%s%s"):format(i, NS.Route.Name(spec), spec.holes, spec.holes == 1 and "" or "s",
            e.best and ("  -  best |cff3be870" .. Putt.FormatTime(e.best) .. "|r") or "  -  |cff9499b3not played|r")
        local label = ("%d. %s"):format(i, spec.to)
        if #label > 15 then label = label:sub(1, 14) .. "." end
        buttons[#buttons + 1] = { label, function() self:StartRoute(spec, false) end }
    end
    local total = 0
    for _ in pairs(NS.Route.Log()) do total = total + 1 end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cff9499b3%d route%s flown. Every flight you take is added here, and its record counts wherever you play it.|r"):format(total, total == 1 and "" or "s")
    buttons[#buttons + 1] = { "Back", function() self:ShowMenu() end, "ghost" }
    if self.menu:IsShown() then self.menu:Hide() end
    self.card:Open({ title = "Flight Log", color = COLORS.green, center = true, body = table.concat(lines, "\n"), buttons = buttons })
end

function UI:ShowMenu()
    local g = self.game
    if self.board:IsShown() then self.board:Hide() end
    if self.locker:IsShown() then self.locker:Hide() end
    local day = Today()
    local d = self.db.daily[day]
    local course = Putt.MakeCourse("daily", DayNum(day))
    local lines = {
        ("|cffffcc40Today's course: %s|r  -  %d holes, par %d"):format(course.name or "Greens", #course.holes, course.par),
    }
    if d and d.best then
        lines[#lines + 1] = ("Your best today: |cffffffff%s|r  (%d tries)"):format(Putt.FormatTime(d.best), d.tries or 1)
    else
        lines[#lines + 1] = "You haven't played today's course yet."
    end
    if self.db.quickBest then lines[#lines + 1] = ("Quick round best: %s"):format(Putt.FormatTime(self.db.quickBest)) end
    local inProgress = g.state == "aim" or g.state == "roll" or g.state == "sunk"
    local flying = NS.Route.Flying()
    local routeSpec = flying or NS.Route.Last()
    local routeBtn
    if routeSpec then
        local e = NS.Route.Log()[routeSpec.id]
        table.insert(lines, 1, ("|cff3be870%s:|r |cffffffff%s|r  -  %d hole%s%s"):format(flying and "Your flight" or "Last flight",
            NS.Route.Name(routeSpec), routeSpec.holes, routeSpec.holes == 1 and "" or "s",
            (e and e.best) and ("  -  your record " .. Putt.FormatTime(e.best)) or (flying and "  -  no record yet" or "")))
        if flying then routeBtn = { "Play this flight", function() self:PlayFlight() end } end
    end
    local logBtn = next(NS.Route.Log()) and { "Flight log", function() self:ShowFlightLog() end } or nil
    local buttons = {
        { (d and d.best) and "Replay daily" or "Play daily", function() self:StartCourse("daily") end },
        { "Quick round", function() self:ShowCoursePicker() end },
        { V.match and V.match.state ~= "done" and "Versus (open)" or "Versus", function() self:ShowVersus() end },
    }
    local rl = NS.Social:RankLine("putt", day)
    if rl then lines[#lines + 1] = "Today: " .. rl end
    lines[#lines + 1] = ("Ball: |cffffcc40%s|r     Putter: |cffffcc40%s|r"):format(self:Ball().name, self:Club().name)
    if routeBtn then table.insert(buttons, 1, routeBtn) end
    if logBtn then buttons[#buttons + 1] = logBtn end
    if not (routeBtn and logBtn) then buttons[#buttons + 1] = { "Ball & putter", function() self:ShowLocker() end } end
    buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end }
    buttons[#buttons + 1] = { "How to play", function() self:ShowHelp() end, "ghost" }
    if inProgress then
        table.insert(buttons, 1, { "Resume", nil })
        buttons[2][3], buttons[3][3] = "ghost", nil
    end
    -- the menu holds six buttons: the extras give way first
    for _, drop in ipairs({ "How to play", "Ball & putter", "Flight log" }) do
        if #buttons > 6 then
            for i = #buttons, 1, -1 do if buttons[i][1] == drop then table.remove(buttons, i) break end end
        end
    end
    if self.card:IsShown() then self.card:Hide() end
    local options = NS.CommonOptions()
    self.menu:Open({
        title = "Gryphon Greens", sub = "Mini golf across Azeroth, against the clock", icon = "Interface\\Icons\\INV_Misc_Orb_01",
        color = COLORS.green, lines = lines, buttons = buttons, options = options,
    })
end

---------------------------------------------------------------------------
-- Versus: lobby, live rivals, results
---------------------------------------------------------------------------
local VS_STATUS = {
    ready = "|cff3be870ready|r", invited = "|cff9499b3invited...|r", declined = "|cffd9534fdeclined|r",
    busy = "|cffd9534fbusy in another game|r", version = "|cffd9534fneeds to update Flight Buddy|r",
    private = "|cffd9534fonly takes challenges from friends, guild or group|r", noanswer = "|cff9499b3no answer|r",
    gone = "|cffd9534fleft|r",
}
local function Hex(c) return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) end

function UI:StartVersus(m)
    local course = V.BuildCourse(m.key, m.seed, m.len)
    if not course then return end
    course.vsId = m.id
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    if self.board:IsShown() then self.board:Hide() end
    if self.locker:IsShown() then self.locker:Hide() end
    self.game:Start(course)
    self:RenderHole()
    W.Sound("IG_QUEST_LIST_OPEN")
end

-- one HUD line: where each rival is
function UI:VersusLine()
    local m = V.match
    if not m then return "" end
    local parts = {}
    local rivals = #m.order - 1
    for _, name in ipairs(m.order) do
        if name ~= m.me then
            local p = m.players[name]
            local col = Hex(p.color)
            local nm = p.short:match("^[^-]+") or p.short
            if #nm > 10 then nm = nm:sub(1, 9) .. "." end
            local st
            if p.final then st = Putt.FormatTime(p.final)
            elseif p.left then st = "left"
            elseif p.away then st = "away"
            elseif rivals == 1 then st = ("hole %d, %d strokes"):format(min(p.hole, m.len), p.total + p.strokes)
            else st = ("H%d %d"):format(min(p.hole, m.len), p.total + p.strokes) end
            parts[#parts + 1] = col .. nm .. "|r " .. st
        end
    end
    return table.concat(parts, rivals > 2 and " " or "   ")
end

function UI:UpdateGhosts(el)
    local pool = self.ghosts
    if not pool then pool = {}; self.ghosts = pool end
    local n = 0
    local g, m, cv = self.game, V.match, self.canvas
    if m and (m.state == "play" or m.state == "done") and g.course and g.course.vsId == m.id and g.hole and g.state ~= "done" then
        self.ghostTrail = (self.ghostTrail or 0) - el
        local trail = self.ghostTrail <= 0 and not NS.db.settings.reducedMotion
        if trail then self.ghostTrail = 0.05 end
        for _, name in ipairs(m.order) do
            local p = m.players[name]
            if name ~= m.me then
                local x, y, sinking, z, rolling = V:Ghost(p, g.index)
                if x then
                    n = n + 1
                    local gh = pool[n]
                    if not gh then
                        gh = { ring = W.Tex(cv, "OVERLAY", "ring", 0), ball = W.Tex(cv, "OVERLAY", "ball", 1), name = W.Text(cv, 10) }
                        gh.name:SetShadowOffset(1, -1)
                        pool[n] = gh
                    end
                    local c = p.color
                    local size = (P.BALL_R * 2 + 2) * (1 + 0.75 * (z or 0))
                    local a = 0.85
                    if sinking then
                        local k = min(1, (GetTime() - p.sunkAt) / 0.6)
                        size, a = size * (1 - 0.7 * k), 0.85 * (1 - k)
                        if not p.sunkFx then p.sunkFx = true; self:Burst(x, y, c, 10, 90); W.SFX("cup") end
                    else
                        p.sunkFx = nil
                    end
                    gh.ball:SetSize(size, size)
                    gh.ball:SetVertexColor(c[1], c[2], c[3], a)
                    gh.ball:SetPoint("CENTER", cv, "TOPLEFT", x, -(y - 16 * (z or 0)))
                    gh.ring:SetSize(size + 6, size + 6)
                    gh.ring:SetVertexColor(c[1], c[2], c[3], a * 0.55)
                    gh.ring:SetPoint("CENTER", gh.ball, "CENTER")
                    gh.name:SetText(p.short:match("^[^-]+") or p.short)
                    gh.name:SetTextColor(c[1], c[2], c[3], a)
                    gh.name:SetPoint("BOTTOM", gh.ball, "TOP", 0, 3)
                    gh.ball:Show(); gh.ring:Show(); gh.name:Show()
                    if rolling and trail then self:Particle(x, y, 0, 0, 0.22, 6, c, 0.3) end
                end
            end
        end
    end
    for i = n + 1, #pool do pool[i].ball:Hide(); pool[i].ring:Hide(); pool[i].name:Hide() end
end

function UI:VersusChanged()
    self.hudKey = nil
    if not self.card:IsShown() then return end
    local kind = self.card.opts and self.card.opts.vs
    if kind == "lobby" then
        local m = V.match
        if m and m.state == "lobby" then self:ShowVersus()
        elseif not m then self.card:Close(); self:ShowMenu() end
    elseif kind == "results" then
        self:ShowVersusResults()
    end
end

function UI:ShowVersus()
    local m = V.match
    if m and m.state == "done" then return self:ShowVersusResults() end
    if m and m.state ~= "lobby" then
        if self.menu:IsShown() then self.menu:Hide() end
        self.card:Open({ title = "Match in progress", color = COLORS.gold, center = true,
            body = "Your match is still running. The clock doesn't stop while you're away from the green.",
            buttons = {
                { "Back to the match", nil },
                { "Leave match", function() V:Leave(); self:ShowMenu() end, "ghost" },
            } })
        return
    end
    if not m then m = V:Host() end
    if self.menu:IsShown() then self.menu:Hide() end
    local host = m.host == m.me
    local c = NS.PuttCourses[m.key]
    local lines = {
        "Race up to three other players on the same course at the same time. You watch their balls roll while you play.",
        "|cff9499b3Fastest time wins: the clock, plus 5 seconds a stroke over par, minus 5 under.|r",
        "",
        ("|cffffcc40%s|r   %d holes"):format(c and c.name or m.key, m.len),
        "",
    }
    local ready = 0
    for _, name in ipairs(m.order) do
        local p = m.players[name]
        if p.status == "ready" then ready = ready + 1 end
        lines[#lines + 1] = ("%s%s|r   %s%s"):format(Hex(p.color), p.short, VS_STATUS[p.status] or p.status, name == m.host and "  |cff9499b3(host)|r" or "")
    end
    local buttons
    if host then
        if #m.order == 1 then lines[#lines + 1] = "|cff9499b3Invite someone to get started. They need Flight Buddy too.|r" end
        local keep = { keepOpen = true }
        local function B(label, fn, style) return { label, fn, style, keepOpen = true } end
        buttons = {
            { ready >= 2 and "Start match" or "Waiting...", function()
                if not V:StartMatch() then self:ShowVersus(); self:Hint("Nobody has accepted yet") end
            end, ready >= 2 and "primary" or "ghost" },
        }
        if IsInGroup and IsInGroup() then buttons[#buttons + 1] = B("Invite group", function() if not V:InviteParty() then self:Hint("Nobody in your group to invite") end end) end
        if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") and not (UnitIsUnit and UnitIsUnit("target", "player")) then
            buttons[#buttons + 1] = B("Invite target", function() V:InviteTarget() end)
        end
        buttons[#buttons + 1] = B("Invite by name", function() V:AskName() end)
        buttons[#buttons + 1] = B("Next course", function()
            local keys = V:CourseKeys()
            local at = 1
            for i, k in ipairs(keys) do if k == m.key then at = i end end
            V:Host(keys[at % #keys + 1], m.len)
            self:VersusReinvite()
        end)
        buttons[#buttons + 1] = B(m.len == 3 and "Play 6 holes" or "Play 3 holes", function()
            V:Host(m.key, m.len == 3 and 6 or 3)
            self:VersusReinvite()
        end)
        buttons[#buttons + 1] = { "Cancel", function() V:Leave(); self:ShowMenu() end, "ghost" }
    else
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("Waiting for %s to start the match..."):format(m.players[m.host].short)
        buttons = { { "Leave", function() V:Leave(); self:ShowMenu() end, "ghost" } }
    end
    self.card:Open({ title = "Versus", color = COLORS.gold, body = table.concat(lines, "\n"), buttons = buttons, vs = "lobby" })
end

-- the course or length changed: anyone already invited needs the new details
function UI:VersusReinvite()
    local m = V.match
    if not (m and m.state == "lobby" and m.host == m.me) then return end
    for _, name in ipairs(m.order) do
        if name ~= m.me then
            local p = m.players[name]
            p.status = "invited"
            V:Invite(p.name)
        end
    end
    self:ShowVersus()
end

function UI:ShowVersusResults()
    local m = V.match
    if not m then return self:ShowMenu() end
    local list = V:Standings()
    local over = m.state == "done"
    local me = m.players[m.me]
    local lines, place = {}, 0
    for i, p in ipairs(list) do
        local st
        if p.final then st = ("|cffffffff%s|r   %d strokes"):format(Putt.FormatTime(p.final), p.total)
        elseif p.left then st = "|cffd9534fleft the match|r"
        elseif p.away then st = "|cff9499b3not responding|r"
        else st = ("|cff9499b3on hole %d of %d|r"):format(min(p.hole, m.len), m.len) end
        if p == me then place = i end
        lines[#lines + 1] = ("%s  %s%s|r%s   %s"):format(p.final and (i .. ".") or "-", Hex(p.color), p.short, p == me and " (you)" or "", st)
    end
    local title, color = "Round complete", COLORS.green
    if over then
        local finished = 0
        for _, p in ipairs(list) do if p.final then finished = finished + 1 end end
        if finished < 2 then title, color = "Match over", COLORS.gold
        elseif place == 1 then title, color = "Victory!", COLORS.gold
        else title, color = (place == 2 and "Second place" or (place == 3 and "Third place" or "Fourth place")), COLORS.dim end
        if place == 1 and finished >= 2 and not m.cheered then m.cheered = true; W.SFX("fever_bin"); self.db.vsWins = (self.db.vsWins or 0) + 1 end
        if not m.counted then m.counted = true; self.db.vsPlayed = (self.db.vsPlayed or 0) + 1 end
    else
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff9499b3Waiting for the others to finish...|r"
    end
    local buttons = {}
    if m.host == m.me and over then
        buttons[#buttons + 1] = { "Rematch", function()
            local names = {}
            for _, name in ipairs(m.order) do if name ~= m.me and not m.players[name].left then names[#names + 1] = m.players[name].name end end
            V:Leave(true)
            V:Host(m.key, m.len)
            for _, nm in ipairs(names) do V:Invite(nm) end
            self:ShowVersus()
        end }
    end
    buttons[#buttons + 1] = { "Menu", function() if V.match and V.match.state == "done" then V:Leave(true) end self:ShowMenu() end, #buttons > 0 and "ghost" or nil }
    self.card:Open({ title = title, color = color, center = true, body = table.concat(lines, "\n"), buttons = buttons, vs = "results" })
end

function UI:ShowResults(final, elapsed, adj, strokes, par, newBest, landedIt)
    local g = self.game
    local daily = g.course.kind == "daily"
    local diff = strokes - par
    if g.course.kind == "route" then
        local c = g.course
        local spec = c.route
        local lines = {
            ("|cffffffff%s|r%s"):format(Putt.FormatTime(final), newBest and "   |cff3be870ROUTE RECORD|r" or ""),
            "",
            ("Clock %s   Strokes %s%s"):format(Putt.FormatTime(elapsed), Putt.FormatAdj(adj), landedIt and "   |cff3be870Landed it  -5s|r" or ""),
            ("%d strokes  (%s%d vs par %d)"):format(strokes, diff > 0 and "+" or "", diff, par),
        }
        if final > elapsed + adj - (landedIt and 5 or 0) + 0.05 then lines[#lines + 1] = "|cff9499b3Bonuses can take off at most half your time.|r" end
        if c.live and not landedIt then lines[#lines + 1] = "|cff9499b3Finish before you land for 5 seconds off.|r"
        elseif not c.live then lines[#lines + 1] = "|cff9499b3Play it in the air and finish before you land for 5 seconds off.|r" end
        local rk, n = NS.Social:Rank(NS.Route.Board(spec), "all", "realm")
        if rk and n > 1 then lines[#lines + 1] = ("This route: |cffffcc40#%d|r of %d"):format(rk, n) end
        self.card:Open({
            title = NS.Route.Name(spec), color = COLORS.green, center = true,
            body = table.concat(lines, "\n"),
            buttons = {
                { "Route board", function() self:ShowBoard(nil, spec) end },
                { "Menu", function() self:ShowMenu() end },
            },
        })
        return
    end
    local lines = {
        ("|cffffffff%s|r%s"):format(Putt.FormatTime(final), newBest and "   |cff3be870NEW BEST|r" or ""),
        "",
        ("Clock %s   Strokes %s"):format(Putt.FormatTime(elapsed), Putt.FormatAdj(adj)),
        ("%d strokes  (%s%d vs par %d)"):format(strokes, diff > 0 and "+" or "", diff, par),
    }
    if final > elapsed + adj + 0.05 then lines[#lines + 1] = "|cff9499b3Bonuses can take off at most half your time.|r" end
    if daily then
        local board = NS.Social:Board("putt", Today())
        for i, e in ipairs(board) do
            if e.me then lines[#lines + 1] = ("Leaderboard rank |cffffcc40#%d|r of %d"):format(i, #board) end
        end
    end
    self.card:Open({
        title = daily and "Daily course complete" or "Round complete", color = COLORS.green, center = true,
        body = table.concat(lines, "\n"),
        buttons = daily and {
            { "Leaderboard", function() self:ShowBoard() end },
            { "Menu", function() self:ShowMenu() end },
        } or {
            { "Play again", function() self:StartCourse("quick", g.course and g.course.key) end },
            { "Leaderboard", function() self:ShowBoard(g.course and g.course.key) end },
            { "Menu", function() self:ShowMenu() end, "ghost" },
        },
    })
end

function UI:ShowBoard(courseKey, routeSpec)
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide() end
    local day = Today()
    local d = self.db.daily[day]
    routeSpec = routeSpec or NS.Route.Flying() or NS.Route.Last()
    local views = {
        { label = "Daily course", game = "putt", day = day, periods = false, period = "day",
          title = "Greens daily leaderboard",
          sub = ("Today's course  -  lower time wins  -  %s"):format(day:sub(1, 4) .. "-" .. day:sub(5, 6) .. "-" .. day:sub(7, 8)),
          empty = "No times yet today. Play the daily to set the pace!",
          onPost = d and d.best and function()
              local diff = (d.strokes or 0) - (d.par or 0)
              SendChatMessage(("[Flight Buddy] Gryphon Greens daily: %s (%d strokes, %+d)"):format(Putt.FormatTime(d.best), d.strokes or 0, diff), "GUILD")
          end or nil },
    }
    local start = 1
    if routeSpec then
        local spec = routeSpec
        table.insert(views, 1, { label = "This route", game = NS.Route.Board(spec), periods = true, period = "all",
            title = NS.Route.Name(spec), sub = ("%d holes for this flight  -  lower time wins"):format(spec.holes),
            empty = "Nobody has a time on this route yet. Fly it and set the record!",
            onPost = function()
                local mine = NS.Social:Mine(NS.Route.Board(spec), "all")
                if mine then SendChatMessage(("[Flight Buddy] %s -> %s in %s. Beat that on your next flight."):format(spec.from, spec.to, Putt.FormatTime(mine.s)), "GUILD") end
            end })
        if NS.Route.Flying() or (self.game.course and self.game.course.kind == "route") then start = 1 else start = 2 end
    end
    for _, k in ipairs(Putt.COURSE_ORDER) do
        local c = Putt.CourseInfo(k)
        if c then
            local key = k
            views[#views + 1] = { label = c.name, game = "pq_" .. key, periods = true, period = "all",
                title = c.name, sub = "Quick round best times  -  lower wins",
                empty = "No rounds on this course yet. Play a quick round here!",
                onPost = function()
                    local mine = NS.Social:Mine("pq_" .. key, "all")
                    if mine then SendChatMessage(("[Flight Buddy] Gryphon Greens, %s: %s"):format(c.name, Putt.FormatTime(mine.s)), "GUILD") end
                end }
            if key == courseKey then start = #views end
        end
    end
    views[#views + 1] = { label = "Grand Tour", game = "pq_" .. Putt.TOUR, periods = true, period = "all",
        title = "Grand Tour", sub = "Nine holes from every course  -  lower wins", empty = "Nobody has finished a Grand Tour yet." }
    if courseKey == Putt.TOUR then start = #views end
    self.board:Open({
        views = views, view = start,
        fmt = function(e)
            local s, p = (e.d or ""):match("^(%d+):(%d+)$")
            local det = s and (("%d strokes (%+d)"):format(tonumber(s), tonumber(s) - tonumber(p))) or ""
            return Putt.FormatTime(e.s), det
        end,
        onClose = function() if self.game.state == "idle" or self.game.state == "done" then self:ShowMenu() end end,
    })
end

---------------------------------------------------------------------------
-- Locker
---------------------------------------------------------------------------
function UI:BuildLocker(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", self.canvas, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", self.canvas, "BOTTOMRIGHT")
    p:SetFrameLevel(self.canvas:GetFrameLevel() + 30)
    p:EnableMouse(true)
    W.Panel(p, "wood")
    p:Hide()
    self.locker = p
    local title = W.Text(p, 18)
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Locker")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    p.items = {}
    local function Section(text, y)
        local s = W.Text(p, 11, W.FONT_NUM)
        s:SetPoint("TOPLEFT", 22, y)
        s:SetText(text)
        s:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])
    end
    local function Item(list, kind, i, y)
        local it = list[i]
        local b = CreateFrame("Button", nil, p)
        b:SetSize(436, 30)
        b:SetPoint("TOPLEFT", 22, y)
        b.bg = W.Solid(b, "BACKGROUND", 1, 1, 1, 0.03)
        b.bg:SetAllPoints()
        b.hl = W.Solid(b, "HIGHLIGHT", 1, 1, 1, 0.06)
        b.hl:SetAllPoints()
        if kind == "ball" then
            b.icon = W.Tex(b, "ARTWORK", "ball")
            b.icon:SetVertexColor(it.color[1], it.color[2], it.color[3])
        else
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetTexture(it.icon)
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 6, 0)
        b.name = W.Text(b, 13); b.name:SetPoint("LEFT", 34, 0)
        b.req = W.Text(b, 11, W.FONT_NUM); b.req:SetPoint("RIGHT", -10, 0)
        b:SetScript("OnClick", function()
            if Unlocked(self.db, it) then
                self.db.locker[kind] = it.id
                W.Sound("IG_CHARACTER_INFO_TAB")
                self:FillLocker()
                self:RenderHole()
            end
        end)
        b.item, b.kind = it, kind
        p.items[#p.items + 1] = b
    end
    Section("GOLF BALLS", -54)
    for i = 1, #UI.BALLS do Item(UI.BALLS, "ball", i, -72 - (i - 1) * 32) end
    local y = -72 - #UI.BALLS * 32 - 14
    Section("PUTTERS", y)
    for i = 1, #UI.CLUBS do Item(UI.CLUBS, "club", i, y - 18 - (i - 1) * 32) end
    local back = W.Button(p, 120, 30, "Back", "primary")
    back:SetPoint("BOTTOMRIGHT", -22, 18)
    back:SetScript("OnClick", function()
        p:Hide()
        if self.lockerFromMenu then self.lockerFromMenu = nil; self:ShowMenu() end
    end)
end

function UI:FillLocker()
    for _, b in ipairs(self.locker.items) do
        local it = b.item
        local open = Unlocked(self.db, it)
        local equipped = self.db.locker[b.kind] == it.id
        b.name:SetText(equipped and ("|cffffcc40" .. it.name .. "|r") or it.name)
        b.name:SetAlpha(open and 1 or 0.45)
        b.icon:SetDesaturated(not open)
        b.icon:SetAlpha(open and 1 or 0.5)
        if equipped then b.req:SetText("|cff3be870Equipped|r")
        elseif open then b.req:SetText("Click to equip")
        else
            local have = self.db[it.req[1]] or 0
            b.req:SetText(("%s  (%d/%d)"):format(it.req[3], min(have, it.req[2]), it.req[2]))
        end
        b.bg:SetColorTexture(1, 1, 1, equipped and 0.08 or 0.03)
    end
end

function UI:ShowLocker()
    if self.card:IsShown() then self.card:Hide() end
    if self.menu:IsShown() then self.menu:Hide(); self.lockerFromMenu = true end
    if self.board:IsShown() then self.board:Hide() end
    self:FillLocker()
    self.locker:Show()
end
