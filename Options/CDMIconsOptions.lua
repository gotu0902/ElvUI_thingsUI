local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local P   = select(4, unpack(ElvUI))

local function AnchorArgs(key, opts)
    opts = opts or {}

    local function db()  return E.db.thingsUI.cdmIcons[key] end

    local function dis()
        if opts.alwaysOn then return false end
        return not db().anchorEnabled
    end

    return {
        anchorHeader = { order = 20, type = "header", name = "Anchor" },
        anchorEnabled = {
            order = 21, type = "toggle", width = "full",
            name = "Enable Custom Anchor",
            hidden = function() return opts.alwaysOn end,
            get = function() return db().anchorEnabled end,
            set = function(_, v)
                db().anchorEnabled = v
                TUI:UpdateCDMIcons()
            end,
        },
        anchorFrame = {
            order = 22, type = "select", name = "Anchor To",
            values  = ns.ANCHORS.FilteredValues,
            sorting = ns.ANCHORS.FilteredOrder,
            disabled = dis,
            get = function() return db().anchorFrame end,
            set = function(_, v)
                if v ~= db().anchorFrame then ns.ANCHORS.ResetPlacement(db()) end
                db().anchorFrame = v
                TUI:UpdateCDMIcons()
            end,
        },
        anchorPoint = {
            order = 23, type = "select", name = "Anchor From (self)",
            values = ns.POINTS.VALUES,
            sorting = ns.POINTS.ORDER,
            disabled = dis,
            get = function() return db().anchorPoint end,
            set = function(_, v)
                db().anchorPoint = v
                TUI:UpdateCDMIcons()
            end,
        },
        anchorRelativePoint = {
            order = 24, type = "select", name = "Anchor To (target)",
            values = ns.POINTS.VALUES,
            sorting = ns.POINTS.ORDER,
            disabled = dis,
            get = function() return db().anchorRelativePoint end,
            set = function(_, v)
                db().anchorRelativePoint = v
                TUI:UpdateCDMIcons()
            end,
        },
        anchorXOffset = {
            order = 25, type = "range", name = "X Offset",
            min = -300, max = 300, step = 0.01, bigStep = 1,
            disabled = dis,
            get = function() return db().anchorXOffset end,
            set = function(_, v)
                db().anchorXOffset = v
                TUI:UpdateCDMIcons()
            end,
        },
        anchorYOffset = {
            order = 26, type = "range", name = "Y Offset",
            min = -300, max = 300, step = 0.01, bigStep = 1,
            disabled = dis,
            get = function() return db().anchorYOffset end,
            set = function(_, v)
                db().anchorYOffset = v
                TUI:UpdateCDMIcons()
            end,
        },
        resetAnchor = {
            order = 27, type = "execute", name = "Reset Anchor",
            disabled = dis,
            func = function()
                local d = P and P.thingsUI and P.thingsUI.cdmIcons and P.thingsUI.cdmIcons[key]
                local v = db()
                if d then
                    v.anchorFrame         = d.anchorFrame
                    v.anchorPoint         = d.anchorPoint
                    v.anchorRelativePoint = d.anchorRelativePoint
                    v.anchorXOffset       = d.anchorXOffset
                    v.anchorYOffset       = d.anchorYOffset
                end
                TUI:UpdateCDMIcons()
                ns.NotifyChange()
            end,
        },
    }
end

local function TextArgs(key)
    local function tdb() return E.db.thingsUI.cdmIcons[key].text end
    local function refresh()
        TUI:UpdateCDMText()
        if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
    end

    local function FieldGroup(order, prefix, name, includePlacement)
        local function get(field) return tdb()[prefix .. field] end
        local function set(field, v) tdb()[prefix .. field] = v; refresh() end
        local showKey = "show" .. (prefix:sub(1, 1):upper() .. prefix:sub(2))
        local disabled = function() return not tdb()[showKey] end

        local args = {
            show = {
                order = 1, type = "toggle", name = "Show " .. name,
                get = function() return tdb()[showKey] end,
                set = function(_, v) tdb()[showKey] = v; refresh() end,
            },
            font = {
                order = 2, type = "select", dialogControl = "LSM30_Font",
                name = "Font", values = ns.FontValues,
                get = function() return get("Font") end,
                set = function(_, v) set("Font", v) end,
                disabled = disabled,
            },
            fontSize = {
                order = 3, type = "range", name = "Size",
                min = 6, max = 72, step = 1,
                get = function() return get("FontSize") end,
                set = function(_, v) set("FontSize", v) end,
                disabled = disabled,
            },
            outline = {
                order = 4, type = "select", name = "Outline",
                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                get = function() return get("FontOutline") end,
                set = function(_, v) set("FontOutline", v) end,
                disabled = disabled,
            },
            color = {
                order = 5, type = "color", name = "Color",
                get = function()
                    local c = get("Color") or { r = 1, g = 1, b = 1 }
                    return c.r or 1, c.g or 1, c.b or 1
                end,
                set = function(_, r, g, b) set("Color", { r = r, g = g, b = b }) end,
                disabled = disabled,
            },
        }

        if includePlacement then
            args.point = {
                order = 10, type = "select", name = "Anchor Point",
                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                get = function() return get("Point") end,
                set = function(_, v) set("Point", v) end,
                disabled = disabled,
            }
            args.xOffset = {
                order = 11, type = "range", name = "X Offset",
                min = -50, max = 50, step = 0.5, bigStep = 1,
                get = function() return get("XOffset") or 0 end,
                set = function(_, v) set("XOffset", v) end,
                disabled = disabled,
            }
            args.yOffset = {
                order = 12, type = "range", name = "Y Offset",
                min = -50, max = 50, step = 0.5, bigStep = 1,
                get = function() return get("YOffset") or 0 end,
                set = function(_, v) set("YOffset", v) end,
                disabled = disabled,
            }
        end

        return { order = order, type = "group", inline = true, name = name, args = args }
    end

    return {
        stacksGroup   = FieldGroup(10, "stacks",   "Stacks",   true),
        countGroup    = FieldGroup(20, "count",    "Charges",  true),
        cooldownGroup = FieldGroup(30, "cooldown", "Cooldown Text", true),
    }
end

-- the Aura Icons picker, placing the icon in this row
local function AddAuraIconArg(row)
    local function spec() return ns.SpecialBars and ns.SpecialBars.GetCurrentSpecID and ns.SpecialBars.GetCurrentSpecID() end
    return {
        order = 0.5, type = "select", name = "|cFFFF80C0Add Aura Icon|r", width = "double",
        hidden = function() return not (ns.SB_GroupPickValues and spec()) end,
        values = function() return ns.SB_GroupPickValues(false, spec()) end,
        sorting = function() return ns.SB_GroupPickSorting(false, spec()) end,
        get = function() return "" end,
        set = function(_, v)
            local id = tonumber(v)
            if id and ns.SB_PlaceSpell(false, id, spec(), nil, row) then
                TUI:UpdateSpecialBars()
                ns.NotifyChange()
            end
        end,
    }
end

local function ViewerGroup(order, key, label, opts)
    opts = opts or {}
    local minIconSize = opts.minIconSize or 12
    local maxIconSize = opts.maxIconSize or 100

    local layoutArgs = {
            sizeHeader = { order = 1, type = "header", name = "Icon Size" },
            lockAspect = {
                order = 2, type = "toggle", name = "Square Icons",
                get = function() return E.db.thingsUI.cdmIcons[key].lockAspect end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].lockAspect = v
                    TUI:UpdateCDMIcons()
                end,
            },
            iconWidth = {
                order = 3, type = "range",
                name = function()
                    return E.db.thingsUI.cdmIcons[key].lockAspect and "Icon Size" or "Icon Width"
                end,
                min = minIconSize, max = maxIconSize, step = 0.01, bigStep = 1,
                get = function() return E.db.thingsUI.cdmIcons[key].iconWidth end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconWidth = v
                    TUI:UpdateCDMIcons()
                end,
            },
            iconHeight = {
                order = 4, type = "range", name = "Icon Height",
                min = minIconSize, max = maxIconSize, step = 0.01, bigStep = 1,
                hidden = function() return E.db.thingsUI.cdmIcons[key].lockAspect end,
                get = function() return E.db.thingsUI.cdmIcons[key].iconHeight end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconHeight = v
                    TUI:UpdateCDMIcons()
                end,
            },
            iconZoom = {
                order = 5, type = "range", name = "Icon Zoom",
                min = 0, max = 0.30, step = 0.01, isPercent = true,
                get = function() return E.db.thingsUI.cdmIcons[key].iconZoom or 0 end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconZoom = v
                    TUI:UpdateCDMIcons()
                end,
            },
            iconLockAspectRatio = {
                order = 6, type = "toggle", name = "Lock Icon Aspect Ratio",
                get = function() return E.db.thingsUI.cdmIcons[key].iconLockAspectRatio ~= false end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconLockAspectRatio = v
                    TUI:UpdateCDMIcons()
                end,
            },

            layoutHeader = { order = 10, type = "header", name = "Layout" },
            spacing = {
                order = 11, type = "range", name = "Spacing",
                min = -10, max = 10, step = 0.01, bigStep = 1,
                get = function() return E.db.thingsUI.cdmIcons[key].spacing end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].spacing = v
                    TUI:UpdateCDMIcons()
                end,
            },
            growthDirection = {
                order = 12, type = "select", name = "Growth Direction",
                values = ns.GROWTH.VALUES, sorting = ns.GROWTH.ORDER,
                get = function() return E.db.thingsUI.cdmIcons[key].growthDirection end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].growthDirection = v
                    TUI:UpdateCDMIcons()
                end,
            },
            iconsPerRow = {
                order = 13, type = "range", name = "Icons per Row",
                min = 1, max = 30, step = 1,
                disabled = function()
                    local v = E.db.thingsUI.cdmIcons[key]
                    if v.elbowEnabled then return true end
                    return (v.maxIcons or 0) > 0 and (v.overflowTarget or "") ~= ""
                end,
                get = function() return E.db.thingsUI.cdmIcons[key].iconsPerRow end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconsPerRow = v
                    TUI:UpdateCDMIcons()
                end,
            },
            invertSwipe = {
                order = 13.42, type = "toggle", name = "Invert Swipe",
                hidden = function() return key ~= "buffIcon" end,
                get = function() return E.db.thingsUI.cdmIcons[key].invertSwipe end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].invertSwipe = v
                    TUI:UpdateCDMIcons()
                end,
            },
            elbowHeader = {
                order = 13.51, type = "header", name = "Elbow",
            },
            elbowEnabled = {
                order = 13.52, type = "toggle", name = "Turn After X Icons", width = "full",
                desc = "The run turns a corner instead of starting a new full row, so the bar reads as an L.",
                get = function() return E.db.thingsUI.cdmIcons[key].elbowEnabled end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].elbowEnabled = v
                    TUI:UpdateCDMIcons()
                end,
            },
            elbowAfter = {
                order = 13.53, type = "range", name = "Turn After",
                min = 1, max = 30, step = 1,
                disabled = function() return not E.db.thingsUI.cdmIcons[key].elbowEnabled end,
                get = function() return E.db.thingsUI.cdmIcons[key].elbowAfter or 10 end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].elbowAfter = v
                    TUI:UpdateCDMIcons()
                end,
            },
            elbowDirection = {
                order = 13.54, type = "select", name = "Turn Towards",
                values = function()
                    local g = E.db.thingsUI.cdmIcons[key].growthDirection or "CENTERED_H"
                    if g == "DOWN" or g == "UP" or g == "CENTERED_V" then
                        return { RIGHT = "Right", LEFT = "Left" }
                    end
                    return { DOWN = "Down", UP = "Up" }
                end,
                sorting = function()
                    local g = E.db.thingsUI.cdmIcons[key].growthDirection or "CENTERED_H"
                    if g == "DOWN" or g == "UP" or g == "CENTERED_V" then
                        return { "LEFT", "RIGHT" }
                    end
                    return { "UP", "DOWN" }
                end,
                disabled = function() return not E.db.thingsUI.cdmIcons[key].elbowEnabled end,
                get = function()
                    local db = E.db.thingsUI.cdmIcons[key]
                    local g = db.growthDirection or "CENTERED_H"
                    local vertical = (g == "DOWN" or g == "UP" or g == "CENTERED_V")
                    local cur = db.elbowDirection
                    local ok = vertical and (cur == "LEFT" or cur == "RIGHT")
                        or (not vertical and (cur == "UP" or cur == "DOWN"))
                    return ok and cur or (vertical and "LEFT" or "DOWN")
                end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].elbowDirection = v
                    TUI:UpdateCDMIcons()
                end,
            },
            overflowHeader = {
                order = 13.6, type = "header", name = "Overflow",
                hidden = function() return key == "buffIcon" end,
            },
            maxIcons = {
                order = 13.7, type = "range", name = "Max Icons (0 = Off)",
                desc = "Icons past this count move to the bar below.",
                min = 0, max = 30, step = 1,
                hidden = function() return key == "buffIcon" end,
                get = function() return E.db.thingsUI.cdmIcons[key].maxIcons or 0 end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].maxIcons = v
                    TUI:UpdateCDMIcons()
                end,
            },
            overflowTarget = {
                order = 13.8, type = "select", name = "Overflow To",
                values = function()
                    local out = { [""] = "None" }
                    local names = { essential = "Essential", utility = "Utility", buffIcon = "Buff Icons" }
                    for k, label in pairs(names) do
                        local o = E.db.thingsUI.cdmIcons[k]
                        if k ~= key and not (o and (o.maxIcons or 0) > 0 and (o.overflowTarget or "") ~= "") then
                            out[k] = label
                        end
                    end
                    return out
                end,
                hidden = function() return key == "buffIcon" end,
                disabled = function() return (E.db.thingsUI.cdmIcons[key].maxIcons or 0) <= 0 end,
                get = function() return E.db.thingsUI.cdmIcons[key].overflowTarget or "" end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].overflowTarget = v
                    TUI:UpdateCDMIcons()
                end,
            },
            overflowPlacement = {
                order = 13.9, type = "select", name = "Overflow Position",
                desc = "Where the moved icons land in the receiving bar.",
                values = function()
                    local t = E.db.thingsUI.cdmIcons[key].overflowTarget
                    local tdb = t and t ~= "" and E.db.thingsUI.cdmIcons[t]
                    local g = tdb and tdb.growthDirection or "CENTERED_H"
                    if g == "DOWN" or g == "UP" or g == "CENTERED_V" then
                        return { START = "Top", END = "Bottom" }
                    end
                    return { START = "Left", END = "Right" }
                end,
                sorting = { "START", "END" },
                hidden = function() return key == "buffIcon" end,
                disabled = function()
                    local v = E.db.thingsUI.cdmIcons[key]
                    return (v.maxIcons or 0) <= 0 or (v.overflowTarget or "") == ""
                end,
                get = function() return E.db.thingsUI.cdmIcons[key].overflowPlacement or "END" end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].overflowPlacement = v
                    TUI:UpdateCDMIcons()
                end,
            },
            wrapDirection = {
                order = 13.5, type = "select", name = "Wrap Direction",
                values = function()
                    local g = E.db.thingsUI.cdmIcons[key].growthDirection or "CENTERED_H"
                    if g == "DOWN" or g == "UP" or g == "CENTERED_V" then
                        return { RIGHT = "Right", LEFT = "Left" }
                    end
                    return { DOWN = "Down", UP = "Up" }
                end,
                get = function()
                    local db = E.db.thingsUI.cdmIcons[key]
                    local g = db.growthDirection or "CENTERED_H"
                    local vertical = (g == "DOWN" or g == "UP" or g == "CENTERED_V")
                    return db.wrapDirection or (vertical and "RIGHT" or "DOWN")
                end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].wrapDirection = v
                    TUI:UpdateCDMIcons()
                end,
            },
    }

    if key ~= "buffIcon" then
        layoutArgs.hidePassive = {
            order = 14, type = "toggle", name = "Hide Passive Cooldowns", width = 1.4,
            desc = "Hide cooldowns that a talent has turned into a passive (e.g. a talent that replaces an active ability).",
            get = function() return E.db.thingsUI.cdmIcons[key].hidePassive end,
            set = function(_, v)
                E.db.thingsUI.cdmIcons[key].hidePassive = v
                TUI:UpdateCDMIcons()
            end,
        }
    end

    if opts.includeAnchor then
        local anchorOpts = { alwaysOn = opts.alwaysOnAnchor }
        for k, v in pairs(AnchorArgs(key, anchorOpts)) do
            layoutArgs[k] = v
        end
    end

    return {
        order = order,
        type  = "group",
        name  = label,
        childGroups = "tab",
        args  = {
            addAuraIcon = (key == "essential" or key == "utility") and AddAuraIconArg(key) or nil,
            layoutTab = {
                order = 1, type = "group", name = "Size & Position",
                args  = layoutArgs,
            },
            textTab = {
                order = 2, type = "group", name = "Text",
                args  = TextArgs(key),
            },
        },
    }
end

local GLOW_STYLES = { pixel = "Pixel Glow", autocast = "Autocast Shine", proc = "Proc Glow", button = "Action Button Glow" }
local GLOW_STYLE_ORDER = { "pixel", "autocast", "proc", "button" }

-- the glow look, shared by Layout > Glow and a Spell Editor spell's own style
local function GlowStyleArgs(base, get, set, disabled, hidden)
    local function style() return get("style") or "pixel" end
    local function only(hide)
        return function() return (hidden and hidden()) or hide(style()) end
    end
    local function range(order, key, name, min, max, step, def, hide)
        return {
            order = base + order, type = "range", name = name, min = min, max = max, step = step,
            hidden = only(hide), disabled = disabled,
            get = function() return get(key) or def end,
            set = function(_, v) set(key, v) end,
        }
    end
    return {
        style = {
            order = base + 2, type = "select", name = "Style", values = GLOW_STYLES, sorting = GLOW_STYLE_ORDER,
            hidden = hidden, disabled = disabled,
            get = function() return style() end,
            set = function(_, v) set("style", v) end,
        },
        lines = range(5, "lines", "Lines", 4, 16, 1, 8, function(s) return s ~= "pixel" end),
        thickness = range(6, "thickness", "Thickness", 1, 4, 1, 2, function(s) return s ~= "pixel" end),
        particles = range(7, "particles", "Particles", 1, 8, 1, 4, function(s) return s ~= "autocast" end),
        scale = range(8, "scale", "Scale", 0.5, 2, 0.05, 1, function(s) return s ~= "autocast" end),
        frequency = range(9, "frequency", "Speed", 0.05, 0.5, 0.01, 0.25, function(s) return s == "proc" end),
        offset = range(10, "offset", "Offset", -8, 8, 1, 0, function(s) return s == "button" end),
    }
end

local function GlowTab(order)
    local function gdb()
        local db = E.db.thingsUI.cdmIcons
        db.glow = db.glow or {}
        return db.glow
    end
    local function Update()
        if TUI.UpdateCDMGlow then TUI:UpdateCDMGlow() end
    end
    local args = {
        desc = {
            order = 0, type = "description",
            name = "Replace Blizzard's proc glow on Essential and Utility icons with a thingsUI style. Spell Editor glows use it too, unless a spell has its own style.\n",
        },
        enabled = {
            order = 1, type = "toggle", name = "Custom Glow",
            get = function() return gdb().enabled end,
            set = function(_, v) gdb().enabled = v; Update() end,
        },
        useColor = {
            order = 3, type = "toggle", name = "Custom Color",
            disabled = function() return not gdb().enabled end,
            get = function() return gdb().useColor end,
            set = function(_, v) gdb().useColor = v; Update() end,
        },
        customColor = {
            order = 4, type = "color", name = "Color",
            disabled = function() return not (gdb().enabled and gdb().useColor) end,
            get = function()
                local c = gdb().customColor or { r = 1, g = 0.85, b = 0.1 }
                return c.r, c.g, c.b
            end,
            set = function(_, r, g, b) gdb().customColor = { r = r, g = g, b = b }; Update() end,
        },
    }
    local look = GlowStyleArgs(0, function(k) return gdb()[k] end,
        function(k, v) gdb()[k] = v; Update() end,
        function() return not gdb().enabled end)
    for k, v in pairs(look) do args[k] = v end
    return { order = order, type = "group", name = "Glow", args = args }
end

local PANDEMIC_MODES = { blizzard = "Blizzard", hide = "Hidden", custom = "Custom Glow" }

-- Blizzard's aura display on cooldown icons: the overlay, its swipe and the pandemic glow
local function AuraOverlayTab(order)
    local function cdm() return E.db.thingsUI.cdmIcons end
    local function Update() TUI:UpdateCDMIcons() end
    local function Pandemic()
        if ns.CDMIcons and ns.CDMIcons.ClearPandemicAll then ns.CDMIcons.ClearPandemicAll() end
    end
    local function mode() local c = cdm() return c.pandemicMode or (c.hidePandemic and "hide") or "blizzard" end
    local function notCustom() return mode() ~= "custom" end
    local function fx()
        local c = cdm()
        c.pandemicFX = c.pandemicFX or {}
        return c.pandemicFX
    end
    local args = {
        desc = {
            order = 0, type = "description",
            name = "Blizzard's aura display on Essential and Utility icons: the overlay while a spell's aura runs, its swipe, and the pandemic glow.\n",
        },
        hideAuraOverlay = {
            order = 1, type = "toggle", width = "full",
            name = "Hide Aura Overlay on all spells (Spell Editor can change it per spell)",
            get = function() return cdm().hideAuraOverlay end,
            set = function(_, v) cdm().hideAuraOverlay = v; Update() end,
        },
        swipeHeader = { order = 10, type = "header", name = "Aura Swipe" },
        swipeColorOn = {
            order = 11, type = "toggle", name = "Own Swipe Color",
            get = function() return cdm().auraSwipeColor ~= nil end,
            set = function(_, v) cdm().auraSwipeColor = v and { r = 1, g = 0.82, b = 0, a = 0.6 } or nil; Update() end,
        },
        swipeColor = {
            order = 12, type = "color", name = "Color", hasAlpha = true,
            hidden = function() return cdm().auraSwipeColor == nil end,
            get = function()
                local c = cdm().auraSwipeColor
                return c.r, c.g, c.b, c.a or 0.6
            end,
            set = function(_, r, g, b, a) cdm().auraSwipeColor = { r = r, g = g, b = b, a = a }; Update() end,
        },
        swipeReverse = {
            order = 13, type = "toggle", name = "Reverse Swipe",
            get = function() return cdm().auraSwipeReverse end,
            set = function(_, v) cdm().auraSwipeReverse = v or nil; Update() end,
        },
        pandemicHeader = { order = 20, type = "header", name = "Pandemic Glow" },
        pandemicMode = {
            order = 21, type = "select", name = "Pandemic Glow",
            values = PANDEMIC_MODES, sorting = { "blizzard", "hide", "custom" },
            get = mode,
            set = function(_, v)
                local c = cdm()
                c.pandemicMode = (v ~= "blizzard") and v or nil
                c.hidePandemic = nil
                Pandemic()
            end,
        },
        pandemicColorOn = {
            order = 22, type = "toggle", name = "Own Color", hidden = notCustom,
            get = function() return cdm().pandemicColor ~= nil end,
            set = function(_, v) cdm().pandemicColor = v and { r = 1, g = 0.3, b = 0.3 } or nil; Pandemic() end,
        },
        pandemicColor = {
            order = 23, type = "color", name = "Color",
            hidden = function() return notCustom() or cdm().pandemicColor == nil end,
            get = function()
                local c = cdm().pandemicColor
                return c.r, c.g, c.b
            end,
            set = function(_, r, g, b) cdm().pandemicColor = { r = r, g = g, b = b }; Pandemic() end,
        },
        pandemicBrk = { order = 24, type = "description", name = "", width = "full", hidden = notCustom },
    }
    local look = GlowStyleArgs(30, function(k) return fx()[k] end,
        function(k, v) fx()[k] = v; Pandemic() end, nil, notCustom)
    for k, v in pairs(look) do args["pandemic_" .. k] = v end
    return { order = order, type = "group", name = "Aura Overlay", args = args }
end

-- Racials -> CDM
local RACIAL_DEST_TAG = {
    essential = "|cFFFFD27F(Essential)|r",
    utility   = "|cFFFFD27F(Utility)|r",
    dynamic   = "|cFF8AC8FF(Dynamic)|r",
}
local function RacialsToCDMTab(order)
    local function rdb() return E.db.thingsUI.racialsCDM end
    local function dest() local db = rdb(); db.dest = db.dest or {}; return db.dest end
    local CG = ns.CustomGroups

    local function Update()
        if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end
        if ns.NotifyChange then ns.NotifyChange() end
    end

    local function RacialGroupName(id)
        return ns.RacialsCDM and ns.RacialsCDM.FindRacialGroup and ns.RacialsCDM.FindRacialGroup(id)
    end

    local function SortedRacials()
        local list = {}
        for _, id in ipairs(ns.Racials or {}) do
            local owned = (not (CG and CG.PlayerHasRacial)) or CG.PlayerHasRacial(id)
            list[#list + 1] = { id = id, owned = owned,
                nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) }
        end
        table.sort(list, function(a, b)
            if a.owned ~= b.owned then return a.owned end
            return a.nm < b.nm
        end)
        return list
    end

    local function RacialLabel(id, owned, tabKey)
        local nm  = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id)
        local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 0
        local label
        if owned then
            label = ("|T%d:14:14|t %s"):format(tex, nm)
        else
            label = ("|T%d:14:14|t |cFF777777%s (other race)|r"):format(tex, nm)
        end
        local d = dest()[id]
        if d and d ~= tabKey then label = label .. "  " .. (RACIAL_DEST_TAG[d] or "") end
        local gname = RacialGroupName(id)
        if gname then label = label .. ("  |cFFF20553(CG: %s)|r"):format(gname) end
        return label
    end

    local function DestTab(tabOrder, key, label)
        local args = {
            addUnassigned = {
                order = 1, type = "execute", name = "|cFF59D759Add All Unassigned|r", width = 1.2,
                func = function()
                    for _, id in ipairs(ns.Racials or {}) do
                        if not dest()[id] then dest()[id] = key end
                    end
                    Update()
                end,
            },
            addAll = {
                order = 2, type = "execute", name = "Add ALL Racials", width = 1.2,
                confirm = function()
                    return ("Move every racial (including ones assigned elsewhere) to %s?"):format(label)
                end,
                func = function()
                    for _, id in ipairs(ns.Racials or {}) do dest()[id] = key end
                    Update()
                end,
            },
            hint = {
                order = 3, type = "description", fontSize = "medium", width = "full",
                name = "|cFF888888Tick to add here - ticking a racial assigned elsewhere moves it here. Untick to remove.\nAssigned racials replace the Cooldown Manager's own copy (it gets hidden).|r\n",
            },
        }
        for i, e in ipairs(SortedRacials()) do
            local id, owned = e.id, e.owned
            args["r" .. id] = {
                order = 10 + i, type = "toggle", width = 1.7,
                name = function() return RacialLabel(id, owned, key) end,
                get = function() return dest()[id] == key end,
                set = function(_, v)
                    if v then
                        dest()[id] = key
                    elseif dest()[id] == key then
                        dest()[id] = nil
                    end
                    Update()
                end,
            }
        end
        return {
            order = tabOrder, type = "group",
            name = function()
                local n = 0
                for _, v in pairs(dest()) do if v == key then n = n + 1 end end
                return n > 0 and ("%s (%d)"):format(label, n) or label
            end,
            args = args,
        }
    end

    local function cgOnly() return rdb() and rdb().customGroupsOnly end

    local essentialTab = DestTab(10, "essential", "Essential")
    local utilityTab   = DestTab(11, "utility", "Utility")
    local dynamicTab   = DestTab(12, "dynamic", "Dynamic")
    essentialTab.disabled = cgOnly
    utilityTab.disabled   = cgOnly
    dynamicTab.disabled   = cgOnly

    return {
        order = order, type = "group", name = "Racials", childGroups = "tab",
        args = {
            customGroupsOnly = {
                order = 0.5, type = "toggle", name = "Custom Groups Only", width = 1.4,
                desc = "Kick racials out of the CDM viewers entirely (native entries are parked under Not Displayed). For ppl that don't want racials in their essential or utility.",
                get = cgOnly,
                set = function(_, v)
                    rdb().customGroupsOnly = v
                    if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end
                    if ns.NotifyChange then ns.NotifyChange() end
                end,
            },
            threshold = {
                order = 1, type = "range", name = "Dynamic Threshold", min = 1, max = 20, step = 1,
                hidden = function()
                    if cgOnly() then return true end
                    local d = rdb() and rdb().dest
                    if d then for _, v in pairs(d) do if v == "dynamic" then return false end end end
                    return true
                end,
                get = function() return (rdb() and rdb().dynamicThreshold) or 8 end,
                set = function(_, v) rdb().dynamicThreshold = v; if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end end,
            },
            essentialTab = essentialTab,
            utilityTab   = utilityTab,
            dynamicTab   = dynamicTab,
        },
    }
end

-- one cooldown's own glow and text, on top of the viewer's settings
-- one Spell Editor page: Essential/Utility cooldowns, or Buff Icons (stored apart,
-- so a spell that is both a cooldown and a buff can look different in each)
local function SpellEditorPage(order, buffs)
    local sel
    local storeKey = buffs and "perBuff" or "perSpell"
    local function store()
        local db = E.db.thingsUI.cdmIcons
        db[storeKey] = db[storeKey] or {}
        return db[storeKey]
    end
    local function isSpell() return type(sel) == "number" end
    local function entry(create)
        if not isSpell() then return nil end
        local ps = store()
        if create and not ps[sel] then ps[sel] = {} end
        return ps[sel]
    end
    local function apply()
        local ps = store()
        local e = sel and ps[sel]
        -- rules switched off with nothing set are no setting
        if e and e.visibility then
            local keep = false
            for k, v in pairs(e.visibility) do
                if not (k == "enabled" and not v) then keep = true break end
            end
            if not keep then e.visibility = nil end
        end
        if sel and ps[sel] and not next(ps[sel]) then ps[sel] = nil end
        if ns.CDMIcons and ns.CDMIcons.RefreshSpellRules then ns.CDMIcons.RefreshSpellRules() end
        if TUI.UpdateCDMGlow then TUI:UpdateCDMGlow() end
        if ns.CDMText and ns.CDMText.RefreshAll then ns.CDMText.RefreshAll() end
        if ns.CDMIcons and ns.CDMIcons.RefreshCustomIcons then ns.CDMIcons.RefreshCustomIcons() end
        if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() end
        ns.NotifyChange()
    end
    local function setField(k, v)
        entry(true)[k] = v
        apply()
    end
    local function spellName(id)
        return (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id)
    end
    local function spellLabel(id)
        local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        return (icon and ("|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. spellName(id)
    end
    local function specSpells()
        if buffs then
            -- this spec's tracked buffs, keyed by base spell like the lookup
            local out = {}
            local function add(info)
                local sid = info and info.spellID
                if sid and not (issecretvalue and issecretvalue(sid)) then out[sid] = true end
            end
            local cat = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff
            local ids = cat and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet(cat, false)
            for _, cdID in ipairs(ids or {}) do add(C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)) end
            -- that set is Blizzard's default; a buff dragged in from another category lives in the viewer
            local v = _G.BuffIconCooldownViewer
            if v then
                for _, c in ipairs({ v:GetChildren() }) do add(c.cooldownInfo) end
            end
            return out
        end
        local spec = GetSpecialization and GetSpecialization()
        local specID = spec and GetSpecializationInfo(spec)
        return (ns.CDMSpells and ns.CDMSpells.GetForSpec and ns.CDMSpells.GetForSpec(specID)) or {}
    end
    local function byName(a, b) return spellName(a) < spellName(b) end
    -- spells set up on another class or spec stay out of the list (Spell ID still reaches them)
    local function listed(id, spec)
        return spec[id] ~= nil or id == sel or (IsPlayerSpell and IsPlayerSpell(id)) or false
    end
    -- Aura Icons in a row (cooldowns), or every Aura Icon/Bar drawing a tracked buff (buffs,
    -- Blizzard's copy hidden): they keep their look in their own settings.
    -- covered = the buff spells they take over
    local function rowIcons()
        local out, covered, SB = {}, {}, ns.SpecialBars
        if not SB then return out, covered end
        if buffs then
            local cdm = E.db.thingsUI.cdmIcons
            if cdm and cdm.hideGroupedDuplicates == false then return out, covered end
            local tracked, SA = specSpells(), ns.SpecialAura
            local function add(prefix, key, d)
                if not (d and d.enabled and d.spellID) then return end
                local ids = (SA and SA.ExpandSpellIDs and SA.ExpandSpellIDs(d.spellID)) or { [d.spellID] = true }
                local hit = false
                for id in pairs(ids) do
                    if tracked[id] then covered[id] = true; hit = true end
                end
                if hit then out[prefix .. key] = d end
            end
            for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do add("si:", "icon" .. i, SB.GetIconDB("icon" .. i)) end
            for i = 1, (SB.GetBarCount and SB.GetBarCount() or 0) do add("sb:", "bar" .. i, SB.GetBarDB("bar" .. i)) end
            return out, covered
        end
        for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
            local key = "icon" .. i
            local idb = SB.GetIconDB(key)
            if idb and idb.enabled and idb.cdmRow and idb.spellID then out["si:" .. key] = idb end
        end
        return out, covered
    end
    -- spells an Aura Icon sits on top of
    local function overSpells()
        local out, SB = {}, ns.SpecialBars
        if buffs or not SB then return out end
        for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
            local d = SB.GetIconDB("icon" .. i)
            if d and d.enabled and d.spellID and d.overSpell and not d.cdmRow then out[d.overSpell] = true end
        end
        return out
    end
    local ON_TOP = " |cFFFFD27F(Aura On Top)|r"
    local function iconKey() return type(sel) == "string" and sel:match("^si:(.+)$") or nil end
    local function barKey() return type(sel) == "string" and sel:match("^sb:(.+)$") or nil end
    local function own(k, def)
        return {
            order = 3, type = "toggle", name = "Own Color",
            get = function() local e = entry() return (e and e[k]) ~= nil end,
            set = function(_, v) setField(k, v and ns.DeepCopy(def) or nil) end,
        }, {
            order = 4, type = "color", name = "Color",
            hidden = function() local e = entry() return not (e and e[k]) end,
            get = function()
                local c = (entry() or {})[k] or def
                return c.r, c.g, c.b
            end,
            set = function(_, r, g, b) setField(k, { r = r, g = g, b = b }) end,
        }
    end
    local WHITE = { r = 1, g = 1, b = 1 }
    local cdColorOn, cdColor = own("cooldownColor", WHITE)
    local countColorOn, countColor = own("countColor", WHITE)
    -- own anchor point and offsets; without a point, 0 keeps the viewer's offset
    local function place(prefix, hideKey)
        local pk, xk, yk = prefix .. "Point", prefix .. "XOffset", prefix .. "YOffset"
        local function hidden() local e = entry() return (e and e[hideKey]) and true or false end
        local values = { [""] = "Viewer's" }
        for k, v in pairs(ns.POINTS.VALUES) do values[k] = v end
        local sorting = { "" }
        for _, k in ipairs(ns.POINTS.ORDER) do sorting[#sorting + 1] = k end
        return { order = 5, type = "description", name = "", width = "full" }, {
            order = 6, type = "select", name = "Position", values = values, sorting = sorting,
            hidden = hidden,
            get = function() local e = entry() return (e and e[pk]) or "" end,
            set = function(_, v)
                entry(true)[pk] = (v ~= "") and v or nil
                apply()
            end,
        }, {
            order = 7, type = "range", name = "X Offset", min = -50, max = 50, step = 1,
            hidden = hidden,
            get = function() local e = entry() return (e and e[xk]) or 0 end,
            set = function(_, v) setField(xk, (v ~= 0) and v or nil) end,
        }, {
            order = 8, type = "range", name = "Y Offset", min = -50, max = 50, step = 1,
            hidden = hidden,
            get = function() local e = entry() return (e and e[yk]) or 0 end,
            set = function(_, v) setField(yk, (v ~= 0) and v or nil) end,
        }
    end
    local cdBrk, cdPoint, cdX, cdY = place("cooldown", "hideCooldownText")
    -- swipe and pandemic changes need a layout pass and the pandemic frames redone
    local function lookField(k, v)
        setField(k, v)
        TUI:UpdateCDMIcons()
        if ns.CDMIcons and ns.CDMIcons.ClearPandemicAll then ns.CDMIcons.ClearPandemicAll() end
    end
    local function cdmDB() return E.db.thingsUI.cdmIcons end
    local function globalPandemic()
        local c = cdmDB()
        return c.pandemicMode or (c.hidePandemic and "hide") or "blizzard"
    end
    local function pandemicMode() local e = entry() return (e and e.pandemicMode) or globalPandemic() end
    local function notCustom() return pandemicMode() ~= "custom" end
    local function noOwnPandemicLook() local e = entry() return notCustom() or not (e and e.pandemicFX) end
    local pandemicLook = GlowStyleArgs(10,
        function(k) local e = entry() return e and e.pandemicFX and e.pandemicFX[k] end,
        function(k, v)
            local e = entry(true)
            e.pandemicFX = e.pandemicFX or {}
            e.pandemicFX[k] = v
            lookField("pandemicFX", e.pandemicFX)
        end,
        nil, noOwnPandemicLook)
    local PANDEMIC_NAMES = { blizzard = "Blizzard", hide = "Hidden", custom = "Custom Glow" }
    local function glowOff()
        local e = entry()
        if buffs then return (e and e.glow) ~= "always" end
        return (e and e.glow) == "never"
    end
    local function noOwnLook() local e = entry() return not (e and e.glowFX) end
    local look = GlowStyleArgs(10,
        function(k) local e = entry() return e and e.glowFX and e.glowFX[k] end,
        function(k, v)
            local e = entry(true)
            e.glowFX = e.glowFX or {}
            e.glowFX[k] = v
            apply()
        end,
        glowOff, noOwnLook)
    local countBrk, countPoint, countX, countY = place("count", "hideCount")

    return {
        order = order, type = "group", name = buffs and "Buff Icons" or "Cooldowns",
        args = {
            desc = {
                order = 0, type = "description",
                name = buffs and "Glow and text for one buff in Buff Icons. Buffs set up here are green, buffs an Aura Icon or Aura Bar already shows are pink. Glow needs Custom Glow on in CDM > Layout > Glow.\n"
                    or "Glow and text for one cooldown in Essential or Utility. Spells set up here are green, Aura Icons in a row are pink. Glow needs Custom Glow on in CDM > Layout > Glow.\n",
            },
            spell = {
                order = 1, type = "select", name = "Spell", width = "double",
                values = function()
                    local out = {}
                    local ri, covered = rowIcons()
                    local spec, over = specSpells(), overSpells()
                    for id in pairs(spec) do
                        if not covered[id] then out[id] = spellLabel(id) end
                    end
                    for id in pairs(store()) do
                        if listed(id, spec) then out[id] = "|cFF40FF40" .. spellLabel(id) .. "|r" end
                    end
                    if isSpell() and not out[sel] then out[sel] = spellLabel(sel) end
                    for id in pairs(over) do
                        if out[id] then out[id] = out[id] .. ON_TOP end
                    end
                    for k, d in pairs(ri) do
                        out[k] = "|cFFFF80C0" .. spellLabel(d.spellID)
                            .. (k:sub(1, 3) == "sb:" and " (Aura Bar)|r" or " (Aura Icon)|r")
                    end
                    return out
                end,
                sorting = function()
                    local set, icons, other = {}, {}, {}
                    local spec = specSpells()
                    for id in pairs(store()) do
                        if listed(id, spec) then set[#set + 1] = id end
                    end
                    local ri, covered = rowIcons()
                    for k in pairs(ri) do icons[#icons + 1] = k end
                    for id in pairs(spec) do
                        if not store()[id] and not covered[id] then other[#other + 1] = id end
                    end
                    if isSpell() and not store()[sel] and (spec[sel] == nil or covered[sel]) then other[#other + 1] = sel end
                    table.sort(set, byName)
                    table.sort(icons, function(a, b) return spellName(ri[a].spellID) < spellName(ri[b].spellID) end)
                    table.sort(other, byName)
                    for _, k in ipairs(icons) do set[#set + 1] = k end
                    for _, id in ipairs(other) do set[#set + 1] = id end
                    return set
                end,
                get = function() return sel end,
                set = function(_, v) sel = v end,
            },
            specialIcon = {
                order = 9, type = "execute", width = 1.5,
                name = function() return barKey() and "Open Aura Bar Settings" or "Open Aura Icon Settings" end,
                hidden = function() return not (iconKey() or barKey()) end,
                func = function()
                    if iconKey() and ns.SB_OpenIconEditor then ns.SB_OpenIconEditor(iconKey())
                    elseif barKey() and ns.SB_OpenBarEditor then ns.SB_OpenBarEditor(barKey()) end
                end,
            },
            spellID = {
                order = 2, type = "input", name = "Spell ID",
                get = function() return "" end,
                set = function(_, v)
                    local n = tonumber(v)
                    if n and C_Spell.GetSpellName and C_Spell.GetSpellName(n) then sel = n end
                end,
            },
            settings = {
                order = 10, type = "group", inline = true,
                name = function() return isSpell() and spellLabel(sel) or "" end,
                hidden = function() return not isSpell() end,
                args = {
                    overlayGrp = {
                        order = 0.6, type = "group", inline = true, name = buffs and "Swipe" or "Aura Overlay",
                        args = {
                            auraOverlay = {
                                order = 1, type = "select", name = "Aura Overlay", width = 1.4, hidden = buffs,
                                values = function()
                                    local on = E.db.thingsUI.cdmIcons.hideAuraOverlay
                                    return { default = on and "Settings (hidden)" or "Settings (shown)", hide = "Hide", show = "Show" }
                                end,
                                sorting = { "default", "hide", "show" },
                                get = function() local e = entry() return (e and e.auraOverlay) or "default" end,
                                set = function(_, v)
                                    setField("auraOverlay", (v ~= "default") and v or nil)
                                    TUI:UpdateCDMIcons()
                                end,
                            },
                            swipeDir = {
                                order = 2, type = "select", width = 1.2,
                                name = buffs and "Invert Swipe" or "Aura Swipe Direction",
                                values = function()
                                    local on
                                    if buffs then
                                        local v = cdmDB().buffIcon
                                        on = v and v.invertSwipe
                                    else
                                        on = cdmDB().auraSwipeReverse
                                    end
                                    return { default = on and "Settings (reversed)" or "Settings (normal)", on = "Reversed", off = "Normal" }
                                end,
                                sorting = { "default", "on", "off" },
                                get = function()
                                    local e = entry()
                                    return (e and (buffs and e.invertSwipe or e.swipeReverse)) or "default"
                                end,
                                set = function(_, v)
                                    lookField(buffs and "invertSwipe" or "swipeReverse", (v ~= "default") and v or nil)
                                end,
                            },
                            swipeBrk = { order = 3, type = "description", name = "", width = "full" },
                            swipeColorOn = {
                                order = 4, type = "toggle", name = "Own Swipe Color",
                                get = function() local e = entry() return (e and e.swipeColor) ~= nil end,
                                set = function(_, v)
                                    lookField("swipeColor", v and { r = 1, g = 0.82, b = 0, a = 0.6 } or nil)
                                end,
                            },
                            swipeColor = {
                                order = 5, type = "color", name = "Color", hasAlpha = true,
                                hidden = function() local e = entry() return not (e and e.swipeColor) end,
                                get = function()
                                    local c = entry().swipeColor
                                    return c.r, c.g, c.b, c.a or 0.6
                                end,
                                set = function(_, r, g, b, a) lookField("swipeColor", { r = r, g = g, b = b, a = a }) end,
                            },
                        },
                    },
                    pandemicGrp = {
                        order = 0.7, type = "group", inline = true, name = "Pandemic Glow",
                        args = {
                            pandemicMode = {
                                order = 1, type = "select", name = "Pandemic Glow", width = 1.4,
                                values = function()
                                    return { default = "Settings (" .. PANDEMIC_NAMES[globalPandemic()] .. ")",
                                        blizzard = "Blizzard", hide = "Hidden", custom = "Custom Glow" }
                                end,
                                sorting = { "default", "blizzard", "hide", "custom" },
                                get = function() local e = entry() return (e and e.pandemicMode) or "default" end,
                                set = function(_, v) lookField("pandemicMode", (v ~= "default") and v or nil) end,
                            },
                            pandemicColorOn = {
                                order = 2, type = "toggle", name = "Own Color", hidden = notCustom,
                                get = function() local e = entry() return (e and e.pandemicColor) ~= nil end,
                                set = function(_, v) lookField("pandemicColor", v and { r = 1, g = 0.3, b = 0.3 } or nil) end,
                            },
                            pandemicColor = {
                                order = 3, type = "color", name = "Color",
                                hidden = function() local e = entry() return notCustom() or not (e and e.pandemicColor) end,
                                get = function()
                                    local c = entry().pandemicColor
                                    return c.r, c.g, c.b
                                end,
                                set = function(_, r, g, b) lookField("pandemicColor", { r = r, g = g, b = b }) end,
                            },
                            pandemicStyleOn = {
                                order = 4, type = "toggle", name = "Own Glow Style", hidden = notCustom,
                                get = function() local e = entry() return (e and e.pandemicFX) ~= nil end,
                                set = function(_, v)
                                    -- starts from Layout > Aura Overlay
                                    lookField("pandemicFX", v and ns.DeepCopy(cdmDB().pandemicFX or {}) or nil)
                                end,
                            },
                            pandemicBrk = { order = 5, type = "description", name = "", width = "full", hidden = noOwnPandemicLook },
                            style = pandemicLook.style,
                            lines = pandemicLook.lines,
                            thickness = pandemicLook.thickness,
                            particles = pandemicLook.particles,
                            scale = pandemicLook.scale,
                            frequency = pandemicLook.frequency,
                            offset = pandemicLook.offset,
                        },
                    },
                    iconGrp = {
                        order = 0.5, type = "group", inline = true, name = "Icon",
                        args = ns.CustomIconArgs(function() local e = entry() return e and e.customIcon end,
                            function(v) setField("customIcon", v) end, 1),
                    },
                    showGrp = {
                        order = 0.52, type = "group", inline = true, name = "Show",
                        args = (function()
                            -- the rules table appears with the first rule set
                            local function vis()
                                local e = entry()
                                if e and e.visibility then return e.visibility end
                                return setmetatable({}, { __newindex = function(_, k, v)
                                    local t = entry(true)
                                    t.visibility = t.visibility or {}
                                    t.visibility[k] = v
                                end })
                            end
                            local a = {
                                cdState = {
                                    order = 0.5, type = "select", name = "Cooldown", hidden = buffs,
                                    values = { any = "Always", cooldown = "Only On Cooldown", ready = "Only When Ready" },
                                    sorting = { "any", "cooldown", "ready" },
                                    get = function() local e = entry() return (e and e.cdState) or "any" end,
                                    set = function(_, v) setField("cdState", (v ~= "any") and v or nil) end,
                                },
                            }
                            for k, v in pairs(ns.VisibilityArgs(vis, apply)) do a[k] = v end
                            return a
                        end)(),
                    },
                    onTopGrp = {
                        order = 0.55, type = "group", inline = true, name = "Aura Icon On Top",
                        hidden = buffs,
                        args = (function()
                            local SB = ns.SpecialBars
                            local function count() return (SB and SB.GetIconCount and SB.GetIconCount()) or 0 end
                            -- this spec's Aura Icon sitting on the selected spell
                            local function linked()
                                if not (SB and isSpell()) then return nil end
                                for i = 1, count() do
                                    local d = SB.GetIconDB("icon" .. i)
                                    if d and d.overSpell == sel then return "icon" .. i, d end
                                end
                            end
                            local function linkedDB() return select(2, linked()) end
                            local function noLink() return linked() == nil end
                            local function refresh() TUI:UpdateSpecialBars(); ns.NotifyChange() end
                            local function bget(k, dflt) local d = linkedDB() local v = d and d[k] if v == nil then return dflt end return v end
                            local function bset(k, v) local d = linkedDB() if d then d[k] = v; refresh() end end
                            return {
                                pick = {
                                    order = 1, type = "select", name = "Aura Icon", width = 1.5,
                                    values = function()
                                        local nm = isSpell() and C_Spell.GetSpellName and C_Spell.GetSpellName(sel)
                                        local out = { [""] = "|cFF888888- None -|r", new = "|cFF40FF40+ New Aura Icon: " .. (nm or "this spell") .. "|r" }
                                        for i = 1, count() do
                                            local d = SB.GetIconDB("icon" .. i)
                                            if d and d.spellID then
                                                local busy = d.overSpell and d.overSpell ~= sel
                                                out["icon" .. i] = spellLabel(d.spellID) .. (busy and " |cff888888(on another)|r" or "")
                                            end
                                        end
                                        return out
                                    end,
                                    sorting = function()
                                        local out = { "", "new" }
                                        for i = 1, count() do
                                            local d = SB.GetIconDB("icon" .. i)
                                            if d and d.spellID then out[#out + 1] = "icon" .. i end
                                        end
                                        return out
                                    end,
                                    get = function() return linked() or "" end,
                                    set = function(_, v)
                                        -- one icon per cooldown
                                        for i = 1, count() do
                                            local d = SB.GetIconDB("icon" .. i)
                                            if d and d.overSpell == sel then d.overSpell = nil; SB.ReleaseIcon("icon" .. i) end
                                        end
                                        if v == "new" then
                                            local specID = SB.GetCurrentSpecID()
                                            v = (ns.SB_PlaceSpell and ns.SB_PlaceSpell(false, sel, specID)
                                                and SB.FindSlotForSpell and SB.FindSlotForSpell("icons", sel, specID)) or ""
                                        end
                                        if v ~= "" then
                                            local d = SB.GetIconDB(v)
                                            d.overSpell, d.cdmRow, d.customGroup, d.enabled = sel, nil, nil, true
                                            SB.ReleaseIcon(v)
                                        end
                                        if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end
                                        refresh()
                                    end,
                                },
                                open = {
                                    order = 2, type = "execute", name = "Open Aura Icon Settings", width = 1.2, hidden = noLink,
                                    func = function()
                                        local k = linked()
                                        if k and ns.SB_OpenIconEditor then ns.SB_OpenIconEditor(k) end
                                    end,
                                },
                                cdText = ns.OverCDArgs(linkedDB, function()
                                    local k = linked()
                                    if k and SB.RestyleOverCD then SB.RestyleOverCD(k) end
                                    ns.NotifyChange()
                                end, 10, noLink),
                                border = {
                                    order = 20, type = "group", inline = true, name = "Aura Icon Border", hidden = noLink,
                                    args = {
                                        showBorder = { order = 1, type = "toggle", name = "Show Border",
                                            get = function() return bget("showBorder", false) end, set = function(_, v) bset("showBorder", v) end },
                                        borderSize = { order = 2, type = "range", name = "Size", min = 1, max = 16, step = 1,
                                            disabled = function() return not bget("showBorder", false) end,
                                            get = function() return bget("borderSize", 1) end, set = function(_, v) bset("borderSize", v) end },
                                        borderColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                                            disabled = function() return not bget("showBorder", false) end,
                                            get = function() local c = bget("borderColor", {}) return c.r or 0, c.g or 0, c.b or 0, c.a or 1 end,
                                            set = function(_, r, g, b, a) bset("borderColor", { r = r, g = g, b = b, a = a }) end },
                                        borderInset = { order = 4, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                                            disabled = function() return not bget("showBorder", false) end,
                                            get = function() return bget("borderInset", 0) end, set = function(_, v) bset("borderInset", v) end },
                                        borderStroke = { order = 5, type = "toggle", name = "Stroke",
                                            disabled = function() return not bget("showBorder", false) end,
                                            get = function() return bget("borderStroke", false) end, set = function(_, v) bset("borderStroke", v or nil) end },
                                    },
                                },
                            }
                        end)(),
                    },
                    glowGrp = {
                        order = 1, type = "group", inline = true, name = "Glow",
                        args = {
                            glow = {
                                order = 1, type = "select", name = "Glow",
                                -- a buff never procs: off, or on while its icon shows
                                values = buffs and { default = "Off", always = "While Shown" }
                                    or { default = "On Proc", always = "Always", never = "Never" },
                                sorting = buffs and { "default", "always" } or { "default", "always", "never" },
                                get = function() local e = entry() return (e and e.glow) or "default" end,
                                set = function(_, v) setField("glow", (v ~= "default") and v or nil) end,
                            },
                            glowColorOn = {
                                order = 2, type = "toggle", name = "Own Glow Color",
                                disabled = glowOff,
                                get = function() local e = entry() return (e and e.glowColor) ~= nil end,
                                set = function(_, v) setField("glowColor", v and { r = 1, g = 0.85, b = 0.1 } or nil) end,
                            },
                            glowColor = {
                                order = 3, type = "color", name = "Glow Color",
                                hidden = function() local e = entry() return not (e and e.glowColor) end,
                                get = function()
                                    local c = (entry() or {}).glowColor or {}
                                    return c.r or 1, c.g or 0.85, c.b or 0.1
                                end,
                                set = function(_, r, g, b) setField("glowColor", { r = r, g = g, b = b }) end,
                            },
                            glowStyleOn = {
                                order = 4, type = "toggle", name = "Own Glow Style",
                                disabled = glowOff,
                                get = function() return not noOwnLook() end,
                                set = function(_, v)
                                    -- starts from Layout > Glow
                                    local g = E.db.thingsUI.cdmIcons.glow or {}
                                    setField("glowFX", v and {
                                        style = g.style, lines = g.lines, thickness = g.thickness, particles = g.particles,
                                        scale = g.scale, frequency = g.frequency, offset = g.offset,
                                    } or nil)
                                end,
                            },
                            glowBrk = { order = 5, type = "description", name = "", width = "full", hidden = noOwnLook },
                            style = look.style,
                            lines = look.lines,
                            thickness = look.thickness,
                            particles = look.particles,
                            scale = look.scale,
                            frequency = look.frequency,
                            offset = look.offset,
                        },
                    },
                    cooldownGrp = {
                        order = 2, type = "group", inline = true, name = buffs and "Duration Text" or "Cooldown Text",
                        args = {
                            hideCooldownText = {
                                order = 1, type = "toggle", name = "Hide",
                                get = function() local e = entry() return (e and e.hideCooldownText) and true or false end,
                                set = function(_, v) setField("hideCooldownText", v or nil) end,
                            },
                            cooldownFontSize = {
                                order = 2, type = "range", name = "Size (0 = viewer's)",
                                min = 0, max = 40, step = 1,
                                hidden = function() local e = entry() return (e and e.hideCooldownText) and true or false end,
                                get = function() local e = entry() return (e and e.cooldownFontSize) or 0 end,
                                set = function(_, v) setField("cooldownFontSize", (v > 0) and v or nil) end,
                            },
                            colorOn = cdColorOn,
                            color = cdColor,
                            brk = cdBrk,
                            point = cdPoint,
                            xOffset = cdX,
                            yOffset = cdY,
                        },
                    },
                    countGrp = {
                        order = 3, type = "group", inline = true, name = buffs and "Stacks" or "Stacks and Charges",
                        args = {
                            hideCount = {
                                order = 1, type = "toggle", name = "Hide",
                                get = function() local e = entry() return (e and e.hideCount) and true or false end,
                                set = function(_, v) setField("hideCount", v or nil) end,
                            },
                            countFontSize = {
                                order = 2, type = "range", name = "Size (0 = viewer's)",
                                min = 0, max = 40, step = 1,
                                hidden = function() local e = entry() return (e and e.hideCount) and true or false end,
                                get = function() local e = entry() return (e and e.countFontSize) or 0 end,
                                set = function(_, v) setField("countFontSize", (v > 0) and v or nil) end,
                            },
                            colorOn = countColorOn,
                            color = countColor,
                            brk = countBrk,
                            point = countPoint,
                            xOffset = countX,
                            yOffset = countY,
                        },
                    },
                    reset = {
                        order = 9, type = "execute", name = "Reset This Spell",
                        disabled = function() return entry() == nil end,
                        func = function() store()[sel] = nil; apply() end,
                    },
                },
            },
        },
    }
end

-- its own Modules entry: per-spell look for Essential/Utility cooldowns and Buff Icons
function TUI:SpellEditorOptions()
    return {
        type = "group", name = "CDM Spell Editor", childGroups = "tab",
        args = {
            cooldowns = SpellEditorPage(1, false),
            buffs = SpellEditorPage(2, true),
        },
    }
end

local function TrinketsTab(order)
    local function bl()
        local db = E.db.thingsUI.cdmIcons
        db.trinketBlacklist = db.trinketBlacklist or {}
        return db.trinketBlacklist
    end
    local function poke()
        if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
        if ns.TrinketsCDM then ns.TrinketsCDM.Refresh() end
        if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
    end
    local function ent(id, create)
        local b = bl()
        local e = b[id]
        if e == true then e = { use = true, buff = true }; b[id] = e end
        if not e and create then e = {}; b[id] = e end
        return e
    end
    local function setFlag(id, flag, v)
        if not id then return end
        local e = ent(id, true)
        e[flag] = v or nil
        if not (e.use or e.buff) then bl()[id] = nil end
        poke()
    end
    local function itemLabel(id)
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        return ("|T%d:16:16|t %s"):format(icon or 134400, name or ("Item " .. id))
    end
    local function listedIDs()
        local out = {}
        for id in pairs(bl()) do out[#out + 1] = id end
        table.sort(out)
        return out
    end
    local function slotID(slot)
        return GetInventoryItemID and GetInventoryItemID("player", slot) or nil
    end

    local eqArgs = {}
    local function slotRow(ord, slot)
        eqArgs["s" .. slot .. "_label"] = {
            order = ord, type = "description", width = 1.0, fontSize = "medium",
            name = function()
                local id = slotID(slot)
                return id and itemLabel(id) or "|cff888888(empty slot)|r"
            end,
        }
        eqArgs["s" .. slot .. "_use"] = {
            order = ord + 0.1, type = "toggle", name = "Hide Cooldown", width = 0.65,
            disabled = function() return not slotID(slot) end,
            get = function() local e = slotID(slot) and ent(slotID(slot)) return (e and e.use) and true or false end,
            set = function(_, v) setFlag(slotID(slot), "use", v) end,
        }
        eqArgs["s" .. slot .. "_buff"] = {
            order = ord + 0.2, type = "toggle", name = "Hide Buff", width = 0.65,
            disabled = function() return not slotID(slot) end,
            get = function() local e = slotID(slot) and ent(slotID(slot)) return (e and e.buff) and true or false end,
            set = function(_, v) setFlag(slotID(slot), "buff", v) end,
        }
        eqArgs["s" .. slot .. "_dest"] = {
            order = ord + 0.25, type = "select", name = "Destination", width = 0.9,
            values = function()
                local out = { [0] = "Blizzard CDM", essential = "Essential", utility = "Utility" }
                for _, g in ipairs((ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups()) or {}) do
                    out[g.id] = g.name or ("Group " .. g.id)
                end
                return out
            end,
            sorting = function()
                local out = { 0, "essential", "utility" }
                for _, g in ipairs((ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups()) or {}) do
                    out[#out + 1] = g.id
                end
                return out
            end,
            get = function()
                local db = E.db.thingsUI.cdmIcons
                local d = db and db.trinketDest and db.trinketDest[tostring(slot)]
                return d and (d.row or d.group) or 0
            end,
            set = function(_, v)
                local db = E.db.thingsUI.cdmIcons
                db.trinketDest = db.trinketDest or {}
                local d
                if v == "essential" or v == "utility" then d = { row = v }
                elseif v ~= 0 then d = { group = v } end
                db.trinketDest[tostring(slot)] = d
                if ns.TrinketsCDM then ns.TrinketsCDM.Refresh() end
                if TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
                if ns.CustomGroups and ns.CustomGroups._rebuildOptions then ns.CustomGroups._rebuildOptions() end
                ns.NotifyChange()
            end,
        }
        eqArgs["s" .. slot .. "_brk"] = { order = ord + 0.3, type = "description", name = "", width = "full" }
    end
    slotRow(1, 13)
    slotRow(2, 14)

    local blArgs = {}
    for ri = 1, 10 do
        local function rowID() return listedIDs()[ri] end
        local hidden = function() return rowID() == nil end
        blArgs["b" .. ri .. "_label"] = {
            order = ri, type = "description", width = 1.2, fontSize = "medium",
            name = function() local id = rowID() return id and itemLabel(id) or "" end,
            hidden = hidden,
        }
        blArgs["b" .. ri .. "_use"] = {
            order = ri + 0.1, type = "toggle", name = "Hide Cooldown", width = 0.7, hidden = hidden,
            get = function() local id = rowID() local e = id and ent(id) return (e and e.use) and true or false end,
            set = function(_, v) setFlag(rowID(), "use", v) end,
        }
        blArgs["b" .. ri .. "_buff"] = {
            order = ri + 0.2, type = "toggle", name = "Hide Buff", width = 0.7, hidden = hidden,
            get = function() local id = rowID() local e = id and ent(id) return (e and e.buff) and true or false end,
            set = function(_, v) setFlag(rowID(), "buff", v) end,
        }
        blArgs["b" .. ri .. "_del"] = {
            order = ri + 0.3, type = "execute", name = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:13|t", width = 0.3, hidden = hidden,
            func = function()
                local id = rowID()
                if id then bl()[id] = nil; poke() end
            end,
        }
        blArgs["b" .. ri .. "_brk"] = { order = ri + 0.4, type = "description", name = "", width = "full", hidden = hidden }
    end

    return {
        order = order, type = "group", name = "Trinkets",
        args = {
            desc = {
                order = 1, type = "description",
                name = "Hide a trinket's |cFFFFD200cooldown|r (everywhere: Blizzard's rows, Destination and groups) and its |cFF60E0A0buff|r (Buff Icons) separately. Blacklisting is by item, so it sticks across swaps.\n",
            },
            addID = {
                order = 2, type = "input", name = "Add by Item ID or name",
                get = function() return "" end,
                set = function(_, v)
                    v = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if v == "" then return end
                    local id = tonumber(v)
                    if not id and C_Item.GetItemInfoInstant then
                        id = C_Item.GetItemInfoInstant(v)
                    end
                    if id then
                        bl()[id] = { use = true, buff = true }
                        poke()
                    end
                end,
            },
            equippedGrp = { order = 3, type = "group", inline = true, name = "Equipped", args = eqArgs },
            blacklistGrp = { order = 4, type = "group", inline = true, name = "Blacklisted", args = blArgs },
        },
    }
end

function TUI:CDMIconsOptions()

    return {
        order = 30,
        type = "group",
        name = "CDM",
        childGroups = "tab",
        args = {

            layoutTab = {
                order = 10, type = "group", name = "Layout", childGroups = "tab",
                args = {
                    essentialTab = ViewerGroup(10, "essential", "Essential"),
                    utilityTab   = ViewerGroup(20, "utility",   "Utility",
                                    { includeAnchor = true }),
                    buffIconTab  = ViewerGroup(30, "buffIcon",  "Buff Icons",
                                    { includeAnchor = true, alwaysOnAnchor = true,
                                      minIconSize = 10, maxIconSize = 60 }),
                    glowSubTab   = GlowTab(40),
                    auraSubTab   = AuraOverlayTab(45),
                },
            },
            racialsToCDMSubTab = RacialsToCDMTab(30),
            trinketBlacklistSubTab = TrinketsTab(40),
            clusterPositioningSubTab = (function()
                local g = TUI.ClusterPositioningSubTab and TUI:ClusterPositioningSubTab() or nil
                if g then g.order = 50 end
                return g
            end)(),
            settingsTab = {
                order = 60, type = "group", name = "Settings",
                args = {
                    editModeLock = {
                        order = 1, type = "toggle", width = "full",
                        name = "Lock CDM viewers in /editmode",
                        get = function() return E.db.thingsUI.cdmIcons.editModeLock end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.editModeLock = v
                        end,
                    },
                    hideAuraBorder = {
                        order = 2, type = "toggle", width = "full",
                        name = "Hide Blizzard aura border",
                        get = function() return E.db.thingsUI.cdmIcons.hideAuraBorder end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.hideAuraBorder = v
                            TUI:UpdateCDMIcons()
                            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
                        end,
                    },
                    auraOverlayLink = {
                        order = 3, type = "description", width = "full",
                        name = "|cFF888888Hide Aura Overlay and the pandemic glow live in Layout > Aura Overlay.|r",
                    },
                    hideGroupedDuplicates = {
                        order = 4.5, type = "toggle", width = "full",
                        name = "Hide CDM copies of what thingsUI already shows (Groups, Charge Bar, Aura Icons)",
                        get = function() return E.db.thingsUI.cdmIcons.hideGroupedDuplicates ~= false end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.hideGroupedDuplicates = v
                            if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
                        end,
                    },
                    autoEnableCDM = {
                        order = 5, type = "toggle", width = "full",
                        name = "Auto-enable Cooldown Manager",
                        get = function() return E.db.thingsUI.cdmIcons.autoEnableCDM end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.autoEnableCDM = v
                            if v and ns.CDMIcons and ns.CDMIcons.MaybeAutoEnableCDM then ns.CDMIcons.MaybeAutoEnableCDM() end
                        end,
                    },
                },
            },
        },
    }
end
