local _, ns = ...
local E = ns.E

-- a pack profile (NHT / FHT) is told when a newer version changes the pack, and picks what to take
local M = {}
ns.PackUpdate = M

local PACKS = { NHT = true, FHT = true }

local function Store()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local st = _G.thingsUIGlobalDB
    st.packState = st.packState or {}
    return st
end

local function Res() return ns.Setup and ns.Setup.Res and ns.Setup.Res() or "1440p" end
local function PackStr(key, res) return ns.InstallString(key .. "_PLUGIN", res) end

local function Prints(diff)
    local out = {}
    for i, list in pairs(diff) do
        for _, it in ipairs(list) do out[i .. "|" .. it.ident] = it.pack end
    end
    return out
end

-- this profile now holds the pack as shipped (installed, updated, or the update was declined)
function M.Record(key, res, str)
    local profile = ns.Share.CurrentProfile()
    str = str or PackStr(key, res or Res())
    if not (profile and str) then return end
    local data = ns.Share.Decode(str)
    if not data then return end
    Store().packState[profile] = {
        pack = key, res = res or Res(), version = ns.Share.Print(str), prints = Prints(ns.Share.PackDiff(data)),
    }
end

-- what the pack changed since this profile last took it, against what it has now: "new" (not here),
-- "pack" (only the pack changed it), "mine" (changed here too), "diff" (no record of the last pack)
function M.Changes(key, res, rec)
    local str = PackStr(key, res)
    local data = str and ns.Share.Decode(str)
    if not data then return nil end
    local base = rec and rec.prints
    local up, n, names = {}, 0, {}
    for i, list in pairs(ns.Share.PackDiff(data)) do
        for _, it in ipairs(list) do
            local b = base and base[i .. "|" .. it.ident]
            local st
            if it.pack == it.cur or (b and b == it.pack) then
                st = nil
            elseif not it.cur then
                st = b and "mine" or "new"
            elseif b and b == it.cur then
                st = "pack"
            else
                st = base and "mine" or "diff"
            end
            if st then
                up[i] = up[i] or {}
                up[i][it.id] = st
                n = n + 1
                names[#names + 1] = it.label
            end
        end
    end
    return up, n, names, str
end

-- no hideOnEscape: ElvUI's popup would take every key press, keybinds included
E.PopupDialogs.TUI_PACK_UPDATE = {
    text = "%s", selectCallbackByIndex = true, timeout = 0, whileDead = 1, preferredIndex = 3,
    button1 = "Review", button2 = "Not Now", button3 = "Skip This Update",
    OnShow = function(self) self:SetScript("OnKeyDown", nil) end,
    OnButton1 = function(_, d) if d then M.Review(d) end end,
    OnButton2 = function() end,
    OnButton3 = function(_, d) if d then M.Record(d.key, d.res, d.str) end end,
}

function M.Review(d)
    local W = ns.ShareWizard
    if not W then return end
    W.Open(d.str, {
        title = d.key .. " setup update",
        update = d.up,
        onApplied = function() M.Record(d.key, d.res, d.str) end,
    })
end

-- manual: also when this version was seen already, and it says so when there's nothing
function M.Check(manual)
    local st = Store()
    if not st.installComplete and not manual then return end
    local profile = ns.Share.CurrentProfile()
    local rec = profile and st.packState[profile]
    local key = (rec and rec.pack) or (profile and PACKS[profile] and profile)
    if not key then
        if manual then print("|cFF8080FFthingsUI|r: this profile wasn't set up from a thingsUI pack (NHT / FHT).") end
        return
    end
    local res = (rec and rec.res) or Res()
    local str = PackStr(key, res)
    if not str then return end
    if rec and rec.version == ns.Share.Print(str) and not manual then return end
    local up, n, names = M.Changes(key, res, rec)
    if not up then return end
    if n == 0 then
        M.Record(key, res, str)
        if manual then print("|cFF8080FFthingsUI|r: your " .. key .. " setup has everything the pack has.") end
        return
    end
    local list = table.concat(names, ", ", 1, math.min(#names, 6)) .. ((#names > 6) and (" and %d more"):format(#names - 6) or "")
    E:StaticPopup_Show("TUI_PACK_UPDATE",
        ("|cFF8080FFthingsUI|r: the |cFFFFD200%s|r setup has %d update(s):\n%s\n\nReview them? Nothing changes unless you tick it."):format(key, n, list),
        nil, { key = key, res = res, str = str, up = up })
end

ns.SlashCommand("updates", function() M.Check(true) end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(8, function()
        if InCombatLockdown() then return end
        M.Check(false)
    end)
end)
