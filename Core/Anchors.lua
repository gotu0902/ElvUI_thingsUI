local _, ns = ...
ns.ANCHORS = ns.ANCHORS or {}

local C_ELV, C_CDM, C_TUI = "FF7AC0FF", "FFFFD27F", "FF8080FF"
local function col(hex, s) return "|c" .. hex .. s .. "|r" end
ns.ANCHORS.TUI_COLOR = C_TUI

local STATIC_VALUES = {
    ["BARSETUP_TOP"]              = col(C_TUI, "Top of Bar Setup Stack"),
    ["ElvUF_Player"]              = col(C_ELV, "ElvUI Player Frame"),
    ["ElvUF_Target"]              = col(C_ELV, "ElvUI Target Frame"),
    ["ElvUF_TargetTarget"]        = col(C_ELV, "ElvUI Target of Target"),
    ["ElvUF_Focus"]               = col(C_ELV, "ElvUI Focus Frame"),
    ["ElvUF_Party"]               = col(C_ELV, "ElvUI Party Frames"),
    ["ElvUF_Player_ClassBar"]     = col(C_ELV, "ElvUI Class Bar"),
    ["ElvUF_Player_CastBar"]      = col(C_ELV, "ElvUI Player Castbar"),
    ["Minimap"]                   = col(C_ELV, "ElvUI Minimap"),
    ["EssentialCooldownViewer"]   = col(C_CDM, "CDM: Essential Cooldowns"),
    ["UtilityCooldownViewer"]     = col(C_CDM, "CDM: Utility Cooldowns"),
    ["BuffIconCooldownViewer"]    = col(C_CDM, "CDM: Buff Icons"),
    ["CDMTAIL_BuffIconCooldownViewer"] = col(C_CDM, "CDM: Buff Icons (After Last Icon)"),
    ["ElvUI_thingsUI_ChargeBar"]  = col(C_TUI, "TUI Charge Bar"),
    ["TUI_KickTracker"]           = col(C_TUI, "TUI Kick Tracker"),
    ["Grid2LayoutFrame"]          = "Grid2 Layout Frame",
    ["UIParent"]                  = "Screen (UIParent)",
    ["CUSTOM"]                    = "|cFFFFFF00Custom Frame...|r",
}

local STATIC_ORDER = {
    "BARSETUP_TOP",
    "ElvUF_Player", "ElvUF_Target", "ElvUF_TargetTarget", "ElvUF_Focus", "ElvUF_Party", "ElvUF_Player_ClassBar", "ElvUF_Player_CastBar", "Minimap",
    "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "CDMTAIL_BuffIconCooldownViewer", "ElvUI_thingsUI_ChargeBar", "TUI_KickTracker", "Grid2LayoutFrame", "UIParent", "CUSTOM",
}

local function ResolveSpellName(spellID)
    if not spellID or spellID == 0 then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name and info.name ~= "" then return info.name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name and name ~= "" then return name end
    end
    return nil
end

local function GetSlotSpellHint(getDB, idx)
    if not getDB then return nil end
    local db = getDB(idx)
    if type(db) ~= "table" then return nil end
    return ResolveSpellName(db.spellID or db.spellId)
end

local function GetSpecialSlots()
    local SB = ns.SpecialBars
    if not SB then return nil end
    local out = {}

    if SB.GetBarCount then
        local n = SB.GetBarCount() or 0
        for i = 1, n do
            local key = "bar" .. i
            local hint = GetSlotSpellHint(SB.GetBarDB, key)
            local label = string.format("TUI Aura Bar %d", i)
            if hint then label = label .. " (" .. hint .. ")" end
            out[#out + 1] = { frame = "TUI_SpecialBar_" .. key, label = col(C_TUI, label) }
        end
    end
    if SB.GetIconCount then
        local n = SB.GetIconCount() or 0
        for i = 1, n do
            local key = "icon" .. i
            local hint = GetSlotSpellHint(SB.GetIconDB, key)
            local label = string.format("TUI Aura Icon %d", i)
            if hint then label = label .. " (" .. hint .. ")" end
            out[#out + 1] = { frame = "TUI_SpecialIcon_" .. key, label = col(C_TUI, label) }
        end
    end

    if #out == 0 then return nil end
    return out
end
-- Old name kept for any caller that still uses it.
local GetSpecialBarKeys = GetSpecialSlots

-- our own groups and combo bars, the ones that have a frame right now
local MODULE_FRAMES = {
    { "CustomGroups", "GetGroups", "TUI_CustomGroup", "TUI Group" },
    { "CustomBars",   "GetGroups", "TUI_CustomBars",  "TUI Bar Group" },
    { "ComboBars",    "GetBars",   "TUI_ComboBar_",   "TUI Combo Bar" },
}
local function GetModuleFrames()
    local out = {}
    for _, m in ipairs(MODULE_FRAMES) do
        local mod = ns[m[1]]
        local list = mod and mod[m[2]] and mod[m[2]]()
        for _, g in ipairs(list or {}) do
            local fname = m[3] .. tostring(g.id)
            if _G[fname] then
                local kind = (g.display == "text" and m[1] == "CustomBars") and "TUI Text Group" or m[4]
                out[#out + 1] = { frame = fname, label = col(C_TUI, kind .. ": " .. tostring(g.name or g.id)) }
            end
        end
    end
    return out
end

-- true when target already hangs off frame: SetPoint would throw
function ns.ANCHORS.DependsOn(target, frame)
    for _ = 1, 12 do
        if not target or target == _G.UIParent then return false end
        if target == frame then return true end
        if not (target.GetNumPoints and target:GetNumPoints() > 0) then return false end
        local _, rel = target:GetPoint(1)
        if issecretvalue and issecretvalue(rel) then return false end
        target = rel
    end
    return false
end

local ResolveName
function ns.ANCHORS.ResolveAnchorTarget(anchorName, frame)
    local target = ResolveName(anchorName)
    if frame and target and ns.ANCHORS.DependsOn(target, frame) then return nil end
    return target
end

function ResolveName(anchorName)
    if not anchorName or anchorName == "" then return nil end
    if anchorName == "BARSETUP_TOP" then
        local bs = ns.BarSetup
        if bs and bs.GetTopmostBarFrame then
            local top = bs.GetTopmostBarFrame()
            if top then return top end
        end
        local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
        return setup and _G[setup.anchorFrame or ""] or nil
    end
    if anchorName == "ElvUF_Player_ClassBar" then
        local p = _G.ElvUF_Player
        return p and (p.ClassBarHolder or p.ClassBar) or nil
    end
    local tailName = anchorName:match("^CDMTAIL_(.+)")
    if tailName then
        return ns.CDMIcons and ns.CDMIcons.FlowTailForName and ns.CDMIcons.FlowTailForName(tailName)
    end
    local proxy = ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(anchorName)
    if proxy then return proxy end
    local target = _G[anchorName]
    if anchorName == "ElvUF_Player_CastBar" and target and target.Holder then
        return target.Holder
    end
    return target
end

function ns.ANCHORS.GetSharedAnchorValues()
    local values = {}
    for k, v in pairs(STATIC_VALUES) do values[k] = v end
    local sbs = GetSpecialBarKeys()
    if sbs then
        for _, e in ipairs(sbs) do values[e.frame] = e.label end
    end
    for _, e in ipairs(GetModuleFrames()) do values[e.frame] = e.label end
    return values
end

local TAIL_ORDER = { "Grid2LayoutFrame", "UIParent", "CUSTOM" }
local TAIL_SET   = { Grid2LayoutFrame = true, UIParent = true, CUSTOM = true }
function ns.ANCHORS.GetSharedAnchorOrder()
    local order = {}
    for _, k in ipairs(STATIC_ORDER) do
        if not TAIL_SET[k] then order[#order + 1] = k end
    end
    local sbs = GetSpecialBarKeys()
    if sbs then
        for _, e in ipairs(sbs) do order[#order + 1] = e.frame end
    end
    for _, e in ipairs(GetModuleFrames()) do order[#order + 1] = e.frame end
    for _, k in ipairs(TAIL_ORDER) do order[#order + 1] = k end
    return order
end

-- the shared list without one frame (the one being placed); custom = keep "Custom Frame..."
function ns.ANCHORS.ValuesExcept(name, custom)
    local out = custom and ns.ANCHORS.GetSharedAnchorValues() or ns.ANCHORS.FilteredValues()
    if name then out[name] = nil end
    return out
end
function ns.ANCHORS.OrderExcept(name, custom)
    local out = {}
    for _, k in ipairs(custom and ns.ANCHORS.GetSharedAnchorOrder() or ns.ANCHORS.FilteredOrder()) do
        if k ~= name then out[#out + 1] = k end
    end
    return out
end

function ns.ANCHORS.FilteredValues()
    local out = {}
    for k, v in pairs(ns.ANCHORS.GetSharedAnchorValues()) do
        if k ~= "CUSTOM" then out[k] = v end
    end
    return out
end
function ns.ANCHORS.FilteredOrder()
    local out = {}
    for _, k in ipairs(ns.ANCHORS.GetSharedAnchorOrder()) do
        if k ~= "CUSTOM" then out[#out + 1] = k end
    end
    return out
end

-- Inherit Width/Height from Anchor; the width keeps the anchor's pixel parity so it centers crisp
function ns.ANCHORS.InheritedSize(db, frame, target, w, h)
    if not target then return w, h end
    local tn = target.GetName and target:GetName()
    local cdmInset = (tn and tn:match("^TUI_CDMProxy_")) and 2 or 0
    if db.inheritWidth then
        local aw = target:GetWidth()
        if aw and aw > 0 then
            w = aw + cdmInset + (db.inheritWidthOffset or 0)
            local one = ns.Pixel.Size(frame)
            if one and one > 0 then
                local p = math.floor(aw / one + 0.5)
                local e = math.floor(w / one + 0.5)
                if (p - e) % 2 ~= 0 then e = e + 1 end
                w = e * one
            end
        end
    end
    if db.inheritHeight then
        local ah = target:GetHeight()
        if ah and ah > 0 then h = ah + cdmInset + (db.inheritHeightOffset or 0) end
    end
    return w, h
end

-- a new anchor frame starts from CENTER on CENTER without offsets; f = field names where they differ
local PLACEMENT = { "anchorPoint", "anchorRelativePoint", "anchorXOffset", "anchorYOffset" }
function ns.ANCHORS.ResetPlacement(db, f)
    if not db then return end
    f = f or PLACEMENT
    db[f[1]], db[f[2]], db[f[3]], db[f[4]] = "CENTER", "CENTER", 0, 0
end

ns.ANCHORS.SHARED_ANCHOR_VALUES = STATIC_VALUES
ns.ANCHORS.SHARED_ANCHOR_ORDER  = STATIC_ORDER

ns.POINTS = ns.POINTS or {}
ns.POINTS.VALUES = {
  CENTER      = "CENTER",
  TOP         = "TOP",
  BOTTOM      = "BOTTOM",
  LEFT        = "LEFT",
  RIGHT       = "RIGHT",
  TOPLEFT     = "TOPLEFT",
  TOPRIGHT    = "TOPRIGHT",
  BOTTOMLEFT  = "BOTTOMLEFT",
  BOTTOMRIGHT = "BOTTOMRIGHT",
}
ns.POINTS.ORDER = {
  "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}
ns.STRATA = ns.STRATA or {}
function ns.STRATA.Apply(frame, strata, level)
    strata = strata or "MEDIUM"
    if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
    frame._tuiBaseLevel = frame._tuiBaseLevel or frame:GetFrameLevel()
    level = level or frame._tuiBaseLevel
    if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end
end
ns.STRATA.VALUES = {
  BACKGROUND        = "BACKGROUND",
  LOW               = "LOW",
  MEDIUM            = "MEDIUM",
  HIGH              = "HIGH",
  DIALOG            = "DIALOG",
  TOOLTIP           = "TOOLTIP",
}
ns.STRATA.ORDER = {
  "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP",
}

ns.OUTLINE = ns.OUTLINE or {}
ns.OUTLINE.VALUES = {
  NONE              = "None",
  OUTLINE           = "Outline",
  THICKOUTLINE      = "Thick Outline",
  MONOCHROME        = "Monochrome",
  MONOCHROMEOUTLINE = "Monochrome Outline",
}
ns.OUTLINE.ORDER = {
  "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "MONOCHROMEOUTLINE",
}

ns.GROWTH = ns.GROWTH or {}
ns.GROWTH.VALUES = {
  CENTERED_H = "Centered (Horizontal)",
  CENTERED_V = "Centered (Vertical)",
  RIGHT      = "Grow Right",
  LEFT       = "Grow Left",
  DOWN       = "Grow Down",
  UP         = "Grow Up",
}
ns.GROWTH.ORDER = { "CENTERED_H", "CENTERED_V", "RIGHT", "LEFT", "DOWN", "UP" }
ns.GROWTH.DIRECTIONAL = {
  RIGHT = "Grow Right", LEFT = "Grow Left", DOWN = "Grow Down", UP = "Grow Up",
}
ns.GROWTH.DIRECTIONAL_ORDER = { "RIGHT", "LEFT", "DOWN", "UP" }

ns.SORTING = {
  VALUES = {
    manual   = "Manual",
    long     = "Longest Remaining First",
    short    = "Shortest Remaining First",
    new      = "Newest First",
    instance = "Oldest First",
  },
  ORDER = { "manual", "long", "short", "new", "instance" },
}
ns.SORTING.ENTRY_VALUES, ns.SORTING.ENTRY_ORDER = {}, {}
for _, k in ipairs(ns.SORTING.ORDER) do
    if k ~= "manual" then
        ns.SORTING.ENTRY_VALUES[k] = ns.SORTING.VALUES[k]
        ns.SORTING.ENTRY_ORDER[#ns.SORTING.ENTRY_ORDER + 1] = k
    end
end
