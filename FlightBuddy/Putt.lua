-- Flight Buddy :: Putt.lua
-- Gryphon Greens: top-down mini golf time trial. Pure simulation (no WoW API).
local ADDON, NS = ...

local Putt = {}
NS.Putt = Putt

local sqrt, abs, min, max, floor = math.sqrt, math.abs, math.min, math.max, math.floor
local cos, sin, pi = math.cos, math.sin, math.pi

local P = {
    W = 480, H = 560, CELL = 40, COLS = 12, ROWS = 14,
    BALL_R = 6, CUP_R = 10,
    MAX_SPEED = 900, POWER_CURVE = 1.3,  -- roll distance = full distance * power^1.3 (half pull ~ 40%)
    DECEL = 95, DRAG = 0.50,   -- lighter rolling resistance + speed drag: smooth roll-outs, no dead stop
    STEP = 1 / 240, MAX_STEPS = 96,
    STOP = 3, SINK_SPEED = 220, SINK_SPEED_LONG = 120,   -- the ball must arrive gently to drop: long putts that come in hot lip out
    LIP = 0.4,          -- ...and gentler still off-centre: a ball catching the edge of the cup drops at this much less pace than one dead centre
    WALL_E = 0.78, BUMP_E = 0.86,
    SLOPE = 45, BOOST = 1100, BOOST_MAX = 500,
    MAX_STROKES = 8,
    STROKE_SEC = 5,     -- each stroke under par takes this much off your time (over par adds it)
    ACE_SEC = 5,        -- extra bonus for a hole-in-one
    COIN_SEC = 3,       -- a lucky coin picked up on the way takes this much off your time
    MAX_BONUS = 0.5,    -- bonuses can take off at most this share of your clock
    SHOT_TIMEOUT = 14,
    -- Grass slows a fast ball more than a slow one (see Putt.Friction). A ball at rest sits still on
    -- any slope that pulls less than HOLD x the friction; once it is rolling slowly the grass holds
    -- it less than that (SLIP, least at SLIP_V), so on a steep slope it keeps rolling downhill, at a
    -- pace you can see, until the ground eases off.
    HOLD = 0.62, SLIP = 0.55, SLIP_V = 24, CREEP_V = 120,
    REV = 5,            -- goes up whenever the holes or the way a ball rolls change (old best times are retired)
    HOLES = 6,
    WOBBLE_FROM = 0.75,          -- above this power the putt starts losing accuracy...
    WOBBLE = math.rad(2.5),      -- ...up to this much random angle error at full power
    BEVEL = 18,                  -- every inside corner is cut by a short angled rail: no 90-degree pockets
    RELIEF = 20,                 -- a ball that stops against a rail is eased this far (centre) off it
    TUNNEL_EXIT = 190,           -- minimum speed a ball leaves a tunnel with
    FAN = 6,                     -- fan strength multiplier: strong enough to bend a putt and carry a stopped ball
    FENCE_T = 3.5,               -- half the thickness of an added wall (PuttHard.lua "walls")
}
Putt.C = P

-- What slows a ball rolling at speed sp over ground with this rolling resistance and drag.
-- On sand, snow, ice and the like (plain = false) it is the plain sum, decel + drag x speed.
-- Grass is the same at CREEP_V and above; below that both parts ease off. The resistance falls to
-- SLIP of itself at SLIP_V and comes back up to HOLD as the ball stops, the way a thing is harder to
-- start moving than to keep moving. So nothing creeps: on a slope a ball either stops, or rolls.
function Putt.Friction(sp, decel, drag, plain)
    if not plain or sp >= P.CREEP_V then return decel + drag * sp end
    local k
    if sp < P.SLIP_V then
        k = 1 - sp / P.SLIP_V
        k = P.SLIP + (P.HOLD - P.SLIP) * k * k
    else
        k = (sp - P.SLIP_V) / (P.CREEP_V - P.SLIP_V)
        k = P.SLIP + (1 - P.SLIP) * k * k
    end
    return decel * k + drag * sp * sp / P.CREEP_V
end

-- terrain codes ------------------------------------------------------------
-- decel/drag override grass; hazard = penalty stroke and return to last spot
Putt.TERRAIN = {
    ["."] = { name = "grass" },
    T = { name = "grass" }, C = { name = "grass" }, o = { name = "grass" }, O = { name = "grass" },
    A = { name = "grass" }, B = { name = "grass" },
    s = { name = "sand", decel = 640, drag = 1.2 },
    n = { name = "snow", decel = 800, drag = 1.2 },
    i = { name = "ice", decel = 26, drag = 0.05 },
    w = { name = "water", hazard = "Splash!" },
    l = { name = "lava", hazard = "Scorched!" },
    x = { name = "slime", hazard = "Slimed!" },
    g = { name = "goo", decel = 4000, drag = 12 },   -- sticky bog: grabs the ball, no penalty
    ["^"] = { name = "slope", slope = { 0, -1 } }, v = { name = "slope", slope = { 0, 1 } },
    ["<"] = { name = "slope", slope = { -1, 0 } }, [">"] = { name = "slope", slope = { 1, 0 } },
    -- a real hill: steeper than rolling resistance, so a ball that runs out of pace rolls back down
    J = { name = "slope", slope = { 0, 3 } }, K = { name = "slope", slope = { 0, -3 } },
    p = { name = "pit", pit = "Fell on the tracks!" },   -- only safe where a tram car is passing
    H = { name = "hearth", hearth = true },    -- a hearthstone rune: touch it and the ball goes home to the tee
    h = { name = "hex", hex = true },
    q = { name = "sheep", hex = true, sheep = true },   -- a mage's polymorph: the ball becomes a sheep and wanders          -- a witch doctor's brew: the ball turns into a frog and hops about on its own
    M = { name = "moonwell", bless = true },   -- roll through it and the next shot goes further
    U = { name = "boost", boost = { 0, -1 } }, D = { name = "boost", boost = { 0, 1 } },
    L = { name = "boost", boost = { -1, 0 } }, R = { name = "boost", boost = { 1, 0 } },
}
local TERRAIN = Putt.TERRAIN

---------------------------------------------------------------------------
-- Building a hole from a template
---------------------------------------------------------------------------
local function rotatePoint(x, y, mirror)
    if mirror then return P.W - x, y end
    return x, y
end

-- template = { name, theme, map = {14 strings of 12 chars}, walls = {{gx1,gy1,gx2,gy2},...},
--              setup = function(hole, rng, mirror) end }
local SWAP = { ["<"] = ">", [">"] = "<", L = "R", R = "L" }

-- spatial index: which walls are near each 40-unit cell (keeps collision cheap)
local function IndexWalls(h)
    local G = 40
    local cols, rows = math.ceil(P.W / G), math.ceil(P.H / G)
    local cells = {}
    for i, w in ipairs(h.walls) do
        local pad = 10
        local c0, c1 = max(0, floor((min(w[1], w[3]) - pad) / G)), min(cols - 1, floor((max(w[1], w[3]) + pad) / G))
        local r0, r1 = max(0, floor((min(w[2], w[4]) - pad) / G)), min(rows - 1, floor((max(w[2], w[4]) + pad) / G))
        for r = r0, r1 do
            for c = c0, c1 do
                local k = r * cols + c + 1
                local list = cells[k]
                if not list then list = {}; cells[k] = list end
                list[#list + 1] = w
            end
        end
    end
    h.wallCells, h.wallG, h.wallCols = cells, G, cols
end

local NONE = {}
function Putt.WallsNear(h, x, y)
    if not h.wallCells then return h.walls end
    local G = h.wallG
    local c, r = floor(x / G), floor(y / G)
    if c < 0 or r < 0 or c >= h.wallCols then return NONE end
    return h.wallCells[r * h.wallCols + c + 1] or NONE
end

-- every wall within ~40 units of (x, y): the 3x3 block of index cells
function Putt.WallsAround(h, x, y)
    if not h.wallCells then return h.walls end
    local G, cols = h.wallG, h.wallCols
    local c, r = floor(x / G), floor(y / G)
    local out, seen = {}, {}
    for rr = r - 1, r + 1 do
        for cc = c - 1, c + 1 do
            if cc >= 0 and rr >= 0 and cc < cols then
                local list = h.wallCells[rr * cols + cc + 1]
                if list then
                    for i = 1, #list do
                        local w = list[i]
                        if not seen[w] then seen[w] = true; out[#out + 1] = w end
                    end
                end
            end
        end
    end
    return out
end

-- painted holes (courseart/build.py): fine terrain grid + traced rails + objects
local function BuildPainted(tpl, seed, mirror, rng)
    local W = P.W
    local function X(x) return mirror and (W - x) or x end
    local h = {
        name = tpl.name, tip = tpl.tip, mirror = mirror, art = tpl.art, key = tpl.key,
        walls = {}, bumpers = {}, movers = {}, portals = {}, boosts = {}, fans = {}, ramps = {},
        res = tpl.res, grid = {}, theme = tpl.theme or "elwynn", baked = true,
    }
    h.gridCols, h.gridRows = #tpl.grid[1], #tpl.grid
    local remap = tpl.extra and tpl.extra.remap
    for i, row in ipairs(tpl.grid) do
        if remap then row = row:gsub(".", remap) end
        if mirror then row = row:reverse():gsub("[<>LR]", SWAP) end
        h.grid[i] = row
    end
    -- patches laid over the painted grass (PuttHard.lua): sand traps, ice, boost lanes. Only plain
    -- grass is replaced, so a patch never covers a hazard, a slope or the edge of the hole.
    h.patches, h.coins = {}, {}
    local pex = tpl.extra
    for _, pt in ipairs(pex and pex.patches or {}) do
        local ch = pt.t
        if mirror and SWAP[ch] then ch = SWAP[ch] end
        local q = { t = ch, shape = pt.shape }
        if pt.shape == "circle" then
            q.x, q.y, q.r = X(pt.x), pt.y, pt.r
            q.x1, q.y1, q.x2, q.y2 = q.x - q.r, q.y - q.r, q.x + q.r, q.y + q.r
        else
            local xa, xb = X(pt.x1), X(pt.x2)
            q.x1, q.y1, q.x2, q.y2 = min(xa, xb), pt.y1, max(xa, xb), pt.y2
        end
        local res = h.res
        for row = max(1, floor(q.y1 / res) + 1), min(h.gridRows, floor(q.y2 / res) + 1) do
            local line = h.grid[row]
            local cy = (row - 0.5) * res
            local out, changed = {}, false
            local c0, c1 = max(1, floor(q.x1 / res) + 1), min(h.gridCols, floor(q.x2 / res) + 1)
            for col = c0, c1 do
                local cx = (col - 0.5) * res
                local inside = (q.shape ~= "circle") or ((cx - q.x) ^ 2 + (cy - q.y) ^ 2 <= q.r * q.r)
                if inside and line:sub(col, col) == "." then out[col] = ch; changed = true end
            end
            if changed then
                local t = {}
                for col = 1, #line do t[col] = out[col] or line:sub(col, col) end
                h.grid[row] = table.concat(t)
            end
        end
        h.patches[#h.patches + 1] = q
    end
    for _, c in ipairs(pex and pex.coins or {}) do
        h.coins[#h.coins + 1] = { x = X(c[1]), y = c[2] }
    end
    if tpl.lie then
        h.lie = {}
        for i, row in ipairs(tpl.lie) do h.lie[i] = mirror and row:reverse() or row end
    end
    local fw = tpl.walls
    for i = 1, #fw, 4 do
        h.walls[#h.walls + 1] = { X(fw[i]), fw[i + 1], X(fw[i + 2]), fw[i + 3] }
    end
    h.boundaryWalls = #h.walls
    h.tee = { x = X(tpl.tee[1]), y = tpl.tee[2] }
    h.cup = { x = X(tpl.cup[1]), y = tpl.cup[2] }
    -- bumpers painted into the art are invisible to the UI; tpl.showPosts lists any the art forgot
    -- to paint (by index), which get drawn as the course's post sprite instead
    local show = tpl.showPosts
    for i, b in ipairs(tpl.bumpers or {}) do
        local visible = false
        for _, k in ipairs(show and show.idx or {}) do if k == i then visible = true end end
        if visible then
            h.bumpers[#h.bumpers + 1] = { x = X(b[1]), y = b[2], r = b[3], style = show.style }
        else
            h.bumpers[#h.bumpers + 1] = { x = X(b[1]), y = b[2], r = b[3], baked = true, kick = b[4] }
        end
    end
    for _, p in ipairs(tpl.portals or {}) do
        local pt = { ax = X(p.ax), ay = p.ay, bx = X(p.bx), by = p.by, r = p.r or 15, baked = true }
        if p.dx then pt.dx = (mirror and -1 or 1) * p.dx; pt.dy = p.dy end
        if p.adx then pt.adx = (mirror and -1 or 1) * p.adx; pt.ady = p.ady end
        pt.exit = p.exit
        pt.markB = p.markB   -- the far mouth is not in the painting: the game draws it
        pt.lift = p.lift     -- "up" or "down": a lift platform the ball rides in plain sight, not a tunnel
        h.portals[#h.portals + 1] = pt
    end
    -- launch ramps: hit one fast enough, along its direction, and the ball flies over whatever is behind it
    for _, rp in ipairs(tpl.ramps or {}) do
        h.ramps[#h.ramps + 1] = { x = X(rp.x), y = rp.y, r = rp.r or 12, dx = (mirror and -1 or 1) * rp.dx, dy = rp.dy,
                                  min = rp.min or 260, clear = rp.clear or 90 }
    end
    -- cannons: roll onto the pad and the ball is fired through the air to a fixed landing spot
    h.cannons = {}
    for _, c in ipairs(tpl.cannons or {}) do
        h.cannons[#h.cannons + 1] = { x = X(c.x), y = c.y, r = c.r or 12, tx = X(c.tx), ty = c.ty, dur = c.dur or 1.1,
                                      vx = (mirror and -1 or 1) * (c.vx or 0), vy = c.vy or 0 }
    end
    local function range(v)
        if type(v) == "table" then return v[1] + rng.next() * (v[2] - v[1]) end
        return v
    end
    local function addMover(m)
        if m.kind == "spinner" then
            local dir = rng.next() < 0.5 and 1 or -1
            h.movers[#h.movers + 1] = { kind = "spinner", cx = X(m.cx), cy = m.cy, len = m.len, arms = m.arms or 4,
                spd = dir * range(m.spd or { 1.1, 1.6 }), a0 = rng.next() * pi, sails = m.sails, gear = m.gear }
        elseif m.kind == "patrol" then
            h.movers[#h.movers + 1] = { kind = "patrol", faction = m.faction or "alliance", r = m.r or 13, carry = m.carry,
                x1 = X(m.x1), y1 = m.y1, x2 = X(m.x2), y2 = m.y2, spd = range(m.spd or { 0.8, 1.2 }), phase = rng.next() * 6 }
        elseif m.kind == "slider" then
            h.movers[#h.movers + 1] = { kind = "slider", x1 = X(m.x1), y1 = m.y1, x2 = X(m.x2), y2 = m.y2,
                dx = (mirror and -1 or 1) * (m.dx or 1), dy = m.dy or 0, amp = m.amp or 40, spd = range(m.spd or { 1.6, 2.2 }), phase = rng.next() * 6 }
        elseif m.kind == "orbit" then
            -- wisps circling a spot: little glowing bumpers that drift round and round
            h.movers[#h.movers + 1] = { kind = "orbit", cx = X(m.cx), cy = m.cy, rad = m.rad or 40, n = m.n or 2, r = m.r or 8,
                spd = (mirror and -1 or 1) * (m.spd or 1.2), a0 = m.a0 or rng.next() * 6.28, pts = {} }
        elseif m.kind == "tram" then
            -- a flat car sliding along its track: the only safe ground over the pit it runs in
            h.movers[#h.movers + 1] = { kind = "tram", x1 = X(m.x1), x2 = X(m.x2), y = m.y, hw = m.hw or 60, hh = m.hh or 40,
                spd = m.spd or 0.6, phase = m.phase or 0, x = X(m.x1), tex = m.tex }
        elseif m.kind == "gate" then
            -- a portcullis bar that slides across a gap and back on a steady beat
            h.movers[#h.movers + 1] = { kind = "gate", x1 = X(m.x1), y1 = m.y1, x2 = X(m.x2), y2 = m.y2,
                period = m.period or 3.2, open = m.open or 0.5, phase = m.phase or 0 }
        end
    end
    -- extra obstacles layered on the painted hole (PuttHard.lua); ex.drop retires some of the
    -- hole's own movers (by index) so a signature hazard can take their place
    local ex = tpl.extra
    local drop = {}
    for _, i in ipairs(ex and ex.drop or {}) do drop[i] = true end
    for i, m in ipairs(tpl.movers or {}) do if not drop[i] then addMover(m) end end
    if ex then
        for _, b in ipairs(ex.bumpers or {}) do
            h.bumpers[#h.bumpers + 1] = { x = X(b[1]), y = b[2], r = b[3], style = ex.style }
        end
        for _, m in ipairs(ex.movers or {}) do addMover(m) end
        -- ex.solid: things painted into the art that should be solid (e.g. a retired spinner's hub)
        for _, b in ipairs(ex.solid or {}) do
            h.bumpers[#h.bumpers + 1] = { x = X(b[1]), y = b[2], r = b[3], baked = true, kick = b[4] }
        end
        if ex.tip then h.tip = ex.tip end
    end
    -- ex.walls: low walls added to the painted hole, each a straight bar { x1, y1, x2, y2 } as thick
    -- as the hole's own curb. Solid on every side; drawn by the UI in the curb's colour.
    h.fences = {}
    h.curb = tpl.curb
    for _, f in ipairs(ex and ex.walls or {}) do
        local x1, y1, x2, y2 = X(f[1]), f[2], X(f[3]), f[4]
        local dx, dy = x2 - x1, y2 - y1
        local l = sqrt(dx * dx + dy * dy)
        if l > 1 then
            local T = P.FENCE_T
            local nx, ny = -dy / l * T, dx / l * T
            local a1, a2, b1, b2 = x1 + nx, y1 + ny, x2 + nx, y2 + ny
            local c1, c2, d1, d2 = x2 - nx, y2 - ny, x1 - nx, y1 - ny
            h.walls[#h.walls + 1] = { a1, a2, b1, b2, fence = true }
            h.walls[#h.walls + 1] = { b1, b2, c1, c2, fence = true }
            h.walls[#h.walls + 1] = { c1, c2, d1, d2, fence = true }
            h.walls[#h.walls + 1] = { d1, d2, a1, a2, fence = true }
            h.fences[#h.fences + 1] = { x1, y1, x2, y2 }
        end
    end
    -- ex.surface: the shape of the whole green (see Putt.SurfaceGrid). Each entry adds to its height:
    --   tilt   { k = "tilt", dx, dy, a }                the whole green falls away towards (dx, dy)
    --   grade  { k = "grade", x1, y1, x2, y2, h }       climbs by h from the first point to the second, level beyond both
    --   ridge  { k = "ridge", h, w, pts = { x, y, ... } } a rounded ridge (h > 0) or a trough (h < 0) along a line, w to each side
    --   mound  { k = "mound", x, y, r, h, flat }        a round rise (h > 0) or hollow (h < 0); flat is the level share of its radius
    --   funnel { k = "funnel", x, y, r, a }             a punchbowl whose slope holds all the way down to its middle
    -- Heights are in the units gravity works in: the pull on the ball is the downhill slope of the
    -- surface, and where that beats rolling resistance a ball cannot stop: it rolls on down.
    h.surface = nil
    if ex and ex.surface and ex.surface[1] then
        local list = {}
        for _, c in ipairs(ex.surface) do
            local q = { k = c.k, a = c.a, h = c.h, w = c.w, r = c.r, flat = c.flat, y = c.y, y1 = c.y1, y2 = c.y2, dy = c.dy }
            if c.x then q.x = X(c.x) end
            if c.x1 then q.x1, q.x2 = X(c.x1), X(c.x2) end
            if c.dx then q.dx = (mirror and -1 or 1) * c.dx end
            if c.pts then
                q.pts = {}
                for i = 1, #c.pts, 2 do q.pts[i], q.pts[i + 1] = X(c.pts[i]), c.pts[i + 1] end
            end
            list[#list + 1] = q
        end
        h.surface = list
        h.surf = Putt.SurfaceGrid(list, ex.surface, mirror)
    end
    -- signature hazards (mages, ghouls, war drums, whirlwinds, tide pools): see Putt:StepActors
    h.actors = {}
    h.figures = {}
    local function XP(list)
        local out = {}
        for i, p in ipairs(list or {}) do out[i] = { X(p[1]), p[2] } end
        return out
    end
    for _, a in ipairs(ex and ex.actors or {}) do
        local A = {}
        for k, v in pairs(a) do A[k] = v end
        if a.x then A.x = X(a.x) end
        if a.x1 then A.x1, A.x2 = X(a.x1), X(a.x2) end
        if a.targets then A.targets = XP(a.targets) end
        if a.fig then
            -- a drummer stands just behind his drum; everyone else stands on the spot
            local fx = A.x + ((a.kind == "drum") and ((A.x > W / 2) and 18 or -18) or 0)
            local fig = { name = a.fig, x = fx, y = A.y + ((a.kind == "drum") and -6 or 0), h = a.figH or 44, anim = "breathe",
                flip = (A.x > W / 2), phase = rng.next() * 6.28, actor = A }
            h.figures[#h.figures + 1] = fig
            A.figure = fig
        end
        h.actors[#h.actors + 1] = A
    end
    local fanList = {}
    if not (ex and ex.dropFans) then
        for _, f in ipairs(tpl.fans or {}) do fanList[#fanList + 1] = f end
    end
    for _, f in ipairs(ex and ex.fans or {}) do fanList[#fanList + 1] = f end
    for _, f in ipairs(fanList) do
        local fan = { x = X(f.x), y = f.y, dx = (mirror and -1 or 1) * f.dx, dy = f.dy, len = f.len, width = f.width,
            force = range(f.force or 140) * P.FAN * (ex and ex.fanScale or 1) }
        h.fans[#h.fans + 1] = fan
        -- a wall-mounted fan sits in the scenery, out of the way; a free-standing one is solid
        fan.wall = f.wall
        fan.period, fan.tide = f.period, f.tide
        if not f.wall then h.bumpers[#h.bumpers + 1] = { x = fan.x, y = fan.y, r = 13, fan = fan } end
    end
    -- scenery figures (no physics): mirrored with the hole, sprites flipped to match
    local acting = {}
    for _, f in ipairs(h.figures) do acting[f.name] = true end
    for _, f in ipairs(tpl.figures or {}) do
        -- a scenery copy of a figure that's now doing something would only confuse
        if not acting[f.name] then h.figures[#h.figures + 1] = { name = f.name, x = X(f.x), y = f.y, h = f.h, anim = f.anim,
            flip = (f.flip and true or false) ~= (mirror and true or false), phase = rng.next() * 6.28 } end
    end
    h.covers = {}
    for _, c in ipairs(tpl.covers or {}) do
        local x0, x1 = X(c[1]), X(c[3])
        h.covers[#h.covers + 1] = { min(x0, x1), c[2], max(x0, x1), c[4] }
    end
    IndexWalls(h)
    h.par = (ex and ex.par) or tpl.par or 3
    return h
end

function Putt.BuildHole(tpl, seed, forceMirror)
    local rng = NS.Game.RNG(seed * 7919 + 104729)
    for _ = 1, 4 do rng.next() end -- warm up: nearby seeds give very different holes
    local mirror = (not tpl.noMirror) and rng.next() < 0.5
    if forceMirror ~= nil then mirror = forceMirror end
    if tpl.grid then return BuildPainted(tpl, seed, mirror, rng) end
    local map = tpl.map
    if tpl.variant then map = tpl.variant(rng) or map end
    local h = {
        name = tpl.name, theme = tpl.theme, tip = tpl.tip, mirror = mirror,
        cells = {}, walls = {}, bumpers = {}, movers = {}, portals = {}, boosts = {}, fans = {}, ramps = {},
        zone = tpl.zone,
    }
    local C, COLS, ROWS = P.CELL, P.COLS, P.ROWS
    local portalA, portalB
    for row = 0, ROWS - 1 do
        local line = map[row + 1] or ""
        for col = 0, COLS - 1 do
            local srcCol = mirror and (COLS - 1 - col) or col
            local ch = line:sub(srcCol + 1, srcCol + 1)
            if ch == "" then ch = " " end
            if mirror then
                if ch == "<" then ch = ">" elseif ch == ">" then ch = "<"
                elseif ch == "L" then ch = "R" elseif ch == "R" then ch = "L" end
            end
            local t = TERRAIN[ch]
            local idx = row * COLS + col + 1
            if t then
                h.cells[idx] = ch
                local cx, cy = (col + 0.5) * C, (row + 0.5) * C
                if ch == "T" then h.tee = { x = cx, y = cy }
                elseif ch == "C" then h.cup = { x = cx, y = cy }
                elseif ch == "o" then h.bumpers[#h.bumpers + 1] = { x = cx, y = cy, r = 9 }
                elseif ch == "O" then h.bumpers[#h.bumpers + 1] = { x = cx, y = cy, r = 15 }
                elseif ch == "A" then portalA = { x = cx, y = cy }
                elseif ch == "B" then portalB = { x = cx, y = cy } end
            end
        end
    end
    assert(h.tee and h.cup, "hole needs a tee and a cup: " .. tostring(tpl.name))
    if portalA and portalB then
        local pt = { ax = portalA.x, ay = portalA.y, bx = portalB.x, by = portalB.y, r = 13 }
        -- optional fixed exit direction: the portal keeps your speed but launches you its own way
        if tpl.portalDir then pt.dx = (mirror and -1 or 1) * tpl.portalDir[1]; pt.dy = tpl.portalDir[2] end
        h.portals[1] = pt
    end

    -- boundary walls between playable cells and void, merged into long runs
    local function playable(col, row)
        if col < 0 or row < 0 or col >= COLS or row >= ROWS then return false end
        return h.cells[row * COLS + col + 1] ~= nil
    end
    -- horizontal edges (on grid line y=row, between row-1 and row)
    for row = 0, ROWS do
        local runStart
        for col = 0, COLS do
            local a, b = playable(col, row - 1), playable(col, row)
            local edge = col < COLS and (a ~= b)
            if edge and not runStart then runStart = col
            elseif not edge and runStart then
                h.walls[#h.walls + 1] = { runStart * C, row * C, col * C, row * C }
                runStart = nil
            end
        end
    end
    for col = 0, COLS do
        local runStart
        for row = 0, ROWS do
            local a, b = playable(col - 1, row), playable(col, row)
            local edge = row < ROWS and (a ~= b)
            if edge and not runStart then runStart = row
            elseif not edge and runStart then
                h.walls[#h.walls + 1] = { col * C, runStart * C, col * C, row * C }
                runStart = nil
            end
        end
    end
    h.boundaryWalls = #h.walls
    -- interior walls (grid units)
    for _, w in ipairs(tpl.walls or {}) do
        local x1, y1 = rotatePoint(w[1] * C, w[2] * C, mirror)
        local x2, y2 = rotatePoint(w[3] * C, w[4] * C, mirror)
        h.walls[#h.walls + 1] = { x1, y1, x2, y2, interior = true }
    end
    -- corner bevels: a short 45-degree rail across every inside corner so a ball
    -- can never wedge into a square pocket (it kicks back out into open play)
    if P.BEVEL > 0 then
        local L = P.BEVEL
        local function bevel(X, Y, sx, sy)
            h.walls[#h.walls + 1] = { X + sx * L, Y, X, Y + sy * L, bevel = true }
        end
        -- boundary corners: grid points with exactly one playable cell around them
        for gy = 0, ROWS do
            for gx = 0, COLS do
                local q = { { -1, -1 }, { 0, -1 }, { -1, 0 }, { 0, 0 } }
                local n, sx, sy = 0, 0, 0
                for _, d in ipairs(q) do
                    if playable(gx + d[1], gy + d[2]) then
                        n = n + 1; sx = d[1] == 0 and 1 or -1; sy = d[2] == 0 and 1 or -1
                    end
                end
                if n == 1 then bevel(gx * C, gy * C, sx, sy) end
            end
        end
        -- where an interior wall meets a rail at a right angle, bevel both sides of the joint
        local function onBoundary(x, y, horiz)
            for i = 1, h.boundaryWalls do
                local w = h.walls[i]
                local wh = abs(w[2] - w[4]) < 0.5
                if wh ~= horiz then
                    if wh and abs(w[2] - y) < 0.5 and x >= min(w[1], w[3]) - 0.5 and x <= max(w[1], w[3]) + 0.5 then return true end
                    if not wh and abs(w[1] - x) < 0.5 and y >= min(w[2], w[4]) - 0.5 and y <= max(w[2], w[4]) + 0.5 then return true end
                end
            end
        end
        for i = h.boundaryWalls + 1, #h.walls do
            local w = h.walls[i]
            if w.interior then
                local horiz = abs(w[2] - w[4]) < 0.5
                for e = 0, 1 do
                    local X, Y = w[1 + e * 2], w[2 + e * 2]
                    local OX, OY = w[3 - e * 2], w[4 - e * 2]
                    if onBoundary(X, Y, horiz) then
                        if horiz then
                            local sx = OX > X and 1 or -1
                            for _, sy in ipairs({ -1, 1 }) do
                                if playable(floor((X + sx * 1) / C), floor((Y + sy * 1) / C)) then bevel(X, Y, sx, sy) end
                            end
                        else
                            local sy = OY > Y and 1 or -1
                            for _, sx in ipairs({ -1, 1 }) do
                                if playable(floor((X + sx * 1) / C), floor((Y + sy * 1) / C)) then bevel(X, Y, sx, sy) end
                            end
                        end
                    end
                end
            end
        end
    end
    if tpl.setup then tpl.setup(h, rng, mirror) end
    if mirror then
        for _, f in ipairs(h.fans) do if f.mirrorable then f.x, f.dx = P.W - f.x, -f.dx end end
        for _, m in ipairs(h.movers) do
            if m.kind == "patrol" and m.mirrorable then m.x1, m.x2 = P.W - m.x1, P.W - m.x2 end
        end
    end
    for _, f in ipairs(h.fans) do
        f.force = (f.force or 140) * P.FAN
        h.bumpers[#h.bumpers + 1] = { x = f.x, y = f.y, r = 13, fan = f }
    end
    h.actors, h.figures = h.actors or {}, h.figures or {}
    -- jitter bumpers a touch so no two days look identical
    if tpl.jitter then
        for _, b in ipairs(h.bumpers) do
            b.x = b.x + (rng.next() - 0.5) * tpl.jitter
            b.y = b.y + (rng.next() - 0.5) * tpl.jitter
        end
    end
    h.par = tpl.par or 3
    return h
end

function Putt.Cell(h, x, y)
    if h.grid then
        local res = h.res
        local col, row = floor(x / res), floor(y / res)
        if col < 0 or row < 0 or col >= h.gridCols or row >= h.gridRows then return nil end
        local ch = h.grid[row + 1]:sub(col + 1, col + 1)
        if ch == " " or ch == "" then return nil end
        return ch
    end
    local col, row = floor(x / P.CELL), floor(y / P.CELL)
    if col < 0 or row < 0 or col >= P.COLS or row >= P.ROWS then return nil end
    return h.cells[row * P.COLS + col + 1]
end

---------------------------------------------------------------------------
-- Courses
---------------------------------------------------------------------------
-- day = integer like 20261105; kind = "daily" | "quick"
Putt.COURSE = "human"
Putt.COURSE_ORDER = { "human", "dwarf", "gnome", "nelf", "orc", "troll", "undead", "mulgore" }
Putt.TOUR = "tour" -- the Grand Tour: a 9-hole sampler from every course
Putt.TOUR_HOLES = 9
-- the daily course rotates through the courses, the same for everyone that day
function Putt.DailyCourseKey(dayNum)
    local list = {}
    for _, k in ipairs(Putt.COURSE_ORDER) do if NS.PuttCourses and NS.PuttCourses[k] then list[#list + 1] = k end end
    if #list == 0 then return Putt.COURSE end
    return list[(math.floor(tonumber(dayNum) or 0) % #list) + 1]
end
function Putt.CourseInfo(key, seed)
    if key == Putt.TOUR then
        -- deal holes round-robin from every course (each course's holes shuffled by the seed),
        -- then play them in course order so the tour travels across Azeroth
        local rng = NS.Game.RNG((seed or 1) * 71 + 5)
        local per, keys = {}, {}
        for _, k in ipairs(Putt.COURSE_ORDER) do
            local c = NS.PuttCourses and NS.PuttCourses[k]
            if c and #c.holes > 0 then
                local list = {}
                for i = 1, #c.holes do list[i] = i end
                for i = #list, 2, -1 do local j = rng.int(1, i); list[i], list[j] = list[j], list[i] end
                per[k] = list; keys[#keys + 1] = k
            end
        end
        local take, total, any = {}, 0, true
        while total < Putt.TOUR_HOLES and any do
            any = false
            for _, k in ipairs(keys) do
                if total < Putt.TOUR_HOLES and #per[k] > 0 then
                    take[k] = take[k] or {}
                    take[k][#take[k] + 1] = table.remove(per[k], 1)
                    total = total + 1; any = true
                end
            end
        end
        local holes = {}
        for _, k in ipairs(keys) do
            local t = take[k] or {}
            table.sort(t)
            for _, i in ipairs(t) do holes[#holes + 1] = NS.PuttCourses[k].holes[i] end
        end
        return { key = Putt.TOUR, name = "Grand Tour", holes = holes }
    end
    return NS.PuttCourses and NS.PuttCourses[key]
end
function Putt.MakeCourse(kind, seed, courseKey)
    if not courseKey and kind == "daily" then courseKey = Putt.DailyCourseKey(seed) end
    local course = Putt.CourseInfo(courseKey or Putt.COURSE, seed)
    if course then
        -- a real course: its holes in order; each day (or quick round) mirrors some of them
        local rng = NS.Game.RNG(seed * 131 + (kind == "daily" and 7 or 3))
        for _ = 1, 4 do rng.next() end
        local holes, par = {}, 0
        for i, tpl in ipairs(course.holes) do
            holes[i] = Putt.BuildHole(tpl, seed * 977 + i * 31, rng.next() < 0.5)
            par = par + holes[i].par
        end
        return { kind = kind, seed = seed, holes = holes, par = par, key = course.key, name = course.name }
    end
    local tpls = NS.PuttHoles
    local rng = NS.Game.RNG(seed * 131 + (kind == "daily" and 7 or 3))
    local order = {}
    for i = 1, #tpls do order[i] = i end
    for i = #order, 2, -1 do
        local j = rng.int(1, i)
        order[i], order[j] = order[j], order[i]
    end
    local holes = {}
    for i = 1, P.HOLES do
        local tpl = tpls[order[i]]
        holes[i] = Putt.BuildHole(tpl, seed * 977 + i * 31 + order[i])
    end
    local par = 0
    for _, h in ipairs(holes) do par = par + h.par end
    return { kind = kind, seed = seed, holes = holes, par = par }
end

---------------------------------------------------------------------------
-- Game object
---------------------------------------------------------------------------
function Putt.New(handlers)
    local g = setmetatable({}, { __index = Putt })
    g.h = handlers or {}
    g.state = "idle"
    return g
end

function Putt:Emit(ev, ...)
    local f = self.h[ev]
    if f then f(...) end
end

function Putt:Start(course, resume)
    self.course = course
    self.rng = NS.Game.RNG(course.seed * 17 + (time and time() or 0) % 100000)
    self.index = 0
    self.card = {}
    self.elapsed = 0
    self.started = false
    self.time = 0
    if resume and resume.index and resume.index >= 1 then
        for i = 1, resume.index - 1 do self.card[i] = resume.card[i] end
        self.index = resume.index - 1
        self.elapsed = resume.elapsed or 0
        self.started = resume.index > 1 or (resume.strokes or 0) > 0
    end
    if resume then self.resumeStrokes = resume.strokes end
    self:NextHole()
end

-- snapshot at the start of the current hole (for resuming after a logout)
function Putt:Snapshot()
    if not self.course or self.state == "done" then return nil end
    -- strokes on the current hole carry over, so reloading never wipes a bad hole
    return { kind = self.course.kind, seed = self.course.seed, key = self.course.key, index = self.index,
             card = self.card, elapsed = self.elapsed, strokes = self.strokes }
end

function Putt:NextHole()
    self.index = self.index + 1
    local hole = self.course.holes[self.index]
    if not hole then return self:Finish() end
    self.hole = hole
    self.strokes = self.resumeStrokes or 0
    self.blessed = nil
    self.resumeStrokes = nil
    self.ball = { x = hole.tee.x, y = hole.tee.y, vx = 0, vy = 0 }
    self.rest = { x = hole.tee.x, y = hole.tee.y }
    for _, m in ipairs(hole.movers) do m.t = 0 end
    hole.clock = 0
    for _, c in ipairs(hole.coins or NONE) do c.got = nil end
    self.coinsGot = 0
    self.shots = {}
    self.fanPin = nil
    self.grace = self.index > 1 and 1.2 or 0 -- a moment to read each new hole
    self.state = "aim"
    self:Emit("hole", self.index, hole)
end

-- How far a ball launched at speed v rolls on flat ground (same friction as Step),
-- tabulated once, then inverted so the pull sets the roll distance rather than the speed.
local ROLL = {}
do
    local h = P.STEP
    for i = 0, 90 do
        local v, d = i * 10, 0
        while v > P.STOP do
            local nv = v - Putt.Friction(v, P.DECEL, P.DRAG, true) * h
            if nv < 0 then nv = 0 end
            d = d + (v + nv) * 0.5 * h
            v = nv
        end
        ROLL[i] = d
    end
end
function Putt.RollDistance(v)
    local f = max(0, min(90, v / 10))
    local i = floor(f)
    if i >= 90 then return ROLL[90] end
    return ROLL[i] + (ROLL[i + 1] - ROLL[i]) * (f - i)
end
function Putt.SpeedFor(power)
    local want = ROLL[90] * (max(0, min(1, power)) ^ P.POWER_CURVE)
    for i = 1, 90 do
        if ROLL[i] >= want then
            local a, b = ROLL[i - 1], ROLL[i]
            return ((i - 1) + (b > a and (want - a) / (b - a) or 0)) * 10
        end
    end
    return P.MAX_SPEED
end

function Putt:Shoot(angle, power)
    if self.state ~= "aim" then return false end
    power = max(0.02, min(1, power or 0))
    -- power vs accuracy: slamming it adds a little random wobble
    if power > P.WOBBLE_FROM and self.rng then
        local k = (power - P.WOBBLE_FROM) / (1 - P.WOBBLE_FROM)
        angle = angle + (self.rng.next() * 2 - 1) * P.WOBBLE * k
    end
    -- distance tracks the pull evenly: short putts keep fine control, full power reaches any cup
    local sp = Putt.SpeedFor(power)
    local used = self.blessed
    if used then sp = sp * 1.35; self.blessed = nil; self:Emit("blessUsed") end
    local b = self.ball
    b.usedBless = used
    b.vx, b.vy = cos(angle) * sp, sin(angle) * sp
    b.age, b.slow, b.portalLock, b.travel, b.tunnel, b.knocked = 0, 0, nil, 0, nil, nil
    b.rampShort = nil
    b.air, b.z, b.twist, b.whirled, b.lift = nil, nil, nil, nil, nil
    b.twistCd = nil   -- every putt starts clean, so a replay of the shot on another client matches
    self.fanPin = nil
    b.still, b.windy, b.boosted = 0, false, false
    b.hexed, b.hexT = nil, nil
    b.carry, b.carryLock = nil, nil
    self.strokes = self.strokes + 1
    self.started = true
    self.state = "roll"
    self.acc = 0
    self:ArmActors()
    self:Emit("shot", self.strokes, power)
    return true
end

-- per-frame update (dt real seconds). Moving obstacles always animate.
function Putt:Update(dt)
    if self.state == "idle" or self.state == "done" then return end
    self.time = self.time + dt
    if (self.grace or 0) > 0 then
        self.grace = self.grace - dt
    elseif self.started and (self.state == "aim" or self.state == "roll") then
        self.elapsed = self.elapsed + dt
    end
    if self.state == "roll" then
        -- obstacles move in the same small steps as the ball, so nothing skips through it
        self.acc = self.acc + dt
        local steps = 0
        while self.acc >= P.STEP and steps < P.MAX_STEPS and self.state == "roll" do
            self.acc = self.acc - P.STEP
            steps = steps + 1
            self:MoveObstacles(P.STEP)
            self:Step(P.STEP)
        end
        if steps >= P.MAX_STEPS then self.acc = 0 end
        if self.state ~= "roll" then self.acc = 0 end
    elseif self.state == "aim" and self.ball and #self.hole.movers > 0 then
        -- a guard, gnoll or windmill sail walking into a resting ball knocks it away
        local b, r = self.ball, P.BALL_R
        local n = max(1, math.ceil(dt / P.STEP))
        local h = dt / n
        for _ = 1, n do
            self:MoveObstacles(h)
            b.vx, b.vy = 0, 0
            local hit = self:HitMovers(b, r)
            if hit then
                local m = type(hit) == "table" and hit
                if m and m.kind == "patrol" and m.x then
                    -- a walker bats the ball aside, out of its own path (never herds it into a rail)
                    local mvx, mvy = m.vx or 0, m.vy or 0
                    local ms = sqrt(mvx * mvx + mvy * mvy)
                    local nx, ny = b.x - m.x, b.y - m.y
                    local nd = sqrt(nx * nx + ny * ny)
                    if nd < 1e-3 then nx, ny, nd = 0, -1, 1 end
                    nx, ny = nx / nd, ny / nd
                    local px, py
                    if ms > 1e-3 then px, py = -mvy / ms, mvx / ms else px, py = -ny, nx end
                    if px * nx + py * ny < 0 then px, py = -px, -py end
                    if abs(px * nx + py * ny) < 0.05 then px, py = -px, -py end
                    local dx, dy = nx * 0.6 + px, ny * 0.6 + py
                    local dl = sqrt(dx * dx + dy * dy)
                    local k = max(170, ms * 1.6)
                    b.vx, b.vy = dx / dl * k, dy / dl * k
                else
                    local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
                    if sp < 120 then
                        -- a firm knock even from a slow sail
                        local dx, dy = b.x - self.rest.x, b.y - self.rest.y
                        local d = sqrt(dx * dx + dy * dy)
                        if sp > 1e-3 then b.vx, b.vy = b.vx / sp * 120, b.vy / sp * 120
                        elseif d > 1e-3 then b.vx, b.vy = dx / d * 120, dy / d * 120 end
                    end
                end
                b.age, b.slow, b.portalLock, b.travel, b.tunnel, b.still = 0, 0, nil, 0, nil, 0
                b.knocked = true
                self.acc = 0
                self.state = "roll"
                self:Emit("knocked")
                break
            end
        end
        if self.state == "aim" then self:RestActors(dt) end
        if self.state == "aim" then self:RestFans() end
    elseif self.state == "aim" and self.ball then
        self:MoveObstacles(dt)
        self:RestActors(dt)
        if self.state == "aim" then self:RestFans() end
    elseif self.state == "sunk" then
        self:MoveObstacles(dt)
        self.sunkT = self.sunkT - dt
        if self.sunkT <= 0 then self:NextHole() end
    else
        self:MoveObstacles(dt)
    end
end

function Putt:MoveObstacles(dt)
    local hole = self.hole
    hole.clock = (hole.clock or 0) + dt
    for _, m in ipairs(hole.movers) do
        m.t = (m.t or 0) + dt
        if m.kind == "spinner" then
            m.a = (m.a0 or 0) + m.spd * m.t
            m.omega = m.spd
        elseif m.kind == "patrol" then
            -- a guard walking a beat between two points (eases at each end)
            local ph = (m.phase or 0) + m.spd * m.t
            local k = (1 - cos(ph)) / 2
            m.x, m.y = m.x1 + (m.x2 - m.x1) * k, m.y1 + (m.y2 - m.y1) * k
            local dk = sin(ph) * m.spd / 2
            m.vx, m.vy = (m.x2 - m.x1) * dk, (m.y2 - m.y1) * dk
        elseif m.kind == "tram" then
            local ph = m.phase + m.spd * m.t
            local nx = m.x1 + (m.x2 - m.x1) * (1 - cos(ph)) / 2
            local dxm = nx - (m.x or nx)
            -- whatever is standing on the car rides along with it
            local bl = self.ball
            if bl and not bl.air and not bl.tunnel and abs(bl.x - (m.x or nx)) <= m.hw and abs(bl.y - m.y) <= m.hh then
                bl.x = bl.x + dxm
                if self.state == "aim" and self.rest then self.rest.x = bl.x end
            end
            m.x = nx
        elseif m.kind == "slider" then
            local ph = m.phase + m.spd * m.t
            local off = sin(ph) * m.amp
            m.ox, m.oy = m.dx * off, m.dy * off
            local v = cos(ph) * m.amp * m.spd
            m.vx, m.vy = m.dx * v, m.dy * v
        elseif m.kind == "orbit" then
            local a = m.a0 + m.spd * m.t
            for k = 1, m.n do
                local ak = a + (k - 1) * 2 * pi / m.n
                local p = m.pts[k]
                if not p then p = {}; m.pts[k] = p end
                p.x, p.y = m.cx + cos(ak) * m.rad, m.cy + sin(ak) * m.rad
                p.vx, p.vy = -sin(ak) * m.rad * m.spd, cos(ak) * m.rad * m.spd
            end
        elseif m.kind == "gate" then
            -- 0 = open (bar tucked in at x1,y1) .. 1 = shut (bar reaches x2,y2); slides in 0.35s
            local u = ((m.t + m.phase) % m.period) / m.period
            local sl = 0.35 / m.period
            local c
            if u < m.open then c = 0
            elseif u < m.open + sl then c = (u - m.open) / sl
            elseif u < 1 - sl then c = 1
            else c = (1 - u) / sl end
            m.closed = c
            m.warn = (u > m.open - 0.6 / m.period and u < m.open) -- about to shut: the bar rattles
        end
    end
end

---------------------------------------------------------------------------
-- Signature hazards. Everything runs off the hole clock, so a shot always plays out
-- the same way for the same timing (fair, learnable, and the test bots can plan with it).
---------------------------------------------------------------------------
local function cycle(a, clock)
    local t = clock + (a.phase or 0)
    local k = floor(t / a.period)
    return k, t - k * a.period
end
Putt.Cycle = cycle

-- tide pool: how full it is now (0 dry .. 1 full)
function Putt.PoolFill(a, clock)
    local _, u = cycle(a, clock)
    u = u / a.period
    if u < 0.18 then return u / 0.18 end
    if u < 0.55 then return 1 end
    if u < 0.72 then return 1 - (u - 0.55) / 0.17 end
    return 0
end

-- ghoul's slime: where the current blob is headed and how it's doing
-- returns target x, y, state ("fly" with progress 0..1, or "goo" with radius), cycle index
local LOB = 0.85
function Putt.Goo(a, clock)
    local k, u = cycle(a, clock)
    local tg = a.targets[(k % #a.targets) + 1]
    if u < LOB then return tg[1], tg[2], "fly", u / LOB, k end
    local life = a.period - LOB
    local age = u - LOB
    local r = a.r or 18
    if age < 0.12 then r = r * (0.5 + 0.5 * age / 0.12) end
    if age > life - 0.3 then r = r * max(0, (life - age) / 0.3) end
    return tg[1], tg[2], "goo", r, k
end

-- war drum: radius of the current shockwave ring (nil between beats)
local RING_T = 0.6
function Putt.DrumRing(a, clock)
    local k, u = cycle(a, clock)
    if u < RING_T then return u / RING_T * a.reach, k end
    return nil, k
end

function Putt.WhirlPos(a, clock)
    local ph = (a.phase or 0) + a.spd * clock
    local k = (1 - cos(ph)) / 2
    return a.x1 + (a.x2 - a.x1) * k, a.y1 + (a.y2 - a.y1) * k
end

-- called on every putt: mages reset, old fireballs fizzle, waves you start inside don't hit you
function Putt:ArmActors()
    local hole, b = self.hole, self.ball
    self.shots = {}
    b.drum, b.goo, b.blasted, b.washed = {}, nil, {}, nil
    local clock = hole.clock or 0
    for i, a in ipairs(hole.actors or {}) do
        if a.kind == "mage" then
            a.cool, a.wind = a.first or 0.5, nil
        elseif a.kind == "drum" then
            local R, k = Putt.DrumRing(a, clock)
            local d = sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
            if R and d <= R then b.drum[i] = k end
        end
    end
end

-- per physics step while rolling. Returns decel, drag overrides (goo), or "stop" if the ball was penalised
function Putt:StepActors(b, h)
    local hole = self.hole
    local clock = hole.clock or 0
    local decel, drag
    local inGoo = false
    for i, a in ipairs(hole.actors) do
        local kind = a.kind
        if kind == "mage" then
            -- a mage lobs a fireball at a ball that rolls too close
            local dx, dy = b.x - a.x, b.y - (a.y - 18)
            local d = sqrt(dx * dx + dy * dy)
            if a.wind then
                a.wind = a.wind - h
                if a.wind <= 0 then
                    a.wind = nil
                    local sx, sy = a.x, a.y - 18
                    local ex, ey = b.x - sx, b.y - sy
                    local el = max(1, sqrt(ex * ex + ey * ey))
                    local sp = a.speed or 300
                    self.shots[#self.shots + 1] = { x = sx, y = sy, vx = ex / el * sp, vy = ey / el * sp,
                        life = (a.range + 80) / sp, from = a }
                    a.cool = a.cd or 2.0
                    self:Emit("cast", a)
                end
            else
                a.cool = (a.cool or 0) - h
                if a.cool <= 0 and d < a.range then
                    a.wind = a.windup or 0.45
                    self:Emit("windup", a)
                end
            end
        elseif kind == "ghoul" then
            local gx, gy, st, r = Putt.Goo(a, clock)
            if st == "goo" and r > 4 then
                local d2 = (b.x - gx) ^ 2 + (b.y - gy) ^ 2
                if d2 < r * r then
                    inGoo = true
                    decel, drag = 720, 2.6
                    if not b.goo then b.goo = true; self:Emit("goo", gx, gy) end
                end
            end
        elseif kind == "drum" then
            local R, k = Putt.DrumRing(a, clock)
            if R and b.drum[i] ~= k then
                local dx, dy = b.x - a.x, b.y - a.y
                local d = sqrt(dx * dx + dy * dy)
                if d <= R and d < a.reach and d > 1 then
                    b.drum[i] = k
                    local push = a.push * (1 - 0.5 * d / a.reach)
                    b.vx, b.vy = b.vx + dx / d * push, b.vy + dy / d * push
                    self:Emit("drumhit", a, b.x, b.y)
                end
            end
        elseif kind == "whirl" then
            local wx, wy = Putt.WhirlPos(a, clock)
            local dx, dy = b.x - wx, b.y - wy
            local d = sqrt(dx * dx + dy * dy)
            if (b.twistCd or 0) <= 0 then
                local core = a.r * 0.75
                if d < core then
                    -- caught: the funnel takes the ball up and throws it (see Putt:Step)
                    self:Twist(a, wx, wy)
                    return nil, nil, "stop"
                elseif d < a.r * 1.6 and d > 1 then
                    -- anything passing close is dragged toward the funnel
                    local k = 1 - (d - core) / (a.r * 1.6 - core)
                    local pull = (a.pull or 560) * k
                    b.vx = b.vx - dx / d * pull * h
                    b.vy = b.vy - dy / d * pull * h
                    b.windy = true
                    if not b.whirled then b.whirled = true; self:Emit("whirl", a) end
                end
            end
        elseif kind == "pool" then
            local f = Putt.PoolFill(a, clock)
            local r = a.r * f
            if b.washed == i then
                -- floated out of this pool a moment ago: it only counts again once the ball is clear of it
                if (b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 > (a.r + 4) ^ 2 then b.washed = nil end
            elseif r > 9 and (b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 < (r - 3) ^ 2 then
                self:Hazard("Swept away!")
                return nil, nil, "stop"
            end
        end
    end
    if not inGoo then b.goo = nil end
    -- fireballs
    local shots = self.shots
    for j = #shots, 1, -1 do
        local s = shots[j]
        s.x, s.y = s.x + s.vx * h, s.y + s.vy * h
        s.life = s.life - h
        local dx, dy = b.x - s.x, b.y - s.y
        if dx * dx + dy * dy < (P.BALL_R + 7) ^ 2 then
            local sp = sqrt(s.vx * s.vx + s.vy * s.vy)
            local kick = s.from.kick or 230
            b.vx, b.vy = b.vx + s.vx / sp * kick, b.vy + s.vy / sp * kick
            table.remove(shots, j)
            self:Emit("fireball", s.x, s.y)
        elseif s.life <= 0 then
            table.remove(shots, j)
            self:Emit("fizzle", s.x, s.y)
        end
    end
    return decel, drag
end

-- a tornado has the ball: it spins up the funnel, then gets thrown
function Putt:Twist(a, wx, wy)
    local b = self.ball
    local dx, dy = b.x - wx, b.y - wy
    b.twist = { a = a, t = 0, dur = a.hold or 0.95, ang = math.atan2(dy, dx), spin = a.twirl or 15,
                rad = max(7, sqrt(dx * dx + dy * dy)) }
    b.vx, b.vy = 0, 0
    b.hexT = nil
    b.lift = 40   -- how far up the screen a unit of height carries the ball (the UI reads this): right up the funnel
    self:Emit("twister", a)
end

-- Hazards don't wait for you to putt. A ball left sitting in one gets the same treatment as a rolling one,
-- with no stroke counted: the tornado takes it, a drum beat or a rising tide shoves it, a mage blasts it.
function Putt:RestActors(dt)
    local hole, b = self.hole, self.ball
    local actors = hole.actors
    if not actors or not actors[1] or (self.grace or 0) > 0 then return end
    -- a ball still on the tee is left alone: the hole hasn't started
    if self.rest.x == hole.tee.x and self.rest.y == hole.tee.y and b.x == hole.tee.x and b.y == hole.tee.y then return end
    if (b.twistCd or 0) > 0 then b.twistCd = b.twistCd - dt end
    local clock = hole.clock or 0
    local rest = self.rest
    local moved
    for i, a in ipairs(actors) do
        local kind = a.kind
        if kind == "whirl" then
            if (b.twistCd or 0) <= 0 then
                local wx, wy = Putt.WhirlPos(a, clock)
                if (b.x - wx) ^ 2 + (b.y - wy) ^ 2 < (a.r * 0.75) ^ 2 then
                    self:Twist(a, wx, wy)
                    moved = true
                end
            end
        elseif kind == "drum" then
            local R, k = Putt.DrumRing(a, clock)
            b.drum = b.drum or {}
            if R and b.drum[i] ~= k then
                local dx, dy = b.x - a.x, b.y - a.y
                local d = sqrt(dx * dx + dy * dy)
                if d <= R and d < a.reach and d > 1 then
                    b.drum[i] = k
                    local push = a.push * (1 - 0.5 * d / a.reach)
                    b.vx, b.vy = dx / d * push, dy / d * push
                    self:Emit("drumhit", a, b.x, b.y)
                    moved = true
                end
            end
        elseif kind == "pool" then
            local r = a.r * Putt.PoolFill(a, clock)
            local dx, dy = b.x - a.x, b.y - a.y
            local d = sqrt(dx * dx + dy * dy)
            if r > 9 and d < r - 3 then
                -- the rising water floats the ball out over the rim
                if d < 1 then dx, dy, d = 0, 1, 1 end
                b.vx, b.vy = dx / d * 170, dy / d * 170
                b.washed = i
                self:Emit("washed", a)
                moved = true
            end
        elseif kind == "mage" then
            -- one blast for each place the ball comes to rest inside his range
            local dx, dy = b.x - a.x, b.y - (a.y - 18)
            local d = sqrt(dx * dx + dy * dy)
            rest.mage = rest.mage or {}
            b.blasted = b.blasted or {}
            if d >= a.range or rest.mage[i] or b.blasted[i] then
                a.rwind = nil
            else
                if not rest.mageT then rest.mageT = 1.1; rest.mageI = i; self:Emit("windup", a)
                elseif rest.mageI == i then
                    rest.mageT = rest.mageT - dt
                    a.rwind = max(0, rest.mageT / 1.1)   -- how much of his wind-up is left (the UI lights his staff)
                    if rest.mageT <= 0 then
                        a.rwind = nil
                        rest.mage[i], rest.mageT, rest.mageI = true, nil, nil
                        b.blasted[i] = true   -- once per putt: he doesn't juggle a ball you can't get away from
                        local kick = a.kick or 230
                        if d < 1 then dx, dy, d = 0, 1, 1 end
                        b.vx, b.vy = dx / d * kick, dy / d * kick
                        self:Emit("cast", a)
                        self:Emit("fireball", b.x, b.y)
                        moved = true
                    end
                end
            end
        end
        if moved then break end
    end
    if moved then
        b.age, b.slow, b.portalLock, b.travel, b.tunnel, b.still = 0, 0, nil, 0, nil, 0
        b.knocked = true
        self.acc = 0
        self.state = "roll"
        self:Emit("knocked")
    end
end

-- A ball left sitting in a fan's stream is blown off down it, the same as a rolling one, with no stroke
-- counted. Only where the wind beats the ground's grip, and never twice from the same spot: a ball the
-- fan has already pinned against a rail stays put until you putt it.
function Putt:RestFans()
    local hole, b = self.hole, self.ball
    if not hole.fans[1] or (self.grace or 0) > 0 then return end
    if self.rest.x == hole.tee.x and self.rest.y == hole.tee.y and b.x == hole.tee.x and b.y == hole.tee.y then return end
    local t = TERRAIN[Putt.Cell(hole, b.x, b.y) or " "] or TERRAIN["."]
    local grip = (t.decel or (P.DECEL * P.HOLD)) * 1.15
    local pin = self.fanPin
    for i, f in ipairs(hole.fans) do
        if f.period then f.off = ((hole.clock or 0) % f.period) > f.period * 0.45 end
        if not f.off then
            local rx, ry = b.x - f.x, b.y - f.y
            local along = rx * f.dx + ry * f.dy
            local perp = abs(rx * f.dy - ry * f.dx)
            if along > 0 and along < f.len and perp < f.width / 2 then
                local k = f.force * (1 - 0.5 * along / f.len) * (1 - perp / (f.width / 2) * 0.3)
                local pinned = pin and pin.i == i and (b.x - pin.x) ^ 2 + (b.y - pin.y) ^ 2 < 9
                if k > grip and not pinned then
                    self.fanPin = { i = i, x = b.x, y = b.y }
                    b.vx, b.vy = f.dx * 30, f.dy * 30
                    b.age, b.slow, b.portalLock, b.travel, b.tunnel, b.still = 0, 0, nil, 0, nil, 0
                    b.windy = true
                    b.knocked = true
                    self.acc = 0
                    self.state = "roll"
                    self:Emit("gust", f)
                    self:Emit("knocked")
                    return true
                end
            end
        end
    end
end

-- collide ball with a segment (x1,y1)-(x2,y2) whose surface moves with (svx, svy)
local function hitSegment(b, x1, y1, x2, y2, e, svx, svy, r)
    local ex, ey = x2 - x1, y2 - y1
    local len2 = ex * ex + ey * ey
    local t = len2 > 0 and ((b.x - x1) * ex + (b.y - y1) * ey) / len2 or 0
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx, cy = x1 + ex * t, y1 + ey * t
    local dx, dy = b.x - cx, b.y - cy
    local d2 = dx * dx + dy * dy
    if d2 >= r * r then return false end
    local d = sqrt(d2)
    local nx, ny
    if d < 1e-5 then
        local l = sqrt(len2)
        nx, ny = -ey / l, ex / l
        d = 0
    else
        nx, ny = dx / d, dy / d
    end
    b.x, b.y = cx + nx * r, cy + ny * r
    local rvx, rvy = b.vx - (svx or 0), b.vy - (svy or 0)
    local vn = rvx * nx + rvy * ny
    if vn < 0 then
        b.vx = b.vx - (1 + e) * vn * nx
        b.vy = b.vy - (1 + e) * vn * ny
        return -vn
    end
    return 0
end
Putt.HitSegment = hitSegment

-- collide the ball with every moving obstacle; returns true if anything touched it
function Putt:HitMovers(b, r)
    local hole = self.hole
    local touched = false
    self.lastMover = nil
    local vx0, vy0, x0, y0 = b.vx, b.vy, b.x, b.y
    for _, m in ipairs(hole.movers) do
        if m.kind == "spinner" then
            local hubR = m.hub or 7
            local dx, dy = b.x - m.cx, b.y - m.cy
            local d2 = dx * dx + dy * dy
            local reach = m.len + r + 2
            if d2 < reach * reach then
                for k = 0, m.arms - 1 do
                    local a = m.a + k * 2 * pi / m.arms
                    local ex, ey = m.cx + cos(a) * m.len, m.cy + sin(a) * m.len
                    -- surface velocity at the closest point (omega x r)
                    local cx, cy = m.cx + cos(a) * min(m.len, sqrt(d2)), m.cy + sin(a) * min(m.len, sqrt(d2))
                    local svx, svy = -(cy - m.cy) * m.omega, (cx - m.cx) * m.omega
                    local imp = hitSegment(b, m.cx, m.cy, ex, ey, 0.6, svx, svy, r + 2)
                    if imp and imp > 60 then self:Emit("wall", imp) end
                end
                local hd = sqrt(dx * dx + dy * dy)
                if hd < hubR + r and hd > 1e-5 then
                    b.x, b.y = m.cx + dx / hd * (hubR + r), m.cy + dy / hd * (hubR + r)
                end
            end
        elseif m.kind == "patrol" and m.x then
            local dx, dy = b.x - m.x, b.y - m.y
            local rr = m.r + r
            local d2 = dx * dx + dy * dy
            if d2 < rr * rr then
                local d = sqrt(d2)
                if d < 1e-5 then dx, dy, d = 0, -1, 1 end
                local nx, ny = dx / d, dy / d
                b.x, b.y = m.x + nx * rr, m.y + ny * rr
                local vn = (b.vx - m.vx) * nx + (b.vy - m.vy) * ny
                self.lastMover = m
                if m.carry and (b.carryLock or 0) <= 0 and not b.carry then
                    -- it picks the ball up and walks off with it for a moment
                    b.carry = { m = m, t = m.carry }
                    b.vx, b.vy = 0, 0
                    self:Emit("grab", m)
                elseif vn < 0 then
                    b.vx, b.vy = b.vx - 1.85 * vn * nx, b.vy - 1.85 * vn * ny
                    if -vn > 40 then self:Emit("patrol", m, -vn) end
                end
            end
        elseif m.kind == "slider" then
            local ox, oy = m.ox or 0, m.oy or 0
            local imp = hitSegment(b, m.x1 + ox, m.y1 + oy, m.x2 + ox, m.y2 + oy, 0.8, m.vx or 0, m.vy or 0, r + 3)
            if imp and imp > 60 then self:Emit("wall", imp) end
        elseif m.kind == "orbit" then
            for _, p in ipairs(m.pts) do
                local dx, dy = b.x - p.x, b.y - p.y
                local rr = m.r + r
                local d2 = dx * dx + dy * dy
                if d2 < rr * rr then
                    local d = sqrt(d2)
                    if d < 1e-5 then dx, dy, d = 0, -1, 1 end
                    local nx, ny = dx / d, dy / d
                    b.x, b.y = p.x + nx * rr, p.y + ny * rr
                    local vn = (b.vx - p.vx) * nx + (b.vy - p.vy) * ny
                    if vn < 0 then
                        b.vx, b.vy = b.vx - 1.9 * vn * nx, b.vy - 1.9 * vn * ny
                        if -vn > 40 then self:Emit("wisp", p, -vn) end
                    end
                end
            end
        elseif m.kind == "gate" and (m.closed or 0) > 0.02 then
            local c = m.closed
            local ex, ey = m.x1 + (m.x2 - m.x1) * c, m.y1 + (m.y2 - m.y1) * c
            local imp = hitSegment(b, m.x1, m.y1, ex, ey, 0.7, 0, 0, r + 3)
            if imp and imp > 60 then self:Emit("wall", imp) end
        end
    end
    if b.vx ~= vx0 or b.vy ~= vy0 or b.x ~= x0 or b.y ~= y0 then touched = self.lastMover or true end
    return touched
end

function Putt:Step(h)
    local b, hole = self.ball, self.hole
    local r = P.BALL_R
    b.age = b.age + h
    local tu = b.tunnel
    if tu then
        tu.t = tu.t + h
        if tu.t < tu.dur then return end
        local pt = tu.pt
        b.tunnel = nil
        b.x, b.y = tu.tx, tu.ty
        -- however softly it went in, the tunnel always rolls it back out into play,
        -- in the direction that mouth faces
        local sp = pt.exit or max(tu.sp, P.TUNNEL_EXIT)   -- pt.exit: this tunnel always lets the ball out at one gentle pace
        local dx, dy
        if tu.toB then dx, dy = pt.dx, pt.dy else dx, dy = pt.adx, pt.ady end
        if dx then
            b.vx, b.vy = dx * sp, dy * sp
        else
            local d = sqrt(tu.vx * tu.vx + tu.vy * tu.vy)
            if d > 1e-3 then b.vx, b.vy = tu.vx / d * sp, tu.vy / d * sp end
        end
        b.portalLock, b.lockX, b.lockY = pt, tu.tx, tu.ty
        self:Emit("tunnelOut", pt, tu)
        return
    end
    if b.carryLock then b.carryLock = b.carryLock - h; if b.carryLock <= 0 then b.carryLock = nil end end
    local cr = b.carry
    if cr then
        local m = cr.m
        cr.t = cr.t - h
        b.x, b.y, b.vx, b.vy = m.x, m.y, 0, 0
        if cr.t <= 0 then
            -- set down just ahead of it, on open ground; if there is none yet, it keeps walking
            local sp = sqrt((m.vx or 0) ^ 2 + (m.vy or 0) ^ 2)
            local ux, uy = 0, -1
            if sp > 1 then ux, uy = m.vx / sp, m.vy / sp end
            local px, py = m.x + ux * (m.r + P.BALL_R + 4), m.y + uy * (m.r + P.BALL_R + 4)
            local lt = TERRAIN[Putt.Cell(hole, px, py) or " "]
            if (lt and not lt.hazard and not lt.pit and Putt.Clearance(hole, px, py) >= P.BALL_R + 1) or cr.t < -3 then
                if cr.t >= -3 then b.x, b.y = px, py end
                b.vx, b.vy = ux * 70, uy * 70
                b.carry, b.carryLock = nil, 1.2
                self:Emit("drop", m)
            end
        end
        return
    end
    local tw = b.twist
    if tw then
        -- spinning up the funnel: the ball circles the tornado, climbing, as the tornado carries it along
        tw.t = tw.t + h
        local a = tw.a
        local wx, wy = Putt.WhirlPos(a, hole.clock or 0)
        local k = min(1, tw.t / tw.dur)
        local ang = tw.ang + tw.spin * tw.t
        local rad = tw.rad * (1 - k) + 6
        b.x, b.y = wx + cos(ang) * rad, wy + sin(ang) * rad
        b.z = 1.5 * k
        if k >= 1 then
            -- thrown clear, the way it was facing when the funnel let go. It always comes down on open
            -- ground on the course: if there is none along that line, the throw swings round, a little
            -- at a time, to the nearest heading that has some.
            local want = a.throw or 125
            local ux, uy, dist
            for _, turn in ipairs({ 0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4, 1.75, -1.75, 2.1, -2.1, 2.45, -2.45, 2.8, -2.8, 3.14 }) do
                local cx, cy = cos(ang + turn), sin(ang + turn)
                for _, d in ipairs({ 0, 12, 24, -14, -28, -42, -56, -70, -84, -98 }) do
                    local lx, ly = b.x + cx * (want + d), b.y + cy * (want + d)
                    local lt = TERRAIN[Putt.Cell(hole, lx, ly) or " "]
                    if lt and not lt.hazard and not lt.pit and Putt.Clearance(hole, lx, ly) >= P.BALL_R + 1 then
                        ux, uy, dist = cx, cy, want + d
                        break
                    end
                end
                if dist then break end
            end
            if not dist then ux, uy, dist = cos(ang), sin(ang), 20 end   -- nowhere at all: it drops beside the funnel
            b.twist, b.twistCd = nil, 1.5
            b.air = { t = 0, dur = 0.55 + dist / 420, fx = b.x, fy = b.y, tx = b.x + ux * dist, ty = b.y + uy * dist,
                      vx = ux * 130, vy = uy * 130, z0 = b.z, twister = a }
            self:Emit("twistThrow", a, b.air)
        end
        return
    end
    if (b.twistCd or 0) > 0 and not b.air then b.twistCd = b.twistCd - h end
    local air = b.air
    if air then
        -- in the air off a ramp: nothing touches it until it comes down
        air.t = air.t + h
        local k = min(1, air.t / air.dur)
        b.x, b.y = air.fx + (air.tx - air.fx) * k, air.fy + (air.ty - air.fy) * k
        b.z = air.z0 and (air.z0 * (1 - k) + 0.6 * math.sin(k * math.pi)) or math.sin(k * math.pi)
        if k >= 1 then
            b.air, b.z, b.lift = nil, nil, nil
            b.vx, b.vy = air.vx * 0.55, air.vy * 0.55
            self:Emit("land", air)
        end
        return
    end
    local ch = Putt.Cell(hole, b.x, b.y)
    local t = TERRAIN[ch or " "]
    if not t then
        return self:Hazard("Out of bounds!")
    end
    if t.hearth then
        local fx, fy = b.x, b.y
        b.x, b.y, b.vx, b.vy = hole.tee.x, hole.tee.y, 0, 0
        b.hexT = nil
        self:Emit("hearth", fx, fy)
        return
    end
    if t.hex and not b.hexed then b.hexed = true; b.hexT = 1.8; b.hexN = -1; b.hexSheep = t.sheep; self:Emit("hex", t.sheep) end
    if b.hexT then
        b.hexT = b.hexT - h
        local n = floor((1.8 - b.hexT) / 0.45)
        if n ~= b.hexN then
            b.hexN = n
            local a = (b.x * 12.9898 + b.y * 78.233 + n * 37.7) % 6.2832
            b.vx, b.vy = math.cos(a) * 150, math.sin(a) * 150
        end
        if b.hexT <= 0 then b.hexT = nil; self:Emit("hexEnd") end
    end
    if t.bless and not self.blessed and not b.usedBless then self.blessed = true; self:Emit("bless") end
    for _, c in ipairs(hole.cannons or {}) do
        local cx, cy = b.x - c.x, b.y - c.y
        if cx * cx + cy * cy < c.r * c.r then
            -- you aim the shot by how you roll in: the ball flies the way it was travelling (within the
            -- cannon's arc), and a faster roll-in carries further
            local ax, ay = c.tx - c.x, c.ty - c.y
            local d0 = sqrt(ax * ax + ay * ay); ax, ay = ax / d0, ay / d0
            local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
            local ux, uy = ax, ay
            if sp > 20 and (b.vx * ax + b.vy * ay) > 0 then
                local off = math.atan2(ax * b.vy - ay * b.vx, ax * b.vx + ay * b.vy)
                off = max(-0.6, min(0.6, off))
                local ca, sa = cos(off), sin(off)
                ux, uy = ax * ca - ay * sa, ax * sa + ay * ca
            end
            local dist = d0 * max(0.8, min(1.25, 0.8 + 0.45 * (sp - 120) / 380))
            local lx, ly = c.x + ux * dist, c.y + uy * dist
            -- never fire into trouble: ease back toward the cannon's own mark until the landing is safe
            for _, k in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
                local px, py = lx + (c.tx - lx) * k, ly + (c.ty - ly) * k
                local lt = TERRAIN[Putt.Cell(hole, px, py) or " "]
                if k == 1 or (lt and not lt.hazard and not lt.pit and Putt.Clearance(hole, px, py) >= P.BALL_R + 2) then lx, ly = px, py; break end
            end
            b.air = { t = 0, dur = c.dur, fx = c.x, fy = c.y, tx = lx, ty = ly, vx = ux * 30, vy = uy * 30, cannon = c }
            b.x, b.y, b.z = c.x, c.y, 0
            self:Emit("launch", c, b.air)
            return
        end
    end
    for _, rp in ipairs(hole.ramps) do
        local rx, ry = b.x - rp.x, b.y - rp.y
        if rx * rx + ry * ry < rp.r * rp.r then
            local along = b.vx * rp.dx + b.vy * rp.dy
            if along < rp.min and along > 40 and not b.rampShort then
                -- rolled onto it without the pace to fly: say so once per putt
                b.rampShort = true
                self:Emit("rampShort", rp)
            end
            if along >= rp.min then
                -- the ramp throws the ball the way it points (a glancing hit keeps a little of its sideways drift)
                local side = b.vx * -rp.dy + b.vy * rp.dx
                local ux, uy = rp.dx, rp.dy
                b.vx, b.vy = rp.dx * along + -rp.dy * side * 0.4, rp.dy * along + rp.dx * side * 0.4
                local want = max(rp.clear, min(rp.clear * 1.9, along * 0.36))
                -- come down on open ground: the nearest safe spot along the flight line, long before short
                local best
                for _, d in ipairs({ 0, 6, 12, 18, 26, 34, 44, -6, -12 }) do
                    local lx, ly = b.x + ux * (want + d), b.y + uy * (want + d)
                    local lt = TERRAIN[Putt.Cell(hole, lx, ly) or " "]
                    if lt and not lt.hazard and Putt.Clearance(hole, lx, ly) >= P.BALL_R + 1 then best = want + d; break end
                end
                local dist = best or want
                b.air = { t = 0, dur = 0.42 + dist / 520, fx = b.x, fy = b.y, tx = b.x + ux * dist, ty = b.y + uy * dist,
                          vx = b.vx, vy = b.vy, ramp = rp }
                b.z = 0
                self:Emit("launch", rp, b.air)
                return
            end
        end
    end
    if t.hazard then return self:Hazard(t.hazard) end
    if t.pit then
        local safe = false
        for _, m in ipairs(hole.movers) do
            if m.kind == "tram" and abs(b.x - m.x) <= m.hw and abs(b.y - m.y) <= m.hh then safe = true end
        end
        if not safe then return self:Hazard(t.pit) end
    end

    local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
    -- slopes and boost pads
    local ax, ay = 0, 0
    if t.slope then ax, ay = t.slope[1] * P.SLOPE, t.slope[2] * P.SLOPE end
    -- the shape of the green: gravity down whatever slope the ball is on
    local lie = 0
    if hole.surf then
        local cx, cy = Putt.Lie(hole, b.x, b.y)
        ax, ay = ax + cx, ay + cy
        lie = sqrt(cx * cx + cy * cy)
    end
    if t.boost then
        local along = b.vx * t.boost[1] + b.vy * t.boost[2]
        if along < P.BOOST_MAX then ax, ay = ax + t.boost[1] * P.BOOST, ay + t.boost[2] * P.BOOST end
        if not b.boosted then b.boosted = true; self:Emit("boost") end
    else
        b.boosted = false
    end
    -- wind fans: push along the fan's direction, fading with distance
    for _, f in ipairs(hole.fans) do
        local rx, ry = b.x - f.x, b.y - f.y
        local along = rx * f.dx + ry * f.dy
        if f.period then f.off = ((hole.clock or 0) % f.period) > f.period * 0.45 end   -- the hole clock, so a replay of the shot matches
        if along > 0 and along < f.len and not f.off then
            local perp = abs(rx * f.dy - ry * f.dx)
            if perp < f.width / 2 then
                local k = f.force * (1 - 0.5 * along / f.len) * (1 - perp / (f.width / 2) * 0.3)
                ax, ay = ax + f.dx * k, ay + f.dy * k
                b.windy = true
            end
        end
    end
    b.vx, b.vy = b.vx + ax * h, b.vy + ay * h

    local gDecel, gDrag
    if hole.actors[1] or (self.shots and self.shots[1]) then
        local stop
        gDecel, gDrag, stop = self:StepActors(b, h)
        if stop then return end
    end

    -- rolling friction
    local decel = gDecel or t.decel or P.DECEL
    local drag = gDrag or t.drag or P.DRAG
    local plain = not (gDecel or t.decel)
    sp = sqrt(b.vx * b.vx + b.vy * b.vy)
    if sp > 0 then
        -- (it eases as the ball slows: see HOLD)
        local ns = sp - Putt.Friction(sp, decel, drag, plain) * h
        if ns < 0 then ns = 0 end
        local k = ns / sp
        b.vx, b.vy = b.vx * k, b.vy * k
        sp = ns
    end
    if sp > P.MAX_SPEED then
        local k = P.MAX_SPEED / sp
        b.vx, b.vy, sp = b.vx * k, b.vy * k, P.MAX_SPEED
    end

    -- cup: gentle pull when slow and close, sink when slow enough over the hole
    local cup = hole.cup
    local cdx, cdy = cup.x - b.x, cup.y - b.y
    local cd = sqrt(cdx * cdx + cdy * cdy)
    -- The tee shot (your ace attempt) must arrive very gently if it rolled a long way;
    -- every putt after that gets the normal, forgiving cup.
    local strict = (self.strokes == 1) and min(1, max(0, ((b.travel or 0) - 150) / 250)) or 0
    local sinkSpeed = P.SINK_SPEED - (P.SINK_SPEED - P.SINK_SPEED_LONG) * strict
    -- like a real cup, the middle takes a firmer putt than the edge: catch the lip too fast and it spins out
    local off = min(1, cd / (P.CUP_R - 2))
    sinkSpeed = sinkSpeed * (1 - P.LIP * off * off)
    if cd < P.CUP_R + 5 and sp < 170 - 90 * strict and cd > 0.01 then
        local pull = (520 - 220 * strict) * (1 - cd / (P.CUP_R + 5))
        b.vx, b.vy = b.vx + cdx / cd * pull * h, b.vy + cdy / cd * pull * h
    end
    if cd < P.CUP_R - 2 then
        if sp < sinkSpeed then return self:Sink() end
        -- lip: too hot, it rattles across
        b.vx, b.vy = b.vx * (1 - 1.5 * h), b.vy * (1 - 1.5 * h)
        if not b.lipped then b.lipped = true; self:Emit("lip") end
    end

    b.x, b.y = b.x + b.vx * h, b.y + b.vy * h
    b.travel = (b.travel or 0) + sp * h
    for _, c in ipairs(hole.coins or NONE) do
        if not c.got and (b.x - c.x) ^ 2 + (b.y - c.y) ^ 2 < (r + 9) ^ 2 then
            c.got = true
            self.coinsGot = (self.coinsGot or 0) + 1
            self:Emit("coin", c)
        end
    end

    -- walls
    local walls = Putt.WallsNear(hole, b.x, b.y)
    for i = 1, #walls do
        local w = walls[i]
        local x1, y1, x2, y2 = w[1], w[2], w[3], w[4]
        if (b.x + r > min(x1, x2)) and (b.x - r < max(x1, x2)) and (b.y + r > min(y1, y2)) and (b.y - r < max(y1, y2)) then
            local imp = hitSegment(b, x1, y1, x2, y2, P.WALL_E, 0, 0, r)
            if imp and imp > 60 then self:Emit("wall", imp) end
        end
    end
    -- bumpers
    for _, bp in ipairs(hole.bumpers) do
        local dx, dy = b.x - bp.x, b.y - bp.y
        local rr = bp.r + r
        local d2 = dx * dx + dy * dy
        if d2 < rr * rr then
            local d = sqrt(d2)
            if d < 1e-5 then dx, dy, d = 0, -1, 1 end
            local nx, ny = dx / d, dy / d
            b.x, b.y = bp.x + nx * rr, bp.y + ny * rr
            local vn = b.vx * nx + b.vy * ny
            if vn < 0 then
                b.vx, b.vy = b.vx - (1 + P.BUMP_E) * vn * nx, b.vy - (1 + P.BUMP_E) * vn * ny
                if bp.kick then
                    -- a bouncy mushroom: it throws the ball off harder than it came in
                    local out = b.vx * nx + b.vy * ny
                    if out < bp.kick then b.vx, b.vy = b.vx + (bp.kick - out) * nx, b.vy + (bp.kick - out) * ny end
                end
                if -vn > 40 then self:Emit("bumper", bp, -vn) end
            end
        end
    end
    -- moving obstacles
    self:HitMovers(b, r)
    -- tunnels (painted holes) are two-way: roll into either mouth and come out the other.
    -- old-style portals are one way A -> B.
    for _, pt in ipairs(hole.portals) do
        local enterA = (b.x - pt.ax) ^ 2 + (b.y - pt.ay) ^ 2 < pt.r * pt.r
        local enterB = pt.baked and (b.x - pt.bx) ^ 2 + (b.y - pt.by) ^ 2 < pt.r * pt.r
        if b.portalLock == pt then
            -- just came out of this tunnel: ignore it until the ball has left the mouth
            local ex, ey = b.x - (b.lockX or pt.bx), b.y - (b.lockY or pt.by)
            if ex * ex + ey * ey > (pt.r + 8) * (pt.r + 8) then b.portalLock = nil end
        elseif pt.baked and (enterA or enterB) then
            -- a real tunnel: the ball drops in, rolls underground for a moment,
            -- and comes out the far mouth (keeping its speed)
            local tsp = sqrt(b.vx * b.vx + b.vy * b.vy)
            local len = sqrt((pt.bx - pt.ax) ^ 2 + (pt.by - pt.ay) ^ 2)
            local fx, fy, tx, ty = pt.ax, pt.ay, pt.bx, pt.by
            if not enterA then fx, fy, tx, ty = pt.bx, pt.by, pt.ax, pt.ay end
            b.tunnel = { pt = pt, t = 0, dur = pt.lift and 1.3 or max(0.4, min(1.1, len / max(tsp, 180))), sp = tsp,
                         vx = b.vx, vy = b.vy, toB = enterA, fx = fx, fy = fy, tx = tx, ty = ty }
            b.x, b.y = fx, fy
            b.vx, b.vy = 0, 0
            self:Emit("portal", pt, b.tunnel.dur, b.tunnel)
            return
        elseif enterA then
            b.x, b.y = pt.bx, pt.by
            if pt.dx then
                local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
                b.vx, b.vy = pt.dx * sp, pt.dy * sp
            end
            b.portalLock, b.lockX, b.lockY = pt, pt.bx, pt.by
            self:Emit("portal", pt)
        end
    end
    -- safety: escaped the board somehow
    if b.x < -20 or b.y < -20 or b.x > P.W + 20 or b.y > P.H + 20 then
        return self:Hazard("Out of bounds!")
    end

    -- come to rest
    sp = sqrt(b.vx * b.vx + b.vy * b.vy)
    if sp < P.STOP * 3 then b.still = (b.still or 0) + h else b.still = 0 end
    local hold = t.decel or (P.DECEL * P.HOLD)      -- the steepest pull a ball can sit still against here
    local resting = (sp < P.STOP and not t.boost and not b.windy and lie < hold
            and (not t.slope or hold > P.SLOPE * max(abs(t.slope[1]), abs(t.slope[2]))))
        or (b.still > 0.7 and lie < hold)
        or b.still > 1.0   -- held still for a second (pinned against a rail by a slope, say): it has stopped
    b.windy = false
    if resting or b.age > P.SHOT_TIMEOUT then
        b.vx, b.vy = 0, 0
        self:Rest()
    end
end

-- The height of a green's surface at (x, y): the sum of its shapes (see BuildPainted, ex.surface).
function Putt.SurfaceHeight(list, x, y)
    local H = 0
    for i = 1, #list do
        local s = list[i]
        local k = s.k
        if k == "tilt" then
            H = H - s.a * (s.dx * (x - P.W / 2) + s.dy * (y - P.H / 2))
        elseif k == "grade" then
            local ex, ey = s.x2 - s.x1, s.y2 - s.y1
            local u = ((x - s.x1) * ex + (y - s.y1) * ey) / (ex * ex + ey * ey)
            if u >= 1 then H = H + s.h elseif u > 0 then H = H + s.h * u * u * (3 - 2 * u) end
        elseif k == "ridge" then
            local p, best = s.pts, 1e18
            for q = 1, #p - 3, 2 do
                local x1, y1 = p[q], p[q + 1]
                local ex, ey = p[q + 2] - x1, p[q + 3] - y1
                local l2 = ex * ex + ey * ey
                local t = l2 > 0 and ((x - x1) * ex + (y - y1) * ey) / l2 or 0
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
                local dx, dy = x - (x1 + ex * t), y - (y1 + ey * t)
                local d2 = dx * dx + dy * dy
                if d2 < best then best = d2 end
            end
            local w2 = s.w * s.w
            if best < w2 then local v = 1 - best / w2; H = H + s.h * v * v end
        elseif k == "mound" then
            local dx, dy = x - s.x, y - s.y
            local d2 = dx * dx + dy * dy
            if d2 < s.r * s.r then
                local u, f = sqrt(d2) / s.r, s.flat or 0
                if u <= f then H = H + s.h
                else local v = (u - f) / (1 - f); local w = 1 - v * v; H = H + s.h * w * w end
            end
        elseif k == "funnel" then
            local dx, dy = x - s.x, y - s.y
            local d2 = dx * dx + dy * dy
            if d2 < s.r * s.r then
                local u = sqrt(d2) / s.r
                if u >= 0.6 then H = H - s.a * s.r * (1 - u) * (1 - u) / 0.8
                else H = H - s.a * s.r * (0.8 - u) end
            end
        end
    end
    return H
end

-- The surface worked out once on a grid: its height at every node, and the pull of gravity there
-- (the downhill slope). Play reads the pull between nodes; the screen reads both to draw the green.
local SURF_RES = 8
local surfCache = setmetatable({}, { __mode = "k" })
function Putt.SurfaceGrid(list, key, mirror)
    local c = key and surfCache[key]
    if c and c[mirror and 2 or 1] then return c[mirror and 2 or 1] end
    local res = SURF_RES
    local nx, ny = floor(P.W / res) + 1, floor(P.H / res) + 1
    local g = { res = res, nx = nx, ny = ny, gx = {}, gy = {}, hh = {} }
    local SH, e = Putt.SurfaceHeight, 2
    local lo, hi = 1e18, -1e18
    for j = 0, ny - 1 do
        local y = j * res
        for i = 0, nx - 1 do
            local x = i * res
            local n = j * nx + i + 1
            local h0 = SH(list, x, y)
            g.hh[n] = h0
            g.gx[n] = (SH(list, x - e, y) - SH(list, x + e, y)) / (2 * e)
            g.gy[n] = (SH(list, x, y - e) - SH(list, x, y + e)) / (2 * e)
            if h0 < lo then lo = h0 end
            if h0 > hi then hi = h0 end
        end
    end
    g.lo, g.hi = lo, hi
    if key then
        surfCache[key] = surfCache[key] or {}
        surfCache[key][mirror and 2 or 1] = g
    end
    return g
end

-- The pull of the green on a ball at (x, y): acceleration down the slope it is on.
function Putt.Lie(hole, x, y)
    local g = hole.surf
    if not g then return 0, 0 end
    local res, nx = g.res, g.nx
    local fx, fy = x / res, y / res
    local i, j = floor(fx), floor(fy)
    if i < 0 then i = 0 elseif i > nx - 2 then i = nx - 2 end
    if j < 0 then j = 0 elseif j > g.ny - 2 then j = g.ny - 2 end
    local u, v = fx - i, fy - j
    if u < 0 then u = 0 elseif u > 1 then u = 1 end
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    local n = j * nx + i + 1
    local gx, gy = g.gx, g.gy
    local a, b, c, d = (1 - u) * (1 - v), u * (1 - v), (1 - u) * v, u * v
    return gx[n] * a + gx[n + 1] * b + gx[n + nx] * c + gx[n + nx + 1] * d,
           gy[n] * a + gy[n + 1] * b + gy[n + nx] * c + gy[n + nx + 1] * d
end

-- How high the green stands at (x, y), for drawing it.
function Putt.Height(hole, x, y)
    local g = hole.surf
    if not g then return 0 end
    local res, nx = g.res, g.nx
    local fx, fy = x / res, y / res
    local i, j = floor(fx), floor(fy)
    if i < 0 then i = 0 elseif i > nx - 2 then i = nx - 2 end
    if j < 0 then j = 0 elseif j > g.ny - 2 then j = g.ny - 2 end
    local u, v = min(1, max(0, fx - i)), min(1, max(0, fy - j))
    local n = j * nx + i + 1
    local hh = g.hh
    return hh[n] * (1 - u) * (1 - v) + hh[n + 1] * u * (1 - v) + hh[n + nx] * (1 - u) * v + hh[n + nx + 1] * u * v
end

-- Rail relief: like the house rule of moving your ball a club-head off the wall,
-- a ball that stops pressed against a rail or bumper is eased into open grass so
-- every lie leaves room for a real swing. Never moves it into a hazard or the void.
function Putt.Clearance(hole, x, y)
    -- distance from (x, y) to the nearest rail, and to the nearest bumper surface
    local best = 1e9
    local walls = Putt.WallsAround(hole, x, y)
    for i = 1, #walls do
        local w = walls[i]
        local x1, y1 = w[1], w[2]
        local ex, ey = w[3] - x1, w[4] - y1
        local len2 = ex * ex + ey * ey
        local t = len2 > 0 and ((x - x1) * ex + (y - y1) * ey) / len2 or 0
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local dx, dy = x - (x1 + ex * t), y - (y1 + ey * t)
        local d = sqrt(dx * dx + dy * dy)
        if d < best then best = d end
    end
    for _, bp in ipairs(hole.bumpers) do
        local d = sqrt((x - bp.x) ^ 2 + (y - bp.y) ^ 2) - bp.r + 4
        if d < best then best = d end
    end
    return best
end

-- how many of 36 swing directions are blocked within a short putt's reach
function Putt.Blocked(hole, x, y)
    local r, n = P.BALL_R, 0
    local walls = Putt.WallsAround(hole, x, y)
    for k = 0, 35 do
        local a = k * pi / 18
        local ca, sa = cos(a), sin(a)
        for s = 2, 28, 2 do
            local px, py = x + ca * s, y + sa * s
            local hit = Putt.Cell(hole, px, py) == nil
            if not hit then
                for i = 1, #walls do
                    local w = walls[i]
                    local ex, ey = w[3] - w[1], w[4] - w[2]
                    local l2 = ex * ex + ey * ey
                    local t = l2 > 0 and ((px - w[1]) * ex + (py - w[2]) * ey) / l2 or 0
                    if t < 0 then t = 0 elseif t > 1 then t = 1 end
                    local dx, dy = px - w[1] - ex * t, py - w[2] - ey * t
                    if dx * dx + dy * dy < r * r then hit = true; break end
                end
            end
            if not hit then
                for _, bp in ipairs(hole.bumpers) do
                    if (px - bp.x) ^ 2 + (py - bp.y) ^ 2 < (bp.r + r) ^ 2 then hit = true; break end
                end
            end
            if hit then n = n + 1; break end
        end
    end
    return n
end
local MAX_BLOCKED = 12 -- at least two thirds of directions always open

local function safeGround(hole, x, y)
    -- the spot and a ball-width around it must be plain, playable, hazard-free ground
    for _, o in ipairs({ { 0, 0 }, { 7, 0 }, { -7, 0 }, { 0, 7 }, { 0, -7 } }) do
        local ch = Putt.Cell(hole, x + o[1], y + o[2])
        local t = ch and TERRAIN[ch]
        if not t or t.hazard or t.boost then return false end
    end
    for _, a in ipairs(hole.actors or NONE) do
        if a.kind == "pool" and (x - a.x) ^ 2 + (y - a.y) ^ 2 < (a.r + 8) ^ 2 then return false end
    end
    return true
end
Putt.SafeGround = safeGround

-- Rail relief: like the house rule of moving your ball a club-head off the wall,
-- a ball that stops pressed against a rail or bumper is moved to the nearest spot
-- of safe, open grass with room for a full swing. Never into a hazard or the void.
function Putt:Relief()
    local hole, b = self.hole, self.ball
    local D = P.RELIEF
    if D <= 0 then return false end
    local cup = hole.cup
    local x0, y0 = b.x, b.y
    -- only a ball that is truly jammed against a rail or bumper gets moved, and only a
    -- hair: where it stops is where you play it from (players hated the ball "teleporting")
    if Putt.Clearance(hole, x0, y0) >= P.BALL_R + 2.5 and safeGround(hole, x0, y0) then return false end
    D = P.BALL_R + 5
    -- nearest qualifying spot, searched in widening rings (closest first)
    local bx, by
    for ring = 2, 120, 2 do
        local n = math.max(12, floor(ring * 0.8))
        local bestD
        for k = 0, n - 1 do
            local a = k * 2 * pi / n
            local x, y = x0 + cos(a) * ring, y0 + sin(a) * ring
            local lx, ly = Putt.Lie(hole, x, y)
            if Putt.Clearance(hole, x, y) >= D and safeGround(hole, x, y) and lx * lx + ly * ly < (P.DECEL * P.HOLD) ^ 2
                and (x - cup.x) ^ 2 + (y - cup.y) ^ 2 >= (P.CUP_R + 10) ^ 2 then
                -- keep the ball on the same side of every rail (no hopping through walls)
                local crosses = false
                for i = 1, #hole.walls do
                    local w = hole.walls[i]
                    local d1 = (w[3] - w[1]) * (y0 - w[2]) - (w[4] - w[2]) * (x0 - w[1])
                    local d2 = (w[3] - w[1]) * (y - w[2]) - (w[4] - w[2]) * (x - w[1])
                    local d3 = (x - x0) * (w[2] - y0) - (y - y0) * (w[1] - x0)
                    local d4 = (x - x0) * (w[4] - y0) - (y - y0) * (w[3] - x0)
                    if d1 * d2 < 0 and d3 * d4 < 0 then crosses = true; break end
                end
                if not crosses then
                    local cd = (x - cup.x) ^ 2 + (y - cup.y) ^ 2
                    if not bestD or cd < bestD then bestD, bx, by = cd, x, y end -- tie-break: towards the cup
                end
            end
        end
        if bx then break end
    end
    if not bx then return false end
    b.x, b.y = bx, by
    self:Emit("relief", x0, y0, bx, by)
    return true
end

-- painted holes ship a map of every good lie (courseart/build.py), so relief is
-- just "nearest good spot on the same side of the rails"
local function crossesWall(hole, x0, y0, x, y)
    for i = 1, #hole.walls do
        local w = hole.walls[i]
        local d1 = (w[3] - w[1]) * (y0 - w[2]) - (w[4] - w[2]) * (x0 - w[1])
        local d2 = (w[3] - w[1]) * (y - w[2]) - (w[4] - w[2]) * (x - w[1])
        if d1 * d2 < 0 then
            local d3 = (x - x0) * (w[2] - y0) - (y - y0) * (w[1] - x0)
            local d4 = (x - x0) * (w[4] - y0) - (y - y0) * (w[3] - x0)
            if d3 * d4 < 0 then return true end
        end
    end
    return false
end

function Putt:ReliefPainted(x0, y0)
    local hole, b = self.hole, self.ball
    local res, lie = hole.res, hole.lie
    local cols, rows = hole.gridCols, hole.gridRows
    local c0, r0 = floor(x0 / res), floor(y0 / res)
    local function good(c, r)
        if c < 0 or r < 0 or c >= cols or r >= rows then return false end
        return lie[r + 1]:byte(c + 1) == 49 -- "1"
    end
    if good(c0, r0) then return false end
    local cup = hole.cup
    local function search(radius, tries)
        local cands = {}
        for r = max(0, r0 - radius), min(rows - 1, r0 + radius) do
            local row = lie[r + 1]
            for c = max(0, c0 - radius), min(cols - 1, c0 + radius) do
                if row:byte(c + 1) == 49 then
                    local x, y = (c + 0.5) * res, (r + 0.5) * res
                    if (x - cup.x) ^ 2 + (y - cup.y) ^ 2 >= (P.CUP_R + 10) ^ 2 then
                        cands[#cands + 1] = { x, y, (x - x0) ^ 2 + (y - y0) ^ 2 }
                    end
                end
            end
        end
        table.sort(cands, function(p, q) return p[3] < q[3] end)
        for i = 1, min(#cands, tries) do
            local x, y = cands[i][1], cands[i][2]
            -- only spots within the searched square are certainly the nearest
            if not crossesWall(hole, x0, y0, x, y) then return x, y end
        end
    end
    -- nearby first (cheap), then the whole neighbourhood
    local x, y = search(8, 30)
    if not x then x, y = search(32, 400) end
    if not x then return false end
    b.x, b.y = x, y
    self:Emit("relief", x0, y0, x, y)
    return true
end

function Putt:Rest()
    local b = self.ball
    if self.shots and self.shots[1] then
        for _, s in ipairs(self.shots) do self:Emit("fizzle", s.x, s.y) end
        self.shots = {}
    end
    for _, a in ipairs(self.hole.actors or NONE) do if a.kind == "mage" then a.wind = nil end end
    self:Relief()
    self.rest = { x = b.x, y = b.y }
    if self.strokes >= P.MAX_STROKES then
        self:Emit("pickup")
        return self:CompleteHole(false)
    end
    self.state = "aim"
    self:Emit("rest")
end

function Putt:Hazard(text)
    local b = self.ball
    if b.knocked then
        -- an obstacle knocked a resting ball in: put it back, no penalty
        b.knocked = nil
        b.x, b.y, b.vx, b.vy = self.rest.x, self.rest.y, 0, 0
        self:Emit("hazard", text, b.x, b.y, true)
        self.state = "aim"
        return
    end
    self.strokes = self.strokes + 1 -- penalty stroke
    local fx, fy = b.x, b.y
    b.x, b.y, b.vx, b.vy = self.rest.x, self.rest.y, 0, 0
    self:Emit("hazard", text, fx, fy)
    if self.strokes >= P.MAX_STROKES then
        self:Emit("pickup")
        return self:CompleteHole(false)
    end
    self.state = "aim"
end

function Putt:Sink()
    local b = self.ball
    b.vx, b.vy = 0, 0
    b.x, b.y = self.hole.cup.x, self.hole.cup.y
    self:CompleteHole(true)
end

function Putt.HoleAdjust(strokes, par)
    local adj = (strokes - par) * P.STROKE_SEC
    if strokes == 1 then adj = adj - P.ACE_SEC end
    return adj
end

function Putt:CompleteHole(sunk)
    local strokes = self.strokes
    local par = self.hole.par
    local adj = Putt.HoleAdjust(strokes, par)
    local coins = sunk and (self.coinsGot or 0) or 0
    adj = adj - coins * P.COIN_SEC
    self.card[self.index] = { strokes = strokes, par = par, adj = adj, sunk = sunk, coins = coins }
    self.state = "sunk"
    self.sunkT = 1.6
    self:Emit("sunk", strokes, par, adj, sunk)
end

function Putt:Totals()
    local strokes, par, adj = 0, 0, 0
    for _, c in ipairs(self.card or {}) do
        strokes, par, adj = strokes + c.strokes, par + c.par, adj + c.adj
    end
    return strokes, par, adj
end

-- The time that goes on the board: your clock, plus penalty strokes, less bonuses. Bonuses can take
-- off at most half the clock, so no run of birdies and coins ever banks a round down to nothing.
function Putt.FinalTime(elapsed, adj)
    return max(elapsed * (1 - P.MAX_BONUS), elapsed + (adj or 0))
end

function Putt:Finish()
    local strokes, par, adj = self:Totals()
    self.final = Putt.FinalTime(self.elapsed, adj)
    self.state = "done"
    self:Emit("done", self.final, self.elapsed, adj, strokes, par)
end

---------------------------------------------------------------------------
-- Aim guide: straight ray to the first thing it touches plus a short
-- reflected stub. Deliberately short - reading the bounce is the skill.
---------------------------------------------------------------------------
function Putt:Guide(angle, maxLen)
    local hole, b = self.hole, self.ball
    local r = P.BALL_R
    local dx, dy = cos(angle), sin(angle)
    local x, y = b.x, b.y
    local stepLen = 3
    local travelled = 0
    local pts = { x, y }
    local bounced = false
    local probe = { x = x, y = y, vx = dx, vy = dy }
    while travelled < maxLen do
        probe.x, probe.y = probe.x + probe.vx * stepLen, probe.y + probe.vy * stepLen
        travelled = travelled + stepLen
        local hit = false
        local near = Putt.WallsNear(hole, probe.x, probe.y)
        for i = 1, #near do
            local w = near[i]
            if hitSegment(probe, w[1], w[2], w[3], w[4], 1, 0, 0, r) then hit = true end
        end
        for _, bp in ipairs(hole.bumpers) do
            local ex, ey = probe.x - bp.x, probe.y - bp.y
            local rr = bp.r + r
            local d2 = ex * ex + ey * ey
            if d2 < rr * rr then
                local d = sqrt(d2)
                local nx, ny = ex / d, ey / d
                probe.x, probe.y = bp.x + nx * rr, bp.y + ny * rr
                local vn = probe.vx * nx + probe.vy * ny
                if vn < 0 then probe.vx, probe.vy = probe.vx - 2 * vn * nx, probe.vy - 2 * vn * ny end
                hit = true
            end
        end
        if hit then
            pts[#pts + 1], pts[#pts + 2] = probe.x, probe.y
            if bounced then break end
            bounced = true
            maxLen = travelled + 46
        end
    end
    pts[#pts + 1], pts[#pts + 2] = probe.x, probe.y
    return pts
end

-- The aim line with the break read into it: the path the ball takes over its first `len` units,
-- bending with the lie of the green (rises, hollows and painted slopes) at the pace it is hit.
-- Only the ground is read, not rails or anything that moves: what happens after the first
-- stretch is still yours to judge.
function Putt:Preview(angle, power, len)
    local hole, b = self.hole, self.ball
    local x, y = b.x, b.y
    local sp = Putt.SpeedFor(power)
    if self.blessed then sp = sp * 1.35 end
    local vx, vy = cos(angle) * sp, sin(angle) * sp
    local pts = { x, y }
    local h, gone, mark = 1 / 120, 0, 0
    for _ = 1, 900 do
        local t = TERRAIN[Putt.Cell(hole, x, y) or " "] or TERRAIN["."]
        local ax, ay = Putt.Lie(hole, x, y)
        if t.slope then ax, ay = ax + t.slope[1] * P.SLOPE, ay + t.slope[2] * P.SLOPE end
        vx, vy = vx + ax * h, vy + ay * h
        local v = sqrt(vx * vx + vy * vy)
        if v > 0 then
            local nv = v - Putt.Friction(v, t.decel or P.DECEL, t.drag or P.DRAG, not t.decel) * h
            if nv <= 2 then break end
            vx, vy, v = vx * nv / v, vy * nv / v, nv
        end
        x, y = x + vx * h, y + vy * h
        gone = gone + v * h
        if gone - mark >= 6 then mark = gone; pts[#pts + 1], pts[#pts + 2] = x, y end
        if gone >= len then break end
    end
    if gone < len then
        -- a putt too soft to cover the line: carry it on straight, so the line never gives the distance away
        local n = #pts
        local dx, dy = cos(angle), sin(angle)
        if n >= 4 then
            local ex, ey = pts[n - 1] - pts[n - 3], pts[n] - pts[n - 2]
            local l = sqrt(ex * ex + ey * ey)
            if l > 1e-3 then dx, dy = ex / l, ey / l end
        end
        pts[#pts + 1], pts[#pts + 2] = x + dx * (len - gone), y + dy * (len - gone)
    elseif pts[#pts - 1] ~= x or pts[#pts] ~= y then
        pts[#pts + 1], pts[#pts + 2] = x, y
    end
    return pts
end

---------------------------------------------------------------------------
-- Formatting helpers shared by UI and leaderboards
---------------------------------------------------------------------------
function Putt.FormatTime(sec)
    sec = max(0, sec or 0)
    local m = floor(sec / 60)
    local s = sec - m * 60
    return ("%d:%04.1f"):format(m, s)
end

function Putt.FormatAdj(adj)
    if adj == 0 then return "+0s" end
    return (adj > 0 and "+" or "-") .. floor(abs(adj) + 0.5) .. "s"
end
