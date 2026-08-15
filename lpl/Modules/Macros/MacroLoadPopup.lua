local addonName, LPL = ...

LPL.MacroLoadPopup = {}

local FRAME_NAME = "LPLMacroLoadPopup"
local ROW_HEIGHT = 28

local function CollectLiveMacros()
    local list = {}
    local numAccount, numCharacter = GetNumMacros()
    numAccount = numAccount or 0
    numCharacter = numCharacter or 0

    local function push(index, scope)
        local name, icon, body = GetMacroInfo(index)
        if not name then
            return
        end
        list[#list + 1] = {
            index = index,
            scope = scope,
            name = name,
            icon = icon,
            body = body or "",
        }
    end

    for i = 1, numAccount do
        push(i, "Account")
    end
    local charStart = (MAX_ACCOUNT_MACROS or 120) + 1
    for i = charStart, charStart + numCharacter - 1 do
        push(i, "Character")
    end
    return list
end

function LPL.MacroLoadPopup:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(420, 380)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(225)
    frame:EnableMouse(true)
    frame:Hide()
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    LPL.Theme:ApplyBackdrop(titleBar, "panel", "titleBar", "border")

    local title = LPL:CreateLabel(titleBar, "header")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    title:SetText("Load from Macros")

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 12, -8)
    hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -8)
    hint:SetJustifyH("LEFT")
    hint:SetText("Loads into the editor. Save writes back to that Account/Character macro and to your LPL library.")
    hint:SetTextColor(LPL.Theme:GetColor("textMuted"))

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 16)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
    frame.content = content
    frame.rows = {}

    local function SyncContentWidth()
        local width = math.max((scroll:GetWidth() or 0) - 4, 100)
        content:SetWidth(width)
    end

    scroll:HookScript("OnSizeChanged", SyncContentWidth)

    function frame:ClearRows()
        for _, row in ipairs(self.rows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(self.rows)
    end

    function frame:Rebuild(onPick)
        self:ClearRows()
        SyncContentWidth()
        local macros = CollectLiveMacros()
        if #macros == 0 then
            local empty = self.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -4)
            empty:SetText("No account or character macros found.")
            local holder = CreateFrame("Frame", nil, self.content)
            holder:Hide()
            self.rows[1] = holder
            self.content:SetHeight(40)
            return
        end

        local y = 0
        local goldR, goldG, goldB, goldA = LPL.Theme:GetColor("textLabel")
        for _, macro in ipairs(macros) do
            local row = CreateFrame("Button", nil, self.content, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -y)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            LPL.MacroIcons:SetTexture(icon, macro.icon)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(string.format("[%s] %s", macro.scope, macro.name or ""))
            label:SetTextColor(goldR, goldG, goldB, goldA or 1)

            row:SetScript("OnEnter", function(self)
                LPL.Theme:ApplyBackdrop(self, "button", "bgButtonHover", "classListBorder")
            end)
            row:SetScript("OnLeave", function(self)
                if self.ClearBackdrop then
                    self:ClearBackdrop()
                elseif self.SetBackdrop then
                    self:SetBackdrop(nil)
                end
            end)
            row:SetScript("OnClick", function()
                frame:Hide()
                if onPick then
                    onPick(macro)
                end
            end)

            self.rows[#self.rows + 1] = row
            y = y + ROW_HEIGHT + 2
        end
        self.content:SetHeight(math.max(y, 40))
    end

    self.frame = frame
    return frame
end

function LPL.MacroLoadPopup:Show(onPick)
    local frame = self:EnsureFrame()
    frame:Rebuild(onPick)
    frame:Show()
end
