local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].trinketsCDM = {
    enabled  = false,
    mode     = "EMBEDDED",
    group    = nil,
    groupPosition = "END",
    attach   = "ESSENTIAL",
    dynamicThreshold = 10,
    essentialSide = "RIGHT",
    utilitySide   = "RIGHT",
    includePassive = false,
    blacklist = {},
    bar = {
        iconSize = 36,
        spacing = 2,
        growth = "RIGHT",
        anchorFrame = "UIParent",
        anchorPoint = "CENTER",
        anchorRelativePoint = "CENTER",
        anchorXOffset = 0,
        anchorYOffset = 0,
        text = {
            showCooldown = true,
            cooldownFont = "Expressway",
            cooldownFontSize = 14,
            cooldownFontOutline = "OUTLINE",
            cooldownColor = { r = 1, g = 1, b = 1 },
            cooldownPoint = "CENTER",
            cooldownXOffset = 0,
            cooldownYOffset = 0,
        },
    },
}
