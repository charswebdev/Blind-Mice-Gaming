local addonName, LPL = ...

LPL.ConditionSetList = {}

function LPL.ConditionSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "conditions",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Condition Rules",
        hint = "Select a condition, then Edit | Link loadouts or individual builds | Filter by linked Limits.",
        emptyFilterText = "No conditions match your search or filters.",
        emptyButtonLabel = "New Condition",
        emptyButtonWidth = 150,
        getItems = function()
            return LPL.ConditionStore:GetAll()
        end,
        getID = function(rule)
            return rule.id
        end,
        getName = function(rule)
            local name = rule.name or "Condition"
            if rule.enabled == false then
                return name .. " (disabled)"
            end
            return name
        end,
        getFilters = function(rule)
            return LPL.ConditionStore:GetAggregatedFilters(rule)
        end,
        getClassKey = function()
            return nil
        end,
        getSpecKey = function()
            return nil
        end,
        getHeroKey = function()
            return nil
        end,
        isActive = function()
            return false
        end,
        getSubtitle = function(rule)
            return LPL.ConditionStore:GetSummaryLine(rule)
        end,
        getSubtitleColor = function()
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
