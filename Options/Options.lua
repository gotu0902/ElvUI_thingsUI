local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local SHARED_ANCHOR_VALUES = ns.ANCHORS.SHARED_ANCHOR_VALUES
local anchors = ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES

local GetSpecialBarSlotDB = ns.SpecialBars and ns.SpecialBars.GetSpecialBarSlotDB
local CleanString = ns.SpecialBars and ns.SpecialBars.CleanString

local function SpecialBarTabName(barKey, index)
    -- Fallback if DB helpers aren't available for some reason
    if not GetSpecialBarSlotDB then
        return ("Special Bar %d"):format(index or 0)
    end

    local db = GetSpecialBarSlotDB(barKey) or {}
    local spell = db.spellName or ""
    if CleanString then
        spell = CleanString(spell)
    else
        spell = tostring(spell):gsub("^%s+", ""):gsub("%s+$", "")
    end

    if spell ~= "" then
        return ("Special Bar %d: %s"):format(index or 0, spell)
    end
    return ("Special Bar %d"):format(index or 0)
end

-------------------------------------------------
-- ELVUI CONFIG OPTIONS
-------------------------------------------------
function TUI.ConfigTable()
    E.Options.args.thingsUI = {
        order = 100,
        type = "group",
        name = "|cFF8080FFthingsUI|r",
        childGroups = "tab",
        args = {
            header = {
                order = 1,
                type = "header",
                name = "thingsUI v" .. TUI.version,
            },
            description = {
                order = 2,
                type = "description",
                name = "Additional customization options for the Blizzard Cooldown Manager.\n\n",
            },
            
            -------------------------------------------------
            -- BUFF ICONS TAB
            -------------------------------------------------
            generalTab = {
                order = 10,
                type = "group",
                name = "General",
                args = {
                    buffIconsHeader = {
                        order = 1,
                        type = "header",
                        name = "Buff Icon Viewer (BuffIconCooldownViewer)",
                    },
                    verticalBuffs = {
                        order = 2,
                        type = "toggle",
                        name = "Grow Vertically (Top to Bottom)",
                        desc = "Stack buff icons vertically from top to bottom instead of horizontally.",
                        width = "full",
                        get = function() return E.db.thingsUI.verticalBuffs end,
                        set = function(_, value)
                            E.db.thingsUI.verticalBuffs = value
                            TUI:UpdateVerticalBuffs()
                        end,
                    },
                    verticalNote = {
                        order = 3,
                        type = "description",
                        name = "\n|cFFFFFF00Note:|r If disabling, you may need to reload UI to restore default horizontal layout.\n",
                    },
                    
                    psettingsHeader = {
                        order = 10,
                        type = "header",
                        name = "ElvUI Private Settings",
                    },
                    psettingsDescription = {
                        order = 11,
                        type = "description",
                        name = "Apply ElvUI private settings.\n\n|cFFFF6B6BWarning:|r This will overwrite your Private Profile settings!\n",
                    },
                    psettingsImport = {
                        order = 12,
                        type = "execute",
                        name = "Setup things Settings",
                        desc = "Apply ElvUI private settings.",
                        func = function()
                            -- ElvUI Private General
                            E.private["general"]["chatBubbleFont"] = "Expressway"
                            E.private["general"]["chatBubbleFontOutline"] = "OUTLINE"
                            E.private["general"]["chatBubbles"] = "nobackdrop"
                            E.private["general"]["classColors"] = true
                            E.private["general"]["glossTex"] = "ElvUI Blank"
                            E.private["general"]["minimap"]["hideTracking"] = true
                            E.private["general"]["nameplateFont"] = "Expressway"
                            E.private["general"]["nameplateLargeFont"] = "Expressway"
                            E.private["general"]["normTex"] = "ElvUI Blank"
                            E.private["install_complete"] = 12.12
                            -- ElvUI Private Other
                            E.private["nameplates"]["enable"] = false
                            E.private["skins"]["blizzard"]["cooldownManager"] = false
                            E.private["skins"]["parchmentRemoverEnable"] = true
                            
                            print("|cFF8080FFthingsUI|r - ElvUI private settings applied! |cFFFFFF00Reload required.|r")
                            E:StaticPopup_Show("PRIVATE_RL")
                        end,
                    },
                },
            },
            
            -------------------------------------------------
            -- BUFF BARS TAB
            -------------------------------------------------
            buffBarsTab = {
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
                            layoutHeader = {
                                order = 1,
                                type = "header",
                                name = "Size & Spacing",
                            },
                            growthDirection = {
                                order = 2,
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
                                order = 3,
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
                                order = 4,
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
                                order = 5,
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
                                order = 6,
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
                                order = 7,
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
                            
                            textureHeader = {
                                order = 10,
                                type = "header",
                                name = "Textures & Colors",
                            },
                            statusBarTexture = {
                                order = 11,
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
                                order = 12,
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
                                order = 13,
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
                            
                            iconHeader = {
                                order = 20,
                                type = "header",
                                name = "Icon",
                            },
                            iconEnabled = {
                                order = 21,
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
                                order = 22,
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
                                order = 23,
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
                    
                    -----------------------------------------
                    -- TEXT SUB-GROUP
                    -----------------------------------------
                    textGroup = {
                        order = 20,
                        type = "group",
                        name = "Text",
                        args = {
                            fontHeader = {
                                order = 1,
                                type = "header",
                                name = "Font",
                            },
                            font = {
                                order = 2,
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
                                order = 3,
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
                                order = 4,
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
                            
                            nameTextHeader = {
                                order = 10,
                                type = "header",
                                name = "Name Text",
                            },
                            namePoint = {
                                order = 11,
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
                                order = 12,
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
                                order = 13,
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
                            
                            durationTextHeader = {
                                order = 20,
                                type = "header",
                                name = "Duration Text",
                            },
                            durationPoint = {
                                order = 21,
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
                                order = 22,
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
                                order = 23,
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
                            
                            stackHeader = {
                                order = 30,
                                type = "header",
                                name = "Stack Count",
                            },
                            stackAnchor = {
                                order = 30.5,
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
                                order = 31,
                                type = "select",
                                name = "Stack Position",
                                desc = "Anchor point for the stack count on the icon.",
                                values = {
                                    ["CENTER"] = "Center",
                                    ["TOP"] = "Top",
                                    ["BOTTOM"] = "Bottom",
                                    ["TOPLEFT"] = "Top Left",
                                    ["TOPRIGHT"] = "Top Right",
                                    ["BOTTOMLEFT"] = "Bottom Left",
                                    ["BOTTOMRIGHT"] = "Bottom Right",
                                },
                                get = function() return E.db.thingsUI.buffBars.stackPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.stackPoint = value
                                    wipe(ns.skinnedBars)
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.iconEnabled end,
                            },
                            stackFontSize = {
                                order = 32,
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
                                order = 33,
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
                                order = 34,
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
                                order = 35,
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
                    
                    -----------------------------------------
                    -- ANCHORING SUB-GROUP
                    -----------------------------------------
                    anchoringGroup = {
                        order = 30,
                        type = "group",
                        name = "Anchoring",
                        args = {
                            anchorHeader = {
                                order = 1,
                                type = "header",
                                name = "Anchor Settings",
                            },
                            anchorEnabled = {
                                order = 2,
                                type = "toggle",
                                name = "Enable Anchoring",
                                desc = "Anchor the buff bar container to another frame.",
                                get = function() return E.db.thingsUI.buffBars.anchorEnabled end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorEnabled = value
                                    TUI:UpdateBuffBars()
                                end,
                            },
                            anchorFrame = {
                                order = 3,
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
                                order = 4,
                                type = "select",
                                name = "Anchor From",
                                desc = "The point on the buff bars to anchor.",
                                values = {
                                    ["TOP"] = "TOP",
                                    ["BOTTOM"] = "BOTTOM",
                                    ["LEFT"] = "LEFT",
                                    ["RIGHT"] = "RIGHT",
                                    ["CENTER"] = "CENTER",
                                    ["TOPLEFT"] = "TOPLEFT",
                                    ["TOPRIGHT"] = "TOPRIGHT",
                                    ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                },
                                get = function() return E.db.thingsUI.buffBars.anchorPoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorPoint = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorRelativePoint = {
                                order = 5,
                                type = "select",
                                name = "Anchor To",
                                desc = "The point on the target frame to anchor to.",
                                values = {
                                    ["TOP"] = "TOP",
                                    ["BOTTOM"] = "BOTTOM",
                                    ["LEFT"] = "LEFT",
                                    ["RIGHT"] = "RIGHT",
                                    ["CENTER"] = "CENTER",
                                    ["TOPLEFT"] = "TOPLEFT",
                                    ["TOPRIGHT"] = "TOPRIGHT",
                                    ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                },
                                get = function() return E.db.thingsUI.buffBars.anchorRelativePoint end,
                                set = function(_, value)
                                    E.db.thingsUI.buffBars.anchorRelativePoint = value
                                    TUI:UpdateBuffBars()
                                end,
                                disabled = function() return not E.db.thingsUI.buffBars.anchorEnabled end,
                            },
                            anchorXOffset = {
                                order = 6,
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
                                order = 7,
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
            
            -------------------------------------------------
            -- CLUSTER POSITIONING TAB
            -------------------------------------------------
            clusterPositioningTab = {
                order = 30,
                type = "group",
                name = "BCDM + ElvUI",
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
                    debugHeader = {
                        order = 5,
                        type = "header",
                        name = "Debug Info",
                    },
                    currentLayout = {
                        order = 6,
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
                        order = 9,
                        type = "description",
                        name = "If Utility Icons exceed Essential Icons by the number you set in Icon Settings -> Utility Threshold, UnitFrames will move. \n\nUseful if you have way more Utility than Essential and it starts to overlap.\n",
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
                                min = 20, max = 80, step = 1,
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
                                min = 15, max = 60, step = 1,
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
                                min = -100, max = 100, step = 1,
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
                            playerTargetHeader = {
                                order = 1,
                                type = "header",
                                name = "Player / Target Frame",
                            },
                            playerEnabled = {
                                order = 2,
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
                                order = 3,
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
                                order = 4,
                                type = "range",
                                name = "Frame Gap",
                                desc = "Gap between Player/Target frames and Essential.",
                                min = -50, max = 50, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.frameGap end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.frameGap = value
                                    TUI:QueueClusterUpdate()
                                end,
                            },
                            
                            totHeader = {
                                order = 10,
                                type = "header",
                                name = "Target of Target Frame",
                            },
                            totEnabled = {
                                order = 11,
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
                                order = 12,
                                type = "range",
                                name = "ToT Gap",
                                desc = "Gap between TargetTarget and Target frame.",
                                min = -50, max = 50, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.targetTargetFrame.gap end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.targetTargetFrame.gap = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetTargetFrame.enabled end,
                            },
                            
                            castBarHeader = {
                                order = 20,
                                type = "header",
                                name = "Target Cast Bar",
                            },
                            castBarEnabled = {
                                order = 21,
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
                                order = 22,
                                type = "range",
                                name = "CastBar Y Gap",
                                desc = "Vertical gap between Target frame and CastBar.",
                                min = -50, max = 50, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.gap end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.targetCastBar.gap = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
                            },
                            castBarXOffset = {
                                order = 23,
                                type = "range",
                                name = "CastBar X Offset",
                                desc = "Horizontal offset for CastBar.",
                                min = -100, max = 100, step = 1,
                                get = function() return E.db.thingsUI.clusterPositioning.targetCastBar.xOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.clusterPositioning.targetCastBar.xOffset = value
                                    TUI:QueueClusterUpdate()
                                end,
                                disabled = function() return not E.db.thingsUI.clusterPositioning.enabled or not E.db.thingsUI.clusterPositioning.targetCastBar.enabled end,
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
                                min = -100, max = 100, step = 1,
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
                                min = -100, max = 100, step = 1,
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

            -------------------------------------------------
            -- SPECIAL BARS TAB
            -------------------------------------------------
            specialBarsTab = {
                order = 50,
                type = "group",
                name = "Special Bars",
                -- Bars as tabs (Special Bar 1/2/3)
                childGroups = "tab",
                args = {
                    infoGroup = {
                        order = 1,
                        type = "group",
                        name = "Info",
                        args = {
                            specialBarsHeader = {
                                order = 1,
                                type = "header",
                                name = "Special Bars",
                            },
                            description = {
                                order = 2,
                                type = "description",
                                name = "Yoink individual tracked bars from the BuffBarCooldownViewer and reposition them independently.\n\nEnter the exact spell name as it appears in your Tracked Bars. The bar will be pulled out and displayed at your chosen anchor. It keeps updating in combat because CDM handles the aura tracking internally.\n\n|cFFFFFF00The spell must be in your Tracked Bars list in the Cooldown Manager.|r\n|cFF00FF00Settings are saved per specialization — each spec remembers its own spells and layout.|r",
                            },
                        },
                    },
                    bar1Group = {
                        order = 10,
                        type = "group",
                        name = function() return SpecialBarTabName("bar1", 1) end,
                        childGroups = "tree",
                        args = TUI:SpecialBarOptions("bar1"),
                    },
                    bar2Group = {
                        order = 20,
                        type = "group",
                        name = function() return SpecialBarTabName("bar2", 2) end,
                        childGroups = "tree",
                        args = TUI:SpecialBarOptions("bar2"),
                    },
                    bar3Group = {
                        order = 30,
                        type = "group",
                        name = function() return SpecialBarTabName("bar3", 3) end,
                        childGroups = "tree",
                        args = TUI:SpecialBarOptions("bar3"),
                    },
                    bar4Group = {
                        order = 40,
                        type = "group",
                        name = function() return SpecialBarTabName("bar4", 4) end,
                        childGroups = "tree",
                        args = TUI:SpecialBarOptions("bar4"),
                    },
                    bar5Group = {
                        order = 50,
                        type = "group",
                        name = function() return SpecialBarTabName("bar5", 5) end,
                        childGroups = "tree",
                        args = TUI:SpecialBarOptions("bar5"),
                    },
                },
            },
        },
    }
end