local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

-- Pending text in the "Add Item ID" input box. Module-local so it survives
-- AceConfig refreshes between keystroke and Add click.
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
            name = "Hide specific trinkets from the BCDM trinket bar so they're excluded from the layout (Essential width / Utility shift / FHT overflow). Useful for trinkets that aren't actual on-use abilities you want tracked.\n\n",
        },
        addItemID = {
            order = 10, type = "input", name = "Item ID",
            desc = "Numeric item ID. Find it via /dump GetInventoryItemID('player', 13) or 14.",
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
                return ("|cFFFFFF00Blacklist Trinket 13: %s|r"):format(t.name)
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
                return ("|cFF00FF00Blacklist Trinket 14: %s|r"):format(t.name)
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

    -- Pre-allocate a fixed pool of rows; bind each to its current entry via
    -- an index lookup. Show only rows that have a corresponding entry.
    -- 12 is plenty — anyone past that has bigger problems than 13/14 trinket bloat.
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

function TUI:BCDMElvUIOptions()
    return {
        order = 30,
        type = "group",
        name = "BCDM + ElvUI",
        childGroups = "tab",
        args = {
            clusterPositioningSubTab = {
                order = 1,
                type = "group",
                name = "Cluster Positioning",
                childGroups = "tree",
                args = {
                    header = {
                        order = 1,
                        type = "header",
                        name = "Dynamic BCDM + ElvUI Positioning",
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
                        desc = "Anchor unit frames to the Essential Cooldown Viewer.",
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
                        desc = "Manually trigger repositioning.",
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
                            essentialIconWidth = {
                                order = 1,
                                type = "range",
                                name = "Essential Icon Width",
                                desc = "Width of Essential Cooldown icons.",
                                min = 20, max = 80, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.essentialIconWidth end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.essentialIconWidth = value
                                    TUI:QueueClusterUpdate()
                                end,
                            },
                            utilityIconWidth = {
                                order = 2,
                                type = "range",
                                name = "Utility Icon Width",
                                desc = "Width of Utility Cooldown icons (usually smaller).",
                                min = 15, max = 60, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.utilityIconWidth end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.utilityIconWidth = value
                                    TUI:QueueClusterUpdate()
                                end,
                            },
                            accountForUtility = {
                                order = 3,
                                type = "toggle",
                                name = "Account for Utility Overflow",
                                desc = "Move frames outward if Utility icons exceed Essential icons.",
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
                                desc = "How many MORE utility icons than essential icons to trigger movement.",
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
                                desc = "Pixels to move each frame outward when threshold is met.",
                                min = 10, max = 200, step = 5,
                                get = function() return E.db.thingsUI.clusterPositioning.utilityOverflowOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.utilityOverflowOffset = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                            },
                            yOffset = {
                                order = 6,
                                type = "range",
                                name = "Y Offset",
                                desc = "Vertical offset for all unit frames.",
                                min = -100, max = 100, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.yOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.yOffset = value
                                    TUI:QueueClusterUpdate()
                                end,
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
                                        desc = "Anchor ElvUF_Player to the left of Essential.",
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
                                        desc = "Anchor ElvUF_Target to the right of Essential.",
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
                                        desc = "Gap between Player/Target frames and Essential.",
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
                                        desc = "Anchor ElvUF_TargetTarget to the target frame.",
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
                                        desc = "Gap between TargetTarget and Target frame.",
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
                                        desc = "Anchor ElvUF_Target_CastBar below the target frame.",
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
                                        desc = "Vertical gap between Target frame and CastBar.",
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
                                        desc = "Horizontal offset for CastBar.",
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

                    -----------------------------------------
                    -- DYNAMIC CASTBAR
                    -----------------------------------------
                    dynamicCastBarGroup = {
                        order = 30,
                        type = "group",
                        name = "Dynamic Castbar",
                        args = {
                            dynamicCastBarDesc = {
                                order = 1,
                                type = "description",
                                name = "Dynamically anchor the BCDM CastBar to the Secondary Power Bar when it is active, otherwise fall back to the Power Bar.\n\nUseful for specs with both bars or only Secondary, without needing multiple profiles.\n\nDruids who shapeshift mid cast like Convoke will get a 0.5s resize thing.\nCould maybe fix it with superfast updates, but kinda seemed like overkill. Better safe than sorry (:\n",
                            },
                            dynamicCastBarEnabled = {
                                order = 2,
                                type = "toggle",
                                name = "Enable Dynamic BCDM Castbar",
                                desc = "Automatically switch BCDM Castbar anchor between Power Bar and Secondary Power Bar.",
                                width = "full",
                                get = function() return E.db.thingsUI.dynamicCastBarAnchor.enabled end,
                                set = function(_, value)
                                    E.db.thingsUI.dynamicCastBarAnchor.enabled = value
                                    TUI:UpdateDynamicCastBarAnchor()
                                end,
                            },
                            dynamicCastBarPoint = {
                                order = 3,
                                type = "select",
                                name = "Anchor From",
                                desc = "The point on the CastBar to anchor.",
                                values = {
                                    ["TOP"] = "Top",
                                    ["BOTTOM"] = "Bottom",
                                    ["LEFT"] = "Left",
                                    ["RIGHT"] = "Right",
                                    ["CENTER"] = "Center",
                                },
                                get = function() return E.db.thingsUI.dynamicCastBarAnchor.point end,
                                set = function(_, value)
                                    E.db.thingsUI.dynamicCastBarAnchor.point = value
                                    TUI:UpdateDynamicCastBarAnchor()
                                end,
                                disabled = function() return not E.db.thingsUI.dynamicCastBarAnchor.enabled end,
                            },
                            dynamicCastBarRelative = {
                                order = 4,
                                type = "select",
                                name = "Anchor To",
                                desc = "The point on the Power Bar to anchor to.",
                                values = {
                                    ["TOP"] = "Top",
                                    ["BOTTOM"] = "Bottom",
                                    ["LEFT"] = "Left",
                                    ["RIGHT"] = "Right",
                                    ["CENTER"] = "Center",
                                },
                                get = function() return E.db.thingsUI.dynamicCastBarAnchor.relativePoint end,
                                set = function(_, value)
                                    E.db.thingsUI.dynamicCastBarAnchor.relativePoint = value
                                    TUI:UpdateDynamicCastBarAnchor()
                                end,
                                disabled = function() return not E.db.thingsUI.dynamicCastBarAnchor.enabled end,
                            },
                            dynamicCastBarX = {
                                order = 5,
                                type = "range",
                                name = "X Offset",
                                min = -100, max = 100, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.dynamicCastBarAnchor.xOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.dynamicCastBarAnchor.xOffset = value
                                    TUI:UpdateDynamicCastBarAnchor()
                                end,
                                disabled = function() return not E.db.thingsUI.dynamicCastBarAnchor.enabled end,
                            },
                            dynamicCastBarY = {
                                order = 6,
                                type = "range",
                                name = "Y Offset",
                                min = -100, max = 100, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.dynamicCastBarAnchor.yOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.dynamicCastBarAnchor.yOffset = value
                                    TUI:UpdateDynamicCastBarAnchor()
                                end,
                                disabled = function() return not E.db.thingsUI.dynamicCastBarAnchor.enabled end,
                            },
                            dynamicCastBarStatus = {
                                order = 7,
                                type = "description",
                                name = function()
                                    local secondary = _G["BCDM_SecondaryPowerBar"]
                                    local primary = _G["BCDM_PowerBar"]
                                    local castBar = _G["BCDM_CastBar"]
                                    local parts = {}
                                    parts[#parts + 1] = "|cFFFFFF00CastBar:|r " .. (castBar and "found" or "|cFFFF0000not found|r")
                                    parts[#parts + 1] = "|cFFFFFF00PowerBar:|r " .. (primary and (primary:IsShown() and "active" or "hidden") or "|cFFFF0000not found|r")
                                    parts[#parts + 1] = "|cFFFFFF00SecondaryPowerBar:|r " .. (secondary and (secondary:IsShown() and "|cFF00FF00active|r" or "hidden") or "not found")
                                    return "\n" .. table.concat(parts, "\n")
                                end,
                            },
                        },
                    },
                },
            },
            trinketsCDMSubTab = {
                order = 2,
                type = "group",
                name = "Trinkets to CDM",
                args = {
                    modeGroup = {
                        order = 1,
                        type = "group",
                        name = "Mode",
                        inline = true,
                        args = {
                            trinketsCDMDesc = {
                                order = 0,
                                type = "description",
                                name = "Position BCDM's trinket bar relative to the Essential or Utility cooldown viewer.\n",
                            },
                            trinketsCDMEnabled = {
                                order = 1,
                                type = "toggle",
                                name = "Enable",
                                desc = "Position BCDM's trinket bar relative to the Essential or Utility cooldown viewer.",
                                width = "full",
                                get = function() return E.db.thingsUI.trinketsCDM.enabled end,
                                set = function(_, value)
                                    E.db.thingsUI.trinketsCDM.enabled = value
                                    TUI:UpdateTrinketsCDM()
                                    NotifyChange()
                                end,
                            },
                            trinketsCDMMode = {
                                order = 2,
                                type = "toggle",
                                name = "NHT (Horizontal)",
                                desc = "Trinkets extend the Essential row horizontally (grows left or right).",
                                hidden = function() return not E.db.thingsUI.trinketsCDM.enabled end,
                                get = function() return E.db.thingsUI.trinketsCDM.mode == "NHT" end,
                                set = function(_, value)
                                    if value then
                                        E.db.thingsUI.trinketsCDM.mode = "NHT"
                                        TUI:UpdateTrinketsCDM()
                                        NotifyChange()
                                    end
                                end,
                            },
                            trinketsCDMModeFHT = {
                                order = 3,
                                type = "toggle",
                                name = "FHT (Vertical)",
                                desc = "Trinkets grow vertically from the end of Essential. If Essential + trinkets exceed the limit, they overflow to the Utility slot (Utility shifts down).",
                                hidden = function() return not E.db.thingsUI.trinketsCDM.enabled end,
                                get = function() return E.db.thingsUI.trinketsCDM.mode == "FHT" end,
                                set = function(_, value)
                                    if value then
                                        E.db.thingsUI.trinketsCDM.mode = "FHT"
                                        TUI:UpdateTrinketsCDM()
                                        NotifyChange()
                                    end
                                end,
                            },
                        },
                    },
                    layoutGroup = {
                        order = 2,
                        type = "group",
                        name = "Layout",
                        inline = true,
                        hidden = function() return not E.db.thingsUI.trinketsCDM.enabled end,
                        args = {
                            trinketsCDMSide = {
                                order = 1,
                                type = "select",
                                name = "Side",
                                desc = "Which end of EssentialCooldownViewer to anchor to.",
                                hidden = function() return E.db.thingsUI.trinketsCDM.mode == "FHT" end,
                                values = {
                                    RIGHT = "Right",
                                    LEFT  = "Left",
                                },
                                get = function() return E.db.thingsUI.trinketsCDM.side end,
                                set = function(_, value)
                                    E.db.thingsUI.trinketsCDM.side = value
                                    TUI:UpdateTrinketsCDM()
                                end,
                            },
                            trinketsCDMGap = {
                                order = 2,
                                type = "range",
                                name = "Gap",
                                desc = "Pixel gap between EssentialCooldownViewer and the trinket bar. NHT = horizontal, FHT = vertical.",
                                min = -20, max = 20, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.trinketsCDM.gap end,
                                set = function(_, value)
                                    E.db.thingsUI.trinketsCDM.gap = value
                                    TUI:UpdateTrinketsCDM()
                                end,
                            },
                            trinketsCDMFhtLimit = {
                                order = 3,
                                type = "range",
                                name = "FHT Essential Limit",
                                desc = "Maximum combined icon count (Essential + trinkets) before trinkets overflow to the Utility slot.",
                                hidden = function() return E.db.thingsUI.trinketsCDM.mode ~= "FHT" end,
                                min = 1, max = 30, step = 1,
                                get = function() return E.db.thingsUI.trinketsCDM.fhtLimit end,
                                set = function(_, value)
                                    E.db.thingsUI.trinketsCDM.fhtLimit = value
                                    TUI:UpdateTrinketsCDM()
                                end,
                            },
                        },
                    },
                    blacklistGroup = TUI:TrinketBlacklistOptions(),
                },
            },
        },
    }
end
