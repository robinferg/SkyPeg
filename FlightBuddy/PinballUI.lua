-- Flight Buddy :: PinballUI.lua
-- High Tinker Pinball: the brand-new table in Tinker Town, Ironforge. You and your gnome friends
-- crowd round it; they cheer, heckle and take credit for everything. Draws Pinball.lua's table.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Pin = NS.Pinball
local C = Pin.C

local UI = {}
NS.PinballUI = UI

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local MEDIA = "pin\\"
local FONT_SHOUT = "Fonts\\SKURRI.TTF"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local DMD = { 1.0, 0.55, 0.12 }
-- lights on the painted playfield (x, y, radius, colour): glass lamps and crystals in the art
local LAMPS = {
    lane_G = { 160, 75, 9, 0.35, 0.85, 1 },
    lane_N = { 200, 75, 9, 0.35, 0.85, 1 },
    lane_O = { 240, 75, 9, 0.35, 0.85, 1 },
    lane_M = { 280, 75, 9, 0.35, 0.85, 1 },
    lane_E = { 320, 75, 9, 0.35, 0.85, 1 },
    lock_1 = { 179, 296, 12, 0.3, 0.8, 1 },
    lock_2 = { 301, 296, 12, 0.3, 0.8, 1 },
    lock_3 = { 240, 243, 10, 1, 0.75, 0.3 },
    saucer = { 131, 320, 14, 1, 0.75, 0.3 },
    kickback = { 61, 466, 14, 0.4, 0.8, 1 },
    shoot_again = { 398, 466, 14, 0.4, 0.8, 1 },
}

---------------------------------------------------------------------------
-- Your friends at the table
---------------------------------------------------------------------------
local PALS
PALS = {
    mekkatorque = { name = "High Tinker Mekkatorque", icon = "pal_mekkatorque", color = { 1, 0.82, 0.3 } },
    overspark   = { name = "Tinkmaster Overspark",    icon = "pal_overspark",   color = { 0.6, 0.85, 1 } },
    fizzle      = { name = "Fizzle Brassbolt",        icon = "pal_fizzle",      color = { 1, 0.6, 0.85 } },
    thermaplugg = { name = "Mekgineer Thermaplugg",   icon = "pal_thermaplugg", color = { 0.6, 1, 0.45 } },
}

-- who's at the table with you: your pick does most of the talking (cosmetic; scoring is the same for all)
UI.CREW = {
    { key = "mekkatorque", line = "Big speeches, bigger cheers" },
    { key = "overspark",   line = "Dry wit, precise calibration" },
    { key = "fizzle",      line = "Enthusiasm at 112 percent" },
    { key = "thermaplugg", line = "Heckles every single shot", jackpots = 5, lockText = "Hit 5 jackpots to make him show up" },
}
-- ball finishes (cosmetic)
UI.BALLS = {
    { key = "steel",   name = "Polished Steel",  tint = { 1, 1, 1 } },
    { key = "arcane",  name = "Arcane Bearing",  tint = { 0.75, 0.6, 1 },  games = 5 },
    { key = "molten",  name = "Molten Slug",     tint = { 1, 0.55, 0.3 },  best = 250000 },
    { key = "frost",   name = "Frost Marble",    tint = { 0.6, 0.85, 1 },  best = 500000 },
    { key = "fel",     name = "Fel Cog",         tint = { 0.55, 1, 0.45 }, jackpots = 10 },
    { key = "gold",    name = "Gilded Gnomish",  tint = { 1, 0.85, 0.35 }, best = 1000000 },
}
UI.BALL = {}
for _, b in ipairs(UI.BALLS) do UI.BALL[b.key] = b end

local QUIPS = {
    quest = {
        { "mekkatorque", "A new job for my favourite engineer! The clock's ticking!" },
        { "overspark", "Work order received. Deadline: unreasonable. As usual." },
        { "fizzle", "Ooh, a quest! I love quests! What's a quest?" },
    },
    questDone = {
        { "mekkatorque", "Job done! That's going straight on your engineering record!" },
        { "overspark", "Completed ahead of schedule. Suspicious. Well done." },
        { "fizzle", "We did it! I mostly cheered, but I cheered REALLY well!" },
    },
    questFail = {
        { "thermaplugg", "Ha! Missed your deadline! Gnomeregan stays MINE!" },
        { "overspark", "Out of time. I'll file it under 'next time'." },
    },
    rust = {
        { "thermaplugg", "My gremlins rusted your flippers! Good luck flipping NOW!" },
        { "thermaplugg", "A little leper-gnome sabotage, free of charge!" },
    },
    rustFixed = {
        { "overspark", "One dose of oil from the hangar. Flippers good as new." },
        { "mekkatorque", "Repaired! Those gremlins are no match for a real engineer!" },
    },
    loop = {
        { "fizzle", "Wheee! Round and round! Do it again!" },
        { "overspark", "A perfect loop. The arch is load-bearing, try not to dent it." },
    },
    wizard = { { "mekkatorque", "HIGH TINKER MODE! Every job done! Everything pays triple!" } },
    extra = { { "mekkatorque", "Extra ball! Even Gnomeregan's finest need a second try sometimes." } },
    start = {
        { "mekkatorque", "Welcome to the grand opening! Please don't lick the Arcane Reactor." },
        { "overspark", "I calibrated the flippers myself. With a hammer. Precisely." },
        { "fizzle", "Ooh, a new table! It only caught fire twice during testing!" },
    },
    launch = {
        { "overspark", "Spring tension at 112 percent. Nothing could possibly go wrong." },
        { "fizzle", "Launch sequence go! Was that a countdown? I forgot to count." },
        { "mekkatorque", "Fire! For Gnomeregan! And for points!" },
    },
    bumper = {
        { "fizzle", "Sparks! Good sparks or bad sparks? ...Good sparks!" },
        { "overspark", "That cog is load-bearing. Please keep hitting it." },
        { "mekkatorque", "Listen to those cogs sing! Mostly in tune!" },
    },
    sling = {
        { "overspark", "Boing. That's the technical term." },
        { "fizzle", "The slingshots run on rubber bands and optimism!" },
    },
    lane = {
        { "fizzle", "Ooh, a letter! Collect the whole word, it's very educational." },
    },
    gnome = {
        { "mekkatorque", "G-N-O-M-E! You spelled us! Bonus multiplier up!" },
        { "fizzle", "You spelled GNOME! Nobody ever spells gnome right! It's the silent G!" },
        { "overspark", "Multiplier increased. I'll multiply something too. Probably a mistake." },
    },
    target = {
        { "overspark", "That target took me three weeks and an eyebrow." },
        { "fizzle", "Knock 'em all down and the parts bin opens!" },
    },
    tinker = {
        { "mekkatorque", "T-I-N-K-E-R! To the parts bin! Let's see what falls out!" },
        { "overspark", "Parts bin, open! Stand back, it's mostly sprockets and regret." },
    },
    sheep = { { "fizzle", "Baa-BOOM! Somebody tell the Explosive Sheep it did great." } },
    chicken = { { "overspark", "The Battle Chicken is guarding the cogs! Triple points! Mind the feathers." } },
    cap = { { "mekkatorque", "Mind Control Cap engaged. The ball WANTS to come back now." } },
    ray = { { "fizzle", "The Death Ray fired! Two hundred thousand! Only minor scorching!" } },
    rayBackfire = { { "overspark", "The Death Ray backfired. My eyebrows have left the building." } },
    enlarge = { { "fizzle", "World Enlarger! The flippers are huge! Everything is slightly huge!" } },
    remote = { { "overspark", "Universal Remote: lock lit! It also turned on someone's oven in Stormwind." } },
    boots = { { "mekkatorque", "Goblin Rocket Boots. They exploded. Of course they exploded." } },
    lock = {
        { "fizzle", "Gyrocopter parked! Don't feed it after midnight." },
        { "overspark", "Another gyro in the hangar. Mind the rotors!" },
    },
    multiball = {
        { "mekkatorque", "GYROCOPTER AIR SHOW! Three balls! Hide the tools!" },
        { "fizzle", "An air show! This is the best day of my whole life!" },
    },
    jackpot = {
        { "mekkatorque", "JACKPOT! Put it in the Gnomeregan reclamation fund!" },
        { "overspark", "Jackpot! I knew the hangar's coin slot worked!" },
    },
    overload = {
        { "overspark", "The Arcane Reactor is overloading! Super jackpot at the hangar, before it melts!" },
        { "fizzle", "The reactor's glowing! Is it supposed to glow? Shoot the hangar, quick!" },
    },
    super = {
        { "mekkatorque", "SUPER JACKPOT! And the reactor didn't explode! ...Yet!" },
    },
    spin = {
        { "fizzle", "Wheee! The spinner's heating up the reactor!" },
    },
    kickback = {
        { "overspark", "Kickback! Patent pending and only slightly illegal." },
    },
    saved = {
        { "fizzle", "Ball saved! I put a safety net down there. Well, a fishing net." },
        { "overspark", "Ball saved. The warranty covers it. This once." },
    },
    drain = {
        { "thermaplugg", "Ha! Another ball for my collection in Gnomeregan!" },
        { "thermaplugg", "Your engineering is as flimsy as your little goggles!" },
        { "thermaplugg", "Down the drain! Just like your precious city! Wait, that one was me." },
        { "fizzle", "Drained! Don't worry, the next ball is extra bouncy. Probably." },
    },
    over = {
        { "mekkatorque", "Splendid game! I'll have it engraved. On a very small plaque." },
        { "overspark", "Not bad! For a dwarf. Oh, you're a gnome? Then it was average." },
        { "fizzle", "Again! Again! I'll hold your goggles!" },
    },
    nudge = {
        { "overspark", "I gave the table a little nudge. Don't tell the High Tinker." },
    },
}

function UI:Init(db)
    self.db = db -- FlightBuddyDB.pin
    db.best = db.best or 0
    db.games = db.games or 0
    db.top = db.top or {}
    db.stats = db.stats or {}
    db.crew = db.crew or "mekkatorque"
    db.ball = db.ball or "steel"
end

function UI:Unlocked(it)
    local db = self.db
    if it.games and (db.games or 0) < it.games then return false end
    if it.best and (db.best or 0) < it.best then return false end
    if it.jackpots and ((db.stats and db.stats.jackpots) or 0) < it.jackpots then return false end
    return true
end

local function LockText(self, it)
    if it.lockText then return it.lockText end
    local db = self.db
    if it.games then return ("Play %d games  (%d)"):format(it.games, db.games or 0) end
    if it.best then return ("Score %s in one game"):format(W.Commas(it.best)) end
    if it.jackpots then return ("Hit %d jackpots  (%d)"):format(it.jackpots, (db.stats and db.stats.jackpots) or 0) end
end

function UI:BallFinish()
    local b = UI.BALL[self.db.ball]
    if not b or not self:Unlocked(b) then b = UI.BALLS[1] end
    return b
end

function UI:CrewKey()
    for _, c in ipairs(UI.CREW) do
        if c.key == self.db.crew and self:Unlocked(c) then return c.key end
    end
    return "mekkatorque"
end

function UI:ApplyBall()
    local t = self:BallFinish().tint
    for _, b in ipairs(self.ballTex or {}) do b:SetVertexColor(t[1], t[2], t[3]) end
end

function UI:ShowCrew()
    if self.menu:IsShown() then self.menu:Hide() end
    local items = {}
    for _, c in ipairs(UI.CREW) do
        local pal = PALS[c.key]
        items[#items + 1] = { key = c.key, name = pal.name, line = c.line, desc = c.line,
            icon = W.MEDIA .. MEDIA .. pal.icon, locked = not self:Unlocked(c), lockText = LockText(self, c) }
    end
    self.picker:Open({
        title = "Who's at the table?", color = { 1, 0.7, 0.25 },
        sub = "Your pick does most of the talking. Scoring is the same whoever you choose.",
        items = items, selected = self:CrewKey(),
        onPick = function(key) self.db.crew = key; self:Say("start", true) end,
        onClose = function() self:ShowMenu() end,
    })
end

function UI:ShowBalls()
    if self.menu:IsShown() then self.menu:Hide() end
    local items = {}
    for _, b in ipairs(UI.BALLS) do
        items[#items + 1] = { key = b.key, name = b.name, line = "Ball finish", tint = b.tint,
            icon = W.MEDIA .. "ball2", locked = not self:Unlocked(b), lockText = LockText(self, b) }
    end
    self.picker:Open({
        title = "Pick a ball", color = { 1, 0.7, 0.25 },
        sub = "Purely for looks. Unlock more by playing.",
        items = items, selected = self:BallFinish().key,
        onPick = function(key) self.db.ball = key; self:ApplyBall() end,
        onClose = function() self:ShowMenu() end,
    })
end

local function Tex(parent, file, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(W.MEDIA .. MEDIA .. file) end
    return t
end

local function Commas(n) return W.Commas(floor(n)) end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetAllPoints(parent)
    f:Hide()

    -- the dot-matrix display over the table
    local dmd = CreateFrame("Frame", nil, f)
    dmd:SetPoint("TOPLEFT", 20, -36); dmd:SetPoint("TOPRIGHT", -20, -36); dmd:SetHeight(70)
    local dbg = W.Solid(dmd, "BACKGROUND", 0.05, 0.025, 0.01, 0.95)
    dbg:SetAllPoints()
    W.Border(dmd, 0.12)
    self.score = W.Text(dmd, 26, FONT_SHOUT, "OUTLINE")
    self.score:SetPoint("TOPLEFT", 10, -6)
    self.score:SetTextColor(DMD[1], DMD[2], DMD[3])
    self.ballText = W.Text(dmd, 11, W.FONT_NUM)
    self.ballText:SetPoint("BOTTOMLEFT", 10, 8)
    self.ballText:SetTextColor(DMD[1] * 0.85, DMD[2] * 0.85, DMD[3] * 0.85)
    self.pal = dmd:CreateTexture(nil, "ARTWORK")
    self.pal:SetSize(50, 50)
    self.pal:SetPoint("LEFT", dmd, "LEFT", 196, 0)
    self.palName = W.Text(dmd, 11, W.FONT)
    self.palName:SetPoint("TOPLEFT", self.pal, "TOPRIGHT", 8, 2)
    self.palLine = W.Text(dmd, 11, W.FONT)
    self.palLine:SetPoint("TOPLEFT", self.palName, "BOTTOMLEFT", 0, -3)
    self.palLine:SetWidth(186)
    self.palLine:SetJustifyH("LEFT")
    if self.palLine.SetSpacing then self.palLine:SetSpacing(2) end
    self.palLine:SetTextColor(1, 0.94, 0.82)

    -- the table
    local area = CreateFrame("Frame", nil, f)
    area:SetSize(C.W, C.H)
    area:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110)
    area:SetClipsChildren(true)
    self.area = area
    local bg = Tex(area, "pin_table", "BACKGROUND", -8)
    bg:SetAllPoints()
    bg:SetTexCoord(0, 960 / 1024, 0, 1120 / 2048)
    local T = Pin.BuildTable()
    self.T = T
    -- playfield lettering in WoW's own fonts (gold Morpheus, like the game's titles)
    local function Label(x, y, text, size, r, g, b, font)
        local fs = W.Text(area, size, font or FONT_TITLE, "OUTLINE", "ARTWORK")
        fs:SetPoint("CENTER", area, "TOPLEFT", x, -y)
        fs:SetText(text)
        fs:SetTextColor(r, g, b)
        fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1)
        return fs
    end
    Label(150, 542, "High Tinker", 15, 1, 0.84, 0.3)
    Label(318, 542, "Pinball", 15, 1, 0.84, 0.3)
    -- lights
    local function Glow(x, y, size, r, g, b)
        local t = W.Tex(area, "ARTWORK", "glow", 2)
        t:SetBlendMode("ADD")
        t:SetSize(size, size)
        t:SetPoint("CENTER", area, "TOPLEFT", x, -y)
        t:SetVertexColor(r, g, b)
        t:SetAlpha(0)
        return t
    end
    -- light inserts painted into the playfield; each one can be lit
    self.lamps = {}
    for name, l in pairs(LAMPS) do
        local x, y, r, cr, cg, cb = l[1], l[2], l[3], l[4], l[5], l[6]
        local lp = {}
        if name:match("^lane_") then
            lp.face = W.Tex(area, "ARTWORK", "circle", 1)
            lp.face:SetSize(r * 2 - 1, r * 2 - 1)
            lp.face:SetPoint("CENTER", area, "TOPLEFT", x, -y)
            lp.face:SetVertexColor(min(1, cr + 0.25), min(1, cg + 0.25), min(1, cb + 0.25))
            lp.face:SetBlendMode("ADD")
        end
        lp.glow = Glow(x, y, r * (name:match("^arrow") and 3.4 or 3.2), cr, cg, cb)
        lp.on = 0
        self.lamps[name] = lp
    end
    -- bumpers
    self.bumpers = {}
    for i, bu in ipairs(T.bumpers) do
        local s = {}
        s.glow = Glow(bu.x, bu.y, 90, 1, 0.75, 0.3)
        s.lit = 0
        self.bumpers[i] = s
    end
    self.slingLit = { 0, 0 }
    self.slingGlow = {}
    for i, sl in ipairs(T.slings) do
        self.slingGlow[i] = Glow((sl.x1 + sl.x2) / 2, (sl.y1 + sl.y2) / 2, 70, 1, 0.3, 0.2)
    end
    -- drop targets
    self.targets = {}
    for i, t in ipairs(T.targets) do
        local s = {}
        -- the panel's lamps: a hit target's lamp burns bright
        s.glow = Glow(t.lx, t.ly, 46, 1, 0.85, 0.4)
        s.letter = W.Text(area, 10, FONT_TITLE, "OUTLINE", "OVERLAY")
        s.letter:SetPoint("CENTER", area, "TOPLEFT", t.lx, -t.ly)
        s.letter:SetText(t.letter)
        self.targets[i] = s
    end
    -- spinner plate
    self.spinPlate = W.Solid(area, "ARTWORK", 0.72, 0.5, 0.95, 0.9, 3)
    self.spinPlate:SetSize(T.spinner.x2 - T.spinner.x1 - 4, 4)
    self.spinPlate:SetPoint("CENTER", area, "TOPLEFT", (T.spinner.x1 + T.spinner.x2) / 2, -T.spinner.y)
    self.spinAngle, self.spinSpeed = 0, 0
    -- flippers
    self.flipTex = {
        L = Tex(area, "pin_flipper", "ARTWORK", 4),
        R = Tex(area, "pin_flipper_r", "ARTWORK", 4),
    }
    -- plunger spring
    self.spring = Tex(area, "pin_spring", "ARTWORK", 2)
    self.spring:SetWidth(18)
    -- balls
    self.ballTex = {}
    for i = 1, 4 do
        local b = W.Tex(area, "OVERLAY", "ball2", 2)
        b:SetSize(C.BALL_R * 2 + 2, C.BALL_R * 2 + 2)
        b:Hide()
        self.ballTex[i] = b
    end
    -- particles and floating text
    self.parts = {}
    for i = 1, 60 do
        local t = W.Tex(area, "OVERLAY", "glow", 3)
        t:SetBlendMode("ADD")
        t:Hide()
        self.parts[i] = { t = t, life = 0 }
    end
    self.partIdx = 0
    self.floats = {}
    for i = 1, 8 do
        local fs = W.Text(area, 16, FONT_SHOUT, "THICKOUTLINE")
        fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(2, -2)
        fs:Hide()
        self.floats[i] = { fs = fs, life = 0 }
    end
    self.floatIdx = 0
    -- the big shout and the gizmo popup
    self.shout = W.Text(area, 30, FONT_SHOUT, "THICKOUTLINE")
    self.shout:SetPoint("CENTER", area, "TOPLEFT", 239, -400)
    self.shout:SetShadowColor(0, 0, 0, 1); self.shout:SetShadowOffset(2, -2)
    self.shoutT = 0
    local gz = CreateFrame("Frame", nil, area)
    gz:SetSize(300, 64)
    gz:SetPoint("CENTER", area, "TOPLEFT", 239, -200)
    gz:SetFrameLevel(area:GetFrameLevel() + 8)
    local gzb = W.Solid(gz, "BACKGROUND", 0.06, 0.04, 0.02, 0.92)
    gzb:SetAllPoints()
    W.Border(gz, 0.12)
    gz.icon = gz:CreateTexture(nil, "ARTWORK")
    gz.icon:SetSize(48, 48)
    gz.icon:SetPoint("LEFT", 8, 0)
    gz.name = W.Text(gz, 15, FONT_TITLE, "OUTLINE")
    gz.name:SetPoint("TOPLEFT", gz.icon, "TOPRIGHT", 10, -2)
    gz.name:SetTextColor(1, 0.82, 0.35)
    gz.desc = W.Text(gz, 11, W.FONT)
    gz.desc:SetPoint("TOPLEFT", gz.name, "BOTTOMLEFT", 0, -4)
    gz.desc:SetWidth(220); gz.desc:SetJustifyH("LEFT")
    gz:Hide()
    self.gizmo = gz
    self.flash = W.Solid(area, "OVERLAY", 1, 1, 1, 0, 7)
    self.flash:SetAllPoints()

    -- mouse: left button = left flipper, right button = right flipper, click the lane = plunger
    area:EnableMouse(true)
    area:SetScript("OnMouseDown", function(_, button)
        if self:Paused() then return end
        local x = self:CursorX()
        if x and x > C.LANE_WALL - 2 and self.game.state == "plunge" then self:Plunger(true); self.mousePlunge = true; return end
        if button == "LeftButton" then self:Flip("L", true) elseif button == "RightButton" then self:Flip("R", true) end
    end)
    area:SetScript("OnMouseUp", function(_, button)
        if self.mousePlunge then self.mousePlunge = false; self:Plunger(false); return end
        if button == "LeftButton" then self:Flip("L", false) elseif button == "RightButton" then self:Flip("R", false) end
    end)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 20, 10); bar:SetPoint("BOTTOMRIGHT", -20, 10); bar:SetHeight(30)
    bar:SetFrameLevel(f:GetFrameLevel() + 4)
    local start = W.Button(bar, 96, 26, "New game")
    start:SetPoint("LEFT", 0, 0)
    start:SetScript("OnClick", function() self:StartGame() end)
    self.startButton = start
    local help = W.Button(bar, 60, 26, "Help", "ghost")
    help:SetPoint("RIGHT", 0, 0)
    help:SetScript("OnClick", function() self:ShowHelp() end)
    local scores = W.Button(bar, 70, 26, "Scores", "ghost")
    scores:SetPoint("RIGHT", help, "LEFT", -6, 0)
    scores:SetScript("OnClick", function() self:ShowBoard() end)
    local menu = W.Button(bar, 60, 26, "Menu", "ghost")
    menu:SetPoint("RIGHT", scores, "LEFT", -6, 0)
    menu:SetScript("OnClick", function() self:ShowMenu() end)
    self.menuButton = menu
    self.keys = W.Text(bar, 10, W.FONT)
    self.keys:SetPoint("LEFT", start, "RIGHT", 8, 0)
    self.keys:SetPoint("RIGHT", menu, "LEFT", -8, 0)
    self.keys:SetJustifyH("CENTER")
    self.keys:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.keys:SetText("Flip |cffffcc40Shift|r or mouse  -  Plunge |cffffcc40Space|r")

    self.card = W.Card(f, area)
    self.menu = NS.NewMenuPanel(f, area)
    self.board = NS.NewBoardPanel(f, area)
    self.picker = NS.NewPickerPanel(f, area)
    self:ApplyBall()
    self.game = Pin.New(setmetatable({ owner = self }, { __index = function(_, k) return UI["On_" .. k] end }))
    self.palT = 0
    f:SetScript("OnUpdate", function(_, el) W.Guard("Pinball", self.OnUpdate, self, el) end)
    self:Say("start")
    self:Refresh()
end

function UI:CursorX()
    if not GetCursorPosition then return nil end
    local x = GetCursorPosition()
    local s = self.area:GetEffectiveScale()
    local left = self.area:GetLeft()
    if not left or not s or s == 0 then return nil end
    return x / s - left
end

function UI:Paused()
    return (NS.Shell and NS.Shell:IsModal()) or self.card:IsShown() or self.menu:IsShown() or self.board:IsShown()
        or (self.picker and self.picker:IsShown())
end

function UI:IsBusy()
    local s = self.game and self.game.state
    return s == "play" or s == "plunge" or s == "drained"
end

function UI:OnShow()
    if not self.db.seenHelp then
        self.db.seenHelp = true
        self:ShowHelp()
    elseif self.game.state == "idle" or self.game.state == "over" then
        self:ShowMenu()
    end
    self:Refresh()
end

function UI:OnHide()
    -- the table just pauses: flippers drop, the game waits for you
    if self.game then
        self.game:Flipper("L", false); self.game:Flipper("R", false)
        if self.game.pulling then self.game:Plunger(false) end
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local LEFT_KEYS = { LSHIFT = true, Z = true, LEFT = true, A = true, LCTRL = true }
local RIGHT_KEYS = { RSHIFT = true, SLASH = true, RIGHT = true, D = true, RCTRL = true, M = true }
local PLUNGE_KEYS = { SPACE = true, DOWN = true, S = true }

function UI:OnKey(key)
    if self:Paused() then return false end
    local g = self.game
    if key == "ENTER" and (g.state == "idle" or g.state == "over") then self:StartGame(); return true end
    if LEFT_KEYS[key] then self:Flip("L", true); return true end
    if RIGHT_KEYS[key] then self:Flip("R", true); return true end
    if PLUNGE_KEYS[key] then
        if g.state == "idle" or g.state == "over" then self:StartGame() else self:Plunger(true) end
        return true
    end
    return false
end

function UI:OnKeyUp(key)
    if LEFT_KEYS[key] then self:Flip("L", false) end
    if RIGHT_KEYS[key] then self:Flip("R", false) end
    if PLUNGE_KEYS[key] then self:Plunger(false) end
end

function UI:Flip(side, down)
    local g = self.game
    if g.state ~= "play" and g.state ~= "plunge" then return end
    if down and not g.flips[side].held then W.SFX("putt", 0.02) end
    g:Flipper(side, down)
end

function UI:Plunger(down)
    local g = self.game
    if g.state ~= "plunge" and g.state ~= "play" then return end
    g:Plunger(down)
end

function UI:StartGame()
    self.card:Hide()
    if self.menu then self.menu:Hide(); self.board:Hide(); self.picker:Hide() end
    self:ApplyBall()
    self.game:NewGame(floor((time() % 100000) * 13 + ((GetTime and GetTime() or 0) * 100) % 997) + 1)
    self:Refresh()
end

---------------------------------------------------------------------------
-- Talking
---------------------------------------------------------------------------
function UI:Say(kind, force)
    local list = QUIPS[kind]
    if not list then return end
    if not force and (self.palT or 0) > 2.2 and kind ~= "over" and kind ~= "multiball" and kind ~= "super" then return end
    -- your table crew pick gets most of the lines
    local q
    local crew = self.db and self:CrewKey()
    if crew then
        local mine = {}
        for _, it in ipairs(list) do if it[1] == crew then mine[#mine + 1] = it end end
        if #mine > 0 and math.random() < 0.75 then q = mine[math.random(#mine)] end
    end
    q = q or list[math.random(#list)]
    local p = PALS[q[1]]
    self.pal:SetTexture(W.MEDIA .. MEDIA .. p.icon)
    self.palName:SetText(p.name)
    self.palName:SetTextColor(p.color[1], p.color[2], p.color[3])
    self.palLine:SetText(q[2])
    self.palT = 4.5
end

function UI:Shout(text, c, dur)
    c = c or { 1, 0.8, 0.3 }
    self.shout:SetText(text)
    self.shout:SetTextColor(c[1], c[2], c[3])
    self.shoutT, self.shoutMax = dur or 1.4, dur or 1.4
    self.shout:Show()
end

function UI:Float(text, x, y, c, size)
    self.floatIdx = self.floatIdx % #self.floats + 1
    local f = self.floats[self.floatIdx]
    f.fs:SetFont(FONT_SHOUT, size or 16, "THICKOUTLINE")
    f.fs:SetText(text)
    f.fs:SetTextColor(c[1], c[2], c[3])
    f.x, f.y, f.life, f.max = max(40, min(400, x)), y, 1.0, 1.0
    f.fs:Show()
end

function UI:Particle(x, y, vx, vy, life, size, c)
    self.partIdx = self.partIdx % #self.parts + 1
    local p = self.parts[self.partIdx]
    p.x, p.y, p.vx, p.vy, p.life, p.max, p.size = x, y, vx, vy, life, life, size
    p.t:SetVertexColor(c[1], c[2], c[3])
    p.t:Show()
end

function UI:Burst(x, y, c, n, sp)
    if NS.db.settings.reducedMotion then n = floor(n / 3) end
    for k = 1, n do
        local a = k / n * 2 * pi + math.random() * 0.5
        local s = sp * (0.4 + math.random() * 0.8)
        self:Particle(x, y, cos(a) * s, sin(a) * s, 0.35 + math.random() * 0.3, 6 + math.random() * 6, c)
    end
end

---------------------------------------------------------------------------
-- Engine events (handlers are looked up as UI.On_<event>)
---------------------------------------------------------------------------
local BUMPER_SOUNDS = { "pop1", "pop2", "pop3", "pop4", "pop5", "pop6" }
function UI:On_newGame() self.bumpN = 0; self:Say("start", true); self:Refresh() end
function UI:On_ball(n)
    self:Refresh()
    if n > 1 then self:Shout("Ball " .. n, { 1, 0.8, 0.3 }, 1.2) end
end
function UI:On_launch(k) W.SFX("launch"); if math.random() < 0.5 then self:Say("launch") end end
function UI:On_skillshot() end
function UI:On_flip() end
function UI:On_flipHit() end
function UI:On_points(pts, x, y, why)
    if why == "bumper" or why == "sling" or why == "spin" or why == "lane" then return end
    if pts >= 5000 then self:Float(Commas(pts), x, y - 16, pts >= 100000 and { 1, 0.85, 0.3 } or { 1, 1, 1 }, pts >= 100000 and 22 or 15) end
end
function UI:On_bumper(i)
    local s = self.bumpers[i]
    s.lit = 0.14
    self.bumpN = (self.bumpN or 0) + 1
    W.SFX(BUMPER_SOUNDS[self.bumpN % #BUMPER_SOUNDS + 1])
    local bu = self.T.bumpers[i]
    self:Burst(bu.x, bu.y, self.game:Timer("chicken") and { 1, 0.95, 0.6 } or { 1, 0.7, 0.25 }, 6, 110)
    if self.bumpN % 9 == 0 then self:Say("bumper") end
end
function UI:On_sling(i)
    self.slingLit[i] = 0.12
    W.SFX("knock", 0.05)
    if math.random() < 0.08 then self:Say("sling") end
end
function UI:On_rollover(i, new)
    if new then W.SFX("purple", 0.05); if math.random() < 0.25 then self:Say("lane") end end
end
function UI:On_gnome(mult)
    W.SFX("multiplier")
    self:Shout("G-N-O-M-E!  Bonus x" .. mult, { 1, 0.85, 0.35 })
    self:Say("gnome", true)
    self.flash:SetAlpha(0.25)
end
function UI:On_target(i)
    W.SFX("bucket", 0.05)
    local t = self.T.targets[i]
    self:Burst(t.x1, (t.y1 + t.y2) / 2, { 1, 0.85, 0.4 }, 8, 90)
    if math.random() < 0.2 then self:Say("target") end
end
function UI:On_targetsReset() W.SFX("pop8", 0.1) end
function UI:On_gizmo(key, backfire)
    local gz = Pin.GIZMO[key]
    local p = self.gizmo
    p.icon:SetTexture(W.MEDIA .. MEDIA .. "giz_" .. key)
    p.name:SetText(gz.name)
    p.desc:SetText(backfire and "It backfired. Eyebrow insurance pays +5,000." or gz.desc)
    p.t = 3.2
    p:Show()
    W.SFX(key == "sheep" and "rb_rumble" or (key == "ray" and not backfire and "rb_zap" or "power"))
    if key == "sheep" or (key == "ray" and backfire) then self.shakeT = 0.35 end
    self:Say("tinker", true)
    self.pendingQuip = backfire and "rayBackfire" or key
    self.pendingQuipT = 1.6
    self.flash:SetAlpha(0.3)
end
function UI:On_spin(n)
    self.spinSpeed = min(40, self.spinSpeed + n * 9)
    W.SFX("pop2", 0.06)
    if n >= 4 and math.random() < 0.3 then self:Say("spin") end
end
function UI:On_saucer() W.SFX("cup"); self:Shout("Hangar visit!", { 0.9, 0.9, 1 }, 1) end
function UI:On_kick() W.SFX("knock") end
function UI:On_questStart(name, goal, need, t)
    W.SFX("multiplier")
    self:Shout(name:upper(), { 0.6, 0.9, 1 }, 2)
    self:Float(("%s: %d in %ds"):format(goal, need, t), 239, 360, { 0.8, 0.95, 1 }, 14)
    self:Say("quest", true)
    self:Refresh()
end
function UI:On_questProgress(have, need) W.SFX("pop8", 0.08) end
function UI:On_questTime(s) self:Float("+" .. s .. "s quest time", 131, 300, { 0.6, 1, 0.6 }, 13) end
function UI:On_questDone(name, pts, n)
    W.SFX("win")
    self:Shout("JOB DONE!  " .. Commas(pts), { 1, 0.85, 0.3 }, 2)
    self:Say("questDone", true)
    self.flash:SetAlpha(0.35)
end
function UI:On_questFail(name) W.SFX("coin_lose", 0.3); self:Shout("Out of time", { 0.75, 0.75, 0.75 }, 1.2); self:Say("questFail") end
function UI:On_loop(n)
    W.SFX("tunnel")
    self:Shout(n > 1 and ("LOOP x" .. n .. "!") or "LOOP!", { 0.5, 0.9, 1 }, 1.1)
    if n >= 2 then self:Say("loop") end
end
function UI:On_combo(n) W.SFX("style", 0.3); self:Float("COMBO x" .. n, 239, 250, { 1, 0.65, 1 }, 14 + min(n, 6) * 2) end
function UI:On_overclock() W.SFX("rb_zap"); self:Shout("COGS OVERCLOCKED!", { 1, 0.75, 0.3 }, 1.6); self:Say("bumper", true) end
function UI:On_extraLit() W.SFX("freeball"); self:Shout("Extra ball lit at the hangar!", { 0.6, 1, 0.6 }, 2) end
function UI:On_extraBall() W.SFX("win"); self:Shout("EXTRA BALL!", { 0.6, 1, 0.6 }, 2.2); self:Say("extra", true); self.flash:SetAlpha(0.4) end
function UI:On_wizard() W.SFX("fever"); self:Shout("HIGH TINKER MODE!  x3", { 1, 0.85, 0.3 }, 2.6); self:Say("wizard", true); self.flash:SetAlpha(0.6); self.shakeT = 0.4 end
function UI:On_rust()
    W.SFX("lose", 0.3)
    self:Shout("RUSTY FLIPPERS!  Fix them at the hangar", { 1, 0.45, 0.3 }, 2.4)
    self:Say("rust", true)
    self.shakeT = 0.25
end
function UI:On_rustFixed() W.SFX("freeball"); self:Shout("Flippers fixed!", { 0.6, 1, 0.6 }, 1.4); self:Say("rustFixed", true) end
function UI:On_lock(n)
    W.SFX("freeball")
    self:Shout("Gyrocopter " .. n .. " parked!", { 0.6, 1, 0.6 })
    self:Say("lock", true)
end
function UI:On_multiball()
    W.SFX("fever")
    self:Shout("GYROCOPTER AIR SHOW!", { 1, 0.6, 0.25 }, 2.2)
    self:Say("multiball", true)
    self.flash:SetAlpha(0.45); self.shakeT = 0.3
end
function UI:On_multiballOver() self:Shout("Air show over", { 0.8, 0.8, 0.8 }, 1.2) end
function UI:On_jackpot()
    W.SFX("win")
    self:Shout("JACKPOT!", { 1, 0.85, 0.2 }, 1.6)
    self:Say("jackpot", true)
    self.flash:SetAlpha(0.4)
end
function UI:On_overload()
    W.SFX("rb_zap")
    self:Shout("REACTOR OVERLOAD!", { 0.6, 0.8, 1 }, 1.8)
    self:Say("overload", true)
end
function UI:On_super()
    W.SFX("win")
    self:Shout("SUPER JACKPOT!", { 0.7, 0.9, 1 }, 2.2)
    self:Say("super", true)
    self.flash:SetAlpha(0.6); self.shakeT = 0.4
end
function UI:On_kickback() W.SFX("knock"); self:Shout("Kickback!", { 0.5, 1, 0.5 }, 1); self:Say("kickback", true) end
function UI:On_saved() W.SFX("freeball"); self:Shout("Ball saved!", { 0.5, 0.85, 1 }, 1.2); self:Say("saved", true) end
function UI:On_nudge() W.SFX("knock"); self.shakeT = 0.2; if math.random() < 0.5 then self:Say("nudge") end end
function UI:On_drainExtra() W.SFX("lose", 0.2) end
function UI:On_drain(bonus, mult)
    W.SFX("lose")
    self:Shout(("Bonus %s%s"):format(Commas(bonus), mult > 1 and ("  (x" .. mult .. ")") or ""), { 1, 0.8, 0.35 }, 2)
    self:Say("drain", true)
    self.nextBallT = 2.2
    self:Refresh()
end
function UI:On_over(score)
    local db = self.db
    db.games = db.games + 1
    local newBest = score > db.best
    if newBest then db.best = score end
    table.insert(db.top, { s = score, d = date and date("%Y-%m-%d") or "" })
    table.sort(db.top, function(a, b) return a.s > b.s end)
    while #db.top > 10 do table.remove(db.top) end
    local st = self.game.stats
    for k, v in pairs(st) do db.stats[k] = (db.stats[k] or 0) + v end
    self.nextBallT = nil
    NS.Social:SubmitBest("pin", score, ("%d jackpots"):format(self.game.stats.jackpots or 0))
    self:Say("over", true)
    self:Refresh()
    local gz = {}
    for _, k in ipairs(self.game.gizmosWon) do gz[#gz + 1] = Pin.GIZMO[k].name end
    self.card:Open({
        title = newBest and "New High Tinker record!" or "Game over",
        color = newBest and COLORS.gold or { 1, 0.6, 0.25 }, center = true,
        body = table.concat({
            ("Score  |cffffcc40%s|r"):format(Commas(score)),
            ("Best  %s"):format(Commas(db.best)),
            "",
            ("Cogs %d   Targets %d   Spins %d   Jackpots %d"):format(st.bumpers, st.targets, st.spins, st.jackpots),
            #gz > 0 and ("Gizmos: " .. table.concat(gz, ", ")) or "No gizmos this time. The parts bin is judging you.",
        }, "\n"),
        buttons = { { "Play again", function() self:StartGame() end }, { "Leaderboards", function() self:ShowBoard() end, "ghost" }, { "Menu", function() self:ShowMenu() end, "ghost" } },
    })
end

function UI:ShowMenu()
    if self.board:IsShown() then self.board:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    local db = self.db
    local g = self.game
    local inGame = g.state == "play" or g.state == "plunge" or g.state == "drained"
    local lines = { "Tinker Town's newest marvel. Your friends are watching!" }
    if #db.top > 0 then
        local t = {}
        for i = 1, min(3, #db.top) do t[#t + 1] = Commas(db.top[i].s) end
        lines[#lines + 1] = ("Your best games: |cffffcc40%s|r     Games %d"):format(table.concat(t, "   "), db.games)
    else
        lines[#lines + 1] = "No scores yet. Be the first name on the table!"
    end
    local rl = NS.Social:RankLine("pin", "all")
    if rl then lines[#lines + 1] = rl end
    lines[#lines + 1] = ("At the table: |cffffcc40%s|r     Ball: |cffffcc40%s|r"):format(PALS[self:CrewKey()].name, self:BallFinish().name)
    local buttons = {}
    if inGame then buttons[#buttons + 1] = { "Resume", function() self:Refresh() end } end
    buttons[#buttons + 1] = { inGame and "New game" or "Start game", function() self:StartGame() end, inGame and "ghost" or nil }
    buttons[#buttons + 1] = { "Table crew", function() self:ShowCrew() end }
    buttons[#buttons + 1] = { "Ball", function() self:ShowBalls() end }
    buttons[#buttons + 1] = { "Leaderboards", function() self:ShowBoard() end }
    buttons[#buttons + 1] = { "How to play", function() self:ShowHelp() end, "ghost" }
    self.menu:Open({
        title = "High Tinker Pinball", sub = "Tinker Town, Ironforge", icon = "Interface\\Icons\\Trade_Engineering",
        color = { 1, 0.7, 0.25 }, lines = lines, buttons = buttons, options = NS.CommonOptions(),
    })
end

function UI:ShowBoard()
    if self.menu:IsShown() then self.menu:Hide() end
    if self.card:IsShown() then self.card:Hide() end
    self.board:Open({
        game = "pin", periods = true,
        title = "High Tinker Pinball", sub = "High scores",
        empty = "No scores here yet. Plunge a ball!",
        fmt = function(e) return Commas(e.s), e.d or "" end,
        onPost = function()
            if self.db.best > 0 then SendChatMessage(("[Flight Buddy] High Tinker Pinball best: %s"):format(Commas(self.db.best)), "GUILD") end
        end,
        onClose = function() if self.game.state == "idle" or self.game.state == "over" then self:ShowMenu() end end,
    })
end

function UI:ShowHelp()
    self.card:Open({
        title = "High Tinker Pinball", color = { 1, 0.7, 0.25 },
        body = table.concat({
            "|cffffcc40Flippers|r: Left/Right Shift, Z and /, arrow keys, or the left and right mouse buttons.",
            "|cffffcc40Plunger|r: hold Space (or click the launch lane), let go to fire. Longer pull, harder shot.",
            "",
            "Spell |cffffcc40G-N-O-M-E|r in the top lanes for a bonus multiplier (flippers shift the lit lanes).",
            "Knock down |cffffcc40T-I-N-K-E-R|r to open the parts bin: Explosive Sheep, Battle Chicken, Death Ray...",
            "Park 3 |cffffcc40Gyrocopters|r in the hangar for a 3-ball Air Show with jackpots.",
            "Cogs and the spinner heat the |cff8fc8ffArcane Reactor|r. Overload it, then hit the hangar for a super jackpot.",
            "|cff99ddffJobs|r: Mekkatorque hands out timed jobs (cogs, targets, spinner, loops, lamps). The hangar adds 10s.",
            "Finish 3 jobs to light an |cff80ff80extra ball|r at the hangar. Finish all 5 for |cffffcc40High Tinker Mode|r: everything x3.",
            "Loop the arch and chain shots quickly for |cffff99ffcombos|r. Every 25 cog hits overclocks the cogs.",
            "Beware |cffff6040Thermaplugg's gremlins|r: they rust your flippers. Hit the hangar to fix them.",
            "",
            "Three balls. A short ball save at the start of each ball.",
        }, "\n"),
        buttons = { { "Let's play", function() if self.game.state == "idle" or self.game.state == "over" then self:StartGame() else self:Refresh() end end } },
    })
end

function UI:Refresh()
    local g = self.game
    if not g then return end
    self.score:SetText(Commas(g.score or 0))
    if g.state == "idle" then
        self.ballText:SetText(("BEST %s   GAMES %d"):format(Commas(self.db.best), self.db.games))
    else
        local extra = {}
        if g:Timer("chicken") then extra[#extra + 1] = "CHICKEN x3" end
        if g:Timer("enlarge") then extra[#extra + 1] = "BIG FLIPPERS" end
        if g:Timer("overload") then extra[#extra + 1] = "SUPER JACKPOT LIT" end
        if g.multiball then extra[#extra + 1] = "AIR SHOW" end
        if g:Timer("wizard") then extra[#extra + 1] = "|cffffcc40HIGH TINKER x3|r" end
        if g:Timer("rust") then extra[#extra + 1] = "|cffff6040RUSTY FLIPPERS|r" end
        if g:Timer("overclock") then extra[#extra + 1] = "OVERCLOCK" end
        if g.extraLit then extra[#extra + 1] = "|cff80ff80EXTRA BALL LIT|r" end
        if g.quest then
            local q = g.quest
            extra[#extra + 1] = ("|cff99ddffJOB: %s %d/%d  %ds|r"):format(q.name, q.have, q.need, math.ceil(q.t))
        end
        self.ballText:SetText(("BALL %d/%d   x%d   REACTOR %d%%   %s"):format(min(g.ballNum or 1, C.BALLS), C.BALLS, g.mult or 1,
            floor(g.reactor or 0), table.concat(extra, "  ")))
    end
end

---------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------
function UI:OnUpdate(el)
    if el > 0.05 then el = 0.05 end
    self.rt = (self.rt or 0) + el
    local g = self.game
    local rt = self.rt
    if not self:Paused() then
        g:Update(el)
        if self.nextBallT then
            self.nextBallT = self.nextBallT - el
            if self.nextBallT <= 0 then self.nextBallT = nil; g:Continue(); self:Refresh() end
        end
    end
    self.hudT = (self.hudT or 0) - el
    if self.hudT <= 0 then self.hudT = 0.1; self:Refresh() end
    local a, T = self.area, self.T
    -- lights
    local blink = (sin(rt * 9) > 0) and 1 or 0.15
    local L = {}
    for i = 1, 5 do L["lane_" .. ("GNOME"):sub(i, i)] = g.lanes and g.lanes[i] and 1 or 0 end
    for k = 1, 3 do
        L["lock_" .. k] = ((g.locks or 0) >= k and 1) or ((g.lockLit and (g.locks or 0) + 1 == k) and blink) or 0
    end
    local over = g:Timer("overload")
    L.saucer = (over or g:Timer("rust") or g.extraLit) and (0.5 + 0.5 * sin(rt * 10)) or ((g.multiball or g.quest) and blink or 0)
    L.lock_3 = g:Timer("wizard") and blink or (g.quest and 0.6 + 0.4 * sin(rt * 4) or 0)
    L.arrow_lock = (g.lockLit or g.multiball or over) and blink or 0
    L.kickback = g.kickback and 1 or 0
    L.shoot_again = (g:BallSaveOn() and g.state ~= "idle") and (0.4 + 0.6 * abs(sin(rt * 6))) or 0
    local tleft = 0
    for _, t in ipairs(T.targets) do if g.T.targets[_] and g.T.targets[_].up then tleft = tleft + 1 end end
    L.arrow_tinker = (g.state == "play" and tleft <= 2) and blink or 0
    L.arrow_spin = g.state == "play" and ((g.reactor or 0) > 70 and blink or 0.35) or 0
    local rp = over and 10 or floor((g.reactor or 0) / 10 + 0.001)
    for k = 1, 10 do L["reactor_" .. k] = (k <= rp) and (over and blink or 1) or 0 end
    for m = 2, 5 do L["mult_" .. m] = ((g.mult or 1) >= m) and 1 or 0 end
    -- bonus counter: one lamp per 2,500 of end-of-ball bonus banked this ball (all ten = 25K+)
    local bs = g.ballStats
    local bk = bs and floor((bs.bumpers * 250 + bs.targets * 2000 + bs.spins * 100 + bs.rollovers * 1500) / 2500) or 0
    for k = 1, 10 do L["bonus_" .. k] = (k <= bk) and ((bk > 10 and k == 10) and blink or 1) or 0 end
    if g.state == "idle" or g.state == "over" then
        -- attract mode: chase the lamps
        local i = 0
        for name in pairs(L) do i = i + 1; L[name] = (floor(rt * 6 + i * 0.7) % 4 == 0) and 0.8 or 0 end
    end
    for name, lp in pairs(self.lamps) do
        local v = L[name] or 0
        lp.on = lp.on + (v - lp.on) * min(1, el * 18)
        if lp.face then lp.face:SetAlpha(lp.on * 0.85) end
        lp.glow:SetAlpha(lp.on * 0.7)
    end
    -- bumpers flash when hit
    for i, s in ipairs(self.bumpers) do
        s.lit = max(0, s.lit - el)
        s.glow:SetAlpha(s.lit > 0 and 0.9 or (g:Timer("chicken") and 0.25 + 0.15 * sin(rt * 6) or 0))
    end
    for i = 1, 2 do
        self.slingLit[i] = max(0, self.slingLit[i] - el)
        self.slingGlow[i]:SetAlpha(self.slingLit[i] > 0 and 0.8 or 0)
    end
    for i, t in ipairs(T.targets) do
        local up = g.T.targets[i].up
        self.targets[i].glow:SetAlpha(up and 0 or 0.85)
        if up then self.targets[i].letter:SetTextColor(0.35, 0.2, 0.05) else self.targets[i].letter:SetTextColor(1, 1, 0.85) end
    end
    -- spinner
    self.spinSpeed = max(0, self.spinSpeed - el * 25)
    self.spinAngle = self.spinAngle + self.spinSpeed * el
    self.spinPlate:SetHeight(max(1, 6 * abs(cos(self.spinAngle))))
    -- flippers
    for side, tex in pairs(self.flipTex) do
        local f = g.flips[side]
        local px, py, ex, ey, len = g:FlipperGeom(f, side)
        local sc = len / 202
        local w, h = 256 * sc, 64 * sc
        tex:SetSize(w, h)
        local cx, cy = px + ex * 96 * sc, py + ey * 96 * sc
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", a, "TOPLEFT", cx, -cy)
        if tex.SetRotation then tex:SetRotation(side == "L" and -f.a or f.a) end
    end
    -- plunger spring
    local pull = g.pulling and min(1, (g.plunger or 0) / C.PLUNGE_TIME) or 0
    local top = C.PLUNGE_Y + C.BALL_R + pull * 22
    self.spring:SetHeight(max(4, 556 - top))
    self.spring:ClearAllPoints()
    self.spring:SetPoint("TOP", a, "TOPLEFT", C.LANE_X, -top)
    -- balls
    local n = 0
    for _, b in ipairs(g.balls or {}) do
        n = n + 1
        local t = self.ballTex[n]
        if t then
            t:ClearAllPoints()
            local by = b.y
            if b.inLane and b.y >= C.PLUNGE_Y - 1 then by = by + pull * 22 end
            t:SetPoint("CENTER", a, "TOPLEFT", b.x, -by)
            t:Show()
        end
    end
    for i = n + 1, #self.ballTex do self.ballTex[i]:Hide() end
    -- particles, floats, shout, gizmo popup, flash, shake
    for _, p in ipairs(self.parts) do
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then p.t:Hide() else
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local k = p.life / p.max
                p.t:SetSize(p.size * k + 2, p.size * k + 2)
                p.t:SetPoint("CENTER", a, "TOPLEFT", p.x, -p.y)
                p.t:SetAlpha(k)
            end
        end
    end
    for _, fl in ipairs(self.floats) do
        if fl.life > 0 then
            fl.life = fl.life - el
            if fl.life <= 0 then fl.fs:Hide() else
                local k = fl.life / fl.max
                fl.fs:SetPoint("CENTER", a, "TOPLEFT", fl.x, -(fl.y - (1 - k) * 24))
                fl.fs:SetAlpha(min(1, k * 4))
            end
        end
    end
    if self.shoutT > 0 then
        self.shoutT = self.shoutT - el
        self.shout:SetAlpha(min(1, self.shoutT * 4, (self.shoutMax - self.shoutT) * 10 + 0.3))
        if self.shoutT <= 0 then self.shout:Hide() end
    end
    local gz = self.gizmo
    if gz:IsShown() then
        gz.t = gz.t - el
        gz:SetAlpha(min(1, gz.t * 3))
        if gz.t <= 0 then gz:Hide() end
    end
    if self.pendingQuipT then
        self.pendingQuipT = self.pendingQuipT - el
        if self.pendingQuipT <= 0 then self.pendingQuipT = nil; self:Say(self.pendingQuip, true) end
    end
    if self.palT > 0 then self.palT = self.palT - el end
    local fa = self.flash:GetAlpha()
    if fa > 0 then self.flash:SetAlpha(max(0, fa - el * 3)) end
    if (self.shakeT or 0) > 0 and not NS.db.settings.reducedMotion then
        self.shakeT = self.shakeT - el
        local k = max(0, self.shakeT) * 18
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20 + (math.random() - 0.5) * k, -110 + (math.random() - 0.5) * k)
    elseif self.shakeT then
        self.shakeT = nil
        a:ClearAllPoints(); a:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -110)
    end
end
