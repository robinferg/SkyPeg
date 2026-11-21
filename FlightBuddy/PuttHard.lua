-- Flight Buddy :: PuttHard.lua
-- What makes each painted hole hard, layered on top of what its picture already holds.
-- 1. Each land's signature hazard: Stormwind mages throw fireballs, ghouls lob slime, orc war drums
--    send shockwaves, wisps circle, tide pools flood, gnome blowers push and dust devils spin.
-- 2. Walls and posts (the generated block at the end): stubs of wall off the curbs that make
--    chicanes and close the straight lines, posts that guard the cup, and each hole's par.
--    Placed by golf/harden/design.lua against simulated shots, then played by test bots for par.
-- Positions are in hole units (480 x 560), for the hole as painted; mirrored holes flip them.
local ADDON, NS = ...
local C = NS.PuttCourses
if not C then return end

local function Add(course, key, more)
    local c = C[course]
    if not c then return end
    for _, h in ipairs(c.holes) do
        if h.key == key then
            h.extra = h.extra or {}
            for k, v in pairs(more) do
                if k == "tip" or k == "par" or k == "curb" then h[k] = v
                elseif type(v) ~= "table" then h.extra[k] = v
                else
                    h.extra[k] = h.extra[k] or {}
                    for _, item in ipairs(v) do table.insert(h.extra[k], item) end
                end
            end
        end
    end
end
-- Mulgore: a dust devil wanders across the middle of Camp Narache and spins a slow ball off line
Add("mulgore", "mg_mu_narache", { actors = { { kind = "whirl", x1 = 196, y1 = 262, x2 = 286, y2 = 262, r = 26, spd = 0.7 } },
    tip = "A dust devil drifts across the camp. Wait for it to clear, or hit firmly past it." })
-- Elwynn: Stormwind mages guard the lanes, and a Duskwood ghoul lobs slime
Add("human", "mg_goldshire", { actors = { { kind = "mage", x = 323, y = 251, range = 100, fig = "mage", figH = 48 } },
    tip = "A mage stands by the bend and throws fireballs at slow balls. Roll past him quickly." })
Add("human", "mg_canals", { actors = { { kind = "mage", x = 104, y = 182, range = 100, fig = "mage", figH = 48 } },
    tip = "A canal mage guards the last stretch. Fast balls slip past his fireballs." })
Add("human", "mg_darkshire", { actors = { { kind = "ghoul", x = 418, y = 374, targets = { { 397, 330 }, { 400, 295 }, { 369, 470 } }, period = 3.2, fig = "ghoul", figH = 46, r = 16 } },
    tip = "A ghoul lobs slime onto the path. Watch where it lands, then go." })
-- Tirisfal: a Scarlet sorcerer watches the monastery road
Add("undead", "mg_ti_scarlet", { actors = { { kind = "mage", x = 138, y = 192, range = 95, fig = "mage", figH = 48 } },
    tip = "A Scarlet sorcerer watches the first corner. Don't dawdle near him." })
-- Durotar: war drums and dust devils
Add("orc", "mg_valley_of_trials", { actors = { { kind = "drum", x = 108, y = 318, reach = 120, period = 2.8, push = 150, fig = "grommash", figH = 48 } },
    tip = "Every drum beat sends out a shockwave. Putt between the beats." })
Add("orc", "mg_razormane_grounds", { actors = { { kind = "whirl", x1 = 308, y1 = 284, x2 = 392, y2 = 280, r = 26, spd = 0.7 } },
    tip = "A dust devil drifts across the grounds. Wait for it to clear, or hit firmly past it." })
-- Teldrassil: wisps circle the glades
Add("nelf", "mg_moonwell_grove", { movers = { { kind = "orbit", cx = 343, cy = 298, rad = 30, n = 2, spd = 1.2 } },
    tip = "Wisps circle the lane to the moonwell. Time your putt through the gap." })
-- Echo Isles: tide pools and a witch doctor
Add("troll", "mg_senjin_village", { actors = { { kind = "pool", x = 99, y = 258, r = 26, period = 4.6 } },
    tip = "A tide pool floods the first lane. Cross at low water." })
Add("troll", "mg_darkspear_strand", { actors = { { kind = "pool", x = 190, y = 330, r = 28, period = 4.8 }, { kind = "pool", x = 292, y = 204, r = 28, period = 4.8, phase = 2.4 } },
    tip = "Two tide pools rise and fall on the strand. Cross each at low water." })
Add("troll", "mg_voodoo_grove", { actors = { { kind = "ghoul", fig = "troll", x = 40, y = 243, targets = { { 120, 340 }, { 104, 260 }, { 114, 208 } }, period = 3.2, color = "voodoo", figH = 46, r = 16 } },
    tip = "The witch doctor hurls hexed goo onto the path. Read where it's headed." })
-- Gnomeregan: a wall blower in Tinker Town
Add("gnome", "mg_tinker_town", { fans = { { x = 176, y = 300, dx = -1, dy = 0, len = 128, width = 70, force = 90, wall = true } },
    tip = "The wall blower pushes everything left. Aim a little into the wind." })

-- Walls, posts and pars. Generated: edit golf/harden/ and recompile, not this block.
Add("human", "mg_canals", { contours = { { x = 417, y = 55, r = 27, a = -115, cup = true } }, tip = "A canal mage guards the last stretch. The cup lies in a punchbowl: get the ball over the lip and the slope gathers it to the hole.", par = 4 })
Add("human", "mg_darkshire", { contours = { { x = 397, y = 436, r = 24, a = 175 } }, tip = "A ghoul lobs slime onto the path. Over the rise with pace, or round it: a weak putt rolls back.", par = 4 })
Add("human", "mg_goldshire", { contours = { { x = 287, y = 168, r = 29, a = 175 }, { x = 154, y = 378, r = 31, a = 85 } }, tip = "A mage stands by the bend and throws fireballs at slow balls. Over the rise with pace, or round it: a weak putt rolls back.", par = 3 })
Add("human", "mg_lakeshire", { contours = { { x = 239, y = 80, r = 34, a = 150, flat = 0.44, cup = true }, { x = 249, y = 338, r = 38, a = 175 } }, tip = "Gnolls patrol the bridge between the two crates. Mind the rise in the lane: over it with pace, or round it. The cup sits on a crown: judge the pace.", par = 2 })
Add("human", "mg_northshire", { walls = { { 88, 301, 150, 302 } }, curb = { 0.85, 0.73, 0.64 }, contours = { { x = 348, y = 92, r = 32, a = 150, flat = 0.47, cup = true } }, movers = { { kind = "patrol", faction = "kobold", r = 12, x1 = 248, y1 = 65, x2 = 280, y2 = 143, spd = { 0.5, 0.7 } } }, tip = "Round the abbey fountain and into the corner. A wall closes half the lane: go round its open end, or bank off the far curb. The cup sits on a crown: judge the pace.", par = 3 })
Add("human", "mg_westfall", { bumpers = { { 182, 457, 11 } }, style = "human", contours = { { x = 405, y = 97, r = 33, a = 150, flat = 0.46, cup = true } }, movers = { { kind = "patrol", faction = "golem", r = 12, x1 = 57, y1 = 171, x2 = 87, y2 = 245, spd = { 0.5, 0.7 } } }, tip = "All the way round the old mill. A post stands in the lane: pick a side. The cup sits on a crown: judge the pace.", par = 2 })
Add("dwarf", "mg_coldridge_valley", { walls = { { 271, 414, 211, 414 } }, curb = { 0.71, 0.70, 0.76 }, movers = { { kind = "patrol", faction = "ram", r = 12, x1 = 168, y1 = 170, x2 = 316, y2 = 182, spd = { 0.5, 0.7 } } }, tip = "The frozen pond barely slows a ball. A wall stands across the middle of the lane: bank round either end.", par = 2 })
Add("dwarf", "mg_frostmane_hold", { contours = { { x = 287, y = 428, r = 30, a = 175 }, { x = 227, y = 490, r = 30, a = 175 }, { x = 94, y = 246, r = 44, a = 85 } }, movers = { { kind = "patrol", faction = "raider", r = 12, x1 = 96, y1 = 95, x2 = 148, y2 = 219, spd = { 0.5, 0.7 } } }, tip = "The long way winds round the troll camp. Aim through the pass between the two rises: the valley gathers a good putt and turns a poor one away.", par = 3 })
Add("dwarf", "mg_gates_of_ironforge", { walls = { { 269, 190, 209, 190 } }, curb = { 0.70, 0.66, 0.68 }, tip = "The great gate opens and closes on a slow beat. A wall stands across the middle of the lane: bank round either end.", par = 3 })
Add("dwarf", "mg_iceflow_lake", { bumpers = { { 238, 464, 9 }, { 240, 122, 9 } }, style = "dwarf", tip = "Roll onto the stone pad and the dwarven mortar fires your ball across the lake, the way it was rolling. A post stands in the lane: pick a side.", par = 3 })
Add("dwarf", "mg_kharanos", { walls = { { 322, 212, 316, 146 } }, curb = { 0.70, 0.68, 0.73 }, contours = { { x = 174, y = 370, r = 28, a = 175 }, { x = 92, y = 370, r = 28, a = 175 } }, tip = "Round the corner by the Thunderbrew kegs. Aim through the pass between the two rises: the valley gathers a good putt and turns a poor one away.", par = 2 })
Add("dwarf", "mg_the_great_forge", { contours = { { x = 344, y = 189, r = 38, a = 175 } }, movers = { { kind = "patrol", faction = "dwarf", r = 12, x1 = 309, y1 = 272, x2 = 431, y2 = 222, spd = { 0.5, 0.7 } } }, tip = "Left or right around the forge, it is the same distance. Over the rise with pace, or round it: a weak putt rolls back.", par = 2 })
Add("gnome", "mg_assembly_line", { contours = { { x = 78, y = 78, r = 28, a = 130 }, { x = 206, y = 490, r = 38, a = 175 } }, movers = { { kind = "patrol", faction = "gnome", r = 12, x1 = 290, y1 = 253, x2 = 423, y2 = 198, spd = { 0.5, 0.7 } } }, tip = "Two big bends. Land the ball on the conveyor belt on the first one and it carries you up and round. Over the rise with pace, or round it: a weak putt rolls back.", par = 3 })
Add("gnome", "mg_deeprun_tram", { contours = { { x = 363, y = 113, r = 43, a = 150, flat = 0.35, cup = true } }, tip = "The only way across the track is the tram car. The cup sits on a crown: too soft and the ball rolls back off, too firm and it runs over the far side.", par = 2 })
Add("gnome", "mg_gnomeregan_core", { walls = { { 65, 298, 121, 286 } }, curb = { 0.66, 0.61, 0.62 }, contours = { { x = 277, y = 298, r = 46, a = 150, flat = 0.33, cup = true } }, tip = "A long hook round the reactor and back in to its heart. A wall closes half the lane: go round its open end, or bank off the far curb. The cup sits on a crown: judge the pace.", par = 3 })
Add("gnome", "mg_radiation_labs", { contours = { { x = 150, y = 85, r = 44, a = -115, cup = true }, { x = 202, y = 282, r = 36, a = 85 } }, movers = { { kind = "patrol", faction = "gnome", r = 12, x1 = 333, y1 = 214, x2 = 373, y2 = 116, spd = { 0.5, 0.7 } } }, tip = "A long S with one pool of green sludge in the middle bend. The green rolls here: putts break down the slope, more as they slow. The cup lies in a punchbowl.", par = 4 })
Add("gnome", "mg_steam_works", { contours = { { x = 326, y = 96, r = 30, a = 150, flat = 0.50, cup = true } }, movers = { { kind = "patrol", faction = "gnome", r = 12, x1 = 75, y1 = 76, x2 = 119, y2 = 183, spd = { 0.5, 0.7 } } }, tip = "Roll onto the striped launch plate and it throws the ball over the pipes, the way it was rolling. The cup sits on a crown: too soft and the ball rolls back off, too firm and it runs over the far side.", par = 2 })
Add("gnome", "mg_tinker_town", { walls = { { 138, 326, 84, 326 } }, curb = { 0.69, 0.64, 0.66 }, contours = { { x = 364, y = 106, r = 44, a = -115, cup = true }, { x = 193, y = 110, r = 38, a = 175 } }, tip = "The wall blower pushes everything left. A wall stands across the middle of the lane: bank round either end. The cup lies in a punchbowl.", par = 3 })
Add("nelf", "mg_banethil_barrow", { bumpers = { { 89, 247, 11 } }, style = "nelf", contours = { { x = 402, y = 411, r = 46, a = 150, flat = 0.33, cup = true } }, movers = { { kind = "orbit", cx = 296, cy = 160, rad = 28, n = 2, spd = 1.1 } }, tip = "The long way is over the top of the barrow. A post stands in the lane: pick a side. The cup sits on a crown: judge the pace.", par = 2 })
Add("nelf", "mg_dolanaar", { contours = { { x = 281, y = 93, r = 44, a = -115, cup = true }, { x = 161, y = 316, r = 35, a = -130 } }, tip = "Three lanes and two wide bends. A slow ball is drawn into the hollow, so hit firmly past it. The cup lies in a punchbowl.", par = 3 })
Add("nelf", "mg_moonwell_grove", { walls = { { 426, 366, 360, 366 } }, curb = { 0.77, 0.72, 0.83 }, contours = { { x = 125, y = 92, r = 46, a = 150, flat = 0.33, cup = true }, { x = 344, y = 189, r = 38, a = 175 } }, tip = "Wisps circle the lane to the moonwell. A wall closes half the lane: go round its open end, or bank off the far curb. The cup sits on a crown: judge the pace.", par = 3 })
Add("nelf", "mg_ruttheran_village", { contours = { { x = 243, y = 87, r = 30, a = 150, flat = 0.50, cup = true } }, movers = { { kind = "patrol", faction = "wolf", r = 12, x1 = 280, y1 = 179, x2 = 332, y2 = 53, spd = { 0.5, 0.7 } } }, tip = "No bridge here. Roll into the portal by the dock and the ball steps out on the far shore. The cup is up on a crown. Judge the pace: a weak putt comes back down to you.", par = 2 })
Add("nelf", "mg_shadowglen", { contours = { { x = 268, y = 69, r = 44, a = -115, cup = true }, { x = 234, y = 183, r = 30, a = 175 } }, movers = { { kind = "orbit", cx = 144, cy = 264, rad = 28, n = 2, spd = 1.1 } }, tip = "Three bouncy mushrooms sit in the middle. Mind the rise in the lane: over it with pace, or round it. The cup lies in a punchbowl.", par = 3 })
Add("nelf", "mg_temple_of_the_moon", { contours = { { x = 240, y = 101, r = 44, a = -115, cup = true }, { x = 348, y = 424, r = 36, a = 85 } }, movers = { { kind = "orbit", cx = 376, cy = 352, rad = 28, n = 2, spd = 1.1 } }, tip = "Two marble rails make a zigzag: right, then left, then up the neck to the cup. The broad swell bends every putt across it, so aim uphill of your line. The cup lies in a punchbowl.", par = 4 })
Add("orc", "mg_burning_blade_coven", { walls = { { 368, 298, 400, 298 } }, curb = { 0.65, 0.55, 0.54 }, contours = { { x = 375, y = 426, r = 46, a = 150, flat = 0.33, cup = true } }, tip = "Lava has spilled onto the inside of the bend: cut the corner for the coin and you risk a scorched ball. A wall stands across the middle of the lane: bank round either end.", par = 3 })
Add("orc", "mg_drygulch_ravine", { contours = { { x = 399, y = 63, r = 31, a = 130 }, { x = 175, y = 272, r = 38, a = 175 } }, tip = "A winding ravine with two big bends. Mind the rise in the lane: over it with pace, or round it. Be bold at the cup: the rise behind it rolls a long putt back.", par = 3 })
Add("orc", "mg_gates_of_orgrimmar", { contours = { { x = 135, y = 130, r = 44, a = -115, cup = true } }, movers = { { kind = "patrol", faction = "orc", r = 12, x1 = 238, y1 = 196, x2 = 227, y2 = 72, spd = { 0.5, 0.7 } } }, tip = "Roll onto the goblin cannon and it fires the ball over the spiked trench, the way it was rolling. The cup is at the bottom of a punchbowl. Anything that reaches the bowl rolls in towards it.", par = 3 })
Add("orc", "mg_razor_hill", { bumpers = { { 358, 218, 11 } }, style = "orc", contours = { { x = 124, y = 102, r = 44, a = -115, cup = true } }, tip = "A kodo plods back and forth across the corner. A post stands in the lane: pick a side. The cup lies in a punchbowl.", par = 2 })
Add("orc", "mg_razormane_grounds", { contours = { { x = 153, y = 83, r = 41, a = 150, flat = 0.37, cup = true }, { x = 348, y = 209, r = 32, a = -130 }, { x = 230, y = 450, r = 38, a = 175 } }, tip = "A dust devil drifts across the grounds. Mind the rise in the lane: over it with pace, or round it. The cup sits on a crown: judge the pace.", par = 3 })
Add("orc", "mg_valley_of_trials", { contours = { { x = 213, y = 80, r = 46, a = 150, flat = 0.33, cup = true }, { x = 260, y = 339, r = 38, a = 175 } }, tip = "Every drum beat sends out a shockwave. Over the rise with pace, or round it: a weak putt rolls back. The cup sits on a crown: judge the pace.", par = 2 })
Add("troll", "mg_darkspear_strand", { contours = { { x = 258, y = 68, r = 46, a = 150, flat = 0.33, cup = true }, { x = 248, y = 397, r = 38, a = 175 } }, tip = "Two tide pools rise and fall on the strand. Mind the rise in the lane: over it with pace, or round it. The cup sits on a crown: judge the pace.", par = 2 })
Add("troll", "mg_echo_isles_shore", { contours = { { x = 148, y = 54, r = 46, a = 150, flat = 0.33, cup = true }, { x = 344, y = 329, r = 38, a = 175 }, { x = 362, y = 190, r = 56, a = 85 } }, tip = "One long curve round the bay. A murloc patrols the inside line: get too close and it grabs the ball and runs off with it. Mind the rise in the lane: over it with pace, or round it.", par = 2 })
Add("troll", "mg_senjin_village", { walls = { { 158, 198, 99, 198 } }, curb = { 0.72, 0.70, 0.68 }, contours = { { x = 368, y = 95, r = 46, a = 150, flat = 0.33, cup = true } }, tip = "A tide pool floods the first lane. A wall closes half the lane: go round its open end, or bank off the far curb. The cup sits on a crown: judge the pace.", par = 3 })
Add("troll", "mg_tide_pools", { contours = { { x = 125, y = 75, r = 46, a = 150, flat = 0.33, cup = true }, { x = 355, y = 350, r = 38, a = 175 } }, tip = "Out along the rope bridge and back. Mind the rise in the lane: over it with pace, or round it. The cup sits on a crown: judge the pace.", par = 3 })
Add("troll", "mg_voodoo_grove", { bumpers = { { 112, 298, 11 } }, style = "troll", contours = { { x = 320, y = 78, r = 37, a = -115, cup = true } }, tip = "The witch doctor hurls hexed goo onto the path. A post stands in the lane: pick a side. The cup lies in a punchbowl.", par = 2 })
Add("troll", "mg_zalazanes_fall", { walls = { { 334, 403, 305, 401 } }, curb = { 0.76, 0.64, 0.60 }, contours = { { x = 125, y = 280, r = 46, a = 150, flat = 0.33, cup = true } }, movers = { { kind = "patrol", faction = "raider", r = 12, x1 = 344, y1 = 177, x2 = 391, y2 = 65, spd = { 0.5, 0.7 } } }, tip = "The short line round the bend runs right over a hearthstone rune. A wall stands across the middle of the lane: bank round either end. The cup sits on a crown: judge the pace.", par = 3 })
Add("undead", "mg_ti_agamand", { bumpers = { { 341, 102, 11 } }, style = "undead", contours = { { x = 156, y = 182, r = 28, a = 150, flat = 0.54, cup = true } }, movers = { { kind = "patrol", faction = "ghoul", r = 12, x1 = 305, y1 = 312, x2 = 367, y2 = 328, spd = { 0.5, 0.7 } } }, tip = "All the way round the haunted mill. A post stands in the lane: pick a side. The cup sits on a crown: judge the pace.", par = 3 })
Add("undead", "mg_ti_brill", { contours = { { x = 101, y = 314, r = 37, a = -115, cup = true }, { x = 361, y = 322, r = 28, a = 175 } }, tip = "Up past the inn, over the top and back down to the cup. Over the rise with pace, or round it: a weak putt rolls back. The cup lies in a punchbowl.", par = 3 })
Add("undead", "mg_ti_deathknell", { contours = { { x = 103, y = 78, r = 27, a = 150, flat = 0.56, cup = true }, { x = 303, y = 344, r = 25, a = 175 } }, tip = "A long S through the graveyard. Mind the rise in the lane: over it with pace, or round it. The cup sits on a crown: judge the pace.", par = 3 })
Add("undead", "mg_ti_plague", { walls = { { 166, 283, 223, 312 } }, curb = { 0.67, 0.60, 0.59 }, contours = { { x = 113, y = 80, r = 30, a = -115, cup = true } }, movers = { { kind = "patrol", faction = "ghoul", r = 12, x1 = 252, y1 = 267, x2 = 391, y2 = 210, spd = { 0.5, 0.7 } } }, tip = "The cauldron of plague slime on the left grabs a ball and holds it. A wall closes half the lane: go round its open end, or bank off the far curb. The cup lies in a punchbowl.", par = 3 })
Add("undead", "mg_ti_scarlet", { contours = { { x = 324, y = 401, r = 31, a = -115, cup = true } }, tip = "A Scarlet sorcerer watches the first corner. A punchbowl green: once over the rim, let the slope do the work.", par = 4 })
Add("undead", "mg_ti_undercity", { tip = "Roll onto the elevator plate in the ruined throne room and the ball rides down into the Undercity.", par = 4 })
Add("mulgore", "mg_mu_bloodhoof", { walls = { { 48, 374, 113, 374 } }, curb = { 0.73, 0.67, 0.65 }, contours = { { x = 113, y = 262, r = 38, a = 175 } }, tip = "The air totem in the corner blows a gust down the first leg, a few seconds on and a few off. A wall closes half the lane: go round its open end, or bank off the far curb.", par = 3 })
Add("mulgore", "mg_mu_mine", { contours = { { x = 353, y = 123, r = 37, a = 150, flat = 0.40, cup = true } }, tip = "The mine cart is the only way over the track. The cup sits on a crown: too soft and the ball rolls back off, too firm and it runs over the far side.", par = 2 })
Add("mulgore", "mg_mu_narache", { walls = { { 324, 203, 284, 202 }, { 176, 201, 216, 201 } }, curb = { 0.75, 0.66, 0.59 }, contours = { { x = 222, y = 426, r = 56, a = 85 } }, tip = "A dust devil drifts across the camp. Thread the gate for the straight line to the cup.", par = 2 })
Add("mulgore", "mg_mu_redcloud", { walls = { { 257, 479, 283, 419 } }, curb = { 0.73, 0.68, 0.61 }, contours = { { x = 100, y = 83, r = 36, a = -115, cup = true } }, movers = { { kind = "patrol", faction = "kodo", r = 12, x1 = 253, y1 = 212, x2 = 288, y2 = 125, spd = { 0.5, 0.7 } } }, tip = "The mesa rises in the middle of the S. A wall closes half the lane: go round its open end, or bank off the far curb. The cup lies in a punchbowl.", par = 3 })
Add("mulgore", "mg_mu_stonebull", { walls = { { 178, 69, 199, 110 } }, curb = { 0.73, 0.67, 0.64 }, contours = { { x = 205, y = 449, r = 38, a = 175 } }, tip = "One long sweep round the lake. A wall closes half the lane: go round its open end, or bank off the far curb.", par = 3 })
Add("mulgore", "mg_mu_thunderbluff", { movers = { { kind = "patrol", faction = "harpy", r = 12, x1 = 142, y1 = 109, x2 = 179, y2 = 198, spd = { 0.5, 0.7 } } }, tip = "Roll onto the wooden lift at the foot of the bluff and the ball rides up to the city on top. A harpy walks back and forth across the lane. Wait for the gap.", par = 3 })
Add("arathi", "mg_binding", { contours = { { x = 197, y = 94, r = 26, a = 130 }, { x = 381, y = 192, r = 28, a = 175 } }, movers = { { kind = "patrol", faction = "elemental", r = 12, x1 = 75, y1 = 169, x2 = 103, y2 = 237, spd = { 0.5, 0.7 } } }, tip = "Left or right around the great stone, it's the same distance. Over the rise with pace, or round it: a weak putt rolls back. A rise behind the cup brings a long putt back, so be bold.", par = 3 })
Add("arathi", "mg_farm", { contours = { { x = 247, y = 146, r = 34, a = 85 } }, movers = { { kind = "patrol", faction = "sheep", r = 12, x1 = 181, y1 = 307, x2 = 267, y2 = 285, spd = { 0.5, 0.7 } } }, tip = "Two bends and a hay bale in each. The green rolls here: putts break down the slope, more as they slow.", par = 3 })
Add("arathi", "mg_southshore", { bumpers = { { 387, 342, 11 } }, style = "arathi", tip = "Round the well and along the top, where a Horde raider prowls. A post stands in the lane: pick a side.", par = 2 })
Add("arathi", "mg_stromgarde", { bumpers = { { 122, 274, 11 } }, style = "arathi", contours = { { x = 389, y = 398, r = 28, a = -115, cup = true } }, tip = "One wide arch through the ruins. A post stands in the lane: pick a side. The cup lies in a punchbowl.", par = 3 })
Add("arathi", "mg_tarren", { contours = { { x = 222, y = 440, r = 38, a = 175 } }, tip = "Climb the bridge, then choose: the short line runs through river mud that stops the ball dead, the dry line hugs the outer curb. Mind the rise in the lane: over it with pace, or round it.", par = 2 })
Add("arathi", "mg_thoradin", { walls = { { 268, 195, 208, 194 } }, curb = { 0.83, 0.64, 0.54 }, tip = "Thread the gap in the wall, or hit the ramp hard and fly over it. A wall stands across the middle of the lane: bank round either end.", par = 3 })
