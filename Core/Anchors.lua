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

-- Frame strata values for the dropdown shared by every module that exposes a strata option.
ns.STRATA = ns.STRATA or {}
ns.STRATA.VALUES = {
  BACKGROUND        = "Background",
  LOW               = "Low",
  MEDIUM            = "Medium",
  HIGH              = "High",
  DIALOG            = "Dialog",
  FULLSCREEN        = "Fullscreen",
  FULLSCREEN_DIALOG = "Fullscreen Dialog",
  TOOLTIP           = "Tooltip",
}
ns.STRATA.ORDER = {
  "BACKGROUND", "LOW", "MEDIUM", "HIGH",
  "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
}