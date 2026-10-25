--[[
	BM Hub Raid/Darkbeard Scanner - دکمه‌ها و قطعه‌های تعاملی محل شروع Raid و احضار Darkbeard رو ثبت می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_raid.lua?t=" .. os.time()))()
	فقط می‌خونه؛ هیچ چیزی به سرور فرستاده نمیشه (به جز درخواست لود شدن نقشه‌ی اطراف که کار عادی خود بازیه).
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local out = { "== BM RAID/DARKBEARD SCAN ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function fmt(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function posOf(x)
	local ok, p = pcall(function()
		if x:IsA("Model") then return x:GetPivot().Position end
		if x:IsA("BasePart") then return x.Position end
	end)
	return ok and p and fmt(p) or ""
end
local function notify(t)
	print("[BMR] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Raid Scanner", Text = t, Duration = 6 }) end)
end

-- قطعه‌های تعاملی زیر یه مدل
local function dumpInteractives(root, label, limit)
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if n >= limit then break end
		local kind
		if d:IsA("ClickDetector") then kind = "CLICK"
		elseif d:IsA("ProximityPrompt") then kind = "PROMPT action=" .. d.ActionText .. " object=" .. d.ObjectText
		elseif d:IsA("TouchTransmitter") then kind = "TOUCH"
		end
		if kind then
			n += 1
			add(label, "|", kind, "|", d.Parent:GetFullName(), posOf(d.Parent))
		end
	end
	add(label, "interactives:", n)
end

local okRun, runErr = pcall(function()
	-- 1) Darkbeard Arena
	local arenaPos = Vector3.new(3792.7, 31.4, -3471.8)
	pcall(function() player:RequestStreamAroundAsync(arenaPos, 5) end)
	task.wait(1)
	local arena = workspace.Map:FindFirstChild("DarkbeardArena")
	add("--- DarkbeardArena:", arena and arena:GetFullName() or "not found")
	if arena then
		for _, c in ipairs(arena:GetChildren()) do add("  child:", c.ClassName, c.Name, posOf(c)) end
		dumpInteractives(arena, "arena", 40)
	end
	for _, name in ipairs({ "Darkbeard", "Fist of Darkness" }) do
		local found = workspace:FindFirstChild(name, true)
		add("search", name, "->", found and (found:GetFullName() .. " " .. posOf(found)) or "none")
	end

	-- 2) Raid summon (Hot and Cold / Mysterious Scientist)
	local labPos = Vector3.new(-6561.4, 309.3, -4749.1)
	pcall(function() player:RequestStreamAroundAsync(labPos, 5) end)
	task.wait(1)
	add("--- Raid-like objects in Map:")
	local n = 0
	for i, d in ipairs(workspace.Map:GetDescendants()) do
		if i % 5000 == 0 then task.wait() end
		if n >= 40 then break end
		local l = d.Name:lower()
		if (d:IsA("Model") or d:IsA("BasePart") or d:IsA("Folder")) and (l:find("raid") or l:find("summon") or l:find("microchip") or l:find("chip")) then
			n += 1
			add(d.ClassName, d:GetFullName(), posOf(d))
			if d:IsA("Model") or d:IsA("Folder") then dumpInteractives(d, "  raid:" .. d.Name, 10) end
		end
	end
	local rm = workspace:FindFirstChild("RaidMap") or workspace.Map:FindFirstChild("RaidMap")
	add("--- RaidMap:", rm and rm:GetFullName() or "not found")
	if rm then
		for i, c in ipairs(rm:GetChildren()) do
			if i > 20 then break end
			add("  child:", c.ClassName, c.Name, posOf(c))
		end
	end
	local tools = {}
	for _, cont in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") then table.insert(tools, t.Name) end
			end
		end
	end
	add("tools:", table.concat(tools, ", "))
end)
if not okRun then add("SCAN ERROR:", runErr) end

pcall(function() writefile("bmscan/raid.txt", table.concat(out, "\n")) end)
for i, line in ipairs(out) do print(("[BMR %03d] %s"):format(i, line)) end
notify("Done ✔ - tell Claude")
