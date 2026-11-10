local _, BMGAM = ...

BMGAM.Settings = BMGAM.Settings or {}
local Settings = BMGAM.Settings
local Theme = BMGAM.Theme
local PAGE = 4000

local function BindingText()
    if type(GetBindingKey) == "function" then
        local key = GetBindingKey("BMGAM_READUNDERMOUSE")
        if type(key) == "string" and key ~= "" then
            return key
        end
    end
    return "Not bound"
end

local function MinimapState()
    local account = BMGAM.DB and BMGAM.DB.Account and BMGAM.DB.Account() or nil
    if type(account) == "table" and account.minimap == false then
        return "Off"
    end
    return "On"
end

function Settings.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    title:SetJustifyH("LEFT")
    Theme.Font(title, 16, Theme.GOLD, "OUTLINE")
    title:SetText("Settings")

    local minimap = CreateFrame("Button", nil, frame)
    minimap:SetHeight(22)
    minimap:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    minimap:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    minimap.label = minimap:CreateFontString(nil, "OVERLAY")
    minimap.label:SetPoint("LEFT", 0, 0)
    minimap.label:SetJustifyH("LEFT")
    Theme.Font(minimap.label, 13, Theme.CREAM, "")
    minimap.label:SetText("Show minimap button")
    minimap.value = minimap:CreateFontString(nil, "OVERLAY")
    minimap.value:SetPoint("RIGHT", 0, 0)
    minimap.value:SetJustifyH("RIGHT")
    Theme.Font(minimap.value, 13, Theme.GOLD, "OUTLINE")
    minimap.value:SetText(MinimapState())
    minimap:SetScript("OnClick", function()
        local account = BMGAM.DB.Account()
        account.minimap = account.minimap == false
        if BMGAM.Minimap and BMGAM.Minimap.Refresh then
            BMGAM.Minimap.Refresh()
        end
        minimap.value:SetText(MinimapState())
    end)
    frame.minimapValue = minimap.value

    local minimapNote = frame:CreateFontString(nil, "OVERLAY")
    minimapNote:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -2)
    minimapNote:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    minimapNote:SetJustifyH("LEFT")
    minimapNote:SetWordWrap(true)
    Theme.Font(minimapNote, 12, Theme.DIM, "")
    minimapNote:SetText("The minimap button uses the addon icon.")

    local readRow = CreateFrame("Frame", nil, frame)
    readRow:SetHeight(22)
    readRow:SetPoint("TOPLEFT", minimapNote, "BOTTOMLEFT", 0, -10)
    readRow:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    readRow.label = readRow:CreateFontString(nil, "OVERLAY")
    readRow.label:SetPoint("LEFT", 0, 0)
    readRow.label:SetJustifyH("LEFT")
    Theme.Font(readRow.label, 13, Theme.CREAM, "")
    readRow.label:SetText("Read under the mouse")
    readRow.value = readRow:CreateFontString(nil, "OVERLAY")
    readRow.value:SetPoint("RIGHT", 0, 0)
    readRow.value:SetJustifyH("RIGHT")
    Theme.Font(readRow.value, 13, Theme.GOLD, "OUTLINE")
    readRow.value:SetText(BindingText())
    frame.bindingValue = readRow.value

    local slashRow = CreateFrame("Frame", nil, frame)
    slashRow:SetHeight(22)
    slashRow:SetPoint("TOPLEFT", readRow, "BOTTOMLEFT", 0, -6)
    slashRow:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    slashRow.label = slashRow:CreateFontString(nil, "OVERLAY")
    slashRow.label:SetPoint("LEFT", 0, 0)
    slashRow.label:SetJustifyH("LEFT")
    Theme.Font(slashRow.label, 13, Theme.CREAM, "")
    slashRow.label:SetText("Slash command")
    slashRow.value = slashRow:CreateFontString(nil, "OVERLAY")
    slashRow.value:SetPoint("RIGHT", 0, 0)
    slashRow.value:SetJustifyH("RIGHT")
    Theme.Font(slashRow.value, 13, Theme.GOLD, "OUTLINE")
    slashRow.value:SetText("/avread")

    local readNote = frame:CreateFontString(nil, "OVERLAY")
    readNote:SetPoint("TOPLEFT", slashRow, "BOTTOMLEFT", 0, -2)
    readNote:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    readNote:SetJustifyH("LEFT")
    readNote:SetWordWrap(true)
    Theme.Font(readNote, 12, Theme.DIM, "")
    readNote:SetText("Reading aloud happens only when this key is pressed, or when /avread is typed. It reads what is under the mouse. Nothing is read on its own.")

    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(26)
    header:SetPoint("TOPLEFT", readNote, "BOTTOMLEFT", 0, -16)
    header:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    header.title = header:CreateFontString(nil, "OVERLAY")
    header.title:SetPoint("LEFT", 0, 0)
    header.title:SetJustifyH("LEFT")
    Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
    header.title:SetText("Export / Import")

    local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    popup:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    popup:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 0)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(40)
    Theme.Paint(popup, Theme.PANEL, Theme.GOLD)
    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetPoint("TOPLEFT", 12, -10)
    popup.title:SetJustifyH("LEFT")
    Theme.Font(popup.title, 15, Theme.GOLD, "OUTLINE")
    popup.error = popup:CreateFontString(nil, "OVERLAY")
    popup.error:SetPoint("LEFT", popup.title, "RIGHT", 12, 0)
    popup.error:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    popup.error:SetJustifyH("LEFT")
    Theme.Font(popup.error, 12, Theme.YELLOW, "")
    popup.error:SetText("")

    local box = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 10, -36)
    box:SetPoint("BOTTOMRIGHT", -10, 42)
    if box.SetClipsChildren then
        box:SetClipsChildren(true)
    end
    Theme.Paint(box, Theme.BG, Theme.GOLD_DIM)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    if scroll.SetClipsChildren then
        scroll:SetClipsChildren(true)
    end
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(PAGE)
    if edit.SetMaxBytes then
        edit:SetMaxBytes(PAGE)
    end
    edit:SetAltArrowKeyMode(false)
    edit:SetTextInsets(2, 2, 2, 2)
    edit:SetFont(GameFontNormal:GetFont(), 12, "")
    edit:SetTextColor(Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3], 1)
    edit:SetWidth(200)
    edit:SetHeight(20)
    scroll:SetScrollChild(edit)
    local function FitEdit()
        local width = scroll:GetWidth() - 4
        if width < 40 then
            width = 40
        end
        edit:SetWidth(width)
        scroll:UpdateScrollChildRect()
    end
    local function Wheel(_, delta)
        local current = scroll:GetVerticalScroll()
        local maxScroll = scroll:GetVerticalScrollRange()
        local nextScroll = current - (delta * 24)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        scroll:SetVerticalScroll(nextScroll)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", Wheel)
    scroll:SetScript("OnSizeChanged", FitEdit)
    edit:EnableMouseWheel(true)
    edit:SetScript("OnMouseWheel", Wheel)
    edit:SetScript("OnTextChanged", function()
        scroll:UpdateScrollChildRect()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)
    popup.edit = edit
    popup.scroll = scroll
    popup.FitEdit = FitEdit

    local function Button(text, width)
        local button = CreateFrame("Button", nil, popup, "BackdropTemplate")
        button:SetSize(width, 24)
        button:SetFrameLevel(popup:GetFrameLevel() + 10)
        Theme.Paint(button, Theme.BG, Theme.GOLD)
        button.label = button:CreateFontString(nil, "OVERLAY")
        button.label:SetPoint("CENTER")
        Theme.Font(button.label, 13, Theme.GOLD, "OUTLINE")
        button.label:SetText(text)
        return button
    end

    local importParts = {}
    local exportCode = ""
    local exportPage = 1

    local function PageCount(code)
        local length = type(code) == "string" and #code or 0
        if length < 1 then
            return 1
        end
        local count = math.ceil(length / PAGE)
        if count < 1 then
            return 1
        end
        return count
    end

    local function ShowExportPage()
        local pages = PageCount(exportCode)
        if exportPage < 1 then
            exportPage = 1
        end
        if exportPage > pages then
            exportPage = pages
        end
        local startAt = ((exportPage - 1) * PAGE) + 1
        local stopAt = startAt + PAGE - 1
        if stopAt > #exportCode then
            stopAt = #exportCode
        end
        local slice = ""
        if startAt <= #exportCode then
            slice = string.sub(exportCode, startAt, stopAt)
        end
        edit:SetMaxLetters(PAGE)
        if edit.SetMaxBytes then
            edit:SetMaxBytes(PAGE)
        end
        if popup.FitEdit then
            popup.FitEdit()
        end
        edit:SetText(slice)
        if popup.FitEdit then
            popup.FitEdit()
        end
        if popup.scroll then
            popup.scroll:SetVerticalScroll(0)
        end
        if pages > 1 then
            popup.title:SetText("Export " .. tostring(exportPage) .. " / " .. tostring(pages))
            popup.error:SetText("Copy this page, then Next.")
        else
            popup.title:SetText("Export")
            popup.error:SetText("")
        end
        edit:SetFocus()
        edit:HighlightText()
    end

    local prev = Button("Prev", 70)
    prev:SetPoint("BOTTOMLEFT", 10, 10)
    local nextPage = Button("Next", 70)
    nextPage:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    prev:SetScript("OnClick", function()
        exportPage = exportPage - 1
        ShowExportPage()
    end)
    nextPage:SetScript("OnClick", function()
        exportPage = exportPage + 1
        ShowExportPage()
    end)
    local load = Button("Load", 90)
    load:SetPoint("BOTTOMRIGHT", -108, 10)
    local add = Button("Add", 70)
    add:SetPoint("RIGHT", load, "LEFT", -8, 0)
    local close = Button("Close", 90)
    close:SetPoint("BOTTOMRIGHT", -10, 10)
    close:SetScript("OnClick", function()
        edit:ClearFocus()
        popup:Hide()
    end)
    add:SetScript("OnClick", function()
        local text = edit:GetText() or ""
        if text == "" then
            return
        end
        importParts[#importParts + 1] = text
        edit:SetText("")
        edit:SetFocus()
        edit:SetCursorPosition(0)
        popup.error:SetText("Added " .. tostring(#importParts) .. ". Paste the next page, or Load.")
    end)
    load:SetScript("OnClick", function()
        local parts = {}
        local index = 1
        while importParts[index] do
            parts[#parts + 1] = importParts[index]
            index = index + 1
        end
        local current = edit:GetText() or ""
        if current ~= "" then
            parts[#parts + 1] = current
        end
        local pack = BMGAM.Transfer and BMGAM.Transfer.Decode and BMGAM.Transfer.Decode(table.concat(parts)) or nil
        if not pack then
            popup.error:SetText("That code could not be read.")
            return
        end
        if not BMGAM.Transfer.Apply(pack) then
            popup.error:SetText("That code is not a Forever export.")
            return
        end
        importParts = {}
        popup:Hide()
        if BMGAM.Window then
            if not BMGAM.DB.Get(BMGAM.Window.selected) then
                local player = UnitGUID and UnitGUID("player") or nil
                if player and BMGAM.DB.Get(player) then
                    BMGAM.Window.selected = player
                else
                    local list = BMGAM.DB.List()
                    BMGAM.Window.selected = list[1] and list[1].guid or nil
                end
            end
            if BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end
    end)
    popup.load = load
    popup.add = add
    popup.prev = prev
    popup.nextPage = nextPage
    popup:Hide()

    local function OpenImport()
        importParts = {}
        popup.title:SetText("Import")
        popup.error:SetText("Add each copied page, then Load.")
        popup.load:Show()
        popup.add:Show()
        popup.prev:Hide()
        popup.nextPage:Hide()
        edit:SetMaxLetters(PAGE)
        if edit.SetMaxBytes then
            edit:SetMaxBytes(PAGE)
        end
        edit:SetText("")
        popup:Show()
        if popup.FitEdit then
            popup.FitEdit()
        end
        if popup.scroll then
            popup.scroll:SetVerticalScroll(0)
        end
        edit:SetFocus()
        edit:SetCursorPosition(0)
    end

    local function OpenExport()
        popup.load:Hide()
        popup.add:Hide()
        popup.prev:Show()
        popup.nextPage:Show()
        popup.error:SetText("")
        edit:SetText("")
        popup:Show()
        exportCode = ""
        exportPage = 1
        local code = nil
        if BMGAM.Transfer and BMGAM.Transfer.Encode then
            local encoded, value = pcall(BMGAM.Transfer.Encode)
            if encoded and type(value) == "string" then
                code = value
            end
        end
        if type(code) ~= "string" or code == "" then
            popup.title:SetText("Export")
            popup.error:SetText("This data could not be written.")
            return
        end
        exportCode = code
        ShowExportPage()
    end

    local exportButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    exportButton:SetSize(80, 22)
    exportButton:SetPoint("RIGHT", 0, 0)
    Theme.Paint(exportButton, Theme.BG, Theme.GOLD)
    exportButton.label = exportButton:CreateFontString(nil, "OVERLAY")
    exportButton.label:SetPoint("CENTER")
    Theme.Font(exportButton.label, 12, Theme.GOLD, "OUTLINE")
    exportButton.label:SetText("Export")
    exportButton:SetScript("OnClick", OpenExport)

    local importButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    importButton:SetSize(80, 22)
    importButton:SetPoint("RIGHT", exportButton, "LEFT", -8, 0)
    Theme.Paint(importButton, Theme.BG, Theme.GOLD)
    importButton.label = importButton:CreateFontString(nil, "OVERLAY")
    importButton.label:SetPoint("CENTER")
    Theme.Font(importButton.label, 12, Theme.GOLD, "OUTLINE")
    importButton.label:SetText("Import")
    importButton:SetScript("OnClick", OpenImport)

    frame:SetScript("OnHide", function()
        popup:Hide()
        edit:ClearFocus()
    end)

    local watch = CreateFrame("Frame", nil, frame)
    watch:RegisterEvent("UPDATE_BINDINGS")
    watch:SetScript("OnEvent", function()
        if BMGAM.Window and BMGAM.Window.tab == "settings" and frame.bindingValue then
            frame.bindingValue:SetText(BindingText())
        end
    end)

    function frame:Refresh()
        if frame.minimapValue then
            frame.minimapValue:SetText(MinimapState())
        end
        if frame.bindingValue then
            frame.bindingValue:SetText(BindingText())
        end
    end

    return frame
end
