local _, ns = ...
local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local E = ns.E
local function GetACD()
    return E and E.Libs and E.Libs.AceConfigDialog
end

local CreateFrame = CreateFrame
local pairs, ipairs, unpack = pairs, ipairs, unpack

local C_LINK  = { 0.40, 0.70, 1.00 }
local C_HOVER = { 0.65, 0.85, 1.00 }
local C_SEP   = { 0.45, 0.45, 0.45 }
local ROW_H   = 18
local LINK_SEP = "   •   "

-- Link-row rendering
local function Cell_OnEnter(btn)
    if not (btn.path or btn.onClick) then return end
    local c = btn._hover or C_HOVER
    btn.text:SetTextColor(c[1], c[2], c[3])
    btn.underline:SetVertexColor(c[1], c[2], c[3])
end
local function Cell_OnLeave(btn)
    if not (btn.path or btn.onClick) then return end
    local c = btn._color or C_LINK
    btn.text:SetTextColor(c[1], c[2], c[3])
    btn.underline:SetVertexColor(c[1], c[2], c[3])
end
local function Cell_OnClick(btn)
    if btn.onClick then btn.onClick(); return end  -- action link (e.g. set editClass), no navigation
    local ACD = GetACD()
    if not ACD or not btn.path then return end
    ACD:SelectGroup(btn.appName, unpack(btn.path))
end

local function AcquireCell(self, i)
    local cell = self.cells[i]
    if not cell then
        cell = CreateFrame("Button", nil, self.content)
        cell:SetHeight(ROW_H)
        cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.text:SetPoint("LEFT", cell, "LEFT", 0, 0)
        cell.underline = cell:CreateTexture(nil, "OVERLAY")
        cell.underline:SetColorTexture(1, 1, 1, 1)
        cell.underline:SetHeight(1)
        cell.underline:SetPoint("TOPLEFT", cell.text, "BOTTOMLEFT", 0, -1)
        cell.underline:SetPoint("TOPRIGHT", cell.text, "BOTTOMRIGHT", 0, -1)
        cell:SetScript("OnEnter", Cell_OnEnter)
        cell:SetScript("OnLeave", Cell_OnLeave)
        cell:SetScript("OnClick", Cell_OnClick)
        self.cells[i] = cell
    end
    return cell
end

local function AcquireSep(self, i)
    local sep = self.seps[i]
    if not sep then
        sep = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sep:SetTextColor(C_SEP[1], C_SEP[2], C_SEP[3])
        self.seps[i] = sep
    end
    return sep
end

-- Lay the links out left-to-right, wrapping to a new line when a cell would overflow the width.
local function Layout(self)
    local links = self._links
    if type(links) == "function" then links = links() end   -- dynamic: re-resolved each render
    for _, c in ipairs(self.cells) do c:Hide() end
    for _, s in ipairs(self.seps) do s:Hide() end
    if not links or #links == 0 then
        self.frame:SetHeight(1); self.frame.height = 1
        return
    end

    local avail = (self._width or self.content:GetWidth() or 0) - 4
    if avail <= 1 then avail = 1e9 end   -- width unknown yet: single line, re-laid out on OnWidthSet

    local x, y, sepIdx, rows = 0, 0, 0, 1
    local prevActionable = false
    for i = 1, #links do
        local link = links[i]
        local actionable = (link.path ~= nil) or (link.onClick ~= nil)
        local col = link.color or C_LINK
        local cell = AcquireCell(self, i)
        cell.text:SetText(link.label or "")
        cell.text:SetTextColor(col[1], col[2], col[3])
        cell._color = col
        cell._hover = link.hover or { (col[1] + 1) / 2, (col[2] + 1) / 2, (col[3] + 1) / 2 }
        cell.appName = self._appName
        cell.path = link.path
        cell.onClick = link.onClick
        cell.underline:SetVertexColor(col[1], col[2], col[3])
        cell.underline:SetShown(actionable)
        cell:EnableMouse(actionable)
        local w = cell.text:GetStringWidth() + 2
        cell:SetWidth(w)

        -- Separator sits BEFORE this cell, only when the previous link was actionable.
        local needSep = (i > 1) and prevActionable
        local sep, sepW = nil, 0
        if needSep then
            sepIdx = sepIdx + 1
            sep = AcquireSep(self, sepIdx)
            sep:SetText(LINK_SEP)
            sepW = sep:GetStringWidth()
        end

        if x > 0 and (x + sepW + w) > avail then   -- wrap
            x = 0; y = y - ROW_H; rows = rows + 1
            needSep = false                          -- no leading bullet at line start
        end

        if needSep then
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
            sep:Show()
            x = x + sepW
        end

        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
        cell:Show()
        x = x + w
        prevActionable = actionable
    end

    local h = rows * ROW_H
    self.frame:SetHeight(h); self.frame.height = h
end

-- Widget
local methods = {
    ["OnAcquire"]  = function(self) self._links = nil; self:SetWidth(400) end,
    ["OnRelease"]  = function(self) self._arg = nil; self._links = nil end,
    ["OnWidthSet"] = function(self, width) self._width = width; self.content:SetWidth(width or 0); Layout(self) end,
    ["SetText"]    = function() end,  -- name unused; data arrives via SetCustomData
    ["SetCustomData"] = function(self, arg)
        self._arg = arg
        self._appName = (arg and arg.appName) or "ElvUI"
        self._links = arg and arg.links
        Layout(self)
    end,
    ["SetFontObject"] = function() end,
    ["SetImage"]      = function() end,
    ["SetImageSize"]  = function() end,
    ["SetColor"]      = function() end,
    ["SetJustifyH"]   = function() end,
    ["SetJustifyV"]   = function() end,
    ["SetDisabled"]   = function() end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(ROW_H)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local widget = { type = "TUI_OptionLink", frame = frame, content = content, cells = {}, seps = {} }
    for name, fn in pairs(methods) do widget[name] = fn end
    frame.obj = widget
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType("TUI_OptionLink", Constructor, 1)

-- Option-table helpers
function ns.OptionLink(order, label, ...)
    return {
        order = order, type = "description", dialogControl = "TUI_OptionLink",
        width = "full", name = "",
        arg = { links = { { label = label, path = { ... } } } },
    }
end

-- ns.OptionLinkRow
function ns.OptionLinkRow(order, links)
    local L = {}
    for i = 1, #links do
        local lk = links[i]
        local path = {}
        for j = 2, #lk do path[#path + 1] = lk[j] end
        L[i] = { label = lk[1], path = path }
    end
    return {
        order = order, type = "description", dialogControl = "TUI_OptionLink",
        width = "full", name = "",
        arg = { links = L },
    }
end

function ns.OptionLinkRowDynamic(order, provider)
    return {
        order = order, type = "description", dialogControl = "TUI_OptionLink",
        width = "full", name = "",
        arg = { links = provider },
    }
end
