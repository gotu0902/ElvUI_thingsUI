local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local function DB() return E.db.thingsUI.kickTracker end
local function gget(k) return DB()[k] end
local function gset(k, v)
    DB()[k] = v
    TUI:UpdateKickTracker()
    NotifyChange()
end
local function Off() return not DB().enabled end
local function Free() return (gget("anchorFrame") or "UIParent") == "UIParent" end

local function unpackColor(c)
    c = c or {}
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

-- everything but itself
local function AnchorValues()
    local out = ns.ANCHORS.FilteredValues()
    out.TUI_KickTracker = nil
    return out
end

local function AnchorOrder()
    local out = {}
    for _, k in ipairs(ns.ANCHORS.FilteredOrder()) do
        if k ~= "TUI_KickTracker" then out[#out + 1] = k end
    end
    return out
end

-- each part per state
local STATES = { "ready", "cooldown", "low" }
local PARTS = { { "bar", "Bar", true }, { "bg", "Background", true }, { "name", "Name" }, { "time", "Time" } }
local W_LABEL, W_CELL, W_CLASS = 0.6, 0.55, 1.2

local function ColorsArgs()
    local function noLow() return not gget("almostReady") end
    local function part(p) return DB().colors[p] end
    local function classOf(p) return DB().classColors[p] end
    local function head(o, text, w) return { order = o, type = "description", name = text, width = w, fontSize = "medium" } end
    local args = {
        h0 = head(1, "", W_LABEL),
        h1 = head(1.1, "Ready", W_CELL),
        h2 = head(1.2, "On Cooldown", W_CELL),
        h3 = head(1.3, "Almost Ready", W_CELL),
        h4 = head(1.4, "Class Color", W_CLASS),
        hBrk = { order = 1.9, type = "description", name = "", width = "full" },
    }
    for i, p in ipairs(PARTS) do
        local key, label, alpha = p[1], p[2], p[3]
        local o = 2 + i
        args[key] = head(o, label, W_LABEL)
        for j, st in ipairs(STATES) do
            -- the time only shows while the kick is down
            if key == "time" and st == "ready" then
                args[key .. st] = head(o + j * 0.1, "", W_CELL)
            else
                args[key .. st] = {
                    order = o + j * 0.1, type = "color", name = "", width = W_CELL, hasAlpha = alpha,
                    -- a class-colored bar still takes the alpha from here
                    disabled = function() return (st == "low" and noLow()) or (not alpha and classOf(key)[st]) or false end,
                    get = function() return unpackColor(part(key)[st]) end,
                    set = function(_, r, g, b, a)
                        part(key)[st] = { r = r, g = g, b = b, a = alpha and a or nil }
                        TUI:UpdateKickTracker()
                        NotifyChange()
                    end,
                }
            end
        end
        args[key .. "Class"] = {
            order = o + 0.4, type = "multiselect", dialogControl = "Dropdown", name = "", width = W_CLASS,
            values = function()
                local v = { cooldown = "On Cooldown" }
                if key ~= "time" then v.ready = "Ready" end
                if not noLow() then v.low = "Almost Ready" end
                return v
            end,
            get = function(_, k) return classOf(key)[k] or false end,
            set = function(_, k, v)
                classOf(key)[k] = v and true or false
                TUI:UpdateKickTracker()
                NotifyChange()
            end,
        }
        args[key .. "Brk"] = { order = o + 0.5, type = "description", name = "", width = "full" }
    end
    args.lowGroup = {
        order = 20, type = "group", inline = true, name = "Almost Ready",
        args = {
            almostReady = { order = 1, type = "toggle", name = "Almost Ready",
                get = function() return gget("almostReady") end, set = function(_, v) gset("almostReady", v) end },
            thresholdSeconds = { order = 2, type = "range", name = "Below (Sec)", min = 1, max = 30, step = 1,
                disabled = noLow,
                get = function() return gget("thresholdSeconds") or 3 end, set = function(_, v) gset("thresholdSeconds", v) end },
            brk = { order = 3, type = "description", name = "", width = "full" },
            glowThreshold = { order = 4, type = "toggle", name = "Glow",
                disabled = noLow,
                get = function() return gget("glowThreshold") end, set = function(_, v) gset("glowThreshold", v) end },
            glowType = { order = 5, type = "select", name = "Glow Type",
                values = { pixel = "Pixel", ants = "Ants", proc = "Proc", pulse = "Pulse" }, sorting = { "pixel", "ants", "proc", "pulse" },
                disabled = function() return noLow() or not gget("glowThreshold") end,
                get = function() return gget("glowType") end, set = function(_, v) gset("glowType", v) end },
            glowColor = { order = 6, type = "color", name = "Glow Color", hasAlpha = true,
                disabled = function() return noLow() or not gget("glowThreshold") end,
                get = function() return unpackColor(gget("glowColor")) end,
                set = function(_, r, g, b, a) gset("glowColor", { r = r, g = g, b = b, a = a }) end },
        },
    }
    return args
end

function TUI:KickTrackerOptions()
    return {
        order = 5.6, type = "group", name = "Kick Tracker", childGroups = "tab",
        args = {
            enabled = {
                order = 1, type = "toggle", name = "Enable Kick Tracker", width = "full",
                get = function() return gget("enabled") end,
                set = function(_, v)
                    local db = DB()
                    -- starts out for dungeons; the Visibility tab takes it from there
                    if v and not db.visibility then db.visibility = { enabled = true, places = { dungeon = true } } end
                    gset("enabled", v)
                end,
            },
            desc = {
                order = 2, type = "description",
                name = "Your group's interrupts, nobody else needs an addon. Other players' cooldowns start when their kick lands: one that stops nothing can't be seen.\n",
            },
            showSelf = {
                order = 3, type = "toggle", name = "Show Yourself", disabled = Off,
                get = function() return gget("showSelf") ~= false end,
                set = function(_, v) gset("showSelf", v) end,
            },
            nsrtNicknames = {
                order = 4, type = "toggle", name = "NSRT Nicknames", disabled = Off,
                get = function() return gget("nsrtNicknames") ~= false end,
                set = function(_, v) gset("nsrtNicknames", v) end,
            },
            layoutTab = {
                order = 10, type = "group", name = "Layout & Position", disabled = Off,
                args = {
                    sizeGrp = {
                        order = 1, type = "group", inline = true, name = "Size",
                        args = {
                            width = { order = 1, type = "range", name = "Width", min = 60, max = 600, step = 1,
                                disabled = function() return gget("inheritWidth") and not Free() end,
                                get = function() return gget("width") end, set = function(_, v) gset("width", v) end },
                            inheritWidth = { order = 1.1, type = "toggle", name = "Inherit Width from Anchor",
                                disabled = Free,
                                get = function() return gget("inheritWidth") end, set = function(_, v) gset("inheritWidth", v) end },
                            inheritWidthOffset = { order = 1.2, type = "range", name = "Width Nudge", min = -200, max = 200, step = 0.5, bigStep = 1,
                                disabled = function() return not gget("inheritWidth") or Free() end,
                                get = function() return gget("inheritWidthOffset") end, set = function(_, v) gset("inheritWidthOffset", v) end },
                            height = { order = 2, type = "range", name = "Height", min = 8, max = 60, step = 1,
                                disabled = function() return gget("inheritHeight") and not Free() end,
                                get = function() return gget("height") end, set = function(_, v) gset("height", v) end },
                            inheritHeight = { order = 2.1, type = "toggle", name = "Inherit Height from Anchor",
                                disabled = Free,
                                get = function() return gget("inheritHeight") end, set = function(_, v) gset("inheritHeight", v) end },
                            inheritHeightOffset = { order = 2.2, type = "range", name = "Height Nudge", min = -50, max = 50, step = 0.5, bigStep = 1,
                                disabled = function() return not gget("inheritHeight") or Free() end,
                                get = function() return gget("inheritHeightOffset") end, set = function(_, v) gset("inheritHeightOffset", v) end },
                        },
                    },
                    barGrp = {
                        order = 2, type = "group", inline = true, name = "Bar",
                        args = {
                            spacing = { order = 1, type = "range", name = "Spacing", min = -1, max = 20, step = 1,
                                get = function() return gget("spacing") end, set = function(_, v) gset("spacing", v) end },
                            growth = { order = 2, type = "select", name = "Growth Direction",
                                values = { DOWN = "Grow Down", UP = "Grow Up" }, sorting = { "DOWN", "UP" },
                                get = function() return gget("growth") end, set = function(_, v) gset("growth", v) end },
                            statusBarTexture = { order = 3, type = "select", dialogControl = "LSM30_Statusbar", name = "Bar Texture",
                                values = function() return ns.LSM:HashTable("statusbar") end,
                                get = function() return gget("statusBarTexture") end, set = function(_, v) gset("statusBarTexture", v) end },
                            cooldownFill = { order = 7, type = "select", name = "On Cooldown",
                                values = { drain = "Bar Drains", fill = "Bar Fills Up" }, sorting = { "drain", "fill" },
                                get = function() return gget("cooldownFill") end, set = function(_, v) gset("cooldownFill", v) end },
                            reverseFill = { order = 8, type = "toggle", name = "Reverse Fill",
                                get = function() return gget("reverseFill") end, set = function(_, v) gset("reverseFill", v) end },
                        },
                    },
                    borderGrp = {
                        order = 3, type = "group", inline = true, name = "Border",
                        args = {
                            showBorder = { order = 1, type = "toggle", name = "Show Border",
                                get = function() return gget("showBorder") end, set = function(_, v) gset("showBorder", v) end },
                            borderSize = { order = 2, type = "range", name = "Size", min = 1, max = 6, step = 1,
                                disabled = function() return not gget("showBorder") end,
                                get = function() return gget("borderSize") end, set = function(_, v) gset("borderSize", v) end },
                            borderColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                                disabled = function() return not gget("showBorder") end,
                                get = function() return unpackColor(gget("borderColor")) end,
                                set = function(_, r, g, b, a) gset("borderColor", { r = r, g = g, b = b, a = a }) end },
                        },
                    },
                    iconGrp = {
                        order = 4, type = "group", inline = true, name = "Icon",
                        args = {
                            iconEnabled = { order = 1, type = "toggle", name = "Show Icon",
                                get = function() return gget("iconEnabled") ~= false end, set = function(_, v) gset("iconEnabled", v) end },
                            iconSide = { order = 2, type = "select", name = "Side",
                                disabled = function() return gget("iconEnabled") == false end,
                                values = { LEFT = "Left", RIGHT = "Right" }, sorting = { "LEFT", "RIGHT" },
                                get = function() return gget("iconSide") end, set = function(_, v) gset("iconSide", v) end },
                            iconSpacing = { order = 3, type = "range", name = "Icon Spacing", min = -1, max = 20, step = 1,
                                disabled = function() return gget("iconEnabled") == false end,
                                get = function() return gget("iconSpacing") end, set = function(_, v) gset("iconSpacing", v) end },
                            iconZoom = { order = 4, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true,
                                disabled = function() return gget("iconEnabled") == false end,
                                get = function() return gget("iconZoom") end, set = function(_, v) gset("iconZoom", v) end },
                        },
                    },
                    posGrp = {
                        order = 5, type = "group", inline = true, name = "Position",
                        args = {
                            toggleMovers = { order = 1, type = "execute", name = "Toggle thingsUI Movers", width = 1.2,
                                func = function() E:ToggleMoveMode("THINGSUI") end },
                            anchorFrame = { order = 2, type = "select", name = "Anchor To", width = "double",
                                values = AnchorValues, sorting = AnchorOrder,
                                get = function() return gget("anchorFrame") end,
                                set = function(_, v)
                                    if v ~= gget("anchorFrame") then ns.ANCHORS.ResetPlacement(DB()) end
                                    gset("anchorFrame", v)
                                end },
                            anchorPoint = { order = 4, type = "select", name = "Anchor From (self)",
                                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                get = function() return gget("anchorPoint") end, set = function(_, v) gset("anchorPoint", v) end },
                            anchorRelativePoint = { order = 5, type = "select", name = "Anchor To (target)",
                                values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                get = function() return gget("anchorRelativePoint") end, set = function(_, v) gset("anchorRelativePoint", v) end },
                            anchorXOffset = { order = 6, type = "range", name = "X Offset", min = -800, max = 800, step = 0.01, bigStep = 1,
                                get = function() return gget("anchorXOffset") end, set = function(_, v) gset("anchorXOffset", v) end },
                            anchorYOffset = { order = 7, type = "range", name = "Y Offset", min = -800, max = 800, step = 0.01, bigStep = 1,
                                get = function() return gget("anchorYOffset") end, set = function(_, v) gset("anchorYOffset", v) end },
                            strataBrk = { order = 9, type = "description", name = "", width = "full" },
                            frameStrata = { order = 10, type = "select", name = "Frame Strata",
                                values = ns.STRATA.VALUES, sorting = ns.STRATA.ORDER,
                                get = function() return gget("frameStrata") or "MEDIUM" end,
                                set = function(_, v) gset("frameStrata", (v ~= "MEDIUM") and v or nil) end },
                            frameLevel = { order = 11, type = "range", name = "Frame Level", min = 1, max = 100, step = 1,
                                get = function()
                                    local f = _G.TUI_KickTracker
                                    return gget("frameLevel") or (f and f._tuiBaseLevel) or 1
                                end,
                                set = function(_, v) gset("frameLevel", v) end },
                        },
                    },
                },
            },
            colorsTab = {
                order = 15, type = "group", name = "Colors", disabled = Off,
                args = ColorsArgs(),
            },
            textTab = {
                order = 20, type = "group", name = "Text", disabled = Off,
                args = {
                    font = { order = 1, type = "select", dialogControl = "LSM30_Font", name = "Font",
                        values = ns.FontValues,
                        get = function() return gget("font") end, set = function(_, v) gset("font", v) end },
                    fontSize = { order = 2, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                        get = function() return gget("fontSize") end, set = function(_, v) gset("fontSize", v) end },
                    fontOutline = { order = 3, type = "select", name = "Outline",
                        values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                        get = function() return gget("fontOutline") end, set = function(_, v) gset("fontOutline", v) end },
                    nameGroup = {
                        order = 10, type = "group", inline = true, name = "Name",
                        args = {
                            showName = { order = 1, type = "toggle", name = "Show Name",
                                get = function() return gget("showName") ~= false end, set = function(_, v) gset("showName", v) end },
                            namePoint = { order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                                get = function() return gget("namePoint") end, set = function(_, v) gset("namePoint", v) end },
                            nameXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                                get = function() return gget("nameXOffset") end, set = function(_, v) gset("nameXOffset", v) end },
                            nameYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.01, bigStep = 1,
                                get = function() return gget("nameYOffset") end, set = function(_, v) gset("nameYOffset", v) end },
                        },
                    },
                    durationGroup = {
                        order = 20, type = "group", inline = true, name = "Cooldown",
                        args = {
                            showDuration = { order = 1, type = "toggle", name = "Show Cooldown",
                                get = function() return gget("showDuration") ~= false end, set = function(_, v) gset("showDuration", v) end },
                            durationPoint = { order = 2, type = "select", name = "Align",
                                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                                get = function() return gget("durationPoint") end, set = function(_, v) gset("durationPoint", v) end },
                            durationXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                                get = function() return gget("durationXOffset") end, set = function(_, v) gset("durationXOffset", v) end },
                            durationYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.01, bigStep = 1,
                                get = function() return gget("durationYOffset") end, set = function(_, v) gset("durationYOffset", v) end },
                            tenthsBelow = { order = 6, type = "range", name = "Decimals Below (Sec)", min = 0, max = 30, step = 1,
                                get = function() return gget("tenthsBelow") end, set = function(_, v) gset("tenthsBelow", v) end },
                            durationFontSize = { order = 1.5, type = "range", name = "Font Size", min = 6, max = 36, step = 1,
                                get = function() return gget("durationFontSize") or gget("fontSize") end,
                                set = function(_, v) gset("durationFontSize", v) end },
                        },
                    },
                },
            },
            visibilityTab = {
                order = 30, type = "group", name = "Visibility", disabled = Off,
                args = ns.VisibilityArgs(function()
                    local db = DB()
                    db.visibility = db.visibility or {}
                    return db.visibility
                end, function()
                    TUI:UpdateKickTracker()
                    NotifyChange()
                end),
            },
        },
    }
end
