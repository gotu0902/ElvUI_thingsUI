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

-- Re-anchors Details windows to rcp using their actual baseframes, then calls
-- SaveLibWindow so Details' own restore system preserves the new position.
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

-- Full apply: resizes rcp to fit both Details windows, then re-anchors them.
function TUI:ApplyDetailsRightChatAnchor()
    local rcp = _G["RightChatPanel"]
    if not rcp or not _G["Details"] then return end
    local inst1 = Details:GetInstance(1)
    local inst2 = Details:GetInstance(2)

    local LO = E:GetModule("Layout")
    local CH = E:GetModule("Chat")

    -- Enable right panel backdrop without clobbering the left side
    local current = E.db["chat"]["panelBackdrop"] or "HIDEBOTH"
    if current == "HIDEBOTH" then
        E.db["chat"]["panelBackdrop"] = "RIGHT"
    elseif current == "LEFT" then
        E.db["chat"]["panelBackdrop"] = "SHOWBOTH"
    end

    -- baseframe:GetHeight() already includes the title bar
    local w1 = (inst1 and inst1.baseframe and inst1.baseframe:GetWidth()  > 10) and inst1.baseframe:GetWidth()  or 214
    local w2 = (inst2 and inst2.baseframe and inst2.baseframe:GetWidth()  > 10) and inst2.baseframe:GetWidth()  or 209
    local h  = (inst1 and inst1.baseframe and inst1.baseframe:GetHeight() > 10) and inst1.baseframe:GetHeight() or 201
    local gap = 4  -- visual border is ~1px outside baseframe on each side; inset anchors by 1, gap compensates
    local wOff = (E.db.thingsUI and E.db.thingsUI.rightChatWidthOffset)  or 0
    local hOff = (E.db.thingsUI and E.db.thingsUI.rightChatHeightOffset) or 0
    local panelW = math.floor(w1 + w2 + gap + wOff)
    local panelH = math.floor(h + 19 + hOff)  -- 17 for title bar + 2 for 1px per side
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

    -- Anchor Details to rcp and save so their restore system uses our position
    TUI:ReanchorDetailsRightChat()
end

function TUI:Initialize()
    EP:RegisterPlugin(addon, TUI.ConfigTable)

    -- BCDM profile-change debug prints.  Set to false once the integration works
    -- reliably (or do it at runtime: /run ElvUI[1]:GetModule("thingsUI").__bcdmDebug=false)
    if self.__bcdmDebug == nil then self.__bcdmDebug = false end

    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)

    -- Hook ToggleChatPanels so our panel size survives any ElvUI layout call
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

    -- Hook UpdateMoverPositions so Details re-anchors whenever the Right Chat mover is moved.
    hooksecurefunc(E, "UpdateMoverPositions", function()
        if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
            C_Timer.After(0.1, function()
                if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                    TUI:ReanchorDetailsRightChat()
                end
            end)
        end
    end)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    self:UpdateDynamicCastBarAnchor()
    self:UpdateTrinketsCDM()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(2, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()
            if ns.MarkBuffBarsDirty then ns.MarkBuffBarsDirty() end
            if E.db.thingsUI and E.db.thingsUI.autoSetAudioChannels then
                SetCVar("Sound_NumChannels", 32)
            end
            -- delays until it succeeds (or gives up after ~10s).
            if TUI.__RegisterBCDMProfileCallback and not TUI.__bcdmCallbackRegistered then
                local delays = {0, 1, 3, 6, 10}
                for _, d in ipairs(delays) do
                    C_Timer.After(d, function()
                        if not TUI.__bcdmCallbackRegistered then
                            TUI.__RegisterBCDMProfileCallback()
                        end
                    end)
                end
            end

            if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                TUI:ReanchorDetailsRightChat()  -- instant anchor so windows don't float
                C_Timer.After(3, function()     -- then do full size+anchor once everything is settled
                    if E.db.thingsUI and E.db.thingsUI.rightChatAsBackground then
                        TUI:ApplyDetailsRightChatAnchor()
                    end
                end)
            end

            local trinketFrame = _G["BCDM_TrinketBar"]
            if trinketFrame and not trinketFrame._TUI_hooked then
                trinketFrame._TUI_hooked = true
                hooksecurefunc(trinketFrame, "SetPoint", function()
                    if ns.TrinketsCDM and ns.TrinketsCDM._suppressHook then return end
                    if not (E.db.thingsUI and E.db.thingsUI.trinketsCDM and E.db.thingsUI.trinketsCDM.enabled) then return end
                    if ns.TrinketsCDM.QueueUpdate then ns.TrinketsCDM.QueueUpdate() end
                end)

                for i = 1, trinketFrame:GetNumChildren() do
                    local child = select(i, trinketFrame:GetChildren())
                    if child then
                        child:HookScript("OnShow", function()
                            if ns.TrinketsCDM and ns.TrinketsCDM.QueueUpdate then ns.TrinketsCDM.QueueUpdate() end
                        end)
                        child:HookScript("OnHide", function()
                            if ns.TrinketsCDM and ns.TrinketsCDM.QueueUpdate then ns.TrinketsCDM.QueueUpdate() end
                        end)
                    end
                end
            end

            local essFrame = _G["EssentialCooldownViewer"]
            if essFrame and not essFrame._TUI_essHooked then
                essFrame._TUI_essHooked = true
                hooksecurefunc(essFrame, "SetPoint", function()
                    if ns.TrinketsCDM and ns.TrinketsCDM._suppressEssHook then return end
                    if not (E.db.thingsUI and E.db.thingsUI.trinketsCDM and E.db.thingsUI.trinketsCDM.enabled) then return end
                    if ns.TrinketsCDM.ResetEssentialSavedPoint then ns.TrinketsCDM.ResetEssentialSavedPoint() end
                    if ns.TrinketsCDM.QueueUpdate then ns.TrinketsCDM.QueueUpdate() end
                end)

                local _origGetWidth = essFrame.GetWidth
                essFrame.GetWidth = function(self)
                    local baseWidth = _origGetWidth(self)
                    if ns.TrinketsCDM and ns.TrinketsCDM.GetNHTAnchor and ns.TrinketsCDM.GetNHTAnchor() then
                        local tf = _G["BCDM_TrinketBar"]
                        if tf and tf:IsShown() then
                            local tw = tf:GetWidth()
                            if tw and tw > 1 then return baseWidth + tw end
                        end
                    end
                    return baseWidth
                end
            end
            -- Hook dependent bars so centering shift fckn works
            local depBars = { "UtilityCooldownViewer", "BuffIconCooldownViewer", "BCDM_PowerBar", "BCDM_SecondaryPowerBar", "BCDM_CastBar" }
            for _, barName in ipairs(depBars) do
                local f = _G[barName]
                if f and not f._TUI_depHooked then
                    f._TUI_depHooked = true
                    local capturedName = barName 
                    hooksecurefunc(f, "SetPoint", function()
                        if ns.TrinketsCDM and ns.TrinketsCDM._suppressDepHook then return end
                        if not (E.db.thingsUI and E.db.thingsUI.trinketsCDM and E.db.thingsUI.trinketsCDM.enabled) then return end
                        if ns.TrinketsCDM.ResetDepShift then ns.TrinketsCDM.ResetDepShift(capturedName) end
                        if ns.TrinketsCDM.QueueUpdate then ns.TrinketsCDM.QueueUpdate() end
                    end)
                    -- For bars that show/hide (CastBar), re-apply combined
                    if barName == "BCDM_CastBar" or barName == "BCDM_PowerBar" or barName == "BCDM_SecondaryPowerBar" then
                        f:HookScript("OnShow", function(self)
                            if not (ns.TrinketsCDM and ns.TrinketsCDM.GetNHTAnchor and ns.TrinketsCDM.GetNHTAnchor()) then return end
                            C_Timer.After(0, function()
                                if ns.TrinketsCDM and ns.TrinketsCDM.ApplyMatchWidth then
                                    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
                                    local gap = db and db.gap or 1
                                    local ev = _G["EssentialCooldownViewer"]
                                    local essW = ev and ev:GetWidth()
                                    if essW and essW > 1 then
                                        ns.TrinketsCDM.ApplyMatchWidth(essW + gap)
                                    else
                                        ns.TrinketsCDM.ApplyMatchWidth()
                                    end
                                end
                            end)
                        end)
                    end
                end
            end

            local utilFrame = _G["UtilityCooldownViewer"]
            if utilFrame and not utilFrame._TUI_widthOverride then
                utilFrame._TUI_widthOverride = true
                local _origUtilGetWidth = utilFrame.GetWidth
                utilFrame.GetWidth = function(self)
                    local baseWidth = _origUtilGetWidth(self)
                    if ns.TrinketsCDM and ns.TrinketsCDM.GetNHTAnchor and ns.TrinketsCDM.GetNHTAnchor() then
                        local tf = _G["BCDM_TrinketBar"]
                        if tf and tf:IsShown() then
                            local tw = tf:GetWidth()
                            if tw and tw > 1 then return baseWidth + tw end
                        end
                    end
                    return baseWidth
                end
            end
            TUI:UpdateTrinketsCDM()
    
            if TUI._SetupBCDMBarHooks then TUI._SetupBCDMBarHooks() end
        end)
    end)

    -- Enforce BCDM bar visibility after profile changes.
    local function SetupBCDMBarHooks()
        local pb = _G["BCDM_PowerBar"]
        if pb and not pb._TUI_showHooked then
            pb._TUI_showHooked = true
            hooksecurefunc(pb, "Show", function(self)
                if TUI.__bcdmSuppressPB then
                    self:Hide()
                end
            end)
        end
        local sb = _G["BCDM_SecondaryPowerBar"]
        if sb and not sb._TUI_showHooked then
            sb._TUI_showHooked = true
            hooksecurefunc(sb, "Show", function(self)
                if TUI.__bcdmSuppressSB then
                    self:Hide()
                end
            end)
        end
    end
    TUI._SetupBCDMBarHooks = SetupBCDMBarHooks

    local function ForceReapplyBCDMProfile(db, reason)
        if not db or not db.profile then return end
        local currentProfile = db:GetCurrentProfile()
        local p = db.profile
        local pbDisabled = not p.PowerBar or not p.PowerBar.Enabled
        local sbDisabled = not p.SecondaryPowerBar or not p.SecondaryPowerBar.Enabled

        if TUI.__bcdmDebug then
            print(string.format("|cFF8080FFTUI|r: ForceReapplyBCDMProfile (%s) profile=%s PB.disabled=%s SB.disabled=%s",
                tostring(reason or "?"), tostring(currentProfile),
                tostring(pbDisabled), tostring(sbDisabled)))
        end

        -- Only suppress bars that are DISABLED in the profile.
        -- When bars are enabled, leave them alone — BCDM handles Swap logic,
        -- positioning, etc. internally.  We only need to enforce "disabled = hidden".
        TUI.__bcdmSuppressPB = pbDisabled
        TUI.__bcdmSuppressSB = sbDisabled

        SetupBCDMBarHooks()

        local pb = _G["BCDM_PowerBar"]
        if pb then
            if pbDisabled then pb:Hide() else pb:Show() end
        end
        local sb = _G["BCDM_SecondaryPowerBar"]
        if sb then
            if sbDisabled then sb:Hide() else sb:Show() end
        end
    end

    local function ResolveBCDMDB()
        local AceDB = LibStub("AceDB-3.0", true)
        if not AceDB or not AceDB.db_registry then return nil end
        for db in pairs(AceDB.db_registry) do
            if type(db) == "table" and type(db.RegisterCallback) == "function"
               and type(db.profile) == "table"
               and type(db.profile.PowerBar)          == "table"
               and type(db.profile.SecondaryPowerBar) == "table"
               and type(db.profile.CastBar)           == "table"
               and type(db.profile.CooldownManager)   == "table"
               and type(db.profile.CooldownManager.Essential) == "table"
               and db.profile.CooldownManager.Enable ~= nil then
                return db
            end
        end
        return nil
    end

    local function RegisterBCDMProfileCallback()
        if TUI.__bcdmCallbackRegistered then return true end
        local db = ResolveBCDMDB()
        if not db then
            if TUI.__bcdmDebug then
                local AceDB = LibStub("AceDB-3.0", true)
                local regCount = 0
                if AceDB and AceDB.db_registry then
                    for _ in pairs(AceDB.db_registry) do regCount = regCount + 1 end
                end
                print(string.format("|cFF8080FFTUI|r: cannot find BCDM db yet (AceDB=%s, dbs_in_registry=%d)",
                    tostring(AceDB ~= nil), regCount))
            end
            return false
        end
        db.RegisterCallback(TUI, "OnProfileChanged", function()
            if TUI.__bcdmDebug then print("|cFF8080FFTUI|r: OnProfileChanged fired") end
            TUI.__bcdmProfileLastChanged = GetTime()

            ForceReapplyBCDMProfile(db, "OnProfileChanged")
        end)
        TUI.__bcdmCallbackRegistered = true
        TUI.__bcdmDB = db
        if TUI.__bcdmDebug then
            local dsEnabled = "n/a"
            if db.IsDualSpecEnabled then
                local ok, res = pcall(db.IsDualSpecEnabled, db)
                if ok then dsEnabled = tostring(res) end
            end
            print(string.format("|cFF8080FFTUI|r: registered OnProfileChanged (profile=%s, LibDualSpec=%s)",
                tostring(db:GetCurrentProfile() or "?"), dsEnabled))
        end
        return true
    end
    TUI.__RegisterBCDMProfileCallback = RegisterBCDMProfileCallback

    RegisterBCDMProfileCallback()

    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit ~= "player" then return end

        local markedAt = GetTime()
        local profileBefore = TUI.__bcdmDB and TUI.__bcdmDB:GetCurrentProfile()
        C_Timer.After(3, function()
            local last = TUI.__bcdmProfileLastChanged or 0
            if last < markedAt then
                local db = TUI.__bcdmDB
                if not db then return end
                local profileNow = db:GetCurrentProfile()
                if profileBefore and profileNow == profileBefore then
                    if TUI.__bcdmDebug then
                        print(string.format("|cFF8080FFTUI|r: spec-change fallback skipped (profile unchanged: %s)", tostring(profileNow)))
                    end
                    return
                end
                ForceReapplyBCDMProfile(db, "spec-change fallback")
                if TUI.__bcdmDebug and db.IsDualSpecEnabled then
                    local ok, res = pcall(db.IsDualSpecEnabled, db)
                    if ok and not res then
                        print("|cFF8080FFTUI|r: heads-up — LibDualSpec profiles are OFF for BCDM; toggle 'Enable spec profiles' under /BCDM -> Profiles for auto-swap on spec change.")
                    end
                end
            end
        end)

        -- Plugin's own deferred work: scan CDM children, refresh our skins/positions.
        C_Timer.After(1.5, function()
            wipe(ns.skinnedBars)
            wipe(ns.yoinkedBars)
            PrimeAndScanCDM()
            TUI:UpdateBuffBars()
            TUI:UpdateClusterPositioning()
            TUI:UpdateDynamicCastBarAnchor()
        end)
    end)

    print("|cFF8080FFElvUI_thingsUI|r v" .. self.version .. " loaded")
end

function TUI:ProfileUpdate()
    wipe(ns.skinnedBars)
    wipe(ns.yoinkedBars)
    self:UpdateVerticalBuffs()
    self:UpdateBuffBars()
    self:UpdateSpecialBars()
    self:UpdateClusterPositioning()
    self:UpdateDynamicCastBarAnchor()
    self:UpdateTrinketsCDM()
end

hooksecurefunc(E, "UpdateAll", function() TUI:ProfileUpdate() end)

E:RegisterModule(TUI:GetName())