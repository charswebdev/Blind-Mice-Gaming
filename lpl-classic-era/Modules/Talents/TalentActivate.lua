local addonName, LPL = ...

LPL.TalentActivate = {}

local function CountLivePoints(talentGroup)
    local build = LPL.TalentAPI:CaptureLiveBuild(talentGroup)
    return build and build.totalPoints or 0
end

local function RankMatches(draft, talentGroup)
    local tabCount = LPL.TalentAPI:GetNumTabs()
    for tabIndex = 1, tabCount do
        for _, talent in ipairs(LPL.TalentAPI:IterateTabTalents(tabIndex, talentGroup)) do
            local wanted = LPL.TalentAPI:GetDraftRank(draft, tabIndex, talent.talentIndex)
            if (talent.rank or 0) ~= wanted then
                return false
            end
        end
    end
    return true
end

function LPL.TalentActivate:CanApply(draft)
    if type(draft) ~= "table" then
        return false, "No talent build selected."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot apply talents in combat."
    end
    local playerClass = LPL.TalentAPI:GetPlayerClassID()
    if draft.classID and playerClass and tonumber(draft.classID) ~= playerClass then
        return false, "This build is for a different class."
    end
    return true
end

function LPL.TalentActivate:ApplyDraft(draft, onDone)
    local ok, err = self:CanApply(draft)
    if not ok then
        if LPL.ActivateFeedback then
            LPL.ActivateFeedback:Speak(err or "Cannot apply talents.")
        else
            print("|cffff6060LPL:|r " .. (err or "Cannot apply talents."))
        end
        if onDone then
            onDone(false, err)
        end
        return false, err
    end

    local talentGroup = LPL.TalentAPI:GetActiveTalentGroup()
    local live = LPL.TalentAPI:CaptureLiveBuild(talentGroup)

    -- Detect decreases: Classic cannot unlearn without a reset.
    local needsReset = false
    for tabIndex = 1, LPL.TalentAPI:GetNumTabs() do
        for _, talent in ipairs(LPL.TalentAPI:IterateTabTalents(tabIndex, talentGroup)) do
            local wanted = LPL.TalentAPI:GetDraftRank(draft, tabIndex, talent.talentIndex)
            if talent.rank > wanted then
                needsReset = true
                break
            end
        end
        if needsReset then
            break
        end
    end

    if needsReset then
        local msg = "This build needs fewer ranks than you currently have. Reset your talents at a trainer first, then apply again."
        if LPL.ActivateFeedback then
            LPL.ActivateFeedback:Speak(msg)
        else
            print("|cffffcc00LPL:|r " .. msg)
        end
        if onDone then
            onDone(false, msg)
        end
        return false, msg
    end

    -- Learn missing ranks in tier order.
    local learned = 0
    local guard = 0
    while guard < 80 do
        guard = guard + 1
        local progressed = false
        for tabIndex = 1, LPL.TalentAPI:GetNumTabs() do
            local talents = LPL.TalentAPI:IterateTabTalents(tabIndex, talentGroup)
            table.sort(talents, function(a, b)
                if a.tier ~= b.tier then
                    return a.tier < b.tier
                end
                return a.column < b.column
            end)
            for _, talent in ipairs(talents) do
                local wanted = LPL.TalentAPI:GetDraftRank(draft, tabIndex, talent.talentIndex)
                local liveInfo = LPL.TalentAPI:GetTalentInfo(tabIndex, talent.talentIndex, talentGroup)
                local have = liveInfo and liveInfo.rank or 0
                if have < wanted then
                    local okLearn, learnErr = LPL.TalentAPI:LearnTalent(tabIndex, talent.talentIndex)
                    if not okLearn then
                        if onDone then
                            onDone(false, learnErr)
                        end
                        return false, learnErr
                    end
                    learned = learned + 1
                    progressed = true
                end
            end
        end
        if not progressed then
            break
        end
    end

    local matches = RankMatches(draft, talentGroup)
    local summary = LPL.TalentAPI:SummarizeBuild(draft)
    if matches then
        local msg = string.format("Talents applied (%s).", summary)
        if LPL.ActivateFeedback then
            LPL.ActivateFeedback:Speak(msg)
            LPL.ActivateFeedback:Play(summary)
        else
            print("|cff33cc33LPL:|r " .. msg)
        end
        if onDone then
            onDone(true)
        end
        return true
    end

    local msg = string.format(
        "Applied %d talent ranks toward %s. Open the Blizzard talent UI if anything is still missing.",
        learned,
        summary
    )
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Speak(msg)
        if learned > 0 then
            LPL.ActivateFeedback:Play(summary)
        end
    else
        print("|cffffcc00LPL:|r " .. msg)
    end
    if onDone then
        onDone(learned > 0, msg)
    end
    return learned > 0, msg
end

function LPL.TalentActivate:ApplySet(buildID, onDone)
    local build = LPL.TalentStore:Get(buildID)
    if not build then
        local err = "Talent build not found."
        if onDone then
            onDone(false, err)
        end
        return false, err
    end
    return self:ApplyDraft(build, onDone)
end

-- Alias used by LoadoutActivate
function LPL.TalentActivate:ApplyBuild(buildID, onDone)
    return self:ApplySet(buildID, onDone)
end

function LPL.TalentActivate:IsActive(build)
    if type(build) ~= "table" then
        return false
    end
    local playerClass = LPL.TalentAPI:GetPlayerClassID()
    if build.classID and playerClass and tonumber(build.classID) ~= playerClass then
        return false
    end
    return RankMatches(build, LPL.TalentAPI:GetActiveTalentGroup())
end
