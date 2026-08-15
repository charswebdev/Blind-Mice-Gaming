local ADDON_NAME, ns = ...

local Tools = {}
ns.Tools = Tools

local function LuaMemoryKB()
	local ok, kb = pcall(collectgarbage, "count")
	if ok then
		return tonumber(kb)
	end
	return nil
end

function Tools.ClearAddonMemory()
	local before = LuaMemoryKB()
	local ok, err = pcall(collectgarbage, "collect")
	if not ok then
		ok, err = pcall(collectgarbage)
	end
	local after = LuaMemoryKB()
	if not ok then
		ns.Print("This client blocked a forced garbage collect: " .. tostring(err))
		return
	end
	if before and after then
		local freed = math.max(0, before - after)
		ns.Print(string.format(
			"Addon memory: %.2f MB -> %.2f MB (freed %.2f MB).",
			before / 1024,
			after / 1024,
			freed / 1024
		))
	else
		ns.Print("Requested addon Lua garbage collection.")
	end
end

function Tools.CompactVRAM()
	ns.Print("Compacting VRAM. The screen may hitch for a moment.")
	if RestartGx then
		local ok, err = pcall(RestartGx)
		if not ok then
			ns.Print("RestartGx failed: " .. tostring(err))
		end
	elseif ConsoleExec then
		pcall(ConsoleExec, "gxRestart")
	else
		ns.Print("Graphics restart is not available on this client.")
	end
end

function Tools.RestartAudioVideo()
	ns.Print("Restarting audio and video. Sound and the screen may hitch briefly.")
	if Sound_GameSystem_RestartSoundSystem then
		pcall(Sound_GameSystem_RestartSoundSystem)
	end
	if RestartGx then
		pcall(RestartGx)
	elseif ConsoleExec then
		pcall(ConsoleExec, "gxRestart")
	end
end
