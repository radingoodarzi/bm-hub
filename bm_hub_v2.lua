--[[
	BM Hub  -  Blox Fruits
	Executors: Solara / Delta (PC + Mobile)

	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v2.lua"))()

	کلید RightControl یا دکمه‌ی شناور BM = باز/بسته کردن پنل
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if genv.BMHub and genv.BMHub.Destroy then pcall(genv.BMHub.Destroy) end
local Hub = { Connections = {}, Running = true, Version = "1.65" }
genv.BMHub = Hub
print("[BM Hub] loading v" .. Hub.Version)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Svc = { Teleport = game:GetService("TeleportService"), Http = game:GetService("HttpService"), VirtualUser = game:GetService("VirtualUser") }
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

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
local SEA_BY_PLACE = { [2753915549] = 1, [4442272183] = 2, [7449423635] = 3, [79091703265657] = 2, [100117331123089] = 3 }
local Sea = SEA_BY_PLACE[game.PlaceId] or 0

-- PlaceId ها عوض میشن، پس از اسم جزیره‌ها هم Sea رو تشخیص میدیم
local SEA_MARKERS = {
	{ 2, { "Kingdom of Rose", "Cafe", "Graveyard Island", "Snow Mountain", "Hot and Cold", "Cursed Ship", "Ice Castle", "Forgotten Island" } },
	{ 3, { "Port Town", "Hydra Island", "Great Tree", "Castle on the Sea", "Floating Turtle", "Haunted Castle", "Sea of Treats", "Tiki Outpost" } },
	{ 1, { "Windmill", "Marine Starter", "Middle Town", "Jungle", "Pirate Village", "Frozen Village", "Marine Fortress", "Skylands", "Prison", "Magma Village", "Fountain City" } },
}
pcall(function()
	if Sea ~= 0 then return end
	local loc = workspace._WorldOrigin.Locations
	for _, entry in ipairs(SEA_MARKERS) do
		for _, name in ipairs(entry[2]) do
			if loc:FindFirstChild(name) then
				Sea = entry[1]
				return
			end
		end
	end
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
local CommF = Remotes and Remotes:FindFirstChild("CommF_")

local function invoke(...)
	if not CommF then return nil end
	local ok, res = pcall(CommF.InvokeServer, CommF, ...)
	if ok then return res end
end

-- برای لیبل‌هایی که مدام آپدیت میشن: جواب سرور تا ttl ثانیه کش میشه
local invokeCache = {}
local function invokeCached(key, ttl, ...)
	local c = invokeCache[key]
	if c and tick() - c.t < ttl then return c.v end
	invokeCache[key] = { t = tick(), v = c and c.v }
	local args = { ... }
	task.spawn(function()
		invokeCache[key] = { t = tick(), v = invoke(table.unpack(args)) }
	end)
	return c and c.v
end

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local Net = Modules and Modules:FindFirstChild("Net")

-- اسم ریموت‌ها با آپدیت‌ها عوض میشه، پس با جستجو پیداشون می‌کنیم
local function findRemote(key)
	local hit
	pcall(function()
		for _, r in ipairs({ Net, Modules, ReplicatedStorage }) do
			if r then
				for _, d in ipairs(r:GetDescendants()) do
					if d:IsA("RemoteEvent") and d.Name:find(key, 1, true) then
						hit = d
						return
					end
				end
			end
		end
	end)
	return hit
end
local RegisterAttack = findRemote("RegisterAttack")
local RegisterHit = findRemote("RegisterHit")

local executorName = "?"
pcall(function() executorName = tostring((identifyexecutor or getexecutorname)()) end)

local notifyHook -- بعد از ساخت UI مقدار می‌گیره (برای اعلان از لوپ‌ها)
Hub.Errors = {}
local function logError(where, err)
	local msg = where .. ": " .. tostring(err)
	table.insert(Hub.Errors, msg)
	if #Hub.Errors > 8 then table.remove(Hub.Errors, 1) end
	warn("[BM Hub] " .. msg)
	if Hub.LiveLog then Hub.LiveLog("ERROR " .. msg) end
end

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
	BringMobs = true, FastAttack = true, Weapon = "Melee", AttackMethod = "Auto",
	FarmDistance = 3, TweenSpeed = 300, AutoClick = true, AttackRange = 60,

	MasteryFarm = false, MasteryWeapon = "Blox Fruit", MasteryHealth = 25,
	UseSkills = true, SkillZ = true, SkillX = true, SkillC = false, SkillV = false,
	AutoFactory = false, AutoEcto = false, AutoRengoku = false, AutoTrident = false, DealerNotify = true, AutoLegendary = false, AutoAllBosses = false,
	AutoRaid = false, AutoBuyChip = false, RaidType = "Flame", AutoDarkbeard = false,
	AutoTeam = true, TeamChoice = "Pirates", AutoSea2 = false, AutoBartilo = false, AutoSea3 = false, AutoSaber = false,
	AutoElite = false, AutoYama = false, AutoBone = false, AutoCake = false, AutoSeaBeast = false, SeaBeastWeapon = "Blox Fruit",
	AutoBoneGamble = false, AutoAbilities = false, AutoPirateRaid = false, EventNotify = true, AutoAwaken = false, AutoHakiColor = false, AutoMaterial = false, Material = nil, AutoRetreat = true, RetreatHP = 35, FarmSkills = true,
	AutoTushita = false, AutoCDK = false, AutoRaceV2 = false, AutoRaceV3 = false, AutoSoulGuitar = false, AutoStyles = false,
	AutoHopNear = false, HopDistance = 300, SelectedStyle = nil, AutoSave = true,
	AutoKen = false, AutoRace = false, BossESP = false, BossNotify = true, FruitNotify = true,
	CPUSaver = false, FPSCapOn = false, FPSCap = 30, AutoRejoin = true, StatType2 = "None",
	SelectedBossSpawn = nil,
	AutoBoss = false, SelectedBoss = nil, BossQuest = true,
	AutoHaki = true,
	AutoStats = false, StatType = "Melee", StatAmount = 3,
	AutoChest = false, AutoFruit = false, AutoStore = false, AutoRandomFruit = false,
	FruitMinBeli = 500000, FruitMinBeliK = 500, FruitMaxBuys = 3,
	FruitESP = false, ChestESP = false, PlayerESP = false, MobESP = false, NPCESP = false, IslandESP = false, EventESP = false,
	HuntHop = false, HuntTarget = nil, HuntWait = 12, HuntMaxHops = 40, HuntGoTo = true, MoonNotify = true,
	SpeedOn = false, WalkSpeed = 60, JumpOn = false, JumpPower = 80,
	Noclip = false, InfJump = false, AntiAFK = true, WalkOnWater = false, AutoBerries = false, Fullbright = false, NoFog = false,
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
-- فارم‌های اصلی اولویت دارن؛ صندوق/میوه وقتی اینا روشنن صبر می‌کنن تا سر حرکت دعوا نشه
local function mainFarmBusy()
	return S.AutoFarm or S.AutoBoss or S.AutoFactory or S.AutoEcto or S.AutoRengoku or S.AutoTrident or S.AutoAllBosses or S.AutoRaid or S.AutoDarkbeard
		or S.AutoSea2 or S.AutoBartilo or S.AutoSea3 or S.AutoSaber
		or S.AutoElite or S.AutoYama or S.AutoBone or S.AutoCake or S.AutoSeaBeast or S.AutoPirateRaid or S.AutoMaterial
		or S.AutoTushita or S.AutoCDK or S.AutoRaceV2 or S.AutoRaceV3 or S.AutoSoulGuitar or S.AutoStyles
		or (Hub.SpecialAny ~= nil and Hub.SpecialAny())
end

local function anyFarm()
	return S.AutoFarm or S.AutoBoss or S.AutoChest or S.AutoFruit or S.AutoFactory or S.AutoEcto
		or S.AutoRengoku or S.AutoTrident or S.AutoAllBosses or S.AutoRaid or S.AutoDarkbeard or S.AutoBerries
		or S.AutoSea2 or S.AutoBartilo or S.AutoSea3 or S.AutoSaber
		or S.AutoElite or S.AutoYama or S.AutoBone or S.AutoCake or S.AutoSeaBeast or S.AutoPirateRaid or S.AutoMaterial
		or S.AutoTushita or S.AutoCDK or S.AutoRaceV2 or S.AutoRaceV3 or S.AutoSoulGuitar or S.AutoStyles
		or (Hub.SpecialAny ~= nil and Hub.SpecialAny())
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
local tweenTo -- پایین‌تر تعریف میشه

-- سرعت پرواز بیشتر از 300 ریسک بن داره؛ هیچ‌وقت ازش بالاتر نمیره
local MAX_SAFE_SPEED = 300

-- پورتال‌های خود بازی: باید روی «نقطه‌ی ورود» بایستی و بعد requestEntrance با «مقصد» بفرستی
-- (همون کاری که اسکریپت AnimateEntrance خود بازی می‌کنه). هر ردیف: { مقصد، نقطه‌ی ورود }
local portalHop
do
local PORTALS = {
	[1] = {
		{ Vector3.new(61163.9, 11.7, 1819.8), Vector3.new(4050.3, -1.7, -1814.1) }, -- ورود به شهر زیر آب
		{ Vector3.new(3864.9, 6.7, -1926.8), Vector3.new(61170.0, -2, 1952.8) }, -- خروج از شهر زیر آب
		{ Vector3.new(-4166.6, 1093.7, -347.2), Vector3.new(-6020.3, 5469.2, 2209.8) }, -- آسمان
	},
	[3] = {
		{ Vector3.new(-5027.0, 316.5, -3206.7), Vector3.new(5650.9, 1017.3, -350.4) }, -- Hydra → Castle on the Sea
		{ Vector3.new(5650.9, 1017.3, -350.4), Vector3.new(-5027.0, 316.5, -3206.7) }, -- Castle → Hydra
		{ Vector3.new(-12463.6, 378.3, -7566.1), Vector3.new(-5060.4, 316.5, -3193.2) }, -- Castle → Mansion
		{ Vector3.new(-5060.4, 318.5, -3193.2), Vector3.new(-12463.6, 376.4, -7566.1) }, -- Mansion → Castle
	},
}
local portalBusy, lastPortal = false, 0

-- اگه «پرواز تا نقطه‌ی ورود + فاصله‌ی مقصد تا هدف» کوتاه‌تر از پرواز مستقیم باشه، از پورتال میریم
portalHop = function(target, keepGoing)
	local list = PORTALS[Sea]
	if portalBusy or not list or not getRoot() or tick() - lastPortal < 2 then return end
	portalBusy = true
	local prevStatus = S.Status
	-- تا 3 پورتال پشت سر هم (مثلاً Hydra → Castle → Mansion)
	for _ = 1, 3 do
		local root = getRoot()
		if not root or (keepGoing and not keepGoing()) then break end
		local best, bestCost
		for _, p in ipairs(list) do
			local cost = (target - p[1]).Magnitude + (root.Position - p[2]).Magnitude
			if not bestCost or cost < bestCost then best, bestCost = p, cost end
		end
		if not best or bestCost >= (root.Position - target).Magnitude * 0.8 then break end
		S.Status = "Using portal ⚡"
		tweenTo(CFrame.new(best[2] + Vector3.new(0, 3, 0)), keepGoing)
		task.wait(0.4)
		if not CollectionService:HasTag(player, "Teleporting") then invoke("requestEntrance", best[1]) end
		-- تا 4 ثانیه صبر می‌کنیم تا سرور جابجامون کنه
		local moved, t = false, 0
		while t < 4 do
			t += task.wait(0.1)
			local r = getRoot()
			if r and (r.Position - best[1]).Magnitude < (r.Position - best[2]).Magnitude then moved = true break end
		end
		lastPortal = tick()
		if not moved then break end
		task.wait(0.5)
	end
	S.Status = prevStatus
	portalBusy = false
end
end -- پورتال‌ها

-- manual = true یعنی دکمه‌ی تلپورت دستی (نه فارم)
tweenTo = function(cf, keepGoing, manual)
	local root = getRoot()
	if not root or not cf then return false end
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	if (root.Position - cf.Position).Magnitude > 1500 then
		pcall(portalHop, cf.Position, keepGoing)
		root = getRoot()
		if not root then return false end
	end
	local dist = (root.Position - cf.Position).Magnitude
	if dist <= 10 then
		root.CFrame = cf
		return true
	end
	stopTween()
	setFloat(true)
	local t = TweenService:Create(root, TweenInfo.new(dist / math.clamp(S.TweenSpeed, 50, MAX_SAFE_SPEED), Enum.EasingStyle.Linear), { CFrame = cf })
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
-- "Smoke Admiral [Lv. 1150] [Boss]" -> "Smoke Admiral"
local function mobBaseName(name)
	return (name:gsub("%s*%[.-%]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- مابی که مدتی آسیب نمی‌بینه (گیر کرده توی دیوار/آب) یه مدت نادیده گرفته میشه
local mobSkipUntil = setmetatable({}, { __mode = "k" })

local function isAliveMob(m)
	if (mobSkipUntil[m] or 0) > tick() then return false end
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

-- نکته: Luau حداکثر 200 متغیر local در یک اسکوپ قبول می‌کنه؛ بخش‌های مستقل داخل do ... end هستن
local FALLBACK_BY_SEA
do
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
-- مختصات تقریبی NPC ها؛ اگه کوئست قبول نشه، خودش بدون کوئست همون مانستر رو فارم می‌کنه
local FALLBACK_SEA2 = {
	{ 700, "Area1Quest", 1, "Raider", Vector3.new(-429.54, 71.77, 1836.18) },
	{ 725, "Area1Quest", 2, "Mercenary", Vector3.new(-429.54, 71.77, 1836.18) },
	{ 775, "Area2Quest", 1, "Swan Pirate", Vector3.new(638.43, 71.77, 918.28) },
	{ 800, "Area2Quest", 2, "Factory Staff", Vector3.new(638.43, 71.77, 918.28) },
	{ 875, "MarineQuest3", 1, "Marine Lieutenant", Vector3.new(-2440.79, 71.71, -3216.06) },
	{ 900, "MarineQuest3", 2, "Marine Captain", Vector3.new(-2440.79, 71.71, -3216.06) },
	{ 950, "ZombieQuest", 1, "Zombie", Vector3.new(-5497.06, 47.59, -795.23) },
	{ 975, "ZombieQuest", 2, "Vampire", Vector3.new(-5497.06, 47.59, -795.23) },
	{ 1000, "SnowMountainQuest", 1, "Snow Trooper", Vector3.new(609.85, 400.11, -5372.25) },
	{ 1050, "SnowMountainQuest", 2, "Winter Warrior", Vector3.new(609.85, 400.11, -5372.25) },
	{ 1100, "IceSideQuest", 1, "Lab Subordinate", Vector3.new(-6064.06, 15.24, -4902.97) },
	{ 1125, "IceSideQuest", 2, "Horned Warrior", Vector3.new(-6064.06, 15.24, -4902.97) },
	{ 1175, "FireSideQuest", 1, "Magma Ninja", Vector3.new(-5428.03, 15.06, -5299.43) },
	{ 1200, "FireSideQuest", 2, "Lava Pirate", Vector3.new(-5428.03, 15.06, -5299.43) },
	{ 1250, "ShipQuest1", 1, "Ship Deckhand", Vector3.new(1037.80, 125.09, 32911.60) },
	{ 1275, "ShipQuest1", 2, "Ship Engineer", Vector3.new(1037.80, 125.09, 32911.60) },
	{ 1300, "ShipQuest2", 1, "Ship Steward", Vector3.new(968.80, 125.09, 33244.12) },
	{ 1325, "ShipQuest2", 2, "Ship Officer", Vector3.new(968.80, 125.09, 33244.12) },
	{ 1350, "FrostQuest", 1, "Arctic Warrior", Vector3.new(5667.65, 26.79, -6486.08) },
	{ 1375, "FrostQuest", 2, "Snow Lurker", Vector3.new(5667.65, 26.79, -6486.08) },
	{ 1425, "ForgottenQuest", 1, "Sea Soldier", Vector3.new(-3054.44, 235.54, -10142.81) },
	{ 1450, "ForgottenQuest", 2, "Water Fighter", Vector3.new(-3054.44, 235.54, -10142.81) },
}
local FALLBACK_SEA3 = {
	{ 1500, "PiratePortQuest", 1, "Pirate Millionaire", Vector3.new(-290.07, 42.90, 5581.58) },
	{ 1525, "PiratePortQuest", 2, "Pistol Billionaire", Vector3.new(-290.07, 42.90, 5581.58) },
	{ 1575, "AmazonQuest", 1, "Dragon Crew Warrior", Vector3.new(5832.83, 51.68, -1101.51) },
	{ 1600, "AmazonQuest", 2, "Dragon Crew Archer", Vector3.new(5832.83, 51.68, -1101.51) },
	{ 1625, "AmazonQuest2", 1, "Female Islander", Vector3.new(5448.86, 601.52, 751.13) },
	{ 1650, "AmazonQuest2", 2, "Giant Islander", Vector3.new(5448.86, 601.52, 751.13) },
	{ 1700, "MarineTreeIsland", 1, "Marine Commodore", Vector3.new(2180.54, 27.82, -6741.55) },
	{ 1725, "MarineTreeIsland", 2, "Marine Rear Admiral", Vector3.new(2180.54, 27.82, -6741.55) },
	{ 1775, "DeepForestIsland3", 1, "Fishman Raider", Vector3.new(-10581.66, 330.87, -8761.19) },
	{ 1800, "DeepForestIsland3", 2, "Fishman Captain", Vector3.new(-10581.66, 330.87, -8761.19) },
	{ 1825, "DeepForestIsland", 1, "Forest Pirate", Vector3.new(-13234.04, 331.49, -7625.40) },
	{ 1850, "DeepForestIsland", 2, "Mythological Pirate", Vector3.new(-13234.04, 331.49, -7625.40) },
	{ 1900, "DeepForestIsland2", 1, "Jungle Pirate", Vector3.new(-12680.39, 389.97, -9902.02) },
	{ 1925, "DeepForestIsland2", 2, "Musketeer Pirate", Vector3.new(-12680.39, 389.97, -9902.02) },
	{ 1975, "HauntedQuest1", 1, "Reborn Skeleton", Vector3.new(-9479.22, 141.22, 5566.09) },
	{ 2000, "HauntedQuest1", 2, "Living Zombie", Vector3.new(-9479.22, 141.22, 5566.09) },
	{ 2025, "HauntedQuest2", 1, "Demonic Soul", Vector3.new(-9516.99, 172.02, 6078.47) },
	{ 2050, "HauntedQuest2", 2, "Posessed Mummy", Vector3.new(-9516.99, 172.02, 6078.47) },
	{ 2075, "NutsIslandQuest", 1, "Peanut Scout", Vector3.new(-2104.39, 38.10, -10194.22) },
	{ 2100, "NutsIslandQuest", 2, "Peanut President", Vector3.new(-2104.39, 38.10, -10194.22) },
	{ 2125, "IceCreamIslandQuest", 1, "Ice Cream Chef", Vector3.new(-820.65, 65.82, -10965.80) },
	{ 2150, "IceCreamIslandQuest", 2, "Ice Cream Commander", Vector3.new(-820.65, 65.82, -10965.80) },
	{ 2200, "CakeQuest1", 1, "Cookie Crafter", Vector3.new(-2021.32, 37.80, -12028.73) },
	{ 2225, "CakeQuest1", 2, "Cake Guard", Vector3.new(-2021.32, 37.80, -12028.73) },
	{ 2250, "CakeQuest2", 1, "Baking Staff", Vector3.new(-1927.92, 37.80, -12842.54) },
	{ 2275, "CakeQuest2", 2, "Head Baker", Vector3.new(-1927.92, 37.80, -12842.54) },
	{ 2300, "ChocQuest1", 1, "Cocoa Warrior", Vector3.new(233.23, 29.88, -12201.23) },
	{ 2325, "ChocQuest1", 2, "Chocolate Bar Battler", Vector3.new(233.23, 29.88, -12201.23) },
	{ 2350, "ChocQuest2", 1, "Sweet Thief", Vector3.new(150.51, 30.69, -12774.50) },
	{ 2375, "ChocQuest2", 2, "Candy Rebel", Vector3.new(150.51, 30.69, -12774.50) },
	{ 2400, "CandyQuest1", 1, "Candy Pirate", Vector3.new(-1150.04, 20.38, -14446.33) },
	{ 2425, "CandyQuest1", 2, "Snow Demon", Vector3.new(-1150.04, 20.38, -14446.33) },
	{ 2450, "TikiQuest1", 1, "Isle Outlaw", Vector3.new(-16547.75, 61.13, -173.41) },
	{ 2475, "TikiQuest1", 2, "Island Boy", Vector3.new(-16547.75, 61.13, -173.41) },
	{ 2500, "TikiQuest2", 1, "Sun-kissed Warrior", Vector3.new(-16539.08, 55.69, 1051.57) },
	{ 2525, "TikiQuest2", 2, "Isle Champion", Vector3.new(-16539.08, 55.69, 1051.57) },
	{ 2550, "TikiQuest3", 1, "Serpent Hunter", Vector3.new(-16665.19, 104.60, 1579.69) },
	{ 2575, "TikiQuest3", 2, "Skull Slayer", Vector3.new(-16665.19, 104.60, 1579.69) },
}
FALLBACK_BY_SEA = { FALLBACK_SEA1, FALLBACK_SEA2, FALLBACK_SEA3 }
end

local FALLBACK_BOSSES = {
	"The Gorilla King", "Bobby", "Yeti", "Mob Leader", "Vice Admiral", "Warden", "Chief Warden",
	"Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Saber Expert", "Greybeard",
}

local QuestList, BossList = {}, {}

local function useFallback()
	local list = FALLBACK_BY_SEA[Sea]
	if #QuestList == 0 and list then
		for _, f in ipairs(list) do
			table.insert(QuestList, { level = f[1], quest = f[2], index = f[3], mob = f[4], npc = CFrame.new(f[5]) })
		end
	end
end

-- مختصات تقریبی هر کوئست (از جدول‌های پشتیبان) برای پیدا کردن NPC درست
local QUEST_REF = {}
for _, list in ipairs(FALLBACK_BY_SEA) do
	for _, f in ipairs(list) do
		if not QUEST_REF[f[2]] then QUEST_REF[f[2]] = f[5] end
	end
end

-- ماب‌هایی که توی این Sea وجود دارن
local function seaMobSet()
	local set, n = {}, 0
	local function addName(name)
		local b = mobBaseName(name)
		if not set[b] then
			set[b] = true
			n += 1
		end
	end
	local sp = spawnFolder()
	if sp then
		for _, p in ipairs(sp:GetChildren()) do addName(p.Name) end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, m in ipairs(enemies:GetChildren()) do addName(m.Name) end
	end
	for _, m in ipairs(ReplicatedStorage:GetChildren()) do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then addName(m.Name) end
	end
	return set, n
end

local function questGivers()
	local list = {}
	for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
		if folder then
			for _, npc in ipairs(folder:GetChildren()) do
				if npc.Name:find("Quest") then
					local ok, cf = pcall(function() return npc:GetPivot() end)
					if ok and cf.Position.Y > -500 then table.insert(list, cf) end
				end
			end
		end
	end
	return list
end

local function spawnCentroid(mob)
	local sp = spawnFolder()
	if not sp then return nil end
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(sp:GetChildren()) do
		if p:IsA("BasePart") and mobBaseName(p.Name) == mob then
			sum += p.Position
			n += 1
		end
	end
	return n > 0 and sum / n or nil
end

-- نزدیک‌ترین NPC کوئست‌دهنده به محل تقریبی کوئست یا محل اسپاون ماب‌ها
local function findQuestNpc(givers, qName, mob)
	local ref = QUEST_REF[qName] or spawnCentroid(mob)
	if not ref then return nil end
	local best, bestDist
	for _, cf in ipairs(givers) do
		local d = (cf.Position - ref).Magnitude
		if d < 700 and (not bestDist or d < bestDist) then best, bestDist = cf, d end
	end
	return best or CFrame.new(ref)
end

-- فقط ماژول Quests خونده میشه؛ GuideModule روی Solara گیر می‌کنه
local function loadQuestData()
	local QuestsMod = safeRequire(ReplicatedStorage:FindFirstChild("Quests"))
	if not QuestsMod then error("Quests module not readable") end
	local mobs, mobCount = seaMobSet()
	local givers = questGivers()
	local quests, bosses = {}, {}
	for qName, entries in pairs(QuestsMod) do
		if type(entries) == "table" then
			for idx, e in pairs(entries) do
				if type(e) == "table" and type(e.LevelReq) == "number" and type(e.Task) == "table" then
					local mob, count = next(e.Task)
					local inSea = mobCount == 0 or mobs[mob]
					-- کوئست‌های خاص (مثل 50 تایی‌ها) حذف میشن
					if type(mob) == "string" and type(count) == "number" and count <= 20 and inSea then
						local entry = { quest = qName, index = idx, level = e.LevelReq, mob = mob, npc = findQuestNpc(givers, qName, mob) }
						if count == 1 then
							table.insert(bosses, entry)
						elseif entry.npc then
							table.insert(quests, entry)
						end
					end
				end
			end
		end
	end
	if #quests > 0 then
		table.clear(QuestList)
		for _, q in ipairs(quests) do table.insert(QuestList, q) end
	end
	table.clear(BossList)
	for _, b in ipairs(bosses) do table.insert(BossList, b) end
	table.sort(QuestList, function(a, b) return a.level < b.level end)
	table.sort(BossList, function(a, b) return a.level < b.level end)
end

useFallback()
task.spawn(function()
	local ok, err = pcall(loadQuestData)
	Hub.QuestLoadInfo = ok and (#QuestList .. " quests, " .. #BossList .. " bosses") or ("error: " .. tostring(err))
	print("[BM Hub] quest data:", Hub.QuestLoadInfo)
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

-- کوئست با پیشرفت کامل مثل (8/8) تموم‌شده حساب میشه
local function questDone(txt)
	local cur, total = txt:match("(%d+)%s*/%s*(%d+)")
	return cur ~= nil and tonumber(cur) >= tonumber(total)
end

-- متن کوئست فعال (یا nil). بازی جای کادر کوئست رو عوض کرده، پس اگه کادر قدیمی نبود
-- توی کل PlayerGui دنبال متن «Defeat ... (x/y)» که روی صفحه‌ست می‌گردیم
local questLabel
local function shownOnScreen(o)
	while o and o:IsA("GuiObject") do
		if not o.Visible then return false end
		o = o.Parent
	end
	return not (o and o:IsA("ScreenGui")) or o.Enabled
end
local function labelQuestText(d)
	local t = d.Text
	if t:find("%d+%s*/%s*%d+") then return t end
	-- پیشرفت (x/y) گاهی یه لیبل جداست
	for _, o in ipairs(d.Parent and d.Parent:GetDescendants() or {}) do
		if o ~= d and o:IsA("TextLabel") and o.Text:find("^%s*%(?%d+%s*/%s*%d+%)?%s*$") then return t .. " (" .. o.Text:gsub("[%(%)%s]", "") .. ")" end
	end
	return t
end
local function questTitle()
	local g = questGui()
	local t
	pcall(function() if g and g.Visible then t = g.Container.QuestTitle.Title.Text end end)
	if t and t ~= "" then return t end
	if questLabel and questLabel.Parent and shownOnScreen(questLabel) and questLabel.Text:lower():find("^%s*defeat") then
		return labelQuestText(questLabel)
	end
	if tick() - (Hub.QuestScanAt or 0) < 2 then return nil end
	Hub.QuestScanAt = tick()
	questLabel = nil
	local pg = player:FindFirstChild("PlayerGui")
	for _, d in ipairs(pg and pg:GetDescendants() or {}) do
		if d:IsA("TextLabel") and d.Text:lower():find("^%s*defeat") and d.Parent and d.Parent.Name ~= "BMHub" and shownOnScreen(d) then
			questLabel = d
			Hub.QuestLabelPath = d:GetFullName()
			return labelQuestText(d)
		end
	end
end

-- اسم ماب توی متن کوئست: کامل، یا (برای غلط املایی مثل Posessed/Possessed و جمع مثل Mummies)
-- 3 حرف اول کلمه‌ی اول + 4 حرف اول کلمه‌ی آخر
local function titleHasMob(txt, mob)
	local l, m = txt:lower(), mob:lower()
	if l:find(m, 1, true) then return true end
	local first, last = m:match("^(%a+)"), m:match("(%a+)$")
	return first ~= nil and l:find(first:sub(1, 3), 1, true) ~= nil and l:find(last:sub(1, 4), 1, true) ~= nil
end

local function hasQuest(mob)
	local txt = questTitle()
	-- کادر کوئست پیدا نشد ولی سرور گفت قبول شد (0) → تا 60 ثانیه فعال حسابش می‌کنیم
	if not txt then
		return Hub.QuestTakenMob ~= nil and (mob == nil or Hub.QuestTakenMob == mob) and tick() - (Hub.QuestTakenAt or 0) < 60
	end
	if questDone(txt) then return false end
	if not mob then return true end
	return titleHasMob(txt, mob)
end

-- اگه کوئستی چند بار گرفته نشد، یه مدت بدون کوئست فارم می‌کنیم
local questFailures, questBlockedUntil = {}, {}
local function questBlocked(q)
	return (questBlockedUntil[q.quest .. q.index] or 0) > tick()
end

local function takeQuest(q, keepGoing)
	local started = tick()
	-- فقط کوئست یه ماب دیگه رو ول می‌کنیم؛ کوئست تموم‌شده (8/8) خودش تحویل میشه
	local cur = questTitle()
	if cur and not questDone(cur) and not titleHasMob(cur, q.mob) then invoke("AbandonQuest") end
	local key = q.quest .. q.index
	-- لول کافی نیست → سرور قبول نمی‌کنه؛ اصلاً نمیریم پیش NPC
	if q.level and q.level > (dataValue("Level") or 0) then
		questBlockedUntil[key] = tick() + 60
		return
	end
	S.Status = "Taking quest: " .. q.mob
	if not tweenTo(q.npc, keepGoing) then return end
	-- جای ذخیره‌شده ممکنه چند قدم با NPC واقعی فرق کنه؛ الان که لود شده، خود NPC رو پیدا می‌کنیم
	local npcCF, npcName = q.npc, "saved position"
	pcall(function()
		local bestD
		for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
			for _, npc in ipairs(folder and folder:GetChildren() or {}) do
				local d = (npc:GetPivot().Position - q.npc.Position).Magnitude
				if npc.Name:find("Quest") and d < 80 and (not bestD or d < bestD) then
					npcCF, npcName, bestD = npc:GetPivot(), npc.Name, d
				end
			end
		end
	end)
	if npcCF ~= q.npc then tweenTo(npcCF, keepGoing) end
	-- سرور موقعیت جدید رو با کمی تاخیر می‌بینه
	setFloat(true)
	task.wait(0.5)
	-- متن کوئست همیشه دقیقاً اسم ماب نیست؛ هر کوئست فعال و تموم‌نشده یعنی گرفته شد
	local function taken()
		if hasQuest(q.mob) then return true end
		local title = questTitle()
		return title ~= nil and not questDone(title)
	end
	local res
	for attempt = 1, 2 do
		if (keepGoing and not keepGoing()) or not alive() then return end
		S.Status = ("Taking quest: %s (try %d/2)"):format(q.mob, attempt)
		local root = getRoot()
		if root then root.CFrame = npcCF end
		res = invoke("StartQuest", q.quest, q.index)
		-- از کد خود بازی: 0 = قبول شد، 1 = خطا، 2 = قبلاً تموم کردی، بقیه = لول کم
		local waited = 0
		while res ~= 0 and waited < 1.2 and not taken() do
			waited += task.wait(0.1)
		end
		if res == 0 or taken() then
			Hub.QuestTakenAt, Hub.QuestTakenMob = tick(), q.mob
			questFailures[key] = 0
			Hub.LastQuestTime = tick() - started
			S.Status = ("Quest taken in %.1fs: %s"):format(Hub.LastQuestTime, q.mob)
			return
		end
	end
	questFailures[key] = (questFailures[key] or 0) + 1
	local r = getRoot()
	logError("StartQuest " .. key, ("not accepted (%s) npc=%s dist=%.0f"):format(tostring(res), npcName, r and (r.Position - npcCF.Position).Magnitude or -1))
	if questFailures[key] >= 3 then
		-- مدت کوتاه بدون کوئست، بعد دوباره تلاش
		questBlockedUntil[key] = tick() + 15
		questFailures[key] = 0
	end
end

---------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------
local function findWeapon()
	local bp = player:FindFirstChild("Backpack")
	local fallback
	for _, cont in ipairs({ getChar(), bp }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") then
					if t.ToolTip == S.Weapon then return t end
					if not fallback and t.ToolTip == "Melee" then fallback = t end
				end
			end
		end
	end
	if fallback then return fallback end
	-- اگه ToolTip ها فرق داشتن، اولین ابزار
	for _, cont in ipairs({ getChar(), bp }) do
		if cont then
			local t = cont:FindFirstChildOfClass("Tool")
			if t then return t end
		end
	end
end

local function equipWeapon(tooltip)
	local t, h
	if tooltip then
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont and not t then
				for _, tool in ipairs(cont:GetChildren()) do
					if tool:IsA("Tool") and tool.ToolTip == tooltip then
						t = tool
						break
					end
				end
			end
		end
	end
	t, h = t or findWeapon(), getHum()
	if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
end

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

Hub.AttackInfo = { remote = 0, click = 0, tool = 0, lastError = "none" }

local function clickScreen()
	local vs = camera.ViewportSize
	local pos = Vector2.new(vs.X * 0.85, vs.Y * 0.45)
	local ok, err = pcall(function()
		Svc.VirtualUser:CaptureController()
		Svc.VirtualUser:Button1Down(pos, camera.CFrame)
		Svc.VirtualUser:Button1Up(pos, camera.CFrame)
	end)
	if not ok and VIM then
		ok, err = pcall(function()
			VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
			VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
		end)
	end
	if ok then
		Hub.AttackInfo.click += 1
	else
		Hub.AttackInfo.lastError = "click: " .. tostring(err)
	end
end

local cooldown = { remote = 0, click = 0, skill = 0 }
local function remoteAttack(root)
	if not (RegisterAttack and RegisterHit) then return end
	if tick() - cooldown.remote < 0.1 then return end
	cooldown.remote = tick()
	local hits = {}
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= S.AttackRange then
				table.insert(hits, { m, m:FindFirstChild("Head") or m.HumanoidRootPart })
			end
		end
	end
	if #hits == 0 then return end
	local ok, err = pcall(function()
		RegisterAttack:FireServer(0)
		RegisterHit:FireServer(hits[1][2], hits)
	end)
	if ok then
		Hub.AttackInfo.remote += 1
	else
		Hub.AttackInfo.lastError = "remote: " .. tostring(err)
	end
end

local function attack()
	local root = getRoot()
	if not root then return end
	local m = S.AttackMethod
	if S.FastAttack and (m == "Auto" or m == "Remote") then remoteAttack(root) end
	if tick() - cooldown.click < 0.12 then return end
	cooldown.click = tick()
	if m == "Auto" or m == "Tool" then
		local tool = getChar() and getChar():FindFirstChildOfClass("Tool")
		if tool and pcall(function() tool:Activate() end) then
			Hub.AttackInfo.tool += 1
		end
	end
	if m == "Auto" or m == "Click" then clickScreen() end
end

-- استفاده از اسکیل‌ها (Z X C V) با شبیه‌سازی کیبورد
local SKILL_KEYS = { Z = Enum.KeyCode.Z, X = Enum.KeyCode.X, C = Enum.KeyCode.C, V = Enum.KeyCode.V }
local function useSkills()
	if not S.UseSkills or not VIM or tick() - cooldown.skill < 0.6 then return end
	cooldown.skill = tick()
	for _, k in ipairs({ "Z", "X", "C", "V" }) do
		if S["Skill" .. k] then
			pcall(function()
				VIM:SendKeyEvent(true, SKILL_KEYS[k], false, game)
				task.wait(0.05)
				VIM:SendKeyEvent(false, SKILL_KEYS[k], false, game)
			end)
		end
	end
end

local function enemyInRange()
	local root = getRoot()
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then return false end
	for _, m in ipairs(enemies:GetChildren()) do
		if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= S.AttackRange then
			return true
		end
	end
	return false
end

-- کلیک خودکار: همیشه به ماب‌های داخل Attack Range حمله می‌کنه، حتی وقتی فارم خاموشه
task.spawn(function()
	while Hub.Running do
		task.wait(0.1)
		if S.AutoClick and alive() and enemyInRange() then
			pcall(function()
				equipWeapon()
				attack()
			end)
		end
	end
end)

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
	local lastHp, lastHit = hum and hum.Health or 0, tick()
	while Hub.Running and keepGoing() and alive() and mob.Parent and hum and hum.Health > 0 do
		local root = getRoot()
		-- جون کم: میریم بالا (بیرون از دسترس ماب‌ها) تا جون برگرده، بعد ادامه
		local me = getHum()
		if S.AutoRetreat and me and me.MaxHealth > 0 and me.Health / me.MaxHealth * 100 < S.RetreatHP then
			S.Status = "Low HP — healing above the mobs"
			tweenTo(CFrame.new(root.Position + Vector3.new(0, 150, 0)), keepGoing)
			local t0 = tick()
			while keepGoing() and alive() and tick() - t0 < 30 do
				local h = getHum()
				if not h or h.Health / h.MaxHealth >= 0.8 then break end
				setFloat(true)
				task.wait(0.5)
			end
			lastHit = tick()
			S.Status = "Farming: " .. name
			root = getRoot()
			if not root then break end
		end
		-- اگه 8 ثانیه کنارش بودیم و جونش کم نشد، گیر کرده: 45 ثانیه رد میشیم و میریم سراغ بعدی
		if hum.Health < lastHp - 1 then
			lastHp, lastHit = hum.Health, tick()
		elseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120 then
			mobSkipUntil[mob] = tick() + 45
			S.Status = "Skipping stuck " .. name
			break
		end
		-- از کد بازی: هیت‌باکس M1 حدود 10 استاد جلوی کاراکتره و فقط ماب‌های «جلو»ی تو رو می‌زنه.
		-- پس 4 استاد کنار ماب (سمتی که خودمون هستیم)، کمی بالاتر، رو به ماب (ارتفاع زیاد = هیچ ضربه‌ای ثبت نمیشه)
		local h = math.clamp(S.FarmDistance, 0, 6)
		local away = Vector3.new(root.Position.X - hrp.Position.X, 0, root.Position.Z - hrp.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
		local standAt = hrp.Position + away * 4 + Vector3.new(0, h, 0)
		local target = CFrame.lookAt(standAt, Vector3.new(hrp.Position.X, standAt.Y, hrp.Position.Z))
		-- Mastery: وقتی جون ماب کم شد، با سلاح مستری تمومش می‌کنیم
		local masteryPhase = S.MasteryFarm and hum.MaxHealth > 0 and (hum.Health / hum.MaxHealth) * 100 <= S.MasteryHealth
		if (root.Position - target.Position).Magnitude > 80 then
			tweenTo(target, keepGoing)
		else
			setFloat(true)
			root.CFrame = masteryPhase and CFrame.lookAt(target.Position, hrp.Position) or target
		end
		if masteryPhase then
			equipWeapon(S.MasteryWeapon)
			useSkills()
		else
			equipWeapon()
		end
		if S.BringMobs then bringMobs(name, hrp.CFrame) end
		attack(mob)
		-- اسکیل‌ها وقتی ماب هنوز پرجونه (دمیج زیاد = زمان کمتر کنار ماب)
		if S.FarmSkills and not masteryPhase and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth > 0.25 then useSkills() end
		task.wait(0.08)
	end
end

---------------------------------------------------------------------
-- Farm loops
---------------------------------------------------------------------
-- لول مانستر از اسم / DisplayName / Attribute
local function mobLevel(m)
	local a = m:GetAttribute("Level")
	if type(a) == "number" then return a end
	local h = m:FindFirstChildOfClass("Humanoid")
	for _, s in ipairs({ m.Name, h and h.DisplayName or "" }) do
		local n = s:match("Lv%.?%s*(%d+)")
		if n then return tonumber(n) end
	end
end

-- بدون داده‌ی کوئست: بهترین مانستر بر اساس لول، وگرنه نزدیک‌ترین
local function pickMobByLevel()
	local enemies = workspace:FindFirstChild("Enemies")
	local root = getRoot()
	if not enemies or not root then return nil end
	local myLevel = dataValue("Level") or 1
	local best, bestLv, bestDist, nearest, nearestDist
	for _, m in ipairs(enemies:GetChildren()) do
		if isAliveMob(m) then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if not nearestDist or d < nearestDist then nearest, nearestDist = m, d end
			local lv = mobLevel(m)
			if lv and lv <= myLevel then
				if not bestLv or lv > bestLv or (lv == bestLv and d < bestDist) then
					best, bestLv, bestDist = m, lv, d
				end
			end
		end
	end
	return best or nearest
end

-- اسم مانستر رو از متن کوئست فعال روی صفحه درمیاره (مثلا "Defeat 5 Bandits (0/5)")
local candidateCache = { t = 0, set = {} }
local questMobCache = { t = 0 }
local function activeQuestMob()
	local title = questTitle()
	if not title or title == "" or questDone(title) then return nil end
	-- متن کوئست با پیشرفت عوض میشه، پس بدون (x/y) کش می‌کنیم
	local base = title:gsub("%(.-%)", "")
	if questMobCache.title == base and tick() - questMobCache.t < 10 then return questMobCache.mob end
	local lower = base:lower()
	if tick() - candidateCache.t > 10 then
		local candidates = {}
		for _, q in ipairs(QuestList) do candidates[q.mob] = true end
		for _, q in ipairs(BossList) do candidates[q.mob] = true end
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do candidates[mobBaseName(m.Name)] = true end
		end
		local sp = spawnFolder()
		if sp then
			for _, p in ipairs(sp:GetChildren()) do candidates[mobBaseName(p.Name)] = true end
		end
		candidateCache = { t = tick(), set = candidates }
	end
	local best
	for name in pairs(candidateCache.set) do
		if lower:find(name:lower(), 1, true) and (not best or #name > #best) then best = name end
	end
	questMobCache = { title = base, mob = best, t = tick() }
	return best
end

local function farmTarget()
	if S.FarmMode == "Selected Mob" and S.SelectedMob then
		return questForMob(S.SelectedMob) or { mob = S.SelectedMob, noQuest = true }
	end
	if S.FarmMode == "Nearest Mob" then return nil end
	return questForLevel(dataValue("Level") or 1)
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.1)
		if S.AutoFarm and alive() then
			local keep = function() return S.AutoFarm end
			local ok, err = pcall(function()
				-- اول کوئستی که الان داری
				if S.FarmMode ~= "Selected Mob" then
					local qm = activeQuestMob()
					if qm then
						local mob = findMob(qm)
						if mob then
							killMob(mob, function() return S.AutoFarm and activeQuestMob() == qm end)
						else
							S.Status = "Waiting for " .. qm
							local q2 = questForMob(qm)
							local sp = mobSpawn(qm) or (q2 and q2.npc)
							if sp then
								tweenTo(sp * CFrame.new(0, 30, 0), function() return S.AutoFarm and not findMob(qm) end)
							end
						end
						return
					end
				end
				local q = farmTarget()
				if not q then
					local mob = pickMobByLevel()
					if not mob then
						S.Status = "No mobs found nearby"
						return
					end
					killMob(mob, keep)
					return
				end
				local useQuest = S.TakeQuest and not q.noQuest and q.npc and not questBlocked(q)
				if useQuest and not hasQuest(q.mob) then
					takeQuest(q, keep)
					-- کوئست گرفته شد؟ همین الان برو سراغ ماب‌ها، بدون دور اضافه‌ی لوپ
					if not hasQuest(q.mob) then return end
				end
				local mob = findMob(q.mob)
				if not mob then
					S.Status = "Waiting for " .. q.mob
					local sp = mobSpawn(q.mob) or (q.npc and q.npc * CFrame.new(0, 30, 0))
					if sp then
						tweenTo(sp * CFrame.new(0, 30, 0), function() return S.AutoFarm and not findMob(q.mob) end)
					end
					return
				end
				killMob(mob, function() return S.AutoFarm and (not useQuest or hasQuest(q.mob)) end)
			end)
			if not ok then
				S.Status = "Error: " .. tostring(err)
				logError("AutoFarm", err)
				task.wait(1)
			end
		end
	end
end)

-- Boss
task.spawn(function()
	while Hub.Running do
		task.wait(0.2)
		if S.AutoBoss and S.SelectedBoss and alive() then
			local keep = function() return S.AutoBoss end
			local ok, err = pcall(function()
				local boss = findMobAnywhere(S.SelectedBoss)
				if not boss then
					S.Status = S.SelectedBoss .. " not spawned"
					return
				end
				local q = questForMob(S.SelectedBoss)
				if S.BossQuest and q and not questBlocked(q) and not hasQuest(q.mob) then
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
			if not ok then
				logError("AutoBoss", err)
				task.wait(1)
			end
		end
	end
end)

do
-- Sea 2: Factory (Core) و Ectoplasm (ماب‌های Cursed Ship)
local FACTORY_POS = Vector3.new(431, 238, -433)
local CURSED_SHIP_POS = Vector3.new(900.9, 144, 33072.6)
local ECTO_MOBS = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" }
local ECTO_BOSSES = { "Cursed Captain" }

task.spawn(function()
	while Hub.Running do
		task.wait(0.3)
		if S.AutoFactory and alive() then
			local keep = function() return S.AutoFactory end
			local ok, err = pcall(function()
				local core = findMobAnywhere("Core")
				if not core then
					S.Status = "Factory closed (Core not spawned)"
					return
				end
				if core.Parent ~= workspace:FindFirstChild("Enemies") then
					S.Status = "Going to Factory"
					tweenTo(CFrame.new(FACTORY_POS + Vector3.new(0, 30, 0)), keep)
					return
				end
				killMob(core, keep)
			end)
			if not ok then logError("AutoFactory", err) end
		elseif S.AutoEcto and alive() then
			local keep = function() return S.AutoEcto end
			local ok, err = pcall(function()
				-- اگه باس کشتی اسپاون شده، اول اون
				for _, bossName in ipairs(ECTO_BOSSES) do
					local boss = findMobAnywhere(bossName)
					if boss then
						if boss.Parent ~= workspace:FindFirstChild("Enemies") then
							S.Status = "Going to " .. bossName
							tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmDistance, 0), keep)
						else
							killMob(boss, keep)
						end
						return
					end
				end
				-- بهترین کوئست کشتی برای لولت (پول و XP بیشتر کنار Ectoplasm)
				local shipQuest
				local lv = dataValue("Level") or 1
				for _, q in ipairs(QuestList) do
					if table.find(ECTO_MOBS, q.mob) and q.level <= lv then shipQuest = q end
				end
				local useQuest = S.TakeQuest and shipQuest and not questBlocked(shipQuest)
				if useQuest and not hasQuest(shipQuest.mob) then
					takeQuest(shipQuest, keep)
					if not hasQuest(shipQuest.mob) then return end
				end
				-- اول ماب کوئست، بعد بقیه‌ی ماب‌های کشتی (نزدیک‌ترین)
				local best, bestDist
				local root = getRoot()
				local order = useQuest and { shipQuest.mob } or ECTO_MOBS
				for _, name in ipairs(order) do
					local m = findMob(name)
					if m then
						local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
						if not bestDist or d < bestDist then best, bestDist = m, d end
					end
				end
				if not best and useQuest then
					local sp = mobSpawn(shipQuest.mob)
					if sp then
						S.Status = "Going to " .. shipQuest.mob
						tweenTo(sp * CFrame.new(0, 30, 0), function() return S.AutoEcto and not findMob(shipQuest.mob) end)
						return
					end
				end
				if best then
					killMob(best, function() return S.AutoEcto and (not useQuest or hasQuest(shipQuest.mob)) end)
				else
					S.Status = "Going to Cursed Ship"
					tweenTo(CFrame.new(CURSED_SHIP_POS + Vector3.new(0, 40, 0)), function() return S.AutoEcto end)
				end
			end)
			if not ok then logError("AutoEcto", err) end
		end
	end
end)
end -- Factory / Ectoplasm

---------------------------------------------------------------------
-- Sea 2 items (Rengoku, Dragon Trident, Legendary Sword Dealer)
---------------------------------------------------------------------
local POS = {
	RengokuChest = Vector3.new(6571.2, 299.4, -6967.4),
	IceCastle = Vector3.new(6062.3, 155.3, -6880.9),
	ForgottenIsland = Vector3.new(-3194.2, 155.3, -10795.3),
	ElAdmin = Vector3.new(1321.0, 121.8, 33134.8),
	MysteriousMan = Vector3.new(-2573.5, 1620.7, -3745.2),
}

local function backpackTool(name)
	for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
		local t = cont and cont:FindFirstChild(name)
		if t and t:IsA("Tool") then return t end
	end
end

-- اینونتوری (با دو اسم دستور قدیمی/جدید)، 20 ثانیه کش
local inventoryCache, inventoryTime = {}, 0
local function inventoryNames()
	if tick() - inventoryTime < 20 then return inventoryCache end
	local set = {}
	for _, cmd in ipairs({ "getInventoryWeapons", "getInventory" }) do
		local r = invoke(cmd)
		if type(r) == "table" then
			for _, item in pairs(r) do
				-- مقدار = تعداد (برای متریال‌ها مثل Bones)، یا true
				if type(item) == "table" and item.Name then set[item.Name] = tonumber(item.Count) or true end
			end
		end
	end
	inventoryCache, inventoryTime = set, tick()
	return set
end

local function hasItem(name)
	return backpackTool(name) ~= nil or inventoryNames()[name] ~= nil
end

-- نزدیک‌ترین ماب از لیست؛ اگه نبود میره سمت fallbackPos
local function farmNearestOf(names, keep, fallbackPos)
	local root = getRoot()
	local best, bestDist
	for _, name in ipairs(names) do
		local m = findMob(name)
		if m then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if not bestDist or d < bestDist then best, bestDist = m, d end
		end
	end
	if best then
		killMob(best, keep)
	elseif fallbackPos then
		S.Status = "Looking for " .. table.concat(names, " / ")
		tweenTo(CFrame.new(fallbackPos + Vector3.new(0, 40, 0)), keep)
	end
end

-- باس رو اگه اسپاون شده می‌کشه؛ true یعنی باس پیدا شد
local function fightBoss(name, keep)
	local boss = findMobAnywhere(name)
	if not boss then return false end
	if boss.Parent ~= workspace:FindFirstChild("Enemies") then
		S.Status = "Going to " .. name
		tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmDistance, 0), keep)
	else
		killMob(boss, keep)
	end
	return true
end

local function touchPart(part)
	local root = getRoot()
	if not (root and part and firetouchinterest) then return false end
	pcall(function()
		firetouchinterest(root, part, 0)
		task.wait(0.1)
		firetouchinterest(root, part, 1)
	end)
	return true
end

task.spawn(function()
	while Hub.Running do
		task.wait(0.3)
		if S.AutoRengoku and alive() then
			local keep = function() return S.AutoRengoku end
			local ok, err = pcall(function()
				if hasItem("Rengoku") then
					S.AutoRengoku = false
					S.Status = "Rengoku obtained ✔"
					if notifyHook then notifyHook("Rengoku", "You already have Rengoku ✔", 6) end
					return
				end
				local key = backpackTool("Hidden Key")
				if key then
					-- کلید داریم: میریم سراغ صندوق Rengoku توی Ice Castle
					S.Status = "Opening Rengoku chest"
					local h = getHum()
					if h and key.Parent ~= getChar() then h:EquipTool(key) end
					tweenTo(CFrame.new(POS.RengokuChest), keep)
					local det
					pcall(function() det = workspace.Map.IceCastle.RengokuChest.Detection end)
					touchPart(det)
					task.wait(1.5)
					return
				end
				-- Awakened Ice Admiral شانس بیشتری داره (حدود 5%)
				if not fightBoss("Awakened Ice Admiral", keep) then
					farmNearestOf({ "Arctic Warrior", "Snow Lurker" }, keep, POS.IceCastle)
				end
			end)
			if not ok then logError("AutoRengoku", err) end
		elseif S.AutoTrident and alive() then
			local keep = function() return S.AutoTrident end
			local ok, err = pcall(function()
				if hasItem("Dragon Trident") then
					S.AutoTrident = false
					S.Status = "Dragon Trident obtained ✔"
					if notifyHook then notifyHook("Dragon Trident", "You have Dragon Trident ✔", 6) end
					return
				end
				local q = questForMob("Tide Keeper")
				if q and S.BossQuest and not questBlocked(q) and not hasQuest(q.mob) and findMobAnywhere("Tide Keeper") then
					takeQuest(q, keep)
					return
				end
				if not fightBoss("Tide Keeper", keep) then
					S.Status = "Tide Keeper not spawned, waiting at Forgotten Island"
					tweenTo(CFrame.new(POS.ForgottenIsland + Vector3.new(0, 60, 0)), keep)
					task.wait(2)
				end
			end)
			if not ok then logError("AutoTrident", err) end
		end
	end
end)

-- Legendary Sword Dealer هر چند ساعت یه جا اسپاون میشه
local function dealerPosition()
	for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
		local npc = folder and folder:FindFirstChild("Legendary Sword Dealer")
		if npc then
			local ok, cf = pcall(function() return npc:GetPivot() end)
			if ok and cf.Position.Y > -500 then return cf end
		end
	end
end

task.spawn(function()
	local wasSpawned = dealerPosition() ~= nil
	while Hub.Running do
		task.wait(5)
		local now = dealerPosition() ~= nil
		if now and not wasSpawned and S.DealerNotify and notifyHook then
			notifyHook("Legendary Sword Dealer", "He just spawned! Check the Items tab.", 8)
		end
		wasSpawned = now
	end
end)

---------------------------------------------------------------------
-- Raid و Darkbeard (Sea 2) — مختصات و قطعه‌ها از اسکن خود بازی
---------------------------------------------------------------------
do
	local SCIENTIST = Vector3.new(-6561.4, 309.3, -4749.1) -- Mysterious Scientist (خرید چیپ)
	local DARK_SUMMONER = Vector3.new(3778.7, 14.9, -3499.4) -- DarkbeardArena.Summoner.Detection

	-- وقتی توی Raid هستی، جزیره‌های Island 1..5 توی Locations ظاهر میشن
	local function raidIsland()
		local loc = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")
		if not loc then return nil end
		for i = 5, 1, -1 do
			local p = loc:FindFirstChild("Island " .. i)
			if p then return p, i end
		end
	end

	local function raidChip()
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.Name:find("Microchip") then return t end
				end
			end
		end
	end

	-- دکمه‌ی شروع Raid (RaidSummon2.Button.Main با ClickDetector)، نزدیک‌ترینش
	local function raidButton()
		local root = getRoot()
		local best, bestDist
		pcall(function()
			for _, m in ipairs(workspace.Map.CircleIsland:GetChildren()) do
				if m.Name == "RaidSummon2" then
					local b = m:FindFirstChild("Button") and m.Button:FindFirstChild("Main")
					if b and b:FindFirstChildOfClass("ClickDetector") then
						local d = (b.Position - root.Position).Magnitude
						if not bestDist or d < bestDist then best, bestDist = b, d end
					end
				end
			end
		end)
		return best
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.3)
			if S.AutoRaid and alive() then
				local keep = function() return S.AutoRaid end
				local ok, err = pcall(function()
					local island, idx = raidIsland()
					if island then
						-- توی Raid: نزدیک‌ترین دشمن رو بزن، اگه نبود برو جزیره‌ی بعدی
						local root = getRoot()
						local enemies = workspace:FindFirstChild("Enemies")
						local target, bestDist
						if enemies then
							for _, m in ipairs(enemies:GetChildren()) do
								if isAliveMob(m) then
									local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
									if d < 3000 and (not bestDist or d < bestDist) then target, bestDist = m, d end
								end
							end
						end
						if target then
							S.Status = ("Raid island %d: %s"):format(idx, mobBaseName(target.Name))
							killMob(target, keep)
						else
							S.Status = "Raid: going to island " .. idx
							tweenTo(island.CFrame * CFrame.new(0, 60, 0), keep)
						end
						return
					end
					local chip = raidChip()
					if chip then
						local btn = raidButton()
						if not btn then
							S.Status = "Going to raid lab"
							tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 20, 0)), keep)
							return
						end
						S.Status = "Starting raid"
						tweenTo(btn.CFrame * CFrame.new(0, 3, 0), keep)
						task.wait(0.3)
						if fireclickdetector then pcall(fireclickdetector, btn:FindFirstChildOfClass("ClickDetector")) end
						task.wait(5)
						return
					end
					if not S.AutoBuyChip then
						S.Status = "Raid: no Microchip (turn on Auto Buy Chip)"
						task.wait(2)
						return
					end
					if (dataValue("Level") or 0) < 1100 then
						S.Status = "Raid needs level 1100"
						task.wait(3)
						return
					end
					S.Status = "Buying " .. S.RaidType .. " chip"
					tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 3, 4)), keep)
					task.wait(0.3)
					local r = invoke("RaidsNpc", "Select", S.RaidType)
					task.wait(1.5)
					if not raidChip() then
						S.Status = "Chip not bought: " .. tostring(r)
						task.wait(10)
					end
				end)
				if not ok then logError("AutoRaid", err) end
			elseif S.AutoDarkbeard and alive() then
				local keep = function() return S.AutoDarkbeard end
				local ok, err = pcall(function()
					if fightBoss("Darkbeard", keep) then return end
					local fist = backpackTool("Fist of Darkness")
					if not fist then
						S.Status = "Darkbeard: need Fist of Darkness (drops from chests)"
						task.wait(3)
						return
					end
					-- با Fist of Darkness توی دست، Summoner رو لمس می‌کنیم
					S.Status = "Summoning Darkbeard"
					local h = getHum()
					if h and fist.Parent ~= getChar() then h:EquipTool(fist) end
					tweenTo(CFrame.new(DARK_SUMMONER + Vector3.new(0, 3, 0)), keep)
					local det
					pcall(function() det = workspace.Map.DarkbeardArena.Summoner.Detection end)
					touchPart(det)
					task.wait(4)
				end)
				if not ok then logError("AutoDarkbeard", err) end
			end
		end
	end)
end

do
-- خرید خودکار شمشیر افسانه‌ای: وقتی Dealer اسپاون شد میره پیشش و مثل دیالوگ خود بازی (1,2,3) می‌خره
local LEGENDARY_SWORDS = { "Shisui", "Saddi", "Wando" }
local LEGENDARY_PRICE = 2000000
task.spawn(function()
	while Hub.Running do
		task.wait(8)
		if S.AutoLegendary and alive() then
			local ok, err = pcall(function()
				inventoryTime = 0
				local missing = {}
				for _, sw in ipairs(LEGENDARY_SWORDS) do
					if not hasItem(sw) then table.insert(missing, sw) end
				end
				if #missing == 0 then
					S.AutoLegendary = false
					if notifyHook then notifyHook("Legendary Swords", "You own all 3 ✔ (Shisui, Saddi, Wando)", 6) end
					return
				end
				local cf = dealerPosition()
				if not cf then
					S.Status = "Waiting for Legendary Sword Dealer to spawn"
					return
				end
				if (dataValue("Beli") or 0) < LEGENDARY_PRICE then
					S.Status = "Dealer spawned but need $2,000,000"
					return
				end
				-- فارم موقتاً متوقف میشه تا سر حرکت دعوا نشه
				local wasFarming = S.AutoFarm
				S.AutoFarm = false
				stopTween()
				S.Status = "Going to Legendary Sword Dealer"
				tweenTo(cf * CFrame.new(0, 0, 4), function() return S.AutoLegendary end)
				task.wait(0.4)
				local beliBefore = dataValue("Beli") or 0
				for _, step in ipairs({ "1", "2", "3" }) do
					invoke("LegendarySwordDealer", step)
					task.wait(0.4)
				end
				task.wait(1)
				inventoryTime = 0
				local bought
				for _, sw in ipairs(missing) do
					if hasItem(sw) then bought = sw end
				end
				local spent = beliBefore - (dataValue("Beli") or 0)
				if notifyHook then
					notifyHook("Legendary Sword Dealer", bought and ("Bought " .. bought .. " ✔") or (spent > 0 and "Purchase made ✔" or "Nothing bought (already owned / sold out)"), 8)
				end
				S.AutoFarm = wasFarming
				task.wait(60)
			end)
			if not ok then logError("AutoLegendary", err) end
		end
	end
end)
end -- شمشیر افسانه‌ای

---------------------------------------------------------------------
-- Progression (حساب تازه از لول 0): تیم، باز کردن Seaها، Bartilo، Saber
-- دستورها همون دستورهای خود بازی هستن؛ منطق مرحله‌به‌مرحله نوشته شده
---------------------------------------------------------------------
do
	local function waitAt(pos, keep)
		tweenTo(CFrame.new(pos + Vector3.new(0, 30, 0)), keep)
	end

	-- باس رو می‌کشه یا کنار محل اسپاونش منتظر می‌مونه
	local function huntBoss(name, keep, spawnPos)
		if fightBoss(name, keep) then return true end
		S.Status = "Waiting for " .. name
		if spawnPos then waitAt(spawnPos, keep) end
		task.wait(1)
		return false
	end

	local function equipNamed(name)
		local t = backpackTool(name)
		local h = getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end

	local function stepSea2(keep)
		local r = invoke("TravelDressrosa")
		if type(r) ~= "string" or not r:find("Cannot") then
			S.Status = "Traveling to Sea 2..."
			task.wait(8)
			return
		end
		local data = invoke("DressrosaQuestProgress") or {}
		if not data.UsedKey then
			if not data.TalkedDetective then
				S.Status = "Sea 2: talking to Military Detective"
				invoke("DressrosaQuestProgress", "Detective")
			else
				S.Status = "Sea 2: using key"
				equipNamed("Key")
			end
			invoke("DressrosaQuestProgress", "UseKey")
			task.wait(1)
		elseif not data.KilledIceBoss then
			S.Status = "Sea 2: defeating Ice Admiral"
			huntBoss("Ice Admiral", keep, Vector3.new(1328, 43, -1346))
		else
			invoke("TravelDressrosa")
			task.wait(8)
		end
	end

	local BARTILO = Vector3.new(-461.5, 72.3, 300.3)
	local function stepBartilo(keep)
		local prog = invoke("BartiloQuestProgress") or {}
		if prog.DidPlates then
			S.AutoBartilo = false
			if notifyHook then notifyHook("Bartilo", "Bartilo quest complete ✔", 6) end
			return
		end
		if prog.KilledBandits == false then
			if not hasQuest("Swan Pirate") then
				S.Status = "Bartilo: taking quest"
				tweenTo(CFrame.new(BARTILO + Vector3.new(0, 3, 4)), keep)
				invoke("BartiloQuestProgress", "Bartilo")
				invoke("StartQuest", "BartiloQuest", 1)
				task.wait(1)
				return
			end
			local m = findMob("Swan Pirate")
			if m then
				S.Status = "Bartilo: farming Swan Pirates"
				killMob(m, function() return keep() and hasQuest("Swan Pirate") end)
			else
				waitAt(Vector3.new(932.6, 126.1, 1180.3), keep)
			end
			return
		end
		local stage = invoke("BartiloQuestProgress", "Bartilo")
		if stage == 1 then
			S.Status = "Bartilo: defeating Jeremy"
			huntBoss("Jeremy", keep, Vector3.new(2129, 449, 779))
		elseif stage == 2 then
			for i = 1, 8 do
				if not keep() then return end
				local plate
				pcall(function() plate = workspace.Map.Dressrosa.BartiloPlates["Plate" .. i] end)
				if plate then
					S.Status = ("Bartilo: plate %d/8"):format(i)
					tweenTo(CFrame.new(plate.Position + Vector3.new(0, 4, 0)), keep)
					touchPart(plate)
					task.wait(0.3)
				end
			end
		else
			task.wait(2)
		end
	end

	local function stepSea3(keep)
		local r = invoke("TravelZou")
		if type(r) ~= "string" or not r:find("Cannot") then
			S.Status = "Traveling to Sea 3..."
			task.wait(8)
			return
		end
		local unlock = invoke("GetUnlockables") or {}
		if not unlock.FlamingoAccess then
			-- این مرحله یه میوه‌ی 1M+ از اینونتوری مصرف می‌کنه؛ خودکار انجامش نمیدیم
			S.Status = "Sea 3: give Trevor a $1M+ fruit yourself first"
			task.wait(5)
			return
		end
		local check = invoke("ZQuestProgress", "Check")
		if check == 0 then
			S.Status = "Sea 3: rip_indra"
			invoke("ZQuestProgress", "Begin")
			huntBoss("rip_indra", keep)
		elseif check == 1 then
			invoke("TravelZou")
			task.wait(8)
		else
			S.Status = "Sea 3: defeating Don Swan"
			if huntBoss("Don Swan", keep, Vector3.new(2288, 15, 863)) then
				invoke("ZQuestProgress", "Begin")
			end
		end
	end

	local function stepSaber(keep)
		local data = invoke("ProQuestProgress") or {}
		if data.UsedRelic then
			if hasItem("Saber") then
				S.AutoSaber = false
				if notifyHook then notifyHook("Saber", "You have Saber ✔", 6) end
				return
			end
			S.Status = "Saber: fighting Saber Expert"
			local sp
			pcall(function() sp = ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder["Saber Expert"].Position end)
			huntBoss("Saber Expert", keep, sp)
			return
		end
		local plates
		pcall(function() plates = workspace.Map.Jungle.QuestPlates end)
		if not (plates and plates:FindFirstChild("Door")) then
			S.Status = "Saber: going to jungle puzzle"
			waitAt(Vector3.new(-1254.3, 18.4, 342.3), keep)
			return
		end
		if plates.Door.Transparency == 0 then
			S.Status = "Saber: pressing jungle plates"
			for _, v in ipairs(plates:GetChildren()) do
				if v:IsA("Model") and v.Name:find("Plate") and v:FindFirstChild("Button") then
					tweenTo(CFrame.new(v.Button.Position + Vector3.new(0, 4, 0)), keep)
					touchPart(v.Button)
				end
			end
			return
		end
		if not data.UsedTorch then
			S.Status = "Saber: torch"
			if backpackTool("Torch") then
				invoke("ProQuestProgress", "DestroyTorch")
			else
				invoke("ProQuestProgress", "GetTorch")
			end
		elseif not data.UsedCup then
			S.Status = "Saber: filling cup"
			invoke("ProQuestProgress", "GetCup")
			local cup = equipNamed("Cup")
			if cup then invoke("ProQuestProgress", "FillCup", cup) end
			invoke("ProQuestProgress", "SickMan")
		elseif not data.TalkedSon then
			S.Status = "Saber: talking to Rich Son"
			invoke("ProQuestProgress", "RichSon")
		elseif not data.KilledMob then
			S.Status = "Saber: defeating Mob Leader"
			huntBoss("Mob Leader", keep)
		else
			S.Status = "Saber: placing relic"
			invoke("ProQuestProgress", "RichSon")
			equipNamed("Relic")
			invoke("ProQuestProgress", "PlaceRelic")
		end
		task.wait(1)
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			-- انتخاب تیم وقتی هنوز تیم نداری
			if S.AutoTeam and not player.Team then pcall(invoke, "SetTeam", S.TeamChoice) end
			if alive() then
				local lv = dataValue("Level") or 0
				local step, flag
				if S.AutoSea2 and Sea == 1 and lv >= 700 then step, flag = stepSea2, "AutoSea2"
				elseif S.AutoBartilo and Sea == 2 and lv >= 850 then step, flag = stepBartilo, "AutoBartilo"
				elseif S.AutoSea3 and Sea == 2 and lv >= 1500 then step, flag = stepSea3, "AutoSea3"
				elseif S.AutoSaber and Sea == 1 and lv >= 200 then step, flag = stepSaber, "AutoSaber"
				end
				if step then
					local ok, err = pcall(step, function() return S[flag] end)
					if not ok then
						logError(flag, err)
						task.wait(2)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Sea 3: Elite Hunter، Yama، Bone، Cake Prince، Sea Beast + هاکی خودکار
-- (اسم‌ها و دستورها از کد بازی/Kaitun، منطق نوشته‌ی خودمون)
---------------------------------------------------------------------
local function materialCount(name)
	local v = inventoryNames()[name]
	if type(v) == "number" and v > 0 then return v end
	-- Bone توی لیست inventory نمیاد؛ خود Death King تعدادش رو میگه (کش 3 ثانیه)
	if name == "Bones" then
		local c = Hub.BoneCache
		if not c or tick() - c.t > 3 then
			c = { t = tick(), v = tonumber(invoke("Bones", "Check")) or 0 }
			Hub.BoneCache = c
		end
		return c.v
	end
	return 0
end

do
	local ELITES = { "Diablo", "Deandre", "Urban", "Tyrant of the Skies" }
	local BONE_MOBS = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
	local CAKE_MOBS = { "Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker" }
	local CAKE_BOSSES = { "Cake Prince", "Dough King" }
	local HAUNTED = Vector3.new(-9515, 164, 5786)
	local CAKE_ISLAND = Vector3.new(-2021, 37, -12028)

	local function findElite()
		for _, n in ipairs(ELITES) do
			if findMobAnywhere(n) then return n end
		end
	end

	-- نزدیک‌ترین ماب از لیست، با کوئست خودش (اگه Take Quest روشنه)
	local function farmList(list, keep, waitPos)
		local root = getRoot()
		-- اگه کوئست یکی از همین ماب‌ها رو داریم، فقط همون رو می‌زنیم که کوئست پیش بره
		local questMob = activeQuestMob()
		local inList = false
		for _, n in ipairs(list) do
			if n == questMob then inList = true end
		end
		local best, bestDist
		for _, n in ipairs(inList and { questMob } or list) do
			local m = findMob(n)
			if m then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bestDist or d < bestDist then best, bestDist = m, d end
			end
		end
		if not best then
			S.Status = "Waiting for " .. (inList and questMob or "mobs") .. " to spawn"
			-- فقط وقتی دوریم پرواز می‌کنیم؛ کنار جزیره همون‌جا صبر می‌کنیم
			if (root.Position - waitPos).Magnitude > 300 then
				tweenTo(CFrame.new(waitPos + Vector3.new(0, 40, 0)), keep)
			else
				task.wait(1)
			end
			return
		end
		local name = mobBaseName(best.Name)
		local q = questForMob(name)
		if S.TakeQuest and q and not inList and not questBlocked(q) and not hasQuest(name) then
			takeQuest(q, keep)
			return
		end
		S.Status = "Farming " .. name .. (inList and " (quest)" or "")
		killMob(best, keep)
	end

	local function stepElite(keep)
		local elite = findElite()
		if not elite then
			S.Status = "Elite Hunter: no elite spawned (progress " .. tostring(invokeCached("eliteProg", 20, "EliteHunter", "Progress") or "?") .. ")"
			task.wait(3)
			return
		end
		-- متن کوئست Elite ممکنه اسم باس رو نداشته باشه؛ پس هر کوئست فعالِ تموم‌نشده رو کوئست Elite حساب می‌کنیم
		local title = questTitle() or ""
		local active = title ~= "" and not questDone(title)
		if not active then
			S.Status = "Elite Hunter: taking quest"
			invoke("EliteHunter")
			task.wait(1.5)
			return
		end
		-- اگه کوئست اسم یه Elite دیگه رو داره، همون رو بزن
		for _, n in ipairs(ELITES) do
			if title:lower():find(n:lower(), 1, true) then elite = n end
		end
		S.Status = "Elite Hunter: hunting " .. elite
		if not fightBoss(elite, keep) then task.wait(1) end
	end

	local function stepYama(keep)
		if hasItem("Yama") then
			S.AutoYama = false
			if notifyHook then notifyHook("Yama", "You have Yama ✔", 6) end
			return
		end
		local prog = tonumber(invoke("EliteHunter", "Progress")) or 0
		if prog < 30 then
			S.Status = ("Yama: elites %d/30 (turn on Auto Elite)"):format(prog)
			task.wait(5)
			return
		end
		local hit
		pcall(function() hit = workspace.Map.Waterfall.SealedKatana.Hitbox end)
		if not hit then
			S.Status = "Yama: going to waterfall"
			tweenTo(CFrame.new(5241, 23, 1055), keep)
			return
		end
		S.Status = "Yama: pulling the sword"
		tweenTo(hit.CFrame * CFrame.new(0, 3, 0), keep)
		local cd = hit:FindFirstChildOfClass("ClickDetector")
		if cd and fireclickdetector then pcall(fireclickdetector, cd) end
		task.wait(0.5)
	end

	-- Auto Bone: فقط کوئست مومیایی (Posessed Mummy). متن کوئست رو با «mumm» چک می‌کنیم
	-- چون اسم ماب Posessed ولی ممکنه توی متن Possessed/Mummies باشه
	local function mummyQuestActive()
		local title = questTitle()
		if not title then return hasQuest("Posessed Mummy") end
		return not questDone(title) and title:lower():find("mumm", 1, true) ~= nil
	end

	local function stepBone(keep)
		-- Soul Reaper اسپاون شد → اول اون
		if findMobAnywhere("Soul Reaper") then
			S.Status = "Bone: fighting Soul Reaper"
			fightBoss("Soul Reaper", keep)
			return
		end
		-- قمار Bone دقیقاً مثل دیالوگ Death King (از کد خود بازی):
		-- Check → (تعداد Bone، لیست آیتم‌ها، تعداد ترید باقی‌مونده، دقیقه تا ریست، سقف)
		-- Buy, 1, شماره‌ی آیتم → 1 = انجام شد، 2 = Bone کافی نیست، 3 = این آیتم رو داری
		if S.AutoBoneGamble and tick() > (Hub.BoneGambleWait or 0) then
			local ok, bones, shop, left, minutes = pcall(CommF.InvokeServer, CommF, "Bones", "Check")
			bones, left = tonumber(bones) or 0, tonumber(left) or 0
			if Hub.LiveLog then Hub.LiveLog(("Bone gamble check: ok=%s bones=%s tradesLeft=%s resetMin=%s"):format(tostring(ok), tostring(bones), tostring(left), tostring(minutes))) end
			local idx, cost = 1, 50
			pcall(function()
				for k, item in pairs(shop[1]) do
					if tonumber(item[2]) == 50 then idx, cost = k, 50 end
				end
			end)
			if not ok then
				Hub.BoneGambleWait = tick() + 60
			elseif left <= 0 then
				Hub.BoneGambleWait = tick() + math.max(1, tonumber(minutes) or 5) * 60
				S.Status = ("Bone gamble: 0 trades left, reset in %s min"):format(tostring(minutes))
			elseif bones >= cost then
				local dk
				for _, f in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
					for _, n in ipairs(f and f:GetChildren() or {}) do
						if not dk and (n.Name:find("Death King") or n.Name:find("Halloween")) then pcall(function() dk = n:GetPivot() end) end
					end
				end
				S.Status = ("Bone gamble: trading (%d bones, %d trades left)"):format(bones, left)
				if dk then
					tweenTo(dk * CFrame.new(0, 0, -4), keep)
					task.wait(0.4)
				end
				local r = invoke("Bones", "Buy", 1, idx)
				Hub.BoneCache = nil
				if r == 1 then
					if notifyHook then notifyHook("Bone Gamble", "Trade completed ✔ (" .. (left - 1) .. " left)", 4) end
				else
					Hub.BoneGambleWait = tick() + 120
					logError("BoneGamble", ("result %s (1=ok 2=no bones 3=have item) item #%d dk=%s"):format(tostring(r), idx, tostring(dk ~= nil)))
				end
				task.wait(0.5)
				return
			end
			if ok and left > 0 and bones < cost then Hub.BoneGambleWait = tick() + 30 end
		end
		-- اگه موقع اجرای اسکریپت دور بودیم، این کوئست توی لیست نیست؛ خودمون می‌سازیمش
		local q = questForMob("Posessed Mummy")
			or { quest = "HauntedQuest2", index = 2, level = 2050, mob = "Posessed Mummy", npc = CFrame.new(-9516.99, 172.02, 6078.47) }
		if mummyQuestActive() then
			Hub.MummyGoneAt = nil
		elseif S.TakeQuest and q and not questBlocked(q) then
			-- کوئست تازه تموم شده؛ سرور یه لحظه طول می‌کشه تا کوئست بعدی رو قبول کنه
			Hub.MummyGoneAt = Hub.MummyGoneAt or tick()
			if tick() - Hub.MummyGoneAt >= 1.5 then
				takeQuest(q, keep)
				if mummyQuestActive() then Hub.MummyGoneAt = nil end
				return
			end
		end
		local target = findMob("Posessed Mummy")
		-- وقتی مومیایی نیست، بقیه‌ی ماب‌های Bone رو می‌زنیم (بدون کوئست، فقط برای Bone)
		if not target then
			local root = getRoot()
			local bestDist
			for _, n in ipairs(BONE_MOBS) do
				local m = findMob(n)
				if m then
					local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
					if not bestDist or d < bestDist then target, bestDist = m, d end
				end
			end
		end
		if not target then
			S.Status = "Bone: waiting for mobs"
			if (getRoot().Position - HAUNTED).Magnitude > 300 then
				tweenTo(CFrame.new(HAUNTED + Vector3.new(0, 40, 0)), keep)
			else
				task.wait(1)
			end
			return
		end
		S.Status = "Bone: " .. mobBaseName(target.Name) .. (mummyQuestActive() and " (mummy quest)" or "")
		killMob(target, keep)
	end

	local function stepCake(keep)
		for _, b in ipairs(CAKE_BOSSES) do
			if findMobAnywhere(b) then
				S.Status = "Fighting " .. b
				fightBoss(b, keep)
				return
			end
		end
		farmList(CAKE_MOBS, keep, CAKE_ISLAND)
	end

	-- Sea Beast: بالای سرش می‌مونه و اسکیل‌ها رو می‌زنه
	local function stepSeaBeast(keep)
		local folder = workspace:FindFirstChild("SeaBeasts")
		local root = getRoot()
		local best, bestDist
		if folder then
			for _, b in ipairs(folder:GetChildren()) do
				local hrp = b:FindFirstChild("HumanoidRootPart") or b.PrimaryPart
				if hrp then
					local d = (hrp.Position - root.Position).Magnitude
					if not bestDist or d < bestDist then best, bestDist = hrp, d end
				end
			end
		end
		if not best then
			S.Status = "No Sea Beast spawned"
			task.wait(3)
			return
		end
		S.Status = "Fighting Sea Beast"
		local target = CFrame.new(best.Position + Vector3.new(0, 60, 0))
		if (root.Position - target.Position).Magnitude > 80 then
			tweenTo(target, keep)
		else
			setFloat(true)
			root.CFrame = CFrame.lookAt(target.Position, best.Position)
		end
		equipWeapon(S.SeaBeastWeapon)
		local saved = S.UseSkills
		S.UseSkills = true
		useSkills()
		S.UseSkills = saved
		task.wait(0.2)
	end

	-- باس‌های خاص: برای هر کدوم یه تیک «بکش» و (اگه احضار داره) یه تیک «احضار» جدا
	local function equipItem(name)
		local t = backpackTool(name)
		local h = getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end
	local SPECIAL = {
		{ id = "SoulReaper", label = "Soul Reaper", names = { "Soul Reaper" }, sea = 3, cost = "Hallow Essence",
			ready = function() return backpackTool("Hallow Essence") ~= nil end,
			summon = function(keep)
				equipItem("Hallow Essence")
				local det
				pcall(function() det = workspace.Map["Haunted Castle"].Summoner.Detection end)
				if not det then
					tweenTo(CFrame.new(HAUNTED + Vector3.new(0, 40, 0)), keep)
					return
				end
				tweenTo(CFrame.new(det.Position + Vector3.new(0, 3, 0)), keep)
				touchPart(det)
				task.wait(3)
			end },
		{ id = "CakePrince", label = "Cake Prince", names = { "Cake Prince" }, sea = 3,
			ready = function() return true end,
			summon = function(keep) farmList(CAKE_MOBS, keep, CAKE_ISLAND) end },
		{ id = "DoughKing", label = "Dough King", names = { "Dough King" }, sea = 3, cost = "Sweet Chalice",
			ready = function() return backpackTool("Sweet Chalice") ~= nil or hasItem("Sweet Chalice") end,
			summon = function(keep) farmList(CAKE_MOBS, keep, CAKE_ISLAND) end },
		{ id = "Indra", label = "rip_indra", names = { "rip_indra True Form", "rip_indra" }, sea = 3 },
		{ id = "CursedCaptain", label = "Cursed Captain", names = { "Cursed Captain" }, sea = 2 },
		{ id = "Order", label = "Order", names = { "Order" }, sea = 2 },
	}
	Hub.Special = SPECIAL
	Hub.SpecialAny = function()
		for _, b in ipairs(SPECIAL) do
			if S["Kill" .. b.id] or S["Summon" .. b.id] then return true end
		end
		return false
	end
	local function spawnedName(b)
		for _, n in ipairs(b.names) do
			if findMobAnywhere(n) then return n end
		end
	end
	Hub.SpecialSpawned = spawnedName
	-- کاری که الان باید بکنیم (اگه هست): اول کشتن باس اسپاون‌شده، بعد احضار
	local function specialAction()
		for _, b in ipairs(SPECIAL) do
			if b.sea == Sea and (S["Kill" .. b.id] or S["Summon" .. b.id]) then
				local n = spawnedName(b)
				if n then
					return function(keep)
						S.Status = "Special boss: fighting " .. n
						fightBoss(n, keep)
					end, S["Kill" .. b.id] and "Kill" .. b.id or "Summon" .. b.id
				end
			end
		end
		for _, b in ipairs(SPECIAL) do
			if b.sea == Sea and S["Summon" .. b.id] and b.summon and b.ready() then
				return function(keep)
					S.Status = "Special boss: summoning " .. b.label
					b.summon(keep)
				end, "Summon" .. b.id
			end
		end
	end

	-- فارم متریال: ماب‌هایی که هر متریال رو دراپ می‌کنن (دراپ‌ها سمت سرورن، لیست از اطلاعات Blox Fruits)
	local MATERIALS = {
		[1] = {
			{ "Leather", { "Brute", "Pirate" } },
			{ "Scrap Metal", { "Brute" } },
			{ "Angel Wings", { "Royal Soldier", "Royal Squad" } },
			{ "Magma Ore", { "Military Soldier", "Military Spy" } },
			{ "Fish Tail", { "Fishman Warrior", "Fishman Commando" } },
		},
		[2] = {
			{ "Leather", { "Marine Captain" } },
			{ "Scrap Metal", { "Swan Pirate", "Factory Staff" } },
			{ "Radioactive Material", { "Factory Staff" } },
			{ "Magma Ore", { "Lava Pirate", "Magma Ninja" } },
			{ "Mystic Droplet", { "Water Fighter", "Sea Soldier" } },
			{ "Vampire Fang", { "Vampire" } },
			{ "Ectoplasm", { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" } },
		},
		[3] = {
			{ "Leather", { "Jungle Pirate" } },
			{ "Scrap Metal", { "Jungle Pirate" } },
			{ "Fish Tail", { "Fishman Raider", "Fishman Captain" } },
			{ "Dragon Scale", { "Dragon Crew Warrior", "Dragon Crew Archer" } },
			{ "Conjured Cocoa", { "Chocolate Bar Battler", "Cocoa Warrior" } },
			{ "Gunpowder", { "Pistol Billionaire" } },
			{ "Mini Tusk", { "Mythological Pirate" } },
			{ "Demonic Wisp", { "Demonic Soul" } },
			{ "Bones", { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" } },
		},
	}
	Hub.Materials = MATERIALS[Sea] or {}
	local function stepMaterial(keep)
		local entry
		for _, m in ipairs(Hub.Materials) do
			if S.Material and S.Material:sub(1, #m[1] + 1) == m[1] .. " " then entry = m end
		end
		if not entry then
			S.Status = "Material: pick one in the Farm tab"
			task.wait(2)
			return
		end
		-- اگه ماب لود نیست، میریم محل اسپاون یا NPC کوئستش
		local spot
		for _, n in ipairs(entry[2]) do
			local q = questForMob(n)
			spot = spot or spawnCentroid(n) or (q and q.npc and q.npc.Position)
		end
		if not spot then
			S.Status = "Material: can't find " .. table.concat(entry[2], " / ") .. " in this sea"
			task.wait(3)
			return
		end
		farmList(entry[2], keep, spot)
	end

	-- Pirate Raid: دزدهای دریایی که به Castle on the Sea حمله می‌کنن
	local CASTLE = Vector3.new(-5100, 315, -3000)
	local function stepPirateRaid(keep)
		local enemies = workspace:FindFirstChild("Enemies")
		local root = getRoot()
		local best, bestDist
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - CASTLE).Magnitude < 900 then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bestDist or d < bestDist then best, bestDist = m, d end
			end
		end
		if not best then
			S.Status = "Pirate Raid: waiting at Castle on the Sea"
			tweenTo(CFrame.new(CASTLE + Vector3.new(0, 60, 0)), keep)
			task.wait(2)
			return
		end
		S.Status = "Pirate Raid: fighting " .. mobBaseName(best.Name)
		killMob(best, keep)
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.3)
			if alive() then
				local step, flag
				local sStep, sFlag = specialAction()
				if sStep then step, flag = sStep, sFlag
				elseif S.AutoSeaBeast then step, flag = stepSeaBeast, "AutoSeaBeast"
				elseif S.AutoMaterial then step, flag = stepMaterial, "AutoMaterial"
				elseif S.AutoPirateRaid and Sea == 3 then step, flag = stepPirateRaid, "AutoPirateRaid"
				elseif S.AutoElite and Sea == 3 then step, flag = stepElite, "AutoElite"
				elseif S.AutoYama and Sea == 3 then step, flag = stepYama, "AutoYama"
				elseif S.AutoBone and Sea == 3 then step, flag = stepBone, "AutoBone"
				elseif S.AutoCake and Sea == 3 then step, flag = stepCake, "AutoCake"
				end
				if step then
					local ok, err = pcall(step, function() return S[flag] end)
					if not ok then
						logError(flag, err)
						task.wait(2)
					end
				end
			end
		end
	end)

	-- قمار Bone (50 Bone هر بار) و خرید خودکار هاکی‌های پایه وقتی پولش هست
	task.spawn(function()
		while Hub.Running do
			task.wait(5)
			-- وقتی Auto Bone روشنه خودش میره پیش Death King؛ اینجا فقط وقتی خاموشه (بدون حرکت)
			if S.AutoBoneGamble and Sea == 3 and not S.AutoBone and tick() > (Hub.BoneGambleWait or 0) then
				inventoryTime = 0
				local before = materialCount("Bones")
				if before >= 50 then
					local r = invoke("Bones", "Buy", 1, 1)
					Hub.BoneCache = nil
					-- 1 یعنی ترید انجام شد
					if r ~= 1 then Hub.BoneGambleWait = tick() + 300 end
				end
			end
			if S.AutoAbilities and alive() then
				local char = getChar()
				local beli = dataValue("Beli") or 0
				for _, a in ipairs({ { "Buso", 25000 }, { "Geppo", 10000 }, { "Soru", 100000 } }) do
					if beli >= a[2] and not CollectionService:HasTag(char, a[1]) then
						invoke("BuyHaki", a[1])
						task.wait(0.5)
					end
				end
			end
			-- بیدار کردن اسکیل میوه با Fragment (همون دستوری که NPC خود بازی می‌فرسته)
			if S.AutoAwaken and alive() and (dataValue("Fragments") or 0) > 0 and tick() - (Hub.AwakenAt or 0) > 60 then
				Hub.AwakenAt = tick()
				local check = invoke("Awakener", "Check")
				if check and check ~= 0 then
					local r = invoke("Awakener", "Awaken")
					if r and notifyHook then notifyHook("Auto Awaken", "Result: " .. tostring(type(r) == "table" and (r.Key or r.Name) or r), 6) end
				end
			end
			-- رنگ هاکی از Master of Auras (فقط وقتی اسپاون شده و پول بیشتر از حداقل هست)
			if S.AutoHakiColor and alive() and (dataValue("Beli") or 0) > S.FruitMinBeli then
				if invoke("ColorsDealer", "1") then
					local r = invoke("ColorsDealer", "2")
					-- هر بار روشن کردن = فقط یه خرید، که پول یه‌جا خرج نشه
					S.AutoHakiColor = false
					if notifyHook then notifyHook("Haki Color", "Result: " .. tostring(r) .. " (toggle turned off)", 8) end
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- کوئست‌های بلند: Tushita، CDK، Race V2/V3، Soul Guitar، فایتینگ استایل‌ها
-- دستورها از کد بازی/Kaitun؛ همه‌ی جابجایی‌ها با پرواز امن (بدون پرش مستقیم)
---------------------------------------------------------------------
do
	local function go(pos, keep)
		tweenTo(typeof(pos) == "CFrame" and pos or CFrame.new(pos + Vector3.new(0, 3, 0)), keep)
	end
	local function has(name) return backpackTool(name) ~= nil end
	local function equip(name)
		local t, h = backpackTool(name), getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end
	local function aliveNamed(pattern)
		for _, f in ipairs({ workspace:FindFirstChild("Enemies"), ReplicatedStorage }) do
			if f then
				for _, m in ipairs(f:GetChildren()) do
					if m:IsA("Model") and m.Name:find(pattern) and isAliveMob(m) then return m end
				end
			end
		end
	end
	local function killNearby(radius, keep)
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not (root and enemies) then return false end
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= radius then
				killMob(m, keep)
				return true
			end
		end
		return false
	end

	-- Tushita (Sea 3، لول 2200): Longma → مشعل مقدس → 5 مشعل
	local function stepTushita(keep)
		if hasItem("Tushita") then
			S.AutoTushita = false
			if notifyHook then notifyHook("Tushita", "You have Tushita ✔", 6) end
			return
		end
		local turtle = workspace.Map:FindFirstChild("Turtle")
		if turtle and not turtle:FindFirstChild("TushitaGate") then
			S.Status = "Tushita: defeating Longma"
			if not fightBoss("Longma", keep) then task.wait(2) end
			return
		end
		if not aliveNamed("indra") then
			S.Status = "Tushita: needs rip_indra spawned in server"
			task.wait(3)
			return
		end
		if not has("Holy Torch") then
			S.Status = "Tushita: getting Holy Torch"
			local door
			pcall(function() door = workspace.Map.Waterfall.SecretRoom.Room.Door.Door.Hitbox end)
			if door then
				go(door.CFrame, keep)
				touchPart(door)
			end
			task.wait(1)
			return
		end
		for i = 1, 5 do
			if not keep() then return end
			local torch
			pcall(function() torch = workspace.Map.Turtle.QuestTorches["Torch" .. i] end)
			if torch then
				S.Status = ("Tushita: torch %d/5"):format(i)
				equip("Holy Torch")
				local part = torch:IsA("BasePart") and torch or torch:FindFirstChildWhichIsA("BasePart", true)
				if part then
					go(part.Position, keep)
					touchPart(part)
					task.wait(0.5)
				end
			end
		end
	end

	-- CDK (Sea 3): Trial های Evil و Good
	local function stepCDK(keep)
		if hasItem("Cursed Dual Katana") then
			S.AutoCDK = false
			if notifyHook then notifyHook("CDK", "You have Cursed Dual Katana ✔", 6) end
			return
		end
		if invoke("CDKQuest", "OpenDoor") == "can" then invoke("CDKQuest", "OpenDoor", true) end
		local q = invoke("CDKQuest", "Progress")
		if type(q) ~= "table" then
			S.Status = "CDK: needs Yama + Tushita (350 mastery each)"
			task.wait(5)
			return
		end
		local evil, good = q.Evil, q.Good
		if evil == 0 or evil == -3 then
			S.Status = "CDK Evil 1: Mythological Pirate"
			invoke("CDKQuest", "StartTrial", "Evil")
			local m = aliveNamed("Mythological Pirate")
			if m and m.Parent == workspace.Enemies then
				go(m.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0), keep)
				task.wait(1)
			else
				go(Vector3.new(-13239, 520, -6813), keep)
			end
		elseif evil == 1 or evil == -4 then
			S.Status = "CDK Evil 2: haze mobs"
			invoke("CDKQuest", "StartTrial", "Evil")
			local haze = player:FindFirstChild("QuestHaze")
			if haze then
				for _, v in ipairs(haze:GetChildren()) do
					if v:IsA("ValueBase") and tonumber(v.Value) and v.Value > 0 then
						local m = findMob(v.Name)
						if m then
							killMob(m, keep)
						else
							local sp
							pcall(function() sp = ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder[v.Name].Position end)
							if sp then go(sp + Vector3.new(0, 30, 0), keep) end
						end
						return
					end
				end
			end
			task.wait(1)
		elseif evil == 2 or evil == -5 then
			S.Status = "CDK Evil 3: Soul Reaper / Hell Dimension"
			invoke("CDKQuest", "StartTrial", "Evil")
			local hell = workspace.Map:FindFirstChild("HellDimension")
			if hell then
				if killNearby(300, keep) then return end
				for i = 1, 3 do
					local t = hell:FindFirstChild("Torch" .. i)
					local pp = t and t:FindFirstChildOfClass("ProximityPrompt")
					if pp and pp.Enabled then
						go(t.Position, keep)
						if fireproximityprompt then pcall(fireproximityprompt, pp) end
						return
					end
				end
			elseif aliveNamed("Soul Reaper") then
				local m = aliveNamed("Soul Reaper")
				go(m:GetPivot(), keep)
			elseif has("Hallow Essence") then
				equip("Hallow Essence")
				local det
				pcall(function() det = workspace.Map["Haunted Castle"].Summoner.Detection end)
				if det then
					go(det.Position, keep)
					touchPart(det)
				end
			else
				S.Status = "CDK Evil 3: farming bones for Hallow Essence"
				local m
				for _, n in ipairs({ "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }) do
					m = m or findMob(n)
				end
				if m then killMob(m, keep) else go(Vector3.new(-9515, 194, 5786), keep) end
			end
		elseif good == 0 or good == -3 then
			S.Status = "CDK Good 1: finding boats"
			invoke("CDKQuest", "StartTrial", "Good")
			for _, pos in ipairs({ Vector3.new(-9550, 21, 4690), Vector3.new(-6120, 16, -2250), Vector3.new(-9530, 7, -8370) }) do
				if not keep() then return end
				go(pos, keep)
				task.wait(1)
				local npcs = workspace:FindFirstChild("NPCs")
				if npcs then
					for _, n in ipairs(npcs:GetChildren()) do
						if n.Name:find("Boat") then invoke("CDKQuest", "BoatQuest", n) end
					end
				end
			end
		elseif good == 1 or good == -4 then
			S.Status = "CDK Good 2: reaching objective"
			invoke("CDKQuest", "StartTrial", "Good")
			go(Vector3.new(6148.4, 294.4, -6741.1), keep)
			task.wait(2)
		elseif good == 2 or good == -5 then
			S.Status = "CDK Good 3: Heavenly Dimension"
			invoke("CDKQuest", "StartTrial", "Good")
			local heaven = workspace.Map:FindFirstChild("HeavenlyDimension")
			if heaven then
				if killNearby(300, keep) then return end
				for i = 1, 3 do
					local t = heaven:FindFirstChild("Torch" .. i)
					local pp = t and t:FindFirstChildOfClass("ProximityPrompt")
					if pp and pp.Enabled then
						go(t.Position, keep)
						if fireproximityprompt then pcall(fireproximityprompt, pp) end
						return
					end
				end
				local exit = heaven:FindFirstChild("Exit")
				if exit then
					go(exit.Position, keep)
					touchPart(exit)
				end
			else
				S.Status = "CDK Good 3: waiting for Cake Queen"
				if not fightBoss("Cake Queen", keep) then task.wait(3) end
			end
		else
			S.Status = "CDK: final step, talk to the CDK door"
			task.wait(5)
		end
	end

	-- Race V2 (Sea 2): Alchemist + 3 گل
	local function stepRaceV2(keep)
		local race = player:FindFirstChild("Data") and player.Data:FindFirstChild("Race")
		if race and race:FindFirstChild("Evolved") then
			S.AutoRaceV2 = false
			if notifyHook then notifyHook("Race V2", "Race evolved to V2 ✔", 6) end
			return
		end
		local check = invoke("Alchemist", "1")
		if check == 0 then
			S.Status = "Race V2: talking to Alchemist"
			invoke("Alchemist", "2")
		elseif check == 1 then
			for i = 1, 2 do
				if not has("Flower " .. i) then
					local f = workspace:FindFirstChild("Flower" .. i)
					S.Status = "Race V2: flower " .. i
					if f then
						go(f.Position, keep)
						touchPart(f)
					end
					return
				end
			end
			if not has("Flower 3") then
				S.Status = "Race V2: flower 3 (Zombies)"
				local z = findMob("Zombie")
				if z then killMob(z, function() return keep() and not has("Flower 3") end) else go(Vector3.new(-5685, 78, -853), keep) end
			end
		elseif check == 2 then
			S.Status = "Race V2: submitting flowers"
			invoke("Alchemist", "3")
		end
		task.wait(1)
	end

	-- Race V3 (Sea 2): Wenlocktoad
	local humanStage = 0
	local function stepRaceV3(keep)
		local check = invoke("Wenlocktoad", "1")
		if check == 0 then
			S.Status = "Race V3: starting quest"
			invoke("Wenlocktoad", "2")
			task.wait(1)
			return
		elseif check ~= 1 then
			S.Status = "Race V3: done or not available (" .. tostring(check) .. ")"
			S.AutoRaceV3 = false
			return
		end
		local race = dataValue("Race")
		if race == "Human" then
			local bosses = { { "Jeremy", Vector3.new(2333, 449, 700) }, { "Diamond", Vector3.new(-1714, 199, -104) }, { "Orbitus", Vector3.new(-2149, 73, -4304) } }
			local b = bosses[humanStage + 1]
			if b then
				S.Status = "Race V3: defeating " .. b[1]
				if fightBoss(b[1], keep) then
					if not findMobAnywhere(b[1]) then humanStage += 1 end
				else
					go(b[2] + Vector3.new(0, 30, 0), keep)
				end
			else
				invoke("Wenlocktoad", "3")
			end
		elseif race == "Rabbit" then
			S.Status = "Race V3: collecting chests (keep Auto Chest on)"
			S.AutoChest = true
			invoke("Wenlocktoad", "3")
			task.wait(10)
		elseif race == "Fishman" then
			S.Status = "Race V3: kill a Sea Beast (Sea Events tab)"
			invoke("Wenlocktoad", "3")
			task.wait(10)
		else
			S.Status = "Race V3: " .. tostring(race) .. " trial must be done manually"
			task.wait(10)
		end
	end

	-- Soul Guitar (Sea 3): مراسم ماه کامل + پازل‌ها + ساخت
	local function stepSoulGuitar(keep)
		if hasItem("Skull Guitar") then
			S.AutoSoulGuitar = false
			if notifyHook then notifyHook("Soul Guitar", "You have Skull Guitar ✔", 6) end
			return
		end
		local check = invoke("GuitarPuzzleProgress", "Check")
		if not check then
			local full = false
			pcall(function()
				full = Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431" and (Lighting.ClockTime > 16 or Lighting.ClockTime < 5)
			end)
			if full then
				S.Status = "Soul Guitar: gravestone ritual"
				go(Vector3.new(-8654, 140, 6167), keep)
				invoke("gravestoneEvent", 2)
				invoke("gravestoneEvent", 2, true)
			else
				S.Status = "Soul Guitar: waiting for full moon night"
			end
			task.wait(3)
		elseif check.Swamp == false then
			S.Status = "Soul Guitar: clearing swamp zombies"
			local z = findMob("Living Zombie")
			if z then killMob(z, keep) else go(Vector3.new(-10170, 168, 5939), keep) end
		elseif check.Gravestones == false then
			invoke("GuitarPuzzleProgress", "Gravestones")
		elseif check.Ghost == false then
			invoke("GuitarPuzzleProgress", "Ghost")
		elseif check.Trophies == false then
			invoke("GuitarPuzzleProgress", "Trophies")
		elseif check.Pipes == false then
			invoke("GuitarPuzzleProgress", "Pipes")
		else
			local frag = dataValue("Fragments") or 0
			if frag >= 5000 and materialCount("Bones") >= 500 and materialCount("Ectoplasm") >= 250 then
				S.Status = "Soul Guitar: crafting"
				invoke("soulGuitarBuy")
			else
				S.Status = ("Soul Guitar: need 5000 frag (%d), 500 bones (%d), 250 ecto (%d)"):format(frag, materialCount("Bones"), materialCount("Ectoplasm"))
				task.wait(10)
			end
		end
		task.wait(1)
	end

	-- فایتینگ استایل‌ها به ترتیب؛ مکان معلم هر Sea از Kaitun
	local STYLE_CHAIN = {
		{ "Black Leg", "BuyBlackLeg", { Vector3.new(-985, 14, 3988), Vector3.new(-4754, 35, -4849), Vector3.new(-5045, 372, -3178) } },
		{ "Electro", "BuyElectro", { Vector3.new(-5384, 14, -2149), Vector3.new(-4864, 35, -4765), Vector3.new(-4994, 315, -3201) } },
		{ "Fishman Karate", "BuyFishmanKarate", { Vector3.new(61585, 19, 987), Vector3.new(-4957, 35, -4668), Vector3.new(-5022, 372, -3187) } },
		{ "Dragon Claw", "DragonClaw", { nil, Vector3.new(702, 187, 653), Vector3.new(-4980, 372, -3205) } },
		{ "Superhuman", "BuySuperhuman", { nil, Vector3.new(1379, 247, -5190), Vector3.new(-5004, 372, -3194) } },
		{ "Death Step", "BuyDeathStep", { nil, Vector3.new(6356, 296, -6763), Vector3.new(-4997, 315, -3220) } },
		{ "Sharkman Karate", "BuySharkmanKarate", { nil, Vector3.new(-2602, 239, -10317), Vector3.new(-4974, 315, -3221) } },
		{ "Electric Claw", "BuyElectricClaw", { nil, nil, Vector3.new(-10371, 331, -10131) } },
		{ "Dragon Talon", "BuyDragonTalon", { nil, nil, Vector3.new(5661, 1210, 863) } },
		{ "Godhuman", "BuyGodhuman", { nil, nil, nil } },
	}
	local styleTried = {}
	-- فقط استایل «بعدی» نسبت به استایل فعلی؛ هیچ‌وقت به استایل ضعیف‌تر برنمی‌گرده
	local function currentStyleIndex()
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.ToolTip == "Melee" then
						for i, st in ipairs(STYLE_CHAIN) do
							if st[1] == t.Name then return i end
						end
					end
				end
			end
		end
		return 0
	end
	local function stepStyles(keep)
		local nextIdx = currentStyleIndex() + 1
		local st = STYLE_CHAIN[nextIdx]
		if not st then
			S.AutoStyles = false
			if notifyHook then notifyHook("Fighting Styles", "You already have the best style ✔", 6) end
			return
		end
		for _, st in ipairs({ st }) do
			local name, cmd, spots = st[1], st[2], st[3]
			if (styleTried[name] or 0) < tick() then
				styleTried[name] = tick() + 300
				local pos = spots[Sea]
				if pos then
					S.Status = "Styles: going to " .. name .. " teacher"
					go(pos, keep)
					task.wait(0.4)
				end
				local r
				if cmd == "DragonClaw" then
					invoke("BlackbeardReward", "DragonClaw", "1")
					r = invoke("BlackbeardReward", "DragonClaw", "2")
				else
					invoke(cmd, true)
					r = invoke(cmd)
				end
				S.Status = "Styles: " .. name .. " -> " .. tostring(r)
				if notifyHook then notifyHook("Fighting Style", name .. ": " .. tostring(r), 5) end
				return
			end
		end
		S.Status = "Styles: nothing to buy right now (retry in 5 min)"
		task.wait(10)
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.5)
			if alive() then
				local step, flag
				if S.AutoTushita and Sea == 3 then step, flag = stepTushita, "AutoTushita"
				elseif S.AutoCDK and Sea == 3 then step, flag = stepCDK, "AutoCDK"
				elseif S.AutoRaceV2 and Sea == 2 then step, flag = stepRaceV2, "AutoRaceV2"
				elseif S.AutoRaceV3 and Sea == 2 then step, flag = stepRaceV3, "AutoRaceV3"
				elseif S.AutoSoulGuitar and Sea == 3 then step, flag = stepSoulGuitar, "AutoSoulGuitar"
				elseif S.AutoStyles then step, flag = stepStyles, "AutoStyles"
				end
				if step then
					local ok, err = pcall(step, function() return S[flag] end)
					if not ok then
						logError(flag, err)
						task.wait(2)
					end
				end
			end
		end
	end)
end

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
		if S.AutoChest and alive() and not mainFarmBusy() then
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
		if S.AutoFruit and alive() and not mainFarmBusy() then
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

-- میوه‌ی رندوم: سیستم جدید Gacha، با دستور قدیمی Cousin به‌عنوان پشتیبان
local GachaRF = Net and Net:FindFirstChild("RF/GachaNetworkRF")
local function describe(r)
	if type(r) == "table" then
		local parts = {}
		for k, v in pairs(r) do
			table.insert(parts, tostring(k) .. "=" .. tostring(v))
			if #parts >= 4 then break end
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(r)
end

local function buyRandomFruit()
	if GachaRF then
		local ok, r = pcall(GachaRF.InvokeServer, GachaRF, { Context = "Purchase", BoxName = "ZiolesGacha" })
		if ok and r ~= nil then return true, "Gacha: " .. describe(r) end
		if not ok then logError("Gacha", r) end
	end
	local r = invoke("Cousin", "Buy")
	if r ~= nil then return true, "Cousin: " .. describe(r) end
	return false, "no response (cooldown / not enough beli?)"
end

-- محدودیت‌های ایمنی: حداقل بلی که نگه داره + حداکثر خرید در هر بار روشن کردن
Hub.FruitBuys = 0
task.spawn(function()
	local delay = 30
	while Hub.Running do
		if S.AutoRandomFruit then
			local beli = dataValue("Beli") or 0
			if beli < S.FruitMinBeli then
				S.AutoRandomFruit = false
				if notifyHook then notifyHook("Auto Random Fruit", "Stopped: beli below " .. S.FruitMinBeli, 6) end
			elseif Hub.FruitBuys >= S.FruitMaxBuys then
				S.AutoRandomFruit = false
				if notifyHook then notifyHook("Auto Random Fruit", "Stopped: bought " .. Hub.FruitBuys .. " fruits (limit)", 6) end
			else
				local ok, info = buyRandomFruit()
				S.Status = "Random fruit: " .. info
				if ok then
					Hub.FruitBuys += 1
					if notifyHook then notifyHook("Random Fruit (" .. Hub.FruitBuys .. "/" .. S.FruitMaxBuys .. ")", info, 4) end
				end
				-- اگه نشد کم‌کم صبر بیشتر (تا 5 دقیقه)
				delay = ok and 30 or math.min(delay * 2, 300)
			end
		end
		task.wait(delay)
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
			if pts > 0 then
				local amount = math.min(pts, S.StatAmount)
				-- پخش بین دو استت
				if S.StatType2 ~= "None" and S.StatType2 ~= S.StatType and amount >= 2 then
					local half = math.floor(amount / 2)
					invoke("AddPoint", S.StatType, amount - half)
					invoke("AddPoint", S.StatType2, half)
				else
					invoke("AddPoint", S.StatType, amount)
				end
			end
		end
	end
end)

-- Observation (Ken) و اسکیل ریس (کلید T)
local CommE = Remotes and Remotes:FindFirstChild("CommE")
task.spawn(function()
	local tick5 = 0
	while Hub.Running do
		task.wait(1)
		tick5 += 1
		if alive() and tick5 % 5 == 0 then
			if S.AutoKen and CommE then pcall(CommE.FireServer, CommE, "Ken", true) end
			if S.AutoRace and VIM then
				pcall(function()
					VIM:SendKeyEvent(true, Enum.KeyCode.T, false, game)
					task.wait(0.05)
					VIM:SendKeyEvent(false, Enum.KeyCode.T, false, game)
				end)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Boss spawns / notifiers
---------------------------------------------------------------------
-- محل اسپاون باس‌ها از EnemySpawns (اسم‌هایی که [Boss] دارن)
local function bossSpawns()
	local out, seen = {}, {}
	local sp = spawnFolder()
	if sp then
		for _, p in ipairs(sp:GetChildren()) do
			if p:IsA("BasePart") and p.Name:find("%[Boss%]") then
				local n = mobBaseName(p.Name)
				if not seen[n] then
					seen[n] = true
					table.insert(out, { name = n, cf = p.CFrame })
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

local function bossNames()
	local set, out = {}, {}
	for _, b in ipairs(bossSpawns()) do set[b.name] = true end
	for _, q in ipairs(BossList) do set[q.mob] = true end
	for n in pairs(set) do table.insert(out, n) end
	table.sort(out)
	return out
end

-- همه‌ی باس‌های اسپاون‌شده‌ی این Sea یکی‌یکی (نزدیک‌ترین اول)، با کوئستشون اگه Take Boss Quest روشن باشه
task.spawn(function()
	while Hub.Running do
		task.wait(0.5)
		if S.AutoAllBosses and alive() then
			local keep = function() return S.AutoAllBosses end
			local ok, err = pcall(function()
				local root = getRoot()
				local target, bestDist
				for _, name in ipairs(bossNames()) do
					local b = findMobAnywhere(name)
					if b then
						local d = (b:GetPivot().Position - root.Position).Magnitude
						if not bestDist or d < bestDist then target, bestDist = name, d end
					end
				end
				if not target then
					S.Status = "No bosses spawned right now"
					task.wait(3)
					return
				end
				local q = questForMob(target)
				if S.BossQuest and q and not questBlocked(q) and not hasQuest(q.mob) then
					takeQuest(q, keep)
				end
				fightBoss(target, keep)
			end)
			if not ok then logError("AutoAllBosses", err) end
		end
	end
end)

task.spawn(function()
	local present, first = {}, true
	while Hub.Running do
		task.wait(3)
		pcall(function()
			for _, name in ipairs(bossNames()) do
				local now = findMobAnywhere(name) ~= nil
				if now and not present[name] and not first and S.BossNotify and notifyHook then
					notifyHook("Boss Spawned", name .. " just spawned!", 6)
				end
				present[name] = now
			end
			first = false
		end)
	end
end)

connect(workspace.ChildAdded, function(v)
	if S.FruitNotify and notifyHook and (v:IsA("Tool") or v:IsA("Model")) and v.Name:find("Fruit") then
		notifyHook("Fruit Spawned", v.Name .. " is on the map!", 8)
	end
end)

-- رویدادهای دنیا (Mirage، Kitsune، Prehistoric، Frozen Dimension و ...) — فقط نگاه می‌کنه و خبر میده
Hub.Events = {}
task.spawn(function()
	local KEYS = { "mirage", "mystic", "kitsune", "prehistoric", "frozen", "leviathan" }
	local first = true
	while Hub.Running do
		pcall(function()
			local found = {}
			local wo = workspace:FindFirstChild("_WorldOrigin")
			for _, folder in ipairs({ wo and wo:FindFirstChild("Locations"), workspace:FindFirstChild("Map") }) do
				for _, c in ipairs(folder and folder:GetChildren() or {}) do
					local l = c.Name:lower()
					for _, k in ipairs(KEYS) do
						if l:find(k, 1, true) and (c:IsA("BasePart") or c:IsA("Model")) then
							found[k] = found[k] or c
						end
					end
				end
			end
			for k, obj in pairs(found) do
				if not Hub.Events[k] and not first and S.EventNotify and notifyHook then
					notifyHook("World Event", obj.Name .. " spawned!", 10)
				end
			end
			Hub.Events = found
			first = false
		end)
		task.wait(5)
	end
end)

-- Auto Rejoin وقتی از بازی بیرون انداخته میشی
pcall(function()
	connect(game:GetService("GuiService").ErrorMessageChanged, function(msg)
		if S.AutoRejoin and msg and msg ~= "" then
			task.wait(3)
			pcall(function() Svc.Teleport:Teleport(game.PlaceId, player) end)
		end
	end)
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

---------------------------------------------------------------------
-- راه رفتن روی آب، بری‌ها، نور و مه
---------------------------------------------------------------------
do
	-- سطح آب از قطعه‌ی WaterBody خود بازی؛ یه سکوی نامرئی محلی زیر پا میذاریم (فقط روی کامپیوتر خودت)
	local platform, waterY, waterCheck = nil, nil, 0
	local function readWaterTop()
		local ok, list = pcall(CollectionService.GetTagged, CollectionService, "WaterBody")
		local w = ok and list[1]
		if not w then return nil end
		if w:IsA("BasePart") then return w.Position.Y + w.Size.Y / 2 end
		if w:IsA("Model") then
			local cf, size = w:GetBoundingBox()
			return cf.Position.Y + size.Y / 2
		end
	end
	connect(RunService.Heartbeat, function()
		if not S.WalkOnWater then
			if platform then
				platform:Destroy()
				platform = nil
			end
			return
		end
		if tick() - waterCheck > 5 then
			waterCheck = tick()
			waterY = readWaterTop() or waterY
		end
		local root = getRoot()
		if not root or not waterY then return end
		if not platform then
			platform = Instance.new("Part")
			platform.Name = "BMWaterWalk"
			platform.Anchored = true
			platform.Transparency = 1
			platform.Size = Vector3.new(24, 1, 24)
			platform.CanQuery = false
			platform.Parent = workspace
		end
		-- فقط وقتی نزدیک سطح آبی (نه وقتی بالای جزیره یا زیر آب)
		if root.Position.Y > waterY - 2 and root.Position.Y < waterY + 12 then
			platform.CanCollide = true
			platform.CFrame = CFrame.new(root.Position.X, waterY - 0.5, root.Position.Z)
		else
			platform.CanCollide = false
		end
	end)

	-- بری‌ها: مثل بازیکن واقعی دکمه‌ی E خود بازی (ProximityPrompt) رو می‌زنیم
	local function promptPos(p)
		local par = p.Parent
		if par and par:IsA("Attachment") then return par.WorldPosition end
		if par and par:IsA("BasePart") then return par.Position end
		if par and par:IsA("Model") then return par:GetPivot().Position end
	end
	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			if S.AutoBerries and alive() and not mainFarmBusy() then
				pcall(function()
					local root = getRoot()
					local best, bestDist, bestPos
					for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
						for _, d in ipairs(bush:GetDescendants()) do
							if d:IsA("ProximityPrompt") and d.Enabled then
								local pos = promptPos(d)
								if pos then
									local dist = (pos - root.Position).Magnitude
									if not bestDist or dist < bestDist then best, bestDist, bestPos = d, dist, pos end
								end
							end
						end
					end
					if not best then
						S.Status = "No berries ready nearby"
						task.wait(4)
						return
					end
					S.Status = "Collecting berry"
					tweenTo(CFrame.new(bestPos + Vector3.new(0, 3, 0)), function() return S.AutoBerries and best.Parent ~= nil end)
					task.wait(0.3)
					if fireproximityprompt then pcall(fireproximityprompt, best) end
					task.wait(0.6)
				end)
			end
		end
	end)

	-- نور کامل و بدون مه (فقط روی صفحه‌ی خودت)
	local saved = {}
	local function applyLighting()
		if S.Fullbright or S.NoFog then
			if not saved.stored then
				saved = { stored = true, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient }
			end
			if S.Fullbright then
				Lighting.Brightness = 2
				Lighting.ClockTime = 14
				Lighting.GlobalShadows = false
				Lighting.Ambient = Color3.fromRGB(178, 178, 178)
			end
			if S.NoFog then
				Lighting.FogEnd = 1e9
				for _, a in ipairs(Lighting:GetChildren()) do
					if a:IsA("Atmosphere") then a.Density = 0 end
				end
			end
		elseif saved.stored then
			Lighting.Brightness = saved.Brightness
			Lighting.ClockTime = saved.ClockTime
			Lighting.FogEnd = saved.FogEnd
			Lighting.GlobalShadows = saved.GlobalShadows
			Lighting.Ambient = saved.Ambient
			saved = {}
		end
	end
	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			pcall(applyLighting)
		end
	end)
end

connect(UserInputService.JumpRequest, function()
	if S.InfJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

connect(player.Idled, function()
	if S.AntiAFK then
		pcall(function()
			Svc.VirtualUser:CaptureController()
			Svc.VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

---------------------------------------------------------------------
-- Utility actions
---------------------------------------------------------------------
-- lowest = true: کم‌جمعیت‌ترین سرور
local function serverHop(lowest)
	local order = lowest and "Asc" or "Desc"
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100")
	end)
	if ok then
		local data = Svc.Http:JSONDecode(body)
		local best
		for _, s in ipairs(data.data or {}) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				if not lowest then
					best = s
					break
				end
				if s.playing > 0 and (not best or s.playing < best.playing) then best = s end
			end
		end
		if best then
			Svc.Teleport:TeleportToPlaceInstance(game.PlaceId, best.id, player)
			return true
		end
	end
	return false
end

-- وقتی بازیکن دیگه‌ای نزدیک بشه سرور عوض میشه
task.spawn(function()
	while Hub.Running do
		task.wait(1)
		if S.AutoHopNear and alive() then
			local root = getRoot()
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - root.Position).Magnitude <= S.HopDistance then
					S.Status = "Player nearby (" .. p.Name .. "), hopping..."
					serverHop(true)
					task.wait(10)
					break
				end
			end
		end
	end
end)

-- Server Finder: بدون رفتن به یه سرور نمیشه دید چی توشه؛ پس میره، چند ثانیه نگاه می‌کنه، نبود میره بعدی
-- وضعیت (سرورهای دیده‌شده، تعداد هاپ) توی فایل می‌مونه چون بعد از تلپورت هاب از اول اجرا میشه
do
	local HUNT_FILE = "BMHub_hunt.json"
	local LOADER = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v2.lua"))()'
	local queueTp = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	Hub.CanQueue = queueTp ~= nil

	local function readHunt()
		local ok, d = pcall(function() return Svc.Http:JSONDecode(readfile(HUNT_FILE)) end)
		d = (ok and type(d) == "table") and d or {}
		d.visited = type(d.visited) == "table" and d.visited or {}
		d.hops = tonumber(d.hops) or 0
		d.last = tonumber(d.last) or 0
		return d
	end
	local function writeHunt(d) pcall(function() writefile(HUNT_FILE, Svc.Http:JSONEncode(d)) end) end
	function Hub.HuntReset() writeHunt({ visited = {}, hops = 0, last = os.time() }) end
	function Hub.HuntHops() return readHunt().hops end

	local function fullMoonNight()
		local full = false
		pcall(function()
			full = Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431" and (Lighting.ClockTime > 16 or Lighting.ClockTime < 5)
		end)
		return full
	end
	Hub.FullMoonNight = fullMoonNight

	local EVENT_KEYS = { ["Mirage Island"] = { "mirage", "mystic" }, ["Kitsune Island"] = { "kitsune" }, ["Prehistoric Island"] = { "prehistoric" } }

	function Hub.HuntTargets()
		local out = { "Any Fruit", "Full Moon" }
		if Sea == 2 then table.insert(out, "Legendary Sword Dealer") end
		if Sea == 3 then
			for _, n in ipairs({ "Mirage Island", "Kitsune Island", "Prehistoric Island" }) do table.insert(out, n) end
		end
		for _, n in ipairs(bossNames()) do table.insert(out, "Boss: " .. n) end
		return out
	end

	-- اگه هدف توی همین سرور باشه، جاش و اسمش رو برمی‌گردونه
	function Hub.HuntFind(t)
		if not t then return nil end
		if t == "Any Fruit" then
			local f = getWorldFruits()[1]
			if f then return f.part.Position, f.obj.Name end
		elseif t == "Full Moon" then
			local r = fullMoonNight() and getRoot()
			if r then return r.Position, "Full moon night" end
		elseif t == "Legendary Sword Dealer" then
			local cf = dealerPosition()
			if cf then return cf.Position, t end
		elseif EVENT_KEYS[t] then
			for _, k in ipairs(EVENT_KEYS[t]) do
				local obj = Hub.Events[k]
				if obj then return (obj:IsA("Model") and obj:GetPivot().Position or obj.Position), t end
			end
		else
			local name = t:match("^Boss: (.+)$")
			local m = name and findMobAnywhere(name)
			if m then return m:GetPivot().Position, name end
		end
	end

	-- یه سرور تصادفی که قبلاً نرفتیم و جا داره
	local function pickServer(seen)
		local cursor, pool = nil, {}
		for _ = 1, 3 do
			local ok, body = pcall(function()
				return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100" .. (cursor and ("&cursor=" .. cursor) or ""))
			end)
			if not ok then break end
			local okD, data = pcall(function() return Svc.Http:JSONDecode(body) end)
			if not okD or type(data) ~= "table" then break end
			for _, s in ipairs(data.data or {}) do
				if s.id and not seen[s.id] and (s.playing or 0) < (s.maxPlayers or 0) - 1 then table.insert(pool, s.id) end
			end
			cursor = data.nextPageCursor
			if #pool >= 20 or not cursor then break end
			task.wait(1)
		end
		return #pool > 0 and pool[math.random(#pool)] or nil
	end

	local tpFailed = false
	pcall(function()
		connect(Svc.Teleport.TeleportInitFailed, function(p) if p == player then tpFailed = true end end)
	end)

	Hub.HuntStatus = "Off"
	task.spawn(function()
		task.wait(3)
		-- شکاری که بیشتر از ۲۰ دقیقه پیش ول شده ادامه پیدا نمی‌کنه
		if S.HuntHop and os.time() - readHunt().last > 1200 then S.HuntHop = false end
		local arrived = tick()
		while Hub.Running do
			task.wait(1)
			if not S.HuntHop then
				Hub.HuntStatus = "Off"
				arrived = tick()
			else
				local d = readHunt()
				local pos, what = Hub.HuntFind(S.HuntTarget)
				local waited = tick() - arrived
				if pos then
					S.HuntHop = false
					Hub.HuntReset()
					if Hub.SaveSettings then Hub.SaveSettings() end
					Hub.HuntStatus = "Found " .. tostring(what) .. " ✔ (after " .. d.hops .. " hops)"
					if notifyHook then notifyHook("Server Finder", "Found " .. tostring(what) .. "!", 15) end
					if S.HuntGoTo and Hub.GoTo and S.HuntTarget ~= "Full Moon" then
						Hub.GoTo(CFrame.new(pos + Vector3.new(0, 40, 0)))
					end
				elseif waited < S.HuntWait then
					Hub.HuntStatus = ("Checking this server... %ds  (hop %d/%d)"):format(math.ceil(S.HuntWait - waited), d.hops, S.HuntMaxHops)
				elseif d.hops >= S.HuntMaxHops then
					S.HuntHop = false
					Hub.HuntReset()
					if Hub.SaveSettings then Hub.SaveSettings() end
					Hub.HuntStatus = "Stopped: not found in " .. S.HuntMaxHops .. " servers"
					if notifyHook then notifyHook("Server Finder", Hub.HuntStatus, 10) end
				else
					local seen = { [game.JobId] = true }
					for _, id in ipairs(d.visited) do seen[id] = true end
					local id = pickServer(seen)
					if not id then
						Hub.HuntStatus = "No new server found, retrying in 10s..."
						arrived = tick() - S.HuntWait + 10
					else
						table.insert(d.visited, game.JobId)
						while #d.visited > 200 do table.remove(d.visited, 1) end
						d.hops += 1
						d.last = os.time()
						writeHunt(d)
						if Hub.SaveSettings then Hub.SaveSettings() end
						if queueTp then pcall(queueTp, LOADER) end
						Hub.HuntStatus = "Hopping (" .. d.hops .. "/" .. S.HuntMaxHops .. ")..."
						tpFailed = false
						pcall(function() Svc.Teleport:TeleportToPlaceInstance(game.PlaceId, id, player) end)
						-- اگه تلپورت نشد (سرور پر شد و ...) چند ثانیه بعد یکی دیگه
						local t0 = tick()
						repeat task.wait(1) until tpFailed or tick() - t0 > 20 or not Hub.Running
						arrived = tick() - S.HuntWait + 5
					end
				end
			end
		end
	end)

	-- اعلان شروع شب ماه کامل
	task.spawn(function()
		local was = fullMoonNight()
		while Hub.Running do
			task.wait(10)
			local now = fullMoonNight()
			if now and not was and S.MoonNotify and notifyHook then notifyHook("Full Moon", "Full moon night started!", 12) end
			was = now
		end
	end)

	-- Mirage: مدل جزیره، بلندترین نقطه (برای نگاه به ماه) و Blue Gear
	function Hub.MirageModel()
		local map = workspace:FindFirstChild("Map")
		for _, c in ipairs(map and map:GetChildren() or {}) do
			local l = c.Name:lower()
			if l:find("mirage", 1, true) or l:find("mystic", 1, true) then return c end
		end
		return Hub.Events.mirage or Hub.Events.mystic
	end
	function Hub.MirageTop()
		local m = Hub.MirageModel()
		if not m then return nil end
		local best
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide and p.Transparency < 1 and p.Size.Magnitude > 4 then
				local top = p.Position.Y + p.Size.Y / 2
				if not best or top > best.Y then best = Vector3.new(p.Position.X, top, p.Position.Z) end
			end
		end
		return best
	end
	-- اسم دقیق Blue Gear هنوز از دامپ تأیید نشده؛ هر پارت قابل‌دیدنی که اسمش gear داره
	function Hub.FindGear()
		local m = Hub.MirageModel()
		if not m then return nil end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name:lower():find("gear", 1, true) then return p end
		end
	end
	-- برای لیبل و ESP که هر ۰.۳ ثانیه صدا زده میشن؛ گشتن کل جزیره هر ۵ ثانیه یه بار
	local gearAt, gearPart = 0, nil
	function Hub.GearCached()
		if tick() - gearAt > 5 then
			gearAt = tick()
			gearPart = Hub.FindGear()
		end
		return gearPart and gearPart.Parent and gearPart or nil
	end
	function Hub.DumpMirage()
		local m = Hub.MirageModel()
		if not m then return nil end
		local lines = {}
		for i, v in ipairs(m:GetDescendants()) do
			if i > 4000 then break end
			local extra = v:IsA("BasePart") and (" pos=%.0f,%.0f,%.0f T=%.2f"):format(v.Position.X, v.Position.Y, v.Position.Z, v.Transparency) or ""
			table.insert(lines, v:GetFullName() .. " [" .. v.ClassName .. "]" .. extra)
		end
		pcall(function() writefile("bmscan/mirage.txt", table.concat(lines, "\n")) end)
		return #lines
	end
end

-- کدها (کدهای ریست استت عمداً حذف شدن)
local CODES = {
	"EASTEREXP", "LIGHTNINGABUSE", "1LOSTADMIN", "CHANDLER", "Sub2CaptainMaui", "BIGNEWS", "kittgaming",
	"Sub2Fer999", "Enyu_is_Pro", "Magicbus", "JCWK", "Bluxxy", "fudd10_v2", "SUB2GAMERROBOT_EXP1",
	"Sub2UncleKizaru", "Axiore", "Sub2Daigrock", "Sub2NoobMaster123", "StrawHatMaine", "TantaiGaming",
	"Fudd10", "TheGreatAce", "Sub2OfficialNoobie",
}
local function redeemAllCodes()
	local redeem = Remotes and Remotes:FindFirstChild("Redeem")
	if not redeem then return 0, "Redeem remote not found" end
	local n = 0
	for _, code in ipairs(CODES) do
		if pcall(redeem.InvokeServer, redeem, code) then n += 1 end
		task.wait(0.3)
	end
	return n
end

-- فایتینگ استایل‌ها: اسم -> دستورهای CommF_ (به ترتیب)
local FIGHTING_STYLES = {
	{ "Black Leg", { { "BuyBlackLeg" } } },
	{ "Electro", { { "BuyElectro" } } },
	{ "Fishman Karate", { { "BuyFishmanKarate" } } },
	{ "Dragon Claw", { { "BlackbeardReward", "DragonClaw", "1" }, { "BlackbeardReward", "DragonClaw", "2" } } },
	{ "Superhuman", { { "BuySuperhuman" } } },
	{ "Death Step", { { "BuyDeathStep" } } },
	{ "Sharkman Karate", { { "BuySharkmanKarate", true }, { "BuySharkmanKarate" } } },
	{ "Electric Claw", { { "BuyElectricClaw" } } },
	{ "Dragon Talon", { { "BuyDragonTalon" } } },
	{ "Godhuman", { { "BuyGodhuman" } } },
	{ "Sanguine Art", { { "BuySanguineArt" } } },
}
local function styleNames()
	local out = {}
	for _, s in ipairs(FIGHTING_STYLES) do table.insert(out, s[1]) end
	return out
end
local function buyStyle(name)
	for _, s in ipairs(FIGHTING_STYLES) do
		if s[1] == name then
			local last
			for _, args in ipairs(s[2]) do
				last = invoke(table.unpack(args))
				task.wait(0.2)
			end
			return last
		end
	end
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

-- NPC های دور توی ReplicatedStorage.NPCs نگه داشته میشن
local function npcFolders()
	return { workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }
end

local function npcList()
	local out = {}
	for _, folder in ipairs(npcFolders()) do
		if folder then
			for _, v in ipairs(folder:GetChildren()) do
				local name = v.Name:gsub("^%s+", "")
				if v:IsA("Model") and name ~= "" and not table.find(out, v.Name) then table.insert(out, v.Name) end
			end
		end
	end
	table.sort(out)
	return out
end

local function findNPC(name)
	for _, folder in ipairs(npcFolders()) do
		local npc = folder and folder:FindFirstChild(name)
		if npc then
			local ok, cf = pcall(function() return npc:GetPivot() end)
			if ok and cf.Position.Y > -500 then return cf end
		end
	end
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
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, m in ipairs(enemies:GetChildren()) do
			local n = mobBaseName(m.Name)
			if not table.find(out, n) then table.insert(out, n) end
		end
	end
	return out
end

-- گزارش برای پیدا کردن مشکل‌ها (کپی میشه تا برای Claude بفرستی)
-- لاگ زنده: چند دقیقه‌ی آخر کارهای اسکریپت توی bmscan/live.txt، که Claude بدون دکمه زدن ببینه چی شده
do
	local lines, dirty = {}, false
	local function push(text)
		table.insert(lines, os.date("%H:%M:%S") .. "  " .. text)
		if #lines > 200 then table.remove(lines, 1) end
		dirty = true
	end
	Hub.LiveLog = push
	pcall(function()
		if makefolder and not (isfolder and isfolder("bmscan")) then makefolder("bmscan") end
	end)
	push(("BM Hub %s started | sea %s | place %s | level %s"):format(Hub.Version, tostring(Sea), tostring(game.PlaceId), tostring(dataValue("Level"))))
	task.spawn(function()
		local last, lastBeat = "", 0
		while Hub.Running do
			pcall(function()
				local on = {}
				for k, v in pairs(S) do
					if v == true and (k:find("^Auto") or k:find("^Kill") or k:find("^Summon")) and k ~= "AutoSave" and k ~= "AutoRejoin" and k ~= "AutoHaki" then
						table.insert(on, k)
					end
				end
				table.sort(on)
				local root, hum = getRoot(), getHum()
				local state = ("%s | quest: %s | on: %s"):format(S.Status, questTitle() or "none", table.concat(on, ","))
				-- فقط وقتی چیزی عوض شد، یا هر 15 ثانیه یه خط
				if state ~= last or tick() - lastBeat > 15 then
					local pos = root and ("(%d, %d, %d)"):format(math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z)) or "dead"
					push(("%s | pos %s | hp %d | moving %s"):format(state, pos, hum and math.floor(hum.Health) or 0, tostring(activeTween ~= nil)))
					last, lastBeat = state, tick()
				end
				-- حمله: هر 3 ثانیه وقتی ماب نزدیکه (برای فهمیدن این‌که دمیج می‌خوره یا نه)
				local char = getChar()
				local enemies = workspace:FindFirstChild("Enemies")
				if root and char and enemies and tick() - (Hub.AtkLogAt or 0) > 3 then
					local near, best, bestD = 0, nil, nil
					for _, m in ipairs(enemies:GetChildren()) do
						if isAliveMob(m) then
							local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
							if d <= S.AttackRange then near += 1 end
							if not bestD or d < bestD then best, bestD = m, d end
						end
					end
					if near > 0 then
						Hub.AtkLogAt = tick()
						local held = char:FindFirstChildOfClass("Tool")
						local a = Hub.AttackInfo
						local function flag(n) local v = char:FindFirstChild(n) return v and tostring(v.Value) or "-" end
						push(("ATTACK held=%s near=%d target=%s hp=%d dist=%d | clicks=%d activates=%d err=%s | Stun=%s Busy=%s Sit=%s"):format(
							held and (held.Name .. "[" .. tostring(held.ToolTip) .. "]") or "none", near, mobBaseName(best.Name),
							math.floor(best.Humanoid.Health), math.floor(bestD), a.click, a.tool, tostring(a.lastError),
							flag("Stun"), flag("Busy"), tostring(hum and hum.Sit)))
					end
				end
				if dirty then
					dirty = false
					writefile("bmscan/live.txt", table.concat(lines, "\n"))
				end
			end)
			task.wait(1)
		end
	end)
end

local function debugReport()
	local lines = {}
	local function add(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
		table.insert(lines, table.concat(parts, " "))
	end
	local identity = "?"
	pcall(function() identity = (getthreadidentity or getidentity or get_thread_identity)() end)
	add("== BM Hub", Hub.Version, "debug ==")
	add("executor:", executorName, "| identity:", identity, "| place:", game.PlaceId, "| sea:", Sea)
	add("level:", dataValue("Level"), "| beli:", dataValue("Beli"), "| status:", S.Status)
	add("funcs: require=", pcall(function() return require end) and type(require),
		"setclipboard=", type(setclipboard), "sethiddenproperty=", type(sethiddenproperty),
		"gethui=", type(gethui), "VIM=", VIM ~= nil)
	add("CommF:", CommF and CommF:GetFullName() or "nil")
	add("RegisterAttack:", RegisterAttack and RegisterAttack:GetFullName() or "nil")
	add("RegisterHit:", RegisterHit and RegisterHit:GetFullName() or "nil")
	local a = Hub.AttackInfo
	add("attacks remote/click/tool:", a.remote, a.click, a.tool, "| last error:", a.lastError)
	if Net then
		local names = {}
		for i, r in ipairs(Net:GetChildren()) do
			if i > 40 then break end
			table.insert(names, r.Name)
		end
		add("Net children:", table.concat(names, ", "))
	else
		local mods = {}
		for _, c in ipairs(ReplicatedStorage:GetChildren()) do table.insert(mods, c.Name .. "(" .. c.ClassName .. ")") end
		add("ReplicatedStorage:", table.concat(mods, ", "))
	end
	add("quest data:", Hub.QuestLoadInfo or "loading/hung", "| QuestList:", #QuestList, "| BossList:", #BossList)
	local q = questForLevel(dataValue("Level") or 1)
	add("quest for level:", q and (q.quest .. " #" .. tostring(q.index) .. " " .. q.mob .. " @ " .. tostring(q.npc and q.npc.Position)) or "none",
		"| blocked:", q and questBlocked(q))
	add("quest title:", questTitle() or "none", "| label:", Hub.QuestLabelPath or "old Main.Quest box")
	add("last quest take time:", Hub.LastQuestTime and ("%.1fs"):format(Hub.LastQuestTime) or "n/a")
	local enemies = workspace:FindFirstChild("Enemies")
	add("Enemies folder:", enemies ~= nil, "| count:", enemies and #enemies:GetChildren() or 0)
	if enemies then
		for i, m in ipairs(enemies:GetChildren()) do
			if i > 6 then break end
			local h = m:FindFirstChildOfClass("Humanoid")
			local attrs = {}
			for k, v in pairs(m:GetAttributes()) do table.insert(attrs, k .. "=" .. tostring(v)) end
			add("  mob:", m.Name, "| display:", h and h.DisplayName, "| lv:", mobLevel(m), "| attrs:", table.concat(attrs, ","))
		end
	end
	local sp = spawnFolder()
	if sp then
		local names = {}
		for i, p in ipairs(sp:GetChildren()) do
			if i > 10 then break end
			table.insert(names, p.Name)
		end
		add("EnemySpawns:", table.concat(names, ", "))
	else
		add("EnemySpawns: nil")
	end
	local tools = {}
	for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
		if cont then
			for _, t in ipairs(cont:GetChildren()) do
				if t:IsA("Tool") then table.insert(tools, t.Name .. "[" .. t.ToolTip .. "]") end
			end
		end
	end
	add("tools:", table.concat(tools, ", "))
	inventoryTime = 0
	local invNames = {}
	for n in pairs(inventoryNames()) do table.insert(invNames, n) end
	add("inventory (" .. #invNames .. "):", table.concat(invNames, ", "))
	add("dealer spawned:", dealerPosition() ~= nil, "| hidden key:", backpackTool("Hidden Key") ~= nil)
	pcall(function() add("bones:", materialCount("Bones"), "| gamble wait:", math.max(0, math.floor((Hub.BoneGambleWait or 0) - tick())), "s | Death King (bones, trades left, minutes, max):", select(2, pcall(function() local b, _, l, m, x = CommF:InvokeServer("Bones", "Check") return table.concat({ tostring(b), tostring(l), tostring(m), tostring(x) }, ", ") end)), "| AutoBone:", S.AutoBone, "AutoBoneGamble:", S.AutoBoneGamble) end)
	add("errors:", #Hub.Errors > 0 and table.concat(Hub.Errors, " || ") or "none")
	return table.concat(lines, "\n")
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
-- لوگوی BloxyMax: یه بار از گیت‌هاب دانلود میشه توی پوشه‌ی executor و با getcustomasset نمایش داده میشه
local LOGO
pcall(function()
	if not (getcustomasset and writefile and isfile) then return end
	pcall(function()
		if makefolder and not (isfolder and isfolder("BMHub")) then makefolder("BMHub") end
	end)
	local path = "BMHub/logo.png"
	if not isfile(path) then
		writefile(path, game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/assets/logo.png"))
	end
	LOGO = getcustomasset(path)
end)

-- اگه لوگو در دسترس باشه، جای متن "BM" رو می‌گیره؛ وگرنه همون متن می‌مونه
local function applyLogo(holder)
	if not LOGO then return nil end
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("TextLabel") then c.Visible = false end
	end
	if holder:IsA("TextButton") then holder.Text = "" end
	holder.BackgroundTransparency = 1
	local img = Instance.new("ImageLabel")
	img.Name = "Logo"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = LOGO
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = holder.ZIndex + 1
	img.Parent = holder
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	return img
end

local Theme = {
	-- تم BloxyMax: مشکی + آبی (هماهنگ با لوگو)
	Bg = Color3.fromRGB(7, 8, 10),
	Panel = Color3.fromRGB(13, 14, 17),
	Card = Color3.fromRGB(20, 22, 26),
	CardHover = Color3.fromRGB(28, 32, 40),
	Text = Color3.fromRGB(238, 242, 250),
	SubText = Color3.fromRGB(128, 138, 156),
	Accent1 = Color3.fromRGB(0, 110, 255),
	Accent2 = Color3.fromRGB(0, 210, 255),
	Off = Color3.fromRGB(44, 48, 56),
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
-- Solara روی gethui/CoreGui کلیک‌ها رو نمی‌گیره، پس اونجا PlayerGui استفاده میشه
local placed = false
if not executorName:lower():find("solara") then
	placed = pcall(function() root.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
end
if not placed or not root.Parent then root.Parent = player:WaitForChild("PlayerGui") end
print("[BM Hub] executor:", executorName)
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
	if not Hub.Running then return end
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

notifyHook = notify

-- Main window
local FULL = UDim2.fromOffset(600, 390)
local main = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
	BackgroundColor3 = Theme.Bg, ClipsDescendants = true, Visible = false, Parent = root,
}, { corner(14) })
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(16, 17, 20), Color3.fromRGB(5, 6, 8)), Rotation = 90, Parent = main })
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
applyLogo(logo)
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
local tabList = new("ScrollingFrame", {
	Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Accent2, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local pageHolder = new("Frame", {
	Position = UDim2.fromOffset(170, 60), Size = UDim2.new(1, -180, 1, -70), BackgroundTransparency = 1,
	ClipsDescendants = true, Parent = main,
})

local Pages, Tabs, tabCount = {}, {}, 0
local currentPage
local dynamicLabels = {}
-- کلیدها با وضعیت واقعی هماهنگ می‌مونن (وقتی اسکریپت خودش یه گزینه رو خاموش می‌کنه)
local toggleSyncers = {}

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
		tween(t.bar, 0.3, { Size = on and UDim2.fromOffset(3, 18) or UDim2.fromOffset(3, 0) }, Enum.EasingStyle.Back)
	end
end

local function createTab(name, icon)
	tabCount += 1
	local btn = new("TextButton", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = Theme.Card, BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = tabCount, Parent = tabList,
	}, { corner(8) })
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), Parent = btn,
	}, { corner(2), gradient(90) })
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 22, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 15, Text = icon, TextColor3 = Theme.Text, Parent = btn,
	})
	local label = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamBold, TextSize = 13, Text = name, TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
	})
	Tabs[name] = { button = btn, label = label, bar = bar }

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, Parent = pageHolder,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	Pages[name] = page
	btn.Activated:Connect(function() selectPage(name) end)

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
		local hit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10, Active = true, Parent = c })
		local sw =new("Frame", {
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
		local shown
		local function render()
			local on = S[key]
			shown = on
			swGrad.Enabled = on
			tween(sw, 0.2, { BackgroundColor3 = on and Color3.new(1, 1, 1) or Theme.Off })
			tween(knob, 0.3, {
				Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(190, 192, 210),
			}, Enum.EasingStyle.Back)
		end
		hit.Activated:Connect(function()
			S[key] = not S[key]
			render()
			notify(text, S[key] and "ON ✔" or "OFF ✖", 1.5)
			if cb then task.spawn(cb, S[key]) end
		end)
		hoverCard(c, hit)
		render()
		table.insert(toggleSyncers, function()
			if S[key] ~= shown then render() end
		end)
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
		local hit = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10, Active = true, Parent = c })
		hit.Activated:Connect(function()
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
		local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 26), ZIndex = 10, Active = true, Parent = c })
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
		local header = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Text = "", ZIndex = 10, Active = true, Parent = c })
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
				b.Activated:Connect(function()
					S[key] = o
					refreshLabel()
					close()
					if cb then task.spawn(cb, o) end
				end)
			end
			return #opts
		end
		header.Activated:Connect(function()
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
-- Settings save / load (پوشه‌ی workspace خود executor)
---------------------------------------------------------------------
local SETTINGS_FILE = "BMHub_settings.json"
-- گزینه‌هایی که پول خرج می‌کنن هیچ‌وقت خودکار روشن نمیشن
local SKIP_SAVE = { Status = true, AutoRandomFruit = true, AutoLegendary = true, AutoBuyChip = true, AutoBoneGamble = true, AutoAbilities = true, AutoStyles = true, AutoSoulGuitar = true, AutoAwaken = true, AutoHakiColor = true, SummonSoulReaper = true, SummonDoughKing = true }

local function saveSettings()
	local data = {}
	for k, v in pairs(S) do
		local t = type(v)
		if not SKIP_SAVE[k] and (t == "boolean" or t == "number" or t == "string") then data[k] = v end
	end
	return pcall(function() writefile(SETTINGS_FILE, Svc.Http:JSONEncode(data)) end)
end

local function loadSettings()
	local ok, data = pcall(function()
		if isfile and not isfile(SETTINGS_FILE) then return nil end
		return Svc.Http:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if not ok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		if S[k] ~= nil and type(S[k]) == type(v) and not SKIP_SAVE[k] then S[k] = v end
	end
	return true
end

Hub.SaveSettings = saveSettings
local settingsLoaded = loadSettings()
-- تنظیمات ذخیره‌شده‌ای که باید همون اول اعمال بشن
if S.CPUSaver then pcall(function() RunService:Set3dRenderingEnabled(false) end) end
if S.FPSCapOn and setfpscap then pcall(setfpscap, S.FPSCap) end
print("[BM Hub] settings loaded:", settingsLoaded)

task.spawn(function()
	while Hub.Running do
		task.wait(30)
		if S.AutoSave then saveSettings() end
	end
end)

---------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------
do -- صفحه‌ها: هر تب توی do خودش (رجیسترهای Luau محدودن) و گزینه‌های هر دریا فقط توی همون دریا
local function goTo(cf) return tweenTo(cf, nil, true) end
Hub.GoTo = goTo
local function stopOff(on) if not on then stopTween() S.Status = "Idle" end end
local SEA_NAME = Sea > 0 and ("Sea " .. Sea) or "Sea ?"

-- Home: اطلاعات و دیباگ
do
	local T = createTab("Home", "⌂")
	T:Profile()
	T:Section("Stats")
	T:Label(function() return "Level:  <font color=\"#00D2FF\">" .. formatNumber(dataValue("Level") or 0) .. "</font>  •  " .. SEA_NAME end)
	T:Label(function() return "Beli:  <font color=\"#7CFF9B\">$" .. formatNumber(dataValue("Beli") or 0) .. "</font>" end)
	T:Label(function() return "Fragments:  <font color=\"#7FC8FF\">" .. formatNumber(dataValue("Fragments") or 0) .. "</font>" end)
	T:Label(function() return "Stat Points:  " .. formatNumber(dataValue("Points") or 0) end)
	T:Label(function() return "Status:  <font color=\"#FFD166\">" .. S.Status .. "</font>" end)
	T:Label(function() return "Quest:  " .. (questTitle() or "none") end)
	T:Section("Info")
	T:Label(function() return "Quests loaded: " .. #QuestList .. "  •  Bosses: " .. #BossList end)
	T:Label(function() return "Toggle UI:  RightControl  /  BM button" end)
	T:Section("Debug")
	T:Button("Copy Debug Report", function()
		local report = debugReport()
		local copied = pcall(function() (setclipboard or toclipboard)(report) end)
		-- کپی همیشه به Claude نمی‌رسه؛ توی فایل هم ذخیره می‌کنیم
		pcall(function()
			if makefolder and not (isfolder and isfolder("bmscan")) then makefolder("bmscan") end
			writefile("bmscan/debug.txt", report)
		end)
		print(report)
		notify("Debug Report", copied and "Copied ✔ — paste it to Claude" or "Printed to console (F9)", 5)
	end)
end

-- Farm: فارم لول/ماب، مستری، اسکیل‌ها (همه‌ی دریاها)
do
	local T = createTab("Farm", "☰")
	T:Section("Auto Farm")
	T:Toggle("Auto Farm", "AutoFarm", stopOff)
	T:Dropdown("Farm Mode", function() return { "Level", "Nearest Mob", "Selected Mob" } end, "FarmMode")
	T:Dropdown("Select Mob", mobOptions, "SelectedMob")
	T:Toggle("Take Quest", "TakeQuest")
	T:Toggle("Auto Click (attacks with the weapon in your hand)", "AutoClick")
	T:Toggle("Fast Attack (faster normal clicks)", "FastAttack")
	T:Toggle("Bring Mobs", "BringMobs")
	T:Toggle("Use Skills While Farming (Z/X/C)", "FarmSkills")
	T:Toggle("Auto Retreat When Low HP", "AutoRetreat")
	T:Slider("Retreat Below HP %", 10, 70, "RetreatHP")
	if #(Hub.Materials or {}) > 0 then
		T:Section("Materials (" .. SEA_NAME .. ")")
		T:Dropdown("Material", function()
			local out = {}
			for _, m in ipairs(Hub.Materials) do table.insert(out, m[1] .. " (" .. table.concat(m[2], ", ") .. ")") end
			return out
		end, "Material")
		T:Toggle("Auto Farm Material", "AutoMaterial", stopOff)
		T:Label(function() return "Farms the mobs that drop it (turn off Auto Farm)" end)
	end
	T:Section("Mastery Farm")
	T:Toggle("Mastery Farm (with Auto Farm)", "MasteryFarm")
	T:Dropdown("Mastery Weapon", function() return { "Blox Fruit", "Sword", "Gun" } end, "MasteryWeapon")
	T:Slider("Switch at Mob HP %", 5, 90, "MasteryHealth")
	T:Section("Skills")
	T:Toggle("Use Skills", "UseSkills")
	T:Toggle("Skill Z", "SkillZ")
	T:Toggle("Skill X", "SkillX")
	T:Toggle("Skill C", "SkillC")
	T:Toggle("Skill V", "SkillV")
end

-- دریای فعلی: فقط فارم‌ها، آیتم‌ها و پیشرفت همین دریا
do
	local T = createTab(SEA_NAME, "≋")
	if Sea == 1 then
		T:Section("Progress")
		T:Toggle("Auto Saber (Lv 200+)", "AutoSaber", stopOff)
		T:Toggle("Auto Unlock Sea 2 (Lv 700+)", "AutoSea2", stopOff)
		T:Label(function() return "Turn off Auto Farm while these run" end)
	elseif Sea == 2 then
		T:Section("Farms")
		T:Toggle("Auto Factory (Core)", "AutoFactory", stopOff)
		T:Toggle("Auto Ectoplasm (Cursed Ship)", "AutoEcto", stopOff)
		T:Label(function() return "Ectoplasm: " .. formatNumber(invokeCached("ectoCount", 15, "Ectoplasm", "Check") or 0) end)
		T:Section("Raid (Lv 1100+)")
		T:Dropdown("Raid Type", function()
			return { "Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Magma", "Buddha", "Sand", "Phoenix", "Dough" }
		end, "RaidType")
		T:Toggle("Auto Buy Chip (spends!)", "AutoBuyChip")
		T:Toggle("Auto Raid (start + clear islands)", "AutoRaid", stopOff)
		T:Section("Progress")
		T:Toggle("Auto Bartilo Quest (Lv 850+)", "AutoBartilo", stopOff)
		T:Toggle("Auto Unlock Sea 3 (Lv 1500+)", "AutoSea3", stopOff)
		T:Toggle("Auto Race V2 (Alchemist)", "AutoRaceV2", stopOff)
		T:Toggle("Auto Race V3 (Human/Rabbit/Fishman)", "AutoRaceV3", stopOff)
		T:Section("Swords")
		T:Toggle("Auto Rengoku (key + chest)", "AutoRengoku", stopOff)
		T:Label(function()
			return "Hidden Key: " .. (backpackTool("Hidden Key") and "✔ have key" or "no key yet") .. "  •  from Ice Castle mobs"
		end)
		T:Toggle("Auto Dragon Trident (Tide Keeper)", "AutoTrident", stopOff)
		T:Button("Go to El Admin (Midnight Blade, 100 Ectoplasm)", function()
			goTo(CFrame.new(POS.ElAdmin + Vector3.new(0, 3, 4)))
			notify("Midnight Blade", "Click El Admin and buy it (100 Ectoplasm)", 6)
		end)
		T:Section("True Triple Katana")
		T:Label(function()
			return "Sword Dealer: " .. (dealerPosition() and "<font color=\"#7CFF9B\">SPAWNED</font>" or "not spawned")
		end)
		T:Toggle("Sword Dealer Spawn Alert", "DealerNotify")
		T:Toggle("Auto Buy Legendary Sword ($2M each)", "AutoLegendary")
		T:Label(function()
			local have = {}
			for _, sw in ipairs({ "Shisui", "Saddi", "Wando" }) do table.insert(have, sw .. (hasItem(sw) and " ✔" or " ✖")) end
			return table.concat(have, "   ")
		end)
		T:Button("Go to Legendary Sword Dealer", function()
			local cf = dealerPosition()
			if not cf then return notify("Sword Dealer", "Not spawned right now") end
			goTo(cf * CFrame.new(0, 0, 4))
		end)
		T:Button("Go to Mysterious Man (TTK)", function()
			goTo(CFrame.new(POS.MysteriousMan + Vector3.new(0, 3, 4)))
		end)
		T:Label(function() return "TTK: Saddi + Shisui + Wando (300 mastery each) + $2M" end)
	elseif Sea == 3 then
		T:Section("Farms")
		T:Toggle("Auto Elite Hunter", "AutoElite", stopOff)
		T:Toggle("Auto Yama (after 30 elites)", "AutoYama", stopOff)
		T:Label(function() return "Elite progress: " .. tostring(invokeCached("eliteProg", 20, "EliteHunter", "Progress") or "?") .. "/30" end)
		T:Toggle("Auto Bone (Haunted Castle, mummy quest)", "AutoBone", stopOff)
		T:Toggle("Auto Bone Gamble (50 bones each)", "AutoBoneGamble")
		T:Label(function() return "Bones: " .. formatNumber(materialCount("Bones")) .. "  (gamble trades while Auto Bone is on)" end)
		T:Toggle("Auto Cake Prince (cake mobs + boss)", "AutoCake", stopOff)
		T:Label(function() return "Cake Prince: " .. tostring(invokeCached("cakeSpawner", 20, "CakePrinceSpawner") or "?") end)
		T:Section("Items & Progress")
		T:Toggle("Auto Tushita (Lv 2200+)", "AutoTushita", stopOff)
		T:Toggle("Auto CDK (Yama + Tushita 350 mastery)", "AutoCDK", stopOff)
		T:Toggle("Auto Soul Guitar (full moon, spends mats)", "AutoSoulGuitar", stopOff)
	else
		T:Label(function() return "Sea not detected — rejoin or tell Claude the PlaceId" end)
	end
end

-- Sea Events: فقط دریای 2 و 3
if Sea == 2 or Sea == 3 then
	local T = createTab("Sea Events", "⚓")
	T:Section("Sea Beasts")
	T:Toggle("Auto Sea Beast (fly over it + skills)", "AutoSeaBeast", stopOff)
	T:Dropdown("Sea Beast Weapon", function() return { "Blox Fruit", "Sword", "Gun", "Melee" } end, "SeaBeastWeapon")
	T:Label(function()
		local f = workspace:FindFirstChild("SeaBeasts")
		return "Sea Beasts in server: " .. (f and #f:GetChildren() or 0)
	end)
	if Sea == 3 then
		T:Section("Pirate Raid (Castle on the Sea)")
		T:Toggle("Auto Pirate Raid (kill raiders at Castle)", "AutoPirateRaid", stopOff)
		T:Section("World Events")
		T:Toggle("Event Spawn Alert", "EventNotify")
		T:Label(function()
			local names = {}
			for _, obj in pairs(Hub.Events) do table.insert(names, obj.Name) end
			local full = false
			pcall(function()
				full = Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431" and (Lighting.ClockTime > 16 or Lighting.ClockTime < 5)
			end)
			return "Events: " .. (#names > 0 and table.concat(names, ", ") or "none") .. "  •  Full moon night: " .. (full and "YES" or "no")
		end)
		for _, ev in ipairs({ { "Mirage Island", { "mirage", "mystic" } }, { "Kitsune Island", { "kitsune" } }, { "Prehistoric Island", { "prehistoric" } }, { "Frozen Dimension", { "frozen" } } }) do
			T:Button("Go to " .. ev[1], function()
				local obj
				for _, k in ipairs(ev[2]) do obj = obj or Hub.Events[k] end
				if not obj then return notify(ev[1], "Not spawned in this server") end
				local pos = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
				goTo(CFrame.new(pos + Vector3.new(0, 80, 0)))
			end)
		end
		T:Section("Mirage & Full Moon")
		T:Toggle("Full Moon Alert", "MoonNotify")
		T:Label(function()
			local t = Lighting.ClockTime
			return ("Game time %02d:%02d  •  Full moon night: %s  •  Blue Gear: %s"):format(math.floor(t), math.floor(t % 1 * 60),
				Hub.FullMoonNight() and "YES" or "no", Hub.GearCached() and "FOUND ✔" or "not seen")
		end)
		T:Button("Go to Mirage Highest Point", function()
			local top = Hub.MirageTop()
			if not top then return notify("Mirage", "Mirage Island is not in this server") end
			goTo(CFrame.new(top + Vector3.new(0, 4, 0)))
		end)
		T:Button("Go to Blue Gear", function()
			local g = Hub.FindGear()
			if not g then return notify("Mirage", Hub.MirageModel() and "Gear not found (press Scan Mirage and tell me)" or "Mirage Island is not in this server", 6) end
			goTo(g.CFrame * CFrame.new(0, 4, 0))
		end)
		T:Button("Scan Mirage (writes bmscan/mirage.txt)", function()
			local n = Hub.DumpMirage()
			notify("Mirage", n and ("Saved " .. n .. " objects") or "Mirage Island is not in this server", 5)
		end)
	end
end

-- Bosses
do
	local T = createTab("Bosses", "♛")
	T:Section("Auto Boss (" .. SEA_NAME .. ")")
	T:Dropdown("Select Boss", bossOptions, "SelectedBoss")
	T:Toggle("Auto Farm Boss", "AutoBoss", stopOff)
	T:Toggle("Take Boss Quest", "BossQuest")
	T:Toggle("Auto All Bosses (nearest spawned first)", "AutoAllBosses", stopOff)
	T:Toggle("Boss Spawn Alert", "BossNotify")
	local anySpecial = false
	for _, b in ipairs(Hub.Special or {}) do
		if b.sea == Sea then
			if not anySpecial then T:Section("Special Bosses") anySpecial = true end
			T:Toggle("Auto Kill " .. b.label, "Kill" .. b.id, stopOff)
			if b.summon then
				T:Toggle("Auto Summon " .. b.label .. (b.cost and (" (uses " .. b.cost .. "!)") or " (farms cake mobs)"), "Summon" .. b.id, stopOff)
			end
			T:Label(function()
				local n = Hub.SpecialSpawned(b)
				local need = b.cost and ("  •  " .. b.cost .. ": " .. (b.ready() and "✔" or "✖")) or ""
				return b.label .. ": " .. (n and "SPAWNED ✔" or "not spawned") .. need
			end)
		end
	end
	if Sea == 2 then
		T:Section("Darkbeard")
		T:Toggle("Auto Darkbeard (summon + fight)", "AutoDarkbeard", stopOff)
		T:Label(function()
			return "Fist of Darkness: " .. (backpackTool("Fist of Darkness") and "✔ have it" or "✖ (get from chests)")
		end)
	end
	T:Section("Spawned & Locations")
	T:Button("List Spawned Bosses", function()
		local alive_ = {}
		for _, n in ipairs(bossNames()) do
			if findMobAnywhere(n) then table.insert(alive_, n) end
		end
		notify("Spawned Bosses (" .. #alive_ .. ")", #alive_ > 0 and table.concat(alive_, ", ") or "None right now", 7)
	end)
	T:Dropdown("Boss Spawn", function()
		local out = {}
		for _, b in ipairs(bossSpawns()) do table.insert(out, b.name) end
		return out
	end, "SelectedBossSpawn")
	T:Button("Teleport to Boss Spawn", function()
		for _, b in ipairs(bossSpawns()) do
			if b.name == S.SelectedBossSpawn then return goTo(b.cf * CFrame.new(0, 40, 0)) end
		end
		notify("Boss", "Select a boss spawn first")
	end)
end

-- Items: میوه، صندوق، بری، کلکسیون همین دریا
do
	local T = createTab("Items", "◆")
	T:Section("Devil Fruits")
	T:Toggle("Auto Collect Fruits", "AutoFruit", function(on) if not on then stopTween() end end)
	T:Toggle("Auto Store Fruits", "AutoStore")
	T:Toggle("Fruit Spawn Alert", "FruitNotify")
	T:Toggle("Auto Random Fruit (spends beli!)", "AutoRandomFruit", function(on)
		if on then Hub.FruitBuys = 0 end
	end)
	T:Slider("Keep At Least Beli (x1000)", 0, 5000, "FruitMinBeliK", function(v) S.FruitMinBeli = v * 1000 end)
	T:Slider("Max Fruits Per Run", 1, 20, "FruitMaxBuys")
	T:Button("Buy Random Fruit", function()
		local _, info = buyRandomFruit()
		notify("Random Fruit", info, 6)
	end)
	T:Button("Find Fruits In Server", function()
		local list = getWorldFruits()
		if #list == 0 then return notify("Fruits", "No fruits spawned") end
		local names = {}
		for _, f in ipairs(list) do table.insert(names, f.obj.Name) end
		notify("Fruits (" .. #list .. ")", table.concat(names, ", "), 6)
	end)
	T:Section("Chests & Berries")
	T:Toggle("Auto Chest", "AutoChest", function(on) if not on then stopTween() end end)
	T:Toggle("Auto Collect Berries", "AutoBerries", function(on) if not on then stopTween() end end)
	T:Label(function() return "Berry bushes loaded: " .. #CollectionService:GetTagged("BerryBush") end)
	-- کلکسیون: آیتم‌های مهم همین دریا که داری / نداری
	local COLLECTION = {
		[1] = { "Saber", "Pole (1st Form)", "Gravity Cane", "Trident", "Warden's Sword", "Longsword", "Bisento", "Soul Cane", "Shark Saw", "Jitte" },
		[2] = { "Rengoku", "Dragon Trident", "Midnight Blade", "True Triple Katana", "Koko", "Dual-Headed Blade", "Kabucha", "Bizarre Revolver", "Acidum Rifle" },
		[3] = { "Yama", "Tushita", "Cursed Dual Katana", "Hallow Scythe", "Shark Anchor", "Canvander", "Buddy Sword", "Twin Hooks", "Spikey Trident", "Dark Dagger", "Skull Guitar", "Fox Lamp", "Venom Bow", "Dragonstorm" },
	}
	local list = COLLECTION[Sea]
	if list then
		T:Section("Collection (" .. SEA_NAME .. ")")
		local function missing()
			local out = {}
			for _, item in ipairs(list) do
				if not hasItem(item) then table.insert(out, item) end
			end
			return out
		end
		T:Label(function()
			local m = #missing()
			return ("<font color=\"%s\">%d/%d owned</font>"):format(m == 0 and "#7CFF9B" or "#FFD166", #list - m, #list)
		end)
		T:Dropdown("Missing", function()
			local m = missing()
			return #m > 0 and m or { "Nothing missing ✔" }
		end, "ViewMissingSea" .. Sea)
	end
end

-- Combat: تنظیمات حمله، هاکی، پرواز
do
	local T = createTab("Combat", "⚔")
	T:Section("Weapon & Attack")
	T:Dropdown("Farm Weapon", function() return { "Melee", "Sword", "Blox Fruit", "Gun" } end, "Weapon")
	T:Dropdown("Attack Method", function() return { "Auto", "Remote", "Click", "Tool" } end, "AttackMethod")
	T:Toggle("Auto Click (attacks with the weapon in your hand)", "AutoClick")
	T:Toggle("Fast Attack (faster normal clicks)", "FastAttack")
	T:Slider("Attack Range", 10, 150, "AttackRange")
	T:Toggle("Bring Mobs", "BringMobs")
	T:Button("Attack Test (stand next to a mob, hold your weapon)", function()
		-- هر روش کلیک رو 4 ثانیه امتحان می‌کنه و کم شدن جون ماب رو توی لاگ می‌نویسه
		task.spawn(function()
			local log = Hub.LiveLog or print
			local root, char = getRoot(), getChar()
			local tool = char and char:FindFirstChildOfClass("Tool")
			local best, bestD
			for _, m in ipairs(workspace.Enemies:GetChildren()) do
				if isAliveMob(m) then
					local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
					if not bestD or d < bestD then best, bestD = m, d end
				end
			end
			if not tool or not best or bestD > 12 then
				return notify("Attack Test", "Hold a weapon and stand within 10 studs of a mob", 5)
			end
			local savedClick = S.AutoClick
			S.AutoClick = false
			local vs = camera.ViewportSize
			-- یه نقطه از صفحه که هیچ UI روش نیست
			local free = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
			local pg = player:FindFirstChild("PlayerGui")
			for _, pt in ipairs({ { 0.5, 0.5 }, { 0.5, 0.35 }, { 0.3, 0.5 }, { 0.7, 0.6 }, { 0.5, 0.75 } }) do
				local v = Vector2.new(vs.X * pt[1], vs.Y * pt[2])
				local ok, objs = pcall(function() return pg:GetGuiObjectsAtPosition(v.X, v.Y) end)
				if ok and #objs == 0 then free = v break end
			end
			local methods = {
				{ "tool:Activate()", function() tool:Activate() end },
				{ "VirtualUser click", function()
					Svc.VirtualUser:CaptureController()
					Svc.VirtualUser:Button1Down(free, camera.CFrame)
					task.wait(0.03)
					Svc.VirtualUser:Button1Up(free, camera.CFrame)
				end },
				{ "VirtualInputManager click", function()
					VIM:SendMouseButtonEvent(free.X, free.Y, 0, true, game, 0)
					task.wait(0.03)
					VIM:SendMouseButtonEvent(free.X, free.Y, 0, false, game, 0)
				end },
			}
			log(("ATTACK TEST start: tool=%s[%s] mob=%s dist=%d freeClick=(%d,%d)"):format(tool.Name, tostring(tool.ToolTip), mobBaseName(best.Name), math.floor(bestD), free.X, free.Y))
			notify("Attack Test", "Testing 3 methods (12 s)... don't touch the mouse", 5)
			for _, m in ipairs(methods) do
				local h = best:FindFirstChildOfClass("Humanoid")
				if not h or h.Health <= 0 then break end
				local before, err = h.Health, "ok"
				local t0 = tick()
				while tick() - t0 < 4 do
					local r = getRoot()
					local p = best.HumanoidRootPart.Position
					if r then r.CFrame = CFrame.lookAt(r.Position, Vector3.new(p.X, r.Position.Y, p.Z)) end
					local ok, e = pcall(m[2])
					if not ok then err = tostring(e) end
					task.wait(0.25)
				end
				log(("ATTACK TEST %s: hp %d -> %d (%s) err=%s"):format(m[1], math.floor(before), math.floor(h.Health), h.Health < before and "DAMAGE ✔" or "no damage", err))
			end
			S.AutoClick = savedClick
			notify("Attack Test", "Done ✔ - tell Claude", 6)
		end)
	end)
	T:Section("Haki & Race")
	T:Toggle("Auto Haki (Buso)", "AutoHaki")
	T:Toggle("Auto Observation (Ken)", "AutoKen")
	T:Toggle("Auto Race Skill (T)", "AutoRace")
	T:Section("Movement")
	T:Slider("Farm Height (0-6, higher = no hits)", 0, 6, "FarmDistance")
	T:Slider("Tween Speed (max 300 safe)", 100, 300, "TweenSpeed")
end

-- Shop
do
	local T = createTab("Shop", "$")
	T:Section("Codes")
	T:Button("Redeem All Codes", function()
		notify("Codes", "Redeeming " .. #CODES .. " codes...", 3)
		local n, err = redeemAllCodes()
		notify("Codes", err or ("Sent " .. n .. " codes ✔ (expired ones are ignored)"), 5)
	end)
	T:Section("Fighting Styles")
	T:Dropdown("Style", styleNames, "SelectedStyle")
	T:Button("Buy Selected Style", function()
		if not S.SelectedStyle then return notify("Shop", "Select a style first") end
		local r = buyStyle(S.SelectedStyle)
		notify(S.SelectedStyle, r ~= nil and tostring(r) or "Request sent (need beli/fragments + requirements)", 5)
	end)
	T:Toggle("Auto Next Fighting Style (spends!)", "AutoStyles", stopOff)
	T:Section("Abilities & Haki")
	T:Toggle("Auto Buy Buso / Geppo / Soru (when affordable)", "AutoAbilities")
	T:Toggle("Auto Buy Haki Color (spends beli!)", "AutoHakiColor")
	T:Label(function() return "Haki color keeps at least " .. formatNumber(S.FruitMinBeli) .. " beli (Items tab slider)" end)
	T:Toggle("Auto Awaken Fruit (spends fragments!)", "AutoAwaken")
	for _, b in ipairs({
		{ "Buy Geppo (Sky Jump)", { { "BuyHaki", "Geppo" } } },
		{ "Buy Buso Haki", { { "BuyHaki", "Buso" } } },
		{ "Buy Soru (Flash Step)", { { "BuyHaki", "Soru" } } },
		{ "Buy Observation (Ken)", { { "KenTalk", "Start" }, { "KenTalk", "Buy" } } },
		{ "Buy Random Haki Color", { { "ColorsDealer", "2" } } },
	}) do
		T:Button(b[1], function()
			local r
			for _, a in ipairs(b[2]) do
				r = invoke(table.unpack(a))
				task.wait(0.2)
			end
			notify(b[1], r ~= nil and tostring(r) or "Request sent", 4)
		end)
	end
end

-- Teleport
do
	local T = createTab("Teleport", "➤")
	-- مکان‌های مهم هر Sea (مختصات از اسکن خود بازی)
	local QUICK_PLACES = {
		[2] = {
			{ "Cafe", Vector3.new(-380.4, 72.8, 303.2) },
			{ "Kingdom of Rose", Vector3.new(-195.1, 155.3, 279.9) },
			{ "Mansion", Vector3.new(-393.3, 367.3, 687.5) },
			{ "Dark Arena (Darkbeard)", Vector3.new(3807.1, 11.8, -3452.2) },
			{ "Factory", Vector3.new(431.0, 238.4, -433.2) },
			{ "Colosseum", Vector3.new(-1836.4, 72.8, 1360.2) },
			{ "Green Zone", Vector3.new(-2340.8, 155.3, -3396.3) },
			{ "Graveyard Island", Vector3.new(-5577.9, 87.6, -782.2) },
			{ "Snow Mountain", Vector3.new(856.2, 50.3, -5278.3) },
			{ "Hot and Cold", Vector3.new(-5734.3, 49.4, -5146.4) },
			{ "Ice Castle", Vector3.new(6062.3, 155.3, -6880.9) },
			{ "Forgotten Island", Vector3.new(-3194.2, 155.3, -10795.3) },
		},
		[3] = {
			{ "Castle on the Sea", Vector3.new(-5027.0, 316.5, -3206.7) },
			{ "Mansion", Vector3.new(-12463.6, 378.3, -7566.1) },
			{ "Hydra Island", Vector3.new(5650.9, 1017.3, -350.4) },
			{ "Port Town", Vector3.new(-290.1, 42.9, 5581.6) },
			{ "Great Tree", Vector3.new(2180.5, 27.8, -6741.6) },
			{ "Floating Turtle", Vector3.new(-13234.0, 331.5, -7625.4) },
			{ "Haunted Castle", Vector3.new(-9515.0, 164.0, 5786.0) },
			{ "Sea of Treats (Cake)", Vector3.new(-2021.3, 37.8, -12028.7) },
			{ "Peanut / Ice Cream Island", Vector3.new(-820.7, 65.8, -10965.8) },
			{ "Chocolate Island", Vector3.new(233.2, 29.9, -12201.2) },
			{ "Tiki Outpost", Vector3.new(-16547.8, 61.1, -173.4) },
		},
	}
	if QUICK_PLACES[Sea] then
		T:Section("Quick Places (" .. SEA_NAME .. ")")
		for _, place in ipairs(QUICK_PLACES[Sea]) do
			T:Button(place[1], function()
				goTo(CFrame.new(place[2] + Vector3.new(0, 40, 0)))
			end)
		end
	end
	T:Section("Islands")
	T:Dropdown("Island", islandList, "SelectedIsland")
	T:Button("Teleport to Island", function()
		if not S.SelectedIsland then return notify("Teleport", "Select an island first") end
		goTo(islandCFrame(S.SelectedIsland))
	end)
	T:Section("NPCs & Players")
	T:Dropdown("NPC", npcList, "SelectedNPC")
	T:Button("Teleport to NPC", function()
		local cf = S.SelectedNPC and findNPC(S.SelectedNPC)
		if not cf then return notify("Teleport", "NPC not found") end
		goTo(cf * CFrame.new(0, 0, 4))
	end)
	T:Dropdown("Player", playerList, "SelectedPlayer")
	T:Button("Teleport to Player", function()
		local p = S.SelectedPlayer and Players:FindFirstChild(S.SelectedPlayer)
		local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not r then return notify("Teleport", "Player not found") end
		goTo(r.CFrame * CFrame.new(0, 5, 0))
	end)
	T:Button("Stop Teleport", function() stopTween() end)
	T:Section("Server Finder (hops servers until found)")
	T:Dropdown("Find", Hub.HuntTargets, "HuntTarget")
	T:Toggle("Server Hop Until Found", "HuntHop", function(on)
		if not on then return end
		if not S.HuntTarget then
			S.HuntHop = false
			return notify("Server Finder", "Pick what to find first")
		end
		Hub.HuntReset()
		if not Hub.CanQueue then
			notify("Server Finder", "Your executor can't auto re-run after hop: put the loader in its autoexec folder", 10)
		end
	end)
	T:Toggle("Fly To It When Found", "HuntGoTo")
	T:Slider("Seconds To Check Each Server", 5, 60, "HuntWait")
	T:Slider("Max Hops", 5, 200, "HuntMaxHops")
	T:Label(function() return "Finder: " .. tostring(Hub.HuntStatus) end)
	T:Label(function() return "Auto re-run after hop: " .. (Hub.CanQueue and "YES" or "NO (use autoexec)") end)
	T:Section("Travel Between Seas")
	for i, cmd in ipairs({ "TravelMain", "TravelDressrosa", "TravelZou" }) do
		if i ~= Sea then T:Button("Travel to Sea " .. i, function() invoke(cmd) end) end
	end
end

-- Stats
do
	local T = createTab("Stats", "▲")
	T:Section("Auto Stats")
	T:Dropdown("Stat", function() return { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType")
	T:Dropdown("Split With", function() return { "None", "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType2")
	T:Slider("Points Per Tick", 1, 100, "StatAmount")
	T:Toggle("Auto Stats", "AutoStats")
end

-- ESP
do
	local T = createTab("ESP", "◉")
	T:Section("ESP")
	T:Toggle("Player ESP", "PlayerESP")
	T:Toggle("Fruit ESP", "FruitESP")
	T:Toggle("Chest ESP", "ChestESP")
	T:Toggle("Boss ESP", "BossESP")
	T:Toggle("Mob ESP (nearest 40)", "MobESP")
	T:Toggle("NPC ESP", "NPCESP")
	T:Toggle("Island ESP", "IslandESP")
	T:Toggle("World Event + Blue Gear ESP", "EventESP")
end

-- Misc
do
	local T = createTab("Misc", "✦")
	T:Section("Team")
	T:Dropdown("Team", function() return { "Pirates", "Marines" } end, "TeamChoice")
	T:Toggle("Auto Pick Team", "AutoTeam")
	T:Section("Player")
	T:Toggle("WalkSpeed", "SpeedOn", function(on)
		if not on then local h = getHum() if h then h.WalkSpeed = 16 end end
	end)
	T:Slider("Speed", 16, 300, "WalkSpeed")
	T:Toggle("JumpPower", "JumpOn", function(on)
		if not on then local h = getHum() if h then h.JumpPower = 50 end end
	end)
	T:Slider("Jump", 50, 300, "JumpPower")
	T:Toggle("Infinite Jump", "InfJump")
	T:Toggle("Noclip", "Noclip")
	T:Toggle("Walk on Water", "WalkOnWater")
	T:Section("Visual")
	T:Toggle("Fullbright (always bright)", "Fullbright")
	T:Toggle("No Fog", "NoFog")
	T:Section("Server")
	T:Toggle("Anti AFK", "AntiAFK")
	T:Button("Server Hop", function()
		if not serverHop() then notify("Server Hop", "No server found") end
	end)
	T:Button("Hop to Low Player Server", function()
		if not serverHop(true) then notify("Server Hop", "No server found") end
	end)
	T:Toggle("Auto Hop When Player Near", "AutoHopNear")
	T:Slider("Hop Distance", 50, 1000, "HopDistance")
	T:Button("Rejoin", function() Svc.Teleport:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
	T:Toggle("Auto Rejoin On Kick", "AutoRejoin")
	T:Section("Performance")
	T:Button("FPS Boost", function()
		fpsBoost()
		notify("FPS Boost", "Done ✔")
	end)
	T:Toggle("CPU Saver (no 3D render)", "CPUSaver", function(on)
		pcall(function() RunService:Set3dRenderingEnabled(not on) end)
	end)
	T:Toggle("FPS Cap", "FPSCapOn", function(on)
		if not setfpscap then return notify("FPS Cap", "Executor has no setfpscap") end
		setfpscap(on and S.FPSCap or 0)
	end)
	T:Slider("Max FPS", 10, 120, "FPSCap", function(v)
		if S.FPSCapOn and setfpscap then pcall(setfpscap, v) end
	end)
	T:Section("Settings")
	T:Toggle("Auto Save Settings", "AutoSave")
	T:Button("Save Settings", function()
		notify("Settings", saveSettings() and "Saved ✔" or "Save failed (executor has no writefile)", 3)
	end)
	T:Button("Load Settings", function()
		notify("Settings", loadSettings() and "Loaded ✔  re-run the hub to refresh the UI" or "No saved settings", 4)
	end)
	T:Button("Destroy Hub", function() Hub.Destroy() end)
end
end -- صفحه‌ها

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------
do
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
			if S.BossESP then
				local enemies = workspace:FindFirstChild("Enemies")
				local names = {}
				for _, n in ipairs(bossNames()) do names[n] = true end
				if enemies then
					for _, m in ipairs(enemies:GetChildren()) do
						local base = mobBaseName(m.Name)
						if names[base] and isAliveMob(m) then
							local h = m:FindFirstChildOfClass("Humanoid")
							local pct = math.floor(h.Health / math.max(h.MaxHealth, 1) * 100)
							espSet(m, m.HumanoidRootPart, ("👑 %s  %d%%  %dm"):format(base, pct, dist(m.HumanoidRootPart)), Color3.fromRGB(255, 140, 60))
						end
					end
				end
			end
			if S.ChestESP then
				for i, c in ipairs(getChests()) do
					if i > 40 then break end
					espSet(c, c, ("%s  %dm"):format(c.Name, dist(c)), Color3.fromRGB(255, 210, 90))
				end
			end
			if S.MobESP then
				local enemies = workspace:FindFirstChild("Enemies")
				local bosses, mobs = {}, {}
				for _, n in ipairs(bossNames()) do bosses[n] = true end
				for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
					if isAliveMob(m) and not bosses[mobBaseName(m.Name)] then table.insert(mobs, { m = m, d = dist(m.HumanoidRootPart) }) end
				end
				table.sort(mobs, function(a, b) return a.d < b.d end)
				for i, e in ipairs(mobs) do
					if i > 40 then break end
					local h = e.m:FindFirstChildOfClass("Humanoid")
					local pct = math.floor(h.Health / math.max(h.MaxHealth, 1) * 100)
					espSet(e.m, e.m.HumanoidRootPart, ("%s  %d%%  %dm"):format(mobBaseName(e.m.Name), pct, e.d), Color3.fromRGB(230, 230, 240))
				end
			end
			if S.NPCESP then
				local npcs = workspace:FindFirstChild("NPCs")
				for _, n in ipairs(npcs and npcs:GetChildren() or {}) do
					local part = n:IsA("Model") and (n:FindFirstChild("HumanoidRootPart") or n.PrimaryPart)
					if part and dist(part) <= 3000 then
						espSet(n, part, ("💬 %s  %dm"):format(n.Name, dist(part)), Color3.fromRGB(130, 200, 255))
					end
				end
			end
			if S.IslandESP then
				local wo = workspace:FindFirstChild("_WorldOrigin")
				local loc = wo and wo:FindFirstChild("Locations")
				for _, p in ipairs(loc and loc:GetChildren() or {}) do
					if p:IsA("BasePart") then espSet(p, p, ("🏝 %s  %dm"):format(p.Name, dist(p)), Color3.fromRGB(110, 230, 230)) end
				end
			end
			if S.EventESP then
				for _, obj in pairs(Hub.Events) do
					local part = obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
					if part then espSet(obj, part, ("🌟 %s  %dm"):format(obj.Name, dist(part)), Color3.fromRGB(255, 120, 230)) end
				end
				local g = Hub.GearCached()
				if g then espSet(g, g, ("⚙ Blue Gear  %dm"):format(dist(g)), Color3.fromRGB(80, 160, 255)) end
			end
			for k, e in pairs(ESP) do
				if not e.seen then
					e.gui:Destroy()
					ESP[k] = nil
				end
			end
		end)
		for _, sync in ipairs(toggleSyncers) do pcall(sync) end
		for _, d in ipairs(dynamicLabels) do
			pcall(function() d.label.Text = d.fn() end)
		end
	end
end)

end -- ESP

---------------------------------------------------------------------
-- Window behaviour
---------------------------------------------------------------------
do
local minimized = false
-- وضعیت باز/بسته جدا نگه داشته میشه تا کلیک وسط انیمیشن قاطی نکنه
local isOpen = false
local showToken = 0
local function showMain(show)
	isOpen = show
	showToken += 1
	local token = showToken
	if show then
		main.Visible = true
		tween(main, 0.45, { Size = minimized and UDim2.fromOffset(FULL.X.Offset, 50) or FULL }, Enum.EasingStyle.Back)
	else
		tween(main, 0.3, { Size = UDim2.fromOffset(0, 0) })
		task.delay(0.32, function()
			if token == showToken and not isOpen then main.Visible = false end
		end)
	end
end
local function toggleMain() showMain(not isOpen) end

minBtn.Activated:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "–"
	tween(main, 0.35, { Size = minimized and UDim2.fromOffset(FULL.X.Offset, 50) or FULL })
end)
closeBtn.Activated:Connect(function() showMain(false) end)

local function makeDraggable(handle, target, onClick)
	local dragging, startPos, startInput, moved
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			startInput, startPos = i.Position, target.Position
			local conn
			conn = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					conn:Disconnect()
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
-- خود دایره دکمه‌ست (نه Frame با متن روش) تا کلیک/تاچ همیشه بهش برسه
local floatBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 60, 0.3, 0), Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Active = true, Visible = false, ZIndex = 50,
	Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = "BM", Parent = root,
}, { corner(26) })
animated(gradient(), 120).Parent = floatBtn
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = floatBtn })
applyLogo(floatBtn)
local floatScale = new("UIScale", { Parent = floatBtn })
makeDraggable(floatBtn, floatBtn, function()
	floatScale.Scale = 0.85
	tween(floatScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	toggleMain()
end)

connect(UserInputService.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then toggleMain() end
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
	local bigLogoImg = applyLogo(bigLogo)
	if bigLogoImg then
		bigLogo.Size = UDim2.fromOffset(56, 56)
		bigLogo.Position = UDim2.new(0.5, 0, 0, 10)
		bigLogoImg.ImageTransparency = 1
	end
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
	tween(bigLogo, fade, { BackgroundTransparency = bigLogoImg and 1 or 0 })
	if bigLogoImg then tween(bigLogoImg, fade, { ImageTransparency = 0 }) end
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
		if o:IsA("ImageLabel") then tween(o, 0.4, { ImageTransparency = 1 }) end
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
end -- پنجره و صفحه‌ی خوش‌آمد

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
	pcall(function() RunService:Set3dRenderingEnabled(true) end)
	for _, c in ipairs(Hub.Connections) do pcall(function() c:Disconnect() end) end
	pcall(function() root:Destroy() end)
	pcall(function() espFolder:Destroy() end)
end
