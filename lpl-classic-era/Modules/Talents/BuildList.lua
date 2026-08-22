local addonName, LPL = ...

LPL.TalentBuildList = {}

function LPL.TalentBuildList:Create(parent, bottomInset)
    local list = LPL.SetListView:Create(parent, {
        bottomInset = bottomInset,
        listKey = "talents",
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Builds",
        hint = "Class > spec > hero talent · Double-click to edit · Green dot = active build.",
        emptyFilterText = "No builds match your search or filters.",
        emptyButtonLabel = "New Build",
        emptyButtonWidth = 160,
        getItems = function()
            return LPL.BuildStore:GetAll()
        end,
        getID = function(build)
            return build.id
        end,
        getName = function(build)
            return build.name
        end,
        getFilters = function(build)
            return build.filters
        end,
        getClassKey = function(build)
            return build.classID
        end,
        getSpecKey = function(build)
            return build.specID
        end,
        getHeroKey = function(build)
            return build.subTreeID
        end,
        isActive = function(build)
            return LPL.BuildActive:IsActive(build)
        end,
        getSubtitle = function(build)
            local parts = {}
            if build.level then
                parts[#parts + 1] = "Lv " .. build.level
            end
            local line = table.concat(parts, " · ")
            if build.restrictions and next(build.restrictions) then
                if line == "" then
                    return "Restricted"
                end
                return line .. " · Restricted"
            end
            return line
        end,
        getSubtitleColor = function(build)
            return LPL.BuildStore:GetClassColor(build.classID)
        end,
    })

    list.SetOnNewBuild = list.SetOnNew
    list.SetSelectedBuildID = list.SetSelectedID
    list.SetDeleteEnabled = function() end

    return list
end
