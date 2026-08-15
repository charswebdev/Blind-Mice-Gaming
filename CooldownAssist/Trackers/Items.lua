--[[
  Cooldown Assist — item / toy / hearthstone / equipped gear / consumable readiness
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Items = CA.Items or {}
local Items = CA.Items

local POLL_SEC = 1.0
local BAG_REFRESH_THROTTLE = 0.35
local TOY_CACHE_SEC = 60
local TOY_CHUNK = 35

local tracked = {}
local trackedByItemID = {}
local pendingCount = 0
local pollTicker = nil
local lastBagRefresh = 0
local lastItemFullRefresh = 0
local toyCache = nil
local toyCacheAt = 0
local scanQueued = false
local toyHarvestGen = 0
local toyHarvest = nil

local function CanUseNumber(v)
    if CA.Compat and CA.Compat.CanUseNumber then
        return CA.Compat.CanUseNumber(v)
    end
    return type(v) == "number"
end

local function MinCooldownSec()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local v = sv.minCooldownSeconds
    if type(v) ~= "number" or v < 0 then
        return 5
    end
    return v
end

local function SafeCall(fn, ...)
    if CA.Compat and CA.Compat.SafeCall then
        return CA.Compat.SafeCall(fn, ...)
    end
    if not fn then
        return
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return
    end
    return unpack(results, 2, #results)
end

local function SafeRegisterEvent(frame, event)
    if CA.Compat and CA.Compat.SafeRegisterEvent then
        return CA.Compat.SafeRegisterEvent(frame, event)
    end
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok and true or false
end

local function TrackerKey(kind, id)
    return tostring(kind) .. ":" .. tostring(id)
end

local function IsEnabledKey(key)
    if CA.DB and CA.DB.IsTrackerEnabled then
        return CA.DB.IsTrackerEnabled(key)
    end
    return true
end

local function CanAnnounceEntry(entry)
    if not entry or not IsEnabledKey(entry.key) then
        return false
    end
    local cat = entry.category or "general"
    if CA.Categories and CA.Categories.IsEnabled then
        return CA.Categories.IsEnabled(cat)
    end
    return true
end

local function GetItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local name = SafeCall(C_Item.GetItemNameByID, itemID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    if GetItemInfo then
        local name = SafeCall(GetItemInfo, itemID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "Item " .. tostring(itemID)
end

local function GetItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then
        local icon = SafeCall(C_Item.GetItemIconByID, itemID)
        if icon then
            return icon
        end
    end
    if GetItemIcon then
        local icon = SafeCall(GetItemIcon, itemID)
        if icon then
            return icon
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

--- Returns isActive, duration (if readable), enable
local function SafeFlagTrue(v)
    local ok, result = pcall(function()
        return v == true
    end)
    return ok and result and true or false
end

local function GetItemCooldownState(itemID)
    -- Prefer structured API when present (Midnight may include NeverSecret isActive).
    if C_Item and C_Item.GetItemCooldown then
        local a, b, c = SafeCall(C_Item.GetItemCooldown, itemID)
        if type(a) == "table" then
            local info = a
            local dur = CanUseNumber(info.duration) and info.duration or nil
            local start = CanUseNumber(info.startTime) and info.startTime or nil
            local isActive = SafeFlagTrue(info.isActive)
            if not isActive and type(dur) == "number" and dur > 0 and type(start) == "number" and start > 0 then
                isActive = true
            end
            return { isActive = isActive, duration = dur, enable = info.isEnabled }
        end
        local startTime, duration, enable = a, b, c
        local dur = CanUseNumber(duration) and duration or nil
        local start = CanUseNumber(startTime) and startTime or nil
        local isActive = false
        if type(dur) == "number" and type(start) == "number" then
            isActive = dur > 0 and start > 0
        elseif enable == false or enable == 0 then
            isActive = false
        end
        return { isActive = isActive, duration = dur, enable = enable }
    end
    if GetItemCooldown then
        local startTime, duration, enable = SafeCall(GetItemCooldown, itemID)
        local dur = CanUseNumber(duration) and duration or nil
        local start = CanUseNumber(startTime) and startTime or nil
        local isActive = false
        if type(dur) == "number" and type(start) == "number" then
            isActive = dur > 0 and start > 0
        elseif enable == false or enable == 0 then
            isActive = false
        end
        return { isActive = isActive, duration = dur, enable = enable }
    end
    return nil
end

local function EnsurePoll()
    if pollTicker or pendingCount <= 0 then
        return
    end
    if not (C_Timer and C_Timer.NewTicker) then
        return
    end
    pollTicker = C_Timer.NewTicker(POLL_SEC, function()
        Items.PollPending()
        if pendingCount <= 0 and pollTicker then
            pollTicker:Cancel()
            pollTicker = nil
        end
    end)
end

local function SetPending(entry, pending)
    if entry.pending == pending then
        return
    end
    entry.pending = pending
    if pending then
        pendingCount = pendingCount + 1
        EnsurePoll()
    else
        pendingCount = math.max(0, pendingCount - 1)
    end
end

local function ShouldTrackDuration(duration)
    local minSec = MinCooldownSec()
    if type(duration) == "number" then
        return duration >= minSec
    end
    -- Secret/unknown duration: still mark pending when we saw a use transition via events.
    return true
end

local function OnBecameReady(entry)
    SetPending(entry, false)
    entry.wakeAt = nil
    -- Combat potions share one CD: announce a single ready, silence siblings.
    if entry.consumableType == "potion" then
        for _, other in pairs(tracked) do
            if other ~= entry and other.consumableType == "potion" and other.pending then
                SetPending(other, false)
                other.wakeAt = nil
            end
        end
    end
    local minSec = MinCooldownSec()
    local meaningful = (type(entry.observedDuration) == "number" and entry.observedDuration >= minSec)
        or entry.sawSecretCooldown == true
    entry.sawSecretCooldown = nil
    if not meaningful then
        return
    end
    if not CanAnnounceEntry(entry) then
        return
    end
    if CA.Announce and CA.Announce.Ready then
        local opts = CA.Announce.OptsForEntry and CA.Announce.OptsForEntry(entry) or nil
        CA.Announce.Ready(entry.name, opts)
    end
end

local function ScheduleWake(entry, duration)
    if type(duration) ~= "number" or duration <= 0 or not (C_Timer and C_Timer.After) then
        return
    end
    local key = entry.key
    local gen = (entry.wakeGen or 0) + 1
    entry.wakeGen = gen
    C_Timer.After(duration + 0.05, function()
        local e = tracked[key]
        if not e or e.wakeGen ~= gen then
            return
        end
        Items.Evaluate(e.itemID)
    end)
end

local function FindEntry(itemID)
    return trackedByItemID[itemID]
end

function Items.Evaluate(itemID)
    if type(itemID) ~= "number" then
        return
    end
    local entry = FindEntry(itemID)
    if not entry then
        return
    end

    local cd = GetItemCooldownState(itemID)
    if not cd then
        return
    end

    if cd.isActive then
        if ShouldTrackDuration(cd.duration) then
            if not entry.pending then
                SetPending(entry, true)
                if type(cd.duration) == "number" then
                    entry.observedDuration = cd.duration
                    ScheduleWake(entry, cd.duration)
                else
                    entry.sawSecretCooldown = true
                    if type(entry.observedDuration) ~= "number" then
                        entry.observedDuration = MinCooldownSec()
                    end
                end
            elseif type(cd.duration) ~= "number" then
                entry.sawSecretCooldown = true
                if type(entry.observedDuration) ~= "number" then
                    entry.observedDuration = MinCooldownSec()
                end
            end
        end
        return
    end

    if entry.pending then
        OnBecameReady(entry)
    end
end

function Items.PollPending()
    for _, entry in pairs(tracked) do
        if entry.pending then
            Items.Evaluate(entry.itemID)
        end
    end
end

function Items.RefreshPending()
    Items.PollPending()
end

--- Equipped / consumable / hearth / teleport (small set). Skips idle toys.
function Items.RefreshActive()
    for _, entry in pairs(tracked) do
        if entry.pending or entry.kind ~= "toy" then
            Items.Evaluate(entry.itemID)
        end
    end
end

function Items.RefreshAll()
    for _, entry in pairs(tracked) do
        Items.Evaluate(entry.itemID)
    end
end

local function ThrottledRefreshPending()
    local now = (GetTime and GetTime()) or 0
    if (now - lastBagRefresh) < BAG_REFRESH_THROTTLE then
        return
    end
    lastBagRefresh = now
    Items.RefreshPending()
end

local function GetItemSpellName(itemID)
    if C_Item and C_Item.GetItemSpell then
        local spellID, spellName = SafeCall(C_Item.GetItemSpell, itemID)
        if type(spellName) == "string" and spellName ~= "" then
            return spellName, spellID
        end
        if type(spellID) == "number" and C_Spell and C_Spell.GetSpellName then
            local n = SafeCall(C_Spell.GetSpellName, spellID)
            if type(n) == "string" and n ~= "" then
                return n, spellID
            end
        end
    end
    if GetItemSpell then
        local spellName, spellID = SafeCall(GetItemSpell, itemID)
        if type(spellName) == "string" and spellName ~= "" then
            return spellName, spellID
        end
    end
    return nil, nil
end

local function ItemLooksLikeTeleport(itemID, name)
    -- Hearthstones count as teleports in the Teleport tab.
    if CA.Categories and CA.Categories.IsHearthstoneName and CA.Categories.IsHearthstoneName(name) then
        return true
    end
    if CA.Teleports and CA.Teleports.IsTeleportItemID and CA.Teleports.IsTeleportItemID(itemID) then
        return true
    end
    if CA.Categories and CA.Categories.IsTeleportName and CA.Categories.IsTeleportName(name) then
        return true
    end
    local spellName = GetItemSpellName(itemID)
    if CA.Categories and CA.Categories.IsTeleportName and CA.Categories.IsTeleportName(spellName) then
        return true
    end
    return false
end

local function PlayerOwnsItem(itemID)
    -- Prefer CanUse so class-locked toys (e.g. Nature's Beacon / Druid) stay off other classes.
    if CA.Teleports and CA.Teleports.PlayerCanUseItem then
        return CA.Teleports.PlayerCanUseItem(itemID)
    end
    if CA.Teleports and CA.Teleports.PlayerOwnsItem then
        return CA.Teleports.PlayerOwnsItem(itemID)
    end
    if type(itemID) ~= "number" or itemID <= 0 then
        return false
    end
    if PlayerHasToy and SafeCall(PlayerHasToy, itemID) then
        return true
    end
    if C_Item and C_Item.GetItemCount then
        local count = SafeCall(C_Item.GetItemCount, itemID, true, false, true)
        if type(count) == "number" and count > 0 then
            return true
        end
    end
    return false
end

local function RemoveTrackedEntry(entry)
    if not entry or not entry.key then
        return
    end
    if entry.pending then
        SetPending(entry, false)
    end
    tracked[entry.key] = nil
    if entry.itemID and trackedByItemID[entry.itemID] == entry then
        trackedByItemID[entry.itemID] = nil
    end
end

local function AddItem(itemID, source, category, nameOverride, iconOverride)
    if type(itemID) ~= "number" or itemID <= 0 then
        return false
    end
    local kind = "item"
    if type(source) == "string" then
        if source:find("^toy:") then
            kind = "toy"
        elseif source:find("^hearth:") then
            kind = "hearth"
        elseif source:find("^teleport:") then
            kind = "teleport"
        elseif source:find("^trinket:") then
            kind = "trinket"
        elseif source:find("^gear:") then
            kind = "gear"
        elseif source:find("^consumable:") then
            kind = "consumable"
        end
    end
    local key = TrackerKey(kind, itemID)
    if tracked[key] then
        tracked[key].sources[source or kind] = true
        trackedByItemID[itemID] = tracked[key]
        return false
    end
    local existing = trackedByItemID[itemID]
    if existing then
        existing.sources[source or kind] = true
        return false
    end

    local entry = {
        key = key,
        itemID = itemID,
        name = nameOverride or GetItemName(itemID),
        icon = iconOverride or GetItemIcon(itemID),
        category = category or "general",
        pending = false,
        wakeGen = 0,
        observedDuration = nil,
        sources = { [source or kind] = true },
        kind = kind,
    }
    tracked[key] = entry
    trackedByItemID[itemID] = entry
    return true
end

function Items.ScanHearthstone()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeHearthstone == false then
        return 0
    end
    local itemID
    if C_Container and C_Container.PlayerHasHearthstone then
        itemID = SafeCall(C_Container.PlayerHasHearthstone)
    end
    if type(itemID) ~= "number" or itemID <= 0 then
        return 0
    end
    if AddItem(itemID, "hearth:" .. tostring(itemID), "general") then
        return 1
    end
    return 0
end

local function ScanBagSlot(bag, slot, tryAdd)
    local itemID
    if C_Container and C_Container.GetContainerItemID then
        itemID = SafeCall(C_Container.GetContainerItemID, bag, slot)
    elseif GetContainerItemID then
        itemID = SafeCall(GetContainerItemID, bag, slot)
    end
    if type(itemID) == "number" and itemID > 0 then
        tryAdd(itemID)
    end
end

local function InvalidateToyCache()
    toyCache = nil
    toyCacheAt = 0
end

local function CancelToyHarvest()
    toyHarvestGen = toyHarvestGen + 1
    toyHarvest = nil
end

local function AfterFrame(fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local function ApplyToyBoxFilters()
    if C_ToyBoxInfo and C_ToyBoxInfo.SetDefaultFilters then
        SafeCall(C_ToyBoxInfo.SetDefaultFilters)
    end
    if C_ToyBox.SetFilterString then
        SafeCall(C_ToyBox.SetFilterString, "")
    end
    if C_ToyBox.SetCollectedShown then
        SafeCall(C_ToyBox.SetCollectedShown, true)
    end
    if C_ToyBox.SetUncollectedShown then
        SafeCall(C_ToyBox.SetUncollectedShown, false)
    end
    if C_ToyBox.SetUnusableShown then
        SafeCall(C_ToyBox.SetUnusableShown, true)
    end
    if C_ToyBox.SetAllSourceTypeFilters then
        SafeCall(C_ToyBox.SetAllSourceTypeFilters, true)
    end
    if C_ToyBox.SetAllExpansionTypeFilters then
        SafeCall(C_ToyBox.SetAllExpansionTypeFilters, true)
    elseif C_ToyBox.SetExpansionTypeFilter and GetNumExpansions then
        local n = SafeCall(GetNumExpansions) or 0
        for i = 1, n do
            SafeCall(C_ToyBox.SetExpansionTypeFilter, i, true)
        end
    end
    if C_ToyBox.ForceToyRefilter then
        SafeCall(C_ToyBox.ForceToyRefilter)
    end
end

local function FilteredToyCount()
    if C_ToyBox.GetNumFilteredToys then
        return SafeCall(C_ToyBox.GetNumFilteredToys) or 0
    end
    if C_ToyBox.GetNumLearnedDisplayedToys then
        return SafeCall(C_ToyBox.GetNumLearnedDisplayedToys) or 0
    end
    if C_ToyBox.GetNumToys then
        return SafeCall(C_ToyBox.GetNumToys) or 0
    end
    return 0
end

local function CollectToyAtIndex(index)
    local itemID = SafeCall(C_ToyBox.GetToyFromIndex, index)
    if type(itemID) ~= "number" or itemID <= 0 then
        return nil
    end
    if PlayerHasToy and not SafeCall(PlayerHasToy, itemID) then
        return nil
    end
    local toyName, icon
    if C_ToyBox.GetToyInfo then
        local id, name, tex = SafeCall(C_ToyBox.GetToyInfo, itemID)
        toyName = name
        icon = tex
        if type(id) == "number" and id > 0 then
            itemID = id
        end
    end
    return { itemID = itemID, name = toyName, icon = icon }
end

--- Cached owned toys. Never ForceToyRefilter here; harvest does that in slices.
local function GetOwnedToyList()
    local now = (GetTime and GetTime()) or 0
    if toyCache and (now - toyCacheAt) < TOY_CACHE_SEC then
        return toyCache
    end
    return toyCache or {}
end

local ContinueToyHarvest
local ToyBelongsInOtherTab
local ClassAllowsItem

local function PruneToysNotKept(keep)
    local drop = {}
    for _, entry in pairs(tracked) do
        if entry.kind == "toy" and (not keep or not keep[entry.itemID]) then
            drop[#drop + 1] = entry
        end
    end
    for i = 1, #drop do
        RemoveTrackedEntry(drop[i])
    end
end

local function FinishToyHarvest(job)
    toyCache = job and job.list or toyCache
    toyCacheAt = (GetTime and GetTime()) or 0
    local keep = job and job.keepToys
    toyHarvest = nil
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeToys == false then
        PruneToysNotKept(nil)
    else
        PruneToysNotKept(keep)
    end
    if CA.Settings and CA.Settings.IsShown and CA.Settings.IsShown() and CA.Settings.RefreshTrackers then
        CA.Settings.RefreshTrackers()
    end
end

local function ApplyOwnedToysSlice()
    local job = toyHarvest
    if not job or job.gen ~= toyHarvestGen or job.phase ~= "apply" then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, ContinueToyHarvest)
        end
        return
    end

    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local favoritesOnly = sv.toysFavoritesOnly == true
    job.keepToys = job.keepToys or {}
    local last = math.min(#job.list, job.applyIndex + TOY_CHUNK - 1)
    for i = job.applyIndex, last do
        local t = job.list[i]
        local itemID, toyName, icon = t.itemID, t.name, t.icon
        if not ClassAllowsItem(itemID) then
            -- skip
        elseif favoritesOnly and C_ToyBox and C_ToyBox.GetIsFavorite and not SafeCall(C_ToyBox.GetIsFavorite, itemID) then
            -- skip
        else
            local name = toyName or GetItemName(itemID)
            if ToyBelongsInOtherTab(itemID, name) then
                if sv.includeTeleportItems ~= false and PlayerOwnsItem(itemID) then
                    AddItem(itemID, "teleport:" .. tostring(itemID), "general", name, icon)
                end
            elseif sv.includeToys ~= false then
                AddItem(itemID, "toy:" .. tostring(itemID), "general", name, icon)
                job.keepToys[itemID] = true
            end
        end
    end
    job.applyIndex = last + 1
    if job.applyIndex <= #job.list then
        AfterFrame(ContinueToyHarvest)
        return
    end
    FinishToyHarvest(job)
end

local function CollectOwnedToysSlice()
    local job = toyHarvest
    if not job or job.gen ~= toyHarvestGen or job.phase ~= "collect" then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, ContinueToyHarvest)
        end
        return
    end

    local last = math.min(job.num, job.index + TOY_CHUNK - 1)
    for i = job.index, last do
        local row = CollectToyAtIndex(i)
        if row then
            job.list[#job.list + 1] = row
        end
    end
    job.index = last + 1
    if job.index <= job.num then
        AfterFrame(ContinueToyHarvest)
        return
    end
    job.phase = "apply"
    job.applyIndex = 1
    AfterFrame(ContinueToyHarvest)
end

ContinueToyHarvest = function()
    local job = toyHarvest
    if not job or job.gen ~= toyHarvestGen then
        return
    end
    if job.phase == "collect" then
        CollectOwnedToysSlice()
    elseif job.phase == "apply" then
        ApplyOwnedToysSlice()
    end
end

local function BeginToyCollect(gen)
    if gen ~= toyHarvestGen then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                BeginToyCollect(gen)
            end)
        end
        return
    end
    local num = 0
    if C_ToyBox and C_ToyBox.GetToyFromIndex then
        num = FilteredToyCount()
    end
    toyHarvest = {
        gen = gen,
        phase = "collect",
        index = 1,
        num = num,
        list = {},
        applyIndex = 1,
    }
    AfterFrame(ContinueToyHarvest)
end

--- Spread ForceToyRefilter + toy walk across frames so a large box cannot hitch one tick.
function Items.RequestToyHarvest(force)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeToys == false then
        PruneToysNotKept(nil)
        if sv.includeTeleportItems == false then
            return
        end
    end
    if not (C_ToyBox and C_ToyBox.GetToyFromIndex) then
        return
    end

    local now = (GetTime and GetTime()) or 0
    if not force and toyCache and (now - toyCacheAt) < TOY_CACHE_SEC then
        toyHarvestGen = toyHarvestGen + 1
        local gen = toyHarvestGen
        toyHarvest = {
            gen = gen,
            phase = "apply",
            index = 1,
            num = #toyCache,
            list = toyCache,
            applyIndex = 1,
        }
        AfterFrame(ContinueToyHarvest)
        return
    end

    toyHarvestGen = toyHarvestGen + 1
    local gen = toyHarvestGen
    -- Own frame for Blizzard's refilter (cannot be split; isolate it).
    AfterFrame(function()
        if gen ~= toyHarvestGen then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            if C_Timer and C_Timer.After then
                C_Timer.After(1.0, function()
                    if gen == toyHarvestGen then
                        Items.RequestToyHarvest(true)
                    end
                end)
            end
            return
        end
        ApplyToyBoxFilters()
        AfterFrame(function()
            BeginToyCollect(gen)
        end)
    end)
end

ToyBelongsInOtherTab = function(itemID, name)
    if CA.Categories and CA.Categories.IsHearthstoneName and CA.Categories.IsHearthstoneName(name) then
        return true
    end
    if ItemLooksLikeTeleport(itemID, name) then
        return true
    end
    return false
end

ClassAllowsItem = function(itemID)
    if CA.Teleports and CA.Teleports.ItemAllowedForPlayerClassFast then
        return CA.Teleports.ItemAllowedForPlayerClassFast(itemID)
    end
    if CA.Teleports and CA.Teleports.ItemAllowedForPlayerClass then
        return CA.Teleports.ItemAllowedForPlayerClass(itemID)
    end
    return true
end

--- Owned toys that are not teleports/hearthstones (those go to the Teleport tab).
function Items.ScanToys(toyList)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeToys == false then
        return 0
    end
    if not (C_ToyBox and C_ToyBox.GetToyFromIndex) then
        return 0
    end

    local favoritesOnly = sv.toysFavoritesOnly == true
    local added = 0
    local list = toyList or GetOwnedToyList()

    for i = 1, #list do
        local t = list[i]
        local itemID, toyName, icon = t.itemID, t.name, t.icon
        if not ClassAllowsItem(itemID) then
            -- skip
        elseif favoritesOnly and C_ToyBox and C_ToyBox.GetIsFavorite and not SafeCall(C_ToyBox.GetIsFavorite, itemID) then
            -- skip
        else
            local name = toyName or GetItemName(itemID)
            if not ToyBelongsInOtherTab(itemID, name) then
                if AddItem(itemID, "toy:" .. tostring(itemID), "general", name, icon) then
                    added = added + 1
                end
            end
        end
    end

    return added
end

--- Discover teleport items / toys the player owns (bags, equipped, toy box).
function Items.ScanTeleports(toyList)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeTeleportItems == false then
        return 0
    end

    local added = 0
    local seen = {}

    local function TryAdd(itemID, nameOverride, iconOverride)
        if type(itemID) ~= "number" or itemID <= 0 or seen[itemID] then
            return
        end
        seen[itemID] = true
        local name = nameOverride or GetItemName(itemID)
        if not ItemLooksLikeTeleport(itemID, name) then
            return
        end
        if not PlayerOwnsItem(itemID) then
            return
        end
        local source = "teleport:" .. tostring(itemID)
        if AddItem(itemID, source, "general", name, iconOverride) then
            added = added + 1
        end
    end

    -- Curated teleport item / toy IDs (includes zone-hidden toys via quest ownership).
    local ids = CA.Teleports and CA.Teleports.ITEM_IDS
    if type(ids) == "table" then
        for i = 1, #ids do
            local itemID = ids[i]
            local toyName, icon
            if C_ToyBox and C_ToyBox.GetToyInfo then
                local id, name, tex = SafeCall(C_ToyBox.GetToyInfo, itemID)
                toyName = name
                icon = tex
                if type(id) == "number" and id > 0 then
                    itemID = id
                end
            end
            TryAdd(itemID, toyName, icon)
        end
    end

    -- Bags (catch scrolls / one-offs not in the curated list).
    local bags = { 0, 1, 2, 3, 4, 5 }
    if Enum and Enum.BagIndex then
        bags = {
            Enum.BagIndex.Backpack or 0,
            Enum.BagIndex.Bag_1 or 1,
            Enum.BagIndex.Bag_2 or 2,
            Enum.BagIndex.Bag_3 or 3,
            Enum.BagIndex.Bag_4 or 4,
            Enum.BagIndex.ReagentBag or 5,
        }
    end
    for bi = 1, #bags do
        local bag = bags[bi]
        local numSlots = 0
        if C_Container and C_Container.GetContainerNumSlots then
            numSlots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
        elseif GetContainerNumSlots then
            numSlots = SafeCall(GetContainerNumSlots, bag) or 0
        end
        for slot = 1, numSlots do
            ScanBagSlot(bag, slot, TryAdd)
        end
    end

    -- Equipped gear (Kirin Tor rings, cloaks of Coordination, etc.).
    if GetInventoryItemID then
        for slot = 1, 19 do
            local id = SafeCall(GetInventoryItemID, "player", slot)
            if type(id) == "number" then
                TryAdd(id)
            end
        end
    end

    -- Owned toys with teleport-like names (reuse shared toy list; no second refilter).
    local list = toyList or GetOwnedToyList()
    for i = 1, #list do
        local t = list[i]
        TryAdd(t.itemID, t.name, t.icon)
    end

    return added
end

local TRINKET_SLOTS = { 13, 14 } -- INVSLOT_TRINKET1 / TRINKET2
-- Shirt (4) and tabard (19) excluded; weapons/armor/rings/cloak included.
local GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17 }

local function SlotIsTrinket(slot)
    return slot == 13 or slot == 14
end

local function ItemIsTeleportOrHearth(itemID, name)
    if CA.Categories and CA.Categories.IsHearthstoneName and CA.Categories.IsHearthstoneName(name) then
        return true
    end
    if CA.Teleports and CA.Teleports.IsTeleportItemID and CA.Teleports.IsTeleportItemID(itemID) then
        return true
    end
    if CA.Categories and CA.Categories.IsTeleportName and CA.Categories.IsTeleportName(name) then
        return true
    end
    return false
end

local function GetItemClassSubclass(itemID)
    if GetItemInfoInstant then
        local _, _, _, _, _, classID, subclassID = SafeCall(GetItemInfoInstant, itemID)
        if type(classID) == "number" then
            return classID, subclassID
        end
    end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subclassID = SafeCall(C_Item.GetItemInfoInstant, itemID)
        if type(classID) == "number" then
            return classID, subclassID
        end
    end
    return nil, nil
end

local function GetOwnedBagCount(itemID)
    if C_Item and C_Item.GetItemCount then
        local count = SafeCall(C_Item.GetItemCount, itemID, false, false, false)
        if type(count) == "number" then
            return count
        end
    end
    if GetItemCount then
        local count = SafeCall(GetItemCount, itemID, false)
        if type(count) == "number" then
            return count
        end
    end
    return 0
end

--- Classify bag consumables: potions, healthstones, flasks/phials, elixirs, food, bandages.
--- Returns a type string, or nil.
local function ClassifyConsumable(itemID, name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if ItemIsTeleportOrHearth(itemID, name) then
        return nil
    end
    local lower = name:lower()
    if lower:find("healthstone", 1, true) then
        return "healthstone"
    end

    local classID, subclassID = GetItemClassSubclass(itemID)
    local consumableClass = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
    local potionSub = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Potion) or 1
    local elixirSub = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Elixir) or 2
    local foodSub = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Fooddrink) or 4
    local bandageSub = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Bandage) or 6

    if type(classID) == "number" and classID == consumableClass and type(subclassID) == "number" then
        if subclassID == potionSub then
            return "potion"
        end
        if subclassID == elixirSub then
            return "elixir"
        end
        if subclassID == foodSub then
            return "food"
        end
        if subclassID == bandageSub then
            return "bandage"
        end
    end

    if lower:find("flask", 1, true) or lower:find("phial", 1, true) then
        return "flask"
    end
    if lower:find("elixir", 1, true) then
        return "elixir"
    end
    if lower:find("bandage", 1, true) then
        return "bandage"
    end
    if lower:find("feast", 1, true)
        or lower:find("food", 1, true)
        or lower:find("drink", 1, true)
        or lower:find("well fed", 1, true)
    then
        return "food"
    end
    if lower:find("potion", 1, true) then
        return "potion"
    end

    return nil
end

local function PlayerBagIndices()
    if Enum and Enum.BagIndex then
        return {
            Enum.BagIndex.Backpack or 0,
            Enum.BagIndex.Bag_1 or 1,
            Enum.BagIndex.Bag_2 or 2,
            Enum.BagIndex.Bag_3 or 3,
            Enum.BagIndex.Bag_4 or 4,
            Enum.BagIndex.ReagentBag or 5,
        }
    end
    return { 0, 1, 2, 3, 4, 5 }
end

--- Bag consumables (potions, flasks/phials, elixirs, food, bandages, healthstones) with a Use effect.
function Items.ScanConsumables()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local wantConsumables = sv.includeCombatPotions ~= false
    local wantStones = sv.includeHealthstones ~= false
    if not wantConsumables and not wantStones then
        local drop = {}
        for _, entry in pairs(tracked) do
            if entry.kind == "consumable" then
                drop[#drop + 1] = entry
            end
        end
        for i = 1, #drop do
            RemoveTrackedEntry(drop[i])
        end
        return 0
    end

    local stillOwned = {}
    local added = 0
    local itemCat = (CA.Categories and CA.Categories.ITEM) or "item"
    local seen = {}

    local function Consider(itemID)
        if type(itemID) ~= "number" or itemID <= 0 or seen[itemID] then
            return
        end
        seen[itemID] = true
        local name = GetItemName(itemID)
        local ctype = ClassifyConsumable(itemID, name)
        if not ctype then
            return
        end
        if ctype == "healthstone" then
            if not wantStones then
                return
            end
        elseif not wantConsumables then
            return
        end
        if GetOwnedBagCount(itemID) <= 0 then
            return
        end
        local spellName, spellID = GetItemSpellName(itemID)
        if type(spellID) ~= "number" or spellID <= 0 then
            return
        end
        stillOwned[itemID] = true
        local source = "consumable:" .. tostring(itemID)
        if AddItem(itemID, source, itemCat, name) then
            added = added + 1
        end
        local entry = trackedByItemID[itemID]
        if entry then
            entry.kind = "consumable"
            entry.consumableType = ctype
            entry.useSpellID = spellID
            if type(spellName) == "string" and spellName ~= "" and (not entry.name or entry.name:find("^Item ")) then
                entry.name = name
            end
        end
    end

    local bags = PlayerBagIndices()
    for bi = 1, #bags do
        local bag = bags[bi]
        local numSlots = 0
        if C_Container and C_Container.GetContainerNumSlots then
            numSlots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
        elseif GetContainerNumSlots then
            numSlots = SafeCall(GetContainerNumSlots, bag) or 0
        end
        for slot = 1, numSlots do
            ScanBagSlot(bag, slot, Consider)
        end
    end

    local drop = {}
    for _, entry in pairs(tracked) do
        if entry.kind == "consumable" and not stillOwned[entry.itemID] then
            drop[#drop + 1] = entry
        end
    end
    for i = 1, #drop do
        RemoveTrackedEntry(drop[i])
    end

    for itemID in pairs(stillOwned) do
        Items.Evaluate(itemID)
    end

    return added
end

--- Equipped trinkets and other on-use gear with a Use spell.
function Items.ScanEquipped()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local wantTrinkets = sv.includeTrinkets ~= false
    local wantGear = sv.includeOnUseGear ~= false
    if not wantTrinkets and not wantGear then
        -- Drop any previously tracked gear entries.
        local drop = {}
        for key, entry in pairs(tracked) do
            if entry.kind == "trinket" or entry.kind == "gear" then
                drop[#drop + 1] = entry
            end
        end
        for i = 1, #drop do
            RemoveTrackedEntry(drop[i])
        end
        return 0
    end

    if not GetInventoryItemID then
        return 0
    end

    local stillEquipped = {}
    local added = 0
    local itemCat = (CA.Categories and CA.Categories.ITEM) or "item"

    local function ConsiderSlot(slot, asTrinket)
        local itemID = SafeCall(GetInventoryItemID, "player", slot)
        if type(itemID) ~= "number" or itemID <= 0 then
            return
        end
        local name = GetItemName(itemID)
        if ItemIsTeleportOrHearth(itemID, name) then
            return
        end
        local spellName, spellID = GetItemSpellName(itemID)
        if type(spellID) ~= "number" or spellID <= 0 then
            -- No Use effect (passive trinket / flavor item).
            return
        end
        stillEquipped[itemID] = true
        local source
        if asTrinket then
            source = "trinket:" .. tostring(itemID)
        else
            source = "gear:" .. tostring(slot) .. ":" .. tostring(itemID)
        end
        if AddItem(itemID, source, itemCat, name) then
            added = added + 1
        end
        local entry = trackedByItemID[itemID]
        if entry then
            entry.equipSlot = slot
            entry.useSpellID = spellID
            if type(spellName) == "string" and spellName ~= "" and (not entry.name or entry.name:find("^Item ")) then
                entry.name = name
            end
        end
    end

    if wantTrinkets then
        for i = 1, #TRINKET_SLOTS do
            ConsiderSlot(TRINKET_SLOTS[i], true)
        end
    end
    if wantGear then
        for i = 1, #GEAR_SLOTS do
            ConsiderSlot(GEAR_SLOTS[i], false)
        end
    end

    -- Unequipped: remove from tracker so the Items tab stays accurate.
    local drop = {}
    for _, entry in pairs(tracked) do
        if (entry.kind == "trinket" or entry.kind == "gear") and not stillEquipped[entry.itemID] then
            drop[#drop + 1] = entry
        end
    end
    for i = 1, #drop do
        RemoveTrackedEntry(drop[i])
    end

    -- Pick up mid-cooldown state for newly seen / still-equipped pieces.
    for itemID in pairs(stillEquipped) do
        Items.Evaluate(itemID)
    end

    return added
end

--- opts.heavy = start chunked toy harvest. Light = hearth + teleports + gear + consumables.
function Items.ScanAll(opts)
    opts = opts or {}
    local heavy = opts.heavy == true
    local a = Items.ScanHearthstone()
    -- Curated teleports / bags / equipped only. Toy-box walk is async.
    local c = Items.ScanTeleports({})
    local d = Items.ScanEquipped()
    local e = Items.ScanConsumables()
    if heavy then
        Items.RequestToyHarvest(true)
    end
    return (a or 0) + (c or 0) + (d or 0) + (e or 0)
end

function Items.ClearDiscovery()
    if pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end
    CancelToyHarvest()
    wipe(tracked)
    wipe(trackedByItemID)
    pendingCount = 0
    InvalidateToyCache()
end

function Items.GetTrackedList(filter)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    filter = filter or sv.cooldownListFilter or "all"
    local list = {}
    for _, entry in pairs(tracked) do
        local cat = entry.category or "general"
        local _, useSpellID = GetItemSpellName(entry.itemID)
        local row = {
            key = entry.key,
            -- Real use-spell when known (never reuse itemID as spellID — causes mis-grouping).
            spellID = (type(useSpellID) == "number" and useSpellID > 0) and useSpellID or nil,
            itemID = entry.itemID,
            name = entry.name or GetItemName(entry.itemID),
            icon = entry.icon or GetItemIcon(entry.itemID),
            enabled = IsEnabledKey(entry.key),
            pending = entry.pending and true or false,
            category = cat,
            categoryLabel = (CA.Categories and CA.Categories.Label and CA.Categories.Label(cat)) or cat,
            major = type(entry.observedDuration) == "number" and entry.observedDuration >= (sv.majorCooldownSeconds or 45),
            observedDuration = entry.observedDuration,
            kind = entry.kind,
            sources = entry.sources,
        }
        if CA.Categories and CA.Categories.ResolveGroup then
            row.group = CA.Categories.ResolveGroup(row)
            row.groupLabel = CA.Categories.GroupLabel(row.group)
        else
            row.group = "general"
            row.groupLabel = "General"
        end
        -- Teleport tab: only items/toys the player currently owns.
        if row.group == "teleport"
            and CA.Teleports and CA.Teleports.PlayerHasAccess
            and not CA.Teleports.PlayerHasAccess(row)
        then
            -- skip
        elseif filter == "all" or filter == row.group then
            -- Only "all" shows every group; other filters are exclusive.
            list[#list + 1] = row
        end
    end
    return list
end

function Items.GetReadyNames()
    local names = {}
    local minSec = MinCooldownSec()
    for _, entry in pairs(tracked) do
        if CanAnnounceEntry(entry) then
            local cd = GetItemCooldownState(entry.itemID)
            if cd and not cd.isActive then
                local meaningful = type(entry.observedDuration) == "number" and entry.observedDuration >= minSec
                if meaningful then
                    names[#names + 1] = entry.name
                end
            end
        end
    end
    return names
end

--- Name to speak on buff fade when the aura matches an enabled tracked item/use spell.
function Items.GetFadeAnnounceName(spellID, auraName)
    if type(spellID) == "number" and spellID > 0 then
        for _, entry in pairs(tracked) do
            if CanAnnounceEntry(entry) then
                if entry.useSpellID == spellID then
                    return entry.name or GetItemName(entry.itemID)
                end
                local _, useSpellID = GetItemSpellName(entry.itemID)
                if useSpellID == spellID then
                    return entry.name or GetItemName(entry.itemID)
                end
            end
        end
    end
    if type(auraName) == "string" and auraName ~= "" then
        local lower = auraName:lower()
        for _, entry in pairs(tracked) do
            if CanAnnounceEntry(entry) then
                local n = entry.name or GetItemName(entry.itemID)
                if type(n) == "string" and n:lower() == lower then
                    return n
                end
            end
        end
    end
    return nil
end

local equipScanPending = false
local consumableScanPending = false

local eventFrame = CreateFrame("Frame")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_COOLDOWN")
SafeRegisterEvent(eventFrame, "BAG_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
if CA.Compat and CA.Compat.HasToyBox and CA.Compat.HasToyBox() then
    SafeRegisterEvent(eventFrame, "TOYS_UPDATED")
    SafeRegisterEvent(eventFrame, "HEARTHSTONE_BOUND")
else
    -- Hearthstone bind event exists on some Classic builds.
    SafeRegisterEvent(eventFrame, "HEARTHSTONE_BOUND")
end

local function RefreshSettingsTrackersIfShown()
    if CA.Settings and CA.Settings.IsShown and CA.Settings.IsShown() and CA.Settings.RefreshTrackers then
        CA.Settings.RefreshTrackers()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- Login / world enter discovery is owned by Spells.RequestRescan(true) to avoid double scans.
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if equipScanPending then
            return
        end
        equipScanPending = true
        local delay = (InCombatLockdown and InCombatLockdown()) and 1.0 or 0.35
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                equipScanPending = false
                Items.ScanEquipped()
                Items.RefreshPending()
                RefreshSettingsTrackersIfShown()
            end)
        else
            equipScanPending = false
            Items.ScanEquipped()
        end
        return
    end

    if event == "BAG_UPDATE" then
        if consumableScanPending then
            return
        end
        consumableScanPending = true
        local delay = (InCombatLockdown and InCombatLockdown()) and 1.25 or 0.5
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                consumableScanPending = false
                Items.ScanConsumables()
                Items.RefreshPending()
                RefreshSettingsTrackersIfShown()
            end)
        else
            consumableScanPending = false
            Items.ScanConsumables()
        end
        return
    end

    if event == "TOYS_UPDATED" or event == "HEARTHSTONE_BOUND" then
        InvalidateToyCache()
        if InCombatLockdown and InCombatLockdown() then
            if CA.Spells and CA.Spells.RequestRescan then
                CA.Spells.RequestRescan(true)
            end
            return
        end
        if scanQueued then
            return
        end
        scanQueued = true
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                scanQueued = false
                Items.ScanHearthstone()
                Items.RequestToyHarvest(true)
            end)
        else
            scanQueued = false
            Items.RequestToyHarvest(true)
        end
        return
    end
    if event == "BAG_UPDATE_COOLDOWN" then
        -- Potions / gear CDs. Do not walk the whole toy box every pulse.
        local now = (GetTime and GetTime()) or 0
        if (now - lastBagRefresh) < BAG_REFRESH_THROTTLE then
            return
        end
        lastBagRefresh = now
        if (now - lastItemFullRefresh) >= 2.5 then
            lastItemFullRefresh = now
            Items.RefreshAll()
        else
            Items.RefreshActive()
        end
    end
end)
