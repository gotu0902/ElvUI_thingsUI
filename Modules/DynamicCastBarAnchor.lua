local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local updateFrame = CreateFrame("Frame")
local isDirty = false
local isEnabled = false
local hookedSecondary = false
local lastAnchorTarget = nil
local hookedCDMSettings = false

local function GetCastBar()
    return _G["BCDM_CastBar"]
end

local function GetPowerBar()
    return _G["BCDM_PowerBar"]
end

local function GetSecondaryPowerBar()
    return _G["BCDM_SecondaryPowerBar"]
end

local function UpdateCastBarAnchor()
    if not isEnabled then return end
    
    local db = E.db.thingsUI.dynamicCastBarAnchor
    if not db or not db.enabled then return end
    
    local castBar = GetCastBar()
    if not castBar then return end
    
    local secondary = GetSecondaryPowerBar()
    local primary = GetPowerBar()
    
    local anchorTarget
    if secondary and secondary:IsShown() and secondary:GetWidth() > 0 then
        anchorTarget = secondary
    elseif primary and primary:IsShown() then
        anchorTarget = primary
    else
        return 
    end
    
    if anchorTarget == lastAnchorTarget then return end
    lastAnchorTarget = anchorTarget
    
    pcall(function()
        castBar:ClearAllPoints()
        castBar:SetPoint(
            db.point or "TOP",
            anchorTarget,
            db.relativePoint or "BOTTOM",
            db.xOffset or 0,
            db.yOffset or 0
        )
    end)
end

local function OnNextFrame(self) -- One-shot timer that costs zero CPU when nothing happens, cancels itself out /D.G
    self:SetScript("OnUpdate", nil)
    isDirty = false
    UpdateCastBarAnchor()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end

local function HookCDMSettings()
    if hookedCDMSettings then return end
    local settings = _G["CooldownViewerSettings"]
    if not settings then return end
    
    hookedCDMSettings = true
    pcall(function()
        settings:HookScript("OnShow", function()
            -- CDM opening can re-anchor things, re-apply after it settles
            C_Timer.After(0.1, function()
                lastAnchorTarget = nil
                MarkDirty()
            end)
        end)
        settings:HookScript("OnHide", function()
            -- CDM closing — BCDM re-applies its anchors, override again
            C_Timer.After(0.1, function()
                lastAnchorTarget = nil
                MarkDirty()
            end)
        end)
    end)
end

local function HookSecondaryPowerBar()
    if hookedSecondary then return end
    local secondary = GetSecondaryPowerBar()
    if not secondary then return end
    
    hookedSecondary = true
    pcall(function()
        secondary:HookScript("OnShow", function()
            lastAnchorTarget = nil
            MarkDirty()
        end)
        secondary:HookScript("OnHide", function()
            lastAnchorTarget = nil
            MarkDirty()
        end)
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            HookSecondaryPowerBar()
            HookCDMSettings()
            lastAnchorTarget = nil
            MarkDirty()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        HookSecondaryPowerBar()
        lastAnchorTarget = nil
        MarkDirty()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        hookedSecondary = false
        lastAnchorTarget = nil
        C_Timer.After(0.5, function()
            HookSecondaryPowerBar()
            MarkDirty()
        end)
    end
end)

function TUI:UpdateDynamicCastBarAnchor()
    local db = E.db.thingsUI.dynamicCastBarAnchor
    if db and db.enabled then
        isEnabled = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        
        HookSecondaryPowerBar()
        HookCDMSettings()
        lastAnchorTarget = nil
        MarkDirty()
    else
        isEnabled = false
        isDirty = false
        lastAnchorTarget = nil
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
    end
end
