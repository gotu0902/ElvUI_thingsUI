local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local NotifyChange = ns.NotifyChange

local CG_X = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t"
local LINK = { 0.6, 0.72, 0.85 }
local MAX_ROWS = 12
local editing = {}

local LIGHTS = { any = "Any Is Up", all = "All Are Up", none = "None Is Up", count = "How Many Are Up" }
local LIGHTS_ORDER = { "any", "all", "none", "count" }
local SIDES = { auto = "Buff or Debuff", HELPFUL = "Buff on You", HARMFUL = "Your Debuff on Target" }
local SIDES_ORDER = { "auto", "HELPFUL", "HARMFUL" }
local GLOW_WHEN = { off = "Off", all = "When All Are Active", missing = "When One Is Missing" }
local GLOW_WHEN_ORDER = { "off", "all", "missing" }
local GLOW_TYPES = { pixel = "Pixel", ants = "Ants", proc = "Proc", pulse = "Pulse" }
local GLOW_TYPES_ORDER = { "pixel", "ants", "proc", "pulse" }

local function CB() return ns.ComboBars end
local function Refresh() CB().QueueRefresh() end

local function CurSpec()
    local BS = ns.BarSetup
    return (BS and BS.GetCurrentSpecID and BS.GetCurrentSpecID()) or 0
end

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

local function OpenCooldownSettings()
    if InCombatLockdown() then return end
    if not _G.CooldownViewerSettings and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
    end
    local cvs = _G.CooldownViewerSettings
    if cvs and cvs.ShowUIPanel and not cvs:IsShown() then cvs:ShowUIPanel() end
end

local function ColorArg(order, name, get, set, hidden, alpha)
    return {
        order = order, type = "color", name = name, hasAlpha = alpha or false, hidden = hidden,
        get = function() local c = get() or {} return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end,
        set = function(_, r, g, b, a) set({ r = r, g = g, b = b, a = a }) end,
    }
end

local function BarTab(bi)
    local function bar() return CB().GetBars()[bi] end
    local function g(k) local b = bar() return b and CB().Get(b, k) end
    local function s(k, v) local b = bar() if b then b[k] = v; Refresh() end end
    local function segs() local b = bar() return (b and b.segments) or {} end
    local function sel()
        local b = bar()
        if not b then return 1 end
        return math.max(1, math.min(editing[b.id] or 1, #b.segments))
    end
    local function seg() return segs()[sel()] end
    local function sget(k, dflt)
        local x = seg()
        local v = x and x[k]
        if v == nil then v = dflt end
        return v
    end
    local function sset(k, v) local x = seg() if x then x[k] = v; Refresh() end end
    local function isText() return g("display") == "text" end
    local function stacked() local b = bar() return b and CB().InStack(b) end
    local function noSeg() return seg() == nil end
    local function isCount() return sget("lights") == "count" end

    local function spellIDs()
        local out = {}
        for id in pairs(sget("spells") or {}) do out[#out + 1] = id end
        table.sort(out)
        return out
    end

    -- where else an aura shows: built once per frame while the panel draws
    local idxCache, idxStamp
    local function UsesOf(id)
        local t = GetTime()
        if idxStamp ~= t or not idxCache then
            local b = bar()
            idxStamp, idxCache = t, CB().UsageIndex(b and b.id)
        end
        return CB().UsesOf(id, bar(), sel(), idxCache)
    end

    local rows = {}
    for ri = 1, MAX_ROWS do
        local function rowID() return spellIDs()[ri] end
        local hidden = function() return rowID() == nil end
        rows["r" .. ri] = {
            order = 10 + ri, type = "description", width = 1.6, fontSize = "medium", hidden = hidden,
            name = function() local id = rowID() return id and SpellLabel(id) or "" end,
        }
        rows["x" .. ri] = {
            order = 10 + ri + 0.1, type = "execute", width = 0.3, name = CG_X, hidden = hidden,
            func = function()
                local id, x = rowID(), seg()
                if id and x and x.spells then x.spells[id] = nil; Refresh() end
            end,
        }
        -- where else this aura shows: links (another minibar of this bar selects it)
        local uses = ns.OptionLinkRowDynamic(10 + ri + 0.15, function()
            local id, b = rowID(), bar()
            if not (id and b) then return {} end
            local out = {}
            for _, e in ipairs(UsesOf(id)) do
                if e.minibar then
                    local i = e.minibar
                    out[#out + 1] = { label = e.label, color = LINK,
                        onClick = function() editing[b.id] = i; C_Timer.After(0, NotifyChange) end }
                else
                    out[#out + 1] = { label = e.label, path = e.path, color = LINK }
                end
            end
            return out
        end)
        uses.width, uses.hidden = 1.45, hidden
        rows["s" .. ri] = { order = 10 + ri + 0.12, type = "description", name = "", width = 0.15, hidden = hidden }
        rows["u" .. ri] = uses
        rows["b" .. ri] = { order = 10 + ri + 0.2, type = "description", name = "", width = "full", hidden = hidden }
    end
    rows.addAura = {
        order = 1, type = "select", dialogControl = "TUI_SpellDropdown", name = "|cFF60E0A0Add Aura|r", width = "double",
        values = function()
            local vals = ns.AuraPick("spec", CurSpec())
            local own = sget("spells") or {}
            -- where an aura already shows (fine to use it here too), this bar's other minibars first
            local b = bar()
            local idx = CB().UsageIndex(b and b.id)
            local mine = {}
            for i, x in ipairs(segs()) do
                if i ~= sel() then
                    for id in pairs(CB().SegSpells(x)) do mine[id] = mine[id] or ("Minibar " .. i) end
                end
            end
            local out = {}
            for k, v in pairs(vals) do
                local id = tonumber(k)
                local used = idx[id]
                local where = mine[id] or (used and used[1].label)
                local more = (mine[id] and used) or (used and #used > 1)
                if own[id] then
                    out[k] = v .. " |cFF60E0A0(added)|r"
                elseif where then
                    out[k] = v .. " |cFF888888(" .. where .. (more and " +" or "") .. ")|r"
                else
                    out[k] = v
                end
            end
            return out
        end,
        -- the ones already in this minibar on top
        sorting = function()
            local list = select(2, ns.AuraPick("spec", CurSpec()))
            local own = sget("spells") or {}
            local top, rest = {}, {}
            for _, k in ipairs(list) do
                if own[tonumber(k)] then top[#top + 1] = k else rest[#rest + 1] = k end
            end
            for _, k in ipairs(rest) do top[#top + 1] = k end
            return top
        end,
        disabled = function() return #spellIDs() >= MAX_ROWS end,
        get = function() return "" end,
        set = function(_, v)
            local x, id = seg(), tonumber(v)
            if x and id then x.spells = x.spells or {}; x.spells[id] = true; Refresh() end
        end,
    }
    rows.addID = {
        order = 2, type = "input", name = "|cFF60E0A0...or by ID or name|r",
        disabled = function() return #spellIDs() >= MAX_ROWS end,
        get = function() return "" end,
        set = function(_, v)
            local x, id = seg(), SpellIDFrom(v)
            if x and id then x.spells = x.spells or {}; x.spells[id] = true; Refresh() end
        end,
    }
    rows.collection = {
        order = 3, type = "select", name = "Aura Collection",
        values = function()
            local out = { [""] = "None" }
            local AC = ns.AuraCollections
            for _, c in ipairs((AC and AC.List()) or {}) do
                if AC.Source(c.key) == "spells" then out[c.key] = c.name end
            end
            return out
        end,
        sorting = function()
            local out = { "" }
            local AC = ns.AuraCollections
            for _, c in ipairs((AC and AC.List()) or {}) do
                if AC.Source(c.key) == "spells" then out[#out + 1] = c.key end
            end
            return out
        end,
        get = function() return sget("collection") or "" end,
        set = function(_, v) sset("collection", (v ~= "") and v or nil) end,
    }
    rows.collectionLink = ns.OptionLinkRowDynamic(4, function()
        local key = sget("collection")
        if key then
            return { { label = "Edit Collection", path = { "thingsUI", "modulesTab", "auraCollections", "col_" .. key } } }
        end
        return { { label = "Make a Collection", path = { "thingsUI", "modulesTab", "auraCollections" } } }
    end)
    rows.empty = {
        order = 5, type = "description",
        name = "|cFF888888No auras of its own yet.|r",
        hidden = function() return spellIDs()[1] ~= nil end,
    }
    -- a heading over the links column, while any aura shows somewhere else
    local function noUses()
        for _, id in ipairs(spellIDs()) do
            if #UsesOf(id) > 0 then return false end
        end
        return true
    end
    rows.hdrA = { order = 10.01, type = "description", name = "", width = 2.05, hidden = noUses }
    rows.hdrU = { order = 10.02, type = "description", name = "|cFFFFD200Also In|r", width = 1.45, hidden = noUses }
    rows.hdrB = { order = 10.03, type = "description", name = "", width = "full", hidden = noUses }

    local function untracked()
        local b = bar()
        return b and CB().Untracked(b) or {}
    end

    local tab = {
        order = 10 + bi, type = "group", childGroups = "tab",
        name = function()
            local b = bar()
            if not b then return "" end
            local nm = b.name or ("Combo Bar " .. b.id)
            if not b.enabled then return "|cFF888888" .. nm .. "|r" end
            return ns.TabName(nm, b.tabColor)
        end,
        args = {
            enabled = {
                order = 1, type = "toggle", name = "Enable", width = 0.6,
                get = function() return g("enabled") end,
                set = function(_, v) s("enabled", v); NotifyChange() end,
            },
            name = {
                order = 2, type = "input", name = "Name",
                get = function() return g("name") or "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v ~= "" then s("name", v) end
                end,
            },
            display = {
                order = 3, type = "select", name = "Display", width = 0.8,
                values = { bar = "Bar", text = "Text" }, sorting = { "bar", "text" },
                get = function() return g("display") end,
                set = function(_, v) s("display", v) end,
            },
            showIn = {
                order = 4, type = "select", name = "Show In", width = 0.9,
                values = { standalone = "Standalone", barsetup = "Bar Setup" }, sorting = { "standalone", "barsetup" },
                get = function() return g("showIn") end,
                set = function(_, v) local b = bar() if b then CB().SetShowIn(b, v) end end,
            },
            loadOn = {
                order = 5, type = "multiselect", name = "Load On (none ticked: every spec)",
                values = function()
                    local out = {}
                    local _, _, classID = UnitClass("player")
                    for _, rec in ipairs(ns.SpecsForClass(classID)) do
                        out[rec.id] = ("|T%d:14:14|t %s"):format(rec.icon or 0, rec.name or rec.id)
                    end
                    local b = bar()
                    for sid in pairs((b and b.specs) or {}) do
                        if not out[sid] then
                            local m = ns.SpecMeta(sid)
                            out[sid] = m and ((m.name or "") .. " " .. (m.className or "")) or tostring(sid)
                        end
                    end
                    return out
                end,
                get = function(_, k) local b = bar() return b and b.specs and b.specs[k] or false end,
                set = function(_, k, v)
                    local b = bar()
                    if not b then return end
                    b.specs = b.specs or {}
                    b.specs[k] = v or nil
                    Refresh()
                end,
            },
            barSetupLink = {
                order = 6, type = "description", dialogControl = "TUI_OptionLink", width = "full", name = "",
                hidden = function() return g("showIn") ~= "barsetup" end,
                arg = { links = { { label = "Open Bar Setup", path = { "thingsUI", "modulesTab", "barSetup" } } } },
            },
            stackNote = {
                order = 6.5, type = "description", width = "full",
                hidden = function()
                    local b = bar()
                    return not b or g("showIn") ~= "barsetup" or CB().InStack(b) or not CB().LoadedHere(b)
                end,
                name = "|cFFFFD200Not in this spec's Bar Setup right now (Bar Setup off, or the bar is unticked there). It shows Standalone meanwhile.|r",
            },
            delete = {
                order = 7, type = "execute", name = "Delete Bar", width = 0.8,
                confirm = true, confirmText = "Delete this Combo Bar?",
                func = function()
                    local b = bar()
                    if b then CB().DeleteBar(b.id) end
                    if CB()._rebuildOptions then CB()._rebuildOptions() end
                    NotifyChange()
                end,
            },

            minibars = {
                order = 10, type = "group", name = "Minibars",
                args = {
                    pick = {
                        order = 1, type = "select", name = "Minibar", width = 1.4,
                        values = function()
                            local out = {}
                            for i, x in ipairs(segs()) do
                                local c = x.color or {}
                                out[i] = ("|cFF%02x%02x%02x%d.|r %s"):format((c.r or 1) * 255, (c.g or 1) * 255, (c.b or 1) * 255,
                                    i, CB().SegName(x, i))
                            end
                            return out
                        end,
                        sorting = function()
                            local out = {}
                            for i in ipairs(segs()) do out[i] = i end
                            return out
                        end,
                        get = function() return sel() end,
                        set = function(_, v) local b = bar() if b then editing[b.id] = v end end,
                    },
                    add = {
                        order = 2, type = "execute", name = "+ Add Minibar", width = 0.8,
                        disabled = function() return #segs() >= 10 end,
                        func = function()
                            local b = bar()
                            if not b then return end
                            b.segments[#b.segments + 1] = ns.Defaults.ComboSegment(#b.segments + 1)
                            editing[b.id] = #b.segments
                            Refresh()
                        end,
                    },
                    left = {
                        order = 3, type = "execute", name = "Move Left", width = 0.7,
                        disabled = function() return sel() <= 1 end,
                        func = function()
                            local b, i = bar(), sel()
                            if not b or i <= 1 then return end
                            b.segments[i], b.segments[i - 1] = b.segments[i - 1], b.segments[i]
                            editing[b.id] = i - 1
                            Refresh()
                        end,
                    },
                    right = {
                        order = 4, type = "execute", name = "Move Right", width = 0.7,
                        disabled = function() return sel() >= #segs() end,
                        func = function()
                            local b, i = bar(), sel()
                            if not b or i >= #b.segments then return end
                            b.segments[i], b.segments[i + 1] = b.segments[i + 1], b.segments[i]
                            editing[b.id] = i + 1
                            Refresh()
                        end,
                    },
                    remove = {
                        order = 5, type = "execute", name = "Remove", width = 0.6,
                        disabled = noSeg,
                        confirm = true, confirmText = "Remove this minibar?",
                        func = function()
                            local b, i = bar(), sel()
                            if b and b.segments[i] then table.remove(b.segments, i); Refresh() end
                        end,
                    },
                    editor = {
                        order = 10, type = "group", inline = true, hidden = noSeg,
                        name = function() return ("Minibar %d"):format(sel()) end,
                        args = {
                            -- shows what the minibar says; empty = no text
                            label = {
                                order = 1, type = "input", name = "Text",
                                get = function() local x = seg() return x and CB().SegLabel(x, sel()) or "" end,
                                set = function(_, v)
                                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                    sset("label", v)
                                end,
                            },
                            auraName = {
                                order = 1.5, type = "execute", name = "Use Aura Name", width = 0.8,
                                hidden = function() return sget("label") == nil end,
                                func = function() sset("label", nil) end,
                            },
                            color = ColorArg(2, "Color", function() return sget("color") end,
                                function(c) sset("color", c) end),
                            ownText = {
                                order = 2.1, type = "toggle", name = "Own Text Color", width = 0.9,
                                hidden = isText,
                                get = function() return sget("textColor") ~= nil end,
                                set = function(_, v)
                                    local b = bar()
                                    sset("textColor", v and ns.DeepCopy((b and CB().Get(b, "nameColor")) or { r = 1, g = 1, b = 1 }) or nil)
                                end,
                            },
                            textColor = ColorArg(2.2, "Text Color", function() return sget("textColor") end,
                                function(c) sset("textColor", c) end,
                                function() return isText() or sget("textColor") == nil end),
                            brk = { order = 2.5, type = "description", name = "", width = "full" },
                            lights = {
                                order = 3, type = "select", name = "Color When",
                                values = LIGHTS, sorting = LIGHTS_ORDER,
                                get = function() return sget("lights", "any") end,
                                set = function(_, v) sset("lights", v) end,
                            },
                            upTo = {
                                order = 4, type = "range", name = "Up To", min = 2, max = 10, step = 1,
                                hidden = function() return not isCount() end,
                                get = function() return sget("pieces", 3) end,
                                set = function(_, v) sset("pieces", v) end,
                            },
                            side = {
                                order = 5, type = "select", name = "Aura Is",
                                values = function()
                                    if isCount() then return { HELPFUL = SIDES.HELPFUL, HARMFUL = SIDES.HARMFUL } end
                                    return SIDES
                                end,
                                sorting = function()
                                    if isCount() then return { "HELPFUL", "HARMFUL" } end
                                    return SIDES_ORDER
                                end,
                                get = function() local x = seg() return x and CB().Side(x) or "auto" end,
                                set = function(_, v) sset("side", v) end,
                            },
                            fill = {
                                order = 6, type = "select", name = "Fill",
                                values = { full = "Full", time = "Drains With Time" }, sorting = { "full", "time" },
                                hidden = function()
                                    local x = seg()
                                    return isText() or not x or isCount() or CB().LuaLit(x)
                                end,
                                get = function() return sget("fill", "full") end,
                                set = function(_, v) sset("fill", v) end,
                            },
                            glow = {
                                order = 7, type = "toggle", name = "Glow While Active",
                                get = function() return sget("glow") or false end,
                                set = function(_, v) sset("glow", v or nil) end,
                            },
                            auras = {
                                order = 20, type = "group", inline = true, name = "Auras",
                                args = rows,
                            },
                        },
                    },
                    trackNote = {
                        order = 30, type = "description", width = "full",
                        hidden = function() return #untracked() == 0 end,
                        name = function()
                            local names = {}
                            for _, id in ipairs(untracked()) do names[#names + 1] = C_Spell.GetSpellName(id) or tostring(id) end
                            return "\n|cFFFFD200All Are Up, None Is Up and the bar glow follow auras in combat through Blizzard's Cooldown Manager. Add these to Buffs or Bars there (out of combat they work anyway):|r\n"
                                .. table.concat(names, ", ")
                        end,
                    },
                    trackOpen = {
                        order = 31, type = "execute", name = "Open Cooldown Settings",
                        hidden = function() return #untracked() == 0 end,
                        func = OpenCooldownSettings,
                    },
                },
            },

            look = {
                order = 20, type = "group", name = "Look",
                args = {
                    height = {
                        order = 1, type = "range", name = "Height", min = 4, max = 60, step = 1,
                        hidden = isText,
                        get = function() return g("height") end,
                        set = function(_, v) s("height", v) end,
                    },
                    width = {
                        order = 2, type = "range", name = "Width", min = 40, max = 800, step = 1,
                        hidden = function() return isText() or stacked() end,
                        get = function() return g("width") end,
                        set = function(_, v) s("width", v) end,
                    },
                    gap = {
                        order = 3, type = "range", name = "Gap", min = 0, max = 20, step = 1,
                        hidden = isText,
                        get = function() return g("gap") end,
                        set = function(_, v) s("gap", v) end,
                    },
                    textSpacing = {
                        order = 3, type = "range", name = "Spacing", min = 0, max = 60, step = 1,
                        hidden = function() return not isText() end,
                        get = function() return g("textSpacing") end,
                        set = function(_, v) s("textSpacing", v) end,
                    },
                    texture = {
                        order = 4, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
                        values = function() return ns.LSM and ns.LSM:HashTable("statusbar") or {} end,
                        get = function() return g("statusBarTexture") end,
                        set = function(_, v) s("statusBarTexture", v) end,
                    },
                    emptyColor = ColorArg(5, "Empty Color", function() return g("emptyColor") end,
                        function(c) s("emptyColor", c) end, nil, true),
                    showBorder = {
                        order = 6, type = "toggle", name = "Border", width = 0.6,
                        get = function() return g("showBorder") end,
                        set = function(_, v) s("showBorder", v) end,
                    },
                    borderColor = ColorArg(7, "Border Color", function() return g("borderColor") end,
                        function(c) s("borderColor", c) end, function() return not g("showBorder") end, true),
                    frameStrata = {
                        order = 8, type = "select", name = "Frame Strata",
                        values = ns.STRATA.VALUES, sorting = ns.STRATA.ORDER,
                        get = function() return g("frameStrata") end,
                        set = function(_, v) s("frameStrata", v) end,
                    },
                },
            },

            text = {
                order = 25, type = "group", name = "Text",
                args = {
                    font = {
                        order = 1, type = "select", dialogControl = "LSM30_Font", name = "Font",
                        values = ns.FontValues,
                        get = function() return g("font") end,
                        set = function(_, v) s("font", v) end,
                    },
                    fontSize = {
                        order = 2, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                        get = function() return g("fontSize") end,
                        set = function(_, v) s("fontSize", v) end,
                    },
                    fontOutline = {
                        order = 3, type = "select", name = "Outline",
                        values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                        get = function() return g("fontOutline") end,
                        set = function(_, v) s("fontOutline", v) end,
                    },
                    textCase = {
                        order = 4, type = "select", name = "Case",
                        values = { normal = "Normal", upper = "UPPERCASE" }, sorting = { "normal", "upper" },
                        get = function() return g("textCase") or "normal" end,
                        set = function(_, v) s("textCase", (v ~= "normal") and v or nil) end,
                    },
                    justify = {
                        order = 5, type = "select", name = "Align",
                        values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" },
                        hidden = function() return not isText() end,
                        get = function() return g("justify") end,
                        set = function(_, v) s("justify", v) end,
                    },
                    textNote = {
                        order = 6, type = "description", width = "full",
                        name = "|cff888888Each minibar's text and its own text color are in the Minibars tab.|r\n",
                    },
                    nameGroup = {
                        order = 10, type = "group", inline = true, name = "Name",
                        args = {
                            showLabels = {
                                order = 1, type = "toggle", name = "Show Name",
                                hidden = isText,
                                get = function() return g("showLabels") end,
                                set = function(_, v) s("showLabels", v) end,
                            },
                            namePoint = {
                                order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" },
                                hidden = isText,
                                get = function() return g("namePoint") end,
                                set = function(_, v) s("namePoint", v) end,
                            },
                            nameXOffset = {
                                order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                                hidden = isText,
                                get = function() return g("nameXOffset") end,
                                set = function(_, v) s("nameXOffset", v) end,
                            },
                            nameYOffset = {
                                order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.01, bigStep = 1,
                                hidden = isText,
                                get = function() return g("nameYOffset") end,
                                set = function(_, v) s("nameYOffset", v) end,
                            },
                            nameColor = ColorArg(5, "Color", function() return g("nameColor") end,
                                function(c) s("nameColor", c) end, isText),
                            dimTextColor = ColorArg(6, "Inactive Color", function() return g("dimTextColor") end,
                                function(c) s("dimTextColor", c) end, function() return not isText() end),
                            activeNote = {
                                order = 7, type = "description", width = "full",
                                hidden = function() return not isText() end,
                                name = "|cff888888Active: the minibar's color.|r",
                            },
                        },
                    },
                    durationGroup = {
                        order = 20, type = "group", inline = true, name = "Duration",
                        args = {
                            showDuration = {
                                order = 1, type = "toggle", name = "Show Duration",
                                get = function() return g("showDuration") end,
                                set = function(_, v) s("showDuration", v) end,
                            },
                            durationPoint = {
                                order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" },
                                hidden = isText,
                                get = function() return g("durationPoint") end,
                                set = function(_, v) s("durationPoint", v) end,
                            },
                            durationXOffset = {
                                order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                                hidden = isText,
                                get = function() return g("durationXOffset") end,
                                set = function(_, v) s("durationXOffset", v) end,
                            },
                            durationYOffset = {
                                order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.01, bigStep = 1,
                                hidden = isText,
                                get = function() return g("durationYOffset") end,
                                set = function(_, v) s("durationYOffset", v) end,
                            },
                            durationColor = ColorArg(5, "Color", function() return g("durationColor") end,
                                function(c) s("durationColor", c) end, isText),
                        },
                    },
                    stackGroup = {
                        order = 30, type = "group", inline = true, name = "Stacks",
                        hidden = isText,
                        args = {
                            showStacks = {
                                order = 1, type = "toggle", name = "Show Stacks",
                                get = function() return g("showStacks") end,
                                set = function(_, v) s("showStacks", v) end,
                            },
                            stackFontSize = {
                                order = 2, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                                get = function() return g("stackFontSize") end,
                                set = function(_, v) s("stackFontSize", v) end,
                            },
                            stackFontOutline = {
                                order = 2.5, type = "select", name = "Outline",
                                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                                get = function() return g("stackFontOutline") end,
                                set = function(_, v) s("stackFontOutline", v) end,
                            },
                            stackPoint = {
                                order = 3, type = "select", name = "Position",
                                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                get = function() return g("stackPoint") end,
                                set = function(_, v) s("stackPoint", v) end,
                            },
                            stackXOffset = {
                                order = 4, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                                get = function() return g("stackXOffset") end,
                                set = function(_, v) s("stackXOffset", v) end,
                            },
                            stackYOffset = {
                                order = 5, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.01, bigStep = 1,
                                get = function() return g("stackYOffset") end,
                                set = function(_, v) s("stackYOffset", v) end,
                            },
                            stackColor = ColorArg(6, "Color", function() return g("stackColor") end,
                                function(c) s("stackColor", c) end),
                        },
                    },
                },
            },

            glow = {
                order = 30, type = "group", name = "Glow",
                args = {
                    glowWhen = {
                        order = 1, type = "select", name = "Glow the Bar",
                        values = GLOW_WHEN, sorting = GLOW_WHEN_ORDER,
                        get = function() return g("glowWhen") end,
                        set = function(_, v) s("glowWhen", v) end,
                    },
                    glowCombat = {
                        order = 2, type = "toggle", name = "Only In Combat",
                        disabled = function() return g("glowWhen") == "off" end,
                        get = function() return g("glowCombat") end,
                        set = function(_, v) s("glowCombat", v) end,
                    },
                    look = {
                        order = 10, type = "group", inline = true, name = "Look (also Glow While Active)",
                        args = {
                            glowType = {
                                order = 1, type = "select", name = "Type",
                                values = GLOW_TYPES, sorting = GLOW_TYPES_ORDER,
                                get = function() return g("glowType") end,
                                set = function(_, v) s("glowType", v) end,
                            },
                            glowColor = ColorArg(2, "Color", function() return g("glowColor") end,
                                function(c) s("glowColor", c) end, nil, true),
                            glowThickness = {
                                order = 3, type = "range", name = "Thickness", min = 0.5, max = 10, step = 0.5,
                                disabled = function() return g("glowType") == "proc" end,
                                get = function() return g("glowThickness") end,
                                set = function(_, v) s("glowThickness", v) end,
                            },
                            glowLength = {
                                order = 4, type = "range", name = "Length", min = 1, max = 6, step = 1,
                                disabled = function() return g("glowType") ~= "pixel" end,
                                get = function() return math.min(6, g("glowLength")) end,
                                set = function(_, v) s("glowLength", v) end,
                            },
                            glowLines = {
                                order = 5, type = "range", name = "Particles", min = 1, max = 12, step = 1,
                                disabled = function() local t = g("glowType") return t ~= "pixel" and t ~= "ants" end,
                                get = function() return math.min(12, g("glowLines")) end,
                                set = function(_, v) s("glowLines", v) end,
                            },
                            glowSpeed = {
                                order = 6, type = "range", name = "Speed", min = 0.05, max = 2, step = 0.05, bigStep = 0.25,
                                get = function() return math.abs(g("glowSpeed")) end,
                                set = function(_, v) s("glowSpeed", v) end,
                            },
                            glowOffset = {
                                order = 7, type = "range", name = "Offset", min = -10, max = 10, step = 0.5,
                                disabled = function() local t = g("glowType") return t ~= "pixel" and t ~= "ants" end,
                                get = function() return g("glowOffset") end,
                                set = function(_, v) s("glowOffset", v) end,
                            },
                        },
                    },
                    trackNote = {
                        order = 20, type = "description", width = "full",
                        hidden = function() return g("glowWhen") == "off" or #untracked() == 0 end,
                        name = "\n|cFFFFD200Some auras aren't in Blizzard's Cooldown Manager: the glow can't see them in combat. See the Minibars tab.|r",
                    },
                },
            },

            position = {
                order = 40, type = "group", name = "Position",
                hidden = stacked,
                args = {
                    anchorFrame = {
                        order = 1, type = "select", name = "Anchor To",
                        values = function() return ns.ANCHORS.FilteredValues() end,
                        sorting = function() return ns.ANCHORS.FilteredOrder() end,
                        get = function() return g("anchorFrame") end,
                        set = function(_, v)
                            local b = bar()
                            if not b then return end
                            if v ~= g("anchorFrame") then
                                ns.ANCHORS.ResetPlacement(b, { "anchorPoint", "anchorRelativePoint", "anchorXOffset", "anchorYOffset" })
                            end
                            s("anchorFrame", v)
                        end,
                    },
                    anchorPoint = {
                        order = 2, type = "select", name = "Point",
                        values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                        get = function() return g("anchorPoint") end,
                        set = function(_, v) s("anchorPoint", v) end,
                    },
                    anchorRelativePoint = {
                        order = 3, type = "select", name = "To Point",
                        values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                        get = function() return g("anchorRelativePoint") end,
                        set = function(_, v) s("anchorRelativePoint", v) end,
                    },
                    anchorXOffset = {
                        order = 4, type = "range", name = "X Offset", min = -1000, max = 1000, step = 1,
                        get = function() return g("anchorXOffset") end,
                        set = function(_, v) s("anchorXOffset", v) end,
                    },
                    anchorYOffset = {
                        order = 5, type = "range", name = "Y Offset", min = -1000, max = 1000, step = 1,
                        get = function() return g("anchorYOffset") end,
                        set = function(_, v) s("anchorYOffset", v) end,
                    },
                },
            },

            visibility = {
                order = 50, type = "group", name = "Visibility",
                args = ns.VisibilityArgs(function()
                    local b = bar()
                    if not b then return {} end
                    b.visibility = b.visibility or {}
                    return b.visibility
                end, Refresh),
            },
        },
    }
    return tab
end

local args

local function Rebuild()
    if not args then return end
    for k in pairs(args) do
        if k:match("^bar%d+$") then args[k] = nil end
    end
    for i in ipairs(CB().GetBars()) do args["bar" .. i] = BarTab(i) end
end

function TUI:ComboBarsOptions()
    args = {
        new = {
            order = 1, type = "execute", name = "+ New Combo Bar", width = 1.2,
            func = function()
                CB().NewBar()
                Rebuild()
                NotifyChange()
            end,
        },
        desc = {
            order = 2, type = "description",
            name = "Minibars that color in while their auras are up: one per buff or debuff, one for a whole list, or a count (how many of your DoTs are up). Show it as a bar or as a line of text.\n",
        },
    }
    Rebuild()
    CB()._rebuildOptions = Rebuild
    return {
        order = 0.45, type = "group", name = "Aura Combo Bars", childGroups = "tab",
        args = args,
    }
end
