local addonName, LPL = ...

LPL.PvpTalentCodec = {}

local SLOT_COUNT = 3

local function GetSlotCount()
    return (LPL.PvpTalentStore and LPL.PvpTalentStore.SLOT_COUNT) or SLOT_COUNT
end

function LPL.PvpTalentCodec:GetPlayerClassAndSpec()
    if LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity then
        return LPL.TalentTree:GetPlayerIdentity()
    end
    local classID = select(3, UnitClass("player"))
    local specID
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex and specIndex > 0 then
        specID = select(1, GetSpecializationInfo(specIndex))
    end
    return classID, specID
end

function LPL.PvpTalentCodec:GetClassIDForSpec(specID)
    specID = tonumber(specID)
    if not specID then
        return nil
    end
    if LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec then
        return LPL.TalentTree:GetClassIDForSpec(specID)
    end
    -- GetSpecializationInfoByID returns classFile as 6th; resolve classID via TalentTree when available.
    return nil
end

function LPL.PvpTalentCodec:GetTalentInfo(talentID)
    talentID = tonumber(talentID)
    if not talentID or talentID < 1 then
        return nil
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentInfo then
        local info = C_SpecializationInfo.GetPvpTalentInfo(talentID)
        if type(info) == "table" and info.talentID then
            return {
                talentID = info.talentID,
                name = info.name,
                icon = info.icon,
                spellID = info.spellID,
                unlocked = info.unlocked,
                available = info.available,
            }
        end
    end

    if GetPvpTalentInfoByID then
        local id, name, icon, _, _, spellID, unlocked = GetPvpTalentInfoByID(talentID)
        if id then
            return {
                talentID = id,
                name = name,
                icon = icon,
                spellID = spellID,
                unlocked = unlocked,
            }
        end
    end

    return nil
end

function LPL.PvpTalentCodec:GetAvailableTalentIDs(specID, slotIndex)
    specID = tonumber(specID)
    slotIndex = tonumber(slotIndex) or 1
    if not specID then
        return {}, false
    end

    local _, playerSpecID = self:GetPlayerClassAndSpec()
    if playerSpecID == specID and C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentSlotInfo then
        local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex)
        if type(slotInfo) == "table" and type(slotInfo.availableTalentIDs) == "table" and #slotInfo.availableTalentIDs > 0 then
            return CopyTable(slotInfo.availableTalentIDs), true
        end
    end

    local static = LPL.PvpTalentData and LPL.PvpTalentData.talentsBySpec and LPL.PvpTalentData.talentsBySpec[specID]
    if type(static) == "table" and #static > 0 then
        return CopyTable(static), false
    end

    return {}, false
end

function LPL.PvpTalentCodec:SanitizeDraft(draft)
    if type(draft) ~= "table" then
        return draft
    end
    draft.talents = draft.talents or {}
    local seen = {}
    for slot = 1, GetSlotCount() do
        local talentID = tonumber(draft.talents[slot])
        if talentID and talentID > 0 and not seen[talentID] then
            draft.talents[slot] = talentID
            seen[talentID] = true
        else
            draft.talents[slot] = nil
        end
    end
    draft.specID = tonumber(draft.specID)
    if draft.specID and LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec then
        draft.classID = LPL.TalentTree:GetClassIDForSpec(draft.specID)
    else
        draft.classID = tonumber(draft.classID)
    end
    return draft
end

function LPL.PvpTalentCodec:AssignTalent(draft, slotIndex, talentID)
    if type(draft) ~= "table" then
        return false
    end
    slotIndex = tonumber(slotIndex)
    talentID = tonumber(talentID)
    if not slotIndex or slotIndex < 1 or slotIndex > GetSlotCount() then
        return false
    end

    draft.talents = draft.talents or {}
    if not talentID or talentID < 1 then
        draft.talents[slotIndex] = nil
        return true
    end

    for slot = 1, GetSlotCount() do
        if slot ~= slotIndex and tonumber(draft.talents[slot]) == talentID then
            draft.talents[slot] = nil
        end
    end
    draft.talents[slotIndex] = talentID
    return true
end

function LPL.PvpTalentCodec:CanCaptureFromCharacter(draft)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot update PvP talents in combat."
    end
    local _, playerSpecID = self:GetPlayerClassAndSpec()
    if not playerSpecID then
        return false, "No active specialization."
    end
    if draft and draft.specID and tonumber(draft.specID) ~= playerSpecID then
        return false, "Switch to this specialization before updating from your character."
    end
    return true
end

function LPL.PvpTalentCodec:CaptureFromCharacter(draft)
    draft = draft or {}
    local ok, err = self:CanCaptureFromCharacter(draft)
    if not ok then
        return nil, err
    end

    local classID, specID = self:GetPlayerClassAndSpec()
    draft.classID = classID
    draft.specID = specID
    draft.talents = draft.talents or {}
    wipe(draft.talents)

    if C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentSlotInfo then
        for slot = 1, GetSlotCount() do
            local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slot)
            local talentID = slotInfo and tonumber(slotInfo.selectedTalentID)
            if talentID and talentID > 0 then
                draft.talents[slot] = talentID
            end
        end
    elseif C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs then
        local selected = C_SpecializationInfo.GetAllSelectedPvpTalentIDs() or {}
        for slot = 1, math.min(GetSlotCount(), #selected) do
            local talentID = tonumber(selected[slot])
            if talentID and talentID > 0 then
                draft.talents[slot] = talentID
            end
        end
    end

    return self:SanitizeDraft(draft)
end

function LPL.PvpTalentCodec:ShowTalentTooltip(owner, talentID, options)
    if not owner or not talentID then
        return
    end
    options = options or {}
    local info = self:GetTalentInfo(talentID)
    if not info then
        return
    end

    if GameTooltip and GameTooltip.SetPvpTalent then
        GameTooltip:SetOwner(owner, options.anchor or "ANCHOR_RIGHT")
        if LPL.ResetGameTooltipContent then
            LPL:ResetGameTooltipContent(GameTooltip)
        elseif GameTooltip.ClearLines then
            GameTooltip:ClearLines()
        end
        local ok = pcall(GameTooltip.SetPvpTalent, GameTooltip, talentID)
        if ok then
            GameTooltip:Show()
            if LPL.SetGameTooltipAccessibilityPlain then
                local plain = LPL:CollectGameTooltipPlainText(GameTooltip)
                LPL:SetGameTooltipAccessibilityPlain(GameTooltip, owner, plain)
            end
            return
        end
    end

    if info.spellID and LPL.ShowGameTooltip then
        LPL:ShowGameTooltip(owner, {
            spellID = info.spellID,
            anchor = options.anchor or "ANCHOR_RIGHT",
        })
        return
    end

    if LPL.ShowAccessibleGameTooltip then
        LPL:ShowAccessibleGameTooltip(owner, info.name or "PvP Talent", nil, {
            anchor = options.anchor or "ANCHOR_RIGHT",
        })
    end
end

function LPL.PvpTalentCodec:HideTalentTooltip(owner)
    if LPL.ClearGameTooltipData then
        LPL:ClearGameTooltipData(GameTooltip)
    elseif GameTooltip then
        GameTooltip:Hide()
    end
end
