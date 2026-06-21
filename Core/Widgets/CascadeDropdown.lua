local _, ns = ...
local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local select, pairs, ipairs, type, tostring = select, pairs, ipairs, type, tostring

local function Fixlevels(parent, ...)
    local i = 1
    local child = select(i, ...)
    while child do
        child:SetFrameLevel(parent:GetFrameLevel() + 1)
        Fixlevels(child, child:GetChildren())
        i = i + 1
        child = select(i, ...)
    end
end

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}
local CLASS_INDEX = {}
for i, t in ipairs(CLASS_ORDER) do CLASS_INDEX[t] = i end

local ClassColor = ns.ClassColor

local function ClassLabel(token)
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
    return ClassColor(token) .. name .. "|r"
end

local function ParseKey(key)
    if type(key) ~= "string" then return nil end
    local classToken, rest = key:match("^([A-Z_]+):(.+)$")
    if not classToken then return nil end
    local specID, leafKey = rest:match("^(%d+):(.+)$")
    if specID then return classToken, tonumber(specID), leafKey end
    specID = rest:match("^(%d+)$")
    if specID then return classToken, tonumber(specID), nil end
    return nil
end

local function GroupValues(values)
    local grouped = {}
    local other = {}
    for value, label in pairs(values) do
        local classToken, specID, _ = ParseKey(value)
        if classToken and specID then
            grouped[classToken] = grouped[classToken] or {}
            grouped[classToken][specID] = grouped[classToken][specID] or {}
            local bucket = grouped[classToken][specID]
            bucket[#bucket + 1] = { value = value, label = label }
        else
            other[#other + 1] = { value = value, label = label }
        end
    end
    return grouped, other
end

-- Spec cache
local GetSpecMeta = ns.SpecMeta

local function SpecLabel(specID, fallback)
    local m = GetSpecMeta(specID)
    if not m then return fallback or tostring(specID) end
    local iconStr = m.icon and ("|T"..m.icon..":14:14|t ") or ""
    return iconStr .. (m.name or fallback or tostring(specID))
end


-- Widget def
do
    local widgetType = "TUI_CascadeDropdown"
    local widgetVersion = 1

    local PopulatePullout

    -- Event handlers 
    local function Control_OnEnter(this) this.obj.button:LockHighlight(); this.obj:Fire("OnEnter") end
    local function Control_OnLeave(this) this.obj.button:UnlockHighlight(); this.obj:Fire("OnLeave") end
    local function Dropdown_OnHide(this) if this.obj.open then this.obj.pullout:Close() end end

    local function Dropdown_TogglePullout(this)
        local self = this.obj
        if self.open then
            self.open = nil
            self.pullout:Close()
            AceGUI:ClearFocus()
        else
            if self.pulloutDirty then
                PopulatePullout(self)
                self.pulloutDirty = nil
            end
            self.open = true
            self.pullout:SetWidth(self.pulloutWidth or self.frame:GetWidth())
            self.pullout:Open("TOPLEFT", self.frame, "BOTTOMLEFT", 0, self.label:IsShown() and -2 or 0)
            AceGUI:SetFocus(self)
        end
    end

    local activeOpenDropdown
    local function IsClickInside(self, mouseFrame)
        if not mouseFrame then return false end
        local f = mouseFrame
        while f do
            if f == self.pullout.frame or f == self.frame then return true end
            if f._tuiCascadeOwner == self then return true end
            f = f:GetParent()
        end
        return false
    end

    local function GetClickedFrames()
        if GetMouseFoci then return GetMouseFoci() end
        if GetMouseFocus then return { GetMouseFocus() } end
        return {}
    end

    local function ClickIsInsideAny(self, frames)
        for _, f in ipairs(frames or {}) do
            if IsClickInside(self, f) then return true end
        end
        return false
    end

    local mouseListener = CreateFrame("Frame")
    mouseListener:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mouseListener:SetScript("OnEvent", function(_, _, button)
        if not activeOpenDropdown or not activeOpenDropdown.open then return end
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        local frames = GetClickedFrames()
        if not ClickIsInsideAny(activeOpenDropdown, frames) then
            activeOpenDropdown.pullout:Close()
        end
    end)

    local function OnPulloutOpen(this)
        local self = this.userdata.obj
        self.open = true
        activeOpenDropdown = self
        self:Fire("OnOpened")
    end
    local function OnPulloutClose(this)
        local self = this.userdata.obj
        self.open = nil
        if activeOpenDropdown == self then activeOpenDropdown = nil end
        self:Fire("OnClosed")
    end

    local function ShowMultiText(self)
        local n = 0
        for _, v in pairs(self.selected or {}) do if v then n = n + 1 end end
        if n == 0 then
            self:SetText("|cFF888888None selected|r")
        elseif n == 1 then
            self:SetText("1 spec selected")
        else
            self:SetText(n .. " specs selected")
        end
    end

    local reopenPending = false

    local function OnLeafToggle(item, _, checked)
        local self = item.userdata.obj
        local value = item.userdata.value
        if self.multiselect then
            self.selected = self.selected or {}
            self.selected[value] = checked and true or nil
            self:Fire("OnValueChanged", value, checked)
            ShowMultiText(self)

            self.preserveOpenAcrossRefresh = true
            self:Fire("OnClosed")
        else
            if checked then
                self.value = value
                self:SetText(self.list[value] or "")
                self:Fire("OnValueChanged", value)
                if self.open then self.pullout:Close() end
            else
                item:SetValue(true)
            end
        end
    end

    -- Tree construction
    local function MakeLeafItem(self, leaf, text)
        local item = AceGUI:Create("Dropdown-Item-Toggle")
        if self.multiselect then
            item:SetValue((self.selected or {})[leaf.value] == true)
        else
            item:SetValue(self.value == leaf.value)
        end
        item:SetText(text or leaf.label)
        item.userdata.obj = self
        item.userdata.value = leaf.value
        item:SetCallback("OnValueChanged", OnLeafToggle)
        if item.frame then item.frame._tuiCascadeOwner = self end
        return item
    end

    -- Build a class/spec submenu item that tags itself for click-outside.
    local function MakeMenuItem(self, text)
        local item = AceGUI:Create("Dropdown-Item-Menu")
        item:SetText(text)
        item.userdata.obj = self
        item.SetValue = function() end
        if item.frame then item.frame._tuiCascadeOwner = self end
        return item
    end

    local function MakeSubPullout(self)
        local sub = AceGUI:Create("Dropdown-Pullout")
        sub:SetHideOnLeave(true)
        sub.frame._tuiCascadeOwner = self
        return sub
    end

    function PopulatePullout(self)
        local pullout = self.pullout
        pullout:Clear()

        local grouped, other = GroupValues(self.list or {})

        local classTokens = {}
        for token in pairs(grouped) do classTokens[#classTokens + 1] = token end
        table.sort(classTokens, function(a, b)
            local na = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[a]) or a
            local nb = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[b]) or b
            return na < nb
        end)

        for _, classToken in ipairs(classTokens) do
            local specMap = grouped[classToken]
            local specIDs = {}
            for sid in pairs(specMap) do specIDs[#specIDs + 1] = sid end
            table.sort(specIDs)

            local classItem = MakeMenuItem(self, ClassLabel(classToken))
            local classSub = MakeSubPullout(self)

            for _, specID in ipairs(specIDs) do
                local leaves = specMap[specID]
                local specLabel = SpecLabel(specID)

                if #leaves == 1 and not leaves[1].label:find(":") then
                    classSub:AddItem(MakeLeafItem(self, leaves[1], specLabel))
                else
                    local specItem = MakeMenuItem(self, specLabel)
                    local specSub = MakeSubPullout(self)
                    for _, leaf in ipairs(leaves) do
                        specSub:AddItem(MakeLeafItem(self, leaf))
                    end
                    specItem:SetMenu(specSub)
                    classSub:AddItem(specItem)
                end
            end

            classItem:SetMenu(classSub)
            pullout:AddItem(classItem)
        end

        if #other > 0 then
            local otherItem = MakeMenuItem(self, "|cFFAAAAAAOther|r")
            local otherSub = MakeSubPullout(self)
            for _, leaf in ipairs(other) do
                otherSub:AddItem(MakeLeafItem(self, leaf))
            end
            otherItem:SetMenu(otherSub)
            pullout:AddItem(otherItem)
        end
    end

    -- AceGUI cbs
    local function OnAcquire(self)
        local pullout = AceGUI:Create("Dropdown-Pullout")
        self.pullout = pullout
        pullout.userdata.obj = self
        pullout:SetCallback("OnClose", OnPulloutClose)
        pullout:SetCallback("OnOpen", OnPulloutOpen)
        self.pullout.frame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        Fixlevels(self.pullout.frame, self.pullout.frame:GetChildren())

        self:SetHeight(44)
        self:SetWidth(200)
        self:SetLabel()
        self:SetPulloutWidth(nil)
        self.list = {}
        self.selected = nil
        self.multiselect = false
        self.pulloutDirty = true

        if reopenPending then
            reopenPending = false
            local target = self
            C_Timer.After(0, function()
                if target and target.frame and target.frame:IsVisible()
                   and target.button and not target.open then
                    Dropdown_TogglePullout(target.button)
                end
            end)
        end
    end

    local function OnRelease(self)
        if self.preserveOpenAcrossRefresh and self.open then
            reopenPending = true
        end
        self.preserveOpenAcrossRefresh = nil
        if self.open then self.pullout:Close() end
        AceGUI:Release(self.pullout)
        self.pullout = nil
        self:SetText("")
        self:SetDisabled(false)
        self.value = nil
        self.list = nil
        self.selected = nil
        self.open = nil
        self.multiselect = false
        self.frame:ClearAllPoints()
        self.frame:Hide()
    end

    local function SetDisabled(self, disabled)
        self.disabled = disabled
        if disabled then
            self.text:SetTextColor(0.5,0.5,0.5)
            self.button:Disable()
            self.button_cover:Disable()
            self.label:SetTextColor(0.5,0.5,0.5)
        else
            self.button:Enable()
            self.button_cover:Enable()
            self.label:SetTextColor(1,.82,0)
            self.text:SetTextColor(1,1,1)
        end
    end

    local function SetText(self, text) self.text:SetText(text or "") end

    local function SetLabel(self, text)
        if text and text ~= "" then
            self.label:SetText(text)
            self.label:Show()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -15, -14)
            self:SetHeight(40)
            self.alignoffset = 26
        else
            self.label:SetText("")
            self.label:Hide()
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -15, 0)
            self:SetHeight(26)
            self.alignoffset = 12
        end
    end

    local function SetValue(self, value)
        local text = (self.list and self.list[value]) or ""
        if type(value) == "string" then
            local class, sid = value:match("^([A-Z_]+):(%d+)$")
            local m = sid and ns.SpecMeta and ns.SpecMeta(tonumber(sid))
            if m then
                local icon = m.icon and ("|T" .. m.icon .. ":14:14|t ") or ""
                text = icon .. (ns.ClassColor and ns.ClassColor(class) or "") .. (m.name or text) .. "|r"
            end
        end
        self:SetText(text)
        self.value = value
    end
    local function GetValue(self) return self.value end

    local function SetItemValue(self, item, value)
        self.selected = self.selected or {}
        self.selected[item] = value and true or nil
        self.pulloutDirty = true
        ShowMultiText(self)
    end

    local function SetItemDisabled() end

    -- SetList is called every render with the same (function-returned)
    local function ListsEqual(a, b)
        if not a or not b then return false end
        local na = 0; for _ in pairs(a) do na = na + 1 end
        local nb = 0; for _ in pairs(b) do nb = nb + 1 end
        if na ~= nb then return false end
        for k, v in pairs(a) do if b[k] ~= v then return false end end
        return true
    end
    local function SetList(self, list)
        list = list or {}
        if ListsEqual(self.list, list) then return end
        self.list = list
        self.pulloutDirty = true
    end

    local function SetMultiselect(self, multi)
        local newVal = multi and true or false
        if self.multiselect == newVal then return end
        self.multiselect = newVal
        self.pulloutDirty = true
    end

    local function GetMultiselect(self) return self.multiselect end

    local function SetPulloutWidth(self, width) self.pulloutWidth = width end

    local instanceCount = 0

    -- Frame construction 
    local function Constructor()
        instanceCount = instanceCount + 1
        local frame = CreateFrame("Frame", nil, UIParent)
        local dropdown = CreateFrame("Frame", "TUI_CascadeDropdown_Inner"..instanceCount, frame, "UIDropDownMenuTemplate")

        local self = {
            type    = widgetType,
            frame   = frame,
            dropdown = dropdown,
            count   = 0,

            OnAcquire = OnAcquire,
            OnRelease = OnRelease,
            ClearFocus = function(self) if self.open then self.pullout:Close() end end,

            SetText  = SetText,
            SetValue = SetValue,
            GetValue = GetValue,
            SetList  = SetList,
            SetLabel = SetLabel,
            SetDisabled = SetDisabled,
            SetMultiselect = SetMultiselect,
            GetMultiselect = GetMultiselect,
            SetItemValue = SetItemValue,
            SetItemDisabled = SetItemDisabled,
            SetPulloutWidth = SetPulloutWidth,
        }
        frame.obj = self
        dropdown.obj = self

        self.alignoffset = 26
        frame:SetHeight(44)
        frame:SetWidth(200)
        frame:SetScript("OnHide", Dropdown_OnHide)

        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", -15, 0)
        dropdown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 17, 0)
        dropdown:EnableMouse(false)

        -- Strip native arrows that come with UIDropDownMenuTemplate
        local left = _G[dropdown:GetName() and (dropdown:GetName().."Left") or ""]
        local middle = _G[dropdown:GetName() and (dropdown:GetName().."Middle") or ""]
        local right = _G[dropdown:GetName() and (dropdown:GetName().."Right") or ""]
        if left then left:SetTexture(nil) end
        if middle then middle:SetTexture(nil) end
        if right then right:SetTexture(nil) end

        local text = _G[dropdown:GetName() and (dropdown:GetName().."Text") or ""] or dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.text = text
        text:ClearAllPoints()
        text:SetPoint("RIGHT", dropdown, "RIGHT", -43, 2)
        text:SetPoint("LEFT", dropdown, "LEFT", 25, 2)
        text:SetJustifyH("RIGHT")

        local button = _G[dropdown:GetName() and (dropdown:GetName().."Button") or ""] or CreateFrame("Button", nil, dropdown)
        self.button = button
        button.obj = self
        button:SetScript("OnEnter", Control_OnEnter)
        button:SetScript("OnLeave", Control_OnLeave)
        button:SetScript("OnClick", Dropdown_TogglePullout)

        local button_cover = CreateFrame("Button", nil, frame)
        self.button_cover = button_cover
        button_cover.obj = self
        button_cover:SetAllPoints()
        button_cover:SetScript("OnEnter", Control_OnEnter)
        button_cover:SetScript("OnLeave", Control_OnLeave)
        button_cover:SetScript("OnClick", Dropdown_TogglePullout)

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.label = label
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetHeight(18)

        AceGUI:RegisterAsWidget(self)

        local Skins = ElvUI and ElvUI[1] and ElvUI[1].Skins
        if Skins and Skins.Ace3_RegisterAsWidget then
            local realType = self.type
            self.type = "Dropdown-ElvUI"
            pcall(Skins.Ace3_RegisterAsWidget, Skins, self)
            self.type = realType
        end

        return self
    end

    AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)
end


-- Helpers
ns.CascadeDropdown = ns.CascadeDropdown or {}
function ns.CascadeDropdown.AllSpecs()
    local out = {}
    for _, r in ipairs(ns.AllSpecs()) do
        if r.name then out[r.classToken .. ":" .. r.id] = r.name end
    end
    return out
end
