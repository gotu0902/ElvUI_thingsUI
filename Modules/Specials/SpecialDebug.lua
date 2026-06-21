local _, ns = ...
local E = ns.E
local SB = ns.SpecialBars

-- /tuispecial debug dumperino
local function _yn(b) return b and "Y" or "n" end
local function _parentName(frame)
    local p = frame and frame:GetParent()
    if not p then return "nil" end
    return (p.GetName and p:GetName()) or tostring(p)
end
local function _safeName(child)
    if not (child and child.Bar and child.Bar.Name) then return "-" end
    local raw = child.Bar.Name:GetText()
    if raw == nil then return "<nil>" end
    if issecretvalue(raw) then return "<secret>" end
    return (SB.CleanString and SB.CleanString(raw)) or tostring(raw)
end
local function _liveMatch(spellID, wantsBar)
    if not spellID then return "noSID" end
    local viewer = wantsBar and BuffBarCooldownViewer or BuffIconCooldownViewer
    if viewer then
        local kids = { viewer:GetChildren() }
        for i = 1, #kids do
            if SB.SafeMatch(kids[i], spellID, wantsBar) then return "viewer#" .. i end
        end
    end
    for child in pairs(SB.yoinkedBars or {}) do
        if SB.SafeMatch(child, spellID, wantsBar) then return "yoinked" end
    end
    return "NONE"
end
local function _pt(frame)
    if not frame then return "noframe" end
    local p, rel, rp, x, y = frame:GetPoint()
    if not p then return "NOPOINT" end
    local relName = (rel and rel.GetName and rel:GetName()) or tostring(rel)
    return ("%s@%s:%s %d,%d"):format(p, relName, tostring(rp), math.floor((x or 0)+0.5), math.floor((y or 0)+0.5))
end

SLASH_TUISPECIAL1 = "/tuispecial"
SlashCmdList.TUISPECIAL = function()
    if not SB then return end
    print(("|cFF8080FFthingsUI Special|r --- dump --- combat=%s barChildren=%s iconChildren=%s")
        :format(tostring(InCombatLockdown()),
            tostring(BuffBarCooldownViewer  and BuffBarCooldownViewer:GetNumChildren()),
            tostring(BuffIconCooldownViewer and BuffIconCooldownViewer:GetNumChildren())))
    local bdb = E.db.thingsUI and E.db.thingsUI.buffBars
    if bdb then
        print(("|cFF88FF88BuffBarViewer|r live=%s | cfg anchorEnabled=%s frame=%s %s->%s %s,%s")
            :format(_pt(BuffBarCooldownViewer), tostring(bdb.anchorEnabled), tostring(bdb.anchorFrame),
                tostring(bdb.anchorPoint), tostring(bdb.anchorRelativePoint),
                tostring(bdb.anchorXOffset), tostring(bdb.anchorYOffset)))
    end
    for i = 1, SB.GetBarCount() do
        local key = "bar" .. i
        local db = SB.GetBarDB(key)
        if db and db.enabled and db.spellID then
            local st = SB.specialBarState[key]
            local child = st and st.childFrame
            local anchorName = (db.anchorMode ~= "CUSTOM") and db.anchorMode or db.anchorFrame
            local anchorTgt = SB.ResolveAnchorTarget and SB.ResolveAnchorTarget(anchorName)
            print(("|cFFFFD200%s|r sid=%s '%s' | held=%s parent=%s shown=%s yoink=%s name=%s | liveMatch=%s wrapShown=%s wrapPt=%s anchor=%s->%s")
                :format(key, tostring(db.spellID), tostring(db.spellName),
                    _yn(child), child and _parentName(child) or "-",
                    child and _yn(child:IsShown()) or "-",
                    child and _yn(SB.yoinkedBars[child]) or "-",
                    child and _safeName(child) or "-",
                    _liveMatch(db.spellID, true),
                    (st and st.wrapper) and _yn(st.wrapper:IsShown()) or "-",
                    (st and st.wrapper) and _pt(st.wrapper) or "-",
                    tostring(anchorName), anchorTgt and (anchorTgt.GetName and anchorTgt:GetName() or "unnamed") or "nil"))
        end
    end
    for i = 1, SB.GetIconCount() do
        local key = "icon" .. i
        local db = SB.GetIconDB(key)
        if db and db.enabled and db.spellID then
            local st = SB.iconGroupState[key]
            local child = st and st.childFrame
            print(("|cFFFFD200%s|r sid=%s '%s' | held=%s parent=%s shown=%s yoink=%s | liveMatch=%s wrap=%s")
                :format(key, tostring(db.spellID), tostring(db.spellName),
                    _yn(child), child and _parentName(child) or "-",
                    child and _yn(child:IsShown()) or "-",
                    child and _yn(SB.yoinkedBars[child]) or "-",
                    _liveMatch(db.spellID, false),
                    (st and st.wrapper) and _yn(st.wrapper:IsShown()) or "-"))
        end
    end
end
