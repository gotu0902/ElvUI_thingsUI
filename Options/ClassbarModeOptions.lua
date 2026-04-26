-- ClassbarMode options tab. Per-spec list of which specs should have the
-- ElvUI player classbar enabled and where it should be placed (above primary
-- power or above secondary power slot in the BCDM cluster).

local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local SLOT_VALUES = {
    SECONDARY = "Secondary Power slot",
    POWER     = "Power slot",
}

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

-- Selection state for the "add" controls
local selectedSpecToAdd = ""
local selectedSlotToAdd = "SECONDARY"

local function GetClassFile()
    return E.myclass
end

-- Build a select dict of all specs for current player class that aren't
-- already in the enabled list.
local function GetAvailableSpecChoices()
    local choices = { [""] = "|cFF888888— Select Spec —|r" }
    local db = E.db.thingsUI.classbarMode
    local enabled = (db and db.specs) or {}

    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for i = 1, numSpecs do
        local id, name = GetSpecializationInfo(i)
        if id then
            local key = tostring(id)
            if not enabled[key] then
                choices[key] = name or ("Spec "..key)
            end
        end
    end
    return choices
end

local function GetEnabledSpecsList()
    local db = E.db.thingsUI.classbarMode
    if not db or not db.specs then return {} end
    local list = {}
    for key, entry in pairs(db.specs) do
        local id = tonumber(key)
        local name = "Spec "..key
        local className
        if id and id > 0 then
            local _, sName, _, _, _, _, cName = GetSpecializationInfoByID(id)
            name = sName or name
            className = cName
        end
        list[#list+1] = { key = key, name = name, className = className, slot = entry.slot or "SECONDARY" }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function BuildEnabledArgs()
    -- AceConfig requires args to be a table. Allocate fixed slots (max specs
    -- per class is small) and resolve each slot to the i-th enabled spec at
    -- display time.
    local args = {}

    args.empty = {
        order = 0, type = "description",
        name = "|cFF888888No specs enabled. Use the controls above to add one.|r",
        hidden = function() return #GetEnabledSpecsList() > 0 end,
    }

    for i = 1, 8 do
        local function entry()
            return GetEnabledSpecsList()[i]
        end
        local function entryKey()
            local e = entry(); return e and e.key or nil
        end
        local order = i * 10
        args["hdr"..i] = {
            order = order, type = "header",
            name = function()
                local e = entry()
                if not e then return "" end
                return e.className and (e.className.." - "..e.name) or e.name
            end,
            hidden = function() return entry() == nil end,
        }
        args["slot"..i] = {
            order = order + 1, type = "select", name = "Slot",
            values = SLOT_VALUES,
            hidden = function() return entry() == nil end,
            get = function()
                local k = entryKey(); if not k then return "SECONDARY" end
                return E.db.thingsUI.classbarMode.specs[k].slot or "SECONDARY"
            end,
            set = function(_, v)
                local k = entryKey(); if not k then return end
                E.db.thingsUI.classbarMode.specs[k].slot = v
                if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
            end,
        }
        args["remove"..i] = {
            order = order + 2, type = "execute", name = "Remove",
            hidden = function() return entry() == nil end,
            func = function()
                local k = entryKey(); if not k then return end
                E.db.thingsUI.classbarMode.specs[k] = nil
                if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                NotifyChange()
            end,
        }
    end

    return args
end

function TUI:ClassbarModeOptions()
    return {
        order = 52,
        type = "group",
        name = "Classbar Mode",
        childGroups = "tab",
        args = {
            description = {
                order = 1, type = "description",
                name = "Per-spec ElvUI player classbar enable. When the current spec is in the list below the classbar is enabled, detached, parented to UIParent, and anchored above the BCDM cluster (inheriting the Essential Cooldown Viewer width). The dynamic cast bar will stack above the classbar.\n\n|cFFFF6B6BNote:|r Spec switching only re-applies out of combat.\n\n",
            },
            enabled = {
                order = 2, type = "toggle", name = "Enable Classbar Mode",
                desc = "Master toggle. When off, this module won't touch the ElvUI classbar settings.",
                width = "full",
                get = function() return E.db.thingsUI.classbarMode.enabled end,
                set = function(_, v)
                    E.db.thingsUI.classbarMode.enabled = v
                    TUI:UpdateClassbarMode()
                end,
            },

            addGroup = {
                order = 10, type = "group", inline = true, name = "Add Spec",
                args = {
                    specSelect = {
                        order = 1, type = "select", name = "Spec",
                        values = GetAvailableSpecChoices,
                        get = function() return selectedSpecToAdd end,
                        set = function(_, v) selectedSpecToAdd = v end,
                    },
                    slotSelect = {
                        order = 2, type = "select", name = "Slot",
                        desc = "Where the classbar should sit:\n• Secondary Power slot: above the primary power bar (e.g. Frost Mage icicles).\n• Power slot: above the Essential Cooldown Viewer.",
                        values = SLOT_VALUES,
                        get = function() return selectedSlotToAdd end,
                        set = function(_, v) selectedSlotToAdd = v end,
                    },
                    add = {
                        order = 3, type = "execute", name = "Add",
                        disabled = function() return not selectedSpecToAdd or selectedSpecToAdd == "" end,
                        func = function()
                            if selectedSpecToAdd == "" then return end
                            local db = E.db.thingsUI.classbarMode
                            db.specs = db.specs or {}
                            db.specs[selectedSpecToAdd] = { slot = selectedSlotToAdd or "SECONDARY" }
                            selectedSpecToAdd = ""
                            if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                            NotifyChange()
                        end,
                    },
                },
            },

            enabledList = {
                order = 20, type = "group", inline = true, name = "Enabled Specs",
                args = BuildEnabledArgs(),
            },

            offsetGroup = {
                order = 30, type = "group", inline = true, name = "Position & Width",
                disabled = function() return not E.db.thingsUI.classbarMode.enabled end,
                args = {
                    widthOffset = {
                        order = 1, type = "range", name = "Width Offset",
                        desc = "Pixels added to the inherited Essential Cooldown Viewer width.",
                        min = -200, max = 200, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.classbarMode.widthOffset or 0 end,
                        set = function(_, v)
                            E.db.thingsUI.classbarMode.widthOffset = v
                            if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                        end,
                    },
                    xOffset = {
                        order = 2, type = "range", name = "X Offset",
                        min = -200, max = 200, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.classbarMode.xOffset or 0 end,
                        set = function(_, v)
                            E.db.thingsUI.classbarMode.xOffset = v
                            if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                        end,
                    },
                    gap = {
                        order = 3, type = "range", name = "Gap",
                        desc = "Vertical gap between the classbar and the bar below it.",
                        min = -20, max = 50, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.classbarMode.gap or 1 end,
                        set = function(_, v)
                            E.db.thingsUI.classbarMode.gap = v
                            if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
                        end,
                    },
                },
            },
        },
    }
end
