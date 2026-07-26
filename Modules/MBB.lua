local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

ns.MBB = ns.MBB or {}
local M = ns.MBB

local function DB() return E.db.thingsUI and E.db.thingsUI.mbb end
local function MainButton() return _G.MinimapButtonButtonButton end
local function Loaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MinimapButtonButton") and MainButton()
end

local function ApplyPosition()
    local db = DB()
    local btn = MainButton()
    if not (db and db.manage and btn) then return end
    local target = ns.ANCHORS.ResolveAnchorTarget(db.anchor or "Minimap") or _G.UIParent
    local point = db.point or "TOPRIGHT"
    btn:ClearAllPoints()
    btn:SetPoint(point, target, point, db.x or 0, db.y or 0)
end

local STRIP_IDS = { [136430] = true, [136467] = true, [136477] = true, [136443] = true }
local rawSetScale = _G.UIParent.SetScale
local rawSetParent = _G.UIParent.SetParent

local function ContainerOf(main)
    for _, c in ipairs({ main:GetChildren() }) do
        if c.IsObjectType and c:IsObjectType("Frame") then return c end
    end
end

local skinned = {}
local function SkinButton(btn)
    if skinned[btn] then return false end
    skinned[btn] = true
    local icon = btn.icon
    for _, region in next, { btn:GetRegions() } do
        if region.IsObjectType and region:IsObjectType("Texture") and region ~= icon then
            local tex = region:GetTexture()
            local drop = region == btn.border or region == btn.background
            if not drop and type(tex) == "number" then drop = STRIP_IDS[tex] end
            if not drop and type(tex) == "string" then
                local l = tex:lower()
                drop = l:find("border") or l:find("background") or l:find("alphamask") or l:find("trackingborder")
            end
            if drop then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    if btn._tuiSkin then btn._tuiSkin:Hide() end
end

local function SkinAll()
    local db = DB()
    local main = MainButton()
    if not (db and db.skin and main) then return end
    for _, container in ipairs({ main:GetChildren() }) do
        if container.IsObjectType and container:IsObjectType("Frame") then
            local resized = false
            for _, btn in ipairs({ container:GetChildren() }) do
                if btn.GetRegions then
                    SkinButton(btn)
                    local w, s = btn:GetWidth() or 0, btn:GetScale() or 1
                    if w > 0 and w * s > 38 then
                        rawSetScale(btn, 33 / w)
                        resized = true
                    end
                end
            end
            if resized then
                -- visibility toggle is the only external way to trigger MBB's relayout
                for _, btn in ipairs({ container:GetChildren() }) do
                    if btn.IsShown and btn:IsShown() and btn.Hide and btn.Show then
                        btn:Hide()
                        btn:Show()
                        break
                    end
                end
            end
        end
    end
end

local function NormalizeCollected()
    local main = MainButton()
    if not main then return end
    for _, container in ipairs({ main:GetChildren() }) do
        if container.IsObjectType and container:IsObjectType("Frame") then
            for _, btn in ipairs({ container:GetChildren() }) do
                if btn.SetIgnoreParentScale then btn:SetIgnoreParentScale(false) end
                if btn.SetIgnoreParentAlpha then btn:SetIgnoreParentAlpha(false) end
            end
        end
    end
    -- adopt whitelisted strays ElvUI re-parented back via its SetParent hook
    local container = ContainerOf(main)
    if not container then return end
    for key, name in pairs(M.COLLECT or {}) do
        if M.IsCollected(key) then
            local btn = _G[name]
            if btn then
                if btn:GetParent() ~= container then rawSetParent(btn, container) end
                if btn.SetIgnoreParentScale then btn:SetIgnoreParentScale(false) end
                if btn.SetIgnoreParentAlpha then btn:SetIgnoreParentAlpha(false) end
            end
        end
    end
end

local function ForceRelayout()
    local main = MainButton()
    local cont = main and ContainerOf(main)
    if not cont then return end
    for _, btn in ipairs({ cont:GetChildren() }) do
        if btn.IsShown and btn:IsShown() and btn.Hide and btn.Show then
            btn:Hide()
            btn:Show()
            return
        end
    end
end

local function MBBSlash(cmd)
    local handler = SlashCmdList and SlashCmdList["MinimapButtonButton"]
    if handler then handler(cmd) end
end

function M.GetOption(name)
    if Settings and Settings.GetValue then
        -- variable registered by MBB's own settings panel; errors on unknown variable
        local ok, v = pcall(Settings.GetValue, "MinimapButtonButton_" .. name)
        if ok then return v end
    end
    local o = _G.MinimapButtonButtonOptions
    return o and o[name]
end

function M.SetOption(name, value)
    if Settings and Settings.SetValue then
        -- variable registered by MBB's own settings panel; errors on unknown variable
        local ok = pcall(Settings.SetValue, "MinimapButtonButton_" .. name, value)
        if ok then return end
    end
    if name == "direction" then
        MBBSlash("set direction " .. value)
    elseif name == "buttonsPerRow" then
        MBBSlash("set buttonsperrow " .. value)
    end
end

function M.SetDirection(v) M.SetOption("direction", v) end
function M.SetWrap(n) M.SetOption("buttonsPerRow", n) end

local DIR_POINT = {
    leftdown = "TOPRIGHT", leftup = "BOTTOMRIGHT",
    rightdown = "TOPLEFT", rightup = "BOTTOMLEFT",
    upleft = "BOTTOMRIGHT", upright = "BOTTOMLEFT",
    downleft = "TOPRIGHT", downright = "TOPLEFT",
}

local fixingAnchor = false
local function OverlapContainer()
    local db = DB()
    if not (db and db.hideMain) then return end
    local main = MainButton()
    local cont = main and ContainerOf(main)
    if not cont then return end
    local pt = DIR_POINT[M.GetOption("direction") or "leftdown"] or "TOPRIGHT"
    fixingAnchor = true
    cont:ClearAllPoints()
    cont:SetPoint(pt, main, pt, 0, 0)
    fixingAnchor = false
end

local DRAW_LAYERS = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
local function ApplyHideMain()
    local db = DB()
    local main = MainButton()
    if not main then return end
    local cont = ContainerOf(main)
    if db and db.hideMain then
        for _, layer in ipairs(DRAW_LAYERS) do main:DisableDrawLayer(layer) end
        if main.backdrop and main.backdrop.Hide then main.backdrop:Hide() end
        main:EnableMouse(false)
        if cont then
            if not cont._tuiShowHooked then
                cont._tuiShowHooked = true
                cont:HookScript("OnHide", function()
                    C_Timer.After(0, function()
                        local d = DB()
                        if d and d.hideMain and cont.Show then cont:Show() end
                    end)
                end)
                hooksecurefunc(cont, "SetPoint", function()
                    if fixingAnchor then return end
                    local d = DB()
                    if d and d.hideMain then OverlapContainer() end
                end)
            end
            cont:Show()
        end
        OverlapContainer()
    else
        for _, layer in ipairs(DRAW_LAYERS) do main:EnableDrawLayer(layer) end
        if main.backdrop and main.backdrop.Show then main.backdrop:Show() end
        main:EnableMouse(true)
        ForceRelayout()
    end
end

local pending
local function QueueSkin()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        NormalizeCollected()
        SkinAll()
    end)
end

M.COLLECT = {
    queueStatus = "QueueStatusButton",
    omniumFolio = "ExpansionLandingPageMinimapButton",
}

function M.IsCollected(key)
    local name = M.COLLECT[key]
    local o = _G.MinimapButtonButtonOptions
    return name and o and o.whitelist and o.whitelist[name] == true or false
end

function M.SetCollected(key, on)
    local name = M.COLLECT[key]
    local handler = SlashCmdList and SlashCmdList["MinimapButtonButton"]
    if not (name and handler and Loaded()) then return end
    if on then
        handler("include " .. name)
        print("|cFF8080FFthingsUI|r - " .. name .. " will be collected next time you open MinimapButtonButton (or /reload).")
    else
        handler("ignore " .. name)
        print("|cFF8080FFthingsUI|r - " .. name .. " released. |cFFFFFF00Reload required.|r")
    end
end

-- Re-adopts strays and re-anchors when Blizzard/MBB re-assert mid-session
local function VerifyState()
    if InCombatLockdown() then return end
    if not Loaded() then return end
    local db = DB()
    if not db then return end
    local main = MainButton()
    if db.manage then
        local target = ns.ANCHORS.ResolveAnchorTarget(db.anchor or "Minimap") or _G.UIParent
        local _, relTo = main:GetPoint(1)
        if relTo ~= target then ApplyPosition() end
    end
    local cont = ContainerOf(main)
    if not cont then return end
    for key, name in pairs(M.COLLECT) do
        if M.IsCollected(key) then
            local btn = _G[name]
            if btn and btn:GetParent() ~= cont then
                NormalizeCollected()
                QueueSkin()
                ForceRelayout()
                return
            end
        end
    end
end

local function ApplyHoverAlpha()
    local db = DB()
    local main = MainButton()
    if not main then return end
    if not (db and db.mouseover) then main:SetAlpha(1); return end
    local cont = ContainerOf(main)
    local over = main:IsMouseOver() or (cont and cont:IsShown() and cont:IsMouseOver())
    main:SetAlpha(over and 1 or 0)
end

local hoverTicker
local verifyTicker
local hooked = false
function TUI:UpdateMBB()
    if not Loaded() then return end
    local db = DB()
    local main = MainButton()
    if not hooked then
        hooked = true
        main:HookScript("OnMouseDown", QueueSkin)
    end
    if not verifyTicker then verifyTicker = C_Timer.NewTicker(1, VerifyState) end
    if db and not db.seeded then
        db.seeded = true
        M.SetDirection("leftup")
        M.SetWrap(6)
    end
    main:SetScale((db and db.scale) or 1)
    if db and db.mouseover then
        if not hoverTicker then hoverTicker = C_Timer.NewTicker(0.2, ApplyHoverAlpha) end
        ApplyHoverAlpha()
    else
        if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
        main:SetAlpha(1)
    end
    ApplyPosition()
    NormalizeCollected()
    SkinAll()
    ApplyHideMain()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        if TUI.UpdateMBB then TUI:UpdateMBB() end
    end)
end)
