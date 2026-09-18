local addonName, LPL = ...

LPL.ActionBarSetList = {}

function LPL.ActionBarSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "actionbars",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Action Bar Sets",
        hint = "Universal by default | Use Limits to group by class, spec, or character | Green dot = on your bars.",
        emptyFilterText = "No action bar sets match your search or filters.",
        emptyButtonLabel = "New Action Bar Set",
        emptyButtonWidth = 180,
        getItems = function()
            return LPL.ActionBarStore:GetAll()
        end,
        getID = function(set)
            return set.id
        end,
        getName = function(set)
            return set.name
        end,
        getFilters = function(set)
            return set.filters
        end,
        getClassKey = function(set)
            return LPL.ActionBarStore:GetEffectiveClassID(set)
        end,
        getSpecKey = function(set)
            return LPL.ActionBarStore:GetEffectiveSpecID(set)
        end,
        getHeroKey = function(set)
            return LPL.ActionBarStore:GetEffectiveHeroID(set)
        end,
        isActive = function(set)
            return LPL.ActionBarActive:IsActive(set)
        end,
        getSubtitle = function(set)
            return LPL.SetRestrictions:FormatListSubtitle(LPL.ActionBarStore:GetSummaryLine(set), set.restrictions)
        end,
        getSubtitleColor = function(set)
            local classID = LPL.ActionBarStore:GetEffectiveClassID(set)
            if classID and LPL.BuildStore then
                return LPL.BuildStore:GetClassColor(classID)
            end
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
