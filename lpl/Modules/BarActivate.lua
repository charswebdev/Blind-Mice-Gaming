local addonName, LPL = ...

LPL.BarActivate = {}

local ICON = "Interface\\AddOns\\lpl\\icons\\activate_64"

local LABELS = {
    loadouts = "Loadouts",
    talents = "Talents",
    pvptalents = "PvP Talents",
    actionbars = "Action Bars",
    keybinds = "Keybinds",
    equipment = "Equipment",
    editmode = "Edit Mode",
    cooldownmanager = "Cooldown Manager",
    conditions = "Conditions",
    addonsets = "Addon Sets",
}

local DELETE_HOOKS = {
    { store = "LoadoutStore", key = "loadouts" },
    { store = "BuildStore", key = "talents" },
    { store = "PvpTalentStore", key = "pvptalents" },
    { store = "ActionBarStore", key = "actionbars" },
    { store = "KeybindStore", key = "keybinds" },
    { store = "EquipmentStore", key = "equipment" },
    { store = "EditModeStore", key = "editmode" },
    { store = "CooldownManagerStore", key = "cooldownmanager" },
    { store = "ConditionStore", key = "conditions" },
    { store = "AddonSetStore", key = "addonsets" },
}

function LPL.BarActivate:Supports(listKey)
    return LABELS[listKey] ~= nil
end

function LPL.BarActivate:Label(listKey)
    return LABELS[listKey] or "Build"
end

local function MacroBody(listKey, id)
    return "/lpl act " .. tostring(listKey) .. " " .. tostring(id)
end

local function FitMacroName(name)
    name = tostring(name or "")
    name = name:gsub("[%c|]", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%s+", " ")
    if name == "" then
        name = "LPL"
    end
    if #name > 16 then
        name = name:sub(1, 16)
    end
    return name
end

local function MacroCount()
    local account, character = 0, 0
    if GetNumMacros then
        account, character = GetNumMacros()
    end
    return tonumber(account) or 0, tonumber(character) or 0
end

local function FindMacroByBody(body)
    if not GetMacroBody then
        return nil
    end
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    local maxCharacter = MAX_CHARACTER_MACROS or 18
    for index = 1, maxAccount + maxCharacter do
        local ok, existing = pcall(GetMacroBody, index)
        if ok and type(existing) == "string" then
            local compareOk, same = pcall(function()
                return existing:gsub("%s+$", "") == body
            end)
            if compareOk and same then
                return index
            end
        end
    end
    return nil
end

local function NameTakenByOther(name, body)
    if not GetMacroIndexByName or not GetMacroBody then
        return false
    end
    local ok, index = pcall(GetMacroIndexByName, name)
    if not ok or type(index) ~= "number" or index <= 0 then
        return false
    end
    local bodyOk, existing = pcall(GetMacroBody, index)
    if bodyOk and existing == body then
        return false
    end
    return true
end

local function UniqueMacroName(preferred, body)
    local base = FitMacroName(preferred)
    if not NameTakenByOther(base, body) then
        return base
    end
    for number = 2, 9 do
        local suffix = " " .. number
        local trimmed = base
        if #trimmed + #suffix > 16 then
            trimmed = trimmed:sub(1, 16 - #suffix)
        end
        local candidate = trimmed .. suffix
        if not NameTakenByOther(candidate, body) then
            return candidate
        end
    end
    return base
end

local QUESTION_MARK_ICON = 134400

local function LoadMacroUI()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_MacroUI")
    end
end

local ICON_FILE_PATHS = {
    "Interface\\Icons\\lpl_activate.blp",
    "Interface\\Icons\\lpl_activate",
    "Interface\\AddOns\\lpl\\icons\\activate_64.blp",
    "Interface\\AddOns\\lpl\\icons\\activate_64.tga",
    "Interface\\AddOns\\lpl\\icons\\activate_64",
}

local function UsableFileID(value)
    return type(value) == "number" and value > 0 and value ~= QUESTION_MARK_ICON
end

local function ResolveIconFileID()
    if UsableFileID(LPL.BarActivate.iconFileID) then
        return LPL.BarActivate.iconFileID
    end
    if GetFileIDFromPath then
        for _, path in ipairs(ICON_FILE_PATHS) do
            local ok, id = pcall(GetFileIDFromPath, path)
            if ok and UsableFileID(id) then
                LPL.BarActivate.iconFileID = id
                return id
            end
        end
    end
    if not LPL.barActivateProbe then
        local frame = CreateFrame("Frame")
        frame:Hide()
        LPL.barActivateProbe = frame:CreateTexture(nil, "BACKGROUND")
    end
    local probe = LPL.barActivateProbe
    for _, path in ipairs(ICON_FILE_PATHS) do
        probe:SetTexture(path)
        if probe.GetTextureFileID then
            local ok, id = pcall(function()
                return probe:GetTextureFileID()
            end)
            if ok and UsableFileID(id) then
                LPL.BarActivate.iconFileID = id
                return id
            end
        end
    end
    return nil
end

local function MacroStillValid(index)
    if not GetMacroInfo then
        return true
    end
    local ok, name, _, body = pcall(GetMacroInfo, index)
    if not ok or type(name) ~= "string" or name == "" then
        return false
    end
    if type(body) == "string" and not body:find("/lpl act ", 1, true) then
        return false
    end
    return true
end

local function StoredIcon(index)
    if not GetMacroInfo then
        return nil
    end
    local ok, _, icon = pcall(GetMacroInfo, index)
    if ok then
        return icon
    end
    return nil
end

local function RestoreQuestionMark(index, name, body)
    if EditMacro then
        pcall(EditMacro, index, name, QUESTION_MARK_ICON, body)
    end
end

local function TryStoreIcon(index, name, body, icon)
    if not EditMacro or icon == nil then
        return false
    end
    local ok = pcall(EditMacro, index, name, icon, body)
    if not ok or not MacroStillValid(index) then
        RestoreQuestionMark(index, name, body)
        return false
    end
    local saved = StoredIcon(index)
    if saved == QUESTION_MARK_ICON or saved == nil then
        return false
    end
    if type(saved) == "number" then
        LPL.BarActivate.iconFileID = saved
    end
    return true
end

local function ApplyStoredIcon(index, name, body)
    if not index or not EditMacro then
        return
    end
    local current = StoredIcon(index)
    if UsableFileID(current) then
        pcall(EditMacro, index, name, current, body)
        if MacroStillValid(index) then
            LPL.BarActivate.iconFileID = current
            return
        end
        RestoreQuestionMark(index, name, body)
    end
    local fileID = ResolveIconFileID()
    if fileID and TryStoreIcon(index, name, body, fileID) then
        return
    end
    for _, path in ipairs(ICON_FILE_PATHS) do
        if TryStoreIcon(index, name, body, path) then
            return
        end
    end
    RestoreQuestionMark(index, name, body)
end

local function CreateBarMacro(name, body)
    if not CreateMacro then
        return nil
    end
    LoadMacroUI()
    local accountCount, characterCount = MacroCount()
    local perCharacter = nil
    if accountCount >= (MAX_ACCOUNT_MACROS or 120) then
        if characterCount >= (MAX_CHARACTER_MACROS or 18) then
            print("|cffff6060LPL:|r Your macro book is full. Delete a macro, then drag the build again.")
            return nil
        end
        perCharacter = true
    end

    -- The card picture is drawn on the bar after the drop. A custom file here
    -- makes CreateMacro fail and the drag never starts.
    local ok, index = pcall(CreateMacro, name, QUESTION_MARK_ICON, body, perCharacter)
    if ok and type(index) == "number" and index > 0 then
        return index
    end

    print("|cffff6060LPL:|r Could not create the action bar macro.")
    return nil
end

function LPL.BarActivate:EnsureMacro(listKey, id, buildName)
    local body = MacroBody(listKey, id)
    local name = UniqueMacroName(buildName, body)
    local index = FindMacroByBody(body)
    if not index and GetMacroIndexByName then
        local preferred = FitMacroName(buildName)
        local ok, byName = pcall(GetMacroIndexByName, preferred)
        if ok and type(byName) == "number" and byName > 0 then
            index = byName
            name = preferred
        end
    end
    if not index then
        index = CreateBarMacro(name, body)
    end
    if index then
        ApplyStoredIcon(index, name, body)
    end
    return index
end

function LPL.BarActivate:PlaceOnCursor(index)
    if InCombatLockdown and InCombatLockdown() then
        print("|cffffcc00LPL:|r Leave combat before dragging a build onto your action bar.")
        return false
    end
    LoadMacroUI()
    if not PickupMacro then
        print("|cffff6060LPL:|r Action bar macros are not available.")
        return false
    end
    local name
    if GetMacroInfo and type(index) == "number" and index > 0 then
        name = GetMacroInfo(index)
    end
    if type(name) == "string" and name ~= "" then
        -- One call only. A second PickupMacro puts the macro back down.
        PickupMacro(name)
        return true
    end
    if type(index) == "number" and index > 0 then
        PickupMacro(index)
        return true
    end
    print("|cffff6060LPL:|r That build's macro is missing. Drag the icon again.")
    return false
end

function LPL.BarActivate:BeginDrag(listKey, id, buildName)
    if not self:Supports(listKey) or id == nil or tostring(id) == "" then
        return false
    end
    local index = self:EnsureMacro(listKey, id, buildName)
    if not index then
        return false
    end
    return self:PlaceOnCursor(index)
end

function LPL.BarActivate:RemoveMacro(listKey, id)
    if not self:Supports(listKey) or id == nil or not DeleteMacro then
        return
    end
    local index = FindMacroByBody(MacroBody(listKey, id))
    if not index then
        return
    end
    local ok = pcall(DeleteMacro, index)
    if not ok then
        print("|cffffcc00LPL:|r Leave combat so the action bar macro for this build can be removed.")
    end
end

local function ApplyCondition(id)
    if not LPL.ConditionStore then
        print("|cffff6060LPL:|r Conditions are not available.")
        return false
    end
    local rule = LPL.ConditionStore:Get(id)
    if not rule then
        print("|cffff6060LPL:|r Condition not found.")
        return false
    end
    local targets = LPL.ConditionStore:GetEligibleTargetsForPlayer(rule)
    if #targets == 0 then
        print("|cffff6060LPL:|r This condition has no build that can be applied on this character.")
        return false
    end
    local target = targets[1]
    local ok = LPL.ConditionStore:ApplyLink(target.type, target.id)
    if ok and #targets > 1 then
        print("|cff33cc33LPL:|r Used the first linked build, \"" .. (target.name or "build") .. "\".")
    end
    return ok
end

function LPL.BarActivate:Apply(listKey, id)
    if LPL.Initialize then
        pcall(LPL.Initialize)
    end
    id = tostring(id or "")
    if not self:Supports(listKey) or id == "" then
        print("|cffff6060LPL:|r That action bar button is not a Light Paws build.")
        return false
    end

    if listKey == "loadouts" then
        return LPL.LoadoutActivate and LPL.LoadoutActivate:ApplySet(id)
    elseif listKey == "talents" then
        return LPL.TalentActivate and LPL.TalentActivate:ApplyBuild(id)
    elseif listKey == "pvptalents" then
        return LPL.PvpTalentActivate and LPL.PvpTalentActivate:ApplySet(id)
    elseif listKey == "actionbars" then
        return LPL.ActionBarActivate and LPL.ActionBarActivate:ApplySet(id)
    elseif listKey == "keybinds" then
        return LPL.KeybindActivate and LPL.KeybindActivate:ApplySet(id)
    elseif listKey == "equipment" then
        return LPL.EquipmentActivate and LPL.EquipmentActivate:ApplySet(id)
    elseif listKey == "editmode" then
        return LPL.EditModeActivate and LPL.EditModeActivate:ApplySet(id)
    elseif listKey == "cooldownmanager" then
        return LPL.CooldownManagerActivate and LPL.CooldownManagerActivate:ApplySet(id)
    elseif listKey == "conditions" then
        return ApplyCondition(id)
    elseif listKey == "addonsets" then
        if not LPL.AddonSetActivate then
            print("|cffff6060LPL:|r Addon sets are not available.")
            return false
        end
        LPL.AddonSetActivate:ConfirmReplace({ id }, function()
            LPL.AddonSetActivate:ApplyAndPromptReload(LPL.AddonSetActivate.MODE_REPLACE, { id })
        end)
        return true
    end

    print("|cffff6060LPL:|r That action bar button is not a Light Paws build.")
    return false
end

local function IsBarMacroBody(body)
    return type(body) == "string" and body:find("/lpl act ", 1, true) ~= nil
end

local function ApplyActionButtonIcon(button)
    if not button or not button.action then
        return
    end
    local function paint()
    local icon = button.icon or button.Icon
    if not icon or not icon.SetTexture then
        if button.lplBarIcon then
            button.lplBarIcon:Hide()
        end
        return
    end
    local actionType, macroIndex = GetActionInfo(button.action)
    if actionType ~= "macro" then
        if button.lplBarIcon then
            button.lplBarIcon:Hide()
        end
        return
    end
    local body
    if GetMacroBody then
        local ok, text = pcall(GetMacroBody, macroIndex)
        if ok then
            body = text
        end
    end
    if not IsBarMacroBody(body) and GetMacroInfo then
        local ok, _, _, text = pcall(GetMacroInfo, macroIndex)
        if ok then
            body = text
        end
    end
    if not IsBarMacroBody(body) then
        if button.lplBarIcon then
            button.lplBarIcon:Hide()
        end
        return
    end
    local overlay = button.lplBarIcon
    if not overlay then
        overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
        overlay:SetTexture(ICON)
        if overlay.SetTexCoord then
            overlay:SetTexCoord(0, 1, 0, 1)
        end
        button.lplBarIcon = overlay
    end
    overlay:ClearAllPoints()
    overlay:SetAllPoints(icon)
    overlay:Show()
    end
    pcall(paint)
end

local function RefreshActionButtons()
    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
    }
    for _, prefix in ipairs(prefixes) do
        for slot = 1, 12 do
            local button = _G[prefix .. slot]
            if button then
                ApplyActionButtonIcon(button)
            end
        end
    end
end

local hookedUpdates = {}

local function HookActionButtonUpdates()
    local function hookMixin(mixin)
        if type(mixin) ~= "table" or type(mixin.Update) ~= "function" then
            return
        end
        if hookedUpdates[mixin.Update] then
            return
        end
        hooksecurefunc(mixin, "Update", ApplyActionButtonIcon)
        hookedUpdates[mixin.Update] = true
    end

    hookMixin(ActionBarActionButtonMixin)
    hookMixin(ActionButtonMixin)
    if type(ActionButton_Update) == "function" and not hookedUpdates[ActionButton_Update] then
        hooksecurefunc("ActionButton_Update", ApplyActionButtonIcon)
        hookedUpdates[ActionButton_Update] = true
    end
    RefreshActionButtons()
end

HookActionButtonUpdates()

local iconWatch = CreateFrame("Frame")
iconWatch:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
iconWatch:RegisterEvent("UPDATE_MACROS")
iconWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
iconWatch:SetScript("OnEvent", function()
    HookActionButtonUpdates()
end)

for _, hook in ipairs(DELETE_HOOKS) do
    local store = LPL[hook.store]
    if store and type(store.Delete) == "function" and not store.barActivateDeleteWrapped then
        local original = store.Delete
        local listKey = hook.key
        store.Delete = function(self, setID, ...)
            local packed = { original(self, setID, ...) }
            if packed[1] ~= false and setID ~= nil then
                LPL.BarActivate:RemoveMacro(listKey, setID)
            end
            return unpack(packed)
        end
        store.barActivateDeleteWrapped = true
    end
end
