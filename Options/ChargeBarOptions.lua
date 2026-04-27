local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

-- Filter the shared anchor list:
--   CUSTOM      → not a real frame, would error on SetPoint.
--   BCDM_CastBar → DynamicCastBarAnchor anchors the castbar onto its own targets,
--                  picking it here can create a SetPoint dependency loop.
local CHARGE_BAR_ANCHOR_VALUES = {}
do
    for k, v in pairs(ns.ANCHORS.SHARED_ANCHOR_VALUES) do
        if k ~= "CUSTOM" and k ~= "BCDM_CastBar" then
            CHARGE_BAR_ANCHOR_VALUES[k] = v
        end
    end
end

local SLOT_VALUES = {
    SECONDARY       = "Secondary Power slot",
    POWER           = "Power slot",
    ABOVE_SECONDARY = "Above Secondary",
}

local POINT_VALUES = {
    TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right", CENTER = "Center",
    TOPLEFT = "Top Left", TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right",
}

local function IsFHT() return E.db.thingsUI.chargeBar.mode == "FHT" end

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
local selectedEditSpec  = nil -- key of spec currently being edited in Spec Options tab

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
                    hidden = function() return IsFHT() end,
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
                        if IsFHT() then return true end
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
    local function GetEditSpec()
        local list = GetEnabledSpecsList()
        if #list == 0 then selectedEditSpec = nil; return nil end
        -- auto-select first when invalid
        local valid = false
        if selectedEditSpec then
            for _, e in ipairs(list) do
                if e.key == selectedEditSpec then valid = true; break end
            end
        end
        if not valid then selectedEditSpec = list[1].key end
        return E.db.thingsUI.chargeBar.specs[selectedEditSpec]
    end
    local function GetEditSpecChoices()
        local out = {}
        for _, e in ipairs(GetEnabledSpecsList()) do
            out[e.key] = FormatSpecLabel(e)
        end
        return out
    end

    return {
        order = 53,
        type = "group",
        name = "Charge Bar",
        childGroups = "tab",
        args = {
            description = {
                order = 1, type = "description",
                name = "Per-spec spell-charge tracker.\n\n|cFFFFD200NHT|r places the bar in the BCDM cluster (Power or Secondary Power slot) inheriting the Essential Cooldown Viewer width. \nIf Classbar Mode is enabled for the same spec on the same slot, the classbar wins and the charge bar is hidden, so, keep an eye on that.\n\n|cFFFFD200FHT|r doesn't use BCDM Power Bars so it's more free, or you could anchor it to something.\nCan also use it for NHT if you want I guess.\n\n",
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
            modeNHT = {
                order = 3, type = "toggle", name = "NHT (BCDM Slots)",
                desc = "Anchor charge bars into the BCDM cluster — Power slot, Secondary Power slot, or above Secondary.",
                hidden = function() return not E.db.thingsUI.chargeBar.enabled end,
                get = function() return E.db.thingsUI.chargeBar.mode == "NHT" end,
                set = function(_, v)
                    if v then
                        E.db.thingsUI.chargeBar.mode = "NHT"
                        Update()
                        NotifyChange()
                    end
                end,
            },
            modeFHT = {
                order = 4, type = "toggle", name = "FHT (Free Anchor)",
                desc = "Anchor the charge bar to any frame (UIParent, ElvUI Player Frame, etc.). For FHT/Healer profiles that don't use BCDM Power Bars.",
                hidden = function() return not E.db.thingsUI.chargeBar.enabled end,
                get = function() return E.db.thingsUI.chargeBar.mode == "FHT" end,
                set = function(_, v)
                    if v then
                        E.db.thingsUI.chargeBar.mode = "FHT"
                        Update()
                        NotifyChange()
                    end
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
                            local conflict = GetClassbarSlot(v)
                            if conflict and selectedSlotToAdd == conflict then
                                selectedSlotToAdd = (conflict == "SECONDARY") and "POWER" or "SECONDARY"
                            end
                        end,
                    },
                    slotSelect = {
                        order = 2, type = "select", name = "Slot",
                        hidden = function() return IsFHT() end,
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
                            selectedEditSpec = selectedSpecToAdd
                            selectedSpecToAdd = ""
                            Update()
                            NotifyChange()
                        end,
                    },
                    addAllClass = {
                        order = 4, type = "execute", name = "Add All My Class's Specs",
                        desc = "Create charge bar entries for every spec of your current class. Each entry uses the chosen Slot (or the opposite slot when it would conflict with Classbar Mode for that spec).\n\nAfter adding, edit one spec and use |cFFFFD200Copy to All Specs|r to share the spell, color, and text settings.",
                        width = 1.5,
                        func = function()
                            local _, playerClassFile = UnitClass("player")
                            if not playerClassFile then return end

                            local db = E.db.thingsUI.chargeBar
                            db.specs = db.specs or {}

                            local desiredSlot = selectedSlotToAdd or "SECONDARY"
                            local addedAny, lastKey

                            for cid = 1, 13 do
                                local numSpecs = GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(cid) or 0
                                for i = 1, numSpecs do
                                    local sid = GetSpecializationInfoForClassID and GetSpecializationInfoForClassID(cid, i)
                                    if sid then
                                        local _, _, _, _, _, sClassFile = GetSpecializationInfoByID(sid)
                                        if sClassFile == playerClassFile then
                                            local key = tostring(sid)
                                            if not db.specs[key] then
                                                local slot = desiredSlot
                                                local conflict = GetClassbarSlot(key)
                                                if conflict and conflict == slot then
                                                    slot = (slot == "SECONDARY") and "POWER" or "SECONDARY"
                                                end
                                                db.specs[key] = {
                                                    slot           = slot,
                                                    spellID        = nil,
                                                    useClassColor  = true,
                                                    showText       = true,
                                                    textFont       = "Expressway",
                                                    textSize       = 12,
                                                    textOutline    = "OUTLINE",
                                                }
                                                addedAny = true
                                                lastKey = key
                                            end
                                        end
                                    end
                                end
                            end

                            if addedAny then
                                selectedEditSpec = lastKey
                                selectedSpecToAdd = ""
                                Update()
                                NotifyChange()
                            end
                        end,
                    },
                },
            },

            -- ============================================================
            -- TAB 1: Layout
            -- ============================================================
            layoutTab = {
                order = 30, type = "group", name = "Layout",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    appearance = {
                        order = 1, type = "group", inline = true, name = "Appearance",
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
                                min = 6, max = 60, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.chargeBar.height or 18 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.height = v; Update() end,
                            },
                            xGap = {
                                order = 3, type = "range", name = "Segment Gap",
                                desc = "Horizontal gap between charge segments. Total bar width stays the same — segments shrink to make room.\n\n|cFFAAAAAA-1 makes adjacent segment borders share a 1px seam (recommended).|r",
                                min = -10, max = 20, step = 1,
                                get = function() return E.db.thingsUI.chargeBar.xGap or -1 end,
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
                    offsetGroup = {
                        order = 2, type = "group", inline = true, name = "Position & Width (NHT)",
                        hidden = function() return IsFHT() end,
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
                    fhtAnchorGroup = {
                        order = 3, type = "group", inline = true, name = "Anchor (FHT)",
                        hidden = function() return not IsFHT() end,
                        args = {
                            anchorFrame = {
                                order = 1, type = "select", name = "Anchor Frame",
                                desc = "Frame the charge bar attaches to.",
                                values = CHARGE_BAR_ANCHOR_VALUES,
                                get = function() return E.db.thingsUI.chargeBar.anchorFrame or "UIParent" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.anchorFrame = v; Update() end,
                            },
                            anchorPoint = {
                                order = 2, type = "select", name = "Anchor From",
                                desc = "Point on the charge bar that anchors.",
                                values = POINT_VALUES,
                                get = function() return E.db.thingsUI.chargeBar.anchorPoint or "CENTER" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.anchorPoint = v; Update() end,
                            },
                            anchorRelativePoint = {
                                order = 3, type = "select", name = "Anchor To",
                                desc = "Point on the anchor frame to attach to.",
                                values = POINT_VALUES,
                                get = function() return E.db.thingsUI.chargeBar.anchorRelativePoint or "CENTER" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.anchorRelativePoint = v; Update() end,
                            },
                            fhtWidth = {
                                order = 10, type = "range", name = "Width",
                                min = 20, max = 800, step = 0.01, bigStep = 1,
                                disabled = function()
                                    local db = E.db.thingsUI.chargeBar
                                    return db.inheritWidth and db.anchorFrame ~= "UIParent"
                                end,
                                get = function() return E.db.thingsUI.chargeBar.fhtWidth or 200 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.fhtWidth = v; Update() end,
                            },
                            inheritWidth = {
                                order = 11, type = "toggle", name = "Inherit Width from Anchor",
                                desc = "Match the width of the anchor frame. Ignored when anchor is UIParent (would span the whole screen).",
                                disabled = function() return E.db.thingsUI.chargeBar.anchorFrame == "UIParent" end,
                                get = function() return E.db.thingsUI.chargeBar.inheritWidth end,
                                set = function(_, v) E.db.thingsUI.chargeBar.inheritWidth = v; Update() end,
                            },
                            inheritWidthOffset = {
                                order = 12, type = "range", name = "Width Nudge",
                                desc = "Pixels added to the inherited width.",
                                min = -200, max = 200, step = 0.01, bigStep = 1,
                                disabled = function()
                                    local db = E.db.thingsUI.chargeBar
                                    return not db.inheritWidth or db.anchorFrame == "UIParent"
                                end,
                                get = function() return E.db.thingsUI.chargeBar.inheritWidthOffset or 0 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.inheritWidthOffset = v; Update() end,
                            },
                            fhtXOffset = {
                                order = 20, type = "range", name = "X Offset",
                                min = -800, max = 800, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.chargeBar.fhtXOffset or 0 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.fhtXOffset = v; Update() end,
                            },
                            fhtYOffset = {
                                order = 21, type = "range", name = "Y Offset",
                                min = -800, max = 800, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.chargeBar.fhtYOffset or 0 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.fhtYOffset = v; Update() end,
                            },
                        },
                    },
                },
            },

            -- ============================================================
            -- TAB 2: Spec Options
            -- ============================================================
            specTab = {
                order = 40, type = "group", name = "Spec Options",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    empty = {
                        order = 0, type = "description", fontSize = "medium",
                        name = "|cFF888888No specs enabled. Add one above to configure it here.|r",
                        hidden = function() return #GetEnabledSpecsList() > 0 end,
                    },
                    selector = {
                        order = 1, type = "select", name = "Editing Spec", width = 2.0,
                        desc = "Choose which enabled spec to configure.",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        values = GetEditSpecChoices,
                        get = function() GetEditSpec(); return selectedEditSpec end,
                        set = function(_, v) selectedEditSpec = v end,
                    },
                    remove = {
                        order = 2, type = "execute", name = "Remove This Spec", width = 1.0,
                        confirm = true,
                        confirmText = "Remove this spec from the charge bar list?",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        func = function()
                            if not selectedEditSpec then return end
                            E.db.thingsUI.chargeBar.specs[selectedEditSpec] = nil
                            selectedEditSpec = nil
                            Update()
                            NotifyChange()
                        end,
                    },
                    copyToAll = {
                        order = 3, type = "execute", name = "Copy to All Specs", width = 1.2,
                        desc = "Copy this spec's Spell ID, Color, and Recharge Text settings to every other spec of the same class — adding new entries for any specs not yet enabled.\n\n|cFFAAAAAASlot is not copied|r — slots are kept per-spec to avoid Classbar Mode conflicts. New entries inherit this spec's slot, falling back to Secondary if it would conflict with Classbar Mode.",
                        confirm = true,
                        confirmText = "Copy this spec's Spell ID, Color and Text settings to all other specs of the same class?\n\nMissing specs will be added automatically.",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        disabled = function() return not selectedEditSpec end,
                        func = function()
                            local src = selectedEditSpec and E.db.thingsUI.chargeBar.specs[selectedEditSpec]
                            if not src then return end

                            -- Determine source spec's class.
                            -- NOTE: `srcID and Func()` only returns the first value of Func() due to
                            -- the `and` short-circuit, so we must call it on its own line to get all returns.
                            local srcID = tonumber(selectedEditSpec)
                            if not srcID then return end
                            local _, _, _, _, _, srcClassFile = GetSpecializationInfoByID(srcID)
                            if not srcClassFile then return end

                            local function applySettings(dst)
                                dst.spellID       = src.spellID
                                dst.useClassColor = src.useClassColor
                                if src.customColor then
                                    dst.customColor = {
                                        r = src.customColor.r,
                                        g = src.customColor.g,
                                        b = src.customColor.b,
                                    }
                                else
                                    dst.customColor = nil
                                end
                                dst.showText    = src.showText
                                dst.textFont    = src.textFont
                                dst.textSize    = src.textSize
                                dst.textOutline = src.textOutline
                            end

                            local db = E.db.thingsUI.chargeBar
                            db.specs = db.specs or {}

                            -- Walk every classID 1..13 and find specs whose classFile matches the source.
                            -- This is more robust than GetClassInfo, which can vary across patches.
                            for cid = 1, 13 do
                                local numSpecs = GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(cid) or 0
                                for i = 1, numSpecs do
                                    local sid = GetSpecializationInfoForClassID and GetSpecializationInfoForClassID(cid, i)
                                    if sid then
                                        local _, _, _, _, _, sClassFile = GetSpecializationInfoByID(sid)
                                        if sClassFile == srcClassFile then
                                            local key = tostring(sid)
                                            if key ~= selectedEditSpec then
                                                local dst = db.specs[key]
                                                if not dst then
                                                    -- Pick a slot: prefer src.slot, but avoid Classbar conflict
                                                    local slot = src.slot or "SECONDARY"
                                                    local conflict = GetClassbarSlot(key)
                                                    if conflict and conflict == slot then
                                                        slot = (slot == "SECONDARY") and "POWER" or "SECONDARY"
                                                    end
                                                    dst = { slot = slot }
                                                    db.specs[key] = dst
                                                end
                                                applySettings(dst)
                                            end
                                        end
                                    end
                                end
                            end

                            Update()
                            NotifyChange()
                        end,
                    },

                    -- Slot + Spell ID
                    bindings = {
                        order = 10, type = "group", inline = true, name = "Tracked Spell",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        args = {
                            spellID = {
                                order = 1, type = "input", name = "Spell ID", width = 1.2,
                                desc = "Numeric spell ID of the ability to track. Must be a spell with charges (e.g. Charge=100, Hover=358267, Shimmer=212653).",
                                get = function() local e = GetEditSpec(); return e and tostring(e.spellID or "") or "" end,
                                set = function(_, v)
                                    local e = GetEditSpec(); if not e then return end
                                    v = (v or ""):gsub("%s", "")
                                    e.spellID = (v ~= "" and tonumber(v)) or nil
                                    Update()
                                end,
                            },
                            slot = {
                                order = 2, type = "select", name = "Slot", width = 1.3,
                                hidden = function() return IsFHT() end,
                                values = function() return GetRowSlotChoices(selectedEditSpec) end,
                                get = function() local e = GetEditSpec(); return e and (e.slot or "SECONDARY") or "SECONDARY" end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.slot = v; Update() end,
                            },
                            conflict = {
                                order = 3, type = "description", width = "full", fontSize = "medium",
                                name = function()
                                    local e = GetEditSpec(); if not e then return "" end
                                    local cs = GetClassbarSlot(selectedEditSpec)
                                    if cs and (e.slot or "SECONDARY") == cs then
                                        return "|cFFFF6B6B⚠ Classbar Mode is using this slot on this spec — the classbar wins and the charge bar is hidden.|r"
                                    end
                                    return ""
                                end,
                                hidden = function()
                                    if IsFHT() then return true end
                                    local e = GetEditSpec(); if not e then return true end
                                    local cs = GetClassbarSlot(selectedEditSpec)
                                    return not (cs and (e.slot or "SECONDARY") == cs)
                                end,
                            },
                        },
                    },

                    -- Color
                    color = {
                        order = 20, type = "group", inline = true, name = "Color",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        args = {
                            useClassColor = {
                                order = 1, type = "toggle", name = "Use Class Color", width = 1.2,
                                get = function() local e = GetEditSpec(); return e and (e.useClassColor ~= false) end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.useClassColor = v; Update() end,
                            },
                            customColor = {
                                order = 2, type = "color", name = "Custom Color", width = 1.0,
                                disabled = function() local e = GetEditSpec(); return not e or e.useClassColor ~= false end,
                                get = function()
                                    local e = GetEditSpec(); local c = (e and e.customColor) or {}
                                    return c.r or 0.2, c.g or 0.6, c.b or 1.0
                                end,
                                set = function(_, r, g, b)
                                    local e = GetEditSpec(); if not e then return end
                                    e.customColor = { r = r, g = g, b = b }
                                    Update()
                                end,
                            },
                        },
                    },

                    -- Recharge text
                    text = {
                        order = 30, type = "group", inline = true, name = "Recharge Text",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        args = {
                            showText = {
                                order = 1, type = "toggle", name = "Show", width = 0.6,
                                get = function() local e = GetEditSpec(); return e and (e.showText ~= false) end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.showText = v; Update() end,
                            },
                            textFont = {
                                order = 2, type = "select", dialogControl = "LSM30_Font",
                                name = "Font", width = 1.2,
                                values = (LSM and LSM.HashTable and LSM:HashTable("font")) or {},
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function() local e = GetEditSpec(); return e and (e.textFont or "Expressway") end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textFont = v; Update() end,
                            },
                            textSize = {
                                order = 3, type = "range", name = "Size", width = 0.9,
                                min = 6, max = 32, step = 1,
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function() local e = GetEditSpec(); return e and (e.textSize or 12) or 12 end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textSize = v; Update() end,
                            },
                            textOutline = {
                                order = 4, type = "select", name = "Outline", width = 1.0,
                                values = OUTLINE_VALUES,
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function() local e = GetEditSpec(); return e and (e.textOutline or "OUTLINE") or "OUTLINE" end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textOutline = v; Update() end,
                            },
                        },
                    },
                },
            },
        },
    }
end
