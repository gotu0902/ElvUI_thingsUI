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

-- Forward declaration so UpdateNow can call HookCluster (defined later).
local HookCluster = function() end

local isDirty   = false
local isEnabled = false
local playerEntered = (IsLoggedIn and IsLoggedIn()) or false
local currentSpellID
local currentMaxCharges = 0
local rechargeStart, rechargeDuration

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

-- Returns true if classbarMode is occupying the same slot for this spec.
local function HasClassbarConflict(slot)
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
    local essential = _G["EssentialCooldownViewer"]
    if slot == "POWER" then
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

    -- Note: no SetTemplate on the root frame. Each charge segment gets its
    -- own ElvUI backdrop so gaps between segments stay transparent.

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
        -- Backdrop wrapper holds the ElvUI border; inner StatusBar is inset
        -- by E.Border so the border stays visible above the fill texture.
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
    local segW  = (barW - xGap * (n - 1)) / n
    if segW < 1 then segW = 1 end

    -- Build / position N segment status bars
    local tex = (LSM and LSM:Fetch("statusbar", db.statusBarTexture)) or E.media.blankTex
    for i = 1, n do
        local s = GetSegment(i)
        s:SetStatusBarTexture(tex)
        local wrap = s.wrap
        wrap:ClearAllPoints()
        wrap:SetPoint("LEFT", barFrame, "LEFT", (i - 1) * (segW + xGap), 0)
        wrap:SetSize(segW, barH)
        wrap:Show()
        s:Show()
    end
    ReleaseSegments(n + 1)
    activeSegmentCount = n

    -- Re-apply colors (texture / color)
    -- Done by ApplyVisuals using activeSegmentCount.

    rechargeFrame:SetWidth(segW)
    rechargeFrame:SetHeight(barH)

    -- Ticks between segments. Skip if xGap > 0 since segments are already
    -- visually separated.
    ReleaseTicks()
    if (xGap or 0) <= 0 and db.showTicks and db.tickWidth and db.tickWidth > 0 then
        local tc = db.tickColor or {}
        for i = 1, n - 1 do
            local t = GetTick(i)
            t:SetColorTexture(tc.r or 0, tc.g or 0, tc.b or 0, tc.a or 1)
            t:SetSize(db.tickWidth, barH)
            t:ClearAllPoints()
            t:SetPoint("CENTER", barFrame, "LEFT", segW * i, 0)
            t:Show()
            activeTickCount = i
        end
    end
end

local function _UpdateChargeStateInner()
    if not currentSpellID then return end
    local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(currentSpellID) or nil
    if not info then
        frame:Hide()
        return
    end

    local cur, mx = info.currentCharges, info.maxCharges
    -- During combat, when our addon execution is tainted by ElvUI (we hook
    -- UF.Configure_ClassBar in ClassbarMode), C_Spell.GetSpellCharges may
    -- return secure-tainted or nil fields. Bail out and wait for the next
    -- event after combat.
    if type(cur) ~= "number" or type(mx) ~= "number" then return end

    if mx ~= currentMaxCharges then
        currentMaxCharges = mx
        ApplyChargeLayout()
    end

    -- Fill each segment 0/1
    for i = 1, activeSegmentCount do
        local s = segmentPool[i]
        if s then s:SetValue(i <= cur and 1 or 0) end
    end

    local cdStart    = info.cooldownStartTime
    local cdDuration = info.cooldownDuration
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
        UpdateChargeState()
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
    local clusterWidth = (left and right and right > left) and (right - left) or (target:GetWidth() or 0)
    local desiredWidth = math.max(20, math.floor(clusterWidth + (db.widthOffset or 0) + 0.5))

    frame:SetWidth(desiredWidth)
    frame:SetHeight(db.height or 18)

    local essential = _G["EssentialCooldownViewer"]
    -- Anchor LEFT to essential, shift by (clusterLeft - essentialLeft) so the
    -- bar's left edge sits at the cluster's true leftmost edge (which may be
    -- a trinket child whose container has 0 width).
    local leftAnchorFrame = essential or target
    local leftDelta = 0
    if essential and left then
        local el = essential:GetLeft()
        if el then leftDelta = left - el end
    end

    frame:ClearAllPoints()
    frame:SetPoint("LEFT",   leftAnchorFrame, "LEFT", (db.xOffset or 0) + leftDelta, 0)
    frame:SetPoint("BOTTOM", target,          "TOP",  0,                              db.gap or 1)
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

    -- Verify the player actually has this spell with charges
    local info = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID) or nil
    if not info or not info.maxCharges or info.maxCharges <= 1 then
        HideAll(); return
    end

    EnsureFrame()
    HookCluster() -- re-scan for newly-added trinket / essential children
    currentSpellID = spellID
    currentMaxCharges = info.maxCharges

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

eventFrame:SetScript("OnEvent", function(_, event, arg1)
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
    end
end)

HookCluster = function()
    local f = _G["EssentialCooldownViewer"]
    if f and not f._TUI_chargeBarHooked then
        f._TUI_chargeBarHooked = true
        f:HookScript("OnSizeChanged", function() MarkDirty() end)
    end
    -- Hook each essential icon's OnShow/OnHide so we react when icons are
    -- added/removed (which changes EssentialCooldownViewer's effective width
    -- but doesn't always fire its OnSizeChanged).
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
end

function TUI:UpdateChargeBar()
    local db = E.db.thingsUI.chargeBar
    if db and db.enabled then
        isEnabled = true
        -- If the user toggles enable in-game (after PLAYER_ENTERING_WORLD
        -- already fired), the event won't fire again, so seed the flag from
        -- IsLoggedIn() here.
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
