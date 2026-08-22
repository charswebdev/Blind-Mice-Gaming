local addonName, LPL = ...

local Theme = LPL.Theme

function LPL:CreatePanel(name, parent)
    local panel = CreateFrame("Frame", name, parent, "BackdropTemplate")
    Theme:ApplyBackdrop(panel, "panel", "bgElevated", "border")
    return panel
end

function LPL:CreateButton(name, parent)
    local button = CreateFrame("Button", name, parent, "BackdropTemplate")

    local function ApplyButtonAppearance(buttonFrame, state)
        if not buttonFrame:IsEnabled() then
            Theme:ApplyBackdrop(buttonFrame, "button", "classButtonDisabledBg", "border")
            if buttonFrame.label then
                buttonFrame.label:SetTextColor(Theme:GetColor("classButtonTextDisabled"))
            end
            return
        end

        local bgKey = "bgButton"
        if state == "hover" then
            bgKey = "bgButtonHover"
        elseif state == "pressed" then
            bgKey = "bgButtonPressed"
        end

        Theme:ApplyBackdrop(buttonFrame, "button", bgKey, "classButtonBorder")
        if buttonFrame.label then
            buttonFrame.label:SetTextColor(Theme:GetColor("classButtonText"))
        end
    end

    local label = button:CreateFontString(nil, "OVERLAY", nil)
    label:SetFontObject(Theme.fonts.button)
    label:SetPoint("CENTER")
    button.label = label

    ApplyButtonAppearance(button, "normal")

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            ApplyButtonAppearance(self, "hover")
        end
    end)
    button:SetScript("OnLeave", function(self)
        ApplyButtonAppearance(self, "normal")
    end)
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            ApplyButtonAppearance(self, "pressed")
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self:IsEnabled() then
            ApplyButtonAppearance(self, "hover")
        end
    end)

    local enable = button.Enable
    function button:Enable()
        enable(self)
        ApplyButtonAppearance(self, "normal")
    end

    local disable = button.Disable
    function button:Disable()
        disable(self)
        ApplyButtonAppearance(self, "disabled")
    end

    function button:SetText(text)
        self.label:SetText(text)
    end

    function button:SetLabelColor(colorKey)
        self.label:SetTextColor(Theme:GetColor(colorKey))
    end

    function button:UpdateAppearance(state)
        ApplyButtonAppearance(self, state or "normal")
    end

    return button
end

local GLOW_BUTTON_PAD = 14

local glowRingBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    tileSize = 0,
    edgeSize = 3,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function LPL:CreateGlowButton(name, parent)
    local container = CreateFrame("Frame", name, parent)
    container:EnableMouse(false)

    local button = CreateFrame("Button", nil, container, "BackdropTemplate")
    button:SetPoint("CENTER", container, "CENTER", 0, 0)
    LPL.Theme:ApplyBackdrop(button, "button", "bgMaroon", "maroonBorder")

    local glowHalo = container:CreateTexture(nil, "BACKGROUND")
    glowHalo:SetPoint("TOPLEFT", button, "TOPLEFT", -GLOW_BUTTON_PAD, GLOW_BUTTON_PAD)
    glowHalo:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", GLOW_BUTTON_PAD, -GLOW_BUTTON_PAD)

    local glowRing = CreateFrame("Frame", nil, container, "BackdropTemplate")
    glowRing:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
    glowRing:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
    LPL.Theme:EnsureBackdrop(glowRing)
    glowRing:SetBackdrop(glowRingBackdrop)
    glowRing:SetBackdropColor(0, 0, 0, 0)

    local label = button:CreateFontString(nil, "OVERLAY", nil)
    label:SetFontObject(Theme.fonts.bodyBold)
    label:SetPoint("CENTER")
    label:SetTextColor(Theme:GetColor("textLabel"))
    button.label = label

    function button:SetText(text)
        self.label:SetText(text)
    end

    button:SetFrameLevel(container:GetFrameLevel() + 2)
    glowRing:SetFrameLevel(container:GetFrameLevel() + 1)

    container.button = button
    container.glowHalo = glowHalo
    container.glowRing = glowRing

    local function ApplyGlowStyle(hovered, pressed)
        local Theme = LPL.Theme
        local fillKey = hovered and "greenGlowFillHover" or "greenGlowFill"
        local fr, fg, fb, fa = Theme:GetColor(fillKey)
        local br, bg, bb = Theme:GetColor("greenBorder")
        local borderAlpha = pressed and 0.75 or (hovered and 1 or 0.85)

        glowHalo:SetColorTexture(fr, fg, fb, fa)
        glowRing:SetBackdropBorderColor(br, bg, bb, borderAlpha)

        if pressed then
            Theme:ApplyBackdrop(button, "button", "bgMaroonPressed", "maroonBorder")
        elseif hovered then
            Theme:ApplyBackdrop(button, "button", "bgMaroonHover", "maroonBorder")
        else
            Theme:ApplyBackdrop(button, "button", "bgMaroon", "maroonBorder")
        end
    end

    button:SetScript("OnEnter", function()
        if button:IsEnabled() then
            ApplyGlowStyle(true, false)
        end
    end)
    button:SetScript("OnLeave", function()
        if button:IsEnabled() then
            ApplyGlowStyle(false, false)
        end
    end)
    button:SetScript("OnMouseDown", function()
        if button:IsEnabled() then
            ApplyGlowStyle(true, true)
        end
    end)
    button:SetScript("OnMouseUp", function()
        if button:IsEnabled() then
            ApplyGlowStyle(true, false)
        end
    end)

    ApplyGlowStyle(false, false)

    function container:SetSize(width, height)
        button:SetSize(width, height)
        self:SetWidth(width + GLOW_BUTTON_PAD * 2)
        self:SetHeight(height + GLOW_BUTTON_PAD * 2)
    end

    function container:SetText(text)
        button:SetText(text)
    end

    function container:SetScript(event, handler)
        button:SetScript(event, handler)
    end

    function container:Enable()
        button:Enable()
    end

    function container:Disable()
        button:Disable()
    end

    function container:IsEnabled()
        return button:IsEnabled()
    end

    return container
end

function LPL:CreateLabel(parent, size)
    local fontObject = Theme.fonts.body
    if size == "title" then
        fontObject = Theme.fonts.title
    elseif size == "header" then
        fontObject = Theme.fonts.header
    elseif size == "small" then
        fontObject = Theme.fonts.small
    elseif size == "bold" then
        fontObject = Theme.fonts.bodyBold
    end

    local label = parent:CreateFontString(nil, "OVERLAY", nil)
    label:SetFontObject(fontObject)
    label:SetTextColor(Theme:GetColor("textBright"))
    if label.SetMouseClickEnabled then
        label:SetMouseClickEnabled(false)
    end
    return label
end

function LPL:CreateEditBox(name, parent, width)
    local container = CreateFrame("Frame", name, parent)
    container:SetHeight(28)
    container:SetWidth(width or 220)

    local edit = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    edit:SetAllPoints(container)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(LPL.BuildStore and LPL.BuildStore.MAX_NAME_LENGTH or 150)
    edit:SetFontObject(Theme.fonts.body)
    edit:SetTextColor(Theme:GetColor("textBright"))

    container.editBox = edit

    function container:GetText()
        return edit:GetText()
    end

    function container:SetText(text)
        edit:SetText(text or "")
    end

    function container:SetOnEnterPressed(callback)
        edit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            if callback then
                callback()
            end
        end)
    end

    function container:SetOnEscapePressed(callback)
        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            if callback then
                callback()
            end
        end)
    end

    return container
end

function LPL:CreateSidebarTab(name, parent, data)
    local tab = CreateFrame("Button", name, parent, "BackdropTemplate")
    tab:SetSize(48, 48)

    local accent = tab:CreateTexture(nil, "BACKGROUND")
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(Theme:GetColor("accent"))
    accent:Hide()
    tab.accent = accent

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("CENTER")
    if data.iconStem and LPL.SetIconTexture and LPL:SetIconTexture(icon, data.iconStem) then
        -- custom addon icon
    elseif data.icon then
        icon:SetTexture(data.icon)
        if data.icon:find("AddOns\\", 1, true) then
            icon:SetTexCoord(0, 1, 0, 1)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    tab.icon = icon

    tab.moduleID = data.id
    tab.tooltipTitle = data.label
    tab.tooltipText = data.description or ""

    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            Theme:ApplyBackdrop(self, "button", "tabHover", "border")
        end
        LPL:ShowAccessibleGameTooltip(self, self.tooltipTitle, self.tooltipText)
    end)

    tab:SetScript("OnLeave", function(self)
        LPL:ClearGameTooltipData(GameTooltip)
        if not self.isActive then
            LPL.Theme:ClearBackdrop(self)
        end
    end)

    function tab:SetActive(active)
        self.isActive = active
        if active then
            Theme:ApplyBackdrop(self, "button", "tabActive", "border")
            self.accent:Show()
            self.icon:SetVertexColor(1, 1, 1)
        else
            LPL.Theme:ClearBackdrop(self)
            self.accent:Hide()
            self.icon:SetVertexColor(0.65, 0.68, 0.75)
        end
    end

    return tab
end

local DROPDOWN_MENU_SUFFIXES = { "Button", "Text", "Middle", "Left", "Right", "Icon" }

local function HideDropDownMenuChrome(menu)
    if not menu then
        return
    end
    menu:EnableMouse(false)
    menu:SetAlpha(0)
    menu:SetSize(1, 1)
    menu:ClearAllPoints()
    menu:SetPoint("TOP", UIParent, "BOTTOM", 0, -200)

    local menuName = menu:GetName()
    if menuName then
        for _, suffix in ipairs(DROPDOWN_MENU_SUFFIXES) do
            local child = _G[menuName .. suffix]
            if child then
                if child.Hide then
                    child:Hide()
                end
                if child.EnableMouse then
                    child:EnableMouse(false)
                end
                if child.SetAlpha then
                    child:SetAlpha(0)
                end
            end
        end
    end
end

function LPL:CreateDropdown(name, parent, width)
    local dropdownWidth = width or 150
    local container = CreateFrame("Frame", name, parent)
    container:SetSize(dropdownWidth, 52)

    local title = self:CreateLabel(container, "small")
    title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    title:SetTextColor(Theme:GetColor("textLabel"))

    local box = self:CreateButton(nil, container)
    box:SetSize(dropdownWidth, 28)
    box:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    box.label:ClearAllPoints()
    box.label:SetPoint("LEFT", box, "LEFT", 10, 0)
    box.label:SetPoint("RIGHT", box, "RIGHT", -26, 0)
    box.label:SetJustifyH("LEFT")

    local arrow = box:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    arrow:SetTexCoord(0, 1, 0, 1)
    arrow:SetVertexColor(1, 0.92, 0.4)

    local menu = CreateFrame("Frame", name and (name .. "Menu") or nil, container, "UIDropDownMenuTemplate")
    HideDropDownMenuChrome(menu)
    UIDropDownMenu_SetWidth(menu, dropdownWidth)
    C_Timer.After(0, function()
        if menu then
            HideDropDownMenuChrome(menu)
        end
    end)

    container.title = title
    container.box = box
    container.menu = menu
    container.items = {}
    container.selectedID = nil

    box:SetScript("OnClick", function()
        if container.disabled then
            return
        end
        ToggleDropDownMenu(1, nil, menu, box, 0, 0)
    end)

    function container:SetLabel(text)
        self.title:SetText(text)
    end

    function container:SetDisplayText(labelText)
        self.box:SetText(labelText or "")
    end

    function container:Refresh()
        local owner = self
        UIDropDownMenu_Initialize(self.menu, function()
            for _, item in ipairs(owner.items) do
                local info = UIDropDownMenu_CreateInfo()
                if item.isHeader then
                    info.text = item.name or ""
                    info.isTitle = true
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info)
                else
                    info.text = item.name
                    info.checked = item.id == owner.selectedID
                        or (item.id ~= nil and owner.selectedID ~= nil and tostring(item.id) == tostring(owner.selectedID))
                    info.func = function()
                        owner.selectedID = item.id
                        CloseDropDownMenus()
                        owner:SetDisplayText(item.name)
                        if owner.onSelect then
                            owner.onSelect(item.id, item)
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)

        local selectedName = "Select..."
        for _, item in ipairs(self.items) do
            if not item.isHeader and (
                item.id == self.selectedID
                or (item.id ~= nil and self.selectedID ~= nil and tostring(item.id) == tostring(self.selectedID))
            ) then
                selectedName = item.name
                break
            end
        end
        self:SetDisplayText(selectedName)
    end

    function container:SetItems(items, selectedID, onSelect)
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
        self:Refresh()
    end

    function container:SetEnabled(enabled)
        self.disabled = not enabled
        if enabled then
            self.box:Enable()
            self.box:SetAlpha(1)
        else
            self.box:Disable()
            self.box:SetAlpha(0.5)
        end
    end

    return container
end
