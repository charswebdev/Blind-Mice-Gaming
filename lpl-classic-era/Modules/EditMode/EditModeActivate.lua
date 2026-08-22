local addonName, LPL = ...

LPL.EditModeActivate = {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply Edit Mode layout."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play(message)
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function ApplySetData(setData, setName)
    if type(setData) ~= "table" then
        return Fail("Invalid Edit Mode layout.")
    end

    if LPL.EditModeCodec then
        LPL.EditModeCodec:SanitizeDraft(setData)
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(setData) then
        local summary = LPL.SetRestrictions:GetSummaryLine(setData.restrictions)
            or "another character, class, or specialization"
        return Fail("This Edit Mode layout is restricted to " .. summary .. ".")
    end

    local layoutString = setData.layoutString
    if type(layoutString) ~= "string" or layoutString:match("^%s*$") then
        return Fail(string.format('"%s" has no Edit Mode layout string.', setName or setData.name or "Layout"))
    end

    local ok, err = LPL.EditModeCodec:ApplyLayoutString(layoutString, {
        name = setName or setData.name,
        editModeCharacterSpecific = setData.editModeCharacterSpecific,
        setID = setData.id,
    })
    if not ok then
        return Fail(err)
    end

    setName = setName or setData.name or "Edit Mode Layout"
    return Success(string.format('Applied "%s" to Edit Mode.', setName))
end

function LPL.EditModeActivate:ApplySet(setID)
    if not setID then
        return Fail("No Edit Mode layout selected.")
    end
    local set = LPL.EditModeStore:Get(setID)
    if not set then
        return Fail("Edit Mode layout not found.")
    end
    return ApplySetData(CopyTable(set), set.name)
end

function LPL.EditModeActivate:ApplyDraft(draftSet, name)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to apply.")
    end
    local draft = CopyTable(draftSet)
    draft.name = name or draft.name
    return ApplySetData(draft, draft.name)
end
