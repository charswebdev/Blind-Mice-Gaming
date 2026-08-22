local addonName, LPL = ...

LPL.EditModeSetList = {}

function LPL.EditModeSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "editmode",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Edit Mode Layouts",
        hint = "Universal by default | Use Limits to group by class, spec, or character | Green dot = active on your character | Double-click to edit.",
        emptyFilterText = "No Edit Mode layouts match your search or filters.",
        emptyButtonLabel = "New Edit Mode Layout",
        emptyButtonWidth = 200,
        getItems = function()
            return LPL.EditModeStore:GetAll()
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
            return LPL.EditModeStore:GetEffectiveClassID(set)
        end,
        getSpecKey = function(set)
            return LPL.EditModeStore:GetEffectiveSpecID(set)
        end,
        getHeroKey = function(set)
            return LPL.EditModeStore:GetEffectiveHeroID(set)
        end,
        isActive = function(set)
            return LPL.EditModeActive and LPL.EditModeActive:IsActive(set)
        end,
        getSubtitle = function(set)
            local line = LPL.EditModeStore:GetSummaryLine(set)
            if set.restrictions and next(set.restrictions) then
                return line .. " · Restricted"
            end
            return line
        end,
        getSubtitleColor = function(set)
            local classID = LPL.EditModeStore:GetEffectiveClassID(set)
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
