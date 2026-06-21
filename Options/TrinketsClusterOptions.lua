local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

local pendingItemID = ""

local function GetEquippedTrinketInfo(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return nil end
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return { id = itemID, name = name or ("Item " .. itemID), icon = icon }
end

local function GetBlacklist()
    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
    if not db then return nil end
    db.blacklist = db.blacklist or {}
    return db.blacklist
end

local function AddToBlacklist(itemID)
    local bl = GetBlacklist(); if not bl or not itemID then return end
    bl[itemID] = true
    if TUI.UpdateTrinketsCDM then TUI:UpdateTrinketsCDM() end
    NotifyChange()
end

local function RemoveFromBlacklist(itemID)
    local bl = GetBlacklist(); if not bl or not itemID then return end
    bl[itemID] = nil
    if TUI.UpdateTrinketsCDM then TUI:UpdateTrinketsCDM() end
    NotifyChange()
end

-- Returns a sorted list of {id, name} for currently blacklisted items.
local function GetBlacklistEntries()
    local bl = GetBlacklist() or {}
    local out = {}
    for id in pairs(bl) do
        out[#out + 1] = { id = id, name = (C_Item.GetItemInfo(id)) or ("Item " .. id) }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function TUI:TrinketBlacklistOptions()
    local args = {
        desc = {
            order = 1, type = "description",
            name = "Hide specific trinkets from the bar by item ID. Hidden trinkets still get cooldowns processed in the background - they're just not shown.\n\n",
        },
        addItemID = {
            order = 10, type = "input", name = "Item ID",
            get = function() return pendingItemID end,
            set = function(_, v)
                v = (v or ""):gsub("%s", "")
                pendingItemID = v
            end,
        },
        addButton = {
            order = 11, type = "execute", name = "Add",
            disabled = function() return tonumber(pendingItemID) == nil end,
            func = function()
                local id = tonumber(pendingItemID)
                if id then AddToBlacklist(id); pendingItemID = "" end
            end,
        },
        quickAddHeader = {
            order = 19, type = "header", name = "Currently Equipped",
        },
        quickAdd13 = {
            order = 20, type = "execute", width = "double",
            name = function()
                local t = GetEquippedTrinketInfo(13)
                if not t then return "|cFFFFFF00Trinket 13 (empty)|r" end
                local bl = GetBlacklist()
                if bl and bl[t.id] then
                    return ("|cFF888888Trinket 13: %s (blacklisted)|r"):format(t.name)
                end
                return ("|cFFA20000Blacklist Trinket 13|r :|cFFFFFF00 %s|r"):format(t.name)
            end,
            disabled = function()
                local t = GetEquippedTrinketInfo(13); if not t then return true end
                local bl = GetBlacklist()
                return bl and bl[t.id] or false
            end,
            func = function()
                local t = GetEquippedTrinketInfo(13)
                if t then AddToBlacklist(t.id) end
            end,
        },
        quickAdd14 = {
            order = 21, type = "execute", width = "double",
            name = function()
                local t = GetEquippedTrinketInfo(14)
                if not t then return "|cFF00FF00Trinket 14 (empty)|r" end
                local bl = GetBlacklist()
                if bl and bl[t.id] then
                    return ("|cFF888888Trinket 14: %s (blacklisted)|r"):format(t.name)
                end
                return ("|cFFA20000Blacklist Trinket 14|r :|cFF00FF00 %s|r"):format(t.name)
            end,
            disabled = function()
                local t = GetEquippedTrinketInfo(14); if not t then return true end
                local bl = GetBlacklist()
                return bl and bl[t.id] or false
            end,
            func = function()
                local t = GetEquippedTrinketInfo(14)
                if t then AddToBlacklist(t.id) end
            end,
        },
        listHeader = {
            order = 29, type = "header", name = "Blacklisted Items",
        },
        emptyDesc = {
            order = 30, type = "description",
            name = "|cFF888888No items blacklisted.|r",
            hidden = function() return #GetBlacklistEntries() > 0 end,
        },
    }

    for i = 1, 12 do
        local idx = i
        local function entry() return GetBlacklistEntries()[idx] end
        args["row" .. i] = {
            order = 100 + i, type = "group", inline = true,
            name = "",
            hidden = function() return entry() == nil end,
            args = {
                label = {
                    order = 1, type = "description", width = 2.5, fontSize = "medium",
                    name = function()
                        local e = entry(); if not e then return "" end
                        return ("|cFFFFD200%s|r |cFF888888(%d)|r"):format(e.name, e.id)
                    end,
                },
                remove = {
                    order = 2, type = "execute", name = "Remove", width = 0.7,
                    func = function()
                        local e = entry(); if e then RemoveFromBlacklist(e.id) end
                    end,
                },
            },
        }
    end

    return {
        order = 3,
        type = "group",
        name = "Trinket Blacklist",
        inline = true,
        hidden = function() return not E.db.thingsUI.trinketsCDM.enabled end,
        args = args,
    }
end

function TUI:ClusterPositioningSubTab()
    return {
                order = 1,
                type = "group",
                name = "Cluster Positioning",
                childGroups = "tree",
                args = {
                    header = {
                        order = 1,
                        type = "header",
                        name = "Cluster Positioning",
                    },
                    description = {
                        order = 2,
                        type = "description",
                        name = "Anchor ElvUI unit frames to the Essential Cooldown Viewer.\n\nWhen enabled:\n• ElvUF_Player anchors to the left\n• ElvUF_Target anchors to the right\n• ElvUF_TargetTarget anchors to Target\n• ElvUF_Target_CastBar anchors below Target\n\n|cFFFF4040Warning:|r This overrides ElvUI's unit frame positioning, it will look weird in /emove.\n\n",
                    },
                    enabled = {
                        order = 3,
                        type = "toggle",
                        name = "Enable Cluster Positioning",
                        width = "full",
                        get = function() return E.db.thingsUI.clusterPositioning.enabled end,
                        set = function(_, value)
                            E.db.thingsUI.clusterPositioning.enabled = value
                            TUI:UpdateClusterPositioning()
                        end,
                    },
                    recalculate = {
                        order = 4,
                        type = "execute",
                        name = "Recalculate Now",
                        func = function() TUI:RecalculateCluster() end,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                    },
                    debugGroup = {
                        order = 5,
                        type = "group",
                        name = "Debug Info",
                        inline = true,
                        args = {
                            currentLayout = {
                                order = 1,
                                type = "description",
                                name = function()
                                    local essentialCount = 0
                                    if EssentialCooldownViewer then
                                        for _, child in ipairs({ EssentialCooldownViewer:GetChildren() }) do
                                            if child and child:IsShown() then essentialCount = essentialCount + 1 end
                                        end
                                    end
                                    local utilityCount = 0
                                    if UtilityCooldownViewer then
                                        for _, child in ipairs({ UtilityCooldownViewer:GetChildren() }) do
                                            if child and child:IsShown() then utilityCount = utilityCount + 1 end
                                        end
                                    end

                                    local TR = ns.TrinketsCDM
                                    local trinketCount = (TR and TR.GetExtraEssentialCount and TR.GetExtraEssentialCount()) or 0
                                    if trinketCount > 0 then
                                        local key = (TR.GetTrinketAttachKey and TR.GetTrinketAttachKey()) or "essential"
                                        if key == "utility" then
                                            utilityCount = utilityCount + trinketCount
                                        else
                                            essentialCount = essentialCount + trinketCount
                                        end
                                    end
                                    return string.format("|cFFFFFF00Essential Icons:|r %d\n|cFFFFFF00Utility Icons:|r %d", essentialCount, utilityCount)
                                end,
                            },
                            debugInfo = {
                                order = 2,
                                type = "description",
                                name = "\nIf Utility Icons exceed Essential Icons by the number you set in Icon Settings -> Utility Threshold, UnitFrames will move. \n\nUseful if you have way more Utility than Essential and it starts to overlap.\n",
                            },
                        },
                    },

                    -----------------------------------------
                    -- ICON SETTINGS
                    -----------------------------------------
                    iconGroup = {
                        order = 10,
                        type = "group",
                        name = "Icon Settings",
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                        args = {
                            iconSizeInfo = {
                                order = 1, type = "description",
                                name = "|cFF888888Essential and Utility icon widths are read from the CDM Icons tabs (Essential / Utility -> Icon Size).|r\n",
                            },
                            accountForUtility = {
                                order = 3,
                                type = "toggle",
                                name = "Account for Utility Overflow",
                                get = function() return E.db.thingsUI.clusterPositioning.accountForUtility end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.accountForUtility = value
                                    TUI:QueueClusterUpdate()
                                end,
                            },
                            utilityThreshold = {
                                order = 4,
                                type = "range",
                                name = "Utility Threshold",
                                min = 1, max = 10, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.utilityThreshold end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.utilityThreshold = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                            },
                            utilityOverflowOffset = {
                                order = 5,
                                type = "range",
                                name = "Overflow Offset",
                                min = 10, max = 200, step = 5,
                                get = function() return E.db.thingsUI.clusterPositioning.utilityOverflowOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.utilityOverflowOffset = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                            },
                        },
                    },

                    -----------------------------------------
                    -- UnitFrame Settings
                    -----------------------------------------
                    elvuiFramesGroup = {
                        order = 20,
                        type = "group",
                        name = "UnitFrame Settings",
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                        args = {
                            playerTargetGroup = {
                                order = 1,
                                type = "group",
                                name = "Player / Target Frame",
                                inline = true,
                                args = {
                                    playerEnabled = {
                                        order = 1,
                                        type = "toggle",
                                        name = "Position Player Frame",
                                        get = function() return E.db.thingsUI.clusterPositioning.playerFrame.enabled end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.playerFrame.enabled = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                    },
                                    targetEnabled = {
                                        order = 2,
                                        type = "toggle",
                                        name = "Position Target Frame",
                                        get = function() return E.db.thingsUI.clusterPositioning.targetFrame.enabled end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetFrame.enabled = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                    },
                                    frameGap = {
                                        order = 3,
                                        type = "range",
                                        name = "Frame Gap",
                                        min = -50, max = 50, step = 0.01, bigStep = 1,
                                        get = function() return E.db.thingsUI.clusterPositioning.frameGap end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.frameGap = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                    },
                                },
                            },
                            totGroup = {
                                order = 2,
                                type = "group",
                                name = "Target of Target Frame",
                                inline = true,
                                args = {
                                    totEnabled = {
                                        order = 1,
                                        type = "toggle",
                                        name = "Position TargetTarget Frame",
                                        get = function() return E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                    },
                                    totGap = {
                                        order = 2,
                                        type = "range",
                                        name = "ToT Gap",
                                        min = -50, max = 50, step = 0.01, bigStep = 1,
                                        get = function() return E.db.thingsUI.clusterPositioning.targetTargetFrame.gap end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetTargetFrame.gap = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled end,
                                    },
                                },
                            },
                            castBarGroup = {
                                order = 3,
                                type = "group",
                                name = "Target Cast Bar",
                                inline = true,
                                args = {
                                    castBarEnabled = {
                                        order = 1,
                                        type = "toggle",
                                        name = "Position Target CastBar",
                                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetCastBar.enabled = value
                                            TUI:UpdateClusterPositioning()
                                        end,
                                    },
                                    castBarGap = {
                                        order = 2,
                                        type = "range",
                                        name = "CastBar Y Gap",
                                        min = -50, max = 50, step = 0.01, bigStep = 1,
                                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.gap end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetCastBar.gap = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                                    },
                                    castBarXOffset = {
                                        order = 3,
                                        type = "range",
                                        name = "CastBar X Offset",
                                        min = -100, max = 100, step = 0.01, bigStep = 1,
                                        get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.xOffset end,
                                        set = function(_, value)
                                            E.db.thingsUI.clusterPositioning.targetCastBar.xOffset = value
                                            TUI:QueueClusterUpdate()
                                        end,
                                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                                    },
                                },
                            },
                        },
                    },

                },
            }
end

function TUI:TrinketsOptions()
    local function tdb() return E.db.thingsUI.trinketsCDM end
    -- Migrate old NHT/FHT + nhtSide profiles so the selects show the right values.
    if ns.TrinketsCDM and ns.TrinketsCDM.MigrateDB then ns.TrinketsCDM.MigrateDB(tdb()) end
    local function set(k, v) tdb()[k] = v; TUI:UpdateTrinketsCDM(); NotifyChange() end
    local function isEmbedded() return (tdb().mode or "EMBEDDED") == "EMBEDDED" end
    local function isBar()      return (tdb().mode or "EMBEDDED") == "BAR" end
    local function isGrouped()  return (tdb().mode or "EMBEDDED") == "GROUP" end
    local SIDES = { TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right" }

    -- Trinket Bar (mode == "BAR") helpers.
    local function bdb() return tdb().bar end
    local function bset(k, v) bdb()[k] = v; TUI:UpdateTrinketsCDM(); NotifyChange() end
    local function tset(k, v) bdb().text[k] = v; TUI:UpdateTrinketsCDM(); NotifyChange() end
    local function isUIParent() return (bdb().anchorFrame or "UIParent") == "UIParent" end
    local function noCD() return not bdb().text.showCooldown end
    return {
        order = 2, type = "group", name = "Trinkets",
        args = {
            desc = {
                order = 0, type = "description",
                name = "Show trinket cooldowns embedded in a CDM row, as a standalone bar, or folded into a Custom Group. \n\n",
            },
            enabled = {
                order = 1, type = "toggle", name = "Enable", width = "full",
                get = function() return tdb().enabled end,
                set = function(_, v) set("enabled", v) end,
            },
            includePassive = {
                order = 2, type = "toggle", name = "Include Passive Trinkets",
                hidden = function() return not tdb().enabled end,
                get = function() return tdb().includePassive end,
                set = function(_, v) set("includePassive", v) end,
            },
            modeGroup = {
                order = 10, type = "group", inline = true, name = "Mode",
                hidden = function() return not tdb().enabled end,
                args = {
                    mode = {
                        order = 1, type = "select", name = "Mode",
                        values = { EMBEDDED = "Embedded", BAR = "Trinket Bar", GROUP = "Custom Group" },
                        sorting = { "EMBEDDED", "BAR", "GROUP" },
                        get = function() return tdb().mode or "EMBEDDED" end,
                        set = function(_, v) set("mode", v) end,
                    },
                },
            },
            groupGroup = {
                order = 15, type = "group", inline = true, name = "Custom Group",
                hidden = function() return not tdb().enabled or not isGrouped() end,
                args = {
                    group = {
                        order = 1, type = "select", name = "Group",
                        values = function()
                            local v = {}
                            if ns.CustomGroups and ns.CustomGroups.GetGroups then
                                for _, g in ipairs(ns.CustomGroups.GetGroups()) do v[g.id] = g.name or ("Group " .. g.id) end
                            end
                            return v
                        end,
                        sorting = function()
                            local sorted = {}
                            if ns.CustomGroups and ns.CustomGroups.GetGroups then
                                for _, g in ipairs(ns.CustomGroups.GetGroups()) do sorted[#sorted + 1] = g end
                            end
                            table.sort(sorted, function(a, b) return (a.name or "") < (b.name or "") end)
                            local order = {}
                            for _, g in ipairs(sorted) do order[#order + 1] = g.id end
                            return order
                        end,
                        get = function() return tdb().group end,
                        set = function(_, v) set("group", v) end,
                    },
                    position = {
                        order = 2, type = "select", name = "Position",
                        values = { START = "First", END = "Last" },
                        sorting = { "START", "END" },
                        get = function() return tdb().groupPosition or "END" end,
                        set = function(_, v) set("groupPosition", v) end,
                    },
                    gotoGroup = {
                        order = 3, type = "execute", name = "Go to Custom Group",
                        hidden = function() return not tdb().group end,
                        func = function()
                            local idx
                            if ns.CustomGroups and ns.CustomGroups.GetGroups then
                                for i, g in ipairs(ns.CustomGroups.GetGroups()) do
                                    if g.id == tdb().group then idx = i; break end
                                end
                            end
                            E:ToggleOptions(idx and ("thingsUI,modulesTab,customGroups,group" .. idx)
                                or "thingsUI,modulesTab,customGroups")
                        end,
                    },
                },
            },
            embeddedGroup = {
                order = 20, type = "group", inline = true, name = "Embedded Settings",
                hidden = function() return not tdb().enabled or not isEmbedded() end,
                args = {
                    attach = {
                        order = 1, type = "select", name = "Attach To",
                        values = {
                            ESSENTIAL = "Essential",
                            UTILITY   = "Utility",
                            DYNAMIC   = "Dynamic (Essential -> Utility on overflow)",
                        },
                        get = function() return tdb().attach end,
                        set = function(_, v) set("attach", v) end,
                    },
                    dynamicThreshold = {
                        order = 2, type = "range", name = "Dynamic Threshold",
                        min = 1, max = 20, step = 1,
                        hidden = function() return tdb().attach ~= "DYNAMIC" end,
                        get = function() return tdb().dynamicThreshold end,
                        set = function(_, v) set("dynamicThreshold", v) end,
                    },
                    sideHeader = {
                        order = 9, type = "header", name = "Side",
                    },
                    essentialSide = {
                        order = 10, type = "select", name = "When in Essential",
                        values = SIDES,
                        hidden = function() return tdb().attach == "UTILITY" end,
                        get = function() return tdb().essentialSide or "RIGHT" end,
                        set = function(_, v) set("essentialSide", v) end,
                    },
                    utilitySide = {
                        order = 11, type = "select", name = "When in Utility",
                        values = SIDES,
                        hidden = function() return tdb().attach == "ESSENTIAL" end,
                        get = function() return tdb().utilitySide or "RIGHT" end,
                        set = function(_, v) set("utilitySide", v) end,
                    },
                    sizeHint = {
                        order = 20, type = "description", fontSize = "medium",
                        name = "\n|cFF888888Trinkets inherit icon size and spacing from the viewer they're embedded in (set under CDM -> Essential / Utility), and follow its growth direction.|r",
                    },
                },
            },
            barGroup = {
                order = 30, type = "group", inline = true, name = "Trinket Bar",
                hidden = function() return not tdb().enabled or not isBar() end,
                args = {
                    moveHint = {
                        order = 0, type = "description",
                        name = "A standalone bar. Move it via |cFFFFD200/emove|r (\"thingsUI Trinket Bar\") when Anchor To = UIParent, or snap it to a frame below.\n",
                    },
                    -- Sizing
                    sizeHeader = { order = 1, type = "header", name = "Sizing" },
                    iconSize = {
                        order = 2, type = "range", name = "Icon Size", min = 8, max = 64, step = 1,
                        get = function() return bdb().iconSize end,
                        set = function(_, v) bset("iconSize", v) end,
                    },
                    spacing = {
                        order = 3, type = "range", name = "Spacing", min = -10, max = 10, step = 0.01, bigStep = 1,
                        get = function() return bdb().spacing end,
                        set = function(_, v) bset("spacing", v) end,
                    },
                    growth = {
                        order = 4, type = "select", name = "Growth Direction", values = ns.GROWTH.DIRECTIONAL, sorting = ns.GROWTH.DIRECTIONAL_ORDER,
                        get = function() return bdb().growth end,
                        set = function(_, v) bset("growth", v) end,
                    },
                    -- Anchor
                    anchorHeader = { order = 10, type = "header", name = "Anchor" },
                    anchorFrame = {
                        order = 11, type = "select", name = "Anchor To",
                        values = ns.ANCHORS.FilteredValues, sorting = ns.ANCHORS.FilteredOrder,
                        get = function() return bdb().anchorFrame or "UIParent" end,
                        set = function(_, v) bset("anchorFrame", v) end,
                    },
                    anchorPoint = {
                        order = 12, type = "select", name = "Anchor From (self)",
                        values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                        hidden = isUIParent,
                        get = function() return bdb().anchorPoint end,
                        set = function(_, v) bset("anchorPoint", v) end,
                    },
                    anchorRelativePoint = {
                        order = 13, type = "select", name = "Anchor To (target)",
                        values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                        hidden = isUIParent,
                        get = function() return bdb().anchorRelativePoint end,
                        set = function(_, v) bset("anchorRelativePoint", v) end,
                    },
                    anchorXOffset = {
                        order = 14, type = "range", name = "X Offset", min = -400, max = 400, step = 1,
                        hidden = isUIParent,
                        get = function() return bdb().anchorXOffset end,
                        set = function(_, v) bset("anchorXOffset", v) end,
                    },
                    anchorYOffset = {
                        order = 15, type = "range", name = "Y Offset", min = -400, max = 400, step = 1,
                        hidden = isUIParent,
                        get = function() return bdb().anchorYOffset end,
                        set = function(_, v) bset("anchorYOffset", v) end,
                    },
                    -- Cooldown text
                    textHeader = { order = 20, type = "header", name = "Cooldown Text" },
                    showCooldown = {
                        order = 21, type = "toggle", name = "Show Cooldown Text", width = "full",
                        get = function() return bdb().text.showCooldown end,
                        set = function(_, v) tset("showCooldown", v) end,
                    },
                    cdFont = {
                        order = 22, type = "select", dialogControl = "LSM30_Font",
                        name = "Font", values = ns.FontValues, disabled = noCD,
                        get = function() return bdb().text.cooldownFont end,
                        set = function(_, v) tset("cooldownFont", v) end,
                    },
                    cdSize = {
                        order = 23, type = "range", name = "Font Size", min = 6, max = 40, step = 1,
                        disabled = noCD,
                        get = function() return bdb().text.cooldownFontSize end,
                        set = function(_, v) tset("cooldownFontSize", v) end,
                    },
                    cdOutline = {
                        order = 24, type = "select", name = "Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                        disabled = noCD,
                        get = function() return bdb().text.cooldownFontOutline end,
                        set = function(_, v) tset("cooldownFontOutline", v) end,
                    },
                    cdColor = {
                        order = 25, type = "color", name = "Color", disabled = noCD,
                        get = function()
                            local c = bdb().text.cooldownColor or {}
                            return c.r or 1, c.g or 1, c.b or 1
                        end,
                        set = function(_, r, g, b)
                            local c = bdb().text.cooldownColor or {}
                            c.r, c.g, c.b = r, g, b
                            bdb().text.cooldownColor = c
                            TUI:UpdateTrinketsCDM(); NotifyChange()
                        end,
                    },
                    cdPoint = {
                        order = 26, type = "select", name = "Text Position",
                        values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER, disabled = noCD,
                        get = function() return bdb().text.cooldownPoint end,
                        set = function(_, v) tset("cooldownPoint", v) end,
                    },
                    cdX = {
                        order = 27, type = "range", name = "Text X", min = -50, max = 50, step = 1,
                        disabled = noCD,
                        get = function() return bdb().text.cooldownXOffset end,
                        set = function(_, v) tset("cooldownXOffset", v) end,
                    },
                    cdY = {
                        order = 28, type = "range", name = "Text Y", min = -50, max = 50, step = 1,
                        disabled = noCD,
                        get = function() return bdb().text.cooldownYOffset end,
                        set = function(_, v) tset("cooldownYOffset", v) end,
                    },
                },
            },
            blacklistGroup = TUI:TrinketBlacklistOptions(),
        },
    }
end
