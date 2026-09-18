local addonName, LPL = ...

LPL.PvpTalentActivate = {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply PvP talent set."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function GetSlotCount()
    return (LPL.PvpTalentStore and LPL.PvpTalentStore.SLOT_COUNT) or 3
end

local function GetSelectedTalentID(slotIndex)
    if not C_SpecializationInfo or not C_SpecializationInfo.GetPvpTalentSlotInfo then
        return nil
    end
    local info = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex)
    return info and tonumber(info.selectedTalentID) or nil
end

local function IsSlotEnabled(slotIndex)
    if not C_SpecializationInfo or not C_SpecializationInfo.GetPvpTalentSlotInfo then
        return false
    end
    local info = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex)
    return info and info.enabled == true
end

local function TalentUnlocked(talentID)
    talentID = tonumber(talentID)
    if not talentID then
        return false
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentUnlockLevel then
        local level = C_SpecializationInfo.GetPvpTalentUnlockLevel(talentID)
        if level and UnitLevel and UnitLevel("player") < level then
            return false
        end
    end
    local info = LPL.PvpTalentCodec and LPL.PvpTalentCodec:GetTalentInfo(talentID)
    if info and info.unlocked == false then
        return false
    end
    return true
end

local function CanUsePvpTalentUI()
    if C_SpecializationInfo and C_SpecializationInfo.CanPlayerUsePVPTalentUI then
        local canUse, reason = C_SpecializationInfo.CanPlayerUsePVPTalentUI()
        if not canUse then
            return false, reason or "PvP talents cannot be changed right now."
        end
    end
    return true
end

local function LearnIntoSlot(talentID, slotIndex)
    if not LearnPvpTalent then
        return false, "LearnPvpTalent is unavailable."
    end
    local ok, result = pcall(LearnPvpTalent, talentID, slotIndex)
    if not ok then
        return false, "Failed to learn PvP talent."
    end
    -- LearnPvpTalent returns true on success in modern clients.
    if result == false then
        return false, "Could not learn that PvP talent."
    end
    return true
end

local function ApplySetData(setData, setName)
    if type(setData) ~= "table" then
        return Fail("Invalid PvP talent set.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot apply PvP talents in combat.")
    end

    local canUse, reason = CanUsePvpTalentUI()
    if not canUse then
        return Fail(reason)
    end

    if LPL.PvpTalentCodec then
        LPL.PvpTalentCodec:SanitizeDraft(setData)
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(setData) then
        local summary = LPL.SetRestrictions:GetSummaryLine(setData.restrictions)
            or "another character, class, or specialization"
        return Fail("This PvP set is restricted to " .. summary .. ".")
    end

    local _, playerSpecID = LPL.PvpTalentCodec:GetPlayerClassAndSpec()
    local setSpecID = tonumber(setData.specID)
    if setSpecID and playerSpecID and setSpecID ~= playerSpecID then
        local specName = select(2, GetSpecializationInfoByID(setSpecID))
        return Fail(string.format(
            "Switch to %s before applying this PvP set.",
            specName or "the matching specialization"
        ))
    end

    if not LearnPvpTalent then
        return Fail("PvP talent learning is unavailable.")
    end

    local applied = 0
    local skipped = 0
    local slotCount = GetSlotCount()

    for slot = 1, slotCount do
        local talentID = setData.talents and tonumber(setData.talents[slot])
        if talentID and talentID > 0 then
            if not IsSlotEnabled(slot) then
                skipped = skipped + 1
            elseif not TalentUnlocked(talentID) then
                skipped = skipped + 1
            elseif GetSelectedTalentID(slot) == talentID then
                applied = applied + 1
            else
                local ok = LearnIntoSlot(talentID, slot)
                if ok then
                    applied = applied + 1
                else
                    skipped = skipped + 1
                end
            end
        end
    end

    setName = setName or setData.name or "PvP Set"
    if applied == 0 and skipped > 0 then
        return Fail(string.format('Could not apply any talents from "%s".', setName))
    end
    if skipped > 0 then
        if LPL.ActivateFeedback then
            LPL.ActivateFeedback:Play()
        end
        print(string.format(
            "|cffffcc00LPL:|r Applied \"%s\" with %d talent%s skipped (locked slot, level, or unavailable).",
            setName,
            skipped,
            skipped == 1 and "" or "s"
        ))
        return true
    end
    if applied == 0 then
        return Fail(string.format('"%s" has no PvP talents to apply.', setName))
    end
    return Success(string.format('Applied "%s" to your PvP talents.', setName))
end

function LPL.PvpTalentActivate:ApplySet(setID)
    if not setID then
        return Fail("No PvP set selected.")
    end
    local set = LPL.PvpTalentStore:Get(setID)
    if not set then
        return Fail("PvP set not found.")
    end
    return ApplySetData(CopyTable(set), set.name)
end

function LPL.PvpTalentActivate:ApplyDraft(draftSet, name)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to apply.")
    end
    local draft = CopyTable(draftSet)
    draft.name = name or draft.name
    return ApplySetData(draft, draft.name)
end
