local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
P["thingsUI"] = P["thingsUI"] or {}

-- Per-setup/bar templates -> Modules/Bars/BarSetup.lua cus BAR_KEYS

P["thingsUI"].barSetup = {
    enabled = true,
    active = 1,
    setups = {},
}
