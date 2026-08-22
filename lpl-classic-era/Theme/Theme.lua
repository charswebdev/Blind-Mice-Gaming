local addonName, LPL = ...

LPL.Theme = {
    colors = {
        bgPrimary = { 0.00, 0.00, 0.00, 1.00 },
        bgSidebar = { 0.10, 0.10, 0.12, 1.00 },
        bgElevated = { 0.14, 0.14, 0.17, 1.00 },
        bgButton = { 0.18, 0.18, 0.22, 1.00 },
        bgButtonHover = { 0.24, 0.24, 0.30, 1.00 },
        bgButtonPressed = { 0.14, 0.14, 0.18, 1.00 },
        border = { 0.25, 0.27, 0.32, 1.00 },
        borderActive = { 0.35, 0.65, 1.00, 1.00 },
        accent = { 0.35, 0.65, 1.00, 1.00 },
        textBright = { 0.95, 0.95, 0.97, 1.00 },
        textSecondary = { 0.78, 0.81, 0.88, 1.00 },
        textLabel = { 1.00, 0.92, 0.40, 1.00 },
        actionBarSlotBg = { 0.00, 0.00, 0.00, 1.00 },
        actionBarSlotBorder = { 1.00, 0.92, 0.40, 1.00 },
        textMuted = { 0.72, 0.75, 0.82, 1.00 },
        textDisabled = { 0.55, 0.58, 0.64, 1.00 },
        titleBar = { 0.08, 0.08, 0.10, 1.00 },
        tabActive = { 0.16, 0.18, 0.24, 1.00 },
        tabHover = { 0.14, 0.15, 0.19, 1.00 },
        bgMaroon = { 0.58, 0.10, 0.16, 1.00 },
        bgMaroonHover = { 0.68, 0.14, 0.22, 1.00 },
        bgMaroonPressed = { 0.42, 0.08, 0.12, 1.00 },
        maroonBorder = { 0.72, 0.18, 0.26, 1.00 },
        maroonGlow = { 0.92, 0.32, 0.42, 0.70 },
        bgListSelected = { 0.28, 0.05, 0.09, 1.00 },
        listSelectedBorder = { 0.48, 0.11, 0.16, 1.00 },
        greenGlow = { 0.40, 1.00, 0.50, 1.00 },
        greenBorder = { 0.50, 1.00, 0.55, 1.00 },
        greenGlowFill = { 0.30, 0.90, 0.40, 0.28 },
        greenGlowFillHover = { 0.35, 0.95, 0.45, 0.40 },
    },
    fonts = {},
    backdrop = {
        panel = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        },
        button = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        },
    },
}

function LPL.Theme:InitFonts()
    self.fonts.title = CreateFont("LPLFontTitle")
    self.fonts.title:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")

    self.fonts.header = CreateFont("LPLFontHeader")
    self.fonts.header:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")

    self.fonts.body = CreateFont("LPLFontBody")
    self.fonts.body:SetFont(STANDARD_TEXT_FONT, 12, "")

    self.fonts.bodyBold = CreateFont("LPLFontBodyBold")
    self.fonts.bodyBold:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")

    self.fonts.small = CreateFont("LPLFontSmall")
    self.fonts.small:SetFont(STANDARD_TEXT_FONT, 11, "")

    self.fonts.button = CreateFont("LPLFontButton")
    self.fonts.button:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
end

function LPL.Theme:GetWoWClassColor(classFile)
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            return color.r, color.g, color.b
        end
    end

    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local color = RAID_CLASS_COLORS[classFile]
        return color.r, color.g, color.b
    end

    return 1, 1, 1
end

function LPL.Theme:WrapClassFileText(classFile, text)
    text = text or classFile or ""
    if type(classFile) ~= "string" or classFile == "" then
        return text
    end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color and color.WrapTextInColorCode then
            return color:WrapTextInColorCode(text)
        end
    end
    local r, g, b = self:GetWoWClassColor(classFile)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

function LPL.Theme:WrapRaceText(raceID, text)
    text = text or ""
    raceID = tonumber(raceID)
    if not raceID or text == "" then
        return text
    end
    if C_CreatureInfo and C_CreatureInfo.GetFactionInfo and GetFactionColor then
        local factionInfo = C_CreatureInfo.GetFactionInfo(raceID)
        local groupTag = factionInfo and factionInfo.groupTag
        if groupTag then
            local color = GetFactionColor(groupTag)
            if color and color.WrapTextInColorCode then
                return color:WrapTextInColorCode(text)
            end
        end
    end
    return text
end

-- LightPaws-style covenant coloring via Blizzard COVENANT_COLORS[textureKit].
function LPL.Theme:WrapCovenantText(covenantID, text)
    text = text or ""
    covenantID = tonumber(covenantID)
    if not covenantID or text == "" then
        return text
    end
    if C_Covenants and C_Covenants.GetCovenantData then
        local data = C_Covenants.GetCovenantData(covenantID)
        if data then
            if (not text or text == "") and data.name then
                text = data.name
            end
            local kit = data.textureKit
            if kit and COVENANT_COLORS and COVENANT_COLORS[kit] and COVENANT_COLORS[kit].WrapTextInColorCode then
                return COVENANT_COLORS[kit]:WrapTextInColorCode(text)
            end
        end
    end
    return text
end

function LPL.Theme:InitClassColors()
    local function SetClassColor(key, classFile, alpha)
        local r, g, b = self:GetWoWClassColor(classFile)
        self.colors[key] = { r, g, b, alpha or 1.00 }
    end

    SetClassColor("classButtonBorder", "PALADIN")
    SetClassColor("classListBorder", "HUNTER")
    SetClassColor("classListSelected", "ROGUE")
    SetClassColor("classButtonText", "PRIEST")
    -- Classic Era has no Evoker; EVOKER falls back to white and breaks disabled buttons.
    self.colors.classButtonDisabledBg = { 0.10, 0.10, 0.12, 1.00 }
    self.colors.classButtonTextDisabled = { 0.55, 0.58, 0.64, 1.00 }
end

function LPL.Theme:ApplyListRowBackdrop(frame, selected, hovered, isActive)
    self:ClearFlatBackground(frame)
    if selected then
        self:ApplyBackdrop(frame, "button", "bgListSelected", "listSelectedBorder")
    elseif hovered then
        self:ApplyBackdrop(frame, "button", "bgButtonHover", "classListBorder")
    elseif isActive then
        self:ApplyBackdrop(frame, "button", "bgButton", "greenBorder")
    else
        self:ApplyBackdrop(frame, "button", "bgButton", "classListBorder")
    end
end

function LPL.Theme:ApplyListHeaderBackdrop(frame)
    if not frame then
        return
    end

    if frame.ClearBackdrop then
        frame:ClearBackdrop()
    elseif frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end

    if not frame.lplHeaderBackground then
        frame.lplHeaderBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame.lplHeaderBackground:SetAllPoints()
    end

    frame.lplHeaderBackground:SetColorTexture(0, 0, 0, 1)
    frame.lplHeaderBackground:Show()

    if frame.lplBackground then
        frame.lplBackground:Hide()
    end
    if frame.lplBorder then
        frame.lplBorder:Hide()
    end
end

function LPL.Theme:ClearListHeaderBackdrop(frame)
    if not frame then
        return
    end
    if frame.lplHeaderBackground then
        frame.lplHeaderBackground:Hide()
    end
end

function LPL.Theme:GetColor(name)
    local color = self.colors[name]
    if not color then
        return 1, 1, 1, 1
    end
    return color[1], color[2], color[3], color[4]
end

function LPL.Theme:EnsureBackdrop(frame)
    if not frame or frame.SetBackdrop then
        return
    end

    if BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        if BackdropTemplateMixin.OnBackdropLoaded then
            BackdropTemplateMixin.OnBackdropLoaded(frame)
        end
    end
end

function LPL.Theme:ApplyFlatBackground(frame, bgColorKey, borderColorKey)
    -- Border sits behind a 1px-inset fill. A full-size BORDER-layer texture
    -- would cover the fill and paint every panel grey.
    if not frame.lplBorder then
        frame.lplBorder = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    frame.lplBorder:ClearAllPoints()
    frame.lplBorder:SetAllPoints(frame)
    if frame.lplBorder.SetDrawLayer then
        frame.lplBorder:SetDrawLayer("BACKGROUND", -8)
    end

    if not frame.lplBackground then
        frame.lplBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    frame.lplBackground:ClearAllPoints()
    frame.lplBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.lplBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    if frame.lplBackground.SetDrawLayer then
        frame.lplBackground:SetDrawLayer("BACKGROUND", -7)
    end

    local r, g, b, a = self:GetColor(bgColorKey or "bgPrimary")
    local br, bg, bb, ba = self:GetColor(borderColorKey or "border")
    frame.lplBorder:SetColorTexture(br, bg, bb, ba)
    frame.lplBackground:SetColorTexture(r, g, b, a)
    frame.lplBorder:Show()
    frame.lplBackground:Show()
end

function LPL.Theme:ClearFlatBackground(frame)
    if frame.lplBackground then
        frame.lplBackground:Hide()
    end
    if frame.lplBorder then
        frame.lplBorder:Hide()
    end
end

function LPL.Theme:ApplyBackdrop(frame, backdropKey, bgColorKey, borderColorKey)
    if not frame then
        return
    end

    local backdropInfo = self.backdrop[backdropKey] or self.backdrop.panel
    local r, g, b, a = self:GetColor(bgColorKey or "bgPrimary")
    local br, bg, bb, ba = self:GetColor(borderColorKey or "border")

    self:EnsureBackdrop(frame)

    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
        frame:SetBackdropColor(r, g, b, a)
        frame:SetBackdropBorderColor(br, bg, bb, ba)
    elseif frame.ApplyBackdrop then
        frame.backdropInfo = backdropInfo
        frame:ApplyBackdrop()
        if frame.SetBackdropColor then
            frame:SetBackdropColor(r, g, b, a)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(br, bg, bb, ba)
        end
    end

    -- Panel chrome must keep a color-texture fill. SetBackdrop can succeed
    -- without drawing, which leaves titles and footers floating on the world.
    if backdropKey == "panel" or (not frame.SetBackdrop and not frame.ApplyBackdrop) then
        self:ApplyFlatBackground(frame, bgColorKey, borderColorKey)
    end
end

function LPL.Theme:ClearBackdrop(frame)
    if not frame then
        return
    end

    if frame.ClearBackdrop then
        frame:ClearBackdrop()
    elseif frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end

    self:ClearFlatBackground(frame)
end

function LPL.Theme:ApplyScale(scale)
    local clamped = math.max(0.8, math.min(1.2, scale or 1.0))
    if LPL.MainFrame and LPL.MainFrame.frame then
        LPL.MainFrame.frame:SetScale(clamped)
    end
    return clamped
end
