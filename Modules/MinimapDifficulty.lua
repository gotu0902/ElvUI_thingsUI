local _, ns = ...
local TUI = ns.TUI
local E   = ns.E

local function DB() return E.db.thingsUI and E.db.thingsUI.instanceDifficulty end

local COLORS = {
    dungeon = "ff4fa8ff",
    raid    = "ffff8000",
    bg      = "ff40ff40",
    arena   = "ffff4060",
    mplus   = "ffa335ee",
}

local DIFF = {
    [1]   = { "N",   "dungeon" },
    [2]   = { "HC",  "dungeon" },
    [23]  = { "M",   "dungeon" },
    [24]  = { "TW",  "dungeon" },
    [205] = { "F",   "dungeon" },
    [3]   = { "N",   "raid" },
    [4]   = { "N",   "raid" },
    [5]   = { "HC",  "raid" },
    [6]   = { "HC",  "raid" },
    [9]   = { "N",   "raid" },
    [14]  = { "N",   "raid" },
    [15]  = { "HC",  "raid" },
    [16]  = { "M",   "raid" },
    [33]  = { "TW",  "raid" },
    [220] = { "S",   "raid" },
    [7]   = { "LFR", "raid" },
    [17]  = { "LFR", "raid" },
    [8]   = { "M+",  "mplus" },
    [11]  = { "HC",  "dungeon" },
    [12]  = { "N",   "dungeon" },
    [208] = { "D",   "dungeon" },
}

local INSET = {
    TOP = { 0, -2 }, BOTTOM = { 0, 2 }, LEFT = { 2, 0 }, RIGHT = { -2, 0 }, CENTER = { 0, 0 },
    TOPLEFT = { 2, -2 }, TOPRIGHT = { -2, -2 }, BOTTOMLEFT = { 2, 2 }, BOTTOMRIGHT = { -2, 2 },
}

local frame
local function BlizzFlag() return _G.MinimapCluster and _G.MinimapCluster.InstanceDifficulty end

local function Ensure()
    if frame then return frame end
    frame = CreateFrame("Frame", "TUI_InstanceDifficulty", _G.Minimap)
    frame:SetSize(60, 20)
    frame:SetFrameLevel(_G.Minimap:GetFrameLevel() + 10)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    return frame
end

local function Generate()
    local db = DB()
    if not (db and db.enable and frame) then return end
    local inInstance, iType = IsInInstance()
    local txt = ""
    if inInstance then
        if iType == "arena" then
            local size
            if C_PvP and C_PvP.GetActiveMatchBracket then
                local b = C_PvP.GetActiveMatchBracket()
                size = (b == 0 and "2v2") or (b == 1 and "3v3") or (b == 2 and "5v5")
            end
            txt = "|c" .. COLORS.arena .. (size or "Arena") .. "|r"
        elseif iType == "pvp" then
            local _, _, _, _, maxP, _, _, _, groupSize = GetInstanceInfo()
            txt = "|cffffffff" .. (groupSize or maxP or "") .. "|r|c" .. COLORS.bg .. "BG|r"
        else
            local _, _, difficulty, diffName, _, _, _, _, groupSize = GetInstanceInfo()
            local d = DIFF[difficulty]
            if difficulty == 8 then
                local lvl = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo()
                txt = "|c" .. COLORS.mplus .. "M+|r" .. ((lvl and lvl > 0) and ("|cffffffff" .. lvl .. "|r") or "")
            else
                local suffix = d and d[1] or (diffName and diffName ~= "" and diffName:sub(1, 1)) or "?"
                local cat = d and d[2] or (iType == "raid" and "raid" or "dungeon")
                txt = "|cffffffff" .. (groupSize or "") .. "|r|c" .. (COLORS[cat] or "ffffffff") .. suffix .. "|r"
            end
        end
    end
    frame.text:SetText(txt)
    local flag = BlizzFlag()
    if flag and flag:IsShown() then flag:Hide() end
end

local hooked = false
local function InstallHooks()
    if hooked then return end
    local flag = BlizzFlag()
    if not flag then return end
    hooked = true
    flag:HookScript("OnShow", function(f)
        local db = DB()
        if db and db.enable then f:Hide() end
    end)
    if flag.Update then
        hooksecurefunc(flag, "Update", function()
            local db = DB()
            if db and db.enable then Generate() end
        end)
    end
end

function TUI:UpdateInstanceDifficulty()
    local db = DB()
    if not db then return end
    if db.enable then
        local f = Ensure()
        InstallHooks()
        local font = (E.Libs and E.Libs.LSM and E.Libs.LSM:Fetch("font", db.font or "Expressway")) or STANDARD_TEXT_FONT
        local flag = (db.fontOutline ~= "NONE") and (db.fontOutline or "OUTLINE") or ""
        f.text:SetFont(font, db.fontSize or 12, flag)
        local point = db.point or "TOPLEFT"
        local ins = INSET[point] or INSET.TOPLEFT
        f:ClearAllPoints()
        f:SetPoint(point, _G.Minimap, point, ins[1] + (db.x or 0), ins[2] + (db.y or 0))
        f.text:ClearAllPoints()
        f.text:SetPoint(point, f, point, 0, 0)
        f:Show()
        Generate()
    else
        if frame then
            frame:Hide()
            frame.text:SetText("")
        end
        local flag = BlizzFlag()
        if flag and IsInInstance() then flag:Show() end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UPDATE_INSTANCE_INFO")
ev:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
ev:RegisterEvent("CHALLENGE_MODE_START")
ev:SetScript("OnEvent", function()
    local db = DB()
    if db and db.enable then
        if not frame then TUI:UpdateInstanceDifficulty() else Generate() end
    end
end)
