local _, ns = ...

-- the Visibility tab of a group, Aura Icon or Aura Bar; vis() returns its (created) rules table
function ns.VisibilityArgs(vis, onChange)
    local V = ns.Visibility
    local function off() return not vis().enabled end
    local function set(k, v) vis()[k] = v; onChange() end
    local function multi(key, order, name, values, hidden)
        return {
            order = order, type = "multiselect", name = name, values = values,
            hidden = hidden or off,
            get = function(_, k) local t = vis()[key] return (t and t[k]) and true or false end,
            set = function(_, k, v)
                local t = vis()[key] or {}
                t[k] = v or nil
                vis()[key] = next(t) and t or nil
                onChange()
            end,
        }
    end
    local function toggle(key, order, name, default)
        return {
            order = order, type = "toggle", name = name, hidden = off,
            get = function()
                local v = vis()[key]
                if v == nil then return default or false end
                return v
            end,
            set = function(_, v) set(key, v) end,
        }
    end
    return {
        enabled = {
            order = 1, type = "toggle", name = "Use Visibility Rules", width = "full",
            get = function() return vis().enabled or false end,
            set = function(_, v) set("enabled", v) end,
        },
        hint = {
            order = 2, type = "description", hidden = off,
            name = "Every rule you set has to match. Ticked boxes in one list are alternatives, none ticked = anywhere.\n",
        },
        combat = {
            order = 3, type = "select", name = "Show", values = V.COMBAT, sorting = V.COMBAT_ORDER, hidden = off,
            get = function() return vis().combat or "always" end,
            set = function(_, v) set("combat", (v ~= "always") and v or nil) end,
        },
        brk = { order = 4, type = "description", name = "", width = "full", hidden = off },
        solo = toggle("solo", 5, "Solo", true),
        party = toggle("party", 6, "Party", true),
        raid = toggle("raid", 7, "Raid", true),
        places = multi("places", 10, "Only In", V.PLACES),
        forms = multi("forms", 20, "Only in Form", function() return V.FormChoices(vis().forms) end,
            function() return off() or not (V.HasForms() or vis().forms) end),
        hideGrp = {
            order = 30, type = "group", inline = true, name = "Hide When", hidden = off,
            args = {
                hideMounted = toggle("hideMounted", 1, "Mounted"),
                hideNoTarget = toggle("hideNoTarget", 2, "No Target"),
                hideNoEnemy = toggle("hideNoEnemy", 3, "No Enemy Target"),
                hideResting = toggle("hideResting", 4, "Resting"),
            },
        },
    }
end
