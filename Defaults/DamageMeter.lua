local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].damageMeter = {
    provider = "DETAILS",
    styleBars = true,
    font = "Expressway",
    fontSize = 12,
    valueFontSize = 12,
    fontOutline = "OUTLINE",
    fontShadow = false,
    headerFontSize = 12,
    barTexture = "",
    iconBorder = true,
    iconBorderSize = 1,
    iconBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    barLayout = false,
    iconGap = 4,
    hideGearMenu = false,
    windowGap = 4,
}
