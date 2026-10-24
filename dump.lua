--[[
	BM Hub Scanner - اطلاعات بازی رو جمع می‌کنه و توی bm_dump.txt ذخیره می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump.lua"))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local SPY_SECONDS = 60
local out = {}
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function section(name) add("") add("===== " .. name .. " =====") end

local function fmtVec(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function posOf(x)
	local ok, p = pcall(function()
		if x:IsA("Model") then return x:GetPivot().Position end
		if x:IsA("BasePart") then return x.Position end
	end)
	return ok and p and fmtVec(p) or "?"
end

local function ser(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then return ("%q"):format(v) end
	if t == "Instance" then return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">" end
	if t == "Vector3" then return "V3" .. fmtVec(v) end
	if t == "CFrame" then return "CF" .. fmtVec(v.Position) end
	if t == "table" then
		if depth > 3 then return "{...}" end
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 25 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

-- پیام وضعیت روی صفحه
local gui = Instance.new("ScreenGui")
gui.Name = "BMScanner"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(460, 70)
label.Position = UDim2.new(0.5, -230, 0, 60)
label.BackgroundColor3 = Color3.fromRGB(18, 19, 28)
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
local function status(t) label.Text = t print("[BM Scanner] " .. t) end
status("BM Scanner: scanning...")

---------------------------------------------------------------------
section("INFO")
local executor = "?"
pcall(function() executor = tostring((identifyexecutor or getexecutorname)()) end)
local identity = "?"
pcall(function() identity = (getthreadidentity or getidentity)() end)
add("executor:", executor, "| identity:", identity, "| place:", game.PlaceId, "| job:", game.JobId)
add("funcs: hookmetamethod=", type(hookmetamethod), "getnamecallmethod=", type(getnamecallmethod),
	"hookfunction=", type(hookfunction), "getgc=", type(getgc), "decompile=", type(decompile),
	"getsenv=", type(getsenv), "writefile=", type(writefile), "setclipboard=", type(setclipboard), "require=", type(require))

local data = player:FindFirstChild("Data")
if data then
	local vals = {}
	for _, v in ipairs(data:GetChildren()) do
		if v:IsA("ValueBase") then table.insert(vals, v.Name .. "=" .. tostring(v.Value)) end
	end
	add("Data:", table.concat(vals, ", "))
end
local char = player.Character
add("position:", char and posOf(char) or "?")
local tools = {}
for _, cont in ipairs({ char, player:FindFirstChild("Backpack") }) do
	if cont then
		for _, t in ipairs(cont:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, t.Name .. "[" .. t.ToolTip .. "]") end
		end
	end
end
add("tools:", table.concat(tools, ", "))

---------------------------------------------------------------------
section("REMOTES")
local count = 0
for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
	if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
		count += 1
		if count <= 600 then add(d.ClassName, d:GetFullName()) end
	end
end
add("total remotes:", count)

section("REPLICATEDSTORAGE TOP")
for _, c in ipairs(ReplicatedStorage:GetChildren()) do add(c.ClassName, c.Name) end

---------------------------------------------------------------------
-- require با تایم‌اوت
local function tryRequire(name)
	local m = ReplicatedStorage:FindFirstChild(name)
	if not m then return nil, "not found" end
	local result, err, done = nil, nil, false
	task.spawn(function()
		local ok, r = pcall(require, m)
		if ok then result = r else err = r end
		done = true
	end)
	local t = 0
	while not done and t < 5 do
		t += task.wait(0.1)
	end
	if not done then return nil, "timeout" end
	return result, err
end

section("QUESTS MODULE")
local quests, qerr = tryRequire("Quests")
add("require Quests:", quests and "ok" or tostring(qerr))
if type(quests) == "table" then
	for qName, entries in pairs(quests) do
		if type(entries) == "table" then
			for idx, e in pairs(entries) do
				if type(e) == "table" then
					add(qName, idx, "LevelReq=" .. tostring(e.LevelReq), "Name=" .. tostring(e.Name), "Task=" .. ser(e.Task))
				end
			end
		end
	end
end

section("GUIDE MODULE")
local guide, gerr = tryRequire("GuideModule")
add("require GuideModule:", guide and "ok" or tostring(gerr))
if type(guide) == "table" then
	add("keys:", ser(guide, 2):sub(1, 1500))
	pcall(function()
		for k, info in pairs(guide.Data.NPCList) do
			add("NPC", ser(k, 3), "=>", ser(info, 1))
		end
	end)
end

---------------------------------------------------------------------
section("WORKSPACE TOP")
for _, c in ipairs(workspace:GetChildren()) do
	if not c:IsA("BasePart") then add(c.ClassName, c.Name) end
end

section("NPCS")
local npcs = workspace:FindFirstChild("NPCs")
if npcs then
	for _, n in ipairs(npcs:GetChildren()) do add(n.Name, posOf(n)) end
end
local rsNpcs = ReplicatedStorage:FindFirstChild("NPCs")
if rsNpcs then
	add("-- ReplicatedStorage.NPCs:")
	for _, n in ipairs(rsNpcs:GetChildren()) do add(n.Name, posOf(n)) end
end

local wo = workspace:FindFirstChild("_WorldOrigin")
section("ENEMY SPAWNS")
local sp = wo and wo:FindFirstChild("EnemySpawns")
if sp then
	for _, p in ipairs(sp:GetChildren()) do add(p.Name, posOf(p)) end
else
	add("EnemySpawns not found")
end

section("LOCATIONS")
local loc = wo and wo:FindFirstChild("Locations")
if loc then
	for _, p in ipairs(loc:GetChildren()) do add(p.Name, posOf(p)) end
end

section("ENEMIES")
local enemies = workspace:FindFirstChild("Enemies")
if enemies then
	local seen = {}
	for _, m in ipairs(enemies:GetChildren()) do
		if not seen[m.Name] then
			seen[m.Name] = true
			local h = m:FindFirstChildOfClass("Humanoid")
			local attrs = {}
			for k, v in pairs(m:GetAttributes()) do table.insert(attrs, k .. "=" .. tostring(v)) end
			add(m.Name, "| display:", h and h.DisplayName, "| hp:", h and h.MaxHealth, "| pos:", posOf(m), "| attrs:", table.concat(attrs, ","))
		end
	end
end

section("QUEST GUI")
local main = player.PlayerGui:FindFirstChild("Main")
local qg = main and main:FindFirstChild("Quest")
if qg then
	add("visible:", qg.Visible)
	for _, d in ipairs(qg:GetDescendants()) do
		local txt = (d:IsA("TextLabel") or d:IsA("TextButton")) and (" text=" .. ("%q"):format(d.Text)) or ""
		add(d.ClassName, d:GetFullName():gsub("^.-PlayerGui%.", "") .. txt)
	end
else
	add("PlayerGui.Main.Quest not found")
	if main then
		local names = {}
		for _, c in ipairs(main:GetChildren()) do table.insert(names, c.Name) end
		add("Main children:", table.concat(names, ", "))
	end
end

---------------------------------------------------------------------
-- شنود (فقط اگه executor اجازه بده)
section("SPY")
local spyLog = {}
local canSpy = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function"
add("spy available:", canSpy)
if canSpy then
	local old
	local ok, err = pcall(function()
		old = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if (method == "FireServer" or method == "InvokeServer") and #spyLog < 400 then
				local okName, full = pcall(function() return self:GetFullName() end)
				local args = { ... }
				task.spawn(function()
					table.insert(spyLog, ("%.2f %s %s %s"):format(os.clock(), method, okName and full or "?", ser(args)))
				end)
			end
			return old(self, ...)
		end)
	end)
	if not ok then
		add("hook failed:", err)
		canSpy = false
	end
end

local function finish()
	for _, l in ipairs(spyLog) do add(l) end
	local text = table.concat(out, "\n")
	local saved = pcall(function() writefile("bm_dump.txt", text) end)
	local copied = pcall(function() (setclipboard or toclipboard)(text) end)
	status(("Done ✔  saved file: %s  |  copied: %s\nTell Claude it's done."):format(saved and "yes" or "no", copied and "yes" or "no"))
	print(text)
	task.delay(15, function() gui:Destroy() end)
end

if canSpy then
	for t = SPY_SECONDS, 1, -1 do
		status(("Spy ON (%ds): take a quest by hand and hit the quest mob a few times"):format(t))
		task.wait(1)
	end
end
finish()
