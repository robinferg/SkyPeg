-- Flight Buddy :: Gems.lua
-- Jewelcrafter's Bench: the match-3 engine (no UI). Swap two neighbouring gems to line up three or
-- more of a kind. Bigger matches cut special gems:
--   4 in a row      -> Faceted gem   (clears its whole row or column when it goes)
--   L or T shape    -> Brilliant cut (bursts the 3x3 around it)
--   5 in a row      -> Prismatic gem (swap it with any gem to clear every gem of that colour)
-- Specials swapped into each other combine (two Faceted = a cross, Prismatic + Faceted = every gem
-- of that colour turns Faceted and fires, two Prismatics = the whole bench...).
-- Work Orders also bring geode crusts (a crusted gem can't be swapped; a match cracks the crust) and
-- ore veins (cells under the gems that clear when a gem is cut on top of them).
--
-- The engine resolves a move instantly and returns a list of phases (swap, clear, fall, shuffle)
-- that the UI plays back as animation.
local ADDON, NS = ...

local Gems = {}
NS.Gems = Gems

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

Gems.ROWS, Gems.COLS = 8, 8
Gems.KINDS = 6
-- the six gems of the bench (classic-era stones), in colour order
Gems.GEM = {
    { key = "ruby",     name = "Star Ruby",          color = { 1.00, 0.28, 0.30 } },
    { key = "sapphire", name = "Blue Sapphire",      color = { 0.30, 0.55, 1.00 } },
    { key = "emerald",  name = "Huge Emerald",       color = { 0.30, 0.90, 0.45 } },
    { key = "topaz",    name = "Citrine",            color = { 1.00, 0.78, 0.25 } },
    { key = "amethyst", name = "Large Opal",         color = { 0.78, 0.45, 1.00 } },
    { key = "diamond",  name = "Azerothian Diamond", color = { 0.85, 0.95, 1.00 } },
}
Gems.POINTS = { gem = 30, h = 150, v = 150, bomb = 250, prism = 500, crust = 60, vein = 80, moveLeft = 400 }
Gems.RUSH_TIME = 90
Gems.DAILY_MOVES = 25

---------------------------------------------------------------------------
-- Work Orders: a campaign of levels, generated from the level number (the same for everyone)
---------------------------------------------------------------------------
-- goal kinds: "score" (reach N), "collect" (cut N of some gems), "veins" (clear every ore vein),
-- "geodes" (crack N crusts)
function Gems.Order(level)
    local rng = NS.Game.RNG(level * 7919 + 13)
    local o = { level = level, moves = 20 + (level % 3) * 2, kinds = level <= 2 and 5 or 6, goals = {},
        veins = 0, crusts = 0, crustRefill = 0 }
    local cycle = (level - 1) % 4
    local tier = floor((level - 1) / 4)
    if level == 1 then
        o.goals[1] = { kind = "score", need = 3000 }
        o.moves = 20
    elseif cycle == 0 then
        o.moves = 20 + min(6, tier)
        o.goals[1] = { kind = "score", need = 4500 + tier * 1800 }
    elseif cycle == 1 then
        local a = rng.int(1, o.kinds)
        local b = (a % o.kinds) + 1
        o.goals[1] = { kind = "collect", gem = a, need = 14 + tier * 3 }
        o.goals[2] = { kind = "collect", gem = b, need = 14 + tier * 3 }
    elseif cycle == 2 then
        o.veins = min(32, 8 + tier * 4)
        o.goals[1] = { kind = "veins", need = o.veins }
        o.moves = o.moves + 6 + min(4, tier)
    else
        -- every crust on the bench at the start must be cracked; a few more drop in as spares
        o.crusts = min(24, 6 + tier * 3)
        o.crustRefill = 0.03
        o.goals[1] = { kind = "geodes", need = o.crusts }
        o.moves = o.moves + 4 + min(4, tier)
    end
    -- star thresholds scale with the move count (a careful player earns roughly 450 a move)
    o.stars = { 0, 330 * o.moves + tier * 300, 480 * o.moves + tier * 500 }
    o.name = ({ "Polish a commission", "Fill an order", "Strike the vein", "Crack the geodes" })[cycle + 1]
    if level == 1 then o.name = "Your first commission" end
    o.seed = level * 104729 + 7
    return o
end

---------------------------------------------------------------------------
local Game = {}
Game.__index = Game

function Gems.New(handlers)
    local g = setmetatable({ h = handlers or {}, state = "idle", nextId = 0 }, Game)
    g.rng = NS.Game.RNG(1)
    return g
end

function Game:Emit(ev, ...)
    local f = self.h[ev]
    if f then f(self.h.owner, ...) end
end

local function key(r, c) return r * 16 + c end

function Game:NewGem(k, sp)
    self.nextId = self.nextId + 1
    return { id = self.nextId, k = k, sp = sp, crust = 0 }
end

function Game:RandKind() return self.rng.int(1, self.kinds) end

function Game:At(r, c)
    if r < 1 or c < 1 or r > Gems.ROWS or c > Gems.COLS then return nil end
    return self.grid[r][c]
end

-- mode: "orders" (opts.level), "daily" (opts.day), "rush"
function Game:Start(mode, opts)
    opts = opts or {}
    self.mode = mode
    self.score, self.cascadeBest, self.specialsMade, self.bigCombo = 0, 0, 0, 0
    self.collected = {}
    for k = 1, Gems.KINDS do self.collected[k] = 0 end
    self.cracked, self.veinsCleared = 0, 0
    self.moves, self.timeLeft = nil, nil
    self.order = nil
    self.kinds = Gems.KINDS
    self.crustRefill = 0
    local seed
    if mode == "orders" then
        local o = Gems.Order(opts.level or 1)
        self.order = o
        self.moves = o.moves
        self.kinds = o.kinds
        self.crustRefill = o.crustRefill
        seed = o.seed
    elseif mode == "daily" then
        self.moves = Gems.DAILY_MOVES
        seed = tonumber(opts.day) or 1
    else
        self.timeLeft = Gems.RUSH_TIME
        seed = opts.seed or floor((self.clock or 0) * 1000) + 1
    end
    self.rng = NS.Game.RNG(seed)
    self.seed = seed
    self:Fill()
    -- ore veins and crusts for work orders
    self.vein = {}
    for r = 1, Gems.ROWS do self.vein[r] = {} end
    if self.order then
        local placed = 0
        local tries = 0
        while placed < (self.order.veins or 0) and tries < 500 do
            tries = tries + 1
            -- veins run in seams: favour the lower half of the bench
            local r = self.rng.int(3, Gems.ROWS)
            local c = self.rng.int(1, Gems.COLS)
            if not self.vein[r][c] then self.vein[r][c] = true; placed = placed + 1 end
        end
        local crusts = 0
        tries = 0
        while crusts < (self.order.crusts or 0) and tries < 500 do
            tries = tries + 1
            local g = self.grid[self.rng.int(2, Gems.ROWS)][self.rng.int(1, Gems.COLS)]
            if g.crust == 0 and not g.sp then g.crust = 1; crusts = crusts + 1 end
        end
    end
    self.state = "play"
    self:Emit("start")
end

-- a fresh bench with no ready-made matches and at least one move
function Game:Fill()
    for attempt = 1, 200 do
        self.grid = {}
        for r = 1, Gems.ROWS do
            self.grid[r] = {}
            for c = 1, Gems.COLS do
                local k
                repeat
                    k = self:RandKind()
                    local bad = (c >= 3 and self.grid[r][c - 1].k == k and self.grid[r][c - 2].k == k)
                        or (r >= 3 and self.grid[r - 1][c].k == k and self.grid[r - 2][c].k == k)
                until not bad
                self.grid[r][c] = self:NewGem(k)
            end
        end
        if self:FindMove() then return end
    end
end

---------------------------------------------------------------------------
-- Matching
---------------------------------------------------------------------------
-- prismatic gems (k = 0) never match by colour
local function same(a, b) return a and b and a.k ~= 0 and a.k == b.k end

-- groups of matched cells: { cells = { {r,c},... }, h = longest horizontal run, v = longest vertical run, kind }
function Game:FindMatches()
    local R, Cn = Gems.ROWS, Gems.COLS
    local inRunH, inRunV = {}, {}
    local runs = {}
    for r = 1, R do
        local c = 1
        while c <= Cn do
            local g = self.grid[r][c]
            local e = c
            while e + 1 <= Cn and same(g, self.grid[r][e + 1]) do e = e + 1 end
            if g and g.k ~= 0 and e - c + 1 >= 3 then
                runs[#runs + 1] = { dir = "h", r = r, c1 = c, c2 = e, len = e - c + 1, k = g.k }
                for x = c, e do inRunH[key(r, x)] = #runs end
            end
            c = e + 1
        end
    end
    for c = 1, Cn do
        local r = 1
        while r <= R do
            local g = self.grid[r][c]
            local e = r
            while e + 1 <= R and same(g, self.grid[e + 1][c]) do e = e + 1 end
            if g and g.k ~= 0 and e - r + 1 >= 3 then
                runs[#runs + 1] = { dir = "v", c = c, r1 = r, r2 = e, len = e - r + 1, k = g.k }
                for y = r, e do inRunV[key(y, c)] = #runs end
            end
            r = e + 1
        end
    end
    if #runs == 0 then return {} end
    -- join runs that share a cell (L and T shapes) with a little union-find
    local parent = {}
    for i = 1, #runs do parent[i] = i end
    local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    for k2, hi in pairs(inRunH) do
        local vi = inRunV[k2]
        if vi then parent[find(hi)] = find(vi) end
    end
    local groups, byRoot = {}, {}
    for i, run in ipairs(runs) do
        local root = find(i)
        local gp = byRoot[root]
        if not gp then gp = { cells = {}, seen = {}, h = 0, v = 0, k = run.k, runs = {} }; byRoot[root] = gp; groups[#groups + 1] = gp end
        gp.runs[#gp.runs + 1] = run
        if run.dir == "h" then
            gp.h = max(gp.h, run.len)
            for x = run.c1, run.c2 do
                local kk = key(run.r, x)
                if not gp.seen[kk] then gp.seen[kk] = true; gp.cells[#gp.cells + 1] = { run.r, x } end
            end
        else
            gp.v = max(gp.v, run.len)
            for y = run.r1, run.r2 do
                local kk = key(y, run.c)
                if not gp.seen[kk] then gp.seen[kk] = true; gp.cells[#gp.cells + 1] = { y, run.c } end
            end
        end
    end
    return groups
end

-- would swapping these two cells make a match (or fire a special)?
function Game:SwapMakesMatch(r1, c1, r2, c2)
    local a, b = self.grid[r1][c1], self.grid[r2][c2]
    if not (a and b) then return false end
    if a.crust > 0 or b.crust > 0 then return false end
    if a.k == 0 or b.k == 0 then return true end
    if a.sp and b.sp then return true end
    self.grid[r1][c1], self.grid[r2][c2] = b, a
    local ok = false
    for _, p in ipairs({ { r1, c1 }, { r2, c2 } }) do
        local r, c = p[1], p[2]
        local g = self.grid[r][c]
        local n = 1
        local x = c - 1 while x >= 1 and same(g, self.grid[r][x]) do n = n + 1; x = x - 1 end
        x = c + 1 while x <= Gems.COLS and same(g, self.grid[r][x]) do n = n + 1; x = x + 1 end
        if n >= 3 then ok = true end
        n = 1
        local y = r - 1 while y >= 1 and same(g, self.grid[y][c]) do n = n + 1; y = y - 1 end
        y = r + 1 while y <= Gems.ROWS and same(g, self.grid[y][c]) do n = n + 1; y = y + 1 end
        if n >= 3 then ok = true end
    end
    self.grid[r1][c1], self.grid[r2][c2] = a, b
    return ok
end

-- any legal move? returns r1, c1, r2, c2 (used for hints and shuffles)
function Game:FindMove()
    for r = 1, Gems.ROWS do
        for c = 1, Gems.COLS do
            if c < Gems.COLS and self:SwapMakesMatch(r, c, r, c + 1) then return r, c, r, c + 1 end
            if r < Gems.ROWS and self:SwapMakesMatch(r, c, r + 1, c) then return r, c, r + 1, c end
        end
    end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
function Game:Adjacent(r1, c1, r2, c2) return abs(r1 - r2) + abs(c1 - c2) == 1 end

function Game:CanAct() return self.state == "play" end

-- try a swap. Returns phases (for animation); phases[1].ok is false for a swap that doesn't match.
function Game:Swap(r1, c1, r2, c2)
    if not self:CanAct() or not self:Adjacent(r1, c1, r2, c2) then return nil end
    local a, b = self.grid[r1][c1], self.grid[r2][c2]
    if not (a and b) then return nil end
    local phases = {}
    if a.crust > 0 or b.crust > 0 or not self:SwapMakesMatch(r1, c1, r2, c2) then
        phases[1] = { t = "swap", a = { r1, c1 }, b = { r2, c2 }, ok = false }
        self:Emit("badswap")
        return phases
    end
    self.grid[r1][c1], self.grid[r2][c2] = b, a
    phases[1] = { t = "swap", a = { r1, c1 }, b = { r2, c2 }, ok = true }
    if self.moves then self.moves = self.moves - 1 end
    -- special combinations fire straight away
    local forced = {}
    if a.k == 0 or b.k == 0 or (a.sp and b.sp) then
        self:Combine(a, b, r2, c2, r1, c1, forced)
    end
    self:Resolve(phases, { [key(r1, c1)] = true, [key(r2, c2)] = true }, forced)
    self:AfterMove(phases)
    return phases
end

-- two specials (or a prismatic gem) swapped together: a is now at (ra, ca), b at (rb, cb)
function Game:Combine(a, b, ra, ca, rb, cb, forced)
    local function color(of) return (of and of.k ~= 0) and of.k or self:MostCommon() end
    -- the swapped specials are used up by the combination (they don't also go off on their own)
    if a.sp then a.spent = true end
    if b.sp and (a.k == 0 or b.k == 0) then
        if b.k == 0 then b.spent = true end
    end
    if a.k == 0 and b.k == 0 then
        forced.all = true
    elseif a.k == 0 or b.k == 0 then
        local prism, other = (a.k == 0) and a or b, (a.k == 0) and b or a
        prism.spent = true
        other.spent = nil
        local pr, pc = (prism == a) and ra or rb, (prism == a) and ca or cb
        local k = other.k
        forced.color = { k = k, as = (other.sp and other.sp ~= "prism") and other.sp or nil }
        forced.cells = { { pr, pc } }
    else
        -- two specials: Faceted+Faceted = cross, Faceted+Brilliant = 3-wide cross, Brilliant+Brilliant = 5x5
        local s1, s2 = a.sp, b.sp
        local line1, line2 = (s1 == "h" or s1 == "v"), (s2 == "h" or s2 == "v")
        forced.cells = { { ra, ca }, { rb, cb } }
        if line1 and line2 then
            forced.cross = { r = ra, c = ca, w = 0 }
        elseif line1 or line2 then
            forced.cross = { r = ra, c = ca, w = 1 }
        else
            forced.area = { r = ra, c = ca, rad = 2 }
        end
        a.spent, b.spent = true, true
    end
end

function Game:MostCommon()
    local n = {}
    local best, bk = -1, 1
    for r = 1, Gems.ROWS do
        for c = 1, Gems.COLS do
            local g = self.grid[r][c]
            if g and g.k ~= 0 then
                n[g.k] = (n[g.k] or 0) + 1
                if n[g.k] > best then best, bk = n[g.k], g.k end
            end
        end
    end
    return bk
end

-- clear, cut specials, cascade until the bench settles
function Game:Resolve(phases, swapped, forced)
    local cascade = 0
    while true do
        local groups = self:FindMatches()
        local hasForced = forced and next(forced) ~= nil
        if #groups == 0 and not hasForced then break end
        cascade = cascade + 1
        local clear, cause = {}, {}
        local created = {}
        local blasts = {}
        local keepNew = {}
        local function mark(r, c, why)
            if r < 1 or c < 1 or r > Gems.ROWS or c > Gems.COLS then return end
            local k2 = key(r, c)
            if not clear[k2] then clear[k2] = { r, c }; cause[k2] = why end
        end
        -- forced effects from a special swap
        if hasForced then
            if forced.all then
                blasts[#blasts + 1] = { kind = "all" }
                for r = 1, Gems.ROWS do for c = 1, Gems.COLS do mark(r, c, "blast") end end
            end
            if forced.color then
                local k = forced.color.k
                blasts[#blasts + 1] = { kind = "color", k = k }
                for r = 1, Gems.ROWS do
                    for c = 1, Gems.COLS do
                        local g = self.grid[r][c]
                        if g and g.k == k then
                            if forced.color.as then
                                -- every gem of the colour becomes that special, then they all go off
                                g.sp = forced.color.as
                                if g.sp == "h" or g.sp == "v" then g.sp = (self.rng.next() < 0.5) and "h" or "v" end
                            end
                            mark(r, c, "blast")
                        end
                    end
                end
            end
            if forced.cross then
                local x = forced.cross
                blasts[#blasts + 1] = { kind = "cross", r = x.r, c = x.c, w = x.w }
                for d = -x.w, x.w do
                    for c = 1, Gems.COLS do mark(x.r + d, c, "blast") end
                    for r = 1, Gems.ROWS do mark(r, x.c + d, "blast") end
                end
            end
            if forced.area then
                local x = forced.area
                blasts[#blasts + 1] = { kind = "area", r = x.r, c = x.c, rad = x.rad }
                for r = x.r - x.rad, x.r + x.rad do for c = x.c - x.rad, x.c + x.rad do mark(r, c, "blast") end end
            end
            for _, p in ipairs(forced.cells or {}) do mark(p[1], p[2], "blast") end
            forced = nil
        end
        -- ordinary matches, and the special gems they cut
        for _, gp in ipairs(groups) do
            for _, p in ipairs(gp.cells) do mark(p[1], p[2], "match") end
            local sp
            if gp.h >= 5 or gp.v >= 5 then sp = "prism"
            elseif gp.h >= 3 and gp.v >= 3 then sp = "bomb"
            elseif gp.h == 4 then sp = "h"
            elseif gp.v == 4 then sp = "v" end
            if sp then
                -- the new gem appears where you swapped (if that was part of it), else mid-match
                local at
                for _, p in ipairs(gp.cells) do if swapped and swapped[key(p[1], p[2])] then at = p end end
                at = at or gp.cells[floor((#gp.cells + 1) / 2)]
                local ng = self:NewGem(sp == "prism" and 0 or gp.k, sp)
                created[#created + 1] = { gem = ng, r = at[1], c = at[2] }
                keepNew[key(at[1], at[2])] = ng
                self.specialsMade = self.specialsMade + 1
                self:Add(Gems.POINTS[sp])
            end
        end
        -- set off any specials caught in the clear (chains)
        local queue = {}
        for k2, p in pairs(clear) do queue[#queue + 1] = p end
        local qi = 1
        local fired = {}
        while qi <= #queue do
            local p = queue[qi]; qi = qi + 1
            local g = self.grid[p[1]][p[2]]
            if g and g.sp and not g.spent and not fired[g.id] and g.crust == 0 then
                fired[g.id] = true
                local before = #queue
                local function add(r, c)
                    if r < 1 or c < 1 or r > Gems.ROWS or c > Gems.COLS then return end
                    local k2 = key(r, c)
                    if not clear[k2] then clear[k2] = { r, c }; cause[k2] = "blast"; queue[#queue + 1] = { r, c } end
                end
                if g.sp == "h" then
                    blasts[#blasts + 1] = { kind = "row", r = p[1] }
                    for c = 1, Gems.COLS do add(p[1], c) end
                elseif g.sp == "v" then
                    blasts[#blasts + 1] = { kind = "col", c = p[2] }
                    for r = 1, Gems.ROWS do add(r, p[2]) end
                elseif g.sp == "bomb" then
                    blasts[#blasts + 1] = { kind = "area", r = p[1], c = p[2], rad = 1 }
                    for r = p[1] - 1, p[1] + 1 do for c = p[2] - 1, p[2] + 1 do add(r, c) end end
                elseif g.sp == "prism" then
                    local k = self:MostCommon()
                    blasts[#blasts + 1] = { kind = "color", k = k }
                    for r = 1, Gems.ROWS do
                        for c = 1, Gems.COLS do
                            local o = self.grid[r][c]
                            if o and o.k == k then add(r, c) end
                        end
                    end
                end
            end
        end
        -- remove gems (crusts crack instead), clear veins, score
        local cleared, crustBroke, veins = {}, {}, {}
        local n = 0
        for k2, p in pairs(clear) do
            local r, c = p[1], p[2]
            local g = self.grid[r][c]
            if g then
                if g.crust > 0 then
                    g.crust = g.crust - 1
                    crustBroke[#crustBroke + 1] = { gem = g, r = r, c = c }
                    self.cracked = self.cracked + 1
                    self:Add(Gems.POINTS.crust)
                else
                    cleared[#cleared + 1] = { gem = g, r = r, c = c, why = cause[k2] }
                    if g.k ~= 0 then self.collected[g.k] = (self.collected[g.k] or 0) + 1 end
                    self.grid[r][c] = nil
                    n = n + 1
                    if self.vein[r] and self.vein[r][c] then
                        self.vein[r][c] = nil
                        veins[#veins + 1] = { r, c }
                        self.veinsCleared = self.veinsCleared + 1
                        self:Add(Gems.POINTS.vein)
                    end
                end
            end
        end
        local pts = n * Gems.POINTS.gem * cascade
        self:Add(pts)
        -- the newly cut specials take their places
        for _, cr in ipairs(created) do
            if self.grid[cr.r][cr.c] == nil then self.grid[cr.r][cr.c] = cr.gem
            else
                -- the spot survived (crust): put the special somewhere it can land
                cr.lost = true
            end
        end
        self.cascadeBest = max(self.cascadeBest, cascade)
        if n >= 12 then self.bigCombo = self.bigCombo + 1 end
        phases[#phases + 1] = { t = "clear", cleared = cleared, created = created, blasts = blasts, cascade = cascade,
            points = pts, crust = crustBroke, veins = veins, count = n }
        self:Emit("clear", cascade, n, #created)
        -- gravity and refill
        phases[#phases + 1] = self:Gravity()
        swapped = nil
    end
    return cascade
end

function Game:Gravity()
    local moves, spawns = {}, {}
    for c = 1, Gems.COLS do
        local write = Gems.ROWS
        for r = Gems.ROWS, 1, -1 do
            local g = self.grid[r][c]
            if g then
                if r ~= write then
                    self.grid[write][c] = g
                    self.grid[r][c] = nil
                    moves[#moves + 1] = { gem = g, r0 = r, r1 = write, c = c }
                end
                write = write - 1
            end
        end
        local n = write
        for r = write, 1, -1 do
            local g = self:NewGem(self:RandKind())
            if self.crustRefill > 0 and self.rng.next() < self.crustRefill then g.crust = 1 end
            self.grid[r][c] = g
            spawns[#spawns + 1] = { gem = g, r1 = r, c = c, r0 = r - n }
        end
    end
    return { t = "fall", moves = moves, spawns = spawns }
end

function Game:Add(p)
    self.score = self.score + floor(p)
end

-- after a move settles: shuffle a stuck bench, check goals and the end of the game
function Game:AfterMove(phases)
    if not self:FindMove() then
        self:Shuffle()
        phases[#phases + 1] = { t = "shuffle" }
    end
    if self:GoalsDone() and self.mode == "orders" then
        -- unused moves become bonus points ("polish")
        local left = self.moves or 0
        local bonus = left * Gems.POINTS.moveLeft
        self:Add(bonus)
        phases[#phases + 1] = { t = "done", won = true, bonus = bonus, left = left }
        self:Finish(true)
    elseif self.moves and self.moves <= 0 then
        local won = self.mode ~= "orders"
        phases[#phases + 1] = { t = "done", won = won }
        self:Finish(won)
    end
end

function Game:Shuffle()
    local list = {}
    for r = 1, Gems.ROWS do for c = 1, Gems.COLS do list[#list + 1] = self.grid[r][c] end end
    for attempt = 1, 100 do
        for i = #list, 2, -1 do
            local j = self.rng.int(1, i)
            list[i], list[j] = list[j], list[i]
        end
        local i = 0
        for r = 1, Gems.ROWS do for c = 1, Gems.COLS do i = i + 1; self.grid[r][c] = list[i] end end
        if #self:FindMatches() == 0 and self:FindMove() then return end
    end
    -- couldn't: deal a fresh bench (keeps the score)
    self:Fill()
end

---------------------------------------------------------------------------
-- Goals, time, the end
---------------------------------------------------------------------------
function Game:GoalProgress(goal)
    if goal.kind == "score" then return self.score
    elseif goal.kind == "collect" then return self.collected[goal.gem] or 0
    elseif goal.kind == "veins" then return self.veinsCleared
    elseif goal.kind == "geodes" then return self.cracked end
    return 0
end

function Game:GoalsDone()
    if not self.order then return false end
    for _, goal in ipairs(self.order.goals) do
        if self:GoalProgress(goal) < goal.need then return false end
    end
    return true
end

function Game:Stars()
    if not self.order then return 0 end
    if not self:GoalsDone() then return 0 end
    local s = 1
    if self.score >= self.order.stars[2] then s = 2 end
    if self.score >= self.order.stars[3] then s = 3 end
    return s
end

function Game:Finish(won)
    if self.state ~= "play" then return end
    self.state = "over"
    self.won = won
    self:Emit("over", won)
end

-- Gem Rush clock (the UI calls this every frame while the bench is idle and not paused)
function Game:Tick(dt)
    self.clock = (self.clock or 0) + dt
    if self.state ~= "play" or not self.timeLeft then return end
    self.timeLeft = self.timeLeft - dt
    if self.timeLeft <= 0 then
        self.timeLeft = 0
        self:Finish(true)
    end
end

-- save / restore a Work Order in progress
function Game:Serialize()
    if self.state ~= "play" or self.mode ~= "orders" then return nil end
    local cells = {}
    for r = 1, Gems.ROWS do
        for c = 1, Gems.COLS do
            local g = self.grid[r][c]
            cells[#cells + 1] = ("%d%s%d"):format(g.k, g.sp and g.sp:sub(1, 1) or "-", g.crust)
        end
    end
    local veins = {}
    for r = 1, Gems.ROWS do for c = 1, Gems.COLS do if self.vein[r][c] then veins[#veins + 1] = r * 10 + c end end end
    return { v = 1, level = self.order.level, score = self.score, moves = self.moves, cells = table.concat(cells, ","),
        veins = veins, collected = self.collected, cracked = self.cracked, veinsCleared = self.veinsCleared }
end

local SP = { h = "h", v = "v", b = "bomb", p = "prism" }
function Game:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or not s.cells then return false end
    self:Start("orders", { level = s.level })
    local i = 0
    for cell in s.cells:gmatch("[^,]+") do
        i = i + 1
        local r, c = floor((i - 1) / Gems.COLS) + 1, (i - 1) % Gems.COLS + 1
        local k, sp, crust = cell:match("^(%d)(.)(%d)$")
        if not k or r > Gems.ROWS then return false end
        local g = self:NewGem(tonumber(k), SP[sp])
        g.crust = tonumber(crust)
        self.grid[r][c] = g
    end
    for r = 1, Gems.ROWS do self.vein[r] = {} end
    for _, v in ipairs(s.veins or {}) do self.vein[floor(v / 10)][v % 10] = true end
    self.score, self.moves = s.score or 0, s.moves or self.moves
    for k = 1, Gems.KINDS do self.collected[k] = (s.collected and s.collected[k]) or 0 end
    self.cracked, self.veinsCleared = s.cracked or 0, s.veinsCleared or 0
    if #self:FindMatches() > 0 or not self:FindMove() then self:Shuffle() end
    return true
end
