local addonName, LPL = ...

LPL.EquipmentSetList = {}

function LPL.EquipmentSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "equipment",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Equipment Sets",
        hint = "Universal by default | Use Limits to restrict by class, spec, or character | Green dot = on your character | Double-click to edit.",
        emptyFilterText = "No equipment sets match your search or filters.",
        emptyButtonLabel = "New Equipment Set",
        emptyButtonWidth = 180,
        getItems = function()
            return LPL.EquipmentStore:GetAll()
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
            return LPL.EquipmentStore:GetEffectiveClassID(set)
        end,
        getSpecKey = function(set)
            return LPL.EquipmentStore:GetEffectiveSpecID(set)
        end,
        getHeroKey = function(set)
            return LPL.EquipmentStore:GetEffectiveHeroID(set)
        end,
        isActive = function(set)
            return LPL.EquipmentActive:IsActive(set)
        end,
        getSubtitle = function(set)
            local line = LPL.EquipmentStore:GetSummaryLine(set)
            local restrictionLine = LPL.SetRestrictions and LPL.SetRestrictions:GetSummaryLine(set.restrictions)
            if restrictionLine then
                if line == "" then
                    return restrictionLine
                end
                return line .. " | " .. restrictionLine
            end
            return line
        end,
        getSubtitleColor = function(set)
            if set.restrictions and next(set.restrictions) then
                local classID = LPL.EquipmentStore:GetEffectiveClassID(set)
                if classID and LPL.BuildStore then
                    return LPL.BuildStore:GetClassColor(classID)
                end
            end
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
