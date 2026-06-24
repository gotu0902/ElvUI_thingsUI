local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.TrinketsCDM = ns.TrinketsCDM or {}

local M = ns.TrinketsCDM
local SLOTS = { 13, 14 }
local buttons = {}
local SYNTHETIC_COOLDOWN_BASE = 1000000

local function GetDB()
    return E.db.thingsUI and E.db.thingsUI.trinketsCDM
end

local function IsGroupedIntoCustomGroup()
    return (ns.CustomGroups and ns.CustomGroups.GetTrinketOwnerGroup
            and ns.CustomGroups.GetTrinketOwnerGroup()) and true or false
end
M.IsGroupedIntoCustomGroup = IsGroupedIntoCustomGroup

local function MigrateDB(db)
    if not db or rawget(db, "_tuiTrinketMigrated") then return end
    db._tuiTrinketMigrated = true
    if db.mode == "NHT" then db.mode = "EMBEDDED"
    elseif db.mode == "FHT" then db.mode = "BAR" end
    local oldSide = rawget(db, "nhtSide")
    if oldSide then
        if rawget(db, "essentialSide") == nil then db.essentialSide = oldSide end
        if rawget(db, "utilitySide")   == nil then db.utilitySide   = oldSide end
        db.nhtSide = nil
    end
end
M.MigrateDB = MigrateDB

local USABLE_CLASSIFICATION_BY_ITEMID = setmetatable({}, { __mode = "kv" })

local function IsUsableTrinket(itemID)
    if not itemID then return false end
    local cached = USABLE_CLASSIFICATION_BY_ITEMID[itemID]
    if cached ~= nil then return cached end
    local spellName = C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
    local result = spellName ~= nil
    USABLE_CLASSIFICATION_BY_ITEMID[itemID] = result
    return result
end

local function IsBlacklisted(itemID)
    if not itemID then return false end
    local db = GetDB()
    return db and db.blacklist and db.blacklist[itemID] or false
end
M.IsBlacklisted = IsBlacklisted

local function StyleButton(btn)
    if btn._tuiStyled then return end
    btn._tuiStyled = true

    local S = E.GetModule and E:GetModule("Skins", true)
    if S and S.HandleIcon and btn.icon then
        S:HandleIcon(btn.icon, true)
    end
end

local function UpdateButtonCooldown(btn)
    local slot = btn._slot
    if not slot or not btn.cooldown then return end
    local start, duration = GetInventoryItemCooldown("player", slot)
    local onCooldown = start and duration and duration > 0
                       and (start + duration - GetTime()) > 0.1
    if onCooldown then
        btn.cooldown:SetCooldown(start, duration)
    else
        btn.cooldown:Clear()
    end
    if btn.icon and btn.icon.SetDesaturated then
        btn.icon:SetDesaturated(onCooldown or false)
    end
end

local function UpdateButtonIcon(btn)
    local slot = btn._slot
    local itemID = slot and GetInventoryItemID("player", slot)
    btn._itemID = itemID

    if itemID then
        local tex = GetInventoryItemTexture("player", slot)
        if btn.icon and tex then btn.icon:SetTexture(tex) end
        btn._synthCooldownID = SYNTHETIC_COOLDOWN_BASE + slot
    else
        if btn.icon then btn.icon:SetTexture(nil) end
    end
end

local function CreateButton(slot)
    if buttons[slot] then return buttons[slot] end

    local name = "TUI_TrinketButton_" .. slot

    local btn = CreateFrame("Button", name, _G.UIParent)
    btn._slot = slot
    btn:SetSize(36, 36)
    btn:EnableMouse(false)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    btn.icon = icon

    local cd = CreateFrame("Cooldown", name .. "Cooldown", btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:EnableMouse(false)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    btn.cooldown = cd
    btn.Cooldown = cd

    btn.GetCooldownID = function(self)
        return self._synthCooldownID or (SYNTHETIC_COOLDOWN_BASE + (self._slot or 0))
    end

    StyleButton(btn)
    buttons[slot] = btn
    return btn
end

local function ResolveAttachViewer()
    local db = GetDB()
    if not (db and db.enabled) then return nil end

    local mode = db.mode or "EMBEDDED"
    if mode ~= "EMBEDDED" then return nil end

    local attach = db.attach or "ESSENTIAL"
    local viewer, key
    if attach == "ESSENTIAL" then
        viewer, key = _G.EssentialCooldownViewer, "essential"
    elseif attach == "UTILITY" then
        viewer, key = _G.UtilityCooldownViewer, "utility"
    elseif attach == "DYNAMIC" then
        local ev = _G.EssentialCooldownViewer
        local native = 0
        if ev then
            for i = 1, ev:GetNumChildren() do
                local c = select(i, ev:GetChildren())
                if c and c:IsShown() and c.GetCooldownID and c ~= buttons[13] and c ~= buttons[14] then
                    native = native + 1
                end
            end
        end
        local threshold = db.dynamicThreshold or 10
        if native >= threshold then
            viewer, key = _G.UtilityCooldownViewer, "utility"
        else
            viewer, key = _G.EssentialCooldownViewer, "essential"
        end
    end
    if not viewer then return nil end
    local side = (key == "utility") and (db.utilitySide or "RIGHT") or (db.essentialSide or "RIGHT")
    return viewer, side, key
end

local applying = false

local function GetAttachIconSize(viewer)
    local key = (viewer == _G.UtilityCooldownViewer) and "utility" or "essential"
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local vdb = cdm and cdm[key]
    if vdb and vdb.overrideSize then
        local w = vdb.iconWidth or 36
        local h = vdb.lockAspect and w or (vdb.iconHeight or w)
        return w, h, (vdb.spacing or 1)
    end
    local h = viewer:GetHeight()
    if not h or h < 1 then h = 36 end
    return h, h, (vdb and vdb.spacing or 1)
end

local function GetViewerGrowth(key)
    local cdm = E.db.thingsUI and E.db.thingsUI.cdmIcons
    local vdb = cdm and cdm[key]
    return (vdb and vdb.growthDirection) or "CENTERED_H"
end

local PLACEMENT_START_EDGE = {
    DOWN = "TOP", UP = "BOTTOM", RIGHT = "LEFT", LEFT = "RIGHT",
    CENTERED_H = "LEFT", CENTERED_V = "TOP",
}

local function ComputePlacement(growth, side)
    local startEdge = PLACEMENT_START_EDGE[growth] or "LEFT"
    if side == startEdge then return "START" else return "END" end
end
M.ComputePlacement = ComputePlacement

local barFrame
local function GetBarDB()
    local db = GetDB()
    return (db and db.bar) or {}
end

local function EnsureBarFrame()
    if barFrame then return barFrame end
    barFrame = CreateFrame("Frame", "TUI_TrinketBar", _G.UIParent)
    barFrame:SetSize(80, 36)
    barFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    local ms = ns.MoverSync
    if ms and ms.CreateManaged then
        ms.CreateManaged(barFrame, "TUI_TrinketBarMover", "thingsUI Trinket Bar", {
            configString  = "thingsUI,modulesTab,cdm,trinketsToCDMSubTab",
            shouldDisable = function()
                local db = GetDB()
                return not (db and db.enabled and (db.mode or "EMBEDDED") == "BAR")
            end,
            onSave = function(point, relPoint, x, y)
                local bdb = GetBarDB()
                bdb.anchorPoint = point
                bdb.anchorRelativePoint = relPoint
                bdb.anchorXOffset = x
                bdb.anchorYOffset = y
                if M.QueueLayout then M.QueueLayout() end
                ns.NotifyChange()
            end,
        })
    end
    return barFrame
end

local function HideBar()
    if barFrame then barFrame:Hide() end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

local function ApplyBarLayout()
    local db = GetDB()
    local bdb = GetBarDB()
    local frame = EnsureBarFrame()

    local includePassive = db.includePassive == true
    local size   = bdb.iconSize or 36
    local sp     = bdb.spacing or 2
    local growth = bdb.growth or "RIGHT"

    local shown = {}
    for _, slot in ipairs(SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        local isUsable = itemID and IsUsableTrinket(itemID)
        local isBL = itemID and IsBlacklisted(itemID)
        if itemID and (includePassive or isUsable) and not isBL then
            local btn = CreateButton(slot)
            UpdateButtonIcon(btn)
            UpdateButtonCooldown(btn)
            btn.layoutIndex = nil
            if btn:GetParent() ~= frame then btn:SetParent(frame) end
            btn:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
            btn:SetSize(size, size)
            shown[#shown + 1] = btn
        else
            local btn = buttons[slot]
            if btn then btn:Hide() end
        end
    end

    local n = #shown
    for i, btn in ipairs(shown) do
        btn:ClearAllPoints()
        local off = (i - 1) * (size + sp)
        if growth == "LEFT" then
            btn:SetPoint("RIGHT", frame, "RIGHT", -off, 0)
        elseif growth == "DOWN" then
            btn:SetPoint("TOP", frame, "TOP", 0, -off)
        elseif growth == "UP" then
            btn:SetPoint("BOTTOM", frame, "BOTTOM", 0, off)
        else
            btn:SetPoint("LEFT", frame, "LEFT", off, 0)
        end
        btn:Show()
    end

    local along = (n > 0) and (n * size + (n - 1) * sp) or size
    if growth == "DOWN" or growth == "UP" then
        frame:SetSize(size, math.max(along, size))
    else
        frame:SetSize(math.max(along, size), size)
    end

    local af = bdb.anchorFrame or "UIParent"
    local target = (af ~= "UIParent") and _G[af] or nil
    if af == "ElvUF_Player_CastBar" and target and target.Holder then
        target = target.Holder
    end
    frame:ClearAllPoints()
    frame:SetPoint(bdb.anchorPoint or "CENTER", target or _G.UIParent,
        bdb.anchorRelativePoint or "CENTER",
        bdb.anchorXOffset or 0, bdb.anchorYOffset or 0)

    frame:SetShown(n > 0)

    if ns.CDMText and ns.CDMText.StyleChild and bdb.text then
        for _, btn in ipairs(shown) do
            ns.CDMText.StyleChild(btn, bdb.text)
        end
    end

    M._trinketCount = n
    M._trinketExtentX, M._trinketExtentY = 0, 0
    M._attachViewer, M._shownButtons, M._placement = nil, nil, nil
end

local function NotifyConsumers()
    if ns.CDMIcons and ns.CDMIcons.RefreshAll then ns.CDMIcons.RefreshAll() end
    if ns.CDMText and ns.CDMText.RefreshAll then ns.CDMText.RefreshAll() end
    C_Timer.After(0, function()
        if ns.EssentialMover and ns.EssentialMover.Apply then ns.EssentialMover.Apply() end
        if ns.BarSetup and ns.BarSetup.ApplyStack then ns.BarSetup.ApplyStack() end
        if TUI.UpdateClusterPositioning then TUI:UpdateClusterPositioning() end
        if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
    end)
end

local function ApplyLayout()
    if applying then return end
    if InCombatLockdown() then
        return
    end
    applying = true

    local db = GetDB()
    MigrateDB(db)

    if db and db.enabled and IsGroupedIntoCustomGroup() then
        HideBar()
        local includePassive = db.includePassive == true
        local grouped = {}
        for _, slot in ipairs(SLOTS) do
            local itemID = GetInventoryItemID("player", slot)
            local isUsable = itemID and IsUsableTrinket(itemID)
            local isBL = itemID and IsBlacklisted(itemID)
            if itemID and (includePassive or isUsable) and not isBL then
                local btn = CreateButton(slot)
                UpdateButtonIcon(btn)
                UpdateButtonCooldown(btn)
                btn.layoutIndex = nil
                grouped[#grouped + 1] = btn
            else
                local btn = buttons[slot]
                if btn then btn:Hide() end
            end
        end
        M._groupButtons = grouped
        M._trinketCount, M._trinketExtentX, M._trinketExtentY = #grouped, 0, 0
        M._attachViewer, M._shownButtons, M._placement = nil, nil, nil
        applying = false
        if ns.CustomGroups and ns.CustomGroups.QueueLayout then ns.CustomGroups.QueueLayout() end
        NotifyConsumers()
        return
    end
    M._groupButtons = nil

    if db and db.enabled and (db.mode or "EMBEDDED") == "BAR" then
        ApplyBarLayout()
        applying = false
        NotifyConsumers()
        return
    end

    HideBar()

    local viewer, side, attachKey = ResolveAttachViewer()

    if not viewer then
        for _, slot in ipairs(SLOTS) do
            local btn = buttons[slot]
            if btn then
                btn:Hide()
                btn:SetParent(_G.UIParent)
            end
        end
        M._trinketCount, M._trinketExtentX, M._trinketExtentY, M._trinketSide = 0, 0, 0, "RIGHT"
        M._attachViewer, M._shownButtons, M._placement = nil, nil, nil
        applying = false
        NotifyConsumers()
        return
    end

    local includePassive = db.includePassive == true
    side = side or "RIGHT"
    local W, H, spacing = GetAttachIconSize(viewer)
    local S = (spacing or 1) + 2

    local shown = {}
    for _, slot in ipairs(SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        local isUsable = itemID and IsUsableTrinket(itemID)
        local isBL = itemID and IsBlacklisted(itemID)
        local eligible = itemID
            and (includePassive or isUsable)
            and not isBL

        if eligible then
            local btn = CreateButton(slot)
            UpdateButtonIcon(btn)
            UpdateButtonCooldown(btn)
            if btn:GetParent() ~= _G.UIParent then
                btn:SetParent(_G.UIParent)
            end
            btn:SetFrameStrata(viewer:GetFrameStrata() or "MEDIUM")
            btn:SetFrameLevel((viewer:GetFrameLevel() or 1) + 5)
            btn:SetSize(W, H)
            btn:Show()
            shown[#shown + 1] = btn
        else
            local btn = buttons[slot]
            if btn then
                btn:Hide()
                if btn:GetParent() ~= _G.UIParent then
                    btn:SetParent(_G.UIParent)
                end
            end
        end
    end

    local n = #shown
    local placement = ComputePlacement(GetViewerGrowth(attachKey), side)
    for i, btn in ipairs(shown) do
        if placement == "START" then
            btn.layoutIndex = -1000 + i
        else
            btn.layoutIndex = 100000 + i
        end
    end

    M._trinketCount   = n
    M._trinketSide    = side
    M._attachViewer   = viewer
    M._placement      = placement
    M._shownButtons   = shown
    M._trinketExtentX = 0
    M._trinketExtentY = 0
    M._trinketAttachKey = attachKey or ((viewer == _G.UtilityCooldownViewer) and "utility" or "essential")

    applying = false

    NotifyConsumers()
end

local queued = false
local function QueueLayout()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        ApplyLayout()
    end)
end
M.QueueLayout = QueueLayout
M.QueueUpdate = QueueLayout

function M.GetExtraEssentialCount() return M._trinketCount or 0 end
function M.GetTrinketExtent() return M._trinketExtentX or 0, M._trinketSide or "RIGHT" end
function M.GetTrinketExtentY() return M._trinketExtentY or 0, M._trinketSide or "TOP" end
function M.GetTrinketAxis()
    local s = M._trinketSide
    return (s == "TOP" or s == "BOTTOM") and "V" or "H"
end
function M.GetTrinketAttachKey() return M._trinketAttachKey or "essential" end
function M.GetInlineButtonsFor(viewer)
    if M._attachViewer ~= viewer then return nil end
    local b = M._shownButtons
    if not b or #b == 0 then return nil end
    return b
end

function M.GetGroupButtons()
    local b = M._groupButtons
    if not b or #b == 0 then return nil end
    return b
end
function M.ResetEssentialSavedPoint() end
function M.IsTrinketBlacklisted() return false end

local hookedRefresh = false
local function HookViewerRefresh()
    if hookedRefresh then return end
    for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        local v = _G[name]
        if v and v.RefreshLayout and not v._tuiTrinketRefreshHooked then
            v._tuiTrinketRefreshHooked = true
            hooksecurefunc(v, "RefreshLayout", function() QueueLayout() end)
            hookedRefresh = true
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 ~= 13 and arg1 ~= 14 then return end
        QueueLayout()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        for _, btn in pairs(buttons) do
            if btn:IsShown() then UpdateButtonCooldown(btn) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        QueueLayout()
    else
        C_Timer.After(1, function() HookViewerRefresh(); QueueLayout() end)
    end
end)

function TUI:UpdateTrinketsCDM()
    QueueLayout()
end