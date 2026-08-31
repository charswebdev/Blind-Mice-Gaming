local ADDON_NAME, ns = ...

local Panel = {}
ns.Panel = Panel

local ROW_COUNT = 10

local function Backdrop(frame, bg, border)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local ROYAL = { 0.255, 0.412, 0.882, 1 }
local ROYAL_HOVER = { 0.35, 0.52, 0.95, 1 }
local ROYAL_BORDER = { 0.18, 0.30, 0.70, 1 }

local function MakeButton(parent, text, width, tooltip)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(width or 88, 22)
	Backdrop(b, ROYAL, ROYAL_BORDER)
	local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("CENTER")
	label:SetText(text)
	label:SetTextColor(1, 1, 1, 1)
	b.label = label
	b:SetScript("OnEnter", function(self)
		self:SetBackdropColor(ROYAL_HOVER[1], ROYAL_HOVER[2], ROYAL_HOVER[3], ROYAL_HOVER[4])
		if tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(text)
			GameTooltip:AddLine(tooltip, 0.85, 0.85, 0.85, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self:SetBackdropColor(ROYAL[1], ROYAL[2], ROYAL[3], ROYAL[4])
		GameTooltip:Hide()
	end)
	return b
end

function Panel:Create()
	if self.frame then
		return self.frame
	end

	local f = CreateFrame("Frame", "FPSDiagPanel", UIParent, "BackdropTemplate")
	f:SetSize(660, 748)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:Hide()
	Backdrop(f, { 0.07, 0.08, 0.10, 0.96 }, { 0.32, 0.34, 0.38, 1 })
	tinsert(UISpecialFrames, "FPSDiagPanel")

	local db = ns.db and ns.db.panel or { point = "CENTER", x = 0, y = 0 }
	f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		ns.db.panel.point = point
		ns.db.panel.x = x
		ns.db.panel.y = y
	end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("FPSDiag")

	local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	subtitle:SetText("Blind Mice Gaming  ·  addon vs game")

	local close = MakeButton(f, "Close", 64)
	close:SetPoint("TOPRIGHT", -12, -12)
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	local record = MakeButton(f, "Record", 80)
	record:SetPoint("RIGHT", close, "LEFT", -8, 0)
	record:SetScript("OnClick", function()
		if ns.Profiler.recording then
			ns.Profiler:StopRecording()
		else
			ns.Profiler:StartRecording()
		end
		Panel:Refresh()
	end)

	local fps = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	fps:SetPoint("TOPLEFT", 16, -52)

	local cause = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	cause:SetPoint("LEFT", fps, "RIGHT", 16, 0)

	local context = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	context:SetPoint("TOPLEFT", 16, -88)
	context:SetPoint("TOPRIGHT", -16, -88)
	context:SetJustifyH("LEFT")

	local barBack = CreateFrame("Frame", nil, f, "BackdropTemplate")
	barBack:SetPoint("TOPLEFT", 16, -112)
	barBack:SetPoint("TOPRIGHT", -16, -112)
	barBack:SetHeight(18)
	Backdrop(barBack, { 0.12, 0.13, 0.15, 1 }, { 0.25, 0.26, 0.28, 1 })

	local addonBar = barBack:CreateTexture(nil, "ARTWORK")
	addonBar:SetColorTexture(0.90, 0.55, 0.18, 1)
	addonBar:SetPoint("TOPLEFT", 1, -1)
	addonBar:SetPoint("BOTTOMLEFT", 1, 1)

	local clientBar = barBack:CreateTexture(nil, "ARTWORK")
	clientBar:SetColorTexture(0.32, 0.58, 0.92, 1)
	clientBar:SetPoint("TOPLEFT", addonBar, "TOPRIGHT", 0, 0)
	clientBar:SetPoint("BOTTOMLEFT", addonBar, "BOTTOMRIGHT", 0, 0)

	local barLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	barLabel:SetPoint("TOPLEFT", barBack, "BOTTOMLEFT", 0, -6)
	barLabel:SetPoint("TOPRIGHT", barBack, "BOTTOMRIGHT", 0, -6)
	barLabel:SetJustifyH("LEFT")

	local COLS = {
		{ key = "name", label = "Addon", x = 8, w = 200, justify = "LEFT" },
		{ key = "recent", label = "Recent", x = 216, w = 78, justify = "RIGHT" },
		{ key = "last", label = "Last", x = 302, w = 78, justify = "RIGHT" },
		{ key = "peak", label = "Peak", x = 388, w = 78, justify = "RIGHT" },
		{ key = "over", label = ">50ms", x = 474, w = 62, justify = "RIGHT" },
		{ key = "memory", label = "Memory", x = 544, w = 84, justify = "RIGHT" },
	}

	local minuteBack = CreateFrame("Frame", nil, f, "BackdropTemplate")
	minuteBack:SetPoint("TOPLEFT", barLabel, "BOTTOMLEFT", 0, -10)
	minuteBack:SetPoint("TOPRIGHT", barLabel, "BOTTOMRIGHT", 0, -10)
	minuteBack:SetHeight(92)
	Backdrop(minuteBack, { 0.10, 0.11, 0.14, 1 }, { 0.28, 0.30, 0.34, 1 })

	local minuteHead = minuteBack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	minuteHead:SetPoint("TOPLEFT", 10, -6)
	minuteHead:SetText("Hardest hit in the last 60 seconds")

	local minuteRows = {}
	local minuteLabels = { "Hardest", "Next" }
	local prev = minuteHead
	for i = 1, 2 do
		local label = minuteBack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -8)
		label:SetText(minuteLabels[i])
		local value = minuteBack:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
		value:SetPoint("RIGHT", -10, 0)
		value:SetJustifyH("LEFT")
		value:SetWordWrap(false)
		if i == 1 then
			value:SetText("Collecting samples…")
		end
		minuteRows[i] = { label = label, value = value }
		prev = value
	end
	minuteRows[2].label:Hide()
	minuteRows[2].value:Hide()

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", minuteBack, "BOTTOMLEFT", 0, -10)
	header:SetPoint("TOPRIGHT", minuteBack, "BOTTOMRIGHT", 0, -10)
	header:SetHeight(18)
	for _, col in ipairs(COLS) do
		local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", col.x, 0)
		fs:SetWidth(col.w)
		fs:SetJustifyH(col.justify)
		fs:SetText(col.label)
	end

	local rows = {}
	for i = 1, ROW_COUNT do
		local row = CreateFrame("Frame", nil, f, "BackdropTemplate")
		row:SetHeight(22)
		row:SetPoint("LEFT", 16, 0)
		row:SetPoint("RIGHT", -16, 0)
		if i == 1 then
			row:SetPoint("TOP", header, "BOTTOM", 0, -4)
		else
			row:SetPoint("TOP", rows[i - 1], "BOTTOM", 0, -1)
		end
		if i % 2 == 0 then
			Backdrop(row, { 1, 1, 1, 0.03 }, { 0, 0, 0, 0 })
		else
			Backdrop(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
		end
		for _, col in ipairs(COLS) do
			local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetPoint("LEFT", col.x, 0)
			fs:SetWidth(col.w)
			fs:SetJustifyH(col.justify)
			row[col.key] = fs
		end
		rows[i] = row
	end

	local hitchTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hitchTitle:SetPoint("TOPLEFT", rows[ROW_COUNT], "BOTTOMLEFT", 0, -14)
	hitchTitle:SetText("Recent hitches (over 50 ms)")

	local hitchText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hitchText:SetPoint("TOPLEFT", hitchTitle, "BOTTOMLEFT", 0, -6)
	hitchText:SetPoint("RIGHT", -16, 0)
	hitchText:SetJustifyH("LEFT")
	hitchText:SetSpacing(3)

	local adviceBack = CreateFrame("Frame", nil, f, "BackdropTemplate")
	adviceBack:SetPoint("BOTTOMLEFT", 16, 16)
	adviceBack:SetPoint("BOTTOMRIGHT", -16, 16)
	adviceBack:SetHeight(78)
	Backdrop(adviceBack, { 0.10, 0.11, 0.14, 1 }, { 0.28, 0.30, 0.34, 1 })

	local memBtn = MakeButton(f, "Clear Memory", 150, "Force Lua garbage collection for addon memory. Same idea as HyperFrame.")
	memBtn:SetPoint("BOTTOMLEFT", adviceBack, "TOPLEFT", 0, 10)
	memBtn:SetScript("OnClick", function()
		if ns.Tools then
			ns.Tools.ClearAddonMemory()
		end
	end)
	hitchText:SetPoint("BOTTOMLEFT", memBtn, "TOPLEFT", 0, 10)

	local vramBtn = MakeButton(f, "Compact VRAM", 150, "Restart the graphics engine to reclaim GPU memory. The screen may hitch.")
	vramBtn:SetPoint("LEFT", memBtn, "RIGHT", 8, 0)
	vramBtn:SetScript("OnClick", function()
		if ns.Tools then
			ns.Tools.CompactVRAM()
		end
	end)

	local avBtn = MakeButton(f, "Restart A/V", 150, "Restart the audio engine and graphics engine.")
	avBtn:SetPoint("LEFT", vramBtn, "RIGHT", 8, 0)
	avBtn:SetScript("OnClick", function()
		if ns.Tools then
			ns.Tools.RestartAudioVideo()
		end
	end)

	local advice = adviceBack:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	advice:SetPoint("TOPLEFT", 10, -10)
	advice:SetPoint("BOTTOMRIGHT", -10, 10)
	advice:SetJustifyH("LEFT")
	advice:SetJustifyV("TOP")
	advice:SetWordWrap(true)

	self.frame = f
	self.fps = fps
	self.cause = cause
	self.context = context
	self.addonBar = addonBar
	self.clientBar = clientBar
	self.barBack = barBack
	self.barLabel = barLabel
	self.rows = rows
	self.hitchText = hitchText
	self.advice = advice
	self.record = record
	self.minuteRows = minuteRows
	return f
end

function Panel:IsShown()
	return self.frame and self.frame:IsShown()
end

function Panel:Show()
	if not self.frame then
		self:Create()
	end
	if ns.Profiler then
		ns.Profiler.lastMemUpdate = nil
		ns.Profiler:Sample()
	end
	self.frame:Show()
	self:Refresh()
end

function Panel:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function Panel:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

function Panel:Refresh()
	if not self.frame or not self.frame:IsShown() then
		return
	end
	local snap = ns.Profiler and ns.Profiler:GetSnapshot()
	if not snap then
		return
	end

	self.fps:SetText(ns.FormatFPS(snap.fps))
	local cause, advice = ns.Classifier.Classify(snap)
	self.cause:SetText(cause)
	self.cause:SetTextColor(ns.Classifier.CauseColor(cause))
	self.advice:SetText(advice)

	if ns.Profiler.recording then
		self.record.label:SetText("Stop")
	else
		self.record.label:SetText("Record")
	end

	local combat = snap.inCombat and "Combat" or "Out of combat"
	if snap.inEncounter then
		combat = "Encounter"
	end
	local rec = snap.recording and "  ·  Recording" or ""
	self.context:SetText(string.format(
		"%s  ·  %s  ·  %d nameplates  ·  World %dms  ·  Home %dms  ·  CPU-bound %s%s",
		snap.zone ~= "" and snap.zone or "Unknown zone",
		combat,
		snap.nameplates or 0,
		snap.latencyWorld or 0,
		snap.latencyHome or 0,
		snap.cpuBound == nil and "?" or (snap.cpuBound and "yes" or "no"),
		rec
	))

	local width = self.barBack:GetWidth() - 2
	if width < 10 then
		width = 480
	end
	local budget = math.max(snap.appMs or 0, snap.frameMs or 16.7, 1)
	local addonShare = math.min(1, (snap.addonMs or 0) / budget)
	local residualShare = math.min(1 - addonShare, (snap.residualMs or 0) / budget)
	self.addonBar:SetWidth(math.max(1, width * addonShare))
	self.clientBar:SetWidth(math.max(1, width * residualShare))
	self.barLabel:SetText(string.format(
		"Addons %s (%.0f%%)   Game leftover %s (%.0f%%)   Frame ~%s   Hitches >50ms: %d   >100ms: %d",
		ns.FormatMs(snap.addonMs),
		addonShare * 100,
		ns.FormatMs(snap.residualMs),
		residualShare * 100,
		ns.FormatMs(snap.frameMs),
		snap.over50 or 0,
		snap.over100 or 0
	))

	for i = 1, ROW_COUNT do
		local row = self.rows[i]
		local data = snap.top and snap.top[i]
		if data then
			local suffix = data.self and "  (this addon)" or ""
			row.name:SetText((data.title or data.name) .. suffix)
			row.recent:SetText(ns.FormatMs(data.recent))
			row.last:SetText(ns.FormatMs(data.last))
			if data.kind == "game" then
				row.peak:SetText("—")
				row.over:SetText("—")
				row.memory:SetText("—")
			else
				row.peak:SetText(ns.FormatMs(data.peak))
				row.over:SetText(tostring(math.floor(data.over50 or 0)))
				row.memory:SetText(ns.FormatMem(data.memory))
			end
			if data.kind == "game" then
				row.name:SetTextColor(0.40, 0.70, 1.00)
			elseif data.self then
				row.name:SetTextColor(0.55, 0.55, 0.55)
			elseif i == 1 then
				row.name:SetTextColor(0.95, 0.70, 0.30)
			else
				row.name:SetTextColor(0.90, 0.90, 0.90)
			end
			row:Show()
		else
			row.name:SetText("")
			row.recent:SetText("")
			row.last:SetText("")
			row.peak:SetText("")
			row.over:SetText("")
			row.memory:SetText("")
		end
	end

	local minute = ns.Profiler.GetMinuteWorst and ns.Profiler:GetMinuteWorst()
	local rows = self.minuteRows
	if not minute or #minute == 0 then
		rows[1].label:SetText("Hardest")
		rows[1].value:SetText("Collecting samples. Keep the overlay on, or leave this panel open.")
		rows[1].value:SetTextColor(0.70, 0.70, 0.70)
		rows[2].label:Hide()
		rows[2].value:Hide()
	else
		local headers = { "Hardest", "Next" }
		for i = 1, 2 do
			local data = minute[i]
			if data and (data.ms or 0) > 0 then
				local kind = data.kind == "game" and "Game UI" or "Addon"
				rows[i].label:SetText(headers[i])
				rows[i].label:Show()
				rows[i].value:SetText(string.format("%s  ·  %s  ·  peak %s", data.title or data.name, kind, ns.FormatMs(data.ms)))
				if data.kind == "game" then
					rows[i].value:SetTextColor(0.40, 0.70, 1.00)
				else
					rows[i].value:SetTextColor(0.95, 0.70, 0.30)
				end
				rows[i].value:Show()
			else
				rows[i].label:Hide()
				rows[i].value:Hide()
			end
		end
	end

	local hitches = ns.Profiler:GetHitches()
	if not hitches or #hitches == 0 then
		self.hitchText:SetText("None yet this session.")
	else
		local lines = {}
		local n = math.min(4, #hitches)
		for i = 1, n do
			local h = hitches[i]
			local who = h.addon and ns.AddonTitle(h.addon) or "Frame hitch"
			lines[#lines + 1] = string.format("%s  %s  %s", who, ns.FormatMs(h.ms), h.zone ~= "" and h.zone or "")
		end
		self.hitchText:SetText(table.concat(lines, "\n"))
	end
end
