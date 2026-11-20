-- Flight Buddy :: Picker.lua
-- A "choose your ..." screen every game can use before it starts: a grid of portraits with a
-- name and a line each (what it does, or how to unlock it). Click one to pick it.
local ADDON, NS = ...

local W = NS.W
local COLORS = W.COLORS

local COLS = 3
local MAX_TILES = 9
local TILE_W, TILE_H = 138, 136

-- parent: the game frame; area: the 480x560 board the picker covers
function NS.NewPickerPanel(parent, area)
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", area, "TOPLEFT")
    p:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT")
    p:SetFrameLevel(area:GetFrameLevel() + 28)
    p:EnableMouse(true)
    W.Panel(p, "wood")
    p:Hide()

    p.title = W.Text(p, 24, W.FONT_TITLE, "OUTLINE")
    p.title:SetPoint("TOP", 0, -18)
    p.sub = W.Text(p, 11, W.FONT)
    p.sub:SetPoint("TOP", p.title, "BOTTOM", 0, -5)
    p.sub:SetWidth(430)
    p.sub:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    p.tiles = {}
    local gridW = COLS * TILE_W + (COLS - 1) * 8
    for i = 1, MAX_TILES do
        local t = CreateFrame("Button", nil, p)
        t:SetSize(TILE_W, TILE_H)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        t:SetPoint("TOPLEFT", p, "TOP", -gridW / 2 + col * (TILE_W + 8), -66 - row * (TILE_H + 8))
        t.bg = W.Solid(t, "BACKGROUND", 0.13, 0.08, 0.045, 1)
        t.bg:SetAllPoints()
        t.edge = W.Solid(t, "BORDER", 1, 1, 1, 0.08)
        t.edge:SetPoint("BOTTOMLEFT"); t.edge:SetPoint("BOTTOMRIGHT"); t.edge:SetHeight(2)
        t.hl = W.Solid(t, "HIGHLIGHT", 1, 1, 1, 0.06)
        t.hl:SetAllPoints()
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(64, 64)
        t.icon:SetPoint("TOP", 0, -10)
        t.name = W.Text(t, 12)
        t.name:SetPoint("TOP", t.icon, "BOTTOM", 0, -6)
        t.name:SetWidth(TILE_W - 10)
        t.line = W.Text(t, 10, W.FONT)
        t.line:SetPoint("TOP", t.name, "BOTTOM", 0, -4)
        t.line:SetWidth(TILE_W - 12)
        t.line:SetJustifyV("TOP")
        t.tag = W.Text(t, 10, W.FONT_NUM, "OUTLINE")
        t.tag:SetPoint("TOPRIGHT", -6, -6)
        t:SetScript("OnEnter", function(self)
            local it = self.item
            if not (it and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(it.name, 1, 0.82, 0.25)
            if it.desc then GameTooltip:AddLine(it.desc, 1, 1, 1, true) end
            if it.locked and it.lockText then GameTooltip:AddLine(it.lockText, 0.6, 0.6, 0.7, true) end
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        p.tiles[i] = t
    end

    p.back = W.Button(p, 130, 30, "Done", "primary")
    p.back:SetPoint("BOTTOMRIGHT", -20, 16)
    p.back:SetScript("OnClick", function() p:Hide(); if p.spec and p.spec.onClose then p.spec.onClose() end end)
    p.note = W.Text(p, 11, W.FONT)
    p.note:SetPoint("BOTTOMLEFT", 22, 26)
    p.note:SetPoint("RIGHT", p.back, "LEFT", -10, 0)
    p.note:SetJustifyH("LEFT")
    p.note:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])

    -- spec = { title=, sub=, color=, note=, selected=key, onPick=function(key) end, onClose=function() end,
    --          items = { { key=, name=, desc=, line=, icon=, coords={l,r,t,b}, tint={r,g,b}, round=bool,
    --                      locked=bool, lockText= } } }
    function p:Open(spec)
        self.spec = spec
        local c = spec.color or COLORS.gold
        self.title:SetText(spec.title or "")
        self.title:SetTextColor(c[1], c[2], c[3])
        self.sub:SetText(spec.sub or "")
        self.note:SetText(spec.note or "")
        self:Fill()
        self:Show()
    end

    function p:Fill()
        local spec = self.spec
        for i, t in ipairs(self.tiles) do
            local it = spec.items[i]
            t.item = it
            if it then
                local mine = spec.selected == it.key
                t.icon:SetTexture(it.icon)
                local co = it.coords or (it.round and { 0.08, 0.92, 0.08, 0.92 }) or { 0, 1, 0, 1 }
                t.icon:SetTexCoord(co[1], co[2], co[3], co[4])
                local tint = it.tint or { 1, 1, 1 }
                local k = it.locked and 0.22 or 1
                t.icon:SetVertexColor(tint[1] * k, tint[2] * k, tint[3] * k)
                if t.icon.SetDesaturated then t.icon:SetDesaturated(it.locked and true or false) end
                t.name:SetText(it.locked and ("|cff8a8d99" .. it.name .. "|r") or it.name)
                t.line:SetText(it.locked and (it.lockText or "Locked") or (it.line or it.desc or ""))
                local lc = it.locked and COLORS.dim or COLORS.green
                t.line:SetTextColor(lc[1], lc[2], lc[3])
                t.tag:SetText(mine and "|cffffcc40CHOSEN|r" or (it.locked and "|cff8a8d99LOCKED|r" or ""))
                if mine then
                    t.bg:SetColorTexture(0.30, 0.21, 0.08, 1)
                    t.edge:SetColorTexture(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
                else
                    t.bg:SetColorTexture(0.13, 0.08, 0.045, 1)
                    t.edge:SetColorTexture(1, 1, 1, 0.08)
                end
                t:SetScript("OnClick", function()
                    if it.locked then W.SFX("knock"); return end
                    spec.selected = it.key
                    if spec.onPick then spec.onPick(it.key) end
                    W.Sound("IG_CHARACTER_INFO_TAB")
                    self:Fill()
                end)
                t:Show()
            else
                t:Hide()
            end
        end
    end
    return p
end
