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
    local unknown = false
    if UnitCanAttack and UnitIsFriend then
        local hostile = UnitCanAttack("player", unit) and not UnitIsFriend("player", unit)
        if hostile and max <= 100 and max > 0 then
            unknown = true
        end
    end
    return cur, max, pct, unknown
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
        if frame.PowerText then
            frame.PowerText:SetText("")
        end
        if frame.AltPowerText then
            frame.AltPowerText:SetText("")
        end
        return
    end

    local name = (UnitName and UnitName(unit)) or unit
    local status = StatusWords(unit)
    local cr, cg, cb = UF.Theme.ClassColor(unit)
    local profile, ucfg = UnitOpts(frame)
    local classic = profile.style == "classic"

    if frame.NameFS then
        if classic then
            frame.NameFS:SetTextColor(cr, cg, cb, 1)
        else
            frame.NameFS:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
        end
        if status then
            frame.NameFS:SetText(name .. "  " .. status)
        else
            frame.NameFS:SetText(name)
        end
    end

    local _, _, pct, unknown = Factory.HealthInfo(unit)
    if frame.Health then
        frame.Health:SetMinMaxValues(0, 1)
        frame.Health:SetValue(pct)
        if status == "Dead" or status == "Ghost" then
            frame.Health:SetStatusBarColor(0.35, 0.35, 0.35, 1)
        elseif classic then
            if pct <= 0.35 then
                frame.Health:SetStatusBarColor(UF.Theme.healthLow[1], UF.Theme.healthLow[2], UF.Theme.healthLow[3], 1)
            else
                frame.Health:SetStatusBarColor(UF.Theme.health[1], UF.Theme.health[2], UF.Theme.health[3], 1)
            end
        else
            frame.Health:SetStatusBarColor(cr, cg, cb, 1)
        end
    end
    if frame.HealthText then
        local mode = ucfg.healthText or profile.healthText or "both"
        if (frame:GetWidth() or 200) < 90 and mode == "both" then
            mode = "percent"
        end
        local cur, maxh = Factory.HealthInfo(unit)
        if status then
            frame.HealthText:SetText(status)
        else
            frame.HealthText:SetText(UF.Power.Format(cur, maxh, mode, unknown))
        end
    end

    local primary = UF.Power.Primary(unit)
    if frame.Power then
        local pmax = primary.max or 0
        local pcur = primary.cur or 0
        if pmax > 0 then
            frame.Power:SetMinMaxValues(0, pmax)
            frame.Power:SetValue(pcur)
        else
            frame.Power:SetMinMaxValues(0, 1)
            frame.Power:SetValue(0)
        end
        frame.Power:SetStatusBarColor(primary.r, primary.g, primary.b, 1)
        if frame.PowerText then
            local pmode = ucfg.powerText or profile.powerText or "both"
            if (frame:GetWidth() or 200) < 90 and pmode == "both" then
                pmode = "current"
            end
            if status or pmax <= 0 then
                frame.PowerText:SetText("")
            else
                frame.PowerText:SetText(UF.Power.Format(pcur, pmax, pmode, false))
            end
        end
    end

    local altPowerOn = ucfg.showAltPower
    if altPowerOn == nil then
        altPowerOn = profile.showAltPower ~= false
    end
    local alt = UF.Power.Secondary(unit)
    local wantAlt = altPowerOn and alt ~= nil and type(alt.max) == "number" and alt.max > 0
    if frame._altShown ~= wantAlt then
        frame._altShown = wantAlt
        LayoutVisual(frame)
    end
    if frame.AltPower then
        if wantAlt then
            frame.AltPower:SetMinMaxValues(0, alt.max)
            frame.AltPower:SetValue(alt.cur or 0)
            frame.AltPower:SetStatusBarColor(alt.r, alt.g, alt.b, 1)
            if frame.AltPowerText then
                local amode = ucfg.powerText or profile.powerText or "both"
                if alt.discrete then
                    amode = (amode == "none" and "none") or "both"
                end
                frame.AltPowerText:SetText(UF.Power.Format(alt.cur, alt.max, amode, false))
            end
        elseif frame.AltPowerText then
            frame.AltPowerText:SetText("")
        end
    end

    Factory.ApplyPortrait(frame, unit)
    if UF.Extras and UF.Extras.UpdateHeals then
        UF.Extras.UpdateHeals(frame)
    end

    if frame.unit == "player" and profile.speech and profile.speech.healthLow and not status then
        local _, _, hpct = Factory.HealthInfo("player")
        if hpct > 0 and hpct <= 0.35 then
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

function Factory.ApplyPortrait(frame, unit)
    if not frame or not frame.Portrait then
        return
    end
    local profile = UF.DB.Get()
    local cfg = profile.frames and profile.frames[frame.saveId or frame.id]
    local mode = (cfg and cfg.portrait) or profile.portrait or "portrait"
    if mode == "off" then
        frame.Portrait:Hide()
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

function LayoutVisual(frame)
    local profile = UF.DB.Get()
    local pad = 4
    local left = pad
    local cfg = profile.frames and profile.frames[frame.saveId or frame.id]
    if type(cfg) ~= "table" then
        cfg = {}
    end
    local portraitMode = cfg.portrait or profile.portrait or "portrait"
    local portraitOn = portraitMode ~= "off"
    if portraitOn and frame.Portrait then
        frame.Portrait:Show()
        local ph = math.max(18, (frame.cfgH or 52) - 8)
        frame.Portrait:SetSize(ph, ph)
        frame.Portrait:ClearAllPoints()
        frame.Portrait:SetPoint("LEFT", frame, "LEFT", pad, 0)
        left = pad + ph + 4
    elseif frame.Portrait then
        frame.Portrait:Hide()
    end
    local h = frame.cfgH or frame:GetHeight() or 52
    local powerOn = cfg.showPower
    if powerOn == nil then
        powerOn = profile.showPower ~= false
    end
    local altOn = frame._altShown
    local barH = h < 36 and 5 or 8
    local nameH = h < 36 and 10 or 14
    local bottom = 3
    local textSize = ((frame:GetWidth() or 200) < 100 or h < 36) and 9 or 11
    local textPos = cfg.textPos or {}
    if frame.NameFS then
        Font(frame.NameFS, h < 36 and 10 or 12, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText then
            UF.Pos.ApplyText(frame.NameFS, frame, textPos.name or "TOPLEFT")
        else
            frame.NameFS:ClearAllPoints()
            frame.NameFS:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -2)
            frame.NameFS:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -2)
        end
    end
    if frame.AltPower then
        if altOn then
            frame.AltPower:Show()
            frame.AltPower:ClearAllPoints()
            frame.AltPower:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, bottom)
            frame.AltPower:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, bottom)
            frame.AltPower:SetHeight(barH)
            bottom = bottom + barH + 1
        else
            frame.AltPower:Hide()
        end
    end
    if frame.Power then
        if powerOn then
            frame.Power:Show()
            frame.Power:ClearAllPoints()
            frame.Power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, bottom)
            frame.Power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, bottom)
            frame.Power:SetHeight(barH)
            bottom = bottom + barH + 1
        else
            frame.Power:Hide()
        end
    end
    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(nameH + 2))
        frame.Health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, bottom)
    end
    if frame.HealthText then
        Font(frame.HealthText, textSize, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText then
            UF.Pos.ApplyText(frame.HealthText, frame.Health, textPos.health or "CENTER")
        end
    end
    if frame.PowerText then
        Font(frame.PowerText, textSize > 9 and 10 or 9, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText then
            UF.Pos.ApplyText(frame.PowerText, frame.Power, textPos.power or "CENTER")
        end
    end
    if frame.AltPowerText then
        Font(frame.AltPowerText, textSize > 9 and 10 or 9, 1, 1, 1)
        if UF.Pos and UF.Pos.ApplyText then
            UF.Pos.ApplyText(frame.AltPowerText, frame.AltPower, textPos.power or "CENTER")
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

    local nameFS = frame:CreateFontString(nil, "OVERLAY")
    Font(nameFS, 12, 1, 1, 1)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    frame.NameFS = nameFS

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    frame.Health = health

    local healthText = health:CreateFontString(nil, "OVERLAY")
    Font(healthText, 11, 1, 1, 1)
    healthText:SetPoint("CENTER", health, "CENTER", 0, 0)
    frame.HealthText = healthText

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    power:SetMinMaxValues(0, 1)
    power:SetValue(1)
    frame.Power = power

    local powerText = power:CreateFontString(nil, "OVERLAY")
    Font(powerText, 10, 1, 1, 1)
    powerText:SetPoint("CENTER", power, "CENTER", 0, 0)
    frame.PowerText = powerText

    local altPower = CreateFrame("StatusBar", nil, frame)
    altPower:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    altPower:SetMinMaxValues(0, 1)
    altPower:SetValue(0)
    altPower:Hide()
    frame.AltPower = altPower

    local altText = altPower:CreateFontString(nil, "OVERLAY")
    Font(altText, 10, 1, 1, 1)
    altText:SetPoint("CENTER", altPower, "CENTER", 0, 0)
    frame.AltPowerText = altText

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
            or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" then
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
