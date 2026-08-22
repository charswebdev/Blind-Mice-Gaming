local addonName, LPL = ...

LPL.LoadoutActivate = {}

local POST_TALENT_DELAY = 0.35
local busy = false

local function Fail(message)
    busy = false
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:PopSuppress()
    end
    print("|cffff6060LPL:|r " .. (message or "Could not activate loadout."))
    return false, message
end

local function Success(message)
    busy = false
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:PopSuppress()
        LPL.ActivateFeedback:Play(message)
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function Warn(message)
    print("|cffffcc00LPL:|r " .. message)
end

local function PrimaryID(set, pluralField)
    local ids = LPL.LoadoutStore:GetSegmentIDs(set, pluralField)
    return ids[1], #ids
end

local function NoteMulti(label, count)
    if count and count > 1 then
        Warn(string.format("%s: applying first of %d linked sets.", label, count))
    end
end

local function TryApply(label, applyFn, setID, count)
    if not setID then
        return true
    end
    NoteMulti(label, count)
    if not applyFn then
        Warn(string.format("%s: activate is unavailable.", label))
        return false
    end
    local ok = applyFn(setID)
    if not ok then
        Warn(string.format("%s: skipped (see message above).", label))
        return false
    end
    return true
end

local function ApplyNonTalentSegments(set)
    local applied = 0
    local skipped = 0

    local function run(label, pluralField, applyFn)
        local id, count = PrimaryID(set, pluralField)
        if not id then
            return
        end
        if TryApply(label, applyFn, id, count) then
            applied = applied + 1
        else
            skipped = skipped + 1
        end
    end

    -- Spec-dependent first, then bars/gear, then UI layouts.
    -- Classic Era: no Retail PvP talents or Cooldown Manager.
    run("Action Bars", "actionBarSetIDs", LPL.ActionBarActivate and function(id)
        return LPL.ActionBarActivate:ApplySet(id)
    end)
    run("Keybinds", "keybindSetIDs", LPL.KeybindActivate and function(id)
        return LPL.KeybindActivate:ApplySet(id)
    end)
    run("Equipment", "equipmentSetIDs", LPL.EquipmentActivate and function(id)
        return LPL.EquipmentActivate:ApplySet(id)
    end)
    run("Edit Mode", "editModeSetIDs", LPL.EditModeActivate and function(id)
        return LPL.EditModeActivate:ApplySet(id)
    end)

    return applied, skipped
end

local function ApplyAddonSetSegments(set)
    if not LPL.AddonSetActivate or not LPL.LoadoutStore then
        return false, 0
    end
    local ids = LPL.LoadoutStore:GetSegmentIDs(set, "addonSetIDs")
    if #ids == 0 then
        return false, 0
    end
    local ok = LPL.AddonSetActivate:Apply(LPL.AddonSetActivate.MODE_REPLACE, ids)
    return ok == true, #ids
end

local function CompleteLoadout(set, loadoutName, talentAttempted, talentOk)
    local applied, skipped = ApplyNonTalentSegments(set)
    if talentAttempted and talentOk then
        applied = applied + 1
    elseif talentAttempted and not talentOk then
        skipped = skipped + 1
    end

    local addonOk, addonCount = ApplyAddonSetSegments(set)
    if addonOk then
        applied = applied + 1
        if addonCount > 1 then
            Warn(string.format("Addon Sets: applied union of %d linked sets.", addonCount))
        end
    elseif addonCount > 0 then
        skipped = skipped + 1
        Warn("Addon Sets: skipped (see message above).")
    end

    if applied == 0 then
        return Fail(string.format('Could not apply any segments from "%s".', loadoutName))
    end

    local result
    if skipped > 0 then
        result = Success(string.format(
            'Applied loadout "%s" (%d segment%s applied, %d skipped).',
            loadoutName,
            applied,
            applied == 1 and "" or "s",
            skipped
        ))
    else
        result = Success(string.format('Applied loadout "%s".', loadoutName))
    end

    if addonOk and LPL.AddonSetActivate and LPL.AddonSetActivate.PromptReload then
        LPL.AddonSetActivate:PromptReload(string.format(
            'Loadout "%s" updated addon enable states.\n\nReload the UI now to apply addon changes?',
            loadoutName
        ))
    end

    return result
end

function LPL.LoadoutActivate:IsBusy()
    return busy
end

function LPL.LoadoutActivate:ApplyDraft(draftSet, name)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to activate.")
    end

    if busy then
        return Fail("A loadout activate is already in progress.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot activate a loadout in combat.")
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(draftSet) then
        local summary = LPL.SetRestrictions:GetSummaryLine(draftSet.restrictions)
            or "another character, class, or specialization"
        return Fail("This loadout is restricted to " .. summary .. ".")
    end

    if LPL.LoadoutStore:CountAttachedSegments(draftSet) == 0 then
        return Fail("Attach at least one segment before activating.")
    end

    local loadoutName = name or draftSet.name or "Loadout"
    local talentID, talentCount = PrimaryID(draftSet, "talentBuildIDs")

    busy = true
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:PlayStart()
        LPL.ActivateFeedback:PushSuppress()
    end
    print(string.format("|cff33cc33LPL:|r Activating loadout \"%s\"...", loadoutName))

    -- Safety: never leave Activate permanently locked if talent apply is cancelled mid-flight.
    C_Timer.After(60, function()
        if busy then
            busy = false
            if LPL.ActivateFeedback then
                LPL.ActivateFeedback:PopSuppress()
            end
            Warn("Loadout activate timed out.")
        end
    end)

    if not talentID then
        return CompleteLoadout(draftSet, loadoutName, false, false)
    end

    if not LPL.TalentActivate then
        Warn("Talents: activate is unavailable.")
        return CompleteLoadout(draftSet, loadoutName, true, false)
    end

    NoteMulti("Talents", talentCount)

    local started = LPL.TalentActivate:ApplyBuild(talentID, function(ok)
        if not busy then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            Fail("Cannot finish loadout activate in combat.")
            return
        end
        C_Timer.After(POST_TALENT_DELAY, function()
            if not busy then
                return
            end
            CompleteLoadout(draftSet, loadoutName, true, ok and true or false)
        end)
    end)

    if not started then
        -- TalentActivate Fail() schedules the completion callback; keep busy until then.
        return false
    end

    return true
end

function LPL.LoadoutActivate:ApplySet(setID)
    if not setID then
        return Fail("No loadout selected.")
    end
    local set = LPL.LoadoutStore:Get(setID)
    if not set then
        return Fail("Loadout not found.")
    end
    return self:ApplyDraft(set, set.name)
end
