local _, ns = ...
local E   = ns.E
local TUI = ns.TUI
local NotifyChange = ns.NotifyChange

local function CurrentSpecID()
    local i = GetSpecialization and GetSpecialization()
    return i and select(1, GetSpecializationInfo(i)) or 0
end

local POTION_NAMES = {
    [241288] = "Potion of Recklessness",
    [241308] = "Light's Potential",
    [241292] = "Draught of Rampant Abandon",
}
local function PotionValues()
    local v = {}
    for id, name in pairs(POTION_NAMES) do
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        v[id] = (icon and ("|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. name
    end
    return v
end
local function PotionSorting()
    local s = {}
    for id in pairs(POTION_NAMES) do s[#s + 1] = id end
    table.sort(s, function(a, b) return POTION_NAMES[a] < POTION_NAMES[b] end)
    return s
end

-- Colours match the module sidebar (Options.lua Colorize): CDM gold, Custom Groups pink.
local CDM_HEX, CG_HEX = "FFD27F", "F20553"
local function DestinationValues()
    local v = {
        essential  = "|cFF" .. CDM_HEX .. "CDM: Essential Cooldowns|r",
        utility    = "|cFF" .. CDM_HEX .. "CDM: Utility Cooldowns|r",
        standalone = "Standalone (own mover)",
    }
    local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups() or {}
    for _, g in ipairs(groups) do
        v[g.id] = "|cFF" .. CG_HEX .. "Custom Group: " .. (g.name or tostring(g.id)) .. "|r"
            .. (g.enabled and "" or " |cFFFF6060(off)|r")
    end
    return v
end
-- CDM first, then Custom Groups, then Standalone.
local function DestinationSorting()
    local s = { "essential", "utility" }
    local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups() or {}
    local sorted = {}
    for _, g in ipairs(groups) do sorted[#sorted + 1] = g end
    table.sort(sorted, function(a, b) return (a.name or "") < (b.name or "") end)
    for _, g in ipairs(sorted) do s[#s + 1] = g.id end
    s[#s + 1] = "standalone"
    return s
end

-- The destination's options page as (label, pathKeys) for an OptionLink. Custom Group
-- tabs are keyed group<index> (CustomGroupsOptions rebuildGroupEntries).
local function DestLink(t)
    if not t.destination then return end
    if t.destination == "essential" then return "Open: CDM Essential", { "thingsUI", "modulesTab", "cdm", "essentialTab" } end
    if t.destination == "utility"   then return "Open: CDM Utility",   { "thingsUI", "modulesTab", "cdm", "utilityTab" } end
    local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups()
    if not groups then return end
    for i, g in ipairs(groups) do
        if g.id == t.destination then
            return "Open: " .. (g.name or ("Group " .. g.id)),
                   { "thingsUI", "modulesTab", "customGroups", "group" .. i }
        end
    end
end

local function GroupOf(dest)
    return ns.CustomGroups and ns.CustomGroups.GroupByID and ns.CustomGroups.GroupByID(dest)
end

local function TimerLabel(t)
    local T = ns.Timers
    local tex = T and T.GetTexture(t)
    local label
    if t.kind == "lust" then
        label = "Hero / Lust"
    elseif t.kind == "spell" then
        label = (C_Spell.GetSpellName and C_Spell.GetSpellName(t.spellID)) or ("Spell " .. tostring(t.spellID))
    else
        label = (C_Item.GetItemInfo(t.itemID)) or ("Item " .. tostring(t.itemID))
    end
    return (tex and ("|T" .. tex .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. (label or "?")
end

local function RemoveByID(id)
    local T = ns.Timers
    for i, t in ipairs(T.GetTimers()) do
        if t.id == id then T.RemoveTimer(i); return end
    end
end

-- One tab's worth of settings for a timer.
local function TimerTab(t, id, order, Rebuild)
    local T = ns.Timers
    local args = {
        disable = {
            order = 1, type = "toggle", name = "Disable Timer", width = 1.0,
            get = function() return not t.enabled end,
            set = function(_, v) t.enabled = not v; T.Update() end,
        },
        dest = {
            order = 2, type = "select", name = "Destination", width = 1.5,
            values = DestinationValues, sorting = DestinationSorting,
            disabled = function() return not t.enabled end,
            get = function() return t.destination end,
            set = function(_, v)
                t.destination = v
                if type(v) == "number" and not t.groupScope then t.groupScope = "global" end
                T.Update(); Rebuild(); NotifyChange()  -- Rebuild refreshes the link + scope picker
            end,
        },
        styleHeader = { order = 10, type = "header", name = "Behaviour" },
        showCDTimer = {
            order = 11, type = "toggle", name = "Show Buff Swipe", width = 1.2,
            hidden = function() return t.kind == "lust" end,  -- lust always shows the buff
            get = function() return t.showCDTimer end,
            set = function(_, v) t.showCDTimer = v; T.Update() end,
        },
        trackCooldown = {
            order = 11.5, type = "toggle", name = "Show Cooldown", width = 1.2,
            hidden = function() return t.kind == "lust" end,
            get = function() return t.trackCooldown ~= false end,
            set = function(_, v) t.trackCooldown = v; T.Update() end,
        },
        showIdle = {
            order = 12, type = "toggle", name = "Show When Idle", width = 1.0,
            hidden = function() return t.kind == "lust" end,  -- lust is buff-only (never idle)
            get = function() return t.showIdle end,
            set = function(_, v) t.showIdle = v; T.Update() end,
        },
        -- Glow look is per-timer, independent of destination (rides the icon). Same set
        -- of controls as Special Icons (Type/Color/Thickness/Length/Particles/Speed/X/Y).
        glowGroup = {
            order = 13, type = "group", inline = true, name = "Glow",
            args = {
                showGlow = {
                    order = 1, type = "toggle", width = 1.0,
                    name = function() return t.kind == "lust" and "Glow when Active" or "Show Glow" end,
                    get = function() return t.glowReadyInCombat end,
                    set = function(_, v) t.glowReadyInCombat = v; T.Update() end,
                },
                glowWhen = {
                    order = 2, type = "select", name = "Glow When", width = 1.2,
                    hidden = function() return t.kind == "lust" or not t.glowReadyInCombat end,
                    -- "Ready in Combat" needs Show When Idle (else the icon isn't up to glow).
                    values = function()
                        local v = { active = "While Active" }
                        if t.showIdle then v.ready = "Ready in Combat" end
                        return v
                    end,
                    sorting = function() return t.showIdle and { "active", "ready" } or { "active" } end,
                    get = function()
                        if t.glowWhen == "ready" and not t.showIdle then return "active" end
                        return t.glowWhen or "active"
                    end,
                    set = function(_, v) t.glowWhen = v; T.Update() end,
                },
                glowType = {
                    order = 3, type = "select", name = "Type", width = 1.0,
                    disabled = function() return not t.glowReadyInCombat end,
                    values = { pixel = "Pixel", autocast = "Autocast", proc = "Proc", button = "Button" },
                    sorting = { "pixel", "autocast", "proc", "button" },
                    get = function() return t.glowType or "pixel" end,
                    set = function(_, v) t.glowType = v; T.Update() end,
                },
                glowColor = {
                    order = 4, type = "color", name = "Color", width = 0.7, hasAlpha = true,
                    disabled = function() return not t.glowReadyInCombat end,
                    get = function() local c = t.glowColor or {}; return c.r or 1, c.g or 1, c.b or 0, c.a or 1 end,
                    set = function(_, r, g, b, a)
                        t.glowColor = t.glowColor or {}
                        local c = t.glowColor; c.r, c.g, c.b, c.a = r, g, b, a; T.Update()
                    end,
                },
                glowThickness = {
                    order = 5, type = "range", name = "Thickness", min = 0.5, max = 10, step = 0.5,
                    disabled = function() return not t.glowReadyInCombat or t.glowType == "button" or t.glowType == "proc" end,
                    get = function() return t.glowThickness or 2 end,
                    set = function(_, v) t.glowThickness = v; T.Update() end,
                },
                glowLength = {
                    order = 6, type = "range", name = "Length", min = 1, max = 40, step = 1,
                    disabled = function() return not t.glowReadyInCombat or (t.glowType or "pixel") ~= "pixel" end,
                    get = function() return t.glowLength or 10 end,
                    set = function(_, v) t.glowLength = v; T.Update() end,
                },
                glowN = {
                    order = 7, type = "range", name = "Particles", min = 1, max = 32, step = 1,
                    disabled = function() return not t.glowReadyInCombat or t.glowType == "button" or t.glowType == "proc" end,
                    get = function() return t.glowN or 8 end,
                    set = function(_, v) t.glowN = v; T.Update() end,
                },
                glowFrequency = {
                    order = 8, type = "range", name = "Speed", min = -2, max = 2, step = 0.05, bigStep = 0.25,
                    disabled = function() return not t.glowReadyInCombat or t.glowType == "button" end,
                    get = function() return t.glowFrequency or 0.25 end,
                    set = function(_, v) t.glowFrequency = v; T.Update() end,
                },
                glowXOffset = {
                    order = 9, type = "range", name = "X Offset", min = -20, max = 20, step = 0.5,
                    disabled = function() return not t.glowReadyInCombat or t.glowType == "button" or t.glowType == "proc" end,
                    get = function() return t.glowXOffset or 0 end,
                    set = function(_, v) t.glowXOffset = v; T.Update() end,
                },
                glowYOffset = {
                    order = 10, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                    disabled = function() return not t.glowReadyInCombat or t.glowType == "button" or t.glowType == "proc" end,
                    get = function() return t.glowYOffset or 0 end,
                    set = function(_, v) t.glowYOffset = v; T.Update() end,
                },
            },
        },
    }
    -- Built-ins (Hero/Lust) can't be removed.
    if not t.builtin then
        args.remove = {
            order = 3, type = "execute", name = "Remove", width = 0.8,
            confirm = true, confirmText = "Remove this timer?",
            func = function() RemoveByID(id); Rebuild(); NotifyChange() end,
        }
    end
    -- Timer -> Custom Group: which scope of the group shows it (Global / this Class / this Spec).
    if type(t.destination) == "number" and GroupOf(t.destination) then
        args.groupScope = {
            order = 2.5, type = "select", name = "Show On", width = 1.2,
            values = { global = "Global", class = "This Class", spec = "This Spec" },
            sorting = { "global", "class", "spec" },
            get = function()
                local s = t.groupScope or "global"
                if s == "global" then return "global" end
                return (type(s) == "number") and "spec" or "class"
            end,
            set = function(_, v)
                if v == "spec" then t.groupScope = CurrentSpecID()
                elseif v == "class" then local _, cf = UnitClass("player"); t.groupScope = cf
                else t.groupScope = "global" end
                T.Update(); NotifyChange()
            end,
        }
    end
    -- Clickable link to the destination's config page (ns.OptionLink, our underlined
    -- text-link widget). Refreshes when the destination dropdown changes (set rebuilds).
    local lbl, path = DestLink(t)
    if lbl and ns.OptionLink then
        args.gotoDest = ns.OptionLink(4, lbl, unpack(path))
    end
    if t.kind ~= "lust" then
        args.durHeader = { order = 20, type = "header", name = "Duration" }
        args.durationAuto = {
            order = 21, type = "toggle", name = "Auto Duration", width = 1.3,
            get = function() return t.durationAuto end,
            set = function(_, v) t.durationAuto = v; T.Update() end,
        }
        args.duration = {
            order = 22, type = "range", name = "Manual Duration (s)", width = 1.3,
            min = 0, max = 600, step = 0.5, bigStep = 1,
            hidden = function() return t.durationAuto end,
            get = function() return t.duration or 0 end,
            set = function(_, v) t.duration = (v > 0) and v or nil; T.Update() end,
        }
    end
    -- Standalone owns its own size / position (/emove) / cooldown text - CDM & Custom
    -- Group hosts inherit those from the host, so these only show for Standalone.
    if t.destination == "standalone" then
        local function txt() t.text = t.text or { showCooldown = true }; return t.text end
        args.saHeader = { order = 30, type = "header", name = "Standalone" }
        args.saNote = { order = 31, type = "description",
            name = "Drag with |cFFFFD200/emove|r (\"Timer: …\") or use the offsets below, they should be buddies.\n" }
        args.saSize = {
            order = 32, type = "range", name = "Icon Size", width = 1.3,
            min = 12, max = 80, step = 1,
            get = function() return t.iconSize or 36 end,
            set = function(_, v) t.iconSize = v; T.Update() end,
        }
        args.saAnchorFrame = {
            order = 33, type = "select", name = "Anchor To", width = 1.3,
            values = ns.ANCHORS.GetSharedAnchorValues, sorting = ns.ANCHORS.GetSharedAnchorOrder,
            get = function() return t.anchorFrame or "UIParent" end,
            set = function(_, v) t.anchorFrame = v; T.Update() end,
        }
        args.saAnchorCustom = {
            order = 33.5, type = "input", name = "Custom Frame Name", width = 1.5,
            hidden = function() return t.anchorFrame ~= "CUSTOM" end,
            get = function() return t.anchorFrameCustom or "" end,
            set = function(_, v) t.anchorFrameCustom = (v or ""):gsub("%s", ""); T.Update() end,
        }
        args.saAnchorPoint = {
            order = 34, type = "select", name = "Point", width = 1.0,
            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
            get = function() return t.anchorPoint or "CENTER" end,
            set = function(_, v) t.anchorPoint = v; T.Update() end,
        }
        args.saAnchorRel = {
            order = 35, type = "select", name = "Anchor To (point)", width = 1.2,
            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
            hidden = function() return (t.anchorFrame or "UIParent") == "UIParent" end,
            get = function() return t.anchorRelativePoint or "CENTER" end,
            set = function(_, v) t.anchorRelativePoint = v; T.Update() end,
        }
        args.saX = {
            order = 36, type = "range", name = "X Offset", width = 1.1, min = -800, max = 800, step = 1,
            get = function() return t.anchorXOffset or 0 end,
            set = function(_, v) t.anchorXOffset = v; T.Update() end,
        }
        args.saY = {
            order = 37, type = "range", name = "Y Offset", width = 1.1, min = -800, max = 800, step = 1,
            get = function() return t.anchorYOffset or 0 end,
            set = function(_, v) t.anchorYOffset = v; T.Update() end,
        }
        local function durShown() return (not t.text) or t.text.showCooldown ~= false end
        args.saTextHeader = { order = 40, type = "header", name = "Duration Text" }
        args.saTxtShow = {
            order = 41, type = "toggle", name = "Show Duration", width = 1.5,
            get = function() return durShown() end,
            set = function(_, v) txt().showCooldown = v; T.Update() end,
        }
        args.saTxtFont = {
            order = 42, type = "select", name = "Font", dialogControl = "LSM30_Font",
            values = ns.FontValues, hidden = function() return not durShown() end,
            get = function() return t.text and t.text.cooldownFont end,
            set = function(_, v) txt().cooldownFont = v; T.Update() end,
        }
        args.saTxtSize = {
            order = 43, type = "range", name = "Font Size", min = 6, max = 32, step = 1,
            hidden = function() return not durShown() end,
            get = function() return (t.text and t.text.cooldownFontSize) or 16 end,
            set = function(_, v) txt().cooldownFontSize = v; T.Update() end,
        }
        args.saTxtOutline = {
            order = 44, type = "select", name = "Outline",
            values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
            hidden = function() return not durShown() end,
            get = function() return (t.text and t.text.cooldownFontOutline) or "OUTLINE" end,
            set = function(_, v) txt().cooldownFontOutline = v; T.Update() end,
        }
        args.saTxtColor = {
            order = 45, type = "color", name = "Colour",
            hidden = function() return not durShown() end,
            get = function() local c = (t.text and t.text.cooldownColor) or {}; return c.r or 1, c.g or 1, c.b or 1 end,
            set = function(_, r, g, b) txt().cooldownColor = { r = r, g = g, b = b }; T.Update() end,
        }
        -- Item count (Custom Groups draws its own; standalone needs its own toggle + text).
        if t.kind == "item" then
            local function cntShown() return t.text and t.text.showCount end
            args.saCountHeader = { order = 50, type = "header", name = "Item Count" }
            args.saCountShow = {
                order = 51, type = "toggle", name = "Show Item Count", width = 1.5,
                get = function() return cntShown() end,
                set = function(_, v) txt().showCount = v; T.Update() end,
            }
            args.saCountFont = {
                order = 52, type = "select", name = "Font", dialogControl = "LSM30_Font",
                values = ns.FontValues, hidden = function() return not cntShown() end,
                get = function() return t.text and t.text.countFont end,
                set = function(_, v) txt().countFont = v; T.Update() end,
            }
            args.saCountSize = {
                order = 53, type = "range", name = "Font Size", min = 6, max = 32, step = 1,
                hidden = function() return not cntShown() end,
                get = function() return (t.text and t.text.countFontSize) or 12 end,
                set = function(_, v) txt().countFontSize = v; T.Update() end,
            }
            args.saCountOutline = {
                order = 54, type = "select", name = "Outline",
                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                hidden = function() return not cntShown() end,
                get = function() return (t.text and t.text.countFontOutline) or "OUTLINE" end,
                set = function(_, v) txt().countFontOutline = v; T.Update() end,
            }
            args.saCountColor = {
                order = 55, type = "color", name = "Colour",
                hidden = function() return not cntShown() end,
                get = function() local c = (t.text and t.text.countColor) or {}; return c.r or 1, c.g or 1, c.b or 1 end,
                set = function(_, r, g, b) txt().countColor = { r = r, g = g, b = b }; T.Update() end,
            }
            args.saCountPoint = {
                order = 56, type = "select", name = "Anchor Point", width = 1.1,
                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                hidden = function() return not cntShown() end,
                get = function() return (t.text and t.text.countPoint) or "BOTTOMRIGHT" end,
                set = function(_, v) txt().countPoint = v; T.Update() end,
            }
            args.saCountX = {
                order = 57, type = "range", name = "X Offset", min = -40, max = 40, step = 1,
                hidden = function() return not cntShown() end,
                get = function() return (t.text and t.text.countXOffset) or -1 end,
                set = function(_, v) txt().countXOffset = v; T.Update() end,
            }
            args.saCountY = {
                order = 58, type = "range", name = "Y Offset", min = -40, max = 40, step = 1,
                hidden = function() return not cntShown() end,
                get = function() return (t.text and t.text.countYOffset) or 1 end,
                set = function(_, v) txt().countYOffset = v; T.Update() end,
            }
        end
    end
    return {
        order = order, type = "group",  -- NOT inline -> rendered as a tab
        name = function() return TimerLabel(t) end,
        args = args,
    }
end

function TUI:TimersOptions()
    local T = ns.Timers
    local Rebuild  -- fwd

    local opts = {
        order = 9,
        type = "group",
        name = "Timers",
        childGroups = "tab",
        args = {
            intro = {
                order = 1, type = "description", name = " ",
            },
            add = {
                order = 2, type = "group", inline = true, name = "Add Timer",
                args = {
                    addPotion = {
                        order = 1, type = "select", name = "Common Potion", width = 1.5,
                        values = PotionValues, sorting = PotionSorting,
                        get = function() end,
                        set = function(_, v) T.AddTimer("item", v); Rebuild(); NotifyChange() end,
                    },
                    addItem = {
                        order = 2, type = "input", name = "Add Item (ID)", width = 1.0,
                        get = function() return "" end,
                        set = function(_, v) local id = tonumber(v); if id then T.AddTimer("item", id); Rebuild(); NotifyChange() end end,
                    },
                },
            },
        },
    }

    Rebuild = function()
        for k in pairs(opts.args) do
            if type(k) == "string" and k:match("^tmr") then opts.args[k] = nil end
        end
        for i, t in ipairs(T and T.GetTimers() or {}) do
            local order = (t.kind == "lust") and 1 or (10 + i)  -- Hero/Lust is always tab #1
            opts.args["tmr" .. t.id] = TimerTab(t, t.id, order, Rebuild)
        end
    end

    Rebuild()
    -- Let M.Update() (e.g. the Custom Groups item "Timer" toggle) refresh the tabs.
    if T then T._rebuildOptions = Rebuild end
    return opts
end
