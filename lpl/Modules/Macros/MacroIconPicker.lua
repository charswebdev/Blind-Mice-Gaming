local addonName, LPL = ...

LPL.MacroIconPicker = {}

local FRAME_NAME = "LPLMacroIconPicker"
local COLS = 8
local ICON_SIZE = 36
local ICON_PAD = 4

function LPL.MacroIconPicker:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(420, 480)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(220)
    frame:EnableMouse(true)
    frame:Hide()
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    LPL.Theme:ApplyBackdrop(titleBar, "panel", "titleBar", "border")

    local title = LPL:CreateLabel(titleBar, "header")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    title:SetText("Choose Macro Icon")

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        frame:Hide()
        if frame.onCancel then
            frame.onCancel()
        end
    end)

    local sectionDrop = LPL:CreateDropdown(nil, frame, 150)
    sectionDrop:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 12, -8)
    sectionDrop:SetLabel("Section")
    frame.sectionDrop = sectionDrop

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", sectionDrop, "TOPRIGHT", 16, 0)
    searchLabel:SetText("Search")
    searchLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(160, 24)
    searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -4)
    frame.searchBox = searchBox

    local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countLabel:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    countLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
    frame.countLabel = countLabel

    local gridHost = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    gridHost:SetPoint("TOPLEFT", sectionDrop, "BOTTOMLEFT", 0, -12)
    gridHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 48)
    LPL.Theme:ApplyBackdrop(gridHost, "panel", "bgElevated", "border")

    local scroll = CreateFrame("ScrollFrame", nil, gridHost, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", gridHost, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", gridHost, "BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
    frame.content = content
    frame.iconButtons = {}

    local okButton = LPL:CreateButton(nil, frame)
    okButton:SetSize(100, 28)
    okButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    okButton:SetText("OK")
    frame.okButton = okButton

    local cancelButton = LPL:CreateButton(nil, frame)
    cancelButton:SetSize(100, 28)
    cancelButton:SetPoint("RIGHT", okButton, "LEFT", -8, 0)
    cancelButton:SetText("Cancel")

    cancelButton:SetScript("OnClick", function()
        frame:Hide()
        if frame.onCancel then
            frame.onCancel()
        end
    end)

    okButton:SetScript("OnClick", function()
        local texture = frame.selectedTexture
        frame:Hide()
        if frame.onSelect and texture ~= nil then
            frame.onSelect(texture)
        end
    end)

    searchBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            frame:RebuildGrid()
        end
    end)

    function frame:ClearIconButtons()
        for _, btn in ipairs(self.iconButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        wipe(self.iconButtons)
    end

    function frame:RebuildGrid()
        self:ClearIconButtons()
        local entries = LPL.MacroIcons:Filter(self.sectionKey or "all", self.searchBox:GetText() or "")
        self.countLabel:SetText(string.format("%d icons", #entries))

        local width = (ICON_SIZE + ICON_PAD) * COLS
        local rows = math.max(1, math.ceil(#entries / COLS))
        self.content:SetSize(width, rows * (ICON_SIZE + ICON_PAD))

        for index, entry in ipairs(entries) do
            local btn = CreateFrame("Button", nil, self.content)
            btn:SetSize(ICON_SIZE, ICON_SIZE)
            local col = (index - 1) % COLS
            local row = math.floor((index - 1) / COLS)
            btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * (ICON_SIZE + ICON_PAD), -row * (ICON_SIZE + ICON_PAD))

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(btn)
            LPL.MacroIcons:SetTexture(tex, entry.texture)
            btn.textureValue = entry.texture

            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints(btn)
            highlight:SetColorTexture(1, 1, 1, 0.2)

            local selected = btn:CreateTexture(nil, "OVERLAY")
            selected:SetAllPoints(btn)
            selected:SetColorTexture(1, 0.92, 0.4, 0.35)
            selected:Hide()
            btn.selectedOverlay = selected

            btn:SetScript("OnClick", function()
                self.selectedTexture = entry.texture
                for _, other in ipairs(self.iconButtons) do
                    if other.selectedOverlay then
                        other.selectedOverlay:SetShown(tostring(other.textureValue) == tostring(self.selectedTexture))
                    end
                end
                self.okButton:SetEnabled(true)
            end)

            if self.selectedTexture ~= nil and tostring(self.selectedTexture) == tostring(entry.texture) then
                selected:Show()
            end

            self.iconButtons[#self.iconButtons + 1] = btn
        end
    end

    function frame:BuildSections()
        local catalog = LPL.MacroIcons:GetCatalog()
        local items = {}
        for _, section in ipairs(catalog.sections) do
            items[#items + 1] = { id = section.key, name = section.label }
        end
        self.sectionDrop:SetItems(items, self.sectionKey or "all", function(id)
            self.sectionKey = id or "all"
            self:RebuildGrid()
        end)
    end

    self.frame = frame
    return frame
end

function LPL.MacroIconPicker:Show(currentTexture, onSelect, onCancel)
    local frame = self:EnsureFrame()
    frame.onSelect = onSelect
    frame.onCancel = onCancel
    frame.selectedTexture = currentTexture or LPL.MacroIcons:GetQuestionMark()
    frame.sectionKey = "all"
    frame.searchBox:SetText("")
    LPL.MacroIcons:Invalidate()
    frame:BuildSections()
    frame:RebuildGrid()
    frame.okButton:SetEnabled(frame.selectedTexture ~= nil)
    frame:Show()
end

function LPL.MacroIconPicker:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
