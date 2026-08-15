local addonName, LPL = ...

LPL.BuildStore = {}

LPL.BuildStore.MAX_NAME_LENGTH = 150

local SAVE_DIALOG = "LPL_SAVE_BUILD"

local function GetTalentsData()
    return LPL.DB:GetTalents()
end

function LPL.BuildStore:NormalizeNodesForStorage(nodes)
    if type(nodes) ~= "table" then
        return {}
    end

    local stored = {}
    for rawNodeID, value in pairs(nodes) do
        local nodeID = tostring(rawNodeID)
        if type(value) == "number" then
            local rank = math.floor(value)
            if rank > 0 then
                stored[nodeID] = rank
            end
        elseif type(value) == "table" then
            local rank = tonumber(value.rank or value.ranks or value[1])
            local entryID = value.entryID or value.entryId
            if rank and rank > 0 then
                entryID = entryID and tonumber(entryID) or nil
                if entryID then
                    stored[nodeID] = {
                        rank = math.floor(rank),
                        entryID = entryID,
                    }
                else
                    stored[nodeID] = math.floor(rank)
                end
            end
        end
    end
    return stored
end

function LPL.BuildStore:NormalizeEntriesForStorage(entries)
    if type(entries) ~= "table" then
        return nil
    end

    local stored = {}
    for rawNodeID, entryID in pairs(entries) do
        local nodeID = tostring(rawNodeID)
        entryID = tonumber(entryID)
        if nodeID and entryID then
            stored[nodeID] = entryID
        end
    end
    if not next(stored) then
        return nil
    end
    return stored
end

function LPL.BuildStore:NormalizeBuildRecord(build)
    if type(build) ~= "table" then
        return nil
    end

    build.id = tostring(build.id or "")
    if build.id == "" then
        return nil
    end

    build.name = self:NormalizeBuildName(build.name, "New Build")
    build.classID = tonumber(build.classID) or build.classID
    build.specID = tonumber(build.specID) or build.specID
    build.subTreeID = tonumber(build.subTreeID) or build.subTreeID
    build.level = tonumber(build.level) or build.level
    build.nodes = self:NormalizeNodesForStorage(build.nodes)

    local entries = self:NormalizeEntriesForStorage(build.entries)
    if entries then
        build.entries = entries
    else
        build.entries = nil
    end

    if LPL.SetRestrictions then
        build.restrictions = LPL.SetRestrictions:NormalizeRestrictions(build.restrictions)
        LPL.SetRestrictions:UpdateTalentBuildFilters(build)
    end

    build.createdAt = tonumber(build.createdAt) or time()
    build.updatedAt = tonumber(build.updatedAt) or build.createdAt

    return build
end

local function SyncTalentsGlobal(talents)
    _G.LPLDB = _G.LPLDB or {}
    _G.LPLDB.talents = talents
    if LPL.DB then
        LPL.DB.data = _G.LPLDB
    end
    return talents
end

function LPL.BuildStore:CommitBuild(build)
    build = self:NormalizeBuildRecord(build)
    if not build then
        return false
    end

    build.updatedAt = time()
    if not build.createdAt then
        build.createdAt = build.updatedAt
    end

    local talents = SyncTalentsGlobal(GetTalentsData())
    if type(talents.builds) ~= "table" then
        talents.builds = {}
    end

    talents.builds[build.id] = build

    local numericID = tostring(build.id):match("^build_(%d+)$")
    if numericID then
        local idNum = tonumber(numericID) or 0
        talents.nextBuildId = math.max(talents.nextBuildId or 0, idNum)
    end

    return true
end

function LPL.BuildStore:MigrateStorage()
    local talents = SyncTalentsGlobal(GetTalentsData())
    local builds = self:EnsureBuildsTable()

    for buildID, build in pairs(builds) do
        if type(build) == "table" then
            build.id = build.id or tostring(buildID)
            self:NormalizeBuildRecord(build)
        end
    end

    local maxID = talents.nextBuildId or 0
    for buildID in pairs(builds) do
        local numericID = tostring(buildID):match("^build_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    talents.nextBuildId = maxID
end

function LPL.BuildStore:EnsureBuildsTable()
    local talents = SyncTalentsGlobal(GetTalentsData())
    if type(talents.builds) ~= "table" then
        talents.builds = {}
    end
    if talents.nextBuildId == nil then
        talents.nextBuildId = 0
    end
    return talents.builds
end

function LPL.BuildStore:GenerateID()
    local talents = GetTalentsData()
    talents.nextBuildId = (talents.nextBuildId or 0) + 1
    return "build_" .. talents.nextBuildId
end

function LPL.BuildStore:GetAll()
    local builds = self:EnsureBuildsTable()
    local list = {}
    for _, build in pairs(builds) do
        list[#list + 1] = build
    end
    return list
end

function LPL.BuildStore:Get(buildID)
    if not buildID then
        return nil
    end
    return self:EnsureBuildsTable()[buildID]
end

function LPL.BuildStore:ResolveName(id, list, fallback)
    if not id or not list then
        return fallback or "-"
    end
    for _, entry in ipairs(list) do
        if entry.id == id then
            return entry.name or fallback or "-"
        end
    end
    return fallback or "-"
end

function LPL.BuildStore:NormalizeBuildName(name, fallback)
    fallback = fallback or "New Build"
    if type(name) ~= "string" then
        return fallback
    end
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        return fallback
    end
    if #name > self.MAX_NAME_LENGTH then
        name = name:sub(1, self.MAX_NAME_LENGTH)
    end
    return name
end

function LPL.BuildStore:FormatLoadoutPath(data, overrideName)
    if type(data) ~= "table" then
        return overrideName or "Imported Build"
    end

    local buildName = self:NormalizeBuildName(overrideName or data.name, "Imported Build")
    local classID = tonumber(data.classID)
    local specID = tonumber(data.specID)
    local subTreeID = tonumber(data.subTreeID)

    local parts = {}
    local className = self:ResolveName(classID, LPL.TalentTree:GetClasses(), nil)
    if className and className ~= "-" then
        parts[#parts + 1] = className
    end

    local specName = self:ResolveName(specID, LPL.TalentTree:GetSpecsForClass(classID or 1), nil)
    if specName and specName ~= "" and specName ~= "-" then
        parts[#parts + 1] = specName
    end

    local heroName = self:ResolveName(subTreeID, LPL.TalentTree:GetHeroTalentsForSpec(specID or 0), nil)
    if heroName and heroName ~= "" and heroName ~= "-" and heroName ~= "Hero" then
        parts[#parts + 1] = heroName
    end

    parts[#parts + 1] = buildName
    return table.concat(parts, ">")
end

function LPL.BuildStore:FindByLoadoutPath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local normalized = path:lower()
    for _, build in pairs(self:EnsureBuildsTable()) do
        local buildPath = self:FormatLoadoutPath(build)
        if buildPath:lower() == normalized then
            return build
        end
        if build.name and build.name:lower() == normalized then
            return build
        end
    end
    return nil
end

local function FilterImportNodes(nodes, subTreeID, includeTalents, includeHero)
    if not nodes then
        return {}
    end
    if includeTalents and includeHero then
        return LPL.BuildStore:NormalizeNodesForStorage(nodes)
    end

    local filtered = {}
    for rawNodeID, value in pairs(nodes) do
        local nodeID = tonumber(rawNodeID)
        local pool = nodeID and LPL.TalentTree:GetNodePointPool(nodeID, subTreeID) or "spec"
        local include = false
        if pool == "hero" then
            include = includeHero
        else
            include = includeTalents
        end
        if include then
            filtered[tostring(rawNodeID)] = value
        end
    end
    return LPL.BuildStore:NormalizeNodesForStorage(filtered)
end

function LPL.BuildStore:ApplyImport(importData, buildName, options)
    if type(importData) ~= "table" or type(options) ~= "table" then
        return nil
    end

    local path = self:FormatLoadoutPath(importData, buildName)
    local existingBuild = options.existingBuildID and self:Get(options.existingBuildID)
        or self:FindByLoadoutPath(path)

    local includeTalents = options.talents ~= false
    local includeHero = options.hero ~= false
    local includeActionBars = options.actionBars == true
    local useExisting = existingBuild ~= nil

    if not includeTalents and not includeHero and not includeActionBars then
        return nil
    end

    local subTreeID = importData.subTreeID
    local nodes = FilterImportNodes(importData.nodes, subTreeID, includeTalents, includeHero)

    if useExisting then
        local build = existingBuild
        if includeTalents or includeHero then
            if includeTalents and includeHero then
                build.nodes = nodes
            elseif includeTalents then
                local merged = {}
                for nodeID, value in pairs(build.nodes or {}) do
                    local pool = LPL.TalentTree:GetNodePointPool(tonumber(nodeID), build.subTreeID)
                    if pool ~= "hero" then
                        merged[nodeID] = value
                    end
                end
                for nodeID, value in pairs(nodes) do
                    merged[nodeID] = value
                end
                build.nodes = merged
            elseif includeHero then
                local merged = {}
                for nodeID, value in pairs(build.nodes or {}) do
                    local pool = LPL.TalentTree:GetNodePointPool(tonumber(nodeID), build.subTreeID)
                    if pool == "hero" then
                        merged[nodeID] = value
                    end
                end
                for nodeID, value in pairs(nodes) do
                    merged[nodeID] = value
                end
                build.nodes = merged
            end
        end
        if includeHero and subTreeID then
            build.subTreeID = subTreeID
        end
        if includeTalents or includeHero then
            build.specID = importData.specID or build.specID
            build.classID = importData.classID or build.classID
            build.level = importData.level or build.level
        end
        build.name = self:NormalizeBuildName(buildName, build.name)
        build.updatedAt = time()
        if not self:CommitBuild(build) then
            return nil
        end
        return build
    end

    local createData = {
        name = buildName,
        classID = importData.classID,
        specID = importData.specID,
        subTreeID = importData.subTreeID,
        level = importData.level,
        nodes = nodes,
    }
    local build = self:CreateFromImport(createData, buildName)
    if not build then
        return nil
    end
    return build
end

function LPL.BuildStore:SuggestBuildName(view)
    view = view or LPL.DB:GetTalentView()
    if not view or not view.classID then
        return "New Build"
    end
    local className = self:ResolveName(view.classID, LPL.TalentTree:GetClasses(), "Build")
    local specName = self:ResolveName(view.specID, LPL.TalentTree:GetSpecsForClass(view.classID), "")
    if specName and specName ~= "" and specName ~= "-" then
        return self:NormalizeBuildName(className .. " " .. specName, "New Build")
    end
    return self:NormalizeBuildName(className, "New Build")
end

function LPL.BuildStore:ApplySandboxToBuild(build, sandbox, view)
    if not build or not sandbox or not view then
        return false
    end
    build.classID = view.classID
    build.specID = view.specID
    build.subTreeID = view.subTreeID
    build.level = view.level
    if GetMaxLevelForPlayerExpansion then
        build.level = view.level or GetMaxLevelForPlayerExpansion()
    end
    build.nodes = sandbox:ExportToBuildNodes()
    if sandbox.entries then
        build.entries = {}
        for nodeID, entryID in pairs(sandbox.entries) do
            build.entries[tostring(nodeID)] = tonumber(entryID) or entryID
        end
    else
        build.entries = nil
    end
    build.updatedAt = time()
    return true
end

function LPL.BuildStore:Update(buildID, sandbox, view, name)
    local build = self:Get(buildID)
    if not build then
        return false
    end
    if name then
        build.name = self:NormalizeBuildName(name, build.name)
    end
    if not self:ApplySandboxToBuild(build, sandbox, view) then
        return false
    end
    return self:CommitBuild(build)
end

function LPL.BuildStore:CreateFromSandbox(name, sandbox, view)
    if not sandbox or not view then
        return nil
    end

    local level = view.level or 90
    if GetMaxLevelForPlayerExpansion then
        level = view.level or GetMaxLevelForPlayerExpansion()
    end

    local id = self:GenerateID()
    local build = {
        id = id,
        name = self:NormalizeBuildName(name, "New Build"),
        classID = view.classID,
        specID = view.specID,
        subTreeID = view.subTreeID,
        level = level,
        nodes = sandbox:ExportToBuildNodes(),
        createdAt = time(),
        updatedAt = time(),
    }

    if sandbox.entries then
        build.entries = {}
        for nodeID, entryID in pairs(sandbox.entries) do
            build.entries[tostring(nodeID)] = tonumber(entryID) or entryID
        end
    end

    if not self:CommitBuild(build) then
        return nil
    end
    return build
end

function LPL.BuildStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end

    local now = time()
    local build = {
        id = self:GenerateID(),
        name = self:NormalizeBuildName(name, importData.name or "Imported Build"),
        classID = tonumber(importData.classID),
        specID = tonumber(importData.specID),
        subTreeID = tonumber(importData.subTreeID),
        level = tonumber(importData.level) or (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 90,
        nodes = self:NormalizeNodesForStorage(importData.nodes),
        createdAt = now,
        updatedAt = now,
    }

    if not build.specID then
        return nil
    end

    build.classID = build.classID or LPL.TalentTree:GetClassIDForSpec(build.specID)

    if build.subTreeID then
        local heroes = LPL.TalentTree:GetHeroTalentsForSpec(build.specID) or {}
        local heroValid = false
        for _, hero in ipairs(heroes) do
            if hero.id == build.subTreeID then
                heroValid = true
                break
            end
        end
        if not heroValid then
            build.subTreeID = heroes[1] and heroes[1].id
        end
    else
        local heroes = LPL.TalentTree:GetHeroTalentsForSpec(build.specID) or {}
        build.subTreeID = heroes[1] and heroes[1].id
    end

    if not self:CommitBuild(build) then
        return nil
    end
    return build
end

function LPL.BuildStore:EnsureSaveDialog()
    if StaticPopupDialogs[SAVE_DIALOG] then
        return
    end

    StaticPopupDialogs[SAVE_DIALOG] = {
        text = "Save build as:",
        button1 = SAVE,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = LPL.BuildStore.MAX_NAME_LENGTH,
        OnShow = function(dialog)
            local suggested = dialog.data and dialog.data.suggestedName or "New Build"
            dialog.editBox:SetMaxLetters(LPL.BuildStore.MAX_NAME_LENGTH)
            dialog.editBox:SetText(suggested)
            dialog.editBox:SetFocus()
            dialog.editBox:HighlightText()
        end,
        OnAccept = function(dialog)
            local data = dialog.data
            if not data or not data.onAccept then
                return
            end
            local name = LPL.BuildStore:NormalizeBuildName(
                dialog.editBox:GetText(),
                data.suggestedName or "New Build"
            )
            data.onAccept(name)
        end,
        EditBoxOnEnterPressed = function(editBox)
            editBox:GetParent().button1:Click()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function LPL.BuildStore:PromptSaveName(suggestedName, onAccept)
    self:EnsureSaveDialog()
    StaticPopup_Show(SAVE_DIALOG, nil, nil, {
        suggestedName = self:NormalizeBuildName(suggestedName, "New Build"),
        onAccept = onAccept,
    })
end

function LPL.BuildStore:SaveFromEditor(buildID, sandbox, view, name, onSaved)
    if not sandbox or not view then
        return false
    end

    local normalizedName = self:NormalizeBuildName(name, self:SuggestBuildName(view))

    if buildID then
        local ok = self:Update(buildID, sandbox, view, normalizedName)
        if ok then
            if onSaved then
                onSaved(buildID, false)
            end
            print(string.format("|cff33cc33LPL:|r Saved build \"%s\".", normalizedName))
        end
        return ok
    end

    local build = self:CreateFromSandbox(normalizedName, sandbox, view)
    if build then
        if onSaved then
            onSaved(build.id, true)
        end
        print(string.format("|cff33cc33LPL:|r Saved build \"%s\".", build.name or normalizedName))
    end
    return build ~= nil
end

function LPL.BuildStore:GetSummaryLine(build)
    if not build then
        return ""
    end
    local className = self:ResolveName(build.classID, LPL.TalentTree:GetClasses(), "Class")
    local specName = self:ResolveName(build.specID, LPL.TalentTree:GetSpecsForClass(build.classID or 1), "Spec")
    local heroName = self:ResolveName(build.subTreeID, LPL.TalentTree:GetHeroTalentsForSpec(build.specID or 0), "Hero")
    return string.format("%s · %s · %s", className, specName, heroName)
end

function LPL.BuildStore:GetClassColor(classID)
    if not classID or not GetClassInfo then
        return LPL.Theme:GetColor("textSecondary")
    end

    local _, classFile = GetClassInfo(classID)
    if not classFile then
        return LPL.Theme:GetColor("textSecondary")
    end

    return LPL.Theme:GetWoWClassColor(classFile)
end

function LPL.BuildStore:CreateNew(name)
    local classID = LPL.TalentTree:GetDefaultClassID()
    local specs = LPL.TalentTree:GetSpecsForClass(classID)
    local specID = specs[1] and specs[1].id
    local heroes = specID and LPL.TalentTree:GetHeroTalentsForSpec(specID) or {}
    local subTreeID = heroes[1] and heroes[1].id

    local level = 90
    if GetMaxLevelForPlayerExpansion then
        level = GetMaxLevelForPlayerExpansion()
    end

    local id = self:GenerateID()
    local build = {
        id = id,
        name = self:NormalizeBuildName(name, "New Build"),
        classID = classID,
        specID = specID,
        subTreeID = subTreeID,
        level = level,
        nodes = {},
        createdAt = time(),
        updatedAt = time(),
    }

    self:EnsureBuildsTable()[id] = build
    self:CommitBuild(build)
    return build
end

function LPL.BuildStore:Delete(buildID)
    if not buildID then
        return false
    end
    local builds = self:EnsureBuildsTable()
    if builds[buildID] then
        builds[buildID] = nil
        return true
    end
    return false
end

function LPL.BuildStore:ApplyToView(build)
    if not build then
        return
    end
    local view = LPL.DB:GetTalentView()
    view.classID = build.classID
    view.specID = build.specID
    view.subTreeID = build.subTreeID
    view.level = build.level or view.level
end

function LPL.BuildStore:ConfirmDelete(buildID, onConfirm)
    local build = self:Get(buildID)
    if not build then
        return
    end

    local dialogName = "LPL_CONFIRM_DELETE_BUILD"
    if not StaticPopupDialogs[dialogName] then
        StaticPopupDialogs[dialogName] = {
            text = "Delete build \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.buildID and LPL.BuildStore:Delete(data.buildID) then
                    if data.onConfirm then
                        data.onConfirm()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(dialogName, build.name or "Build", nil, {
        buildID = buildID,
        onConfirm = onConfirm,
    })
end
