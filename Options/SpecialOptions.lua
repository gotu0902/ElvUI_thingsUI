local addon, ns = ...
local TUI   = ns.TUI
local E     = ns.E
local LSM   = ns.LSM

local SB = ns.SpecialBars

local forceCurrentSpec = false
local function ESpec()
    if forceCurrentSpec then return nil end
    return SB.EditingSpec and SB.EditingSpec() or nil
end
local function CurSpecID()
    local idx = GetSpecialization()
    return idx and GetSpecializationInfo(idx) or 0
end

local function SettleAfterSlotChange()
    if ns.SB_RebuildSlotPages then ns.SB_RebuildSlotPages() end
    TUI:UpdateSpecialBars()
    if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
    C_Timer.After(0.25, function()
        TUI:UpdateSpecialBars()
        if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
    end)
end

local STRATA_VALUES = ns.STRATA.VALUES
local STRATA_ORDER  = ns.STRATA.ORDER
local POINT_VALUES  = ns.POINTS.VALUES
local POINT_ORDER   = ns.POINTS.ORDER

local function BuildAnchorValues(includeBars, includeIcons, excludeFrame)
    local t = {}
    for k, v in pairs(ns.ANCHORS.GetSharedAnchorValues()) do
        if k == excludeFrame then
        elseif k:find("^TUI_SpecialBar_") then
            if includeBars then t[k] = v end
        elseif k:find("^TUI_SpecialIcon_") then
            if includeIcons then t[k] = v end
        else
            t[k] = v
        end
    end
    return t
end

local function FindAnchorsTargetingFrame(targetFrame)
    if not targetFrame or targetFrame == "" then return {} end
    local out = {}

    -- Special Bars / Icons
    local barCount  = (SB and SB.GetBarCount  and SB.GetBarCount())  or 0
    local iconCount = (SB and SB.GetIconCount and SB.GetIconCount()) or 0
    for i = 1, barCount do
        local key = "bar" .. i
        local bdb = SB and SB.GetBarDB and SB.GetBarDB(key)
        if bdb and (bdb.anchorMode == targetFrame or bdb.anchorFrame == targetFrame) then
            out[#out + 1] = "Special Bar " .. i
        end
    end
    for i = 1, iconCount do
        local key = "icon" .. i
        local idb = SB and SB.GetIconDB and SB.GetIconDB(key)
        if idb and (idb.anchorMode == targetFrame or idb.anchorFrame == targetFrame) then
            out[#out + 1] = "Special Icon " .. i
        end
    end

    local bs = ns.BarSetup
    if bs and bs.GetActiveSetup then
        local setup = bs.GetActiveSetup()
        if setup and setup.bars then
            local labels = bs.BAR_LABELS or {}
            for k, b in pairs(setup.bars) do
                if b.mode == "FHT" and b.anchorFrame == targetFrame then
                    out[#out + 1] = labels[k] or k
                end
            end

            if setup.anchorFrame == targetFrame then
                out[#out + 1] = "Bar Setup stack"
            end
        end
    end

    return out
end

local function BuildAnchorSorting(includeBars, includeIcons, excludeFrame)
    local order = {}
    for _, k in ipairs(ns.ANCHORS.GetSharedAnchorOrder()) do
        if k == excludeFrame then
        elseif k:find("^TUI_SpecialBar_") then
            if includeBars then order[#order+1] = k end
        elseif k:find("^TUI_SpecialIcon_") then
            if includeIcons then order[#order+1] = k end
        else
            order[#order+1] = k
        end
    end
    return order
end

local NotifyChange = ns.NotifyChange

local function QueueUpdate()
    if TUI.QueueSpecialBarsUpdate then TUI:QueueSpecialBarsUpdate() else TUI:UpdateSpecialBars() end
    if ns.BarSetup and ns.BarSetup.ApplyStack then
        C_Timer.After(0.05, ns.BarSetup.ApplyStack)
    end

    if ns.CustomGroups and ns.CustomGroups.QueueLayout then
        C_Timer.After(0.1, ns.CustomGroups.QueueLayout)
    end
    C_Timer.After(0.05, NotifyChange)
end

local function unpackColor(c, hasAlpha)
    if not c then return 1, 1, 1, hasAlpha and 1 or nil end
    if hasAlpha then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function GetEnrichedSpellList()
    local es = ESpec()
    local rawList = SB.GetRawSpellList(es)
    local enriched = {}
    local nameToID = {}
    for id, data in pairs(rawList) do
        enriched[id] = data
        if data.name then nameToID[data.name] = id end
    end

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

    for i = 1, SB.GetBarCount(es) do migrate(SB.GetBarDB("bar"..i, es)) end
    for i = 1, SB.GetIconCount(es) do migrate(SB.GetIconDB("icon"..i, es)) end
    return enriched
end

local function LiveAs(id, data, knownBar, knownIcon)
    if ESpec() then
        local t, nd = data.type, data.notDisplayed
        local asBar  = (t and t:find("Bar", 1, true) and not nd) or false
        local asIcon = (t and t:find("Icon", 1, true) and not nd) or false
        return asBar, asIcon
    end
    local pid = data.parentID
    if pid and pid ~= id then
        return knownBar[id] or false, knownIcon[id] or false
    end
    return knownBar[id] or (pid and knownBar[pid]), knownIcon[id] or (pid and knownIcon[pid])
end

local function GetChoicesTable(currentKey, isBar)
    local choices = { [""] = "|cFF888888- None -|r" }

    if SB.ScanAndHookCDMChildren then SB.ScanAndHookCDMChildren() end
    local rawList = GetEnrichedSpellList()
    local knownBar  = SB.knownBarSpells  or {}
    local knownIcon = SB.knownIconSpells or {}

    local nameCounts = {}
    for _, data in pairs(rawList) do
        if data.name then nameCounts[data.name] = (nameCounts[data.name] or 0) + 1 end
    end

    for id, data in pairs(rawList) do
        local usage = SB.GetSpellUsageInfo(id, isBar and currentKey or nil, not isBar and currentKey or nil, ESpec())
        local iconStr = ""
        if data.icon then
            iconStr = "|T" .. data.icon .. ":16:16:0:0:64:64:4:60:4:60|t "
        else
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
        local liveAsBar, liveAsIcon = LiveAs(id, data, knownBar, knownIcon)

        local talented = IsPlayerSpell(id) or (pid and IsPlayerSpell(pid)) or false
        local inCDM = data.type and data.type ~= "Unknown"
        local live = liveAsBar or liveAsIcon

        if usage then
            local isIconUsage = usage:find("Icon", 1, true)
            local nameColor = isIconUsage and "|cFFFFB347" or "|cFFFF8800"
            local tagColor  = isIconUsage and "|cFFCC8844" or "|cFFAA6600"
            local where = ""
            local iconNum = usage:match("^Icon (%d+)")
            if iconNum then
                local idb = SB.GetIconDB("icon" .. iconNum, ESpec())
                local gid = idb and idb.customGroup
                local g = gid and ns.CustomGroups and ns.CustomGroups.GroupByID and ns.CustomGroups.GroupByID(gid)
                if g and g.name then where = " |cFF8AC8FF[" .. g.name .. "]|r" end
            end
            choices[tostring(id)] = iconStr .. nameColor .. displayName .. "|r " .. tagColor .. "(In use: " .. usage .. ")|r" .. where
        elseif live then
            choices[tostring(id)] = iconStr .. "|cFF00FF00" .. displayName .. "|r"
        elseif inCDM and talented then
            choices[tostring(id)] = iconStr .. "|cFF66CCFF" .. displayName .. "|r |cFF6699CC(Not tracked)|r"
        elseif inCDM then
            choices[tostring(id)] = iconStr .. "|cFFAAAAAA" .. displayName .. "|r |cFF666666(Not talented)|r"
        else
            choices[tostring(id)] = iconStr .. "|cFF666666" .. displayName .. " |cFF555555(?)|r|r"
        end
    end
    return choices
end

local function GetSortRank(id, data, knownBar, knownIcon)
    local pid = data.parentID
    local liveAsBar, liveAsIcon = LiveAs(id, data, knownBar, knownIcon)
    local usage = SB.GetSpellUsageInfo(id, nil, nil, ESpec())
    if usage then
        return usage:find("Icon", 1, true) and 2 or 1
    end
    if liveAsBar or liveAsIcon then return 3 end
    local talented = IsPlayerSpell(id) or (pid and IsPlayerSpell(pid)) or false
    local inCDM = data.type and data.type ~= "Unknown"
    if inCDM and talented then return 4 end
    if inCDM then return 5 end
    return 6
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

function ns.SB_SpellChoices(currentKey, isBar)
    forceCurrentSpec = true
    local res = GetChoicesTable(currentKey, isBar)
    forceCurrentSpec = false
    return res
end
function ns.SB_SpellChoicesSorting()
    forceCurrentSpec = true
    local res = GetSortedKeys()
    forceCurrentSpec = false
    return res
end

StaticPopupDialogs["TUI_STYLE_USE_ALL"] = {
    text = "Apply style '%s' to ALL special %s (every spec)?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        local n = 0
        SB.Styles.EachSpecial(data.kind, function(d)
            if d.spellID then SB.Styles.ApplyToDB(data.kind, data.name, d); n = n + 1 end
        end)
        E:Print(("Style '%s' applied to %d %s."):format(data.name, n, data.kind))
        QueueUpdate()
        NotifyChange()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["TUI_STYLE_USE_SPEC"] = {
    text = "Apply style '%s' to all of %s's %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        local s = SB.GetSpecRoot(data.specID)
        local field = (data.kind == "bars") and "bars" or "icons"
        local n = 0
        for _, d in pairs((s and s[field]) or {}) do
            if type(d) == "table" and d.spellID then
                SB.Styles.ApplyToDB(data.kind, data.name, d)
                n = n + 1
            end
        end
        E:Print(("Style '%s' applied to %d %s."):format(data.name, n, data.kind))
        QueueUpdate()
        NotifyChange()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function OpenStyleUsePicker(kind, name)
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    local field = (kind == "bars") and "bars" or "icons"

    local entries, classesSet = {}, {}
    local sbdb = E.db.thingsUI and E.db.thingsUI.specialBars
    for specKey, s in pairs((sbdb and sbdb.specs) or {}) do
        for sk, d in pairs(s[field] or {}) do
            if type(d) == "table" and d.spellID then
                local m = ns.SpecMeta and ns.SpecMeta(tonumber(specKey))
                local si = C_Spell.GetSpellInfo(d.spellID)
                entries[#entries + 1] = {
                    d = d, specKey = specKey,
                    classToken = (m and m.classToken) or "?",
                    className  = (m and m.className) or specKey,
                    specName   = (m and m.name) or specKey,
                    specIcon   = m and m.icon,
                    specIndex  = (m and m.specIndex) or 0,
                    spellName  = d.spellName or (si and si.name) or sk,
                    spellTex   = si and si.iconID,
                }
                if m and m.classToken then classesSet[m.classToken] = true end
            end
        end
    end

    local checks = {}
    local filterClass, sortByStyle = nil, false

    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    f:SetTitle(("Apply Style: %s"):format(name))
    f:SetWidth(500)
    f:SetHeight(580)
    f:SetLayout("Fill")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    f:AddChild(scroll)

    local rebuild

    local function addHeader(text)
        local h = AceGUI:Create("Heading"); h:SetText(text); h:SetFullWidth(true); scroll:AddChild(h)
    end

    local function addEntry(e)
        local d = e.d
        local cb = AceGUI:Create("CheckBox")
        cb:SetFullWidth(true)
        local specPre = (sortByStyle and e.specIcon) and ("|T" .. e.specIcon .. ":14:14|t ") or ""
        local tex = e.spellTex and ("|T" .. e.spellTex .. ":14:14|t ") or ""
        local base = specPre .. tex .. e.spellName
        local styleTag = (not sortByStyle and d.styleName)
            and (" |cFF" .. SB.Styles.ColorHex(d.styleName) .. "[" .. d.styleName .. "]|r") or ""
        local usesThis = d.styleName == name
        if usesThis and not SB.Styles.IsDirty(kind, name, d) then
            cb:SetLabel(base .. styleTag .. " |cFF888888(already using)|r")
            cb:SetValue(true); cb:SetDisabled(true)
        else
            cb:SetLabel(base .. styleTag .. (usesThis and " |cFFFFD200(changed)|r" or ""))
            cb:SetValue(checks[d] and true or false)
            cb:SetCallback("OnValueChanged", function(_, _, v) checks[d] = v and true or nil end)
        end
        scroll:AddChild(cb)
    end

    rebuild = function()
        scroll:ReleaseChildren()

        local classDD = AceGUI:Create("Dropdown")
        classDD:SetLabel("Show"); classDD:SetRelativeWidth(0.5)
        local vals, order = { ALL = "|cFFFFD200All classes|r" }, { "ALL" }
        local clist = {}
        for ct in pairs(classesSet) do clist[#clist + 1] = ct end
        table.sort(clist, function(a, b)
            return ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[a]) or a)
                 < ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[b]) or b)
        end)
        for _, ct in ipairs(clist) do
            vals[ct] = ns.ClassColor(ct) .. ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[ct]) or ct) .. "|r"
            order[#order + 1] = ct
        end
        classDD:SetList(vals, order)
        classDD:SetValue(filterClass or "ALL")
        classDD:SetCallback("OnValueChanged", function(_, _, v) filterClass = (v ~= "ALL") and v or nil; rebuild() end)
        scroll:AddChild(classDD)

        local showAll = AceGUI:Create("Button")
        showAll:SetText("Show All"); showAll:SetRelativeWidth(0.22)
        showAll:SetCallback("OnClick", function() filterClass = nil; rebuild() end)
        scroll:AddChild(showAll)

        local sortCB = AceGUI:Create("CheckBox")
        sortCB:SetLabel("Sort by style"); sortCB:SetRelativeWidth(0.28)
        sortCB:SetValue(sortByStyle)
        sortCB:SetCallback("OnValueChanged", function(_, _, v) sortByStyle = v and true or false; rebuild() end)
        scroll:AddChild(sortCB)

        local list = {}
        for _, e in ipairs(entries) do
            if not filterClass or e.classToken == filterClass then list[#list + 1] = e end
        end

        if sortByStyle then
            table.sort(list, function(a, b)
                local sa, sb = a.d.styleName or "", b.d.styleName or ""
                if sa ~= sb then
                    if sa == "" then return false end
                    if sb == "" then return true end
                    return sa < sb
                end
                if a.className ~= b.className then return a.className < b.className end
                if a.specIndex ~= b.specIndex then return a.specIndex < b.specIndex end
                return a.spellName < b.spellName
            end)
            local cur = "\1"
            for _, e in ipairs(list) do
                local sn = e.d.styleName or ""
                if sn ~= cur then
                    cur = sn
                    addHeader(sn == "" and "|cFF888888No style|r" or SB.Styles.ColoredName(sn))
                end
                addEntry(e)
            end
        else
            table.sort(list, function(a, b)
                if a.className ~= b.className then return a.className < b.className end
                if a.specIndex ~= b.specIndex then return a.specIndex < b.specIndex end
                return a.spellName < b.spellName
            end)
            local cur = "\1"
            for _, e in ipairs(list) do
                if e.specKey ~= cur then
                    cur = e.specKey
                    local ico = e.specIcon and ("|T" .. e.specIcon .. ":14:14|t ") or ""
                    addHeader(ico .. ns.ClassColor(e.classToken) .. e.className .. " - " .. e.specName .. "|r")
                end
                addEntry(e)
            end
        end

        local applyBtn = AceGUI:Create("Button")
        applyBtn:SetText("Apply Style"); applyBtn:SetRelativeWidth(0.5)
        applyBtn:SetCallback("OnClick", function()
            local n = 0
            for d in pairs(checks) do SB.Styles.ApplyToDB(kind, name, d); n = n + 1 end
            AceGUI:Release(f)
            E:Print(("Style '%s' applied to %d %s."):format(name, n, kind))
            QueueUpdate(); NotifyChange()
        end)
        scroll:AddChild(applyBtn)
        local cancel = AceGUI:Create("Button")
        cancel:SetText(CANCEL); cancel:SetRelativeWidth(0.5)
        cancel:SetCallback("OnClick", function() AceGUI:Release(f) end)
        scroll:AddChild(cancel)
    end

    rebuild()
end

function ns.SB_StyleUseRow(kind, nameFn, orderNum, withGoto)
    local field = (kind == "bars") and "bars" or "icons"
    local function specLink(targetID)
        local m = ns.SpecMeta and ns.SpecMeta(targetID)
        local specName = m and m.name or "spec"
        local specIcon = m and m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
        local s = SB.GetSpecRoot(targetID)
        local specCount = 0
        for _, d in pairs((s and s[field]) or {}) do
            if type(d) == "table" and d.spellID then specCount = specCount + 1 end
        end
        return {
            label = ("%sAll %s %s (%d)"):format(specIcon, specName, kind, specCount),
            color = { 0.4, 0.85, 1 },
            onClick = function()
                local dialog = StaticPopup_Show("TUI_STYLE_USE_SPEC", nameFn(), specName, kind)
                if dialog then dialog.data = { kind = kind, name = nameFn(), specID = targetID } end
            end,
        }
    end
    local row = ns.OptionLinkRowDynamic(orderNum, function()
        local n = nameFn()
        local count, mine = 0, 0
        SB.Styles.EachSpecial(kind, function(d)
            if d.spellID then
                count = count + 1
                if d.styleName == n then mine = mine + 1 end
            end
        end)
        local links = {
            { label = "Use style on:  ", color = { 1, 0.82, 0 } },
            { label = ("All %s (%d)"):format(kind, count), color = { 0.4, 1, 0.4 },
              onClick = function()
                  local dialog = StaticPopup_Show("TUI_STYLE_USE_ALL", n, kind)
                  if dialog then dialog.data = { kind = kind, name = n } end
              end },
        }
        local es = ESpec()
        if es then links[#links + 1] = specLink(es) end
        links[#links + 1] = specLink(CurSpecID())
        links[#links + 1] = { label = ("Choose...  (%d using now)"):format(mine), color = { 0.54, 0.78, 1 },
            onClick = function() OpenStyleUsePicker(kind, n) end }
        if withGoto then
            links[#links + 1] = { label = "Go to Style", color = { 1, 0.82, 0 },
                onClick = function() if ns.SB_OpenStyleTab then ns.SB_OpenStyleTab(kind, nameFn()) end end }
        end
        return links
    end)
    row.hidden = function() return not nameFn() end
    return row
end

local BARSETUP_OWNED = { showBackdrop = true, backdropColor = true, width = true, height = true }
local GROUPED_ICON_OWNED = {
    showCooldown = true, invertSwipe = true, width = true, height = true,
    keepAspectRatio = true, zoom = true, iconLockAspectRatio = true,
    frameStrata = true, desaturateWhenInactive = true,
}

local function StyleArgs(kind, db, ignoreFn)
    local function styleName() return db().styleName end
    local function ackd() return db()._styleDriftAck == true end
    local function isDirty()
        local n = styleName()
        if not (n and SB.Styles) then return false end
        return SB.Styles.IsDirty(kind, n, db(), ignoreFn and ignoreFn() or nil)
    end
    local function warnShown() return isDirty() and not ackd() end
    local noun = (kind == "bars") and "bar" or "icon"
    return {
        stylePick = {
            order = 5.1, type = "select", name = "Style", width = 1.1,
            hidden = function() return not db().spellID end,
            values = function() return SB.Styles.DropdownValues(kind, "|cFF888888- None -|r") end,
            sorting = function() return SB.Styles.DropdownSorting(kind, true) end,
            get = function() return styleName() or "" end,
            set = function(_, v)
                db()._styleDriftAck = nil
                if v == "" then
                    db().styleName = nil
                else
                    SB.Styles.ApplyToDB(kind, v, db())
                end
                QueueUpdate(); NotifyChange()
            end,
        },
        styleNew = {
            order = 5.2, type = "input", name = "Create New Style ", width = 1.1,
            hidden = function() return not db().spellID end,
            get = function() return "" end,
            set = function(_, v)
                v = (v or ""):match("^%s*(.-)%s*$")
                if v ~= "" then
                    db()._styleDriftAck = nil
                    SB.Styles.Save(kind, v, db())
                    QueueUpdate(); NotifyChange()
                end
            end,
        },
        styleDirty = {
            order = 5.3, type = "description", width = "full", fontSize = "medium",
            hidden = function() return not warnShown() end,
            name = function()
                return ("|cFFFFD200Not the same settings as style '%s' - you can update the style or revert.|r")
                    :format(styleName() or "?")
            end,
        },
        styleUpdate = {
            order = 5.4, type = "execute", name = "|cFF40FF40Update Style|r", width = 0.9,
            hidden = function() return not warnShown() end,
            confirm = function()
                return ("Overwrite style '%s' with this %s's settings? Every special using the style follows."):format(styleName() or "?", noun)
            end,
            func = function()
                db()._styleDriftAck = nil
                SB.Styles.Save(kind, styleName(), db())
                QueueUpdate(); NotifyChange()
            end,
        },
        styleRevert = {
            order = 5.5, type = "execute", name = "Revert to Style", width = 0.9,
            hidden = function() return not warnShown() end,
            func = function()
                db()._styleDriftAck = nil
                SB.Styles.ApplyToDB(kind, styleName(), db())
                QueueUpdate(); NotifyChange()
            end,
        },
        styleIgnore = (function()
            local row = ns.OptionLinkRowDynamic(5.55, function()
                return { { label = "Ignore warning", color = { 1, 0.25, 0.25 },
                    onClick = function() db()._styleDriftAck = true; NotifyChange() end } }
            end)
            row.hidden = function() return not warnShown() end
            return row
        end)(),
        styleIgnored = {
            order = 5.3, type = "description", width = "full", fontSize = "medium",
            hidden = function() return not (isDirty() and ackd()) end,
            name = function()
                return ("|cFF40FF40Warning ignored - different settings than style '%s'.|r"):format(styleName() or "?")
            end,
        },
        styleUnignore = {
            order = 5.35, type = "execute", name = "|cFF888888Show update / revert again|r", width = 1.0,
            hidden = function() return not (isDirty() and ackd()) end,
            func = function() db()._styleDriftAck = nil; NotifyChange() end,
        },
        styleUseRow = (function()
            local row = ns.OptionLinkRowDynamic(5.6, function()
                return {
                    { label = "Go to Style", color = { 1, 0.82, 0 },
                      onClick = function() if ns.SB_OpenStyleTab then ns.SB_OpenStyleTab(kind, styleName()) end end },
                }
            end)
            row.hidden = function() return not styleName() end
            return row
        end)(),
    }
end

local function SpecialCounts(kind)
    local counts = {}
    local sbdb = E.db.thingsUI and E.db.thingsUI.specialBars
    local specs = sbdb and sbdb.specs or {}
    local field = (kind == "bars") and "bars" or "icons"
    for specKey, s in pairs(specs) do
        local n = 0
        for _, d in pairs(s[field] or {}) do
            if type(d) == "table" and d.spellID then n = n + 1 end
        end
        if n > 0 then counts[tonumber(specKey)] = n end
    end
    return counts
end

local function CommonHeader(kind)
    return {
        editingSpec = {
            order = 0, type = "select", name = "Editing Spec", width = "double",
            dialogControl = "TUI_CascadeDropdown",
            values = function() return ns.CascadeDropdown.AllSpecsWithCounts(SpecialCounts(kind)) end,
            get = function()
                local sid = SB.editingSpec or CurSpecID()
                local m = ns.SpecMeta(sid)
                return m and (m.classToken .. ":" .. sid) or nil
            end,
            set = function(_, value)
                local sid = tonumber(value and value:match("^[A-Z_]+:(%d+)$") or nil)
                if sid then
                    SB.editingSpec = (sid ~= CurSpecID()) and sid or nil
                    NotifyChange()
                end
            end,
        },
        gotoCur = {
            order = 0.5, type = "execute", width = 1.2,
            hidden = function() return not ESpec() end,
            name = function()
                local m = ns.SpecMeta(CurSpecID())
                if not m then return "Go to Current Spec" end
                local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
                return "Go to " .. icon .. ns.ClassColor(m.classToken) .. (m.name or "?") .. "|r"
            end,
            func = function() SB.editingSpec = nil; NotifyChange() end,
        },
    }
end

function TUI:SpecialBarOptions(barKey, ctx)
    ctx = ctx or {}
    local styleMode = ctx.styleName ~= nil
    local function curStyle() return (type(ctx.styleName) == "function") and ctx.styleName() or ctx.styleName end
    local barName = "TUI_SpecialBar_" .. (barKey or "")
    local function db()
        if styleMode then return SB.Styles.Get("bars", curStyle()) or {} end
        return SB.GetBarDB(barKey, ESpec())
    end
    local function get(k) return db()[k] end
    local function set(k, v)
        db()[k] = v
        if styleMode then
            SB.Styles.ApplyToUsers("bars", curStyle()); TUI:UpdateSpecialBars(); NotifyChange()
        else
            QueueUpdate()
        end
    end

    local function IsGrouped()
        if styleMode then return false end
        local gid = db().customGroup
        local g = gid and ns.CustomBars and ns.CustomBars.GroupByID and ns.CustomBars.GroupByID(gid)
        return (g and g.enabled) and true or false
    end

    local function IsInBarSetup()
        if styleMode then return false end
        local bs = ns.BarSetup
        if not bs or not bs.GetActiveSetup then return false end
        local setup = bs.GetActiveSetup()
        if not (setup and setup.order) then return false end
        local target = "special:" .. barKey
        for _, k in ipairs(setup.order) do
            if k == target then

                local b = setup.bars and setup.bars[k]
                return b ~= nil and b.enabled == true
            end
        end
        return false
    end

    local commonArgs = {}
    if not styleMode then
    commonArgs = CommonHeader("bars")
    commonArgs.spellSelect = {
        order = 1, type = "select", name = "Select Spell", width = "double",
        values = function() return GetChoicesTable(barKey, true) end,
        sorting = GetSortedKeys,
        get = function() return db().spellID and tostring(db().spellID) or "" end,
        set = function(_, v)
            local id = tonumber(v)
            if id then
                local usage = SB.GetSpellUsageInfo(id, barKey, nil, ESpec())
                if usage then
                    E:Print("This spell is already used by " .. usage .. "!")
                    return
                end
            end

            if SB.ReleaseBar and not ESpec() then SB.ReleaseBar(barKey) end
            db().spellID = id
            local rawList = SB.GetRawSpellList(ESpec())
            db().spellName = id and (rawList[id] and rawList[id].name or "") or ""
            db().enabled = id ~= nil
            NotifyChange()
            QueueUpdate()
        end,
    }
    commonArgs.enabled = {
        order = 3, type = "toggle", name = "Enable",
        get = function() return get("enabled") end,
        set = function(_, v) if not v and not ESpec() then SB.ReleaseBar(barKey) end; db().enabled = v; QueueUpdate() end,
        hidden = function() return not db().spellID end,
    }
    commonArgs.customGroup = {
        order = 3.5, type = "select", name = "|cFFF27D2ABar Group|r",
        hidden = function()
            if not db().spellID then return true end
            if IsInBarSetup() then return true end
            local CBm = ns.CustomBars
            return not (CBm and CBm.GetGroups and #CBm.GetGroups() > 0)
        end,
        values = function()
            local out = { [0] = "|cFF888888Standalone|r" }
            for _, g in ipairs((ns.CustomBars and ns.CustomBars.GetGroups and ns.CustomBars.GetGroups()) or {}) do
                out[g.id] = g.name or ("Bar Group " .. g.id)
            end
            return out
        end,
        sorting = function()
            local out = { 0 }
            local groups = (ns.CustomBars and ns.CustomBars.GetGroups and ns.CustomBars.GetGroups()) or {}
            local ids = {}
            for _, g in ipairs(groups) do ids[#ids + 1] = g.id end
            table.sort(ids, function(a, b)
                local ga = ns.CustomBars.GroupByID(a)
                local gb = ns.CustomBars.GroupByID(b)
                return (ga and ga.name or "") < (gb and gb.name or "")
            end)
            for _, id in ipairs(ids) do out[#out + 1] = id end
            return out
        end,
        get = function() return db().customGroup or 0 end,
        set = function(_, v)
            db().customGroup = (v ~= 0) and v or nil
            if not ESpec() then SB.ReleaseBar(barKey) end
            QueueUpdate()
            if TUI.QueueCustomBarsUpdate then TUI:QueueCustomBarsUpdate() end
            NotifyChange()
        end,
    }
    commonArgs.customGroupLink = {
        order = 3.6, type = "execute", name = "Go to Bar Group", width = 0.9,
        hidden = function()
            local gid = db().customGroup
            return not (gid and ns.CustomBars and ns.CustomBars.GroupByID and ns.CustomBars.GroupByID(gid))
        end,
        func = function()
            if E.ToggleOptions then E:ToggleOptions("thingsUI,modulesTab,customBars") end
        end,
    }
    commonArgs.auraKind = {
        order = 3.7, type = "select", name = "Aura Type",
        hidden = function() return not IsGrouped() end,
        values = { HELPFUL = "Buff (on you)", HARMFUL = "Debuff (on target)" },
        sorting = { "HELPFUL", "HARMFUL" },
        get = function() return db().auraKind or "HELPFUL" end,
        set = function(_, v)
            db().auraKind = (v == "HARMFUL") and v or nil
            if TUI.QueueCustomBarsUpdate then TUI:QueueCustomBarsUpdate() end
        end,
    }
    commonArgs.auraKindHint = {
        order = 3.8, type = "description", width = "full",
        hidden = function() return not (IsGrouped() and db().auraKind == "HARMFUL") end,
        name = "|cFF888888Debuff bars need the group's Unit set to Target.|r",
    }
    commonArgs.restoreDefaults = {
        order = 4.5, type = "execute", name = "Restore Defaults",
        confirm = function() return "Reset this bar's settings to defaults? Spell selection will be kept." end,
        func = function()
            local s = SB.GetSpecRoot(ESpec())
            local savedSpellID   = s.bars and s.bars[barKey] and s.bars[barKey].spellID
            local savedSpellName = s.bars and s.bars[barKey] and s.bars[barKey].spellName
            if s.bars then s.bars[barKey] = nil end
            if not ESpec() then SB.ReleaseBar(barKey) end
            local fresh = SB.GetBarDB(barKey, ESpec())
            fresh.spellID   = savedSpellID
            fresh.spellName = savedSpellName
            fresh.enabled   = savedSpellID ~= nil
            QueueUpdate()
            NotifyChange()
        end,
    }
    commonArgs.deleteBar = {
        order = 4.6, type = "execute", name = "Delete Bar",
        confirm = function() return "Delete this Special Bar?" end,
        func = function()
            local idx = tonumber(barKey:match("%d+"))
            if SB.RemoveBarSlot then SB.RemoveBarSlot(idx, ESpec()) end
            SettleAfterSlotChange(); NotifyChange()
        end,
    }
    commonArgs.divider = { order = 5, type = "header", name = "" }
    commonArgs.styleBlock = {
        order = 5.05, type = "group", name = "Style", inline = true,
        hidden = function() return not db().spellID end,
        args = StyleArgs("bars", db, function() return IsInBarSetup() and BARSETUP_OWNED or nil end),
    }
    commonArgs.styleSpacer = {
        order = 5.9, type = "description", width = "full", fontSize = "large", name = " ",
        hidden = function() return not db().spellID end,
    }
    end

    local function merge(extra)
        local out = {}
        for k, v in pairs(commonArgs) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        return out
    end

    return {
        layoutGroup = {
            order = 10, type = "group", name = "Layout",
            args = merge({
                styleNote = {
                    order = 0, type = "description", width = "full", fontSize = "medium",
                    hidden = function() return not styleMode end,
                    name = function() return ("|cFFFFD200Editing style '%s'. Bars placed in a Bar Setup ignore these size settings - the Bar Setup tab owns their width.|r\n"):format(curStyle() or "?") end,
                },
                sizeGroup = {
                    order = 10, type = "group", name = "Size", inline = true,
                    args = {
                        barSetupHint = {
                            order = 0, type = "description", width = "full", fontSize = "medium",
                            hidden = function() return not IsInBarSetup() end,
                            name = "|cFFFF4040Active in Bar Setup - width is owned by the Bar Setup tab.|r\n",
                        },
                        groupedHint = {
                            order = 0.1, type = "description", width = "full", fontSize = "medium",
                            hidden = function() return not IsGrouped() end,
                            name = "|cFFF27D2AIn a Bar Group - the group owns size, position and bar style.|r\n",
                        },
                        width = {
                            order = 1, type = "range", name = "Width", min = 50, max = 600, step = 1,
                            get = function() return get("width") end,
                            set = function(_, v) set("width", v) end,
                            disabled = function() return get("inheritWidth") or IsInBarSetup() end,
                        },
                        inheritWidth = {
                            order = 2, type = "toggle", name = "Inherit Width from Anchor",
                            get = function() return get("inheritWidth") end,
                            set = function(_, v) set("inheritWidth", v) end,
                            disabled = function() return IsInBarSetup() end,
                        },
                        inheritWidthOffset = {
                            order = 3, type = "range", name = "Width Nudge", min = -200, max = 200, step = 0.5,
                            get = function() return get("inheritWidthOffset") end,
                            set = function(_, v) set("inheritWidthOffset", v) end,
                            disabled = function() return (not get("inheritWidth")) or IsInBarSetup() end,
                        },
                        height = { order = 4, type = "range", name = "Height", min = 8, max = 60, step = 1, get = function() return get("height") end, set = function(_, v) set("height", v) end, disabled = function() return get("inheritHeight") end },
                        inheritHeight = { order = 5, type = "toggle", name = "Inherit Height from Anchor", get = function() return get("inheritHeight") end, set = function(_, v) set("inheritHeight", v) end },
                        inheritHeightOffset = { order = 6, type = "range", name = "Height Nudge", min = -50, max = 50, step = 0.5, get = function() return get("inheritHeightOffset") end, set = function(_, v) set("inheritHeightOffset", v) end, disabled = function() return not get("inheritHeight") end },
                    },
                },
                appearanceGroup = {
                    order = 11, type = "group", name = "Layout", inline = true,
                    args = {
                        statusBarTexture = { order = 1, type = "select", name = "Texture", dialogControl = "LSM30_Statusbar", values = LSM:HashTable("statusbar"), get = function() return get("statusBarTexture") end, set = function(_, v) set("statusBarTexture", v) end },
                        useClassColor = { order = 2, type = "toggle", name = "Use Class Color", get = function() return get("useClassColor") end, set = function(_, v) set("useClassColor", v) end },
                        customColor = { order = 3, type = "color", name = "Custom Color", hasAlpha = false, disabled = function() return get("useClassColor") end, get = function() return unpackColor(get("customColor"), false) end, set = function(_, r, g, b) set("customColor", { r=r, g=g, b=b }) end },
                        frameStrata = {
                            order = 4, type = "select", name = "Frame Strata",
                            values = STRATA_VALUES, sorting = STRATA_ORDER,
                            get = function() return get("frameStrata") or "MEDIUM" end,
                            set = function(_, v) set("frameStrata", v) end,
                        },
                    },
                },
                placeholderGroup = {
                    order = 12, type = "group", name = "Edit Mode Placeholder", inline = true,
                    args = {
                        placeholderHint = {
                            order = 0, type = "description", width = "full", fontSize = "medium",
                            hidden = function() return not IsInBarSetup() end,
                            name = "|cFFFF4040Forced on in Bar Setup - reserves the bar's slot in the stack.|r\n",
                        },
                        showBackdrop = { order = 1, type = "toggle", name = "Show Placeholder Backdrop", desc = "Show an empty background when not active.", disabled = function() return IsInBarSetup() end, get = function() return get("showBackdrop") or IsInBarSetup() end, set = function(_, v) set("showBackdrop", v) end },
                        backdropColor = { order = 2, type = "color", name = "Backdrop Color", hasAlpha = true, disabled = function() return not (get("showBackdrop") or IsInBarSetup()) end, get = function() return unpackColor(get("backdropColor"), true) end, set = function(_, r, g, b, a) set("backdropColor", {r=r,g=g,b=b,a=a}) end },
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
                        fontOutline = { order = 3, type = "select", name = "Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER, get = function() return get("fontOutline") end, set = function(_, v) set("fontOutline", v) end },
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
                        stackFontOutline = { order = 4, type = "select", name = "Stack Outline", values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER, disabled = function() return not get("showStacks") end, get = function() return get("stackFontOutline") end, set = function(_, v) set("stackFontOutline", v) end },
                        stackPoint = { order = 5, type = "select", name = "Stack Position", values = POINT_VALUES, sorting = POINT_ORDER, disabled = function() return not get("showStacks") end, get = function() return get("stackPoint") end, set = function(_, v) set("stackPoint", v) end },
                        stackXOffset = { order = 6, type = "range", name = "Stack X Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackXOffset") end, set = function(_, v) set("stackXOffset", v) end },
                        stackYOffset = { order = 7, type = "range", name = "Stack Y Offset", min = -20, max = 20, step = 0.5, disabled = function() return not get("showStacks") end, get = function() return get("stackYOffset") end, set = function(_, v) set("stackYOffset", v) end },
                    },
                },
            }),
        },
        anchorGroup = {
            order = 30, type = "group", name = "Anchor & Position",
            hidden = function() return styleMode or IsGrouped() end,
            args = merge({
                anchorSettingsGroup = {
                    order = 50, type = "group", name = "Anchor & Position", inline = true,
                    args = {
                        toggleMovers = {
                            order = 0, type = "execute", name = "Toggle Movers (thingsUI)",
                            func = function()
                                if E and E.ToggleMoveMode then E:ToggleMoveMode("THINGSUI") end
                            end,
                        },
                        barSetupHint = {
                            order = 0.4, type = "description", width = "full", fontSize = "medium",
                            hidden = function() return not IsInBarSetup() end,
                            name = "|cFFFF4040Active in Bar Setup - position is owned by the Bar Setup tab.|r\n",
                        },
                        anchorMode = { order = 1, type = "select", name = "Anchor Frame", width = "double",
                            values  = function() return BuildAnchorValues(true, true, barName) end,
                            sorting = function() return BuildAnchorSorting(true, true, barName) end,
                            disabled = function() return IsInBarSetup() end,
                            get = function() return get("anchorMode") or "UIParent" end,
                            set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                        anchoredToHint = {
                            order = 0.5, type = "description", width = "full", fontSize = "medium",
                            name = function()
                                local users = FindAnchorsTargetingFrame(barName)
                                if #users == 0 then return "" end
                                return "|cFFFFD200Bar anchored to this:|r " .. table.concat(users, ", ") .. "\n"
                            end,
                            hidden = function()
                                return #FindAnchorsTargetingFrame(barName) == 0
                            end,
                        },
                        anchorFrame = { order = 2, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, disabled = function() return IsInBarSetup() end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                        anchorPoint = { order = 3, type = "select", name = "Anchor From", values = POINT_VALUES, sorting = POINT_ORDER, disabled = function() return IsInBarSetup() end, get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                        anchorRelativePoint = { order = 4, type = "select", name = "Anchor To", values = POINT_VALUES, sorting = POINT_ORDER, disabled = function() return IsInBarSetup() end, get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                        anchorXOffset = { order = 5, type = "range", name = "X Offset", min = -500, max = 500, step = 0.5, bigStep = 1, disabled = function() return IsInBarSetup() end, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                        anchorYOffset = { order = 6, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.5, bigStep = 1, disabled = function() return IsInBarSetup() end, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
                    },
                },
            }),
        },
    }
end

function TUI:SpecialIconOptions(keyArg, ctx)
    ctx = ctx or {}
    local styleMode = ctx.styleName ~= nil
    local function curStyle() return (type(ctx.styleName) == "function") and ctx.styleName() or ctx.styleName end
    local function curKey() return type(keyArg) == "function" and keyArg() or keyArg end
    local function iconName() return "TUI_SpecialIcon_" .. (curKey() or "") end
    local function db()
        if styleMode then return SB.Styles.Get("icons", curStyle()) or {} end
        return SB.GetIconDB(curKey(), ESpec())
    end
    local function get(k) return db()[k] end
    local function set(k, v)
        db()[k] = v
        if styleMode then
            SB.Styles.ApplyToUsers("icons", curStyle()); TUI:UpdateSpecialBars(); NotifyChange()
        else
            QueueUpdate()
        end
    end
    local function isGrouped()
        if styleMode then return false end
        local gid = db().customGroup
        if not gid then return false end
        local g = ns.CustomGroups and ns.CustomGroups.GroupByID and ns.CustomGroups.GroupByID(gid)
        return (g and g.enabled) and true or false
    end

    local commonArgs = {}
    if not styleMode then
    commonArgs = CommonHeader("icons")
    commonArgs.spellSelect = {
        order = 1, type = "select", name = "Spell", width = "double",
        values = function() return GetChoicesTable(curKey(), false) end,
        sorting = GetSortedKeys,
        get = function() return db().spellID and tostring(db().spellID) or "" end,
        set = function(_, v)
            local id = tonumber(v)
            if id then
                local usage = SB.GetSpellUsageInfo(id, nil, curKey(), ESpec())
                if usage then
                    E:Print("This spell is already used by " .. usage .. "!")
                    return
                end
            end

            if SB.ReleaseIcon and not ESpec() then SB.ReleaseIcon(curKey()) end
            db().spellID = id
            local rawList = SB.GetRawSpellList(ESpec())
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
        set = function(_, v) db().enabled = v; if not v and not ESpec() then SB.ReleaseIcon(curKey()) end; QueueUpdate() end,
    }
    commonArgs.customGroup = {
        order = 3.5, type = "select",
        name = "|cFF8AC8FFCustom Group|r",
        hidden = function()
            if not db().spellID then return true end
            local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups()
            return not (groups and #groups > 0)
        end,
        values = function()
            local t = { [0] = "|cFF888888Standalone|r" }
            local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups() or {}
            for _, g in ipairs(groups) do t[g.id] = g.name or ("Group " .. g.id) end
            return t
        end,
        sorting = function()
            local groups = ns.CustomGroups and ns.CustomGroups.GetGroups and ns.CustomGroups.GetGroups() or {}
            local sorted = {}
            for _, g in ipairs(groups) do sorted[#sorted + 1] = g end
            table.sort(sorted, function(a, b) return (a.name or "") < (b.name or "") end)
            local order = { 0 }   -- Standalone first
            for _, g in ipairs(sorted) do order[#order + 1] = g.id end
            return order
        end,
        get = function() return db().customGroup or 0 end,
        set = function(_, v)
            db().customGroup = (v ~= 0) and v or nil
            if not ESpec() then SB.ReleaseIcon(curKey()) end
            QueueUpdate()
            if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
            NotifyChange()
        end,
    }
    commonArgs.customGroupLink = {
        order = 3.6, type = "execute", name = "|cFF8AC8FFGo to Custom Group|r",
        hidden = function() return not isGrouped() end,
        func = function()
            local idx
            if ns.CustomGroups and ns.CustomGroups.GetGroups then
                for i, g in ipairs(ns.CustomGroups.GetGroups()) do
                    if g.id == db().customGroup then idx = i; break end
                end
            end
            E:ToggleOptions(idx and ("thingsUI,modulesTab,customGroups,group" .. idx)
                or "thingsUI,modulesTab,customGroups")
        end,
    }
    commonArgs.restoreDefaults = {
        order = 4.5, type = "execute", name = "Restore Defaults",
        confirm = function() return "Reset this icon's settings to defaults? Spell selection will be kept." end,
        func = function()
            local s = SB.GetSpecRoot(ESpec())
            local savedSpellID   = s.icons and s.icons[curKey()] and s.icons[curKey()].spellID
            local savedSpellName = s.icons and s.icons[curKey()] and s.icons[curKey()].spellName
            if s.icons then s.icons[curKey()] = nil end
            if not ESpec() then SB.ReleaseIcon(curKey()) end
            local fresh = SB.GetIconDB(curKey(), ESpec())
            fresh.spellID   = savedSpellID
            fresh.spellName = savedSpellName
            fresh.enabled   = savedSpellID ~= nil
            QueueUpdate()
            NotifyChange()
        end,
    }
    commonArgs.copyIcon = {
        order = 4.4, type = "execute", name = "|cFF8AC8FFCopy Icon|r",
        hidden = function() return not db().spellID end,
        disabled = function() local s = SB.GetSpecRoot(ESpec()); return (s.iconCount or 3) >= (SB.MAX_SLOTS or 12) end,
        func = function()
            local s = SB.GetSpecRoot(ESpec()); local c = s.iconCount or 3
            if c >= (SB.MAX_SLOTS or 12) then return end
            local copy = ns.DeepCopy(db())
            copy.spellID, copy.spellName = nil, nil   -- can't track one spell twice; keep the style, pick a new spell
            copy.enabled = false
            local newKey = "icon" .. (c + 1)
            s.icons = s.icons or {}
            s.icons[newKey] = copy
            s.iconCount = c + 1
            TUI:UpdateSpecialBars(); NotifyChange()
            if ns.SB_OpenIconEditor then ns.SB_OpenIconEditor(newKey) end
        end,
    }
    commonArgs.deleteIcon = {
        order = 4.6, type = "execute", name = "Delete Icon",
        confirm = function() return "Delete this Special Icon?" end,
        func = function()
            local idx = tonumber(curKey():match("%d+"))
            if SB.RemoveIconSlot then SB.RemoveIconSlot(idx, ESpec()) end
            if ns.SB_CloseIconEditor then ns.SB_CloseIconEditor() end
            SettleAfterSlotChange(); NotifyChange()
        end,
    }
    commonArgs.divider = { order = 5, type = "header", name = "" }
    commonArgs.styleBlock = {
        order = 5.05, type = "group", name = "Style", inline = true,
        hidden = function() return not db().spellID end,
        args = StyleArgs("icons", db, function() return isGrouped() and GROUPED_ICON_OWNED or nil end),
    }
    commonArgs.styleSpacer = {
        order = 5.9, type = "description", width = "full", fontSize = "large", name = " ",
        hidden = function() return not db().spellID end,
    }
    end

    local function merge(extra)
        local out = {}
        for k, v in pairs(commonArgs) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        return out
    end

    return {
        appearGroup = {
            order = 10, type = "group", name = "Layout",
            args = merge({
                styleNote = {
                    order = 0, type = "description", width = "full", fontSize = "medium",
                    hidden = function() return not styleMode end,
                    name = function() return ("|cFFFFD200Editing style '%s'. Size & border apply when the icon isn't in a Custom Group (the group owns those).|r\n"):format(curStyle() or "?") end,
                },
                sizeStyleGroup = {
                    order = 10, type = "group", name = "Size & Style", inline = true,
                    args = {
                        keepAspectRatio = { order = 1, type = "toggle", name = "Square Icons",
                            disabled = function() return isGrouped() end,
                            get = function() return get("keepAspectRatio") ~= false end,
                            set = function(_, v)
                                if v then set("height", get("width") or 36) end
                                set("keepAspectRatio", v)
                            end },
                        size = { order = 2, type = "range", name = "Size", min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") == false end,
                            disabled = function() return isGrouped() end,
                            get = function() return get("width") or 36 end,
                            set = function(_, v) set("width", v); set("height", v) end },
                        width  = { order = 3, type = "range", name = "Width",  min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") ~= false end,
                            disabled = function() return isGrouped() end,
                            get = function() return get("width") or 36 end,
                            set = function(_, v) set("width", v) end },
                        height = { order = 4, type = "range", name = "Height", min = 16, max = 128, step = 0.01, bigStep = 1,
                            hidden = function() return get("keepAspectRatio") ~= false end,
                            disabled = function() return isGrouped() end,
                            get = function() return get("height") or 36 end,
                            set = function(_, v) set("height", v) end },
                        iconLockAspectRatio = { order = 4.5, type = "toggle", name = "Lock Icon Aspect Ratio",
                            hidden = function() return get("keepAspectRatio") ~= false end,
                            disabled = function() return isGrouped() end,
                            get = function() return get("iconLockAspectRatio") ~= false end,
                            set = function(_, v) set("iconLockAspectRatio", v) end },
                        zoom   = { order = 5, type = "range", name = "Zoom", min = 0, max = 0.45, step = 0.01, bigStep = 0.05, isPercent = true,
                            disabled = function() return isGrouped() end,
                            get = function() return get("zoom") end, set = function(_, v) set("zoom", v) end },
                        desaturate = { order = 6, type = "toggle", name = "Show when Idle",
                            disabled = function() return isGrouped() end,
                            get = function() return get("desaturateWhenInactive") end, set = function(_, v) set("desaturateWhenInactive", v) end },
                        frameStrata = {
                            order = 7, type = "select", name = "Frame Strata",
                            values = STRATA_VALUES, sorting = STRATA_ORDER,
                            disabled = function() return isGrouped() end,
                            get = function() return get("frameStrata") or "MEDIUM" end,
                            set = function(_, v) set("frameStrata", v) end,
                        },
                    },
                },
                cooldownGroup = {
                    order = 11, type = "group", name = "Cooldown", inline = true,
                    args = {
                        showCooldown = { order = 1, type = "toggle", name = "Show Cooldown Sweep",
                            disabled = function() return isGrouped() end,
                            get = function() return get("showCooldown") end, set = function(_, v) set("showCooldown", v) end },
                        invertSwipe = { order = 2, type = "toggle", name = "Invert Sweep",
                            disabled = function() return not get("showCooldown") or isGrouped() end,
                            get = function() return get("invertSwipe") end, set = function(_, v) set("invertSwipe", v) end },
                        groupSwipeHint = { order = 3, type = "description", width = "full",
                            hidden = function() return not isGrouped() end,
                            name = "|cff888888The Custom Group's aura settings control the sweep while grouped.|r" },
                        showPandemic = { order = 3, type = "toggle", name = "Pandemic Indicator",
                            get = function() return get("showPandemic") end,
                            set = function(_, v) set("showPandemic", v) end },
                    },
                },
                borderGroup = {
                    order = 12, type = "group", name = "Border", inline = true,
                    args = {
                        showBorder  = { order = 1, type = "toggle", name = "Show Border",
                            get = function() return get("showBorder") end,
                            set = function(_, v) set("showBorder", v) end },
                        borderSize  = { order = 2, type = "range", name = "Size",  min = 1, max = 16,  step = 0.01, bigStep = 1,
                            disabled = function()
                                if not get("showBorder") then return true end
                                local AL = ns.AuraLane
                                local style = AL and AL.MapGlowStyle(get("glowType")) or "pulse"
                                return get("showGlow") and style == "pixel" and get("glowBorderStroke") and true or false
                            end,
                            get = function() return get("borderSize") end,
                            set = function(_, v) set("borderSize", v) end },
                        borderColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                            disabled = function() return not get("showBorder") end,
                            get = function() return unpackColor(get("borderColor"), true) end,
                            set = function(_, r, g, b, a) set("borderColor", { r=r, g=g, b=b, a=a }) end },
                        borderInset = { order = 4, type = "range", name = "Inset", min = -10, max = 10, step = 0.01, bigStep = 1,
                            disabled = function() return not get("showBorder") end,
                            get = function() return get("borderInset") end,
                            set = function(_, v) set("borderInset", v) end },
                    },
                },
                glowGroup = {
                    order = 13, type = "group", name = "Glow While Active", inline = true,
                    args = {
                        glowNote = {
                            order = 0, type = "description", width = "full", fontSize = "medium",
                            name = function() return ("|cFFFFD200Makeshift glows, unfortunately LibCustomGlow doesn't work with aura containers yet|r\n"):format(curStyle() or "?") end, },
                        showGlow = { order = 1, type = "toggle", name = "Show Glow",
                            get = function() return get("showGlow") end,
                            set = function(_, v) set("showGlow", v) end },
                        glowType = { order = 2, type = "select", name = "Style",
                            disabled = function() return not get("showGlow") end,
                            values = { ["pulse"]="Pulse Ring", ["pixel"]="Pixel Glow", ["proc"]="Proc Glow", ["ants"]="Marching Ants" },
                            get = function()
                                local AL = ns.AuraLane
                                return AL and AL.MapGlowStyle(get("glowType")) or "pulse"
                            end,
                            set = function(_, v) set("glowType", v) end },
                        glowColor = { order = 3, type = "color", name = "Color", hasAlpha = true,
                            disabled = function() return not get("showGlow") end,
                            get = function() return unpackColor(get("glowColor"), true) end,
                            set = function(_, r, g, b, a) set("glowColor", { r=r, g=g, b=b, a=a }) end },
                        glowThickness = { order = 4, type = "range", name = "Thickness", min = 1, max = 10, step = 1,
                            disabled = function()
                                local AL = ns.AuraLane
                                local style = AL and AL.MapGlowStyle(get("glowType")) or "pulse"
                                return not get("showGlow") or (style ~= "pulse" and style ~= "pixel")
                            end,
                            get = function() return get("glowThickness") or 2 end,
                            set = function(_, v) set("glowThickness", v) end },
                        glowBorderStroke = { order = 4.5, type = "toggle", name = "Bordered Stroke",
                            hidden = function()
                                local AL = ns.AuraLane
                                return (AL and AL.MapGlowStyle(get("glowType")) or "pulse") ~= "pixel"
                            end,
                            disabled = function() return not get("showGlow") or not get("showBorder") end,
                            get = function() return get("glowBorderStroke") end,
                            set = function(_, v) set("glowBorderStroke", v) end },
                        glowLines = { order = 5, type = "range", name = "Particles", min = 1, max = 12, step = 1,
                            hidden = function()
                                local AL = ns.AuraLane
                                return (AL and AL.MapGlowStyle(get("glowType")) or "pulse") ~= "pixel"
                            end,
                            disabled = function() return not get("showGlow") end,
                            get = function() return get("glowLines") or 8 end,
                            set = function(_, v) set("glowLines", v) end },
                        glowLength = { order = 6, type = "range", name = "Line Length", min = 1, max = 6, step = 1,
                            hidden = function()
                                local AL = ns.AuraLane
                                return (AL and AL.MapGlowStyle(get("glowType")) or "pulse") ~= "pixel"
                            end,
                            disabled = function() return not get("showGlow") end,
                            get = function() return get("glowLength") or 3 end,
                            set = function(_, v) set("glowLength", v) end },
                        glowOffset = { order = 7, type = "range", name = "Offset", min = -6, max = 8, step = 0.01, bigStep = 1,
                            hidden = function()
                                local AL = ns.AuraLane
                                return (AL and AL.MapGlowStyle(get("glowType")) or "pulse") ~= "pixel"
                            end,
                            disabled = function() return not get("showGlow") end,
                            get = function() return get("glowOffset") or 0 end,
                            set = function(_, v) set("glowOffset", v) end },
                        glowSpeed = { order = 8, type = "range", name = "Speed", min = 0.05, max = 1, step = 0.05,
                            hidden = function()
                                local AL = ns.AuraLane
                                return (AL and AL.MapGlowStyle(get("glowType")) or "pulse") ~= "pixel"
                            end,
                            disabled = function() return not get("showGlow") end,
                            get = function() return get("glowSpeed") or 0.25 end,
                            set = function(_, v) set("glowSpeed", v) end },
                    },
                },
            }),
        },
        textGroup = {
            order = 15, type = "group", name = "Text",
            args = merge({
                overrideGroupText = {
                    order = 5, type = "toggle", name = "|cFF8AC8FFOverride Custom Group Text|r", width = "full",
                    hidden = function() return not isGrouped() end,
                    get = function() return get("overrideGroupText") end,
                    set = function(_, v) set("overrideGroupText", v) end,
                },
                groupTextNote = {
                    order = 6, type = "description", width = "full", fontSize = "medium",
                    hidden = function() return not isGrouped() or get("overrideGroupText") end,
                    name = "|cFF888888Cooldown text follows the Custom Group. Enable the toggle above to set your own.|r\n",
                },
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
                            values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                            disabled = function() return not get("showStacks") end,
                            get = function() return get("stackFontOutline") end,
                            set = function(_, v) set("stackFontOutline", v) end },
                        stackColor  = { order = 5, type = "color", name = "Color", hasAlpha = false,
                            disabled = function() return not get("showStacks") end,
                            get = function() return unpackColor(get("stackColor"), false) end,
                            set = function(_, r, g, b) set("stackColor", { r=r, g=g, b=b }) end },
                        stackPoint  = { order = 6, type = "select", name = "Position",
                            values = POINT_VALUES, sorting = POINT_ORDER,
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
                            values = ns.OUTLINE.VALUES, sorting = ns.OUTLINE.ORDER,
                            disabled = function() return not get("showDuration") end,
                            get = function() return get("durationFontOutline") end,
                            set = function(_, v) set("durationFontOutline", v) end },
                        durationColor  = { order = 5, type = "color", name = "Color", hasAlpha = false,
                            disabled = function() return not get("showDuration") end,
                            get = function() return unpackColor(get("durationColor"), false) end,
                            set = function(_, r, g, b) set("durationColor", { r=r, g=g, b=b }) end },
                        durationPoint  = { order = 6, type = "select", name = "Position",
                            values = POINT_VALUES, sorting = POINT_ORDER,
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
            order = 20, type = "group", name = "Anchor & Position",
            hidden = function() return isGrouped() or styleMode end,
            args = merge({
                anchorSettingsGroup = {
                    order = 50, type = "group", name = "Anchor & Position", inline = true,
                    args = {
                        toggleMovers = {
                            order = 0, type = "execute", name = "Toggle Movers (thingsUI)",
                            func = function()
                                if E and E.ToggleMoveMode then E:ToggleMoveMode("THINGSUI") end
                            end,
                        },
                        anchorMode = { order = 1, type = "select", name = "Anchor Frame", width = "double",
                            values  = function() return BuildAnchorValues(true, true, iconName()) end,
                            sorting = function() return BuildAnchorSorting(true, true, iconName()) end,
                            get = function() return get("anchorMode") or "UIParent" end,
                            set = function(_, v) db().anchorMode = v; if v ~= "CUSTOM" then db().anchorFrame = v end; QueueUpdate() end },
                        anchoredToHint = {
                            order = 0.5, type = "description", width = "full", fontSize = "medium",
                            name = function()
                                local users = FindAnchorsTargetingFrame(iconName())
                                if #users == 0 then return "" end
                                return "|cFFFFD200Anchored to this:|r " .. table.concat(users, ", ") .. "\n"
                            end,
                            hidden = function()
                                return #FindAnchorsTargetingFrame(iconName()) == 0
                            end,
                        },
                        anchorFrame = { order = 2, type = "input", name = "Custom Frame Name", width = "double", hidden = function() return get("anchorMode") ~= "CUSTOM" end, get = function() return get("anchorFrame") end, set = function(_, v) set("anchorFrame", v) end },
                        anchorPoint = { order = 3, type = "select", name = "Anchor From",
                            values = POINT_VALUES, sorting = POINT_ORDER,
                            get = function() return get("anchorPoint") end, set = function(_, v) set("anchorPoint", v) end },
                        anchorRelativePoint = { order = 4, type = "select", name = "Anchor To",
                            values = POINT_VALUES, sorting = POINT_ORDER,
                            get = function() return get("anchorRelativePoint") end, set = function(_, v) set("anchorRelativePoint", v) end },
                        anchorXOffset = { order = 5, type = "range", name = "X Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorXOffset") end, set = function(_, v) set("anchorXOffset", v) end },
                        anchorYOffset = { order = 6, type = "range", name = "Y Offset", min = -500, max = 500, step = 0.01, bigStep = 1, get = function() return get("anchorYOffset") end, set = function(_, v) set("anchorYOffset", v) end },
                    },
                },
            }),
        },
    }
end