local addon, ns = ...
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars

local SPECIAL_BAR_DEFAULTS  = ns.SPECIAL_BAR_DEFAULTS
local SPECIAL_ICON_DEFAULTS = ns.SPECIAL_ICON_DEFAULTS
local DeepCopy = ns.DeepCopy

local function GetCurrentSpecID()
    local idx = GetSpecialization()
    return idx and GetSpecializationInfo(idx) or 0
end

local function FillDefaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if tbl[k] == nil then tbl[k] = DeepCopy(v)
        elseif type(v) == "table" and type(tbl[k]) == "table" then FillDefaults(tbl[k], v) end
    end
end

local function GetSpecRoot()
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db then return nil end  -- profile not loaded yet (early call); caller handles nil
    if not db.specs then db.specs = {} end
    local specID = GetCurrentSpecID()
    if specID == 0 then specID = 1 end
    local key = tostring(specID)
    if not db.specs[key] then db.specs[key] = { bars = {}, icons = {}, barCount = 3, iconCount = 3 } end
    local s = db.specs[key]
    if not s.bars      then s.bars      = {} end
    if not s.icons     then s.icons     = {} end
    if not s.barCount  then s.barCount  = 3  end
    if not s.iconCount then s.iconCount = 3  end
    return s
end

local function GetBarDB(barKey)
    local s = GetSpecRoot()
    if not s then return nil end
    if not s.bars[barKey] then
        s.bars[barKey] = {}
        FillDefaults(s.bars[barKey], SPECIAL_BAR_DEFAULTS)
    end
    return s.bars[barKey]
end

local function GetIconDB(iconKey)
    local s = GetSpecRoot()
    if not s then return nil end
    if not s.icons[iconKey] then
        s.icons[iconKey] = {}
        FillDefaults(s.icons[iconKey], SPECIAL_ICON_DEFAULTS)
    end
    return s.icons[iconKey]
end

local function GetBarCount()  local s = GetSpecRoot(); return (s and s.barCount)  or 3 end
local function GetIconCount() local s = GetSpecRoot(); return (s and s.iconCount) or 3 end

SB.GetCurrentSpecID = GetCurrentSpecID
SB.GetSpecRoot      = GetSpecRoot
SB.GetBarDB         = GetBarDB
SB.GetIconDB        = GetIconDB
SB.GetBarCount      = GetBarCount
SB.GetIconCount     = GetIconCount
