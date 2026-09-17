--[[
  BMG Unit Frames — incoming heals, absorbs, highlight, movable cast bar, range
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Extras = UF.Extras or {}
local Ex = UF.Extras

local function ExtraCfg(frame)
    local p = UF.DB.Get()
    local cfg = p.frames and p.frames[frame.saveId or frame.id] or {}
    cfg.extra = cfg.extra or {}
    cfg.extra.cast = cfg.extra.cast or { attach = "BELOW", w = 0, h = 12, point = "CENTER", x = 0, y = 0 }
    return cfg.extra
end

local function OverlaySlice(bar, parent, startPct, endPct)
    if not bar or not parent then
        return
    end
    if endPct <= startPct or endPct <= 0 then
        bar:Hide()
        return
    end
    if startPct < 0 then
        startPct = 0
    end
    if endPct > 1 then
        endPct = 1
    end
    local w = parent:GetWidth() or 1
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", w * startPct, 0)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", w * startPct, 0)
    bar:SetWidth(math.max(1, w * (endPct - startPct)))
    bar:Show()
end

function Ex.UpdateHeals(frame)
    if not frame or not frame.unit then
        return
    end
    local extra = ExtraCfg(frame)
    local exists = not (UnitExists and not UnitExists(frame.unit))
    local cur, maxh = 0, 0
    if exists and UF.Factory and UF.Factory.HealthInfo then
        cur, maxh = UF.Factory.HealthInfo(frame.unit)
    end
    if not (UF.Compat and UF.Compat.IsUsablePositive and UF.Compat.IsUsablePositive(maxh)) then
        if frame.Heal then
            frame.Heal:Hide()
        end
        if frame.Absorb then
            frame.Absorb:Hide()
        end
        if frame.HealAbsorb then
            frame.HealAbsorb:Hide()
        end
        return
    end

    local incoming = 0
    if extra.healPredict ~= false then
        incoming = UF.Compat.IncomingHeals(frame.unit)
    end
    if frame.Heal then
        if incoming > 0 then
            frame.Heal:Show()
            frame.Heal:SetMinMaxValues(0, 1)
            local shown = (cur + incoming) / maxh
            if shown > 1 then
                shown = 1
            end
            frame.Heal:SetValue(shown)
        else
            frame.Heal:Hide()
        end
    end

    local absorbs = 0
    if extra.absorb ~= false then
        absorbs = UF.Compat.Absorbs(frame.unit)
    end
    if frame.Absorb then
        if absorbs > 0 then
            OverlaySlice(frame.Absorb, frame.Health, cur / maxh, (cur + absorbs) / maxh)
        else
            frame.Absorb:Hide()
        end
    end

    local eaten = 0
    if extra.healAbsorb ~= false then
        eaten = UF.Compat.HealAbsorbs(frame.unit)
    end
    if frame.HealAbsorb then
        if eaten > 0 then
            local start = (cur - eaten) / maxh
            OverlaySlice(frame.HealAbsorb, frame.Health, start, cur / maxh)
        else
            frame.HealAbsorb:Hide()
        end
    end
end

function Ex.LayoutCast(frame)
    if not frame or not frame.Cast then
        return
    end
    local extra = ExtraCfg(frame)
    local c = extra.cast
    local h = c.h or 12
    if h < 8 then
        h = 8
    end
    if h > 40 then
        h = 40
    end
    local w = c.w or 0
    local attach = c.attach or "BELOW"
    local bar = frame.Cast
    bar:SetHeight(h)
    bar:ClearAllPoints()
    if extra.castBar == false then
        bar:Hide()
        return
    end
    if attach == "FREE" then
        bar:SetParent(UIParent)
        bar:SetFrameStrata("MEDIUM")
        bar:SetWidth((w > 0 and w) or (frame:GetWidth() or 200))
        bar:SetPoint(c.point or "CENTER", UIParent, c.point or "CENTER", c.x or 0, c.y or 0)
    else
        bar:SetParent(frame)
        if attach == "ABOVE" then
            if w > 0 then
                bar:SetWidth(w)
                bar:SetPoint("BOTTOM", frame, "TOP", 0, 2)
            else
                bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
                bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
            end
        elseif attach == "INSIDE" then
            bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 3)
            bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 3)
        else
            if w > 0 then
                bar:SetWidth(w)
                bar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
            else
                bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
                bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
            end
        end
    end
end

local function SaveCastPos(frame)
    if not frame or not frame.Cast then
        return
    end
    local extra = ExtraCfg(frame)
    extra.cast = extra.cast or {}
    extra.cast.attach = "FREE"
    local point, _, _, x, y = frame.Cast:GetPoint(1)
    extra.cast.point = point or "CENTER"
    extra.cast.x = x or 0
    extra.cast.y = y or 0
    extra.cast.w = math.floor((frame.Cast:GetWidth() or 200) + 0.5)
    extra.cast.h = math.floor((frame.Cast:GetHeight() or 12) + 0.5)
end

function Ex.UpdateCast(frame)
    if not frame or not frame.Cast then
        return
    end
    local extra = ExtraCfg(frame)
    if extra.castBar == false then
        frame.Cast:Hide()
        if frame.CastText then
            frame.CastText:SetText("")
        end
        return
    end
    local name, _, startTime, endTime, _, channel = UF.Compat.CastInfo(frame.unit)
    local locked = UF.DB.Get().locked ~= false
    if not name then
        if not locked then
            frame.Cast:Show()
            frame.Cast:SetMinMaxValues(0, 1)
            frame.Cast:SetValue(0)
            if frame.CastText then
                frame.CastText:SetText("Cast bar")
            end
        else
            frame.Cast:Hide()
            if frame.CastText then
                frame.CastText:SetText("")
            end
        end
        return
    end
    frame.Cast:Show()
    startTime = (startTime or 0) / 1000
    endTime = (endTime or 0) / 1000
    local duration = endTime - startTime
    if duration <= 0 then
        duration = 1
    end
    local now = GetTime and GetTime() or startTime
    local progress = now - startTime
    if channel then
        progress = endTime - now
    end
    frame.Cast:SetMinMaxValues(0, duration)
    frame.Cast:SetValue(progress)
    if frame.CastText then
        frame.CastText:SetText(name)
    end
end

function Ex.UpdateRange(frame)
    if not frame then
        return
    end
    local extra = ExtraCfg(frame)
    if extra.rangeFade == false then
        frame:SetAlpha(1)
        return
    end
    if not frame.unit or (UnitExists and not UnitExists(frame.unit)) then
        frame:SetAlpha(1)
        return
    end
    if UF.Compat.InRange(frame.unit) then
        frame:SetAlpha(1)
    else
        frame:SetAlpha(0.45)
    end
end

function Ex.UpdateHighlight(frame)
    if not frame or not frame._hl then
        return
    end
    local extra = ExtraCfg(frame)
    local r, g, b, show = 1, 0.92, 0.4, false
    if extra.aggro ~= false and frame.unit and UF.Compat.Threat(frame.unit) >= 2 then
        r, g, b = 0.95, 0.18, 0.18
        show = true
    elseif extra.mouseover ~= false and frame._hlHover then
        r, g, b = 1, 0.92, 0.45
        show = true
    end
    local hl = frame._hl
    if show then
        hl.top:SetColorTexture(r, g, b, 0.9)
        hl.bottom:SetColorTexture(r, g, b, 0.9)
        hl.left:SetColorTexture(r, g, b, 0.9)
        hl.right:SetColorTexture(r, g, b, 0.9)
        hl:Show()
    else
        hl:Hide()
    end
end

function Ex.Skin(frame, style)
    if not frame then
        return
    end
    if not style then
        local p = UF.DB.Get()
        local cfg = p.frames and p.frames[frame.saveId or frame.id]
        style = UF.Factory and UF.Factory.StyleId and UF.Factory.StyleId(cfg) or "blizzard"
    end
    if not (UF.Factory and UF.Factory.SkinBar) then
        return
    end
    if frame.Heal then
        UF.Factory.SkinBar(frame.Heal, style, "health", true)
        frame.Heal:SetStatusBarColor(0.15, 0.70, 0.35, 0.55)
    end
    if frame.Absorb then
        UF.Factory.SkinBar(frame.Absorb, style, "health", true)
        frame.Absorb:SetStatusBarColor(0.95, 0.86, 0.30, 0.85)
    end
    if frame.HealAbsorb then
        UF.Factory.SkinBar(frame.HealAbsorb, style, "health", true)
        frame.HealAbsorb:SetStatusBarColor(0.62, 0.28, 0.85, 0.80)
    end
    if frame.Cast then
        UF.Factory.SkinBar(frame.Cast, style, "health")
        frame.Cast:SetStatusBarColor(1.0, 0.72, 0.28, 1)
    end
end

function Ex.Update(frame)
    Ex.Skin(frame)
    Ex.LayoutCast(frame)
    Ex.UpdateHeals(frame)
    Ex.UpdateCast(frame)
    Ex.UpdateRange(frame)
    Ex.UpdateHighlight(frame)
end

function Ex.Apply(frame)
    Ex.Update(frame)
end

function Ex.Attach(frame)
    if not frame or frame._extrasAttached then
        return
    end
    frame._extrasAttached = true

    if frame.Health then
        local function Overlay(color)
            local bar = CreateFrame("StatusBar", nil, frame.Health)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
            bar:SetFrameLevel((frame.Health:GetFrameLevel() or 1) + 1)
            bar:Hide()
            return bar
        end
        local heal = CreateFrame("StatusBar", nil, frame.Health)
        heal:SetAllPoints()
        heal:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        heal:SetStatusBarColor(0.15, 0.70, 0.35, 0.55)
        local hlvl = (frame.Health:GetFrameLevel() or 2) - 1
        if hlvl < 1 then
            hlvl = 1
            frame.Health:SetFrameLevel(2)
        end
        heal:SetFrameLevel(hlvl)
        heal:Hide()
        frame.Heal = heal
        frame.Absorb = Overlay({ 0.95, 0.86, 0.30, 0.85 })
        frame.HealAbsorb = Overlay({ 0.62, 0.28, 0.85, 0.80 })
    end

    local cast = CreateFrame("StatusBar", nil, frame)
    cast:SetHeight(12)
    cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    cast:SetStatusBarColor(1.0, 0.72, 0.28, 1)
    cast:SetMovable(true)
    cast:SetClampedToScreen(true)
    cast:EnableMouse(true)
    cast:RegisterForDrag("LeftButton")
    cast:EnableMouseWheel(true)
    if UF.Widgets and UF.Widgets.Paint then
        UF.Widgets.Paint(cast, 0.05, 0.05, 0.05, 0.9, 0.4, 0.4, 0.4)
    end
    cast:Hide()
    frame.Cast = cast
    local ct = cast:CreateFontString(nil, "OVERLAY")
    ct:SetFont(UF.Theme.FontPath(), 10, "OUTLINE")
    ct:SetPoint("CENTER")
    ct:SetTextColor(1, 1, 1, 1)
    frame.CastText = ct
    cast:SetScript("OnDragStart", function(self)
        if UF.DB.Get().locked or UF.Compat.InCombat() then
            if UF.Speech then
                UF.Speech.Say("Unlock frames to move the cast bar.")
            end
            return
        end
        ExtraCfg(frame).cast.attach = "FREE"
        self:StartMoving()
    end)
    cast:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveCastPos(frame)
        if UF.Speech then
            UF.Speech.Say("Cast bar moved.")
        end
    end)
    cast:SetScript("OnMouseWheel", function(self, delta)
        if UF.DB.Get().locked or UF.Compat.InCombat() then
            return
        end
        local extra = ExtraCfg(frame)
        extra.cast.h = (extra.cast.h or 12) + (delta * 1)
        if extra.cast.h < 8 then
            extra.cast.h = 8
        end
        if extra.cast.h > 40 then
            extra.cast.h = 40
        end
        extra.cast.w = math.floor((self:GetWidth() or 200) + 0.5)
        Ex.LayoutCast(frame)
        if UF.Speech then
            UF.Speech.Say("Cast bar height " .. tostring(extra.cast.h) .. ".")
        end
    end)

    local hl = CreateFrame("Frame", nil, frame)
    hl:SetAllPoints()
    hl:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
    local function Edge(rel1, rel2, vertical)
        local t = hl:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.92, 0.4, 0.9)
        t:SetPoint(rel1, frame, rel1, 0, 0)
        t:SetPoint(rel2, frame, rel2, 0, 0)
        if vertical then
            t:SetWidth(2)
        else
            t:SetHeight(2)
        end
        return t
    end
    hl.top = Edge("TOPLEFT", "TOPRIGHT", false)
    hl.bottom = Edge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    hl.left = Edge("TOPLEFT", "BOTTOMLEFT", true)
    hl.right = Edge("TOPRIGHT", "BOTTOMRIGHT", true)
    hl:Hide()
    frame._hl = hl

    local oldEnter = frame:GetScript("OnEnter")
    local oldLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function(self)
        self._hlHover = true
        Ex.UpdateHighlight(self)
        if oldEnter then
            oldEnter(self)
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self._hlHover = false
        Ex.UpdateHighlight(self)
        if oldLeave then
            oldLeave(self)
        end
    end)

    local events = {
        "UNIT_HEAL_PREDICTION",
        "UNIT_ABSORB_AMOUNT_CHANGED",
        "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
        "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
    }
    for i = 1, #events do
        pcall(frame.RegisterEvent, frame, events[i])
    end
    local prev = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(self, event, ...)
        if prev then
            prev(self, event, ...)
        end
        if string.sub(event, 1, 12) == "UNIT_SPELLCAST" then
            Ex.UpdateCast(self)
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
            Ex.UpdateHighlight(self)
        else
            Ex.UpdateHeals(self)
        end
    end)
    local old = frame:GetScript("OnUpdate")
    frame:SetScript("OnUpdate", function(self, elapsed)
        if old then
            old(self, elapsed)
        end
        self._exTick = (self._exTick or 0) + elapsed
        if self._exTick >= 0.1 then
            self._exTick = 0
            if self.Cast and self.Cast:IsShown() then
                Ex.UpdateCast(self)
            end
            self._rangeTick = (self._rangeTick or 0) + 0.1
            if self._rangeTick >= 0.4 then
                self._rangeTick = 0
                Ex.UpdateRange(self)
                Ex.UpdateHeals(self)
                Ex.UpdateHighlight(self)
            end
        end
    end)
    Ex.LayoutCast(frame)
    Ex.Update(frame)
end
