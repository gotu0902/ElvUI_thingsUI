local _, ns = ...
local TUI = ns.TUI

local function Installed()
    return ns.IsAddOnInstalled and ns.IsAddOnInstalled("Grid2")
end
local function Enabled()
    return ns.IsAddOnEnabled and ns.IsAddOnEnabled("Grid2")
end

function TUI:Grid2Options()
    local args = {
        desc = {
            order = 1, type = "description", fontSize = "medium", width = "full",
            name = "If your class has a healer spec and you use FHT, you need to go Grid2 -> General -> Profiles -> And choose the profile per spec o7.\n\n",
        },
        disabledNote = {
            order = 2, type = "description", width = "full",
            name = "|cFFFF6B6BGrid2 is installed but disabled - enable it and /reload to import.|r\n",
            hidden = function() return Enabled() end,
        },
    }

    -- One inline group per tier (NHT / FHT), buttons in list order.
    local tierGroup, count, order = {}, {}, 10
    for _, p in ipairs(ns.GRID2_PROFILES or {}) do
        if not tierGroup[p.group] then
            tierGroup[p.group] = { order = order, type = "group", inline = true, name = p.group .. " Profiles", args = {} }
            args["grp" .. p.group] = tierGroup[p.group]
            count[p.group] = 0
            order = order + 10
        end
        count[p.group] = count[p.group] + 1
        tierGroup[p.group].args["btn" .. p.key] = {
            order = count[p.group], type = "execute", name = p.label, width = "double",
            disabled = function() return not Enabled() end,
            func = function() if ns.ImportGrid2ProfileConfirm then ns.ImportGrid2ProfileConfirm(p.key, p.name) end end,
        }
    end

    return {
        order = 45, type = "group", name = "Grid2",
        hidden = function() return not Installed() end,
        args = args,
    }
end
