local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local NotifyChange = ns.NotifyChange

function TUI:ClusterPositioningSubTab()
    return {
                order = 1,
                type = "group",
                name = "Cluster Positioning",
                args = {
                    header = {
                        order = 1,
                        type = "header",
                        name = "Cluster Positioning",
                    },
                    description = {
                        order = 2,
                        type = "description",
                        name = "Anchor ElvUI unit frames to the Essential Cooldown Viewer.\n\nWhen enabled:\n• ElvUF_Player anchors to the left\n• ElvUF_Target anchors to the right\n• ElvUF_TargetTarget anchors to Target\n• ElvUF_Target_CastBar anchors below Target\n• Focus frame + castbar anchor wherever you choose (default: below Target)\n\n|cFFFF4040Warning:|r This overrides ElvUI's unit frame positioning, it will look weird in /emove.\n\n",
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
                                    local essentialCount, utilityCount = 0, 0
                                    if ns.ClusterCounts then essentialCount, utilityCount = ns.ClusterCounts() end
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

                    -- ICON SETTINGS
                    iconGroup = {
                        order = 10,
                        type = "group",
                        name = "Icon Settings",
                        inline = true,
                        disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                        args = {
                            iconSizeInfo = {
                                order = 1, type = "description",
                                name = "|cFF888888Overflow is measured from the live on-screen Essential and Utility row widths - each side moves only as far as Utility actually sticks out.|r\n",
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
                                min = 0, max = 200, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.utilityOverflowOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.utilityOverflowOffset = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.accountForUtility end,
                            },
                        },
                    },

                    playerTargetGroup = {
                                order = 20,
                                type = "group",
                                name = "Player / Target Frame",
                                inline = true,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
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
                                order = 21,
                                type = "group",
                                name = "Target of Target Frame",
                                inline = true,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
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
                                order = 22,
                                type = "group",
                                name = "Target Cast Bar",
                                inline = true,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
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
                    focusGroup = (function()
                                local function fdb() return E.db.thingsUI.clusterPositioning.focusFrame end
                                local function fset(k, v) fdb()[k] = v; TUI:QueueClusterUpdate() end
                                local function off() return not E.db.thingsUI.clusterPositioning.enabled or not fdb().enabled end
                                return {
                                    order = 23, type = "group", name = "Focus Frame", inline = true,
                                    disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                                    args = {
                                        enabled = {
                                            order = 1, type = "toggle", name = "Position Focus Frame",
                                            get = function() return fdb().enabled end,
                                            set = function(_, v) fset("enabled", v) end,
                                        },
                                        matchWidth = {
                                            order = 2, type = "toggle", name = "Match Anchor Width",
                                            disabled = off,
                                            get = function() return fdb().matchWidth end,
                                            set = function(_, v) fset("matchWidth", v) end,
                                        },
                                        anchorFrame = {
                                            order = 3, type = "select", name = "Anchor Frame", width = "double",
                                            values = function() return ns.ANCHORS.FilteredValues() end,
                                            sorting = function() return ns.ANCHORS.FilteredOrder() end,
                                            disabled = off,
                                            get = function() return fdb().anchorFrame or "ElvUF_Target" end,
                                            set = function(_, v) fset("anchorFrame", v) end,
                                        },
                                        anchorPoint = {
                                            order = 4, type = "select", name = "Anchor From",
                                            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                            disabled = off,
                                            get = function() return fdb().anchorPoint or "TOP" end,
                                            set = function(_, v) fset("anchorPoint", v) end,
                                        },
                                        anchorRelativePoint = {
                                            order = 5, type = "select", name = "Anchor To",
                                            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                            disabled = off,
                                            get = function() return fdb().anchorRelativePoint or "BOTTOM" end,
                                            set = function(_, v) fset("anchorRelativePoint", v) end,
                                        },
                                        xOffset = {
                                            order = 6, type = "range", name = "X Offset",
                                            min = -500, max = 500, step = 0.5, bigStep = 1,
                                            disabled = off,
                                            get = function() return fdb().xOffset or 0 end,
                                            set = function(_, v) fset("xOffset", v) end,
                                        },
                                        yOffset = {
                                            order = 7, type = "range", name = "Y Offset",
                                            min = -500, max = 500, step = 0.5, bigStep = 1,
                                            disabled = off,
                                            get = function() return fdb().yOffset or 0 end,
                                            set = function(_, v) fset("yOffset", v) end,
                                        },
                                    },
                                }
                            end)(),
                    focusCastBarGroup = (function()
                                local function cdb() return E.db.thingsUI.clusterPositioning.focusCastBar end
                                local function cset(k, v) cdb()[k] = v; TUI:QueueClusterUpdate() end
                                local function off() return not E.db.thingsUI.clusterPositioning.enabled or not cdb().enabled end
                                return {
                                    order = 24, type = "group", name = "Focus Cast Bar", inline = true,
                                    disabled = function() return not E.db.thingsUI.clusterPositioning.enabled end,
                                    args = {
                                        enabled = {
                                            order = 1, type = "toggle", name = "Position Focus CastBar",
                                            desc = "Anchors the focus castbar to the Focus frame. Width follows the Focus frame automatically.",
                                            get = function() return cdb().enabled end,
                                            set = function(_, v) cset("enabled", v) end,
                                        },
                                        anchorPoint = {
                                            order = 2, type = "select", name = "Anchor From",
                                            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                            disabled = off,
                                            get = function() return cdb().anchorPoint or "TOP" end,
                                            set = function(_, v) cset("anchorPoint", v) end,
                                        },
                                        anchorRelativePoint = {
                                            order = 3, type = "select", name = "Anchor To",
                                            values = ns.POINTS.VALUES, sorting = ns.POINTS.ORDER,
                                            disabled = off,
                                            get = function() return cdb().anchorRelativePoint or "BOTTOM" end,
                                            set = function(_, v) cset("anchorRelativePoint", v) end,
                                        },
                                        xOffset = {
                                            order = 4, type = "range", name = "X Offset",
                                            min = -200, max = 200, step = 0.5, bigStep = 1,
                                            disabled = off,
                                            get = function() return cdb().xOffset or 0 end,
                                            set = function(_, v) cset("xOffset", v) end,
                                        },
                                        yOffset = {
                                            order = 5, type = "range", name = "Y Offset",
                                            min = -200, max = 200, step = 0.5, bigStep = 1,
                                            disabled = off,
                                            get = function() return cdb().yOffset or 0 end,
                                            set = function(_, v) cset("yOffset", v) end,
                                        },
                                    },
                                }
                            end)(),

                },
            }
end

