local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].clusterPositioning = {
    enabled              = false,
    essentialIconPadding = 1,
    utilityIconPadding   = 1,
    accountForUtility    = true,
    utilityThreshold     = 3,
    utilityOverflowOffset = 25,
    frameGap             = 20,
    playerFrame     = { enabled = true },
    targetFrame     = { enabled = true },
    targetTargetFrame = { enabled = true, gap = 1 },
    targetCastBar   = { enabled = true, gap = 1, xOffset = 0 },
    additionalPowerBar = { enabled = false, gap = 4, xOffset = 0 },
}
