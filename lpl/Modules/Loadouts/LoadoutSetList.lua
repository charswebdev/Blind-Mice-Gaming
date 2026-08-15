local addonName, LPL = ...

LPL.LoadoutSetList = {}

function LPL.LoadoutSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "loadouts",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Loadouts",
        hint = "Universal by default | Use Limits to group by class, spec, or character | Double-click to edit and attach segments.",
        emptyFilterText = "No loadouts match your search or filters.",
        emptyButtonLabel = "New Loadout",
        emptyButtonWidth = 140,
        getItems = function()
            return LPL.LoadoutStore:GetAll()
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
            return LPL.LoadoutStore:GetEffectiveClassID(set)
        end,
        getSpecKey = function(set)
            return LPL.LoadoutStore:GetEffectiveSpecID(set)
        end,
        getHeroKey = function(set)
            return LPL.LoadoutStore:GetEffectiveHeroID(set)
        end,
        isActive = function()
            return false
        end,
        getSubtitle = function(set)
            local line = LPL.LoadoutStore:GetSummaryLine(set)
            if set.restrictions and next(set.restrictions) then
                return line .. " · Restricted"
            end
            return line
        end,
        getSubtitleColor = function(set)
            local classID = LPL.LoadoutStore:GetEffectiveClassID(set)
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
