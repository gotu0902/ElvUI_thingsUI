local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local updateFrame = CreateFrame("Frame")
local eventFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local lastEssentialCount = 0
local lastUtilityCount = 0
local forceClusterUpdate = true
local combatDeferred = false
local MarkDirty

-- Count visible icons in a frame
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

-- Hook CDM children so we update only when bars actually appear/disappear.
local hookedChildren = {}

local function HookViewerChildren(viewer)
    if not viewer then return end

    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child and not hookedChildren[child] then
            hookedChildren[child] = true
            child:HookScript("OnShow", MarkDirty)
            child:HookScript("OnHide", MarkDirty)
        end
    end
end

local function ScanAndHookViewers()
    HookViewerChildren(EssentialCooldownViewer)
    HookViewerChildren(UtilityCooldownViewer)
end

-- Coalesce rapid config changes into one update per frame
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

-- Calculate effective cluster width
local function CalculateEffectiveWidth()
    local db = E.db.thingsUI.clusterPositioning
    
    local essentialCount = EssentialCooldownViewer and CountVisibleChildren(EssentialCooldownViewer) or 0
    local utilityCount = UtilityCooldownViewer and CountVisibleChildren(UtilityCooldownViewer) or 0
    
    local essentialWidth = (essentialCount * db.essentialIconWidth) + (math.max(0, essentialCount - 1) * db.essentialIconPadding)
    
    if not db.accountForUtility or utilityCount == 0 or essentialCount == 0 then
        return essentialWidth, essentialCount, utilityCount, 0
    end
    
    local utilityWidth = (utilityCount * db.utilityIconWidth) + (math.max(0, utilityCount - 1) * db.utilityIconPadding)
    
    local overflow = 0
    local extraUtilityIcons = math.max(0, utilityCount - essentialCount)
    local threshold = db.utilityThreshold or 3
    
    if extraUtilityIcons >= threshold and utilityWidth > essentialWidth then
        local widthDifference = utilityWidth - essentialWidth
        overflow = widthDifference + ((db.utilityOverflowOffset or 25) * 2)
    end
    
    return essentialWidth + overflow, essentialCount, utilityCount, overflow
end

-- Apply positioning
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
    
    -- Only update if something actually changed (counts), unless forced
    if (not forceClusterUpdate) and essentialCount == lastEssentialCount and utilityCount == lastUtilityCount then return end
    forceClusterUpdate = false
    lastEssentialCount = essentialCount
    lastUtilityCount = utilityCount
    
    local yOffset = db.yOffset
    local sideOverflow = utilityOverflow / 2
    
    if db.playerFrame.enabled then
        local playerFrame = _G["ElvUF_Player"]
        if playerFrame then
            playerFrame:ClearAllPoints()
            playerFrame:SetPoint("RIGHT", EssentialCooldownViewer, "LEFT", -(db.frameGap + sideOverflow), yOffset)
        end
    end
    
    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", EssentialCooldownViewer, "RIGHT", db.frameGap + sideOverflow, yOffset)
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
end

-- Dirty-flag system: coalesce multiple show/hide events into one update next frame
local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    UpdateClusterPositioning()
end

MarkDirty = function()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end

-- Event handler
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

-- Restore frames to their ElvUI mover positions
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
        C_Timer.After(0.1, RestoreFramesToElvUI)
        C_Timer.After(0.5, RestoreFramesToElvUI)
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
    
    local essentialWidth = (essentialCount * db.essentialIconWidth) + (math.max(0, essentialCount - 1) * db.essentialIconPadding)
    local utilityWidth = (utilityCount * db.utilityIconWidth) + (math.max(0, utilityCount - 1) * db.utilityIconPadding)
    
end