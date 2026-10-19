local _, ns = ...

-- show/hide rules shared by Groups, Aura Icons and Aura Bars: every rule that is set
-- must match, ticked values inside one list are alternatives, an empty list = anywhere
local V = {}
ns.Visibility = V

V.COMBAT = { always = "Always", ["in"] = "In Combat", out = "Out of Combat", never = "Never" }
V.COMBAT_ORDER = { "always", "in", "out", "never" }
V.PLACES = {
    world = "Open World", dungeon = "Dungeon", raid = "Raid", delve = "Delve",
    scenario = "Scenario", arena = "Arena", pvp = "Battleground", housing = "Housing",
}
V.ROLES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

-- the current spec's role
local function Role()
    local spec = GetSpecialization and GetSpecialization()
    return (spec and GetSpecializationRole(spec)) or "DAMAGER"
end
V.Role = Role

local inCombat = InCombatLockdown() and true or false

local function Place()
    if C_Housing and C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot() then return "housing" end
    if C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress() then return "delve" end
    local inInstance, iType = IsInInstance()
    if not inInstance then return "world" end
    if iType == "party" then return "dungeon" end
    if iType == "raid" or iType == "arena" or iType == "pvp" or iType == "scenario" then return iType end
    return "world"
end
V.Place = Place

-- the current shapeshift form as its spell ID (string), "none" without one
local function FormKey()
    local i = GetShapeshiftForm and GetShapeshiftForm() or 0
    if i and i > 0 then
        local _, _, _, spellID = GetShapeshiftFormInfo(i)
        if spellID then return tostring(spellID) end
    end
    return "none"
end
V.FormKey = FormKey

-- this character's forms, plus any a stored rule names
function V.FormChoices(stored)
    local out = { none = "No Form" }
    for i = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
        local _, _, _, spellID = GetShapeshiftFormInfo(i)
        if spellID then out[tostring(spellID)] = C_Spell.GetSpellName(spellID) or ("Form " .. i) end
    end
    for k in pairs(stored or {}) do
        if not out[k] then out[k] = (tonumber(k) and C_Spell.GetSpellName(tonumber(k))) or k end
    end
    return out
end

function V.HasForms() return (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0 end

-- druid travel, aquatic and flight forms count as mounted
local function Mounted()
    if IsMounted() then return true end
    local id = GetShapeshiftFormID and GetShapeshiftFormID()
    return id == 3 or id == 4 or id == 27
end

local function GroupType()
    if IsInRaid() then return "raid" end
    return IsInGroup() and "party" or "solo"
end

-- what any rule has asked about: the state signature only covers those
local used = {}

function V.Shown(v)
    if not (v and v.enabled) then return true end
    used.any = true
    if v.combat then used.combat = true end
    if v.solo == false or v.party == false or v.raid == false then used.group = true end
    if v.places and next(v.places) then used.place = true end
    if v.roles and next(v.roles) then used.role = true end
    if v.forms and next(v.forms) then used.form = true end
    if v.hideMounted then used.mount = true end
    if v.hideNoTarget or v.hideNoEnemy then used.target = true end
    if v.hideResting then used.rest = true end
    local c = v.combat or "always"
    if c == "never" then return false end
    if c == "in" and not inCombat then return false end
    if c == "out" and inCombat then return false end
    if v[GroupType()] == false then return false end
    if v.places and next(v.places) and not v.places[Place()] then return false end
    if v.roles and next(v.roles) and not v.roles[Role()] then return false end
    if v.forms and next(v.forms) and not v.forms[FormKey()] then return false end
    if v.hideMounted and Mounted() then return false end
    local target = UnitExists("target")
    if v.hideNoTarget and not target then return false end
    if v.hideNoEnemy and not (target and UnitCanAttack("player", "target")) then return false end
    if v.hideResting and IsResting() then return false end
    return true
end

-- owners re-check themselves when anything a rule can read has changed
local listeners = {}
function V.OnChange(fn) listeners[#listeners + 1] = fn end

local lastSig
local function Check()
    if not used.any then return end
    local target = used.target and UnitExists("target")
    local sig = table.concat({
        used.combat and tostring(inCombat) or "",
        used.group and GroupType() or "",
        used.place and Place() or "",
        used.role and Role() or "",
        used.form and FormKey() or "",
        used.mount and tostring(Mounted()) or "",
        used.target and (tostring(target) .. tostring(target and UnitCanAttack("player", "target"))) or "",
        used.rest and tostring(IsResting()) or "",
    }, "|")
    if sig == lastSig then return end
    lastSig = sig
    for i = 1, #listeners do listeners[i]() end
end

local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; Check() end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING" }) do
    ev:RegisterEvent(e)
end
-- it also fires for every group member
ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
ev:SetScript("OnEvent", function(_, event)
    -- combat flips at once; the rest coalesce (zone loads fire several)
    if event == "PLAYER_REGEN_DISABLED" then inCombat = true; Check()
    elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false; Check()
    else Queue() end
end)
