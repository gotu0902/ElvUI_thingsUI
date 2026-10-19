local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local MAX_ROWS = 40
local CG_X = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t"

local function SpellLabel(id)
    local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    local tex = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
    return ("|T%d:16:16|t %s |cFF888888%d|r"):format(tex or 134400, nm or "Spell", id)
end

local function SpellIDFrom(v)
    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local id = tonumber(v)
    if not id and v ~= "" and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(v)
        id = info and info.spellID
    end
    if id and C_Spell.GetSpellName and C_Spell.GetSpellName(id) then return id end
end

local function CollectionTab(order, key)
    local AC = ns.AuraCollections
    local function isFilter() return AC.Source(key) == "filter" end
    local function ids()
        local out = {}
        for id in pairs(AC.OwnList(key)) do out[#out + 1] = id end
        table.sort(out)
        return out
    end

    local rows = {}
    for ri = 1, MAX_ROWS do
        local function rowID() return ids()[ri] end
        local hidden = function() return rowID() == nil end
        rows["r" .. ri] = {
            order = ri, type = "description", width = 1.6, fontSize = "medium", hidden = hidden,
            name = function() local id = rowID() return id and SpellLabel(id) or "" end,
        }
        rows["x" .. ri] = {
            order = ri + 0.1, type = "execute", width = 0.3, name = CG_X, hidden = hidden,
            func = function() local id = rowID() if id then AC.RemoveSpell(key, id) end end,
        }
        rows["b" .. ri] = { order = ri + 0.2, type = "description", name = "", width = "full", hidden = hidden }
    end
    rows.empty = {
        order = 0, type = "description",
        name = function() return isFilter() and "|cFF888888Nothing excluded.|r" or "|cFF888888No spells yet.|r" end,
        hidden = function() return ids()[1] ~= nil end,
    }

    local elvValues = function()
        local out = { [""] = "None" }
        for _, name in ipairs(AC.ElvFilterNames()) do out[name] = name end
        return out
    end
    local elvSorting = function()
        local out = { "" }
        for _, name in ipairs(AC.ElvFilterNames()) do out[#out + 1] = name end
        return out
    end
    local filterValues = {}
    for token, f in pairs(AC.FILTERS) do filterValues[token] = f.name end

    return {
        order = order, type = "group",
        name = function()
            local c = AC.Get(key)
            return ns.TabName(c and c.name or key, (AC.Raw(key) or {}).tabColor)
        end,
        args = {
            name = {
                order = 1, type = "input", name = "Name",
                get = function() local c = AC.Get(key) return c and c.name or "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    local raw = AC.Raw(key, true)
                    if not raw then return end
                    -- a built-in goes back to its own name when cleared
                    if v == "" then
                        if not AC.Preset(key) then return end
                        raw.name = nil
                    else
                        raw.name = v
                    end
                    AC.Changed()
                end,
            },
            tabColorOn = (ns.TabColorArgs(function(create) return AC.Raw(key, create) end, ns.NotifyChange, 1.5)),
            tabColor = select(2, ns.TabColorArgs(function(create) return AC.Raw(key, create) end, ns.NotifyChange, 1.5)),
            source = {
                order = 2, type = "select", name = "Source",
                values = { spells = "Spell List", filter = "Blizzard Filter" }, sorting = { "spells", "filter" },
                get = function() return AC.Source(key) end,
                set = function(_, v) AC.Raw(key, true).source = v; AC.Changed() end,
            },
            filter = {
                order = 3, type = "multiselect", name = "Blizzard Filters",
                values = filterValues,
                hidden = function() return not isFilter() end,
                get = function(_, t) return AC.HasFilter(key, t) end,
                set = function(_, t, v) AC.SetFilter(key, t, v) end,
            },
            brk = { order = 4, type = "description", name = "", width = "full" },
            add = {
                order = 5, type = "input",
                name = function() return isFilter() and "Leave Out Spell (ID or name)" or "Add Spell (ID or name)" end,
                get = function() return "" end,
                set = function(_, v)
                    local id = SpellIDFrom(v)
                    if id then AC.AddSpell(key, id) end
                end,
            },
            elv = {
                order = 6, type = "select",
                name = function() return isFilter() and "Leave Out an ElvUI Filter" or "Add an ElvUI Filter" end,
                values = elvValues, sorting = elvSorting,
                get = function() local raw = AC.Raw(key) return (raw and raw.elvFilter) or "" end,
                set = function(_, v) AC.Raw(key, true).elvFilter = (v ~= "") and v or nil; AC.Changed() end,
            },
            list = {
                order = 10, type = "group", inline = true,
                name = function() return isFilter() and "Left Out" or "Spells" end,
                args = rows,
            },
            used = {
                order = 20, type = "description", width = "full",
                name = function()
                    local u = AC.UsedBy(key)
                    if #u == 0 then return "\n|cFF888888Not used by any group yet.|r" end
                    return "\n|cFFFFD200Used by|r\n" .. table.concat(u, "\n")
                end,
            },
            reset = {
                order = 30, type = "execute", name = "Reset to Default",
                hidden = function() return AC.Preset(key) == nil end,
                disabled = function() return AC.Raw(key) == nil end,
                confirm = true, confirmText = "Undo your changes to this collection?",
                func = function() AC.Reset(key) end,
            },
            delete = {
                order = 31, type = "execute", name = "Delete Collection",
                hidden = function() return AC.Preset(key) ~= nil end,
                confirm = true,
                confirmText = "Delete this collection? Groups using a spell list keep a copy of it.",
                func = function() AC.Delete(key) end,
            },
        },
    }
end

function TUI:AuraCollectionsOptions()
    local AC = ns.AuraCollections
    local args = {
        desc = {
            order = 1, type = "description",
            name = "Aura lists for Groups - Icons and Groups - Bars (their Auras tab). Groups follow a collection, so a change here reaches every group using it. A Blizzard Filter matches inside the game client, like ElvUI's filter strings: no list to keep up to date. Several filters show auras matching any of them.\n",
        },
        new = {
            order = 2, type = "input", name = "New Collection",
            get = function() return "" end,
            set = function(_, v) AC.Create(v) end,
        },
    }
    local function Fill()
        for k in pairs(args) do
            if k:sub(1, 4) == "col_" then args[k] = nil end
        end
        -- tabs by name, built-ins and your own mixed (renames resort on the next rebuild)
        local list = AC.List()
        table.sort(list, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
        for i, c in ipairs(list) do
            args["col_" .. c.key] = CollectionTab(10 + i, c.key)
        end
    end
    AC._rebuildOptions = Fill
    Fill()
    return {
        order = 0.5, type = "group", name = "Aura Collections", childGroups = "tab",
        args = args,
    }
end
