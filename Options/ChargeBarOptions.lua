local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local SLOT_VALUES = {
    SECONDARY = "Secondary Power slot",
    POWER     = "Power slot",
}

local OUTLINE_VALUES = {
    NONE             = "None",
    OUTLINE          = "Outline",
    THICKOUTLINE     = "Thick Outline",
    MONOCHROMEOUTLINE= "Monochrome Outline",
}

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

local function Update()
    if ns.ChargeBar and ns.ChargeBar.RequestUpdate then ns.ChargeBar.RequestUpdate() end
end

-- Add controls
local selectedSpecToAdd = ""
local selectedSlotToAdd = "SECONDARY"

local function GetClassbarSlot(specKey)
    local cdb = E.db.thingsUI.classbarMode
    if not cdb or not cdb.enabled or not cdb.specs then return nil end
    local entry = cdb.specs[specKey]
    return entry and (entry.slot or "SECONDARY") or nil
end

local function GetAvailableSpecChoices()
    local choices = { [""] = "|cFF888888— Select Spec —|r" }
    local db = E.db.thingsUI.chargeBar
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

-- Slot choices for add row, filtered by classbarMode conflict on selected spec
local function GetAddSlotChoices()
    local conflict = GetClassbarSlot(selectedSpecToAdd)
    local out = {}
    for k, v in pairs(SLOT_VALUES) do
        if k ~= conflict then out[k] = v end
    end
    return out
end

local function GetEnabledSpecsList()
    local db = E.db.thingsUI.chargeBar
    if not db or not db.specs then return {} end
    local list = {}
    for key, entry in pairs(db.specs) do
        local id = tonumber(key)
        local name = "Spec "..key
        local className, classFile, icon
        if id and id > 0 then
            local _, sName, _, sIcon, _, cFile, cName = GetSpecializationInfoByID(id)
            name      = sName  or name
            className = cName
            classFile = cFile
            icon      = sIcon
        end
        list[#list+1] = {
            key = key, name = name, className = className,
            classFile = classFile, icon = icon, entry = entry,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function FormatSpecLabel(e)
    if not e then return "" end
    local label
    if e.className then
        local color = e.classFile and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classFile])
        local hex = color and color.colorStr or "ffffffff"
        label = ("|c%s%s|r |cFFAAAAAA-|r |c%s%s|r"):format(hex, e.className, hex, e.name)
    else
        label = e.name
    end
    if e.icon then
        return ("|T%d:18:18:0:0:64:64:4:60:4:60|t  %s"):format(e.icon, label)
    end
    return label
end

-- Per-row slot choices: exclude classbarMode's slot on this spec
local function GetRowSlotChoices(specKey)
    local conflict = GetClassbarSlot(specKey)
    local out = {}
    for k, v in pairs(SLOT_VALUES) do
        if k ~= conflict then out[k] = v end
    end
    return out
end

local function BuildEnabledArgs()
    local args = {}
    args.empty = {
        order = 0, type = "description", fontSize = "medium",
        name = "|cFF888888No specs enabled. Use the controls above to add one.|r",
        hidden = function() return #GetEnabledSpecsList() > 0 end,
    }

    for i = 1, 8 do
        local function entry()    return GetEnabledSpecsList()[i] end
        local function entryKey() local e = entry(); return e and e.key or nil end
        local function ent()
            local k = entryKey(); if not k then return nil end
            return E.db.thingsUI.chargeBar.specs[k]
        end

        args["row"..i] = {
            order = i * 10, type = "group", inline = true,
            name = function() return FormatSpecLabel(entry()) end,
            hidden = function() return entry() == nil end,
            args = {
                spellID = {
                    order = 1, type = "input", name = "Spell ID", width = 1.0,
                    desc = "Numeric spell ID of the ability to track. Must be a spell with charges (e.g. Charge=100, Hover=358267, Shimmer=212653).",
                    get = function() local e = ent(); return e and tostring(e.spellID or "") or "" end,
                    set = function(_, v)
                        local e = ent(); if not e then return end
                        v = (v or ""):gsub("%s", "")
                        e.spellID = (v ~= "" and tonumber(v)) or nil
                        Update()
                    end,
                },
                slot = {
                    order = 2, type = "select", name = "Slot", width = 1.3,
                    values = function() local e = entry(); return GetRowSlotChoices(e and e.key) end,
                    get = function() local e = ent(); return e and (e.slot or "SECONDARY") or "SECONDARY" end,
                    set = function(_, v) local e = ent(); if not e then return end; e.slot = v; Update() end,
                },
                conflict = {
                    order = 3, type = "description", width = 1.0,
                    name = function()
                        local e = entry(); if not e then return "" end
                        local cs = GetClassbarSlot(e.key)
                        if cs and (ent() and ent().slot or "SECONDARY") == cs then
                            return "|cFFFF6B6B⚠ Classbar conflict|r"
                        end
                        return ""
                    end,
                    hidden = function()
                        local e = entry(); if not e then return true end
                        local cs = GetClassbarSlot(e.key)
                        return not (cs and (ent() and ent().slot or "SECONDARY") == cs)
                    end,
                },
                remove = {
                    order = 4, type = "execute", name = "Remove", width = 0.7,
                    func = function()
                        local k = entryKey(); if not k then return end
                        E.db.thingsUI.chargeBar.specs[k] = nil
                        Update()
                        NotifyChange()
                    end,
                },
            },
        }
    end
    return args
end

function TUI:ChargeBarOptions()
    return {
        order = 53,
        type = "group",
        name = "Charge Bar",
        childGroups = "tab",
        args = {
            description = {
                order = 1, type = "description",
                name = "Per-spec spell-charge tracker. Place a charge bar in the BCDM cluster (Power or Secondary Power slot) inheriting the Essential Cooldown Viewer width.\n\n|cFFFF6B6BNote:|r If Classbar Mode is enabled for the same spec on the same slot, the classbar wins and the charge bar is hidden.\n\n",
            },
            enabled = {
                order = 2, type = "toggle", name = "Enable Charge Bar",
                desc = "Master toggle.",
                width = "full",
                get = function() return E.db.thingsUI.chargeBar.enabled end,
                set = function(_, v)
                    E.db.thingsUI.chargeBar.enabled = v
                    TUI:UpdateChargeBar()
                end,
            },

            addGroup = {
                order = 10, type = "group", inline = true, name = "Add Spec",
                args = {
                    specSelect = {
                        order = 1, type = "select", name = "Spec",
                        values = GetAvailableSpecChoices,
                        get = function() return selectedSpecToAdd end,
                        set = function(_, v)
                            selectedSpecToAdd = v
                            -- Reset slot if it conflicts
                            local conflict = GetClassbarSlot(v)
                            if conflict and selectedSlotToAdd == conflict then
                                selectedSlotToAdd = (conflict == "SECONDARY") and "POWER" or "SECONDARY"
                            end
                        end,
                    },
                    slotSelect = {
                        order = 2, type = "select", name = "Slot",
                        values = GetAddSlotChoices,
                        get = function() return selectedSlotToAdd end,
                        set = function(_, v) selectedSlotToAdd = v end,
                    },
                    add = {
                        order = 3, type = "execute", name = "Add",
                        disabled = function() return not selectedSpecToAdd or selectedSpecToAdd == "" end,
                        func = function()
                            if selectedSpecToAdd == "" then return end
                            local db = E.db.thingsUI.chargeBar
                            db.specs = db.specs or {}
                            db.specs[selectedSpecToAdd] = {
                                slot           = selectedSlotToAdd or "SECONDARY",
                                spellID        = nil,
                                useClassColor  = true,
                                showText       = true,
                                textFont       = "Expressway",
                                textSize       = 12,
                                textOutline    = "OUTLINE",
                            }
                            selectedSpecToAdd = ""
                            Update()
                            NotifyChange()
                        end,
                    },
                },
            },

            enabledList = {
                order = 20, type = "group", inline = true, name = "Enabled Specs",
                args = BuildEnabledArgs(),
            },

            appearance = {
                order = 30, type = "group", inline = true, name = "Appearance",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    statusBarTexture = {
                        order = 1, type = "select", dialogControl = "LSM30_Statusbar",
                        name = "Bar Texture",
                        values = (LSM and LSM.HashTable and LSM:HashTable("statusbar")) or {},
                        get = function() return E.db.thingsUI.chargeBar.statusBarTexture end,
                        set = function(_, v) E.db.thingsUI.chargeBar.statusBarTexture = v; Update() end,
                    },
                    height = {
                        order = 2, type = "range", name = "Height",
                        min = 6, max = 60, step = 1,
                        get = function() return E.db.thingsUI.chargeBar.height or 18 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.height = v; Update() end,
                    },
                    xGap = {
                        order = 3, type = "range", name = "Segment Gap",
                        desc = "Horizontal gap between charge segments. Total bar width stays the same — segments shrink to make room.",
                        min = 0, max = 20, step = 1,
                        get = function() return E.db.thingsUI.chargeBar.xGap or 0 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.xGap = v; Update() end,
                    },
                    rechargeColor = {
                        order = 4, type = "color", name = "Recharge Color", hasAlpha = true,
                        get = function()
                            local c = E.db.thingsUI.chargeBar.rechargeColor or {}
                            return c.r or 0.5, c.g or 0.5, c.b or 0.5, c.a or 0.8
                        end,
                        set = function(_, r, g, b, a)
                            E.db.thingsUI.chargeBar.rechargeColor = { r = r, g = g, b = b, a = a }
                            Update()
                        end,
                    },
                    showTicks = {
                        order = 5, type = "toggle", name = "Show Ticks",
                        disabled = function() return (E.db.thingsUI.chargeBar.xGap or 0) > 0 end,
                        desc = "Disabled when Segment Gap > 0 since segments are already visually separated.",
                        get = function() return E.db.thingsUI.chargeBar.showTicks end,
                        set = function(_, v) E.db.thingsUI.chargeBar.showTicks = v; Update() end,
                    },
                    tickWidth = {
                        order = 6, type = "range", name = "Tick Width",
                        min = 1, max = 6, step = 1,
                        disabled = function()
                            return not E.db.thingsUI.chargeBar.showTicks
                                or (E.db.thingsUI.chargeBar.xGap or 0) > 0
                        end,
                        get = function() return E.db.thingsUI.chargeBar.tickWidth or 1 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.tickWidth = v; Update() end,
                    },
                    tickColor = {
                        order = 7, type = "color", name = "Tick Color", hasAlpha = true,
                        disabled = function()
                            return not E.db.thingsUI.chargeBar.showTicks
                                or (E.db.thingsUI.chargeBar.xGap or 0) > 0
                        end,
                        get = function()
                            local c = E.db.thingsUI.chargeBar.tickColor or {}
                            return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            E.db.thingsUI.chargeBar.tickColor = { r = r, g = g, b = b, a = a }
                            Update()
                        end,
                    },
                },
            },

            colorPerSpec = {
                order = 35, type = "group", inline = true, name = "Per-Spec Color",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled or #GetEnabledSpecsList() == 0 end,
                args = (function()
                    local out = {}
                    for i = 1, 8 do
                        local function entry()    return GetEnabledSpecsList()[i] end
                        local function ent()
                            local e = entry(); if not e then return nil end
                            return E.db.thingsUI.chargeBar.specs[e.key]
                        end
                        out["row"..i] = {
                            order = i * 10, type = "group", inline = true,
                            name = function() return FormatSpecLabel(entry()) end,
                            hidden = function() return entry() == nil end,
                            args = {
                                useClassColor = {
                                    order = 1, type = "toggle", name = "Use Class Color", width = 1.2,
                                    get = function() local e = ent(); return e and (e.useClassColor ~= false) end,
                                    set = function(_, v) local e = ent(); if not e then return end; e.useClassColor = v; Update() end,
                                },
                                customColor = {
                                    order = 2, type = "color", name = "Custom Color", width = 1.0,
                                    disabled = function() local e = ent(); return not e or e.useClassColor ~= false end,
                                    get = function()
                                        local e = ent(); local c = (e and e.customColor) or {}
                                        return c.r or 0.2, c.g or 0.6, c.b or 1.0
                                    end,
                                    set = function(_, r, g, b)
                                        local e = ent(); if not e then return end
                                        e.customColor = { r = r, g = g, b = b }
                                        Update()
                                    end,
                                },
                            },
                        }
                    end
                    return out
                end)(),
            },

            textGroup = {
                order = 40, type = "group", inline = true, name = "Recharge Text",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled or #GetEnabledSpecsList() == 0 end,
                args = (function()
                    local out = {}
                    for i = 1, 8 do
                        local function entry()    return GetEnabledSpecsList()[i] end
                        local function ent()
                            local e = entry(); if not e then return nil end
                            return E.db.thingsUI.chargeBar.specs[e.key]
                        end
                        out["row"..i] = {
                            order = i * 10, type = "group", inline = true,
                            name = function() return FormatSpecLabel(entry()) end,
                            hidden = function() return entry() == nil end,
                            args = {
                                showText = {
                                    order = 1, type = "toggle", name = "Show", width = 0.6,
                                    get = function() local e = ent(); return e and (e.showText ~= false) end,
                                    set = function(_, v) local e = ent(); if not e then return end; e.showText = v; Update() end,
                                },
                                textFont = {
                                    order = 2, type = "select", dialogControl = "LSM30_Font",
                                    name = "Font", width = 1.2,
                                    values = (LSM and LSM.HashTable and LSM:HashTable("font")) or {},
                                    disabled = function() local e = ent(); return not e or e.showText == false end,
                                    get = function() local e = ent(); return e and (e.textFont or "Expressway") end,
                                    set = function(_, v) local e = ent(); if not e then return end; e.textFont = v; Update() end,
                                },
                                textSize = {
                                    order = 3, type = "range", name = "Size", width = 0.9,
                                    min = 6, max = 32, step = 1,
                                    disabled = function() local e = ent(); return not e or e.showText == false end,
                                    get = function() local e = ent(); return e and (e.textSize or 12) or 12 end,
                                    set = function(_, v) local e = ent(); if not e then return end; e.textSize = v; Update() end,
                                },
                                textOutline = {
                                    order = 4, type = "select", name = "Outline", width = 1.0,
                                    values = OUTLINE_VALUES,
                                    disabled = function() local e = ent(); return not e or e.showText == false end,
                                    get = function() local e = ent(); return e and (e.textOutline or "OUTLINE") or "OUTLINE" end,
                                    set = function(_, v) local e = ent(); if not e then return end; e.textOutline = v; Update() end,
                                },
                            },
                        }
                    end
                    return out
                end)(),
            },

            offsetGroup = {
                order = 50, type = "group", inline = true, name = "Position & Width",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    widthOffset = {
                        order = 1, type = "range", name = "Width Offset",
                        desc = "Pixels added to the inherited Essential Cooldown Viewer width.",
                        min = -200, max = 200, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.chargeBar.widthOffset or 0 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.widthOffset = v; Update() end,
                    },
                    xOffset = {
                        order = 2, type = "range", name = "X Offset",
                        min = -200, max = 200, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.chargeBar.xOffset or 0 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.xOffset = v; Update() end,
                    },
                    gap = {
                        order = 3, type = "range", name = "Gap",
                        desc = "Vertical gap between the charge bar and the bar below it.",
                        min = -20, max = 50, step = 0.01, bigStep = 1,
                        get = function() return E.db.thingsUI.chargeBar.gap or 1 end,
                        set = function(_, v) E.db.thingsUI.chargeBar.gap = v; Update() end,
                    },
                },
            },
        },
    }
end
