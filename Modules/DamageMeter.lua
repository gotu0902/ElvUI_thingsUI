local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.DamageMeterSkin = ns.DamageMeterSkin or {}
local M = ns.DamageMeterSkin

local LSM = E.Libs and E.Libs.LSM

local function DB() return E.db.thingsUI and E.db.thingsUI.damageMeter end
local function Native() return _G.DamageMeter and _G.DamageMeter.ForEachSessionWindow end
local function Active()
    local db = DB()
    return Native() and db and db.provider == "BLIZZARD"
end

local function FontFlag(db)
    local f = db.fontOutline or "OUTLINE"
    if f == "NONE" then return "" end
    return f
end

local function StyleFS(fs, font, size, flag, shadow)
    if not fs then return end
    if font then fs:SetFont(font, size, flag) end
    if shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowColor(0, 0, 0, 0)
    end
end

local function StyleEntry(entry)
    local db = DB()
    if not (entry and db and db.styleBars and Active()) then return end
    local sb = entry.StatusBar
    local font = LSM and LSM:Fetch("font", db.font or "Expressway")
    local flag = FontFlag(db)
    if sb then
        StyleFS(sb.Name,  font, db.fontSize or 12, flag, db.fontShadow)
        StyleFS(sb.Value, font, db.valueFontSize or db.fontSize or 12, flag, db.fontShadow)
        if db.barTexture and db.barTexture ~= "" and LSM and sb.GetStatusBarTexture then
            local tex = LSM:Fetch("statusbar", db.barTexture)
            local t = sb:GetStatusBarTexture()
            if tex and t then t:SetTexture(tex) end
        end
    end
    local icon = entry.Icon
    if icon then
        if db.iconBorder then
            local b = entry._tuiIconBorder
            if not b then
                b = CreateFrame("Frame", nil, icon, "BackdropTemplate")
                entry._tuiIconBorder = b
            end
            local s = db.iconBorderSize or 1
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", icon, "TOPLEFT", -s, s)
            b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", s, -s)
            b:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8x8]], edgeSize = s })
            local c = db.iconBorderColor or {}
            b:SetBackdropBorderColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
            b:SetShown(icon:IsShown())
        elseif entry._tuiIconBorder then
            entry._tuiIconBorder:Hide()
        end
        if db.barLayout and sb then
            local style = _G.DamageMeter.GetStyle and _G.DamageMeter:GetStyle()
            local THIN = Enum.DamageMeterStyle and Enum.DamageMeterStyle.Thin
            if not THIN or style ~= THIN then
                local xoff = icon:IsShown() and ((icon:GetWidth() or 24) + (db.iconGap or 4)) or 0
                sb:ClearAllPoints()
                sb:SetPoint("TOPLEFT", entry, "TOPLEFT", xoff, 0)
                sb:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
end

local function ApplyWindowChrome(win)
    local db = DB()
    if not (win and db and Active()) then return end
    local font = LSM and LSM:Fetch("font", db.font or "Expressway")
    local flag = FontFlag(db)
    if db.styleBars and font then
        StyleFS(win.SessionTimer, font, db.headerFontSize or 12, flag, db.fontShadow)
        local tn = win.DamageMeterTypeDropdown and win.DamageMeterTypeDropdown.TypeName
        StyleFS(tn, font, db.headerFontSize or 12, flag, db.fontShadow)
    end
    if win.SettingsDropdown then win.SettingsDropdown:SetShown(not db.hideGearMenu) end
end

local suspended = false
local function Panel() return _G.RightChatPanel end
local function AnchorActive()
    return Active() and E.db.thingsUI and E.db.thingsUI.rightChatAsBackground and Panel()
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function ReapplyAnchor()
    if suspended or not AnchorActive() then return end
    local dm = _G.DamageMeter
    local p = Panel()
    if not (dm and dm.SetPointBase and dm.ClearAllPointsBase and p) then return end
    local db = DB()
    local pad = 4
    local gap = db.windowGap or 4
    local w2 = _G.DamageMeterSessionWindow2
    local two = w2 and w2:IsShown()
    local pw = (p:GetWidth() or 0) - pad * 2
    local ph = (p:GetHeight() or 0) - pad * 2
    if pw < 50 or ph < 50 then return end
    local w = two and ((pw - gap) / 2) or pw
    w  = Clamp(math.floor(w), 200, 600)
    local h = Clamp(math.floor(ph), 120, 400)
    dm:ClearAllPointsBase()
    dm:SetPointBase("TOPLEFT", p, "TOPLEFT", pad, -pad)
    dm:SetSize(w, h)
    if two then
        w2:ClearAllPoints()
        w2:SetPoint("TOPLEFT", dm, "TOPRIGHT", gap, 0)
        w2:SetSize(w, h)
    end
end

function M.RestyleAll()
    if not Native() then return end
    _G.DamageMeter:ForEachSessionWindow(function(win)
        ApplyWindowChrome(win)
        local sb = win.GetScrollBox and win:GetScrollBox()
        if sb and sb.ForEachFrame then sb:ForEachFrame(StyleEntry) end
        local lpe = win.GetLocalPlayerEntry and win:GetLocalPlayerEntry()
        if lpe then StyleEntry(lpe) end
    end)
end

local hookedWindows = {}
local function HookWindow(win)
    if not win or hookedWindows[win] then return end
    hookedWindows[win] = true
    if win.SetupEntry then hooksecurefunc(win, "SetupEntry", function(_, entry) StyleEntry(entry) end) end
    if win.InitEntry then hooksecurefunc(win, "InitEntry", function(_, entry) StyleEntry(entry) end) end
    if win.ShowLocalPlayerEntry then
        hooksecurefunc(win, "ShowLocalPlayerEntry", function(w)
            local e = w.GetLocalPlayerEntry and w:GetLocalPlayerEntry()
            if e then StyleEntry(e) end
        end)
    end
    if win.SetMinimized then hooksecurefunc(win, "SetMinimized", function(w) ApplyWindowChrome(w) end) end
    ApplyWindowChrome(win)
end

local reapplyQueued = false
local function QueueReapply()
    if reapplyQueued then return end
    reapplyQueued = true
    C_Timer.After(0, function() reapplyQueued = false; ReapplyAnchor() end)
end

local hooked = false
local function InstallHooks()
    if hooked or not Native() then return end
    hooked = true
    local dm = _G.DamageMeter

    hooksecurefunc(dm, "SetupSessionWindow", function(_, idx)
        HookWindow(_G["DamageMeterSessionWindow" .. (idx or 1)])
        QueueReapply()
    end)
    if dm.ApplySystemAnchor then hooksecurefunc(dm, "ApplySystemAnchor", QueueReapply) end
    if dm.RefreshLayout then
        hooksecurefunc(dm, "RefreshLayout", function()
            M.RestyleAll()
            QueueReapply()
        end)
    end

    local emm = _G.EditModeManagerFrame
    if emm then
        hooksecurefunc(emm, "EnterEditMode", function()
            suspended = true
            -- park on UIParent so an edit-mode save never serializes our panel anchor
            local f = _G.DamageMeter
            if AnchorActive() and f and f.SetPointBase then
                local l, t, uh = f:GetLeft(), f:GetTop(), UIParent:GetHeight()
                if l and t and uh then
                    f:ClearAllPointsBase()
                    f:SetPointBase("TOPLEFT", UIParent, "TOPLEFT", l, t - uh)
                end
            end
        end)
        hooksecurefunc(emm, "ExitEditMode", function()
            suspended = false
            C_Timer.After(0.1, ReapplyAnchor)
        end)
    end

    local p = Panel()
    if p then
        hooksecurefunc(p, "SetWidth",  QueueReapply)
        hooksecurefunc(p, "SetHeight", QueueReapply)
    end

    dm:ForEachSessionWindow(function(win) HookWindow(win) end)
end

function TUI:UpdateDamageMeter()
    if not Active() then return end
    InstallHooks()
    M.RestyleAll()
    ReapplyAnchor()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, function() TUI:UpdateDamageMeter() end)
end)
