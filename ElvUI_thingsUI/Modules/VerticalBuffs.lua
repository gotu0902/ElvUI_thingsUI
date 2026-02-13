local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

-- =========================================
-- EVENT-DRIVEN VERTICAL BUFF POSITIONING
-- Uses dirty-flag: event → mark dirty → process next frame → stop
-- =========================================
local updateFrame = CreateFrame("Frame")
local eventFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local reusableIconTable = {}

local function PositionBuffsVertically()
    if not BuffIconCooldownViewer then return end
    if not E.db.thingsUI or not E.db.thingsUI.verticalBuffs then return end
    
    wipe(reusableIconTable)

    local children = { BuffIconCooldownViewer:GetChildren() }
    for _, childFrame in ipairs(children) do
        if childFrame and childFrame.Icon and childFrame:IsShown() then
            reusableIconTable[#reusableIconTable + 1] = childFrame
        end
    end

    if #reusableIconTable == 0 then return end

    table.sort(reusableIconTable, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    local iconSize = reusableIconTable[1]:GetWidth()
    local iconSpacing = BuffIconCooldownViewer.childYPadding or 0
    
    for index, iconFrame in ipairs(reusableIconTable) do
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("TOP", BuffIconCooldownViewer, "TOP", 0, -((index - 1) * (iconSize + iconSpacing)))
    end
end

local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    PositionBuffsVertically()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_AURA" then
        MarkDirty()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, MarkDirty)
    elseif event == "PLAYER_REGEN_ENABLED" then
        MarkDirty()
    end
end)

function TUI:UpdateVerticalBuffs()
    if E.db.thingsUI.verticalBuffs then
        isEnabled = true
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        MarkDirty()
    else
        isEnabled = false
        isDirty = false
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
    end
end
