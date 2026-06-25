local _, ns = ...
local TUI = ns.TUI
local E   = ns.E
local LSM = ns.LSM
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

ns.CustomGroups = ns.CustomGroups or {}
local M = ns.CustomGroups

local groupState = {}
local QueueLayout  -- fwd

local function GetCurrentSpecID()
    local idx = GetSpecialization()
    return idx and GetSpecializationInfo(idx) or 0
end

local function GetCurrentClassFile()
    local _, cf = UnitClass("player")
    return cf or "PRIEST"
end

local function GetDB()
    return E.db.thingsUI and E.db.thingsUI.customGroups
end

local DefaultGroup = ns.Defaults.Group
M.DefaultGroup = DefaultGroup

local OLD_FLAT_KEYS = {
    "enabled", "iconSize", "spacing", "growth", "columns",
    "hideZeroCharges", "qualityBorder",
    "fleetingMarker", "fleetingBorderSize", "fleetingBorderInset", "fleetingBorderColor", "fleetingBorderStroke",
    "scopeOrder", "anchorFrame", "anchorPoint", "anchorRelativePoint", "anchorXOffset", "anchorYOffset",
    "text", "global", "classes", "specs",
}
local function CarryOldFlat(g, db)
    local any = false
    for _, k in ipairs(OLD_FLAT_KEYS) do
        local v = rawget(db, k)
        if v ~= nil then g[k] = v; any = true; db[k] = nil end
    end
    return any
end

local function EnsureDB()
    local db = GetDB()
    if not db then return nil end
    if not db.groups then db.groups = {} end
    if not db.nextID then db.nextID = 1 end
    if not db._migratedMulti then
        db._migratedMulti = true
        if #db.groups == 0 then
            local g = DefaultGroup(db.nextID, "Group 1")
            db.nextID = db.nextID + 1
            CarryOldFlat(g, db)
            db.groups[1] = g
        end
    end
    return db
end
M.EnsureDB = EnsureDB

local function GetGroups()
    local db = EnsureDB()
    return db and db.groups or {}
end
M.GetGroups = GetGroups

local function GroupByID(id)
    for _, g in ipairs(GetGroups()) do if g.id == id then return g end end
end
M.GroupByID = GroupByID

function M.GetScopeRoot(group, scope, key, create)
    if not group then return nil end
    local root
    if scope == "global" then
        if create then group.global = group.global or {} end
        root = group.global
    elseif scope == "class" then
        group.classes = group.classes or {}
        key = key or GetCurrentClassFile()
        if create then group.classes[key] = group.classes[key] or {} end
        root = group.classes[key]
    else -- spec
        group.specs = group.specs or {}
        if not key then local id = GetCurrentSpecID(); key = (id ~= 0) and id or 1 end
        key = tostring(key)
        if create then group.specs[key] = group.specs[key] or {} end
        root = group.specs[key]
    end
    if create and root then
        root.spells = root.spells or {}
        root.items  = root.items  or {}
    end
    return root
end

local H = ns.CDHelpers
local SetCooldown                 = H.SetCooldownFromDuration
local SetDesat                    = H.SetDesat
local UpdateSpellIconDesaturation = H.SpellDesat

local function UpdateSpellIcon(btn)
    local id = btn._id
    if not id then return end
    local charges = C_Spell.GetSpellCharges(id)
    if charges and (charges.maxCharges or 0) > 1 then
        if btn.count then btn.count:SetText(C_Spell.GetSpellDisplayCount and C_Spell.GetSpellDisplayCount(id) or charges.currentCharges) end
        SetCooldown(btn.cooldown, C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(id))
    else
        if btn.count then btn.count:SetText("") end
        SetCooldown(btn.cooldown, C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(id))
    end
    UpdateSpellIconDesaturation(btn, id)
end

local function ResolveItemID(id)
    if id == 5512 or id == 224464 then
        local _, cf = UnitClass("player")
        if cf == "WARLOCK" then
            local knows = C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(386689)
            return knows and 224464 or 5512
        end
    end
    return id
end

-- Fleeting-r1, r1, Fleeting-r2, r2.
local POTION_GROUPS = {
    { 245916, 241300, 245917, 241301 },  -- Lightfused Mana Potion
    { 245904, 241294, 245905, 241295 },  -- Potion of Devoured Dreams
    { 245902, 241288, 245903, 241289 },  -- Potion of Recklessness
    { 245898, 241308, 245897, 241309 },  -- Light's Potential
    { 245918, 241304, 245919, 241305 },  -- Silvermoon Health Potion
    { 245910, 241292, 245911, 241293 },  -- Draught of Rampant Abandon
}
local POTION_OF = {}
local FLEETING  = {}
for gi, grp in ipairs(POTION_GROUPS) do
    for ri, id in ipairs(grp) do
        POTION_OF[id] = gi
        if ri == 1 or ri == 3 then FLEETING[id] = true end
    end
end
M.POTION_OF = POTION_OF
M.FLEETING  = FLEETING
M.POTION_GROUPS = POTION_GROUPS   -- exported so Timers can register all rank variants' triggers

local function PickBestOwnedPotion(gi)
    local grp = POTION_GROUPS[gi]; if not grp then return nil end
    for _, id in ipairs(grp) do
        if (C_Item.GetItemCount(id) or 0) > 0 then return id end
    end
    return grp[1]
end

local function ParseQualityAtlasFromLink(link)
    if type(link) ~= "string" then return end
    return link:match("|A:(Professions%-[^:|]-Tier%d+):")
        or link:match("(Professions%-Icon%-Quality%-%d+%-Tier%d+)")
        or link:match("(Professions%-Icon%-Quality%-Tier%d+)")
end

local function ResolveItemQualityAtlas(id)
    if not id then return end
    local _, link = C_Item.GetItemInfo(id)
    local fromLink = ParseQualityAtlasFromLink(link)
    if fromLink then return fromLink end
    local rank
    if C_TradeSkillUI then
        local info = link or id
        if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
            rank = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(info)
        end
        if not rank and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
            rank = C_TradeSkillUI.GetItemReagentQualityByItemInfo(info)
        end
    end
    if not rank or rank <= 0 then return end
    local expansionID = select(15, C_Item.GetItemInfo(id))
    if expansionID == 11 then
        return "Professions-Icon-Quality-12-Tier" .. rank .. "-Small"
    end
    return "Professions-Icon-Quality-Tier" .. rank .. "-Small"
end

local function ApplyQualityAtlas(btn, id)
    local q = btn.QualityAtlas
    if not q then return end
    local g = btn._group
    if not (g and g.qualityBorder) then q:Hide(); return end
    local atlas = ResolveItemQualityAtlas(id)
    if not atlas then q:Hide(); return end
    local sz = math.max(6, math.floor((btn:GetWidth() or 36) * (g.qualityScale or 0.42)))
    local pt = g.qualityPoint or "TOPLEFT"
    q:ClearAllPoints()
    q:SetPoint(pt, btn, pt, g.qualityXOffset or 0, g.qualityYOffset or 0)
    q:SetSize(sz, sz)
    q:SetAtlas(atlas)
    if btn.QualityFrame then
        local L = btn:GetFrameLevel()
        if btn.cooldown then btn.cooldown:SetFrameLevel(L + 3) end
        btn.QualityFrame:SetFrameStrata(btn:GetFrameStrata() or "MEDIUM")
        btn.QualityFrame:SetFrameLevel((g.qualityLayer == "BEHIND") and (L + 1) or (L + 11))
    end
    q:Show()
end

local _bMain  = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bInner = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local _bOuter = { bgFile = nil, edgeFile = nil, edgeSize = 1 }
local function DrawStroke3(bd, inner, outer, anchor, size, inset, bc, stroke)
    if not bd then return end
    _bMain.edgeFile = E.media.blankTex; _bMain.edgeSize = size
    bd:SetBackdrop(nil); bd:SetBackdrop(_bMain)
    bd:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a or 1)
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT",     anchor, "TOPLEFT",      inset, -inset)
    bd:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset,  inset)
    bd:Show()
    if stroke then
        _bInner.edgeFile = E.media.blankTex; _bInner.edgeSize = 1
        inner:SetBackdrop(nil); inner:SetBackdrop(_bInner)
        inner:SetBackdropBorderColor(0, 0, 0, 1)
        inner:ClearAllPoints()
        inner:SetPoint("TOPLEFT",     anchor, "TOPLEFT",      inset + size, -(inset + size))
        inner:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -(inset + size),  inset + size)
        inner:Show()
        _bOuter.edgeFile = E.media.blankTex; _bOuter.edgeSize = 1
        outer:SetBackdrop(nil); outer:SetBackdrop(_bOuter)
        outer:SetBackdropBorderColor(0, 0, 0, 1)
        outer:ClearAllPoints()
        outer:SetPoint("TOPLEFT",     anchor, "TOPLEFT",      inset - 1, -(inset - 1))
        outer:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -(inset - 1),  inset - 1)
        outer:Show()
    elseif inner then
        inner:Hide(); outer:Hide()
    end
end

local function ApplyFleetingBorder(btn, id)
    local bd, inner, outer = btn.FleetingBorder, btn.FleetingBorderInner, btn.FleetingBorderOuter
    if not bd then return end
    local g = btn._group
    if not (g and g.fleetingMarker and FLEETING[id]) then
        bd:Hide(); inner:Hide(); outer:Hide(); return
    end
    DrawStroke3(bd, inner, outer, btn,
        g.fleetingBorderSize or 2, g.fleetingBorderInset or 0,
        g.fleetingBorderColor or { r = 0.2, g = 0.8, b = 1, a = 1 }, g.fleetingBorderStroke)
end

local function ApplyGroupBorder(btn)
    local bd, inner, outer = btn.tuiBorder, btn.tuiBorderInner, btn.tuiBorderOuter
    if not bd then return end
    local g = btn._group
    if not (g and g.showBorder) then
        bd:Hide(); inner:Hide(); outer:Hide(); return
    end
    DrawStroke3(bd, inner, outer, btn,
        g.borderSize or 1, g.borderInset or 0,
        g.borderColor or { r = 0, g = 0, b = 0, a = 1 }, g.borderStroke)
end

local USES_ITEMS = { [5512] = true, [224464] = true }  -- Healthstone / Demonic (Gluttony) Healthstone

local ItemCooldownChanged = H.ItemCooldownChanged

local function UpdateItemIcon(btn, force)
    local id = btn._id
    if not id then return end
    if force or btn._styledItemID ~= id then
        local ready = true
        if btn.icon then
            local tex = select(10, C_Item.GetItemInfo(id))
            if tex then
                if btn._tex ~= tex then btn.icon:SetTexture(tex); btn._tex = tex end
            else
                ready = false
            end
        end
        ApplyQualityAtlas(btn, id)
        ApplyFleetingBorder(btn, id)
        btn._styledItemID = ready and id or nil
    end

    local usesItem = USES_ITEMS[id]
    local timer = ns.Timers and btn._group and ns.Timers.FindItemTimer(id, btn._group.id)
    local count = usesItem and C_Item.GetItemCount(id, false, true) or C_Item.GetItemCount(id)
    if btn.count then
        local show = usesItem and (count and count > 0) or (count and count > 1)
        if timer and timer.enabled and not timer.showIdle then show = false end
        btn.count:SetText(show and tostring(count) or "")
    end
    local bStart, bDur
    if timer and timer.enabled and timer.showCDTimer then bStart, bDur = ns.Timers.GetActiveBuff(timer, GetTime()) end

    local start, dur = C_Item.GetItemCooldown(id)
    local active = (start and dur and dur > 0) or false
    if bStart then
        if ItemCooldownChanged(btn.cooldown, true, bStart, bDur) then btn.cooldown:SetCooldown(bStart, bDur) end
        if btn.icon and btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
    elseif active and not (timer and timer.enabled and timer.trackCooldown == false) then
        if ItemCooldownChanged(btn.cooldown, true, start, dur) then btn.cooldown:SetCooldown(start, dur) end
        if btn.icon and btn.icon.SetDesaturated then btn.icon:SetDesaturated(true) end
    else
        if ItemCooldownChanged(btn.cooldown, false, start, dur) then btn.cooldown:Clear() end
        if btn.icon and btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
    end
    if btn.icon and btn.icon.SetVertexColor then
        if C_Item.IsUsableItem(id) then btn.icon:SetVertexColor(1, 1, 1) else btn.icon:SetVertexColor(0.5, 0.5, 0.5) end
    end
    if ns.TimersRender and ns.TimersRender.UpdateGlow then ns.TimersRender.UpdateGlow(btn, timer) end
end

local TimerActive = H.TimerActive
M.TimerActive = TimerActive

local function UpdateTimerGlow(btn, timer)
    if ns.TimersRender and ns.TimersRender.UpdateGlow then ns.TimersRender.UpdateGlow(btn, timer) end
end

local function UpdateTimerIcon(btn)
    local timer = ns.Timers and ns.Timers.GetByID(btn._id)
    if not timer then return end
    if btn.icon then
        local tex = ns.Timers.GetTexture(timer)
        if tex then btn.icon:SetTexture(tex) end
    end
    local now = GetTime()
    if timer.kind == "lust" then

        local phase, start, dur = ns.Timers.GetLustState(now)
        if phase == "buff" then
            if ItemCooldownChanged(btn.cooldown, true, start, dur) then btn.cooldown:SetCooldown(start, dur) end
        else
            if ItemCooldownChanged(btn.cooldown, false) then btn.cooldown:Clear() end
        end
        SetDesat(btn.icon, 0)
        if btn.count then btn.count:SetText("") end
        UpdateTimerGlow(btn, timer, now)
        return
    end
    local bStart, bDur = ns.Timers.GetActiveBuff(timer, now)
    if bStart and timer.showCDTimer then
        if ItemCooldownChanged(btn.cooldown, true, bStart, bDur) then btn.cooldown:SetCooldown(bStart, bDur) end
        SetDesat(btn.icon, 0)
    elseif timer.trackCooldown == false then
        if ItemCooldownChanged(btn.cooldown, false) then btn.cooldown:Clear() end
        SetDesat(btn.icon, 0)
    elseif timer.kind == "item" and timer.itemID then
        local start, dur = C_Item.GetItemCooldown(timer.itemID)
        local active = (start and dur and dur > 0) or false
        if active then
            if ItemCooldownChanged(btn.cooldown, true, start, dur) then btn.cooldown:SetCooldown(start, dur) end
            SetDesat(btn.icon, 1)
        else
            if ItemCooldownChanged(btn.cooldown, false, start, dur) then btn.cooldown:Clear() end
            SetDesat(btn.icon, 0)
        end
    elseif timer.kind == "spell" and timer.spellID then
        SetCooldown(btn.cooldown, C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(timer.spellID))
        UpdateSpellIconDesaturation(btn, timer.spellID)
    else
        btn.cooldown:Clear()
        SetDesat(btn.icon, 0)
    end
    if btn.count then btn.count:SetText("") end
    UpdateTimerGlow(btn, timer, now)
end

local function UpdateIcon(btn)
    if btn._type == "item" then UpdateItemIcon(btn, true)
    elseif btn._type == "timer" then UpdateTimerIcon(btn)
    else UpdateSpellIcon(btn) end
    ApplyGroupBorder(btn)
end

local function StyleIcon(btn)
    local S = E.GetModule and E:GetModule("Skins", true)
    if S and S.HandleIcon and btn.icon then S:HandleIcon(btn.icon, true) end
end

local function CreateIcon(gs, group, kind, id)
    local pool = (kind == "item") and gs.itemIcons
              or (kind == "timer") and gs.timerIcons
              or gs.spellIcons
    if pool[id] then pool[id]._group = group; return pool[id] end

    local name = "TUI_CustomGroup" .. group.id .. "_" .. kind .. id
    local btn = CreateFrame("Button", name, gs.container)
    btn._type, btn._id, btn._group = kind, id, group
    btn:EnableMouse(false)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    btn.icon = icon

    local cd = CreateFrame("Cooldown", name .. "CD", btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:EnableMouse(false)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    btn.cooldown = cd
    btn.Cooldown = cd
    if kind == "timer" then

        cd:SetScript("OnCooldownDone", function()
            local t = ns.Timers and ns.Timers.GetByID(btn._id)
            if t and t.showIdle then
                UpdateIcon(btn)
            elseif QueueLayout then
                QueueLayout()
            end
        end)
    else

        cd:SetScript("OnCooldownDone", function()
            local t = ns.Timers and btn._group and ns.Timers.FindItemTimer(btn._id, btn._group.id)
            if t and t.enabled and not t.showIdle and QueueLayout then
                QueueLayout()
            else
                UpdateIcon(btn)
            end
        end)
    end

    local blvl = btn:GetFrameLevel()
    btn.tuiBorder      = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.tuiBorderInner = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.tuiBorderOuter = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.tuiBorder:SetFrameLevel(blvl + 7)
    btn.tuiBorderInner:SetFrameLevel(blvl + 8)
    btn.tuiBorderOuter:SetFrameLevel(blvl + 8)
    btn.tuiBorder:Hide(); btn.tuiBorderInner:Hide(); btn.tuiBorderOuter:Hide()

    local hi = CreateFrame("Frame", nil, btn)
    hi:SetAllPoints(btn)
    hi:SetFrameLevel(btn:GetFrameLevel() + 10)
    btn.count = hi:CreateFontString(nil, "OVERLAY")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")

    if kind == "item" then
        icon:SetTexture(select(10, C_Item.GetItemInfo(id)) or 134400)

        btn.QualityFrame = CreateFrame("Frame", nil, btn)
        btn.QualityFrame:SetFrameLevel(btn:GetFrameLevel() + 11)
        btn.QualityAtlas = btn.QualityFrame:CreateTexture(nil, "OVERLAY")
        btn.QualityAtlas:Hide()
        local lvl = btn:GetFrameLevel()
        btn.FleetingBorder      = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.FleetingBorderInner = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.FleetingBorderOuter = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.FleetingBorder:SetFrameLevel(lvl + 5)
        btn.FleetingBorderInner:SetFrameLevel(lvl + 6)
        btn.FleetingBorderOuter:SetFrameLevel(lvl + 6)
        btn.FleetingBorder:Hide(); btn.FleetingBorderInner:Hide(); btn.FleetingBorderOuter:Hide()
    elseif kind == "timer" then
        local timer = ns.Timers and ns.Timers.GetByID(id)
        icon:SetTexture((timer and ns.Timers.GetTexture(timer)) or 134400)
    else
        icon:SetTexture((C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400)
    end

    StyleIcon(btn)
    pool[id] = btn
    return btn
end

local function EnsureContainer(group)
    local gs = groupState[group.id]
    if gs and gs.container then return gs end
    gs = gs or { spellIcons = {}, itemIcons = {}, timerIcons = {}, shown = {} }
    groupState[group.id] = gs

    local cname = "TUI_CustomGroup" .. group.id
    local container = CreateFrame("Frame", cname, _G.UIParent)
    container:SetSize(80, 36)
    container:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    gs.container = container

    local ms = ns.MoverSync
    if ms and ms.CreateManaged then
        ms.CreateManaged(container, "TUI_CustomGroupMover" .. group.id, group.name or ("Custom Group " .. group.id), {
            configString  = "thingsUI,modulesTab,customGroups",
            shouldDisable = function() local g = GroupByID(group.id); return not (g and g.enabled) end,
            onSave = function(point, relPoint, x, y)
                group.anchorPoint = point
                group.anchorRelativePoint = relPoint
                group.anchorXOffset = x
                group.anchorYOffset = y
                if QueueLayout then QueueLayout() end
                ns.NotifyChange()
            end,
        })
    end
    return gs
end

local function HideGroupIcons(gs)
    for _, b in pairs(gs.spellIcons) do b:Hide() end
    for _, b in pairs(gs.itemIcons) do b:Hide() end
    if gs.timerIcons then for _, b in pairs(gs.timerIcons) do b:Hide() end end
end

local function PlayerHasRacial(id)
    if IsPlayerSpell(id) then return true end
    if id == 202719 then local _, race = UnitRace("player"); return race == "BloodElf" end
    return false
end
M.PlayerHasRacial = PlayerHasRacial

local _seen = {}
local function TimerInScope(t, scope)
    local s = t.groupScope or "global"
    if scope == "global" then return s == "global" end
    if scope == "spec"   then return type(s) == "number" and s == GetCurrentSpecID() end
    local _, cf = UnitClass("player")
    return s == cf
end

local function CollectScopeInto(group, scope, root, shown)
    local hideZero = group.hideZeroCharges
    local list = {}
    if root then
        for id, d in pairs(root.spells or {}) do
            local hideRacial = ns.RacialSet and ns.RacialSet[id] and not PlayerHasRacial(id)
            if d and d.enabled ~= false and not _seen["s" .. id] and not hideRacial and C_Spell.GetSpellInfo(id) then
                _seen["s" .. id] = true
                list[#list + 1] = { kind = "spell", id = id, li = d.layoutIndex or 999 }
            end
        end
        local groupBest = {}
        for id, d in pairs(root.items or {}) do
            if d and d.enabled ~= false then
                local eid = ResolveItemID(id)
                local gi = POTION_OF[eid]
                if gi then
                    local li = d.layoutIndex or 999
                    local g = groupBest[gi]
                    if not g then groupBest[gi] = { li = li } elseif li < g.li then g.li = li end
                elseif not _seen["i" .. eid] and C_Item.GetItemInfo(eid)
                       and not (hideZero and (C_Item.GetItemCount(eid) or 0) <= 0)
                       and not (ns.Timers and ns.Timers.FindItemTimer and ns.Timers.FindItemTimer(eid, group.id)) then
                    _seen["i" .. eid] = true
                    list[#list + 1] = { kind = "item", id = eid, li = d.layoutIndex or 999 }
                end
            end
        end
        for gi, g in pairs(groupBest) do
            if not _seen["g" .. gi] then
                local repId = PickBestOwnedPotion(gi)
                if repId and C_Item.GetItemInfo(repId)
                   and not (hideZero and (C_Item.GetItemCount(repId) or 0) <= 0)
                   and not (ns.Timers and ns.Timers.FindItemTimer and ns.Timers.FindItemTimer(repId, group.id)) then
                    _seen["g" .. gi] = true
                    list[#list + 1] = { kind = "item", id = repId, li = g.li }
                end
            end
        end
    end
    if ns.Timers then
        local now = GetTime()
        for _, t in ipairs(ns.Timers.GetTimers()) do
            if t.enabled and t.destination == group.id and TimerInScope(t, scope)
               and ((t.showIdle and t.kind ~= "lust") or TimerActive(t, now)) then
                local li = t.groupOrder or 10000
                if t.kind == "item" and t.itemID then
                    if not _seen["i" .. t.itemID] then
                        _seen["i" .. t.itemID] = true
                        list[#list + 1] = { kind = "item", id = t.itemID, li = li }
                    end
                else
                    list[#list + 1] = { kind = "timer", id = t.id, li = li }
                end
            end
        end
    end

    if scope == "spec" and ns.SpecialBars then
        local SB = ns.SpecialBars
        for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
            local ikey = "icon" .. i
            local idb = SB.GetIconDB and SB.GetIconDB(ikey)
            if idb and idb.enabled and idb.spellID and idb.customGroup == group.id then
                list[#list + 1] = { kind = "specialicon", id = ikey, li = idb.customGroupOrder or 20000 }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.li == b.li then return tostring(a.id) < tostring(b.id) end
        return a.li < b.li
    end)
    for _, e in ipairs(list) do
        shown[#shown + 1] = { kind = e.kind, id = e.id }
    end
end

local function CollectEntries(group, shown)
    for i = #shown, 1, -1 do shown[i] = nil end
    wipe(_seen)
    local order = group.scopeOrder or { "global", "class", "spec" }
    for _, scope in ipairs(order) do
        CollectScopeInto(group, scope, M.GetScopeRoot(group, scope, nil, false), shown)
    end
end

function M.GetTrinketOwnerGroup()
    local db = E.db.thingsUI and E.db.thingsUI.trinketsCDM
    if not (db and db.enabled and db.mode == "GROUP" and db.group) then return nil end
    local g = GroupByID(db.group)
    return (g and g.enabled) and g or nil
end

local function ApplyGroup(group)
    local gs = EnsureContainer(group)
    local frame = gs.container

    if not group.enabled then
        HideGroupIcons(gs)
        frame:Hide()
        return
    end

    local iw = group.iconWidth or group.iconSize or 36
    local ih = (group.squareIcon ~= false) and iw or (group.iconHeight or iw)
    local sp     = group.spacing or 2
    local growth = group.growth or "RIGHT"
    local perLine = math.max(0, math.floor(group.columns or 0))

    HideGroupIcons(gs)
    CollectEntries(group, gs.shown)

    if ns.SpecialBars and ns.SpecialBars.SyncGroupedIconSizes then
        ns.SpecialBars.SyncGroupedIconSizes(group.id, iw, ih)
    end
    local btns = {}
    for _, e in ipairs(gs.shown) do
        if e.kind == "specialicon" then

            local w = ns.SpecialBars and ns.SpecialBars.GetIconWrapper and ns.SpecialBars.GetIconWrapper(e.id)
            if w and w:IsShown() then
                ns.Pixel.SetSize(w, iw, ih)
                btns[#btns + 1] = w
            end
        else
            local btn = CreateIcon(gs, group, e.kind, e.id)
            if btn:GetParent() ~= frame then btn:SetParent(frame) end
            btn:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
            ns.Pixel.SetSize(btn, iw, ih)
            UpdateIcon(btn)
            if btn.count then
                local t = group.text or {}
                local font = (LSM and LSM:Fetch("font", t.countFont or "Expressway")) or STANDARD_TEXT_FONT

                E:SetFont(btn.count, font, t.countFontSize or 12, t.countFontOutline or "OUTLINE")
                local cc = t.countColor or {}
                btn.count:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
                local pt = t.countPoint or "BOTTOMRIGHT"
                btn.count:ClearAllPoints()
                btn.count:SetPoint(pt, btn, pt, t.countXOffset or 0, t.countYOffset or 0)
                btn.count:SetShown(t.showCount ~= false)
            end
            btns[#btns + 1] = btn
        end
    end

    if M.GetTrinketOwnerGroup() == group and ns.TrinketsCDM and ns.TrinketsCDM.GetGroupButtons then
        local tb = ns.TrinketsCDM.GetGroupButtons()
        if tb then
            local tcdb = E.db.thingsUI.trinketsCDM
            local atStart = (tcdb and tcdb.groupPosition == "START")
            for i = 1, #tb do
                local b = tb[i]
                if b:GetParent() ~= frame then b:SetParent(frame) end
                b:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
                ns.Pixel.SetSize(b, iw, ih)
                if atStart then table.insert(btns, i, b) else btns[#btns + 1] = b end
            end
        end
    end

    local n = #btns
    local lineLen = (perLine > 0) and perLine or n
    if lineLen < 1 then lineLen = 1 end
    local horizontal = (growth == "LEFT" or growth == "RIGHT")
    local wrapDir = group.wrapDir or (horizontal and "DOWN" or "RIGHT")
    local pt, alongSign, crossSign
    if horizontal then
        local h = (growth == "LEFT") and "RIGHT" or "LEFT"
        alongSign = (growth == "LEFT") and -1 or 1
        if wrapDir == "UP" then pt, crossSign = "BOTTOM" .. h, 1 else pt, crossSign = "TOP" .. h, -1 end
    else
        local v = (growth == "UP") and "BOTTOM" or "TOP"
        alongSign = (growth == "UP") and 1 or -1
        if wrapDir == "LEFT" then pt, crossSign = v .. "RIGHT", -1 else pt, crossSign = v .. "LEFT", 1 end
    end

    local alongDim = horizontal and iw or ih
    local crossDim = horizontal and ih or iw
    for i, btn in ipairs(btns) do
        btn:ClearAllPoints()
        local idx = i - 1
        local along = (idx % lineLen) * (alongDim + sp)
        local cross = math.floor(idx / lineLen) * (crossDim + sp)
        local x, y
        if horizontal then x, y = along * alongSign, cross * crossSign
        else               x, y = cross * crossSign, along * alongSign end
        ns.Pixel.SetPoint(btn, pt, frame, pt, x, y)
        btn:Show()
    end

    local lines = (n > 0) and math.ceil(n / lineLen) or 1
    local alongCount = math.min(lineLen, math.max(n, 1))
    local alongPx = alongCount * alongDim + math.max(0, alongCount - 1) * sp
    local crossPx = lines * crossDim + math.max(0, lines - 1) * sp
    if horizontal then
        ns.Pixel.SetSize(frame, alongPx, crossPx)
    else
        ns.Pixel.SetSize(frame, crossPx, alongPx)
    end

    local af = group.anchorFrame or "UIParent"
    if af == "CUSTOM" then af = group.anchorFrameCustom or "UIParent" end
    local SB = ns.SpecialBars
    local target = (af ~= "UIParent")
        and ((SB and SB.ResolveAnchorTarget and SB.ResolveAnchorTarget(af)) or _G[af])
        or nil
    frame:ClearAllPoints()
    ns.Pixel.SetPoint(frame, group.anchorPoint or "CENTER", target or _G.UIParent,
        group.anchorRelativePoint or "CENTER", group.anchorXOffset or 0, group.anchorYOffset or 0)

    frame:SetShown(n > 0)

    if ns.CDMText and ns.CDMText.StyleChild and group.text then
        for _, btn in ipairs(btns) do ns.CDMText.StyleChild(btn, group.text) end
    end
end

local function ApplyAll()
    local groups = GetGroups()
    local live = {}
    for _, g in ipairs(groups) do live[g.id] = true end
    for id, gs in pairs(groupState) do
        if not live[id] and gs.container then
            HideGroupIcons(gs)
            gs.container:Hide()
        end
    end
    for _, g in ipairs(groups) do ApplyGroup(g) end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

local queued = false
QueueLayout = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; ApplyAll() end)
end
M.QueueLayout = QueueLayout

if ns.Timers and ns.Timers.AddHostRefresh then
    ns.Timers.AddHostRefresh(QueueLayout)
end

if ns.Timers and ns.Timers.AddHostRepaint then
    local function TimerRepaint()
        local T, R = ns.Timers, ns.TimersRender
        if not (T and R) then return end
        local now = GetTime()
        local restructure = false
        for _, gs in pairs(groupState) do
            if gs.timerIcons then
                for _, b in pairs(gs.timerIcons) do
                    local t = T.GetByID(b._id)
                    if t then
                        if b:IsShown() then
                            R.Update(b, t)
                        elseif R.TimerActive(t, now) then
                            restructure = true
                        end
                    end
                end
            end
        end
        if restructure then QueueLayout() end
    end
    ns.Timers.AddHostRepaint(TimerRepaint)
end

if ns.TimersRender and ns.TimersRender.RegisterGlowHost then
    ns.TimersRender.RegisterGlowHost(function()
        local T = ns.Timers
        if not T then return end
        for _, gs in pairs(groupState) do
            if gs.timerIcons then
                for _, b in pairs(gs.timerIcons) do
                    if b:IsShown() then
                        local t = T.GetByID(b._id)
                        if t then ns.TimersRender.UpdateGlow(b, t) end
                    end
                end
            end
            if gs.itemIcons then
                for _, b in pairs(gs.itemIcons) do
                    if b:IsShown() and b._group then
                        local t = T.FindItemTimer(b._id, b._group.id)
                        if t then ns.TimersRender.UpdateGlow(b, t) end
                    end
                end
            end
        end
    end)
end

local function RefreshSpell(spellID)
    for _, gs in pairs(groupState) do
        for _, b in pairs(gs.spellIcons) do
            if b._id == spellID and b:IsShown() then UpdateSpellIcon(b) end
        end
    end
end
local function RefreshSpellsAll()
    for _, gs in pairs(groupState) do
        for _, b in pairs(gs.spellIcons) do if b:IsShown() then UpdateSpellIcon(b) end end
    end
end
local function RefreshItemsAll()
    for _, gs in pairs(groupState) do
        for _, b in pairs(gs.itemIcons) do if b:IsShown() then UpdateItemIcon(b) end end
    end
end

local _pendingCD = {}
local _cdThrottled = false
local function _cdThrottleTick()
    if not next(_pendingCD) then _cdThrottled = false; return end
    _cdThrottled = true
    C_Timer.After(0.1, _cdThrottleTick)
    for _, gs in pairs(groupState) do
        for _, b in pairs(gs.spellIcons) do
            if _pendingCD[b._id] and b:IsShown() then UpdateSpellIcon(b) end
        end
    end
    wipe(_pendingCD)
end
local function RefreshSpellThrottled(spellID)
    if _cdThrottled then
        _pendingCD[spellID] = true
        return
    end
    _cdThrottled = true
    C_Timer.After(0.1, _cdThrottleTick)
    RefreshSpell(spellID)
end

local function NextIndex(root)
    local mx = 0
    for _, d in pairs(root.spells or {}) do if (d.layoutIndex or 0) > mx then mx = d.layoutIndex end end
    for _, d in pairs(root.items  or {}) do if (d.layoutIndex or 0) > mx then mx = d.layoutIndex end end
    return mx + 1
end

function M.AddSpell(group, scope, key, spellID)
    spellID = tonumber(spellID)
    local root = M.GetScopeRoot(group, scope, key, true); if not (root and spellID) then return end
    if root.spells[spellID] then return end
    root.spells[spellID] = { enabled = true, layoutIndex = NextIndex(root) }
    QueueLayout()
end
function M.RemoveSpell(group, scope, key, spellID)
    spellID = tonumber(spellID)
    local root = M.GetScopeRoot(group, scope, key, false); if not (root and root.spells) then return end
    root.spells[spellID] = nil
    QueueLayout()
end
function M.AddItem(group, scope, key, itemID)
    itemID = tonumber(itemID)
    local root = M.GetScopeRoot(group, scope, key, true); if not (root and itemID) then return end
    if root.items[itemID] then return end
    root.items[itemID] = { enabled = true, layoutIndex = NextIndex(root) }
    QueueLayout()
end
function M.RemoveItem(group, scope, key, itemID)
    itemID = tonumber(itemID)
    local root = M.GetScopeRoot(group, scope, key, false); if not (root and root.items) then return end
    root.items[itemID] = nil
    QueueLayout()
end

function M.ResolveItemByName(text)
    if not text or text == "" then return nil end
    local id = C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(text)
    if id then return id end
    local lower = text:lower()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local iid = C_Container.GetContainerItemID(bag, slot)
            if iid then
                local nm = C_Item.GetItemInfo(iid)
                if nm and nm:lower():find(lower, 1, true) then return iid end
            end
        end
    end
    return nil
end
function M.AddItemByName(group, scope, key, text)
    local id = M.ResolveItemByName(text)
    if not id then return false end
    M.AddItem(group, scope, key, id)
    return true
end

function M.MoveEntry(group, scope, key, uid, dir)
    local list = {}
    local root = M.GetScopeRoot(group, scope, key, true)
    if root then
        for sid, d in pairs(root.spells or {}) do list[#list + 1] = { uid = "spell:" .. sid, ref = d, of = "layoutIndex", dflt = 999 } end
        for iid, d in pairs(root.items  or {}) do list[#list + 1] = { uid = "item:"  .. iid, ref = d, of = "layoutIndex", dflt = 999 } end
    end
    if ns.Timers then
        for _, t in ipairs(ns.Timers.GetTimers()) do
            if t.destination == group.id then
                local s = t.groupScope or "global"
                local inScope = (scope == "global" and s == "global")
                    or (scope == "spec"  and tostring(s) == tostring(key))
                    or (scope == "class" and s == key)
                if inScope then list[#list + 1] = { uid = "timer:" .. t.id, ref = t, of = "groupOrder", dflt = 10000 } end
            end
        end
    end
    if scope == "spec" and tostring(key) == tostring(GetCurrentSpecID()) and ns.SpecialBars then
        local SB = ns.SpecialBars
        for i = 1, (SB.GetIconCount and SB.GetIconCount() or 0) do
            local ikey = "icon" .. i
            local idb = SB.GetIconDB and SB.GetIconDB(ikey)
            if idb and idb.customGroup == group.id then list[#list + 1] = { uid = "si:" .. ikey, ref = idb, of = "customGroupOrder", dflt = 20000 } end
        end
    end
    table.sort(list, function(a, b)
        local la, lb = a.ref[a.of] or a.dflt, b.ref[b.of] or b.dflt
        if la == lb then return a.uid < b.uid end
        return la < lb
    end)
    for i, e in ipairs(list) do e.ref[e.of] = i end
    local pos
    for i, e in ipairs(list) do if e.uid == uid then pos = i break end end
    if not pos then return end
    local swap = pos + dir
    if swap < 1 or swap > #list then return end
    local a, b = list[pos], list[swap]
    a.ref[a.of], b.ref[b.of] = b.ref[b.of], a.ref[a.of]
    QueueLayout()
end

function M.MoveScope(group, scope, dir)
    group.scopeOrder = group.scopeOrder or { "global", "class", "spec" }
    local ord = group.scopeOrder
    local pos
    for i, s in ipairs(ord) do if s == scope then pos = i break end end
    if not pos then return end
    local swap = pos + dir
    if swap < 1 or swap > #ord then return end
    ord[pos], ord[swap] = ord[swap], ord[pos]
    QueueLayout()
end

function M.AddGroup()
    local db = EnsureDB(); if not db then return end
    local g = DefaultGroup(db.nextID, "Group " .. db.nextID)
    g.enabled = true
    db.nextID = db.nextID + 1
    db.groups[#db.groups + 1] = g
    QueueLayout()
    return g
end
function M.RemoveGroup(index)
    local db = EnsureDB(); if not db then return end
    local g = db.groups[index]
    if not g then return end

    local gs = groupState[g.id]
    if gs then
        HideGroupIcons(gs)
        if gs.container then gs.container:Hide() end
    end
    if ns.MoverSync and ns.MoverSync.RemoveManaged then
        ns.MoverSync.RemoveManaged("TUI_CustomGroupMover" .. g.id)
    end
    table.remove(db.groups, index)
    QueueLayout()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_CHARGES")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED"
       or event == "BAG_UPDATE_DELAYED" then
        QueueLayout()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if arg1 then RefreshSpellThrottled(arg1) end
    elseif event == "SPELL_UPDATE_CHARGES" then
        RefreshSpellsAll()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        RefreshItemsAll()
    end
end)

function TUI:UpdateCustomGroups()
    QueueLayout()
end
