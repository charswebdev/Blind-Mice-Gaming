local addonName, LPL = ...

LPL.AddonSetActivate = {}

local RELOAD_DIALOG = "LPL_ADDON_SET_RELOAD_UI"
local REPLACE_DIALOG = "LPL_ADDON_SET_CONFIRM_REPLACE"

local MODE_REPLACE = "replace"
local MODE_ENABLE = "enable"
local MODE_DISABLE = "disable"

function LPL.AddonSetActivate:ResolveApplyScope(sets)
    if type(sets) ~= "table" then
        return LPL.AddonSetStore.SCOPE_ACCOUNT
    end
    for _, set in ipairs(sets) do
        if set and set.scope == LPL.AddonSetStore.SCOPE_CHARACTER then
            return LPL.AddonSetStore.SCOPE_CHARACTER
        end
    end
    return LPL.AddonSetStore.SCOPE_ACCOUNT
end

function LPL.AddonSetActivate:BuildUnionAddonMap(sets)
    local map = {}
    if type(sets) ~= "table" then
        return map
    end
    for _, set in ipairs(sets) do
        if set and type(set.addons) == "table" then
            for _, name in ipairs(set.addons) do
                if type(name) == "string" and name ~= "" then
                    map[name] = true
                end
            end
        end
    end
    return map
end

function LPL.AddonSetActivate:GetSetsByIDs(setIDs)
    return LPL.AddonSetStore:CollectExpandedSets(setIDs)
end

local function EnableAddon(name, character)
    if C_AddOns and C_AddOns.EnableAddOn then
        if character then
            pcall(C_AddOns.EnableAddOn, name, character)
        else
            pcall(C_AddOns.EnableAddOn, name)
        end
        return
    end
    if EnableAddOn then
        if character then
            pcall(EnableAddOn, name, character)
        else
            pcall(EnableAddOn, name)
        end
    end
end

local function DisableAddon(name, character)
    if C_AddOns and C_AddOns.DisableAddOn then
        if character then
            pcall(C_AddOns.DisableAddOn, name, character)
        else
            pcall(C_AddOns.DisableAddOn, name)
        end
        return
    end
    if DisableAddOn then
        if character then
            pcall(DisableAddOn, name, character)
        else
            pcall(DisableAddOn, name)
        end
    end
end

local function PersistAddOnChanges()
    if C_AddOns and C_AddOns.SaveAddOns then
        pcall(C_AddOns.SaveAddOns)
    elseif SaveAddOns then
        pcall(SaveAddOns)
    end
end

function LPL.AddonSetActivate:CanDisableAddon(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if LPL.AddonSetStore:IsProtected(name) then
        return false
    end
    local ok = LPL.AddonSetStore:IsManagedAddon(name)
    return ok == true
end

function LPL.AddonSetActivate:Apply(mode, setIDs)
    mode = mode or MODE_REPLACE
    local sets = self:GetSetsByIDs(setIDs)
    if #sets == 0 then
        return false, "Select at least one addon set."
    end

    local union = self:BuildUnionAddonMap(sets)
    local unionCount = 0
    for _ in pairs(union) do
        unionCount = unionCount + 1
    end

    local scope = self:ResolveApplyScope(sets)
    local character = LPL.AddonSetStore:GetEnableCharacterArg(scope)
    local enabled = 0
    local disabled = 0
    local skippedProtected = 0

    if mode == MODE_REPLACE then
        local installed = LPL.AddonSetStore:GetInstalledAddons()
        local seen = {}
        for _, info in ipairs(installed) do
            local name = info.name
            seen[name] = true
            if union[name] then
                EnableAddon(name, character)
                enabled = enabled + 1
            elseif self:CanDisableAddon(name) then
                DisableAddon(name, character)
                disabled = disabled + 1
            elseif LPL.AddonSetStore:IsProtected(name) then
                skippedProtected = skippedProtected + 1
            end
        end
        for name in pairs(union) do
            if not seen[name] and C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(name) then
                EnableAddon(name, character)
                enabled = enabled + 1
            end
        end
    elseif mode == MODE_ENABLE then
        for name in pairs(union) do
            if C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(name) then
                EnableAddon(name, character)
                enabled = enabled + 1
            end
        end
    elseif mode == MODE_DISABLE then
        for name in pairs(union) do
            if self:CanDisableAddon(name) then
                DisableAddon(name, character)
                disabled = disabled + 1
            elseif LPL.AddonSetStore:IsProtected(name) then
                skippedProtected = skippedProtected + 1
            end
        end
    else
        return false, "Unknown apply mode."
    end

    PersistAddOnChanges()

    local scopeLabel = scope == LPL.AddonSetStore.SCOPE_CHARACTER and "Character" or "Account"
    local setLabel
    if #sets == 1 then
        setLabel = string.format("\"%s\"", sets[1].name or "Addon Set")
    else
        setLabel = string.format("%d sets", #sets)
    end

    local summary
    if mode == MODE_REPLACE then
        summary = string.format(
            "Activated addons from %s (%s): enabled %d, disabled %d.",
            setLabel,
            scopeLabel,
            enabled,
            disabled
        )
    elseif mode == MODE_ENABLE then
        summary = string.format("Enabled %d addon%s from %s (%s).", enabled, enabled == 1 and "" or "s", setLabel, scopeLabel)
    else
        summary = string.format("Disabled %d addon%s from %s (%s).", disabled, disabled == 1 and "" or "s", setLabel, scopeLabel)
    end
    if skippedProtected > 0 then
        summary = summary .. string.format(" Kept %d protected.", skippedProtected)
    end
    if unionCount == 0 and mode ~= MODE_REPLACE then
        summary = summary .. " (set list was empty)"
    end

    print("|cff33cc33LPL:|r " .. summary)
    return true, summary, {
        mode = mode,
        setCount = #sets,
        enabled = enabled,
        disabled = disabled,
        skippedProtected = skippedProtected,
        scope = scope,
    }
end

function LPL.AddonSetActivate:PromptReload(message)
    if not StaticPopupDialogs[RELOAD_DIALOG] then
        StaticPopupDialogs[RELOAD_DIALOG] = {
            text = "%s",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(
        RELOAD_DIALOG,
        message or "Addon changes are pending. Reload the UI to apply them?"
    )
end

function LPL.AddonSetActivate:ApplyAndPromptReload(mode, setIDs)
    local ok, summary = self:Apply(mode, setIDs)
    if not ok then
        print("|cffff6060LPL:|r " .. (summary or "Could not apply addon set."))
        return false
    end

    local modeLabel = "Apply"
    if mode == MODE_REPLACE then
        modeLabel = "Activate"
    elseif mode == MODE_ENABLE then
        modeLabel = "Enable"
    elseif mode == MODE_DISABLE then
        modeLabel = "Disable"
    end

    self:PromptReload(string.format(
        "%s finished.\n\n%s\n\nReload the UI now to apply addon changes?",
        modeLabel,
        summary or ""
    ))
    return true
end

function LPL.AddonSetActivate:CountMissingInSets(sets)
    local union = self:BuildUnionAddonMap(sets)
    local names = {}
    for name in pairs(union) do
        names[#names + 1] = name
    end
    return LPL.AddonSetStore:CountMissingAddons(names)
end

function LPL.AddonSetActivate:ConfirmReplace(setIDs, onConfirm)
    local primary = {}
    if type(setIDs) == "table" then
        for _, setID in ipairs(setIDs) do
            local set = LPL.AddonSetStore:Get(setID)
            if set then
                primary[#primary + 1] = set
            end
        end
    end
    if #primary == 0 then
        print("|cffff6060LPL:|r Select at least one addon set.")
        return
    end

    local expanded = LPL.AddonSetStore:CollectExpandedSets(setIDs)
    local missing = self:CountMissingInSets(expanded)

    local label
    if #primary == 1 then
        label = string.format("\"%s\"", primary[1].name or "this set")
    else
        label = string.format("%d selected sets", #primary)
    end
    if missing > 0 then
        label = label .. string.format(
            "\n\nWarning: %d addon%s in the set%s %s not installed on this client.",
            missing,
            missing == 1 and "" or "s",
            #expanded == 1 and "" or "s",
            missing == 1 and "is" or "are"
        )
    end

    if not StaticPopupDialogs[REPLACE_DIALOG] then
        StaticPopupDialogs[REPLACE_DIALOG] = {
            text = "Activate %s?\n\nOther addons will be disabled (except protected / locked). A reload will be required.",
            button1 = "Activate",
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.onConfirm then
                    data.onConfirm()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(REPLACE_DIALOG, label, nil, {
        setIDs = setIDs,
        onConfirm = onConfirm,
    })
end

LPL.AddonSetActivate.MODE_REPLACE = MODE_REPLACE
LPL.AddonSetActivate.MODE_ENABLE = MODE_ENABLE
LPL.AddonSetActivate.MODE_DISABLE = MODE_DISABLE
