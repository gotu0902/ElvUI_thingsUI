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
    local function refresh() TUI:UpdateCDMText() end

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
                        -- a receiving bar may not also push onward
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
            layoutTab = {
                order = 1, type = "group", name = "Layout",
                args  = layoutArgs,
            },
            textTab = {
                order = 2, type = "group", name = "Text",
                args  = TextArgs(key),
            },
        },
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
    return {
        order = order, type = "group", name = "Glow",
        args = {
            desc = {
                order = 0, type = "description",
                name = "Replace Blizzard's proc glow on Essential and Utility icons with a thingsUI style.\n",
            },
            enabled = {
                order = 1, type = "toggle", name = "Custom Glow",
                get = function() return gdb().enabled end,
                set = function(_, v) gdb().enabled = v; Update() end,
            },
            style = {
                order = 2, type = "select", name = "Style",
                disabled = function() return not gdb().enabled end,
                values = { pixel = "Pixel Glow", autocast = "Autocast Shine", proc = "Proc Glow", button = "Action Button Glow" },
                sorting = { "pixel", "autocast", "proc", "button" },
                get = function() return gdb().style or "pixel" end,
                set = function(_, v) gdb().style = v; Update() end,
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
            lines = {
                order = 5, type = "range", name = "Lines", min = 4, max = 16, step = 1,
                hidden = function() return (gdb().style or "pixel") ~= "pixel" end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().lines or 8 end,
                set = function(_, v) gdb().lines = v; Update() end,
            },
            thickness = {
                order = 6, type = "range", name = "Thickness", min = 1, max = 4, step = 1,
                hidden = function() return (gdb().style or "pixel") ~= "pixel" end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().thickness or 2 end,
                set = function(_, v) gdb().thickness = v; Update() end,
            },
            particles = {
                order = 7, type = "range", name = "Particles", min = 1, max = 8, step = 1,
                hidden = function() return (gdb().style or "pixel") ~= "autocast" end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().particles or 4 end,
                set = function(_, v) gdb().particles = v; Update() end,
            },
            scale = {
                order = 8, type = "range", name = "Scale", min = 0.5, max = 2, step = 0.05,
                hidden = function() return (gdb().style or "pixel") ~= "autocast" end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().scale or 1 end,
                set = function(_, v) gdb().scale = v; Update() end,
            },
            frequency = {
                order = 9, type = "range", name = "Speed", min = 0.05, max = 0.5, step = 0.01,
                hidden = function()
                    local s = gdb().style or "pixel"
                    return s == "proc"
                end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().frequency or 0.25 end,
                set = function(_, v) gdb().frequency = v; Update() end,
            },
            offset = {
                order = 10, type = "range", name = "Offset", min = -8, max = 8, step = 1,
                hidden = function() return (gdb().style or "pixel") == "button" end,
                disabled = function() return not gdb().enabled end,
                get = function() return gdb().offset or 0 end,
                set = function(_, v) gdb().offset = v; Update() end,
            },
        },
    }
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
        local nat = ns.RacialsCDM and ns.RacialsCDM.NativeViewer and ns.RacialsCDM.NativeViewer(id)
        if nat and d and d ~= "off" then
            if d ~= "dynamic" and d ~= nat then
                label = label .. ("  |cFFFF3030! shown in CDM %s|r"):format(nat == "essential" and "Essential" or "Utility")
            else
                label = label .. "  |cFF888888(CDM native)|r"
            end
        end
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
                name = "|cFF888888Tick to add here - ticking a racial assigned elsewhere moves it here. Untick to remove.\nIf the racial is shown natively in the Cooldown Manager, its CDM position wins. |r|cFFFF3030!|r|cFF888888 = it sits in the other viewer - move it in Blizzard's Cooldown Settings.|r\n",
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

local function TrinketsTab(order)
    local function bl()
        local db = E.db.thingsUI.cdmIcons
        db.trinketBlacklist = db.trinketBlacklist or {}
        return db.trinketBlacklist
    end
    local function poke()
        if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
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
                local out = { [0] = "CDM" }
                for _, g in ipairs((ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups()) or {}) do
                    out[g.id] = g.name or ("Group " .. g.id)
                end
                return out
            end,
            get = function()
                local db = E.db.thingsUI.cdmIcons
                local d = db and db.trinketDest and db.trinketDest[tostring(slot)]
                return d and d.group or 0
            end,
            set = function(_, v)
                local db = E.db.thingsUI.cdmIcons
                db.trinketDest = db.trinketDest or {}
                db.trinketDest[tostring(slot)] = (v ~= 0) and { group = v } or nil
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
                name = "Hide trinkets from the CDM viewers: the |cFFFFD200cooldown|r (Essential/Utility) and the |cFF60E0A0buff|r (Buff Icons) hide separately. Blacklisting is by item, so it sticks across swaps.\n",
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

            essentialTab        = ViewerGroup(10, "essential", "Essential"),
            utilityTab          = ViewerGroup(20, "utility",   "Utility",
                                    { includeAnchor = true }),
            buffIconTab         = ViewerGroup(30, "buffIcon",  "Buff Icons",
                                    { includeAnchor = true, alwaysOnAnchor = true,
                                      minIconSize = 10, maxIconSize = 60 }),
            racialsToCDMSubTab = RacialsToCDMTab(45),
            glowSubTab = GlowTab(46),
            trinketBlacklistSubTab = TrinketsTab(47),
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
                    hideAuraOverlay = {
                        order = 3, type = "toggle", width = "full",
                        name = "Hide Aura Overlay",
                        get = function() return E.db.thingsUI.cdmIcons.hideAuraOverlay end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.hideAuraOverlay = v
                            TUI:UpdateCDMIcons()
                        end,
                    },
                    hidePandemic = {
                        order = 4, type = "toggle", width = "full",
                        name = "Hide Pandemic Glow",
                        get = function() return E.db.thingsUI.cdmIcons.hidePandemic end,
                        set = function(_, v)
                            E.db.thingsUI.cdmIcons.hidePandemic = v
                            if ns.CDMIcons and ns.CDMIcons.ClearPandemicAll then ns.CDMIcons.ClearPandemicAll() end
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
