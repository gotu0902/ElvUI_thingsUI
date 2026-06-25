local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local Pixel = ns.Pixel

ns.CDMIcons = ns.CDMIcons or {}
local M = ns.CDMIcons

local H = ns.CDHelpers
local NotSecret     = H.NotSecret
local GetDesatCurve = H.GetDesatCurve
local SetDesat      = H.SetDesat

local VIEWERS = {
    EssentialCooldownViewer = "essential",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffIcon",
}

local hookedViewers = {}
local hookedChildren = {}
local applyingChild  = {}
local pendingViewers = {}
local pendingFrame   = CreateFrame("Frame")
local QueueLayout

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

            if c:IsShown() and not (ns.yoinkedBars and ns.yoinkedBars[c]) then
                out[#out + 1] = c
            end
        end
    end
    return out
end

local function SortByCooldownID(children)
    table.sort(children, function(a, b)
        local ai = a.layoutIndex or math.huge
        local bi = b.layoutIndex or math.huge
        return ai < bi
    end)
end

local cdmRebuilding = false

local function ReapplyChildAnchor(child)
    if cdmRebuilding then return end
    if applyingChild[child] then return end

    if ns.yoinkedBars and ns.yoinkedBars[child] then return end
    local a = child._tuiAnchor
    if not a or not a.relative then

        local viewer = child._tuiViewer
        if viewer then viewer._tuiLayoutSig = nil; QueueLayout(viewer) end
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
    if cdInfo and cdInfo.isOnGCD then SetDesat(icon, 0); return end
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

    if cdInfo and cdInfo.isOnGCD then
        if cd.Clear then cd:Clear() end
    elseif cdInfo and cdInfo.startTime and cdInfo.duration and C_DurationUtil and C_DurationUtil.CreateDuration then
        local fb = C_DurationUtil.CreateDuration()
        if fb and fb.SetTimeFromStart then fb:SetTimeFromStart(cdInfo.startTime, cdInfo.duration); SetCDFromDur(cd, fb) end
    elseif cd.Clear then cd:Clear() end
end

local function ProcessCooldownFrame(child)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    if not (cdm and cdm.hideAuraOverlay) then return end
    if not OverlayEligible(child) then return end
    local cd = child.Cooldown
    if not cd or applyingOverlay[cd] then return end

    applyingOverlay[cd] = true
    StripOverlayTextures(child)
    ApplyCooldownStyle(cd)
    local info = child.cooldownInfo
    local spellID = info and (info.overrideSpellID or info.spellID)
    if spellID and NotSecret(spellID) and type(spellID) == "number" and spellID > 0 and C_Spell then
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

    if type(child.OnAuraInstanceInfoSet) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoSet", OnChildAuraChanged)
    end
    if type(child.OnAuraInstanceInfoCleared) == "function" then
        hooksecurefunc(child, "OnAuraInstanceInfoCleared", OnChildAuraChanged)
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

local function TrinketAnchorShift(viewer, vdb)
    local TR = ns.TrinketsCDM
    if not (TR and TR.GetTrinketExtent) then return 0 end
    local ext, side = TR.GetTrinketExtent()
    ext = ext or 0
    if ext <= 0 then return 0 end
    local attachKey = (TR.GetTrinketAttachKey and TR.GetTrinketAttachKey()) or "essential"
    local centre = (side == "LEFT") and (ext / 2) or -(ext / 2)
    local viewerKey = VIEWERS[viewer:GetName()]
    local shift = 0
    if attachKey == "utility" and viewerKey == "utility" then
        shift = shift + centre
    end
    if vdb.anchorFrame == "EssentialCooldownViewer" and attachKey == "essential" then
        shift = shift - centre
    end
    return shift
end


local function TrinketAnchorShiftY(viewer, vdb)
    local TR = ns.TrinketsCDM
    if not (TR and TR.GetTrinketExtentY) then return 0 end
    local ext, side = TR.GetTrinketExtentY()
    ext = ext or 0
    if ext <= 0 then return 0 end
    local attachKey = (TR.GetTrinketAttachKey and TR.GetTrinketAttachKey()) or "essential"
    local centre = (side == "TOP") and -(ext / 2) or (ext / 2)
    local viewerKey = VIEWERS[viewer:GetName()]
    local shift = 0
    if attachKey == "utility" and viewerKey == "utility" then
        shift = shift + centre
    end
    if vdb.anchorFrame == "EssentialCooldownViewer" and attachKey == "essential" then
        shift = shift - centre
    end
    return shift
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

    local xShift = TrinketAnchorShift(viewer, vdb)
    local yShift = TrinketAnchorShiftY(viewer, vdb)

    applyingViewerAnchor[proxy] = true
    proxy:ClearAllPoints()
    proxy:SetPoint(
        vdb.anchorPoint or "CENTER",
        target,
        vdb.anchorRelativePoint or "CENTER",
        (vdb.anchorXOffset or 0) + xShift,
        (vdb.anchorYOffset or 0) + yShift
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
        + math.floor((vdb.iconZoom or 0) * 1000) * 7
        + (vdb.iconLockAspectRatio ~= false and 1 or 0) * 13
        + (vdb.lockAspect and 1 or 0) * 113
        + (vdb.overrideSize and 1 or 0) * 211
    local g = vdb.growthDirection
    if g then for i = 1, #g do sig = sig + g:byte(i) * i end end
    return sig
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

local function LayoutViewer(viewer)

    if cdmRebuilding then return end
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then return end
    local vdb = GetViewerDB(viewer:GetName())
    if not vdb then return end

    HookViewerAnchor(viewer)
    ReapplyViewerAnchor(viewer)

    viewer._tuiVisible = viewer._tuiVisible or {}
    local visible = CollectAndHook(viewer, viewer._tuiVisible, HookChild)
    local TR = ns.TrinketsCDM
    if TR and TR.GetInlineButtonsFor then
        local tb = TR.GetInlineButtonsFor(viewer)
        if tb then for i = 1, #tb do visible[#visible + 1] = tb[i] end end
    end
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

    if #visible == 0 then return end

    SortByCooldownID(visible)

    local sig = ComputeLayoutSig(visible, vdb)
    if viewer._tuiLayoutSig == sig then return end
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
            end
        end
    end

    local iconW = (sizeW) or visible[1]:GetWidth() or 36
    local iconH = (sizeH) or visible[1]:GetHeight() or 36
    local BACKDROP_INSET = 2
    local spacing  = (vdb.spacing or 0) + BACKDROP_INSET
    local growth   = GROWTH[vdb.growthDirection] or GROWTH.CENTERED_H
    local perLine  = math.max(1, vdb.iconsPerRow or 20)
    local anchorPin = vdb.anchorPoint or "CENTER"
    local count    = #visible

    local cols, rows
    if growth.axis == "V" then
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
    for i = 1, count do
        local child = visible[i]
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
        local ancX, ancY = _cornerXY(anchorPin,  totalW, totalH)
        local ax, ay = pinX + x - ancX, pinY + y - ancY

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

    local vscale = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    if math.abs((proxy:GetScale() or 1) - vscale) > 0.001 then proxy:SetScale(vscale) end
    if math.abs((proxy:GetWidth() or 0) - totalW) > 0.5
       or math.abs((proxy:GetHeight() or 0) - totalH) > 0.5 then
        Pixel.SetSize(proxy, totalW, totalH)
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
            self._tuiLayoutSig = nil
            QueueLayout(self)
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

function M.RefreshAll()
    M.Invalidate()
    HookEditModeExit()
    EnsureUtilityMover()
    for name in pairs(VIEWERS) do
        HookViewer(name)
        QueueLayout(_G[name])
    end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

function TUI:UpdateCDMIcons()
    M.RefreshAll()
    if ns.EssentialMover and ns.EssentialMover.OnGrowthDirectionChanged then
        ns.EssentialMover.OnGrowthDirectionChanged()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        cdmRebuilding = true
        C_Timer.After(2.5, function() cdmRebuilding = false end)
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAll) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        M.RefreshAll()
    else
        M.RefreshAll()
        for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do C_Timer.After(t, M.RefreshAll) end
    end
end)
