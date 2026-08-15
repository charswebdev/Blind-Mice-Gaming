local addonName, LPL = ...

LPL.MacroStore = {}

LPL.MacroStore.MAX_NAME_LENGTH = 150
LPL.MacroStore.MAX_BODY_LENGTH = 255
LPL.MacroStore.DEFAULT_ICON = 134400 -- INV_Misc_QuestionMark

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_MACRO_SET"

local function GetMacrosData()
    return LPL.DB:GetMacros()
end

function LPL.MacroStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Macro"
    if type(name) ~= "string" then
        return fallback
    end
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        return fallback
    end
    if #name > self.MAX_NAME_LENGTH then
        name = name:sub(1, self.MAX_NAME_LENGTH)
    end
    return name
end

function LPL.MacroStore:NormalizeBody(body)
    if type(body) ~= "string" then
        return ""
    end
    if #body > self.MAX_BODY_LENGTH then
        body = body:sub(1, self.MAX_BODY_LENGTH)
    end
    return body
end

function LPL.MacroStore:NormalizeIcon(icon)
    local asNumber = tonumber(icon)
    if asNumber then
        return asNumber
    end
    if type(icon) == "string" and icon ~= "" then
        return icon
    end
    return self.DEFAULT_ICON
end

function LPL.MacroStore:EnsureSetsTable()
    local data = GetMacrosData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.MacroStore:GenerateID()
    local data = GetMacrosData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "macro_" .. data.nextSetId
end

function LPL.MacroStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Macro")
    set.icon = self:NormalizeIcon(set.icon)
    set.body = self:NormalizeBody(set.body)
    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt
    set.sourceMacroIndex = tonumber(set.sourceMacroIndex)
    if set.sourceMacroIndex and set.sourceMacroIndex < 1 then
        set.sourceMacroIndex = nil
    end
    if type(set.sourceMacroScope) ~= "string" or set.sourceMacroScope == "" then
        set.sourceMacroScope = nil
    end
    if type(set.sourceMacroName) ~= "string" or set.sourceMacroName == "" then
        set.sourceMacroName = nil
    end
    return set
end

function LPL.MacroStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        icon = self.DEFAULT_ICON,
        body = "",
        sourceMacroIndex = nil,
        sourceMacroScope = nil,
        sourceMacroName = nil,
    }
end

LPL.MacroStore.BLIZZARD_NAME_LENGTH = 16

function LPL.MacroStore:NormalizeBlizzardMacroName(name)
    name = self:NormalizeSetName(name, "")
    if name == "" then
        return ""
    end
    if #name > self.BLIZZARD_NAME_LENGTH then
        name = name:sub(1, self.BLIZZARD_NAME_LENGTH)
    end
    return name
end

function LPL.MacroStore:ApplyLiveMacroSource(draft, macro)
    if type(draft) ~= "table" or type(macro) ~= "table" then
        return draft
    end
    draft.name = macro.name or draft.name
    draft.icon = self:NormalizeIcon(macro.icon)
    draft.body = self:NormalizeBody(macro.body)
    draft.sourceMacroIndex = tonumber(macro.index)
    draft.sourceMacroScope = macro.scope
    draft.sourceMacroName = macro.name
    return draft
end

function LPL.MacroStore:ClearLiveMacroSource(draft)
    if type(draft) ~= "table" then
        return draft
    end
    draft.sourceMacroIndex = nil
    draft.sourceMacroScope = nil
    draft.sourceMacroName = nil
    return draft
end

function LPL.MacroStore:HasLiveMacroSource(draft)
    return type(draft) == "table" and (
        (draft.sourceMacroIndex and draft.sourceMacroIndex > 0)
        or (type(draft.sourceMacroScope) == "string" and draft.sourceMacroScope ~= "")
        or (type(draft.sourceMacroName) == "string" and draft.sourceMacroName ~= "")
    )
end

function LPL.MacroStore:FindLiveMacroIndexByName(wantName, scope)
    if type(wantName) ~= "string" or wantName == "" or not GetMacroInfo then
        return nil
    end
    wantName = self:NormalizeBlizzardMacroName(wantName)
    if wantName == "" then
        return nil
    end

    local numAccount, numCharacter = GetNumMacros()
    numAccount = numAccount or 0
    numCharacter = numCharacter or 0

    local function scan(startIndex, count)
        if count < 1 then
            return nil
        end
        for i = startIndex, startIndex + count - 1 do
            local name = GetMacroInfo(i)
            if name == wantName then
                return i
            end
        end
        return nil
    end

    local charStart = (MAX_ACCOUNT_MACROS or 120) + 1
    if scope == "Character" then
        return scan(charStart, numCharacter)
    end
    if scope == "Account" then
        return scan(1, numAccount)
    end
    return scan(1, numAccount) or scan(charStart, numCharacter)
end

function LPL.MacroStore:ResolveLiveMacroIndex(draft)
    if type(draft) ~= "table" then
        return nil
    end

    local index = tonumber(draft.sourceMacroIndex)
    if index and index > 0 and GetMacroInfo then
        local name = GetMacroInfo(index)
        if name then
            -- Index is still valid; keep it even if the player renamed the draft.
            return index
        end
    end

    local bySourceName = self:FindLiveMacroIndexByName(draft.sourceMacroName, draft.sourceMacroScope)
    if bySourceName then
        return bySourceName
    end

    return self:FindLiveMacroIndexByName(draft.name, draft.sourceMacroScope)
end

function LPL.MacroStore:NormalizeIconForEditMacro(icon)
    icon = self:NormalizeIcon(icon)
    if type(icon) == "number" and icon > 0 then
        return icon
    end
    if type(icon) == "string" and icon ~= "" then
        local asNumber = tonumber(icon)
        if asNumber and asNumber > 0 then
            return asNumber
        end
        local leaf = icon:match("[^\\/]+$") or icon
        leaf = leaf:gsub("%.blp$", ""):gsub("%.BLP$", "")
        if leaf ~= "" then
            return leaf
        end
    end
    return nil
end

function LPL.MacroStore:WriteToLiveMacro(draft)
    if type(draft) ~= "table" then
        return true, nil
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Saved to LPL library, but Blizzard macros cannot be updated in combat."
    end
    if not EditMacro then
        return false, "Saved to LPL library, but EditMacro is unavailable."
    end

    local index = self:ResolveLiveMacroIndex(draft)
    if not index then
        -- Still try a plain name match so Save updates Blizzard even without Load-from.
        index = self:FindLiveMacroIndexByName(draft.name, nil)
    end
    if not index then
        if self:HasLiveMacroSource(draft) then
            return false, "Saved to LPL library, but the original Blizzard macro was not found."
        end
        -- LPL-only entry with no matching Blizzard macro name — leave Blizzard alone.
        return true, nil
    end

    local blizzardName = self:NormalizeBlizzardMacroName(draft.name)
    if blizzardName == "" then
        local existingName = GetMacroInfo(index)
        blizzardName = self:NormalizeBlizzardMacroName(existingName)
    end
    if blizzardName == "" then
        return false, "Saved to LPL library, but Blizzard macro name is empty."
    end

    local body = self:NormalizeBody(draft.body)
    local icon = self:NormalizeIconForEditMacro(draft.icon)

    local ok, result = pcall(EditMacro, index, blizzardName, icon, body)
    if not ok then
        -- Retry without icon — bad icon values are a common EditMacro failure.
        ok, result = pcall(EditMacro, index, blizzardName, nil, body)
    end
    if not ok then
        return false, "Saved to LPL library, but updating the Blizzard macro failed (" .. tostring(result) .. ")."
    end

    local newIndex = tonumber(result) or index
    -- Best-effort confirm; GetMacroInfo can lag a frame after EditMacro.
    if GetMacroInfo then
        local _, _, liveBody = GetMacroInfo(newIndex)
        if self:NormalizeBody(liveBody) ~= body then
            local retryOk, retryResult = pcall(EditMacro, newIndex, nil, nil, body)
            if retryOk then
                newIndex = tonumber(retryResult) or newIndex
            end
        end
    end

    draft.sourceMacroIndex = newIndex
    draft.sourceMacroName = blizzardName
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    draft.sourceMacroScope = newIndex > maxAccount and "Character" or "Account"

    if #self:NormalizeSetName(draft.name, "") > self.BLIZZARD_NAME_LENGTH then
        return true, string.format(
            "Updated %s macro \"%s\" (Blizzard name truncated to %d characters).",
            draft.sourceMacroScope,
            blizzardName,
            self.BLIZZARD_NAME_LENGTH
        )
    end

    return true, string.format("Updated %s macro \"%s\".", draft.sourceMacroScope, blizzardName)
end

function LPL.MacroStore:SuggestSetName()
    return "New Macro"
end

function LPL.MacroStore:Get(setID)
    if not setID then
        return nil
    end
    local sets = self:EnsureSetsTable()
    return self:NormalizeSetRecord(sets[tostring(setID)])
end

function LPL.MacroStore:GetAll()
    local list = {}
    for _, set in pairs(self:EnsureSetsTable()) do
        local normalized = self:NormalizeSetRecord(set)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.MacroStore:GetSummaryLine(set)
    if type(set) ~= "table" then
        return "Invalid macro"
    end
    local body = self:NormalizeBody(set.body)
    local icon = self:NormalizeIcon(set.icon)
    local iconLabel = type(icon) == "number" and ("#" .. tostring(icon)) or tostring(icon)
    local line = string.format("Icon %s · %d / %d characters", iconLabel, #body, self.MAX_BODY_LENGTH)
    if self:HasLiveMacroSource(set) then
        local scope = set.sourceMacroScope or "Blizzard"
        line = line .. string.format(" · Linked to %s macro", scope)
    end
    return line
end

function LPL.MacroStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    sets[set.id] = set
    return true
end

function LPL.MacroStore:Delete(setID)
    if not setID then
        return false
    end
    local sets = self:EnsureSetsTable()
    setID = tostring(setID)
    if not sets[setID] then
        return false
    end
    sets[setID] = nil
    return true
end

function LPL.MacroStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end
    local name = self:NormalizeSetName(draft.name, "")
    if name == "" then
        return false, "Enter a macro name before saving."
    end
    return true
end

function LPL.MacroStore:SaveFromEditor(setID, name, draft, onSaved)
    draft = draft or {}
    draft.name = name
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save macro."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestSetName())
    draft.name = name
    draft.icon = self:NormalizeIcon(draft.icon)
    draft.body = self:NormalizeBody(draft.body)

    local liveOk, liveMsg = self:WriteToLiveMacro(draft)

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.icon = draft.icon
        set.body = draft.body
        set.sourceMacroIndex = draft.sourceMacroIndex
        set.sourceMacroScope = draft.sourceMacroScope
        set.sourceMacroName = draft.sourceMacroName
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved macro \"%s\".", name))
        if liveOk and liveMsg then
            print("|cff33cc33LPL:|r " .. liveMsg)
        elseif not liveOk and liveMsg then
            print("|cffffcc00LPL:|r " .. liveMsg)
        end
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        icon = draft.icon,
        body = draft.body,
        sourceMacroIndex = draft.sourceMacroIndex,
        sourceMacroScope = draft.sourceMacroScope,
        sourceMacroName = draft.sourceMacroName,
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created macro \"%s\".", name))
    if liveOk and liveMsg then
        print("|cff33cc33LPL:|r " .. liveMsg)
    elseif not liveOk and liveMsg then
        print("|cffffcc00LPL:|r " .. liveMsg)
    end
    return true
end

function LPL.MacroStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete macro \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.MacroStore:Delete(data.setID) then
                    if data.onConfirm then
                        data.onConfirm()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Macro", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end
