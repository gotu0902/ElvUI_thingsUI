local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local Pixel = ns.Pixel

ns.CDMIcons = ns.CDMIcons or {}
ns.CDM_SPACING_INSET = ns.CDM_SPACING_INSET or 2
local M = ns.CDMIcons

local H = ns.CDHelpers
local IsSecret      = H.IsSecret
local NotSecret     = H.NotSecret
local GetDesatCurve = H.GetDesatCurve
local SetDesat      = H.SetDesat

local VIEWERS = {
    EssentialCooldownViewer = "essential",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffIcon",
}

local VIEWER_BY_KEY = {
    essential = "EssentialCooldownViewer",
    utility   = "UtilityCooldownViewer",
    buffIcon  = "BuffIconCooldownViewer",
}

local overflowOut = {}

local hookedViewers = {}
local hookedChildren = {}
local applyingChild  = {}
local pendingViewers = {}
local passiveHidden  = {}
local passiveDirty   = false
local pendingFrame   = CreateFrame("Frame")
local QueueLayout
local LayoutViewer

local proxies = {}
local function GetProxy(viewer)
    if not viewer then return nil end
    local name = viewer:GetName()
    local p = proxies[name]
    if not p then
        p = CreateFrame("Frame", "TUI_CDMProxy_" .. name, _G.UIParent)
        p:SetSize(1, 1)
        p:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
        proxies[name] = p
    end
    return p
end
M.GetProxy = GetProxy

function M.ProxyForName(name)
    if name and VIEWERS[name] then
        local v = _G[name]
        if v then return GetProxy(v) end
    end
    return nil
end

local GROWTH = {
    CENTERED_H = { axis = "H", pin = "CENTER", stepX =  1, stepY = -1 },
    CENTERED_V = { axis = "V", pin = "CENTER", stepX =  1, stepY = -1 },
    RIGHT      = { axis = "H", pin = "LEFT",   stepX =  1, stepY = -1 },
    LEFT       = { axis = "H", pin = "RIGHT",  stepX = -1, stepY = -1 },
    DOWN       = { axis = "V", pin = "TOP",    stepX =  1, stepY = -1 },
    UP         = { axis = "V", pin = "BOTTOM", stepX =  1, stepY =  1 },
}

local function GetViewerDB(viewerName)
    local key = VIEWERS[viewerName]
    if not key then return nil end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    return cdm and cdm[key]
end

local function GetIconSize(vdb)
    if not vdb or not vdb.overrideSize then return nil, nil end
    local w = vdb.iconWidth or 36
    local h = vdb.lockAspect and w or (vdb.iconHeight or w)
    return w, h
end

local function CollectAndHook(viewer, out, hookFn)
    for i = #out, 1, -1 do out[i] = nil end
    local n = viewer:GetNumChildren()
    if n == 0 then return out end
    local kids = { viewer:GetChildren() }
    for i = 1, n do
        local c = kids[i]
        if c and c.GetCooldownID then
            if hookFn then hookFn(c, viewer) end

            if c:IsShown() and not (ns.yoinkedBars and ns.yoinkedBars[c]) and not passiveHidden[c] then
                out[#out + 1] = c
            end
        end
    end
    return out
end

local passiveMouse = {}
local pendingMouse = {}

local function SetChildMouse(child, on)
    if InCombatLockdown() then
        pendingMouse[child] = on
    else
        pendingMouse[child] = nil
        child:EnableMouse(on)
    end
end

local function ApplyPassiveState(child, hide)
    if hide then
        if not passiveHidden[child] then
            passiveHidden[child] = true
            passiveMouse[child] = child:IsMouseEnabled() and true or false
            child:SetAlpha(0)
            SetChildMouse(child, false)
        end
    elseif passiveHidden[child] then
        passiveHidden[child] = nil
        child:SetAlpha(1)
        SetChildMouse(child, passiveMouse[child] ~= false)
        passiveMouse[child] = nil
    end
end

local function PlainID(v)
    if IsSecret(v) then return nil end
    return v
end

local function RebuildPassiveCache()
    local inCombat = InCombatLockdown()
    passiveDirty = inCombat
    if not inCombat then
        for c, want in pairs(pendingMouse) do
            pendingMouse[c] = nil
            if c.EnableMouse then c:EnableMouse(want) end
        end
    end
    local changed = false
    for name in pairs(VIEWERS) do
        local viewer = _G[name]
        local vdb = GetViewerDB(name)
        if viewer and vdb then
            local wantHide = vdb.hidePassive and C_Spell and C_Spell.IsSpellPassive
            local kids = { viewer:GetChildren() }
            for i = 1, #kids do
                local c = kids[i]
                if c and c.GetCooldownID
                    and not (ns.yoinkedBars and ns.yoinkedBars[c])
                    and not c._tuiSpecialBarKey and not c._tuiSpecialIconKey then
                    local info = c.cooldownInfo
                    local base = info and PlainID(info.spellID) or nil
                    local sid = info and (PlainID(info.overrideTooltipSpellID)
                        or PlainID(info.overrideSpellID) or base) or nil
                    if base and C_Spell.GetOverrideSpell then
                        local live = PlainID(C_Spell.GetOverrideSpell(base))
                        if live and live ~= 0 and live ~= base then sid = live end
                    end
                    local hide
                    if not wantHide then
                        hide = false
                    elseif sid then
                        local p = C_Spell.IsSpellPassive(sid)
                        if NotSecret(p) then
                            hide = p == true
                        elseif not inCombat then
                            hide = false
                        end
                    end
                    if sid and not hide and ns.RacialsCDM and ns.RacialsCDM.ShouldHideNativeSpell
                        and ns.RacialsCDM.ShouldHideNativeSpell(sid) then
                        hide = true
                    end
                    if hide ~= nil then
                        if (passiveHidden[c] and true or false) ~= hide then changed = true end
                        ApplyPassiveState(c, hide)
                    end
                end
            end
        end
    end
    if changed then
        M.Invalidate()
        for name in pairs(VIEWERS) do QueueLayout(_G[name]) end
    end
end

local passiveQueued = false
local function QueuePassiveRebuild()
    if passiveQueued then return end
    passiveQueued = true
    C_Timer.After(0.1, function()
        passiveQueued = false
        RebuildPassiveCache()
    end)
end

function M.IsPassiveHidden(child) return passiveHidden[child] == true end

local function SortByCooldownID(children)
    table.sort(children, function(a, b)
        local ai = a.layoutIndex or math.huge
        local bi = b.layoutIndex or math.huge
        return ai < bi
    end)
end

local cdmRebuilding = false
local lastSpec

local function ReapplyChildAnchor(child)
    if cdmRebuilding then return end
    if applyingChild[child] then return end

    if ns.yoinkedBars and ns.yoinkedBars[child] then return end
    local a = child._tuiAnchor
    if not a or not a.relative then
        local viewer = child._tuiViewer
        if viewer then viewer._tuiLayoutSig = nil; LayoutViewer(viewer) end
        return
    end
    applyingChild[child] = true
    child:ClearAllPoints()
    child:SetPoint(a.point, a.relative, a.relativePoint, a.x, a.y)
    applyingChild[child] = nil
end

local function OnChildAuraChanged(child)
    local viewer = child._tuiViewer
    if viewer then QueueLayout(viewer) end
end

local OVERLAY_ATLAS   = "UI-HUD-CoolDownManager-IconOverlay"
local OVERLAY_TEX_ID  = 6707800
local applyingOverlay = {}

local function OverlayEligible(child)
    if not child then return false end
    if ns.yoinkedBars and ns.yoinkedBars[child] then return false end
    local v = child._tuiViewer
    local vn = v and v.GetName and v:GetName()
    if vn ~= "EssentialCooldownViewer" and vn ~= "UtilityCooldownViewer" then return false end
    if not child.cooldownInfo then return false end
    return true
end

local SWIPE_TEX = "Interface\\Buttons\\WHITE8X8"

local function SetCDFromDur(cd, durObj)
    if not (cd and cd.SetCooldownFromDurationObject and durObj) then return false end
    if pcall(cd.SetCooldownFromDurationObject, cd, durObj, false) then return true end
    return pcall(cd.SetCooldownFromDurationObject, cd, durObj)
end

local function StripOverlayTextures(frame)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") then
            local a = r.GetAtlas and r:GetAtlas()
            local t = r.GetTexture and r:GetTexture()
            if (NotSecret(a) and a == OVERLAY_ATLAS) or (NotSecret(t) and t == OVERLAY_TEX_ID) then
                r:SetAlpha(0); r:Hide()
            end
        end
    end
end

local function ApplyCooldownStyle(cd)
    if cd.SetDrawSwipe          then cd:SetDrawSwipe(true) end
    if cd.SetDrawEdge           then cd:SetDrawEdge(false) end
    if cd.SetDrawBling          then cd:SetDrawBling(true) end
    if cd.SetReverse            then cd:SetReverse(false) end
    if cd.SetSwipeColor         then cd:SetSwipeColor(0, 0, 0, 0.8) end
    if cd.SetSwipeTexture       then cd:SetSwipeTexture(SWIPE_TEX) end
    if cd.SetUseAuraDisplayTime then cd:SetUseAuraDisplayTime(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
end

local function UpdateIconDesat(icon, cdInfo, durObj, hasCharge)
    if not icon then return end
    if cdInfo and NotSecret(cdInfo.isOnGCD) and cdInfo.isOnGCD then SetDesat(icon, 0); return end
    if durObj and not hasCharge and type(durObj.EvaluateRemainingDuration) == "function" then
        local curve = GetDesatCurve()
        if curve then SetDesat(icon, durObj:EvaluateRemainingDuration(curve, 0) or 0)
        else SetDesat(icon, 0) end
        return
    end
    SetDesat(icon, 0)
end

local function ApplyAuraState(child, cd, spellID)
    local cdInfo    = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
    local durObj    = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID)
    local hasCharge = type(child.HasVisualDataSource_Charges) == "function" and not not child:HasVisualDataSource_Charges()
    local chargeDur = hasCharge and C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(spellID)

    UpdateIconDesat(child.Icon, cdInfo, durObj, hasCharge)

    local applied
    if hasCharge and chargeDur then applied = SetCDFromDur(cd, chargeDur)
    elseif not hasCharge and durObj then applied = SetCDFromDur(cd, durObj) end
    if applied then return end

    if cdInfo and NotSecret(cdInfo.isOnGCD) and cdInfo.isOnGCD then
        if cd.Clear then cd:Clear() end
    elseif cdInfo and NotSecret(cdInfo.startTime) and NotSecret(cdInfo.duration) and C_DurationUtil and C_DurationUtil.CreateDuration then
        local fb = C_DurationUtil.CreateDuration()
        if fb and fb.SetTimeFromStart then fb:SetTimeFromStart(cdInfo.startTime, cdInfo.duration); SetCDFromDur(cd, fb) end
    elseif cd.Clear then cd:Clear() end
end

local function EnforceSpellTexture(child)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not (cdm and cdm.hideAuraOverlay) then return end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs:IsShown() then return end
    if not OverlayEligible(child) then return end
    local info = child.cooldownInfo
    local base = info and PlainID(info.spellID) or nil
    if not (type(base) == "number" and base > 0) then return end
    local tex = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(base)
    local icon = child.Icon
    if not (tex and icon and icon.SetTexture) then return end
    local cur = icon:GetTexture()
    if NotSecret(cur) and cur == tex then return end
    icon:SetTexture(tex)
    local tc = child._tuiZoomCoord
    if tc and icon.SetTexCoord then icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
end

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local overrideGlow = {}
local childAuraOn  = {}

local function StopOverrideGlow(child)
    if not overrideGlow[child] then return end
    overrideGlow[child] = nil
    if LCG then LCG.ProcGlow_Stop(child, "tuiOverrideGlow") end
end

local function UpdateOverrideGlow(child)
    if not (LCG and IsSpellOverlayed) then return end
    if not childAuraOn[child] then StopOverrideGlow(child) return end
    local info = child.cooldownInfo
    local base = info and PlainID(info.spellID) or nil
    local live
    if type(base) == "number" and base > 0 and C_Spell.GetOverrideSpell then
        live = PlainID(C_Spell.GetOverrideSpell(base))
        if live == 0 or live == base then live = nil end
    end
    if not live then StopOverrideGlow(child) return end
    local o = IsSpellOverlayed(live)
    if not NotSecret(o) then return end
    if o == true then
        if not overrideGlow[child] then
            overrideGlow[child] = true
            LCG.ProcGlow_Start(child, { key = "tuiOverrideGlow" })
        end
    else
        StopOverrideGlow(child)
    end
end

local function ProcessCooldownFrame(child)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not (cdm and cdm.hideAuraOverlay) then return end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs:IsShown() then return end
    if not OverlayEligible(child) then return end
    EnforceSpellTexture(child)
    UpdateOverrideGlow(child)
    local cd = child.Cooldown
    if not cd or applyingOverlay[cd] then return end

    applyingOverlay[cd] = true
    StripOverlayTextures(child)
    ApplyCooldownStyle(cd)
    local info = child.cooldownInfo
    local spellID = info and (PlainID(info.overrideSpellID) or PlainID(info.spellID)) or nil
    if spellID and type(spellID) == "number" and spellID > 0 and C_Spell then
        ApplyAuraState(child, cd, spellID)
    else
        if cd.Clear then cd:Clear() end
        SetDesat(child.Icon, 0)
    end
    applyingOverlay[cd] = nil
end

local function HideAuraOverlay(child)
    ProcessCooldownFrame(child)
end

local function EnsureOverlayHooks(child)
    local cd = child and child.Cooldown
    if not cd or cd._tuiOverlayHooked then return end
    if not OverlayEligible(child) then return end
    cd._tuiOverlayHooked = true
    if not child._tuiTexHooked and type(child.RefreshSpellTexture) == "function" then
        child._tuiTexHooked = true
        hooksecurefunc(child, "RefreshSpellTexture", EnforceSpellTexture)
    end
    local function reapply() ProcessCooldownFrame(child) end
    hooksecurefunc(cd, "SetCooldown", reapply)
    if cd.SetCooldownFromDurationObject then hooksecurefunc(cd, "SetCooldownFromDurationObject", reapply) end
    if cd.SetSwipeColor then hooksecurefunc(cd, "SetSwipeColor", reapply) end
    local icon = child.Icon
    if icon and not icon._tuiOverlayHooked then
        icon._tuiOverlayHooked = true
        if icon.SetDesaturated  then hooksecurefunc(icon, "SetDesaturated",  reapply) end
        if icon.SetDesaturation then hooksecurefunc(icon, "SetDesaturation", reapply) end
    end
end

local function HookChild(child, viewer)
    if hookedChildren[child] then return end
    hookedChildren[child] = true
    child._tuiViewer = viewer

    hooksecurefunc(child, "SetPoint",        ReapplyChildAnchor)
    hooksecurefunc(child, "ClearAllPoints", ReapplyChildAnchor)
    hooksecurefunc(child, "Hide", OnChildAuraChanged)
    hooksecurefunc(child, "SetShown", OnChildAuraChanged)

    if type(child.OnAuraInstanceInfoSet) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoSet", function(self)
            childAuraOn[self] = true
            OnChildAuraChanged(self)
        end)
    end
    if type(child.OnAuraInstanceInfoCleared) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoCleared", function(self)
            childAuraOn[self] = nil
            StopOverrideGlow(self)
            OnChildAuraChanged(self)
        end)
    end

    local db = child.DebuffBorder
    if db and not db._tuiAuraHooked and type(db.UpdateFromAuraData) == "function" then
        db._tuiAuraHooked = true
        hooksecurefunc(db, "UpdateFromAuraData", function(self)
            local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
            if cdm and cdm.hideAuraBorder then self:SetAlpha(0) end
        end)
    end

    EnsureOverlayHooks(child)
end

local hookedViewerAnchors = {}
local applyingViewerAnchor = {}

local function ResolveViewerAnchorTarget(viewerName, vdb)
    local targetFrameName = vdb.anchorFrame
    if viewerName == "BuffIconCooldownViewer" and targetFrameName == "BARSETUP_TOP" then
        local bs = ns.BarSetup
        if bs and bs.GetTopmostBarFrame then
            local top = bs.GetTopmostBarFrame()
            if top then return top end
        end

        local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
        return setup and _G[setup.anchorFrame or ""] or nil
    end
    local target = _G[targetFrameName or ""]

    if targetFrameName == "ElvUF_Player_CastBar" and target and target.Holder then
        return target.Holder
    end
    return target
end

local function AnchorRequired(viewerName, vdb)
    if not vdb then return false end
    if viewerName == "BuffIconCooldownViewer" then return true end
    return vdb.anchorEnabled == true
end

local function ReapplyViewerAnchor(viewer)
    local proxy = GetProxy(viewer)
    if applyingViewerAnchor[proxy] then return end
    local viewerName = viewer:GetName()
    local vdb = GetViewerDB(viewerName)

    if not AnchorRequired(viewerName, vdb) then return end

    local target = ResolveViewerAnchorTarget(viewerName, vdb)
    if not target then return end
    local tname = target.GetName and target:GetName()
    if tname and VIEWERS[tname] then target = GetProxy(target) end

    applyingViewerAnchor[proxy] = true
    proxy:ClearAllPoints()
    proxy:SetPoint(
        vdb.anchorPoint or "CENTER",
        target,
        vdb.anchorRelativePoint or "CENTER",
        vdb.anchorXOffset or 0,
        vdb.anchorYOffset or 0
    )
    applyingViewerAnchor[proxy] = nil
end

local function HookViewerAnchor(viewer)
    if hookedViewerAnchors[viewer] then return end
    hookedViewerAnchors[viewer] = true

    hooksecurefunc(viewer, "SetPoint", function(self)
        if applyingViewerAnchor[self] then return end
        local name = self:GetName()

        if not AnchorRequired(name, GetViewerDB(name)) then return end
        QueueLayout(self)
    end)
    hooksecurefunc(viewer, "ClearAllPoints", function(self)
        if applyingViewerAnchor[self] then return end
        local name = self:GetName()
        if not AnchorRequired(name, GetViewerDB(name)) then return end
        QueueLayout(self)
    end)
end


local function ComputeLayoutSig(visible, vdb)
    local sig = #visible
    for i = 1, #visible do
        local c = visible[i]
        local id = c.cooldownID or 0
        if type(id) ~= "number" then id = 0 end
        sig = sig + id * i + (c.layoutIndex or 0) * 17
    end
    sig = sig
        + (vdb.iconWidth or 36) * 1000003
        + (vdb.iconHeight or 36) * 503
        + math.floor((vdb.spacing or 0) * 100) * 31
        + (vdb.iconsPerRow or 20) * 41
        + (vdb.maxIcons or 0) * 4099
        + ((vdb.overflowPlacement == "START") and 8191 or 0)
        + math.floor((vdb.iconZoom or 0) * 1000) * 7
        + (vdb.iconLockAspectRatio ~= false and 1 or 0) * 13
        + (vdb.lockAspect and 1 or 0) * 113
        + (vdb.overrideSize and 1 or 0) * 211
        + (vdb.elbowEnabled and 1 or 0) * 65521
        + (vdb.elbowAfter or 0) * 1543
        + (vdb.invertSwipe and 1 or 0) * 379
    local g = vdb.growthDirection
    if g then for i = 1, #g do sig = sig + g:byte(i) * i end end
    local eb = vdb.elbowDirection
    if eb then for i = 1, #eb do sig = sig + eb:byte(i) * i * 3 end end
    if vdb.wrapDirection == "UP" or vdb.wrapDirection == "LEFT" then sig = sig + 307 end
    return sig
end

local ELBOW_STEP = {
    UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
}

local function ElbowCell(i, elbowAt, growth, step)
    if i <= elbowAt then
        if growth.axis == "V" then return 0, (i - 1) * growth.stepY end
        return (i - 1) * growth.stepX, 0
    end
    local j = i - elbowAt
    if growth.axis == "V" then
        return j * step[1], (elbowAt - 1) * growth.stepY
    end
    return (elbowAt - 1) * growth.stepX, j * step[2]
end

local function EnsureFlowTail(proxy, viewerName)
    if not proxy._tuiFlowTail then
        proxy._tuiFlowTail = CreateFrame("Frame", "TUI_CDMFlowTail_" .. viewerName, proxy)
    end
    return proxy._tuiFlowTail
end

function M.FlowTailForName(name)
    if name and VIEWERS[name] then
        local v = _G[name]
        if v then return EnsureFlowTail(GetProxy(v), name) end
    end
    return nil
end

local function _cornerXY(point, w, h)
    local dx = point:find("RIGHT") and w or (point:find("LEFT") and 0 or w * 0.5)
    local dy = point:find("BOTTOM") and -h or (point:find("TOP") and 0 or -h * 0.5)
    return dx, dy
end

local function ProxyOwnedByThingsUI(viewer, vdb)
    if viewer:GetName() == "EssentialCooldownViewer" then
        local edb = E.db.thingsUI and E.db.thingsUI.essentialMover
        return (edb and edb.enabled) and true or false
    end
    return AnchorRequired(viewer:GetName(), vdb)
end

local function MirrorProxyToViewer(proxy, viewer)
    local fl, fb = viewer:GetLeft(), viewer:GetBottom()
    if not fl or not fb then return end
    proxy:ClearAllPoints()
    proxy:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", fl, fb)
end

local barRestackPending
local function NotifyClusterWidthChanged()
    if barRestackPending then return end
    barRestackPending = true
    C_Timer.After(0, function()
        barRestackPending = nil
        if InCombatLockdown() then return end
        if ns.BarSetup and ns.BarSetup.ResetWidthCache and ns.BarSetup.ApplyStack then
            ns.BarSetup.ResetWidthCache()
            ns.BarSetup.ApplyStack()
        end
    end)
end

LayoutViewer = function(viewer)

    if cdmRebuilding then return end
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return end
    local vdb = GetViewerDB(viewer:GetName())
    if not vdb then return end

    HookViewerAnchor(viewer)
    ReapplyViewerAnchor(viewer)

    viewer._tuiVisible = viewer._tuiVisible or {}
    local visible = CollectAndHook(viewer, viewer._tuiVisible, HookChild)
    local TM = ns.TimersCDM
    if TM and TM.GetInlineButtonsFor then
        local tmb = TM.GetInlineButtonsFor(viewer)
        if tmb then for i = 1, #tmb do visible[#visible + 1] = tmb[i] end end
    end
    local RC = ns.RacialsCDM
    if RC and RC.GetInlineButtonsFor then
        local rcb = RC.GetInlineButtonsFor(viewer)
        if rcb then for i = 1, #rcb do visible[#visible + 1] = rcb[i] end end
    end

    SortByCooldownID(visible)

    local myName = viewer:GetName()
    local cap = tonumber(vdb.maxIcons) or 0
    local targetKey = vdb.overflowTarget
    local targetName = targetKey and targetKey ~= "" and VIEWER_BY_KEY[targetKey] or nil
    if targetName == myName then targetName = nil end

    local moved
    if cap > 0 and targetName and #visible > cap then
        moved = {}
        for i = cap + 1, #visible do moved[#moved + 1] = visible[i] end
        for i = #visible, cap + 1, -1 do visible[i] = nil end
        moved._from = myName
        moved._placement = vdb.overflowPlacement
    end

    local prev, prevName
    for name, list in pairs(overflowOut) do
        if list._from == myName then prev, prevName = list, name end
    end

    local changed = false
    if prevName ~= targetName or (prev == nil) ~= (moved == nil) then
        changed = true
    elseif prev and moved then
        if #prev ~= #moved then
            changed = true
        else
            for i = 1, #moved do
                if prev[i] ~= moved[i] then changed = true break end
            end
        end
    end

    if changed then
        if prevName then overflowOut[prevName] = nil end
        local dirty = _G[prevName or ""]
        if dirty then dirty._tuiLayoutSig = nil; QueueLayout(dirty) end
    end
    if moved then
        overflowOut[targetName] = moved
        if changed then
            local tv = _G[targetName]
            if tv then tv._tuiLayoutSig = nil; QueueLayout(tv) end
        end
    end

    local incoming = overflowOut[myName]
    if incoming then
        if incoming._placement == "START" then
            for i = #incoming, 1, -1 do table.insert(visible, 1, incoming[i]) end
        else
            for i = 1, #incoming do visible[#visible + 1] = incoming[i] end
        end
    end

    if #visible == 0 then
        local proxy = GetProxy(viewer)
        local tail = EnsureFlowTail(proxy, viewer:GetName())
        local sizeW, sizeH = GetIconSize(vdb)
        local w = sizeW or proxy._tuiLastIconW or 36
        local h = sizeH or proxy._tuiLastIconH or 36
        local pin = vdb.anchorPoint or "CENTER"
        Pixel.SetSize(proxy, w, h)
        if viewer == _G.EssentialCooldownViewer then NotifyClusterWidthChanged() end
        local dx, dy = _cornerXY(pin, w, h)
        tail:SetSize(w, h)
        tail:ClearAllPoints()
        tail:SetPoint("CENTER", proxy, pin, w / 2 - dx, -h / 2 - dy)
        if proxy._tuiLastIconW ~= w or proxy._tuiLastIconH ~= h then
            proxy._tuiLastIconW, proxy._tuiLastIconH = w, h
            local T = ns.TUI
            if T and T.UpdateCustomGroups then T:UpdateCustomGroups() end
        end
        viewer._tuiLayoutSig = nil
        return
    end

    local sig = ComputeLayoutSig(visible, vdb)
    if viewer._tuiLayoutSig == sig then
        local proxy = GetProxy(viewer)
        local vscale = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
        if math.abs((proxy:GetScale() or 1) - vscale) > 0.001 then proxy:SetScale(vscale) end
        if not ProxyOwnedByThingsUI(viewer, vdb) then
            MirrorProxyToViewer(proxy, viewer)
        end
        return
    end
    viewer._tuiLayoutSig = sig

    local cdmRoot = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if cdmRoot and cdmRoot.hideAuraBorder then
        for i = 1, #visible do
            local b = visible[i].DebuffBorder
            if b then b:SetAlpha(0) end
        end
    end
    if cdmRoot and cdmRoot.hideAuraOverlay then
        for i = 1, #visible do EnsureOverlayHooks(visible[i]); HideAuraOverlay(visible[i]) end
    end

    local sizeW, sizeH = GetIconSize(vdb)
    if sizeW and sizeH then
        for i = 1, #visible do
            local c = visible[i]
            local cw, ch = c:GetSize()
            if math.abs((cw or 0) - sizeW) > 0.5 or math.abs((ch or 0) - sizeH) > 0.5 then
                Pixel.SetSize(c, sizeW, sizeH)
            end
        end
    end

    -- pooled frames migrate between viewers, so the reverse flag must be
    -- asserted (or cleared) on every pass, not only where it is wanted
    local wantRev = VIEWERS[viewer:GetName()] == "buffIcon" and vdb.invertSwipe or false
    for i = 1, #visible do
        local cd = visible[i].Cooldown
        if cd and cd.SetReverse then cd:SetReverse(wantRev) end
    end

    local zoom = tonumber(vdb.iconZoom) or 0
    local lockTex = vdb.iconLockAspectRatio ~= false
    if zoom > 0 or lockTex then
        local frameW = sizeW or (visible[1] and visible[1]:GetWidth() or 0)
        local frameH = sizeH or (visible[1] and visible[1]:GetHeight() or 0)

        local left, right, top, bottom
        if lockTex and frameW > 0 and frameH > 0 then
            local base = 1 - zoom * 2
            local xCrop, yCrop = base, base
            local ratio = frameW / frameH
            if ratio > 1 then yCrop = xCrop / ratio
            elseif ratio < 1 then xCrop = yCrop * ratio end
            left = (1 - xCrop) / 2; right = 1 - left
            top  = (1 - yCrop) / 2; bottom = 1 - top
        else
            left, right, top, bottom = zoom, 1 - zoom, zoom, 1 - zoom
        end
        for i = 1, #visible do
            local c = visible[i]
            local tex = c.Icon
            if tex and tex.SetTexCoord then
                tex:SetTexCoord(left, right, top, bottom)
                local tc = c._tuiZoomCoord
                if not tc then tc = {}; c._tuiZoomCoord = tc end
                tc[1], tc[2], tc[3], tc[4] = left, right, top, bottom
            end
        end
    end

    local iconW = (sizeW) or visible[1]:GetWidth() or 36
    local iconH = (sizeH) or visible[1]:GetHeight() or 36
    local spacing  = (vdb.spacing or 0) + (ns.CDM_SPACING_INSET or 2)
    local growth   = GROWTH[vdb.growthDirection] or GROWTH.CENTERED_H
    local perLine  = math.max(1, vdb.iconsPerRow or 20)
    local anchorPin = vdb.anchorPoint or "CENTER"
    local count    = #visible

    local elbowStep
    if vdb.elbowEnabled then
        local vertical = (growth.axis == "V")
        local step = ELBOW_STEP[vdb.elbowDirection]
        local fits = step and ((vertical and step[1] ~= 0) or (not vertical and step[2] ~= 0))
        elbowStep = fits and step or (vertical and ELBOW_STEP.LEFT or ELBOW_STEP.DOWN)
    end
    local elbowAt = elbowStep and math.max(1, vdb.elbowAfter or 10) or nil
    if elbowAt and count <= elbowAt then elbowStep, elbowAt = nil, nil end

    local cols, rows
    if elbowStep then
        if growth.axis == "V" then cols, rows = 1, math.min(elbowAt, count)
        else                       cols, rows = math.min(elbowAt, count), 1 end
    elseif growth.axis == "V" then
        rows = math.min(perLine, count)
        cols = math.ceil(count / perLine)
    else
        cols = math.min(perLine, count)
        rows = math.ceil(count / perLine)
    end

    local stepX  = (iconW + spacing) * growth.stepX
    local stepY  = (iconH + spacing) * growth.stepY
    local totalW = cols * iconW + math.max(0, cols - 1) * spacing
    local totalH = rows * iconH + math.max(0, rows - 1) * spacing

    local startX, startY
    if growth.pin == "CENTER" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY =  ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "LEFT" then
        startX = iconW / 2
        startY = ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "RIGHT" then
        startX = -iconW / 2
        startY = ((rows - 1) * (iconH + spacing)) / 2
    elseif growth.pin == "TOP" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY = -iconH / 2
    elseif growth.pin == "BOTTOM" then
        startX = -((cols - 1) * (iconW + spacing)) / 2
        startY = iconH / 2
    end

    local proxy = GetProxy(viewer)
    local cellW = iconW + spacing
    local cellH = iconH + spacing
    local centered = (growth.pin == "CENTER")
    local wrapDir = vdb.wrapDirection
    local wrapFlip = (growth.axis == "H" and wrapDir == "UP")
        or (growth.axis == "V" and wrapDir == "LEFT")
    for i = 1, count do
        local child = visible[i]
        local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
        local ax, ay

        if elbowStep then
            local cx, cy = ElbowCell(i, elbowAt, growth, elbowStep)
            ax = iconW / 2 + cx * cellW - ancX
            ay = -iconH / 2 + cy * cellH - ancY
        else
        local col, row, lineLen
        if growth.axis == "V" then
            col = math.floor((i - 1) / perLine)
            row = (i - 1) % perLine
            lineLen = math.min(perLine, count - col * perLine)
        else
            row = math.floor((i - 1) / perLine)
            col = (i - 1) % perLine
            lineLen = math.min(perLine, count - row * perLine)
        end
        if wrapFlip then
            if growth.axis == "V" then col = cols - 1 - col else row = rows - 1 - row end
        end

        local x, y
        if centered and growth.axis == "V" then
            x = startX + col * stepX
            y = ((lineLen - 1) / 2 - row) * cellH
        elseif centered then
            x = (col - (lineLen - 1) / 2) * cellW
            y = startY + row * stepY
        else
            x = startX + col * stepX
            y = startY + row * stepY
        end

        local pinX, pinY = _cornerXY(growth.pin, totalW, totalH)
        ax, ay = pinX + x - ancX, pinY + y - ancY
        end

        child._tuiAnchor = child._tuiAnchor or {}
        child._tuiAnchor.point         = "CENTER"
        child._tuiAnchor.relative      = proxy
        child._tuiAnchor.relativePoint = anchorPin
        child._tuiAnchor.x             = ax
        child._tuiAnchor.y             = ay
        applyingChild[child] = true
        child:ClearAllPoints()
        child:SetPoint("CENTER", proxy, anchorPin, ax, ay)
        applyingChild[child] = nil
    end

    do
        local tail = EnsureFlowTail(proxy, viewer:GetName())
        local ti, total = count + 1, count + 1
        local ax, ay
        if elbowStep then
            local cx, cy = ElbowCell(ti, elbowAt, growth, elbowStep)
            local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
            ax = iconW / 2 + cx * cellW - ancX
            ay = -iconH / 2 + cy * cellH - ancY
        else
            local col, row, lineLen
            if growth.axis == "V" then
                col = math.floor((ti - 1) / perLine)
                row = (ti - 1) % perLine
                lineLen = math.min(perLine, total - col * perLine)
            else
                row = math.floor((ti - 1) / perLine)
                col = (ti - 1) % perLine
                lineLen = math.min(perLine, total - row * perLine)
            end
            local x, y
            if centered and growth.axis == "V" then
                x = startX + col * stepX
                y = ((lineLen - 1) / 2 - row) * cellH
            elseif centered then
                x = (col - (lineLen - 1) / 2) * cellW
                y = startY + row * stepY
            else
                x = startX + col * stepX
                y = startY + row * stepY
            end
            local pinX, pinY = _cornerXY(growth.pin, totalW, totalH)
            local ancX, ancY = _cornerXY(anchorPin, totalW, totalH)
            ax, ay = pinX + x - ancX, pinY + y - ancY
        end
        tail:SetSize(iconW, iconH)
        tail:ClearAllPoints()
        tail:SetPoint("CENTER", proxy, anchorPin, ax, ay)
        tail:Show()
        if proxy._tuiLastIconW ~= iconW or proxy._tuiLastIconH ~= iconH then
            proxy._tuiLastIconW, proxy._tuiLastIconH = iconW, iconH
            local T = ns.TUI
            if T and T.UpdateCustomGroups then T:UpdateCustomGroups() end
        end
    end

    local vscale = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    if math.abs((proxy:GetScale() or 1) - vscale) > 0.001 then proxy:SetScale(vscale) end
    if math.abs((proxy:GetWidth() or 0) - totalW) > 0.5
       or math.abs((proxy:GetHeight() or 0) - totalH) > 0.5 then
        Pixel.SetSize(proxy, totalW, totalH)
        if viewer == _G.EssentialCooldownViewer then NotifyClusterWidthChanged() end
    end

    if not ProxyOwnedByThingsUI(viewer, vdb) then
        MirrorProxyToViewer(proxy, viewer)
    end
end

local function FlushPending(self)
    self:SetScript("OnUpdate", nil)
    for viewer in pairs(pendingViewers) do
        pendingViewers[viewer] = nil
        LayoutViewer(viewer)
    end
end

QueueLayout = function(viewer)
    if not viewer or pendingViewers[viewer] then return end
    pendingViewers[viewer] = true
    pendingFrame:SetScript("OnUpdate", FlushPending)
end

local function HookViewer(name)
    if hookedViewers[name] then return end
    local viewer = _G[name]
    if not viewer or type(viewer.RefreshLayout) ~= "function" then return false end
    hookedViewers[name] = true
    hooksecurefunc(viewer, "RefreshLayout", QueueLayout)

    if type(viewer.OnAcquireItemFrame) == "function" then
        hooksecurefunc(viewer, "OnAcquireItemFrame", function(self, itemFrame)
            HookChild(itemFrame, self)
            itemFrame._tuiViewer = self
            itemFrame._tuiAnchor = nil
            childAuraOn[itemFrame] = nil
            StopOverrideGlow(itemFrame)
            ApplyPassiveState(itemFrame, false)
            passiveMouse[itemFrame] = nil
            self._tuiLayoutSig = nil
            QueueLayout(self)
            QueuePassiveRebuild()
        end)
    end
    QueueLayout(viewer)
    return true
end

local function RelayoutAllForced()
    M.Invalidate()
    for name in pairs(VIEWERS) do QueueLayout(_G[name]) end
end

local function RelayoutAllForcedStaggered()
    RelayoutAllForced()
    C_Timer.After(0.05, RelayoutAllForced)
    C_Timer.After(0.20, RelayoutAllForced)
end

local emmHooked, cvsHooked = false, false
local function HookEditModeExit()
    if not emmHooked then
        local emm = _G.EditModeManagerFrame
        if emm then
            emmHooked = true
            if type(emm.EnterEditMode) == "function" then
                hooksecurefunc(emm, "EnterEditMode", RelayoutAllForcedStaggered)
            end
            hooksecurefunc(emm, "ExitEditMode", RelayoutAllForcedStaggered)
        end
    end
    if not cvsHooked then
        local cvs = _G.CooldownViewerSettings
        if cvs and cvs.HookScript then
            cvsHooked = true
            cvs:HookScript("OnShow", RelayoutAllForcedStaggered)
            cvs:HookScript("OnHide", RelayoutAllForcedStaggered)
        end
    end
end

function M.IsRebuilding() return cdmRebuilding end

function M.Invalidate()
    for name in pairs(VIEWERS) do
        local v = _G[name]
        if v then v._tuiLayoutSig = nil end
    end
end

local utilityMoverCreated = false
local function EnsureUtilityMover()
    if utilityMoverCreated then return end
    local v = _G.UtilityCooldownViewer
    local ms = ns.MoverSync
    if not (v and ms and ms.CreateManaged) then return end
    utilityMoverCreated = true
    ms.CreateManaged(GetProxy(v), "TUI_UtilityMover", "Utility Cooldowns", {
        configString      = "thingsUI,modulesTab,cdm,utilityTab",
        ignoreSizeChanged = true,
        shouldDisable = function()
            local vdb = GetViewerDB("UtilityCooldownViewer")
            return not (vdb and vdb.anchorEnabled)
        end,
        onSave = function(point, relPoint, x, y)
            local vdb = GetViewerDB("UtilityCooldownViewer")
            if not vdb then return end
            vdb.anchorPoint = point
            vdb.anchorRelativePoint = relPoint
            vdb.anchorXOffset = x
            vdb.anchorYOffset = y
            QueueLayout(_G.UtilityCooldownViewer)
            ns.NotifyChange()
        end,
        onNudge = function(dx, dy)
            local vdb = GetViewerDB("UtilityCooldownViewer")
            if not vdb then return end
            vdb.anchorXOffset = (vdb.anchorXOffset or 0) + dx
            vdb.anchorYOffset = (vdb.anchorYOffset or 0) + dy
            QueueLayout(_G.UtilityCooldownViewer)
            ns.NotifyChange()
        end,
    })
end

local HEAL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local function HealViewerVisibility()
    if Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.SpecAgnosticEssential then return end
    if InCombatLockdown() then return end
    for _, name in ipairs(HEAL_VIEWERS) do
        local v = _G[name]
        if v and not v:IsShown() and type(v.UpdateShownState) == "function" then
            v:UpdateShownState()
        end
    end
end

function M.RefreshAllSoft()
    HookEditModeExit()
    EnsureUtilityMover()
    HealViewerVisibility()
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not (cdm and cdm.hideAuraOverlay) then
        for c in pairs(overrideGlow) do StopOverrideGlow(c) end
    end
    for name in pairs(VIEWERS) do
        HookViewer(name)
        QueueLayout(_G[name])
    end
    QueuePassiveRebuild()
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

function M.RefreshAll()
    M.Invalidate()
    M.RefreshAllSoft()
end

function TUI:UpdateCDMIcons()
    M.RefreshAll()
    if ns.EssentialMover and ns.EssentialMover.OnGrowthDirectionChanged then
        ns.EssentialMover.OnGrowthDirectionChanged()
    end
end

function M.MaybeAutoEnableCDM()
    if InCombatLockdown() then return end
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not (cdm and cdm.autoEnableCDM) then return end
    local gdb = _G.thingsUIGlobalDB
    local guid = UnitGUID and UnitGUID("player")
    if not (gdb and guid) then return end

    local skins = E.private and E.private.skins and E.private.skins.blizzard
    if skins and not skins.cooldownManager then
        gdb.cdmSkinEnabled = gdb.cdmSkinEnabled or {}
        if not gdb.cdmSkinEnabled[guid] then
            gdb.cdmSkinEnabled[guid] = true
            skins.cooldownManager = true
            print("|cFF8080FFthingsUI|r enabled the ElvUI Cooldown Manager skin (required). |cFFFFFF00Reload to apply.|r")
            if E.StaticPopup_Show then E:StaticPopup_Show("PRIVATE_RL") end
        end
    end

    if GetCVarBool and GetCVarBool("cooldownViewerEnabled") then return end
    if not (C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable
            and C_CooldownViewer.IsCooldownViewerAvailable()) then return end
    gdb.cdmAutoEnabled = gdb.cdmAutoEnabled or {}
    if gdb.cdmAutoEnabled[guid] then return end
    gdb.cdmAutoEnabled[guid] = true
    pcall(SetCVar, "cooldownViewerEnabled", "1")
    print("|cFF8080FFthingsUI|r enabled the Cooldown Manager (required). Turn off auto-enable in the CDM options.")
    for _, t in ipairs({ 0.5, 1.0, 2.0 }) do C_Timer.After(t, M.RefreshAll) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
if C_EventUtils and C_EventUtils.IsEventValid
    and C_EventUtils.IsEventValid("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED") then
    f:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
end
f:SetScript("OnEvent", function(_, event)
    if event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
        QueuePassiveRebuild()
        return
    end

    M.MaybeAutoEnableCDM()
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local spec = GetSpecialization and GetSpecialization()
        if lastSpec ~= nil and spec ~= lastSpec then
            cdmRebuilding = true
            C_Timer.After(2.5, function() cdmRebuilding = false end)
        end
        lastSpec = spec
        C_Timer.After(0.5, M.RefreshAll)
        for _, t in ipairs({ 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if passiveDirty then QueuePassiveRebuild() end
        M.RefreshAll()
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    else
        M.RefreshAll()
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAllSoft) end
    end
end)

local function DumpVal(v)
    if issecretvalue and issecretvalue(v) then return "secret" end
    return tostring(v)
end

SLASH_TUICDM1 = "/tuicdm"
SlashCmdList.TUICDM = function()
    local emm = _G.EditModeManagerFrame
    local cvs = _G.CooldownViewerSettings
    print(("|cFF8080FFtuicdm|r editmode=%s cvs=%s rebuilding=%s"):format(
        tostring(emm and emm:IsShown()), tostring(cvs and cvs:IsShown()), tostring(M.IsRebuilding())))
    for name in pairs(VIEWERS) do
        local v = _G[name]
        if v then
            local vdb = GetViewerDB(name)
            local proxy = GetProxy(v)
            local kids = { v:GetChildren() }
            local shown, withCID = 0, 0
            for i = 1, #kids do
                local c = kids[i]
                if c:IsShown() then shown = shown + 1 end
                if c.GetCooldownID then withCID = withCID + 1 end
            end
            local buf = {}
            local vis = CollectAndHook(v, buf, HookChild)
            print(("  |cFFFFD27F%s|r shown=%s kids=%d shownKids=%d cid=%d visible=%d"):format(
                name, tostring(v:IsShown()), #kids, shown, withCID, #vis))
            print(("    viewer %dx%d @(%d,%d)  proxy %dx%d @(%s,%s) scale=%.2f"):format(
                math.floor(v:GetWidth() or 0), math.floor(v:GetHeight() or 0),
                math.floor(v:GetLeft() or 0), math.floor(v:GetBottom() or 0),
                math.floor(proxy:GetWidth() or 0), math.floor(proxy:GetHeight() or 0),
                tostring(proxy:GetLeft() and math.floor(proxy:GetLeft())),
                tostring(proxy:GetBottom() and math.floor(proxy:GetBottom())),
                proxy:GetScale() or 1))
            print(("    vdb grow=%s perRow=%s icon=%sx%s sig=%s"):format(
                tostring(vdb and vdb.growthDirection), tostring(vdb and vdb.iconsPerRow),
                tostring(vdb and vdb.iconWidth), tostring(vdb and vdb.iconHeight),
                tostring(v._tuiLayoutSig)))
            local c1 = vis[1]
            if c1 then
                local pt, rel, rp, x, y = c1:GetPoint()
                print(("    child1 cid=%s %dx%d pt=%s rel=%s(%s) x=%s y=%s"):format(
                    DumpVal(c1.cooldownID), math.floor(c1:GetWidth() or 0), math.floor(c1:GetHeight() or 0),
                    tostring(pt), tostring(rel and rel.GetName and rel:GetName() or rel), tostring(rp),
                    DumpVal(x), DumpVal(y)))
            end
        end
    end
end
