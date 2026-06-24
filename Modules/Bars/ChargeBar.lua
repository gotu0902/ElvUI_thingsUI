local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local CB = {}
ns.ChargeBar = CB

local frame
local barFrame
local chargeBar
local rechargeBar
local rechargeText
local ticksContainer
local tickPool = {}
local activeTickCount = 0

local updateFrame = CreateFrame("Frame")
local eventFrame  = CreateFrame("Frame")

local HookCluster = function() end

local isDirty   = false
local isEnabled = false
local playerEntered = (IsLoggedIn and IsLoggedIn()) or false
local currentSpellID
local currentMaxCharges = 0

local lastLayoutW, lastLayoutH, lastLayoutN
local lastLayoutShowTicks, lastLayoutTickW, lastLayoutTickR, lastLayoutTickG, lastLayoutTickB, lastLayoutTickA
local lastVisualSpellID, lastVisualR, lastVisualG, lastVisualB
local lastVisualRR, lastVisualRG, lastVisualRB, lastVisualRA
local lastVisualBgR, lastVisualBgG, lastVisualBgB, lastVisualBgA
local lastVisualBdR, lastVisualBdG, lastVisualBdB, lastVisualBdA
local lastVisualShowText, lastVisualFont, lastVisualSize, lastVisualOutline

local lastAppliedHeight
local lastFhtW, lastFhtH, lastFhtTarget, lastFhtPoint, lastFhtRel, lastFhtXOff, lastFhtYOff

local function InvalidateLayoutCache()
    lastLayoutW, lastLayoutH, lastLayoutN = nil, nil, nil
    lastLayoutShowTicks = nil
    lastVisualSpellID = nil
    lastAppliedHeight = nil
    lastFhtW, lastFhtH, lastFhtTarget = nil, nil, nil
    lastFhtPoint, lastFhtRel, lastFhtXOff, lastFhtYOff = nil, nil, nil, nil
end
CB._InvalidateLayoutCache = InvalidateLayoutCache

local function GetCurrentSpecID()
    local idx = GetSpecialization and GetSpecialization() or nil
    return idx and select(1, GetSpecializationInfo(idx)) or 0
end

local function GetSpecEntry()
    local db = E.db.thingsUI.chargeBar
    if not db or not db.enabled or not db.specs then return nil end
    local id = GetCurrentSpecID()
    if id == 0 then return nil end
    return db.specs[tostring(id)]
end

local function IsFHT()
    if E.db.thingsUI.barSetup and E.db.thingsUI.barSetup.enabled == false then return true end
    local bs = ns.BarSetup
    if not bs or not bs.GetActiveSetup then return false end
    local setup = bs.GetActiveSetup()
    local b = setup and setup.bars and setup.bars.chargebar
    return not (b and b.enabled)
end

function CB.GetActiveSlot()
    if IsFHT() then return nil end
    local entry = GetSpecEntry()
    if not entry then return nil end
    return entry.slot or "SECONDARY"
end

function CB.GetActiveAnchorFrame()
    if not isEnabled or not frame or not frame:IsShown() then return nil end
    if IsFHT() then return nil end
    if not CB.GetActiveSlot() then return nil end
    return frame
end

function CB.IsNHTForCurrentSpec()
    if not CB.IsActiveForCurrentSpec() then return false end
    return not IsFHT()
end

function CB.GetConfiguredMode()
    return IsFHT() and "FHT" or "NHT"
end

function CB.IsActiveForCurrentSpec()
    if not isEnabled then return false end
    local entry = GetSpecEntry()
    if not entry then return false end
    return entry.spellID ~= nil and entry.spellID ~= ""
end

function CB.GetInactiveReason()
    if not isEnabled then return "Charge Bar disabled" end
    local entry = GetSpecEntry()
    if not entry then return "inactive on this spec" end
    if entry.spellID == nil or entry.spellID == "" then return "no spell ID" end
    return nil
end

local function ApplyStrata()
    if not frame then return end
    local s = (E.db.thingsUI.chargeBar and E.db.thingsUI.chargeBar.frameStrata) or "LOW"
    frame:SetFrameStrata(s)
end

local function EnsureFrame()
    if frame then return end

    frame = CreateFrame("Frame", "ElvUI_thingsUI_ChargeBar", E.UIParent, "BackdropTemplate")
    ApplyStrata()
    frame:Hide()

    local px = ns.Pixel.Size(frame)

    frame.tuiBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.tuiBg:SetAllPoints(frame)
    frame.tuiBg:SetColorTexture(0, 0, 0, 0.7)
    frame.tuiBorder = {}

    local function mkEdge() return frame:CreateTexture(nil, "BORDER") end

    frame.tuiBorder.top    = mkEdge()
    frame.tuiBorder.bottom = mkEdge()
    frame.tuiBorder.left   = mkEdge()
    frame.tuiBorder.right  = mkEdge()
    frame.tuiBorder.top:SetPoint("TOPLEFT",    frame, "TOPLEFT",     0,  0)
    frame.tuiBorder.top:SetPoint("TOPRIGHT",   frame, "TOPRIGHT",    0,  0)
    frame.tuiBorder.top:SetHeight(px)
    frame.tuiBorder.bottom:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0, 0)
    frame.tuiBorder.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.tuiBorder.bottom:SetHeight(px)
    frame.tuiBorder.left:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, 0)
    frame.tuiBorder.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.tuiBorder.left:SetWidth(px)
    frame.tuiBorder.right:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0, 0)
    frame.tuiBorder.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.tuiBorder.right:SetWidth(px)
    for _, t in pairs(frame.tuiBorder) do t:SetColorTexture(0, 0, 0, 1) end

    barFrame = CreateFrame("Frame", nil, frame)
    barFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",      px, -px)
    barFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px,  px)

    chargeBar = CreateFrame("StatusBar", "ElvUI_thingsUI_ChargeBar_Charges", barFrame)
    chargeBar:SetAllPoints(barFrame)
    chargeBar:SetMinMaxValues(0, 1)
    chargeBar:SetValue(0)

    if chargeBar.SetColorFill then
        chargeBar:SetColorFill(0.2, 0.6, 1.0, 1)
    else
        chargeBar:SetStatusBarTexture(E.media.blankTex)
    end

    rechargeBar = CreateFrame("StatusBar", "ElvUI_thingsUI_ChargeBar_Recharge", barFrame)

    rechargeBar:SetPoint("LEFT", chargeBar:GetStatusBarTexture(), "RIGHT")
    rechargeBar:SetPoint("TOP",    barFrame, "TOP",    0, 0)
    rechargeBar:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 0)
    if rechargeBar.SetColorFill then
        rechargeBar:SetColorFill(0.5, 0.5, 0.5, 0.8)
    else
        rechargeBar:SetStatusBarTexture(E.media.blankTex)
    end
    rechargeBar:SetFrameLevel(chargeBar:GetFrameLevel() + 1)
    rechargeBar:SetMinMaxValues(0, 1)
    rechargeBar:SetValue(0)

    rechargeText = rechargeBar:CreateFontString(nil, "OVERLAY")
    rechargeText:SetPoint("CENTER", rechargeBar, "CENTER", 0, 0)

    ticksContainer = CreateFrame("Frame", nil, barFrame)
    ticksContainer:SetAllPoints(barFrame)
    ticksContainer:SetFrameLevel(barFrame:GetFrameLevel() + 5)

    ns.Pixel.SetSize(frame, 200, 18)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", E.UIParent, "CENTER", 0, 0)

    if E and E.CreateMover then
        E:CreateMover(frame, "ElvUI_thingsUI_ChargeBarMover",
            "thingsUI Charge Bar", nil, nil, nil, "ALL,THINGSUI",
            function() return not (E.db.thingsUI.chargeBar and E.db.thingsUI.chargeBar.enabled) end,
            "thingsUI,modulesTab,chargeBar")
    end
end

local function ReleaseTicks()
    for i = 1, activeTickCount do
        if tickPool[i] then tickPool[i]:Hide() end
    end
    activeTickCount = 0
end

local function GetTick(i)
    if not tickPool[i] then
        tickPool[i] = ticksContainer:CreateTexture(nil, "OVERLAY")
    end
    return tickPool[i]
end

local function ApplyChargeLayout()
    if not currentSpellID or currentMaxCharges <= 0 then
        if chargeBar then
            chargeBar:SetMinMaxValues(0, 1)
            chargeBar:SetValue(0)
        end
        if rechargeBar then rechargeBar:Hide() end
        ReleaseTicks()
        return
    end

    local db = E.db.thingsUI.chargeBar
    local barW = barFrame:GetWidth()
    local barH = barFrame:GetHeight()
    if not barW or barW <= 0 then return end

    local n     = currentMaxCharges
    local barWInt = math.floor(barW + 0.5)
    local showTicks = db.showTicks and db.tickWidth and db.tickWidth > 0
    local tc = db.tickColor or {}
    local tcr, tcg, tcb, tca = tc.r or 0, tc.g or 0, tc.b or 0, tc.a or 1
    local tickW = db.tickWidth or 1

    if lastLayoutW == barWInt and lastLayoutH == barH
       and lastLayoutN == n
       and lastLayoutShowTicks == showTicks
       and lastLayoutTickW == tickW
       and lastLayoutTickR == tcr and lastLayoutTickG == tcg
       and lastLayoutTickB == tcb and lastLayoutTickA == tca then
        return
    end
    lastLayoutW, lastLayoutH = barWInt, barH
    lastLayoutN = n
    lastLayoutShowTicks, lastLayoutTickW = showTicks, tickW
    lastLayoutTickR, lastLayoutTickG, lastLayoutTickB, lastLayoutTickA = tcr, tcg, tcb, tca

    chargeBar:SetMinMaxValues(0, n)
    rechargeBar:SetWidth(barW / n)

    ReleaseTicks()
    if showTicks and n > 1 then
        for i = 1, n - 1 do
            local t = GetTick(i)
            t:SetColorTexture(tcr, tcg, tcb, tca)
            t:SetSize(tickW, barH)
            t:ClearAllPoints()
            local x = math.floor((i * barWInt) / n + 0.5)
            t:SetPoint("CENTER", barFrame, "LEFT", x, 0)
            t:Show()
            activeTickCount = i
        end
    end
end

local function LayoutPick(entry, db, key, fallback)
    if entry.useGlobalLayout == false and entry[key] ~= nil then
        return entry[key]
    end
    if db[key] ~= nil then return db[key] end
    return fallback
end

local function ApplyVisuals(entry)
    EnsureFrame()
    local db = E.db.thingsUI.chargeBar

    local r, g, b = 0.2, 0.6, 1.0
    if entry.useClassColor ~= false then
        local c = E:ClassColor(E.myclass, true)
        if c then r, g, b = c.r, c.g, c.b end
    elseif entry.customColor then
        r, g, b = entry.customColor.r or r, entry.customColor.g or g, entry.customColor.b or b
    end

    local rc = LayoutPick(entry, db, "rechargeColor", {}) or {}
    local rcR, rcG, rcB, rcA = rc.r or 0.5, rc.g or 0.5, rc.b or 0.5, rc.a or 0.8
    local bg = LayoutPick(entry, db, "backgroundColor", {}) or {}
    local bgR, bgG, bgB, bgA = bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.7
    local bd = LayoutPick(entry, db, "borderColor", {}) or {}
    local bdR, bdG, bdB, bdA = bd.r or 0, bd.g or 0, bd.b or 0, bd.a or 1
    local showText = LayoutPick(entry, db, "showText", true) ~= false
    local fontName = LayoutPick(entry, db, "textFont", "Expressway")
    local fontSize = LayoutPick(entry, db, "textSize", 12)
    local fontOutline = LayoutPick(entry, db, "textOutline", "OUTLINE")

    if lastVisualSpellID == currentSpellID
       and lastVisualR == r and lastVisualG == g and lastVisualB == b
       and lastVisualRR == rcR and lastVisualRG == rcG and lastVisualRB == rcB and lastVisualRA == rcA
       and lastVisualBgR == bgR and lastVisualBgG == bgG and lastVisualBgB == bgB and lastVisualBgA == bgA
       and lastVisualBdR == bdR and lastVisualBdG == bdG and lastVisualBdB == bdB and lastVisualBdA == bdA
       and lastVisualShowText == showText
       and lastVisualFont == fontName and lastVisualSize == fontSize and lastVisualOutline == fontOutline then
        return
    end
    lastVisualSpellID = currentSpellID
    lastVisualR, lastVisualG, lastVisualB = r, g, b
    lastVisualRR, lastVisualRG, lastVisualRB, lastVisualRA = rcR, rcG, rcB, rcA
    lastVisualBgR, lastVisualBgG, lastVisualBgB, lastVisualBgA = bgR, bgG, bgB, bgA
    lastVisualBdR, lastVisualBdG, lastVisualBdB, lastVisualBdA = bdR, bdG, bdB, bdA
    lastVisualShowText = showText
    lastVisualFont, lastVisualSize, lastVisualOutline = fontName, fontSize, fontOutline

    if chargeBar.SetColorFill then
        chargeBar:SetColorFill(r, g, b, 1)
    else
        chargeBar:SetStatusBarColor(r, g, b, 1)
    end
    if rechargeBar.SetColorFill then
        rechargeBar:SetColorFill(rcR, rcG, rcB, rcA)
    else
        rechargeBar:SetStatusBarColor(rcR, rcG, rcB, rcA)
    end

    if frame.tuiBg then
        frame.tuiBg:SetColorTexture(bgR, bgG, bgB, bgA)
    end
    if frame.tuiBorder then
        for _, t in pairs(frame.tuiBorder) do
            t:SetColorTexture(bdR, bdG, bdB, bdA)
        end
    end

    if showText then
        local font = (LSM and LSM:Fetch("font", fontName)) or STANDARD_TEXT_FONT
        E:SetFont(rechargeText, font, fontSize, fontOutline)
        rechargeText:SetTextColor(1, 1, 1, 1)
        rechargeText:Show()
    else
        rechargeText:Hide()
    end
end

local function ApplyPosition(entry)
    if not frame then return end
    local db = E.db.thingsUI.chargeBar
    local h = db.height or 18
    if lastAppliedHeight == h then return end
    lastAppliedHeight = h
    ns.Pixel.SetSize(frame, frame:GetWidth() or 200, h)
    if ns.BarSetup and ns.BarSetup.ApplyStack then
        ns.BarSetup.ApplyStack()
    end
end

local function ResolveAnchorTarget(anchorName)
    local proxy = ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(anchorName)
    if proxy then return proxy, anchorName end
    local f = _G[anchorName]
    if type(f) == "table" and type(f.GetObjectType) == "function" then
        if anchorName == "ElvUF_Player_CastBar" and f.Holder then
            f = f.Holder
        end
        if f ~= frame then return f, anchorName end
    end
    return UIParent, "UIParent"
end

local function ApplyPositionFHT()
    if not frame then return end
    local db = E.db.thingsUI.chargeBar

    local target, resolvedName = ResolveAnchorTarget(db.anchorFrame or "UIParent")
    local point = db.anchorPoint or "CENTER"
    local relative = db.anchorRelativePoint or "CENTER"

    local w = db.fhtWidth or 200
    if db.inheritWidth and resolvedName ~= "UIParent" then
        local aw = target:GetWidth()
        if aw and aw > 0 then w = aw + (db.inheritWidthOffset or 0) end
    end
    if w < 20 then w = 20 end
    local h = db.height or 18
    local xOff = db.fhtXOffset or 0
    local yOff = db.fhtYOffset or 0

    if lastFhtW == w and lastFhtH == h and lastFhtTarget == target
       and lastFhtPoint == point and lastFhtRel == relative
       and lastFhtXOff == xOff and lastFhtYOff == yOff then
        return
    end
    lastFhtW, lastFhtH = w, h
    lastFhtTarget = target
    lastFhtPoint, lastFhtRel = point, relative
    lastFhtXOff, lastFhtYOff = xOff, yOff

    ns.Pixel.SetSize(frame, w, h)
    frame:ClearAllPoints()
    ns.Pixel.SetPoint(frame, point, target, relative, xOff, yOff)
end

local function FollowOverride(id)
    if not id then return id end
    if FindSpellOverrideByID then
        local override = FindSpellOverrideByID(id)
        if override and override > 0 then return override end
    end
    return id
end

local function ResolveSpellID(entry)
    if not entry then return nil end
    if entry.spellName and type(entry.spellName) == "string" and entry.spellName ~= "" then
        if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
            local id = C_Spell.GetSpellIDForSpellIdentifier(entry.spellName)
            if id then return FollowOverride(id) end
        end
    end
    local raw = entry.spellID
    if type(raw) == "number" and raw > 0 then return FollowOverride(raw) end
    if type(raw) == "string" then
        local n = tonumber(raw)
        if n then return FollowOverride(n) end
        local id = C_Spell and C_Spell.GetSpellIDForSpellIdentifier and C_Spell.GetSpellIDForSpellIdentifier(raw)
        if id then return FollowOverride(id) end
    end
    return nil
end

local function _UpdateChargeStateInner()
    if not currentSpellID then return end
    local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(currentSpellID) or nil
    if not info then return end

    local mx = info.maxCharges
    if type(mx) == "number" and not issecretvalue(mx) and mx ~= currentMaxCharges then
        currentMaxCharges = mx
        ApplyChargeLayout()
    end

    chargeBar:SetValue(info.currentCharges)

    local durationObj = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(currentSpellID)
    local active = info.isActive
    if durationObj and (issecretvalue(active) or active) then
        rechargeBar.isActive = true
        rechargeBar:SetTimerDuration(
            durationObj,
            Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection.ElapsedTime
        )
        rechargeBar:Show()
    else
        rechargeBar.isActive = false
        rechargeBar:Hide()
        rechargeText:SetText("")
    end
end

local function UpdateChargeState() _UpdateChargeStateInner() end

local function UpdateRechargeText()
    if not rechargeText:IsShown() then return end
    if not rechargeBar.GetTimerDuration or not rechargeBar.isActive then
        rechargeText:SetText("")
        return
    end
    local timer = rechargeBar:GetTimerDuration()
    if not timer then
        rechargeText:SetText("")
        return
    end
    rechargeText:SetFormattedText("%.1f", timer:GetRemainingDuration())
end

local textTicker = CreateFrame("Frame")
textTicker:Hide()
local rechargeTextElapsed = 0
textTicker:SetScript("OnUpdate", function(_, elapsed)
    if not rechargeBar or not rechargeBar:IsShown() then
        textTicker:Hide()
        return
    end
    rechargeTextElapsed = rechargeTextElapsed + elapsed
    if rechargeTextElapsed >= 0.1 then
        rechargeTextElapsed = 0
        UpdateRechargeText()
    end
end)

local function HideAll()
    local wasShown = frame and frame:IsShown()
    if frame then frame:Hide() end
    if rechargeBar then rechargeBar:Hide() end
    textTicker:Hide()
    if wasShown then
        if TUI.InvalidateDynamicCastBarAnchor then
            TUI:InvalidateDynamicCastBarAnchor()
        end
        if ns.BarSetup and ns.BarSetup.ApplyStack then
            ns.BarSetup.ApplyStack()
        end
        if ns.MoverSync and ns.MoverSync.Queue then
            ns.MoverSync.Queue()
        end
    end
end

local function UpdateNow()
    if not isEnabled or not playerEntered then
        HideAll() return
    end

    local entry = GetSpecEntry()
    if not entry then
        HideAll() return
    end

    local spellID = ResolveSpellID(entry)
    if not spellID then
        HideAll() return
    end

    local info = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID) or nil
    if not info then
        HideAll(); return
    end
    local mx = info.maxCharges
    if type(mx) ~= "number" or mx < 1 then
        if not currentMaxCharges or currentMaxCharges < 1 or currentSpellID ~= spellID then
            HideAll(); return
        end
        mx = currentMaxCharges
    end

    EnsureFrame()
    local fht = IsFHT()

    if currentSpellID ~= spellID then
        currentSpellID = spellID
        InvalidateLayoutCache()
    end
    currentMaxCharges = mx

    if fht then
        ApplyPositionFHT()
    else
        ApplyPosition(entry)
    end
    ApplyStrata()
    ApplyChargeLayout()
    ApplyVisuals(entry)
    UpdateChargeState()

    local wasShown = frame:IsShown()
    frame:Show()
    if not wasShown and TUI.InvalidateDynamicCastBarAnchor then
        TUI:InvalidateDynamicCastBarAnchor()
    end

    if not wasShown and ns.ClassbarMode and ns.ClassbarMode.RequestUpdate then
        local cdb = E.db.thingsUI.classbarMode
        if cdb and cdb.enabled and cdb.specs then
            local idx = GetSpecialization and GetSpecialization() or nil
            local id  = idx and select(1, GetSpecializationInfo(idx)) or 0
            local cEntry = id ~= 0 and cdb.specs[tostring(id)]
            if cEntry and cEntry.slot == "ABOVE_CHARGEBAR" then
                ns.ClassbarMode.RequestUpdate()
            end
        end
    end

    if rechargeBar:IsShown() and rechargeText:IsShown() then
        textTicker:Show()
    else
        textTicker:Hide()
    end
end

local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    isDirty = false
    UpdateNow()
end

local function MarkDirty()
    if not isEnabled then return end
    if isDirty then return end
    isDirty = true
    updateFrame:SetScript("OnUpdate", OnNextFrame)
end
CB.MarkDirty = MarkDirty

eventFrame:SetScript("OnEvent", function(_, event, arg1, _, arg3)
    if event == "PLAYER_ENTERING_WORLD" then
        playerEntered = true
        C_Timer.After(0.5, MarkDirty)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        InvalidateLayoutCache()
        C_Timer.After(0.3, MarkDirty)
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.1, MarkDirty)
    elseif event == "SPELL_UPDATE_CHARGES" then
        if frame and frame:IsShown() then
            UpdateChargeState()
            if rechargeBar:IsShown() and rechargeText:IsShown() then
                textTicker:Show()
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        if currentSpellID and arg3 == currentSpellID and frame and frame:IsShown() then
            UpdateChargeState()
            if rechargeBar:IsShown() and rechargeText:IsShown() then
                textTicker:Show()
            end
        end
    end
end)

local function MarkDirtyFromCluster()
    if isDirty then return end
    MarkDirty()
end

HookCluster = function()
    local f = _G["EssentialCooldownViewer"]
    if not f or f._TUI_chargeBarHooked then return end
    f._TUI_chargeBarHooked = true
    if type(f.RefreshLayout) == "function" then
        hooksecurefunc(f, "RefreshLayout", MarkDirtyFromCluster)
    end
end

function TUI:UpdateChargeBar()
    local db = E.db.thingsUI.chargeBar
    InvalidateLayoutCache()
    if db and db.enabled then
        isEnabled = true
        if not playerEntered and IsLoggedIn and IsLoggedIn() then
            playerEntered = true
        end
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
        eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        HookCluster()
        if playerEntered then C_Timer.After(0.2, MarkDirty) end
    else
        isEnabled = false
        isDirty = false
        updateFrame:SetScript("OnUpdate", nil)
        eventFrame:UnregisterAllEvents()
        textTicker:Hide()
        HideAll()
    end
end

function CB.RequestUpdate()
    MarkDirty()
end
function CB.RequestUpdateFull()
    InvalidateLayoutCache()
    MarkDirty()
end
