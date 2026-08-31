local addonName, LPL = ...

LPL.PvpTalentSetList = {}

function LPL.PvpTalentSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "pvptalents",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved PvP Talent Sets",
        hint = "Universal by default | Use Limits to group by class, spec, or character | Green dot = on your character | Double-click to edit.",
        emptyFilterText = "No PvP talent sets match your search or filters.",
        emptyButtonLabel = "New PvP Set",
        emptyButtonWidth = 150,
        getItems = function()
            return LPL.PvpTalentStore:GetAll()
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
            return LPL.PvpTalentStore:GetEffectiveClassID(set)
        end,
        getSpecKey = function(set)
            return LPL.PvpTalentStore:GetEffectiveSpecID(set)
        end,
        getHeroKey = function(set)
            return LPL.PvpTalentStore:GetEffectiveHeroID(set)
        end,
        isActive = function(set)
            return LPL.PvpTalentActive and LPL.PvpTalentActive:IsActive(set)
        end,
        getSubtitle = function(set)
            return LPL.SetRestrictions:FormatListSubtitle(LPL.PvpTalentStore:GetSummaryLine(set), set.restrictions)
        end,
        getSubtitleColor = function(set)
            local classID = LPL.PvpTalentStore:GetEffectiveClassID(set)
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
