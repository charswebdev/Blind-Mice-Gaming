local addonName, LPL = ...

LPL.MacroIcons = {}

local QUESTION_MARK = 134400
local catalogCache = nil

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    pcall(fn, ...)
end

local function FilenameFromTexture(texture)
    if type(texture) == "number" then
        if C_Texture and C_Texture.GetFilenameFromFileDataID then
            local ok, name = pcall(C_Texture.GetFilenameFromFileDataID, texture)
            if ok and type(name) == "string" and name ~= "" then
                return name
            end
        end
        return tostring(texture)
    end
    if type(texture) == "string" then
        local leaf = texture:match("([^\\/]+)$") or texture
        leaf = leaf:gsub("%.blp$", ""):gsub("%.BLP$", "")
        return leaf
    end
    return ""
end

local function SectionForName(name)
    local t = string.lower(name or "")
    if t == "" or t == "inv_misc_questionmark" or t == tostring(QUESTION_MARK) then
        return "dynamic"
    end
    if t:find("spell_", 1, true) then
        return "spell"
    end
    if t:find("ability_", 1, true) then
        return "ability"
    end
    if t:find("achievement_", 1, true) then
        return "achievement"
    end
    if t:find("inv_", 1, true) then
        return "inventory"
    end
    if t:find("item_", 1, true) then
        return "item"
    end
    return "misc"
end

local function CollectSpellbookFileIDs(into)
    local active = {}
    local spellBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or "player"
    local getNumTabs = GetNumSpellTabs or (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines)
    if not getNumTabs then
        return
    end

    local function GetTabInfo(index)
        if _G.GetSpellTabInfo then
            return _G.GetSpellTabInfo(index)
        end
        if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
            local info = C_SpellBook.GetSpellBookSkillLineInfo(index)
            if info then
                return info.name, info.iconID, info.itemIndexOffset, info.numSpellBookItems
            end
        end
    end

    local getItemInfo = GetSpellBookItemInfo or (C_SpellBook and C_SpellBook.GetSpellBookItemType)
    local getItemTexture = GetSpellBookItemTexture or (C_SpellBook and C_SpellBook.GetSpellBookItemTexture)
    local getSpellTexture = GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture)

    for i = 1, getNumTabs() do
        local _, _, offset, numSpells = GetTabInfo(i)
        offset = (offset or 0) + 1
        local tabEnd = offset + (numSpells or 0)
        for j = offset, tabEnd - 1 do
            if getItemInfo and getItemTexture then
                local spellType, id = getItemInfo(j, spellBank)
                if spellType ~= "FUTURESPELL" then
                    local fileID = getItemTexture(j, spellBank)
                    if fileID then
                        active[fileID] = true
                    end
                end
                if spellType == "FLYOUT" and GetFlyoutInfo and GetFlyoutSlotInfo and getSpellTexture then
                    local _, _, numSlots, isKnown = GetFlyoutInfo(id)
                    if isKnown and numSlots and numSlots > 0 then
                        for k = 1, numSlots do
                            local spellID, _, slotKnown = GetFlyoutSlotInfo(id, k)
                            if slotKnown and spellID then
                                local fileID = getSpellTexture(spellID)
                                if fileID then
                                    active[fileID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for fileID in pairs(active) do
        into[#into + 1] = fileID
    end
end

function LPL.MacroIcons:Invalidate()
    catalogCache = nil
end

function LPL.MacroIcons:GetCatalog()
    if catalogCache then
        return catalogCache
    end

    local raw = {}
    CollectSpellbookFileIDs(raw)
    SafeCall(GetLooseMacroIcons, raw)
    SafeCall(GetLooseMacroItemIcons, raw)
    SafeCall(GetMacroIcons, raw)
    SafeCall(GetMacroItemIcons, raw)

    local seen = {}
    local entries = {}
    -- Dynamic / question mark first.
    entries[#entries + 1] = {
        texture = QUESTION_MARK,
        name = "INV_Misc_QuestionMark",
        search = "inv_misc_questionmark question mark dynamic",
        section = "dynamic",
    }
    seen[QUESTION_MARK] = true
    seen["inv_misc_questionmark"] = true

    for _, texture in ipairs(raw) do
        local name = FilenameFromTexture(texture)
        local key = type(texture) == "number" and texture or string.lower(name)
        if not seen[key] then
            seen[key] = true
            local search = string.lower(name)
            entries[#entries + 1] = {
                texture = texture,
                name = name,
                search = search,
                section = SectionForName(name),
            }
        end
    end

    catalogCache = {
        entries = entries,
        sections = {
            { key = "all", label = "All" },
            { key = "dynamic", label = "Dynamic" },
            { key = "spell", label = "Spell" },
            { key = "ability", label = "Ability" },
            { key = "achievement", label = "Achievement" },
            { key = "inventory", label = "Inventory" },
            { key = "item", label = "Item" },
            { key = "misc", label = "Misc" },
        },
    }
    return catalogCache
end

function LPL.MacroIcons:Filter(sectionKey, searchText)
    local catalog = self:GetCatalog()
    local needle = string.lower(searchText or "")
    local out = {}
    for _, entry in ipairs(catalog.entries) do
        local sectionOk = sectionKey == "all" or entry.section == sectionKey
        local searchOk = needle == "" or (entry.search and entry.search:find(needle, 1, true))
        if sectionOk and searchOk then
            out[#out + 1] = entry
        end
    end
    return out
end

function LPL.MacroIcons:SetTexture(textureWidget, texture)
    if not textureWidget then
        return
    end
    if type(texture) == "number" then
        textureWidget:SetTexture(texture)
    elseif type(texture) == "string" and texture ~= "" then
        if texture:find("\\", 1, true) or texture:find("/", 1, true) then
            textureWidget:SetTexture(texture)
        else
            textureWidget:SetTexture("Interface\\Icons\\" .. texture)
        end
    else
        textureWidget:SetTexture(QUESTION_MARK)
    end
end

function LPL.MacroIcons:GetQuestionMark()
    return QUESTION_MARK
end
