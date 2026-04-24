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
    wrapper:SetFrameStrata("MEDIUM")
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

-- Separate backdrop tables per frame — SetBackdrop stores the reference, so sharing
-- a single table between two frames causes the last call to overwrite both.
local _bdBar  = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bdIcon = { bgFile = nil, edgeFile = nil, edgeSize = 1 }

local function FindBarBySpell(spellID, forKey)
    if not spellID then return nil end
    local claimed = SB.RebuildClaimedBarFrames()
    if BuffBarCooldownViewer then
        local children, childCount = SB.GetChildrenReuseFind(BuffBarCooldownViewer)
        for i = 1, childCount do
            local child = children[i]
            local owner = claimed[child]
            if (not owner or owner == forKey) and SB.SafeMatch(child, spellID, true) then
                return child
            end
        end
    end
    for child in pairs(yoinkedBars) do
        local owner = claimed[child]
        if (not owner or owner == forKey) and SB.SafeMatch(child, spellID, true) then
            return child
        end
    end
    return nil
end

local function StyleSpecialBar(childFrame, db, effectiveHeight)
    local bar  = childFrame.Bar
    local icon = childFrame.Icon
    if not bar then return end

    if not childFrame.tuiBackdrop then
        childFrame.tuiBackdrop = CreateFrame("Frame", nil, childFrame, "BackdropTemplate")
        _bdBar.bgFile   = E.media.blankTex
        _bdBar.edgeFile = E.media.blankTex
        _bdBar.edgeSize = 1
        childFrame.tuiBackdrop:SetBackdrop(_bdBar)
    end
    childFrame.tuiBackdrop:SetBackdropColor(0, 0, 0, 0.6)
    childFrame.tuiBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
    childFrame.tuiBackdrop:SetFrameLevel(childFrame:GetFrameLevel() - 1)

    local barOffset = 0
    if db.iconEnabled and icon then
        icon:SetAlpha(1)
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
        icon.tuiBackdrop:Show()
        icon.tuiBackdrop:SetAllPoints(icon)
        icon.tuiBackdrop:SetFrameLevel(icon:GetFrameLevel() - 1)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", childFrame, "LEFT", 0, 0)
        barOffset = effectiveHeight + (db.iconSpacing or 1)
    elseif icon then
        -- SetAlpha instead of Hide — icon is a CDM sub-frame.
        icon:SetAlpha(0)
    end

    childFrame.tuiBackdrop:Show()
    childFrame.tuiBackdrop:ClearAllPoints()
    childFrame.tuiBackdrop:SetPoint("TOPLEFT",     childFrame, "TOPLEFT",     barOffset, 0)
    childFrame.tuiBackdrop:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0,         0)

    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",     childFrame.tuiBackdrop, "TOPLEFT",     1, -1)
    bar:SetPoint("BOTTOMRIGHT", childFrame.tuiBackdrop, "BOTTOMRIGHT", -1, 1)

    -- Hide BACKGROUND-layer textures (CDM's BarBG + BCDM's barBackground)
    if not childFrame._tuiBarBgRegions then childFrame._tuiBarBgRegions = {} end
    for i = 1, bar:GetNumRegions() do
        local r = select(i, bar:GetRegions())
        if r and type(r.GetDrawLayer) == "function" then
            local layer = r:GetDrawLayer()
            if layer == "BACKGROUND" then
                childFrame._tuiBarBgRegions[r] = r:GetAlpha()
                r:SetAlpha(0)
            end
        end
    end

    local font = LSM:Fetch("font", db.font)
    if bar.Name then
        if db.showName then
            bar.Name:SetAlpha(1)
            bar.Name:SetFont(font, db.fontSize, db.fontOutline)
            bar.Name:ClearAllPoints()
            bar.Name:SetPoint(db.namePoint or "LEFT", bar, db.namePoint or "LEFT", db.nameXOffset or 2, db.nameYOffset or 0)
        else bar.Name:SetAlpha(0) end
    end

    if bar.Duration then
        if db.showDuration then
            bar.Duration:SetAlpha(1)
            bar.Duration:SetFont(font, db.fontSize, db.fontOutline)
            bar.Duration:ClearAllPoints()
            bar.Duration:SetPoint(db.durationPoint or "RIGHT", bar, db.durationPoint or "RIGHT", db.durationXOffset or -4, db.durationYOffset or 0)
        else bar.Duration:SetAlpha(0) end
    end

    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.statusBarTexture))
    if db.useClassColor then
        local c = E:ClassColor(E.myclass, true)
        bar:SetStatusBarColor(c.r, c.g, c.b)
    else
        bar:SetStatusBarColor(db.customColor.r, db.customColor.g, db.customColor.b)
    end
    if bar.BarBG then bar.BarBG:SetAlpha(0) end
    if bar.Pip   then bar.Pip:SetAlpha(0)   end

    if icon and icon.Applications then
        local stackFont = LSM:Fetch("font", db.font)
        if icon.Applications.SetFont then
            icon.Applications:SetFont(stackFont, db.stackFontSize or 14, db.stackFontOutline or "OUTLINE")
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
        if not db.showStacks then icon.Applications:SetAlpha(0) else icon.Applications:SetAlpha(1) end
    end
end

local function ReleaseBar(barKey)
    local state = specialBarState[barKey]
    if not state then return end
    ReturnFrame(state.childFrame)
    if state.wrapper then state.wrapper:Hide() end
    specialBarState[barKey] = nil
end

local UpdateBarSlot
UpdateBarSlot = function(barKey)
    local db = SB.GetBarDB(barKey)
    if not db.enabled or not db.spellID then ReleaseBar(barKey); return end

    local wrapper     = GetOrCreateWrapper(barKey)
    local anchorName  = (db.anchorMode ~= "CUSTOM") and db.anchorMode or db.anchorFrame
    local anchorFrame = anchorName and _G[anchorName]

    local effectiveWidth = db.width
    if db.inheritWidth and anchorFrame then
        local aw = anchorFrame:GetWidth()
        if aw and aw > 0 then effectiveWidth = aw + (db.inheritWidthOffset or 0) end
    end
    local effectiveHeight = db.height
    if db.inheritHeight and anchorFrame then
        local ah = anchorFrame:GetHeight()
        if ah and ah > 0 then effectiveHeight = ah + (db.inheritHeightOffset or 0) end
    end

    wrapper:SetSize(effectiveWidth, effectiveHeight)
    if anchorFrame then
        wrapper:ClearAllPoints()
        wrapper:SetPoint(db.anchorPoint, anchorFrame, db.anchorRelativePoint, db.anchorXOffset, db.anchorYOffset)
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
        realFrame:SetParent(wrapper)
        realFrame:ClearAllPoints()
        realFrame:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
        realFrame:SetSize(effectiveWidth, effectiveHeight)
        yoinkedBars[realFrame] = true

        wrapper.backdrop:Hide()
        StyleSpecialBar(realFrame, db, effectiveHeight)
        wrapper:Show()
    else
        if specialBarState[barKey] and specialBarState[barKey].childFrame then
            ReturnFrame(specialBarState[barKey].childFrame)
        end
        local state = specialBarState[barKey]
        if not state then state = {}; specialBarState[barKey] = state end
        state.wrapper    = wrapper
        state.childFrame = nil
        state.w          = nil
        state.h          = nil

        if db.showBackdrop then
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

SB.UpdateBarSlot = UpdateBarSlot
SB.ReleaseBar    = ReleaseBar