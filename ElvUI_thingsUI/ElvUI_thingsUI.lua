local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local LSM = E.Libs.LSM
local addon, ns = ...
local TUI = E:NewModule("thingsUI", "AceHook-3.0", "AceEvent-3.0")
ns.TUI = TUI
TUI.version = "2.1.0" 
TUI.name = "thingsUI"

local SHARED_ANCHOR_VALUES = {
    ["ElvUF_Player"] = "ElvUI Player Frame",
    ["ElvUF_Target"] = "ElvUI Target Frame",
    ["ElvUF_Player_ClassBar"] = "ElvUI Class Bar",
    ["EssentialCooldownViewer"] = "Essential Cooldowns",
    ["UtilityCooldownViewer"] = "Utility Cooldowns",
    ["BCDM_Power"] = "BCDM Power Bar",
    ["BCDM_CastBar"] = "BCDM Cast Bar",
    ["UIParent"] = "Screen (UIParent)",
    ["CUSTOM"] = "|cFFFFFF00Custom Frame...|r",
}

local SPECIAL_BAR_ANCHOR_VALUES = {}
for k, v in pairs(SHARED_ANCHOR_VALUES) do SPECIAL_BAR_ANCHOR_VALUES[k] = v end
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar1"] = "TUI Special Bar 1"
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar2"] = "TUI Special Bar 2"
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar3"] = "TUI Special Bar 3"

-- Defaults
P["thingsUI"] = {
    verticalBuffs = false,
    buffBars = {
        enabled = false,
        growthDirection = "UP", 
        width = 240,
        height = 23,
        spacing = 1,
        statusBarTexture = "ElvUI Blank",
        font = "Expressway",
        fontSize = 14,
        fontOutline = "OUTLINE",
        iconEnabled = true,
        iconSpacing = 1,    
        iconZoom = 0.1,     
        inheritWidth = true,
        inheritWidthOffset = 0,
        stackFontSize = 14  ,                                                                                                                                                     
        stackFontOutline = "OUTLINE",
        stackPoint = "CENTER",
        stackAnchor = "ICON", 
        stackXOffset = 0,
        stackYOffset = 0,
        namePoint = "LEFT",
        nameXOffset = 2,
        nameYOffset = 0,
        durationPoint = "RIGHT",
        durationXOffset = -4,
        durationYOffset = 0,
        backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        useClassColor = true,
        customColor = { r = 0.2, g = 0.6, b = 1.0 },
        anchorEnabled = true,
        anchorFrame = "ElvUF_Player",
        anchorPoint = "BOTTOM",
        anchorRelativePoint = "TOP",
        anchorXOffset = 0,
        anchorYOffset = 50,
    },
    clusterPositioning = {
        enabled = false,
        essentialIconWidth = 42,
        essentialIconPadding = 1,
        utilityIconWidth = 35,
        utilityIconPadding = 1,
        accountForUtility = true,
        utilityThreshold = 3,
        utilityOverflowOffset = 25,
        yOffset = 0,
        frameGap = 20,
        playerFrame = { enabled = true },
        targetFrame = { enabled = true },
        targetTargetFrame = { enabled = true, gap = 1 },
        targetCastBar = { enabled = true, gap = 1, xOffset = 0 },
        additionalPowerBar = { enabled = false, gap = 1, xOffset = 0 },
    },
    specialBars = { specs = {} },
}

local clusterOriginalPoints = {}

local function SavePoints(frame)
    if not frame or clusterOriginalPoints[frame] then return end
    local pts = {}
    for i = 1, frame:GetNumPoints() do
        local p, rel, rp, x, y = frame:GetPoint(i)
        pts[i] = { p, rel, rp, x, y }
    end
    clusterOriginalPoints[frame] = pts
end

local function RestoreClusterPoints()
    for frame, pts in pairs(clusterOriginalPoints) do
        if frame and frame.ClearAllPoints then
            frame:ClearAllPoints()
            for i = 1, #pts do
                local p, rel, rp, x, y = unpack(pts[i])
                frame:SetPoint(p, rel, rp, x, y)
            end
        end
    end
    wipe(clusterOriginalPoints)
end

local pendingClusterRestore = false

local function RequestRestoreClusterPoints()
    if InCombatLockdown() then
        pendingClusterRestore = true
        return
    end
    pendingClusterRestore = false
    RestoreClusterPoints()
end

-------------------------------------------------
-- SPECIAL BARS Defaults
-------------------------------------------------

local SPECIAL_BAR_DEFAULTS = {
    enabled = false,
    spellName = "",
    width = 230,
    inheritWidth = false,
    inheritWidthOffset = 0,
    height = 23,
    inheritHeight = false,
    inheritHeightOffset = 0,
    statusBarTexture = "ElvUI Blank",
    font = "Expressway",
    fontSize = 14,
    fontOutline = "OUTLINE",
    useClassColor = true,
    customColor = { r = 0.2, g = 0.6, b = 1.0 },
    backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
    showBackdrop = false,
    backdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 },
    iconEnabled = true,
    iconSpacing = 1,
    iconZoom = 0.1,
    showStacks = true,
    stackFontSize = 14,
    stackFontOutline = "OUTLINE",
    stackPoint = "CENTER",
    stackAnchor = "ICON", 
    stackXOffset = 0,
    stackYOffset = 0,
    showName = true,
    namePoint = "LEFT",
    nameXOffset = 2,
    nameYOffset = 0,
    showDuration = true,
    durationPoint = "RIGHT",
    durationXOffset = -4,
    durationYOffset = 0,
    anchorMode = "UIParent",
    anchorFrame = "BCDM_CastBar",
    anchorPoint = "CENTER",
    anchorRelativePoint = "CENTER",
    anchorXOffset = 0,
    anchorYOffset = 0,
}

-------------------------------------------------
-- BURST MODE CONTROLLER
-------------------------------------------------
-- This system replaces constant OnUpdate with short bursts of activity
-- triggered by events 
-- This should help with your CPU thing my guy, lmk if somethings off /D.G

local BURST_DURATION = 1.0 -- How long to run update loop after an event (seconds)
local UPDATE_THROTTLE = 0.05 -- How often to update during a burst

local burstEndTime = 0
local isBursting = false
local mainUpdateFrame = CreateFrame("Frame")

-- Forward declarations
local PositionBuffsVertically
local UpdateBuffBarPositions
local UpdateSpecialBarSlot
local GetSpecialBarDB
local ScanAndHookCDMChildren
local yoinkedBars = {}

local function MainOnUpdate(self, elapsed)
    local currentTime = GetTime()
    
    -- If burst is over, stop the script to save CPU
    if currentTime > burstEndTime then
        self:SetScript("OnUpdate", nil)
        isBursting = false
        return
    end
    
    -- Throttle execution
    if self.nextUpdate and currentTime < self.nextUpdate then return end
    self.nextUpdate = currentTime + UPDATE_THROTTLE
    
    -- --- EXECUTE UPDATES ---
    
    -- 1. Vertical Buffs
    if E.db.thingsUI.verticalBuffs then
        pcall(PositionBuffsVertically)
    end
    -- Prewipe SB yoinks to ensure they are not accidentally re-skinned as normal bars in the next step    
    if E.db.thingsUI.specialBars then 
        wipe(yoinkedBars) 
    end
    
    -- 2. Special Bars 
    -- We process this BEFORE normal bars to ensure yoinked bars are marked
    if E.db.thingsUI.specialBars then
        local specDB = GetSpecialBarDB()
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" then
                pcall(UpdateSpecialBarSlot, barKey)
            end
        end
    end
    
    -- 3. Normal Buff Bars (Skin Logic)
    -- This now ONLY handles normal bars, avoiding double-work
    if E.db.thingsUI.buffBars and E.db.thingsUI.buffBars.enabled then
        pcall(UpdateBuffBarPositions)
    end
end

function TUI:TriggerBurst()
    -- OPTIMIZATION: Scan for new children ONCE at the start of a burst,
    -- instead of every frame inside MainOnUpdate.
    ScanAndHookCDMChildren()
    
    burstEndTime = GetTime() + BURST_DURATION
    if not isBursting then
        isBursting = true
        mainUpdateFrame:SetScript("OnUpdate", MainOnUpdate)
    end
end

-------------------------------------------------
-- VERTICAL BUFF ICONS
-------------------------------------------------
local reusableIconTable = {}

PositionBuffsVertically = function()
    if not BuffIconCooldownViewer then return end
    
    wipe(reusableIconTable)
    for _, childFrame in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
        if childFrame and childFrame.Icon and childFrame:IsShown() then
            table.insert(reusableIconTable, childFrame)
        end
    end

    if #reusableIconTable == 0 then return end

    table.sort(reusableIconTable, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local iconSize = reusableIconTable[1]:GetWidth()
    local iconSpacing = BuffIconCooldownViewer.childYPadding or 0
    
    for index, iconFrame in ipairs(reusableIconTable) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("TOP", BuffIconCooldownViewer, "TOP", 0, -((index - 1) * (iconSize + iconSpacing)))
    end
end

function TUI:UpdateVerticalBuffs()
    -- Only need to trigger a single update/burst when settings change
    if E.db.thingsUI.verticalBuffs then
        self:TriggerBurst()
    end
end

-------------------------------------------------
-- BUFF BAR SKINNING
-------------------------------------------------
local skinnedBars = {} 

local function GetClassColor()
    local classColor = E:ClassColor(E.myclass, true)
    return classColor.r, classColor.g, classColor.b
end

local function SkinBuffBar(childFrame)
    if not childFrame then return end
    pcall(function()
        local db = E.db.thingsUI.buffBars
        local bar = childFrame.Bar
        local icon = childFrame.Icon
        if not bar then return end
        
        -- Sizing
        local effectiveWidth = db.width
        if db.inheritWidth and db.anchorEnabled then
            local anchorFrame = _G[db.anchorFrame]
            if anchorFrame then effectiveWidth = (anchorFrame:GetWidth() or 0) + (db.inheritWidthOffset or 0) end
        end
        childFrame:SetSize(effectiveWidth, db.height)
        
        -- Main Backdrop
        if not childFrame.tuiBackdrop then
            childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
            childFrame.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.7)
            childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
            childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)
        end

        local barOffset = 0
        local height = db.height

        -- Icon Skinning
        if icon and icon.Icon then
            if db.iconEnabled then
                icon:Show()
                icon:SetSize(height, height)
                icon.Icon:SetTexCoord(db.iconZoom, 1-db.iconZoom, db.iconZoom, 1-db.iconZoom)
                
                if not icon.tuiBackdrop then
                    icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
                    icon.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
                    icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
                    icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
                end
                icon.tuiBackdrop:Show()
                icon.tuiBackdrop:SetAllPoints(icon)
                icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
                
                -- Position Icon
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
                
                barOffset = height + (db.iconSpacing or 3)
            else 
                icon:Hide() 
            end
        end
        
        -- Bar Backdrop Positioning
        childFrame.tuiBackdrop:Show()
        childFrame.tuiBackdrop:ClearAllPoints()
        childFrame.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
        childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)

        -- Bar Positioning (Inset)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", childFrame.tuiBackdrop, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
        
        -- Skin Bar
        local texture = LSM:Fetch("statusbar", db.statusBarTexture)
        bar:SetStatusBarTexture(texture)
        if db.useClassColor then
            bar:SetStatusBarColor(GetClassColor())
        else
            bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b)
        end
        
        -- Clean up
        if bar.BarBG then bar.BarBG:SetAlpha(0) end
        if bar.Pip then bar.Pip:SetAlpha(0) end
        
        -- Fonts
        local font = LSM:Fetch("font", db.font)
        if bar.Name then
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 4, db.nameYOffset or 0)
        end
        if bar.Duration then
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
        end
        skinnedBars[childFrame] = true
    end)
end

local function IsBarActive(childFrame)
    if not childFrame then return false end
    if not childFrame:IsShown() then return false end
    if not childFrame.Bar then return false end
    return true
end

local function AnchorBuffBarContainer()
    if not BuffBarCooldownViewer then return end
    local db = E.db.thingsUI.buffBars
    if not db.anchorEnabled then return end
    local anchorFrame = _G[db.anchorFrame]
    if not anchorFrame then return end
    
    pcall(function()
        BuffBarCooldownViewer:ClearAllPoints()
        BuffBarCooldownViewer:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
    end)
end

local reusableBarTable = {}


UpdateBuffBarPositions = function()
    if not BuffBarCooldownViewer then return end
    local db = E.db.thingsUI.buffBars
    wipe(reusableBarTable)
    
    -- Gather valid bars
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return end
    
    for _, childFrame in ipairs(children) do
        -- NOTE: We now skip any checks for special bars here. 
        -- UpdateSpecialBarSlot (called before this in MainOnUpdate) has already flagged them in 'yoinkedBars'.
        if childFrame and IsBarActive(childFrame) and not yoinkedBars[childFrame] then
            SkinBuffBar(childFrame)
            table.insert(reusableBarTable, childFrame)
        end
    end
    
    if #reusableBarTable == 0 then return end
    
    pcall(function()
        table.sort(reusableBarTable, function(a, b)
            return (a.layoutIndex or 0) < (b.layoutIndex or 0)
        end)
    end)
    
    local spacing = db.spacing
    local height = db.height
    
    for index, barFrame in ipairs(reusableBarTable) do
        barFrame:ClearAllPoints()
        if db.growthDirection == "DOWN" then
            barFrame:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, -((index - 1) * (height + spacing)))
        else 
            barFrame:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, ((index - 1) * (height + spacing)))
        end
    end
    
    AnchorBuffBarContainer()
end

-- Event Listener for Burst Triggers
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

eventFrame:SetScript("OnEvent", function()
  local db = E.db.thingsUI
  if db.verticalBuffs or (db.buffBars and db.buffBars.enabled) or db.specialBars then
    TUI:TriggerBurst()
  end
end)

function TUI:UpdateBuffBars()
    -- Trigger an immediate update
    if E.db.thingsUI.buffBars.enabled then
        wipe(skinnedBars)
        self:TriggerBurst()
    end
end

-------------------------------------------------
-- SPECIAL BARS
-------------------------------------------------
local specialBarState = {}
local knownCDMChildren = {}
local hookedCDMChildren = {}

local function CleanString(str)
    if not str then return "" end
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    str = str:match("^%s*(.-)%s*$")
    return str
end

local function OnCDMChildShown(childFrame)
    TUI:TriggerBurst()
end

ScanAndHookCDMChildren = function()
    if not BuffBarCooldownViewer then return end
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return end
    
    for _, childFrame in ipairs(children) do
        if childFrame and not hookedCDMChildren[childFrame] then
            hookedCDMChildren[childFrame] = true
            knownCDMChildren[childFrame] = true
            pcall(function()
                childFrame:HookScript("OnShow", OnCDMChildShown)
            end)
            -- If we found a new child that is already shown, ensure we trigger a burst
            if childFrame:IsShown() then 
                -- We are likely already inside TriggerBurst calling this, so setting 
                -- isBursting=true is fine, it will just extend/refresh.
            end
        end
    end
end

local function ResolveAnchorFrame(db)
    local mode = db.anchorMode or db.anchorFrame or "ElvUF_Player"
    if mode == "CUSTOM" then return db.anchorFrame or "ElvUF_Player" end
    return mode
end

local function FindBarBySpellName(spellName)
    if not BuffBarCooldownViewer or not spellName or spellName == "" then return nil end
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return nil end
    
    local targetName = CleanString(spellName)
    
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.Bar then
            local match = false
            if childFrame.Bar.Name then
                pcall(function()
                    local barText = CleanString(childFrame.Bar.Name:GetText())
                    if barText and barText == targetName then match = true end
                end)
            end
            if not match and childFrame.auraSpellID then
                pcall(function()
                    local targetID = tonumber(targetName)
                    if targetID and targetID == childFrame.auraSpellID then
                        match = true
                    else
                        local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(childFrame.auraSpellID)
                        local resolvedName = spellInfo and spellInfo.name or GetSpellInfo(childFrame.auraSpellID)
                        if resolvedName and CleanString(resolvedName) == targetName then match = true end
                    end
                end)
            end
            if match then return childFrame end
        end
    end
    return nil
end

local function GetOrCreateWrapper(barKey)
    if specialBarState[barKey] and specialBarState[barKey].wrapper then
        return specialBarState[barKey].wrapper
    end
    local frameName = "TUI_SpecialBar_" .. barKey
    local wrapper = _G[frameName] or CreateFrame("Frame", frameName, UIParent)
    wrapper:SetFrameStrata("MEDIUM")
    wrapper:SetFrameLevel(10)
    
    if not wrapper.backdrop then
        local bd = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
        bd:SetAllPoints(wrapper)
        bd:SetFrameLevel(wrapper:GetFrameLevel())
        bd:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        bd:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        bd:SetBackdropBorderColor(0, 0, 0, 0.8)
        bd:Hide()
        wrapper.backdrop = bd
    end
    wrapper:Show()
    return wrapper
end

local function ReleaseSpecialBar(barKey)
    local state = specialBarState[barKey]
    if not state then return end
    
    if state.childFrame and state.originalParent then
        pcall(function()
            state.childFrame:SetParent(state.originalParent)
            yoinkedBars[state.childFrame] = nil
        end)
    end
    
    if state.wrapper then
        if state.wrapper.backdrop then state.wrapper.backdrop:Hide() end
        state.wrapper:Hide()
    end
    specialBarState[barKey] = nil
end

local function StyleSpecialBar(childFrame, db)
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    if not bar then return end
    
    -- Sizing & Backdrops (Split logic from 2.0.2)
    if not childFrame.tuiBackdrop then
        childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        childFrame.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
    end
    childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.7)
    childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
    childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)

    local height = db.height
    local barOffset = 0

    if db.iconEnabled and icon then
        icon:Show()
        icon:SetSize(height, height)
        if icon.Icon then
            icon.Icon:SetTexCoord(db.iconZoom or 0.1, 1-(db.iconZoom or 0.1), db.iconZoom or 0.1, 1-(db.iconZoom or 0.1))
        end
        
        if not icon.tuiBackdrop then
            icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
            icon.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
            icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        icon.tuiBackdrop:Show()
        icon.tuiBackdrop:SetAllPoints(icon)
        icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
        
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        barOffset = height + (db.iconSpacing or 3)
    elseif icon then
        icon:Hide()
        barOffset = 0
    end
    
    childFrame.tuiBackdrop:Show()
    childFrame.tuiBackdrop:ClearAllPoints()
    childFrame.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
    childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)

    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", childFrame.tuiBackdrop, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
    
    local font = LSM:Fetch("font", db.font)
    if bar.Name then
        if db.showName then
            bar.Name:Show()
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:ClearAllPoints()
            bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 4, db.nameYOffset or 0)
        else bar.Name:Hide() end
    end
    
    if bar.Duration then
        if db.showDuration then
            bar.Duration:Show()
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:ClearAllPoints()
            bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
        else bar.Duration:Hide() end
    end
    
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then bar:SetStatusBarColor(GetClassColor()) else bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b) end
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
end

UpdateSpecialBarSlot = function(barKey)
    local db = GetSpecialBarSlotDB(barKey)
    if not db or not db.enabled or not db.spellName or db.spellName == "" then
        ReleaseSpecialBar(barKey)
        return
    end
    
    local state = specialBarState[barKey]
    local childFrame
    local resolvedAnchor = ResolveAnchorFrame(db)
    local anchorFrame = _G[resolvedAnchor]
    
    local effectiveWidth = db.width
    if db.inheritWidth and anchorFrame then
        local aw = anchorFrame:GetWidth()
        if aw and aw > 0 then effectiveWidth = aw + (db.inheritWidthOffset or 0) end
    end

    local effectiveHeight = db.height
    if db.inheritHeight and anchorFrame then
        local ah = anchorFrame:GetHeight()
        if ah and ah > 0 then effectiveHeight = ah + (db.inheritHeightOffset or 0) end
        db.height = effectiveHeight
    end
    
    if state and state.childFrame then
        local stillValid = false
        pcall(function() if state.childFrame.Bar and state.childFrame.Bar.Name then stillValid = true end end)
        if stillValid then
            childFrame = state.childFrame
            yoinkedBars[childFrame] = true
        else
            if state.childFrame then yoinkedBars[state.childFrame] = nil end
            if state.wrapper then state.wrapper:Hide() end
            specialBarState[barKey] = nil
            state = nil
        end
    end
    
    if not childFrame then
        childFrame = FindBarBySpellName(db.spellName)
    end
    
    local wrapper = GetOrCreateWrapper(barKey)
    wrapper:SetSize(effectiveWidth , effectiveHeight)
    pcall(function()
        if anchorFrame then
            wrapper:ClearAllPoints()
            wrapper:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
        end
    end)
    
-- Determine active state early
local isActive = false
pcall(function()
    if childFrame then isActive = childFrame:IsShown() end
end)

-- Placeholder when missing OR inactive
if (not childFrame) or (not isActive) then
    if db.showBackdrop and wrapper.backdrop then
        wrapper:Show()
        wrapper.backdrop:Show()

        local bc = db.backdropColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
        wrapper.backdrop:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)

        wrapper.backdrop:ClearAllPoints()
        wrapper.backdrop:SetAllPoints(wrapper)

    else
        if wrapper.backdrop then wrapper.backdrop:Hide() end
        wrapper:Hide()
    end

    if state and state.childFrame then
    yoinkedBars[state.childFrame] = nil
    if state.originalParent then
        pcall(function()
            state.childFrame:SetParent(state.originalParent)
        end)
    end
    state.childFrame = nil
end

    if not specialBarState[barKey] then
        specialBarState[barKey] = { wrapper = wrapper }
    end
    return
end

-- Active: proceed with yoink/state
if wrapper.backdrop then wrapper.backdrop:Hide() end

    if not state or state.childFrame ~= childFrame then
        if state and state.childFrame and state.childFrame ~= childFrame then
            yoinkedBars[state.childFrame] = nil
            if state.originalParent then pcall(function() state.childFrame:SetParent(state.originalParent) end) end
        end
        specialBarState[barKey] = {
            childFrame = childFrame,
            originalParent = childFrame:GetParent(),
            wrapper = wrapper,
        }
        state = specialBarState[barKey]
    end

    yoinkedBars[childFrame] = true
    
    pcall(function()
        if childFrame:GetParent() ~= wrapper then childFrame:SetParent(wrapper) end
        childFrame:SetSize(effectiveWidth, effectiveHeight)
        childFrame:ClearAllPoints()
        childFrame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    end)
    
    pcall(StyleSpecialBar, childFrame, db)
    wrapper:Show()
end

function TUI:UpdateSpecialBars()
    if not E.db.thingsUI.specialBars then return end
    self:TriggerBurst()
end

-------------------------------------------------
-- CLUSTER POSITIONING
-------------------------------------------------

local function CountVisibleChildren(frame)
    if not frame then return 0 end
    local count = 0
    for _, child in ipairs({ frame:GetChildren() }) do
        if child and child:IsShown() then count = count + 1 end
    end
    return count
end

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

local function UpdateClusterPositioning()
    local db = E.db.thingsUI.clusterPositioning

    -- If cluster is disabled, restore anything we previously moved
    if not db.enabled then
        RestoreClusterPoints()
        return
    end

    -- If we can't move things now, don't fight combat lockdown
    if InCombatLockdown() then return end
    if not EssentialCooldownViewer then return end

    local effectiveWidth, essentialCount, utilityCount, utilityOverflow = CalculateEffectiveWidth()
    local yOffset = db.yOffset
    local sideOverflow = utilityOverflow / 2

    if db.playerFrame.enabled then
        local playerFrame = _G["ElvUF_Player"]
        if playerFrame then
            SavePoints(playerFrame)
            playerFrame:ClearAllPoints()
            playerFrame:SetPoint("RIGHT", EssentialCooldownViewer, "LEFT", -(db.frameGap + sideOverflow), yOffset)
        end
    end

    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            SavePoints(targetFrame)
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", EssentialCooldownViewer, "RIGHT", db.frameGap + sideOverflow, yOffset)
        end
    end

    if db.targetTargetFrame.enabled then
        local totFrame = _G["ElvUF_TargetTarget"]
        local targetFrame = _G["ElvUF_Target"]
        if totFrame and targetFrame then
            SavePoints(totFrame)
            totFrame:ClearAllPoints()
            totFrame:SetPoint("LEFT", targetFrame, "RIGHT", db.targetTargetFrame.gap, 0)
        end
    end

    if db.targetCastBar.enabled then
        local targetFrame = _G["ElvUF_Target"]
        local castBar = _G["ElvUF_Target_CastBar"]
        if targetFrame and castBar then
            local holder = castBar.Holder or castBar
            SavePoints(holder)
            holder:ClearAllPoints()
            holder:SetPoint("TOP", targetFrame, "BOTTOM", db.targetCastBar.xOffset, -db.targetCastBar.gap)
        end
    end

    if db.additionalPowerBar and db.additionalPowerBar.enabled then
        local playerFrame = _G["ElvUF_Player"]
        local powerBar = _G["ElvUF_Player_AdditionalPowerBar"]
        if playerFrame and powerBar then
            SavePoints(powerBar)
            powerBar:ClearAllPoints()
            powerBar:SetPoint("TOP", playerFrame, "BOTTOM", db.additionalPowerBar.xOffset, db.additionalPowerBar.gap)
        end
    end
end

local clusterPending = false

local function RequestClusterUpdate()
    if clusterPending then return end
    clusterPending = true
    C_Timer.After(0, function()
        clusterPending = false
        UpdateClusterPositioning()
    end)
end

local function HookViewer(viewer)
    if not viewer then return end

    -- When viewer appears or wraps rows (size changes), re-evaluate
    viewer:HookScript("OnShow", RequestClusterUpdate)
    viewer:HookScript("OnSizeChanged", RequestClusterUpdate)

    -- When CDM rebuilds layout (e.g. add/remove spells), re-evaluate
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", RequestClusterUpdate)
    end
end

-- We only want to setup hooks once
local clusterHooksSetup = false
local function SetupClusterHooks()
    if clusterHooksSetup then return end
    clusterHooksSetup = true

    -- Catches settings/layout rebuilds
    if CooldownViewerSettings and CooldownViewerSettings.RefreshLayout then
        hooksecurefunc(CooldownViewerSettings, "RefreshLayout", RequestClusterUpdate)
    end

    -- Viewers
    HookViewer(_G.EssentialCooldownViewer)
    HookViewer(_G.UtilityCooldownViewer)
    -- Do an initial update next frame
    RequestClusterUpdate()
end

function TUI:UpdateClusterPositioning()
    if not E.db.thingsUI.clusterPositioning.enabled then return end
    SetupClusterHooks()
    RequestClusterUpdate()
    HookViewer(_G.EssentialCooldownViewer)
    HookViewer(_G.UtilityCooldownViewer)
end

function TUI:RecalculateCluster()
    if InCombatLockdown() then return end
    UpdateClusterPositioning()
    HookViewer(_G.EssentialCooldownViewer)
    HookViewer(_G.UtilityCooldownViewer)
    print("|cFF8080FFthingsUI|r - Cluster positions recalculated.")
end

-- Helper for Special Bar DB (Same as before)
GetSpecialBarDB = function()
    if not E.db.thingsUI.specialBars then E.db.thingsUI.specialBars = { specs = {} } end
    if not E.db.thingsUI.specialBars.specs then E.db.thingsUI.specialBars.specs = {} end
    local specID = GetCurrentSpecID()
    if specID == 0 then specID = 1 end
    local specKey = tostring(specID)
    if not E.db.thingsUI.specialBars.specs[specKey] then
        E.db.thingsUI.specialBars.specs[specKey] = {}
        for _, barKey in ipairs({"bar1", "bar2", "bar3"}) do
            E.db.thingsUI.specialBars.specs[specKey][barKey] = {}
            for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
                if type(v) == "table" then
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = {}
                    for k2, v2 in pairs(v) do E.db.thingsUI.specialBars.specs[specKey][barKey][k][k2] = v2 end
                else
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = v
                end
            end
        end
    end
    return E.db.thingsUI.specialBars.specs[specKey]
end

GetSpecialBarSlotDB = function(barKey)
    local specDB = GetSpecialBarDB()
    if not specDB[barKey] then specDB[barKey] = {} end
    -- Ensure defaults
    for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
        if specDB[barKey][k] == nil then
            if type(v) == "table" then
                specDB[barKey][k] = {}
                for k2, v2 in pairs(v) do specDB[barKey][k][k2] = v2 end
            else
                specDB[barKey][k] = v
            end
        end
    end
    return specDB[barKey]
end

GetCurrentSpecID = function()
    local specIndex = GetSpecialization()
    if specIndex then return GetSpecializationInfo(specIndex) or 0 end
    return 0
end

-------------------------------------------------
-- MODULE INITIALIZATION
-------------------------------------------------

function TUI:FullRefresh()
    wipe(skinnedBars)
    wipe(yoinkedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
end

function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)

    self:FullRefresh()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        self:TriggerBurst()
        self:UpdateClusterPositioning()
        C_Timer.After(2, function()
            self:TriggerBurst()
            self:UpdateClusterPositioning()
        end)
    end)

    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        C_Timer.After(1, function()
            self:FullRefresh()
            self:TriggerBurst()
        end)
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingClusterRestore then
            RequestRestoreClusterPoints()
            -- self:TriggerBurst() --  Don't think we need this here, testing.
            self:UpdateClusterPositioning()
        end
    end)

    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded")
end

-------------------------------------------------
-- SPECIAL BAR CONFIG GENERATOR
-------------------------------------------------
function TUI:SpecialBarOptions(barKey)
    local function get(key) return GetSpecialBarSlotDB(barKey)[key] end
    local function set(key, value) GetSpecialBarSlotDB(barKey)[key] = value; TUI:UpdateSpecialBars() end
    local function setWipe(key, value) GetSpecialBarSlotDB(barKey)[key] = value; wipe(skinnedBars); TUI:UpdateSpecialBars() end
    
    return {
        specInfo = {
            order = 0, type = "description", width = "full",
            name = function()
                local specIndex = GetSpecialization()
                local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "Unknown"
                return "|cFFFFFF00Current spec: " .. specName .. "|r  (settings are saved per spec)"
            end,
        },
        enabled = {
            order = 1, type = "toggle", name = "Enable", width = "full",
            get = function() return get("enabled") end,
            set = function(_, v)
                if not v then ReleaseSpecialBar(barKey) end
                GetSpecialBarSlotDB(barKey).enabled = v
                TUI:UpdateSpecialBars()
            end,
        },
        spellName = {
            order = 2, type = "input", name = "Spell Name", width = "double",
            desc = "Exact spell name as shown in Tracked Bars (e.g., Ironfur, Frenzied Regeneration).",
            get = function() return get("spellName") end,
            set = function(_, v)
                -- Fully release and clear any cached state
                ReleaseSpecialBar(barKey)
                specialBarState[barKey] = nil
                wipe(skinnedBars)
                GetSpecialBarSlotDB(barKey).spellName = v
                -- Delay to let CDM reclaim the released bar
                C_Timer.After(0.15, function()
                    TUI:UpdateSpecialBars()
                end)
            end,
        },
        spellStatus = {
            order = 3, type = "description", width = "full",
            name = function()
                local name = GetSpecialBarSlotDB(barKey).spellName or ""
                if name == "" then return "" end
                if not BuffBarCooldownViewer then return "|cFFFF8800BuffBarCooldownViewer not found — open Cooldown Manager settings to initialize it|r" end
                if InCombatLockdown() then return "|cFFFFFF00Status check unavailable in combat|r" end
                
                -- Force a fresh scan for new CDM children every time this status is checked
                ScanAndHookCDMChildren()
                
                -- Check if this bar is currently yoinked and active
                local state = specialBarState[barKey]
                if state and state.childFrame and state.wrapper then
                    local isShown = false
                    pcall(function() isShown = state.wrapper:IsShown() end)
                    if isShown then
                        return "|cFF00FF00 Active (yoinked from Tracked Bars)|r"
                    end
                end
                
                -- Check all CDM children (including wrappers we may have created)
                local found = false
                local targetName = CleanString(name)
                
                pcall(function()
                    local children = { BuffBarCooldownViewer:GetChildren() }
                    for _, cf in ipairs(children) do
                        local match = false
                        if cf.Bar and cf.Bar.Name then
                            local t = CleanString(cf.Bar.Name:GetText())
                            if t and t == targetName then match = true end
                        end
                        if not match and cf.auraSpellID then
                            local targetID = tonumber(targetName)
                            if targetID and targetID == cf.auraSpellID then match = true end
                        end
                        if match then found = true end
                    end
                end)
                if found then
                    return "|cFF00FF00 Found in Tracked Bars|r"
                end
                
                -- Also check if another special bar already yoinked this spell
                for otherKey, otherState in pairs(specialBarState) do
                    if otherKey ~= barKey and otherState.childFrame then
                        local match = false
                        pcall(function()
                            local t = CleanString(otherState.childFrame.Bar.Name:GetText())
                            if t and t == targetName then match = true end
                        end)
                        if match then
                            return "|cFFFF8800 Found but yoinked by " .. otherKey .. "|r"
                        end
                    end
                end

                return "|cFFFF0000 Not found in Tracked Bars yet|r — Open CDM to force a scan, tab back in and out of this tab to check. Otherwise it's not in the Tracked Bars or may be misspelled. Or doesn't exist"
            end,
        },
        
        layoutHeader = { order = 10, type = "header", name = "Layout" },
        width = {
            order = 11, type = "range", name = "Width", min = 50, max = 500, step = 1,
            get = function() return get("width") end,
            set = function(_, v) setWipe("width", v) end,
            disabled = function() return get("inheritWidth") end,
        },
        inheritWidth = {
            order = 11.5, type = "toggle", name = "Inherit Width from Anchor",
            desc = "Automatically match the width of the anchor frame.",
            get = function() return get("inheritWidth") end,
            set = function(_, v) setWipe("inheritWidth", v) end,
        },
        inheritWidthOffset = {
            order = 11.6, type = "range", name = "Width Nudge",
            desc = "Fine-tune the inherited width.",
            min = -10, max = 10, step = 0.01, bigStep = 0.5,
            get = function() return get("inheritWidthOffset") end,
            set = function(_, v) setWipe("inheritWidthOffset", v) end,
            disabled = function() return not get("inheritWidth") end,
        },
        height = {
            order = 12, type = "range", name = "Height", min = 8, max = 60, step = 1,
            get = function() return get("height") end,
            set = function(_, v) setWipe("height", v) end,
            disabled = function() return get("inheritHeight") end,
        },
        inheritHeight = {
            order = 12.5, type = "toggle", name = "Inherit Height from Anchor",
            desc = "Automatically match the height of the anchor frame.",
            get = function() return get("inheritHeight") end,
            set = function(_, v) setWipe("inheritHeight", v) end,
        },
        inheritHeightOffset = {
            order = 12.6, type = "range", name = "Height Nudge",
            desc = "Fine-tune the inherited height.",
            min = -10, max = 10, step = 0.01, bigStep = 0.5,
            get = function() return get("inheritHeightOffset") end,
            set = function(_, v) setWipe("inheritHeightOffset", v) end,
            disabled = function() return not get("inheritHeight") end,
        },
        statusBarTexture = {
            order = 13, type = "select", name = "Texture",
            dialogControl = "LSM30_Statusbar", values = LSM:HashTable("statusbar"),
            get = function() return get("statusBarTexture") end,
            set = function(_, v) setWipe("statusBarTexture", v) end,
        },
        useClassColor = {
            order = 14, type = "toggle", name = "Use Class Color",
            get = function() return get("useClassColor") end,
            set = function(_, v) setWipe("useClassColor", v) end,
        },
        customColor = {
            order = 15, type = "color", name = "Custom Color", hasAlpha = false,
            disabled = function() return get("useClassColor") end,
            get = function() local c = get("customColor"); return c.r, c.g, c.b end,
            set = function(_, r, g, b) setWipe("customColor", { r = r, g = g, b = b }) end,
        },
        
        iconHeader = { order = 20, type = "header", name = "Icon" },
        iconEnabled = {
            order = 21, type = "toggle", name = "Show Icon",
            get = function() return get("iconEnabled") end,
            set = function(_, v) setWipe("iconEnabled", v) end,
        },
        iconSpacing = {
            order = 22, type = "range", name = "Icon Spacing", min = 0, max = 10, step = 1,
            get = function() return get("iconSpacing") end,
            set = function(_, v) setWipe("iconSpacing", v) end,
            disabled = function() return not get("iconEnabled") end,
        },
        iconZoom = {
            order = 23, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true,
            get = function() return get("iconZoom") end,
            set = function(_, v) setWipe("iconZoom", v) end,
            disabled = function() return not get("iconEnabled") end,
        },
        
        textHeader = { order = 30, type = "header", name = "Text" },
        font = {
            order = 31, type = "select", name = "Font",
            dialogControl = "LSM30_Font", values = LSM:HashTable("font"),
            get = function() return get("font") end,
            set = function(_, v) setWipe("font", v) end,
        },
        fontSize = {
            order = 32, type = "range", name = "Font Size", min = 6, max = 30, step = 1,
            get = function() return get("fontSize") end,
            set = function(_, v) setWipe("fontSize", v) end,
        },
        fontOutline = {
            order = 33, type = "select", name = "Font Outline",
            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
            get = function() return get("fontOutline") end,
            set = function(_, v) setWipe("fontOutline", v) end,
        },
        showName = {
            order = 34, type = "toggle", name = "Show Name",
            get = function() return get("showName") end,
            set = function(_, v) setWipe("showName", v) end,
        },
        namePoint = {
            order = 35, type = "select", name = "Name Alignment",
            values = { ["LEFT"] = "Left", ["CENTER"] = "Center", ["RIGHT"] = "Right" },
            get = function() return get("namePoint") end,
            set = function(_, v) setWipe("namePoint", v) end,
            disabled = function() return not get("showName") end,
        },
        nameXOffset = {
            order = 36, type = "range", name = "Name X Offset", min = -50, max = 50, step = 0.5,
            get = function() return get("nameXOffset") end,
            set = function(_, v) setWipe("nameXOffset", v) end,
            disabled = function() return not get("showName") end,
        },
        nameYOffset = {
            order = 37, type = "range", name = "Name Y Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("nameYOffset") end,
            set = function(_, v) setWipe("nameYOffset", v) end,
            disabled = function() return not get("showName") end,
        },
        
        durationPoint = {
            order = 38,
            type = "select",
            name = "Duration Alignment",
            values = {
                ["LEFT"] = "Left",
                ["CENTER"] = "Center",
                ["RIGHT"] = "Right",
            },
            get = function() return get("durationPoint") end,
            set = function(_, v) setWipe("durationPoint", v) end,
            disabled = function() return not get("showDuration") end,
        },
        durationXOffset = {
            order = 39,
            type = "range",
            name = "Duration X Offset",
            min = -50, max = 50, step = 0.5,
            get = function() return get("durationXOffset") end,
            set = function(_, v) setWipe("durationXOffset", v) end,
            disabled = function() return not get("showDuration") end,
        },
        durationYOffset = {
            order = 40,
            type = "range",
            name = "Duration Y Offset",
            min = -20, max = 20, step = 0.5,
            get = function() return E.db.thingsUI.buffBars.durationYOffset end,
            set = function(_, v)
                E.db.thingsUI.buffBars.durationYOffset = value
                wipe(skinnedBars)
                TUI:UpdateBuffBars()
            end,
        },
        
        stackHeader = { order = 40, type = "header", name = "Stack Count" },
        showStacks = {
            order = 41, type = "toggle", name = "Show Stack Count",
            get = function() return get("showStacks") end,
            set = function(_, v) setWipe("showStacks", v) end,
        },
        stackAnchor = {
            order = 41.5, type = "select", name = "Stack Anchor",
            desc = "Anchor the stack count to the Icon or the Bar.",
            values = { ["ICON"] = "Icon", ["BAR"] = "Bar" },
            get = function() return get("stackAnchor") or "ICON" end,
            set = function(_, v) setWipe("stackAnchor", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackFontSize = {
            order = 42, type = "range", name = "Stack Font Size", min = 6, max = 36, step = 1,
            get = function() return get("stackFontSize") end,
            set = function(_, v) setWipe("stackFontSize", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackFontOutline = {
            order = 43, type = "select", name = "Stack Outline",
            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
            get = function() return get("stackFontOutline") end,
            set = function(_, v) setWipe("stackFontOutline", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackPoint = {
            order = 44, type = "select", name = "Stack Position",
            values = { ["CENTER"] = "Center", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOP"] = "Top", ["BOTTOM"] = "Bottom" },
            get = function() return get("stackPoint") end,
            set = function(_, v) setWipe("stackPoint", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackXOffset = {
            order = 45, type = "range", name = "Stack X Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("stackXOffset") end,
            set = function(_, v) setWipe("stackXOffset", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackYOffset = {
            order = 46, type = "range", name = "Stack Y Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("stackYOffset") end,
            set = function(_, v) setWipe("stackYOffset", v) end,
            disabled = function() return not get("showStacks") end,
        },
        
        backdropHeader = { order = 48, type = "header", name = "Backdrop" },
        showBackdrop = {
            order = 48.1, type = "toggle", name = "Show Backdrop",
            desc = "Show a persistent background behind the bar slot, visible even when the aura is not active.",
            get = function() return get("showBackdrop") end,
            set = function(_, v) setWipe("showBackdrop", v) end,
        },
        backdropColor = {
            order = 48.2, type = "color", name = "Backdrop Color", hasAlpha = true,
            get = function()
                local c = get("backdropColor") or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
                return c.r, c.g, c.b, c.a
            end,
            set = function(_, r, g, b, a) setWipe("backdropColor", { r = r, g = g, b = b, a = a }) end,
            disabled = function() return not get("showBackdrop") end,
        },
        
        anchorHeader = { order = 50, type = "header", name = "Anchor" },
        anchorMode = {
            order = 51, type = "select", name = "Anchor To", width = "double",
            desc = "Choose a predefined frame or select Custom to type a frame name.",
            values = SPECIAL_BAR_ANCHOR_VALUES,
            get = function() return get("anchorMode") or get("anchorFrame") or "ElvUF_Player" end,
            set = function(_, v)
                GetSpecialBarSlotDB(barKey).anchorMode = v
                if v ~= "CUSTOM" then
                    GetSpecialBarSlotDB(barKey).anchorFrame = v
                end
                TUI:UpdateSpecialBars()
            end,
        },
        anchorFrame = {
            order = 51.5, type = "input", name = "Custom Frame Name", width = "double",
            desc = "Type the exact frame name (e.g., ElvUF_Player, UIParent).",
            get = function() return get("anchorFrame") end,
            set = function(_, v) set("anchorFrame", v) end,
            hidden = function() return (get("anchorMode") or get("anchorFrame") or "ElvUF_Player") ~= "CUSTOM" end,
        },
        anchorPoint = {
            order = 52, type = "select", name = "Point",
            values = { ["TOP"] = "TOP", ["BOTTOM"] = "BOTTOM", ["LEFT"] = "LEFT", ["RIGHT"] = "RIGHT", ["CENTER"] = "CENTER",
                       ["TOPLEFT"] = "TOPLEFT", ["TOPRIGHT"] = "TOPRIGHT", ["BOTTOMLEFT"] = "BOTTOMLEFT", ["BOTTOMRIGHT"] = "BOTTOMRIGHT" },
            get = function() return get("anchorPoint") end,
            set = function(_, v) set("anchorPoint", v) end,
        },
        anchorRelativePoint = {
            order = 53, type = "select", name = "Relative Point",
            values = { ["TOP"] = "TOP", ["BOTTOM"] = "BOTTOM", ["LEFT"] = "LEFT", ["RIGHT"] = "RIGHT", ["CENTER"] = "CENTER",
                       ["TOPLEFT"] = "TOPLEFT", ["TOPRIGHT"] = "TOPRIGHT", ["BOTTOMLEFT"] = "BOTTOMLEFT", ["BOTTOMRIGHT"] = "BOTTOMRIGHT" },
            get = function() return get("anchorRelativePoint") end,
            set = function(_, v) set("anchorRelativePoint", v) end,
        },
        anchorXOffset = {
            order = 54, type = "range", name = "X Offset", min = -500, max = 500, step = 0.5, bigStep = 1,
            get = function() return get("anchorXOffset") end,
            set = function(_, v) set("anchorXOffset", v) end,
        },
        anchorYOffset = {
            order = 55, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.5, bigStep = 1,
            get = function() return get("anchorYOffset") end,
            set = function(_, v) set("anchorYOffset", v) end,
        },
        
        -- Reset Button
        resetSettings = {
            order = 100, -- High order to ensure it appears at the bottom
            type = "execute",
            name = "Reset to Defaults",
            desc = "Reset all settings for this bar to their default values.",
            func = function()
                local db = GetSpecialBarSlotDB(barKey)
                
                -- Loop through the defaults table and copy values over
                for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
                    if type(v) == "table" then
                        -- Create a new table for colors to avoid reference issues
                        db[k] = {}
                        for subKey, subVal in pairs(v) do
                            db[k][subKey] = subVal
                        end
                    else
                        db[k] = v
                    end
                end
                
                -- Force a full refresh
                wipe(skinnedBars) 
                TUI:UpdateSpecialBars()
                print("|cFF8080FFthingsUI|r: " .. barKey .. " reset to defaults.")
            end,
        },
    }
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
            generalTab = {
                order = 10,
                type = "group",
                name = "General",
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
                    
                    windToolsHeader = {
                        order = 10,
                        type = "header",
                        name = "WindTools & ElvUI Private Settings",
                    },
                    windToolsDescription = {
                        order = 11,
                        type = "description",
                        name = "Apply things's recommended WindTools and ElvUI private settings.\n\n|cFFFF6B6BWarning:|r This will overwrite your current WindTools settings!\n",
                    },
                    setupWindTools = {
                        order = 12,
                        type = "execute",
                        name = "Setup things Settings",
                        desc = "Apply recommended WindTools and ElvUI private settings.",
                        func = function()
                            -- WindTools Maps
                            E.private["WT"]["maps"]["instanceDifficulty"]["align"] = "CENTER"
                            E.private["WT"]["maps"]["instanceDifficulty"]["enable"] = true
                            E.private["WT"]["maps"]["minimapButtons"]["backdropSpacing"] = 0
                            E.private["WT"]["maps"]["minimapButtons"]["buttonSize"] = 28
                            E.private["WT"]["maps"]["minimapButtons"]["buttonsPerRow"] = 1
                            E.private["WT"]["maps"]["minimapButtons"]["expansionLandingPage"] = true
                            E.private["WT"]["maps"]["minimapButtons"]["mouseOver"] = true
                            E.private["WT"]["maps"]["minimapButtons"]["orientation"] = "VERTICAL"
                            E.private["WT"]["maps"]["minimapButtons"]["spacing"] = 1
                            E.private["WT"]["maps"]["worldMap"]["scale"]["size"] = 1.33
                            
                            -- WindTools Quest
                            E.private["WT"]["quest"]["objectiveTracker"]["colorfulPercentage"] = true
                            E.private["WT"]["quest"]["objectiveTracker"]["cosmeticBar"]["border"] = "ONEPIXEL"
                            E.private["WT"]["quest"]["objectiveTracker"]["cosmeticBar"]["color"]["mode"] = "CLASS"
                            E.private["WT"]["quest"]["objectiveTracker"]["cosmeticBar"]["offsetY"] = -13
                            E.private["WT"]["quest"]["objectiveTracker"]["cosmeticBar"]["texture"] = "ElvUI Blank"
                            E.private["WT"]["quest"]["objectiveTracker"]["enable"] = true
                            E.private["WT"]["quest"]["objectiveTracker"]["percentage"] = true
                            
                            -- WindTools Skins
                            E.private["WT"]["skins"]["addons"]["worldQuestTab"] = false
                            E.private["WT"]["skins"]["blizzard"]["scenario"] = false
                            E.private["WT"]["skins"]["cooldownViewer"]["enable"] = false
                            E.private["WT"]["skins"]["ime"]["label"]["name"] = "Expressway"
                            E.private["WT"]["skins"]["shadow"] = false
                            E.private["WT"]["skins"]["widgets"]["button"]["backdrop"]["texture"] = "ElvUI Blank"
                            E.private["WT"]["skins"]["widgets"]["treeGroupButton"]["backdrop"]["texture"] = "ElvUI Blank"
                            
                            -- WindTools UnitFrames
                            E.private["WT"]["unitFrames"]["roleIcon"]["enable"] = false
                            E.private["WT"]["unitFrames"]["roleIcon"]["roleIconStyle"] = "LYNUI"
                            
                            -- ElvUI Private General
                            E.private["general"]["chatBubbleFont"] = "Expressway"
                            E.private["general"]["chatBubbleFontOutline"] = "OUTLINE"
                            E.private["general"]["chatBubbles"] = "nobackdrop"
                            E.private["general"]["classColors"] = true
                            E.private["general"]["glossTex"] = "ElvUI Blank"
                            E.private["general"]["minimap"]["hideTracking"] = true
                            E.private["general"]["nameplateFont"] = "Expressway"
                            E.private["general"]["nameplateLargeFont"] = "Expressway"
                            E.private["general"]["normTex"] = "ElvUI Blank"
                            E.private["install_complete"] = 12.12
                            
                            -- ElvUI Private Other
                            E.private["nameplates"]["enable"] = false
                            E.private["skins"]["blizzard"]["cooldownManager"] = false
                            E.private["skins"]["parchmentRemoverEnable"] = true
                            
                            print("|cFF8080FFthingsUI|r - WindTools & ElvUI private settings applied! |cFFFFFF00Reload required.|r")
                            E:StaticPopup_Show("PRIVATE_RL")
                        end,
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
                childGroups = "tree",
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
                    presetDPSTank = {
                        order = 3,
                        type = "execute",
                        name = "Load DPS/Tank Preset",
                        desc = "Load default buff bar settings for DPS and Tank specs (bars grow UP from player frame).",
                        func = function()
                            local db = E.db.thingsUI.buffBars
                            db.enabled = true
                            db.growthDirection = "UP"
                            db.width = 240
                            db.inheritWidth = true
                            db.inheritWidthOffset = 0
                            db.height = 23
                            db.spacing = 1
                            db.statusBarTexture = "ElvUI Blank"
                            db.useClassColor = true
                            db.iconEnabled = true
                            db.iconSpacing = 1
                            db.iconZoom = 0.1
                            db.font = "Expressway"
                            db.fontSize = 14
                            db.fontOutline = "OUTLINE"
                            db.namePoint = "LEFT"
                            db.nameXOffset = 2
                            db.nameYOffset = 0
                            db.durationPoint = "RIGHT"
                            db.durationXOffset = -4
                            db.durationYOffset = 0
                            db.stackAnchor = "ICON"
                            db.stackPoint = "CENTER"
                            db.stackFontSize = 15
                            db.stackFontOutline = "OUTLINE"
                            db.stackXOffset = 0
                            db.stackYOffset = 0
                            db.anchorEnabled = true
                            db.anchorFrame = "ElvUF_Player"
                            db.anchorPoint = "BOTTOM"
                            db.anchorRelativePoint = "TOP"
                            db.anchorXOffset = 0
                            db.anchorYOffset = 50
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    presetHealer = {
                        order = 4,
                        type = "execute",
                        name = "Load Healer Preset",
                        desc = "Load default buff bar settings for Healer specs (bars grow DOWN from class bar).",
                        func = function()
                            local db = E.db.thingsUI.buffBars
                            db.enabled = true
                            db.growthDirection = "DOWN"
                            db.width = 218
                            db.inheritWidth = true
                            db.inheritWidthOffset = 2
                            db.height = 23
                            db.spacing = 1
                            db.statusBarTexture = "ElvUI Blank"
                            db.useClassColor = true
                            db.iconEnabled = true
                            db.iconSpacing = 1
                            db.iconZoom = 0
                            db.font = "Expressway"
                            db.fontSize = 15
                            db.fontOutline = "OUTLINE"
                            db.namePoint = "LEFT"
                            db.nameXOffset = 4
                            db.nameYOffset = 0
                            db.durationPoint = "RIGHT"
                            db.durationXOffset = -4
                            db.durationYOffset = 0
                            db.stackAnchor = "ICON"
                            db.stackPoint = "CENTER"
                            db.stackFontSize = 15
                            db.stackFontOutline = "OUTLINE"
                            db.stackXOffset = 0
                            db.stackYOffset = 0
                            db.anchorEnabled = true
                            db.anchorFrame = "ElvUF_Player_ClassBar"
                            db.anchorPoint = "TOP"
                            db.anchorRelativePoint = "BOTTOM"
                            db.anchorXOffset = 0
                            db.anchorYOffset = -2
                            wipe(skinnedBars)
                            TUI:UpdateBuffBars()
                        end,
                    },
                    
                    -----------------------------------------
                    -- LAYOUT SUB-GROUP
                    -----------------------------------------
                    layoutGroup = {
                        order = 10,
                        type = "group",
                        name = "Layout",
                        args = {
                            layoutHeader = {
                                order = 1,
                                type = "header",
                                name = "Size & Spacing",
                            },
                            growthDirection = {
                                order = 2,
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
                                order = 3,
                                type = "range",
                                name = "Width",
                                min = 100, max = 400, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.width end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.width = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return E.db.thingsUI.buffBars.inheritWidth end,
                            },
                            inheritWidth = {
                                order = 4,
                                type = "toggle",
                                name = "Inherit Width from Anchor",
                                desc = "Automatically match the width of the anchor frame. Requires anchoring to be enabled.",
                                get = function() return E.db.thingsUI.buffBars.inheritWidth end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.inheritWidth = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            inheritWidthOffset = {
                                order = 5,
                                type = "range",
                                name = "Width Nudge",
                                desc = "Fine-tune the inherited width. Add or subtract pixels from the anchor's width.",
                                min = -10, max = 10, step = 0.01, bigStep = 0.5,
                                get = function() return E.db.thingsUI.buffBars.inheritWidthOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.inheritWidthOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.inheritWidth end,
                            },
                            height = {
                                order = 6,
                                type = "range",
                                name = "Height",
                                min = 10, max = 40, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.height end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.height = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            spacing = {
                                order = 7,
                                type = "range",
                                name = "Spacing",
                                min = -10, max = 10, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.spacing end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.spacing = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            
                            textureHeader = {
                                order = 10,
                                type = "header",
                                name = "Textures & Colors",
                            },
                            statusBarTexture = {
                                order = 11,
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
                                order = 12,
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
                                order = 13,
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
                            
                            iconHeader = {
                                order = 20,
                                type = "header",
                                name = "Icon",
                            },
                            iconEnabled = {
                                order = 21,
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
                            iconSpacing = {
                                order = 22,
                                type = "range",
                                name = "Icon Spacing",
                                desc = "Gap between the icon and the bar.",
                                min = 0, max = 10, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.iconSpacing end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.iconSpacing = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            iconZoom = {
                                order = 23,
                                type = "range",
                                name = "Icon Zoom",
                                desc = "How much to crop the icon edges. 0 = no crop (full texture), 0.1 = ElvUI default.",
                                min = 0, max = 0.45, step = 0.01,
                                isPercent = true,
                                get = function() return E.db.thingsUI.buffBars.iconZoom end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.iconZoom = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                        },
                    },
                    
                    -----------------------------------------
                    -- TEXT SUB-GROUP
                    -----------------------------------------
                    textGroup = {
                        order = 20,
                        type = "group",
                        name = "Text",
                        args = {
                            fontHeader = {
                                order = 1,
                                type = "header",
                                name = "Font",
                            },
                            font = {
                                order = 2,
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
                                order = 3,
                                type = "range",
                                name = "Font Size",
                                min = 8, max = 50, step = 1,
                                get = function() return E.db.thingsUI.buffBars.fontSize end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.fontSize = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            fontOutline = {
                                order = 4,
                                type = "select",
                                name = "Font Outline",
                                desc = "Outline for Name and Duration text.",
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
                            
                            nameTextHeader = {
                                order = 10,
                                type = "header",
                                name = "Name Text",
                            },
                            namePoint = {
                                order = 11,
                                type = "select",
                                name = "Name Alignment",
                                desc = "Anchor point for the spell name text.",
                                values = {
                                    ["LEFT"] = "Left",
                                    ["CENTER"] = "Center",
                                    ["RIGHT"] = "Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.namePoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.namePoint = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            nameXOffset = {
                                order = 12,
                                type = "range",
                                name = "Name X Offset",
                                min = -50, max = 50, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.nameXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.nameXOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            nameYOffset = {
                                order = 13,
                                type = "range",
                                name = "Name Y Offset",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.nameYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.nameYOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            
                            durationTextHeader = {
                                order = 20,
                                type = "header",
                                name = "Duration Text",
                            },
                            durationPoint = {
                                order = 21,
                                type = "select",
                                name = "Duration Alignment",
                                desc = "Anchor point for the duration text.",
                                values = {
                                    ["LEFT"] = "Left",
                                    ["CENTER"] = "Center",
                                    ["RIGHT"] = "Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.durationPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationPoint = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            durationXOffset = {
                                order = 22,
                                type = "range",
                                name = "Duration X Offset",
                                min = -50, max = 50, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.durationXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationXOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            durationYOffset = {
                                order = 23,
                                type = "range",
                                name = "Duration Y Offset",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.durationYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationYOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            
                            stackHeader = {
                                order = 30,
                                type = "header",
                                name = "Stack Count",
                            },
                            stackAnchor = {
                                order = 30.5,
                                type = "select",
                                name = "Stack Anchor",
                                desc = "Anchor the stack count to the Icon or the Bar.",
                                values = {
                                    ["ICON"] = "Icon",
                                    ["BAR"] = "Bar",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackAnchor end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackAnchor = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackPoint = {
                                order = 31,
                                type = "select",
                                name = "Stack Position",
                                desc = "Anchor point for the stack count on the icon.",
                                values = {
                                    ["CENTER"] = "Center",
                                    ["TOP"] = "Top",
                                    ["BOTTOM"] = "Bottom",
                                    ["TOPLEFT"] = "Top Left",
                                    ["TOPRIGHT"] = "Top Right",
                                    ["BOTTOMLEFT"] = "Bottom Left",
                                    ["BOTTOMRIGHT"] = "Bottom Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackPoint = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontSize = {
                                order = 32,
                                type = "range",
                                name = "Stack Font Size",
                                desc = "Font size for the stack count on icons.",
                                min = 6, max = 50, step = 1,
                                get = function() return E.db.thingsUI.buffBars.stackFontSize end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackFontSize = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontOutline = {
                                order = 33,
                                type = "select",
                                name = "Stack Font Outline",
                                values = {
                                    ["NONE"] = "None",
                                    ["OUTLINE"] = "Outline",
                                    ["THICKOUTLINE"] = "Thick Outline",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackFontOutline end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackFontOutline = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackXOffset = {
                                order = 34,
                                type = "range",
                                name = "Stack X Offset",
                                desc = "Horizontal offset for the stack count text.",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.stackXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackXOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackYOffset = {
                                order = 35,
                                type = "range",
                                name = "Stack Y Offset",
                                desc = "Vertical offset for the stack count text.",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.stackYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackYOffset = value
                                    wipe(skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                        },
                    },
                    
                    -----------------------------------------
                    -- ANCHORING SUB-GROUP
                    -----------------------------------------
                    anchoringGroup = {
                        order = 30,
                        type = "group",
                        name = "Anchoring",
                        args = {
                            anchorHeader = {
                                order = 1,
                                type = "header",
                                name = "Anchor Settings",
                            },
                            anchorEnabled = {
                                order = 2,
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
                                order = 3,
                                type = "select",
                                name = "Anchor Frame",
                                desc = "Select a frame to anchor to.",
                                values = SHARED_ANCHOR_VALUES,
                                get = function() return E.db.thingsUI.buffBars.anchorFrame end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorFrame = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorPoint = {
                                order = 4,
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
                                order = 5,
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
                                order = 6,
                                type = "range",
                                name = "X Offset",
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.anchorXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorXOffset = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorYOffset = {
                                order = 7,
                                type = "range",
                                name = "Y Offset",
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.anchorYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorYOffset = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                        },
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
                        desc = "Move frames outward if Utility icons exceed Essential icons.",
                        get = function() return E.db.thingsUI.clusterPositioning.accountForUtility end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.accountForUtility = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    utilityThreshold = {
                        order = 14,
                        type = "range",
                        name = "Utility Threshold",
                        desc = "How many MORE utility icons than essential icons to trigger movement.",
                        min = 1, max = 10, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.utilityThreshold end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.utilityThreshold = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                    },
                    utilityOverflowOffset = {
                        order = 15,
                        type = "range",
                        name = "Overflow Offset",
                        desc = "Pixels to move each frame outward when threshold is met.",
                        min = 10, max = 200, step = 5,
                        get = function() return E.db.thingsUI.clusterPositioning.utilityOverflowOffset end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.utilityOverflowOffset = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                    },
                    yOffset = {
                        order = 16,
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
                    
                    playerTargetHeader = {
                        order = 20,
                        type = "header",
                        name = "Player / Target Frame",
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
                    targetEnabled = {
                        order = 22,
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
                    frameGap = {
                        order = 23,
                        type = "range",
                        name = "Frame Gap",
                        desc = "Gap between Player/Target frames and Essential.",
                        min = -50, max = 50, step = 1,
                        get = function() return E.db.thingsUI.clusterPositioning.frameGap end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.frameGap = value
                            TUI:RecalculateCluster()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
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
                        min = -50, max = 50, step = 1,
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
                            TUI:UpdateClusterPositioning()
                        end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    castBarGap = {
                        order = 52,
                        type = "range",
                        name = "CastBar Y Gap",
                        desc = "Vertical gap between Target frame and CastBar.",
                        min = -50, max = 50, step = 1,
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
            -- SPECIAL BARS TAB
            -------------------------------------------------
            specialBarsTab = {
                order = 50,
                type = "group",
                name = "Special Bars",
                childGroups = "tree",
                args = {
                    specialBarsHeader = {
                        order = 1,
                        type = "header",
                        name = "Special Bars",
                    },
                    description = {
                        order = 2,
                        type = "description",
                        name = "Yoink individual tracked bars from the BuffBarCooldownViewer and reposition them independently.\n\nEnter the exact spell name as it appears in your Tracked Bars. The bar will be pulled out and displayed at your chosen anchor. It keeps updating in combat because CDM handles the aura tracking internally.\n\n|cFFFFFF00The spell must be in your Tracked Bars list in the Cooldown Manager.|r\n|cFF00FF00Settings are saved per specialization — each spec remembers its own spells and layout.|r",
                    },
                    bar1Group = {
                        order = 10,
                        type = "group",
                        name = "Special Bar 1",
                        args = TUI:SpecialBarOptions("bar1"),
                    },
                    bar2Group = {
                        order = 20,
                        type = "group",
                        name = "Special Bar 2",
                        args = TUI:SpecialBarOptions("bar2"),
                    },
                    bar3Group = {
                        order = 30,
                        type = "group",
                        name = "Special Bar 3",
                        args = TUI:SpecialBarOptions("bar3"),
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
    RequestRestoreClusterPoints()
    self:FullRefresh()
    self:TriggerBurst()
end

if E.data and E.data.RegisterCallback then
    E.data:RegisterCallback(TUI, "OnProfileChanged", "ProfileUpdate")
    E.data:RegisterCallback(TUI, "OnProfileCopied", "ProfileUpdate")
    E.data:RegisterCallback(TUI, "OnProfileReset", "ProfileUpdate")
end

-- Initialize when ElvUI is ready
E:RegisterModule(TUI:GetName())