local addonName, LPL = ...

LPL.HousingSetList = {}

function LPL.HousingSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "housing",
        supportedFilters = {},
        title = "Saved Housing Blueprints",
        hint = "Blizzard house codes | Copy for House copies the code | Import on your plot in House Editor | Double-click to edit.",
        emptyFilterText = "No housing blueprints match your search.",
        emptyButtonLabel = "New Housing Blueprint",
        emptyButtonWidth = 190,
        getItems = function()
            return LPL.HousingStore:GetAll()
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
            return LPL.HousingStore:GetSummaryLine(set)
        end,
        getSubtitleColor = function()
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
