local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.MoverSync = ns.MoverSync or {}
local M = ns.MoverSync

local ShortAnchor

local TARGETS = {
    {
        moverName = "ElvUF_PlayerMover",
        frame     = function() return _G.ElvUF_Player end,
        baseLabel = "Player Frame",
        tag       = function()
            local cp = E.db.thingsUI and E.db.thingsUI.clusterPositioning
            if cp and cp.enabled and cp.playerFrame and cp.playerFrame.enabled then
                return "|cFF888888(Cluster)|r"
            end
        end,
    },
    {
        moverName = "ElvUF_TargetMover",
        frame     = function() return _G.ElvUF_Target end,
        baseLabel = "Target Frame",
        tag       = function()
            local cp = E.db.thingsUI and E.db.thingsUI.clusterPositioning
            if cp and cp.enabled and cp.targetFrame and cp.targetFrame.enabled then
                return "|cFF888888(Cluster)|r"
            end
        end,
    },
    {
        moverName = "ElvUF_TargetTargetMover",
        frame     = function() return _G.ElvUF_TargetTarget end,
        baseLabel = "TargetTarget Frame",
        tag       = function()
            local cp = E.db.thingsUI and E.db.thingsUI.clusterPositioning
            if cp and cp.enabled and cp.targetTargetFrame and cp.targetTargetFrame.enabled then
                return "|cFF888888(Cluster)|r"
            end
        end,
    },
    {
        moverName = "ElvUF_TargetCastbarMover",
        frame     = function()
            local t = _G.ElvUF_Target
            local cb = t and t.Castbar
            return cb and (cb.Holder or cb)
        end,
        baseLabel = "Target Castbar",
        tag       = function()
            local cp = E.db.thingsUI and E.db.thingsUI.clusterPositioning
            if cp and cp.enabled and cp.targetCastBar and cp.targetCastBar.enabled then
                return "|cFF888888(Cluster)|r"
            end
        end,
    },
    {
        moverName = "ElvUI_thingsUI_ChargeBarMover",
        frame     = function() return _G.ElvUI_thingsUI_ChargeBar end,
        baseLabel = "thingsUI Charge Bar",
        tag       = function()
            if ns.BarSetup and not ns.BarSetup.IsActive() then
                local af = E.db.thingsUI and E.db.thingsUI.chargeBar
                              and E.db.thingsUI.chargeBar.anchorFrame
                if af and af ~= "UIParent" then
                    return "|cFFFFAA00(Anchor: "..ShortAnchor(af)..")|r"
                end
                return nil
            end
            local CB = ns.ChargeBar

            if CB and CB.IsNHTForCurrentSpec and CB.IsNHTForCurrentSpec() then
                return "|cFF888888(Bar Setup)|r"
            end

            if CB and CB.GetConfiguredMode and CB.GetConfiguredMode() == "FHT" then
                local af = E.db.thingsUI.chargeBar.anchorFrame
                if af and af ~= "UIParent" then
                    return "|cFFFFAA00(Anchor: "..ShortAnchor(af)..")|r"
                end
            end
        end,

        hide = function()
            local CB = ns.ChargeBar
            if not CB then return false end
            if CB.IsActiveForCurrentSpec and CB.IsActiveForCurrentSpec() then
                return false
            end

            local mode = CB.GetConfiguredMode and CB.GetConfiguredMode()
            return mode ~= "FHT"
        end,
    },

    {
        moverName = "TUI_TrinketBarMover",
        frame     = function() return _G.TUI_TrinketBar end,
        baseLabel = "thingsUI Trinket Bar",
        tag       = function()
            local td = E.db.thingsUI and E.db.thingsUI.trinketsCDM
            local af = td and td.bar and td.bar.anchorFrame
            if af and af ~= "UIParent" and af ~= "" then
                return "|cFFFFAA00(Anchor: " .. ShortAnchor(af) .. ")|r"
            end
        end,
        hide = function()
            local td = E.db.thingsUI and E.db.thingsUI.trinketsCDM
            return not (td and td.enabled and (td.mode or "EMBEDDED") == "BAR")
        end,
    },
    {
        moverName = "TUI_UtilityMover",
        frame     = function()
            local v = _G.UtilityCooldownViewer
            return (v and ns.CDMIcons and ns.CDMIcons.GetProxy and ns.CDMIcons.GetProxy(v)) or v
        end,
        baseLabel = "Utility Cooldowns",
        alwaysSync = true,
        tag       = function()
            local u = E.db.thingsUI and E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.utility
            if not (u and u.anchorEnabled) then return nil end
            local af = u.anchorFrame
            if af == "EssentialCooldownViewer" then return "|cFF888888(Cluster)|r" end
            if af and af ~= "UIParent" and af ~= "" then
                return "|cFFFFAA00(Anchor: " .. ShortAnchor(af) .. ")|r"
            end
        end,
        hide = function()
            local u = E.db.thingsUI and E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.utility
            return not (u and u.anchorEnabled)
        end,
    },
    {
        moverName = "ElvUF_PlayerCastbarMover",
        frame     = function()
            local p = _G.ElvUF_Player
            local cb = p and p.Castbar
            return cb and (cb.Holder or cb)
        end,
        baseLabel = "Player Castbar",
        tag       = function()
            if ns.BarSetup and not ns.BarSetup.IsActive() then return nil end
            local bs = ns.BarSetup and ns.BarSetup.GetActiveSetup and ns.BarSetup.GetActiveSetup()
            local b  = bs and bs.bars and bs.bars.castbar
            if b and b.enabled and (b.mode or "NHT") == "NHT" then
                return "|cFF888888(Bar Setup)|r"
            end
        end,
    },
    {
        moverName = "ClassBarMover",
        frame     = function()
            local p = _G.ElvUF_Player
            return p and p.ClassBarHolder
        end,
        baseLabel = "Class Bar",
        tag       = function()
            if ns.BarSetup and not ns.BarSetup.IsActive() then return nil end
            local CM = ns.ClassbarMode
            if CM and CM.IsNHTForCurrentSpec and CM.IsNHTForCurrentSpec() then
                return "|cFF888888(Bar Setup)|r"
            end
        end,
        hide = function()
            local bs = ns.BarSetup and ns.BarSetup.GetActiveSetup and ns.BarSetup.GetActiveSetup()
            local b  = bs and bs.bars and bs.bars.classbar
            if b and b.enabled and b.mode == "ATTACHED" then
                return true
            end
        end,
    },
    {
        moverName = "PlayerPowerBarMover",
        frame     = function()
            local p = _G.ElvUF_Player
            local pw = p and p.Power
            return pw and pw.Holder
        end,
        baseLabel = "Player Powerbar",
        tag       = function()
            if ns.BarSetup and not ns.BarSetup.IsActive() then return nil end
            local bs = ns.BarSetup and ns.BarSetup.GetActiveSetup and ns.BarSetup.GetActiveSetup()
            local b  = bs and bs.bars and bs.bars.power
            if b and b.enabled and (b.mode or "NHT") == "NHT" then
                return "|cFF888888(Bar Setup)|r"
            end
        end,
        hide = function()
            local bs = ns.BarSetup and ns.BarSetup.GetActiveSetup and ns.BarSetup.GetActiveSetup()
            local b  = bs and bs.bars and bs.bars.power
            if b and b.enabled and b.mode == "ATTACHED" then
                return true
            end
        end,
    },
}

local function SyncMoverToFrame(mover, frame)
    if not (mover and frame and frame.GetLeft) then return end
    local fl, fb = frame:GetLeft(), frame:GetBottom()
    if not fl or not fb then return end
    local w, h = frame:GetSize()
    if not w or w <= 0 or not h or h <= 0 then return end

    local anchorParent = frame:GetParent() or _G.UIParent

    while anchorParent and anchorParent ~= _G.UIParent
          and anchorParent ~= _G.WorldFrame do
        anchorParent = anchorParent:GetParent()
        if not anchorParent then break end
    end
    anchorParent = anchorParent or _G.UIParent

    local fScale = (frame.GetEffectiveScale  and frame:GetEffectiveScale())  or 1
    local aScale = (anchorParent.GetEffectiveScale and anchorParent:GetEffectiveScale()) or 1
    if aScale == 0 then aScale = 1 end
    local k = fScale / aScale
    mover:ClearAllPoints()
    mover:SetSize(w, h)
    mover:SetPoint("BOTTOMLEFT", anchorParent, "BOTTOMLEFT", fl * k, fb * k)
end

local function SetMoverLock(mover, locked)
    if not mover then return end
    if not mover._tuiLockHooked then
        mover._tuiLockHooked = true
        local origStart = mover:GetScript("OnDragStart")
        mover:SetScript("OnDragStart", function(self, ...)
            if self._tuiLocked then return end
            if origStart then return origStart(self, ...) end
        end)
    end
    mover._tuiLocked = locked and true or nil
end

local SHORT_ANCHOR = {
    ElvUF_Player                = "Player",
    ElvUF_Player_CastBar        = "Player Cast",
    ElvUF_Target_CastBar        = "Target Cast",
    ElvUF_Target                = "Target",
    ElvUF_TargetTarget          = "ToT",
    ElvUF_Pet                   = "Pet",
    ElvUF_Focus                 = "Focus",
    EssentialCooldownViewer     = "Essential",
    UtilityCooldownViewer       = "Utility",
    BuffIconCooldownViewer      = "BuffIcons",
    BuffBarCooldownViewer       = "BuffBars",
    BARSETUP_TOP                = "BarSetup",
    UIParent                    = "UIParent",
}
function ShortAnchor(name)
    return SHORT_ANCHOR[name] or name
end

local function EnsureConfigMode()
    if not E then return end
    if E.ConfigMode_AddGroup then
        E:ConfigMode_AddGroup("THINGSUI", "thingsUI")
        return
    end
    if not E.ConfigModeLayouts then return end
    for _, v in ipairs(E.ConfigModeLayouts) do
        if v == "THINGSUI" then return end
    end
    table.insert(E.ConfigModeLayouts, "THINGSUI")
    if E.ConfigModeLocalizedStrings then
        E.ConfigModeLocalizedStrings.THINGSUI = "thingsUI"
    end
end
M.EnsureConfigMode = EnsureConfigMode

local _moverSession = false
function M.ToggleMover()
    if not (E and E.ToggleMoveMode) or InCombatLockdown() then return end
    if E.ConfigurationMode then
        E:ToggleMoveMode()
    else
        _moverSession = true
        E:ToggleMoveMode("THINGSUI")
    end
end

if E and E.ToggleMoveMode and not M._moverHook then
    M._moverHook = true
    hooksecurefunc(E, "ToggleMoveMode", function()

        if ns.TimersStandalone and ns.TimersStandalone.Refresh then ns.TimersStandalone.Refresh() end
        if _moverSession and not E.ConfigurationMode then
            _moverSession = false
            if E.ToggleOptions then E:ToggleOptions("thingsUI") end
        end
    end)
end

local nudgeHandlers = {}
function M.RegisterNudge(moverName, fn)
    if moverName and type(fn) == "function" then nudgeHandlers[moverName] = fn end
end
if E and E.NudgeMover and not M._nudgeHook then
    M._nudgeHook = true
    hooksecurefunc(E, "NudgeMover", function(_, x, y)
        local mover = E.MoverNudgeFrame and E.MoverNudgeFrame.child
        local fn = mover and mover.name and nudgeHandlers[mover.name]
        if fn then fn(mover, x, y) end
    end)
end

local _managedDragging = {}
local _managedCreated  = {}

function M.IsDragging(moverName)
    return _managedDragging[moverName] == true
end

function M.CreateManaged(frame, moverName, label, opts)
    if not (E and E.CreateMover and frame and moverName) then return _G[moverName] end
    if _managedCreated[moverName] then return _G[moverName] end
    opts = opts or {}
    EnsureConfigMode()

    local function save(self)
        if not opts.onSave then return end
        local point, _, relPoint, x, y = self:GetPoint()
        if point and x and y then
            opts.onSave(point, relPoint or point, math.floor(x + 0.5), math.floor(y + 0.5))
        end
    end

    E:CreateMover(frame, moverName, label or moverName, nil, nil,
        function(self)
            if not _managedDragging[moverName] then return end
            _managedDragging[moverName] = nil
            save(self)
        end,
        "ALL,THINGSUI", opts.shouldDisable, opts.configString, opts.ignoreSizeChanged)

    local mv = _G[moverName]
    if mv and not mv._tuiDragHooked then
        mv._tuiDragHooked = true
        mv:HookScript("OnDragStart", function() _managedDragging[moverName] = true end)
    end
    -- Anchored movers nudge their anchor offset (onNudge); others save absolute (save).
    M.RegisterNudge(moverName, function(self, nx, ny)
        if opts.onNudge then opts.onNudge(nx or 0, ny or 0) else save(self) end
    end)

    _managedCreated[moverName] = true
    return mv
end

function M.RemoveManaged(moverName, frame)
    if E and E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
    if frame and frame.Hide then frame:Hide() end
    _managedDragging[moverName] = nil
end

function M.SetManagedEnabled(moverName, enabled)
    if not (moverName and E) then return end
    if enabled then
        if E.DisabledMovers and E.DisabledMovers[moverName] and E.EnableMover then E:EnableMover(moverName) end
    elseif E.CreatedMovers and E.CreatedMovers[moverName] and E.DisableMover then
        E:DisableMover(moverName)
    end
end

local TUI_BORDER = { 0.5, 0.5, 1 }
local function ColorMover(moverName)
    local m = _G[moverName]
    if m and m.SetBackdropBorderColor then
        m:SetBackdropBorderColor(TUI_BORDER[1], TUI_BORDER[2], TUI_BORDER[3])
    end
end

local syncing = false
function M.SyncAll()
    if syncing then return end
    syncing = true
    EnsureConfigMode()

    for _, t in ipairs(TARGETS) do
        local mover = _G[t.moverName]
        local frame = t.frame and t.frame()
        if mover then

            local shouldHide = t.hide and t.hide() or false
            if shouldHide then
                if E and E.DisableMover and E.CreatedMovers and E.CreatedMovers[t.moverName] then
                    E:DisableMover(t.moverName)
                end
            else
                if E and E.EnableMover and E.DisabledMovers and E.DisabledMovers[t.moverName] then
                    E:EnableMover(t.moverName)
                end

                local tag = t.tag and t.tag()
                if frame and (tag or t.alwaysSync) then
                    SyncMoverToFrame(mover, frame)
                end
                if mover.text and mover.text.SetText then
                    local label = t.baseLabel
                    if tag then label = label .. " " .. tag end
                    mover.text:SetText(label)
                end
                SetMoverLock(mover, tag ~= nil)
            end
        end
    end

    local SB = ns.SpecialBars
    local barCount  = (SB and SB.GetBarCount  and SB.GetBarCount())  or 0
    local iconCount = (SB and SB.GetIconCount and SB.GetIconCount()) or 0
    local bs   = ns.BarSetup
    local setup = bs and bs.GetActiveSetup and bs.GetActiveSetup()
    local inOrder = {}
    if setup and setup.order then
        for _, k in ipairs(setup.order) do inOrder[k] = true end
    end

    for i = 1, barCount do
        local mover = _G["TUI_SpecialBarMover_bar" .. i]
        if mover then
            local key   = "special:bar" .. i
            local db    = SB and SB.GetBarDB and SB.GetBarDB("bar" .. i) or nil
            local label = string.format("SB%d", i)
            local lock  = false
            local inBarSetup = false
            if inOrder[key] then
                label = label .. " |cFFFF6666(Bar Setup)|r"
                lock  = true
                inBarSetup = true
            elseif db then
                local anchorName = (db.anchorMode and db.anchorMode ~= "CUSTOM")
                    and db.anchorMode or db.anchorFrame
                if anchorName and anchorName ~= "UIParent" and anchorName ~= "" then
                    label = label .. " |cFFFFAA00(" .. ShortAnchor(anchorName) .. ")|r"
                    lock  = true
                end
            end
            if mover.text and mover.text.SetText then mover.text:SetText(label) end
            SetMoverLock(mover, lock)

            if inBarSetup then
                local wrapper = _G["TUI_SpecialBar_bar" .. i]
                if wrapper then
                    SyncMoverToFrame(mover, wrapper)
                end
            end
        end
    end
    for i = 1, iconCount do
        local mover = _G["TUI_SpecialIconMover_icon" .. i]
        if mover then
            local db    = SB and SB.GetIconDB and SB.GetIconDB("icon" .. i) or nil
            local label = string.format("SI%d", i)
            local lock  = false
            if db then
                local anchorName = (db.anchorMode and db.anchorMode ~= "CUSTOM")
                    and db.anchorMode or db.anchorFrame
                if anchorName and anchorName ~= "UIParent" and anchorName ~= "" then
                    label = label .. " |cFFFFAA00(" .. ShortAnchor(anchorName) .. ")|r"
                    lock  = true
                end
            end
            if mover.text and mover.text.SetText then mover.text:SetText(label) end
            SetMoverLock(mover, lock)
        end
    end

    local CGm = ns.CustomGroups
    local cgGroups = (CGm and CGm.GetGroups and CGm.GetGroups()) or {}
    for _, g in ipairs(cgGroups) do
        local mname = "TUI_CustomGroupMover" .. g.id
        local mover = _G[mname]
        if mover then
            if not g.enabled then
                if E.DisableMover and E.CreatedMovers and E.CreatedMovers[mname] then E:DisableMover(mname) end
            else
                if E.EnableMover and E.DisabledMovers and E.DisabledMovers[mname] then E:EnableMover(mname) end
                local af = g.anchorFrame
                local lock, label = false, (g.name or "Custom Group")
                if af and af ~= "UIParent" and af ~= "" then
                    label = label .. " |cFFFFAA00(Anchor: " .. ShortAnchor(af) .. ")|r"
                    lock = true
                end
                local frame = _G["TUI_CustomGroup" .. g.id]
                if frame then SyncMoverToFrame(mover, frame) end
                if mover.text and mover.text.SetText then mover.text:SetText(label) end
                SetMoverLock(mover, lock)
            end
            ColorMover(mname)
        end
    end

    if E.CreatedMovers then
        local live, orphans = {}, {}
        for _, g in ipairs(cgGroups) do live[tostring(g.id)] = true end
        for mname in pairs(E.CreatedMovers) do
            local id = mname:match("^TUI_CustomGroupMover(%d+)$")
            if id and not live[id] then orphans[#orphans + 1] = { mname, id } end
        end
        for _, o in ipairs(orphans) do M.RemoveManaged(o[1], _G["TUI_CustomGroup" .. o[2]]) end
    end

    local Tm = ns.Timers
    local timers = (Tm and Tm.GetTimers and Tm.GetTimers()) or {}
    for _, t in ipairs(timers) do
        if t.destination == "standalone" then
            local mname = "TUI_TimerStandaloneMover" .. t.id
            local mover = _G[mname]
            if mover then
                if not t.enabled then
                    if E.DisableMover and E.CreatedMovers and E.CreatedMovers[mname] then E:DisableMover(mname) end
                else
                    if E.EnableMover and E.DisabledMovers and E.DisabledMovers[mname] then E:EnableMover(mname) end
                    local af = t.anchorFrame
                    local lock = af and af ~= "UIParent" and af ~= ""
                    if lock and mover.text and mover.text.SetText then
                        mover.text:SetText("Timer (Anchor: " .. ShortAnchor(af) .. ")")
                    end
                    local frame = _G["TUI_TimerStandalone" .. t.id]
                    if frame then SyncMoverToFrame(mover, frame) end
                    SetMoverLock(mover, lock and true or false)
                end
                ColorMover(mname)
            end
        end
    end

    ColorMover("TUI_EssentialMover")
    ColorMover("TUI_UtilityMover")
    ColorMover("TUI_TrinketBarMover")
    ColorMover("ElvUI_thingsUI_ChargeBarMover")
    for i = 1, barCount do ColorMover("TUI_SpecialBarMover_bar" .. i) end
    for i = 1, iconCount do ColorMover("TUI_SpecialIconMover_icon" .. i) end

    syncing = false
end

local pending = false
local tickFrame = CreateFrame("Frame")
local function FlushPending(self)
    self:SetScript("OnUpdate", nil)
    pending = false
    M.SyncAll()
end
function M.Queue()
    if pending then return end
    pending = true
    tickFrame:SetScript("OnUpdate", FlushPending)
end

function TUI:UpdateMoverSync()
    M.Queue()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    EnsureConfigMode()
    C_Timer.After(1, M.Queue)
end)

if E and E.ToggleMoveMode then
    hooksecurefunc(E, "ToggleMoveMode", function() M.Queue() end)
end
