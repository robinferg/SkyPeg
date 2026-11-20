-- Flight Buddy :: Shell.lua
-- The main window (a tavern games cabinet): hanging sign, game tabs, options, take-off prompt,
-- landing card, keyboard routing.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS
local Shell = {}
NS.Shell = Shell

local WIN_W, WIN_H = 580, 830
local CONTENT_X, CONTENT_Y = 30, -80   -- the cabinet screen

Shell.TABS = {
    { key = "home",  label = "Tavern", icon = "Interface\\Icons\\INV_Drink_04", sub = "The common room", neon = { 1.0, 0.8, 0.4 } },
    { key = "peg", short = "Runes",   label = "Rune Breaker", icon = "Interface\\Icons\\INV_Misc_Rune_01", sub = "Rune Breaker", neon = { 1.0, 0.55, 0.15 } },
    { key = "putt",  label = "Greens",    icon = "Interface\\Icons\\INV_Misc_Orb_01",        sub = "Daily putt", daily = true, neon = { 0.35, 0.95, 0.45 } },
    { key = "flap", short = "Gryphon",  label = "Featherbeard", icon = "Interface\\Icons\\Ability_Mount_Gryphon_01", sub = "Gryphon flight", neon = { 1.0, 0.75, 0.30 } },
    { key = "gem",   label = "Jewelcrafter", short = "Gems", icon = "Interface\\Icons\\INV_Misc_Gem_01", sub = "Jewelcrafter's Bench", daily = true, neon = { 0.6, 0.8, 1 } },
    { key = "pin",   label = "Pinball", icon = "Interface\\Icons\\Trade_Engineering", sub = "High Tinker Pinball", neon = { 1.0, 0.55, 0.20 } },
    { key = "roll",  label = "Death Roll", short = "Roll", icon = W.MEDIA .. "deathroll\\dr_icon", fullIcon = true, sub = "Death Roll", neon = { 1.0, 0.3, 0.25 } },
}

local function InCombat() return InCombatLockdown and InCombatLockdown() end

function Shell:Init(db)
    self.db = db
    self.mods = { home = NS.Home, peg = NS.Peg, putt = NS.PuttUI, flap = NS.FlapUI, pin = NS.PinballUI, gem = NS.GemsUI, roll = NS.DeathRollTab }
end

function Shell:IsShown() return self.frame and self.frame:IsShown() end

function Shell:AutoScale()
    local s = self.db.settings.scale
    if s then return s end
    local sh = (GetScreenHeight and GetScreenHeight()) or 768
    return math.max(0.6, math.min(1, sh * 0.92 / WIN_H))
end

function Shell:Build()
    local db = self.db
    local f = CreateFrame("Frame", "FlightBuddyFrame", UIParent)
    self.frame = f
    f:SetSize(WIN_W, WIN_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScale(self:AutoScale())
    if db.pos then
        f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    end
    f:Hide()
    tinsert(UISpecialFrames, "FlightBuddyFrame")

    -- the tavern games cabinet: carved oak with brass corners (512x733 of a 512x1024 texture)
    local cab = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    cab:SetTexture(W.TAVERN .. "tavern_frame")
    cab:SetAllPoints()
    cab:SetTexCoord(0, 1, 0, 733 / 1024)

    -- marquee doubles as the drag handle
    local tb = CreateFrame("Frame", nil, f)
    tb:SetPoint("TOPLEFT", 10, -6); tb:SetSize(WIN_W - 20, 70)
    tb:EnableMouse(true)
    tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() f:StartMoving() end)
    tb:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        db.pos = { p, rp, x, y }
    end)
    -- the hanging tavern sign: painted board with the name carved in gold
    local signF = CreateFrame("Frame", nil, f)
    signF:SetSize(340, 85)
    signF:SetPoint("TOP", f, "TOP", 0, 2)
    signF:SetFrameLevel(tb:GetFrameLevel() + 2)
    signF:EnableMouse(false)
    local sign = signF:CreateTexture(nil, "ARTWORK")
    sign:SetTexture(W.TAVERN .. "tavern_sign")
    sign:SetAllPoints()
    self.signText = W.Text(signF, 30, W.FONT_TITLE, "OUTLINE")
    self.signText:SetPoint("CENTER", 0, -4)
    self.signText:SetText("Flight Buddy")
    self.signText:SetTextColor(1, 0.84, 0.42)
    self.signSub = W.Text(signF, 9, W.FONT)
    self.signSub:SetPoint("TOP", self.signText, "BOTTOM", 0, -1)
    self.signSub:SetText("TAVERN  GAMES")
    self.signSub:SetTextColor(0.98, 0.86, 0.6)
    self.sign = signF

    -- lanterns either side of the sign, with candlelight that flickers
    self.glows = {}
    for i, x in ipairs({ 58, WIN_W - 58 }) do
        local glow = f:CreateTexture(nil, "ARTWORK", nil, 1)
        glow:SetTexture(W.TAVERN .. "candle_glow")
        glow:SetBlendMode("ADD")
        glow:SetSize(150, 150)
        glow:SetPoint("CENTER", f, "TOPLEFT", x, -46)
        local lan = f:CreateTexture(nil, "ARTWORK", nil, 3)
        lan:SetTexture(W.TAVERN .. "lantern")
        lan:SetSize(40, 40)
        lan:SetPoint("CENTER", f, "TOPLEFT", x, -40)
        self.glows[i] = glow
    end
    self.bulbs = {}
    self.bulbT = 0

    -- brass plate on the counter for the flight status
    local plateHost = CreateFrame("Frame", nil, f)
    plateHost:SetSize(230, 24)
    plateHost:SetPoint("CENTER", f, "TOP", 0, -811)
    self.plate = W.Three(plateHost, W.TAVERN .. "btn_brass", 12, "ARTWORK", 1)
    self.status = W.Text(plateHost, 11, W.FONT)
    self.status:SetPoint("CENTER", 0, 0)
    self.status:SetTextColor(0.24, 0.13, 0.04)
    self.status:SetShadowColor(1, 0.9, 0.6, 0.3)
    self.status:SetText((self.statusText or "Grounded"):upper())

    -- big red close button; sits above the marquee's drag handle so clicks reach it
    local close = CreateFrame("Button", nil, f)
    close:SetSize(30, 30)
    close:SetPoint("CENTER", f, "TOPRIGHT", -26, -26)
    close:SetFrameLevel(tb:GetFrameLevel() + 10)
    close:SetNormalTexture(W.TAVERN .. "knob_close")
    close:SetHighlightTexture(W.TAVERN .. "knob_close_hi")
    close:SetPushedTexture(W.TAVERN .. "knob_close_hi")
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function() W.Sound("IG_MAINMENU_CLOSE"); self:Close() end)
    close:SetScript("OnEnter", function(b)
        if GameTooltip then GameTooltip:SetOwner(b, "ANCHOR_BOTTOM"); GameTooltip:SetText("Close"); GameTooltip:Show() end
    end)
    close:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.closeButton = close
    local help = W.Button(f, 24, 22, "?", "ghost")
    help:SetPoint("LEFT", f, "TOPLEFT", 40, -811)
    local opts = W.Button(f, 70, 22, "OPTIONS", "ghost")
    opts:SetPoint("LEFT", help, "RIGHT", 6, 0)
    opts:SetScript("OnClick", function() self:ToggleOptions() end)
    help:SetScript("OnClick", function()
        if self.options:IsShown() then self:ToggleOptions() end
        local m = self.mods[self.tab]
        if m and m.ShowHelp then m:ShowHelp() end
    end)

    -- tabs: oak planks across the top; the chosen game's plank is lit like a brass-trimmed plaque
    self.tabButtons = {}
    local nTabs = #Shell.TABS
    local gap = 4
    local tabW = math.min(156, math.floor((WIN_W - 56 - gap * (nTabs - 1)) / nTabs))
    local x = math.floor((WIN_W - (tabW * nTabs + gap * (nTabs - 1))) / 2)
    for i, t in ipairs(Shell.TABS) do
        local b = W.Button(f, tabW, 28, "", "tab")
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -84)
        b.neon = t.neon
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 27, 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetText(t.short or t.label)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 8, 0)
        b.icon:SetTexture(t.icon)
        if t.fullIcon then b.icon:SetTexCoord(0, 1, 0, 1); b.icon:SetSize(18, 18) else b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        b.dot = W.Tex(b, "OVERLAY", "circle")
        b.dot:SetSize(7, 7)
        b.dot:SetPoint("RIGHT", -10, 0)
        b.dot:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3])
        b.dot:Hide()
        b:SetScript("OnClick", function() self:SelectTab(t.key) end)
        self.tabButtons[t.key] = b
        x = x + tabW + gap
    end

    -- content host; each game builds a 520x712 frame inside the cabinet screen
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, CONTENT_Y)
    content:SetSize(520, 712)
    self.content = content

    -- shell-level modal (landing) covering the play area
    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -110)
    area:SetSize(480, 560)
    area:SetFrameLevel(content:GetFrameLevel() + 40)
    self.area = area
    self.card = W.Card(f, area)
    self.card:SetFrameLevel(content:GetFrameLevel() + 60)
    self.card:HookScript("OnHide", function() self:UpdateModal() end)

    -- CRT bezel + glass over every game board (mouse passes through)
    local bezel = CreateFrame("Frame", nil, f)
    bezel:SetPoint("TOPLEFT", area, "TOPLEFT", -9, 9)
    bezel:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 9, -9)
    bezel:SetFrameLevel(content:GetFrameLevel() + 45)
    bezel:EnableMouse(false)
    local bz = bezel:CreateTexture(nil, "OVERLAY")
    bz:SetTexture(W.TAVERN .. "bezel_tavern")
    bz:SetPoint("TOPLEFT", -4, 4)
    bz:SetPoint("BOTTOMRIGHT", 4, -4)
    self.bezel = bezel

    self:BuildOptions(f)

    f:SetScript("OnUpdate", function(_, el) W.Guard("Shell", self.OnUpdate, self, el) end)
    f:SetScript("OnShow", function()
        W.Sound("IG_MAINMENU_OPEN")
        if not InCombat() and f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
        local m = self.mods[self.tab]
        if m and m.OnShow and m.frame then m:OnShow() end
    end)
    f:SetScript("OnHide", function()
        W.Sound("IG_MAINMENU_CLOSE")
        for _, m in pairs(self.mods) do if m.frame and m.OnHide then m:OnHide() end end
        if self.options then self.options:Hide() end
        self.card:Hide()
        self.pendingLand = false
        self.modal = false
    end)

    -- keyboard: each game decides which keys it wants; everything else passes through to WoW
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(frame, key)
        if InCombat() or not frame.SetPropagateKeyboardInput then return end
        local m = self.mods[self.tab]
        local used = false
        if not self:IsModal() and m and m.OnKey then used = m:OnKey(key) and true or false end
        frame:SetPropagateKeyboardInput(not used)
    end)
    f:SetScript("OnKeyUp", function(frame, key)
        if InCombat() or not frame.SetPropagateKeyboardInput then return end
        local m = self.mods[self.tab]
        if m and m.OnKeyUp then m:OnKeyUp(key) end
        frame:SetPropagateKeyboardInput(true)
    end)

    self:SelectTab("home")
end

function Shell:SelectTab(key)
    if not self.mods[key] then key = "home" end
    if self.options and self.options:IsShown() then self:ToggleOptions() end
    self.tab = key
    self.db.tab = key
    for k, m in pairs(self.mods) do
        if k ~= key and m.frame and m.frame:IsShown() then
            m.frame:Hide()
            if m.OnHide then m:OnHide() end
        end
    end
    local m = self.mods[key]
    if not m.frame then m:Build(self.content) end
    -- the wooden picture frame goes round game boards, not the tavern's common room
    if self.bezel then self.bezel:SetShown(key ~= "home" and key ~= "roll") end
    m.frame:Show()
    if m.OnShow then m:OnShow() end
    for k, b in pairs(self.tabButtons) do
        local on = k == key
        b:SetStyle(on and "tabOn" or "tab")
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
    end
    self:RefreshDots()
end

function Shell:RefreshDots()
    if not self.tabButtons then return end
    for _, t in ipairs(Shell.TABS) do
        local m = self.mods[t.key]
        local pending = t.daily and m.DailyPending and m:DailyPending()
        self.tabButtons[t.key].dot:SetShown(pending and true or false)
    end
end

function Shell:Open(reason, tab)
    if InCombat() then
        NS.Print("Can't open Flight Buddy in combat.")
        return
    end
    if not self.frame then self:Build() end
    self:HideToast()
    if tab then self:SelectTab(tab) end
    self.frame:Show()
    if reason == "flight" then
        local m = self.mods[self.tab]
        local spec = NS.Route and NS.Route.Flying()
        if m and m.Banner then
            if spec then
                m:Banner(spec.from .. "  >  " .. spec.to, ("This flight has its own %d-hole round of Gryphon Greens"):format(spec.holes), COLORS.gold)
            else
                m:Banner("Have a nice flight", "Pick a game - your progress is saved", COLORS.gold)
            end
        end
    end
end

function Shell:Close() if self.frame then self.frame:Hide() end end
function Shell:Toggle() if self:IsShown() then self:Close() else self:Open() end end

function Shell:UpdateModal()
    self.modal = self:IsModal()
end

-- Is a shell popup (landing card / options) really covering the games right now?
-- Asked live every time: a cached flag can go stale when the whole window hides,
-- because WoW tells the card it is hidden before the window's own cleanup runs.
function Shell:IsModal()
    if not (self.frame and self.frame:IsShown()) then return false end
    return (self.options and self.options:IsShown()) or (self.card and self.card:IsShown()) or false
end

function Shell:SetStatus(text, flying)
    self.statusText = text
    self.flying = flying and true or false
    if self.status then self.status:SetText(text:upper()) end
end

function Shell:OnUpdate(el)
    -- candlelight flickers in the lanterns
    self.bulbT = self.bulbT + el
    local still = NS.db.settings.reducedMotion
    for i, g in ipairs(self.glows or {}) do
        local t = self.bulbT * (6 + i) + i * 2
        local k = still and 0.8 or (0.72 + 0.12 * math.sin(t) + 0.08 * math.sin(t * 2.7 + 1) + 0.06 * math.sin(t * 5.3))
        g:SetAlpha(k)
    end
    -- landing countdown
    local o = self.card:IsShown() and self.card.opts
    if o and o.countdown then
        o.left = o.left - el
        self.card.card.body:SetText(o.body .. ("\n\n|cff9499b3Closing in %d...|r"):format(math.max(0, math.ceil(o.left))))
        if o.left <= 0 then
            self.card:Close()
            self:Close()
            return
        end
    end
    -- show the landing card once the current shot/turn settles
    if self.pendingLand then
        local m = self.mods[self.tab]
        if not (m and m.IsBusy and m:IsBusy()) and not self.card:IsShown() then
            self.pendingLand = false
            self:ShowLanded()
        end
    end
end

function Shell:ShowLanded()
    local zone = (GetZoneText and GetZoneText()) or ""
    local auto = self.db.settings.closeOnLand
    self.card:Open({
        title = "You've landed", color = COLORS.gold, center = true,
        body = ("Welcome to %s. Everything is saved for your next flight."):format(zone ~= "" and zone or "the ground"),
        countdown = auto, left = 6,
        buttons = {
            { "Keep playing" },
            { "Close", function() self:Close() end },
        },
    })
    self:UpdateModal()
end

function Shell:OnLanded()
    self:HideToast()
    if not self:IsShown() then return end
    self.pendingLand = true
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
local FLIGHT_MODES = { "auto", "ask", "off" }
local FLIGHT_LABELS = { auto = "Open automatically", ask = "Ask me", off = "Do nothing" }

function Shell:BuildOptions(f)
    local db = self.db
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -36)
    p:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -4, 4)
    p:SetFrameLevel(self.content:GetFrameLevel() + 50)
    p:EnableMouse(true)
    W.Panel(p, "wood")
    p:Hide()
    p:SetScript("OnHide", function() self:UpdateModal() end)
    self.options = p

    local title = W.Text(p, 24, W.FONT_TITLE, "OUTLINE")
    title:SetPoint("TOPLEFT", 28, -24)
    title:SetText("Options")
    title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    local y = -66
    local function Row(label, hint)
        local l = W.Text(p, 13)
        l:SetPoint("TOPLEFT", 28, y)
        l:SetText(label)
        if hint then
            local h = W.Text(p, 11, W.FONT_NUM)
            h:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
            h:SetText(hint)
            h:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        end
        local ry = y
        y = y - (hint and 48 or 36)
        return ry
    end
    local function AddToggle(label, hint, key, after)
        local ry = Row(label, hint)
        local t = W.Toggle(p, function() return db.settings[key] end, function(v) db.settings[key] = v; if after then after(v) end end)
        t:SetPoint("TOPRIGHT", -28, ry + 2)
    end
    local function Section(text)
        local s = W.Text(p, 14, W.FONT_TITLE)
        s:SetPoint("TOPLEFT", 28, y - 4)
        s:SetText(text)
        s:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
        y = y - 24
    end

    Section("Flying")
    local ry = Row("When I take a flight", "Flight Buddy can pop up as you leave the flight master")
    local mode = W.Button(p, 150, 24, FLIGHT_LABELS[db.settings.onFlight] or FLIGHT_LABELS.auto)
    mode:SetPoint("TOPRIGHT", -28, ry + 4)
    mode:SetScript("OnClick", function(b)
        local idx = 1
        for i, m in ipairs(FLIGHT_MODES) do if m == db.settings.onFlight then idx = i end end
        db.settings.onFlight = FLIGHT_MODES[idx % #FLIGHT_MODES + 1]
        b.text:SetText(FLIGHT_LABELS[db.settings.onFlight])
        W.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    end)
    AddToggle("Close when I land", "Short countdown, then everything is saved", "closeOnLand")

    Section("General")
    AddToggle("Share my scores", "Leaderboards with your friends, guild and group", "share")
    AddToggle("Realm leaderboards", "Everyone on your realm who runs Flight Buddy", "realmBoards", function(v)
        if v then NS.Social:JoinRealm() else NS.Social:LeaveRealm() end
    end)
    AddToggle("Sound effects", nil, "sound")
    AddToggle("Reduced motion", "No screen shake, slow-mo or trails", "reducedMotion")
    AddToggle("Rune Breaker: Space bar shoots", nil, "space")
    AddToggle("Rune Breaker: glyphs", "Extra shapes on crystals and titan runes", "symbols", function()
        if NS.Peg.RestyleAll then NS.Peg:RestyleAll() end
    end)

    local sy = Row("Window size")
    local val = W.Text(p, 13, W.FONT_NUM)
    local function SetScaleBy(d)
        local cur = self:AutoScale()
        local s = math.floor((cur + d) * 20 + 0.5) / 20
        s = math.max(0.6, math.min(1.5, s))
        if d ~= 0 then db.settings.scale = s end
        f:SetScale(s)
        val:SetText(math.floor(s * 100 + 0.5) .. "%")
    end
    local plus = W.Button(p, 28, 24, "+")
    plus:SetPoint("TOPRIGHT", -28, sy + 4)
    plus:SetScript("OnClick", function() SetScaleBy(0.05) end)
    val:SetPoint("RIGHT", plus, "LEFT", -10, 0)
    local minus = W.Button(p, 28, 24, "-")
    minus:SetPoint("RIGHT", val, "LEFT", -10, 0)
    minus:SetScript("OnClick", function() SetScaleBy(-0.05) end)
    SetScaleBy(0)

    local stats = W.Text(p, 11, W.FONT_NUM)
    stats:SetPoint("BOTTOMLEFT", 28, 70)
    stats:SetJustifyH("LEFT")
    if stats.SetSpacing then stats:SetSpacing(2) end
    self.statsText = stats

    local reset = W.Button(p, 160, 30, "New Rune Breaker run")
    reset:SetPoint("BOTTOMLEFT", 28, 22)
    reset:SetScript("OnClick", function(b)
        if b.confirm then
            b.confirm = false
            b.text:SetText("New Rune Breaker run")
            self:ToggleOptions()
            NS.Peg:NewRun()
            self:SelectTab("peg")
        else
            b.confirm = true
            b.text:SetText("Click to confirm")
        end
    end)
    self.resetButton = reset
    local done = W.Button(p, 140, 30, "Done", "primary")
    done:SetPoint("BOTTOMRIGHT", -28, 22)
    done:SetScript("OnClick", function() self:ToggleOptions() end)
end

function Shell:ToggleOptions()
    local p = self.options
    if p:IsShown() then
        p:Hide()
    else
        local db = self.db
        local ps, pt, fl, pn = db.peg.stats or {}, db.putt or {}, db.flap or {}, db.pin or {}
        self.statsText:SetText(table.concat({
            ("|cffffcc40Flights|r %s"):format(W.Commas(db.stats.flights or 0)),
            ("|cffffcc40Rune Breaker|r  best level score %s   levels cleared %s   shots %s"):format(W.Commas(db.peg.bestLevelScore or 0), W.Commas(ps.levels or 0), W.Commas(ps.shots or 0)),
            ("|cffffcc40Greens|r  holes %s   aces %s   dailies %s"):format(W.Commas(pt.holes or 0), W.Commas(pt.aces or 0), W.Commas(pt.dailies or 0)),
            ("|cffffcc40Featherbeard|r  best %s   flights %s"):format(W.Commas(fl.best or 0), W.Commas(fl.games or 0)),
            ("|cffffcc40High Tinker Pinball|r  best %s   games %s"):format(W.Commas(pn.best or 0), W.Commas(pn.games or 0)),
        }, "\n"))
        self.resetButton.confirm = false
        self.resetButton.text:SetText("New Rune Breaker run")
        p:Show()
    end
    self:UpdateModal()
end

---------------------------------------------------------------------------
-- Take-off prompt ("Ask me" mode)
---------------------------------------------------------------------------
function Shell:ShowToast()
    if not self.toast then
        local t = CreateFrame("Frame", "FlightBuddyToast", UIParent)
        t:SetSize(350, 64)
        t:SetPoint("TOP", UIParent, "TOP", 0, -150)
        t:SetFrameStrata("HIGH")
        W.Nine(t, "wood", 14)
        local icon = t:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\Minimap\\Tracking\\FlightMaster")
        icon:SetSize(26, 26)
        icon:SetPoint("LEFT", 16, 0)
        local l1 = W.Text(t, 14)
        l1:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
        l1:SetText("Long flight ahead?")
        t.l2 = W.Text(t, 11, W.FONT_NUM)
        t.l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
        t.l2:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        local play = W.Button(t, 60, 24, "Play", "primary")
        play:SetPoint("RIGHT", -12, 0)
        play:SetScript("OnClick", function() self:Open("flight") end)
        local no = W.Button(t, 24, 24, "X", "ghost")
        no:SetPoint("RIGHT", play, "LEFT", -6, 0)
        no:SetScript("OnClick", function() self:HideToast() end)
        t:SetScript("OnUpdate", function(frame, el)
            frame.left = (frame.left or 0) - el
            if frame.left < 1 then frame:SetAlpha(math.max(0, frame.left)) end
            if frame.left <= 0 then frame:Hide() end
        end)
        self.toast = t
    end
    local pend = {}
    for _, tb in ipairs(Shell.TABS) do
        local m = self.mods[tb.key]
        if tb.daily and m and m.DailyPending and m:DailyPending() then pend[#pend + 1] = tb.label end
    end
    self.toast.l2:SetText(#pend > 0 and ("Today's " .. table.concat(pend, " & ") .. " daily is waiting") or "Play a round while you fly")
    self.toast.left = 20
    self.toast:SetAlpha(1)
    self.toast:Show()
    W.Sound("IG_PLAYER_INVITE")
end

function Shell:HideToast()
    if self.toast then self.toast:Hide() end
end
