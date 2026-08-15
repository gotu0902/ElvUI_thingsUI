local _, ns = ...

-- temp: /tuitotem sink probe
SLASH_TUITOTEM1 = "/tuitotem"
SlashCmdList.TUITOTEM = function()
    local have, name, start, dur, icon = GetTotemInfo(1)
    local sv = issecretvalue
    print("|cff16c3f2tuitotem|r combat=" .. (InCombatLockdown() and "YES" or "no")
        .. " secret=" .. ((sv and sv(start)) and "YES" or "no"))

    local f = _G.TUI_TotemProbe
    if not f then
        f = CreateFrame("Frame", "TUI_TotemProbe", UIParent)
        f:SetSize(40, 40)
        f:SetPoint("CENTER", 0, 200)
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetAllPoints(f)
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetAllPoints(f)
        f.bar = CreateFrame("StatusBar", nil, UIParent)
        f.bar:SetSize(120, 14)
        f.bar:SetPoint("TOP", f, "BOTTOM", 0, -4)
        f.bar:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
        f.bar:SetStatusBarColor(1, 0.6, 0.1)
        f.bar.bg = f.bar:CreateTexture(nil, "BACKGROUND")
        f.bar.bg:SetAllPoints()
        f.bar.bg:SetColorTexture(0, 0, 0, 0.6)
        f.slide = f.bar:CreateAnimationGroup()
        f.anim = f.slide:CreateAnimation("Translation")
        f.anim:SetTarget(f.bar)
        f.anim:SetOffset(0, -30)
    end
    f:Show()
    f.bar:Show()

    local ok, err = pcall(f.tex.SetTexture, f.tex, icon)
    print("icon SetTexture: " .. (ok and "OK" or ("THREW: " .. tostring(err))))

    ok, err = pcall(f.cd.SetCooldown, f.cd, start, dur)
    print("cd SetCooldown: " .. (ok and "OK" or ("THREW: " .. tostring(err))))

    ok, err = pcall(function()
        f.bar:SetMinMaxValues(0, dur)
        f.bar:SetValue(start + dur - GetTime())
    end)
    print("bar SetValue: " .. (ok and "OK" or ("THREW: " .. tostring(err))))

    ok, err = pcall(function()
        f.slide:Stop()
        f.anim:SetDuration(start + dur - GetTime())
        f.slide:Play()
    end)
    print("anim SetDuration: " .. (ok and "OK" or ("THREW: " .. tostring(err))))
end
