-- Flight Buddy: Death Roll window. Its own small window (not a tavern tab), so it works in a raid between pulls.
-- Every roll is played out as a blow in the Brawler's Pit: your roll is the health you are left with.
local _, NS = ...
local W = NS.W
local COLORS = W.COLORS
local D = NS.DeathRoll
local UI = {}
NS.DeathRollUI = UI

local floor, min, max, sin, abs = math.floor, math.min, math.max, math.sin, math.abs
local WIN_W, WIN_H = 448, 706
local AW, AH = 420, 490          -- the arena picture (6:7)
local FLOOR_Y = 452              -- where feet stand, from the top of the arena
local LX, RX = 108, AW - 108     -- the two fighters

-- Painted art lives in Media\deathroll\. Each piece switches on here as it is delivered; until then the
-- window uses a stand-in from the game itself.
local ART = { arena = true, crest = true, plaque = true, die = true, cup = true, fx = true, tomb = true, icon = true, pot = true, coin = true, laurel = true, turn = true }
local function Art(name) return W.MEDIA .. "deathroll\\" .. name end

local CLASS_NAME = { WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue", PRIEST = "priest", SHAMAN = "shaman",
                     MAGE = "mage", WARLOCK = "warlock", DRUID = "druid" }
-- what each class swings: { name, effect }
local ATTACKS = {
    WARRIOR = { { "Mortal Strike", "slash" }, { "Heroic Strike", "slash" }, { "Execute", "slash" } },
    PALADIN = { { "Hammer of Justice", "impact" }, { "Judgement", "impact" }, { "Holy Shock", "bolt" } },
    HUNTER  = { { "Aimed Shot", "impact" }, { "Arcane Shot", "bolt" }, { "Multi-Shot", "impact" } },
    ROGUE   = { { "Sinister Strike", "slash" }, { "Backstab", "slash" }, { "Eviscerate", "slash" } },
    PRIEST  = { { "Smite", "impact" }, { "Mind Blast", "shadow" }, { "Shadow Word: Pain", "shadow" } },
    SHAMAN  = { { "Lightning Bolt", "bolt" }, { "Earth Shock", "bolt" }, { "Stormstrike", "slash" } },
    MAGE    = { { "Fireball", "fire" }, { "Frostbolt", "frost" }, { "Pyroblast", "fire" } },
    WARLOCK = { { "Shadow Bolt", "shadow" }, { "Immolate", "fire" }, { "Searing Pain", "fire" } },
    DRUID   = { { "Wrath", "bolt" }, { "Maul", "slash" }, { "Moonfire", "frost" } },
}
local FX_COLOR = { slash = { 0.95, 0.95, 1 }, impact = { 1, 0.9, 0.5 }, fire = { 1, 0.5, 0.15 }, frost = { 0.55, 0.85, 1 },
                   bolt = { 0.5, 0.75, 1 }, shadow = { 0.7, 0.4, 1 } }
local KIND = {
    glance = { verb = "grazes",  word = "Glancing blow", color = { 0.75, 0.78, 0.85 }, shake = 2,  size = 18 },
    hit    = { verb = "hits",    word = "Hit",           color = { 1, 0.9, 0.55 },     shake = 5,  size = 22 },
    heavy  = { verb = "slams",   word = "Heavy hit",     color = { 1, 0.65, 0.25 },    shake = 8,  size = 26 },
    crit   = { verb = "CRITS",   word = "CRITICAL!",     color = { 1, 0.3, 0.2 },      shake = 13, size = 32 },
    death  = { verb = "finishes", word = "DEATH BLOW",   color = { 1, 0.15, 0.15 },    shake = 16, size = 34 },
}

-- a class crest (or the game's own class icon until the crest art exists) on any texture
local function SetCrest(tex, class)
    if ART.crest and CLASS_NAME[class] then
        tex:SetTexture(Art("dr_crest_" .. CLASS_NAME[class]))
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if tc then tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) else tex:SetTexCoord(0, 0.25, 0, 0.25) end
    end
end

local function ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end
local function Hex(r, g, b) return ("|cff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)) end
local function Tag(g, key)
    local r, gg, b = ClassColor(g.class[key])
    return Hex(r, gg, b) .. D.Short(g.name[key]) .. "|r"
end
local function AttackFor(g, e)
    local attacker = D.Other(g, e.who)
    local list = ATTACKS[g.class[attacker]] or ATTACKS.WARRIOR
    return list[(e.seq + #g.name[attacker]) % #list + 1], attacker
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function UI:Init(db)
    self.db = db
    D.onChange = function() if self:Visible() then self:Refresh() end end
    D.onOpen = function(lobby) self:Open() end
    D.onRound = function(g) self:ResetDisplay(g) end
    D.onRoll = function(g, e, mine) self:OnRoll(g, e, mine) end
    D.onNotice = function(w) self:Notice(w) end
    D.onDeclined = function() if self:Visible() then self:Refresh() end end
end

local function Fighter(arena, x, flip)
    local f = { x = x, flip = flip }
    f.shadow = W.Tex(arena, "ARTWORK", "glow", 0)
    f.shadow:SetSize(120, 26); f.shadow:SetVertexColor(0, 0, 0, 0.5)
    f.shadow:SetPoint("CENTER", arena, "TOPLEFT", x, -FLOOR_Y)
    -- the player's real character when the game can show it
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, arena)
    if ok and m then
        m:SetSize(190, 250)
        m:SetPoint("BOTTOM", arena, "TOPLEFT", x, -FLOOR_Y - 8)
        m:Hide()
        f.model = m
    end
    -- otherwise their class crest
    f.crest = arena:CreateTexture(nil, "ARTWORK", nil, 3)
    f.crest:SetSize(104, 104)
    f.tomb = arena:CreateTexture(nil, "ARTWORK", nil, 4)
    f.tomb:SetSize(ART.tomb and 104 or 72, ART.tomb and 104 or 72)
    f.tomb:Hide()
    f.ox, f.oy, f.shakeT, f.shake = 0, 0, 0, 0
    return f
end

local function Plate(arena, left)
    local p = {}
    local a1, a2, dir = left and "TOPLEFT" or "TOPRIGHT", left and "TOPLEFT" or "TOPRIGHT", left and 1 or -1
    p.icon = arena:CreateTexture(nil, "ARTWORK", nil, 3)
    p.icon:SetSize(48, 48)
    p.icon:SetPoint(a1, arena, a2, dir * 8, -7)
    p.laurel = arena:CreateTexture(nil, "ARTWORK", nil, 2)
    p.laurel:SetSize(62, 62)
    p.laurel:SetPoint("CENTER", p.icon, "CENTER", 0, -3)
    if ART.laurel then p.laurel:SetTexture(Art("dr_laurel")) end
    p.laurel:Hide()
    p.name = W.Text(arena, 14)
    p.name:SetPoint(a1, arena, a2, dir * 62, -12)
    p.name:SetJustifyH(left and "LEFT" or "RIGHT")
    p.back = W.Solid(arena, "ARTWORK", 0, 0, 0, 0.65, 1)
    p.back:SetSize(118, 18)
    p.back:SetPoint(a1, arena, a2, dir * 60, -32)
    p.fill = W.Solid(arena, "ARTWORK", 0.8, 0.15, 0.12, 1, 2)
    p.fill:SetHeight(14)
    p.fill:SetPoint(left and "LEFT" or "RIGHT", p.back, left and "LEFT" or "RIGHT", dir * 2, 0)
    p.hp = W.Text(arena, 13, W.FONT_NUM)
    p.hp:SetPoint("CENTER", p.back, "CENTER", 0, 0)
    p.turn = W.Text(arena, 11)
    p.turn:SetPoint(a1, p.back, left and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -4)
    p.turn:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    return p
end

function UI:Build()
    -- The game lives in "body". It sits either in its own small window (handy in a raid, and it stays open in
    -- combat) or docked in the Flight Buddy window as the Death Roll tab.
    local win = CreateFrame("Frame", "FlightBuddyDeathRoll", UIParent)
    self.win = win
    win:SetSize(WIN_W, WIN_H)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
    win:SetScript("OnDragStop", function(fr)
        fr:StopMovingOrSizing()
        local p, _, rp, x, y = fr:GetPoint()
        self.db.pos = { p, rp, x, y }
    end)
    local sh = (GetScreenHeight and GetScreenHeight()) or 768
    win:SetScale(max(0.6, min(1, sh * 0.9 / WIN_H)))
    local pos = self.db.pos
    if pos then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else win:SetPoint("CENTER", UIParent, "CENTER", -260, 0) end
    win:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "FlightBuddyDeathRoll") end
    W.Nine(win, "wood", 18)
    local close = W.Button(win, 26, 24, "X", "ghost")
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetFrameLevel(win:GetFrameLevel() + 20)
    close:SetScript("OnClick", function() win:Hide() end)

    local f = CreateFrame("Frame", nil, win)
    self.frame = f
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("TOP", win, "TOP", 0, 0)

    local title = W.Text(f, 24, W.FONT_TITLE)
    title:SetPoint("TOP", ART.icon and 16 or 0, -12)
    if ART.icon then
        local ti = f:CreateTexture(nil, "ARTWORK")
        ti:SetTexture(Art("dr_icon"))
        ti:SetSize(34, 34)
        ti:SetPoint("RIGHT", title, "LEFT", -6, 0)
        self.titleIcon = ti
    end
    self.title = title
    title:SetText("Death Roll")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.ledgerBtn = W.Button(f, 70, 24, "Ledger", "ghost")
    self.ledgerBtn:SetPoint("TOPLEFT", 12, -12)
    self.ledgerBtn:SetScript("OnClick", function() self.showLedger = not self.showLedger; self:Refresh() end)

    -- the pit
    local arena = CreateFrame("Frame", nil, f)
    self.arena = arena
    arena:SetSize(AW, AH)
    arena:SetPoint("TOP", 0, -46)
    if arena.SetClipsChildren then arena:SetClipsChildren(true) end
    self.bg = arena:CreateTexture(nil, "BACKGROUND", nil, -6)
    self.bg:SetAllPoints()
    if ART.arena then
        self.bg:SetTexture(Art("dr_arena"))
        self.bg:SetTexCoord(0, 1, 0, 597 / 1024)   -- the 6:7 picture sits in the top of a 512x1024 sheet
    else
        self.bg:SetColorTexture(0.10, 0.07, 0.05, 1)
        local wall = W.Tex(arena, "BACKGROUND", "gradient", -5)
        wall:SetPoint("TOPLEFT"); wall:SetPoint("TOPRIGHT"); wall:SetHeight(FLOOR_Y - 70)
        wall:SetVertexColor(0.45, 0.25, 0.10, 0.55)
        local sand = W.Solid(arena, "BACKGROUND", 0.55, 0.43, 0.27, 1, -4)
        sand:SetPoint("BOTTOMLEFT"); sand:SetPoint("BOTTOMRIGHT"); sand:SetHeight(AH - FLOOR_Y + 70)
        local rail = W.Solid(arena, "BACKGROUND", 0.25, 0.15, 0.08, 1, -3)
        rail:SetPoint("BOTTOMLEFT", 0, AH - FLOOR_Y + 70); rail:SetPoint("BOTTOMRIGHT", 0, AH - FLOOR_Y + 70); rail:SetHeight(10)
    end
    local dim = W.Tex(arena, "BACKGROUND", "gradient", -2)
    dim:SetPoint("TOPLEFT"); dim:SetPoint("TOPRIGHT"); dim:SetHeight(110)
    dim:SetVertexColor(0, 0, 0, ART.arena and 0.45 or 0.7)
    W.Border(arena, 0.1)

    self.fighters = { Fighter(arena, LX, false), Fighter(arena, RX, true) }
    -- everything drawn over the fighters (numbers, dice, hits, the lobby) lives on a layer above the character models
    local top = CreateFrame("Frame", nil, arena)
    top:SetAllPoints()
    top:SetFrameLevel(arena:GetFrameLevel() + 6)
    for _, ft in ipairs(self.fighters) do if ft.model then ft.model:SetFrameLevel(arena:GetFrameLevel() + 2) end end
    self.plates = { Plate(top, true), Plate(top, false) }

    -- the stake, top centre
    self.pot = top:CreateTexture(nil, "ARTWORK", nil, 2)
    self.pot:SetSize(34, 34)
    self.pot:SetPoint("TOP", 0, -2)
    if ART.pot then self.pot:SetTexture(Art("dr_pot")) end
    self.pot:Hide()
    self.stake = W.Text(top, 14, W.FONT_NUM)
    self.stake:SetPoint("TOP", 0, ART.pot and -36 or -14)
    self.stake:SetTextColor(1, 0.85, 0.3)
    self.round = W.Text(top, 11)
    self.round:SetPoint("TOP", top, "TOP", 0, -72)

    -- the number everyone is watching
    self.plaque = top:CreateTexture(nil, "ARTWORK", nil, 1)
    self.plaque:SetSize(ART.plaque and 234 or 210, ART.plaque and 77 or 70)
    self.plaque:SetPoint("CENTER", arena, "TOPLEFT", AW / 2, -206)
    if ART.plaque then self.plaque:SetTexture(Art("dr_plaque")) else self.plaque:SetColorTexture(0, 0, 0, 0.62) end
    self.number = W.Text(top, 40, W.FONT_NUM)
    self.number:SetPoint("CENTER", self.plaque, "CENTER", 0, 3)
    self.range = W.Text(top, 12, W.FONT_NUM)
    self.range:SetPoint("TOP", self.plaque, "BOTTOM", 0, -3)
    self.range:SetTextColor(0.85, 0.82, 0.75)
    self.callout = W.Text(top, 26, W.FONT_TITLE)
    self.callout:SetPoint("BOTTOM", self.plaque, "TOP", 0, 8)
    self.callout:Hide()

    -- dice
    self.dice = {}
    for i = 1, 2 do
        local t = top:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetSize(44, 44)
        if ART.die then t:SetTexture(Art("dr_die")) else t:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up") end
        t:Hide()
        self.dice[i] = t
    end
    -- whose roll it is: a gauntlet holding a die, bobbing over that fighter
    self.turnMark = top:CreateTexture(nil, "OVERLAY", nil, 1)
    self.turnMark:SetSize(46, 46)
    if ART.turn then self.turnMark:SetTexture(Art("dr_turn")) end
    self.turnMark:Hide()
    -- the winnings changing hands
    self.coins = {}
    for i = 1, 7 do
        local c = top:CreateTexture(nil, "OVERLAY", nil, 5)
        c:SetSize(22, 22)
        if ART.coin then c:SetTexture(Art("dr_coin")) end
        c:Hide()
        self.coins[i] = c
    end
    self.crown = top:CreateTexture(nil, "OVERLAY", nil, 1)
    self.crown:SetSize(92, 92)
    if ART.laurel then self.crown:SetTexture(Art("dr_laurel")) end
    self.crown:Hide()
    -- the dice cup the roller throws from
    self.cup = top:CreateTexture(nil, "OVERLAY", nil, 1)
    self.cup:SetSize(64, 64)
    if ART.cup then self.cup:SetTexture(Art("dr_cup")) end
    self.cup:Hide()
    -- hit effect and floating damage
    self.fx = top:CreateTexture(nil, "OVERLAY", nil, 3)
    self.fx:SetBlendMode("ADD")
    self.fx:Hide()
    self.fxSprite = top:CreateTexture(nil, "OVERLAY", nil, 4)
    self.fxSprite:Hide()
    self.proj = top:CreateTexture(nil, "OVERLAY", nil, 5)
    self.proj:SetSize(78, 78)
    self.proj:Hide()
    self.dmg = W.Text(top, 24, W.FONT_NUM)
    self.dmg:Hide()
    self.flash = W.Solid(top, "OVERLAY", 1, 1, 1, 0, 6)
    self.flash:SetAllPoints()

    -- lobby and ledger sit over the pit
    self:BuildLobby(top)
    self.ledger = W.Text(top, 13)
    self.ledger:SetPoint("TOPLEFT", 22, -130)
    self.ledger:SetWidth(AW - 44)
    self.ledger:SetJustifyH("LEFT")
    if self.ledger.SetSpacing then self.ledger:SetSpacing(5) end
    self.ledgerBack = W.Solid(top, "ARTWORK", 0, 0, 0, 0.78, 5)
    self.ledgerBack:SetPoint("TOPLEFT", 10, -118); self.ledgerBack:SetPoint("BOTTOMRIGHT", -10, 12)
    self.ledgerRows = {}
    for i = 1, 5 do
        local b = W.Button(top, 78, 22, "", "ghost")
        b:SetPoint("TOPRIGHT", arena, "TOPRIGHT", -20, -166 - (i - 1) * 23)
        b:Hide()
        self.ledgerRows[i] = b
    end

    -- play-by-play
    self.logBack = W.Solid(f, "ARTWORK", 0, 0, 0, 0.45)
    self.logBack:SetPoint("TOPLEFT", arena, "BOTTOMLEFT", 0, -6)
    self.logBack:SetPoint("TOPRIGHT", arena, "BOTTOMRIGHT", 0, -6)
    self.logBack:SetHeight(76)
    self.log = W.Text(f, 11)
    self.log:SetPoint("TOPLEFT", self.logBack, "TOPLEFT", 8, -6)
    self.log:SetPoint("BOTTOMRIGHT", self.logBack, "BOTTOMRIGHT", -8, 6)
    self.log:SetJustifyH("LEFT"); self.log:SetJustifyV("BOTTOM")
    if self.log.SetSpacing then self.log:SetSpacing(3) end
    self.lines = {}

    -- status and buttons
    self.status = W.Text(f, 13)
    self.status:SetPoint("TOP", self.logBack, "BOTTOM", 0, -8)
    self.status:SetWidth(AW)
    self.buttons = {}
    for i = 1, 3 do self.buttons[i] = W.Button(f, 132, 32, "") end

    f:SetScript("OnUpdate", function(_, el) W.Guard("DeathRollUI", self.OnUpdate, self, el) end)
    f:SetScript("OnShow", function() self:Refresh(true) end)
    self.anim, self.pending, self.disp = nil, {}, nil
end

function UI:BuildLobby(arena)
    local L = CreateFrame("Frame", nil, arena)
    self.lobby = L
    L:SetPoint("TOPLEFT", 10, -118); L:SetPoint("BOTTOMRIGHT", -10, 12)
    local back = W.Solid(L, "BACKGROUND", 0, 0, 0, 0.72)
    back:SetAllPoints()
    local head = W.Text(L, 17, W.FONT_TITLE)
    head:SetPoint("TOP", 0, -12)
    head:SetText("Throw down a challenge")
    head:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    L.rules = W.Text(L, 11)
    L.rules:SetPoint("TOP", head, "BOTTOM", 0, -6)
    L.rules:SetWidth(360)
    L.rules:SetTextColor(0.85, 0.82, 0.75)
    L.rules:SetText("Take turns rolling. Each roll is 1 to whatever the last one was. Roll a 1 and you lose. Your roll is the health you're left with.")

    local wl = W.Text(L, 13)
    wl:SetPoint("TOPLEFT", 26, -88)
    wl:SetText("Wager (gold)")
    local box = CreateFrame("EditBox", nil, L)
    L.wager = box
    box:SetSize(96, 24)
    box:SetPoint("LEFT", wl, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetFont(W.FONT_NUM, 15, "")
    box:SetTextColor(1, 0.85, 0.3)
    box:SetJustifyH("CENTER")
    if box.SetNumeric then box:SetNumeric(true) end
    box:SetMaxLetters(7)
    local bb = W.Solid(box, "BACKGROUND", 0, 0, 0, 0.7)
    bb:SetPoint("TOPLEFT", -4, 2); bb:SetPoint("BOTTOMRIGHT", 4, -2)
    box:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
    box:SetText(tostring(floor((D.db.lastWager or 0) / 10000)))

    L.start = W.Button(L, 150, 26, "")
    L.start:SetPoint("LEFT", box, "RIGHT", 22, 0)
    L.start:SetScript("OnClick", function()
        local at = 1
        for i, v in ipairs(D.STARTS) do if v == D.db.start then at = i end end
        D.db.start = D.STARTS[at % #D.STARTS + 1]
        self:Refresh()
    end)

    L.opps = {}
    for i = 1, 6 do
        local b = W.Button(L, 180, 28, "")
        b:SetPoint("TOPLEFT", 16 + ((i - 1) % 2) * 190, -128 - floor((i - 1) / 2) * 33)
        L.opps[i] = b
    end
    L.record = W.Text(L, 12, W.FONT_NUM)
    L.record:SetPoint("BOTTOM", 0, 62)
    L.record:SetWidth(370)
    L.opts = {}
    local function Opt(i, label, get, set)
        local t = W.Toggle(L, get, set)
        t:SetPoint("BOTTOMLEFT", 22, 34 - (i - 1) * 24)
        local tx = W.Text(L, 11)
        tx:SetPoint("LEFT", t, "RIGHT", 8, 0)
        tx:SetText(label)
        L.opts[i] = t
    end
    Opt(1, "Tell me when guildmates or my group start a Death Roll", function() return D.db.notify end, function(v) D.db.notify = v end)
    Opt(2, "Post my results in guild chat", function() return D.db.guildChat end, function(v) D.db.guildChat = v end)
    L:Hide()
end

function UI:Visible() return self.frame and self.frame:IsVisible() and true or false end

-- put the game in the Flight Buddy window's Death Roll tab
function UI:Dock(host)
    if not self.frame then self:Build() end
    self.win:Hide()
    local f = self.frame
    f:SetParent(host)
    f:ClearAllPoints()
    -- the tab row already says "Death Roll": drop the window's own title and start the pit just under the tabs
    f:SetPoint("TOP", host, "TOP", 0, 8)
    f:SetFrameLevel(host:GetFrameLevel() + 1)
    self.title:Hide()
    if self.titleIcon then self.titleIcon:Hide() end
    self.ledgerBtn:ClearAllPoints()
    self.ledgerBtn:SetPoint("TOPRIGHT", self.logBack, "TOPRIGHT", -4, -4)
    self.ledgerBtn:SetSize(64, 20)
    self.docked = host
    f:Show()
    self:Refresh(true)
end

-- or in its own window
function UI:Float()
    if not self.frame then self:Build() end
    local f = self.frame
    if self.docked or f:GetParent() ~= self.win then
        f:SetParent(self.win)
        f:ClearAllPoints()
        f:SetPoint("TOP", self.win, "TOP", 0, 0)
        f:SetFrameLevel(self.win:GetFrameLevel() + 1)
        self.title:Show()
        if self.titleIcon then self.titleIcon:Show() end
        self.ledgerBtn:ClearAllPoints()
        self.ledgerBtn:SetPoint("TOPLEFT", 12, -12)
        self.ledgerBtn:SetSize(70, 24)
        self.docked = nil
    end
    f:Show()
    self.win:Show()
    self:Refresh(true)
end

-- show the game wherever the player is looking: the tab if the tavern is open, its own window if not
function UI:Open()
    local Shell = NS.Shell
    if Shell and Shell:IsShown() and Shell.mods and Shell.mods.roll then
        if Shell.tab ~= "roll" or not self:Visible() then Shell:SelectTab("roll") end
        return
    end
    self:Float()
end

function UI:Toggle()
    if self:Visible() and not self.docked then self.win:Hide() else self:Open() end
end

-- the tab in the Flight Buddy window
local Tab = {}
NS.DeathRollTab = Tab
function Tab:Build(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()
    self.frame = f
end
function Tab:OnShow() UI:Dock(self.frame) end
function Tab:OnHide() end

---------------------------------------------------------------------------
-- Which game is on the table
---------------------------------------------------------------------------
function UI:Game()
    local g = D.game
    if g and g.state ~= "pending" then return g, true end
    if self.watchId and D.watch[self.watchId] then return D.watch[self.watchId], false end
    return nil
end

function UI:Wager()
    local v = tonumber(self.lobby.wager:GetText() or "") or 0
    return floor(max(0, v)) * 10000
end

-- people I could challenge right now: my target, then my group
function UI:Opponents()
    local out, seen = {}, {}
    local function add(unit, label)
        if not (UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return end
        if UnitIsUnit and UnitIsUnit(unit, "player") then return end
        local n, r = UnitName(unit)
        if not n or n == (UNKNOWNOBJECT or "Unknown") then return end
        local full = r and r ~= "" and (n .. "-" .. r) or n
        if seen[full] then return end
        seen[full] = true
        local _, class = UnitClass(unit)
        out[#out + 1] = { full = full, short = n, class = class, label = label }
    end
    add("target", "target")
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do if #out >= 5 then break end add("raid" .. i) end
    else
        for i = 1, 4 do add("party" .. i) end
    end
    return out
end

function UI:Hint(text)
    self.hint, self.hintT = text, 3
    self:Refresh()
end

---------------------------------------------------------------------------
-- Fighters
---------------------------------------------------------------------------
function UI:SetFighter(i, g, key)
    local f = self.fighters[i]
    local class = g and g.class[key] or "WARRIOR"
    if f.key == key and f.class == class and f.gameId == (g and g.id) then return end
    f.key, f.class, f.gameId, f.dead = key, class, g and g.id, false
    f.tomb:Hide()
    local unit = g and D.UnitFor(g.name[key])
    local shown = false
    if f.model and unit and not NS.db.settings.reducedMotion then
        local ok = pcall(function()
            f.model:ClearModel()
            f.model:SetUnit(unit)
            f.model:SetFacing(f.flip and -0.75 or 0.75)
            if f.model.SetCamDistanceScale then f.model:SetCamDistanceScale(1.35) end
            f.model:SetAnimation(0)
        end)
        shown = ok and (unit == "player" or not UnitIsVisible or UnitIsVisible(unit)) and true or false
    end
    f.useModel = shown
    if f.model then f.model:SetShown(shown) end
    f.crest:SetShown(not shown)
    if not shown then
        SetCrest(f.crest, class)
    end
end

function UI:Anim(i, id)
    local f = self.fighters[i]
    if f.useModel and f.model then pcall(f.model.SetAnimation, f.model, id) end
end

function UI:PlaceFighters(el)
    for i, f in ipairs(self.fighters) do
        if f.shakeT > 0 then f.shakeT = f.shakeT - el end
        local sx = f.shakeT > 0 and sin(f.shakeT * 70) * f.shake * (f.shakeT / 0.35) or 0
        local x, y = f.x + f.ox + sx, FLOOR_Y + f.oy
        if f.model then
            f.model:ClearAllPoints()
            f.model:SetPoint("BOTTOM", self.arena, "TOPLEFT", x, -(y + 8))
        end
        f.crest:ClearAllPoints()
        f.crest:SetPoint("BOTTOM", self.arena, "TOPLEFT", x, -(y - 6) + (f.dead and -18 or 0))
        f.crest:SetAlpha(f.dead and (ART.tomb and 0 or 0.35) or 1)
        if f.crest.SetRotation then f.crest:SetRotation(f.dead and (f.flip and -1.2 or 1.2) or 0) end
        f.tomb:ClearAllPoints()
        f.tomb:SetPoint("BOTTOM", self.arena, "TOPLEFT", f.x, -(FLOOR_Y - 2))
    end
end

---------------------------------------------------------------------------
-- Display state: what the pit shows, which trails the real game while a blow plays out
---------------------------------------------------------------------------
function UI:ResetDisplay(g)
    self.disp = { id = g.id, round = g.round, shown = #g.hist, cur = g.cur, hp = { [g.a] = g.hp[g.a], [g.b] = g.hp[g.b] }, start = g.start }
    self.anim, self.pending = nil, {}
    self.lines = {}
    if self.dice then for _, d in ipairs(self.dice) do d:Hide() end end
    if self.cup then self.cup:Hide() end
    for _, f in ipairs(self.fighters) do f.dead, f.ox, f.oy = false, 0, 0; f.tomb:Hide(); f.gameId = nil end
    if #g.hist == 0 or g.hist[#g.hist].round ~= g.round then
        self:Line(g.round > 1 and ("|cffffcc40Double or nothing!|r %s rolls first, from %s."):format(Tag(g, g.turn), W.Commas(g.start))
            or ("%s challenges %s%s. Rolling from %s."):format(Tag(g, g.a), Tag(g, g.b),
                g.wager > 0 and (" for |cffffcc40" .. D.Money(g.wager) .. "|r") or "", W.Commas(g.start)))
        self.disp.hp = { [g.a] = g.start, [g.b] = g.start }
        self.disp.cur = g.start
        self.disp.shown = #g.hist
    else
        for _, e in ipairs(g.hist) do if e.round == g.round then self:Line(self:Describe(g, e, e.max)) end end
        local last = g.hist[#g.hist]
        if g.state == "over" then
            for i, key in ipairs({ g.a, g.b }) do if key == g.loser then self.fighters[i].dead = true end end
        end
        self.lastEntry = last
    end
    if self:Visible() then self:Refresh() end
end

function UI:Line(text)
    self.lines[#self.lines + 1] = text
    while #self.lines > 4 do table.remove(self.lines, 1) end
    if self.log then self.log:SetText(table.concat(self.lines, "\n")) end
end

function UI:Describe(g, e, hpBefore)
    local atk, attacker = AttackFor(g, e)
    local k = KIND[e.kind] or KIND.hit
    if e.forfeit then return ("%s throws in the towel. %s wins."):format(Tag(g, e.who), Tag(g, attacker)) end
    if e.kind == "death" then
        return ("%s rolls a |cffff30301|r. %s lands the killing %s!"):format(Tag(g, e.who), Tag(g, attacker), atk[1])
    end
    local dmg = max(0, (hpBefore or e.max) - e.roll)
    return ("%s rolls |cffffffff%s|r of %s: %s %s for %s"):format(Tag(g, e.who), W.Commas(e.roll), W.Commas(e.max),
        atk[1], k.verb, W.Commas(dmg))
end

function UI:OnRoll(g, e, mine)
    -- a line in my own chat for games I'm not looking at
    local shown = self:Visible() and self:Game() == g
    if not shown then
        if mine then
            self:Open()   -- the pit opens already showing this roll
            shown = nil
        elseif e.kind == "death" and D.db.notify then
            NS.Print(("Death Roll: %s beat %s%s after %d rolls."):format(D.Short(g.name[g.winner]), D.Short(g.name[g.loser]),
                g.wager > 0 and (" for " .. D.Money(g.wager)) or "", #g.hist))
        end
    end
    if mine and e.kind == "death" and D.db.guildChat and g.winner == D.Key((UnitName("player"))) and SendChatMessage and IsInGuild and IsInGuild() then
        local amt = (g.owed and g.owed.amount or 0)
        pcall(SendChatMessage, ("[Death Roll] %s beat %s%s."):format(D.Short(g.name[g.winner]), D.Short(g.name[g.loser]),
            g.round > 1 and (amt > 0 and (" at double or nothing: " .. D.Money(amt) .. " owed") or " at double or nothing: debt wiped")
            or (g.wager > 0 and (" for " .. D.Money(g.wager)) or "")), "GUILD")
    end
    if shown and self.disp and self.disp.id == g.id and self.disp.round == g.round then
        self.pending[#self.pending + 1] = e
    end
end

---------------------------------------------------------------------------
-- One blow, played out
---------------------------------------------------------------------------
local ROLL_T, HIT_T, END_T = 0.75, 1.05, 2.1
local PROJECTILE = { fire = true, frost = true, bolt = true, shadow = true }   -- these fly across the pit; the rest are swung up close

function UI:StartAnim(g, e)
    local atk, attacker = AttackFor(g, e)
    local vi = (e.who == g.a) and 1 or 2
    self.anim = { g = g, e = e, t = 0, atk = atk, attacker = attacker, vi = vi, ai = 3 - vi, hpFrom = self.disp.hp[e.who], hit = false,
                  fast = #self.pending > 2 }
    self.range:SetText(("%s rolls 1 - %s"):format(D.Short(g.name[e.who]), W.Commas(e.max)))
    if ART.die then for _, d in ipairs(self.dice) do d:SetTexture(Art("dr_die")) end end
    W.SFX("bucket", 0.1)
end

function UI:FinishAnim()
    local a = self.anim
    if not a then return end
    local g, e = a.g, a.e
    self.disp.hp[e.who] = e.roll
    self.disp.cur = e.roll
    self.disp.shown = e.seq
    self.anim = nil
    self.dmg:Hide(); self.fx:Hide(); self.fxSprite:Hide(); self.callout:Hide(); self.cup:Hide(); self.proj:Hide()
    for _, d in ipairs(self.dice) do d:Hide() end
    for _, f in ipairs(self.fighters) do f.ox, f.oy = 0, 0 end
    if e.kind == "death" and ART.die and not e.forfeit then
        -- the die that did it stays on the sand
        local d = self.dice[1]
        d:SetTexture(Art("dr_die_skull"))
        d:ClearAllPoints()
        d:SetPoint("CENTER", self.arena, "TOPLEFT", AW / 2, -(FLOOR_Y - 10))
        if d.SetRotation then d:SetRotation(0) end
        d:SetAlpha(1)
        d:Show()
    end
    self:Refresh()
end

function UI:Land(a)
    local g, e = a.g, a.e
    local k = KIND[e.kind] or KIND.hit
    a.hit = true
    local vf, af = self.fighters[a.vi], self.fighters[a.ai]
    self:Line(self:Describe(g, e, a.hpFrom))
    self.number:SetText(W.Commas(e.roll))
    self.number:SetTextColor(k.color[1], k.color[2], k.color[3])
    vf.shake, vf.shakeT = k.shake, 0.35
    self:Anim(a.ai, (ATTACKS[g.class[a.attacker]] and a.atk[2] ~= "slash" and a.atk[2] ~= "impact") and 53 or 17)
    local dmg = max(0, a.hpFrom - e.roll)
    self.dmg:SetText(e.forfeit and "yields" or ("-" .. W.Commas(dmg)))
    self.dmg:SetFont(W.FONT_NUM, k.size, "OUTLINE")
    self.dmg:SetTextColor(k.color[1], k.color[2], k.color[3])
    self.dmg:Show()
    self.callout:SetText(k.word)
    self.callout:SetTextColor(k.color[1], k.color[2], k.color[3])
    self.callout:SetShown(e.kind ~= "hit")
    local c = FX_COLOR[a.atk[2]] or FX_COLOR.impact
    self.fx:SetTexture(W.MEDIA .. "glow")
    self.fx:SetVertexColor(c[1], c[2], c[3], 1)
    self.fx:Show()
    if ART.fx then
        -- a graze is a puff of dust, a crit or a killing blow is the big burst; a spell that flew in bursts on
        -- impact, and a blade leaves its arc
        local file = e.kind == "glance" and "dr_fx_miss" or (e.kind == "crit" or e.kind == "death") and "dr_fx_crit"
            or (PROJECTILE[a.atk[2]] and "dr_fx_impact") or ("dr_fx_" .. a.atk[2])
        self.proj:Hide()
        self.fxSprite:SetTexture(Art(file))
        self.fxSprite:SetTexCoord(a.vi == 1 and 1 or 0, a.vi == 1 and 0 or 1, 0, 1)
        self.fxSprite:Show()
    end
    if e.kind == "death" then
        vf.dead = true
        self:Anim(a.vi, 1)
        if ART.tomb then vf.tomb:SetTexture(Art("dr_tomb")) else vf.tomb:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
        if not vf.useModel then vf.tomb:Show() end
        if ART.die then for _, d in ipairs(self.dice) do d:SetTexture(Art("dr_die_skull")) end end
        W.SFX("lose", 0.2)
    elseif e.kind == "crit" then
        self:Anim(a.vi, 10); W.SFX("rb_stomp", 0.1)
    elseif e.kind == "glance" then
        W.SFX("pop1", 0.05)
    else
        self:Anim(a.vi, 9); W.SFX("knock", 0.05)
    end
    if (e.kind == "crit" or e.kind == "death") and not NS.db.settings.reducedMotion then self.flashT = 0.3 end
    if e.kind == "death" and ART.coin and (e.after or 0) > (e.before or 0) then
        -- gold leaves the loser for the winner
        self.coinT, self.coinFrom, self.coinTo = 0, vf.x, af.x
        W.SFX("coin_win", 0.2)
    end
end

function UI:UpdateCoins(el)
    if not self.coinT then return end
    self.coinT = self.coinT + el
    local live = false
    for i, c in ipairs(self.coins) do
        local k = (self.coinT - 0.5 - (i - 1) * 0.09) / 0.7
        if k >= 0 and k <= 1 then
            live = true
            local x = self.coinFrom + (self.coinTo - self.coinFrom) * k
            local y = FLOOR_Y - 70 - sin(k * 3.1416) * (70 + (i % 3) * 14)
            c:ClearAllPoints()
            c:SetPoint("CENTER", self.arena, "TOPLEFT", x, -y)
            c:Show()
        else
            c:Hide()
            if k < 0 then live = true end
        end
    end
    if not live then self.coinT = nil end
end

function UI:OnUpdate(el)
    if el > 0.1 then el = 0.1 end
    self.rt = (self.rt or 0) + el
    self:UpdateCoins(el)
    self:UpdateMarks()
    if self.hintT then self.hintT = self.hintT - el; if self.hintT <= 0 then self.hint, self.hintT = nil, nil; self:Refresh() end end
    if self.flashT then
        self.flashT = self.flashT - el
        self.flash:SetColorTexture(1, 1, 1, max(0, self.flashT) * 1.2)
        if self.flashT <= 0 then self.flashT = nil end
    end
    local g = self:Game()
    if g and self.disp and self.disp.id == g.id and not self.anim and self.pending[1] then
        self:StartAnim(g, table.remove(self.pending, 1))
    end
    local a = self.anim
    if a then
        a.t = a.t + el * (a.fast and 2.5 or 1)
        local e = a.e
        local vf, af = self.fighters[a.vi], self.fighters[a.ai]
        local dirA = (a.ai == 1) and 1 or -1
        if a.t < ROLL_T then
            -- dice tumble, the number spins
            local k = a.t / ROLL_T
            if floor(a.t * 30) ~= a.tick then
                a.tick = floor(a.t * 30)
                self.number:SetText(W.Commas(math.random(1, max(1, e.max))))
                self.number:SetTextColor(1, 1, 1)
            end
            -- the roller shakes the cup, then the dice spill out toward the middle of the floor
            local side = (a.vi == 1) and 1 or -1            -- which way the dice travel
            local cupX = (a.vi == 1) and (LX + 62) or (RX - 62)
            if ART.cup then
                local shake = k < 0.35 and sin(a.t * 60) * 5 or 0
                self.cup:ClearAllPoints()
                self.cup:SetPoint("CENTER", self.arena, "TOPLEFT", cupX + shake, -(FLOOR_Y - 96) - shake * 0.5)
                self.cup:SetTexCoord(side == 1 and 0 or 1, side == 1 and 1 or 0, 0, 1)
                if self.cup.SetRotation then self.cup:SetRotation(-side * min(1, k * 2.4) * 0.9) end
                self.cup:SetAlpha(1 - max(0, k - 0.75) * 4)
                self.cup:Show()
            end
            for i, d in ipairs(self.dice) do
                local kk = max(0, (k - 0.3) / 0.7)
                local tx = AW / 2 + (i == 1 and -30 or 30)
                local px = (cupX + side * 26) + (tx - (cupX + side * 26)) * kk
                local py = (FLOOR_Y - 70) + (400 - (FLOOR_Y - 70)) * kk - abs(sin((kk + i * 0.17) * 3.1416 * 2.2)) * 60 * (1 - kk * 0.7)
                d:SetAlpha(k < 0.3 and 0 or 1)
                d:ClearAllPoints()
                d:SetPoint("CENTER", self.arena, "TOPLEFT", px, -py)
                if d.SetRotation then d:SetRotation(a.t * (9 + i * 3)) end
                d:Show()
            end
        elseif a.t < HIT_T then
            -- the attacker lunges
            local k = (a.t - ROLL_T) / (HIT_T - ROLL_T)
            local spell = ART.fx and PROJECTILE[a.atk[2]] and not e.forfeit
            af.ox = dirA * (spell and 14 or 46) * k
            if spell then
                if not a.cast then
                    a.cast = true
                    self.proj:SetTexture(Art("dr_fx_" .. a.atk[2]))
                    self.proj:SetTexCoord(dirA == 1 and 0 or 1, dirA == 1 and 1 or 0, 0, 1)
                    self:Anim(a.ai, 53)
                    W.SFX("launch", 0.1)
                end
                local fromX, toX = af.x + dirA * 50, vf.x - dirA * 20
                self.proj:ClearAllPoints()
                self.proj:SetPoint("CENTER", self.arena, "TOPLEFT", fromX + (toX - fromX) * k, -(FLOOR_Y - 92 - sin(k * 3.1416) * 12))
                self.proj:Show()
            end
            self.cup:Hide()
            self.number:SetText(W.Commas(e.roll))
        else
            if not a.hit then self:Land(a) end
            local k = min(1, (a.t - HIT_T) / 0.35)
            af.ox = dirA * 46 * (1 - k)
            local kk = (a.t - HIT_T) / (END_T - HIT_T)
            local kd = KIND[e.kind] or KIND.hit
            vf.ox = -dirA * (e.kind == "glance" and 4 or 14) * max(0, 1 - kk * 2)
            -- the health bar drains
            self.disp.hp[e.who] = a.hpFrom + (e.roll - a.hpFrom) * min(1, kk * 2.2)
            self:DrawPlates(a.g)
            self.dmg:ClearAllPoints()
            self.dmg:SetPoint("CENTER", self.arena, "TOPLEFT", vf.x, -(FLOOR_Y - 150 - kk * 46))
            self.dmg:SetAlpha(max(0, 1 - max(0, kk - 0.6) * 2.5))
            local s = (60 + kd.shake * 9) * (0.6 + kk)
            self.fx:SetSize(s, s)
            self.fx:ClearAllPoints()
            self.fx:SetPoint("CENTER", self.arena, "TOPLEFT", vf.x, -(FLOOR_Y - 90))
            self.fx:SetAlpha(max(0, 1 - kk * 1.6))
            if ART.fx then
                self.fxSprite:SetSize(110 + kd.shake * 3, 110 + kd.shake * 3)
                self.fxSprite:ClearAllPoints()
                self.fxSprite:SetPoint("CENTER", self.arena, "TOPLEFT", vf.x, -(FLOOR_Y - 90))
                self.fxSprite:SetAlpha(max(0, 1 - max(0, kk - 0.3) * 1.6))
            end
            self.callout:SetAlpha(max(0, 1 - max(0, kk - 0.7) * 3.3))
            if a.t >= END_T then self:FinishAnim() end
        end
    end
    self:PlaceFighters(el)
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------
-- the turn gauntlet over whoever rolls next, and the laurel over the winner
function UI:UpdateMarks()
    local g = self:Game()
    local showTurn, showCrown = false, false
    if g and not self.lobby:IsShown() and not self.ledger:IsShown() then
        for i, key in ipairs({ g.a, g.b }) do
            local f = self.fighters[i]
            local head = FLOOR_Y - (f.useModel and 232 or 128)
            if ART.turn and g.state == "play" and g.turn == key and not self.anim and not self.pending[1] then
                showTurn = true
                self.turnMark:ClearAllPoints()
                self.turnMark:SetPoint("BOTTOM", self.arena, "TOPLEFT", f.x, -(head - 4 - abs(sin((self.rt or 0) * 3)) * 8))
            end
            if ART.laurel and g.state == "over" and g.winner == key and not self.anim and not self.pending[1] then
                showCrown = true
                self.crown:ClearAllPoints()
                self.crown:SetPoint("BOTTOM", self.arena, "TOPLEFT", f.x, -(head + 6))
            end
        end
    end
    self.turnMark:SetShown(showTurn)
    self.crown:SetShown(showCrown)
end

function UI:DrawPlates(g)
    local d = self.disp
    for i, key in ipairs({ g.a, g.b }) do
        local p = self.plates[i]
        local hp = d and d.hp[key] or g.hp[key]
        local r, gg, b = ClassColor(g.class[key])
        p.name:SetText(D.Short(g.name[key]))
        p.name:SetTextColor(r, gg, b)
        local frac = max(0, min(1, hp / max(1, g.start)))
        -- the bar is a square-root scale so the endgame (tiny numbers) still shows
        p.fill:SetWidth(max(1, 114 * math.sqrt(frac)))
        SetCrest(p.icon, g.class[key])
        p.fill:SetColorTexture(frac > 0.25 and 0.25 or 0.85, frac > 0.25 and 0.75 or 0.2, 0.2, 1)
        p.fill:SetShown(hp > 1 or (g.state ~= "over" or key ~= g.loser))
        p.hp:SetText(hp <= 1 and key == g.loser and "DEAD" or W.Commas(floor(hp + 0.5)))
        p.laurel:SetShown(ART.laurel and g.state == "over" and key == g.winner and not self.anim and not self.pending[1])
        local turn = g.state == "play" and g.turn == key and not self.anim
        p.turn:SetText(turn and "to roll" or (g.state == "over" and key == g.winner and "WINNER" or ""))
    end
end

function UI:SetButtons(list)
    local n = #list
    for i, b in ipairs(self.buttons) do
        local s = list[i]
        if s then
            b.text:SetText(s[1])
            b:SetStyle(s[3] or (i == 1 and "primary" or nil))
            b:SetScript("OnClick", s[2])
            b:SetWidth(n == 1 and 220 or 132)
            b:ClearAllPoints()
            b:SetPoint("BOTTOM", self.frame, "BOTTOM", (i - (n + 1) / 2) * 140, 14)
            b:Show()
        else
            b:Hide()
        end
    end
end

function UI:DrawLedger()
    local s = D.db
    local lines = { ("|cffffcc40Your record|r   %d wins   %d losses   net %s%s|r"):format(s.wins, s.losses,
        s.net >= 0 and "|cff3be870+" or "|cffd9534f-", D.Money(abs(s.net))), "" }
    local rows = {}
    for key, led in pairs(s.ledger) do if led.owe ~= 0 then rows[#rows + 1] = { key = key, led = led } end end
    table.sort(rows, function(x, y) return abs(x.led.owe) > abs(y.led.owe) end)
    if #rows == 0 then lines[#lines + 1] = "|cff9499b3Nobody owes anybody. All square.|r" end
    for i, b in ipairs(self.ledgerRows) do
        local r = rows[i]
        if r then
            local mineToPay = r.led.owe < 0
            lines[#lines + 1] = mineToPay and ("You owe %s  |cffd9534f%s|r"):format(D.Short(r.led.name), D.Money(-r.led.owe))
                or ("%s owes you  |cff3be870%s|r"):format(D.Short(r.led.name), D.Money(r.led.owe))
            b.text:SetText(mineToPay and "Pay" or "Forgive")
            b:SetScript("OnClick", function()
                if mineToPay then
                    local ok, why = D:PayUp(r.led.name, -r.led.owe)
                    if not ok then self:Hint(why) end
                else
                    D:Forgive(r.key)
                end
            end)
            b:Show()
        else
            b:Hide()
        end
    end
    if #rows > 5 then lines[#lines + 1] = ("|cff9499b3...and %d more|r"):format(#rows - 5) end
    local h = s.history
    if h[1] then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cffffcc40Recent|r"
        for i = 1, min(4, #h) do
            local e = h[i]
            lines[#lines + 1] = ("%s %s%s  |cff9499b3%d rolls|r"):format(e.won and "|cff3be870Beat|r" or "|cffd9534fLost to|r", D.Short(e.opp),
                e.amount > 0 and ("  " .. D.Money(e.amount) .. (e.double and " (double or nothing)" or "")) or "", e.rolls or 0)
        end
    end
    self.ledger:SetText(table.concat(lines, "\n"))
end

function UI:Refresh(reset)
    if not self.frame then return end
    local g, mine = self:Game()
    local me = D.Key((UnitName("player")))
    local pend = D.game and D.game.state == "pending" and D.game
    if g and (reset or not self.disp or self.disp.id ~= g.id or self.disp.round ~= g.round) then self:ResetDisplay(g) end

    local ledger = self.showLedger and not (g and g.state == "play" and mine)
    self.ledger:SetShown(ledger); self.ledgerBack:SetShown(ledger)
    if ledger then self:DrawLedger() else for _, b in ipairs(self.ledgerRows) do b:Hide() end end
    self.ledgerBtn.text:SetText(ledger and "Back" or "Ledger")
    local lobby = not g and not pend and not ledger
    self.lobby:SetShown(lobby)
    local inGame = g and not ledger
    self.plaque:SetShown(inGame and true or false); self.number:SetShown(inGame and true or false); self.range:SetShown(inGame and true or false)
    for i = 1, 2 do
        local p = self.plates[i]
        local show = g and true or false
        p.name:SetShown(show); p.back:SetShown(show); p.fill:SetShown(show); p.hp:SetShown(show); p.turn:SetShown(show)
        p.icon:SetShown(show)
        if not show then p.laurel:Hide() end
    end

    if g then
        self:SetFighter(1, g, g.a); self:SetFighter(2, g, g.b)
        for _, ft in ipairs(self.fighters) do ft.shadow:Show() end
        self:DrawPlates(g)
        -- in a double-or-nothing round the stake shown is what the loser will owe if they lose again
        local stake = g.wager
        if g.round > 1 and g.owed and not g.watching then stake = g.state == "play" and g.owed.amount * 2 or g.owed.amount end
        self.stake:SetText(stake > 0 and D.Money(stake) or "For glory")
        self.pot:SetShown(ART.pot and stake > 0)
        self.round:SetText(g.round > 1 and "|cffff8040DOUBLE OR NOTHING|r" or (mine and "" or "|cff9499b3watching|r"))
        if not self.anim then
            self.number:SetText(W.Commas(self.disp.cur))
            self.number:SetTextColor(1, 1, 1)
            self.range:SetText(g.state == "play" and ("next roll: 1 - %s"):format(W.Commas(self.disp.cur)) or "")
        end
    else
        self.stake:SetText(""); self.round:SetText(""); self.pot:Hide()
        -- nobody in the pit yet
        for _, ft in ipairs(self.fighters) do
            if ft.model then ft.model:Hide() end
            ft.crest:Hide(); ft.tomb:Hide(); ft.shadow:Hide()
            ft.key, ft.gameId = nil, nil
        end
        self.lines = {}
        self.log:SetText("|cff9499b3The play-by-play of each roll shows here.|r")
    end

    -- status line and buttons
    local status, btns = "", {}
    if self.hint then status = "|cffffb030" .. self.hint .. "|r" end
    if pend and not g then
        if status == "" then status = ("Waiting for %s to accept..."):format(D.Short(pend.name[pend.b])) end
        btns = { { "Cancel", function() D:Forfeit() end, "ghost" } }
    elseif g and mine then
        local opp = D.Other(g, me)
        local oppN = D.Short(g.name[opp])
        local busy = self.anim or self.pending[1]
        if g.state == "play" then
            if g.turn == me then
                if status == "" then status = "Your roll." end
                btns = { { ("Roll  1 - %s"):format(W.Commas(g.cur)), function()
                    if self.anim or self.pending[1] then return end
                    D:Roll()
                end }, { "Forfeit", function() D:Forfeit() end, "ghost" } }
            else
                if status == "" then status = ("Waiting for %s to roll 1 - %s..."):format(oppN, W.Commas(g.cur)) end
                btns = { { "Forfeit", function() D:Forfeit() end, "ghost" } }
            end
        elseif not busy then
            local owed = g.owed
            local amount = owed and owed.amount or 0
            local iOwe = owed and owed.from == me
            if status == "" then
                if amount <= 0 then
                    status = g.round > 1 and "|cff3be870Nothing! The debt is wiped.|r" or (g.winner == me and "|cff3be870You win.|r" or "|cffd9534fYou lose.|r")
                elseif owed.paid then status = "|cff3be870Paid in full.|r"
                elseif iOwe then status = ("|cffd9534fYou owe %s %s.|r"):format(oppN, D.Money(amount))
                else status = ("|cff3be870%s owes you %s.|r"):format(oppN, D.Money(amount)) end
                if g.offer and g.offer.from == me then status = status .. "  Waiting on double or nothing..." end
                if g.refused and iOwe then status = status .. "  They turned down double or nothing." end
            end
            if g.offer and g.offer.from ~= me then
                btns = { { "Take the bet", function() if StaticPopup_Hide then StaticPopup_Hide("FLIGHTBUDDY_DR_DOUBLE") end D:AnswerDouble(true) end },
                         { "Refuse", function() if StaticPopup_Hide then StaticPopup_Hide("FLIGHTBUDDY_DR_DOUBLE") end D:AnswerDouble(false) end, "ghost" } }
            elseif iOwe and amount > 0 and not owed.paid then
                btns = { { "Pay " .. D.Money(amount), function()
                    local ok, why = D:PayUp(g.name[opp], amount)
                    if not ok then self:Hint(why) end
                end } }
                if not g.offer and not g.refused then
                    btns[#btns + 1] = { "Double or nothing", function()
                        local ok, why = D:OfferDouble()
                        if not ok then self:Hint(why) end
                    end }
                end
                btns[#btns + 1] = { "Done", function() D:Done(); self.watchId = nil; self:Refresh() end, "ghost" }
            else
                btns = { { "Rematch", function()
                    local name, wager, start = g.name[opp], g.wager, g.start
                    D:Done()
                    local ok, why = D:Challenge(name, wager, start)
                    if not ok then self:Hint(why) end
                end }, { "Done", function() D:Done(); self:Refresh() end, "ghost" } }
            end
        end
    elseif g then
        if status == "" then
            status = g.state == "play" and ("%s to roll 1 - %s"):format(D.Short(g.name[g.turn]), W.Commas(g.cur))
                or ("%s wins."):format(D.Short(g.name[g.winner]))
        end
        btns = { { "Stop watching", function() self.watchId = nil; self:Refresh() end, "ghost" } }
    elseif lobby then
        local L = self.lobby
        L.start.text:SetText("Roll from " .. W.Commas(D.db.start))
        local opps = self:Opponents()
        for i, b in ipairs(L.opps) do
            local o = opps[i]
            if i == 6 or (not o and i == #opps + 1) then
                b.text:SetText("Challenge by name...")
                b:SetStyle("ghost")
                b:SetScript("OnClick", function() self:AskName() end)
                b:Show()
                if i ~= 6 then for j = i + 1, 6 do L.opps[j]:Hide() end break end
            elseif o then
                local r, gg, bl = ClassColor(o.class)
                b.text:SetText(("Challenge %s%s|r"):format(Hex(r, gg, bl), o.short))
                b:SetStyle(i == 1 and "primary" or nil)
                b:SetScript("OnClick", function()
                    L.wager:ClearFocus()
                    local ok, why = D:Challenge(o.full, self:Wager(), D.db.start)
                    if not ok then self:Hint(why) end
                end)
                b:Show()
            end
        end
        local s = D.db
        L.record:SetText(("%d wins   %d losses   net %s%s|r"):format(s.wins, s.losses, s.net >= 0 and "|cff3be870+" or "|cffd9534f-", D.Money(abs(s.net))))
        for _, t in ipairs(L.opts) do if t.Refresh then t:Refresh() end end
        if status == "" then status = "|cff9499b3Or type  /deathroll Name 50  to challenge anyone|r" end
        -- games going on that I could watch
        local wid = D.watchLatest
        local w = wid and D.watch[wid]
        if w and w.state == "play" and GetTime() - w.last < 180 then
            btns = { { ("Watch %s vs %s"):format(D.Short(w.name[w.a]), D.Short(w.name[w.b])), function() self.watchId = wid; self:Refresh(true) end } }
        end
    end
    self.status:SetText(status)
    self:SetButtons(btns)
end

function UI:AskName()
    if not StaticPopupDialogs then return end
    if not StaticPopupDialogs["FLIGHTBUDDY_DR_NAME"] then
        local function go(name)
            if name and name:match("%S") then
                local ok, why = D:Challenge(name, self:Wager(), D.db.start)
                if not ok then self:Hint(why) end
            end
        end
        StaticPopupDialogs["FLIGHTBUDDY_DR_NAME"] = {
            text = "Death Roll who? Type a character name.",
            button1 = "Challenge", button2 = CANCEL or "Cancel", hasEditBox = true, maxLetters = 48,
            OnAccept = function(popup)
                local eb = popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
                go(eb and eb:GetText())
            end,
            EditBoxOnEnterPressed = function(eb) go(eb:GetText()); eb:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    if StaticPopup_Show then StaticPopup_Show("FLIGHTBUDDY_DR_NAME") end
end

---------------------------------------------------------------------------
-- "Bob and Ann are death rolling": a small notice with a Watch button
---------------------------------------------------------------------------
function UI:Notice(w)
    if self:Visible() and not D.game and not self.watchId then self:Refresh() end
    if not self.toast then
        local t = CreateFrame("Frame", "FlightBuddyDeathRollToast", UIParent)
        t:SetSize(380, 58)
        t:SetPoint("TOP", UIParent, "TOP", 0, -220)
        t:SetFrameStrata("HIGH")
        W.Nine(t, "wood", 14)
        local icon = t:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 14, 0)
        if ART.icon then icon:SetTexture(Art("dr_icon")) else icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up") end
        t.l1 = W.Text(t, 13)
        t.l1:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
        t.l2 = W.Text(t, 11, W.FONT_NUM)
        t.l2:SetPoint("TOPLEFT", t.l1, "BOTTOMLEFT", 0, -4)
        t.l2:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        t.watch = W.Button(t, 64, 24, "Watch", "primary")
        t.watch:SetPoint("RIGHT", -12, 0)
        local no = W.Button(t, 24, 24, "X", "ghost")
        no:SetPoint("RIGHT", t.watch, "LEFT", -6, 0)
        no:SetScript("OnClick", function() t:Hide() end)
        t:SetScript("OnUpdate", function(fr, el)
            fr.left = (fr.left or 0) - el
            if fr.left < 1 then fr:SetAlpha(max(0, fr.left)) end
            if fr.left <= 0 then fr:Hide() end
        end)
        self.toast = t
    end
    local t = self.toast
    t.l1:SetText(("%s vs %s"):format(Tag(w, w.a), Tag(w, w.b)))
    t.l2:SetText((w.round > 1 and "Double or nothing: " or "Death Roll: ") .. (w.wager > 0 and D.Money(w.wager) or "for glory")
        .. ", from " .. W.Commas(w.start))
    t.watch:SetScript("OnClick", function()
        t:Hide()
        self.watchId = w.id
        self:Open()
    end)
    t.left = 9
    t:SetAlpha(1)
    t:Show()
    W.SFX("bucket", 1)
end
