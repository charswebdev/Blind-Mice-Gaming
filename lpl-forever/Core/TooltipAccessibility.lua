local addonName, LPL = ...

local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue

local TOOLTIP_COLORS = {}

local HINT_PATTERNS = {
    "^Drag ",
    "^Shift%+",
    "^Right%-click",
    "^Left%-click",
    "^Click to",
    "^Ignored ",
    "^Empty",
    "^Re%-enable",
    "^Open a ",
    "^Return to ",
    "^Load your ",
    "^Your character ",
    "^Pet slot ",
    "^Slot %d",
}

local function HasSecretAPI()
    return type(issecretvalue) == "function" and type(canaccessvalue) == "function"
end

local function ColorFromFontObject(color, fallback)
    if color and color.GetRGB then
        return { color:GetRGB() }
    end
    if type(color) == "table" then
        return { color.r or fallback[1], color.g or fallback[2], color.b or fallback[3] }
    end
    return fallback
end

local function InitTooltipColors()
    TOOLTIP_COLORS.title = ColorFromFontObject(HIGHLIGHT_FONT_COLOR, { 1, 1, 1 })
    TOOLTIP_COLORS.normal = ColorFromFontObject(NORMAL_FONT_COLOR, { 1, 0.82, 0 })
    TOOLTIP_COLORS.gray = ColorFromFontObject(GRAY_FONT_COLOR, { 0.5, 0.5, 0.5 })
    TOOLTIP_COLORS.gold = { 1, 0.82, 0 }
    TOOLTIP_COLORS.green = ColorFromFontObject(GREEN_FONT_COLOR, { 0.4, 1, 0.5 })
    TOOLTIP_COLORS.red = ColorFromFontObject(RED_FONT_COLOR, { 1, 0.1, 0.1 })
    TOOLTIP_COLORS.purple = { 0.78, 0.55, 1 }
    TOOLTIP_COLORS.enchant = { 0.4, 1, 0.5 }
end

InitTooltipColors()

function LPL:PlainString(value)
    if value == nil then
        return nil
    end

    if HasSecretAPI() and not canaccessvalue(value) then
        return nil
    end

    if type(value) == "string" then
        return value ~= "" and value or nil
    end

    if HasSecretAPI() and issecretvalue(value) then
        if type(string.concat) == "function" then
            local ok, text = pcall(string.concat, value)
            if ok and type(text) == "string" and text ~= "" then
                return text
            end
        end
        return nil
    end

    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    return nil
end

function LPL:SanitizePlainText(value)
    return self:PlainString(value)
end

function LPL:PlainStringOr(value, fallback)
    return self:PlainString(value) or fallback
end

function LPL:SafePrintf(fmt, ...)
    local count = select("#", ...)
    local args = { ... }
    for i = 1, count do
        local safe = self:PlainString(args[i])
        if safe then
            args[i] = safe
        elseif HasSecretAPI() and not canaccessvalue(args[i]) then
            return
        end
    end
    print(string.format(fmt, unpack(args, 1, count)))
end

function LPL:GetTooltipColor(colorKey)
    local color = TOOLTIP_COLORS[colorKey] or TOOLTIP_COLORS.normal
    return color[1], color[2], color[3]
end

function LPL:ParseTooltipLine(line)
    if type(line) == "string" then
        return { text = line }
    end
    if type(line) == "table" then
        return line
    end
    return nil
end

function LPL:IsTooltipHintLine(text)
    if type(text) ~= "string" then
        return false
    end
    for _, pattern in ipairs(HINT_PATTERNS) do
        if text:match(pattern) then
            return true
        end
    end
    return false
end

function LPL:InferTooltipLineColor(text, lineIndex, useHeader)
    if type(text) ~= "string" or text == "" then
        return "normal"
    end
    if self:IsTooltipHintLine(text) then
        return "gray"
    end
    if lineIndex == 1 and useHeader then
        return "title"
    end
    if text:match("^%+%d") or text:match("^%-%d") or text:match("^Increases ") then
        return "green"
    end
    if text:match("^%[") then
        return "purple"
    end
    if text:match("^Item Level ") then
        return "gray"
    end
    return "normal"
end

local function SurfaceTooltipData(data)
    if not data or type(data) ~= "table" then
        return
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
        if data.lines then
            for _, line in ipairs(data.lines) do
                if type(line) == "table" then
                    pcall(TooltipUtil.SurfaceArgs, line)
                end
            end
        end
    end
end

local function NormalizeTooltipPlainChunk(text)
    if type(text) ~= "string" then
        return nil
    end
    local norm = text:gsub("%s+", " "):match("^%s*(.-)%s*$")
    if not norm or norm == "" then
        return nil
    end
    return norm
end

function LPL:AppendTooltipPlainPart(parts, seen, value)
    local text = self:PlainString(value)
    if not text or text == " " then
        return
    end

    local norm = NormalizeTooltipPlainChunk(text)
    if not norm or seen[norm] then
        return
    end

    seen[norm] = true
    parts[#parts + 1] = text
end

function LPL:AppendTooltipDataLines(parts, seen, data)
    if not data or not data.lines then
        return
    end

    SurfaceTooltipData(data)
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            self:AppendTooltipPlainPart(parts, seen, line.leftText)
            self:AppendTooltipPlainPart(parts, seen, line.rightText)
        elseif type(line) == "string" then
            self:AppendTooltipPlainPart(parts, seen, line)
        end
    end
end

function LPL:AppendTooltipFontStringLines(parts, seen, tooltip)
    if not tooltip or not tooltip.GetName then
        return
    end

    local prefix = tooltip:GetName()
    if type(prefix) ~= "string" or prefix == "" then
        return
    end

    for index = 1, 60 do
        local left = _G[prefix .. "TextLeft" .. index]
        local right = _G[prefix .. "TextRight" .. index]
        if left and left.GetText then
            self:AppendTooltipPlainPart(parts, seen, left:GetText())
        end
        if right and right.GetText then
            self:AppendTooltipPlainPart(parts, seen, right:GetText())
        end
    end
end

function LPL:CollectGameTooltipPlainText(tooltip)
    tooltip = tooltip or GameTooltip
    if not tooltip then
        return nil
    end

    local parts = {}
    local seen = {}

    if tooltip.processingInfo and tooltip.processingInfo.tooltipData then
        self:AppendTooltipDataLines(parts, seen, tooltip.processingInfo.tooltipData)
    end

    if tooltip.GetTooltipData then
        local ok, data = pcall(tooltip.GetTooltipData, tooltip)
        if ok and data then
            self:AppendTooltipDataLines(parts, seen, data)
        end
    end

    self:AppendTooltipFontStringLines(parts, seen, tooltip)

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, " ")
end

function LPL:ResetGameTooltipAccessibility(tooltip, owner)
    if owner then
        owner.lplTooltipPlain = nil
        owner.lplTooltipManaged = nil
    end

    if not tooltip then
        return
    end

    if tooltip.processingInfo then
        tooltip.processingInfo = nil
    end

    if tooltip.lplA11yPlain then
        tooltip.lplA11yPlain:Hide()
        if tooltip.lplA11yPlain.SetText then
            tooltip.lplA11yPlain:SetText("")
        end
    end
end

function LPL:ResetGameTooltipContent(tooltip)
    if not tooltip then
        return
    end
    if tooltip.ClearLines then
        tooltip:ClearLines()
    end
    self:ResetGameTooltipAccessibility(tooltip)
end

function LPL:ClearGameTooltipData(tooltip)
    if not tooltip then
        return
    end
    local owner = tooltip:GetOwner()
    tooltip:Hide()
    self:ResetGameTooltipAccessibility(tooltip, owner)
end

function LPL:SetGameTooltipAccessibilityPlain(tooltip, owner, plain)
    if not owner then
        return
    end

    owner.lplTooltipManaged = true
    plain = self:SanitizePlainText(plain)
    if not plain then
        owner.lplTooltipPlain = nil
        return
    end

    owner.lplTooltipPlain = plain
end

function LPL:AddGameTooltipStyledLine(tooltip, line, lineIndex, options)
    options = options or {}
    local parsed = self:ParseTooltipLine(line)
    if not parsed then
        return nil
    end

    local text = parsed.text
    if text == " " then
        tooltip:AddLine(" ")
        return nil
    end

    text = self:PlainString(text)
    if not text then
        return nil
    end

    local colorKey = parsed.color or self:InferTooltipLineColor(text, lineIndex, options.useHeader)
    local r, g, b = self:GetTooltipColor(colorKey)
    local wrap = parsed.wrap ~= false
    local useAddLine = options.forceAddLine or parsed.forceAddLine or lineIndex > 1

    if useAddLine then
        if GameTooltip_AddColoredLine and colorKey == "gray" then
            GameTooltip_AddColoredLine(tooltip, text, GRAY_FONT_COLOR, wrap)
        elseif GameTooltip_AddNormalLine and colorKey == "normal" then
            GameTooltip_AddNormalLine(tooltip, text, wrap)
        elseif GameTooltip_AddHighlightLine and colorKey == "title" then
            GameTooltip_AddHighlightLine(tooltip, text, wrap)
        else
            tooltip:AddLine(text, r, g, b, wrap)
        end
    elseif GameTooltip_AddHighlightLine and colorKey == "title" then
        GameTooltip_AddHighlightLine(tooltip, text, wrap)
    else
        local ok = pcall(tooltip.SetText, tooltip, text, r, g, b)
        if not ok then
            if CreateColor then
                tooltip:SetText(text, CreateColor(r, g, b, 1))
            else
                tooltip:SetText(text)
            end
        end
    end

    return text
end

function LPL:ShowGameTooltip(owner, spec)
    if not owner or not GameTooltip then
        return
    end

    spec = spec or {}
    GameTooltip:SetOwner(owner, spec.anchor or "ANCHOR_RIGHT")
    self:ResetGameTooltipContent(GameTooltip)

    local plainParts = {}
    local hasHyperlink = false

    if spec.hyperlink then
        local link = self:PlainString(spec.hyperlink)
        if link then
            GameTooltip:SetHyperlink(link)
            hasHyperlink = true
        end
    end

    if not hasHyperlink and spec.spellID then
        local spellID = tonumber(spec.spellID)
        if spellID then
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(spellID)
                hasHyperlink = true
            else
                local link = "spell:" .. spellID
                GameTooltip:SetHyperlink(link)
                hasHyperlink = true
            end
        end
    end

    local lines = spec.lines or {}
    if hasHyperlink and #lines > 0 then
        GameTooltip:AddLine(" ")
    end

    for index, line in ipairs(lines) do
        if line then
            local text = self:AddGameTooltipStyledLine(GameTooltip, line, index, {
                useHeader = not hasHyperlink,
                forceAddLine = hasHyperlink,
            })
            if text then
                plainParts[#plainParts + 1] = text
            end
        end
    end

    if not hasHyperlink and #plainParts == 0 then
        self:ResetGameTooltipAccessibility(GameTooltip, owner)
        return
    end

    GameTooltip:Show()

    local plain = self:CollectGameTooltipPlainText(GameTooltip)
    if not plain or plain == "" then
        plain = table.concat(plainParts, " ")
    end

    self:SetGameTooltipAccessibilityPlain(GameTooltip, owner, plain)
end

function LPL:ShowGameTooltipLines(owner, lines, options)
    self:ShowGameTooltip(owner, {
        lines = lines,
        anchor = options and options.anchor,
        hyperlink = options and options.hyperlink,
    })
end

function LPL:ShowAccessibleGameTooltip(owner, title, body, options)
    local lines = {}
    local titleText = self:PlainString(title)
    if titleText then
        lines[#lines + 1] = { text = titleText, color = "title" }
    end

    local bodyText = self:PlainString(body)
    if bodyText then
        for line in bodyText:gmatch("[^\r\n]+") do
            lines[#lines + 1] = line
        end
    end

    self:ShowGameTooltip(owner, {
        lines = lines,
        anchor = options and options.anchor,
    })
end

function LPL:GetAccessibilityTooltipPlain()
    if not GameTooltip or not GameTooltip:IsShown() then
        return nil
    end

    local owner = GameTooltip:GetOwner()
    if not owner or (not owner.lplTooltipManaged and not owner.lplTooltipPlain) then
        return nil
    end

    local collected = self:CollectGameTooltipPlainText(GameTooltip)
    if collected and collected ~= "" then
        return self:SanitizePlainText(collected)
    end

    return self:SanitizePlainText(owner.lplTooltipPlain)
end

_G.LPL_GetAccessibilityTooltipPlain = function()
    if not LPL or not LPL.GetAccessibilityTooltipPlain then
        return nil
    end

    local ok, text = pcall(LPL.GetAccessibilityTooltipPlain, LPL)
    if ok then
        return text
    end

    return nil
end
