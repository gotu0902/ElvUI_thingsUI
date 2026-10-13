local _, ns = ...

-- One hooksecurefunc per Blizzard viewer method, fanned out to every module that wants it.
ns.ViewerHooks = ns.ViewerHooks or {}
local VH = ns.ViewerHooks

local lists = {}

-- securecallfunction keeps one module's error from skipping the rest, as separate hooks did
local function Dispatch(list, ...)
    for i = 1, #list do securecallfunction(list[i].fn, ...) end
end

-- Subscribe (or replace) `key`'s handler; false while the viewer is not there yet.
function VH.On(viewer, method, key, fn)
    if type(viewer) == "string" then viewer = _G[viewer] end
    if not viewer or type(viewer[method]) ~= "function" then return false end
    local byMethod = lists[viewer]
    if not byMethod then byMethod = {}; lists[viewer] = byMethod end
    local list = byMethod[method]
    if not list then
        list = {}
        byMethod[method] = list
        hooksecurefunc(viewer, method, function(...) Dispatch(list, ...) end)
    end
    for i = 1, #list do
        if list[i].key == key then list[i].fn = fn; return true end
    end
    list[#list + 1] = { key = key, fn = fn }
    return true
end
