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

local function SectionsOn()
    if not (AH.DB and AH.DB.Get) then
        return true
    end
    local sv = AH.DB.Get()
    return sv.tooltipAddonSections ~= false
end

local function OwnerBlocked(tip)
    if not tip or not tip.GetOwner or not (AH.DB and AH.DB.Get) then
        return false
    end
    local sv = AH.DB.Get()
    if type(sv.tooltipAddons) ~= "table" then
        return false
    end
    local ok, owner = pcall(tip.GetOwner, tip)
    if not ok or not owner or not owner.GetName then
        return false
    end
    local named, frameName = pcall(owner.GetName, owner)
    if not named or type(frameName) ~= "string" or frameName == "" then
        return false
    end
    for addon, enabled in pairs(sv.tooltipAddons) do
        if enabled == false and type(addon) == "string" and string.find(frameName, addon, 1, true) == 1 then
            return true
        end
    end
    return false
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
-- Uses both named globals (GameTooltipTextLeft1) and tooltip fields (tip.TextLeft1).
local function LeftFS(tip, i)
    local field = tip and tip["TextLeft" .. i]
    if field then
        return field
    end
    local name = tip and tip.GetName and tip:GetName()
    if type(name) == "string" and name ~= "" then
        return _G[name .. "TextLeft" .. i]
    end
    return nil
end

local function RightFS(tip, i)
    local field = tip and tip["TextRight" .. i]
    if field then
        return field
    end
    local name = tip and tip.GetName and tip:GetName()
    if type(name) == "string" and name ~= "" then
        return _G[name .. "TextRight" .. i]
    end
    return nil
end

local function TalentChrome(text)
    local lower = string.lower(text)
    if lower == "specialization" or lower == "abilities" or lower == "traits" then
        return true
    end
    if string.find(lower, "specialization", 1, true) and string.find(lower, "abilities", 1, true) and string.find(lower, "traits", 1, true) then
        return true
    end
    return false
end

local function GatherFromFontStrings(tip)
    local parts = {}
    if not tip then
        return parts, false
    end
    local num = 0
    local okNum, n = pcall(function()
        local count = tip:NumLines()
        if type(count) ~= "number" then
            return 0
        end
        if count > 0 then
            return count
        end
        return 0
    end)
    if okNum and type(n) == "number" and n > 0 then
        num = n
    end
    if num < 1 then
        num = 20
    else
        num = math.max(num, 8)
    end
    local any = false
    local emptyRun = 0
    for i = 1, num do
        local lt = FsText(LeftFS(tip, i))
        local rt = FsText(RightFS(tip, i))
        if lt and rt then
            parts[#parts + 1] = lt .. ", " .. rt
            any = true
            emptyRun = 0
        elseif lt then
            parts[#parts + 1] = lt
            any = true
            emptyRun = 0
        elseif rt then
            parts[#parts + 1] = rt
            any = true
            emptyRun = 0
        else
            emptyRun = emptyRun + 1
            if num == 20 and emptyRun >= 3 and i >= 3 then
                break
            end
        end
    end
    return parts, any
end

local function ExtractLineFromTooltipDataLine(line)
    if type(line) ~= "table" then
        return NonEmpty(line)
    end
    local function Field(t, key)
        if type(t) ~= "table" then
            return nil
        end
        local ok, value = pcall(function()
            return t[key]
        end)
        if not ok then
            return nil
        end
        return NonEmpty(value)
    end
    local lt = Field(line, "leftText")
    if not lt then
        lt = Field(line, "LeftText")
    end
    if not lt then
        lt = Field(line, "textLeft")
    end
    if not lt then
        lt = Field(line, "leftString")
    end
    if not lt then
        lt = Field(line, "text")
    end
    if not lt and type(line.args) == "table" then
        for i = 1, #line.args do
            local arg = line.args[i]
            if type(arg) == "table" then
                lt = Field(arg, "stringVal")
                if not lt then
                    lt = Field(arg, "text")
                end
                if not lt then
                    lt = Field(arg, "leftText")
                end
            elseif type(arg) == "string" then
                lt = NonEmpty(arg)
            end
            if lt then
                break
            end
        end
    end
    local rt = Field(line, "rightText")
    if not rt then
        rt = Field(line, "RightText")
    end
    if not rt then
        rt = Field(line, "textRight")
    end
    if not rt then
        rt = Field(line, "rightString")
    end
    if lt and TalentChrome(lt) then
        lt = nil
    end
    if rt and TalentChrome(rt) then
        rt = nil
    end
    if lt and rt then
        local both = lt .. ", " .. rt
        if TalentChrome(both) then
            return nil
        end
        return both
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
    local function takeLine(line)
        local okLine, chunk = pcall(ExtractLineFromTooltipDataLine, line)
        if okLine and chunk then
            parts[#parts + 1] = chunk
            any = true
        elseif not okLine then
            secretBlocked = true
        end
    end
    for i = 1, #lines do
        takeLine(lines[i])
    end
    if not any then
        for _, line in pairs(lines) do
            takeLine(line)
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
            if t and not TalentChrome(t) then
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

local function MergePartLists(lists)
    local out = {}
    local seen = {}
    for li = 1, #lists do
        local parts = lists[li]
        if type(parts) == "table" then
            for i = 1, #parts do
                local s = parts[i]
                if type(s) == "string" and s ~= "" and not seen[s] then
                    seen[s] = true
                    out[#out + 1] = s
                end
            end
        end
    end
    return out
end

local function GatherOneTooltip(tip)
    local dparts, dany, secretBlocked = GatherFromTooltipData(tip)
    local fparts, fany = GatherFromFontStrings(tip)
    local qparts, qany = {}, false
    if SectionsOn() then
        qparts, qany = GatherFromLibQTip(tip)
    end
    local rparts, rany = GatherFromRegions(tip)
    local merged = MergePartLists({ dparts, fparts, qparts, rparts })
    local kept = {}
    for i = 1, #merged do
        if not TalentChrome(merged[i]) then
            kept[#kept + 1] = merged[i]
        end
    end
    if #kept == 0 then
        return "", "none", secretBlocked
    end
    local src = "merged"
    if dany then
        src = "data"
    elseif fany then
        src = "font"
    elseif qany then
        src = "qtip"
    elseif rany then
        src = "regions"
    end
    return JoinParts(kept), src, secretBlocked
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

local function NameFromSpellID(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then
            n = NonEmpty(n)
            if n then
                return n
            end
        end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then
            return NonEmpty(n)
        end
    end
    return nil
end

local function NameFromDefinitionID(id)
    if type(id) ~= "number" or not (C_Traits and C_Traits.GetDefinitionInfo) then
        return nil
    end
    local ok, info = pcall(C_Traits.GetDefinitionInfo, id)
    if not ok or type(info) ~= "table" then
        return nil
    end
    local n = NonEmpty(info.overrideName)
    if n then
        return n
    end
    return NameFromSpellID(info.spellID)
end

local function NameFromMouseFocus()
    local foci = MouseFrames()
    for i = 1, #foci do
        local f = foci[i]
        local guard = 0
        while f and guard < 10 do
            guard = guard + 1
            local n = FsText(f.Name) or FsText(f.Label) or FsText(f.Title)
            if n then
                return n
            end
            n = NonEmpty(f.name) or NonEmpty(f.talentName) or NonEmpty(f.spellName) or NonEmpty(f.overrideName)
            if n and (n:find("Frame", 1, true) or n:find("Button", 1, true) or n:find(".", 1, true)) then
                n = nil
            end
            if n then
                return n
            end
            if f.GetSpellID then
                local ok, id = pcall(f.GetSpellID, f)
                if ok then
                    n = NameFromSpellID(id)
                    if n then
                        return n
                    end
                end
            end
            n = NameFromSpellID(f.spellID) or NameFromDefinitionID(f.definitionID)
            if not n and type(f.entryInfo) == "table" then
                n = NonEmpty(f.entryInfo.overrideName) or NameFromDefinitionID(f.entryInfo.definitionID)
            end
            if not n and type(f.nodeInfo) == "table" then
                n = NameFromDefinitionID(f.nodeInfo.definitionID)
            end
            if n then
                return n
            end
            local ok, parent = pcall(function()
                return f.GetParent and f:GetParent()
            end)
            if not ok then
                break
            end
            f = parent
        end
    end
    return nil
end

local function GetTooltipTitle(tip)
    if not tip then
        return nil
    end
    if tip.GetSpell then
        local ok, name, _, spellID = pcall(function()
            return tip:GetSpell()
        end)
        if ok then
            local n = NonEmpty(name) or NameFromSpellID(spellID)
            if n then
                return n
            end
        end
    end
    if TooltipUtil and TooltipUtil.GetDisplayedSpell then
        local ok, spellID = pcall(TooltipUtil.GetDisplayedSpell, tip)
        if ok then
            local n = NameFromSpellID(spellID)
            if n then
                return n
            end
            if type(spellID) == "table" then
                n = NameFromSpellID(spellID.spellID or spellID.id) or NonEmpty(spellID.name)
                if n then
                    return n
                end
            end
        end
    end
    if tip.GetItem then
        local ok, name = pcall(function()
            return tip:GetItem()
        end)
        if ok then
            local n = NonEmpty(name)
            if n then
                return n
            end
        end
    end
    if tip.GetUnit then
        local ok, name = pcall(function()
            return tip:GetUnit()
        end)
        if ok then
            local n = NonEmpty(name)
            if n then
                return n
            end
        end
    end
    if tip.GetTooltipData then
        local ok, data = pcall(function()
            return tip:GetTooltipData()
        end)
        if ok and type(data) == "table" then
            local n = NonEmpty(data.name) or NameFromSpellID(data.id) or NameFromDefinitionID(data.id)
            if n then
                return n
            end
            if type(data.hyperlink) == "string" then
                n = NonEmpty((data.hyperlink:match("%[(.-)%]")))
                if n then
                    return n
                end
            end
        end
    end
    return NameFromMouseFocus()
end

local function PrependTitle(text, title)
    if type(title) ~= "string" or title == "" then
        return text or ""
    end
    if type(text) ~= "string" or text == "" then
        return title
    end
    if text == title then
        return text
    end
    local start = text:sub(1, #title)
    if start == title then
        return text
    end
    local ltext, ltitle = text:lower(), title:lower()
    if ltext:sub(1, #ltitle) == ltitle then
        return text
    end
    if ltext:find(ltitle, 1, true) then
        return text
    end
    return title .. ". " .. text
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
    add(PrimaryTooltip)
    add(ShoppingTooltip1)
    add(ShoppingTooltip2)
    local foci = MouseFrames()
    for i = 1, #foci do
        local f = foci[i]
        local guard = 0
        while f and guard < 8 do
            guard = guard + 1
            if f ~= UIParent and f ~= WorldFrame then
                local nm = ""
                if f.GetName then
                    local okName, frameName = pcall(function()
                        return f:GetName()
                    end)
                    if okName and type(frameName) == "string" then
                        nm = frameName
                    end
                end
                local kindOk, kind = pcall(function()
                    return f.GetObjectType and f:GetObjectType()
                end)
                if (kindOk and kind == "GameTooltip") or f.TextLeft1 or f.GetTooltipData or nm:find("Tooltip", 1, true) or (SectionsOn() and IsLibQTipFrame(f)) then
                    add(f)
                end
            end
            local ok, parent = pcall(function()
                return f.GetParent and f:GetParent()
            end)
            if not ok then
                break
            end
            f = parent
        end
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
    local addonText = SectionsOn() and GetAddonSpeakText(tip) or nil
    if (text == "" or secretBlocked) and addonText then
        text = addonText
        source = "addon"
        secretBlocked = false
    end
    text = PrependTitle(text or "", GetTooltipTitle(tip))
    return text or "", source or "none", secretBlocked and true or false
end

-- Window switches keep their written description here. The read key hides
-- GameTooltip before the binding runs, so the description has to be stored.
local hoverText = nil
local hoverOwner = nil
local tippedWidgets = {}

function Tooltips.WatchTip(widget, text)
    if not widget or type(text) ~= "string" or text == "" then
        return
    end
    widget._ahTipText = text
    if not widget._ahTipWatch then
        widget._ahTipWatch = true
        tippedWidgets[#tippedWidgets + 1] = widget
    end
end

local function WidgetVisible(widget)
    if not widget or not widget.IsVisible then
        return false
    end
    local shown = false
    local ok = pcall(function()
        if widget:IsVisible() then
            shown = true
        end
    end)
    return ok and shown
end

local function TipUnderMouse()
    for i = #tippedWidgets, 1, -1 do
        local widget = tippedWidgets[i]
        if WidgetVisible(widget) then
            local over = false
            local ok = pcall(function()
                if widget.IsMouseOver and widget:IsMouseOver() then
                    over = true
                elseif MouseIsOver and MouseIsOver(widget) then
                    over = true
                end
            end)
            if ok and over then
                local text = widget._ahTipText
                if type(text) == "string" and text ~= "" then
                    return text
                end
            end
        end
    end
    return nil
end

local function MouseOverHelper()
    local win = AccessibilityHelperWindow
    if not win or not win.IsVisible or not win.IsMouseOver then
        return false
    end
    local over = false
    local ok = pcall(function()
        if win:IsVisible() and win:IsMouseOver() then
            over = true
        end
    end)
    return ok and over
end

function Tooltips.ForgetWindowTip()
    hoverOwner = nil
    hoverText = nil
    lastTipText = nil
    lastTipAt = 0
    pcall(function()
        if not GameTooltip or not GameTooltip.GetOwner or not GameTooltip.Hide then
            return
        end
        local owner = GameTooltip:GetOwner()
        if owner and owner._ahTipText then
            GameTooltip:Hide()
        end
    end)
end

function Tooltips.SetHoverText(owner, text)
    if type(text) ~= "string" or IsSecret(text) or text == "" then
        return
    end
    hoverOwner = owner
    hoverText = text
    CacheTipText(text)
end

function Tooltips.ClearHoverText(owner)
    if owner == nil or hoverOwner == owner then
        hoverOwner = nil
        hoverText = nil
    end
end

function Tooltips.GetHoverText()
    if hoverOwner and not WidgetVisible(hoverOwner) then
        hoverOwner = nil
        hoverText = nil
        return nil
    end
    if type(hoverText) ~= "string" or IsSecret(hoverText) or hoverText == "" then
        return nil
    end
    return hoverText
end

local function BuildSpeakText(tip, allowCache)
    local text, _, secretBlocked = "", nil, false
    if tip then
        text, _, secretBlocked = ResolveTipText(tip)
    end
    if text == "" and allowCache ~= false then
        local cached = GetCachedTipText()
        if cached then
            text = cached
            secretBlocked = false
        end
    end
    if text == "" then
        return "", secretBlocked
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
    return full, false
end

local function PlainLineText(fs)
    if not fs or not fs.GetText then
        return nil
    end
    local ok, t = pcall(fs.GetText, fs)
    if not ok or type(t) ~= "string" then
        return nil
    end
    t = Trim(t)
    if t == "" or TalentChrome(t) then
        return nil
    end
    return t
end

local function PlainTipText(tip)
    if not tip then
        return ""
    end
    local parts = {}
    local emptyRun = 0
    for i = 1, 30 do
        local lt = PlainLineText(LeftFS(tip, i))
        local rt = PlainLineText(RightFS(tip, i))
        local line = nil
        if lt and rt then
            line = lt .. ", " .. rt
        elseif lt or rt then
            line = lt or rt
        end
        if line and TalentChrome(line) then
            line = nil
        end
        if line then
            parts[#parts + 1] = line
            emptyRun = 0
        else
            emptyRun = emptyRun + 1
            if emptyRun >= 2 and i >= 2 then
                break
            end
        end
    end
    if #parts > 1 then
        local last = parts[#parts]
        if type(last) == "string" and string.find(last, "^%d+$") then
            parts[#parts] = nil
        end
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, ". ")
end

local function RefreshCacheFromTip(tip)
    if not tip or not TooltipIsUsable(tip) then
        return
    end
    local text = ""
    local okText, resolved = pcall(ResolveTipText, tip)
    if okText and type(resolved) == "string" then
        text = resolved
    end
    if text == "" then
        local okPlain, plain = pcall(PlainTipText, tip)
        if okPlain and type(plain) == "string" then
            text = plain
        end
    end
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

pcall(InstallTipHooks)

--- Current tooltip text under the mouse, without speaking. Empty if none is showing.
function Tooltips.GetHoveredText()
    InstallTipHooks()
    local tip = PickPrimaryTooltip()
    if not tip or not TooltipIsUsable(tip) then
        return ""
    end
    local full = BuildSpeakText(tip, false)
    return full or ""
end

--- Read the hovered / shown tooltip via TTS (full text).
-- One press reads. A later press, while it is still speaking, stops it.
-- Key-repeat while the key is held does not start the line again.
function Tooltips.ReadHovered()
    local now = 0
    if GetTime then
        local okNow, t = pcall(GetTime)
        if okNow and type(t) == "number" then
            now = t
        end
    end
    if type(Tooltips._lastCall) == "number" and type(now) == "number" then
        local okGap, gap = pcall(function()
            return now - Tooltips._lastCall
        end)
        if okGap and type(gap) == "number" and gap >= 0 and gap < 1.25 then
            return
        end
    end
    Tooltips._lastCall = now

    local stillSpeaking = AH.Speech and AH.Speech.IsNavBusy and AH.Speech.IsNavBusy()
    if Tooltips._readingText and stillSpeaking then
        Tooltips._readingText = nil
        if AH.Speech.ClearNavQueue then
            AH.Speech.ClearNavQueue()
        end
        return
    end

    if not TooltipsEnabled() then
        Tooltips._readingText = nil
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say("Tooltip reading is disabled.", AH.Speech.PRIORITY_NAV, { noEcho = true })
        end
        return
    end

    local text = TipUnderMouse()
    local overWindow = MouseOverHelper()
    if overWindow then
        if not text or text == "" then
            text = Tooltips.GetHoverText()
        end
        if not text or text == "" then
            text = "No tooltip is showing."
        end
    else
        if not text then
            text = Tooltips.GetHoverText()
        end
        if not text or text == "" then
            local okPlain, plain = pcall(PlainTipText, GameTooltip)
            if okPlain and type(plain) == "string" and plain ~= "" then
                text = plain
            end
        end
        if not text or text == "" then
            local tip = nil
            local okTip, picked = pcall(PickPrimaryTooltip)
            if okTip then
                tip = picked
            end
            if tip and OwnerBlocked(tip) then
                text = "That addon's tooltip is off."
            else
                local okRead, readText = pcall(BuildSpeakText, tip)
                if okRead and type(readText) == "string" and readText ~= "" then
                    text = readText
                end
            end
        end
        if not text or text == "" then
            text = GetCachedTipText()
        end
        if not text or text == "" then
            text = "No tooltip is showing."
        end
    end

    Tooltips._readingText = text
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(text, AH.Speech.PRIORITY_NAV, { noEcho = true })
    else
        print("|cff66ccff[Helper]|r " .. text)
    end
end

-- Bindings.xml calls this by name. A press sends key down and key up.
-- Key up must not read again or stop the line.
function AccessibilityHelper_ReadTooltipBinding(keystate)
    if keystate == "up" then
        return
    end
    if not (AH.Tooltips and AH.Tooltips.ReadHovered) then
        return
    end
    local ok, err = pcall(AH.Tooltips.ReadHovered)
    if not ok then
        print("|cff66ccff[Helper]|r Read key error: " .. tostring(err))
    end
end

-- The keybind page can show Numpad * while the binding itself never runs.
-- Watch the saved key so a press still reaches ReadHovered.
local readKeyDown = false
local keyWatch = CreateFrame("Frame")
keyWatch:SetScript("OnUpdate", function(self, elapsed)
    self._acc = (self._acc or 0) + (elapsed or 0)
    if self._acc > 0.2 then
        self._acc = 0
        if GetBindingKey then
            local okKey, key = pcall(GetBindingKey, "ACCESSIBILITYHELPER_READTOOLTIP")
            if okKey and type(key) == "string" and key ~= "" then
                Tooltips._readKey = key
            end
        end
    end
    local key = Tooltips._readKey
    if not key or not IsKeyDown then
        return
    end
    local typing = false
    pcall(function()
        if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
            typing = true
        end
    end)
    if typing then
        readKeyDown = false
        return
    end
    local down = false
    pcall(function()
        if IsKeyDown(key) then
            down = true
        end
    end)
    if down and not readKeyDown then
        Tooltips.ReadHovered()
    end
    readKeyDown = down
end)
