-- Core/Anchors.lua
local _, ns = ...
ns.ANCHORS = ns.ANCHORS or {}

ns.ANCHORS.SHARED_ANCHOR_VALUES = {
  ["ElvUF_Player"]         = "ElvUI Player Frame",
  ["ElvUF_Target"]         = "ElvUI Target Frame",
  ["ElvUF_Player_ClassBar"]= "ElvUI Class Bar",
  ["EssentialCooldownViewer"] = "Essential Cooldowns",
  ["UtilityCooldownViewer"]   = "Utility Cooldowns",
  ["BuffIconCooldownViewer"] = "Buff Icon Bar",
  ["BCDM_PowerBar"]        = "BCDM Power Bar",
  ["BCDM_SecondaryPowerBar"]        = "BCDM Secondary Power Bar",
  ["BCDM_CastBar"]        = "BCDM Cast Bar",
  ["Grid2LayoutFrame"]   = "Grid2 Layout Frame",
  ["UIParent"]             = "Screen (UIParent)",
  ["CUSTOM"]               = "|cFFFFFF00Custom Frame...|r",
}

ns.ANCHORS.SHARED_ANCHOR_ORDER = {
  "ElvUF_Player", "ElvUF_Target", "ElvUF_Player_ClassBar",
  "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
  "BCDM_PowerBar", "BCDM_SecondaryPowerBar", "BCDM_CastBar", "Grid2LayoutFrame", "UIParent", "CUSTOM",
}

-- Frame anchor points (CENTER, TOPLEFT, ...) shared by every dropdown that picks
-- a SetPoint corner. Title Case for display; keys are the actual point strings
-- passed to SetPoint.
ns.POINTS = ns.POINTS or {}
ns.POINTS.VALUES = {
  CENTER      = "CENTER",
  TOP         = "TOP",
  BOTTOM      = "BOTTOM",
  LEFT        = "LEFT",
  RIGHT       = "RIGHT",
  TOPLEFT     = "TOPLEFT",
  TOPRIGHT    = "TOPRIGHT",
  BOTTOMLEFT  = "BOTTOMLEFT",
  BOTTOMRIGHT = "BOTTOMRIGHT",
}
ns.POINTS.ORDER = {
  "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

-- Frame strata values for the dropdown shared by every module that exposes a strata option.
ns.STRATA = ns.STRATA or {}
ns.STRATA.VALUES = {
  BACKGROUND        = "BACKGROUND",
  LOW               = "LOW",
  MEDIUM            = "MEDIUM",
  HIGH              = "HIGH",
  DIALOG            = "DIALOG",
  TOOLTIP           = "TOOLTIP",
}
ns.STRATA.ORDER = {
  "BACKGROUND", "LOW", "MEDIUM", "HIGH",
  "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}