local addonName, LPL = ...

LPL.AddonSetSetList = {}

function LPL.AddonSetSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "addonsets",
        supportedFilters = {},
        multiSelect = true,
        title = "Addon Sets",
        hint = "Click to multi-select · Double-click to edit · Activate replaces · Import/Export share strings",
        emptyFilterText = "No addon sets match your search.",
        emptyButtonLabel = "New Addon Set",
        emptyButtonWidth = 150,
        getItems = function()
            return LPL.AddonSetStore:GetAll()
        end,
        getID = function(set)
            return set.id
        end,
        getName = function(set)
            return set.name
        end,
        getFilters = function()
            return {}
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
        getSubtitle = function(set)
            return LPL.AddonSetStore:GetSummaryLine(set)
        end,
        getSubtitleColor = function(set)
            if LPL.AddonSetStore:GetSummaryWarning(set) then
                return 1, 0.55, 0.35
            end
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
