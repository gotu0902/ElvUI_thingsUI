local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].comboBars = { bars = {}, nextID = 1 }

ns.COMBO_BAR_DEFAULTS = {
    name = "Combo Bar",
    enabled = true,
    display = "bar",
    showIn = "standalone",
    width = 220,
    height = 12,
    gap = 2,
    statusBarTexture = "ElvUI Norm",
    emptyColor = { r = 0.08, g = 0.08, b = 0.08, a = 0.8 },
    showBorder = true,
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    frameStrata = "MEDIUM",
    font = "Expressway",
    fontSize = 12,
    fontOutline = "OUTLINE",
    justify = "CENTER",
    showLabels = false,
    namePoint = "LEFT",
    nameXOffset = 3,
    nameYOffset = 0,
    nameColor = { r = 1, g = 1, b = 1 },
    dimTextColor = { r = 0.45, g = 0.45, b = 0.45, a = 1 },
    showDuration = false,
    durationPoint = "RIGHT",
    durationXOffset = -3,
    durationYOffset = 0,
    durationColor = { r = 1, g = 1, b = 1 },
    showStacks = false,
    stackFontSize = 12,
    stackFontOutline = "OUTLINE",
    stackPoint = "CENTER",
    stackXOffset = 0,
    stackYOffset = 0,
    stackColor = { r = 1, g = 1, b = 1 },
    textSpacing = 10,
    glowWhen = "off",
    glowCombat = true,
    glowType = "pixel",
    glowColor = { r = 1, g = 0.85, b = 0.2, a = 1 },
    glowThickness = 2,
    glowLength = 3,
    glowLines = 8,
    glowSpeed = 0.25,
    glowOffset = 0,
    anchorFrame = "UIParent",
    anchorPoint = "CENTER",
    anchorRelativePoint = "CENTER",
    anchorXOffset = 0,
    anchorYOffset = -180,
}

ns.COMBO_SEGMENT_COLORS = {
    { r = 0.95, g = 0.3, b = 0.3 },
    { r = 0.35, g = 0.6, b = 1 },
    { r = 0.4, g = 0.9, b = 0.4 },
    { r = 0.95, g = 0.8, b = 0.25 },
    { r = 0.8, g = 0.45, b = 1 },
}

function ns.Defaults.ComboBar(id, name, specID)
    local b = ns.DeepCopy(ns.COMBO_BAR_DEFAULTS)
    b.id = id
    b.name = name or ("Combo Bar " .. id)
    b.specs = (specID and specID > 0) and { [specID] = true } or {}
    b.segments = {}
    return b
end

function ns.Defaults.ComboSegment(i)
    local c = ns.COMBO_SEGMENT_COLORS[((i or 1) - 1) % #ns.COMBO_SEGMENT_COLORS + 1]
    return { lights = "any", side = "auto", pieces = 3, fill = "full", spells = {},
        color = { r = c.r, g = c.g, b = c.b, a = 1 } }
end
