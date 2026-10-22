local _, ns = ...
local E = ns.E

-- The active layout as raid-frame rectangles, placed the way ElvUI's raid header
-- grows. Drag one onto another to take its place; Save writes the list back.

local RO = ns.RaidOrder
local ED = {}
RO.Editor = ED

local ROLE_ORDERS = { "TDH", "THD", "DTH", "DHT", "HTD", "HDT" }
local ROLE_KEY = { T = "TANK", D = "DAMAGER", H = "HEALER" }
local ROLE_LABEL = { TANK = "Tank", DAMAGER = "DPS", HEALER = "Healer" }
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local GAP, TOP, BOTTOM = 3, 76, 92

local frame, ghost, seq, drag
local cells = {}

local function Skins() return E:GetModule("Skins", true) end

local function RoleOrderText(order)
    local t = {}
    for i = 1, 3 do t[i] = ROLE_LABEL[ROLE_KEY[order:sub(i, i)]] end
    return table.concat(t, " > ")
end

-- the raid header in use, else Raid 1
local function LayoutDB()
    local uf = E:GetModule("UnitFrames", true)
    for _, g in ipairs(RO.GROUPS) do
        local H = uf and uf[g]
        if H and H.db and H:IsVisible() then return H.db end
    end
    return E.db.unitframe.units.raid1
end

-- the saved list, then group members not on it yet
local function BuildSeq()
    local roster = RO.Roster() or {}
    local seen = RO.Store().seen
    local byShort = {}
    for l in pairs(roster) do
        local s = RO.StripRealm(l)
        byShort[s] = byShort[s] or l
    end
    local out, used = {}, {}
    for _, entry in ipairs(RO.ActiveList()) do
        local l = entry:lower()
        local key = roster[l] and l or byShort[RO.StripRealm(l)]
        local m = key and not used[key] and roster[key]
        if m then used[key] = true end
        local s = seen[l]
        out[#out + 1] = {
            name = m and m.name or entry,
            class = m and m.class or (s and s.c),
            role = m and m.role or (s and s.r),
            present = m and true or false,
        }
    end
    local extra = {}
    for l, m in pairs(roster) do
        if not used[l] then extra[#extra + 1] = m end
    end
    table.sort(extra, function(a, b) return a.name < b.name end)
    for _, m in ipairs(extra) do
        out[#out + 1] = { name = m.name, class = m.class, role = m.role, present = true, new = true }
    end
    return out
end

-- role order, same classes together if wanted; ties keep the current order
local function SortByRole()
    local r = RO.Store()
    local order = r.roleOrder or "TDH"
    local rank = {}
    for i = 1, 3 do rank[ROLE_KEY[order:sub(i, i)]] = i end
    local first = {}
    for i, it in ipairs(seq) do
        it.i = i
        local k = (it.role or "") .. ":" .. (it.class or "")
        first[k] = first[k] or i
    end
    local stack = r.stackClasses ~= false
    table.sort(seq, function(a, b)
        local ra, rb = rank[a.role] or 4, rank[b.role] or 4
        if ra ~= rb then return ra < rb end
        if stack then
            local ca = first[(a.role or "") .. ":" .. (a.class or "")]
            local cb = first[(b.role or "") .. ":" .. (b.class or "")]
            if ca ~= cb then return ca < cb end
        end
        return a.i < b.i
    end)
end

local function Paint(c, it, i)
    local col = it.class and (E:ClassColor(it.class) or RAID_CLASS_COLORS[it.class])
    local dim = it.present and 1 or 0.45
    if col then
        c.fill:SetVertexColor(col.r * dim, col.g * dim, col.b * dim, 0.85)
    else
        c.fill:SetVertexColor(0.25, 0.25, 0.25, 0.85)
    end
    c.name:SetText(RO.StripRealm(it.name))
    c.name:SetTextColor(it.present and 1 or 0.6, it.present and 1 or 0.6, it.present and 1 or 0.6)
    local atlas = it.role and ROLE_ATLAS[it.role]
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        c.role:SetAtlas(atlas)
        c.role:Show()
    else
        c.role:Hide()
    end
    c.num:SetText(i)
    if it.new then c.num:SetTextColor(0.3, 1, 0.4) else c.num:SetTextColor(0.8, 0.8, 0.8) end
end

local Layout

local function Move(from, to)
    if not (seq[from] and to) or from == to then return end
    to = math.max(1, math.min(to, #seq))
    local it = table.remove(seq, from)
    table.insert(seq, to, it)
    Layout()
end

local function StopDrag(commit)
    if not drag then return end
    local from, to = drag, ghost and ghost.target
    drag = nil
    if ghost then
        ghost:Hide()
        ghost.target = nil
    end
    for _, c in ipairs(cells) do
        c:SetAlpha(1)
        c.drop:Hide()
    end
    if commit then Move(from, to) end
end

local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost.fill = ghost:CreateTexture(nil, "ARTWORK")
    ghost.fill:SetAllPoints()
    ghost.fill:SetTexture(E.media.normTex)
    ghost.name = ghost:CreateFontString(nil, "OVERLAY")
    ghost.name:FontTemplate(nil, 11, "OUTLINE")
    ghost.name:SetPoint("CENTER")
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        local target
        for i = 1, #seq do
            local c = cells[i]
            if c and c:IsShown() and c:IsMouseOver() then target = i break end
        end
        if target ~= self.target then
            if self.target and cells[self.target] then cells[self.target].drop:Hide() end
            self.target = target
            if target and target ~= drag then cells[target].drop:Show() end
        end
    end)
    ghost:Hide()
    return ghost
end

local function StartDrag(c)
    local it = seq[c.idx]
    if not it then return end
    drag = c.idx
    local g = Ghost()
    g:SetSize(c:GetSize())
    g.fill:SetVertexColor(c.fill:GetVertexColor())
    g.name:SetText(RO.StripRealm(it.name))
    g.target = nil
    g:Show()
    c:SetAlpha(0.35)
end

local function Tooltip(c)
    local it = seq[c.idx]
    if not it then return end
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    GameTooltip:AddLine(it.name, 1, 1, 1)
    if it.role and ROLE_LABEL[it.role] then GameTooltip:AddLine(ROLE_LABEL[it.role], 0.8, 0.8, 0.8) end
    if it.new then
        GameTooltip:AddLine("Not on the list yet: Save adds them", 0.3, 1, 0.4)
    elseif not it.present then
        GameTooltip:AddLine("Not in your group - right-click removes", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function Cell(i)
    local c = cells[i]
    if c then return c end
    c = CreateFrame("Button", nil, frame.grid)
    c:SetTemplate()
    c:RegisterForDrag("LeftButton")
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.fill = c:CreateTexture(nil, "ARTWORK")
    c.fill:SetPoint("TOPLEFT", 1, -1)
    c.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    c.fill:SetTexture(E.media.normTex)
    c.role = c:CreateTexture(nil, "OVERLAY")
    c.role:SetSize(12, 12)
    c.role:SetPoint("TOPLEFT", 3, -3)
    c.num = c:CreateFontString(nil, "OVERLAY")
    c.num:FontTemplate(nil, 9, "OUTLINE")
    c.num:SetPoint("TOPRIGHT", -3, -3)
    c.name = c:CreateFontString(nil, "OVERLAY")
    c.name:FontTemplate(nil, 11, "OUTLINE")
    c.name:SetPoint("BOTTOMLEFT", 3, 3)
    c.name:SetPoint("BOTTOMRIGHT", -3, 3)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.drop = c:CreateTexture(nil, "OVERLAY", nil, 7)
    c.drop:SetAllPoints()
    c.drop:SetColorTexture(0.3, 0.82, 0.65, 0.45)
    c.drop:Hide()
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    c:SetScript("OnDragStart", StartDrag)
    c:SetScript("OnDragStop", function() StopDrag(true) end)
    c:SetScript("OnClick", function(self, button)
        local it = seq[self.idx]
        if button == "RightButton" then
            if it and not it.present then
                table.remove(seq, self.idx)
                GameTooltip:Hide()
                Layout()
            end
        elseif IsShiftKeyDown() then
            Move(self.idx, 1)
        end
    end)
    c:SetScript("OnEnter", Tooltip)
    c:SetScript("OnLeave", GameTooltip_Hide)
    cells[i] = c
    return c
end

Layout = function()
    local db = LayoutDB()
    local a, b = (db.growthDirection or "RIGHT_DOWN"):match("^(%u+)_(%u+)$")
    local pa, pb = STEP[a] or STEP.RIGHT, STEP[b] or STEP.DOWN
    local perLine = db.raidWideSorting and math.max(1, (db.groupsPerRowCol or 1) * 5) or 5
    local w = math.min(math.max(db.width or 80, 60), 110)
    local h = math.min(math.max(db.height or 40, 26), 50)
    local n = #seq
    local pos, minX, maxX, minY, maxY = {}, 0, 0, 0, 0
    for k = 0, n - 1 do
        local along, line = k % perLine, math.floor(k / perLine)
        local x = (pa[1] * along + pb[1] * line) * (w + GAP)
        local y = (pa[2] * along + pb[2] * line) * (h + GAP)
        pos[k + 1] = { x, y }
        minX, maxX = math.min(minX, x), math.max(maxX, x)
        minY, maxY = math.min(minY, y), math.max(maxY, y)
    end
    for i, it in ipairs(seq) do
        local c = Cell(i)
        c.idx = i
        c:SetSize(w, h)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", pos[i][1] - minX, pos[i][2] - maxY)
        Paint(c, it, i)
        c:Show()
    end
    for i = n + 1, #cells do cells[i]:Hide() end
    local gw = n > 0 and (maxX - minX + w) or 300
    local gh = n > 0 and (maxY - minY + h) or 30
    frame.grid:SetSize(gw, gh)
    frame.empty:SetShown(n == 0)
    frame.note:SetText(db.raidWideSorting and ""
        or "ElvUI's Raid-Wide Sorting is off: the order applies inside each group.")
    frame:SetSize(math.max(gw + 24, 500), TOP + gh + BOTTOM)
end

local function Button(text, w, onClick)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(w, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    local S = Skins()
    if S and S.HandleButton then S:HandleButton(btn) end
    return btn
end

local function Build()
    frame = CreateFrame("Frame", "TUI_RaidBuilderFrame", UIParent)
    frame:SetTemplate("Transparent")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function() StopDrag(false) end)
    tinsert(UISpecialFrames, "TUI_RaidBuilderFrame")

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:FontTemplate(nil, 14, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", 12, -10)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local S = Skins()
    if S and S.HandleCloseButton then S:HandleCloseButton(close) end

    local roleBtn = Button("", 170, nil)
    roleBtn:SetPoint("TOPLEFT", 12, -38)
    local ARROW = " |TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-2:32:32:0:32:32:0|t"
    local function RoleText() roleBtn:SetText(RoleOrderText(RO.Store().roleOrder or "TDH") .. ARROW) end
    local function PickOrder(o)
        RO.Store().roleOrder = o
        RoleText()
        SortByRole()
        Layout()
    end
    -- every order in a menu: a button that cycles on click doesn't read as a choice
    roleBtn:SetScript("OnClick", function(self)
        local menu = MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("Sort by Role order")
            for _, o in ipairs(ROLE_ORDERS) do
                root:CreateRadio(RoleOrderText(o),
                    function() return (RO.Store().roleOrder or "TDH") == o end,
                    function() PickOrder(o) end)
            end
        end)
        -- above the builder, which sits in FULLSCREEN_DIALOG itself
        if menu and menu.SetFrameStrata then menu:SetFrameStrata("TOOLTIP") end
    end)
    frame.roleText = RoleText

    local sortBtn = Button("Sort by Role", 110, function() SortByRole() Layout() end)
    sortBtn:SetPoint("LEFT", roleBtn, "RIGHT", 6, 0)

    local stack = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    stack:SetSize(22, 22)
    stack:SetPoint("LEFT", sortBtn, "RIGHT", 8, 0)
    if S and S.HandleCheckBox then S:HandleCheckBox(stack) end
    local stackLabel = frame:CreateFontString(nil, "OVERLAY")
    stackLabel:FontTemplate(nil, 12)
    stackLabel:SetPoint("LEFT", stack, "RIGHT", 4, 0)
    stackLabel:SetText("Stack Classes")
    stack:SetScript("OnClick", function(self)
        RO.Store().stackClasses = self:GetChecked() and true or false
        SortByRole()
        Layout()
    end)
    frame.stack = stack

    frame.grid = CreateFrame("Frame", nil, frame)
    frame.grid:SetPoint("TOPLEFT", 12, -TOP)
    frame.empty = frame.grid:CreateFontString(nil, "OVERLAY")
    frame.empty:FontTemplate(nil, 12)
    frame.empty:SetPoint("TOPLEFT")
    frame.empty:SetText("No names yet: join a group, or add names in the options.")

    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:FontTemplate(nil, 11)
    hint:SetPoint("BOTTOMLEFT", 12, 58)
    hint:SetPoint("BOTTOMRIGHT", -12, 58)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetText("Drag a frame onto another to take its place. Shift-click sends it to the front.\nDim = not in your group, green number = not on the list yet.")

    frame.note = frame:CreateFontString(nil, "OVERLAY")
    frame.note:FontTemplate(nil, 11)
    frame.note:SetPoint("BOTTOMLEFT", 12, 40)
    frame.note:SetTextColor(1, 0.82, 0.3)

    local save = Button("Save", 100, function()
        local r = RO.Store()
        local list = {}
        for _, it in ipairs(seq) do list[#list + 1] = it.name end
        r.layouts[r.active] = list
        for _, it in ipairs(seq) do
            if it.present then RO.Remember(it.name, it.class, it.role) end
        end
        RO.Changed()
        ns.NotifyChange()
        frame:Hide()
    end)
    save:SetPoint("BOTTOMRIGHT", -12, 10)
    local cancel = Button("Cancel", 100, function() frame:Hide() end)
    cancel:SetPoint("RIGHT", save, "LEFT", -6, 0)
    local reset = Button("Reset", 100, function()
        seq = BuildSeq()
        Layout()
    end)
    reset:SetPoint("BOTTOMLEFT", 12, 10)
end

function ED.Open()
    if not frame then Build() end
    seq = BuildSeq()
    frame.title:SetText("Raid Frame Builder  |cFF888888" .. RO.Store().active .. "|r")
    frame.roleText()
    frame.stack:SetChecked(RO.Store().stackClasses ~= false)
    Layout()
    frame:Show()
    frame:Raise()
end
