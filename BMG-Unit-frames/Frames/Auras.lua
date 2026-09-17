--[[
  BMG Unit Frames — buff / debuff icons
  Adapted from common unit-frame practice (enable, size, count, filter, timers).
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Auras = UF.Auras or {}
local Auras = UF.Auras

local DEBUFF_COLOR = {
    Magic = { 0.20, 0.60, 1.00 },
    Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison = { 0.00, 0.60, 0.00 },
}

local CURE = {
    PRIEST = { Magic = true, Disease = true },
    PALADIN = { Magic = true, Disease = true, Poison = true },
    SHAMAN = { Disease = true, Poison = true },
    DRUID = { Curse = true, Poison = true },
    MAGE = { Curse = true },
    MONK = { Poison = true, Disease = true, Magic = true },
}

local function PlayerCanCure()
    local _, class = UnitClass("player")
    return class and CURE[class] or {}
end

local function UnitOpts(frame)
    local p = UF.DB.Get()
    return p.frames and p.frames[frame.saveId or frame.id] or {}
end

local function AuraCfg(frame, kind)
    local cfg = UnitOpts(frame)
    cfg.auras = cfg.auras or {}
    if type(cfg.auras[kind]) ~= "table" then
        cfg.auras[kind] = { enabled = false, size = 18, max = 8, perRow = 8, growth = "RIGHT", anchor = "BOTTOMLEFT", filter = "all", timers = true, stacks = true }
    end
    return cfg.auras[kind]
end

local function Mine(source)
    return source == "player" or source == "pet" or source == "vehicle"
end

local function Keep(filter, source, dtype, harmful)
    if filter == "mine" then
        return Mine(source)
    end
    if filter == "dispellable" then
        if not harmful or not dtype then
            return false
        end
        return PlayerCanCure()[dtype] == true
    end
    return true
end

local function MakeButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:EnableMouse(true)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.Icon = icon
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 0)
    btn.Border = border
    local count = btn:CreateFontString(nil, "OVERLAY")
    count:SetFont(UF.Theme.FontPath(), 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    count:SetTextColor(1, 1, 1, 1)
    btn.Count = count
    local timer = btn:CreateFontString(nil, "OVERLAY")
    timer:SetFont(UF.Theme.FontPath(), 9, "OUTLINE")
    timer:SetPoint("TOP", 0, 0)
    timer:SetTextColor(1, 1, 0.75, 1)
    btn.Timer = timer
    btn:SetScript("OnEnter", function(self)
        if GameTooltip and self._index then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetUnitAura then
                GameTooltip:SetUnitAura(self._unit, self._index, self._filter)
            elseif self._name then
                GameTooltip:SetText(self._name)
            end
            GameTooltip:Show()
        end
        if UF.Speech and UF.Speech.Say and self._name then
            local msg = self._name
            if self._count and self._count > 1 then
                msg = msg .. ", " .. tostring(self._count) .. " stacks"
            end
            if self._remain and self._remain > 0 then
                msg = msg .. ", " .. tostring(math.floor(self._remain + 0.5)) .. " seconds"
            end
            UF.Speech.Say(msg .. ".")
        end
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return btn
end

local function Holder(frame, kind)
    if not frame._auraHolders then
        frame._auraHolders = {}
    end
    if frame._auraHolders[kind] then
        return frame._auraHolders[kind]
    end
    local h = CreateFrame("Frame", nil, frame)
    h:SetSize(1, 1)
    h.buttons = {}
    frame._auraHolders[kind] = h
    return h
end

local function PlaceIcons(holder, cfg, count)
    local size = cfg.size or 18
    local perRow = cfg.perRow or cfg.max or 8
    if perRow < 1 then
        perRow = 1
    end
    local growth = string.upper(cfg.growth or "RIGHT")
    local xDir = (growth == "LEFT") and -1 or 1
    local yDir = (growth == "UP") and 1 or -1
    local wrapDown = (growth == "LEFT" or growth == "RIGHT")
    for i = 1, count do
        local btn = holder.buttons[i]
        btn:ClearAllPoints()
        btn:SetSize(size, size)
        local col, row
        if wrapDown then
            col = (i - 1) % perRow
            row = math.floor((i - 1) / perRow)
            btn:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (size + 2) * xDir, -row * (size + 2))
        else
            row = (i - 1) % perRow
            col = math.floor((i - 1) / perRow)
            btn:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (size + 2), row * (size + 2) * yDir)
        end
    end
    local rows = math.ceil(count / perRow)
    local cols = math.min(count, perRow)
    if wrapDown then
        holder:SetSize(cols * (size + 2), rows * (size + 2))
    else
        holder:SetSize(rows * (size + 2), cols * (size + 2))
    end
end

local function AnchorHolder(frame, holder, cfg)
    holder:ClearAllPoints()
    local a = string.upper(cfg.anchor or "BOTTOMLEFT")
    if a == "TOPRIGHT" then
        holder:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", 2, 2)
    elseif a == "TOPLEFT" then
        holder:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", -2, 2)
    elseif a == "BOTTOMRIGHT" then
        holder:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", 2, -2)
    elseif a == "CENTER" then
        holder:SetPoint("CENTER", frame, "CENTER", 0, 0)
    else
        holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    end
end

local function Scan(frame, kind, filterToken)
    local cfg = AuraCfg(frame, kind)
    local holder = Holder(frame, kind)
    if not cfg.enabled then
        holder:Hide()
        return
    end
    holder:Show()
    AnchorHolder(frame, holder, cfg)
    local maxn = cfg.max or 8
    local shown = 0
    local index = 1
    while shown < maxn do
        local name, icon, count, dtype, duration, expires, source = UF.Compat.Aura(frame.unit, index, filterToken)
        if not name then
            break
        end
        if Keep(cfg.filter or "all", source, dtype, kind == "debuffs") then
            shown = shown + 1
            local btn = holder.buttons[shown]
            if not btn then
                btn = MakeButton(holder)
                holder.buttons[shown] = btn
            end
            btn:Show()
            btn.Icon:SetTexture(icon)
            btn._name = name
            btn._unit = frame.unit
            btn._index = index
            btn._filter = filterToken
            btn._count = count or 0
            local remain = 0
            if type(expires) == "number" and expires > 0 and GetTime then
                remain = expires - GetTime()
            end
            btn._remain = remain
            if cfg.stacks ~= false and count and count > 1 then
                btn.Count:SetText(tostring(count))
            else
                btn.Count:SetText("")
            end
            if cfg.timers ~= false and remain > 0 then
                if remain >= 60 then
                    btn.Timer:SetText(string.format("%dm", math.floor(remain / 60 + 0.5)))
                else
                    btn.Timer:SetText(tostring(math.floor(remain + 0.5)))
                end
            else
                btn.Timer:SetText("")
            end
            if kind == "debuffs" and dtype and DEBUFF_COLOR[dtype] then
                local c = DEBUFF_COLOR[dtype]
                btn.Border:SetColorTexture(c[1], c[2], c[3], 0.55)
            else
                btn.Border:SetColorTexture(0, 0, 0, 0)
            end
        end
        index = index + 1
        if index > 40 then
            break
        end
    end
    for i = shown + 1, #holder.buttons do
        holder.buttons[i]:Hide()
    end
    if shown > 0 then
        PlaceIcons(holder, cfg, shown)
    else
        holder:SetSize(1, 1)
    end
end

function Auras.Update(frame)
    if not frame or not frame.unit then
        return
    end
    if UnitExists and not UnitExists(frame.unit) then
        local b = frame._auraHolders and frame._auraHolders.buffs
        local d = frame._auraHolders and frame._auraHolders.debuffs
        if b then
            b:Hide()
        end
        if d then
            d:Hide()
        end
        return
    end
    Scan(frame, "buffs", "HELPFUL")
    Scan(frame, "debuffs", "HARMFUL")
end

function Auras.Apply(frame)
    Auras.Update(frame)
end

function Auras.Attach(frame)
    if not frame or frame._aurasAttached then
        return
    end
    frame._aurasAttached = true
    Holder(frame, "buffs")
    Holder(frame, "debuffs")
    pcall(frame.RegisterEvent, frame, "UNIT_AURA")
    local prev = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(self, event, arg1, ...)
        if event == "UNIT_AURA" and (not arg1 or arg1 == self.unit or arg1 == "player") then
            Auras.Update(self)
        end
        if prev then
            prev(self, event, arg1, ...)
        end
    end)
    if frame.unit == "targettarget" or frame.unit == "focustarget" then
        local old = frame:GetScript("OnUpdate")
        frame:SetScript("OnUpdate", function(self, elapsed)
            if old then
                old(self, elapsed)
            end
            self._auraTick = (self._auraTick or 0) + elapsed
            if self._auraTick >= 0.25 then
                self._auraTick = 0
                Auras.Update(self)
            end
        end)
    end
    Auras.Update(frame)
end
