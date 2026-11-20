-- Flight Buddy :: Menu.lua
-- The pre-game menu every game shares: a title, a few lines about your progress, big buttons
-- (Play / Resume, Hero, Leaderboard, How to play) and an options list with on/off switches.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS

local MAX_BUTTONS = 6
local MAX_OPTIONS = 6
local floor, ceil, max = math.floor, math.ceil, math.max

-- parent: the game frame; area: the 480x560 board the menu covers
function NS.NewMenuPanel(parent, area)
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", area, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    p:SetFrameLevel(area:GetFrameLevel() + 25)
    p:EnableMouse(true)
    W.Panel(p, "wood")
    p:Hide()

    -- game icon set in a brass-rimmed oak coaster
    p.coaster = p:CreateTexture(nil, "BORDER")
    p.coaster:SetTexture(W.TAVERN .. "coaster")
    p.coaster:SetSize(62, 62)
    p.coaster:SetPoint("TOPLEFT", 20, -18)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(38, 38)
    p.icon:SetPoint("CENTER", p.coaster, "CENTER")
    p.title = W.Text(p, 26, W.FONT_TITLE, "OUTLINE")
    p.title:SetPoint("TOPLEFT", p.coaster, "TOPRIGHT", 10, -6)
    p.sub = W.Text(p, 11, W.FONT)
    p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
    p.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
    -- brass rule under the header
    p.rule = W.Solid(p, "ARTWORK", COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.55)
    p.rule:SetHeight(2)
    p.rule:SetPoint("TOPLEFT", 26, -88)
    p.rule:SetPoint("TOPRIGHT", -26, -88)
    p.ruleShade = W.Solid(p, "ARTWORK", 0, 0, 0, 0.5)
    p.ruleShade:SetHeight(1)
    p.ruleShade:SetPoint("TOPLEFT", p.rule, "BOTTOMLEFT")
    p.ruleShade:SetPoint("TOPRIGHT", p.rule, "BOTTOMRIGHT")
    p.lines = W.Text(p, 12, W.FONT)
    p.lines:SetPoint("TOPLEFT", 28, -100)
    p.lines:SetWidth(428)
    p.lines:SetJustifyH("LEFT")
    if p.lines.SetSpacing then p.lines:SetSpacing(4) end

    p.buttons = {}
    for i = 1, MAX_BUTTONS do
        local b = W.Button(p, 204, 34, "")
        p.buttons[i] = b
    end
    p.optTitle = W.Text(p, 15, W.FONT_TITLE)
    p.optTitle:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    p.optTitle:SetText("Options")
    p.options = {}
    for i = 1, MAX_OPTIONS do
        local o = CreateFrame("Button", nil, p)
        o:SetSize(428, 24)
        -- an oak box with a brass rim; ticked = a brass stud in it
        o.rim = W.Solid(o, "BORDER", 0.62, 0.47, 0.2, 1)
        o.rim:SetSize(18, 18)
        o.rim:SetPoint("LEFT", 0, 0)
        o.box = W.Solid(o, "ARTWORK", 0.13, 0.08, 0.04, 1)
        o.box:SetSize(14, 14)
        o.box:SetPoint("CENTER", o.rim, "CENTER")
        o.check = o:CreateTexture(nil, "OVERLAY")
        o.check:SetTexture(W.TAVERN .. "tack")
        o.check:SetSize(16, 16)
        o.check:SetPoint("CENTER", o.box, "CENTER")
        o.label = W.Text(o, 12, W.FONT)
        o.label:SetPoint("LEFT", o.rim, "RIGHT", 10, 0)
        o.label:SetJustifyH("LEFT")
        o.hl = W.Solid(o, "HIGHLIGHT", 1, 0.85, 0.5, 0.06)
        o.hl:SetAllPoints()
        p.options[i] = o
    end

    -- spec = { title=, sub=, icon=, color=, lines={...}, buttons={ {label, fn, style} }, options={ {label, get, set} } }
    function p:Open(spec)
        self.spec = spec
        local c = spec.color or COLORS.gold
        self.title:SetText(spec.title or "")
        self.title:SetTextColor(c[1], c[2], c[3])
        self.sub:SetText(spec.sub or "")
        self.icon:SetTexture(spec.icon)
        self.icon:SetShown(spec.icon ~= nil)
        self.lines:SetText(table.concat(spec.lines or {}, "\n"))
        -- buttons in two columns under the text
        local top = -108 - max(1, #(spec.lines or {})) * 17
        for i, b in ipairs(self.buttons) do
            local s = spec.buttons and spec.buttons[i]
            if s then
                b.text:SetText(s[1])
                b:SetStyle(s[3] or (i == 1 and "primary" or nil))
                b:SetScript("OnClick", function() if not s.keepOpen then self:Hide() end if s[2] then s[2]() end end)
                b:ClearAllPoints()
                local col, row = (i - 1) % 2, floor((i - 1) / 2)
                b:SetPoint("TOPLEFT", 26 + col * 222, top - row * 42)
                b:Show()
            else
                b:Hide()
            end
        end
        local nb = spec.buttons and #spec.buttons or 0
        local otop = top - ceil(nb / 2) * 42 - 14
        local opts = spec.options or {}
        self.optTitle:SetShown(#opts > 0)
        self.optTitle:ClearAllPoints()
        self.optTitle:SetPoint("TOPLEFT", 26, otop)
        for i, o in ipairs(self.options) do
            local s = opts[i]
            if s then
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", 26, otop - 20 - (i - 1) * 28)
                o.label:SetText(s[1])
                o.check:SetShown(s[2]() and true or false)
                o:SetScript("OnClick", function()
                    s[3](not s[2]())
                    o.check:SetShown(s[2]() and true or false)
                    W.SFX("pop1")
                end)
                o:Show()
            else
                o:Hide()
            end
        end
        self:Show()
    end
    return p
end

-- the options every game's menu shows
function NS.CommonOptions()
    local st = NS.db.settings
    return {
        { "Sound effects", function() return st.sound end, function(v) st.sound = v end },
        { "Reduced motion (less shake and fewer particles)", function() return st.reducedMotion end, function(v) st.reducedMotion = v end },
        { "Share my scores with friends and guild", function() return st.share ~= false end, function(v) st.share = v end },
        { "Realm leaderboards (everyone on your realm with Flight Buddy)", function() return st.realmBoards ~= false end,
          function(v) st.realmBoards = v; if v then NS.Social:JoinRealm() else NS.Social:LeaveRealm() end end },
    }
end
