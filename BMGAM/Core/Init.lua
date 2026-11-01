local _, BMGAM = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
frame:RegisterEvent("BANK_TABS_CHANGED")
frame:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
frame:RegisterEvent("GUILDBANK_UPDATE_TABS")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
frame:RegisterEvent("MAJOR_FACTION_UNLOCKED")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("MAIL_SEND_SUCCESS")
frame:RegisterEvent("MAIL_FAILED")
frame:RegisterEvent("UPDATE_PENDING_MAIL")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
frame:RegisterEvent("BIDS_UPDATED")
frame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
frame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
frame:RegisterEvent("AUCTION_CANCELED")
frame:RegisterEvent("AUCTION_HOUSE_NEW_BID_RECEIVED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
frame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")

local loaded = false

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "BMGAM" then
            return
        end
        loaded = true
        BMGAM.DB.Init()
        BMGAM.Minimap.Refresh()
        return
    end
    if not loaded then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        BMGAM.Scan.OnEnteringWorld()
        return
    end
    if event == "BAG_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnBags then
            BMGAM.Scan.OnBags()
        end
        return
    end
    if event == "BANKFRAME_OPENED" then
        if BMGAM.Scan and BMGAM.Scan.OnBank then
            BMGAM.Scan.OnBank(true)
        end
        return
    end
    if event == "BANKFRAME_CLOSED" then
        if BMGAM.Scan and BMGAM.Scan.OnBank then
            BMGAM.Scan.OnBank(false)
        end
        return
    end
    if event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        if BMGAM.Scan and BMGAM.Scan.ReadOpenBank then
            BMGAM.Scan.ReadOpenBank()
        end
        return
    end
    if event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANK_UPDATE_TABS" then
        if BMGAM.Scan and BMGAM.Scan.OnGuildBank then
            BMGAM.Scan.OnGuildBank(true)
        end
        return
    end
    if event == "GUILDBANKFRAME_CLOSED" then
        if BMGAM.Scan and BMGAM.Scan.OnGuildBank then
            BMGAM.Scan.OnGuildBank(false)
        end
        return
    end
    if event == "GUILDBANKBAGSLOTS_CHANGED" then
        if BMGAM.Scan and BMGAM.Scan.ReadOpenGuildBank then
            BMGAM.Scan.ReadOpenGuildBank()
        end
        return
    end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local opened = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        local banker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
        local guild = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
        local isBank = false
        local isGuild = false
        if banker ~= nil then
            local ok, match = pcall(function()
                return arg1 == banker
            end)
            isBank = ok and match
        end
        if guild ~= nil then
            local ok, match = pcall(function()
                return arg1 == guild
            end)
            isGuild = ok and match
        end
        local mailer = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
        local isMail = false
        if mailer ~= nil then
            local ok, match = pcall(function()
                return arg1 == mailer
            end)
            isMail = ok and match
        end
        local auctioneer = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Auctioneer
        local isAuction = false
        if auctioneer ~= nil then
            local ok, match = pcall(function()
                return arg1 == auctioneer
            end)
            isAuction = ok and match
        end
        if isBank and BMGAM.Scan and BMGAM.Scan.OnBank then
            BMGAM.Scan.OnBank(opened)
        elseif isGuild and BMGAM.Scan and BMGAM.Scan.OnGuildBank then
            BMGAM.Scan.OnGuildBank(opened)
        elseif isMail and BMGAM.Scan and BMGAM.Scan.OnMailbox then
            BMGAM.Scan.OnMailbox(opened)
        elseif isAuction and BMGAM.Scan and BMGAM.Scan.OnAuctionHouse then
            BMGAM.Scan.OnAuctionHouse(opened)
        end
        return
    end
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnProfession then
            BMGAM.Scan.OnProfession()
        end
        return
    end
    if event == "MAIL_SHOW" then
        if BMGAM.Scan and BMGAM.Scan.OnMailbox then
            BMGAM.Scan.OnMailbox(true)
        end
        return
    end
    if event == "MAIL_CLOSED" then
        if BMGAM.Scan and BMGAM.Scan.OnMailbox then
            BMGAM.Scan.OnMailbox(false)
        end
        return
    end
    if event == "MAIL_INBOX_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnInboxUpdate then
            BMGAM.Scan.OnInboxUpdate()
        end
        return
    end
    if event == "MAIL_SEND_SUCCESS" then
        if BMGAM.Scan and BMGAM.Scan.OnMailSent then
            BMGAM.Scan.OnMailSent()
        end
        return
    end
    if event == "MAIL_FAILED" then
        if BMGAM.Scan and BMGAM.Scan.OnMailFailed then
            BMGAM.Scan.OnMailFailed()
        end
        return
    end
    if event == "AUCTION_HOUSE_SHOW" then
        if BMGAM.Scan and BMGAM.Scan.OnAuctionHouse then
            BMGAM.Scan.OnAuctionHouse(true)
        end
        return
    end
    if event == "AUCTION_HOUSE_CLOSED" then
        if BMGAM.Scan and BMGAM.Scan.OnAuctionHouse then
            BMGAM.Scan.OnAuctionHouse(false)
        end
        return
    end
    if event == "OWNED_AUCTIONS_UPDATED" then
        if BMGAM.Scan and BMGAM.Scan.OnOwnedAuctions then
            BMGAM.Scan.OnOwnedAuctions()
        end
        return
    end
    if event == "BIDS_UPDATED" then
        if BMGAM.Scan and BMGAM.Scan.OnBidsUpdated then
            BMGAM.Scan.OnBidsUpdated()
        end
        return
    end
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if BMGAM.Scan and BMGAM.Scan.OnAuctionThrottle then
            BMGAM.Scan.OnAuctionThrottle()
        end
        return
    end
    if event == "AUCTION_HOUSE_AUCTION_CREATED" or event == "AUCTION_CANCELED" or event == "AUCTION_HOUSE_NEW_BID_RECEIVED" then
        if BMGAM.Scan and BMGAM.Scan.OnAuctionChanged then
            BMGAM.Scan.OnAuctionChanged()
        end
        return
    end
    if event == "QUEST_LOG_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnQuests then
            BMGAM.Scan.OnQuests(false)
        end
        return
    end
    if event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        if BMGAM.Scan and BMGAM.Scan.OnQuests then
            BMGAM.Scan.OnQuests(true)
        end
        return
    end
    if event == "QUEST_TURNED_IN" then
        if BMGAM.Scan and BMGAM.Scan.OnQuestTurnedIn then
            BMGAM.Scan.OnQuestTurnedIn(arg1)
        end
        return
    end
    if event == "QUEST_DATA_LOAD_RESULT" then
        if BMGAM.Scan and BMGAM.Scan.OnQuestData then
            BMGAM.Scan.OnQuestData(arg1)
        end
        if BMGAM.Quests and BMGAM.Quests.OnQuestData then
            BMGAM.Quests.OnQuestData(arg1)
        end
        return
    end
    if event == "UPDATE_PENDING_MAIL" then
        if BMGAM.Scan and BMGAM.Scan.ReadMailNotice then
            BMGAM.Scan.ReadMailNotice()
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
        return
    end
    if event == "UPDATE_FACTION" or event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event == "MAJOR_FACTION_UNLOCKED" then
        if BMGAM.Scan and BMGAM.Scan.ReadReputations then
            pcall(BMGAM.Scan.ReadReputations)
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
        return
    end
    if event == "CURRENCY_DISPLAY_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.ReadCurrencies then
            pcall(BMGAM.Scan.ReadCurrencies)
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
        return
    end
    if event == "SKILL_LINES_CHANGED" then
        if BMGAM.Scan and BMGAM.Scan.ReadProfessionList then
            pcall(BMGAM.Scan.ReadProfessionList)
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
        return
    end
    if event == "WEEKLY_REWARDS_UPDATE" then
        if BMGAM.Vault and BMGAM.Vault.Read then
            pcall(BMGAM.Vault.Read)
        end
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_MONEY" or event == "PLAYER_GUILD_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" or event == "TRAIT_SUB_TREE_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        BMGAM.Scan.OnUpdate()
    end
end)

SLASH_BMGAM1 = "/bmgam"
SlashCmdList.BMGAM = function()
    if BMGAM.Window and BMGAM.Window.Toggle then
        BMGAM.Window.Toggle()
    end
end

SLASH_BMGAMREAD1 = "/avread"
SlashCmdList.BMGAMREAD = function()
    if BMGAM.Read and BMGAM.Read.UnderMouse then
        BMGAM.Read.UnderMouse()
    end
end

function BMGAM_OnAddonCompartmentClick()
    if BMGAM.Window and BMGAM.Window.Toggle then
        BMGAM.Window.Toggle()
    end
end
