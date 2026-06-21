local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

local C2, C4 = 194 / 255, 68 / 255   -- c2c2c2 / 444444

local function StripTags(s)
    return (s:gsub("%[namecolor%]", ""):gsub("%[classcolor%]", ""))
end

local function ForEachTextFormat(tbl, path, fn)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if k == "text_format" and type(v) == "string" then
            fn(tbl, v, path .. "/text_format")
        elseif type(v) == "table" then
            ForEachTextFormat(v, path .. "/" .. tostring(k), fn)
        end
    end
end

local function SetBackdrop(g)
    local c = E.db.unitframe.colors
    c.health_backdrop = c.health_backdrop or {}
    c.health_backdrop.r, c.health_backdrop.g, c.health_backdrop.b = g, g, g
end

local function RefreshUF()
    local UF = E:GetModule("UnitFrames", true)
    if UF and UF.Update_AllFrames then UF:Update_AllFrames() end
end

local function ApplyClassColored()
    local db = E.db.thingsUI
    if db.uiColoring ~= "class" then   -- snapshot only when leaving dark mode
        local backup = {}
        ForEachTextFormat(E.db.unitframe.units, "units", function(t, v, p)
            local stripped = StripTags(v)
            if stripped ~= v then backup[p] = v; t.text_format = stripped end
        end)
        db.uiColoringBackup = backup
    end
    E.db.unitframe.colors.healthclass = true
    SetBackdrop(C4)
    db.uiColoring = "class"
    RefreshUF()
    print("|cFF8080FFthingsUI|r - UnitFrame Coloring: Class Colored.")
end

local function ApplyDarkMode()
    local db = E.db.thingsUI
    local backup = db.uiColoringBackup
    if backup then
        ForEachTextFormat(E.db.unitframe.units, "units", function(t, _, p)
            if backup[p] then t.text_format = backup[p] end
        end)
    end
    E.db.unitframe.colors.healthclass = false
    SetBackdrop(C2)
    db.uiColoring = "dark"
    RefreshUF()
    print("|cFF8080FFthingsUI|r - UnitFrame Coloring: Dark Mode.")
end
ns.ApplyClassColored = ApplyClassColored
ns.ApplyDarkMode = ApplyDarkMode

-- "Move That Stuff": minimap/auras/DT panels to top-right (shared with the install wizard).
function ns.MoveThatStuff()
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
    print("|cFF8080FFthingsUI|r - Minimap, Auras and DT panels moved to Top Right.")
end

-- Pixel-perfect UI scale (ElvUI's Installer "Auto Scale"). Shared with the install wizard.
function ns.SetAutoScale()
    if not E.PixelBestSize then return end
    local best = E:PixelBestSize()
    E.global.general.UIScale = best
    E:PixelScaleChanged()
    E.ShowPopup = true
    print(string.format("|cFF8080FFthingsUI|r - UI Scale set to %.4f. |cFFFFFF00Reload required.|r", best))
    return best
end

-- Friend ActionBars presets: apply their diff, then refresh bars + movers.
local function ApplyABPreset(name, apply)
    apply()
    local AB = E:GetModule("ActionBars", true)
    if AB and AB.UpdateButtonSettings then AB:UpdateButtonSettings() end
    if E.UpdateMoverPositions then E:UpdateMoverPositions() end
    print("|cFF8080FFthingsUI|r - Applied " .. name .. "'s ActionBars.")
end

function TUI:PositioningTweaksOptions()
    return {
        order = 20,
        type = "group",
        name = "ElvUI QoL",
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
                                func = ns.MoveThatStuff,
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
                                    E.db["movers"]["RightChatMover"] = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-205,2"
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
                                hidden = function() return not E.db.thingsUI.rightChatAsBackground end,
                                func = function()
                                    TUI:ApplyDetailsRightChatAnchor()
                                    print("|cFF8080FFthingsUI|r - Details! chat anchor reapplied.")
                                end,
                            },
                        },
                    },
                    ufColoringGroup = {
                        order = 3,
                        type = "group",
                        name = "UnitFrame Coloring",
                        inline = true,
                        args = {
                            ufColoringDesc = {
                                order = 1,
                                type = "description",
                                name = "Class Colored = class-coloured health bars, dark backdrop, white names.\n Dark Mode normal things colors.\n",
                            },
                            classColored = {
                                order = 2, type = "execute", name = "Class Colored", width = 1.2,
                                func = ApplyClassColored,
                            },
                            darkMode = {
                                order = 3, type = "execute", name = "Dark Mode", width = 1.2,
                                func = ApplyDarkMode,
                            },
                        },
                    },
                    friendPresetsGroup = {
                        order = 4,
                        type = "group",
                        name = "Buddies Presets",
                        inline = true,
                        args = {
                            friendPresetsDesc = {
                                order = 1,
                                type = "description",
                                name = "Some buddys that uses things have made adjustments, the buttons will load their profiles. To revert you'll have to import NHT Profile from wago :)\n\n If you want your preset here, gimme a shout and I'll see what I can do o7\n",
                            },
                            lommes = {
                                order = 2, type = "execute", name = "Nala's profile", width = 1.2,
                                desc = "Just Nalas ActionBars setup atm (he uses 3 bars, 5-1-6 atm tho hehe)",
                                func = function()
                                    ApplyABPreset("Nala (5-1-6)", function()
                                        local a = E.db.actionbar
                                        a.bar1.buttonSize = 40
                                        a.bar1.inheritGlobalFade = true
                                        a.bar3.enabled = false
                                        a.bar4.enabled = false
                                        a.bar5.buttonSize = 40
                                        a.bar5.inheritGlobalFade = true
                                        a.bar6.buttonSize = 40
                                        a.bar6.inheritGlobalFade = true
                                        a.globalFadeAlpha = 0.69
                                        a.lockActionBars = false
                                        local m = E.db.movers
                                        m["ElvAB_1"]  = "BOTTOM,UIParent,BOTTOM,0,47"
                                        m["ElvAB_5"]  = "BOTTOM,UIParent,BOTTOM,0,88"
                                        m["ElvAB_6"]  = "BOTTOM,UIParent,BOTTOM,0,4"
                                    end)
                                end,
                            },
                        },
                    },
        },
    }
end

function TUI:FixesAndQoLOptions()
    return {
        order = 30,
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
                                    E.private["skins"]["blizzard"]["cooldownManager"] = true
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
                                    .. "|cFFFFFF00Sound_NumChannels|r |cFF888888= 32|r - Number of active sound channels. Might help with FPS is the word on the thing.\n"
                                    .. "|cFFFFFF00weatherDensity|r |cFF888888= 0|r - Weather density (default: 0).\n"
                                    .. "|cFFFFFF00RAIDweatherDensity|r |cFF888888= 0|r - Raid weather density (default: 3).\n\n",
                            },
                            cvarsImport = {
                                order = 2,
                                type = "execute",
                                name = "Import CVars",
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
                        name = "Set UI Scale (Auto)",
                        inline = true,
                        args = {
                            uiScaleDesc = {
                                order = 1,
                                type = "description",
                                name = function()
                                    local best = E.PixelBestSize and E:PixelBestSize() or 0
                                    return string.format(
                                        "Snap UI Scale to the pixel-perfect value for your screen (768 / physical height). "
                                        .. "Matches ElvUI's |cFFFFFF00Auto Scale|r in the Installer.\n\n"
                                        .. "Current screen: |cFFFFFF00%s|r -> best scale |cFFFFFF00%.4f|r\n"
                                        .. "Current UI Scale: |cFFFFFF00%.4f|r\n\n"
                                        .. "|cFFFF6B6BReload required after pressing the button.|r\n\n",
                                        E.resolution or "?",
                                        best,
                                        E.global and E.global.general and E.global.general.UIScale or 0
                                    )
                                end,
                            },
                            uiScaleButton = {
                                order = 2,
                                type = "execute",
                                name = function()
                                    local best = E.PixelBestSize and E:PixelBestSize() or 0
                                    return string.format("Set UI Scale (%.4f)", best)
                                end,
                                func = function() ns.SetAutoScale() end,
                            },
                        },
                    },
        },
    }
end
