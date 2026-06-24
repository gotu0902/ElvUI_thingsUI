local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local updateFrame = CreateFrame("Frame")
local eventFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local lastEssentialCount = 0
local lastUtilityCount = 0
local lastGeoSig = nil
local forceClusterUpdate = true
local combatDeferred = false
local MarkDirty
local clusterProxy

local function CountVisibleChildren(frame)
    if not frame then return 0 end

    local count = 0
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child and child:IsShown() then
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

local hookedProxy = false
local function HookEssentialProxy()
    if hookedProxy then return end
    local pr = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(EssentialCooldownViewer)
    if not pr then return end
    hookedProxy = true
    local mark = function() MarkDirty() end
    hooksecurefunc(pr, "SetSize",        mark)
    hooksecurefunc(pr, "SetWidth",       mark)
    hooksecurefunc(pr, "SetHeight",      mark)
    hooksecurefunc(pr, "SetPoint",       mark)
    hooksecurefunc(pr, "ClearAllPoints", mark)
    hooksecurefunc(pr, "SetScale",       mark)
end

local function ScanAndHookViewers()
    HookViewerChildren(EssentialCooldownViewer)
    HookViewerChildren(UtilityCooldownViewer)
    HookEssentialProxy()
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

local function GetIconWidth(viewerKey, fallback)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local v = cdm and cdm[viewerKey]
    if not v then return fallback end
    return v.iconWidth or fallback
end

local function CalculateEffectiveWidth()
    local db = E.db.thingsUI.clusterPositioning
    local essentialIconWidth = GetIconWidth("essential", 40)
    local utilityIconWidth   = GetIconWidth("utility",   32)

    local essentialCount = EssentialCooldownViewer and CountVisibleChildren(EssentialCooldownViewer) or 0
    local utilityCount = UtilityCooldownViewer and CountVisibleChildren(UtilityCooldownViewer) or 0

    local extraTrinkets = ns.TrinketsCDM and ns.TrinketsCDM.GetExtraEssentialCount and ns.TrinketsCDM.GetExtraEssentialCount() or 0
    if extraTrinkets > 0 then
        local attachKey = (ns.TrinketsCDM.GetTrinketAttachKey and ns.TrinketsCDM.GetTrinketAttachKey()) or "essential"
        if attachKey == "utility" then
            utilityCount = utilityCount + extraTrinkets
        else
            essentialCount = essentialCount + extraTrinkets
        end
    end

    local essentialWidth = (essentialCount * essentialIconWidth) + (math.max(0, essentialCount - 1) * db.essentialIconPadding)

    if not db.accountForUtility or utilityCount == 0 or essentialCount == 0 then
        return essentialWidth, essentialCount, utilityCount, 0
    end

    local utilityWidth = (utilityCount * utilityIconWidth) + (math.max(0, utilityCount - 1) * db.utilityIconPadding)

    local overflow = 0
    local extraUtilityIcons = math.max(0, utilityCount - essentialCount)
    local threshold = db.utilityThreshold or 3

    if extraUtilityIcons >= threshold and utilityWidth > essentialWidth then
        local widthDifference = utilityWidth - essentialWidth
        overflow = widthDifference + ((db.utilityOverflowOffset or 25) * 2)
    end

    return essentialWidth + overflow, essentialCount, utilityCount, overflow
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
    proxy:SetSize(w * k, h * k)
    proxy:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", fl * k, fb * k)
    return true
end

local function UpdateClusterPositioning()
    local db = E.db.thingsUI.clusterPositioning
    if not db.enabled then return end
    if not EssentialCooldownViewer then return end
    
    if InCombatLockdown() then
        if not combatDeferred then
            combatDeferred = true
        end
        return
    end
    
    local effectiveWidth, essentialCount, utilityCount, utilityOverflow = CalculateEffectiveWidth()

    local cdmProxy = ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(EssentialCooldownViewer)
    local src = cdmProxy or EssentialCooldownViewer
    local vLeft  = src:GetLeft()  or 0
    local vRight = src:GetRight() or 0
    local vCY    = ((src:GetTop() or 0) + (src:GetBottom() or 0)) * 0.5
    local geoSig = math.floor(vLeft + 0.5) + math.floor(vRight + 0.5) * 7
                 + math.floor(vCY + 0.5) * 13 + essentialCount * 101
                 + utilityCount * 211 + math.floor((utilityOverflow or 0) + 0.5) * 17
    if (not forceClusterUpdate) and geoSig == lastGeoSig then return end
    forceClusterUpdate = false
    lastGeoSig = geoSig
    lastEssentialCount = essentialCount
    lastUtilityCount = utilityCount

    local proxy = EnsureProxy()
    if not SyncProxyToViewer(proxy, src) then return end

    local yOffset = 0
    local sideOverflow = utilityOverflow / 2
    local viewerW = src:GetWidth() or 0
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
            playerFrame:SetPoint("RIGHT", proxy, "LEFT", -(db.frameGap + sideOverflow + leftExtra) - parityNudge, yOffset)
        end
    end

    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", proxy, "RIGHT", db.frameGap + sideOverflow + rightExtra + parityNudge, yOffset)
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
            lastEssentialCount = -1
            lastUtilityCount = -1
            ForceClusterUpdate()
            MarkDirty()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatDeferred = false
        ScanAndHookViewers()
        lastEssentialCount = -1
        lastUtilityCount = -1
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
end

function TUI:UpdateClusterPositioning()
    if E.db.thingsUI.clusterPositioning.enabled then
        isEnabled = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

        C_Timer.After(0.5, function()
            ScanAndHookViewers()
            lastEssentialCount = -1
            lastUtilityCount = -1
            ForceClusterUpdate()
            MarkDirty()
        end)
    else
        isEnabled = false
        isDirty = false
        combatDeferred = false
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
        lastEssentialCount = 0
        lastUtilityCount = 0
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
    
    lastEssentialCount = -1
    lastUtilityCount = -1
    ForceClusterUpdate()
    UpdateClusterPositioning()
    
    local db = E.db.thingsUI.clusterPositioning
    local effectiveWidth, essentialCount, utilityCount, overflow = CalculateEffectiveWidth()
    local extraIcons = math.max(0, utilityCount - essentialCount)
    local threshold = db.utilityThreshold or 3
    local triggered = extraIcons >= threshold
end