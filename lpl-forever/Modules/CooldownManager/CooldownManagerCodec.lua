local addonName, LPL = ...

LPL.CooldownManagerCodec = {}

function LPL.CooldownManagerCodec:NormalizeLayoutString(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:match("^%s*(.-)%s*$") or ""
    return text
end

function LPL.CooldownManagerCodec:SanitizeDraft(draft)
    if type(draft) ~= "table" then
        return draft
    end
    draft.layoutString = self:NormalizeLayoutString(draft.layoutString)
    return draft
end

function LPL.CooldownManagerCodec:IsAvailable()
    if not C_CooldownViewer then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_CooldownViewer")
        end
    end
    if not C_CooldownViewer then
        return false, "Cooldown Manager API is unavailable."
    end
    if C_CooldownViewer.IsCooldownViewerAvailable then
        local available, reason = C_CooldownViewer.IsCooldownViewerAvailable()
        if not available then
            return false, reason or "Cooldown Manager is not available right now."
        end
    end
    if not C_CooldownViewer.GetLayoutData then
        return false, "Could not read Cooldown Manager layout data."
    end
    return true
end

function LPL.CooldownManagerCodec:CanCaptureFromCharacter()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot update Cooldown Manager layouts in combat."
    end
    return self:IsAvailable()
end

function LPL.CooldownManagerCodec:CanApplyToCharacter()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot apply Cooldown Manager layouts in combat."
    end
    local ok, err = self:IsAvailable()
    if not ok then
        return false, err
    end
    if not C_CooldownViewer.SetLayoutData then
        return false, "Could not apply Cooldown Manager layout data."
    end
    return true
end

function LPL.CooldownManagerCodec:GetCurrentLayoutString()
    local ok = self:IsAvailable()
    if not ok or not C_CooldownViewer.GetLayoutData then
        return ""
    end
    return self:NormalizeLayoutString(C_CooldownViewer.GetLayoutData())
end

function LPL.CooldownManagerCodec:CaptureFromCharacter(draft)
    draft = draft or {}
    local ok, err = self:CanCaptureFromCharacter()
    if not ok then
        return nil, err
    end

    local layoutString = self:GetCurrentLayoutString()
    if layoutString == "" then
        return nil, "Cooldown Manager returned an empty layout string."
    end

    draft.layoutString = layoutString
    return self:SanitizeDraft(draft)
end

function LPL.CooldownManagerCodec:ApplyLayoutString(layoutString)
    layoutString = self:NormalizeLayoutString(layoutString)
    if layoutString == "" then
        return false, "This set has no Cooldown Manager layout string."
    end

    local ok, err = self:CanApplyToCharacter()
    if not ok then
        return false, err
    end

    -- Always persist the blob first. This is what survives /reload and logout.
    -- (Same class of bug as Edit Mode: session apply without a real datastore write.)
    local wrote = pcall(C_CooldownViewer.SetLayoutData, layoutString)
    if not wrote then
        return false, "Failed to apply Cooldown Manager layout."
    end

    -- Then sync CooldownViewerSettings so in-memory layouts match the datastore.
    -- Without this, opening CDM settings can save the old memory over our blob.
    local settings = CooldownViewerSettings
    local layoutManager = settings and settings.GetLayoutManager and settings:GetLayoutManager()
    local serializer = settings and settings.GetSerializer and settings:GetSerializer()
    local dataProvider = settings and settings.GetDataProvider and settings:GetDataProvider()

    local settingsReady = layoutManager
        and serializer
        and dataProvider
        and serializer.SetSerializedData
        and serializer.ReadData
        and layoutManager.InitMemberVariables
        and layoutManager.ClearActiveLayout
        and dataProvider.SwitchToBestLayoutForSpec
        and layoutManager.IsLoaded
        and layoutManager:IsLoaded()

    if not settingsReady then
        return true
    end

    pcall(function()
        -- Clear serializer cache and re-assert the datastore write.
        serializer:SetSerializedData(layoutString)
        layoutManager:InitMemberVariables()
        layoutManager:ClearActiveLayout()
        serializer:ReadData()
        dataProvider:SwitchToBestLayoutForSpec()

        if dataProvider.MarkDirty then
            dataProvider:MarkDirty()
        end

        -- SwitchToBestLayoutForSpec marks pending changes; flush remapped active
        -- layout IDs / order back to the datastore instead of discarding them.
        if serializer.WriteData then
            serializer:WriteData()
        elseif layoutManager.SetHasPendingChanges and layoutManager.SaveLayouts then
            layoutManager:SetHasPendingChanges(true)
            layoutManager:SaveLayouts()
        end

        if layoutManager.SetHasPendingChanges then
            layoutManager:SetHasPendingChanges(false)
        end
        if layoutManager.NotifyListeners then
            layoutManager:NotifyListeners()
        end
    end)

    return true
end

function LPL.CooldownManagerCodec:LooksLikeLayoutString(text)
    text = self:NormalizeLayoutString(text)
    if text == "" then
        return false
    end
    -- Blizzard CDM strings commonly start with a version digit and pipe.
    if text:match("^%d+|") then
        return true
    end
    -- Accept any non-empty pasted string; activate will validate.
    return #text >= 8
end
