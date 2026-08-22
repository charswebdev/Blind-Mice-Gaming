local addonName, LPL = ...

LPL.MacroSetList = {}

function LPL.MacroSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "macros",
        supportedFilters = {},
        title = "Saved Macros",
        hint = "Load from Account/Character macros, edit, then Save to update both LPL and Blizzard | Double-click to edit | Export copies body text.",
        emptyFilterText = "No macros match your search.",
        emptyButtonLabel = "New Macro",
        emptyButtonWidth = 140,
        getItems = function()
            return LPL.MacroStore:GetAll()
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
            return LPL.MacroStore:GetSummaryLine(set)
        end,
        getSubtitleColor = function()
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
