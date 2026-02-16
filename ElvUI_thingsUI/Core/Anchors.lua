-- Core/Anchors.lua
local _, ns = ...
ns.ANCHORS = ns.ANCHORS or {}

ns.ANCHORS.SHARED_ANCHOR_VALUES = {
  ["ElvUF_Player"] = "ElvUI Player Frame",
  ["ElvUF_Target"] = "ElvUI Target Frame",
  ["ElvUF_Player_ClassBar"] = "ElvUI Class Bar",
  ["EssentialCooldownViewer"] = "Essential Cooldowns",
  ["UtilityCooldownViewer"] = "Utility Cooldowns",
  ["BCDM_PowerBar"] = "BCDM Power Bar",
--  ["BCDM_CastBar"] = "BCDM Cast Bar", Kinda bugged if inherit width is on, disabling atm, can just use Essential + y offset.
  ["UIParent"] = "Screen (UIParent)",
  ["CUSTOM"] = "|cFFFFFF00Custom Frame...|r",
}

ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES = {}
for k, v in pairs(ns.ANCHORS.SHARED_ANCHOR_VALUES) do
  ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES[k] = v
end

ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar1"] = "TUI Special Bar 1"
ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar2"] = "TUI Special Bar 2"
ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar3"] = "TUI Special Bar 3"
ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar4"] = "TUI Special Bar 4"
ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES["TUI_SpecialBar_bar5"] = "TUI Special Bar 5"