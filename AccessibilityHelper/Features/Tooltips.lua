--[[
  Accessibility Helper — tooltip reader (Phase 4)
  Dual gather: TooltipData first, FontString fallback.
  Also reads Titan Panel (TitanPanelTooltip, LibQTip, LDB plugin frames).
  Full read, chunked TTS, re-press cancels.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Tooltips = AH.Tooltips or {}
local Tooltips = AH.Tooltips

-- Keybinds often hide GameTooltip on key-down before the binding runs.
-- Keep the last readable tip briefly so ReadHovered still works.
local lastTipText = nil
local lastTipAt = 0
local LAST_TIP_TTL = 8

local function IsSecret(v)
    if v == nil then
        return false
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        return ok and secret and true or false
    end
    return false
end

--- Coerce tooltip field to a plain string without erroring on secrets.
-- Never compare or mutate secret values (Midnight throws if tainted).
local function SafeStr(v)
    if v == nil then
        return ""
    end
    if IsSecret(v) then
        return ""
    end
    if type(v) == "string" then
        return v
    end
    if type(v) == "number" or type(v) == "boolean" then
        if IsSecret(v) then
            return ""
        end
        return tostring(v)
    end
    local ok, s = pcall(tostring, v)
    if not ok or IsSecret(s) or type(s) ~= "string" then
        return ""
    end
    if s == "userdata" then
        return ""
    end
    return s
end

local function Trim(s)
    if type(s) ~= "string" or IsSecret(s) then
        return ""
    end
    local ok, trimmed = pcall(function()
        return s:gsub("^%s+", ""):gsub("%s+$", "")
    end)
    if not ok or type(trimmed) ~= "string" or IsSecret(trimmed) then
        return ""
    end
    return trimmed
end

local function NonEmpty(s)
    s = Trim(SafeStr(s))
    if type(s) ~= "string" or IsSecret(s) then
        return nil
    end
    if s == "" then
        return nil
    end
    return s
end

local function FsText(fs)
    if not fs then
        return nil
    end
    local okShown, shown = pcall(function()
        return fs:IsShown()
    end)
    if okShown and shown == false then
        return nil
    end
    local ok, t = pcall(function()
        return fs:GetText()
    end)
    if not ok then
        return nil
    end
    return NonEmpty(t)
end

local function TooltipsEnabled()
    if not (AH.DB and AH.DB.Get) then
        return true
    end
    local sv = AH.DB.Get()
    return sv.tooltipsEnabled ~= false
end

local function TitanTipsEnabled()
    if not TooltipsEnabled() then
        return false
    end
    if not (AH.DB and AH.DB.Get) then
        return true
    end
    local sv = AH.DB.Get()
    return sv.tooltipTitanEnabled ~= false
end

local function CompareEnabled()
    if not (AH.DB and AH.DB.Get) then
        return true
    end
    local sv = AH.DB.Get()
    return sv.tooltipCompare ~= false
end

local function TooltipIsUsable(tip)
    if not tip then
        return false
    end
    local okShown, shown = pcall(function()
        return tip:IsShown()
    end)
    if not okShown or not shown then
        return false
    end
    return true
end

--- FontString line gather (Classic + fallback).
local function GatherFromFontStrings(tip)
    local parts = {}
    local name = tip.GetName and tip:GetName()
    if not name then
        return parts, false
    end
    local okNum, num = pcall(function()
        return tip:NumLines() or 0
    end)
    if not okNum or type(num) ~= "number" or num < 1 then
        return parts, false
    end
    local any = false
    for i = 1, num do
        local lt = FsText(_G[name .. "TextLeft" .. i])
        local rt = FsText(_G[name .. "TextRight" .. i])
        if lt and rt then
            parts[#parts + 1] = lt .. ", " .. rt
            any = true
        elseif lt then
            parts[#parts + 1] = lt
            any = true
        elseif rt then
            parts[#parts + 1] = rt
            any = true
        end
    end
    return parts, any
end

local function ExtractLineFromTooltipDataLine(line)
    if type(line) ~= "table" then
        return NonEmpty(line)
    end
    local lt = NonEmpty(line.leftText or line.LeftText or line.textLeft or line.leftString)
    local rt = NonEmpty(line.rightText or line.RightText or line.textRight or line.rightString)
    if lt and rt then
        return lt .. ", " .. rt
    end
    return lt or rt
end

--- Structured TooltipData gather (10.0.2+ / modern clients).
local function GatherFromTooltipData(tip)
    local parts = {}
    if not tip or not tip.GetTooltipData then
        return parts, false, false
    end
    local ok, data = pcall(function()
        return tip:GetTooltipData()
    end)
    if not ok or type(data) ~= "table" then
        return parts, false, not ok -- secretError-ish
    end
    local lines = data.lines
    if type(lines) ~= "table" then
        return parts, false, false
    end
    local any = false
    local secretBlocked = false
    for i = 1, #lines do
        local okLine, chunk = pcall(ExtractLineFromTooltipDataLine, lines[i])
        if okLine and chunk then
            parts[#parts + 1] = chunk
            any = true
        elseif not okLine then
            secretBlocked = true
        end
    end
    -- Also try hyperlink title if lines empty but hyperlink present.
    if not any then
        local h = NonEmpty(data.hyperlink)
        if h then
            parts[#parts + 1] = h
            any = true
        end
    end
    return parts, any, secretBlocked
end

--- LibQTip-1.0 cell text (Titan LDB plugins and some Titan extras).
local function IsLibQTipFrame(tip)
    return type(tip) == "table"
        and type(tip.GetLineCount) == "function"
        and type(tip.lines) == "table"
        and type(tip.columns) == "table"
end

local function GatherFromLibQTip(tip)
    local parts = {}
    if not IsLibQTipFrame(tip) then
        return parts, false
    end
    local okLines, nLines = pcall(function()
        return tip:GetLineCount() or 0
    end)
    local okCols, nCols = pcall(function()
        return tip:GetColumnCount() or 0
    end)
    if not okLines or type(nLines) ~= "number" or nLines < 1 then
        return parts, false
    end
    if not okCols or type(nCols) ~= "number" or nCols < 1 then
        nCols = 1
    end
    local any = false
    for i = 1, nLines do
        local line = tip.lines[i]
        local cells = line and line.cells
        if type(cells) == "table" then
            local row = {}
            for j = 1, nCols do
                local cell = cells[j]
                local fs = cell and (cell.fontString or cell.FontString)
                local t = FsText(fs)
                if not t and cell then
                    t = FsText(cell)
                end
                if t then
                    row[#row + 1] = t
                end
            end
            if #row > 0 then
                parts[#parts + 1] = table.concat(row, ", ")
                any = true
            end
        end
    end
    return parts, any
end

--- Visible FontString walk for unnamed / custom LDB tooltip frames.
local function GatherFromRegions(frame)
    local parts = {}
    if not frame then
        return parts, false
    end
    local seen = {}
    local function Walk(obj, depth)
        if not obj or depth > 8 or seen[obj] then
            return
        end
        seen[obj] = true
        local okType, objType = pcall(function()
            if obj.GetObjectType then
                return obj:GetObjectType()
            end
            return nil
        end)
        if okType and objType == "FontString" then
            local t = FsText(obj)
            if t then
                parts[#parts + 1] = t
            end
            return
        end
        local okReg, regions = pcall(function()
            if obj.GetRegions then
                return { obj:GetRegions() }
            end
            return nil
        end)
        if okReg and type(regions) == "table" then
            for i = 1, #regions do
                Walk(regions[i], depth + 1)
            end
        end
        local okKids, children = pcall(function()
            if obj.GetChildren then
                return { obj:GetChildren() }
            end
            return nil
        end)
        if okKids and type(children) == "table" then
            for i = 1, #children do
                Walk(children[i], depth + 1)
            end
        end
    end
    Walk(frame, 0)
    return parts, #parts > 0
end

local function GetLibQTip()
    if type(LibStub) ~= "function" and type(LibStub) ~= "table" then
        return nil
    end
    local ok, lib = pcall(LibStub, "LibQTip-1.0", true)
    if ok and type(lib) == "table" and type(lib.IterateTooltips) == "function" then
        return lib
    end
    return nil
end

local function JoinParts(parts)
    if not parts or #parts == 0 then
        return ""
    end
    return table.concat(parts, ". ")
end

local function GatherOneTooltip(tip)
    local parts, any, secretBlocked = GatherFromTooltipData(tip)
    if any then
        return JoinParts(parts), "data", secretBlocked
    end
    local fparts, fany = GatherFromFontStrings(tip)
    if fany then
        return JoinParts(fparts), "font", secretBlocked
    end
    local qparts, qany = GatherFromLibQTip(tip)
    if qany then
        return JoinParts(qparts), "qtip", secretBlocked
    end
    local rparts, rany = GatherFromRegions(tip)
    if rany then
        return JoinParts(rparts), "regions", secretBlocked
    end
    return "", "none", secretBlocked
end

local function GetCompareTooltips(mainTip)
    local list = {}
    if mainTip and mainTip.shoppingTooltips then
        for i = 1, #mainTip.shoppingTooltips do
            list[#list + 1] = mainTip.shoppingTooltips[i]
        end
    end
    if ShoppingTooltip1 then
        list[#list + 1] = ShoppingTooltip1
    end
    if ShoppingTooltip2 then
        list[#list + 1] = ShoppingTooltip2
    end
    if ShoppingTooltip3 then
        list[#list + 1] = ShoppingTooltip3
    end
    -- Deduplicate by identity.
    local seen = {}
    local out = {}
    for i = 1, #list do
        local t = list[i]
        if t and not seen[t] then
            seen[t] = true
            out[#out + 1] = t
        end
    end
    return out
end

--- Plain-text summary set by Blind Mice / other addons when Blizzard tooltip
--- lines are secret or empty (e.g. Cooldown Assist settings rows).
local function GetAddonSpeakText(tip)
    if not tip then
        return nil
    end
    local t = tip.AccessibilityHelperSpeakText
    if type(t) ~= "string" or IsSecret(t) then
        return nil
    end
    t = Trim(t)
    if type(t) ~= "string" or IsSecret(t) or t == "" then
        return nil
    end
    return t
end

local function MouseFrames()
    local list = {}
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and type(foci) == "table" then
            for i = 1, #foci do
                if foci[i] then
                    list[#list + 1] = foci[i]
                end
            end
        end
    end
    if #list == 0 and GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        if ok and f then
            list[1] = f
        end
    end
    return list
end

local function IsTitanRelatedFrame(frame)
    local guard = 0
    while frame and guard < 12 do
        guard = guard + 1
        local okName, name = pcall(function()
            return frame.GetName and frame:GetName()
        end)
        if okName and type(name) == "string" then
            if name:find("TitanPanel", 1, true) or name:find("TitanBar", 1, true) then
                return true
            end
        end
        if type(frame.registry) == "table" and frame.registry.id then
            return true
        end
        if type(frame.ldb_obj) == "table" then
            return true
        end
        local okParent, parent = pcall(function()
            return frame.GetParent and frame:GetParent()
        end)
        if not okParent then
            break
        end
        frame = parent
    end
    return false
end

local function HoveringTitanPlugin()
    if not TitanTipsEnabled() then
        return false
    end
    local foci = MouseFrames()
    for i = 1, #foci do
        if IsTitanRelatedFrame(foci[i]) then
            return true
        end
    end
    return false
end

local function CandidateTooltips()
    local tips = {}
    local function add(t)
        if t and TooltipIsUsable(t) then
            tips[#tips + 1] = t
        end
    end
    add(GameTooltip)
    add(ItemRefTooltip)
    add(EmbeddedItemTooltip)
    if GameTooltip and GameTooltip.ItemTooltip then
        add(GameTooltip.ItemTooltip.Tooltip)
    end
    if TitanTipsEnabled() then
        add(TitanPanelTooltip)
        if type(TitanPlugins) == "table" then
            for _, plugin in pairs(TitanPlugins) do
                if type(plugin) == "table" and plugin.tooltipDisplayFrame then
                    add(plugin.tooltipDisplayFrame)
                end
            end
        end
        local qtip = GetLibQTip()
        if qtip then
            for _, tip in qtip:IterateTooltips() do
                add(tip)
            end
        end
    end
    return tips
end

local function TipHasReadableContent(tip)
    if not tip then
        return false
    end
    if GetAddonSpeakText(tip) then
        return true
    end
    local text = GatherOneTooltip(tip)
    return text ~= ""
end

local function IsTitanSourceTip(tip)
    if not tip then
        return false
    end
    if tip == TitanPanelTooltip then
        return true
    end
    if IsLibQTipFrame(tip) then
        return true
    end
    if type(TitanPlugins) == "table" then
        for _, plugin in pairs(TitanPlugins) do
            if type(plugin) == "table" and plugin.tooltipDisplayFrame == tip then
                return true
            end
        end
    end
    return false
end

local function PickPrimaryTooltip()
    local tips = CandidateTooltips()
    local function firstReadable(pred)
        for i = 1, #tips do
            if pred(tips[i]) and TipHasReadableContent(tips[i]) then
                return tips[i]
            end
        end
        return nil
    end

    -- Hovering a Titan plugin: prefer Titan / LibQTip / LDB frames over GameTooltip.
    if HoveringTitanPlugin() then
        local titanTip = firstReadable(IsTitanSourceTip)
        if titanTip then
            return titanTip
        end
    end

    -- Prefer GameTooltip when it has content (including addon speak text).
    local gameTip = firstReadable(function(tip)
        return tip == GameTooltip
    end)
    if gameTip then
        return gameTip
    end

    local anyTip = firstReadable(function()
        return true
    end)
    if anyTip then
        return anyTip
    end

    -- Last resort: shown frame even if gather failed (may be secret).
    if TooltipIsUsable(GameTooltip) then
        return GameTooltip
    end
    if TitanTipsEnabled() and TooltipIsUsable(TitanPanelTooltip) then
        return TitanPanelTooltip
    end
    return tips[1]
end

local function Now()
    return (GetTime and GetTime()) or 0
end

local function CacheTipText(text)
    if type(text) == "string" and not IsSecret(text) and text ~= "" then
        lastTipText = text
        lastTipAt = Now()
    end
end

local function GetCachedTipText()
    if type(lastTipText) ~= "string" or lastTipText == "" then
        return nil
    end
    if (Now() - lastTipAt) > LAST_TIP_TTL then
        return nil
    end
    return lastTipText
end

local function ResolveTipText(tip)
    if not tip then
        return "", "none", false
    end
    local text, source, secretBlocked = GatherOneTooltip(tip)
    local addonText = GetAddonSpeakText(tip)
    if (text == "" or secretBlocked) and addonText then
        return addonText, "addon", false
    end
    return text or "", source or "none", secretBlocked and true or false
end

local function RefreshCacheFromTip(tip)
    if not tip or not TooltipIsUsable(tip) then
        return
    end
    local text = ResolveTipText(tip)
    if text ~= "" then
        CacheTipText(text)
    end
end

local hookedTips = {}
local processorHooked = false
local extraCacheFrame = nil

local function HookTipCache(tip)
    if not tip or not tip.HookScript or hookedTips[tip] then
        return
    end
    hookedTips[tip] = true
    pcall(function()
        tip:HookScript("OnShow", function(self)
            RefreshCacheFromTip(self)
        end)
        tip:HookScript("OnUpdate", function(self, elapsed)
            self._ahTipAccum = (self._ahTipAccum or 0) + (elapsed or 0)
            if self._ahTipAccum < 0.15 then
                return
            end
            self._ahTipAccum = 0
            RefreshCacheFromTip(self)
        end)
    end)
end

local function InstallTipHooks()
    HookTipCache(GameTooltip)
    HookTipCache(ItemRefTooltip)
    if TitanTipsEnabled() then
        HookTipCache(TitanPanelTooltip)
    end
    if not processorHooked then
        processorHooked = true
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
            local function postCall(tooltip)
                if tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == TitanPanelTooltip then
                    RefreshCacheFromTip(tooltip)
                end
            end
            for _, dataType in pairs(Enum.TooltipDataType) do
                if type(dataType) == "number" then
                    pcall(TooltipDataProcessor.AddTooltipPostCall, dataType, postCall)
                end
            end
        end
    end
    -- LibQTip / custom LDB frames are not GameTooltip; keep a light cache while they are shown.
    if not extraCacheFrame then
        extraCacheFrame = CreateFrame("Frame")
        extraCacheFrame:SetScript("OnUpdate", function(self, elapsed)
            self._ahTipAccum = (self._ahTipAccum or 0) + (elapsed or 0)
            if self._ahTipAccum < 0.2 then
                return
            end
            self._ahTipAccum = 0
            if not TitanTipsEnabled() then
                return
            end
            if not (TitanPanelTooltip or TitanPlugins or GetLibQTip()) then
                return
            end
            local tip = PickPrimaryTooltip()
            RefreshCacheFromTip(tip)
        end)
    end
end

InstallTipHooks()

--- Read the hovered / shown tooltip via TTS (full text).
-- Re-press while a tooltip read is speaking cancels it.
function Tooltips.ReadHovered()
    if not TooltipsEnabled() then
        if AH.Speech then
            AH.Speech.Say("Tooltip reading is disabled.", AH.Speech.PRIORITY_LOW)
        end
        return
    end

    InstallTipHooks()

    -- Re-press cancels an in-progress tooltip/nav read.
    if Tooltips._readingActive then
        Tooltips._readingActive = false
        if AH.Speech and AH.Speech.ClearNavQueue then
            AH.Speech.ClearNavQueue()
        end
        return
    end

    -- Stop any prior nav line before starting a new tooltip read (no flush lock).
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end

    local tip = PickPrimaryTooltip()
    local text, source, secretBlocked = "", "none", false
    if tip then
        text, source, secretBlocked = ResolveTipText(tip)
    end

    if text == "" then
        local cached = GetCachedTipText()
        if cached then
            text = cached
            source = "cache"
            secretBlocked = false
        end
    end

    if text == "" then
        if secretBlocked then
            if AH.Speech then
                AH.Speech.Say("Tooltip text is unavailable right now.", AH.Speech.PRIORITY_NAV)
            end
        else
            if AH.Speech then
                AH.Speech.Say("No tooltip is showing.", AH.Speech.PRIORITY_NAV)
            end
        end
        return
    end

    local full = text

    if tip and CompareEnabled() then
        local compares = GetCompareTooltips(tip)
        for i = 1, #compares do
            local ctip = compares[i]
            if ctip ~= tip and TooltipIsUsable(ctip) then
                local ctext = ResolveTipText(ctip)
                if ctext ~= "" then
                    full = full .. ". Compared to: " .. ctext
                end
            end
        end
    end

    CacheTipText(full)
    Tooltips._readingActive = true

    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(full, AH.Speech.PRIORITY_NAV)
        -- Clear reading flag after a short window so a later press can start a new read
        -- even if utterance-end callbacks are unavailable.
        if C_Timer and C_Timer.After then
            C_Timer.After(math.min(20, math.max(1.5, #full * 0.04)), function()
                Tooltips._readingActive = false
            end)
        else
            Tooltips._readingActive = false
        end
    else
        Tooltips._readingActive = false
        print("|cff66ccff[Helper]|r " .. full)
    end
end
