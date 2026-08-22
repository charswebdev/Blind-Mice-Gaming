local ADDON_NAME, ns = ...

local Classifier = {}
ns.Classifier = Classifier

local FPS_OK = 55
local FPS_LOW = 50
local ADDON_MS = 3.0
local TOP_ADDON_MS = 2.5
local LAG_MS = 400
local SETTINGS_SCALE = 1.15

function Classifier.TopOffender(snapshot)
	if not snapshot or not snapshot.top then
		return nil
	end
	for i = 1, #snapshot.top do
		local row = snapshot.top[i]
		if row and row.kind ~= "game" and not row.self then
			return row
		end
	end
	return nil
end

function Classifier.Heaviest(snapshot)
	if snapshot and snapshot.heaviest then
		return snapshot.heaviest
	end
	local top = Classifier.TopOffender(snapshot)
	if top then
		return {
			kind = "addon",
			name = top.name,
			title = top.title,
			ms = top.recent,
		}
	end
	return {
		kind = "game",
		name = "GameUI",
		title = ns.GAME_UI_TITLE or "Game UI",
		ms = snapshot and snapshot.residualMs or 0,
	}
end

function Classifier.CauseColor(cause)
	if cause == "Addon" then
		return 0.95, 0.62, 0.20
	elseif cause == "Game" then
		return 0.40, 0.70, 1.00
	elseif cause == "Lag" then
		return 0.95, 0.85, 0.30
	elseif cause == "Settings" then
		return 0.75, 0.55, 0.95
	elseif cause == "OK" then
		return 0.45, 0.85, 0.50
	end
	return 0.70, 0.70, 0.70
end

function Classifier.Classify(snapshot)
	if not snapshot then
		return "Unknown", "No sample yet."
	end
	if not snapshot.profiler then
		return "Unknown", "This client has no C_AddOnProfiler API. FPSDiag Phase 1 needs Retail 11.0.7 or newer."
	end

	local top = Classifier.TopOffender(snapshot)
	local fps = snapshot.fps or 0
	local addonMs = snapshot.addonMs or 0
	local residual = snapshot.residualMs or 0
	local appMs = snapshot.appMs or 0

	if fps >= FPS_OK and (snapshot.frameMs or 0) < 32 and addonMs < 4 then
		return "OK", "Frame rate looks healthy. Keep the overlay up if you want to catch a drop later."
	end

	if (snapshot.latencyWorld or 0) >= LAG_MS and fps >= 45 then
		return "Lag", string.format(
			"This is network delay, not FPS. World latency is %d ms while you still have %.0f FPS. Do not disable addons for this.",
			snapshot.latencyWorld or 0,
			fps
		)
	end

	local addonShare = (appMs > 0.5) and (addonMs / appMs) or 0
	if addonMs >= ADDON_MS and addonShare >= 0.55 then
		if top and top.recent >= TOP_ADDON_MS then
			local extra = ""
			if top.name == "WeakAuras" or top.name == "WeakAurasOptions" then
				extra = " Use WeakAuras' own profiler: /wa pstart before a pull, /wa pstop after, /wa pprint to see which auras."
			end
			return "Addon", string.format(
				"%s is using %s of recent addon time (all addons %s, game leftover %s). Disable it or cut its work, then /reload to confirm.",
				top.title,
				ns.FormatMs(top.recent),
				ns.FormatMs(addonMs),
				ns.FormatMs(residual)
			) .. extra
		end
		return "Addon", string.format(
			"Your addons are using %s vs %s leftover for the game. Sort the list below and disable the heaviest one.",
			ns.FormatMs(addonMs),
			ns.FormatMs(residual)
		)
	end

	if residual >= 8 and residual > addonMs * 1.4 then
		local extra = ""
		if (snapshot.nameplates or 0) >= 20 then
			extra = string.format(" %d nameplates are visible — hide enemy or friendly plates and retest.", snapshot.nameplates)
		elseif snapshot.instanceType == "none" and snapshot.zone ~= "" then
			extra = string.format(" You are in %s. Crowded hubs often tank FPS even with light addons.", snapshot.zone)
		end
		return "Game", string.format(
			"Addons only used %s. The rest of the client used %s. This is the game scene or engine, not a specific addon.",
			ns.FormatMs(addonMs),
			ns.FormatMs(residual)
		) .. extra
	end

	if snapshot.cpuBound == false and (snapshot.renderScale or 1) > SETTINGS_SCALE and fps < FPS_LOW then
		return "Settings", string.format(
			"The client does not look CPU-bound and Render Scale is %.0f%%. Set it to 100%% in System > Graphics and retest. FPSDiag cannot measure GPU time directly.",
			(snapshot.renderScale or 1) * 100
		)
	end

	if top and top.recent >= TOP_ADDON_MS then
		return "Addon", string.format(
			"%s is the heaviest addon at %s recent. Game leftover is %s.",
			top.title,
			ns.FormatMs(top.recent),
			ns.FormatMs(residual)
		)
	end

	if fps < FPS_LOW then
		return "Game", string.format(
			"FPS is %.0f and addons are only %s. Likely the world, encounter, or hardware — not a single addon.",
			fps,
			ns.FormatMs(addonMs)
		)
	end

	return "OK", "No strong limiter right now. Record a fight if the drop only happens in combat."
end
