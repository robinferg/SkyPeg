-- Flight Buddy :: Levels.lua
-- Rune Breaker boards: sixteen hand-designed layouts, one per painted stage, themed to the place
-- and ordered from gentle to hard. Built from round runes, rune-stone bricks (straight and curved),
-- and moving parts (orbits, slides, spinners). Where the 25 fire crystals land is weighted per board,
-- so difficulty is designed rather than random. Tuned with luatest/rbsim.lua.
local ADDON, NS = ...

local Levels = {}
NS.Levels = Levels

local cos, sin, pi, floor, sqrt, min, max, abs = math.cos, math.sin, math.pi, math.floor, math.sqrt, math.min, math.max, math.abs

local THEMES = {
    { name = "Crossroads Sunset",   art = "crossroads", dim = 0.28, top = { 0.20, 0.10, 0.16 }, bottom = { 0.55, 0.26, 0.12 } },
    { name = "Thunder Bluff Spires", art = "thunderbluff", dim = 0.28, top = { 0.08, 0.13, 0.25 }, bottom = { 0.40, 0.30, 0.22 } },
    { name = "Stranglethorn Vines", art = "stranglethorn", dim = 0.25, top = { 0.03, 0.15, 0.10 }, bottom = { 0.10, 0.36, 0.20 } },
    { name = "Twisting Nether",     art = "nether", dim = 0.35, top = { 0.12, 0.03, 0.20 }, bottom = { 0.32, 0.08, 0.40 } },
    { name = "Dalaran Orbits",      art = "dalaran", dim = 0.25, top = { 0.10, 0.06, 0.24 }, bottom = { 0.30, 0.20, 0.52 } },
    { name = "Ironforge Lattice",   art = "ironforge", dim = 0.25, top = { 0.10, 0.08, 0.07 }, bottom = { 0.36, 0.22, 0.10 } },
    { name = "Blackrock Funnel",    art = "blackrock", dim = 0.32, top = { 0.12, 0.04, 0.03 }, bottom = { 0.45, 0.10, 0.04 } },
    { name = "Moonglade Bloom",     art = "moonglade", dim = 0.2, top = { 0.04, 0.08, 0.20 }, bottom = { 0.14, 0.34, 0.42 } },
}
Levels.THEMES = THEMES

-- Sixteen stages (painted Feud & Fellowship scenes), then the run loops harder.
-- org = fire crystals on the board.
local STAGES = {
    { name = "Goldshire Camp",        bg = "pbg_camp_tent",     org = 15, easy = true },
    { name = "Elwynn Keep",           bg = "pbg_camp_castle",   org = 21, easy = true },
    { name = "Dun Morogh Peaks",      bg = "pbg_frost_peaks",   org = 12, easy = true },
    { name = "Frostwhisper Falls",    bg = "pbg_frost_falls",   org = 22 },
    { name = "Hall of Runes",         bg = "pbg_forge_hall",    org = 21 },
    { name = "The Great Forge",       bg = "pbg_forge_anvil",   org = 20 },
    { name = "Thousand Needles",      bg = "pbg_steppe_mesas",  org = 20 },
    { name = "Field of Bones",        bg = "pbg_steppe_bones",  org = 25 },
    { name = "Lakeshire Meadow",      bg = "pbg_camp_meadow",   org = 22 },
    { name = "Redridge Rise",         bg = "pbg_camp_ridge",    org = 19 },
    { name = "Alterac Pass",          bg = "pbg_frost_pass",    org = 17 },
    { name = "Everlook Pines",        bg = "pbg_frost_pines",   org = 25 },
    { name = "Shadowforge Gate",      bg = "pbg_forge_banner",  org = 20 },
    { name = "Halls of Molten Stone", bg = "pbg_forge_pillars", org = 20 },
    { name = "The Crossroads",        bg = "pbg_steppe_road",   org = 20 },
    { name = "Desolace Sunset",       bg = "pbg_steppe_sunset", org = 21 },
}
for _, s in ipairs(STAGES) do
    s.dim = 0.12
    s.top, s.bottom = { 0.10, 0.10, 0.16 }, { 0.30, 0.26, 0.14 }
end
Levels.STAGES = STAGES

local W, PEG_R
local TOP, BOTTOM = 112, 505
local BRICK_R = 6            -- half-thickness of a brick

---------------------------------------------------------------------------
-- Board-building kit. Every piece takes an optional weight w: how likely it
-- is to be chosen as a fire crystal (1 = normal, 3 = a "hot" hard-to-reach spot,
-- 0.3 = rarely). Layouts add bricks first, then runes (runes overlapping a brick are skipped).
---------------------------------------------------------------------------
local function Kit(pegs, rng, cycle)
    local K = {}
    local minD = PEG_R * 2 + 3

    local function segDist(px, py, b)
        local br = b.brick
        local ex, ey = cos(br.ang), sin(br.ang)
        local t = max(-br.len, min(br.len, (px - b.x) * ex + (py - b.y) * ey))
        local qx, qy = b.x + ex * t, b.y + ey * t
        return sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
    end
    local function free(x, y)
        for _, p in ipairs(pegs) do
            if not p.orbit and not p.slide then
                if p.brick then
                    if segDist(x, y, p) < PEG_R + BRICK_R + 3 then return false end
                else
                    local dx, dy = p.x - x, p.y - y
                    if dx * dx + dy * dy < minD * minD then return false end
                end
            end
        end
        return true
    end
    local function inBoard(x, y, pad)
        pad = pad or 0
        return x >= PEG_R + 6 - pad and x <= W - PEG_R - 6 + pad and y >= TOP and y <= BOTTOM
    end
    local speedUp = 1 + cycle * 0.15

    function K.peg(x, y, w)
        if not inBoard(x, y) or not free(x, y) then return end
        pegs[#pegs + 1] = { x = x, y = y, r = PEG_R, kind = "blue", alive = true, lit = false, w = w or 1 }
        return pegs[#pegs]
    end
    function K.line(x1, y1, x2, y2, gap, w)
        local d = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local n = max(1, floor(d / gap + 0.5))
        for i = 0, n do K.peg(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n, w) end
    end
    function K.arc(cx, cy, r, a0, a1, gap, w)
        local n = max(1, floor(abs(a1 - a0) * r / gap + 0.5))
        for i = 0, n do local a = a0 + (a1 - a0) * i / n; K.peg(cx + cos(a) * r, cy + sin(a) * r, w) end
    end
    function K.ring(cx, cy, r, n, a0, w)
        for i = 0, n - 1 do local a = (a0 or 0) + i * 2 * pi / n; K.peg(cx + cos(a) * r, cy + sin(a) * r, w) end
    end
    -- a filled patch of staggered runes
    function K.field(x0, y0, x1, y1, dx, dy, w, holeFn)
        local row = 0
        local y = y0
        while y <= y1 do
            local x = x0 + (row % 2) * dx / 2
            while x <= x1 do
                if not holeFn or not holeFn(x, y) then K.peg(x, y, w) end
                x = x + dx
            end
            y = y + dy
            row = row + 1
        end
    end
    -- "bricks" are laid out as straight rows of runes (no solid tiles on the boards).
    local RUNE_GAP = PEG_R * 2 + 7
    local function offsets(len)
        local n = max(1, floor(2 * len / RUNE_GAP + 0.5))
        local t = {}
        for i = 0, n do t[#t + 1] = -len + 2 * len * i / n end
        return t
    end
    -- centre (x, y), half-length len, angle ang (radians, y down); spin turns the row round its centre
    function K.brick(x, y, len, ang, w, spin)
        ang = ang or 0
        if spin then
            for _, t in ipairs(offsets(len)) do
                if abs(t) < 1 then K.peg(x, y, w)
                else K.orbit(x, y, abs(t), ang + (t < 0 and pi or 0), spin, w) end
            end
            return
        end
        local ex, ey = cos(ang), sin(ang)
        for _, t in ipairs(offsets(len)) do K.peg(x + ex * t, y + ey * t, w) end
    end
    function K.brickLine(x1, y1, x2, y2, n, w)
        K.line(x1, y1, x2, y2, RUNE_GAP, w)
    end
    function K.brickArc(cx, cy, r, a0, a1, n, w)
        K.arc(cx, cy, r, a0, a1, RUNE_GAP, w)
    end
    -- moving parts
    function K.orbit(cx, cy, rad, a, spd, w)
        local x, y = cx + cos(a) * rad, cy + sin(a) * rad
        local p = { x = x, y = y, r = PEG_R, kind = "blue", alive = true, lit = false, w = w or 1,
                    orbit = { cx = cx, cy = cy, rad = rad, a = a, spd = spd * speedUp } }
        pegs[#pegs + 1] = p
        return p
    end
    function K.orbitRing(cx, cy, rad, n, spd, w, brickLen, a0)
        for i = 0, n - 1 do K.orbit(cx, cy, rad, (a0 or 0) + i * 2 * pi / n, spd, w) end
    end
    local function slide1(x1, y1, x2, y2, spd, phase, w)
        local k = 0.5 - 0.5 * cos(phase or 0)
        local p = { x = x1 + (x2 - x1) * k, y = y1 + (y2 - y1) * k, r = PEG_R, kind = "blue",
                    alive = true, lit = false, w = w or 1,
                    slide = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, t = phase or 0, spd = spd * speedUp } }
        pegs[#pegs + 1] = p
        return p
    end
    -- a slider; with brickLen it is a short row of runes moving together
    function K.slide(x1, y1, x2, y2, spd, phase, w, brickLen, ang)
        if not brickLen then return slide1(x1, y1, x2, y2, spd, phase, w) end
        local ex, ey = cos(ang or 0), sin(ang or 0)
        for _, t in ipairs(offsets(brickLen)) do
            slide1(x1 + ex * t, y1 + ey * t, x2 + ex * t, y2 + ey * t, spd, phase, w)
        end
    end
    function K.spinner(x, y, len, spd, arms, w)
        arms = arms or 1
        K.peg(x, y, w)
        for i = 0, arms - 1 do
            for _, t in ipairs(offsets(len)) do
                if abs(t) >= 1 then K.orbit(x, y, abs(t), i * pi / arms + (t < 0 and pi or 0), spd, w) end
            end
        end
    end
    K.rng = rng
    return K
end

---------------------------------------------------------------------------
-- The sixteen boards
---------------------------------------------------------------------------
local LAYOUTS = {}

-- 1. Goldshire Camp: two tents, a campfire and a lantern garland. Dense and friendly.
LAYOUTS[1] = function(K)
    K.arc(240, -120, 300, pi * 0.32, pi * 0.68, 34)                 -- lantern garland sagging across the top
    for _, cx in ipairs({ 130, 350 }) do                            -- the tents
        K.line(cx, 190, cx - 82, 330, 27); K.line(cx, 190, cx + 82, 330, 27)
        K.line(cx - 58, 330, cx + 58, 330, 29)
        K.line(cx, 222, cx, 300, 26)                                -- tent pole
    end
    K.ring(240, 405, 44, 10, 0.3)                                   -- the campfire
    K.peg(240, 405, 1.5)
    K.field(40, 455, 440, 495, 44, 38, 1, function(x) return abs(x - 240) < 50 end)  -- the meadow
    for _, p in ipairs({ { 240, 250 }, { 240, 290 }, { 60, 390 }, { 420, 390 }, { 165, 400 }, { 315, 400 } }) do K.peg(p[1], p[2]) end
end

-- 2. Elwynn Keep: the castle wall (bricks with crenels to drop through), towers and the keep.
LAYOUTS[2] = function(K)
    for i = 0, 6 do                                                 -- merlons along the wall top
        K.brick(66 + i * 58, 318, 16, 0, 0.8)
    end
    K.brickLine(40, 340, 440, 340, 10, 0.6, 30)                     -- the wall (wide crenels let the ball through)
    for _, x in ipairs({ 70, 410 }) do                              -- towers with peaked roofs
        K.line(x, 200, x, 300, 25)
        K.line(x - 30, 205, x, 170, 22); K.line(x, 170, x + 30, 205, 22)
    end
    K.line(185, 290, 185, 210, 26); K.line(295, 290, 295, 210, 26)  -- the keep
    K.line(185, 210, 295, 210, 27)
    K.line(240, 180, 240, 140, 20)                                  -- its banner pole
    K.field(150, 240, 330, 285, 36, 30, 1)
    K.field(60, 385, 420, 495, 46, 38, 1.3)                         -- the courtyard below: crystals hide here
end

-- 3. Dun Morogh Peaks: three peaks with snow-capped tops and open valleys.
LAYOUTS[3] = function(K)
    for _, pk in ipairs({ { 95, 200, 1 }, { 240, 160, 1.2 }, { 385, 215, 1 } }) do
        local x, y = pk[1], pk[2]
        K.brick(x - 14, y + 6, 15, -0.75, 0.5); K.brick(x + 14, y + 6, 15, 0.75, 0.5)  -- snowcaps
        K.line(x - 26, y + 26, x - 92, 470, 27, pk[3]); K.line(x + 26, y + 26, x + 92, 470, 27, pk[3])
        K.field(x - 40, y + 70, x + 40, 450, 34, 34, 0.9, function(px, py) return abs(px - x) > (py - y) * 0.4 end)
    end
    K.line(40, 140, 150, 130, 28, 0.6); K.line(330, 130, 440, 140, 28, 0.6)        -- drifting cloud lines
end

-- 4. Frostwhisper Falls: a rune waterfall, ice pools on either side, floes sliding along the bottom.
LAYOUTS[4] = function(K)
    for i = 0, 11 do                                                -- the falls
        local y = 140 + i * 30
        K.peg(222 + (i % 2) * 10, y, 1); K.peg(262 - (i % 2) * 10, y, 1)
    end
    K.brickArc(110, 250, 62, 0.15, pi - 0.15, 4, 0.5)               -- left ice pool
    K.brickArc(370, 300, 62, 0.15, pi - 0.15, 4, 0.5)               -- right ice pool
    K.field(70, 215, 150, 270, 30, 28, 1.3)                         -- runes resting in the pools
    K.field(330, 265, 410, 320, 30, 28, 1.3)
    K.field(40, 140, 180, 190, 40, 40, 1)                           -- spray
    K.field(300, 140, 440, 230, 40, 40, 1)
    K.field(40, 360, 180, 420, 40, 34, 1)
    K.slide(70, 455, 200, 455, 1.1, 0, 0.6, 24, 0)                  -- ice floes
    K.slide(410, 470, 280, 470, 1.1, 1.6, 0.6, 24, 0)
    K.field(40, 490, 440, 500, 60, 30, 0.8)
end

-- 5. Hall of Runes: a great rune circle whose outer ring of bricks slowly turns.
LAYOUTS[5] = function(K)
    local cx, cy = 240, 315
    K.orbitRing(cx, cy, 165, 10, 0.32, 0.6, 26, 0.3)                -- the turning ring
    K.ring(cx, cy, 120, 18, 0, 1.6)                                 -- inner circles of runes
    K.ring(cx, cy, 86, 13, 0.2, 1.8)
    K.ring(cx, cy, 54, 8, pi / 8, 3.2)
    K.line(cx, cy - 30, cx, cy + 30, 20, 3.5)                       -- the rune itself
    K.peg(cx - 22, cy - 18, 2.5); K.peg(cx + 22, cy - 18, 2.5)
    for _, c in ipairs({ { 50, 140 }, { 430, 140 }, { 50, 490 }, { 430, 490 } }) do K.ring(c[1], c[2], 22, 4, pi / 4, 0.7) end
    K.field(120, 140, 360, 150, 40, 30, 0.6)                        -- the hall\'s lintel
    K.field(150, 495, 330, 500, 40, 30, 1)
end

-- 6. The Great Forge: a brick anvil, a hammer that keeps swinging, sparks flying.
LAYOUTS[6] = function(K)
    K.brickLine(150, 300, 360, 300, 5, 0.7)                         -- the anvil's face
    K.brick(122, 292, 20, -0.25, 0.7)                               -- its horn
    K.line(200, 325, 215, 390, 22, 1.5); K.line(310, 325, 295, 390, 22, 1.5)  -- waist
    K.brickLine(160, 412, 350, 412, 4, 0.7)                         -- base
    K.field(175, 435, 335, 495, 38, 32, 2.4)                        -- under the anvil: hot crystals
    K.spinner(110, 190, 34, 1.6, 1, 0.6)                            -- the hammer
    K.ring(110, 190, 52, 9, 0, 1)
    for i = 0, 13 do                                                -- sparks spraying up and right
        local a = -0.25 - i * 0.16
        local r = 90 + (i % 3) * 32
        K.peg(255 + cos(a) * r + 70, 300 + sin(a) * r * 0.9, 1.2)
    end
    K.field(40, 360, 140, 495, 34, 34, 1)
    K.field(380, 360, 440, 495, 34, 34, 1)
end

-- 7. Thousand Needles: tall stone needles to pinball between.
LAYOUTS[7] = function(K)
    local xs = { 58, 122, 186, 250, 314, 378, 432 }
    local tops = { 260, 200, 300, 170, 280, 210, 300 }
    for i, x in ipairs(xs) do
        local y = tops[i]
        local n = floor((470 - y) / 60)
        for k = 0, n - 1 do K.brick(x, y + 30 + k * 62, 26, pi / 2, 0.4) end
        K.peg(x, y - 6, 1.6)                                        -- the needle's cap
    end
    for i = 1, #xs - 1 do                                           -- runes hanging in the gaps
        local mx = (xs[i] + xs[i + 1]) / 2
        local y0 = max(tops[i], tops[i + 1]) - 10
        for k = 0, 6 do K.peg(mx + ((k % 2) * 2 - 1) * 8, y0 + k * 34, 1.3) end
    end
    K.arc(240, 40, 130, pi * 0.2, pi * 0.8, 32, 0.8)
end

-- 8. Field of Bones: a fallen giant's ribcage and skull.
LAYOUTS[8] = function(K)
    K.line(60, 215, 340, 215, 28, 0.8)                              -- the spine
    for i = 0, 5 do                                                 -- ribs: curved bricks hanging off the spine
        local x = 80 + i * 50
        K.brickArc(x + 26, 215, 26, pi, pi * 0.5, 2, 0.5, 3)
        K.brickArc(x + 26, 300, 40, pi * 1.25, pi * 0.75, 2, 0.5, 3)
    end
    K.field(85, 245, 330, 320, 50, 36, 1.6)                         -- inside the ribcage: hot
    K.ring(395, 175, 42, 11, 0, 1)                                  -- the skull
    K.peg(380, 165, 1.4); K.peg(410, 165, 1.4)
    K.line(365, 222, 425, 222, 20, 1)                               -- jaw
    K.field(40, 380, 440, 495, 44, 38, 1.1)                         -- scattered bones
    K.brick(110, 400, 22, 0.4, 0.5); K.brick(360, 430, 22, -0.5, 0.5)
end

-- 9. Lakeshire Meadow: a stone bridge over the lake, lily pads drifting below.
LAYOUTS[9] = function(K)
    K.brickArc(240, 520, 215, pi * 1.13, pi * 1.87, 8, 0.6)         -- the bridge arch
    K.arc(240, 520, 245, pi * 1.12, pi * 1.88, 30, 1)               -- runes along the bridge
    K.field(40, 140, 440, 230, 40, 34, 1.1)                         -- the town on the hill
    for k = 0, 3 do                                                 -- lily pads
        local y = 420 + (k % 2) * 34
        K.slide(60 + k * 20, y, 420 - k * 20, y, 0.55 + k * 0.08, k * 1.3, 2.2)
    end
    K.field(150, 360, 330, 400, 36, 36, 1.4)                        -- under the arch
    K.line(30, 500, 30, 400, 34, 0.8); K.line(450, 500, 450, 400, 34, 0.8)   -- reeds
end

-- 10. Redridge Rise: zig-zag ridges and gnoll camps.
LAYOUTS[10] = function(K)
    K.brickLine(40, 190, 250, 240, 4, 0.5)                          -- ridges
    K.brickLine(440, 290, 230, 340, 4, 0.5)
    K.brickLine(40, 390, 250, 440, 4, 0.5)
    for _, c in ipairs({ { 340, 190, 1.2 }, { 120, 300, 2 }, { 360, 410, 2.4 }, { 210, 160, 1 } }) do  -- gnoll camps
        K.ring(c[1], c[2], 30, 7, 0, c[3])
        K.peg(c[1], c[2], c[3])
    end
    K.field(60, 470, 440, 495, 48, 30, 1.6)
    K.field(280, 135, 440, 150, 40, 30, 0.8)
    K.field(40, 250, 200, 280, 40, 30, 1.4)                         -- slopes between the ridges
    K.field(280, 380, 440, 400, 40, 30, 1.8)
    K.field(40, 135, 160, 160, 40, 30, 0.8)
end

-- 11. Alterac Pass: cliff walls narrowing to a pass, boulders sliding across it.
LAYOUTS[11] = function(K)
    K.brickLine(30, 200, 175, 410, 5, 0.4)                          -- the cliffs
    K.brickLine(450, 200, 305, 410, 5, 0.4)
    K.field(40, 250, 120, 495, 32, 34, 1.4, function(x, y) return x > 30 + (y - 200) * 0.69 - 18 end)   -- behind the cliffs
    K.field(360, 250, 440, 495, 32, 34, 1.4, function(x, y) return x < 450 - (y - 200) * 0.69 + 18 end)
    K.slide(150, 300, 330, 300, 0.9, 0, 2)                          -- boulders crossing the pass
    K.slide(330, 360, 150, 360, 0.9, 0, 2)
    K.slide(195, 430, 285, 430, 1.3, 0.8, 2.6)
    K.field(110, 140, 370, 230, 38, 34, 1)                          -- the snowfield above the pass
end

-- 12. Everlook Pines: three pines with brick trunks, snowflakes drifting round.
LAYOUTS[12] = function(K)
    for _, t in ipairs({ { 95, 190, 1.2 }, { 240, 160, 1.6 }, { 385, 200, 1.2 } }) do
        local x, y = t[1], t[2]
        for tier = 0, 3 do                                          -- tiers of branches
            local ty = y + tier * 52
            local hw = 22 + tier * 14
            K.line(x - hw, ty + 34, x, ty, 24, t[3]); K.line(x, ty, x + hw, ty + 34, 24, t[3])
        end
        K.brick(x, y + 250, 26, pi / 2, 0.4)                        -- trunk
    end
    K.orbitRing(165, 300, 26, 4, 1.2, 4.5)                          -- snowflakes
    K.orbitRing(315, 320, 26, 4, -1.2, 4.5)
    K.field(40, 470, 440, 495, 40, 30, 3)
end

-- 13. Shadowforge Gate: a portcullis of iron bars rising and falling. Time your shot.
LAYOUTS[13] = function(K)
    for i = 0, 6 do                                                 -- the portcullis bars
        local x = 75 + i * 55
        K.slide(x, 230, x, 300, 1.25, i * 0.9, 0.4, 34, pi / 2)
    end
    K.brickLine(40, 190, 440, 190, 8, 0.5, 26)                      -- the lintel, with gaps
    K.field(60, 140, 420, 165, 45, 30, 0.8)                         -- flames above the gate
    K.field(50, 370, 430, 495, 38, 34, 3.5)                         -- the hall beyond: crystals
    K.brick(120, 345, 30, 0, 0.5); K.brick(360, 345, 30, 0, 0.5)
end

-- 14. Halls of Molten Stone: three spinning bars inside rings of runes.
LAYOUTS[14] = function(K)
    for _, s in ipairs({ { 130, 230, 1.5 }, { 350, 230, -1.5 }, { 240, 390, 1.9 } }) do
        K.spinner(s[1], s[2], 30, s[3], 2, 0.5)
        K.ring(s[1], s[2], 58, 13, 0, 3.2)
    end
    K.field(40, 140, 440, 165, 44, 30, 0.8)
    for _, x in ipairs({ 40, 440 }) do K.line(x, 300, x, 495, 32, 1) end      -- lava pillars
    K.field(80, 470, 400, 495, 46, 30, 1)
end

-- 15. The Crossroads: crossed roads of bricks, a spinning signpost, camps in the quadrants.
LAYOUTS[15] = function(K)
    K.brickLine(40, 150, 200, 290, 4, 0.5); K.brickLine(440, 150, 280, 290, 4, 0.5)
    K.brickLine(200, 350, 40, 490, 4, 0.5); K.brickLine(280, 350, 440, 490, 4, 0.5)
    K.spinner(240, 320, 36, 1.3, 1, 0.6)                            -- the signpost
    K.ring(240, 320, 60, 12, 0, 4.2)
    K.field(180, 130, 300, 230, 34, 32, 1)                          -- north camp
    K.field(40, 270, 120, 380, 34, 32, 1.6)                         -- west
    K.field(360, 270, 440, 380, 34, 32, 1.6)                        -- east
    K.field(170, 420, 310, 495, 36, 32, 4.2)                          -- south
end

-- 16. Desolace Sunset: the finale. A sun of crystals behind a turning ring, mesas with shelves.
LAYOUTS[16] = function(K)
    local cx, cy = 240, 250
    K.orbitRing(cx, cy, 82, 9, 0.8, 0.6, 22)                        -- the turning ring guarding the sun
    K.ring(cx, cy, 48, 8, 0, 7)                                     -- the sun: hot crystals
    K.peg(cx, cy, 7)
    K.brickLine(40, 380, 170, 380, 3, 0.4); K.brickLine(310, 380, 440, 380, 3, 0.4)  -- mesa shelves
    K.field(50, 405, 160, 495, 34, 32, 4.5)                         -- under the mesas
    K.field(320, 405, 430, 495, 34, 32, 4.5)
    K.slide(190, 450, 290, 450, 1.0, 0, 1.4, 26, 0)                 -- a drifting tumbleweed shelf
    K.field(40, 140, 130, 340, 36, 40, 0.8)
    K.field(350, 140, 440, 340, 36, 40, 0.8)
    K.arc(cx, cy, 130, pi * 0.15, pi * 0.85, 34, 1)
end

function Levels.Count() return #LAYOUTS end

---------------------------------------------------------------------------
-- Build a level: the stage's board, then crystals (weighted), hero runes
---------------------------------------------------------------------------
function Levels.Build(level, runSeed)
    local C = NS.Game.C
    W, PEG_R = C.W, C.PEG_R
    local rng = NS.Game.RNG((runSeed or 1) * 31 + level * 7919)
    local si = ((level - 1) % #STAGES) + 1
    local stage = STAGES[si]
    local idx = si
    local cycle = floor((level - 1) / #STAGES)
    local pegs = {}
    LAYOUTS[idx](Kit(pegs, rng, cycle))

    -- fire crystals: a weighted draw without replacement (hot spots are more likely)
    local nOrange = min(stage.org or 25, floor(#pegs * 0.34))
    nOrange = min(nOrange + cycle * 2, floor(#pegs * 0.4))
    local pool = {}
    for i, p in ipairs(pegs) do
        local w = max(0.05, p.w or 1)
        if stage.easy then w = w * (1.6 - (p.y - TOP) / (BOTTOM - TOP)) end   -- early boards: crystals sit high, in reach
        pool[#pool + 1] = { i = i, w = w }
    end
    for _ = 1, nOrange do
        local tot = 0
        for _, e in ipairs(pool) do tot = tot + e.w end
        local r = rng.next() * tot
        for k, e in ipairs(pool) do
            r = r - e.w
            if r <= 0 or k == #pool then
                pegs[e.i].kind = "orange"
                table.remove(pool, k)
                break
            end
        end
    end
    -- two hero runes: round, still, in the open middle of the board
    local cands = {}
    for _, p in ipairs(pegs) do
        if p.kind == "blue" and not p.brick and not p.orbit and not p.slide then
            cands[#cands + 1] = { p = p, d = abs(p.y - 300) + abs(p.x - 240) * 0.5 + rng.next() * 120 }
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    local first
    for _, c in ipairs(cands) do
        if not first then
            first = c.p
            c.p.kind, c.p.power = "green", "hero"
        elseif (c.p.x - first.x) ^ 2 + (c.p.y - first.y) ^ 2 > 120 * 120 then
            c.p.kind, c.p.power = "green", "hero"
            break
        end
    end
    for _, p in ipairs(pegs) do p.w = nil end

    local d = stage
    return pegs, { name = d.name, top = d.top, bottom = d.bottom, bg = d.bg, dim = d.dim, layout = idx, cycle = cycle }
end
