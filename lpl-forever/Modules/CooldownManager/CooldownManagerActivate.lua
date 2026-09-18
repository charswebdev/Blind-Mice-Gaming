local addonName, LPL = ...

LPL.CooldownManagerActivate = {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply Cooldown Manager set."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function ApplySetData(setData, setName)
    if type(setData) ~= "table" then
        return Fail("Invalid Cooldown Manager set.")
    end

    if LPL.CooldownManagerCodec then
        LPL.CooldownManagerCodec:SanitizeDraft(setData)
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(setData) then
        local summary = LPL.SetRestrictions:GetSummaryLine(setData.restrictions)
            or "another character, class, or specialization"
        return Fail("This Cooldown Manager set is restricted to " .. summary .. ".")
    end

    local layoutString = setData.layoutString
    if type(layoutString) ~= "string" or layoutString:match("^%s*$") then
        return Fail(string.format('"%s" has no Cooldown Manager layout string.', setName or setData.name or "Set"))
    end

    local ok, err = LPL.CooldownManagerCodec:ApplyLayoutString(layoutString)
    if not ok then
        return Fail(err)
    end

    setName = setName or setData.name or "Cooldown Manager Set"
    return Success(string.format('Applied "%s" to Cooldown Manager.', setName))
end

function LPL.CooldownManagerActivate:ApplySet(setID)
    if not setID then
        return Fail("No Cooldown Manager set selected.")
    end
    local set = LPL.CooldownManagerStore:Get(setID)
    if not set then
        return Fail("Cooldown Manager set not found.")
    end
    return ApplySetData(CopyTable(set), set.name)
end

function LPL.CooldownManagerActivate:ApplyDraft(draftSet, name)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to apply.")
    end
    local draft = CopyTable(draftSet)
    draft.name = name or draft.name
    return ApplySetData(draft, draft.name)
end
