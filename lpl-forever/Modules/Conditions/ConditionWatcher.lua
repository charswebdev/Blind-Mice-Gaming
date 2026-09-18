local addonName, LPL = ...

LPL.ConditionWatcher = {}

local DEBOUNCE_SECONDS = 0.35
local TIME_TICK_SECONDS = 60

local started = false
local evaluatePending = false
local combatDeferred = false
local suppressedKey = nil
local handledKey = nil
local promptOpen = false

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function ClearPromptState()
    promptOpen = false
    if LPL.ConditionPrompt then
        LPL.ConditionPrompt:Hide()
    end
end

local function ApplyTarget(target)
    if type(target) ~= "table" then
        return false
    end
    if InCombat() then
        combatDeferred = true
        print("|cffffcc00LPL:|r Condition apply deferred until combat ends.")
        return false
    end
    return LPL.ConditionStore:ApplyTarget(target)
end

local function OnAccept(match, target)
    promptOpen = false
    if match and match.situationKey then
        handledKey = match.situationKey
        suppressedKey = nil
    end
    ApplyTarget(target)
end

local function OnDecline(match)
    promptOpen = false
    if match and match.situationKey then
        suppressedKey = match.situationKey
    end
end

local function TryPrompt(match)
    if not match then
        return
    end

    local key = match.situationKey
    if key and (key == suppressedKey or key == handledKey) then
        return
    end

    if promptOpen or (LPL.ConditionPrompt and LPL.ConditionPrompt:IsShown()) then
        return
    end

    if LPL.LoadoutActivate and LPL.LoadoutActivate:IsBusy() then
        return
    end

    promptOpen = true
    local shown = LPL.ConditionPrompt:Show(match, function(_, target)
        OnAccept(match, target)
    end, function()
        OnDecline(match)
    end)

    if not shown then
        promptOpen = false
    end
end

function LPL.ConditionWatcher:EvaluateNow(force)
    if not LPL.ConditionStore or not LPL.ConditionMatcher then
        return false
    end

    if not LPL.ConditionStore:IsMasterEnabled() then
        ClearPromptState()
        return false
    end

    local ctx = LPL.ConditionMatcher:BuildContext()
    local key = LPL.ConditionMatcher:GetSituationKey(ctx)

    -- Situation changed: allow prompting again even after a prior decline/apply.
    if handledKey and handledKey ~= key then
        handledKey = nil
    end
    if suppressedKey and suppressedKey ~= key then
        suppressedKey = nil
    end

    if force then
        -- Manual check can re-offer after a prior apply or decline in the same situation.
        handledKey = nil
        suppressedKey = nil
    end

    local match = LPL.ConditionMatcher:FindMatch(ctx)
    if not match then
        if force then
            ClearPromptState()
        end
        return false
    end

    if InCombat() then
        combatDeferred = true
        return false
    end

    combatDeferred = false
    TryPrompt(match)
    return true
end

local function ScheduleEvaluate()
    if evaluatePending then
        return
    end
    evaluatePending = true
    C_Timer.After(DEBOUNCE_SECONDS, function()
        evaluatePending = false
        LPL.ConditionWatcher:EvaluateNow(false)
    end)
end

function LPL.ConditionWatcher:Start()
    if started then
        return
    end
    started = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("PLAYER_UPDATE_RESTING")
    frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
    frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")

    if C_EventUtils and C_EventUtils.IsEventValid then
        if C_EventUtils.IsEventValid("WALK_IN_DATA_UPDATE") then
            frame:RegisterEvent("WALK_IN_DATA_UPDATE")
        end
        if C_EventUtils.IsEventValid("ACTIVE_DELVE_DATA_UPDATE") then
            frame:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE")
        end
        if C_EventUtils.IsEventValid("PLAYER_HOUSING_STATE_UPDATED") then
            frame:RegisterEvent("PLAYER_HOUSING_STATE_UPDATED")
        end
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            if combatDeferred then
                combatDeferred = false
                ScheduleEvaluate()
            end
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
            return
        end

        ScheduleEvaluate()
    end)

    C_Timer.NewTicker(TIME_TICK_SECONDS, function()
        if not LPL.ConditionStore:IsMasterEnabled() then
            return
        end
        ScheduleEvaluate()
    end)

    -- First pass shortly after login/reload settles.
    C_Timer.After(1.0, function()
        LPL.ConditionWatcher:EvaluateNow(false)
    end)
end

function LPL.ConditionWatcher:NotifySettingsChanged()
    -- Master toggle / rule edits: re-evaluate, but keep decline suppress for current key.
    ScheduleEvaluate()
end
