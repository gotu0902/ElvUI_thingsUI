local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM
local anchors = ns.ANCHORS.SPECIAL_BAR_ANCHOR_VALUES
local GetSpecialBarSlotDB = ns.SpecialBars.GetSpecialBarSlotDB
local ReleaseSpecialBar = ns.SpecialBars.ReleaseSpecialBar
local ScanAndHookCDMChildren = ns.SpecialBars.ScanAndHookCDMChildren
local SPECIAL_BAR_DEFAULTS = ns.SpecialBars.SPECIAL_BAR_DEFAULTS
local CleanString = ns.SpecialBars.CleanString
local specialBarState = ns.SpecialBars.specialBarState

function TUI:SpecialBarOptions(barKey)
    local function get(key) return GetSpecialBarSlotDB(barKey)[key] end
    local function set(key, value)
        GetSpecialBarSlotDB(barKey)[key] = value
        if TUI.QueueSpecialBarsUpdate then
            TUI:QueueSpecialBarsUpdate()
        else
            TUI:UpdateSpecialBars()
        end
    end
    local function setWipe(key, value)
        GetSpecialBarSlotDB(barKey)[key] = value
        if TUI.QueueSpecialBarsUpdate then
            TUI:QueueSpecialBarsUpdate()
        else
            TUI:UpdateSpecialBars()
        end
    end
    
    return {
        specInfo = {
            order = 0, type = "description", width = "full",
            name = function()
                local specIndex = GetSpecialization()
                local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or "Unknown"
                return "|cFFFFFF00Current spec: " .. specName .. "|r  (settings are saved per spec)"
            end,
        },
        enabled = {
            order = 1, type = "toggle", name = "Enable", width = "full",
            get = function() return get("enabled") end,
            set = function(_, v)
                if not v then ReleaseSpecialBar(barKey) end
                GetSpecialBarSlotDB(barKey).enabled = v
                TUI:UpdateSpecialBars()
            end,
        },
        spellName = {
            order = 2, type = "input", name = "Spell Name", width = "double",
            desc = "Exact spell name as shown in Tracked Bars (e.g., Ironfur, Frenzied Regeneration).",
            get = function() return get("spellName") end,
            set = function(_, v)
                -- Fully release and clear any cached state
                ReleaseSpecialBar(barKey)
                specialBarState[barKey] = nil
                        GetSpecialBarSlotDB(barKey).spellName = v
                -- Delay to let CDM reclaim the released bar
                C_Timer.After(0.15, function()
                    TUI:UpdateSpecialBars()
                end)
            end,
        },
        spellStatus = {
            order = 3, type = "description", width = "full",
            name = function()
                local name = GetSpecialBarSlotDB(barKey).spellName or ""
                if name == "" then return "" end
                if not BuffBarCooldownViewer then return "|cFFFF8800BuffBarCooldownViewer not found — open Cooldown Manager settings to initialize it|r" end
                if InCombatLockdown() then return "|cFFFFFF00Status check unavailable in combat|r" end
                
                -- Force a fresh scan for new CDM children every time this status is checked
                ScanAndHookCDMChildren()
                
                -- Check if this bar is currently yoinked and active
                local state = specialBarState[barKey]
                if state and state.childFrame and state.wrapper then
                    local isShown = false
                    pcall(function() isShown = state.wrapper:IsShown() end)
                    if isShown then
                        return "|cFF00FF00 Active (yoinked from Tracked Bars)|r"
                    end
                end
                
                -- Check all CDM children (including wrappers we may have created)
                local found = false
                local targetName = CleanString(name)
                
                pcall(function()
                    local children = { BuffBarCooldownViewer:GetChildren() }
                    for _, cf in ipairs(children) do
                        local match = false
                        if cf.Bar and cf.Bar.Name then
                            local t = CleanString(cf.Bar.Name:GetText())
                            if t and t == targetName then match = true end
                        end
                        if not match and cf.auraSpellID then
                            local targetID = tonumber(targetName)
                            if targetID and targetID == cf.auraSpellID then match = true end
                        end
                        if match then found = true end
                    end
                end)
                if found then
                    return "|cFF00FF00 Found in Tracked Bars|r"
                end
                
                -- Also check if another special bar already yoinked this spell
                for otherKey, otherState in pairs(specialBarState) do
                    if otherKey ~= barKey and otherState.childFrame then
                        local match = false
                        pcall(function()
                            local t = CleanString(otherState.childFrame.Bar.Name:GetText())
                            if t and t == targetName then match = true end
                        end)
                        if match then
                            return "|cFFFF8800 Found but yoinked by " .. otherKey .. "|r"
                        end
                    end
                end

                return "|cFFFF0000 Not found in Tracked Bars yet|r — Open CDM to force a scan, tab back in and out of this tab to check. Otherwise it's not in the Tracked Bars or may be misspelled. Or doesn't exist"
            end,
        },
        
        layoutHeader = { order = 10, type = "header", name = "Layout" },
        width = {
            order = 11, type = "range", name = "Width", min = 50, max = 500, step = 1,
            get = function() return get("width") end,
            set = function(_, v) setWipe("width", v) end,
            disabled = function() return get("inheritWidth") end,
        },
        inheritWidth = {
            order = 11.5, type = "toggle", name = "Inherit Width from Anchor",
            desc = "Automatically match the width of the anchor frame.",
            get = function() return get("inheritWidth") end,
            set = function(_, v) setWipe("inheritWidth", v) end,
        },
        inheritWidthOffset = {
            order = 11.6, type = "range", name = "Width Nudge",
            desc = "Fine-tune the inherited width.",
            min = -10, max = 10, step = 0.01, bigStep = 0.5,
            get = function() return get("inheritWidthOffset") end,
            set = function(_, v) setWipe("inheritWidthOffset", v) end,
            disabled = function() return not get("inheritWidth") end,
        },
        height = {
            order = 12, type = "range", name = "Height", min = 8, max = 60, step = 1,
            get = function() return get("height") end,
            set = function(_, v) setWipe("height", v) end,
            disabled = function() return get("inheritHeight") end,
        },
        inheritHeight = {
            order = 12.5, type = "toggle", name = "Inherit Height from Anchor",
            desc = "Automatically match the height of the anchor frame.",
            get = function() return get("inheritHeight") end,
            set = function(_, v) setWipe("inheritHeight", v) end,
        },
        inheritHeightOffset = {
            order = 12.6, type = "range", name = "Height Nudge",
            desc = "Fine-tune the inherited height.",
            min = -10, max = 10, step = 0.01, bigStep = 0.5,
            get = function() return get("inheritHeightOffset") end,
            set = function(_, v) setWipe("inheritHeightOffset", v) end,
            disabled = function() return not get("inheritHeight") end,
        },
        statusBarTexture = {
            order = 13, type = "select", name = "Texture",
            dialogControl = "LSM30_Statusbar", values = LSM:HashTable("statusbar"),
            get = function() return get("statusBarTexture") end,
            set = function(_, v) setWipe("statusBarTexture", v) end,
        },
        useClassColor = {
            order = 14, type = "toggle", name = "Use Class Color",
            get = function() return get("useClassColor") end,
            set = function(_, v) setWipe("useClassColor", v) end,
        },
        customColor = {
            order = 15, type = "color", name = "Custom Color", hasAlpha = false,
            disabled = function() return get("useClassColor") end,
            get = function() local c = get("customColor"); return c.r, c.g, c.b end,
            set = function(_, r, g, b) setWipe("customColor", { r = r, g = g, b = b }) end,
        },
        
        iconHeader = { order = 20, type = "header", name = "Icon" },
        iconEnabled = {
            order = 21, type = "toggle", name = "Show Icon",
            get = function() return get("iconEnabled") end,
            set = function(_, v) setWipe("iconEnabled", v) end,
        },
        iconSpacing = {
            order = 22, type = "range", name = "Icon Spacing", min = 0, max = 10, step = 1,
            get = function() return get("iconSpacing") end,
            set = function(_, v) setWipe("iconSpacing", v) end,
            disabled = function() return not get("iconEnabled") end,
        },
        iconZoom = {
            order = 23, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true,
            get = function() return get("iconZoom") end,
            set = function(_, v) setWipe("iconZoom", v) end,
            disabled = function() return not get("iconEnabled") end,
        },
        
        textHeader = { order = 30, type = "header", name = "Text" },
        font = {
            order = 31, type = "select", name = "Font",
            dialogControl = "LSM30_Font", values = LSM:HashTable("font"),
            get = function() return get("font") end,
            set = function(_, v) setWipe("font", v) end,
        },
        fontSize = {
            order = 32, type = "range", name = "Font Size", min = 6, max = 30, step = 1,
            get = function() return get("fontSize") end,
            set = function(_, v) setWipe("fontSize", v) end,
        },
        fontOutline = {
            order = 33, type = "select", name = "Font Outline",
            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
            get = function() return get("fontOutline") end,
            set = function(_, v) setWipe("fontOutline", v) end,
        },
        showName = {
            order = 34, type = "toggle", name = "Show Name",
            get = function() return get("showName") end,
            set = function(_, v) setWipe("showName", v) end,
        },
        namePoint = {
            order = 35, type = "select", name = "Name Alignment",
            values = { ["LEFT"] = "Left", ["CENTER"] = "Center", ["RIGHT"] = "Right" },
            get = function() return get("namePoint") end,
            set = function(_, v) setWipe("namePoint", v) end,
            disabled = function() return not get("showName") end,
        },
        nameXOffset = {
            order = 36, type = "range", name = "Name X Offset", min = -50, max = 50, step = 0.5,
            get = function() return get("nameXOffset") end,
            set = function(_, v) setWipe("nameXOffset", v) end,
            disabled = function() return not get("showName") end,
        },
        nameYOffset = {
            order = 37, type = "range", name = "Name Y Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("nameYOffset") end,
            set = function(_, v) setWipe("nameYOffset", v) end,
            disabled = function() return not get("showName") end,
        },
        
        durationHeader = { order = 37.4, type = "header", name = "Duration" },
        showDuration = {
            order = 37.5, type = "toggle", name = "Show Duration",
            get = function() return get("showDuration") end,
            set = function(_, v) setWipe("showDuration", v) end,
        },
        durationPoint = {
            order = 38,
            type = "select",
            name = "Duration Alignment",
            values = {
                ["LEFT"] = "Left",
                ["CENTER"] = "Center",
                ["RIGHT"] = "Right",
            },
            get = function() return get("durationPoint") end,
            set = function(_, v) setWipe("durationPoint", v) end,
            disabled = function() return not get("showDuration") end,
        },
        durationXOffset = {
            order = 39,
            type = "range",
            name = "Duration X Offset",
            min = -50, max = 50, step = 0.5,
            get = function() return get("durationXOffset") end,
            set = function(_, v) setWipe("durationXOffset", v) end,
            disabled = function() return not get("showDuration") end,
        },
        durationYOffset = {
            order = 40,
            type = "range",
            name = "Duration Y Offset",
            min = -20, max = 20, step = 0.5,
            get = function() return get("durationYOffset") end,
            set = function(_, v) setWipe("durationYOffset", v) end,
            disabled = function() return not get("showDuration") end,
        },
        
        stackHeader = { order = 40, type = "header", name = "Stack Count" },
        showStacks = {
            order = 41, type = "toggle", name = "Show Stack Count",
            get = function() return get("showStacks") end,
            set = function(_, v) setWipe("showStacks", v) end,
        },
        stackAnchor = {
            order = 41.5, type = "select", name = "Stack Anchor",
            desc = "Anchor the stack count to the Icon or the Bar.",
            values = { ["ICON"] = "Icon", ["BAR"] = "Bar" },
            get = function() return get("stackAnchor") or "ICON" end,
            set = function(_, v) setWipe("stackAnchor", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackFontSize = {
            order = 42, type = "range", name = "Stack Font Size", min = 6, max = 36, step = 1,
            get = function() return get("stackFontSize") end,
            set = function(_, v) setWipe("stackFontSize", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackFontOutline = {
            order = 43, type = "select", name = "Stack Outline",
            values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline" },
            get = function() return get("stackFontOutline") end,
            set = function(_, v) setWipe("stackFontOutline", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackPoint = {
            order = 44, type = "select", name = "Stack Position",
            values = { ["CENTER"] = "Center", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOP"] = "Top", ["BOTTOM"] = "Bottom" },
            get = function() return get("stackPoint") end,
            set = function(_, v) setWipe("stackPoint", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackXOffset = {
            order = 45, type = "range", name = "Stack X Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("stackXOffset") end,
            set = function(_, v) setWipe("stackXOffset", v) end,
            disabled = function() return not get("showStacks") end,
        },
        stackYOffset = {
            order = 46, type = "range", name = "Stack Y Offset", min = -20, max = 20, step = 0.5,
            get = function() return get("stackYOffset") end,
            set = function(_, v) setWipe("stackYOffset", v) end,
            disabled = function() return not get("showStacks") end,
        },
        
        backdropHeader = { order = 48, type = "header", name = "Backdrop" },
        showBackdrop = {
            order = 48.1, type = "toggle", name = "Show Backdrop",
            desc = "Show a persistent background behind the bar slot, visible even when the aura is not active.",
            get = function() return get("showBackdrop") end,
            set = function(_, v) setWipe("showBackdrop", v) end,
        },
        backdropColor = {
            order = 48.2, type = "color", name = "Backdrop Color", hasAlpha = true,
            get = function()
                local c = get("backdropColor") or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
                return c.r, c.g, c.b, c.a
            end,
            set = function(_, r, g, b, a) setWipe("backdropColor", { r = r, g = g, b = b, a = a }) end,
            disabled = function() return not get("showBackdrop") end,
        },
        
        anchorHeader = { order = 50, type = "header", name = "Anchor" },
        anchorMode = {
            order = 51, type = "select", name = "Anchor To", width = "double",
            desc = "Choose a predefined frame or select Custom to type a frame name.",
            values = anchors,
            get = function() return get("anchorMode") or get("anchorFrame") or "ElvUF_Player" end,
            set = function(_, v)
                GetSpecialBarSlotDB(barKey).anchorMode = v
                if v ~= "CUSTOM" then
                    GetSpecialBarSlotDB(barKey).anchorFrame = v
                end
                TUI:UpdateSpecialBars()
            end,
        },
        anchorFrame = {
            order = 51.5, type = "input", name = "Custom Frame Name", width = "double",
            desc = "Type the exact frame name (e.g., ElvUF_Player, UIParent).",
            get = function() return get("anchorFrame") end,
            set = function(_, v) set("anchorFrame", v) end,
            hidden = function() return (get("anchorMode") or get("anchorFrame") or "ElvUF_Player") ~= "CUSTOM" end,
        },
        anchorPoint = {
            order = 52, type = "select", name = "Point",
            values = { ["TOP"] = "TOP", ["BOTTOM"] = "BOTTOM", ["LEFT"] = "LEFT", ["RIGHT"] = "RIGHT", ["CENTER"] = "CENTER",
                       ["TOPLEFT"] = "TOPLEFT", ["TOPRIGHT"] = "TOPRIGHT", ["BOTTOMLEFT"] = "BOTTOMLEFT", ["BOTTOMRIGHT"] = "BOTTOMRIGHT" },
            get = function() return get("anchorPoint") end,
            set = function(_, v) set("anchorPoint", v) end,
        },
        anchorRelativePoint = {
            order = 53, type = "select", name = "Relative Point",
            values = { ["TOP"] = "TOP", ["BOTTOM"] = "BOTTOM", ["LEFT"] = "LEFT", ["RIGHT"] = "RIGHT", ["CENTER"] = "CENTER",
                       ["TOPLEFT"] = "TOPLEFT", ["TOPRIGHT"] = "TOPRIGHT", ["BOTTOMLEFT"] = "BOTTOMLEFT", ["BOTTOMRIGHT"] = "BOTTOMRIGHT" },
            get = function() return get("anchorRelativePoint") end,
            set = function(_, v) set("anchorRelativePoint", v) end,
        },
        anchorXOffset = {
            order = 54, type = "range", name = "X Offset", min = -500, max = 500, step = 0.5, bigStep = 1,
            get = function() return get("anchorXOffset") end,
            set = function(_, v) set("anchorXOffset", v) end,
        },
        anchorYOffset = {
            order = 55, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.5, bigStep = 1,
            get = function() return get("anchorYOffset") end,
            set = function(_, v) set("anchorYOffset", v) end,
        },
        
        -- Reset Button
        resetSettings = {
            order = 100, -- High order to ensure it appears at the bottom
            type = "execute",
            name = "Reset to Defaults",
            desc = "Reset all settings for this bar to their default values.",
            func = function()
                local db = GetSpecialBarSlotDB(barKey)
                
                -- Loop through the defaults table and copy values over
                for k, v in pairs(SPECIAL_BAR_DEFAULTS) do
                    if type(v) == "table" then
                        -- Create a new table for colors to avoid reference issues
                        db[k] = {}
                        for subKey, subVal in pairs(v) do
                            db[k][subKey] = subVal
                        end
                    else
                        db[k] = v
                    end
                end
                
                -- Force a full refresh
                TUI:UpdateSpecialBars()
                print("|cFF8080FFthingsUI|r: " .. barKey .. " reset to defaults.")
            end,
        },
    }
end