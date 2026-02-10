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
TUI.version = "2.0.0" -- Split backdrops for proper spacing
TUI.name = "thingsUI"

-- Shared Anchor List
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

-- Special Bars Anchor List (Includes TUI Bars)
local SPECIAL_BAR_ANCHOR_VALUES = {}
for k, v in pairs(SHARED_ANCHOR_VALUES) do SPECIAL_BAR_ANCHOR_VALUES[k] = v end
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar1"] = "TUI Special Bar 1"
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar2"] = "TUI Special Bar 2"
SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar3"] = "TUI Special Bar 3"

-- Defaults that get merged into ElvUI's profile
P["thingsUI"] = {
    -- Buff Icons (BuffIconCooldownViewer)
    verticalBuffs = false,
    
    -- Buff Bars (BuffBarCooldownViewer)
    buffBars = {
        enabled = false,
        growthDirection = "UP", -- "UP" or "DOWN"
        width = 240,
        height = 23,
        spacing = 1,
        statusBarTexture = "ElvUI Blank",
        font = "Expressway",
        fontSize = 14,
        fontOutline = "OUTLINE",
        iconEnabled = true,
        iconSpacing = 1,    -- Gap between icon and bar
        iconZoom = 0.1,     -- 0 = full texture, 0.1 = 10% crop each side (like ElvUI default)
        inheritWidth = true, -- Inherit width from anchor frame
        inheritWidthOffset = 0, -- Fine-tune offset when inheriting width
        stackFontSize = 14  , -- Stack count font size                                                                                                                                                      
        stackFontOutline = "OUTLINE",
        stackPoint = "CENTER",
        stackAnchor = "ICON",  -- "ICON" or "BAR"
        stackXOffset = 0,
        stackYOffset = 0,
        -- Name text positioning
        namePoint = "LEFT",
        nameXOffset = 2,
        nameYOffset = 0,
        -- Duration text positioning
        durationPoint = "RIGHT",
        durationXOffset = -4,
        durationYOffset = 0,
        backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        useClassColor = true,
        customColor = { r = 0.2, g = 0.6, b = 1.0 },
        -- Anchor settings
        anchorEnabled = true,
        anchorFrame = "ElvUF_Player",
        anchorPoint = "BOTTOM",      -- Point on buff bars
        anchorRelativePoint = "TOP", -- Point on target frame
        anchorXOffset = 0,
        anchorYOffset = 50,
    },
    
    -- Dynamic Cooldown Cluster Positioning
    clusterPositioning = {
        enabled = false,
        essentialIconWidth = 42,    -- Width per Essential icon
        essentialIconPadding = 1,   -- Padding between Essential icons
        utilityIconWidth = 35,      -- Width per Utility icon (for reference)
        utilityIconPadding = 1,     -- Padding between Utility icons
        accountForUtility = true,   -- Account for Utility icons extending past Essential
        utilityThreshold = 3,       -- How many MORE utility icons than essential to trigger movement
        utilityOverflowOffset = 25, -- Pixels to add per side when threshold is met
        yOffset = 0,                -- Y offset for all unit frames
        frameGap = 20,              -- Gap between Player/Target and Essential (shared)
        
        -- Unit Frame positioning
        playerFrame = {
            enabled = true,
        },
        targetFrame = {
            enabled = true,
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
        additionalPowerBar = {
            enabled = false,
            gap = 1,
            xOffset = 0,
        },
    },

    -- Special Bars (yoinked from Tracked Bars) — stored per spec
    specialBars = {
        -- Per-spec storage: specialBars.specs[specID] = { bar1 = {...}, bar2 = {...}, bar3 = {...} }
        specs = {},
    },
}

-------------------------------------------------
-- VERTICAL BUFF ICONS (BuffIconCooldownViewer)
-------------------------------------------------
local iconUpdateThrottle = 0.05
local iconNextUpdate = 0
local iconUpdateFrame = CreateFrame("Frame")
local reusableIconTable = {}

local function PositionBuffsVertically()
    local currentTime = GetTime()
    if currentTime < iconNextUpdate then return end
    iconNextUpdate = currentTime + iconUpdateThrottle
    
    if not BuffIconCooldownViewer then return end
    if not E.db.thingsUI or not E.db.thingsUI.verticalBuffs then return end
    
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
    if E.db.thingsUI.verticalBuffs then
        iconUpdateFrame:SetScript("OnUpdate", PositionBuffsVertically)
    else
        iconUpdateFrame:SetScript("OnUpdate", nil)
    end
end

-------------------------------------------------
-- BUFF BAR SKINNING (BuffBarCooldownViewer)
-------------------------------------------------
local barUpdateThrottle = 0.05 -- Faster updates (20 times per second)
local barNextUpdate = 0
local barUpdateFrame = CreateFrame("Frame")
local skinnedBars = {} -- Track which bars we've skinned (for wipe on settings change)

local function GetClassColor()
    local classColor = E:ClassColor(E.myclass, true)
    return classColor.r, classColor.g, classColor.b
end

local function SkinBuffBar(childFrame, forceUpdate)
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
        
        -- KILL OLD UNIBODY BACKDROP (Fjerner den gamle store boksen)
        if childFrame.tuiBackdrop then childFrame.tuiBackdrop:Hide() end

        -- Calculate offsets
        local barOffset = 0
        local iconSize = db.height

        -- ICON SKINNING & BACKDROP
        if icon and icon.Icon then
            if db.iconEnabled then
                icon:Show()
                icon:SetSize(iconSize, iconSize)
                icon.Icon:SetTexCoord(db.iconZoom, 1-db.iconZoom, db.iconZoom, 1-db.iconZoom)
                
                -- Create separate backdrop for Icon
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
                
                -- Inset the texture slightly inside the icon border
                icon.Icon:ClearAllPoints()
                icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
                icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
                
                barOffset = iconSize + (db.iconSpacing or 3)
            else 
                icon:Hide() 
            end
        end
        
        -- BAR BACKDROP (Create separate backdrop for Bar)
        if not bar.tuiBackdrop then
            bar.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
            bar.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            bar.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.7)
            bar.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
            bar.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)
        end
        bar.tuiBackdrop:Show()
        bar.tuiBackdrop:ClearAllPoints()
        -- Anchor bar backdrop to the calculated offset
        bar.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
        bar.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)

        -- BAR POSITIONING (Inset inside the bar backdrop)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", bar.tuiBackdrop, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", bar.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
        
        -- Skin the bar
        local texture = LSM:Fetch("statusbar", db.statusBarTexture)
        bar:SetStatusBarTexture(texture)
        if db.useClassColor then
            bar:SetStatusBarColor(GetClassColor())
        else
            bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b)
        end
        
        -- Textures & Pip
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

-- Check if a bar has an active aura (is actually tracking something)
local function IsBarActive(childFrame)
    if not childFrame then return false end
    if not childFrame:IsShown() then return false end
    if not childFrame.Bar then return false end
    
    -- If it's shown and has a Bar, consider it active
    -- CDM handles hiding inactive bars itself
    return true
end

-- Anchor the BuffBarCooldownViewer container
local function AnchorBuffBarContainer()
    if not BuffBarCooldownViewer then return end
    
    local db = E.db.thingsUI.buffBars
    if not db.anchorEnabled then return end
    
    local anchorFrame = _G[db.anchorFrame]
    if not anchorFrame then return end
    
    -- Use pcall since we're anchoring to potentially protected frames
    -- But BuffBarCooldownViewer itself is NOT protected, so this should work
    pcall(function()
        BuffBarCooldownViewer:ClearAllPoints()
        BuffBarCooldownViewer:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
    end)
end

local reusableBarTable = {}
local yoinkedBars = {}  -- childFrame references that are yoinked by Special Bars
local UpdateSpecialBarSlot  -- forward declaration (defined after special bar system)
local FindBarBySpellName
local ReleaseSpecialBar
local GetOrCreateWrapper
local StyleSpecialBar
local GetSpecialBarDB
local GetSpecialBarSlotDB
local GetCurrentSpecID
local ScanAndHookCDMChildren  -- forward declaration for CDM child hooking

local function UpdateBuffBarPositions()
    if not BuffBarCooldownViewer then return end
    
    local db = E.db.thingsUI.buffBars
    wipe(reusableBarTable)
    
    -- Process special bar yoinks FIRST, before positioning normal bars
    -- This ensures yoinked bars are marked before the positioning loop
    if E.db.thingsUI.specialBars then
        local specDB = GetSpecialBarDB()
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" then
                pcall(UpdateSpecialBarSlot, barKey)
            end
        end
    end
    
    -- Safely get children (might fail in combat)
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return end
    
    for _, childFrame in ipairs(children) do
        -- Only include bars that are shown AND have active aura data AND not yoinked
        if childFrame and IsBarActive(childFrame) and not yoinkedBars[childFrame] then
            SkinBuffBar(childFrame)
            table.insert(reusableBarTable, childFrame)
        end
    end
    
    if #reusableBarTable == 0 then return end
    
    -- Sort with pcall in case layoutIndex is protected
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
        else -- UP
            barFrame:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, ((index - 1) * (height + spacing)))
        end
    end
    
    -- Apply container anchor if enabled (this one DOES need combat check since it anchors to ElvUI frames)
    AnchorBuffBarContainer()
end

local function BuffBarOnUpdate()
    local currentTime = GetTime()
    if currentTime < barNextUpdate then return end
    barNextUpdate = currentTime + barUpdateThrottle
    
    if not E.db.thingsUI then return end
    if not BuffBarCooldownViewer then return end
    
    -- Always process special bars (they run inside UpdateBuffBarPositions)
    if E.db.thingsUI.buffBars and E.db.thingsUI.buffBars.enabled then
        pcall(UpdateBuffBarPositions)
    elseif E.db.thingsUI.specialBars then
        -- Buff bar skinning disabled but special bars may be active
        ScanAndHookCDMChildren()
        local specDB = GetSpecialBarDB()
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" then
                pcall(UpdateSpecialBarSlot, barKey)
            end
        end
    end
end

-- Event-based updates for more reliable skinning
local buffBarEventFrame = CreateFrame("Frame")
buffBarEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
buffBarEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Combat ended
buffBarEventFrame:RegisterUnitEvent("UNIT_AURA", "player")

buffBarEventFrame:SetScript("OnEvent", function(self, event, ...)
    if not E.db.thingsUI then return end
    if not BuffBarCooldownViewer then return end
    
    -- Process buff bar skinning if enabled
    if E.db.thingsUI.buffBars and E.db.thingsUI.buffBars.enabled then
        pcall(UpdateBuffBarPositions)
    end
    
    -- ALWAYS process special bars on aura events (even if buff bar skinning is off)
    -- This is critical for yoinking newly-created CDM child frames mid-combat
    if E.db.thingsUI.specialBars then
        ScanAndHookCDMChildren()
        local specDB = GetSpecialBarDB()
        for barKey, barDB in pairs(specDB) do
            if type(barDB) == "table" then
                pcall(UpdateSpecialBarSlot, barKey)
            end
        end
    end
end)

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
-- SPECIAL BARS (Yoinked from BuffBarCooldownViewer)
-------------------------------------------------

-- Default template for a special bar slot
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
    stackAnchor = "ICON", -- New: "ICON" or "BAR"
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
    anchorMode = "UIParent",  -- Predefined or "CUSTOM"
    anchorFrame = "BCDM_CastBar", -- Used when anchorMode == "CUSTOM"
    anchorPoint = "CENTER",
    anchorRelativePoint = "CENTER",
    anchorXOffset = 0,
    anchorYOffset = 0,
}

-- Resolve actual frame name from anchor settings
local function ResolveAnchorFrame(db)
    local mode = db.anchorMode or db.anchorFrame or "ElvUF_Player"
    if mode == "CUSTOM" then
        return db.anchorFrame or "ElvUF_Player"
    end
    return mode
end

-- Get the current spec ID
GetCurrentSpecID = function()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex) or 0
    end
    return 0
end

-- Get or create spec-specific special bar config
-- Returns the bar table for the current spec, creating defaults if needed
GetSpecialBarDB = function()
    if not E.db.thingsUI.specialBars then
        E.db.thingsUI.specialBars = { specs = {} }
    end
    if not E.db.thingsUI.specialBars.specs then
        E.db.thingsUI.specialBars.specs = {}
    end
    
    local specID = GetCurrentSpecID()
    if specID == 0 then specID = 1 end  -- Fallback
    local specKey = tostring(specID)
    
    if not E.db.thingsUI.specialBars.specs[specKey] then
        -- Create fresh defaults for this spec
        E.db.thingsUI.specialBars.specs[specKey] = {}
        for _, barKey in ipairs({"bar1", "bar2", "bar3"}) do
            E.db.thingsUI.specialBars.specs[specKey][barKey] = {}
            for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
                if type(v) == "table" then
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = {}
                    for k2, v2 in pairs(v) do
                        E.db.thingsUI.specialBars.specs[specKey][barKey][k][k2] = v2
                    end
                else
                    E.db.thingsUI.specialBars.specs[specKey][barKey][k] = v
                end
            end
        end

    end
    
    return E.db.thingsUI.specialBars.specs[specKey]
end

-- Get a specific bar's DB for the current spec
GetSpecialBarSlotDB = function(barKey)
    local specDB = GetSpecialBarDB()
    if not specDB[barKey] then
        specDB[barKey] = {}
    end
    -- Ensure all defaults exist (fill in missing keys)
    for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
        if specDB[barKey][k] == nil then
            if type(v) == "table" then
                specDB[barKey][k] = {}
                for k2, v2 in pairs(v) do
                    specDB[barKey][k][k2] = v2
                end
            else
                specDB[barKey][k] = v
            end
        elseif type(v) == "table" and type(specDB[barKey][k]) == "table" then
            -- Ensure nested table has all default keys
            for k2, v2 in pairs(v) do
                if specDB[barKey][k][k2] == nil then
                    specDB[barKey][k][k2] = v2
                end
            end
        end
    end
    return specDB[barKey]
end

local specialBarUpdateFrame = CreateFrame("Frame")
local specialBarThrottle = 0.05
local specialBarNextUpdate = 0
local specialBarState = {}  -- Track state per barKey: { childFrame, originalParent, wrapperFrame }

-- Track known CDM children so we can detect newly created ones
local knownCDMChildren = {}   -- [childFrame] = true
local hookedCDMChildren = {}  -- [childFrame] = true (OnShow hooked)

-- Helper: clean text for matching (remove colors, trim spaces)
local function CleanString(str)
    if not str then return "" end
    -- Remove color codes like |c%x%x%x%x%x%x%x%x
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    -- Remove restore code |r
    str = str:gsub("|r", "")
    -- Trim whitespace
    str = str:match("^%s*(.-)%s*$")
    return str
end

-- Called when a BCDM child frame is shown (either new or re-shown)
-- This is the critical path for catching first-time spell casts mid-combat
local function OnCDMChildShown(childFrame)
    if not E.db.thingsUI or not E.db.thingsUI.specialBars then return end
    if not childFrame or not childFrame.Bar then return end
    
    -- Check if any special bar is waiting for this spell
    local specDB = GetSpecialBarDB()
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
            local match = false
            local targetName = CleanString(barDB.spellName)
            
            -- Try text match first (works out of combat)
            if childFrame.Bar.Name then
                pcall(function()
                    local barText = CleanString(childFrame.Bar.Name:GetText())
                    if barText and barText == targetName then
                        match = true
                    end
                end)
            end
            -- Fallback: match via auraSpellID (works in combat OR if user entered an ID)
            if not match and childFrame.auraSpellID then
                pcall(function()
                    -- Check if user entered a raw spell ID
                    local targetID = tonumber(targetName)
                    if targetID and targetID == childFrame.auraSpellID then
                        match = true
                    else
                        -- Check against spell info name
                    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(childFrame.auraSpellID)
                    local resolvedName = spellInfo and spellInfo.name
                    if not resolvedName then
                        resolvedName = GetSpellInfo(childFrame.auraSpellID)
                    end
                        if resolvedName and CleanString(resolvedName) == targetName then
                        match = true
                        end
                    end
                end)
            end
            if match then
                -- This child matches a special bar! Check if we already yoinked it
                local state = specialBarState[barKey]
                if not state or not state.childFrame or state.childFrame ~= childFrame then
                    -- New match — immediately try to yoink via UpdateSpecialBarSlot
                    pcall(UpdateSpecialBarSlot, barKey)
                end
            end
        end
    end
end

-- Scan BuffBarCooldownViewer for new children and hook their OnShow
ScanAndHookCDMChildren = function()
    if not BuffBarCooldownViewer then return end
    
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return end
    
    for _, childFrame in ipairs(children) do
        if childFrame and not hookedCDMChildren[childFrame] then
            hookedCDMChildren[childFrame] = true
            knownCDMChildren[childFrame] = true
            -- Hook OnShow so we catch the moment CDM activates this bar
            pcall(function()
                childFrame:HookScript("OnShow", OnCDMChildShown)
            end)
            -- If it's already shown right now, process it immediately
            local isShown = false
            pcall(function() isShown = childFrame:IsShown() end)
            if isShown then
                OnCDMChildShown(childFrame)
            end
        end
    end
end

-- Wrapper frame for a yoinked bar — provides independent anchoring
GetOrCreateWrapper = function(barKey)
    -- Check if we already have this wrapper in memory
    if specialBarState[barKey] and specialBarState[barKey].wrapper then
        return specialBarState[barKey].wrapper
    end
    
    -- Check if the frame already exists globally (prevents duplication on script reload/update)
    local frameName = "TUI_SpecialBar_" .. barKey
    local wrapper = _G[frameName] or CreateFrame("Frame", frameName, UIParent)
    
    -- Ensure default props
    if not wrapper:IsShown() then wrapper:Show() end
    wrapper:SetFrameStrata("MEDIUM")
    wrapper:SetFrameLevel(10)
    
    -- Check if backdrop exists on this frame (might be a reused frame)
    if not wrapper.backdrop then
        local bd = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
        bd:SetAllPoints(wrapper)
        bd:SetFrameLevel(wrapper:GetFrameLevel())
        bd:SetBackdrop({
            bgFile = E.media.blankTex,
            edgeFile = E.media.blankTex,
            edgeSize = 1,
        })
        bd:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        bd:SetBackdropBorderColor(0, 0, 0, 0.8)
        bd:Hide()
        wrapper.backdrop = bd
    end
    
    return wrapper
end

-- Find a tracked bar by spell name from BuffBarCooldownViewer
FindBarBySpellName = function(spellName)
    if not BuffBarCooldownViewer or not spellName or spellName == "" then return nil end
    
    local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
    if not ok or not children then return nil end
    
    local targetName = CleanString(spellName)
    
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.Bar then
            local match = false
            -- Primary: try matching via Bar.Name text (works out of combat)
            if childFrame.Bar.Name then
                pcall(function()
                    local barText = CleanString(childFrame.Bar.Name:GetText())
                    if barText and barText == targetName then
                        match = true
                    end
                end)
            end
            -- Fallback: match via auraSpellID (works in combat when GetText returns secret value)
            if not match and childFrame.auraSpellID then
                pcall(function()
                    -- Check if user entered a raw spell ID
                    local targetID = tonumber(targetName)
                    if targetID and targetID == childFrame.auraSpellID then
                        match = true
                    else
                    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(childFrame.auraSpellID)
                    local resolvedName = spellInfo and spellInfo.name
                    if not resolvedName then
                        -- Legacy API fallback
                        resolvedName = GetSpellInfo(childFrame.auraSpellID)
                    end
                        if resolvedName and CleanString(resolvedName) == targetName then
                        match = true
                        end
                    end
                end)
            end
            if match then return childFrame end
        end
    end
    return nil
end

-- Release a yoinked bar back to its original parent
ReleaseSpecialBar = function(barKey)
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

-- Style a yoinked bar with special bar settings
StyleSpecialBar = function(childFrame, db)
    local bar = childFrame.Bar
    local icon = childFrame.Icon
    if not bar then return end
    
    -- SIZING: childFrame is strictly sized.
    -- We need to split the backdrops for spacing to work.
    
    -- 1. Use the childFrame.tuiBackdrop as the BAR backdrop (repurposed)
    if not childFrame.tuiBackdrop then
        childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        childFrame.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
    end
    -- We will position this backdrop later based on offset
    childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.7)
    childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
    childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)

    local height = db.height
    local barOffset = 0

    -- 2. ICON STYLING
    if db.iconEnabled and icon then
        icon:Show()
        icon:SetSize(height, height) -- Square icon match bar height
        
        if icon.Icon then
            icon.Icon:SetTexCoord(db.iconZoom or 0.1, 1-(db.iconZoom or 0.1), db.iconZoom or 0.1, 1-(db.iconZoom or 0.1))
            icon.Icon:SetDrawLayer("ARTWORK", 1) 
            -- Inset texture
            icon.Icon:ClearAllPoints()
            icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
            icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        end
        
        -- Icon Backdrop
        if not icon.tuiBackdrop then
            icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
            icon.tuiBackdrop:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
            icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
            icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        icon.tuiBackdrop:Show()
        icon.tuiBackdrop:SetAllPoints(icon)
        icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
        
        -- Icon Position
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        
        barOffset = height + (db.iconSpacing or 3)
    elseif icon then
        icon:Hide()
        barOffset = 0
    end
    
    -- 3. BAR BACKDROP POSITIONING
    childFrame.tuiBackdrop:Show()
    childFrame.tuiBackdrop:ClearAllPoints()
    childFrame.tuiBackdrop:SetPoint("TOPLEFT", childFrame, "TOPLEFT", barOffset, 0)
    childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)

    -- 4. BAR POSITIONING (Inset inside the bar backdrop)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", childFrame.tuiBackdrop, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)
    
    -- Show Name logic
    local font = LSM:Fetch("font", db.font)
    if bar.Name then
        if db.showName then
            bar.Name:Show()
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:ClearAllPoints()
            bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 4, db.nameYOffset or 0)
        else
            bar.Name:Hide()
        end
    end
    
    -- Show Duration logic
    if bar.Duration then
        if db.showDuration then
            bar.Duration:Show()
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:ClearAllPoints()
            bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
        else
            bar.Duration:Hide()
        end
    end
    
    -- Statusbar Texture & Colors
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then bar:SetStatusBarColor(GetClassColor()) else bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b) end
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
    
    -- Fonts
    local font = LSM:Fetch("font", db.font)
    if bar.Name then bar.Name:SetFont(font, db.fontSize, db.fontOutline) end
    if bar.Duration then bar.Duration:SetFont(font, db.fontSize, db.fontOutline) end
end

-- Main update for a single special bar slot
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

    -- STRICT SIZING: Do not guess borders. Use raw values.
    local effectiveWidth = db.width
    if db.inheritWidth and anchorFrame then
        local aw = anchorFrame:GetWidth()
        if aw and aw > 0 then 
            effectiveWidth = aw + (db.inheritWidthOffset or 0)
        end
    end

    local effectiveHeight = db.height
    if db.inheritHeight and anchorFrame then
        local ah = anchorFrame:GetHeight()
        if ah and ah > 0 then 
            effectiveHeight = ah + (db.inheritHeightOffset or 0)
        end
        -- Sync the DB height so StyleSpecialBar uses the correct value for Icon size
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
        ScanAndHookCDMChildren()
        childFrame = FindBarBySpellName(db.spellName)
    end
    
    local wrapper = GetOrCreateWrapper(barKey)
    
    -- Apply strict sizing to wrapper
    wrapper:SetSize(effectiveWidth, effectiveHeight)
    
    pcall(function()
        if anchorFrame then
            wrapper:ClearAllPoints()
            wrapper:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
        end
    end)
    
    -- Placeholder logic (Backdrop)
    if wrapper.backdrop then
        if db.showBackdrop and (not childFrame or not childFrame:IsShown()) then
            wrapper.backdrop:Show()
            wrapper:Show()
            
            -- Adjust placeholder to match the split layout (Only show "Bar" area)
            local bc = db.backdropColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
            wrapper.backdrop:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
            wrapper.backdrop:ClearAllPoints()
            local phOffset = 0
            if db.iconEnabled then
                phOffset = effectiveHeight + (db.iconSpacing or 3)
            end
            wrapper.backdrop:SetPoint("TOPLEFT", wrapper, "TOPLEFT", phOffset, 0)
            wrapper.backdrop:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 0, 0)
            
        else
            wrapper.backdrop:Hide()
            if not childFrame then wrapper:Hide() end
        end
    end
    
    -- No child frame? We are done (just showed placeholder if needed)
    if not childFrame then
        if not specialBarState[barKey] then specialBarState[barKey] = { wrapper = wrapper } end
        return
    end
    
    local isActive = false
    pcall(function() isActive = childFrame:IsShown() end)
    yoinkedBars[childFrame] = true
    
    if not isActive then
        return
    end

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
    
    -- Parent the child to the wrapper
    pcall(function()
        if childFrame:GetParent() ~= wrapper then childFrame:SetParent(wrapper) end
        
        -- Resize the actual childFrame to match wrapper exactly
        childFrame:SetSize(effectiveWidth, effectiveHeight)
        
        childFrame:ClearAllPoints()
        childFrame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    end)
    
    -- Apply styling (texture, icon pos, etc)
    pcall(StyleSpecialBar, childFrame, db)
    wrapper:Show()
end

local function SpecialBarOnUpdate()
    -- This is only used when buff bar skinning is disabled but special bars are active
    local currentTime = GetTime()
    if currentTime < specialBarNextUpdate then return end
    specialBarNextUpdate = currentTime + specialBarThrottle
    
    if not E.db.thingsUI or not E.db.thingsUI.specialBars then return end
    if not BuffBarCooldownViewer then return end
    
    -- Periodically scan for new CDM children (catches first-time spell casts)
    ScanAndHookCDMChildren()
    
    local specDB = GetSpecialBarDB()
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" then
            pcall(UpdateSpecialBarSlot, barKey)
        end
    end
end

function TUI:UpdateSpecialBars()
    if not E.db.thingsUI.specialBars then return end
    
    -- Hook existing CDM children immediately so we catch OnShow events
    ScanAndHookCDMChildren()
    
    local specDB = GetSpecialBarDB()
    local anyEnabled = false
    
    -- First release any bars from OTHER specs that might be yoinked
    for barKey, state in pairs(specialBarState) do
        local db = specDB[barKey]
        if not db or not db.enabled or not db.spellName or db.spellName == "" then
            ReleaseSpecialBar(barKey)
        end
    end
    
    for barKey, barDB in pairs(specDB) do
        if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
            anyEnabled = true
        else
            if type(barDB) == "table" then
                ReleaseSpecialBar(barKey)
            end
        end
    end
    
    if anyEnabled then
        if not E.db.thingsUI.buffBars or not E.db.thingsUI.buffBars.enabled then
            specialBarUpdateFrame:SetScript("OnUpdate", SpecialBarOnUpdate)
        end
        barUpdateFrame:SetScript("OnUpdate", BuffBarOnUpdate)
        
        -- Schedule additional scans to catch CDM children created after init
        -- CDM may create bar frames slightly later during loading
        for _, delay in ipairs({ 0.5, 1.0, 2.0, 5.0 }) do
            C_Timer.After(delay, function()
                ScanAndHookCDMChildren()
                -- Also try to yoink immediately on each delayed scan
                local currentSpecDB = GetSpecialBarDB()
                for barKey, barDB in pairs(currentSpecDB) do
                    if type(barDB) == "table" and barDB.enabled and barDB.spellName and barDB.spellName ~= "" then
                        pcall(UpdateSpecialBarSlot, barKey)
                    end
                end
            end)
        end
    else
        specialBarUpdateFrame:SetScript("OnUpdate", nil)
        for barKey, _ in pairs(specialBarState) do
            ReleaseSpecialBar(barKey)
        end
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
    
    -- Calculate utility width
    local utilityWidth = (utilityCount * db.utilityIconWidth) + (math.max(0, utilityCount - 1) * db.utilityIconPadding)
    
    -- Only add overflow if utility is wider than essential
    local overflow = 0
    local extraUtilityIcons = math.max(0, utilityCount - essentialCount)
    local threshold = db.utilityThreshold or 3
    
    if extraUtilityIcons >= threshold and utilityWidth > essentialWidth then
        -- Calculate how much wider utility is than essential
        local widthDifference = utilityWidth - essentialWidth
        -- Add the configured offset on top of the width difference
        overflow = widthDifference + ((db.utilityOverflowOffset or 25) * 2)
    end
    
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
            playerFrame:SetPoint("RIGHT", EssentialCooldownViewer, "LEFT", -(db.frameGap + sideOverflow), yOffset)
        end
    end
    
    -- Position Target Frame - anchor to right of Essential (plus overflow)
    if db.targetFrame.enabled then
        local targetFrame = _G["ElvUF_Target"]
        if targetFrame then
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint("LEFT", EssentialCooldownViewer, "RIGHT", db.frameGap + sideOverflow, yOffset)
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
    
    -- Position Additional Power Bar - anchor above Player frame (for ferals, etc.)
    if db.additionalPowerBar and db.additionalPowerBar.enabled then
        local playerFrame = _G["ElvUF_Player"]
        local powerBar = _G["ElvUF_Player_AdditionalPowerBar"]
        if playerFrame and powerBar then
            powerBar:ClearAllPoints()
            powerBar:SetPoint("TOP", playerFrame, "BOTTOM", db.additionalPowerBar.xOffset, db.additionalPowerBar.gap)
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
    
    -- Additional Power Bar - anchor to its mover
    local powerBar = _G["ElvUF_Player_AdditionalPowerBar"]
    local powerBarMover = _G["ElvUF_AdditionalPowerBarMover"]
    if powerBar and powerBarMover then
        powerBar:ClearAllPoints()
        powerBar:SetPoint("CENTER", powerBarMover, "CENTER", 0, 0)
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
    local threshold = db.utilityThreshold or 3
    local triggered = extraIcons >= threshold
    
    -- Calculate widths for debug
    local essentialWidth = (essentialCount * db.essentialIconWidth) + (math.max(0, essentialCount - 1) * db.essentialIconPadding)
    local utilityWidth = (utilityCount * db.utilityIconWidth) + (math.max(0, utilityCount - 1) * db.utilityIconPadding)
    
    print(string.format("|cFF8080FFElvUI_thingsUI|r - Essential: %d (%dpx), Utility: %d (%dpx), +%d extra", 
        essentialCount, essentialWidth, utilityCount, utilityWidth, extraIcons))
    print(string.format("|cFF8080FFElvUI_thingsUI|r - Threshold: %d, %s, Overflow: %dpx (each side: %dpx)", 
        threshold, triggered and "|cFF00FF00TRIGGERED|r" or "|cFFFF0000not triggered|r", overflow, overflow/2))
end

-------------------------------------------------
-- MODULE INITIALIZATION
-------------------------------------------------
function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)
    
    -- Start-clean
    wipe(skinnedBars)
    wipe(yoinkedBars)

    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        -- Tømme driten, om det ikke virker dreper jeg noen. Ingame.
        wipe(skinnedBars)
        
        C_Timer.After(2, function()
            wipe(skinnedBars)
            wipe(yoinkedBars)
            
            -- Finn rammene CDM har laget mens vi ventet
            ScanAndHookCDMChildren()
            
            -- Oppdater i rekkefølge
            local specDB = GetSpecialBarDB()
            for barKey in pairs(specDB) do UpdateSpecialBarSlot(barKey) end
            
            TUI:UpdateBuffBars()
            TUI:UpdateVerticalBuffs()
            TUI:UpdateClusterPositioning()
            
        end)
    end)
    
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        C_Timer.After(1, function() 
            wipe(skinnedBars)
            wipe(yoinkedBars)
            TUI:UpdateSpecialBars() 
            TUI:UpdateBuffBars()
        end)
    end)
    
    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded - Config in /elvui -> thingsUI")
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
                            db.inheritWidthOffset = 1
                            db.height = 23
                            db.spacing = 3
                            db.statusBarTexture = "ElvUI Blank"
                            db.useClassColor = true
                            db.iconEnabled = true
                            db.iconSpacing = 4
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
                            db.anchorXOffset = -0.5
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
                            db.inheritWidthOffset = 3
                            db.height = 23
                            db.spacing = 3
                            db.statusBarTexture = "ElvUI Blank"
                            db.useClassColor = true
                            db.iconEnabled = true
                            db.iconSpacing = 4
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
                            db.anchorXOffset = -0.5
                            db.anchorYOffset = -3
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
    wipe(skinnedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
end

local function OnProfileChanged()
    TUI:ProfileUpdate()
end

hooksecurefunc(E, "UpdateAll", OnProfileChanged)

-- Initialize when ElvUI is ready
E:RegisterModule(TUI:GetName())