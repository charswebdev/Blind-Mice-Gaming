local addonName, LPL = ...

LPL.LoadoutEditor = {}

local COL_WIDTH = 300
local COL_GAP = 24
local BTN_SIZE = 22
local SLOT_HEIGHT = 56

local SEGMENTS = {
    {
        field = "talentBuildIDs",
        singular = "talentBuildID",
        label = "Talents",
        getAll = function()
            return LPL.TalentStore and LPL.TalentStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.TalentStore and LPL.TalentStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.TalentStore and LPL.TalentStore:GetSummaryLine(record) or ""
        end,
        getClassID = function(record)
            return LPL.TalentStore and LPL.TalentStore:GetEffectiveClassID(record)
        end,
        getSpecID = function(record)
            return record and tonumber(record.specID)
        end,
    },
    {
        field = "actionBarSetIDs",
        singular = "actionBarSetID",
        label = "Action Bars",
        getAll = function()
            return LPL.ActionBarStore and LPL.ActionBarStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.ActionBarStore and LPL.ActionBarStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.ActionBarStore and LPL.ActionBarStore:GetSummaryLine(record) or ""
        end,
        getClassID = function(record)
            return LPL.ActionBarStore and LPL.ActionBarStore:GetEffectiveClassID(record)
        end,
        getSpecID = function(record)
            return LPL.ActionBarStore and LPL.ActionBarStore:GetEffectiveSpecID(record)
        end,
    },
    {
        field = "keybindSetIDs",
        singular = "keybindSetID",
        label = "Keybinding Profiles",
        getAll = function()
            return LPL.KeybindStore and LPL.KeybindStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.KeybindStore and LPL.KeybindStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.KeybindStore and LPL.KeybindStore:GetSummaryLine(record) or ""
        end,
    },
    {
        field = "equipmentSetIDs",
        singular = "equipmentSetID",
        label = "Equipment",
        getAll = function()
            return LPL.EquipmentStore and LPL.EquipmentStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.EquipmentStore and LPL.EquipmentStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.EquipmentStore and LPL.EquipmentStore:GetSummaryLine(record) or ""
        end,
        getClassID = function(record)
            return LPL.EquipmentStore and LPL.EquipmentStore:GetEffectiveClassID(record)
        end,
        getSpecID = function(record)
            return LPL.EquipmentStore and LPL.EquipmentStore:GetEffectiveSpecID(record)
        end,
    },
    {
        field = "editModeSetIDs",
        singular = "editModeSetID",
        label = "Edit Mode",
        getAll = function()
            return LPL.EditModeStore and LPL.EditModeStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.EditModeStore and LPL.EditModeStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.EditModeStore and LPL.EditModeStore:GetSummaryLine(record) or ""
        end,
        getClassID = function(record)
            return LPL.EditModeStore and LPL.EditModeStore:GetEffectiveClassID(record)
        end,
        getSpecID = function(record)
            return LPL.EditModeStore and LPL.EditModeStore:GetEffectiveSpecID(record)
        end,
    },
    {
        field = "addonSetIDs",
        singular = "addonSetID",
        label = "Addon Sets",
        getAll = function()
            return LPL.AddonSetStore and LPL.AddonSetStore:GetAll() or {}
        end,
        get = function(id)
            return LPL.AddonSetStore and LPL.AddonSetStore:Get(id)
        end,
        getSummary = function(record)
            return LPL.AddonSetStore and LPL.AddonSetStore:GetSummaryLine(record) or ""
        end,
    },
}

local function GetClassName(classID)
    classID = tonumber(classID)
    if not classID then
        return "Other"
    end
    if LPL.TalentTree and LPL.TalentTree.GetClasses then
        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            if class.id == classID then
                return class.name or class.file or ("Class " .. classID)
            end
        end
    end
    if GetClassInfo then
        local name = GetClassInfo(classID)
        if name then
            return name
        end
    end
    return "Class " .. classID
end

local function GetSpecName(classID, specID)
    specID = tonumber(specID)
    if not specID then
        return "General"
    end
    if LPL.TalentTree and LPL.TalentTree.GetSpecsForClass then
        for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(classID or 0)) do
            if spec.id == specID then
                return spec.name or ("Spec " .. specID)
            end
        end
    end
    if GetSpecializationInfoByID then
        local _, name = GetSpecializationInfoByID(specID)
        if name then
            return name
        end
    end
    return "Spec " .. specID
end

local function CollectDraftClassIDs(draft)
    local classIDs = {}
    if type(draft) ~= "table" then
        return classIDs
    end

    local restrictions = draft.restrictions
    if type(restrictions) == "table" and type(restrictions.class) == "table" then
        for key in pairs(restrictions.class) do
            local classID = tonumber(key)
            if not classID and LPL.SetRestrictions and LPL.SetRestrictions.GetClassIDForClassFile then
                classID = LPL.SetRestrictions:GetClassIDForClassFile(key)
            end
            if classID then
                classIDs[classID] = true
            end
        end
    end

    if type(restrictions) == "table" and type(restrictions.spec) == "table"
        and LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec
    then
        for specID in pairs(restrictions.spec) do
            specID = tonumber(specID)
            local classID = specID and LPL.TalentTree:GetClassIDForSpec(specID)
            if classID then
                classIDs[classID] = true
            end
        end
    end

    if not next(classIDs) then
        local classID = tonumber(draft.classID)
        if not classID and LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
            classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(draft)
        end
        if classID then
            classIDs[classID] = true
        end
    end

    return classIDs
end

local function CollectDraftSpecIDs(draft)
    local specIDs = {}
    if type(draft) ~= "table" then
        return specIDs
    end

    local restrictions = draft.restrictions
    if type(restrictions) == "table" and type(restrictions.spec) == "table" then
        for specID in pairs(restrictions.spec) do
            specID = tonumber(specID)
            if specID then
                specIDs[specID] = true
            end
        end
    end

    if not next(specIDs) then
        local specID = tonumber(draft.specID)
        if specID then
            specIDs[specID] = true
        end
    end

    return specIDs
end

local function RecordMatchesDraftLimits(record, segment, draftClassIDs, draftSpecIDs)
    if type(record) ~= "table" then
        return false
    end

    local hasClassFilter = next(draftClassIDs) ~= nil
    local hasSpecFilter = next(draftSpecIDs) ~= nil
    if not hasClassFilter and not hasSpecFilter then
        return true
    end

    local recordClassID = segment.getClassID and segment.getClassID(record) or nil
    local recordSpecID = segment.getSpecID and segment.getSpecID(record) or nil

    if hasClassFilter then
        -- Universal / unrestricted sets are usable by any class.
        if recordClassID and not draftClassIDs[recordClassID] then
            return false
        end
    end

    if hasSpecFilter then
        if recordSpecID and not draftSpecIDs[recordSpecID] then
            return false
        end
    end

    return true
end

local function SortRecordsByName(list)
    table.sort(list, function(a, b)
        return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end)
end

local function AddRecordItem(items, record)
    items[#items + 1] = {
        id = tostring(record.id),
        name = record.name or tostring(record.id),
    }
end

local function BuildGroupedItems(records, segment)
    local byClass = {}
    local other = {}

    for _, record in ipairs(records) do
        local classID = segment.getClassID and segment.getClassID(record) or nil
        if classID then
            local classBucket = byClass[classID]
            if not classBucket then
                classBucket = { classID = classID, bySpec = {}, general = {} }
                byClass[classID] = classBucket
            end
            local specID = segment.getSpecID and segment.getSpecID(record) or nil
            if specID then
                local specBucket = classBucket.bySpec[specID]
                if not specBucket then
                    specBucket = { specID = specID, records = {} }
                    classBucket.bySpec[specID] = specBucket
                end
                specBucket.records[#specBucket.records + 1] = record
            else
                classBucket.general[#classBucket.general + 1] = record
            end
        else
            other[#other + 1] = record
        end
    end

    local classOrder = {}
    for classID in pairs(byClass) do
        classOrder[#classOrder + 1] = classID
    end
    table.sort(classOrder, function(a, b)
        return GetClassName(a):lower() < GetClassName(b):lower()
    end)

    local items = {
        { id = nil, name = "None" },
    }

    for _, classID in ipairs(classOrder) do
        local classBucket = byClass[classID]
        items[#items + 1] = {
            isHeader = true,
            name = GetClassName(classID),
        }

        local specOrder = {}
        for specID in pairs(classBucket.bySpec) do
            specOrder[#specOrder + 1] = specID
        end
        table.sort(specOrder, function(a, b)
            return GetSpecName(classID, a):lower() < GetSpecName(classID, b):lower()
        end)

        SortRecordsByName(classBucket.general)
        for _, record in ipairs(classBucket.general) do
            AddRecordItem(items, record)
        end

        for _, specID in ipairs(specOrder) do
            local specBucket = classBucket.bySpec[specID]
            items[#items + 1] = {
                isHeader = true,
                name = "  " .. GetSpecName(classID, specID),
            }
            SortRecordsByName(specBucket.records)
            for _, record in ipairs(specBucket.records) do
                AddRecordItem(items, record)
            end
        end
    end

    if #other > 0 then
        items[#items + 1] = {
            isHeader = true,
            name = "Other",
        }
        SortRecordsByName(other)
        for _, record in ipairs(other) do
            AddRecordItem(items, record)
        end
    end

    return items
end

local function BuildFilteredItems(records, selectedID, segment)
    SortRecordsByName(records)
    local items = {
        { id = nil, name = "None" },
    }
    local seen = {}
    for _, record in ipairs(records) do
        local id = tostring(record.id)
        seen[id] = true
        AddRecordItem(items, record)
    end

    -- Keep the current attachment visible even if Limits no longer match it.
    if selectedID and not seen[tostring(selectedID)] then
        local current = segment.get(selectedID)
        if current then
            AddRecordItem(items, current)
        end
    end

    return items
end

local function BuildItems(segment, draftSet, selectedID)
    local draftClassIDs = CollectDraftClassIDs(draftSet)
    local draftSpecIDs = CollectDraftSpecIDs(draftSet)
    local hasClassOrSpecLimits = next(draftClassIDs) ~= nil or next(draftSpecIDs) ~= nil

    local list = segment.getAll() or {}
    local matching = {}
    for _, record in ipairs(list) do
        if type(record) == "table" and record.id
            and RecordMatchesDraftLimits(record, segment, draftClassIDs, draftSpecIDs)
        then
            matching[#matching + 1] = record
        end
    end

    if hasClassOrSpecLimits then
        return BuildFilteredItems(matching, selectedID, segment)
    end

    local items = BuildGroupedItems(matching, segment)
    if selectedID then
        local found = false
        local selectedKey = tostring(selectedID)
        for _, item in ipairs(items) do
            if not item.isHeader and item.id and tostring(item.id) == selectedKey then
                found = true
                break
            end
        end
        if not found then
            local current = segment.get(selectedID)
            if current then
                AddRecordItem(items, current)
            end
        end
    end
    return items
end

local function UpdateSlotSummary(slot, segment, selectedID)
    if not slot or not slot.summary then
        return
    end
    if not selectedID then
        slot.summary:SetText("Not attached")
        slot.summary:SetTextColor(LPL.Theme:GetColor("textMuted"))
        return
    end
    local record = segment.get(selectedID)
    if not record then
        slot.summary:SetText("Missing set (cleared on save)")
        slot.summary:SetTextColor(LPL.Theme:GetColor("textMuted"))
        return
    end
    local line = segment.getSummary(record)
    if type(line) ~= "string" or line == "" then
        line = record.name or selectedID
    end
    slot.summary:SetText(line)
    slot.summary:SetTextColor(LPL.Theme:GetColor("textSecondary"))
end

local function GetDraftSegmentIDs(draft, segment)
    if not draft then
        return {}
    end
    if LPL.LoadoutStore and LPL.LoadoutStore.GetSegmentIDs then
        return LPL.LoadoutStore:GetSegmentIDs(draft, segment.field)
    end
    return LPL.LoadoutStore:NormalizeSegmentIDs(draft[segment.field] or draft[segment.singular])
end

local function SetDraftSegmentIDs(draft, segment, ids)
    if not draft then
        return
    end
    if LPL.LoadoutStore and LPL.LoadoutStore.SetSegmentIDs then
        LPL.LoadoutStore:SetSegmentIDs(draft, segment.field, ids)
        return
    end
    draft[segment.field] = ids or {}
    draft[segment.singular] = draft[segment.field][1]
end

local function ResolveIcon(stem)
    if LPL.ResolveIconPath then
        return LPL:ResolveIconPath(stem)
    end
    return "Interface\\AddOns\\lpl-classic-era\\icons\\" .. stem .. ".tga"
end

local function CreateIconButton(parent, stem, tooltip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BTN_SIZE, BTN_SIZE)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(ResolveIcon(stem))
    button.icon = icon

    button:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        if GameTooltip and tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetAlpha(0.9)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetAlpha(0.9)
    return button
end

function LPL.LoadoutEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.draftSet = nil
    frame.segments = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Loadout")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    frame.statusLabel = status

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Link one or more sets per segment. + adds another link, X unlinks. Limits filter the lists.")
    hint:SetTextColor(LPL.Theme:GetColor("textMuted"))

    local grid = CreateFrame("Frame", nil, frame)
    grid:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -18)
    grid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    frame.grid = grid

    local leftCol = CreateFrame("Frame", nil, grid)
    leftCol:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
    leftCol:SetWidth(COL_WIDTH)
    local rightCol = CreateFrame("Frame", nil, grid)
    rightCol:SetPoint("TOPLEFT", grid, "TOPLEFT", COL_WIDTH + COL_GAP, 0)
    rightCol:SetWidth(COL_WIDTH)
    frame.leftCol = leftCol
    frame.rightCol = rightCol

    local function EnsureDraftSlots(segment)
        if not frame.draftSet then
            return { "" }
        end
        local ids = GetDraftSegmentIDs(frame.draftSet, segment)
        if #ids == 0 then
            return { "" }
        end
        local slots = {}
        for i, id in ipairs(ids) do
            slots[i] = id
        end
        return slots
    end

    local function WriteDraftSlots(segment, slotIDs)
        local compact = {}
        for _, id in ipairs(slotIDs or {}) do
            if type(id) == "string" and id ~= "" then
                compact[#compact + 1] = id
            end
        end
        SetDraftSegmentIDs(frame.draftSet, segment, compact)
    end

    local function ReadUISlots(block)
        if type(block.uiSlots) == "table" and #block.uiSlots > 0 then
            return block.uiSlots
        end
        local ids = EnsureDraftSlots(block.segment)
        block.uiSlots = ids
        return ids
    end

    local function CommitUISlots(block)
        WriteDraftSlots(block.segment, block.uiSlots or {})
    end

    for index, segment in ipairs(SEGMENTS) do
        local parentCol = ((index - 1) % 2 == 0) and leftCol or rightCol
        local block = CreateFrame("Frame", nil, parentCol)
        block:SetWidth(COL_WIDTH)
        block.segment = segment
        block.uiSlots = nil
        block.slotRows = {}

        local label = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        label:SetText(segment.label)
        label:SetTextColor(LPL.Theme:GetColor("textLabel"))
        block.label = label

        local slotsHost = CreateFrame("Frame", nil, block)
        slotsHost:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        slotsHost:SetWidth(COL_WIDTH)
        block.slotsHost = slotsHost

        frame.segments[#frame.segments + 1] = block
    end

    function frame:RefreshStatus()
        local labels = LPL.LoadoutStore:GetAttachedSegmentLabels(self.draftSet)
        if #labels == 0 then
            self.statusLabel:SetText("No segments attached.")
        elseif #labels <= 3 then
            self.statusLabel:SetText("Attached: " .. table.concat(labels, " · "))
        else
            self.statusLabel:SetText(string.format("%d segments attached.", #labels))
        end
    end

    function frame:RelayoutColumns()
        local leftY, rightY = 0, 0
        for index, block in ipairs(self.segments) do
            local isLeft = ((index - 1) % 2 == 0)
            local y = isLeft and leftY or rightY
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT", isLeft and self.leftCol or self.rightCol, "TOPLEFT", 0, -y)
            local height = 18 + (math.max(#block.slotRows, 1) * SLOT_HEIGHT) + 8
            block:SetHeight(height)
            if isLeft then
                leftY = leftY + height + 12
            else
                rightY = rightY + height + 12
            end
        end
        self.leftCol:SetHeight(math.max(leftY, 1))
        self.rightCol:SetHeight(math.max(rightY, 1))
    end

    function frame:RebuildSegmentSlots(block)
        local segment = block.segment
        for _, row in ipairs(block.slotRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(block.slotRows)

        local slotIDs = ReadUISlots(block)

        for slotIndex, selectedID in ipairs(slotIDs) do
            local row = CreateFrame("Frame", nil, block.slotsHost)
            row:SetSize(COL_WIDTH, SLOT_HEIGHT)
            row:SetPoint("TOPLEFT", block.slotsHost, "TOPLEFT", 0, -((slotIndex - 1) * SLOT_HEIGHT))

            local dropWidth = COL_WIDTH - (BTN_SIZE * 2) - 10
            local drop = LPL:CreateDropdown(nil, row, dropWidth)
            drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            drop:SetLabel("")
            drop.title:Hide()
            drop:SetHeight(36)
            drop.box:ClearAllPoints()
            drop.box:SetPoint("TOPLEFT", drop, "TOPLEFT", 0, 0)

            local removeBtn = CreateIconButton(row, "link_remove_32", "Unlink this set")
            removeBtn:SetPoint("LEFT", drop.box, "RIGHT", 4, 0)

            local addBtn = CreateIconButton(row, "link_add_32", "Add another linked set")
            addBtn:SetPoint("LEFT", removeBtn, "RIGHT", 2, 0)

            local summary = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            summary:SetPoint("TOPLEFT", drop.box, "BOTTOMLEFT", 0, -2)
            summary:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
            summary:SetJustifyH("LEFT")
            row.summary = summary

            local items = BuildItems(segment, self.draftSet, selectedID ~= "" and selectedID or nil)
            drop:SetItems(items, selectedID ~= "" and selectedID or nil, function(id)
                if not self.draftSet then
                    return
                end
                block.uiSlots[slotIndex] = id and tostring(id) or ""
                CommitUISlots(block)
                UpdateSlotSummary(row, segment, block.uiSlots[slotIndex] ~= "" and block.uiSlots[slotIndex] or nil)
                self:RefreshStatus()
            end)
            UpdateSlotSummary(row, segment, selectedID ~= "" and selectedID or nil)

            removeBtn:SetScript("OnClick", function()
                if not self.draftSet then
                    return
                end
                if #block.uiSlots <= 1 then
                    block.uiSlots[1] = ""
                else
                    table.remove(block.uiSlots, slotIndex)
                end
                CommitUISlots(block)
                self:RefreshDropdowns()
            end)

            addBtn:SetScript("OnClick", function()
                if not self.draftSet then
                    return
                end
                block.uiSlots[#block.uiSlots + 1] = ""
                CommitUISlots(block)
                self:RefreshDropdowns()
            end)

            block.slotRows[#block.slotRows + 1] = row
        end

        block.slotsHost:SetHeight(math.max(#block.slotRows, 1) * SLOT_HEIGHT)
    end

    function frame:RefreshDropdowns()
        if not self.draftSet then
            return
        end
        for _, block in ipairs(self.segments) do
            self:RebuildSegmentSlots(block)
        end
        self:RelayoutColumns()
        self:RefreshStatus()
    end

    function frame:Refresh()
        self:RefreshDropdowns()
    end

    function frame:SetDraftSet(draft)
        self.draftSet = draft
        for _, block in ipairs(self.segments) do
            block.uiSlots = nil
        end
        self:Refresh()
    end

    return frame
end

function LPL.LoadoutEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
