local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local LSM = ns.LSM
local H   = ns.CDHelpers

local kids, regions = {}, {}

ns.CDMText = ns.CDMText or {}
local M = ns.CDMText

local VIEWERS = {
    EssentialCooldownViewer = "essential",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffIcon",
}

local function GetTextDB(viewerName)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local vkey = VIEWERS[viewerName]
    local v = cdm and vkey and cdm[vkey]
    return v and v.text or nil
end

-- an icon overflowed into another row takes that row's text
local function ShownName(child)
    local CI = ns.CDMIcons
    if CI and CI.ShownIn then return CI.ShownIn(child) end
    local p = child:GetParent()
    return p and p.GetName and p:GetName()
end

local function FetchFont(name)
    if LSM then
        local p = LSM:Fetch("font", name)
        if p then return p end
    end
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- ElvUI's CDM skin makes count text ignore its parent's scale (and with it the UI and
-- icon scale): every text we style follows its icon again, like the cooldown text does
local function NormalizeScale(fs)
    if not fs.SetIgnoreParentScale then return end
    fs:SetIgnoreParentScale(false)
    fs:SetScale(1)
end

local function ApplyText(fs, font, size, outline, color, point, x, y, show)
    if not fs or not fs.SetFont then return end
    if not show then
        fs:SetAlpha(0)
        return
    end
    fs:SetAlpha(1)
    E:SetFont(fs, FetchFont(font), size or 12, outline or "OUTLINE")
    NormalizeScale(fs)
    if color then fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1) end
    if point then
        fs:ClearAllPoints()
        local parent = fs:GetParent()
        if parent then
            fs:SetPoint(point, parent, point, x or 0, y or 0)
        end
    end
end

local function ReleaseFromElvUICooldown(cd)
    if not cd or not E.RegisteredCooldowns then return end
    if E.RegisteredCooldowns[cd] then
        E.RegisteredCooldowns[cd] = nil
    end
    local mod = E.CooldownByModule and E.CooldownByModule.cdmanager
    if mod then mod[cd] = nil end
    if cd.SetCountdownFormatter then cd:SetCountdownFormatter(nil) end
end
M.ReleaseFromElvUICooldown = ReleaseFromElvUICooldown

-- Spell Editor: the viewer's text settings with one spell's overrides on top
local merged = setmetatable({}, { __mode = "k" })
local function SpellText(child, t)
    local get = ns.CDMIcons and ns.CDMIcons.SpellSettings
    local o = get and get(child)
    if not (o and next(o)) then return t end
    local byT = merged[t]
    if not byT then byT = {}; merged[t] = byT end
    local m = byT[o]
    if not m then
        m = setmetatable({}, { __index = t })
        if o.hideCooldownText then m.showCooldown = false end
        if o.cooldownFontSize and o.cooldownFontSize > 0 then m.cooldownFontSize = o.cooldownFontSize end
        if o.cooldownColor then m.cooldownColor = o.cooldownColor end
        if o.hideCount then m.showCount = false; m.showStacks = false end
        if o.countFontSize and o.countFontSize > 0 then
            m.countFontSize = o.countFontSize; m.stacksFontSize = o.countFontSize
        end
        if o.countColor then m.countColor = o.countColor; m.stacksColor = o.countColor end
        -- an own point takes its offsets as they are; without one they replace the viewer's
        if o.cooldownPoint then m.cooldownPoint = o.cooldownPoint end
        local cx = o.cooldownXOffset or (o.cooldownPoint and 0)
        local cy = o.cooldownYOffset or (o.cooldownPoint and 0)
        if cx then m.cooldownXOffset = cx end
        if cy then m.cooldownYOffset = cy end
        if o.countPoint then m.countPoint, m.stacksPoint = o.countPoint, o.countPoint end
        local nx = o.countXOffset or (o.countPoint and 0)
        local ny = o.countYOffset or (o.countPoint and 0)
        if nx then m.countXOffset, m.stacksXOffset = nx, nx end
        if ny then m.countYOffset, m.stacksYOffset = ny, ny end
        byT[o] = m
    end
    return m
end

local preview = false

-- sample cooldown and stack/charge text on top of the icon, styled like the real ones
local function PreviewText(child, t)
    local p = child._tuiPrev
    -- icons only: viewers also hold Edit Mode's selection frame
    if not preview or not (child.Cooldown or child.cooldown) then
        if p then p.layer:Hide() end
        return
    end
    if not p then
        p = { layer = CreateFrame("Frame", nil, child) }
        p.layer:SetAllPoints(child)
        p.cd = p.layer:CreateFontString(nil, "OVERLAY")
        p.count = p.layer:CreateFontString(nil, "OVERLAY")
        child._tuiPrev = p
    end
    p.layer:SetFrameLevel(child:GetFrameLevel() + 6)
    p.layer:Show()
    -- the font first: SetText errors on a fontstring without one
    E:SetFont(p.cd, FetchFont(t.cooldownFont), t.cooldownFontSize or 14, t.cooldownFontOutline or "OUTLINE")
    E:SetFont(p.count, FetchFont(t.countFont), t.countFontSize or 12, t.countFontOutline or "OUTLINE")
    p.cd:SetText("12")
    p.count:SetText("3")
    ApplyText(p.cd, t.cooldownFont, t.cooldownFontSize or 14, t.cooldownFontOutline,
        t.cooldownColor, t.cooldownPoint or "CENTER", t.cooldownXOffset, t.cooldownYOffset, t.showCooldown)
    if child:GetParent() == _G.BuffIconCooldownViewer then
        ApplyText(p.count, t.stacksFont, t.stacksFontSize, t.stacksFontOutline,
            t.stacksColor, t.stacksPoint or "BOTTOMRIGHT", t.stacksXOffset, t.stacksYOffset, t.showStacks)
    else
        ApplyText(p.count, t.countFont, t.countFontSize, t.countFontOutline,
            t.countColor, t.countPoint or "BOTTOMRIGHT", t.countXOffset, t.countYOffset, t.showCount)
    end
end

function M.SetPreview(on)
    on = on and true or false
    if preview == on then return end
    preview = on
    M.RefreshAll()
end

local function StyleChild(child, t)
    if not child then return end
    child._tuiTextSpell = ns.CDMIcons and ns.CDMIcons.ChildSpell and ns.CDMIcons.ChildSpell(child) or nil
    t = SpellText(child, t)
    child._tuiTextConfig = t

    local applications = child.Applications and child.Applications.Applications
    ApplyText(applications,
        t.stacksFont, t.stacksFontSize, t.stacksFontOutline,
        t.stacksColor, t.stacksPoint, t.stacksXOffset, t.stacksYOffset,
        t.showStacks)

    local charge = child.ChargeCount and child.ChargeCount.Current
    ApplyText(charge,
        t.countFont, t.countFontSize, t.countFontOutline,
        t.countColor, t.countPoint, t.countXOffset, t.countYOffset,
        t.showCount)

    local cd = child.Cooldown
    if cd then
        ReleaseFromElvUICooldown(cd)
        local cdText = cd.Text
        if not cdText then
            for i = 1, H.RegionsInto(cd, regions) do
                local r = regions[i]
                if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                    cdText = r
                    cd.Text = r
                    break
                end
            end
        end
        if cdText then
            if t.showCooldown then
                cd:SetHideCountdownNumbers(false)
                cdText:SetAlpha(1)
                E:SetFont(cdText, FetchFont(t.cooldownFont),
                    t.cooldownFontSize or 14, t.cooldownFontOutline or "OUTLINE")
                NormalizeScale(cdText)
                if t.cooldownColor then
                    cdText:SetTextColor(t.cooldownColor.r or 1,
                                        t.cooldownColor.g or 1,
                                        t.cooldownColor.b or 1)
                end
                if t.cooldownPoint then
                    cdText:ClearAllPoints()
                    cdText:SetPoint(t.cooldownPoint, cd, t.cooldownPoint,
                        t.cooldownXOffset or 0, t.cooldownYOffset or 0)
                end
            else
                cd:SetHideCountdownNumbers(true)
                cdText:SetAlpha(0)
            end
        end
    end
    PreviewText(child, t)
end

M.StyleChild = StyleChild

local function ReassertCountText(_, text)
    if not text or not text.GetParent then return end
    local child = text:GetParent()
    for _ = 1, 2 do
        if not child then return end
        local t = child._tuiTextConfig
        if not t then
            local vn = ShownName(child)
            if vn and VIEWERS[vn] then
                t = GetTextDB(vn)
                if t then child._tuiTextConfig = t end
            end
        end
        if t then
            if child.Applications and child.Applications.Applications == text then
                ApplyText(text, t.stacksFont, t.stacksFontSize, t.stacksFontOutline,
                    t.stacksColor, t.stacksPoint, t.stacksXOffset, t.stacksYOffset, t.showStacks)
            elseif (child.ChargeCount and child.ChargeCount.Current == text) or child.Count == text then
                ApplyText(text, t.countFont, t.countFontSize, t.countFontOutline,
                    t.countColor, t.countPoint, t.countXOffset, t.countYOffset, t.showCount)
            end
            return
        end
        child = child:GetParent()
    end
end

local hookedElvUICount, hookedElvUIViewers = false, false
local function HookElvUICountText()
    local S = E:GetModule("Skins", true)
    if not S then return end
    if not hookedElvUICount and type(S.CooldownManager_CountText) == "function" then
        hookedElvUICount = true
        hooksecurefunc(S, "CooldownManager_CountText", ReassertCountText)
    end
    -- newer ElvUI keeps CountText private; its settings refresh still runs through here
    if not hookedElvUIViewers and type(S.CooldownManager_UpdateViewers) == "function" then
        hookedElvUIViewers = true
        hooksecurefunc(S, "CooldownManager_UpdateViewers", function() M.RefreshAll() end)
    end
end
M.HookElvUICountText = HookElvUICountText

local function ApplyToViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer or not viewer.GetNumChildren then return end
    local t = GetTextDB(viewerName)
    if not t then return end

    for i = 1, H.ChildrenInto(viewer, kids) do
        local c = kids[i]
        if c and not (ns.yoinkedBars and ns.yoinkedBars[c]) then
            local shown = ShownName(c)
            StyleChild(c, (shown ~= viewerName and VIEWERS[shown] and GetTextDB(shown)) or t)
        end
    end

    local TM = ns.TimersCDM
    if TM and TM.GetInlineButtonsFor then
        local tmb = TM.GetInlineButtonsFor(viewer)
        if tmb then for i = 1, #tmb do StyleChild(tmb[i], t) end end
    end
    
    local RC = ns.RacialsCDM
    if RC and RC.GetInlineButtonsFor then
        local rcb = RC.GetInlineButtonsFor(viewer)
        if rcb then for i = 1, #rcb do StyleChild(rcb[i], t) end end
    end

    local TR = ns.TrinketsCDM
    if TR and TR.GetInlineButtonsFor then
        local trb = TR.GetInlineButtonsFor(viewer)
        if trb then for i = 1, #trb do StyleChild(trb[i], t) end end
    end
end

local function OnViewerRefresh(viewer)
    ApplyToViewer(viewer:GetName())
end

-- Blizzard re-uses a frame for another spell without a full refresh
function M.SyncChild(child)
    local sid = ns.CDMIcons and ns.CDMIcons.ChildSpell and ns.CDMIcons.ChildSpell(child)
    if child._tuiTextSpell == sid then return end
    local vn = ShownName(child)
    local t = vn and VIEWERS[vn] and GetTextDB(vn)
    if t then StyleChild(child, t) end
end

function M.RefreshAll()
    wipe(merged)
    HookElvUICountText()
    for name in pairs(VIEWERS) do
        ns.ViewerHooks.On(name, "RefreshLayout", "CDMText", OnViewerRefresh)
        ApplyToViewer(name)
    end
end

local refreshQueued = false
function M.QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function() refreshQueued = false; M.RefreshAll() end)
end

function TUI:UpdateCDMText()
    M.RefreshAll()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
boot:SetScript("OnEvent", function()
    for _, t in ipairs({ 0.5, 1.0, 2.0, 4.0 }) do
        C_Timer.After(t, M.RefreshAll)
    end
end)
