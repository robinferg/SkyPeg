-- Flight Buddy :: Home.lua
-- The Tavern: a fantasy arcade hall. From the top: the keeper of the games (she tells you what is
-- worth playing), the marquee (one featured game, one PLAY button), your regular's plaque, the cabinet
-- floor (every game is a little arcade cabinet, eight to a page), the chalkboard of today's specials
-- and Tavern Talk, the notes your friends and guild pin to the board.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local floor, ceil, max, min, sin, abs = math.floor, math.ceil, math.max, math.min, math.sin, math.abs
local T = W.TAVERN

local UI = {}
NS.Home = UI

local FW, FH = 520, 674                 -- the room (the cabinet screen below the token row)
local INK = { 0.20, 0.12, 0.05 }        -- writing on parchment and brass
local NAME = "|cff7a2a0c"               -- names written on parchment

-- every game in the tavern: tab key, name, tagline, key art and where to look in it
-- (mx, my = centre of the marquee picture; tx, ty, tz = centre and zoom of the cabinet screen)
UI.GAMES = {
    { key = "peg",  name = "Rune Breaker", tag = "Shatter runes with Warcraft heroes.",
      art = "key_runes", mx = 0.5, my = 0.70, tx = 0.62, ty = 0.72, tz = 0.56, board = "rb" },
    { key = "putt", name = "Gryphon Greens", tag = "Mini golf against the clock.",
      art = "key_greens", mx = 0.5, my = 0.40, tx = 0.60, ty = 0.36, tz = 0.56, board = "putt", daily = true },
    { key = "flap", name = "Featherbeard", tag = "Fly a gryphon through Dun Morogh.",
      art = "key_gryphon", mx = 0.5, my = 0.30, tx = 0.60, ty = 0.36, tz = 0.74, board = "flap" },
    { key = "pin",  name = "High Tinker Pinball", plate = "Pinball", tag = "Gnomish pinball in Tinker Town.",
      art = "key_pinball", mx = 0.5, my = 0.50, tx = 0.50, ty = 0.50, tz = 0.56, board = "pin" },
    { key = "gem",  name = "Jewelcrafter's Bench", plate = "Jewelcrafter", tag = "Cut gems three in a row.",
      art = "key_gems", mx = 0.5, my = 0.50, tx = 0.40, ty = 0.50, tz = 0.56, board = "gemd", daily = true },
    { key = "roll", name = "Death Roll", tag = "Wager gold on the roll of the dice.",
      art = "key_roll", mx = 0.5, my = 0.60, tx = 0.60, ty = 0.60, tz = 0.60 },
}
-- games still being built: they stand on the floor under dust sheets
UI.SOON = { "Deeprun Tram Runner", "Azeroth Trivia", "Goblin Minefield" }
UI.PER_PAGE = 8

local function Today() return NS.Social and NS.Social.Today() or (date and date("%Y%m%d")) or "" end
local function Still() return NS.db and NS.db.settings and NS.db.settings.reducedMotion end

local function GameByKey(key)
    for _, g in ipairs(UI.GAMES) do if g.key == key then return g end end
end

-- Show a w x h window of a 4:3 picture (stored square), centred on (cx, cy), `zoom` of its width wide.
local function ArtWindow(tex, w, h, cx, cy, zoom)
    local uw = zoom or 1
    local vh = uw * (4 / 3) / (w / h)
    if vh > 1 then uw = uw / vh; vh = 1 end
    local u0 = max(0, min(1 - uw, (cx or 0.5) - uw / 2))
    local v0 = max(0, min(1 - vh, (cy or 0.5) - vh / 2))
    tex:SetTexCoord(u0, u0 + uw, v0, v0 + vh)
end

local function Glow(parent, layer, size, r, g, b, sub)
    local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 0)
    t:SetTexture(T .. "candle_glow")
    t:SetBlendMode("ADD")
    t:SetSize(size, size)
    if r then t:SetVertexColor(r, g, b) end
    return t
end

function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -38)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    f:Hide()
    self.t = 0

    -- the back wall of the game hall: timber, a shelf of mugs and trophies, two lanterns, a carpet runner
    local wall = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    wall:SetTexture(T .. "tav_wall")
    wall:SetAllPoints()
    wall:SetTexCoord(0, 1, 0, FH / (FW / 0.75))
    self.lamps = {}
    for i, x in ipairs({ 44, 476 }) do
        local g = Glow(f, "BACKGROUND", 170, 1, 0.82, 0.55, -6)
        g:SetPoint("CENTER", f, "TOPLEFT", x, -74)
        self.lamps[i] = g
    end

    self:BuildMarquee(f)
    self:BuildPlaque(f)
    self:BuildFloor(f)
    self:BuildSpecials(f)
    self:BuildTalk(f)
    self:BuildHost(f)
    f:SetScript("OnUpdate", function(_, el) W.Guard("Tavern", self.OnUpdate, self, el) end)
end

---------------------------------------------------------------------------
-- The keeper of the games: she greets you, tips you off and describes whatever you point at
---------------------------------------------------------------------------
UI.HOST = "Pim Tokenspring"

function UI:BuildHost(f)
    local h = CreateFrame("Button", nil, f)
    h:SetSize(104, 112)
    h:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    h:SetFrameLevel(f:GetFrameLevel() + 16)
    h.tex = h:CreateTexture(nil, "ARTWORK")
    h.tex:SetSize(118, 118)
    h.tex:SetPoint("BOTTOM", h, "BOTTOM", 4, -4)
    h.tex:SetTexture(T .. "tav_host_wave")
    h:SetScript("OnClick", function() W.SFX("pop2"); self.hover = nil; self:NextTip() end)
    h:SetScript("OnEnter", function()
        self:Point(("I'm %s%s|r, keeper of the games. Click me for a tip, or point at anything in the room."):format(NAME, UI.HOST), "wave")
    end)
    h:SetScript("OnLeave", function() self:Unpoint() end)
    self.host = h
    self.pose = "wave"

    -- her words: a parchment scroll that unrolls over the shelf while she talks
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(304, 67)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 110, -20)
    b:SetFrameLevel(f:GetFrameLevel() + 18)
    local bt = b:CreateTexture(nil, "ARTWORK")
    bt:SetTexture(T .. "tav_bubble")
    bt:SetAllPoints()
    b.text = W.Text(b, 11, W.FONT)
    b.text:SetPoint("TOPLEFT", 32, -9)
    b.text:SetPoint("BOTTOMRIGHT", -40, 9)
    b.text:SetJustifyH("LEFT")
    if b.text.SetJustifyV then b.text:SetJustifyV("MIDDLE") end
    if b.text.SetSpacing then b.text:SetSpacing(2) end
    b.text:SetTextColor(INK[1], INK[2], INK[3])
    b.text:SetShadowColor(0, 0, 0, 0)
    b:SetAlpha(0)
    b:Hide()
    self.bubble = b
    self.sayA = 0
end

function UI:Pose(pose)
    pose = pose or "wave"
    if self.pose == pose then return end
    self.pose = pose
    self.host.tex:SetTexture(T .. "tav_host_" .. pose)
    self.hop = 1
end

-- hold: seconds to keep the scroll open (nil = until Hush)
function UI:Say(text, pose, hold)
    self.bubble.text:SetText(text or "")
    self.bubble:Show()
    self.sayHold = hold
    self.sayOn = true
    self:Pose(pose)
end

function UI:Hush(after)
    self.sayHold = after or 0.3
end

-- pointing at something in the room: she describes it for as long as you point
function UI:Point(text, pose)
    self.hover = true
    self:Say(text, pose or "point")
end

function UI:Unpoint()
    self.hover = nil
    self:Hush(0.35)
    self.tipT = max(self.tipT or 0, 8)
end

function UI:Tips()
    local db = NS.db
    local tips = {}
    local open, dailies = {}, 0
    for _, it in ipairs(self:Specials()) do
        if it.kind == "flight" then
            tips[#tips + 1] = { ("This flight has its own %d-hole round of golf. Tee off from the marquee!"):format(it.holes), "point" }
        elseif it.kind == "daily" then
            dailies = dailies + 1
            if not it.done then open[#open + 1] = it.text end
        end
    end
    if #open > 0 then
        tips[#tips + 1] = { ("Still open today: %s%s|r. Same for everyone, so go and beat your guild!"):format(NAME, table.concat(open, ", ")), "point" }
    elseif dailies > 0 then
        tips[#tips + 1] = { "Every special on the chalkboard is ticked off. Nicely played!", "cheer" }
    end
    local run = db.peg and db.peg.run
    if run then tips[#tips + 1] = { ("Your %sRune Breaker|r run is waiting at stage %d."):format(NAME, run.level or 1), "point" } end
    local dr = db.dr
    if dr and ((dr.wins or 0) + (dr.losses or 0)) == 0 then
        tips[#tips + 1] = { ("Fancy a wager? Challenge a friend to a %sDeath Roll|r from anywhere with /deathroll."):format(NAME), "point" }
    end
    tips[#tips + 1] = { "Point at a cabinet and I'll tell you about it. Click it to play.", "wave" }
    tips[#tips + 1] = { "See the dust sheets? New games. No peeking until they're ready!", "wave" }
    return tips
end

function UI:NextTip()
    if self.hover then return end
    local tips = self:Tips()
    self.tipIdx = ((self.tipIdx or 0) % #tips) + 1
    local tip = tips[self.tipIdx]
    self:Say(tip[1], tip[2], 6.5)
    self.tipT = 6.5 + 13
end

function UI:Greet()
    local name = UnitName and UnitName("player") or "friend"
    local title = self:PatronTitle()
    self.tipIdx = 0
    self:Say(("Welcome back, %s%s|r! Pull up a chair, %s."):format(NAME, name, title:lower()), "wave", 3.4)
    self.tipT = 4.6
end

---------------------------------------------------------------------------
-- The marquee: one featured game with one big PLAY button. It shows this flight's round while you
-- fly, then today's open dailies, then the game you played last; point at a cabinet to preview it.
---------------------------------------------------------------------------
local MQ_W, MQ_H = 400, 132
local MQ_X, MQ_Y = 14, 106
local MQ_WIN = { 0.1014, 0.8986, 0.3673, 0.8883 }     -- the cut-out in the sign (left, right, top, bottom)
local MQ_BULBS = { 0.212, 0.356, 0.500, 0.644, 0.788 }

function UI:BuildMarquee(f)
    local m = CreateFrame("Button", nil, f)
    m:SetSize(MQ_W, MQ_H)
    m:SetPoint("TOPLEFT", f, "TOPLEFT", MQ_X, -MQ_Y)
    m:SetFrameLevel(f:GetFrameLevel() + 2)
    self.marquee = m
    local x0, x1, y0, y1 = MQ_WIN[1] * MQ_W, MQ_WIN[2] * MQ_W, MQ_WIN[3] * MQ_H, MQ_WIN[4] * MQ_H
    local sw, sh = x1 - x0, y1 - y0
    local back = W.Solid(m, "BACKGROUND", 0.07, 0.045, 0.03, 1)
    back:SetPoint("TOPLEFT", m, "TOPLEFT", x0 - 3, -(y0 - 3))
    back:SetPoint("BOTTOMRIGHT", m, "TOPLEFT", x1 + 3, -(y1 + 3))

    -- what is on the sign: fades as one when the feature changes
    local body = CreateFrame("Frame", nil, m)
    body:SetPoint("TOPLEFT", m, "TOPLEFT", x0, -y0)
    body:SetSize(sw, sh)
    body:SetFrameLevel(m:GetFrameLevel() + 1)
    m.body = body
    local AW = floor(sw * 0.60)
    m.artW, m.artH = AW + 3, sh + 6
    m.art = body:CreateTexture(nil, "BORDER")
    m.art:SetPoint("TOPRIGHT", body, "TOPRIGHT", 3, 3)
    m.art:SetSize(m.artW, m.artH)
    local fade = body:CreateTexture(nil, "BORDER", nil, 2)
    fade:SetTexture(T .. "tav_fade")
    fade:SetVertexColor(0.07, 0.045, 0.03)
    fade:SetPoint("TOPLEFT", m.art, "TOPLEFT", -1, 0)
    fade:SetPoint("BOTTOMLEFT", m.art, "BOTTOMLEFT", -1, 0)
    fade:SetWidth(96)
    m.kicker = W.Text(body, 9, W.FONT)
    m.kicker:SetPoint("TOPLEFT", 10, -6)
    m.kicker:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])
    m.title = W.Text(body, 17, W.FONT_TITLE)
    m.title:SetPoint("TOPLEFT", 10, -18)
    m.title:SetWidth(sw - 96)
    m.title:SetJustifyH("LEFT")
    if m.title.SetWordWrap then m.title:SetWordWrap(false) end
    m.title:SetTextColor(1, 0.90, 0.62)
    m.sub = W.Text(body, 10, W.FONT)
    m.sub:SetPoint("TOPLEFT", 10, -40)
    m.sub:SetWidth(sw - 92)
    m.sub:SetJustifyH("LEFT")
    if m.sub.SetWordWrap then m.sub:SetWordWrap(false) end
    m.sub:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    -- pips: one per feature, the lit one is showing
    m.pips = {}
    for i = 1, 5 do
        local p = W.Tex(body, "OVERLAY", "circle")
        p:SetSize(6, 6)
        m.pips[i] = p
    end

    -- the hanging sign itself, its row of bulbs and its two lanterns
    local over = CreateFrame("Frame", nil, m)
    over:SetAllPoints()
    over:SetFrameLevel(m:GetFrameLevel() + 2)
    local sign = over:CreateTexture(nil, "ARTWORK")
    sign:SetTexture(T .. "tav_marquee")
    sign:SetAllPoints()
    m.bulbs = {}
    for i, u in ipairs(MQ_BULBS) do
        local g = Glow(over, "OVERLAY", 34, 1, 0.78, 0.62)
        g:SetPoint("CENTER", over, "TOPLEFT", u * MQ_W, -0.19 * MQ_H)
        m.bulbs[i] = g
    end
    m.lanterns = {}
    for i, u in ipairs({ 0.036, 0.964 }) do
        local g = Glow(over, "OVERLAY", 58, 1, 0.80, 0.50)
        g:SetPoint("CENTER", over, "TOPLEFT", u * MQ_W, -0.63 * MQ_H)
        m.lanterns[i] = g
    end
    m.shine = over:CreateTexture(nil, "OVERLAY", nil, 2)
    m.shine:SetTexture(T .. "candle_glow")
    m.shine:SetBlendMode("ADD")
    m.shine:SetVertexColor(1, 0.85, 0.55)
    m.shine:SetPoint("TOPLEFT", over, "TOPLEFT", x0 - 30, -(y0 - 30))
    m.shine:SetPoint("BOTTOMRIGHT", over, "TOPLEFT", x1 + 30, -(y1 + 30))
    m.shine:SetAlpha(0)

    m.play = W.Button(m, 64, 26, "PLAY", "primary")
    m.play:SetPoint("BOTTOMRIGHT", m, "TOPLEFT", x1 - 8, -(y1 - 7))
    m.play:SetFrameLevel(m:GetFrameLevel() + 4)
    m.play:SetScript("OnClick", function() self:PlayFeature() end)
    m.play:HookScript("OnEnter", function() m.over = true end)
    m.play:HookScript("OnLeave", function() m.over = false end)
    m:SetScript("OnClick", function() self:PlayFeature() end)
    m:SetScript("OnEnter", function() m.over = true end)
    m:SetScript("OnLeave", function() m.over = false end)
    m.alpha = 1
    self.mqIdx, self.mqT = 1, 0
end

-- everything worth putting up in lights right now
function UI:Features()
    local out = {}
    local db = NS.db
    for _, it in ipairs(self:Specials()) do
        local g = GameByKey(it.key)
        if it.kind == "flight" then
            out[#out + 1] = { id = "flight", kicker = "THIS FLIGHT", title = it.text, game = g, go = it.go,
                sub = ("A %d-hole round of golf made for this route"):format(it.holes) }
        elseif it.kind == "daily" and not it.done then
            out[#out + 1] = { id = "daily-" .. it.key, kicker = "TODAY'S DAILY  -  " .. g.name:upper(), title = it.title or it.text, game = g, go = it.go, sub = it.blurb }
        end
    end
    local last = db.lastGame and GameByKey(db.lastGame)
    if last then
        out[#out + 1] = { id = "last-" .. last.key, kicker = "JUMP BACK IN", title = last.name, game = last,
            sub = (self:CardStat(last)), go = function() NS.Shell:SelectTab(last.key) end }
    end
    if #out == 0 then
        local g = UI.GAMES[1]
        out[1] = { id = "house", kicker = "HOUSE FAVOURITE", title = g.name, game = g, sub = g.tag, go = function() NS.Shell:SelectTab(g.key) end }
    end
    while #out > 5 do out[#out] = nil end
    return out
end

function UI:GameFeature(g)
    local stat = self:CardStat(g)
    return { id = "game-" .. g.key, kicker = "NOW SHOWING", title = g.name, game = g, sub = stat ~= "" and stat or g.tag,
        go = function() NS.Shell:SelectTab(g.key) end, preview = true }
end

function UI:ApplyFeature(ft)
    local m = self.marquee
    m.shown = ft
    m.kicker:SetText(ft.kicker or "")
    m.title:SetText(ft.title or "")
    m.sub:SetText(ft.sub or "")
    local g = ft.game or UI.GAMES[1]
    m.art:SetTexture(T .. g.art)
    ArtWindow(m.art, m.artW, m.artH, g.mx, g.my, 1)
    local n = ft.preview and 0 or #(self.features or {})
    for i, p in ipairs(m.pips) do
        if n > 1 and i <= n then
            p:ClearAllPoints()
            p:SetPoint("BOTTOMLEFT", m.body, "BOTTOMLEFT", 11 + (i - 1) * 10, 5)
            local on = self.features[i] and self.features[i].id == ft.id
            if on then p:SetVertexColor(1, 0.86, 0.45, 1) else p:SetVertexColor(0.75, 0.62, 0.42, 0.45) end
            p:Show()
        else
            p:Hide()
        end
    end
end

-- what the marquee should be showing this instant
function UI:WantedFeature()
    if self.preview then return self.preview end
    local list = self.features or {}
    if self.mqIdx > #list then self.mqIdx = 1 end
    return list[self.mqIdx]
end

function UI:RefreshFeatures()
    local keep = self.features and self.features[self.mqIdx] and self.features[self.mqIdx].id
    self.features = self:Features()
    if keep then
        for i, ft in ipairs(self.features) do if ft.id == keep then self.mqIdx = i end end
    end
    if self.mqIdx > #self.features then self.mqIdx = 1 end
    -- same feature, fresher numbers: update in place, no fade
    local m = self.marquee
    local want = self:WantedFeature()
    if want and m.shown and m.shown.id == want.id then self:ApplyFeature(want) end
end

function UI:PlayFeature()
    local ft = self.marquee.shown
    if not ft then return end
    W.SFX("pop3")
    ft.go()
end

---------------------------------------------------------------------------
-- The regular's plaque: who you are in this tavern
---------------------------------------------------------------------------
UI.TITLES = {
    { 0, "Wanderer" }, { 10, "Traveller" }, { 30, "Regular" }, { 75, "Barfly" }, { 150, "Local Legend" },
    { 300, "Tavern Champion" }, { 600, "Keeper of the Games" },
}

function UI:GamesPlayed()
    local db = NS.db
    local n = 0
    n = n + ((db.peg and db.peg.cleared) or 0)
    n = n + ((db.putt and db.putt.rounds) or 0) + ((db.putt and db.putt.dailies) or 0)
    n = n + ((db.flap and db.flap.games) or 0)
    n = n + ((db.pin and db.pin.games) or 0)
    n = n + ((db.gem and db.gem.games) or 0)
    n = n + ((db.dr and ((db.dr.wins or 0) + (db.dr.losses or 0))) or 0)
    return n
end

function UI:PatronTitle()
    local n = self:GamesPlayed()
    local title, nextAt, nextTitle = UI.TITLES[1][2], nil, nil
    for i, t in ipairs(UI.TITLES) do
        if n >= t[1] then
            title = t[2]
            nextAt = UI.TITLES[i + 1] and UI.TITLES[i + 1][1]
            nextTitle = UI.TITLES[i + 1] and UI.TITLES[i + 1][2]
        end
    end
    return title, n, nextAt, nextTitle
end

local PL_W, PL_H = 84, 124
local PL_WIN = { 0.2059, 0.79, 0.1671, 0.5635 }
local XP_W, XP_H = 62, 7

function UI:BuildPlaque(f)
    local p = CreateFrame("Button", nil, f)
    p:SetSize(PL_W, PL_H)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", 424, -110)
    p:SetFrameLevel(f:GetFrameLevel() + 2)
    self.plaque = p
    local cx = (PL_WIN[1] + PL_WIN[2]) / 2 * PL_W
    local cy = (PL_WIN[3] + PL_WIN[4]) / 2 * PL_H
    local d = (PL_WIN[2] - PL_WIN[1]) * PL_W
    local back = W.Solid(p, "BACKGROUND", 0.10, 0.07, 0.05, 1)
    back:SetSize(d + 2, d + 2)
    back:SetPoint("CENTER", p, "TOPLEFT", cx, -cy)
    -- your face behind the brass ring
    p.port = p:CreateTexture(nil, "BORDER")
    p.port:SetSize(d + 4, d + 4)
    p.port:SetPoint("CENTER", p, "TOPLEFT", cx, -cy)
    p.port:SetTexture("Interface\\Icons\\INV_Drink_04")
    p.port:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local wood = p:CreateTexture(nil, "ARTWORK")
    wood:SetTexture(T .. "tav_plaque")
    wood:SetAllPoints()
    p.ring = p:CreateTexture(nil, "OVERLAY")
    p.ring:SetTexture(T .. "tav_ring")
    p.ring:SetBlendMode("ADD")
    p.ring:SetSize(d + 12, d + 12)
    p.ring:SetPoint("CENTER", p, "TOPLEFT", cx, -cy)
    p.ring:SetAlpha(0)
    self.patronName = W.Text(p, 11, W.FONT_TITLE)
    self.patronName:SetPoint("TOP", p, "TOP", 0, -71)
    self.patronName:SetWidth(PL_W - 12)
    if self.patronName.SetWordWrap then self.patronName:SetWordWrap(false) end
    self.patronName:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.patronTitle = W.Text(p, 9, W.FONT)
    self.patronTitle:SetPoint("TOP", p, "TOP", 0, -84)
    self.patronTitle:SetWidth(PL_W - 10)
    if self.patronTitle.SetWordWrap then self.patronTitle:SetWordWrap(false) end
    self.patronTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    -- progress to the next title: a brass tube that fills with gold
    local xb = W.Solid(p, "OVERLAY", 0.07, 0.04, 0.02, 1, 1)
    xb:SetSize(XP_W - 6, XP_H - 3)
    xb:SetPoint("CENTER", p, "TOP", 0, -101)
    self.patronBar = W.Solid(p, "OVERLAY", 1.0, 0.80, 0.30, 1, 2)
    self.patronBar:SetHeight(XP_H - 3)
    self.patronBar:SetPoint("LEFT", xb, "LEFT", 0, 0)
    local tube = p:CreateTexture(nil, "OVERLAY", nil, 3)
    tube:SetTexture(T .. "tav_xp")
    tube:SetSize(XP_W, XP_H)
    tube:SetPoint("CENTER", xb, "CENTER", 0, 0)
    p:SetScript("OnEnter", function()
        p.over = true
        local title, n, nextAt, nextTitle = self:PatronTitle()
        local flights = (NS.db.stats and NS.db.stats.flights) or 0
        local line = ("Your plaque: %s games played and %s flights."):format(W.Commas(n), W.Commas(flights))
        if nextAt then
            line = line .. (" %d more to become %s%s|r."):format(nextAt - n, NAME, nextTitle)
        else
            line = line .. " There's no higher title than yours!"
        end
        self:Point(line, nextAt and "point" or "cheer")
    end)
    p:SetScript("OnLeave", function() p.over = false; self:Unpoint() end)
end

function UI:RefreshPatron()
    local name = UnitName and UnitName("player") or "Patron"
    self.patronName:SetText(name)
    local title, n, nextAt = self:PatronTitle()
    self.patronTitle:SetText(title)
    local prevAt = 0
    for _, t in ipairs(UI.TITLES) do if n >= t[1] then prevAt = t[1] end end
    local k = nextAt and (n - prevAt) / max(1, nextAt - prevAt) or 1
    self.patronBar:SetWidth(max(1, (XP_W - 6) * min(1, k)))
end

-- your own face in the plaque's brass ring (asked for once each time the Tavern opens)
function UI:RefreshPortrait()
    if SetPortraitTexture then pcall(function()
        SetPortraitTexture(self.plaque.port, "player")
        self.plaque.port:SetTexCoord(0, 1, 0, 1)
    end) end
end

---------------------------------------------------------------------------
-- The cabinet floor: every game is a dwarven arcade cabinet with its own picture on the screen
---------------------------------------------------------------------------
local CAB_W, CAB_H = 102, 150
local FLOOR_Y = 242
local CAB_WIN = { 0.1635, 0.8355, 0.2462, 0.4917 }

function UI:BuildFloor(f)
    self.slots = {}
    self.page = 1
    local wx0, wx1, wy0, wy1 = CAB_WIN[1] * CAB_W, CAB_WIN[2] * CAB_W, CAB_WIN[3] * CAB_H, CAB_WIN[4] * CAB_H
    for i = 1, UI.PER_PAGE do
        local col, row = (i - 1) % 4, floor((i - 1) / 4)
        local c = CreateFrame("Button", nil, f)
        c:SetSize(CAB_W, CAB_H)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", 33 + col * 117, -(FLOOR_Y + row * 152))
        c:SetFrameLevel(f:GetFrameLevel() + 3 + row * 4)
        c.phase = i * 1.7
        -- the shadow it throws on the floorboards
        local sh = c:CreateTexture(nil, "BACKGROUND")
        sh:SetTexture(T .. "candle_glow")
        sh:SetVertexColor(0, 0, 0, 0.7)
        sh:SetSize(CAB_W + 26, 30)
        sh:SetPoint("CENTER", c, "BOTTOM", 0, 5)
        -- everything that lifts when you point at it
        local b = CreateFrame("Frame", nil, c)
        b:SetSize(CAB_W, CAB_H)
        b:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        b:SetFrameLevel(c:GetFrameLevel() + 1)
        c.body = b
        c.back = W.Solid(b, "BACKGROUND", 0.05, 0.04, 0.05, 1, 1)
        c.back:SetPoint("TOPLEFT", b, "TOPLEFT", wx0 - 2, -(wy0 - 2))
        c.back:SetPoint("BOTTOMRIGHT", b, "TOPLEFT", wx1 + 2, -(wy1 + 2))
        c.art = b:CreateTexture(nil, "BORDER")
        c.art:SetPoint("TOPLEFT", b, "TOPLEFT", wx0 - 2, -(wy0 - 2))
        c.art:SetPoint("BOTTOMRIGHT", b, "TOPLEFT", wx1 + 2, -(wy1 + 2))
        c.artW, c.artH = wx1 - wx0 + 4, wy1 - wy0 + 4
        c.cab = b:CreateTexture(nil, "ARTWORK")
        c.cab:SetTexture(T .. "tav_cabinet")
        c.cab:SetAllPoints()
        c.sheet = b:CreateTexture(nil, "ARTWORK")
        c.sheet:SetTexture(T .. "tav_cabinet_covered")
        c.sheet:SetAllPoints()
        -- screen glow, the lantern on the roof and the rune on the base
        c.screen = Glow(b, "OVERLAY", 10, 1, 0.9, 0.7)
        c.screen:ClearAllPoints()
        c.screen:SetPoint("TOPLEFT", b, "TOPLEFT", wx0 - 16, -(wy0 - 14))
        c.screen:SetPoint("BOTTOMRIGHT", b, "TOPLEFT", wx1 + 16, -(wy1 + 14))
        c.lamp = Glow(b, "OVERLAY", 46, 1, 0.82, 0.5)
        c.lamp:SetPoint("CENTER", b, "TOPLEFT", CAB_W * 0.5, -CAB_H * 0.105)
        c.rune = Glow(b, "OVERLAY", 30, 0.35, 0.75, 1)
        c.rune:SetPoint("CENTER", b, "TOPLEFT", CAB_W * 0.5, -CAB_H * 0.845)
        -- the brass nameplate under the screen
        local plate = CreateFrame("Frame", nil, b)
        plate:SetSize(82, 15)
        plate:SetPoint("CENTER", b, "TOPLEFT", CAB_W * 0.5, -CAB_H * 0.563)
        plate:SetFrameLevel(c:GetFrameLevel() + 2)
        W.Three(plate, T .. "btn_brass", 8, "ARTWORK", 1)
        c.name = W.Text(plate, 10, W.FONT_NUM)
        c.name:SetPoint("CENTER", 0, 0)
        c.name:SetTextColor(INK[1], INK[2], INK[3])
        c.name:SetShadowColor(1, 0.92, 0.65, 0.35)
        c.plate = plate
        -- pinned to the roof: a wax seal (daily open / never played) and your rank ribbon
        local badges = CreateFrame("Frame", nil, b)
        badges:SetAllPoints()
        badges:SetFrameLevel(c:GetFrameLevel() + 2)
        c.seal = badges:CreateTexture(nil, "OVERLAY", nil, 3)
        c.seal:SetSize(30, 30)
        c.seal:SetPoint("CENTER", badges, "TOPLEFT", CAB_W - 13, -30)
        c.ribbon = badges:CreateTexture(nil, "OVERLAY", nil, 3)
        c.ribbon:SetSize(30, 30)
        c.ribbon:SetPoint("CENTER", badges, "TOPLEFT", 13, -32)
        c.lift, c.glow = 0, 0
        c:SetScript("OnEnter", function() self:CabinetEnter(c) end)
        c:SetScript("OnLeave", function() self:CabinetLeave(c) end)
        c:SetScript("OnClick", function() self:CabinetClick(c) end)
        self.slots[i] = c
    end

    -- signpost hands to walk along the floor when there are more than eight games
    self.arrows = {}
    for i, dir in ipairs({ -1, 1 }) do
        local a = CreateFrame("Button", nil, f)
        a:SetSize(30, 16)
        a:SetPoint("CENTER", f, "TOPLEFT", dir < 0 and 17 or FW - 17, -(FLOOR_Y + 152))
        a:SetFrameLevel(f:GetFrameLevel() + 12)
        a.tex = a:CreateTexture(nil, "ARTWORK")
        a.tex:SetTexture(T .. "tav_arrow")
        a.tex:SetAllPoints()
        if dir < 0 then a.tex:SetTexCoord(1, 0, 0, 1) end
        local hl = a:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(T .. "candle_glow")
        hl:SetBlendMode("ADD")
        hl:SetSize(44, 44)
        hl:SetPoint("CENTER")
        a:SetScript("OnClick", function() W.SFX("pop2"); self:TurnPage(dir) end)
        a:SetScript("OnEnter", function() self:Point(dir < 0 and "Back along the floor." or "More cabinets this way!", "point") end)
        a:SetScript("OnLeave", function() self:Unpoint() end)
        self.arrows[i] = a
    end
    self.pageText = W.Text(f, 10, W.FONT)
    self.pageText:SetPoint("CENTER", f, "TOPLEFT", FW - 17, -(FLOOR_Y + 168))
    self.pageText:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
end

function UI:Pages() return max(1, ceil(#UI.GAMES / UI.PER_PAGE)) end

function UI:TurnPage(dir)
    local n = self:Pages()
    self.page = ((self.page - 1 + dir) % n) + 1
    self:FillFloor()
    self:RefreshFloor()
end

-- stand this page's cabinets on the floor; spare places hold the games still under dust sheets
function UI:FillFloor()
    local pages = self:Pages()
    if self.page > pages then self.page = 1 end
    local first = (self.page - 1) * UI.PER_PAGE
    local soon = 0
    for i, c in ipairs(self.slots) do
        local g = UI.GAMES[first + i]
        c.game = g
        c.soon = nil
        if g then
            c.cab:Show(); c.sheet:Hide(); c.art:Show(); c.back:Show(); c.plate:Show()
            c.art:SetTexture(T .. g.art)
            ArtWindow(c.art, c.artW, c.artH, g.tx, g.ty, g.tz)
            c.name:SetText(g.plate or g.name)
        else
            soon = soon + 1
            c.soon = UI.SOON[(first + i - #UI.GAMES - 1) % #UI.SOON + 1]
            c.cab:Hide(); c.sheet:Show(); c.art:Hide(); c.back:Hide(); c.plate:Hide()
            c.seal:Hide(); c.ribbon:Hide()
            c.screen:SetAlpha(0); c.lamp:SetAlpha(0); c.rune:SetAlpha(0)
        end
    end
    for _, a in ipairs(self.arrows) do a:SetShown(pages > 1) end
    self.pageText:SetText(pages > 1 and ("%d/%d"):format(self.page, pages) or "")
end

function UI:Go(key)
    W.SFX("pop3")
    NS.Shell:SelectTab(key)
end

function UI:CabinetEnter(c)
    c.over = true
    if c.game then
        local g = c.game
        local stat = self:CardStat(g)
        local line = ("%s%s|r  %s"):format(NAME, g.name, g.tag)
        if stat and stat ~= "" then line = line .. "\n" .. stat end
        if c.rankText then line = line .. "  -  " .. c.rankText end
        self:Point(line, "point")
        self.preview = self:GameFeature(g)
    else
        self:Point(("Under wraps for now. %s%s|r is still being built in the back room."):format(NAME, c.soon or "Something new"), "wave")
    end
end

function UI:CabinetLeave(c)
    c.over = false
    self.preview = nil
    self:Unpoint()
end

function UI:CabinetClick(c)
    if c.game then
        self:Go(c.game.key)
    else
        W.SFX("pop1")
        self:Point("No peeking! I'll pull the sheet off the moment it's ready.", "cheer")
    end
end

function UI:Played(g)
    local db = NS.db
    if g.key == "peg" then
        local s = db.peg or {}
        return s.run ~= nil or (s.bestLevelScore or 0) > 0 or ((s.stats and s.stats.shots) or 0) > 0
    elseif g.key == "putt" then
        local s = db.putt or {}
        return (s.holes or 0) > 0 or (s.rounds or 0) > 0 or (s.dailies or 0) > 0
    elseif g.key == "flap" then
        return ((db.flap and db.flap.games) or 0) > 0 or ((db.flap and db.flap.best) or 0) > 0
    elseif g.key == "pin" then
        return ((db.pin and db.pin.games) or 0) > 0
    elseif g.key == "gem" then
        return ((db.gem and db.gem.games) or 0) > 0 or ((db.gem and db.gem.level) or 1) > 1
    elseif g.key == "roll" then
        return db.dr ~= nil and ((db.dr.wins or 0) + (db.dr.losses or 0)) > 0
    end
    return true
end

function UI:CardStat(g)
    local db = NS.db
    if g.key == "roll" then
        local s = db.dr
        local played = s and ((s.wins or 0) + (s.losses or 0)) or 0
        if played == 0 then return "Challenge a friend" end
        local net = s.net or 0
        return ("%d won, %d lost  |  %s%s"):format(s.wins or 0, s.losses or 0, net >= 0 and "+" or "-", NS.DeathRoll.Money(abs(net)))
    elseif g.key == "peg" then
        local run = db.peg and db.peg.run
        local best = db.peg and db.peg.bestLevelScore or 0
        return run and ("Stage " .. (run.level or 1) .. "  |  best " .. W.Short(best)) or (best > 0 and ("Best " .. W.Short(best)) or "A hero awaits"), "rb", "all"
    elseif g.key == "putt" then
        local d = db.putt and db.putt.daily and db.putt.daily[Today()]
        return d and d.best and ("Today " .. NS.Putt.FormatTime(d.best)) or "Daily not played", "putt", Today()
    elseif g.key == "flap" then
        local best = db.flap and db.flap.best or 0
        return best > 0 and ("Best flight " .. best) or "Not flown yet", "flap", "all"
    elseif g.key == "pin" then
        local best = db.pin and db.pin.best or 0
        return best > 0 and ("Best " .. W.Short(best)) or "Not played yet", "pin", "all"
    elseif g.key == "gem" then
        local G = NS.GemsUI
        local d = G.db and G:Daily()
        if d and (d.best or 0) > 0 then return "Today " .. W.Short(d.best), "gemd", Today() end
        return ("Work Order #%d"):format((db.gem and db.gem.level) or 1), "gemd", Today()
    end
    return ""
end

local RIBBONS = { "tav_ribbon_gold", "tav_ribbon_silver", "tav_ribbon_bronze" }

function UI:RefreshFloor()
    for _, c in ipairs(self.slots) do
        local g = c.game
        if g then
            local _, board, day = self:CardStat(g)
            -- a ribbon for a top-three place among your guild, friends or realm
            c.rankText = nil
            local ribbon
            if board and NS.Social then
                for _, fl in ipairs({ { "guild", "Guild" }, { "friend", "Friends" }, { "realm", "Realm" } }) do
                    local rk, n = NS.Social:Rank(board, day, fl[1])
                    if rk and n > 1 then
                        c.rankText = ("%s #%d of %d"):format(fl[2], rk, n)
                        ribbon = RIBBONS[rk]
                        break
                    end
                end
            end
            if ribbon then c.ribbon:SetTexture(T .. ribbon); c.ribbon:Show() else c.ribbon:Hide() end
            local mod = NS.Shell.mods and NS.Shell.mods[g.key]
            local pending = g.daily and mod and mod.DailyPending and mod.db and mod:DailyPending()
            if pending then
                c.seal:SetTexture(T .. "tav_seal_daily"); c.seal:Show()
            elseif not self:Played(g) then
                c.seal:SetTexture(T .. "tav_seal_new"); c.seal:Show()
            else
                c.seal:Hide()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Today's specials: the dailies chalked on the board, ticked off as you play them
---------------------------------------------------------------------------
local BOARD_W, BOARD_H = 252, 112
local BOARD_Y = 548

function UI:BuildSpecials(f)
    local b = CreateFrame("Frame", nil, f)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -BOARD_Y)
    b:SetSize(BOARD_W, BOARD_H)
    b:SetFrameLevel(f:GetFrameLevel() + 2)
    local slate = b:CreateTexture(nil, "BACKGROUND")
    slate:SetTexture(T .. "tav_chalkboard")
    slate:SetAllPoints()
    local c = COLORS.chalk
    local t = W.Text(b, 13, W.FONT_TITLE)
    t:SetPoint("TOP", 0, -17)
    t:SetText("Today's Specials")
    t:SetTextColor(c[1], c[2], c[3])
    t:SetShadowColor(0, 0, 0, 0)
    local ul = W.Solid(b, "ARTWORK", c[1], c[2], c[3], 0.3)
    ul:SetSize(118, 1)
    ul:SetPoint("TOP", t, "BOTTOM", 0, -2)
    self.specials = {}
    for i = 1, 4 do
        local r = CreateFrame("Button", nil, b)
        r:SetSize(i == 4 and 160 or 206, 14)     -- the last line stops short of the rag on the ledge
        r:SetPoint("TOPLEFT", 23, -35 - (i - 1) * 14)
        -- a chalk box, ticked when the special is done
        r.box = {}
        for k = 1, 4 do
            local e = W.Solid(r, "ARTWORK", c[1], c[2], c[3], 0.55)
            r.box[k] = e
        end
        r.box[1]:SetSize(8, 1); r.box[1]:SetPoint("TOPLEFT", 0, -3)
        r.box[2]:SetSize(8, 1); r.box[2]:SetPoint("TOPLEFT", 0, -10)
        r.box[3]:SetSize(1, 8); r.box[3]:SetPoint("TOPLEFT", 0, -3)
        r.box[4]:SetSize(1, 8); r.box[4]:SetPoint("TOPLEFT", 7, -3)
        r.tick = r:CreateTexture(nil, "OVERLAY")
        r.tick:SetTexture(T .. "tav_tick")
        r.tick:SetSize(15, 15)
        r.tick:SetPoint("CENTER", r, "LEFT", 5, 2)
        r.text = W.Text(r, 10.5, W.FONT)
        r.text:SetPoint("LEFT", 14, 0)
        r.text:SetPoint("RIGHT", -52, 0)
        r.text:SetJustifyH("LEFT")
        if r.text.SetWordWrap then r.text:SetWordWrap(false) end
        r.text:SetShadowColor(0, 0, 0, 0)
        r.state = W.Text(r, 10.5, W.FONT)
        r.state:SetPoint("RIGHT", 0, 0)
        r.state:SetJustifyH("RIGHT")
        r.state:SetShadowColor(0, 0, 0, 0)
        r.hl = W.Solid(r, "HIGHLIGHT", 1, 1, 1, 0.07)
        r.hl:SetPoint("TOPLEFT", -3, 0)
        r.hl:SetPoint("BOTTOMRIGHT", 3, 0)
        r:SetScript("OnEnter", function() if r.item then self:Point(r.item.say or r.item.text, "point") end end)
        r:SetScript("OnLeave", function() self:Unpoint() end)
        self.specials[i] = r
    end
end

function UI:Specials()
    local db = NS.db
    local out = {}
    -- the flight you're on: its own round of golf, as long as the flight
    local R = NS.Route
    local spec = R and R.Flying()
    if spec then
        local e = R.Log()[spec.id]
        out[#out + 1] = { kind = "flight", key = "putt", holes = spec.holes, text = ("%s > %s"):format(spec.from, spec.to),
            done = e and e.best and NS.Putt.FormatTime(e.best),
            state = ("|cff9fe08a%d hole%s|r"):format(spec.holes, spec.holes == 1 and "" or "s"),
            say = ("The flight you're on: a %d-hole round of golf that lasts as long as the trip."):format(spec.holes),
            go = function() NS.Shell:SelectTab("putt"); NS.PuttUI:PlayFlight() end }
    end
    -- Greens daily course
    local day = Today()
    local pd = db.putt and db.putt.daily and db.putt.daily[day]
    local cname = "Today's course"
    if NS.Putt and NS.Putt.DailyCourseKey then
        local ok, c = pcall(function() return NS.Putt.CourseInfo(NS.Putt.DailyCourseKey(tonumber(day))) end)
        if ok and c and c.name then cname = c.name end
    end
    out[#out + 1] = { kind = "daily", key = "putt", text = cname .. " golf", title = cname, blurb = "Same holes for everyone. Fastest time wins.",
        done = pd and pd.best and NS.Putt.FormatTime(pd.best),
        say = ("Today's %sGryphon Greens|r course is %s. Everyone plays the same holes, fastest time wins."):format(NAME, cname),
        go = function() NS.Shell:SelectTab("putt") end }
    -- Featherbeard daily run
    local fd = NS.FlapUI.Daily and NS.FlapUI.db and NS.FlapUI:Daily()
    local fdone = fd and (fd.best or 0) > 0 and ("best " .. fd.best)
    out[#out + 1] = { kind = "daily", key = "flap", text = "Ironforge Run", blurb = "Same gates for everyone. Furthest flight wins.", done = fdone,
        say = ("The %sIronforge Run|r is today's Featherbeard route. Same gates for everyone, furthest flight wins."):format(NAME),
        go = function() NS.Shell:SelectTab("flap"); if NS.FlapUI.SetMode then NS.FlapUI:SetMode("daily") end end }
    -- Jewelcrafter's Daily Commission
    local G = NS.GemsUI
    local gd = G.db and G:Daily()
    out[#out + 1] = { kind = "daily", key = "gem", text = "Gem commission", title = "Daily Commission", blurb = "Same board for everyone. Highest score wins.",
        done = gd and (gd.best or 0) > 0 and W.Short(gd.best),
        say = ("The %sDaily Commission|r: one gem board a day at the Jewelcrafter's Bench. Highest score wins."):format(NAME),
        go = function() NS.Shell:SelectTab("gem"); if G.Begin then G:Begin("daily", { day = Today() }) end end }
    -- Rune Breaker run in progress (the board has four lines; in the air the flight takes this one)
    local run = db.peg and db.peg.run
    if #out < 4 then
        out[#out + 1] = { kind = "run", key = "peg", text = run and ("Rune Breaker: stage " .. (run.level or 1)) or "Rune Breaker: new run",
            state = "", go = function() NS.Shell:SelectTab("peg") end,
            say = run and ("Your %sRune Breaker|r run is waiting at stage %d."):format(NAME, run.level or 1)
                or ("Start a new %sRune Breaker|r run: pick a hero and clear every orange rune."):format(NAME) }
    end
    return out
end

function UI:RefreshSpecials()
    local list = self:Specials()
    local c = COLORS.chalk
    for i, r in ipairs(self.specials) do
        local it = list[i]
        r.item = it
        if it then
            r.text:SetText(it.text)
            r.text:SetTextColor(c[1], c[2], c[3], it.done and 0.6 or 1)
            r.tick:SetShown(it.done and true or false)
            local state = it.done and ("|cff9fe08a" .. it.done .. "|r") or it.state or "|cffffd27anew!|r"
            r.state:SetText(state)
            -- a line with nothing on the right gets the whole width for its words
            r.text:SetPoint("RIGHT", r, "RIGHT", state == "" and -2 or -52, 0)
            r:SetScript("OnClick", function() W.SFX("pop2"); it.go() end)
            r:Show()
        else
            r:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Tavern Talk: the latest results from your friends and guild, pinned to the notice board
---------------------------------------------------------------------------
local BOARD_NAMES = { rb = "Rune Breaker", putt = "the Greens daily", flap = "Featherbeard", flapd = "the Ironforge Run",
    pin = "Pinball", gem = "Gem Rush", gemd = "the Daily Commission", gemw = "Work Orders" }

function UI:BuildTalk(f)
    local t = CreateFrame("Button", nil, f)
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 262, -BOARD_Y)
    t:SetSize(BOARD_W, BOARD_H)
    t:SetFrameLevel(f:GetFrameLevel() + 2)
    local cork = t:CreateTexture(nil, "BACKGROUND")
    cork:SetTexture(T .. "tav_noticeboard")
    cork:SetAllPoints()
    t:SetScript("OnEnter", function()
        self:Point(("%sTavern Talk|r: the latest scores from your friends and guild get pinned here. Click to read on."):format(NAME), "point")
    end)
    t:SetScript("OnLeave", function() self:Unpoint() end)
    t:SetScript("OnClick", function() W.SFX("pop1"); self:TurnTalk() end)
    self.talkBoard = t
    -- the board's name, carved along the top of its frame
    local title = W.Text(t, 10, W.FONT_TITLE)
    title:SetPoint("TOP", t, "TOP", 0, -1)
    title:SetText("Tavern Talk")
    title:SetTextColor(1, 0.86, 0.52)
    self.notes = {}
    for i = 1, 2 do
        local n = CreateFrame("Frame", nil, t)
        n:SetSize(214, 39)
        n:SetPoint("TOPLEFT", t, "TOPLEFT", i == 1 and 17 or 21, -(15 + (i - 1) * 42))
        n:SetFrameLevel(t:GetFrameLevel() + 1)
        local p = n:CreateTexture(nil, "ARTWORK")
        p:SetTexture(T .. (i == 1 and "tav_note_a" or "tav_note_b"))
        p:SetAllPoints()
        local pin = n:CreateTexture(nil, "OVERLAY")
        pin:SetTexture(T .. "tav_pin")
        pin:SetSize(20, 20)
        pin:SetPoint("CENTER", n, "TOPLEFT", 12, -8)
        n.text = W.Text(n, 10, W.FONT)
        n.text:SetPoint("TOPLEFT", 24, -6)
        n.text:SetPoint("BOTTOMRIGHT", -12, 7)
        n.text:SetJustifyH("LEFT")
        if n.text.SetJustifyV then n.text:SetJustifyV("MIDDLE") end
        if n.text.SetMaxLines then n.text:SetMaxLines(2) end
        n.text:SetTextColor(INK[1], INK[2], INK[3])
        n.text:SetShadowColor(0, 0, 0, 0)
        self.notes[i] = n
    end
    self.talkAt = 0
    self.talkT = 0
end

function UI:TalkLines()
    local S = NS.Social
    if not (S and S.db and S.db.boards) then return {} end
    local me = S.Me()
    local today = Today()
    local out = {}
    S:RefreshPeople()
    for game, days in pairs(S.db.boards) do
        local label = BOARD_NAMES[game]
        if not label and game:match("^pq_") then label = "Greens" end
        if not label and game:match("^rt_") then label = "Flight golf" end
        for day, entries in pairs(days) do
            if day == "all" or day == today then
                local mine = entries[me]
                for who, e in pairs(entries) do
                    if who ~= me and e.t and not e.r then
                        local close = S:IsFriend(who) or S:IsGuildmate(who) or e.src == "guild" or e.src == "friend" or e.src == "group"
                        if close then
                            local beat = mine and ((S.GAMES[game] == "low" and e.s < mine.s) or (S.GAMES[game] ~= "low" and e.s > mine.s))
                            local score = (S.GAMES[game] == "low") and NS.Putt.FormatTime(e.s) or W.Short(e.s)
                            local name = NAME .. (Ambiguate and Ambiguate(who, "short") or who) .. "|r"
                            local line = beat and ("%s beat you at %s: |cff000000%s|r"):format(name, label or game, score)
                                or ("%s scored |cff000000%s|r at %s"):format(name, score, label or game)
                            out[#out + 1] = { t = e.t, text = line }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.text < b.text end)
    return out
end

local function Ago(t)
    local now = time and time() or t
    local d = max(0, now - t)
    if d < 90 then return "now" end
    if d < 3600 then return floor(d / 60) .. "m" end
    if d < 86400 then return floor(d / 3600) .. "h" end
    return floor(d / 86400) .. "d"
end

-- more than two notes? the board turns over to the next pair
function UI:TurnTalk()
    local n = #(self.talkLines or {})
    if n <= 2 then return end
    self.talkAt = (self.talkAt + 2) % (ceil(n / 2) * 2)
    self.talkT = 0
    self:RefreshTalk(true)
end

function UI:RefreshTalk(keep)
    if not keep then self.talkLines = self:TalkLines() end
    local lines = self.talkLines or {}
    if self.talkAt >= #lines then self.talkAt = 0 end
    for i, n in ipairs(self.notes) do
        local it = lines[self.talkAt + i]
        if it then
            n.text:SetText(("%s  |cff7d6a4c%s|r"):format(it.text, Ago(it.t)))
            n:Show()
        elseif #lines == 0 then
            -- nothing pinned yet: two notes from the keeper
            local off = NS.db.settings.share == false
            if i == 1 then n.text:SetText(off and "Score sharing is switched off." or "It's quiet in here for now.")
            else n.text:SetText(off and "Turn it on in Options to hear from friends and guild." or "Scores from friends and guild get pinned up here.") end
            n:Show()
        else
            n:Hide()
        end
    end
end

---------------------------------------------------------------------------
function UI:Refresh()
    if not self.frame then return end
    self:RefreshSpecials()
    self:RefreshPatron()
    self:RefreshFloor()
    self:RefreshTalk()
    self:RefreshFeatures()
end

function UI:OnShow()
    self.preview, self.hover = nil, nil
    for _, c in ipairs(self.slots) do c.over = false end
    self:FillFloor()
    self:Refresh()
    self:RefreshPortrait()
    if NS.Social then
        -- ask around for today's dailies so the talk and ranks are fresh
        for _, g in ipairs({ "putt", "flapd" }) do pcall(NS.Social.Query, NS.Social, g, Today()) end
    end
    self.refreshT = 2
    self.mqT = 0
    local m = self.marquee
    local want = self:WantedFeature()
    if want then self:ApplyFeature(want); m.alpha = 1; m.body:SetAlpha(1); m.next = nil end
    self:Greet()
end

function UI:OnHide()
    self.preview, self.hover = nil, nil
    if self.bubble then self.bubble:Hide(); self.sayOn = false; self.sayA = 0; self.bubble:SetAlpha(0) end
end

function UI:OnUpdate(el)
    local still = Still()
    self.t = self.t + el
    local t = self.t

    -- lantern light on the wall
    for i, g in ipairs(self.lamps) do
        local q = t * (5 + i) + i * 2
        g:SetAlpha(still and 0.5 or (0.44 + 0.08 * sin(q) + 0.05 * sin(q * 2.7 + 1) + 0.04 * sin(q * 5.3)))
    end

    -- the keeper: breathes a little, hops when she changes pose
    self.hop = max(0, (self.hop or 0) - el * 4)
    local bob = still and 0 or (sin(t * 2.1) * 1.2 + sin(self.hop * 3.1416) * 5)
    self.host.tex:SetPoint("BOTTOM", self.host, "BOTTOM", 4, -4 + bob)

    -- her scroll fades in while she talks and away when she is done
    if self.sayOn and self.sayHold then
        self.sayHold = self.sayHold - el
        if self.sayHold <= 0 then self.sayOn = false; self.sayHold = nil end
    end
    local want = self.sayOn and 1 or 0
    if self.sayA ~= want then
        local d = want - self.sayA
        self.sayA = (still or abs(d) < 0.02) and want or (self.sayA + d * min(1, el * 10))
        self.bubble:SetAlpha(self.sayA)
        if self.sayA == 0 then
            self.bubble:Hide()
            if not self.hover then self:Pose("wave") end
        end
    end
    -- every so often she offers a tip of her own
    self.tipT = (self.tipT or 5) - el
    if self.tipT <= 0 then
        if self.hover then self.tipT = 4 else self:NextTip() end
    end

    -- the marquee: chasing bulbs, flickering lanterns, features in rotation
    local m = self.marquee
    local lit = m.over or self.preview
    for i, g in ipairs(m.bulbs) do
        local k
        if still then k = 0.55
        elseif lit then k = 0.75 + 0.2 * sin(t * 9 + i)
        else
            local ph = (t * 1.6 - i * 0.2) % 1
            k = 0.22 + 0.7 * max(0, 1 - ph * 2.4)
        end
        g:SetAlpha(k)
    end
    for i, g in ipairs(m.lanterns) do
        local q = t * (6 + i) + i * 3
        g:SetAlpha(still and 0.6 or (0.55 + 0.12 * sin(q) + 0.07 * sin(q * 2.3 + 1)))
    end
    local sa = m.over and 0.16 or 0
    m.shineA = (m.shineA or 0) + (sa - (m.shineA or 0)) * min(1, el * 10)
    m.shine:SetAlpha(m.shineA)
    if not self.preview and not m.over and #(self.features or {}) > 1 then
        self.mqT = self.mqT + el
        if self.mqT >= 6.5 then
            self.mqT = 0
            self.mqIdx = self.mqIdx % #self.features + 1
        end
    end
    local ft = self:WantedFeature()
    if ft and (not m.shown or m.shown.id ~= ft.id) then
        if still then
            self:ApplyFeature(ft); m.alpha = 1
        else
            m.alpha = m.alpha - el * 9
            if m.alpha <= 0 then m.alpha = 0; self:ApplyFeature(ft) end
        end
        m.body:SetAlpha(m.alpha)
    elseif m.alpha < 1 then
        m.alpha = min(1, m.alpha + el * 6)
        m.body:SetAlpha(m.alpha)
    end

    -- the floor: a cabinet lifts and lights up when you point at it; runes pulse; screens flicker
    for _, c in ipairs(self.slots) do
        local wantLift = (c.over and not still) and 4 or 0
        if c.lift ~= wantLift then
            local d = wantLift - c.lift
            c.lift = abs(d) < 0.1 and wantLift or (c.lift + d * min(1, el * 14))
            c.body:SetPoint("TOPLEFT", c, "TOPLEFT", 0, c.lift)
        end
        if c.game then
            local wantGlow = c.over and 1 or 0
            c.glow = c.glow + (wantGlow - c.glow) * min(1, el * 10)
            c.lamp:SetAlpha(c.glow * (still and 0.8 or (0.75 + 0.15 * sin(t * 11 + c.phase))))
            c.screen:SetAlpha(0.10 + 0.22 * c.glow + (still and 0 or 0.03 * sin(t * 7 + c.phase * 3)))
            c.rune:SetAlpha(still and 0.4 or (0.32 + 0.22 * sin(t * 1.8 + c.phase) + 0.3 * c.glow))
            local v = 0.82 + 0.18 * c.glow
            c.art:SetVertexColor(v, v, v)
        end
    end
    local p = self.plaque
    p.ringA = (p.ringA or 0) + ((p.over and 0.8 or 0) - (p.ringA or 0)) * min(1, el * 10)
    p.ring:SetAlpha(p.ringA)

    -- the notice board turns over on its own when there is more to read
    self.talkT = self.talkT + el
    if self.talkT >= 8 then self:TurnTalk(); self.talkT = 0 end

    self.refreshT = (self.refreshT or 0) - el
    if self.refreshT <= 0 then
        self.refreshT = 3
        self:Refresh()
    end
end

function UI:ShowHelp()
    NS.Shell.card:Open({
        title = "Welcome to the Tavern", color = COLORS.gold, center = true,
        body = table.concat({
            "Every game is a cabinet on the floor: point at one to see it up on the marquee, click it to play.",
            "",
            "The marquee always has something worth playing, and its PLAY button takes you straight there.",
            "",
            "Dailies are chalked on the board and are the same for everyone, so compare times with your friends and guild. Tavern Talk pins up their latest scores.",
        }, "\n"),
        buttons = { { "Let's play" } },
    })
end

function UI:Banner() end
