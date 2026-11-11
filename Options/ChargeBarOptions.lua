local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local NotifyChange = ns.NotifyChange

local FILL_VALUES = { ltr = "Left to Right", rtl = "Right to Left", edges = "Toward the Middle", middle = "From the Middle" }
local FILL_ORDER  = { "ltr", "rtl", "edges", "middle" }
local SELF = "ElvUI_thingsUI_ChargeBar"

-- everything a spec's own layout holds
local LAYOUT_KEYS = {
    "frameStrata", "height", "fillMode", "rechargeColor", "backgroundColor", "borderColor",
    "showTicks", "tickWidth", "tickColor", "showText", "textFont", "textSize", "textOutline",
    "anchorFrame", "anchorPoint", "anchorRelativePoint", "fhtWidth", "inheritWidth", "inheritWidthOffset",
    "fhtXOffset", "fhtYOffset",
}
local SPEC_KEYS = { "spellID", "spellName", "oneCharge", "useClassColor", "customColor", "useGlobalLayout", "standalone" }

local function DB() return E.db.thingsUI.chargeBar end
local function Off() return not DB().enabled end

local function Update()
    if ns.ChargeBar and ns.ChargeBar.RequestUpdateFull then ns.ChargeBar.RequestUpdateFull() end
end

local function Restack()
    local BS = ns.BarSetup
    if not BS then return end
    if BS.ResetWidthCache then BS.ResetWidthCache() end
    if BS.ApplyStack then BS.ApplyStack() end
end

local function CurrentSpecID()
    local idx = C_SpecializationInfo.GetSpecialization()
    return idx and select(1, C_SpecializationInfo.GetSpecializationInfo(idx)) or nil
end

-- the spec the page shows; nil = yours
local viewSpec
local function ViewSpec() return viewSpec or CurrentSpecID() end
local function Key() local id = ViewSpec() return id and tostring(id) end
local function Entry()
    local k, db = Key(), DB()
    return k and db.specs and db.specs[k] or nil
end
local function NoEntry() return Entry() == nil end
local function NewEntry() return { useClassColor = true, useGlobalLayout = true } end

local function SpecLabel(id)
    local m = id and ns.SpecMeta(id)
    if not m then return "this spec" end
    local icon = m.icon and ("|T%d:16:16:0:0:64:64:4:60:4:60|t "):format(m.icon) or ""
    return ("%s%s%s %s|r"):format(icon, ns.ClassColor(m.classToken), m.name or "?", m.className or "")
end

-- the layout the page edits: the spec's own, or the global one
local function LT()
    local e = Entry()
    if e and e.useGlobalLayout == false then return e, true end
    return DB(), false
end
local function Own() return select(2, LT()) end
local function lget(k, d)
    local v = LT()[k]
    if v == nil then v = DB()[k] end
    if v == nil then v = d end
    return v
end
local function lset(k, v) LT()[k] = v; Update() end

local function SeedLayout(e, force)
    local db = DB()
    for _, k in ipairs(LAYOUT_KEYS) do
        if force or e[k] == nil then e[k] = ns.DeepCopy(db[k]) end
    end
end

local function InSetup()
    local bs = E.db.thingsUI.barSetup
    if bs and bs.enabled == false then return false end
    local BS = ns.BarSetup
    local setup = BS and BS.SetupForSpec and BS.SetupForSpec(ViewSpec())
    local b = setup and setup.bars and setup.bars.chargebar
    return (b and b.enabled) and true or false
end
local function Stacked()
    local e = Entry()
    return e ~= nil and not e.standalone and InSetup()
end

local function SpellName(id)
    return (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id)
end

local function ViewHasCDM()
    local specID = ViewSpec()
    local map = specID and ns.CDMSpells and ns.CDMSpells.GetForSpec(specID)
    return (map and next(map) ~= nil) and true or false
end

local function CDMOrdered()
    local specID = ViewSpec()
    local map = specID and ns.CDMSpells and ns.CDMSpells.GetForSpec(specID)
    if not (map and next(map)) then return {} end
    -- charge spells first; the rest too, for one set up before its charge talent
    local chargeMap = ns.CDMSpells.GetChargesForSpec(specID) or {}
    local list = {}
    for id, nd in pairs(map) do
        list[#list + 1] = { id = id, nd = nd, nm = SpellName(id), ch = chargeMap[id] }
    end
    table.sort(list, function(a, b)
        if (a.ch ~= nil) ~= (b.ch ~= nil) then return a.ch ~= nil end
        if a.nd ~= b.nd then return not a.nd end
        return a.nm < b.nm
    end)
    return list
end
local function NoSpells() return NoEntry() or #CDMOrdered() == 0 end

local function ColorOpt(order, name, key, dr, dg, db, da, disabled)
    return {
        order = order, type = "color", name = name, hasAlpha = true, disabled = disabled,
        get = function()
            local c = lget(key, {})
            return c.r or dr, c.g or dg, c.b or db, c.a or da
        end,
        set = function(_, r, g, b, a) lset(key, { r = r, g = g, b = b, a = a }) end,
    }
end

local function NoText() return lget("showText", true) == false end
local function NoTicks() return not lget("showTicks") end
local function ScreenAnchor() return lget("anchorFrame", "UIParent") == "UIParent" end

local function AddSpec(key)
    local db = DB()
    db.specs = db.specs or {}
    db.specs[key] = db.specs[key] or NewEntry()
end

function TUI:ChargeBarOptions()
    return {
        order = 53,
        type = "group",
        name = "Charge Bar",
        childGroups = "tab",
        args = {
            enabled = {
                order = 1, type = "toggle", name = "Enable Charge Bar", width = "full",
                get = function() return DB().enabled end,
                set = function(_, v)
                    DB().enabled = v
                    TUI:UpdateChargeBar()
                    Restack()
                end,
            },
            picker = {
                order = 2, type = "select", name = "Editing Spec", width = "double",
                dialogControl = "TUI_CascadeDropdown",
                values = function()
                    local out = {}
                    local specs = DB().specs or {}
                    for _, r in ipairs(ns.AllSpecs()) do
                        if r.name then
                            local e = specs[tostring(r.id)]
                            local label = r.name
                            if e then label = label .. "\a" .. (e.enabled ~= false and "active" or "off") end
                            out[r.classToken .. ":" .. r.id] = label
                        end
                    end
                    return out
                end,
                get = function()
                    local m = ns.SpecMeta(ViewSpec())
                    return m and (m.classToken .. ":" .. m.id) or nil
                end,
                set = function(_, v)
                    local sid = tonumber(type(v) == "string" and v:match("^[A-Z_]+:(%d+)$"))
                    if sid then viewSpec = sid; NotifyChange() end
                end,
            },
            gotoCur = {
                order = 3, type = "execute", width = 1.2,
                hidden = function() return ViewSpec() == CurrentSpecID() end,
                name = function() return "Go to " .. SpecLabel(CurrentSpecID()) end,
                func = function() viewSpec = nil; NotifyChange() end,
            },

            specTab = {
                order = 10, type = "group",
                name = function() local m = ns.SpecMeta(ViewSpec()) return (m and m.name) or "Spec" end,
                disabled = Off,
                args = {
                    none = {
                        order = 1, type = "description", width = "full", fontSize = "medium", hidden = function() return not NoEntry() end,
                        name = function() return "|cFF888888No Charge Bar on|r " .. SpecLabel(ViewSpec()) .. "|cFF888888 yet.|r\n" end,
                    },
                    add = {
                        order = 2, type = "execute", name = "Add Charge Bar", width = 1.2,
                        hidden = function() return not NoEntry() end,
                        func = function()
                            local k = Key()
                            if not k then return end
                            AddSpec(k)
                            Update(); Restack(); NotifyChange()
                        end,
                    },
                    addClass = {
                        order = 3, type = "execute", name = "Add to Every Spec of the Class", width = 1.6,
                        hidden = function() return not NoEntry() end,
                        func = function()
                            local m = ns.SpecMeta(ViewSpec())
                            if not m then return end
                            for _, r in ipairs(ns.AllSpecs()) do
                                if r.classToken == m.classToken then AddSpec(tostring(r.id)) end
                            end
                            Update(); Restack(); NotifyChange()
                        end,
                    },

                    specEnabled = {
                        order = 10, type = "toggle", name = "Enable on This Spec", width = 1.2, hidden = NoEntry,
                        get = function() local e = Entry() return e and e.enabled ~= false end,
                        set = function(_, v)
                            local e = Entry(); if not e then return end
                            e.enabled = v
                            Update(); Restack(); NotifyChange()
                        end,
                    },
                    showIn = {
                        order = 11, type = "select", name = "Show In", width = 0.9, hidden = NoEntry,
                        values = { barsetup = "Bar Setup", standalone = "Standalone" }, sorting = { "barsetup", "standalone" },
                        get = function() local e = Entry() return (e and e.standalone) and "standalone" or "barsetup" end,
                        set = function(_, v)
                            local e = Entry(); if not e then return end
                            e.standalone = (v == "standalone") or nil
                            Update(); Restack(); NotifyChange()
                        end,
                    },
                    barSetupLink = {
                        order = 12, type = "description", dialogControl = "TUI_OptionLink", width = 1.2, name = "",
                        hidden = function() local e = Entry() return not e or e.standalone end,
                        arg = { links = { { label = "Open Bar Setup", path = { "thingsUI", "modulesTab", "barSetup" } } } },
                    },
                    stackNote = {
                        order = 13, type = "description", width = "full",
                        hidden = function() local e = Entry() return not e or e.standalone or InSetup() end,
                        name = "|cFFFFD200Not in this spec's Bar Setup right now (Bar Setup off, or the Charge Bar is unticked there). It shows Standalone meanwhile.|r",
                    },

                    spell = {
                        order = 20, type = "group", inline = true, name = "Tracked Spell", hidden = NoEntry,
                        args = {
                            emptyMsg = {
                                order = 0.5, type = "description", width = "full", fontSize = "medium",
                                hidden = function() return #CDMOrdered() > 0 end,
                                name = function()
                                    if not ViewHasCDM() then
                                        return SpecLabel(ViewSpec()) .. " isn't scanned yet.\n"
                                            .. "|cFF888888Log into this spec once: only the spec you are in can be read.|r"
                                    end
                                    return "|cFF888888No spells in the Cooldown Manager for|r " .. SpecLabel(ViewSpec()) .. "|cFF888888.|r"
                                end,
                            },
                            spellPick = {
                                order = 1, type = "select", dialogControl = "TUI_SpellDropdown", name = "Spell", width = 2.0,
                                hidden = NoSpells,
                                values = function()
                                    local out = {}
                                    for _, s in ipairs(CDMOrdered()) do
                                        local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s.id)) or 0
                                        local tag = s.ch and (" |cFF888888(%d charges)|r"):format(s.ch) or " |cFF888888(1 charge)|r"
                                        out[s.id] = (s.nd
                                            and ("|T%d:16:16:0:0:64:64:4:60:4:60|t  |cFFFF6060%s|r"):format(tex, s.nm)
                                            or  ("|T%d:16:16:0:0:64:64:4:60:4:60|t  %s"):format(tex, s.nm)) .. tag
                                    end
                                    local e = Entry()
                                    local stored = e and tonumber(e.spellID)
                                    if stored and not out[stored] then
                                        out[stored] = (e.spellName or "Unknown") .. " |cFF888888(not in cooldown manager)|r"
                                    end
                                    return out
                                end,
                                sorting = function()
                                    local keys, known = {}, false
                                    local e = Entry()
                                    local stored = e and tonumber(e.spellID)
                                    for _, s in ipairs(CDMOrdered()) do
                                        keys[#keys + 1] = s.id
                                        if s.id == stored then known = true end
                                    end
                                    if stored and not known then keys[#keys + 1] = stored end
                                    return keys
                                end,
                                get = function() local e = Entry() return e and tonumber(e.spellID) or nil end,
                                set = function(_, v)
                                    local e = Entry(); if not e then return end
                                    e.spellID = v
                                    e.spellName = SpellName(v)
                                    Update(); Restack()
                                end,
                            },
                            oneCharge = {
                                order = 2, type = "select", name = "With One Charge", width = 1.5,
                                hidden = NoSpells,
                                values = { bar = "Single Bar", cdm = "Show in Cooldown Manager" },
                                sorting = { "bar", "cdm" },
                                get = function() local e = Entry() return (e and e.oneCharge) or "bar" end,
                                set = function(_, v)
                                    local e = Entry(); if not e then return end
                                    e.oneCharge = (v ~= "bar") and v or nil
                                    Update()
                                end,
                            },
                        },
                    },
                    color = {
                        order = 30, type = "group", inline = true, name = "Color", hidden = NoEntry,
                        args = {
                            useClassColor = {
                                order = 1, type = "toggle", name = "Use Class Color", width = 1.2,
                                get = function() local e = Entry() return e and e.useClassColor ~= false end,
                                set = function(_, v) local e = Entry(); if not e then return end; e.useClassColor = v; Update() end,
                            },
                            customColor = {
                                order = 2, type = "color", name = "Custom Color", width = 1.0,
                                disabled = function() local e = Entry() return not e or e.useClassColor ~= false end,
                                get = function()
                                    local e = Entry()
                                    local c = (e and e.customColor) or {}
                                    return c.r or 0.2, c.g or 0.6, c.b or 1.0
                                end,
                                set = function(_, r, g, b)
                                    local e = Entry(); if not e then return end
                                    e.customColor = { r = r, g = g, b = b }
                                    Update()
                                end,
                            },
                        },
                    },
                    manage = {
                        order = 90, type = "group", inline = true, name = "Manage", hidden = NoEntry,
                        args = {
                            copyToAll = {
                                order = 1, type = "execute", name = "Copy to the Class's Other Specs", width = 1.6,
                                confirm = true,
                                confirmText = "Copy this spec's spell, color and layout to the other specs of its class?\nMissing specs are added.",
                                func = function()
                                    local src, m = Entry(), ns.SpecMeta(ViewSpec())
                                    if not (src and m) then return end
                                    local own = Key()
                                    for _, r in ipairs(ns.AllSpecs()) do
                                        local key = tostring(r.id)
                                        if r.classToken == m.classToken and key ~= own then
                                            AddSpec(key)
                                            local dst = DB().specs[key]
                                            for _, k in ipairs(SPEC_KEYS) do dst[k] = ns.DeepCopy(src[k]) end
                                            for _, k in ipairs(LAYOUT_KEYS) do dst[k] = ns.DeepCopy(src[k]) end
                                        end
                                    end
                                    Update(); Restack(); NotifyChange()
                                end,
                            },
                            remove = {
                                order = 2, type = "execute", width = 1.6,
                                name = function()
                                    local m = ns.SpecMeta(ViewSpec())
                                    return "Remove from " .. ((m and m.name) or "This Spec")
                                end,
                                confirm = function() return "Remove the Charge Bar from " .. SpecLabel(ViewSpec()) .. "?" end,
                                func = function()
                                    local k = Key()
                                    if not (k and DB().specs) then return end
                                    DB().specs[k] = nil
                                    Update(); Restack(); NotifyChange()
                                end,
                            },
                        },
                    },
                },
            },

            layoutTab = {
                order = 20, type = "group", name = "Layout",
                disabled = Off,
                args = {
                    useGlobalLayout = {
                        order = 1, type = "toggle", name = "Use Global Layout", width = 1.2, hidden = NoEntry,
                        get = function() local e = Entry() return e and e.useGlobalLayout ~= false end,
                        set = function(_, v)
                            local e = Entry(); if not e then return end
                            if not v then SeedLayout(e) end
                            e.useGlobalLayout = v
                            Update(); Restack(); NotifyChange()
                        end,
                    },
                    copyGlobal = {
                        order = 2, type = "execute", name = "Copy from Global Layout", width = 1.3,
                        hidden = function() return not Own() end,
                        confirm = true, confirmText = "Replace this spec's layout with the global one?",
                        func = function()
                            local e = Entry(); if not e then return end
                            SeedLayout(e, true)
                            Update(); Restack(); NotifyChange()
                        end,
                    },
                    which = {
                        order = 3, type = "description", width = "full", fontSize = "medium",
                        name = function()
                            if Own() then return "Own layout of " .. SpecLabel(ViewSpec()) .. ".\n" end
                            return "|cFFFFD200Global layout|r, shared by every spec that uses it.\n"
                        end,
                    },
                    appearance = {
                        order = 10, type = "group", inline = true, name = "Appearance",
                        args = {
                            height = {
                                order = 1, type = "range", name = "Height",
                                min = 6, max = 60, step = 0.01, bigStep = 1,
                                hidden = function() return Own() and Stacked() end,
                                get = function() return lget("height", 18) end,
                                set = function(_, v) lset("height", v) end,
                            },
                            fillMode = {
                                order = 2, type = "select", name = "Fill Direction",
                                values = FILL_VALUES, sorting = FILL_ORDER,
                                get = function() return lget("fillMode", "ltr") end,
                                set = function(_, v) lset("fillMode", v) end,
                            },
                            frameStrata = {
                                order = 3, type = "select", name = "Frame Strata",
                                values = ns.STRATA.VALUES, sorting = ns.STRATA.ORDER,
                                get = function() return lget("frameStrata", "LOW") end,
                                set = function(_, v) lset("frameStrata", v) end,
                            },
                            rechargeColor   = ColorOpt(4, "Recharge Color", "rechargeColor", 0.5, 0.5, 0.5, 0.8),
                            backgroundColor = ColorOpt(5, "Background Color", "backgroundColor", 0, 0, 0, 0.7),
                            borderColor     = ColorOpt(6, "Border Color", "borderColor", 0, 0, 0, 1),
                            tickBreak = { order = 6.5, type = "description", name = "", width = "full" },
                            showTicks = {
                                order = 7, type = "toggle", name = "Show Ticks",
                                get = function() return lget("showTicks") and true or false end,
                                set = function(_, v) lset("showTicks", v) end,
                            },
                            tickWidth = {
                                order = 8, type = "range", name = "Tick Width",
                                min = 1, max = 6, step = 1,
                                disabled = NoTicks,
                                get = function() return lget("tickWidth", 1) end,
                                set = function(_, v) lset("tickWidth", v) end,
                            },
                            tickColor = ColorOpt(9, "Tick Color", "tickColor", 0, 0, 0, 1, NoTicks),
                        },
                    },
                    text = {
                        order = 20, type = "group", inline = true, name = "Recharge Text",
                        args = {
                            showText = {
                                order = 1, type = "toggle", name = "Show", width = 0.6,
                                get = function() return not NoText() end,
                                set = function(_, v) lset("showText", v) end,
                            },
                            textFont = {
                                order = 2, type = "select", dialogControl = "LSM30_Font", name = "Font", width = 1.2,
                                values = ns.FontValues,
                                disabled = NoText,
                                get = function() return lget("textFont", "Expressway") end,
                                set = function(_, v) lset("textFont", v) end,
                            },
                            textSize = {
                                order = 3, type = "range", name = "Size", width = 0.9,
                                min = 6, max = 32, step = 1,
                                disabled = NoText,
                                get = function() return lget("textSize", 12) end,
                                set = function(_, v) lset("textSize", v) end,
                            },
                            textOutline = {
                                order = 4, type = "select", name = "Outline", width = 1.0,
                                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                                disabled = NoText,
                                get = function() return lget("textOutline", "OUTLINE") end,
                                set = function(_, v) lset("textOutline", v) end,
                            },
                        },
                    },
                    position = {
                        order = 30, type = "group", inline = true, name = "Position (Standalone)",
                        args = {
                            stacked = {
                                order = 0, type = "description", width = "full", hidden = function() return not Stacked() end,
                                name = function()
                                    return SpecLabel(ViewSpec()) .. " |cFFFFD200sits in the Bar Setup stack. These apply once Show In is Standalone.|r\n"
                                end,
                            },
                            anchorFrame = {
                                order = 1, type = "select", name = "Anchor To", width = 1.4,
                                values = function()
                                    local out = ns.ANCHORS.FilteredValues()
                                    out[SELF] = nil
                                    return out
                                end,
                                sorting = function()
                                    local out = {}
                                    for _, k in ipairs(ns.ANCHORS.FilteredOrder()) do
                                        if k ~= SELF then out[#out + 1] = k end
                                    end
                                    return out
                                end,
                                get = function() return lget("anchorFrame", "UIParent") end,
                                set = function(_, v)
                                    local t = LT()
                                    if v ~= lget("anchorFrame", "UIParent") then
                                        ns.ANCHORS.ResetPlacement(t, { "anchorPoint", "anchorRelativePoint", "fhtXOffset", "fhtYOffset" })
                                    end
                                    lset("anchorFrame", v)
                                end,
                            },
                            anchorPoint = {
                                order = 2, type = "select", name = "Point",
                                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                get = function() return lget("anchorPoint", "CENTER") end,
                                set = function(_, v) lset("anchorPoint", v) end,
                            },
                            anchorRelativePoint = {
                                order = 3, type = "select", name = "To Point",
                                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                get = function() return lget("anchorRelativePoint", "CENTER") end,
                                set = function(_, v) lset("anchorRelativePoint", v) end,
                            },
                            fhtXOffset = {
                                order = 4, type = "range", name = "X Offset",
                                min = -1000, max = 1000, step = 0.01, bigStep = 1,
                                get = function() return lget("fhtXOffset", 0) end,
                                set = function(_, v) lset("fhtXOffset", v) end,
                            },
                            fhtYOffset = {
                                order = 5, type = "range", name = "Y Offset",
                                min = -1000, max = 1000, step = 0.01, bigStep = 1,
                                get = function() return lget("fhtYOffset", 0) end,
                                set = function(_, v) lset("fhtYOffset", v) end,
                            },
                            sizeBreak = { order = 9, type = "description", name = "", width = "full" },
                            fhtWidth = {
                                order = 10, type = "range", name = "Width",
                                min = 20, max = 800, step = 0.01, bigStep = 1,
                                disabled = function() return lget("inheritWidth") and not ScreenAnchor() end,
                                get = function() return lget("fhtWidth", 200) end,
                                set = function(_, v) lset("fhtWidth", v) end,
                            },
                            inheritWidth = {
                                order = 11, type = "toggle", name = "Inherit Width from Anchor",
                                disabled = ScreenAnchor,
                                get = function() return lget("inheritWidth") and true or false end,
                                set = function(_, v) lset("inheritWidth", v) end,
                            },
                            inheritWidthOffset = {
                                order = 12, type = "range", name = "Width Nudge",
                                min = -200, max = 200, step = 0.01, bigStep = 1,
                                disabled = function() return not lget("inheritWidth") or ScreenAnchor() end,
                                get = function() return lget("inheritWidthOffset", 0) end,
                                set = function(_, v) lset("inheritWidthOffset", v) end,
                            },
                        },
                    },
                },
            },
        },
    }
end
