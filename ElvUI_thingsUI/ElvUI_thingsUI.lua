-- thingsUI - ElvUI Plugin
-- Adds additional customization options for the Cooldown Manager

local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local LSM = E.Libs.LSM
local addon, ns = ...

-- Create the plugin module
local TUI = E:NewModule("thingsUI", "AceHook-3.0", "AceEvent-3.0")
ns.TUI = TUI

-- Plugin version info
TUI.version = "1.10.1"
TUI.name = "thingsUI"

-- Defaults that get merged into ElvUI's profile
P["thingsUI"] = {
    -- Buff Icons (BuffIconCooldownViewer)
    verticalBuffs = false,
    
    -- Buff Bars (BuffBarCooldownViewer)
    buffBars = {
        enabled = false,
        growthDirection = "UP", -- "UP" or "DOWN"
        width = 200,
        height = 20,
        spacing = 1,
        statusBarTexture = "ElvUI Norm",
        font = "PT Sans Narrow",
        fontSize = 12,
        fontOutline = "OUTLINE",
        iconEnabled = true,
        backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        useClassColor = true,
        customColor = { r = 0.2, g = 0.6, b = 1.0 },
        -- Anchor settings
        anchorEnabled = false,
        anchorFrame = "ElvUF_Player",
        anchorPoint = "BOTTOM",      -- Point on buff bars
        anchorRelativePoint = "TOP", -- Point on target frame
        anchorXOffset = 0,
        anchorYOffset = 5,
    },
    
    -- Dynamic Cooldown Cluster Positioning
    clusterPositioning = {
        enabled = false,
        essentialIconWidth = 42,    -- Width per Essential icon
        essentialIconPadding = 1,   -- Padding between Essential icons
        utilityIconWidth = 30,      -- Width per Utility icon (usually smaller)
        utilityIconPadding = 1,     -- Padding between Utility icons
        accountForUtility = true,   -- Account for Utility icons extending past Essential
        yOffset = 0,                -- Y offset for all unit frames
        
        -- Unit Frame positioning
        playerFrame = {
            enabled = true,
            gap = 5,
        },
        targetFrame = {
            enabled = true,
            gap = 5,
        },
        targetTargetFrame = {
            enabled = true,
            gap = 1,
        },
        targetCastBar = {
            enabled = true,
            gap = 1,
            xOffset = 0,
        },
    },
    -- Anchor BetterCooldownManager frames
    bcdmAnchors = {
        enabled = false,
        throttle = 0,

        -- Supported anchor targets: PLAYER, TARGET, ESSENTIAL, UTILITY, UIPARENT
        frames = {
            BCDM_CustomCooldownViewer = {
                enabled = false,
                anchorTo = "PLAYER",
                point = "CENTER",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0,
            },
            BCDM_AdditionalCustomCooldownViewer = {
                enabled = false,
                anchorTo = "PLAYER",
                point = "CENTER",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0,
            },
            BCDM_CustomItemBar = {
                enabled = false,
                anchorTo = "PLAYER",
                point = "CENTER",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0,
            },
            BCDM_TrinketBar = {
                enabled = false,
                anchorTo = "PLAYER",
                point = "CENTER",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0,
            },
            BCDM_CustomItemSpellBar = {
                enabled = false,
                anchorTo = "PLAYER",
                point = "CENTER",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0,
            },
        },
    },

}

-------------------------------------------------
-- VERTICAL BUFF ICONS (BuffIconCooldownViewer)
-------------------------------------------------
local iconUpdateThrottle = 0.05
local iconNextUpdate = 0
local iconUpdateFrame = CreateFrame("Frame")

local function PositionBuffsVertically()
    local currentTime = GetTime()
    if currentTime < iconNextUpdate then return end
    iconNextUpdate = currentTime + iconUpdateThrottle
    
    if not BuffIconCooldownViewer then return end
    if not E.db.thingsUI or not E.db.thingsUI.verticalBuffs then return end
    
    local visibleBuffIcons = {}

    for _, childFrame in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
        if childFrame and childFrame.Icon and childFrame:IsShown() then
            table.insert(visibleBuffIcons, childFrame)
        end
    end

    if #visibleBuffIcons == 0 then return end

    table.sort(visibleBuffIcons, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local iconSize = visibleBuffIcons[1]:GetWidth()
    local iconSpacing = BuffIconCooldownViewer.childYPadding or 0
    
    for index, iconFrame in ipairs(visibleBuffIcons) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("TOP", BuffIconCooldownViewer, "TOP", 0, -((index - 1) * (iconSize + iconSpacing)))
    end
end

function TUI:UpdateVerticalBuffs()
    if E.db.thingsUI.verticalBuffs then
        iconUpdateFrame:SetScript("OnUpdate", PositionBuffsVertically)
    else
        iconUpdateFrame:SetScript("OnUpdate", nil)
    end
end

-------------------------------------------------
-- BUFF BAR SKINNING (BuffBarCooldownViewer)
-------------------------------------------------
local barUpdateThrottle = 0.1
local barNextUpdate = 0
local barUpdateFrame = CreateFrame("Frame")
local skinnedBars = {}

local function GetClassColor()
    local classColor = E:ClassColor(E.myclass, true)
    return classColor.r, classColor.g, classColor.b
end

local function SkinBuffBar(childFrame, forceUpdate)
    if not childFrame then return end
    if InCombatLockdown() then return end -- Don't skin during combat
    
    local db = E.db.thingsUI.buffBars
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    
    if not bar then return end
    
    -- Check if this is a new bar or needs full skinning
    local needsFullSkin = not skinnedBars[childFrame] or forceUpdate
    
    -- ALWAYS apply size (fixes width reset issue)
    childFrame:SetSize(db.width, db.height)
    
    -- Skin the status bar
    if bar then
        bar:ClearAllPoints()
        
        if db.iconEnabled and icon then
            bar:SetPoint("TOPLEFT", childFrame, "TOPLEFT", db.height + 2, 0)
            bar:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)
        else
            bar:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 0, 0)
            bar:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)
        end
        
        -- Apply ElvUI statusbar texture
        local texture = LSM:Fetch("statusbar", db.statusBarTexture)
        bar:SetStatusBarTexture(texture)
        
        -- Bar color
        if db.useClassColor then
            local r, g, b = GetClassColor()
            bar:SetStatusBarColor(r, g, b, 1)
        else
            bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b, 1)
        end
        
        -- Background
        if bar.BarBG then
            bar.BarBG:SetTexture(texture)
            bar.BarBG:SetVertexColor(db.backgroundColor.r, db.backgroundColor.g, db.backgroundColor.b, db.backgroundColor.a)
            bar.BarBG:ClearAllPoints()
            bar.BarBG:SetAllPoints(bar)
        end
        
        -- Hide the pip/spark if it exists
        if bar.Pip then
            bar.Pip:SetAlpha(0)
        end
        
        -- Spell name text
        if bar.Name then
            local font = LSM:Fetch("font", db.font)
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:ClearAllPoints()
            bar.Name:SetPoint("LEFT", bar, "LEFT", 4, 0)
            bar.Name:SetJustifyH("LEFT")
        end
        
        -- Duration text
        if bar.Duration then
            local font = LSM:Fetch("font", db.font)
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:ClearAllPoints()
            bar.Duration:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
            bar.Duration:SetJustifyH("RIGHT")
        end
        
        -- Create backdrop if it doesn't exist
        if needsFullSkin and not childFrame.tuiBackdrop then
            childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
            childFrame.tuiBackdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
            childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
            childFrame.tuiBackdrop:SetBackdrop({
                bgFile = E.media.blankTex,
                edgeFile = E.media.blankTex,
                edgeSize = 1,
            })
            childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0)
            childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
            childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel())
        end
    end
    
    -- Skin the icon
    if icon and icon.Icon then
        if db.iconEnabled then
            icon:Show()
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 0, 0)
            icon:SetSize(db.height, db.height)
            
            icon.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Trim edges
            icon.Icon:ClearAllPoints()
            icon.Icon:SetAllPoints(icon)
            
            -- Icon backdrop
            if needsFullSkin and not icon.tuiBackdrop then
                icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
                icon.tuiBackdrop:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
                icon.tuiBackdrop:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
                icon.tuiBackdrop:SetBackdrop({
                    bgFile = E.media.blankTex,
                    edgeFile = E.media.blankTex,
                    edgeSize = 1,
                })
                icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 0)
                icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
                icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel())
            end
        else
            icon:Hide()
        end
    end
    
    -- Hide debuff border if present
    if childFrame.DebuffBorder then
        childFrame.DebuffBorder:SetAlpha(0)
    end
    
    skinnedBars[childFrame] = true
end

-- Check if a bar has an active aura (is actually tracking something)
local function IsBarActive(childFrame)
    if not childFrame then return false end
    
    -- Use pcall to safely handle protected values during combat
    local success, result = pcall(function()
        if not childFrame:IsShown() then return false end
        
        -- Check if the bar has actual content (name text or duration)
        local bar = childFrame.Bar
        if bar then
            -- Check if there's a spell name set
            if bar.Name then
                local text = bar.Name:GetText()
                if text and text ~= "" then
                    return true
                end
            end
            -- Check if the bar has a value (duration progress)
            local value = bar:GetValue()
            local min, max = bar:GetMinMaxValues()
            if max > 0 and value > 0 then
                return true
            end
        end
        
        return false
    end)
    
    if success then
        return result
    else
        -- If we can't access the values (combat lockdown), assume bar is active if shown
        return childFrame:IsShown()
    end
end

-- Anchor the BuffBarCooldownViewer container
local function AnchorBuffBarContainer()
    if not BuffBarCooldownViewer then return end
    if InCombatLockdown() then return end
    
    local db = E.db.thingsUI.buffBars
    if not db.anchorEnabled then return end
    
    local anchorFrame = _G[db.anchorFrame]
    if not anchorFrame then return end
    
    BuffBarCooldownViewer:ClearAllPoints()
    BuffBarCooldownViewer:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
end

local function UpdateBuffBarPositions()
    if not BuffBarCooldownViewer then return end
    if InCombatLockdown() then return end -- Skip during combat
    
    local db = E.db.thingsUI.buffBars
    local visibleBars = {}
    
    for _, childFrame in ipairs({ BuffBarCooldownViewer:GetChildren() }) do
        -- Only include bars that are shown AND have active aura data
        if childFrame and IsBarActive(childFrame) then
            SkinBuffBar(childFrame)
            table.insert(visibleBars, childFrame)
        end
    end
    
    if #visibleBars == 0 then return end
    
    -- Sort with pcall in case layoutIndex is protected
    pcall(function()
        table.sort(visibleBars, function(a, b)
            return (a.layoutIndex or 0) < (b.layoutIndex or 0)
        end)
    end)
    
    local spacing = db.spacing
    local height = db.height
    
    for index, barFrame in ipairs(visibleBars) do
        barFrame:ClearAllPoints()
        
        if db.growthDirection == "DOWN" then
            barFrame:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, -((index - 1) * (height + spacing)))
        else -- UP
            barFrame:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, ((index - 1) * (height + spacing)))
        end
    end
    
    -- Apply container anchor if enabled
    AnchorBuffBarContainer()
end

local function BuffBarOnUpdate()
    local currentTime = GetTime()
    if currentTime < barNextUpdate then return end
    barNextUpdate = currentTime + barUpdateThrottle
    
    if not E.db.thingsUI or not E.db.thingsUI.buffBars.enabled then return end
    if not BuffBarCooldownViewer then return end
    
    UpdateBuffBarPositions()
end

function TUI:UpdateBuffBars()
    if E.db.thingsUI.buffBars.enabled then
        barUpdateFrame:SetScript("OnUpdate", BuffBarOnUpdate)
        -- Force immediate update
        if BuffBarCooldownViewer then
            wipe(skinnedBars)
            UpdateBuffBarPositions()
        end
    else
        barUpdateFrame:SetScript("OnUpdate", nil)
    end
end

-------------------------------------------------
-- DYNAMIC COOLDOWN CLUSTER POSITIONING
-------------------------------------------------
local clusterUpdateFrame = CreateFrame("Frame")
local clusterUpdateThrottle = 0.2
local clusterNextUpdate = 0
local lastEssentialCount = 0
local lastUtilityCount = 0

-- Count visible icons in a frame
local function CountVisibleChildren(frame)
    if not frame then return 0 end
    
    local count = 0
    for _, child in ipairs({ frame:GetChildren() }) do
        if child and child:IsShown() then
            count = count + 1
        end
    end
    return count
end

-- Calculate effective cluster width (accounting for Utility overflow)
local function CalculateEffectiveWidth()
    local db = E.db.thingsUI.clusterPositioning
    
    local essentialCount = EssentialCooldownViewer and CountVisibleChildren(EssentialCooldownViewer) or 0
    local utilityCount = UtilityCooldownViewer and CountVisibleChildren(UtilityCooldownViewer) or 0
    
    -- Essential width: icons * size + (icons-1) * padding
    local essentialWidth = (essentialCount * db.essentialIconWidth) + (math.max(0, essentialCount - 1) * db.essentialIconPadding)
    
    -- If not accounting for utility, just return essential width
    if not db.accountForUtility or utilityCount == 0 or essentialCount == 0 then
        return essentialWidth, essentialCount, utilityCount, 0
    end
    
    -- Simple approach: if utility has MORE icons than essential, calculate overflow
    -- based on the EXTRA icons times the utility icon width
    local extraUtilityIcons = math.max(0, utilityCount - essentialCount)

    -- 3 Utility icons == 1 Essential "step"
    local virtualEssential = math.floor(extraUtilityIcons / 3)
    local overflow = virtualEssential * (db.essentialIconWidth + db.essentialIconPadding)
    
    local effectiveWidth = essentialWidth + overflow
    
    return effectiveWidth, essentialCount, utilityCount, overflow
end

-- Apply positioning to all frames
local function UpdateClusterPositioning()
    local db = E.db.thingsUI.clusterPositioning
    if not db.enabled then return end
    if InCombatLockdown() then return end
    if not EssentialCooldownViewer then return end
    
    local effectiveWidth, essentialCount, utilityCount, utilityOverflow = CalculateEffectiveWidth()
    
    -- Only update if counts changed
    if essentialCount == lastEssentialCount and utilityCount == lastUtilityCount then return end
    lastEssentialCount = essentialCount
    lastUtilityCount = utilityCount
    
    local yOffset = db.yOffset
    
    -- Half the overflow goes to each side
    local sideOverflow = utilityOverflow / 2
    
    -- Position Player Frame - anchor to left of Essential (plus overflow)
    if db.playerFrame.enabled then
        local playerFrame = _G["ElvUF_Player"]
        if playerFrame then
            playerFrame:ClearAllPoints()
            playerFrame:SetPoint("RIGHT", EssentialCooldownViewer, "LEFT", -(db.playerFrame.gap + sideOverflow), yOffset)
        end
    end
    
    -- Position Target Frame - anchor to right of Essential (plus overflow)
    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", EssentialCooldownViewer, "RIGHT", db.targetFrame.gap + sideOverflow, yOffset)
        end
    end
    
    -- Position TargetTarget Frame - anchor to Target frame
    if db.targetTargetFrame.enabled then
        local totFrame = _G["ElvUF_TargetTarget"]
        local targetFrame = _G["ElvUF_Target"]
        if totFrame and targetFrame then
            totFrame:ClearAllPoints()
            totFrame:SetPoint("LEFT", targetFrame, "RIGHT", db.targetTargetFrame.gap, 0)
        end
    end
    
    -- Position Target CastBar - anchor below Target frame
    if db.targetCastBar.enabled then
        local targetFrame = _G["ElvUF_Target"]
        local castBar = _G["ElvUF_Target_CastBar"]
        if targetFrame and castBar then
            local holder = castBar.Holder or castBar
            holder:ClearAllPoints()
            holder:SetPoint("TOP", targetFrame, "BOTTOM", db.targetCastBar.xOffset, -db.targetCastBar.gap)
        end
    end
end

-- OnUpdate handler
local function ClusterPositioningOnUpdate()
    local currentTime = GetTime()
    if currentTime < clusterNextUpdate then return end
    clusterNextUpdate = currentTime + clusterUpdateThrottle
    
    if not E.db.thingsUI or not E.db.thingsUI.clusterPositioning.enabled then return end
    
    UpdateClusterPositioning()
end

-- Restore frames to their original ElvUI positions
local function RestoreFramesToElvUI()
    if InCombatLockdown() then return end
    
    local UF = E:GetModule("UnitFrames")
    if not UF then return end
    
    -- Player frame
    local playerFrame = _G["ElvUF_Player"]
    local playerMover = _G["ElvUF_PlayerMover"]
    if playerFrame and playerMover then
        playerFrame:ClearAllPoints()
        playerFrame:SetPoint("CENTER", playerMover, "CENTER", 0, 0)
    end
    
    -- Target frame
    local targetFrame = _G["ElvUF_Target"]
    local targetMover = _G["ElvUF_TargetMover"]
    if targetFrame and targetMover then
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("CENTER", targetMover, "CENTER", 0, 0)
    end
    
    -- TargetTarget frame
    local totFrame = _G["ElvUF_TargetTarget"]
    local totMover = _G["ElvUF_TargetTargetMover"]
    if totFrame and totMover then
        totFrame:ClearAllPoints()
        totFrame:SetPoint("CENTER", totMover, "CENTER", 0, 0)
    end
    
    -- Target CastBar - anchor holder to the mover
    local castBar = _G["ElvUF_Target_CastBar"]
    local castBarMover = _G["ElvUF_TargetCastbarMover"]
    if castBar and castBarMover then
        local holder = castBar.Holder or castBar
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", castBarMover, "CENTER", 0, 0)
    end
end

function TUI:UpdateClusterPositioning()
    if E.db.thingsUI.clusterPositioning.enabled then
        clusterUpdateFrame:SetScript("OnUpdate", ClusterPositioningOnUpdate)
        -- Force immediate update
        C_Timer.After(0.5, function()
            lastEssentialCount = -1
            lastUtilityCount = -1
            UpdateClusterPositioning()
        end)
    else
        clusterUpdateFrame:SetScript("OnUpdate", nil)
        lastEssentialCount = 0
        lastUtilityCount = 0
        -- Restore frames to ElvUI's original positions
        -- Use multiple delays to ensure it catches after profile fully loads
        C_Timer.After(0.1, function()
            if not InCombatLockdown() then
                RestoreFramesToElvUI()
            end
        end)
        C_Timer.After(0.5, function()
            if not InCombatLockdown() then
                RestoreFramesToElvUI()
            end
        end)
        C_Timer.After(1.0, function()
            if not InCombatLockdown() then
                RestoreFramesToElvUI()
            end
        end)
    end
end

-- Manual trigger for repositioning
function TUI:RecalculateCluster()
    if InCombatLockdown() then
        print("|cFF8080FFElvUI_thingsUI|r - Cannot reposition during combat.")
        return
    end
    
    lastEssentialCount = -1
    lastUtilityCount = -1
    UpdateClusterPositioning()
    
    local db = E.db.thingsUI.clusterPositioning
    local effectiveWidth, essentialCount, utilityCount, overflow = CalculateEffectiveWidth()
    local extraIcons = math.max(0, utilityCount - essentialCount)
    
    print(string.format("|cFF8080FFElvUI_thingsUI|r - Essential: %d, Utility: %d (ExtraUtility: %d, VirtualEssential: %d), Overflow: %dpx (each side: %dpx)", 
        essentialCount, utilityCount, extraIcons, math.floor(extraIcons / 3), overflow, overflow/2))
end

-------------------------------------------------
-- BCDM ANCHORING
-------------------------------------------------
local bcdmUpdateFrame = CreateFrame("Frame")
local bcdmUpdateThrottleDefault = 0.2
local bcdmNextUpdate = 0

local function GetBCDMAnchorFrame(anchorTo)
    if anchorTo == "PLAYER" then
        return _G["ElvUF_Player"]
    elseif anchorTo == "TARGET" then
        return _G["ElvUF_Target"]
    elseif anchorTo == "ESSENTIAL" then
        return _G["EssentialCooldownViewer"]
    elseif anchorTo == "UTILITY" then
        return _G["UtilityCooldownViewer"]
    else -- UIPARENT
        return UIParent
    end
end

local function ApplyBCDMAnchors()
    if not E.db.thingsUI or not E.db.thingsUI.bcdmAnchors then return end

    local db = E.db.thingsUI.bcdmAnchors
    if not db.enabled then return end
    if InCombatLockdown() then return end

    local frames = db.frames or {}
    for frameName, fdb in pairs(frames) do
        if fdb and fdb.enabled then
            local frame = _G[frameName]
            if frame then
                local anchor = GetBCDMAnchorFrame(fdb.anchorTo)
                if anchor then
                    frame:ClearAllPoints()
                    frame:SetPoint(
                        fdb.point or "TOP",
                        anchor,
                        fdb.relativePoint or "BOTTOM",
                        fdb.xOffset or 0,
                        fdb.yOffset or 0
                    )
                end
            end
        end
    end
end

local function BCDMAnchorsOnUpdate()
    if not E.db.thingsUI or not E.db.thingsUI.bcdmAnchors then return end

    local db = E.db.thingsUI.bcdmAnchors
    if not db.enabled then return end

    local currentTime = GetTime()
    local throttle = db.throttle or bcdmUpdateThrottleDefault
    if currentTime < bcdmNextUpdate then return end
    bcdmNextUpdate = currentTime + throttle

    ApplyBCDMAnchors()
end

function TUI:UpdateBCDMAnchors()
    if not E.db.thingsUI or not E.db.thingsUI.bcdmAnchors then return end

    local db = E.db.thingsUI.bcdmAnchors

    -- Always clear the updater first (we only enable it if you explicitly want periodic re-apply)
    bcdmUpdateFrame:SetScript("OnUpdate", nil)

    if not db.enabled then return end

    -- One-shot apply now
    ApplyBCDMAnchors()

    -- Hook OnShow for BCDM frames so anchors get re-applied when they appear (no constant polling).
    TUI._bcdmHooked = TUI._bcdmHooked or {}

    local function HookFrameByName(frameName)
        local f = _G[frameName]
        if f and not TUI._bcdmHooked[f] then
            f:HookScript("OnShow", ApplyBCDMAnchors)
            TUI._bcdmHooked[f] = true
        end
    end

    local names = {
        "BCDM_CustomCooldownViewer",
        "BCDM_AdditionalCustomCooldownViewer",
        "BCDM_CustomItemBar",
        "BCDM_TrinketBar",
        "BCDM_CustomItemSpellBar",
    }

    for _, n in ipairs(names) do
        HookFrameByName(n)
    end

    -- Try a few times in case BCDM creates frames slightly later.
    if not TUI._bcdmHookTicker then
        local tries = 0
        TUI._bcdmHookTicker = C_Timer.NewTicker(0.5, function(ticker)
            tries = tries + 1
            for _, n in ipairs(names) do
                HookFrameByName(n)
            end
            ApplyBCDMAnchors()

            if tries >= 10 then
                ticker:Cancel()
                TUI._bcdmHookTicker = nil
            end
        end)
    end

    -- Optional: enable periodic re-apply ONLY if throttle > 0
    local throttle = db.throttle or 0
    if throttle and throttle > 0 then
        bcdmNextUpdate = 0
        bcdmUpdateFrame:SetScript("OnUpdate", BCDMAnchorsOnUpdate)
    end
end

function TUI:ReanchorBCDMNow()
    if InCombatLockdown() then
        print("|cFF8080FFElvUI_thingsUI|r - Cannot reposition during combat.")
        return
    end

    bcdmNextUpdate = 0
    ApplyBCDMAnchors()
end

-- Generate shared config options for a BCDM frame
function TUI:BCDMFrameOptions(frameName)
    local anchorTargets = {
        PLAYER = "ElvUF_Player",
        TARGET = "ElvUF_Target",
        ESSENTIAL = "EssentialCooldownViewer",
        UTILITY = "UtilityCooldownViewer",
        UIPARENT = "UIParent",
    }

    local points = {
        TOP = "TOP",
        BOTTOM = "BOTTOM",
        LEFT = "LEFT",
        RIGHT = "RIGHT",
        CENTER = "CENTER",
        TOPLEFT = "TOPLEFT",
        TOPRIGHT = "TOPRIGHT",
        BOTTOMLEFT = "BOTTOMLEFT",
        BOTTOMRIGHT = "BOTTOMRIGHT",
    }

    return {
        enabled = {
            order = 1,
            type = "toggle",
            name = "Enable",
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].enabled end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].enabled = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
        anchorTo = {
            order = 2,
            type = "select",
            name = "Anchor To",
            values = anchorTargets,
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].anchorTo end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].anchorTo = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
        point = {
            order = 3,
            type = "select",
            name = "Point",
            values = points,
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].point end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].point = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
        relativePoint = {
            order = 4,
            type = "select",
            name = "Relative Point",
            values = points,
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].relativePoint end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].relativePoint = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
        xOffset = {
            order = 5,
            type = "range",
            name = "X Offset",
            min = -500, max = 500, step = 1,
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].xOffset end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].xOffset = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
        yOffset = {
            order = 6,
            type = "range",
            name = "Y Offset",
            min = -500, max = 500, step = 1,
            get = function() return E.db.thingsUI.bcdmAnchors.frames[frameName].yOffset end,
            set = function(_, value)
                E.db.thingsUI.bcdmAnchors.frames[frameName].yOffset = value
                TUI:UpdateBCDMAnchors()
            end,
            disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
        },
    }
end



-------------------------------------------------
-- MODULE INITIALIZATION
-------------------------------------------------
function TUI:Initialize()
    -- Register the plugin with ElvUI
    EP:RegisterPlugin(addon, TUI.ConfigTable)
    
    -- Apply settings
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateClusterPositioning()
    self:UpdateBCDMAnchors()
    
    -- Register for profile changes
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        TUI:UpdateVerticalBuffs()
        TUI:UpdateBuffBars()
        TUI:UpdateClusterPositioning()
        TUI:UpdateBCDMAnchors()
    end)
    
    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded - Config in /elvui → thingsUI")
end

-------------------------------------------------
-- ELVUI CONFIG OPTIONS
-------------------------------------------------
function TUI:ConfigTable()
    E.Options.args.thingsUI = {
        order = 100,
        type = "group",
        name = "|cFF8080FFthingsUI|r",
        childGroups = "tab",
        args = {
            header = {
                order = 1,
                type = "header",
                name = "thingsUI v" .. TUI.version,
            },
            description = {
                order = 2,
                type = "description",
                name = "Additional customization options for the Blizzard Cooldown Manager.\n\n",
            },
            
            -------------------------------------------------
            -- BUFF ICONS TAB
            -------------------------------------------------
            buffIconsTab = {
                order = 10,
                type = "group",
                name = "Buff Icons",
                args = {
                    buffIconsHeader = {
                        order = 1,
                        type = "header",
                        name = "Buff Icon Viewer (BuffIconCooldownViewer)",
                    },
                    verticalBuffs = {
                        order = 2,
                        type = "toggle",
                        name = "Grow Vertically (Top to Bottom)",
                        desc = "Stack buff icons vertically from top to bottom instead of horizontally.",
                        width = "full",
                        get = function() return E.db.thingsUI.verticalBuffs end,
                        set = function(_, value)
                            E.db.thingsUI.verticalBuffs = value
                            TUI:UpdateVerticalBuffs()
                        end,
                    },
                    verticalNote = {
                        order = 3,
                        type = "description",
                        name = "\n|cFFFFFF00Note:|r If disabling, you may need to reload UI to restore default horizontal layout.\n",
                    },
                },
            },
            
            -------------------------------------------------
            -- BUFF BARS TAB
            -------------------------------------------------
            buffBarsTab = {
                order = 20,
                type = "group",
                name = "Buff Bars",
                args = {
                    buffBarsHeader = {
                        order = 1,
                        type = "header",
                        name = "Buff Bar Viewer (BuffBarCooldownViewer)",
                    },
                    enabled = {
                        order = 2,
                        type = "toggle",
                        name = "Enable Buff Bar Skinning",
                        desc = "Apply ElvUI styling to the Cooldown Manager buff bars.",
                        width = "full",
                        get = function() return E.db.thingsUI.buffBars.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.enabled = value
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    layoutHeader = {
                        order = 10,
                        type = "header",
                        name = "Layout",
                    },
                    growthDirection = {
                        order = 11,
                        type = "select",
                        name = "Growth Direction",
                        desc = "Direction the bars grow.",
                        values = {
                            ["UP"] = "Up",
                            ["DOWN"] = "Down",
                        },
                        get = function() return E.db.thingsUI.buffBars.growthDirection end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.growthDirection = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    width = {
                        order = 12,
                        type = "range",
                        name = "Width",
                        min = 100, max = 400, step = 1,
                        get = function() return E.db.thingsUI.buffBars.width end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.width = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    height = {
                        order = 13,
                        type = "range",
                        name = "Height",
                        min = 10, max = 40, step = 1,
                        get = function() return E.db.thingsUI.buffBars.height end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.height = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    spacing = {
                        order = 14,
                        type = "range",
                        name = "Spacing",
                        min = 0, max = 10, step = 1,
                        get = function() return E.db.thingsUI.buffBars.spacing end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.spacing = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    textureHeader = {
                        order = 20,
                        type = "header",
                        name = "Textures & Colors",
                    },
                    statusBarTexture = {
                        order = 21,
                        type = "select",
                        name = "Status Bar Texture",
                        dialogControl = "LSM30_Statusbar",
                        values = LSM:HashTable("statusbar"),
                        get = function() return E.db.thingsUI.buffBars.statusBarTexture end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.statusBarTexture = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    useClassColor = {
                        order = 22,
                        type = "toggle",
                        name = "Use Class Color",
                        desc = "Color the bar based on your class.",
                        get = function() return E.db.thingsUI.buffBars.useClassColor end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.useClassColor = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    customColor = {
                        order = 23,
                        type = "color",
                        name = "Custom Bar Color",
                        desc = "Custom color when not using class color.",
                        hasAlpha = false,
                        disabled = function() return E.db.thingsUI.buffBars.useClassColor end,
                        get = function()
                            local c = E.db.thingsUI.buffBars.customColor
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b)
                            E.db.thingsUI.buffBars.customColor = { r = r, g = g, b = b }
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    fontHeader = {
                        order = 30,
                        type = "header",
                        name = "Font",
                    },
                    font = {
                        order = 31,
                        type = "select",
                        name = "Font",
                        dialogControl = "LSM30_Font",
                        values = LSM:HashTable("font"),
                        get = function() return E.db.thingsUI.buffBars.font end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.font = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    fontSize = {
                        order = 32,
                        type = "range",
                        name = "Font Size",
                        min = 8, max = 24, step = 1,
                        get = function() return E.db.thingsUI.buffBars.fontSize end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.fontSize = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    fontOutline = {
                        order = 33,
                        type = "select",
                        name = "Font Outline",
                        values = {
                            ["NONE"] = "None",
                            ["OUTLINE"] = "Outline",
                            ["THICKOUTLINE"] = "Thick Outline",
                            ["MONOCHROME"] = "Monochrome",
                        },
                        get = function() return E.db.thingsUI.buffBars.fontOutline end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.fontOutline = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    iconHeader = {
                        order = 40,
                        type = "header",
                        name = "Icon",
                    },
                    iconEnabled = {
                        order = 41,
                        type = "toggle",
                        name = "Show Icon",
                        desc = "Display the spell icon next to the bar.",
                        get = function() return E.db.thingsUI.buffBars.iconEnabled end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.iconEnabled = value
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    anchorHeader = {
                        order = 50,
                        type = "header",
                        name = "Anchor Settings",
                    },
                    anchorEnabled = {
                        order = 51,
                        type = "toggle",
                        name = "Enable Anchoring",
                        desc = "Anchor the buff bar container to another frame.",
                        get = function() return E.db.thingsUI.buffBars.anchorEnabled end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorEnabled = value
                            TUI:UpdateBuffBars()
                        end,
                    },
                    anchorFrame = {
                        order = 52,
                        type = "input",
                        name = "Anchor Frame",
                        desc = "Name of the frame to anchor to (e.g., ElvUF_Player, EssentialCooldownViewer).",
                        width = "double",
                        get = function() return E.db.thingsUI.buffBars.anchorFrame end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorFrame = value
                            TUI:UpdateBuffBars()
                        end,
                        disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                    },
                    anchorPoint = {
                        order = 53,
                        type = "select",
                        name = "Point",
                        desc = "The point on the buff bars to anchor.",
                        values = {
                            ["TOP"] = "TOP",
                            ["BOTTOM"] = "BOTTOM",
                            ["LEFT"] = "LEFT",
                            ["RIGHT"] = "RIGHT",
                            ["CENTER"] = "CENTER",
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return E.db.thingsUI.buffBars.anchorPoint end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorPoint = value
                            TUI:UpdateBuffBars()
                        end,
                        disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                    },
                    anchorRelativePoint = {
                        order = 54,
                        type = "select",
                        name = "Relative Point",
                        desc = "The point on the target frame to anchor to.",
                        values = {
                            ["TOP"] = "TOP",
                            ["BOTTOM"] = "BOTTOM",
                            ["LEFT"] = "LEFT",
                            ["RIGHT"] = "RIGHT",
                            ["CENTER"] = "CENTER",
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return E.db.thingsUI.buffBars.anchorRelativePoint end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorRelativePoint = value
                            TUI:UpdateBuffBars()
                        end,
                        disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                    },
                    anchorXOffset = {
                        order = 55,
                        type = "range",
                        name = "X Offset",
                        min = -500, max = 500, step = 1,
                        get = function() return E.db.thingsUI.buffBars.anchorXOffset end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorXOffset = value
                            TUI:UpdateBuffBars()
                        end,
                        disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                    },
                    anchorYOffset = {
                        order = 56,
                        type = "range",
                        name = "Y Offset",
                        min = -500, max = 500, step = 1,
                        get = function() return E.db.thingsUI.buffBars.anchorYOffset end,
                        set = function(_, value)
                            E.db.thingsUI.buffBars.anchorYOffset = value
                            TUI:UpdateBuffBars()
                        end,
                        disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                    },
                },
            },
            
            -------------------------------------------------
            -- CLUSTER POSITIONING TAB
            -------------------------------------------------
            clusterPositioningTab = {
                order = 30,
                type = "group",
                name = "Cluster Positioning",
                args = {
                    header = {
                        order = 1,
                        type = "header",
                        name = "Dynamic Cooldown Cluster Positioning",
                    },
                    description = {
                        order = 2,
                        type = "description",
                        name = "Anchor ElvUI unit frames to the Essential Cooldown Viewer.\n\nWhen enabled:\n• ElvUF_Player anchors to the left\n• ElvUF_Target anchors to the right\n• ElvUF_TargetTarget anchors to Target\n• ElvUF_Target_CastBar anchors below Target\n\n|cFFFF4040Warning:|r This overrides ElvUI's unit frame positioning!\n\n",
                    },
                    enabled = {
                        order = 3,
                        type = "toggle",
                        name = "Enable Cluster Positioning",
                        desc = "Anchor unit frames to the Essential Cooldown Viewer.",
                        width = "full",
                        get = function() return E.db.thingsUI.clusterPositioning.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.enabled = value
                            TUI:UpdateClusterPositioning()
                        end,
                    },
                    recalculate = {
                        order = 4,
                        type = "execute",
                        name = "Recalculate Now",
                        desc = "Manually trigger repositioning.",
                        func = function() TUI:RecalculateCluster() end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    
                    iconSettingsHeader = {
                        order = 10,
                        type = "header",
                        name = "Icon Settings",
                    },
                    essentialIconWidth = {
                        order = 11,
                        type = "range",
                        name = "Essential Icon Width",
                        desc = "Width of Essential Cooldown icons.",
                        min = 20, max = 80, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.essentialIconWidth end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.essentialIconWidth = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    utilityIconWidth = {
                        order = 12,
                        type = "range",
                        name = "Utility Icon Width",
                        desc = "Width of Utility Cooldown icons (usually smaller).",
                        min = 15, max = 60, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.utilityIconWidth end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.utilityIconWidth = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    accountForUtility = {
                        order = 13,
                        type = "toggle",
                        name = "Account for Utility Overflow",
                        desc = "Expand cluster width if Utility icons extend past Essential.",
                        get = function() return E.db.thingsUI.clusterPositioning.accountForUtility end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.accountForUtility = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    yOffset = {
                        order = 14,
                        type = "range",
                        name = "Y Offset",
                        desc = "Vertical offset for all unit frames.",
                        min = -100, max = 100, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.yOffset end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.yOffset = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    
                    playerHeader = {
                        order = 20,
                        type = "header",
                        name = "Player Frame",
                    },
                    playerEnabled = {
                        order = 21,
                        type = "toggle",
                        name = "Position Player Frame",
                        desc = "Anchor ElvUF_Player to the left of Essential.",
                        get = function() return E.db.thingsUI.clusterPositioning.playerFrame.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.playerFrame.enabled = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    playerGap = {
                        order = 22,
                        type = "range",
                        name = "Player Gap",
                        desc = "Gap between player frame and Essential.",
                        min = 0, max = 50, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.playerFrame.gap end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.playerFrame.gap = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.playerFrame.enabled end,
                    },
                    
                    targetHeader = {
                        order = 30,
                        type = "header",
                        name = "Target Frame",
                    },
                    targetEnabled = {
                        order = 31,
                        type = "toggle",
                        name = "Position Target Frame",
                        desc = "Anchor ElvUF_Target to the right of Essential.",
                        get = function() return E.db.thingsUI.clusterPositioning.targetFrame.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetFrame.enabled = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    targetGap = {
                        order = 32,
                        type = "range",
                        name = "Target Gap",
                        desc = "Gap between target frame and Essential.",
                        min = 0, max = 50, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.targetFrame.gap end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetFrame.gap = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetFrame.enabled end,
                    },
                    
                    totHeader = {
                        order = 40,
                        type = "header",
                        name = "Target of Target Frame",
                    },
                    totEnabled = {
                        order = 41,
                        type = "toggle",
                        name = "Position TargetTarget Frame",
                        desc = "Anchor ElvUF_TargetTarget to the target frame.",
                        get = function() return E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    totGap = {
                        order = 42,
                        type = "range",
                        name = "ToT Gap",
                        desc = "Gap between TargetTarget and Target frame.",
                        min = 0, max = 50, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.targetTargetFrame.gap end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetTargetFrame.gap = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled end,
                    },
                    
                    castBarHeader = {
                        order = 50,
                        type = "header",
                        name = "Target Cast Bar",
                    },
                    castBarEnabled = {
                        order = 51,
                        type = "toggle",
                        name = "Position Target CastBar",
                        desc = "Anchor ElvUF_Target_CastBar below the target frame.",
                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetCastBar.enabled = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    castBarGap = {
                        order = 52,
                        type = "range",
                        name = "CastBar Y Gap",
                        desc = "Vertical gap between Target frame and CastBar.",
                        min = 0, max = 50, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.gap end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetCastBar.gap = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                    },
                    castBarXOffset = {
                        order = 53,
                        type = "range",
                        name = "CastBar X Offset",
                        desc = "Horizontal offset for CastBar.",
                        min = -100, max = 100, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.xOffset end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.targetCastBar.xOffset = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                    },
                    
                    debugHeader = {
                        order = 60,
                        type = "header",
                        name = "Debug Info",
                    },
                    currentLayout = {
                        order = 61,
                        type = "description",
                        name = function()
                            local essentialCount = 0
                            if EssentialCooldownViewer then
                                for _, child in ipairs({ EssentialCooldownViewer:GetChildren() }) do
                                    if child and child:IsShown() then essentialCount = essentialCount + 1 end
                                end
                            end
                            local utilityCount = 0
                            if UtilityCooldownViewer then
                                for _, child in ipairs({ UtilityCooldownViewer:GetChildren() }) do
                                    if child and child:IsShown() then utilityCount = utilityCount + 1 end
                                end
                            end
                            return string.format("|cFFFFFF00Essential Icons:|r %d\n|cFFFFFF00Utility Icons:|r %d", essentialCount, utilityCount)
                        end,
                    },
                },
            },

            -------------------------------------------------
            -- BCDM ANCHORING TAB
            -------------------------------------------------
            bcdmAnchorsTab = {
                order = 40,
                type = "group",
                name = "Anchor BCDM Stuff",
                args = {
                    header = {
                        order = 1,
                        type = "header",
                        name = "BetterCooldownManager Anchors",
                    },
                    description = {
                        order = 2,
                        type = "description",
                        name = "Anchor selected BetterCooldownManager frames to ElvUI unit frames (or other frames).\n\n",
                    },
                    enabled = {
                        order = 3,
                        type = "toggle",
                        name = "Enable BCDM Anchoring",
                        width = "full",
                        get = function() return E.db.thingsUI.bcdmAnchors.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.bcdmAnchors.enabled = value
                            TUI:UpdateBCDMAnchors()
                        end,
                    },
                    throttle = {
                        order = 4,
                        type = "range",
                        name = "Update Throttle",
                        desc = "0 = no polling (recommended). Set > 0 only if BCDM keeps moving frames on its own.",
                        min = 0, max = 1.0, step = 0.05,
                        get = function() return E.db.thingsUI.bcdmAnchors.throttle or 0 end,
                        set = function(_, value)
                            E.db.thingsUI.bcdmAnchors.throttle = value
                        end,
                        disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
                    },
                    recalc = {
                        order = 5,
                        type = "execute",
                        name = "Re-anchor now",
                        func = function() TUI:UpdateBCDMAnchors() end,
                        disabled = function() return not E.db.thingsUI.bcdmAnchors.enabled end,
                    },
                    spacer = { order = 6, type = "description", name = "\n" },

                    customCooldownViewer = {
                        order = 10,
                        type = "group",
                        name = "CustomCooldownViewer",
                        inline = true,
                        args = TUI:BCDMFrameOptions("BCDM_CustomCooldownViewer"),
                    },

                    additionalCustomCooldownViewer = {
                        order = 20,
                        type = "group",
                        name = "AdditionalCustomCooldownViewer",
                        inline = true,
                        args = TUI:BCDMFrameOptions("BCDM_AdditionalCustomCooldownViewer"),
                    },

                    customItemBar = {
                        order = 30,
                        type = "group",
                        name = "CustomItemBar",
                        inline = true,
                        args = TUI:BCDMFrameOptions("BCDM_CustomItemBar"),
                    },

                    trinketBar = {
                        order = 40,
                        type = "group",
                        name = "TrinketBar",
                        inline = true,
                        args = TUI:BCDMFrameOptions("BCDM_TrinketBar"),
                    },

                    customItemSpellBar = {
                        order = 50,
                        type = "group",
                        name = "CustomItemSpellBar",
                        inline = true,
                        args = TUI:BCDMFrameOptions("BCDM_CustomItemSpellBar"),
                    },
                },
            },
        },
    }
end

-------------------------------------------------
-- PROFILE HOOKS
-------------------------------------------------
function TUI:ProfileUpdate()
    wipe(skinnedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateClusterPositioning()
    self:UpdateBCDMAnchors()
end

local function OnProfileChanged()
    TUI:ProfileUpdate()
end

hooksecurefunc(E, "UpdateAll", OnProfileChanged)

-- Initialize when ElvUI is ready
E:RegisterModule(TUI:GetName())
