local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

local NotifyChange = ns.NotifyChange
local LSM = E.Libs and E.Libs.LSM

local function db() return E.db.thingsUI.damageMeter end
local function tdb() local d = db(); d.tui = d.tui or {}; return d.tui end
local function tset(k, v) tdb()[k] = v; if TUI.UpdateTUIMeter then TUI:UpdateTUIMeter() end; NotifyChange() end
local function notTUI() return (db().provider or "DETAILS") ~= "TUI" end

local function wcfg(i)
    local t = tdb()
    t.windows = t.windows or {}
    t.windows[i] = t.windows[i] or {}
    return t.windows[i]
end
local function noBorders()
    local t = tdb()
    return not t.windowBorder and t.headerBorder == false and t.windowDivider == false
end

local LAYOUT_COUNT = { ["1"] = 1, ["2"] = 2, ["1L2R"] = 3, ["2L1R"] = 3, ["4"] = 4 }
local function winCount() return LAYOUT_COUNT[tdb().layout or "2"] or 2 end

local function TimerToggle(i)
    return {
        order = 10 + i, type = "toggle", name = "Timer: Window " .. i,
        hidden = function() return winCount() < i end,
        get = function() return wcfg(i).showTimer end,
        set = function(_, v) wcfg(i).showTimer = v; if TUI.UpdateTUIMeter then TUI:UpdateTUIMeter() end; NotifyChange() end,
    }
end

function TUI:DamageMeterOptions()
    return {
        order = 60, type = "group", name = "Damage Meter", childGroups = "tab",
        args = {
            desc = {
                order = 1, type = "description", fontSize = "medium", width = "full",
                name = "If you want to use Mini Meter instead of Details.\n",
            },
            providerGroup = {
                order = 2, type = "group", name = "Provider", inline = true,
                args = {
                    provider = {
                        order = 1, type = "select", name = "Damage Meter", width = 1.2,
                        values = {
                            DETAILS = "Details!",
                            TUI     = "|cFF8080FFMini Meter|r",
                        },
                        sorting = { "DETAILS", "TUI" },
                        confirm = function(_, v)
                            if v == "TUI" then
                                return "Use the Mini Meter? Details! (if installed) is disabled and the UI reloads now."
                            end
                            return "Switch to Details!? The addon is re-enabled and the UI reloads now."
                        end,
                        get = function() return ns.GetDamageMeterProvider() end,
                        set = function(_, v)
                            if ns.SetDamageMeterProvider then ns.SetDamageMeterProvider(v) end
                            -- enable-state applies at load; the other meter keeps running otherwise
                            if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
                        end,
                    },
                    reload = {
                        order = 2, type = "execute", name = "Reload UI",
                        func = function() ReloadUI() end,
                    },
                },
            },
            detailsTab = {
                order = 5, type = "group", name = "Details!",
                hidden = function() return not notTUI() end,
                args = {
                    d = {
                        order = 1, type = "description", fontSize = "medium", width = "full",
                        name = "\n|cFFFFD200Details! is the selected damage meter - switch the provider above to configure the Mini Meter.|r",
                    },
                },
            },
            windowsTab = {
                order = 10, type = "group", name = "Windows",
                hidden = notTUI,
                args = {
                    testMode = {
                        order = 0.5, type = "toggle", name = "|cFF40FF40Test Mode|r",
                        get = function() return ns.TUIMeter and ns.TUIMeter.testMode end,
                        set = function(_, v)
                            if ns.TUIMeter then ns.TUIMeter.testMode = v; ns.TUIMeter.RefreshAll() end
                        end,
                    },
                    layout = {
                        order = 1, type = "select", name = "Window Layout", width = 1.4,
                        values = {
                            ["1"]    = "1 Window",
                            ["2"]    = "2 - Left & Right",
                            ["1L2R"] = "3 - 1 Left, 2 Right",
                            ["2L1R"] = "3 - 2 Left, 1 Right",
                            ["4"]    = "4 - 2x2 Grid",
                        },
                        sorting = { "1", "2", "1L2R", "2L1R", "4" },
                        get = function() return tdb().layout or "2" end,
                        set = function(_, v) tset("layout", v) end,
                    },
                    splitH = {
                        order = 1.1, type = "range", name = "Left Width", min = 0.15, max = 0.85, step = 0.01, isPercent = true,
                        hidden = function() return (tdb().layout or "2") == "1" end,
                        get = function() return tdb().splitH or 0.5 end,
                        set = function(_, v) tset("splitH", v) end,
                    },
                    splitV = {
                        order = 1.2, type = "range", name = "Top Height", min = 0.15, max = 0.85, step = 0.01, isPercent = true,
                        hidden = function()
                            local l = tdb().layout or "2"
                            return l == "1" or l == "2"
                        end,
                        get = function() return tdb().splitV or 0.5 end,
                        set = function(_, v) tset("splitV", v) end,
                    },
                    bgAlpha = {
                        order = 2, type = "range", name = "Background Opacity", min = 0, max = 1, step = 0.01, isPercent = true,
                        get = function() return tdb().bgAlpha or 0 end,
                        set = function(_, v) tset("bgAlpha", v) end,
                    },
                    windowBorder = {
                        order = 3, type = "toggle", name = "Window Border",
                        get = function() return tdb().windowBorder end,
                        set = function(_, v) tset("windowBorder", v) end,
                    },
                    windowDivider = {
                        order = 4, type = "toggle", name = "Window Divider",
                        get = function() return tdb().windowDivider ~= false end,
                        set = function(_, v) tset("windowDivider", v) end,
                    },
                    windowBorderSize = {
                        order = 5, type = "range", name = "Border Size", min = 1, max = 4, step = 1,
                        disabled = noBorders,
                        get = function() return tdb().windowBorderSize or 1 end,
                        set = function(_, v) tset("windowBorderSize", v) end,
                    },
                    windowBorderColor = {
                        order = 6, type = "color", name = "Border Color", hasAlpha = true,
                        disabled = noBorders,
                        get = function()
                            local c = tdb().windowBorderColor or {}
                            return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                        end,
                        set = function(_, r, g, b, a) tset("windowBorderColor", { r = r, g = g, b = b, a = a }) end,
                    },
                    windowGap = {
                        order = 7, type = "range", name = "Window Gap", min = -40, max = 40, step = 0.01, bigStep = 1,
                        get = function() return tdb().windowGap or -1 end,
                        set = function(_, v) tset("windowGap", v) end,
                    },
                    panelInset = {
                        order = 8, type = "range", name = "Panel Inset", min = -10, max = 20, step = 0.01, bigStep = 1,
                        disabled = function() return not E.db.thingsUI.rightChatAsBackground end,
                        get = function() return tdb().panelInset or 0 end,
                        set = function(_, v) tset("panelInset", v) end,
                    },
                    refreshRate = {
                        order = 9, type = "range", name = "Refresh Rate (s)", min = 0.1, max = 5, step = 0.1,
                        get = function() return tdb().refreshRate or 5 end,
                        set = function(_, v) tset("refreshRate", v) end,
                    },
                    menuSegments = {
                        order = 9.5, type = "range", name = "Menu Segments", min = 1, max = 50, step = 1,
                        get = function() return tdb().menuSegments or 20 end,
                        set = function(_, v) tset("menuSegments", v) end,
                    },
                    hint = {
                        order = 30, type = "description", fontSize = "medium", width = "full",
                        name = "\n|cFF888888Right-click a window for mode/segments/reset. Scroll to see everyone. Drag the title bar upwards to temporarily expand a docked window.|r",
                    },
                },
            },
            barsTab = {
                order = 20, type = "group", name = "Bars",
                hidden = notTUI,
                args = {
                    barsGroup = {
                        order = 1, type = "group", name = "Bars", inline = true,
                        args = {
                            autoFit = {
                                order = 0.5, type = "toggle", name = "Auto Fit Bars",
                                desc = "Bar Height becomes a target - each window stretches its bars to fill the space exactly.",
                                get = function() return tdb().autoFit ~= false end,
                                set = function(_, v) tset("autoFit", v) end,
                            },
                            barHeight = {
                                order = 1, type = "range", name = "Bar Height", min = 6, max = 40, step = 0.01, bigStep = 1,
                                get = function() return tdb().barHeight or 23.4 end,
                                set = function(_, v) tset("barHeight", v) end,
                            },
                            barSpacing = {
                                order = 2, type = "range", name = "Bar Spacing", min = -4, max = 10, step = 0.01, bigStep = 1,
                                get = function() return tdb().barSpacing or -1 end,
                                set = function(_, v) tset("barSpacing", v) end,
                            },
                            barTexture = {
                                order = 3, type = "select", name = "Bar Texture", dialogControl = "LSM30_Statusbar",
                                values = LSM and LSM:HashTable("statusbar") or {},
                                get = function() return tdb().barTexture ~= "" and tdb().barTexture or nil end,
                                set = function(_, v) tset("barTexture", v) end,
                            },
                            classColor = {
                                order = 4, type = "toggle", name = "Class Colors",
                                get = function() return tdb().classColor ~= false end,
                                set = function(_, v) tset("classColor", v) end,
                            },
                            nsrtNicknames = {
                                order = 4.5, type = "toggle", name = "NSRT Nicknames",
                                desc = "Show Northern Sky Raid Tools nicknames instead of character names.",
                                hidden = function() return _G.NSAPI == nil end,
                                get = function() return tdb().nsrtNicknames ~= false end,
                                set = function(_, v)
                                    if ns.TUIMeter and ns.TUIMeter.InvalidateNicknames then
                                        ns.TUIMeter.InvalidateNicknames()
                                    end
                                    tset("nsrtNicknames", v)
                                end,
                            },
                            barBgAlpha = {
                                order = 5, type = "range", name = "Bar Background", min = 0, max = 1, step = 0.01, isPercent = true,
                                get = function() return tdb().barBgAlpha or 0 end,
                                set = function(_, v) tset("barBgAlpha", v) end,
                            },
                            barBorder = {
                                order = 6, type = "toggle", name = "Bar Border",
                                desc = "Uses the Icon border size and color.",
                                get = function() return tdb().barBorder ~= false end,
                                set = function(_, v) tset("barBorder", v) end,
                            },
                        },
                    },
                    textGroup = {
                        order = 10, type = "group", name = "Text", inline = true,
                        args = {
                            font = {
                                order = 1, type = "select", name = "Font", dialogControl = "LSM30_Font",
                                values = ns.FontValues,
                                get = function() return tdb().font end,
                                set = function(_, v) tset("font", v) end,
                            },
                            fontSize = {
                                order = 2, type = "range", name = "Name Size", min = 6, max = 30, step = 1,
                                get = function() return tdb().fontSize or 12 end,
                                set = function(_, v) tset("fontSize", v) end,
                            },
                            valueFontSize = {
                                order = 3, type = "range", name = "Value Size", min = 6, max = 30, step = 1,
                                get = function() return tdb().valueFontSize or 12 end,
                                set = function(_, v) tset("valueFontSize", v) end,
                            },
                            fontOutline = {
                                order = 4, type = "select", name = "Outline",
                                values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                                get = function() return tdb().fontOutline or "OUTLINE" end,
                                set = function(_, v) tset("fontOutline", v) end,
                            },
                            fontShadow = {
                                order = 5, type = "toggle", name = "Shadow",
                                get = function() return tdb().fontShadow end,
                                set = function(_, v) tset("fontShadow", v) end,
                            },
                            numberFormat = {
                                order = 6, type = "select", name = "Numbers",
                                values = { both = "Damage (DPS)", total = "Damage", persec = "DPS" },
                                sorting = { "both", "total", "persec" },
                                get = function() return tdb().numberFormat or "both" end,
                                set = function(_, v) tset("numberFormat", v) end,
                            },
                            showRank = {
                                order = 7, type = "toggle", name = "Rank Numbers",
                                get = function() return tdb().showRank ~= false end,
                                set = function(_, v) tset("showRank", v) end,
                            },
                        },
                    },
                    iconGroup = {
                        order = 20, type = "group", name = "Icon", inline = true,
                        args = {
                            iconStyle = {
                                order = 1, type = "select", name = "Icon",
                                values = { spec = "Spec Icon", class = "Class Icon", none = "None" },
                                sorting = { "spec", "class", "none" },
                                get = function() return tdb().iconStyle or "spec" end,
                                set = function(_, v) tset("iconStyle", v) end,
                            },
                            iconZoom = {
                                order = 2, type = "range", name = "Icon Zoom", min = 0, max = 0.3, step = 0.01,
                                get = function() return tdb().iconZoom or 0.05 end,
                                set = function(_, v) tset("iconZoom", v) end,
                            },
                            iconGap = {
                                order = 3, type = "range", name = "Icon Gap", min = -2, max = 12, step = 0.5,
                                get = function() return tdb().iconGap or -1 end,
                                set = function(_, v) tset("iconGap", v) end,
                            },
                            iconBorder = {
                                order = 4, type = "toggle", name = "Icon Border",
                                get = function() return tdb().iconBorder end,
                                set = function(_, v) tset("iconBorder", v) end,
                            },
                            iconBorderSize = {
                                order = 5, type = "range", name = "Border Size", min = 1, max = 4, step = 1,
                                get = function() return tdb().iconBorderSize or 1 end,
                                set = function(_, v) tset("iconBorderSize", v) end,
                            },
                            iconBorderColor = {
                                order = 6, type = "color", name = "Border Color", hasAlpha = true,
                                get = function()
                                    local c = tdb().iconBorderColor or {}
                                    return c.r or 0, c.g or 0, c.b or 0, c.a or 1
                                end,
                                set = function(_, r, g, b, a) tset("iconBorderColor", { r = r, g = g, b = b, a = a }) end,
                            },
                        },
                    },
                },
            },
            titleTab = {
                order = 30, type = "group", name = "Title Bar",
                hidden = notTUI,
                args = {
                    headerHeight = {
                        order = 1, type = "range", name = "Height", min = 12, max = 32, step = 0.01, bigStep = 1,
                        get = function() return tdb().headerHeight or 25 end,
                        set = function(_, v) tset("headerHeight", v) end,
                    },
                    headerFontSize = {
                        order = 2, type = "range", name = "Text Size", min = 6, max = 24, step = 1,
                        get = function() return tdb().headerFontSize or 13 end,
                        set = function(_, v) tset("headerFontSize", v) end,
                    },
                    contentPad = {
                        order = 3, type = "range", name = "Bar Gap", min = -4, max = 10, step = 0.01, bigStep = 1,
                        get = function() return tdb().contentPad or -1 end,
                        set = function(_, v) tset("contentPad", v) end,
                    },
                    headerBorder = {
                        order = 4, type = "toggle", name = "Title Bar Border",
                        get = function() return tdb().headerBorder ~= false end,
                        set = function(_, v) tset("headerBorder", v) end,
                    },
                    sessionTag = {
                        order = 4.5, type = "toggle", name = "Session Tag [C]/[O]",
                        get = function() return tdb().sessionTag ~= false end,
                        set = function(_, v) tset("sessionTag", v) end,
                    },
                    timer1 = TimerToggle(1),
                    timer2 = TimerToggle(2),
                    timer3 = TimerToggle(3),
                    timer4 = TimerToggle(4),
                },
            },
        },
    }
end
