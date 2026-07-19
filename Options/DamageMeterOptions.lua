local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

local NotifyChange = ns.NotifyChange
local LSM = E.Libs and E.Libs.LSM

local function db() return E.db.thingsUI.damageMeter end
local function set(k, v) db()[k] = v; TUI:UpdateDamageMeter(); NotifyChange() end
local function isDetails() return (db().provider or "DETAILS") ~= "BLIZZARD" end

function TUI:DamageMeterOptions()
    return {
        order = 60, type = "group", name = "Damage Meter",
        args = {
            desc = {
                order = 1, type = "description", fontSize = "medium", width = "full",
                name = "Styles Blizzard's built-in Damage Meter (12.1+). Pick the meter under |cFFFFFFFFElvUI QoL -> Damage Meter|r; with the Ingame meter + Right Chat Backdrop enabled, window 1 & 2 dock side by side inside the right chat panel.\n",
            },
            detailsHint = {
                order = 2, type = "description", fontSize = "medium", width = "full",
                name = "|cFFFFD200Details! is the selected damage meter - these options apply when the Ingame Damage Meter is selected.|r\n",
                hidden = function() return not isDetails() end,
            },
            blizzHint = {
                order = 3, type = "description", fontSize = "medium", width = "full",
                name = "|cFF888888Frame size, bar height, padding, style and numbers live in Blizzard's Edit Mode settings for the meter (writing those from an addon taints the meter).|r\n",
                hidden = isDetails,
            },
            styleBars = {
                order = 5, type = "toggle", name = "Style Bars & Text", width = 1.4,
                disabled = isDetails,
                get = function() return db().styleBars end,
                set = function(_, v) set("styleBars", v) end,
            },
            fontGroup = {
                order = 10, type = "group", name = "Text", inline = true,
                disabled = function() return isDetails() or not db().styleBars end,
                args = {
                    font = {
                        order = 1, type = "select", name = "Font", dialogControl = "LSM30_Font",
                        values = ns.FontValues,
                        get = function() return db().font end,
                        set = function(_, v) set("font", v) end,
                    },
                    fontSize = {
                        order = 2, type = "range", name = "Name Size", min = 6, max = 30, step = 1,
                        get = function() return db().fontSize end,
                        set = function(_, v) set("fontSize", v) end,
                    },
                    valueFontSize = {
                        order = 3, type = "range", name = "Value Size", min = 6, max = 30, step = 1,
                        get = function() return db().valueFontSize end,
                        set = function(_, v) set("valueFontSize", v) end,
                    },
                    fontOutline = {
                        order = 4, type = "select", name = "Outline",
                        values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                        get = function() return db().fontOutline end,
                        set = function(_, v) set("fontOutline", v) end,
                    },
                    fontShadow = {
                        order = 5, type = "toggle", name = "Shadow",
                        get = function() return db().fontShadow end,
                        set = function(_, v) set("fontShadow", v) end,
                    },
                    headerFontSize = {
                        order = 6, type = "range", name = "Title Bar Text Size", min = 6, max = 30, step = 1,
                        get = function() return db().headerFontSize end,
                        set = function(_, v) set("headerFontSize", v) end,
                    },
                },
            },
            barGroup = {
                order = 20, type = "group", name = "Bars", inline = true,
                disabled = function() return isDetails() or not db().styleBars end,
                args = {
                    barTexture = {
                        order = 1, type = "select", name = "Bar Texture", dialogControl = "LSM30_Statusbar",
                        values = LSM and LSM:HashTable("statusbar") or {},
                        get = function() return db().barTexture ~= "" and db().barTexture or nil end,
                        set = function(_, v) set("barTexture", v) end,
                    },
                    barTextureReset = {
                        order = 2, type = "execute", name = "Default Texture", width = 0.8,
                        func = function() set("barTexture", "") end,
                    },
                    barLayout = {
                        order = 3, type = "toggle", name = "Manage Icon Gap", width = 1.2,
                        desc = "Re-anchors the bar next to the spec icon with your gap. Off = Blizzard's layout.",
                        get = function() return db().barLayout end,
                        set = function(_, v) set("barLayout", v) end,
                    },
                    iconGap = {
                        order = 4, type = "range", name = "Icon Gap", min = -4, max = 20, step = 0.5,
                        disabled = function() return isDetails() or not db().styleBars or not db().barLayout end,
                        get = function() return db().iconGap end,
                        set = function(_, v) set("iconGap", v) end,
                    },
                },
            },
            iconGroup = {
                order = 30, type = "group", name = "Spec Icon Border", inline = true,
                disabled = function() return isDetails() or not db().styleBars end,
                args = {
                    iconBorder = {
                        order = 1, type = "toggle", name = "Show Border",
                        get = function() return db().iconBorder end,
                        set = function(_, v) set("iconBorder", v) end,
                    },
                    iconBorderSize = {
                        order = 2, type = "range", name = "Size", min = 1, max = 6, step = 1,
                        disabled = function() return isDetails() or not db().iconBorder end,
                        get = function() return db().iconBorderSize end,
                        set = function(_, v) set("iconBorderSize", v) end,
                    },
                    iconBorderColor = {
                        order = 3, type = "color", name = "Color", hasAlpha = true,
                        disabled = function() return isDetails() or not db().iconBorder end,
                        get = function()
                            local c = db().iconBorderColor or {}
                            return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                        end,
                        set = function(_, r, g, b, a) set("iconBorderColor", { r = r, g = g, b = b, a = a }) end,
                    },
                },
            },
            windowGroup = {
                order = 40, type = "group", name = "Windows", inline = true,
                disabled = isDetails,
                args = {
                    windowGap = {
                        order = 1, type = "range", name = "Window Gap", min = 0, max = 40, step = 1,
                        desc = "Gap between window 1 and 2 when docked in the right chat panel.",
                        get = function() return db().windowGap end,
                        set = function(_, v) set("windowGap", v) end,
                    },
                    hideGearMenu = {
                        order = 2, type = "toggle", name = "Hide Gear Menu", width = 1.2,
                        get = function() return db().hideGearMenu end,
                        set = function(_, v) set("hideGearMenu", v) end,
                    },
                },
            },
        },
    }
end
