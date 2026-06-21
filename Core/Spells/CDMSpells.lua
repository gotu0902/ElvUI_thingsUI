local _, ns = ...

ns.CDMSpells = ns.CDMSpells or {}
local M = ns.CDMSpells

local CAT_ESSENTIAL = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential
local CAT_UTILITY   = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Utility

local liveCache = {}
local liveCharges = {}

local function CurrentSpecID()
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        local id = PlayerUtil.GetCurrentSpecID()
        if id then return id end
    end
    local idx = GetSpecialization and GetSpecialization()
    return idx and select(1, GetSpecializationInfo(idx)) or nil
end

local function Store()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    g.cdmSpecCache = g.cdmSpecCache or {}
    return g.cdmSpecCache
end

local function ChargeStore()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    g.cdmChargeCache = g.cdmChargeCache or {}
    return g.cdmChargeCache
end

-- Max charges; nil if 1/secret.
local function ChargesOf(spellID)
    local c = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
    local mx = c and c.maxCharges
    if mx == nil or (issecretvalue and issecretvalue(mx)) then return nil end
    return mx
end

local function SpellIDOf(cdID)
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
    return info and (info.overrideSpellID or info.spellID) or nil
end

local function CollectCategory(cat, into)
    if not (cat and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return end
    local shown = {}
    local shownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, false)
    if shownIDs then
        for _, cdID in ipairs(shownIDs) do
            local sid = SpellIDOf(cdID)
            if sid then shown[sid] = true end
        end
    end
    local allIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
    if not allIDs then return end
    for _, cdID in ipairs(allIDs) do
        local sid = SpellIDOf(cdID)
        if sid then
            local nd = not shown[sid]
            if into[sid] == nil then into[sid] = nd
            elseif into[sid] and not nd then into[sid] = false end
        end
    end
end

function M.RefreshCurrentSpec()
    local specID = CurrentSpecID()
    if not specID then return end
    local map = {}
    CollectCategory(CAT_ESSENTIAL, map)
    CollectCategory(CAT_UTILITY, map)
    if next(map) == nil then return end
    liveCache[specID] = map
    local store = Store()
    if store then store[specID] = map end

    -- Out of combat only (secret).
    if not InCombatLockdown() then
        local charges = {}
        for sid in pairs(map) do
            local mx = ChargesOf(sid)
            if mx and mx > 1 then charges[sid] = mx end
        end
        liveCharges[specID] = charges
        local cstore = ChargeStore()
        if cstore then cstore[specID] = charges end
    end
end

function M.GetForSpec(specID)
    if not specID then return nil end
    if specID == CurrentSpecID() then
        if not liveCache[specID] then M.RefreshCurrentSpec() end
        if liveCache[specID] then return liveCache[specID] end
    end
    local store = Store()
    return (store and store[specID]) or liveCache[specID]
end

-- {spellID -> maxCharges}, >1 only.
function M.GetChargesForSpec(specID)
    if not specID then return nil end
    if specID == CurrentSpecID() then
        if not liveCharges[specID] then M.RefreshCurrentSpec() end
        if liveCharges[specID] then return liveCharges[specID] end
    end
    local store = ChargeStore()
    return (store and store[specID]) or liveCharges[specID]
end

function M.GetForClass(classToken)
    if not classToken then return nil end
    local merged, any = {}, false
    for _, rec in ipairs(ns.AllSpecs() or {}) do
        if rec.classToken == classToken then
            local m = M.GetForSpec(rec.id)
            if m then
                any = true
                for sid, nd in pairs(m) do
                    if merged[sid] == nil then merged[sid] = nd
                    elseif merged[sid] and not nd then merged[sid] = false end
                end
            end
        end
    end
    return any and merged or nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("COOLDOWN_VIEWER_TABLE_HOTFIXED") then
    f:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
end
f:SetScript("OnEvent", function() C_Timer.After(0, M.RefreshCurrentSpec) end)
