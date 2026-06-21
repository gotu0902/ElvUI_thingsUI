local _, ns = ...

local Pixel = {}
ns.Pixel = Pixel

local math_floor = math.floor
local math_ceil  = math.ceil

local function GetEffectiveScale(frame)
    if frame and frame.GetEffectiveScale then
        local s = frame:GetEffectiveScale()
        if s and s > 0 then return s end
    end
    if UIParent and UIParent.GetEffectiveScale then
        local s = UIParent:GetEffectiveScale()
        if s and s > 0 then return s end
    end
    return 1
end

function Pixel.Size(frame)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, GetEffectiveScale(frame))
    end
    local E = ElvUI and ElvUI[1] or nil
    return (E and E.mult) or 1
end

-- Round to the nearest pixel step
function Pixel.Snap(value, frame)
    if not value or value == 0 then return 0 end
    local step = Pixel.Size(frame)
    if value >= 0 then
        return math_floor(value / step + 0.5) * step
    end
    return math_ceil(value / step - 0.5) * step
end

-- Prefer PixelUtil's own SetPoint/SetSize when available
function Pixel.SetPoint(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return end
    if PixelUtil and PixelUtil.SetPoint then
        PixelUtil.SetPoint(frame, point, relativeTo, relativePoint, x or 0, y or 0)
    else
        frame:SetPoint(point, relativeTo, relativePoint, Pixel.Snap(x or 0, frame), Pixel.Snap(y or 0, frame))
    end
end

function Pixel.SetSize(frame, width, height)
    if not frame then return end
    width  = width or 1
    height = height or width
    if PixelUtil and PixelUtil.SetSize then
        PixelUtil.SetSize(frame, width, height)
    else
        frame:SetSize(Pixel.Snap(width, frame), Pixel.Snap(height, frame))
    end
end
