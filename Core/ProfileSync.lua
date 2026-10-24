local _, ns = ...
local E = ns.E
local TUI = ns.TUI
local DeepCopy = ns.DeepCopy
local P = _G.ElvUI and _G.ElvUI[4]

-- Profile Sync: one set of profiles that keep the picked modules the same. The profile in
-- use hands its copy to the rest of the set when it is switched away from, at logout and
-- on Sync Now; a profile outside the set never writes into it.
ns.ProfileSync = ns.ProfileSync or {}
local M = ns.ProfileSync

-- frame positions and sizes stay with each profile unless the module syncs them
local POS = {
    anchor = true, anchorFrame = true, anchorFrameCustom = true, anchorMode = true,
    anchorPoint = true, anchorRelativePoint = true, anchorXOffset = true, anchorYOffset = true,
    anchorTo = true, xOffset = true, yOffset = true,
}
-- frame spots only in a module's own table (Minimap, Essential mover); deeper they place text
local TOP_POS = { point = true, x = true, y = true }
local SIZE = {
    width = true, height = true, iconSize = true, iconWidth = true, iconHeight = true,
    barHeight = true, barWidth = true, windowWidth = true, windowHeight = true, headerHeight = true,
    fhtWidth = true, scale = true, overrideSize = true, matchWidth = true,
    inheritWidth = true, inheritHeight = true, inheritWidthOffset = true, inheritHeightOffset = true,
}

-- { profiles = { [name] = true }, modules = { [id] = { mode = "all"|"some", parts = {}, pos, size } } }
local function Store()
    local g = _G.thingsUIGlobalDB
    if type(g) ~= "table" then g = {}; _G.thingsUIGlobalDB = g end
    local s = g.profileSync
    if type(s) ~= "table" then s = {}; g.profileSync = s end
    -- the first build kept a member list per module: one set now
    if type(s.profiles) ~= "table" then
        local set, mods = {}, {}
        for id, grp in pairs(s) do
            if type(grp) == "table" and type(grp.members) == "table" then
                for name in pairs(grp.members) do set[name] = true end
                mods[id] = { mode = "all", pos = (grp.keepPos == false) or nil }
                s[id] = nil
            end
        end
        s.profiles, s.modules = set, mods
    end
    if type(s.modules) ~= "table" then s.modules = {} end
    return s
end

local function Profiles() return (E.data and E.data.profiles) or {} end
local function Current() return E.data and E.data:GetCurrentProfile() end
M.Current = Current

function M.SectionID(sec) return sec.id or sec.keys[1] end

function M.SectionByID(id)
    for _, sec in ipairs(ns.Share.SECTIONS) do
        if (sec.id or sec.keys[1]) == id then return sec end
    end
end

-- a section's group kind filter (Groups - Bars / Groups - Text share one list)
local function Fits(sec, g)
    local S = ns.Share
    return not (sec and sec.only) or (S.GroupKind(g) == sec.only)
end

-- ------------------------------------------------------------ the set

-- set profiles that still exist, sorted
function M.SetProfiles()
    local s, out = Store(), {}
    local profiles = Profiles()
    for name in pairs(s.profiles) do
        if profiles[name] then out[#out + 1] = name else s.profiles[name] = nil end
    end
    table.sort(out)
    return out
end

function M.InSet(name) return (name and Store().profiles[name]) and true or false end

function M.SetInSet(name, on)
    if not name then return end
    Store().profiles[name] = on and true or nil
end

-- syncing at all: a module picked, this profile in the set with someone else
function M.Active()
    return M.InSet(Current()) and #M.SetProfiles() > 1
end

-- ------------------------------------------------------------ modules

function M.Module(id, create)
    local mods = Store().modules
    local c = mods[id]
    if type(c) ~= "table" then
        if not create then return nil end
        c = {}
        mods[id] = c
    end
    return c
end

function M.Mode(id)
    local c = M.Module(id)
    return c and c.mode or nil
end

function M.SetMode(id, mode)
    local c = M.Module(id, true)
    c.mode = mode
    if not mode then Store().modules[id] = nil end
end

function M.SetFlag(id, flag, on)
    local c = M.Module(id, true)
    if on then c[flag] = true else c[flag] = nil end
end

function M.SetPart(id, part, on)
    local c = M.Module(id, true)
    c.parts = c.parts or {}
    if on then c.parts[part] = true else c.parts[part] = nil end
end

-- name syncs the module with at least one other profile
function M.Syncs(id, name)
    return M.Mode(id) ~= nil and M.InSet(name) and #M.SetProfiles() > 1
end

-- ------------------------------------------------------------ parts

local LIST_KEY = { customGroups = "groups", customBars = "groups", barSetup = "setups" }
local LABELS = {
    essential = "Essential", utility = "Utility", buffIcon = "Buff Icons",
    perSpell = "Spell Editor: Cooldowns", perBuff = "Spell Editor: Buff Icons",
    trinketBlacklist = "Trinket Blacklist", tui = "Mini Meter", mbb = "MinimapButtonButton",
    instanceDifficulty = "Difficulty Text", essentialMover = "Essential Mover",
    groupAnchor = "Group Frame Anchor", raidOrder = "Raid Frame Builder: Enable",
    actionBarCopy = "Action Bar Copy: Keys Follow & Auto Fill",
    autoSetAudioChannels = "Audio Channels", rightChatAsBackground = "Right Chat as Meter Backdrop",
    rightChatWidthOffset = "Right Chat Width", rightChatHeightOffset = "Right Chat Height",
    _general = "General",
}

local function Pretty(k)
    if LABELS[k] then return LABELS[k] end
    local s = tostring(k):gsub("(%l)(%u)", "%1 %2")
    return (s:gsub("^%l", string.upper))
end

local function PartKind(id, sec)
    local dk = sec.keys[1]
    if #sec.keys > 1 then return "keys" end
    if LIST_KEY[dk] then return "list" end
    if dk == "specialBars" then return "specs" end
    if dk == "specialStyles" then return "styles" end
    return "blob"
end

local function SpecName(key)
    local m = ns.SpecMeta and ns.SpecMeta(tonumber(key))
    return (m and m.name and m.className) and (m.name .. " " .. m.className) or (m and m.name) or ("Spec " .. tostring(key))
end

-- what Some can pick in a module, from this profile's data: { { key, label } }
function M.Parts(id)
    local sec = M.SectionByID(id)
    local out = {}
    if not sec then return out end
    local db = E.db.thingsUI or {}
    local kind = PartKind(id, sec)
    if kind == "keys" then
        for _, k in ipairs(sec.keys) do out[#out + 1] = { key = k, label = Pretty(k) } end
    elseif kind == "list" then
        local dk = sec.keys[1]
        for _, it in ipairs(((db[dk] or {})[LIST_KEY[dk]]) or {}) do
            if type(it) == "table" and it.name and Fits(sec, it) then out[#out + 1] = { key = "n:" .. it.name, label = it.name } end
        end
    elseif kind == "specs" then
        for specKey in pairs(((db.specialBars or {}).specs) or {}) do
            out[#out + 1] = { key = tostring(specKey), label = SpecName(specKey) }
        end
        table.sort(out, function(a, b) return a.label < b.label end)
    elseif kind == "styles" then
        for _, k in ipairs({ "icons", "bars" }) do
            for name in pairs(((db.specialStyles or {})[k]) or {}) do
                out[#out + 1] = { key = k .. ":" .. name, label = (k == "icons" and "Icon: " or "Bar: ") .. name }
            end
        end
        table.sort(out, function(a, b) return a.label < b.label end)
    else
        local seen, general = {}, false
        local function scan(t)
            for k, v in pairs(type(t) == "table" and t or {}) do
                if type(v) == "table" then
                    if not seen[k] then seen[k] = true; out[#out + 1] = { key = k, label = Pretty(k) } end
                else
                    general = true
                end
            end
        end
        scan(P and P.thingsUI and P.thingsUI[id])
        scan(db[id])
        table.sort(out, function(a, b) return a.label < b.label end)
        if general then table.insert(out, 1, { key = "_general", label = LABELS._general }) end
    end
    return out
end

-- ------------------------------------------------------------ copying

-- the defaults a stored (sparse) table leaves out
local function MergeDefaults(dst, def)
    if type(dst) ~= "table" or type(def) ~= "table" then return dst end
    for k, v in pairs(def) do
        if dst[k] == nil then dst[k] = DeepCopy(v)
        elseif type(dst[k]) == "table" and type(v) == "table" then MergeDefaults(dst[k], v) end
    end
    return dst
end

local function IDOf(t)
    if type(t) ~= "table" then return nil end
    if t.id ~= nil then return t.id end
    return t.name
end

-- puts old's own positions and/or sizes back into new; lists pair up by id or name, and
-- things old never had keep what they came with
local function Restore(new, old, top, pos, size)
    if type(new) ~= "table" or type(old) ~= "table" then return end
    if type(new[1]) == "table" and IDOf(new[1]) ~= nil then
        local byID = {}
        for _, o in ipairs(old) do
            local k = IDOf(o)
            if k ~= nil then byID[k] = o end
        end
        for _, n in ipairs(new) do Restore(n, byID[IDOf(n)], false, pos, size) end
        return
    end
    if pos then
        for k in pairs(POS) do new[k] = DeepCopy(old[k]) end
        if top then for k in pairs(TOP_POS) do new[k] = DeepCopy(old[k]) end end
    end
    if size then
        for k in pairs(SIZE) do new[k] = DeepCopy(old[k]) end
    end
    for k, v in pairs(new) do
        if type(v) == "table" and not POS[k] then Restore(v, old[k], false, pos, size) end
    end
end

-- does a module keep spots / sizes of its own? (spots held by ElvUI movers aren't in our data)
local function HasKey(t, set, top)
    if type(t) ~= "table" then return false end
    for k, v in pairs(t) do
        if set[k] or (top and set == POS and TOP_POS[k]) then return true end
        if type(v) == "table" and HasKey(v, set, false) then return true end
    end
    return false
end

-- docked: the module's size and spot come from somewhere else right now
local DOCKED = {
    damageMeter = function(db) return db and db.rightChatAsBackground and "Docked in Right Chat, which sets its size and spot." end,
}

function M.DockedNote(id)
    local f = DOCKED[id]
    return f and f(E.db and E.db.thingsUI) or nil
end

local function Holds(id, set)
    local sec = M.SectionByID(id)
    if not sec or M.DockedNote(id) then return false end
    local db = (E.db and E.db.thingsUI) or {}
    for _, k in ipairs(sec.keys) do
        if HasKey(db[k], set, true) or HasKey(P and P.thingsUI and P.thingsUI[k], set, true) then return true end
    end
    return false
end
function M.HasPositions(id) return Holds(id, POS) end
function M.HasSizes(id) return Holds(id, SIZE) end

-- one value for a member: the source's copy, the member's own positions/sizes kept unless synced
local function CopyFor(src, dstOld, def, cfg, top)
    local new = DeepCopy(src)
    local keepPos, keepSize = not cfg.pos, not cfg.size
    if (keepPos or keepSize) and type(new) == "table" then
        local old = MergeDefaults(DeepCopy(type(dstOld) == "table" and dstOld or {}), def)
        Restore(new, old, top, keepPos, keepSize)
    end
    return new
end

local function Def(k) return P and P.thingsUI and P.thingsUI[k] end

-- Aura Icons / Aura Bars find their group by id, ids differ per profile while names don't:
-- when only one side of that link is written, the links follow the names
local REFS = { customGroups = "icons", customBars = "bars" }

local function GroupNames(db, key)
    local out = {}
    local t = type(db) == "table" and db[key]
    for _, g in ipairs((type(t) == "table" and t.groups) or {}) do
        if type(g) == "table" and g.id ~= nil then out[g.id] = g.name end
    end
    return out
end

local function GroupIDs(db, key)
    local out = {}
    local t = type(db) == "table" and db[key]
    for _, g in ipairs((type(t) == "table" and t.groups) or {}) do
        if type(g) == "table" and g.name ~= nil and out[g.name] == nil then out[g.name] = g.id end
    end
    return out
end

local function Before(dst)
    return { customGroups = GroupNames(dst, "customGroups"), customBars = GroupNames(dst, "customBars") }
end

local function FixRefs(dst, before, src, keys)
    local wrote = {}
    for _, k in ipairs(keys) do wrote[k] = true end
    for owner, holder in pairs(REFS) do
        local names
        if wrote[owner] and not wrote.specialBars then names = before[owner]
        elseif wrote.specialBars and not wrote[owner] then names = GroupNames(src, owner) end
        if names then
            local ids = GroupIDs(dst, owner)
            local sb = dst.specialBars
            for _, s in pairs((type(sb) == "table" and sb.specs) or {}) do
                for _, d in pairs((type(s) == "table" and type(s[holder]) == "table" and s[holder]) or {}) do
                    if type(d) == "table" and d.customGroup ~= nil then d.customGroup = ids[names[d.customGroup]] end
                end
            end
        end
    end
end

local function Sub(t, k)
    if type(t[k]) ~= "table" then t[k] = {} end
    return t[k]
end

-- picked list entries by name: an existing one keeps its own id (and what is kept)
local function SomeList(src, dst, id, parts, cfg)
    local lk = LIST_KEY[id]
    local st = src[id]
    if type(st) ~= "table" then return end
    local dt = Sub(dst, id)
    dt[lk] = dt[lk] or {}
    local hasIDs = lk == "groups"
    local byName = {}
    for i, it in ipairs(dt[lk]) do
        byName[it.name or ""] = i
        if hasIDs and type(it.id) == "number" and it.id >= (dt.nextID or 1) then dt.nextID = it.id + 1 end
    end
    if hasIDs then dt.nextID = dt.nextID or 1 end
    for _, it in ipairs(st[lk] or {}) do
        local n = it.name or ""
        if parts["n:" .. n] then
            local i = byName[n]
            local old = i and dt[lk][i]
            local new = CopyFor(it, old, nil, old and cfg or { pos = true, size = true }, false)
            if hasIDs then
                if old then new.id = old.id else new.id = dt.nextID; dt.nextID = dt.nextID + 1 end
            end
            if i then dt[lk][i] = new else dt[lk][#dt[lk] + 1] = new; byName[n] = #dt[lk] end
        end
    end
end

-- All on Groups - Bars or Groups - Text: that kind mirrors by name, the other kind stays
local function KindMirror(src, dst, sec, cfg)
    local dk = sec.keys[1]
    local parts, names = {}, {}
    for _, it in ipairs(((type(src[dk]) == "table" and src[dk].groups) or {})) do
        if Fits(sec, it) and it.name then parts["n:" .. it.name] = true; names[it.name] = true end
    end
    local dt = dst[dk]
    if type(dt) == "table" and type(dt.groups) == "table" then
        local keep = {}
        for _, g in ipairs(dt.groups) do
            if not Fits(sec, g) or (g.name and names[g.name]) then keep[#keep + 1] = g end
        end
        dt.groups = keep
    end
    SomeList(src, dst, dk, parts, cfg)
end

-- one module from src into dst, by its mode
local function Write(src, dst, id, cfg)
    local sec = M.SectionByID(id)
    if not (sec and cfg and cfg.mode) then return end
    local before = Before(dst)
    local wrote = {}
    if cfg.mode == "all" and sec.only then
        KindMirror(src, dst, sec, cfg)
        wrote[1] = sec.keys[1]
    elseif cfg.mode == "all" then
        for _, k in ipairs(sec.keys) do
            dst[k] = CopyFor(src[k], dst[k], Def(k), cfg, true)
            wrote[#wrote + 1] = k
        end
    else
        local parts = cfg.parts or {}
        local kind = PartKind(id, sec)
        if kind == "keys" then
            for _, k in ipairs(sec.keys) do
                if parts[k] then
                    dst[k] = CopyFor(src[k], dst[k], Def(k), cfg, true)
                    wrote[#wrote + 1] = k
                end
            end
        elseif kind == "list" then
            SomeList(src, dst, sec.keys[1], parts, cfg)
            wrote[1] = sec.keys[1]
        elseif kind == "specs" then
            local ss = (type(src.specialBars) == "table" and src.specialBars.specs) or {}
            local ds = Sub(Sub(dst, "specialBars"), "specs")
            for specKey in pairs(parts) do
                local s = ss[specKey] or ss[tonumber(specKey)]
                if s ~= nil then ds[specKey] = CopyFor(s, ds[specKey], nil, cfg, false) end
            end
            wrote[1] = id
        elseif kind == "styles" then
            local ss = type(src.specialStyles) == "table" and src.specialStyles or {}
            local ds = Sub(dst, "specialStyles")
            for part in pairs(parts) do
                local k, name = part:match("^(%a+):(.+)$")
                if k and type(ss[k]) == "table" and ss[k][name] ~= nil then
                    Sub(ds, k)[name] = DeepCopy(ss[k][name])
                end
            end
        else
            local s = type(src[id]) == "table" and src[id] or {}
            local d = Sub(dst, id)
            local def = Def(id) or {}
            for part in pairs(parts) do
                if part == "_general" then
                    for k, v in pairs(s) do if type(v) ~= "table" then d[k] = v end end
                elseif s[part] ~= nil then
                    d[part] = CopyFor(s[part], d[part], def[part], cfg, false)
                end
            end
            wrote[1] = id
        end
    end
    FixRefs(dst, before, src, wrote)
end

local function DBOf(name)
    if name == Current() then return E.db.thingsUI end
    return ns.Share.ProfileDB(name, true)
end

-- the profile in use hands every synced module to the rest of the set
function M.Push(onlyID)
    local cur = Current()
    if not (cur and M.InSet(cur)) then return end
    local live = E.db and E.db.thingsUI
    if not live then return end
    local mods = Store().modules
    for _, name in ipairs(M.SetProfiles()) do
        if name ~= cur then
            local dst = ns.Share.ProfileDB(name, true)
            for id, cfg in pairs(mods) do
                if (not onlyID or onlyID == id) and type(cfg) == "table" and cfg.mode then Write(live, dst, id, cfg) end
            end
        end
    end
end

-- master's copy of one module into the given profiles; the profile in use reloads
-- (once, at the end, while M._batch is on)
function M.SeedTo(id, master, targets)
    local cfg = M.Module(id)
    if not (cfg and cfg.mode) then return end
    local src = DBOf(master) or {}
    local mine = false
    for _, name in ipairs(targets) do
        if name ~= master and Profiles()[name] then
            if name == Current() then
                local live = E.db.thingsUI
                Write(src, live, id, cfg)
                -- a sparse source leaves out defaults the live profile needs
                local sec = M.SectionByID(id)
                for _, k in ipairs(sec and sec.keys or {}) do
                    if type(live[k]) == "table" then MergeDefaults(live[k], Def(k))
                    elseif live[k] == nil and Def(k) ~= nil then live[k] = DeepCopy(Def(k)) end
                end
                mine = true
            else
                Write(src, ns.Share.ProfileDB(name, true), id, cfg)
            end
        end
    end
    if mine then
        if M._batch then
            M._reload = true
        else
            if TUI.ProfileUpdate then TUI:ProfileUpdate() end
            E:StaticPopup_Show("CONFIG_RL")
        end
    end
end

local function EndBatch()
    M._batch = nil
    if M._reload then
        M._reload = nil
        if TUI.ProfileUpdate then TUI:ProfileUpdate() end
        E:StaticPopup_Show("CONFIG_RL")
    end
end

-- ------------------------------------------------- telling differences apart

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- whether name's copy of a module differs from master's, positions/sizes aside unless synced
local function Norm(v, k)
    if type(v) == "table" then return MergeDefaults(DeepCopy(v), Def(k)) end
    if v == nil then return DeepCopy(Def(k)) end
    return v
end

-- would a sync from master change name's copy of the module? (a dry run on a copy)
function M.Differs(id, master, name)
    local cfg = M.Module(id)
    if not (cfg and cfg.mode) then cfg = { mode = "all" } end
    local sec = M.SectionByID(id)
    if not sec then return false end
    local src, dst = DBOf(master) or {}, DBOf(name) or {}
    local probe = {}
    for _, k in ipairs(sec.keys) do probe[k] = DeepCopy(dst[k]) end
    if REFS[id] or id == "specialBars" then
        for _, k in ipairs({ "specialBars", "customGroups", "customBars" }) do
            if probe[k] == nil then probe[k] = DeepCopy(dst[k]) end
        end
    end
    Write(src, probe, id, cfg)
    for _, k in ipairs(sec.keys) do
        if not Same(Norm(probe[k], k), Norm(dst[k], k)) then return true end
    end
    return false
end

-- ------------------------------------------------- group lists meeting

-- Groups - Icons and Groups - Bars/Text: a member's groups meet the master's by name
local LISTS = { customGroups = "icons", customBars = "bars" }

-- a list module: its data key, member layout and group kind filter
local function ListOf(id)
    local sec = M.SectionByID(id)
    local dk = sec and sec.keys[1]
    if not (dk and LISTS[dk]) then return nil end
    return dk, LISTS[dk], sec
end
function M.IsList(id) return ListOf(id) ~= nil end

local function Scopes(g, kind)
    local out = {}
    if kind == "icons" then out[#out + 1] = { "g", g.global, { "spells", "items", "auras" } }
    else out[#out + 1] = { "g", g, { "auras" } } end
    local kinds = (kind == "icons") and { "spells", "items", "auras" } or { "auras" }
    for ck, r in pairs(g.classes or {}) do out[#out + 1] = { "c:" .. tostring(ck), r, kinds } end
    for sk, r in pairs(g.specs or {}) do out[#out + 1] = { "s:" .. tostring(sk), r, kinds } end
    return out
end

-- a group's members, path -> { scope, list, id, e }
local function MemberMap(g, kind)
    local out = {}
    if type(g) ~= "table" then return out end
    for _, sc in ipairs(Scopes(g, kind)) do
        local scope, root, lists = sc[1], sc[2], sc[3]
        if type(root) == "table" then
            for _, l in ipairs(lists) do
                for id, e in pairs((type(root[l]) == "table" and root[l]) or {}) do
                    out[scope .. "/" .. l .. "/" .. tostring(id)] = { scope = scope, list = l, id = id, e = e }
                end
            end
        end
    end
    if kind == "bars" then
        for _, c in ipairs(g.cooldowns or {}) do
            if type(c) == "table" and c.id then out["cd/" .. tostring(c.id)] = { scope = "cd", id = c.id, e = c } end
        end
    end
    return out
end

local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- what master's list does to other's: onlyOther (gone unless kept), onlyMaster (added),
-- differ (both have members, not the same), takeOther (master's copy empty)
function M.GroupDiff(id, master, other)
    local dk, kind, sec = ListOf(id)
    if not dk then return nil end
    local mt, ot = (DBOf(master) or {})[dk], (DBOf(other) or {})[dk]
    local mg, og = {}, {}
    for _, g in ipairs((type(mt) == "table" and mt.groups) or {}) do if Fits(sec, g) then mg[#mg + 1] = g end end
    for _, g in ipairs((type(ot) == "table" and ot.groups) or {}) do if Fits(sec, g) then og[#og + 1] = g end end
    local byName, seen = {}, {}
    for _, g in ipairs(mg) do byName[g.name or ""] = g end
    local d = { onlyOther = {}, onlyMaster = {}, differ = {}, takeOther = {} }
    for _, g in ipairs(og) do
        local n = g.name or ""
        seen[n] = true
        local m = byName[n]
        if not m then
            d.onlyOther[#d.onlyOther + 1] = n
        else
            local a, b = MemberMap(m, kind), MemberMap(g, kind)
            local same = true
            for k in pairs(a) do if b[k] == nil then same = false break end end
            if same then for k in pairs(b) do if a[k] == nil then same = false break end end end
            if not same then
                local na, nb = Count(a), Count(b)
                if na == 0 then d.takeOther[#d.takeOther + 1] = { name = n, other = nb }
                elseif nb > 0 then d.differ[#d.differ + 1] = { name = n, master = na, other = nb } end
            end
        end
    end
    for _, g in ipairs(mg) do
        if not seen[g.name or ""] then d.onlyMaster[#d.onlyMaster + 1] = g.name or "" end
    end
    return d
end

function M.HasConflicts(d)
    return d and (#d.onlyOther + #d.differ + #d.takeOther) > 0
end

local function RootFor(g, kind, scope, create)
    if scope == "g" then
        if kind ~= "icons" then return g end
        if create and type(g.global) ~= "table" then g.global = {} end
        return g.global
    end
    local tag, key = scope:match("^(%a):(.+)$")
    local bucket = (tag == "c") and "classes" or "specs"
    if create and type(g[bucket]) ~= "table" then g[bucket] = {} end
    local t = g[bucket]
    if not t then return nil end
    if create and type(t[key]) ~= "table" then t[key] = {} end
    return t[key]
end

local function MaxIndex(root)
    local mx = 0
    for _, l in ipairs({ "spells", "items", "auras" }) do
        for _, e in pairs((type(root[l]) == "table" and root[l]) or {}) do
            if type(e) == "table" and type(e.layoutIndex) == "number" and e.layoutIndex > mx and e.layoutIndex < 90000 then mx = e.layoutIndex end
        end
    end
    return mx
end

-- other's members that master lacks join master's group, after its own
local function Union(m, g, kind)
    local have = MemberMap(m, kind)
    for path, it in pairs(MemberMap(g, kind)) do
        if not have[path] then
            if it.scope == "cd" then
                m.cooldowns = m.cooldowns or {}
                m.cooldowns[#m.cooldowns + 1] = DeepCopy(it.e)
            else
                local root = RootFor(m, kind, it.scope, true)
                root[it.list] = root[it.list] or {}
                local e = DeepCopy(it.e)
                if type(e) == "table" and e.layoutIndex then e.layoutIndex = MaxIndex(root) + 1 end
                root[it.list][it.id] = e
            end
        end
    end
end

-- choices: keep[name] = other's own group joins master, merge[name] = members join
function M.MergeInto(id, master, other, choices)
    local dk, kind, sec = ListOf(id)
    if not dk then return end
    local mine = master == Current()
    local mdb = DBOf(master)
    local mt = mdb[dk]
    if type(mt) ~= "table" then
        mt = DeepCopy(Def(dk)) or {}
        mdb[dk] = mt
    end
    mt.groups = mt.groups or {}
    mt.nextID = mt.nextID or 1
    local byName = {}
    for _, g in ipairs(mt.groups) do
        if Fits(sec, g) then byName[g.name or ""] = g end
        if type(g.id) == "number" and g.id >= mt.nextID then mt.nextID = g.id + 1 end
    end
    local ot = (DBOf(other) or {})[dk]
    for _, g in ipairs((type(ot) == "table" and ot.groups) or {}) do
        local n = g.name or ""
        local m = byName[n]
        if not Fits(sec, g) then
            -- the other kind is another module's business
        elseif not m then
            if choices.keep[n] then
                local ng = DeepCopy(g)
                ng.id = mt.nextID
                mt.nextID = mt.nextID + 1
                mt.groups[#mt.groups + 1] = ng
                byName[n] = ng
            end
        elseif choices.merge[n] then
            Union(m, g, kind)
        end
    end
    if mine then
        if dk == "customGroups" and TUI.UpdateCustomGroups then TUI:UpdateCustomGroups() end
        if dk == "customBars" and TUI.UpdateCustomBars then TUI:UpdateCustomBars() end
    end
end

-- ------------------------------------------------- setting it up, with questions

local POPUP = { text = "%s", selectCallbackByIndex = true, timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3 }

-- Cancel and Escape both count as no, once
local function No(d)
    if d and d.no and not d.done then d.done = true; d.no() end
end

E.PopupDialogs.TUI_SYNC_CONFIRM = CreateFromMixins(POPUP, {
    button1 = "Sync", button2 = CANCEL,
    OnButton1 = function(_, d) if d then d.done = true end if d and d.yes then d.yes() end end,
    OnButton2 = function(_, d) No(d) end,
    OnCancel = function(_, d) No(d) end,
})

E.PopupDialogs.TUI_SYNC_WHOSE = CreateFromMixins(POPUP, {
    OnButton1 = function(_, d) if d then d.done = true end if d and d.pick then d.pick(true) end end,
    OnButton2 = function(_, d) if d then d.done = true end if d and d.pick then d.pick(false) end end,
    OnButton3 = function(_, d) No(d) end,
    OnCancel = function(_, d) No(d) end,
})

local function ModuleName(id)
    local sec = M.SectionByID(id)
    return sec and sec.name or id
end
M.ModuleName = ModuleName

local function Confirm(text, yes, no)
    E:StaticPopup_Show("TUI_SYNC_CONFIRM", text, nil, { yes = yes, no = no })
end

-- master's module goes to targets: list modules in All ask where groups don't line up,
-- the rest warn when targets differ; nothing changes on Cancel
function M.SeedModule(id, targets, done, quiet, no, master)
    master = master or Current()
    local cfg = M.Module(id)
    if not (cfg and cfg.mode and master) then return end
    local others = {}
    for _, n in ipairs(targets) do if n ~= master then others[#others + 1] = n end end
    if #others == 0 then if done then done() end return end
    local function Finish()
        M.SeedTo(id, master, others)
        if done then done() end
    end
    if cfg.mode == "all" and M.IsList(id) then
        local i = 0
        local function Next()
            i = i + 1
            local other = others[i]
            if not other then Finish() return end
            local d = M.GroupDiff(id, master, other)
            if M.HasConflicts(d) then
                M.OpenResolver(id, master, other, d, function(choices)
                    M.MergeInto(id, master, other, choices)
                    Next()
                end, no)
            else
                Next()
            end
        end
        Next()
        return
    end
    local differ = {}
    for _, n in ipairs(others) do if M.Differs(id, master, n) then differ[#differ + 1] = n end end
    if quiet or #differ == 0 or cfg.mode == "some" then Finish() return end
    Confirm(("|cFFFFD200%s|r is different in |cFF8AC8FF%s|r.\nThat gets |cFF8AC8FF%s|r's settings."):format(
        ModuleName(id), table.concat(differ, ", "), master), Finish, no)
end

local function SyncedIDs()
    local ids = {}
    for id, cfg in pairs(Store().modules) do if type(cfg) == "table" and cfg.mode then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
end
M.SyncedIDs = SyncedIDs

-- this profile joins a set that already syncs: it takes a member's settings or hands over its own
function M.JoinSelf(done)
    local cur = Current()
    local others = {}
    for _, n in ipairs(M.SetProfiles()) do if n ~= cur then others[#others + 1] = n end end
    local ids = SyncedIDs()
    if #others == 0 or #ids == 0 then
        M.SetInSet(cur, true)
        if done then done() end
        return
    end
    local other = others[1]
    local dlg = E.PopupDialogs.TUI_SYNC_WHOSE
    dlg.button1, dlg.button2, dlg.button3 = "Use " .. other .. "'s", "Use This Profile's", CANCEL
    E:StaticPopup_Show("TUI_SYNC_WHOSE", ("|cFF8AC8FF%s|r joins the sync of %s.\nWhose settings? The others are replaced."):format(
        cur, table.concat(others, ", ")), nil, { pick = function(theirs)
        M.SetInSet(cur, true)
        local master = theirs and other or cur
        local targets = theirs and { cur } or M.SetProfiles()
        M._batch = true
        local i = 0
        local function Next()
            i = i + 1
            local id = ids[i]
            if not id then
                EndBatch()
                if done then done() end
                return
            end
            M.SeedModule(id, targets, Next, true, function() M.SetInSet(cur, false); EndBatch() end, master)
        end
        Next()
    end })
end

-- name joins the set: every synced module of this profile goes to it
function M.Join(name, done)
    local master = Current()
    local ids = {}
    for id, cfg in pairs(Store().modules) do if type(cfg) == "table" and cfg.mode then ids[#ids + 1] = id end end
    table.sort(ids)
    if name == master or #ids == 0 or not M.InSet(master) then
        M.SetInSet(name, true)
        if done then done() end
        return
    end
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = ModuleName(id) end
    Confirm(("|cFF8AC8FF%s|r joins the sync: its %s get this profile's settings."):format(name, table.concat(names, ", ")), function()
        M.SetInSet(name, true)
        local i = 0
        local function Next()
            i = i + 1
            local id = ids[i]
            if not id then if done then done() end return end
            local cfg = M.Module(id)
            if cfg and cfg.mode == "all" and M.IsList(id) then
                local d = M.GroupDiff(id, master, name)
                if M.HasConflicts(d) then
                    M.OpenResolver(id, master, name, d, function(choices)
                        M.MergeInto(id, master, name, choices)
                        M.SeedTo(id, master, { name })
                        Next()
                    end)
                    return
                end
            end
            M.SeedTo(id, master, { name })
            Next()
        end
        Next()
    end)
end

-- the questions for one list module, one window
function M.OpenResolver(id, master, other, d, apply, cancel)
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    if M._resolver then AceGUI:Release(M._resolver) end
    local f = AceGUI:Create("Frame")
    if ns.SolidDialog then ns.SolidDialog(f) end
    M._resolver = f
    local decided = false
    f:SetCallback("OnClose", function(w)
        if M._resolver == w then M._resolver = nil end
        AceGUI:Release(w)
        if not decided and cancel then cancel() end
    end)
    f:SetTitle("|cFF8080FFthingsUI|r Profile Sync: " .. ModuleName(id))
    f:SetLayout("Flow")
    f:SetWidth(520)
    f:SetHeight(520)
    local function Text(t)
        local l = AceGUI:Create("Label")
        l:SetFullWidth(true)
        l:SetFontObject(GameFontHighlight)
        l:SetText(t)
        f:AddChild(l)
    end
    local function Head(t)
        local h = AceGUI:Create("Heading")
        h:SetFullWidth(true)
        h:SetText(t)
        f:AddChild(h)
    end
    local M_, O_ = "|cFF8AC8FF" .. master .. "|r", "|cFF8AC8FF" .. other .. "|r"
    Text(("%s hands its groups to %s. Look and size follow %s; groups are matched by name.\n "):format(M_, O_, M_))
    local choices = { keep = {}, merge = {} }
    if #d.onlyOther > 0 then
        Head("Only in " .. other)
        Text(("No group with these names in %s - kept, they're added to %s too; unticked, they're gone from %s."):format(M_, M_, O_))
        for _, n in ipairs(d.onlyOther) do
            choices.keep[n] = true
            local cb = AceGUI:Create("CheckBox")
            cb:SetLabel("Keep '" .. n .. "'")
            cb:SetWidth(230)
            cb:SetValue(true)
            cb:SetCallback("OnValueChanged", function(_, _, v) choices.keep[n] = v and true or nil end)
            f:AddChild(cb)
        end
    end
    if #d.differ > 0 then
        Head("Same name, different members")
        for _, it in ipairs(d.differ) do
            choices.merge[it.name] = true
            local dd = AceGUI:Create("Dropdown")
            dd:SetLabel(("'%s': %s has %d, %s has %d"):format(it.name, master, it.master, other, it.other))
            dd:SetWidth(460)
            dd:SetList({ merge = "Merge both (everything from both ends up in both)", master = "Use " .. master .. "'s" }, { "merge", "master" })
            dd:SetValue("merge")
            dd:SetCallback("OnValueChanged", function(_, _, v) choices.merge[it.name] = (v == "merge") or nil end)
            f:AddChild(dd)
        end
    end
    if #d.takeOther > 0 then
        Head("Empty in " .. master)
        for _, it in ipairs(d.takeOther) do
            choices.merge[it.name] = true
            local cb = AceGUI:Create("CheckBox")
            cb:SetLabel(("'%s': take %s's %d"):format(it.name, other, it.other))
            cb:SetFullWidth(true)
            cb:SetValue(true)
            cb:SetCallback("OnValueChanged", function(_, _, v) choices.merge[it.name] = v and true or nil end)
            f:AddChild(cb)
        end
    end
    if #d.onlyMaster > 0 then
        Text(" \n|cFF888888New in " .. other .. ": " .. table.concat(d.onlyMaster, ", ") .. "|r")
    end
    Text(" ")
    local go = AceGUI:Create("Button")
    go:SetText("Sync")
    go:SetWidth(160)
    go:SetCallback("OnClick", function()
        decided = true
        AceGUI:Release(f)
        apply(choices)
    end)
    f:AddChild(go)
    local no = AceGUI:Create("Button")
    no:SetText(CANCEL)
    no:SetWidth(160)
    no:SetCallback("OnClick", function() AceGUI:Release(f) end)
    f:AddChild(no)
end

-- ------------------------------------------------- pack config

-- this profile's sync setup, for an export (only while it really syncs)
function M.ExportConfig(ids)
    if not M.Active() then return nil end
    local out, any = {}, false
    for _, id in ipairs(ids) do
        local c = M.Module(id)
        if c and c.mode then
            out[id] = DeepCopy(c)
            any = true
        end
    end
    return any and out or nil
end

-- a pack's setup, cleaned: { [id] = cfg } (the first build exported a list of ids)
function M.ReadConfig(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for k, v in pairs(raw) do
        local id, cfg = k, v
        if type(k) == "number" and type(v) == "string" then id, cfg = v, { mode = "all" } end
        if type(id) == "string" and M.SectionByID(id) and type(cfg) == "table"
            and (cfg.mode == "all" or cfg.mode == "some") then
            out[id] = { mode = cfg.mode, pos = cfg.pos and true or nil, size = cfg.size and true or nil,
                parts = type(cfg.parts) == "table" and DeepCopy(cfg.parts) or nil }
        end
    end
    return out
end

-- ------------------------------------------------- staying safe

-- a profile whose thingsUI was just replaced must not spread it to the set
local function Leave(name, why)
    if not (name and M.InSet(name)) then return end
    Store().profiles[name] = nil
    if why then
        print(("|cFF8080FFthingsUI|r: %s %s, so it left Profile Sync. Tick it again under thingsUI -> Sync."):format(name, why))
    end
end
M.Leave = Leave

function M.Init()
    if M._init or not (E.data and E.data.RegisterCallback) then return end
    M._init = true
    local db = E.data
    -- before AceDB lets go of the old profile, and before it strips defaults at logout
    db.RegisterCallback(M, "OnProfileShutdown", function() M.Push() end)
    db.RegisterCallback(M, "OnDatabaseShutdown", function() M.Push() end)
    db.RegisterCallback(M, "OnProfileDeleted", function(_, _, name) Leave(name) end)
    db.RegisterCallback(M, "OnProfileReset", function() Leave(Current(), "was reset") end)
    -- copying a fellow set member changes nothing; anything else leaves
    db.RegisterCallback(M, "OnProfileCopied", function(_, _, from)
        if not M.InSet(from) then Leave(Current(), "was copied from " .. tostring(from)) end
    end)
    -- an imported ElvUI profile carries no thingsUI (ElvUI's export leaves it out):
    -- it leaves the set before ElvUI swaps to it, or it would spread defaults
    local D = E:GetModule("Distributor", true)
    if D and D.SetImportedProfile then
        local orig = D.SetImportedProfile
        D.SetImportedProfile = function(self, dataType, dataKey, ...)
            if dataType == "profile" and type(dataKey) == "string" then Leave(dataKey, "was imported") end
            return orig(self, dataType, dataKey, ...)
        end
    end
end
