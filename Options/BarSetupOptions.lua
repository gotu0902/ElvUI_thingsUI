local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

local NotifyChange = ns.NotifyChange

local function ActiveSetup()
    return ns.BarSetup and ns.BarSetup.GetActiveSetup and ns.BarSetup.GetActiveSetup()
end

local function ActiveSetupIndex()
    local active = ActiveSetup()
    if not active then return nil end
    local setups = E.db.thingsUI.barSetup.setups   -- ActiveSetup() ensured the DB
    for i = 1, (setups and #setups or 0) do
        if setups[i] == active then return i, active end
    end
end

local function CurrentSpecName()
    local idx = GetSpecialization and GetSpecialization()
    local id = idx and select(1, GetSpecializationInfo(idx))
    local m = id and ns.SpecMeta and ns.SpecMeta(id)
    return m and (m.name .. " " .. m.className) or "your spec"
end

local function EnsureBarSetupDB()
    if ns.BarSetup and ns.BarSetup.EnsureDB then ns.BarSetup.EnsureDB() end
end

local function CurrentEditIndex()
    EnsureBarSetupDB()
    return E.db.thingsUI.barSetup.active or 1
end

local function GetSetups()
    EnsureBarSetupDB()
    return E.db.thingsUI.barSetup.setups
end

local function GetSetup(i)
    return GetSetups()[i]
end

local function ApplyStack()
    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
end

-- Spec picker
local selectedClassID = nil

local function ClassColorHex(classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if not c then return "FFFFFF" end
    return string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
end

local function GetClassChoices()
    local values, order = {}, {}
    if not GetNumClasses or not GetClassInfo then return values, order end
    local entries = {}
    for classID = 1, GetNumClasses() do
        local className, classFile = GetClassInfo(classID)
        if className then
            values[classID] = string.format("|cFF%s%s|r", ClassColorHex(classFile), className)
            entries[#entries + 1] = { id = classID, name = className }
        end
    end

    table.sort(entries, function(a, b) return a.name < b.name end)
    for i = 1, #entries do order[i] = entries[i].id end
    return values, order
end

local function GetSpecChoicesForClass(classID)
    local values, order = {}, {}
    for _, r in ipairs(ns.SpecsForClass(classID)) do
        local label = r.name or ("Spec " .. r.specIndex)
        if r.icon then
            label = string.format("|T%d:18:18:0:0:64:64:4:60:4:60|t %s", r.icon, label)
        end
        values[r.id] = label
        order[#order + 1] = r.id
    end
    return values, order
end

local SPEC_INFO_CACHE = {}
local function GetSpecInfo(specID)
    local cached = SPEC_INFO_CACHE[specID]
    if cached then return cached end
    local m = ns.SpecMeta(specID)
    if not m then return nil end
    local info = { className = m.className, classFile = m.classToken, specName = m.name }
    SPEC_INFO_CACHE[specID] = info
    return info
end

local function GetActiveSpecLabels(setup)
    local out = {}
    if not (setup and setup.specs) then return out end
    for specID in pairs(setup.specs) do
        local info = GetSpecInfo(specID)
        if info then
            out[#out + 1] = {
                id = specID,
                label = string.format("|cFF%s%s|r - %s",
                    ClassColorHex(info.classFile), info.className, info.specName),
                sortKey = info.className .. info.specName,
            }
        end
    end
    table.sort(out, function(a, b) return a.sortKey < b.sortKey end)
    return out
end

local MODE_VALUES_3 = {
    NHT      = "In stack",
    FHT      = "Anchor (custom)",
    ATTACHED = "Attached (player frame)",
}
local MODE_VALUES_2 = {
    NHT = "In stack",
    FHT = "Anchor (custom)",
}
local function ModeValuesFor(key)
    if key == "power" or key == "classbar" then return MODE_VALUES_3 end
    return MODE_VALUES_2
end

local BAR_COLORS = {
    power     = "FF8888", 
    castbar   = "FFD27F", 
    classbar  = "6FB7FF", 
    chargebar = "C780FF", 
}
local MAX_SLOTS = 12

local function BarRows(setup)
    local args = {}

    for slot = 1, MAX_SLOTS do
        local capturedSlot = slot
        local function key()    return setup.order[capturedSlot] end
        local function bar()    local k = key(); return k and setup.bars[k] end
        local function isPresent() return key() ~= nil end
        local function lastSlot()  return #setup.order end

        local function isSpecial()
            local k = key()
            return type(k) == "string" and k:sub(1, 8) == "special:"
        end
        local function isFHT()
            if isSpecial() then return false end
            local b = bar(); return b and b.mode == "FHT"
        end
        local function isNHT()
            if isSpecial() then return true end -- always stacked
            local b = bar(); return b and b.mode == "NHT"
        end
        local function isAttached()
            if isSpecial() then return false end
            local b = bar(); return b and b.mode == "ATTACHED"
        end

        local function isOff()
            local b = bar()
            return not (b and b.enabled)
        end

        local function disabledWhenOff(extra)
            if extra then
                return function() return isOff() or extra() end
            end
            return isOff
        end

        args["slot_" .. slot] = {
            order = slot,
            type  = "group",
            inline = true,
            hidden = function() return not isPresent() end,
            name = function()
                local k = key()
                if not k then return "" end
                local lbl = (ns.BarSetup.GetBarLabel and ns.BarSetup.GetBarLabel(k))
                            or ns.BarSetup.BAR_LABELS[k] or k
                local col = BAR_COLORS[k] or "FFFFFF"

                local inactiveReason
                if ns.BarSetup.IsSpecialBarAvailable
                   and type(k) == "string" and k:sub(1, 8) == "special:"
                   and not ns.BarSetup.IsSpecialBarAvailable(k) then
                    inactiveReason = "inactive on this spec"
                elseif k == "chargebar" then
                    local CB = ns.ChargeBar
                    if CB and CB.GetInactiveReason then
                        inactiveReason = CB.GetInactiveReason()
                    end
                elseif k == "classbar" then
                    local CM = ns.ClassbarMode
                    if CM and CM.IsEnabledForCurrentSpec and not CM.IsEnabledForCurrentSpec() then
                        inactiveReason = "inactive on this spec"
                    end
                end
                if inactiveReason then
                    return string.format("|cFFFFFF00%d.|r |cFF888888%s (%s)|r", capturedSlot, lbl, inactiveReason)
                end
                return string.format("|cFFFFFF00%d.|r |cFF%s%s|r", capturedSlot, col, lbl)
            end,
            args = {
                enabled = {
                    order = 1, type = "toggle", name = "", width = 0.2,
                    get = function() local b = bar(); return b and b.enabled end,
                    set = function(_, v) local b = bar(); if b then b.enabled = v; ApplyStack(); TUI:UpdateSpecialBars() end end,
                },
                moveUp = {
                    order = 2, type = "execute", name = "Up", width = 0.4,
                    disabled = function() return capturedSlot <= 1 end,
                    func = function()
                        local k = key()
                        if k then ns.BarSetup.MoveBar(setup, k, -1); ApplyStack(); NotifyChange() end
                    end,
                },
                moveDown = {
                    order = 3, type = "execute", name = "Down", width = 0.4,
                    disabled = function() return capturedSlot >= lastSlot() end,
                    func = function()
                        local k = key()
                        if k then ns.BarSetup.MoveBar(setup, k, 1); ApplyStack(); NotifyChange() end
                    end,
                },
                mode = {
                    order = 4, type = "select", name = "Mode", width = 1.0,
                    values  = function() local k = key(); return ModeValuesFor(k) end,
                    hidden = function()
                        if isSpecial() then return true end
                        return key() == "chargebar"
                    end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.mode end,
                    set = function(_, v) local b = bar(); if b then b.mode = v; ApplyStack() end end,
                },
                widthOffset = {
                    order = 5, type = "range", name = "Width ±", width = 0.7,
                    min = -50, max = 50, step = 0.01, bigStep = 1,
                    hidden = function() return not isNHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.widthOffset or 0 end,
                    set = function(_, v) local b = bar(); if b then b.widthOffset = v; ApplyStack() end end,
                },
                xOffset = {
                    order = 5.5, type = "range", name = "X ±", width = 0.7,
                    min = -50, max = 50, step = 0.01, bigStep = 1,
                    hidden = function() return not isNHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.xOffset or 0 end,
                    set = function(_, v) local b = bar(); if b then b.xOffset = v; ApplyStack() end end,
                },
                height = {
                    order = 6, type = "range", width = 0.7,
                    name = function()
                        if isAttached() then return "|cFFFFAA00Attached Height|r" end
                        return "Height"
                    end,
                    desc = function()
                        if isAttached() then
                            return "Height used only in Attached mode. Stored per setup, so a different setup (or spec) can keep its own NHT/FHT height."
                        end
                        return "Sets the height of this bar in its own module's settings. Synced with the value shown in the bar's own tab."
                    end,
                    min = 4, max = 60, step = 0.01, bigStep = 1,
                    disabled = disabledWhenOff(),
                    get = function()
                        local k = key()
                        if not k then return 0 end
                        if isAttached() and ns.BarSetup.GetAttachedHeight then
                            return ns.BarSetup.GetAttachedHeight(setup, k)
                        end
                        return ns.BarSetup.GetBarHeight and ns.BarSetup.GetBarHeight(k) or 0
                    end,
                    set = function(_, v)
                        local k = key()
                        if k and ns.BarSetup.SetBarHeight then
                            ns.BarSetup.SetBarHeight(k, v)
                            ApplyStack()
                        end
                    end,
                },

                fhtAnchor = {
                    order = 10, type = "select", name = "Anchor To", width = 1.4,
                    values  = function() return ns.ANCHORS.GetSharedAnchorValues() end,
                    sorting = function() return ns.ANCHORS.GetSharedAnchorOrder()  end,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.anchorFrame end,
                    set = function(_, v) local b = bar(); if b then b.anchorFrame = v; ApplyStack() end end,
                },
                fhtFrom = {
                    order = 11, type = "select", name = "From", width = 0.7,
                    values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.anchorPoint end,
                    set = function(_, v) local b = bar(); if b then b.anchorPoint = v; ApplyStack() end end,
                },
                fhtTo = {
                    order = 12, type = "select", name = "To", width = 0.7,
                    values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.anchorTo end,
                    set = function(_, v) local b = bar(); if b then b.anchorTo = v; ApplyStack() end end,
                },
                fhtX = {
                    order = 13, type = "range", name = "X", width = 0.6,
                    min = -300, max = 300, step = 0.01, bigStep = 1,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.xOffset or 0 end,
                    set = function(_, v) local b = bar(); if b then b.xOffset = v; ApplyStack() end end,
                },
                fhtY = {
                    order = 14, type = "range", name = "Y", width = 0.6,
                    min = -300, max = 300, step = 0.01, bigStep = 1,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.yOffset or 0 end,
                    set = function(_, v) local b = bar(); if b then b.yOffset = v; ApplyStack() end end,
                },
                fhtInheritWidth = {
                    order = 15, type = "toggle", name = "Inherit Width From Anchor", width = 1.5,
                    hidden = function() return not isFHT() end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.inheritWidthFromAnchor or false end,
                    set = function(_, v) local b = bar(); if b then b.inheritWidthFromAnchor = v; ApplyStack() end end,
                },
                fhtInheritWidthOffset = {
                    order = 16, type = "range", name = "Width Nudge", width = 0.8,
                    min = -50, max = 50, step = 0.01, bigStep = 1,
                    hidden = function() local b = bar(); return not isFHT() or not (b and b.inheritWidthFromAnchor) end,
                    disabled = disabledWhenOff(),
                    get = function() local b = bar(); return b and b.inheritWidthOffset or 0 end,
                    set = function(_, v) local b = bar(); if b then b.inheritWidthOffset = v; ApplyStack() end end,
                },
            },
        }
    end
    return args
end

local function SetupEditor(idx)
    local setup = GetSetup(idx)
    if not setup then return { type = "group", name = "-", args = {} } end

    local classValues, classOrder = GetClassChoices()

    local function defaultClassID()
        if E.myclass and GetNumClasses then
            for cid = 1, GetNumClasses() do
                local _, classFile = GetClassInfo(cid)
                if classFile == E.myclass then return cid end
            end
        end
        return classOrder[1]
    end
    if not selectedClassID then selectedClassID = defaultClassID() end

    -- Specs
    local specsTab = {
        type = "group", order = 1, name = "Specs",
        args = {
            nameInput = {
                order = 1, type = "input", name = "Setup Name", width = "double",
                get = function() return setup.name end,
                set = function(_, v)
                    if v and v ~= "" then setup.name = v end
                    NotifyChange()
                end,
            },
            deleteButton = {
                order = 2, type = "execute", name = "Delete Setup",
                confirm = function() return "Delete '" .. (setup.name or "?") .. "'?" end,
                disabled = function() return idx == 1 end,
                func = function()
                    ns.BarSetup.RemoveSetup(idx)
                    E.db.thingsUI.barSetup.active = 1
                    if ns.BarSetup._rebuildSetupOptions then
                        ns.BarSetup._rebuildSetupOptions()
                    end
                    ApplyStack(); NotifyChange()
                end,
            },

            pickHeader = { order = 10, type = "header", name = "Pick Specs by Class" },
            pickHint = {
                order = 11, type = "description",
                name = function()
                    if idx == 1 then
                        return "Global is the fallback used when no other setup matches the current spec. Spec list below has no effect on Global.\n"
                    end
                    return "Tick specs below to apply this setup when you're in them. Setups override Global; if multiple match, the lower-index one wins.\n"
                end,
            },
            classPick = {
                order = 12, type = "select", name = "Class", width = "double",
                values  = classValues,
                sorting = classOrder,
                hidden = function() return idx == 1 end,
                get = function() return selectedClassID end,
                set = function(_, v) selectedClassID = v; NotifyChange() end,
            },
            specPick = {
                order = 13, type = "multiselect", name = "Specs",
                hidden = function() return idx == 1 end,
                values = function() return (GetSpecChoicesForClass(selectedClassID)) end,
                get = function(_, k) return setup.specs[k] and true or false end,
                set = function(_, k, v)
                    setup.specs[k] = v or nil
                    ApplyStack()
                end,
            },

            activeHeader = { order = 20, type = "header", name = "Active on Specs" },
            activeList = {
                order = 21, type = "group", inline = true, name = "Currently Active",
                hidden = function() return idx == 1 end,
                args = (function()
                    local out = {
                        emptyDesc = {
                            order = 0, type = "description",
                            name = "|cFF888888None selected - this setup will never activate.|r",
                            hidden = function() return #GetActiveSpecLabels(setup) > 0 end,
                        },
                    }
                    for i = 1, 40 do
                        local idx2 = i
                        local function entry() return GetActiveSpecLabels(setup)[idx2] end
                        out["row" .. i] = {
                            order = 10 + i, type = "group", inline = true, name = "",
                            hidden = function() return entry() == nil end,
                            args = {
                                label = {
                                    order = 1, type = "description", width = 2.5,
                                    fontSize = "medium",
                                    name = function() local e = entry(); return e and e.label or "" end,
                                },
                                remove = {
                                    order = 2, type = "execute", name = "X", width = 0.4,
                                    func = function()
                                        local e = entry(); if not e then return end
                                        setup.specs[e.id] = nil
                                        ApplyStack(); NotifyChange()
                                    end,
                                },
                            },
                        }
                    end
                    return out
                end)(),
            },
        },
    }

    -- Bar Order
    local barOrderTab = {
        type = "group", order = 2, name = "Bar Order",
        args = {
            addSpecialBars = {
                order = 1, type = "multiselect",
                name = "Include Special Bars",
                values = function()
                    local out = {}
                    local SB = ns.SpecialBars
                    local n  = (SB and SB.GetBarCount and SB.GetBarCount()) or 0
                    for i = 1, n do
                        out["special:bar" .. i] = ns.BarSetup.GetBarLabel("special:bar" .. i)
                    end
                    return out
                end,
                get = function(_, k)
                    if not setup.order then return false end
                    for _, key in ipairs(setup.order) do
                        if key == k then return true end
                    end
                    return false
                end,
                set = function(_, k, v)
                    local existingIndex
                    for idx, key in pairs(setup.order) do
                        if key == k then existingIndex = idx; break end
                    end
                    if v then
                        if not existingIndex then
                            setup.order[#setup.order + 1] = k
                            setup.bars[k] = setup.bars[k] or {
                                enabled = true, mode = "NHT", widthOffset = 0,
                                anchorFrame = "UIParent", anchorPoint = "CENTER",
                                anchorTo = "CENTER", xOffset = 0, yOffset = 0,
                            }
                        end
                    elseif existingIndex then
                        table.remove(setup.order, existingIndex)
                    end
                    ApplyStack(); TUI:UpdateSpecialBars(); NotifyChange()
                end,
            },
            rows = {
                order = 10, type = "group", inline = true, name = "Bars",
                args = BarRows(setup),
            },
        },
    }

    -- Layout tab 
    local layoutTab = {
        type = "group", order = 3, name = "Layout",
        args = {
            anchorHeader = { order = 1, type = "header", name = "Stack Anchor" },
            anchorFrame = {
                order = 2, type = "select", name = "Anchor To",
                values  = function() return ns.ANCHORS.GetSharedAnchorValues() end,
                sorting = function() return ns.ANCHORS.GetSharedAnchorOrder()  end,
                get = function() return setup.anchorFrame end,
                set = function(_, v) setup.anchorFrame = v; ApplyStack() end,
            },
            anchorPoint = {
                order = 3, type = "select", name = "Anchor From (stack)",
                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                get = function() return setup.anchorPoint end,
                set = function(_, v) setup.anchorPoint = v; ApplyStack() end,
            },
            anchorTo = {
                order = 4, type = "select", name = "Anchor To (target)",
                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                get = function() return setup.anchorTo end,
                set = function(_, v) setup.anchorTo = v; ApplyStack() end,
            },
            xOffset = {
                order = 5, type = "range", name = "X Offset",
                min = -200, max = 200, step = 0.01, bigStep = 1,
                get = function() return setup.xOffset end,
                set = function(_, v) setup.xOffset = v; ApplyStack() end,
            },
            yOffset = {
                order = 6, type = "range", name = "Y Offset",
                min = -200, max = 200, step = 0.01, bigStep = 1,
                get = function() return setup.yOffset end,
                set = function(_, v) setup.yOffset = v; ApplyStack() end,
            },
            gap = {
                order = 7, type = "range", name = "Gap Between Bars",
                min = 0, max = 20, step = 0.01, bigStep = 1,
                get = function() return setup.gap end,
                set = function(_, v) setup.gap = v; ApplyStack() end,
            },

            widthHeader = { order = 20, type = "header", name = "Width" },
            inheritWidth = {
                order = 21, type = "toggle", width = "full",
                name = "Inherit Width From Cluster",
                get = function() return setup.inheritWidth end,
                set = function(_, v) setup.inheritWidth = v; ApplyStack() end,
            },
            widthOffset = {
                order = 22, type = "range", name = "Width Offset",
                min = -50, max = 50, step = 0.01, bigStep = 1,
                disabled = function() return not setup.inheritWidth end,
                get = function() return setup.widthOffset end,
                set = function(_, v) setup.widthOffset = v; ApplyStack() end,
            },
            minWidth = {
                order = 23, type = "range", name = "Minimum Width",
                min = 0, max = 1000, step = 0.01, bigStep = 1,
                disabled = function() return not setup.inheritWidth end,
                get = function() return setup.minWidth end,
                set = function(_, v) setup.minWidth = v; ApplyStack() end,
            },
        },
    }

    return {
        type = "group",
        name = function()   -- live rename + active=green
            local nm = setup.name or ("Setup " .. idx)
            if setup == ActiveSetup() then return "|cFF33FF33" .. nm .. "|r" end
            return nm
        end,
        order = 100 + idx,
        childGroups = "tab",
        args = {
            specs    = specsTab,
            barOrder = barOrderTab,
            layout   = layoutTab,
        },
    }
end

function TUI:BarSetupOptions()
    EnsureBarSetupDB()

    local args = {
        desc = {
            order = 1, type = "description",
            name = "Stack Player Power, Cast Bar, Class Bar and Charge Bar above the CDM cluster. Each setup can target specific specs; the |cFFFFFF00Global|r setup is the fallback.\n\n",
        },
        enabled = {
            order = 2, type = "toggle", name = "Enable Bar Setup", width = "full",
            get = function() return E.db.thingsUI.barSetup.enabled ~= false end,
            set = function(_, v)
                E.db.thingsUI.barSetup.enabled = v
                if v then
                    if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
                elseif ns.BarSetup and ns.BarSetup.RestoreBarsToElvUI then
                    ns.BarSetup.RestoreBarsToElvUI()
                end
                if ns.ChargeBar and ns.ChargeBar.RequestUpdate then ns.ChargeBar.RequestUpdate() end
                if ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then ns.ClassbarMode.RequestUpdate() end
            end,
        },
        disabledHint = {
            order = 3, type = "description", fontSize = "medium", width = "full",
            name = "|cFFFFFF00Bar Setup is disabled.|r Each bar uses its own FHT positioning + mover. Classbar width / detached anchor lives in ElvUI's |cFFFFFFFFUnitFrames -> Player -> Classbar|r.",
            hidden = function() return E.db.thingsUI.barSetup.enabled ~= false end,
        },
    }

    local function rebuildSetupEntries()
        for k in pairs(args) do
            if type(k) == "string" and k:match("^setup%d+$") then args[k] = nil end
        end
        local setups = GetSetups()
        for i = 1, #setups do
            local editor = SetupEditor(i)
            local origHidden = editor.hidden
            editor.hidden = function(info)
                if E.db.thingsUI.barSetup.enabled == false then return true end
                if type(origHidden) == "function" then return origHidden(info) end
                return origHidden
            end
            args["setup" .. i] = editor
        end
    end

    args.activeSetupLink = ns.OptionLinkRowDynamic(2.5, function()
        if E.db.thingsUI.barSetup.enabled == false then return {} end
        local idx, active = ActiveSetupIndex()
        if not idx then return {} end
        return {
            { label = "Active for " .. CurrentSpecName() .. ":  " },
            { label = active.name or ("Setup " .. idx), color = { 0.2, 1, 0.2 },
              path = { "thingsUI", "modulesTab", "barSetup", "setup" .. idx } },
        }
    end)

    args.addSetup = {
        order = 4, type = "execute", name = "+ New Setup",
        hidden = function() return E.db.thingsUI.barSetup.enabled == false end,
        func = function()
            ns.BarSetup.AddSetup()
            rebuildSetupEntries()
            NotifyChange()
        end,
    }

    ns.BarSetup._rebuildSetupOptions = rebuildSetupEntries
    rebuildSetupEntries()

    return {
        order = 25,
        type = "group",
        name = "Bar Setup",
        childGroups = "tab",
        args = args,
    }
end