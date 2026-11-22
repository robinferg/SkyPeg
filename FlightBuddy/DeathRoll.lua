-- Flight Buddy: Death Roll. One-on-one death rolls with a wager, played with the game's real /roll.
-- First roll is 1 to the starting number, every next roll is 1 to the last result, and whoever rolls a 1 loses.
-- A challenge goes out like a duel request (a hidden whisper), so it can be sent from anywhere. Rolls are read
-- from the system "X rolls N (1-M)" line whenever it is visible (same party or raid, or standing nearby);
-- when it is not, each player's addon reports its own roll. Guildmates and groupmates with Flight Buddy get a
-- notice and can watch the play-by-play.
local _, NS = ...
local D = {}
NS.DeathRoll = D

local floor, min, max = math.floor, math.min, math.max
local PREFIX = "FBDR"
local INVITE_SECS = 60
local COPPER_PER_GOLD = 10000
D.STARTS = { 100, 1000, 10000, 100000 }

local queue, sendAcc = {}, 0

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
-- names are written and whispered the one way Social does it (see "Names" in Social.lua)
local function MyRealm() return (GetNormalizedRealmName and GetNormalizedRealmName()) or "" end
local function Norm(name)
    if type(name) ~= "string" or name == "" then return nil end
    return NS.Social.Canon(name)
end
local function Short(full)
    if not full then return "?" end
    return NS.Social.Target(full)
end
local function Key(name) name = Norm(name); return name and name:lower() end
local function MeName() return Norm((UnitName and UnitName("player")) or "Player") end
local function Me() return Key(MeName()) end
local function MyClass() local _, c = UnitClass("player"); return c or "WARRIOR" end
local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(function() return get and get("FlightBuddy", "Version") end)
    return (ok and type(v) == "string" and v ~= "") and v or "?"
end
D.Short, D.Key = Short, Key
-- A player's name without the realm, lower case. The server does not always write a realm the way
-- this client does, and may write it differently from one message to the next (see Social.lua), so
-- inside a game the two players are told apart by this and by the game's number, never by realm.
local function Bare(name)
    if type(name) ~= "string" or name == "" then return nil end
    return (name:match("^(.+)%-[^%-]+$") or name):lower()
end
local function Same(a, b) return a ~= nil and b ~= nil and (Key(a) == Key(b) or Bare(a) == Bare(b)) end

function D.Money(copper)
    copper = floor(max(0, copper or 0) + 0.5)
    local g, s, c = floor(copper / COPPER_PER_GOLD), floor(copper / 100) % 100, copper % 100
    if g > 0 and s == 0 and c == 0 then return ("%sg"):format(NS.W.Commas(g)) end
    if g > 0 then return ("%sg %ds"):format(NS.W.Commas(g), s) end
    if s > 0 then return c > 0 and ("%ds %dc"):format(s, c) or ("%ds"):format(s) end
    return ("%dc"):format(c)
end

---------------------------------------------------------------------------
-- Wire
---------------------------------------------------------------------------
-- the last few messages in and out, for /deathroll debug
local wireLog = {}
local function Log(dir, chan, who, text)
    wireLog[#wireLog + 1] = ("%s %s %s %s: %s"):format(date and date("%H:%M:%S") or "", dir, chan or "?", tostring(who or "-"), tostring(text):sub(1, 60))
    if #wireLog > 24 then table.remove(wireLog, 1) end
end
local function Raw(text, chatType, target) queue[#queue + 1] = { text, chatType, target } end
local function Whisper(name, ...) Raw(table.concat({ ... }, ","), "WHISPER", Short(name)) end
-- Every way a player might be reached, each once: as we would normally whisper them, and by bare
-- name when that carries a realm (a spelling of our own realm we have not learned yet cannot be
-- whispered, but the bare name can).
local function Addresses(names)
    local list, seen = {}, {}
    local function add(t)
        if type(t) ~= "string" or t == "" or NS.Social.IsMe(t) then return end
        t = Short(t)
        if not seen[t:lower()] then seen[t:lower()] = true; list[#list + 1] = t end
    end
    for i = 1, 4 do
        local name = names[i]
        if type(name) == "string" and name ~= "" then
            add(name)
            add(name:match("^(.+)%-[^%-]+$"))
        end
    end
    return list
end
-- an answer to somebody: it goes to every spelling of them we have (the game on the other side takes
-- the same news twice without harm)
local function Reply(names, ...)
    local text = table.concat({ ... }, ",")
    for _, t in ipairs(Addresses(names)) do Raw(text, "WHISPER", t) end
end
-- everyone who might want to watch: the guild and whatever group I'm in
local function Broadcast(...)
    local text = table.concat({ ... }, ",")
    if IsInGuild and IsInGuild() then Raw(text, "GUILD") end
    if IsInRaid and IsInRaid() then Raw(text, "RAID")
    elseif IsInGroup and IsInGroup() then Raw(text, "PARTY") end
end

function D:Init(db)
    db.dr = db.dr or {}
    local s = db.dr
    s.ledger = s.ledger or {}     -- [player key] = { name =, owe = copper they owe me (negative: I owe them) }
    s.looks = s.looks or {}       -- [player key] = { race =, sex =, items = { ... }, at =, name = } (see "Looks")
    s.history = s.history or {}   -- newest first
    s.wins, s.losses, s.net = s.wins or 0, s.losses or 0, s.net or 0
    if s.notify == nil then s.notify = true end
    if s.start == nil then s.start = 1000 end
    self.db = s
    self:TidyNames()
    self.watch = {}
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    -- "%s rolls %d (%d-%d)" in the client's own language, turned into a pattern
    local fmt = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pat = pat:gsub("%%%d?%$?s", "(.+)"):gsub("%%%d?%$?d", "(%%d+)")
    self.rollPattern = "^" .. pat .. "$"
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_SYSTEM", "TRADE_SHOW", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "UI_INFO_MESSAGE" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, event, a1, a2)
        NS.W.Guard("DeathRoll", function()
            if event == "CHAT_MSG_SYSTEM" then D:OnSystem(a1)
            elseif event == "TRADE_SHOW" then D:OnTradeShow()
            elseif event == "TRADE_MONEY_CHANGED" or event == "TRADE_ACCEPT_UPDATE" then D:OnTradeMoney()
            elseif event == "TRADE_CLOSED" then D:OnTradeClosed()
            elseif event == "UI_INFO_MESSAGE" then
                local msg = type(a2) == "string" and a2 or a1
                if ERR_TRADE_COMPLETE and msg == ERR_TRADE_COMPLETE then D:OnTradeDone() end
            end
        end)
    end)
    self.events = ev
    if StaticPopupDialogs then
        StaticPopupDialogs["FLIGHTBUDDY_DR_INVITE"] = {
            text = "%s challenges you to a Death Roll.\n%s",
            button1 = ACCEPT or "Accept", button2 = DECLINE or "Decline",
            OnAccept = function() D:Accept() end,
            OnCancel = function() D:Decline() end,
            timeout = INVITE_SECS, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopupDialogs["FLIGHTBUDDY_DR_DOUBLE"] = {
            text = "%s wants DOUBLE OR NOTHING.\n%s",
            button1 = ACCEPT or "Accept", button2 = DECLINE or "Decline",
            OnAccept = function() D:AnswerDouble(true) end,
            OnCancel = function() D:AnswerDouble(false) end,
            timeout = INVITE_SECS, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
end

function D:Changed() if self.onChange then self.onChange() end end

---------------------------------------------------------------------------
-- Who may put a challenge on your screen: people you are grouped with, friends and guildmates
---------------------------------------------------------------------------
function D:Trusted(sender)
    if self.db.anyone then return true end
    local short = Short(sender)
    if (UnitInParty and UnitInParty(short)) or (UnitInRaid and UnitInRaid(short)) then return true end
    local S = NS.Social
    if S and ((S.IsFriend and S:IsFriend(sender)) or (S.IsGuildmate and S:IsGuildmate(sender))) then return true end
    return false
end

-- a unit token for a player, if they are my target or in my group (for their model and for trading)
function D.UnitFor(full)
    local key = Key(full)
    if not key then return nil end
    if key == Me() then return "player" end
    local function is(unit)
        if not (UnitExists and UnitExists(unit)) then return false end
        local n, r = UnitName(unit)
        return n and Key(r and r ~= "" and (n .. "-" .. r) or n) == key
    end
    if is("target") then return "target" end
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do if is("raid" .. i) then return "raid" .. i end end
    else
        for i = 1, 4 do if is("party" .. i) then return "party" .. i end end
    end
    return nil
end

---------------------------------------------------------------------------
-- Looks: what a player's character looks like (race, sex and what they are wearing), so the pit can
-- show them when they are not standing next to you. Each player sends their own with a challenge
-- or an accept; it is kept between sessions, so the next duel shows them straight away.
---------------------------------------------------------------------------
-- head, shoulders, back, chest, shirt, tabard, wrists, hands, waist, legs, feet, main hand, off hand, ranged
local LOOK_SLOTS = { 1, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 16, 17, 18 }
local RACE_ID = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8, Goblin = 9, BloodElf = 10, Draenei = 11 }
D.LOOK_SLOTS = LOOK_SLOTS

function D.MyLook()
    local _, raceFile, raceID
    if UnitRace then _, raceFile, raceID = UnitRace("player") end
    raceID = raceID or RACE_ID[raceFile or ""] or 1
    local sex = (UnitSex and UnitSex("player")) or 2      -- 2 male, 3 female
    local items = {}
    for i, slot in ipairs(LOOK_SLOTS) do items[i] = (GetInventoryItemID and GetInventoryItemID("player", slot)) or 0 end
    return { race = raceID, sex = sex == 3 and 3 or 2, items = items, at = time() }
end

local function LookFields(l) return l.race, l.sex, table.concat(l.items, ".") end
local function SendLook(to, id) Whisper(to, "L", id, LookFields(D.MyLook())) end

function D:Look(key)
    local looks = key and self.db.looks
    if not looks then return nil end
    if looks[key] then return looks[key] end
    -- the same player kept under another spelling of the realm
    local b = Bare(key)
    for k, l in pairs(looks) do if Bare(k) == b then return l end end
    return nil
end

function D:StoreLook(skey, name, race, sex, itemText)
    race, sex = tonumber(race), tonumber(sex)
    if not race or race < 1 or race > 99 or race ~= floor(race) or (sex ~= 2 and sex ~= 3) or type(itemText) ~= "string" then return end
    local items, n = {}, 0
    for v in itemText:gmatch("[^%.]+") do
        n = n + 1
        if n > #LOOK_SLOTS then break end
        local id = tonumber(v)
        items[n] = (id and id >= 0 and id < 10000000 and id == floor(id)) and id or 0
    end
    for i = n + 1, #LOOK_SLOTS do items[i] = 0 end
    local looks = self.db.looks
    looks[skey] = { race = race, sex = sex, items = items, at = time(), name = name }
    -- keep the 150 most recent
    local count, oldest, oldKey = 0, nil, nil
    for k, l in pairs(looks) do
        count = count + 1
        if not oldest or (l.at or 0) < oldest then oldest, oldKey = l.at or 0, k end
    end
    if count > 150 and oldKey and oldKey ~= skey then looks[oldKey] = nil end
    self:Changed()
end

---------------------------------------------------------------------------
-- A game (mine, or one I am watching)
---------------------------------------------------------------------------
local function NewGame(id, aFull, bFull, aClass, bClass, wager, start)
    local a, b = Key(aFull), Key(bFull)
    return { id = id, a = a, b = b, wager = wager, start = start, round = 1,
             name = { [a] = aFull, [b] = bFull }, class = { [a] = aClass, [b] = bClass },
             cur = start, turn = a, seq = 0, hist = {}, hp = { [a] = start, [b] = start },
             state = "play", owed = nil, began = GetTime(), last = GetTime() }
end

local function Other(g, key) return key == g.a and g.b or g.a end
D.Other = Other

-- tell my opponent something about our game
local function Tell(g, ...)
    local opp = Other(g, Me())
    Reply({ g.to, g.name[opp], g.wire and g.wire[opp] }, ...)
end

-- Which of my game's two players sent this? Their exact name, a spelling of them seen before, the
-- same name under another spelling of the realm, or (while my challenge is waiting for its answer)
-- whoever answers it: only the player I whispered knows the game's number.
local function From(g, skey, sender, cmd)
    if skey == g.a or skey == g.b then return skey end
    local k = g.alias and g.alias[skey]
    if k then return k end
    local me = Me()
    if g.a ~= me and g.b ~= me then return nil end
    local opp = Other(g, me)
    local answer = g.state == "pending" and g.a == me and (cmd == "A" or cmd == "D")
    if Bare(sender) == Bare(g.name[opp]) or answer then
        g.alias = g.alias or {}
        g.alias[skey] = opp
        return opp
    end
    return nil
end

function D:Mine() return self.game end
function D:Busy() local g = self.game; return g and (g.state == "pending" or g.state == "play") end
function D:MyTurn() local g = self.game; return g and g.state == "play" and g.turn == Me() end

-- how hard a roll lands: the further the number falls, the bigger the hit
function D.HitKind(prev, roll)
    if roll <= 1 then return "death" end
    local f = (prev - roll) / max(1, prev)
    if f >= 0.85 then return "crit" end
    if f >= 0.5 then return "heavy" end
    if f >= 0.15 then return "hit" end
    return "glance"
end

-- a roll counts. Returns the history entry.
local function Apply(g, who, roll, verified)
    local prev = g.cur
    g.seq = g.seq + 1
    local e = { seq = g.seq, who = who, roll = roll, max = prev, kind = D.HitKind(prev, roll), verified = verified and true or false,
                round = g.round }
    g.hist[#g.hist + 1] = e
    g.cur = roll
    g.hp[who] = roll
    g.last = GetTime()
    if roll <= 1 then
        g.state, g.loser, g.winner = "over", who, Other(g, who)
        -- what is owed now. A double-or-nothing round either doubles the debt or wipes it.
        local before = g.owed and g.owed.amount or 0
        if g.owed and g.round > 1 then
            if g.loser == g.owed.from then g.owed.amount = g.owed.amount * 2 else g.owed.amount = 0 end
        else
            g.owed = { from = g.loser, to = g.winner, amount = g.wager }
        end
        e.before, e.after = before, g.owed.amount
    else
        g.turn = Other(g, who)
    end
    return e
end

---------------------------------------------------------------------------
-- Ledger and record
---------------------------------------------------------------------------
-- one player, one line: debts filed under another spelling of our realm are added to the one we use
function D:TidyNames()
    local led = self.db and self.db.ledger
    if not led then return end
    local moves
    for key, e in pairs(led) do
        local to = type(e) == "table" and e.name and Key(e.name)
        if to and to ~= key then moves = moves or {}; moves[#moves + 1] = { key, to } end
    end
    for _, m in ipairs(moves or {}) do
        local e = led[m[1]]
        led[m[1]] = nil
        e.name = Norm(e.name)
        if led[m[2]] then led[m[2]].owe = (led[m[2]].owe or 0) + (e.owe or 0) else led[m[2]] = e end
    end
    -- saved looks follow their owner to the one spelling too
    local looks, lm = self.db.looks, nil
    for key, l in pairs(looks or {}) do
        local to = type(l) == "table" and l.name and Key(l.name)
        if to and to ~= key then lm = lm or {}; lm[#lm + 1] = { key, to } end
    end
    for _, m in ipairs(lm or {}) do
        local l = looks[m[1]]
        looks[m[1]] = nil
        if not looks[m[2]] or (looks[m[2]].at or 0) < (l.at or 0) then looks[m[2]] = l end
    end
end

function D:Entry(full)
    local key = Key(full)
    local e = self.db.ledger[key]
    if not e then e = { name = full, owe = 0 }; self.db.ledger[key] = e end
    e.name = full
    return e
end

-- my game's round just ended: move the debt and the stats by what changed
function D:Record(g, e)
    local me = Me()
    local opp = Other(g, me)
    local delta = (e.after or 0) - (e.before or 0)          -- how much the debt grew (negative: it was wiped)
    local signed = (g.owed.to == me) and delta or -delta     -- from my side: + they owe me more
    local led = self:Entry(g.name[opp])
    led.owe = led.owe + signed
    local s = self.db
    s.net = s.net + signed
    if g.winner == me then s.wins = s.wins + 1 else s.losses = s.losses + 1 end
    table.insert(s.history, 1, { t = time(), opp = g.name[opp], won = g.winner == me, amount = g.round > 1 and (e.before or 0) or g.wager,
                                 double = g.round > 1 or nil, rolls = #g.hist })
    while #s.history > 40 do table.remove(s.history) end
end

---------------------------------------------------------------------------
-- Challenge, accept, play
---------------------------------------------------------------------------
function D:Challenge(name, wagerCopper, start)
    name = Norm(name and name:match("^%s*(.-)%s*$"))
    if not name or Key(name) == Me() then return false, "Pick another player" end
    if self:Busy() then return false, "You're already in a Death Roll" end
    wagerCopper = floor(max(0, wagerCopper or 0))
    start = floor(max(2, min(start or self.db.start or 1000, 1000000)))
    if GetMoney and GetMoney() < wagerCopper then return false, "You don't have that much gold" end
    local me = MeName()
    local g = NewGame(Short(me):gsub("[,;%s]", ""):sub(1, 12) .. ":" .. (time() % 100000), me, name, MyClass(), "WARRIOR", wagerCopper, start)
    g.state, g.sentAt = "pending", GetTime()
    g.to = name       -- the name the challenge went to: whatever else, that one reaches them
    self.game = g
    self.db.start, self.db.lastWager = start, wagerCopper
    Whisper(name, "C", g.id, wagerCopper, start, MyClass())
    SendLook(name, g.id)
    self:Changed()
    return true
end

function D:ChallengeTarget(wagerCopper, start)
    if not (UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")) then return false, "Target a player first" end
    local n, r = UnitName("target")
    return self:Challenge(r and r ~= "" and (n .. "-" .. r) or n, wagerCopper, start)
end

function D:Accept()
    local inv = self.invite
    if not inv then return end
    self.invite = nil
    if GetMoney and GetMoney() < inv.wager then
        Reply({ inv.from, inv.raw }, "D", inv.id, "poor")
        NS.Print("You don't have " .. D.Money(inv.wager) .. " to wager.")
        return
    end
    local g = NewGame(inv.id, inv.from, MeName(), inv.class, MyClass(), inv.wager, inv.start)
    g.wire = { [g.a] = inv.raw }
    self.game = g
    -- "I accept": whispered to every spelling of the challenger, and said on the guild and group
    -- channels too, so one lost whisper cannot leave them waiting
    Tell(g, "A", inv.id, MyClass(), Version())
    Broadcast("A", inv.id, MyClass(), Version())
    g.ackWait = { n = 0, at = GetTime() }   -- said again (see Pump) until the challenger's game says it heard
    Tell(g, "L", inv.id, LookFields(D.MyLook()))
    Broadcast("L", inv.id, LookFields(D.MyLook()))
    if self.onOpen then self.onOpen() end
    self:Changed()
end

function D:Decline(reason)
    local inv = self.invite
    if not inv then return end
    self.invite = nil
    Reply({ inv.from, inv.raw }, "D", inv.id, reason or "no")
end

-- throw the dice: the real /roll, so the server picks the number
function D:Roll()
    local g = self.game
    if not (g and g.state == "play" and g.turn == Me()) then return false end
    if g.rolledAt and GetTime() - g.rolledAt < 1.5 then return false end
    g.rolledAt = GetTime()
    if RandomRoll then RandomRoll(1, g.cur) end
    return true
end

function D:Announce(e)
    local g = self.game
    Broadcast("R", g.id, e.seq, Short(g.name[e.who]), e.roll, e.max)
end

local function StartRound(self, g)
    Broadcast("G", g.id, g.name[g.a], g.name[g.b], g.class[g.a], g.class[g.b], (g.owed and g.round > 1) and g.owed.amount * 2 or g.wager, g.start, g.round,
        g.name[g.turn], g.seq)
    -- and what I look like, for anyone watching
    if g.round == 1 then Broadcast("L", g.id, LookFields(D.MyLook())) end
end

-- my own roll or my opponent's, however it reached me
function D:TakeRoll(who, roll, maxv, verified)
    local g = self.game
    if not (g and g.state == "play") or who ~= g.turn or maxv ~= g.cur or roll < 1 or roll > g.cur then return false end
    local e = Apply(g, who, roll, verified)
    local me = Me()
    if who == me then
        Tell(g, "R", g.id, e.seq, roll, maxv)
        self:Announce(e)
    end
    if g.state == "over" then self:Record(g, e) end
    if self.onRoll then self.onRoll(g, e, true) end
    self:Changed()
    return true
end

-- the loser asks to go again for double or nothing
function D:OfferDouble()
    local g = self.game
    local me = Me()
    if not (g and g.state == "over" and g.owed and g.owed.amount > 0 and g.owed.from == me and not g.offer) then return false, "Nothing to double" end
    if GetMoney and GetMoney() < g.owed.amount * 2 then return false, "You can't cover double" end
    g.offer = { from = me, at = GetTime() }
    Tell(g, "O", g.id)
    self:Changed()
    return true
end

local function BeginDouble(self, g)
    g.round = g.round + 1
    g.offer = nil
    g.cur, g.turn, g.state = g.start, g.owed.from, "play"
    g.hp = { [g.a] = g.start, [g.b] = g.start }
    g.winner, g.loser, g.rolledAt = nil, nil, nil
    g.last = GetTime()
end

function D:AnswerDouble(yes)
    local g = self.game
    local me = Me()
    if not (g and g.state == "over" and g.offer and g.offer.from ~= me) then return end
    local opp = Other(g, me)
    if yes then
        Tell(g, "Y", g.id)
        BeginDouble(self, g)
        if self.onOpen then self.onOpen() end
        if self.onRound then self.onRound(g) end
    else
        g.offer = nil
        Tell(g, "N", g.id)
    end
    self:Changed()
end

-- give up mid-roll: you take the loss
function D:Forfeit()
    local g = self.game
    local me = Me()
    if not g then return end
    if g.state == "pending" then
        Tell(g, "X", g.id)
        self.game = nil
    elseif g.state == "play" then
        Tell(g, "F", g.id)
        Broadcast("E", g.id, Short(g.name[me]))
        self:Concede(g, me)
    end
    self:Changed()
end

function D:Concede(g, who)
    g.cur = 1
    local e = Apply(g, who, 1, true)
    e.forfeit = true
    self:Record(g, e)
    if self.onRoll then self.onRoll(g, e, true) end
end

-- finished: clear the table (the debt stays in the ledger until it is paid)
function D:Done()
    local g = self.game
    if g and g.state == "over" then self.game = nil; self:Changed() end
end

---------------------------------------------------------------------------
-- Paying up. An addon can't hand over gold: this opens the trade and fills in the amount; you press Trade.
---------------------------------------------------------------------------
function D:PayUp(full, copper)
    local unit = D.UnitFor(full)
    if not unit or unit == "player" then return false, ("Target %s or group with them to trade"):format(Short(full)) end
    if CheckInteractDistance then
        local ok, near = pcall(CheckInteractDistance, unit, 2)
        if ok and near == false then return false, ("Stand next to %s to trade"):format(Short(full)) end
    end
    self.pay = { key = Key(full), copper = copper, at = GetTime() }
    if InitiateTrade then InitiateTrade(unit) end
    return true
end

function D:OnTradeShow()
    local n, r = UnitName("NPC")
    self.trade = { key = n and Key(r and r ~= "" and (n .. "-" .. r) or n), name = n, mine = 0, theirs = 0 }
    local p = self.pay
    if p and self.trade.key == p.key and GetTime() - p.at < 30 then
        if TradePlayerInputMoneyFrame and MoneyInputFrame_SetCopper then pcall(MoneyInputFrame_SetCopper, TradePlayerInputMoneyFrame, p.copper)
        elseif SetTradeMoney then pcall(SetTradeMoney, p.copper) end
    end
    self.pay = nil
end

function D:OnTradeMoney()
    local t = self.trade
    if not t then return end
    t.mine = (GetPlayerTradeMoney and tonumber(GetPlayerTradeMoney())) or t.mine
    t.theirs = (GetTargetTradeMoney and tonumber(GetTargetTradeMoney())) or t.theirs
end

-- a trade went through: gold that changed hands with someone in the ledger pays down what is owed
function D:OnTradeDone()
    local t = self.trade
    self.trade = nil
    if not (t and t.key) then return end
    local led = self.db.ledger[t.key]
    if not led or led.owe == 0 then return end
    local before = led.owe
    if led.owe < 0 and t.mine > 0 then led.owe = min(0, led.owe + t.mine)
    elseif led.owe > 0 and t.theirs > 0 then led.owe = max(0, led.owe - t.theirs) end
    if led.owe ~= before then
        NS.Print(led.owe == 0 and ("Death Roll debt with %s is settled."):format(Short(led.name))
            or ("Death Roll: %s still owed %s %s."):format(D.Money(math.abs(led.owe)), led.owe > 0 and "by" or "to", Short(led.name)))
        local g = self.game
        if g and g.owed and Key(g.name[Other(g, Me())]) == t.key then g.owed.paid = (led.owe == 0) end
        self:Changed()
    end
end

function D:OnTradeClosed()
    if self.trade then self.trade.closedAt = GetTime() end
end

function D:Forgive(key)
    local led = self.db.ledger[key]
    if led then led.owe = 0; self:Changed() end
end

---------------------------------------------------------------------------
-- Incoming
---------------------------------------------------------------------------
local function num(s, lo, hi)
    local v = tonumber(s)
    if not v or v ~= v or v < lo or v > hi or v ~= floor(v) then return nil end
    return v
end
local CLASSES = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1,
                  DEATHKNIGHT = 1, MONK = 1, DEMONHUNTER = 1, EVOKER = 1 }
local function cls(s) return CLASSES[s or ""] and s or "WARRIOR" end

function D:OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local raw = sender       -- exactly as the server wrote them
    sender = Norm(sender)
    if not sender then return end
    local skey = Key(sender)
    local me = Me()
    if skey == me then return end
    Log("in ", channel, raw, text)
    local a = { strsplit(",", text) }
    local cmd, id = a[1], a[2]
    if not cmd or not id then return end
    local g = self.game

    -- what the sender's character looks like: from my opponent, from whoever is challenging me, or
    -- (on the guild or group channel) from the players of a death roll I can watch
    if cmd == "L" then
        local mine = g and g.id == id and From(g, skey, sender, cmd)
        local known = mine or (g and (skey == g.a or skey == g.b)) or (self.invite and Same(self.invite.from, sender))
        if not known and channel ~= "WHISPER" then
            for _, w in pairs(self.watch) do if skey == w.a or skey == w.b then known = true end end
        end
        -- (my opponent's look is kept under the name my game knows them by)
        if known or self:Trusted(sender) then self:StoreLook(mine or skey, sender, a[3], a[4], a[5]) end
        return
    end

    if channel ~= "WHISPER" then
        -- News of my own game heard on the guild or group channel is the same news as the whisper,
        -- in case that was lost: "I accept" and each roll. Anything else there is somebody else's game.
        if not (g and g.id == id) then return self:OnWatch(cmd, id, a, sender, skey) end
        if cmd == "R" then a = { "R", id, a[3], a[5], a[6] }      -- (said aloud, a roll names its roller)
        elseif cmd ~= "A" then return end
    end

    if cmd == "C" then
        local wager, start = num(a[3], 0, 1e11), num(a[4], 2, 1000000)
        if not wager or not start then return end
        if not self:Trusted(sender) then
            self.blocked = self.blocked or {}
            if (self.blocked[skey] or 0) < GetTime() - 60 then
                self.blocked[skey] = GetTime()
                NS.Print(("%s tried to challenge you to a Death Roll. Group up or add them as a friend to play."):format(Short(sender)))
            end
            return Reply({ sender, raw }, "D", id, "private")
        end
        if self:Busy() then return Reply({ sender, raw }, "D", id, "busy") end
        if self.invite and not Same(self.invite.from, sender) then Reply({ self.invite.from, self.invite.raw }, "D", self.invite.id, "busy") end
        self.invite = { id = id, from = sender, raw = raw, wager = wager, start = start, class = cls(a[5]), at = GetTime() }
        local detail = (wager > 0 and ("Wager: " .. D.Money(wager)) or "No wager, just for glory") .. ("\nRolling from %s"):format(NS.W.Commas(start))
        if self.onInvite then self.onInvite(self.invite) end
        if StaticPopup_Show then StaticPopup_Show("FLIGHTBUDDY_DR_INVITE", Short(sender), detail)
        else NS.Print(("%s challenges you to a Death Roll (%s). Type /deathroll accept."):format(Short(sender), detail:gsub("\n", ", "))) end
        return
    end
    if cmd == "X" then
        if self.invite and self.invite.id == id and Same(self.invite.from, sender) then
            self.invite = nil
            if StaticPopup_Hide then StaticPopup_Hide("FLIGHTBUDDY_DR_INVITE") end
        end
        return
    end
    if not g or g.id ~= id then return end
    local from = From(g, skey, sender, cmd)
    if not from or from == me then return end
    skey = from
    g.name[from] = sender       -- as the server writes them
    g.wire = g.wire or {}
    g.wire[from] = raw
    g.ackWait = nil   -- anything from my opponent about this game means theirs is running
    if cmd == "K" then return end

    if cmd == "A" then
        if skey == g.b then Tell(g, "K", id) end   -- heard you (an accept said twice is answered twice)
        if g.state == "pending" and skey == g.b then
            g.class[g.b] = cls(a[3])
            g.state, g.began, g.last = "play", GetTime(), GetTime()
            StartRound(self, g)
            if self.onOpen then self.onOpen() end
            if self.onRound then self.onRound(g) end
            self:Changed()
        end
    elseif cmd == "D" then
        if g.state == "pending" and skey == g.b then
            local why = a[3]
            self.game = nil
            NS.Print(("%s %s."):format(Short(sender), why == "busy" and "is busy in another Death Roll" or why == "private"
                and "only takes challenges from friends, guild or group" or why == "poor" and "can't cover that wager" or "declined your Death Roll"))
            if self.onDeclined then self.onDeclined(sender, why) end
            self:Changed()
        end
    elseif cmd == "R" then
        local seq, roll, maxv = num(a[3], 1, 9999), num(a[4], 1, 1000000), num(a[5], 1, 1000000)
        if not (seq and roll and maxv) then return end
        if seq == g.seq + 1 then
            self:TakeRoll(skey, roll, maxv, false)
        end
    elseif cmd == "O" then
        if g.state == "over" and g.owed and g.owed.amount > 0 and g.owed.from == skey and not g.offer then
            g.offer = { from = skey, at = GetTime() }
            local detail = ("%s owes you %s.\nWin and it's %s. Lose and the debt is wiped."):format(Short(sender), D.Money(g.owed.amount), D.Money(g.owed.amount * 2))
            if StaticPopup_Show then StaticPopup_Show("FLIGHTBUDDY_DR_DOUBLE", Short(sender), detail) end
            if self.onOpen then self.onOpen() end
            self:Changed()
        end
    elseif cmd == "Y" then
        if g.state == "over" and g.offer and g.offer.from == me then
            BeginDouble(self, g)
            StartRound(self, g)
            if self.onRound then self.onRound(g) end
            self:Changed()
        end
    elseif cmd == "N" then
        if g.state == "over" and g.offer and g.offer.from == me then
            g.offer = nil
            g.refused = true
            if self.onDeclined then self.onDeclined(sender, "double") end
            self:Changed()
        end
    elseif cmd == "F" then
        if g.state == "play" then
            self:Concede(g, skey)
            self:Changed()
        end
    end
end

-- someone else's death roll, heard on the guild or group channel
function D:OnWatch(cmd, id, a, sender, skey)
    local mine = self.game
    if mine and mine.id == id then return end
    if cmd == "G" then
        local aN, bN = Norm(a[3]), Norm(a[4])
        local stake, start, round = num(a[7], 0, 1e12), num(a[8], 2, 1000000), num(a[9], 1, 99)
        if not (aN and bN and stake and start and round) then return end
        if skey ~= Key(aN) and skey ~= Key(bN) then return end
        if Key(aN) == Me() or Key(bN) == Me() then return end
        local w = self.watch[id]
        local fresh = not w or w.round ~= round
        if not fresh then return end
        w = NewGame(id, aN, bN, cls(a[5]), cls(a[6]), stake, start)
        w.round, w.watching = round, true
        local first = Key(Norm(a[10]))
        if first == w.a or first == w.b then w.turn = first end
        w.seq = num(a[11], 0, 9999) or 0   -- roll numbers carry on across double-or-nothing rounds
        self.watch[id] = w
        self.watchLatest = id
        -- keep the list small
        local n = 0
        for _ in pairs(self.watch) do n = n + 1 end
        if n > 6 then
            local oldK, oldT
            for k, v in pairs(self.watch) do if k ~= id and (not oldT or v.last < oldT) then oldK, oldT = k, v.last end end
            if oldK then self.watch[oldK] = nil end
        end
        if self.db.notify and self.onNotice then self.onNotice(w) end
        self:Changed()
    elseif cmd == "R" then
        local w = self.watch[id]
        local seq, roll, maxv = num(a[3], 1, 9999), num(a[5], 1, 1000000), num(a[6], 1, 1000000)
        if not (w and seq and roll and maxv) or w.state ~= "play" then return end
        if skey ~= w.turn or seq ~= w.seq + 1 or maxv ~= w.cur or roll > w.cur then return end
        local e = Apply(w, skey, roll, false)
        if self.onRoll then self.onRoll(w, e, false) end
        self:Changed()
    elseif cmd == "E" then
        local w = self.watch[id]
        if w and w.state == "play" and (skey == w.a or skey == w.b) then
            w.cur = 1
            local e = Apply(w, skey, 1, false)
            e.forfeit = true
            if self.onRoll then self.onRoll(w, e, false) end
            self:Changed()
        end
    end
end

-- the system line "Name rolls 437 (1-1000)"
function D:OnSystem(text)
    local g = self.game
    if not (g and g.state == "play") or type(text) ~= "string" then return end
    local who, roll, lo, hi = text:match(self.rollPattern)
    roll, lo, hi = tonumber(roll), tonumber(lo), tonumber(hi)
    if not (who and roll and lo and hi) then return end
    local key = Key(who)
    local turnShort = Short(g.name[g.turn]):lower()
    if key ~= g.turn and who:lower() ~= turnShort then
        -- was it the roll my opponent's addon already reported? Then it is confirmed.
        local last = g.hist[#g.hist]
        if last and not last.verified and last.roll == roll and last.max == hi and (key == last.who or who:lower() == Short(g.name[last.who]):lower()) then
            last.verified = true
            self:Changed()
        end
        return
    end
    if lo ~= 1 or hi ~= g.cur then
        if g.turn == Me() then NS.Print(("Death Roll: that roll doesn't count. Roll 1-%d."):format(g.cur)) end
        return
    end
    self:TakeRoll(g.turn, roll, hi, true)
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
function D:Pump(el)
    sendAcc = sendAcc + el
    if sendAcc >= 0.12 and #queue > 0 then
        sendAcc = 0
        local q = table.remove(queue, 1)
        Log("out", q[2], q[3], q[1])
        NS.Social.Deliver(PREFIX, q[1], q[2], q[3])
    end
    local now = GetTime()
    if self.trade and self.trade.closedAt and now - self.trade.closedAt > 3 then self.trade = nil end
    if self.invite and now - self.invite.at > INVITE_SECS then self.invite = nil end
    local g = self.game
    if g and g.ackWait and now - g.ackWait.at > 4 then
        -- my accept has not been acknowledged: say it again, three times at most
        if g.ackWait.n < 3 and g.state == "play" and g.seq == 0 then
            g.ackWait.n, g.ackWait.at = g.ackWait.n + 1, now
            Tell(g, "A", g.id, MyClass(), Version())
            Broadcast("A", g.id, MyClass(), Version())
        else
            g.ackWait = nil
        end
    end
    if g then
        if g.state == "pending" and not g.nudged and now - g.sentAt > 20 then
            g.nudged = true
            NS.Print(("No answer from %s yet. If they have already accepted on their screen, their Flight Buddy is older than yours and its answer is not getting through: they need the same version you have."):format(Short(g.name[g.b])))
        end
        if g.state == "pending" and now - g.sentAt > INVITE_SECS then
            self.game = nil
            NS.Print(("%s didn't answer your Death Roll."):format(Short(g.name[g.b])))
            self:Changed()
        elseif g.state == "over" and g.offer and now - g.offer.at > INVITE_SECS then
            g.offer = nil
            self:Changed()
        end
    end
end

-- /deathroll debug: what this game knows and the last messages in and out, to copy into a bug report
function D:Debug()
    local S = NS.Social
    NS.Print(("Death Roll debug. Flight Buddy %s. I am \"%s\"; the client calls my realm \"%s\"; the server has written it: %s"):format(
        Version(), tostring(UnitName and UnitName("player")), MyRealm(), (S.RealmSpellings and S.RealmSpellings()) or "?"))
    local g = self.game
    if g then
        NS.Print(("  game %s: %s, %s (a) against %s (b), sent to \"%s\""):format(g.id, g.state, tostring(g.name[g.a]), tostring(g.name[g.b]), tostring(g.to or "-")))
    else
        NS.Print("  no game" .. (self.invite and (", an invitation from " .. tostring(self.invite.raw)) or ""))
    end
    if #wireLog == 0 then NS.Print("  no Death Roll messages yet this session") end
    for _, l in ipairs(wireLog) do NS.Print("  " .. l) end
end

-- /deathroll Name 50 (gold), /deathroll accept, /deathroll
function D:Slash(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local lc = (cmd or ""):lower()
    if lc == "accept" then self:Accept(); return end
    if lc == "decline" then self:Decline(); return end
    if lc == "look" then if self.onLookTest then self.onLookTest() end; return end
    if lc == "debug" then return self:Debug() end
    if lc ~= "" then
        -- "Name [gold]" or "First Last [gold]"
        local whole = (msg or ""):match("^%s*(.-)%s*$")
        local nm, gold = whole:match("^(.-)%s+(%d+)$")
        if not nm then nm, gold = whole, nil end
        local ok, why = self:Challenge(nm, (tonumber(gold) or 0) * COPPER_PER_GOLD, self.db.start)
        if ok then NS.Print("Death Roll challenge sent to " .. nm .. ".") elseif why then NS.Print(why .. ".") end
    end
    if self.onOpen then self.onOpen(true) end
end
