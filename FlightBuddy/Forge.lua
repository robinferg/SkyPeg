-- Flight Buddy :: Forge.lua
-- The Great Forge: the smelting engine (no UI). A 4x4 anvil of metal bars. Slide every bar one
-- way; two of the same metal that meet smelt into one bar of the next metal up the ladder:
--   Copper > Tin > Bronze > Silver > Iron > Gold > Steel > Mithril > Truesilver > Thorium > Arcanite
-- and on past Arcanite for anyone who gets there. After every move a new Copper bar (now and
-- then Tin) drops onto an empty spot. The forge goes cold when the anvil is full and nothing can
-- be smelted.
--
-- The engine resolves a move at once and returns what happened (which bars slid where, which
-- smelted, what dropped in) for the screen to play back.
local ADDON, NS = ...

local Forge = {}
NS.Forge = Forge

local floor = math.floor

Forge.N = 4
Forge.DAILY_MOVES = 200     -- hammer strikes in the Daily Smelt
Forge.UNDOS = 2             -- reheats in a free forge
Forge.GOAL = 11             -- Arcanite

-- the ladder: real bars, by item id (their icons come from the game itself)
Forge.BARS = {
    { key = "copper",     name = "Copper",     item = 2840,  icon = "INV_Ingot_02",            color = { 0.86, 0.50, 0.28 } },
    { key = "tin",        name = "Tin",        item = 3576,  icon = "INV_Ingot_05",            color = { 0.70, 0.74, 0.76 } },
    { key = "bronze",     name = "Bronze",     item = 2841,  icon = "INV_Ingot_Bronze",        color = { 0.72, 0.52, 0.22 } },
    { key = "silver",     name = "Silver",     item = 2842,  icon = "INV_Ingot_01",            color = { 0.88, 0.90, 0.95 } },
    { key = "iron",       name = "Iron",       item = 3575,  icon = "INV_Ingot_Iron",          color = { 0.52, 0.54, 0.58 } },
    { key = "gold",       name = "Gold",       item = 3577,  icon = "INV_Ingot_03",            color = { 1.00, 0.82, 0.25 } },
    { key = "steel",      name = "Steel",      item = 3859,  icon = "INV_Ingot_Steel",         color = { 0.50, 0.62, 0.74 } },
    { key = "mithril",    name = "Mithril",    item = 3860,  icon = "INV_Ingot_06",            color = { 0.40, 0.76, 0.86 } },
    { key = "truesilver", name = "Truesilver", item = 6037,  icon = "INV_Ingot_08",            color = { 0.62, 0.92, 1.00 } },
    { key = "thorium",    name = "Thorium",    item = 12359, icon = "INV_Ingot_07",            color = { 0.36, 0.84, 0.46 } },
    { key = "arcanite",   name = "Arcanite",   item = 12360, icon = "INV_Misc_StoneTablet_05", color = { 0.58, 0.48, 1.00 } },
    { key = "darkiron",   name = "Dark Iron",  item = 11371, icon = "INV_Ingot_Mithril",       color = { 0.78, 0.24, 0.18 } },
    { key = "enchanted",  name = "Enchanted Thorium", short = "Ench. Thorium", item = 12655, icon = "INV_Ingot_Eternium", color = { 0.30, 0.95, 0.80 } },
    { key = "elementium", name = "Elementium", item = 17771, icon = "INV_Ingot_Thorium",       color = { 0.90, 0.40, 0.95 } },
    -- nobody is expected up here, but the anvil can hold them and each needs its own face
    { key = "sulfuron",   name = "Sulfuron",   item = 17203, icon = "INV_Ingot_Mithril",       color = { 1.00, 0.55, 0.10 } },
    { key = "eternium",   name = "Eternium",   item = 23447, icon = "INV_Ingot_Eternium",      color = { 0.55, 0.60, 1.00 } },
    { key = "khorium",    name = "Khorium",    item = 23449, icon = "INV_Ingot_Thorium",       color = { 1.00, 0.30, 0.55 } },
}

-- what a bar is worth when it is smelted: 2, 4, 8 ... like the numbers on the classic tiles
function Forge.Value(tier) return 2 ^ tier end
function Forge.Bar(tier) return Forge.BARS[tier] or Forge.BARS[#Forge.BARS] end

local DIRS = { left = { 0, -1 }, right = { 0, 1 }, up = { -1, 0 }, down = { 1, 0 } }
Forge.DIRS = DIRS

function Forge.New()
    local g = setmetatable({}, { __index = Forge })
    g.state = "idle"
    g.grid = {}
    for r = 1, Forge.N do g.grid[r] = {} end
    g.score, g.moves, g.best, g.nextId = 0, 0, 0, 0
    g.rs = 1
    return g
end

-- the same numbers on every computer (Park-Miller), with the state kept where it can be saved
function Forge:Rand()
    self.rs = (self.rs * 16807) % 2147483647
    return (self.rs - 1) / 2147483646
end

local function DaySeed(day)
    local n = 0
    for ch in tostring(day):gmatch("%d") do n = (n * 10 + tonumber(ch)) % 2147483000 end
    return n * 31 + 777
end

-- mode "forge": a free forge (opts.seed), saved between sessions, with reheats
-- mode "daily": the Daily Smelt (opts.day): the same bars drop for everyone, DAILY_MOVES strikes
function Forge:Start(mode, opts)
    opts = opts or {}
    self.mode = mode == "daily" and "daily" or "forge"
    self.day = self.mode == "daily" and opts.day or nil
    local seed = self.mode == "daily" and DaySeed(opts.day or 0) or (opts.seed or 1)
    self.rs = floor(math.abs(seed)) % 2147483646 + 1
    for r = 1, Forge.N do for c = 1, Forge.N do self.grid[r][c] = nil end end
    self.score, self.moves, self.best, self.nextId = 0, 0, 0, 0
    self.movesLeft = self.mode == "daily" and Forge.DAILY_MOVES or nil
    self.undosLeft = self.mode == "forge" and Forge.UNDOS or 0
    self.undo, self.won, self.wonNow = nil, false, false
    self.state = "play"
    local a = self:Spawn()
    local b = self:Spawn()
    return { a, b }
end

-- drop a new bar on an empty spot: Copper nine times in ten, Tin the tenth
function Forge:Spawn()
    local free = {}
    for r = 1, Forge.N do for c = 1, Forge.N do
        if not self.grid[r][c] then free[#free + 1] = { r, c } end
    end end
    if #free == 0 then return nil end
    local spot = free[1 + floor(self:Rand() * #free)] or free[#free]
    local tier = self:Rand() < 0.9 and 1 or 2
    self.nextId = self.nextId + 1
    local t = { id = self.nextId, t = tier }
    self.grid[spot[1]][spot[2]] = t
    if tier > self.best then self.best = tier end
    return { id = t.id, r = spot[1], c = spot[2], t = tier }
end

function Forge:CanMove()
    local N, G = Forge.N, self.grid
    for r = 1, N do for c = 1, N do
        local t = G[r][c]
        if not t then return true end
        if c < N and G[r][c + 1] and G[r][c + 1].t == t.t then return true end
        if r < N and G[r + 1][c] and G[r + 1][c].t == t.t then return true end
    end end
    return false
end

local function Snapshot(self)
    local cells = {}
    for r = 1, Forge.N do for c = 1, Forge.N do
        local t = self.grid[r][c]
        cells[(r - 1) * Forge.N + c] = t and t.t or 0
    end end
    return { cells = cells, score = self.score, rs = self.rs, moves = self.moves, movesLeft = self.movesLeft,
        won = self.won, best = self.best }
end

-- Slide every bar towards `dir` ("left", "right", "up", "down"). Returns nil when nothing can
-- move that way, otherwise:
--   { dir =, slides = { { id, fr, fc, tr, tc, into = id of the bar it smelts into } ... },
--     smelts = { { id, r, c, t = new tier } ... }, spawn = { id, r, c, t }, gained = points,
--     over = true when the forge is now cold, won = true the first time Arcanite is made }
function Forge:Move(dir)
    local d = DIRS[dir]
    if not d or self.state ~= "play" then return nil end
    local N, G = Forge.N, self.grid
    local before = Snapshot(self)
    local res = { dir = dir, slides = {}, smelts = {}, gained = 0 }
    local moved = false
    for line = 1, N do
        -- the cells of this line, starting from the edge the bars are pushed against
        local cells = {}
        for k = 1, N do
            local r, c
            if d[1] ~= 0 then c = line; r = (d[1] < 0) and k or (N + 1 - k)
            else r = line; c = (d[2] < 0) and k or (N + 1 - k) end
            cells[k] = { r, c }
        end
        local at, last, lastMerged = 0, nil, false
        for k = 1, N do
            local r, c = cells[k][1], cells[k][2]
            local t = G[r][c]
            if t then
                G[r][c] = nil
                if last and last.t == t.t and not lastMerged then
                    -- smelt into the bar already resting there
                    local tr, tc = cells[at][1], cells[at][2]
                    last.t = last.t + 1
                    lastMerged = true
                    res.slides[#res.slides + 1] = { id = t.id, fr = r, fc = c, tr = tr, tc = tc, into = last.id }
                    res.smelts[#res.smelts + 1] = { id = last.id, r = tr, c = tc, t = last.t }
                    res.gained = res.gained + Forge.Value(last.t)
                    if last.t > self.best then self.best = last.t end
                    moved = true
                else
                    at = at + 1
                    local tr, tc = cells[at][1], cells[at][2]
                    G[tr][tc] = t
                    last, lastMerged = t, false
                    if tr ~= r or tc ~= c then
                        res.slides[#res.slides + 1] = { id = t.id, fr = r, fc = c, tr = tr, tc = tc }
                        moved = true
                    end
                end
            end
        end
    end
    if not moved then return nil end
    self.undo = before
    self.score = self.score + res.gained
    self.moves = self.moves + 1
    if self.movesLeft then self.movesLeft = self.movesLeft - 1 end
    res.spawn = self:Spawn()
    if not self.won and self.best >= Forge.GOAL then self.won = true; res.won = true end
    if (self.movesLeft and self.movesLeft <= 0) or not self:CanMove() then
        self.state = "over"
        res.over = true
    end
    return res
end

-- Reheat: take back the last move (a free forge only, UNDOS times a game; it can also bring a
-- cold forge back to life). Returns true if it did.
function Forge:CanUndo() return self.mode == "forge" and self.undo ~= nil and (self.undosLeft or 0) > 0 and self.state ~= "idle" end

function Forge:Undo()
    if not self:CanUndo() then return false end
    local s = self.undo
    self.undo = nil
    self.undosLeft = self.undosLeft - 1
    for r = 1, Forge.N do for c = 1, Forge.N do
        local tier = s.cells[(r - 1) * Forge.N + c]
        if tier > 0 then
            self.nextId = self.nextId + 1
            self.grid[r][c] = { id = self.nextId, t = tier }
        else
            self.grid[r][c] = nil
        end
    end end
    self.score, self.rs, self.moves, self.movesLeft, self.won, self.best = s.score, s.rs, s.moves, s.movesLeft, s.won, s.best
    self.state = "play"
    return true
end

-- every bar on the anvil: { id, r, c, t }
function Forge:Tiles()
    local out = {}
    for r = 1, Forge.N do for c = 1, Forge.N do
        local t = self.grid[r][c]
        if t then out[#out + 1] = { id = t.id, r = r, c = c, t = t.t } end
    end end
    return out
end

---------------------------------------------------------------------------
-- Saving: the whole forge in a small table, written after every move
---------------------------------------------------------------------------
function Forge:Serialize()
    if self.state == "idle" then return nil end
    local s = Snapshot(self)
    s.v, s.mode, s.day, s.state, s.undosLeft = 1, self.mode, self.day, self.state, self.undosLeft
    if self.undo then
        local u = self.undo
        local cells = {}
        for i = 1, Forge.N * Forge.N do cells[i] = u.cells[i] end
        s.undo = { cells = cells, score = u.score, rs = u.rs, moves = u.moves, movesLeft = u.movesLeft, won = u.won, best = u.best }
    end
    return s
end

local function GoodCells(cells)
    if type(cells) ~= "table" then return false end
    for i = 1, Forge.N * Forge.N do
        local v = cells[i]
        if type(v) ~= "number" or v < 0 or v > 40 or v ~= floor(v) then return false end
    end
    return true
end

local function GoodSnap(s)
    return type(s) == "table" and GoodCells(s.cells) and type(s.score) == "number" and s.score >= 0
        and type(s.rs) == "number" and s.rs >= 1 and s.rs < 2147483647 and s.rs == floor(s.rs)
        and type(s.moves) == "number" and s.moves >= 0
end

function Forge:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or not GoodSnap(s) then return false end
    if s.mode ~= "forge" and s.mode ~= "daily" then return false end
    if s.mode == "daily" and (type(s.movesLeft) ~= "number" or s.movesLeft < 0 or s.day == nil) then return false end
    self.mode, self.day = s.mode, s.day
    self.nextId, self.best = 0, 0
    for r = 1, Forge.N do for c = 1, Forge.N do
        local tier = s.cells[(r - 1) * Forge.N + c]
        if tier > 0 then
            self.nextId = self.nextId + 1
            self.grid[r][c] = { id = self.nextId, t = tier }
            if tier > self.best then self.best = tier end
        else
            self.grid[r][c] = nil
        end
    end end
    self.score, self.rs, self.moves = s.score, s.rs, s.moves
    self.movesLeft = s.mode == "daily" and s.movesLeft or nil
    self.undosLeft = s.mode == "forge" and math.max(0, math.min(Forge.UNDOS, tonumber(s.undosLeft) or 0)) or 0
    self.won = s.won and true or (self.best >= Forge.GOAL)
    if type(s.best) == "number" and s.best > self.best then self.best = s.best end
    self.undo = (s.mode == "forge" and GoodSnap(s.undo)) and s.undo or nil
    -- a forge that was cold when it was saved is still cold; anything else is checked afresh
    if (self.movesLeft and self.movesLeft <= 0) or not self:CanMove() then self.state = "over" else self.state = "play" end
    return true
end
