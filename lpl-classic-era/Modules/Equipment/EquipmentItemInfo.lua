local addonName, LPL = ...

LPL.EquipmentItemInfo = {}

local scanTooltip

local GetItemGem = C_Item and C_Item.GetItemGem or _G.GetItemGem
local GetDetailedItemLevelInfo = C_Item and C_Item.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
local GetItemUniquenessByID = C_Item and C_Item.GetItemUniquenessByID
local GetItemQualityByID = C_Item and C_Item.GetItemQualityByID
local GetItemQualityColor = C_Item and C_Item.GetItemQualityColor or _G.GetItemQualityColor

local function PlainLink(link)
    if not link then
        return nil
    end
    if LPL.PlainString then
        return LPL:PlainString(link)
    end
    return link
end

local function EnsureScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "LPLEquipmentScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTooltip
end

local function ParseItemLinkFields(itemLink)
    if not itemLink then
        return nil
    end
    local itemString = itemLink:match("item:([%-%d:]+)")
    if not itemString then
        return nil
    end
    local fields = { strsplit(":", itemString) }
    return {
        itemID = tonumber(fields[1]),
        enchantID = tonumber(fields[2]),
    }
end

local function StripEnchantPrefix(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:match("^Enchants?ed:%s*(.+)$") or text
    if LPL.PlainString then
        text = LPL:PlainString(text) or text
    end
    return text
end

local function IsStatLine(text)
    if type(text) ~= "string" or text == "" then
        return false
    end
    return text:match("^%+") ~= nil
        or text:match("^%-%d") ~= nil
        or text:match("^Increases") ~= nil
        or text:match("^Grant") ~= nil
end

local function IsEnchantNameLine(text, r, g, b)
    if type(text) ~= "string" or text == "" then
        return false
    end
    if IsStatLine(text) then
        return false
    end
    if text:match("^Item Level")
        or text:match("^Requires")
        or text:match("^Equip:")
        or text:match("^Use:")
        or text:match("^Set:")
        or text:match("^<")
        or text:match("Socket")
        or text:match("Prismatic")
        or text:match("^Durability")
        or text:match("^Classes:")
        or text:match("^Unique")
        or text:match("^Bind") then
        return false
    end
    if text:match("^Enchants?ed:") then
        return true
    end
    if r and g and b and g > 0.75 and r < 0.65 and b < 0.85 then
        return true
    end
    return false
end

local function GetEnchantNameFromID(enchantID)
    enchantID = tonumber(enchantID)
    if not enchantID or enchantID < 1 then
        return nil
    end

    local tip = EnsureScanTooltip()
    tip:ClearLines()
    tip:SetHyperlink("enchant:" .. enchantID)
    local left = _G["LPLEquipmentScanTooltipTextLeft1"]
    local name = left and left:GetText()
    name = StripEnchantPrefix(name)
    if name and name ~= "" then
        return name
    end
    return nil
end

local function ScanTooltipEnchantLines(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil, {}
    end

    local tip = EnsureScanTooltip()
    tip:ClearLines()
    tip:SetHyperlink(itemLink)

    local name
    local details = {}

    for i = 2, tip:NumLines() do
        local left = _G["LPLEquipmentScanTooltipTextLeft" .. i]
        if left then
            local text = left:GetText()
            local r, g, b = left:GetTextColor()
            if LPL.PlainString then
                text = LPL:PlainString(text) or text
            end
            if type(text) == "string" and text ~= "" then
                if IsStatLine(text) then
                    details[#details + 1] = text
                elseif IsEnchantNameLine(text, r, g, b) then
                    local parsed = StripEnchantPrefix(text)
                    if parsed and parsed ~= "" then
                        name = name or parsed
                    end
                end
            end
        end
    end

    return name, details
end

function LPL.EquipmentItemInfo:GetEnchantInfo(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil, nil
    end

    local fields = ParseItemLinkFields(itemLink)
    local name = fields and GetEnchantNameFromID(fields.enchantID)
    local scanName, details = ScanTooltipEnchantLines(itemLink)

    name = name or scanName
    if details and #details == 0 then
        details = nil
    end

    if not name and not details then
        return nil, nil
    end

    return name, details
end

function LPL.EquipmentItemInfo:GetEnchantText(itemLink)
    local name = self:GetEnchantInfo(itemLink)
    return name
end

local UPGRADE_LINE_TYPE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemUpgradeLevel) or 32
local upgradeTooltipCapturePattern

local function StripTooltipColorCodes(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if LPL.PlainString then
        text = LPL:PlainString(text) or text
    end
    return text
end

local function SurfaceTooltipData(data)
    if not data or type(data) ~= "table" then
        return
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
        if data.lines then
            for _, line in ipairs(data.lines) do
                if type(line) == "table" then
                    pcall(TooltipUtil.SurfaceArgs, line)
                end
            end
        end
    end
end

local function GetUpgradeTooltipCapturePattern()
    if upgradeTooltipCapturePattern then
        return upgradeTooltipCapturePattern
    end

    if ITEM_UPGRADE_TOOLTIP_FORMAT_STRING then
        local pattern = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
        pattern = pattern:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
        pattern = pattern:gsub("%%s", "(.+)")
        pattern = pattern:gsub("%%d", "(%%d+)")
        upgradeTooltipCapturePattern = "^" .. pattern
    else
        upgradeTooltipCapturePattern = "^Upgrade Level: (.+) (%d+)/(%d+)"
    end

    return upgradeTooltipCapturePattern
end

local function NormalizeUpgradeTrackName(trackString)
    trackString = StripTooltipColorCodes(trackString)
    if not trackString then
        return nil
    end
    trackString = trackString:gsub("|A.-|a", ""):gsub("|T.-|t", "")
    trackString = trackString:match("^%s*(.-)%s*$")
    if not trackString or trackString == "" then
        return nil
    end
    return trackString
end

local function BuildUpgradeInfo(trackString, currentLevel, maxLevel)
    trackString = NormalizeUpgradeTrackName(trackString)
    currentLevel = tonumber(currentLevel)
    maxLevel = tonumber(maxLevel)

    if not trackString or not currentLevel or not maxLevel then
        return nil
    end
    if maxLevel < 1 or maxLevel > 24 or currentLevel < 0 or currentLevel > maxLevel then
        return nil
    end

    return {
        trackString = trackString,
        currentLevel = currentLevel,
        maxLevel = maxLevel,
    }
end

local function ParseUpgradeLineText(text)
    text = StripTooltipColorCodes(text)
    if not text or text == "" then
        return nil
    end
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", "")

    local trackString, currentLevel, maxLevel = text:match(GetUpgradeTooltipCapturePattern())
    if not trackString or not currentLevel or not maxLevel then
        return nil
    end

    return BuildUpgradeInfo(trackString, currentLevel, maxLevel)
end

local function GetUpgradeInfoFromTooltipData(tooltipData)
    if not tooltipData or not tooltipData.lines then
        return nil
    end

    SurfaceTooltipData(tooltipData)

    for _, line in ipairs(tooltipData.lines) do
        if line and (line.type == UPGRADE_LINE_TYPE or tonumber(line.type) == UPGRADE_LINE_TYPE) then
            local info = ParseUpgradeLineText(line.leftText)
            if info then
                return info
            end
        end
    end

    for index = 1, math.min(#tooltipData.lines, 6) do
        local line = tooltipData.lines[index]
        if line and line.leftText then
            local info = ParseUpgradeLineText(line.leftText)
            if info then
                return info
            end
        end
    end

    return nil
end

local function GetUpgradeInfoFromTooltipAPI(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return nil
    end

    local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if ok and tooltipData then
        return GetUpgradeInfoFromTooltipData(tooltipData)
    end

    return nil
end

local function GetUpgradeInfoFromScanTooltip(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil
    end

    local tip = EnsureScanTooltip()
    tip:ClearLines()
    tip:SetHyperlink(itemLink)

    for index = 1, math.min(tip:NumLines(), 6) do
        local left = _G["LPLEquipmentScanTooltipTextLeft" .. index]
        if left and left.GetText then
            local info = ParseUpgradeLineText(left:GetText())
            if info then
                return info
            end
        end
    end

    return nil
end

function LPL.EquipmentItemInfo:GetUpgradeInfo(itemLink)
    return nil
end

function LPL.EquipmentItemInfo:GetUpgradeText(itemLink)
    return nil
end

function LPL.EquipmentItemInfo:GetItemLevel(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil
    end
    if GetDetailedItemLevelInfo then
        return GetDetailedItemLevelInfo(itemLink)
    end
    return nil
end

function LPL.EquipmentItemInfo:GetGemEntries(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink or not GetItemGem then
        return {}
    end

    local gems = {}
    local index = 1
    local gemName, gemLink = GetItemGem(itemLink, index)
    while gemName do
        local icon
        if gemLink then
            if GetItemIcon then
                icon = GetItemIcon(gemLink)
            end
            if not icon and C_Item and C_Item.GetItemIconByID then
                local gemID = tonumber((PlainLink(gemLink) or ""):match("item:(%d+)"))
                if gemID then
                    icon = C_Item.GetItemIconByID(gemID)
                end
            end
        end
        if LPL.PlainString then
            gemName = LPL:PlainString(gemName) or gemName
        end
        gems[#gems + 1] = {
            name = gemName,
            link = gemLink,
            icon = icon,
        }
        index = index + 1
        gemName, gemLink = GetItemGem(itemLink, index)
    end
    return gems
end

function LPL.EquipmentItemInfo:GetUniqueFamily(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil, nil
    end

    if GetItemUniquenessByID then
        local isUnique, _, limitCategoryCount, limitCategoryID = GetItemUniquenessByID(itemLink)
        if isUnique then
            local family = limitCategoryID
            if family == -1 then
                family = tonumber(itemLink:match("item:(%d+)")) or itemLink
            end
            local maxEquipped = limitCategoryCount or 1
            return family, maxEquipped
        end
        return nil, nil
    end

    if GetItemUniqueness then
        local isUnique, _, limitCategoryCount, limitCategoryID = GetItemUniqueness(itemLink)
        if isUnique then
            local family = limitCategoryID
            if family == -1 then
                family = tonumber(itemLink:match("item:(%d+)")) or itemLink
            end
            return family, limitCategoryCount or 1
        end
    end

    return nil, nil
end

local function GetItemIDFromLink(itemLink)
    if not itemLink then
        return nil
    end
    return tonumber(itemLink:match("item:(%d+)"))
end

function LPL.EquipmentItemInfo:GetItemQuality(itemLink)
    itemLink = PlainLink(itemLink)
    if not itemLink then
        return nil
    end

    local quality = tonumber(itemLink:match("|cnIQ(%d+)"))
    if quality then
        return quality
    end

    local itemID = GetItemIDFromLink(itemLink)
    if itemID and GetItemQualityByID then
        quality = GetItemQualityByID(itemID)
        if type(quality) == "number" then
            return quality
        end
    end

    if GetItemInfoInstant then
        local instantQuality = select(3, GetItemInfoInstant(itemLink))
        if type(instantQuality) == "number" then
            return instantQuality
        end
        if itemID then
            instantQuality = select(3, GetItemInfoInstant(itemID))
            if type(instantQuality) == "number" then
                return instantQuality
            end
        end
    end

    return nil
end

function LPL.EquipmentItemInfo:GetItemQualityColor(itemLink)
    local quality = self:GetItemQuality(itemLink)
    if type(quality) == "number" and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end
    return LPL.Theme:GetColor("textBright")
end

function LPL.EquipmentItemInfo:EnrichEntry(entry, itemLink)
    if type(entry) ~= "table" or entry.cleared then
        return entry
    end

    itemLink = PlainLink(itemLink or entry.link)
    if not itemLink and entry.itemID and C_Item and C_Item.GetItemLinkByID then
        itemLink = PlainLink(C_Item.GetItemLinkByID(entry.itemID))
    end
    if not itemLink then
        entry.enchantText = nil
        entry.enchantName = nil
        entry.enchantDetails = nil
        entry.upgrade = nil
        entry.upgradeText = nil
        entry.gems = nil
        entry.itemLevel = nil
        entry._lplEnriched = nil
        entry._lplEnrichedLink = nil
        return entry
    end

    entry.link = itemLink
    entry.itemLevel = self:GetItemLevel(itemLink)
    entry.enchantName, entry.enchantDetails = self:GetEnchantInfo(itemLink)
    entry.enchantText = entry.enchantName
    entry.upgrade = self:GetUpgradeInfo(itemLink)
    entry.upgradeText = self:GetUpgradeText(itemLink)
    entry.gems = self:GetGemEntries(itemLink)
    if entry.gems and #entry.gems == 0 then
        entry.gems = nil
    end
    return entry
end

function LPL.EquipmentItemInfo:EnsureEntryEnriched(entry)
    if type(entry) ~= "table" or entry.cleared or not entry.itemID then
        return entry
    end

    local itemLink = PlainLink(entry.link)
    if not itemLink and entry.itemID and C_Item and C_Item.GetItemLinkByID then
        itemLink = PlainLink(C_Item.GetItemLinkByID(entry.itemID))
    end

    if entry._lplEnriched and entry._lplEnrichedLink == itemLink then
        return entry
    end

    self:EnrichEntry(entry, itemLink)
    entry._lplEnriched = true
    entry._lplEnrichedLink = itemLink
    return entry
end

function LPL.EquipmentItemInfo:ApplyUniqueLimits(runtime)
    if type(runtime) ~= "table" then
        return
    end

    local budget = {}
    local slotsByFamily = {}

    for inventorySlotId, itemLink in pairs(runtime.equipment or {}) do
        if not runtime.ignored[inventorySlotId] and itemLink then
            local function RegisterLink(link)
                local family, maxEquipped = self:GetUniqueFamily(link)
                if family then
                    budget[family] = budget[family] or maxEquipped
                    slotsByFamily[family] = slotsByFamily[family] or {}
                    slotsByFamily[family][#slotsByFamily[family] + 1] = inventorySlotId
                end
            end

            RegisterLink(itemLink)
            if GetItemGem then
                local index = 1
                local _, gemLink = GetItemGem(itemLink, index)
                while gemLink do
                    RegisterLink(gemLink)
                    index = index + 1
                    _, gemLink = GetItemGem(itemLink, index)
                end
            end
        end
    end

    for family, slots in pairs(slotsByFamily) do
        local maxEquipped = budget[family] or 1
        if #slots > maxEquipped then
            table.sort(slots)
            for index = maxEquipped + 1, #slots do
                local slotID = slots[index]
                runtime.ignored[slotID] = true
                runtime.equipment[slotID] = nil
                runtime.locations[slotID] = nil
            end
        end
    end
end
