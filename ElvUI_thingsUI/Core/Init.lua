local _, ns = ...
local TUI = ns.TUI
local E = ns.E
local EP = ns.EP
local addon = ns.addon

-- On entering world: prime CDM + scan, but if we load in combat, wait until combat ends
local function PrimeAndScanCDM()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    if InCombatLockdown() then
        -- retry once we're out of combat
        if not TUI.__cdmRegenHooked then
            TUI.__cdmRegenHooked = true
            TUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                TUI:UnregisterEvent("PLAYER_REGEN_ENABLED")
                TUI.__cdmRegenHooked = nil
                C_Timer.After(0.1, PrimeAndScanCDM)
            end)
        end
        return
    end

    local f = _G.CooldownViewerSettings
    if f then
        -- show 1 tick, hide, then scan (forces Blizzard to build tracked bars)
        f:Show()
        C_Timer.After(0, function()
            f:Hide()

            if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
                ns.SpecialBars.ScanAndHookCDMChildren()
            end

            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
        end)
    else
        -- no settings frame found, still try scan
        if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
            ns.SpecialBars.ScanAndHookCDMChildren()
        end
        if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, PrimeAndScanCDM)
end)


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
            PrimeAndScanCDM()
            
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
            PrimeAndScanCDM()
            TUI:UpdateSpecialBars()
            TUI:UpdateBuffBars()
        end)
    end)
    
    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded - Config in /elvui -> thingsUI")
end

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
