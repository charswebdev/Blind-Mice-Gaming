local addonName, LPL = ...

LPL.ImportExport = {
    instance = nil,
    requestedView = nil,
    requestedExportText = nil,
    requestedExportName = nil,
}

local ImportExportModule = {
    id = "builds",
    label = "Import / Export",
    description = "Import and export talent builds using share strings.",
    iconStem = "import_64",
    order = 60,
    instance = nil,
}

local function CreateCodeInputArea(parent, frameLevel)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -72)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 72)
    container:SetFrameLevel(frameLevel)
    container:SetClipsChildren(true)
    LPL.Theme:ApplyBackdrop(container, "panel", "bgElevated", "border")
    container:EnableMouse(true)

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -26, 8)
    scroll:SetFrameLevel(frameLevel + 1)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local editBox = CreateFrame("EditBox", "LPLImportExportEditBox", scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(LPL.Theme.fonts.body)
    editBox:SetTextColor(LPL.Theme:GetColor("textBright"))
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    scroll:SetScrollChild(editBox)

    local function UpdateEditBoxLayout()
        local width = scroll:GetWidth()
        if not width or width < 40 then
            return
        end

        editBox:SetWidth(width)
        local fontHeight = select(2, editBox:GetFont()) or 12
        local lineCount = editBox:GetNumLines() or 1
        local contentHeight = math.max(lineCount * fontHeight + 16, scroll:GetHeight())
        editBox:SetHeight(contentHeight)
        scroll:UpdateScrollChildRect()
    end

    scroll:HookScript("OnSizeChanged", UpdateEditBoxLayout)
    editBox:HookScript("OnTextChanged", UpdateEditBoxLayout)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local fontHeight = select(2, editBox:GetFont()) or 12
        local scrollTop = scroll:GetVerticalScroll()
        local scrollHeight = scroll:GetHeight()
        local cursorOffset = math.abs(y or 0)
        local cursorBottom = cursorOffset + (cursorHeight or fontHeight)

        if cursorBottom > scrollTop + scrollHeight then
            scroll:SetVerticalScroll(cursorBottom - scrollHeight)
        elseif cursorOffset < scrollTop then
            scroll:SetVerticalScroll(cursorOffset)
        end
    end)

    local function FocusEditBox()
        editBox:SetFocus()
    end

    container:SetScript("OnMouseDown", FocusEditBox)
    scroll:SetScript("OnMouseDown", FocusEditBox)
    editBox:SetScript("OnMouseDown", FocusEditBox)

    container.scroll = scroll
    container.editBox = editBox
    container.UpdateEditBoxLayout = UpdateEditBoxLayout
    return container
end

function ImportExportModule.create(parent)
    local frame = CreateFrame("Frame", "LPLImportExportModule", parent)
    frame:SetAllPoints(parent)

    local title = LPL:CreateLabel(frame, "title")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -24)
    title:SetText("Import / Export")

    local subtitle = LPL:CreateLabel(frame, "body")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    subtitle:SetText("Paste a BtWLoadouts, LightPawsLoadouts, or LPL share string. Import creates a loadout and links the imported sets.")

    local nameLabel = LPL:CreateLabel(frame, "small")
    nameLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 44)
    nameLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))
    nameLabel:SetText("Loadout name")

    local nameBox = LPL:CreateEditBox(nil, frame, 280)
    nameBox:SetPoint("BOTTOMLEFT", nameLabel, "TOPLEFT", 0, -4)
    nameBox:SetHeight(28)
    nameBox:SetText("Imported Loadout")

    local errorLabel = LPL:CreateLabel(frame, "small")
    errorLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)
    errorLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -180, 16)
    errorLabel:SetJustifyH("LEFT")
    errorLabel:SetTextColor(1, 0.35, 0.35)
    errorLabel:SetText("")

    local importButton = LPL:CreateButton(nil, frame)
    importButton:SetSize(120, 28)
    importButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
    importButton:SetText("Import")

    local baseLevel = frame:GetFrameLevel() + 10
    local inputArea = CreateCodeInputArea(frame, baseLevel)
    local editBox = inputArea.editBox
    nameBox:SetFrameLevel(baseLevel + 5)
    importButton:SetFrameLevel(baseLevel + 5)

    frame.mode = nil
    frame.exportText = nil
    frame.validateTimer = nil
    frame.validImportData = nil
    frame.validImportKind = nil
    frame.validImportAddonKey = nil
    frame.importContext = nil

    local function DefaultImportName(importKind)
        if importKind == "equipment" then
            return "Imported Equipment Set"
        end
        if importKind == "actionbars" then
            return "Imported Action Bar Set"
        end
        if importKind == "keybinds" then
            return "Imported Keybinding Profile"
        end
        if importKind == "pvptalents" then
            return "Imported PvP Set"
        end
        if importKind == "cooldownmanager" then
            return "Imported Cooldown Manager Set"
        end
        if importKind == "editmode" then
            return "Imported Edit Mode Layout"
        end
        if importKind == "addonsets" then
            return "Imported Addon Set"
        end
        if importKind == "loadout" then
            return "Imported Loadout"
        end
        if importKind == "macros" then
            return "Imported Macro"
        end
        if importKind == "addonprofiles" or importKind == "vaultchooser" then
            return "Imported Addon Profile"
        end
        return "Imported Loadout"
    end

    local function NormalizeImportName(importKind, name)
        if importKind == "equipment" then
            return LPL.EquipmentStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "actionbars" then
            return LPL.ActionBarStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "keybinds" then
            return LPL.KeybindStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "pvptalents" then
            return LPL.PvpTalentStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "cooldownmanager" then
            return LPL.CooldownManagerStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "editmode" then
            return LPL.EditModeStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "addonsets" then
            return LPL.AddonSetStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "macros" then
            return LPL.MacroStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        if importKind == "addonprofiles" or importKind == "vaultchooser" then
            return LPL.AddonProfileStore:NormalizeSetName(name, DefaultImportName(importKind))
        end
        return LPL.BuildStore:NormalizeBuildName(name, DefaultImportName(importKind))
    end

    local function LooksLikeMacroBody(str)
        if type(str) ~= "string" or str == "" or #str > (LPL.MacroStore.MAX_BODY_LENGTH or 255) then
            return false
        end
        local first = str:match("^%s*([^\r\n]+)")
        if not first then
            return false
        end
        local lower = first:lower()
        if lower:find("^#showtooltip") then
            return true
        end
        if first:find("^/") then
            return true
        end
        return false
    end

    local function ResolveVaultImport(text)
        local trimmed = (text or ""):match("^%s*(.-)%s*$") or ""
        if trimmed == "" then
            return nil, nil
        end
        local ctx = frame.importContext
        local addonKey = "custom"
        if LPL.AddonCatalog and LPL.AddonCatalog.Detect then
            addonKey = LPL.AddonCatalog:Detect(trimmed) or "custom"
        end
        if addonKey ~= "custom" then
            return "addonprofiles", addonKey
        end
        if ctx == "macros" then
            return "macros", nil
        end
        if ctx == "addonsmanager" then
            return "addonprofiles", "custom"
        end
        if LooksLikeMacroBody(trimmed) then
            return "macros", nil
        end
        return "vaultchooser", "custom"
    end

    local function ResolveImportKind(text)
        local rawSource = LPL.TalentShare:GetRawImportSource(text)
        if rawSource then
            if rawSource.type == "loadout" then
                return "loadout"
            end
            if rawSource.type == "equipment" or rawSource.type == "lplequipment" then
                return "equipment"
            end
            if rawSource.type == "actionbars" or rawSource.type == "lplactionbars" then
                return "actionbars"
            end
            if rawSource.type == "keybinds" then
                return "keybinds"
            end
            if rawSource.type == "pvptalents" then
                return "pvptalents"
            end
            if rawSource.type == "cooldownmanager" then
                return "cooldownmanager"
            end
            if rawSource.type == "editmode" then
                return "editmode"
            end
            if rawSource.type == "addonsets" or rawSource.type == "addonset" then
                return "addonsets"
            end
        end

        if LPL.LoadoutImport:BuildImportPreviewFromText(text, "Imported Loadout") then
            return "loadout"
        end

        if LPL.EquipmentShare:ValidateImportString(text) then
            return "equipment"
        end
        if LPL.PvpTalentShare:ValidateImportString(text) then
            return "pvptalents"
        end
        if LPL.CooldownManagerShare:ValidateImportString(text) then
            return "cooldownmanager"
        end
        if LPL.EditModeShare:ValidateImportString(text) then
            return "editmode"
        end
        if LPL.AddonSetShare and LPL.AddonSetShare:ValidateImportString(text) then
            return "addonsets"
        end
        if LPL.ActionBarShare:ValidateImportString(text) then
            return "actionbars"
        end
        if LPL.KeybindShare and LPL.KeybindShare:ValidateImportString(text) then
            return "keybinds"
        end
        if LPL.TalentShare:ValidateImportString(text) then
            return "talents"
        end

        local vaultKind = ResolveVaultImport(text)
        if vaultKind then
            return vaultKind
        end
        return nil
    end

    local function ParseImportData(text, importKind)
        if importKind == "macros" then
            return true, {
                name = DefaultImportName("macros"),
                body = text or "",
                icon = LPL.MacroStore.DEFAULT_ICON,
            }
        end
        if importKind == "addonprofiles" or importKind == "vaultchooser" then
            local addonKey = "custom"
            if LPL.AddonCatalog and LPL.AddonCatalog.Detect then
                addonKey = LPL.AddonCatalog:Detect(text) or "custom"
            end
            return true, {
                name = DefaultImportName("addonprofiles"),
                profileString = text or "",
                addonKey = addonKey,
                addonLabel = "",
            }
        end
        if importKind == "loadout" then
            local preview = LPL.LoadoutImport:BuildImportPreviewFromText(text, DefaultImportName("loadout"))
            if preview then
                return true, preview
            end
            return false, nil, "Invalid loadout string."
        end
        if importKind == "equipment" then
            return LPL.EquipmentShare:ParseImportString(text)
        end
        if importKind == "pvptalents" then
            return LPL.PvpTalentShare:ParseImportString(text)
        end
        if importKind == "cooldownmanager" then
            return LPL.CooldownManagerShare:ParseImportString(text)
        end
        if importKind == "editmode" then
            return LPL.EditModeShare:ParseImportString(text)
        end
        if importKind == "addonsets" then
            return LPL.AddonSetShare:ParseImportString(text)
        end
        if importKind == "actionbars" then
            return LPL.ActionBarShare:ParseImportString(text)
        end
        if importKind == "keybinds" then
            return LPL.KeybindShare:ParseImportString(text)
        end
        return LPL.TalentShare:ParseImportString(text)
    end

    local function ValidateImportForText(text)
        local importKind = ResolveImportKind(text)
        if importKind == "macros" or importKind == "addonprofiles" or importKind == "vaultchooser" then
            if not text or text:match("^%s*$") then
                return false, "Paste a macro body or addon profile string."
            end
            return true, ""
        end
        if importKind == "loadout" then
            if LPL.LoadoutImport:BuildImportPreviewFromText(text, DefaultImportName("loadout")) then
                return true, ""
            end
            return false, "Invalid loadout string."
        end
        if importKind == "equipment" then
            return LPL.EquipmentShare:ValidateImportString(text)
        end
        if importKind == "pvptalents" then
            return LPL.PvpTalentShare:ValidateImportString(text)
        end
        if importKind == "cooldownmanager" then
            return LPL.CooldownManagerShare:ValidateImportString(text)
        end
        if importKind == "editmode" then
            return LPL.EditModeShare:ValidateImportString(text)
        end
        if importKind == "addonsets" then
            return LPL.AddonSetShare:ValidateImportString(text)
        end
        if importKind == "actionbars" then
            return LPL.ActionBarShare:ValidateImportString(text)
        end
        if importKind == "keybinds" then
            return LPL.KeybindShare:ValidateImportString(text)
        end
        if importKind == "talents" then
            return LPL.TalentShare:ValidateImportString(text)
        end
        local _, equipmentErr = LPL.EquipmentShare:ValidateImportString(text)
        local _, pvpErr = LPL.PvpTalentShare:ValidateImportString(text)
        local _, cdmErr = LPL.CooldownManagerShare:ValidateImportString(text)
        local _, editErr = LPL.EditModeShare:ValidateImportString(text)
        local _, addonSetErr = LPL.AddonSetShare and LPL.AddonSetShare:ValidateImportString(text)
        local _, talentErr = LPL.TalentShare:ValidateImportString(text)
        local _, actionBarErr = LPL.ActionBarShare:ValidateImportString(text)
        local _, keybindErr = LPL.KeybindShare and LPL.KeybindShare:ValidateImportString(text)
        return false, equipmentErr or pvpErr or cdmErr or editErr or addonSetErr or talentErr or actionBarErr or keybindErr or "Invalid share string."
    end

    local function BuildImportPreview(text, importName, importKind)
        importKind = importKind or ResolveImportKind(text)
        if importKind == "macros" or importKind == "addonprofiles" or importKind == "vaultchooser" then
            return nil
        end
        if importKind == "loadout" then
            return LPL.LoadoutImport:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "equipment" then
            return LPL.EquipmentShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "pvptalents" then
            return LPL.PvpTalentShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "cooldownmanager" then
            return LPL.CooldownManagerShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "editmode" then
            return LPL.EditModeShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "addonsets" then
            return LPL.AddonSetShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "actionbars" then
            return LPL.ActionBarShare:BuildImportPreviewFromText(text, importName)
        end
        if importKind == "keybinds" then
            return LPL.KeybindShare:BuildImportPreviewFromText(text, importName)
        end
        return LPL.TalentShare:BuildImportPreviewFromText(text, importName)
    end

    local function RefreshImportChrome(importKind, addonKey)
        if importKind == "macros" then
            nameLabel:SetText("Macro name")
            importButton:SetText("Import Macro")
            subtitle:SetText("Detected as a Macro Manager body. Import saves to Macro Manager (does not write Blizzard macros).")
        elseif importKind == "addonprofiles" then
            nameLabel:SetText("Profile name")
            importButton:SetText("Import Profile")
            local label = (LPL.AddonCatalog and LPL.AddonCatalog:GetLabel(addonKey or "custom")) or "Custom"
            subtitle:SetText(string.format("Detected as Addon Profile (%s). Import saves to Addons Manager.", label))
        elseif importKind == "vaultchooser" then
            nameLabel:SetText("Name")
            importButton:SetText("Import…")
            subtitle:SetText("Not a known LPL share string. Import will ask whether to save as a Macro or Addon Profile.")
        else
            nameLabel:SetText("Loadout name")
            importButton:SetText("Import")
            subtitle:SetText("Paste a BtWLoadouts, LightPawsLoadouts, or LPL share string. Import creates a loadout and links the imported sets.")
        end
    end

    local function NavigateToVaultModule(moduleId, setID)
        LPL.Modules:Activate(moduleId)
        local module = LPL.Modules:Get(moduleId)
        if not module or not module.instance then
            return
        end
        module.instance.selectedSetID = setID
        if module.instance.ShowList then
            module.instance:ShowList()
        end
        if module.instance.Refresh then
            module.instance:Refresh()
        end
    end

    local function SaveLinkedLoadout(loadoutName, segments)
        if not LPL.LoadoutStore or type(segments) ~= "table" then
            return nil
        end

        loadoutName = LPL.LoadoutStore:NormalizeSetName(loadoutName, "Imported Loadout")
        local data = {
            name = loadoutName,
            restrictions = {},
        }
        local hasAny = false
        local defs = LPL.LoadoutStore.SEGMENT_DEFS or {}
        for _, def in ipairs(defs) do
            local ids = segments[def.plural]
            local singular = segments[def.singular]
            if type(ids) == "table" and #ids > 0 then
                data[def.plural] = ids
                data[def.singular] = ids[1]
                hasAny = true
            elseif singular then
                data[def.plural] = { tostring(singular) }
                data[def.singular] = tostring(singular)
                hasAny = true
            end
        end
        if not hasAny then
            return nil
        end

        local existing = LPL.LoadoutStore:FindByName(loadoutName)
        local loadout = LPL.LoadoutStore:ApplyImport(data, loadoutName, {
            loadout = true,
            existingLoadoutID = existing and existing.id or nil,
        })
        if loadout then
            print(string.format(
                "|cff33cc33LPL:|r Saved loadout \"%s\" and linked imported sets.",
                loadout.name or loadoutName
            ))
            NavigateToVaultModule("loadouts", loadout.id)
        end
        return loadout
    end

    local function CommitVaultImport(importKind, text, importName)
        text = text or ""
        importName = NormalizeImportName(importKind, importName)

        if importKind == "macros" then
            if #text > (LPL.MacroStore.MAX_BODY_LENGTH or 255) then
                print(string.format(
                    "|cffffcc00LPL:|r Macro body truncated to %d characters.",
                    LPL.MacroStore.MAX_BODY_LENGTH or 255
                ))
            end
            local draft = {
                name = importName,
                icon = LPL.MacroStore.DEFAULT_ICON,
                body = text,
            }
            LPL.MacroStore:SaveFromEditor(nil, importName, draft, function(setID)
                NavigateToVaultModule("macros", setID)
            end)
            return true
        end

        if importKind == "addonprofiles" then
            local addonKey = "custom"
            if LPL.AddonCatalog and LPL.AddonCatalog.Detect then
                addonKey = LPL.AddonCatalog:Detect(text) or "custom"
            end
            if addonKey == "custom" and frame.validImportAddonKey and frame.validImportAddonKey ~= "custom" then
                addonKey = frame.validImportAddonKey
            end
            local soft = LPL.AddonProfileStore.SOFT_WARN_BYTES or (128 * 1024)
            if #text >= soft then
                print("|cffffcc00LPL:|r Large addon profile string — SavedVariables may grow.")
            end
            local draft = {
                name = importName,
                addonKey = addonKey,
                addonLabel = "",
                profileString = text,
                notes = "",
            }
            LPL.AddonProfileStore:SaveFromEditor(nil, importName, draft, function(setID)
                NavigateToVaultModule("addonsmanager", setID)
            end)
            return true
        end

        return false
    end

    local function SetError(message)
        errorLabel:SetText(message or "")
    end

    local function ValidateImportText()
        frame.validateTimer = nil
        if frame.mode ~= "import" then
            return
        end
        local text = editBox:GetText() or ""
        local ok, err = ValidateImportForText(text)
        if ok then
            local importKind = ResolveImportKind(text)
            local parseOk, importData = ParseImportData(text, importKind)
            frame.validImportData = parseOk and importData or nil
            frame.validImportKind = importKind
            frame.validImportAddonKey = importData and importData.addonKey or nil
            if importKind == "addonprofiles" or importKind == "vaultchooser" then
                local _, addonKey = ResolveVaultImport(text)
                frame.validImportAddonKey = addonKey or frame.validImportAddonKey
            end
            RefreshImportChrome(importKind, frame.validImportAddonKey)
            SetError("")
            if importData then
                local defaultName = DefaultImportName(importKind)
                local currentName = nameBox:GetText()
                local sourceName = importData.name
                if importKind == "loadout" and importData.rawSource then
                    sourceName = importData.rawSource.name or importData.buildName
                end
                if currentName == ""
                    or currentName == "Imported Build"
                    or currentName == "Imported Action Bar Set"
                    or currentName == "Imported Keybinding Profile"
                    or currentName == "Imported Equipment Set"
                    or currentName == "Imported PvP Set"
                    or currentName == "Imported Edit Mode Layout"
                    or currentName == "Imported Addon Set"
                    or currentName == "Imported Loadout"
                    or currentName == "Imported Macro"
                    or currentName == "Imported Addon Profile"
                    or currentName == "Imported Cooldown Manager Set" then
                    if sourceName then
                        nameBox:SetText(NormalizeImportName(importKind, sourceName))
                    else
                        nameBox:SetText(defaultName)
                    end
                end
            end
            importButton:SetEnabled(text ~= "" and (
                frame.validImportData ~= nil
                or importKind == "macros"
                or importKind == "addonprofiles"
                or importKind == "vaultchooser"
            ))
        else
            frame.validImportData = nil
            frame.validImportKind = nil
            frame.validImportAddonKey = nil
            RefreshImportChrome(nil, nil)
            SetError(err)
            importButton:SetEnabled(false)
        end
    end

    local function ScheduleValidation()
        if frame.validateTimer then
            frame.validateTimer:Cancel()
        end
        local text = editBox:GetText() or ""
        if text == "" then
            frame.validImportData = nil
            frame.validImportKind = nil
            SetError("")
            importButton:SetEnabled(false)
            return
        end
        frame.validateTimer = C_Timer.NewTimer(0.12, ValidateImportText)
    end

    local function ApplyImportMode()
        frame.mode = "import"
        frame.exportText = nil
        frame.importContext = LPL.ImportExport.importContext
        title:SetText("Import")
        RefreshImportChrome(nil, nil)
        if frame.importContext == "macros" then
            subtitle:SetText("Paste a macro body. Known addon strings still save to Addons Manager when detected.")
            nameLabel:SetText("Macro name")
            importButton:SetText("Import Macro")
            nameBox:SetText("Imported Macro")
        elseif frame.importContext == "addonsmanager" then
            subtitle:SetText("Paste an addon profile string. Known formats are auto-labeled when possible.")
            nameLabel:SetText("Profile name")
            importButton:SetText("Import Profile")
            nameBox:SetText("Imported Addon Profile")
        else
            nameBox:SetText("Imported Loadout")
        end
        nameLabel:Show()
        nameBox:Show()
        importButton:Show()
        editBox:EnableKeyboard(true)
        editBox:SetScript("OnChar", nil)
        editBox:SetText("")
        SetError("")
        frame.validImportData = nil
        frame.validImportKind = nil
        frame.validImportAddonKey = nil
        importButton:SetEnabled(false)
        inputArea.UpdateEditBoxLayout()
        C_Timer.After(0, function()
            if frame.mode == "import" and editBox then
                editBox:SetFocus()
            end
        end)
    end

    local function ApplyExportMode(exportText, buildName)
        frame.mode = "export"
        frame.exportText = exportText or ""
        title:SetText("Export")
        local hint = "Select the string below and press Ctrl+C. Paste into WoW's talent import or LPL's import."
        if buildName and buildName ~= "" then
            hint = string.format(
                "Build: %s - copy below and paste into WoW's talent import or LPL's import.",
                buildName
            )
        end
        subtitle:SetText(hint)
        nameLabel:Hide()
        nameBox:Hide()
        importButton:Hide()
        editBox:EnableKeyboard(true)
        editBox:SetScript("OnChar", function(self)
            if frame.exportText then
                self:SetText(frame.exportText:gsub("|", "||"))
                self:HighlightText()
            end
        end)
        editBox:SetText(frame.exportText:gsub("|", "||"))
        SetError("")
        inputArea.UpdateEditBoxLayout()
        editBox:HighlightText()
        editBox:SetFocus()
    end

    function frame:ShowImportMode()
        ApplyImportMode()
    end

    function frame:ShowExportMode(exportText, buildName)
        ApplyExportMode(exportText, buildName)
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if frame.mode == "export" then
            if frame.exportText and userInput then
                self:SetText(frame.exportText:gsub("|", "||"))
                self:HighlightText()
            end
            return
        end
        ScheduleValidation()
    end)

    importButton:SetScript("OnClick", function()
        if frame.mode ~= "import" then
            return
        end
        local text = editBox:GetText() or ""
        local importKind = frame.validImportKind or ResolveImportKind(text)
        local importName = NormalizeImportName(importKind, nameBox:GetText())

        if importKind == "macros" or importKind == "addonprofiles" then
            CommitVaultImport(importKind, text, importName)
            return
        end

        if importKind == "vaultchooser" then
            LPL.VaultImportChooser:Show(function(picked)
                local nameForKind = NormalizeImportName(picked, nameBox:GetText())
                CommitVaultImport(picked, text, nameForKind)
            end)
            return
        end

        local preview = BuildImportPreview(text, importName, importKind)
        if not preview then
            SetError("Could not preview import.")
            return
        end

        LPL.ImportConfirmDialog:Show(preview, function(options)
            options.existingActionBarID = preview.existingActionBarID
            options.existingKeybindID = preview.existingKeybindID
            options.existingEquipmentID = preview.existingEquipmentID
            options.existingPvpTalentID = preview.existingPvpTalentID
            options.existingCooldownManagerID = preview.existingCooldownManagerID
            options.existingEditModeID = preview.existingEditModeID
            options.existingAddonSetID = preview.existingAddonSetID
            local rawSource = preview.rawSource or LPL.TalentShare:GetRawImportSource(text) or {}

            if preview.importKind == "loadout" then
                local path = preview.loadoutPath or importName
                local build
                local err
                local actionBarSet
                local keybindSet
                local equipmentSet
                local pvpSet
                local cdmSet
                local editModeSet
                local addonSet
                local talentBuildIDs = {}
                local actionBarSetIDs = {}
                local keybindSetIDs = {}
                local equipmentSetIDs = {}
                local pvpTalentSetIDs = {}
                local cooldownManagerSetIDs = {}
                local editModeSetIDs = {}
                local addonSetIDs = {}

                local function CollectIDs(target, primary, all)
                    if type(all) == "table" then
                        for _, set in ipairs(all) do
                            if set and set.id then
                                target[#target + 1] = set.id
                            end
                        end
                    elseif primary and primary.id then
                        target[#target + 1] = primary.id
                    end
                end

                if options.talents or options.hero then
                    build, err = LPL.TalentShare:ImportString(text, importName, options)
                    if not build and not options.actionBars and not options.keybinds and not options.equipment
                        and not options.pvpTalents and not options.cooldownManager and not options.editMode
                        and not options.addonSets then
                        SetError(err or "Import failed.")
                        return
                    end
                    if build and build.id then
                        talentBuildIDs[#talentBuildIDs + 1] = build.id
                    end
                    -- Extra talent builds attached to the same loadout export.
                    if type(rawSource.dftalents) == "table" and #rawSource.dftalents > 1 and LPL.BuildStore then
                        for index = 2, #rawSource.dftalents do
                            local segment = rawSource.dftalents[index]
                            if type(segment) == "table" then
                                local extraName = segment.name or (path .. " " .. tostring(index))
                                local extraOpts = CopyTable(options)
                                extraOpts.existingBuildID = nil
                                local extra
                                if type(segment.string) == "string" and segment.string ~= "" then
                                    extra = LPL.TalentShare:ImportString(segment.string, extraName, extraOpts)
                                elseif type(segment.nodes) == "table" then
                                    local importData = {
                                        name = extraName,
                                        classID = segment.classID,
                                        specID = segment.specID,
                                        subTreeID = segment.subTreeID,
                                        nodes = LPL.BuildStore:NormalizeNodesForStorage(segment.nodes),
                                    }
                                    extra = LPL.BuildStore:ApplyImport(importData, extraName, extraOpts)
                                end
                                if extra and extra.id then
                                    talentBuildIDs[#talentBuildIDs + 1] = extra.id
                                end
                            end
                        end
                    end
                end

                if options.actionBars then
                    local set, abErr, all = LPL.ActionBarShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and abErr and not build then
                        SetError(abErr)
                        return
                    end
                    if set then
                        actionBarSet = set
                        CollectIDs(actionBarSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported action bar set \"%s\".", set.name or path))
                    end
                end

                if options.keybinds then
                    local set, kbErr, all = LPL.KeybindShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and kbErr and not build and not actionBarSet then
                        SetError(kbErr)
                        return
                    end
                    if set then
                        keybindSet = set
                        CollectIDs(keybindSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported keybinding profile \"%s\".", set.name or path))
                    end
                end

                if options.equipment then
                    local set, eqErr, all = LPL.EquipmentShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and eqErr and not build then
                        SetError(eqErr)
                        return
                    end
                    if set then
                        equipmentSet = set
                        CollectIDs(equipmentSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported equipment set \"%s\".", set.name or path))
                    end
                end

                if options.pvpTalents then
                    local set, pvpErr, all = LPL.PvpTalentShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and pvpErr and not build then
                        SetError(pvpErr)
                        return
                    end
                    if set then
                        pvpSet = set
                        CollectIDs(pvpTalentSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported PvP set \"%s\" (saved for PvP tab).", set.name or path))
                    end
                end

                if options.cooldownManager then
                    local set, cdmErr, all = LPL.CooldownManagerShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and cdmErr and not build then
                        SetError(cdmErr)
                        return
                    end
                    if set then
                        cdmSet = set
                        CollectIDs(cooldownManagerSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported Cooldown Manager set \"%s\" (saved for Cooldown Manager tab).", set.name or path))
                    end
                end

                if options.editMode then
                    local set, emErr, all = LPL.EditModeShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and emErr and not build then
                        SetError(emErr)
                        return
                    end
                    if set then
                        editModeSet = set
                        CollectIDs(editModeSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported Edit Mode layout \"%s\" (saved for Edit Mode tab).", set.name or path))
                    end
                end

                if options.addonSets then
                    local set, asErr, all = LPL.AddonSetShare:ApplyLoadoutSegments(rawSource, path, options)
                    if not set and asErr and not build then
                        SetError(asErr)
                        return
                    end
                    if set then
                        addonSet = set
                        CollectIDs(addonSetIDs, set, all)
                        print(string.format("|cff33cc33LPL:|r Imported Addon Set \"%s\" (saved for Addon Sets tab).", set.name or path))
                    end
                end

                if LPL.LoadoutStore then
                    local loadoutName = importName or path or "Imported Loadout"
                    if build or actionBarSet or keybindSet or equipmentSet or pvpSet or cdmSet or editModeSet or addonSet
                        or #talentBuildIDs > 0 or #actionBarSetIDs > 0 then
                        SaveLinkedLoadout(loadoutName, {
                            talentBuildIDs = talentBuildIDs,
                            talentBuildID = talentBuildIDs[1],
                            actionBarSetIDs = actionBarSetIDs,
                            actionBarSetID = actionBarSetIDs[1],
                            keybindSetIDs = keybindSetIDs,
                            keybindSetID = keybindSetIDs[1],
                            equipmentSetIDs = equipmentSetIDs,
                            equipmentSetID = equipmentSetIDs[1],
                            pvpTalentSetIDs = pvpTalentSetIDs,
                            pvpTalentSetID = pvpTalentSetIDs[1],
                            cooldownManagerSetIDs = cooldownManagerSetIDs,
                            cooldownManagerSetID = cooldownManagerSetIDs[1],
                            editModeSetIDs = editModeSetIDs,
                            editModeSetID = editModeSetIDs[1],
                            addonSetIDs = addonSetIDs,
                            addonSetID = addonSetIDs[1],
                        })
                    elseif LPL.Modules:Get("loadouts") then
                        LPL.Modules:Activate("loadouts")
                    end
                end
                return
            end

            if preview.importKind == "equipment" then
                local set, err = LPL.EquipmentShare:ImportString(text, importName, options)
                if not set then
                    SetError(err or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported equipment set \"%s\".", set.name or importName))
                SaveLinkedLoadout(importName, {
                    equipmentSetIDs = { set.id },
                    equipmentSetID = set.id,
                })
                return
            end

            if preview.importKind == "actionbars" then
                local set, err = LPL.ActionBarShare:ImportString(text, importName, options)
                if not set then
                    SetError(err or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported action bar set \"%s\".", set.name or importName))
                SaveLinkedLoadout(importName, {
                    actionBarSetIDs = { set.id },
                    actionBarSetID = set.id,
                })
                return
            end

            if preview.importKind == "keybinds" then
                local set, err = LPL.KeybindShare:ImportString(text, importName, options)
                if not set then
                    SetError(err or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported keybinding profile \"%s\".", set.name or importName))
                SaveLinkedLoadout(importName, {
                    keybindSetIDs = { set.id },
                    keybindSetID = set.id,
                })
                return
            end

            if preview.importKind == "pvptalents" then
                local set, pvpErr = LPL.PvpTalentShare:ImportString(text, importName, options)
                if not set then
                    SetError(pvpErr or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported PvP set \"%s\" (saved for PvP tab).", set.name or importName))
                SaveLinkedLoadout(importName, {
                    pvpTalentSetIDs = { set.id },
                    pvpTalentSetID = set.id,
                })
                return
            end

            if preview.importKind == "cooldownmanager" then
                local set, cdmErr = LPL.CooldownManagerShare:ImportString(text, importName, options)
                if not set then
                    SetError(cdmErr or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported Cooldown Manager set \"%s\" (saved for Cooldown Manager tab).", set.name or importName))
                SaveLinkedLoadout(importName, {
                    cooldownManagerSetIDs = { set.id },
                    cooldownManagerSetID = set.id,
                })
                return
            end

            if preview.importKind == "editmode" then
                local set, emErr = LPL.EditModeShare:ImportString(text, importName, options)
                if not set then
                    SetError(emErr or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported Edit Mode layout \"%s\" (saved for Edit Mode tab).", set.name or importName))
                SaveLinkedLoadout(importName, {
                    editModeSetIDs = { set.id },
                    editModeSetID = set.id,
                })
                return
            end

            if preview.importKind == "addonsets" then
                local set, asErr = LPL.AddonSetShare:ImportString(text, importName, options)
                if not set then
                    SetError(asErr or "Import failed.")
                    return
                end
                print(string.format("|cff33cc33LPL:|r Imported Addon Set \"%s\" (saved for Addon Sets tab).", set.name or importName))
                SaveLinkedLoadout(importName, {
                    addonSetIDs = { set.id },
                    addonSetID = set.id,
                })
                return
            end

            local build, err
            local talentBuildIDs = {}
            local actionBarSetIDs = {}
            if options.talents or options.hero then
                build, err = LPL.TalentShare:ImportString(text, importName, options)
                if not build and not options.actionBars then
                    SetError(err or "Import failed.")
                    return
                end
                if build and build.id then
                    talentBuildIDs[#talentBuildIDs + 1] = build.id
                end
            end

            if options.actionBars then
                local set, abErr = LPL.ActionBarShare:ApplyLoadoutSegments(rawSource, preview.loadoutPath, options)
                if not set and abErr then
                    SetError(abErr)
                    return
                end
                if set then
                    print(string.format("|cff33cc33LPL:|r Imported action bar set \"%s\".", set.name or preview.loadoutPath))
                    if set.id then
                        actionBarSetIDs[#actionBarSetIDs + 1] = set.id
                    end
                end
            end

            if build then
                print(string.format("|cff33cc33LPL:|r Imported build \"%s\".", build.name or importName))
            end

            local loadout = SaveLinkedLoadout(importName, {
                talentBuildIDs = talentBuildIDs,
                talentBuildID = talentBuildIDs[1],
                actionBarSetIDs = actionBarSetIDs,
                actionBarSetID = actionBarSetIDs[1],
            })
            if not loadout then
                if build then
                    LPL.Modules:Activate("talents")
                    local talentsModule = LPL.Modules:Get("talents")
                    if talentsModule and talentsModule.instance then
                        talentsModule.instance.selectedBuildID = build.id
                        if talentsModule.instance.ShowList then
                            talentsModule.instance:ShowList()
                        end
                        talentsModule.instance:Refresh()
                    end
                elseif options.actionBars then
                    LPL.Modules:Activate("actionbars")
                    local actionBarsModule = LPL.Modules:Get("actionbars")
                    if actionBarsModule and actionBarsModule.instance then
                        local set = LPL.ActionBarStore:FindByName(preview.loadoutPath)
                        if set then
                            actionBarsModule.instance.selectedSetID = set.id
                        end
                        if actionBarsModule.instance.ShowList then
                            actionBarsModule.instance:ShowList()
                        end
                        actionBarsModule.instance:Refresh()
                    end
                end
            end
        end)
    end)

    nameBox:SetOnEnterPressed(function()
        if importButton:IsEnabled() then
            importButton:Click()
        end
    end)

    frame:Hide()
    ImportExportModule.instance = frame
    LPL.ImportExport.instance = frame
    return frame
end

function LPL.ImportExport:GetInstance()
    if self.instance then
        return self.instance
    end
    local module = LPL.Modules:Get("builds")
    if module and module.instance then
        self.instance = module.instance
        return module.instance
    end
    return nil
end

function LPL.ImportExport:ClearRequest()
    self.requestedView = nil
    self.requestedExportText = nil
    self.requestedExportName = nil
end

function LPL.ImportExport:ApplyRequestedView()
    local instance = self:GetInstance()
    if not instance then
        return false
    end

    if self.requestedView == "export" then
        instance:ShowExportMode(self.requestedExportText, self.requestedExportName)
        self:ClearRequest()
        return true
    end

    if self.requestedView == "import" then
        instance:ShowImportMode()
        self:ClearRequest()
        return true
    end

    return false
end

function ImportExportModule:OnShow()
    if LPL.ImportExport:ApplyRequestedView() then
        return
    end

    -- Sidebar visit with no explicit OpenImport context.
    LPL.ImportExport.importContext = nil
    local instance = LPL.ImportExport:GetInstance()
    if instance then
        instance:ShowImportMode()
    end
end

function LPL.ImportExport:OpenImport(importContext)
    self.requestedView = "import"
    self.requestedExportText = nil
    self.requestedExportName = nil
    self.importContext = importContext -- "macros" | "addonsmanager" | nil
    LPL.Modules:Activate("builds")
    self:ApplyRequestedView()
end

function LPL.ImportExport:OpenExport(exportText, buildName)
    self.requestedView = "export"
    self.requestedExportText = exportText or ""
    self.requestedExportName = buildName
    LPL.Modules:Activate("builds")
    if not self:ApplyRequestedView() then
        C_Timer.After(0, function()
            self:ApplyRequestedView()
        end)
    end
end

LPL.Modules:Register({
    id = ImportExportModule.id,
    label = ImportExportModule.label,
    description = ImportExportModule.description,
    iconStem = ImportExportModule.iconStem,
    order = ImportExportModule.order,
    create = ImportExportModule.create,
    OnShow = function()
        ImportExportModule:OnShow()
    end,
})
