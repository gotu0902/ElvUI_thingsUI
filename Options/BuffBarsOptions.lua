local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local SHARED_ANCHOR_VALUES = ns.ANCHORS.SHARED_ANCHOR_VALUES
local STRATA_VALUES = ns.STRATA.VALUES
local STRATA_ORDER  = ns.STRATA.ORDER
local POINT_VALUES  = ns.POINTS.VALUES
local POINT_ORDER   = ns.POINTS.ORDER

function TUI:BuffBarsOptions()
    return {
        order = 20,
        type = "group",
        name = "Buff Bars",
        childGroups = "tree",
        args = {
            buffBarsHeader = {
                order = 1,
                type = "header",
                name = "Buff Bar Viewer (BuffBarCooldownViewer)",
            },
            enabled = {
                order = 2,
                type = "toggle",
                name = "Enable Buff Bar Skinning",
                desc = "Apply ElvUI styling to the Cooldown Manager buff bars.",
                width = "full",
                get = function() return E.db.thingsUI.buffBars.enabled end,
                set = function(_, value)
                    E.db.thingsUI.buffBars.enabled = value
                    TUI:UpdateBuffBars()
                end,
            },
            presetDPSTank = {
                order = 3,
                type = "execute",
                name = "Load DPS/Tank Preset",
                desc = "Load default buff bar settings for DPS and Tank specs (bars grow UP from player frame).",
               func = function()
                    local db = E.db.thingsUI.buffBars
                    db.enabled = true
                    db.growthDirection = "UP"
                    db.width = 240
                    db.inheritWidth = true
                    db.inheritWidthOffset = 0
                    db.height = 23
                    db.spacing = 1
                    db.statusBarTexture = "ElvUI Blank"
                    db.useClassColor = true
                    db.iconEnabled = true
                    db.iconSpacing = 1
                    db.iconZoom = 0.1
                    db.font = "Expressway"
                    db.fontSize = 14
                    db.fontOutline = "OUTLINE"
                    db.namePoint = "LEFT"
                    db.nameXOffset = 2
                    db.nameYOffset = 0
                    db.durationPoint = "RIGHT"
                    db.durationXOffset = -4
                    db.durationYOffset = 0
                    db.stackAnchor = "ICON"
                    db.stackPoint = "CENTER"
                    db.stackFontSize = 15
                    db.stackFontOutline = "OUTLINE"
                    db.stackXOffset = 0
                    db.stackYOffset = 0
                    db.anchorEnabled = true
                    db.anchorFrame = "ElvUF_Player"
                    db.anchorPoint = "BOTTOM"
                    db.anchorRelativePoint = "TOP"
                    db.anchorXOffset = 0
                    db.anchorYOffset = 50
                    wipe(ns.skinnedBars)
                    TUI:UpdateBuffBars()
                end,
            },
            presetHealer = {
                order = 4,
                type = "execute",
                name = "Load Healer Preset",
                desc = "Load default buff bar settings for Healer specs (bars grow DOWN from class bar).",
                func = function()
                    local db = E.db.thingsUI.buffBars
                    db.enabled = true
                    db.growthDirection = "DOWN"
                    db.width = 218
                    db.inheritWidth = true
                    db.inheritWidthOffset = 2
                    db.height = 23
                    db.spacing = 1
                    db.statusBarTexture = "ElvUI Blank"
                    db.useClassColor = true
                    db.iconEnabled = true
                    db.iconSpacing = 1
                    db.iconZoom = 0
                    db.font = "Expressway"
                    db.fontSize = 15
                    db.fontOutline = "OUTLINE"
                    db.namePoint = "LEFT"
                    db.nameXOffset = 4
                    db.nameYOffset = 0
                    db.durationPoint = "RIGHT"
                    db.durationXOffset = -4
                    db.durationYOffset = 0
                    db.stackAnchor = "ICON"
                    db.stackPoint = "CENTER"
                    db.stackFontSize = 15
                    db.stackFontOutline = "OUTLINE"
                    db.stackXOffset = 0
                    db.stackYOffset = 0
                    db.anchorEnabled = true
                    db.anchorFrame = "ElvUF_Player_ClassBar"
                    db.anchorPoint = "TOP"
                    db.anchorRelativePoint = "BOTTOM"
                    db.anchorXOffset = 0
                    db.anchorYOffset = -2
                    wipe(ns.skinnedBars)
                    TUI:UpdateBuffBars()
                end,
            },

            -----------------------------------------
            -- LAYOUT SUB-GROUP
            -----------------------------------------
            layoutGroup = {
                order = 10,
                type = "group",
                name = "Layout",
                args = {
                    sizeGroup = {
                        order = 1,
                        type = "group",
                        name = "Size & Spacing",
                        inline = true,
                        args = {
                            growthDirection = {
                                order = 1,
                                type = "select",
                                name = "Growth Direction",
                                desc = "Direction the bars grow.",
                                values = {
                                    ["UP"] = "Up",
                                    ["DOWN"] = "Down",
                                },
                                get = function() return E.db.thingsUI.buffBars.growthDirection end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.growthDirection = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            width = {
                                order = 2,
                                type = "range",
                                name = "Width",
                                min = 100, max = 400, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.width end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.width = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return E.db.thingsUI.buffBars.inheritWidth end,
                            },
                            inheritWidth = {
                                order = 3,
                                type = "toggle",
                                name = "Inherit Width from Anchor",
                                desc = "Automatically match the width of the anchor frame. Requires anchoring to be enabled.",
                                get = function() return E.db.thingsUI.buffBars.inheritWidth end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.inheritWidth = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            inheritWidthOffset = {
                                order = 4,
                                type = "range",
                                name = "Width Nudge",
                                desc = "Fine-tune the inherited width. Add or subtract pixels from the anchor's width.",
                                min = -10, max = 10, step = 0.01, bigStep = 0.5,
                                get = function() return E.db.thingsUI.buffBars.inheritWidthOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.inheritWidthOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.inheritWidth end,
                            },
                            height = {
                                order = 5,
                                type = "range",
                                name = "Height",
                                min = 10, max = 40, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.height end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.height = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            spacing = {
                                order = 6,
                                type = "range",
                                name = "Spacing",
                                min = -10, max = 10, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.spacing end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.spacing = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                        },
                    },
                    textureGroup = {
                        order = 2,
                        type = "group",
                        name = "Textures & Colors",
                        inline = true,
                        args = {
                            statusBarTexture = {
                                order = 1,
                                type = "select",
                                name = "Status Bar Texture",
                                dialogControl = "LSM30_Statusbar",
                                values = LSM:HashTable("statusbar"),
                                get = function() return E.db.thingsUI.buffBars.statusBarTexture end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.statusBarTexture = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            useClassColor = {
                                order = 2,
                                type = "toggle",
                                name = "Use Class Color",
                                desc = "Color the bar based on your class.",
                                get = function() return E.db.thingsUI.buffBars.useClassColor end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.useClassColor = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            customColor = {
                                order = 3,
                                type = "color",
                                name = "Custom Bar Color",
                                desc = "Custom color when not using class color.",
                                hasAlpha = false,
                                disabled = function() return E.db.thingsUI.buffBars.useClassColor end,
                                get = function()
                                    local c = E.db.thingsUI.buffBars.customColor
                                    return c.r, c.g, c.b
                                end,
                                set = function(_, r, g, b)
                                    E.db.thingsUI.buffBars.customColor = { r = r, g = g, b = b }
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                        },
                    },
                    iconGroup = {
                        order = 3,
                        type = "group",
                        name = "Icon",
                        inline = true,
                        args = {
                            iconEnabled = {
                                order = 1,
                                type = "toggle",
                                name = "Show Icon",
                                desc = "Display the spell icon next to the bar.",
                                get = function() return E.db.thingsUI.buffBars.iconEnabled end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.iconEnabled = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            iconSpacing = {
                                order = 2,
                                type = "range",
                                name = "Icon Spacing",
                                desc = "Gap between the icon and the bar.",
                                min = 0, max = 10, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.iconSpacing end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.iconSpacing = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            iconZoom = {
                                order = 3,
                                type = "range",
                                name = "Icon Zoom",
                                desc = "How much to crop the icon edges. 0 = no crop (full texture), 0.1 = ElvUI default.",
                                min = 0, max = 0.45, step = 0.01,
                                isPercent = true,
                                get = function() return E.db.thingsUI.buffBars.iconZoom end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.iconZoom = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                        },
                    },
                },
            },

            -----------------------------------------
            -- TEXT SUB-GROUP
            -----------------------------------------
            textGroup = {
                order = 20,
                type = "group",
                name = "Text",
                args = {
                    fontGroup = {
                        order = 1,
                        type = "group",
                        name = "Font",
                        inline = true,
                        args = {
                            font = {
                                order = 1,
                                type = "select",
                                name = "Font",
                                dialogControl = "LSM30_Font",
                                values = LSM:HashTable("font"),
                                get = function() return E.db.thingsUI.buffBars.font end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.font = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            fontSize = {
                                order = 2,
                                type = "range",
                                name = "Font Size",
                                min = 8, max = 50, step = 1,
                                get = function() return E.db.thingsUI.buffBars.fontSize end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.fontSize = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            fontOutline = {
                                order = 3,
                                type = "select",
                                name = "Font Outline",
                                desc = "Outline for Name and Duration text.",
                                values = {
                                    ["NONE"] = "None",
                                    ["OUTLINE"] = "Outline",
                                    ["THICKOUTLINE"] = "Thick Outline",
                                    ["MONOCHROME"] = "Monochrome",
                                },
                                get = function() return E.db.thingsUI.buffBars.fontOutline end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.fontOutline = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                        },
                    },
                    nameTextGroup = {
                        order = 2,
                        type = "group",
                        name = "Name Text",
                        inline = true,
                        args = {
                            namePoint = {
                                order = 1,
                                type = "select",
                                name = "Name Alignment",
                                desc = "Anchor point for the spell name text.",
                                values = {
                                    ["LEFT"] = "Left",
                                    ["CENTER"] = "Center",
                                    ["RIGHT"] = "Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.namePoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.namePoint = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            nameXOffset = {
                                order = 2,
                                type = "range",
                                name = "Name X Offset",
                                min = -50, max = 50, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.nameXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.nameXOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            nameYOffset = {
                                order = 3,
                                type = "range",
                                name = "Name Y Offset",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.nameYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.nameYOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                        },
                    },
                    durationTextGroup = {
                        order = 3,
                        type = "group",
                        name = "Duration Text",
                        inline = true,
                        args = {
                            durationPoint = {
                                order = 1,
                                type = "select",
                                name = "Duration Alignment",
                                desc = "Anchor point for the duration text.",
                                values = {
                                    ["LEFT"] = "Left",
                                    ["CENTER"] = "Center",
                                    ["RIGHT"] = "Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.durationPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationPoint = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            durationXOffset = {
                                order = 2,
                                type = "range",
                                name = "Duration X Offset",
                                min = -50, max = 50, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.durationXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationXOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            durationYOffset = {
                                order = 3,
                                type = "range",
                                name = "Duration Y Offset",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.durationYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.durationYOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                            },
                        },
                    },
                    stackGroup = {
                        order = 4,
                        type = "group",
                        name = "Stack Count",
                        inline = true,
                        args = {
                            stackAnchor = {
                                order = 1,
                                type = "select",
                                name = "Stack Anchor",
                                desc = "Anchor the stack count to the Icon or the Bar.",
                                values = {
                                    ["ICON"] = "Icon",
                                    ["BAR"] = "Bar",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackAnchor end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackAnchor = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackPoint = {
                                order = 2,
                                type = "select",
                                name = "Stack Position",
                                desc = "Anchor point for the stack count on the icon.",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function() return E.db.thingsUI.buffBars.stackPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackPoint = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontSize = {
                                order = 3,
                                type = "range",
                                name = "Stack Font Size",
                                desc = "Font size for the stack count on icons.",
                                min = 6, max = 50, step = 1,
                                get = function() return E.db.thingsUI.buffBars.stackFontSize end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackFontSize = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontOutline = {
                                order = 4,
                                type = "select",
                                name = "Stack Font Outline",
                                values = {
                                    ["NONE"] = "None",
                                    ["OUTLINE"] = "Outline",
                                    ["THICKOUTLINE"] = "Thick Outline",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackFontOutline end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackFontOutline = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackXOffset = {
                                order = 5,
                                type = "range",
                                name = "Stack X Offset",
                                desc = "Horizontal offset for the stack count text.",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.stackXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackXOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackYOffset = {
                                order = 6,
                                type = "range",
                                name = "Stack Y Offset",
                                desc = "Vertical offset for the stack count text.",
                                min = -20, max = 20, step = 0.5,
                                get = function() return E.db.thingsUI.buffBars.stackYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackYOffset = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                        },
                    },
                },
            },

            -----------------------------------------
            -- ANCHORING SUB-GROUP
            -----------------------------------------
            anchoringGroup = {
                order = 30,
                type = "group",
                name = "Anchoring",
                args = {
                    anchorSettingsGroup = {
                        order = 1,
                        type = "group",
                        name = "Anchor Settings",
                        inline = true,
                        args = {
                            anchorEnabled = {
                                order = 1,
                                type = "toggle",
                                name = "Enable Anchoring",
                                desc = "Anchor the buff bar container to another frame.",
                                get = function() return E.db.thingsUI.buffBars.anchorEnabled end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorEnabled = value
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            frameStrata = {
                                order = 0.5,
                                type = "select",
                                name = "Frame Strata",
                                desc = "Render layer for the buff bars. Higher strata draws on top of lower ones.",
                                values = STRATA_VALUES,
                                sorting = STRATA_ORDER,
                                get = function() return E.db.thingsUI.buffBars.frameStrata or "MEDIUM" end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.frameStrata = value
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            anchorFrame = {
                                order = 2,
                                type = "select",
                                name = "Anchor Frame",
                                desc = "Select a frame to anchor to.",
                                values = SHARED_ANCHOR_VALUES,
                                get = function() return E.db.thingsUI.buffBars.anchorFrame end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorFrame = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorPoint = {
                                order = 3,
                                type = "select",
                                name = "Anchor From",
                                desc = "The point on the buff bars to anchor.",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function() return E.db.thingsUI.buffBars.anchorPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorPoint = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorRelativePoint = {
                                order = 4,
                                type = "select",
                                name = "Anchor To",
                                desc = "The point on the target frame to anchor to.",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function() return E.db.thingsUI.buffBars.anchorRelativePoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorRelativePoint = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorXOffset = {
                                order = 5,
                                type = "range",
                                name = "X Offset",
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.anchorXOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorXOffset = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorYOffset = {
                                order = 6,
                                type = "range",
                                name = "Y Offset",
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.buffBars.anchorYOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorYOffset = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                        },
                    },
                },
            },
        },
    }
end
