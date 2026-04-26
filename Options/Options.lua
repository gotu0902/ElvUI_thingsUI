local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local SHARED_ANCHOR_VALUES = ns.ANCHORS.SHARED_ANCHOR_VALUES
local SB = ns.SpecialBars

-- Tracks which source spec is selected in the copy-from dropdowns
local selectedCopySpec = ""

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end

-- Returns number of bar slots and icon slots that have a spell configured
local function CountConfiguredSlots(specData)
    local bars, icons = 0, 0
    if specData.bars then
        for _, slot in pairs(specData.bars) do
            if type(slot) == "table" and slot.spellID then bars = bars + 1 end
        end
    end
    if specData.icons then
        for _, slot in pairs(specData.icons) do
            if type(slot) == "table" and slot.spellID then icons = icons + 1 end
        end
    end
    return bars, icons
end

-- Returns a table of {[specIDstring] = "ClassName - SpecName"} for specs that
-- have saved data, excluding the current spec.
local function GetOtherSpecChoices()
    local choices = { [""] = "|cFF888888— Select Spec —|r" }
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return choices end
    local currentID = tostring(SB and SB.GetSpecRoot and (function()
        local idx = GetSpecialization()
        return idx and select(1, GetSpecializationInfo(idx)) or 0
    end)() or 0)
    for specIDStr, specData in pairs(db.specs) do
        if specIDStr ~= currentID then
            local configuredBars, configuredIcons = CountConfiguredSlots(specData)
            -- Skip specs with nothing configured
            if configuredBars > 0 or configuredIcons > 0 then
                local sid = tonumber(specIDStr)
                local specName, className
                if sid and sid > 0 then
                    local _, sName, _, _, _, _, cName = GetSpecializationInfoByID(sid)
                    specName  = sName  or ("Spec "..specIDStr)
                    className = cName  or ""
                else
                    specName, className = "Spec "..specIDStr, ""
                end
                local label = className ~= "" and (className.." - "..specName) or specName
                label = label .. " |cFF888888("..configuredBars.."b/"..configuredIcons.."i)|r"
                choices[specIDStr] = label
            end
        end
    end
    return choices
end

local function CopySpecSection(sourceKey, copyBars, copyIcons)
    if not sourceKey or sourceKey == "" then return end
    local db = E.db.thingsUI and E.db.thingsUI.specialBars
    if not db or not db.specs then return end
    local src = db.specs[sourceKey]
    if not src then return end

    local dest = SB.GetSpecRoot()

    if copyBars and src.bars then
        dest.barCount = src.barCount or dest.barCount or 3
        dest.bars = dest.bars or {}
        for i = 1, (dest.barCount or 3) do
            local key = "bar"..i
            local srcSlot = src.bars[key]
            if srcSlot then
                SB.ReleaseBar(key)
                dest.bars[key] = DeepCopy(srcSlot)
                -- Keep spellID as-is. If it doesn't exist in this spec's CDM the slot
                -- simply sits inactive — the user can add the spell to CDM or pick a new one.
            end
        end
    end

    if copyIcons and src.icons then
        dest.iconCount = src.iconCount or dest.iconCount or 3
        dest.icons = dest.icons or {}
        for i = 1, (dest.iconCount or 3) do
            local key = "icon"..i
            local srcSlot = src.icons[key]
            if srcSlot then
                SB.ReleaseIcon(key)
                dest.icons[key] = DeepCopy(srcSlot)
            end
        end
    end

    TUI:UpdateSpecialBars()
    NotifyChange()
end

local function BarTabName(barKey, index)
    if not SB then return ("Bar %d"):format(index) end
    local db = SB.GetBarDB(barKey) or {}
    local name = db.spellName or ""
    if name == "" then return ("Bar %d"):format(index) end
    -- Warn if the spell isn't in the current spec's CDM list
    local inCDM = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then
        return ("|cFFFF4444! Bar %d: %s|r"):format(index, name)
    end
    return ("Bar %d: %s"):format(index, name)
end

local function IconTabName(iconKey, index)
    if not SB then return ("Icon %d"):format(index) end
    local db = SB.GetIconDB(iconKey) or {}
    local name = db.spellName or ""
    if name == "" then return ("Icon %d"):format(index) end
    local inCDM = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
    if not inCDM then
        return ("|cFFFF4444! Icon %d: %s|r"):format(index, name)
    end
    return ("Icon %d: %s"):format(index, name)
end

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
                name = "Skin Buff Bars, automatically move frames when using BCDM and CDM icons increase, seperate Tracked Bars with Special Bars o7.\n\n",
            },
            
            -------------------------------------------------
            -- GENERAL TAB
            -------------------------------------------------
            generalTab = {
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
                                    E.db["movers"]["DebuffsMover"] = "TOPRIGHT,UIParent,TOPRIGHT,-216,-101"
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
                                    E.db["movers"]["DebuffsMover"] = "TOPLEFT,ElvUIParent,TOPLEFT,2,-101"
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
                    },          -- end detailsChatGroup
                    },          -- end positioningTab args
                },              -- end positioningTab
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
                    },  -- end fixesTab args
                },      -- end fixesTab
                },      -- end generalTab args
            },          -- end generalTab

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
                                        values = {
                                            ["CENTER"] = "Center",
                                            ["LEFT"] = "Left",
                                            ["RIGHT"] = "Right",
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
                                        order = 4,
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
            },
            
            -------------------------------------------------
            -- CLUSTER POSITIONING TAB
            -------------------------------------------------
            clusterPositioningTab = {
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
                                        min = -50, max = 50, step = 1,
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
                                        min = -50, max = 50, step = 1,
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
                                        min = -50, max = 50, step = 1,
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
                childGroups = "tab",
                args = {
                    controlGroup = {
                        order = 1, type = "group", name = "Manage",
                        args = {
                            desc = { order = 1, type = "description",
                                name = "Pull individual Tracked Buff bars from the Cooldown Manager and reposition them anywhere.\n\nSettings are saved per specialization.\n" },
                            barCountHeader = { order = 2, type = "header", name = "Special Bars" },
                            barCount = {
                                order = 3, type = "range", name = "Number of Bar Slots", min = 1, max = 12, step = 1,
                                get = function() if not SB then return 3 end; return SB.GetSpecRoot().barCount or 3 end,
                                set = function(_, v)
                                    if not SB then return end
                                    local old = SB.GetSpecRoot().barCount or 3
                                    SB.GetSpecRoot().barCount = v
                                    if v < old then
                                        for i = v+1, old do SB.ReleaseBar("bar"..i) end
                                        TUI:UpdateSpecialBars()
                                    end
                                    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
                                    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
                                end,
                            },
                            copyHeader = { order = 10, type = "header", name = "Copy from Another Spec" },
                            copyDesc = { order = 11, type = "description",
                                name = "Copies bar settings from another spec. Spells not available in the current spec are set to None.\n" },
                            copySpecSelect = {
                                order = 12, type = "select", name = "Copy From", width = "double",
                                values = GetOtherSpecChoices,
                                get = function() return selectedCopySpec end,
                                set = function(_, v) selectedCopySpec = v; NotifyChange() end,
                            },
                            copyBarsButton = {
                                order = 13, type = "execute", name = "Copy Bars",
                                disabled = function() return not selectedCopySpec or selectedCopySpec == "" end,
                                confirm = function() return "Overwrite your current bar settings with bars from the selected spec?" end,
                                func = function() CopySpecSection(selectedCopySpec, true, false) end,
                            },
                        },
                    },
                    bar1Group  = { order=10,  type="group", childGroups="tree", name=function() return BarTabName("bar1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 1  end, args=TUI:SpecialBarOptions("bar1")  },
                    bar2Group  = { order=20,  type="group", childGroups="tree", name=function() return BarTabName("bar2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 2  end, args=TUI:SpecialBarOptions("bar2")  },
                    bar3Group  = { order=30,  type="group", childGroups="tree", name=function() return BarTabName("bar3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 3  end, args=TUI:SpecialBarOptions("bar3")  },
                    bar4Group  = { order=40,  type="group", childGroups="tree", name=function() return BarTabName("bar4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 4  end, args=TUI:SpecialBarOptions("bar4")  },
                    bar5Group  = { order=50,  type="group", childGroups="tree", name=function() return BarTabName("bar5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 5  end, args=TUI:SpecialBarOptions("bar5")  },
                    bar6Group  = { order=60,  type="group", childGroups="tree", name=function() return BarTabName("bar6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 6  end, args=TUI:SpecialBarOptions("bar6")  },
                    bar7Group  = { order=70,  type="group", childGroups="tree", name=function() return BarTabName("bar7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 7  end, args=TUI:SpecialBarOptions("bar7")  },
                    bar8Group  = { order=80,  type="group", childGroups="tree", name=function() return BarTabName("bar8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 8  end, args=TUI:SpecialBarOptions("bar8")  },
                    bar9Group  = { order=90,  type="group", childGroups="tree", name=function() return BarTabName("bar9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 9  end, args=TUI:SpecialBarOptions("bar9")  },
                    bar10Group = { order=100, type="group", childGroups="tree", name=function() return BarTabName("bar10",10) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 10 end, args=TUI:SpecialBarOptions("bar10") },
                    bar11Group = { order=110, type="group", childGroups="tree", name=function() return BarTabName("bar11",11) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 11 end, args=TUI:SpecialBarOptions("bar11") },
                    bar12Group = { order=120, type="group", childGroups="tree", name=function() return BarTabName("bar12",12) end, hidden=function() return not SB or (SB.GetSpecRoot().barCount or 3) < 12 end, args=TUI:SpecialBarOptions("bar12") },
                },
            },

            specialIconsTab = {
                order = 51,
                type = "group",
                name = "Special Icons",
                childGroups = "tab",
                args = {
                    controlGroup = {
                        order = 1, type = "group", name = "Manage",
                        args = {
                            iconCountHeader = { order = 1, type = "header", name = "Special Icons" },
                            iconCount = {
                                order = 2, type = "range", name = "Number of Icon Slots", min = 1, max = 12, step = 1,
                                get = function() if not SB then return 3 end; return SB.GetSpecRoot().iconCount or 3 end,
                                set = function(_, v)
                                    if not SB then return end
                                    local old = SB.GetSpecRoot().iconCount or 3
                                    SB.GetSpecRoot().iconCount = v
                                    if v < old then
                                        for i = v+1, old do SB.ReleaseIcon("icon"..i) end
                                        TUI:UpdateSpecialBars()
                                    end
                                    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
                                    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
                                end,
                            },
                            copyHeader = { order = 10, type = "header", name = "Copy from Another Spec" },
                            copyDesc = { order = 11, type = "description",
                                name = "Copies icon settings from another spec. Spells not available in the current spec are set to None.\n" },
                            copySpecSelect = {
                                order = 12, type = "select", name = "Copy From", width = "double",
                                values = GetOtherSpecChoices,
                                get = function() return selectedCopySpec end,
                                set = function(_, v) selectedCopySpec = v; NotifyChange() end,
                            },
                            copyIconsButton = {
                                order = 13, type = "execute", name = "Copy Icons",
                                disabled = function() return not selectedCopySpec or selectedCopySpec == "" end,
                                confirm = function() return "Overwrite your current icon settings with icons from the selected spec?" end,
                                func = function() CopySpecSection(selectedCopySpec, false, true) end,
                            },
                        },
                    },
                    icon1Group  = { order=201, type="group", childGroups="tree", name=function() return IconTabName("icon1",1)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 1  end, args=TUI:SpecialIconOptions("icon1")  },
                    icon2Group  = { order=202, type="group", childGroups="tree", name=function() return IconTabName("icon2",2)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 2  end, args=TUI:SpecialIconOptions("icon2")  },
                    icon3Group  = { order=203, type="group", childGroups="tree", name=function() return IconTabName("icon3",3)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 3  end, args=TUI:SpecialIconOptions("icon3")  },
                    icon4Group  = { order=204, type="group", childGroups="tree", name=function() return IconTabName("icon4",4)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 4  end, args=TUI:SpecialIconOptions("icon4")  },
                    icon5Group  = { order=205, type="group", childGroups="tree", name=function() return IconTabName("icon5",5)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 5  end, args=TUI:SpecialIconOptions("icon5")  },
                    icon6Group  = { order=206, type="group", childGroups="tree", name=function() return IconTabName("icon6",6)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 6  end, args=TUI:SpecialIconOptions("icon6")  },
                    icon7Group  = { order=207, type="group", childGroups="tree", name=function() return IconTabName("icon7",7)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 7  end, args=TUI:SpecialIconOptions("icon7")  },
                    icon8Group  = { order=208, type="group", childGroups="tree", name=function() return IconTabName("icon8",8)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 8  end, args=TUI:SpecialIconOptions("icon8")  },
                    icon9Group  = { order=209, type="group", childGroups="tree", name=function() return IconTabName("icon9",9)   end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 9  end, args=TUI:SpecialIconOptions("icon9")  },
                    icon10Group = { order=210, type="group", childGroups="tree", name=function() return IconTabName("icon10",10) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 10 end, args=TUI:SpecialIconOptions("icon10") },
                    icon11Group = { order=211, type="group", childGroups="tree", name=function() return IconTabName("icon11",11) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 11 end, args=TUI:SpecialIconOptions("icon11") },
                    icon12Group = { order=212, type="group", childGroups="tree", name=function() return IconTabName("icon12",12) end, hidden=function() return not SB or (SB.GetSpecRoot().iconCount or 3) < 12 end, args=TUI:SpecialIconOptions("icon12") },
                },
            },

            -------------------------------------------------
            -- CLASSBAR MODE TAB
            -------------------------------------------------
            classbarModeTab = TUI:ClassbarModeOptions(),
        },
    }
end