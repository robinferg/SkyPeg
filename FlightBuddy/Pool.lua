-- Flight Buddy :: Pool.lua
-- Tavern Pool: the engine (no UI). A pool table seen from above, the long way up the screen:
-- sixteen balls, six pockets, cushions with proper jaws, and the rules of eight-ball.
--   match  you against one of the tavern regulars (they think for themselves, see Think)
--   solo   clear all fifteen in as few shots as you can
--   daily  the same scattered table for everyone, fewest shots wins
-- Everything is in table units: (0, 0) is the top left of the cloth, y runs DOWN the screen.
-- The physics is stepped in fixed slices, so the same shot always ends the same way.
local ADDON, NS = ...

local Pool = {}
NS.Pool = Pool

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

Pool.TW, Pool.TH, Pool.R = 244, 488, 8
Pool.MIN_V, Pool.MAX_V = 70, 1000           -- cue ball speed at no power and at full power
Pool.BREAK_BOOST = 1.6
Pool.FOUL_COST = 1                          -- shots added for a foul when playing alone
local TW, TH, R = Pool.TW, Pool.TH, Pool.R
local DT = 1 / 240
local DECEL, DRAG = 62, 0.09                -- rolling friction, and a little that grows with speed
local REST_BALL, REST_RAIL, REST_JAW = 0.95, 0.74, 0.6
local CG, SG = 17, 14                       -- how far a corner / side pocket's mouth runs along the rail
local HEAD_Y, FOOT_Y = TH * 0.76, TH * 0.27 -- where the cue ball starts, and the top ball of the rack

-- pockets: centre, and how near a ball's centre must come to drop
Pool.POCKETS = {
    { x = -2, y = -2, r = 16 }, { x = TW + 2, y = -2, r = 16 },
    { x = -6, y = TH / 2, r = 13.5 }, { x = TW + 6, y = TH / 2, r = 13.5 },
    { x = -2, y = TH + 2, r = 16 }, { x = TW + 2, y = TH + 2, r = 16 },
}
local POCKETS = Pool.POCKETS
-- the points of the cushions either side of each pocket
local JAWS = {
    { 0, CG }, { 0, TH / 2 - SG }, { 0, TH / 2 + SG }, { 0, TH - CG },
    { TW, CG }, { TW, TH / 2 - SG }, { TW, TH / 2 + SG }, { TW, TH - CG },
    { CG, 0 }, { TW - CG, 0 }, { CG, TH }, { TW - CG, TH },
}

Pool.COLORS = {
    [0] = { 0.97, 0.96, 0.92 }, { 1.00, 0.80, 0.10 }, { 0.20, 0.40, 0.95 }, { 0.92, 0.18, 0.15 }, { 0.55, 0.25, 0.80 },
    { 1.00, 0.52, 0.10 }, { 0.15, 0.65, 0.30 }, { 0.60, 0.16, 0.14 }, { 0.08, 0.08, 0.09 },
}
function Pool.Color(id) return Pool.COLORS[id > 8 and id - 8 or id] end
function Pool.Kind(id) return id == 0 and "cue" or (id == 8 and "eight") or (id < 8 and "solid" or "stripe") end

Pool.FOES = {
    { key = "barkeep", name = "The Barkeep", blurb = "Plays between pouring drinks.", err = 0.060, look = 1 },
    { key = "brawler", name = "The Brawler", blurb = "Hits hard, thinks later.",     err = 0.026, look = 2 },
    { key = "hustler", name = "The Hustler", blurb = "Has been waiting for you.",    err = 0.008, look = 4 },
}

function Pool.New()
    local g = setmetatable({}, { __index = Pool })
    g.phase = "idle"
    g.balls = {}
    g.rs = 1
    return g
end

function Pool:Rand()
    self.rs = (self.rs * 16807) % 2147483647
    return (self.rs - 1) / 2147483646
end

local function DaySeed(day)
    local n = 0
    for ch in tostring(day):gmatch("%d") do n = (n * 10 + tonumber(ch)) % 2147483000 end
    return n * 19 + 31337
end

---------------------------------------------------------------------------
-- Setting the table
---------------------------------------------------------------------------
local function Ball(id, x, y) return { id = id, x = x, y = y, vx = 0, vy = 0, on = true } end

function Pool:Free(x, y, skip, gap)
    if x < R or x > TW - R or y < R or y > TH - R then return false end
    for _, b in ipairs(self.balls) do
        if b.on and b ~= skip and (b.x - x) ^ 2 + (b.y - y) ^ 2 < (2 * R + (gap or 0.5)) ^ 2 then return false end
    end
    return true
end

-- the triangle: eight ball in the middle, a solid and a stripe in the back corners
function Pool:Rack()
    local ids = {}
    for id = 1, 15 do if id ~= 8 and id ~= 1 and id ~= 15 then ids[#ids + 1] = id end end
    for i = #ids, 2, -1 do
        local j = 1 + floor(self:Rand() * i) % i
        ids[i], ids[j] = ids[j], ids[i]
    end
    local n, k = 0, 0
    local step = 2 * R + 0.6
    for row = 1, 5 do
        for i = 1, row do
            n = n + 1
            local id
            if n == 5 then id = 8 elseif n == 11 then id = 1 elseif n == 15 then id = 15 else k = k + 1; id = ids[k] end
            self.balls[#self.balls + 1] = Ball(id, TW / 2 + (i - (row + 1) / 2) * step, FOOT_Y - (row - 1) * step * 0.8660254)
        end
    end
end

-- the daily table: fifteen balls strewn about, the same for everyone
function Pool:Scatter()
    for id = 1, 15 do
        for _ = 1, 400 do
            local x, y = R + 6 + self:Rand() * (TW - 2 * R - 12), R + 6 + self:Rand() * (TH * 0.68)
            local clear = self:Free(x, y, nil, 7)
            for _, p in ipairs(POCKETS) do if (x - p.x) ^ 2 + (y - p.y) ^ 2 < 30 ^ 2 then clear = false end end
            if clear then self.balls[#self.balls + 1] = Ball(id, x, y); break end
        end
    end
end

-- mode "match": opts.foe (1..3), opts.seed; "solo": opts.seed; "daily": opts.day
function Pool:Start(mode, opts)
    opts = opts or {}
    self.mode = (mode == "match" or mode == "daily") and mode or "solo"
    self.day = self.mode == "daily" and opts.day or nil
    self.foe = self.mode == "match" and max(1, min(#Pool.FOES, opts.foe or 1)) or nil
    local seed = self.mode == "daily" and DaySeed(opts.day or 0) or (opts.seed or 1)
    self.rs = floor(abs(seed)) % 2147483646 + 1
    self.balls = { Ball(0, TW / 2, HEAD_Y) }
    if self.mode == "daily" then self:Scatter() else self:Rack() end
    self.turn = "you"
    self.group = {}
    self.shots, self.fouls = 0, 0
    self.breakShot = self.mode ~= "daily"
    self.inHand = false
    self.winner, self.last, self.pending = nil, nil, nil
    self.phase = "aim"
end

function Pool:Cue() return self.balls[1] end
function Pool:Get(id) for _, b in ipairs(self.balls) do if b.id == id then return b end end end

function Pool:Left(kind)
    local n = 0
    for _, b in ipairs(self.balls) do
        if b.on and b.id ~= 0 and (kind == nil or Pool.Kind(b.id) == kind) then n = n + 1 end
    end
    return n
end

function Pool:Score() return (self.shots or 0) + (self.fouls or 0) * Pool.FOUL_COST end

-- may `who` strike ball `id` first without fouling?
function Pool:Legal(id, who)
    if id == 0 then return false end
    if self.mode ~= "match" then return true end
    local mine = self.group[who or self.turn]
    if not mine then return id ~= 8 end
    if self:Left(mine) == 0 then return id == 8 end
    return Pool.Kind(id) == mine
end

---------------------------------------------------------------------------
-- Physics
---------------------------------------------------------------------------
local function InMouth(x, y)
    -- is a ball here in front of a pocket rather than a cushion?
    if x < R or x > TW - R then
        if y < CG or y > TH - CG or abs(y - TH / 2) < SG then return true end
    end
    if y < R or y > TH - R then
        if x < CG or x > TW - CG then return true end
    end
    return false
end

function Pool:Moving()
    for _, b in ipairs(self.balls) do if b.on and (b.vx ~= 0 or b.vy ~= 0) then return true end end
    return false
end

local function Substep(self, ev)
    local balls = self.balls
    for _, b in ipairs(balls) do
        if b.on and (b.vx ~= 0 or b.vy ~= 0) then
            local s = sqrt(b.vx * b.vx + b.vy * b.vy)
            local s2 = s - (DECEL + DRAG * s) * DT
            if s2 < 3 then b.vx, b.vy = 0, 0
            else
                b.vx, b.vy = b.vx * s2 / s, b.vy * s2 / s
                b.x, b.y = b.x + b.vx * DT, b.y + b.vy * DT
            end
        end
    end
    -- ball against ball (a few passes, so a blow runs right through a tight rack at once)
    local n = #balls
    for _ = 1, 4 do
        local any = false
        for i = 1, n - 1 do
            local a = balls[i]
            if a.on then
                local am = a.vx ~= 0 or a.vy ~= 0
                for j = i + 1, n do
                    local b = balls[j]
                    if b.on and (am or b.vx ~= 0 or b.vy ~= 0) then
                        local dx, dy = b.x - a.x, b.y - a.y
                        local d2 = dx * dx + dy * dy
                        if d2 < 4 * R * R and d2 > 0 then
                            local d = sqrt(d2)
                            local nx, ny = dx / d, dy / d
                            local rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
                            if rel > 0 then
                                local p = (1 + REST_BALL) / 2 * rel
                                a.vx, a.vy = a.vx - p * nx, a.vy - p * ny
                                b.vx, b.vy = b.vx + p * nx, b.vy + p * ny
                                if a.id == 0 and not self.firstHit then self.firstHit = b.id end
                                if rel > ev.hit then ev.hit = rel end
                                any = true
                                am = true
                            end
                            local push = (2 * R - d) / 2 + 0.005
                            a.x, a.y, b.x, b.y = a.x - nx * push, a.y - ny * push, b.x + nx * push, b.y + ny * push
                        end
                    end
                end
            end
        end
        if not any then break end
    end
    -- pockets, jaws, cushions
    for _, b in ipairs(balls) do
        if b.on then
            local gone
            if b.x < R + 10 or b.x > TW - R - 10 or b.y < R + 10 or b.y > TH - R - 10 then
                for i, p in ipairs(POCKETS) do
                    if (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2 < p.r * p.r then gone = i; break end
                end
                if not gone and (b.x < -1 or b.x > TW + 1 or b.y < -1 or b.y > TH + 1) then
                    -- past the cloth in a pocket's mouth: it is down
                    local best
                    for i, p in ipairs(POCKETS) do
                        local d = (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2
                        if not best or d < best then best, gone = d, i end
                    end
                end
            end
            if gone then
                b.on, b.vx, b.vy = false, 0, 0
                self.potted[#self.potted + 1] = b.id
                ev.pots[#ev.pots + 1] = { id = b.id, pocket = gone, x = b.x, y = b.y }
            else
                for _, j in ipairs(JAWS) do
                    local dx, dy = b.x - j[1], b.y - j[2]
                    local d2 = dx * dx + dy * dy
                    if d2 < R * R and d2 > 0 then
                        local d = sqrt(d2)
                        local nx, ny = dx / d, dy / d
                        local vn = b.vx * nx + b.vy * ny
                        if vn < 0 then
                            b.vx, b.vy = b.vx - (1 + REST_JAW) * vn * nx, b.vy - (1 + REST_JAW) * vn * ny
                            if -vn > ev.rail then ev.rail = -vn end
                        end
                        b.x, b.y = j[1] + nx * R, j[2] + ny * R
                    end
                end
                if InMouth(b.x, b.y) then
                    -- past the line of the cushion in a pocket's mouth the cloth falls away: the ball
                    -- is drawn down into the pocket and cannot come to rest on the lip
                    local best, px, py
                    for _, p in ipairs(POCKETS) do
                        local d = (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2
                        if not best or d < best then best, px, py = d, p.x, p.y end
                    end
                    local d = sqrt(best)
                    if d > 0 then b.vx, b.vy = b.vx + (px - b.x) / d * 900 * DT, b.vy + (py - b.y) / d * 900 * DT end
                else
                    if b.x < R then b.x = R; if b.vx < 0 then if -b.vx > ev.rail then ev.rail = -b.vx end; b.vx = -b.vx * REST_RAIL; self.railed = true end
                    elseif b.x > TW - R then b.x = TW - R; if b.vx > 0 then if b.vx > ev.rail then ev.rail = b.vx end; b.vx = -b.vx * REST_RAIL; self.railed = true end end
                    if b.y < R then b.y = R; if b.vy < 0 then if -b.vy > ev.rail then ev.rail = -b.vy end; b.vy = -b.vy * REST_RAIL; self.railed = true end
                    elseif b.y > TH - R then b.y = TH - R; if b.vy > 0 then if b.vy > ev.rail then ev.rail = b.vy end; b.vy = -b.vy * REST_RAIL; self.railed = true end end
                end
            end
        end
    end
end

-- Strike the cue ball: angle in radians (0 = right, pi/2 = UP the screen), power 0..1.
function Pool:Shoot(angle, power)
    if self.phase ~= "aim" then return false end
    power = max(0, min(1, power or 0.5))
    -- the table as it stood, with the shot on top: enough to play it again after a reload
    self.pending = { angle = angle, power = power, before = self:Snapshot() }
    local c = self:Cue()
    local v = Pool.MIN_V + (Pool.MAX_V - Pool.MIN_V) * power
    if self.breakShot then v = v * Pool.BREAK_BOOST end      -- the break is struck with the whole arm
    c.vx, c.vy = cos(angle) * v, -sin(angle) * v
    self.firstHit, self.potted, self.railed = nil, {}, false
    self.acc, self.clock = 0, 0
    self.inHand = false
    self.phase = "roll"
    return true
end

-- Advance the balls by dt seconds. Returns what was heard: { hit = hardest ball-on-ball, rail =,
-- pots = { { id, pocket, x, y } ... } }, and done = true once everything has stopped (the rules
-- have then been applied: see self.last).
function Pool:Step(dt)
    local ev = { hit = 0, rail = 0, pots = {} }
    if self.phase ~= "roll" then return ev, false end
    self.acc = self.acc + dt
    while self.acc >= DT do
        self.acc = self.acc - DT
        self.clock = self.clock + DT
        Substep(self, ev)
        if not self:Moving() or self.clock > 25 then
            for _, b in ipairs(self.balls) do b.vx, b.vy = 0, 0 end
            self:Resolve()
            return ev, true
        end
    end
    return ev, false
end

-- run the shot to its end at once
function Pool:Run()
    local guard = 0
    while self.phase == "roll" and guard < 4000 do self:Step(0.05); guard = guard + 1 end
    return self.last
end

---------------------------------------------------------------------------
-- The rules, applied when the balls stop
---------------------------------------------------------------------------
local function Spot(self, b, x, y)
    -- put a ball back on the table at (x, y), or as near above it as there is room
    for i = 0, 60 do
        for _, off in ipairs({ 0, -1, 1 }) do
            local px, py = x + off * i * 4, y - (off == 0 and i * 4 or 0)
            if self:Free(px, py, b) then b.x, b.y, b.on, b.vx, b.vy = px, py, true, 0, 0; return end
        end
    end
    b.x, b.y, b.on = x, y, true
end

function Pool:Resolve()
    local who = self.turn
    local other = who == "you" and "foe" or "you"
    local res = { who = who, potted = self.potted, first = self.firstHit }
    local cueDown, eightDown, mineDown, anyDown = false, false, 0, 0
    for _, id in ipairs(self.potted) do
        if id == 0 then cueDown = true
        elseif id == 8 then eightDown = true
        else
            anyDown = anyDown + 1
            if self.group[who] and Pool.Kind(id) == self.group[who] then mineDown = mineDown + 1 end
        end
    end
    self.shots = self.shots + 1
    if self.mode ~= "match" then
        -- alone at the table: every ball counts, a scratch or a clean miss costs a shot
        if cueDown then res.foul = "scratch" elseif not self.firstHit then res.foul = "nothing" end
        if res.foul then self.fouls = self.fouls + 1 end
        if cueDown then Spot(self, self:Cue(), TW / 2, HEAD_Y) end
        if self:Left() == 0 then self.phase, self.winner = "over", "you"; res.won = true else self.phase = "aim" end
    else
        local cleared = self.group[who] and (self:Left(self.group[who]) + mineDown) == 0
        if cueDown then res.foul = "scratch"
        elseif not self.firstHit then res.foul = "nothing"
        elseif self.firstHit == 8 and not cleared then res.foul = "eight"
        elseif cleared and self.firstHit ~= 8 then res.foul = "wrong"
        elseif self.group[who] and not cleared and Pool.Kind(self.firstHit) ~= self.group[who] then res.foul = "wrong" end
        if eightDown and self.breakShot then
            -- the eight on the break goes back on its spot
            Spot(self, self:Get(8), TW / 2, FOOT_Y)
            eightDown = false
        end
        if eightDown then
            self.phase = "over"
            self.winner = (cleared and not res.foul) and who or other
            res.eight = true
        else
            if not self.group[who] and not self.breakShot and not res.foul and anyDown > 0 then
                for _, id in ipairs(self.potted) do
                    if id ~= 0 and id ~= 8 then
                        self.group[who] = Pool.Kind(id)
                        self.group[other] = self.group[who] == "solid" and "stripe" or "solid"
                        res.assigned = self.group[who]
                        break
                    end
                end
                mineDown = 0
                for _, id in ipairs(self.potted) do if id ~= 0 and id ~= 8 and Pool.Kind(id) == self.group[who] then mineDown = mineDown + 1 end end
            end
            local keep = not res.foul and ((self.group[who] and mineDown > 0) or (not self.group[who] and anyDown > 0))
            if cueDown then Spot(self, self:Cue(), TW / 2, HEAD_Y) end
            if res.foul then self.inHand = true end
            if not keep then self.turn = other; res.passed = true end
            self.phase = "aim"
        end
    end
    self.breakShot = false
    self.pending = nil
    self.last = res
    return res
end

-- ball in hand: put the cue ball down at (x, y) if there is room
function Pool:PlaceCue(x, y)
    if self.phase ~= "aim" or not self.inHand then return false end
    x, y = max(R, min(TW - R, x)), max(R, min(TH - R, y))
    local c = self:Cue()
    if not self:Free(x, y, c, 1) then return false end
    c.x, c.y = x, y
    return true
end

---------------------------------------------------------------------------
-- Looking down the cue
---------------------------------------------------------------------------
-- Where the cue ball first touches something along `angle`:
--   { x, y = the cue ball's centre at that moment, ball = id struck (nil for a cushion),
--     ox, oy = the way the struck ball leaves, cx, cy = the way the cue ball leaves }
function Pool:Sight(angle)
    local c = self:Cue()
    local dx, dy = cos(angle), -sin(angle)
    local best, hit = 1e9, nil
    for _, b in ipairs(self.balls) do
        if b.on and b.id ~= 0 then
            local fx, fy = b.x - c.x, b.y - c.y
            local along = fx * dx + fy * dy
            if along > 0 then
                local off2 = fx * fx + fy * fy - along * along
                if off2 < 4 * R * R then
                    local t = along - sqrt(4 * R * R - off2)
                    if t < best then best, hit = t, b end
                end
            end
        end
    end
    -- the cushions
    local tw = 1e9
    if dx > 0 then tw = min(tw, (TW - R - c.x) / dx) elseif dx < 0 then tw = min(tw, (R - c.x) / dx) end
    if dy > 0 then tw = min(tw, (TH - R - c.y) / dy) elseif dy < 0 then tw = min(tw, (R - c.y) / dy) end
    if not hit or tw < best then
        return { x = c.x + dx * tw, y = c.y + dy * tw, dist = tw }
    end
    local gx, gy = c.x + dx * best, c.y + dy * best
    local ox, oy = (hit.x - gx) / (2 * R), (hit.y - gy) / (2 * R)
    local k = dx * ox + dy * oy
    local cx, cy = dx - k * ox, dy - k * oy
    local cl = sqrt(cx * cx + cy * cy)
    if cl > 1e-6 then cx, cy = cx / cl, cy / cl end
    return { x = gx, y = gy, dist = best, ball = hit.id, ox = ox, oy = oy, cx = cx, cy = cy, full = k }
end

-- is the straight path from (ax, ay) to (bx, by) free of balls (other than those named)?
local function Clear(self, ax, ay, bx, by, skipA, skipB)
    local dx, dy = bx - ax, by - ay
    local len = sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return true end
    dx, dy = dx / len, dy / len
    for _, b in ipairs(self.balls) do
        if b.on and b ~= skipA and b ~= skipB then
            local fx, fy = b.x - ax, b.y - ay
            local along = fx * dx + fy * dy
            if along > 0 and along < len then
                if fx * fx + fy * fy - along * along < (2 * R - 0.5) ^ 2 then return false end
            end
        end
    end
    return true
end

-- every straight pot on for `who`, easiest first: { ball, pocket, gx, gy (where the cue ball must
-- arrive), cut (0 = dead straight .. 1 = impossible), ease }
function Pool:Pots(who, cx, cy)
    local c = self:Cue()
    cx, cy = cx or c.x, cy or c.y
    local out = {}
    for _, b in ipairs(self.balls) do
        if b.on and b.id ~= 0 and self:Legal(b.id, who) then
            for pi_, p in ipairs(POCKETS) do
                -- aim at the mouth of the pocket rather than its far back
                local tx = max(6, min(TW - 6, p.x))
                local ty = max(6, min(TH - 6, p.y))
                local px, py = tx - b.x, ty - b.y
                local pl = sqrt(px * px + py * py)
                if pl > 1 then
                    px, py = px / pl, py / pl
                    local gx, gy = b.x - px * 2 * R, b.y - py * 2 * R
                    local sx, sy = gx - cx, gy - cy
                    local sl = sqrt(sx * sx + sy * sy)
                    if sl > 1 and gx > R and gx < TW - R and gy > R and gy < TH - R then
                        local cut = (sx * px + sy * py) / sl          -- 1 = straight, 0 = right angle
                        if cut > 0.28 and Clear(self, cx, cy, gx, gy, c, b) and Clear(self, b.x, b.y, tx, ty, b, c) then
                            -- side pockets close up when the ball comes at them along the rail
                            local open = (pi_ == 3 or pi_ == 4) and abs(px) or 1
                            if open > 0.45 then
                                out[#out + 1] = { ball = b.id, pocket = pi_, gx = gx, gy = gy, cut = 1 - cut,
                                    ease = cut * cut * open / (1 + (pl + sl) / 420), dist = pl + sl }
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.ease ~= b.ease then return a.ease > b.ease end if a.ball ~= b.ball then return a.ball < b.ball end return a.pocket < b.pocket end)
    return out
end

---------------------------------------------------------------------------
-- The regulars
---------------------------------------------------------------------------
function Pool:Clone()
    local h = Pool.New()
    for k, v in pairs(self) do if type(v) ~= "table" then h[k] = v end end
    h.group = { you = self.group.you, foe = self.group.foe }
    h.balls = {}
    for i, b in ipairs(self.balls) do h.balls[i] = { id = b.id, x = b.x, y = b.y, vx = 0, vy = 0, on = b.on } end
    return h
end

-- What the opponent does with this table: { angle, power, place = { x, y } or nil }.
-- They pick the easiest pot they can see; the better ones play a few out in their head first
-- and take one that goes in. Their hands shake as much as their `err` says.
function Pool:Think()
    local foe = Pool.FOES[self.foe or 1]
    local who = self.turn
    local c = self:Cue()
    local place
    if self.inHand then
        -- ball in hand: stand the cue ball straight behind the easiest ball
        local bestV
        for _, b in ipairs(self.balls) do
            if b.on and b.id ~= 0 and self:Legal(b.id, who) then
                for _, p in ipairs(POCKETS) do
                    local tx, ty = max(6, min(TW - 6, p.x)), max(6, min(TH - 6, p.y))
                    local px, py = tx - b.x, ty - b.y
                    local pl = sqrt(px * px + py * py)
                    px, py = px / pl, py / pl
                    for _, back in ipairs({ 70, 110, 45 }) do
                        local x, y = b.x - px * (2 * R + back), b.y - py * (2 * R + back)
                        if self:Free(x, y, c, 1) and Clear(self, x, y, b.x - px * 2 * R, b.y - py * 2 * R, c, b) and Clear(self, b.x, b.y, tx, ty, b, c) then
                            local v = 1 / (1 + pl)
                            if not bestV or v > bestV then bestV, place = v, { x = x, y = y } end
                        end
                    end
                end
            end
        end
    end
    local cx, cy = place and place.x or c.x, place and place.y or c.y
    local pots = self:Pots(who, cx, cy)
    local pick
    if #pots > 0 then
        pick = pots[1]
        -- think ahead: try the best few in the head and prefer one that drops without a foul
        for i = 1, min(foe.look, #pots) do
            local p = pots[i]
            local h = self:Clone()
            if place then h:Cue().x, h:Cue().y = place.x, place.y end
            h.pending = nil
            local a = atan2(-(p.gy - cy), p.gx - cx)
            h.Snapshot = function() return nil end
            h:Shoot(a, min(1, 0.30 + p.dist / 700))
            local res = h:Run()
            local good = res and not res.foul and not (res.eight and h.winner ~= who)
            local dropped = false
            for _, id in ipairs(res and res.potted or {}) do if id == p.ball then dropped = true end end
            if good and dropped then pick = p; break end
        end
    end
    local angle, power
    if pick then
        angle = atan2(-(pick.gy - cy), pick.gx - cx)
        power = min(1, 0.30 + pick.dist / 700)
    else
        -- nothing on: roll up to the nearest ball they are allowed to hit
        local best
        for _, b in ipairs(self.balls) do
            if b.on and b.id ~= 0 and self:Legal(b.id, who) then
                local d = (b.x - cx) ^ 2 + (b.y - cy) ^ 2
                local open = Clear(self, cx, cy, b.x, b.y, c, b)
                local v = d * (open and 1 or 9)
                if not best or v < best then best = v; angle = atan2(-(b.y - cy), b.x - cx) end
            end
        end
        angle = angle or pi / 2
        power = 0.42
    end
    if self.breakShot then angle, power = atan2(-(FOOT_Y - cy), TW / 2 - cx), 0.95 end
    -- an unsteady hand: two throws of the dice make most shots near the mark and a few well off
    local wobble = (self:Rand() + self:Rand() - 1) * foe.err * (self.breakShot and 0.3 or 1)
    return { angle = angle + wobble, power = power, place = place }
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
function Pool:Snapshot()
    local balls = {}
    for i, b in ipairs(self.balls) do balls[i] = { b.id, b.x, b.y, b.on and 1 or 0 } end
    return { balls = balls, turn = self.turn, you = self.group.you, foe = self.group.foe, shots = self.shots, fouls = self.fouls,
        breakShot = self.breakShot, inHand = self.inHand, rs = self.rs }
end

function Pool:Serialize()
    if self.phase ~= "aim" and self.phase ~= "roll" then return nil end
    local s = self.pending and self.pending.before or self:Snapshot()
    local out = { v = 1, mode = self.mode, day = self.day, level = self.foe, table = s }
    if self.pending then out.angle, out.power = self.pending.angle, self.pending.power end
    return out
end

function Pool:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or type(s.table) ~= "table" or type(s.table.balls) ~= "table" then return false end
    if s.mode ~= "match" and s.mode ~= "solo" and s.mode ~= "daily" then return false end
    if s.mode == "daily" and s.day == nil then return false end
    local t = s.table
    if #t.balls ~= 16 then return false end
    local balls, seen = {}, {}
    for i, b in ipairs(t.balls) do
        if type(b) ~= "table" or type(b[1]) ~= "number" or type(b[2]) ~= "number" or type(b[3]) ~= "number" then return false end
        local id = b[1]
        if id ~= floor(id) or id < 0 or id > 15 or seen[id] or (i == 1) ~= (id == 0) then return false end
        if b[2] ~= b[2] or b[3] ~= b[3] or b[2] < 0 or b[2] > TW or b[3] < 0 or b[3] > TH then return false end
        seen[id] = true
        balls[i] = { id = id, x = b[2], y = b[3], vx = 0, vy = 0, on = b[4] == 1 }
    end
    if not balls[1].on then return false end
    local function kind(v) return (v == "solid" or v == "stripe") and v or nil end
    self.mode, self.day = s.mode, s.day
    self.foe = s.mode == "match" and max(1, min(#Pool.FOES, tonumber(s.level) or 1)) or nil
    self.balls = balls
    self.turn = t.turn == "foe" and s.mode == "match" and "foe" or "you"
    self.group = { you = kind(t.you), foe = kind(t.foe) }
    if (self.group.you == nil) ~= (self.group.foe == nil) or (self.group.you and self.group.you == self.group.foe) then self.group = {} end
    self.shots = max(0, floor(tonumber(t.shots) or 0))
    self.fouls = max(0, floor(tonumber(t.fouls) or 0))
    self.breakShot = t.breakShot and true or false
    self.inHand = t.inHand and true or false
    self.rs = (type(t.rs) == "number" and t.rs >= 1 and t.rs < 2147483647) and floor(t.rs) or 1
    self.winner, self.last, self.pending = nil, nil, nil
    self.phase = "aim"
    if self:Left() == 0 then self.phase = "idle"; return false end
    -- a shot was in the air when the save was made: play it out
    if type(s.angle) == "number" and type(s.power) == "number" then
        self:Shoot(s.angle, s.power)
        self:Run()
    end
    return true
end
