local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

function TUI:GeneralOptions()
    return {
        order = 10,
        type = "group",
        name = "General",
        childGroups = "tab",
        args = {
            generalSubTab = {
                order = 1,
                type = "group",
                name = "General",
                args = {
                    buffIconsGroup = {
                        order = 1,
                        type = "group",
                        name = "Buff Icon Viewer (BuffIconCooldownViewer)",
                        inline = true,
                        args = {
                            verticalBuffs = {
                                order = 1,
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
                                order = 2,
                                type = "description",
                                name = "\n|cFFFFFF00Used for FHT (Healing).|r If disabling, you may need to reload UI to restore default horizontal layout.\n",
                            },
                        },
                    },
                },
            },
            positioningTab = {
                order = 2,
                type = "group",
                name = "Positioning Tweaks",
                args = {
                    minimapGroup = {
                        order = 1,
                        type = "group",
                        name = "Minimap & Aura Positions",
                        inline = true,
                        args = {
                            positionsTRDescription = {
                                order = 1,
                                type = "description",
                                name = "Move Minimap, auras and DT panels to top right, Details! to bottom right (if chat anchoring enabled).\n\n",
                            },
                            positionTopRight = {
                                order = 2,
                                type = "execute",
                                name = "Move! That! Stuff!",
                                func = function()
                                    E.db["movers"]["MinimapMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-2,-2"
                                    E.db["movers"]["VehicleLeaveButton"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-152,-2"
                                    E.db["movers"]["QueueStatusMover"] = "TOPRIGHT,UIParent,TOPRIGHT,-10,-14"
                                    E.db["movers"]["DTPanelFriends and GuildMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-170"
                                    E.db["movers"]["DTPanelSystemMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-139,-174"
                                    E.db["movers"]["DTPanelTimeMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-76,-185"
                                    E.db["movers"]["BuffsMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-217,-2"
                                    E.db["auras"]["buffs"]["growthDirection"] = "LEFT_DOWN"
                                    E.db["movers"]["DebuffsMover"] = "TOPRIGHT,UIParent,TOPRIGHT,-216,-120"
                                    E.db["auras"]["debuffs"]["growthDirection"] = "LEFT_DOWN"
                                    E.db["movers"]["GMMover"] = "TOPLEFT,ElvUIParent,TOPLEFT,635,-2"
                                    E.db["movers"]["RightChatMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-2,2"
                                    E:UpdateMoverPositions()
                                    E:UpdateAuras()
                                    print("|cFF8080FFthingsUI|r - Minimap Auras and DT panels moved to Top Right, Details! bottom right (if chat anchoring enabled).")
                                end,
                            },
                            positionsGruffDescription = {
                                order = 3,
                                type = "description",
                                name = "\nMove them back to default positions.",
                            },
                            positionGruff = {
                                order = 4,
                                type = "execute",
                                name = "Reset to default",
                                func = function()
                                    E.db["movers"]["MinimapMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-2,2"
                                    E.db["movers"]["VehicleLeaveButton"] = "BOTTOMRIGHT,UIParent,BOTTOMRIGHT,-151,152"
                                    E.db["movers"]["QueueStatusMover"] = "BOTTOMRIGHT,UIParent,BOTTOMRIGHT,-9,176"
                                    E.db["movers"]["DTPanelFriends and GuildMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,0,5"
                                    E.db["movers"]["DTPanelSystemMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-142,1"
                                    E.db["movers"]["DTPanelTimeMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-68,1"
                                    E.db["movers"]["BuffsMover"] = "TOPLEFT,ElvUIParent,TOPLEFT,2,-2"
                                    E.db["auras"]["buffs"]["growthDirection"] = "RIGHT_DOWN"
                                    E.db["movers"]["DebuffsMover"] = "TOPLEFT,ElvUIParent,TOPLEFT,2,-120"
                                    E.db["auras"]["debuffs"]["growthDirection"] = "RIGHT_DOWN"
                                    E.db["movers"]["GMMover"] = "TOPRIGHT,ElvUIParent,TOPRIGHT,-377,-2"
                                    E.db["movers"]["RightChatMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-202,2"
                                    E:UpdateMoverPositions()
                                    E:UpdateAuras()
                                    print("|cFF8080FFthingsUI|r - Minimap, Auras and Details! reset to default positions.")
                                end,
                            },
                        },
                    },
                    detailsChatGroup = {
                        order = 2,
                        type = "group",
                        name = "Details! Chat Backdrop",
                        inline = true,
                        args = {
                            rightChatBackdropDescription = {
                                order = 1,
                                type = "description",
                                name = "Use ElvUI's Right Chat Panel as a backdrop for Details! windows 1 & 2, side by side inside it.\n",
                            },
                            rightChatBackdrop = {
                                order = 2,
                                type = "toggle",
                                name = "Enable",
                                desc = "Enables the right chat panel backdrop, sets its size, and places Details! windows 1 & 2 side by side inside it.",
                                width = "full",
                                get = function() return E.db.thingsUI.rightChatAsBackground end,
                                set = function(_, value)
                                    E.db.thingsUI.rightChatAsBackground = value
                                    if value then
                                        TUI:ApplyDetailsRightChatAnchor()
                                        print("|cFF8080FFthingsUI|r - Right Chat Backdrop enabled. Details! anchored inside panel.")
                                    else
                                        local LO = E:GetModule("Layout")
                                        local CH = E:GetModule("Chat")
                                        local current = E.db["chat"]["panelBackdrop"] or "RIGHT"
                                        if current == "RIGHT" then
                                            E.db["chat"]["panelBackdrop"] = "HIDEBOTH"
                                        elseif current == "SHOWBOTH" then
                                            E.db["chat"]["panelBackdrop"] = "LEFT"
                                        end
                                        if LO and LO.ToggleChatPanels then LO:ToggleChatPanels() end
                                        if CH then
                                            if CH.PositionChats then CH:PositionChats() end
                                            if CH.UpdateEditboxAnchors then CH:UpdateEditboxAnchors() end
                                        end
                                        print("|cFF8080FFthingsUI|r - Right Chat Backdrop disabled.")
                                    end
                                end,
                            },
                            rightChatWidthOffset = {
                                order = 3,
                                type = "range",
                                name = "Width Offset",
                                desc = "Fine-tune the right chat panel width. Applied on top of the auto-calculated size.",
                                hidden = function() return not E.db.thingsUI.rightChatAsBackground end,
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.rightChatWidthOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.rightChatWidthOffset = value
                                    TUI:ApplyDetailsRightChatAnchor()
                                end,
                            },
                            rightChatHeightOffset = {
                                order = 4,
                                type = "range",
                                name = "Height Offset",
                                desc = "Fine-tune the right chat panel height. Applied on top of the auto-calculated size.",
                                hidden = function() return not E.db.thingsUI.rightChatAsBackground end,
                                min = -500, max = 500, step = 0.01, bigStep = 1,
                                get = function() return E.db.thingsUI.rightChatHeightOffset end,
                                set = function(_, value)
                                    E.db.thingsUI.rightChatHeightOffset = value
                                    TUI:ApplyDetailsRightChatAnchor()
                                end,
                            },
                            rightChatReapply = {
                                order = 5,
                                type = "execute",
                                name = "Reapply",
                                desc = "Reapply sizing and anchors — use this if you've resized Details! windows or the ElvUI right chat panel.",
                                hidden = function() return not E.db.thingsUI.rightChatAsBackground end,
                                func = function()
                                    TUI:ApplyDetailsRightChatAnchor()
                                    print("|cFF8080FFthingsUI|r - Details! chat anchor reapplied.")
                                end,
                            },
                        },
                    },
                },
            },
            fixesTab = {
                order = 3,
                type = "group",
                name = "Fixes and QoL",
                args = {
                    psettingsGroup = {
                        order = 1,
                        type = "group",
                        name = "Import settings.",
                        inline = true,
                        args = {
                            psettingsDescription = {
                                order = 1,
                                type = "description",
                                name = "Alternative to import ElvUI private settings.\n\n|cFFFF6B6BWarning:|r This will overwrite your Private Profile settings!\n\n",
                            },
                            psettingsImport = {
                                order = 2,
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
                    cvarsGroup = {
                        order = 2,
                        type = "group",
                        name = "Import CVars",
                        inline = true,
                        args = {
                            cvarsDescription = {
                                order = 1,
                                type = "description",
                                name = "Applies the following World of Warcraft audio/graphics CVars:\n\n"
                                    .. "|cFFFFFF00Sound_NumChannels|r |cFF888888= 32|r — Number of active sound channels. Might help with FPS is the word on the thing.\n"
                                    .. "|cFFFFFF00weatherDensity|r |cFF888888= 0|r — Weather density (default: 0).\n"
                                    .. "|cFFFFFF00RAIDweatherDensity|r |cFF888888= 0|r — Raid weather density (default: 3).\n\n",
                            },
                            cvarsImport = {
                                order = 2,
                                type = "execute",
                                name = "Import CVars",
                                desc = "Apply the listed CVars.",
                                func = function()
                                    SetCVar("Sound_NumChannels", 32)
                                    SetCVar("weatherDensity", 0)
                                    SetCVar("RAIDweatherDensity", 0)
                                    print("|cFF8080FFthingsUI|r - CVars applied: Sound_NumChannels=32, weatherDensity=0, RAIDweatherDensity=0.")
                                end,
                            },
                            autoSetAudioChannels = {
                                order = 3,
                                type = "toggle",
                                name = "Auto-set Sound Channels on Login",
                                desc = "Automatically set Sound_NumChannels to 32 each time you enter the world. Since something keeps resetting this CVar.",
                                width = "full",
                                get = function() return E.db.thingsUI.autoSetAudioChannels end,
                                set = function(_, value)
                                    E.db.thingsUI.autoSetAudioChannels = value
                                end,
                            },
                        },
                    },
                    UIScaleGroup = {
                        order = 3,
                        type = "group",
                        name = "Set UI Scale for 1440p",
                        inline = true,
                        args = {
                            uiScaleDesc = {
                                order = 1,
                                type = "description",
                                name = "If stuff looks weird, you must reset UI Scale to 0.53, or click this button.\n\n|cFFFF6B6BReload required|r\n\n",
                            },
                            uiScaleButton = {
                                order = 2,
                                type = "execute",
                                name = "Set UI Scale (0.53)",
                                func = function()
                                    E.global.general.UIScale = 0.53
                                    E:PixelScaleChanged()
                                    E.ShowPopup = true
                                    print("|cFF8080FFthingsUI|r - UI Scale set to 0.53. |cFFFFFF00Reload required.|r")
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end
