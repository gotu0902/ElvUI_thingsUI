local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

local CB = {}
ns.ChargeBar = CB

local frame
local barFrame              -- layout container for segments
local segmentPool = {}      -- per-charge StatusBars
local activeSegmentCount = 0
local rechargeFrame
local rechargeText
local ticksContainer
local tickPool = {}
local activeTickCount = 0

local updateFrame = CreateFrame("Frame")
local eventFrame  = CreateFrame("Frame")
local rechargeTicker = CreateFrame("Frame")
rechargeTicker:Hide()

local HookCluster = function() end

local isDirty   = false
local isEnabled = false
local playerEntered = (IsLoggedIn and IsLoggedIn()) or false
local currentSpellID
local currentMaxCharges = 0
local rechargeStart, rechargeDuration
local cachedRechargeDuration = {} -- [spellID] = seconds
local predictedCharges

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

local function HasClassbarConflict(slot)
    if slot == "ABOVE_SECONDARY" then return false end
    local cdb = E.db.thingsUI.classbarMode
    if not cdb or not cdb.enabled or not cdb.specs then return false end
    local id = GetCurrentSpecID()
    if id == 0 then return false end
    local entry = cdb.specs[tostring(id)]
    if not entry then return false end
    return (entry.slot or "SECONDARY") == slot
end

function CB.GetActiveSlot()
    local entry = GetSpecEntry()
    if not entry then return nil end
    if HasClassbarConflict(entry.slot or "SECONDARY") then return nil end
    return entry.slot or "SECONDARY"
end

-- For the dynamic cast bar to stack above us when shown.
function CB.GetActiveAnchorFrame()
    if not isEnabled or not frame or not frame:IsShown() then return nil end
    if not CB.GetActiveSlot() then return nil end
    return frame
end

local function GetAnchorTarget(slot)
    local primary   = _G["BCDM_PowerBar"]
    local secondary = _G["BCDM_SecondaryPowerBar"]
    local essential = _G["EssentialCooldownViewer"]
    if slot == "POWER" then
        if essential then return essential end
    elseif slot == "ABOVE_SECONDARY" then
        if secondary and secondary:IsShown() and secondary:GetWidth() > 0 then
            return secondary
        end

        if primary and primary:IsShown() and primary:GetWidth() > 0 then
            return primary
        end
        if essential then return essential end
    else
        if primary and primary:IsShown() and primary:GetWidth() > 0 then
            return primary
        end
        if essential then return essential end
    end
    return nil
end

local function GetClusterBounds()
    local essential = _G["EssentialCooldownViewer"]
    if not essential then return nil end
    local left, right = essential:GetLeft(), essential:GetRight()
    if not left or not right then return nil end
    local trinket = _G["BCDM_TrinketBar"]
    if trinket then
        local tl, tr = trinket:GetLeft(), trinket:GetRight()
        local hasTrinket = trinket:IsShown() and trinket:GetWidth() > 0 and tl and tr
        if not hasTrinket then
            -- Container may have 0 width; derive bounds from visible children.
            for i = 1, trinket:GetNumChildren() do
                local child = select(i, trinket:GetChildren())
                if child and child:IsShown() and child.GetLeft then
                    local cl, cr = child:GetLeft(), child:GetRight()
                    if cl and cr then
                        tl = (tl and math.min(tl, cl)) or cl
                        tr = (tr and math.max(tr, cr)) or cr
                        hasTrinket = true
                    end
                end
            end
        end
        if hasTrinket and tl and tr then
            if tl < left  then left  = tl end
            if tr > right then right = tr end
        end
    end
    return left, right
end

local function GetTickTexture()
    return (LSM and LSM:Fetch("statusbar", E.db.thingsUI.chargeBar.statusBarTexture)) or E.media.blankTex
end

local function EnsureFrame()
    if frame then return end

    frame = CreateFrame("Frame", "ElvUI_thingsUI_ChargeBar", E.UIParent, "BackdropTemplate")
    frame:SetFrameStrata("LOW")
    frame:Hide()

    barFrame = CreateFrame("Frame", nil, frame)
    barFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, 0)
    barFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    rechargeFrame = CreateFrame("StatusBar", nil, barFrame)
    rechargeFrame:SetMinMaxValues(0, 1)
    rechargeFrame:SetValue(0)

    rechargeText = rechargeFrame:CreateFontString(nil, "OVERLAY")

    ticksContainer = CreateFrame("Frame", nil, barFrame)
    ticksContainer:SetAllPoints(barFrame)
    ticksContainer:SetFrameLevel(barFrame:GetFrameLevel() + 5)
end

local function GetSegment(i)
    if not segmentPool[i] then
        local wrap = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
        if wrap.SetTemplate then wrap:SetTemplate("Default") end

        local s = CreateFrame("StatusBar", nil, wrap)
        s:SetPoint("TOPLEFT",     wrap, "TOPLEFT",      E.Border, -E.Border)
        s:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -E.Border,  E.Border)
        s:SetMinMaxValues(0, 1)
        s:SetValue(0)

        s.wrap = wrap
        segmentPool[i] = s
    end
    return segmentPool[i]
end

local function ReleaseSegments(fromIndex)
    for i = fromIndex, activeSegmentCount do
        local s = segmentPool[i]
        if s then
            s:Hide()
            if s.wrap then s.wrap:Hide() end
        end
    end
    if fromIndex <= activeSegmentCount then
        activeSegmentCount = fromIndex - 1
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


local function ApplyVisuals(entry)
    EnsureFrame()
    local db = E.db.thingsUI.chargeBar

    local tex = (LSM and LSM:Fetch("statusbar", db.statusBarTexture)) or E.media.blankTex

    -- Color
    local r, g, b = 0.2, 0.6, 1.0
    if entry.useClassColor ~= false then
        local c = E:ClassColor(E.myclass, true)
        if c then r, g, b = c.r, c.g, c.b end
    elseif entry.customColor then
        r, g, b = entry.customColor.r or r, entry.customColor.g or g, entry.customColor.b or b
    end

    -- Apply to all active segments
    for i = 1, activeSegmentCount do
        local s = segmentPool[i]
        if s then
            s:SetStatusBarTexture(tex)
            s:SetStatusBarColor(r, g, b, 1)
        end
    end

    rechargeFrame:SetStatusBarTexture(tex)
    local rc = db.rechargeColor or {}
    rechargeFrame:SetStatusBarColor(rc.r or 0.5, rc.g or 0.5, rc.b or 0.5, rc.a or 0.8)

    -- Text
    if entry.showText ~= false then
        local font = (LSM and LSM:Fetch("font", entry.textFont or "Expressway")) or STANDARD_TEXT_FONT
        rechargeText:SetFont(font, entry.textSize or 12, entry.textOutline or "OUTLINE")
        rechargeText:SetTextColor(1, 1, 1, 1)
        rechargeText:ClearAllPoints()
        rechargeText:SetPoint("CENTER", rechargeFrame, "CENTER", 0, 0)
        rechargeText:Show()
    else
        rechargeText:Hide()
    end
end

local function ApplyChargeLayout()
    if not currentSpellID or currentMaxCharges <= 0 then
        ReleaseSegments(1)
        ReleaseTicks()
        return
    end

    local db = E.db.thingsUI.chargeBar
    local barW = barFrame:GetWidth()
    local barH = barFrame:GetHeight()
    if not barW or barW <= 0 then return end

    local n     = currentMaxCharges
    local xGap  = db.xGap or 0
    local barWInt = math.floor(barW + 0.5)
    local D       = barWInt - xGap * (n - 1) -- total drawable pixel width
    local function segLeft(i)  -- 0-based pixel offset of segment i's left edge
        return math.floor(((i - 1) * D) / n + 0.5) + (i - 1) * xGap
    end
    local function segRight(i)
        return math.floor((i * D) / n + 0.5) + (i - 1) * xGap
    end

    -- Build / position N segment status bars
    local tex = (LSM and LSM:Fetch("statusbar", db.statusBarTexture)) or E.media.blankTex
    local lastSegW = 1
    for i = 1, n do
        local s = GetSegment(i)
        s:SetStatusBarTexture(tex)
        local left  = segLeft(i)
        local w     = segRight(i) - left
        if w < 1 then w = 1 end
        lastSegW = w
        local wrap = s.wrap
        wrap:ClearAllPoints()
        wrap:SetPoint("LEFT", barFrame, "LEFT", left, 0)
        wrap:SetSize(w, barH)
        wrap:Show()
        s:Show()
    end
    ReleaseSegments(n + 1)
    activeSegmentCount = n

    rechargeFrame:SetWidth(lastSegW)
    rechargeFrame:SetHeight(barH)

    ReleaseTicks()
    if (xGap or 0) <= 0 and db.showTicks and db.tickWidth and db.tickWidth > 0 then
        local tc = db.tickColor or {}
        for i = 1, n - 1 do
            local t = GetTick(i)
            t:SetColorTexture(tc.r or 0, tc.g or 0, tc.b or 0, tc.a or 1)
            t:SetSize(db.tickWidth, barH)
            t:ClearAllPoints()
            -- Place tick centered on the boundary between segment i and i+1.
            t:SetPoint("CENTER", barFrame, "LEFT", segRight(i), 0)
            t:Show()
            activeTickCount = i
        end
    end
end

local function _UpdateChargeStateInner()
    if not currentSpellID then return end
    local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(currentSpellID) or nil
    if not info then return end -- don't hide; keep last predicted state visible

    local function safeNumber(field)
        local ok, v = pcall(function() return info[field] end)
        if not ok or type(v) ~= "number" then return nil end
        local ok2, isPos = pcall(function() return v >= 0 end)
        if not ok2 or not isPos then return nil end
        return v
    end

    local cur        = safeNumber("currentCharges")
    local mx         = safeNumber("maxCharges")
    local cdStart    = safeNumber("cooldownStartTime")
    local cdDuration = safeNumber("cooldownDuration")

    if cdDuration and cdDuration > 0 then
        cachedRechargeDuration[currentSpellID] = cdDuration
    end

    -- Combat-taint fallback: API returned nil/garbagerino for charge countserino.
    if not cur or not mx then
        if predictedCharges == nil then return end -- nothing to fall back on
        cur = predictedCharges
        mx  = currentMaxCharges
        cdStart    = rechargeStart or cdStart
        cdDuration = rechargeDuration or cachedRechargeDuration[currentSpellID]
    end

    if mx ~= currentMaxCharges then
        currentMaxCharges = mx
        ApplyChargeLayout()
    end

    -- Sync prediction back to truth
    predictedCharges = cur

    -- Fill each segment 0/1
    for i = 1, activeSegmentCount do
        local s = segmentPool[i]
        if s then s:SetValue(i <= cur and 1 or 0) end
    end

    if cur < mx and type(cdStart) == "number" and type(cdDuration) == "number" and cdDuration > 0 then
        rechargeStart    = cdStart
        rechargeDuration = cdDuration
        local target = segmentPool[cur + 1]
        if target then
            rechargeFrame:ClearAllPoints()
            rechargeFrame:SetAllPoints(target)
            rechargeFrame:Show()
        else
            rechargeFrame:Hide()
        end
    else
        rechargeStart, rechargeDuration = nil, nil
        rechargeFrame:Hide()
    end
end

local function RenderPredicted()
    if not currentSpellID or not currentMaxCharges or currentMaxCharges <= 0 then return end
    local cur = predictedCharges
    if type(cur) ~= "number" then return end
    local mx = currentMaxCharges

    for i = 1, activeSegmentCount do
        local s = segmentPool[i]
        if s then s:SetValue(i <= cur and 1 or 0) end
    end

    if cur < mx and rechargeStart and rechargeDuration then
        local target = segmentPool[cur + 1]
        if target then
            rechargeFrame:ClearAllPoints()
            rechargeFrame:SetAllPoints(target)
            rechargeFrame:Show()
        else
            rechargeFrame:Hide()
        end
    else
        rechargeFrame:Hide()
    end
end

local function UpdateChargeState()
    -- Wrap in pcall to swallow secure-taint errors during combat lockdown.
    pcall(_UpdateChargeStateInner)
end

local function _OnRechargeUpdateInner()
    if not rechargeStart or not rechargeDuration then
        rechargeText:SetText("")
        rechargeFrame:SetValue(0)
        return
    end
    local now = GetTime()
    local elapsed = now - rechargeStart
    local remaining = rechargeDuration - elapsed
    if remaining <= 0 then
        if type(predictedCharges) == "number" then
            predictedCharges = predictedCharges + 1
            if currentMaxCharges and predictedCharges > currentMaxCharges then
                predictedCharges = currentMaxCharges
            end
        end
        if predictedCharges and currentMaxCharges and predictedCharges < currentMaxCharges
           and type(rechargeDuration) == "number" and rechargeDuration > 0 then
            rechargeStart = now -- chain next charge's timer from now
        else
            rechargeStart, rechargeDuration = nil, nil
        end
        RenderPredicted()
        UpdateChargeState() -- best-effort sync
        return
    end
    rechargeFrame:SetMinMaxValues(0, rechargeDuration)
    rechargeFrame:SetValue(elapsed)
    if rechargeText:IsShown() then
        rechargeText:SetFormattedText("%.1f", remaining)
    end
end

local function OnRechargeUpdate()
    pcall(_OnRechargeUpdateInner)
end

local function ApplyPosition(entry)
    if not frame then return end
    local target = GetAnchorTarget(entry.slot or "SECONDARY")
    if not target then frame:Hide(); return end

    local db = E.db.thingsUI.chargeBar
    local left, right = GetClusterBounds()

    frame:SetHeight(db.height or 18)

    local essential       = _G["EssentialCooldownViewer"]
    local leftAnchorFrame = essential or target

    local leftDelta, rightDelta
    if essential and left and right then
        local el = essential:GetLeft()
        if el then
            leftDelta  = left  - el
            rightDelta = right - el
        end
    end

    local xOff      = db.xOffset or 0
    local widthOff  = db.widthOffset or 0

    frame:ClearAllPoints()
    if leftDelta and rightDelta then
        local half = widthOff / 2
        frame:SetPoint("LEFT",   leftAnchorFrame, "LEFT", leftDelta  + xOff - half, 0)
        frame:SetPoint("RIGHT",  leftAnchorFrame, "LEFT", rightDelta + xOff + half, 0)
    else
        -- Fallback: cluster bounds unavailable; fall back to width math.
        local clusterWidth = target:GetWidth() or 0
        local desiredWidth = math.max(20, math.floor(clusterWidth + widthOff + 0.5))
        frame:SetWidth(desiredWidth)
        frame:SetPoint("LEFT", leftAnchorFrame, "LEFT", xOff, 0)
    end
    frame:SetPoint("BOTTOM", target, "TOP", 0, db.gap or 1)
end

local function ResolveSpellID(entry)
    if not entry then return nil end
    local raw = entry.spellID
    if type(raw) == "number" and raw > 0 then return raw end
    if type(raw) == "string" then
        local n = tonumber(raw)
        if n then return n end
        local id = C_Spell and C_Spell.GetSpellIDForSpellIdentifier and C_Spell.GetSpellIDForSpellIdentifier(raw)
        if id then return id end
    end
    return nil
end

local function HideAll()
    local wasShown = frame and frame:IsShown()
    if frame then frame:Hide() end
    rechargeStart, rechargeDuration = nil, nil
    if wasShown and TUI.InvalidateDynamicCastBarAnchor then
        TUI:InvalidateDynamicCastBarAnchor()
    end
end

local function UpdateNow()
    if not isEnabled or not playerEntered then HideAll() return end

    local entry = GetSpecEntry()
    if not entry then HideAll() return end

    local slot = entry.slot or "SECONDARY"
    if HasClassbarConflict(slot) then HideAll() return end

    local spellID = ResolveSpellID(entry)
    if not spellID then HideAll() return end

    local info = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID) or nil
    if not info then HideAll(); return end
    local okMax, mx = pcall(function() return info.maxCharges end)
    if not okMax or type(mx) ~= "number" or mx <= 1 then

        if not currentMaxCharges or currentMaxCharges <= 1 or currentSpellID ~= spellID then
            HideAll(); return
        end
        mx = currentMaxCharges
    end

    EnsureFrame()
    HookCluster() -- re-scan for newly-added trinket / essential children
    if currentSpellID ~= spellID then
        -- Spell changed (e.g. spec swap): reset prediction state.
        predictedCharges = nil
        rechargeStart, rechargeDuration = nil, nil
    end
    currentSpellID = spellID
    currentMaxCharges = mx

    pcall(function()
        local d = info.cooldownDuration
        if type(d) == "number" and d > 0 then
            cachedRechargeDuration[spellID] = d
        end
    end)

    ApplyPosition(entry)
    ApplyChargeLayout()
    ApplyVisuals(entry)
    UpdateChargeState()

    local wasShown = frame:IsShown()
    frame:Show()
    if not wasShown and TUI.InvalidateDynamicCastBarAnchor then
        TUI:InvalidateDynamicCastBarAnchor()
    end

    if rechargeStart then
        rechargeTicker:Show()
    else
        rechargeTicker:Hide()
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

rechargeTicker:SetScript("OnUpdate", function()
    if not isEnabled or not frame or not frame:IsShown() then
        rechargeTicker:Hide()
        return
    end
    OnRechargeUpdate()
end)

eventFrame:SetScript("OnEvent", function(_, event, arg1, _, arg3)
    if event == "PLAYER_ENTERING_WORLD" then
        playerEntered = true
        C_Timer.After(0.5, MarkDirty)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        C_Timer.After(0.3, MarkDirty)
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.1, MarkDirty)
    elseif event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_COOLDOWN" then
        if frame and frame:IsShown() then UpdateChargeState() end
        if frame and frame:IsShown() and rechargeStart then rechargeTicker:Show() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        -- arg3 is spellID on this event
        if currentSpellID and arg3 == currentSpellID and frame and frame:IsShown() then

            local pc = predictedCharges
            if type(pc) ~= "number" then pc = currentMaxCharges or 0 end
            if pc > 0 then pc = pc - 1 end
            predictedCharges = pc

            if not rechargeStart and currentMaxCharges and pc < currentMaxCharges then

                local dur = cachedRechargeDuration[currentSpellID]
                if not (type(dur) == "number" and dur > 0) then
                    local ok, d = pcall(function()
                        return C_Spell and C_Spell.GetSpellChargeDuration
                           and C_Spell.GetSpellChargeDuration(currentSpellID)
                    end)
                    if ok and type(d) == "number" and d > 0 then
                        dur = d
                        cachedRechargeDuration[currentSpellID] = d
                    end
                end
                if type(dur) == "number" and dur > 0 then
                    rechargeStart    = GetTime()
                    rechargeDuration = dur
                end
            end

            -- Render directly from predicted state — does not call
            RenderPredicted()
            if rechargeStart then rechargeTicker:Show() end

            -- Also try the normal API path; if it succeeds it'll sync truth.
            UpdateChargeState()
        end
    end
end)

HookCluster = function()
    local f = _G["EssentialCooldownViewer"]
    if f and not f._TUI_chargeBarHooked then
        f._TUI_chargeBarHooked = true
        f:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
    if f then
        for i = 1, f:GetNumChildren() do
            local child = select(i, f:GetChildren())
            if child and not child._TUI_chargeBarHooked then
                child._TUI_chargeBarHooked = true
                child:HookScript("OnShow", function() MarkDirty() end)
                child:HookScript("OnHide", function() MarkDirty() end)
            end
        end
    end
    local t = _G["BCDM_TrinketBar"]
    if t and not t._TUI_chargeBarHooked then
        t._TUI_chargeBarHooked = true
        t:HookScript("OnSizeChanged", function() MarkDirty() end)
        t:HookScript("OnShow",        function() MarkDirty() end)
        t:HookScript("OnHide",        function() MarkDirty() end)
    end
    if t then
        for i = 1, t:GetNumChildren() do
            local child = select(i, t:GetChildren())
            if child and not child._TUI_chargeBarHooked then
                child._TUI_chargeBarHooked = true
                child:HookScript("OnShow", function() MarkDirty() end)
                child:HookScript("OnHide", function() MarkDirty() end)
            end
        end
    end
    local p = _G["BCDM_PowerBar"]
    if p and not p._TUI_chargeBarHooked then
        p._TUI_chargeBarHooked = true
        p:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
    local sp = _G["BCDM_SecondaryPowerBar"]
    if sp and not sp._TUI_chargeBarHooked then
        sp._TUI_chargeBarHooked = true
        sp:HookScript("OnSizeChanged", function() MarkDirty() end)
        sp:HookScript("OnShow",        function() MarkDirty() end)
        sp:HookScript("OnHide",        function() MarkDirty() end)
    end
end

function TUI:UpdateChargeBar()
    local db = E.db.thingsUI.chargeBar
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
        rechargeTicker:Hide()
        HideAll()
    end
end

function CB.RequestUpdate()
    MarkDirty()
end
