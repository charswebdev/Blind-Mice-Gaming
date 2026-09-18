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
            if build.specID then
                return build.specID
            end
            if build.restrictions and build.restrictions.herotalents and LPL.SetRestrictions.ParseHeroTalentKey then
                for key in pairs(build.restrictions.herotalents) do
                    local specID = LPL.SetRestrictions:ParseHeroTalentKey(key)
                    if specID then
                        return specID
                    end
                end
            end
            return nil
        end,
        getHeroKey = function(build)
            if build.subTreeID then
                return build.subTreeID
            end
            if build.restrictions and build.restrictions.herotalents and LPL.SetRestrictions.ParseHeroTalentKey then
                for key in pairs(build.restrictions.herotalents) do
                    local _, heroID = LPL.SetRestrictions:ParseHeroTalentKey(key)
                    if heroID then
                        return heroID
                    end
                end
            end
            return nil
        end,
        isActive = function(build)
            return LPL.BuildActive:IsActive(build)
        end,
        getSubtitle = function(build)
            local levelText = ""
            if build.level then
                levelText = "Level: " .. tostring(build.level)
            end
            return LPL.SetRestrictions:FormatListSubtitle(levelText, build.restrictions)
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
