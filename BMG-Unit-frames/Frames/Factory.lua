--[[
  BMG Unit Frames — secure unit button factory
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Factory = UF.Factory or {}
local Factory = UF.Factory

local LayoutVisual

local function Templates()
    if BackdropTemplateMixin then
        return "SecureUnitButtonTemplate,BackdropTemplate"
    end
    return "SecureUnitButtonTemplate"
end

local TEX_CLASSIC = "Interface\\TargetingFrame\\UI-StatusBar"
local TEX_MODERN_HEALTH = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
local TEX_MODERN_POWER = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill"
local TEX_BLOCKY = "Interface\\Buttons\\WHITE8x8"

local function StyleId(cfg)
    local id = cfg and cfg.barStyle
    if id == "modern" or id == "blocky" then
        return id
    end
    return "blizzard"
end

local function BarTexture(style, kind)
    if style == "blocky" then
        return TEX_BLOCKY
    end
    if style == "modern" then
        if kind == "power" then
            return TEX_MODERN_POWER
        end
        return TEX_MODERN_HEALTH
    end
    return TEX_CLASSIC
end

local function PrepBar(bar)
    if not bar then
        return
    end
    if bar.SetOrientation then
        bar:SetOrientation("HORIZONTAL")
    end
    if bar.SetRotatesTexture then
        bar:SetRotatesTexture(false)
    end
    if bar.SetReverseFill then
        bar:SetReverseFill(false)
    end
end

local function EnsureBarBg(bar)
    if not bar._ufBg then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bar._ufBg = bg
    end
    return bar._ufBg
end

local function EnsureBarEdge(bar)
    if bar._ufEdge then
        return bar._ufEdge
    end
    local function Strip(layer)
        local t = bar:CreateTexture(nil, layer or "OVERLAY")
        t:SetColorTexture(0, 0, 0, 1)
        return t
    end
    local top = Strip("BORDER")
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    local bottom = Strip("BORDER")
    bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    local left = Strip("BORDER")
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    local right = Strip("BORDER")
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar._ufEdge = { top = top, bottom = bottom, left = left, right = right }
    return bar._ufEdge
end

local function PaintBarEdge(bar, r, g, b, a, size)
    local edge = EnsureBarEdge(bar)
    size = size or 1
    a = a or 1
    edge.top:SetHeight(size)
    edge.bottom:SetHeight(size)
    edge.left:SetWidth(size)
    edge.right:SetWidth(size)
    edge.top:SetColorTexture(r, g, b, a)
    edge.bottom:SetColorTexture(r, g, b, a)
    edge.left:SetColorTexture(r, g, b, a)
    edge.right:SetColorTexture(r, g, b, a)
    edge.top:Show()
    edge.bottom:Show()
    edge.left:Show()
    edge.right:Show()
end

local function SkinBar(bar, style, kind, fillOnly)
    if not bar then
        return
    end
    style = StyleId({ barStyle = style })
    PrepBar(bar)
    local tex = BarTexture(style, kind)
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(tex)
    end
    if fillOnly then
        return
    end
    local bg = EnsureBarBg(bar)
    if style == "blocky" then
        bg:SetTexture(TEX_BLOCKY)
        bg:SetVertexColor(0.02, 0.02, 0.02, 1)
        PaintBarEdge(bar, 0, 0, 0, 1, 1)
    elseif style == "modern" then
        bg:SetTexture(tex)
        bg:SetVertexColor(0.10, 0.10, 0.12, 0.90)
        PaintBarEdge(bar, 0.06, 0.06, 0.07, 1, 1)
    else
        bg:SetTexture(TEX_CLASSIC)
        bg:SetVertexColor(0, 0, 0, 0.55)
        PaintBarEdge(bar, 0.18, 0.14, 0.08, 0.95, 2)
    end
end

function Factory.StyleId(cfg)
    return StyleId(cfg)
end

function Factory.SkinBar(bar, style, kind, fillOnly)
    SkinBar(bar, style, kind, fillOnly)
end

local function PortraitMode(cfg, profile)
    local mode = (cfg and cfg.portrait) or (profile and profile.portrait) or "2d"
    if mode == "portrait" then
        return "2d"
    end
    if mode == "off" then
        return "hidden"
    end
    return mode
end

local function HealthColorMode(profile, cfg)
    local mode = (cfg and cfg.healthColor) or (profile and profile.healthColor)
    if mode == "blizzard" or mode == "class" then
        return mode
    end
    if profile and profile.style == "classic" then
        return "blizzard"
    end
    return "class"
end

local NAME_BG = {
    dark = { 0.06, 0.06, 0.06 },
    transparent = { 0, 0, 0 },
    black = { 0, 0, 0 },
    gold = { 0.32, 0.26, 0.05 },
    health = { 0.12, 0.72, 0.18 },
}

local NAME_TEXT = {
    white = { 1, 1, 1 },
    gold = { 1, 0.92, 0.4 },
    black = { 0, 0, 0 },
}

local function NamePlace(cfg)
    local place = cfg and cfg.nameBar
    if place == "overlay" or place == "bottom" or place == "hidden" or place == "top" then
        return place
    end
    return "top"
end

local function NameStripH(cfg)
    if NamePlace(cfg) ~= "top" and NamePlace(cfg) ~= "bottom" then
        return 0
    end
    local h = tonumber(cfg and cfg.nameBarH) or 16
    if h < 10 then
        h = 10
    end
    if h > 32 then
        h = 32
    end
    return h
end

local function PickColor(id, unit, kind)
    if id == "class" then
        return UF.Theme.ClassColor(unit)
    end
    local pack = (kind == "text") and NAME_TEXT or NAME_BG
    local c = pack[id]
    if c then
        return c[1], c[2], c[3]
    end
    if kind == "text" then
        return 1, 1, 1
    end
    return 0.06, 0.06, 0.06
end

local function PaintNameBar(frame, cfg, unit)
    if not frame.NameBar then
        return
    end
    local place = NamePlace(cfg)
    if place == "hidden" then
        frame.NameBar:Hide()
        if frame.NameFS then
            frame.NameFS:Hide()
        end
        if frame.LevelFS then
            frame.LevelFS:Hide()
        end
        return
    end
    frame.NameBar:Show()
    if frame.NameFS then
        frame.NameFS:Show()
    end
    if frame.LevelFS then
        if cfg.showLevel == false then
            frame.LevelFS:Hide()
        else
            frame.LevelFS:Show()
        end
    end
    local bgId = cfg.nameBg or "dark"
    local br, bg, bb = PickColor(bgId, unit, "bg")
    local fillA, borderA = 1, 1
    if bgId == "transparent" then
        fillA = 0
        borderA = 0
    end
    local style = StyleId(cfg)
    local er, eg, eb, edge = 0.22, 0.22, 0.22, 2
    if style == "blocky" then
        er, eg, eb, edge = 0, 0, 0, 1
    elseif style == "modern" then
        er, eg, eb, edge = 0.06, 0.06, 0.07, 1
    else
        er, eg, eb, edge = 0.18, 0.14, 0.08, 2
    end
    if UF.Widgets and UF.Widgets.Paint then
        UF.Widgets.Paint(frame.NameBar, br, bg, bb, fillA, er, eg, eb)
        if frame.NameBar.SetBackdrop then
            frame.NameBar:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = edge,
                insets = { left = edge, right = edge, top = edge, bottom = edge },
            })
            frame.NameBar:SetBackdropColor(br, bg, bb, fillA)
            frame.NameBar:SetBackdropBorderColor(er, eg, eb, borderA)
        elseif frame.NameBar.SetBackdropBorderColor then
            frame.NameBar:SetBackdropBorderColor(er, eg, eb, borderA)
        end
    end
    if frame.NameFS then
        local tr, tg, tb = PickColor(cfg.nameText or "white", unit, "text")
        frame.NameFS:SetTextColor(tr, tg, tb, 1)
        if frame.LevelFS then
            frame.LevelFS:SetTextColor(tr, tg, tb, 1)
        end
    end
end

local function BarWidth(want, fill)
    fill = fill or 20
    local w = tonumber(want) or 0
    if w <= 0 then
        return fill
    end
    if w < 20 then
        w = 20
    end
    if w > fill then
        w = fill
    end
    return w
end

local function BarAlign(v)
    v = string.upper(tostring(v or "LEFT"))
    if v == "RIGHT" or v == "CENTER" then
        return v
    end
    return "LEFT"
end

local function ShowCur(mode)
    return mode == "both" or mode == "current"
end

local function ShowPct(mode)
    return mode == "both" or mode == "percent"
end

local function LevelTextOf(unit)
    local lvl
    if UnitEffectiveLevel then
        lvl = UnitEffectiveLevel(unit)
    elseif UnitLevel then
        lvl = UnitLevel(unit)
    end
    if UF.Compat and UF.Compat.CanUseNumber and not UF.Compat.CanUseNumber(lvl) then
        return ""
    end
    if type(lvl) ~= "number" then
        return ""
    end
    if lvl < 0 then
        return "??"
    end
    if lvl <= 0 then
        return ""
    end
    return tostring(math.floor(lvl + 0.5))
end

local function Font(fs, size, r, g, b)
    local ok = fs:SetFont(UF.Theme.FontPath(), size, "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlightSmall)
    end
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
end

local function UnitOpts(frame)
    local p = UF.DB.Get()
    local cfg = p.frames and p.frames[frame.saveId or frame.id]
    if type(cfg) ~= "table" then
        cfg = {}
    end
    return p, cfg
end

local function StatusWords(unit)
    if UnitIsDead and UnitIsDead(unit) then
        return "Dead"
    end
    if UnitIsGhost and UnitIsGhost(unit) then
        return "Ghost"
    end
    if UnitIsConnected and not UnitIsConnected(unit) then
        return "Offline"
    end
    return nil
end

function Factory.HealthInfo(unit)
    if UF.Compat and UF.Compat.Health then
        return UF.Compat.Health(unit)
    end
    local cur = UnitHealth and UnitHealth(unit) or 0
    local max = UnitHealthMax and UnitHealthMax(unit) or 0
    if type(cur) ~= "number" then
        cur = 0
    end
    if type(max) ~= "number" then
        max = 0
    end
    local pct = 0
    if max > 0 then
        pct = cur / max
        if pct < 0 then
            pct = 0
        end
        if pct > 1 then
            pct = 1
        end
    end
    return cur, max, pct, false, false
end

function Factory.Update(frame)
    if not frame or not frame.unit then
        return
    end
    local unit = frame.unit
    if UnitExists and not UnitExists(unit) then
        if frame.NameFS then
            frame.NameFS:SetText(frame.label or unit)
        end
        if frame.HealthText then
            frame.HealthText:SetText("")
        end
        if frame.HealthPct then
            frame.HealthPct:SetText("")
        end
        if frame.PowerText then
            frame.PowerText:SetText("")
        end
        if frame.PowerPct then
            frame.PowerPct:SetText("")
        end
        if frame.AltPowerText then
            frame.AltPowerText:SetText("")
        end
        if frame.AltPowerPct then
            frame.AltPowerPct:SetText("")
        end
        if frame.LevelFS then
            frame.LevelFS:SetText("")
        end
        Factory.UpdatePips(frame, nil)
        return
    end

    local name = (UF.Compat and UF.Compat.UnitNameOf and UF.Compat.UnitNameOf(unit)) or unit
    local status = StatusWords(unit)
    local cr, cg, cb = UF.Theme.ClassColor(unit)
    local profile, ucfg = UnitOpts(frame)
    local blizzardHealth = HealthColorMode(profile, ucfg) == "blizzard"

    if frame.NameFS then
        if status then
            frame.NameFS:SetText(name .. "  " .. status)
        else
            frame.NameFS:SetText(name)
        end
    end
    if frame.LevelFS then
        if ucfg.showLevel ~= false then
            frame.LevelFS:SetText(LevelTextOf(unit))
        else
            frame.LevelFS:SetText("")
        end
    end
    PaintNameBar(frame, ucfg, unit)

    local cur, maxh, pct, unknown, secret = Factory.HealthInfo(unit)
    if frame.Health then
        if UF.Compat and UF.Compat.ApplyBar then
            UF.Compat.ApplyBar(frame.Health, cur, maxh, pct)
        else
            frame.Health:SetMinMaxValues(0, 1)
            pcall(frame.Health.SetValue, frame.Health, pct or 0)
        end
        if status == "Dead" or status == "Ghost" then
            frame.Health:SetStatusBarColor(0.35, 0.35, 0.35, 1)
        elseif blizzardHealth then
            local usablePct = UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(pct)
            if usablePct and pct <= 0.35 then
                frame.Health:SetStatusBarColor(UF.Theme.healthLow[1], UF.Theme.healthLow[2], UF.Theme.healthLow[3], 1)
            else
                frame.Health:SetStatusBarColor(UF.Theme.health[1], UF.Theme.health[2], UF.Theme.health[3], 1)
            end
        else
            frame.Health:SetStatusBarColor(cr, cg, cb, 1)
        end
    end
    local hmode = ucfg.healthText or profile.healthText or "both"
    if (frame:GetWidth() or 200) < 90 and hmode == "both" then
        hmode = "percent"
    end
    if frame.HealthText then
        if status then
            frame.HealthText:SetText(status)
        elseif not ShowCur(hmode) then
            frame.HealthText:SetText("")
        elseif UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(cur) and UF.Compat.CanUseNumber(maxh) then
            frame.HealthText:SetText(UF.Power.Format(cur, maxh, "current", unknown, false))
        else
            frame.HealthText:SetText("")
        end
    end
    if frame.HealthPct then
        if status or not ShowPct(hmode) then
            frame.HealthPct:SetText("")
        elseif UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(pct) then
            frame.HealthPct:SetText(string.format("%d%%", math.floor(pct * 100 + 0.5)))
        else
            local textPct = UF.Compat and UF.Compat.HealthPercentText and UF.Compat.HealthPercentText(unit)
            if not (UF.Compat and UF.Compat.ApplyPercentText and UF.Compat.ApplyPercentText(frame.HealthPct, textPct or pct, "%%")) then
                frame.HealthPct:SetText("")
            end
        end
    end

    local primary = UF.Power.Primary(unit)
    if frame.Power then
        local pmax = primary.max
        local pcur = primary.cur
        local ppct = primary.pct
        if UF.Compat and UF.Compat.ApplyBar then
            UF.Compat.ApplyBar(frame.Power, pcur, pmax, ppct)
        elseif UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(pmax) and pmax > 0 then
            frame.Power:SetMinMaxValues(0, pmax)
            pcall(frame.Power.SetValue, frame.Power, pcur or 0)
        else
            frame.Power:SetMinMaxValues(0, 1)
            pcall(frame.Power.SetValue, frame.Power, ppct or 0)
        end
        frame.Power:SetStatusBarColor(primary.r, primary.g, primary.b, 1)
        local pmode = ucfg.powerText or profile.powerText or "both"
        if (frame:GetWidth() or 200) < 90 and pmode == "both" then
            pmode = "current"
        end
        local usableMax = UF.Compat and UF.Compat.IsUsablePositive and UF.Compat.IsUsablePositive(pmax)
        if frame.PowerText then
            if status or not ShowCur(pmode) then
                frame.PowerText:SetText("")
            elseif usableMax and UF.Compat.CanUseNumber(pcur) then
                frame.PowerText:SetText(UF.Power.Format(pcur, pmax, "current", false))
            else
                frame.PowerText:SetText("")
            end
        end
        if frame.PowerPct then
            if status or not ShowPct(pmode) then
                frame.PowerPct:SetText("")
            elseif usableMax and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(ppct) then
                frame.PowerPct:SetText(string.format("%d%%", math.floor(ppct * 100 + 0.5)))
            else
                local textPct = UF.Compat and UF.Compat.PowerPercentText and UF.Compat.PowerPercentText(unit, primary.id)
                if not (UF.Compat and UF.Compat.ApplyPercentText and UF.Compat.ApplyPercentText(frame.PowerPct, textPct or ppct, "%%")) then
                    frame.PowerPct:SetText("")
                end
            end
        end
    end

    local altPowerOn = ucfg.showAltPower
    if altPowerOn == nil then
        altPowerOn = profile.showAltPower ~= false
    end
    local alt = UF.Power.Secondary(unit)
    local usableAltMax = alt and UF.Compat and UF.Compat.IsUsablePositive and UF.Compat.IsUsablePositive(alt.max)
    local secretAltMax = alt and alt.max ~= nil and UF.Compat and UF.Compat.IsSecretValue and UF.Compat.IsSecretValue(alt.max)
    local wantAlt = altPowerOn and alt ~= nil and (usableAltMax or secretAltMax or (alt.max ~= nil and not (UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(alt.max))))
    local usableAltCur = alt and UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(alt.cur)
    local usePips = wantAlt and usableAltMax and usableAltCur and (alt.discrete or (UF.Power.IsPipToken and UF.Power.IsPipToken(alt.token)))
    local pipCount = 0
    if usePips then
        pipCount = math.min(10, math.floor(alt.max + 0.5))
    end
    if frame._altShown ~= wantAlt or frame._usePips ~= usePips or frame._pipCount ~= pipCount then
        frame._altShown = wantAlt
        frame._usePips = usePips
        frame._pipCount = pipCount
        LayoutVisual(frame)
    end
    if frame.AltPower then
        if wantAlt and not usePips then
            if UF.Compat and UF.Compat.ApplyBar then
                UF.Compat.ApplyBar(frame.AltPower, alt.cur, alt.max, alt.pct)
            else
                pcall(frame.AltPower.SetMinMaxValues, frame.AltPower, 0, alt.max)
                pcall(frame.AltPower.SetValue, frame.AltPower, alt.cur)
            end
            frame.AltPower:SetStatusBarColor(alt.r, alt.g, alt.b, 1)
            local amode = ucfg.powerText or profile.powerText or "both"
            if frame.AltPowerText then
                if ShowCur(amode) and UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(alt.cur) and UF.Compat.CanUseNumber(alt.max) then
                    frame.AltPowerText:SetText(UF.Power.Format(alt.cur, alt.max, "current", false))
                else
                    frame.AltPowerText:SetText("")
                end
            end
            if frame.AltPowerPct then
                if ShowPct(amode) and UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(alt.pct) then
                    frame.AltPowerPct:SetText(string.format("%d%%", math.floor(alt.pct * 100 + 0.5)))
                else
                    frame.AltPowerPct:SetText("")
                end
            end
        else
            if frame.AltPowerText then
                frame.AltPowerText:SetText("")
            end
            if frame.AltPowerPct then
                frame.AltPowerPct:SetText("")
            end
        end
    end
    if frame.Pips then
        Factory.UpdatePips(frame, usePips and alt or nil)
    end

    Factory.ApplyPortrait(frame, unit)
    if UF.Extras and UF.Extras.UpdateHeals then
        UF.Extras.UpdateHeals(frame)
    end

    if frame.unit == "player" and profile.speech and profile.speech.healthLow and not status then
        local _, _, hpct = Factory.HealthInfo("player")
        if UF.Compat and UF.Compat.CanUseNumber and UF.Compat.CanUseNumber(hpct) and hpct > 0 and hpct <= 0.35 then
            if not frame._lowAnnounced then
                frame._lowAnnounced = true
                if not (AccessibilityHelper and AccessibilityHelper.DB and AccessibilityHelper.DB.Get
                    and AccessibilityHelper.DB.Get().stateHealthLow ~= false) then
                    UF.Speech.Say("Health " .. math.floor(hpct * 100 + 0.5) .. " percent.")
                end
            end
        else
            frame._lowAnnounced = false
        end
    end
end

function Factory.UpdatePips(frame, alt)
    if not frame or not frame.Pips then
        return
    end
    if not alt or not frame._usePips then
        for i = 1, 10 do
            if frame.Pips[i] then
                frame.Pips[i]:Hide()
            end
        end
        return
    end
    local cur = math.floor((alt.cur or 0) + 0.5)
    local max = frame._pipCount or 0
    for i = 1, 10 do
        local pip = frame.Pips[i]
        if pip and i <= max then
            pip:Show()
            if i <= cur then
                pip:SetColorTexture(alt.r or 1, alt.g or 0.85, alt.b or 0.2, 1)
            else
                pip:SetColorTexture(0.12, 0.12, 0.12, 1)
            end
        elseif pip then
            pip:Hide()
        end
    end
end

function Factory.ApplyPortrait(frame, unit)
    if not frame then
        return
    end
    local profile = UF.DB.Get()
    local cfg = profile.frames and profile.frames[frame.saveId or frame.id]
    local mode = PortraitMode(cfg, profile)
    if frame.Portrait3D then
        frame.Portrait3D:Hide()
    end
    if frame.Portrait then
        frame.Portrait:Hide()
    end
    if mode == "hidden" then
        return
    end
    if mode == "3d" and frame.Portrait3D and unit and UnitExists and UnitExists(unit) then
        local ok = pcall(function()
            frame.Portrait3D:Show()
            if frame.Portrait3D.ClearModel then
                frame.Portrait3D:ClearModel()
            end
            if frame.Portrait3D.SetUnit then
                frame.Portrait3D:SetUnit(unit)
            end
            if frame.Portrait3D.SetPortraitZoom then
                frame.Portrait3D:SetPortraitZoom(1)
            end
            if frame.Portrait3D.SetCamDistanceScale then
                frame.Portrait3D:SetCamDistanceScale(1)
            end
            if frame.Portrait3D.SetRotation then
                frame.Portrait3D:SetRotation(0)
            end
        end)
        if ok then
            return
        end
        frame.Portrait3D:Hide()
        mode = "2d"
    end
    if not frame.Portrait then
        return
    end
    frame.Portrait:Show()
    if mode == "class" then
        local _, class = UnitClass(unit)
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if coords then
            frame.Portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            frame.Portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            return
        end
    end
    frame.Portrait:SetTexCoord(0, 1, 0, 1)
    if SetPortraitTexture then
        SetPortraitTexture(frame.Portrait, unit)
    end
end

local function PlaceHBar(bar, left, top, height, wantW, fillW, align)
    if not bar then
        return
    end
    if bar.SetStatusBarTexture then
        PrepBar(bar)
    end
    local parent = bar:GetParent()
    fillW = fillW or ((parent:GetWidth() or 200) - left - 3)
    if fillW < 20 then
        fillW = 20
    end
    local width = BarWidth(wantW, fillW)
    local x = left
    align = BarAlign(align)
    if align == "RIGHT" then
        x = left + (fillW - width)
    elseif align == "CENTER" then
        x = left + math.floor((fillW - width) * 0.5)
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -top)
    bar:SetSize(width, height)
end

function Factory.Measure(cfg, flags)
    cfg = cfg or {}
    flags = flags or {}
    local pad = 3
    local gap = 1
    local powerOn = flags.powerOn
    if powerOn == nil then
        powerOn = cfg.showPower ~= false
    end
    local powerH = 0
    if powerOn then
        powerH = tonumber(cfg.powerBarH) or 14
        if powerH < 4 then
            powerH = 4
        end
        if powerH > 48 then
            powerH = 48
        end
    end
    local altH = 0
    if flags.usePips then
        altH = math.max(10, math.min(18, powerH > 0 and powerH or 12))
    elseif flags.altShown then
        altH = powerH > 0 and powerH or 14
    end
    local nameH = NameStripH(cfg)
    local reserved = pad + (nameH > 0 and (nameH + gap) or 0) + (powerH > 0 and (powerH + gap) or 0) + (altH > 0 and (altH + gap) or 0) + pad
    local frameH = tonumber(cfg.h) or 56
    local wantHealth = tonumber(cfg.healthBarH)
    local healthH = frameH - reserved
    if not flags.lockHeight then
        if flags.fitFromBars and wantHealth then
            healthH = wantHealth
            frameH = reserved + healthH
        elseif wantHealth and wantHealth > healthH then
            healthH = wantHealth
            frameH = reserved + healthH
        end
    end
    if healthH < 12 then
        healthH = 12
        if not flags.lockHeight then
            frameH = reserved + healthH
        end
    end
    return cfg.w or 220, frameH, healthH, powerH, altH, pad, gap, nameH
end

function Factory.FitHeight(cfg, flags)
    local opts = {}
    flags = flags or {}
    for k, v in pairs(flags) do
        opts[k] = v
    end
    opts.fitFromBars = true
    opts.lockHeight = nil
    return Factory.Measure(cfg, opts)
end

function LayoutVisual(frame)
    local profile = UF.DB.Get()
    local cfg = profile.frames and profile.frames[frame.saveId or frame.id]
    if type(cfg) ~= "table" then
        cfg = {}
    end
    local powerOn = cfg.showPower
    if powerOn == nil then
        powerOn = profile.showPower ~= false
    end
    local w, h, healthH, powerH, altH, pad, gap, nameH = Factory.Measure(cfg, {
        powerOn = powerOn,
        altShown = frame._altShown and not frame._usePips,
        usePips = frame._usePips,
        lockHeight = true,
    })
    if not (UF.Compat and UF.Compat.InCombat and UF.Compat.InCombat()) then
        frame:SetSize(w, tonumber(cfg.h) or h)
        frame.cfgH = tonumber(cfg.h) or h
        h = frame.cfgH
    else
        h = frame.cfgH or frame:GetHeight() or h
    end
    local portraitMode = PortraitMode(cfg, profile)
    local portraitOn = portraitMode ~= "hidden"
    local side = (cfg.portraitSide == "right") and "RIGHT" or "LEFT"
    local left = pad
    local right = pad
    local ph = math.max(18, h - 6)
    if portraitOn then
        if side == "RIGHT" then
            right = pad + ph + 3
        else
            left = pad + ph + 3
        end
        local function PlacePortrait(tex)
            if not tex then
                return
            end
            tex:ClearAllPoints()
            tex:SetSize(ph, ph)
            if side == "RIGHT" then
                tex:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
            else
                tex:SetPoint("LEFT", frame, "LEFT", pad, 0)
            end
        end
        PlacePortrait(frame.Portrait)
        PlacePortrait(frame.Portrait3D)
    end
    local compact = h < 40
    local textSize = ((w or 200) < 110 or compact) and 10 or 12
    local textPos = cfg.textPos or {}
    local namePlace = NamePlace(cfg)
    local overlayH = tonumber(cfg.nameBarH) or 16
    if overlayH < 10 then
        overlayH = 10
    end
    if overlayH > 32 then
        overlayH = 32
    end
    local fillW = (frame:GetWidth() or w or 200) - left - right
    if fillW < 20 then
        fillW = 20
    end
    local barStyle = StyleId(cfg)
    SkinBar(frame.Health, barStyle, "health")
    SkinBar(frame.Power, barStyle, "power")
    SkinBar(frame.AltPower, barStyle, "power")
    if UF.Extras and UF.Extras.Skin then
        UF.Extras.Skin(frame, barStyle)
    end
    local top = pad
    if namePlace == "top" and frame.NameBar and nameH > 0 then
        PlaceHBar(frame.NameBar, left, top, nameH, cfg.nameBarW, fillW, cfg.nameBarAlign)
        top = top + nameH + gap
    end
    if frame.Health then
        frame.Health:Show()
        PlaceHBar(frame.Health, left, top, healthH, cfg.healthBarW, fillW, cfg.healthBarAlign)
        top = top + healthH + gap
    end
    if namePlace == "bottom" and frame.NameBar and nameH > 0 then
        PlaceHBar(frame.NameBar, left, top, nameH, cfg.nameBarW, fillW, cfg.nameBarAlign)
        top = top + nameH + gap
    end
    if frame.NameBar then
        if namePlace == "hidden" then
            frame.NameBar:Hide()
        elseif namePlace == "overlay" and frame.Health then
            local hw = frame.Health:GetWidth() or fillW
            local nw = BarWidth(cfg.nameBarW, hw)
            local nx = 0
            local nAlign = BarAlign(cfg.nameBarAlign)
            if nAlign == "RIGHT" then
                nx = hw - nw
            elseif nAlign == "CENTER" then
                nx = math.floor((hw - nw) * 0.5)
            end
            frame.NameBar:Show()
            frame.NameBar:ClearAllPoints()
            frame.NameBar:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", nx, 0)
            frame.NameBar:SetSize(nw, overlayH)
            if frame.NameBar.SetFrameLevel and frame.Health.GetFrameLevel then
                frame.NameBar:SetFrameLevel(frame.Health:GetFrameLevel() + 2)
            end
        else
            frame.NameBar:Show()
        end
    end
    local host = frame.NameBar or frame.Health
    local nameSize = compact and 10 or 12
    local tr, tg, tb = PickColor(cfg.nameText or "white", frame.unit, "text")
    if frame.NameFS then
        Font(frame.NameFS, nameSize, tr, tg, tb)
        frame.NameFS:ClearAllPoints()
        if namePlace == "hidden" then
            frame.NameFS:Hide()
        elseif host then
            frame.NameFS:Show()
            if UF.Pos and UF.Pos.ApplyText then
                UF.Pos.ApplyText(frame.NameFS, host, textPos.name or "LEFT")
            end
        end
    end
    if frame.LevelFS then
        Font(frame.LevelFS, nameSize, tr, tg, tb)
        frame.LevelFS:ClearAllPoints()
        if namePlace == "hidden" or cfg.showLevel == false then
            frame.LevelFS:Hide()
        elseif host then
            frame.LevelFS:Show()
            if UF.Pos and UF.Pos.ApplyText then
                UF.Pos.ApplyText(frame.LevelFS, host, textPos.level or "RIGHT")
            end
        end
    end
    PaintNameBar(frame, cfg, frame.unit)
    if frame.Power then
        if powerOn and powerH > 0 then
            frame.Power:Show()
            PlaceHBar(frame.Power, left, top, powerH, cfg.powerBarW, fillW, cfg.powerBarAlign)
            top = top + powerH + gap
        else
            frame.Power:Hide()
        end
    end
    if frame.AltPower then
        if frame._altShown and not frame._usePips and altH > 0 then
            frame.AltPower:Show()
            PlaceHBar(frame.AltPower, left, top, altH, cfg.altBarW, fillW, cfg.altBarAlign)
            top = top + altH + gap
        else
            frame.AltPower:Hide()
        end
    end
    if frame.Pips then
        local count = frame._pipCount or 0
        local size = math.max(8, math.min(16, altH > 0 and altH or 12))
        local pgap = 3
        if frame._usePips and count > 0 then
            for i = 1, 10 do
                local pip = frame.Pips[i]
                if pip then
                    if i <= count then
                        pip:ClearAllPoints()
                        pip:SetSize(size, size)
                        pip:SetPoint("TOPLEFT", frame, "TOPLEFT", left + (i - 1) * (size + pgap), -top)
                        pip:Show()
                    else
                        pip:Hide()
                    end
                end
            end
        else
            for i = 1, 10 do
                if frame.Pips[i] then
                    frame.Pips[i]:Hide()
                end
            end
        end
    end
    local small = compact and 9 or 10
    if frame.HealthText then
        Font(frame.HealthText, textSize, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.Health then
            UF.Pos.ApplyText(frame.HealthText, frame.Health, textPos.health or "LEFT")
        end
    end
    if frame.HealthPct then
        Font(frame.HealthPct, textSize, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.Health then
            UF.Pos.ApplyText(frame.HealthPct, frame.Health, textPos.healthPct or "RIGHT")
        end
    end
    if frame.PowerText then
        Font(frame.PowerText, small, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.Power then
            UF.Pos.ApplyText(frame.PowerText, frame.Power, textPos.power or "LEFT")
        end
    end
    if frame.PowerPct then
        Font(frame.PowerPct, small, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.Power then
            UF.Pos.ApplyText(frame.PowerPct, frame.Power, textPos.powerPct or "RIGHT")
        end
    end
    if frame.AltPowerText then
        Font(frame.AltPowerText, small, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.AltPower then
            UF.Pos.ApplyText(frame.AltPowerText, frame.AltPower, textPos.alt or "LEFT")
        end
    end
    if frame.AltPowerPct then
        Font(frame.AltPowerPct, small, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText and frame.AltPower then
            UF.Pos.ApplyText(frame.AltPowerPct, frame.AltPower, textPos.altPct or "RIGHT")
        end
    end
end

local function Paint(frame)
    if UF.Widgets and UF.Widgets.Paint then
        UF.Widgets.Paint(frame, UF.Theme.bg[1], UF.Theme.bg[2], UF.Theme.bg[3], 1, 1, 1, 1)
    end
end

local function SavePos(frame)
    local cfg = UF.DB.Get().frames[frame.saveId]
    if type(cfg) ~= "table" then
        return
    end
    local mover = frame.mover or frame
    local point, _, _, x, y = mover:GetPoint(1)
    cfg.point = point or "CENTER"
    cfg.x = x or 0
    cfg.y = y or 0
    cfg.scale = mover:GetScale() or 1
end

function Factory.SetLocked(frame, locked)
    if not frame then
        return
    end
    if frame.UnlockLabel then
        if locked then
            frame.UnlockLabel:Hide()
        else
            frame.UnlockLabel:Show()
        end
    end
end

function Factory.Create(opts)
    opts = opts or {}
    local parent = opts.parent or UIParent
    local frame = CreateFrame("Button", opts.name, parent, Templates())
    frame:SetSize(opts.w or 190, opts.h or 48)
    frame.cfgH = opts.h or 48
    frame.unit = opts.unit
    frame.id = opts.id
    frame.saveId = opts.saveId or opts.id
    frame.label = opts.label or opts.unit
    frame.mover = opts.mover
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")
    frame:RegisterForDrag("LeftButton")
    frame:SetAttribute("unit", opts.unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    if opts.watch ~= false and RegisterUnitWatch then
        RegisterUnitWatch(frame)
    end
    Paint(frame)

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.Portrait = portrait
    local ok3d, model = pcall(CreateFrame, "PlayerModel", nil, frame)
    if ok3d and model then
        frame.Portrait3D = model
        frame.Portrait3D:Hide()
    end

    local nameTmpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local nameBar = CreateFrame("Frame", nil, frame, nameTmpl)
    nameBar:SetHeight(16)
    frame.NameBar = nameBar
    local nameFS = nameBar:CreateFontString(nil, "OVERLAY")
    Font(nameFS, 12, 1, 1, 1)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    nameFS:SetPoint("LEFT", nameBar, "LEFT", 6, 0)
    frame.NameFS = nameFS
    local levelFS = nameBar:CreateFontString(nil, "OVERLAY")
    Font(levelFS, 12, 1, 1, 1)
    levelFS:SetJustifyH("RIGHT")
    levelFS:SetWordWrap(false)
    levelFS:SetPoint("RIGHT", nameBar, "RIGHT", -6, 0)
    frame.LevelFS = levelFS

    local health = CreateFrame("StatusBar", nil, frame)
    PrepBar(health)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    frame.Health = health

    local healthText = health:CreateFontString(nil, "OVERLAY")
    Font(healthText, 11, 1, 1, 1)
    healthText:SetPoint("LEFT", health, "LEFT", 4, 0)
    frame.HealthText = healthText
    local healthPct = health:CreateFontString(nil, "OVERLAY")
    Font(healthPct, 11, 1, 1, 1)
    healthPct:SetPoint("RIGHT", health, "RIGHT", -4, 0)
    frame.HealthPct = healthPct

    local power = CreateFrame("StatusBar", nil, frame)
    PrepBar(power)
    power:SetMinMaxValues(0, 1)
    power:SetValue(1)
    frame.Power = power

    local powerText = power:CreateFontString(nil, "OVERLAY")
    Font(powerText, 10, 1, 1, 1)
    powerText:SetPoint("LEFT", power, "LEFT", 4, 0)
    frame.PowerText = powerText
    local powerPct = power:CreateFontString(nil, "OVERLAY")
    Font(powerPct, 10, 1, 1, 1)
    powerPct:SetPoint("RIGHT", power, "RIGHT", -4, 0)
    frame.PowerPct = powerPct

    local altPower = CreateFrame("StatusBar", nil, frame)
    PrepBar(altPower)
    altPower:SetMinMaxValues(0, 1)
    altPower:SetValue(0)
    altPower:Hide()
    frame.AltPower = altPower
    frame.Pips = {}
    for i = 1, 10 do
        local pip = frame:CreateTexture(nil, "OVERLAY")
        pip:SetSize(12, 12)
        pip:Hide()
        frame.Pips[i] = pip
    end

    local altText = altPower:CreateFontString(nil, "OVERLAY")
    Font(altText, 10, 1, 1, 1)
    altText:SetPoint("LEFT", altPower, "LEFT", 4, 0)
    frame.AltPowerText = altText
    local altPct = altPower:CreateFontString(nil, "OVERLAY")
    Font(altPct, 10, 1, 1, 1)
    altPct:SetPoint("RIGHT", altPower, "RIGHT", -4, 0)
    frame.AltPowerPct = altPct

    local unlock = frame:CreateFontString(nil, "OVERLAY")
    Font(unlock, 10, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    unlock:SetPoint("TOP", frame, "TOP", 0, 12)
    unlock:SetText(opts.label or opts.unit)
    unlock:Hide()
    frame.UnlockLabel = unlock

    LayoutVisual(frame)

    frame:SetScript("OnDragStart", function(self)
        if UF.DB.Get().locked or UF.Compat.InCombat() then
            if UF.Compat.InCombat() then
                UF.Speech.Say("Frames are locked in combat.")
            end
            return
        end
        local mover = self.mover or self
        mover:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        local mover = self.mover or self
        mover:StopMovingOrSizing()
        SavePos(self)
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        if UF.DB.Get().locked or UF.Compat.InCombat() then
            return
        end
        local mover = self.mover or self
        local scale = mover:GetScale() or 1
        scale = scale + (delta * 0.05)
        if scale < 0.6 then
            scale = 0.6
        end
        if scale > 2 then
            scale = 2
        end
        mover:SetScale(scale)
        SavePos(self)
        UF.Speech.Say(self.label .. " scale " .. string.format("%.2f", scale) .. ".")
    end)
    frame:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            if GameTooltip.SetUnit then
                GameTooltip:SetUnit(self.unit)
            else
                GameTooltip:AddLine(self.label or self.unit)
            end
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local events = {
        "PLAYER_ENTERING_WORLD",
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_POWER_UPDATE",
        "UNIT_POWER_FREQUENT",
        "UNIT_POWER",
        "UNIT_MAXPOWER",
        "UNIT_DISPLAYPOWER",
        "UNIT_COMBO_POINTS",
        "RUNES_UPDATED",
        "UNIT_POWER_BAR_SHOW",
        "UNIT_POWER_BAR_HIDE",
        "UPDATE_SHAPESHIFT_FORM",
        "UNIT_NAME_UPDATE",
        "UNIT_PORTRAIT_UPDATE",
        "UNIT_CONNECTION",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_FOCUS_CHANGED",
        "GROUP_ROSTER_UPDATE",
        "UNIT_HEAL_PREDICTION",
        "UNIT_ABSORB_AMOUNT_CHANGED",
        "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    }
    for i = 1, #events do
        pcall(frame.RegisterEvent, frame, events[i])
    end
    pcall(frame.RegisterEvent, frame, "UNIT_HEALTH_FREQUENT")
    frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "UNIT_COMBO_POINTS" or event == "RUNES_UPDATED" or event == "UPDATE_SHAPESHIFT_FORM" then
            Factory.Update(self)
            return
        end
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE"
            or event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER" or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER" or event == "UNIT_NAME_UPDATE" or event == "UNIT_PORTRAIT_UPDATE"
            or event == "UNIT_CONNECTION" or event == "UNIT_HEALTH_FREQUENT"
            or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE"
            or event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED"
            or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
            if arg1 and arg1 ~= self.unit and arg1 ~= "player" then
                if self.unit ~= "targettarget" and self.unit ~= "focustarget" then
                    return
                end
            end
        end
        Factory.Update(self)
    end)
    if opts.unit == "targettarget" or opts.unit == "focustarget" then
        frame:SetScript("OnUpdate", function(self, elapsed)
            self._tick = (self._tick or 0) + elapsed
            if self._tick >= 0.2 then
                self._tick = 0
                Factory.Update(self)
            end
        end)
    end

    frame.RefreshStyle = function(self)
        LayoutVisual(self)
        Paint(self)
        Factory.Update(self)
        if UF.Auras then
            UF.Auras.Apply(self)
        end
        if UF.Indicators then
            UF.Indicators.Apply(self)
        end
        if UF.Extras then
            UF.Extras.Apply(self)
        end
    end

    if UF.Auras then
        UF.Auras.Attach(frame)
    end
    if UF.Indicators then
        UF.Indicators.Attach(frame)
    end
    if UF.Extras then
        UF.Extras.Attach(frame)
    end

    Factory.Update(frame)
    return frame
end
