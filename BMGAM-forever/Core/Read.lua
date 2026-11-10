local _, BMGAM = ...

BMGAM.Read = BMGAM.Read or {}

_G.BINDING_HEADER_BMGAM = "BMG Alt Manager"
_G.BINDING_NAME_BMGAM_TOGGLE = "Open or close"
_G.BINDING_NAME_BMGAM_READUNDERMOUSE = "Read under the mouse"

local lastTipText = ""
local lastTipAt = 0
local speakGen = 0

local function IsSecret(value)
    if value == nil or type(issecretvalue) ~= "function" then
        return false
    end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafeStr(value)
    if value == nil or IsSecret(value) then
        return ""
    end
    if type(value) == "string" then
        return value
    end
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    local ok, text = pcall(tostring, value)
    if not ok or IsSecret(text) or type(text) ~= "string" or text == "userdata" then
        return ""
    end
    return text
end

local function Clean(value)
    local text = SafeStr(value)
    if text == "" or IsSecret(text) then
        return ""
    end
    local ok, cleaned = pcall(function()
        local s = text
        s = s:gsub("|T.-|t", " ")
        s = s:gsub("|A.-|a", " ")
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        s = s:gsub("|H.-|h(.-)|h", "%1")
        s = s:gsub("|n", " ")
        s = s:gsub("%s+", " ")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        return s
    end)
    if not ok or type(cleaned) ~= "string" or IsSecret(cleaned) then
        return ""
    end
    if #cleaned > 280 then
        cleaned = cleaned:sub(1, 280)
    end
    return cleaned
end

local function Now()
    if GetTime then
        return GetTime()
    end
    return 0
end

local function VoiceID()
    local voiceType = 0
    if Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard ~= nil then
        voiceType = Enum.TtsVoiceType.Standard
    end
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, voiceType)
        if ok and type(id) == "number" and not IsSecret(id) then
            return id
        end
    end
    return 0
end

local function SpeechRate()
    if C_TTSSettings and C_TTSSettings.GetSpeechRate then
        local ok, rate = pcall(C_TTSSettings.GetSpeechRate)
        if ok and type(rate) == "number" and not IsSecret(rate) then
            if rate < 0 then
                return 0
            end
            if rate > 10 then
                return 10
            end
            return rate
        end
    end
    return 0
end

local function SayChunk(text, overlap)
    if type(text) ~= "string" or text == "" or not C_VoiceChat or not C_VoiceChat.SpeakText then
        return
    end
    local voiceID = VoiceID()
    local rate = SpeechRate()
    local interfaceVersion = select(4, GetBuildInfo()) or 0
    local midnight = interfaceVersion >= 120000 or not (Enum and Enum.VoiceTtsDestination)
    if midnight then
        local ok = pcall(C_VoiceChat.SpeakText, voiceID, text, rate, 100, overlap and true or false)
        if ok then
            return
        end
    end
    local destination = 1
    if Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback ~= nil then
        destination = Enum.VoiceTtsDestination.LocalPlayback
    end
    pcall(C_VoiceChat.SpeakText, voiceID, text, destination, rate, 100)
end

local function Speak(text)
    text = Clean(text)
    if text == "" then
        return
    end
    speakGen = speakGen + 1
    local gen = speakGen
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then
        pcall(C_VoiceChat.StopSpeakingText)
    end
    local rest = text
    local first = true
    local function nextChunk()
        if gen ~= speakGen or rest == "" then
            return
        end
        local chunk = rest
        if #rest > 220 then
            local slice = rest:sub(1, 220)
            local breakAt = slice:match(".*()[%s%p]") or 220
            if breakAt < 110 then
                breakAt = 220
            end
            chunk = rest:sub(1, breakAt)
            rest = rest:sub(breakAt + 1):gsub("^%s+", "")
        else
            rest = ""
        end
        SayChunk(chunk, first)
        first = false
        if rest ~= "" and C_Timer and C_Timer.After then
            C_Timer.After(math.max(0.7, #chunk * 0.045), nextChunk)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, nextChunk)
    else
        nextChunk()
    end
end

local function Shown(frame)
    if not frame or not frame.IsShown then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok or IsSecret(shown) then
        return false
    end
    return shown == true
end

local function FrameName(frame)
    if not frame or not frame.GetName then
        return ""
    end
    local ok, name = pcall(frame.GetName, frame)
    if ok and type(name) == "string" then
        return name
    end
    return ""
end

local function MouseFrames()
    local list = {}
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and type(foci) == "table" then
            local index = 1
            while foci[index] do
                list[#list + 1] = foci[index]
                index = index + 1
            end
        end
    end
    if not list[1] and GetMouseFocus then
        local ok, focus = pcall(GetMouseFocus)
        if ok and focus then
            list[1] = focus
        end
    end
    return list
end

local function IsTooltipFrame(frame)
    if not frame then
        return false
    end
    if GameTooltip and frame == GameTooltip then
        return true
    end
    if ItemRefTooltip and frame == ItemRefTooltip then
        return true
    end
    if TitanPanelTooltip and frame == TitanPanelTooltip then
        return true
    end
    local name = FrameName(frame)
    if name == "GameTooltip" or name == "ItemRefTooltip" or name == "TitanPanelTooltip" then
        return true
    end
    if name:find("Tooltip", 1, true) then
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

local function CursorPoint()
    if not GetCursorPosition then
        return nil, nil
    end
    local x, y = GetCursorPosition()
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        local ok, value = pcall(UIParent.GetEffectiveScale, UIParent)
        if ok and type(value) == "number" and value > 0 and not IsSecret(value) then
            scale = value
        end
    end
    return x / scale, y / scale
end

local function ContainsCursor(region)
    if not region or not region.GetLeft then
        return false
    end
    local x, y = CursorPoint()
    if not x then
        return false
    end
    local ok, left, right, bottom, top = pcall(function()
        return region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
    end)
    if not ok or IsSecret(left) or IsSecret(right) or IsSecret(bottom) or IsSecret(top) then
        return false
    end
    if type(left) ~= "number" or type(right) ~= "number" or type(bottom) ~= "number" or type(top) ~= "number" then
        return false
    end
    return x >= left and x <= right and y >= bottom and y <= top
end

local function FontText(region)
    if not region or not Shown(region) or not region.GetText then
        return ""
    end
    local typeOk, kind = pcall(function()
        return region.GetObjectType and region:GetObjectType()
    end)
    if typeOk and kind and kind ~= "FontString" and kind ~= "Button" then
        return ""
    end
    local ok, value = pcall(region.GetText, region)
    if not ok then
        return ""
    end
    return Clean(value)
end

local function LeftLine(tip, index)
    local field = tip and tip["TextLeft" .. index]
    if field then
        return field
    end
    local name = FrameName(tip)
    if name ~= "" then
        return _G[name .. "TextLeft" .. index]
    end
    return nil
end

local function RightLine(tip, index)
    local field = tip and tip["TextRight" .. index]
    if field then
        return field
    end
    local name = FrameName(tip)
    if name ~= "" then
        return _G[name .. "TextRight" .. index]
    end
    return nil
end

local function AddUnique(out, seen, text)
    text = Clean(text)
    if text == "" or seen[text] then
        return
    end
    seen[text] = true
    out[#out + 1] = text
end

local function TooltipDataParts(tip)
    local parts = {}
    local seen = {}
    if not tip or not tip.GetTooltipData then
        return parts
    end
    local ok, data = pcall(tip.GetTooltipData, tip)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        if ok and type(data) == "table" then
            AddUnique(parts, seen, data.hyperlink)
        end
        return parts
    end
    local index = 1
    while data.lines[index] and index <= 24 do
        local line = data.lines[index]
        if type(line) == "table" then
            AddUnique(parts, seen, line.leftText)
            AddUnique(parts, seen, line.rightText)
        end
        index = index + 1
    end
    if not parts[1] then
        AddUnique(parts, seen, data.hyperlink)
    end
    return parts
end

local function TooltipFontParts(tip)
    local parts = {}
    local seen = {}
    if not tip then
        return parts
    end
    local count = 12
    if tip.NumLines then
        local ok, n = pcall(tip.NumLines, tip)
        if ok and type(n) == "number" and not IsSecret(n) and n > 0 then
            count = n
        end
    end
    if count > 24 then
        count = 24
    end
    local index = 1
    while index <= count do
        local left = FontText(LeftLine(tip, index))
        local right = FontText(RightLine(tip, index))
        if left ~= "" and right ~= "" then
            AddUnique(parts, seen, left .. ", " .. right)
        elseif left ~= "" then
            AddUnique(parts, seen, left)
        elseif right ~= "" then
            AddUnique(parts, seen, right)
        end
        index = index + 1
    end
    return parts
end

local function LibQTipParts(tip)
    local parts = {}
    local seen = {}
    if type(tip) ~= "table" or type(tip.GetLineCount) ~= "function" or type(tip.lines) ~= "table" then
        return parts
    end
    local okLines, nLines = pcall(tip.GetLineCount, tip)
    local okCols, nCols = pcall(tip.GetColumnCount, tip)
    if not okLines or type(nLines) ~= "number" or nLines < 1 then
        return parts
    end
    if not okCols or type(nCols) ~= "number" or nCols < 1 then
        nCols = 1
    end
    local lineIndex = 1
    while lineIndex <= nLines and lineIndex <= 24 do
        local line = tip.lines[lineIndex]
        local cells = line and line.cells
        if type(cells) == "table" then
            local row = {}
            local col = 1
            while col <= nCols do
                local cell = cells[col]
                local text = ""
                if type(cell) == "table" then
                    text = FontText(cell.fontString or cell.FontString)
                    if text == "" then
                        text = FontText(cell)
                    end
                end
                if text ~= "" then
                    row[#row + 1] = text
                end
                col = col + 1
            end
            if row[1] then
                AddUnique(parts, seen, table.concat(row, ", "))
            end
        end
        lineIndex = lineIndex + 1
    end
    return parts
end

local function RegionParts(frame)
    local parts = {}
    local seen = {}
    local visited = {}
    local function Walk(obj, depth)
        if not obj or depth > 6 or visited[obj] then
            return
        end
        visited[obj] = true
        local text = FontText(obj)
        if text ~= "" then
            AddUnique(parts, seen, text)
        end
        if obj.GetRegions then
            local ok, regions = pcall(function()
                return { obj:GetRegions() }
            end)
            if ok and type(regions) == "table" then
                local index = 1
                while regions[index] and index <= 40 do
                    Walk(regions[index], depth + 1)
                    index = index + 1
                end
            end
        end
        if depth < 6 and obj.GetChildren then
            local ok, children = pcall(function()
                return { obj:GetChildren() }
            end)
            if ok and type(children) == "table" then
                local index = 1
                while children[index] and index <= 30 do
                    Walk(children[index], depth + 1)
                    index = index + 1
                end
            end
        end
    end
    Walk(frame, 0)
    return parts
end

local function Join(parts)
    if type(parts) ~= "table" or not parts[1] then
        return ""
    end
    local text = table.concat(parts, ". ")
    if #text > 700 then
        text = text:sub(1, 700)
    end
    return text
end

local function GatherTip(tip)
    if not tip then
        return ""
    end
    local parts = {}
    local seen = {}
    local function take(list)
        if type(list) ~= "table" then
            return
        end
        local index = 1
        while list[index] do
            AddUnique(parts, seen, list[index])
            index = index + 1
        end
    end
    take(TooltipDataParts(tip))
    take(TooltipFontParts(tip))
    take(LibQTipParts(tip))
    take(RegionParts(tip))
    return Join(parts)
end

local function RememberTip(tip)
    local text = GatherTip(tip)
    if text ~= "" then
        lastTipText = text
        lastTipAt = Now()
    end
end

local function IsTitanFrame(frame)
    local guard = 0
    while frame and guard < 12 do
        guard = guard + 1
        local name = FrameName(frame)
        if name:find("TitanPanel", 1, true) or name:find("TitanBar", 1, true) then
            return true
        end
        if type(frame.registry) == "table" or type(frame.ldb_obj) == "table" then
            return true
        end
        local ok, parent = pcall(function()
            return frame.GetParent and frame:GetParent()
        end)
        if not ok then
            break
        end
        frame = parent
    end
    return false
end

local function HoveringTitan()
    local foci = MouseFrames()
    local index = 1
    while foci[index] do
        if IsTitanFrame(foci[index]) then
            return true
        end
        index = index + 1
    end
    return false
end

local function LiveTooltipText()
    if HoveringTitan() then
        if Shown(TitanPanelTooltip) then
            local text = GatherTip(TitanPanelTooltip)
            if text ~= "" then
                RememberTip(TitanPanelTooltip)
                return text
            end
        end
        if type(LibStub) == "function" or type(LibStub) == "table" then
            local ok, lib = pcall(LibStub, "LibQTip-1.0", true)
            if ok and type(lib) == "table" and type(lib.IterateTooltips) == "function" then
                local found = ""
                pcall(function()
                    for tip in lib:IterateTooltips() do
                        if Shown(tip) then
                            local text = GatherTip(tip)
                            if text ~= "" then
                                found = text
                                return
                            end
                        end
                    end
                end)
                if found ~= "" then
                    lastTipText = found
                    lastTipAt = Now()
                    return found
                end
            end
        end
    end
    if Shown(GameTooltip) then
        local text = GatherTip(GameTooltip)
        if text ~= "" then
            RememberTip(GameTooltip)
            return text
        end
    end
    if Shown(ItemRefTooltip) then
        local text = GatherTip(ItemRefTooltip)
        if text ~= "" then
            RememberTip(ItemRefTooltip)
            return text
        end
    end
    return ""
end

local function RecentTooltipText()
    if lastTipText == "" then
        return ""
    end
    if (Now() - lastTipAt) > 0.75 then
        return ""
    end
    return lastTipText
end

local function WidgetText(frame)
    if not frame then
        return ""
    end
    local text = FontText(frame)
    if text ~= "" then
        return text
    end
    local keys = { "Text", "Label", "Name", "TitleText", "ButtonText", "text", "label" }
    local index = 1
    while keys[index] do
        local child = frame[keys[index]]
        text = FontText(child)
        if text ~= "" then
            return text
        end
        if type(child) == "string" then
            text = Clean(child)
            if text ~= "" then
                return text
            end
        end
        index = index + 1
    end
    return ""
end

local function CollectLabels(frame, hitOnly, out, seen, depth)
    if not frame or depth > 3 or IsTooltipFrame(frame) or IsWorldOrRoot(frame) or not Shown(frame) then
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
            local index = 1
            while regions[index] and index <= 40 do
                local text = FontText(regions[index])
                if text ~= "" and (not hitOnly or ContainsCursor(regions[index])) then
                    AddUnique(out, seen, text)
                end
                index = index + 1
            end
        end
    end
    if depth < 3 and frame.GetChildren then
        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if ok and type(children) == "table" then
            local index = 1
            while children[index] and index <= 24 do
                CollectLabels(children[index], hitOnly, out, seen, depth + 1)
                index = index + 1
            end
        end
    end
end

local function FrameArea(frame)
    if not frame or not ContainsCursor(frame) then
        return nil
    end
    local ok, left, right, bottom, top = pcall(function()
        return frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    end)
    if not ok or type(left) ~= "number" or type(right) ~= "number" or type(bottom) ~= "number" or type(top) ~= "number" then
        return nil
    end
    if IsSecret(left) or IsSecret(right) or IsSecret(bottom) or IsSecret(top) then
        return nil
    end
    local width = right - left
    local height = top - bottom
    if width <= 0 or height <= 0 then
        return nil
    end
    return width * height
end

local function RowSpeech(frame)
    if frame.left and frame.right then
        local left = FontText(frame.left)
        local right = FontText(frame.right)
        if left ~= "" and right ~= "" then
            return left .. ". " .. right
        end
        if left ~= "" then
            return left
        end
        return right
    end
    if frame.label and frame.value then
        local parts = {}
        local function add(region)
            local text = FontText(region)
            if text ~= "" then
                parts[#parts + 1] = text
            end
        end
        add(frame.label)
        add(frame.value)
        add(frame.rankWord)
        add(frame.rank)
        if parts[1] then
            return table.concat(parts, " ")
        end
    end
    if frame.title then
        return FontText(frame.title)
    end
    if frame.text then
        return FontText(frame.text)
    end
    return ""
end

local function WalkUnderCursor(consider)
    local function Walk(frame, depth)
        if not frame or depth > 12 or not Shown(frame) or IsWorldOrRoot(frame) or IsTooltipFrame(frame) then
            return
        end
        consider(frame)
        if not frame.GetChildren then
            return
        end
        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if not ok or type(children) ~= "table" then
            return
        end
        local index = 1
        while children[index] and index <= 80 do
            Walk(children[index], depth + 1)
            index = index + 1
        end
    end
    local foci = MouseFrames()
    local index = 1
    while foci[index] do
        local frame = foci[index]
        local guard = 0
        while frame and guard < 8 do
            guard = guard + 1
            if not IsWorldOrRoot(frame) then
                Walk(frame, 0)
            end
            local ok, parent = pcall(function()
                return frame.GetParent and frame:GetParent()
            end)
            if not ok then
                break
            end
            frame = parent
        end
        index = index + 1
    end
end

local function RowUnderCursor()
    local bestText = ""
    local bestArea = nil
    WalkUnderCursor(function(frame)
        local speech = RowSpeech(frame)
        local area = FrameArea(frame)
        if speech ~= "" and area and (not bestArea or area < bestArea) then
            bestArea = area
            bestText = speech
        end
    end)
    return bestText
end

local function LabelText()
    local bestText = ""
    local bestArea = nil
    local function ConsiderRegion(region)
        if not region or not Shown(region) then
            return
        end
        local typeOk, kind = pcall(function()
            return region.GetObjectType and region:GetObjectType()
        end)
        if not typeOk or kind ~= "FontString" then
            return
        end
        local text = FontText(region)
        local area = FrameArea(region)
        if text ~= "" and area and (not bestArea or area < bestArea) then
            bestArea = area
            bestText = text
        end
    end
    WalkUnderCursor(function(frame)
        if frame.GetRegions then
            local ok, regions = pcall(function()
                return { frame:GetRegions() }
            end)
            if ok and type(regions) == "table" then
                local index = 1
                while regions[index] and index <= 40 do
                    ConsiderRegion(regions[index])
                    index = index + 1
                end
            end
        end
    end)
    return bestText
end

local function SpellName(spellID)
    if type(spellID) ~= "number" or IsSecret(spellID) then
        return ""
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok then
            return Clean(name)
        end
    end
    return ""
end

local function ActionText()
    local foci = MouseFrames()
    local index = 1
    while foci[index] do
        local frame = foci[index]
        local guard = 0
        while frame and guard < 10 do
            guard = guard + 1
            local action = frame.action
            if type(action) == "number" and not IsSecret(action) and GetActionInfo then
                local ok, actionType, id = pcall(GetActionInfo, action)
                if ok and actionType == "spell" then
                    local name = SpellName(id)
                    if name ~= "" then
                        return name
                    end
                elseif ok and actionType == "macro" and GetActionText then
                    local textOk, text = pcall(GetActionText, action)
                    text = textOk and Clean(text) or ""
                    if text ~= "" then
                        return text
                    end
                elseif ok and actionType == "item" and C_Item and C_Item.GetItemNameByID then
                    local nameOk, name = pcall(C_Item.GetItemNameByID, id)
                    name = nameOk and Clean(name) or ""
                    if name ~= "" then
                        return name
                    end
                end
            end
            local spell = SpellName(frame.spellID)
            if spell ~= "" then
                return spell
            end
            local ok, parent = pcall(function()
                return frame.GetParent and frame:GetParent()
            end)
            if not ok then
                break
            end
            frame = parent
        end
        index = index + 1
    end
    return ""
end

local function UnitText()
    if not UnitName then
        return ""
    end
    local ok, name = pcall(UnitName, "mouseover")
    if not ok then
        return ""
    end
    name = Clean(name)
    if name == "" then
        return ""
    end
    local parts = { name }
    if UnitLevel then
        local levelOk, level = pcall(UnitLevel, "mouseover")
        if levelOk and type(level) == "number" and not IsSecret(level) then
            if level > 0 then
                parts[#parts + 1] = "Level " .. tostring(level)
            elseif level == -1 then
                parts[#parts + 1] = "Skull"
            end
        end
    end
    return table.concat(parts, ". ")
end

function BMGAM.Read.UnderMouse()
    local row = RowUnderCursor()
    if row ~= "" then
        Speak(row)
        return
    end
    local label = LabelText()
    if label ~= "" then
        Speak(label)
        return
    end
    local live = LiveTooltipText()
    if live ~= "" then
        Speak(live)
        return
    end
    local recent = RecentTooltipText()
    if recent ~= "" then
        Speak(recent)
        return
    end
    local action = ActionText()
    if action ~= "" then
        Speak(action)
        return
    end
    local unit = UnitText()
    if unit ~= "" then
        Speak(unit)
    end
end

function BMGAM_ReadUnderMouse()
    BMGAM.Read.UnderMouse()
end

function BMGAM_ToggleWindow()
    if BMGAM.Window and BMGAM.Window.Toggle then
        BMGAM.Window.Toggle()
    end
end

local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < 0.2 then
        return
    end
    self.elapsed = 0
    if HoveringTitan() and Shown(TitanPanelTooltip) then
        RememberTip(TitanPanelTooltip)
    elseif Shown(GameTooltip) then
        RememberTip(GameTooltip)
    elseif Shown(ItemRefTooltip) then
        RememberTip(ItemRefTooltip)
    end
end)

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    local function Remember(tooltip)
        if tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == TitanPanelTooltip then
            RememberTip(tooltip)
        end
    end
    for _, dataType in pairs(Enum.TooltipDataType) do
        if type(dataType) == "number" then
            pcall(TooltipDataProcessor.AddTooltipPostCall, dataType, Remember)
        end
    end
end
