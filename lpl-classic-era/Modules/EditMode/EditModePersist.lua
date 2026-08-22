local addonName, LPL = ...

-- Classic Era: Blizzard resets Edit Mode / keybinds across reload.
-- Evidence from live WTF (FREYAHEART): editMode.lastApplied IS saved, but a
-- parallel db.persist bucket was not. Restore must use lastApplied / set IDs
-- on the real SavedVariables table, force re-apply on login, and always chat.

LPL.EditModePersist = {}

local restorePending = false
local restoreAttempt = 0
local MAX_RESTORE_ATTEMPTS = 10

-- Prefer the addon-environment SavedVariables global (what WoW serializes).
local function ResolveDB()
    if type(LPLClassicEraDB) ~= "table" then
        if type(_G.LPLClassicEraDB) == "table" then
            LPLClassicEraDB = _G.LPLClassicEraDB
        else
            LPLClassicEraDB = {}
        end
    end
    _G.LPLClassicEraDB = LPLClassicEraDB
    if LPL.DB then
        LPL.DB.data = LPLClassicEraDB
    end
    if type(LPLClassicEraDB.editMode) ~= "table" then
        LPLClassicEraDB.editMode = {}
    end
    if type(LPLClassicEraDB.keybinds) ~= "table" then
        LPLClassicEraDB.keybinds = { sets = {}, nextSetId = 0 }
    end
    if type(LPLClassicEraDB.actionBars) ~= "table" then
        LPLClassicEraDB.actionBars = { sets = {}, nextSetId = 0 }
    end
    -- Keep optional mirror bucket, but do not rely on it (it was missing from WTF).
    if type(LPLClassicEraDB.persist) ~= "table" then
        LPLClassicEraDB.persist = {}
    end
    if type(LPLClassicEraDB.persist.editMode) ~= "table" then
        LPLClassicEraDB.persist.editMode = {}
    end
    if type(LPLClassicEraDB.persist.keybinds) ~= "table" then
        LPLClassicEraDB.persist.keybinds = {}
    end
    if type(LPLClassicEraDB.persist.actionBars) ~= "table" then
        LPLClassicEraDB.persist.actionBars = {}
    end
    return LPLClassicEraDB
end

local function HasLayoutString(bucket)
    return type(bucket) == "table"
        and type(bucket.layoutString) == "string"
        and bucket.layoutString ~= ""
end

local function GetRememberedEditMode()
    local db = ResolveDB()
    if HasLayoutString(db.editMode.lastApplied) then
        return db.editMode.lastApplied, "lastApplied"
    end
    if HasLayoutString(db.persist.editMode) then
        return db.persist.editMode, "persist"
    end
    if LPL.EditModeStore and LPL.EditModeStore.GetAll then
        local sets = LPL.EditModeStore:GetAll()
        local best
        for i = 1, #sets do
            local set = sets[i]
            if HasLayoutString(set) then
                if not best or (tonumber(set.updatedAt) or 0) > (tonumber(best.updatedAt) or 0) then
                    best = set
                end
            end
        end
        if best then
            return {
                layoutString = best.layoutString,
                name = best.name,
                setID = best.id,
                editModeCharacterSpecific = best.editModeCharacterSpecific ~= false,
            }, "store"
        end
    end
    return nil, "none"
end

local function GetRememberedKeybindSetID()
    local db = ResolveDB()
    local setID = db.keybinds.lastAppliedSetID or db.persist.keybinds.setID
    if setID and setID ~= "" then
        return tostring(setID), db.keybinds.lastAppliedScope or db.persist.keybinds.scope, "remembered"
    end
    if LPL.KeybindStore and LPL.KeybindStore.GetAll then
        local sets = LPL.KeybindStore:GetAll()
        local best
        for i = 1, #sets do
            local set = sets[i]
            if set and set.id then
                if not best or (tonumber(set.updatedAt) or 0) > (tonumber(best.updatedAt) or 0) then
                    best = set
                end
            end
        end
        if best then
            return tostring(best.id), best.scope, "store"
        end
    end
    return nil, nil, "none"
end

local function GetRememberedActionBarSetID()
    local db = ResolveDB()
    local setID = db.actionBars.lastAppliedSetID or db.persist.actionBars.setID
    if setID and setID ~= "" then
        return tostring(setID), "remembered"
    end
    return nil, "none"
end

local function ActiveEditModeIsPreset()
    if not LPL.EditModeCodec or not LPL.EditModeCodec.EnsureAPI or not LPL.EditModeCodec:EnsureAPI() then
        return true
    end
    if not C_EditMode or not C_EditMode.GetLayouts then
        return true
    end
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" then
        return true
    end
    local active = tonumber(info.activeLayout)
    if not active then
        return true
    end
    -- When GetActiveLayoutInfo fails with "preset", treat as needs restore.
    local layout, err = LPL.EditModeCodec:GetActiveLayoutInfo()
    if not layout then
        if type(err) == "string" and err:find("preset", 1, true) then
            return true
        end
        -- No readable custom layout → force restore.
        return true
    end
    return false
end

function LPL.EditModePersist:RememberApplied(layoutString, options)
    options = options or {}
    layoutString = LPL.EditModeCodec and LPL.EditModeCodec:NormalizeLayoutString(layoutString) or layoutString
    if type(layoutString) ~= "string" or layoutString == "" then
        return
    end

    local db = ResolveDB()
    local record = {
        layoutString = layoutString,
        name = options.name,
        setID = options.setID and tostring(options.setID) or nil,
        editModeCharacterSpecific = options.editModeCharacterSpecific ~= false,
        updatedAt = time(),
    }
    db.editMode.lastApplied = CopyTable(record)
    db.persist.editMode = CopyTable(record)
end

function LPL.EditModePersist:RememberKeybindSet(setID, scope)
    local db = ResolveDB()
    local id = setID and tostring(setID) or nil
    db.keybinds.lastAppliedSetID = id
    db.keybinds.lastAppliedScope = scope
    db.keybinds.lastAppliedAt = time()
    db.persist.keybinds.setID = id
    db.persist.keybinds.scope = scope
    db.persist.keybinds.updatedAt = time()
end

function LPL.EditModePersist:RememberActionBarSet(setID)
    local db = ResolveDB()
    local id = setID and tostring(setID) or nil
    db.actionBars.lastAppliedSetID = id
    db.persist.actionBars.setID = id
    db.persist.actionBars.updatedAt = time()
end

function LPL.EditModePersist:RestoreEditModeIfNeeded(force)
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end

    local bucket, source = GetRememberedEditMode()
    if not bucket then
        return false, "nothing-saved"
    end

    if not LPL.EditModeCodec or not LPL.EditModeCodec.EnsureAPI then
        return false, "no-codec"
    end
    if not LPL.EditModeCodec:EnsureAPI() then
        return false, "api-not-ready"
    end

    -- Classic often reports a matching layout string while the HUD is still a preset.
    -- Only skip when we are sure a custom layout is active and force was not requested.
    if not force and not ActiveEditModeIsPreset() then
        local wanted = bucket.layoutString
        if LPL.EditModeActive and LPL.EditModeActive.IsActive then
            if LPL.EditModeActive:IsActive({ layoutString = wanted, restrictions = {} }) then
                return false, "already-active:" .. source
            end
        end
    end

    local ok, err
    if bucket.setID and LPL.EditModeStore and LPL.EditModeActivate then
        local set = LPL.EditModeStore:Get(bucket.setID)
        if set and HasLayoutString(set) then
            if LPL.ActivateFeedback and LPL.ActivateFeedback.PushSuppress then
                LPL.ActivateFeedback:PushSuppress()
            end
            ok = LPL.EditModeActivate:ApplySet(bucket.setID)
            if LPL.ActivateFeedback and LPL.ActivateFeedback.PopSuppress then
                LPL.ActivateFeedback:PopSuppress()
            end
            if ok then
                return true, "restored-set"
            end
        end
    end

    ok, err = LPL.EditModeCodec:ApplyLayoutString(bucket.layoutString, {
        name = bucket.name or "LPL Layout",
        editModeCharacterSpecific = bucket.editModeCharacterSpecific ~= false,
        setID = bucket.setID,
    })
    if ok then
        return true, "restored-string"
    end
    return false, tostring(err or "apply-failed")
end

function LPL.EditModePersist:RestoreKeybindsIfNeeded()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if not LPL.KeybindStore or not LPL.KeybindActivate then
        return false, "no-api"
    end

    local setID, scope, source = GetRememberedKeybindSetID()
    if not setID then
        return false, "nothing-saved"
    end

    local set = LPL.KeybindStore:Get(setID)
    if not set then
        return false, "missing-set"
    end

    if LPL.ActivateFeedback and LPL.ActivateFeedback.PushSuppress then
        LPL.ActivateFeedback:PushSuppress()
    end
    -- Always re-apply on login; Classic binding set flips are unreliable to detect.
    local ok = LPL.KeybindActivate:ApplySet(setID, { skipRemember = false, silent = true })
    if LPL.ActivateFeedback and LPL.ActivateFeedback.PopSuppress then
        LPL.ActivateFeedback:PopSuppress()
    end
    if ok then
        if scope then
            LPL.EditModePersist:RememberKeybindSet(setID, scope)
        end
        return true, "restored"
    end
    return false, "apply-failed"
end

function LPL.EditModePersist:RestoreActionBarsIfNeeded()
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    if not LPL.ActionBarStore or not LPL.ActionBarActivate then
        return false, "no-api"
    end
    local setID, source = GetRememberedActionBarSetID()
    if not setID then
        return false, "nothing-saved"
    end
    local set = LPL.ActionBarStore:Get(setID)
    if not set then
        return false, "missing-set"
    end
    if LPL.ActivateFeedback and LPL.ActivateFeedback.PushSuppress then
        LPL.ActivateFeedback:PushSuppress()
    end
    local ok = LPL.ActionBarActivate:ApplySet(setID)
    if LPL.ActivateFeedback and LPL.ActivateFeedback.PopSuppress then
        LPL.ActivateFeedback:PopSuppress()
    end
    if ok then
        return true, "restored"
    end
    return false, "apply-failed"
end

local function RunRestorePass()
    if InCombatLockdown and InCombatLockdown() then
        restorePending = true
        return
    end

    restoreAttempt = restoreAttempt + 1
    ResolveDB()

    local editBucket = GetRememberedEditMode()

    -- First attempts always force Edit Mode re-apply (Classic preset snap-back).
    local forceEdit = restoreAttempt <= 3
    local editOk, editReason = LPL.EditModePersist:RestoreEditModeIfNeeded(forceEdit)
    local keyOk, keyReason = LPL.EditModePersist:RestoreKeybindsIfNeeded()
    LPL.EditModePersist:RestoreActionBarsIfNeeded()

    local retryEdit = (not editOk) and (
        editReason == "api-not-ready"
        or editReason == "no-codec"
        or editReason == "apply-failed"
        or editReason == "combat"
        or (type(editReason) == "string" and editReason:find("loading", 1, true))
    )
    local retryKeys = (not keyOk) and (keyReason == "apply-failed" or keyReason == "combat")

    if (retryEdit or retryKeys) and restoreAttempt < MAX_RESTORE_ATTEMPTS then
        C_Timer.After(1.0 + restoreAttempt * 0.4, RunRestorePass)
    end

    -- If we had something remembered but edit still looks like a preset, keep trying.
    if editBucket and ActiveEditModeIsPreset() and restoreAttempt < MAX_RESTORE_ATTEMPTS and not retryEdit then
        C_Timer.After(1.5 + restoreAttempt * 0.3, RunRestorePass)
    end
end

function LPL.EditModePersist:ScheduleRestore()
    restorePending = false
    restoreAttempt = 0
    C_Timer.After(1.0, RunRestorePass)
end

function LPL.EditModePersist:Start()
    if self.started then
        return
    end
    self.started = true
    ResolveDB()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("EDIT_MODE_LAYOUTS_UPDATED") then
        frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if restorePending then
                LPL.EditModePersist:ScheduleRestore()
            end
            return
        end
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            C_Timer.After(0.35, function()
                -- Blizzard sometimes overwrites after us; force another pass.
                restoreAttempt = math.max(restoreAttempt, 1)
                RunRestorePass()
            end)
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            restorePending = true
            return
        end
        LPL.EditModePersist:ScheduleRestore()
    end)

    C_Timer.After(2.5, function()
        if restoreAttempt == 0 then
            LPL.EditModePersist:ScheduleRestore()
        end
    end)
end
