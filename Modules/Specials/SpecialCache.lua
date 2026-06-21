local addon, ns = ...

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars

local GetCurrentSpecID = SB.GetCurrentSpecID   -- from SpecialDB (loaded first)

local CAT_BUFF = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
local CAT_BAR  = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar

local spellInfoCache = {}
local baseSpellCache = {}

local function GetCachedSpellInfo(spellID)
    if not spellID then return nil end
    local cached = spellInfoCache[spellID]
    if cached ~= nil then return cached ~= false and cached or nil end
    local info = C_Spell.GetSpellInfo(spellID)
    spellInfoCache[spellID] = info or false
    return info
end

local function GetBaseSpellID(spellID)
    if type(spellID) ~= "number" then return nil end
    local cached = baseSpellCache[spellID]
    if cached ~= nil then return cached end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    local result = (base and base ~= 0) and base or spellID
    baseSpellCache[spellID] = result
    return result
end

local function InvalidateSpellCaches()
    wipe(spellInfoCache)
    wipe(baseSpellCache)
end

--  CDM spell list
local cachedSpellList     = nil
local cachedSpellListSpec = nil

local function MergeType(curType, newLabel)
    if not curType or curType == "Unknown" then return newLabel end
    if curType:find(newLabel, 1, true) then return curType end
    return curType .. " & " .. newLabel
end

local function BuildCDMSpellList()
    -- The core scanner (SpecialShared) owns these; read live each call.
    local knownBarSpells  = SB.knownBarSpells  or {}
    local knownIconSpells = SB.knownIconSpells or {}
    local specID = GetCurrentSpecID()
    if cachedSpellList and cachedSpellListSpec == specID then
        for spellID in pairs(knownBarSpells) do
            if cachedSpellList[spellID] then
                cachedSpellList[spellID].type = MergeType(cachedSpellList[spellID].type, "Bar")
                cachedSpellList[spellID].notDisplayed = nil
            end
        end
        for spellID in pairs(knownIconSpells) do
            if cachedSpellList[spellID] then
                cachedSpellList[spellID].type = MergeType(cachedSpellList[spellID].type, "Icon")
                cachedSpellList[spellID].notDisplayed = nil
            end
        end
        return cachedSpellList
    end

    local list = {}
    if not C_CooldownViewer then return list end

    local rowSpellCount = {}
    local function preCount(cat, includeAll)
        if not cat then return end
        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, includeAll)
        if not ids then return end
        for _, cdID in ipairs(ids) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
            if info then
                local sid = info.overrideSpellID or info.spellID
                if sid then rowSpellCount[sid] = (rowSpellCount[sid] or 0) + 1 end
            end
        end
    end
    preCount(CAT_BUFF, false); preCount(CAT_BAR, false)
    preCount(CAT_BUFF, true);  preCount(CAT_BAR, true)

    local function collect(cat, label, includeAll, notDisplayedFlag)
        if not cat then return end
        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, includeAll)
        if ids then
            for _, cdID in ipairs(ids) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info then
                    local parentID = info.overrideSpellID or info.spellID
                    local key = parentID
                    if parentID and rowSpellCount[parentID] and rowSpellCount[parentID] > 1
                        and info.linkedSpellIDs and info.linkedSpellIDs[1] then
                        key = info.linkedSpellIDs[1]
                    end
                    local displayInfo = key and C_Spell.GetSpellInfo(key)
                    if displayInfo then
                        if not list[key] then
                            list[key] = {
                                name = displayInfo.name,
                                icon = displayInfo.iconID,
                                type = label,
                                notDisplayed = notDisplayedFlag or nil,
                                parentID = parentID,
                            }
                        else
                            list[key].type = MergeType(list[key].type, label)
                            if not notDisplayedFlag then list[key].notDisplayed = nil end
                        end
                    end
                end
            end
        end
    end

    collect(CAT_BUFF, "Icon", false, false)
    collect(CAT_BAR,  "Bar",  false, false)
    collect(CAT_BUFF, "Icon", true,  true)
    collect(CAT_BAR,  "Bar",  true,  true)

    for key, data in pairs(list) do
        local pid = data.parentID
        local isBarFrame  = (key and knownBarSpells[key])  or (pid and knownBarSpells[pid])
        local isIconFrame = (key and knownIconSpells[key]) or (pid and knownIconSpells[pid])
        if isBarFrame and isIconFrame then
            data.type = "Bar & Icon"
            data.notDisplayed = nil
        elseif isBarFrame then
            data.type = "Bar"
            data.notDisplayed = nil
        elseif isIconFrame then
            data.type = "Icon"
            data.notDisplayed = nil
        end
    end

    cachedSpellList     = list
    cachedSpellListSpec = specID
    return list
end

local function InvalidateSpellListCache()
    cachedSpellList     = nil
    cachedSpellListSpec = nil
end

local function GetRawSpellList() return BuildCDMSpellList() end

SB.GetCachedSpellInfo       = GetCachedSpellInfo
SB.GetBaseSpellID           = GetBaseSpellID
SB.InvalidateSpellCaches    = InvalidateSpellCaches
SB.GetRawSpellList          = GetRawSpellList
SB.InvalidateSpellListCache = InvalidateSpellListCache
