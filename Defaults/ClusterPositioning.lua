local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

P["thingsUI"].clusterPositioning = {
    enabled              = false,
    accountForUtility    = true,
    utilityThreshold     = 3,
    utilityOverflowOffset = 10,
    frameGap             = 20,
    playerFrame     = { enabled = true },
    targetFrame     = { enabled = true },
    targetTargetFrame = { enabled = true, gap = 1 },
    targetCastBar   = { enabled = true, gap = 1, xOffset = 0 },
    additionalPowerBar = { enabled = false, gap = 4, xOffset = 0 },
    focusFrame = {
        enabled = false,
        anchorFrame = "ElvUF_Target",
        anchorPoint = "TOP", anchorRelativePoint = "BOTTOM",
        xOffset = 0, yOffset = -10,
        matchWidth = true,
    },
    focusCastBar = {
        enabled = false,
        anchorPoint = "TOP", anchorRelativePoint = "BOTTOM",
        xOffset = 0, yOffset = -1,
    },
}
