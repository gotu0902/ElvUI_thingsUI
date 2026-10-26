local addon, ns = ...
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars

SB.MAX_SLOTS = 30

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

-- the highest slot number a list holds (a count from before counts were saved)
local function Highest(list, prefix)
    local n = 0
    for k in pairs(list) do
        local i = tonumber(tostring(k):match("^" .. prefix .. "(%d+)$"))
        if i and i > n then n = i end
    end
    return n
end

-- slots at the end with no spell are dropped once a session (the old three empty ones per spec)
local trimmed = setmetatable({}, { __mode = "k" })
local function Trim(s)
    if trimmed[s] then return end
    trimmed[s] = true
    while s.iconCount > 0 do
        local d = s.icons["icon" .. s.iconCount]
        if type(d) == "table" and d.spellID then break end
        s.icons["icon" .. s.iconCount] = nil
        s.iconCount = s.iconCount - 1
    end
    while s.barCount > 0 do
        local d = s.bars["bar" .. s.barCount]
        if type(d) == "table" and d.spellID then break end
        s.bars["bar" .. s.barCount] = nil
        s.barCount = s.barCount - 1
    end
end

local function GetSpecRoot(specID)
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db then return nil end
    if not db.specs then db.specs = {} end
    specID = specID or GetCurrentSpecID()
    if specID == 0 then specID = 1 end
    local key = tostring(specID)
    if not db.specs[key] then db.specs[key] = { bars = {}, icons = {}, barCount = 0, iconCount = 0 } end
    local s = db.specs[key]
    if not s.bars      then s.bars      = {} end
    if not s.icons     then s.icons     = {} end
    if not s.barCount  then s.barCount  = Highest(s.bars, "bar") end
    if not s.iconCount then s.iconCount = Highest(s.icons, "icon") end
    Trim(s)
    return s
end

local function GetBarDB(barKey, specID)
    local s = GetSpecRoot(specID)
    if not s then return nil end
    if not s.bars[barKey] then
        s.bars[barKey] = {}
        FillDefaults(s.bars[barKey], SPECIAL_BAR_DEFAULTS)
    end
    return s.bars[barKey]
end

local function GetIconDB(iconKey, specID)
    local s = GetSpecRoot(specID)
    if not s then return nil end
    if not s.icons[iconKey] then
        s.icons[iconKey] = { _borderOut = true }
        FillDefaults(s.icons[iconKey], SPECIAL_ICON_DEFAULTS)
    end
    return s.icons[iconKey]
end

local function GetBarCount(specID)  local s = GetSpecRoot(specID); return (s and s.barCount)  or 0 end
local function GetIconCount(specID) local s = GetSpecRoot(specID); return (s and s.iconCount) or 0 end

-- a slot for a new Aura Bar / Icon: the first one without a spell is cleared and reused,
-- else one is added; nil when the spec is full
SB.freshSlots = {}
local function TakeSlot(kind, specID)
    local s = GetSpecRoot(specID)
    if not s then return nil end
    local isBar = kind == "bars"
    local prefix, list = isBar and "bar" or "icon", isBar and s.bars or s.icons
    local n = isBar and s.barCount or s.iconCount
    local idx
    for i = 1, n do
        local d = list[prefix .. i]
        if type(d) ~= "table" or not d.spellID then idx = i break end
    end
    if not idx then
        if n >= (SB.MAX_SLOTS or 30) then return nil end
        idx = n + 1
        if isBar then s.barCount = idx else s.iconCount = idx end
    end
    local key = prefix .. idx
    if not specID or tostring(specID) == tostring(GetCurrentSpecID()) then
        local release = isBar and SB.ReleaseBar or SB.ReleaseIcon
        if release then release(key) end
    end
    list[key] = nil
    SB.freshSlots[key] = true
    return key
end

-- slots holding a spell (the count shown to the user)
local function UsedSlots(kind, specID)
    local s = GetSpecRoot(specID)
    if not s then return 0 end
    local isBar = kind == "bars"
    local prefix, list = isBar and "bar" or "icon", isBar and s.bars or s.icons
    local used = 0
    for i = 1, (isBar and s.barCount or s.iconCount) do
        local d = list[prefix .. i]
        if type(d) == "table" and d.spellID then used = used + 1 end
    end
    return used
end

-- two Aura Bars trade slots: Bar Setup orders by slot, so they trade places there;
-- anchors between this spec's bars and icons follow the bar
local function SwapBars(a, b, specID)
    local s = GetSpecRoot(specID)
    if not (s and a and b and a ~= b) then return end
    s.bars[a], s.bars[b] = s.bars[b], s.bars[a]
    local fa, fb = "TUI_SpecialBar_" .. a, "TUI_SpecialBar_" .. b
    for _, list in ipairs({ s.bars, s.icons }) do
        for _, d in pairs(list) do
            if type(d) == "table" then
                if d.anchorFrame == fa then d.anchorFrame = fb
                elseif d.anchorFrame == fb then d.anchorFrame = fa end
                if d.fillInFor == a then d.fillInFor = b
                elseif d.fillInFor == b then d.fillInFor = a end
            end
        end
    end
    SB.freshSlots[a], SB.freshSlots[b] = SB.freshSlots[b], SB.freshSlots[a]
    if (not specID or tostring(specID) == tostring(GetCurrentSpecID())) and SB.ReleaseBar then
        SB.ReleaseBar(a)
        SB.ReleaseBar(b)
    end
end

SB.editingSpec = nil
function SB.EditingSpec()
    local es = SB.editingSpec
    if es and es ~= GetCurrentSpecID() then return es end
    return nil
end

SB.GetCurrentSpecID = GetCurrentSpecID
SB.GetSpecRoot      = GetSpecRoot
SB.GetBarDB         = GetBarDB
SB.GetIconDB        = GetIconDB
SB.GetBarCount      = GetBarCount
SB.GetIconCount     = GetIconCount
SB.TakeSlot         = TakeSlot
SB.UsedSlots        = UsedSlots
SB.SwapBars         = SwapBars
