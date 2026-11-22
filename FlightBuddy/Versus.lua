-- Flight Buddy: Versus. Live mini golf against other players, with no server.
-- Everyone plays the same course at the same time. Each shot crosses as one small hidden addon
-- message (where the ball was, how it was hit, and the hole clock), and every other client replays
-- it on its own copy of the hole, so you watch the other balls roll as ghosts.
local _, NS = ...
local V = {}
NS.Versus = V

local floor, min, max = math.floor, math.min, math.max
local PREFIX = "FBVS"
local PROTO = "1"
local MAX_PLAYERS = 4
local INVITE_SECS = 60
V.COLORS = { { 0.40, 0.78, 1.00 }, { 1.00, 0.50, 0.42 }, { 0.80, 0.55, 1.00 }, { 1.00, 0.82, 0.30 } }
V.LENGTHS = { 3, 6 }

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
V.Short = Short
local function MeName()
    local n = UnitName and UnitName("player")
    return Norm(n or "Player")
end
-- players are keyed without regard to case, so "bob" typed in chat and "Bob" on the wire are one person
local function Key(name) name = Norm(name); return name and name:lower() end
local function Me() return Key(MeName()) end

---------------------------------------------------------------------------
-- Wire
---------------------------------------------------------------------------
local function Raw(text, chatType, target)
    queue[#queue + 1] = { text, chatType, target }
end
local function Whisper(name, ...)
    Raw(table.concat({ ... }, ","), "WHISPER", Short(name))
end

function V:SendAll(...)
    local m = self.match
    if not m then return end
    local text = table.concat({ ... }, ",")
    for _, name in ipairs(m.order) do
        local p = m.players[name]
        if name ~= m.me and not p.left then Raw(text, "WHISPER", Short(p.name)) end
    end
end

function V:Init(db)
    self.db = db
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    if StaticPopupDialogs then
        StaticPopupDialogs["FLIGHTBUDDY_VS_INVITE"] = {
            text = "%s challenges you to mini golf.\n%s",
            button1 = ACCEPT or "Accept", button2 = DECLINE or "Decline",
            OnAccept = function() V:Accept() end,
            OnCancel = function() V:Decline() end,
            timeout = INVITE_SECS, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopupDialogs["FLIGHTBUDDY_VS_NAME"] = {
            text = "Challenge who? Type a character name.",
            button1 = "Invite", button2 = CANCEL or "Cancel", hasEditBox = true, maxLetters = 48,
            OnAccept = function(popup)
                local eb = popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
                local name = eb and eb:GetText()
                if name and name:match("%S") then V:Invite(name) end
            end,
            EditBoxOnEnterPressed = function(eb)
                local name = eb:GetText()
                if name and name:match("%S") then V:Invite(name) end
                eb:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
end

function V:Changed() if self.onChange then self.onChange() end end

---------------------------------------------------------------------------
-- The course both sides build from the same seed
---------------------------------------------------------------------------
function V.BuildCourse(key, seed, len)
    local Putt = NS.Putt
    if not (NS.PuttCourses and NS.PuttCourses[key]) then return nil end
    local c = Putt.MakeCourse("versus", seed, key)
    if not c or not c.holes or #c.holes == 0 then return nil end
    len = max(1, min(len or #c.holes, #c.holes))
    local holes, par = {}, 0
    for i = 1, len do holes[i] = c.holes[i]; par = par + holes[i].par end
    c.holes, c.par, c.kind = holes, par, "versus"
    return c
end

-- a number both clients must agree on before a match starts (different versions build different holes)
function V.Fingerprint(c)
    local s = 17 + NS.Putt.C.REV * 7919      -- (and the same rules for how a ball rolls)
    for _, h in ipairs(c.holes) do
        s = (s * 31 + h.par * 7 + floor(h.tee.x) + floor(h.tee.y) * 3 + floor(h.cup.x) * 5 + floor(h.cup.y) * 11
            + #(h.movers or {}) * 13 + #(h.actors or {}) * 19 + #(h.walls or {}) * 23 + #(h.bumpers or {}) * 29 + #(h.surface or {}) * 37 + floor(h.surf and (h.surf.hi - h.surf.lo) or 0) % 9973 * 41) % 1000003
    end
    return s
end

function V:CourseKeys()
    local out = {}
    for _, k in ipairs(NS.Putt.COURSE_ORDER) do if NS.PuttCourses[k] then out[#out + 1] = k end end
    if NS.PuttCourses.arathi then out[#out + 1] = "arathi" end
    return out
end

---------------------------------------------------------------------------
-- Match bookkeeping
---------------------------------------------------------------------------
local function AddPlayer(m, full, status)
    local name = Key(full)
    if m.players[name] then return m.players[name] end
    local p = { key = name, name = full, short = Short(full), status = status, hole = 0, total = 0, strokes = 0, seen = GetTime() }
    m.players[name] = p
    m.order[#m.order + 1] = name
    p.color = V.COLORS[((#m.order - 1) % #V.COLORS) + 1]
    return p
end

function V:Busy()
    local m = self.match
    return m and (m.state == "count" or m.state == "play")
end

-- host: open a lobby (or change its settings while nobody has joined yet)
function V:Host(key, len)
    local m = self.match
    if m and m.host == Me() and m.state == "lobby" then
        if key then m.key = key end
        if len then m.len = len end
        m.seed = (time() % 100000) * 7 + floor(GetTime() * 100) % 97
        self:Changed()
        return m
    end
    if m then self:Leave() end
    local keys = self:CourseKeys()
    local me = Me()
    m = { id = (Short(MeName()):gsub("[,;%s]", "")):sub(1, 12) .. ":" .. (time() % 100000), host = me, me = me, state = "lobby",
          key = key or keys[math.random(1, #keys)], len = len or (self.db and self.db.vsLen) or 3,
          seed = (time() % 100000) * 7 + floor(GetTime() * 100) % 97, players = {}, order = {} }
    AddPlayer(m, MeName(), "ready")
    self.match = m
    self:Changed()
    return m
end

function V:InviteText(m)
    local c = V.BuildCourse(m.key, m.seed, m.len)
    if not c then return nil end
    return table.concat({ "I", m.id, PROTO, m.key, m.seed, m.len, V.Fingerprint(c) }, ",")
end

function V:Invite(name)
    name = Norm(name and name:match("^%s*(.-)%s*$"))
    if not name or Key(name) == Me() then return false end
    local m = self.match
    if not (m and m.host == Me() and m.state == "lobby") then
        if self:Busy() then return false end
        m = self:Host()
    end
    if #m.order >= MAX_PLAYERS and not m.players[Key(name)] then
        NS.Print("A match holds up to " .. MAX_PLAYERS .. " players.")
        return false
    end
    local text = self:InviteText(m)
    if not text then return false end
    local p = AddPlayer(m, name, "invited")
    if p.status ~= "ready" then p.status, p.invitedAt = "invited", GetTime() end
    Raw(text, "WHISPER", Short(name))
    self:Changed()
    return true
end

function V:InviteParty()
    if not (IsInGroup and IsInGroup()) then return false end
    local n = 0
    local raid = IsInRaid and IsInRaid()
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        if UnitExists and UnitExists(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
            local nm, realm = UnitName(unit)
            if nm and nm ~= (UNKNOWNOBJECT or "Unknown") then
                if self:Invite(realm and realm ~= "" and (nm .. "-" .. realm) or nm) then n = n + 1 end
            end
        end
    end
    return n > 0
end

function V:InviteTarget()
    if not (UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")) then return false end
    local nm, realm = UnitName("target")
    if not nm then return false end
    return self:Invite(realm and realm ~= "" and (nm .. "-" .. realm) or nm)
end

function V:AskName()
    if StaticPopup_Show then StaticPopup_Show("FLIGHTBUDDY_VS_NAME") else NS.Print("Type /fb vs Name to challenge someone.") end
end

-- who may put a challenge on your screen: people you are grouped with, friends and guildmates
function V:Trusted(sender)
    if self.db and self.db.vsAnyone then return true end
    local short = Short(sender)
    if (UnitInParty and UnitInParty(short)) or (UnitInRaid and UnitInRaid(short)) then return true end
    local S = NS.Social
    if S and ((S.IsFriend and S:IsFriend(sender)) or (S.IsGuildmate and S:IsGuildmate(sender))) then return true end
    return false
end

function V:Accept()
    local inv = self.invite
    if not inv then return end
    self.invite = nil
    if self.match then self:Leave() end
    local me = Me()
    local m = { id = inv.id, host = Key(inv.from), me = me, state = "lobby", key = inv.key, len = inv.len, seed = inv.seed,
                players = {}, order = {} }
    AddPlayer(m, inv.from, "ready")
    AddPlayer(m, MeName(), "ready")
    self.match = m
    Whisper(inv.from, "A", inv.id)
    if self.onJoin then self.onJoin() end
    self:Changed()
end

function V:Decline(reason)
    local inv = self.invite
    if not inv then return end
    self.invite = nil
    Whisper(inv.from, "D", inv.id, reason or "no")
end

-- host: everyone who said yes starts together
function V:StartMatch()
    local m = self.match
    if not (m and m.host == m.me and m.state == "lobby") then return false end
    local names, kept = {}, {}
    for _, name in ipairs(m.order) do
        local p = m.players[name]
        if p.status == "ready" then names[#names + 1] = p.name; kept[#kept + 1] = name
        else Whisper(p.name, "X", m.id); m.players[name] = nil end
    end
    if #names < 2 then
        m.order = kept
        self:Changed()
        return false
    end
    m.order = kept
    self:SendAll("G", m.id, table.concat(names, ";"))
    self:Begin(m)
    return true
end

function V:Begin(m)
    local Putt = NS.Putt
    m.state, m.countT = "count", 3.5
    for i, name in ipairs(m.order) do
        local p = m.players[name]
        p.status, p.hole, p.total, p.strokes, p.final, p.left, p.away = "playing", 1, 0, 0, nil, nil, nil
        p.color = V.COLORS[((i - 1) % #V.COLORS) + 1]
        p.seen = GetTime()
        if name ~= m.me then
            local c = V.BuildCourse(m.key, m.seed, m.len)
            p.g = Putt.New({})
            p.g:Start(c)
            p.shown = false
        end
    end
    if self.db then self.db.vsLen = m.len end
    if self.onCount then self.onCount(m) end
    self:Changed()
end

function V:Leave(quiet)
    local m = self.match
    if not m then return end
    if not quiet then
        if m.state == "lobby" and m.host == m.me then self:SendAll("X", m.id)
        elseif m.state == "lobby" then Whisper(m.players[m.host].name, "D", m.id, "left")
        elseif m.state ~= "done" then self:SendAll("Q", m.id) end
    end
    self.match = nil
    self:Changed()
end

---------------------------------------------------------------------------
-- My own play, reported to the others
---------------------------------------------------------------------------
local function N(v) return ("%.17g"):format(v) end

function V:Playing(game)
    local m = self.match
    return m and m.state == "play" and game and game.course and game.course.kind == "versus" and game.course.vsId == m.id
end

function V:OnShot(game)
    if not self:Playing(game) then return end
    local m, b, h = self.match, game.ball, game.hole
    local me = m.players[m.me]
    me.hole, me.strokes = game.index, game.strokes
    self:SendAll("S", m.id, game.index, game.strokes, N(h.clock or 0), N(b.x), N(b.y), N(b.vx), N(b.vy))
    self:Changed()
end

function V:OnHole(game, strokes, sunk)
    if not self:Playing(game) then return end
    local m = self.match
    local me = m.players[m.me]
    me.total = me.total + strokes
    me.hole, me.strokes = game.index + 1, 0
    self:SendAll("H", m.id, game.index, strokes, sunk and 1 or 0, me.total)
    self:Changed()
end

-- the round is over for me. Versus time runs on the wall clock, so closing the window can't stop it.
function V:OnFinish(game, adj, strokes, par)
    if not self:Playing(game) then return nil end
    local m = self.match
    local me = m.players[m.me]
    local final = NS.Putt.FinalTime(GetTime() - m.t0, adj)
    me.final, me.status, me.total = final, "done", strokes
    self:SendAll("F", m.id, floor(final * 1000 + 0.5), strokes, par)
    self:CheckOver()
    self:Changed()
    return final
end

function V:Elapsed()
    local m = self.match
    if not (m and m.t0) then return 0 end
    local me = m.players[m.me]
    if me and me.final then return me.final end
    return GetTime() - m.t0
end

function V:CheckOver()
    local m = self.match
    if not m or m.state ~= "play" then return end
    for _, name in ipairs(m.order) do
        local p = m.players[name]
        if not p.final and not p.left then return end
    end
    m.state = "done"
    if self.onOver then self.onOver(m) end
end

-- finished players by time, then everyone still out on the course by how far along they are
function V:Standings()
    local m = self.match
    local out = {}
    if not m then return out end
    for _, name in ipairs(m.order) do out[#out + 1] = m.players[name] end
    table.sort(out, function(a, b)
        if (a.final ~= nil) ~= (b.final ~= nil) then return a.final ~= nil end
        if a.final and b.final then return a.final < b.final end
        if (a.left and true or false) ~= (b.left and true or false) then return not a.left end
        if a.hole ~= b.hole then return a.hole > b.hole end
        return (a.total + a.strokes) < (b.total + b.strokes)
    end)
    return out
end

---------------------------------------------------------------------------
-- Incoming
---------------------------------------------------------------------------
local function num(s, lo, hi)
    local v = tonumber(s)
    if not v or v ~= v or v < lo or v > hi then return nil end
    return v
end

function V:OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" or channel ~= "WHISPER" then return end
    sender = Norm(sender)
    if not sender or Key(sender) == Me() then return end
    local skey = Key(sender)
    local a = { strsplit(",", text) }
    local cmd, id = a[1], a[2]
    if not cmd or not id then return end
    local m = self.match

    if cmd == "I" then
        local key, seed, len, fp = a[4], num(a[5], 0, 1e9), num(a[6], 1, 18), num(a[7], 0, 1e7)
        if a[3] ~= PROTO or not key or not seed or not len then return Whisper(sender, "D", id, "version") end
        if not self:Trusted(sender) then
            self.blocked = self.blocked or {}
            if (self.blocked[sender] or 0) < GetTime() - 60 then
                self.blocked[sender] = GetTime()
                NS.Print(("%s tried to challenge you to mini golf. Group up or add them as a friend to play."):format(Short(sender)))
            end
            return Whisper(sender, "D", id, "private")
        end
        if self:Busy() or (InCombatLockdown and InCombatLockdown()) then return Whisper(sender, "D", id, "busy") end
        local c = V.BuildCourse(key, seed, len)
        if not c or V.Fingerprint(c) ~= fp then
            NS.Print(("%s challenged you, but you two are on different Flight Buddy versions. Update the addon to play."):format(Short(sender)))
            return Whisper(sender, "D", id, "version")
        end
        if self.invite and self.invite.from ~= sender then Whisper(self.invite.from, "D", self.invite.id, "busy") end
        self.invite = { id = id, from = sender, key = key, seed = seed, len = len, name = c.name or key, at = GetTime() }
        local detail = ("%s, %d holes"):format(c.name or "Mini golf", len)
        if self.onInvite and self.onInvite(self.invite, detail) then return end
        if StaticPopup_Show then StaticPopup_Show("FLIGHTBUDDY_VS_INVITE", Short(sender), detail)
        else NS.Print(("%s challenges you to mini golf (%s). Type /fb accept."):format(Short(sender), detail)) end
        return
    end

    if cmd == "X" then
        if self.invite and self.invite.id == id and self.invite.from == sender then
            self.invite = nil
            if StaticPopup_Hide then StaticPopup_Hide("FLIGHTBUDDY_VS_INVITE") end
        end
        if m and m.id == id and m.host == skey and m.state == "lobby" then
            self.match = nil
            NS.Print(Short(sender) .. " called the match off.")
            self:Changed()
        end
        return
    end

    if not m or m.id ~= id then return end
    local p = m.players[skey]
    if p then p.name, p.short = sender, Short(sender) end

    if cmd == "A" then
        if m.host == m.me and m.state == "lobby" and p then
            p.status = "ready"
            self:Changed()
        end
    elseif cmd == "D" then
        if m.host == m.me and m.state == "lobby" and p then
            local why = a[3]
            p.status = (why == "busy" and "busy") or (why == "version" and "version") or (why == "private" and "private")
                or (why == "left" and "gone") or "declined"
            self:Changed()
        end
    elseif cmd == "G" then
        if m.host ~= skey or m.state ~= "lobby" or m.host == m.me then return end
        local names = { strsplit(";", a[3] or "") }
        if #names < 2 or #names > MAX_PLAYERS then return end
        local mine = false
        m.players, m.order = {}, {}
        for _, nm in ipairs(names) do
            nm = Norm(nm)
            if nm then AddPlayer(m, nm, "ready"); if Key(nm) == m.me then mine = true end end
        end
        if not mine then self.match = nil; return self:Changed() end
        self:Begin(m)
    elseif not p or (m.state ~= "play" and m.state ~= "count" and m.state ~= "done") then
        return
    elseif cmd == "S" then
        local hole, stroke = num(a[3], 1, m.len), num(a[4], 1, 99)
        local t, x, y, vx, vy = num(a[5], 0, 1e6), num(a[6], -50, 2000), num(a[7], -50, 2000), num(a[8], -5000, 5000), num(a[9], -5000, 5000)
        if not (hole and stroke and t and x and y and vx and vy and p.g) then return end
        p.seen, p.away = GetTime(), nil
        p.hole, p.strokes = hole, stroke
        local g = p.g
        if g.index ~= hole or g.state == "sunk" or g.state == "done" then
            g.index = hole - 1
            g:NextHole()
        end
        local h = g.hole
        if not h then return end
        for _, mv in ipairs(h.movers) do mv.t = t end
        h.clock = t
        g:MoveObstacles(0)
        g.ball = { x = x, y = y, vx = vx, vy = vy, age = 0, slow = 0, travel = 0 }
        g.rest = { x = x, y = y }
        g.strokes = stroke
        g.state, g.acc = "roll", 0
        g:ArmActors()
        p.shown, p.sunkAt = true, nil
        p.shotAt = GetTime()
        self:Changed()
    elseif cmd == "H" then
        local hole, strokes, total = num(a[3], 1, m.len), num(a[4], 1, 99), num(a[6], 0, 999)
        if not (hole and strokes and total) then return end
        p.seen, p.away = GetTime(), nil
        p.total, p.hole, p.strokes = total, hole + 1, 0
        p.holedAt, p.holedIdx, p.holedSunk = GetTime(), hole, a[5] == "1"
        self:Changed()
    elseif cmd == "F" then
        local ms, strokes = num(a[3], 0, 3.6e7), num(a[4], 1, 999)
        if not (ms and strokes) or p.final then return end
        p.seen, p.away = GetTime(), nil
        p.final, p.total, p.status, p.strokes = ms / 1000, strokes, "done", 0
        p.hole = m.len + 1
        if self.onRival then self.onRival(p, "finish") end
        self:CheckOver()
        self:Changed()
    elseif cmd == "Q" then
        if not p.final then
            p.left, p.status = true, "left"
            if self.onRival then self.onRival(p, "left") end
            self:CheckOver()
            self:Changed()
        end
    end
end

---------------------------------------------------------------------------
-- Every frame (from the core driver, so it runs with the window closed too)
---------------------------------------------------------------------------
function V:Pump(el)
    sendAcc = sendAcc + el
    if sendAcc >= 0.12 and #queue > 0 then
        sendAcc = 0
        local q = table.remove(queue, 1)
        NS.Social.Deliver(PREFIX, q[1], q[2], q[3])
    end
    if self.invite and GetTime() - self.invite.at > INVITE_SECS then self.invite = nil end
    local m = self.match
    if not m then return end
    local now = GetTime()
    if m.state == "lobby" and m.host == m.me then
        for _, name in ipairs(m.order) do
            local p = m.players[name]
            if p.status == "invited" and now - (p.invitedAt or now) > INVITE_SECS then p.status = "noanswer"; self:Changed() end
        end
    elseif m.state == "count" then
        m.countT = m.countT - el
        if m.countT <= 0 then
            m.state, m.t0 = "play", now
            if self.onStart then self.onStart(m) end
            self:Changed()
        end
    elseif m.state == "play" or m.state == "done" then
        local step = min(el, 0.05)
        for _, name in ipairs(m.order) do
            local p = m.players[name]
            local g = p.g
            if g then
                if g.state == "roll" then
                    g:Update(step)
                    if g.state == "sunk" and not p.sunkAt then p.sunkAt = now end
                end
                -- they holed out: once my replay of the shot has stopped, the ball leaves the hole
                -- even if my copy of it came to rest somewhere else
                if p.holedIdx and g.state ~= "roll" and g.index == p.holedIdx and now - p.holedAt > 0.15 then
                    if g.state ~= "sunk" then
                        g.state = "sunk"
                        if p.holedSunk and not p.sunkAt then p.sunkAt = now end
                    end
                    p.holedIdx = nil
                end
                if m.state == "play" and not p.final and not p.left and not p.away and now - p.seen > 150 then
                    p.away = true
                    self:Changed()
                end
            end
        end
    end
end

-- where to draw a rival's ball on my screen, if they are on the hole I am looking at
function V:Ghost(p, myIndex)
    local g = p.g
    if not g or not p.shown or p.left or not g.hole or g.index ~= myIndex then return nil end
    if g.state == "sunk" or g.state == "done" then
        if p.sunkAt and GetTime() - p.sunkAt < 0.6 then return g.hole.cup.x, g.hole.cup.y, true end
        return nil
    end
    local b = g.ball
    if not b or b.tunnel then return nil end
    return b.x, b.y, false, b.z or 0, g.state == "roll"
end

-- /fb vs Name, /fb accept, /fb decline
function V:Slash(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S+)%s*(.-)%s*$")
    cmd = cmd and cmd:lower()
    if cmd == "accept" then self:Accept(); return true end
    if cmd == "decline" then self:Decline(); return true end
    if cmd == "vs" or cmd == "versus" or cmd == "challenge" then
        if rest and rest ~= "" then
            if self:Invite(rest) then NS.Print("Challenge sent to " .. rest .. ".") end
        end
        if NS.Shell then NS.Shell:Open(nil, "putt") end
        local ui = NS.PuttUI
        if ui and ui.frame and ui.ShowVersus then ui:ShowVersus() end
        return true
    end
    return false
end
