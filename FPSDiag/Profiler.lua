local ADDON_NAME, ns = ...

local Profiler = {}
ns.Profiler = Profiler

local SAMPLE_IDLE = 0.50
local SAMPLE_ACTIVE = 0.25
local FRAME_SMOOTH = 0.15
local HITCH_MS = 50
local MAX_HITCHES = 20
local MAX_RECORD_SAMPLES = 480

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

local function CollectTop(metric, k)
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

	if not C_AddOns or not C_AddOns.GetNumAddOns then
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

function Profiler:Sample()
	wipe(snapshot.top)
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
		return snapshot
	end

	local M = MetricEnum()
	local recentMetric = (ns.inEncounter and M.EncounterAverageTime) or M.RecentAverageTime

	snapshot.addonMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, recentMetric)
	snapshot.addonLastMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.LastTime)
	snapshot.addonPeakMs = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.PeakTime)
	snapshot.appMs = SafeMetric(C_AddOnProfiler.GetApplicationMetric, recentMetric)
	snapshot.appLastMs = SafeMetric(C_AddOnProfiler.GetApplicationMetric, M.LastTime)
	snapshot.over10 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver10Ms)
	snapshot.over50 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver50Ms)
	snapshot.over100 = SafeMetric(C_AddOnProfiler.GetOverallMetric, M.CountTimeOver100Ms)
	snapshot.residualMs = math.max(0, snapshot.appMs - snapshot.addonMs)

	local ranked = CollectTop(recentMetric, 12)
	self:_RefreshMemory()
	for i = 1, #ranked do
		local name = ranked[i].name
		snapshot.top[i] = {
			name = name,
			title = ns.AddonTitle(name),
			recent = ranked[i].value,
			last = SafeAddonMetric(name, M.LastTime),
			peak = SafeAddonMetric(name, M.PeakTime),
			over50 = SafeAddonMetric(name, M.CountTimeOver50Ms),
			over100 = SafeAddonMetric(name, M.CountTimeOver100Ms),
			memory = self:_AddonMemory(name),
			self = ns.IsSelf(name),
		}
	end

	local worst = snapshot.top[1]
	if worst and not worst.self and worst.last >= HITCH_MS then
		self:_AddHitch(worst.name, worst.last, "addon")
	elseif snapshot.addonLastMs >= HITCH_MS then
		self:_AddHitch(worst and worst.name or nil, snapshot.addonLastMs, "addons")
	end

	if self.recording then
		recordSamples[#recordSamples + 1] = {
			time = snapshot.time,
			fps = snapshot.fps,
			addonMs = snapshot.addonMs,
			residualMs = snapshot.residualMs,
			topName = worst and worst.name or nil,
			topMs = worst and worst.recent or 0,
		}
		while #recordSamples > MAX_RECORD_SAMPLES do
			table.remove(recordSamples, 1)
		end
	end

	return snapshot
end

function Profiler:_RefreshMemory()
	local now = GetTime()
	if self.lastMemUpdate and (now - self.lastMemUpdate) < 2 then
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
	self:Sample()
end

function Profiler:StopRecording()
	self.recording = false
	local elapsed = self.recordStarted and (GetTime() - self.recordStarted) or 0
	ns.Print(string.format("Recording stopped (%.0f seconds, %d samples).", elapsed, #recordSamples))
	self:Sample()
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
		self:NoteFrame(elapsed)
		accum = accum + elapsed
		local interval = SAMPLE_IDLE
		if self.recording or (ns.Panel and ns.Panel:IsShown()) then
			interval = SAMPLE_ACTIVE
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
