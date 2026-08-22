local ADDON_NAME, ns = ...

local Profiler = {}
ns.Profiler = Profiler

-- Blizzard's RecentAverageTime is already a 60-tick rolling average.
-- Reading it more often does not make it more accurate — it only costs FPS.
local SAMPLE_IDLE = 1.00
local SAMPLE_PANEL = 1.00
local SAMPLE_RECORD = 0.50
local FRAME_SMOOTH = 0.15
local HITCH_MS = 50
local MAX_HITCHES = 20
local MAX_RECORD_SAMPLES = 480
local MEM_INTERVAL = 8
local TOP_OVERLAY = 5
local TOP_PANEL = 10

local snapshot = {
	top = {},
}

local hitches = {}
local recordSamples = {}

local function MetricEnum()
	return Enum and Enum.AddOnProfilerMetric
end

local function SafeMetric(fn, metric, fallback)
	if not fn or metric == nil then
		return fallback or 0
	end
	local ok, value = pcall(fn, metric)
	if not ok then
		return fallback or 0
	end
	return tonumber(value) or 0
end

local function SafeAddonMetric(name, metric)
	if not C_AddOnProfiler or not C_AddOnProfiler.GetAddOnMetric or metric == nil then
		return 0
	end
	local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, name, metric)
	if not ok then
		return 0
	end
	return tonumber(value) or 0
end

function Profiler:HasAPI()
	return C_AddOnProfiler
		and C_AddOnProfiler.GetOverallMetric
		and C_AddOnProfiler.GetApplicationMetric
		and MetricEnum() ~= nil
end

function Profiler:GetSnapshot()
	return snapshot
end

function Profiler:GetHitches()
	return hitches
end

function Profiler:GetRecordSamples()
	return recordSamples
end

function Profiler:IsLive()
	return self.recording
		or (ns.Overlay and ns.Overlay:IsShown())
		or (ns.Panel and ns.Panel:IsShown())
end

local function CollectTop(metric, k, allowScan)
	local list = {}
	if C_AddOnProfiler.GetTopKAddOnsForMetric then
		local ok, results = pcall(C_AddOnProfiler.GetTopKAddOnsForMetric, metric, k)
		if ok and type(results) == "table" then
			for i = 1, #results do
				local row = results[i]
				local name = row.addOnName or row.AddOnName or row.name
				if name then
					list[#list + 1] = {
						name = name,
						value = tonumber(row.metricValue or row.MetricValue or row.value) or 0,
					}
				end
			end
			return list
		end
	end

	-- Full addon scan is expensive (Titan-style suites have dozens of folders).
	-- Only do it when the panel is open and GetTopK is missing.
	if not allowScan or not C_AddOns or not C_AddOns.GetNumAddOns then
		return list
	end
	local num = C_AddOns.GetNumAddOns() or 0
	for i = 1, num do
		local name, _, _, _, _, security = C_AddOns.GetAddOnInfo(i)
		if name and security ~= "SECURE" and C_AddOns.IsAddOnLoaded(i) then
			list[#list + 1] = {
				name = name,
				value = SafeAddonMetric(name, metric),
			}
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > k do
		list[#list] = nil
	end
	return list
end

function Profiler:NoteFrame(elapsed)
	local frameMs = (elapsed or 0) * 1000
	if not self.frameMs then
		self.frameMs = frameMs
	else
		self.frameMs = self.frameMs + (frameMs - self.frameMs) * FRAME_SMOOTH
	end
	if frameMs >= HITCH_MS then
		self:_AddHitch(nil, frameMs, "frame")
	end
end

function Profiler:_AddHitch(addonName, ms, kind)
	local now = GetTime()
	local last = hitches[1]
	if last and (now - last.time) < 0.20 and last.ms >= (ms - 1) then
		return
	end
	table.insert(hitches, 1, {
		time = now,
		addon = addonName,
		ms = ms,
		kind = kind or "addon",
		zone = GetZoneText and GetZoneText() or "",
		combat = ns.inCombat and true or false,
	})
	while #hitches > MAX_HITCHES do
		hitches[#hitches] = nil
	end
end

local function RecycleTop(count)
	local top = snapshot.top
	for i = #top, count + 1, -1 do
		top[i] = nil
	end
	return top
end

local function FillAddonRow(row, name, recent, last, peak, over50, over100, memory)
	row = row or {}
	row.name = name
	row.title = ns.AddonTitle(name)
	row.recent = recent or 0
	row.last = last or 0
	row.peak = peak or 0
	row.over50 = over50 or 0
	row.over100 = over100 or 0
	row.memory = memory or 0
	row.self = ns.IsSelf(name)
	row.kind = "addon"
	return row
end

local function FillGameRow(row, recent, last)
	row = row or {}
	row.name = "GameUI"
	row.title = ns.GAME_UI_TITLE
	row.recent = recent or 0
	row.last = last or 0
	row.peak = 0
	row.over50 = 0
	row.over100 = 0
	row.memory = 0
	row.self = false
	row.kind = "game"
	return row
end

function Profiler:_SetHeaviest()
	local addonRow
	for i = 1, #snapshot.top do
		local row = snapshot.top[i]
		if row and row.kind ~= "game" and not row.self then
			addonRow = row
			break
		end
	end
	local gameMs = snapshot.residualMs or 0
	local addonMs = addonRow and addonRow.recent or 0
	if addonRow and addonMs >= gameMs then
		snapshot.heaviest = {
			kind = "addon",
			name = addonRow.name,
			title = addonRow.title,
			ms = addonMs,
		}
	else
		snapshot.heaviest = {
			kind = "game",
			name = "GameUI",
			title = ns.GAME_UI_TITLE,
			ms = gameMs,
		}
	end
end

function Profiler:_RankWithGame(addonRows, gameRecent, gameLast)
	local ranked = {}
	for i = 1, #addonRows do
		ranked[i] = addonRows[i]
	end
	ranked[#ranked + 1] = FillGameRow({}, gameRecent, gameLast)
	table.sort(ranked, function(a, b)
		if a.recent == b.recent then
			if a.kind == b.kind then
				return (a.title or "") < (b.title or "")
			end
			return a.kind == "addon"
		end
		return a.recent > b.recent
	end)
	return ranked
end

function Profiler:Sample(full)
	local panelOpen = ns.Panel and ns.Panel:IsShown()
	full = full or panelOpen or self.recording

	snapshot.time = GetTime()
	snapshot.fps = GetFramerate() or 0
	snapshot.frameMs = self.frameMs or (snapshot.fps > 0 and (1000 / snapshot.fps) or 16.7)
	snapshot.recording = self.recording and true or false
	snapshot.inCombat = ns.inCombat and true or false
	snapshot.inEncounter = ns.inEncounter and true or false
	snapshot.nameplates = ns.nameplates or 0
	snapshot.zone = GetZoneText and GetZoneText() or ""
	snapshot.subZone = GetMinimapZoneText and GetMinimapZoneText() or ""
	snapshot.instanceType = "none"
	if GetInstanceInfo then
		local _, instanceType = GetInstanceInfo()
		snapshot.instanceType = instanceType or "none"
	end

	local _, _, latencyHome, latencyWorld = GetNetStats()
	snapshot.latencyHome = latencyHome or 0
	snapshot.latencyWorld = latencyWorld or 0

	if IsCpuBound then
		local ok, bound = pcall(IsCpuBound)
		snapshot.cpuBound = ok and bound or nil
	else
		snapshot.cpuBound = nil
	end

	local scale = tonumber(GetCVar and GetCVar("RenderScale"))
	snapshot.renderScale = scale or 1

	snapshot.profiler = self:HasAPI()
	if not snapshot.profiler then
		snapshot.addonMs = 0
		snapshot.addonLastMs = 0
		snapshot.addonPeakMs = 0
		snapshot.appMs = 0
		snapshot.appLastMs = 0
		snapshot.residualMs = 0
		snapshot.over10 = 0
		snapshot.over50 = 0
		snapshot.over100 = 0
		snapshot.top = RecycleTop(0)
		snapshot.heaviest = {
			kind = "game",
			name = "GameUI",
			title = ns.GAME_UI_TITLE,
			ms = 0,
		}
		return snapshot
	end

	local M = MetricEnum()
	local recentMetric = (ns.inEncounter and M.EncounterAverageTime) or M.RecentAverageTime

	snapshot.addonMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, recentMetric)
	snapshot.addonLastMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.LastTime)
	snapshot.appMs = SafeMetric(C_AddOnProfiler.GetApplicationMetric, recentMetric)
	snapshot.appLastMs = SafeMetric(C_AddOnProfiler.GetApplicationMetric, M.LastTime)
	snapshot.residualMs = math.max(0, snapshot.appMs - snapshot.addonMs)
	local gameLast = math.max(0, (snapshot.appLastMs or 0) - (snapshot.addonLastMs or 0))

	-- Hitch counts and peak are panel-only; overlay does not need them.
	if full then
		snapshot.addonPeakMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.PeakTime)
		snapshot.over10 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver10Ms)
		snapshot.over50 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver50Ms)
		snapshot.over100 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver100Ms)
	else
		snapshot.addonPeakMs = snapshot.addonPeakMs or 0
		snapshot.over10 = snapshot.over10 or 0
		snapshot.over50 = snapshot.over50 or 0
		snapshot.over100 = snapshot.over100 or 0
	end

	local want = full and TOP_PANEL or TOP_OVERLAY
	local ranked = CollectTop(recentMetric, want, full)
	if full then
		self:_RefreshMemory()
	end

	local addonRows = {}
	for i = 1, #ranked do
		local name = ranked[i].name
		local last, peak, over50, over100, memory = 0, 0, 0, 0, 0
		if full then
			last = SafeAddonMetric(name, M.LastTime)
			peak = SafeAddonMetric(name, M.PeakTime)
			over50 = SafeAddonMetric(name, M.CountTimeOver50Ms)
			over100 = SafeAddonMetric(name, M.CountTimeOver100Ms)
			memory = self:_AddonMemory(name)
		end
		addonRows[i] = FillAddonRow(addonRows[i], name, ranked[i].value, last, peak, over50, over100, memory)
	end

	local mixed = self:_RankWithGame(addonRows, snapshot.residualMs, gameLast)
	local top = RecycleTop(#mixed)
	for i = 1, #mixed do
		top[i] = mixed[i]
	end
	snapshot.top = top
	self:_SetHeaviest()

	local worstAddon
	for i = 1, #snapshot.top do
		local row = snapshot.top[i]
		if row and row.kind == "addon" and not row.self then
			worstAddon = row
			break
		end
	end
	if full and worstAddon and worstAddon.last >= HITCH_MS then
		self:_AddHitch(worstAddon.name, worstAddon.last, "addon")
	elseif snapshot.addonLastMs >= HITCH_MS then
		self:_AddHitch(worstAddon and worstAddon.name or nil, snapshot.addonLastMs, "addons")
	end

	if self.recording then
		local heaviest = snapshot.heaviest
		recordSamples[#recordSamples + 1] = {
			time = snapshot.time,
			fps = snapshot.fps,
			addonMs = snapshot.addonMs,
			residualMs = snapshot.residualMs,
			topName = heaviest and heaviest.name or nil,
			topTitle = heaviest and heaviest.title or nil,
			topMs = heaviest and heaviest.ms or 0,
		}
		while #recordSamples > MAX_RECORD_SAMPLES do
			table.remove(recordSamples, 1)
		end
	end

	return snapshot
end

function Profiler:_RefreshMemory()
	local now = GetTime()
	if self.lastMemUpdate and (now - self.lastMemUpdate) < MEM_INTERVAL then
		return
	end
	self.lastMemUpdate = now
	if UpdateAddOnMemoryUsage then
		pcall(UpdateAddOnMemoryUsage)
	end
end

function Profiler:_AddonMemory(name)
	if GetAddOnMemoryUsage then
		local ok, kb = pcall(GetAddOnMemoryUsage, name)
		if ok then
			return tonumber(kb) or 0
		end
	end
	if C_AddOns and C_AddOns.GetAddOnMemoryUsage then
		local ok, kb = pcall(C_AddOns.GetAddOnMemoryUsage, name)
		if ok then
			return tonumber(kb) or 0
		end
	end
	return 0
end

function Profiler:StartRecording()
	wipe(recordSamples)
	self.recording = true
	self.recordStarted = GetTime()
	ns.Print("Recording started. Play normally, then /fps record to stop.")
	self:Sample(true)
end

function Profiler:StopRecording()
	self.recording = false
	local elapsed = self.recordStarted and (GetTime() - self.recordStarted) or 0
	ns.Print(string.format("Recording stopped (%.0f seconds, %d samples).", elapsed, #recordSamples))
	self:Sample(true)
end

function Profiler:Start()
	if self.started then
		return
	end
	self.started = true
	self.frameMs = nil
	local accum = 0
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(_, elapsed)
		local live = self:IsLive()
		if live then
			self:NoteFrame(elapsed)
		end
		if not live then
			accum = 0
			return
		end
		accum = accum + elapsed
		local interval = SAMPLE_IDLE
		if self.recording then
			interval = SAMPLE_RECORD
		elseif ns.Panel and ns.Panel:IsShown() then
			interval = SAMPLE_PANEL
		end
		if accum >= interval then
			accum = 0
			self:Sample()
			if ns.Overlay then
				ns.Overlay:Refresh()
			end
			if ns.Panel and ns.Panel:IsShown() then
				ns.Panel:Refresh()
			end
		end
	end)
	self:Sample()
end
