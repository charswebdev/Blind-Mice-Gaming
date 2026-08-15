local addon = Exploration

local function bind(name, script)
    local btn = CreateFrame("Button", name, UIParent)
    btn:SetSize(1, 1)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 0)
    btn:Hide()
    btn:SetScript("OnClick", script)
end

bind("ExplorationMarkDiscoveredButton", function()
    if addon.active then
        if addon.MarkCurrentDiscovered then
            addon:MarkCurrentDiscovered("keybind")
        else
            addon:AdvanceStep("keybind")
        end
    end
end)

bind("ExplorationGoNextButton", function()
    if addon.active then
        if addon.MarkCurrentDiscovered then
            addon:MarkCurrentDiscovered("keybind")
        elseif addon.waypoint.index then
            addon.segment.route[addon.waypoint.index].discovered = true
            if addon.ArmProximityRearmFromPlayer then
                addon:ArmProximityRearmFromPlayer()
            end
            addon:DetermineNextWaypoint()
            if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
        end
    end
end)

bind("ExplorationGoPreviousButton", function()
    addon:PreviousStep()
end)

bind("ExplorationNextZoneButton", function()
    if addon.active then
        addon:JumpToNextSegment()
        if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
    end
end)

bind("ExplorationPrevZoneButton", function()
    if addon.active then
        addon:JumpToPreviousSegment()
        if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
    end
end)

bind("ExplorationAbandonButton", function()
    if addon.active then
        addon:ClearActive()
        if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
    end
end)

---------------------------------------------------------------------------
-- Secure action keybind (Use Charm / Exit Bench / Warband Bank / Teleport Home).
-- One CLICK binding — SyncActionKeybindButtons keeps its macro/teleport current.
---------------------------------------------------------------------------

local actionKeybindButton
local pendingActionSync = nil
local actionSyncFrame = nil

do
    local btn = CreateFrame("Button", "ExplorationActionButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(1, 1)
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 0)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:Hide()
    actionKeybindButton = btn
end

local function clearActionKeybindButton(btn)
    if not btn or (InCombatLockdown and InCombatLockdown()) then return end
    if addon.ClearHousingTeleportButton then
        addon:ClearHousingTeleportButton(btn)
    end
    btn:SetScript("PreClick", nil)
    btn:SetAttribute("type", nil)
    btn:SetAttribute("macrotext", nil)
end

local function applyActionKeybindButton(btn, act)
    if not btn then return end
    if not act or not addon.active or not (act.macro or act.housingTeleport) then
        clearActionKeybindButton(btn)
        return
    end
    if act.housingTeleport then
        local ready = addon.ConfigureHousingTeleportButton and addon:ConfigureHousingTeleportButton(btn)
        if not ready then
            btn:SetScript("PreClick", function()
                if addon.ConfigureHousingTeleportButton then
                    addon:ConfigureHousingTeleportButton(btn)
                end
            end)
        else
            btn:SetScript("PreClick", nil)
        end
        return
    end
    if addon.ClearHousingTeleportButton then
        addon:ClearHousingTeleportButton(btn)
    end
    btn:SetScript("PreClick", nil)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", act.macro)
end

--- Prefer the first shown footer action; otherwise first collected waypoint action.
local function pickPrimaryAction(actions)
    if actions and actions.macro then
        return actions
    end
    if type(actions) == "table" then
        for i = 1, #actions do
            local act = actions[i]
            if act and (act.macro or act.housingTeleport) then
                return act
            end
        end
    end
    return nil
end

function addon:SyncActionKeybindButtons(actions)
    local act = pickPrimaryAction(actions)

    if InCombatLockdown and InCombatLockdown() then
        pendingActionSync = act -- may be nil (clear)
        if not actionSyncFrame then
            actionSyncFrame = CreateFrame("Frame")
            actionSyncFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            actionSyncFrame:SetScript("OnEvent", function()
                if not actionSyncFrame._hasPending then return end
                actionSyncFrame._hasPending = nil
                local queued = pendingActionSync
                pendingActionSync = nil
                applyActionKeybindButton(actionKeybindButton, queued)
            end)
        end
        actionSyncFrame._hasPending = true
        return
    end

    if actionSyncFrame then
        actionSyncFrame._hasPending = nil
    end
    pendingActionSync = nil
    applyActionKeybindButton(actionKeybindButton, act)
end
