-- Flight Buddy :: Widgets.lua
-- Shared look-and-feel helpers for every game panel.
local ADDON, NS = ...

local W = {}
NS.W = W

W.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
W.FONT = "Fonts\\FRIZQT__.TTF"
W.FONT_NUM = "Fonts\\ARIALN.TTF"
W.FONT_TITLE = "Fonts\\MORPHEUS.TTF"
W.TAVERN = W.MEDIA .. "tavern\\"

-- the tavern palette: candlelit parchment text on dark oak, brass and ale-gold accents
W.COLORS = {
    gold   = { 1.00, 0.82, 0.38 }, accent = { 0.95, 0.66, 0.24 },
    text   = { 0.96, 0.91, 0.80 }, dim    = { 0.72, 0.63, 0.50 },
    panel  = { 0.16, 0.10, 0.06 },
    green  = { 0.46, 0.80, 0.38 }, yellow = { 0.90, 0.74, 0.28 }, gray = { 0.32, 0.25, 0.18 },
    red    = { 0.92, 0.36, 0.28 }, blue = { 0.45, 0.68, 1.0 },
    ink    = { 0.22, 0.13, 0.06 }, chalk = { 0.93, 0.95, 0.90 },
}
local COLORS = W.COLORS

-- 1,250,000 -> "1.25M", 230000 -> "230k"
function W.Short(n)
    n = n or 0
    if n >= 1e6 then return (("%.2f"):format(n / 1e6):gsub("%.?0+$", "")) .. "M" end
    if n >= 1e4 then return math.floor(n / 1000 + 0.5) .. "k" end
    return W.Commas(n)
end

function W.Commas(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return (n < 0 and "-" or "") .. out
end

function W.Tex(parent, layer, file, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(W.MEDIA .. file) end
    return t
end

function W.Solid(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function W.Text(parent, size, font, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or W.FONT, size, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.75)
    fs:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    return fs
end

-- A group of textures that behaves like one (SetVertexColor, Show, Hide, SetAlpha... hit them all)
local Group = {}
Group.__index = function(g, k)
    if type(k) ~= "string" then return nil end
    return function(self, ...)
        local r
        for _, t in ipairs(self) do r = t[k](t, ...) end
        return r
    end
end

-- Nine-slice panel from a square atlas (corners are `frac` of the atlas), drawn with on-screen corners `edge` px.
-- kind: "wood" (dark oak, brass trim), "parch" (parchment), "chalk" (chalkboard in a wooden frame)
local NINE = { wood = "panel_wood", parch = "panel_parch", chalk = "panel_chalk" }
function W.Nine(f, kind, edge, layer, sub, frac)
    local file = W.TAVERN .. (NINE[kind] or kind)
    edge = edge or 16
    frac = frac or 0.25
    layer = layer or "BACKGROUND"
    sub = sub or -7
    local parts = setmetatable({}, Group)
    local cut = { 0, frac, 1 - frac, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            local t = f:CreateTexture(nil, layer, nil, sub)
            t:SetTexture(file)
            t:SetTexCoord(cut[col], cut[col + 1], cut[row], cut[row + 1])
            local l = col == 1 and "LEFT" or (col == 3 and "RIGHT" or nil)
            local tp = row == 1 and "TOP" or (row == 3 and "BOTTOM" or nil)
            -- corners: fixed size; edges stretch one way; the middle fills
            if l and tp then
                t:SetSize(edge, edge)
                t:SetPoint(tp .. l, f, tp .. l)
            elseif tp then
                t:SetHeight(edge)
                t:SetPoint(tp .. "LEFT", f, tp .. "LEFT", edge, 0)
                t:SetPoint(tp .. "RIGHT", f, tp .. "RIGHT", -edge, 0)
            elseif l then
                t:SetWidth(edge)
                t:SetPoint("TOP" .. l, f, "TOP" .. l, 0, -edge)
                t:SetPoint("BOTTOM" .. l, f, "BOTTOM" .. l, 0, edge)
            else
                t:SetPoint("TOPLEFT", f, "TOPLEFT", edge, -edge)
                t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -edge, edge)
            end
            parts[#parts + 1] = t
        end
    end
    return parts
end

-- Three-slice horizontal bar (buttons): caps are `frac` of the atlas width, drawn `cap` px wide.
function W.Three(f, file, cap, layer, sub, frac)
    frac = frac or 0.14
    local parts = setmetatable({}, Group)
    local cut = { 0, frac, 1 - frac, 1 }
    for i = 1, 3 do
        local t = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t:SetTexture(file)
        t:SetTexCoord(cut[i], cut[i + 1], 0, 1)
        if i == 1 then
            t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(cap)
        elseif i == 3 then
            t:SetPoint("TOPRIGHT"); t:SetPoint("BOTTOMRIGHT"); t:SetWidth(cap)
        else
            t:SetPoint("TOPLEFT", cap, 0); t:SetPoint("BOTTOMRIGHT", -cap, 0)
        end
        parts[i] = t
    end
    function parts:SetFile(file2) for _, t in ipairs(self) do t:SetTexture(file2) end end
    return parts
end

-- The standard background for a panel that covers a game board
function W.Panel(f, kind)
    return W.Nine(f, kind or "wood", 22, "BACKGROUND", -7)
end

function W.Border(f, a)
    local function edge() return W.Solid(f, "BORDER", 1, 1, 1, a) end
    local t = edge(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    local b = edge(); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    local l = edge(); l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    local r = edge(); r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

function W.Button(parent, w, h, label, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local cap = math.min(math.floor(h * 0.55), math.floor(w / 2))
    -- tavern buttons: a brass plate (primary), an oak plank (default) or a dark stained plank (ghost)
    b.bg = W.Three(b, W.TAVERN .. "btn_wood", cap, "BACKGROUND", 0)
    b.hl = W.Three(b, W.TAVERN .. "btn_wood", cap, "HIGHLIGHT", 0)
    b.hl:SetBlendMode("ADD")
    b.hl:SetVertexColor(1, 0.85, 0.55, 0.22)
    b.text = W.Text(b, h >= 26 and 13 or 11)
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(label or "")
    local FILES = { primary = "btn_brass", ghost = "btn_dark", tab = "btn_dark", tabOn = "btn_plaque" }
    function b:SetStyle(st)
        self.style = st
        local file = W.TAVERN .. (FILES[st] or "btn_wood")
        self.bg:SetFile(file)
        self.hl:SetFile(file)
        self.bg:SetVertexColor(1, 1, 1, 1)
        if st == "primary" then
            self.text:SetTextColor(0.20, 0.11, 0.03)
            self.text:SetShadowColor(1, 0.9, 0.6, 0.35)
        elseif st == "ghost" then
            self.text:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
            self.text:SetShadowColor(0, 0, 0, 0.8)
        elseif st == "tab" then
            self.bg:SetVertexColor(1, 1, 1, 0.75)
            self.text:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
            self.text:SetShadowColor(0, 0, 0, 0.8)
        elseif st == "tabOn" then
            self.text:SetTextColor(1, 0.92, 0.7)
            self.text:SetShadowColor(0, 0, 0, 0.85)
        else
            self.text:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
            self.text:SetShadowColor(0, 0, 0, 0.85)
        end
    end
    b:SetStyle(style)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    return b
end

function W.Toggle(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(40, 20)
    b.bg = W.Tex(b, "BACKGROUND", "pill"); b.bg:SetAllPoints()
    b.knob = W.Tex(b, "ARTWORK", "circle"); b.knob:SetSize(16, 16)
    function b:Refresh()
        if get() then
            self.bg:SetVertexColor(0.86, 0.66, 0.26)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("CENTER", self, "RIGHT", -10, 0)
        else
            self.bg:SetVertexColor(0.30, 0.20, 0.12)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("CENTER", self, "LEFT", 10, 0)
        end
    end
    b:SetScript("OnClick", function(self) set(not get()); self:Refresh(); W.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON") end)
    b:Refresh()
    return b
end

local throttle = {}
W.SOUNDS = "Interface\\AddOns\\" .. ADDON .. "\\Sounds\\"
-- plays one of our own .ogg effects (falls back silently if the client can't)
function W.SFX(file, gap)
    local db = NS.db
    if not db or not db.settings.sound then return end
    if gap then
        local now = GetTime()
        if now - (throttle[file] or 0) < gap then return end
        throttle[file] = now
    end
    if PlaySoundFile then pcall(PlaySoundFile, W.SOUNDS .. file .. ".ogg", "SFX") end
end

function W.Sound(name, gap)
    local db = NS.db
    if not db or not db.settings.sound then return end
    if gap then
        local now = GetTime()
        if now - (throttle[name] or 0) < gap then return end
        throttle[name] = now
    end
    local id = SOUNDKIT and SOUNDKIT[name]
    if id then pcall(PlaySound, id, "SFX") end
end

-- A modal card that sits over a game board: { title, body, color, center, buttons = {{label, fn, style}} }
function W.Card(parent, board)
    local ov = CreateFrame("Frame", nil, parent)
    ov:SetPoint("TOPLEFT", board, "TOPLEFT")
    ov:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT")
    ov:SetFrameLevel(board:GetFrameLevel() + 20)
    ov:EnableMouse(true)
    local dim = W.Solid(ov, "BACKGROUND", 0.04, 0.02, 0.01, 0.66)
    dim:SetAllPoints()
    ov:Hide()
    local card = CreateFrame("Frame", nil, ov)
    card:SetWidth(380)
    card:SetPoint("CENTER", 0, 10)
    W.Panel(card, "wood")
    card.accent = W.Solid(card, "ARTWORK", 1, 1, 1, 0)
    card.accent:SetPoint("TOPLEFT"); card.accent:SetPoint("TOPRIGHT"); card.accent:SetHeight(1)
    card.title = W.Text(card, 22, W.FONT_TITLE)
    card.title:SetPoint("TOP", 0, -24)
    card.body = W.Text(card, 13)
    card.body:SetPoint("TOP", card.title, "BOTTOM", 0, -12)
    card.body:SetWidth(330)
    if card.body.SetSpacing then card.body:SetSpacing(3) end
    card.buttons = {}
    for i = 1, 9 do card.buttons[i] = W.Button(card, 110, 30, "") end
    ov.card = card

    function ov:Open(o)
        local c = o.color or COLORS.gold
        card.title:SetText(o.title or "")
        card.title:SetTextColor(c[1], c[2], c[3])
        card.accent:SetColorTexture(c[1], c[2], c[3], 0)
        card.body:SetJustifyH(o.center and "CENTER" or "LEFT")
        card.body:SetText(o.body or "")
        local bh = math.max(30, card.body:GetStringHeight() or 0)
        local btns = o.buttons or {}
        local n = #btns
        local bw = n >= 3 and 106 or 140
        local rows = math.ceil(n / 3)
        for i, b in ipairs(card.buttons) do
            local spec = btns[i]
            b:ClearAllPoints()
            if spec then
                b:SetWidth(bw)
                b.text:SetText(spec[1])
                b:SetStyle(spec[3] or (i == 1 and "primary" or nil))
                b:SetScript("OnClick", function()
                    if not spec.keepOpen then ov:Close() end
                    if spec[2] then spec[2]() end
                end)
                -- up to three per row, rows stacked upwards; the first row is on top
                local row = math.floor((i - 1) / 3)
                local inRow = math.min(3, n - row * 3)
                local col = (i - 1) % 3 + 1
                b:SetPoint("BOTTOM", card, "BOTTOM", (col - (inRow + 1) / 2) * (bw + 10), 18 + (rows - 1 - row) * 38)
                b:Show()
            else
                b:Hide()
            end
        end
        card:SetHeight(26 + 26 + 12 + bh + (n > 0 and 74 + (rows - 1) * 38 or 34))
        ov.opts = o
        ov:Show()
    end
    function ov:Close()
        ov:Hide()
        if ov.opts and ov.opts.onClose then ov.opts.onClose() end
        ov.opts = nil
    end
    return ov
end


-- Run a per-frame function, catching errors: the first one is printed to chat
-- and saved (FlightBuddyDB.lastError) so it can be diagnosed, instead of the
-- game silently freezing with WoW's error display turned off.
local reported = {}
function W.Guard(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        err = tostring(err)
        if not reported[tag .. err] then
            reported[tag .. err] = true
            if NS.db then
                NS.db.lastError = { where = tag, err = err, stack = debugstack and debugstack(2, 12, 0) or "",
                                    when = date and date("%Y-%m-%d %H:%M:%S") or "" }
            end
            local f = DEFAULT_CHAT_FRAME
            if f then f:AddMessage("|cffff9e2eFlight Buddy|r hit an error in " .. tag .. ": " .. err) end
        end
    end
    return ok
end
