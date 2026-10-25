local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local CB = {}
ns.ChargeBar = CB

local frame
local barFrame
-- one piece per charge: { bar, clip, rech, text }
local slots = {}
local rechargeOn, textOn = false, true
local fillR, fillG, fillB = 0.2, 0.6, 1.0
local recR, recG, recB, recA = 0.5, 0.5, 0.5, 0.8
local textFont, textSize, textOutline
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
-- no charge info: the spell isn't a charge spell right now (its talent not taken)
local noChargeInfo = false

local lastLayoutW, lastLayoutH, lastLayoutN, lastLayoutMode
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
    local entry = db.specs[tostring(id)]
    if entry and entry.enabled == false then return nil end
    return entry
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

local function Fill(bar, r, g, b, a)
    if bar.SetColorFill then bar:SetColorFill(r, g, b, a) else bar:SetStatusBarColor(r, g, b, a) end
end

local function GetSlot(i)
    local s = slots[i]
    if s then return s end
    s = {}
    s.bar = CreateFrame("StatusBar", nil, barFrame)
    if not s.bar.SetColorFill then s.bar:SetStatusBarTexture(E.media.blankTex) end
    Fill(s.bar, fillR, fillG, fillB, 1)
    s.gate = CreateFrame("Frame", nil, barFrame)
    s.gate:SetClipsChildren(true)
    s.gate:SetFrameLevel(s.bar:GetFrameLevel() + 1)
    s.clip = CreateFrame("Frame", nil, s.gate)
    s.clip:SetClipsChildren(true)
    s.rech = CreateFrame("StatusBar", nil, s.clip)
    if not s.rech.SetColorFill then s.rech:SetStatusBarTexture(E.media.blankTex) end
    Fill(s.rech, recR, recG, recB, recA)
    s.rech:SetMinMaxValues(0, 1)
    s.rech:Hide()
    s.text = s.rech:CreateFontString(nil, "OVERLAY")
    s.text:SetPoint("CENTER", s.rech, "CENTER", 0, 0)
    E:SetFont(s.text, textFont or STANDARD_TEXT_FONT, textSize or 12, textOutline or "OUTLINE")
    s.text:SetTextColor(1, 1, 1, 1)
    s.text:SetShown(textOn)
    slots[i] = s
    return s
end

-- the k-th charge to fill: its piece (1 = left) and whether it fills leftwards
local function Place(k, n, mode)
    if mode == "rtl" then return n - k + 1, true end
    if mode == "edges" then
        if k % 2 == 1 then return (k + 1) / 2, false end
        return n - k / 2 + 1, true
    end
    if mode == "middle" then
        if n % 2 == 0 then
            if k % 2 == 1 then return n / 2 - (k - 1) / 2, true end
            return n / 2 + k / 2, false
        end
        local c = (n + 1) / 2
        if k == 1 then return c, false end
        if k % 2 == 0 then return c - k / 2, true end
        return c + (k - 1) / 2, false
    end
    return k, false
end

local function FillMode()
    local db = E.db.thingsUI.chargeBar
    local e = GetSpecEntry()
    if e and e.useGlobalLayout == false and e.fillMode then return e.fillMode end
    return db.fillMode or "ltr"
end

-- Each piece holds one charge (min k-1, max k: the game clamps the secret count itself).
-- Its recharge (and text) sits in two clips: the piece's empty part, and a gate the piece
-- before it opens only once that one is full - just the charge coming back shows its timer.
local function LayoutSlots(n, W, mode)
    local seg = W / n
    for k = 1, n do
        local s = GetSlot(k)
        local p, left = Place(k, n, mode)
        local x0, x1 = (p - 1) * seg, p * seg
        s.x0, s.x1, s.left = x0, x1, left
        s.bar:ClearAllPoints()
        s.bar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x0, 0)
        s.bar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMLEFT", x1, 0)
        s.bar:SetMinMaxValues(k - 1, k)
        s.bar:SetReverseFill(left)
        s.bar:Show()
        local tex = s.bar:GetStatusBarTexture()
        s.rech:ClearAllPoints()
        s.rech:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x0, 0)
        s.rech:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMLEFT", x1, 0)
        s.rech:SetReverseFill(left)
        -- the piece's empty part (zero wide once it's full)
        s.clip:ClearAllPoints()
        if left then
            s.clip:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x0, 0)
            s.clip:SetPoint("BOTTOMRIGHT", tex, "BOTTOMLEFT", 0, 0)
        else
            s.clip:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, 0)
            s.clip:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMLEFT", x1, 0)
        end
        -- open once the piece before it is full
        s.gate:ClearAllPoints()
        local prev = k > 1 and slots[k - 1]
        if not prev then
            s.gate:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x0, 0)
            s.gate:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMLEFT", x1, 0)
        elseif prev.left then
            s.gate:SetPoint("TOPLEFT", prev.bar:GetStatusBarTexture(), "TOPLEFT", x0 - prev.x0, 0)
            s.gate:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMLEFT", x1, 0)
        else
            s.gate:SetPoint("TOPLEFT", barFrame, "TOPLEFT", x0, 0)
            s.gate:SetPoint("BOTTOMRIGHT", prev.bar:GetStatusBarTexture(), "BOTTOMRIGHT", x1 - prev.x1, 0)
        end
        s.gate:Show()
    end
    for k = n + 1, #slots do
        slots[k].bar:Hide()
        slots[k].gate:Hide()
    end
end

local function HideSlots()
    for _, s in ipairs(slots) do s.bar:Hide(); s.gate:Hide() end
end

local function SetCharges(v)
    for k = 1, math.min(currentMaxCharges, #slots) do slots[k].bar:SetValue(v) end
end

local function ApplyChargeLayout()
    if not currentSpellID or currentMaxCharges <= 0 then
        HideSlots()
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

    local mode = FillMode()
    if lastLayoutW == barWInt and lastLayoutH == barH
       and lastLayoutN == n and lastLayoutMode == mode
       and lastLayoutShowTicks == showTicks
       and lastLayoutTickW == tickW
       and lastLayoutTickR == tcr and lastLayoutTickG == tcg
       and lastLayoutTickB == tcb and lastLayoutTickA == tca then
        return
    end
    lastLayoutW, lastLayoutH = barWInt, barH
    lastLayoutN, lastLayoutMode = n, mode
    lastLayoutShowTicks, lastLayoutTickW = showTicks, tickW
    lastLayoutTickR, lastLayoutTickG, lastLayoutTickB, lastLayoutTickA = tcr, tcg, tcb, tca

    LayoutSlots(n, barW, mode)

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

    fillR, fillG, fillB = r, g, b
    recR, recG, recB, recA = rcR, rcG, rcB, rcA
    for _, s in ipairs(slots) do
        Fill(s.bar, r, g, b, 1)
        Fill(s.rech, rcR, rcG, rcB, rcA)
    end

    if frame.tuiBg then
        frame.tuiBg:SetColorTexture(bgR, bgG, bgB, bgA)
    end
    if frame.tuiBorder then
        for _, t in pairs(frame.tuiBorder) do
            t:SetColorTexture(bdR, bdG, bdB, bdA)
        end
    end

    textOn = showText
    textFont = (LSM and LSM:Fetch("font", fontName)) or STANDARD_TEXT_FONT
    textSize, textOutline = fontSize, fontOutline
    for _, s in ipairs(slots) do
        E:SetFont(s.text, textFont, textSize, textOutline)
        s.text:SetShown(showText)
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

local function RawSpellID(entry)
    if not entry then return nil end
    if entry.spellName and type(entry.spellName) == "string" and entry.spellName ~= "" then
        if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
            local id = C_Spell.GetSpellIDForSpellIdentifier(entry.spellName)
            if id then return id end
        end
    end
    local raw = entry.spellID
    if type(raw) == "number" and raw > 0 then return raw end
    if type(raw) == "string" then
        local n = tonumber(raw)
        if n then return n end
        return C_Spell and C_Spell.GetSpellIDForSpellIdentifier and C_Spell.GetSpellIDForSpellIdentifier(raw) or nil
    end
    return nil
end

local function ResolveSpellID(entry)
    local id = RawSpellID(entry)
    return id and FollowOverride(id)
end

-- With one charge the game runs the spell as a plain cooldown: a one-piece bar ("bar")
-- or the bar hides and the icon stays in the Cooldown Manager ("cdm")
local function OneChargeMode(entry)
    return (entry and entry.oneCharge) or "bar"
end

local function MaxChargesOf(id)
    local info = id and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(id)
    local mx = info and info.maxCharges
    if issecretvalue and issecretvalue(mx) then
        return (id == currentSpellID and currentMaxCharges > 0) and currentMaxCharges or nil
    end
    return info and mx or 1
end

-- the spell this spec's bar tracks (as set, and its live override): its CDM copy is a duplicate
function CB.TrackedSpells()
    if not CB.IsActiveForCurrentSpec() then return nil end
    local entry = GetSpecEntry()
    local raw = RawSpellID(entry)
    if not raw then return nil end
    local live = FollowOverride(raw)
    if issecretvalue and issecretvalue(live) then live = nil end
    if OneChargeMode(entry) == "cdm" and (MaxChargesOf(live or raw) or 2) <= 1 then return nil end
    return raw, live
end

local lastTracked
local function NotifyTracked()
    local a, b = CB.TrackedSpells()
    local sig = tostring(a) .. ":" .. tostring(b)
    if sig == lastTracked then return end
    lastTracked = sig
    if ns.CDMIcons and ns.CDMIcons.QueuePassiveRebuild then ns.CDMIcons.QueuePassiveRebuild() end
end

local function HideRecharge()
    rechargeOn = false
    for _, s in ipairs(slots) do
        s.rech:Hide()
        s.text:SetText("")
    end
end

-- the one-charge cooldown's end: no event follows it, so a hidden Cooldown marks it
local endCD
local function WatchEnd(dur)
    if not endCD then
        endCD = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
        endCD:SetSize(1, 1)
        endCD:SetPoint("BOTTOMLEFT")
        endCD:SetDrawSwipe(false)
        endCD:SetDrawEdge(false)
        endCD:SetDrawBling(false)
        endCD:SetHideCountdownNumbers(true)
        endCD:SetScript("OnCooldownDone", function()
            if not (slots[1] and currentMaxCharges <= 1) then return end
            HideRecharge()
            SetCharges(1)
        end)
    end
    if dur and endCD.SetCooldownFromDurationObject then endCD:SetCooldownFromDurationObject(dur, true) end
end

-- every piece runs the timer; the clips decide which one is seen
local function ShowRecharge(durationObj)
    rechargeOn = true
    for k = 1, math.min(currentMaxCharges, #slots) do
        local r = slots[k].rech
        r:SetTimerDuration(durationObj, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
        r:Show()
    end
end

-- one charge: the spell's own cooldown fills the one piece (the GCD left out)
local function UpdateSingle(info)
    local CI = ns.CDMIcons
    local onCD = CI and CI.OnRealCD and CI.OnRealCD(currentSpellID)
    if info then SetCharges(info.currentCharges)
    elseif onCD ~= nil then SetCharges(onCD and 0 or 1) end
    local dur = onCD ~= false and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(currentSpellID)
    if dur then
        ShowRecharge(dur)
        WatchEnd(dur)
    else
        HideRecharge()
    end
end

local function _UpdateChargeStateInner()
    if not currentSpellID then return end
    local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(currentSpellID) or nil
    if not info then
        if noChargeInfo then UpdateSingle(nil) end
        return
    end

    local mx = info.maxCharges
    if type(mx) == "number" and not issecretvalue(mx) and mx ~= currentMaxCharges then
        currentMaxCharges = mx
        ApplyChargeLayout()
    end
    if currentMaxCharges <= 1 then
        UpdateSingle(info)
        return
    end

    SetCharges(info.currentCharges)

    local durationObj = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(currentSpellID)
    local active = info.isActive
    if durationObj and (issecretvalue(active) or active) then
        ShowRecharge(durationObj)
    else
        HideRecharge()
    end
end

local function UpdateChargeState() _UpdateChargeStateInner() end

local function UpdateRechargeText()
    if not (textOn and rechargeOn and slots[1]) then return end
    local timer = slots[1].rech.GetTimerDuration and slots[1].rech:GetTimerDuration()
    local n = math.min(currentMaxCharges, #slots)
    for k = 1, n do
        local t = slots[k].text
        if timer then t:SetFormattedText("%.1f", timer:GetRemainingDuration()) else t:SetText("") end
    end
end

local textTicker = CreateFrame("Frame")
textTicker:Hide()
local rechargeTextElapsed = 0
textTicker:SetScript("OnUpdate", function(_, elapsed)
    if not rechargeOn then
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
    HideRecharge()
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
    NotifyTracked()
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
    local mx
    if info then
        mx = info.maxCharges
        if type(mx) ~= "number" or (issecretvalue and issecretvalue(mx)) or mx < 1 then
            if not currentMaxCharges or currentMaxCharges < 1 or currentSpellID ~= spellID then
                HideAll(); return
            end
            mx = currentMaxCharges
        end
    elseif IsPlayerSpell(spellID) then
        mx = 1
    else
        HideAll(); return
    end
    noChargeInfo = not info
    if mx <= 1 and OneChargeMode(entry) == "cdm" then
        HideAll(); return
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

    if rechargeOn and textOn then
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
            if rechargeOn and textOn then
                textTicker:Show()
            end
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- one charge runs on the spell's cooldown; read inside the event (the GCD flag is right there)
        if currentMaxCharges <= 1 and frame and frame:IsShown() then
            UpdateChargeState()
            if rechargeOn and textOn then
                textTicker:Show()
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        if currentSpellID and arg3 == currentSpellID and frame and frame:IsShown() then
            UpdateChargeState()
            if rechargeOn and textOn then
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
    ns.ViewerHooks.On("EssentialCooldownViewer", "RefreshLayout", "ChargeBar", MarkDirtyFromCluster)
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
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
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
        NotifyTracked()
    end
end

function CB.RequestUpdate()
    MarkDirty()
end
function CB.RequestUpdateFull()
    InvalidateLayoutCache()
    MarkDirty()
end
