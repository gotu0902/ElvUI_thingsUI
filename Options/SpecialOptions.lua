local addon, ns = ...
local TUI   = ns.TUI
local E     = ns.E
local LSM   = ns.LSM

local SB = ns.SpecialBars

local function BuildAnchorValues(includeBars, includeIcons)
    local t = {}
    for k, v in pairs(ns.ANCHORS.SHARED_ANCHOR_VALUES) do t[k] = v end
    if includeBars then
        local n = SB and SB.GetSpecRoot and (SB.GetSpecRoot().barCount or 0) or 0
        for i = 1, n do t["TUI_SpecialBar_bar"..i] = "Special Bar "..i end
    end
    if includeIcons then
        local n = SB and SB.GetSpecRoot and (SB.GetSpecRoot().iconCount or 0) or 0
        for i = 1, n do t["TUI_SpecialIcon_icon"..i] = "Special Icon "..i end
    end
    return t
end

local function BuildAnchorSorting(includeBars, includeIcons)
    local order = {}
    for _, k in ipairs(ns.ANCHORS.SHARED_ANCHOR_ORDER) do order[#order+1] = k end
    if includeBars then
        local n = SB and SB.GetSpecRoot and (SB.GetSpecRoot().barCount or 0) or 0
        for i = 1, n do order[#order+1] = "TUI_SpecialBar_bar"..i end
    end
    if includeIcons then
        local n = SB and SB.GetSpecRoot and (SB.GetSpecRoot().iconCount or 0) or 0
        for i = 1, n do order[#order+1] = "TUI_SpecialIcon_icon"..i end
    end
    return order
end

local function NotifyChange()
    local ok, reg = pcall(LibStub, "AceConfigRegistry-3.0")
    if ok and reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

local function QueueUpdate()
    if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() else TUI:UpdateSpecialBars() end
    C_Timer.After(0.05, NotifyChange)
end

-- Safe color unpacker — returns fallback values when the DB entry is nil
local function unpackColor(c, hasAlpha)
    if not c then return 1, 1, 1, hasAlpha and 1 or nil end
    if hasAlpha then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function GetEnrichedSpellList()
    local rawList = SB.GetRawSpellList()
    local enriched = {}
    for id, data in pairs(rawList) do enriched[id] = data end

    for i = 1, SB.GetBarCount() do
        local id = SB.GetBarDB("bar"..i).spellID
        if id and not enriched[id] then
            local info = C_Spell.GetSpellInfo(id)
            if info then enriched[id] = { name = info.name, type = "Unknown" } end
        end
    end
    for i = 1, SB.GetIconCount() do
        local id = SB.GetIconDB("icon"..i).spellID
        if id and not enriched[id] then
            local info = C_Spell.GetSpellInfo(id)
            if info then enriched[id] = { name = info.name, type = "Unknown" } end
        end
    end
    return enriched
end

local function GetChoicesTable(currentKey, isBar)
    local choices = { [""] = "|cFF888888— None —|r" }
    local rawList = GetEnrichedSpellList()
    local knownBar  = SB.knownBarSpells  or {}
    local knownIcon = SB.knownIconSpells or {}

    for id, data in pairs(rawList) do
        local usage = SB.GetSpellUsageInfo(id, isBar and currentKey or nil, not isBar and currentKey or nil)
        local iconStr = ""
        if data.icon then
            iconStr = "|T" .. data.icon .. ":16:16:0:0:64:64:4:60:4:60|t "
        else
            -- Try resolving the icon on the fly
            local si = C_Spell.GetSpellInfo(id)
            if si and si.iconID then
                iconStr = "|T" .. si.iconID .. ":16:16:0:0:64:64:4:60:4:60|t "
            end
        end

        local typeLabel
        local isActive = false 
        if knownBar[id] and knownIcon[id] then
            typeLabel = "|cFF888888(Bar & Icon)|r"
            isActive = true
        elseif knownBar[id] then
            typeLabel = "|cFF888888(Bar)|r"
            isActive = true
        elseif knownIcon[id] then
            typeLabel = "|cFF888888(Icon)|r"
            isActive = true
        elseif data.type and data.type ~= "Unknown" then
            if data.notDisplayed then
                typeLabel = "|cFF666666(" .. data.type .. " - Not Displayed)|r"
            else
                typeLabel = "|cFF888888(" .. data.type .. ")|r"
                isActive = true
            end
        else
            typeLabel = "|cFF555555(?)|r"
        end

        if usage then
            -- In-use by another slot — orange/yellow so it stands out but clearly unavailable
            choices[tostring(id)] = iconStr .. "|cFFFF8800" .. data.name .. "|r |cFFAA6600(In use: " .. usage .. ")|r"
        elseif isActive then
            -- Active in CDM viewer — bright green (fetches talented\available stuff as well, not sure how to fix that)
            choices[tostring(id)] = iconStr .. "|cFF00FF00" .. data.name .. "|r " .. typeLabel
        elseif data.type and data.type ~= "Unknown" then
            -- In CDM API but not active — light gray (probably not talented)
            choices[tostring(id)] = iconStr .. "|cFFAAAAAA" .. data.name .. "|r " .. typeLabel
        else
            -- Unknown / not in CDM at all — dim
            choices[tostring(id)] = iconStr .. "|cFF666666" .. data.name .. " " .. typeLabel .. "|r"
        end
    end
    return choices
end

local function GetSortedKeys()
    local rawList = GetEnrichedSpellList()
    local keys = { "" }
    local sorted = {}
    for id in pairs(rawList) do sorted[#sorted+1] = id end
    table.sort(sorted, function(a, b) return rawList[a].name < rawList[b].name end)
    for _, id in ipairs(sorted) do keys[#keys+1] = tostring(id) end
    return keys
end

local function CommonHeader()
    return {
        specInfo = {
            order = 0, type = "description", width = "full",
            name = function()
                local idx = GetSpecialization()
                local name = idx and select(2, GetSpecializationInfo(idx)) or "Unknown"
                return "|cFFFFFF00Spec: " .. name .. "|r  (per-spec)"
            end,
        },
    }
end

function TUI:SpecialBarOptions(barKey)
    local function db() return SB.GetBarDB(barKey) end
    local function get(k) return db()[k] end
    local function set(k, v) db()[k] = v; QueueUpdate() end

    local commonArgs = CommonHeader()
    commonArgs.spellSelect = {
        order = 1, type = "select", name = "Select Spell", width = "double",
        values = function() return GetChoicesTable(barKey, true) end,
        sorting = GetSortedKeys,
        get = function() return db().spellID and tostring(db().spellID) or "" end,
        set = function(_, v)
            local id = tonumber(v)
            if id then
                local usage = SB.GetSpellUsageInfo(id, barKey, nil)
                if usage then
                    E:Print("Denne spellen er allerede i bruk av " .. usage .. "!")
                    return
                end
            end
            db().spellID = id
            local rawList = SB.GetRawSpellList()
            db().spellName = id and (rawList[id] and rawList[id].name or "") or ""
            db().enabled = id ~= nil
            NotifyChange()
            QueueUpdate()
        end,
    }
    commonArgs.enabled = {
        order = 3, type = "toggle", name = "Enable",
        get = function() return get("enabled") end,
        set = function(_, v) if not v then SB.ReleaseBar(barKey) end; db().enabled = v; QueueUpdate() end,
        hidden = function() return not db().spellID end,
    }
    commonArgs.divider = { order = 4, type = "header", name = "" }

    local function merge(extra)
        local out = {}
        for k, v in pairs(commonArgs) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        return out
    end

    return {
        layoutGroup = {
            order = 10, type = "group", name = "Layout & Style",
            args = merge({
                lHeader = { order = 10, type = "header", name = "Size" },
                width = { order = 11, type = "range", name = "Width", min = 50, max = 600, step = 1, get = function() return get("width") end, set = function(_, v) set("width", v) end, disabled = function() return get("inheritWidth") end },
                inheritWidth = { order = 11.5, type = "toggle", name = "Inherit Width from Anchor", get = function() return get("inheritWidth") end, set = function(_, v) set("inheritWidth", v) end },
                inheritWidthOffset = { order = 11.6, type = "range", name = "Width Nudge", min = -200, max = 200, step = 0.5, get = function() return get("inheritWidthOffset") end, set = function(_, v) set("inheritWidthOffset", v) end, disabled = function() return not get("inheritWidth") end },
                height = { order = 12, type = "range", name = "Height", min = 8, max = 60, step = 1, get = function() return get("height") end, set = function(_, v) set("height", v) end, disabled = function() return get("inheritHeight") end },
                inheritHeight = { order = 12.5, type = "toggle", name = "Inherit Height from Anchor", get = function() return get("inheritHeight") end, set = function(_, v) set("inheritHeight", v) end },
                inheritHeightOffset = { order = 12.6, type = "range", name = "Height Nudge", min = -50, max = 50, step = 0.5, get = function() return get("inheritHeightOffset") end, set = function(_, v) set("inheritHeightOffset", v) end, disabled = function() return not get("inheritHeight") end },
                
                texHeader = { order = 13, type = "header", name = "Appearance" },
                statusBarTexture = { order = 14, type = "select", name = "Texture", dialogControl = "LSM30_Statusbar", values = LSM:HashTable("statusbar"), get = function() return get("statusBarTexture") end, set = function(_, v) set("statusBarTexture", v) end },
                useClassColor = { order = 15, type = "toggle", name = "Use Class Color", get = function() return get("useClassColor") end, set = function(_, v) set("useClassColor", v) end },
                customColor = { order = 16, type = "color", name = "Custom Color", hasAlpha = false, disabled = function() return get("useClassColor") end, get = function() return unpackColor(get("customColor"), false) end, set = function(_, r, g, b) set("customColor", { r=r, g=g, b=b }) end },
                
                backdropHeader = { order = 17, type = "header", name = "Edit Mode Placeholder" },
                showBackdrop = { order = 18, type = "toggle", name = "Show Placeholder Backdrop", desc = "Show an empty background when not active.", get = function() return get("showBackdrop") end, set = function(_, v) set("showBackdrop", v) end },
                backdropColor = { order = 19, type = "color", name = "Backdrop Color", hasAlpha = true, disabled = function() return not get("showBackdrop") end, get = function() return unpackColor(get("backdropColor"), true) end, set = function(_, r, g, b, a) set("backdropColor", {r=r,g=g,b=b,a=a}) end },
                
                iconHeader = { order = 20, type = "header", name = "Bar Icon" },
                iconEnabled = { order = 21, type = "toggle", name = "Show Icon on Bar", get = function() return get("iconEnabled") end, set = function(_, v) set("iconEnabled", v) end },
                iconSpacing = { order = 22, type = "range", name = "Icon Spacing", min = 0, max = 20, step = 1, disabled = function() return not get("iconEnabled") end, get = function() return get("iconSpacing") end, set = function(_, v) set("iconSpacing", v) end },
                iconZoom = { order = 23, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true, disabled = function() return not get("iconEnabled") end, get = function() return get("iconZoom") end, set = function(_, v) set("iconZoom", v) end },
            }),
        },
        textGroup = {
            order = 20, type = "group", name = "Text",
            args = merge({
                fontHeader = { order = 30, type = "header", name = "Font" },
                font = { order = 31, type = "select", name = "Font", dialogControl = "LSM30_Font", values = LSM:HashTable("font"), get = function() return get("font") end, set = function(_, v) set("font", v) end },
                fontSize = { order = 32, type = "range", name = "Size", min = 6, max = 72, step = 1, get = function() return get("fontSize") end, set = function(_, v) set("fontSize", v) end },
                fontOutline = { order = 33, type = "select", name = "Outline", values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" }, get = function() return get("fontOutline") end, set = function(_, v) set("fontOutline", v) end },
                nameHeader = { order = 34, type = "header", name = "Name" },
                showName = { order = 35, type = "toggle", name = "Show Name", get = function() return get("showName") end, set = function(_, v) set("showName", v) end },
                namePoint = { order = 36, type = "select", name = "Align", values = { ["LEFT"]="Left", ["CENTER"]="Center", ["RIGHT"]="Right" }, disabled = function() return not get("showName") end, get = function() return get("namePoint") end, set = function(_, v) set("namePoint", v) end },
                nameXOffset = { order = 37, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5, disabled = function() return not get("showName") end, get = function() return get("nameXOffset") end, set = function(_, v) set("nameXOffset", v) end },
                nameYOffset = { order = 38, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showName") end, get = function() return get("nameYOffset") end, set = function(_, v) set("nameYOffset", v) end },
                durHeader = { order = 39, type = "header", name = "Duration" },
                showDuration = { order = 40, type = "toggle", name = "Show Duration", get = function() return get("showDuration") end, set = function(_, v) set("showDuration", v) end },
                durationPoint = { order = 41, type = "select", name = "Align", values = { ["LEFT"]="Left", ["CENTER"]="Center", ["RIGHT"]="Right" }, disabled = function() return not get("showDuration") end, get = function() return get("durationPoint") end, set = function(_, v) set("durationPoint", v) end },
                durationXOffset = { order = 42, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5, disabled = function() return not get("showDuration") end, get = function() return get("durationXOffset") end, set = function(_, v) set("durationXOffset", v) end },
                durationYOffset = { order = 43, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showDuration") end, get = function() return get("durationYOffset") end, set = function(_, v) set("durationYOffset", v) end },
                stackHeader = { order = 44, type = "header", name = "Stack Count" },
                showStacks = { order = 45, type = "toggle", name = "Show Stacks", get = function() return get("showStacks") end, set = function(_, v) set("showStacks", v) end },
                stackAnchor = { order = 46, type = "select", name = "Anchor To", values = { ["ICON"]="Icon", ["BAR"]="Bar" }, disabled = function() return not get("showStacks") end, get = function() return get("stackAnchor") or "ICON" end, set = function(_, v) set("stackAnchor", v) end },
                stackFontSize = { order = 47, type = "range", name = "Stack Font Size", min = 6, max = 72, step = 1, disabled = function() return not get("showStacks") end, get = function() return get("stackFontSize") end, set = function(_, v) set("stackFontSize", v) end },
                stackFontOutline = { order = 48, type = "select", name = "Stack Outline", values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" }, disabled = function() return not get("showStacks") end, get = function() return get("stackFontOutline") end, set = function(_, v) set("stackFontOutline", v) end },
                stackPoint = { order = 49, type = "select", name = "Stack Position", values = { ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom", ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right" }, disabled = function() return not get("showStacks") end, get = function() return get("stackPoint") end, set = function(_, v) set("stackPoint", v) end },
                stackXOffset = { order = 50, type = "range", name = "Stack X Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackXOffset") end, set = function(_, v) set("stackXOffset", v) end },
                stackYOffset = { order = 51, type = "range", name = "Stack Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackYOffset") end, set = function(_, v) set("stackYOffset", v) end },
            }),
        },
        anchorGroup = {
            order = 30, type = "group", name = "Anchor",
            args = merge({
                anchorHeader = { order = 50, type = "header", name = "Anchor" },
                anchorMode = { order = 51, type = "select", name = "Anchor Frame", width = "double",
                    values  = function() return BuildAnchorValues(true, false) end,
                    sorting = function() return BuildAnchorSorting(true, false) end,
                    get = function() return get("anchorMode") or "UIParent" end,
                    set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                anchorFrame = { order = 51.5, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                anchorPoint = { order = 52, type = "select", name = "Anchor From", values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" }, get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                anchorRelativePoint = { order = 53, type = "select", name = "Anchor To", values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" }, get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                anchorXOffset = { order = 54, type = "range", name = "X Offset", min = -500, max = 500, step = 0.5, bigStep = 1, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                anchorYOffset = { order = 55, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.5, bigStep = 1, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
            }),
        },
    }
end

function TUI:SpecialIconOptions(iconKey)
    local function db() return SB.GetIconDB(iconKey) end
    local function get(k) return db()[k] end
    local function set(k, v) db()[k] = v; QueueUpdate() end

    local commonArgs = CommonHeader()
    commonArgs.spellSelect = {
        order = 1, type = "select", name = "Spell", width = "double",
        values = function() return GetChoicesTable(iconKey, false) end,
        sorting = GetSortedKeys,
        get = function() return db().spellID and tostring(db().spellID) or "" end,
        set = function(_, v)
            local id = tonumber(v)
            if id then
                local usage = SB.GetSpellUsageInfo(id, nil, iconKey)
                if usage then
                    E:Print("Denne spellen er allerede i bruk av " .. usage .. "!")
                    return
                end
            end
            db().spellID = id
            local rawList = SB.GetRawSpellList()
            db().spellName = id and (rawList[id] and rawList[id].name or "") or ""
            db().enabled = id ~= nil
            NotifyChange()
            QueueUpdate()
        end,
    }
    commonArgs.enabled = {
        order = 3, type = "toggle", name = "Enable",
        hidden = function() return not db().spellID end,
        get = function() return get("enabled") end,
        set = function(_, v) db().enabled = v; if not v then SB.ReleaseIcon(iconKey) end; QueueUpdate() end,
    }
    commonArgs.restoreDefaults = {
        order = 4.5, type = "execute", name = "Restore Defaults",
        desc = "Reset all settings for this icon to their default values.",
        hidden = function() return not db().spellID end,
        func = function()
            local s = SB.GetSpecRoot()
            local key = iconKey
            if s.icons then s.icons[key] = nil end
            SB.ReleaseIcon(key)
            QueueUpdate()
            NotifyChange()
        end,
    }
    commonArgs.divider = { order = 5, type = "header", name = "" }

    local function merge(extra)
        local out = {}
        for k, v in pairs(commonArgs) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        return out
    end

    return {
        appearGroup = {
            order = 10, type = "group", name = "Appearance",
            args = merge({
                sizeHeader = { order = 10, type = "header", name = "Size & Style" },
                keepAspectRatio = { order = 10.5, type = "toggle", name = "Keep Aspect Ratio",
                    desc = "Lock width and height together. Drag 'Size' to scale uniformly.",
                    get = function() return get("keepAspectRatio") ~= false end,
                    set = function(_, v)
                        -- When locking, snap height to current width
                        if v then set("height", get("width") or 36) end
                        set("keepAspectRatio", v)
                    end },
                size = { order = 11, type = "range", name = "Size", min = 16, max = 128, step = 0.01, bigStep = 1,
                    hidden = function() return get("keepAspectRatio") == false end,
                    get = function() return get("width") or 36 end,
                    set = function(_, v) set("width", v); set("height", v) end },
                width  = { order = 11.2, type = "range", name = "Width",  min = 16, max = 128, step = 0.01, bigStep = 1,
                    hidden = function() return get("keepAspectRatio") ~= false end,
                    get = function() return get("width") or 36 end,
                    set = function(_, v) set("width", v) end },
                height = { order = 11.5, type = "range", name = "Height", min = 16, max = 128, step = 0.01, bigStep = 1,
                    hidden = function() return get("keepAspectRatio") ~= false end,
                    get = function() return get("height") or 36 end,
                    set = function(_, v) set("height", v) end },
                zoom   = { order = 12,  type = "range", name = "Zoom",   min = 0,  max = 0.45, step = 0.01, bigStep = 0.05, isPercent = true, get = function() return get("zoom") end, set = function(_, v) set("zoom", v) end },
                desaturate  = { order = 13, type = "toggle", name = "Show when Inactive", get = function() return get("desaturateWhenInactive") end, set = function(_, v) set("desaturateWhenInactive", v) end },
                cdHeader    = { order = 14, type = "header", name = "Cooldown" },
                showCooldown = { order = 15, type = "toggle", name = "Show Cooldown Sweep", get = function() return get("showCooldown") end, set = function(_, v) set("showCooldown", v) end },
                borderHeader = { order = 16, type = "header", name = "Border" },
                showBorder  = { order = 16.5, type = "toggle", name = "Show Border",
                    get = function() return get("showBorder") end,
                    set = function(_, v) set("showBorder", v) end },
                borderSize  = { order = 17, type = "range", name = "Size",  min = 1, max = 16,  step = 0.01, bigStep = 1,
                    disabled = function() return not get("showBorder") end,
                    get = function() return get("borderSize") end,
                    set = function(_, v) set("borderSize", v) end },
                borderColor = { order = 18, type = "color", name = "Color", hasAlpha = true,
                    disabled = function() return not get("showBorder") end,
                    get = function() return unpackColor(get("borderColor"), true) end,
                    set = function(_, r, g, b, a) set("borderColor", { r=r, g=g, b=b, a=a }) end },
                borderInset = { order = 19, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                    desc = "Expands (+) or shrinks (−) the border away from the icon edge.",
                    disabled = function() return not get("showBorder") end,
                    get = function() return get("borderInset") end,
                    set = function(_, v) set("borderInset", v) end },
                borderStroke = { order = 20, type = "toggle", name = "Stroke",
                    desc = "Adds a thin black outline on both sides of the border.",
                    disabled = function() return not get("showBorder") end,
                    get = function() return get("borderStroke") end,
                    set = function(_, v) set("borderStroke", v) end },
                -- Glow ------------------------------------------------------
                glowHeader = { order = 21, type = "header", name = "Glow" },
                showGlow = { order = 22, type = "toggle", name = "Show Glow",
                    get = function() return get("showGlow") end,
                    set = function(_, v) set("showGlow", v) end },
                glowType = { order = 23, type = "select", name = "Type",
                    disabled = function() return not get("showGlow") end,
                    values = { ["pixel"]="Pixel", ["autocast"]="Auto Cast", ["button"]="Button", ["proc"]="Proc" },
                    get = function() return get("glowType") or "pixel" end,
                    set = function(_, v) set("glowType", v) end },
                glowColor = { order = 24, type = "color", name = "Color", hasAlpha = true,
                    disabled = function() return not get("showGlow") end,
                    get = function() return unpackColor(get("glowColor"), true) end,
                    set = function(_, r, g, b, a) set("glowColor", { r=r, g=g, b=b, a=a }) end },
                glowThickness = { order = 25, type = "range", name = "Thickness", min = 0.5, max = 10, step = 0.5,
                    desc = "Line thickness. Auto-matched to Border Size when 'Glow Inside Border' is on.",
                    disabled = function()
                        return not get("showGlow")
                            or get("glowType") == "button"
                            or get("glowType") == "proc"
                            or (get("glowInsideBorder") and get("showBorder"))
                    end,
                    get = function() return get("glowThickness") or 2 end,
                    set = function(_, v) set("glowThickness", v) end },
                glowLength = { order = 26, type = "range", name = "Length", min = 1, max = 40, step = 1,
                    desc = "Length of each pixel line.",
                    disabled = function() return not get("showGlow") or get("glowType") ~= "pixel" end,
                    get = function() return get("glowLength") or 10 end,
                    set = function(_, v) set("glowLength", v) end },
                glowN = { order = 27, type = "range", name = "Particles", min = 1, max = 32, step = 1,
                    desc = "Number of lines / particles.",
                    disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                    get = function() return get("glowN") or 8 end,
                    set = function(_, v) set("glowN", v) end },
                glowFrequency = { order = 28, type = "range", name = "Speed", min = -2, max = 2, step = 0.05, bigStep = 0.25,
                    desc = "Animation speed. Negative values reverse direction.",
                    disabled = function() return not get("showGlow") end,
                    get = function() return get("glowFrequency") or 0.25 end,
                    set = function(_, v) set("glowFrequency", v) end },
                glowXOffset = { order = 29, type = "range", name = "X Offset", min = -20, max = 20, step = 0.5,
                    disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                    get = function() return get("glowXOffset") or 0 end,
                    set = function(_, v) set("glowXOffset", v) end },
                glowYOffset = { order = 30, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                    disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                    get = function() return get("glowYOffset") or 0 end,
                    set = function(_, v) set("glowYOffset", v) end },
                glowInsideBorder = { order = 31, type = "toggle", name = "Glow Inside Border",
                    desc = "Attach the glow to the border frame instead of the icon edge.",
                    disabled = function() return not get("showGlow") or not get("showBorder") end,
                    get = function() return get("glowInsideBorder") end,
                    set = function(_, v) set("glowInsideBorder", v) end },
            }),
        },
        textGroup = {
            order = 15, type = "group", name = "Text",
            args = merge({
                -- Stack Count -----------------------------------------------
                stackHeader = { order = 10, type = "header", name = "Stack Count" },
                showStacks  = { order = 11, type = "toggle", name = "Show Stacks",
                    get = function() return get("showStacks") end,
                    set = function(_, v) set("showStacks", v) end },
                stackFont   = { order = 11.5, type = "select", name = "Font", dialogControl = "LSM30_Font",
                    values = LSM:HashTable("font"),
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackFont") end,
                    set = function(_, v) set("stackFont", v) end },
                stackFontSize = { order = 12, type = "range", name = "Font Size", min = 1, max = 72, step = 1, bigStep = 1,
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackFontSize") end,
                    set = function(_, v) set("stackFontSize", v) end },
                stackFontOutline = { order = 13, type = "select", name = "Outline",
                    values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" },
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackFontOutline") end,
                    set = function(_, v) set("stackFontOutline", v) end },
                stackColor  = { order = 14, type = "color", name = "Color", hasAlpha = false,
                    disabled = function() return not get("showStacks") end,
                    get = function() return unpackColor(get("stackColor"), false) end,
                    set = function(_, r, g, b) set("stackColor", { r=r, g=g, b=b }) end },
                stackPoint  = { order = 15, type = "select", name = "Position",
                    values = { ["CENTER"]="Center", ["TOPLEFT"]="Top Left", ["TOP"]="Top", ["TOPRIGHT"]="Top Right", ["RIGHT"]="Right", ["BOTTOMRIGHT"]="Bottom Right", ["BOTTOM"]="Bottom", ["BOTTOMLEFT"]="Bottom Left", ["LEFT"]="Left" },
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackPoint") or "BOTTOMRIGHT" end,
                    set = function(_, v) set("stackPoint", v) end },
                stackXOffset = { order = 16, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackXOffset") end,
                    set = function(_, v) set("stackXOffset", v) end },
                stackYOffset = { order = 17, type = "range", name = "Y Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                    disabled = function() return not get("showStacks") end,
                    get = function() return get("stackYOffset") end,
                    set = function(_, v) set("stackYOffset", v) end },
                -- Duration --------------------------------------------------
                durationHeader = { order = 20, type = "header", name = "Duration" },
                showDuration   = { order = 21, type = "toggle", name = "Show Duration",
                    get = function() return get("showDuration") end,
                    set = function(_, v) set("showDuration", v) end },
                durationFont   = { order = 22, type = "select", name = "Font", dialogControl = "LSM30_Font",
                    values = LSM:HashTable("font"),
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationFont") end,
                    set = function(_, v) set("durationFont", v) end },
                durationFontSize = { order = 23, type = "range", name = "Font Size", min = 6, max = 36, step = 1, bigStep = 1,
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationFontSize") end,
                    set = function(_, v) set("durationFontSize", v) end },
                durationFontOutline = { order = 24, type = "select", name = "Outline",
                    values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" },
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationFontOutline") end,
                    set = function(_, v) set("durationFontOutline", v) end },
                durationColor  = { order = 25, type = "color", name = "Color", hasAlpha = false,
                    disabled = function() return not get("showDuration") end,
                    get = function() return unpackColor(get("durationColor"), false) end,
                    set = function(_, r, g, b) set("durationColor", { r=r, g=g, b=b }) end },
                durationPoint  = { order = 26, type = "select", name = "Position",
                    values = { ["CENTER"]="Center", ["TOPLEFT"]="Top Left", ["TOP"]="Top", ["TOPRIGHT"]="Top Right", ["RIGHT"]="Right", ["BOTTOMRIGHT"]="Bottom Right", ["BOTTOM"]="Bottom", ["BOTTOMLEFT"]="Bottom Left", ["LEFT"]="Left" },
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationPoint") or "CENTER" end,
                    set = function(_, v) set("durationPoint", v) end },
                durationXOffset = { order = 27, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationXOffset") end,
                    set = function(_, v) set("durationXOffset", v) end },
                durationYOffset = { order = 28, type = "range", name = "Y Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                    disabled = function() return not get("showDuration") end,
                    get = function() return get("durationYOffset") end,
                    set = function(_, v) set("durationYOffset", v) end },
            }),
        },
        anchorGroup = {
            order = 20, type = "group", name = "Anchor",
            args = merge({
                anchorMode = { order = 51, type = "select", name = "Anchor Frame", width = "double",
                    values  = function() return BuildAnchorValues(false, true) end,
                    sorting = function() return BuildAnchorSorting(false, true) end,
                    get = function() return get("anchorMode") or "UIParent" end,
                    set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                anchorFrame = { order = 51.5, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                anchorPoint = { order = 52, type = "select", name = "Anchor From",
                    values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" },
                    get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                anchorRelativePoint = { order = 53, type = "select", name = "Anchor To",
                    values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" },
                    get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                anchorXOffset = { order = 54, type = "range", name = "X Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                anchorYOffset = { order = 55, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
            }),
        },
    }
end