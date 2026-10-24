--[[
	BM Hub  -  Blox Fruits
	Executors: Solara / Delta (PC + Mobile)

	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/bm_hub.lua"))()

	کلید RightControl یا دکمه‌ی شناور BM = باز/بسته کردن پنل
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if genv.BMHub and genv.BMHub.Destroy then pcall(genv.BMHub.Destroy) end
local Hub = { Connections = {}, Running = true, Version = "1.1" }
genv.BMHub = Hub
print("[BM Hub] loading v" .. Hub.Version)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Hub.Connections, c)
	return c
end

---------------------------------------------------------------------
-- Game info
---------------------------------------------------------------------
local SEA_BY_PLACE = { [2753915549] = 1, [4442272183] = 2, [7449423635] = 3 }
local Sea = SEA_BY_PLACE[game.PlaceId] or 0

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
local CommF = Remotes and Remotes:FindFirstChild("CommF_")

local function invoke(...)
	if not CommF then return nil end
	local ok, res = pcall(CommF.InvokeServer, CommF, ...)
	if ok then return res end
end

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Net = Modules and Modules:FindFirstChild("Net")
local RegisterAttack = Net and Net:FindFirstChild("RE/RegisterAttack")
local RegisterHit = Net and Net:FindFirstChild("RE/RegisterHit")

local function safeRequire(m)
	if not m then return nil end
	local ok, res = pcall(require, m)
	if ok and type(res) == "table" then return res end
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local S = {
	AutoFarm = false, FarmMode = "Level", SelectedMob = nil, TakeQuest = true,
	BringMobs = true, FastAttack = true, Weapon = "Melee",
	FarmDistance = 10, TweenSpeed = 300,
	AutoBoss = false, SelectedBoss = nil, BossQuest = true,
	AutoHaki = true,
	AutoStats = false, StatType = "Melee", StatAmount = 3,
	AutoChest = false, AutoFruit = false, AutoStore = false, AutoRandomFruit = false,
	FruitESP = false, ChestESP = false, PlayerESP = false,
	SpeedOn = false, WalkSpeed = 60, JumpOn = false, JumpPower = 80,
	Noclip = false, InfJump = false, AntiAFK = true,
	SelectedIsland = nil, SelectedNPC = nil, SelectedPlayer = nil,
	Status = "Idle",
}

---------------------------------------------------------------------
-- Character helpers
---------------------------------------------------------------------
local function getChar() return player.Character end
local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function alive()
	local h = getHum()
	return h ~= nil and h.Health > 0 and getRoot() ~= nil
end
local function dataValue(name)
	local d = player:FindFirstChild("Data")
	local v = d and d:FindFirstChild(name)
	return v and v.Value
end
local function anyFarm()
	return S.AutoFarm or S.AutoBoss or S.AutoChest or S.AutoFruit
end

---------------------------------------------------------------------
-- Movement (tween + float)
---------------------------------------------------------------------
local activeTween

local function stopTween()
	if activeTween then
		pcall(function() activeTween:Cancel() end)
		activeTween = nil
	end
end

local function setFloat(on)
	local root = getRoot()
	if not root then return end
	local bv = root:FindFirstChild("BMFloat")
	if on and not bv then
		bv = Instance.new("BodyVelocity")
		bv.Name = "BMFloat"
		bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bv.Velocity = Vector3.zero
		bv.Parent = root
	elseif not on and bv then
		bv:Destroy()
	end
end

-- تا رسیدن صبر می‌کنه؛ اگه keepGoing false بشه وسط راه قطع میشه
local function tweenTo(cf, keepGoing)
	local root = getRoot()
	if not root or not cf then return false end
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	local dist = (root.Position - cf.Position).Magnitude
	if dist <= 10 then
		root.CFrame = cf
		return true
	end
	stopTween()
	setFloat(true)
	local t = TweenService:Create(root, TweenInfo.new(dist / math.max(S.TweenSpeed, 50), Enum.EasingStyle.Linear), { CFrame = cf })
	activeTween = t
	t:Play()
	while t.PlaybackState == Enum.PlaybackState.Playing do
		if (keepGoing and not keepGoing()) or not alive() or not Hub.Running then
			t:Cancel()
			break
		end
		task.wait()
	end
	if activeTween == t then activeTween = nil end
	local r = getRoot()
	return r ~= nil and (r.Position - cf.Position).Magnitude < 20
end

---------------------------------------------------------------------
-- Enemies
---------------------------------------------------------------------
local function mobBaseName(name)
	return (name:gsub("%s*%[.-%]%s*$", ""))
end

local function isAliveMob(m)
	local h = m:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and m:FindFirstChild("HumanoidRootPart") ~= nil
end

local function findMob(target)
	local enemies = workspace:FindFirstChild("Enemies")
	local root = getRoot()
	if not enemies then return nil end
	local best, bestDist
	for _, m in ipairs(enemies:GetChildren()) do
		if mobBaseName(m.Name) == target and isAliveMob(m) then
			local d = root and (m.HumanoidRootPart.Position - root.Position).Magnitude or 0
			if not bestDist or d < bestDist then best, bestDist = m, d end
		end
	end
	return best
end

-- باس‌هایی که دور هستن توی ReplicatedStorage نگه داشته میشن
local function findMobAnywhere(target)
	local m = findMob(target)
	if m then return m end
	for _, v in ipairs(ReplicatedStorage:GetChildren()) do
		if v:IsA("Model") and mobBaseName(v.Name) == target and isAliveMob(v) then return v end
	end
end

local function spawnFolder()
	local wo = workspace:FindFirstChild("_WorldOrigin")
	return wo and wo:FindFirstChild("EnemySpawns")
end

local function mobSpawn(target)
	local sp = spawnFolder()
	if not sp then return nil end
	for _, p in ipairs(sp:GetChildren()) do
		if p:IsA("BasePart") and mobBaseName(p.Name) == target then return p.CFrame end
	end
end

---------------------------------------------------------------------
-- Quest data (از ماژول‌های خود بازی خونده میشه)
---------------------------------------------------------------------
local function toCFrame(x)
	local t = typeof(x)
	if t == "CFrame" then return x end
	if t == "Vector3" then return CFrame.new(x) end
	if t == "Instance" then
		if x:IsA("Model") then return x:GetPivot() end
		if x:IsA("BasePart") then return x.CFrame end
	end
	if t == "table" then
		return toCFrame(rawget(x, "CFrame")) or toCFrame(rawget(x, "Position"))
	end
end

-- اگه ماژول‌ها لود نشن (Sea 1)
local FALLBACK_SEA1 = {
	{ 1, "BanditQuest1", 1, "Bandit", Vector3.new(1059.37, 15.45, 1550.42) },
	{ 10, "JungleQuest", 1, "Monkey", Vector3.new(-1598.09, 35.55, 153.38) },
	{ 15, "JungleQuest", 2, "Gorilla", Vector3.new(-1598.09, 35.55, 153.38) },
	{ 30, "BuggyQuest1", 1, "Pirate", Vector3.new(-1141.07, 4.10, 3831.55) },
	{ 40, "BuggyQuest1", 2, "Brute", Vector3.new(-1141.07, 4.10, 3831.55) },
	{ 60, "DesertQuest", 1, "Desert Bandit", Vector3.new(894.49, 5.14, 4392.43) },
	{ 75, "DesertQuest", 2, "Desert Officer", Vector3.new(894.49, 5.14, 4392.43) },
	{ 90, "SnowQuest", 1, "Snow Bandit", Vector3.new(1389.74, 88.15, -1298.91) },
	{ 100, "SnowQuest", 2, "Snowman", Vector3.new(1389.74, 88.15, -1298.91) },
	{ 120, "MarineQuest2", 1, "Chief Petty Officer", Vector3.new(-5039.59, 27.35, 4324.68) },
	{ 150, "SkyQuest", 1, "Sky Bandit", Vector3.new(-4839.53, 716.37, -2619.44) },
	{ 175, "SkyQuest", 2, "Dark Master", Vector3.new(-4839.53, 716.37, -2619.44) },
	{ 190, "PrisonerQuest", 1, "Prisoner", Vector3.new(5308.93, 1.66, 475.12) },
	{ 210, "PrisonerQuest", 2, "Dangerous Prisoner", Vector3.new(5308.93, 1.66, 475.12) },
	{ 250, "ColosseumQuest", 1, "Toga Warrior", Vector3.new(-1580.05, 6.35, -2986.48) },
	{ 275, "ColosseumQuest", 2, "Gladiator", Vector3.new(-1580.05, 6.35, -2986.48) },
	{ 300, "MagmaQuest", 1, "Military Soldier", Vector3.new(-5313.37, 10.95, 8515.29) },
	{ 325, "MagmaQuest", 2, "Military Spy", Vector3.new(-5313.37, 10.95, 8515.29) },
	{ 375, "FishmanQuest", 1, "Fishman Warrior", Vector3.new(61122.65, 18.50, 1569.40) },
	{ 400, "FishmanQuest", 2, "Fishman Commando", Vector3.new(61122.65, 18.50, 1569.40) },
	{ 450, "SkyExp1Quest", 1, "God's Guard", Vector3.new(-4721.89, 843.87, -1949.97) },
	{ 475, "SkyExp1Quest", 2, "Shanda", Vector3.new(-7859.10, 5544.19, -381.48) },
	{ 525, "SkyExp2Quest", 1, "Royal Squad", Vector3.new(-7906.82, 5634.66, -1411.99) },
	{ 550, "SkyExp2Quest", 2, "Royal Soldier", Vector3.new(-7906.82, 5634.66, -1411.99) },
	{ 625, "FountainQuest", 1, "Galley Pirate", Vector3.new(5259.82, 37.35, 4050.03) },
	{ 650, "FountainQuest", 2, "Galley Captain", Vector3.new(5259.82, 37.35, 4050.03) },
}
local FALLBACK_BOSSES = {
	"The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral", "Warden", "Chief Warden",
	"Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Saber Expert", "Greybeard",
}

local QuestList, BossList = {}, {}

local function useFallback()
	if #QuestList == 0 and Sea == 1 then
		for _, f in ipairs(FALLBACK_SEA1) do
			table.insert(QuestList, { level = f[1], quest = f[2], index = f[3], mob = f[4], npc = CFrame.new(f[5]) })
		end
	end
end

-- require روی بعضی executor ها گیر می‌کنه، برای همین جدا و با تایم‌اوت اجرا میشه
local function loadQuestData()
	local QuestsMod = safeRequire(ReplicatedStorage:FindFirstChild("Quests"))
	local GuideMod = safeRequire(ReplicatedStorage:FindFirstChild("GuideModule"))
	local npcByLevel = {}
	pcall(function()
		for key, info in pairs(GuideMod.Data.NPCList) do
			if type(info) == "table" and type(info.Levels) == "table" then
				local cf = toCFrame(key) or toCFrame(info)
				if cf then
					for _, lv in pairs(info.Levels) do npcByLevel[lv] = cf end
				end
			end
		end
	end)
	local quests, bosses = {}, {}
	pcall(function()
		local hasSpawns = spawnFolder() ~= nil
		for qName, entries in pairs(QuestsMod) do
			if type(entries) == "table" then
				for idx, e in pairs(entries) do
					if type(e) == "table" and type(e.LevelReq) == "number" and type(e.Task) == "table" then
						local mob, count = next(e.Task)
						local npc = npcByLevel[e.LevelReq]
						if type(mob) == "string" and npc then
							local entry = { quest = qName, index = idx, level = e.LevelReq, mob = mob, npc = npc }
							if count == 1 then
								table.insert(bosses, entry)
							elseif not hasSpawns or mobSpawn(mob) then
								table.insert(quests, entry)
							end
						end
					end
				end
			end
		end
	end)
	if #quests > 0 then
		table.clear(QuestList)
		for _, q in ipairs(quests) do table.insert(QuestList, q) end
	end
	for _, b in ipairs(bosses) do table.insert(BossList, b) end
	table.sort(QuestList, function(a, b) return a.level < b.level end)
	table.sort(BossList, function(a, b) return a.level < b.level end)
end

useFallback()
task.spawn(function()
	local ok, err = pcall(loadQuestData)
	print("[BM Hub] quest data:", ok and (#QuestList .. " quests, " .. #BossList .. " bosses") or err)
end)

local function questForLevel(lv)
	local pick
	for _, q in ipairs(QuestList) do
		if q.level <= lv then pick = q end
	end
	return pick
end

local function questForMob(mob)
	for _, q in ipairs(QuestList) do
		if q.mob == mob then return q end
	end
	for _, q in ipairs(BossList) do
		if q.mob == mob then return q end
	end
end

local function questGui()
	local pg = player:FindFirstChild("PlayerGui")
	local m = pg and pg:FindFirstChild("Main")
	return m and m:FindFirstChild("Quest")
end

local function hasQuest(mob)
	local q = questGui()
	if not q or not q.Visible then return false end
	local ok, txt = pcall(function() return q.Container.QuestTitle.Title.Text end)
	if not ok or not mob then return true end
	return txt:find(mob, 1, true) ~= nil
end

local function takeQuest(q, keepGoing)
	local g = questGui()
	if g and g.Visible then invoke("AbandonQuest") end
	S.Status = "Taking quest: " .. q.mob
	if tweenTo(q.npc, keepGoing) then
		task.wait(0.25)
		invoke("StartQuest", q.quest, q.index)
		task.wait(0.25)
	end
end

---------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------
local function findWeapon()
	local bp = player:FindFirstChild("Backpack")
	for _, cont in ipairs({ getChar(), bp }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") and t.ToolTip == S.Weapon then return t end
			end
		end
	end
end

local function equipWeapon()
	local t, h = findWeapon(), getHum()
	if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
end

local lastClick = 0
local function attack()
	local root = getRoot()
	if not root then return end
	if S.FastAttack and RegisterAttack and RegisterHit then
		local hits = {}
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do
				if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= 60 then
					table.insert(hits, { m, m:FindFirstChild("Head") or m.HumanoidRootPart })
				end
			end
		end
		if #hits > 0 then
			pcall(function()
				RegisterAttack:FireServer(0)
				RegisterHit:FireServer(hits[1][2], hits)
			end)
		end
	end
	local tool = getChar() and getChar():FindFirstChildOfClass("Tool")
	if tool and tick() - lastClick > 0.15 then
		lastClick = tick()
		pcall(function() tool:Activate() end)
	end
end

local function bringMobs(name, cf)
	local enemies = workspace:FindFirstChild("Enemies")
	local root = getRoot()
	if not enemies or not root then return end
	pcall(function()
		if sethiddenproperty then sethiddenproperty(player, "SimulationRadius", math.huge) end
	end)
	for _, m in ipairs(enemies:GetChildren()) do
		if mobBaseName(m.Name) == name and isAliveMob(m) then
			local hrp = m.HumanoidRootPart
			if (hrp.Position - root.Position).Magnitude <= 300 then
				pcall(function()
					hrp.CanCollide = false
					hrp.CFrame = cf
					m.Humanoid.WalkSpeed = 0
					m.Humanoid.JumpPower = 0
				end)
			end
		end
	end
end

local function killMob(mob, keepGoing)
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local hrp = mob:FindFirstChild("HumanoidRootPart")
	local name = mobBaseName(mob.Name)
	S.Status = "Farming: " .. name
	while Hub.Running and keepGoing() and alive() and mob.Parent and hum and hum.Health > 0 do
		local root = getRoot()
		local target = CFrame.new(hrp.Position + Vector3.new(0, S.FarmDistance, 0))
		if (root.Position - target.Position).Magnitude > 80 then
			tweenTo(target, keepGoing)
		else
			setFloat(true)
			root.CFrame = target
		end
		equipWeapon()
		if S.BringMobs then bringMobs(name, hrp.CFrame) end
		attack()
		task.wait(0.08)
	end
end

---------------------------------------------------------------------
-- Farm loops
---------------------------------------------------------------------
local function farmTarget()
	if S.FarmMode == "Selected Mob" and S.SelectedMob then
		return questForMob(S.SelectedMob)
	end
	return questForLevel(dataValue("Level") or 1)
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.1)
		if S.AutoFarm and alive() then
			local keep = function() return S.AutoFarm end
			local ok, err = pcall(function()
				local q = farmTarget()
				if not q then
					S.Status = "No quest found for your level"
					return
				end
				if S.TakeQuest and not hasQuest(q.mob) then
					takeQuest(q, keep)
					return
				end
				local mob = findMob(q.mob)
				if not mob then
					S.Status = "Waiting for " .. q.mob
					local sp = mobSpawn(q.mob)
					if sp then
						tweenTo(sp * CFrame.new(0, 30, 0), function() return S.AutoFarm and not findMob(q.mob) end)
					end
					return
				end
				killMob(mob, function() return S.AutoFarm and (not S.TakeQuest or hasQuest(q.mob)) end)
			end)
			if not ok then S.Status = "Error: " .. tostring(err) end
		end
	end
end)

-- Boss
task.spawn(function()
	while Hub.Running do
		task.wait(0.2)
		if S.AutoBoss and S.SelectedBoss and alive() then
			local keep = function() return S.AutoBoss end
			pcall(function()
				local boss = findMobAnywhere(S.SelectedBoss)
				if not boss then
					S.Status = S.SelectedBoss .. " not spawned"
					return
				end
				local q = questForMob(S.SelectedBoss)
				if S.BossQuest and q and not hasQuest(q.mob) then
					takeQuest(q, keep)
					return
				end
				if boss.Parent ~= workspace:FindFirstChild("Enemies") then
					S.Status = "Going to " .. S.SelectedBoss
					tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmDistance, 0), keep)
					return
				end
				killMob(boss, keep)
			end)
		end
	end
end)

-- Chests
local chestCache, chestCacheTime = {}, 0
local function getChests()
	local list = {}
	local ok, tagged = pcall(CollectionService.GetTagged, CollectionService, "_ChestTagged")
	if ok then
		for _, c in ipairs(tagged) do
			if c:IsA("BasePart") and c:IsDescendantOf(workspace) and not c:GetAttribute("IsDisabled") then
				table.insert(list, c)
			end
		end
	end
	if #list == 0 then
		if tick() - chestCacheTime > 30 then
			chestCache, chestCacheTime = {}, tick()
			for _, c in ipairs(workspace:GetDescendants()) do
				if c:IsA("BasePart") and c.Name:match("^Chest%d$") then table.insert(chestCache, c) end
			end
		end
		for _, c in ipairs(chestCache) do
			if c.Parent then table.insert(list, c) end
		end
	end
	local root = getRoot()
	if root then
		table.sort(list, function(a, b)
			return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
		end)
	end
	return list
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.2)
		if S.AutoChest and alive() then
			pcall(function()
				local c = getChests()[1]
				if not c then
					S.Status = "No chests found"
					return
				end
				S.Status = "Collecting chest"
				tweenTo(c.CFrame, function() return S.AutoChest and c.Parent ~= nil end)
				task.wait(0.15)
			end)
		end
	end
end)

-- Fruits
local function getWorldFruits()
	local list = {}
	for _, v in ipairs(workspace:GetChildren()) do
		if (v:IsA("Tool") or v:IsA("Model")) and v.Name:find("Fruit") then
			local h = v:FindFirstChild("Handle") or v:FindFirstChildWhichIsA("BasePart", true)
			if h then table.insert(list, { obj = v, part = h }) end
		end
	end
	return list
end

local function storeFruits()
	local bp = player:FindFirstChild("Backpack")
	for _, cont in ipairs({ bp, getChar() }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") and t.Name:find(" Fruit$") then
					local base = t.Name:gsub(" Fruit$", "")
					local storeName = t:GetAttribute("OriginalName") or (base .. "-" .. base)
					invoke("StoreFruit", storeName, t)
				end
			end
		end
	end
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.5)
		if S.AutoFruit and alive() then
			pcall(function()
				local f = getWorldFruits()[1]
				if f then
					S.Status = "Collecting " .. f.obj.Name
					tweenTo(f.part.CFrame, function() return S.AutoFruit and f.obj.Parent == workspace end)
					task.wait(0.3)
				end
			end)
		end
		if S.AutoStore then pcall(storeFruits) end
	end
end)

task.spawn(function()
	while Hub.Running do
		if S.AutoRandomFruit then invoke("Cousin", "Buy") end
		task.wait(30)
	end
end)

-- Haki + Stats
task.spawn(function()
	while Hub.Running do
		task.wait(1)
		if S.AutoHaki and alive() and not getChar():FindFirstChild("HasBuso") then
			invoke("Buso")
		end
		if S.AutoStats then
			local pts = dataValue("Points") or 0
			if pts > 0 then invoke("AddPoint", S.StatType, math.min(pts, S.StatAmount)) end
		end
	end
end)

---------------------------------------------------------------------
-- Player mods (noclip, speed, jump, float cleanup)
---------------------------------------------------------------------
connect(RunService.Stepped, function()
	local char = getChar()
	if not char then return end
	if S.Noclip or anyFarm() or activeTween then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end
end)

connect(RunService.Heartbeat, function()
	local hum = getHum()
	if hum then
		if S.SpeedOn then hum.WalkSpeed = S.WalkSpeed end
		if S.JumpOn then
			hum.UseJumpPower = true
			hum.JumpPower = S.JumpPower
		end
	end
	if not anyFarm() and not activeTween then setFloat(false) end
end)

connect(UserInputService.JumpRequest, function()
	if S.InfJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

connect(player.Idled, function()
	if S.AntiAFK then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

---------------------------------------------------------------------
-- Utility actions
---------------------------------------------------------------------
local function serverHop()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
	end)
	if ok then
		local data = HttpService:JSONDecode(body)
		for _, s in ipairs(data.data or {}) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
				return true
			end
		end
	end
	return false
end

local function fpsBoost()
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	for i, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Material = Enum.Material.SmoothPlastic
			v.Reflectance = 0
		elseif v:IsA("Decal") or v:IsA("Texture") then
			v.Transparency = 1
		elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
			v.Enabled = false
		end
		if i % 3000 == 0 then task.wait() end
	end
end

local function islandList()
	local out = {}
	local wo = workspace:FindFirstChild("_WorldOrigin")
	local loc = wo and wo:FindFirstChild("Locations")
	if loc then
		for _, v in ipairs(loc:GetChildren()) do
			if v:IsA("BasePart") and not table.find(out, v.Name) then table.insert(out, v.Name) end
		end
	end
	table.sort(out)
	return out
end

local function islandCFrame(name)
	local wo = workspace:FindFirstChild("_WorldOrigin")
	local loc = wo and wo:FindFirstChild("Locations")
	local p = loc and loc:FindFirstChild(name)
	return p and p.CFrame * CFrame.new(0, 40, 0)
end

local function npcList()
	local out = {}
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, v in ipairs(npcs:GetChildren()) do
			if v:IsA("Model") and not table.find(out, v.Name) then table.insert(out, v.Name) end
		end
	end
	table.sort(out)
	return out
end

local function playerList()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then table.insert(out, p.Name) end
	end
	return out
end

local function mobOptions()
	local out = {}
	for _, q in ipairs(QuestList) do
		if not table.find(out, q.mob) then table.insert(out, q.mob) end
	end
	return out
end

local function bossOptions()
	local out = {}
	for _, q in ipairs(BossList) do
		if not table.find(out, q.mob) then table.insert(out, q.mob) end
	end
	if #out == 0 then
		for _, n in ipairs(FALLBACK_BOSSES) do table.insert(out, n) end
	end
	return out
end

local function formatNumber(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local Theme = {
	Bg = Color3.fromRGB(12, 13, 19),
	Panel = Color3.fromRGB(18, 19, 28),
	Card = Color3.fromRGB(25, 26, 38),
	CardHover = Color3.fromRGB(33, 35, 52),
	Text = Color3.fromRGB(236, 239, 255),
	SubText = Color3.fromRGB(135, 140, 168),
	Accent1 = Color3.fromRGB(130, 90, 255),
	Accent2 = Color3.fromRGB(0, 210, 255),
	Off = Color3.fromRGB(52, 54, 74),
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function gradient(rot)
	return new("UIGradient", { Color = ColorSequence.new(Theme.Accent1, Theme.Accent2), Rotation = rot or 0 })
end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local root = new("ScreenGui", {
	Name = "BMHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local placed = pcall(function() root.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not placed or not root.Parent then root.Parent = player:WaitForChild("PlayerGui") end
print("[BM Hub] UI parent:", root.Parent:GetFullName())

local espFolder = new("Folder", { Name = "BMHubESP", Parent = root.Parent })

local uiScale = new("UIScale", { Parent = root })
local function updateScale()
	local vs = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vs.X / 900, vs.Y / 540), 0.55, 1)
end
updateScale()
connect(camera:GetPropertyChangedSignal("ViewportSize"), updateScale)

-- گرادیان‌های متحرک
local animatedGradients = {}
local function animated(g, speed)
	table.insert(animatedGradients, { g = g, speed = speed or 60 })
	return g
end
connect(RunService.RenderStepped, function(dt)
	for _, a in ipairs(animatedGradients) do
		a.g.Rotation = (a.g.Rotation + dt * a.speed) % 360
	end
end)

-- Notifications
local notifHolder = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(270, 400),
	BackgroundTransparency = 1, Parent = root,
}, {
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local notifCount = 0
local function notify(title, text, dur)
	notifCount += 1
	local slot = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = notifCount, Parent = notifHolder })
	local card = new("Frame", {
		Position = UDim2.new(1.2, 0, 0, 0), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Panel, Parent = slot,
	}, { corner(10) })
	local st = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Parent = card })
	animated(gradient(), 90).Parent = st
	new("Frame", { Size = UDim2.new(0, 4, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card }, { corner(2), gradient(90) })
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		Text = title, Parent = card,
	})
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -28, 0, 28),
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = text, Parent = card,
	})
	tween(card, 0.45, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	task.delay(dur or 3, function()
		tween(card, 0.35, { Position = UDim2.new(1.2, 0, 0, 0) })
		task.wait(0.4)
		slot:Destroy()
	end)
end

-- Main window
local FULL = UDim2.fromOffset(600, 390)
local main = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
	BackgroundColor3 = Theme.Bg, ClipsDescendants = true, Visible = false, Parent = root,
}, { corner(14) })
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(22, 22, 34), Color3.fromRGB(10, 10, 16)), Rotation = 90, Parent = main })
local mainStroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = main })
animated(gradient(), 70).Parent = mainStroke

-- نور متحرک پس‌زمینه
local glow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromOffset(380, 380),
	BackgroundColor3 = Theme.Accent1, BackgroundTransparency = 0.88, ZIndex = 0, Parent = main,
}, { corner(999) })
task.spawn(function()
	local points = { UDim2.fromScale(0.85, 0.2), UDim2.fromScale(0.7, 0.9), UDim2.fromScale(0.15, 0.8), UDim2.fromScale(0.2, 0.1) }
	local i = 1
	while Hub.Running and glow.Parent do
		tween(glow, 6, { Position = points[i], BackgroundColor3 = (i % 2 == 0) and Theme.Accent1 or Theme.Accent2 }, Enum.EasingStyle.Sine)
		task.wait(6)
		i = i % #points + 1
	end
end)

-- Topbar
local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = main })
local logo = new("Frame", {
	Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.new(1, 1, 1), Parent = topbar,
}, { corner(9) })
animated(gradient(), 120).Parent = logo
new("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1), Text = "BM", Parent = logo,
})
local titleLbl = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 7), Size = UDim2.fromOffset(200, 22),
	Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "BM Hub", Parent = topbar,
})
animated(gradient(), 40).Parent = titleLbl
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 28), Size = UDim2.fromOffset(260, 16),
	Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
	Text = ("Blox Fruits  •  Sea %s  •  v%s"):format(Sea > 0 and Sea or "?", Hub.Version), Parent = topbar,
})

local function topButton(text, x)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 11), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Card, Text = text, Font = Enum.Font.GothamBold, TextSize = 16,
		TextColor3 = Theme.Text, AutoButtonColor = false, Parent = topbar,
	}, { corner(8) })
	b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundColor3 = Theme.CardHover }) end)
	b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundColor3 = Theme.Card }) end)
	return b
end
local closeBtn = topButton("×", -12)
local minBtn = topButton("–", -46)

new("Frame", {
	Position = UDim2.new(0, 12, 0, 50), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = main,
}, { gradient() })

-- Sidebar
local sidebar = new("Frame", {
	Position = UDim2.fromOffset(10, 60), Size = UDim2.new(0, 150, 1, -70), BackgroundColor3 = Theme.Panel,
	BackgroundTransparency = 0.2, Parent = main,
}, { corner(10) })
local tabList = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, Parent = sidebar }, {
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local indicator = new("Frame", {
	Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(2, 13), BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 3, Parent = sidebar,
}, { corner(2), gradient(90) })

local pageHolder = new("Frame", {
	Position = UDim2.fromOffset(170, 60), Size = UDim2.new(1, -180, 1, -70), BackgroundTransparency = 1,
	ClipsDescendants = true, Parent = main,
})

local Pages, Tabs, tabCount = {}, {}, 0
local currentPage
local dynamicLabels = {}

local function hoverCard(card, trigger)
	trigger.MouseEnter:Connect(function() tween(card, 0.15, { BackgroundColor3 = Theme.CardHover }) end)
	trigger.MouseLeave:Connect(function() tween(card, 0.15, { BackgroundColor3 = Theme.Card }) end)
end

local function selectPage(name)
	if currentPage == name then return end
	currentPage = name
	for n, p in pairs(Pages) do
		if n == name then
			p.Visible = true
			p.Position = UDim2.fromOffset(0, 18)
			tween(p, 0.35, { Position = UDim2.fromOffset(0, 0) })
		else
			p.Visible = false
		end
	end
	for n, t in pairs(Tabs) do
		local on = n == name
		tween(t.label, 0.2, { TextColor3 = on and Theme.Text or Theme.SubText })
		tween(t.button, 0.2, { BackgroundTransparency = on and 0 or 1 })
		if on then
			local y = t.button.AbsolutePosition.Y - sidebar.AbsolutePosition.Y
			tween(indicator, 0.35, { Position = UDim2.fromOffset(2, y / uiScale.Scale + 8) }, Enum.EasingStyle.Back)
		end
	end
end

local function createTab(name, icon)
	tabCount += 1
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Card, BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = tabCount, Parent = tabList,
	}, { corner(8) })
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 22, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 15, Text = icon, TextColor3 = Theme.Text, Parent = btn,
	})
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 13, Text = name, TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
	})
	Tabs[name] = { button = btn, label = label }

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, Parent = pageHolder,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	Pages[name] = page
	btn.MouseButton1Click:Connect(function() selectPage(name) end)

	local order = 0
	local api = {}

	local function card(h)
		order += 1
		return new("Frame", {
			Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Theme.Card, LayoutOrder = order, Parent = page,
		}, { corner(9) })
	end

	local function cardLabel(c, text, h)
		return new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 0, h or 38),
			Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = text, Parent = c,
		})
	end

	function api:Section(text)
		order += 1
		local l = new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(text),
			LayoutOrder = order, Parent = page,
		}, { new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6) }) })
		gradient().Parent = l
	end

	function api:Toggle(text, key, cb)
		local c = card(38)
		cardLabel(c, text)
		local hit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = c })
		local sw = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 22),
			BackgroundColor3 = Theme.Off, Parent = c,
		}, { corner(11) })
		local swGrad = gradient()
		swGrad.Enabled = false
		swGrad.Parent = sw
		local knob = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(190, 192, 210), Parent = sw,
		}, { corner(8) })
		local function render()
			local on = S[key]
			swGrad.Enabled = on
			tween(sw, 0.2, { BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.Off })
			tween(knob, 0.3, {
				Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(190, 192, 210),
			}, Enum.EasingStyle.Back)
		end
		hit.MouseButton1Click:Connect(function()
			S[key] = not S[key]
			render()
			if cb then task.spawn(cb, S[key]) end
		end)
		hoverCard(c, hit)
		render()
	end

	function api:Button(text, cb)
		local c = card(36)
		c.ClipsDescendants = true
		cardLabel(c, text, 36)
		local arrow = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(20, 36),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, Text = "›",
			TextColor3 = Color3.new(1, 1, 1), Parent = c,
		})
		gradient().Parent = arrow
		local hit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = c })
		hit.MouseButton1Click:Connect(function()
			local r = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
				BackgroundColor3 = Theme.Accent2, BackgroundTransparency = 0.7, Parent = c,
			}, { corner(999) })
			tween(r, 0.5, { Size = UDim2.fromOffset(500, 500), BackgroundTransparency = 1 })
			task.delay(0.5, function() r:Destroy() end)
			task.spawn(function()
				local ok, err = pcall(cb)
				if not ok then notify("Error", tostring(err), 4) end
			end)
		end)
		hoverCard(c, hit)
	end

	function api:Slider(text, min, max, key, cb)
		local c = card(54)
		cardLabel(c, text, 30)
		local val = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(60, 30),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent2,
			TextXAlignment = Enum.TextXAlignment.Right, Parent = c,
		})
		local bar = new("Frame", {
			Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = Theme.Off, Parent = c,
		}, { corner(3) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, { corner(3), gradient() })
		local knob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar,
		}, { corner(7) })
		local function set(v)
			v = math.clamp(math.floor(v + 0.5), min, max)
			S[key] = v
			local a = (v - min) / (max - min)
			tween(fill, 0.12, { Size = UDim2.fromScale(a, 1) })
			tween(knob, 0.12, { Position = UDim2.fromScale(a, 0.5) })
			val.Text = tostring(v)
			if cb then cb(v) end
		end
		local dragging = false
		local function fromX(x)
			local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			set(min + (max - min) * a)
		end
		local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 26), Parent = c })
		hit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				fromX(i.Position.X)
			end
		end)
		connect(UserInputService.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				fromX(i.Position.X)
			end
		end)
		connect(UserInputService.InputEnded, function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		set(S[key])
	end

	function api:Dropdown(text, getOptions, key, cb)
		local c = card(38)
		c.ClipsDescendants = true
		local lbl = cardLabel(c, "")
		local arrow = new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(20, 38),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, Text = "▼", TextColor3 = Theme.SubText, Parent = c,
		})
		local header = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Text = "", Parent = c })
		local list = new("ScrollingFrame", {
			Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent2, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c,
		}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local open = false
		local function refreshLabel()
			lbl.Text = text .. ":  " .. tostring(S[key] or "None")
		end
		local function close()
			open = false
			tween(c, 0.25, { Size = UDim2.new(1, 0, 0, 38) })
			tween(arrow, 0.25, { Rotation = 0 })
		end
		local function build()
			for _, ch in ipairs(list:GetChildren()) do
				if ch:IsA("TextButton") then ch:Destroy() end
			end
			local opts = getOptions() or {}
			for i, o in ipairs(opts) do
				local b = new("TextButton", {
					Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = Theme.Panel, AutoButtonColor = false, LayoutOrder = i,
					Font = Enum.Font.GothamMedium, TextSize = 12, Text = tostring(o),
					TextColor3 = (S[key] == o) and Theme.Accent2 or Theme.SubText, Parent = list,
				}, { corner(6) })
				b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.CardHover }) end)
				b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.Panel }) end)
				b.MouseButton1Click:Connect(function()
					S[key] = o
					refreshLabel()
					close()
					if cb then task.spawn(cb, o) end
				end)
			end
			return #opts
		end
		header.MouseButton1Click:Connect(function()
			if open then
				close()
				return
			end
			open = true
			local h = math.min(math.max(build(), 1) * 30, 150)
			list.Size = UDim2.new(1, -16, 0, h)
			tween(c, 0.3, { Size = UDim2.new(1, 0, 0, 48 + h) })
			tween(arrow, 0.25, { Rotation = 180 })
		end)
		hoverCard(c, header)
		refreshLabel()
	end

	function api:Label(fn)
		local c = card(30)
		local l = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, RichText = true, Text = "", Parent = c,
		})
		table.insert(dynamicLabels, { label = l, fn = fn })
	end

	function api:Profile()
		local c = card(70)
		local stroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.4, Parent = c })
		animated(gradient(), 50).Parent = stroke
		local avatar = new("ImageLabel", {
			Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Theme.Panel, Parent = c,
		}, { corner(24) })
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if ok then avatar.Image = img end
		end)
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(72, 14), Size = UDim2.new(1, -84, 0, 20),
			Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Welcome, " .. player.DisplayName, Parent = c,
		})
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(72, 36), Size = UDim2.new(1, -84, 0, 18),
			Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "@" .. player.Name .. "  •  BM Hub v" .. Hub.Version, Parent = c,
		})
	end

	return api
end

---------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------
local Home = createTab("Home", "⌂")
Home:Profile()
Home:Section("Stats")
Home:Label(function() return "Level:  <font color=\"#00D2FF\">" .. formatNumber(dataValue("Level") or 0) .. "</font>" end)
Home:Label(function() return "Beli:  <font color=\"#7CFF9B\">$" .. formatNumber(dataValue("Beli") or 0) .. "</font>" end)
Home:Label(function() return "Fragments:  <font color=\"#C79BFF\">" .. formatNumber(dataValue("Fragments") or 0) .. "</font>" end)
Home:Label(function() return "Stat Points:  " .. formatNumber(dataValue("Points") or 0) end)
Home:Label(function() return "Status:  <font color=\"#FFD166\">" .. S.Status .. "</font>" end)
Home:Section("Info")
Home:Label(function() return "Quests loaded: " .. #QuestList .. "  •  Bosses: " .. #BossList end)
Home:Label(function() return "Toggle UI:  RightControl  /  BM button" end)

local Farm = createTab("Main Farm", "⚔")
Farm:Section("Auto Farm")
Farm:Toggle("Auto Farm", "AutoFarm", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
Farm:Dropdown("Farm Mode", function() return { "Level", "Selected Mob" } end, "FarmMode")
Farm:Dropdown("Select Mob", mobOptions, "SelectedMob")
Farm:Toggle("Take Quest", "TakeQuest")
Farm:Section("Combat")
Farm:Dropdown("Weapon", function() return { "Melee", "Sword", "Blox Fruit", "Gun" } end, "Weapon")
Farm:Toggle("Fast Attack", "FastAttack")
Farm:Toggle("Bring Mobs", "BringMobs")
Farm:Toggle("Auto Haki (Buso)", "AutoHaki")
Farm:Slider("Farm Height", 0, 30, "FarmDistance")
Farm:Slider("Tween Speed", 100, 350, "TweenSpeed")

local Boss = createTab("Bosses", "♛")
Boss:Section("Auto Boss")
Boss:Dropdown("Select Boss", bossOptions, "SelectedBoss")
Boss:Toggle("Auto Farm Boss", "AutoBoss", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
Boss:Toggle("Take Boss Quest", "BossQuest")
Boss:Button("Check Boss Spawned", function()
	if not S.SelectedBoss then return notify("Boss", "Select a boss first") end
	local b = findMobAnywhere(S.SelectedBoss)
	notify("Boss", S.SelectedBoss .. (b and " is spawned ✔" or " is not spawned ✖"))
end)

local Fruit = createTab("Fruits", "◆")
Fruit:Section("Devil Fruits")
Fruit:Toggle("Auto Collect Fruits", "AutoFruit", function(on)
	if not on then stopTween() end
end)
Fruit:Toggle("Auto Store Fruits", "AutoStore")
Fruit:Toggle("Auto Random Fruit (Cousin)", "AutoRandomFruit")
Fruit:Toggle("Fruit ESP", "FruitESP")
Fruit:Button("Buy Random Fruit", function()
	local r = invoke("Cousin", "Buy")
	notify("Random Fruit", r and tostring(r) or "Request sent")
end)
Fruit:Button("Find Fruits In Server", function()
	local list = getWorldFruits()
	if #list == 0 then return notify("Fruits", "No fruits spawned") end
	local names = {}
	for _, f in ipairs(list) do table.insert(names, f.obj.Name) end
	notify("Fruits (" .. #list .. ")", table.concat(names, ", "), 6)
end)
Fruit:Section("Chests")
Fruit:Toggle("Auto Chest", "AutoChest", function(on)
	if not on then stopTween() end
end)
Fruit:Toggle("Chest ESP", "ChestESP")

local Tp = createTab("Teleport", "➤")
Tp:Section("Seas")
Tp:Button("Travel to Sea 1", function() invoke("TravelMain") end)
Tp:Button("Travel to Sea 2", function() invoke("TravelDressrosa") end)
Tp:Button("Travel to Sea 3", function() invoke("TravelZou") end)
Tp:Section("Islands")
Tp:Dropdown("Island", islandList, "SelectedIsland")
Tp:Button("Teleport to Island", function()
	if not S.SelectedIsland then return notify("Teleport", "Select an island first") end
	tweenTo(islandCFrame(S.SelectedIsland))
end)
Tp:Section("NPCs & Players")
Tp:Dropdown("NPC", npcList, "SelectedNPC")
Tp:Button("Teleport to NPC", function()
	local npcs = workspace:FindFirstChild("NPCs")
	local npc = npcs and S.SelectedNPC and npcs:FindFirstChild(S.SelectedNPC)
	if not npc then return notify("Teleport", "NPC not found") end
	tweenTo(npc:GetPivot() * CFrame.new(0, 0, 4))
end)
Tp:Dropdown("Player", playerList, "SelectedPlayer")
Tp:Button("Teleport to Player", function()
	local p = S.SelectedPlayer and Players:FindFirstChild(S.SelectedPlayer)
	local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not r then return notify("Teleport", "Player not found") end
	tweenTo(r.CFrame * CFrame.new(0, 5, 0))
end)
Tp:Button("Stop Teleport", function() stopTween() end)

local Stats = createTab("Stats", "▲")
Stats:Section("Auto Stats")
Stats:Dropdown("Stat", function() return { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType")
Stats:Slider("Points Per Tick", 1, 100, "StatAmount")
Stats:Toggle("Auto Stats", "AutoStats")

local Visual = createTab("ESP", "◉")
Visual:Section("ESP")
Visual:Toggle("Player ESP", "PlayerESP")
Visual:Toggle("Fruit ESP", "FruitESP")
Visual:Toggle("Chest ESP", "ChestESP")

local Misc = createTab("Misc", "✦")
Misc:Section("Player")
Misc:Toggle("WalkSpeed", "SpeedOn", function(on)
	if not on then local h = getHum() if h then h.WalkSpeed = 16 end end
end)
Misc:Slider("Speed", 16, 300, "WalkSpeed")
Misc:Toggle("JumpPower", "JumpOn", function(on)
	if not on then local h = getHum() if h then h.JumpPower = 50 end end
end)
Misc:Slider("Jump", 50, 300, "JumpPower")
Misc:Toggle("Infinite Jump", "InfJump")
Misc:Toggle("Noclip", "Noclip")
Misc:Section("Server")
Misc:Toggle("Anti AFK", "AntiAFK")
Misc:Button("Server Hop", function()
	if not serverHop() then notify("Server Hop", "No server found") end
end)
Misc:Button("Rejoin", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
Misc:Button("FPS Boost", function()
	fpsBoost()
	notify("FPS Boost", "Done ✔")
end)
Misc:Button("Destroy Hub", function() Hub.Destroy() end)

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------
local ESP = {}
local function espSet(key, adornee, text, color)
	local e = ESP[key]
	if not e then
		local bb = new("BillboardGui", {
			AlwaysOnTop = true, Size = UDim2.fromOffset(200, 34), StudsOffset = Vector3.new(0, 3, 0),
			Adornee = adornee, Parent = espFolder,
		})
		local l = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 13,
			TextStrokeTransparency = 0.3, Parent = bb,
		})
		e = { gui = bb, label = l }
		ESP[key] = e
	end
	e.label.Text = text
	e.label.TextColor3 = color
	e.seen = true
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.3)
		pcall(function()
			for _, e in pairs(ESP) do e.seen = false end
			local myRoot = getRoot()
			local function dist(p)
				return myRoot and math.floor((p.Position - myRoot.Position).Magnitude) or 0
			end
			if S.PlayerESP then
				for _, p in ipairs(Players:GetPlayers()) do
					local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if r then
						local lv = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level")
						espSet(p, r, ("%s  [Lv %s]  %dm"):format(p.DisplayName, lv and lv.Value or "?", dist(r)), Color3.fromRGB(255, 90, 110))
					end
				end
			end
			if S.FruitESP then
				for _, f in ipairs(getWorldFruits()) do
					espSet(f.obj, f.part, ("%s  %dm"):format(f.obj.Name, dist(f.part)), Color3.fromRGB(120, 255, 160))
				end
			end
			if S.ChestESP then
				for i, c in ipairs(getChests()) do
					if i > 40 then break end
					espSet(c, c, ("%s  %dm"):format(c.Name, dist(c)), Color3.fromRGB(255, 210, 90))
				end
			end
			for k, e in pairs(ESP) do
				if not e.seen then
					e.gui:Destroy()
					ESP[k] = nil
				end
			end
		end)
		for _, d in ipairs(dynamicLabels) do
			pcall(function() d.label.Text = d.fn() end)
		end
	end
end)

---------------------------------------------------------------------
-- Window behaviour
---------------------------------------------------------------------
local minimized = false
local function showMain(show)
	if show then
		main.Visible = true
		tween(main, 0.45, { Size = minimized and UDim2.fromOffset(FULL.X.Offset, 50) or FULL }, Enum.EasingStyle.Back)
	else
		tween(main, 0.3, { Size = UDim2.fromOffset(0, 0) })
		task.delay(0.3, function()
			if main.Size.X.Offset < 5 then main.Visible = false end
		end)
	end
end

minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "–"
	tween(main, 0.35, { Size = minimized and UDim2.fromOffset(FULL.X.Offset, 50) or FULL })
end)
closeBtn.MouseButton1Click:Connect(function() showMain(false) end)

local function makeDraggable(handle, target, onClick)
	local dragging, startPos, startInput, moved
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			startInput, startPos = i.Position, target.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					if not moved and onClick then onClick() end
				end
			end)
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = (i.Position - startInput) / uiScale.Scale
			if d.Magnitude > 4 then moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end
makeDraggable(topbar, main)

-- دکمه‌ی شناور (برای موبایل)
local floatBtn = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 60, 0.3, 0), Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = Color3.new(1, 1, 1), Active = true, Visible = false, Parent = root,
}, { corner(26) })
animated(gradient(), 120).Parent = floatBtn
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.5, Parent = floatBtn })
new("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1), Text = "BM", Parent = floatBtn,
})
makeDraggable(floatBtn, floatBtn, function() showMain(not main.Visible or main.Size.X.Offset < 5) end)

connect(UserInputService.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		showMain(not main.Visible or main.Size.X.Offset < 5)
	end
end)

---------------------------------------------------------------------
-- Splash: خوش آمدید
---------------------------------------------------------------------
local function playSplash()
	local blur = new("BlurEffect", { Name = "BMHubBlur", Size = 0, Parent = Lighting })
	local splash = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 170),
		BackgroundColor3 = Theme.Bg, BackgroundTransparency = 1, Parent = root,
	}, { corner(18) })
	local sStroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 1, Parent = splash })
	animated(gradient(), 140).Parent = sStroke
	local sScale = new("UIScale", { Scale = 0.7, Parent = splash })

	local bigLogo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = splash,
	}, { corner(12) })
	animated(gradient(), 160).Parent = bigLogo
	local bigLogoText = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, Text = "BM", Parent = bigLogo,
	})
	local sTitle = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.GothamBlack, TextSize = 32, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
		Text = "BM Hub", Parent = splash,
	})
	animated(gradient(), 80).Parent = sTitle
	local sSub = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.SourceSansBold, TextSize = 24, TextColor3 = Theme.Text, TextTransparency = 1,
		Text = "خوش آمدید", Parent = splash,
	})
	local barBg = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 144), Size = UDim2.new(0.7, 0, 0, 5),
		BackgroundColor3 = Theme.Off, BackgroundTransparency = 1, Parent = splash,
	}, { corner(3) })
	local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBg }, { corner(3), gradient() })

	local fade = 0.6
	tween(blur, fade, { Size = 18 })
	tween(sScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(splash, fade, { BackgroundTransparency = 0.05 })
	tween(sStroke, fade, { Transparency = 0 })
	tween(bigLogo, fade, { BackgroundTransparency = 0 })
	tween(bigLogoText, fade, { TextTransparency = 0 })
	tween(sTitle, fade, { TextTransparency = 0 })
	tween(sSub, fade, { TextTransparency = 0 })
	tween(barBg, fade, { BackgroundTransparency = 0 })
	task.wait(0.4)
	tween(barFill, 2, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad)
	task.wait(2.3)

	tween(blur, 0.5, { Size = 0 })
	tween(sScale, 0.5, { Scale = 1.15 })
	for _, o in ipairs(splash:GetDescendants()) do
		if o:IsA("TextLabel") then tween(o, 0.4, { TextTransparency = 1 }) end
		if o:IsA("Frame") then tween(o, 0.4, { BackgroundTransparency = 1 }) end
		if o:IsA("UIStroke") then tween(o, 0.4, { Transparency = 1 }) end
	end
	tween(splash, 0.4, { BackgroundTransparency = 1 })
	task.wait(0.5)
	splash:Destroy()
	blur:Destroy()
end

task.spawn(function()
	local ok, err = pcall(playSplash)
	if not ok then
		warn("[BM Hub] splash error:", err)
		local b = Lighting:FindFirstChild("BMHubBlur")
		if b then b:Destroy() end
	end
	print("[BM Hub] ready")
	floatBtn.Visible = true
	showMain(true)
	task.wait(0.5)
	selectPage("Home")
	notify("BM Hub", ("Loaded ✔  Sea %s  •  %d quests"):format(Sea > 0 and Sea or "?", #QuestList), 4)
	if Sea == 0 then notify("BM Hub", "This doesn't look like Blox Fruits!", 5) end
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
connect(player.CharacterAdded, function()
	activeTween = nil
end)

function Hub.Destroy()
	Hub.Running = false
	for k, v in pairs(S) do
		if type(v) == "boolean" then S[k] = false end
	end
	stopTween()
	setFloat(false)
	for _, c in ipairs(Hub.Connections) do pcall(function() c:Disconnect() end) end
	pcall(function() root:Destroy() end)
	pcall(function() espFolder:Destroy() end)
end
