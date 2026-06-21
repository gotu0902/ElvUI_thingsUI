local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}
ns.Defaults = ns.Defaults or {}

P["thingsUI"].timers = {
    list   = {},
    nextID = 1,
}

function ns.Defaults.Timer(id)
    return {
        id                  = id,
        enabled             = true,
        kind                = "item",
        itemID              = nil,
        spellID             = nil,
        durationAuto        = true,
        duration            = nil,
        showCDTimer         = true,
        trackCooldown       = true,
        showIdle            = true,
        glowReadyInCombat   = false,
        glowWhen            = "active",
        glowType            = "pixel",
        glowColor           = { r = 1, g = 1, b = 0, a = 1 },
        glowThickness       = 2,
        glowLength          = 10,
        glowN               = 8,
        glowFrequency       = 0.25,
        glowXOffset         = 0,
        glowYOffset         = 0,
        destination         = nil,
        groupScope          = "global",
        order               = id,
        iconSize            = 36,
        anchorFrame         = "UIParent",
        anchorFrameCustom   = "",
        anchorPoint         = "CENTER",
        anchorRelativePoint = "CENTER",
        anchorXOffset       = 0,
        anchorYOffset       = 0,
        text = {
            showCooldown        = true,
            cooldownFont        = "Expressway",
            cooldownFontSize    = 16,
            cooldownFontOutline = "OUTLINE",
            cooldownColor       = { r = 1, g = 1, b = 1 },
            cooldownPoint       = "CENTER",
            cooldownXOffset     = 0,
            cooldownYOffset     = 0,
            showCount           = false,
            countFont           = "Expressway",
            countFontSize       = 12,
            countFontOutline    = "OUTLINE",
            countColor          = { r = 1, g = 1, b = 1 },
            countPoint          = "BOTTOMRIGHT",
            countXOffset        = -1,
            countYOffset        = 1,
        },
    }
end
