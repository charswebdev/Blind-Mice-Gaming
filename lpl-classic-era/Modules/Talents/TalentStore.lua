local addonName, LPL = ...

LPL.TalentStore = {}
LPL.TalentStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_TALENT_BUILD"

local function GetTalentData()
    return LPL.DB:GetTalents()
end

local function SyncGlobal(talents)
    if type(LPLClassicEraDB) ~= "table" then
        LPLClassicEraDB = type(_G.LPLClassicEraDB) == "table" and _G.LPLClassicEraDB or {}
    end
    LPLClassicEraDB.talents = talents
    _G.LPLClassicEraDB = LPLClassicEraDB
    if LPL.DB then
        LPL.DB.data = LPLClassicEraDB
    end
end

function LPL.TalentStore:NormalizeName(name, fallback)
    fallback = fallback or "New Talent Build"
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

function LPL.TalentStore:GenerateID()
    local data = GetTalentData()
    data.nextBuildId = (tonumber(data.nextBuildId) or 0) + 1
    SyncGlobal(data)
    return tostring(data.nextBuildId)
end

function LPL.TalentStore:NormalizeBuild(build)
    if type(build) ~= "table" then
        return nil
    end
    build.id = tostring(build.id or "")
    if build.id == "" then
        return nil
    end
    build.name = self:NormalizeName(build.name, "New Talent Build")
    build.classID = tonumber(build.classID)
    build.level = tonumber(build.level) or LPL.TalentAPI:GetMaxLevel()
    build.talentGroup = tonumber(build.talentGroup) or 1
    build.tabs = type(build.tabs) == "table" and build.tabs or {}
    build.totalPoints = tonumber(build.totalPoints) or LPL.TalentAPI:RecalcDraftPoints(build)
    build.createdAt = tonumber(build.createdAt) or time()
    build.updatedAt = tonumber(build.updatedAt) or build.createdAt
    if LPL.SetRestrictions then
        build.restrictions = LPL.SetRestrictions:NormalizeRestrictions(build.restrictions or {})
        LPL.SetRestrictions:UpdateTalentBuildFilters(build)
    end
    return build
end

function LPL.TalentStore:GetAll()
    local data = GetTalentData()
    if type(data.builds) ~= "table" then
        data.builds = {}
    end
    local list = {}
    for _, build in pairs(data.builds) do
        local normalized = self:NormalizeBuild(build)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        return (a.updatedAt or 0) > (b.updatedAt or 0)
    end)
    return list
end

function LPL.TalentStore:Get(buildID)
    buildID = tostring(buildID or "")
    if buildID == "" then
        return nil
    end
    local data = GetTalentData()
    return self:NormalizeBuild(data.builds and data.builds[buildID])
end

function LPL.TalentStore:SuggestName(draft)
    local classID = draft and tonumber(draft.classID)
    local className
    if classID and GetClassInfo then
        className = GetClassInfo(classID)
    end
    if not className then
        className = select(1, UnitClass("player"))
    end
    local summary = LPL.TalentAPI:SummarizeBuild(draft) or "0/0/0"
    return string.format("%s %s", className or "Talent", summary)
end

function LPL.TalentStore:CreateDraft(name)
    local classID = LPL.TalentAPI:GetPlayerClassID()
    local draft = {
        classID = classID,
        level = LPL.TalentAPI:GetMaxLevel(),
        talentGroup = 1,
        tabs = {},
        totalPoints = 0,
        restrictions = {},
    }
    LPL.TalentAPI:EnsureDraftClass(draft, classID)
    draft.name = self:NormalizeName(name, self:SuggestName(draft))
    return draft
end

function LPL.TalentStore:CommitBuild(build)
    build = self:NormalizeBuild(build)
    if not build then
        return nil
    end
    local data = GetTalentData()
    data.builds = data.builds or {}
    build.updatedAt = time()
    if not build.createdAt then
        build.createdAt = build.updatedAt
    end
    data.builds[build.id] = build
    SyncGlobal(data)
    return build
end

function LPL.TalentStore:SaveFromEditor(buildID, name, draft, onDone)
    if type(draft) ~= "table" then
        return
    end
    local data = GetTalentData()
    data.builds = data.builds or {}

    local build
    if buildID and data.builds[tostring(buildID)] then
        build = CopyTable(data.builds[tostring(buildID)])
        build.id = tostring(buildID)
    else
        build = {
            id = self:GenerateID(),
            createdAt = time(),
        }
    end

    build.name = self:NormalizeName(name, self:SuggestName(draft))
    build.classID = tonumber(draft.classID) or LPL.TalentAPI:GetPlayerClassID()
    build.level = LPL.TalentAPI:GetDraftLevel(draft)
    build.talentGroup = tonumber(draft.talentGroup) or 1
    build.tabs = CopyTable(draft.tabs or {})
    build.restrictions = CopyTable(draft.restrictions or {})
    LPL.TalentAPI:RecalcDraftPoints(build)
    self:CommitBuild(build)

    if onDone then
        onDone(build.id)
    end
    return build
end

function LPL.TalentStore:Delete(buildID)
    buildID = tostring(buildID or "")
    local data = GetTalentData()
    if data.builds then
        data.builds[buildID] = nil
        SyncGlobal(data)
    end
end

function LPL.TalentStore:ConfirmDelete(buildID, onConfirm)
    local build = self:Get(buildID)
    if not build then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete talent build \"%s\"?",
            button1 = YES,
            button2 = NO,
            OnAccept = function(dialog)
                if dialog.data and dialog.data.onConfirm then
                    dialog.data.onConfirm()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local dialog = StaticPopup_Show(DELETE_DIALOG, build.name)
    if dialog then
        dialog.data = {
            onConfirm = function()
                self:Delete(buildID)
                if onConfirm then
                    onConfirm()
                end
            end,
        }
    end
end

function LPL.TalentStore:GetSummaryLine(build)
    return LPL.TalentAPI:SummarizeBuild(build)
end

function LPL.TalentStore:GetEffectiveClassID(build)
    return build and tonumber(build.classID) or nil
end

function LPL.TalentStore:GetClassColor(classID)
    classID = tonumber(classID)
    if not classID then
        return 0.78, 0.61, 0.43
    end
    local classFile
    if type(GetClassInfo) == "function" then
        local _, file = GetClassInfo(classID)
        classFile = file
    end
    if classFile and type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r or 1, c.g or 1, c.b or 1
    end
    return 0.78, 0.61, 0.43
end
