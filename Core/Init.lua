local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local EP  = ns.EP
local addon = ns.addon

local function PrimeAndScanCDM()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    if InCombatLockdown() then
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

    if ns.SpecialBars and ns.SpecialBars.ScanAndHookCDMChildren then
        ns.SpecialBars.ScanAndHookCDMChildren()
    end

    if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, PrimeAndScanCDM)
end)

function TUI:ReanchorDetailsRightChat()
    local rcp = _G["RightChatPanel"]
    if not rcp or not _G["Details"] then return end
    local inst1 = Details:GetInstance(1)
    local inst2 = Details:GetInstance(2)
    if inst1 and inst1.baseframe then
        inst1.baseframe:ClearAllPoints()
        inst1.baseframe:SetPoint("BOTTOMRIGHT", rcp, "BOTTOMRIGHT", -1, 0)
        inst1:SaveLibWindow()
    end
    if inst2 and inst2.baseframe then
        inst2.baseframe:ClearAllPoints()
        inst2.baseframe:SetPoint("BOTTOMLEFT", rcp, "BOTTOMLEFT", 1, 0)
        inst2:SaveLibWindow()
    end
end

function TUI:ApplyDetailsRightChatAnchor()
    local rcp = _G["RightChatPanel"]
    if not rcp or not _G["Details"] then return end
    local inst1 = Details:GetInstance(1)
    local inst2 = Details:GetInstance(2)

    local LO = E:GetModule("Layout")
    local CH = E:GetModule("Chat")

    local current = E.db["chat"]["panelBackdrop"] or "HIDEBOTH"
    if current == "HIDEBOTH" then
        E.db["chat"]["panelBackdrop"] = "RIGHT"
    elseif current == "LEFT" then
        E.db["chat"]["panelBackdrop"] = "SHOWBOTH"
    end

    local w1 = (inst1 and inst1.baseframe and inst1.baseframe:GetWidth()  > 10) and inst1.baseframe:GetWidth()  or 214
    local w2 = (inst2 and inst2.baseframe and inst2.baseframe:GetWidth()  > 10) and inst2.baseframe:GetWidth()  or 209
    local h  = (inst1 and inst1.baseframe and inst1.baseframe:GetHeight() > 10) and inst1.baseframe:GetHeight() or 201
    local gap = 4 
    local wOff = (E.db.thingsUI and E.db.thingsUI.rightChatWidthOffset)  or 0
    local hOff = (E.db.thingsUI and E.db.thingsUI.rightChatHeightOffset) or 0
    local panelW = math.floor(w1 + w2 + gap + wOff)
    local panelH = math.floor(h + 19 + hOff)
    E.db["chat"]["separateSizes"]    = true
    E.db["chat"]["panelWidthRight"]  = panelW
    E.db["chat"]["panelHeightRight"] = panelH

    if LO and LO.ToggleChatPanels then LO:ToggleChatPanels() end
    if CH then
        if CH.PositionChats then CH:PositionChats() end
        if CH.UpdateEditboxAnchors then CH:UpdateEditboxAnchors() end
    end
    E:UpdateMoverPositions()

    rcp:SetWidth(panelW)
    rcp:SetHeight(panelH)
    TUI:ReanchorDetailsRightChat()
end

function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)

    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    local LO = E:GetModule("Layout")
    if LO and LO.ToggleChatPanels then
        hooksecurefunc(LO, "ToggleChatPanels", function()
            if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                local rcp = _G["RightChatPanel"]
                local pw = E.db["chat"]["panelWidthRight"]
                local ph = E.db["chat"]["panelHeightRight"]
                if rcp and pw and pw > 10 and ph and ph > 10 then
                    C_Timer.After(0, function()
                        rcp:SetWidth(pw)
                        rcp:SetHeight(ph)
                    end)
                end
            end
        end)
    end

    hooksecurefunc(E, "UpdateMoverPositions", function()
        if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
            C_Timer.After(0.1, function()
                if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                    TUI:ReanchorDetailsRightChat()
                end
            end)
        end
    end)
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    self:UpdateBarSetup()
    self:UpdateClassbarMode()
    self:UpdateChargeBar()
    self:UpdateTrinketsCDM()
    self:UpdateEditModeLock()
    self:UpdateCDMIcons()
    self:UpdateCDMText()
    if self.UpdateRacialsCDM then self:UpdateRacialsCDM() end
    self:UpdateEssentialMover()
    self:UpdateCustomGroups()
    self:UpdateMoverSync()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(2, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()
            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            if E.db.thingsUI and E.db.thingsUI.autoSetAudioChannels then
                SetCVar("Sound_NumChannels", 32)
            end
            if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                TUI:ReanchorDetailsRightChat()
                C_Timer.After(3, function()
                    if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                        TUI:ApplyDetailsRightChatAnchor()
                    end
                end)
            end
            
            TUI:UpdateTrinketsCDM()
        end)
    end)

    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        C_Timer.After(1.5, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()
            TUI:UpdateBuffBars()
            TUI:UpdateCDMText()
            TUI:UpdateClusterPositioning()
            if ns.BarSetup and ns.BarSetup.ResetWidthCache then ns.BarSetup.ResetWidthCache() end
            TUI:UpdateBarSetup()
            TUI:UpdateClassbarMode()
            TUI:UpdateChargeBar()
            TUI:UpdateCustomGroups()
        end)
    end)

    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded")
end

function TUI:ProfileUpdate()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    if ns.BarSetup and ns.BarSetup.ResetWidthCache then ns.BarSetup.ResetWidthCache() end
    self:UpdateBarSetup()
    self:UpdateClassbarMode()
    self:UpdateChargeBar()
    self:UpdateTrinketsCDM()
    self:UpdateEditModeLock()
    self:UpdateCDMIcons()
    self:UpdateCDMText()
    if self.UpdateRacialsCDM then self:UpdateRacialsCDM() end
    self:UpdateEssentialMover()
    self:UpdateCustomGroups()
    if ns.CustomGroups and ns.CustomGroups._rebuildOptions then ns.CustomGroups._rebuildOptions() end
    if ns.BarSetup and ns.BarSetup._rebuildSetupOptions then ns.BarSetup._rebuildSetupOptions() end
    if ns.Timers then
        if ns.Timers.EnsureLustTimer then ns.Timers.EnsureLustTimer() end
        if ns.Timers.Update then ns.Timers.Update() end
    end
    self:UpdateMoverSync()
end

hooksecurefunc(E, "UpdateAll", function() TUI:ProfileUpdate() end)

E:RegisterModule(TUI:GetName())