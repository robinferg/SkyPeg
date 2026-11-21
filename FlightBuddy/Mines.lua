-- Flight Buddy :: Mines.lua
-- Goblin Minefield: the engine (no UI). The goblins have mined a field; dig every square that
-- has no mine under it. A dug square shows how many of its eight neighbours are mined, and a
-- square with none opens everything around it. Flags mark where you think the mines are.
--   * The first dig is always safe, and so are the squares around it.
--   * Digging a numbered square that already has that many flags round it digs the rest
--     ("chording"): fast, and fatal if a flag is wrong.
--   * One Gnomish Mine Detector a game points out a safe square, for a few seconds on the clock.
-- The score is the time taken; lower is better.
local ADDON, NS = ...

local Mines = {}
NS.Mines = Mines

local floor = math.floor

Mines.SIZES = {
    { key = "small",  name = "Scrap Heap",      n = 9,  mines = 10, board = "ms1" },
    { key = "medium", name = "Proving Grounds", n = 12, mines = 22, board = "ms2" },
    { key = "large",  name = "No Man's Land",   n = 16, mines = 48, board = "ms3" },
}
Mines.DAILY = { key = "daily", name = "Daily Sweep", n = 12, mines = 24, board = "msd" }
Mines.DETECTORS = 1
Mines.DETECT_COST = 10      -- seconds added to the clock for using the detector

function Mines.Size(key)
    for _, s in ipairs(Mines.SIZES) do if s.key == key then return s end end
    return Mines.SIZES[1]
end

function Mines.New()
    local g = setmetatable({}, { __index = Mines })
    g.state = "idle"
    g.n, g.total = 0, 0
    g.grid = {}
    g.rs = 1
    return g
end

function Mines:Rand()
    self.rs = (self.rs * 16807) % 2147483647
    return (self.rs - 1) / 2147483646
end

local function DaySeed(day)
    local n = 0
    for ch in tostring(day):gmatch("%d") do n = (n * 10 + tonumber(ch)) % 2147483000 end
    return n * 17 + 4242
end

local function Around(self, r, c, fn)
    for dr = -1, 1 do
        for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then
                local rr, cc = r + dr, c + dc
                if rr >= 1 and cc >= 1 and rr <= self.n and cc <= self.n then fn(rr, cc, self.grid[rr][cc]) end
            end
        end
    end
end

-- mode "field": opts.size ("small" | "medium" | "large"), opts.seed. Mines are laid at the first
--   dig, away from it.
-- mode "daily": opts.day. The same field for everyone, with the same opening already dug.
--   opts.penalty = seconds already on the clock (the price of earlier tries that day).
function Mines:Start(mode, opts)
    opts = opts or {}
    self.mode = mode == "daily" and "daily" or "field"
    local spec = self.mode == "daily" and Mines.DAILY or Mines.Size(opts.size)
    self.size, self.day = spec.key, self.mode == "daily" and opts.day or nil
    self.n, self.total = spec.n, spec.mines
    local seed = self.mode == "daily" and DaySeed(opts.day or 0) or (opts.seed or 1)
    self.rs = floor(math.abs(seed)) % 2147483646 + 1
    self.grid = {}
    for r = 1, self.n do
        self.grid[r] = {}
        for c = 1, self.n do self.grid[r][c] = { mine = false, n = 0, open = false, flag = false } end
    end
    self.laid = false
    self.opened, self.flags = 0, 0
    self.elapsed, self.penalty = 0, math.max(0, tonumber(opts.penalty) or 0)
    self.detectors = Mines.DETECTORS
    self.clock = false
    self.boom, self.hint = nil, nil
    self.state = "play"
    if self.mode == "daily" then
        -- everyone starts from the same hole in the ground, somewhere in the middle
        local n = self.n
        local r = 3 + floor(self:Rand() * (n - 4))
        local c = 3 + floor(self:Rand() * (n - 4))
        self.start = { r = r, c = c }
        local res = self:Dig(r, c, true)
        -- the opening is on show from the first moment, so the clock is too
        self.clock = true
        return res
    end
    self.start = nil
    return nil
end

function Mines:Lay(sr, sc)
    local n = self.n
    local spots = {}
    for r = 1, n do
        for c = 1, n do
            if math.abs(r - sr) > 1 or math.abs(c - sc) > 1 then spots[#spots + 1] = { r, c } end
        end
    end
    for _ = 1, math.min(self.total, #spots) do
        local i = 1 + floor(self:Rand() * #spots)
        if i > #spots then i = #spots end
        local s = table.remove(spots, i)
        self.grid[s[1]][s[2]].mine = true
    end
    for r = 1, n do
        for c = 1, n do
            local cell = self.grid[r][c]
            cell.n = 0
            Around(self, r, c, function(_, _, o) if o.mine then cell.n = cell.n + 1 end end)
        end
    end
    self.laid = true
end

function Mines:Safe() return self.n * self.n - self.total end
function Mines:MinesLeft() return self.total - self.flags end
function Mines:Time() return (self.elapsed or 0) + (self.penalty or 0) end

function Mines:Tick(dt)
    if self.state == "play" and self.clock then self.elapsed = self.elapsed + dt end
end

-- open (r, c) and everything a blank square opens; `out` collects { r, c, n, d = steps away }
local function Open(self, r, c, out)
    local queue = { { r, c, 0 } }
    local head = 1
    local first = self.grid[r][c]
    if first.open or first.flag then return end
    first.open = true
    self.opened = self.opened + 1
    while queue[head] do
        local q = queue[head]
        head = head + 1
        local cell = self.grid[q[1]][q[2]]
        out[#out + 1] = { r = q[1], c = q[2], n = cell.n, d = q[3] }
        if cell.n == 0 then
            Around(self, q[1], q[2], function(rr, cc, o)
                if not o.open and not o.mine then
                    if o.flag then o.flag = false; self.flags = self.flags - 1 end
                    o.open = true
                    self.opened = self.opened + 1
                    queue[#queue + 1] = { rr, cc, q[3] + 1 }
                end
            end)
        end
    end
end

local function Finish(self, res)
    if res.boom then
        self.state = "lost"
        self.boom = res.boom
        res.lost = true
    elseif self.opened >= self:Safe() then
        self.state = "won"
        res.won = true
        -- the mines that are left plant their own flags
        for r = 1, self.n do for c = 1, self.n do
            local cell = self.grid[r][c]
            if cell.mine and not cell.flag then cell.flag = true; self.flags = self.flags + 1 end
        end end
    end
    return res
end

-- Dig a covered square. Returns nil if nothing happened, otherwise
--   { opened = { { r, c, n, d } ... }, boom = { r, c } when it was a mine, won =, lost = }
function Mines:Dig(r, c, opening)
    if self.state ~= "play" then return nil end
    local cell = self.grid[r] and self.grid[r][c]
    if not cell or cell.open or cell.flag then return nil end
    if not self.laid then self:Lay(r, c) end
    if not opening then self.clock = true end
    self.hint = nil
    local res = { opened = {} }
    if cell.mine then
        res.boom = { r = r, c = c }
    else
        Open(self, r, c, res.opened)
    end
    return Finish(self, res)
end

-- plant or pull up a flag on a covered square
function Mines:Flag(r, c)
    if self.state ~= "play" then return false end
    local cell = self.grid[r] and self.grid[r][c]
    if not cell or cell.open then return false end
    cell.flag = not cell.flag
    self.flags = self.flags + (cell.flag and 1 or -1)
    return true
end

-- Dig everything round a numbered square that already has its number of flags.
function Mines:Chord(r, c)
    if self.state ~= "play" then return nil end
    local cell = self.grid[r] and self.grid[r][c]
    if not cell or not cell.open or cell.n == 0 then return nil end
    local flags, covered = 0, {}
    Around(self, r, c, function(rr, cc, o)
        if o.flag then flags = flags + 1 elseif not o.open then covered[#covered + 1] = { rr, cc } end
    end)
    if flags ~= cell.n or #covered == 0 then return nil end
    self.clock = true
    self.hint = nil
    local res = { opened = {} }
    for _, p in ipairs(covered) do
        local o = self.grid[p[1]][p[2]]
        if o.mine then
            res.boom = res.boom or { r = p[1], c = p[2] }
        end
    end
    if not res.boom then
        for _, p in ipairs(covered) do Open(self, p[1], p[2], res.opened) end
        -- distances in a chord are measured from the number that was clicked
        for _, o in ipairs(res.opened) do o.d = o.d + 1 end
    end
    return Finish(self, res)
end

-- The Gnomish Mine Detector: one safe covered square, by preference one next to ground already
-- dug. Costs DETECT_COST seconds. Returns { r, c } or nil.
function Mines:Detect()
    if self.state ~= "play" or not self.laid or (self.detectors or 0) <= 0 then return nil end
    local near, far = {}, {}
    for r = 1, self.n do
        for c = 1, self.n do
            local cell = self.grid[r][c]
            if not cell.open and not cell.mine and not cell.flag then
                local touching = false
                Around(self, r, c, function(_, _, o) if o.open then touching = true end end)
                if touching then near[#near + 1] = { r, c } else far[#far + 1] = { r, c } end
            end
        end
    end
    local pool = #near > 0 and near or far
    if #pool == 0 then return nil end
    -- (its own little dice, so using the detector never changes where anything else is)
    local pick = pool[1 + (floor(self.elapsed * 10) + self.opened * 7) % #pool]
    self.detectors = self.detectors - 1
    self.penalty = self.penalty + Mines.DETECT_COST
    self.clock = true
    self.hint = { r = pick[1], c = pick[2] }
    return self.hint
end

-- after a loss: where every mine was and which flags were wrong
function Mines:Reveal()
    local mines, wrong = {}, {}
    for r = 1, self.n do
        for c = 1, self.n do
            local cell = self.grid[r][c]
            if cell.mine and not cell.flag then mines[#mines + 1] = { r = r, c = c } end
            if cell.flag and not cell.mine then wrong[#wrong + 1] = { r = r, c = c } end
        end
    end
    return mines, wrong
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
function Mines:Serialize()
    if self.state ~= "play" then return nil end
    local cells = {}
    for r = 1, self.n do
        for c = 1, self.n do
            local cell = self.grid[r][c]
            cells[#cells + 1] = (cell.mine and 1 or 0) + (cell.open and 2 or 0) + (cell.flag and 4 or 0)
        end
    end
    return { v = 1, mode = self.mode, size = self.size, day = self.day, n = self.n, total = self.total,
        cells = table.concat(cells), laid = self.laid, elapsed = floor(self.elapsed * 10) / 10, penalty = self.penalty,
        detectors = self.detectors, rs = self.rs, clock = self.clock, start = self.start and (self.start.r * 100 + self.start.c) or nil,
        hint = self.hint and (self.hint.r * 100 + self.hint.c) or nil }
end

function Mines:Restore(s)
    if type(s) ~= "table" or s.v ~= 1 or type(s.cells) ~= "string" then return false end
    if s.mode ~= "field" and s.mode ~= "daily" then return false end
    local spec = s.mode == "daily" and Mines.DAILY or Mines.Size(s.size)
    if spec.key ~= s.size or s.n ~= spec.n or s.total ~= spec.mines or #s.cells ~= spec.n * spec.n then return false end
    if s.cells:find("[^0-7]") or type(s.elapsed) ~= "number" or s.elapsed < 0 then return false end
    if s.mode == "daily" and s.day == nil then return false end
    local grid, opened, flags, mines = {}, 0, 0, 0
    for r = 1, spec.n do
        grid[r] = {}
        for c = 1, spec.n do
            local v = tonumber(s.cells:sub((r - 1) * spec.n + c, (r - 1) * spec.n + c))
            local cell = { mine = v % 2 == 1, open = floor(v / 2) % 2 == 1, flag = v >= 4, n = 0 }
            if cell.mine and cell.open then return false end
            if cell.open and cell.flag then return false end
            if cell.mine then mines = mines + 1 end
            if cell.open then opened = opened + 1 end
            if cell.flag then flags = flags + 1 end
            grid[r][c] = cell
        end
    end
    local laid = s.laid and true or false
    if laid and mines ~= spec.mines then return false end
    if not laid and (mines > 0 or opened > 0) then return false end
    self.mode, self.size, self.day = s.mode, s.size, s.day
    self.n, self.total, self.grid = spec.n, spec.mines, grid
    self.laid, self.opened, self.flags = laid, opened, flags
    for r = 1, self.n do
        for c = 1, self.n do
            local cell = grid[r][c]
            Around(self, r, c, function(_, _, o) if o.mine then cell.n = cell.n + 1 end end)
        end
    end
    self.elapsed = s.elapsed
    self.penalty = math.max(0, tonumber(s.penalty) or 0)
    self.detectors = math.max(0, math.min(Mines.DETECTORS, tonumber(s.detectors) or 0))
    self.rs = (type(s.rs) == "number" and s.rs >= 1 and s.rs < 2147483647) and floor(s.rs) or 1
    self.clock = s.clock and true or false
    self.start = s.start and { r = floor(s.start / 100), c = s.start % 100 } or nil
    self.hint = s.hint and { r = floor(s.hint / 100), c = s.hint % 100 } or nil
    if self.hint then
        local h = self.grid[self.hint.r] and self.grid[self.hint.r][self.hint.c]
        if not h or h.open or h.mine then self.hint = nil end
    end
    self.boom = nil
    self.state = (laid and opened >= self:Safe()) and "won" or "play"
    return true
end
