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
                get = function() return E.db.thingsUI.cdmIcons[key].iconsPerRow end,
                set = function(_, v)
                    E.db.thingsUI.cdmIcons[key].iconsPerRow = v
                    TUI:UpdateCDMIcons()
                end,
            },
    }

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

-- Racials -> CDM
local RACIAL_DEST = {
    essential = "|cFFFFD27FEssential|r",
    utility   = "|cFFFFD27FUtility|r",
    dynamic   = "|cFF8AC8FFDynamic|r",
}
local RACIAL_DEST_ORDER = { "essential", "utility", "dynamic" }
local function RacialsToCDMTab(order)
    local function rdb() return E.db.thingsUI.racialsCDM end
    local function dest() local db = rdb(); db.dest = db.dest or {}; return db.dest end
    local CG = ns.CustomGroups

    local function addList()
        local list, d = {}, dest()
        for _, id in ipairs(ns.Racials or {}) do
            if not d[id] then
                list[#list + 1] = { id = id, nm = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) }
            end
        end
        table.sort(list, function(a, b) return a.nm < b.nm end)
        return list
    end
    local function addValues()
        local out = {}
        for _, e in ipairs(addList()) do
            local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id)) or 0
            out[tostring(e.id)] = ("|T%d:14:14|t %s"):format(tex, e.nm)
        end
        return out
    end
    local function addSorting()
        local out = {}
        for _, e in ipairs(addList()) do out[#out + 1] = tostring(e.id) end
        return out
    end

    local args = {
        desc = { order = 1, type = "description",
            name = " " },
        threshold = {
            order = 2, type = "range", name = "Dynamic Threshold", min = 1, max = 20, step = 1,
            hidden = function()
                local d = rdb() and rdb().dest
                if d then for _, v in pairs(d) do if v == "dynamic" then return false end end end
                return true
            end,
            get = function() return (rdb() and rdb().dynamicThreshold) or 8 end,
            set = function(_, v) rdb().dynamicThreshold = v; if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end end,
        },
        addRacial = {
            order = 3, type = "select", name = "|cFF59D759Add Racial|r", width = "double",
            values = addValues, sorting = addSorting,
            get = function() return "" end,
            set = function(_, v)
                local id = tonumber(v)
                if id then
                    dest()[id] = "essential"
                    if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end
                    if ns.NotifyChange then ns.NotifyChange() end
                end
            end,
        },
        listHeader = { order = 9, type = "header", name = "Added Racials" },
        empty = { order = 10, type = "description",
            name = "|cFF888888Nothing added yet - pick one from Add Racial above.|r",
            hidden = function() return next(dest()) ~= nil end },
    }

    local idx = 0
    for _, id in ipairs(ns.Racials or {}) do
        idx = idx + 1
        args["entry" .. id] = {
            order = 11 + idx, type = "group", inline = true, name = "",
            hidden = function() return not dest()[id] end,
            args = {
                destSel = {
                    order = 1, type = "select", width = "double",
                    name = function()
                        local nm  = (C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id)
                        local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 0
                        local owned = (not (CG and CG.PlayerHasRacial)) or CG.PlayerHasRacial(id)
                        if owned then return ("|T%d:16:16|t %s"):format(tex, nm) end
                        return ("|T%d:16:16|t |cFF777777%s (other race)|r"):format(tex, nm)
                    end,
                    values = RACIAL_DEST, sorting = RACIAL_DEST_ORDER,
                    get = function() return dest()[id] or "essential" end,
                    set = function(_, v) dest()[id] = v; if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end end,
                },
                remove = {
                    order = 2, type = "execute", name = "Remove", width = 0.7,
                    func = function()
                        dest()[id] = nil
                        if TUI.UpdateRacialsCDM then TUI:UpdateRacialsCDM() end
                        if ns.NotifyChange then ns.NotifyChange() end
                    end,
                },
            },
        }
    end

    return { order = order, type = "group", name = "Racials", args = args }
end

function TUI:CDMIconsOptions()

    return {
        order = 30,
        type = "group",
        name = "CDM",
        childGroups = "tab",
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
            essentialTab        = ViewerGroup(10, "essential", "Essential"),
            utilityTab          = ViewerGroup(20, "utility",   "Utility",
                                    { includeAnchor = true }),
            buffIconTab         = ViewerGroup(30, "buffIcon",  "Buff Icons",
                                    { includeAnchor = true, alwaysOnAnchor = true,
                                      minIconSize = 10, maxIconSize = 60 }),
            racialsToCDMSubTab = RacialsToCDMTab(45),
            clusterPositioningSubTab = (function()
                local g = TUI.ClusterPositioningSubTab and TUI:ClusterPositioningSubTab() or nil
                if g then g.order = 50 end
                return g
            end)(),
        },
    }
end
