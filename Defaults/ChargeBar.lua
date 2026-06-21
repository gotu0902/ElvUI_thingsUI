local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].chargeBar = {
    enabled       = false,
    frameStrata   = "LOW",
    mode          = "NHT",
    widthOffset   = 0,
    xOffset       = 0,
    gap           = 1,
    height        = 18,
    showTicks     = true,
    tickWidth     = 1,
    tickColor     = { r = 0, g = 0, b = 0, a = 1 },
    rechargeColor   = { r = 0.5, g = 0.5, b = 0.5, a = 0.8 },
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.7 },
    borderColor     = { r = 0, g = 0, b = 0, a = 1 },
    showText        = true,
    textFont        = "Expressway",
    textSize        = 12,
    textOutline     = "OUTLINE",
    anchorFrame         = "UIParent",
    anchorPoint         = "CENTER",
    anchorRelativePoint = "CENTER",
    fhtWidth            = 200,
    fhtXOffset          = 0,
    fhtYOffset          = 0,
    inheritWidth        = false,
    inheritWidthOffset  = 0,
    specs         = {},
}
