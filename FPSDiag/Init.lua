local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"

ns.defaults = {
	overlayShown = true,
	overlay = { point = "TOP", x = 0, y = -24 },
	panel = { point = "CENTER", x = 0, y = 0 },
}

local function CopyDefaults(src, dest)
	if type(dest) ~= "table" then
		dest = {}
	end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyDefaults(v, dest[k])
		elseif dest[k] == nil then
			dest[k] = v
		end
	end
	return dest
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff4aa3ffFPSDiag|r: " .. tostring(msg))
end

function ns.StripText(text)
	if not text then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|A.-|a", "")
	return text
end

function ns.AddonTitle(name)
	if not name then
		return "?"
	end
	local title
	if C_AddOns.GetAddOnTitle then
		title = C_AddOns.GetAddOnTitle(name)
	end
	if (not title or title == "") and C_AddOns.GetAddOnInfo then
		local _, infoTitle = C_AddOns.GetAddOnInfo(name)
		title = infoTitle
	end
	title = ns.StripText(title or name)
	if title == "" then
		title = name
	end
	return title
end

function ns.IsSelf(name)
	return name == ADDON_NAME or name == "FPSDiag"
end

function ns.FormatMs(value)
	value = tonumber(value) or 0
	if value <= 0 then
		return "0.00 ms"
	end
	if value >= 100 then
		return string.format("%.0f ms", value)
	end
	return string.format("%.2f ms", value)
end

function ns.FormatMem(kb)
	kb = tonumber(kb) or 0
	if kb <= 0 then
		return "0 KB"
	end
	if kb >= 1024 then
		return string.format("%.2f MB", kb / 1024)
	end
	return string.format("%.0f KB", kb)
end

function ns.FormatFPS(value)
	return string.format("%.0f FPS", tonumber(value) or 0)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then
			return
		end
		FPSDiagDB = CopyDefaults(ns.defaults, FPSDiagDB)
		ns.db = FPSDiagDB
		ns.inCombat = false
		ns.inEncounter = false
		ns.nameplates = 0
	elseif event == "PLAYER_LOGIN" then
		if ns.Profiler then
			ns.Profiler:Start()
		end
		if ns.Overlay then
			ns.Overlay:Create()
			ns.Overlay:SetShown(ns.db.overlayShown)
			ns.Overlay:Refresh()
		end
		if ns.Panel then
			ns.Panel:Create()
		end
		ns.Print("Loaded. Type |cffffffff/fps|r to open, |cffffffff/fps overlay|r to toggle the overlay.")
		if ns.Profiler and not ns.Profiler:HasAPI() then
			ns.Print("Blizzard addon profiler is not available on this client. Phase 1 needs Retail 11.0.7 or newer.")
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		ns.nameplates = 0
		if ns.Profiler then
			ns.Profiler:Sample()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		ns.inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.inCombat = false
		ns.inEncounter = false
	elseif event == "ENCOUNTER_START" then
		ns.inEncounter = true
		ns.inCombat = true
	elseif event == "ENCOUNTER_END" then
		ns.inEncounter = false
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		ns.nameplates = (ns.nameplates or 0) + 1
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		ns.nameplates = math.max(0, (ns.nameplates or 0) - 1)
	end
end)

SLASH_FPS1 = "/fps"
SlashCmdList.FPS = function(msg)
	msg = strtrim(string.lower(msg or ""))
	if msg == "" or msg == "panel" or msg == "toggle" then
		if not ns.Panel then
			ns.Print("Panel did not load. Enable FPSDiag in the AddOns list at character select, then /reload.")
			return
		end
		local ok, err = pcall(function()
			ns.Panel:Toggle()
		end)
		if not ok then
			ns.Print("Could not open the panel: " .. tostring(err))
		end
	elseif msg == "overlay" then
		if ns.Overlay then
			ns.Overlay:Toggle()
		end
	elseif msg == "record" then
		if ns.Profiler then
			if ns.Profiler.recording then
				ns.Profiler:StopRecording()
			else
				ns.Profiler:StartRecording()
			end
			if ns.Panel then
				ns.Panel:Refresh()
			end
		end
	elseif msg == "mem" or msg == "memory" then
		if ns.Tools then
			ns.Tools.ClearAddonMemory()
		end
	elseif msg == "vram" then
		if ns.Tools then
			ns.Tools.CompactVRAM()
		end
	elseif msg == "av" or msg == "audio" or msg == "video" then
		if ns.Tools then
			ns.Tools.RestartAudioVideo()
		end
	elseif msg == "help" then
		ns.Print("/fps — open or close the diagnostic panel")
		ns.Print("/fps overlay — show or hide the FPS overlay")
		ns.Print("/fps record — start or stop recording a fight")
		ns.Print("/fps mem — clear addon Lua memory")
		ns.Print("/fps vram — compact VRAM (graphics restart)")
		ns.Print("/fps av — restart audio and video")
	else
		ns.Print("Unknown command. Type /fps help")
	end
end

function FPSDiag_OnAddonCompartmentClick()
	if ns.Panel then
		ns.Panel:Toggle()
	end
end
