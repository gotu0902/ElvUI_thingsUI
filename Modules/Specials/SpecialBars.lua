local addon, ns = ...
local TUI = ns.TUI
local E = ns.E
local LSM = ns.LSM

ns.SpecialBars = ns.SpecialBars or {}
local SB = ns.SpecialBars
local specialBarState = SB.specialBarState
local yoinkedBars     = SB.yoinkedBars
local ReturnFrame     = function(...) return SB.ReturnFrame(...) end

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

local _bdBar  = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bdIcon = { bgFile = nil, edgeFile = nil, edgeSize = 1 }

local function FindBarBySpell(spellID, forKey)
    return SB.FindChildBySpell(spellID, forKey, true)
end

local function BarStyleSig(db, h)
    local c = db.customColor or {}
    return table.concat({
        tostring(h), tostring(db.font), tostring(db.fontSize), tostring(db.fontOutline),
        tostring(db.showName), tostring(db.namePoint), tostring(db.nameXOffset), tostring(db.nameYOffset),
        tostring(db.showDuration), tostring(db.durationPoint), tostring(db.durationXOffset), tostring(db.durationYOffset),
        tostring(db.statusBarTexture), tostring(db.useClassColor), tostring(c.r), tostring(c.g), tostring(c.b),
        tostring(db.iconEnabled), tostring(db.iconZoom), tostring(db.iconSpacing),
        tostring(db.showStacks), tostring(db.stackFontSize), tostring(db.stackFontOutline),
        tostring(db.stackAnchor), tostring(db.stackPoint), tostring(db.stackXOffset), tostring(db.stackYOffset),
    }, "\a")
end

local function ReassertBarVisuals(childFrame, db)
    local bar, icon = childFrame.Bar, childFrame.Icon
    if not bar then return end
    if childFrame.tuiBackdrop then
        childFrame.tuiBackdrop:SetFrameLevel(math.max(childFrame:GetFrameLevel() - 1, 0))
        childFrame.tuiBackdrop:Show()
    end
    if not childFrame._tuiBarBgRegions then childFrame._tuiBarBgRegions = {} end
    for i = 1, bar:GetNumRegions() do
        local r = select(i, bar:GetRegions())
        if r and type(r.GetDrawLayer) == "function" and r:GetDrawLayer() == "BACKGROUND" then
            if childFrame._tuiBarBgRegions[r] == nil then
                childFrame._tuiBarBgRegions[r] = r:GetAlpha()
            end
            r:SetAlpha(0)
        end
    end
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip   then bar.Pip:SetAlpha(0)   end
    if bar.Name     then bar.Name:SetAlpha(db.showName and 1 or 0) end
    if bar.Duration then bar.Duration:SetAlpha(db.showDuration and 1 or 0) end
    if icon then
        if db.iconEnabled then
            icon:SetAlpha(1)
            if icon.tuiBackdrop then
                icon.tuiBackdrop:SetFrameLevel(math.max(icon:GetFrameLevel() - 1, 0))
                icon.tuiBackdrop:Show()
            end
        else
            icon:SetAlpha(0)
        end
        if icon.Applications then
            icon.Applications:SetAlpha(db.showStacks and 1 or 0)
        end
    end
end

local function StyleSpecialBar(childFrame, db, effectiveHeight)
    local bar  = childFrame.Bar
    local icon = childFrame.Icon
    if not bar then return end

    if not childFrame._tuiBarTextSaved then
        childFrame._tuiBarTextSaved = {
            nameAlpha = bar.Name and bar.Name:GetAlpha() or 1,
            durAlpha  = bar.Duration and bar.Duration:GetAlpha() or 1,
        }
    end

    local sig = BarStyleSig(db, effectiveHeight)
    if childFrame._tuiBarStyleSig == sig then
        ReassertBarVisuals(childFrame, db)
        return
    end
    childFrame._tuiBarStyleSig = sig

    if not childFrame.tuiBackdrop then
        childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        _bdBar.bgFile   = E.media.blankTex
        _bdBar.edgeFile = E.media.blankTex
        _bdBar.edgeSize = 1
        childFrame.tuiBackdrop:SetBackdrop(_bdBar)
    end
    childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.6)
    childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)

    local barOffset = 0
    if db.iconEnabled and icon then
        icon:SetScale(1)
        icon:SetSize(effectiveHeight, effectiveHeight)
        if icon.Icon then
            icon.Icon:SetScale(1)
            local z = db.iconZoom or 0.1
            icon.Icon:SetTexCoord(z, 1-z, z, 1-z)
            icon.Icon:SetDrawLayer("ARTWORK", 1)
            icon.Icon:ClearAllPoints()
            icon.Icon:SetPoint("TOPLEFT",     icon, "TOPLEFT",     1, -1)
            icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
            icon.Icon:SetDesaturated(false)
        end
        if not icon.tuiBackdrop then
            icon.tuiBackdrop = CreateFrame("Frame", nil, icon, "BackdropTemplate")
            _bdIcon.bgFile   = E.media.blankTex
            _bdIcon.edgeFile = E.media.blankTex
            _bdIcon.edgeSize = 1
            icon.tuiBackdrop:SetBackdrop(_bdIcon)
            icon.tuiBackdrop:SetBackdropColor(0, 0, 0, 1)
            icon.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        icon.tuiBackdrop:SetAllPoints(icon)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        barOffset = effectiveHeight + (db.iconSpacing or 1)
    end

    childFrame.tuiBackdrop:ClearAllPoints()
    childFrame.tuiBackdrop:SetPoint("TOPLEFT",     childFrame, "TOPLEFT",     barOffset, 0)
    childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0,         0)

    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",     childFrame.tuiBackdrop, "TOPLEFT",     1, -1)
    bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)

    local font = LSM:Fetch("font", db.font)
    if bar.Name and db.showName then
        E:SetFont(bar.Name, font, db.fontSize, db.fontOutline)
        bar.Name:ClearAllPoints()
        bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 2, db.nameYOffset or 0)
    end
    if bar.Duration and db.showDuration then
        E:SetFont(bar.Duration, font, db.fontSize, db.fontOutline)
        bar.Duration:ClearAllPoints()
        bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
    end

    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b)
    end

    if icon and icon.Applications then
        if icon.Applications.SetFont then
            E:SetFont(icon.Applications, font, db.stackFontSize or 14, db.stackFontOutline or "OUTLINE")
        end
        local stackParent = (db.stackAnchor == "BAR") and bar or icon
        if icon.Applications:GetParent() ~= stackParent then
            icon.Applications:SetParent(stackParent)
        end
        local xOff = db.stackXOffset or 0
        if db.stackAnchor == "BAR" and db.iconEnabled then
            xOff = xOff - ((effectiveHeight + (db.iconSpacing or 1)) / 2)
        end
        local appWidth = (db.stackAnchor == "BAR") and effectiveHeight or 0
        icon.Applications:SetWidth(appWidth)
        icon.Applications:SetJustifyH("CENTER")
        icon.Applications:ClearAllPoints()
        icon.Applications:SetPoint(db.stackPoint or "CENTER", stackParent, db.stackPoint or "CENTER", xOff, db.stackYOffset or 0)
    end

    ReassertBarVisuals(childFrame, db)
end

local function ReleaseBar(barKey)
    local state = specialBarState[barKey]
    if state then
        ReturnFrame(state.childFrame)
        if state.wrapper then state.wrapper:Hide() end
        specialBarState[barKey] = nil
    end

    local moverName = "TUI_SpecialBarMover_" .. barKey
    if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
end

local UpdateBarSlot

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

UpdateBarSlot = function(barKey)
    local db = SB.GetBarDB(barKey)
    if not db.enabled or not db.spellID then ReleaseBar(barKey); return end

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
            local anchorName = setup and (setup.anchorFrame or "EssentialCooldownViewer")
            local stackAnchor = anchorName
                and ((ns.CDMIcons and ns.CDMIcons.ProxyForName and ns.CDMIcons.ProxyForName(anchorName))
                     or _G[anchorName])
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

    local stHeld = specialBarState[barKey]
    local heldBar = stHeld and stHeld.childFrame
    if heldBar and not InCombatLockdown() and not SB.SafeMatch(heldBar, db.spellID, true) then
        ReturnFrame(heldBar, true)
        stHeld.childFrame = nil
        stHeld.w, stHeld.h = nil, nil
    end

    local realFrame = FindBarBySpell(db.spellID, barKey)
    local isActive  = realFrame and realFrame:IsShown()

    if isActive then
        if specialBarState[barKey] and specialBarState[barKey].childFrame ~= realFrame then
            ReturnFrame(specialBarState[barKey].childFrame)
        end
        local state = specialBarState[barKey]
        if not state then state = {}; specialBarState[barKey] = state end
        state.wrapper    = wrapper
        state.childFrame = realFrame
        state.w          = effectiveWidth
        state.h          = effectiveHeight

        realFrame._cdmOriginalParent = realFrame._cdmOriginalParent or realFrame:GetParent()
        if not realFrame._cdmOriginalW then
            realFrame._cdmOriginalW = realFrame:GetWidth()
            realFrame._cdmOriginalH = realFrame:GetHeight()
        end
        if not realFrame._cdmOriginalStrata then
            realFrame._cdmOriginalStrata = realFrame:GetFrameStrata()
            realFrame._cdmOriginalLevel  = realFrame:GetFrameLevel()
        end

        realFrame._tuiSpecialBarKey = barKey
        realFrame._tuiSpecialW, realFrame._tuiSpecialH = effectiveWidth, effectiveHeight
        yoinkedBars[realFrame] = true
        UIParent.SetFrameStrata(realFrame, wrapper:GetFrameStrata())
        UIParent.SetFrameLevel(realFrame, wrapper:GetFrameLevel() + 1)
        UIParent.ClearAllPoints(realFrame)
        UIParent.SetPoint(realFrame, "CENTER", wrapper, "CENTER", 0, 0)
        UIParent.SetSize(realFrame, effectiveWidth, effectiveHeight)

        wrapper.backdrop:Hide()
        StyleSpecialBar(realFrame, db, effectiveHeight)
        wrapper:Show()
    else
        local state = specialBarState[barKey]
        if not state then state = {}; specialBarState[barKey] = state end
        local held = state.childFrame
        if held and held._tuiSpecialBarKey ~= barKey then
            ReturnFrame(held, true)
            state.childFrame = nil
            state.w, state.h = nil, nil
        end
        state.wrapper = wrapper

        if db.showBackdrop or managedByBS then
            local bc = db.backdropColor
            wrapper.backdrop:SetBackdropColor(
                bc and bc.r or 0.1, bc and bc.g or 0.1, bc and bc.b or 0.1,
                bc and bc.a or 0.6
            )
            wrapper.backdrop:Show()
            wrapper:Show()
        else
            wrapper.backdrop:Hide()
            wrapper:Hide()
        end
    end
end

SB.UpdateBarSlot   = UpdateBarSlot
SB.ReleaseBar      = ReleaseBar
SB.StyleSpecialBar = StyleSpecialBar