--[[
  AllQuest — Kaliel-style right-click tracker menu
  MenuUtil on modern Retail; EasyMenu / UIDropDownMenu on Classic.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Menu = AQ.Menu or {}
local Menu = AQ.Menu

local drop

local function EnsurePopup()
    StaticPopupDialogs = StaticPopupDialogs or {}
    if StaticPopupDialogs["ALLQUEST_URL"] then
        return
    end
    StaticPopupDialogs["ALLQUEST_URL"] = {
        text = "Wowhead URL (copy this)",
        button1 = "Close",
        hasEditBox = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function(self, data)
            local box = self.EditBox or self.editBox
            if not box and self.GetName then
                box = _G[self:GetName() .. "EditBox"]
            end
            if box and data then
                box:SetText(data)
                box:HighlightText()
                box:SetFocus()
            end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
end

function Menu.ShowURL(url)
    if type(url) ~= "string" or url == "" then
        return
    end
    if CopyToClipboard then
        pcall(CopyToClipboard, url)
    end
    EnsurePopup()
    if StaticPopup_Show then
        local shown = StaticPopup_Show("ALLQUEST_URL", nil, nil, url)
        if shown then
            local box = shown.EditBox or shown.editBox
            if not box and shown.GetName then
                box = _G[shown:GetName() .. "EditBox"]
            end
            if box then
                box:SetText(url)
                box:HighlightText()
                if box.SetFocus then
                    box:SetFocus()
                end
            end
        end
    end
    AQ:Print(url)
    if AQ.Speech then
        AQ.Speech.Say("Wowhead URL copied")
    end
end

local function AfterRefresh()
    local function go()
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, go)
    else
        go()
    end
end

local function Add(items, text, fn)
    items[#items + 1] = {
        text = text,
        func = function()
            if type(fn) == "function" then
                pcall(fn)
            end
        end,
        notCheckable = true,
    }
end

local function Title(items, text)
    items[#items + 1] = { text = text or "", isTitle = true, notCheckable = true }
end

local function BuildItems(data)
    local items = {}
    if type(data) ~= "table" then
        return items
    end
    local name = data.title or "AllQuest"
    name = name:gsub("^|T.-|t%s*", "")
    Title(items, name)

    if data.achievementID then
        local id = data.achievementID
        Add(items, "Open Achievement", function()
            AQ.Compat.OpenAchievement(id)
        end)
        Add(items, "Stop Tracking", function()
            AQ.Compat.UntrackAchievement(id)
            if AQ.Tracker and AQ.Tracker.Suppress then
                AQ.Tracker.Suppress("achievement", id)
            end
            AfterRefresh()
            if AQ.Speech then
                AQ.Speech.Say("Stopped tracking achievement")
            end
        end)
        Add(items, "Wowhead URL", function()
            Menu.ShowURL(AQ.Compat.WowheadURL("achievement", id))
        end)
        return items
    end

    if data.recipeID then
        local id = data.recipeID
        Add(items, "Stop Tracking", function()
            if C_TradeSkillUI and C_TradeSkillUI.SetRecipeTracked then
                pcall(C_TradeSkillUI.SetRecipeTracked, id, false, false)
                pcall(C_TradeSkillUI.SetRecipeTracked, id, false, true)
            end
            if AQ.Tracker and AQ.Tracker.Suppress then
                AQ.Tracker.Suppress("recipe", id)
            end
            AfterRefresh()
        end)
        Add(items, "Wowhead URL", function()
            Menu.ShowURL(AQ.Compat.WowheadURL("recipe", id))
        end)
        return items
    end

    if data.activityID then
        local id = data.activityID
        Add(items, "Stop Tracking", function()
            if C_PerksActivities then
                if C_PerksActivities.RemoveTrackedPerksActivity then
                    pcall(C_PerksActivities.RemoveTrackedPerksActivity, id)
                end
                if C_PerksActivities.SetPerksActivityTracked then
                    pcall(C_PerksActivities.SetPerksActivityTracked, id, false)
                end
            end
            if AQ.Tracker and AQ.Tracker.Suppress then
                AQ.Tracker.Suppress("activity", id)
            end
            AfterRefresh()
        end)
        return items
    end

    if data.collectibleID then
        local id = data.collectibleID
        local trackType = data.collectibleType
        Add(items, "Stop Tracking", function()
            AQ.Compat.UntrackContent(trackType, id)
            if AQ.Tracker and AQ.Tracker.Suppress then
                AQ.Tracker.Suppress("collectible", id)
            end
            AfterRefresh()
        end)
        return items
    end

    if data.questID then
        local id = data.questID
        local tracked = AQ.Compat.GetSuperTrackedQuestID()
        if tracked == id then
            Add(items, "Stop Super Tracking", function()
                AQ.Compat.ClearSuperTrack()
                AfterRefresh()
                if AQ.Speech then
                    AQ.Speech.Say("Stopped super-tracking")
                end
            end)
        else
            Add(items, "Super Track Quest", function()
                AQ.Compat.SuperTrackQuest(id)
                AfterRefresh()
                if AQ.Speech then
                    AQ.Speech.Say("Super-tracking " .. name)
                end
            end)
        end
        Add(items, "View in Quest Log", function()
            AQ.Compat.OpenQuestDetails(id)
        end)
        Add(items, "Show on Map", function()
            AQ.Compat.ShowQuestOnMap(id)
        end)
        if AQ.Journal and AQ.Journal.OpenQuest then
            Add(items, "Open Questline Journal", function()
                AQ.Journal.OpenQuest(id)
            end)
        end
        if AQ.BtWQuests and AQ.Plugins and AQ.Plugins.IsEnabled("BtWQuests") and AQ.BtWQuests.HasChain and AQ.BtWQuests.HasChain(id) then
            Add(items, "Open in BtWQuests", function()
                AQ.BtWQuests.OpenChain(id)
            end)
        end
        Add(items, "Stop Tracking", function()
            if data.isWorldQuest then
                AQ.Compat.RemoveWorldQuestWatch(id)
            else
                AQ.Compat.RemoveQuestWatch(id)
            end
            if AQ.Tracker and AQ.Tracker.Suppress then
                AQ.Tracker.Suppress("quest", id)
            end
            AfterRefresh()
            if AQ.Speech then
                AQ.Speech.Say("Stopped tracking")
            end
        end)
        if AQ.Compat.CanShareQuest(id) then
            Add(items, "Share Quest", function()
                AQ.Compat.ShareQuest(id)
                if AQ.Speech then
                    AQ.Speech.Say("Sharing quest")
                end
            end)
        end
        Add(items, "Abandon Quest", function()
            AQ.Compat.PromptAbandonQuest(id)
        end)
        Add(items, "Wowhead URL", function()
            Menu.ShowURL(AQ.Compat.WowheadURL("quest", id))
        end)
        if TomTom and AQ.Plugins and AQ.Plugins.IsEnabled("TomTom") and AQ.TomTom and AQ.TomTom.WaypointForQuest then
            Add(items, "TomTom Arrow", function()
                AQ.TomTom.WaypointForQuest(id, name)
            end)
        end
        return items
    end

    if (data.rareMapID and data.rareX and data.rareY) or (data.petMapID and data.petX and data.petY) then
        if TomTom and AQ.Plugins and AQ.Plugins.IsEnabled("TomTom") and AQ.TomTom and AQ.TomTom.AddPoint then
            Add(items, "TomTom Arrow", function()
                if data.rareMapID then
                    AQ.TomTom.AddPoint(data.rareMapID, data.rareX, data.rareY, name)
                else
                    AQ.TomTom.AddPoint(data.petMapID, data.petX, data.petY, name)
                end
            end)
        end
    end
    return items
end

local function ShowEasy(items)
    if not drop then
        drop = CreateFrame("Frame", "AllQuestDropDownMenu", UIParent, "UIDropDownMenuTemplate")
    end
    if EasyMenu then
        EasyMenu(items, drop, "cursor", 0, 0, "MENU", 1)
        return
    end
    if ToggleDropDownMenu and UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(drop, function()
            for i = 1, #items do
                local info = UIDropDownMenu_CreateInfo()
                local it = items[i]
                info.text = it.text
                info.notCheckable = true
                info.isTitle = it.isTitle
                info.func = it.func
                UIDropDownMenu_AddButton(info, 1)
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, drop, "cursor", 0, 0)
    end
end

function Menu.Show(owner, data)
    local items = BuildItems(data)
    if #items <= 1 then
        return false
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for i = 1, #items do
                local it = items[i]
                if it.isTitle then
                    root:CreateTitle(it.text)
                else
                    local fn = it.func
                    root:CreateButton(it.text, function()
                        if type(fn) == "function" then
                            pcall(fn)
                        end
                    end)
                end
            end
        end)
        return true
    end
    ShowEasy(items)
    return true
end
