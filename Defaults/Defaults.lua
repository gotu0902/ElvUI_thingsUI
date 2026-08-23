local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)

P["thingsUI"] = P["thingsUI"] or {}
ns.Defaults = ns.Defaults or {}

local p = P["thingsUI"]
p.autoSetAudioChannels  = false
p.rightChatAsBackground = false
p.rightChatWidthOffset  = 0
p.rightChatHeightOffset = 0
p.mbb = {
    manage = true,
    anchor = "Minimap",
    point = "TOPRIGHT",
    x = 1,
    y = 39,
    skin = true,
    scale = 1.02,
    mouseover = true,
    hideMain = true,
    seeded = false,
}
p.instanceDifficulty = {
    enable = true,
    point = "bottom",
    x = 0,
    y = 10,
    font = "Expressway",
    fontSize = 12,
    fontOutline = "OUTLINE",
}
