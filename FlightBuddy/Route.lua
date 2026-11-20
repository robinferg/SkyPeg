-- Flight Buddy :: Route.lua
-- The flight is the game. Every flight path route (say "Stormwind > Ironforge") has its own round of
-- Gryphon Greens: as many holes as the flight is long, drawn from the lands you take off from and
-- land in, the same for everyone who flies it. Routes keep their own records and leaderboards.
local ADDON, NS = ...

local Route = {}
NS.Route = Route

local floor, max, min = math.floor, math.max, math.min

-- which course's holes suit each zone (zones without a course of their own borrow the nearest in spirit)
local THEME = {
    human = { "Elwynn Forest", "Stormwind City", "Stormwind", "Westfall", "Redridge Mountains", "Duskwood",
              "Deadwind Pass" },
    arathi = { "Arathi Highlands", "Hillsbrad Foothills", "Alterac Mountains", "Southshore", "Refuge Pointe" },
    dwarf = { "Dun Morogh", "Ironforge", "Loch Modan", "Wetlands", "The Hinterlands", "Winterspring", "Alterac Valley" },
    gnome = { "Gnomeregan", "Searing Gorge", "Burning Steppes", "Badlands", "Blackrock Mountain", "Tanaris", "Un'Goro Crater" },
    nelf = { "Teldrassil", "Darnassus", "Darkshore", "Ashenvale", "Felwood", "Moonglade", "Feralas", "Azshara" },
    orc = { "Durotar", "Orgrimmar", "The Barrens", "Stonetalon Mountains", "Desolace", "Blasted Lands", "Swamp of Sorrows" },
    troll = { "Stranglethorn Vale", "Dustwallow Marsh", "Echo Isles", "Booty Bay" },
    undead = { "Tirisfal Glades", "Undercity", "Silverpine Forest", "Western Plaguelands", "Eastern Plaguelands" },
    mulgore = { "Mulgore", "Thunder Bluff", "Thousand Needles", "Silithus" },
}
local ZONE = {}
for theme, zones in pairs(THEME) do for _, z in ipairs(zones) do ZONE[z:lower()] = theme end end

function Route.ThemeOf(zone)
    if not zone then return nil end
    local z = zone:lower()
    if ZONE[z] then return ZONE[z] end
    for name, theme in pairs(ZONE) do
        if z:find(name, 1, true) or name:find(z, 1, true) then return theme end
    end
    return nil
end

-- flight masters are named "Place, Zone"
local function Split(node)
    local place, zone = (node or ""):match("^(.-),%s*(.+)$")
    if place then return place, zone end
    return node or "?", nil
end
Route.Split = Split

local function Hash(s)
    local n = 5381
    for i = 1, #s do n = (n * 33 + s:byte(i)) % 16777216 end
    return n
end

-- seconds of flight a hole is meant to fill, at the reference pace (the same for every player,
-- so everyone on a route gets the same number of holes)
local HOLE_SECONDS, REF_PACE = 42, 1000

-- fl = { from = "Stormwind, Elwynn", to = "Ironforge, Dun Morogh", dist = taxi-map distance or nil, zone = zone at take-off }
function Route.Spec(fl)
    if not (fl and fl.from and fl.to) then return nil end
    local fromPlace, fromZone = Split(fl.from)
    local toPlace, toZone = Split(fl.to)
    local key = fl.from .. " > " .. fl.to
    local h = Hash(key)
    local n = 3
    if fl.dist and fl.dist > 0 then n = floor(fl.dist * REF_PACE / HOLE_SECONDS + 0.5) end
    n = max(1, min(9, n))
    return {
        key = key, id = ("%06x"):format(h), seed = h % 900000 + 1000,
        from = fromPlace, to = toPlace, fromZone = fromZone or fl.zone, toZone = toZone,
        t1 = Route.ThemeOf(fromZone) or Route.ThemeOf(fromPlace) or Route.ThemeOf(fl.zone),
        t2 = Route.ThemeOf(toZone) or Route.ThemeOf(toPlace),
        holes = n,
        fl = { from = fl.from, to = fl.to, dist = fl.dist, zone = fl.zone },
    }
end

function Route.Name(spec) return spec.from .. "  >  " .. spec.to end
function Route.Board(spec) return "rt_" .. spec.id end

-- the round for a route: the first half over the land you leave, the second over the land you reach
function Route.Course(spec)
    local Putt, C = NS.Putt, NS.PuttCourses
    if not (Putt and C and spec) then return nil end
    local rng = NS.Game.RNG(spec.seed)
    local order = Putt.COURSE_ORDER
    local t1 = (spec.t1 and C[spec.t1]) and spec.t1 or order[rng.int(1, #order)]
    local t2 = (spec.t2 and C[spec.t2]) and spec.t2 or t1
    local used, holes, par, lands = {}, {}, 0, {}
    local function draw(theme)
        local list = C[theme].holes
        local free = {}
        for i, tpl in ipairs(list) do if not used[tpl.key] then free[#free + 1] = tpl end end
        if #free == 0 then
            -- a long flight over one land: borrow from the rest of the world
            for _, k in ipairs(order) do
                for _, tpl in ipairs(C[k].holes) do if not used[tpl.key] then free[#free + 1] = tpl end end
            end
        end
        local tpl = free[rng.int(1, #free)]
        used[tpl.key] = true
        return tpl
    end
    local firstHalf = (spec.holes == 1) and 0 or floor(spec.holes / 2 + 0.5)
    for i = 1, spec.holes do
        local theme = (i <= firstHalf) and t1 or t2
        local tpl = draw(theme)
        holes[i] = Putt.BuildHole(tpl, spec.seed * 977 + i * 31, rng.next() < 0.5)
        lands[i] = (i <= firstHalf) and (spec.fromZone or spec.from) or (spec.toZone or spec.to)
        par = par + holes[i].par
    end
    return { kind = "route", seed = spec.seed, holes = holes, par = par, name = Route.Name(spec), route = spec, lands = lands }
end

-- the route you're flying right now (nil on the ground), and the last one you flew
function Route.Flying()
    local fl = NS.db and NS.db.flight
    if fl and fl.from and UnitOnTaxi and UnitOnTaxi("player") then return Route.Spec(fl), fl end
    return nil
end
function Route.Last()
    local fl = NS.db and NS.db.lastFlight
    return fl and Route.Spec(fl) or nil
end

-- your log of routes: { [id] = { name=, holes=, best=, plays=, landed= } }
function Route.Log()
    local db = NS.db
    db.routes = db.routes or {}
    return db.routes
end

-- note a route in your flight log (on take-off, and whenever you finish its round)
function Route.Note(spec, flew)
    if not spec then return nil end
    local log = Route.Log()
    local e = log[spec.id] or { plays = 0 }
    log[spec.id] = e
    e.name, e.holes, e.fl = Route.Name(spec), spec.holes, spec.fl
    e.last = time and time() or 0
    if flew then e.flights = (e.flights or 0) + 1 end
    return e
end

-- your flown routes, most recent first: { { spec=, e= }, ... }
function Route.List(limit)
    local out = {}
    for _, e in pairs(Route.Log()) do
        local spec = e.fl and Route.Spec(e.fl)
        if spec then out[#out + 1] = { spec = spec, e = e } end
    end
    table.sort(out, function(x, y)
        if (x.e.last or 0) ~= (y.e.last or 0) then return (x.e.last or 0) > (y.e.last or 0) end
        return x.spec.key < y.spec.key
    end)
    while limit and #out > limit do out[#out] = nil end
    return out
end
