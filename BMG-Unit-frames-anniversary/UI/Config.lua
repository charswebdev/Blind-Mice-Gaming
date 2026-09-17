--[[
  BMG Unit Frames — per-unit settings with General / Auras / Indicators / More
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Config = UF.Config or {}
local Config = UF.Config

local FRAME_NAME = "BMGUnitFramesConfig"

local UNITS = {
    { id = "player", label = "Player" },
    { id = "pet", label = "Pet" },
    { id = "target", label = "Target" },
    { id = "tot", label = "Target of target" },
    { id = "focus", label = "Focus" },
    { id = "party", label = "Party" },
    { id = "raid", label = "Raid" },
    { id = "arena", label = "Arena" },
}

local TEXT_OPTS = {
    { id = "both", label = "Number and percent" },
    { id = "percent", label = "Percent" },
    { id = "current", label = "Number" },
    { id = "none", label = "Hidden" },
}

local ON_OFF = {
    { id = "on", label = "On" },
    { id = "off", label = "Off" },
}

local FILTER_OPTS = {
    { id = "all", label = "All" },
    { id = "mine", label = "Mine only" },
    { id = "dispellable", label = "Dispellable" },
}

local ANCHOR_OPTS = {
    { id = "BOTTOMLEFT", label = "Below left" },
    { id = "BOTTOMRIGHT", label = "Below right" },
    { id = "TOPLEFT", label = "Above left" },
    { id = "TOPRIGHT", label = "Above right" },
    { id = "CENTER", label = "Center" },
}

local GROWTH_OPTS = {
    { id = "RIGHT", label = "Right" },
    { id = "LEFT", label = "Left" },
    { id = "DOWN", label = "Down" },
    { id = "UP", label = "Up" },
}

local frame
local selected = "player"
local currentTab = "general"
local RelayoutGeneral

local function Speak(text)
    if UF.Speech and UF.Speech.Say then
        UF.Speech.Say(text)
    end
end

local function CloseMenus()
    if UF.Widgets and UF.Widgets.CloseDropdowns then
        UF.Widgets.CloseDropdowns()
    end
end

local function Profile()
    return UF.DB.Get()
end

local function UnitTitle()
    for i = 1, #UNITS do
        if UNITS[i].id == selected then
            return UNITS[i].label
        end
    end
    return selected
end

local function UnitCfg()
    local p = Profile()
    p.frames = p.frames or {}
    if type(p.frames[selected]) ~= "table" then
        p.frames[selected] = UF.DB.DefaultFrame and UF.DB.DefaultFrame(selected, {}) or {}
    end
    if UF.DB.DefaultUnitExtras then
        local extras = UF.DB.DefaultUnitExtras(selected)
        local Merge
        Merge = function(dst, src)
            if type(dst) ~= "table" or type(src) ~= "table" then
                return dst
            end
            for k, v in pairs(src) do
                if type(v) == "table" then
                    if type(dst[k]) ~= "table" then
                        dst[k] = {}
                    end
                    Merge(dst[k], v)
                elseif dst[k] == nil then
                    dst[k] = v
                end
            end
            return dst
        end
        Merge(p.frames[selected], extras)
    end
    return p.frames[selected]
end

local function AuraKind(kind)
    local cfg = UnitCfg()
    cfg.auras = cfg.auras or {}
    if type(cfg.auras[kind]) ~= "table" then
        cfg.auras[kind] = {}
    end
    return cfg.auras[kind]
end

local function HasGrowth(id)
    return id == "party" or id == "raid" or id == "arena"
end

local function RelayoutSelected()
    if not UF.Frames then
        return
    end
    if selected == "party" and UF.Frames.RelayoutParty then
        UF.Frames.RelayoutParty()
    elseif selected == "raid" and UF.Frames.RelayoutRaid then
        UF.Frames.RelayoutRaid()
    elseif selected == "arena" and UF.Frames.RelayoutArena then
        UF.Frames.RelayoutArena()
    end
end

local function ShowTab(id)
    currentTab = id
    if not frame or not frame.pages then
        return
    end
    for name, page in pairs(frame.pages) do
        if page.SetShown then
            page:SetShown(name == id)
        end
    end
    if frame.scroll and frame.pages[id] then
        frame.scroll:SetScrollChild(frame.pages[id])
        frame.pages[id]:SetWidth(500)
        if frame.scroll.UpdateScrollChildRect then
            frame.scroll:UpdateScrollChildRect()
        end
        frame.scroll:SetVerticalScroll(0)
    end
end

local function Refresh()
    if not frame then
        return
    end
    local p = Profile()
    local cfg = UnitCfg()
    if frame.profileBox then
        frame.profileBox:SetText(UF.DB.CurrentName())
    end
    if frame.lockBtn then
        frame.lockBtn:SetLabel(p.locked and "Unlock frames" or "Lock frames")
    end
    if frame.unitLabel then
        frame.unitLabel:SetText(UnitTitle())
    end
    if frame.unitHead then
        frame.unitHead:SetText(string.upper(UnitTitle() .. " frame"))
    end
    if frame.navButtons then
        for i = 1, #frame.navButtons do
            local btn = frame.navButtons[i]
            if btn.navId == selected then
                btn.Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            else
                btn.Label:SetTextColor(0.78, 0.78, 0.78, 1)
            end
        end
    end
    if frame.enableDrop then
        frame.enableDrop:SetValue(cfg.enabled == false and "hidden" or "shown")
    end
    if frame.portraitDrop then
        local mode = cfg.portrait or p.portrait or "2d"
        if mode == "portrait" then
            mode = "2d"
        end
        if mode == "off" then
            mode = "hidden"
        end
        frame.portraitDrop:SetValue(mode)
    end
    if frame.barStyleDrop then
        local style = cfg.barStyle or "blizzard"
        if style ~= "modern" and style ~= "blocky" then
            style = "blizzard"
        end
        frame.barStyleDrop:SetValue(style)
    end
    if frame.healthColorDrop then
        local color = cfg.healthColor or p.healthColor
        if color ~= "blizzard" and color ~= "class" then
            color = (p.style == "classic") and "blizzard" or "class"
        end
        frame.healthColorDrop:SetValue(color)
    end
    if frame.healthBarRow then
        frame.healthBarRow:SetValueText(tostring(cfg.healthBarH or 36))
    end
    if frame.powerBarRow then
        frame.powerBarRow:SetValueText(tostring(cfg.powerBarH or 14))
    end
    if frame.healthDrop then
        frame.healthDrop:SetValue(cfg.healthText or p.healthText or "both")
    end
    if frame.powerTextDrop then
        frame.powerTextDrop:SetValue(cfg.powerText or p.powerText or "both")
    end
    if frame.powerDrop then
        local on = cfg.showPower
        if on == nil then
            on = p.showPower ~= false
        end
        frame.powerDrop:SetValue(on and "on" or "off")
    end
    if frame.altPowerDrop then
        local on = cfg.showAltPower
        if on == nil then
            on = p.showAltPower ~= false
        end
        frame.altPowerDrop:SetValue(on and "on" or "off")
    end
    if frame.widthRow then
        frame.widthRow:SetValueText(tostring(cfg.w or 200))
    end
    if frame.heightRow then
        frame.heightRow:SetValueText(tostring(cfg.h or 56))
    end
    if frame.scaleRow then
        frame.scaleRow:SetValueText(string.format("%.2f", cfg.scale or 1))
    end
    if frame.youDrop then
        frame.youDrop:SetValue(p.showPlayerInParty == false and "off" or "on")
        if selected == "party" then
            frame.youDrop:Show()
        else
            frame.youDrop:Hide()
        end
    end
    if frame.growthDrop then
        frame.growthDrop:SetValue(string.upper(tostring(cfg.growth or "DOWN")))
        if HasGrowth(selected) then
            frame.growthDrop:Show()
        else
            frame.growthDrop:Hide()
        end
    end

    local function FillAura(prefix, kind)
        local a = AuraKind(kind)
        if frame[prefix .. "Enable"] then
            frame[prefix .. "Enable"]:SetValue(a.enabled and "on" or "off")
        end
        if frame[prefix .. "Filter"] then
            frame[prefix .. "Filter"]:SetValue(a.filter or "all")
        end
        if frame[prefix .. "Anchor"] then
            frame[prefix .. "Anchor"]:SetValue(a.anchor or "BOTTOMLEFT")
        end
        if frame[prefix .. "Growth"] then
            frame[prefix .. "Growth"]:SetValue(string.upper(a.growth or "RIGHT"))
        end
        if frame[prefix .. "Timers"] then
            frame[prefix .. "Timers"]:SetValue(a.timers == false and "off" or "on")
        end
        if frame[prefix .. "Size"] then
            frame[prefix .. "Size"]:SetValueText(tostring(a.size or 18))
        end
        if frame[prefix .. "Max"] then
            frame[prefix .. "Max"]:SetValueText(tostring(a.max or 8))
        end
    end
    FillAura("buff", "buffs")
    FillAura("debuff", "debuffs")

    local ind = cfg.indicators or {}
    local function Ind(name, key)
        if frame[name] then
            frame[name]:SetValue(ind[key] == false and "off" or "on")
        end
    end
    Ind("indCombat", "combat")
    Ind("indRest", "resting")
    Ind("indLeader", "leader")
    Ind("indMark", "raidTarget")
    Ind("indPvp", "pvp")
    Ind("indRole", "role")
    Ind("indGroupRole", "groupRole")
    Ind("indRez", "resurrect")
    Ind("indReady", "ready")
    Ind("indElite", "elite")
    Ind("indRare", "rare")
    Ind("indRareElite", "rareelite")
    Ind("indHappy", "happiness")
    Ind("indPhase", "phase")
    Ind("indOor", "oor")
    Ind("indQuest", "quest")
    local indPos = cfg.indPos or {}
    local function IndP(name, key)
        if frame[name] then
            frame[name]:SetValue(string.upper(tostring(indPos[key] or "CENTER")))
        end
    end
    IndP("indCombatPos", "combat")
    IndP("indRestPos", "resting")
    IndP("indLeaderPos", "leader")
    IndP("indMarkPos", "raidTarget")
    IndP("indPvpPos", "pvp")
    IndP("indRolePos", "role")
    IndP("indGroupRolePos", "groupRole")
    IndP("indRezPos", "resurrect")
    IndP("indReadyPos", "ready")
    IndP("indElitePos", "elite")
    IndP("indRarePos", "rare")
    IndP("indRareElitePos", "rareelite")
    IndP("indHappyPos", "happiness")
    IndP("indPhasePos", "phase")
    IndP("indOorPos", "oor")
    IndP("indQuestPos", "quest")
    local indSize = cfg.indSize or {}
    local function IndS(name, key, fallback)
        if frame[name] then
            frame[name]:SetValueText(tostring(indSize[key] or fallback or 14))
        end
    end
    IndS("indCombatSize", "combat", 14)
    IndS("indRestSize", "resting", 14)
    IndS("indLeaderSize", "leader", 12)
    IndS("indMarkSize", "raidTarget", 18)
    IndS("indPvpSize", "pvp", 16)
    IndS("indRoleSize", "role", 12)
    IndS("indGroupRoleSize", "groupRole", 16)
    IndS("indRezSize", "resurrect", 16)
    IndS("indReadySize", "ready", 16)
    IndS("indEliteSize", "elite", 20)
    IndS("indRareSize", "rare", 18)
    IndS("indRareEliteSize", "rareelite", 20)
    IndS("indHappySize", "happiness", 16)
    IndS("indPhaseSize", "phase", 16)
    IndS("indOorSize", "oor", 14)
    IndS("indQuestSize", "quest", 16)
    local tpos = cfg.textPos or {}
    if frame.nameBarDrop then
        frame.nameBarDrop:SetValue(cfg.nameBar or "top")
    end
    if frame.nameBarRow then
        frame.nameBarRow:SetValueText(tostring(cfg.nameBarH or 16))
    end
    if frame.nameBgDrop then
        frame.nameBgDrop:SetValue(cfg.nameBg or "dark")
    end
    if frame.nameTextDrop then
        frame.nameTextDrop:SetValue(cfg.nameText or "white")
    end
    if frame.namePosDrop then
        frame.namePosDrop:SetValue(tpos.name or "LEFT")
    end
    if frame.levelDrop then
        frame.levelDrop:SetValue(cfg.showLevel == false and "off" or "on")
    end
    if frame.levelPosDrop then
        frame.levelPosDrop:SetValue(tpos.level or "RIGHT")
    end
    local function WidthText(v)
        v = tonumber(v) or 0
        if v <= 0 then
            return tostring(cfg.w or 250)
        end
        return tostring(v)
    end
    if frame.nameWRow then
        frame.nameWRow:SetValueText(WidthText(cfg.nameBarW))
    end
    if frame.nameAlignDrop then
        frame.nameAlignDrop:SetValue(cfg.nameBarAlign or "LEFT")
    end
    if frame.healthWRow then
        frame.healthWRow:SetValueText(WidthText(cfg.healthBarW))
    end
    if frame.healthAlignDrop then
        frame.healthAlignDrop:SetValue(cfg.healthBarAlign or "LEFT")
    end
    if frame.healthPosDrop then
        frame.healthPosDrop:SetValue(tpos.health or "LEFT")
    end
    if frame.healthPctPosDrop then
        frame.healthPctPosDrop:SetValue(tpos.healthPct or "RIGHT")
    end
    if frame.powerWRow then
        frame.powerWRow:SetValueText(WidthText(cfg.powerBarW))
    end
    if frame.powerAlignDrop then
        frame.powerAlignDrop:SetValue(cfg.powerBarAlign or "LEFT")
    end
    if frame.powerPosDrop then
        frame.powerPosDrop:SetValue(tpos.power or "LEFT")
    end
    if frame.powerPctPosDrop then
        frame.powerPctPosDrop:SetValue(tpos.powerPct or "RIGHT")
    end
    if frame.altWRow then
        frame.altWRow:SetValueText(WidthText(cfg.altBarW))
    end
    if frame.altAlignDrop then
        frame.altAlignDrop:SetValue(cfg.altBarAlign or "LEFT")
    end
    if frame.altPosDrop then
        frame.altPosDrop:SetValue(tpos.alt or "LEFT")
    end
    if frame.altPctPosDrop then
        frame.altPctPosDrop:SetValue(tpos.altPct or "RIGHT")
    end

    local extra = cfg.extra or {}
    if frame.healDrop then
        frame.healDrop:SetValue(extra.healPredict == false and "off" or "on")
    end
    if frame.absorbDrop then
        frame.absorbDrop:SetValue(extra.absorb == false and "off" or "on")
    end
    if frame.healAbsorbDrop then
        frame.healAbsorbDrop:SetValue(extra.healAbsorb == false and "off" or "on")
    end
    if frame.mouseDrop then
        frame.mouseDrop:SetValue(extra.mouseover == false and "off" or "on")
    end
    if frame.aggroDrop then
        frame.aggroDrop:SetValue(extra.aggro == false and "off" or "on")
    end
    if frame.castDrop then
        frame.castDrop:SetValue(extra.castBar == false and "off" or "on")
    end
    if frame.castAttachDrop then
        local c = extra.cast or {}
        frame.castAttachDrop:SetValue(c.attach or "BELOW")
    end
    if frame.castWRow then
        local c = extra.cast or {}
        frame.castWRow:SetValueText(tostring((c.w and c.w > 0) and c.w or "Match"))
    end
    if frame.castHRow then
        local c = extra.cast or {}
        frame.castHRow:SetValueText(tostring(c.h or 12))
    end
    if frame.rangeDrop then
        frame.rangeDrop:SetValue(extra.rangeFade == false and "off" or "on")
    end
    if frame.styleDrop then
        frame.styleDrop:SetValue(p.style == "classic" and "classic" or "modern")
    end
    if frame.colorDrop then
        frame.colorDrop:SetValue(p.classColors == "modern" and "modern" or "classic")
    end
    RelayoutGeneral()
end

local function ApplyNow()
    if UF.ApplyProfile then
        UF.ApplyProfile(Profile())
    end
    RelayoutSelected()
    Refresh()
end

local FRAME_NUM = {
    w = { min = 60, max = 400, label = "Width " },
    h = { min = 28, max = 160, label = "Frame height " },
    scale = { min = 0.6, max = 2, label = "Scale ", places = 2 },
    healthBarH = { min = 6, max = 64, label = "Health bar height " },
    powerBarH = { min = 4, max = 48, label = "Power bar height " },
    nameBarH = { min = 10, max = 32, label = "Name bar height " },
    nameBarW = { min = 0, max = 400, label = "Name bar width ", fill = true },
    healthBarW = { min = 0, max = 400, label = "Health bar width ", fill = true },
    powerBarW = { min = 0, max = 400, label = "Power bar width ", fill = true },
    altBarW = { min = 0, max = 400, label = "Second power width ", fill = true },
}

local function ParseNumber(text)
    if type(text) == "number" then
        return text
    end
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub(",", ".")
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" then
        return nil
    end
    return tonumber(text)
end

local function ApplyFrameNumber(key, v)
    local spec = FRAME_NUM[key]
    if not spec then
        return
    end
    if UF.Compat.InCombat() then
        Speak("Frames are locked in combat.")
        Refresh()
        return
    end
    if type(v) ~= "number" then
        Speak("Enter a number.")
        Refresh()
        return
    end
    CloseMenus()
    if v < spec.min then
        v = spec.min
    end
    if v > spec.max then
        v = spec.max
    end
    if spec.fill then
        if v <= 0 then
            v = 0
        elseif v < 20 then
            v = 20
        end
    end
    if spec.places then
        local mult = 10 ^ spec.places
        v = math.floor(v * mult + 0.5) / mult
    else
        v = math.floor(v + 0.5)
    end
    local cfg = UnitCfg()
    cfg[key] = v
    local powerOn = cfg.showPower
    if powerOn == nil then
        powerOn = Profile().showPower ~= false
    end
    if key == "healthBarH" or key == "powerBarH" or key == "nameBarH" then
        if UF.Factory and UF.Factory.FitHeight then
            local _, need = UF.Factory.FitHeight(cfg, { powerOn = powerOn })
            cfg.h = need
        end
    elseif key == "h" and UF.Factory and UF.Factory.Measure then
        local _, frameH, healthH = UF.Factory.Measure(cfg, { powerOn = powerOn })
        cfg.h = frameH
        cfg.healthBarH = healthH
    end
    ApplyNow()
    if spec.fill and v <= 0 then
        Speak(spec.label .. "fills the frame.")
    else
        Speak(spec.label .. (spec.places and string.format("%." .. spec.places .. "f", v) or tostring(v)) .. ".")
    end
end

local function Nudge(key, delta, minV, maxV, step)
    local cfg = UnitCfg()
    local spec = FRAME_NUM[key]
    local v = cfg[key]
    if spec and spec.fill then
        v = tonumber(v) or 0
        if v <= 0 then
            v = tonumber(cfg.w) or 250
        end
        ApplyFrameNumber(key, v + (delta * step))
        return
    end
    if type(v) ~= "number" then
        if key == "scale" then
            v = 1
        elseif key == "h" then
            v = 56
        elseif key == "healthBarH" then
            v = 36
        elseif key == "powerBarH" then
            v = 14
        elseif key == "nameBarH" then
            v = 16
        else
            v = 200
        end
    end
    ApplyFrameNumber(key, v + (delta * step))
end

local function ApplyAuraNumber(kind, key, v, minV, maxV)
    if type(v) ~= "number" then
        Speak("Enter a number.")
        Refresh()
        return
    end
    CloseMenus()
    if v < minV then
        v = minV
    end
    if v > maxV then
        v = maxV
    end
    local a = AuraKind(kind)
    a[key] = math.floor(v + 0.5)
    if key == "max" then
        a.perRow = a[key]
    end
    ApplyNow()
    Speak((key == "size" and "Icon size " or "Count ") .. tostring(a[key]) .. ".")
end

local function NudgeAura(kind, key, delta, minV, maxV, step)
    local a = AuraKind(kind)
    ApplyAuraNumber(kind, key, (tonumber(a[key]) or minV) + delta * step, minV, maxV)
end

local function BindEdit(row, fn)
    if not row or not row.SetOnCommit then
        return
    end
    row:SetOnCommit(fn)
    row._onEscape = Refresh
end

local function ParseWidth(text)
    if type(text) == "string" then
        local raw = text:match("^%s*(.-)%s*$") or ""
        local low = string.lower(raw)
        if raw == "" or low == "fill" or low == "match" then
            return 0
        end
    end
    return ParseNumber(text)
end

local function SetTextPos(key, id, spoken)
    UnitCfg().textPos = UnitCfg().textPos or {}
    UnitCfg().textPos[key] = id
    ApplyNow()
    Speak(spoken)
end

local function ApplyIndSize(field, v, label)
    if type(v) ~= "number" then
        Speak("Enter a number.")
        Refresh()
        return
    end
    if v < 8 then
        v = 8
    end
    if v > 40 then
        v = 40
    end
    v = math.floor(v + 0.5)
    local cfg = UnitCfg()
    cfg.indSize = cfg.indSize or {}
    cfg.indSize[field] = v
    ApplyNow()
    Speak((label or "Icon") .. " size " .. tostring(v) .. ".")
end

local function NudgeIndSize(field, delta, label, fallback)
    local cfg = UnitCfg()
    cfg.indSize = cfg.indSize or {}
    local cur = tonumber(cfg.indSize[field]) or fallback or 14
    ApplyIndSize(field, cur + delta, label)
end

local function CastCfg()
    local extra = UnitCfg().extra
    if type(extra) ~= "table" then
        extra = {}
        UnitCfg().extra = extra
    end
    extra.cast = extra.cast or {}
    return extra.cast
end

local function ApplyCastWidth(v, match)
    if match then
        CastCfg().w = 0
        ApplyNow()
        Speak("Cast width matches the frame.")
        return
    end
    if type(v) ~= "number" then
        Speak("Enter a number, or Match.")
        Refresh()
        return
    end
    if v < 80 then
        v = 80
    end
    if v > 400 then
        v = 400
    end
    v = math.floor(v + 0.5)
    CastCfg().w = v
    ApplyNow()
    Speak("Cast width " .. tostring(v) .. ".")
end

local function ApplyCastHeight(v)
    if type(v) ~= "number" then
        Speak("Enter a number.")
        Refresh()
        return
    end
    if v < 8 then
        v = 8
    end
    if v > 40 then
        v = 40
    end
    v = math.floor(v + 0.5)
    CastCfg().h = v
    ApplyNow()
    Speak("Cast height " .. tostring(v) .. ".")
end

local function SaveWindowPos()
    if not frame then
        return
    end
    local p = Profile()
    local point, _, _, x, y = frame:GetPoint(1)
    p.window.point = point or "CENTER"
    p.window.x = x or 0
    p.window.y = y or 0
end

local function FillExport()
    CloseMenus()
    local code = UF.Share.Export()
    frame.code:SetText(code)
    frame.code:SetFocus()
    frame.code:HighlightText()
    local copied = UF.Compat.CopyToClipboard(code)
    Speak(copied and "Export code copied to the clipboard." or "Export code ready. Press control C to copy.")
end

local function DoImport()
    CloseMenus()
    local ok, msg = UF.Share.Import(frame.code:GetText(), frame.profileBox:GetText())
    Speak(msg)
    print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. msg)
    Refresh()
end

local function SelectUnit(id)
    CloseMenus()
    selected = id
    Refresh()
    local label = id
    for i = 1, #UNITS do
        if UNITS[i].id == id then
            label = UNITS[i].label
            break
        end
    end
    Speak(label .. " settings. " .. currentTab .. ".")
end

local function Drop(parent, title, width, titleWidth, options, tip, hint)
    local row = UF.Widgets.Dropdown(parent, title, width, titleWidth)
    row:SetOptions(options)
    row._tip = tip
    row._hint = hint
    row._speakOpen = title
    row._speak = title .. " dropdown."
    return row
end

local function BuildPage(parent, name, height)
    local page = CreateFrame("Frame", nil, parent)
    page:SetWidth(500)
    page:SetHeight(height or 920)
    page:Hide()
    frame.pages[name] = page
    return page
end

local function Stack()
    local y = 0
    return function(widget, h)
        widget:SetPoint("TOPLEFT", 0, y)
        y = y - (h + 8)
        return y
    end
end

function RelayoutGeneral()
    if not frame or not frame.generalRows then
        return
    end
    local y = 0
    for i = 1, #frame.generalRows do
        local row = frame.generalRows[i]
        if row.widget and row.widget.IsShown and row.widget:IsShown() then
            row.widget:ClearAllPoints()
            row.widget:SetPoint("TOPLEFT", 0, y)
            y = y - (row.h + 8)
        end
    end
    local page = frame.pages and frame.pages.general
    if page then
        page:SetHeight(math.max(920, 40 - y))
    end
    if frame.scroll and frame.scroll.UpdateScrollChildRect then
        frame.scroll:UpdateScrollChildRect()
    end
end

local function Build()
    if frame then
        return frame
    end

    local tmpl = UF.Compat.BackdropTemplate()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, tmpl)
    frame:SetSize(760, 640)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    UF.Widgets.Paint(frame, 0.07, 0.07, 0.08, 1, 0.72, 0.66, 0.38)
    tinsert(UISpecialFrames, FRAME_NAME)
    frame.pages = {}

    local p = Profile()
    frame:SetPoint(p.window.point or "CENTER", UIParent, p.window.point or "CENTER", p.window.x or 0, p.window.y or 0)
    frame:SetScript("OnDragStart", function(self)
        CloseMenus()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPos()
    end)
    frame:SetScript("OnHide", CloseMenus)

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("TOPLEFT", 16, -14)
    local folder = (UF.Flavor and UF.Flavor.folder) or "BMG-Unit-frames"
    logo:SetTexture("Interface\\AddOns\\" .. folder .. "\\Media\\Icon.png")

    local title = UF.Widgets.Label(frame, 18, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("BMG Unit Frames")

    local sub = UF.Widgets.Label(frame, 12, 0.62, 0.62, 0.64)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetText("Choose a unit, then a category.")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        CloseMenus()
        frame:Hide()
        Speak("Unit frame settings closed.")
    end)

    local foot = CreateFrame("Frame", nil, frame, tmpl)
    foot:SetPoint("BOTTOMLEFT", 16, 12)
    foot:SetPoint("BOTTOMRIGHT", -16, 12)
    foot:SetHeight(104)
    UF.Widgets.Paint(foot, 0.05, 0.05, 0.06, 1, 0.28, 0.28, 0.30)

    local nav = CreateFrame("Frame", nil, frame, tmpl)
    nav:SetPoint("TOPLEFT", 16, -58)
    nav:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 12)
    nav:SetWidth(168)
    UF.Widgets.Paint(nav, 0.05, 0.05, 0.06, 1, 0.28, 0.28, 0.30)
    frame.navButtons = {}
    for i = 1, #UNITS do
        local info = UNITS[i]
        local btn = CreateFrame("Button", nil, nav)
        btn:SetHeight(30)
        btn:SetPoint("TOPLEFT", 8, -10 - ((i - 1) * 32))
        btn:SetPoint("RIGHT", -8, 0)
        local fs = UF.Widgets.Label(btn, 13, 0.78, 0.78, 0.78)
        fs:SetPoint("LEFT", 8, 0)
        fs:SetText(info.label)
        btn.Label = fs
        btn.navId = info.id
        btn:SetScript("OnClick", function()
            SelectUnit(info.id)
        end)
        btn:SetScript("OnEnter", function()
            fs:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            Speak(info.label)
        end)
        btn:SetScript("OnLeave", function()
            if selected ~= info.id then
                fs:SetTextColor(0.78, 0.78, 0.78, 1)
            end
        end)
        frame.navButtons[#frame.navButtons + 1] = btn
    end

    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", nav, "TOPRIGHT", 16, 0)
    pane:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 12)

    frame.unitLabel = UF.Widgets.Label(pane, 16, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    frame.unitLabel:SetPoint("TOPLEFT", 0, 0)
    frame.unitLabel:SetText("Player")

    local tabs = UF.Widgets.Tabs(pane, {
        { id = "general", label = "General" },
        { id = "auras", label = "Auras" },
        { id = "indicators", label = "Indicators" },
        { id = "more", label = "More" },
    }, 500, function(id, label)
        CloseMenus()
        ShowTab(id)
        Speak(label .. ".")
    end)
    tabs:SetPoint("TOPLEFT", 0, -26)

    local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", pane)
    scroll:SetPoint("TOPLEFT", 0, -62)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxs = self:GetVerticalScrollRange() or 0
        local nexts = cur - (delta * 36)
        if nexts < 0 then
            nexts = 0
        end
        if nexts > maxs then
            nexts = maxs
        end
        self:SetVerticalScroll(nexts)
    end)
    frame.scroll = scroll

    local general = BuildPage(scroll, "general", 1680)
    local rawG = Stack()
    frame.generalRows = {}
    local function g(widget, h)
        table.insert(frame.generalRows, { widget = widget, h = h })
        return rawG(widget, h)
    end
    frame.unitHead = UF.Widgets.Header(general, "Player frame")
    g(frame.unitHead, 16)
    frame.enableDrop = Drop(general, "This frame", 500, 140, {
        { id = "shown", label = "Shown" },
        { id = "hidden", label = "Hidden" },
    }, "This frame", "Show or hide this unit.")
    frame.enableDrop:SetOnChange(function(id, text)
        UnitCfg().enabled = id ~= "hidden"
        ApplyNow()
        Speak(text .. ".")
    end)
    g(frame.enableDrop, 32)
    frame.widthRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.widthRow.minus:SetScript("OnClick", function()
        Nudge("w", -1, 60, 400, 5)
    end)
    frame.widthRow.plus:SetScript("OnClick", function()
        Nudge("w", 1, 60, 400, 5)
    end)
    BindEdit(frame.widthRow, function(text)
        ApplyFrameNumber("w", ParseNumber(text))
    end)
    g(frame.widthRow, 32)
    frame.heightRow = UF.Widgets.Stepper(general, "Height", 500)
    frame.heightRow.minus:SetScript("OnClick", function()
        Nudge("h", -1, 28, 160, 2)
    end)
    frame.heightRow.plus:SetScript("OnClick", function()
        Nudge("h", 1, 28, 160, 2)
    end)
    BindEdit(frame.heightRow, function(text)
        ApplyFrameNumber("h", ParseNumber(text))
    end)
    g(frame.heightRow, 32)
    frame.scaleRow = UF.Widgets.Stepper(general, "Scale", 500)
    frame.scaleRow.minus:SetScript("OnClick", function()
        Nudge("scale", -1, 0.6, 2, 0.05)
    end)
    frame.scaleRow.plus:SetScript("OnClick", function()
        Nudge("scale", 1, 0.6, 2, 0.05)
    end)
    BindEdit(frame.scaleRow, function(text)
        ApplyFrameNumber("scale", ParseNumber(text))
    end)
    g(frame.scaleRow, 32)
    frame.portraitDrop = Drop(general, "Portrait", 500, 140, {
        { id = "3d", label = "3D" },
        { id = "2d", label = "2D" },
        { id = "class", label = "Class icon" },
        { id = "hidden", label = "Hidden" },
    }, "Portrait", "3D model, 2D face, class icon, or hidden.")
    frame.portraitDrop:SetOnChange(function(id, text)
        UnitCfg().portrait = id
        ApplyNow()
        Speak("Portrait " .. text .. ".")
    end)
    g(frame.portraitDrop, 32)
    frame.barStyleDrop = Drop(general, "Bar style", 500, 200, {
        { id = "blizzard", label = "Blizzard Classic" },
        { id = "modern", label = "Blizzard Modern" },
        { id = "blocky", label = "Blocky" },
    }, "Bar style", "How the bars are drawn. Classic is the old gradient. Modern is the raid-style fill. Blocky is a flat solid fill with a hard edge.")
    frame.barStyleDrop:SetOnChange(function(id, text)
        UnitCfg().barStyle = id
        ApplyNow()
        Speak("Bar style " .. text .. ".")
    end)
    g(frame.barStyleDrop, 32)
    frame.youDrop = Drop(general, "Party includes you", 500, 180, ON_OFF, "Show you in party", "Adds your character as the first party bar.")
    frame.youDrop:SetOnChange(function(id, text)
        Profile().showPlayerInParty = id == "on"
        ApplyNow()
        Speak("Party includes you " .. text .. ".")
    end)
    g(frame.youDrop, 32)
    frame.growthDrop = Drop(general, "Growth", 500, 140, {
        { id = "DOWN", label = "Down" },
        { id = "UP", label = "Up" },
        { id = "LEFT", label = "Left" },
        { id = "RIGHT", label = "Right" },
    }, "Growth", "How party, raid, or arena bars stack.")
    frame.growthDrop:SetOnChange(function(id, text)
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            Refresh()
            return
        end
        UnitCfg().growth = id
        ApplyNow()
        Speak("Growth " .. text .. ".")
    end)
    g(frame.growthDrop, 32)

    local nameHead = UF.Widgets.Header(general, "Name bar")
    g(nameHead, 16)
    frame.nameBarDrop = Drop(general, "Placement", 500, 200, {
        { id = "top", label = "Bar above health" },
        { id = "bottom", label = "Bar below health" },
        { id = "overlay", label = "Overlay on health" },
        { id = "hidden", label = "Hidden" },
    }, "Name bar placement", "A styled name strip above, below, or on the health bar.")
    frame.nameBarDrop:SetOnChange(function(id, text)
        local cfg = UnitCfg()
        cfg.nameBar = id
        if (id == "top" or id == "bottom") and UF.Factory and UF.Factory.FitHeight then
            local powerOn = cfg.showPower
            if powerOn == nil then
                powerOn = Profile().showPower ~= false
            end
            local _, need = UF.Factory.FitHeight(cfg, { powerOn = powerOn })
            cfg.h = need
        end
        ApplyNow()
        Speak("Name bar " .. text .. ".")
    end)
    g(frame.nameBarDrop, 32)
    frame.nameBarRow = UF.Widgets.Stepper(general, "Height", 500)
    frame.nameBarRow.minus:SetScript("OnClick", function()
        Nudge("nameBarH", -1, 10, 32, 1)
    end)
    frame.nameBarRow.plus:SetScript("OnClick", function()
        Nudge("nameBarH", 1, 10, 32, 1)
    end)
    BindEdit(frame.nameBarRow, function(text)
        ApplyFrameNumber("nameBarH", ParseNumber(text))
    end)
    g(frame.nameBarRow, 32)
    frame.nameWRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.nameWRow.minus:SetScript("OnClick", function()
        Nudge("nameBarW", -1, 0, 400, 5)
    end)
    frame.nameWRow.plus:SetScript("OnClick", function()
        Nudge("nameBarW", 1, 0, 400, 5)
    end)
    BindEdit(frame.nameWRow, function(text)
        ApplyFrameNumber("nameBarW", ParseWidth(text))
    end)
    g(frame.nameWRow, 32)
    frame.nameAlignDrop = Drop(general, "Align", 500, 140, UF.Pos.ALIGN, "Name bar align", "Left, center, or right when the name bar is narrower than the frame.")
    frame.nameAlignDrop:SetOnChange(function(id, text)
        UnitCfg().nameBarAlign = id
        ApplyNow()
        Speak("Name bar " .. text .. ".")
    end)
    g(frame.nameAlignDrop, 32)
    frame.nameBgDrop = Drop(general, "Background", 500, 180, {
        { id = "dark", label = "Dark" },
        { id = "transparent", label = "Transparent" },
        { id = "black", label = "Black" },
        { id = "class", label = "Class color" },
        { id = "gold", label = "Gold" },
        { id = "health", label = "Health green" },
    }, "Name background", "Fill of the name bar. Dark is the default.")
    frame.nameBgDrop:SetOnChange(function(id, text)
        UnitCfg().nameBg = id
        ApplyNow()
        Speak("Name background " .. text .. ".")
    end)
    g(frame.nameBgDrop, 32)
    frame.nameTextDrop = Drop(general, "Text color", 500, 160, {
        { id = "white", label = "White" },
        { id = "gold", label = "Gold" },
        { id = "class", label = "Class color" },
        { id = "black", label = "Black" },
    }, "Name text", "Color of the unit name.")
    frame.nameTextDrop:SetOnChange(function(id, text)
        UnitCfg().nameText = id
        ApplyNow()
        Speak("Name text " .. text .. ".")
    end)
    g(frame.nameTextDrop, 32)
    frame.namePosDrop = Drop(general, "Name position", 500, 160, UF.Pos.OPTIONS, "Name position", "Where the name sits on the name bar.")
    frame.namePosDrop:SetOnChange(function(id, text)
        SetTextPos("name", id, "Name " .. text .. ".")
    end)
    g(frame.namePosDrop, 32)
    frame.levelDrop = Drop(general, "Level", 500, 140, ON_OFF, "Level", "Show the unit level on the name bar.")
    frame.levelDrop:SetOnChange(function(id, text)
        UnitCfg().showLevel = id == "on"
        ApplyNow()
        Speak("Level " .. text .. ".")
    end)
    g(frame.levelDrop, 32)
    frame.levelPosDrop = Drop(general, "Level position", 500, 160, UF.Pos.OPTIONS, "Level position", "Where the level sits on the name bar.")
    frame.levelPosDrop:SetOnChange(function(id, text)
        SetTextPos("level", id, "Level " .. text .. ".")
    end)
    g(frame.levelPosDrop, 32)

    local healthHead = UF.Widgets.Header(general, "Health bar")
    g(healthHead, 16)
    frame.healthColorDrop = Drop(general, "Color", 500, 180, {
        { id = "blizzard", label = "Blizzard (green)" },
        { id = "class", label = "Class color" },
    }, "Health color", "Standard green health, or the unit's class color.")
    frame.healthColorDrop:SetOnChange(function(id, text)
        UnitCfg().healthColor = id
        ApplyNow()
        Speak("Health color " .. text .. ".")
    end)
    g(frame.healthColorDrop, 32)
    frame.healthBarRow = UF.Widgets.Stepper(general, "Height", 500)
    frame.healthBarRow.minus:SetScript("OnClick", function()
        Nudge("healthBarH", -1, 6, 64, 2)
    end)
    frame.healthBarRow.plus:SetScript("OnClick", function()
        Nudge("healthBarH", 1, 6, 64, 2)
    end)
    BindEdit(frame.healthBarRow, function(text)
        ApplyFrameNumber("healthBarH", ParseNumber(text))
    end)
    g(frame.healthBarRow, 32)
    frame.healthWRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.healthWRow.minus:SetScript("OnClick", function()
        Nudge("healthBarW", -1, 0, 400, 5)
    end)
    frame.healthWRow.plus:SetScript("OnClick", function()
        Nudge("healthBarW", 1, 0, 400, 5)
    end)
    BindEdit(frame.healthWRow, function(text)
        ApplyFrameNumber("healthBarW", ParseWidth(text))
    end)
    g(frame.healthWRow, 32)
    frame.healthAlignDrop = Drop(general, "Align", 500, 140, UF.Pos.ALIGN, "Health bar align", "Left, center, or right when the health bar is narrower than the frame.")
    frame.healthAlignDrop:SetOnChange(function(id, text)
        UnitCfg().healthBarAlign = id
        ApplyNow()
        Speak("Health bar " .. text .. ".")
    end)
    g(frame.healthAlignDrop, 32)
    frame.healthDrop = Drop(general, "Text", 500, 140, TEXT_OPTS, "Health text", "Number, percent, both, or hidden.")
    frame.healthDrop:SetOnChange(function(id, text)
        UnitCfg().healthText = id
        ApplyNow()
        Speak("Health " .. text .. ".")
    end)
    g(frame.healthDrop, 32)
    frame.healthPosDrop = Drop(general, "Number position", 500, 160, UF.Pos.OPTIONS, "Health number position", "Where the health amount sits on the bar.")
    frame.healthPosDrop:SetOnChange(function(id, text)
        SetTextPos("health", id, "Health number " .. text .. ".")
    end)
    g(frame.healthPosDrop, 32)
    frame.healthPctPosDrop = Drop(general, "Percent position", 500, 160, UF.Pos.OPTIONS, "Health percent position", "Where the health percent sits on the bar.")
    frame.healthPctPosDrop:SetOnChange(function(id, text)
        SetTextPos("healthPct", id, "Health percent " .. text .. ".")
    end)
    g(frame.healthPctPosDrop, 32)

    local powerHead = UF.Widgets.Header(general, "Power bar")
    g(powerHead, 16)
    frame.powerDrop = Drop(general, "Show", 500, 140, ON_OFF, "Power bar", "Mana, rage, energy, or focus.")
    frame.powerDrop:SetOnChange(function(id, text)
        UnitCfg().showPower = id == "on"
        ApplyNow()
        Speak("Power bar " .. text .. ".")
    end)
    g(frame.powerDrop, 32)
    frame.powerBarRow = UF.Widgets.Stepper(general, "Height", 500)
    frame.powerBarRow.minus:SetScript("OnClick", function()
        Nudge("powerBarH", -1, 4, 48, 2)
    end)
    frame.powerBarRow.plus:SetScript("OnClick", function()
        Nudge("powerBarH", 1, 4, 48, 2)
    end)
    BindEdit(frame.powerBarRow, function(text)
        ApplyFrameNumber("powerBarH", ParseNumber(text))
    end)
    g(frame.powerBarRow, 32)
    frame.powerWRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.powerWRow.minus:SetScript("OnClick", function()
        Nudge("powerBarW", -1, 0, 400, 5)
    end)
    frame.powerWRow.plus:SetScript("OnClick", function()
        Nudge("powerBarW", 1, 0, 400, 5)
    end)
    BindEdit(frame.powerWRow, function(text)
        ApplyFrameNumber("powerBarW", ParseWidth(text))
    end)
    g(frame.powerWRow, 32)
    frame.powerAlignDrop = Drop(general, "Align", 500, 140, UF.Pos.ALIGN, "Power bar align", "Left, center, or right when the power bar is narrower than the frame.")
    frame.powerAlignDrop:SetOnChange(function(id, text)
        UnitCfg().powerBarAlign = id
        ApplyNow()
        Speak("Power bar " .. text .. ".")
    end)
    g(frame.powerAlignDrop, 32)
    frame.powerTextDrop = Drop(general, "Text", 500, 140, TEXT_OPTS, "Power text", "Number, percent, both, or hidden on the power bar.")
    frame.powerTextDrop:SetOnChange(function(id, text)
        UnitCfg().powerText = id
        ApplyNow()
        Speak("Power text " .. text .. ".")
    end)
    g(frame.powerTextDrop, 32)
    frame.powerPosDrop = Drop(general, "Number position", 500, 160, UF.Pos.OPTIONS, "Power number position", "Where the power amount sits on the bar.")
    frame.powerPosDrop:SetOnChange(function(id, text)
        SetTextPos("power", id, "Power number " .. text .. ".")
    end)
    g(frame.powerPosDrop, 32)
    frame.powerPctPosDrop = Drop(general, "Percent position", 500, 160, UF.Pos.OPTIONS, "Power percent position", "Where the power percent sits on the bar.")
    frame.powerPctPosDrop:SetOnChange(function(id, text)
        SetTextPos("powerPct", id, "Power percent " .. text .. ".")
    end)
    g(frame.powerPctPosDrop, 32)

    local altHead = UF.Widgets.Header(general, "Second power bar")
    g(altHead, 16)
    frame.altPowerDrop = Drop(general, "Show", 500, 140, ON_OFF, "Second power", "Holy Power, combo points, and other class resources.")
    frame.altPowerDrop:SetOnChange(function(id, text)
        UnitCfg().showAltPower = id == "on"
        ApplyNow()
        Speak("Second power " .. text .. ".")
    end)
    g(frame.altPowerDrop, 32)
    frame.altWRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.altWRow.minus:SetScript("OnClick", function()
        Nudge("altBarW", -1, 0, 400, 5)
    end)
    frame.altWRow.plus:SetScript("OnClick", function()
        Nudge("altBarW", 1, 0, 400, 5)
    end)
    BindEdit(frame.altWRow, function(text)
        ApplyFrameNumber("altBarW", ParseWidth(text))
    end)
    g(frame.altWRow, 32)
    frame.altAlignDrop = Drop(general, "Align", 500, 140, UF.Pos.ALIGN, "Second power align", "Left, center, or right when the second power bar is narrower than the frame.")
    frame.altAlignDrop:SetOnChange(function(id, text)
        UnitCfg().altBarAlign = id
        ApplyNow()
        Speak("Second power " .. text .. ".")
    end)
    g(frame.altAlignDrop, 32)
    frame.altPosDrop = Drop(general, "Number position", 500, 160, UF.Pos.OPTIONS, "Second power number position", "Where the second power amount sits.")
    frame.altPosDrop:SetOnChange(function(id, text)
        SetTextPos("alt", id, "Second power number " .. text .. ".")
    end)
    g(frame.altPosDrop, 32)
    frame.altPctPosDrop = Drop(general, "Percent position", 500, 160, UF.Pos.OPTIONS, "Second power percent position", "Where the second power percent sits.")
    frame.altPctPosDrop:SetOnChange(function(id, text)
        SetTextPos("altPct", id, "Second power percent " .. text .. ".")
    end)
    local endY = g(frame.altPctPosDrop, 32)
    if type(endY) == "number" then
        general:SetHeight(math.max(920, 40 - endY))
    end

    local auras = BuildPage(scroll, "auras")
    local function AuraSection(page, place, prefix, kind, title)
        local h = UF.Widgets.Header(page, title)
        place(h, 16)
        frame[prefix .. "Enable"] = Drop(page, "Show", 500, 140, ON_OFF, title, "Show these icons on this unit.")
        frame[prefix .. "Enable"]:SetOnChange(function(id, text)
            AuraKind(kind).enabled = id == "on"
            ApplyNow()
            Speak(title .. " " .. text .. ".")
        end)
        place(frame[prefix .. "Enable"], 32)
        frame[prefix .. "Filter"] = Drop(page, "Filter", 500, 140, FILTER_OPTS, "Filter", "All auras, only yours, or only what you can dispel.")
        frame[prefix .. "Filter"]:SetOnChange(function(id, text)
            AuraKind(kind).filter = id
            ApplyNow()
            Speak("Filter " .. text .. ".")
        end)
        place(frame[prefix .. "Filter"], 32)
        frame[prefix .. "Anchor"] = Drop(page, "Position", 500, 140, ANCHOR_OPTS, "Position", "Where the icons sit on the frame.")
        frame[prefix .. "Anchor"]:SetOnChange(function(id, text)
            AuraKind(kind).anchor = id
            ApplyNow()
            Speak("Position " .. text .. ".")
        end)
        place(frame[prefix .. "Anchor"], 32)
        frame[prefix .. "Growth"] = Drop(page, "Grow", 500, 140, GROWTH_OPTS, "Grow", "Which way extra icons wrap.")
        frame[prefix .. "Growth"]:SetOnChange(function(id, text)
            AuraKind(kind).growth = id
            ApplyNow()
            Speak("Grow " .. text .. ".")
        end)
        place(frame[prefix .. "Growth"], 32)
        frame[prefix .. "Timers"] = Drop(page, "Timers", 500, 140, ON_OFF, "Timers", "Show remaining time on the icon.")
        frame[prefix .. "Timers"]:SetOnChange(function(id, text)
            AuraKind(kind).timers = id == "on"
            ApplyNow()
            Speak("Timers " .. text .. ".")
        end)
        place(frame[prefix .. "Timers"], 32)
        frame[prefix .. "Size"] = UF.Widgets.Stepper(page, "Icon size", 500)
        frame[prefix .. "Size"].minus:SetScript("OnClick", function()
            NudgeAura(kind, "size", -1, 10, 36, 2)
        end)
        frame[prefix .. "Size"].plus:SetScript("OnClick", function()
            NudgeAura(kind, "size", 1, 10, 36, 2)
        end)
        BindEdit(frame[prefix .. "Size"], function(text)
            ApplyAuraNumber(kind, "size", ParseNumber(text), 10, 36)
        end)
        place(frame[prefix .. "Size"], 32)
        frame[prefix .. "Max"] = UF.Widgets.Stepper(page, "How many", 500)
        frame[prefix .. "Max"].minus:SetScript("OnClick", function()
            NudgeAura(kind, "max", -1, 1, 16, 1)
        end)
        frame[prefix .. "Max"].plus:SetScript("OnClick", function()
            NudgeAura(kind, "max", 1, 1, 16, 1)
        end)
        BindEdit(frame[prefix .. "Max"], function(text)
            ApplyAuraNumber(kind, "max", ParseNumber(text), 1, 16)
        end)
        place(frame[prefix .. "Max"], 32)
    end
    local ap = Stack()
    AuraSection(auras, ap, "buff", "buffs", "Buffs")
    AuraSection(auras, ap, "debuff", "debuffs", "Debuffs")

    local indicators = BuildPage(scroll, "indicators", 1500)
    local ip = Stack()
    local ih = UF.Widgets.Header(indicators, "Status icons")
    ip(ih, 16)
    local function IndDrop(key, field, label, hint, defaultSize)
        defaultSize = defaultSize or 14
        frame[key] = Drop(indicators, label, 226, 88, ON_OFF, label, hint)
        frame[key]:SetOnChange(function(id, text)
            local cfg = UnitCfg()
            cfg.indicators = cfg.indicators or {}
            cfg.indicators[field] = id == "on"
            ApplyNow()
            Speak(label .. " " .. text .. ".")
        end)
        frame[key .. "Pos"] = Drop(indicators, "Position", 248, 90, UF.Pos.OPTIONS, label .. " position", "Where this icon sits on the frame.")
        frame[key .. "Pos"]:SetOnChange(function(id, text)
            local cfg = UnitCfg()
            cfg.indPos = cfg.indPos or {}
            cfg.indPos[field] = id
            ApplyNow()
            Speak(label .. " " .. text .. ".")
        end)
        local row = CreateFrame("Frame", nil, indicators)
        row:SetSize(500, 32)
        ip(row, 32)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        if UF.Indicators and UF.Indicators.PaintPreview then
            UF.Indicators.PaintPreview(icon, field)
        end
        frame[key .. "Icon"] = icon
        frame[key]:SetPoint("TOPLEFT", row, "TOPLEFT", 26, 0)
        frame[key .. "Pos"]:SetPoint("TOPLEFT", row, "TOPLEFT", 252, 0)
        frame[key .. "Size"] = UF.Widgets.Stepper(indicators, label .. " size", 500)
        frame[key .. "Size"].minus:SetScript("OnClick", function()
            NudgeIndSize(field, -2, label, defaultSize)
        end)
        frame[key .. "Size"].plus:SetScript("OnClick", function()
            NudgeIndSize(field, 2, label, defaultSize)
        end)
        BindEdit(frame[key .. "Size"], function(text)
            ApplyIndSize(field, ParseNumber(text), label)
        end)
        ip(frame[key .. "Size"], 32)
    end
    IndDrop("indCombat", "combat", "Combat", "Sword icon while the unit is in combat.", 14)
    IndDrop("indRest", "resting", "Resting", "Rest icon on you in an inn or city.", 14)
    IndDrop("indLeader", "leader", "Leader", "Crown when the unit is party or raid leader.", 12)
    IndDrop("indMark", "raidTarget", "Raid marker", "Skull, cross, and other target marks.", 18)
    IndDrop("indPvp", "pvp", "PvP", "Faction flag when PvP is on.", 16)
    IndDrop("indRole", "role", "Main tank or assist", "Tank and assist assignment icons.", 12)
    IndDrop("indGroupRole", "groupRole", "Tank, healer, DPS", "Group role icon for tank, healer, or damage.", 16)
    IndDrop("indRez", "resurrect", "Resurrect", "Shows when a resurrect is incoming.", 16)
    IndDrop("indReady", "ready", "Ready check", "Ready, not ready, or waiting.", 16)
    IndDrop("indElite", "elite", "Elite", "Gold mark for elite and boss units.", 20)
    IndDrop("indRare", "rare", "Rare", "Silver mark for rare units.", 18)
    IndDrop("indRareElite", "rareelite", "Rare elite", "Silver mark for rare-elite units.", 20)
    IndDrop("indHappy", "happiness", "Pet happiness", "Hunter pet mood on Classic.", 16)
    IndDrop("indPhase", "phase", "Phased", "Shows when the unit is in another phase or timeline.", 16)
    IndDrop("indOor", "oor", "Out of range", "Red mark when the unit is too far to interact.", 14)
    IndDrop("indQuest", "quest", "Quest", "Marks quest bosses and units named in your quest log.", 16)

    local more = BuildPage(scroll, "more")
    local mp = Stack()
    local mh = UF.Widgets.Header(more, "This unit")
    mp(mh, 16)
    frame.healDrop = Drop(more, "Incoming heals", 500, 180, ON_OFF, "Incoming heals", "Green overlay for heals already incoming.")
    frame.healDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.healPredict = id == "on"
        ApplyNow()
        Speak("Incoming heals " .. text .. ".")
    end)
    mp(frame.healDrop, 32)
    frame.absorbDrop = Drop(more, "Absorb shield", 500, 180, ON_OFF, "Absorb shield", "Gold overlay for shields. Later clients only.")
    frame.absorbDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.absorb = id == "on"
        ApplyNow()
        Speak("Absorb shield " .. text .. ".")
    end)
    mp(frame.absorbDrop, 32)
    frame.healAbsorbDrop = Drop(more, "Heal absorb", 500, 180, ON_OFF, "Heal absorb", "Purple overlay when heals are absorbed. Later clients only.")
    frame.healAbsorbDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.healAbsorb = id == "on"
        ApplyNow()
        Speak("Heal absorb " .. text .. ".")
    end)
    mp(frame.healAbsorbDrop, 32)
    frame.mouseDrop = Drop(more, "Mouseover highlight", 500, 180, ON_OFF, "Mouseover highlight", "Gold border when you hover this frame.")
    frame.mouseDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.mouseover = id == "on"
        ApplyNow()
        Speak("Mouseover highlight " .. text .. ".")
    end)
    mp(frame.mouseDrop, 32)
    frame.aggroDrop = Drop(more, "Aggro highlight", 500, 180, ON_OFF, "Aggro highlight", "Red border when the unit has threat.")
    frame.aggroDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.aggro = id == "on"
        ApplyNow()
        Speak("Aggro highlight " .. text .. ".")
    end)
    mp(frame.aggroDrop, 32)
    local ch = UF.Widgets.Header(more, "Cast bar")
    mp(ch, 16)
    frame.castDrop = Drop(more, "Cast bar", 500, 180, ON_OFF, "Cast bar", "Show the cast bar for this unit.")
    frame.castDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.castBar = id == "on"
        ApplyNow()
        Speak("Cast bar " .. text .. ".")
    end)
    mp(frame.castDrop, 32)
    frame.castAttachDrop = Drop(more, "Cast position", 500, 160, UF.Pos.CAST_ATTACH, "Cast position", "Below, above, inside, or free so you can drag it.")
    frame.castAttachDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.cast = UnitCfg().extra.cast or {}
        UnitCfg().extra.cast.attach = id
        ApplyNow()
        Speak("Cast bar " .. text .. ".")
    end)
    mp(frame.castAttachDrop, 32)
    frame.castWRow = UF.Widgets.Stepper(more, "Cast width", 500)
    frame.castWRow.minus:SetScript("OnClick", function()
        local v = CastCfg().w or 0
        if v <= 0 then
            v = 200
        end
        ApplyCastWidth(v - 10)
    end)
    frame.castWRow.plus:SetScript("OnClick", function()
        local v = CastCfg().w or 0
        if v <= 0 then
            v = 200
        end
        ApplyCastWidth(v + 10)
    end)
    BindEdit(frame.castWRow, function(text)
        local raw = type(text) == "string" and (text:match("^%s*(.-)%s*$") or "") or ""
        if raw == "" or string.lower(raw) == "match" then
            ApplyCastWidth(nil, true)
            return
        end
        ApplyCastWidth(ParseNumber(raw))
    end)
    mp(frame.castWRow, 32)
    frame.castHRow = UF.Widgets.Stepper(more, "Cast height", 500)
    frame.castHRow.minus:SetScript("OnClick", function()
        ApplyCastHeight((CastCfg().h or 12) - 1)
    end)
    frame.castHRow.plus:SetScript("OnClick", function()
        ApplyCastHeight((CastCfg().h or 12) + 1)
    end)
    BindEdit(frame.castHRow, function(text)
        ApplyCastHeight(ParseNumber(text))
    end)
    mp(frame.castHRow, 32)
    frame.rangeDrop = Drop(more, "Range fade", 500, 180, ON_OFF, "Range fade", "Fade the frame when the unit is out of range.")
    frame.rangeDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.rangeFade = id == "on"
        ApplyNow()
        Speak("Range fade " .. text .. ".")
    end)
    mp(frame.rangeDrop, 32)
    local look = UF.Widgets.Header(more, "All frames")
    mp(look, 16)
    frame.styleDrop = Drop(more, "Name style", 500, 140, {
        { id = "modern", label = "Accent name" },
        { id = "classic", label = "Class-colored name" },
    }, "Name style", "How the unit name is colored. Health color is on the General tab.")
    frame.styleDrop:SetOnChange(function(id, text)
        Profile().style = id
        ApplyNow()
        Speak("Name style " .. text .. ".")
    end)
    mp(frame.styleDrop, 32)
    frame.colorDrop = Drop(more, "Colors", 500, 140, {
        { id = "classic", label = "Classic Blizzard" },
        { id = "modern", label = "Modern" },
    }, "Class colors", "Classic client colors, or modern blue Shamans.")
    frame.colorDrop:SetOnChange(function(id, text)
        Profile().classColors = id
        ApplyNow()
        Speak("Class colors " .. text .. ".")
    end)
    mp(frame.colorDrop, 32)

    ShowTab("general")

    frame.lockBtn = UF.Widgets.Button(foot, "Unlock frames", 248, 28)
    frame.lockBtn:SetPoint("TOPLEFT", 10, -10)
    frame.lockBtn:SetScript("OnClick", function()
        CloseMenus()
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            return
        end
        local db = Profile()
        db.locked = not db.locked
        ApplyNow()
        Speak(db.locked and "Frames locked." or "Frames unlocked.")
    end)
    frame.snapBtn = UF.Widgets.Button(foot, "Use current positions", 248, 28)
    frame.snapBtn:SetPoint("TOPLEFT", 266, -10)
    frame.snapBtn:SetScript("OnClick", function()
        CloseMenus()
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            return
        end
        UF.DB.CaptureAndMaybeSnap(true)
        ApplyNow()
        Speak("Frames moved to your current UI positions.")
    end)
    frame.profileBox = CreateFrame("EditBox", FRAME_NAME .. "Profile", foot, "InputBoxTemplate")
    frame.profileBox:SetSize(140, 24)
    frame.profileBox:SetPoint("TOPLEFT", 16, -46)
    frame.profileBox:SetAutoFocus(false)
    frame.profileBox:SetMaxLetters(32)
    local saveBtn = UF.Widgets.Button(foot, "Save", 72, 26)
    saveBtn:SetPoint("LEFT", frame.profileBox, "RIGHT", 8, 0)
    saveBtn:SetScript("OnClick", function()
        CloseMenus()
        local ok, msg = UF.DB.SaveAs(frame.profileBox:GetText())
        Speak(msg)
        Refresh()
    end)
    local loadBtn = UF.Widgets.Button(foot, "Load", 72, 26)
    loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    loadBtn:SetScript("OnClick", function()
        CloseMenus()
        local ok, msg = UF.DB.Switch(frame.profileBox:GetText())
        Speak(msg)
        Refresh()
    end)
    local exportBtn = UF.Widgets.Button(foot, "Export", 72, 26)
    exportBtn:SetPoint("LEFT", loadBtn, "RIGHT", 6, 0)
    exportBtn:SetScript("OnClick", FillExport)
    frame.code = CreateFrame("EditBox", FRAME_NAME .. "Code", foot)
    frame.code:SetPoint("BOTTOMLEFT", 12, 22)
    frame.code:SetPoint("BOTTOMRIGHT", -12, 22)
    frame.code:SetHeight(20)
    frame.code:SetAutoFocus(false)
    frame.code:SetFontObject(ChatFontNormal)
    frame.code:SetTextColor(0.95, 0.90, 0.70, 1)
    frame.code:SetScript("OnEnterPressed", DoImport)
    frame.code:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    local help = UF.Widgets.Label(foot, 11, 0.55, 0.55, 0.58)
    help:SetPoint("BOTTOMLEFT", 12, 6)
    help:SetText("/bmguf    Key Bindings: BMG Unit Frames    Esc closes")

    frame:SetScript("OnShow", Refresh)
    Refresh()
    return frame
end

function Config.Toggle()
    local f = Build()
    if f:IsShown() then
        CloseMenus()
        f:Hide()
        Speak("Unit frame settings closed.")
    else
        f:Show()
        Speak("BMG Unit Frames. Player. General.")
    end
end

function Config.Open()
    local f = Build()
    if not f:IsShown() then
        f:Show()
        Speak("BMG Unit Frames settings.")
    end
end

function Config.ShowExport()
    Config.Open()
    FillExport()
end

function Config.Refresh()
    Refresh()
end
