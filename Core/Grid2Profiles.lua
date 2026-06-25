local _, ns = ...
local E = ns.E

ns.GRID2_PROFILES = ns.GRID2_PROFILES or {}

local function IsInstalled(addon)
    local n, _, _, _, reason = C_AddOns.GetAddOnInfo(addon)
    return n ~= nil and reason ~= "MISSING"
end
ns.IsAddOnInstalled = ns.IsAddOnInstalled or IsInstalled
ns.IsAddOnEnabled = ns.IsAddOnEnabled or function(addon) return E.IsAddOnEnabled and E:IsAddOnEnabled(addon) end

function ns.FindGrid2Profile(key)
    for _, p in ipairs(ns.GRID2_PROFILES) do if p.key == key then return p end end
end

function ns.ImportGrid2Profile(key)
    if not IsInstalled("Grid2") then print("|cFF8080FFthingsUI|r: Grid2 is not installed."); return end
    local p = ns.FindGrid2Profile(key)
    if not (p and p.data and p.data:gsub("%s", "") ~= "") then
        print("|cFF8080FFthingsUI|r: Grid2 profile '" .. tostring(key) .. "' has no data yet.")
        return
    end
    if not C_AddOns.IsAddOnLoaded("Grid2Options") then C_AddOns.LoadAddOn("Grid2Options") end
    local Grid2 = _G.Grid2
    local importer = Grid2 and (Grid2.ImportProfileIntoKey or Grid2.ImportCurrentProfile)
    if not importer then
        print("|cFF8080FFthingsUI|r: Grid2 import API unavailable (open Grid2's options once, then retry).")
        return
    end
    local ok = importer(p.name, p.data, true, false)
    if ok then print("|cFF8080FFthingsUI|r - Grid2 profile '" .. p.name .. "' imported + activated.") end
    return ok
end

E.PopupDialogs["TUI_IMPORT_GRID2"] = {
    text = "Import + switch to the |cFF8080FFthingsUI|r Grid2 profile\n|cFFFFFFFF%s|r?",
    button1 = YES, button2 = CANCEL,
    OnAccept = function(_, key) ns.ImportGrid2Profile(key) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
function ns.ImportGrid2ProfileConfirm(key, label)
    E:StaticPopup_Show("TUI_IMPORT_GRID2", label or key, nil, key)
end
