local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

ns.SpecialBars = ns.SpecialBars or {}

local specialBarState  = {}
local iconGroupState   = {}
local hookedCDMChildren = {}
local lastBarChildCount  = -1
local lastIconChildCount = -1
local cdmSettingsOpen    = false

local knownBarSpells  = {}
local knownIconSpells = {}

local yoinkedBars = ns.yoinkedBars or {}
ns.yoinkedBars = yoinkedBars

local CAT_BUFF = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
local CAT_BAR  = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local SPECIAL_BAR_DEFAULTS = ns.SPECIAL_BAR_DEFAULTS or {
    enabled = false, spellID = nil, spellName = "", width = 230, inheritWidth = false, inheritWidthOffset = 0,
    height = 24, inheritHeight = false, inheritHeightOffset = 0, statusBarTexture = "ElvUI Blank",
    font = "Expressway", fontSize = 14, fontOutline = "OUTLINE", useClassColor = true, customColor = { r = 0.2, g = 0.6, b = 1.0 },
    backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }, showBackdrop = false, backdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },
    iconEnabled = true, iconSpacing = 1, iconZoom = 0.1, showStacks = true, stackFontSize = 14, stackFontOutline = "OUTLINE",
    stackPoint = "CENTER", stackAnchor = "ICON", stackXOffset = 0, stackYOffset = 0, showName = true, namePoint = "LEFT",
    nameXOffset = 2, nameYOffset = 0, showDuration = true, durationPoint = "RIGHT", durationXOffset = -4, durationYOffset = 0,
    anchorMode = "UIParent", anchorFrame = "UIParent", anchorPoint = "CENTER", anchorRelativePoint = "CENTER", anchorXOffset = 0, anchorYOffset = 0,
}

local SPECIAL_ICON_DEFAULTS = ns.SPECIAL_ICON_DEFAULTS or {
    enabled = false, spellID = nil, spellName = "", width = 36, height = 36, keepAspectRatio = true, zoom = 0.1, anchorMode = "UIParent", anchorFrame = "UIParent",
    anchorPoint = "CENTER", anchorRelativePoint = "CENTER", anchorXOffset = 0, anchorYOffset = 0, showCooldown = true, desaturateWhenInactive = false,    -- Border
    showBorder = false, borderSize = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 }, borderInset = 0, borderStroke = false,
    -- Stack count text
    showStacks = true, stackFont = "Expressway", stackFontSize = 14, stackFontOutline = "OUTLINE", stackColor = { r = 1, g = 1, b = 1 },
    stackPoint = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0,    -- Duration/cooldown text
    showDuration = true, durationFont = "Expressway", durationFontSize = 14, durationFontOutline = "OUTLINE",
    durationColor = { r = 1, g = 1, b = 1 }, durationPoint = "CENTER", durationXOffset = 0, durationYOffset = 0,
    -- Glow
    showGlow = false, glowType = "pixel", glowColor = { r = 1, g = 1, b = 0, a = 1 },
    glowN = 8, glowFrequency = 0.25, glowLength = 10, glowThickness = 2,
    glowXOffset = 0, glowYOffset = 0, glowInsideBorder = false,
}

ns.SPECIAL_BAR_DEFAULTS  = SPECIAL_BAR_DEFAULTS
ns.SPECIAL_ICON_DEFAULTS = SPECIAL_ICON_DEFAULTS

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------
local function GetCurrentSpecID()
    local idx = GetSpecialization()
    return idx and GetSpecializationInfo(idx) or 0
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end

local function FillDefaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if tbl[k] == nil then tbl[k] = DeepCopy(v)
        elseif type(v) == "table" and type(tbl[k]) == "table" then FillDefaults(tbl[k], v) end
    end
end

-- ---------------------------------------------------------------------------
-- DB accesserinho
-- ---------------------------------------------------------------------------
local function GetSpecRoot()
    local db = E.db.thingsUI.specialBars
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
    if not s.bars[barKey] then
        s.bars[barKey] = {}
        FillDefaults(s.bars[barKey], SPECIAL_BAR_DEFAULTS)
    end
    return s.bars[barKey]
end

local function GetIconDB(iconKey)
    local s = GetSpecRoot()
    if not s.icons[iconKey] then
        s.icons[iconKey] = {}
        FillDefaults(s.icons[iconKey], SPECIAL_ICON_DEFAULTS)
    end
    return s.icons[iconKey]
end

local function GetBarCount()  return GetSpecRoot().barCount  or 3 end
local function GetIconCount() return GetSpecRoot().iconCount or 3 end

-- ---------------------------------------------------------------------------
-- Spell list cache
-- ---------------------------------------------------------------------------
local cachedSpellList     = nil
local cachedSpellListSpec = nil

local function MergeType(curType, newLabel)
    if not curType or curType == "Unknown" then return newLabel end
    if curType:find(newLabel, 1, true) then return curType end
    return curType .. " & " .. newLabel
end

local function BuildCDMSpellList()
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

    local seenNames = {}

    local function collect(cat, label, includeAll, notDisplayedFlag)
        if not cat then return end
        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, includeAll)
        if ids then
            for _, cdID in ipairs(ids) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info then
                    local spellID = info.overrideSpellID or info.spellID
                    local spellInfo = spellID and C_Spell.GetSpellInfo(spellID)
                    if spellInfo then
                        local existingID = seenNames[spellInfo.name]
                        if existingID and existingID ~= spellID then
                            if list[existingID] then
                                list[existingID].type = MergeType(list[existingID].type, label)
                                if not notDisplayedFlag then list[existingID].notDisplayed = nil end
                            end
                        elseif not list[spellID] then
                            list[spellID] = {
                                name = spellInfo.name,
                                icon = spellInfo.iconID,
                                type = label,
                                notDisplayed = notDisplayedFlag or nil,
                            }
                            seenNames[spellInfo.name] = spellID
                        else
                            list[spellID].type = MergeType(list[spellID].type, label)
                            if not notDisplayedFlag then list[spellID].notDisplayed = nil end
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

    for spellID in pairs(knownBarSpells) do
        if list[spellID] then
            list[spellID].type = MergeType(list[spellID].type, "Bar")
            list[spellID].notDisplayed = nil
        end
    end
    for spellID in pairs(knownIconSpells) do
        if list[spellID] then
            list[spellID].type = MergeType(list[spellID].type, "Icon")
            list[spellID].notDisplayed = nil
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

-- GetBaseSpellID: ONLY call this with clean, plain Lua numbers from our own DB.
-- Never pass CDM-sourced values here — they may be secret numbers that fool
-- type() but still taint table indexing.
local function GetBaseSpellID(spellID)
    -- spellID must be a raw plain number from our DB, never from CDM frames.
    if type(spellID) ~= "number" then return nil end
    local cached = baseSpellCache[spellID]
    if cached ~= nil then return cached end
    local base = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)
    local result = (base and base ~= 0) and base or spellID
    baseSpellCache[spellID] = result
    return result
end

-- IsSafeID: mirrors CDM's IsSafeNumber — uses issecretvalue() (WoW built-in)
-- to detect tainted values before any table indexing or comparison.
local function IsSafeID(value)
    return value ~= nil
        and type(value) == "number"
        and not issecretvalue(value)
end

local function InvalidateSpellCaches()
    wipe(spellInfoCache)
    wipe(baseSpellCache)
end

local _barKeys  = {}
local _iconKeys = {}
local function EnsureSlotKeys(barCount, iconCount)
    if barCount  > #_barKeys  then for i = #_barKeys  + 1, barCount  do _barKeys[i]  = "bar"  .. i end end
    if iconCount > #_iconKeys then for i = #_iconKeys + 1, iconCount do _iconKeys[i] = "icon" .. i end end
end

-- ---------------------------------------------------------------------------
-- Reusable tables for GetChildren() and claimed-frame lookups
-- ---------------------------------------------------------------------------
-- Two separate buffers because ScanAndHookCDMChildren iterates one buffer
-- and may call OnCDMChildShown → UpdateSlot → FindBySpell which needs its own.
local _childrenBufScan = {}   -- used by ScanAndHookCDMChildren only
local _childrenBufFind = {}   -- used by FindBarBySpell / FindIconBySpell only

-- Helper declared once (no closure per call):
local function _packChildrenScan(...)
    local n = select('#', ...)
    for i = 1, #_childrenBufScan do _childrenBufScan[i] = nil end
    for i = 1, n do _childrenBufScan[i] = select(i, ...) end
    return n
end
local function GetChildrenReuseScan(viewer)
    local n = _packChildrenScan(viewer:GetChildren())
    return _childrenBufScan, n
end

local function _packChildrenFind(...)
    local n = select('#', ...)
    for i = 1, #_childrenBufFind do _childrenBufFind[i] = nil end
    for i = 1, n do _childrenBufFind[i] = select(i, ...) end
    return n
end
local function GetChildrenReuseFind(viewer)
    local n = _packChildrenFind(viewer:GetChildren())
    return _childrenBufFind, n
end

-- Reusable claimed-frame tables — rebuilt in-place instead of allocating new tables
local _claimedBarFrames  = {}
local _claimedIconFrames = {}

local function RebuildClaimedBarFrames()
    wipe(_claimedBarFrames)
    for key, state in pairs(specialBarState) do
        if state.childFrame then _claimedBarFrames[state.childFrame] = key end
    end
    return _claimedBarFrames
end

local function RebuildClaimedIconFrames()
    wipe(_claimedIconFrames)
    for key, state in pairs(iconGroupState) do
        if state.childFrame then _claimedIconFrames[state.childFrame] = key end
    end
    return _claimedIconFrames
end

-- ---------------------------------------------------------------------------
-- Combat-Safe Matchers
-- ---------------------------------------------------------------------------
local function CleanString(str)
    if not str or issecretvalue(str) then return "" end
    return tostring(str):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
end

local function GetCooldownInfoForFrame(child)
    if child.GetCooldownInfo then
        local ok, info = pcall(child.GetCooldownInfo, child)
        if ok and info then return info end
    end
    if child.cooldownInfo then return child.cooldownInfo end
    local cid = child.cooldownID
    if cid and C_CooldownViewer then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
        if ok then return info end
    end
    return nil
end

local function SafeMatch(child, spellID, wantsBar)
    if not child then return false end
    if wantsBar and not child.Bar then return false end
    if not wantsBar and (not child.Icon or child.Bar) then return false end

    local baseTarget = GetBaseSpellID(spellID)  -- plain or nil

    local info = GetCooldownInfoForFrame(child)
    if info then
        local sid = info.overrideSpellID or info.spellID
        if IsSafeID(sid) then
            local bsid = GetBaseSpellID(sid)  -- safe now, sid is plain
            if sid == spellID or sid == baseTarget or bsid == spellID or bsid == baseTarget then
                return true
            end
        end
        if info.linkedSpellIDs then
            for _, lid in ipairs(info.linkedSpellIDs) do
                if IsSafeID(lid) then
                    local blid = GetBaseSpellID(lid)
                    if lid == spellID or lid == baseTarget or blid == spellID or blid == baseTarget then
                        return true
                    end
                end
            end
        end
    end

    local aura = child.auraSpellID
    if IsSafeID(aura) then
        local baura = GetBaseSpellID(aura)
        if aura == spellID or aura == baseTarget or baura == spellID or baura == baseTarget then
            return true
        end
    end
    local ph = child._cdmPHSpellID
    if IsSafeID(ph) then
        local bph = GetBaseSpellID(ph)
        if ph == spellID or ph == baseTarget or bph == spellID or bph == baseTarget then
            return true
        end
    end

    -- Tertiary: bar name text match (bars only, no texture — texture is secret).
    local spellInfo = GetCachedSpellInfo(spellID)
    if not spellInfo then return false end    if wantsBar and spellInfo.name then
        local targetName = CleanString(spellInfo.name)        if child.Bar and child.Bar.Name then
            local ok, raw = pcall(child.Bar.Name.GetText, child.Bar.Name)
            if ok and raw and not issecretvalue(raw) then
                local barText = CleanString(raw)
                if barText == targetName then return true end
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- CDM child hooks (OnShow / OnHide)
-- ---------------------------------------------------------------------------
local function GetUpdateBarSlot()  return ns.SpecialBars.UpdateBarSlot  end
local function GetUpdateIconSlot() return ns.SpecialBars.UpdateIconSlot end
local function GetReleaseBar()     return ns.SpecialBars.ReleaseBar     end
local function GetReleaseIcon()    return ns.SpecialBars.ReleaseIcon    end

local function _doReturnFrame(child)
    child:SetParent(child._cdmOriginalParent)
    child:ClearAllPoints()
    if child._cdmOriginalW and child._cdmOriginalH then
        child:SetSize(child._cdmOriginalW, child._cdmOriginalH)
    end
    if child._tuiBarBgRegions then
        for r, alpha in pairs(child._tuiBarBgRegions) do
            pcall(r.SetAlpha, r, alpha)
        end
        wipe(child._tuiBarBgRegions)
    end
    -- Restore original icon styling saved by StyleYoinkedIcon
    local orig = child._tuiOrigStyle
    if orig then
        -- Icon texcoord
        if child.Icon and orig.iconTexCoords and child.Icon.SetTexCoord then
            child.Icon:SetTexCoord(unpack(orig.iconTexCoords))
        end
        -- Cooldown swipe/edge
        if child.Cooldown then
            if orig.drawSwipe ~= nil then child.Cooldown:SetDrawSwipe(orig.drawSwipe) end
            if orig.drawEdge  ~= nil then child.Cooldown:SetDrawEdge(orig.drawEdge) end
            -- Restore duration FontString(s)
            if orig.cdFont then
                for i = 1, child.Cooldown:GetNumRegions() do
                    local r = select(i, child.Cooldown:GetRegions())
                    if r and r.GetObjectType and r:GetObjectType() == 'FontString' then
                        pcall(r.SetFont, r, orig.cdFont, orig.cdFontSize, orig.cdFontOut)
                        r:SetTextColor(orig.cdR, orig.cdG, orig.cdB)
                        r:ClearAllPoints()
                        if orig.cdPoint and orig.cdRelTo then
                            r:SetPoint(orig.cdPoint, orig.cdRelTo, orig.cdRelPt, orig.cdX, orig.cdY)
                        end
                        if orig.cdShown then r:Show() else r:Hide() end
                    end
                end
            end
        end
        -- Restore stack count (Applications)
        local app = child.Applications
            and child.Applications.Applications
            or  child.Applications
        if app then
            if orig.appFont then
                pcall(app.SetFont, app, orig.appFont, orig.appFontSize, orig.appFontOut)
            end
            if orig.appR then app:SetTextColor(orig.appR, orig.appG, orig.appB) end
            app:SetAlpha(orig.appAlpha or 1)
            app:ClearAllPoints()
            if orig.appPoint and orig.appRelTo then
                app:SetPoint(orig.appPoint, orig.appRelTo, orig.appRelPt, orig.appX, orig.appY)
            end
        end
        child._tuiOrigStyle = nil
    end
end

local function ReturnFrame(child)
    if not child then return end
    if child._cdmOriginalParent then
        pcall(_doReturnFrame, child)
    end
    yoinkedBars[child] = nil
end

-- Helpers for OnCDMChildShown — declared once, zero closures per call
local function _registerShownSpell(childFrame)
    local cid = childFrame.cooldownID
    if cid and C_CooldownViewer then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cid)
        if info then
            local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
            if si and si.spellID then
                local cleanID = si.spellID
                local changed = false
                if childFrame.Bar and not knownBarSpells[cleanID] then
                    knownBarSpells[cleanID] = true; changed = true
                elseif childFrame.Icon and not childFrame.Bar and not knownIconSpells[cleanID] then
                    knownIconSpells[cleanID] = true; changed = true
                end
                if changed then InvalidateSpellListCache() end
            end
        end
    end
end

local function OnCDMChildShown(childFrame)
    if not childFrame then return end
    pcall(childFrame.SetAlpha, childFrame, 0)

    pcall(_registerShownSpell, childFrame)

    if childFrame.Bar then
        local fn = GetUpdateBarSlot()
        if fn then
            local bc = GetBarCount()
            EnsureSlotKeys(bc, 0)
            for i = 1, bc do
                local key = _barKeys[i]
                local db = GetBarDB(key)
                if db.enabled and db.spellID and SafeMatch(childFrame, db.spellID, true) then
                    pcall(fn, key)
                end
            end
        end
    elseif childFrame.Icon then
        local fn = GetUpdateIconSlot()
        if fn then
            local ic = GetIconCount()
            EnsureSlotKeys(0, ic)
            for i = 1, ic do
                local key = _iconKeys[i]
                local db = GetIconDB(key)
                if db.enabled and db.spellID and SafeMatch(childFrame, db.spellID, false) then
                    pcall(fn, key)
                end
            end
        end
    end

    pcall(childFrame.SetAlpha, childFrame, 1)
end

local function OnCDMChildHidden(childFrame)
    if yoinkedBars[childFrame] then
        ReturnFrame(childFrame)
        TUI:QueueSpecialBarsUpdate()
    end
end

-- Reusable viewers list — rebuilt in-place each call (frames may not exist at load)
local _scanViewers = {
    { frame = false, isBar = true  },
    { frame = false, isBar = false },
}

local function ScanAndHookCDMChildren()
    _scanViewers[1].frame = BuffBarCooldownViewer  or false
    _scanViewers[2].frame = BuffIconCooldownViewer or false

    for _, entry in ipairs(_scanViewers) do
        local viewer = entry.frame
        if viewer then
            local children, childCount = GetChildrenReuseScan(viewer)
            for i = 1, childCount do
                local child = children[i]
                -- Register spell ID from visible children (out of combat only)
                if not InCombatLockdown() and C_CooldownViewer and child:IsShown() then
                    local cid = child.cooldownID
                    if cid then
                        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
                        if ok and info then
                            -- Route through GetSpellInfo to get a clean plain spellID
                            local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                            if si and si.spellID then
                                local cleanID = si.spellID
                                local changed = false
                                if entry.isBar and not knownBarSpells[cleanID] then
                                    knownBarSpells[cleanID] = true; changed = true
                                elseif not entry.isBar and not knownIconSpells[cleanID] then
                                    knownIconSpells[cleanID] = true; changed = true
                                end
                                if changed then InvalidateSpellListCache() end
                            end
                        end
                    end
                end
                -- Hook new children only
                if not hookedCDMChildren[child] then
                    hookedCDMChildren[child] = true
                    child._cdmOriginalParent = child:GetParent()
                    pcall(child.HookScript, child, "OnShow", OnCDMChildShown)
                    pcall(child.HookScript, child, "OnHide", OnCDMChildHidden)
                    if child:IsShown() then pcall(OnCDMChildShown, child) end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- QueueSpecialBarsUpdate
-- ---------------------------------------------------------------------------
local specialBarsUpdateQueued = false
-- Pre-allocated callback — avoids creating a new closure on every queue call
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

local cdmMixinHooked = false
local function HookCDMMixins()
    if cdmMixinHooked then return end    local function OnCooldownIDSetIcon(frame)
        -- Register spell ID immediately without waiting for OnShow.
        -- info fields are SECRET — route through GetSpellInfo for a clean key.
        if C_CooldownViewer then
            local info = GetCooldownInfoForFrame(frame)
            if info then
                local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                if si and si.spellID and not knownIconSpells[si.spellID] then
                    knownIconSpells[si.spellID] = true
                    InvalidateSpellListCache()
                end
                if info.linkedSpellIDs then
                    for _, lid in ipairs(info.linkedSpellIDs) do
                        local ls = C_Spell.GetSpellInfo(lid)
                        if ls and ls.spellID and not knownIconSpells[ls.spellID] then
                            knownIconSpells[ls.spellID] = true
                            InvalidateSpellListCache()
                        end
                    end
                end
            end
        end
        TUI:QueueSpecialBarsUpdate()
    end

    local function OnCooldownIDSetBar(frame)
        if C_CooldownViewer then
            local info = GetCooldownInfoForFrame(frame)
            if info then
                local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                if si and si.spellID and not knownBarSpells[si.spellID] then
                    knownBarSpells[si.spellID] = true
                    InvalidateSpellListCache()
                end
                if info.linkedSpellIDs then
                    for _, lid in ipairs(info.linkedSpellIDs) do
                        local ls = C_Spell.GetSpellInfo(lid)
                        if ls and ls.spellID and not knownBarSpells[ls.spellID] then
                            knownBarSpells[ls.spellID] = true
                            InvalidateSpellListCache()
                        end
                    end
                end
            end
        end
        TUI:QueueSpecialBarsUpdate()
    end

    if CooldownViewerBuffIconItemMixin and CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", OnCooldownIDSetIcon)
        cdmMixinHooked = true
    end
    if CooldownViewerBuffBarItemMixin and CooldownViewerBuffBarItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", OnCooldownIDSetBar)
        cdmMixinHooked = true
    end
end

-- ---------------------------------------------------------------------------
-- CDM settings window hook
-- ---------------------------------------------------------------------------
local function HookCDMWindow()
    if ns.__cdmWindowHooked then return end
    local f = _G.CooldownViewerSettings
    if not f then return end
    ns.__cdmWindowHooked = true
    local function _onCDMShow()
        cdmSettingsOpen    = true
        lastBarChildCount  = -1
        lastIconChildCount = -1
        InvalidateSpellListCache()
        TUI:QueueSpecialBarsUpdate()
    end
    local function _onCDMHideDeferred() TUI:UpdateSpecialBars() end
    local function _onCDMHide()
        cdmSettingsOpen    = false
        lastBarChildCount  = -1
        lastIconChildCount = -1
        InvalidateSpellListCache()
        C_Timer.After(0.1, _onCDMHideDeferred)
    end
    pcall(f.HookScript, f, "OnShow", _onCDMShow)
    pcall(f.HookScript, f, "OnHide", _onCDMHide)
end

-- ---------------------------------------------------------------------------
-- UpdateSpecialBars (main entry point called from options + enforcer)
-- ---------------------------------------------------------------------------
function TUI:UpdateSpecialBars()
    if not E.db.thingsUI.specialBars then return end
    ScanAndHookCDMChildren()
    HookCDMWindow()
    HookCDMMixins()

    local barCount = GetBarCount()
    local releaseBar = ns.SpecialBars.ReleaseBar
    for key in pairs(specialBarState) do
        local idx = tonumber(key:match("^bar(%d+)$"))
        if not idx or idx > barCount then releaseBar(key) end
    end
    EnsureSlotKeys(barCount, 0)
    local updateBar = ns.SpecialBars.UpdateBarSlot
    for i = 1, barCount do updateBar(_barKeys[i]) end

    local iconCount = GetIconCount()
    local releaseIcon = ns.SpecialBars.ReleaseIcon
    for key in pairs(iconGroupState) do
        local idx = tonumber(key:match("^icon(%d+)$"))
        if not idx or idx > iconCount then releaseIcon(key) end
    end
    EnsureSlotKeys(0, iconCount)
    local updateIcon = ns.SpecialBars.UpdateIconSlot
    for i = 1, iconCount do updateIcon(_iconKeys[i]) end
end

-- ---------------------------------------------------------------------------
-- Brute-Force Enforcer (20 fps)
-- ---------------------------------------------------------------------------
local enforcer = CreateFrame("Frame")
local enforceTimer = 0
enforcer:SetScript("OnUpdate", function(_, elapsed)
    enforceTimer = enforceTimer + elapsed
    if enforceTimer < 0.05 then return end
    enforceTimer = 0

    local curBarCount  = BuffBarCooldownViewer  and BuffBarCooldownViewer:GetNumChildren()  or 0
    local curIconCount = BuffIconCooldownViewer and BuffIconCooldownViewer:GetNumChildren() or 0
    if curBarCount ~= lastBarChildCount or curIconCount ~= lastIconChildCount then
        lastBarChildCount  = curBarCount
        lastIconChildCount = curIconCount
        ScanAndHookCDMChildren()
        local bc = GetBarCount()
        local ic = GetIconCount()
        EnsureSlotKeys(bc, ic)
        local updateBar  = ns.SpecialBars.UpdateBarSlot
        local updateIcon = ns.SpecialBars.UpdateIconSlot
        if updateBar  then for i = 1, bc do updateBar(_barKeys[i])   end end
        if updateIcon then for i = 1, ic do updateIcon(_iconKeys[i]) end end
    end

    -- Re-anchor active frames — only when parent or size actually drifted
    for _, state in pairs(specialBarState) do
        local child   = state.childFrame
        local wrapper = state.wrapper
        if child and wrapper and child:IsShown() then
            if child:GetParent() ~= wrapper then
                child:SetParent(wrapper)
                child:ClearAllPoints()
                child:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
            end
            if state.w and state.h then
                local cw, ch = child:GetSize()
                if cw ~= state.w or ch ~= state.h then
                    child:SetSize(state.w, state.h)
                end
            end
        end
    end

    for _, state in pairs(iconGroupState) do
        local child   = state.childFrame
        local wrapper = state.wrapper
        if child and wrapper and child:IsShown() then
            if child:GetParent() ~= wrapper then
                child:SetParent(wrapper)
                child:ClearAllPoints()
                child:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
            end
            if state.w and state.h then
                local cw, ch = child:GetSize()
                if cw ~= state.w or ch ~= state.h then
                    child:SetSize(state.w, state.h)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Spec change handler
-- ---------------------------------------------------------------------------
local function OnSpecChanged()
    InvalidateSpellListCache()
    InvalidateSpellCaches()
    local releaseBar  = ns.SpecialBars.ReleaseBar
    local releaseIcon = ns.SpecialBars.ReleaseIcon
    for k in pairs(specialBarState)  do releaseBar(k)  end
    for k in pairs(iconGroupState)   do releaseIcon(k) end
    wipe(hookedCDMChildren)
    wipe(ns.yoinkedBars)
    wipe(knownBarSpells)
    wipe(knownIconSpells)
    lastBarChildCount  = -1
    lastIconChildCount = -1
    TUI:QueueSpecialBarsUpdate()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
        OnSpecChanged()
    end)
end

-- ---------------------------------------------------------------------------
-- Exports via ns.SpecialBars (consumed by SpecialBarOptions.lua and siblings)
-- ---------------------------------------------------------------------------
local SB = ns.SpecialBars

SB.GetSpecRoot             = GetSpecRoot
SB.GetBarDB                = GetBarDB
SB.GetIconDB               = GetIconDB
SB.GetBarCount             = GetBarCount
SB.GetIconCount            = GetIconCount
SB.GetRawSpellList         = GetRawSpellList
SB.InvalidateSpellListCache = InvalidateSpellListCache
SB.InvalidateSpellCaches   = InvalidateSpellCaches
SB.GetBaseSpellID          = GetBaseSpellID
SB.ScanAndHookCDMChildren  = ScanAndHookCDMChildren
SB.ReturnFrame             = ReturnFrame
SB.SafeMatch               = SafeMatch
SB.specialBarState         = specialBarState
SB.iconGroupState          = iconGroupState
SB.knownBarSpells          = knownBarSpells
SB.knownIconSpells         = knownIconSpells
SB.yoinkedBars             = yoinkedBars
SB.RebuildClaimedBarFrames  = RebuildClaimedBarFrames
SB.RebuildClaimedIconFrames = RebuildClaimedIconFrames
SB.GetChildrenReuseFind     = GetChildrenReuseFind

-- GetSpellUsageInfo — needs bar/icon DB, lives here since it spans both types
local function GetSpellUsageInfo(spellID, excludeBarKey, excludeIconKey)
    if not spellID then return nil end
    local s = GetSpecRoot()
    for i = 1, (s.barCount or 3) do
        local key = "bar" .. i
        if key ~= excludeBarKey then
            local bd = s.bars and s.bars[key]
            if bd and bd.spellID == spellID and bd.enabled ~= false then
                return "Bar " .. i
            end
        end
    end
    for i = 1, (s.iconCount or 3) do
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
