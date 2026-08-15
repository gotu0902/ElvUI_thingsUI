local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local CB_UP   = "|TInterface\\Buttons\\Arrow-Up-Up:16:16:0:2|t"
local CB_DOWN = "|TInterface\\Buttons\\Arrow-Up-Up:16:16:0:-2:32:32:0:32:32:0|t"
local CB_X    = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t"

local MAX_GROUPS = 10
local MAX_ROWS = 15

local function CB() return ns.CustomBars end

local function Refresh()
    if TUI.UpdateCustomBars then TUI:UpdateCustomBars() end
    NotifyChange()
end

local editSpec, editClass
local function curSpecID()
    local idx = GetSpecialization()
    return tostring((idx and GetSpecializationInfo(idx)) or 1)
end
local function curClassFile() local _, cf = UnitClass("player"); return cf end
local function getEditSpec()  return editSpec  or curSpecID()  end
local function getEditClass() return editClass or curClassFile() end
local function keyFor(scope)
    if scope == "spec" then return getEditSpec() end
    if scope == "class" then return getEditClass() end
    return nil
end

local editBarFrame
local function EditBarAura(def, title, group)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not (AceGUI and def) then return end
    local sorted = (group and (group.sortMode or "manual") ~= "manual") and true or false
    if editBarFrame then editBarFrame:Hide() end

    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    editBarFrame = f
    f:SetCallback("OnClose", function(w)
        if editBarFrame == w then editBarFrame = nil end
        AceGUI:Release(w)
    end)
    f:SetTitle(title or "Buff")
    f:SetStatusText("Applies to this bar only")
    f:SetLayout("Flow")
    f:SetWidth(400)
    f:SetHeight(320)
    f:EnableResize(false)

    local on = AceGUI:Create("CheckBox")
    on:SetLabel("Enabled")
    on:SetWidth(170)
    on:SetValue(def.enabled ~= false)
    on:SetCallback("OnValueChanged", function(_, _, v) def.enabled = v; Refresh() end)
    f:AddChild(on)

    local half = AceGUI:Create("CheckBox")
    half:SetLabel("Half Width")
    half:SetWidth(170)
    half:SetValue(def.halfWidth and true or false)
    half:SetCallback("OnValueChanged", function(_, _, v) def.halfWidth = v; Refresh() end)
    f:AddChild(half)

    local mine

    local kind = AceGUI:Create("Dropdown")
    kind:SetLabel("Type")
    kind:SetWidth(170)
    kind:SetList({ HELPFUL = "Buff", HARMFUL = "Debuff" }, { "HELPFUL", "HARMFUL" })
    kind:SetValue(def.kind or "HELPFUL")
    kind:SetCallback("OnValueChanged", function(_, _, v)
        def.kind = v
        if mine then mine:SetDisabled(v == "HARMFUL") end
        Refresh()
    end)
    f:AddChild(kind)

    mine = AceGUI:Create("CheckBox")
    mine:SetLabel("Only Mine")
    mine:SetWidth(170)
    mine:SetValue(def.onlyMine and true or false)
    mine:SetDisabled((def.kind or "HELPFUL") == "HARMFUL")
    mine:SetCallback("OnValueChanged", function(_, _, v) def.onlyMine = v; Refresh() end)
    f:AddChild(mine)

    local max = AceGUI:Create("Slider")
    max:SetLabel("Max Bars")
    max:SetWidth(170)
    max:SetSliderValues(1, 10, 1)
    max:SetValue(def.max or 1)
    max:SetDisabled(sorted)
    max:SetCallback("OnValueChanged", function(_, _, v) def.max = v; Refresh() end)
    f:AddChild(max)

    local S = ns.SORTING
    local sort = AceGUI:Create("Dropdown")
    sort:SetLabel("Sort Active By")
    sort:SetWidth(170)
    sort:SetList((S and S.ENTRY_VALUES) or { instance = "Oldest First" },
        (S and S.ENTRY_ORDER) or { "instance" })
    sort:SetValue(def.sort or "instance")
    sort:SetDisabled(sorted)
    sort:SetCallback("OnValueChanged", function(_, _, v) def.sort = v; Refresh() end)
    f:AddChild(sort)

    if sorted then
        local note = AceGUI:Create("Label")
        note:SetFullWidth(true)
        note:SetText("|cffFFD200Group is time-sorted - Max Bars and Sort Active By apply in Manual order only.|r")
        f:AddChild(note)
    end
end

local askScopeFrame
local function AskScope(title, apply)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then apply("global") return end
    if askScopeFrame then askScopeFrame:Hide() end

    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    askScopeFrame = f
    f:SetTitle("Add " .. (title or "Set"))
    f:SetStatusText("Which characters should it show for?")
    f:SetLayout("Flow")
    f:SetWidth(380)
    f:SetHeight(160)
    f:EnableResize(false)
    f:SetCallback("OnClose", function(w)
        if askScopeFrame == w then askScopeFrame = nil end
        AceGUI:Release(w)
    end)

    local _, classFile = UnitClass("player")
    local className = (classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile or "Class"
    for _, c in ipairs({
        { scope = "global", label = "All Characters" },
        { scope = "class",  label = "This Class (" .. className .. ")" },
        { scope = "spec",   label = "This Spec" },
    }) do
        local b = AceGUI:Create("Button")
        b:SetText(c.label)
        b:SetWidth(115)
        b:SetCallback("OnClick", function()
            apply(c.scope)
            f:Hide()
        end)
        f:AddChild(b)
    end
end

local function auraCommonValues()
    local out = {}
    for _, id in ipairs(ns.AURA_COMMON or {}) do
        local nm = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if not nm and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(id) end
        local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 0
        out[tostring(id)] = ("|T%d:14:14|t %s"):format(tex, nm or ("Spell " .. id))
    end
    return out
end

local function auraCommonSorting()
    local list = {}
    for _, id in ipairs(ns.AURA_COMMON or {}) do
        list[#list + 1] = { key = tostring(id), nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or tostring(id) }
    end
    table.sort(list, function(a, b) return a.nm < b.nm end)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.key end
    return out
end

local function EntryLabel(e)
    if e.kind == "specialbar" then
        local sid = e.def.spellID
        local nm = e.def.spellName or (sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "Bar"
        local tex = (sid and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)) or 134400
        return ("|T%d:16:16|t %s |cFF80FF80(Special Bar)|r"):format(tex, nm)
    end
    local sid = CB() and CB().FirstSpell and CB().FirstSpell(e.def)
    local count = 0
    for _ in pairs(e.def.spells or {}) do count = count + 1 end
    local nm = e.def.name or (sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or ("Spell " .. tostring(sid))
    local tex = (sid and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)) or 134400
    local label = ("|T%d:16:16|t %s"):format(tex, nm)
    if count > 1 then label = label .. (" |cFF888888(%d spells)|r"):format(count) end
    if e.def.enabled == false then label = label .. " |cff888888(off)|r" end
    if e.def.halfWidth then label = label .. " |cff8AC8FF(half)|r" end
    if e.def.kind == "HARMFUL" then label = label .. " |cffFF6060(Debuff)|r" end
    return label
end

local function EntryRow(gi, scope, ri)
    local function entry()
        local g = CB() and CB().GetGroups()[gi]
        if not g then return nil end
        return CB().ScopeEntries(g, scope, keyFor(scope))[ri], g
    end
    local hidden = function() return select(1, entry()) == nil end
    local pfx = "r" .. scope .. ri
    return {
        [pfx .. "_up"] = {
            order = ri * 10 + 1, type = "execute", name = CB_UP, width = 0.3, hidden = hidden,
            func = function()
                local e, g = entry()
                if e then CB().MoveEntry(g, scope, e.uid, -1, keyFor(scope)); Refresh() end
            end,
        },
        [pfx .. "_down"] = {
            order = ri * 10 + 2, type = "execute", name = CB_DOWN, width = 0.3, hidden = hidden,
            func = function()
                local e, g = entry()
                if e then CB().MoveEntry(g, scope, e.uid, 1, keyFor(scope)); Refresh() end
            end,
        },
        [pfx .. "_label"] = {
            order = ri * 10 + 3, type = "description", width = 1.4, fontSize = "medium",
            name = function()
                local e = entry()
                return e and EntryLabel(e) or ""
            end,
            hidden = hidden,
        },
        [pfx .. "_edit"] = {
            order = ri * 10 + 4, type = "execute", width = 0.6, hidden = hidden,
            name = function()
                local e = entry()
                return (e and e.kind == "specialbar") and "Edit Bar" or "Settings"
            end,
            func = function()
                local e, g = entry()
                if not e then return end
                if e.kind == "specialbar" then
                    local SBm = ns.SpecialBars
                    if SBm and scope == "spec" then
                        SBm.editingSpec = (getEditSpec() ~= curSpecID()) and tonumber(getEditSpec()) or nil
                    end
                    E:ToggleOptions("thingsUI,modulesTab,specialBars," .. e.barKey .. "Group")
                    return
                end
                local sid = CB().FirstSpell(e.def)
                EditBarAura(e.def, e.def.name or (sid and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "Buff", g)
            end,
        },
        [pfx .. "_del"] = {
            order = ri * 10 + 5, type = "execute", width = 0.3, hidden = hidden,
            name = function()
                local e = entry()
                return (e and e.kind == "specialbar") and "|cffffd200 - |r" or CB_X
            end,
            func = function()
                local e, g = entry()
                if not e then return end
                if e.kind == "specialbar" then
                    e.def.customGroup = nil
                    TUI:UpdateSpecialBars()
                    Refresh()
                else
                    CB().RemoveAura(g, scope, e.uid, keyFor(scope))
                    Refresh()
                end
            end,
        },
        [pfx .. "_purge"] = {
            order = ri * 10 + 5.2, type = "execute", name = CB_X, width = 0.3,
            hidden = function() local e = entry(); return not (e and e.kind == "specialbar") end,
            confirm = function()
                local e = entry()
                local nm = e and e.def and (e.def.spellName or e.def.spellID) or "?"
                return ("Delete special bar '%s' PERMANENTLY? It is removed from Special Bars too."):format(nm)
            end,
            func = function()
                local e = entry(); if not e then return end
                local SBm = ns.SpecialBars
                local slot = tonumber(e.barKey and e.barKey:match("bar(%d+)"))
                if SBm and SBm.RemoveBarSlot and slot then
                    SBm.RemoveBarSlot(slot, (getEditSpec() ~= curSpecID()) and tonumber(getEditSpec()) or nil)
                    if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end
                    TUI:UpdateSpecialBars()
                end
                Refresh()
            end,
        },
        [pfx .. "_style"] = {
            order = ri * 10 + 5.5, type = "select", name = "", width = 1.2,
            hidden = function()
                local e = entry()
                return not (e and e.kind == "specialbar")
            end,
            values = function()
                local SBm = ns.SpecialBars
                return (SBm and SBm.Styles and SBm.Styles.DropdownValues("bars", "|cFF888888- No Style -|r")) or {}
            end,
            sorting = function()
                local SBm = ns.SpecialBars
                return SBm and SBm.Styles and SBm.Styles.DropdownSorting("bars", true) or nil
            end,
            get = function()
                local e = entry()
                return (e and e.def.styleName) or ""
            end,
            set = function(_, v)
                local e = entry()
                if not e then return end
                local SBm = ns.SpecialBars
                e.def._styleDriftAck = nil
                if v == "" then
                    e.def.styleName = nil
                else
                    SBm.Styles.ApplyToDB("bars", v, e.def)
                end
                TUI:UpdateSpecialBars()
                Refresh()
            end,
        },
        [pfx .. "_brk"] = {
            order = ri * 10 + 6, type = "description", name = "", width = "full", hidden = hidden,
        },
    }
end

local function GroupTab(gi)
    local function grp() return CB() and CB().GetGroups()[gi] or nil end
    local function gget(k) local g = grp(); return g and g[k] end
    local function gset(k, v) local g = grp(); if g then g[k] = v; Refresh() end end
    local function unpackColor(c)
        c = c or {}
        return c.r or 1, c.g or 1, c.b or 1
    end

    local function ScopeTabArgs(scope)
        local maxRows = (scope == "spec") and (MAX_ROWS + 12) or MAX_ROWS
        local function full()
            local g = grp()
            return not g or (CB() and #CB().ScopeEntries(g, scope, keyFor(scope)) >= maxRows)
        end
        local function editingOtherSpec()
            return scope == "spec" and getEditSpec() ~= curSpecID()
        end
        local args = {
            addAura = {
                order = 1, type = "select", name = "|cFF60E0A0Add Buff|r", width = "double",
                values = auraCommonValues,
                sorting = auraCommonSorting,
                disabled = full,
                get = function() return "" end,
                set = function(_, v)
                    local g = grp()
                    local id = tonumber(v)
                    if g and id then CB().AddAura(g, scope, id, keyFor(scope)); Refresh() end
                end,
            },
            addAuraID = {
                order = 2, type = "input", name = "|cFF60E0A0...or Buff by ID or name|r",
                disabled = full,
                get = function() return "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v == "" then return end
                    local id = tonumber(v)
                    if not id then
                        local info = C_Spell.GetSpellInfo(v)
                        id = info and info.spellID
                    end
                    local g = grp()
                    if g and id and C_Spell.GetSpellInfo(id) then CB().AddAura(g, scope, id, keyFor(scope)); Refresh() end
                end,
            },
        }
        if scope == "spec" then
            args.addSpecialBar = {
                order = 3, type = "select", name = "|cFF80FF80Add Special Bar|r", width = 1.2,
                disabled = full,
                hidden = function()
                    if editingOtherSpec() then return true end
                    local SBm = ns.SpecialBars
                    if not (SBm and SBm.GetBarCount and SBm.GetBarDB) then return true end
                    for i = 1, SBm.GetBarCount() do
                        local bdb = SBm.GetBarDB("bar" .. i)
                        if bdb and bdb.enabled and bdb.spellID then return false end
                    end
                    return true
                end,
                values = function()
                    local out = { [""] = "|cFF888888- Select -|r" }
                    local SBm = ns.SpecialBars
                    local g = grp()
                    if SBm and SBm.GetBarCount then
                        for i = 1, SBm.GetBarCount() do
                            local bkey = "bar" .. i
                            local bdb = SBm.GetBarDB(bkey)
                            if bdb and bdb.enabled and bdb.spellID then
                                local nm = bdb.spellName
                                    or (C_Spell.GetSpellName and C_Spell.GetSpellName(bdb.spellID)) or bkey
                                local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(bdb.spellID)) or 134400
                                local tag = ""
                                if g and bdb.customGroup == g.id then tag = " |cff888888(here)|r"
                                elseif bdb.customGroup then tag = " |cff888888(in another group)|r" end
                                out[bkey] = ("|T%d:16:16|t %s%s"):format(tex, nm, tag)
                            end
                        end
                    end
                    return out
                end,
                get = function() return "" end,
                set = function(_, v)
                    if v == "" then return end
                    local SBm = ns.SpecialBars
                    local bdb = SBm and SBm.GetBarDB and SBm.GetBarDB(v)
                    local g = grp()
                    if bdb and g then
                        bdb.customGroup = g.id
                        if SBm.ReleaseBar then SBm.ReleaseBar(v) end
                        TUI:UpdateSpecialBars()
                        Refresh()
                    end
                end,
            }
            args.newSpecialBar = {
                order = 4, type = "select", name = "|cFF80FF80New Special Bar (from spell)|r", width = "double",
                disabled = full,
                hidden = editingOtherSpec,
                values = function()
                    return (ns.SB_SpellChoices and ns.SB_SpellChoices(nil, true)) or {}
                end,
                sorting = function()
                    return ns.SB_SpellChoicesSorting and ns.SB_SpellChoicesSorting() or nil
                end,
                get = function() return "" end,
                set = function(_, v)
                    local id = tonumber(v)
                    if not id then return end
                    local SBm = ns.SpecialBars
                    local g = grp()
                    if not (SBm and g) then return end
                    local usage = SBm.GetSpellUsageInfo and SBm.GetSpellUsageInfo(id)
                    if usage then
                        E:Print("This spell is already used by " .. usage .. "!")
                        return
                    end
                    local s = SBm.GetSpecRoot()
                    local c = s.barCount or 3
                    local maxSlots = SBm.MAX_SLOTS or 12
                    if c >= maxSlots then
                        E:Print(("All %d Special Bar slots are in use."):format(maxSlots))
                        return
                    end
                    if ns.SB_RebuildSlotPages then C_Timer.After(0, ns.SB_RebuildSlotPages) end
                    s.barCount = c + 1
                    local bdb = SBm.GetBarDB("bar" .. (c + 1))
                    if SBm.Styles and SBm.Styles.ApplyToDB and SBm.Styles.EffectiveDefault then
                        SBm.Styles.ApplyToDB("bars", SBm.Styles.EffectiveDefault("bars"), bdb)
                    end
                    local raw = SBm.GetRawSpellList and SBm.GetRawSpellList() or {}
                    bdb.spellID = id
                    bdb.spellName = (raw[id] and raw[id].name)
                        or (C_Spell.GetSpellName and C_Spell.GetSpellName(id))
                    bdb.enabled = true
                    bdb.customGroup = g.id
                    TUI:UpdateSpecialBars()
                    Refresh()
                end,
            }
        end
        local rows = {}
        for ri = 1, maxRows do
            for k, v in pairs(EntryRow(gi, scope, ri)) do rows[k] = v end
        end
        args.rowsGrp = { order = 10, type = "group", inline = true, name = "Bars", args = rows }
        return args
    end

    local function scopeCount(scope)
        local g = grp()
        return (g and CB()) and #CB().ScopeEntries(g, scope, keyFor(scope)) or 0
    end

    local function cbSpecCount(g, specID)
        local n = 0
        local root = CB() and CB().GetScopeRoot(g, "spec", specID, false)
        for _, d in pairs((root and root.auras) or {}) do
            if type(d) == "table" and d.enabled ~= false then n = n + 1 end
        end
        local sb = E.db.thingsUI and E.db.thingsUI.specialBars
        local bars = sb and sb.specs and sb.specs[tostring(specID)] and sb.specs[tostring(specID)].bars
        for _, bdb in pairs(bars or {}) do
            if type(bdb) == "table" and bdb.spellID and bdb.customGroup == g.id then n = n + 1 end
        end
        return n
    end

    local function cbClassCount(g, cf)
        local n = 0
        local root = CB() and CB().GetScopeRoot(g, "class", cf, false)
        for _, d in pairs((root and root.auras) or {}) do
            if type(d) == "table" and d.enabled ~= false then n = n + 1 end
        end
        return n
    end

    local presetArgs = {
        pdesc = {
            order = 1, type = "description",
            name = "Add a whole set at once; you pick which characters it shows for.\n",
        },
    }
    for pi, p in ipairs(ns.AURA_PRESETS or {}) do
        presetArgs["p_" .. tostring(p.key)] = {
            order = 10 + pi, type = "execute", width = 1.2,
            name = (p.name or tostring(p.key)) .. " |cff888888(" .. #(p.spells or {}) .. ")|r",
            func = function()
                local g = grp()
                if not g then return end
                AskScope(p.name or tostring(p.key), function(scope)
                    CB().AddAuraSet(g, scope, "preset:" .. tostring(p.key), p, keyFor(scope))
                    Refresh()
                end)
            end,
        }
    end

    local SCOPE_LABEL = { global = "Global", class = "Class", spec = "Spec" }
    local orderArgs = {
        sortMode = { order = 1, type = "select", name = "Bar Order", width = 1.3,
            values = ns.SORTING and ns.SORTING.VALUES, sorting = ns.SORTING and ns.SORTING.ORDER,
            get = function() return gget("sortMode") or "manual" end,
            set = function(_, v) gset("sortMode", v) end },
        maxBars = { order = 2, type = "range", name = "Max Bars (0 = Off)", min = 0, max = 30, step = 1,
            get = function() return gget("maxBars") or 0 end, set = function(_, v) gset("maxBars", v) end },
        sortDesc = { order = 3, type = "description", name = function()
            if (gget("sortMode") or "manual") == "manual" then
                return "\nManual: bars follow the arrow order in each list, lists stacked by the block order below (^/v). Max Bars cuts off everything past the first N lines.\n"
            end
            return "|cFFFFD200Sorted: manual order disabled. Spec, class and global order won't matter shit now be-te-dubs.|r\n"
        end },
    }
    for i = 1, 3 do
        local idx = i
        local function sc()
            local g = grp()
            local o = g and CB() and CB().ScopeOrderFor(g)
            return o and o[idx]
        end
        orderArgs["block" .. i] = {
            order = 10 + i, type = "group", inline = true, name = "",
            hidden = function() return (gget("sortMode") or "manual") ~= "manual" end,
            args = {
                up = { order = 1, type = "execute", name = CB_UP, width = 0.3,
                    func = function() local g, s = grp(), sc(); if g and s then CB().MoveScope(g, s, -1); Refresh() end end },
                down = { order = 2, type = "execute", name = CB_DOWN, width = 0.3,
                    func = function() local g, s = grp(), sc(); if g and s then CB().MoveScope(g, s, 1); Refresh() end end },
                label = { order = 3, type = "description", width = 2, fontSize = "medium",
                    name = function() local s = sc(); return idx .. ".  " .. (SCOPE_LABEL[s] or tostring(s)) end },
            },
        }
    end
    orderArgs.previewGrp = {
        order = 20, type = "group", inline = true, name = "Current Order",
        hidden = function() return (gget("sortMode") or "manual") ~= "manual" end,
        args = {
            list = { order = 1, type = "description", fontSize = "medium", name = function()
                local g = grp()
                if not (g and CB()) then return "" end
                local lines, n = {}, 0
                for _, scope in ipairs(CB().ScopeOrderFor(g)) do
                    for _, e in ipairs(CB().ScopeEntries(g, scope)) do
                        if e.def.enabled ~= false then
                            n = n + 1
                            lines[#lines + 1] = ("%d.  %s  |cff888888%s|r"):format(n, EntryLabel(e), scope)
                        end
                    end
                end
                if n == 0 then return "No bars yet." end
                return table.concat(lines, "\n")
            end },
        },
    }

    return {
        order = 10 + gi, type = "group", childGroups = "tab",
        name = function() local g = grp(); return g and g.name or ("Group " .. gi) end,
        hidden = function() return grp() == nil end,
        args = {
            enabled = {
                order = 1, type = "toggle", name = "Enable",
                get = function() return gget("enabled") ~= false end,
                set = function(_, v) gset("enabled", v) end,
            },
            name = {
                order = 2, type = "input", name = "Group Name",
                get = function() return gget("name") or "" end,
                set = function(_, v) gset("name", v) end,
            },
            delete = {
                order = 3, type = "execute", name = "Delete Group", confirm = true,
                confirmText = "Delete this Bar Group?",
                func = function()
                    if CB() then
                        CB().RemoveGroup(gi)
                        if ns.CustomBars and ns.CustomBars._rebuildOptions then ns.CustomBars._rebuildOptions() end
                        Refresh()
                    end
                end,
            },
            specTab = {
                order = 10, type = "group",
                args = (function()
                    local a = ScopeTabArgs("spec")
                    a.picker = {
                        order = 0.1, type = "select", name = "Editing Spec", width = "double",
                        dialogControl = "TUI_CascadeDropdown",
                        values = function()
                            local g = grp()
                            local counts = {}
                            if g then
                                for _, r in ipairs(ns.AllSpecs()) do counts[r.id] = cbSpecCount(g, r.id) end
                            end
                            return ns.CascadeDropdown.AllSpecsWithCounts(counts)
                        end,
                        get = function()
                            local sid = tonumber(getEditSpec())
                            local m = sid and ns.SpecMeta(sid)
                            return m and (m.classToken .. ":" .. sid) or nil
                        end,
                        set = function(_, value)
                            local sid = value and value:match("^[A-Z_]+:(%d+)$")
                            if sid then editSpec = sid; NotifyChange() end
                        end,
                    }
                    a.gotoCurSpec = {
                        order = 0.2, type = "execute", width = 1.2,
                        hidden = function() return getEditSpec() == curSpecID() end,
                        name = function()
                            local m = ns.SpecMeta(tonumber(curSpecID()))
                            if not m then return "Go to Current Spec" end
                            local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
                            return "Go to " .. icon .. ns.ClassColor(m.classToken) .. (m.name or "?") .. "|r"
                        end,
                        func = function() editSpec = nil; NotifyChange() end,
                    }
                    a.pickerGap = { order = 0.3, type = "description", width = "full", name = " " }
                    return a
                end)(),
                name = function() return "Spec (" .. scopeCount("spec") .. ")" end,
            },
            classTab = {
                order = 11, type = "group",
                args = (function()
                    local a = ScopeTabArgs("class")
                    a.picker = {
                        order = 0.1, type = "select", name = "Editing Class", width = "double",
                        values = function()
                            local g = grp()
                            local out = {}
                            for cid = 1, GetNumClasses() do
                                local className, classFile = GetClassInfo(cid)
                                if classFile then
                                    local label = ns.ClassColor(classFile) .. (className or classFile) .. "|r"
                                    local n = g and cbClassCount(g, classFile) or 0
                                    if n > 0 then label = label .. " |cFFFFD200(" .. n .. ")|r" end
                                    out[classFile] = label
                                end
                            end
                            return out
                        end,
                        get = function() return getEditClass() end,
                        set = function(_, v) editClass = v; NotifyChange() end,
                    }
                    a.gotoCurClass = {
                        order = 0.2, type = "execute", width = 1.2,
                        hidden = function() return getEditClass() == curClassFile() end,
                        name = function()
                            local cf = curClassFile()
                            local nm = cf and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]
                            return "Go to " .. ns.ClassColor(cf) .. (nm or cf or "Current Class") .. "|r"
                        end,
                        func = function() editClass = nil; NotifyChange() end,
                    }
                    a.pickerGap = { order = 0.3, type = "description", width = "full", name = " " }
                    return a
                end)(),
                name = function() return "Class (" .. scopeCount("class") .. ")" end,
            },
            globalTab = {
                order = 12, type = "group", args = ScopeTabArgs("global"),
                name = function() return "Global (" .. scopeCount("global") .. ")" end,
            },
            presetsTab = {
                order = 13, type = "group", name = "Auras",
                args = presetArgs,
            },
            orderTab = { order = 14, type = "group", name = "Order", args = orderArgs },
            layoutTab = {
                order = 20, type = "group", name = "Layout & Position",
                args = {
                    sizeGrp = {
                        order = 1, type = "group", inline = true, name = "Size",
                        args = {
                            width = { order = 1, type = "range", name = "Width", min = 60, max = 600, step = 1,
                                disabled = function() return gget("inheritWidth") and (gget("anchorFrame") or "UIParent") ~= "UIParent" end,
                                get = function() return gget("width") or 220 end, set = function(_, v) gset("width", v) end },
                            inheritWidth = { order = 1.1, type = "toggle", name = "Inherit Width from Anchor",
                                disabled = function() return (gget("anchorFrame") or "UIParent") == "UIParent" end,
                                get = function() return gget("inheritWidth") and true or false end,
                                set = function(_, v) gset("inheritWidth", v) end },
                            inheritWidthOffset = { order = 1.2, type = "range", name = "Width Nudge", min = -200, max = 200, step = 0.5, bigStep = 1,
                                disabled = function() return not gget("inheritWidth") or (gget("anchorFrame") or "UIParent") == "UIParent" end,
                                get = function() return gget("inheritWidthOffset") or 0 end,
                                set = function(_, v) gset("inheritWidthOffset", v) end },
                            height = { order = 2, type = "range", name = "Height", min = 8, max = 60, step = 1,
                                disabled = function() return gget("inheritHeight") and (gget("anchorFrame") or "UIParent") ~= "UIParent" end,
                                get = function() return gget("height") or 22 end, set = function(_, v) gset("height", v) end },
                            inheritHeight = { order = 2.1, type = "toggle", name = "Inherit Height from Anchor",
                                disabled = function() return (gget("anchorFrame") or "UIParent") == "UIParent" end,
                                get = function() return gget("inheritHeight") and true or false end,
                                set = function(_, v) gset("inheritHeight", v) end },
                            inheritHeightOffset = { order = 2.2, type = "range", name = "Height Nudge", min = -50, max = 50, step = 0.5, bigStep = 1,
                                disabled = function() return not gget("inheritHeight") or (gget("anchorFrame") or "UIParent") == "UIParent" end,
                                get = function() return gget("inheritHeightOffset") or 0 end,
                                set = function(_, v) gset("inheritHeightOffset", v) end },
                        },
                    },
                    barGrp = {
                        order = 2, type = "group", inline = true, name = "Bar",
                        args = {
                            spacing = { order = 1, type = "range", name = "Spacing", min = 0, max = 20, step = 1,
                                get = function() return gget("spacing") or 2 end, set = function(_, v) gset("spacing", v) end },
                            growth = { order = 2, type = "select", name = "Growth Direction",
                                values = { DOWN = "Grow Down", UP = "Grow Up" }, sorting = { "DOWN", "UP" },
                                get = function() return gget("growth") or "DOWN" end, set = function(_, v) gset("growth", v) end },
                            unit = { order = 3, type = "select", name = "Unit",
                                values = { player = "Player", target = "Target", focus = "Focus", pet = "Pet" },
                                sorting = { "player", "target", "focus", "pet" },
                                get = function() return gget("unit") or "player" end,
                                set = function(_, v) gset("unit", v) end },
                            statusBarTexture = { order = 4, type = "select", dialogControl = "LSM30_Statusbar", name = "Bar Texture",
                                values = function() return ns.LSM and ns.LSM:HashTable("statusbar") or {} end,
                                get = function() return gget("statusBarTexture") end, set = function(_, v) gset("statusBarTexture", v) end },
                            useClassColor = { order = 5, type = "toggle", name = "Class Color",
                                get = function() return gget("useClassColor") ~= false end, set = function(_, v) gset("useClassColor", v) end },
                            customColor = { order = 6, type = "color", name = "Custom Color",
                                disabled = function() return gget("useClassColor") ~= false end,
                                get = function() return unpackColor(gget("customColor")) end,
                                set = function(_, r, g, b) gset("customColor", { r = r, g = g, b = b }) end },
                        },
                    },
                    iconGrp = {
                        order = 3, type = "group", inline = true, name = "Icon",
                        args = {
                            iconEnabled = { order = 1, type = "toggle", name = "Show Icon",
                                get = function() return gget("iconEnabled") ~= false end, set = function(_, v) gset("iconEnabled", v) end },
                            iconSpacing = { order = 2, type = "range", name = "Icon Spacing", min = 0, max = 20, step = 1,
                                disabled = function() return gget("iconEnabled") == false end,
                                get = function() return gget("iconSpacing") or 1 end, set = function(_, v) gset("iconSpacing", v) end },
                            iconZoom = { order = 3, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true,
                                disabled = function() return gget("iconEnabled") == false end,
                                get = function() return gget("iconZoom") or 0.1 end, set = function(_, v) gset("iconZoom", v) end },
                        },
                    },
                    posGrp = {
                        order = 4, type = "group", inline = true, name = "Position",
                        args = {
                            toggleMovers = { order = 1, type = "execute", name = "Toggle thingsUI Movers", width = 1.2,
                                func = function() E:ToggleMoveMode("THINGSUI") end },
                            anchorFrame = { order = 2, type = "select", name = "Anchor To", width = "double",
                                values = function() return ns.ANCHORS and ns.ANCHORS.FilteredValues and ns.ANCHORS.FilteredValues() or { UIParent = "UIParent" } end,
                                sorting = function() return ns.ANCHORS and ns.ANCHORS.FilteredOrder and ns.ANCHORS.FilteredOrder() or nil end,
                                get = function() return gget("anchorFrame") or "UIParent" end,
                                set = function(_, v) gset("anchorFrame", v) end },
                            anchorFrameCustom = { order = 3, type = "input", name = "Custom Frame Name",
                                hidden = function() return gget("anchorFrame") ~= "CUSTOM" end,
                                get = function() return gget("anchorFrameCustom") or "" end,
                                set = function(_, v) gset("anchorFrameCustom", v) end },
                            anchorPoint = { order = 4, type = "select", name = "Anchor From (self)",
                                values = ns.POINTS and ns.POINTS.VALUES, sorting = ns.POINTS and ns.POINTS.ORDER,
                                get = function() return gget("anchorPoint") or "CENTER" end,
                                set = function(_, v) gset("anchorPoint", v) end },
                            anchorRelativePoint = { order = 5, type = "select", name = "Anchor To (target)",
                                values = ns.POINTS and ns.POINTS.VALUES, sorting = ns.POINTS and ns.POINTS.ORDER,
                                get = function() return gget("anchorRelativePoint") or "CENTER" end,
                                set = function(_, v) gset("anchorRelativePoint", v) end },
                            anchorXOffset = { order = 6, type = "range", name = "X Offset", min = -800, max = 800, step = 0.5, bigStep = 1,
                                get = function() return gget("anchorXOffset") or 0 end,
                                set = function(_, v) gset("anchorXOffset", v) end },
                            anchorYOffset = { order = 7, type = "range", name = "Y Offset", min = -800, max = 800, step = 0.5, bigStep = 1,
                                get = function() return gget("anchorYOffset") or 0 end,
                                set = function(_, v) gset("anchorYOffset", v) end },
                        },
                    },
                },
            },
            textTab = {
                order = 30, type = "group", name = "Text",
                args = {
                    font = { order = 1, type = "select", dialogControl = "LSM30_Font", name = "Font",
                        values = ns.FontValues,
                        get = function() return gget("font") or "Expressway" end, set = function(_, v) gset("font", v) end },
                    fontSize = { order = 2, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                        get = function() return gget("fontSize") or 12 end, set = function(_, v) gset("fontSize", v) end },
                    fontOutline = { order = 3, type = "select", name = "Outline",
                        values = ns.OUTLINE and ns.OUTLINE.VALUES, sorting = ns.OUTLINE and ns.OUTLINE.ORDER,
                        get = function() return gget("fontOutline") or "OUTLINE" end, set = function(_, v) gset("fontOutline", v) end },
                    nameGroup = {
                        order = 10, type = "group", inline = true, name = "Name",
                        args = {
                            showName = { order = 1, type = "toggle", name = "Show Name",
                                get = function() return gget("showName") ~= false end, set = function(_, v) gset("showName", v) end },
                            namePoint = { order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                                get = function() return gget("namePoint") or "LEFT" end, set = function(_, v) gset("namePoint", v) end },
                            nameXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5,
                                get = function() return gget("nameXOffset") or 4 end, set = function(_, v) gset("nameXOffset", v) end },
                            nameYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                                get = function() return gget("nameYOffset") or 0 end, set = function(_, v) gset("nameYOffset", v) end },
                        },
                    },
                    durationGroup = {
                        order = 20, type = "group", inline = true, name = "Duration",
                        args = {
                            showDuration = { order = 1, type = "toggle", name = "Show Duration",
                                get = function() return gget("showDuration") ~= false end, set = function(_, v) gset("showDuration", v) end },
                            durationPoint = { order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                                get = function() return gget("durationPoint") or "RIGHT" end, set = function(_, v) gset("durationPoint", v) end },
                            durationXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5,
                                get = function() return gget("durationXOffset") or -4 end, set = function(_, v) gset("durationXOffset", v) end },
                            durationYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                                get = function() return gget("durationYOffset") or 0 end, set = function(_, v) gset("durationYOffset", v) end },
                        },
                    },
                    stackGroup = {
                        order = 30, type = "group", inline = true, name = "Stacks",
                        args = {
                            showStacks = { order = 1, type = "toggle", name = "Show Stacks",
                                get = function() return gget("showStacks") ~= false end, set = function(_, v) gset("showStacks", v) end },
                            stackAnchor = { order = 1.5, type = "select", name = "Anchor To",
                                values = { ICON = "Icon", BAR = "Bar" }, sorting = { "ICON", "BAR" },
                                disabled = function() return gget("iconEnabled") == false end,
                                get = function() return gget("stackAnchor") or "ICON" end,
                                set = function(_, v) gset("stackAnchor", v) end },
                            stackFontSize = { order = 2, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                                get = function() return gget("stackFontSize") or 12 end, set = function(_, v) gset("stackFontSize", v) end },
                            stackPoint = { order = 3, type = "select", name = "Position",
                                values = ns.POINTS and ns.POINTS.VALUES, sorting = ns.POINTS and ns.POINTS.ORDER,
                                get = function() return gget("stackPoint") or "CENTER" end, set = function(_, v) gset("stackPoint", v) end },
                            stackXOffset = { order = 4, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5,
                                get = function() return gget("stackXOffset") or 0 end, set = function(_, v) gset("stackXOffset", v) end },
                            stackYOffset = { order = 5, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                                get = function() return gget("stackYOffset") or 0 end, set = function(_, v) gset("stackYOffset", v) end },
                        },
                    },
                },
            },
        },
    }
end

local cbArgs

local function RebuildGroupTabs()
    if not cbArgs then return end
    for k in pairs(cbArgs) do
        if k:match("^group%d+$") then cbArgs[k] = nil end
    end
    local n = math.min(#((CB() and CB().GetGroups()) or {}), MAX_GROUPS)
    for gi = 1, n do
        cbArgs["group" .. gi] = GroupTab(gi)
    end
end

function TUI:CustomBarsOptions()
    cbArgs = {
        newGroup = {
            order = 1, type = "execute", name = "+ New Bar Group", width = 1.2,
            disabled = function() return CB() and #CB().GetGroups() >= MAX_GROUPS end,
            func = function()
                if CB() then
                    CB().NewGroup()
                    RebuildGroupTabs()
                    Refresh()
                end
            end,
        },
        desc = {
            order = 2, type = "description",
            name = "Buff and debuff BARS driven by the aura engine. Bars appear while the aura runs and the stack packs itself. Half-width bars share a line.\n",
        },
    }
    RebuildGroupTabs()
    if ns.CustomBars then ns.CustomBars._rebuildOptions = RebuildGroupTabs end
    return {
        order = 31,
        type = "group",
        name = "Groups - Bars",
        childGroups = "tab",
        args = cbArgs,
    }
end
