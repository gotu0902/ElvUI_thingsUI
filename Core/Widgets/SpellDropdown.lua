local _, ns = ...

-- AceGUI's Dropdown with the spell's tooltip on each entry whose key is a spell ID
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local TYPE, VERSION = "TUI_SpellDropdown", 1

-- "12345", 12345 or "spell:12345"; collections, tokens and "" aren't spells
local function SpellOf(value)
    local s = tostring(value or "")
    local id = tonumber(s) or tonumber(s:match("^[%a_]+:(%d+)$"))
    if id and C_Spell.GetSpellName and C_Spell.GetSpellName(id) then return id end
end

local function ItemEnter(item)
    local id = SpellOf(item.userdata and item.userdata.value)
    if not id then return end
    -- beside the whole list (its scroll bar sits right of the entry), level with the entry
    local list = item.pullout and item.pullout.frame
    local dx = (list and list:GetRight() and item.frame:GetRight()) and (list:GetRight() - item.frame:GetRight()) or 0
    GameTooltip:SetOwner(item.frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", item.frame, "TOPRIGHT", dx + 6, 0)
    GameTooltip:SetSpellByID(id)
    GameTooltip:Show()
end

local function ItemLeave() GameTooltip:Hide() end

local function Constructor()
    local widget = AceGUI.WidgetRegistry["Dropdown"]()
    widget.type = TYPE
    local SetList = widget.SetList
    widget.SetList = function(self, list, order, itemType)
        SetList(self, list, order, itemType)
        for _, item in ipairs((self.pullout and self.pullout.items) or {}) do
            if item.userdata and item.userdata.value ~= nil then
                item:SetCallback("OnEnter", ItemEnter)
                item:SetCallback("OnLeave", ItemLeave)
            end
        end
    end
    return widget
end

AceGUI:RegisterWidgetType(TYPE, Constructor, VERSION)
ns.SPELL_DROPDOWN = TYPE
