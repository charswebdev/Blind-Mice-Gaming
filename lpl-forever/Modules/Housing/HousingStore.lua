local addonName, LPL = ...

LPL.HousingStore = {}

LPL.HousingStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_HOUSING_BLUEPRINT"

local function GetHousingData()
    return LPL.DB:GetHousing()
end

function LPL.HousingStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Housing Blueprint"
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

-- Public samples used to lock detect (all 24 chars, Ag prefix, base64 alphabet):
-- AgK4uUr/GmFPA4G3yhZFI95G  WoWDB Kaldorei refuge
-- AgIVtMYjUK1Hzaqx85qWNlyC  official forums
-- AgF3nlpajedJ2Z7rJAqzcDnf  forums Stormwulf house
-- AgQ8F4uPnHdDsqx+JoPhz9NK  forums Halloween WIP
function LPL.HousingStore:NormalizeCode(str)
    if type(str) ~= "string" then
        return ""
    end
    return str:match("^%s*(.-)%s*$") or ""
end

function LPL.HousingStore:Detect(str)
    local code = self:NormalizeCode(str)
    if code == "" or code:find("[\r\n]") then
        return false
    end
    local n = #code
    if n < 22 or n > 28 then
        return false
    end
    if not code:find("^Ag") then
        return false
    end
    return code:match("^Ag[%w%+/=]+$") ~= nil
end

local APPLY_SPEECH = "On your plot: Housing HUD, Blueprint, Import. After a good import, re-save in game. If the creator deletes their save, the shared code dies."

local function SpeakApplyHint(text)
    local AH = _G.AccessibilityHelper or _G.AH
    if AH and AH.Speech and type(AH.Speech.Say) == "function" then
        pcall(AH.Speech.Say, text, AH.Speech.PRIORITY_NAV)
        return true
    end
    return false
end

function LPL.HousingStore:CopyForHouse(setID)
    local set = self:Get(setID)
    if not set then
        print("|cffffcc00LPL:|r Select a housing blueprint first.")
        return false
    end
    local code = self:NormalizeCode(set.code)
    if code == "" then
        print("|cffffcc00LPL:|r Nothing to copy — blueprint code is empty.")
        return false
    end

    local copied = false
    if type(CopyToClipboard) == "function" then
        copied = pcall(CopyToClipboard, code) and true or false
    end

    if copied then
        print(string.format("|cff33cc33LPL:|r Copied \"%s\" to the clipboard.", set.name or "Housing Blueprint"))
    else
        print(string.format("|cffffcc00LPL:|r Could not copy automatically. Code: %s", code))
    end

    if not SpeakApplyHint(APPLY_SPEECH) then
        print("|cff4ecdc4LPL:|r " .. APPLY_SPEECH)
    end
    return copied
end

function LPL.HousingStore:EnsureSetsTable()
    local data = GetHousingData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.HousingStore:GenerateID()
    local data = GetHousingData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "housing_" .. data.nextSetId
end

function LPL.HousingStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Housing Blueprint")
    if type(set.code) ~= "string" then
        set.code = ""
    end
    if type(set.notes) ~= "string" then
        set.notes = ""
    end
    set.byteLength = #(set.code or "")
    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt
    set.schemaVersion = tonumber(set.schemaVersion) or 1
    return set
end

function LPL.HousingStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        code = "",
        notes = "",
    }
end

function LPL.HousingStore:SuggestSetName()
    return "New Housing Blueprint"
end

function LPL.HousingStore:Get(setID)
    if not setID then
        return nil
    end
    local sets = self:EnsureSetsTable()
    return self:NormalizeSetRecord(sets[tostring(setID)])
end

function LPL.HousingStore:GetAll()
    local list = {}
    for _, set in pairs(self:EnsureSetsTable()) do
        local normalized = self:NormalizeSetRecord(set)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.HousingStore:GetSummaryLine(set)
    if type(set) ~= "table" then
        return "Invalid blueprint"
    end
    local bytes = #(type(set.code) == "string" and set.code or "")
    if bytes == 0 then
        return "No code yet"
    end
    return string.format("Blueprint code · %d characters", bytes)
end

function LPL.HousingStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    sets[set.id] = set
    return true
end

function LPL.HousingStore:Delete(setID)
    if not setID then
        return false
    end
    local sets = self:EnsureSetsTable()
    setID = tostring(setID)
    if not sets[setID] then
        return false
    end
    sets[setID] = nil
    return true
end

function LPL.HousingStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end
    local name = self:NormalizeSetName(draft.name, "")
    if name == "" then
        return false, "Enter a name before saving."
    end
    return true
end

function LPL.HousingStore:SaveFromEditor(setID, name, draft, onSaved)
    draft = draft or {}
    draft.name = name
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save housing blueprint."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestSetName())
    local code = type(draft.code) == "string" and draft.code or ""
    local notes = type(draft.notes) == "string" and draft.notes or ""

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.code = code
        set.notes = notes
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved housing blueprint \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        code = code,
        notes = notes,
        createdAt = time(),
        updatedAt = time(),
        schemaVersion = 1,
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created housing blueprint \"%s\".", name))
    return true
end

function LPL.HousingStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete housing blueprint \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.HousingStore:Delete(data.setID) then
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

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Blueprint", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end
