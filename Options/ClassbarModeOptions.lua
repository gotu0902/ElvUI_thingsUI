local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local function GetSelectedSpecIDs()
    local db = E.db.thingsUI.classbarMode
    if not db or not db.specs then return {} end
    local out = {}
    for key in pairs(db.specs) do
        local id = tonumber(key)
        if id then out[id] = true end
    end
    return out
end

local function CascadeKeyToSpecKey(value)
    local _, specID = value:match("^([A-Z_]+):(%d+)$")
    return specID
end

local function CurrentSpecID()
    local idx = GetSpecialization and GetSpecialization()
    return idx and (select(1, GetSpecializationInfo(idx))) or nil
end

function TUI:ClassbarModeOptions()
    return {
        order = 52,
        type = "group",
        name = "Classbar",
        childGroups = "tab",
        args = {
            enabled = {
                order = 1, type = "toggle", name = "Enable Classbar Mode",
                width = "full",
                get = function() return E.db.thingsUI.classbarMode.enabled end,
                set = function(_, v)
                    E.db.thingsUI.classbarMode.enabled = v
                    TUI:UpdateClassbarMode()
                end,
            },

            dynamicClassbar = {
                order = 2, type = "toggle", name = "Dynamic Classbar",
                get = function() return E.db.thingsUI.classbarMode.dynamicClassbar end,
                set = function(_, v)
                    E.db.thingsUI.classbarMode.dynamicClassbar = v
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                end,
            },
            dynamicClassbarDesc = {
                order = 2.1, type = "description", width = "full", fontSize = "small",
                name = "|cFFAAAAAAWhen enabled, the combo points bar will take its place in the bar setup when in cat form by moving bars above it up.|r",
            },

            specPickerBreak = {
                order = 2.5, type = "description", width = "full", name = "",
            },
            specPicker = {
                order = 3, type = "multiselect", name = "Add / Remove Specs",
                desc = "",
                width = 2.0,
                dialogControl = "TUI_CascadeDropdown",
                values = function() return ns.CascadeDropdown.AllSpecs() end,
                get = function(_, value)
                    local specKey = CascadeKeyToSpecKey(value)
                    if not specKey then return false end
                    local db = E.db.thingsUI.classbarMode
                    return db and db.specs and db.specs[specKey] ~= nil
                end,
                set = function(_, value, checked)
                    local specKey = CascadeKeyToSpecKey(value)
                    if not specKey then return end
                    local db = E.db.thingsUI.classbarMode
                    db.specs = db.specs or {}
                    if checked then
                        db.specs[specKey] = db.specs[specKey] or { slot = "SECONDARY" }
                    else
                        db.specs[specKey] = nil
                    end
                    if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                    NotifyChange()
                end,
            },

            addCurrent = {
                order = 4, type = "execute",
                name = function()
                    local m = ns.SpecMeta and ns.SpecMeta(CurrentSpecID())
                    if not m then return "Add Current Spec" end
                    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.classToken]
                    local hex = (c and c.colorStr) or "ffffffff"
                    local icon = m.icon and ("|T%d:16:16:0:0:64:64:4:60:4:60|t "):format(m.icon) or ""
                    return ("%sAdd |c%s%s %s|r"):format(icon, hex, m.name, m.className)
                end,
                disabled = function()
                    local id = CurrentSpecID()
                    if not id then return true end
                    local db = E.db.thingsUI.classbarMode
                    return db and db.specs and db.specs[tostring(id)] ~= nil
                end,
                func = function()
                    local id = CurrentSpecID()
                    if not id then return end
                    local db = E.db.thingsUI.classbarMode
                    db.specs = db.specs or {}
                    db.specs[tostring(id)] = db.specs[tostring(id)] or { slot = "SECONDARY" }
                    if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                    NotifyChange()
                end,
            },

            enabledList = {
                order = 20, type = "group", inline = true, name = " ",
                args = ns.ActiveSpecsList.BuildDynamic({
                    selected = GetSelectedSpecIDs,
                    onRemove = function(specID)
                        local db = E.db.thingsUI.classbarMode
                        if db and db.specs then
                            db.specs[tostring(specID)] = nil
                            if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                            if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                            NotifyChange()
                        end
                    end,
                    emptyText = "No specs enabled. Use the dropdown above to add some.",
                }),
            },
        },
    }
end
