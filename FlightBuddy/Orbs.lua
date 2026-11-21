-- Flight Buddy :: Orbs.lua
-- Orb Cannon: the engine (no UI). A ceiling of orbs hangs over a cannon. Fire an orb up into
-- them (it banks off the side walls); three or more of a kind that touch burst, and anything
-- left hanging from nothing falls. Shots that burst nothing are misses, and enough misses bring
-- the ceiling down a row. It is over when the orbs reach the cannon's line.
--
-- Everything is in field units: x to the right, y DOWN from the ceiling. A shot is resolved at
-- once and the result says what happened (the path flown, what burst, what fell) for the screen
-- to play back.
local ADDON, NS = ...

local Orbs = {}
NS.Orbs = Orbs

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt

Orbs.W = 432
Orbs.D = 36                         -- an orb's width
Orbs.R = 18
Orbs.ROWH = 36 * 0.8660254          -- rows nest into each other
Orbs.MAXROW = 13                    -- an orb below this row has reached the line
Orbs.CX, Orbs.CY = 216, 492         -- the cannon's mouth
Orbs.MIN_A = 0.16                   -- the shallowest aim, in radians from the floor
Orbs.COLORS = 6
Orbs.PEARL, Orbs.BOMB = 7, 8        -- only ever fired, never left on the board
Orbs.KINDS = {
    { key = "arcane", name = "Arcane", color = { 0.78, 0.36, 1.00 } },
    { key = "fel",    name = "Fel",    color = { 0.50, 1.00, 0.25 } },
    { key = "lava",   name = "Lava",   color = { 1.00, 0.48, 0.14 } },
    { key = "snow",   name = "Frost",  color = { 0.80, 0.92, 1.00 } },
    { key = "hearth", name = "Storm",  color = { 0.30, 0.86, 1.00 } },
    { key = "egg",    name = "Gold",   color = { 1.00, 0.82, 0.25 } },
    { key = "pearl",  name = "Prismatic Orb", color = { 0.70, 1.00, 0.95 } },
    { key = "bomb",   name = "Goblin Bomb",   color = { 1.00, 0.35, 0.20 } },
}
Orbs.BOMB_REACH = 36 * 1.75         -- everything this near a bomb goes with it
Orbs.DAILY_ROWS, Orbs.DAILY_COLORS = 7, 5

local W, D, R, ROWH = Orbs.W, Orbs.D, Orbs.R, Orbs.ROWH
local TOUCH2 = (D * 0.86) ^ 2       -- a flying orb stops this near another (a little forgiving in gaps)
local NEAR2 = (D * 1.1) ^ 2

function Orbs.New()
    local g = setmetatable({}, { __index = Orbs })
    g.state = "idle"
    g.grid, g.shift = {}, 0
    g.rs = 1
    g.score, g.shots = 0, 0
    return g
end

function Orbs:Rand()
    self.rs = (self.rs * 16807) % 2147483647
    return (self.rs - 1) / 2147483646
end

local function DaySeed(day)
    local n = 0
    for ch in tostring(day):gmatch("%d") do n = (n * 10 + tonumber(ch)) % 2147483000 end
    return n * 13 + 9001
end

---------------------------------------------------------------------------
-- The honeycomb: wide rows hold 12 orbs, the rows nested between them 11
---------------------------------------------------------------------------
function Orbs:Wide(r) return (r + self.shift) % 2 == 1 end
function Orbs:Cols(r) return self:Wide(r) and 12 or 11 end
function Orbs:XY(r, c) return (self:Wide(r) and R or D) + (c - 1) * D, R + (r - 1) * ROWH end
function Orbs:At(r, c) local row = self.grid[r]; return row and row[c] or nil end

function Orbs:Set(r, c, v)
    local row = self.grid[r]
    if not row then row = {}; self.grid[r] = row end
    row[c] = v
end

function Orbs:Rows()
    local n = 0
    for r, row in pairs(self.grid) do
        if r > n and next(row) then n = r end
    end
    return n
end

-- the (up to six) cells touching (r, c), whether or not anything is in them
function Orbs:Around(r, c)
    local out = { { r, c - 1 }, { r, c + 1 } }
    local lo = self:Wide(r) and c - 1 or c       -- the nested rows sit half an orb across
    for _, rr in ipairs({ r - 1, r + 1 }) do
        out[#out + 1] = { rr, lo }
        out[#out + 1] = { rr, lo + 1 }
    end
    local n, keep = 0, {}
    for _, p in ipairs(out) do
        if p[1] >= 1 and p[2] >= 1 and p[2] <= self:Cols(p[1]) then n = n + 1; keep[n] = p end
    end
    return keep
end

function Orbs:Count()
    local n, seen = 0, {}
    for _, row in pairs(self.grid) do
        for _, v in pairs(row) do n = n + 1; seen[v] = true end
    end
    return n, seen
end

-- every orb on the board: { r, c, color }
function Orbs:Cells()
    local out = {}
    for r, row in pairs(self.grid) do
        for c, v in pairs(row) do out[#out + 1] = { r = r, c = c, color = v } end
    end
    return out
end

---------------------------------------------------------------------------
-- Starting
---------------------------------------------------------------------------
-- a row of orbs that tends to run in twos and threes of a colour, so there is something to aim at
function Orbs:MakeRow(r, colors)
    local row = {}
    for c = 1, self:Cols(r) do
        if c > 1 and self:Rand() < 0.42 then
            row[c] = row[c - 1]
        else
            row[c] = 1 + floor(self:Rand() * colors) % colors
        end
    end
    return row
end

function Orbs:Fill(rows, colors)
    self.grid = {}
    for r = 1, rows do self.grid[r] = self:MakeRow(r, colors) end
end

-- a colour for the cannon: only ones still on the board (nothing you cannot use)
function Orbs:Pick()
    local _, seen = self:Count()
    local have = {}
    for k = 1, Orbs.COLORS do if seen[k] then have[#have + 1] = k end end
    if #have == 0 then return 1 + floor(self:Rand() * self.colors) % self.colors end
    return have[1 + floor(self:Rand() * #have) % #have]
end

-- mode "barrage": endless waves (opts.seed); mode "daily": one board to clear (opts.day)
function Orbs:Start(mode, opts)
    opts = opts or {}
    self.mode = mode == "daily" and "daily" or "barrage"
    self.day = self.mode == "daily" and opts.day or nil
    local seed = self.mode == "daily" and DaySeed(opts.day or 0) or (opts.seed or 1)
    self.rs = floor(abs(seed)) % 2147483646 + 1
    self.shift = 0
    self.score, self.shots, self.misses, self.streak, self.level = 0, 0, 0, 0, 1
    self.bestDrop = 0
    self.colors = self.mode == "daily" and Orbs.DAILY_COLORS or 4
    self.limit = 5
    self:Fill(self.mode == "daily" and Orbs.DAILY_ROWS or 6, self.colors)
    self.cur, self.nxt = self:Pick(), self:Pick()
    self.state = "aim"
end

---------------------------------------------------------------------------
-- A shot
---------------------------------------------------------------------------
function Orbs:Touching(x, y)
    local r0 = floor((y - R) / ROWH + 0.5) + 1
    for r = max(1, r0 - 1), r0 + 1 do
        local row = self.grid[r]
        if row then
            local x0 = self:Wide(r) and R or D
            local c0 = floor((x - x0) / D + 0.5) + 1
            local cy = R + (r - 1) * ROWH
            for c = c0 - 1, c0 + 1 do
                if row[c] then
                    local dx, dy = x - (x0 + (c - 1) * D), y - cy
                    if dx * dx + dy * dy < TOUCH2 then return true end
                end
            end
        end
    end
    return false
end

-- the empty cell an orb stopping at (x, y) settles into
function Orbs:Snap(x, y)
    local r0 = floor((y - R) / ROWH + 0.5) + 1
    local best, br, bc
    for pass = 1, 2 do
        for r = max(1, r0 - 2), r0 + 2 do
            for c = 1, self:Cols(r) do
                if not self:At(r, c) then
                    local ok = pass == 2 or r == 1
                    if not ok then
                        for _, p in ipairs(self:Around(r, c)) do
                            if self:At(p[1], p[2]) then ok = true; break end
                        end
                    end
                    if ok then
                        local cx, cy = self:XY(r, c)
                        local d2 = (x - cx) ^ 2 + (y - cy) ^ 2
                        if not best or d2 < best then best, br, bc = d2, r, c end
                    end
                end
            end
        end
        if best then break end
    end
    return br, bc
end

function Orbs.ClampAim(a)
    if a < Orbs.MIN_A then return Orbs.MIN_A end
    if a > pi - Orbs.MIN_A then return pi - Orbs.MIN_A end
    return a
end

-- Where a shot at angle `a` (radians up from the floor; pi/2 is straight up) would go:
--   { pts = { {x, y}, ... corners of the path }, x, y = where it stops, r, c = the cell it takes }
function Orbs:Trace(a)
    a = Orbs.ClampAim(a)
    local x, y = Orbs.CX, Orbs.CY
    local dx, dy = cos(a) * 3, -sin(a) * 3
    local pts = { { x, y } }
    for _ = 1, 4000 do
        x, y = x + dx, y + dy
        if x < R then
            x = 2 * R - x; dx = -dx
            pts[#pts + 1] = { R, y }
        elseif x > W - R then
            x = 2 * (W - R) - x; dx = -dx
            pts[#pts + 1] = { W - R, y }
        end
        if y <= R then y = R; break end
        if self:Touching(x, y) then break end
    end
    pts[#pts + 1] = { x, y }
    local r, c = self:Snap(x, y)
    return { pts = pts, x = x, y = y, r = r, c = c }
end

-- every orb of `color` joined to (r, c), nearest first: { r, c, color, d = steps away }
local function Group(self, r, c, color)
    local out, seen = {}, {}
    local queue, head = { { r, c, 0 } }, 1
    seen[r * 100 + c] = true
    while queue[head] do
        local q = queue[head]; head = head + 1
        out[#out + 1] = { r = q[1], c = q[2], color = color, d = q[3] }
        for _, p in ipairs(self:Around(q[1], q[2])) do
            local k = p[1] * 100 + p[2]
            if not seen[k] and self:At(p[1], p[2]) == color then
                seen[k] = true
                queue[#queue + 1] = { p[1], p[2], q[3] + 1 }
            end
        end
    end
    return out
end

-- take out everything no longer hanging from the ceiling; returns the fallen
local function DropLoose(self)
    local held = {}
    local queue, head = {}, 1
    for c, v in pairs(self.grid[1] or {}) do
        if v then held[100 + c] = true; queue[#queue + 1] = { 1, c } end
    end
    while queue[head] do
        local q = queue[head]; head = head + 1
        for _, p in ipairs(self:Around(q[1], q[2])) do
            local k = p[1] * 100 + p[2]
            if not held[k] and self:At(p[1], p[2]) then
                held[k] = true
                queue[#queue + 1] = p
            end
        end
    end
    local fallen = {}
    for r, row in pairs(self.grid) do
        for c, v in pairs(row) do
            if not held[r * 100 + c] then fallen[#fallen + 1] = { r = r, c = c, color = v } end
        end
    end
    table.sort(fallen, function(a, b) if a.r ~= b.r then return a.r < b.r end return a.c < b.c end)
    for _, f in ipairs(fallen) do self.grid[f.r][f.c] = nil end
    return fallen
end

-- the ceiling comes down a row: a new row of orbs goes in at the top
function Orbs:AddRow()
    local n = self:Rows()
    for r = n, 1, -1 do self.grid[r + 1] = self.grid[r] end
    self.shift = 1 - self.shift
    self.grid[1] = self:MakeRow(1, self.colors)
    return self.grid[1]
end

function Orbs:Reached() return self:Rows() > Orbs.MAXROW end

-- Fire the orb in the cannon. Returns nil if it cannot be fired, otherwise
--   { pts =, x =, y = (the flight), kind = "orb" | "pearl" | "bomb", r, c, color (what it settled as),
--     popped = { { r, c, color, d } ... }, dropped = { { r, c, color } ... }, gained =, mult =,
--     rowAdded = true, award = "pearl" | "bomb", cleared = true, wave = true (a new wave came in),
--     over = true }
function Orbs:Fire(a)
    if self.state ~= "aim" then return nil end
    local t = self:Trace(a)
    if not t.r then return nil end
    local shot = self.cur
    local res = { pts = t.pts, x = t.x, y = t.y, r = t.r, c = t.c, popped = {}, dropped = {}, gained = 0,
        kind = shot == Orbs.BOMB and "bomb" or (shot == Orbs.PEARL and "pearl" or "orb") }
    self.shots = self.shots + 1
    local cx, cy = self:XY(t.r, t.c)
    if shot == Orbs.BOMB then
        res.color = Orbs.BOMB
        for _, o in ipairs(self:Cells()) do
            local ox, oy = self:XY(o.r, o.c)
            local d = sqrt((ox - cx) ^ 2 + (oy - cy) ^ 2)
            if d <= Orbs.BOMB_REACH then
                res.popped[#res.popped + 1] = { r = o.r, c = o.c, color = o.color, d = floor(d / D + 0.5) }
            end
        end
        table.sort(res.popped, function(p, q) if p.d ~= q.d then return p.d < q.d end if p.r ~= q.r then return p.r < q.r end return p.c < q.c end)
        for _, p in ipairs(res.popped) do self.grid[p.r][p.c] = nil end
    else
        local color = shot
        if shot == Orbs.PEARL then
            -- the Prismatic Orb becomes whichever colour beside it makes the biggest burst
            local bestN = 0
            color = nil
            for k = 1, Orbs.COLORS do
                local touching = false
                for _, p in ipairs(self:Around(t.r, t.c)) do if self:At(p[1], p[2]) == k then touching = true end end
                if touching then
                    self:Set(t.r, t.c, k)
                    local n = #Group(self, t.r, t.c, k)
                    self.grid[t.r][t.c] = nil
                    if n > bestN then bestN, color = n, k end
                end
            end
            color = color or self:Pick()
        end
        res.color = color
        self:Set(t.r, t.c, color)
        local group = Group(self, t.r, t.c, color)
        if #group >= 3 or (shot == Orbs.PEARL and #group >= 2) then
            res.popped = group
            for _, p in ipairs(group) do self.grid[p.r][p.c] = nil end
        end
    end
    if #res.popped > 0 then
        res.dropped = DropLoose(self)
        self.streak = self.streak + 1
        res.mult = 1 + 0.1 * min(10, self.streak - 1)
        local pts = 10 * #res.popped
        for i = 1, #res.dropped do pts = pts + min(200, 20 * i) end
        res.gained = floor(pts * res.mult + 0.5)
        if #res.dropped > self.bestDrop then self.bestDrop = #res.dropped end
        if #res.dropped >= 6 then res.award = "bomb"
        elseif self.streak % 4 == 0 then res.award = "pearl" end
    else
        self.streak = 0
        self.misses = self.misses + 1
        if self.misses >= self.limit then
            self.misses = 0
            self:AddRow()
            res.rowAdded = true
        end
    end
    res.streak = self.streak
    self.score = self.score + res.gained
    local left = self:Count()
    if left == 0 then
        res.cleared = true
        if self.mode == "daily" then
            -- the fewer shots, the bigger the bonus
            res.bonus = 1500 + max(0, 60 - self.shots) * 40
            self.score = self.score + res.bonus
            self.state = "won"
        else
            res.bonus = 500 * self.level
            self.score = self.score + res.bonus
            self.level = self.level + 1
            self.colors = min(Orbs.COLORS, 4 + floor(self.level / 2))
            self.limit = max(3, 5 - floor((self.level - 1) / 3))
            self.misses, self.shift = 0, 0
            self:Fill(min(9, 5 + self.level), self.colors)
            res.wave = true
        end
    elseif self:Reached() then
        self.state = "over"
        res.over = true
    end
    -- reload
    if self.state == "aim" then
        self.cur = self.nxt
        self.nxt = res.award == "bomb" and Orbs.BOMB or (res.award == "pearl" and Orbs.PEARL or self:Pick())
        local _, seen = self:Count()
        if self.cur <= Orbs.COLORS and not seen[self.cur] then self.cur = self:Pick() end
        if self.nxt <= Orbs.COLORS and not seen[self.nxt] then self.nxt = self:Pick() end
    end
    return res
end

-- swap the orb in the cannon with the one waiting
function Orbs:Swap()
    if self.state ~= "aim" then return false end
    self.cur, self.nxt = self.nxt, self.cur
    return true
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
function Orbs:Serialize()
    if self.state ~= "aim" then return nil end
    local rows = {}
    for r = 1, self:Rows() do
        local t = {}
        for c = 1, self:Cols(r) do t[c] = self:At(r, c) or 0 end
        rows[r] = table.concat(t)
    end
    return { v = 1, mode = self.mode, day = self.day, rows = rows, shift = self.shift, score = self.score, shots = self.shots,
        misses = self.misses, streak = self.streak, level = self.level, colors = self.colors, limit = self.limit,
        cur = self.cur, nxt = self.nxt, rs = self.rs, bestDrop = self.bestDrop }
end

local function Whole(v, lo, hi) return type(v) == "number" and v == floor(v) and v >= lo and v <= hi end

function Orbs:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or type(s.rows) ~= "table" then return false end
    if s.mode ~= "barrage" and s.mode ~= "daily" then return false end
    if s.mode == "daily" and s.day == nil then return false end
    if not (Whole(s.shift, 0, 1) and Whole(s.score, 0, 1e9) and Whole(s.shots, 0, 1e6) and Whole(s.misses, 0, 9)
        and Whole(s.level, 1, 999) and Whole(s.colors, 3, Orbs.COLORS) and Whole(s.limit, 2, 9)
        and Whole(s.cur, 1, Orbs.BOMB) and Whole(s.nxt, 1, Orbs.BOMB) and Whole(s.rs, 1, 2147483646)) then return false end
    if #s.rows > Orbs.MAXROW then return false end
    local grid, n = {}, 0
    for r = 1, #s.rows do
        local str = s.rows[r]
        local cols = ((r + s.shift) % 2 == 1) and 12 or 11
        if type(str) ~= "string" or #str ~= cols or str:find("[^0-6]") then return false end
        grid[r] = {}
        for c = 1, cols do
            local v = tonumber(str:sub(c, c))
            if v > 0 then grid[r][c] = v; n = n + 1 end
        end
    end
    if n == 0 then return false end
    self.mode, self.day, self.grid, self.shift = s.mode, s.day, grid, s.shift
    self.score, self.shots, self.misses, self.level = s.score, s.shots, s.misses, s.level
    self.streak = Whole(s.streak, 0, 1e6) and s.streak or 0
    self.bestDrop = Whole(s.bestDrop, 0, 999) and s.bestDrop or 0
    self.colors, self.limit, self.cur, self.nxt, self.rs = s.colors, s.limit, s.cur, s.nxt, s.rs
    self.state = "aim"
    -- anything a damaged save left hanging in mid-air comes down quietly
    DropLoose(self)
    if self:Count() == 0 then self.state = "idle"; return false end
    return true
end
