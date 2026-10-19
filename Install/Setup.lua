local _, ns = ...
local E = ns.E

-- Character setup (/tui alt): installs the pack's profiles and layouts and
-- loads the right ones on each character. ElvUI and BigWigs switch per spec
-- on classes with a healer spec (or Augmentation): FHT there, NHT elsewhere.

ns.Setup = ns.Setup or {}
local M = ns.Setup
local PACK = ns.InstallPack or {}

local RES = { "1440p", "1080p" }
local FOLLOW = "\001spec"
local AUGMENTATION = 1473

local function Say(msg) print("|cFF8080FFthingsUI|r Setup: " .. msg) end

local function CharKey()
    return E.mynameRealm or ((UnitName("player") or "?") .. " - " .. (GetRealmName() or "?"))
end

local function DB()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    local g = _G.thingsUIGlobalDB
    local s = g.setup
    if type(s) ~= "table" then s = {}; g.setup = s end
    s.done = s.done or {}
    s.pick = s.pick or {}
    s.skip = s.skip or {}
    s.fp = s.fp or {}
    s.cdm = s.cdm or {}
    s.roles = s.roles or {}
    return s
end

local function Stamps(key)
    local fp = DB().fp
    fp[key] = fp[key] or {}
    return fp[key]
end

local function ResString(t, res)
    local s = t and (t[res] or t.all)
    s = s and strtrim(s)
    if s and s ~= "" then return s end
end

-- ------------------------------------------------------------ resolution

local function HasRes(res) return ns.InstallString("NHT_PROFILE", res) ~= nil end

local function DetectRes()
    local _, h = GetPhysicalScreenSize()
    return (h and h >= 1300) and "1440p" or "1080p"
end

-- the stored pick, else this screen, else whatever has strings
function M.Res()
    for _, want in ipairs({ DB().res, DetectRes() }) do
        if want and HasRes(want) then return want end
    end
    for _, r in ipairs(RES) do
        if HasRes(r) then return r end
    end
    return "1440p"
end
local Res = M.Res

-- -------------------------------------------------------------- spec rule

local function NumSpecs()
    local classID = select(3, UnitClass("player"))
    local getNum = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
        or GetNumSpecializationsForClassID
    return classID and getNum and getNum(classID) or 0
end

local function SpecKeyFor(classID, n)
    local specID, _, _, _, role = GetSpecializationInfoForClassID(classID, n)
    return (role == "HEALER" or specID == AUGMENTATION) and "FHT" or "NHT"
end

-- per spec index; mixed = the class has a spec that uses FHT
local function ClassSpecKeys()
    local classID = select(3, UnitClass("player"))
    local keys, mixed = {}, false
    for n = 1, NumSpecs() do
        keys[n] = SpecKeyFor(classID, n)
        if keys[n] == "FHT" then mixed = true end
    end
    return keys, mixed
end

function M.SpecPackKey()
    local n = GetSpecialization and GetSpecialization()
    local classID = select(3, UnitClass("player"))
    if not (n and classID) then return "NHT" end
    return SpecKeyFor(classID, n)
end

-- the profile for Tank & DPS ("NHT") or Healer + Aug ("FHT"): the account's pick, else the pack's name
local function RoleProfile(p, key)
    local r = DB().roles[p.key]
    local name = r and r[key]
    if name and p.hasProfile(name) then return name end
    return key
end

-- spec index -> profile; nil when one profile does (no healer spec, or one is missing)
local function FollowMap(p)
    local keys, mixed = ClassSpecKeys()
    if not mixed then return nil end
    local map = {}
    for n, key in ipairs(keys) do
        local name = RoleProfile(p, key)
        if not p.hasProfile(name) then return nil end
        map[n] = name
    end
    return map
end

local function FollowText(p)
    local dps = RoleProfile(p, "NHT")
    if not FollowMap(p) then return dps end
    local classID = select(3, UnitClass("player"))
    local heal = {}
    for n, key in ipairs((ClassSpecKeys())) do
        if key == "FHT" then heal[#heal + 1] = select(2, GetSpecializationInfoForClassID(classID, n)) or "?" end
    end
    return ("%s, %s on %s"):format(dps, RoleProfile(p, "FHT"), table.concat(heal, " + "))
end

-- LibDualSpec keeps its state in a namespace; the public getter reads "off" below level 10
local function DSChar(db)
    local n = db.GetNamespace and db:GetNamespace("LibDualSpec-1.0", true)
    return n and n.char
end

local function DSOn(db)
    local c = DSChar(db)
    return c and c.enabled or false
end

local function DSFollowing(db, map)
    local c = DSChar(db)
    if not (c and c.enabled) then return false end
    for n, name in ipairs(map) do
        if c[n] ~= name then return false end
    end
    return true
end

-- on `name`, and no spec slot moves it elsewhere
local function DSFixed(db, name)
    if db:GetCurrentProfile() ~= name then return false end
    local c = DSChar(db)
    if not (c and c.enabled) then return true end
    for n = 1, NumSpecs() do
        if c[n] ~= nil and c[n] ~= name then return false end
    end
    return true
end

local function DSApply(db, map)
    if not DSOn(db) then db:SetDualSpecEnabled(true) end
    for n, name in ipairs(map) do db:SetDualSpecProfile(name, n) end
end

local function DSUse(db, name)
    -- spec profiles would undo it on the next spec change
    if DSOn(db) then db:SetDualSpecEnabled(false) end
    if db:GetCurrentProfile() ~= name then db:SetProfile(name) end
end

-- ------------------------------------------------------------- popups

local needReload = false

E.PopupDialogs.TUI_SETUP_CONFIRM = {
    text = "%s",
    button1 = "Overwrite", button2 = "Keep Mine",
    OnAccept = function(_, d) d.yes() end,
    OnCancel = function(_, d) d.no() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

local function Confirm(title, message, onYes, onNo)
    E:StaticPopup_Show("TUI_SETUP_CONFIRM", ("|cFF8080FFthingsUI|r %s\n\n%s"):format(title, message), nil,
        { yes = onYes, no = onNo })
end

E.PopupDialogs.TUI_SETUP_RELOAD = {
    text = "|cFF8080FFthingsUI|r: what you set takes effect after a reload.",
    button1 = "Reload Now", button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

local function AskReload()
    if needReload then E:StaticPopup_Show("TUI_SETUP_RELOAD") end
end

local function HideForbiddenPopup()
    if StaticPopup_Hide then StaticPopup_Hide("ADDON_ACTION_FORBIDDEN") end
end

local function Fingerprint(str)
    local h = 2166136261
    for n = 1, #str do
        h = bit.bxor(h, str:byte(n)) % 4294967296
        -- FNV-1a prime 2^24 + 403, split so the product stays exact in a double
        h = (h * 403 + (h % 256) * 16777216) % 4294967296
    end
    return ("%08x-%d"):format(h, #str)
end

-- ------------------------------------------------------------ providers

local PROVIDERS = {}

local function Sorted(list)
    local out = {}
    for _, n in ipairs(list or {}) do out[#out + 1] = n end
    table.sort(out)
    return out
end

-- AceDB + LibDualSpec addons: one profile for Tank & DPS, one for Healer + Aug (NHT / FHT by default)
local function SpecProvider(p)
    p.perChar = true
    p.roles = true
    p.pack = function() return FOLLOW end
    p.label = function(name)
        if name ~= FOLLOW then return name end
        return ("Per spec: %s / %s"):format(RoleProfile(p, "NHT"), RoleProfile(p, "FHT"))
    end
    p.useText = function(name) return name == FOLLOW and FollowText(p) or name end
    p.list = function()
        local out = { FOLLOW }
        for _, n in ipairs(Sorted(p.profiles())) do out[#out + 1] = n end
        return out
    end
    p.exists = function(name) return p.hasProfile(name == FOLLOW and RoleProfile(p, "NHT") or name) end
    p.current = function()
        local db, map = p.db(), FollowMap(p)
        if map and DSFollowing(db, map) then return FOLLOW end
        return db:GetCurrentProfile()
    end
    p.matches = function(want)
        local db = p.db()
        if want ~= FOLLOW then return DSFixed(db, want) end
        local map = FollowMap(p)
        if map then return DSFollowing(db, map) end
        return DSFixed(db, RoleProfile(p, "NHT"))
    end
    p.load = function(want)
        local db = p.db()
        local map = want == FOLLOW and FollowMap(p)
        if map then DSApply(db, map) else DSUse(db, want == FOLLOW and RoleProfile(p, "NHT") or want) end
    end
    return p
end

local function ElvProfile(name) return _G.ElvDB and _G.ElvDB.profiles and _G.ElvDB.profiles[name] ~= nil end

local ELVUI = SpecProvider({
    key = "elvui", title = "ElvUI", color = "8080FF",
    loaded = function() return E.data ~= nil end,
    db = function() return E.data end,
    profiles = function() return (E.data:GetProfiles()) end,
    hasProfile = ElvProfile,
    has = function(res) return ns.InstallString("NHT_PROFILE", res) ~= nil end,
    installed = function()
        for _, key in ipairs({ "NHT", "FHT" }) do
            if ns.InstallString(key .. "_PROFILE", Res()) and not ElvProfile(key) then return false end
        end
        return true
    end,
    install = function(res, done)
        local existing = {}
        for _, key in ipairs({ "NHT", "FHT" }) do
            if ns.InstallString(key .. "_PROFILE", res) and ElvProfile(key) then existing[#existing + 1] = key end
        end
        local function Run(overwrite)
            -- the thingsUI layout applies on the next load
            if ns.InstallElvProfiles(res, overwrite) > 0 then needReload = true end
            done(true)
        end
        if #existing > 0 then
            Confirm("ElvUI", table.concat(existing, " and ") .. " already exist. Overwrite them (profile and thingsUI layout) with the pack's version?",
                function() Run(true) end, function() Run(false) end)
        else
            Run(false)
        end
    end,
})
PROVIDERS[#PROVIDERS + 1] = ELVUI

-- private profiles are per character; ElvUI reloads on its own switch, so the key is written for the next load
local PRIVATE_NAME = "Private things"
local function PrivSV() return _G.ElvPrivateDB end

PROVIDERS[#PROVIDERS + 1] = {
    key = "elvpriv", title = "ElvUI Private & Global", color = "CBA0FF", perChar = true,
    loaded = function() return PrivSV() ~= nil and E.charSettings ~= nil end,
    has = function() return ns.InstallString("ELV_PRIVATE") ~= nil end,
    installed = function() return (PrivSV().profiles or {})[PRIVATE_NAME] ~= nil end,
    install = function(_, done)
        local okP, okG = ns.ImportElvExtras()
        if okP or okG then needReload = true end
        done(okP and true or false)
    end,
    pack = function() return PRIVATE_NAME end,
    list = function()
        local out = {}
        for name in pairs(PrivSV().profiles or {}) do out[#out + 1] = name end
        return Sorted(out)
    end,
    exists = function(name) return (PrivSV().profiles or {})[name] ~= nil end,
    current = function()
        local keys = PrivSV().profileKeys
        return (keys and keys[CharKey()]) or E.charSettings:GetCurrentProfile()
    end,
    load = function(name)
        local sv = PrivSV()
        sv.profileKeys = sv.profileKeys or {}
        sv.profileKeys[CharKey()] = name
        needReload = true
    end,
}

-- ------------------------------------------------------------- BigWigs

local function BWDB() return _G.BigWigsLoader and _G.BigWigsLoader.db end
local function BWProfiles() return PACK.bigwigs or {} end

-- BigWigs' export leaves out Auras (Boss Debuffs); the pack carries them
local AURA_NS, AURA_PREFIX = "BigWigs_Plugins_Auras", "TUIBWA1:"

local function AuraProfiles()
    local sv = _G.BigWigs3DB
    sv.namespaces = sv.namespaces or {}
    sv.namespaces[AURA_NS] = sv.namespaces[AURA_NS] or {}
    local n = sv.namespaces[AURA_NS]
    n.profiles = n.profiles or {}
    return n.profiles
end

local function EncodeAuras(t)
    local packed = C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(t), Enum.CompressionMethod.Deflate)
    return AURA_PREFIX .. C_EncodingUtil.EncodeBase64(packed)
end

local function DecodeAuras(str)
    if str:sub(1, #AURA_PREFIX) ~= AURA_PREFIX then return end
    -- pasted data: the C decoders throw on anything malformed
    local ok, t = pcall(function()
        local raw = C_EncodingUtil.DecodeBase64(str:sub(#AURA_PREFIX + 1))
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(raw, Enum.CompressionMethod.Deflate))
    end)
    if ok and type(t) == "table" then return t end
end

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

local function WriteAuras(name, data)
    local db = BWDB()
    local live = db.GetNamespace and db:GetNamespace(AURA_NS, true)
    if live and db:GetCurrentProfile() == name then
        -- the loaded profile: reset to defaults, then layer ours on top
        live:ResetProfile()
        Merge(live.profile, data)
        _G.BigWigsLoader:SendMessage("BigWigs_ProfileUpdate")
    else
        -- AceDB fills in the defaults when this profile loads
        AuraProfiles()[name] = CopyTable(data)
    end
end

local function BWPrint(bp, res)
    local s = ResString(bp.strings, res)
    return s and Fingerprint(s .. "\n" .. (ResString(bp.auras, res) or ""))
end

local function BWChanged(res)
    local st, out = Stamps("bigwigs"), {}
    for _, bp in ipairs(BWProfiles()) do
        local now = BWPrint(bp, res)
        if now and st[bp.name] and st[bp.name] ~= now and _G.BigWigsAPI.IsValidProfile(bp.name) then
            out[#out + 1] = bp
        end
    end
    return out
end

local BIGWIGS

-- one at a time (each raises BigWigs' own popup and swaps to it); this spec's goes last
local function BWImport(todo, res, overwrite, done)
    local mine = M.SpecPackKey()
    for i, bp in ipairs(todo) do
        if bp.name == mine then table.insert(todo, table.remove(todo, i)); break end
    end
    if #todo > 1 then
        Say("BigWigs asks once per profile and says it will swap to it. Each spec gets the right one afterwards.")
    end
    local n, tried, accepted = 0, 0, 0
    local function Next()
        n = n + 1
        local bp = todo[n]
        if not bp then
            if accepted > 0 then
                local want = DB().pick.bigwigs or FOLLOW
                if BIGWIGS.exists(want) then BIGWIGS.load(want) end
            end
            done(tried == 0 or accepted > 0)
            return
        end
        if not overwrite and _G.BigWigsAPI.IsValidProfile(bp.name) then Next(); return end
        tried = tried + 1
        -- BigWigs rejects a bad string with error()
        local ok, err = pcall(_G.BigWigsAPI.RegisterProfile, "thingsUI", ResString(bp.strings, res), bp.name,
            function(yes)
                if yes then
                    accepted = accepted + 1
                    local auras = DecodeAuras(ResString(bp.auras, res) or "")
                    if auras then WriteAuras(bp.name, auras) end
                    Stamps("bigwigs")[bp.name] = BWPrint(bp, res)
                end
                C_Timer.After(0, Next)
            end)
        if not ok then Say("BigWigs: " .. tostring(err)); Next() end
    end
    Next()
end

BIGWIGS = SpecProvider({
    key = "bigwigs", title = "BigWigs", color = "FF7F3F",
    loaded = function()
        return _G.BigWigsAPI ~= nil and _G.BigWigsAPI.RegisterProfile ~= nil and BWDB() ~= nil
    end,
    db = BWDB,
    profiles = function() return _G.BigWigsAPI.GetProfileList() end,
    hasProfile = function(name) return _G.BigWigsAPI.IsValidProfile(name) end,
    has = function(res)
        for _, bp in ipairs(BWProfiles()) do
            if ResString(bp.strings, res) then return true end
        end
        return false
    end,
    installed = function()
        for _, bp in ipairs(BWProfiles()) do
            if ResString(bp.strings, Res()) and not _G.BigWigsAPI.IsValidProfile(bp.name) then return false end
        end
        return true
    end,
    adopt = function(res)
        local st = Stamps("bigwigs")
        for _, bp in ipairs(BWProfiles()) do
            if st[bp.name] == nil and _G.BigWigsAPI.IsValidProfile(bp.name) then st[bp.name] = BWPrint(bp, res) end
        end
    end,
    outdated = function() return #BWChanged(Res()) > 0 end,
    install = function(res, done, only)
        local todo, existing = {}, {}
        for _, bp in ipairs(BWProfiles()) do
            if (not only or bp.name == only) and ResString(bp.strings, res) then
                todo[#todo + 1] = bp
                if _G.BigWigsAPI.IsValidProfile(bp.name) then existing[#existing + 1] = bp.name end
            end
        end
        if #todo == 0 then done(false); return end
        if #existing > 0 then
            Confirm("BigWigs", table.concat(existing, " and ") .. " already exist. Overwrite with the pack's version?",
                function() BWImport(todo, res, true, done) end, function() BWImport(todo, res, false, done) end)
        else
            BWImport(todo, res, false, done)
        end
    end,
    update = function(res, done)
        local todo = BWChanged(res)
        if #todo == 0 then done(true); return end
        BWImport(todo, res, true, done)
    end,
})
PROVIDERS[#PROVIDERS + 1] = BIGWIGS

-- ------------------------------------------------------ cooldown manager

-- Blizzard's Cooldown Manager layouts live per character (max 5), one per
-- string in the pack.

local function LM()
    local s = _G.CooldownViewerSettings
    return s and s.GetLayoutManager and C_EncodingUtil and s:GetLayoutManager()
end

local function CurrentTag()
    return _G.CooldownViewerUtil and tonumber(_G.CooldownViewerUtil.GetCurrentClassAndSpecTag())
end

-- Blizzard's own reader: "1|" .. Base64(Deflate(CBOR))
local function DecodeLayouts(str)
    local sep = str:find("|", 1, true)
    if not sep then return end
    -- pasted data: the C decoders throw on anything malformed
    local ok, t = pcall(function()
        local raw = C_EncodingUtil.DecodeBase64(str:sub(sep + 1))
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(raw, Enum.CompressionMethod.Deflate))
    end)
    if not (ok and type(t) == "table" and type(t[3]) == "table") then return end
    local out = {}
    for tag, byID in pairs(t[3]) do
        for id in pairs(byID) do
            out[#out + 1] = { tag = tonumber(tag), name = type(t[4]) == "table" and t[4][id] or nil }
        end
    end
    return out
end

local cdmEntries
local function CDMEntries()
    if cdmEntries then return cdmEntries end
    if not LM() then return {} end
    cdmEntries = {}
    for _, s in ipairs(PACK.cdm and PACK.cdm.layouts or {}) do
        s = strtrim(s)
        if s ~= "" then
            local list = DecodeLayouts(s)
            local l = list and list[1]
            if l and l.tag and l.name then
                cdmEntries[#cdmEntries + 1] = { str = s, fp = Fingerprint(s), tag = l.tag, name = l.name }
            else
                Say("a Cooldown Manager string in the pack could not be read.")
            end
        end
    end
    return cdmEntries
end

local function ClassEntries()
    local out = {}
    local classID = select(3, UnitClass("player"))
    for _, e in ipairs(CDMEntries()) do
        if math.floor(e.tag / 10) == classID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.tag < b.tag end)
    return out
end

local function CDMStore()
    local i = DB()
    local k = CharKey()
    i.cdm[k] = i.cdm[k] or {}
    return i.cdm[k]
end

-- "ok" | "outdated" | "missing"; a kept same-name layout counts as handled
local function EntryState(e)
    local held = CDMStore()[e.tag]
    local lm = LM()
    if not (held and lm and lm:GetLayoutByName(e.name, e.tag)) then return "missing" end
    if held == e.fp or held == "kept:" .. e.fp then return "ok" end
    return "outdated"
end

local function SpecName(tag)
    local _, name = GetSpecializationInfoForClassID(math.floor(tag / 10), tag % 10)
    return name or tostring(tag)
end

local function ImportLayout(lm, e, cur)
    local old = lm:GetLayoutByName(e.name, e.tag)
    if old then
        lm:RemoveLayout(CooldownManagerLayout_GetID(old))
    elseif lm:AreLayoutsFullyMaxed() then
        return false, "maxed"
    end
    local ids = lm:CreateLayoutsFromSerializedData(e.str)
    local layout = ids and ids[1] and lm:GetLayout(ids[1])
    if not layout then return false end
    -- saved before the one call that can be refused
    lm:SaveLayouts()
    if e.tag == cur then
        lm:SetActiveLayoutByID(ids[1])
        HideForbiddenPopup()
        C_Timer.After(0, HideForbiddenPopup)
    else
        lm:SetPreviouslyActiveLayout(layout)
    end
    lm:SaveLayouts()
    return true
end

local CDM = {
    key = "cdm", title = "Cooldown Manager (Blizzard)", color = "FFFFFF", charInstall = true,
    none = "No layouts for your class in the pack.",
    loaded = function() return LM() ~= nil end,
    has = function() return #ClassEntries() > 0 end,
    installed = function()
        for _, e in ipairs(ClassEntries()) do
            if EntryState(e) ~= "ok" then return false end
        end
        return true
    end,
    outdated = function()
        for _, e in ipairs(ClassEntries()) do
            if EntryState(e) == "outdated" then return true end
        end
        return false
    end,
    -- one button per spec of this character's class
    parts = function()
        local out = {}
        for _, e in ipairs(ClassEntries()) do
            out[#out + 1] = { label = SpecName(e.tag), state = EntryState(e), arg = e }
        end
        return out
    end,
    -- only: one entry (a spec button) or a list of them
    install = function(_, done, only)
        local lm, store, cur = LM(), CDMStore(), CurrentTag()
        local all, todo = ClassEntries(), {}
        for _, e in ipairs(only and (only.tag and { only } or only) or all) do
            if only or EntryState(e) ~= "ok" then todo[#todo + 1] = e end
        end
        if #todo == 0 then todo = all end
        -- the active spec first, so a full character never leaves it out
        table.sort(todo, function(a, b) return a.tag == cur and b.tag ~= cur end)
        local foreign, names = {}, {}
        for _, e in ipairs(todo) do
            local held = store[e.tag]
            if lm:GetLayoutByName(e.name, e.tag) and not (held and not held:find("^kept:")) then
                foreign[e] = true
                names[#names + 1] = e.name .. " (" .. SpecName(e.tag) .. ")"
            end
        end
        local function Run(overwrite)
            local maxed, failed, imported = {}, {}, 0
            local function Batch()
                for _, e in ipairs(todo) do
                    if foreign[e] and not overwrite then
                        store[e.tag] = "kept:" .. e.fp
                    else
                        local ok, why = ImportLayout(lm, e, cur)
                        if ok then
                            store[e.tag] = e.fp
                            imported = imported + 1
                        else
                            local list = (why == "maxed") and maxed or failed
                            list[#list + 1] = SpecName(e.tag)
                        end
                    end
                end
            end
            lm:LockNotifications()
            -- the lock must be released even if Blizzard's reader throws
            local ok, err = pcall(Batch)
            -- no listener may run inside our execution
            lm.needsNotificationAfterUnlock = false
            lm:UnlockNotifications()
            if not ok then geterrorhandler()(err) end
            if #maxed > 0 then
                Say("no room for " .. table.concat(maxed, ", ") .. " (5 Cooldown Manager layouts per character). "
                    .. "Delete one in the Cooldown Manager settings and install again.")
            end
            if #failed > 0 then Say("Cooldown Manager could not import " .. table.concat(failed, ", ") .. ".") end
            -- imported layouts stay tainted until a reload
            if imported > 0 then needReload = true end
            done(ok and (imported > 0 or (#maxed == 0 and #failed == 0)))
        end
        if #names > 0 then
            Confirm("Cooldown Manager", "This character already has " .. table.concat(names, ", ")
                .. ". Overwrite with the pack's version?", function() Run(true) end, function() Run(false) end)
        else
            Run(false)
        end
    end,
}
CDM.update = function(res, done)
    local list = {}
    for _, e in ipairs(ClassEntries()) do
        if EntryState(e) == "outdated" then list[#list + 1] = e end
    end
    if #list == 0 then done(true); return end
    CDM.install(res, done, list)
end
PROVIDERS[#PROVIDERS + 1] = CDM

-- ------------------------------------------------------------ Edit Mode

-- the list the game indexes: Blizzard's presets first, then saved layouts
local function EMLayouts()
    local info = C_EditMode.GetLayouts()
    local out = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    for _, l in ipairs(info and info.layouts or {}) do out[#out + 1] = l end
    return out, info and info.activeLayout
end

local function EMIndex(name)
    for n, l in ipairs((EMLayouts())) do
        if l.layoutName == name then return n end
    end
end

PROVIDERS[#PROVIDERS + 1] = {
    key = "editmode", title = "Edit Mode (Blizzard)", color = "AAAAAA", perChar = true,
    loaded = function()
        local mgr = _G.EditModeManagerFrame
        return mgr ~= nil and mgr.accountSettings ~= nil and _G.EditModePresetLayoutManager ~= nil
    end,
    pack = function() return "thingsEUI" end,
    list = function()
        local out = {}
        for _, l in ipairs((EMLayouts())) do out[#out + 1] = l.layoutName end
        return out
    end,
    exists = function(name) return EMIndex(name) ~= nil end,
    current = function()
        local list, active = EMLayouts()
        local l = active and list[active]
        return l and l.layoutName
    end,
    load = function(name)
        local idx = EMIndex(name)
        if not idx then return end
        C_EditMode.SetActiveLayout(idx)
        HideForbiddenPopup()
        -- Edit Mode stays tainted until a reload
        needReload = true
    end,
}

-- --------------------------------------------------------------- Details

local DETAILS_NAME = "things"

PROVIDERS[#PROVIDERS + 1] = {
    key = "details", title = "Details!", color = "FFB060",
    loaded = function() return _G.Details ~= nil and _G.Details.GetProfile ~= nil end,
    has = function() return ns.InstallString("DETAILS_PROFILE") ~= nil end,
    installed = function()
        local d = _G.Details
        return d:GetProfile(DETAILS_NAME, false) ~= nil and d.always_use_profile and d.always_use_profile_name == DETAILS_NAME
    end,
    detail = function() return "One profile for all characters: " .. DETAILS_NAME end,
    install = function(_, done) done(ns.EnsureDetailsProfile() and true or false) end,
}

-- ------------------------------------------------- per character, no pack

local function AceDBForSV(sv)
    local lib = LibStub and LibStub("AceDB-3.0", true)
    if not (lib and sv) then return nil end
    for db in pairs(lib.db_registry) do
        if rawget(db, "sv") == sv then return db end
    end
end

PROVIDERS[#PROVIDERS + 1] = {
    key = "grid2", title = "Grid2", color = "7FFF7F", perChar = true,
    none = "Its profiles are in thingsUI -> Grid2.",
    loaded = function() return _G.Grid2 and _G.Grid2.db and true or false end,
    pack = function() end,
    list = function() return Sorted(_G.Grid2.db:GetProfiles()) end,
    exists = function(name) return (_G.Grid2.db.profiles or {})[name] ~= nil end,
    current = function() return _G.Grid2.db:GetCurrentProfile() end,
    load = function(name) _G.Grid2.db:SetProfile(name) end,
}

local function BRDB() return AceDBForSV(_G.BuffRemindersDB) end

PROVIDERS[#PROVIDERS + 1] = SpecProvider({
    key = "buffreminders", title = "BuffReminders", color = "FFD700",
    loaded = function()
        local db = _G.BuffReminders and BRDB()
        return db ~= nil and db.SetDualSpecEnabled ~= nil
    end,
    db = BRDB,
    profiles = function() return (BRDB():GetProfiles()) end,
    hasProfile = function(name) return (BRDB().profiles or {})[name] ~= nil end,
})

PROVIDERS[#PROVIDERS + 1] = {
    key = "platynator", title = "Platynator", color = "FF6EB4", perChar = true,
    loaded = function() return _G.PLATYNATOR_CONFIG and _G.PLATYNATOR_CONFIG.Profiles and true or false end,
    pack = function() return "things" end,
    list = function()
        local out = {}
        for name in pairs(_G.PLATYNATOR_CONFIG.Profiles) do out[#out + 1] = name end
        return Sorted(out)
    end,
    exists = function(name) return _G.PLATYNATOR_CONFIG.Profiles[name] ~= nil end,
    current = function() return _G.PLATYNATOR_CURRENT_PROFILE end,
    -- no public switch: the per-character key is read at load
    load = function(name)
        _G.PLATYNATOR_CURRENT_PROFILE = name
        needReload = true
    end,
}

-- ----------------------------------------------------------------- state

local function Want(p)
    local pick = DB().pick[p.key]
    if pick and p.exists(pick) then return pick end
    local pk = p.pack and p.pack()
    if pk and p.exists(pk) then return pk end
end

local function Label(p, name) return p.label and p.label(name) or name end
local function UseText(p, name) return p.useText and p.useText(name) or Label(p, name) end

local function Usable(p, res) return p.install ~= nil and p.loaded() and p.has(res) end

local function UpdateFor(p) return p.outdated ~= nil and p.loaded() and p.outdated() end

local function Mismatched(p)
    -- per-character installs: offered to alts once the account has used them
    if p.charInstall then
        return DB().done[p.key] ~= nil and Usable(p, Res()) and not p.installed()
    end
    if not (p.perChar and p.loaded()) then return false end
    local want = Want(p)
    if want == nil then return false end
    if p.matches then return not p.matches(want) end
    return p.current() ~= want
end

local function AnyMismatch(skipCDM)
    for _, p in ipairs(PROVIDERS) do
        if not (skipCDM and p.charInstall) and Mismatched(p) then return true end
    end
    return false
end

local function RunInstall(p, res, after, only)
    if InCombatLockdown() then Say("not in combat."); return end
    p.install(res, function(ok)
        if ok and (not only or p.installed()) then
            local i = DB()
            i.done[p.key] = true
            i.res = res
        end
        if after then after(ok) end
    end, only)
end

local function RunUpdate(p, res, after)
    if InCombatLockdown() then Say("not in combat."); return end
    p.update(res, after or function() end)
end

-- installed by hand or before this tracked it
local function Adopt(res)
    local i = DB()
    for _, p in ipairs(PROVIDERS) do
        if Usable(p, res) then
            if i.done[p.key] == nil and p.installed() then i.done[p.key] = true end
            if p.adopt then p.adopt(res) end
        end
    end
end

local Refresh, win

-- every mismatched profile, then the missing Cooldown Manager layouts
function M.LoadForCharacter(skipCDM, after)
    if InCombatLockdown() then Say("not in combat."); return end
    for _, p in ipairs(PROVIDERS) do
        if p.perChar and Mismatched(p) then p.load(Want(p)) end
    end
    local function Finish()
        Refresh()
        -- the window asks when it closes
        if not (win and win:IsShown()) then AskReload() end
        if after then after() end
    end
    if not skipCDM and Mismatched(CDM) then RunInstall(CDM, Res(), Finish) else Finish() end
end

-- ElvUI and BigWigs on the spec rule (or the account's pick)
function M.ApplySpecProfiles()
    local any = false
    for _, p in ipairs({ ELVUI, BIGWIGS }) do
        if p.loaded() then
            local want = Want(p)
            if want then
                any = true
                if not p.matches(want) then p.load(want) end
            end
        end
    end
    return any
end

-- only: one pack profile ("NHT" / "FHT"), else all of them
function M.InstallBigWigs(after, only)
    if not Usable(BIGWIGS, Res()) then if after then after(false) end return false end
    RunInstall(BIGWIGS, Res(), after, only)
    return true
end

function M.InstallCDM(after)
    if not Usable(CDM, Res()) then if after then after(false) end return false end
    RunInstall(CDM, Res(), after)
    return true
end

-- ---------------------------------------------------------------- window

local ROW_H, WIDTH, PAD = 66, 640, 16
local PART_COLOR = { ok = "|cff0dd29f", outdated = "|cffffd100", missing = "|cffff5555" }

local function Skins() return E:GetModule("Skins", true) end

local function MakeButton(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    local S = Skins()
    if S and S.HandleButton then S:HandleButton(b) end
    return b
end

local function MakeText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:FontTemplate(nil, size)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH("LEFT")
    return fs
end

local function StatusOf(p, res)
    if not p.install then
        if not p.loaded() then return "" end
        local want = Want(p)
        if not want then return "|cff888888" .. (p.none or "Pick a profile for your characters.") .. "|r" end
        return Mismatched(p) and "|cffffd100This character uses another profile.|r" or "|cff0dd29fThis character is set.|r"
    end
    if not p.has(res) then return "|cff888888" .. (p.none or ("Not part of the pack for " .. res .. ".")) .. "|r" end
    if UpdateFor(p) then return "|cffffd100Update available.|r" end
    if p.installed() then return "|cff0dd29fInstalled.|r" end
    return "|cffff5555Not installed.|r"
end

local function PickMenu(owner, p)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(p.title .. " for your characters")
        local want = Want(p)
        for i, n in ipairs(p.list()) do
            root:CreateRadio(Label(p, n), function() return n == want end, function()
                DB().pick[p.key] = n
                Refresh()
            end)
            -- which profiles Per spec uses
            if i == 1 and p.roles then
                for _, role in ipairs({ { key = "NHT", label = "Tank & DPS" }, { key = "FHT", label = "Healer + Aug" } }) do
                    local cur = RoleProfile(p, role.key)
                    local sub = root:CreateButton("   " .. role.label .. ": " .. cur)
                    for _, name in ipairs(Sorted(p.profiles())) do
                        sub:CreateRadio(name, function() return name == cur end, function()
                            local roles = DB().roles
                            roles[p.key] = roles[p.key] or {}
                            roles[p.key][role.key] = name
                            DB().pick[p.key] = FOLLOW
                            Refresh()
                        end)
                    end
                end
                root:CreateDivider()
            end
        end
    end)
end

local function BuildRow(parent, p)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r.name = MakeText(r, 14)
    r.name:SetPoint("TOPLEFT", 0, 0)
    r.name:SetText(("|cFF%s%s|r"):format(p.color or "FFFFFF", p.title))
    r.status = MakeText(r, 11)
    r.status:SetPoint("TOPLEFT", 0, -19)
    r.detail = MakeText(r, 11, 0.6, 0.6, 0.6)
    r.detail:SetPoint("TOPLEFT", 0, -36)
    r.detail:SetWidth(WIDTH - 2 * PAD - 250)
    r.detail:SetWordWrap(false)
    local line = r:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.08)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 4)
    line:SetPoint("BOTTOMRIGHT", 0, 4)

    if p.install then
        r.main = MakeButton(r, "Install", 110, function()
            local res = Res()
            if UpdateFor(p) and p.update then RunUpdate(p, res, Refresh) else RunInstall(p, res, Refresh) end
        end)
        r.main:SetPoint("TOPRIGHT", 0, 0)
    end
    if p.perChar then
        r.load = MakeButton(r, "Load", 110, function()
            local want = Want(p)
            if want then p.load(want) end
            Refresh()
        end)
        r.load:SetPoint("TOPRIGHT", 0, -28)
        r.pick = MakeButton(r, "Profile...", 110, function(self) PickMenu(self, p) end)
        r.pick:SetPoint("RIGHT", r.load, "LEFT", -6, 0)
    end
    if p.parts then
        r.parts = {}
        for n = 1, 4 do
            local b = MakeButton(r, "", 80, nil)
            b:SetPoint("TOPLEFT", (n - 1) * 86, -36)
            b:Hide()
            r.parts[n] = b
        end
    end
    return r
end

local function UpdateRow(r, p, res)
    r.status:SetText(StatusOf(p, res))
    local usable = Usable(p, res)
    if r.main then
        local label = (UpdateFor(p) and "Update") or ((p.loaded() and p.installed()) and "Reinstall") or "Install"
        r.main:SetText(label)
        r.main:SetEnabled(usable)
    end
    r.detail:SetText("")
    if p.perChar and p.loaded() then
        local want = Want(p)
        local cur = p.current()
        local curText = cur and UseText(p, cur) or "?"
        if want and Mismatched(p) then curText = "|cffffd100" .. curText .. "|r" end
        r.detail:SetText("This character: " .. curText .. "   Use: " .. (want and UseText(p, want) or "-"))
        r.load:SetEnabled(Mismatched(p))
    elseif p.detail and p.loaded() then
        r.detail:SetText(p.detail())
    end
    if r.parts then
        local parts = usable and p.parts() or {}
        local w = #parts > 0 and math.min(110, math.floor((WIDTH - 2 * PAD - 130 - 6 * (#parts - 1)) / #parts)) or 80
        for n, b in ipairs(r.parts) do
            local part = parts[n]
            if part then
                b:SetText(PART_COLOR[part.state] .. part.label .. "|r")
                b:SetWidth(w)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", (n - 1) * (w + 6), -36)
                b:SetScript("OnClick", function() RunInstall(p, res, Refresh, part.arg) end)
                b:Show()
            else
                b:Hide()
            end
        end
        if #parts > 0 then r.detail:SetText("") end
    end
end

local function CloseWindow()
    if win then win:Hide() end
end

local function BuildWindow()
    local f = CreateFrame("Frame", "TUI_SetupFrame", UIParent)
    f:SetTemplate("Transparent")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetWidth(WIDTH)
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function() AskReload() end)
    tinsert(UISpecialFrames, "TUI_SetupFrame")

    f.title = MakeText(f, 18)
    f.title:SetPoint("TOPLEFT", PAD, -14)
    f.title:SetText("|cFF8080FFthingsUI|r  Character Setup")
    f.sub = MakeText(f, 11, 0.6, 0.6, 0.6)
    f.sub:SetPoint("TOPLEFT", PAD, -38)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    local S = Skins()
    if S and S.HandleCloseButton then S:HandleCloseButton(close) end

    f.res = {}
    for idx, r in ipairs(RES) do
        local b = MakeButton(f, r, 70, function()
            DB().res = r
            Refresh()
        end)
        b.res = r
        f.res[idx] = b
    end

    f.rows = {}
    for _, p in ipairs(PROVIDERS) do f.rows[p.key] = BuildRow(f, p) end

    f.missing = MakeText(f, 11, 0.6, 0.6, 0.6)
    f.missing:SetPoint("BOTTOMLEFT", PAD, 74)
    f.missing:SetWidth(WIDTH - 2 * PAD)

    f.installAll = MakeButton(f, "Install All", 130, function()
        local res = Res()
        local queue = {}
        for _, p in ipairs(PROVIDERS) do
            if Usable(p, res) and (UpdateFor(p) or not p.installed()) then queue[#queue + 1] = p end
        end
        if #queue == 0 then Say("everything in the pack is already installed."); return end
        local n = 0
        local function Next()
            n = n + 1
            local p = queue[n]
            if not p then Refresh(); return end
            if UpdateFor(p) and p.update then RunUpdate(p, res, Next) else RunInstall(p, res, Next) end
        end
        Next()
    end)
    f.installAll:SetPoint("BOTTOMLEFT", PAD, 42)
    f.loadAll = MakeButton(f, "Load for This Character", 180, function() M.LoadForCharacter(false) end)
    f.loadAll:SetPoint("LEFT", f.installAll, "RIGHT", 6, 0)
    f.loadNoCDM = MakeButton(f, "Load Without CDM", 150, function() M.LoadForCharacter(true) end)
    f.loadNoCDM:SetPoint("LEFT", f.loadAll, "RIGHT", 6, 0)
    f.reload = MakeButton(f, "Reload UI", 110, ReloadUI)
    f.reload:SetPoint("BOTTOMRIGHT", -PAD, 42)

    local never = MakeButton(f, "Don't Show Again", 130, function()
        DB().declined = true
        Say("won't ask by itself anymore. /tui alt opens this.")
        CloseWindow()
    end)
    never:SetPoint("BOTTOMLEFT", PAD, 14)
    local skip = MakeButton(f, "Skip This Character", 180, function()
        DB().skip[CharKey()] = true
        Say("won't ask by itself on this character. /tui alt opens this.")
        CloseWindow()
    end)
    skip:SetPoint("LEFT", never, "RIGHT", 6, 0)
    local done = MakeButton(f, "Close", 110, CloseWindow)
    done:SetPoint("BOTTOMRIGHT", -PAD, 14)
    return f
end

Refresh = function()
    if not (win and win:IsShown()) then return end
    local res = Res()
    Adopt(res)
    local screen = DetectRes()
    win.sub:SetText(res .. "   " .. CharKey()
        .. ((screen ~= res) and ("   |cffffd100(your screen: " .. screen .. ")|r") or ""))
    local x = -36
    for idx = #RES, 1, -1 do
        local b = win.res[idx]
        local have = HasRes(b.res)
        b:SetText((b.res == res and "|cff0dd29f" .. b.res .. "|r")
            or (have and b.res) or (b.res .. " |cff888888Soon|r"))
        b:SetWidth(have and 70 or 110)
        b:SetEnabled(have)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", x, -14)
        x = x - b:GetWidth() - 6
    end
    local y, offline = -64, {}
    for _, p in ipairs(PROVIDERS) do
        local row = win.rows[p.key]
        if p.loaded() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, y)
            row:SetPoint("TOPRIGHT", -PAD, y)
            UpdateRow(row, p, res)
            row:Show()
            y = y - ROW_H
        else
            row:Hide()
            offline[#offline + 1] = p.title
        end
    end
    win.missing:SetText(#offline > 0 and ("Not installed or enabled: " .. table.concat(offline, ", ")) or "")
    win:SetHeight(-y + (#offline > 0 and 96 or 80))
    local loadTxt = AnyMismatch(false) and "|cffffd100Load for This Character|r" or "Load for This Character"
    win.loadAll:SetText(loadTxt)
    win.loadNoCDM:SetEnabled(AnyMismatch(true))
    win.reload:SetText(needReload and "|cff0dd29fReload UI|r" or "Reload UI")
end

function M.Open()
    if InCombatLockdown() then Say("not in combat."); return end
    if not win then win = BuildWindow() end
    win:Show()
    Refresh()
end

-- ------------------------------------------------------------ login check

local function CheckLines()
    local lines, sig, hasCDM = {}, {}, false
    for _, p in ipairs(PROVIDERS) do
        if Mismatched(p) then
            if p.charInstall then
                hasCDM = true
                local specs, prints = {}, {}
                for _, part in ipairs(p.parts()) do
                    if part.state ~= "ok" then
                        specs[#specs + 1] = part.label
                        prints[#prints + 1] = part.arg.fp
                    end
                end
                lines[#lines + 1] = ("|cFF%s%s:|r %s"):format(p.color, "Cooldown Manager", table.concat(specs, ", "))
                sig[#sig + 1] = "cdm=" .. table.concat(prints, ",")
            else
                local want = Want(p)
                lines[#lines + 1] = ("|cFF%s%s:|r %s"):format(p.color, p.title, UseText(p, want))
                sig[#sig + 1] = p.key .. "=" .. want
            end
        end
    end
    return lines, table.concat(sig, ";"), hasCDM
end

local POPUP_BASE = {
    text = "%s",
    selectCallbackByIndex = true,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

E.PopupDialogs.TUI_SETUP_CHECK = CreateFromMixins(POPUP_BASE, {
    button1 = "Everything", button2 = "Everything but CDM", button3 = "Skip",
    OnButton1 = function() M.LoadForCharacter(false) end,
    OnButton2 = function() M.LoadForCharacter(true) end,
    OnButton3 = function(_, d) DB().skip[CharKey()] = d.sig end,
})

E.PopupDialogs.TUI_SETUP_CHECK_ONE = CreateFromMixins(POPUP_BASE, {
    button1 = "Load", button2 = "Skip",
    OnButton1 = function() M.LoadForCharacter(false) end,
    OnButton2 = function(_, d) DB().skip[CharKey()] = d.sig end,
})

local checkAtRegen = false

-- nil when it may ask, else why not
local function CheckGate()
    local g = _G.thingsUIGlobalDB
    if not (g and g.installComplete) then return "the installer has not been finished on this account" end
    local i = DB()
    if i.declined then return "Don't Show Again was clicked" end
    if i.skip[CharKey()] == true then return "Skip This Character was clicked" end
    if win and win:IsShown() then return "the window is open" end
    if InCombatLockdown() then return "in combat" end
end

function M.CheckCharacter()
    local why = CheckGate()
    if why then
        if why == "in combat" then checkAtRegen = true end
        return
    end
    Adopt(Res())
    local lines, sig, hasCDM = CheckLines()
    if #lines == 0 or DB().skip[CharKey()] == sig then return end
    local which = (hasCDM and #lines > 1) and "TUI_SETUP_CHECK" or "TUI_SETUP_CHECK_ONE"
    E:StaticPopup_Show(which, "|cFF8080FFthingsUI|r: set up this character?\n\n" .. table.concat(lines, "\n"),
        nil, { sig = sig })
end

-- --------------------------------------------------- new ElvUI profiles

E.PopupDialogs.TUI_NEWPROFILE_COPY = {
    text = "|cFF8080FFthingsUI|r: New ElvUI profile |cFFFFFFFF'%s'|r.\nCopy settings from |cFFFFFFFF'%s'|r?",
    button1 = YES, button2 = NO, button3 = "Never for this profile",
    OnAccept = function(_, data)
        if E.data:GetCurrentProfile() == data.new then E.data:CopyProfile(data.src) end
    end,
    OnAlt = function(_, data)
        local g = _G.thingsUIGlobalDB
        g.newProfileNoAsk = g.newProfileNoAsk or {}
        g.newProfileNoAsk[data.new] = true
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

local pendingNewProfile
local function OnNewProfile(_, _, profileKey) pendingNewProfile = profileKey end
local function OnProfileChanged(_, _, profileKey)
    if not pendingNewProfile or profileKey ~= pendingNewProfile then pendingNewProfile = nil return end
    pendingNewProfile = nil
    if ns.SuppressNewProfileAsk and (GetTime() - ns.SuppressNewProfileAsk) < 5 then return end
    local g = _G.thingsUIGlobalDB
    if g and g.newProfileNoAsk and g.newProfileNoAsk[profileKey] then return end
    local src = M.SpecPackKey()
    if not ElvProfile(src) or src == profileKey then return end
    C_Timer.After(0.2, function()
        if E.data:GetCurrentProfile() ~= profileKey then return end
        E:StaticPopup_Show("TUI_NEWPROFILE_COPY", profileKey, src, { new = profileKey, src = src })
    end)
end

-- ----------------------------------------------------------- author tool

local function ShowCopy(title, text)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    local f = AceGUI:Create("Frame")
    ns.SolidDialog(f)
    f:SetTitle(title)
    f:SetWidth(480)
    f:SetHeight(300)
    f:SetLayout("Fill")
    f:SetCallback("OnClose", function(w) AceGUI:Release(w) end)
    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("Copy the string (Ctrl+C)")
    eb:SetText(text)
    eb:DisableButton(true)
    f:AddChild(eb)
    if eb.editBox then eb.editBox:HighlightText(); eb.editBox:SetFocus() end
end

local function CaptureBigWigsAuras()
    if not (_G.BigWigsAPI and _G.BigWigs3DB) then Say("BigWigs is not loaded."); return end
    local name = _G.BigWigsAPI.GetProfileName()
    ShowCopy("BigWigs Auras: " .. name, EncodeAuras(CopyTable(AuraProfiles()[name] or {})))
end

-- ---------------------------------------------------------------- wiring

local function AltCommand(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "why" then
        local why = CheckGate()
        Say(why and ("won't ask: " .. why .. ".") or "may ask; it does when a profile or layout is off.")
    elseif cmd == "bwauras" then
        CaptureBigWigsAuras()
    else
        M.Open()
    end
end
ns.SlashCommand("alt", AltCommand)
ns.SlashCommand("bwauras", CaptureBigWigsAuras)
-- old name, kept for muscle memory
SLASH_TUIALTSETUP1 = "/tuialt"
SlashCmdList.TUIALTSETUP = AltCommand

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if checkAtRegen then
            checkAtRegen = false
            M.CheckCharacter()
        end
        return
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- E.data exists from here on
    if E.data and E.data.RegisterCallback then
        E.data.RegisterCallback("thingsUISetup", "OnNewProfile", OnNewProfile)
        E.data.RegisterCallback("thingsUISetup", "OnProfileChanged", OnProfileChanged)
    end
    C_Timer.After(6, M.CheckCharacter)
end)
