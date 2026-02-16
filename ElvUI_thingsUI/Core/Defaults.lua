local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
local TUI = ns.TUI

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
        stackFontSize = 15  , -- Stack count font size                                                                                                                                                      
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
            xOffset = -17,
        },
        additionalPowerBar = {
            enabled = false,
            gap = 4,
            xOffset = 0,
        },
    },

    -- Dynamic CastBar Anchor (auto-switch between Power Bar and Secondary Power Bar)
    dynamicCastBarAnchor = {
        enabled = false,
        point = "BOTTOM",
        relativePoint = "TOP",
        xOffset = 0,
        yOffset = 1,
    },

    -- Special Bars (yoinked from Tracked Bars) — stored per spec
    specialBars = {
        -- Per-spec storage: specialBars.specs[specID] = { bar1 = {...}, bar2 = {...}, bar3 = {...} etc etc }
        specs = {},
    },
}
