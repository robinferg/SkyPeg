-- Flight Buddy :: Flap.lua
-- Featherbeard: fly a gryphon between the stone pillars of Dun Morogh (engine only).
-- 480 x 560 units, y down. Pure Lua, no WoW API: tested in luatest/flapsim.lua and e2e_fb.lua.
local ADDON, NS = ...

local Flap = {}
NS.Flap = Flap

local min, max, abs, sqrt, floor, sin = math.min, math.max, math.abs, math.sqrt, math.floor, math.sin

local C = {
    W = 480, H = 560, GROUND = 512,
    X = 140, R = 14,                       -- the rider's position and (forgiving) hit radius
    HEAD_X = 14, HEAD_Y = -12, HEAD_R = 9, -- a second, smaller circle for the gryphon's head
    GRAVITY = 1500, FLAP = -430, MAX_FALL = 640,
    PILLAR_W = 72,
    GAP = { 172, 136 },                    -- gap height: start, hardest
    SPACING = { 250, 205 },                -- distance between spires: start, hardest
    SPEED = { 150, 225 },                  -- scroll speed: start, hardest
    RAMP = 60,                             -- spires passed at which it's hardest
    MAX_SHIFT = 150,                       -- the next gap is never further than this from the last
    COIN_EVERY = 3,                        -- a coin in every few gaps
    SHAVE = 7,                             -- pass a spire this close to the stone and it's a Close Shave
    MOVING_FROM = 25,                      -- from here on some spires slide up and down
    STONEFORM_FROM = 15, STONEFORM_EVERY = 17, -- a Stoneform rune now and then: it shrugs off one crash
    STEP = 1 / 120,
    MEDALS = { { 75, "platinum" }, { 50, "gold" }, { 25, "silver" }, { 10, "bronze" } },
}
Flap.C = C

local Game = {}
Game.__index = Game

function Flap.New(handlers)
    local g = setmetatable({ h = handlers or {}, state = "ready" }, Game)
    g:Reset()
    return g
end

function Game:Emit(ev, ...)
    local f = self.h[ev]
    if f then f(self.h.owner, ...) end
end

function Game:Reset(seed)
    self.seed = seed or self.seed or 1
    self.rng = NS.Game.RNG(self.seed)
    self.y, self.vy = C.H * 0.42, 0
    self.score, self.coins, self.passed = 0, 0, 0
    self.shaves, self.chain, self.bestChain = 0, 0, 0
    self.stoneform, self.stoneUsed, self.ghostT = false, 0, 0
    self.pillars = {}
    self.dist = 0
    self.nextX = C.W + 60
    self.lastGap = C.H * 0.45
    self.count = 0
    self.state = "ready"
    self.t = 0
    self.acc = 0
end

local function lerp(a, b, t) return a + (b - a) * max(0, min(1, t)) end
function Game:Hardness() return self.passed / C.RAMP end
function Game:Speed() return lerp(C.SPEED[1], C.SPEED[2], self:Hardness()) end
function Game:GapSize() return lerp(C.GAP[1], C.GAP[2], self:Hardness()) end

function Game:Start(seed)
    self:Reset(seed)
    self.state = "play"
    self:Flap()
    self:Emit("start")
end

function Game:Flap()
    if self.state == "ready" then return self:Start(self.seedNext) end
    if self.state ~= "play" then return false end
    self.vy = C.FLAP
    self:Emit("flap")
    return true
end

function Game:Spawn()
    local gap = self:GapSize()
    local lo, hi = 110 + gap / 2, C.GROUND - 70 - gap / 2
    local r = self.rng
    local y = lo + r.next() * (hi - lo)
    y = max(self.lastGap - C.MAX_SHIFT, min(self.lastGap + C.MAX_SHIFT, y))
    self.count = self.count + 1
    local n = self.count
    local p = { x = self.nextX, gapY = y, baseY = y, gap = gap, scored = false, clear = 999 }
    -- later on, some spires drift up and down (never past the safe band)
    if n > C.MOVING_FROM and r.next() < min(0.45, 0.2 + (n - C.MOVING_FROM) * 0.01) then
        local room = min(y - lo, hi - y)
        p.amp = max(18, min(48, room))
        p.ph, p.spd = r.next() * 6.28, 1.4 + r.next() * 0.8
        y = max(lo + p.amp, min(hi - p.amp, y))
        p.baseY, p.gapY = y, y
    end
    self.lastGap = y
    local cx = self.nextX + C.PILLAR_W / 2
    if n >= C.STONEFORM_FROM and n % C.STONEFORM_EVERY == 0 then
        p.rune = { x = cx, y = y, taken = false }
    elseif n % C.COIN_EVERY == 0 then
        p.coin = { x = cx, y = y, taken = false }
    end
    self.pillars[#self.pillars + 1] = p
    self.nextX = self.nextX + lerp(C.SPACING[1], C.SPACING[2], self:Hardness())
end

-- circle vs axis-aligned box: overlap, and the gap between them (negative when touching)
local function boxGap(cx, cy, r, x0, y0, x1, y1)
    local nx, ny = max(x0, min(x1, cx)), max(y0, min(y1, cy))
    local dx, dy = cx - nx, cy - ny
    return sqrt(dx * dx + dy * dy) - r
end

function Game:Step(h)
    self.t = self.t + h
    if self.state == "ready" then
        self.y = C.H * 0.42 + math.sin(self.t * 3) * 8      -- bobbing, waiting for the first flap
        return
    end
    if self.state == "over" then return end
    self.vy = min(C.MAX_FALL, self.vy + C.GRAVITY * h)
    self.y = self.y + self.vy * h
    if self.y < C.R then self.y, self.vy = C.R, max(0, self.vy) end  -- the sky is a soft ceiling
    if self.state == "dead" then
        if self.y >= C.GROUND - C.R then
            self.y = C.GROUND - C.R
            self.state = "over"
            self:Emit("over", self.score, self.coins)
        end
        return
    end
    if self.ghostT > 0 then self.ghostT = self.ghostT - h end
    -- scroll the world
    local dx = self:Speed() * h
    self.dist = self.dist + dx
    self.nextX = self.nextX - dx
    for _, p in ipairs(self.pillars) do
        p.x = p.x - dx
        if p.amp then
            p.ph = p.ph + p.spd * h
            p.gapY = p.baseY + sin(p.ph) * p.amp
            if p.coin then p.coin.y = p.gapY end
            if p.rune then p.rune.y = p.gapY end
        end
        if p.coin then p.coin.x = p.coin.x - dx end
        if p.rune then p.rune.x = p.rune.x - dx end
    end
    while self.nextX < C.W + 40 do self:Spawn() end
    while self.pillars[1] and self.pillars[1].x < -C.PILLAR_W - 10 do table.remove(self.pillars, 1) end
    -- collisions and scoring
    local x, y, r = C.X, self.y, C.R
    if y >= C.GROUND - r then
        if self.stoneform then return self:Shrug(nil, true) end
        return self:Die("ground")
    end
    local hx, hy, hr = x + C.HEAD_X, y + C.HEAD_Y, C.HEAD_R
    for _, p in ipairs(self.pillars) do
        local top, bot, x1 = p.gapY - p.gap / 2, p.gapY + p.gap / 2, p.x + C.PILLAR_W
        if not p.broken and p.x < x + 60 and x1 > x - 60 then
            local d = min(boxGap(x, y, r, p.x, -200, x1, top), boxGap(x, y, r, p.x, bot, x1, C.GROUND + 50),
                          boxGap(hx, hy, hr, p.x, -200, x1, top), boxGap(hx, hy, hr, p.x, bot, x1, C.GROUND + 50))
            if d < 0 then
                if self.ghostT > 0 then
                    -- just shrugged off a crash: pass through this spire
                elseif self.stoneform then
                    self:Shrug(p)
                else
                    return self:Die("spire")
                end
            elseif d < p.clear then
                p.clear = d
            end
        end
        if not p.scored and x1 < x - r then
            p.scored = true
            self.passed = self.passed + 1
            self.score = self.score + 1
            local shave = not p.broken and p.clear < C.SHAVE
            if shave then
                self.chain = self.chain + 1
                self.shaves = self.shaves + 1
                self.bestChain = max(self.bestChain, self.chain)
                local bonus = min(self.chain, 3)
                self.score = self.score + bonus
                self:Emit("shave", self.chain, bonus, self.score)
            else
                self.chain = 0
            end
            self:Emit("score", self.score, shave)
        end
        local c = p.coin
        if c and not c.taken and (c.x - x) ^ 2 + (c.y - y) ^ 2 < (r + 12) ^ 2 then
            c.taken = true
            self.coins = self.coins + 1
            self.score = self.score + 1
            self:Emit("coin", c.x, c.y, self.score)
        end
        local ru = p.rune
        if ru and not ru.taken and (ru.x - x) ^ 2 + (ru.y - y) ^ 2 < (r + 14) ^ 2 then
            ru.taken = true
            self.stoneform = true
            self:Emit("stoneform", ru.x, ru.y)
        end
    end
end

-- Stoneform takes the hit: the spire crumbles (or the gryphon bounces off the ground) and flight goes on
function Game:Shrug(p, ground)
    self.stoneform = false
    self.stoneUsed = self.stoneUsed + 1
    self.ghostT = 0.6
    self.chain = 0
    if p then p.broken = true end
    if ground then self.y = C.GROUND - C.R - 1; self.vy = C.FLAP * 1.1 end
    self:Emit("shrug", p and (p.x + C.PILLAR_W / 2) or C.X, self.y)
end

function Game:Die(why)
    self.state = "dead"
    self.vy = min(self.vy, -160)
    self.chain = 0
    self:Emit("hit", why)
end

function Game:Update(dt)
    dt = min(dt, 0.1)
    self.acc = self.acc + dt
    while self.acc >= C.STEP do
        self.acc = self.acc - C.STEP
        self:Step(C.STEP)
        if self.state == "over" then self.acc = 0; break end
    end
end

function Flap.Medal(score)
    for _, m in ipairs(C.MEDALS) do if score >= m[1] then return m[2], m[1] end end
end

function Flap.NextMedal(score)
    for i = #C.MEDALS, 1, -1 do local m = C.MEDALS[i]; if score < m[1] then return m[2], m[1] end end
end

---------------------------------------------------------------------------
-- Quests: three on the board at a time; each pays 1-3 stars toward Gryphon Rider ranks
---------------------------------------------------------------------------
Flap.QUESTS = {
    { id = "pass10",   text = "Fly past 10 pillars in one flight",          stat = "passed",   goal = 10, stars = 1 },
    { id = "pass20",   text = "Fly past 20 pillars in one flight",          stat = "passed",   goal = 20, stars = 2 },
    { id = "pass40",   text = "Fly past 40 pillars in one flight",          stat = "passed",   goal = 40, stars = 3 },
    { id = "coins3",   text = "Grab 3 coins in one flight",                 stat = "coins",    goal = 3,  stars = 1 },
    { id = "coins8",   text = "Grab 8 coins in one flight",                 stat = "coins",    goal = 8,  stars = 2 },
    { id = "shave1",   text = "Make a Close Shave",                         stat = "shaves",   goal = 1,  stars = 1 },
    { id = "shave5",   text = "Make 5 Close Shaves in one flight",          stat = "shaves",   goal = 5,  stars = 2 },
    { id = "chain3",   text = "Chain 3 Close Shaves in a row",              stat = "chain",    goal = 3,  stars = 3 },
    { id = "stone1",   text = "Shrug off a crash with Stoneform",           stat = "stone",    goal = 1,  stars = 2 },
    { id = "daily1",   text = "Fly the Daily Ironforge Run",                stat = "daily",    goal = 1,  stars = 1 },
    { id = "score15",  text = "Score 15 in one flight",                     stat = "score",    goal = 15, stars = 1 },
    { id = "score30",  text = "Score 30 in one flight",                     stat = "score",    goal = 30, stars = 2 },
    { id = "score60",  text = "Score 60 in one flight",                     stat = "score",    goal = 60, stars = 3 },
    { id = "flights5", text = "Take 5 flights",                             stat = "flights",  goal = 5,  stars = 1, total = true },
    { id = "coins25",  text = "Collect 25 coins in total",                  stat = "coins",    goal = 25, stars = 2, total = true },
}
Flap.QUEST = {}
for _, q in ipairs(Flap.QUESTS) do Flap.QUEST[q.id] = q end

-- Gryphon Rider ranks by stars earned
Flap.RANKS = {
    { 0, "Gryphon Hatchling" }, { 3, "Aerie Hand" }, { 7, "Wildhammer Recruit" }, { 12, "Sky Scout" },
    { 18, "Gryphon Rider" }, { 26, "Aerie Peak Ace" }, { 36, "Thane's Wingman" }, { 50, "Falstad's Favourite" },
}
function Flap.Rank(stars)
    local name, nextAt = Flap.RANKS[1][2], nil
    for i, r in ipairs(Flap.RANKS) do
        if stars >= r[1] then name = r[2]; nextAt = Flap.RANKS[i + 1] and Flap.RANKS[i + 1][1] or nil end
    end
    return name, nextAt
end

-- quest state lives in the saved table qs = { active = {ids}, progress = {id = n}, done = {id = true}, stars = n }
function Flap.FillQuests(qs, rng)
    qs.active = qs.active or {}
    qs.progress = qs.progress or {}
    qs.done = qs.done or {}
    qs.stars = qs.stars or 0
    local function has(id) for _, a in ipairs(qs.active) do if a == id then return true end end end
    local guard = 0
    while #qs.active < 3 and guard < 200 do
        guard = guard + 1
        local pool = {}
        for _, q in ipairs(Flap.QUESTS) do
            if not qs.done[q.id] and not has(q.id) then pool[#pool + 1] = q.id end
        end
        if #pool == 0 then qs.done = {}; qs.cycle = (qs.cycle or 0) + 1 else
            local pick = pool[floor((rng and rng() or math.random()) * #pool) + 1]
            qs.active[#qs.active + 1] = pick
            qs.progress[pick] = 0
        end
    end
end

-- run = { passed, coins, shaves, chain, stone, daily, score, flights }; returns the quests completed
function Flap.ApplyRun(qs, run, rng)
    Flap.FillQuests(qs, rng)
    local finished = {}
    for i = #qs.active, 1, -1 do
        local id = qs.active[i]
        local q = Flap.QUEST[id]
        if q then
            local v = run[q.stat] or 0
            if q.total then qs.progress[id] = (qs.progress[id] or 0) + v else qs.progress[id] = max(qs.progress[id] or 0, v) end
            if qs.progress[id] >= q.goal then
                table.remove(qs.active, i)
                qs.done[id] = true
                qs.progress[id] = nil
                qs.stars = qs.stars + q.stars
                finished[#finished + 1] = q
            end
        else
            table.remove(qs.active, i)
        end
    end
    Flap.FillQuests(qs, rng)
    return finished
end

-- the Daily Ironforge Run: everyone flies the same spires today
function Flap.DailySeed(dateStr)
    local n = 0
    for i = 1, #dateStr do n = (n * 31 + dateStr:byte(i)) % 2147483000 end
    return n + 7
end
