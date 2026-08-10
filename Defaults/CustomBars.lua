local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)

P["thingsUI"] = P["thingsUI"] or {}
P["thingsUI"].customBars = { groups = {}, nextID = 1 }

ns.CUSTOM_BAR_GROUP_DEFAULTS = {
    name = "Bar Group",
    enabled = true,
    width = 220,
    height = 22,
    spacing = 2,
    growth = "DOWN",
    unit = "player",
    statusBarTexture = "ElvUI Norm",
    useClassColor = true,
    customColor = { r = 0.2, g = 0.6, b = 1 },
    iconEnabled = true,
    iconSpacing = 1,
    iconZoom = 0.1,
    font = "Expressway",
    fontSize = 12,
    fontOutline = "OUTLINE",
    showName = true,
    namePoint = "LEFT",
    nameXOffset = 4,
    nameYOffset = 0,
    showDuration = true,
    durationPoint = "RIGHT",
    durationXOffset = -4,
    durationYOffset = 0,
    showStacks = true,
    stackFontSize = 12,
    stackPoint = "CENTER",
    stackXOffset = 0,
    stackYOffset = 0,
    anchorFrame = "UIParent",
    anchorPoint = "CENTER",
    anchorRelativePoint = "CENTER",
    anchorXOffset = 0,
    anchorYOffset = -250,
    auras = {},
}
