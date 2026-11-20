-- Flight Buddy :: Social.lua
-- Leaderboards shared with your friends, guild, group and (optionally) everyone on your realm who
-- runs Flight Buddy, via hidden addon messages. Two periods per game: today ("YYYYMMDD") and all-time ("all").
-- Wire format (";"-separated, never shown in chat):
--   1;R;<game>;<period>;<score>;<detail>   a result
--   1;Q;<game>;<period>                    "send me your result for this board"
--   1;T;<game>;<period>;<score>;<detail>;<name>   a result you heard from someone else (realm boards only:
--                                          lets a newcomer see the realm's top scores without waiting for everyone)
local ADDON, NS = ...

local Social = {}
NS.Social = Social

local PREFIX = "FlightBuddy"
local VERSION = "1"
local REALM_CHANNEL = "FlightBuddyLB"
-- games and which way is better (putt is a time: lower wins; the rest are scores)
Social.GAMES = {
    putt = "low", words = "low",
    rb = "high", flap = "high", flapd = "high", pin = "high", tram = "high",
    gem = "high", gemd = "high", gemw = "high",
}
-- Gryphon Greens quick rounds: one board per course (best time, lower wins)
for _, k in ipairs({ "human", "dwarf", "gnome", "nelf", "orc", "troll", "undead", "mulgore", "arathi", "tour" }) do
    Social.GAMES["pq_" .. k] = "low"
end
-- every flight path route has its own Gryphon Greens board: "rt_" + six hex digits (best time, lower wins)
setmetatable(Social.GAMES, { __index = function(_, k)
    if type(k) == "string" and k:match("^rt_%x%x%x%x%x%x$") then return "low" end
end })
local GAMES = Social.GAMES

local queue, sendAcc = {}, 0
Social.listeners = {}
local lastQuery = {}
local lastRealmReply = 0
local lastGossip = 0

local function Now() return (GetServerTime and GetServerTime()) or time() end

-- Dailies turn over with the realm's daily quest reset, so everyone on the realm plays (and
-- ranks on) the same day whatever their time zone. The day is named by the UTC date of the
-- reset that started it. Falls back to your local midnight if the reset time isn't known.
local function ResetIn()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local ok, s = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
        if ok and type(s) == "number" and s > 0 and s <= 86400 then return s end
    end
    if GetQuestResetTime then
        local ok, s = pcall(GetQuestResetTime)
        if ok and type(s) == "number" and s > 0 and s <= 86400 then return s end
    end
    return nil
end

function Social.Today(offsetDays)
    local off = (offsetDays or 0) * 86400
    local r = ResetIn()
    if r then
        -- start of the current game day, snapped to the half hour the reset happens on
        local start = Now() + r - 86400
        start = math.floor((start + 900) / 1800) * 1800
        return date("!%Y%m%d", start + off)
    end
    return date("%Y%m%d", time() + off)
end

function Social.SecondsToReset()
    local r = ResetIn()
    if r then return r end
    local t = date("*t")
    return 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
end

local function MyRealm() return (GetNormalizedRealmName and GetNormalizedRealmName()) or "" end

function Social.Me()
    local name = UnitName("player") or "?"
    local realm = MyRealm()
    return realm ~= "" and (name .. "-" .. realm) or name
end

-- senders arrive as "Name-Realm" or, from your own realm on some clients, just "Name":
-- always store and compare the full form so nobody (you included) appears twice
local function Full(name)
    if type(name) ~= "string" or name == "" then return name end
    if name:find("-", 1, true) then return name end
    local realm = MyRealm()
    return realm ~= "" and (name .. "-" .. realm) or name
end
Social.Full = Full

local function Short(full)
    if Ambiguate then return Ambiguate(full, "none") end
    return (full:gsub("%-.*$", ""))
end
Social.Short = Short

function Social:Init(db)
    self.db = db
    db.boards = db.boards or {}
    -- keep a week of daily history (all-time boards stay)
    local cutoff = Social.Today(-8)
    for game, days in pairs(db.boards) do
        for day in pairs(days) do
            if day ~= "all" and day < cutoff then days[day] = nil end
        end
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    self.joinAt = 12   -- join the realm channel a little after login, once chat is ready
end

---------------------------------------------------------------------------
-- The realm channel: a hidden custom channel every Flight Buddy player joins
---------------------------------------------------------------------------
function Social:RealmEnabled()
    return self.db and self.db.settings and self.db.settings.realmBoards ~= false
end

function Social:RealmChannel()
    if not GetChannelName then return nil end
    local id = GetChannelName(REALM_CHANNEL)
    if id and id > 0 then return id end
    return nil
end

function Social:JoinRealm()
    if not self:RealmEnabled() or not JoinTemporaryChannel then return end
    if self:RealmChannel() then return end
    pcall(JoinTemporaryChannel, REALM_CHANNEL)
    -- keep it out of every chat window: it only carries hidden addon messages
    if ChatFrame_RemoveChannel then
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local cf = _G["ChatFrame" .. i]
            if cf then pcall(ChatFrame_RemoveChannel, cf, REALM_CHANNEL) end
        end
    end
end

function Social:LeaveRealm()
    if LeaveChannelByName and self:RealmChannel() then pcall(LeaveChannelByName, REALM_CHANNEL) end
end

local function Send(msg, chatType, target)
    queue[#queue + 1] = { msg, chatType, target }
end

-- every place our results should go
local function Broadcast(msg)
    if IsInGuild and IsInGuild() then Send(msg, "GUILD") end
    if IsInRaid and IsInRaid() then Send(msg, "RAID")
    elseif IsInGroup and IsInGroup() then Send(msg, "PARTY") end
    if C_FriendList and C_FriendList.GetNumFriends then
        local n = 0
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected and info.name then
                Send(msg, "WHISPER", info.name)
                n = n + 1
                if n >= 25 then break end
            end
        end
    end
    local ch = Social:RealmChannel()
    if ch and Social:RealmEnabled() then Send(msg, "CHANNEL", ch) end
end

-- call every frame (from the core driver frame)
function Social:Pump(el)
    if self.joinAt then
        self.joinAt = self.joinAt - el
        if self.joinAt <= 0 then self.joinAt = nil; self:JoinRealm() end
    end
    sendAcc = sendAcc + el
    if sendAcc < 0.3 or #queue == 0 then return end
    sendAcc = 0
    local m = table.remove(queue, 1)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, m[1], m[2], m[3])
    end
end

local function Better(game, a, b)   -- is score a better than b?
    if GAMES[game] == "high" then return a > b end
    return a < b
end
Social.Better = Better

function Social:Store(game, day, who, score, detail, src, relayed)
    local b = self.db.boards
    b[game] = b[game] or {}
    b[game][day] = b[game][day] or {}
    local cur = b[game][day][who]
    -- second-hand results never replace what we heard from the player themselves (or our own)
    if relayed and cur and not cur.r then return end
    if cur and cur.r and not relayed then cur = nil end
    if cur and not Better(game, score, cur.s) then
        -- same or worse score: just remember the closest way we know them
        if src and src ~= "realm" and cur.src == "realm" then cur.src = src end
        return
    end
    local keepSrc = cur and cur.src
    if keepSrc and keepSrc ~= "realm" and src == "realm" then src = keepSrc end
    b[game][day][who] = { s = score, d = detail, src = src, r = relayed or nil, t = time and time() or nil }
    for _, fn in ipairs(Social.listeners) do fn(game, day) end
end

function Social:Submit(game, day, score, detail)
    if GAMES[game] == "low" then score = math.floor(score * 10 + 0.5) / 10 else score = math.floor(score) end
    self:Store(game, day, Social.Me(), score, detail, "me")
    if self.db.settings and self.db.settings.share == false then return end
    Broadcast(table.concat({ VERSION, "R", game, day, score, detail or "" }, ";"))
end

-- a score for today's board and the all-time board
function Social:SubmitBest(game, score, detail)
    self:Submit(game, Social.Today(), score, detail)
    local mine = self:Mine(game, "all")
    if not mine or Better(game, score, mine.s) then self:Submit(game, "all", score, detail) end
end

function Social:Query(game, day)
    local k = game .. day
    local now = GetTime()
    if lastQuery[k] and now - lastQuery[k] < 90 then return end
    lastQuery[k] = now
    Broadcast(table.concat({ VERSION, "Q", game, day }, ";"))
end

function Social:Mine(game, day)
    local b = self.db.boards[game]
    return b and b[day] and b[day][Social.Me()]
end

local function ValidDay(day)
    if day == "all" then return true end
    if not day or not day:match("^%d%d%d%d%d%d%d%d$") then return false end
    return day >= Social.Today(-1) and day <= Social.Today(1)
end

function Social:OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local v, kind, game, day, score, detail, name = strsplit(";", text)
    if v ~= VERSION or not GAMES[game] or not ValidDay(day) then return end
    sender = Full(sender)
    if not sender then return end
    -- a whisper is from a friend only if they're on your friends list: replies to a realm-wide
    -- question also arrive as whispers, from people you don't know
    local src = (channel == "GUILD" and "guild") or ((channel == "PARTY" or channel == "RAID") and "group")
        or (channel == "CHANNEL" and "realm")
        or ((channel == "WHISPER" and self:IsFriend(sender)) and "friend") or "realm"
    if kind == "R" then
        local s = tonumber(score)
        if not s or s < 0 or s > 1e9 then return end
        if sender == Social.Me() then return end
        self:Store(game, day, sender, s, (detail or ""):sub(1, 24), src)
    elseif kind == "T" then
        -- a realm player passing on a score they heard: realm board only, never about us
        local s = tonumber(score)
        if not s or s < 0 or s > 1e9 or channel ~= "WHISPER" then return end
        -- names can have a space ("First Last-Realm"); realms are sent without spaces
        if type(name) ~= "string" or #name > 48 or not name:match("^[^%-;]+%-[^%s;%-]+$") then return end
        if name == Social.Me() or name == sender then return end
        self:Store(game, day, name, s, (detail or ""):sub(1, 24), "realm", true)
    elseif kind == "Q" then
        if sender == Social.Me() then return end
        local mine = self:Mine(game, day)
        if mine then
            if src == "realm" then
                -- a whole realm can ask at once: answer at most every 20 seconds
                local now = GetTime()
                if now - lastRealmReply < 20 then return end
                lastRealmReply = now
            end
            local msg = table.concat({ VERSION, "R", game, day, mine.s, mine.d or "" }, ";")
            local delay = 0.5 + math.random() * 4
            if C_Timer and C_Timer.After then
                C_Timer.After(delay, function() Send(msg, "WHISPER", sender) end)
            else
                Send(msg, "WHISPER", sender)
            end
        end
        -- on the realm channel, the first few players to answer also pass on the top of their
        -- board, so someone opening the realm board for the first time sees a full table
        if src == "realm" and mine then
            local now = GetTime()
            if now - lastGossip >= 30 then
                lastGossip = now
                local n = 0
                for _, e in ipairs(self:Board(game, day, "realm")) do
                    if not e.me and e.name ~= sender then
                        local msg = table.concat({ VERSION, "T", game, day, e.s, e.d or "", e.name }, ";")
                        local delay = 1 + math.random() * 5 + n * 0.4
                        if C_Timer and C_Timer.After then
                            C_Timer.After(delay, function() Send(msg, "WHISPER", sender) end)
                        else
                            Send(msg, "WHISPER", sender)
                        end
                        n = n + 1
                        if n >= 8 then break end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Who's who: your friends list and guild roster, checked live so a guildmate who is
-- also your friend shows on both boards (however their score reached you)
---------------------------------------------------------------------------
local friendSet, guildSet, setsAt = {}, {}, -100
local function Key(name) return (Short(name) or name):lower() end

function Social:RefreshPeople(force)
    local now = GetTime and GetTime() or 0
    if not force and now - setsAt < 15 then return end
    setsAt = now
    friendSet, guildSet = {}, {}
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name then friendSet[Key(info.name)] = true; friendSet[info.name:lower()] = true end
        end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
        for i = 1, GetNumGuildMembers() or 0 do
            local name = GetGuildRosterInfo(i)
            if name then guildSet[Key(name)] = true; guildSet[name:lower()] = true end
        end
    end
end

function Social:IsFriend(who)
    self:RefreshPeople()
    return friendSet[who:lower()] or friendSet[Key(who)] or false
end
function Social:IsGuildmate(who)
    self:RefreshPeople()
    return guildSet[who:lower()] or guildSet[Key(who)] or false
end

-- sorted list for display: { {name=, short=, s=, d=, me=bool, src=} }
-- filter: nil/"all"/"realm" (everyone you've heard from), "friend", "guild", "group" (you always appear)
function Social:Board(game, day, filter)
    local out = {}
    local b = self.db.boards[game]
    local me = Social.Me()
    if filter == "friend" or filter == "guild" then self:RefreshPeople() end
    for who, e in pairs((b and b[day]) or {}) do
        local mine = who == me
        local keep = mine or not filter or filter == "all" or filter == "realm"
        -- friends and guild go by who they are now (your friends list and guild roster), not by
        -- how their score happened to reach you
        if not keep and filter == "friend" then keep = self:IsFriend(who) end
        if not keep and filter == "guild" then keep = (e.src == "guild") or self:IsGuildmate(who) end
        if not keep and filter == "group" then keep = e.src == "group" end
        if keep then
            out[#out + 1] = { name = who, short = Short(who), s = e.s, d = e.d, src = e.src, me = mine }
        end
    end
    local high = GAMES[game] == "high"
    table.sort(out, function(a, c)
        if a.s ~= c.s then if high then return a.s > c.s end return a.s < c.s end
        return a.name < c.name
    end)
    return out
end

function Social:Rank(game, day, filter)
    local list = self:Board(game, day, filter)
    for i, e in ipairs(list) do if e.me then return i, #list end end
    return nil, #list
end

-- "Friends #2 of 5   Guild #1 of 9   Realm #14 of 60" for a menu (nil if you have no score yet)
function Social:RankLine(game, day)
    if not self:Mine(game, day) then return nil end
    local parts = {}
    for _, f in ipairs({ { "friend", "Friends" }, { "guild", "Guild" }, { "realm", "Realm" } }) do
        local rk, n = self:Rank(game, day, f[1])
        if rk and n > 1 then parts[#parts + 1] = ("%s |cffffcc40#%d|r of %d"):format(f[2], rk, n) end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "     ")
end
