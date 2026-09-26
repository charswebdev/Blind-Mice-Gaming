--[[
  BMG Unit Frames — import / export popups
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.ShareDialog = UF.ShareDialog or {}
local ShareDialog = UF.ShareDialog

local function Speak(text)
    if UF.Speech and UF.Speech.Say then
        UF.Speech.Say(text)
    end
end

local function Paint(frame, r, g, b)
    if UF.Widgets and UF.Widgets.Paint then
        UF.Widgets.Paint(frame, r or 0.04, g or 0.04, b or 0.05, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    end
end

local function Raise(btn, parent)
    if not btn then
        return
    end
    btn:EnableMouse(true)
    btn:SetFrameStrata("FULLSCREEN_DIALOG")
    local level = (parent and parent.GetFrameLevel and parent:GetFrameLevel() or 120) + 8
    btn:SetFrameLevel(level)
end

local function Unlimited(box)
    if not box then
        return
    end
    if box.SetMaxLetters then
        box:SetMaxLetters(0)
    end
    if box.SetMaxBytes then
        box:SetMaxBytes(0)
    end
end

local function SetStatus(frame, text, bad)
    if not frame.status then
        return
    end
    if bad then
        frame.status:SetTextColor(1, 0.4, 0.32, 1)
    else
        frame.status:SetTextColor(0.75, 0.9, 0.55, 1)
    end
    frame.status:SetText(text or "")
end

local function SizeCode(frame)
    local box = frame.code
    if not box then
        return
    end
    local text = box:GetText() or ""
    local n = #text
    local lines = math.floor(n / 42) + 4
    if lines < 8 then
        lines = 8
    end
    if lines > 200 then
        lines = 200
    end
    box:SetHeight(lines * 14)
    if frame.count then
        frame.count:SetText(tostring(n) .. " characters")
    end
end

local function RunImport(frame)
    if frame.nameBox then
        frame.nameBox:ClearFocus()
    end
    if frame.code then
        frame.code:ClearFocus()
    end
    local name = frame.nameBox and frame.nameBox:GetText() or ""
    local code = frame.code and frame.code:GetText() or ""
    if type(code) == "string" then
        code = code:gsub("%s+", "")
    end
    if type(code) ~= "string" or code == "" then
        local msg = "Paste a layout code, then Accept."
        SetStatus(frame, msg, true)
        Speak(msg)
        print("|cffff6600[BMG Unit Frames]|r " .. msg)
        return
    end
    if not UF.Share or not UF.Share.Import then
        SetStatus(frame, "Import is not ready.", true)
        Speak("Import is not ready.")
        return
    end
    local okCall, ok, msg = pcall(UF.Share.Import, code, name)
    if not okCall then
        SetStatus(frame, "That code could not be imported.", true)
        Speak("That code could not be imported.")
        print("|cffff6600[BMG Unit Frames]|r Import error.")
        return
    end
    SetStatus(frame, msg, not ok)
    Speak(msg)
    print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. msg)
    if ok then
        frame:Hide()
        if ShareDialog.shield then
            ShareDialog.shield:Hide()
        end
        if UF.Config and UF.Config.Refresh then
            UF.Config.Refresh()
        end
    end
end

local function Ensure()
    if ShareDialog.frame then
        return ShareDialog.frame
    end
    local tmpl = UF.Compat and UF.Compat.BackdropTemplate and UF.Compat.BackdropTemplate() or nil

    local shield = CreateFrame("Button", "BMGUnitFramesShareShield", UIParent)
    shield:SetAllPoints(UIParent)
    shield:SetFrameStrata("FULLSCREEN_DIALOG")
    shield:SetFrameLevel(90)
    shield:EnableMouse(true)
    shield:RegisterForClicks("AnyUp")
    shield:Hide()
    ShareDialog.shield = shield

    local frame = CreateFrame("Frame", "BMGUnitFramesShareDialog", UIParent, tmpl)
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(120)
    frame:EnableMouse(true)
    frame:Hide()
    Paint(frame)
    tinsert(UISpecialFrames, "BMGUnitFramesShareDialog")

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(36)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame:SetMovable(true)

    local title = UF.Widgets.Label(bar, 16, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    title:SetPoint("LEFT", 14, 0)
    frame.title = title

    local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 2, 0)
    close:SetScript("OnClick", function()
        frame:Hide()
        shield:Hide()
        Speak("Share window closed.")
    end)

    local hint = UF.Widgets.Label(frame, 12, 0.72, 0.72, 0.70)
    hint:SetPoint("TOPLEFT", 16, -44)
    hint:SetPoint("TOPRIGHT", -16, -44)
    hint:SetJustifyH("LEFT")
    if hint.SetWordWrap then
        hint:SetWordWrap(true)
    end
    frame.hint = hint

    local status = UF.Widgets.Label(frame, 13, 1, 0.4, 0.32)
    status:SetPoint("TOPLEFT", 16, -64)
    status:SetPoint("TOPRIGHT", -16, -64)
    status:SetText("")
    frame.status = status

    local nameLabel = UF.Widgets.Label(frame, 12, 0.92, 0.92, 0.88)
    nameLabel:SetPoint("TOPLEFT", 16, -86)
    nameLabel:SetText("Profile name")
    frame.nameLabel = nameLabel

    local nameBox = CreateFrame("EditBox", "BMGUnitFramesShareName", frame, "InputBoxTemplate")
    nameBox:SetPoint("TOPLEFT", 22, -106)
    nameBox:SetSize(300, 24)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)
    nameBox:SetFontObject(ChatFontNormal)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    nameBox:SetScript("OnEnterPressed", function()
        RunImport(frame)
    end)
    frame.nameBox = nameBox

    local codeLabel = UF.Widgets.Label(frame, 12, 0.92, 0.92, 0.88)
    codeLabel:SetPoint("TOPLEFT", 16, -138)
    codeLabel:SetText("Layout code")
    frame.codeLabel = codeLabel

    local count = UF.Widgets.Label(frame, 11, 0.6, 0.6, 0.58)
    count:SetPoint("LEFT", codeLabel, "RIGHT", 10, 0)
    count:SetText("0 characters")
    frame.count = count

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(56)
    footer:EnableMouse(true)
    footer:SetFrameLevel(frame:GetFrameLevel() + 12)
    frame.footer = footer

    local hold = CreateFrame("Frame", nil, frame, tmpl)
    hold:SetPoint("TOPLEFT", 16, -158)
    hold:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -16, 8)
    hold:EnableMouse(true)
    if hold.SetClipsChildren then
        hold:SetClipsChildren(true)
    end
    Paint(hold, 0.02, 0.02, 0.03)
    frame.hold = hold

    local scroll = CreateFrame("ScrollFrame", "BMGUnitFramesShareScroll", hold)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    scroll:EnableMouse(true)

    local code = CreateFrame("EditBox", "BMGUnitFramesShareCode", scroll)
    code:SetMultiLine(true)
    code:SetAutoFocus(false)
    code:SetFontObject(ChatFontNormal)
    code:SetTextColor(0.95, 0.90, 0.70, 1)
    code:SetWidth(500)
    code:SetHeight(180)
    Unlimited(code)
    code:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    code:SetScript("OnTextChanged", function()
        SizeCode(frame)
    end)
    scroll:SetScrollChild(code)
    frame.code = code
    frame.scroll = scroll

    local accept = UF.Widgets.Button(footer, "Accept", 120, 32)
    accept:SetPoint("RIGHT", -16, 0)
    Raise(accept, footer)
    frame.accept = accept

    local copy = UF.Widgets.Button(footer, "Copy", 100, 32)
    copy:SetPoint("RIGHT", accept, "LEFT", -8, 0)
    Raise(copy, footer)
    frame.copy = copy

    local cancel = UF.Widgets.Button(footer, "Close", 90, 32)
    cancel:SetPoint("LEFT", 16, 0)
    Raise(cancel, footer)
    cancel:SetScript("OnClick", function()
        frame:Hide()
        shield:Hide()
        Speak("Share window closed.")
    end)

    frame:SetScript("OnHide", function()
        shield:Hide()
    end)

    ShareDialog.frame = frame
    return frame
end

local function ShowMode(mode, presetCode, presetName)
    local frame = Ensure()
    frame.mode = mode
    SetStatus(frame, "", false)
    if ShareDialog.shield then
        ShareDialog.shield:Show()
        ShareDialog.shield:SetFrameLevel(90)
    end
    local current = UF.DB and UF.DB.CurrentName and UF.DB.CurrentName() or "Default"
    Unlimited(frame.code)
    if mode == "export" then
        frame.title:SetText("Export layout")
        frame.hint:SetText("The code is selected. Press control C, then paste it in Import on the other character.")
        frame.nameLabel:SetText("Profile name")
        frame.nameBox:SetText(current)
        frame.nameBox:ClearFocus()
        local code = presetCode
        if type(code) ~= "string" or code == "" then
            code = UF.Share and UF.Share.Export and UF.Share.Export() or ""
        end
        frame.code:SetText(code)
        SizeCode(frame)
        frame.code:HighlightText()
        frame.accept:SetLabel("Close")
        frame.accept:SetScript("OnClick", function()
            frame:Hide()
            if ShareDialog.shield then
                ShareDialog.shield:Hide()
            end
            Speak("Export closed.")
        end)
        frame.copy:Show()
        frame.copy:SetScript("OnClick", function()
            local text = frame.code:GetText() or ""
            local copied = UF.Compat and UF.Compat.CopyToClipboard and UF.Compat.CopyToClipboard(text)
            frame.code:HighlightText()
            local msg = copied and ("Copied " .. tostring(#text) .. " characters.") or "Code selected. Press control C to copy."
            SetStatus(frame, msg, not copied)
            Speak(msg)
            print("|cff00ff00[BMG Unit Frames]|r " .. msg)
        end)
        local copied = UF.Compat and UF.Compat.CopyToClipboard and UF.Compat.CopyToClipboard(code)
        Speak(copied and "Export ready. Code copied." or "Export ready. Press control C to copy.")
    else
        frame.title:SetText("Import layout")
        frame.hint:SetText("Paste the whole !BMGUF:1! code, type a name, then Accept.")
        frame.nameLabel:SetText("Save as name")
        frame.nameBox:SetText(presetName or current or "Imported")
        frame.code:SetText(presetCode or "")
        SizeCode(frame)
        frame.accept:SetLabel("Accept")
        frame.copy:Hide()
        frame.accept:SetScript("OnClick", function()
            RunImport(frame)
        end)
        Speak("Import layout. Paste the whole code, then Accept.")
    end
    frame:Show()
    frame:Raise()
    Raise(frame.accept, frame.footer)
    Raise(frame.copy, frame.footer)
end

function ShareDialog.ShowExport()
    ShowMode("export")
end

function ShareDialog.ShowImport(code, name)
    if type(code) == "string" and code ~= "" and not code:find("!BMGUF", 1, true) then
        name = code
        code = nil
    end
    ShowMode("import", code, name)
end
