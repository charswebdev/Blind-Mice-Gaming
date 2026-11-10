local _, BMGAM = ...

local frame = CreateFrame("Frame")

local function Listen(event)
    pcall(frame.RegisterEvent, frame, event)
end

Listen("ADDON_LOADED")
Listen("PLAYER_ENTERING_WORLD")
Listen("PLAYER_MONEY")
Listen("PLAYER_EQUIPMENT_CHANGED")
Listen("BAG_UPDATE")
Listen("BANKFRAME_OPENED")
Listen("BANKFRAME_CLOSED")
Listen("PLAYERBANKSLOTS_CHANGED")
Listen("BANK_TABS_CHANGED")
Listen("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
Listen("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
Listen("GUILDBANKFRAME_OPENED")
Listen("GUILDBANKFRAME_CLOSED")
Listen("GUILDBANKBAGSLOTS_CHANGED")
Listen("GUILDBANK_UPDATE_TABS")
Listen("PLAYER_GUILD_UPDATE")
Listen("PLAYER_TALENT_UPDATE")
Listen("CHARACTER_POINTS_CHANGED")
Listen("PLAYER_LEVEL_UP")
Listen("PLAYER_AVG_ITEM_LEVEL_UPDATE")
Listen("TRAIT_CONFIG_UPDATED")
Listen("TRAIT_CONFIG_LIST_UPDATED")
Listen("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
Listen("PLAYER_SPECIALIZATION_CHANGED")
Listen("TRADE_SKILL_SHOW")
Listen("TRADE_SKILL_LIST_UPDATE")
Listen("SKILL_LINES_CHANGED")
Listen("CURRENCY_DISPLAY_UPDATE")
Listen("UPDATE_FACTION")
Listen("MAIL_SHOW")
Listen("MAIL_CLOSED")
Listen("MAIL_INBOX_UPDATE")
Listen("MAIL_SEND_SUCCESS")
Listen("MAIL_FAILED")
Listen("UPDATE_PENDING_MAIL")
Listen("AUCTION_HOUSE_SHOW")
Listen("AUCTION_HOUSE_CLOSED")
Listen("OWNED_AUCTIONS_UPDATED")
Listen("BIDS_UPDATED")
Listen("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Listen("AUCTION_HOUSE_AUCTION_CREATED")
Listen("AUCTION_CANCELED")
Listen("AUCTION_HOUSE_NEW_BID_RECEIVED")
Listen("AUCTION_OWNED_LIST_UPDATE")
Listen("AUCTION_BIDDER_LIST_UPDATE")
Listen("QUEST_LOG_UPDATE")
Listen("QUEST_ACCEPTED")
Listen("QUEST_REMOVED")
Listen("QUEST_TURNED_IN")
Listen("ACHIEVEMENT_EARNED")
Listen("NEW_MOUNT_ADDED")
Listen("COMPANION_LEARNED")
Listen("PET_JOURNAL_LIST_UPDATE")
Listen("TOYS_UPDATED")
Listen("HEIRLOOMS_UPDATED")
Listen("TRANSMOG_COLLECTION_UPDATED")
Listen("TRANSMOG_COLLECTION_SOURCE_ADDED")

local loaded = false

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "BMGAM-forever" then
            return
        end
        loaded = true
        BMGAM.DB.Init()
        if BMGAM.Minimap and BMGAM.Minimap.Refresh then
            BMGAM.Minimap.Refresh()
        end
        return
    end
    if not loaded then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        BMGAM.Scan.OnEnteringWorld()
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" and BMGAM.Scan.OnEquip then
        BMGAM.Scan.OnEquip()
        return
    end
    if event == "BAG_UPDATE" and BMGAM.Scan.OnBags then
        BMGAM.Scan.OnBags()
        return
    end
    if event == "BANKFRAME_OPENED" and BMGAM.Scan.OnBank then
        BMGAM.Scan.OnBank(true)
        return
    end
    if event == "BANKFRAME_CLOSED" and BMGAM.Scan.OnBank then
        BMGAM.Scan.OnBank(false)
        return
    end
    if event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        if BMGAM.Scan.ReadOpenBank then
            BMGAM.Scan.ReadOpenBank()
        end
        return
    end
    if event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANK_UPDATE_TABS" then
        if BMGAM.Scan.OnGuildBank then
            BMGAM.Scan.OnGuildBank(true)
        end
        return
    end
    if event == "GUILDBANKFRAME_CLOSED" and BMGAM.Scan.OnGuildBank then
        BMGAM.Scan.OnGuildBank(false)
        return
    end
    if event == "GUILDBANKBAGSLOTS_CHANGED" and BMGAM.Scan.ReadOpenGuildBank then
        BMGAM.Scan.ReadOpenGuildBank()
        return
    end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local opened = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        local banker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
        local guild = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
        local mailer = Enum and Enum.PlayerInteractionType and (Enum.PlayerInteractionType.MailInfo or Enum.PlayerInteractionType.Mail)
        local auctioneer = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Auctioneer
        local isBank = false
        local isGuild = false
        local isMail = false
        local isAuction = false
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
        if mailer ~= nil then
            local ok, match = pcall(function()
                return arg1 == mailer
            end)
            isMail = ok and match
        end
        if auctioneer ~= nil then
            local ok, match = pcall(function()
                return arg1 == auctioneer
            end)
            isAuction = ok and match
        end
        if isBank and BMGAM.Scan.OnBank then
            BMGAM.Scan.OnBank(opened)
        elseif isGuild and BMGAM.Scan.OnGuildBank then
            BMGAM.Scan.OnGuildBank(opened)
        elseif isMail and BMGAM.Scan.OnMailbox then
            BMGAM.Scan.OnMailbox(opened)
        elseif isAuction and BMGAM.Scan.OnAuctionHouse then
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
    if event == "UPDATE_PENDING_MAIL" then
        if BMGAM.Scan and BMGAM.Scan.ReadMailNotice then
            BMGAM.Scan.ReadMailNotice()
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
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
    if event == "AUCTION_OWNED_LIST_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnLegacyOwned then
            BMGAM.Scan.OnLegacyOwned()
        end
        return
    end
    if event == "AUCTION_BIDDER_LIST_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.OnLegacyBids then
            BMGAM.Scan.OnLegacyBids()
        end
        return
    end
    if event == "UPDATE_FACTION" then
        if BMGAM.Scan and BMGAM.Scan.ReadReputations then
            pcall(BMGAM.Scan.ReadReputations, true)
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end
        return
    end
    if event == "CURRENCY_DISPLAY_UPDATE" then
        if BMGAM.Scan and BMGAM.Scan.ReadCurrencies then
            pcall(BMGAM.Scan.ReadCurrencies)
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end
        return
    end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        if BMGAM.Scan and BMGAM.Scan.ReadQuests then
            pcall(BMGAM.Scan.ReadQuests, false)
        end
        return
    end
    if event == "QUEST_TURNED_IN" then
        if BMGAM.Scan and BMGAM.Scan.ReadQuests then
            pcall(BMGAM.Scan.ReadQuests, true)
        end
        return
    end
    if event == "ACHIEVEMENT_EARNED" then
        if BMGAM.Scan and BMGAM.Scan.ReadAchievements then
            pcall(BMGAM.Scan.ReadAchievements)
        end
        return
    end
    if event == "NEW_MOUNT_ADDED" or event == "COMPANION_LEARNED" or event == "PET_JOURNAL_LIST_UPDATE" or event == "TOYS_UPDATED" or event == "HEIRLOOMS_UPDATED" or event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_COLLECTION_SOURCE_ADDED" then
        if BMGAM.Scan and BMGAM.Scan.ReadCollections then
            pcall(BMGAM.Scan.ReadCollections)
        end
        return
    end
    if event == "SKILL_LINES_CHANGED" then
        if BMGAM.Scan and BMGAM.Scan.ReadProfessionList then
            pcall(BMGAM.Scan.ReadProfessionList)
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end
        return
    end
    BMGAM.Scan.OnUpdate()
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
