--[[
  Accessibility Helper — read whatever is under the cursor
  Labels, tooltips, action buttons, and the unit under the mouse.
  /ahtip still reads tooltips on its own keybind.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.UnderMouse = AH.UnderMouse or {}
local UnderMouse = AH.UnderMouse

local lastAutoText = nil
local lastAutoAt = 0
local pendingText = nil
local pendingAt = 0
local ticker

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

local function SafeStr(v)
    if v == nil or IsSecret(v) then
        return ""
    end
    if type(v) == "string" then
        return v
    end
    if type(v) == "number" or type(v) == "boolean" then
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
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Clean(s)
    s = Trim(SafeStr(s))
    if s == "" or IsSecret(s) then
        return ""
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        s = Trim(AH.ChatText.ForSpeech(s) or "")
    else
        s = s:gsub("|T.-|t", " ")
        s = s:gsub("|A.-|a", " ")
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        s = s:gsub("|H.-|h(.-)|h", "%1")
        s = s:gsub("|n", " ")
        s = s:gsub("%s+", " ")
        s = Trim(s)
    end
    if #s > 280 then
        s = Trim(s:sub(1, 280))
    end
    return s
end

local function Mode()
    if AH.DB and AH.DB.GetUnderMouseMode then
        return AH.DB.GetUnderMouseMode()
    end
    return "keybind"
end

local function Enabled()
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return false
    end
    return Mode() ~= "off"
end

local function HoverOn()
    return Enabled() and Mode() == "hover"
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

local function FrameName(frame)
    if not frame or not frame.GetName then
        return ""
    end
    local ok, name = pcall(function()
        return frame:GetName()
    end)
    if ok and type(name) == "string" then
        return name
    end
    return ""
end

local function IsTooltipFrame(frame)
    local name = FrameName(frame)
    if name == "GameTooltip" or name == "ItemRefTooltip" or name == "TitanPanelTooltip" then
        return true
    end
    if name:find("Tooltip", 1, true) or name:find("GameTooltip", 1, true) then
        return true
    end
    if GameTooltip and frame == GameTooltip then
        return true
    end
    if ItemRefTooltip and frame == ItemRefTooltip then
        return true
    end
    return false
end

local function IsWorldOrRoot(frame)
    if not frame then
        return true
    end
    if WorldFrame and frame == WorldFrame then
        return true
    end
    if UIParent and frame == UIParent then
        return true
    end
    local name = FrameName(frame)
    return name == "WorldFrame" or name == "UIParent"
end

local function IsSettingsFrame(frame)
    local settings = AH.Settings and AH.Settings.GetFrame and AH.Settings.GetFrame()
    if not settings then
        return false
    end
    local f = frame
    local guard = 0
    while f and guard < 16 do
        guard = guard + 1
        if f == settings then
            return true
        end
        local ok, parent = pcall(function()
            return f.GetParent and f:GetParent()
        end)
        if not ok then
            break
        end
        f = parent
    end
    return false
end

local function Shown(frame)
    if not frame then
        return false
    end
    local ok, shown = pcall(function()
        return frame:IsShown()
    end)
    return ok and shown and true or false
end

local function CursorUI()
    if not GetCursorPosition then
        return nil, nil
    end
    local x, y = GetCursorPosition()
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    end
    if scale == 0 then
        scale = 1
    end
    return x / scale, y / scale
end

local function ContainsCursor(region)
    if not region or not region.GetLeft then
        return false
    end
    local cx, cy = CursorUI()
    if not cx then
        return false
    end
    local ok, left, right, bottom, top = pcall(function()
        return region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
    end)
    if not ok or not left or not right or not bottom or not top then
        return false
    end
    return cx >= left and cx <= right and cy >= bottom and cy <= top
end

local function AddUnique(out, seen, text)
    text = Clean(text)
    if text == "" or seen[text] then
        return
    end
    if text == "0" or text == "-" then
        return
    end
    seen[text] = true
    out[#out + 1] = text
end

local function RegionText(region)
    if not region then
        return ""
    end
    local okType, rtype = pcall(function()
        return region.GetObjectType and region:GetObjectType()
    end)
    if not okType or rtype ~= "FontString" then
        return ""
    end
    if not Shown(region) then
        return ""
    end
    local ok, t = pcall(function()
        return region:GetText()
    end)
    if not ok then
        return ""
    end
    return Clean(t)
end

local function WidgetText(frame)
    if not frame then
        return ""
    end
    if frame.GetText then
        local ok, t = pcall(function()
            return frame:GetText()
        end)
        if ok then
            local s = Clean(t)
            if s ~= "" then
                return s
            end
        end
    end
    for _, key in ipairs({ "Text", "Label", "Name", "TitleText", "ButtonText", "text", "label" }) do
        local child = frame[key]
        local s = RegionText(child)
        if s ~= "" then
            return s
        end
        if type(child) == "string" then
            s = Clean(child)
            if s ~= "" then
                return s
            end
        end
    end
    return ""
end

local function CollectFrom(frame, hitOnly, out, seen, depth)
    if not frame or depth > 3 then
        return
    end
    if IsTooltipFrame(frame) or IsWorldOrRoot(frame) then
        return
    end
    if not Shown(frame) then
        return
    end

    local own = WidgetText(frame)
    if own ~= "" and (not hitOnly or ContainsCursor(frame)) then
        AddUnique(out, seen, own)
    end

    if frame.GetRegions then
        local ok, regions = pcall(function()
            return { frame:GetRegions() }
        end)
        if ok and type(regions) == "table" then
            for i = 1, #regions do
                local text = RegionText(regions[i])
                if text ~= "" and (not hitOnly or ContainsCursor(regions[i])) then
                    AddUnique(out, seen, text)
                end
            end
        end
    end

    if frame.GetChildren and depth < 3 then
        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if ok and type(children) == "table" then
            for i = 1, math.min(#children, 40) do
                CollectFrom(children[i], hitOnly, out, seen, depth + 1)
            end
        end
    end
end

local function Join(parts)
    if #parts == 0 then
        return ""
    end
    local maxParts = 4
    local n = math.min(#parts, maxParts)
    local bits = {}
    local total = 0
    for i = 1, n do
        bits[#bits + 1] = parts[i]
        total = total + #parts[i]
        if total > 360 then
            break
        end
    end
    return table.concat(bits, ". ")
end

local function GatherUiLabels()
    local foci = MouseFrames()
    local start
    for i = 1, #foci do
        local f = foci[i]
        if f and not IsTooltipFrame(f) and not IsWorldOrRoot(f) then
            start = f
            break
        end
    end
    if not start then
        return ""
    end

    local hit = {}
    local seenHit = {}
    local frame = start
    local guard = 0
    while frame and guard < 8 do
        guard = guard + 1
        if IsTooltipFrame(frame) or IsWorldOrRoot(frame) then
            break
        end
        CollectFrom(frame, true, hit, seenHit, 0)
        if #hit > 0 then
            return Join(hit)
        end
        local ok, parent = pcall(function()
            return frame.GetParent and frame:GetParent()
        end)
        if not ok then
            break
        end
        frame = parent
    end

    local all = {}
    local seenAll = {}
    frame = start
    guard = 0
    while frame and guard < 6 do
        guard = guard + 1
        if IsTooltipFrame(frame) or IsWorldOrRoot(frame) then
            break
        end
        CollectFrom(frame, false, all, seenAll, 0)
        if #all > 0 then
            return Join(all)
        end
        local ok, parent = pcall(function()
            return frame.GetParent and frame:GetParent()
        end)
        if not ok then
            break
        end
        frame = parent
    end
    return ""
end

local function SpellName(id)
    if type(id) ~= "number" then
        return ""
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" then
            return Clean(n)
        end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and type(n) == "string" then
            return Clean(n)
        end
    end
    return ""
end

local function GatherAction()
    local foci = MouseFrames()
    for i = 1, #foci do
        local f = foci[i]
        local guard = 0
        while f and guard < 10 do
            guard = guard + 1
            local action = f.action
            if type(action) == "number" and GetActionInfo then
                local ok, actionType, id, sub = pcall(GetActionInfo, action)
                if ok then
                    if actionType == "spell" then
                        local n = SpellName(id)
                        if n ~= "" then
                            return n
                        end
                    elseif actionType == "macro" and GetActionText then
                        local okT, t = pcall(GetActionText, action)
                        t = Clean(okT and t or "")
                        if t ~= "" then
                            return t
                        end
                    elseif actionType == "item" and C_Item and C_Item.GetItemNameByID then
                        local okN, n = pcall(C_Item.GetItemNameByID, id)
                        n = Clean(okN and n or "")
                        if n ~= "" then
                            return n
                        end
                    elseif actionType == "item" and GetItemInfo then
                        local okN, n = pcall(GetItemInfo, id)
                        n = Clean(okN and n or "")
                        if n ~= "" then
                            return n
                        end
                    end
                end
            end
            local n = SpellName(f.spellID)
            if n ~= "" then
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
    return ""
end

local function GatherUnit()
    if not UnitExists or not UnitExists("mouseover") then
        return ""
    end
    local parts = {}
    local ok, name = pcall(UnitName, "mouseover")
    name = Clean(ok and name or "")
    if name ~= "" then
        parts[#parts + 1] = name
    end
    if UnitLevel then
        local okL, lvl = pcall(UnitLevel, "mouseover")
        if okL and type(lvl) == "number" and lvl > 0 then
            parts[#parts + 1] = "Level " .. tostring(lvl)
        elseif okL and lvl == -1 then
            parts[#parts + 1] = "Skull"
        end
    end
    if UnitClassification then
        local okC, cls = pcall(UnitClassification, "mouseover")
        if okC and type(cls) == "string" and cls ~= "" and cls ~= "normal" then
            parts[#parts + 1] = cls
        end
    end
    return table.concat(parts, ". ")
end

--- Whatever is under the cursor: tooltip, UI label, action, or unit.
function UnderMouse.GetText()
    local tip = ""
    if AH.Tooltips and AH.Tooltips.GetHoveredText then
        tip = AH.Tooltips.GetHoveredText() or ""
    end
    if type(tip) == "string" and tip ~= "" then
        return tip
    end
    local label = GatherUiLabels()
    if label ~= "" then
        return label
    end
    local action = GatherAction()
    if action ~= "" then
        return action
    end
    return GatherUnit()
end

local function SpeakText(text, emptyMsg)
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if text ~= "" then
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say(text, AH.Speech.PRIORITY_NAV)
        else
            print("|cff66ccff[Helper]|r " .. text)
        end
        return
    end
    if emptyMsg and AH.Speech and AH.Speech.Say then
        AH.Speech.Say(emptyMsg, AH.Speech.PRIORITY_LOW)
    end
end

--- Keybind / /ahread: speak labels under the cursor. Re-press cancels.
function UnderMouse.Read()
    if not Enabled() then
        SpeakText("", "Under-mouse reading is disabled.")
        return
    end
    if UnderMouse._readingActive then
        UnderMouse._readingActive = false
        if AH.Speech and AH.Speech.ClearNavQueue then
            AH.Speech.ClearNavQueue()
        end
        return
    end
    local text = UnderMouse.GetText()
    if text == "" then
        return
    end
    UnderMouse._readingActive = true
    SpeakText(text)
    if C_Timer and C_Timer.After then
        C_Timer.After(math.min(12, math.max(1.2, #(text or "") * 0.04)), function()
            UnderMouse._readingActive = false
        end)
    else
        UnderMouse._readingActive = false
    end
end

local function Tick()
    if not HoverOn() then
        lastAutoText = nil
        pendingText = nil
        return
    end
    if IsSettingsFrame((MouseFrames())[1]) then
        return
    end
    local text = UnderMouse.GetText()
    local now = (GetTime and GetTime()) or 0
    if text == "" then
        lastAutoText = nil
        pendingText = nil
        return
    end
    if text == lastAutoText then
        pendingText = nil
        return
    end
    if text ~= pendingText then
        pendingText = text
        pendingAt = now
        return
    end
    if (now - pendingAt) < 0.28 then
        return
    end
    lastAutoText = text
    lastAutoAt = now
    pendingText = nil
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(text, AH.Speech.PRIORITY_NAV)
    end
end

ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(me, elapsed)
    me._ahAccum = (me._ahAccum or 0) + (elapsed or 0)
    if me._ahAccum < 0.22 then
        return
    end
    me._ahAccum = 0
    Tick()
end)
