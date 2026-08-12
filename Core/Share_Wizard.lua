local _, ns = ...
local E = ns.E

ns.ShareWizard = ns.ShareWizard or {}
local W = ns.ShareWizard

local MODE_META = {
    { key = "choose",    label = "Choose items..." },
    { key = "add",       label = "Add new only (keep everything I have)" },
    { key = "overwrite", label = "Overwrite everything" },
}

local function EnsureItem(p, it)
    p.items[it.id] = p.items[it.id] or { include = (not it.exists) and true or false, fields = nil }
    return p.items[it.id]
end

local function FieldChecked(item, key)
    return item.fields == nil or item.fields[key] == true
end

local function SetField(item, groups, key, val)
    if item.fields == nil then
        item.fields = {}
        for _, fg in ipairs(groups) do item.fields[fg.key] = true end
    end
    item.fields[key] = val or nil
end

function W.ShowExport(str)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not (AceGUI and str and str ~= "") then return end
    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    f:SetTitle("|cFF8080FFthingsUI|r Export")
    f:SetWidth(560)
    f:SetHeight(380)
    f:SetLayout("Fill")
    f:SetStatusText("Ctrl+C to copy, then close")
    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:DisableButton(true)
    eb:SetText(str)
    f:AddChild(eb)
    eb.editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(str); self:HighlightText() end
    end)
    eb.editBox:HighlightText()
    eb.editBox:SetFocus()
end

function W.Open(str)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then
        print("|cFF8080FFthingsUI|r: AceGUI unavailable.")
        return
    end

    local A, plan, chosen, single
    local stage, render
    local pasteText, pasteErr = "", nil

    local function InitFromAnalysis(a)
        A = a
        single = #A.sections == 1
        plan, chosen = {}, {}
        for _, sec in ipairs(A.sections) do
            chosen[sec.index] = single
            plan[sec.index] = { mode = sec.collection and "choose" or "overwrite", items = {} }
        end
        stage = single and "config" or "start"
    end

    if str and tostring(str):gsub("%s", "") ~= "" then
        local a = ns.Share and ns.Share.Analyze(str)
        if not (a and #a.sections > 0) then
            print("|cFF8080FFthingsUI|r: nothing importable in that string.")
            return
        end
        InitFromAnalysis(a)
    else
        stage = "paste"
    end

    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    f:SetTitle("|cFF8080FFthingsUI|r Import")
    f:SetWidth(680)
    f:SetHeight(640)
    f:SetLayout("Fill")

    local function Add(c, wtype, setup)
        local w = AceGUI:Create(wtype)
        if setup then setup(w) end
        c:AddChild(w)
        return w
    end

    local function Heading(c, text)
        return Add(c, "Heading", function(w) w:SetText(text); w:SetFullWidth(true) end)
    end

    local function Label(c, text)
        return Add(c, "Label", function(w)
            w:SetText(text); w:SetFullWidth(true)
            w:SetFontObject(GameFontHighlight)
        end)
    end

    local function SecName(sec)
        return ("|cFF%s%s|r"):format(sec.color or "FFD200", sec.name)
    end

    local function SectionLine(sec)
        local extra = sec.collection
            and (" |cFF888888(%d new, %d already exist)|r"):format(sec.newCount or 0, sec.dupCount or 0) or ""
        return SecName(sec) .. extra
    end

    local function ApplyAll()
        local p = {}
        for _, sec in ipairs(A.sections) do p[sec.index] = { mode = "overwrite" } end
        ns.Share.ApplyPlan(A.data, p)
        AceGUI:Release(f)
        ReloadUI()
    end

    local function ApplyChosen()
        local p = {}
        for _, sec in ipairs(A.sections) do
            p[sec.index] = chosen[sec.index] and plan[sec.index] or { mode = "skip" }
        end
        ns.Share.ApplyPlan(A.data, p)
        AceGUI:Release(f)
        ReloadUI()
    end

    local function BuildPaste(c)
        Heading(c, "Paste an export string")
        Add(c, "MultiLineEditBox", function(w)
            w:SetLabel("")
            w:SetFullWidth(true)
            w:SetNumLines(14)
            w:DisableButton(true)
            w:SetText(pasteText)
            w:SetCallback("OnTextChanged", function(_, _, text) pasteText = text or "" end)
        end)
        if pasteErr then
            Label(c, "|cFFFF6060" .. pasteErr .. "|r")
        end
        Add(c, "Button", function(w)
            w:SetText("Continue >"); w:SetWidth(160)
            w:SetCallback("OnClick", function()
                local a = ns.Share and ns.Share.Analyze(pasteText)
                if a and #a.sections > 0 then
                    pasteErr = nil
                    InitFromAnalysis(a)
                else
                    pasteErr = "Not a valid thingsUI export string."
                end
                render()
            end)
        end)
    end

    local function BuildStart(c)
        Heading(c, "What's in this import")
        for _, sec in ipairs(A.sections) do
            Label(c, SectionLine(sec))
        end
        Label(c, " ")
        local armed
        local btnAll = Add(c, "Button", function(w)
            w:SetText("Import ALL (overwrite)")
            w:SetFullWidth(true)
        end)
        btnAll:SetCallback("OnClick", function()
            if armed then
                ApplyAll()
            else
                armed = true
                btnAll:SetText("|cFFFF6060Overwrites every listed section and reloads - click again|r")
            end
        end)
        Add(c, "Button", function(w)
            w:SetText("Choose Modules...")
            w:SetFullWidth(true)
            w:SetCallback("OnClick", function() stage = "modules"; render() end)
        end)
    end

    local function BuildModules(c)
        Heading(c, "Choose modules")
        Label(c, "Only ticked modules are imported.")
        Add(c, "Button", function(w)
            w:SetText("Select All"); w:SetWidth(120)
            w:SetCallback("OnClick", function()
                for _, sec in ipairs(A.sections) do chosen[sec.index] = true end
                render()
            end)
        end)
        Add(c, "Button", function(w)
            w:SetText("Clear All"); w:SetWidth(120)
            w:SetCallback("OnClick", function()
                for _, sec in ipairs(A.sections) do chosen[sec.index] = false end
                render()
            end)
        end)
        Label(c, " ")
        for _, sec in ipairs(A.sections) do
            Add(c, "CheckBox", function(w)
                w:SetFullWidth(true)
                w:SetLabel(SectionLine(sec))
                w:SetValue(chosen[sec.index] == true)
                w:SetCallback("OnValueChanged", function(_, _, v) chosen[sec.index] = v and true or false end)
            end)
        end
        Label(c, " ")
        Add(c, "Button", function(w)
            w:SetText("< Back"); w:SetWidth(120)
            w:SetCallback("OnClick", function() stage = "start"; render() end)
        end)
        Add(c, "Button", function(w)
            w:SetText("Continue >"); w:SetWidth(140)
            w:SetCallback("OnClick", function()
                for _, sec in ipairs(A.sections) do
                    if chosen[sec.index] then stage = "config"; render(); return end
                end
                print("|cFF8080FFthingsUI|r: tick at least one module.")
            end)
        end)
    end

    local function SecByIndex(idx)
        for _, s in ipairs(A.sections) do if s.index == idx then return s end end
    end

    local function BuildItems(c, sec, p, rerender)
        local newItems, dupItems = {}, {}
        for _, it in ipairs(sec.items or {}) do
            local bucket = it.exists and dupItems or newItems
            bucket[#bucket + 1] = it
        end
        if #newItems > 0 then
            Label(c, "|cFF40FF40New|r")
            for _, it in ipairs(newItems) do
                local item = EnsureItem(p, it)
                Add(c, "CheckBox", function(w)
                    w:SetFullWidth(true); w:SetLabel(it.label); w:SetValue(item.include)
                    w:SetCallback("OnValueChanged", function(_, _, v) item.include = v and true or false end)
                end)
            end
            Label(c, " ")
        end
        if #dupItems > 0 then
            Label(c, "|cFFFFD200Already exist|r")
            for _, it in ipairs(dupItems) do
                local item = EnsureItem(p, it)
                if sec.fieldGroups then
                    local grp = Add(c, "InlineGroup", function(w)
                        w:SetTitle(it.label); w:SetFullWidth(true); w:SetLayout("Flow")
                    end)
                    Add(grp, "CheckBox", function(w)
                        w:SetFullWidth(true); w:SetLabel("|cFFFF6060Overwrite mine|r"); w:SetValue(item.include)
                        w:SetCallback("OnValueChanged", function(_, _, v) item.include = v and true or false; rerender() end)
                    end)
                    if item.include then
                        for _, fg in ipairs(sec.fieldGroups) do
                            Add(grp, "CheckBox", function(w)
                                w:SetWidth(200); w:SetLabel(fg.label); w:SetValue(FieldChecked(item, fg.key))
                                w:SetCallback("OnValueChanged", function(_, _, v) SetField(item, sec.fieldGroups, fg.key, v) end)
                            end)
                        end
                    end
                else
                    Add(c, "CheckBox", function(w)
                        w:SetFullWidth(true)
                        w:SetLabel(it.label .. " |cFF888888- overwrites yours|r")
                        w:SetValue(item.include)
                        w:SetCallback("OnValueChanged", function(_, _, v) item.include = v and true or false end)
                    end)
                end
            end
        end
    end

    local function BuildSectionPage(c, sec, rerender)
        Heading(c, SecName(sec))
        if not sec.collection then
            Label(c, "Imports this whole section, replacing your current settings for it.")
            return
        end
        local p = plan[sec.index]
        for _, m in ipairs(MODE_META) do
            Add(c, "CheckBox", function(w)
                w:SetType("radio"); w:SetFullWidth(true)
                w:SetLabel(m.label)
                w:SetValue(p.mode == m.key)
                w:SetCallback("OnValueChanged", function() p.mode = m.key; rerender() end)
            end)
        end
        Label(c, " ")
        if p.mode == "overwrite" then
            Label(c, ("|cFFFF6060Replaces your whole %s section.|r"):format(sec.name))
        elseif p.mode == "add" then
            Label(c, ("|cFF40FF40Adds %d new item(s); anything you already have is untouched.|r"):format(sec.newCount or 0))
        else
            BuildItems(c, sec, p, rerender)
        end
    end

    local function BuildFinish(c)
        Heading(c, "Ready to import")
        for _, sec in ipairs(A.sections) do
            local p = chosen[sec.index] and plan[sec.index]
            local line
            if not p or p.mode == "skip" then
                line = ("|cFF888888%s - skipped|r"):format(sec.name)
            elseif p.mode == "overwrite" then
                line = SecName(sec) .. " |cFFFF6060- overwrite all|r"
            elseif p.mode == "add" then
                line = SecName(sec) .. (" |cFF40FF40- add %d new|r"):format(sec.newCount or 0)
            else
                local inc = 0
                for _, it in ipairs(sec.items or {}) do
                    local i = p.items[it.id]
                    if i and i.include then inc = inc + 1 end
                end
                line = SecName(sec) .. (" |cFF8AC8FF- %d item(s)|r"):format(inc)
            end
            Label(c, line)
        end
        Label(c, " ")
        Label(c, "|cFFFF6060Applies the import and reloads your UI.|r")
        Add(c, "Button", function(w)
            w:SetText("Apply & Reload"); w:SetWidth(200)
            w:SetCallback("OnClick", ApplyChosen)
        end)
    end

    local function BuildConfig()
        local nodes = {}
        if not single then
            nodes[#nodes + 1] = { value = "back", text = "|cFF888888< Choose Modules|r" }
        end
        for _, sec in ipairs(A.sections) do
            if chosen[sec.index] then
                nodes[#nodes + 1] = { value = tostring(sec.index), text = SecName(sec) }
            end
        end
        nodes[#nodes + 1] = { value = "finish", text = "|cFF40FF40Finish|r" }
        local firstValue = nodes[single and 1 or 2].value

        local tree = Add(f, "TreeGroup", function(w)
            w:SetLayout("Fill")
            w:SetTree(nodes)
            w:SetTreeWidth(170, false)
        end)
        tree:SetCallback("OnGroupSelected", function(widget, _, value)
            if value == "back" then
                C_Timer.After(0, function() stage = "modules"; render() end)
                return
            end
            widget:ReleaseChildren()
            local scroll = Add(widget, "ScrollFrame", function(w) w:SetLayout("Flow") end)
            if value == "finish" then
                BuildFinish(scroll)
            else
                local sec = SecByIndex(tonumber(value))
                if sec then
                    BuildSectionPage(scroll, sec, function() tree:SelectByValue(value) end)
                    Label(scroll, " ")
                    Add(scroll, "Button", function(w)
                        w:SetText("Next >"); w:SetWidth(140)
                        w:SetCallback("OnClick", function()
                            for i, n in ipairs(nodes) do
                                if n.value == value then
                                    tree:SelectByValue(nodes[i + 1] and nodes[i + 1].value or "finish")
                                    return
                                end
                            end
                        end)
                    end)
                end
            end
            scroll:DoLayout()
        end)
        tree:SelectByValue(firstValue)
    end

    render = function()
        f:ReleaseChildren()
        if stage == "paste" then
            f:SetStatusText("Paste & continue")
            local scroll = Add(f, "ScrollFrame", function(w) w:SetLayout("Flow") end)
            BuildPaste(scroll)
            scroll:DoLayout()
        elseif stage == "start" then
            f:SetStatusText("Overview")
            local scroll = Add(f, "ScrollFrame", function(w) w:SetLayout("Flow") end)
            BuildStart(scroll)
            scroll:DoLayout()
        elseif stage == "modules" then
            f:SetStatusText("Choose modules")
            local scroll = Add(f, "ScrollFrame", function(w) w:SetLayout("Flow") end)
            BuildModules(scroll)
            scroll:DoLayout()
        else
            f:SetStatusText("Configure each module, then Finish")
            BuildConfig()
        end
    end

    render()
end
