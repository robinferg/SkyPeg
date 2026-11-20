-- Flight Buddy :: Pinball.lua
-- High Tinker Pinball: the new table in Tinker Town, Ironforge (engine only, no WoW API).
-- 480 x 560 units, y down, the table slopes toward the flippers. Tested by luatest/pinsim.lua and e2e_fb.lua.
local ADDON, NS = ...

local Pin = {}
NS.Pinball = Pin

local sqrt, abs, min, max, floor, cos, sin, pi, atan2 =
    math.sqrt, math.abs, math.min, math.max, math.floor, math.cos, math.sin, math.pi, math.atan2 or math.atan

local C = {
    W = 480, H = 560,
    BALL_R = 8,
    GRAVITY = 840,
    STEP = 1 / 600, MAX_STEPS = 60,
    MAX_SPEED = 1500,
    WALL_E = 0.5, POST_E = 0.6, FLIP_E = 0.25,
    BUMPER_R = 27, BUMPER_KICK = 370,
    SLING_KICK = 340,
    FLIP_LEN = 75, FLIP_R = 7, FLIP_PIVOT_R = 9,
    FLIP_REST = 0.47, FLIP_UP = -0.46, FLIP_UP_SPEED = 30, FLIP_DOWN_SPEED = 16,
    LANE_X = 442, LANE_WALL = 430, MID = 239, PLUNGE_Y = 528,
    PLUNGE_MIN = 760, PLUNGE_MAX = 1380, PLUNGE_TIME = 0.9,
    DRAIN_Y = 580,
    BALLS = 3,
    BALL_SAVE = 6, SAUCER_HOLD = 1.1, SAUCER_GRAB = 700,
}
Pin.C = C

Pin.POINTS = {
    bumper = 1000, sling = 110, rollover = 2500, gnome = 25000, target = 5000, tinker = 40000,
    spin = 150, saucer = 15000, lock = 30000, jackpot = 100000, super = 300000, orbit = 7500,
    combo = 10000, quest = 150000, overclock = 5000,
}

-- Gnome quests: started at the Gyrocopter hangar, one at a time, against the clock.
Pin.QUESTS = {
    { key = "repair", name = "Reactor Repair", goal = "Hit the cogs", need = 10, time = 30 },
    { key = "sheep",  name = "Sheep Roundup",  goal = "Hit TINKER targets", need = 3, time = 30 },
    { key = "spin",   name = "Spin Cycle",     goal = "Rip the spinner", need = 25, time = 30 },
    { key = "loop",   name = "Loop-de-Loop",   goal = "Loop the arch", need = 2, time = 35 },
    { key = "lanes",  name = "Lane Inspection", goal = "Light GNOME lamps", need = 3, time = 30 },
}

---------------------------------------------------------------------------
-- The table (built once; the UI draws from the same data)
---------------------------------------------------------------------------
local function ellipseArc(cx, cy, rx, ry, a0, a1, n)
    local pts = {}
    for i = 0, n do
        local a = a0 + (a1 - a0) * i / n
        pts[#pts + 1] = { cx + cos(a) * rx, cy + sin(a) * ry }
    end
    return pts
end

local function mirror(pts) local o = {} for i, p in ipairs(pts) do o[i] = { 436 - p[1], p[2] } end return o end

function Pin.BuildTable()
    -- Geometry traced from the painted playfield (Media/pin/pin_table): every wall, post and
    -- target sits on something you can see in the art.
    local T = { walls = {}, posts = {}, bumpers = {}, slings = {}, rollovers = {}, targets = {} }
    local function poly(pts, kind)
        for i = 1, #pts - 1 do
            T.walls[#T.walls + 1] = { x1 = pts[i][1], y1 = pts[i][2], x2 = pts[i + 1][1], y2 = pts[i + 1][2], kind = kind or "rail" }
        end
    end
    -- the brass arch and side rails
    local dome = ellipseArc(240, 230, 214, 214, pi, 2 * pi, 32)
    local outer = { { 26, 590 }, { 26, 230 } }
    for _, p in ipairs(dome) do outer[#outer + 1] = p end
    outer[#outer + 1] = { 454, 590 }
    poly(outer, "cabinet")
    -- the plunger lane's inner rail
    poly({ { C.LANE_WALL, 590 }, { C.LANE_WALL, 190 } }, "lane")
    -- the five glass lights in the gear arch: roll over them to light G-N-O-M-E
    for i = 1, 5 do T.rollovers[i] = { x = 160 + (i - 1) * 40, y = 75, r = 10, letter = ("GNOME"):sub(i, i) } end
    -- the three reactor cogs (pop bumpers)
    T.bumpers = { { x = 186, y = 145 }, { x = 283, y = 140 }, { x = 240, y = 200 } }
    -- the spinner on its brass bar, left side
    T.spinner = { x1 = 68, x2 = 118, y = 225 }
    T.posts[#T.posts + 1] = { x = 63, y = 225, r = 6 }
    T.posts[#T.posts + 1] = { x = 124, y = 225, r = 6 }
    -- the Gyrocopter hangar's hole
    T.saucer = { x = 131, y = 320, r = 12 }
    -- the TINKER panel on the right: six lamps, the ball strikes the panel's face beside each one
    for i = 1, 6 do
        local cy = 200 + (i - 1) * 23.4
        T.targets[i] = { x1 = 383, y1 = cy - 11, x2 = 383, y2 = cy + 11, up = true, letter = ("TINKER"):sub(i, i), lx = 404, ly = cy }
    end
    poly({ { 386, 172 }, { 418, 168 }, { C.LANE_WALL, 190 } }, "rail")   -- panel top: off left, or into the lane
    poly({ { 386, 172 }, { 386, 350 } }, "backstop")         -- panel face behind the targets
    poly({ { 386, 350 }, { C.LANE_WALL, 358 } }, "rail")      -- panel bottom
    -- the strut off the left wall
    poly({ { 26, 288 }, { 62, 326 } }, "rail")
    -- inlane / outlane rails down to the flippers
    poly({ { 49, 379 }, { 49, 428 }, { 150, 477 } }, "rail")
    poly({ { 405, 379 }, { 405, 433 }, { 318, 477 } }, "rail")
    T.posts[#T.posts + 1] = { x = 49, y = 373, r = 6 }
    T.posts[#T.posts + 1] = { x = 405, y = 373, r = 6 }
    -- slingshots: the blue crystal face kicks
    local sl = { { 90, 364 }, { 92, 410 }, { 127, 436 } }
    poly(sl, "slingback")
    T.slings[1] = { x1 = sl[1][1], y1 = sl[1][2], x2 = sl[3][1], y2 = sl[3][2], side = "L" }
    local sr = { { 366, 364 }, { 364, 410 }, { 329, 436 } }
    poly(sr, "slingback")
    T.slings[2] = { x1 = sr[3][1], y1 = sr[3][2], x2 = sr[1][1], y2 = sr[1][2], side = "R" }
    -- flippers
    T.flippers = {
        { side = "L", px = 148, py = 487, dir = 1 },
        { side = "R", px = 323, py = 487, dir = -1 },
    }
    -- no gate: a ball that drops back into the plunger lane rides it down and is fired out again
    -- kickback in the left outlane (lit by the left crystal)
    T.kickback = { x = 38, y = 470, xmax = 48 }
    -- precompute wall normals
    for _, w in ipairs(T.walls) do
        local dx, dy = w.x2 - w.x1, w.y2 - w.y1
        w.len = sqrt(dx * dx + dy * dy)
        w.dx, w.dy = dx / w.len, dy / w.len
    end
    for _, s in ipairs(T.slings) do
        local dx, dy = s.x2 - s.x1, s.y2 - s.y1
        s.len = sqrt(dx * dx + dy * dy)
        s.dx, s.dy = dx / s.len, dy / s.len
        -- outward normal: toward the middle of the table
        s.nx, s.ny = -s.dy, s.dx
        if (C.MID - (s.x1 + s.x2) / 2) * s.nx < 0 then s.nx, s.ny = -s.nx, -s.ny end
    end
    return T
end

---------------------------------------------------------------------------
-- Gizmos: what the TINKER bank pays out
---------------------------------------------------------------------------
Pin.GIZMOS = {
    { key = "sheep",   name = "Explosive Sheep",            icon = "Spell_Nature_Polymorph",  desc = "Baa-BOOM! +75,000" },
    { key = "chicken", name = "Gnomish Battle Chicken",     icon = "INV_Chicken2_Mechanical",  desc = "Reactor cogs score triple for 30 seconds" },
    { key = "cap",     name = "Gnomish Mind Control Cap",   icon = "INV_Helmet_49",           desc = "Kickback lit and ball save for 15 seconds" },
    { key = "ray",     name = "Gnomish Death Ray",          icon = "INV_Gizmo_08",            desc = "Fires a 200,000 blast... usually" },
    { key = "enlarge", name = "World Enlarger",             icon = "INV_Gizmo_02",            desc = "Flippers grow for 30 seconds" },
    { key = "remote",  name = "Gnomish Universal Remote",   icon = "INV_Gizmo_05",            desc = "Lights a lock at the Gyrocopter hangar" },
    { key = "boots",   name = "Goblin Rocket Boots",        icon = "INV_Gizmo_RocketBoot_01", desc = "Goblin-made. They exploded. +1,000" },
}
Pin.GIZMO = {}
for _, g in ipairs(Pin.GIZMOS) do Pin.GIZMO[g.key] = g end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local Game = {}
Game.__index = Game

function Pin.New(handlers)
    local g = setmetatable({ h = handlers or {} }, Game)
    g.T = Pin.BuildTable()
    g.state = "idle"
    g.score = 0
    g.balls = {}
    g.flips = { L = { a = C.FLIP_REST, w = 0, held = false }, R = { a = C.FLIP_REST, w = 0, held = false } }
    g.time = 0
    g.timers = {}
    g.lanes = {}
    g.rng = NS.Game.RNG(os and os.time and os.time() or 1)
    return g
end

function Game:Emit(ev, ...)
    local f = self.h[ev]
    if f then f(self.h.owner, ...) end
end

function Game:NewGame(seed)
    self.rng = NS.Game.RNG(seed or floor(self.time * 1000) + 1)
    self.score = 0
    self.ballNum = 0
    self.extraBalls = 0
    self.mult = 1
    self.locks, self.lockLit = 0, false
    self.reactor = 0
    self.overload = 0
    self.multiball = false
    self.timers = {}
    self.gizmosWon = {}
    self.stats = { bumpers = 0, slings = 0, spins = 0, targets = 0, gnomes = 0, tinkers = 0, jackpots = 0, locks = 0, saves = 0, quests = 0, loops = 0, combos = 0 }
    self.quest, self.questNext, self.questsDone = nil, 1, {}
    self.extraLit = false
    self.gremlinT = 45
    self.combo, self.lastShot = 0, -99
    self.loopCombo, self.lastLoop = 0, -99
    self.state = "plunge"
    self:NextBall(true)
    self:Emit("newGame")
end

function Game:ResetBallLights()
    self.lanes = { false, false, false, false, false }
    for _, t in ipairs(self.T.targets) do t.up = true end
    self.ballStats = { bumpers = 0, targets = 0, spins = 0, rollovers = 0 }
end

function Game:NextBall(first)
    self.ballNum = self.ballNum + 1
    self.mult = 1
    self.kickback = (self.kickback or false)
    self:ResetBallLights()
    self.balls = {}
    self:LoadPlunger()
    self.saveArmed = true     -- ball save starts when the ball leaves the plunger lane
    self.saveT = 0
    self.state = "plunge"
    self:Emit("ball", self.ballNum)
end

function Game:LoadPlunger()
    self.plunger = 0
    self.pulling = false
    local b = { x = C.LX or C.LANE_X, y = C.PLUNGE_Y, vx = 0, vy = 0, r = C.BALL_R, inLane = true, still = 0, id = (self.ballId or 0) + 1 }
    self.ballId = b.id
    self.balls[#self.balls + 1] = b
    return b
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
function Game:Flipper(side, down)
    local f = self.flips[side]
    if not f then return end
    if down and not f.held then
        self:Emit("flip", side)
        -- lane change: flippers rotate the lit GNOME lanes
        if self.lanes then
            local l = self.lanes
            if side == "L" then l[1], l[2], l[3], l[4], l[5] = l[2], l[3], l[4], l[5], l[1]
            else l[1], l[2], l[3], l[4], l[5] = l[5], l[1], l[2], l[3], l[4] end
        end
    end
    f.held = down and true or false
end

function Game:Plunger(down)
    if down then
        if self.state == "idle" or self.state == "over" then return end
        self.pulling = true
    elseif self.pulling then
        self.pulling = false
        local b
        for _, x in ipairs(self.balls) do if x.inLane and x.y > C.PLUNGE_Y - 12 then b = x end end
        if b then
            local k = min(1, self.plunger / C.PLUNGE_TIME)
            b.vy = -(C.PLUNGE_MIN + (C.PLUNGE_MAX - C.PLUNGE_MIN) * k)
            self:Emit("launch", k)
        end
        self.plunger = 0
    end
end

-- auto-launch (used by ball save and multiball)
function Game:AutoLaunch(b)
    b.vy = -(C.PLUNGE_MIN + (C.PLUNGE_MAX - C.PLUNGE_MIN) * (0.75 + self.rng.next() * 0.2))
end

---------------------------------------------------------------------------
-- Scoring and rules
---------------------------------------------------------------------------
function Game:Add(pts, x, y, why)
    if self:Timer("wizard") then pts = pts * 3 end
    pts = floor(pts)
    self.score = self.score + pts
    self:Emit("points", pts, x, y, why)
end

function Game:Timer(k) return ((self.timers and self.timers[k]) or 0) > 0 end

function Game:Heat(n)
    if self:Timer("overload") then return end
    self.reactor = min(100, self.reactor + n)
    if self.reactor >= 100 then
        self.reactor = 0
        self.timers.overload = 20
        self:Emit("overload")
    end
end

function Game:HitBumper(i, b)
    local s = self.stats
    s.bumpers = s.bumpers + 1
    self.ballStats.bumpers = self.ballStats.bumpers + 1
    local pts = (self:Timer("overclock") and Pin.POINTS.overclock or Pin.POINTS.bumper) * (self:Timer("chicken") and 3 or 1)
    if self.multiball then pts = pts + 5000 end
    local bu = self.T.bumpers[i]
    self:Add(pts, bu.x, bu.y, "bumper")
    self:Heat(3)
    self:Emit("bumper", i)
    self:QuestTick("repair", 1)
    if s.bumpers % 25 == 0 and not self:Timer("overclock") then
        self.timers.overclock = 15
        self:Emit("overclock")
    end
end

function Game:Rollover(i)
    if self.lanes[i] then
        self:Add(500, self.T.rollovers[i].x, self.T.rollovers[i].y, "lane")
        self:Emit("rollover", i, false)
        return
    end
    self.lanes[i] = true
    self.ballStats.rollovers = self.ballStats.rollovers + 1
    self:Add(Pin.POINTS.rollover, self.T.rollovers[i].x, self.T.rollovers[i].y, "lane")
    self:Emit("rollover", i, true)
    self:QuestTick("lanes", 1)
    local all = true
    for k = 1, 5 do all = all and self.lanes[k] end
    if all then
        self.stats.gnomes = self.stats.gnomes + 1
        self.mult = min(5, self.mult + 1)
        for k = 1, 5 do self.lanes[k] = false end
        self:Add(Pin.POINTS.gnome * self.mult, 216, 92, "gnome")
        self:Emit("gnome", self.mult)
        self:Shot()
    end
end

function Game:HitTarget(i)
    local t = self.T.targets[i]
    t.up = false
    self.stats.targets = self.stats.targets + 1
    self.ballStats.targets = self.ballStats.targets + 1
    self:Add(Pin.POINTS.target, t.x1, (t.y1 + t.y2) / 2, "target")
    self:Emit("target", i)
    self:QuestTick("sheep", 1)
    self:Shot()
    for _, x in ipairs(self.T.targets) do if x.up then return end end
    -- TINKER complete: the bank resets and pays out a gizmo
    self.stats.tinkers = self.stats.tinkers + 1
    self:Add(Pin.POINTS.tinker, 360, 280, "tinker")
    self:After(0.6, function() for _, x in ipairs(self.T.targets) do x.up = true end; self:Emit("targetsReset") end)
    self:Gizmo()
end

function Game:Gizmo()
    local list = Pin.GIZMOS
    local gz = list[self.rng.int(1, #list)]
    self.gizmosWon[#self.gizmosWon + 1] = gz.key
    local backfire = false
    if gz.key == "sheep" then
        self:Add(75000, 216, 280, "gizmo")
    elseif gz.key == "chicken" then
        self.timers.chicken = 30
    elseif gz.key == "cap" then
        self.kickback = true
        self.timers.save = max(self.timers.save or 0, 15)
    elseif gz.key == "ray" then
        backfire = self.rng.next() < 0.25
        if not backfire then self:Add(200000, 216, 280, "gizmo") else self:Add(5000, 216, 280, "gizmo") end
    elseif gz.key == "enlarge" then
        self.timers.enlarge = 30
    elseif gz.key == "remote" then
        self.lockLit = true
    elseif gz.key == "boots" then
        self:Add(1000, 216, 280, "gizmo")
    end
    self:Emit("gizmo", gz.key, backfire)
end

function Game:Spin(n)
    self.stats.spins = self.stats.spins + n
    self.ballStats.spins = self.ballStats.spins + n
    self:Add(Pin.POINTS.spin * n, 96, 262, "spin")
    self:Heat(n * 1.5)
    self:Emit("spin", n)
    self:QuestTick("spin", n)
    if n >= 6 then self:Shot() end
end

-- combos: two major shots within 3.5 s of each other pay more each time
function Game:Shot()
    if self.time - self.lastShot < 3.5 then self.combo = self.combo + 1 else self.combo = 1 end
    self.lastShot = self.time
    if self.combo >= 2 then
        self.stats.combos = self.stats.combos + 1
        self:Add(Pin.POINTS.combo * self.combo, 240, 300, "combo")
        self:Emit("combo", self.combo)
    end
end

-- a ball whipping across the top of the arch is a loop
function Game:Loop(b)
    if self.time - self.lastLoop < 4 then self.loopCombo = self.loopCombo + 1 else self.loopCombo = 1 end
    self.lastLoop = self.time
    self.stats.loops = self.stats.loops + 1
    self:Add(Pin.POINTS.orbit * self.loopCombo, b.x, 60, "loop")
    self:Emit("loop", self.loopCombo)
    self:QuestTick("loop", 1)
    self:Shot()
end

function Game:StartQuest()
    local Q = Pin.QUESTS
    for k = 0, #Q - 1 do
        local i = (self.questNext - 1 + k) % #Q + 1
        if not self.questsDone[Q[i].key] then
            local q = Q[i]
            self.questNext = i % #Q + 1
            self.quest = { key = q.key, name = q.name, goal = q.goal, need = q.need, have = 0, t = q.time }
            self:Emit("questStart", q.name, q.goal, q.need, q.time)
            return true
        end
    end
    return false
end

function Game:QuestTick(key, n)
    local q = self.quest
    if not q or q.key ~= key then return end
    q.have = q.have + n
    if q.have < q.need then self:Emit("questProgress", q.have, q.need); return end
    self.quest = nil
    self.questWait = 8
    self.questsDone[key] = true
    self.stats.quests = self.stats.quests + 1
    local done = 0
    for _ in pairs(self.questsDone) do done = done + 1 end
    local pts = Pin.POINTS.quest * (1 + 0.5 * (done - 1))
    self:Add(pts, 240, 300, "quest")
    self:Emit("questDone", q.name, pts, done)
    if done == 3 then self.extraLit = true; self:Emit("extraLit") end
    if done >= #Pin.QUESTS then
        self.questsDone = {}
        self.timers.wizard = 30
        self:Emit("wizard")
    end
end

function Game:Saucer(b)
    -- captured: pay out, maybe lock, then kick back out
    b.held = C.SAUCER_HOLD
    b.vx, b.vy = 0, 0
    local s = self.T.saucer
    b.x, b.y = s.x, s.y
    self:Shot()
    if self:Timer("rust") then
        self.timers.rust = 0
        self:Add(25000, s.x, s.y, "fixed")
        self:Emit("rustFixed")
    end
    if self.extraLit then
        self.extraLit = false
        self.extraBalls = self.extraBalls + 1
        self:Emit("extraBall")
    end
    if self.quest then
        self.quest.t = self.quest.t + 10
        self:Emit("questTime", 10)
    elseif not self.multiball then
        self:StartQuest()
    end
    if self:Timer("overload") then
        self.timers.overload = 0
        self.stats.jackpots = self.stats.jackpots + 1
        self:Add(Pin.POINTS.super, s.x, s.y, "super")
        self:Emit("super")
    elseif self.multiball then
        self.stats.jackpots = self.stats.jackpots + 1
        self:Add(Pin.POINTS.jackpot, s.x, s.y, "jackpot")
        self:Emit("jackpot")
    elseif self.lockLit or self.locks < 2 and self.rng.next() < 0.5 then
        self.lockLit = false
        self.locks = self.locks + 1
        self.stats.locks = self.stats.locks + 1
        self:Add(Pin.POINTS.lock, s.x, s.y, "lock")
        if self.locks >= 3 then
            self.locks = 0
            self:StartMultiball()
        else
            self:Emit("lock", self.locks)
        end
    else
        self:Add(Pin.POINTS.saucer, s.x, s.y, "saucer")
        self:Emit("saucer")
    end
end

function Game:StartMultiball()
    self.multiball = true
    self.timers.save = max(self.timers.save or 0, 12)
    for _ = 1, 2 do
        local nb = self:LoadPlunger()
        nb.y = C.PLUNGE_Y - 30 * (#self.balls - 1)
        self:AutoLaunch(nb)
    end
    self:Emit("multiball")
end

function Game:After(delay, fn)
    self.timed = self.timed or {}
    self.timed[#self.timed + 1] = { t = delay, fn = fn }
end

---------------------------------------------------------------------------
-- Physics
---------------------------------------------------------------------------
local function closestOnSeg(px, py, x1, y1, dx, dy, len)
    local t = (px - x1) * dx + (py - y1) * dy
    if t < 0 then t = 0 elseif t > len then t = len end
    return x1 + dx * t, y1 + dy * t, t
end

-- bounce ball b off a surface point (qx,qy) with min distance rr; surface velocity (sx,sy)
local function collide(b, qx, qy, rr, e, sx, sy, friction)
    local dx, dy = b.x - qx, b.y - qy
    local d2 = dx * dx + dy * dy
    if d2 >= rr * rr or d2 < 1e-9 then return false end
    local d = sqrt(d2)
    local nx, ny = dx / d, dy / d
    b.x, b.y = qx + nx * rr, qy + ny * rr
    sx, sy = sx or 0, sy or 0
    local rvx, rvy = b.vx - sx, b.vy - sy
    local vn = rvx * nx + rvy * ny
    if vn < 0 then
        local tx, ty = rvx - vn * nx, rvy - vn * ny
        local fr = friction or 0.985
        rvx, rvy = tx * fr - vn * e * nx, ty * fr - vn * e * ny
        b.vx, b.vy = rvx + sx, rvy + sy
        return true, nx, ny, -vn
    end
    return true, nx, ny, 0
end

function Game:FlipperGeom(f, side)
    local T = self.T
    local fl = side == "L" and T.flippers[1] or T.flippers[2]
    local len = C.FLIP_LEN * (self:Timer("enlarge") and 1.3 or 1)
    local ca, sa = cos(f.a), sin(f.a)
    local ex, ey = fl.dir * ca, sa
    return fl.px, fl.py, ex, ey, len, fl
end

function Game:StepFlippers(h)
    for side, f in pairs(self.flips) do
        local target = f.held and C.FLIP_UP or C.FLIP_REST
        local prev = f.a
        local up = C.FLIP_UP_SPEED * (self:Timer("rust") and 0.45 or 1)
        if f.a > target then f.a = max(target, f.a - up * h)
        elseif f.a < target then f.a = min(target, f.a + C.FLIP_DOWN_SPEED * h) end
        f.w = (f.a - prev) / h
    end
end

function Game:StepBall(b, h)
    local T = self.T
    if b.held then
        b.held = b.held - h
        if b.held <= 0 then
            b.held = nil
            local a = -pi / 2 + 0.55 + (self.rng.next() - 0.5) * 0.3   -- up and to the right, toward the cogs
            b.vx, b.vy = cos(a) * 520, sin(a) * 520
            b.y = b.y - 2
            b.saucerCD = 1.6
            self:Emit("kick")
        end
        return
    end
    b.vy = b.vy + C.GRAVITY * h
    local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
    if sp > C.MAX_SPEED then b.vx, b.vy = b.vx / sp * C.MAX_SPEED, b.vy / sp * C.MAX_SPEED end
    local ox, oy = b.x, b.y
    b.x, b.y = b.x + b.vx * h, b.y + b.vy * h
    local r = b.r
    -- the plunger tip holds the ball in its lane
    if b.x > C.LANE_WALL and b.y > C.PLUNGE_Y then
        b.y = C.PLUNGE_Y
        if b.vy > 0 then b.vy = 0 end
        b.vx = 0
        b.inLane = true
        if b.returned and self.state == "play" then
            b.returned = nil
            self:AutoLaunch(b)
            self:Emit("kick")
        end
    end
    if not b.inLane and b.x > C.LANE_WALL + 1 and b.y > 200 then b.inLane = true; b.returned = true end
    if b.inLane and b.y < 172 then
        b.inLane = false
        if self.saveArmed then self.saveArmed = false; self.saveT = C.BALL_SAVE end
        self:Emit("skillshot")
    end
    -- walls
    for _, w in ipairs(T.walls) do
        local qx, qy = closestOnSeg(b.x, b.y, w.x1, w.y1, w.dx, w.dy, w.len)
        collide(b, qx, qy, r, w.kind == "slingback" and 0.4 or C.WALL_E)
    end
    for _, p in ipairs(T.posts) do collide(b, p.x, p.y, r + p.r, C.POST_E) end
    -- one-way gate over the plunger lane: launched balls pass under it, falling ones roll off it
    if not b.inLane and T.gate then
        local g = T.gate
        local qx, qy = closestOnSeg(b.x, b.y, g.x1, g.y1, g.dx, g.dy, g.len)
        collide(b, qx, qy, r, 0.3)
    end
    -- slingshots
    for i, s in ipairs(T.slings) do
        local qx, qy = closestOnSeg(b.x, b.y, s.x1, s.y1, s.dx, s.dy, s.len)
        local hit, nx, ny, vn = collide(b, qx, qy, r, 0.55)
        if hit and vn > 40 and nx * s.nx + ny * s.ny > 0.5 then
            b.vx, b.vy = b.vx + s.nx * C.SLING_KICK, b.vy + s.ny * C.SLING_KICK
            self.stats.slings = self.stats.slings + 1
            self:Add(Pin.POINTS.sling, qx, qy, "sling")
            self:Emit("sling", i)
        end
    end
    -- pop bumpers
    for i, bu in ipairs(T.bumpers) do
        local hit, nx, ny = collide(b, bu.x, bu.y, r + C.BUMPER_R, 0.4)
        if hit and (b.bumpT or 0) <= 0 then
            b.vx, b.vy = b.vx + nx * C.BUMPER_KICK, b.vy + ny * C.BUMPER_KICK
            b.bumpT = 0.05
            self:HitBumper(i, b)
        end
    end
    if b.bumpT then b.bumpT = b.bumpT - h end
    -- drop targets
    for i, t in ipairs(T.targets) do
        if t.up then
            local qx, qy = closestOnSeg(b.x, b.y, t.x1, t.y1, 0, 1, t.y2 - t.y1)
            local hit, nx, ny, vn = collide(b, qx, qy, r, 0.4)
            if hit and vn > 60 then self:HitTarget(i) end
        end
    end
    -- flippers: a moving capsule; the ball takes on the flipper's surface speed where it touches
    for side, f in pairs(self.flips) do
        local px, py, ex, ey, len = self:FlipperGeom(f, side)
        local qx, qy, t = closestOnSeg(b.x, b.y, px, py, ex, ey, len)
        local rad = C.FLIP_PIVOT_R + (C.FLIP_R - C.FLIP_PIVOT_R) * (t / len)
        -- surface velocity = w x r (rotation about the pivot); the right flipper turns the other way
        local rx, ry = qx - px, qy - py
        local w = f.w * (side == "L" and 1 or -1)
        local sx, sy = -w * ry, w * rx
        local hit, nx, ny, vn = collide(b, qx, qy, r + rad, C.FLIP_E, sx, sy, 0.995)
        if hit and vn > 300 and f.w < -1 then self:Emit("flipHit", side, vn) end
    end
    -- sensors: GNOME lanes
    for i, ro in ipairs(T.rollovers) do
        if abs(b.x - ro.x) < 12 and oy < ro.y and b.y >= ro.y and b.vy > 0 then self:Rollover(i) end
    end
    -- loop: whipping across the top of the arch (the launch's own trip over the top doesn't count)
    if b.inLane then b.fresh = true elseif b.y > 200 then b.fresh = nil end
    if not b.inLane and not b.fresh and b.y < 45 and abs(b.vx) > 300 and ((ox < 240 and b.x >= 240) or (ox > 240 and b.x <= 240)) then
        self:Loop(b)
    end
    -- spinner: passing the gate spins it, faster balls spin it more
    local spn = T.spinner
    if b.x > spn.x1 and b.x < spn.x2 and ((oy > spn.y and b.y <= spn.y) or (oy < spn.y and b.y >= spn.y)) then
        self:Spin(max(1, floor(abs(b.vy) / 180)))
    end
    -- saucer
    local sa = T.saucer
    local sdx, sdy = b.x - sa.x, b.y - sa.y
    if b.saucerCD then b.saucerCD = b.saucerCD - h; if b.saucerCD <= 0 then b.saucerCD = nil end end
    if not b.saucerCD and sdx * sdx + sdy * sdy < sa.r * sa.r and sp < C.SAUCER_GRAB then self:Saucer(b) end
    -- kickback in the left outlane
    if self.kickback and b.x < T.kickback.xmax and b.y > T.kickback.y and b.vy > 0 then
        self.kickback = false
        b.vy = -1000; b.vx = 40
        self:Emit("kickback")
    end
    -- stuck? rattle it free (a real table gets a nudge)
    local cradled = b.y > 430 and (self.flips.L.held or self.flips.R.held)
    if sp < 25 and not b.inLane and not cradled then
        b.still = (b.still or 0) + h
        if b.still > 2.5 then
            b.still = 0
            b.vx, b.vy = (self.rng.next() - 0.5) * 300, -260
            self:Emit("nudge")
        end
    else
        b.still = 0
    end
end

function Game:Step(h)
    self.time = self.time + h
    self:StepFlippers(h)
    for k, v in pairs(self.timers) do if v > 0 then self.timers[k] = v - h end end
    if self.saveT and self.saveT > 0 then self.saveT = self.saveT - h end
    -- Thermaplugg's gremlins: every so often they rust the flippers until you fix them at the hangar
    if self.state == "play" and not self.multiball and not self:Timer("rust") then
        self.gremlinT = (self.gremlinT or 45) - h
        if self.gremlinT <= 0 then
            self.gremlinT = 40 + self.rng.next() * 30
            self.timers.rust = 12
            self:Emit("rust")
        end
    end
    if not self.quest and self.state == "play" and not self.multiball then
        self.questWait = (self.questWait or 4) - h
        if self.questWait <= 0 then self.questWait = 8; self:StartQuest() end
    end
    if self.quest and self.state == "play" then
        self.quest.t = self.quest.t - h
        if self.quest.t <= 0 then
            local q = self.quest
            self.quest = nil
            self.questWait = 8
            self:Emit("questFail", q.name)
        end
    end
    if self.timed then
        for i = #self.timed, 1, -1 do
            local e = self.timed[i]
            e.t = e.t - h
            if e.t <= 0 then table.remove(self.timed, i); e.fn() end
        end
    end
    if self.pulling then self.plunger = min(C.PLUNGE_TIME, self.plunger + h) end
    for i = #self.balls, 1, -1 do
        local b = self.balls[i]
        self:StepBall(b, h)
        if b.y > C.DRAIN_Y then
            table.remove(self.balls, i)
            self:Drain(b)
        end
    end
end

function Game:BallSaveOn() return (self.saveT or 0) > 0 or self:Timer("save") end

function Game:Drain(b)
    if self:BallSaveOn() and not self.multiball then
        self.stats.saves = self.stats.saves + 1
        local nb = self:LoadPlunger()
        self:AutoLaunch(nb)
        self:Emit("saved")
        return
    end
    if #self.balls > 0 then
        if #self.balls == 1 and self.multiball then
            self.multiball = false
            self:Emit("multiballOver")
        end
        self:Emit("drainExtra")
        return
    end
    -- last ball gone: end of ball bonus
    self.multiball = false
    if self.quest then self:Emit("questFail", self.quest.name); self.quest = nil end
    self.questWait = 4
    local bs = self.ballStats
    local bonus = (bs.bumpers * 250 + bs.targets * 2000 + bs.spins * 100 + bs.rollovers * 1500) * self.mult
    self.score = self.score + bonus
    self.state = "drained"
    self.timers = {}
    self.kickback = false
    self:Emit("drain", bonus, self.mult)
    if self.extraBalls > 0 then
        self.extraBalls = self.extraBalls - 1
        self.ballNum = self.ballNum - 1
    end
    if self.ballNum >= C.BALLS then
        self.state = "over"
        self:Emit("over", self.score)
    end
end

function Game:Continue()
    if self.state == "drained" then self:NextBall() end
end

function Game:Update(dt)
    if self.state ~= "plunge" and self.state ~= "play" then return end
    dt = min(dt, 0.05)
    self.acc = (self.acc or 0) + dt
    local steps = 0
    while self.acc >= C.STEP and steps < C.MAX_STEPS do
        self.acc = self.acc - C.STEP
        steps = steps + 1
        self:Step(C.STEP)
        if self.state ~= "plunge" and self.state ~= "play" then self.acc = 0; break end
    end
    if steps >= C.MAX_STEPS then self.acc = 0 end
    if self.state == "plunge" or self.state == "play" then
        local any = false
        for _, b in ipairs(self.balls) do if not b.inLane then any = true end end
        if #self.balls > 0 then self.state = any and "play" or "plunge" end
    end
end
