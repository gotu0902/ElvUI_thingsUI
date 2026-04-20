-- Core/Anchors.lua
local _, ns = ...
ns.ANCHORS = ns.ANCHORS or {}

ns.ANCHORS.SHARED_ANCHOR_VALUES = {
  ["ElvUF_Player"]         = "ElvUI Player Frame",
  ["ElvUF_Target"]         = "ElvUI Target Frame",
  ["ElvUF_Player_ClassBar"]= "ElvUI Class Bar",
  ["EssentialCooldownViewer"] = "Essential Cooldowns",
  ["UtilityCooldownViewer"]   = "Utility Cooldowns",
  ["BCDM_PowerBar"]        = "BCDM Power Bar",
  ["UIParent"]             = "Screen (UIParent)",
  ["CUSTOM"]               = "|cFFFFFF00Custom Frame...|r",
}

-- Ordered list of shared anchor keys (for deterministic sort in dropdowns)
ns.ANCHORS.SHARED_ANCHOR_ORDER = {
  "ElvUF_Player", "ElvUF_Target", "ElvUF_Player_ClassBar",
  "EssentialCooldownViewer", "UtilityCooldownViewer",
  "BCDM_PowerBar", "UIParent", "CUSTOM",
}