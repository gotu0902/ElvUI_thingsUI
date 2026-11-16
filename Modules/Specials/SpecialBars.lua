local addon, ns = ...
local TUI = ns.TUI
local E = ns.E

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local specialBarState = SB.specialBarState

local function GetOrCreateWrapper(barKey)
    local name    = "TUI_SpecialBar_" .. barKey
    local wrapper = _G[name] or CreateFrame("Frame", name, UIParent)
    local db = SB.GetBarDB(barKey)
    wrapper:SetFrameStrata((db and db.frameStrata) or "MEDIUM")
    wrapper:SetFrameLevel((db and db.frameLevel) or 10)
    if not wrapper.backdrop then
        local bd = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
        bd:SetAllPoints(wrapper)
        bd:SetFrameLevel(wrapper:GetFrameLevel())
        bd:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        bd:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        bd:SetBackdropBorderColor(0, 0, 0, 0.8)
        bd:Hide()
        wrapper.backdrop = bd
    end
    return wrapper
end

local _moverCreated = {}

local function EnsureMover(wrapper, barKey, displayName)
    if _moverCreated[barKey] then return end
    local ms = ns.MoverSync
    if not (ms and ms.CreateManaged) then return end
    ms.CreateManaged(wrapper, "TUI_SpecialBarMover_" .. barKey, displayName or ("Aura Bar " .. barKey), {
        configString  = "thingsUI,modulesTab,specialBars,barsTab," .. barKey .. "Group,anchorGroup",
        shouldDisable = function() return not (E.db.thingsUI and E.db.thingsUI.specialBars) end,
        onSave = function(point, relPoint, x, y)
            local db = SB.GetBarDB(barKey)
            if not db then return end
            db.anchorPoint = point
            db.anchorRelativePoint = relPoint
            db.anchorXOffset = x
            db.anchorYOffset = y
            ns.NotifyChange()
        end,
        onNudge = function(dx, dy)
            ms.ShiftOffsets(SB.GetBarDB(barKey), dx, dy)
            TUI:QueueSpecialBarsUpdate()
            ns.NotifyChange()
        end,
    })
    _moverCreated[barKey] = true
end

local function HideBarMover(barKey)
    local wrapper = _G["TUI_SpecialBar_" .. barKey]
    if ns.MoverSync and ns.MoverSync.RemoveManaged then
        ns.MoverSync.RemoveManaged("TUI_SpecialBarMover_" .. barKey, wrapper)
    elseif wrapper then
        wrapper:Hide()
    end
end
SB.HideBarMover = HideBarMover

local function HideTicks(layer)
    if not layer then return end
    for _, tex in ipairs(layer.ticks) do tex.ag:Stop(); tex:Hide() end
    layer:Hide()
end

-- ticks live on the wrapper: in combat an aura button can't be touched while its aura is secret
local function PaintTicks(wrapper, db, w, h)
    local TM = ns.Timers
    local list, tdur
    if TM and TM.GetTotemCasts then list, tdur = TM.GetTotemCasts(db.spellID) end
    local layer = wrapper.tickFX
    if not (list and tdur and #list > 0) then HideTicks(layer); return end
    if not layer then
        layer = CreateFrame("Frame", nil, wrapper)
        layer:SetAllPoints(wrapper)
        layer.ticks = {}
        wrapper.tickFX = layer
    end
    layer:SetFrameLevel(wrapper._tuiTickLevel or (wrapper:GetFrameLevel() + 4))
    local left = (db.iconEnabled and (h + (db.iconSpacing or 1)) or 0) + 1
    local areaW = math.max(1, w - left - 1)
    local rev = db.reverseFill and true or false
    local tc = db.totemTickColor or { r = 1, g = 1, b = 1, a = 1 }
    local tw = db.totemTickThickness or 2
    local tlen = math.min(db.totemTickLength or (h - 2), h - 2)
    local now = GetTime()
    local shown = 0
    for _, t in ipairs(list) do
        local rem = (t + tdur) - now
        local x = areaW * (rem / tdur)
        if rem > 0 and x <= areaW then
            shown = shown + 1
            local tex = layer.ticks[shown]
            if not tex then
                tex = layer:CreateTexture(nil, "OVERLAY")
                tex.ag = tex:CreateAnimationGroup()
                tex.move = tex.ag:CreateAnimation("Translation")
                tex.ag:SetScript("OnFinished", function() tex:Hide() end)
                layer.ticks[shown] = tex
            end
            tex:SetColorTexture(tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)
            tex.ag:Stop()
            tex:ClearAllPoints()
            if rev then
                tex:SetPoint("RIGHT", layer, "RIGHT", -1 - x, 0)
            else
                tex:SetPoint("LEFT", layer, "LEFT", left + x, 0)
            end
            tex:SetSize(tw, tlen)
            tex.move:SetOffset(rev and x or -x, 0)
            tex.move:SetDuration(rem)
            tex:Show()
            tex.ag:Play()
        end
    end
    for i = shown + 1, #layer.ticks do layer.ticks[i].ag:Stop(); layer.ticks[i]:Hide() end
    layer:SetShown(shown > 0)
end

-- Fill By Stacks over a placeholder: the piece lines live on the wrapper, so they stay while the
-- aura is gone (without a placeholder the aura's own bar draws them)
local function PaintStackLines(wrapper, db, w, h, test, placeholder)
    local SA = ns.SpecialAura
    local n = SA and SA.StackCount(db)
    local layer = wrapper.segFX
    -- the options preview draws its own
    wrapper._tuiStackLines = (n and placeholder and not test and not db.totemTimer) and true or nil
    if not wrapper._tuiStackLines then
        if layer then layer:Hide() end
        return
    end
    if not layer then
        layer = CreateFrame("Frame", nil, wrapper)
        wrapper.segFX = layer
    end
    layer:SetFrameLevel(wrapper._tuiTickLevel or (wrapper:GetFrameLevel() + 4))
    local left = (db.iconEnabled and (h + (db.iconSpacing or 1)) or 0) + 1
    layer:ClearAllPoints()
    layer:SetPoint("TOPLEFT", wrapper, "TOPLEFT", left, -1)
    layer:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", -1, 1)
    SA.PaintSegments(layer, math.max(1, w - left - 1), n, db.stackGap or 1)
    layer:Show()
end

local function ReleaseBar(barKey)
    local wrapper = _G["TUI_SpecialBar_" .. barKey]
    if wrapper then
        HideTicks(wrapper.tickFX)
        if wrapper.segFX then wrapper.segFX:Hide() end
        if ns.SpecialAura then ns.SpecialAura.Detach(wrapper, barKey) end
        wrapper.backdrop:Hide()
        if wrapper.testFX then wrapper.testFX:Hide() end
        if wrapper.totemFX then wrapper.totemFX:Hide() end
        wrapper:Hide()
    end
    specialBarState[barKey] = nil

    local moverName = "TUI_SpecialBarMover_" .. barKey
    if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
end

local function RenderTestBar(wrapper, db, w, h)
    local fx = wrapper.testFX
    if not fx then
        fx = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
        fx:SetAllPoints(wrapper)
        fx:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        fx:SetBackdropColor(0, 0, 0, 0.6)
        fx:SetBackdropBorderColor(0, 0, 0, 1)
        fx.iconBD = CreateFrame("Frame", nil, fx, "BackdropTemplate")
        fx.iconBD:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
        fx.iconBD:SetBackdropColor(0, 0, 0, 1)
        fx.iconBD:SetBackdropBorderColor(0, 0, 0, 1)
        fx.icon = fx.iconBD:CreateTexture(nil, "ARTWORK")
        fx.bar = CreateFrame("StatusBar", nil, fx)
        fx.bar:SetMinMaxValues(0, 1)
        fx.name = fx.bar:CreateFontString(nil, "OVERLAY")
        fx.dur = fx.bar:CreateFontString(nil, "OVERLAY")
        fx.stacks = fx.bar:CreateFontString(nil, "OVERLAY")
        wrapper.testFX = fx
    end
    fx:SetFrameLevel(wrapper:GetFrameLevel() + 2)

    local LSM = ns.LSM
    local off = 0
    if db.iconEnabled then
        fx.iconBD:ClearAllPoints()
        fx.iconBD:SetPoint("LEFT", fx, "LEFT", 0, 0)
        fx.iconBD:SetSize(h, h)
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        fx.icon:SetTexture(db.customIcon or (raw and raw.icon)
            or (db.spellID and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID)) or 134400)
        local z = db.iconZoom or 0.1
        fx.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        fx.icon:ClearAllPoints()
        fx.icon:SetPoint("TOPLEFT", fx.iconBD, "TOPLEFT", 1, -1)
        fx.icon:SetPoint("BOTTOMRIGHT", fx.iconBD, "BOTTOMRIGHT", -1, 1)
        fx.iconBD:Show()
        off = h + (db.iconSpacing or 1)
    else
        fx.iconBD:Hide()
    end

    fx.bar:ClearAllPoints()
    fx.bar:SetPoint("TOPLEFT", fx, "TOPLEFT", off + 1, -1)
    fx.bar:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", -1, 1)
    fx.bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    fx.bar:SetReverseFill(db.reverseFill and true or false)
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        fx.bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        local c = db.customColor or { r = 0.2, g = 0.6, b = 1 }
        fx.bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    ns.SpecialAura.PreviewFill(fx.bar, db, w - off - 2)

    local font = LSM:Fetch("font", db.font or "Expressway")
    if db.showName then
        E:SetFont(fx.name, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(fx.name, db.nameColor)
        fx.name:ClearAllPoints()
        fx.name:SetPoint(db.namePoint or "LEFT", fx.bar, db.namePoint or "LEFT",
            db.nameXOffset or 2, db.nameYOffset or 0)
        fx.name:SetText(db.spellName or "Bar")
        fx.name:Show()
    else
        fx.name:Hide()
    end
    if db.showDuration then
        E:SetFont(fx.dur, font, db.durationFontSize or db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(fx.dur, db.durationColor)
        fx.dur:ClearAllPoints()
        fx.dur:SetPoint(db.durationPoint or "RIGHT", fx.bar, db.durationPoint or "RIGHT",
            db.durationXOffset or -4, db.durationYOffset or 0)
        fx.dur:SetText("12")
        fx.dur:Show()
    else
        fx.dur:Hide()
    end
    if db.showStacks then
        E:SetFont(fx.stacks, font, db.stackFontSize or 14, db.stackFontOutline or "OUTLINE")
        ns.TextColor(fx.stacks, db.stackColor)
        fx.stacks:ClearAllPoints()
        local anchorTo = (db.stackAnchor == "BAR" or not db.iconEnabled) and fx.bar or fx.iconBD
        fx.stacks:SetPoint(db.stackPoint or "CENTER", anchorTo, db.stackPoint or "CENTER",
            db.stackXOffset or 0, db.stackYOffset or 0)
        fx.stacks:SetText("3")
        fx.stacks:Show()
    else
        fx.stacks:Hide()
    end
    fx:Show()
end

local function CooldownText(cd)
    if cd._tuiText then return cd._tuiText end
    for _, r in ipairs({ cd:GetRegions() }) do
        if r:GetObjectType() == "FontString" then cd._tuiText = r; return r end
    end
end
SB.CooldownText = CooldownText

local function NormalColor(db)
    if db.useClassColor then return E:ClassColor(E.myclass, true) end
    return db.customColor or { r = 0.2, g = 0.6, b = 1 }
end

local function EnsureTotemFX(wrapper)
    local fx = wrapper.totemFX
    if fx then return fx end
    fx = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
    fx:SetAllPoints(wrapper)
    fx:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
    fx:SetBackdropColor(0, 0, 0, 0.6)
    fx:SetBackdropBorderColor(0, 0, 0, 1)
    fx.iconBD = CreateFrame("Frame", nil, fx, "BackdropTemplate")
    fx.iconBD:SetBackdrop({ bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1 })
    fx.iconBD:SetBackdropColor(0, 0, 0, 1)
    fx.iconBD:SetBackdropBorderColor(0, 0, 0, 1)
    fx.icon = fx.iconBD:CreateTexture(nil, "ARTWORK")
    fx.fill = fx:CreateTexture(nil, "ARTWORK")
    fx.slide = fx.fill:CreateAnimationGroup()
    fx.anim = fx.slide:CreateAnimation("Scale")
    fx.anim:SetOrigin("LEFT", 0, 0)
    fx.anim:SetScaleFrom(1, 1)
    fx.anim:SetScaleTo(0, 1)
    fx.slide:SetScript("OnFinished", function() fx.fill:Hide() end)
    fx.top = CreateFrame("Frame", nil, fx)
    fx.top:SetAllPoints(fx)
    fx.name = fx.top:CreateFontString(nil, "OVERLAY")
    fx.cdText = CreateFrame("Cooldown", nil, fx, "CooldownFrameTemplate")
    fx.cdText:SetDrawSwipe(false)
    fx.cdText:SetDrawEdge(false)
    fx.cdText:SetDrawBling(false)
    fx.cdText:SetHideCountdownNumbers(false)
    fx:Hide()
    wrapper.totemFX = fx
    return fx
end

-- While Missing a Buff. A buff on you can't be read in combat, so the bar draws its MISSING
-- look itself (color, text) and the game draws the normal bar over it while the buff is up:
-- two aura frames, a cover for the whole bar and the fill clipped to the time left
local CAN_COND = C_DurationUtil and C_DurationUtil.CreateDuration and Enum.StatusBarTimerDirection
    and Enum.StatusBarInterpolation and true or false
local COND_KEY = "TUICond"
local COND_BG = { r = 0.03, g = 0.03, b = 0.03 }
local condPending = false
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function()
        if not condPending then return end
        condPending = false
        TUI:QueueSpecialBarsUpdate()
    end)
end

local function CondOff(wrapper, fx)
    wrapper._tuiTickLevel = nil
    if not (fx and fx._cond) then return end
    fx._cond = nil
    fx.drv:Hide()
    fx.cover:Hide()
    fx.clip:Hide()
    fx.condText:Hide()
end

local function CondLook(button, t, look)
    -- the layout only places a frame, its size is ours to set
    button:SetSize(look.w, look.h)
    t:SetTexture(look.tex)
    t:SetVertexColor(look.c.r, look.c.g, look.c.b)
end

-- one aura frame for the buff, drawn as a plain colored block; false = retry out of combat
local function CondLayer(fx, field, parent, id, look, pt, anchor, ox, oy)
    local c = fx[field]
    if not c then
        c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        c._tex = {}
        fx[field] = c
    end
    c._look = look
    c:ClearAllPoints()
    c:SetSize(look.w, look.h)
    c:SetPoint(pt, anchor, pt, ox, oy)
    c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    c:SetFlowLayoutAnchorPoint(pt)
    c:SetFlowLayoutGrowthDirection(pt == "TOPRIGHT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down)
    if c.SetFlowLayoutPadding then c:SetFlowLayoutPadding(0, 0, 0, 0) end
    -- this ID alone: the bar's own spell shares its name
    local filter = "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
    local cf = { includeSpellIDs = { [id] = true } }
    local layout = { elementWidth = look.w, elementHeight = look.h, elementSpacing = 0, lineSpacing = 0 }
    if c:HasAuraGroup(COND_KEY) then
        ns.SetAuraGroupCap(c, COND_KEY, 1)
        c:SetAuraGroupFilterString(COND_KEY, filter)
        c:SetAuraGroupCandidateFilters(COND_KEY, cf)
        c:SetAuraGroupLayout(COND_KEY, layout)
    else
        c:AddAuraGroup(COND_KEY, filter, {
            maxFrameCount = 1,
            candidateFilters = cf,
            layout = layout,
            initializeFrame = function(button)
                button:SetMouseMotionEnabled(false)
                local t = button:CreateTexture(nil, "ARTWORK")
                t:SetAllPoints(button)
                c._tex[button] = t
                CondLook(button, t, c._look)
            end,
        })
    end
    local ok = true
    for button, t in pairs(c._tex) do
        -- a frame showing a secret aura denies access, also just outside combat
        if not pcall(CondLook, button, t, look) then ok = false end
    end
    if not c._unit then c:SetUnit("player"); c._unit = "player" end
    if c.UpdateAllAuras then c:UpdateAllAuras() end
    c:Show()
    return ok
end

-- our own frames (any time) and, out of combat, the aura frames for the buff
local function CondPrepare(wrapper, db, w, h)
    local fx = wrapper.totemFX
    if not (db.condBuff and CAN_COND) then CondOff(wrapper, fx) return end
    fx = EnsureTotemFX(wrapper)
    if not fx.drv then
        fx.drv = CreateFrame("StatusBar", nil, fx)
        fx.drv:SetMinMaxValues(0, 1)
        fx.dur = C_DurationUtil.CreateDuration()
        fx.mid = CreateFrame("Frame", nil, fx)
        fx.mid:SetAllPoints(fx)
        fx.condText = fx.mid:CreateFontString(nil, "OVERLAY")
        -- off the wrapper: an aura frame refuses a parent chain that takes input
        fx.cover = CreateFrame("Frame", nil, UIParent)
        fx.clip = CreateFrame("Frame", nil, UIParent)
        fx.clip:SetClipsChildren(true)
        fx.cover:Hide()
        fx.clip:Hide()
        fx:HookScript("OnHide", function() fx.cover:Hide(); fx.clip:Hide() end)
        fx:HookScript("OnShow", function()
            if fx._cond then fx.cover:Show(); fx.clip:Show() end
        end)
    end
    fx._cond = true

    local LSM = ns.LSM
    local left = (db.iconEnabled and (h + (db.iconSpacing or 1)) or 0) + 1
    local areaW, barH = math.max(1, w - left - 1), math.max(1, h - 2)
    local rev = db.reverseFill and true or false
    local tex = LSM:Fetch("statusbar", db.statusBarTexture)
    local lvl = wrapper:GetFrameLevel() + 2
    local strata = wrapper:GetFrameStrata() or "MEDIUM"
    local d = fx.drv
    d:SetFrameLevel(lvl + 1)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", fx, "TOPLEFT", left, -1)
    d:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", -1, 1)
    d:SetStatusBarTexture(tex)
    d:SetReverseFill(rev)
    local mc = db.condColorOn and (db.condColor or { r = 1, g = 0.3, b = 0.3 }) or NormalColor(db)
    d:SetStatusBarColor(mc.r, mc.g, mc.b)

    fx.mid:SetFrameLevel(lvl + 2)
    local ct = fx.condText
    if db.condText and db.condText ~= "" then
        E:SetFont(ct, LSM:Fetch("font", db.font or "Expressway"), db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(ct, db.nameColor)
        ct:ClearAllPoints()
        ct:SetPoint(db.namePoint or "LEFT", fx, db.namePoint or "LEFT", (db.nameXOffset or 2) + left, db.nameYOffset or 0)
        ct:SetText(db.condText)
        ct:Show()
    else
        ct:Hide()
    end

    local cover, clip = fx.cover, fx.clip
    cover:SetFrameStrata(strata)
    cover:SetFrameLevel(lvl + 3)
    cover:ClearAllPoints()
    cover:SetPoint("TOPLEFT", d, "TOPLEFT", -1, 1)
    cover:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 1, -1)
    clip:SetFrameStrata(strata)
    clip:SetFrameLevel(lvl + 6)
    -- the game's fill lands a pixel inside the bar's start: both reach one further out
    local one = (ns.Pixel.Size and ns.Pixel.Size(fx)) or 1
    local st = d:GetStatusBarTexture()
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", st, "TOPLEFT", rev and 0 or -one, 0)
    clip:SetPoint("BOTTOMRIGHT", st, "BOTTOMRIGHT", rev and one or 0, 0)
    -- ticks ride over the game's fill
    wrapper._tuiTickLevel = lvl + 9

    local nc = NormalColor(db)
    local sig = table.concat({ db.condBuff, areaW, barH, one, tostring(rev), tostring(tex), nc.r, nc.g, nc.b }, "|")
    if fx._condSig == sig then return end
    if InCombatLockdown() then condPending = true return end
    fx._condSig = sig
    local pt = rev and "TOPRIGHT" or "TOPLEFT"
    -- the cover hides the missing look, a pixel over each edge
    local a = CondLayer(fx, "condBG", cover, db.condBuff,
        { tex = E.media.blankTex, c = COND_BG, w = areaW + 2, h = barH + 2 }, pt, cover, 0, 0)
    local b = CondLayer(fx, "condC", clip, db.condBuff,
        { tex = tex, c = nc, w = areaW + one, h = barH }, pt, d, rev and one or -one, 0)
    if not (a and b) then fx._condSig = nil; condPending = true end
end

local function RenderTotemBar(wrapper, db, w, h, start, dur)
    local fx = wrapper.totemFX
    if not start then
        if fx then fx:Hide() end
        return
    end
    local remaining = start + dur - GetTime()
    if remaining <= 0 then
        if fx then fx:Hide() end
        return
    end
    fx = EnsureTotemFX(wrapper)
    local lvl = wrapper:GetFrameLevel() + 2
    fx:SetFrameLevel(lvl)
    fx.top:SetFrameLevel(lvl + 10)
    fx.cdText:SetFrameLevel(lvl + 11)

    local LSM = ns.LSM
    local off = 0
    if db.iconEnabled then
        fx.iconBD:ClearAllPoints()
        fx.iconBD:SetPoint("LEFT", fx, "LEFT", 0, 0)
        fx.iconBD:SetSize(h, h)
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        fx.icon:SetTexture(db.customIcon or (raw and raw.icon)
            or (db.spellID and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(db.spellID)) or 134400)
        local z = db.iconZoom or 0.1
        fx.icon:SetTexCoord(z, 1 - z, z, 1 - z)
        fx.icon:ClearAllPoints()
        fx.icon:SetPoint("TOPLEFT", fx.iconBD, "TOPLEFT", 1, -1)
        fx.icon:SetPoint("BOTTOMRIGHT", fx.iconBD, "BOTTOMRIGHT", -1, 1)
        fx.iconBD:Show()
        off = h + (db.iconSpacing or 1)
    else
        fx.iconBD:Hide()
    end

    local left = off + 1
    local areaW = math.max(1, w - left - 1)
    local frac = math.min(1, remaining / dur)
    local rev = db.reverseFill and true or false
    fx.slide:Stop()
    if fx._cond then
        -- the missing look runs on the game's clock, the clip follows its edge
        fx.fill:Hide()
        fx.dur:SetTimeFromStart(start, dur)
        fx.drv:SetTimerDuration(fx.dur, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
        fx.drv:Show()
        -- the buff ends a moment before the bar goes: no missing text in that gap
        local stamp = start + dur
        fx._condEnd = stamp
        C_Timer.After(math.max(0, remaining - 0.5), function()
            if fx._condEnd == stamp then fx.condText:Hide() end
        end)
    else
        fx.fill:SetTexture(LSM:Fetch("statusbar", db.statusBarTexture))
        local c = NormalColor(db)
        fx.fill:SetVertexColor(c.r, c.g, c.b)
        fx.fill:ClearAllPoints()
        if rev then
            fx.fill:SetPoint("TOPRIGHT", fx, "TOPRIGHT", -1, -1)
        else
            fx.fill:SetPoint("TOPLEFT", fx, "TOPLEFT", left, -1)
        end
        fx.anim:SetOrigin(rev and "RIGHT" or "LEFT", 0, 0)
        fx.fill:SetSize(areaW * frac, math.max(1, h - 2))
        fx.anim:SetDuration(remaining)
        fx.fill:Show()
        fx.slide:Play()
    end

    local font = LSM:Fetch("font", db.font or "Expressway")
    -- a missing text takes the name's place
    if db.showName and not (fx._cond and db.condText and db.condText ~= "") then
        E:SetFont(fx.name, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        ns.TextColor(fx.name, db.nameColor)
        fx.name:ClearAllPoints()
        fx.name:SetPoint(db.namePoint or "LEFT", fx, db.namePoint or "LEFT",
            (db.nameXOffset or 2) + left, db.nameYOffset or 0)
        fx.name:SetText(db.spellName or (C_Spell.GetSpellName and C_Spell.GetSpellName(db.spellID)) or "Bar")
        fx.name:Show()
    else
        fx.name:Hide()
    end
    if db.showDuration then
        fx.cdText:ClearAllPoints()
        fx.cdText:SetAllPoints(fx)
        fx.cdText:SetCooldown(start, dur)
        local fs = CooldownText(fx.cdText)
        if fs then
            E:SetFont(fs, font, db.durationFontSize or db.fontSize or 12, db.fontOutline or "OUTLINE")
            ns.TextColor(fs, db.durationColor)
            fs:ClearAllPoints()
            fs:SetPoint(db.durationPoint or "RIGHT", fx, db.durationPoint or "RIGHT",
                db.durationXOffset or -4, db.durationYOffset or 0)
        end
        fx.cdText:Show()
    else
        fx.cdText:Hide()
    end
    fx:Show()
    if fx._cond then
        local vis = fx:IsVisible()
        fx.cover:SetShown(vis)
        fx.clip:SetShown(vis)
    end
end

local function IsManagedByBarSetup(barKey)
    local bs = ns.BarSetup
    return bs.UsesKey(bs.GetActiveSetup(), "special:" .. barKey)
end

-- a Bar Setup bar takes its place's height (Bar Setup > Height by Position), else its own
function SB.StackHeight(barKey, db)
    db = db or SB.GetBarDB(barKey)
    local BS = ns.BarSetup
    return (BS and BS.PositionHeight and BS.PositionHeight("special:" .. barKey)) or db.height or 0
end

-- visibility rules for standalone and Bar Setup bars; a grouped bar follows its group's
local function VisibleNow(db)
    if ns.CustomGroups and ns.CustomGroups.testMode then return ns.Visibility.PreviewShown(db.visibility) end
    return ns.Visibility.Shown(db.visibility)
end

local function Restack()
    local BS = ns.BarSetup
    if not BS then return end
    if InCombatLockdown() then
        if BS.PositionStack then BS.PositionStack(true) end
    elseif BS.ApplyStack then
        BS.ApplyStack()
    end
end

function SB.RefreshBarVisibility()
    local changed = false
    for i = 1, (SB.GetBarCount and SB.GetBarCount() or 0) do
        local key = "bar" .. i
        local db = SB.GetBarDB(key)
        local wrapper = _G["TUI_SpecialBar_" .. key]
        local gid = db and db.customGroup
        local g = type(gid) == "number" and gid > 0 and ns.CustomBars and ns.CustomBars.GroupByID
            and ns.CustomBars.GroupByID(gid)
        if wrapper and db and db.enabled and db.spellID and not g and SB.SpellLearned(db.spellID) then
            local want = VisibleNow(db) and true or false
            if wrapper:IsShown() ~= want then wrapper:SetShown(want); changed = true end
        end
    end
    if changed then Restack() end
end
ns.Visibility.OnChange(function() SB.RefreshBarVisibility() end)

local learnedState = {}

local function UpdateBarSlot(barKey)
    local db = SB.GetBarDB(barKey)
    if not db.enabled or not db.spellID then ReleaseBar(barKey); return end

    -- talented out: the bar goes, and a Bar Setup stack closes up
    local learned = SB.SpellLearned(db.spellID)
    if learnedState[barKey] ~= nil and learnedState[barKey] ~= learned and IsManagedByBarSetup(barKey) then
        C_Timer.After(0, Restack)
    end
    learnedState[barKey] = learned
    if not learned then ReleaseBar(barKey); return end

    local cbGroup = db.customGroup and ns.CustomBars and ns.CustomBars.GroupByID(db.customGroup)
    if cbGroup and not cbGroup.enabled then cbGroup = nil end
    if cbGroup then
        ReleaseBar(barKey)
        if TUI.QueueCustomBarsUpdate then TUI:QueueCustomBarsUpdate() end
        return
    end

    local wrapper     = GetOrCreateWrapper(barKey)
    local managedByBS = IsManagedByBarSetup(barKey)

    local anchorName  = (db.anchorMode ~= "CUSTOM") and db.anchorMode or db.anchorFrame
    local anchorFrame = SB.ResolveAnchorTarget(anchorName, wrapper)

    local cdmInset = (anchorName == "EssentialCooldownViewer"
        or anchorName == "UtilityCooldownViewer"
        or anchorName == "BuffIconCooldownViewer") and 2 or 0
    local effectiveWidth
    if managedByBS then
        effectiveWidth = wrapper:GetWidth()
        if not effectiveWidth or effectiveWidth < 1 then effectiveWidth = db.width or 200 end
    else
        effectiveWidth = db.width
        if db.inheritWidth and anchorFrame then
            local aw = anchorFrame:GetWidth()
            if aw and aw > 0 then effectiveWidth = aw + cdmInset + (db.inheritWidthOffset or 0) end
        end
    end
    local effectiveHeight = managedByBS and SB.StackHeight(barKey, db) or db.height
    if db.inheritHeight and anchorFrame and not managedByBS then
        local ah = anchorFrame:GetHeight()
        if ah and ah > 0 then effectiveHeight = ah + cdmInset + (db.inheritHeightOffset or 0) end
    end

    wrapper:SetSize(effectiveWidth, effectiveHeight)

    local moverName = "TUI_SpecialBarMover_" .. barKey
    if not _moverCreated[barKey] then
        wrapper:ClearAllPoints()
        if managedByBS then

            local bs = ns.BarSetup
            local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
            local stackName = setup and (setup.anchorFrame or "EssentialCooldownViewer")
            local stackAnchor = stackName
                and ((ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(stackName))
                     or _G[stackName])
            if stackAnchor then
                wrapper:SetPoint("BOTTOM", stackAnchor, "TOP", 0, 0)
            else
                wrapper:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        elseif anchorFrame then
            wrapper:SetPoint(db.anchorPoint or "CENTER", anchorFrame, db.anchorRelativePoint or "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
        else
            wrapper:SetPoint("CENTER", UIParent, "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
        end
    elseif not managedByBS then
        wrapper:ClearAllPoints()
        if anchorFrame and anchorFrame ~= UIParent then
            wrapper:SetPoint(db.anchorPoint or "CENTER", anchorFrame, db.anchorRelativePoint or "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
        else
            local mv = _G[moverName]
            if mv then
                wrapper:SetPoint("CENTER", mv, "CENTER", 0, 0)
            else
                wrapper:SetPoint(db.anchorPoint or "CENTER", UIParent, db.anchorRelativePoint or "CENTER", db.anchorXOffset or 0, db.anchorYOffset or 0)
            end
        end
    end

    local moverNum = barKey:match("(%d+)$") or ""
    EnsureMover(wrapper, barKey, "SB" .. moverNum)

    if managedByBS and ns.BarSetup and ns.BarSetup.ApplyStack then
        ns.BarSetup.ApplyStack()
    end

    wrapper:SetShown(VisibleNow(db) and true or false)
    if E and E.DisabledMovers and E.DisabledMovers[moverName] and E.EnableMover then
        E:EnableMover(moverName)
    end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end

    local mover = _G[moverName]
    if mover and anchorFrame and not managedByBS and not (ns.MoverSync and ns.MoverSync.IsDragging(moverName)) then
        local point = db.anchorPoint or "CENTER"
        local relPoint = db.anchorRelativePoint or "CENTER"
        local x, y = db.anchorXOffset or 0, db.anchorYOffset or 0
        local cp, crf, crp, cx, cy = mover:GetPoint()

        local same = cp == point and crp == relPoint
            and crf == anchorFrame
            and cx and math.abs(cx - x) < 0.5
            and cy and math.abs(cy - y) < 0.5
        if not same then
            mover:ClearAllPoints()
            mover:SetPoint(point, anchorFrame, relPoint, x, y)

            local anchorHasName = anchorFrame.GetName and anchorFrame:GetName()
            if E.SaveMoverPosition and anchorHasName then
                E:SaveMoverPosition(moverName)
            end
        end
    end

    local state = specialBarState[barKey]
    if not state then state = {}; specialBarState[barKey] = state end
    state.wrapper = wrapper

    local test = ns.CustomGroups and ns.CustomGroups.testMode
    if test then
        RenderTestBar(wrapper, db, effectiveWidth, effectiveHeight)
    elseif wrapper.testFX then
        wrapper.testFX:Hide()
    end
    if db.showBackdrop or managedByBS or test then
        local bc = db.backdropColor
        wrapper.backdrop:SetBackdropColor(
            bc and bc.r or 0.1, bc and bc.g or 0.1, bc and bc.b or 0.1,
            bc and bc.a or 0.6
        )
        wrapper.backdrop:Show()
    else
        wrapper.backdrop:Hide()
    end

    PaintStackLines(wrapper, db, effectiveWidth, effectiveHeight, test, db.showBackdrop or managedByBS)
    if ns.SpecialAura then
        -- a timer bar is the whole bar: no aura bar under it
        if db.totemTimer and not test then ns.SpecialAura.Detach(wrapper, barKey)
        else ns.SpecialAura.AttachBar(wrapper, barKey, db, effectiveWidth, effectiveHeight) end
    end

    local TM = ns.Timers
    if (db.totemTimer or db.totemTicks) and db.spellID and TM and TM.RegisterTotemSpell and not test then
        TM.RegisterTotemSpell(db.spellID)
        if not SB._totemCB and TM.AddTotemCallback then
            SB._totemCB = true
            TM.AddTotemCallback(SB.OnTotemChange)
        end
        if db.totemTimer then
            CondPrepare(wrapper, db, effectiveWidth, effectiveHeight)
            RenderTotemBar(wrapper, db, effectiveWidth, effectiveHeight, TM.GetTotemState(db.spellID))
        elseif wrapper.totemFX then
            wrapper.totemFX:Hide()
        end
        if db.totemTicks then PaintTicks(wrapper, db, effectiveWidth, effectiveHeight) else HideTicks(wrapper.tickFX) end
    else
        if wrapper.totemFX then wrapper.totemFX:Hide() end
        HideTicks(wrapper.tickFX)
    end
end

-- a tracked cast or totem change: only the slots that show one, ticks alone just repaint
function SB.OnTotemChange()
    if not (E.db.thingsUI and E.db.thingsUI.specialBars) then return end
    local test = ns.CustomGroups and ns.CustomGroups.testMode
    for i = 1, (SB.GetBarCount and SB.GetBarCount() or 0) do
        local key = "bar" .. i
        local db = SB.GetBarDB(key)
        if db and db.enabled and db.spellID then
            if db.totemTimer then
                UpdateBarSlot(key)
            elseif db.totemTicks and not test then
                local wrapper = specialBarState[key] and specialBarState[key].wrapper
                if wrapper then
                    local w, h = wrapper:GetSize()
                    PaintTicks(wrapper, db, w, h)
                end
            end
        end
    end
    local updateIcon = SB.UpdateIconSlot
    if not updateIcon then return end
    for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
        local key = "icon" .. i
        local db = SB.GetIconDB(key)
        if db and db.enabled and db.spellID and db.totemTimer then updateIcon(key) end
    end
end

SB.UpdateBarSlot = UpdateBarSlot
SB.ReleaseBar    = ReleaseBar
