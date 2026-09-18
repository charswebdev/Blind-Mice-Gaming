local addonName, LPL = ...

LPL.KeybindSetList = {}

function LPL.KeybindSetList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "keybinds",
        supportedFilters = {},
        flatList = true,
        title = "Keybinding Profiles",
        hint = "Click to select · Double-click to edit · Green dot = currently bound",
        emptyFilterText = "No keybinding profiles match your search.",
        emptyButtonLabel = "New Profile",
        emptyButtonWidth = 130,
        getItems = function()
            return LPL.KeybindStore:GetAll()
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
        isActive = function(set)
            return LPL.KeybindActive and LPL.KeybindActive:IsActive(set)
        end,
        getSubtitle = function(set)
            return LPL.KeybindStore:GetSummaryLine(set)
        end,
        getSubtitleColor = function(set)
            if LPL.KeybindStore:GetSummaryWarning(set) then
                return 1, 0.55, 0.35
            end
            return LPL.Theme:GetColor("textSecondary")
        end,
    })

    list.SetOnNewSet = list.SetOnNew
    list.SetSelectedSetID = list.SetSelectedID

    return list
end
