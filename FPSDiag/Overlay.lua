local ADDON_NAME, ns = ...

local Overlay = {}
ns.Overlay = Overlay

local function Backdrop(frame, bg, border)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

function Overlay:Create()
	if self.frame then
		return self.frame
	end

	local f = CreateFrame("Button", "FPSDiagOverlay", UIParent, "BackdropTemplate")
	f:SetSize(340, 58)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	Backdrop(f, { 0.06, 0.07, 0.09, 0.92 }, { 0.28, 0.30, 0.34, 1 })

	local db = ns.db and ns.db.overlay or { point = "TOP", x = 0, y = -24 }
	f:SetPoint(db.point or "TOP", UIParent, db.point or "TOP", db.x or 0, db.y or -24)

	local dragged = false
	f:SetScript("OnDragStart", function(self)
		dragged = true
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		ns.db.overlay.point = point
		ns.db.overlay.x = x
		ns.db.overlay.y = y
		C_Timer.After(0, function()
			dragged = false
		end)
	end)
	f:SetScript("OnClick", function(_, button)
		if dragged then
			return
		end
		if button == "RightButton" then
			Overlay:SetShown(false)
			ns.Print("Overlay hidden. Type /fps overlay to show it again.")
		else
			if ns.Panel then
				ns.Panel:Toggle()
			end
		end
	end)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("FPSDiag")
		GameTooltip:AddLine("Left-click: open panel", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-click: hide overlay", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local fps = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fps:SetPoint("TOPLEFT", 10, -7)
	fps:SetText("— FPS")

	local cause = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	cause:SetPoint("TOPRIGHT", -10, -9)
	cause:SetText("WAIT")

	local who = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	who:SetPoint("BOTTOMLEFT", 10, 8)
	who:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 40, 8)
	who:SetJustifyH("LEFT")
	who:SetWordWrap(false)
	who:SetText("Game UI")

	local cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cost:SetPoint("BOTTOMRIGHT", -10, 8)
	cost:SetJustifyH("RIGHT")
	cost:SetText("—")

	self.frame = f
	self.fps = fps
	self.cause = cause
	self.who = who
	self.cost = cost
	self.detail = who
	return f
end

function Overlay:IsShown()
	return self.frame and self.frame:IsShown()
end

function Overlay:SetShown(shown)
	if not self.frame then
		self:Create()
	end
	ns.db.overlayShown = shown and true or false
	if shown then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end

function Overlay:Toggle()
	self:SetShown(not self:IsShown())
end

function Overlay:Refresh()
	if not self.frame or not self.frame:IsShown() then
		return
	end
	local snap = ns.Profiler and ns.Profiler:GetSnapshot()
	if not snap then
		return
	end

	self.fps:SetText(ns.FormatFPS(snap.fps))
	local cause, advice = ns.Classifier.Classify(snap)
	self.cause:SetText(string.upper(cause))
	self.cause:SetTextColor(ns.Classifier.CauseColor(cause))

	local heaviest = ns.Classifier.Heaviest(snap)
	local title = heaviest.title or ns.GAME_UI_TITLE or "Game UI"
	if strlen(title) > 28 then
		title = strsub(title, 1, 26) .. ".."
	end
	self.who:SetText(title)
	if heaviest.kind == "game" then
		self.who:SetTextColor(0.40, 0.70, 1.00)
	else
		self.who:SetTextColor(0.95, 0.70, 0.30)
	end
	self.cost:SetText(ns.FormatMs(heaviest.ms))
	self.advice = advice
end
