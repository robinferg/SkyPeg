-- Flight Buddy :: Board.lua
-- Shared leaderboard panel: Today / All-time, for your Friends, your Guild or the whole Realm.
-- A game can offer several boards (spec.views), flipped through with the arrows.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS

local ROWS = 13
local FILTERS = { { "friend", "Friends" }, { "guild", "Guild" }, { "realm", "Realm" } }
local SRC_LABEL = { friend = "friend", guild = "guild", group = "group", realm = "realm" }

-- parent: the game frame; area: the 480x560 board the panel covers
function NS.NewBoardPanel(parent, area)
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", area, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    p:SetFrameLevel(area:GetFrameLevel() + 30)
    p:EnableMouse(true)
    W.Panel(p, "wood")
    p:Hide()

    p.title = W.Text(p, 22, W.FONT_TITLE)
    p.title:SetPoint("TOPLEFT", 22, -18)
    p.title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    p.sub = W.Text(p, 11, W.FONT_NUM)
    p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -5)
    p.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    -- period (Today / All-time) and who (Everyone / Friends / Guild / Realm)
    p.periodBtns = {}
    for i, per in ipairs({ { "day", "Today" }, { "all", "All-time" } }) do
        local b = W.Button(p, 74, 22, per[2], "tab")
        b:SetPoint("TOPRIGHT", -22 - (2 - i) * 78, -16)
        b:SetScript("OnClick", function() p.period = per[1]; p:Query(); p:Fill() end)
        b.key = per[1]
        p.periodBtns[i] = b
    end
    p.filterBtns = {}
    for i, fl in ipairs(FILTERS) do
        local b = W.Button(p, 78, 22, fl[2], "tab")
        b:SetPoint("TOPRIGHT", -22 - (#FILTERS - i) * 82, -60)
        b:SetScript("OnClick", function()
            p.filter = fl[1]
            if NS.db and NS.db.settings then NS.db.settings.boardFilter = fl[1] end
            if fl[1] ~= "realm" then NS.Social:RefreshPeople(true) end
            p:Fill()
        end)
        b.key = fl[1]
        p.filterBtns[i] = b
    end
    -- which board (when a game has several): < Daily course >
    p.viewPrev = W.Button(p, 24, 22, "<", "ghost")
    p.viewPrev:SetPoint("TOPLEFT", 22, -60)
    p.viewNext = W.Button(p, 24, 22, ">", "ghost")
    p.viewNext:SetPoint("TOPLEFT", 176, -60)
    p.viewLabel = W.Text(p, 12)
    p.viewLabel:SetPoint("LEFT", p.viewPrev, "RIGHT", 4, 0)
    p.viewLabel:SetPoint("RIGHT", p.viewNext, "LEFT", -4, 0)
    p.viewLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    local function Step(d)
        local views = p.base and p.base.views
        if not views then return end
        p.viewIdx = (p.viewIdx - 1 + d) % #views + 1
        p:ApplyView()
        p:Query()
        p:Fill()
        W.SFX("pop1")
    end
    p.viewPrev:SetScript("OnClick", function() Step(-1) end)
    p.viewNext:SetScript("OnClick", function() Step(1) end)

    p.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, p)
        r:SetSize(436, 26)
        r:SetPoint("TOPLEFT", 22, -94 - (i - 1) * 28)
        r.bg = W.Solid(r, "BACKGROUND", 1, 1, 1, i % 2 == 0 and 0.03 or 0.0)
        r.bg:SetAllPoints()
        r.rank = W.Text(r, 13, W.FONT_NUM); r.rank:SetPoint("LEFT", 6, 0); r.rank:SetWidth(26); r.rank:SetJustifyH("RIGHT")
        r.name = W.Text(r, 13); r.name:SetPoint("LEFT", 42, 0); r.name:SetWidth(160); r.name:SetJustifyH("LEFT")
        r.src = W.Text(r, 10, W.FONT_NUM); r.src:SetPoint("LEFT", 206, 0); r.src:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        r.detail = W.Text(r, 12, W.FONT_NUM); r.detail:SetPoint("RIGHT", -96, 0); r.detail:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        r.score = W.Text(r, 14, W.FONT_NUM); r.score:SetPoint("RIGHT", -8, 0)
        p.rows[i] = r
    end
    p.empty = W.Text(p, 13)
    p.empty:SetPoint("TOP", 0, -150)
    p.empty:SetWidth(380)
    p.empty:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    p.foot = W.Text(p, 11, W.FONT_NUM)
    p.foot:SetPoint("BOTTOMLEFT", 22, 58)
    p.foot:SetWidth(436)
    p.foot:SetJustifyH("LEFT")
    p.foot:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    p.refresh = W.Button(p, 120, 30, "Refresh")
    p.refresh:SetPoint("BOTTOMLEFT", 22, 18)
    p.post = W.Button(p, 140, 30, "Post to guild")
    p.post:SetPoint("BOTTOM", 0, 18)
    p.close = W.Button(p, 120, 30, "Back", "primary")
    p.close:SetPoint("BOTTOMRIGHT", -22, 18)
    p.close:SetScript("OnClick", function() p:Hide(); if p.base and p.base.onClose then p.base.onClose() end end)

    function p:Day()
        local spec = self.spec
        if self.period == "all" then return "all" end
        return spec.day or NS.Social.Today()
    end

    function p:Query()
        NS.Social:Query(self.spec.game, self:Day())
    end

    -- spec = { game=, day=, periods=true (Today and All-time), title=, sub=, fmt=function(entry) return scoreText, detailText end,
    --          empty=, onPost=function() end or nil, onClose=function() end or nil,
    --          views = { { label=, game=, day=, periods=, period=, title=, sub=, fmt=, empty=, onPost= }, ... }, view = index }
    -- each view's fields override the spec's while it is showing
    function p:ApplyView()
        local base = self.base
        local v = base.views and base.views[self.viewIdx]
        local spec = setmetatable({}, { __index = base })
        if v then for k, val in pairs(v) do spec[k] = val end end
        self.spec = spec
        self.period = (spec.periods and self.period == "all") and "all" or (spec.period or "day")
        self.title:SetText(spec.title or "")
        self.sub:SetText(spec.sub or "")
        for _, b in ipairs(self.periodBtns) do b:SetShown(spec.periods and true or false) end
        local multi = base.views and #base.views > 1
        self.viewPrev:SetShown(multi and true or false)
        self.viewNext:SetShown(multi and true or false)
        self.viewLabel:SetShown(v ~= nil)
        self.viewLabel:SetText(v and v.label or "")
        self.post:SetShown(spec.onPost ~= nil and IsInGuild and IsInGuild() and true or false)
        self.post:SetScript("OnClick", function() if self.spec.onPost then self.spec.onPost() end end)
    end

    function p:Open(spec)
        self.base = spec
        self.viewIdx = spec.view or 1
        self.period = spec.period or "day"
        local saved = NS.db and NS.db.settings and NS.db.settings.boardFilter
        self.filter = self.filter or saved or "realm"
        if self.filter == "all" or self.filter == "group" then self.filter = "realm" end
        NS.Social:RefreshPeople(true)
        self:ApplyView()
        self:Query()
        self.refresh:SetScript("OnClick", function() NS.Social:RefreshPeople(true); self:Query(); self:Fill() end)
        self:Fill()
        self:Show()
    end

    function p:Fill()
        local spec = self.spec
        if not spec then return end
        local day = self:Day()
        for _, b in ipairs(self.periodBtns) do b:SetStyle(b.key == self.period and "tabOn" or "tab") end
        for _, b in ipairs(self.filterBtns) do b:SetStyle(b.key == self.filter and "tabOn" or "tab") end
        local list = NS.Social:Board(spec.game, day, self.filter)
        local myIdx
        for i, e in ipairs(list) do if e.me then myIdx = i end end
        -- always keep your own row visible
        local first = 1
        if myIdx and myIdx > ROWS then first = myIdx - ROWS + 1 end
        for i, r in ipairs(self.rows) do
            local idx = first + i - 1
            local e = list[idx]
            if e then
                local sc, dt = spec.fmt(e)
                r.rank:SetText(idx)
                r.name:SetText(e.me and ("|cffffcc40" .. e.short .. " (you)|r") or e.short)
                r.src:SetText(e.me and "" or (SRC_LABEL[e.src] or ""))
                r.detail:SetText(dt or "")
                r.score:SetText(sc)
                local medal = (idx == 1 and COLORS.gold) or (idx == 2 and { 0.8, 0.82, 0.88 }) or (idx == 3 and { 0.85, 0.55, 0.3 }) or COLORS.text
                r.rank:SetTextColor(medal[1], medal[2], medal[3])
                r.bg:SetColorTexture(1, 1, 1, e.me and 0.08 or (i % 2 == 0 and 0.03 or 0))
                r:Show()
            else
                r:Hide()
            end
        end
        local none = #list == 0 or (#list == 1 and list[1].me)
        self.empty:SetShown(none)
        local emptyText = spec.empty or "No results yet."
        if #list == 1 then emptyText = "Just you so far." end
        if self.filter == "friend" then emptyText = (#list == 1 and "Just you so far. " or "") .. "None of your friends with Flight Buddy have a result here yet."
        elseif self.filter == "guild" then emptyText = (IsInGuild and IsInGuild()) and ((#list == 1 and "Just you so far. " or "") .. "No guildmates on this board yet.") or "You're not in a guild."
        elseif self.filter == "realm" and #list == 0 then emptyText = NS.Social:RealmEnabled() and "Nobody on the realm board yet. Results arrive as other Flight Buddy players play." or "Realm boards are turned off in Options." end
        self.empty:SetText(emptyText)
        local foot
        if self.period == "all" then
            foot = "All-time bests from everyone you've heard from. Ask again with Refresh."
        else
            local secs = NS.Social.SecondsToReset()
            foot = ("Today's board resets in %dh %02dm."):format(math.floor(secs / 3600), math.floor(secs % 3600 / 60))
        end
        local who = { "online friends" }
        if IsInGuild and IsInGuild() then who[#who + 1] = "guild" end
        if IsInGroup and IsInGroup() then who[#who + 1] = "group" end
        if self.filter == "realm" and not NS.Social:RealmEnabled() then who[#who + 1] = "(realm sharing is off)" end
        if NS.Social:RealmEnabled() then who[#who + 1] = "realm" end
        self.foot:SetText(foot .. "  Shared with your " .. table.concat(who, ", ") .. ".")
    end

    NS.Social.listeners[#NS.Social.listeners + 1] = function(game, day)
        if p:IsShown() and p.spec and p.spec.game == game and p:Day() == day then p:Fill() end
    end
    return p
end
