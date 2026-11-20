-- Flight Buddy :: Home.lua
-- The Tavern: the common room you land in when you open Flight Buddy. A chalkboard of today's
-- specials (the dailies), your patron's plaque, a game card pinned to the notice board for every
-- game, and "Tavern Talk": the latest scores from your friends and guild.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local floor, max, min = math.floor, math.max, math.min

local UI = {}
NS.Home = UI

-- every game in the tavern: tab key, name, tagline, thumbnail art (file + texcoords), leaderboard key
UI.GAMES = {
    { key = "peg",  name = "Rune Breaker", tag = "Shatter runes with Warcraft heroes",
      art = "bg_dalaran", coords = { 0.0, 1.0, 0.12, 0.44 }, board = "rb", ink = { 0.55, 0.22, 0.10 },
      -- three of the heroes lined up in front of Dalaran (rb_heroes is a 4x4 portrait atlas)
      sprites = { { "rb_heroes", { 0, 0.25, 0, 0.25 }, -64 }, { "rb_heroes", { 0.25, 0.5, 0, 0.25 }, 0 }, { "rb_heroes", { 0.75, 1, 0, 0.25 }, 64 } } },
    { key = "putt", name = "Gryphon Greens", tag = "Mini golf against the clock",
      art = "greens\\goldshire", coords = { 0.0, 1.0, 0.32, 0.62 }, board = "putt", daily = true, ink = { 0.18, 0.42, 0.14 } },
    { key = "flap", name = "Featherbeard", tag = "Fly a gryphon through Dun Morogh",
      art = "flap\\bg_far", coords = { 0.0, 0.62, 0.20, 0.55 }, board = "flap", ink = { 0.50, 0.34, 0.08 },
      sprites = { { "flap\\flyer_2", { 0, 1, 0, 1 }, 40, 66 } } },
    { key = "pin",  name = "High Tinker Pinball", tag = "Gnomish pinball in Tinker Town",
      art = "pin\\pin_table", coords = { 0.05, 0.95, 0.08, 0.30 }, board = "pin", ink = { 0.48, 0.20, 0.06 } },
    { key = "gem",  name = "Jewelcrafter's Bench", tag = "Cut gems three in a row",
      art = "gems\\gem_velvet", coords = { 0, 1, 0.3, 0.55 }, tint = { 0.2, 0.24, 0.52 }, board = "gemd", daily = true, ink = { 0.20, 0.26, 0.55 },
      sprites = { { "gems\\gem_ruby", { 0, 1, 0, 1 }, -78, 34 }, { "gems\\gem_sapphire", { 0, 1, 0, 1 }, -40, 34 }, { "gems\\gem_prism", { 0, 1, 0, 1 }, 0, 38 },
                  { "gems\\gem_emerald", { 0, 1, 0, 1 }, 40, 34 }, { "gems\\gem_topaz", { 0, 1, 0, 1 }, 78, 34 } } },
    { key = "roll", name = "Death Roll", tag = "Wager gold on the roll of the dice",
      art = "deathroll\\dr_arena", coords = { 0.0, 1.0, 0.215, 0.305 }, ink = { 0.52, 0.12, 0.08 },
      sprites = { { "deathroll\\dr_die", { 0, 1, 0, 1 }, -46, 38 }, { "deathroll\\dr_icon", { 0, 1, 0, 1 }, 0, 46 }, { "deathroll\\dr_die_skull", { 0, 1, 0, 1 }, 46, 38 } } },
}

local function Today() return NS.Social and NS.Social.Today() or (date and date("%Y%m%d")) or "" end

function UI:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    self.frame = f
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -38)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    f:Hide()

    -- the room: dark plank wall with warm candlelight pooling in from above
    local wall = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    wall:SetTexture(W.TAVERN .. "wall_planks")
    wall:SetAllPoints()
    local warm = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    warm:SetTexture(W.TAVERN .. "candle_glow")
    warm:SetBlendMode("ADD")
    warm:SetVertexColor(1, 0.75, 0.4, 0.35)
    warm:SetSize(700, 420)
    warm:SetPoint("CENTER", f, "TOP", 0, -60)
    self.warm = warm

    self:BuildSpecials(f)
    self:BuildPatron(f)
    self:BuildCards(f)
    self:BuildTalk(f)
    f:SetScript("OnUpdate", function(_, el) W.Guard("Tavern", self.OnUpdate, self, el) end)
end

---------------------------------------------------------------------------
-- Today's specials: a chalkboard of the dailies and what's waiting in each game
---------------------------------------------------------------------------
function UI:BuildSpecials(f)
    local b = CreateFrame("Frame", nil, f)
    b:SetPoint("TOPLEFT", 10, -4)
    b:SetSize(318, 158)
    W.Nine(b, "chalk", 20, "BACKGROUND", -4)
    local t = W.Text(b, 18, W.FONT_TITLE)
    t:SetPoint("TOP", 0, -16)
    t:SetText("Today's Specials")
    t:SetTextColor(COLORS.chalk[1], COLORS.chalk[2], COLORS.chalk[3])
    t:SetShadowColor(0, 0, 0, 0)
    -- a chalk underline
    local ul = W.Solid(b, "ARTWORK", 0.9, 0.92, 0.86, 0.35)
    ul:SetSize(150, 1)
    ul:SetPoint("TOP", t, "BOTTOM", 0, -3)
    self.specials = {}
    for i = 1, 4 do
        local r = CreateFrame("Button", nil, b)
        r:SetSize(278, 22)
        r:SetPoint("TOPLEFT", 20, -46 - (i - 1) * 25)
        r.dot = W.Text(r, 12, W.FONT)
        r.dot:SetPoint("LEFT", 0, 0)
        r.dot:SetText("~")
        r.dot:SetShadowColor(0, 0, 0, 0)
        r.text = W.Text(r, 12, W.FONT)
        r.text:SetPoint("LEFT", 14, 0)
        r.text:SetPoint("RIGHT", -56, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetShadowColor(0, 0, 0, 0)
        r.state = W.Text(r, 11, W.FONT)
        r.state:SetPoint("RIGHT", 0, 0)
        r.state:SetJustifyH("RIGHT")
        r.state:SetShadowColor(0, 0, 0, 0)
        r.hl = W.Solid(r, "HIGHLIGHT", 1, 1, 1, 0.06)
        r.hl:SetAllPoints()
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
        out[#out + 1] = { text = ("%s > %s"):format(spec.from, spec.to),
            done = e and e.best and NS.Putt.FormatTime(e.best),
            state = ("|cff3be870%d hole%s|r"):format(spec.holes, spec.holes == 1 and "" or "s"),
            go = function() NS.Shell:SelectTab("putt"); NS.PuttUI:PlayFlight() end }
    end
    -- Greens daily course
    local putt = NS.PuttUI
    local day = Today()
    local pd = db.putt and db.putt.daily and db.putt.daily[day]
    local cname = "today's course"
    if NS.Putt and NS.Putt.DailyCourseKey then
        local ok, c = pcall(function() return NS.Putt.CourseInfo(NS.Putt.DailyCourseKey(tonumber(day))) end)
        if ok and c and c.name then cname = c.name end
    end
    out[#out + 1] = { text = cname .. " golf", done = pd and pd.best and NS.Putt.FormatTime(pd.best),
        go = function() NS.Shell:SelectTab("putt") end }
    -- Featherbeard daily run
    local fd = NS.FlapUI.Daily and NS.FlapUI.db and NS.FlapUI:Daily()
    local fdone = fd and (fd.best or 0) > 0 and ("best " .. fd.best)
    out[#out + 1] = { text = "Ironforge Run", done = fdone,
        go = function() NS.Shell:SelectTab("flap"); if NS.FlapUI.SetMode then NS.FlapUI:SetMode("daily") end end }
    -- Jewelcrafter's Daily Commission
    local G = NS.GemsUI
    local gd = G.db and G:Daily()
    out[#out + 1] = { text = "Gem commission", done = gd and (gd.best or 0) > 0 and W.Short(gd.best),
        go = function() NS.Shell:SelectTab("gem"); if G.Begin then G:Begin("daily", { day = Today() }) end end }
    -- Rune Breaker run in progress (shown last)
    local run = db.peg and db.peg.run
    -- the board has four lines; in the air the flight takes this one
    if #out < 4 then out[#out + 1] = { text = run and ("Rune Breaker: stage " .. (run.level or 1)) or "Rune Breaker: new run",
        state = "|cffd8d0b8play|r", go = function() NS.Shell:SelectTab("peg") end } end
    return out
end

function UI:RefreshSpecials()
    local list = self:Specials()
    local c = COLORS.chalk
    for i, r in ipairs(self.specials) do
        local it = list[i]
        if it then
            r.text:SetText(it.text)
            r.text:SetTextColor(c[1], c[2], c[3], it.done and 0.55 or 1)
            r.dot:SetTextColor(c[1], c[2], c[3], 0.7)
            if it.done then
                r.state:SetText("|cff9fe08a" .. it.done .. "|r")
            else
                r.state:SetText(it.state or "|cffffd27anew!|r")
            end
            r:SetScript("OnClick", function() W.SFX("pop2"); it.go() end)
            r:Show()
        else
            r:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- The patron's plaque: who you are in this tavern
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
    return n
end

function UI:PatronTitle()
    local n = self:GamesPlayed()
    local title, nextAt = UI.TITLES[1][2], nil
    for i, t in ipairs(UI.TITLES) do
        if n >= t[1] then title = t[2]; nextAt = UI.TITLES[i + 1] and UI.TITLES[i + 1][1] end
    end
    return title, n, nextAt
end

function UI:BuildPatron(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPRIGHT", -10, -4)
    p:SetSize(172, 158)
    W.Nine(p, "wood", 18, "BACKGROUND", -4)
    local crest = p:CreateTexture(nil, "BORDER")
    crest:SetTexture(W.TAVERN .. "coaster")
    crest:SetSize(52, 52)
    crest:SetPoint("TOP", 0, -14)
    local mug = p:CreateTexture(nil, "ARTWORK")
    mug:SetTexture("Interface\\Icons\\INV_Drink_04")
    mug:SetSize(30, 30)
    mug:SetPoint("CENTER", crest, "CENTER")
    mug:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.patronName = W.Text(p, 15, W.FONT_TITLE)
    self.patronName:SetPoint("TOP", crest, "BOTTOM", 0, -6)
    self.patronName:SetWidth(156)
    self.patronName:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.patronTitle = W.Text(p, 11, W.FONT)
    self.patronTitle:SetPoint("TOP", self.patronName, "BOTTOM", 0, -3)
    self.patronTitle:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    -- progress to the next title: a thin brass bar
    local barBg = W.Solid(p, "ARTWORK", 0.08, 0.05, 0.02, 1)
    barBg:SetSize(120, 6)
    barBg:SetPoint("TOP", self.patronTitle, "BOTTOM", 0, -8)
    self.patronBar = W.Solid(p, "OVERLAY", COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.9)
    self.patronBar:SetHeight(6)
    self.patronBar:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    self.patronBarBg = barBg
    self.patronStats = W.Text(p, 10, W.FONT)
    self.patronStats:SetPoint("TOP", barBg, "BOTTOM", 0, -6)
    self.patronStats:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
end

function UI:RefreshPatron()
    local name = UnitName and UnitName("player") or "Patron"
    self.patronName:SetText(name)
    local title, n, nextAt = self:PatronTitle()
    self.patronTitle:SetText(title)
    local prevAt = 0
    for _, t in ipairs(UI.TITLES) do if n >= t[1] then prevAt = t[1] end end
    local k = nextAt and (n - prevAt) / max(1, nextAt - prevAt) or 1
    self.patronBar:SetWidth(max(1, 120 * min(1, k)))
    local flights = (NS.db.stats and NS.db.stats.flights) or 0
    self.patronStats:SetText(("%s games  -  %s flights"):format(W.Commas(n), W.Commas(flights)))
end

---------------------------------------------------------------------------
-- Game cards: parchment pinned to the board, one per game
---------------------------------------------------------------------------
local CARD_W, CARD_H = 245, 116

function UI:BuildCards(f)
    self.cards = {}
    for i, g in ipairs(UI.GAMES) do
        local c = CreateFrame("Button", nil, f)
        c:SetSize(CARD_W, CARD_H)
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        c:SetPoint("TOPLEFT", 10 + col * (CARD_W + 10), -170 - row * (CARD_H + 8))
        W.Nine(c, "parch", 18, "BACKGROUND", -5)
        -- a slightly crooked pin at the top
        local tack = c:CreateTexture(nil, "OVERLAY", nil, 2)
        tack:SetTexture(W.TAVERN .. "tack")
        tack:SetSize(18, 18)
        tack:SetPoint("CENTER", c, "TOP", (i % 2 == 0) and 6 or -6, -8)
        -- the game's art in a dark wooden frame
        local frameT = W.Solid(c, "BORDER", 0.22, 0.13, 0.06, 1)
        frameT:SetPoint("TOPLEFT", 14, -14)
        frameT:SetPoint("TOPRIGHT", -14, -14)
        frameT:SetHeight(46)
        local art = c:CreateTexture(nil, "ARTWORK")
        art:SetPoint("TOPLEFT", frameT, "TOPLEFT", 3, -3)
        art:SetPoint("BOTTOMRIGHT", frameT, "BOTTOMRIGHT", -3, 3)
        art:SetTexture(W.MEDIA .. g.art)
        art:SetTexCoord(g.coords[1], g.coords[2], g.coords[3], g.coords[4])
        if g.tint then art:SetVertexColor(g.tint[1], g.tint[2], g.tint[3]) end
        c.art = art
        for _, sp in ipairs(g.sprites or {}) do
            local t = c:CreateTexture(nil, "ARTWORK", nil, 2)
            t:SetTexture(W.MEDIA .. sp[1])
            t:SetTexCoord(sp[2][1], sp[2][2], sp[2][3], sp[2][4])
            t:SetSize(sp[4] or 44, sp[4] or 44)
            t:SetPoint("BOTTOM", frameT, "BOTTOM", sp[3], 1)
        end
        c.name = W.Text(c, 15, W.FONT_TITLE)
        c.name:SetPoint("TOPLEFT", frameT, "BOTTOMLEFT", 0, -5)
        c.name:SetText(g.name)
        c.name:SetTextColor(g.ink[1], g.ink[2], g.ink[3])
        c.name:SetShadowColor(0, 0, 0, 0)
        c.stat = W.Text(c, 11, W.FONT)
        c.stat:SetPoint("BOTTOMLEFT", 16, 15)
        c.stat:SetPoint("RIGHT", c, "RIGHT", -78, 0)
        c.stat:SetJustifyH("LEFT")
        c.stat:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
        c.stat:SetShadowColor(0, 0, 0, 0)
        c.play = W.Button(c, 62, 24, "Play", "primary")
        c.play:SetPoint("BOTTOMRIGHT", -14, 10)
        c.play:SetScript("OnClick", function() self:Go(g.key) end)
        c.badge = W.Text(c, 10, W.FONT, "OUTLINE")
        c.badge:SetPoint("TOPRIGHT", frameT, "TOPRIGHT", -6, -5)
        c.badge:SetTextColor(1, 0.86, 0.45)
        -- the whole card is clickable; it lifts a little when you point at it
        local glow = c:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture(W.TAVERN .. "candle_glow")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.8, 0.45, 0.18)
        glow:SetPoint("TOPLEFT", -20, 20)
        glow:SetPoint("BOTTOMRIGHT", 20, -20)
        c:SetScript("OnClick", function() self:Go(g.key) end)
        c:SetScript("OnEnter", function(b)
            if not GameTooltip then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(g.name, 1, 0.82, 0.38)
            GameTooltip:AddLine(g.tag, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        c.game = g
        self.cards[i] = c
    end
    -- the empty slot on the board: a notice about games on the way
    local n = #UI.GAMES
    if n % 2 == 1 then
        local c = CreateFrame("Frame", nil, f)
        c:SetSize(CARD_W, CARD_H)
        local row = floor(n / 2)
        c:SetPoint("TOPLEFT", 10 + (CARD_W + 10), -170 - row * (CARD_H + 8))
        W.Nine(c, "parch", 18, "BACKGROUND", -5)
        local tack = c:CreateTexture(nil, "OVERLAY", nil, 2)
        tack:SetTexture(W.TAVERN .. "tack")
        tack:SetSize(18, 18)
        tack:SetPoint("CENTER", c, "TOP", 4, -8)
        local t = W.Text(c, 15, W.FONT_TITLE)
        t:SetPoint("TOP", 0, -22)
        t:SetText("Coming soon")
        t:SetTextColor(0.42, 0.22, 0.08)
        t:SetShadowColor(0, 0, 0, 0)
        local b = W.Text(c, 11, W.FONT)
        b:SetPoint("TOP", t, "BOTTOM", 0, -8)
        b:SetWidth(CARD_W - 30)
        b:SetText("Deeprun Tram Runner\nAzeroth Trivia\nGoblin Minefield")
        b:SetTextColor(COLORS.ink[1], COLORS.ink[2], COLORS.ink[3])
        b:SetShadowColor(0, 0, 0, 0)
        if b.SetSpacing then b:SetSpacing(3) end
    end
end

function UI:Go(key)
    W.SFX("pop3")
    NS.Shell:SelectTab(key)
end

function UI:CardStat(g)
    local db = NS.db
    local S = NS.Social
    if g.key == "roll" then
        local s = db.dr
        local played = s and ((s.wins or 0) + (s.losses or 0)) or 0
        if played == 0 then return "Challenge a friend" end
        local net = s.net or 0
        return ("%d won, %d lost  |  %s%s"):format(s.wins, s.losses, net >= 0 and "+" or "-", NS.DeathRoll.Money(math.abs(net)))
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

function UI:RefreshCards()
    for _, c in ipairs(self.cards) do
        local text, board, day = self:CardStat(c.game)
        c.stat:SetText(text or "")
        local badge = ""
        if board and NS.Social then
            for _, fl in ipairs({ { "guild", "Guild" }, { "friend", "Friends" }, { "realm", "Realm" } }) do
                local rk, n = NS.Social:Rank(board, day, fl[1])
                if rk and n > 1 then badge = ("%s #%d"):format(fl[2], rk); break end
            end
        end
        c.badge:SetText(badge)
        local mod = NS.Shell.mods and NS.Shell.mods[c.game.key]
        local pending = c.game.daily and mod and mod.DailyPending and mod.db and mod:DailyPending()
        c.play.text:SetText(pending and "Daily!" or "Play")
    end
end

---------------------------------------------------------------------------
-- Tavern Talk: the latest results from your friends and guild
---------------------------------------------------------------------------
local BOARD_NAMES = { rb = "Rune Breaker", putt = "the Greens daily", flap = "Featherbeard", flapd = "the Ironforge Run",
    pin = "High Tinker Pinball", gem = "Gem Rush", gemd = "the Daily Commission", gemw = "Work Orders" }

function UI:BuildTalk(f)
    local t = CreateFrame("Frame", nil, f)
    t:SetPoint("BOTTOMLEFT", 10, 6)
    t:SetPoint("BOTTOMRIGHT", -10, 6)
    t:SetHeight(122)
    W.Nine(t, "wood", 18, "BACKGROUND", -4)
    local title = W.Text(t, 15, W.FONT_TITLE)
    title:SetPoint("TOPLEFT", 20, -14)
    title:SetText("Tavern Talk")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    local sub = W.Text(t, 10, W.FONT)
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
    sub:SetText("the latest from your friends and guild")
    sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    self.talk = {}
    for i = 1, 4 do
        local l = W.Text(t, 11, W.FONT)
        l:SetPoint("TOPLEFT", 22, -36 - (i - 1) * 19)
        l:SetPoint("RIGHT", t, "RIGHT", -20, 0)
        l:SetJustifyH("LEFT")
        self.talk[i] = l
    end
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
                            local score = (S.GAMES[game] == "low") and NS.Putt.FormatTime(e.s) or W.Commas(e.s)
                            local name = "|cffffd27a" .. (Ambiguate and Ambiguate(who, "short") or who) .. "|r"
                            local line = beat and ("%s beat your score at %s: |cffffffff%s|r"):format(name, label or game, score)
                                or ("%s scored |cffffffff%s|r at %s"):format(name, score, label or game)
                            out[#out + 1] = { t = e.t, text = line }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

local function Ago(t)
    local now = time and time() or t
    local d = max(0, now - t)
    if d < 90 then return "just now" end
    if d < 3600 then return floor(d / 60) .. "m ago" end
    if d < 86400 then return floor(d / 3600) .. "h ago" end
    return floor(d / 86400) .. "d ago"
end

function UI:RefreshTalk()
    local lines = self:TalkLines()
    for i, l in ipairs(self.talk) do
        local it = lines[i]
        if it then
            l:SetText(("%s  |cff8a7a62%s|r"):format(it.text, Ago(it.t)))
        elseif i == 1 then
            l:SetText(NS.db.settings.share == false and "|cff9a8a72Score sharing is off - turn it on in Options to hear from friends and guild.|r"
                or "|cff9a8a72It's quiet in here. Scores from friends and guildmates with Flight Buddy will show up as they play.|r")
        else
            l:SetText("")
        end
    end
end

---------------------------------------------------------------------------
function UI:Refresh()
    if not self.frame then return end
    self:RefreshSpecials()
    self:RefreshPatron()
    self:RefreshCards()
    self:RefreshTalk()
end

function UI:OnShow()
    self:Refresh()
    if NS.Social then
        -- ask around for today's dailies so the talk and ranks are fresh
        for _, g in ipairs({ "putt", "flapd" }) do pcall(NS.Social.Query, NS.Social, g, Today()) end
    end
    self.refreshT = 2
end

function UI:OnHide() end

function UI:OnUpdate(el)
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
            "Pull up a chair! Pick a game from the notice board, or a special from the chalkboard.",
            "",
            "Dailies are the same for everyone on a given day, so compare times with your friends and guild.",
            "Tavern Talk shows the latest scores from people you know.",
        }, "\n"),
        buttons = { { "Let's play" } },
    })
end

function UI:Banner() end
