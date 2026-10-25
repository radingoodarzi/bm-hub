--[[
	BM Hub Full Scanner - کل ساختار بازی + بایت‌کد همه‌ی اسکریپت‌های سمت کلاینت رو توی فایل ذخیره می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_all.lua?t=" .. os.time()))()
	فقط می‌خونه و فایل می‌نویسه؛ هیچ چیزی به سرور فرستاده نمیشه. decompile نمی‌کنه (هنگ نمی‌کنه).
	خروجی: پوشه‌ی workspace خود Solara -> bmscan/
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local function notify(t)
	print("[BMALL] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Full Scanner", Text = t, Duration = 6 }) end)
end

if not writefile then
	return notify("This executor has no writefile")
end
pcall(function() if makefolder and not (isfolder and isfolder("bmscan")) then makefolder("bmscan") end end)
pcall(function() if makefolder and not (isfolder and isfolder("bmscan/bc")) then makefolder("bmscan/bc") end end)

local function fmt(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function posOf(x)
	local ok, p = pcall(function()
		if x:IsA("Model") then return x:GetPivot().Position end
		if x:IsA("BasePart") then return x.Position end
	end)
	return ok and p and fmt(p) or ""
end

---------------------------------------------------------------------
-- بخش 1: ساختار
---------------------------------------------------------------------
notify("Part 1/2: game structure...")
local out = {}
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function section(n) add("") add("===== " .. n .. " =====") end

local okStruct, structErr = pcall(function()
	section("INFO")
	local ex = "?"
	pcall(function() ex = tostring((identifyexecutor or getexecutorname)()) end)
	add("executor:", ex, "| place:", game.PlaceId, "| job:", game.JobId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	add("position:", root and fmt(root.Position) or "?")
	local caps = {}
	local env = (getgenv and getgenv()) or _G
	for _, n in ipairs({ "getscriptbytecode", "decompile", "getgc", "getconnections", "firesignal", "hookmetamethod", "hookfunction",
		"getnamecallmethod", "getrawmetatable", "setreadonly", "getsenv", "getscripts", "getloadedmodules", "getrunningscripts",
		"firetouchinterest", "fireclickdetector", "fireproximityprompt", "queue_on_teleport", "request", "setfpscap", "gethui", "getgenv" }) do
		local okV, v = pcall(function() return env[n] end)
		table.insert(caps, n .. "=" .. type(okV and v or nil))
	end
	add("caps:", table.concat(caps, " "))

	section("DATA")
	local data = player:FindFirstChild("Data")
	if data then
		for _, v in ipairs(data:GetChildren()) do
			if v:IsA("ValueBase") then add(v.Name, "=", tostring(v.Value)) end
		end
	end

	section("REMOTES")
	for i, d in ipairs(game:GetDescendants()) do
		if i % 5000 == 0 then task.wait() end
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
			add(d.ClassName, d:GetFullName())
		end
	end

	section("TAGS")
	local okTags, tags = pcall(function() return CollectionService:GetAllTags() end)
	if okTags then
		for _, t in ipairs(tags) do
			if not t:find("padding") and not t:find("data%-testid") then
				add(t, #CollectionService:GetTagged(t))
			end
		end
	end

	section("REPLICATEDSTORAGE (depth 2)")
	for _, c in ipairs(ReplicatedStorage:GetChildren()) do
		add(c.ClassName, c.Name)
		if c:IsA("Folder") then
			for i, cc in ipairs(c:GetChildren()) do
				if i > 40 then
					add("    ...")
					break
				end
				add("    " .. cc.ClassName, cc.Name)
			end
		end
	end

	section("MAP (depth 2)")
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, c in ipairs(map:GetChildren()) do
			add(c.ClassName, c.Name, posOf(c))
			for i, cc in ipairs(c:GetChildren()) do
				if i > 30 then break end
				local l = cc.Name:lower()
				if l:find("tele") or l:find("portal") or l:find("door") or l:find("entr") or l:find("exit") or l:find("spawn") or l:find("pad") then
					add("    " .. cc.ClassName, cc.Name, posOf(cc))
				end
			end
		end
	end

	section("NPCS")
	for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
		if folder then
			for _, n in ipairs(folder:GetChildren()) do add(folder.Name, "|", n.Name, posOf(n)) end
		end
	end

	section("LOCATIONS / SPAWNS")
	local wo = workspace:FindFirstChild("_WorldOrigin")
	if wo then
		for _, c in ipairs(wo:GetChildren()) do add("_WorldOrigin child:", c.ClassName, c.Name, posOf(c)) end
		local loc = wo:FindFirstChild("Locations")
		if loc then for _, p in ipairs(loc:GetChildren()) do add("Location", p.Name, posOf(p)) end end
		local ps = wo:FindFirstChild("PlayerSpawns")
		if ps then for _, p in ipairs(ps:GetDescendants()) do if p:IsA("BasePart") then add("PlayerSpawn", p:GetFullName(), posOf(p)) end end end
	end

	section("PLAYERGUI")
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		add(g.ClassName, g.Name, g:IsA("ScreenGui") and ("enabled=" .. tostring(g.Enabled)) or "")
	end
end)
if not okStruct then add("STRUCTURE ERROR:", structErr) end
writefile("bmscan/structure.txt", table.concat(out, "\n"))
notify("Part 1 saved ✔  Part 2/2: script bytecode...")

---------------------------------------------------------------------
-- بخش 2: بایت‌کد اسکریپت‌ها (بدون decompile)
---------------------------------------------------------------------
local index = {}
local saved, failed, total = 0, 0, 0
if getscriptbytecode then
	local seen = {}
	local roots = { ReplicatedStorage, game:GetService("ReplicatedFirst"), player:FindFirstChild("PlayerScripts"), player.PlayerGui, player.Character, game:GetService("StarterPlayer") }
	for _, r in ipairs(roots) do
		if r then
			for _, s in ipairs(r:GetDescendants()) do
				if (s:IsA("LocalScript") or s:IsA("ModuleScript")) and not seen[s] then
					seen[s] = true
					total += 1
					local ok, bc = pcall(getscriptbytecode, s)
					if ok and type(bc) == "string" and #bc > 0 then
						saved += 1
						local okW = pcall(writefile, ("bmscan/bc/%05d.bin"):format(saved), bc)
						table.insert(index, ("%05d\t%s\t%s\t%d\t%s"):format(saved, s.ClassName, s:GetFullName(), #bc, okW and "ok" or "writefail"))
					else
						failed += 1
					end
					if total % 25 == 0 then
						task.wait()
						if total % 250 == 0 then notify(("Bytecode: %d scripts..."):format(total)) end
					end
				end
			end
		end
	end
end
writefile("bmscan/index.tsv", table.concat(index, "\n"))
local summary = ("Done ✔  scripts: %d  saved: %d  failed: %d - tell Claude"):format(total, saved, failed)
writefile("bmscan/done.txt", summary)
notify(summary)
