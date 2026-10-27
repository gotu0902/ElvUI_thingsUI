local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars

local specialBarState  = {}
local iconGroupState   = {}

local knownBarSpells  = {}
local knownIconSpells = {}

local yoinkedBars = ns.yoinkedBars or {}
ns.yoinkedBars = yoinkedBars

local GetSpecRoot   = SB.GetSpecRoot
local GetBarDB      = SB.GetBarDB
local GetIconDB     = SB.GetIconDB
local GetBarCount   = SB.GetBarCount
local GetIconCount  = SB.GetIconCount
local InvalidateSpellListCache = SB.InvalidateSpellListCache
local InvalidateSpellCaches    = SB.InvalidateSpellCaches

local _barKeys  = {}
local _iconKeys = {}
local function EnsureSlotKeys(barCount, iconCount)
    if barCount  > #_barKeys  then for i = #_barKeys  + 1, barCount  do _barKeys[i]  = "bar"  .. i end end
    if iconCount > #_iconKeys then for i = #_iconKeys + 1, iconCount do _iconKeys[i] = "icon" .. i end end
end

local function PlainID(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function InfoSpellID(info)
    return PlainID(info.overrideSpellID) or PlainID(info.spellID)
end

-- every ID of the CDM's buff entries for this spec (rebuilt on spec/talent change), and of the ones you have learned
local cdmAll, cdmLearned = {}, {}
local cdmAllDirty = true
local function AddIDs(set, info)
    local a, b = PlainID(info.spellID), PlainID(info.overrideSpellID)
    if a then set[a] = true end
    if b then set[b] = true end
    for _, l in ipairs(info.linkedSpellIDs or {}) do
        local p = PlainID(l)
        if p then set[p] = true end
    end
end

-- false only when the CDM has the spell for this spec and you haven't learned it (talented out)
function SB.SpellLearned(spellID)
    if not spellID then return false end
    return cdmLearned[spellID] or not cdmAll[spellID] or false
end

local function RefreshKnownSpells()
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return end
    local CAT_BUFF = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
    local CAT_BAR  = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar
    local SA = ns.SpecialAura
    if cdmAllDirty and SA and SA.CDMRows then
        local rows = SA.CDMRows()
        -- the CDM may have nothing yet early in a login
        cdmAllDirty = #rows == 0
        wipe(cdmAll)
        for _, r in ipairs(rows) do
            if r.s then cdmAll[r.s] = true end
            if r.o then cdmAll[r.o] = true end
            for _, l in ipairs(r.linked) do cdmAll[l] = true end
        end
    end
    wipe(cdmLearned)
    local function fill(cat, set)
        wipe(set)
        local ids = cat and C_CooldownViewer.GetCooldownViewerCategorySet(cat, false)
        if not ids then return end
        for _, cdID in ipairs(ids) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
            if info then
                AddIDs(cdmLearned, info)
                local sid = InfoSpellID(info)
                local si = sid and C_Spell.GetSpellInfo(sid)
                if si and si.spellID then
                    set[si.spellID] = true
                    local baseID = PlainID(info.spellID)
                    if baseID then set[baseID] = true end
                    local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
                    if linked then set[linked] = true end
                end
            end
        end
    end
    fill(CAT_BUFF, knownIconSpells)
    fill(CAT_BAR,  knownBarSpells)
    InvalidateSpellListCache()
end

local function HookCDMWindow()
    if ns.__cdmWindowHooked then return end
    local f = _G.CooldownViewerSettings
    if not f then return end
    ns.__cdmWindowHooked = true
    f:HookScript("OnHide", function()
        InvalidateSpellListCache()
        TUI:QueueSpecialBarsUpdate()
    end)
end

local specialBarsUpdateQueued = false
local function _queuedUpdateCallback()
    specialBarsUpdateQueued = false
    if TUI and TUI.UpdateSpecialBars then
        TUI:UpdateSpecialBars()
    end
end
function TUI:QueueSpecialBarsUpdate()
    if specialBarsUpdateQueued then return end
    specialBarsUpdateQueued = true
    C_Timer.After(0, _queuedUpdateCallback)
end

function TUI:UpdateSpecialBars()
    if not (E.db.thingsUI and E.db.thingsUI.specialBars) then return end
    HookCDMWindow()
    if not InCombatLockdown() then RefreshKnownSpells() end

    local barCount = GetBarCount()
    local releaseBar = SB.ReleaseBar
    local hideBarMover = SB.HideBarMover
    for key in pairs(specialBarState) do
        local idx = tonumber(key:match("^bar(%d+)$"))
        if not idx or idx > barCount then if releaseBar then releaseBar(key) end end
    end
    if hideBarMover then
        for i = barCount + 1, (SB.MAX_SLOTS or 12) do hideBarMover("bar" .. i) end
    end
    EnsureSlotKeys(barCount, 0)
    local updateBar = SB.UpdateBarSlot
    if updateBar then for i = 1, barCount do updateBar(_barKeys[i]) end end

    local iconCount = GetIconCount()
    local releaseIcon = SB.ReleaseIcon
    local hideIconMover = SB.HideIconMover
    for key in pairs(iconGroupState) do
        local idx = tonumber(key:match("^icon(%d+)$"))
        if not idx or idx > iconCount then if releaseIcon then releaseIcon(key) end end
    end
    if hideIconMover then
        for i = iconCount + 1, (SB.MAX_SLOTS or 12) do hideIconMover("icon" .. i) end
    end
    EnsureSlotKeys(0, iconCount)
    local updateIcon = SB.UpdateIconSlot
    if updateIcon then for i = 1, iconCount do updateIcon(_iconKeys[i]) end end
    if SB.NotifyAuraSet then SB.NotifyAuraSet() end
    -- cooldown frames report aura on/off for icons on top of them or waiting for a missing aura
    if SB.WatchOverSpells then SB.WatchOverSpells() end
end

local function OnSpecChanged()
    InvalidateSpellListCache()
    if InvalidateSpellCaches then InvalidateSpellCaches() end
    if ns.SpecialAura and ns.SpecialAura.InvalidateSpellExpansion then
        ns.SpecialAura.InvalidateSpellExpansion()
    end
    local releaseBar  = SB.ReleaseBar
    local releaseIcon = SB.ReleaseIcon
    for k in pairs(specialBarState)  do if releaseBar  then releaseBar(k)  end end
    for k in pairs(iconGroupState)   do if releaseIcon then releaseIcon(k) end end
    TUI:QueueSpecialBarsUpdate()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("COOLDOWN_VIEWER_TABLE_HOTFIXED") then
        f:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
    end
    f:RegisterEvent("TRAIT_CONFIG_UPDATED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
        cdmAllDirty = true
        if event == "TRAIT_CONFIG_UPDATED" then
            -- talented in or out: bars come and go, the CDM settles its lists first
            InvalidateSpellListCache()
            C_Timer.After(0.3, function() TUI:QueueSpecialBarsUpdate() end)
            return
        end
        if event == "COOLDOWN_VIEWER_TABLE_HOTFIXED" then
            if ns.SpecialAura and ns.SpecialAura.InvalidateSpellExpansion then
                ns.SpecialAura.InvalidateSpellExpansion()
            end
            InvalidateSpellListCache()
            TUI:QueueSpecialBarsUpdate()
            return
        end
        OnSpecChanged()
    end)
end

local function ResolveAnchorTarget(anchorName)
    return ns.ANCHORS.ResolveAnchorTarget(anchorName)
end

local function RemoveBarSlot(index, specID)
    local s = GetSpecRoot(specID)
    local count = s.barCount or 0
    if not index or index < 1 or index > count then return end
    local release = SB.ReleaseBar
    if release and not specID then for i = 1, count do release("bar" .. i) end end
    s.bars = s.bars or {}
    for i = index, count - 1 do s.bars["bar" .. i] = s.bars["bar" .. (i + 1)] end
    s.bars["bar" .. count] = nil
    s.barCount = math.max(0, count - 1)
end

local function RemoveIconSlot(index, specID)
    local s = GetSpecRoot(specID)
    local count = s.iconCount or 0
    if not index or index < 1 or index > count then return end
    local release = SB.ReleaseIcon
    if release and not specID then for i = 1, count do release("icon" .. i) end end
    s.icons = s.icons or {}
    for i = index, count - 1 do s.icons["icon" .. i] = s.icons["icon" .. (i + 1)] end
    s.icons["icon" .. count] = nil
    s.iconCount = math.max(0, count - 1)
end

SB.RemoveBarSlot          = RemoveBarSlot
SB.RemoveIconSlot         = RemoveIconSlot
SB.ResolveAnchorTarget    = ResolveAnchorTarget
SB.ScanAndHookCDMChildren = RefreshKnownSpells
SB.specialBarState        = specialBarState
SB.iconGroupState         = iconGroupState
SB.knownBarSpells         = knownBarSpells
SB.knownIconSpells        = knownIconSpells
SB.yoinkedBars            = yoinkedBars

local function GetSpellUsageInfo(spellID, excludeBarKey, excludeIconKey, specID)
    if not spellID then return nil end
    local s = GetSpecRoot(specID)
    for i = 1, (s.barCount or 0) do
        local key = "bar" .. i
        if key ~= excludeBarKey then
            local bd = s.bars and s.bars[key]
            if bd and bd.spellID == spellID and bd.enabled ~= false then
                return "Bar " .. i
            end
        end
    end
    for i = 1, (s.iconCount or 0) do
        local key = "icon" .. i
        if key ~= excludeIconKey then
            local id = s.icons and s.icons[key]
            if id and id.spellID == spellID and id.enabled ~= false then
                return "Icon " .. i
            end
        end
    end
    return nil
end

SB.GetSpellUsageInfo = GetSpellUsageInfo

-- the slot of this kind ("bars"/"icons") holding the spell on the spec, enabled or not
local function FindSlotForSpell(kind, spellID, specID)
    local s = GetSpecRoot(specID)
    local isBar = kind == "bars"
    for i = 1, (isBar and (s.barCount or 0) or (s.iconCount or 0)) do
        local key = (isBar and "bar" or "icon") .. i
        local d = s[kind] and s[kind][key]
        if d and d.spellID == spellID then return key end
    end
end
SB.FindSlotForSpell = FindSlotForSpell
