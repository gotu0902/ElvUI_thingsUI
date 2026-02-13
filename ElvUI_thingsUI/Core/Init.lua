local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local EP = ns.EP
local addon = ns.addon

-------------------------------------------------
-- MODULE INITIALIZATION
-------------------------------------------------
function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)
    
    -- Clean slate
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    -- Initialize all modules — each registers its own events
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    
    -- On entering world, give CDM time to create its frames then refresh
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(2, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            
            if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
                ns.SpecialBars.ScanAndHookCDMChildren()
            end
            
            -- Mark dirty instead of full reinit — events handle the rest
            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
        end)
    end)
    
    -- Spec change: clean slate + reinit special bars
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        C_Timer.After(0.5, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            TUI:UpdateSpecialBars()
            TUI:UpdateBuffBars()
        end)
    end)
    
    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded - Config in /elvui -> thingsUI")
end

-------------------------------------------------
-- PROFILE HOOKS
-------------------------------------------------
function TUI:ProfileUpdate()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
end

local function OnProfileChanged()
    TUI:ProfileUpdate()
end

hooksecurefunc(E, "UpdateAll", OnProfileChanged)

E:RegisterModule(TUI:GetName())
