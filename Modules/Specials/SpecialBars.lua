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
    wrapper:SetFrameLevel(10)
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
    ms.CreateManaged(wrapper, "TUI_SpecialBarMover_" .. barKey, displayName or ("Special Bar " .. barKey), {
        configString  = "thingsUI,modulesTab,specialBars," .. barKey .. "Group,anchorGroup",
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

local function ReleaseBar(barKey)
    local wrapper = _G["TUI_SpecialBar_" .. barKey]
    if wrapper then
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
        fx.icon:SetTexture((raw and raw.icon)
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
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        fx.bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        local c = db.customColor or { r = 0.2, g = 0.6, b = 1 }
        fx.bar:SetStatusBarColor(c.r, c.g, c.b)
    end
    fx.bar:SetValue(0.7)

    local font = LSM:Fetch("font", db.font or "Expressway")
    if db.showName then
        E:SetFont(fx.name, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        fx.name:ClearAllPoints()
        fx.name:SetPoint(db.namePoint or "LEFT", fx.bar, db.namePoint or "LEFT",
            db.nameXOffset or 2, db.nameYOffset or 0)
        fx.name:SetText(db.spellName or "Bar")
        fx.name:Show()
    else
        fx.name:Hide()
    end
    if db.showDuration then
        E:SetFont(fx.dur, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
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
        fx.fill = fx:CreateTexture(nil, "ARTWORK")
        fx.slide = fx.fill:CreateAnimationGroup()
        fx.anim = fx.slide:CreateAnimation("Scale")
        fx.anim:SetOrigin("LEFT", 0, 0)
        fx.anim:SetScaleFrom(1, 1)
        fx.anim:SetScaleTo(0, 1)
        fx.slide:SetScript("OnFinished", function() fx.fill:Hide() end)
        fx.name = fx:CreateFontString(nil, "OVERLAY")
        fx.cdText = CreateFrame("Cooldown", nil, fx, "CooldownFrameTemplate")
        fx.cdText:SetDrawSwipe(false)
        fx.cdText:SetDrawEdge(false)
        fx.cdText:SetDrawBling(false)
        fx.cdText:SetHideCountdownNumbers(false)
        wrapper.totemFX = fx
    end
    fx:SetFrameLevel(wrapper:GetFrameLevel() + 2)

    local LSM = ns.LSM
    local off = 0
    if db.iconEnabled then
        fx.iconBD:ClearAllPoints()
        fx.iconBD:SetPoint("LEFT", fx, "LEFT", 0, 0)
        fx.iconBD:SetSize(h, h)
        local raw = SB.GetRawSpellList and SB.GetRawSpellList()[db.spellID]
        fx.icon:SetTexture((raw and raw.icon)
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
    fx.fill:SetTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        fx.fill:SetVertexColor(c.r, c.g, c.b)
    else
        local c = db.customColor or { r = 0.2, g = 0.6, b = 1 }
        fx.fill:SetVertexColor(c.r, c.g, c.b)
    end
    fx.fill:ClearAllPoints()
    fx.fill:SetPoint("TOPLEFT", fx, "TOPLEFT", left, -1)
    fx.fill:SetSize(areaW * frac, math.max(1, h - 2))
    fx.slide:Stop()
    fx.anim:SetDuration(remaining)
    fx.fill:Show()
    fx.slide:Play()

    local font = LSM:Fetch("font", db.font or "Expressway")
    if db.showName then
        E:SetFont(fx.name, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
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
            E:SetFont(fs, font, db.fontSize or 12, db.fontOutline or "OUTLINE")
            fs:ClearAllPoints()
            fs:SetPoint(db.durationPoint or "RIGHT", fx, db.durationPoint or "RIGHT",
                db.durationXOffset or -4, db.durationYOffset or 0)
        end
        fx.cdText:Show()
    else
        fx.cdText:Hide()
    end
    fx:Show()
end

local function IsManagedByBarSetup(barKey)
    local bs = ns.BarSetup
    if not bs or not bs.GetActiveSetup then return false end
    local setup = bs.GetActiveSetup()
    if not (setup and setup.bars and setup.order) then return false end
    local target = "special:" .. barKey

    local inOrder = false
    for _, k in ipairs(setup.order) do
        if k == target then inOrder = true; break end
    end
    if not inOrder then return false end
    local b = setup.bars[target]
    return b ~= nil and b.enabled == true
end

local function UpdateBarSlot(barKey)
    local db = SB.GetBarDB(barKey)
    if not db.enabled or not db.spellID then ReleaseBar(barKey); return end

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
    local anchorFrame = SB.ResolveAnchorTarget(anchorName)

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
    local effectiveHeight = db.height
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

    wrapper:Show()
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

    if ns.SpecialAura then
        ns.SpecialAura.AttachBar(wrapper, barKey, db, effectiveWidth, effectiveHeight)
    end

    local TM = ns.Timers
    if db.totemTimer and db.spellID and TM and TM.RegisterTotemSpell and not test then
        TM.RegisterTotemSpell(db.spellID)
        if not SB._totemCB and TM.AddTotemCallback then
            SB._totemCB = true
            TM.AddTotemCallback(function()
                local T = ns.TUI
                if T and T.UpdateSpecialBars then T:UpdateSpecialBars() end
            end)
        end
        RenderTotemBar(wrapper, db, effectiveWidth, effectiveHeight, TM.GetTotemState(db.spellID))
    elseif wrapper.totemFX then
        wrapper.totemFX:Hide()
    end
end

SB.UpdateBarSlot = UpdateBarSlot
SB.ReleaseBar    = ReleaseBar
