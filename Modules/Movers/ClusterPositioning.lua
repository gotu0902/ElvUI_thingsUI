local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local updateFrame = CreateFrame("Frame")
local eventFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local lastGeoSig = nil
local forceClusterUpdate = true
local MarkDirty
local clusterProxy

local function CountVisibleChildren(frame)
    if not frame then return 0 end

    local hiddenCheck = ns.CDMIcons and ns.CDMIcons.IsPassiveHidden
    local count = 0
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child and child:IsShown() and not (hiddenCheck and hiddenCheck(child)) then
            count = count + 1
        end
    end

    return count
end

local function ForceClusterUpdate()
    forceClusterUpdate = true
end

local hookedViewers = {}

local function HookViewerChildren(viewer)
    if not viewer or hookedViewers[viewer] then return end
    if type(viewer.RefreshLayout) ~= "function" then return end
    hookedViewers[viewer] = true
    hooksecurefunc(viewer, "RefreshLayout", function() MarkDirty() end)
    hooksecurefunc(viewer, "SetSize",   function() MarkDirty() end)
    hooksecurefunc(viewer, "SetWidth",  function() MarkDirty() end)
    hooksecurefunc(viewer, "SetHeight", function() MarkDirty() end)
end

local hookedProxies = {}
local function HookProxy(viewer)
    if not viewer or hookedProxies[viewer] then return end
    local pr = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(viewer)
    if not pr then return end
    hookedProxies[viewer] = true
    local mark = function() MarkDirty() end
    hooksecurefunc(pr, "SetSize",        mark)
    hooksecurefunc(pr, "SetWidth",       mark)
    hooksecurefunc(pr, "SetHeight",      mark)
    hooksecurefunc(pr, "SetPoint",       mark)
    hooksecurefunc(pr, "ClearAllPoints", mark)
    hooksecurefunc(pr, "SetScale",       mark)
end

local hookedUF = false
local function HookUFUpdates()
    if hookedUF then return end
    local UF = E.GetModule and E:GetModule("UnitFrames", true)
    if not UF then return end
    hookedUF = true
    hooksecurefunc(UF, "CreateAndUpdateUF", function(_, unit)
        if unit == "player" or unit == "target" or unit == "focus" then TUI:QueueClusterUpdate() end
    end)
    hooksecurefunc(UF, "Update_AllFrames", function() TUI:QueueClusterUpdate() end)
end

local function ScanAndHookViewers()
    HookViewerChildren(EssentialCooldownViewer)
    HookViewerChildren(UtilityCooldownViewer)
    HookProxy(EssentialCooldownViewer)
    HookProxy(UtilityCooldownViewer)
    HookUFUpdates()
end

local clusterUpdateQueued = false
function TUI:QueueClusterUpdate()
    if clusterUpdateQueued then return end
    clusterUpdateQueued = true
    C_Timer.After(0, function()
        clusterUpdateQueued = false
        ForceClusterUpdate()
        MarkDirty()
    end)
end

local INLINE_SOURCES = { "TrinketsCDM", "TimersCDM", "RacialsCDM" }

-- Fold-ins are UIParent-parented (invisible to GetChildren) but widen the rows
local function CountClusterIcons()
    local essentialCount = EssentialCooldownViewer and CountVisibleChildren(EssentialCooldownViewer) or 0
    local utilityCount = UtilityCooldownViewer and CountVisibleChildren(UtilityCooldownViewer) or 0

    for _, key in ipairs(INLINE_SOURCES) do
        local m = ns[key]
        if m and m.GetInlineButtonsFor then
            local eb = m.GetInlineButtonsFor(EssentialCooldownViewer)
            if eb then essentialCount = essentialCount + #eb end
            local ub = m.GetInlineButtonsFor(UtilityCooldownViewer)
            if ub then utilityCount = utilityCount + #ub end
        end
    end

    return essentialCount, utilityCount
end
ns.ClusterCounts = CountClusterIcons

local function GetBoundsInUIParent(frame)
    if not frame then return end
    local l, r = frame:GetLeft(), frame:GetRight()
    if not l or not r then return end
    local k = (frame:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    return l * k, r * k
end

local STATIC_UTILITY_ANCHORS = { [""] = true, UIParent = true, EssentialCooldownViewer = true }

-- Per-side push from the LIVE row bounds, not icon-size estimates
local function ComputeUtilityOverflow(db, src, essentialCount, utilityCount)
    if not db.accountForUtility or essentialCount == 0 or utilityCount == 0 then return 0, 0 end
    if (utilityCount - essentialCount) < (db.utilityThreshold or 3) then return 0, 0 end
    local uv = UtilityCooldownViewer
    local up = uv and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(uv)
    local eL, eR = GetBoundsInUIParent(src)
    local uL, uR = GetBoundsInUIParent(up or uv)
    if not (eL and uL) then return 0, 0 end
    local off = db.utilityOverflowOffset or 10
    local udb = E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.utility
    if udb and udb.anchorEnabled and not STATIC_UTILITY_ANCHORS[udb.anchorFrame or "UIParent"] then
        -- utility may follow a frame we move: width projection, never live edges
        local half = math.max(0, ((uR - uL) - (eR - eL)) / 2)
        if half == 0 then return 0, 0 end
        return half + off, half + off
    end
    if uL >= eR or uR <= eL then return 0, 0 end
    local left  = math.max(0, eL - uL)
    local right = math.max(0, uR - eR)
    if left  > 0 then left  = left  + off end
    if right > 0 then right = right + off end
    return left, right
end

local function EnsureProxy()
    if clusterProxy then return clusterProxy end
    clusterProxy = CreateFrame("Frame", "TUI_ClusterAnchor", _G.UIParent)
    clusterProxy:SetSize(1, 1)
    return clusterProxy
end

local function SyncProxyToViewer(proxy, viewer)
    local fl, fb = viewer:GetLeft(), viewer:GetBottom()
    if not fl or not fb then return false end
    local w, h = viewer:GetSize()
    if not w or w <= 0 or not h or h <= 0 then return false end
    local k = (viewer:GetEffectiveScale() or 1) / (_G.UIParent:GetEffectiveScale() or 1)
    proxy:ClearAllPoints()
    -- Integer geometry keeps every downstream ±w/2 round-trip lossless
    proxy:SetSize(math.floor(w * k + 0.5), math.floor(h * k + 0.5))
    proxy:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", math.floor(fl * k + 0.5), math.floor(fb * k + 0.5))
    return true
end

local function UpdateClusterPositioning()
    local db = E.db.thingsUI.clusterPositioning
    if not db.enabled then return end
    if not EssentialCooldownViewer then return end
    
    if InCombatLockdown() then return end

    local essentialCount, utilityCount = CountClusterIcons()

    local cdmProxy = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(EssentialCooldownViewer)
    local src = cdmProxy or EssentialCooldownViewer
    local leftOverflow, rightOverflow = ComputeUtilityOverflow(db, src, essentialCount, utilityCount)
    local vLeft  = src:GetLeft()  or 0
    local vRight = src:GetRight() or 0
    local vCY    = ((src:GetTop() or 0) + (src:GetBottom() or 0)) * 0.5
    local geoSig = math.floor(vLeft + 0.5) + math.floor(vRight + 0.5) * 7
                 + math.floor(vCY + 0.5) * 13 + essentialCount * 101
                 + utilityCount * 211 + math.floor(leftOverflow + 0.5) * 17
                 + math.floor(rightOverflow + 0.5) * 19
    if (not forceClusterUpdate) and geoSig == lastGeoSig then return end
    forceClusterUpdate = false
    lastGeoSig = geoSig

    local proxy = EnsureProxy()
    if not SyncProxyToViewer(proxy, src) then return end

    local yOffset = 0
    local viewerW = proxy:GetWidth() or 0
    local parityNudge = (math.floor(viewerW + 0.5) % 2 == 1) and 0.5 or 0
    local trinketExt, trinketSide = 0, "RIGHT"

    if ns.TrinketsCDM and ns.TrinketsCDM.GetTrinketExtent then
        local onEssential = (not ns.TrinketsCDM.GetTrinketAttachKey)
            or ns.TrinketsCDM.GetTrinketAttachKey() == "essential"
        if onEssential then
            trinketExt, trinketSide = ns.TrinketsCDM.GetTrinketExtent()
            trinketExt = trinketExt or 0
        end
    end
    local leftExtra  = (trinketSide == "LEFT")  and trinketExt or 0
    local rightExtra = (trinketSide == "RIGHT") and trinketExt or 0

    if db.playerFrame.enabled then
        local playerFrame = _G["ElvUF_Player"]
        if playerFrame then
            playerFrame:ClearAllPoints()
            playerFrame:SetPoint("RIGHT", proxy, "LEFT", -(math.floor(db.frameGap + leftOverflow + leftExtra + 0.5) + parityNudge), yOffset)
        end
    end

    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", proxy, "RIGHT", math.floor(db.frameGap + rightOverflow + rightExtra + 0.5) + parityNudge, yOffset)
        end
    end
    
    if db.targetTargetFrame.enabled then
        local totFrame = _G["ElvUF_TargetTarget"]
        local targetFrame = _G["ElvUF_Target"]
        if totFrame and targetFrame then
            totFrame:ClearAllPoints()
            totFrame:SetPoint("LEFT", targetFrame, "RIGHT", db.targetTargetFrame.gap, 0)
        end
    end
    
    if db.targetCastBar.enabled then
        local targetFrame = _G["ElvUF_Target"]
        local castBar = _G["ElvUF_Target_CastBar"]
        if targetFrame and castBar then
            local holder = castBar.Holder or castBar
            holder:ClearAllPoints()
            holder:SetPoint("TOP", targetFrame, "BOTTOM", db.targetCastBar.xOffset, -db.targetCastBar.gap)
        end
    end
    
    if db.additionalPowerBar and db.additionalPowerBar.enabled then
        local playerFrame = _G["ElvUF_Player"]
        local powerBar = _G["ElvUF_Player_AdditionalPowerBar"]
        if playerFrame and powerBar then
            powerBar:ClearAllPoints()
            powerBar:SetPoint("TOP", playerFrame, "BOTTOM", db.additionalPowerBar.xOffset, db.additionalPowerBar.gap)
        end
    end

    if db.focusFrame and db.focusFrame.enabled then
        local fdb = db.focusFrame
        local focus = _G["ElvUF_Focus"]
        local anchor = ns.ANCHORS.ResolveAnchorTarget(fdb.anchorFrame or "ElvUF_Target") or _G["ElvUF_Target"]
        if focus and anchor then
            focus:ClearAllPoints()
            focus:SetPoint(fdb.anchorPoint or "TOP", anchor, fdb.anchorRelativePoint or "BOTTOM", fdb.xOffset or 0, fdb.yOffset or 0)
            if fdb.matchWidth then
                local w = anchor.GetWidth and anchor:GetWidth()
                if w and w > 0 then focus:SetWidth(w) end
            end
        end
    end

    if db.focusCastBar and db.focusCastBar.enabled then
        local cdb = db.focusCastBar
        local focus = _G["ElvUF_Focus"]
        local castBar = _G["ElvUF_Focus_CastBar"]
        if focus and castBar then
            local fcb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.focus
                and E.db.unitframe.units.focus.castbar
            local w = focus:GetWidth()
            if fcb and w and w > 0 then
                w = math.floor(w + 0.5) + 1
                if cdb.savedWidth == nil then cdb.savedWidth = fcb.width end
                if fcb.width ~= w then
                    fcb.width = w
                    local UF = E.GetModule and E:GetModule("UnitFrames", true)
                    if UF and UF.Configure_Castbar then pcall(UF.Configure_Castbar, UF, focus) end
                end
            end
            local holder = castBar.Holder or castBar
            holder:ClearAllPoints()
            holder:SetPoint(cdb.anchorPoint or "TOP", focus, cdb.anchorRelativePoint or "BOTTOM", cdb.xOffset or 0, cdb.yOffset or 0)
        end
    end

    if ns.MoverSync and ns.MoverSync.Queue then
        ns.MoverSync.Queue()
    end
end

local SETTLE_TIME = 0.06
local lastMark = 0
local function OnSettleTick(self)
    if (GetTime() - lastMark) < SETTLE_TIME then return end
    self:SetScript("OnUpdate", nil)
    isDirty = false
    UpdateClusterPositioning()
end

MarkDirty = function()
    if not isEnabled then return end
    lastMark = GetTime()
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnSettleTick)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            ScanAndHookViewers()
            ForceClusterUpdate()
            MarkDirty()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ScanAndHookViewers()
        ForceClusterUpdate()
        MarkDirty()
    end
end)

local function RestoreFramesToElvUI()
    if InCombatLockdown() then return end
    
    local playerFrame, playerMover = _G["ElvUF_Player"], _G["ElvUF_PlayerMover"]
    if playerFrame and playerMover then
        playerFrame:ClearAllPoints()
        playerFrame:SetPoint("CENTER", playerMover, "CENTER", 0, 0)
    end
    
    local targetFrame, targetMover = _G["ElvUF_Target"], _G["ElvUF_TargetMover"]
    if targetFrame and targetMover then
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("CENTER", targetMover, "CENTER", 0, 0)
    end
    
    local totFrame, totMover = _G["ElvUF_TargetTarget"], _G["ElvUF_TargetTargetMover"]
    if totFrame and totMover then
        totFrame:ClearAllPoints()
        totFrame:SetPoint("CENTER", totMover, "CENTER", 0, 0)
    end
    
    local castBar, castBarMover = _G["ElvUF_Target_CastBar"], _G["ElvUF_TargetCastbarMover"]
    if castBar and castBarMover then
        local holder = castBar.Holder or castBar
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", castBarMover, "CENTER", 0, 0)
    end
    
    local powerBar, powerBarMover = _G["ElvUF_Player_AdditionalPowerBar"], _G["ElvUF_AdditionalPowerBarMover"]
    if powerBar and powerBarMover then
        powerBar:ClearAllPoints()
        powerBar:SetPoint("CENTER", powerBarMover, "CENTER", 0, 0)
    end

    local focusFrame, focusMover = _G["ElvUF_Focus"], _G["ElvUF_FocusMover"]
    if focusFrame and focusMover then
        focusFrame:ClearAllPoints()
        focusFrame:SetPoint("CENTER", focusMover, "CENTER", 0, 0)
        local uf = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.focus
        if uf and uf.width then focusFrame:SetWidth(uf.width) end
    end

    local fCastBar, fCastBarMover = _G["ElvUF_Focus_CastBar"], _G["ElvUF_FocusCastbarMover"]
    if fCastBar and fCastBarMover then
        local holder = fCastBar.Holder or fCastBar
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", fCastBarMover, "CENTER", 0, 0)
    end

    local cdb = E.db.thingsUI.clusterPositioning.focusCastBar
    if cdb and cdb.savedWidth then
        local fcb = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.focus
            and E.db.unitframe.units.focus.castbar
        if fcb then
            fcb.width = cdb.savedWidth
            local UF = E.GetModule and E:GetModule("UnitFrames", true)
            if UF and UF.Configure_Castbar and _G["ElvUF_Focus"] then
                pcall(UF.Configure_Castbar, UF, _G["ElvUF_Focus"])
            end
        end
        cdb.savedWidth = nil
    end
end

local function ApplyIconInsideDefault()
    local db = E.db.thingsUI.clusterPositioning
    if db.iconInsideApplied then return end
    db.iconInsideApplied = true
    local UF = E.GetModule and E:GetModule("UnitFrames", true)
    for _, unit in ipairs({ "player", "target", "focus" }) do
        local u = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unit]
        local cb = u and u.castbar
        if cb then cb.icon = true; cb.iconAttached = true end
        local f = _G["ElvUF_" .. unit:gsub("^%l", string.upper)]
        if UF and UF.Configure_Castbar and f and f.Castbar then
            pcall(UF.Configure_Castbar, UF, f)
        end
    end
end

function TUI:UpdateClusterPositioning()
    if ns.EssentialMover and ns.EssentialMover.RefreshLabel then ns.EssentialMover.RefreshLabel() end
    if E.db.thingsUI.clusterPositioning.enabled then
        isEnabled = true
        ApplyIconInsideDefault()
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

        C_Timer.After(0.5, function()
            ScanAndHookViewers()
            ForceClusterUpdate()
            MarkDirty()
        end)
    else
        isEnabled = false
        isDirty = false
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
        forceClusterUpdate = true
        -- Profile-switch guard
        C_Timer.After(0.1, RestoreFramesToElvUI)
        C_Timer.After(0.5, RestoreFramesToElvUI)
        C_Timer.After(1.5, RestoreFramesToElvUI)
    end
end

function TUI:RecalculateCluster()
    if InCombatLockdown() then
        print("|cFF8080FFElvUI_thingsUI|r - Cannot reposition during combat.")
        return
    end
    
    ForceClusterUpdate()
    UpdateClusterPositioning()
end