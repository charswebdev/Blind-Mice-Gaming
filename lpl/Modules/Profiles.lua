local addonName, LPL = ...

LPL.Profiles = LPL.Profiles or {}

local ProfilesModule = {
    id = "profiles",
    label = "Profiles",
    description = "Save every LPL vault in a profile. Create, rename, load, delete, export, and import.",
    iconStem = "profiles_64",
    order = 80,
    instance = nil,
}

local PREFIX = "!LPLP1!"

local function Say(text)
    if LPL.SafePrintf then
        LPL:SafePrintf("|cff33CCFFLight Paws:|r %s", text)
    else
        print("|cff33CCFFLight Paws:|r " .. tostring(text))
    end
end

local function PopupEditBox(dialog)
    if dialog.GetEditBox then
        return dialog:GetEditBox()
    end
    return dialog.editBox
end

local function PressAccept(edit)
    local dialog = edit:GetParent()
    if dialog and not dialog.button1 then
        dialog = dialog:GetParent()
    end
    if dialog and dialog.button1 then
        dialog.button1:Click()
    end
end

function LPL.Profiles:ExportText(name)
    LPL.DB:GetActiveProfileName()
    local profile = LPL.DB.data.profiles[name]
    if type(profile) ~= "table" then
        return nil
    end
    local payload = {
        kind = "lpl-profile",
        version = 1,
        flavor = LPL.DB.PROFILE_FLAVOR,
        name = name,
        sections = LPL.DB:CopyProfileSections(profile),
    }
    if not (LPL.TalentShare and LPL.TalentShare.EncodeShareTable) then
        return nil
    end
    local encoded = LPL.TalentShare:EncodeShareTable(payload)
    if type(encoded) ~= "string" or encoded == "" then
        return nil
    end
    return PREFIX .. encoded
end

function LPL.Profiles:ImportText(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #PREFIX) ~= PREFIX then
        return false, "bad_format"
    end
    if not (LPL.TalentShare and LPL.TalentShare.DecodeShareString) then
        return false, "bad_format"
    end
    local ok, source = LPL.TalentShare:DecodeShareString(text:sub(#PREFIX + 1))
    if not ok or type(source) ~= "table" or source.kind ~= "lpl-profile" or tonumber(source.version) ~= 1 then
        return false, "bad_format"
    end
    if source.flavor ~= LPL.DB.PROFILE_FLAVOR then
        return false, "flavor"
    end
    local installed, name = LPL.DB:InstallProfile(source.name, source.sections)
    if not installed then
        return false, name or "bad_name"
    end
    return true, name, LPL.DB:CountProfilePlaces(name)
end

function ProfilesModule:EnsureDialogs()
    if self._dialogs then
        return
    end
    self._dialogs = true

    local export = CreateFrame("Frame", "LPLProfileExportDialog", UIParent, "BackdropTemplate")
    export:SetSize(520, 320)
    export:SetPoint("CENTER")
    export:SetFrameStrata("FULLSCREEN_DIALOG")
    export:EnableMouse(true)
    export:Hide()
    LPL.Theme:ApplyBackdrop(export, "panel", "bgElevated", "border")
    local exportTitle = LPL:CreateLabel(export, "title")
    exportTitle:SetPoint("TOPLEFT", 16, -14)
    exportTitle:SetText("Export profile")
    local exportHint = LPL:CreateLabel(export, "body")
    exportHint:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -6)
    exportHint:SetText("Copy this code. It contains every saved set in the profile.")
    local scroll = CreateFrame("ScrollFrame", nil, export, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -64)
    scroll:SetPoint("BOTTOMRIGHT", -32, 52)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(450)
    edit:SetHeight(180)
    edit:SetScript("OnEscapePressed", function()
        export:Hide()
    end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    scroll:SetScrollChild(edit)
    export.editBox = edit
    local closeBtn = LPL:CreateButton("LPLProfileExportClose", export)
    closeBtn:SetSize(88, 26)
    closeBtn:SetPoint("BOTTOM", 0, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        export:Hide()
    end)
    self.exportDialog = export

    local import = CreateFrame("Frame", "LPLProfileImportDialog", UIParent, "BackdropTemplate")
    import:SetSize(520, 320)
    import:SetPoint("CENTER")
    import:SetFrameStrata("FULLSCREEN_DIALOG")
    import:EnableMouse(true)
    import:Hide()
    LPL.Theme:ApplyBackdrop(import, "panel", "bgElevated", "border")
    local importTitle = LPL:CreateLabel(import, "title")
    importTitle:SetPoint("TOPLEFT", 16, -14)
    importTitle:SetText("Import profile")
    local importHint = LPL:CreateLabel(import, "body")
    importHint:SetPoint("TOPLEFT", importTitle, "BOTTOMLEFT", 0, -6)
    importHint:SetText("Paste a Light Paws profile code. It loads into the matching tabs.")
    local importScroll = CreateFrame("ScrollFrame", nil, import, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", 16, -64)
    importScroll:SetPoint("BOTTOMRIGHT", -32, 52)
    local importEdit = CreateFrame("EditBox", nil, importScroll)
    importEdit:SetMultiLine(true)
    importEdit:SetAutoFocus(false)
    importEdit:SetFontObject("ChatFontNormal")
    importEdit:SetWidth(450)
    importEdit:SetHeight(180)
    importEdit:SetScript("OnEscapePressed", function()
        import:Hide()
    end)
    importScroll:SetScrollChild(importEdit)
    import.editBox = importEdit
    local acceptBtn = LPL:CreateButton("LPLProfileImportAccept", import)
    acceptBtn:SetSize(88, 26)
    acceptBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    acceptBtn:SetText("Import")
    acceptBtn:SetScript("OnClick", function()
        ProfilesModule:AcceptImport()
    end)
    local cancelBtn = LPL:CreateButton("LPLProfileImportCancel", import)
    cancelBtn:SetSize(88, 26)
    cancelBtn:SetPoint("RIGHT", acceptBtn, "LEFT", -8, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        import:Hide()
    end)
    self.importDialog = import

    StaticPopupDialogs["LPL_NEW_VAULT_PROFILE"] = {
        text = "Name the new profile. It starts empty. Saved sets stay in the profile you were using.",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 40,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog)
            local box = PopupEditBox(dialog)
            if box then
                box:SetText("")
                box:SetFocus()
            end
        end,
        OnAccept = function(dialog)
            local box = PopupEditBox(dialog)
            local ok, result = LPL.DB:CreateProfile(box and box:GetText() or "")
            if ok then
                Say("Profile created: " .. result)
                ProfilesModule:Refresh()
            elseif result == "exists" then
                Say("A profile with that name already exists.")
            else
                Say("Enter a profile name.")
            end
        end,
        EditBoxOnEnterPressed = PressAccept,
    }

    StaticPopupDialogs["LPL_RENAME_VAULT_PROFILE"] = {
        text = "Rename %s. The saved sets stay with this profile.",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 40,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog)
            local box = PopupEditBox(dialog)
            local current = dialog.data or ProfilesModule._renameName or ""
            if box then
                box:SetText(current)
                box:HighlightText()
                box:SetFocus()
            end
        end,
        OnAccept = function(dialog, data)
            local oldName = data or dialog.data or ProfilesModule._renameName
            local box = PopupEditBox(dialog)
            local ok, result = LPL.DB:RenameProfile(oldName, box and box:GetText() or "")
            if ok then
                if result ~= oldName then
                    Say("Renamed profile to " .. result .. ".")
                end
                ProfilesModule:Refresh()
            elseif result == "exists" then
                Say("A profile with that name already exists.")
            elseif result == "bad_name" then
                Say("Enter a profile name.")
            else
                Say("That profile does not exist.")
            end
        end,
        EditBoxOnEnterPressed = PressAccept,
    }

    StaticPopupDialogs["LPL_DELETE_VAULT_PROFILE"] = {
        text = "Delete profile %s? Every saved set in that profile is removed.",
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data)
            local ok, nextName = LPL.DB:DeleteProfile(data)
            if ok then
                Say("Deleted profile. Now using " .. tostring(nextName) .. ".")
                ProfilesModule:Refresh()
            else
                Say("Keep at least one profile.")
            end
        end,
    }
end

function ProfilesModule:ShowExport(name)
    self:EnsureDialogs()
    local text = LPL.Profiles:ExportText(name)
    if not text then
        Say("Could not export that profile.")
        return
    end
    self.exportDialog.editBox:SetText(text)
    self.exportDialog:Show()
    self.exportDialog.editBox:SetFocus()
    self.exportDialog.editBox:HighlightText()
    if LPL.DB:CountProfilePlaces(name) == 0 then
        Say("Exported " .. name .. ". It has no saved sets yet.")
    end
end

function ProfilesModule:ShowImport()
    self:EnsureDialogs()
    self.importDialog.editBox:SetText("")
    self.importDialog:Show()
    self.importDialog.editBox:SetFocus()
end

function ProfilesModule:AcceptImport()
    local text = self.importDialog.editBox:GetText() or ""
    local ok, name, count = LPL.Profiles:ImportText(text)
    if ok then
        Say(string.format("Imported profile %s with %d saved sets.", name, count or 0))
        self.importDialog:Hide()
        self:Refresh()
    elseif name == "flavor" then
        Say("That profile is for a different Light Paws version.")
    else
        Say("Could not import that profile. Paste a Light Paws profile code.")
    end
end

function ProfilesModule:PromptCreate()
    self:EnsureDialogs()
    StaticPopup_Show("LPL_NEW_VAULT_PROFILE")
end

function ProfilesModule:PromptRename(name)
    self:EnsureDialogs()
    self._renameName = name
    StaticPopup_Show("LPL_RENAME_VAULT_PROFILE", name, nil, name)
end

function ProfilesModule:PromptDelete(name)
    self:EnsureDialogs()
    if #LPL.DB:ListProfiles() <= 1 then
        Say("Keep at least one profile.")
        return
    end
    StaticPopup_Show("LPL_DELETE_VAULT_PROFILE", name, nil, name)
end

function ProfilesModule:Load(name)
    local ok, result = LPL.DB:LoadProfile(name)
    if ok then
        Say("Loaded profile: " .. result)
        self:Refresh()
    else
        Say("That profile does not exist.")
    end
end

function ProfilesModule:Refresh()
    local frame = self.instance
    if not frame or not frame.rows then
        return
    end
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end
    local names = LPL.DB:ListProfiles()
    local active = LPL.DB:GetActiveProfileName()
    local y = -4
    local width = math.max(240, (frame.scroll:GetWidth() or 480) - 8)
    for index, name in ipairs(names) do
        local row = frame.rows[index] or self:CreateRow(index)
        row:SetWidth(width)
        self:StyleRow(row, name, name == active, LPL.DB:CountProfilePlaces(name))
        row:SetPoint("TOPLEFT", 0, y)
        row:Show()
        y = y - row:GetHeight() - 8
    end
    frame.content:SetSize(width, math.max(1, -y))
end

function ProfilesModule:CreateRow(index)
    local parent = self.instance.content
    local row = LPL:CreatePanel("LPLProfileRow" .. index, parent)
    row:SetHeight(72)
    row.nameText = LPL:CreateLabel(row, "bold")
    row.nameText:SetPoint("TOPLEFT", 12, -10)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.nameText:SetJustifyH("LEFT")
    row.detail = LPL:CreateLabel(row, "body")
    row.detail:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    local function button(text, width)
        local btn = LPL:CreateButton(nil, row)
        btn:SetSize(width, 22)
        btn:SetText(text)
        return btn
    end
    row.loadBtn = button("Load", 64)
    row.renameBtn = button("Rename", 72)
    row.exportBtn = button("Export", 68)
    row.deleteBtn = button("Delete", 64)
    row.loadBtn:SetPoint("BOTTOMLEFT", 10, 8)
    row.renameBtn:SetPoint("LEFT", row.loadBtn, "RIGHT", 6, 0)
    row.exportBtn:SetPoint("LEFT", row.renameBtn, "RIGHT", 6, 0)
    row.deleteBtn:SetPoint("LEFT", row.exportBtn, "RIGHT", 6, 0)
    row.loadBtn:SetScript("OnClick", function(self)
        if self.profileName and self.profileName ~= LPL.DB:GetActiveProfileName() then
            ProfilesModule:Load(self.profileName)
        end
    end)
    row.renameBtn:SetScript("OnClick", function(self)
        ProfilesModule:PromptRename(self.profileName)
    end)
    row.exportBtn:SetScript("OnClick", function(self)
        ProfilesModule:ShowExport(self.profileName)
    end)
    row.deleteBtn:SetScript("OnClick", function(self)
        ProfilesModule:PromptDelete(self.profileName)
    end)
    self.instance.rows[index] = row
    return row
end

function ProfilesModule:StyleRow(row, name, loaded, count)
    row.profileName = name
    row.nameText:SetText(name)
    if loaded then
        row.detail:SetText(string.format("Loaded · %d saved", count))
        row.detail:SetTextColor(LPL.Theme:GetColor("accent"))
        row.loadBtn:SetText("Loaded")
    else
        row.detail:SetText(string.format("%d saved", count))
        row.detail:SetTextColor(LPL.Theme:GetColor("text"))
        row.loadBtn:SetText("Load")
    end
    row.loadBtn.profileName = name
    row.renameBtn.profileName = name
    row.exportBtn.profileName = name
    row.deleteBtn.profileName = name
end

function ProfilesModule.create(parent)
    local frame = CreateFrame("Frame", "LPLProfilesModule", parent)
    frame:SetAllPoints(parent)
    ProfilesModule.instance = frame
    frame.rows = {}

    local title = LPL:CreateLabel(frame, "title")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetText("Profiles")

    local hint = LPL:CreateLabel(frame, "body")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText("Each profile stores every saved set. Load one, then use the other tabs. Export copies the whole profile.")

    local createBtn = LPL:CreateButton("LPLProfileCreate", frame)
    createBtn:SetSize(110, 28)
    createBtn:SetPoint("BOTTOMLEFT", 24, 16)
    createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        ProfilesModule:PromptCreate()
    end)
    local importBtn = LPL:CreateButton("LPLProfileImport", frame)
    importBtn:SetSize(110, 28)
    importBtn:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        ProfilesModule:ShowImport()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -12)
    scroll:SetPoint("BOTTOMRIGHT", -36, 56)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
    frame.content = content

    ProfilesModule:EnsureDialogs()
    ProfilesModule:Refresh()
    frame:Hide()
    return frame
end

function ProfilesModule:OnShow()
    self:Refresh()
end

LPL.Modules:Register({
    id = ProfilesModule.id,
    label = ProfilesModule.label,
    description = ProfilesModule.description,
    iconStem = ProfilesModule.iconStem,
    order = ProfilesModule.order,
    create = ProfilesModule.create,
    OnShow = function()
        ProfilesModule:OnShow()
    end,
})
