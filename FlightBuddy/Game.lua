-- SkyPeg :: Game.lua
-- Pure game simulation (no WoW API calls) so it can be tested outside the client.
local ADDON, NS = ...

local Game = {}
NS.Game = Game

local sqrt, abs, min, max, floor = math.sqrt, math.abs, math.min, math.max, math.floor
local cos, sin, pi, atan2 = math.cos, math.sin, math.pi, math.atan2

local C = {
    W = 480, H = 560,             -- board size in UI units
    LX = 240, LY = 34,            -- launcher pivot
    BARREL = 24,                  -- distance from pivot to muzzle
    BALL_R = 7, PEG_R = 9,
    GRAVITY = 600, LAUNCH = 530,
    PEG_E = 0.76, WALL_E = 0.86,
    STEP = 1 / 240, MAX_STEPS = 72,
    MAX_SPEED = 950,
    BALLS = 10,
    BUCKET_Y = 540, BUCKET_W = 76, BUCKET_SPEED = 115, RIM_R = 5,
    MIN_ANGLE = math.rad(3),
}
Game.C = C

Game.POINTS   = { blue = 10, orange = 100, green = 10, purple = 500 }
-- {fraction of orange pegs cleared, multiplier}
Game.MULT     = { { 0, 1 }, { 0.40, 2 }, { 0.60, 3 }, { 0.76, 5 }, { 0.88, 10 } }
-- Numbers below follow Peggle Deluxe (PopCap's patent US8128476 + published guides)
Game.FREEBALL = { 25000, 75000, 125000 }   -- one-shot score thresholds that award a free ball
Game.FEVER_SLOTS = { 10000, 50000, 100000, 50000, 10000 }
Game.FEVER_TOP = 506      -- top of the Bloodlust treasure chests; stone pillars stand between them
Game.PILLAR_R = 6
Game.BUMPER_R = 17        -- pinball bumpers on top of the pillars (and half ones on the walls): they kick the ball along the row
Game.BUMPER_KICK = { 360, 500 }
Game.FEVER_POINTS = { blue = 1000, green = 1000, purple = 10000 } -- pegs hit during Extreme Fever
Game.WIN_BALL_BONUS = 10000                 -- each unused ball
Game.STYLE = {                              -- style shots
    long      = { "Long Shot", 25000 },
    superlong = { "Super Long Shot", 50000 },
    attack    = { "Orange Attack", 50000 },
    skills    = { "Free Ball Skills", 5000 },
    lucky     = { "Lucky Bounce", 25000 },
    kick      = { "Kick the Bucket", 25000 },
}
Game.LONG_SHOT, Game.SUPER_LONG_SHOT = 210, 320 -- distance between two non-blue pegs hit in a row
Game.STUCK_SECONDS = 0.5 -- a lit peg must have been lit this long before a trapped ball can remove it
Game.TRAP_RADIUS = 12    -- ball counts as trapped while it stays inside this circle...
Game.TRAP_TIME = 0.6     -- ...for this long
Game.CRAWL_WINDOW = 1.2  -- or while it gets less than CRAWL_DIST anywhere over this long (rocking in a dip)
Game.CRAWL_DIST = 34
Game.SHOT_TIDY = 12      -- a ball still in play after this long clears the lit runes around it

Game.POWERS = {
    multi = { name = "Chain Lightning", desc = "splits off a second ball", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
    sight = { name = "Mind Vision",     desc = "full aim guide for 3 shots", icon = "Interface\\Icons\\Spell_Holy_MindVision" },
    fire  = { name = "Fireball",        desc = "ball burns through pegs",    icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
}
Game.POWER_KEYS = { "multi", "sight", "fire" }

---------------------------------------------------------------------------
-- Heroes: pick one before a run; every Hero Rune (green) you hit fires
-- that hero's power. Thrall and Jaina start unlocked; clearing stages
-- unlocks the rest in this order.
---------------------------------------------------------------------------
local I = "Interface\\Icons\\"
Game.HEROES = {
    { key = "thrall",   name = "Thrall",   title = "Warchief of the Horde",      faction = "horde",
      power = "Chain Lightning", desc = "Lightning arcs from the Hero Rune to the 6 nearest runes.",          icon = I .. "Spell_Nature_ChainLightning" },
    { key = "jaina",    name = "Jaina Proudmoore", title = "Lady of Theramore",   faction = "alliance",
      power = "Arcane Missiles", desc = "Two more arcane missiles split off your ball.",                      icon = I .. "Spell_Nature_StarFall" },
    { key = "rexxar",   name = "Rexxar",   title = "Champion of the Horde",      faction = "horde",
      power = "Misha",           desc = "For two shots, Misha bats your falling ball back up (once a shot).", icon = I .. "Ability_Hunter_Pet_Bear" },
    { key = "magni",    name = "Magni Bronzebeard", title = "King of Ironforge",  faction = "alliance",
      power = "Earthquake",      desc = "The board shakes and 5 runes crack open, including a crystal.",      icon = I .. "Spell_Nature_Earthquake" },
    { key = "sylvanas", name = "Sylvanas Windrunner", title = "Banshee Queen",   faction = "horde",
      power = "Black Arrow",     desc = "Your next 3 shots show their whole path.",                           icon = I .. "Ability_TheBlackArrow" },
    { key = "tyrande",  name = "Tyrande Whisperwind", title = "High Priestess of Elune", faction = "alliance",
      power = "Starfall",        desc = "Two stars fall from the sky and break what they hit.",             icon = I .. "Ability_Druid_Starfall" },
    { key = "voljin",   name = "Vol'jin",  title = "Shadow Hunter of the Darkspear", faction = "horde",
      power = "Hex",             desc = "12 runes turn into frogs. Hit a frog and it hops onto the next rune and breaks it too.",             icon = I .. "Spell_Shaman_Hex" },
    { key = "bolvar",   name = "Bolvar Fordragon", title = "Highlord of Stormwind", faction = "alliance",
      power = "Consecration",    desc = "The gryphon catcher grows huge for 4 shots.",                         icon = I .. "Spell_Holy_InnerFire" },
    { key = "cairne",   name = "Cairne Bloodhoof", title = "High Chieftain of the Tauren", faction = "horde",
      power = "War Stomp",       desc = "Shatters every rune close to the Hero Rune.",                         icon = I .. "Ability_WarStomp" },
}
Game.HERO = {}
for i, h in ipairs(Game.HEROES) do h.order = i; Game.HERO[h.key] = h end
Game.HERO_START = { thrall = true, jaina = true }
-- stages cleared (best run) needed to unlock each later hero
Game.HERO_UNLOCK = { rexxar = 1, magni = 2, sylvanas = 4, tyrande = 6, voljin = 8, bolvar = 10, cairne = 12 }

function Game:BucketW()
    return (self.wideShots or 0) > 0 and C.BUCKET_W * 2.6 or C.BUCKET_W
end

---------------------------------------------------------------------------
-- Deterministic RNG (Park-Miller; exact in double precision)
---------------------------------------------------------------------------
function Game.RNG(seed)
    local s = floor(abs(seed or 1)) % 2147483646 + 1
    local r = {}
    function r.next()
        s = (s * 16807) % 2147483647
        return (s - 1) / 2147483646
    end
    function r.range(a, b) return a + (b - a) * r.next() end
    function r.int(a, b) return a + floor(r.next() * (b - a + 1)) end
    return r
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function Game.New(handlers)
    local g = setmetatable({}, { __index = Game })
    g.h = handlers or {}
    g.state = "idle"
    g.score, g.level = 0, 1
    g.balls, g.pegs = {}, {}
    g.time = 0
    return g
end

function Game:Emit(ev, ...)
    local f = self.h[ev]
    if f then f(...) end
end

function Game:NewRun(seed)
    self.runSeed = seed or 12345
    self.level = 1
    self.score = 0
    self.bestShot = 0
    self:StartLevel()
    self.saved = nil
    self:Serialize()
end

function Game:StartLevel(mask)
    local pegs, info = NS.Levels.Build(self.level, self.runSeed)
    self.pegs, self.info = pegs, info
    self.balls = {}
    self.ballsLeft = C.BALLS
    -- scores are per level: every level starts from zero
    self.score = 0
    self.levelStartScore = 0
    self.orangeTotal, self.orangeLit = 0, 0
    for _, p in ipairs(pegs) do
        if p.kind == "orange" then self.orangeTotal = self.orangeTotal + 1 end
    end
    if mask then
        for i, p in ipairs(pegs) do
            if mask:sub(i, i) == "0" then
                p.alive = false
                if p.kind == "orange" then self.orangeLit = self.orangeLit + 1 end
            end
        end
    end
    self.fever, self.feverSlow, self.clutch = false, 0, false
    self.sightShots = 0
    self.mishaShots, self.wideShots = 0, 0
    self.turn = 0
    self.rng = Game.RNG(self.runSeed + self.level * 977)
    self.bucket = { x = C.W / 2, dir = 1 }
    self.state = "aim"
    self:AssignPurple()
    self:Emit("levelStart", self.level, info)
end

function Game:NextLevel()
    self.level = self.level + 1
    self:StartLevel()
end

function Game:RetryLevel()
    self:StartLevel()
end

---------------------------------------------------------------------------
-- Save / restore (only between shots)
---------------------------------------------------------------------------
function Game:Serialize()
    if self.state ~= "aim" then return self.saved end
    local t = {}
    for i, p in ipairs(self.pegs) do t[i] = p.alive and "1" or "0" end
    self.saved = {
        v = 1, seed = self.runSeed, level = self.level, score = self.score,
        levelStartScore = self.levelStartScore, balls = self.ballsLeft,
        sight = self.sightShots, mask = table.concat(t), bestShot = self.bestShot,
        misha = self.mishaShots, wide = self.wideShots, frogs = self:FrogMask(),
    }
    return self.saved
end

function Game:FrogMask()
    local t, any = {}, false
    for i, p in ipairs(self.pegs) do t[i] = p.frog and "1" or "0"; any = any or p.frog end
    return any and table.concat(t) or nil
end

function Game:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or not s.seed then return false end
    self.runSeed, self.level = s.seed, s.level or 1
    self.bestShot = s.bestShot or 0
    self:StartLevel(s.mask)
    -- older saves kept a running total: keep just this level's part of it
    self.score = max(0, (s.score or 0) - (s.levelStartScore or 0))
    self.levelStartScore = 0
    self.ballsLeft = s.balls or C.BALLS
    self.sightShots = s.sight or 0
    self.mishaShots, self.wideShots = s.misha or 0, s.wide or 0
    if s.frogs then
        for i, p in ipairs(self.pegs) do if s.frogs:sub(i, i) == "1" then p.frog = true end end
    end
    if self.orangeLit >= self.orangeTotal or self.ballsLeft <= 0 then
        self:StartLevel() -- saved state was terminal; just replay the level
    end
    -- what was just restored is the fallback for a save asked for while a ball is in flight
    -- (Serialize only works between shots): without it, closing the window during the first shot
    -- of a session saved nothing at all and the run was gone at the next login
    self.saved = nil
    self:Serialize()
    return true
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function Game:Multiplier()
    if self.orangeTotal == 0 then return 1 end
    local frac = self.orangeLit / self.orangeTotal
    local m = 1
    for _, step in ipairs(Game.MULT) do
        if frac >= step[1] then m = step[2] end
    end
    return m
end

function Game:OrangeLeft() return self.orangeTotal - self.orangeLit end

function Game.ClampAngle(a)
    if a < 0 then a = (a < -pi / 2) and (pi - C.MIN_ANGLE) or C.MIN_ANGLE end
    return max(C.MIN_ANGLE, min(pi - C.MIN_ANGLE, a))
end

function Game:AssignPurple()
    local prev = self.purple
    if prev and prev.alive and not prev.lit then prev.kind = "blue" end
    self.purple = nil
    local cands = {}
    for _, p in ipairs(self.pegs) do
        if p.alive and not p.lit and p.kind == "blue" then cands[#cands + 1] = p end
    end
    if #cands > 0 then
        local p = cands[self.rng.int(1, #cands)]
        p.kind = "purple"
        self.purple = p
    end
    self:Emit("purple", self.purple, prev)
end

local function NewBall(x, y, vx, vy)
    return { x = x, y = y, vx = vx, vy = vy, r = C.BALL_R, age = 0, slow = 0,
             fire = 0, travel = 0, hits = 0, alive = true, trapped = 0 }
end

function Game:FeverSlotAt(x)
    local n = #Game.FEVER_SLOTS
    return max(1, min(n, floor(x / (C.W / n)) + 1))
end

---------------------------------------------------------------------------
-- Firing
---------------------------------------------------------------------------
function Game:Fire(angle)
    if self.state ~= "aim" or self.ballsLeft <= 0 then return false end
    angle = Game.ClampAngle(angle)
    local dx, dy = cos(angle), sin(angle)
    self.ballsLeft = self.ballsLeft - 1
    self.shotScore, self.shotHits, self.freeGiven = 0, 0, 0
    self.shotOrangeStart, self.attackGiven = self.orangeLit, false
    self.turn = self.turn + 1
    self.balls = { NewBall(C.LX + dx * C.BARREL, C.LY + dy * C.BARREL, dx * C.LAUNCH, dy * C.LAUNCH) }
    self.acc = 0
    if self.sightShots > 0 then self.sightShots = self.sightShots - 1 end
    self.mishaUsed = false
    self.state = "shot"
    self:Emit("fire", angle)
    return true
end

---------------------------------------------------------------------------
-- Per-frame update (dt in real seconds)
---------------------------------------------------------------------------
function Game:Update(dt)
    if self.state == "idle" then return end
    local ts = 1
    if self.feverSlow > 0 then
        self.feverSlow = self.feverSlow - dt
        ts = 0.25
    elseif self.clutch then
        ts = 0.38
    end
    if self.noSlowMo then ts = 1 end
    local sdt = dt * ts
    self.time = self.time + sdt
    self.timeScale = ts

    if self.state ~= "shot" then self:MoveWorld(sdt) end

    if self.state == "shot" then
        self.acc = (self.acc or 0) + sdt
        local steps = 0
        -- the world moves in the same fixed steps as the ball, so a shot plays out
        -- exactly the same at any frame rate (and exactly as Mind Vision showed it)
        while self.acc >= C.STEP and steps < C.MAX_STEPS and self.state == "shot" do
            self.acc = self.acc - C.STEP
            steps = steps + 1
            self:MoveWorld(C.STEP)
            self:Step(C.STEP)
        end
        if steps >= C.MAX_STEPS then self.acc = 0 end
    elseif self.state == "clearing" then
        self.popTimer = self.popTimer - dt
        while self.popTimer <= 0 and self.state == "clearing" do
            local p = table.remove(self.clearQueue, 1)
            if p then
                p.alive = false
                self:Emit("pop", p)
                self.popTimer = self.popTimer + (#self.clearQueue > 30 and 0.018 or 0.032)
            else
                self:EndTurn()
            end
        end
    end
end

function Game:MoveWorld(dt)
    -- bucket glides back and forth
    local b = self.bucket
    local bw = self:BucketW()
    local lo, hi = bw / 2 + 6, C.W - bw / 2 - 6
    b.x = b.x + b.dir * C.BUCKET_SPEED * dt
    if b.x > hi then b.x, b.dir = hi, -1 elseif b.x < lo then b.x, b.dir = lo, 1 end
    -- moving pegs: orbits (round a centre), slides (back and forth along a line), spinning bricks
    for _, p in ipairs(self.pegs) do
        if p.alive then
            local o, sl, br = p.orbit, p.slide, p.brick
            if o then
                o.a = o.a + o.spd * dt
                local nx, ny = o.cx + cos(o.a) * o.rad, o.cy + sin(o.a) * o.rad
                if br and o.face then br.ang = o.a + pi / 2; br.cx_ = nil end
                if dt > 0 then p.vx, p.vy = (nx - p.x) / dt, (ny - p.y) / dt end
                p.x, p.y = nx, ny
            elseif sl then
                sl.t = sl.t + sl.spd * dt
                local k = 0.5 - 0.5 * cos(sl.t)            -- eases at each end
                local nx, ny = sl.x1 + (sl.x2 - sl.x1) * k, sl.y1 + (sl.y2 - sl.y1) * k
                if dt > 0 then p.vx, p.vy = (nx - p.x) / dt, (ny - p.y) / dt end
                p.x, p.y = nx, ny
            end
            if br and br.spin and not (o and o.face) then
                br.ang = br.ang + br.spin * dt
                br.cx_ = nil
            end
        end
    end
end

function Game:Step(h)
    local pegs, W = self.pegs, C.W
    local G, PE = C.GRAVITY, C.PEG_E
    local anyAlive = false
    local lastOrange = (self:OrangeLeft() == 1 and not self.fever) and self:FindLastOrange() or nil
    local clutch = false

    for bi = 1, #self.balls do
        local b = self.balls[bi]
        if b.alive then
            local r = b.r
            b.age = b.age + h
            b.vy = b.vy + G * h
            local sp2 = b.vx * b.vx + b.vy * b.vy
            if sp2 > C.MAX_SPEED * C.MAX_SPEED then
                local k = C.MAX_SPEED / sqrt(sp2)
                b.vx, b.vy = b.vx * k, b.vy * k
            end
            local px, py = b.x, b.y
            b.x = b.x + b.vx * h
            b.y = b.y + b.vy * h
            b.travel = b.travel + abs(b.x - px) + abs(b.y - py)
            if b.fire > 0 then b.fire = b.fire - h end

            -- walls
            if b.x < r then b.x, b.vx = r, abs(b.vx) * C.WALL_E; b.wall = true
            elseif b.x > W - r then b.x, b.vx = W - r, -abs(b.vx) * C.WALL_E; b.wall = true end
            if b.y < r then b.y, b.vy = r, abs(b.vy) * C.WALL_E end

            -- pegs (round runes, and bricks: rune-stone bars that are a segment with thickness)
            for i = 1, #pegs do
                local p = pegs[i]
                local br = p.alive and p.brick
                if br then
                    local L = br.len
                    local ex, ey = br.cx_, br.cy_
                    if not ex then ex, ey = cos(br.ang), sin(br.ang); br.cx_, br.cy_ = ex, ey end
                    local rx, ry = b.x - p.x, b.y - p.y
                    local rr = p.r + r
                    if rx < L + rr and rx > -L - rr and ry < L + rr and ry > -L - rr then
                        local t = rx * ex + ry * ey
                        if t > L then t = L elseif t < -L then t = -L end
                        local qx, qy = p.x + ex * t, p.y + ey * t
                        local dx, dy = b.x - qx, b.y - qy
                        local d2 = dx * dx + dy * dy
                        if d2 < rr * rr then
                            local d = sqrt(d2)
                            if d < 1e-4 then dx, dy, d = -ey, ex, 1 end
                            local nx, ny = dx / d, dy / d
                            if not p.lit then self:HitPeg(p, b) end
                            if b.fire <= 0 then
                                b.x, b.y = qx + nx * rr, qy + ny * rr
                                -- the contact point moves with the brick (slides and spins)
                                local w = br.spin or 0
                                local pvx = (p.vx or 0) - w * (qy - p.y)
                                local pvy = (p.vy or 0) + w * (qx - p.x)
                                local rvx, rvy = b.vx - pvx, b.vy - pvy
                                local vn = rvx * nx + rvy * ny
                                if vn < 0 then
                                    b.vx = b.vx - (1 + PE) * vn * nx
                                    b.vy = b.vy - (1 + PE) * vn * ny
                                    if vn < -110 then self:Emit("bounce", p, -vn) end
                                end
                            end
                        end
                    end
                elseif p.alive then
                    local dx, dy = b.x - p.x, b.y - p.y
                    local rr = p.r + r
                    if dx < rr and dx > -rr and dy < rr and dy > -rr then
                        local d2 = dx * dx + dy * dy
                        if d2 < rr * rr then
                            local d = sqrt(d2)
                            if d < 1e-4 then dx, dy, d = 0, -1, 1 end
                            local nx, ny = dx / d, dy / d
                            if not p.lit then self:HitPeg(p, b) end
                            if b.fire <= 0 then
                                b.x, b.y = p.x + nx * rr, p.y + ny * rr
                                local pvx, pvy = p.vx or 0, p.vy or 0
                                local rvx, rvy = b.vx - pvx, b.vy - pvy
                                local vn = rvx * nx + rvy * ny
                                if vn < 0 then
                                    local e = p.frog and 1.0 or PE
                                    b.vx = b.vx - (1 + e) * vn * nx
                                    b.vy = b.vy - (1 + e) * vn * ny
                                    if vn < -110 then self:Emit("bounce", p, -vn) end
                                end
                            end
                        end
                    end
                end
            end

            -- Bloodlust: solid pillars between the treasure chests, so it's plain which chest a ball drops into
            if self.fever then
                local n = #Game.FEVER_SLOTS
                local sw = C.W / n
                local top = Game.FEVER_TOP
                for k = 0, n do
                    local px = k * sw
                    local rr = Game.PILLAR_R + r
                    -- the bumper on top: a pinball kick, never weaker than BUMPER_KICK[1]
                    local by = top - 4
                    local rb = Game.BUMPER_R + r
                    local dx, dy = b.x - px, b.y - by
                    local d2 = dx * dx + dy * dy
                    if d2 < rb * rb and d2 > 1e-6 then
                        local d = sqrt(d2)
                        local nx, ny = dx / d, dy / d
                        b.x, b.y = px + nx * rb, by + ny * rb
                        local vn = b.vx * nx + b.vy * ny
                        if vn < 0 then
                            local rx, ry = b.vx - 2 * vn * nx, b.vy - 2 * vn * ny
                            -- a little spin off the dome, and never straight up, so nothing balances on top
                            local a = atan2(ry, rx) + (self.rng.next() - 0.5) * 0.3
                            if abs(nx) < 0.15 then a = atan2(-1, (self.rng.next() < 0.5 and -0.9 or 0.9)) end
                            -- always up and away: between 25 and 70 degrees above the horizon, toward the side it hit
                            local side = (nx < 0) and -1 or 1
                            if k == 0 then side = 1 elseif k == n then side = -1 end
                            local up = math.rad(25 + self.rng.next() * 45)
                            a = atan2(-sin(up), side * cos(up))
                            local sp = min(Game.BUMPER_KICK[2], max(Game.BUMPER_KICK[1], sqrt(rx * rx + ry * ry) * 1.1))
                            -- after a good rally the kicks soften, so every ball settles in a few seconds
                            local nb = (b.bumps or 0)
                            if nb >= 5 then sp = sp * max(0.35, 1 - (nb - 4) * 0.18); up = math.rad(10 + self.rng.next() * 20); a = atan2(-sin(up), side * cos(up)) end
                            b.vx, b.vy = cos(a) * sp, sin(a) * sp
                            b.bumps = (b.bumps or 0) + 1
                            self:Emit("feverBump", k, px, by)
                        end
                    elseif k > 0 and k < n and b.y > top + 6 and abs(b.x - px) < rr then   -- the shaft: stay in your chest
                        local side = (b.px or b.x) < px and -1 or 1      -- the side it was on last step
                        b.x = px + side * rr
                        if (b.vx > 0 and side < 0) or (b.vx < 0 and side > 0) then b.vx = -b.vx * 0.5 end
                    end
                end
            end
            b.px = b.x

            -- bucket (rims are solid, the opening catches)
            if not self.fever then
                local bx, by = self.bucket.x, C.BUCKET_Y
                local half = self:BucketW() / 2
                for s = -1, 1, 2 do
                    local rx = bx + s * half
                    local dx, dy = b.x - rx, b.y - by
                    local rr = C.RIM_R + r
                    local d2 = dx * dx + dy * dy
                    if d2 < rr * rr and d2 > 1e-6 then
                        local d = sqrt(d2)
                        local nx, ny = dx / d, dy / d
                        b.x, b.y = rx + nx * rr, by + ny * rr
                        local vn = b.vx * nx + b.vy * ny
                        if vn < 0 then
                            b.vx, b.vy = b.vx - 1.7 * vn * nx, b.vy - 1.7 * vn * ny
                            b.rimT = self.time
                        end
                    end
                end
                if py < by and b.y >= by and abs(b.x - bx) < half - C.RIM_R then
                    b.alive = false
                    self.ballsLeft = self.ballsLeft + 1
                    self:Emit("bucket", b.x, by)
                    if b.rimT and self.time - b.rimT < 1.5 then
                        self:Style("lucky", b.x, by - 20)
                    elseif self.shotHits == 1 then
                        self:Style("skills", b.x, by - 20)
                    end
                end
            end

            -- Rexxar's Misha bats one falling ball a shot back into play
            if b.alive and b.y > C.H - 18 and b.vy > 0 and (self.mishaShots or 0) > 0 and not self.mishaUsed and not self.fever then
                self.mishaUsed = true
                b.y = C.H - 18
                b.vy = -(560 + self.rng.next() * 90)
                b.vx = b.vx * 0.5 + (C.W / 2 - b.x) * 0.6
                self:Emit("misha", b.x, b.y)
            end
            -- leaving the board
            if b.alive and b.y > C.H + r then
                b.alive = false
                if self.fever then
                    local slot = self:FeverSlotAt(b.x)
                    local pts = Game.FEVER_SLOTS[slot]
                    if self:AllPegsLit() then pts = 100000; self.ultra = true end
                    self.score = self.score + pts
                    self:Emit("feverSlot", slot, pts, b.x)
                end
            end

            -- stuck detection: the ball is trapped while it stays inside a small circle
            if b.alive then
                local ax, ay = b.x - (b.ax or b.x), b.y - (b.ay or b.y)
                if not b.ax or ax * ax + ay * ay > Game.TRAP_RADIUS * Game.TRAP_RADIUS then
                    b.ax, b.ay, b.trapped = b.x, b.y, 0
                else
                    b.trapped = b.trapped + h
                end
                -- crawl: compare with where the ball was CRAWL_WINDOW ago
                b.crawlT = (b.crawlT or 0) + h
                if b.crawlT >= Game.CRAWL_WINDOW then
                    local cx, cy = b.x - (b.cx or b.x), b.y - (b.cy or b.y)
                    b.crawling = b.cx and (cx * cx + cy * cy < Game.CRAWL_DIST * Game.CRAWL_DIST)
                    b.cx, b.cy, b.crawlT = b.x, b.y, 0
                end
                local tidy = b.age > Game.SHOT_TIDY and b.age >= (b.tidyNext or 0)
                if b.trapped > Game.TRAP_TIME or b.crawling or tidy then
                    if tidy then b.tidyNext = b.age + 0.75 end
                    b.crawling = false
                    self:Unstick(b, tidy)
                end
            end

            -- dramatic slow-down near the last orange peg
            if b.alive and lastOrange then
                local dx, dy = lastOrange.x - b.x, lastOrange.y - b.y
                if dx * dx + dy * dy < 80 * 80 and dx * b.vx + dy * b.vy > 0 then clutch = true end
            end

            if b.alive then anyAlive = true end
        end
    end

    if clutch ~= self.clutch then
        self.clutch = clutch
        self:Emit("clutch", clutch, lastOrange)
    end

    -- balls spawned this step (multiball) are appended; keep only live ones
    local live = {}
    for _, b in ipairs(self.balls) do if b.alive then live[#live + 1] = b end end
    self.balls = live
    self:RunTimed(h)
    if not anyAlive and #live == 0 and not (self.timed and #self.timed > 0) then self:BeginClearing() end
end

function Game:FindLastOrange()
    for _, p in ipairs(self.pegs) do
        if p.alive and not p.lit and p.kind == "orange" then return p end
    end
end

function Game:AddPoints(pts, x, y, kind)
    self.score = self.score + pts
    self.shotScore = self.shotScore + pts
    self:Emit("points", pts, x, y, kind)
    while self.freeGiven < #Game.FREEBALL and self.shotScore >= Game.FREEBALL[self.freeGiven + 1] do
        self.freeGiven = self.freeGiven + 1
        self.ballsLeft = self.ballsLeft + 1
        self:Emit("freeball", "style", x, y)
    end
end

function Game:Style(key, x, y)
    local st = Game.STYLE[key]
    self:AddPoints(st[2], x, y, "bonus")
    self:Emit("style", st[1], st[2], x, y)
end

function Game:AllPegsLit()
    for _, p in ipairs(self.pegs) do if p.alive and not p.lit then return false end end
    return true
end

local function StageCount(self, frac) return math.ceil(frac * self.orangeTotal - 1e-9) end

function Game:HitPeg(p, b)
    p.lit = true
    p.hitT = self.time
    self.shotHits = self.shotHits + 1
    local inFever = self.fever
    local mult = self:Multiplier()
    if p.kind == "orange" then
        self.orangeLit = self.orangeLit + 1
        local nm = self:Multiplier()
        if nm ~= mult then self:Emit("multiplier", nm) end
        -- Orange Attack: a whole multiplier stage filled within this one shot
        if not self.attackGiven then
            for k = 2, #Game.MULT do
                local lo, hi = StageCount(self, Game.MULT[k - 1][1]), StageCount(self, Game.MULT[k][1])
                if self.shotOrangeStart <= lo and self.orangeLit >= hi and hi > lo then
                    self.attackGiven = true
                    self:Style("attack", p.x, p.y)
                    break
                end
            end
        end
        if self.orangeLit >= self.orangeTotal and b.rimT and self.time - b.rimT < 2 then
            self:Style("kick", p.x, p.y)
        end
    end
    -- Long Shot: two non-blue pegs hit in a row, far apart
    if p.kind ~= "blue" then
        local ls = b.lastSpecial
        if ls then
            local dx, dy = p.x - ls.x, p.y - ls.y
            local d = sqrt(dx * dx + dy * dy)
            if d >= Game.SUPER_LONG_SHOT then self:Style("superlong", p.x, p.y)
            elseif d >= Game.LONG_SHOT then self:Style("long", p.x, p.y) end
        end
        b.lastSpecial = { x = p.x, y = p.y }
    end
    b.travel, b.hits = 0, b.hits + 1
    local pts = inFever and Game.FEVER_POINTS[p.kind] or (Game.POINTS[p.kind] * mult)
    if p.frog and not inFever then pts = pts + 200 * mult end
    -- a hexed frog hops onto the nearest rune and breaks it too
    if p.frog and not p.hopped then
        p.hopped = true
        local best, bd
        for _, q in ipairs(self.pegs) do
            if q ~= p and q.alive and not q.lit and not (q.kind == "orange" and self.orangeTotal - self.orangeLit <= 1) then
                local d = (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2
                if d < 90 * 90 and (not bd or d < bd) then best, bd = q, d end
            end
        end
        if best then
            self:Emit("hop", p, best)
            self:HitPeg(best, b)
        end
    end
    self:AddPoints(pts, p.x, p.y, p.kind)
    self:Emit("hit", p, self.shotHits)

    if p.kind == "green" and p.power and self.hero and Game.HERO[self.hero] then
        self:HeroPower(p, b)
    elseif p.kind == "green" and p.power then
        local kind = p.power
        if kind == "multi" then
            local nb = NewBall(2 * p.x - b.x, b.y, -b.vx, b.vy - 60)
            nb.hits = 1
            self.balls[#self.balls + 1] = nb
        elseif kind == "sight" then
            self.sightShots = self.sightShots + 3
        elseif kind == "fire" then
            b.fire = 2.6
        end
        self:Emit("power", kind, p)
    end

    if p.kind == "orange" and self.orangeLit >= self.orangeTotal and not self.fever then
        self.fever = true
        self.clutch = false
        self.feverSlow = 1.3
        self:Emit("fever", p)
    end
end

-- light a peg as if the ball had hit it (powers that break runes at a distance)
function Game:PowerLight(p, b)
    if p.alive and not p.lit then self:HitPeg(p, b) end
end

local function unlitNear(self, x, y, n, maxD)
    local list = {}
    for _, q in ipairs(self.pegs) do
        if q.alive and not q.lit then
            local d = (q.x - x) ^ 2 + (q.y - y) ^ 2
            if not maxD or d <= maxD * maxD then list[#list + 1] = { q, d } end
        end
    end
    table.sort(list, function(a, c) return a[2] < c[2] end)
    local out = {}
    for i = 1, min(n or #list, #list) do out[i] = list[i][1] end
    return out
end

-- Hero powers play out over a moment (a bolt jumping rune to rune, a crack racing
-- across the board): each strike is queued and lands in the fixed-step simulation,
-- so the rune breaks exactly when its effect reaches it.
function Game:After(delay, fn)
    self.timed = self.timed or {}
    self.timed[#self.timed + 1] = { t = (self.stepT or 0) + delay, fn = fn }
end

function Game:RunTimed(h)
    self.stepT = (self.stepT or 0) + h
    local q = self.timed
    if not q or #q == 0 then return end
    local i = 1
    while i <= #q do
        if q[i].t <= self.stepT then
            local e = table.remove(q, i)
            e.fn()
        else
            i = i + 1
        end
    end
end

-- order runes into a chain: each link jumps to the nearest rune not yet struck
local function chainOrder(from, list)
    local out, left = {}, {}
    for i, q in ipairs(list) do left[i] = q end
    local cx, cy = from.x, from.y
    while #left > 0 do
        local bi, bd = 1, math.huge
        for i, q in ipairs(left) do
            local d = (q.x - cx) ^ 2 + (q.y - cy) ^ 2
            if d < bd then bi, bd = i, d end
        end
        local q = table.remove(left, bi)
        out[#out + 1] = q
        cx, cy = q.x, q.y
    end
    return out
end

function Game:HeroPower(p, b)
    local key = self.hero
    local hero = Game.HERO[key]
    self:Emit("power", key, p, hero)
    if key == "thrall" then
        -- Chain Lightning: the bolt leaps from the hero rune to the next rune, and on
        local hits = chainOrder(p, unlitNear(self, p.x, p.y, 6))
        self:Emit("chain", p, hits)
        local prev = p
        for i, q in ipairs(hits) do
            local from = prev
            self:After(0.07 * i, function()
                self:Emit("bolt", from, q, i)
                self:PowerLight(q, b)
            end)
            prev = q
        end
    elseif key == "jaina" then
        self:Emit("arcane", p)
        for _, a in ipairs({ -0.5, 0.5 }) do
            local sp = sqrt(b.vx * b.vx + b.vy * b.vy) * 0.9 + 120
            local ang = atan2(b.vy, b.vx) + a
            local nb = NewBall(p.x, p.y - p.r - 8, cos(ang) * sp, -abs(sin(ang) * sp))
            nb.hits, nb.missile = 1, true
            self.balls[#self.balls + 1] = nb
        end
    elseif key == "rexxar" then
        self.mishaShots = max(self.mishaShots or 0, 2)
        self:Emit("mishaCall", p)
    elseif key == "magni" then
        local pool, oranges = {}, {}
        for _, q in ipairs(self.pegs) do
            if q.alive and not q.lit then
                if q.kind == "orange" then oranges[#oranges + 1] = q else pool[#pool + 1] = q end
            end
        end
        local picks = {}
        -- one fire crystal (never the very last one: that stays yours to hit)
        if #oranges > 1 then picks[1] = table.remove(oranges, self.rng.int(1, #oranges)) end
        for _, q in ipairs(oranges) do pool[#pool + 1] = q end
        while #picks < 5 and #pool > 0 do picks[#picks + 1] = table.remove(pool, self.rng.int(1, #pool)) end
        -- Earthquake: cracks split the stone from the hero rune out to each rune in turn
        self:Emit("quake", picks, p)
        for i, q in ipairs(picks) do
            self:After(0.12 * i, function()
                self:Emit("crack", p, q, i)
                if not (q.kind == "orange" and self.orangeTotal - self.orangeLit <= 1) then self:PowerLight(q, b) end
            end)
        end
    elseif key == "sylvanas" then
        self.sightShots = self.sightShots + 3
        self:Emit("blackArrow", p)
    elseif key == "tyrande" then
        for i = 1, 2 do
            local x = 140 + (i - 1) * 200 + (self.rng.next() - 0.5) * 60
            local star = NewBall(x, 14, (self.rng.next() - 0.5) * 60, 40)
            star.hits, star.star = 1, true
            self.balls[#self.balls + 1] = star
        end
        self:Emit("starfall")
    elseif key == "voljin" then
        local pool = {}
        for _, q in ipairs(self.pegs) do
            if q.alive and not q.lit and q.kind == "blue" and not q.frog and not q.brick then pool[#pool + 1] = q end  -- bricks never become frogs
        end
        local frogs = {}
        for _ = 1, min(12, #pool) do
            local q = table.remove(pool, self.rng.int(1, #pool))
            q.frog = true
            frogs[#frogs + 1] = q
        end
        self:Emit("hex", frogs)
    elseif key == "bolvar" then
        self.wideShots = max(self.wideShots or 0, 4)
        self:Emit("consecrate")
    elseif key == "cairne" then
        -- War Stomp: a shockwave rolls outward and breaks each rune as it arrives
        local hits = unlitNear(self, p.x, p.y, nil, 100)
        self:Emit("stomp", p, hits)
        for _, q in ipairs(hits) do
            local d = sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2)
            self:After(0.05 + d / 340, function()
                self:Emit("stompHit", q)
                self:PowerLight(q, b)
            end)
        end
    end
end

function Game:Unstick(b, tidy)
    if b.age > 40 then b.alive = false; return end
    local touching, ready = false, false
    -- a long shot clears lit runes in a wider circle so it can drain
    local reach = tidy and 40 or 8
    for _, p in ipairs(self.pegs) do
        if p.alive and p.lit then
            local dx, dy = b.x - p.x, b.y - p.y
            local rr = p.r + b.r + reach
            if dx * dx + dy * dy < rr * rr then
                touching = true
                if self.time - (p.hitT or 0) >= Game.STUCK_SECONDS then
                    p.alive = false
                    ready = true
                    self:Emit("pop", p)
                end
            end
        end
    end
    if ready then
        b.ax, b.trapped = nil, 0
    elseif not touching and b.trapped > 1.2 then
        -- wedged against a wall or the bucket rim with no peg to clear: a small nudge
        b.vx = b.vx + (self.rng.next() - 0.5) * 300
        b.vy = -140
        b.ax, b.trapped = nil, 0
    end
end

function Game:BeginClearing()
    self.state = "clearing"
    self.timed = nil
    self.clutch = false
    local q = {}
    for _, p in ipairs(self.pegs) do
        if p.alive and p.lit then q[#q + 1] = p end
    end
    table.sort(q, function(a, b) return (a.hitT or 0) < (b.hitT or 0) end)
    self.clearQueue = q
    self.popTimer = 0.45 -- let the lit board sit for a beat, Peggle-style
    if self.shotHits == 0 and not self.fever then
        local win = self.rng.next() < 0.5
        if win then self.ballsLeft = self.ballsLeft + 1 end
        self:Emit("coin", win)
    end
    if self.shotScore > self.bestShot then self.bestShot = self.shotScore end
    if (self.mishaShots or 0) > 0 then self.mishaShots = self.mishaShots - 1 end
    if (self.wideShots or 0) > 0 then self.wideShots = self.wideShots - 1 end
    self:Emit("shotEnd", self.shotScore, self.shotHits)
end

function Game:EndTurn()
    if self.fever then
        local bonus = self.ballsLeft * Game.WIN_BALL_BONUS
        self.score = self.score + bonus
        self.state = "won"
        self:Emit("levelWin", bonus, self.ballsLeft)
    elseif self.ballsLeft <= 0 then
        self.state = "lost"
        self:Emit("gameOver")
    else
        self.state = "aim"
        self:AssignPurple()
        self:Emit("turn")
    end
end

---------------------------------------------------------------------------
-- Aim preview: fills `out` with x,y pairs. Returns point count and the
-- peg the shot would hit first (if any).
---------------------------------------------------------------------------
local function noop() end
local SIM_RNG = { next = function() return 0.5 end, int = function(lo) return lo end }

-- The preview runs the real physics (same step, same pegs, same bucket, same
-- moving parts, same powers) on a scratch copy of the board, so the line you
-- see is the path the ball takes. Dots are spaced by distance travelled.
function Game:Predict(angle, full, out)
    angle = Game.ClampAngle(angle)
    local dx, dy = cos(angle), sin(angle)
    local sim = setmetatable({}, { __index = self })
    sim.Emit, sim.rng = noop, SIM_RNG
    local pegs, map = {}, {}
    for i, p in ipairs(self.pegs) do
        local c = {}
        for k, v in pairs(p) do c[k] = v end
        if p.orbit then c.orbit = { cx = p.orbit.cx, cy = p.orbit.cy, rad = p.orbit.rad, a = p.orbit.a, spd = p.orbit.spd, face = p.orbit.face } end
        if p.slide then local sl = p.slide; c.slide = { x1 = sl.x1, y1 = sl.y1, x2 = sl.x2, y2 = sl.y2, t = sl.t, spd = sl.spd } end
        if p.brick then local br = p.brick; c.brick = { len = br.len, ang = br.ang, spin = br.spin } end
        pegs[i], map[c] = c, p
    end
    sim.pegs = pegs
    sim.bucket = { x = self.bucket.x, dir = self.bucket.dir }
    local ball = NewBall(C.LX + dx * C.BARREL, C.LY + dy * C.BARREL, dx * C.LAUNCH, dy * C.LAUNCH)
    sim.balls = { ball }
    sim.timed, sim.stepT = {}, self.stepT or 0   -- the preview has its own queue of hero-power strikes
    sim.state, sim.clutch = "shot", false
    sim.shotScore, sim.shotHits, sim.freeGiven = 0, 0, 0
    sim.shotOrangeStart, sim.attackGiven = self.orangeLit, false
    sim.BeginClearing = function(s) s.state = "done" end
    local firstPeg
    sim.HitPeg = function(s, p, b)
        if b == ball then firstPeg = firstPeg or map[p] end
        return Game.HitPeg(s, p, b)
    end
    local h = C.STEP
    local maxT = full and 6 or 1.6
    local afterLimit = full and 99 or 0.16
    local spacing = full and 12 or 10
    local cap = full and 160 or 90
    local n, t, after, dist = 0, 0, 0, 0
    local lx, ly = ball.x, ball.y
    while t < maxT and sim.state == "shot" and ball.alive do
        t = t + h
        sim.time = sim.time + h
        sim:MoveWorld(h)
        sim:Step(h)
        if firstPeg then after = after + h end
        local ex, ey = ball.x - lx, ball.y - ly
        dist = dist + sqrt(ex * ex + ey * ey)
        lx, ly = ball.x, ball.y
        if dist >= spacing and n < cap * 2 then
            dist = 0
            out[n + 1], out[n + 2] = ball.x, ball.y
            n = n + 2
        end
        if after > afterLimit then break end
    end
    if n < cap * 2 then out[n + 1], out[n + 2] = lx, ly; n = n + 2 end
    return n / 2, firstPeg
end
