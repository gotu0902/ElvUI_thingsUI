local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")

local TUI = E:NewModule("thingsUI", "AceHook-3.0", "AceEvent-3.0")

ns.addon = addon
ns.E = E
ns.EP = EP
ns.TUI = TUI
ns.LSM = E.Libs.LSM

TUI.version = "2.2.4"
TUI.name = "thingsUI"

-- Shared state across files
ns.skinnedBars = ns.skinnedBars or {}
ns.yoinkedBars = ns.yoinkedBars or {}
