local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].classbarMode = {
    enabled       = false,
    frameStrata   = "MEDIUM",
    widthOffset   = 0,
    xOffset       = 0,
    yOffset       = 1,
    gap           = 1,
    specs         = {},
    dynamicClassbar = false,
}
