local addon, ns = ...
local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")

local TUI = E:NewModule("thingsUI", "AceHook-3.0", "AceEvent-3.0")

ns.addon = addon
ns.E = E
ns.EP = EP
ns.TUI = TUI
ns.LSM = E.Libs.LSM

TUI.version = "4.0.0"
TUI.name = "thingsUI"

ns.skinnedBars = ns.skinnedBars or {}
ns.yoinkedBars = ns.yoinkedBars or {}

function ns.NotifyChange()
    local reg = LibStub("AceConfigRegistry-3.0", true)
    if reg and reg.NotifyChange then reg:NotifyChange("ElvUI") end
end

function ns.ClassColor(token)
    local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]) or { r = 1, g = 1, b = 1 }
    return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

function ns.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = ns.DeepCopy(v) end
    return out
end

function ns.FontValues()
    local out = {}
    if ns.LSM then for _, n in ipairs(ns.LSM:List("font")) do out[n] = n end end
    return out
end

local _allSpecs, _specByID, _specsByClass
local function BuildSpecCache()
    _allSpecs, _specByID, _specsByClass = {}, {}, {}
    if not (GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then return end
    for cid = 1, GetNumClasses() do
        local className, classToken, classID = GetClassInfo(cid)
        if classID then
            local list = {}
            for i = 1, (GetNumSpecializationsForClassID(classID) or 0) do
                local id, name, _, icon = GetSpecializationInfoForClassID(classID, i)
                if id then
                    local rec = { id = id, name = name, icon = icon, classID = classID,
                                  classToken = classToken, className = className, specIndex = i }
                    _allSpecs[#_allSpecs + 1] = rec
                    _specByID[id] = rec
                    list[#list + 1] = rec
                end
            end
            _specsByClass[classID] = list
        end
    end
end
local function EnsureSpecCache() if not _allSpecs then BuildSpecCache() end end

function ns.AllSpecs()             EnsureSpecCache(); return _allSpecs end
function ns.SpecMeta(id)           EnsureSpecCache(); return _specByID[id] end
function ns.SpecsForClass(classID) EnsureSpecCache(); return _specsByClass[classID] or {} end