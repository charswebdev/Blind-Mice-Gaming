local addonName, LPL = ...

LPL.MainFrame = {}

local MIN_WIDTH = 720
local MIN_HEIGHT = 480
local FRAME_NAME = "LPLMainFrame"
local PROFILE_ICON_SIZE = 32

local function CreateProfileIcon(titleBar)
    if not titleBar then
        return
    end

    local portrait = titleBar:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(PROFILE_ICON_SIZE, PROFILE_ICON_SIZE)
    portrait:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    if not LPL:SetIconTexture(portrait, "lpl_64") then
        portrait:SetTexture(LPL.Icons.ADDON_64 or LPL:GetIconPath("lpl", 64))
    end
    portrait:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    titleBar.profileIcon = portrait
end

local function RegisterEscapeClose(frame)
    local frameName = frame:GetName()
    _G[frameName] = frame

    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == frameName then
            table.remove(UISpecialFrames, index)
        end
    end
    table.insert(UISpecialFrames, 1, frameName)
end

local function UpdateLockButton(lockBtn, locked)
    if not lockBtn then
        return
    end
    if locked then
        lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Down")
        lockBtn:SetHighlightTexture("Interface\\Buttons\\LockButton-Locked-Highlight")
    else
        lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
        lockBtn:SetHighlightTexture("Interface\\Buttons\\LockButton-Unlocked-Highlight")
    end
end

function LPL.MainFrame:IsLocked()
    return LPL.DB and LPL.DB:IsFrameLocked()
end

function LPL.MainFrame:SetLocked(locked)
    locked = locked == true
    if LPL.DB then
        LPL.DB:SetFrameLocked(locked)
    end
    local frame = self.frame
    if not frame then
        return
    end
    frame:SetMovable(not locked)
    frame:SetResizable(not locked)
    if locked then
        LPL.DB:SaveFrameState(frame)
    end
    if frame.resizer then
        if locked then
            frame.resizer:Hide()
        else
            frame.resizer:Show()
        end
    end
    UpdateLockButton(frame.lockBtn, locked)
end

function LPL.MainFrame:Hide()
    if not self.frame then
        return
    end
    self.frame:Hide()
    if LPL.DB and LPL.DB.GetUI then
        LPL.DB:GetUI().shown = false
    end
end

function LPL.MainFrame:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    self.frame = frame
    frame:Hide()

    frame:SetSize(980, 680)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 1400, 900)
    else
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
        frame:SetMaxResize(1400, 900)
    end
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")

    LPL.DB:RestoreFrameState(frame)

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(36)
    LPL.Theme:ApplyBackdrop(titleBar, "panel", "titleBar", "border")

    local titleText = LPL:CreateLabel(titleBar, "header")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 14, 0)
    titleText:SetText("Light Paws Loadouts")

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        LPL.MainFrame:Hide()
    end)

    local lockBtn = CreateFrame("Button", nil, titleBar)
    lockBtn:SetSize(16, 16)
    lockBtn:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    lockBtn:SetScript("OnClick", function()
        LPL.MainFrame:SetLocked(not LPL.MainFrame:IsLocked())
    end)
    lockBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        if LPL.MainFrame:IsLocked() then
            GameTooltip:SetText("Unlock to move window", 1, 1, 1)
        else
            GameTooltip:SetText("Lock window position", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.lockBtn = lockBtn
    frame.closeButton = closeButton

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not LPL.MainFrame:IsLocked() then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if not LPL.MainFrame:IsLocked() then
            LPL.DB:SaveFrameState(frame)
        end
    end)

    local resizer = CreateFrame("Button", nil, frame)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function()
        if not LPL.MainFrame:IsLocked() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if not LPL.MainFrame:IsLocked() then
            LPL.DB:SaveFrameState(frame)
        end
    end)
    frame.resizer = resizer

    LPL.Sidebar:Create(frame)
    LPL.ContentHost:Create(frame)
    CreateProfileIcon(titleBar)

    frame.titleBar = titleBar

    frame:SetScript("OnShow", function()
        if LPL.Modules and LPL.Modules.Activate then
            local activeID = LPL.Modules:GetActiveID()
            if not activeID then
                LPL.Modules:Activate(LPL.DB:GetUI().lastTab or "talents")
            end
        end
        LPL.Sidebar:RefreshActiveTab()
        LPL.DB:GetUI().shown = true
    end)

    frame:SetScript("OnHide", function()
        LPL.DB:GetUI().shown = false
    end)

    RegisterEscapeClose(frame)
    self:SetLocked(self:IsLocked())
    self:EnsureHidden()

    return frame
end

function LPL.MainFrame:EnsureHidden()
    if self.frame then
        self.frame:Hide()
    end
    if LPL.DB and LPL.DB.GetUI then
        LPL.DB:GetUI().shown = false
    end
end

function LPL.MainFrame:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self:Hide()
    else
        self.frame:Show()
        local lastTab = LPL.DB:GetUI().lastTab or "talents"
        LPL.Modules:Activate(lastTab)
    end
end

function LPL.MainFrame:Show()
    if not self.frame then
        return
    end
    self.frame:Show()
    local lastTab = LPL.DB:GetUI().lastTab or "talents"
    LPL.Modules:Activate(lastTab)
end
