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
    local nameToID = {}
    for id, data in pairs(rawList) do
        enriched[id] = data
        if data.name then nameToID[data.name] = id end
    end

    -- If a slot's saved spellID isn't in CDM's list but shares a name with a
    -- CDM entry (e.g. user previously saved aura ID 164812 for Moonfire while
    -- CDM exposes parent 8921), migrate the slot to the canonical CDM ID so
    -- the dropdown shows the correct selection and we don't duplicate rows.
    local function migrate(db)
        if not db or not db.spellID or enriched[db.spellID] then return end
        local info = C_Spell.GetSpellInfo(db.spellID)
        if not info then return end
        local canonical = nameToID[info.name]
        if canonical then
            db.spellID = canonical
        else
            enriched[db.spellID] = { name = info.name, type = "Unknown" }
            nameToID[info.name] = db.spellID
        end
    end

    for i = 1, SB.GetBarCount() do migrate(SB.GetBarDB("bar"..i)) end
    for i = 1, SB.GetIconCount() do migrate(SB.GetIconDB("icon"..i)) end
    return enriched
end

local function GetChoicesTable(currentKey, isBar)
    local choices = { [""] = "|cFF888888— None —|r" }
    -- Refresh known tables from the live viewer (rebuilds in place if frames
    -- exist; otherwise leaves the previous snapshot intact so we don't lose
    -- state when CDM is closed).
    if SB.ScanAndHookCDMChildren then SB.ScanAndHookCDMChildren() end
    local rawList = GetEnrichedSpellList()
    local knownBar  = SB.knownBarSpells  or {}
    local knownIcon = SB.knownIconSpells or {}

    -- Count name occurrences so we can suffix #spellID on duplicates only.
    local nameCounts = {}
    for _, data in pairs(rawList) do
        if data.name then nameCounts[data.name] = (nameCounts[data.name] or 0) + 1 end
    end

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

        local displayName = data.name or "?"
        if data.name and nameCounts[data.name] and nameCounts[data.name] > 1 then
            displayName = displayName .. " |cFF888888#" .. tostring(id) .. "|r"
        end

        local pid = data.parentID
        -- knownBar/knownIcon reflect the last CDM viewer scan and persist
        -- across CDM open/close. For split-variant entries (key is a linkedID,
        -- parentID is the shared parent — Blooming Infusion case) we must
        -- only check the entry's own id, otherwise both variants would match
        -- the parent and look "live". Non-split entries (id == parentID)
        -- can fall back to parent, which catches base-spell tracking.
        local isSplitVariant = pid and pid ~= id
        local liveAsBar, liveAsIcon
        if isSplitVariant then
            liveAsBar  = knownBar[id]  or false
            liveAsIcon = knownIcon[id] or false
        else
            liveAsBar  = knownBar[id]  or (pid and knownBar[pid])
            liveAsIcon = knownIcon[id] or (pid and knownIcon[pid])
        end

        local talented = IsPlayerSpell(id) or (pid and IsPlayerSpell(pid)) or false
        local inCDM = data.type and data.type ~= "Unknown"

        local liveType
        if liveAsBar and liveAsIcon then liveType = "Bar & Icon"
        elseif liveAsBar then liveType = "Bar"
        elseif liveAsIcon then liveType = "Icon"
        end

        if usage then
            -- In-use by another slot. Orange shades by slot type.
            local isIconUsage = usage:find("Icon", 1, true)
            local nameColor = isIconUsage and "|cFFFFB347" or "|cFFFF8800"
            local tagColor  = isIconUsage and "|cFFCC8844" or "|cFFAA6600"
            choices[tostring(id)] = iconStr .. nameColor .. displayName .. "|r " .. tagColor .. "(In use: " .. usage .. ")|r"
        elseif liveType then
            -- Currently visible in a CDM viewer. Yellow = Bar only, Green = Icon (or both).
            local isBarOnly = liveType == "Bar"
            local nameColor = isBarOnly and "|cFFFFFF00" or "|cFF00FF00"
            local typeLabel = "|cFF888888(" .. liveType .. ")|r"
            choices[tostring(id)] = iconStr .. nameColor .. displayName .. "|r " .. typeLabel
        elseif inCDM and talented then
            -- Talented but not currently displayed in CDM viewer (parked in Not
            -- Displayed). Light blue — user can drag it into CDM to make it show.
            choices[tostring(id)] = iconStr .. "|cFF66CCFF" .. displayName .. "|r |cFF6699CC(Not tracked)|r"
        elseif inCDM then
            -- In CDM's API but player doesn't have the spell.
            choices[tostring(id)] = iconStr .. "|cFFAAAAAA" .. displayName .. "|r |cFF666666(Not talented)|r"
        else
            -- Unknown / not in CDM at all — dim
            choices[tostring(id)] = iconStr .. "|cFF666666" .. displayName .. " |cFF555555(?)|r|r"
        end
    end
    return choices
end

-- Sort buckets, lower = appears first in dropdown:
--   1: in use as Bar           2: in use as Icon
--   3: live as Bar             4: live as Icon (or Bar & Icon)
--   5: in CDM, talented (Not tracked)
--   6: in CDM, not talented
--   7: unknown / not in CDM
local function GetSortRank(id, data, knownBar, knownIcon)
    local pid = data.parentID
    local isSplitVariant = pid and pid ~= id
    local liveAsBar, liveAsIcon
    if isSplitVariant then
        liveAsBar  = knownBar[id]  or false
        liveAsIcon = knownIcon[id] or false
    else
        liveAsBar  = knownBar[id]  or (pid and knownBar[pid])
        liveAsIcon = knownIcon[id] or (pid and knownIcon[pid])
    end
    local usage = SB.GetSpellUsageInfo(id, nil, nil)
    if usage then
        return usage:find("Icon", 1, true) and 2 or 1
    end
    if liveAsBar and not liveAsIcon then return 3 end
    if liveAsIcon then return 4 end  -- Icon-only or Bar & Icon
    local talented = IsPlayerSpell(id) or (pid and IsPlayerSpell(pid)) or false
    local inCDM = data.type and data.type ~= "Unknown"
    if inCDM and talented then return 5 end
    if inCDM then return 6 end
    return 7
end

local function GetSortedKeys()
    local rawList = GetEnrichedSpellList()
    local knownBar  = SB.knownBarSpells  or {}
    local knownIcon = SB.knownIconSpells or {}
    local ranks = {}
    local sorted = {}
    for id, data in pairs(rawList) do
        sorted[#sorted+1] = id
        ranks[id] = GetSortRank(id, data, knownBar, knownIcon)
    end
    table.sort(sorted, function(a, b)
        if ranks[a] ~= ranks[b] then return ranks[a] < ranks[b] end
        local na, nb = rawList[a].name or "", rawList[b].name or ""
        if na == nb then return a < b end
        return na < nb
    end)
    local keys = { "" }
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
    commonArgs.restoreDefaults = {
        order = 4.5, type = "execute", name = "Restore Defaults",
        desc = "Reset all settings for this bar to their default values.",
        hidden = function() return not db().spellID end,
        confirm = function() return "Reset this bar's settings to defaults? Spell selection will be kept." end,
        func = function()
            local s = SB.GetSpecRoot()
            local savedSpellID   = s.bars and s.bars[barKey] and s.bars[barKey].spellID
            local savedSpellName = s.bars and s.bars[barKey] and s.bars[barKey].spellName
            if s.bars then s.bars[barKey] = nil end
            SB.ReleaseBar(barKey)
            -- Re-create with defaults, then restore spell so user doesn't have to re-pick.
            local fresh = SB.GetBarDB(barKey)
            fresh.spellID   = savedSpellID
            fresh.spellName = savedSpellName
            fresh.enabled   = savedSpellID ~= nil
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
        layoutGroup = {
            order = 10, type = "group", name = "Layout & Style",
            args = merge({
                sizeGroup = {
                    order = 10, type = "group", name = "Size", inline = true,
                    args = {
                        width = { order = 1, type = "range", name = "Width", min = 50, max = 600, step = 1, get = function() return get("width") end, set = function(_, v) set("width", v) end, disabled = function() return get("inheritWidth") end },
                        inheritWidth = { order = 2, type = "toggle", name = "Inherit Width from Anchor", get = function() return get("inheritWidth") end, set = function(_, v) set("inheritWidth", v) end },
                        inheritWidthOffset = { order = 3, type = "range", name = "Width Nudge", min = -200, max = 200, step = 0.5, get = function() return get("inheritWidthOffset") end, set = function(_, v) set("inheritWidthOffset", v) end, disabled = function() return not get("inheritWidth") end },
                        height = { order = 4, type = "range", name = "Height", min = 8, max = 60, step = 1, get = function() return get("height") end, set = function(_, v) set("height", v) end, disabled = function() return get("inheritHeight") end },
                        inheritHeight = { order = 5, type = "toggle", name = "Inherit Height from Anchor", get = function() return get("inheritHeight") end, set = function(_, v) set("inheritHeight", v) end },
                        inheritHeightOffset = { order = 6, type = "range", name = "Height Nudge", min = -50, max = 50, step = 0.5, get = function() return get("inheritHeightOffset") end, set = function(_, v) set("inheritHeightOffset", v) end, disabled = function() return not get("inheritHeight") end },
                    },
                },
                appearanceGroup = {
                    order = 11, type = "group", name = "Appearance", inline = true,
                    args = {
                        statusBarTexture = { order = 1, type = "select", name = "Texture", dialogControl = "LSM30_Statusbar", values = LSM:HashTable("statusbar"), get = function() return get("statusBarTexture") end, set = function(_, v) set("statusBarTexture", v) end },
                        useClassColor = { order = 2, type = "toggle", name = "Use Class Color", get = function() return get("useClassColor") end, set = function(_, v) set("useClassColor", v) end },
                        customColor = { order = 3, type = "color", name = "Custom Color", hasAlpha = false, disabled = function() return get("useClassColor") end, get = function() return unpackColor(get("customColor"), false) end, set = function(_, r, g, b) set("customColor", { r=r, g=g, b=b }) end },
                    },
                },
                placeholderGroup = {
                    order = 12, type = "group", name = "Edit Mode Placeholder", inline = true,
                    args = {
                        showBackdrop = { order = 1, type = "toggle", name = "Show Placeholder Backdrop", desc = "Show an empty background when not active.", get = function() return get("showBackdrop") end, set = function(_, v) set("showBackdrop", v) end },
                        backdropColor = { order = 2, type = "color", name = "Backdrop Color", hasAlpha = true, disabled = function() return not get("showBackdrop") end, get = function() return unpackColor(get("backdropColor"), true) end, set = function(_, r, g, b, a) set("backdropColor", {r=r,g=g,b=b,a=a}) end },
                    },
                },
                iconGroup = {
                    order = 13, type = "group", name = "Bar Icon", inline = true,
                    args = {
                        iconEnabled = { order = 1, type = "toggle", name = "Show Icon on Bar", get = function() return get("iconEnabled") end, set = function(_, v) set("iconEnabled", v) end },
                        iconSpacing = { order = 2, type = "range", name = "Icon Spacing", min = 0, max = 20, step = 1, disabled = function() return not get("iconEnabled") end, get = function() return get("iconSpacing") end, set = function(_, v) set("iconSpacing", v) end },
                        iconZoom = { order = 3, type = "range", name = "Icon Zoom", min = 0, max = 0.45, step = 0.01, isPercent = true, disabled = function() return not get("iconEnabled") end, get = function() return get("iconZoom") end, set = function(_, v) set("iconZoom", v) end },
                    },
                },
            }),
        },
        textGroup = {
            order = 20, type = "group", name = "Text",
            args = merge({
                fontGroup = {
                    order = 30, type = "group", name = "Font", inline = true,
                    args = {
                        font = { order = 1, type = "select", name = "Font", dialogControl = "LSM30_Font", values = LSM:HashTable("font"), get = function() return get("font") end, set = function(_, v) set("font", v) end },
                        fontSize = { order = 2, type = "range", name = "Size", min = 6, max = 72, step = 1, get = function() return get("fontSize") end, set = function(_, v) set("fontSize", v) end },
                        fontOutline = { order = 3, type = "select", name = "Outline", values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" }, get = function() return get("fontOutline") end, set = function(_, v) set("fontOutline", v) end },
                    },
                },
                nameGroup = {
                    order = 31, type = "group", name = "Name", inline = true,
                    args = {
                        showName = { order = 1, type = "toggle", name = "Show Name", get = function() return get("showName") end, set = function(_, v) set("showName", v) end },
                        namePoint = { order = 2, type = "select", name = "Align", values = { ["LEFT"]="Left", ["CENTER"]="Center", ["RIGHT"]="Right" }, disabled = function() return not get("showName") end, get = function() return get("namePoint") end, set = function(_, v) set("namePoint", v) end },
                        nameXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5, disabled = function() return not get("showName") end, get = function() return get("nameXOffset") end, set = function(_, v) set("nameXOffset", v) end },
                        nameYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showName") end, get = function() return get("nameYOffset") end, set = function(_, v) set("nameYOffset", v) end },
                    },
                },
                durationGroup = {
                    order = 32, type = "group", name = "Duration", inline = true,
                    args = {
                        showDuration = { order = 1, type = "toggle", name = "Show Duration", get = function() return get("showDuration") end, set = function(_, v) set("showDuration", v) end },
                        durationPoint = { order = 2, type = "select", name = "Align", values = { ["LEFT"]="Left", ["CENTER"]="Center", ["RIGHT"]="Right" }, disabled = function() return not get("showDuration") end, get = function() return get("durationPoint") end, set = function(_, v) set("durationPoint", v) end },
                        durationXOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 0.5, disabled = function() return not get("showDuration") end, get = function() return get("durationXOffset") end, set = function(_, v) set("durationXOffset", v) end },
                        durationYOffset = { order = 4, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showDuration") end, get = function() return get("durationYOffset") end, set = function(_, v) set("durationYOffset", v) end },
                    },
                },
                stackGroup = {
                    order = 33, type = "group", name = "Stack Count", inline = true,
                    args = {
                        showStacks = { order = 1, type = "toggle", name = "Show Stacks", get = function() return get("showStacks") end, set = function(_, v) set("showStacks", v) end },
                        stackAnchor = { order = 2, type = "select", name = "Anchor To", values = { ["ICON"]="Icon", ["BAR"]="Bar" }, disabled = function() return not get("showStacks") end, get = function() return get("stackAnchor") or "ICON" end, set = function(_, v) set("stackAnchor", v) end },
                        stackFontSize = { order = 3, type = "range", name = "Stack Font Size", min = 6, max = 72, step = 1, disabled = function() return not get("showStacks") end, get = function() return get("stackFontSize") end, set = function(_, v) set("stackFontSize", v) end },
                        stackFontOutline = { order = 4, type = "select", name = "Stack Outline", values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" }, disabled = function() return not get("showStacks") end, get = function() return get("stackFontOutline") end, set = function(_, v) set("stackFontOutline", v) end },
                        stackPoint = { order = 5, type = "select", name = "Stack Position", values = { ["CENTER"]="Center", ["LEFT"]="Left", ["RIGHT"]="Right", ["TOP"]="Top", ["BOTTOM"]="Bottom", ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right" }, disabled = function() return not get("showStacks") end, get = function() return get("stackPoint") end, set = function(_, v) set("stackPoint", v) end },
                        stackXOffset = { order = 6, type = "range", name = "Stack X Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackXOffset") end, set = function(_, v) set("stackXOffset", v) end },
                        stackYOffset = { order = 7, type = "range", name = "Stack Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackYOffset") end, set = function(_, v) set("stackYOffset", v) end },
                    },
                },
            }),
        },
        anchorGroup = {
            order = 30, type = "group", name = "Anchor",
            args = merge({
                anchorSettingsGroup = {
                    order = 50, type = "group", name = "Anchor", inline = true,
                    args = {
                        toggleMovers = {
                            order = 0, type = "execute", name = "Toggle Movers (thingsUI)",
                            desc = "Open ElvUI's mover panel filtered to thingsUI movers.",
                            func = function()
                                if E and E.ToggleMoveMode then E:ToggleMoveMode("THINGSUI") end
                            end,
                        },
                        anchorMode = { order = 1, type = "select", name = "Anchor Frame", width = "double",
                            values  = function() return BuildAnchorValues(true, false) end,
                            sorting = function() return BuildAnchorSorting(true, false) end,
                            get = function() return get("anchorMode") or "UIParent" end,
                            set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                        anchorFrame = { order = 2, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                        anchorPoint = { order = 3, type = "select", name = "Anchor From", values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" }, get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                        anchorRelativePoint = { order = 4, type = "select", name = "Anchor To", values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" }, get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                        anchorXOffset = { order = 5, type = "range", name = "X Offset", min = -500, max = 500, step = 0.5, bigStep = 1, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                        anchorYOffset = { order = 6, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.5, bigStep = 1, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
                    },
                },
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
        confirm = function() return "Reset this icon's settings to defaults? Spell selection will be kept." end,
        func = function()
            local s = SB.GetSpecRoot()
            local savedSpellID   = s.icons and s.icons[iconKey] and s.icons[iconKey].spellID
            local savedSpellName = s.icons and s.icons[iconKey] and s.icons[iconKey].spellName
            if s.icons then s.icons[iconKey] = nil end
            SB.ReleaseIcon(iconKey)
            local fresh = SB.GetIconDB(iconKey)
            fresh.spellID   = savedSpellID
            fresh.spellName = savedSpellName
            fresh.enabled   = savedSpellID ~= nil
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
                sizeStyleGroup = {
                    order = 10, type = "group", name = "Size & Style", inline = true,
                    args = {
                        keepAspectRatio = { order = 1, type = "toggle", name = "Keep Aspect Ratio",
                            desc = "Lock width and height together. Drag 'Size' to scale uniformly.",
                            get = function() return get("keepAspectRatio") ~= false end,
                            set = function(_, v)
                                if v then set("height", get("width") or 36) end
                                set("keepAspectRatio", v)
                            end },
                        size = { order = 2, type = "range", name = "Size", min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") == false end,
                            get = function() return get("width") or 36 end,
                            set = function(_, v) set("width", v); set("height", v) end },
                        width  = { order = 3, type = "range", name = "Width",  min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") ~= false end,
                            get = function() return get("width") or 36 end,
                            set = function(_, v) set("width", v) end },
                        height = { order = 4, type = "range", name = "Height", min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") ~= false end,
                            get = function() return get("height") or 36 end,
                            set = function(_, v) set("height", v) end },
                        zoom   = { order = 5, type = "range", name = "Zoom", min = 0, max = 0.45, step = 0.01, bigStep = 0.05, isPercent = true, get = function() return get("zoom") end, set = function(_, v) set("zoom", v) end },
                        desaturate = { order = 6, type = "toggle", name = "Show when Inactive", get = function() return get("desaturateWhenInactive") end, set = function(_, v) set("desaturateWhenInactive", v) end },
                    },
                },
                cooldownGroup = {
                    order = 11, type = "group", name = "Cooldown", inline = true,
                    args = {
                        showCooldown = { order = 1, type = "toggle", name = "Show Cooldown Sweep", get = function() return get("showCooldown") end, set = function(_, v) set("showCooldown", v) end },
                    },
                },
                borderGroup = {
                    order = 12, type = "group", name = "Border", inline = true,
                    args = {
                        showBorder  = { order = 1, type = "toggle", name = "Show Border",
                            get = function() return get("showBorder") end,
                            set = function(_, v) set("showBorder", v) end },
                        borderSize  = { order = 2, type = "range", name = "Size",  min = 1, max = 16,  step = 0.01, bigStep = 1,
                            disabled = function() return not get("showBorder") end,
                            get = function() return get("borderSize") end,
                            set = function(_, v) set("borderSize", v) end },
                        borderColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                            disabled = function() return not get("showBorder") end,
                            get = function() return unpackColor(get("borderColor"), true) end,
                            set = function(_, r, g, b, a) set("borderColor", { r=r, g=g, b=b, a=a }) end },
                        borderInset = { order = 4, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                            desc = "Expands (+) or shrinks (−) the border away from the icon edge.",
                            disabled = function() return not get("showBorder") end,
                            get = function() return get("borderInset") end,
                            set = function(_, v) set("borderInset", v) end },
                        borderStroke = { order = 5, type = "toggle", name = "Stroke",
                            desc = "Adds a thin black outline on both sides of the border.",
                            disabled = function() return not get("showBorder") end,
                            get = function() return get("borderStroke") end,
                            set = function(_, v) set("borderStroke", v) end },
                    },
                },
                glowGroup = {
                    order = 13, type = "group", name = "Glow", inline = true,
                    args = {
                        showGlow = { order = 1, type = "toggle", name = "Show Glow",
                            get = function() return get("showGlow") end,
                            set = function(_, v) set("showGlow", v) end },
                        glowType = { order = 2, type = "select", name = "Type",
                            disabled = function() return not get("showGlow") end,
                            values = { ["pixel"]="Pixel", ["autocast"]="Auto Cast", ["button"]="Button", ["proc"]="Proc" },
                            get = function() return get("glowType") or "pixel" end,
                            set = function(_, v) set("glowType", v) end },
                        glowColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                            disabled = function() return not get("showGlow") end,
                            get = function() return unpackColor(get("glowColor"), true) end,
                            set = function(_, r, g, b, a) set("glowColor", { r=r, g=g, b=b, a=a }) end },
                        glowThickness = { order = 4, type = "range", name = "Thickness", min = 0.5, max = 10, step = 0.5,
                            desc = "Line thickness. Auto-matched to Border Size when 'Glow Inside Border' is on.",
                            disabled = function()
                                return not get("showGlow")
                                    or get("glowType") == "button"
                                    or get("glowType") == "proc"
                                    or (get("glowInsideBorder") and get("showBorder"))
                            end,
                            get = function() return get("glowThickness") or 2 end,
                            set = function(_, v) set("glowThickness", v) end },
                        glowLength = { order = 5, type = "range", name = "Length", min = 1, max = 40, step = 1,
                            desc = "Length of each pixel line.",
                            disabled = function() return not get("showGlow") or get("glowType") ~= "pixel" end,
                            get = function() return get("glowLength") or 10 end,
                            set = function(_, v) set("glowLength", v) end },
                        glowN = { order = 6, type = "range", name = "Particles", min = 1, max = 32, step = 1,
                            desc = "Number of lines / particles.",
                            disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                            get = function() return get("glowN") or 8 end,
                            set = function(_, v) set("glowN", v) end },
                        glowFrequency = { order = 7, type = "range", name = "Speed", min = -2, max = 2, step = 0.05, bigStep = 0.25,
                            desc = "Animation speed. Negative values reverse direction.",
                            disabled = function() return not get("showGlow") end,
                            get = function() return get("glowFrequency") or 0.25 end,
                            set = function(_, v) set("glowFrequency", v) end },
                        glowXOffset = { order = 8, type = "range", name = "X Offset", min = -20, max = 20, step = 0.5,
                            disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                            get = function() return get("glowXOffset") or 0 end,
                            set = function(_, v) set("glowXOffset", v) end },
                        glowYOffset = { order = 9, type = "range", name = "Y Offset", min = -20, max = 20, step = 0.5,
                            disabled = function() return not get("showGlow") or get("glowType") == "button" or get("glowType") == "proc" end,
                            get = function() return get("glowYOffset") or 0 end,
                            set = function(_, v) set("glowYOffset", v) end },
                        glowInsideBorder = { order = 10, type = "toggle", name = "Glow Inside Border",
                            desc = "Attach the glow to the border frame instead of the icon edge.",
                            disabled = function() return not get("showGlow") or not get("showBorder") end,
                            get = function() return get("glowInsideBorder") end,
                            set = function(_, v) set("glowInsideBorder", v) end },
                    },
                },
            }),
        },
        textGroup = {
            order = 15, type = "group", name = "Text",
            args = merge({
                stackGroup = {
                    order = 10, type = "group", name = "Stack Count", inline = true,
                    args = {
                        showStacks  = { order = 1, type = "toggle", name = "Show Stacks",
                            get = function() return get("showStacks") end,
                            set = function(_, v) set("showStacks", v) end },
                        stackFont   = { order = 2, type = "select", name = "Font", dialogControl = "LSM30_Font",
                            values = LSM:HashTable("font"),
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackFont") end,
                            set = function(_, v) set("stackFont", v) end },
                        stackFontSize = { order = 3, type = "range", name = "Font Size", min = 1, max = 72, step = 1, bigStep = 1,
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackFontSize") end,
                            set = function(_, v) set("stackFontSize", v) end },
                        stackFontOutline = { order = 4, type = "select", name = "Outline",
                            values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" },
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackFontOutline") end,
                            set = function(_, v) set("stackFontOutline", v) end },
                        stackColor  = { order = 5, type = "color", name = "Color", hasAlpha = false,
                            disabled = function() return not get("showStacks") end,
                            get = function() return unpackColor(get("stackColor"), false) end,
                            set = function(_, r, g, b) set("stackColor", { r=r, g=g, b=b }) end },
                        stackPoint  = { order = 6, type = "select", name = "Position",
                            values = { ["CENTER"]="Center", ["TOPLEFT"]="Top Left", ["TOP"]="Top", ["TOPRIGHT"]="Top Right", ["RIGHT"]="Right", ["BOTTOMRIGHT"]="Bottom Right", ["BOTTOM"]="Bottom", ["BOTTOMLEFT"]="Bottom Left", ["LEFT"]="Left" },
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackPoint") or "BOTTOMRIGHT" end,
                            set = function(_, v) set("stackPoint", v) end },
                        stackXOffset = { order = 7, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackXOffset") end,
                            set = function(_, v) set("stackXOffset", v) end },
                        stackYOffset = { order = 8, type = "range", name = "Y Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackYOffset") end,
                            set = function(_, v) set("stackYOffset", v) end },
                    },
                },
                durationGroup = {
                    order = 20, type = "group", name = "Duration", inline = true,
                    args = {
                        showDuration   = { order = 1, type = "toggle", name = "Show Duration",
                            get = function() return get("showDuration") end,
                            set = function(_, v) set("showDuration", v) end },
                        durationFont   = { order = 2, type = "select", name = "Font", dialogControl = "LSM30_Font",
                            values = LSM:HashTable("font"),
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationFont") end,
                            set = function(_, v) set("durationFont", v) end },
                        durationFontSize = { order = 3, type = "range", name = "Font Size", min = 6, max = 36, step = 1, bigStep = 1,
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationFontSize") end,
                            set = function(_, v) set("durationFontSize", v) end },
                        durationFontOutline = { order = 4, type = "select", name = "Outline",
                            values = { ["NONE"]="None", ["OUTLINE"]="Outline", ["THICKOUTLINE"]="Thick" },
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationFontOutline") end,
                            set = function(_, v) set("durationFontOutline", v) end },
                        durationColor  = { order = 5, type = "color", name = "Color", hasAlpha = false,
                            disabled = function() return not get("showDuration") end,
                            get = function() return unpackColor(get("durationColor"), false) end,
                            set = function(_, r, g, b) set("durationColor", { r=r, g=g, b=b }) end },
                        durationPoint  = { order = 6, type = "select", name = "Position",
                            values = { ["CENTER"]="Center", ["TOPLEFT"]="Top Left", ["TOP"]="Top", ["TOPRIGHT"]="Top Right", ["RIGHT"]="Right", ["BOTTOMRIGHT"]="Bottom Right", ["BOTTOM"]="Bottom", ["BOTTOMLEFT"]="Bottom Left", ["LEFT"]="Left" },
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationPoint") or "CENTER" end,
                            set = function(_, v) set("durationPoint", v) end },
                        durationXOffset = { order = 7, type = "range", name = "X Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationXOffset") end,
                            set = function(_, v) set("durationXOffset", v) end },
                        durationYOffset = { order = 8, type = "range", name = "Y Offset", min = -50, max = 50, step = 0.01, bigStep = 1,
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationYOffset") end,
                            set = function(_, v) set("durationYOffset", v) end },
                    },
                },
            }),
        },
        anchorGroup = {
            order = 20, type = "group", name = "Anchor",
            args = merge({
                anchorSettingsGroup = {
                    order = 50, type = "group", name = "Anchor", inline = true,
                    args = {
                        anchorMode = { order = 1, type = "select", name = "Anchor Frame", width = "double",
                            values  = function() return BuildAnchorValues(false, true) end,
                            sorting = function() return BuildAnchorSorting(false, true) end,
                            get = function() return get("anchorMode") or "UIParent" end,
                            set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                        anchorFrame = { order = 2, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                        anchorPoint = { order = 3, type = "select", name = "Anchor From",
                            values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" },
                            get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                        anchorRelativePoint = { order = 4, type = "select", name = "Anchor To",
                            values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["LEFT"]="LEFT", ["RIGHT"]="RIGHT", ["CENTER"]="CENTER", ["TOPLEFT"]="TOPLEFT", ["TOPRIGHT"]="TOPRIGHT", ["BOTTOMLEFT"]="BOTTOMLEFT", ["BOTTOMRIGHT"]="BOTTOMRIGHT" },
                            get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                        anchorXOffset = { order = 5, type = "range", name = "X Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                        anchorYOffset = { order = 6, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
                    },
                },
            }),
        },
    }
end