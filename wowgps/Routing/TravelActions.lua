local _, ns = ...

local TravelActions = {}
ns.TravelActions = TravelActions

TravelActions.RED_X_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
TravelActions.PORTAL_ICON = 135744
TravelActions.HEARTH_ICON = 134414

local function getUtil()
    return nil
end

function TravelActions:InferIconFromText(text)
    if not text then
        return nil
    end
    local lower = text:lower()
    if lower:find("hearthstone") or lower:find("hearth") then
        return self.HEARTH_ICON
    end
    if lower:find("portal") then
        return self.PORTAL_ICON
    end
    return nil
end

function TravelActions:StepNeedsUseAtLocation(step)
    if not step then
        return false
    end

    if step.actionOptions then
        for _, option in ipairs(step.actionOptions) do
            if option.type == "item" or option.type == "spell" then
                return true
            end
        end
    end

    local text = (step.text or ""):lower()
    if text:find("hearthstone") or text:find("hearth") then
        return true
    end

    return false
end

function TravelActions:IsRemoteTravelStep(step)
    if not step then
        return false
    end
    if self:StepNeedsUseAtLocation(step) then
        return true
    end
    if step.checkDistance == false and step.actionOptions and #step.actionOptions > 0 then
        return true
    end
    return false
end

function TravelActions:IsInstantUseStep(step)
    if not step or step.completed then
        return false
    end
    if not step.hasTravelAction or not self:IsStepTravelReady(step) then
        return false
    end

    local action = self:GetBestAction(step)
    if not action or not action.available then
        return false
    end
    if action.type ~= "item" and action.type ~= "spell" then
        return false
    end

    if ns.RouteTracker and ns.RouteTracker.route and ns.RouteTracker:IsPlayerAtDestination() then
        return false
    end

    if step.checkDistance == false then
        if ns.SubStepResolver and ns.SubStepResolver.IsPlayerAtCompletion then
            if ns.SubStepResolver:IsPlayerAtCompletion(step) then
                return false
            end
        end
        return true
    end

    if ns.SubStepResolver and ns.SubStepResolver.IsPlayerAtCompletion then
        if ns.SubStepResolver:IsPlayerAtCompletion(step) then
            return false
        end
    end

    if ns.SubStepResolver and not ns.SubStepResolver:IsCompletionReachable(step) then
        return true
    end

    if ns.RouteTracker then
        local yards = ns.RouteTracker:DistanceToStep(step)
        if yards and yards <= 30 then
            return true
        end
    end

    return false
end

function TravelActions:HasArrivedAfterInstantUse(step)
    if not step or step.completed or not step.hasTravelAction then
        return false
    end
    if not ns.SubStepResolver or not ns.SubStepResolver.IsPlayerAtCompletion then
        return false
    end
    return ns.SubStepResolver:IsPlayerAtCompletion(step)
end

function TravelActions:IsArrowAvailableForStep(step)
    if not step then
        return false
    end
    if ns.SubStepResolver and ns.SubStepResolver.IsTomTomReachable then
        return ns.SubStepResolver:IsTomTomReachable(step)
    end
    return true
end

function TravelActions:GetActionIcon(actionType, id)
    if actionType == "item" and id and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(id)
    end
    if actionType == "spell" and id then
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        if info and info.iconID then
            return info.iconID
        end
    end
    return 134400
end

function TravelActions:ResolveItemName(itemId)
    if not itemId then
        return nil
    end

    local util = getUtil()
    if util and util.GetItemNameSafe then
        local name = util.GetItemNameSafe(itemId)
        if name and name ~= "" and not name:match("^Item_%d+$") and not name:match("^Item %d+$") then
            return name
        end
    end

    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemId)
        if name and name ~= "" then
            return name
        end
    end

    local name = GetItemInfo(itemId)
    if name and name ~= "" then
        return name
    end

    if C_Item and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(itemId)
        if name and name ~= "" then
            return name
        end
    end

    if itemId == 6948 then
        return "Hearthstone"
    end

    return nil
end

function TravelActions:GetActionName(actionType, id)
    if actionType == "item" and id then
        return self:ResolveItemName(id) or ("Item " .. tostring(id))
    end
    if actionType == "spell" and id then
        local util = getUtil()
        if util and util.GetSpellNameSafe then
            local name = util.GetSpellNameSafe(id)
            if name and name ~= "" and not name:match("^Spell_%d+$") then
                return name
            end
        end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        return (info and info.name) or ("Spell " .. tostring(id))
    end
    if actionType == "housing" then
        return "Housing"
    end
    if actionType == "housing_return" then
        return "Return from Housing"
    end
    return "Travel action"
end

function TravelActions:HumanizeLocaText(text)
    if not text or text == "" then
        return text
    end

    text = text:gsub("Item_(%d+)", function(idStr)
        return self:ResolveItemName(tonumber(idStr)) or ("Item_" .. idStr)
    end)

    text = text:gsub("Spell_(%d+)", function(idStr)
        local name = self:GetActionName("spell", tonumber(idStr))
        if name and not name:match("^Spell %d+$") then
            return name
        end
        return "Spell_" .. idStr
    end)

    return text
end

function TravelActions:GetStepDisplayText(step)
    if not step then
        return ""
    end
    return self:HumanizeLocaText(step.text or "")
end

function TravelActions:IsItemOwned(itemId)
    if not itemId then
        return false
    end
    if PlayerHasToy and PlayerHasToy(itemId) then
        return true
    end
    return C_Item.GetItemCount(itemId, false, true) > 0
end

function TravelActions:CanUseAction(actionType, id)
    local util = getUtil()
    if actionType == "item" and id then
        if util and util.CanUseItem then
            return util.CanUseItem(id)
        end
        return self:IsItemOwned(id)
    end
    if actionType == "spell" and id then
        if util and util.CanUseSpell then
            return util.CanUseSpell(id)
        end
        return C_SpellBook and C_SpellBook.IsSpellInSpellBook(id)
    end
    return true
end

function TravelActions:EvaluateOption(option)
    if not option or not option.type then
        return nil
    end

    local id = option.data
    local owned = true
    if option.type == "item" and id then
        owned = self:IsItemOwned(id)
    end

    return {
        type = option.type,
        id = id,
        name = self:GetActionName(option.type, id),
        icon = self:GetActionIcon(option.type, id),
        owned = owned,
        available = self:CanUseAction(option.type, id),
        isToy = option.type == "item" and id and PlayerHasToy and PlayerHasToy(id) or false,
    }
end

function TravelActions:EvaluateStep(step)
    if not step then
        return nil
    end

    step.travelActions = {}
    if not step.actionOptions then
        step.hasTravelAction = false
        step.travelReady = true
        if step.text then
            step.text = self:GetStepDisplayText(step)
        end
        return step.travelActions
    end

    for _, option in ipairs(step.actionOptions) do
        local action = self:EvaluateOption(option)
        if action then
            step.travelActions[#step.travelActions + 1] = action
        end
    end

    step.hasTravelAction = #step.travelActions > 0
    step.travelReady = self:IsStepTravelReady(step)
    if step.text then
        step.text = self:GetStepDisplayText(step)
    end
    return step.travelActions
end

function TravelActions:IsStepTravelReady(step)
    if not step or not step.hasTravelAction then
        return true
    end
    for _, action in ipairs(step.travelActions) do
        if action.available then
            return true
        end
    end
    return false
end

function TravelActions:GetBestAction(step)
    if not step or not step.travelActions then
        return nil
    end
    for _, action in ipairs(step.travelActions) do
        if action.available then
            return action
        end
    end
    return step.travelActions[1]
end

function TravelActions:GetUseMacro(action)
    if not action then
        return nil
    end
    if action.type == "item" and action.id then
        return "/use item:" .. tostring(action.id)
    end
    if action.type == "spell" and action.id then
        local name = action.name
        if name and name ~= "" and not name:match("^Spell %d+$") then
            return "/cast " .. name
        end
        return "/cast " .. tostring(action.id)
    end
    return nil
end

function TravelActions:GetUseLabel(action)
    if not action then
        return nil
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS", true)
    local name = action.name
    if name and name ~= "" and not name:match("^Item %d+$") and not name:match("^Spell %d+$") then
        local fmt = (L and L["USE_ITEM_NAMED"]) or "Use %s"
        return string.format(fmt, name)
    end
    return (L and L["USE_ITEM"]) or "Use"
end

-- Secure-button payloads for the current step (item / toy / spell), matching Exploration's /use macros.
function TravelActions:GetStepUseActions(step)
    if not step or step.completed then
        return {}
    end

    if not step.travelActions then
        self:EvaluateStep(step)
    end

    local list = {}
    for _, action in ipairs(step.travelActions or {}) do
        if (action.type == "item" or action.type == "spell") and action.id then
            local macro = self:GetUseMacro(action)
            if macro then
                list[#list + 1] = {
                    type = action.type,
                    id = action.id,
                    name = action.name,
                    icon = action.icon,
                    available = action.available,
                    isToy = action.isToy,
                    label = self:GetUseLabel(action),
                    macro = macro,
                }
            end
        end
        if #list >= 3 then
            break
        end
    end

    if #list == 0 then
        local text = (step.text or ""):lower()
        if text:find("hearthstone", 1, true) or text:find("hearth", 1, true) then
            local action = self:EvaluateOption({ type = "item", data = 6948 })
            if action then
                list[1] = {
                    type = "item",
                    id = 6948,
                    name = action.name,
                    icon = action.icon,
                    available = action.available,
                    isToy = action.isToy,
                    label = self:GetUseLabel(action),
                    macro = self:GetUseMacro(action),
                }
            end
        end
    end

    return list
end

function TravelActions:GetStepActionSummary(step)
    local action = self:GetBestAction(step)
    if not action then
        return nil
    end

    local status
    if action.available then
        status = "ready"
    elseif action.owned then
        status = "cooldown"
    else
        status = "missing"
    end

    return {
        action = action,
        status = status,
        label = action.name,
    }
end

function TravelActions:RefreshRoute(route)
    if not route then
        return
    end

    for _, step in ipairs(route.steps or {}) do
        self:EvaluateStep(step)
    end

    if route.subSteps then
        for _, subs in pairs(route.subSteps) do
            for _, sub in ipairs(subs) do
                self:EvaluateStep(sub)
            end
        end
    end
end

function TravelActions:GetStepVisual(step, route)
    if not step or step.completed then
        if step and step.completed and self:StepNeedsUseAtLocation(step) then
            local action = self:GetBestAction(step)
            local icon = (action and action.icon) or self:InferIconFromText(step.text) or 134400
            return {
                showActionIcon = true,
                icon = icon,
                showRedX = false,
                itemOk = true,
                arrowOk = true,
                action = action,
            }
        end
        return {
            showActionIcon = false,
            showRedX = false,
            itemOk = true,
            arrowOk = true,
        }
    end

    if self:IsInstantUseStep(step) then
        local action = self:GetBestAction(step)
        local icon = (action and action.icon) or self:InferIconFromText(step.text) or 134400
        return {
            showActionIcon = true,
            icon = icon,
            showRedX = false,
            itemOk = true,
            arrowOk = true,
            useNow = true,
            action = action,
        }
    end

    if not self:StepNeedsUseAtLocation(step) then
        return {
            showActionIcon = false,
            showRedX = not self:IsArrowAvailableForStep(step),
            itemOk = true,
            arrowOk = self:IsArrowAvailableForStep(step),
        }
    end

    local action = self:GetBestAction(step)
    local icon = (action and action.icon) or self:InferIconFromText(step.text) or 134400
    local itemOk = self:IsStepTravelReady(step)
    local arrowOk = self:IsArrowAvailableForStep(step)

    return {
        showActionIcon = true,
        icon = icon,
        showRedX = not itemOk,
        itemOk = itemOk,
        arrowOk = arrowOk,
        action = action,
    }
end

function TravelActions:FormatStepSuffix(step, route)
    local visual = self:GetStepVisual(step, route)
    local redX = string.format("|T%s:14:14|t", self.RED_X_TEXTURE)
    if visual.showActionIcon then
        local iconStr = string.format("|T%d:18:18|t", visual.icon)
        if visual.showRedX then
            return string.format(" %s%s", iconStr, redX)
        end
        return " " .. iconStr
    end
    if visual.showRedX then
        return " " .. redX
    end
    return ""
end

function TravelActions:GetStepTooltipLines(step, route)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS", true)
    local lines = {}
    local visual = self:GetStepVisual(step, route)

    if not self:StepNeedsUseAtLocation(step) then
        if visual.showRedX then
            lines[#lines + 1] = L["ARROW_UNAVAILABLE"]
        end
        return lines
    end

    local summary = self:GetStepActionSummary(step)
    if summary then
        if summary.status == "ready" then
            lines[#lines + 1] = string.format("%s: %s", summary.label, L["TRAVEL_READY"])
        elseif summary.status == "cooldown" then
            lines[#lines + 1] = string.format("%s: %s", summary.label, L["TRAVEL_COOLDOWN"])
        else
            lines[#lines + 1] = string.format("%s: %s", summary.label, L["TRAVEL_MISSING"])
        end
    elseif step.text then
        lines[#lines + 1] = step.text
    end

    if not visual.arrowOk and not visual.useNow then
        lines[#lines + 1] = L["ARROW_UNAVAILABLE"]
    end

    return lines
end
