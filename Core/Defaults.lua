local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
local TUI = ns.TUI

P["thingsUI"] = {
    verticalBuffs = false,
    autoSetAudioChannels = false,
    rightChatAsBackground = false,
    rightChatWidthOffset = 0,
    rightChatHeightOffset = 0,

    trinketsCDM = {
        enabled  = false,
        mode     = "NHT",   -- "NHT" or "FHT"
        side     = "RIGHT",  -- "RIGHT" or "LEFT" (NHT + FHT-in-essential side)
        fhtLimit = 9,        -- max combined essential+trinket count before overflow
        gap      = 1,        -- pixel gap between Essential and trinket bar
    },

    buffBars = {
        enabled            = false,
        growthDirection    = "UP",
        width              = 240,
        height             = 23,
        spacing            = 1,
        statusBarTexture   = "ElvUI Blank",
        font               = "Expressway",
        fontSize           = 14,
        fontOutline        = "OUTLINE",
        iconEnabled        = true,
        iconSpacing        = 1,
        iconZoom           = 0.1,
        inheritWidth       = true,
        inheritWidthOffset = 0,
        stackFontSize      = 15,
        stackFontOutline   = "OUTLINE",
        stackPoint         = "CENTER",
        stackAnchor        = "ICON",
        stackXOffset       = 0,
        stackYOffset       = 0,
        namePoint          = "LEFT",
        nameXOffset        = 2,
        nameYOffset        = 0,
        durationPoint      = "RIGHT",
        durationXOffset    = -4,
        durationYOffset    = 0,
        backgroundColor    = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        useClassColor      = true,
        customColor        = { r = 0.2, g = 0.6, b = 1.0 },
        anchorEnabled      = true,
        anchorFrame        = "ElvUF_Player",
        anchorPoint        = "BOTTOM",
        anchorRelativePoint = "TOP",
        anchorXOffset      = 0,
        anchorYOffset      = 50,
    },

    clusterPositioning = {
        enabled              = false,
        essentialIconWidth   = 42,
        essentialIconPadding = 1,
        utilityIconWidth     = 35,
        utilityIconPadding   = 1,
        accountForUtility    = true,
        utilityThreshold     = 3,
        utilityOverflowOffset = 25,
        yOffset              = 0,
        frameGap             = 20,
        playerFrame     = { enabled = true },
        targetFrame     = { enabled = true },
        targetTargetFrame = { enabled = true, gap = 1 },
        targetCastBar   = { enabled = true, gap = 1, xOffset = -17 },
        additionalPowerBar = { enabled = false, gap = 4, xOffset = 0 },
    },

    dynamicCastBarAnchor = {
        enabled       = false,
        point         = "BOTTOM",
        relativePoint = "TOP",
        xOffset       = 0,
        yOffset       = 1,
    },

    -- Per-spec ElvUI classbar enable. The classbar is placed where the
    -- BCDM power / secondary power bar would sit, inheriting the Essential
    -- Cooldown Viewer width.
    classbarMode = {
        enabled       = false,
        widthOffset   = 0,
        xOffset       = 0,
        yOffset       = 1,
        gap           = 1, -- spacing between classbar and the frame below it
        specs         = {}, -- [specIDstring] = { slot = "SECONDARY" or "POWER" }
    },

    -- specialBars: per-spec storage only.
    -- barCount / iconCount / bars{} / icons{} are created lazily in SpecialBars.lua
    -- via GetSpecRoot() so no defaults are needed here beyond the top-level container.
    specialBars = {
        specs = {},
    },
}