local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local STRATA_VALUES = ns.STRATA.VALUES
local STRATA_ORDER  = ns.STRATA.ORDER

local POINT_VALUES = ns.POINTS.VALUES
local POINT_ORDER  = ns.POINTS.ORDER

local function IsFHT()
    if E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.enabled == false then return true end
    local bs = ns.BarSetup
    local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
    local b = setup and setup.bars and setup.bars.chargebar
    return not (b and b.enabled)
end

local NotifyChange = ns.NotifyChange

local function Update()
    if ns.ChargeBar and ns.ChargeBar.RequestUpdateFull then
        ns.ChargeBar.RequestUpdateFull()
    elseif ns.ChargeBar and ns.ChargeBar.RequestUpdate then
        ns.ChargeBar.RequestUpdate()
    end
end

local selectedEditSpec = nil

local function CurrentSpecID()
    local idx = GetSpecialization and GetSpecialization()
    return idx and select(1, GetSpecializationInfo(idx)) or nil
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

-- "CLASSTOKEN:specID" cascade key -> spec DB key (string-int).
local function CascadeKeyToSpecKey(value)
    local _, specID = value:match("^([A-Z_]+):(%d+)$")
    return specID
end

local function GetEditSpec()
    local list = GetEnabledSpecsList()
    if #list == 0 then selectedEditSpec = nil; return nil end
    local valid = false
    if selectedEditSpec then
        for _, e in ipairs(list) do
            if e.key == selectedEditSpec then valid = true; break end
        end
    end
    if not valid then
        local idx = GetSpecialization and GetSpecialization() or nil
        local curID = idx and select(1, GetSpecializationInfo(idx)) or 0
        local curKey = curID ~= 0 and tostring(curID) or nil
        local pick
        if curKey then
            for _, e in ipairs(list) do
                if e.key == curKey then pick = e.key; break end
            end
        end
        selectedEditSpec = pick or list[1].key
    end
    return E.db.thingsUI.chargeBar.specs[selectedEditSpec]
end

local function GetEditSpecChoices()
    local out = {}
    for _, e in ipairs(GetEnabledSpecsList()) do
        out[e.key] = FormatSpecLabel(e)
    end
    return out
end

local function SpellName(id)
    return (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id)
end

-- True once the edited spec has been scanned into the CDM cache.
local function EditedHasCDM()
    GetEditSpec()
    local specID = tonumber(selectedEditSpec)
    local map = specID and ns.CDMSpells and ns.CDMSpells.GetForSpec(specID)
    return (map and next(map) ~= nil) and true or false
end

local function EditedSpecLabel()
    local specID = tonumber(selectedEditSpec)
    if not specID then return "this spec" end
    local _, sName, _, _, _, _, cName = GetSpecializationInfoByID(specID)
    if sName and cName then return sName .. " " .. cName end
    return sName or "this spec"
end

-- Per-spec charge spells from ns.CDMSpells; empty until the spec is visited.
local function CDMOrderedForEdit()
    GetEditSpec()
    local specID = tonumber(selectedEditSpec)
    local map = specID and ns.CDMSpells and ns.CDMSpells.GetForSpec(specID)
    if not (map and next(map)) then return {} end
    local chargeMap = ns.CDMSpells.GetChargesForSpec(specID)
    local list = {}
    for id, nd in pairs(map) do
        if not chargeMap or chargeMap[id] then   -- nil chargeMap = not captured -> show all
            list[#list + 1] = { id = id, nd = nd, nm = SpellName(id) }
        end
    end
    table.sort(list, function(a, b)
        if a.nd ~= b.nd then return not a.nd end
        return a.nm < b.nm
    end)
    return list
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
                name = "\n\n",
            },
            enabled = {
                order = 2, type = "toggle", name = "Enable Charge Bar",
                width = "full",
                get = function() return E.db.thingsUI.chargeBar.enabled end,
                set = function(_, v)
                    E.db.thingsUI.chargeBar.enabled = v
                    TUI:UpdateChargeBar()
                end,
            },
            description = {
                order = 3, type = "description",
                name = "\n\n",
            },

            -- Cascade dropdown: check specs to add, uncheck to remove.
            specPicker = {
                order = 5, type = "multiselect", name = "Add / Remove Specs",
                desc = "",
                dialogControl = "TUI_CascadeDropdown",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                values = function() return ns.CascadeDropdown.AllSpecs() end,
                get = function(_, value)
                    local specKey = CascadeKeyToSpecKey(value)
                    if not specKey then return false end
                    local db = E.db.thingsUI.chargeBar
                    return db and db.specs and db.specs[specKey] ~= nil
                end,
                set = function(_, value, checked)
                    local specKey = CascadeKeyToSpecKey(value)
                    if not specKey then return end
                    local db = E.db.thingsUI.chargeBar
                    db.specs = db.specs or {}
                    if checked then
                        db.specs[specKey] = db.specs[specKey] or {
                            spellID         = nil,
                            useClassColor   = true,
                            useGlobalLayout = true,
                        }
                        selectedEditSpec = specKey
                    else
                        db.specs[specKey] = nil
                        if selectedEditSpec == specKey then selectedEditSpec = nil end
                    end
                    Update()
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                    NotifyChange()
                end,
            },

            addAllClass = {
                order = 6, type = "execute", name = "Add All My Class's Specs", width = 1.5,
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                func = function()
                    local _, playerClassFile = UnitClass("player")
                    if not playerClassFile then return end
                    local db = E.db.thingsUI.chargeBar
                    db.specs = db.specs or {}
                    local lastKey
                    for _, r in ipairs(ns.AllSpecs()) do
                        if r.classToken == playerClassFile then
                            local key = tostring(r.id)
                            if not db.specs[key] then
                                db.specs[key] = {
                                    spellID         = nil,
                                    useClassColor   = true,
                                    useGlobalLayout = true,
                                }
                                lastKey = key
                            end
                        end
                    end
                    if lastKey then selectedEditSpec = lastKey end
                    Update()
                    NotifyChange()
                end,
            },

            addCurrentSpec = {
                order = 7, type = "execute", width = 1.5,
                disabled = function()
                    if not E.db.thingsUI.chargeBar.enabled then return true end
                    local id = CurrentSpecID()
                    if not id then return true end
                    local db = E.db.thingsUI.chargeBar
                    return db.specs and db.specs[tostring(id)] ~= nil
                end,
                name = function()
                    local m = ns.SpecMeta and ns.SpecMeta(CurrentSpecID())
                    if not m then return "Add Current Spec" end
                    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.classToken]
                    local hex = (c and c.colorStr) or "ffffffff"
                    local icon = m.icon and ("|T%d:16:16:0:0:64:64:4:60:4:60|t "):format(m.icon) or ""
                    return ("%sAdd |c%s%s %s|r"):format(icon, hex, m.name, m.className)
                end,
                func = function()
                    local id = CurrentSpecID()
                    if not id then return end
                    local key = tostring(id)
                    local db = E.db.thingsUI.chargeBar
                    db.specs = db.specs or {}
                    db.specs[key] = db.specs[key] or {
                        spellID         = nil,
                        useClassColor   = true,
                        useGlobalLayout = true,
                    }
                    selectedEditSpec = key
                    Update()
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                    NotifyChange()
                end,
            },

            editingSpecBreak = {
                order = 9, type = "description", width = "full", name = "",
                hidden = function() return #GetEnabledSpecsList() == 0 end,
            },
            editingSpec = {
                order = 10, type = "select", name = "Editing Spec", width = 2.0,
                desc = "",
                hidden = function() return #GetEnabledSpecsList() == 0 end,
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                values = GetEditSpecChoices,
                get = function() GetEditSpec(); return selectedEditSpec end,
                set = function(_, v) selectedEditSpec = v end,
            },

            useGlobalLayout = {
                order = 15, type = "toggle", name = "Use Global Layout", width = "full",
                hidden = function() return #GetEnabledSpecsList() == 0 end,
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                get = function() local e = GetEditSpec(); return e and (e.useGlobalLayout ~= false) end,
                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.useGlobalLayout = v; Update() end,
            },

            -- Spec Layout
            specLayoutTab = {
                order = 20, type = "group", name = "Spec Layout",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    empty = {
                        order = 0, type = "description", fontSize = "medium",
                        name = "|cFF888888No specs enabled. Add one with the dropdown above.|r",
                        hidden = function() return #GetEnabledSpecsList() > 0 end,
                    },
                    bindings = {
                        order = 10, type = "group", inline = true, name = "Tracked Spell",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        args = {
                            emptyMsg = {
                                order = 0.5, type = "description", width = "full", fontSize = "medium",
                                hidden = function() return #CDMOrderedForEdit() > 0 end,
                                name = function()
                                    if not EditedHasCDM() then
                                        return "|cFFFFD200" .. EditedSpecLabel() .. "|r isn't scanned yet.\n"
                                            .. "|cFF888888Log into this spec once — we can only read the spells of the spec you're currently in.|r"
                                    end
                                    return "|cFF888888No spells with charges for " .. EditedSpecLabel() .. ".|r"
                                end,
                            },
                            spellPick = {
                                order = 1, type = "select", name = "Spell", width = 2.0,
                                hidden = function() return #CDMOrderedForEdit() == 0 end,
                                values = function()
                                    GetEditSpec()
                                    local out = {}
                                    for _, s in ipairs(CDMOrderedForEdit()) do
                                        local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s.id)) or 0
                                        out[s.id] = s.nd
                                            and ("|T%d:16:16:0:0:64:64:4:60:4:60|t  |cFFFF6060%s|r"):format(tex, s.nm)
                                            or  ("|T%d:16:16:0:0:64:64:4:60:4:60|t  %s"):format(tex, s.nm)
                                    end
                                    local e = GetEditSpec()
                                    local stored = e and tonumber(e.spellID)
                                    if stored and not out[stored] then
                                        out[stored] = (e.spellName or "Unknown") .. " |cFF888888(not in cooldown manager)|r"
                                    end
                                    return out
                                end,
                                sorting = function()
                                    GetEditSpec()
                                    local keys = {}
                                    for _, s in ipairs(CDMOrderedForEdit()) do keys[#keys + 1] = s.id end
                                    local e = GetEditSpec()
                                    local stored = e and tonumber(e.spellID)
                                    local known = false
                                    for i = 1, #keys do if keys[i] == stored then known = true break end end
                                    if stored and not known then keys[#keys + 1] = stored end
                                    return keys
                                end,
                                get = function() local e = GetEditSpec(); return e and tonumber(e.spellID) or nil end,
                                set = function(_, v)
                                    local e = GetEditSpec(); if not e then return end
                                    e.spellID = v
                                    e.spellName = SpellName(v)
                                    Update()
                                end,
                            },
                            spellSpacer = {
                                order = 2, type = "description", width = "full", name = "\n",
                            },
                            spellPreview = {
                                order = 3, type = "description", width = "full", fontSize = "medium",
                                name = function()
                                    local e = GetEditSpec()
                                    local id = e and tonumber(e.spellID)
                                    if not id then return " " end
                                    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
                                    if not info or not info.name then
                                        return "|cFFFF8080Unknown spell ID|r"
                                    end
                                    local iconStr = info.iconID and ("|T"..info.iconID..":20:20:0:0:64:64:4:60:4:60|t  ") or ""
                                    return iconStr .. "|cFFFFFFFF" .. info.name .. "|r  |cFF888888(" .. id .. ")|r"
                                end,
                            },
                        },
                    },
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

                    -- Per-spec color overrides (only when Use Global Layout is OFF).
                    overrideColors = {
                        order = 25, type = "group", inline = true, name = "Color Overrides",
                        hidden = function()
                            if #GetEnabledSpecsList() == 0 then return true end
                            local e = GetEditSpec(); return not e or e.useGlobalLayout ~= false
                        end,
                        args = {
                            rechargeColor = {
                                order = 1, type = "color", name = "Recharge Color", hasAlpha = true,
                                get = function()
                                    local e = GetEditSpec(); local c = (e and e.rechargeColor) or E.db.thingsUI.chargeBar.rechargeColor or {}
                                    return c.r or 0.5, c.g or 0.5, c.b or 0.5, c.a or 0.8
                                end,
                                set = function(_, r, g, b, a)
                                    local e = GetEditSpec(); if not e then return end
                                    e.rechargeColor = { r = r, g = g, b = b, a = a }
                                    Update()
                                end,
                            },
                            backgroundColor = {
                                order = 2, type = "color", name = "Background", hasAlpha = true,
                                get = function()
                                    local e = GetEditSpec(); local c = (e and e.backgroundColor) or E.db.thingsUI.chargeBar.backgroundColor or {}
                                    return c.r or 0, c.g or 0, c.b or 0, c.a or 0.7
                                end,
                                set = function(_, r, g, b, a)
                                    local e = GetEditSpec(); if not e then return end
                                    e.backgroundColor = { r = r, g = g, b = b, a = a }
                                    Update()
                                end,
                            },
                            borderColor = {
                                order = 3, type = "color", name = "Border", hasAlpha = true,
                                get = function()
                                    local e = GetEditSpec(); local c = (e and e.borderColor) or E.db.thingsUI.chargeBar.borderColor or {}
                                    return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                                end,
                                set = function(_, r, g, b, a)
                                    local e = GetEditSpec(); if not e then return end
                                    e.borderColor = { r = r, g = g, b = b, a = a }
                                    Update()
                                end,
                            },
                        },
                    },

                    -- Per-spec recharge text overrides.
                    text = {
                        order = 30, type = "group", inline = true, name = "Recharge Text Overrides",
                        hidden = function()
                            if #GetEnabledSpecsList() == 0 then return true end
                            local e = GetEditSpec(); return not e or e.useGlobalLayout ~= false
                        end,
                        args = {
                            showText = {
                                order = 1, type = "toggle", name = "Show", width = 0.6,
                                get = function()
                                    local e = GetEditSpec()
                                    if e and e.showText ~= nil then return e.showText ~= false end
                                    return E.db.thingsUI.chargeBar.showText ~= false
                                end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.showText = v; Update() end,
                            },
                            textFont = {
                                order = 2, type = "select", dialogControl = "LSM30_Font",
                                name = "Font", width = 1.2,
                                values = (LSM and LSM.HashTable and LSM:HashTable("font")) or {},
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function()
                                    local e = GetEditSpec()
                                    return (e and e.textFont) or E.db.thingsUI.chargeBar.textFont or "Expressway"
                                end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textFont = v; Update() end,
                            },
                            textSize = {
                                order = 3, type = "range", name = "Size", width = 0.9,
                                min = 6, max = 32, step = 1,
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function()
                                    local e = GetEditSpec()
                                    return (e and e.textSize) or E.db.thingsUI.chargeBar.textSize or 12
                                end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textSize = v; Update() end,
                            },
                            textOutline = {
                                order = 4, type = "select", name = "Outline", width = 1.0,
                                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                                disabled = function() local e = GetEditSpec(); return not e or e.showText == false end,
                                get = function()
                                    local e = GetEditSpec()
                                    return (e and e.textOutline) or E.db.thingsUI.chargeBar.textOutline or "OUTLINE"
                                end,
                                set = function(_, v) local e = GetEditSpec(); if not e then return end; e.textOutline = v; Update() end,
                            },
                        },
                    },

                    -- Per-spec management buttons.
                    manage = {
                        order = 90, type = "group", inline = true, name = "Manage",
                        hidden = function() return #GetEnabledSpecsList() == 0 end,
                        args = {
                            copyToAll = {
                                order = 1, type = "execute", name = "Copy to All Specs", width = 1.5,
                                confirm = true,
                                confirmText = "Copy this spec's settings to all other specs of the same class?\nMissing specs will be added automatically.",
                                disabled = function() return not selectedEditSpec end,
                                func = function()
                                    local src = selectedEditSpec and E.db.thingsUI.chargeBar.specs[selectedEditSpec]
                                    if not src then return end
                                    local srcID = tonumber(selectedEditSpec); if not srcID then return end
                                    local _, _, _, _, _, srcClassFile = GetSpecializationInfoByID(srcID)
                                    if not srcClassFile then return end

                                    local function copyColor(c) return c and { r = c.r, g = c.g, b = c.b, a = c.a } or nil end
                                    local function applySettings(dst)
                                        dst.spellID         = src.spellID
                                        dst.spellName       = src.spellName
                                        dst.useClassColor   = src.useClassColor
                                        dst.customColor     = src.customColor and { r = src.customColor.r, g = src.customColor.g, b = src.customColor.b } or nil
                                        dst.useGlobalLayout = src.useGlobalLayout
                                        dst.rechargeColor   = copyColor(src.rechargeColor)
                                        dst.backgroundColor = copyColor(src.backgroundColor)
                                        dst.borderColor     = copyColor(src.borderColor)
                                        dst.showText        = src.showText
                                        dst.textFont        = src.textFont
                                        dst.textSize        = src.textSize
                                        dst.textOutline     = src.textOutline
                                    end

                                    local db = E.db.thingsUI.chargeBar
                                    db.specs = db.specs or {}
                                    for _, r in ipairs(ns.AllSpecs()) do
                                        if r.classToken == srcClassFile then
                                            local key = tostring(r.id)
                                            if key ~= selectedEditSpec then
                                                local dst = db.specs[key] or {}
                                                db.specs[key] = dst
                                                applySettings(dst)
                                            end
                                        end
                                    end
                                    Update()
                                    NotifyChange()
                                end,
                            },
                            remove = {
                                order = 2, type = "execute", name = "Remove This Spec", width = 1.2,
                                confirm = true,
                                confirmText = "Remove this spec from the charge bar list?",
                                disabled = function() return not selectedEditSpec end,
                                func = function()
                                    if not selectedEditSpec then return end
                                    E.db.thingsUI.chargeBar.specs[selectedEditSpec] = nil
                                    selectedEditSpec = nil
                                    Update()
                                    NotifyChange()
                                end,
                            },
                        },
                    },
                },
            },

            globalLayoutTab = {
                order = 30, type = "group", name = "Global Layout",
                disabled = function() return not E.db.thingsUI.chargeBar.enabled end,
                args = {
                    appearance = {
                        order = 1, type = "group", inline = true, name = "Appearance",
                        args = {
                            frameStrata = {
                                order = 1, type = "select", name = "Frame Strata",
                                values = STRATA_VALUES, sorting = STRATA_ORDER,
                                get = function() return E.db.thingsUI.chargeBar.frameStrata or "LOW" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.frameStrata = v; Update() end,
                            },
                            height = {
                                order = 2, type = "range", name = "Height",
                                min = 6, max = 60, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.chargeBar.height or 18 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.height = v; Update() end,
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
                            backgroundColor = {
                                order = 4.1, type = "color", name = "Background Color", hasAlpha = true,
                                get = function()
                                    local c = E.db.thingsUI.chargeBar.backgroundColor or {}
                                    return c.r or 0, c.g or 0, c.b or 0, c.a or 0.7
                                end,
                                set = function(_, r, g, b, a)
                                    E.db.thingsUI.chargeBar.backgroundColor = { r = r, g = g, b = b, a = a }
                                    Update()
                                end,
                            },
                            borderColor = {
                                order = 4.2, type = "color", name = "Border Color", hasAlpha = true,
                                get = function()
                                    local c = E.db.thingsUI.chargeBar.borderColor or {}
                                    return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                                end,
                                set = function(_, r, g, b, a)
                                    E.db.thingsUI.chargeBar.borderColor = { r = r, g = g, b = b, a = a }
                                    Update()
                                end,
                            },
                            showTicks = {
                                order = 5, type = "toggle", name = "Show Ticks",
                                get = function() return E.db.thingsUI.chargeBar.showTicks end,
                                set = function(_, v) E.db.thingsUI.chargeBar.showTicks = v; Update() end,
                            },
                            tickWidth = {
                                order = 6, type = "range", name = "Tick Width",
                                min = 1, max = 6, step = 1,
                                disabled = function() return not E.db.thingsUI.chargeBar.showTicks end,
                                get = function() return E.db.thingsUI.chargeBar.tickWidth or 1 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.tickWidth = v; Update() end,
                            },
                            tickColor = {
                                order = 7, type = "color", name = "Tick Color", hasAlpha = true,
                                disabled = function() return not E.db.thingsUI.chargeBar.showTicks end,
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
                    globalText = {
                        order = 2, type = "group", inline = true, name = "Recharge Text",
                        args = {
                            showText = {
                                order = 1, type = "toggle", name = "Show", width = 0.6,
                                get = function() return E.db.thingsUI.chargeBar.showText ~= false end,
                                set = function(_, v) E.db.thingsUI.chargeBar.showText = v; Update() end,
                            },
                            textFont = {
                                order = 2, type = "select", dialogControl = "LSM30_Font",
                                name = "Font", width = 1.2,
                                values = (LSM and LSM.HashTable and LSM:HashTable("font")) or {},
                                disabled = function() return E.db.thingsUI.chargeBar.showText == false end,
                                get = function() return E.db.thingsUI.chargeBar.textFont or "Expressway" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.textFont = v; Update() end,
                            },
                            textSize = {
                                order = 3, type = "range", name = "Size", width = 0.9,
                                min = 6, max = 32, step = 1,
                                disabled = function() return E.db.thingsUI.chargeBar.showText == false end,
                                get = function() return E.db.thingsUI.chargeBar.textSize or 12 end,
                                set = function(_, v) E.db.thingsUI.chargeBar.textSize = v; Update() end,
                            },
                            textOutline = {
                                order = 4, type = "select", name = "Outline", width = 1.0,
                                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                                disabled = function() return E.db.thingsUI.chargeBar.showText == false end,
                                get = function() return E.db.thingsUI.chargeBar.textOutline or "OUTLINE" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.textOutline = v; Update() end,
                            },
                        },
                    },
                    fhtAnchorGroup = {
                        order = 3, type = "group", inline = true, name = "Anchor (when not in Bar Setup stack)",
                        hidden = function() return not IsFHT() end,
                        args = {
                            anchorFrame = {
                                order = 1, type = "select", name = "Anchor Frame",
                                values = ns.ANCHORS.FilteredValues,
                                get = function() return E.db.thingsUI.chargeBar.anchorFrame or "UIParent" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.anchorFrame = v; Update() end,
                            },
                            anchorPoint = {
                                order = 2, type = "select", name = "Anchor From",
                                values = POINT_VALUES, sorting = POINT_ORDER,
                                get = function() return E.db.thingsUI.chargeBar.anchorPoint or "CENTER" end,
                                set = function(_, v) E.db.thingsUI.chargeBar.anchorPoint = v; Update() end,
                            },
                            anchorRelativePoint = {
                                order = 3, type = "select", name = "Anchor To",
                                values = POINT_VALUES, sorting = POINT_ORDER,
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
                                disabled = function() return E.db.thingsUI.chargeBar.anchorFrame == "UIParent" end,
                                get = function() return E.db.thingsUI.chargeBar.inheritWidth end,
                                set = function(_, v) E.db.thingsUI.chargeBar.inheritWidth = v; Update() end,
                            },
                            inheritWidthOffset = {
                                order = 12, type = "range", name = "Width Nudge",
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
        },
    }
end
