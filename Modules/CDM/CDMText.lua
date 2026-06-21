local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local LSM = ns.LSM

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

local function FetchFont(name)
    if LSM then
        local p = LSM:Fetch("font", name)
        if p then return p end
    end
    return _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function ApplyText(fs, font, size, outline, color, point, x, y, show)
    if not fs or not fs.SetFont then return end
    if not show then
        fs:SetAlpha(0)
        return
    end
    fs:SetAlpha(1)
    E:SetFont(fs, FetchFont(font), size or 12, outline or "OUTLINE")
    if color then fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1) end
    if point then
        fs:ClearAllPoints()
        local parent = fs:GetParent()
        if parent then
            fs:SetPoint(point, parent, point, x or 0, y or 0)
        end
    end
end

-- Detach the Cooldown frame from ElvUI's cdmanager so its CooldownUpdate stops re-styling text.
local function ReleaseFromElvUICooldown(cd)
    if not cd or not E.RegisteredCooldowns then return end
    if E.RegisteredCooldowns[cd] then
        E.RegisteredCooldowns[cd] = nil
    end
    local mod = E.CooldownByModule and E.CooldownByModule.cdmanager
    if mod and mod[cd] then mod[cd] = nil end
end
M.ReleaseFromElvUICooldown = ReleaseFromElvUICooldown

local function StyleChild(child, t)
    if not child then return end
    child._tuiTextConfig = t  -- remember our config so the ElvUI re-assert hook can restore it

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
            for i = 1, cd:GetNumRegions() do
                local r = select(i, cd:GetRegions())
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
end

M.StyleChild = StyleChild

local function ReassertCountText(_, text)
    if not text or not text.GetParent then return end
    local child = text:GetParent()
    for _ = 1, 2 do
        if not child then return end
        local t = child._tuiTextConfig
        if t then
            if child.Applications and child.Applications.Applications == text then
                ApplyText(text, t.stacksFont, t.stacksFontSize, t.stacksFontOutline,
                    t.stacksColor, t.stacksPoint, t.stacksXOffset, t.stacksYOffset, t.showStacks)
            elseif child.ChargeCount and child.ChargeCount.Current == text then
                ApplyText(text, t.countFont, t.countFontSize, t.countFontOutline,
                    t.countColor, t.countPoint, t.countXOffset, t.countYOffset, t.showCount)
            end
            return
        end
        child = child:GetParent()
    end
end

local hookedElvUICount = false
local function HookElvUICountText()
    if hookedElvUICount then return end
    local S = E:GetModule("Skins", true)
    if not S or type(S.CooldownManager_CountText) ~= "function" then return end
    hookedElvUICount = true
    hooksecurefunc(S, "CooldownManager_CountText", ReassertCountText)
end
M.HookElvUICountText = HookElvUICountText

local function ApplyToViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer or not viewer.GetNumChildren then return end
    local t = GetTextDB(viewerName)
    if not t then return end

    local n = viewer:GetNumChildren()
    for i = 1, n do
        local c = select(i, viewer:GetChildren())
        if c then
            StyleChild(c, t)
        end
    end

    local TR = ns.TrinketsCDM
    if TR and TR.GetInlineButtonsFor then
        local tb = TR.GetInlineButtonsFor(viewer)
        if tb then for i = 1, #tb do StyleChild(tb[i], t) end end
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
end

local hookedViewers = {}
local function HookViewerRefresh(viewerName)
    if hookedViewers[viewerName] then return end
    local viewer = _G[viewerName]
    if not viewer or type(viewer.RefreshLayout) ~= "function" then return end
    hookedViewers[viewerName] = true
    hooksecurefunc(viewer, "RefreshLayout", function()
        ApplyToViewer(viewerName)
    end)
end

function M.RefreshAll()
    HookElvUICountText()
    for name in pairs(VIEWERS) do
        HookViewerRefresh(name)
        ApplyToViewer(name)
    end
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
