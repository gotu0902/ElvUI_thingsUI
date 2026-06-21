local _, ns = ...
ns.ANCHORS = ns.ANCHORS or {}

local C_ELV, C_CDM, C_TUI = "FF7AC0FF", "FFFFD27F", "FF8080FF"
local function col(hex, s) return "|c" .. hex .. s .. "|r" end
ns.ANCHORS.TUI_COLOR = C_TUI  -- exported so dynamic labels (Special slots) match

local STATIC_VALUES = {
    ["BARSETUP_TOP"]              = col(C_TUI, "Top of Bar Setup Stack"),
    ["ElvUF_Player"]              = col(C_ELV, "ElvUI Player Frame"),
    ["ElvUF_Target"]              = col(C_ELV, "ElvUI Target Frame"),
    ["ElvUF_TargetTarget"]        = col(C_ELV, "ElvUI Target of Target"),
    ["ElvUF_Player_ClassBar"]     = col(C_ELV, "ElvUI Class Bar"),
    ["ElvUF_Player_CastBar"]      = col(C_ELV, "ElvUI Player Castbar"),
    ["EssentialCooldownViewer"]   = col(C_CDM, "CDM: Essential Cooldowns"),
    ["UtilityCooldownViewer"]     = col(C_CDM, "CDM: Utility Cooldowns"),
    ["ElvUI_thingsUI_ChargeBar"]  = col(C_TUI, "TUI Charge Bar"),
    ["Grid2LayoutFrame"]          = "Grid2 Layout Frame",
    ["UIParent"]                  = "Screen (UIParent)",
    ["CUSTOM"]                    = "|cFFFFFF00Custom Frame...|r",
}

local STATIC_ORDER = {
    "BARSETUP_TOP",
    "ElvUF_Player", "ElvUF_Target", "ElvUF_TargetTarget", "ElvUF_Player_ClassBar", "ElvUF_Player_CastBar",
    "EssentialCooldownViewer", "UtilityCooldownViewer", "ElvUI_thingsUI_ChargeBar", "Grid2LayoutFrame", "UIParent", "CUSTOM",
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
    local db = getDB(idx)   -- SB.GetBarDB/GetIconDB are nil-safe (return nil if not ready)
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
            local label = string.format("TUI Special Bar %d", i)
            if hint then label = label .. " (" .. hint .. ")" end
            out[#out + 1] = { frame = "TUI_SpecialBar_" .. key, label = col(C_TUI, label) }
        end
    end
    if SB.GetIconCount then
        local n = SB.GetIconCount() or 0
        for i = 1, n do
            local key = "icon" .. i
            local hint = GetSlotSpellHint(SB.GetIconDB, key)
            local label = string.format("TUI Special Icon %d", i)
            if hint then label = label .. " (" .. hint .. ")" end
            out[#out + 1] = { frame = "TUI_SpecialIcon_" .. key, label = col(C_TUI, label) }
        end
    end

    if #out == 0 then return nil end
    return out
end
-- Old name kept for any caller that still uses it.
local GetSpecialBarKeys = GetSpecialSlots

function ns.ANCHORS.MigrateAnchorName(name)
    if name == "ElvUF_Player_CastBar.Holder" then return "ElvUF_Player_CastBar" end
    return name
end

function ns.ANCHORS.GetSharedAnchorValues()
    local values = {}
    for k, v in pairs(STATIC_VALUES) do values[k] = v end
    local sbs = GetSpecialBarKeys()
    if sbs then
        for _, e in ipairs(sbs) do values[e.frame] = e.label end
    end
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
    for _, k in ipairs(TAIL_ORDER) do order[#order + 1] = k end
    return order
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
