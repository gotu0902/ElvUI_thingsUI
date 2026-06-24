local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

ns.SpecialBars = ns.SpecialBars or {}

local specialBarState  = {}
local iconGroupState   = {}
local hookedCDMChildren = {}
local lastBarShownSig  = -1
local lastIconShownSig = -1
local cdmSettingsOpen    = false

local knownBarSpells  = {}
local knownIconSpells = {}

local yoinkedBars = ns.yoinkedBars or {}
ns.yoinkedBars = yoinkedBars

local SB = ns.SpecialBars

local GetSpecRoot   = SB.GetSpecRoot
local GetBarDB      = SB.GetBarDB
local GetIconDB     = SB.GetIconDB
local GetBarCount   = SB.GetBarCount
local GetIconCount  = SB.GetIconCount
local GetCachedSpellInfo       = SB.GetCachedSpellInfo
local GetBaseSpellID           = SB.GetBaseSpellID
local InvalidateSpellListCache = SB.InvalidateSpellListCache
local InvalidateSpellCaches    = SB.InvalidateSpellCaches

local function IsSafeID(value)
    return value ~= nil
        and type(value) == "number"
        and not issecretvalue(value)
end

local _barKeys  = {}
local _iconKeys = {}
local function EnsureSlotKeys(barCount, iconCount)
    if barCount  > #_barKeys  then for i = #_barKeys  + 1, barCount  do _barKeys[i]  = "bar"  .. i end end
    if iconCount > #_iconKeys then for i = #_iconKeys + 1, iconCount do _iconKeys[i] = "icon" .. i end end
end

local _childrenBufScan = {}
local _childrenBufFind = {}

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

local function CleanString(str)
    if not str or issecretvalue(str) then return "" end
    return tostring(str):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
end

local function GetCooldownInfoForFrame(child)
    if child.GetCooldownInfo then
        local info = child:GetCooldownInfo()
        if info then return info end
    end
    if child.cooldownInfo then return child.cooldownInfo end
    local cid = child.cooldownID
    if cid and C_CooldownViewer then
        return C_CooldownViewer.GetCooldownViewerCooldownInfo(cid)
    end
    return nil
end

local function SafeMatch(child, spellID, wantsBar)
    if not child then return false end
    if wantsBar and not child.Bar then return false end
    if not wantsBar and (not child.Icon or child.Bar) then return false end

    local baseTarget = GetBaseSpellID(spellID)

    local info = GetCooldownInfoForFrame(child)
    if info then
        local sid = info.overrideSpellID or info.spellID
        if IsSafeID(sid) then
            local bsid = GetBaseSpellID(sid)
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

    local spellInfo = GetCachedSpellInfo(spellID)
    if not spellInfo then return false end
    if wantsBar and spellInfo.name then
        local targetName = CleanString(spellInfo.name)
        if child.Bar and child.Bar.Name then
            local raw = child.Bar.Name:GetText()
            if raw and not issecretvalue(raw) then
                local barText = CleanString(raw)
                if barText == targetName then return true end
            end
        end
    end

    return false
end

local function IsChildClaimedBySpecial(child)
    if not (child and child.Bar) then return false end
    local bc = GetBarCount()
    EnsureSlotKeys(bc, 0)
    for i = 1, bc do
        local db = GetBarDB(_barKeys[i])
        if db.enabled and db.spellID and SafeMatch(child, db.spellID, true) then
            return true
        end
    end
    return false
end
ns.SpecialBars.IsChildClaimedBySpecial = IsChildClaimedBySpecial

local function GetUpdateBarSlot()  return ns.SpecialBars.UpdateBarSlot  end
local function GetUpdateIconSlot() return ns.SpecialBars.UpdateIconSlot end
local function GetReleaseBar()     return ns.SpecialBars.ReleaseBar     end
local function GetReleaseIcon()    return ns.SpecialBars.ReleaseIcon    end

local function _doReturnFrame(child)

    UIParent.SetParent(child, child._cdmOriginalParent)
    UIParent.ClearAllPoints(child)
    if child._cdmOriginalW and child._cdmOriginalH then
        UIParent.SetSize(child, child._cdmOriginalW, child._cdmOriginalH)
    end

    if child._cdmOriginalStrata then
        UIParent.SetFrameStrata(child, child._cdmOriginalStrata)
        UIParent.SetFrameLevel(child, child._cdmOriginalLevel or 0)
    end
    if child._tuiBarBgRegions then
        for r, alpha in pairs(child._tuiBarBgRegions) do
            r:SetAlpha(alpha)
        end
        wipe(child._tuiBarBgRegions)
    end

    if child._tuiBarTextSaved then
        local s, bar = child._tuiBarTextSaved, child.Bar
        if bar then
            if bar.Name     and s.nameAlpha then bar.Name:SetAlpha(s.nameAlpha) end
            if bar.Duration and s.durAlpha  then bar.Duration:SetAlpha(s.durAlpha) end
        end
        child._tuiBarTextSaved = nil
    end
    local orig = child._tuiOrigStyle
    if orig then
        if child.Icon and orig.iconTexCoords and child.Icon.SetTexCoord then
            child.Icon:SetTexCoord(unpack(orig.iconTexCoords))
        end
        if child.Icon and orig.iconScale and child.Icon.SetScale then
            child.Icon:SetScale(orig.iconScale)
        end
        if child.Cooldown then
            if orig.drawSwipe ~= nil then child.Cooldown:SetDrawSwipe(orig.drawSwipe) end
            if orig.drawEdge  ~= nil then child.Cooldown:SetDrawEdge(orig.drawEdge) end
            if orig.cdFont then
                for i = 1, child.Cooldown:GetNumRegions() do
                    local r = select(i, child.Cooldown:GetRegions())
                    if r and r.GetObjectType and r:GetObjectType() == 'FontString' then
                        E:SetFont(r, orig.cdFont, orig.cdFontSize, orig.cdFontOut)
                        if orig.cdR then r:SetTextColor(orig.cdR, orig.cdG, orig.cdB) end
                        r:SetAlpha(orig.cdShown and 1 or 0)

                        local c = orig.cdPoint
                        if c and not (issecretvalue(c.p) or issecretvalue(c.rp) or issecretvalue(c.x) or issecretvalue(c.y)) then
                            r:ClearAllPoints()
                            r:SetPoint(c.p, c.rel, c.rp or c.p, c.x, c.y)
                        end
                    end
                end
            end
        end
        local app = child.Applications
            and child.Applications.Applications
            or  child.Applications
        if app then
            if orig.appFont then
                E:SetFont(app, orig.appFont, orig.appFontSize, orig.appFontOut)
            end
            if orig.appR then app:SetTextColor(orig.appR, orig.appG, orig.appB) end
            app:SetAlpha(orig.appAlpha or 1)
            local c = orig.appPoint
            if c and not (issecretvalue(c.p) or issecretvalue(c.rp) or issecretvalue(c.x) or issecretvalue(c.y)) then
                app:ClearAllPoints()
                app:SetPoint(c.p, c.rel, c.rp or c.p, c.x, c.y)
            end
        end
        child._tuiOrigStyle = nil
    end
end

local function ReturnFrame(child)
    if not child then return end
    if child._cdmOriginalParent then
        _doReturnFrame(child)

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if ns.CDMIcons and ns.CDMIcons.RefreshAll then ns.CDMIcons.RefreshAll() end
                if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            end)
        end
    end
    yoinkedBars[child] = nil
    child._tuiYoinkActive = nil
end

local function _registerShownSpell(childFrame)
    local cid = childFrame.cooldownID
    if cid and C_CooldownViewer then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cid)
        if info then
            local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
            if si and si.spellID then
                local cleanID = si.spellID

                local linkedID = info.linkedSpellIDs and info.linkedSpellIDs[1]
                local changed = false
                local function mark(set, key)
                    if key and not set[key] then set[key] = true; changed = true end
                end
                if childFrame.Bar then
                    mark(knownBarSpells, cleanID)
                    mark(knownBarSpells, linkedID)
                elseif childFrame.Icon then
                    mark(knownIconSpells, cleanID)
                    mark(knownIconSpells, linkedID)
                end
                if changed then InvalidateSpellListCache() end
            end
        end
    end
end

local function OnCDMChildShown(childFrame)
    if not childFrame then return end
    childFrame:SetAlpha(0)

    _registerShownSpell(childFrame)

    if childFrame.Bar then
        local fn = GetUpdateBarSlot()
        if fn then
            local bc = GetBarCount()
            EnsureSlotKeys(bc, 0)
            for i = 1, bc do
                local key = _barKeys[i]
                local db = GetBarDB(key)
                if db.enabled and db.spellID and SafeMatch(childFrame, db.spellID, true) then
                    fn(key)
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
                    fn(key)
                end
            end
        end
    end

    childFrame:SetAlpha(1)
end

local function OnCDMChildHidden(childFrame)
    if yoinkedBars[childFrame] then
        ReturnFrame(childFrame)
        TUI:QueueSpecialBarsUpdate()
    end
end

local _scanViewers = {
    { frame = false, isBar = true  },
    { frame = false, isBar = false },
}

local OnSpecialChildAura

local _iconSpellToKey = {}

local _applyingSpecialIcon = false
local function OnSpecialChildSetPoint(child)
    local key = child._tuiSpecialIconKey
    if not key or _applyingSpecialIcon then return end
    local upd = ns.SpecialBars.UpdateIconSlot
    if yoinkedBars[child] then

        local wrapper = _G["TUI_SpecialIcon_" .. key]
        if not wrapper then return end
        _applyingSpecialIcon = true
        UIParent.SetFrameStrata(child, wrapper:GetFrameStrata())
        UIParent.SetFrameLevel(child, wrapper:GetFrameLevel() + 1)
        UIParent.ClearAllPoints(child)
        UIParent.SetPoint(child, "CENTER", wrapper, "CENTER", 0, 0)
        _applyingSpecialIcon = nil
        return
    end
    if not upd then return end
    _applyingSpecialIcon = true
    upd(key)
    _applyingSpecialIcon = nil
end

local function ScanAndHookCDMChildren()
    _scanViewers[1].frame = BuffBarCooldownViewer  or false
    _scanViewers[2].frame = BuffIconCooldownViewer or false

    local barViewer  = _scanViewers[1].frame
    local iconViewer = _scanViewers[2].frame
    local barHasChildren  = barViewer  and barViewer:GetNumChildren()  > 0
    local iconHasChildren = iconViewer and iconViewer:GetNumChildren() > 0
    local rebuilding = barHasChildren or iconHasChildren
    if rebuilding then
        wipe(knownBarSpells)
        wipe(knownIconSpells)
        InvalidateSpellListCache()
    end

    wipe(_iconSpellToKey)
    for i = 1, GetIconCount() do
        local idb = GetIconDB("icon" .. i)
        if idb and idb.enabled ~= false and idb.spellID then _iconSpellToKey[idb.spellID] = "icon" .. i end
    end

    for _, entry in ipairs(_scanViewers) do
        local viewer = entry.frame
        if viewer then
            local children, childCount = GetChildrenReuseScan(viewer)
            for i = 1, childCount do
                local child = children[i]
                if not InCombatLockdown() and C_CooldownViewer then
                    local cid = child.cooldownID
                    if cid then
                        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cid)
                        if info then
                            local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                            if si and si.spellID then
                                local cleanID = si.spellID
                                local linkedID = info.linkedSpellIDs and info.linkedSpellIDs[1]
                                local set = entry.isBar and knownBarSpells or knownIconSpells
                                set[cleanID] = true
                                if linkedID then set[linkedID] = true end

                                if not entry.isBar then
                                    child._tuiSpecialIconKey = _iconSpellToKey[cleanID]
                                        or (linkedID and _iconSpellToKey[linkedID]) or nil
                                end
                            end
                        end
                    end
                end
                if not hookedCDMChildren[child] then
                    hookedCDMChildren[child] = true
                    child._cdmOriginalParent = child:GetParent()
   
                    hooksecurefunc(child, "SetPoint", OnSpecialChildSetPoint)

                    if type(child.OnAuraInstanceInfoSet) == "function" then
                        hooksecurefunc(child, "OnAuraInstanceInfoSet", function()
                            if OnSpecialChildAura then OnSpecialChildAura() end
                        end)
                    end
                    if type(child.OnAuraInstanceInfoCleared) == "function" then
                        hooksecurefunc(child, "OnAuraInstanceInfoCleared", function()
                            if OnSpecialChildAura then OnSpecialChildAura() end
                        end)
                    end
                    if child:IsShown() then OnCDMChildShown(child) end
                end
            end
        end
    end

    if rebuilding then
        for child in pairs(yoinkedBars) do
            if child and C_CooldownViewer then
                local cid = child.cooldownID
                if cid then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cid)
                    if info then
                        local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                        if si and si.spellID then
                            local cleanID = si.spellID
                            local linkedID = info.linkedSpellIDs and info.linkedSpellIDs[1]
                            local set
                            if child.Bar then set = knownBarSpells
                            elseif child.Icon then set = knownIconSpells end
                            if set then
                                set[cleanID] = true
                                if linkedID then set[linkedID] = true end
                            end
                        end
                    end
                end
            end
        end
    end
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

local cdmMixinHooked = false
local function HookCDMMixins()
    if cdmMixinHooked then return end
    local function OnCooldownIDSetIcon(frame)
        if C_CooldownViewer then
            local info = GetCooldownInfoForFrame(frame)
            if info then
                local si = C_Spell.GetSpellInfo(info.overrideSpellID or info.spellID)
                if si and si.spellID and not knownIconSpells[si.spellID] then
                    knownIconSpells[si.spellID] = true
                    InvalidateSpellListCache()
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

local function HookCDMWindow()
    if ns.__cdmWindowHooked then return end
    local f = _G.CooldownViewerSettings
    if not f then return end
    ns.__cdmWindowHooked = true
    local function _onCDMShow()
        cdmSettingsOpen    = true
        lastBarShownSig  = -1
        lastIconShownSig = -1
        InvalidateSpellListCache()
        if ns.MarkEnforceDirty then ns.MarkEnforceDirty() end
        TUI:QueueSpecialBarsUpdate()
    end
    local function _onCDMHideDeferred() TUI:UpdateSpecialBars() end
    local function _onCDMHide()
        cdmSettingsOpen    = false
        lastBarShownSig  = -1
        lastIconShownSig = -1
        InvalidateSpellListCache()
        if ns.MarkEnforceDirty then ns.MarkEnforceDirty() end
        C_Timer.After(0.1, _onCDMHideDeferred)
    end
    f:HookScript("OnShow", _onCDMShow)
    f:HookScript("OnHide", _onCDMHide)
end

local function HookViewerRefreshLayouts()
    if ns.__cdmViewerRefreshHooked then return end
    local viewers = {
        "EssentialCooldownViewer", "UtilityCooldownViewer",
        "BuffIconCooldownViewer", "BuffBarCooldownViewer",
    }
    local anyHooked = false
    for _, name in ipairs(viewers) do
        local v = _G[name]
        if v and type(v.RefreshLayout) == "function" then
            hooksecurefunc(v, "RefreshLayout", function()
                lastBarShownSig  = -1
                lastIconShownSig = -1
                InvalidateSpellListCache()
                if ns.SpecialBars._ResetRetryBudget then
                    ns.SpecialBars._ResetRetryBudget()
                end
                if ns.MarkEnforceDirty then ns.MarkEnforceDirty() end
                TUI:QueueSpecialBarsUpdate()
            end)
            anyHooked = true
        end
    end
    if anyHooked then ns.__cdmViewerRefreshHooked = true end
end

local retryScheduled = false
local retriesUsed = 0
local MAX_RETRIES_PER_ROUND = 2

local function ResetRetryBudget()
    retriesUsed = 0
end

ns.SpecialBars._ResetRetryBudget = ResetRetryBudget

local function ScheduleSlotRetry()
    if retryScheduled then return end
    if retriesUsed >= MAX_RETRIES_PER_ROUND then return end
    retryScheduled = true
    retriesUsed = retriesUsed + 1
    C_Timer.After(0.3, function()
        retryScheduled = false
        if TUI and TUI.UpdateSpecialBars then TUI:UpdateSpecialBars() end
    end)
end

function TUI:UpdateSpecialBars()
    if not E.db.thingsUI.specialBars then return end
    ScanAndHookCDMChildren()
    HookCDMWindow()
    HookViewerRefreshLayouts()
    HookCDMMixins()

    local barCount = GetBarCount()
    local releaseBar = ns.SpecialBars.ReleaseBar
    local hideBarMover = ns.SpecialBars.HideBarMover
    for key in pairs(specialBarState) do
        local idx = tonumber(key:match("^bar(%d+)$"))
        if not idx or idx > barCount then if releaseBar then releaseBar(key) end end
    end

    if hideBarMover then
        for i = barCount + 1, 12 do hideBarMover("bar" .. i) end
    end
    EnsureSlotKeys(barCount, 0)
    local updateBar = ns.SpecialBars.UpdateBarSlot
    if updateBar then for i = 1, barCount do updateBar(_barKeys[i]) end end

    local iconCount = GetIconCount()
    local releaseIcon = ns.SpecialBars.ReleaseIcon
    local hideIconMover = ns.SpecialBars.HideIconMover
    for key in pairs(iconGroupState) do
        local idx = tonumber(key:match("^icon(%d+)$"))
        if not idx or idx > iconCount then if releaseIcon then releaseIcon(key) end end
    end
    if hideIconMover then
        for i = iconCount + 1, 12 do hideIconMover("icon" .. i) end
    end
    EnsureSlotKeys(0, iconCount)
    local updateIcon = ns.SpecialBars.UpdateIconSlot
    if updateIcon then for i = 1, iconCount do updateIcon(_iconKeys[i]) end end

    local needsRetry = false
    for i = 1, barCount do
        local db = GetBarDB(_barKeys[i])
        local st = specialBarState[_barKeys[i]]
        if db and db.enabled and db.spellID and not (st and st.childFrame) then
            needsRetry = true; break
        end
    end
    if not needsRetry then
        for i = 1, iconCount do
            local db = GetIconDB(_iconKeys[i])
            local st = iconGroupState[_iconKeys[i]]
            if db and db.enabled and db.spellID and not (st and st.childFrame) then
                needsRetry = true; break
            end
        end
    end
    if needsRetry then ScheduleSlotRetry() end
end

local enforcer = CreateFrame("Frame")
local enforceDirty = false
local enforceTimer = 0
local ENFORCE_INTERVAL = 0.05

local function MarkEnforceDirty()
    enforceDirty = true
end
ns.MarkEnforceDirty = MarkEnforceDirty

local function ShownSig(viewer)
    if not viewer then return 0 end
    local sig = 0
    local kids, n = GetChildrenReuseScan(viewer)
    for i = 1, n do
        local c = kids[i]
        if c and c:IsShown() then
            local id = c.cooldownID
            if type(id) ~= "number" then id = 0 end
            sig = sig + id * i
        end
    end
    return sig
end

local function HeldShownSig(stateTable)
    local sig = 0
    for key, state in pairs(stateTable) do
        local c = state.childFrame
        if c and c:IsShown() then
            sig = sig + (tonumber(key:match("(%d+)$")) or 0)
        end
    end
    return sig
end

local function RunEnforce(force)
    if ns.CDMIcons and ns.CDMIcons.IsRebuilding and ns.CDMIcons.IsRebuilding() then return end
    local curBarSig  = ShownSig(BuffBarCooldownViewer)  + HeldShownSig(specialBarState)
    local curIconSig = ShownSig(BuffIconCooldownViewer) + HeldShownSig(iconGroupState)
    local changed = (curBarSig ~= lastBarShownSig or curIconSig ~= lastIconShownSig)
    if changed then
        lastBarShownSig  = curBarSig
        lastIconShownSig = curIconSig
        ScanAndHookCDMChildren()
        local bc = GetBarCount()
        local ic = GetIconCount()
        EnsureSlotKeys(bc, ic)
        local updateBar  = ns.SpecialBars.UpdateBarSlot
        local updateIcon = ns.SpecialBars.UpdateIconSlot
        if updateBar  then for i = 1, bc do updateBar(_barKeys[i])   end end
        if updateIcon then for i = 1, ic do updateIcon(_iconKeys[i]) end end
    end

    if not (changed or force) then return end

    for _, state in pairs(specialBarState) do
        local child   = state.childFrame
        local wrapper = state.wrapper
        if child and wrapper and child:IsShown() then
            if child:GetParent() ~= wrapper then
                UIParent.SetParent(child, wrapper)
                UIParent.ClearAllPoints(child)
                UIParent.SetPoint(child, "CENTER", wrapper, "CENTER", 0, 0)
            end
            if state.w and state.h then
                local cw, ch = child:GetSize()
                if cw ~= state.w or ch ~= state.h then
                    UIParent.SetSize(child, state.w, state.h)
                end
            end
        end
    end

    for _, state in pairs(iconGroupState) do
        local child   = state.childFrame
        local wrapper = state.wrapper
        if child and wrapper and child:IsShown() then

            local p, rel = child:GetPoint()
            if rel ~= wrapper then
                UIParent.SetFrameStrata(child, wrapper:GetFrameStrata())
                UIParent.SetFrameLevel(child, wrapper:GetFrameLevel() + 1)
                UIParent.ClearAllPoints(child)
                UIParent.SetPoint(child, "CENTER", wrapper, "CENTER", 0, 0)
            end
        end
    end
end

local auraKickScheduled = false
OnSpecialChildAura = function()
    if auraKickScheduled then return end
    auraKickScheduled = true
    C_Timer.After(0, function()
        auraKickScheduled = false
        RunEnforce(true)
    end)
end

enforcer:SetScript("OnUpdate", function(_, elapsed)
    enforceTimer = enforceTimer + elapsed
    if enforceTimer < ENFORCE_INTERVAL then return end
    enforceTimer = 0
    local wasDirty = enforceDirty
    enforceDirty = false
    RunEnforce(wasDirty)
end)

local enforceTriggers = CreateFrame("Frame")
enforceTriggers:RegisterUnitEvent("UNIT_AURA", "player")
enforceTriggers:RegisterEvent("PLAYER_REGEN_ENABLED")
enforceTriggers:RegisterEvent("PLAYER_REGEN_DISABLED")
enforceTriggers:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
enforceTriggers:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
enforceTriggers:SetScript("OnEvent", MarkEnforceDirty)

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
    lastBarShownSig  = -1
    lastIconShownSig = -1
    ResetRetryBudget()
    TUI:QueueSpecialBarsUpdate()
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
        MarkEnforceDirty()
        OnSpecChanged()
    end)
end

local function ResolveAnchorTarget(anchorName)
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
    local proxy = ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(anchorName)
    if proxy then return proxy end
    local target = _G[anchorName]
    if anchorName == "ElvUF_Player_CastBar" and target and target.Holder then
        return target.Holder
    end
    return target
end

local function RemoveBarSlot(index)
    local s = GetSpecRoot()
    local count = s.barCount or 3
    if not index or index < 1 or index > count then return end
    local release = ns.SpecialBars.ReleaseBar
    if release then for i = 1, count do release("bar" .. i) end end
    s.bars = s.bars or {}
    for i = index, count - 1 do s.bars["bar" .. i] = s.bars["bar" .. (i + 1)] end
    s.bars["bar" .. count] = nil
    s.barCount = math.max(1, count - 1)
end
local function RemoveIconSlot(index)
    local s = GetSpecRoot()
    local count = s.iconCount or 3
    if not index or index < 1 or index > count then return end
    local release = ns.SpecialBars.ReleaseIcon
    if release then for i = 1, count do release("icon" .. i) end end
    s.icons = s.icons or {}
    for i = index, count - 1 do s.icons["icon" .. i] = s.icons["icon" .. (i + 1)] end
    s.icons["icon" .. count] = nil
    s.iconCount = math.max(1, count - 1)
end

SB.RemoveBarSlot           = RemoveBarSlot
SB.RemoveIconSlot          = RemoveIconSlot
SB.ResolveAnchorTarget     = ResolveAnchorTarget
SB.ScanAndHookCDMChildren  = ScanAndHookCDMChildren
SB.ReturnFrame             = ReturnFrame
SB.SafeMatch               = SafeMatch
SB.CleanString             = CleanString
SB.specialBarState         = specialBarState
SB.iconGroupState          = iconGroupState
SB.knownBarSpells          = knownBarSpells
SB.knownIconSpells         = knownIconSpells
SB.yoinkedBars             = yoinkedBars
SB.RebuildClaimedBarFrames  = RebuildClaimedBarFrames
SB.RebuildClaimedIconFrames = RebuildClaimedIconFrames
SB.GetChildrenReuseFind     = GetChildrenReuseFind

function SB.GetIconWrapper(iconKey)
    local st = iconKey and iconGroupState[iconKey]
    return st and st.wrapper or nil
end

function SB.SyncGroupedIconSizes(groupID, w, h)
    if not groupID then return end
    local ic = GetIconCount()
    EnsureSlotKeys(0, ic)
    for i = 1, ic do
        local key = _iconKeys[i]
        local db = GetIconDB(key)
        if db.enabled and db.spellID and db.customGroup == groupID then
            local st = iconGroupState[key]
            if st then
                if st.wrapper then ns.Pixel.SetSize(st.wrapper, w, h) end
                local child = st.childFrame
                if child then
                    child._tuiSpecialW, child._tuiSpecialH = w, h
                    UIParent.SetSize(child, w, h)
                end
                st.w, st.h = w, h
            end
        end
    end
end

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