local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local function SHARED_ANCHOR_VALUES() return ns.ANCHORS.GetSharedAnchorValues() end
local STRATA_VALUES = ns.STRATA.VALUES
local STRATA_ORDER  = ns.STRATA.ORDER
local POINT_VALUES  = ns.POINTS.VALUES
local POINT_ORDER   = ns.POINTS.ORDER

local function CDM() return E.db.general.cooldownManager end
local function PokeCDM()
    local S = E:GetModule("Skins", true)
    if S and S.CooldownManager_UpdateViewers then
        S:CooldownManager_UpdateViewers()
    end
end

local function ApplyBuffBarPreset(key)
    local p = ns.Defaults.BuffBarPresets and ns.Defaults.BuffBarPresets[key]
    if not p then return end
    local db = E.db.thingsUI.buffBars
    for k, v in pairs(p.buffBars) do db[k] = v end
    local cdm = CDM()
    for k, v in pairs(p.cdm) do cdm[k] = v end
    wipe(ns.skinnedBars)
    TUI:UpdateBuffBars()
    PokeCDM()
end

function TUI:BuffBarsOptions()
    return {
        order = 20,
        type = "group",
        name = "Buff Bars",
        childGroups = "tab",
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
                desc = "Load default for NHT (bars grow UP from player frame).",
                func = function() ApplyBuffBarPreset("dpsTank") end,
            },
            presetHealer = {
                order = 4,
                type = "execute",
                name = "Load Healer Preset",
                desc = "Load default for FHT (bars grow DOWN from classbar).",
                func = function() ApplyBuffBarPreset("healer") end,
            },

            -- LAYOUT SUB-GROUP
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

            
            -- TEXT SUB-GROUP
            textGroup = {
                order = 20,
                type = "group",
                name = "Text",
                args = {
                    nameGroup = {
                        order = 1,
                        type = "group",
                        name = "Name",
                        inline = true,
                        args = {
                            nameFont = {
                                order = 1,
                                type = "select",
                                name = "Font",
                                dialogControl = "LSM30_Font",
                                values = LSM:HashTable("font"),
                                get = function() return CDM().nameFont end,
                                set = function(_, value) CDM().nameFont = value; PokeCDM() end,
                            },
                            nameFontSize = {
                                order = 2,
                                type = "range",
                                name = "Font Size",
                                min = 8, max = 50, step = 1,
                                get = function() return CDM().nameFontSize end,
                                set = function(_, value) CDM().nameFontSize = value; PokeCDM() end,
                            },
                            nameFontOutline = {
                                order = 3,
                                type = "select",
                                name = "Font Outline",
                                values = ns.OUTLINE.VALUES,
                                sorting = ns.OUTLINE.ORDER,
                                get = function() return CDM().nameFontOutline end,
                                set = function(_, value) CDM().nameFontOutline = value; PokeCDM() end,
                            },
                            namePosition = {
                                order = 4,
                                type = "select",
                                name = "Anchor Point",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function() return CDM().namePosition end,
                                set = function(_, value) CDM().namePosition = value; PokeCDM() end,
                            },
                            namexOffset = {
                                order = 5,
                                type = "range",
                                name = "X Offset",
                                min = -50, max = 50, step = 1,
                                get = function() return CDM().namexOffset end,
                                set = function(_, value) CDM().namexOffset = value; PokeCDM() end,
                            },
                            nameyOffset = {
                                order = 6,
                                type = "range",
                                name = "Y Offset",
                                min = -20, max = 20, step = 1,
                                get = function() return CDM().nameyOffset end,
                                set = function(_, value) CDM().nameyOffset = value; PokeCDM() end,
                            },
                        },
                    },
                    durationGroup = {
                        order = 2,
                        type = "group",
                        name = "Duration",
                        inline = true,
                        args = {
                            durationFont = {
                                order = 1,
                                type = "select",
                                name = "Font",
                                dialogControl = "LSM30_Font",
                                values = LSM:HashTable("font"),
                                get = function() return CDM().durationFont end,
                                set = function(_, value) CDM().durationFont = value; PokeCDM() end,
                            },
                            durationFontSize = {
                                order = 2,
                                type = "range",
                                name = "Font Size",
                                min = 8, max = 50, step = 1,
                                get = function() return CDM().durationFontSize end,
                                set = function(_, value) CDM().durationFontSize = value; PokeCDM() end,
                            },
                            durationFontOutline = {
                                order = 3,
                                type = "select",
                                name = "Font Outline",
                                values = ns.OUTLINE.VALUES,
                                sorting = ns.OUTLINE.ORDER,
                                get = function() return CDM().durationFontOutline end,
                                set = function(_, value) CDM().durationFontOutline = value; PokeCDM() end,
                            },
                            durationPosition = {
                                order = 4,
                                type = "select",
                                name = "Anchor Point",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function() return CDM().durationPosition end,
                                set = function(_, value) CDM().durationPosition = value; PokeCDM() end,
                            },
                            durationxOffset = {
                                order = 5,
                                type = "range",
                                name = "X Offset",
                                min = -50, max = 50, step = 1,
                                get = function() return CDM().durationxOffset end,
                                set = function(_, value) CDM().durationxOffset = value; PokeCDM() end,
                            },
                            durationyOffset = {
                                order = 6,
                                type = "range",
                                name = "Y Offset",
                                min = -20, max = 20, step = 1,
                                get = function() return CDM().durationyOffset end,
                                set = function(_, value) CDM().durationyOffset = value; PokeCDM() end,
                            },
                        },
                    },
                    stackGroup = {
                        order = 5,
                        type = "group",
                        name = "Stack Count",
                        inline = true,
                        args = {
                            stackAnchor = {
                                order = 1,
                                type = "select",
                                name = "Stack Anchor",
                                values = {
                                    ["ICON"] = "Icon",
                                    ["BAR"] = "Bar",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackAnchor end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackAnchor = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                    PokeCDM()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            -- Font + outline ALWAYS proxy ElvUI's count* fields. The visible
                            -- text element is the same FontString regardless of which parent
                            -- it sits on, so styling lives in one place.
                            stackFont = {
                                order = 2,
                                type = "select",
                                name = "Font",
                                dialogControl = "LSM30_Font",
                                values = LSM:HashTable("font"),
                                get = function() return CDM().countFont end,
                                set = function(_, value) CDM().countFont = value; PokeCDM() end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontSize = {
                                order = 3,
                                type = "range",
                                name = "Font Size",
                                min = 6, max = 50, step = 1,
                                get = function() return CDM().countFontSize end,
                                set = function(_, value) CDM().countFontSize = value; PokeCDM() end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontOutline = {
                                order = 4,
                                type = "select",
                                name = "Font Outline",
                                values = ns.OUTLINE.VALUES,
                                sorting = ns.OUTLINE.ORDER,
                                get = function() return CDM().countFontOutline end,
                                set = function(_, value) CDM().countFontOutline = value; PokeCDM() end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            -- Position fields dispatch: ICON anchor -> proxy ElvUI's count*
                            -- fields. BAR anchor -> use our own thingsUI.buffBars.stack*
                            -- because ElvUI doesn't know about reparented stack text.
                            stackPoint = {
                                order = 5,
                                type = "select",
                                name = "Anchor Point",
                                values = POINT_VALUES,
                                sorting = POINT_ORDER,
                                get = function()
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        return E.db.thingsUI.buffBars.stackPoint
                                    end
                                    return CDM().countPosition
                                end,
                                set = function(_, value)
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        E.db.thingsUI.buffBars.stackPoint = value
                                        wipe(ns.skinnedBars)
                                        TUI:UpdateBuffBars()
                                    else
                                        CDM().countPosition = value
                                        PokeCDM()
                                    end
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackXOffset = {
                                order = 6,
                                type = "range",
                                name = "X Offset",
                                min = -50, max = 50, step = 1,
                                get = function()
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        return E.db.thingsUI.buffBars.stackXOffset
                                    end
                                    return CDM().countxOffset
                                end,
                                set = function(_, value)
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        E.db.thingsUI.buffBars.stackXOffset = value
                                        wipe(ns.skinnedBars)
                                        TUI:UpdateBuffBars()
                                    else
                                        CDM().countxOffset = value
                                        PokeCDM()
                                    end
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackYOffset = {
                                order = 7,
                                type = "range",
                                name = "Y Offset",
                                min = -20, max = 20, step = 1,
                                get = function()
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        return E.db.thingsUI.buffBars.stackYOffset
                                    end
                                    return CDM().countyOffset
                                end,
                                set = function(_, value)
                                    if E.db.thingsUI.buffBars.stackAnchor == "BAR" then
                                        E.db.thingsUI.buffBars.stackYOffset = value
                                        wipe(ns.skinnedBars)
                                        TUI:UpdateBuffBars()
                                    else
                                        CDM().countyOffset = value
                                        PokeCDM()
                                    end
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
