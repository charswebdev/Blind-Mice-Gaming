local _, LPL = ...

LPL.Profiles = LPL.Profiles or {}
local Profiles = LPL.Profiles

local PREFIX = "!LPLP1!"
local FLAVOR = "forever"
local KEYS = {
    "talents",
    "actionbars",
    "keybinds",
    "equipment",
    "editmode",
    "loadouts",
    "macros",
    "addonsets",
    "addonprofiles",
}

local COUNT_FIELD = {
    talents = "builds",
    actionbars = "sets",
    keybinds = "sets",
    equipment = "sets",
    editmode = "sets",
    loadouts = "sets",
    macros = "sets",
    addonsets = "sets",
    addonprofiles = "sets",
}

local function Speak(text)
    print("|cff00ff00[Light Paws Loadouts]|r " .. tostring(text))
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function PlainName(name)
    local text = LPL.PlainString and LPL:PlainString(name) or nil
    if type(text) ~= "string" then
        if Secret(name) or type(name) ~= "string" then
            return nil
        end
        text = name
    end
    text = text:gsub("[\r\n]", " ")
    text = text:match("^%s*(.-)%s*$") or ""
    if #text > 40 then
        text = text:sub(1, 40):match("^%s*(.-)%s*$") or ""
    end
    if text == "" then
        return nil
    end
    return text
end

local function CopyStored(value, seen)
    if Secret(value) then
        return nil
    end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    end
    if kind ~= "table" then
        return nil
    end
    seen = seen or {}
    if seen[value] then
        return {}
    end
    seen[value] = true
    local copy = {}
    for key, item in pairs(value) do
        if not Secret(key) and (type(key) == "string" or type(key) == "number") then
            local stored = CopyStored(item, seen)
            if stored ~= nil then
                copy[key] = stored
            end
        end
    end
    return copy
end

local function Blank()
    local profile = {}
    for i = 1, #KEYS do
        local key = KEYS[i]
        if key == "talents" then
            profile[key] = { nextId = 1, builds = {} }
        else
            profile[key] = { nextId = 1, sets = {} }
        end
    end
    return profile
end

local function Alias(db)
    local name = db.activeProfile
    local profile = type(db.profiles) == "table" and db.profiles[name] or nil
    if type(profile) ~= "table" then
        return
    end
    for i = 1, #KEYS do
        local key = KEYS[i]
        if type(profile[key]) ~= "table" then
            profile[key] = key == "talents" and { nextId = 1, builds = {} } or { nextId = 1, sets = {} }
        end
        db[key] = profile[key]
    end
end

function Profiles:Migrate(db)
    if type(db) ~= "table" or self._migrating then
        return
    end
    self._migrating = true
    if type(db.profiles) ~= "table" then
        db.profiles = {}
    end
    if not db.profilesMigrated then
        local profile = {}
        for i = 1, #KEYS do
            local key = KEYS[i]
            if type(db[key]) == "table" then
                profile[key] = db[key]
            elseif key == "talents" then
                profile[key] = { nextId = 1, builds = {} }
            else
                profile[key] = { nextId = 1, sets = {} }
            end
        end
        if type(db.profiles.Default) ~= "table" then
            db.profiles.Default = profile
        end
        db.activeProfile = "Default"
        db.profilesMigrated = true
    end
    local name = db.activeProfile
    if type(name) ~= "string" or name == "" or type(db.profiles[name]) ~= "table" then
        if type(db.profiles.Default) == "table" then
            name = "Default"
        else
            name = next(db.profiles)
        end
        if not name then
            name = "Default"
            db.profiles[name] = Blank()
        end
        db.activeProfile = name
    end
    Alias(db)
    self._migrating = false
end

function Profiles:Section(key)
    local db = LPL.DB.data
    if type(db) ~= "table" then
        db = LPL.DB:Bind(false)
    else
        self:Migrate(db)
    end
    local profile = db.profiles and db.profiles[db.activeProfile]
    if type(profile) ~= "table" then
        if type(db[key]) ~= "table" then
            db[key] = {}
        end
        return db[key]
    end
    if type(profile[key]) ~= "table" then
        profile[key] = {}
    end
    db[key] = profile[key]
    return profile[key]
end

local function Ready()
    local db = LPL.DB:Bind(false)
    Profiles:Migrate(db)
    return db
end

function Profiles:List()
    local db = Ready()
    local names = {}
    for name in pairs(db.profiles or {}) do
        if type(name) == "string" and not Secret(name) then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    return names, db.activeProfile or "Default"
end

function Profiles:Count(name)
    local db = Ready()
    local profile = db.profiles[name]
    if type(profile) ~= "table" then
        return 0
    end
    local count = 0
    for i = 1, #KEYS do
        local key = KEYS[i]
        local section = profile[key]
        local field = COUNT_FIELD[key]
        local bucket = type(section) == "table" and section[field] or nil
        if type(bucket) == "table" then
            for _ in pairs(bucket) do
                count = count + 1
            end
        end
    end
    return count
end

function Profiles:Load(name)
    local db = Ready()
    if type(db.profiles[name]) ~= "table" then
        return false, "missing"
    end
    db.activeProfile = name
    Alias(db)
    return true, name
end

function Profiles:Create(name)
    local db = Ready()
    name = PlainName(name)
    if not name then
        return false, "bad_name"
    end
    if db.profiles[name] then
        return false, "exists"
    end
    db.profiles[name] = Blank()
    db.activeProfile = name
    Alias(db)
    return true, name
end

function Profiles:Rename(oldName, newName)
    local db = Ready()
    if type(db.profiles[oldName]) ~= "table" then
        return false, "missing"
    end
    newName = PlainName(newName)
    if not newName then
        return false, "bad_name"
    end
    if newName == oldName then
        return true, newName
    end
    if db.profiles[newName] then
        return false, "exists"
    end
    db.profiles[newName] = db.profiles[oldName]
    db.profiles[oldName] = nil
    if db.activeProfile == oldName then
        db.activeProfile = newName
    end
    Alias(db)
    return true, newName
end

function Profiles:Delete(name)
    local db = Ready()
    if type(db.profiles[name]) ~= "table" then
        return false, "missing"
    end
    local count = 0
    for _ in pairs(db.profiles) do
        count = count + 1
    end
    if count <= 1 then
        return false, "last"
    end
    db.profiles[name] = nil
    if db.activeProfile == name then
        db.activeProfile = db.profiles.Default and "Default" or next(db.profiles)
    end
    Alias(db)
    return true, db.activeProfile
end

function Profiles:Install(name, sections)
    local db = Ready()
    name = PlainName(name)
    if not name then
        return false, "bad_name"
    end
    local profile = Blank()
    if type(sections) == "table" then
        for i = 1, #KEYS do
            local key = KEYS[i]
            if type(sections[key]) == "table" then
                profile[key] = CopyStored(sections[key]) or profile[key]
            end
        end
    end
    db.profiles[name] = profile
    db.activeProfile = name
    Alias(db)
    return true, name
end

local function FormatKey(key)
    if type(key) == "number" then
        return "[" .. key .. "]"
    end
    if key:match("^[%a_][%w_]*$") then
        return key
    end
    return "[" .. string.format("%q", key) .. "]"
end

local function TableToString(tbl, seen)
    seen = seen or {}
    if seen[tbl] then
        return "{}"
    end
    seen[tbl] = true
    local parts = {}
    for key, value in pairs(tbl) do
        if not Secret(key) and (type(key) == "string" or type(key) == "number") and not Secret(value) then
            local valueText
            local kind = type(value)
            if kind == "table" then
                valueText = TableToString(value, seen)
            elseif kind == "string" then
                valueText = string.format("%q", value)
            elseif kind == "number" or kind == "boolean" then
                valueText = tostring(value)
            end
            if valueText then
                parts[#parts + 1] = FormatKey(key) .. "=" .. valueText
            end
        end
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function StringToTable(text)
    if type(text) ~= "string" or text:sub(1, 1) ~= "{" then
        return false
    end
    text = text:gsub("([{,])(%d+)=", "%1[%2]=")
    local func, err = loadstring("return " .. text, "LPLProfile")
    if not func and load then
        func, err = load("return " .. text, "LPLProfile", "t", {})
    end
    if not func then
        return false, err
    end
    if setfenv then
        setfenv(func, {})
    end
    return pcall(func)
end

local Base64Encode, Base64Decode
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    function Base64Encode(data)
        return ((data:gsub(".", function(char)
            local bits = ""
            local byte = char:byte()
            for i = 8, 1, -1 do
                bits = bits .. (byte % (2 ^ i) - byte % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(group)
            if #group < 6 then
                return ""
            end
            local value = 0
            for i = 1, 6 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (6 - i)) or 0)
            end
            return alphabet:sub(value + 1, value + 1)
        end) .. ({ "", "==", "=" })[#data % 3 + 1])
    end
    function Base64Decode(data)
        data = string.gsub(data, "[^" .. alphabet .. "=]", "")
        return (data:gsub(".", function(char)
            if char == "=" then
                return ""
            end
            local position = alphabet:find(char, 1, true)
            if not position then
                return ""
            end
            local bits = ""
            local value = position - 1
            for i = 6, 1, -1 do
                bits = bits .. (value % (2 ^ i) - value % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(group)
            if #group ~= 8 then
                return ""
            end
            local value = 0
            for i = 1, 8 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (8 - i)) or 0)
            end
            return string.char(value)
        end))
    end
end

local function EncodePayload(payload)
    return "BN" .. Base64Encode(TableToString(payload))
end

local function DecodePayload(text)
    if type(text) ~= "string" or text:sub(1, 2) ~= "BN" then
        return false
    end
    return StringToTable(Base64Decode(text:sub(3)))
end

function Profiles:ExportText(name)
    local db = Ready()
    local profile = db.profiles[name]
    if type(profile) ~= "table" then
        return nil
    end
    local payload = {
        kind = "lpl-profile",
        version = 1,
        flavor = FLAVOR,
        name = name,
        sections = CopyStored(profile) or {},
    }
    local ok, encoded = pcall(EncodePayload, payload)
    if not ok or type(encoded) ~= "string" or encoded == "" then
        return nil
    end
    return PREFIX .. encoded
end

function Profiles:ImportText(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #PREFIX) ~= PREFIX then
        return false, "bad_format"
    end
    local ok, source = DecodePayload(text:sub(#PREFIX + 1))
    if not ok or type(source) ~= "table" or source.kind ~= "lpl-profile" or tonumber(source.version) ~= 1 then
        return false, "bad_format"
    end
    if source.flavor ~= FLAVOR then
        return false, "flavor"
    end
    local installed, name = self:Install(source.name, source.sections)
    if not installed then
        return false, name or "bad_name"
    end
    return true, name, self:Count(name)
end

local function Paint(target, bg, border)
    if not target.SetBackdrop then
        return
    end
    target:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    target:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    if border then
        target:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
end

local function SmallButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 22)
    Paint(button, { 0.18, 0.18, 0.22, 1 }, { 0.96, 0.55, 0.73, 1 })
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    text:SetTextColor(1, 1, 1)
    button.label = text
    button:SetScript("OnEnter", function(self)
        Paint(self, { 0.24, 0.24, 0.30, 1 }, { 0.96, 0.55, 0.73, 1 })
    end)
    button:SetScript("OnLeave", function(self)
        Paint(self, { 0.18, 0.18, 0.22, 1 }, { 0.96, 0.55, 0.73, 1 })
    end)
    function button:SetText(value)
        text:SetText(value)
    end
    return button
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

function Profiles:EnsureDialogs()
    if self._dialogs then
        return
    end
    self._dialogs = true

    local export = CreateFrame("Frame", "LPLForeverProfileExport", UIParent, "BackdropTemplate")
    export:SetSize(520, 300)
    export:SetPoint("CENTER")
    export:SetFrameStrata("FULLSCREEN_DIALOG")
    export:EnableMouse(true)
    export:Hide()
    Paint(export, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.27, 0.32, 1 })
    local title = export:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Export profile")
    title:SetTextColor(0.95, 0.95, 0.97)
    local hint = export:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetText("Copy this code. It contains every saved set in the profile.")
    local scroll = CreateFrame("ScrollFrame", nil, export, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -58)
    scroll:SetPoint("BOTTOMRIGHT", -32, 48)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(450)
    edit:SetHeight(160)
    edit:SetScript("OnEscapePressed", function()
        export:Hide()
    end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    scroll:SetScrollChild(edit)
    export.editBox = edit
    local closeBtn = SmallButton(export, "Close", 80)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetScript("OnClick", function()
        export:Hide()
    end)
    self.exportDialog = export

    local import = CreateFrame("Frame", "LPLForeverProfileImport", UIParent, "BackdropTemplate")
    import:SetSize(520, 300)
    import:SetPoint("CENTER")
    import:SetFrameStrata("FULLSCREEN_DIALOG")
    import:EnableMouse(true)
    import:Hide()
    Paint(import, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.27, 0.32, 1 })
    local importTitle = import:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    importTitle:SetPoint("TOPLEFT", 16, -14)
    importTitle:SetText("Import profile")
    importTitle:SetTextColor(0.95, 0.95, 0.97)
    local importHint = import:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    importHint:SetPoint("TOPLEFT", importTitle, "BOTTOMLEFT", 0, -6)
    importHint:SetText("Paste a WoW Forever Light Paws profile code.")
    local importScroll = CreateFrame("ScrollFrame", nil, import, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", 16, -58)
    importScroll:SetPoint("BOTTOMRIGHT", -32, 48)
    local importEdit = CreateFrame("EditBox", nil, importScroll)
    importEdit:SetMultiLine(true)
    importEdit:SetAutoFocus(false)
    importEdit:SetFontObject("ChatFontNormal")
    importEdit:SetWidth(450)
    importEdit:SetHeight(160)
    importEdit:SetScript("OnEscapePressed", function()
        import:Hide()
    end)
    importScroll:SetScrollChild(importEdit)
    import.editBox = importEdit
    local acceptBtn = SmallButton(import, "Import", 80)
    acceptBtn:SetPoint("BOTTOMRIGHT", -16, 12)
    acceptBtn:SetScript("OnClick", function()
        Profiles:AcceptImport()
    end)
    local cancelBtn = SmallButton(import, "Cancel", 80)
    cancelBtn:SetPoint("RIGHT", acceptBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function()
        import:Hide()
    end)
    self.importDialog = import

    StaticPopupDialogs["LPLF_NEW_PROFILE"] = {
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
            local ok, result = Profiles:Create(box and box:GetText() or "")
            if ok then
                Speak("Profile created: " .. result)
                Profiles:Refresh()
            elseif result == "exists" then
                Speak("A profile with that name already exists.")
            else
                Speak("Enter a profile name.")
            end
        end,
        EditBoxOnEnterPressed = PressAccept,
    }
    StaticPopupDialogs["LPLF_RENAME_PROFILE"] = {
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
            local current = dialog.data or Profiles._renameName or ""
            if box then
                box:SetText(current)
                box:HighlightText()
                box:SetFocus()
            end
        end,
        OnAccept = function(dialog, data)
            local oldName = data or dialog.data or Profiles._renameName
            local box = PopupEditBox(dialog)
            local ok, result = Profiles:Rename(oldName, box and box:GetText() or "")
            if ok then
                if result ~= oldName then
                    Speak("Renamed profile to " .. result .. ".")
                end
                Profiles:Refresh()
            elseif result == "exists" then
                Speak("A profile with that name already exists.")
            elseif result == "bad_name" then
                Speak("Enter a profile name.")
            else
                Speak("That profile does not exist.")
            end
        end,
        EditBoxOnEnterPressed = PressAccept,
    }
    StaticPopupDialogs["LPLF_DELETE_PROFILE"] = {
        text = "Delete profile %s? Every saved set in that profile is removed.",
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data)
            local ok, nextName = Profiles:Delete(data)
            if ok then
                Speak("Deleted profile. Now using " .. tostring(nextName) .. ".")
                Profiles:Refresh()
            else
                Speak("Keep at least one profile.")
            end
        end,
    }
end

function Profiles:ShowExport(name)
    self:EnsureDialogs()
    local text = self:ExportText(name)
    if not text then
        Speak("Could not export that profile.")
        return
    end
    self.exportDialog.editBox:SetText(text)
    self.exportDialog:Show()
    self.exportDialog.editBox:SetFocus()
    self.exportDialog.editBox:HighlightText()
end

function Profiles:ShowImport()
    self:EnsureDialogs()
    self.importDialog.editBox:SetText("")
    self.importDialog:Show()
    self.importDialog.editBox:SetFocus()
end

function Profiles:AcceptImport()
    local text = self.importDialog.editBox:GetText() or ""
    local ok, name, count = self:ImportText(text)
    if ok then
        Speak(string.format("Imported profile %s with %d saved sets.", name, count or 0))
        self.importDialog:Hide()
        self:Refresh()
    elseif name == "flavor" then
        Speak("That profile is for a different Light Paws version.")
    else
        Speak("Could not import that profile. Paste a WoW Forever profile code.")
    end
end

function Profiles:Build(host)
    local page = CreateFrame("Frame", "LPLForeverProfilesPage", host)
    page:SetAllPoints(host)
    page.rows = {}

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetText("Profiles")
    title:SetTextColor(0.95, 0.95, 0.97)
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", page, "RIGHT", -24, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText("Each profile stores every saved set. Load one, then use the other tabs. Export copies the whole profile.")

    local createBtn = SmallButton(page, "Create", 90)
    createBtn:SetPoint("BOTTOMLEFT", 24, 16)
    createBtn:SetScript("OnClick", function()
        Profiles:EnsureDialogs()
        StaticPopup_Show("LPLF_NEW_PROFILE")
    end)
    local importBtn = SmallButton(page, "Import", 90)
    importBtn:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        Profiles:ShowImport()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -12)
    scroll:SetPoint("BOTTOMRIGHT", -36, 52)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    page.scroll = scroll
    page.content = content
    page:Hide()
    return page
end

function Profiles:CreateRow(index)
    local parent = self.page.content
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(64)
    Paint(row, { 0.10, 0.10, 0.12, 1 }, { 0.25, 0.27, 0.32, 1 })
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("TOPLEFT", 12, -8)
    row.nameText:SetTextColor(0.95, 0.95, 0.97)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    row.loadBtn = SmallButton(row, "Load", 64)
    row.renameBtn = SmallButton(row, "Rename", 72)
    row.exportBtn = SmallButton(row, "Export", 68)
    row.deleteBtn = SmallButton(row, "Delete", 64)
    row.loadBtn:SetPoint("BOTTOMLEFT", 10, 8)
    row.renameBtn:SetPoint("LEFT", row.loadBtn, "RIGHT", 6, 0)
    row.exportBtn:SetPoint("LEFT", row.renameBtn, "RIGHT", 6, 0)
    row.deleteBtn:SetPoint("LEFT", row.exportBtn, "RIGHT", 6, 0)
    row.loadBtn:SetScript("OnClick", function(self)
        if self.profileName and self.profileName ~= select(2, Profiles:List()) then
            local ok, result = Profiles:Load(self.profileName)
            if ok then
                Speak("Loaded profile: " .. result)
                Profiles:Refresh()
            end
        end
    end)
    row.renameBtn:SetScript("OnClick", function(self)
        Profiles:EnsureDialogs()
        Profiles._renameName = self.profileName
        StaticPopup_Show("LPLF_RENAME_PROFILE", self.profileName, nil, self.profileName)
    end)
    row.exportBtn:SetScript("OnClick", function(self)
        Profiles:ShowExport(self.profileName)
    end)
    row.deleteBtn:SetScript("OnClick", function(self)
        if #Profiles:List() <= 1 then
            Speak("Keep at least one profile.")
            return
        end
        Profiles:EnsureDialogs()
        StaticPopup_Show("LPLF_DELETE_PROFILE", self.profileName, nil, self.profileName)
    end)
    self.page.rows[index] = row
    return row
end

function Profiles:Refresh()
    local page = self.page
    if not page then
        return
    end
    for i = 1, #page.rows do
        page.rows[i]:Hide()
    end
    local names, active = self:List()
    local y = -4
    local width = math.max(240, (page.scroll:GetWidth() or 480) - 8)
    for index, name in ipairs(names) do
        local row = page.rows[index] or self:CreateRow(index)
        row:SetWidth(width)
        row.profileName = name
        row.nameText:SetText(name)
        local count = self:Count(name)
        if name == active then
            row.detail:SetText(string.format("Loaded · %d saved", count))
            row.detail:SetTextColor(0.35, 0.65, 1)
            row.loadBtn:SetText("Loaded")
        else
            row.detail:SetText(string.format("%d saved", count))
            row.detail:SetTextColor(0.95, 0.95, 0.97)
            row.loadBtn:SetText("Load")
        end
        row.loadBtn.profileName = name
        row.renameBtn.profileName = name
        row.exportBtn.profileName = name
        row.deleteBtn.profileName = name
        row:SetPoint("TOPLEFT", 0, y)
        row:Show()
        y = y - row:GetHeight() - 8
    end
    page.content:SetSize(width, math.max(1, -y))
end

function Profiles:Show(uiFrame)
    local host = uiFrame and uiFrame.listPage and uiFrame.listPage:GetParent()
    if not host then
        return
    end
    if not uiFrame.profilesPage then
        uiFrame.profilesPage = self:Build(host)
    end
    self.page = uiFrame.profilesPage
    self:Refresh()
end
