local addonName, LPL = ...

LPL.AddonProfileSetList = {}

function LPL.AddonProfileSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "addonprofiles",
        supportedFilters = {},
        title = "Saved Addon Profiles",
        hint = "Opaque strings for other addons | Export copies the raw string for Ctrl+C | Double-click to edit.",
        emptyFilterText = "No addon profiles match your search.",
        emptyButtonLabel = "New Addon Profile",
        emptyButtonWidth = 170,
        getItems = function()
            return LPL.AddonProfileStore:GetAll()
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
            return LPL.AddonProfileStore:GetSummaryLine(set)
        end,
        getSubtitleColor = function()
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
