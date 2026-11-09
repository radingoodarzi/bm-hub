--[[
	BM Hub  -  Blox Fruits
	Executors: Solara / Delta (PC + Mobile)

	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()

	کلید RightControl یا دکمه‌ی شناور BM = باز/بسته کردن پنل
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if genv.BMHub and genv.BMHub.Destroy then pcall(genv.BMHub.Destroy) end
local Hub = { Connections = {}, Running = true, Version = "5.7" }
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

local Modules = ReplicatedStorage:WaitForChild("Modules", 20)
local Net = Modules and Modules:WaitForChild("Net", 20)

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
-- اگه هنوز پیدا نشدن (یا بازی عوضشون کرد) هر 2 ثانیه دوباره گشته میشه
local remotesCheckedAt = 0
local function attackRemotes()
	if RegisterAttack and RegisterAttack.Parent and RegisterHit and RegisterHit.Parent then return true end
	Hub.AttackInfo.lastError = "attack remotes not found yet"
	if tick() - remotesCheckedAt < 2 then return false end
	remotesCheckedAt = tick()
	if not Net then
		Modules = ReplicatedStorage:FindFirstChild("Modules")
		Net = Modules and Modules:FindFirstChild("Net")
	end
	RegisterAttack, RegisterHit = findRemote("RegisterAttack"), findRemote("RegisterHit")
	if RegisterAttack and RegisterHit then return true end
	Hub.AttackInfo.lastError = "attack remotes not found yet"
	return false
end

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
	BringMobs = true, Weapon = "Melee", AttackMethod = "Auto",
	FarmHeight = 25, TweenSpeed = 300, AutoClick = true, AttackRange = 60, BringRange = 300, BringMax = 15, AutoPumpkin = false, PumpkinPattern = "pumpkin",

	MasteryFarm = false, MasteryWeapon = "Blox Fruit", MasteryHealth = 25,
	UseSkills = true, SkillZ = true, SkillX = true, SkillC = false, SkillV = false,
	AutoFactory = false, AutoEcto = false, AutoRengoku = false, AutoTrident = false, DealerNotify = true, AutoLegendary = false, AutoAllBosses = false,
	AutoRaid = false, AutoBuyChip = false, RaidType = "Flame", AutoDarkbeard = false,
	AutoTeam = true, TeamChoice = "Pirates", AutoSea2 = false, AutoBartilo = false, AutoSea3 = false, AutoSaber = false,
	AutoElite = false, AutoYama = false, AutoBone = false, AutoCake = false, AutoSeaBeast = false, SeaBeastWeapon = "Blox Fruit",
	AutoBoneGamble = false, AutoAbilities = false, AutoPirateRaid = false, EventNotify = true, AutoAwaken = false, AutoHakiColor = false, AutoMaterial = false, Material = nil, AutoRetreat = true, RetreatHP = 35,
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
	Noclip = false, InfJump = false, AntiAFK = true, WalkOnWater = true, AutoBerries = false, Fullbright = false, NoFog = false,
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
	return S.AutoFarm or S.AutoPumpkin or S.AutoBoss or S.AutoFactory or S.AutoEcto or S.AutoRengoku or S.AutoTrident or S.AutoAllBosses or S.AutoRaid or S.AutoDarkbeard
		or S.AutoSea2 or S.AutoBartilo or S.AutoSea3 or S.AutoSaber
		or S.AutoElite or S.AutoYama or S.AutoBone or S.AutoCake or S.AutoSeaBeast or S.AutoPirateRaid or S.AutoMaterial
		or S.AutoTushita or S.AutoCDK or S.AutoRaceV2 or S.AutoRaceV3 or S.AutoSoulGuitar or S.AutoStyles
		or (Hub.SpecialAny ~= nil and Hub.SpecialAny())
		or (Hub.V3Busy ~= nil and Hub.V3Busy())
end

local function anyFarm()
	return S.AutoFarm or S.AutoPumpkin or S.AutoBoss or S.AutoChest or S.AutoFruit or S.AutoFactory or S.AutoEcto
		or S.AutoRengoku or S.AutoTrident or S.AutoAllBosses or S.AutoRaid or S.AutoDarkbeard or S.AutoBerries
		or S.AutoSea2 or S.AutoBartilo or S.AutoSea3 or S.AutoSaber
		or S.AutoElite or S.AutoYama or S.AutoBone or S.AutoCake or S.AutoSeaBeast or S.AutoPirateRaid or S.AutoMaterial
		or S.AutoTushita or S.AutoCDK or S.AutoRaceV2 or S.AutoRaceV3 or S.AutoSoulGuitar or S.AutoStyles
		or (Hub.SpecialAny ~= nil and Hub.SpecialAny())
		or (Hub.V3Busy ~= nil and Hub.V3Busy())
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
	-- هر فریم از جای «واقعی» کاراکتر یه قدم به مقصد میریم (نه Tween ثابت): اگه سرور برگردوندمون
	-- (rubber-band) از همونجا ادامه میدیم، به جای اینکه هی جلوتر بذاریم و دوباره برگردیم
	local cancelled = false
	local handle = { Cancel = function() cancelled = true end }
	activeTween = handle
	local goal = cf.Position
	local speed = math.clamp(S.TweenSpeed, 50, MAX_SAFE_SPEED)
	local expected, snaps = root.Position, 0
	while not cancelled do
		if (keepGoing and not keepGoing()) or not alive() or not Hub.Running then break end
		root = getRoot()
		if not root then break end
		local dt = math.min(task.wait(), 0.1)
		local pos = root.Position
		if (pos - expected).Magnitude > 1000 then
			break -- بازی تلپورتمون کرد؛ مسیر قبلی دیگه معنی نداره
		end
		if (pos - expected).Magnitude > 25 then
			-- سرور برگردوندمون: کندتر میشیم، یه مکث کوتاه میکنیم و از جای فعلی ادامه میدیم
			snaps += 1
			if snaps > 6 then break end
			speed = math.max(60, speed * 0.7)
			S.Status = ("Server pushed back (%d) - slowing down"):format(snaps)
			task.wait(0.4)
			root = getRoot()
			if not root then break end
			pos = root.Position
		end
		local remaining = goal - pos
		local step = speed * dt
		if remaining.Magnitude <= step + 1 then
			root.CFrame = cf
			break
		end
		local nextPos = pos + remaining.Unit * step
		root.CFrame = CFrame.new(nextPos) * root.CFrame.Rotation
		expected = nextPos
	end
	if activeTween == handle then activeTween = nil end
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
	if not txt then
		-- کادر کوئست قبلاً دیده شده بود و الان نیست = کوئست تموم شد؛ بعد از 2.5 ثانیه (برای پرش لحظه‌ای کادر)
		-- دیگه فعال حسابش نمی‌کنیم تا کوئست بعدی زود گرفته بشه
		if Hub.QuestSeen then
			Hub.QuestGoneSince = Hub.QuestGoneSince or tick()
			if tick() - Hub.QuestGoneSince <= 2.5 then return Hub.QuestTakenMob ~= nil end
			Hub.QuestTakenMob, Hub.QuestSeen, Hub.QuestGoneSince = nil, false, nil
			return false
		end
		-- کادر کوئست پیدا نشد ولی سرور گفت قبول شد (0) → تا 60 ثانیه فعال حسابش می‌کنیم
		return Hub.QuestTakenMob ~= nil and (mob == nil or Hub.QuestTakenMob == mob) and tick() - (Hub.QuestTakenAt or 0) < 60
	end
	Hub.QuestGoneSince = nil
	if Hub.QuestTakenMob then Hub.QuestSeen = true end
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
	task.wait(0.25)
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
			Hub.QuestSeen, Hub.QuestGoneSince = false, nil
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
	if not attackRemotes() then return end
	if tick() - cooldown.remote < 0.1 then return end
	cooldown.remote = tick()
	-- نزدیک‌ترین ماب اولِ لیسته (هدف اصلی ضربه) و حداکثر 15 هدف توی یه ضربه
	local found, hits = {}, {}
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if d <= math.max(S.AttackRange, S.FarmHeight + 20) then
					table.insert(found, { m = m, d = d })
				end
			end
		end
	end
	table.sort(found, function(a, b) return a.d < b.d end)
	for i = 1, math.min(#found, 15) do
		local m = found[i].m
		table.insert(hits, { m, m:FindFirstChild("Head") or m.HumanoidRootPart })
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
	-- میوه‌ی M1 دار: بدون کلیک روی صفحه و انیمیشن
	local fruit = (m == "Auto" or m == "Remote") and Hub.FruitM1 and Hub.FruitM1(root)
	if fruit then
		-- میوه‌ی شمشیری (melee) ضربه‌ی چندهدفه‌ی ملی می‌خوره، بقیه M1 خودشون؛ هیچ‌کدوم کلیک روی صفحه نداره
		if fruit.melee then remoteAttack(root) end
		return
	end
	if m == "Auto" or m == "Remote" then remoteAttack(root) end
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

-- نزدیک‌ترین ماب زنده داخل Attack Range
local function nearestMobInRange()
	local root = getRoot()
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then return nil end
	local best, bestD
	for _, m in ipairs(enemies:GetChildren()) do
		if isAliveMob(m) then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if d <= S.AttackRange and (not bestD or d < bestD) then best, bestD = m, d end
		end
	end
	return best
end

-- ماب‌های هم‌اسم رو (نزدیک‌ترین‌ها اول، تا BringMax تا و داخل BringRange) روی cf جمع می‌کنه
local lastSimRadius = 0
local function bringMobs(name, cf)
	local enemies = workspace:FindFirstChild("Enemies")
	local root = getRoot()
	if not enemies or not root then return end
	if tick() - lastSimRadius > 2 then
		lastSimRadius = tick()
		pcall(function()
			if sethiddenproperty then sethiddenproperty(player, "SimulationRadius", math.huge) end
		end)
	end
	local list = {}
	for _, m in ipairs(enemies:GetChildren()) do
		local base = mobBaseName(m.Name)
		if (base == name or (Hub.BringGroup and Hub.BringGroup[base])) and isAliveMob(m) then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if d <= S.BringRange then table.insert(list, { m = m, d = d }) end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i = 1, math.min(#list, Hub.BringGroup and math.max(S.BringMax, 15) or S.BringMax) do
		local m = list[i].m
		pcall(function()
			local hrp, hum = m.HumanoidRootPart, m.Humanoid
			hrp.CanCollide = false
			hrp.CFrame = cf
			-- سرعت صفر تا ماب‌ها از جمع فرار نکنن / پرت نشن
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end)
	end
end

-- کلیک خودکار: همیشه به ماب‌های داخل Attack Range حمله می‌کنه، حتی وقتی فارم خاموشه
task.spawn(function()
	while Hub.Running do
		task.wait(0.1)
		if S.AutoClick and alive() and not S.KenFarm and tick() >= (Hub.HoldAttackUntil or 0) then
			local mob = nearestMobInRange()
			if mob then
				pcall(function()
					local held = getChar() and getChar():FindFirstChildOfClass("Tool")
					if not held then
						if not mainFarmBusy() then return end
						equipWeapon()
					end
					-- وقتی فارم روشنه خودش جای کاراکتر و ماب‌ها رو تنظیم می‌کنه؛ وگرنه مثل فارم:
					-- رو به ماب می‌چرخیم و ماب‌ها رو 4 استاد جلوی خودمون میاریم (ضربه فقط از نزدیک ثبت میشه)
					if not mainFarmBusy() then
						local root, p = getRoot(), mob.HumanoidRootPart.Position
						root.CFrame = CFrame.lookAt(root.Position, Vector3.new(p.X, root.Position.Y, p.Z))
						if S.BringMobs then bringMobs(mobBaseName(mob.Name), root.CFrame * CFrame.new(0, 0, -4)) end
					end
					attack()
				end)
			end
		end
	end
end)

local function killMob(mob, keepGoing)
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local hrp = mob:FindFirstChild("HumanoidRootPart")
	local name = mobBaseName(mob.Name)
	local stackAt = hrp and hrp.CFrame
	S.Status = "Farming: " .. name
	if Hub.WatchMob then Hub.WatchMob(mob, hum) end
	local lastHp, lastHit = hum and hum.Health or 0, tick()
	while Hub.Running and keepGoing() and alive() and mob.Parent and hum and hum.Health > 0 do
		local root = getRoot()
		-- جون کم: میریم بالا (بیرون از دسترس ماب‌ها) تا جون برگرده، بعد ادامه
		local me = getHum()
		if S.AutoRetreat and me and me.MaxHealth > 0 and (me.Health / me.MaxHealth * 100 < S.RetreatHP or (Hub.InDanger and Hub.InDanger(me.Health))) then
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
			Hub.LastProgress = lastHit
		elseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120
			and (root.Position.Y - hrp.Position.Y) > 11 and Hub.LowerHeight and Hub.LowerHeight() then
			lastHit = tick()
		elseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120 then
			mobSkipUntil[mob] = tick() + 45
			if Hub.LiveLog then Hub.LiveLog(("SKIP %s for 45s: no damage in 8s, hp=%d dist=%d"):format(name, hum.Health, (root.Position - hrp.Position).Magnitude)) end
			S.Status = "Skipping stuck " .. name
			break
		end
		-- بالای سر ماب‌ها می‌ایستیم (Farm Height) تا بهمون نرسن؛ کمی کنارشون که زاویه‌ی نگاه درست بمونه
		local h = math.min(math.clamp(S.FarmHeight, 0, 100), Hub.HeightCap and Hub.HeightCap() or 100) + (Hub.DodgeY or 0)
		local away = Vector3.new(root.Position.X - hrp.Position.X, 0, root.Position.Z - hrp.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
		local standAt = hrp.Position + away * 3 + Vector3.new(0, h, 0)
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
		if S.BringMobs then bringMobs(name, stackAt or hrp.CFrame) end
		attack(mob)
		if Hub.SmartSkill then Hub.SmartSkill(mob, hum) end
		-- اسکیل‌ها وقتی ماب هنوز پرجونه (دمیج زیاد = زمان کمتر کنار ماب)
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

---------------------------------------------------------------------
-- Halloween: کدوها رو با ملی می‌شکنه و ماب‌هایی که ازشون اسپان میشن رو می‌کشه
-- اسم کدوها رو با Pumpkin Name (پیش‌فرض "pumpkin") توی workspace پیدا می‌کنه
---------------------------------------------------------------------
do
	local cache, skipUntil = { t = 0, list = {} }, setmetatable({}, { __mode = "k" })
	local plog = {}

	local function scan(force)
		if not force and tick() - cache.t < 4 then return cache.list end
		cache.t = tick()
		-- کدوهای واقعی هالووین: Workspace.PumpkinHunt.* (ویژگی PumpkinState / PumpkinHits، تگ M1HitRegistry)
		local hunt = workspace:FindFirstChild("PumpkinHunt")
		if hunt then
			local huntList = {}
			for _, o in ipairs(hunt:GetChildren()) do
				if o:IsA("Model") or o:IsA("BasePart") then
					-- بدنه‌ی درشت کدو (جای ضربه)
					local part, size = o:IsA("BasePart") and o or nil, 0
					if not part then
						for _, c in ipairs(o:GetDescendants()) do
							if c:IsA("BasePart") and c.Size.Magnitude > size then part, size = c, c.Size.Magnitude end
						end
					end
					if part then table.insert(huntList, { obj = o, part = part }) end
				end
			end
			cache.list = huntList
			return huntList
		end
		local pat = tostring(S.PumpkinPattern or "pumpkin"):lower()
		local list, n = {}, 0
		for _, o in ipairs(workspace:GetDescendants()) do
			n += 1
			if n % 3000 == 0 then task.wait() end
			if (o:IsA("Model") or o:IsA("BasePart")) and o.Name:lower():find(pat, 1, true) then
				local par = o.Parent
				local childOfMatch = par and par:IsA("Model") and par.Name:lower():find(pat, 1, true)
				if not childOfMatch and not o:FindFirstAncestor("Enemies") and not o:FindFirstAncestor("Characters") then
					local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
					if part then table.insert(list, { obj = o, part = part }) end
				end
			end
		end
		cache.list = list
		return list
	end
	Hub.ScanPumpkins = scan

	-- لیست کدوها (اسم کامل، کلاس، جا، Attribute ها) توی فایل، برای وقتی که اسم‌ها فرق داشته باشن
	function Hub.DumpPumpkins()
		local lines = { "pattern: " .. tostring(S.PumpkinPattern), "" }
		for i, p in ipairs(scan(true)) do
			if i > 80 then break end
			local attrs = {}
			for k, v in pairs(p.obj:GetAttributes()) do table.insert(attrs, k .. "=" .. tostring(v)) end
			local kids = {}
			for _, c in ipairs(p.obj:GetChildren()) do table.insert(kids, c.Name .. "[" .. c.ClassName .. "]") end
			table.insert(lines, ("%s | %s | pos %s | attrs: %s | children: %s"):format(
				p.obj:GetFullName(), p.obj.ClassName, tostring(p.part.Position), table.concat(attrs, ","), table.concat(kids, ",")))
		end
		return pcall(function() writefile("bmscan/pumpkins.txt", table.concat(lines, "\n")) end), #lines - 2
	end

	local function mobWithin(r)
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not root or not enemies then return nil end
		local best, bestD
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if d <= r and (not bestD or d < bestD) then best, bestD = m, d end
			end
		end
		return best
	end

	-- کلیک روی خود کدو (اگه روی صفحه باشه) + ضربه‌ی معمولی سلاح
	local function swingAt(part)
		attack()
		local v, onScreen = camera:WorldToViewportPoint(part.Position)
		if onScreen and VIM then
			pcall(function()
				VIM:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 0)
				VIM:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 0)
			end)
		end
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.2)
			if S.AutoPumpkin and alive() then
				local ok, err = pcall(function()
					-- اول ماب‌هایی که از کدو اسپان شدن
					local mob = mobWithin(40)
					if mob then
						killMob(mob, function() return S.AutoPumpkin and mob.Parent ~= nil end)
						return
					end
					local root = getRoot()
					local best, bestD
					for _, p in ipairs(scan()) do
						local state = p.obj:GetAttribute("PumpkinState")
						if p.obj.Parent and p.part.Parent and (state == nil or state == "Idle") and (skipUntil[p.obj] or 0) < tick() then
							local d = (p.part.Position - root.Position).Magnitude
							if not bestD or d < bestD then best, bestD = p, d end
						end
					end
					if not best then
						S.Status = "No pumpkins found (check Pumpkin Name)"
						task.wait(1)
						return
					end
					local obj, part = best.obj, best.part
					S.Status = "Breaking pumpkin: " .. obj.Name
					local function stillThere() return S.AutoPumpkin and obj.Parent ~= nil and part.Parent ~= nil end
					local function standPoint()
						local r = getRoot()
						local away = Vector3.new(r.Position.X - part.Position.X, 0, r.Position.Z - part.Position.Z)
						away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
						return part.Position + away * 5 + Vector3.new(0, 2, 0)
					end
					if (root.Position - standPoint()).Magnitude > 60 then
						tweenTo(CFrame.new(standPoint()), stillThere)
					end
					local t0, interrupted = tick(), false
					local function snap() return ("state=%s hits=%s"):format(tostring(obj:GetAttribute("PumpkinState")), tostring(obj:GetAttribute("PumpkinHits"))) end
					local before, lastSnap = snap(), nil
					local trail = {}
					while stillThere() and alive() and tick() - t0 < 8 do
						if mobWithin(25) then interrupted = true break end
						local r, sp = getRoot(), standPoint()
						setFloat(true)
						r.CFrame = CFrame.lookAt(sp, Vector3.new(part.Position.X, sp.Y, part.Position.Z))
						equipWeapon("Melee")
						swingAt(part)
						local s = snap()
						if s ~= lastSnap then
							lastSnap = s
							table.insert(trail, ("%.1fs %s"):format(tick() - t0, s))
						end
						task.wait(0.15)
					end
					-- لاگ هر کدو: وضعیت قبل/بعد (برای فهمیدن چرخه‌ی کدو)
					table.insert(plog, ("%s %s | start %s | %s | removed=%s interrupted=%s took %.1fs"):format(
						os.date("%H:%M:%S"), obj.Name, before, table.concat(trail, " > "), tostring(obj.Parent == nil), tostring(interrupted), tick() - t0))
					while #plog > 100 do table.remove(plog, 1) end
					pcall(function() writefile("bmscan/pumpkin_hub.txt", table.concat(plog, "\n")) end)
					-- 8 ثانیه زدیم و نشکست: یه مدت ردش می‌کنیم
					if not interrupted and stillThere() then skipUntil[obj] = tick() + 30 end
				end)
				if not ok then
					S.Status = "Error: " .. tostring(err)
					logError("AutoPumpkin", err)
					task.wait(1)
				end
			end
		end
	end)
end

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
					tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmHeight, 0), keep)
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
							tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmHeight, 0), keep)
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
		tweenTo(boss:GetPivot() * CFrame.new(0, S.FarmHeight, 0), keep)
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

	local raidClickedAt = 0
	local function inRaid()
		if raidIsland() then return true end
		local ok, vis = pcall(function() return player.PlayerGui.Main.TopHUDList.RaidTimer.Visible end)
		return ok and vis == true
	end
	Hub.InRaid = inRaid

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
				local keepOut = function() return S.AutoRaid and not inRaid() end
				local ok, err = pcall(function()
					local island, idx = raidIsland()
					if not island and inRaid() then
						S.Status = "Raid: waiting for the islands to load"
						task.wait(1)
						return
					end
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
							local spot = island.CFrame * CFrame.new(0, 60, 0)
							if (root.Position - spot.Position).Magnitude > 30 then
								S.Status = "Raid: going to island " .. idx
								tweenTo(spot, keep)
							else
								S.Status = "Raid: waiting for mobs on island " .. idx
								setFloat(true)
								task.wait(0.5)
							end
						end
						return
					end
					local chip = raidChip()
					if not chip and tick() - raidClickedAt < 30 then
						S.Status = "Raid: waiting for the raid to start"
						task.wait(1)
						return
					end
					if chip then
						local btn = raidButton()
						if not btn then
							S.Status = "Going to raid lab"
							tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 20, 0)), keepOut)
							return
						end
						S.Status = "Starting raid"
						tweenTo(btn.CFrame * CFrame.new(0, 3, 0), keepOut)
						task.wait(0.3)
						if fireclickdetector then pcall(fireclickdetector, btn:FindFirstChildOfClass("ClickDetector")) end
						raidClickedAt = tick()
						local t0 = tick()
						while keep() and not inRaid() and tick() - t0 < 20 do
							S.Status = "Raid: waiting for the raid to start"
							task.wait(0.5)
						end
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
					tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 3, 4)), keepOut)
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
			S.Status = ("Yama: elites %d/30"):format(prog)
			stepElite(keep)
			return
		end
		local hit
		pcall(function() hit = workspace.Map.Waterfall.SealedKatana.Hitbox end)
		if not hit then
			S.Status = "Yama: going to waterfall"
			tweenTo(CFrame.new(5241, 23, 1055), keep)
			return
		end
		local ghost = findMob("Ghost")
		if ghost and (ghost.HumanoidRootPart.Position - hit.Position).Magnitude < 300 then
			S.Status = "Yama: killing the Ghosts"
			killMob(ghost, keep)
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
		local active = hasQuest("Posessed Mummy")
		local title = questTitle()
		if not title then return active end
		return not questDone(title) and title:lower():find("mumm", 1, true) ~= nil
	end

	local BONE_CLEAR = 150
	local function boneScan()
		local root = getRoot()
		local nearest, nearestDist, mummy, mummyDist
		for _, n in ipairs(BONE_MOBS) do
			local m = findMob(n)
			if m then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not nearestDist or d < nearestDist then nearest, nearestDist = m, d end
				if n == "Posessed Mummy" then mummy, mummyDist = m, d end
			end
		end
		return nearest, nearestDist, mummy, mummyDist
	end

	local function boneTarget()
		local nearest, nearestDist, mummy, mummyDist = boneScan()
		if not nearest then return nil end
		local quest = mummyQuestActive()
		if nearestDist <= BONE_CLEAR then
			return quest and mummy and mummyDist <= BONE_CLEAR and mummy or nearest
		end
		return quest and mummy or nearest
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
			local _, nearDist = boneScan()
			local clear = not nearDist or nearDist > BONE_CLEAR
			if tick() - Hub.MummyGoneAt >= 1.5 and (clear or tick() - Hub.MummyGoneAt >= 20) then
				takeQuest(q, keep)
				if mummyQuestActive() then Hub.MummyGoneAt = nil end
				return
			end
		end
		local target = boneTarget()
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
		Hub.BringGroup = { ["Reborn Skeleton"] = true, ["Living Zombie"] = true, ["Demonic Soul"] = true, ["Posessed Mummy"] = true }
		local fought, fightErr = pcall(killMob, target, keep)
		Hub.BringGroup = nil
		if not fought then error(fightErr, 0) end
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
				elseif S.AutoSeaBeast then step, flag = (Hub.V3 and Hub.V3.seaBeastStep) or stepSeaBeast, "AutoSeaBeast"
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
	Hub.StyleChain = STYLE_CHAIN
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
				if S.AutoTushita and Sea == 3 then step, flag = Hub.V3.tushitaStep or stepTushita, "AutoTushita"
				elseif S.AutoCDK and Sea == 3 then step, flag = Hub.V3.cdkStep or stepCDK, "AutoCDK"
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
		if S.AutoChest and alive() and not mainFarmBusy() and not (Hub.CarryBlock and Hub.CarryBlock()) then
			pcall(function()
				local c = getChests()[1]
				if not c then
					S.Status = "No chests found"
					return
				end
				S.Status = "Collecting chest"
				Hub.ChestsTaken = (Hub.ChestsTaken or 0) + 1
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
			if S.AutoKen and not S.KenFarm and CommE then pcall(CommE.FireServer, CommE, "Ken", true) end
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
	local LOADER = (isfile and select(2, pcall(isfile, "bm.lua")) == true) and 'loadstring(readfile("bm.lua"))()'
		or 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()'
	local queueTp = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	Hub.CanQueue = queueTp ~= nil

	local function readHunt()
		local ok, d = pcall(function() return Svc.Http:JSONDecode(readfile(HUNT_FILE)) end)
		d = (ok and type(d) == "table") and d or {}
		d.visited = type(d.visited) == "table" and d.visited or {}
		d.hops = tonumber(d.hops) or 0
		d.last = tonumber(d.last) or 0
		d.start = tonumber(d.start) or os.time()
		return d
	end
	local function writeHunt(d) pcall(function() writefile(HUNT_FILE, Svc.Http:JSONEncode(d)) end) end
	function Hub.HuntReset() writeHunt({ visited = {}, hops = 0, last = os.time(), start = os.time() }) end
	function Hub.HuntHops() return readHunt().hops end

	local function fullMoonNight()
		local full = false
		pcall(function()
			full = Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431" and (Lighting.ClockTime > 16 or Lighting.ClockTime < 5)
		end)
		return full
	end
	Hub.FullMoonNight = fullMoonNight

	local EVENT_KEYS = { ["Mirage Island"] = { "mirage", "mystic" }, ["Kitsune Island"] = { "kitsune" }, ["Prehistoric Island"] = { "prehistoric" }, ["Frozen Dimension"] = { "frozen" } }

	local function eventPosition(t)
		for _, k in ipairs(EVENT_KEYS[t]) do
			local obj = Hub.Events[k]
			if obj then return obj:IsA("Model") and obj:GetPivot().Position or obj.Position end
		end
	end

	function Hub.HuntTargets()
		local out = { "Any Fruit", "Full Moon" }
		if Sea == 2 then table.insert(out, "Legendary Sword Dealer") end
		if Sea == 3 then
			for _, n in ipairs({ "Mirage Island", "Mirage + Full Moon", "Kitsune Island", "Prehistoric Island", "Frozen Dimension" }) do table.insert(out, n) end
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
		elseif t == "Mirage + Full Moon" then
			-- برای Race V4 هر دو با هم لازمه
			local pos = fullMoonNight() and eventPosition("Mirage Island")
			if pos then return pos, t end
		elseif EVENT_KEYS[t] then
			local pos = eventPosition(t)
			if pos then return pos, t end
		else
			local name = t:match("^Boss: (.+)$")
			local m = name and findMobAnywhere(name)
			if m then return m:GetPivot().Position, name end
		end
	end

	-- یه سرور تصادفی که قبلاً نرفتیم و جا داره
	-- برمی‌گردونه: id یا nil + دلیل (برای وقتی که Roblox لیست سرورها رو نمیده / همه‌ی سرورها دیده شدن)
	local function pickServer(seen)
		local cursor, pool, reason = nil, {}, "no new servers"
		for _ = 1, 3 do
			local ok, body = pcall(function()
				return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100" .. (cursor and ("&cursor=" .. cursor) or ""))
			end)
			if not ok then reason = "server list request failed (rate limited?)" break end
			local okD, data = pcall(function() return Svc.Http:JSONDecode(body) end)
			if not okD or type(data) ~= "table" then reason = "bad server list reply" break end
			if data.errors then reason = "Roblox refused the server list (too many requests)" break end
			for _, s in ipairs(data.data or {}) do
				if s.id and not seen[s.id] and (s.playing or 0) < (s.maxPlayers or 0) - 1 then table.insert(pool, s.id) end
			end
			cursor = data.nextPageCursor
			if #pool >= 20 or not cursor then break end
			task.wait(1)
		end
		if #pool > 0 then return pool[math.random(#pool)] end
		return nil, reason
	end

	local tpFailed = false
	pcall(function()
		connect(Svc.Teleport.TeleportInitFailed, function(p) if p == player then tpFailed = true end end)
	end)

	-- دکمه‌های یک‌کلیکی: هدف رو انتخاب و شکار رو شروع می‌کنه
	function Hub.HuntStart(t)
		S.HuntTarget = t
		Hub.HuntReset()
		S.HuntHop = true
		if Hub.SaveSettings then Hub.SaveSettings() end
	end
	function Hub.HuntStop()
		S.HuntHop = false
		Hub.HuntReset()
		if Hub.SaveSettings then Hub.SaveSettings() end
	end

	-- Job ID از نوتیفایرهای دیسکورد (دقیق‌ترین منبع برای Mirage / Full Moon / میوه‌ها)
	function Hub.JoinJob(text)
		local id = tostring(text or ""):match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x")
		if not id then return false, "No valid Job ID found" end
		if id == game.JobId then return false, "You are already in this server" end
		if queueTp then pcall(queueTp, LOADER) end
		tpFailed = false
		pcall(function() Svc.Teleport:TeleportToPlaceInstance(game.PlaceId, id, player) end)
		local t0 = tick()
		repeat task.wait(0.5) until tpFailed or tick() - t0 > 15
		if tpFailed then return false, "Teleport failed (server full, closed or in another Sea)" end
		return true
	end

	Hub.HuntStatus = "Off"
	task.spawn(function()
		task.wait(3)
		-- شکاری که بیشتر از ۲۰ دقیقه پیش ول شده ادامه پیدا نمی‌کنه
		if S.HuntHop and os.time() - readHunt().last > 1200 then S.HuntHop = false end
		local arrived = tick()
		local pickFails = 0
		local function giveUp(msg)
			S.HuntHop = false
			Hub.HuntReset()
			if Hub.SaveSettings then Hub.SaveSettings() end
			Hub.HuntStatus = "Stopped: " .. msg
			if notifyHook then notifyHook("Server Finder", Hub.HuntStatus, 10) end
		end
		while Hub.Running do
			task.wait(1)
			if not S.HuntHop then
				Hub.HuntStatus = "Off"
				arrived = tick()
				pickFails = 0
			else
				local d = readHunt()
				local pos, what = Hub.HuntFind(S.HuntTarget)
				local waited = tick() - arrived
				if not pos and os.time() - d.start > 1200 then
					giveUp(("not found in 20 minutes (%d hops)"):format(d.hops))
				elseif pos then
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
					local id, why = pickServer(seen)
					if not id then
						pickFails += 1
						if pickFails >= 6 then
							giveUp(tostring(why) .. " (6 tries)")
						else
							Hub.HuntStatus = ("%s - retry %d/6 in 15s..."):format(tostring(why), pickFails)
							arrived = tick() - S.HuntWait + 15
						end
					else
						pickFails = 0
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
						push(("ATTACK held=%s near=%d target=%s hp=%d dist=%d dmg/s=%d fruitM1=%d | clicks=%d activates=%d err=%s | Stun=%s Busy=%s Sit=%s"):format(
							held and (held.Name .. "[" .. tostring(held.ToolTip) .. "]") or "none", near, mobBaseName(best.Name),
							math.floor(best.Humanoid.Health), math.floor(bestD), math.floor(Hub.DamageRate and Hub.DamageRate() or 0), a.fruit or 0, a.click, a.tool, tostring(a.lastError),
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

-- ===== 00_core.lua =====
---------------------------------------------------------------------
-- v3 · Core: وبهوک، ابزارهای مشترک و یک صف مرکزی برای کارهای جدید
-- هر کار فقط یک «قدم» می‌نویسه؛ لوپ مرکزی اولین کار روشن رو اجرا می‌کنه تا سر حرکت دعوا نشه
---------------------------------------------------------------------
do
local okCore, errCore = pcall(function()
	if S.WebhookUrl == nil then S.WebhookUrl = "" end
	if S.WebhookOn == nil then S.WebhookOn = false end

	local V3 = { aiming = false, seen = {} }
	Hub.V3 = V3
	Hub.V3Tasks = {}
	Hub.V3SkipSave = {} -- گزینه‌هایی که پول/آیتم خرج می‌کنن و نباید خودکار روشن بشن

	local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

	function V3.log(msg)
		if Hub.LiveLog then pcall(Hub.LiveLog, msg) end
	end

	function V3.notify(title, text, dur)
		if notifyHook then notifyHook(title, text, dur or 5) end
	end

	-- پیام دیسکورد (وبهوک خود کاربر)؛ Job ID هم میره تا از v2 با Join Job ID وصل بشی
	function V3.webhook(title, desc)
		if not S.WebhookOn or S.WebhookUrl == "" or not httpRequest then return end
		task.spawn(function()
			pcall(httpRequest, {
				Url = S.WebhookUrl,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = Svc.Http:JSONEncode({
					username = "BM Hub",
					embeds = { { title = title, description = desc, color = 53503, footer = { text = "Job ID: " .. game.JobId } } },
				}),
			})
		end)
	end

	-- هر پیام فقط یک بار برای هر کلید (مثلاً «جزیره اسپاون شد») تا اسپم نشه
	function V3.once(key, fn)
		if V3.seen[key] then return end
		V3.seen[key] = true
		fn()
	end
	function V3.resetOnce(key) V3.seen[key] = nil end

	function V3.flatDist(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	-- ابزار با اسم دقیق از Backpack/Character برمی‌داره و توی دست می‌ذاره
	function V3.equip(name)
		local t, h = backpackTool(name), getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end

	-- ابزاری که ToolTip اون نوعه (Blox Fruit / Sword / Gun / Melee)
	function V3.toolByTip(tip)
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.ToolTip == tip then return t end
				end
			end
		end
	end

	function V3.key(code, hold)
		if not VIM then return end
		pcall(function()
			VIM:SendKeyEvent(true, code, false, game)
			task.wait(hold or 0.05)
			VIM:SendKeyEvent(false, code, false, game)
		end)
	end

	-- دوربین رو سمت هدف می‌چرخونه و وسط صفحه کلیک می‌کنه (برای اسلحه‌هایی که با موس نشونه می‌گیرن)
	function V3.aimClick(pos)
		V3.aiming = true
		pcall(function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, pos)
		end)
		local vs = camera.ViewportSize
		local x, y = vs.X * 0.5, vs.Y * 0.5
		if VIM then
			pcall(function()
				VIM:SendMouseMoveEvent(x, y, game)
				VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
				task.wait(0.03)
				VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
			end)
		else
			pcall(function()
				Svc.VirtualUser:CaptureController()
				Svc.VirtualUser:Button1Down(Vector2.new(x, y), camera.CFrame)
				Svc.VirtualUser:Button1Up(Vector2.new(x, y), camera.CFrame)
			end)
		end
	end

	function V3.aimRelease()
		if not V3.aiming then return end
		V3.aiming = false
		pcall(function() camera.CameraType = Enum.CameraType.Custom end)
	end

	-- ProximityPrompt / ClickDetector با یه تابع (هر کدوم executor پشتیبانی کنه)
	function V3.activate(obj)
		if not obj then return false end
		local ok = false
		pcall(function()
			if obj:IsA("ProximityPrompt") and fireproximityprompt then
				fireproximityprompt(obj, 1)
				ok = true
			elseif obj:IsA("ClickDetector") and fireclickdetector then
				fireclickdetector(obj)
				ok = true
			end
		end)
		return ok
	end

	function V3.findDesc(root, name)
		if not root then return nil end
		local ok, res = pcall(function() return root:FindFirstChild(name, true) end)
		return ok and res or nil
	end

	-- flag: اسم کلید توی S، step(keep): یک مرحله، cond(): شرط فعال بودن (مثلاً دریای مناسب)
	function V3.register(flag, step, cond, skipSave)
		if S[flag] == nil then S[flag] = false end
		if skipSave then Hub.V3SkipSave[flag] = true end
		table.insert(Hub.V3Tasks, { flag = flag, step = step, cond = cond })
	end

	function Hub.V3Busy()
		for _, t in ipairs(Hub.V3Tasks) do
			if S[t.flag] and (not t.cond or t.cond()) then return true end
		end
		return false
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.3)
			local ran = false
			if alive() then
				for _, t in ipairs(Hub.V3Tasks) do
					if S[t.flag] and (not t.cond or t.cond()) then
						ran = true
						local flag = t.flag
						local ok, err = pcall(t.step, function() return S[flag] and Hub.Running end)
						if not ok then
							logError(flag, err)
							task.wait(2)
						end
						break
					end
				end
			end
			if not ran then V3.aimRelease() end
		end
		V3.aimRelease()
	end)
end)
if not okCore then logError("v3 core", errCore) end
end

-- ===== 10_sea.lua =====
---------------------------------------------------------------------
-- v3 · Sea: قایق، Leviathan، Prehistoric Island، Frozen Heart، Sea Event
-- مختصات و اسم‌ها از بررسی Banana Cat؛ منطق اجرا نوشته‌ی خودمونه
---------------------------------------------------------------------
do
local okSea, errSea = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({
		BoatChoice = "Beast Hunter", EventBoat = "PirateBrigade", BoatSpeed = 150, WillBack = true,
		ResetForBoat = true, AutoBuyBoat = false, RepairBoat = true,
		SeaSpotSet = false, SeaSpotX = 0, SeaSpotZ = 0, SeaWeapon = "Blox Fruit", SeaHover = 60,
		BoatMaxSpeedOn = false, BoatMaxSpeed = 200,
		SeaHunt = true, SeaDanger = 5, SeaRotate = true, SeaBeastHover = 200, SeaRetreat = true, SeaAttack = "All Fast",
		WaterDefault = false,
		SeaHitBeasts = true, SeaHitShark = true, SeaHitBoats = true, SeaHitSmall = true,
	}) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.AutoBuyBoat = true -- پول خرج می‌کنه؛ هر بار باید دستی روشن بشه

	-- ایستادن روی آب پیش‌فرض روشن (فقط یک بار؛ اگه بعداً خاموشش کنی خاموش می‌مونه). بعد از لود تنظیمات اجرا میشه
	task.delay(3, function()
		if not S.WaterDefault then S.WaterDefault, S.WalkOnWater = true, true end
	end)

	-- Tiki Outpost = دریای 3 نقشه‌ی جدید (فقط اونجا Leviathan و Prehistoric Island هست)
	local TIKI_NPC = Vector3.new(-16204.08, 9.09, 479.23)
	local OLD_NPC = Vector3.new(-13.49, 10.31, 2927.69)
	local HOME = Vector3.new(-32975.99, 0, 25963.71) -- مرکز گشت؛ بیشتر از 10km ازش دور بشی برمی‌گردی
	local FAR = Vector3.new(-118834.52, 0, 99999920) -- جهت گشت (خیلی دور، فقط برای جهت)

	local function hasLocation(name)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local loc = wo and wo:FindFirstChild("Locations")
		return loc ~= nil and loc:FindFirstChild(name) ~= nil
	end
	local function newMap()
		return hasLocation("Tiki Outpost") or game.PlaceId == 100117331123089
	end
	local function leviathanUp() return hasLocation("Frozen Dimension") end
	local function prehistoricUp()
		local m = workspace:FindFirstChild("Map")
		return m ~= nil and m:FindFirstChild("PrehistoricIsland") ~= nil
	end
	V3.hasLocation, V3.prehistoricUp, V3.leviathanUp, V3.newMap = hasLocation, prehistoricUp, leviathanUp, newMap

	-----------------------------------------------------------------
	-- قایق
	-----------------------------------------------------------------
	local function boatAlive(b)
		local hp = b:FindFirstChild("Humanoid")
		if hp and hp:IsA("ValueBase") then return hp.Value > 0 end
		if hp and hp:IsA("Humanoid") then return hp.Health > 0 end
		return true
	end

	-- قایق خودمون (Owner = اسم ما)؛ needPart مثلاً "Harpoon" برای Beast Hunter
	local function myBoat(needPart)
		local boats = workspace:FindFirstChild("Boats")
		if not boats then return nil end
		for _, b in ipairs(boats:GetChildren()) do
			if b:IsA("Model") then
				local owner = b:FindFirstChild("Owner")
				if owner and tostring(owner.Value) == player.Name and b:FindFirstChild("VehicleSeat")
					and boatAlive(b) and (not needPart or b:FindFirstChild(needPart)) then
					return b
				end
			end
		end
	end
	V3.myBoat = myBoat

	local function seatedOn(boat)
		local h = getHum()
		return h ~= nil and boat ~= nil and h.SeatPart ~= nil and h.SeatPart:IsDescendantOf(boat)
	end

	-- برخورد قایق خاموش میشه تا به جزیره/صخره گیر نکنه؛ مقدار قبلی ذخیره میشه و بعدش برمی‌گرده
	local saved = setmetatable({}, { __mode = "k" })
	local function boatNoclip(boat, on)
		for _, p in ipairs(boat:GetDescendants()) do
			if p:IsA("BasePart") then
				if on then
					if saved[p] == nil then saved[p] = p.CanCollide end
					p.CanCollide = false
				elseif saved[p] ~= nil then
					p.CanCollide = saved[p]
					saved[p] = nil
				end
			end
		end
	end

	-- قایق رو (با نشستن روی VehicleSeat) به goal میبره؛ stop() اگه true بده زودتر تموم میشه
	local function sail(boat, goal, keep, stop)
		local seat = boat:FindFirstChild("VehicleSeat")
		if not seat then return false end
		local bv = seat:FindFirstChild("BodyVelocity")
		local force = bv and bv.MaxForce
		if bv then
			bv.MaxForce = Vector3.zero
			bv.Velocity = Vector3.zero
		end
		boatNoclip(boat, true)
		local y = seat.Position.Y
		local speed = math.clamp(S.BoatSpeed, 50, 400)
		local reached, lastNoclip = false, tick()
		local expected, snaps = seat.Position, 0
		while keep() and Hub.Running and boat.Parent and seat.Parent and alive() do
			if not seatedOn(boat) then break end
			if stop and stop() then break end
			local dt = math.min(task.wait(), 0.1)
			local p = seat.Position
			-- مثل پرواز: اگه سرور قایق رو عقب کشید کندتر میشیم و از همونجا ادامه میدیم
			if V3.flatDist(p, expected) > 25 then
				snaps += 1
				speed = math.max(80, speed * 0.75)
				S.Status = ("Boat: server pulled the boat back (%d), now %d speed"):format(snaps, math.floor(speed))
			end
			local flat = Vector3.new(goal.X - p.X, 0, goal.Z - p.Z)
			local step = speed * dt
			if flat.Magnitude <= step + 3 then
				reached = true
				break
			end
			local np = Vector3.new(p.X, y, p.Z) + flat.Unit * step
			seat.CFrame = CFrame.new(np) * seat.CFrame.Rotation
			expected = np
			if tick() - lastNoclip > 1 then
				lastNoclip = tick()
				boatNoclip(boat, true)
			end
		end
		if bv and bv.Parent and force then bv.MaxForce = force end
		if boat.Parent then boatNoclip(boat, false) end
		return reached
	end

	local lastReset = 0
	-- نتیجه: قایقی که روش نشستیم، یا nil (و یک قدم برای رسیدن بهش برداشته شده)
	local function ensureBoat(boatName, keep, needPart)
		local root = getRoot()
		if not root then return nil end
		local boat = myBoat(needPart)
		local dist = boat and (root.Position - boat.VehicleSeat.Position).Magnitude
		if boat and dist >= 4000 and dist < 15000 then
			-- قایق خودت هنوز هست ولی دوره: به جای خریدن دوباره، می‌ریم سراغش
			S.Status = "Boat: flying to your boat"
			tweenTo(boat.VehicleSeat.CFrame, keep)
			return nil
		end
		local far = boat == nil or dist >= 4000
		if far then
			if not S.AutoBuyBoat then
				-- Auto Buy Boat پول خرج می‌کنه و ذخیره نمیشه؛ پس بعد از هر ری‌استارت یه پیام واضح میدیم
				S.Status = "Boat: no boat nearby (turn on Auto Buy Boat)"
				V3.once("needBoat", function()
					V3.notify("Boat needed", "No boat of yours here. Turn on Auto Buy Boat in the Sea tab (spends Beli)", 10)
				end)
				task.wait(2)
				return nil
			end
			local npc = newMap() and TIKI_NPC or OLD_NPC
			local d = (npc - root.Position).Magnitude
			if d > 8 then
				-- خیلی دوریم: به جای پرواز طولانی، می‌میریم تا نزدیک Tiki اسپاون بشیم
				if d > 1000 and S.ResetForBoat and newMap() and tick() - lastReset > 20 then
					local sp = dataValue("LastSpawnPoint")
					if player:GetAttribute("CurrentLocation") ~= "Tiki Outpost" and (sp == "Tiki" or sp == "Tiki2") then
						lastReset = tick()
						S.Status = "Boat: respawning near Tiki Outpost"
						local h = getHum()
						if h then h.Health = 0 end
						task.wait(3)
						return nil
					end
				end
				S.Status = "Boat: flying to the boat dealer"
				tweenTo(CFrame.new(npc + Vector3.new(0, 3, 0)), keep)
				return nil
			end
			S.Status = "Boat: buying " .. boatName
			invoke("BuyBoat", boatName)
			local t0 = tick()
			while keep() and tick() - t0 < 6 and not myBoat(needPart) do task.wait(0.3) end
			return nil
		end
		if not seatedOn(boat) then
			S.Status = "Boat: sitting down"
			tweenTo(boat.VehicleSeat.CFrame, keep)
			task.wait(0.6)
			return nil
		end
		V3.resetOnce("needBoat")
		return boat
	end

	V3.ensureBoat, V3.sail = ensureBoat, sail

	-- سرعت اتوماتیک قایق (MaxSpeed خود صندلی) برای وقتی که دستی رانندگی می‌کنی
	task.spawn(function()
		while Hub.Running do
			task.wait(2)
			if S.BoatMaxSpeedOn then
				local b = myBoat()
				local seat = b and b:FindFirstChild("VehicleSeat")
				if seat then pcall(function() seat.MaxSpeed = S.BoatMaxSpeed end) end
			end
		end
	end)

	-----------------------------------------------------------------
	-- گشت: Leviathan و Prehistoric Island
	-----------------------------------------------------------------
	local back = false -- true = داریم برمی‌گردیم سمت HOME
	local function stepFind(flag, label, boatKey, isUp)
		return function(keep)
			if not newMap() then
				V3.notify(label, "Needs the new Sea 3 map (Tiki Outpost)", 6)
				S[flag] = false
				return
			end
			if isUp() then
				V3.notify(label, label .. " spawned! (switch turned off)", 8)
				V3.webhook(label .. " found", "Spawned in this server")
				S[flag] = false
				return
			end
			local boat = ensureBoat(S[boatKey], keep)
			if not boat then return end
			local seat = boat.VehicleSeat
			local d = V3.flatDist(seat.Position, HOME)
			if S.WillBack then
				if d >= 10000 then back = true elseif d <= 4800 then back = false end
			else
				back = false
			end
			S.Status = label .. ": sailing " .. (back and "back" or "out") .. " (" .. math.floor(d) .. ")"
			sail(boat, back and HOME or FAR, keep, function()
				if isUp() then return true end
				if S.WillBack then
					local dd = V3.flatDist(seat.Position, HOME)
					if not back and dd >= 10000 then return true end
					if back and dd <= 4800 then return true end
				end
				return false
			end)
		end
	end

	-----------------------------------------------------------------
	-- Frozen Heart: با هارپون قلب Leviathan رو می‌زنه (قایق Beast Hunter)
	-----------------------------------------------------------------
	local function stepHeart(keep)
		local map = workspace:FindFirstChild("Map")
		local heart = map and map:FindFirstChild("FrozenHeart")
		local inside, cube = heart and heart:FindFirstChild("Inside"), heart and heart:FindFirstChild("Cube")
		if not (inside and cube) then
			S.Status = "Heart: not spawned"
			task.wait(2)
			return
		end
		if inside:GetAttribute("Harpooned") then
			V3.notify("Frozen Heart", "Harpoon landed ✔ (switch turned off)", 6)
			V3.webhook("Frozen Heart", "Harpoon landed")
			S.AutoFireHeart = false
			return
		end
		local boat = ensureBoat("Beast Hunter", keep, "Harpoon")
		if not boat then return end
		local seat = boat.VehicleSeat
		local hum = getHum()
		local onHarpoon = hum ~= nil and hum.SeatPart ~= nil and hum.SeatPart.Parent ~= nil and hum.SeatPart.Parent.Name == "Harpoon"
		local goal = Vector3.new(cube.Position.X, seat.Position.Y, cube.Position.Z + 300)
		local d = Vector3.new(goal.X - seat.Position.X, 0, goal.Z - seat.Position.Z).Magnitude
		if d > 5 and not onHarpoon then
			if hum and hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" then
				S.Status = "Heart: sailing to the heart"
				sail(boat, goal, keep)
				task.wait(1)
				-- قایق رو رو به قلب می‌چرخونیم
				local pos, tgt = boat:GetPivot().Position, inside.Position
				pcall(function() boat:PivotTo(CFrame.lookAt(pos, Vector3.new(tgt.X, pos.Y, tgt.Z))) end)
			else
				tweenTo(seat.CFrame, keep)
			end
		elseif onHarpoon then
			S.Status = "Heart: firing the harpoon"
			invoke("FireHarpoon", math.pi / 4, 4.4342573293783646e-4, boat.Harpoon, workspace:GetServerTimeNow())
			task.wait(1)
		else
			local hs = boat.Harpoon:FindFirstChild("Seat")
			if hs then tweenTo(hs.CFrame, keep) end
			task.wait(0.5)
		end
	end

	-----------------------------------------------------------------
	-- Sea Event: هیولاهای دریا (SeaBeast، Terrorshark)، قایق‌های دشمن و ماب‌های دریا
	-- از Banana: Sea Event فقط توی دریای عمیق (Danger Level) اسپاون میشه، پس وقتی هدفی نیست
	-- قایق رو به دریای عمیق می‌بریم و گشت می‌زنیم؛ فاصله از هر نوع هدف و جاخالی Sea Beast هم از اونجاست
	-----------------------------------------------------------------
	local function aliveSea(o)
		if not o or not o.Parent then return false end
		local hv = o:FindFirstChild("Health")
		if hv and hv:IsA("ValueBase") then return hv.Value > 0 end
		local h = o:FindFirstChildWhichIsA("Humanoid")
		return h ~= nil and h.Health > 0
	end

	-- نزدیک‌ترین جزیره (برای تشخیص «وسط دریا» و جهت رفتن به دریای عمیق)
	local function nearestIsland(pos)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local loc = wo and wo:FindFirstChild("Locations")
		local best, bestD
		for _, c in ipairs(loc and loc:GetChildren() or {}) do
			if c:IsA("BasePart") then
				local d = V3.flatDist(c.Position, pos)
				if not bestD or d < bestD then best, bestD = c.Position, d end
			end
		end
		return best, bestD
	end
	V3.nearestIsland = nearestIsland

	-- عدد Danger Level قطب‌نمای خود بازی (همون که Banana می‌خونه)؛ nil یعنی خونده نشد
	local function dangerLevel()
		local ok, n = pcall(function()
			local d = player.PlayerGui.Main.Compass.Frame.DangerLevel
			if not d.Visible then return 0 end
			return tonumber(d.TextLabel.Text)
		end)
		return ok and n or nil
	end
	V3.dangerLevel = dangerLevel

	-- rank: هر چی کمتر زودتر؛ Terrorshark جایزه‌ی بیشتری داره
	local RANK = { shark = 1, beast = 2, boat = 3, small = 4 }
	local SEA_RANGE = 3000

	-- focus = "beast": فقط Sea Beast (برای Auto Sea Beast)؛ nil = همه‌ی هدف‌های روشن
	local focus

	local function seaTargets()
		local out, root = {}, getRoot()
		if not root then return out end
		local seen = {}
		local function add(o, kind, label)
			if seen[o] then return end
			local part = o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Engine") or o.PrimaryPart
			if part and aliveSea(o) then
				local d = (part.Position - root.Position).Magnitude
				if d <= SEA_RANGE then
					seen[o] = true
					table.insert(out, { obj = o, part = part, kind = kind, label = label or o.Name, d = d })
				end
			end
		end
		if (S.SeaHitShark and not focus) or focus == "shark" then
			local ts = findMobAnywhere("Terrorshark")
			if ts then add(ts, "shark", "Terrorshark") end
		end
		local sb = workspace:FindFirstChild("SeaBeasts")
		if ((S.SeaHitBeasts and not focus) or focus == "beast") and sb then
			for _, o in ipairs(sb:GetChildren()) do add(o, "beast", "Sea Beast") end
		end
		local boats = workspace:FindFirstChild("Boats")
		if S.SeaHitBoats and boats and not focus then
			for _, b in ipairs(boats:GetChildren()) do
				local owner = b:FindFirstChild("Owner")
				-- قایق بازیکن‌ها رو نمی‌زنیم؛ فقط قایق‌های دشمن (Engine + Health و بدون صاحب بازیکن)
				if b:IsA("Model") and b:FindFirstChild("Engine") and b:FindFirstChild("Health")
					and not (owner and Players:FindFirstChild(tostring(owner.Value))) then
					add(b, "boat")
				end
			end
		end
		-- ماب‌های دریا (کوسه، پیرانا، خدمه‌ها): هر دشمنی دور از جزیره‌ها، چون روی آب ماب جزیره نیست
		local enemies = workspace:FindFirstChild("Enemies")
		if S.SeaHitSmall and enemies and not focus then
			local _, islandD = nearestIsland(root.Position)
			if islandD and islandD > 1500 then
				for _, m in ipairs(enemies:GetChildren()) do
					if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= 800 then add(m, "small", mobBaseName(m.Name)) end
				end
			end
		end
		table.sort(out, function(a, b)
			if RANK[a.kind] ~= RANK[b.kind] then return RANK[a.kind] < RANK[b.kind] end
			return a.d < b.d
		end)
		return out
	end
	V3.seaTargets = seaTargets

	-- جای ایستادن برای هر نوع هدف (اعداد از Banana). lift = جاخالی
	-- Sea Beast: روی آب 200 بالاتر و 50 کنار؛ زیر آب بالای سرش روی ارتفاع -60 + 200
	-- M1 میوه‌ی Banana برای سی ایونت: میوه‌ی M1 دار + M1 Spam. Kitsune روی قایق‌ها M1 نمی‌زنه
	local NEAR_FRUITS = { "T-Rex", "Leopard", "Mammoth", "Dough" }
	local function seaFruitM1(t)
		if S.SeaAttack ~= "M1 Spam" or S.SeaWeapon ~= "Blox Fruit" then return nil end
		local fruit = V3.toolByTip("Blox Fruit")
		if not fruit or not fruit:FindFirstChild("LeftClickRemote") then return nil end
		if t and t.kind == "boat" and fruit.Name == "Kitsune-Kitsune" then return nil end
		return fruit
	end
	V3.seaFruitM1 = seaFruitM1

	-- جای ایستادن و نشونه‌ی M1 میوه (اعداد از Banana):
	-- قایق: 25 زیر Engine و شلیک به 35 زیرش (از زیر قایق، هر ضربه می‌خوره)
	-- Sea Beast: درست بالای سرش، 30 برای میوه‌های نزدیک‌زن و 200 برای بقیه
	-- کوسه و بقیه: 20 بالای سرش (Kitsune 18)
	local function fruitStand(t, fruit, lift)
		local p = t.part.Position
		if t.kind == "boat" and t.part.Name == "Engine" then
			return (t.part.CFrame * CFrame.new(0, -25, 0)).Position + Vector3.new(0, lift, 0), (t.part.CFrame * CFrame.new(0, -35, 0)).Position
		elseif t.kind == "beast" then
			local h = 200
			for _, n in ipairs(NEAR_FRUITS) do
				if fruit.Name:find(n, 1, true) then h = 30 end
			end
			if math.abs(p.Y + 60) <= 175 then return Vector3.new(p.X, p.Y + h + lift, p.Z), p end
			return Vector3.new(p.X, -60 + h + lift, p.Z), p
		end
		local h = fruit.Name == "Kitsune-Kitsune" and 18 or 20
		return p + Vector3.new(0, h + lift, 0), p
	end
	V3.fruitStand = fruitStand

	function V3.seaStand(t, lift)
		local p = t.part.Position
		lift = lift or 0
		local fruit = seaFruitM1(t)
		if fruit then return (fruitStand(t, fruit, lift)) end
		if t.kind == "beast" then
			-- M1 از نزدیک می‌زنه (Banana برای M1 میوه 30 می‌ذاره)
			local h = S.SeaAttack == "M1 Spam" and 30 or S.SeaBeastHover
			if math.abs(p.Y + 60) <= 175 then return Vector3.new(p.X, p.Y + h + lift, p.Z + 50) end
			return Vector3.new(p.X, -60 + h + lift, p.Z)
		elseif t.kind == "shark" then
			return p + Vector3.new(0, 60 + lift, 0)
		elseif t.kind == "small" then
			return p + Vector3.new(0, 20 + lift, 0)
		end
		return p + Vector3.new(0, S.SeaHover + lift, 0)
	end

	-- جاخالی Sea Beast: انیمیشن 8708222556 (از Banana) بعد از 0.7 ثانیه ضربه می‌زنه؛ بقیه رو مغز یاد می‌گیره
	local seaLiftUntil = 0
	local KNOWN_BEAST_ATTACK = { ["rbxassetid://8708222556"] = 0.7 }
	local watchedSea = setmetatable({}, { __mode = "k" })
	local function watchSea(t)
		local hum = t.obj:FindFirstChildOfClass("Humanoid")
		if not hum or watchedSea[hum] then return end
		watchedSea[hum] = true
		if Hub.WatchMob then Hub.WatchMob(t.obj, hum) end
		pcall(function()
			hum.AnimationPlayed:Connect(function(track)
				local id = track.Animation and track.Animation.AnimationId
				local delay = id and KNOWN_BEAST_ATTACK[id]
				if not delay or not Hub.Running then return end
				task.delay(delay, function()
					seaLiftUntil = tick() + math.clamp(track.Length > 0 and track.Length or 3, 1.5, 10)
				end)
			end)
		end)
	end
	local function seaLift()
		if tick() < seaLiftUntil or (Hub.DodgeY or 0) > 0 then return 600 end
		return 0
	end

	-- همه چیز سریع: همه‌ی سلاح‌ها به نوبت (هر کدوم 0.8 ثانیه) با همه‌ی اسکیل‌ها (Z X C V هر 0.3 ثانیه)
	local ROTATION = { "Melee", "Blox Fruit", "Sword", "Gun" }
	local rot, rotAt, keysAt = 0, 0, 0
	local function rotateAttack(t)
		if tick() - rotAt >= 0.8 then
			rotAt = tick()
			for _ = 1, #ROTATION do
				rot = rot % #ROTATION + 1
				if V3.toolByTip(ROTATION[rot]) then break end
			end
			local tool, h = V3.toolByTip(ROTATION[rot]), getHum()
			if tool and h and tool.Parent ~= getChar() then pcall(function() h:EquipTool(tool) end) end
		end
		V3.aimClick(t.part.Position)
		if tick() - keysAt >= 0.3 then
			keysAt = tick()
			for _, k in ipairs({ "Z", "X", "C", "V" }) do V3.key(Enum.KeyCode[k], 0.03) end
		end
	end

	local function equipSeaWeapon(w)
		if w == "Dragonstorm" or w == "Skull Guitar" then
			if not backpackTool(w) then
				invoke("LoadItem", w)
				task.wait(0.4)
			end
			V3.equip(w)
		else
			equipWeapon(w)
		end
	end

	-- M1 پشت سر هم: با سلاح انتخابی سمت هدف کلیک می‌کنه؛ میوه‌ی M1 دار مستقیم هم M1 می‌فرسته
	local m1Combo, m1At = 0, 0

	-- M1 میوه توی یه حلقه‌ی جدا: به حلقه‌ی اصلی (پرواز، اسکن دریا) گره نخورده و کلیک صفحه نداره
	-- فاصله‌ی ضربه همونیه که مغز برای این میوه یاد گرفته (سرور اسپم خیلی تند رو کم‌دمیج می‌کنه)
	local fruitTarget, fruitUntil, fruitCombo = nil, 0, 0
	V3.seaFruitShots = 0
	local function fruitGap(fruit)
		local ok, gap = pcall(function() return Hub.Brain.store.fruit[fruit.Name].gap end)
		return ok and tonumber(gap) or 0.2
	end
	local function fireFruitM1()
		local t = fruitTarget
		if not t or tick() > fruitUntil or not t.obj.Parent then return 0.1 end
		local fruit, root = seaFruitM1(t), getRoot()
		if not fruit or not root or fruit.Parent ~= getChar() then return 0.1 end
		local remote = fruit:FindFirstChild("LeftClickRemote")
		local _, aim = fruitStand(t, fruit, 0)
		local dir = aim - root.Position
		if not remote or dir.Magnitude < 0.5 then return 0.1 end
		fruitCombo = fruitCombo % 4 + 1
		if pcall(function() remote:FireServer(dir.Unit, fruitCombo) end) then
			V3.seaFruitShots += 1
		end
		return fruitGap(fruit)
	end
	V3.fireFruitM1 = fireFruitM1
	function V3.setFruitTarget(t, untilT) fruitTarget, fruitUntil = t, untilT end
	task.spawn(function()
		while Hub.Running do
			local ok, gap = pcall(fireFruitM1)
			task.wait(ok and gap or 0.2)
		end
	end)

	local function m1Attack(t)
		if seaFruitM1(t) then
			equipWeapon("Blox Fruit")
			V3.aimRelease()
			fruitTarget, fruitUntil = t, tick() + 1
			return
		end
		equipSeaWeapon(S.SeaWeapon)
		V3.aimClick(t.part.Position)
		local char, root = getChar(), getRoot()
		local tool = char and char:FindFirstChildOfClass("Tool")
		local remote = tool and tool:FindFirstChild("LeftClickRemote")
		if remote and root and tick() - m1At >= 0.2 then
			m1At = tick()
			m1Combo = m1Combo % 4 + 1
			pcall(function() remote:FireServer((t.part.Position - root.Position).Unit, m1Combo) end)
		end
	end

	local function attackSea(t)
		if S.SeaAttack == "M1 Spam" then return m1Attack(t) end
		local w = S.SeaWeapon
		if w == "Dragonstorm" or w == "Skull Guitar" then
			if not backpackTool(w) then
				invoke("LoadItem", w)
				task.wait(0.4)
			end
			V3.equip(w)
		elseif S.SeaRotate then
			return rotateAttack(t)
		else
			equipWeapon(w)
		end
		V3.aimClick(t.part.Position)
		if tick() - keysAt >= 0.3 then
			keysAt = tick()
			for _, k in ipairs({ "Z", "X", "C", "V" }) do V3.key(Enum.KeyCode[k], 0.03) end
		end
	end
	V3.attackSea = attackSea

	-- تعمیر قایق با چکش وقتی از قایق دور نیستیم؛ true یعنی مشغول تعمیر بود
	local function repair(boat)
		local bar
		pcall(function() bar = player.PlayerGui.Main.BottomHUDList.ShipHealthBar end)
		local label = bar and bar.Visible and bar:FindFirstChild("TextLabel")
		if not label then return false end
		local text = (label.Text:gsub("Ship ", ""))
		local cur, max = text:match("(%d+)%s*/%s*(%d+)")
		if not (cur and max) or tonumber(cur) >= tonumber(max) then return false end
		local char = getChar()
		if not (char and boat.PrimaryPart) then return false end
		if (boat.PrimaryPart.Position - getRoot().Position).Magnitude >= 20 then
			local h = getHum()
			if h then h.Sit = false end
			return true
		end
		local h = getHum()
		if h and h.Sit then
			h.Sit = false
		elseif char:FindFirstChild("_RepairHammer") then
			local hammer = char._RepairHammer
			if hammer:FindFirstChild("M1UP") then
				hammer.M1UP:Destroy()
			elseif not hammer:GetAttribute("Repairing") and hammer:FindFirstChild("M1Down") then
				hammer.M1Down:FireServer("Default")
				task.wait(0.5)
			end
		else
			pcall(function()
				ReplicatedStorage.Remotes.SubclassNetwork.UseSubclass:InvokeServer({ Action = "RequestHammer" })
			end)
			task.wait(3)
		end
		return true
	end

	-- گشت توی دریای عمیق: تا Danger Level هدف دور میشیم، بعد دور یه مربع 500 استادی می‌چرخیم
	local hunt = { i = 0 }
	V3.seaHunt = hunt
	-- کجا بریم وقتی هدفی نیست (تابع خالص): "back" = خیلی دور شدیم، "patrol" = گشت، "out" = برو دریای عمیق
	-- بدون عدد Danger، بیشتر از 3000 استاد دور از جزیره رو عمیق حساب می‌کنیم
	function V3.huntGoal(pos, lvl, island, islandD, center, i)
		if newMap() and V3.flatDist(pos, HOME) > 12000 then return "back", HOME, nil, i end
		if center and V3.flatDist(pos, center) > 3000 then center = nil end
		local deep = (lvl ~= nil and lvl >= S.SeaDanger) or (lvl == nil and islandD ~= nil and islandD > 3000)
		if deep or center then
			center = center or pos
			i = i % 4 + 1
			local a = i * math.pi / 2
			return "patrol", center + Vector3.new(math.cos(a) * 500, 0, math.sin(a) * 500), center, i
		end
		local dir = island and Vector3.new(pos.X - island.X, 0, pos.Z - island.Z) or Vector3.new(0, 0, 1)
		dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(0, 0, 1)
		return "out", pos + dir * 1500, nil, i
	end

	local function huntStep(boat, keep)
		local seat = boat.VehicleSeat
		local lvl = dangerLevel()
		local island, islandD = nearestIsland(seat.Position)
		local mode, goal
		mode, goal, hunt.center, hunt.i = V3.huntGoal(seat.Position, lvl, island, islandD, hunt.center, hunt.i)
		local function found() return #seaTargets() > 0 end
		if mode == "back" then
			S.Status = "Sea Event: too far, sailing back"
			sail(boat, goal, keep, function() return found() or V3.flatDist(seat.Position, HOME) < 9000 end)
		elseif mode == "patrol" then
			S.Status = ("Sea Event: patrolling (danger %s)"):format(tostring(lvl or "?"))
			sail(boat, goal, keep, found)
		else
			S.Status = ("Sea Event: sailing to deep sea (danger %s/%d)"):format(tostring(lvl or "?"), S.SeaDanger)
			sail(boat, goal, keep, function()
				local l = dangerLevel()
				return found() or (l ~= nil and l >= S.SeaDanger)
			end)
		end
	end

	-- آمار جلسه: چی کشتیم
	local kills, current = {}, nil
	V3.seaKills = kills
	local function countKill()
		if current and not aliveSea(current.obj) then
			kills[current.label] = (kills[current.label] or 0) + 1
			if current.kind == "shark" then V3.sharkKills = (V3.sharkKills or 0) + 1 end
			if current.kind == "shark" or current.kind == "beast" then V3.webhook("Sea Event", current.label .. " killed ✔") end
		end
	end

	local seenKinds = setmetatable({}, { __mode = "k" })
	local function stepSeaEvent(keep)
		local list = seaTargets()
		local root = getRoot()
		local hum = getHum()
		if S.SeaRetreat and hum and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth * 100 < S.RetreatHP then
			S.Status = "Sea Event: low HP, healing up high"
			V3.aimRelease()
			tweenTo(CFrame.new(root.Position + Vector3.new(0, 300, 0)), keep)
			local t0 = tick()
			while keep() and alive() and tick() - t0 < 20 do
				local h = getHum()
				if not h or h.Health / h.MaxHealth >= 0.8 then break end
				setFloat(true)
				task.wait(0.5)
			end
			return
		end
		local t = list[1]
		if not current or not t or current.obj ~= t.obj then
			countKill()
			current = t
		end
		if not t then
			local boat = ensureBoat(S.EventBoat, keep)
			if not boat then return end
			V3.aimRelease()
			if S.RepairBoat and repair(boat) then
				S.Status = "Sea Event: repairing the boat"
				return
			end
			local seat = boat.VehicleSeat
			if S.SeaSpotSet then
				local spot = Vector3.new(S.SeaSpotX, 0, S.SeaSpotZ)
				if V3.flatDist(seat.Position, spot) > 200 then
					S.Status = "Sea Event: sailing to your spot"
					sail(boat, spot, keep, function() return #seaTargets() > 0 end)
					return
				end
				S.Status = "Sea Event: waiting at your spot"
				task.wait(1)
				return
			end
			if S.SeaHunt then return huntStep(boat, keep) end
			S.Status = "Sea Event: waiting for an event"
			task.wait(1)
			return
		end
		if not seenKinds[t.obj] then
			seenKinds[t.obj] = true
			V3.webhook("Sea Event: " .. t.label, "Fighting it now")
		end
		watchSea(t)
		local stand = V3.seaStand(t, seaLift())
		S.Status = ("Sea Event: %s%s"):format(t.label, seaLift() > 0 and " (dodging)" or "")
		if (root.Position - stand).Magnitude > 120 then
			tweenTo(CFrame.new(stand), keep)
		else
			setFloat(true)
			-- زیر قایق نگاه عمودی می‌شه و lookAt خراب می‌شه
			root.CFrame = seaFruitM1(t) and CFrame.new(stand) or CFrame.lookAt(stand, t.part.Position)
		end
		attackSea(t)
		task.wait(S.SeaAttack == "M1 Spam" and 0.07 or 0.15)
	end

	-- اسکن دریا: اسم و جای همه‌ی هدف‌های ممکن توی فایل، برای وقتی که اسمی رو نمی‌شناسیم
	function V3.seaScan()
		local root = getRoot()
		local lines = { os.date("%H:%M:%S") .. "  danger " .. tostring(dangerLevel()) .. "  island " .. tostring(math.floor(select(2, nearestIsland(root.Position)) or -1)) }
		local function dump(folder)
			for _, o in ipairs(folder and folder:GetChildren() or {}) do
				local part = o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Engine") or o.PrimaryPart
				if part and (part.Position - root.Position).Magnitude < 5000 then
					local hv = o:FindFirstChild("Health")
					local h = o:FindFirstChildWhichIsA("Humanoid")
					local owner = o:FindFirstChild("Owner")
					table.insert(lines, ("%s | %s | d=%d y=%d | hp=%s | owner=%s"):format(folder.Name, o.Name, (part.Position - root.Position).Magnitude,
						part.Position.Y, tostring(hv and hv.Value or (h and math.floor(h.Health))), tostring(owner and owner.Value)))
				end
			end
		end
		for _, n in ipairs({ "SeaBeasts", "Boats", "Enemies" }) do dump(workspace:FindFirstChild(n)) end
		return pcall(function() writefile("bmscan/sea_scan.txt", table.concat(lines, "\n")) end), #lines - 1
	end

	local sea3 = function() return Sea == 3 end
	local findPrehistoric = stepFind("AutoFindPrehistoric", "Prehistoric Island", "EventBoat", prehistoricUp)
	V3.findPrehistoric = findPrehistoric -- ماژول Volcano وقتی جزیره نیست ازش برای گشت استفاده می‌کنه
	V3.register("AutoFireHeart", stepHeart, sea3)
	V3.register("AutoSeaEvent", stepSeaEvent, function() return Sea == 2 or Sea == 3 end)
	-- Auto Sea Beast (کلید قدیمی v2) حالا با همین موتور: شکار + فقط Sea Beast
	function V3.seaBeastStep(keep)
		focus = "beast"
		local ok, err = pcall(stepSeaEvent, keep)
		focus = nil
		if not ok then error(err, 0) end
	end
	-- فقط Terrorshark (برای کوئست Draco V3): همون شکار با Danger Level
	function V3.sharkStep(keep)
		focus = "shark"
		local ok, err = pcall(stepSeaEvent, keep)
		focus = nil
		if not ok then error(err, 0) end
	end
	V3.register("AutoFindLeviathan", stepFind("AutoFindLeviathan", "Leviathan", "BoatChoice", leviathanUp), sea3)
	V3.register("AutoFindPrehistoric", findPrehistoric, sea3)
end)
if not okSea then logError("v3 sea", errSea) end
end

-- ===== 20_volcano.lua =====
---------------------------------------------------------------------
-- v3 · Volcano: Prehistoric Island کامل (Magnet، کوئست Dragon Hunter، تخم اژدها، Golem، صخره‌ی آتشفشان)
-- مسیرها و اسم‌ها از بررسی Banana Cat؛ Instant Kill (دست‌کاری Humanoid) عمداً پورت نشده
---------------------------------------------------------------------
do
local okVol, errVol = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({
		RemoveLava = true, GolemWeapon = "Melee", VolcanoWeapon = "Blox Fruit", IgnoreMagnet = false,
	}) do
		if S[k] == nil then S[k] = v end
	end

	local function island()
		local m = workspace:FindFirstChild("Map")
		return m and m:FindFirstChild("PrehistoricIsland")
	end

	local function timerVisible(name)
		local ok, vis = pcall(function() return player.PlayerGui.Main.TopHUDList[name].Visible end)
		return ok and vis == true
	end
	local function eventRunning() return timerVisible("PrehistoricRaidTimer") or timerVisible("RaidTimer") end

	local function npcPart(name)
		for _, f in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
			local n = f and f:FindFirstChild(name)
			if n then return n:FindFirstChild("HumanoidRootPart") or n.PrimaryPart end
		end
	end

	-- نزدیک‌ترین ماب زنده از لیست رو می‌کشه؛ اگه لود نیست میره سمت اسپاون‌شون. false = هیچ جا پیداشون نکرد
	local function farmMobs(names, keep)
		local root = getRoot()
		local best, bd
		for _, n in ipairs(names) do
			local m = findMob(n)
			if m then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = m, d end
			end
		end
		if best then
			killMob(best, keep)
			return true
		end
		for _, n in ipairs(names) do
			local c = spawnCentroid(n)
			if c then
				S.Status = "Looking for " .. n
				tweenTo(CFrame.new(c + Vector3.new(0, 60, 0)), keep)
				task.wait(1)
				return true
			end
		end
		return false
	end

	V3.farmMobs = farmMobs

	-- کش اینونتوری (20 ثانیه) رو بعد از 5 ثانیه باطل می‌کنیم تا شمارش تازه باشه ولی سرور اسپم نشه
	local function count(name)
		if tick() - inventoryTime > 5 then inventoryTime = 0 end
		return materialCount(name)
	end
	V3.volcanoCount = materialCount -- برای لیبل UI: همون کش عادی

	-----------------------------------------------------------------
	-- کوئست Dragon Hunter (Blaze Ember) و ساخت Volcanic Magnet
	-----------------------------------------------------------------
	local questText
	local function fetchQuest()
		local rf = Net and Net:FindFirstChild("RF/DragonHunter")
		if not rf then return nil end
		for _, ctx in ipairs({ "Check", "RequestQuest" }) do
			local ok, r = pcall(function() return rf:InvokeServer({ Context = ctx }) end)
			if ok and type(r) == "table" and r.Text then return r.Text end
		end
	end

	-- تکه‌ی Ember که روی نقشه ظاهر میشه (اسمش رو دقیق نمی‌دونیم؛ هر چیزی که Ember داره و Part داره)
	local ignoredEmber = setmetatable({}, { __mode = "k" })
	local function findEmber()
		for _, parent in ipairs({ workspace, workspace:FindFirstChild("_WorldOrigin") }) do
			if parent then
				for _, c in ipairs(parent:GetChildren()) do
					if not ignoredEmber[c] and c.Name:find("Ember") and c:FindFirstChild("Part") then return c end
				end
			end
		end
	end

	-- همه‌ی اسکیل‌ها (Z X C V) رو خودش می‌زنه، حتی اگه سوییچ‌های اسکیل خاموش باشن (برای سنگ و درخت)
	local skillAt = 0
	local function pressAllSkills()
		if tick() - skillAt < 0.5 then return end
		skillAt = tick()
		for _, k in ipairs({ "Z", "X", "C", "V" }) do V3.key(Enum.KeyCode[k]) end
	end

	-- درخت‌های کوئست Dragon Hunter (از Banana): درخت سالم یه مش «Meshes/plant1_Icosphere» داره و به وسطش
	-- نشونه می‌گیریم؛ تنه‌ی بی‌برگ رو 20 پایین‌تر می‌زنیم. شکسته‌ها AlreadyDestroyedClient می‌گیرن.
	-- اسم و جای خود مدل درخت تأیید نشده؛ هر مدلی که اون مش رو داره درخت حساب میشه (Scan Trees می‌نویسه کجان)
	local TREE_MESH = "Meshes/plant1_Icosphere"
	local trees = setmetatable({}, { __mode = "k" })
	local ignoredTree = setmetatable({}, { __mode = "k" })
	local treeScanAt = -100
	local function scanTrees(force)
		if not force and tick() - treeScanAt < 30 then return end
		treeScanAt = tick()
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name == TREE_MESH then
				local m = d:FindFirstAncestorWhichIsA("Model")
				if m and m ~= workspace then trees[m] = true end
			end
		end
	end
	local function treeAlive(m)
		return m.Parent ~= nil and not m:GetAttribute("AlreadyDestroyedClient")
	end
	local function findTree()
		scanTrees()
		local root = getRoot()
		local best, bd
		for m in pairs(trees) do
			if not ignoredTree[m] and treeAlive(m) then
				local d = (m:GetPivot().Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = m, d end
			end
		end
		return best
	end
	function V3.scanTrees()
		scanTrees(true)
		local root = getRoot()
		local lines = { os.date("%H:%M:%S") .. "  quest: " .. tostring(V3.dragonQuestText) }
		for m in pairs(trees) do
			local p = m:GetPivot().Position
			table.insert(lines, ("%s | d=%d | pos=%d,%d,%d | destroyed=%s"):format(m:GetFullName(),
				root and (p - root.Position).Magnitude or -1, p.X, p.Y, p.Z, tostring(m:GetAttribute("AlreadyDestroyedClient"))))
		end
		pcall(function() writefile("bmscan/trees.txt", table.concat(lines, "\n")) end)
		return #lines - 1
	end

	-- یه درخت رو تا 15 ثانیه با اسکیل می‌زنه (مثل Banana)
	local function chopTree(tree, keep)
		ignoredTree[tree] = true
		local t0 = tick()
		while keep() and alive() and treeAlive(tree) and tick() - t0 < 15 do
			local pivot = tree:GetPivot()
			local leafy = V3.findDesc(tree, TREE_MESH) ~= nil
			local aim = leafy and pivot.Position or (pivot * CFrame.new(0, -20, 0)).Position
			local stand = aim + Vector3.new(6, 8, 0)
			local root = getRoot()
			if (root.Position - stand).Magnitude > 10 then
				tweenTo(CFrame.new(stand), keep)
			else
				setFloat(true)
				equipWeapon(S.VolcanoWeapon)
				V3.aimClick(aim)
				pressAllSkills()
			end
			task.wait(0.15)
		end
		V3.aimRelease()
	end

	local function stepQuest(keep)
		local npc = npcPart("Dragon Hunter")
		local root = getRoot()
		if not questText then
			if not npc then
				S.Status = "Dragon Hunter: NPC not found"
				task.wait(2)
				return false
			end
			if (npc.Position - root.Position).Magnitude > 8 then
				S.Status = "Dragon Hunter: going to the NPC"
				tweenTo(npc.CFrame * CFrame.new(0, 4, 4), keep)
				return true
			end
			questText = fetchQuest()
			if not questText then task.wait(2) end
			return true
		end
		local ember = findEmber()
		if ember then
			ignoredEmber[ember] = true
			S.Status = "Dragon Hunter: collecting an ember"
			local t0 = tick()
			while keep() and ember.Parent and tick() - t0 < 15 and alive() do
				local p = ember:FindFirstChild("Part")
				if not p then break end
				tweenTo(p.CFrame, keep)
				task.wait(0.2)
			end
			return true
		end
		if questText:find("Hydra Enforcers") then
			S.Status = "Dragon Hunter: Hydra Enforcers"
			farmMobs({ "Hydra Enforcer" }, keep)
		elseif questText:find("Venomous Assailants") then
			S.Status = "Dragon Hunter: Venomous Assailants"
			farmMobs({ "Venomous Assailant" }, keep)
		elseif questText:lower():find("tree") then
			local tree = findTree()
			if tree then
				S.Status = "Dragon Hunter: breaking a tree"
				chopTree(tree, keep)
			else
				S.Status = "Dragon Hunter: no tree found (press Scan Trees)"
				V3.log("TREE none found, quest=" .. tostring(questText))
				task.wait(3)
			end
		else
			S.Status = "Dragon Hunter: unknown quest, re-requesting"
			V3.log("DRAGONHUNTER unknown quest: " .. tostring(questText))
			questText = nil
			task.wait(3)
		end
		V3.dragonQuestText = questText
		-- کوئست تموم شد؟ از سرور دوباره بپرس
		if tick() - (V3.lastQuestCheck or 0) > 20 then
			V3.lastQuestCheck = tick()
			questText = fetchQuest()
		end
		return true
	end

	-- true = کار این قدم انجام شد (یا منتظریم)؛ false = Magnet آماده‌ست
	local function stepMagnet(keep)
		if hasItem("Volcanic Magnet") then return false end
		local scrap, ember = count("Scrap Metal"), count("Blaze Ember")
		if scrap < 10 then
			S.Status = ("Magnet: Scrap Metal %d/10"):format(scrap)
			if not farmMobs({ "Jungle Pirate", "Musketeer Pirate" }, keep) then task.wait(2) end
		elseif ember < 15 then
			S.Status = ("Magnet: Blaze Ember %d/15"):format(ember)
			stepQuest(keep)
		else
			S.Status = "Magnet: crafting"
			local rf = Net and Net:FindFirstChild("RF/Craft")
			if rf then pcall(function() rf:InvokeServer("Craft", "Volcanic Magnet", 1, {}) end) end
			inventoryTime = 0
			task.wait(2)
		end
		return true
	end

	-----------------------------------------------------------------
	-- خود رویداد جزیره
	-----------------------------------------------------------------
	local function removeLava(isl, core)
		pcall(function()
			for _, d in ipairs(isl:GetDescendants()) do
				if d.Name == "TouchInterest" and d.Parent and d.Parent.Name ~= "TrialTeleport" then d:Destroy() end
			end
		end)
		pcall(function()
			local lava = core:FindFirstChild("InteriorLava")
			if lava then lava:ClearAllChildren() end
		end)
	end

	local function nextEgg(core)
		local eggs = core:FindFirstChild("SpawnedDragonEggs")
		for _, e in ipairs(eggs and eggs:GetChildren() or {}) do
			if e.Name == "DragonEgg" and e:FindFirstChild("Molten") and e.Molten:FindFirstChild("ProximityPrompt") then return e end
		end
	end

	local function findGolem()
		local enemies = workspace:FindFirstChild("Enemies")
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if m.Name:lower():find("golem") and isAliveMob(m) then return m end
		end
	end

	-- صخره‌ای که باید درست بشه: VFXLayer.Specs فعاله (کش 1.5 ثانیه چون GetDescendants سنگینه)
	local rockCache = { t = 0 }
	local function findRock(isl)
		if tick() - rockCache.t < 1.5 then return rockCache.v end
		rockCache.t = tick()
		rockCache.v = nil
		for _, d in ipairs(isl:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Name == "Specs" and d.Enabled and d.Parent and d.Parent.Name == "VFXLayer" then
				rockCache.v = d.Parent.Parent
				break
			end
		end
		return rockCache.v
	end

	local announced = false
	local function stepIsland(keep)
		local isl = island()
		local core = isl and isl:FindFirstChild("Core")
		if not core then
			task.wait(1)
			return
		end
		if not announced then
			announced = true
			V3.webhook("Prehistoric Island", "Island is up — running the event")
		end
		local root = getRoot()
		if player:GetAttribute("CurrentLocation") ~= "Prehistoric Island" then
			local p = npcPart("Fossil Expert")
			if p then
				S.Status = "Volcano: heading to the island"
				tweenTo(p.CFrame, keep)
				return
			end
		end
		if S.RemoveLava and tick() - (V3.lavaAt or 0) > 5 then
			V3.lavaAt = tick()
			removeLava(isl, core)
		end
		local egg = nextEgg(core)
		if egg then
			S.Status = "Volcano: collecting a dragon egg"
			tweenTo(egg.Molten.CFrame, keep)
			if (getRoot().Position - egg.Molten.Position).Magnitude < 8 then
				V3.activate(egg.Molten.ProximityPrompt)
				task.wait(0.5)
			end
			return
		end
		if not eventRunning() then
			local act = core:FindFirstChild("ActivationPrompt")
			if act and act:FindFirstChild("ProximityPrompt") then
				S.Status = "Volcano: starting the event"
				tweenTo(act.CFrame, keep)
				if (getRoot().Position - act.Position).Magnitude < 8 then
					V3.activate(act.ProximityPrompt)
					task.wait(3)
				end
				return
			elseif not core:FindFirstChild("FossilExpertSpawn") then
				local p = npcPart("Fossil Expert")
				if p then
					tweenTo(p.CFrame, keep)
					return
				end
			end
			S.Status = "Volcano: event finished / waiting"
			task.wait(1)
			return
		end
		local golem = findGolem()
		if golem then
			S.Status = "Volcano: fighting the golem"
			local saved = S.Weapon
			S.Weapon = S.GolemWeapon
			local ok, err = pcall(killMob, golem, keep)
			S.Weapon = saved
			if not ok then error(err, 0) end
			return
		end
		local rock = findRock(isl)
		if rock then
			S.Status = "Volcano: fixing the lava rock"
			local pos = rock:GetPivot().Position
			local stand = CFrame.new(pos + Vector3.new(0, 14, 0))
			if (root.Position - stand.Position).Magnitude > 8 then
				tweenTo(stand, keep)
			else
				setFloat(true)
				equipWeapon(S.VolcanoWeapon)
				V3.aimClick(pos)
				-- قبلاً useSkills بود که با سوییچ‌های اسکیل خاموش هیچی نمی‌زد
				pressAllSkills()
			end
			return
		end
		V3.aimRelease()
		local skull = core:FindFirstChild("PrehistoricRelic") and core.PrehistoricRelic:FindFirstChild("Skull")
		if skull and (root.Position - skull.Position).Magnitude > 200 then
			S.Status = "Volcano: back to the center"
			tweenTo(skull.CFrame, keep)
		else
			S.Status = "Volcano: waiting for the next wave"
			task.wait(1)
		end
	end

	local function stepVolcano(keep)
		if V3.newMap and not V3.newMap() then
			V3.notify("Prehistoric Island", "Needs the new Sea 3 map (Tiki Outpost)", 6)
			S.AutoVolcano = false
			return
		end
		if island() then
			stepIsland(keep)
			return
		end
		announced = false
		if not S.IgnoreMagnet and not hasItem("Volcanic Magnet") then
			stepMagnet(keep)
		elseif V3.findPrehistoric then
			V3.findPrehistoric(keep)
		end
	end

	local sea3 = function() return Sea == 3 end
	-- متریال مصرف می‌کنن؛ ذخیره نمیشن تا خودکار روشن نشن
	V3.register("AutoVolcano", stepVolcano, sea3, true)
	V3.register("AutoCraftMagnet", function(keep)
		if not stepMagnet(keep) then
			V3.notify("Volcanic Magnet", "Crafted ✔ (switch turned off)", 6)
			S.AutoCraftMagnet = false
		end
	end, sea3, true)
	V3.register("AutoDragonHunter", stepQuest, sea3)
	V3.npcPart, V3.farmMobs = npcPart, farmMobs -- برای ماژول Draco
end)
if not okVol then logError("v3 volcano", errVol) end
end

-- ===== 30_trials.lua =====
---------------------------------------------------------------------
-- v3 · Trials: Trial نژاد (Temple of Time)، Race V4، Observation V2، Ghoul، Rainbow Haki
-- Cyborg عمداً نیست (Fist of Darkness / Core Brain / Order خیلی حالت داره و بدون تست درست درنمیاد)
---------------------------------------------------------------------
do
local okTr, errTr = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ TrialPressT = true }) do
		if S[k] == nil then S[k] = v end
	end

	local TEMPLE_POS = Vector3.new(28282.57, 14896.85, 105.10)
	local TRIAL_LOCATIONS = { "Trial of Strength", "Trial of the King", "Trial of Water", "Trial of Speed", "Trial of Carnage" }

	local function location(name)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local l = wo and wo:FindFirstChild("Locations")
		return l and l:FindFirstChild(name)
	end
	local function temple()
		local m = workspace:FindFirstChild("Map")
		return m and m:FindFirstChild("Temple of Time")
	end
	local function raidTimer()
		local ok, vis = pcall(function() return player.PlayerGui.Main.TopHUDList.RaidTimer.Visible end)
		return ok and vis == true
	end
	V3.raidTimer = raidTimer
	-- کدوم Trial الان نزدیکمونه (کمتر از 1000 استاد)
	local function nearTrial()
		local root = getRoot()
		if not root then return nil end
		for _, n in ipairs(TRIAL_LOCATIONS) do
			local p = location(n)
			if p and (p.Position - root.Position).Magnitude <= 1000 then return n, p end
		end
	end

	local function raceTask(race, name, loc, keep)
		local root = getRoot()
		if race == "Human" or race == "Ghoul" then
			-- ماب‌های Trial: هر ماب زنده‌ای که کنار جای Trial هست
			local best, bd
			local enemies = workspace:FindFirstChild("Enemies")
			for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
				if isAliveMob(m) and (m.HumanoidRootPart.Position - loc.Position).Magnitude < 900 then
					local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
					if not bd or d < bd then best, bd = m, d end
				end
			end
			if best then killMob(best, keep) else task.wait(0.5) end
		elseif race == "Skypiea" then
			local fin
			pcall(function() fin = workspace.Map.SkyTrial.Model.FinishPart end)
			if fin then
				tweenTo(fin.CFrame, keep)
				task.wait(3)
			end
		elseif race == "Fishman" then
			local list = V3.seaTargets and V3.seaTargets() or {}
			local t = list[1]
			if t and (t.part.Position - loc.Position).Magnitude < 1500 then
				local stand = CFrame.new(t.part.Position + Vector3.new(0, S.SeaHover, 0))
				if (root.Position - stand.Position).Magnitude > 90 then
					tweenTo(stand, keep)
				else
					setFloat(true)
					root.CFrame = CFrame.lookAt(stand.Position, t.part.Position)
				end
				V3.attackSea(t)
			else
				task.wait(0.5)
			end
		elseif race == "Mink" then
			local sp = workspace:FindFirstChild("StartPoint")
			if sp then tweenTo(sp.CFrame * CFrame.new(0, 2, 0), keep) end
			task.wait(0.3)
		else
			-- Cyborg و بقیه: وسط معبد منتظر می‌مونیم
			tweenTo(CFrame.new(TEMPLE_POS), keep)
			task.wait(0.5)
		end
	end

	local lastT = 0
	local function stepTrial(keep)
		local race = dataValue("Race")
		if raidTimer() then
			local name, loc = nearTrial()
			if not name then
				S.Status = "Trial: waiting for the teleport"
				task.wait(0.5)
				return
			end
			S.Status = "Trial: " .. tostring(race) .. " (" .. name .. ")"
			raceTask(race, name, loc, keep)
			return
		end
		local t = temple()
		if not t then
			S.Status = "Trial: flying to the Temple of Time"
			tweenTo(CFrame.new(TEMPLE_POS), keep)
			return
		end
		local corridor = t:FindFirstChild(tostring(race) .. "Corridor")
		local door = corridor and corridor:FindFirstChild("Door") and corridor.Door:FindFirstChild("Door")
		door = door and door:FindFirstChild("RightDoor") and door.RightDoor:FindFirstChild("Union")
		if not door then
			S.Status = "Trial: no corridor found for race " .. tostring(race)
			task.wait(2)
			return
		end
		local border = t:FindFirstChild("FFABorder")
		local ff = border and border:FindFirstChild("Forcefield")
		if ff and ff.Transparency ~= 1 and (getRoot().Position - door.Position).Magnitude > 200 then
			S.Status = "Trial: temple is closed (needs the full moon night)"
		else
			S.Status = "Trial: going to the door"
		end
		if (getRoot().Position - door.Position).Magnitude > 8 then
			tweenTo(door.CFrame, keep)
		elseif S.TrialPressT and tick() - lastT > 5 then
			lastT = tick()
			V3.key(Enum.KeyCode.T)
		else
			task.wait(0.5)
		end
	end

	-----------------------------------------------------------------
	-- Race V4: پیشرفت مرحله‌ای (Begin / Teleport / Continue)
	-----------------------------------------------------------------
	local function stepV4(keep)
		local r = invoke("RaceV4Progress", "Check")
		if r == 1 then
			S.Status = "Race V4: beginning"
			invoke("RaceV4Progress", "Begin")
			task.wait(2)
		elseif r == 2 then
			local spot = Vector3.new(3032.78, 2280.85, -7325.48)
			S.Status = "Race V4: going to the teleport spot"
			tweenTo(CFrame.new(spot), keep)
			if (getRoot().Position - spot).Magnitude < 8 then
				invoke("RaceV4Progress", "Teleport")
				task.wait(2)
			end
		elseif r == 3 then
			S.Status = "Race V4: continuing"
			invoke("RaceV4Progress", "Continue")
			task.wait(2)
		else
			S.Status = "Race V4: nothing to do right now (" .. tostring(r) .. ")"
			task.wait(3)
		end
	end

	-----------------------------------------------------------------
	-- Pull Lever (از Banana): با Valkyrie Helm + Mirror Fractal، اهرم معبد Temple of Time رو می‌کشه.
	-- در بسته باشه: اول قدم‌های Race V4، بعد Mirage (شب Blue Gear، روز بلندترین نقطه برای ماه).
	-- Banana جای «کشیده‌نشده»ی اهرم رو از قبل می‌دونه؛ ما بعد از زدن Prompt نگاه می‌کنیم اهرم جابه‌جا شد یا نه.
	-----------------------------------------------------------------
	local leverTries = 0
	local function findLever()
		local t = temple()
		local lv = t and V3.findDesc(t, "Lever")
		if lv and not lv:FindFirstChildWhichIsA("ProximityPrompt", true) and lv.Parent and lv.Parent.Name == "Lever" then lv = lv.Parent end
		return lv
	end
	local function pivotOf(o)
		if not o then return nil end
		if o:IsA("BasePart") then return o.CFrame end
		if o:IsA("Model") then return o:GetPivot() end
	end
	local function leverDone(msg)
		V3.notify("Pull Lever", msg .. " (switch turned off)", 8)
		V3.log("LEVER " .. msg)
		S.AutoPullLever = false
		leverTries = 0
	end
	V3.leverDone = leverDone

	local function stepLever(keep)
		if not hasItem("Valkyrie Helm") then
			V3.notify("Pull Lever", "Needs Valkyrie Helm (Rip Indra) + Mirror Fractal (Dough King)", 8)
			S.AutoPullLever = false
			return
		end
		if invoke("CheckTempleDoor") then
			local lv = findLever()
			if not lv then
				S.Status = "Pull Lever: flying to the Temple of Time"
				tweenTo(CFrame.new(TEMPLE_POS), keep)
				task.wait(1)
				return
			end
			local prompt = lv:FindFirstChildWhichIsA("ProximityPrompt", true)
			local part = lv:FindFirstChild("Part") or (prompt and prompt.Parent:IsA("BasePart") and prompt.Parent) or lv:FindFirstChildWhichIsA("BasePart", true)
			if not prompt or not prompt.Enabled then return leverDone("Lever already pulled ✔") end
			if (getRoot().Position - part.Position).Magnitude > 10 then
				S.Status = "Pull Lever: going to the lever"
				tweenTo(part.CFrame, keep)
				return
			end
			local handle = lv:FindFirstChild("Lever") or part
			local before = pivotOf(handle)
			S.Status = "Pull Lever: pulling"
			V3.activate(prompt)
			task.wait(2)
			leverTries += 1
			local after = pivotOf(handle)
			local moved = before and after and ((after.Position - before.Position).Magnitude > 0.3
				or (after.LookVector - before.LookVector).Magnitude > 0.05)
			if moved or not prompt.Parent or not prompt.Enabled then
				leverDone("Lever pulled ✔")
			elseif leverTries >= 3 then
				leverDone("Pressed the lever 3 times but it didn't move; check it in the game")
			end
			return
		end
		-- در معبد بسته‌ست
		local r = invoke("RaceV4Progress", "Check")
		if r == 1 or r == 2 or r == 3 then return stepV4(keep) end
		if Hub.MirageModel and Hub.MirageModel() then
			local gear = Hub.FindGear and Hub.FindGear()
			if gear then
				S.Status = "Pull Lever: taking the Blue Gear"
				tweenTo(gear.CFrame * CFrame.new(0, 4, 0), keep)
				task.wait(1)
				return
			end
			local top = Hub.MirageTop and Hub.MirageTop()
			if top then
				S.Status = "Pull Lever: on top of Mirage (look at the moon at night)"
				tweenTo(CFrame.new(top + Vector3.new(0, 5, 0)), keep)
				setFloat(true)
				task.wait(2)
				return
			end
		end
		S.Status = "Pull Lever: temple door closed, waiting for Mirage Island (Teleport → Find Mirage)"
		task.wait(5)
	end

	-----------------------------------------------------------------
	-- Observation V2: کوئست Citizen (Forest Pirate → Captain Elephant → Ken → میوه‌ها)
	-----------------------------------------------------------------
	local KEN_NPC = Vector3.new(-12441.59, 331.49, -7676.20)
	local function questTitle()
		local ok, t = pcall(function()
			local q = player.PlayerGui.Main.Quest
			return q.Visible and q.Container.QuestTitle.Title.Text
		end)
		return ok and t or ""
	end

	local function toKenNpc(keep)
		local root = getRoot()
		if (root.Position - KEN_NPC).Magnitude < 10 then
			invoke("StartQuest", "CitizenQuest", 1)
			task.wait(1)
		else
			tweenTo(CFrame.new(KEN_NPC), keep)
		end
	end

	local function stepKenQuest(keep)
		local phase = invoke("CitizenQuestProgress", "Citizen")
		if phase == 0 then
			local title = questTitle()
			if title:find("Forest Pirate") and title:find("50") then
				S.Status = "Observation V2: Forest Pirates"
				V3.farmMobs({ "Forest Pirate" }, keep)
			else
				toKenNpc(keep)
			end
		elseif phase == 1 then
			local title = questTitle()
			if title:find("Captain Elephant") then
				if findMobAnywhere("Captain Elephant") then
					S.Status = "Observation V2: Captain Elephant"
					fightBoss("Captain Elephant", keep)
				else
					S.Status = "Observation V2: waiting for Captain Elephant"
					task.wait(5)
				end
			else
				toKenNpc(keep)
			end
		elseif phase == 2 then
			S.Status = "Observation V2: going to Ken"
			tweenTo(CFrame.new(-12513.8, 336.167, -9872.91), keep)
			task.wait(1)
		elseif phase == 3 then
			local n = tonumber((tostring(invoke("KenTalk", "Status") or ""):gsub("%D", ""))) or 0
			if n >= 5000 then
				invoke("KenTalk2", "Start")
				local hasBowl = backpackTool("Fruit Bowl") ~= nil
				local hasThree = (dataValue("Beli") or 0) >= 5000000 and backpackTool("Pineapple") and backpackTool("Apple") and backpackTool("Banana")
				if hasBowl or hasThree then
					S.Status = "Observation V2: buying the upgrade"
					invoke("CitizenQuestProgress", "Citizen")
					invoke("KenTalk2", "Buy")
					task.wait(2)
				else
					S.Status = "Observation V2: collecting fruits"
					local root = getRoot()
					for _, nm in ipairs({ "PineappleSpawner", "BananaSpawner", "AppleSpawner" }) do
						local sp = workspace:FindFirstChild(nm)
						local tool = sp and sp:FindFirstChildOfClass("Tool")
						if tool and tool:FindFirstChild("Handle") and firetouchinterest then
							pcall(function() firetouchinterest(root, tool.Handle, 0) end)
						end
					end
					task.wait(3)
				end
			else
				-- تمرین Ken: کنار Marine Commodore می‌مونیم و Observation (E) روشن میشه
				S.Status = ("Observation V2: Ken training (%d/5000)"):format(n)
				local boss = findMob("Marine Commodore")
				local blur = Lighting:FindFirstChild("Blur")
				if blur and blur.Enabled and boss then
					tweenTo(boss.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3), keep)
				else
					if boss then tweenTo(boss.HumanoidRootPart.CFrame * CFrame.new(0, 0, 50), keep) end
					V3.key(Enum.KeyCode.E)
					task.wait(2)
				end
			end
		else
			V3.notify("Observation V2", "Quest state: " .. tostring(phase) .. " (switch turned off)", 6)
			S.AutoKenQuest = false
		end
	end

	-----------------------------------------------------------------
	-- Ghoul (دریای 2): 100 Ectoplasm + Hellfire Torch
	-----------------------------------------------------------------
	local TORCH_SPOT = Vector3.new(918.62, 122.20, 33454.38)
	local function stepGhoul(keep)
		if dataValue("Race") == "Ghoul" or invoke("Ectoplasm", "BuyCheck", 4, true) == 2 then
			V3.notify("Ghoul", "Already a Ghoul (switch turned off)", 6)
			S.AutoGetGhoul = false
			return
		end
		if (materialCount("Ectoplasm") or 0) < 100 then
			S.Status = ("Ghoul: Ectoplasm %d/100"):format(materialCount("Ectoplasm") or 0)
			if not V3.farmMobs({ "Ship Deckhand", "Ship Steward", "Ship Officer", "Ship Engineer" }, keep) then task.wait(2) end
		elseif hasItem("Hellfire Torch") then
			S.Status = "Ghoul: buying the transformation"
			tweenTo(CFrame.new(TORCH_SPOT), keep)
			if (getRoot().Position - TORCH_SPOT).Magnitude < 15 then
				invoke("Ectoplasm", "BuyCheck", 4)
				invoke("Ectoplasm", "Buy", 4)
				task.wait(2)
			end
		elseif findMobAnywhere("Cursed Captain") then
			S.Status = "Ghoul: killing Cursed Captain (Hellfire Torch)"
			fightBoss("Cursed Captain", keep)
		else
			S.Status = "Ghoul: waiting for Cursed Captain to spawn"
			task.wait(5)
		end
	end

	-----------------------------------------------------------------
	-- Rainbow Haki (Horned Man): باس‌های کوئست رو می‌کشه و Bet می‌زنه
	-----------------------------------------------------------------
	local RAINBOW_BOSSES = { "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate" }
	local lastBet = 0
	local function stepRainbow(keep)
		if invoke("HornedMan") == 1 then
			V3.notify("Rainbow Haki", "Done ✔ (switch turned off)", 6)
			S.AutoRainbowHaki = false
			return
		end
		for _, b in ipairs(RAINBOW_BOSSES) do
			if findMobAnywhere(b) then
				S.Status = "Rainbow Haki: " .. b
				fightBoss(b, keep)
				return
			end
		end
		local npc
		for _, f in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
			local n = f and f:FindFirstChild("Horned Man")
			npc = npc or (n and (n:FindFirstChild("HumanoidRootPart") or n.PrimaryPart))
		end
		if npc and (getRoot().Position - npc.Position).Magnitude > 8 then
			S.Status = "Rainbow Haki: going to the Horned Man"
			tweenTo(npc.CFrame, keep)
		elseif npc and tick() - lastBet > 10 then
			lastBet = tick()
			S.Status = "Rainbow Haki: turning in"
			invoke("HornedMan", "Bet")
		else
			S.Status = "Rainbow Haki: waiting for a boss to spawn"
			task.wait(3)
		end
	end

	local sea3 = function() return Sea == 3 end
	V3.register("AutoTrial", stepTrial, sea3)
	V3.register("AutoRaceV4", stepV4, sea3)
	V3.register("AutoPullLever", stepLever, sea3, true)
	-- بلی/آیتم خرج می‌کنن؛ ذخیره نمیشن تا خودکار روشن نشن
	V3.register("AutoKenQuest", stepKenQuest, sea3, true)
	V3.register("AutoRainbowHaki", stepRainbow, sea3, true)
	V3.register("AutoGetGhoul", stepGhoul, function() return Sea == 2 end, true)
end)
if not okTr then logError("v3 trials", errTr) end
end

-- ===== 40_extras.lua =====
---------------------------------------------------------------------
-- v3 · Extras: وبهوک دیسکورد + اعلان رویدادها، Kitsune Island، Azure Ember
-- ماهی‌گیری و آپگرید اینونتوری Banana Cat به UI خود بازی وابسته‌ان و پورت نشدن
---------------------------------------------------------------------
do
local okEx, errEx = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ AutoKitsunePray = false, AzureEmberNeed = 1 }) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.AutoKitsunePray = true -- Azure Ember مصرف می‌کنه

	-- هر چیز جدیدی که توی سرور ظاهر بشه (رویدادها، ماه کامل، Sea Beast) یک بار به دیسکورد میره
	task.spawn(function()
		local seen, first = {}, true
		while Hub.Running do
			pcall(function()
				local now = {}
				for _, obj in pairs(Hub.Events or {}) do now[obj.Name] = true end
				if Hub.FullMoonNight and Hub.FullMoonNight() then now["Full Moon Night"] = true end
				if V3.leviathanUp and V3.leviathanUp() then now["Frozen Dimension (Leviathan)"] = true end
				local sb = workspace:FindFirstChild("SeaBeasts")
				if sb and #sb:GetChildren() > 0 then now["Sea Beast"] = true end
				for label in pairs(now) do
					if not seen[label] and not first then V3.webhook("World Event", label .. " is in this server") end
				end
				seen, first = now, false
			end)
			task.wait(5)
		end
	end)

	-----------------------------------------------------------------
	-- Kitsune Island: شب ماه کامل با قایق میری نقطه‌ی مشخص و منتظر می‌مونی
	-----------------------------------------------------------------
	local SPOT = Vector3.new(-32975.99, 0, 25963.71 + 1000)
	local function kitsuneUp() return Hub.Events ~= nil and Hub.Events.kitsune ~= nil end

	local function stepKitsune(keep)
		if V3.newMap and not V3.newMap() then
			V3.notify("Kitsune Island", "Needs the new Sea 3 map (Tiki Outpost)", 6)
			S.AutoKitsuneSpawn = false
			return
		end
		if kitsuneUp() then
			V3.notify("Kitsune Island", "Spawned! (switch turned off)", 8)
			V3.webhook("Kitsune Island", "Spawned in this server")
			S.AutoKitsuneSpawn = false
			return
		end
		if not (Hub.FullMoonNight and Hub.FullMoonNight()) then
			S.Status = "Kitsune: waiting for a full moon night"
			task.wait(2)
			return
		end
		local t = Lighting.ClockTime
		local nightNow = t >= 18 or t < 5
		local b = V3.myBoat and V3.myBoat()
		local nearSpot = b ~= nil and V3.flatDist(b.VehicleSeat.Position, SPOT) <= 200
		if nearSpot and not nightNow then
			-- قبل از ساعت 18: بالای نقطه توی آسمون منتظر می‌مونیم (از هیولاهای دریا دوریم)
			S.Status = "Kitsune: waiting in the sky for 18:00"
			tweenTo(CFrame.new(SPOT + Vector3.new(0, 2000, 0)), keep)
			task.wait(1)
			return
		end
		local boat = V3.ensureBoat(S.EventBoat, keep)
		if not boat then return end
		if V3.flatDist(boat.VehicleSeat.Position, SPOT) > 200 then
			S.Status = "Kitsune: sailing to the spawn spot"
			V3.sail(boat, SPOT, keep, kitsuneUp)
		else
			S.Status = "Kitsune: waiting at the spot"
			task.wait(1)
		end
	end
	V3.register("AutoKitsuneSpawn", stepKitsune, function() return Sea == 3 end)

	-- Pray کردن کنار مجسمه وقتی Trial فعاله و Azure Ember کافی داری
	task.spawn(function()
		while Hub.Running do
			task.wait(5)
			if S.AutoKitsunePray and alive() and V3.raidTimer and V3.raidTimer()
				and (materialCount("Azure Ember") or 0) >= S.AzureEmberNeed then
				local rf = Net and Net:FindFirstChild("RF/KitsuneStatuePray")
				if rf then
					pcall(function() rf:InvokeServer() end)
					task.wait(5)
				end
			end
		end
	end)
end)
if not okEx then logError("v3 extras", errEx) end
end

-- ===== 50_brain.lua =====
---------------------------------------------------------------------
-- v3 · Brain: مغز مرکزی BM
-- خلبان خودکار (بین فرصت‌های سرور و هدف اصلی تصمیم می‌گیره)، یادگیری از مرگ‌ها،
-- جاخالی یادگرفته از انیمیشن باس‌ها، نگهبان گیر کردن، اسکیل و ترنسفورم هوشمند، Chest Hop
-- ایده‌ها از Banana: جاخالی انیمیشن Sea Beast، Awakening با RaceEnergy، شمارش صندوق و هاپ، Tween Safe
---------------------------------------------------------------------
do
local okBrain, errBrain = pcall(function()
	local V3 = Hub.V3
	local BRAIN_FILE = "BMHub_brain.json"
	-- بعد از تلپورت: اگه لانچر سریع محلی هست (بدون معطلی دانلود) از همون، وگرنه از GitHub
	local LOADER = (isfile and select(2, pcall(isfile, "bm.lua")) == true) and 'loadstring(readfile("bm.lua"))()'
		or 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()'
	for k, v in pairs({
		BrainOn = false, BrainGoal = "Auto Farm", BrainBosses = true, BrainEvents = true, BrainElite = true, BrainFruits = true,
		BrainSeas = false, BrainDeaths = 2,
		Watchdog = true, WatchdogSec = 45,
		SmartDodge = true, DodgeHeight = 70, DodgeLearn = 12, DodgeAfter = 2,
		SmartSkills = true, SmartRace = false, SmartRetreat = true, DeathTime = 3, FruitM1 = true,
		ChestHop = false, ChestHopAt = 20, SafeCarry = true,
		HeightDefault = false, -- یک بار Farm Height قدیمی (12) رو 25 می‌کنه؛ build_v3 بعد از لود تنظیمات
		-- ارتفاع یادگرفته برای هر نوع سلاح (100 = هنوز محدودیتی ندیدیم)
		HeightCapMelee = 100, HeightCapSword = 100, HeightCapFruit = 100, HeightCapGun = 100,
	}) do
		if S[k] == nil then S[k] = v end
	end

	-----------------------------------------------------------------
	-- ارتفاع هوشمند: لاگ بازی نشون داد از 25 استاد بالاتر سرور ضربه‌ی Melee رو قبول نمی‌کنه (dmg/s=0)،
	-- ولی از 12 استاد ضربه می‌خوره. اگه 8 ثانیه از Farm Height ضربه نخورد، برای همون نوع سلاح
	-- 6 استاد پایین میاد (تا حداقل 10) و یادش می‌مونه؛ تازه اگه از 10 هم نخورد ماب رد میشه
	-----------------------------------------------------------------
	local CAP_KEY = { Melee = "HeightCapMelee", Sword = "HeightCapSword", ["Blox Fruit"] = "HeightCapFruit", Gun = "HeightCapGun" }
	local MIN_HEIGHT, HEIGHT_STEP = 10, 6
	local function capKey()
		local c = getChar()
		local t = c and c:FindFirstChildOfClass("Tool")
		return t and CAP_KEY[t.ToolTip], t and t.Name
	end
	function Hub.HeightCap()
		local k = capKey()
		return k and S[k] or 100
	end
	function Hub.LowerHeight()
		local k, tool = capKey()
		if not k then return false end
		local cur = math.min(S.FarmHeight, S[k])
		if cur <= MIN_HEIGHT then return false end
		local new = math.max(MIN_HEIGHT, cur - HEIGHT_STEP)
		S[k] = new
		if Hub.LiveLog then Hub.LiveLog(("HEIGHT no damage from %d studs with %s, trying %d"):format(cur, tostring(tool), new)) end
		if Hub.SaveSettings then pcall(Hub.SaveSettings) end
		return true
	end
	-- وقتی خودت Farm Height رو عوض کنی، یادگرفته‌ها پاک میشن تا دوباره امتحان کنه
	function Hub.ResetHeightCaps()
		for _, k in pairs(CAP_KEY) do S[k] = 100 end
	end

	local Brain = { since = 0, why = "Off", log = {}, ban = {}, deaths = {}, deathTotal = 0, dodges = 0, rescues = 0 }
	Hub.Brain = Brain

	function Brain.note(msg)
		table.insert(Brain.log, 1, os.date("%H:%M:%S ") .. msg)
		while #Brain.log > 5 do table.remove(Brain.log) end
		V3.log("brain: " .. msg)
	end

	local function level() return dataValue("Level") or 0 end
	local function banned(key) return (Brain.ban[key] or 0) > tick() end

	-----------------------------------------------------------------
	-- آمار جلسه: فقط افزایش‌ها جمع میشن (Exp با لول‌آپ صفر میشه، Beli با خرید کم میشه)
	-----------------------------------------------------------------
	local earned, lastValue, statsStart = { Exp = 0, Beli = 0, Fragments = 0 }, {}, tick()
	function Brain.track()
		for k in pairs(earned) do
			local v = dataValue(k)
			if type(v) == "number" then
				if lastValue[k] and v > lastValue[k] then
					earned[k] += v - lastValue[k]
					if Brain.onIncome then Brain.onIncome(k, v - lastValue[k]) end
				end
				lastValue[k] = v
			end
		end
	end
	function Brain.perHour(k)
		return earned[k] / (math.max(tick() - statsStart, 60) / 3600)
	end
	function Brain.resetStats()
		statsStart = tick()
		for k in pairs(earned) do earned[k] = 0 end
	end
	task.spawn(function()
		while Hub.Running do
			pcall(Brain.track)
			task.wait(5)
		end
	end)

	-- Fist of Darkness / God's Chalice با مرگ یا خروج از سرور از دست میرن
	function Brain.carrying()
		return backpackTool("Fist of Darkness") or backpackTool("God's Chalice")
	end
	function Hub.CarryBlock()
		local t = S.SafeCarry and Brain.carrying()
		if not t then
			V3.resetOnce("carry")
			return false
		end
		V3.once("carry", function() V3.notify("Safe Carry", t.Name .. " in backpack: chests paused so you don't lose it", 8) end)
		return true
	end

	-- اگه executor اجازه بده هاب بعد از تلپورت خودش برمی‌گرده (یک بار برای هر تلپورت)
	local reloadQueued = false
	function Hub.QueueReload()
		if reloadQueued then return end
		reloadQueued = true
		if Hub.SaveSettings then Hub.SaveSettings() end
		local queueTp = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
		if queueTp then pcall(queueTp, LOADER) end
	end
	function Hub.ReloadFailed() reloadQueued = false end

	-- سرور کم‌جمعیت = صندوق دست‌نخورده‌ی بیشتر
	function Brain.hop()
		Hub.QueueReload()
		return serverHop(true)
	end

	-----------------------------------------------------------------
	-- قانون‌ها: بالاتر = مهم‌تر. هر قانون یک کلید از S رو روشن می‌کنه و بقیه‌ی کلیدهای مدیریت‌شده خاموش میشن
	-- urgent: کار فعلی رو همون لحظه قطع می‌کنه. maxRun/rest: اگه طول کشید یه مدت کنار میره
	-----------------------------------------------------------------
	local rules, managed = {}, {}
	local function addRule(r)
		managed[r.flag] = true
		if not r.sea or r.sea == Sea then table.insert(rules, r) end
	end

	local CASTLE = Vector3.new(-5100, 315, -3000) -- همون نقطه‌ی stepPirateRaid
	local ELITES = { "Diablo", "Deandre", "Urban", "Tyrant of the Skies" }

	local function raidMobCount()
		local n = 0
		local enemies = workspace:FindFirstChild("Enemies")
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - CASTLE).Magnitude < 900 then n += 1 end
		end
		return n
	end

	-- پرلول‌ترین باس اسپاون‌شده‌ای که از پسش برمیایم و قبلاً زیاد نکشتتمون
	local function bossWorthFighting()
		local my, best, bestLv = level(), nil, -1
		for _, name in ipairs(bossNames()) do
			local b = not banned(name) and findMobAnywhere(name)
			if b then
				local lv = mobLevel(b) or 0
				if lv <= my * 1.05 + 10 and lv > bestLv then best, bestLv = name, lv end
			end
		end
		return best
	end

	addRule({ id = "PirateRaid", label = "Pirate Raid", flag = "AutoPirateRaid", sea = 3, opt = "BrainEvents", urgent = true,
		why = "raiders at Castle on the Sea",
		want = function() return raidMobCount() >= 3 end })
	addRule({ id = "Factory", label = "Factory", flag = "AutoFactory", sea = 2, opt = "BrainEvents", urgent = true,
		why = "Factory Core is open",
		want = function() return findMobAnywhere("Core") ~= nil end })
	for _, b in ipairs(Hub.Special or {}) do
		addRule({ id = b.id, label = b.label, flag = "Kill" .. b.id, sea = b.sea, opt = "BrainBosses", urgent = true,
			why = b.label .. " spawned",
			want = function() return Hub.SpecialSpawned(b) ~= nil end })
	end
	addRule({ id = "Darkbeard", label = "Darkbeard", flag = "AutoDarkbeard", sea = 2, opt = "BrainBosses", urgent = true,
		why = "Darkbeard is up or you carry a Fist of Darkness",
		want = function()
			return level() >= 1000 and (backpackTool("Fist of Darkness") ~= nil or findMobAnywhere("Darkbeard") ~= nil)
		end })
	addRule({ id = "Elite", label = "Elite Hunter", flag = "AutoElite", sea = 3, opt = "BrainElite", maxRun = 300, rest = 120,
		why = "an Elite spawned",
		want = function()
			for _, n in ipairs(ELITES) do
				if findMobAnywhere(n) then return true end
			end
			return false
		end })
	addRule({ id = "Fruit", label = "Fruit Pickup", flag = "AutoFruit", opt = "BrainFruits", urgent = true, maxRun = 60, rest = 180,
		why = "a fruit is on the map",
		want = function() return getWorldFruits()[1] ~= nil end })
	addRule({ id = "WorldBoss", label = "World Boss", flag = "AutoBoss", opt = "BrainBosses", maxRun = 300, rest = 120,
		why = "a boss you can beat spawned",
		want = function()
			local name = bossWorthFighting()
			Brain.bossTarget = name
			return name ~= nil
		end,
		enter = function() S.SelectedBoss = Brain.bossTarget end,
		target = function() return Brain.bossTarget end })
	addRule({ id = "Sea2", label = "Go To Sea 2", flag = "AutoSea2", sea = 1, opt = "BrainSeas", maxRun = 1800, rest = 900,
		why = "level 700 reached",
		want = function() return level() >= 700 end })
	addRule({ id = "Sea3", label = "Go To Sea 3", flag = "AutoSea3", sea = 2, opt = "BrainSeas", maxRun = 1800, rest = 900,
		why = "level 1500 reached",
		want = function() return level() >= 1500 end })

	-- هدف اصلی: وقتی هیچ فرصتی توی سرور نیست همین اجرا میشه
	local GOALS = {
		{ name = "Auto Farm", flag = "AutoFarm" },
		{ name = "Chests", flag = "AutoChest" },
		{ name = "Ectoplasm", flag = "AutoEcto", sea = 2 },
		{ name = "Bones", flag = "AutoBone", sea = 3 },
		{ name = "Cake Prince", flag = "AutoCake", sea = 3 },
		{ name = "Elite Hunter", flag = "AutoElite", sea = 3, noBest = true },
		{ name = "Sea Events", flag = "AutoSeaEvent", seas = { [2] = true, [3] = true }, noBest = true },
	}
	local function goalFits(g)
		if g.seas then return g.seas[Sea] == true end
		return not g.sea or g.sea == Sea
	end
	for _, g in ipairs(GOALS) do managed[g.flag] = true end
	Brain.extraGoals = {} -- هدف‌های پویا (Planner اضافه می‌کنه)
	function Brain.goalNames()
		local out = {}
		for _, g in ipairs(GOALS) do
			if goalFits(g) then table.insert(out, g.name) end
		end
		for _, n in ipairs(Brain.extraGoals) do table.insert(out, n) end
		return out
	end
	-- هدف‌هایی که می‌شه درآمدشون رو با هم مقایسه کرد
	function Brain.goalCandidates()
		local out = {}
		for _, g in ipairs(GOALS) do
			if goalFits(g) and not g.noBest then table.insert(out, g.name) end
		end
		return out
	end
	function Brain.goalByName(name)
		local g = GOALS[1]
		for _, c in ipairs(GOALS) do
			if c.name == name and goalFits(c) then g = c end
		end
		g.id, g.label, g.goal, g.why = "Goal" .. g.name, g.name, true, "nothing better to do right now"
		g.want = function() return true end
		return g
	end
	-- کلیدی که Planner موقتاً دست مغز میده
	function Brain.claim(flag) managed[flag] = true end
	local function goalRule()
		return (Brain.dynamicGoal and Brain.dynamicGoal(S.BrainGoal)) or Brain.goalByName(S.BrainGoal)
	end

	-- بعضی کارها چند مرحله‌ای‌ان (CDK، Tushita و...): اگه خودت روشنشون کردی مغز وسطشون نمی‌پره
	local LONG_JOBS = { "AutoPumpkin", "AutoRengoku", "AutoTrident", "AutoRaid", "AutoBartilo", "AutoSaber", "AutoYama", "AutoTushita", "AutoCDK",
		"AutoRaceV2", "AutoRaceV3", "AutoSoulGuitar", "AutoStyles", "AutoSeaBeast", "AutoMaterial", "AutoStylePlan" }
	local function longJobRunning()
		for _, f in ipairs(LONG_JOBS) do
			if S[f] and not managed[f] then return f end
		end
		for _, t in ipairs(Hub.V3Tasks) do
			if S[t.flag] and not managed[t.flag] and (not t.cond or t.cond()) then return t.flag end
		end
		for _, b in ipairs(Hub.Special or {}) do
			if S["Summon" .. b.id] then return "Summon" .. b.id end
		end
	end

	function Brain.usable(r)
		if r.opt and not S[r.opt] then return false end
		if not r.goal and banned(r.id) then return false end
		return r.want()
	end

	-- اولین قانون قابل‌اجرا؛ کار غیرفوری فعلی تا 15 ثانیه عوض نمیشه تا مغز بین دو کار رفت‌وبرگشت نکنه
	function Brain.choose()
		local pick
		for _, r in ipairs(rules) do
			if Brain.usable(r) then
				pick = r
				break
			end
		end
		pick = pick or goalRule()
		local cur = Brain.current
		if cur and pick.id ~= cur.id and not pick.urgent and tick() - Brain.since < 15 and not cur.goal and Brain.usable(cur) then
			return cur
		end
		return pick
	end

	-- فقط کلید کار انتخاب‌شده روشن می‌مونه
	function Brain.apply(pick)
		local stopped = false
		for f in pairs(managed) do
			local want = pick ~= nil and pick.flag == f
			if (S[f] == true) ~= want then
				if S[f] then stopped = true end
				S[f] = want
			end
		end
		if stopped then stopTween() end
	end

	function Brain.tick()
		local job = longJobRunning()
		if job then
			Brain.why = "Paused: " .. job .. " is on"
			if Brain.current then
				Brain.current = nil
				Brain.apply(nil)
			end
			return
		end
		local cur = Brain.current
		if cur and cur.maxRun and tick() - Brain.since > cur.maxRun then
			-- هر بار که دوباره طول بکشه استراحتش دو برابر میشه (تا 8 برابر)
			cur.rests = math.min((cur.rests or 0) + 1, 4)
			Brain.ban[cur.id] = tick() + cur.rest * 2 ^ (cur.rests - 1)
			Brain.note(cur.label .. " took too long, resting it")
			Brain.current, cur = nil, nil
		end
		local pick = Brain.choose()
		if not cur or pick.id ~= cur.id then
			Brain.current, Brain.since = pick, tick()
			Brain.note("→ " .. pick.label .. " (" .. pick.why .. ")")
		end
		-- هر بار: باس قبلی مرد؟ هدف جدید همینجا جایگزین میشه
		if pick.enter then pick.enter() end
		Brain.why = pick.why
		Brain.apply(pick)
	end

	-- موقع مرگ: اگه یه هدف چند بار توی 10 دقیقه کشتمون، 15 دقیقه ردش می‌کنیم
	function Brain.onDeath()
		Brain.deathTotal += 1
		local cur = Brain.current
		if not S.BrainOn or not cur or cur.goal then return end
		local key = cur.target and cur.target() or cur.id
		local now, recent = tick(), {}
		for _, t in ipairs(Brain.deaths[key] or {}) do
			if now - t < 600 then table.insert(recent, t) end
		end
		table.insert(recent, now)
		Brain.deaths[key] = recent
		if #recent >= S.BrainDeaths then
			Brain.ban[key] = now + 900
			Brain.deaths[key] = nil
			Brain.note(tostring(key) .. " killed you " .. #recent .. "x, avoiding it for 15 min")
			V3.notify("Brain", tostring(key) .. " is too strong right now, skipping it", 6)
		end
	end

	local savedFlags
	task.spawn(function()
		local wasOn, firstLoop = false, true
		while Hub.Running do
			task.wait(1.5)
			if S.BrainOn and not wasOn then
				savedFlags = { SelectedBoss = S.SelectedBoss }
				-- اگه با تنظیمات ذخیره‌شده روشن شده، کلیدهای روشن مال خود مغز بودن نه کاربر
				for f in pairs(managed) do savedFlags[f] = S[f] == true and not firstLoop end
				Brain.current, Brain.since = nil, 0
				Brain.note("Brain on")
			elseif wasOn and not S.BrainOn then
				Brain.current = nil
				Brain.why = "Off"
				stopTween()
				for f in pairs(managed) do S[f] = savedFlags ~= nil and savedFlags[f] == true end
				S.SelectedBoss = savedFlags and savedFlags.SelectedBoss
				Brain.note("Brain off, your switches are back")
			end
			wasOn, firstLoop = S.BrainOn, false
			if S.BrainOn and alive() then
				local ok, err = pcall(Brain.tick)
				if not ok then
					logError("Brain", err)
					task.wait(2)
				end
			end
		end
	end)

	-----------------------------------------------------------------
	-- جاخالی یادگرفته: Banana لیست ثابت انیمیشن Sea Beast داره؛ اینجا خود BM یاد می‌گیره
	-- اگه درست بعد از یه انیمیشن ضربه‌ی سنگین خوردیم، دفعه‌های بعد با دیدن همون انیمیشن میریم بالا
	-----------------------------------------------------------------
	Hub.DodgeY = 0
	local danger, recentAnims, dirty, dodgeEnd = {}, {}, false, 0
	Brain.danger = danger
	-- v=2: نسخه‌ی قبلی ضربه‌ی ماب‌های معمولی رو هم یاد می‌گرفت، اون داده دور ریخته میشه
	Brain.store = { v = 2, danger = danger, ledger = {}, fruit = {} } -- هر چیزی که مغز یاد می‌گیره و باید بمونه
	pcall(function()
		if isfile and not isfile(BRAIN_FILE) then return end
		local d = Svc.Http:JSONDecode(readfile(BRAIN_FILE))
		if d.v == 2 then
			for id, v in pairs(d.danger or {}) do danger[id] = v end
		end
		if type(d.ledger) == "table" then Brain.store.ledger = d.ledger end
		if type(d.fruit) == "table" then Brain.store.fruit = d.fruit end
	end)
	function Brain.markDirty() dirty = true end

	function Brain.learnedCount()
		local n = 0
		for _, d in pairs(danger) do
			if d.n >= S.DodgeAfter then n += 1 end
		end
		return n
	end
	function Brain.forget()
		table.clear(danger)
		dirty = true
	end

	function Brain.learnHit()
		local now = tick()
		for id, r in pairs(recentAnims) do
			if now - r.t > 10 then
				recentAnims[id] = nil
			elseif now - r.t <= 2.5 and not r.counted then
				r.counted = true
				local d = danger[id] or { n = 0, mob = r.mob }
				d.n += 1
				danger[id] = d
				dirty = true
				if d.n == S.DodgeAfter then Brain.note("Learned a dangerous attack of " .. tostring(d.mob)) end
			end
		end
	end

	function Brain.dodge(track)
		local hold = math.clamp(track.Length > 0 and track.Length or 2, 1.2, 4)
		Brain.dodges += 1
		dodgeEnd = math.max(dodgeEnd, tick() + hold)
		Hub.DodgeY = S.DodgeHeight
		task.delay(hold, function()
			if tick() >= dodgeEnd - 0.05 then Hub.DodgeY = 0 end
		end)
	end

	-- فقط باس‌ها: ضربه‌ی عادی ماب‌ها هم سنگینه و اگه ازشون جاخالی بدیم از برد حمله بیرون می‌مونیم
	local bossSet, bossSetAt = {}, 0
	function Brain.isBoss(mob)
		if mob.Name:find("[Boss]", 1, true) then return true end
		-- هیولاهای دریا هم مثل باس: ضربه‌ی سنگین دارن و ارزش یاد گرفتن
		if mob.Name == "Terrorshark" or (mob.Parent and mob.Parent.Name == "SeaBeasts") then return true end
		if tick() - bossSetAt > 30 then
			bossSetAt = tick()
			table.clear(bossSet)
			for _, n in ipairs(bossNames()) do bossSet[n] = true end
			for _, n in ipairs(ELITES) do bossSet[n] = true end
			for _, b in ipairs(Hub.Special or {}) do
				for _, n in ipairs(b.names) do bossSet[n] = true end
			end
		end
		return bossSet[mobBaseName(mob.Name)] == true
	end

	local watched = setmetatable({}, { __mode = "k" })
	function Hub.WatchMob(mob, hum)
		if not S.SmartDodge or not hum or watched[hum] or not Brain.isBoss(mob) then return end
		watched[hum] = true
		local name = mobBaseName(mob.Name)
		pcall(function()
			hum.AnimationPlayed:Connect(function(track)
				if not Hub.Running or not S.SmartDodge or track.Looped then return end
				local id = track.Animation and track.Animation.AnimationId
				if not id then return end
				recentAnims[id] = { t = tick(), mob = name }
				local d = danger[id]
				if d and d.n >= S.DodgeAfter then Brain.dodge(track) end
			end)
		end)
	end

	-- فرار هوشمند: درصد ثابت جلوی باس‌های قوی دیر میشه؛ از دمیج 3 ثانیه‌ی اخیر زمان تا مرگ رو حساب می‌کنیم
	local hits = {}
	function Brain.recordHit(drop)
		table.insert(hits, { t = tick(), drop = drop })
		while #hits > 0 and tick() - hits[1].t > 3 do table.remove(hits, 1) end
	end
	function Hub.InDanger(hp)
		if not S.SmartRetreat then return false end
		local sum = 0
		for _, h in ipairs(hits) do
			if tick() - h.t <= 3 then sum += h.drop end
		end
		return sum > 0 and hp / (sum / 3) < S.DeathTime
	end

	local function hookCharacter(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then return end
		local hp = hum.Health
		connect(hum.HealthChanged, function(h)
			local drop = hp - h
			hp = h
			if drop <= 0 or hum.MaxHealth <= 0 then return end
			Brain.recordHit(drop)
			local pct = drop / hum.MaxHealth * 100
			if S.SmartDodge and pct >= S.DodgeLearn then Brain.learnHit() end
			if Brain.onHeavyHit then Brain.onHeavyHit(pct) end
		end)
		connect(hum.Died, Brain.onDeath)
	end
	connect(player.CharacterAdded, hookCharacter)
	if player.Character then task.spawn(hookCharacter, player.Character) end

	task.spawn(function()
		while Hub.Running do
			task.wait(30)
			if dirty then
				dirty = false
				pcall(function() writefile(BRAIN_FILE, Svc.Http:JSONEncode(Brain.store)) end)
			end
		end
	end)

	-----------------------------------------------------------------
	-- جنگ هوشمند: اسکیل و ترنسفورم فقط وقتی می‌ارزه (باس یا حداقل 3 ماب)
	-----------------------------------------------------------------
	local function fightWorthIt()
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not root or not enemies then return false end
		local n = 0
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= S.AttackRange then
				if Brain.isBoss(m) then return true end
				n += 1
			end
		end
		return n >= 3
	end
	Brain.fightWorthIt = fightWorthIt

	-- M1 میوه: ابزار میوه‌هایی که حمله‌ی کلیکی دارن یه LeftClickRemote داره (از Banana)
	-- جهت سمت ماب و شماره‌ی ضربه‌ی کمبو (1 تا 4) فرستاده میشه. سرور ضربه‌های زیادی رو رد می‌کنه
	-- (لاگ Dragon-Dragon: فاصله‌ی 0.1 نصف فاصله‌ی 0.2 دمیج داد)، پس برای هر میوه یه بار چند فاصله
	-- با دمیج واقعی سنجیده میشه و بهترین نگه داشته میشه. کلیک روی صفحه و انیمیشن نداره
	-- melee: میوه‌هایی که M1 شمشیری دارن (Light، Ice ...) مثل ملی با ضربه‌ی چندهدفه‌ی RegisterHit، بدون کلیک
	local FRUIT_MODES = { { gap = 0.2 }, { gap = 0.3 }, { gap = 0.5 }, { gap = 0.8 }, { melee = true } }
	-- Ice از اینجا دراومد: ضربه‌ی ملی (روش Light) توی بازی برای Ice دمیج نداد، پس Ice مثل بقیه
	-- همه‌ی حالت‌ها رو با دمیج واقعی تست می‌کنه و بهترین رو نگه می‌داره
	local SWORD_LIKE = { ["Light-Light"] = true }
	local RETEST = { ["Ice-Ice"] = true } -- melee ذخیره‌شده‌ی قدیمی این‌ها تست نشده بود
	local TUNE_SECONDS = 8
	local tune
	local fruitCombo, fruitAt = 0, 0
	-- میوه‌ی بدون LeftClickRemote (مثل Ice الان) از مسیر عادی می‌زنه: ضربه‌ی ملی + کلیک ابزار.
	-- 5.4 فقط ضربه‌ی ملی می‌زد و توی بازی M1 ایس اصلاً کار نکرد
	function Brain.heldFruitM1()
		local char = getChar()
		local tool = char and char:FindFirstChildOfClass("Tool")
		local remote = tool and tool:FindFirstChild("LeftClickRemote")
		return remote and tool, remote
	end

	local function fruitMode(tool)
		-- بدون LeftClickRemote فقط ضربه‌ی ملی معنی داره
		if not tool:FindFirstChild("LeftClickRemote") then return { melee = true } end
		local saved = Brain.store.fruit[tool.Name]
		-- نتیجه‌ی نسخه‌های قبل که کلیک داشتن دیگه معتبر نیست
		if saved and saved.melee and RETEST[tool.Name] and not saved.tested then
			Brain.store.fruit[tool.Name], saved = nil, nil
			Brain.markDirty()
		end
		if saved and (saved.melee or (saved.gap and not saved.click and not saved.hit)) then return saved end
		-- میوه‌های شمشیری از اول مثل ملی؛ با Test This Fruit Again همه‌ی حالت‌ها سنجیده میشن
		if not saved and SWORD_LIKE[tool.Name] and not (tune and tune.tool == tool.Name) then
			Brain.store.fruit[tool.Name] = { melee = true }
			Brain.markDirty()
			return Brain.store.fruit[tool.Name]
		end
		if not tune or tune.tool ~= tool.Name then
			tune = { tool = tool.Name, i = 1, time = 0, damage = 0, mobs = 0, bestRate = -1 }
			Brain.note("Testing the best M1 for " .. tool.Name)
		end
		return FRUIT_MODES[tune.i]
	end

	-- حالت M1 ابزار توی دست رو برمی‌گردونه (nil یعنی میوه‌ی M1 دار دستت نیست)
	function Hub.FruitM1(root)
		if not S.FruitM1 then return nil end
		local tool, remote = Brain.heldFruitM1()
		if not tool then return nil end
		local mode = fruitMode(tool)
		if mode.melee then return mode end
		local mob = nearestMobInRange()
		if not mob or tick() - fruitAt < mode.gap then return mode end
		fruitAt = tick()
		fruitCombo = fruitCombo % 4 + 1
		local ok, err = pcall(function()
			remote:FireServer((mob.HumanoidRootPart.Position - root.Position).Unit, fruitCombo)
		end)
		if ok then
			Hub.AttackInfo.fruit = (Hub.AttackInfo.fruit or 0) + 1
		else
			Hub.AttackInfo.lastError = "fruit M1: " .. tostring(err)
		end
		return mode
	end

	-- هر نیم ثانیه‌ی جنگ با میوه: دمیج به ازای هر ماب حساب میشه تا تعداد ماب‌ها نتیجه رو خراب نکنه
	function Brain.tuneStep(drop, mobs)
		local held = Brain.heldFruitM1()
		if not tune or mobs == 0 or not held or held.Name ~= tune.tool then return end
		tune.time += 0.5
		tune.damage += drop
		tune.mobs += mobs
		if tune.time < TUNE_SECONDS then return end
		local mode = FRUIT_MODES[tune.i]
		local rate = tune.damage / TUNE_SECONDS / (tune.mobs / (TUNE_SECONDS * 2))
		V3.log(("FRUIT TEST %s %d/%d %s: %d dmg/s per mob"):format(tune.tool, tune.i, #FRUIT_MODES, mode.melee and "melee hit" or ("gap=" .. tostring(mode.gap)), math.floor(rate)))
		if rate > tune.bestRate then tune.best, tune.bestRate = mode, rate end
		tune.i += 1
		tune.time, tune.damage, tune.mobs = 0, 0, 0
		if tune.i > #FRUIT_MODES then
			local best = table.clone(tune.best)
			best.tested = true
			Brain.store.fruit[tune.tool] = best
			Brain.markDirty()
			Brain.note(("M1 test done for %s: %d dmg/s per mob"):format(tune.tool, math.floor(tune.bestRate)))
			V3.notify("Fruit M1", "Best mode found for " .. tune.tool, 5)
			tune = nil
		end
	end

	function Brain.fruitStatus(tool)
		if tune and tune.tool == tool.Name then return ("testing %d/%d, keep fighting"):format(tune.i, #FRUIT_MODES) end
		local m = Brain.store.fruit[tool.Name]
		if (m and m.melee) or not tool:FindFirstChild("LeftClickRemote") then return "melee hit like a sword, no screen clicks" end
		if not m or not m.gap or m.click or m.hit then return "will test on the first fight" end
		return ("every %.1fs, no screen clicks"):format(m.gap)
	end

	function Brain.retestFruit(tool)
		Brain.store.fruit[tool.Name] = nil
		Brain.markDirty()
		tune = { tool = tool.Name, i = 1, time = 0, damage = 0, mobs = 0, bestRate = -1 }
	end

	-- دمیج واقعی برای لاگ: جمع کم شدن جون ماب‌های نزدیک، تا سلاح‌ها با عدد مقایسه بشن
	local mobHp, damage, damageFrom = setmetatable({}, { __mode = "k" }), 0, tick()
	function Brain.sampleDamage()
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not root or not enemies then return end
		local drop, mobs = 0, 0
		for _, m in ipairs(enemies:GetChildren()) do
			local hum, hrp = m:FindFirstChildOfClass("Humanoid"), m:FindFirstChild("HumanoidRootPart")
			if hum and hrp and (hrp.Position - root.Position).Magnitude <= S.AttackRange + 20 then
				if mobHp[hum] and hum.Health < mobHp[hum] then drop += mobHp[hum] - hum.Health end
				mobHp[hum] = hum.Health
				if hum.Health > 0 then mobs += 1 end
			end
		end
		damage += drop
		Brain.tuneStep(drop, mobs)
	end
	function Hub.DamageRate()
		local rate = damage / math.max(tick() - damageFrom, 0.5)
		damage, damageFrom = 0, tick()
		return rate
	end
	task.spawn(function()
		while Hub.Running do
			pcall(Brain.sampleDamage)
			task.wait(0.5)
		end
	end)

	local nextSkill, skillAt = 1, 0
	local SKILL_ORDER = { "Z", "X", "C", "V" }
	function Hub.SmartSkill(mob, hum)
		if not S.SmartSkills or not S.UseSkills or not VIM or Hub.DodgeY > 0 or tick() - skillAt < 0.9 then return end
		skillAt = tick()
		if hum.MaxHealth <= 0 or hum.Health / hum.MaxHealth < 0.1 or not fightWorthIt() then return end
		for _ = 1, #SKILL_ORDER do
			local k = SKILL_ORDER[nextSkill]
			nextSkill = nextSkill % #SKILL_ORDER + 1
			if S["Skill" .. k] then
				-- موس رو روی ماب می‌بریم تا اسکیل سمت اون بره (دوربین دست نمی‌خوره)
				pcall(function()
					local hrp = mob:FindFirstChild("HumanoidRootPart")
					local v, onScreen = camera:WorldToViewportPoint(hrp.Position)
					if onScreen then VIM:SendMouseMoveEvent(v.X, v.Y, game) end
				end)
				V3.key(Enum.KeyCode[k])
				return
			end
		end
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			if S.SmartRace and alive() then
				pcall(function()
					local char = getChar()
					local energy, on = char:FindFirstChild("RaceEnergy"), char:FindFirstChild("RaceTransformed")
					if energy and on and energy.Value >= 1 and not on.Value and fightWorthIt() then
						local tool = player.Backpack:FindFirstChild("Awakening") or char:FindFirstChild("Awakening")
						if tool then tool.RemoteFunction:InvokeServer(true) end
					end
				end)
			end
		end
	end)

	-----------------------------------------------------------------
	-- نگهبان: وقتی فارم روشنه ولی نه جا عوض میشه، نه پول/XP میاد، نه جون ماب کم میشه، یعنی گیر کرده
	-----------------------------------------------------------------
	local PATIENT = { "wait", "not spawned", "closed", "need ", "no ", "heal", "summon", "checking", "hop" }
	local function patientStatus(st)
		for _, p in ipairs(PATIENT) do
			if st:find(p, 1, true) then return true end
		end
		return false
	end

	function Brain.softRescue()
		Brain.rescues += 1
		Brain.note("Stuck on '" .. tostring(S.Status) .. "', restarting movement")
		stopTween()
		setFloat(false)
		task.wait(0.3)
		-- اگه مغز روشنه این کار 2 دقیقه کنار میره تا سراغ کار بعدی بره
		local cur = Brain.current
		if S.BrainOn and cur and not cur.goal then Brain.ban[cur.id] = tick() + 120 end
	end

	function Brain.hardRescue()
		Brain.rescues += 1
		if Brain.carrying() then return Brain.note("Still stuck, not resetting because you carry a rare item") end
		Brain.note("Still stuck, resetting the character")
		pcall(function()
			getHum().Health = 0
			getChar():BreakJoints()
		end)
	end

	task.spawn(function()
		local sig, since, softDone = nil, tick(), false
		while Hub.Running do
			task.wait(3)
			if S.Watchdog and alive() and mainFarmBusy() then
				local p = getRoot().Position
				local st = tostring(S.Status):lower()
				local now = table.concat({ math.floor(p.X / 8), math.floor(p.Y / 8), math.floor(p.Z / 8), (st:gsub("%d+", "")),
					tostring(dataValue("Exp")), tostring(dataValue("Beli")), tostring(Hub.LastProgress) }, "|")
				if now ~= sig or patientStatus(st) then
					sig, since, softDone = now, tick(), false
				elseif not softDone and tick() - since > S.WatchdogSec then
					softDone = true
					Brain.softRescue()
				elseif tick() - since > S.WatchdogSec * 2 then
					sig, since, softDone = nil, tick(), false
					Brain.hardRescue()
				end
			else
				sig, since, softDone = nil, tick(), false
			end
		end
	end)

	-----------------------------------------------------------------
	-- Chest Hop: بعد از چند صندوق میره سرور کم‌جمعیت (مثل Value Collect Chest to Hop)
	-----------------------------------------------------------------
	Hub.ChestsTaken = 0
	task.spawn(function()
		while Hub.Running do
			task.wait(2)
			if S.ChestHop and S.AutoChest and Hub.ChestsTaken >= S.ChestHopAt and not Brain.carrying() then
				S.Status = "Chest Hop: " .. Hub.ChestsTaken .. " chests done, hopping"
				Brain.note("Chest Hop after " .. Hub.ChestsTaken .. " chests")
				pcall(Brain.hop)
				task.wait(15)
			end
		end
	end)

	Brain.ready = true
end)
if not okBrain then logError("v3 brain", errBrain) end
end

-- ===== 60_planner.lua =====
---------------------------------------------------------------------
-- v3 · Planner: برنامه‌ی حساب و یادگیری درآمد
-- Account Plan: قدم بعدی آیتم‌ها رو از اینونتوری خود بازی پیدا می‌کنه و همون رو اجرا می‌کنه
-- Best Income: درآمد واقعی هر کار رو می‌سنجه و پردرآمدترین رو نگه می‌داره
-- Smart Mastery (از Banana: Rarity توی getInventoryWeapons و LoadItem). Mastery واقعی فقط Level ابزارهای توی کوله‌ست
-- (inventory.txt بازی: getInventoryWeapons فیلد Mastery نداره)
-- به‌علاوه‌ی ردیاب آیتم، گزارش ساعتی، برگشت هاب بعد از تلپورت و PK Guard
---------------------------------------------------------------------
do
local okPlan, errPlan = pcall(function()
	local V3, Brain = Hub.V3, Hub.Brain
	if not (Brain and Brain.ready) then return end
	for k, v in pairs({
		BrainMetric = "Beli", BestTrial = 5, PlanStepMax = 40,
		SmartMastery = false, MasteryTarget = 350,
		LootWatch = true, HourlyReport = false, AutoReload = true, PKGuard = false,
	}) do
		if S[k] == nil then S[k] = v end
	end

	local Planner = { have = {}, mastery = {}, weapons = {}, skip = {}, seen = {}, needMastery = {}, loadTries = {}, scanned = false }
	Hub.Planner = Planner

	-----------------------------------------------------------------
	-- برنامه‌ی حساب: فقط قدم‌هایی که با داشتن آیتم تموم میشن و پول/آیتم خرج نمی‌کنن
	-----------------------------------------------------------------
	local STEPS = {
		{ id = "Saber", label = "Saber", sea = 1, minLv = 200, flag = "AutoSaber", have = "Saber" },
		{ id = "Rengoku", label = "Rengoku", sea = 2, minLv = 1350, flag = "AutoRengoku", have = "Rengoku" },
		{ id = "Trident", label = "Dragon Trident", sea = 2, minLv = 1475, flag = "AutoTrident", have = "Dragon Trident" },
		{ id = "Yama", label = "Yama", sea = 3, minLv = 1775, flag = "AutoYama", have = "Yama" },
		{ id = "Tushita", label = "Tushita", sea = 3, minLv = 2200, flag = "AutoTushita", have = "Tushita" },
		{ id = "CDK", label = "Cursed Dual Katana", sea = 3, flag = "AutoCDK", have = "Cursed Dual Katana",
			mastery = { Yama = 350, Tushita = 350 } },
	}
	local function seaSteps()
		local out = {}
		for _, s in ipairs(STEPS) do
			if s.sea == Sea then table.insert(out, s) end
		end
		return out
	end

	-- چرا الان نمیشه این قدم رو رفت (nil یعنی آماده‌ست)
	function Planner.blocked(s)
		if s.minLv and (dataValue("Level") or 0) < s.minLv then return "needs level " .. s.minLv end
		if (Planner.skip[s.id] or 0) > tick() then return "resting, it took too long" end
		for name, need in pairs(s.mastery or {}) do
			if not Planner.have[name] then return "needs " .. name end
			local m = Planner.mastery[name]
			if m == nil then return "checking the mastery of " .. name .. " (Smart Mastery loads it)" end
			if m < need then return ("needs %d mastery on %s"):format(need, name) end
		end
	end

	function Planner.nextStep()
		if not Planner.scanned then return nil end
		table.clear(Planner.needMastery)
		for _, s in ipairs(seaSteps()) do
			if not Planner.have[s.id] then
				if not Planner.blocked(s) then
					if Planner.stepId ~= s.id then Planner.stepId, Planner.stepSince = s.id, tick() end
					if tick() - Planner.stepSince <= S.PlanStepMax * 60 then return s end
					Planner.skip[s.id] = tick() + 1800
					Planner.stepId = nil
					Brain.note("Plan: " .. s.label .. " took too long, trying again in 30 min")
				else
					-- قدم فقط منتظر Mastery ـه: Smart Mastery باید همون شمشیرها رو بالا ببره
					for name, need in pairs(s.mastery or {}) do
						if Planner.have[name] and (Planner.mastery[name] or -1) < need then Planner.needMastery[name] = need end
					end
				end
			end
		end
	end

	function Planner.stepLine(i)
		local s = seaSteps()[i]
		if not s then return nil end
		if not Planner.scanned then return "· " .. s.label .. " (reading inventory...)" end
		if Planner.have[s.id] then return "✔ " .. s.label end
		local why = Planner.blocked(s)
		return (why and "· " or "→ ") .. s.label .. (why and " (" .. why .. ")" or "")
	end

	-----------------------------------------------------------------
	-- دفتر درآمد: هر کار چقدر پول/XP/Fragment آورده (بین اجراها می‌مونه)
	-----------------------------------------------------------------
	local function entry(label)
		local key = Sea .. ":" .. label
		local e = Brain.store.ledger[key]
		if not e then
			e = { t = 0, Exp = 0, Beli = 0, Fragments = 0 }
			Brain.store.ledger[key] = e
		end
		return e
	end
	Planner.entry = entry

	function Brain.onIncome(k, delta)
		if S.BrainOn and Brain.current then
			local e = entry(Brain.current.label)
			e[k] += delta
			Brain.markDirty()
		end
	end

	-- داده‌ی قدیمی کم‌کم وزنش کم میشه تا تغییر لول و آپدیت بازی رو دنبال کنه
	function Planner.addTime(label, dt)
		local e = entry(label)
		e.t += dt
		if e.t > 7200 then
			for k, v in pairs(e) do e[k] = v / 2 end
		end
	end

	function Planner.rate(label, metric)
		local e = entry(label)
		if e.t < 30 then return 0 end
		return e[metric] / e.t * 3600
	end

	function Planner.topJobs()
		local prefix, out = Sea .. ":", {}
		for key, e in pairs(Brain.store.ledger) do
			if key:sub(1, #prefix) == prefix and e.t >= 60 then
				local label = key:sub(#prefix + 1)
				table.insert(out, { label = label, rate = Planner.rate(label, S.BrainMetric), mins = e.t / 60 })
			end
		end
		table.sort(out, function(a, b) return a.rate > b.rate end)
		return out
	end

	-- کار بعدی: اول هر هدفی که هنوز به اندازه‌ی کافی امتحان نشده، بعد بهترین؛ هر 30 دقیقه یکی دوباره سنجیده میشه
	function Planner.bestGoal()
		local now = tick()
		if Planner.active and now < Planner.activeUntil then return Planner.active end
		local names, trial = Brain.goalCandidates(), S.BestTrial * 60
		local pick, hold, leastT, bestRate
		for _, n in ipairs(names) do
			local t = entry(n).t
			if t < trial and (not leastT or t < leastT) then pick, leastT, hold = n, t, trial end
		end
		if not pick then
			Planner.checkedAt = Planner.checkedAt or now
			if now - Planner.checkedAt > 1800 then
				Planner.checkedAt = now
				for _, n in ipairs(names) do
					if n ~= Planner.active and (not pick or (Planner.seen[n] or 0) < (Planner.seen[pick] or 0)) then pick = n end
				end
				hold = trial
			end
		end
		if not pick then
			for _, n in ipairs(names) do
				local r = Planner.rate(n, S.BrainMetric)
				if not bestRate or r > bestRate then pick, bestRate = n, r end
			end
			hold = 600
		end
		Planner.seen[pick] = now
		Planner.active, Planner.activeUntil = pick, now + hold
		return pick
	end

	table.insert(Brain.extraGoals, "Best Income")
	if #seaSteps() > 0 then table.insert(Brain.extraGoals, "Account Plan") end

	function Brain.dynamicGoal(name)
		if name == "Best Income" then
			local g = Brain.goalByName(Planner.bestGoal())
			g.why = ("best %s so far (%s/h)"):format(S.BrainMetric, formatNumber(math.floor(Planner.rate(g.label, S.BrainMetric))))
			return g
		end
		if name == "Account Plan" then
			-- قدم‌ها وقتی تموم بشن کلید خودشون رو خاموش می‌کنن؛ بدون این خط تا اسکن بعدی دوباره روشن میشد
			local cur = Brain.current
			if cur and cur.planStep and not S[cur.flag] then Planner.have[cur.planStep] = true end
			local s = Planner.nextStep()
			if s then
				Brain.claim(s.flag)
				return { id = "Plan" .. s.id, label = "Plan: " .. s.label, flag = s.flag, goal = true, planStep = s.id, why = "next step of your account plan" }
			end
		end
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(5)
			local cur = Brain.current
			if S.BrainOn and cur then pcall(Planner.addTime, cur.label, 5) end
		end
	end)

	-----------------------------------------------------------------
	-- Smart Mastery: اول شمشیرهایی که برنامه لازم داره، بعد با ارزش‌ترین شمشیر زیر هدف
	-----------------------------------------------------------------
	function Planner.pickMastery()
		local best, bestScore
		for _, w in ipairs(Planner.weapons) do
			local need = Planner.needMastery[w.Name]
			local m = Planner.mastery[w.Name]
			-- نامعلوم = هنوز لود نشده؛ لودش می‌کنیم تا Level خونده بشه (بعد از 3 بار بی‌نتیجه ول می‌کنیم)
			local usable = m ~= nil or (Planner.loadTries[w.Name] or 0) < 3
			if w.Type == "Sword" and usable and (m == nil or m < (need or S.MasteryTarget)) then
				local score = (need and 1000 or 0) + (tonumber(w.Rarity) or 0)
				if not bestScore or score > bestScore then best, bestScore = w, score end
			end
		end
		return best
	end

	function Planner.masteryWanted()
		return S.SmartMastery or (S.BrainOn and S.BrainGoal == "Account Plan" and next(Planner.needMastery) ~= nil)
	end

	function Planner.runMastery()
		local w = Planner.masteryWanted() and S.AutoFarm and Planner.pickMastery()
		if not w then
			if Planner.masteryName then
				Planner.masteryName = nil
				S.MasteryFarm = false
				Brain.note("Mastery goals reached")
			end
			return
		end
		if Planner.masteryName ~= w.Name then
			Planner.masteryName = w.Name
			Brain.note("Mastery: training " .. w.Name)
		end
		if not backpackTool(w.Name) then
			Planner.loadTries[w.Name] = (Planner.loadTries[w.Name] or 0) + 1
			invoke("LoadItem", w.Name)
		end
		S.MasteryFarm, S.MasteryWeapon = true, "Sword"
	end

	-----------------------------------------------------------------
	-- ردیاب آیتم: هر چیز تازه‌ای که به اینونتوری اضافه بشه خبر میده
	-----------------------------------------------------------------
	local knownItems
	function Planner.watchLoot(names)
		if not knownItems then
			knownItems = {}
			for n in pairs(names) do knownItems[n] = true end
			return
		end
		for n in pairs(names) do
			if not knownItems[n] then
				knownItems[n] = true
				if S.LootWatch then
					Brain.note("New item: " .. n)
					V3.notify("New Item", n, 8)
					V3.webhook("New Item", n .. " (" .. player.Name .. ")")
				end
			end
		end
	end

	-- اگه سرور جواب نده داده‌ی قبلی می‌مونه
	function Planner.scan()
		local r = invoke("getInventoryWeapons")
		if type(r) ~= "table" then return false end
		local weapons = {}
		for _, w in pairs(r) do
			if type(w) == "table" and w.Name then
				table.insert(weapons, w)
				if tonumber(w.Mastery) then Planner.mastery[w.Name] = tonumber(w.Mastery) end
			end
		end
		Planner.weapons = weapons
		-- دو تا جدا: اگه کاراکتر nil باشه ipairs روی { nil, کوله } اصلاً به کوله نمی‌رسه
		for _, cont in pairs({ char = getChar(), bp = player:FindFirstChild("Backpack") }) do
			for _, t in ipairs(cont:GetChildren()) do
				local lv = t:IsA("Tool") and t:FindFirstChild("Level")
				if lv and type(lv.Value) == "number" then Planner.mastery[t.Name] = lv.Value end
			end
		end
		for _, s in ipairs(seaSteps()) do
			Planner.have[s.id] = hasItem(s.have)
			for name in pairs(s.mastery or {}) do Planner.have[name] = hasItem(name) end
		end
		Planner.watchLoot(inventoryNames())
		Planner.scanned = true
		return true
	end

	task.spawn(function()
		while Hub.Running do
			pcall(Planner.scan)
			pcall(Planner.runMastery)
			task.wait(30)
		end
	end)

	-----------------------------------------------------------------
	-- گزارش ساعتی به دیسکورد
	-----------------------------------------------------------------
	function Planner.report()
		return ("Level %s  •  XP/h %s  •  Beli/h %s  •  Fragments/h %s  •  Deaths %d  •  Rescues %d"):format(
			tostring(dataValue("Level")), formatNumber(math.floor(Brain.perHour("Exp"))), formatNumber(math.floor(Brain.perHour("Beli"))),
			formatNumber(math.floor(Brain.perHour("Fragments"))), Brain.deathTotal, Brain.rescues)
	end
	task.spawn(function()
		local last = tick()
		while Hub.Running do
			task.wait(60)
			if S.HourlyReport and tick() - last >= 3600 then
				last = tick()
				pcall(function() V3.webhook("Hourly Report", Planner.report()) end)
			end
		end
	end)

	-----------------------------------------------------------------
	-- برگشت هاب بعد از هر تلپورت (Rejoin، Hop): Server Finder خودش این کار رو می‌کنه
	-----------------------------------------------------------------
	pcall(function()
		connect(player.OnTeleport, function(state)
			if state == Enum.TeleportState.Failed then
				Hub.ReloadFailed()
			elseif S.AutoReload and not S.HuntHop then
				Hub.QueueReload()
			end
		end)
	end)

	-----------------------------------------------------------------
	-- PK Guard: اگه ماب نزدیک نیست ولی یه بازیکن نزدیکه و دو ضربه خوردی، سرور عوض میشه
	-----------------------------------------------------------------
	local pkHits, pkHopAt = {}, 0
	function Planner.attackerNearby()
		local root = getRoot()
		if not root then return nil end
		local enemies = workspace:FindFirstChild("Enemies")
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude <= 60 then return nil end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - root.Position).Magnitude <= 120 then return p end
		end
	end

	function Brain.onHeavyHit(pct)
		if not S.PKGuard or pct < 15 then return end
		local attacker = Planner.attackerNearby()
		if not attacker then return end
		local now, recent = tick(), { tick() }
		for _, t in ipairs(pkHits) do
			if now - t < 20 then table.insert(recent, t) end
		end
		pkHits = recent
		if #recent >= 2 and now - pkHopAt > 30 and not Brain.carrying() then
			pkHopAt = now
			pkHits = {}
			Brain.note("PK Guard: leaving the server (" .. attacker.Name .. ")")
			task.spawn(Brain.hop)
		end
	end

	Planner.ready = true
end)
if not okPlan then logError("v3 planner", errPlan) end
end

-- ===== 70_styles.lua =====
---------------------------------------------------------------------
-- v3 · Styles: برنامه‌ی فایتینگ استایل تا Godhuman
-- هر بار حساب می‌کنه چی کمه (سبک پیش‌نیاز، Mastery، متریال، آیتم، پول) و همون رو انجام میده
-- پیش‌نیازها و قیمت‌ها از اطلاعات بازی؛ جواب واقعی سرور موقع خرید توی لاگ میره
-- خرید فقط با کلید Allow Buying؛ Mastery و متریال فقط فارم می‌کنن
---------------------------------------------------------------------
do
local okStyles, errStyles = pcall(function()
	local V3, Brain = Hub.V3, Hub.Brain
	if not (Brain and Brain.ready) then return end
	for k, v in pairs({ AutoStylePlan = false, StyleTarget = "Godhuman", StyleBuy = false }) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.StyleBuy = true -- پول خرج می‌کنه

	local Styles = {}
	Hub.Styles = Styles

	-- needs: سبک‌های پیش‌نیاز و Mastery لازم، mats: متریال، item: آیتم لازم، note: شرط دیگه
	local DEF = {
		["Black Leg"] = { beli = 150000 },
		["Electro"] = { beli = 500000 },
		["Fishman Karate"] = { beli = 750000 },
		["Dragon Claw"] = { frag = 1500 },
		["Superhuman"] = { beli = 3000000,
			needs = { { "Black Leg", 300 }, { "Electro", 300 }, { "Fishman Karate", 300 }, { "Dragon Claw", 300 } } },
		["Death Step"] = { beli = 2500000, frag = 5000, needs = { { "Black Leg", 400 } }, item = "Library Key" },
		["Sharkman Karate"] = { beli = 2500000, frag = 5000, needs = { { "Fishman Karate", 400 } }, item = "Water Key" },
		["Electric Claw"] = { beli = 3000000, frag = 5000, needs = { { "Electro", 400 } }, note = "also needs the Previous Hero quest" },
		["Dragon Talon"] = { beli = 3000000, frag = 5000, needs = { { "Dragon Claw", 400 } }, item = "Fire Essence" },
		["Godhuman"] = { beli = 5000000, frag = 5000, sea = 3, npc = "Ancient Monk",
			needs = { { "Superhuman", 400 }, { "Death Step", 400 }, { "Sharkman Karate", 400 }, { "Electric Claw", 400 }, { "Dragon Talon", 400 } },
			mats = { { "Fish Tail", 20 }, { "Magma Ore", 20 }, { "Dragon Scale", 10 }, { "Mystic Droplet", 10 } } },
	}
	Styles.DEF = DEF
	Styles.TARGETS = { "Superhuman", "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon", "Godhuman" }
	local ITEM_HINT = { ["Library Key"] = "drops from Awakened Ice Admiral (Sea 2)", ["Water Key"] = "drops from Tide Keeper (Sea 2)" }
	-- متریال‌هایی که توی هر دریا فارم میشن (از جدول Materials خود BM)
	local MAT_SEA = { ["Magma Ore"] = "Sea 1 or 2", ["Mystic Droplet"] = "Sea 2", ["Fish Tail"] = "Sea 1 or 3", ["Dragon Scale"] = "Sea 3" }

	-----------------------------------------------------------------
	-- قدم بعدی (تابع خالص؛ st همه‌ی داده‌ها رو داره تا بشه آفلاین تستش کرد)
	-- st = { owned = {}, mastery = {}, beli, frag, sea, mats(name), items(name), teacherSea(name) }
	-----------------------------------------------------------------
	function Styles.plan(name, st)
		if st.owned[name] then return nil end
		local def = DEF[name]
		if not def then return { kind = "unknown", style = name, why = "no data for " .. name } end
		for _, need in ipairs(def.needs or {}) do
			local n, level = need[1], need[2]
			if not st.owned[n] then return Styles.plan(n, st) end
			local m = st.mastery[n]
			if m == nil then return { kind = "unknown", style = n, why = "can't read the mastery of " .. n } end
			if m < level then return { kind = "mastery", style = n, need = level, have = m, why = ("%s mastery %d/%d"):format(n, m, level) } end
		end
		for _, mat in ipairs(def.mats or {}) do
			local have = st.mats(mat[1])
			if have < mat[2] then
				return { kind = "material", mat = mat[1], need = mat[2], have = have, why = ("%s %d/%d"):format(mat[1], have, mat[2]) }
			end
		end
		if def.item and not st.items(def.item) then
			return { kind = "item", item = def.item, why = "needs " .. def.item .. (ITEM_HINT[def.item] and " (" .. ITEM_HINT[def.item] .. ")" or "") }
		end
		if st.beli < (def.beli or 0) or st.frag < (def.frag or 0) then
			return { kind = "money", style = name, why = ("%s needs %s Beli + %s Fragments"):format(name, formatNumber(def.beli or 0), formatNumber(def.frag or 0)) }
		end
		local sea = def.sea or st.teacherSea(name)
		if sea and sea ~= st.sea then return { kind = "sea", sea = sea, why = ("buy %s in Sea %d"):format(name, sea) } end
		return { kind = "buy", style = name, why = "ready to buy " .. name .. (def.note and " (" .. def.note .. ")" or "") }
	end

	-- همه‌ی پیش‌نیازها برای نمایش (✔ / عدد)
	function Styles.lines(name, st)
		local out, seen = {}, {}
		local function walk(n)
			local def = DEF[n]
			for _, need in ipairs(def and def.needs or {}) do
				if not seen[need[1]] then
					seen[need[1]] = true
					local m = st.mastery[need[1]]
					local mark = st.owned[need[1]] and ((m or 0) >= need[2] and "✔" or "·") or "✖"
					table.insert(out, ("%s %s  %s/%d"):format(mark, need[1], st.owned[need[1]] and tostring(m or "?") or "not owned", need[2]))
					if not st.owned[need[1]] then walk(need[1]) end
				end
			end
		end
		walk(name)
		for _, mat in ipairs(DEF[name] and DEF[name].mats or {}) do
			local have = st.mats(mat[1])
			table.insert(out, ("%s %s  %d/%d"):format(have >= mat[2] and "✔" or "·", mat[1], have, mat[2]))
		end
		return out
	end

	-----------------------------------------------------------------
	-- داده‌ی واقعی از بازی
	-----------------------------------------------------------------
	local function meleeTool()
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.ToolTip == "Melee" then return t end
				end
			end
		end
	end
	Styles.meleeTool = meleeTool

	function Styles.state()
		local st = { owned = {}, mastery = {}, sea = Sea, beli = dataValue("Beli") or 0, frag = dataValue("Fragments") or 0, confirmed = {} }
		local P = Hub.Planner
		for _, w in ipairs(P and P.weapons or {}) do
			if DEF[w.Name] then
				st.owned[w.Name], st.confirmed[w.Name] = true, true
				st.mastery[w.Name] = tonumber(w.Mastery)
			end
		end
		local inv = inventoryNames()
		for n in pairs(DEF) do
			if inv[n] then st.owned[n], st.confirmed[n] = true, true end
		end
		local t = meleeTool()
		if t and DEF[t.Name] then
			st.owned[t.Name] = true
			local lv = t:FindFirstChild("Level")
			if st.mastery[t.Name] == nil and lv and type(lv.Value) == "number" then st.mastery[t.Name] = lv.Value end
		end
		st.mats = function(n) return materialCount(n) or 0 end
		st.items = function(n) return hasItem(n) end
		st.teacherSea = function(n)
			for _, c in ipairs(Hub.StyleChain or {}) do
				if c[1] == n then
					if c[3][Sea] then return nil end
					for s = 3, 1, -1 do
						if c[3][s] then return s end
					end
				end
			end
		end
		return st
	end

	-----------------------------------------------------------------
	-- گزارش اینونتوری: فیلدهای واقعی‌ای که بازی برمی‌گردونه (برای اطمینان از Mastery سبک‌ها)
	-----------------------------------------------------------------
	function Styles.report()
		local lines = { os.date("%Y-%m-%d %H:%M:%S") .. "  level " .. tostring(dataValue("Level")) }
		for _, cmd in ipairs({ "getInventoryWeapons", "getInventory" }) do
			local r = invoke(cmd)
			table.insert(lines, ("== %s: %s (%d entries)"):format(cmd, type(r), type(r) == "table" and #r or 0))
			for _, item in pairs(type(r) == "table" and r or {}) do
				if type(item) == "table" then
					local parts = {}
					for k, v in pairs(item) do table.insert(parts, tostring(k) .. "=" .. tostring(v)) end
					table.sort(parts)
					table.insert(lines, "  " .. table.concat(parts, ", "))
				end
			end
		end
		table.insert(lines, "== tools")
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			for _, t in ipairs(cont and cont:GetChildren() or {}) do
				if t:IsA("Tool") then
					local vals = {}
					for _, v in ipairs(t:GetChildren()) do
						if v:IsA("ValueBase") then table.insert(vals, v.Name .. "=" .. tostring(v.Value)) end
					end
					table.insert(lines, ("  %s [%s] %s"):format(t.Name, t.ToolTip, table.concat(vals, ", ")))
				end
			end
		end
		return pcall(function() writefile("bmscan/inventory.txt", table.concat(lines, "\n")) end)
	end
	task.delay(15, function() pcall(Styles.report) end)

	-----------------------------------------------------------------
	-- اجرا
	-----------------------------------------------------------------
	local switchAt, buyAt = 0, 0

	-- عوض کردن سبک فقط برای سبکی که اینونتوری میگه داری؛ اگه پول کم شد کار متوقف میشه
	function Styles.switchTo(name, st)
		local t = meleeTool()
		if t and t.Name == name then return true end
		if not st.confirmed[name] or tick() - switchAt < 20 then return false end
		switchAt = tick()
		local before = dataValue("Beli") or 0
		local r = buyStyle(name)
		task.wait(1)
		local spent = before - (dataValue("Beli") or 0)
		V3.log(("STYLE switch to %s -> %s (beli change %d)"):format(name, tostring(r), -spent))
		if spent > 0 and not S.StyleBuy then
			S.AutoStylePlan = false
			Brain.note("Switching to " .. name .. " cost " .. formatNumber(spent) .. " Beli, plan stopped")
			V3.notify("Fighting Styles", "Switching cost Beli, plan stopped", 8)
		end
		return false
	end

	function Styles.buy(name)
		if tick() - buyAt < 60 then return end
		buyAt = tick()
		local def = DEF[name]
		local spot
		for _, c in ipairs(Hub.StyleChain or {}) do
			if c[1] == name then spot = c[3][Sea] end
		end
		local npc = def.npc and findNPC(def.npc)
		if npc then spot = npc.Position end
		if spot then
			S.Status = "Styles: going to the " .. name .. " teacher"
			tweenTo(CFrame.new(spot + Vector3.new(0, 3, 0)), function() return S.AutoStylePlan end)
			task.wait(0.5)
		end
		local before = { beli = dataValue("Beli") or 0, frag = dataValue("Fragments") or 0 }
		local r = buyStyle(name)
		task.wait(1)
		V3.log(("STYLE buy %s -> %s (beli %d, frag %d)"):format(name, tostring(r),
			(dataValue("Beli") or 0) - before.beli, (dataValue("Fragments") or 0) - before.frag))
		Brain.note("Tried to buy " .. name .. ": " .. tostring(r))
	end

	local function setFarm(farm, material)
		S.AutoFarm, S.AutoMaterial = farm, material ~= nil
		if material then S.Material = material end
	end

	function Styles.tick()
		local st = Styles.state()
		local step = Styles.plan(S.StyleTarget, st)
		-- اگه اینونتوری هیچ سبکی نشون نده، «نداری» با «نمی‌تونم بخونم» یکی میشه؛ پس هیچ کاری نمی‌کنیم
		if next(st.confirmed) == nil then
			step = { kind = "unknown", why = "can't read your fighting styles from the game inventory (send bmscan/inventory.txt)" }
		end
		Styles.step = step
		if not step then
			S.AutoStylePlan = false
			Brain.note("You have " .. S.StyleTarget .. " ✔")
			V3.notify("Fighting Styles", "You have " .. S.StyleTarget .. " ✔", 8)
			return
		end
		S.Status = "Styles: " .. step.why
		if step.kind == "mastery" then
			-- Mastery سبک با فارم معمولی و همون سبک توی دست بالا میره
			if Styles.switchTo(step.style, st) then
				S.Weapon = "Melee"
				setFarm(true)
			else
				setFarm(false)
			end
		elseif step.kind == "material" then
			local entry
			for _, m in ipairs(Hub.Materials or {}) do
				if m[1] == step.mat then entry = m end
			end
			if entry then
				setFarm(false, entry[1] .. " (" .. table.concat(entry[2], ", ") .. ")")
			else
				setFarm(false)
				S.Status = ("Styles: %s - farm it in %s"):format(step.why, MAT_SEA[step.mat] or "another sea")
			end
		elseif step.kind == "money" then
			setFarm(true)
		elseif step.kind == "buy" then
			setFarm(false)
			if S.StyleBuy then
				Styles.buy(step.style)
			else
				S.Status = "Styles: " .. step.why .. " - turn on Allow Buying"
			end
		else
			-- آیتم، دریای دیگه یا داده‌ی نامعلوم: کاری نمی‌کنیم که اشتباه نکنیم
			setFarm(false)
		end
	end

	task.spawn(function()
		local saved
		while Hub.Running do
			task.wait(2)
			if S.AutoStylePlan and alive() then
				saved = saved or { AutoFarm = S.AutoFarm, AutoMaterial = S.AutoMaterial, Weapon = S.Weapon, Material = S.Material }
				local ok, err = pcall(Styles.tick)
				if not ok then logError("Styles", err) end
			elseif saved then
				for k, v in pairs(saved) do S[k] = v end
				saved = nil
				stopTween()
			end
		end
	end)

	Styles.ready = true
end)
if not okStyles then logError("v3 styles", errStyles) end
end

-- ===== 80_move.lua =====
---------------------------------------------------------------------
-- v3 · Move: سرعت و پرش واقعی
-- بازی WalkSpeed / JumpPower رو هر لحظه برمی‌گردونه؛ پس عدد Humanoid تنها کافی نیست.
-- سرعت: سرعت واقعی کاراکتر اندازه گرفته میشه و هر چقدر کمتر از عدد تو بود، همون‌قدر به حرکت اضافه میشه.
-- پرش: لحظه‌ی پرش سرعت عمودی مستقیم تنظیم میشه (ارتفاع ≈ JumpPower² / 392)
---------------------------------------------------------------------
do
local okMove, errMove = pcall(function()
	local Move = { speed = 0 }
	Hub.Move = Move

	-- چقدر باید اضافه کنیم (تابع خالص): هدف منهای سرعت واقعی، فقط وقتی کاربر داره راه میره
	function Move.extra(target, measured, moving)
		if not moving then return 0 end
		return math.max(0, target - measured)
	end

	connect(RunService.Heartbeat, function(dt)
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end
		local v = root.AssemblyLinearVelocity
		Move.speed = Vector3.new(v.X, 0, v.Z).Magnitude
		-- موقع پرواز خود هاب، نشستن روی قایق یا فارم کاری نداریم
		if not S.SpeedOn or hum.SeatPart or activeTween or anyFarm() then return end
		local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		local add = Move.extra(S.WalkSpeed, Move.speed, dir.Magnitude > 0.1)
		if add > 0 then
			root.CFrame = root.CFrame + dir.Unit * add * math.min(dt, 0.1)
		end
	end)

	-- لحظه‌ی پرش: فقط روی زمین (یا با Infinite Jump)
	function Move.jump()
		if not S.JumpOn then return false end
		local root, hum = getRoot(), getHum()
		if not root or not hum or hum.SeatPart then return false end
		if hum.FloorMaterial == Enum.Material.Air and not S.InfJump then return false end
		task.defer(function()
			local r = getRoot()
			if not r then return end
			local vel = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = Vector3.new(vel.X, S.JumpPower, vel.Z)
		end)
		return true
	end
	connect(UserInputService.JumpRequest, Move.jump)

	function Move.jumpHeight() return math.floor(S.JumpPower ^ 2 / (2 * workspace.Gravity)) end
end)
if not okMove then logError("v3 move", errMove) end
end

-- ===== 90_draco.lua =====
---------------------------------------------------------------------
-- v3 · Draco: ارتقای نژاد Draco به V2 و V3 از Dragon Wizard (منطق از Banana Cat)
-- V2 = 5 تا Fire Flower (گل‌ها رو جمع می‌کنه؛ گل نبود Forest Pirate می‌کشه)
-- V3 = کشتن یه Terrorshark (با موتور Sea Event). Trial Draco (V4) عمداً نیست: نصفش توی VM بنانا‌ست.
---------------------------------------------------------------------
do
local okDr, errDr = pcall(function()
	local V3 = Hub.V3
	local Draco = {}
	V3.Draco = Draco

	-- وضعیت‌هایی که سرور برمی‌گردونه (AvailableVQuest)
	local ACTIVE = { V2InProgress = true, V3InProgress = true, V2TurnInReady = true, V3TurnInReady = true }
	Draco.FLOWERS_NEEDED = 5

	-- تصمیم خالص (بدون بازی، برای تست): چی کار کنیم با این وضعیت
	-- ctx = { race, done, quest, flowers, sharkKills, sharkBase }
	function Draco.decide(ctx)
		if ctx.race ~= "Draco" then return "notDraco" end
		if ctx.done then return "done" end
		local q = ctx.quest
		if not q or not ACTIVE[q] then
			if q == "V2" or q == "V3" then return "begin" end
			return "speak"
		end
		if q == "V2TurnInReady" or q == "V3TurnInReady" then return "complete" end
		if q == "V2InProgress" then
			return (ctx.flowers or 0) >= Draco.FLOWERS_NEEDED and "complete" or "flowers"
		end
		-- V3InProgress
		return (ctx.sharkKills or 0) > (ctx.sharkBase or 0) and "complete" or "shark"
	end

	local function rf()
		return Net and Net:FindFirstChild("RF/InteractDragonQuest")
	end
	local function talk(args)
		local r = rf()
		if not r then return nil end
		local ok, res = pcall(function() return r:InvokeServer(args) end)
		if ok then return res end
	end

	local state = { quest = nil, flowers = 0, sharkBase = nil, unknown = 0, lastSpeak = 0, lastTry = 0 }
	Draco.state = state

	local function speak()
		local res = talk({ NPC = "Dragon Wizard", Command = "Speak" })
		state.lastSpeak = tick()
		state.quest = type(res) == "table" and res.AvailableVQuest or nil
		V3.log("DRACO speak -> " .. tostring(state.quest))
		return state.quest
	end

	local function wizard() return V3.npcPart and V3.npcPart("Dragon Wizard") end
	-- کنار NPC؟ نه = داره میره (true یعنی رسیدیم)
	local function atWizard(keep)
		local npc = wizard()
		if not npc then
			S.Status = "Draco: Dragon Wizard not found (go near Tiki Outpost / Hydra)"
			task.wait(3)
			return false
		end
		if (getRoot().Position - npc.Position).Magnitude > 8 then
			S.Status = "Draco: going to the Dragon Wizard"
			tweenTo(npc.CFrame * CFrame.new(0, 4, 4), keep)
			return false
		end
		return true
	end

	-- گل‌های آتش: هر ProximityPrompt که پدرش اسمش flower داره (اسم دقیق مدل تأیید نشده)
	local flowers = setmetatable({}, { __mode = "k" })
	local listener
	local function watchFlowers(on)
		if on and not listener then
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Parent and d.Parent.Name:lower():find("flower", 1, true) then flowers[d] = true end
			end
			listener = workspace.DescendantAdded:Connect(function(d)
				if d:IsA("ProximityPrompt") then
					task.defer(function()
						if d.Parent and d.Parent.Name:lower():find("flower", 1, true) then flowers[d] = true end
					end)
				end
			end)
		elseif not on and listener then
			listener:Disconnect()
			listener = nil
		end
	end
	local function nearestFlower()
		local root, best, bd = getRoot(), nil, nil
		for p in pairs(flowers) do
			local holder = p.Parent
			local part = holder and (holder:IsA("BasePart") and holder or holder.PrimaryPart or holder:FindFirstChildWhichIsA("BasePart", true))
			if part and p.Enabled then
				local d = (part.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = { prompt = p, part = part }, d end
			else
				flowers[p] = nil
			end
		end
		return best
	end

	local function pickFlower(f, keep)
		if (getRoot().Position - f.part.Position).Magnitude > 8 then
			S.Status = "Draco V2: going to a Fire Flower"
			tweenTo(f.part.CFrame, keep)
			return
		end
		S.Status = "Draco V2: picking a Fire Flower"
		V3.activate(f.prompt)
		task.wait(1)
		if not f.prompt.Parent or not f.prompt.Enabled then
			state.flowers += 1
			flowers[f.prompt] = nil
			V3.log("DRACO flower picked " .. state.flowers)
		end
	end

	local function stepDraco(keep)
		local action = Draco.decide({
			race = dataValue("Race"),
			done = hasItem("Primordial Reign"),
			quest = state.quest,
			flowers = state.flowers,
			sharkKills = V3.sharkKills,
			sharkBase = state.sharkBase,
		})
		watchFlowers(action == "flowers")
		if action == "notDraco" then
			V3.notify("Draco", "Your race isn't Draco (switch turned off)", 6)
			S.AutoDraco = false
		elseif action == "done" then
			V3.notify("Draco", "You already have Draco V3 (Primordial Reign) ✔", 6)
			S.AutoDraco = false
		elseif action == "speak" or action == "begin" then
			if not atWizard(keep) then return end
			if action == "begin" then
				S.Status = "Draco: starting the " .. state.quest .. " quest"
				talk({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Begin" })
				state.flowers, state.sharkBase = 0, nil
				task.wait(1)
			end
			local q = speak()
			if not q or (not ACTIVE[q] and q ~= "V2" and q ~= "V3") then
				state.unknown += 1
				S.Status = "Draco: Wizard says " .. tostring(q)
				if state.unknown >= 3 then
					V3.notify("Draco", "Nothing to do now (Wizard: " .. tostring(q) .. "). Switch turned off", 8)
					S.AutoDraco = false
					state.unknown = 0
				end
				task.wait(3)
			else
				state.unknown = 0
			end
		elseif action == "complete" then
			if not atWizard(keep) then return end
			S.Status = "Draco: turning in"
			talk({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
			task.wait(1)
			local before = state.quest
			speak()
			V3.log("DRACO complete " .. tostring(before) .. " -> " .. tostring(state.quest))
			if state.quest == before then
				-- هنوز کافی نیست (مثلاً گلی که شمردیم واقعاً نرفته بود توی کیف)
				state.flowers = math.max(0, Draco.FLOWERS_NEEDED - 1)
				if before == "V3InProgress" then state.sharkBase = V3.sharkKills or 0 end
			else
				V3.notify("Draco", tostring(before) .. " done ✔", 6)
				V3.webhook("Draco", tostring(before) .. " done")
				state.flowers, state.sharkBase = 0, nil
				if before == "V3InProgress" or before == "V3TurnInReady" then
					V3.notify("Draco", "Draco V3 finished ✔ (switch turned off)", 8)
					S.AutoDraco = false
				end
			end
		elseif action == "flowers" then
			local f = nearestFlower()
			if f then return pickFlower(f, keep) end
			S.Status = ("Draco V2: Forest Pirates for Fire Flowers (%d/%d)"):format(state.flowers, Draco.FLOWERS_NEEDED)
			if not (V3.farmMobs and V3.farmMobs({ "Forest Pirate" }, keep)) then
				S.Status = "Draco V2: Forest Pirates not found"
				task.wait(3)
			end
			-- هر 3 دقیقه یه بار از سرور می‌پرسیم شاید تموم شده (شمارش گل‌ها از بیرون قابل‌خوندن نیست)
			if tick() - state.lastSpeak > 180 then state.flowers = Draco.FLOWERS_NEEDED end
		elseif action == "shark" then
			if state.sharkBase == nil then state.sharkBase = V3.sharkKills or 0 end
			if not V3.sharkStep then
				S.Status = "Draco V3: Sea module not loaded"
				task.wait(3)
				return
			end
			V3.sharkStep(keep)
			if S.Status:find("^Sea Event") then S.Status = "Draco V3 · " .. S.Status end
		end
	end

	V3.register("AutoDraco", function(keep)
		local ok, err = pcall(stepDraco, keep)
		if not ok then
			watchFlowers(false)
			error(err, 0)
		end
	end, function() return Sea == 3 end, true)

	-- وقتی خاموش شد شنونده‌ی گل‌ها رو قطع کن
	task.spawn(function()
		while Hub.Running do
			task.wait(2)
			if not S.AutoDraco then watchFlowers(false) end
		end
		watchFlowers(false)
	end)
end)
if not okDr then logError("v3 draco", errDr) end
end

-- ===== 95_swords.lua =====
---------------------------------------------------------------------
-- v3 · Swords: Tushita، CDK (Cursed Dual Katana) و TTK (True Triple Katana) با مراحل دقیق
-- منطق از Banana Cat (بخش‌های خوانا):
--   Tushita: ریموت TushitaProgress (OpenedDoor، Torch 1..5)، بعد Longma
--   CDK: ریموت CDKQuest Progress "Good" → Good/Evil؛ -3/-4/-5 = تریال 3/5، 4/5، 5/5؛ 4 = اون طرف تموم
--        Pedestal1/2 بین دو طرف، Pedestal3 + Cursed Skeleton Boss آخرش
--        Good 5 (Cake Queen → Heavenly Dimension) و Evil 5 (Soul Reaper → Hell Dimension) کامل از Banana
--   Good 3/4 و Evil 3/4 توی بخش قفل‌شده‌ی Banana بود؛ از تحقیق (TheGamer، RobloxDen، Alphr) ساخته شدن:
--   Tushita: Dock Legend (3 فروشنده‌ی قایق) → Sense of Duty (Pirate Raid) → Soulless (Cake Queen، Heaven)
--   Yama: Pain and Suffering (با Yama کتک بخور) → Haze of Misery (ماب‌های بنفش) → Fear the Reaper (Hell)
--   TTK: Saddi + Shisui + Wando (Legendary Sword Dealer) → Mysterious Man (دانش بازی، تأیید نشده)
---------------------------------------------------------------------
do
local okSw, errSw = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ CDKHop = false, AutoTTK = false }) do
		if S[k] == nil then S[k] = v end
	end
	local CDK = {}
	V3.CDK = CDK

	-----------------------------------------------------------------
	-- مرحله‌ی CDK از روی دو عدد سرور (خالص، برای تست)
	-----------------------------------------------------------------
	function CDK.stage(good, evil)
		if good == nil or evil == nil then return "noProgress" end
		if good == 4 and evil == 4 then return "final" end
		if good == 4 and evil == 3 then return "pedestal2" end
		if good == 3 and evil == 4 then return "pedestal1" end
		if good ~= 4 and good ~= -2 then
			if good == -3 then return "good3" end
			if good == -4 then return "good4" end
			if good == -5 then return "good5" end
			return "goodStart"
		end
		if evil == -3 then return "evil3" end
		if evil == -4 then return "evil4" end
		if evil == -5 then return "evil5" end
		return "evilStart"
	end
	CDK.LABEL = {
		noProgress = "can't read progress (need Yama + Tushita)", final = "final: Pedestal3 + Cursed Skeleton Boss",
		pedestal1 = "placing the sword at Pedestal1", pedestal2 = "placing the sword at Pedestal2",
		goodStart = "starting the Tushita scroll", good3 = "Tushita 1: Dock Legend (3 boat dealers)",
		good4 = "Tushita 2: Sense of Duty (Pirate Raid, Castle on the Sea)", good5 = "Tushita 3: Soulless (Cake Queen → Heaven)",
		evilStart = "starting the Yama scroll", evil3 = "Yama 1: Pain and Suffering (take damage with Yama)",
		evil4 = "Yama 2: Haze of Misery (purple-marked mobs)", evil5 = "Yama 3: Fear the Reaper (Soul Reaper → Hell)",
	}

	-----------------------------------------------------------------
	-- ابزارها
	-----------------------------------------------------------------
	local function ownTool(name)
		local c, bp = getChar(), player:FindFirstChild("Backpack")
		return (c and c:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
	end
	local function equip(name)
		local t, h = ownTool(name), getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end
	local function swordLevel(name)
		local t = ownTool(name)
		local lv = t and t:FindFirstChild("Level")
		return lv and tonumber(lv.Value)
	end
	-- دعوا با شمشیر (مثل Banana: Cake Queen، ماب‌های Dimension، باس آخر) و برگردوندن سلاح خودت
	local function withSword(fn, ...)
		local saved = S.Weapon
		S.Weapon = "Sword"
		local ok, err = pcall(fn, ...)
		S.Weapon = saved
		if not ok then error(err, 0) end
	end
	local function go(cf, keep)
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		tweenTo(cf, keep)
	end
	local function near(pos, d)
		local r = getRoot()
		return r and (r.Position - pos).Magnitude <= d
	end
	local function location(name)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local l = wo and wo:FindFirstChild("Locations")
		return l and l:FindFirstChild(name)
	end
	local function skipDialogue()
		pcall(function()
			if player.PlayerGui.Main.Dialogue.Visible then
				local vu = game:GetService("VirtualUser")
				vu:Button1Down(Vector2.new(0, 0))
				vu:Button1Up(Vector2.new(0, 0))
			end
		end)
	end
	local function hopFor(what)
		if S.CDKHop and Hub.Brain and Hub.Brain.hop then
			S.Status = "CDK: hopping to find " .. what
			V3.log("CDK hop for " .. what)
			pcall(Hub.Brain.hop)
			task.wait(10)
		else
			S.Status = "CDK: waiting for " .. what .. " (turn on Hop to look in other servers)"
			task.wait(4)
		end
	end
	-- نزدیک‌ترین ماب زنده دور یه نقطه
	local function mobNear(center, radius)
		local enemies = workspace:FindFirstChild("Enemies")
		local root, best, bd = getRoot(), nil, nil
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - center).Magnitude <= radius then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = m, d end
			end
		end
		return best
	end
	local function promptOf(o) return o and o:FindFirstChildWhichIsA("ProximityPrompt", true) end

	-----------------------------------------------------------------
	-- Dimension (Hell / Heavenly): خروجی رنگی = تموم؛ ماب = بکش؛ مشعل روشن‌نشده = روشن کن
	-----------------------------------------------------------------
	local function stepDimension(mapName, locName, doneColor, keep)
		local dim = workspace.Map:FindFirstChild(mapName)
		local loc = location(locName)
		local center = loc and loc.Position
		if not center and dim then
			local ok, pv = pcall(function() return dim:GetPivot().Position end)
			center = ok and pv or nil
		end
		if not dim or not center then
			S.Status = "CDK: waiting for the " .. locName .. " to load"
			task.wait(1)
			return
		end
		local exit = dim:FindFirstChild("Exit")
		if exit and exit:IsA("BasePart") and exit.BrickColor == BrickColor.new(doneColor) then
			S.Status = "CDK: " .. locName .. " cleared, leaving"
			go(exit.CFrame, keep)
			touchPart(exit)
			task.wait(1)
			return
		end
		local mob = mobNear(center, 1000)
		if mob then
			S.Status = "CDK: clearing the " .. locName .. " (" .. mobBaseName(mob.Name) .. ")"
			withSword(killMob, mob, keep)
			return
		end
		for i = 1, 3 do
			local t = dim:FindFirstChild("Torch" .. i)
			local pp = promptOf(t)
			if t and pp and pp.Enabled then
				S.Status = ("CDK: lighting torch %d in the %s"):format(i, locName)
				local pos = t:IsA("BasePart") and t.Position or t:GetPivot().Position
				if not near(pos, 5) then
					go(CFrame.new(pos), keep)
				end
				V3.activate(pp)
				local t0 = tick()
				while keep() and tick() - t0 < 5 and not mobNear(center, 1000) do task.wait(0.3) end
				local r = getRoot()
				if r then r.CFrame = r.CFrame * CFrame.new(0, 50, 0) end
				return
			end
		end
		S.Status = "CDK: waiting for mobs / torches in the " .. locName
		task.wait(1)
	end

	-----------------------------------------------------------------
	-- مرحله‌ها
	-----------------------------------------------------------------
	-- Tushita 1 «Dock Legend» (تحقیق): با 3 تا Boat Dealer / Luxury Boat Dealer روی 3 جزیره‌ی مختلف حرف بزنی
	-- (گزینه‌ی "Pardon me"). Banana اینجا ریموت CDKQuest BoatQuest رو با خود NPC صدا می‌زنه.
	-- همه‌ی فروشنده‌های قایق رو از لیست NPCهای بازی پیدا می‌کنیم و یکی‌یکی سر می‌زنیم
	local FALLBACK_DOCKS = { Vector3.new(-9550, 21, 4690), Vector3.new(-6120, 16, -2250), Vector3.new(-9530, 7, -8370) }
	local visitedDock = {}
	local function dockKey(p) return math.floor(p.X / 200) .. "," .. math.floor(p.Z / 200) end
	local function boatDealers()
		local out, seen = {}, {}
		for _, f in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
			for _, n in ipairs(f and f:GetChildren() or {}) do
				if n.Name:find("Boat Dealer", 1, true) then
					local ok, pv = pcall(function() return n:GetPivot().Position end)
					if ok and pv.Y > -500 and not seen[dockKey(pv)] then
						seen[dockKey(pv)] = true
						table.insert(out, { npc = n, pos = pv })
					end
				end
			end
		end
		if #out == 0 then
			for _, p in ipairs(FALLBACK_DOCKS) do table.insert(out, { pos = p }) end
		end
		return out
	end
	local function good3(keep)
		local list = boatDealers()
		local target
		for _, d in ipairs(list) do
			if not visitedDock[dockKey(d.pos)] then target = d break end
		end
		if not target then
			-- همه رو دیدیم ولی سرور هنوز Good -3 میگه: از اول
			visitedDock = {}
			target = list[1]
		end
		local count = 0
		for _ in pairs(visitedDock) do count += 1 end
		if not near(target.pos, 25) then
			S.Status = ("CDK Good 3/5 (Dock Legend): boat dealer %d/3"):format(math.min(count + 1, 3))
			go(CFrame.new(target.pos + Vector3.new(0, 5, 4)), keep)
			return
		end
		local npc = target.npc
		if not npc then
			for _, d in ipairs(boatDealers()) do
				if d.npc and (d.pos - target.pos).Magnitude < 50 then npc = d.npc end
			end
		end
		if npc then
			invoke("CDKQuest", "BoatQuest", npc)
			V3.log("CDK BoatQuest " .. npc.Name .. " at " .. dockKey(target.pos))
		end
		skipDialogue()
		visitedDock[dockKey(target.pos)] = true
		task.wait(1)
	end

	local CASTLE = Vector3.new(-5100, 315, -3000)
	local function good4(keep)
		local mob = mobNear(CASTLE, 900)
		if mob then
			S.Status = "CDK Good 4/5: Pirate Raid – " .. mobBaseName(mob.Name)
			killMob(mob, keep)
		else
			S.Status = "CDK Good 4/5: waiting for the raid at Castle on the Sea"
			go(CFrame.new(CASTLE + Vector3.new(0, 60, 0)), keep)
			task.wait(2)
		end
	end

	local function good5(keep)
		local loc = location("Heavenly Dimension")
		if loc and near(loc.Position, 1000) then
			return stepDimension("HeavenlyDimension", "Heavenly Dimension", "Cloudy grey", keep)
		end
		local queen = findMobAnywhere("Cake Queen")
		if queen then
			S.Status = "CDK Good 5/5: fighting Cake Queen"
			withSword(fightBoss, "Cake Queen", keep)
			return
		end
		hopFor("Cake Queen")
	end

	-- Yama 1 «Pain and Suffering» (تحقیق: TheGamer، RobloxDen، Alphr): با Yama توی دست حدود 10,000 دمیج
	-- بخوری (یا تقریباً بمیری). حمله نمی‌کنیم؛ کنار یه ماب قوی وایمیستیم تا بزنتمون.
	-- Banana اینجا Marine Commodore (جزیره‌ی Great Tree) رو استفاده می‌کنه
	local COMMODORE_SPOT = Vector3.new(2180.54, 27.82, -6741.55)
	local function evil3(keep)
		equip("Yama")
		local mob = findMob("Marine Commodore")
		if not mob then
			local root = getRoot()
			local enemies = workspace:FindFirstChild("Enemies")
			for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
				if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude < 300 then mob = m break end
			end
		end
		if not mob then
			S.Status = "CDK Evil 3/5 (Pain and Suffering): going to the Marine Commodores"
			go(CFrame.new(COMMODORE_SPOT + Vector3.new(0, 10, 0)), keep)
			task.wait(1)
			return
		end
		S.Status = "CDK Evil 3/5 (Pain and Suffering): letting " .. mobBaseName(mob.Name) .. " hit you (Yama in hand)"
		local t0 = tick()
		while keep() and alive() and mob.Parent and isAliveMob(mob) and tick() - t0 < 10 do
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if not hrp then break end
			Hub.HoldAttackUntil = tick() + 2 -- Auto Click نباید ماب رو بکشه، باید کتک بخوریم
			setFloat(false)
			local root = getRoot()
			if root then root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
			equip("Yama")
			task.wait(0.3)
		end
	end

	local function evil4(keep)
		local haze = player:FindFirstChild("QuestHaze")
		local pick
		for _, v in ipairs(haze and haze:GetChildren() or {}) do
			if v:IsA("ValueBase") and (tonumber(v.Value) or 0) > 0 then pick = v.Name break end
		end
		if not pick then
			S.Status = "CDK Evil 4/5: waiting for the haze list"
			task.wait(1.5)
			return
		end
		local m = findMob(pick)
		if m then
			S.Status = ("CDK Evil 4/5: haze %s (%s left)"):format(pick, tostring(haze[pick].Value))
			killMob(m, keep)
			return
		end
		local sp
		pcall(function() sp = ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder[pick].Position end)
		sp = sp or (spawnCentroid and spawnCentroid(pick))
		S.Status = "CDK Evil 4/5: going to " .. pick
		if sp then go(CFrame.new(sp + Vector3.new(0, 30, 0)), keep) else task.wait(2) end
	end

	local BONE_MOBS = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
	local gambleAt = 0
	local function evil5(keep)
		local loc = location("Hell Dimension")
		if loc and near(loc.Position, 1000) then
			return stepDimension("HellDimension", "Hell Dimension", "Olivine", keep)
		end
		local reaper = findMobAnywhere("Soul Reaper")
		if reaper then
			-- با Soul Reaper دعوا نمی‌کنیم: کنارش می‌مونیم تا ما رو ببره توی Hell Dimension (مثل Banana)
			S.Status = "CDK Evil 5/5: letting Soul Reaper take you to Hell"
			local t0 = tick()
			while keep() and alive() and tick() - t0 < 60 do
				local hrp = reaper:FindFirstChild("HumanoidRootPart")
				if not hrp or not reaper.Parent then break end
				tweenTo(hrp.CFrame * CFrame.new(0, 0, 3), keep)
				local l = location("Hell Dimension")
				if l and near(l.Position, 1000) then break end
				task.wait(0.2)
			end
			return
		end
		if ownTool("Hallow Essence") then
			local det
			pcall(function() det = workspace.Map["Haunted Castle"].Summoner.Detection end)
			if det then
				S.Status = "CDK Evil 5/5: summoning Soul Reaper (Hallow Essence)"
				if not near(det.Position, 8) then go(det.CFrame, keep) end
				equip("Hallow Essence")
				touchPart(det)
			else
				S.Status = "CDK Evil 5/5: going to Haunted Castle"
				go(CFrame.new(-9515, 194, 5786), keep)
			end
			task.wait(1)
			return
		end
		-- Hallow Essence: از ماب‌های Bone یا قمار Death King (50 بون)، مثل Banana
		if tick() - gambleAt > 5 then
			gambleAt = tick()
			task.spawn(function() invoke("Bones", "Buy", 1, 1) end)
		end
		local m
		for _, n in ipairs(BONE_MOBS) do m = m or findMob(n) end
		if m then
			S.Status = "CDK Evil 5/5: bones for Hallow Essence (" .. mobBaseName(m.Name) .. ")"
			killMob(m, keep)
		else
			S.Status = "CDK Evil 5/5: going to Haunted Castle for bones"
			go(CFrame.new(-9515, 194, 5786), keep)
		end
	end

	local BOSS_WAIT = Vector3.new(-12341.67, 603.35, -6550.61)
	local function cursed() local t = workspace.Map:FindFirstChild("Turtle"); return t and t:FindFirstChild("Cursed") end
	local function pedestal(name, keep)
		local c = cursed()
		local p = c and c:FindFirstChild(name)
		if not p then
			S.Status = "CDK: going to the Cursed room (Floating Turtle)"
			go(CFrame.new(BOSS_WAIT), keep)
			return false
		end
		if not near(p.Position, 10) then
			go(p.CFrame, keep)
			return false
		end
		V3.activate(promptOf(p))
		skipDialogue()
		task.wait(1)
		return true
	end
	local function final(keep)
		local c = cursed()
		local p3 = c and c:FindFirstChild("Pedestal3")
		if not p3 then return pedestal("Pedestal3", keep) end
		if not near(p3.Position, 10) and not findMob("Cursed Skeleton Boss") then
			S.Status = "CDK final: going to Pedestal3"
			go(p3.CFrame, keep)
			return
		end
		local gem = c:FindFirstChild("PlacedGem")
		if gem and gem.Transparency == 0 then
			local boss = findMob("Cursed Skeleton Boss")
			if boss then
				S.Status = "CDK final: fighting Cursed Skeleton Boss"
				withSword(killMob, boss, keep)
			else
				S.Status = "CDK final: waiting for Cursed Skeleton Boss"
				go(CFrame.new(BOSS_WAIT), keep)
				task.wait(1)
			end
		else
			S.Status = "CDK final: placing the gem at Pedestal3"
			V3.activate(promptOf(p3))
			skipDialogue()
			task.wait(1)
		end
	end

	local function readProgress()
		local r = invoke("CDKQuest", "Progress", "Good")
		if type(r) ~= "table" then r = invoke("CDKQuest", "Progress") end
		if type(r) == "table" then return tonumber(r.Good), tonumber(r.Evil) end
	end

	local lastStage
	function V3.cdkStep(keep)
		if hasItem("Cursed Dual Katana") then
			S.AutoCDK = false
			V3.notify("CDK", "You have Cursed Dual Katana ✔", 8)
			return
		end
		if not (hasItem("Yama") and hasItem("Tushita")) then
			V3.notify("CDK", "Needs both Yama and Tushita first (switch turned off)", 8)
			S.AutoCDK = false
			return
		end
		for _, sw in ipairs({ "Yama", "Tushita" }) do
			local lv = swordLevel(sw)
			if lv and lv < 350 then
				V3.notify("CDK", ("%s mastery is %d/350 (use Smart Mastery). Switch turned off"):format(sw, lv), 8)
				S.AutoCDK = false
				return
			end
		end
		-- یکی از دو شمشیر باید دستت باشه (Banana: اگه هیچ‌کدوم نبود Tushita رو لود کن)
		if not ownTool("Tushita") and not ownTool("Yama") then
			S.Status = "CDK: loading Tushita"
			invoke("LoadItem", "Tushita")
			task.wait(1)
			return
		end
		skipDialogue()
		local good, evil = readProgress()
		local stage = CDK.stage(good, evil)
		if stage ~= lastStage then
			V3.log(("CDK stage %s (Good=%s Evil=%s)"):format(stage, tostring(good), tostring(evil)))
			lastStage = stage
		end
		CDK.last = { good = good, evil = evil, stage = stage }
		S.Status = "CDK: " .. (CDK.LABEL[stage] or stage)
		if stage == "noProgress" then
			if invoke("CDKQuest", "OpenDoor") == "can" then invoke("CDKQuest", "OpenDoor", true) end
			task.wait(4)
			return
		end
		-- هر طرف با شمشیر خودش (تحقیق: Alphr/RobloxDen): Good = Tushita، Evil = Yama؛ باس آخر با هر کدوم
		local want = (stage:find("^good") or stage == "pedestal1") and "Tushita"
			or ((stage:find("^evil") or stage == "pedestal2") and "Yama") or nil
		if want and not ownTool(want) then
			S.Status = "CDK: loading " .. want .. " for this trial"
			invoke("LoadItem", want)
			task.wait(1)
			return
		end
		if want then equip(want) end
		if stage == "final" then return final(keep) end
		if stage == "pedestal1" then
			if not pedestal("Pedestal1", keep) then return end
		elseif stage == "pedestal2" then
			if not pedestal("Pedestal2", keep) then return end
		end
		-- مثل Banana هر دور StartTrial همون طرف رو صدا می‌زنیم، بعد کار مرحله
		local side = (good ~= 4 and good ~= -2) and "Good" or "Evil"
		invoke("CDKQuest", "StartTrial", side)
		if stage == "good3" then good3(keep)
		elseif stage == "good4" then good4(keep)
		elseif stage == "good5" then good5(keep)
		elseif stage == "evil3" then evil3(keep)
		elseif stage == "evil4" then evil4(keep)
		elseif stage == "evil5" then evil5(keep)
		else task.wait(1.5) end
	end

	-----------------------------------------------------------------
	-- Tushita (از Banana): TushitaProgress → اگه در باز شده Longma، وگرنه مشعل مقدس + 5 مشعل
	-----------------------------------------------------------------
	local TUSHITA_DOOR = Vector3.new(5677.54, 28.53, 357.95)
	local function doorHitbox()
		local h
		pcall(function() h = workspace.Map.Waterfall.SecretRoom.Room.Door.Door.Hitbox end)
		return h
	end
	function V3.tushitaStep(keep)
		if hasItem("Tushita") then
			S.AutoTushita = false
			V3.notify("Tushita", "You have Tushita ✔", 6)
			return
		end
		local p = invoke("TushitaProgress")
		if type(p) == "table" and p.OpenedDoor then
			if findMobAnywhere("Longma") then
				S.Status = "Tushita: fighting Longma"
				fightBoss("Longma", keep)
			else
				S.Status = "Tushita: door open, waiting for Longma"
				task.wait(3)
			end
			return
		end
		local hit = doorHitbox()
		if not hit then
			S.Status = "Tushita: going to the secret room"
			go(CFrame.new(TUSHITA_DOOR), keep)
			return
		end
		if not hit:FindFirstChild("TouchInterest") then
			S.Status = "Tushita: rip_indra must be spawned in this server"
			task.wait(5)
			return
		end
		if not ownTool("Holy Torch") then
			S.Status = "Tushita: taking the Holy Torch"
			go(hit.CFrame, keep)
			touchPart(hit)
			task.wait(1)
			return
		end
		S.Status = "Tushita: lighting the 5 torches"
		equip("Holy Torch")
		for i = 1, 5 do invoke("TushitaProgress", "Torch", i) end
		task.wait(2)
	end

	-----------------------------------------------------------------
	-- TTK (دریای 2): سه شمشیر Legendary (خریدش با Auto Buy Legendary) → Mysterious Man
	-----------------------------------------------------------------
	local MYSTERIOUS_MAN = Vector3.new(-2573.5, 1620.7, -3745.2)
	local ttkTries = 0
	local function stepTTK(keep)
		if hasItem("True Triple Katana") then
			S.AutoTTK = false
			V3.notify("TTK", "You have True Triple Katana ✔", 8)
			return
		end
		local missing = {}
		for _, sw in ipairs({ "Saddi", "Shisui", "Wando" }) do
			if not hasItem(sw) then table.insert(missing, sw) end
		end
		if #missing > 0 then
			if not S.AutoLegendary then S.AutoLegendary = true end
			S.Status = "TTK: buying " .. table.concat(missing, ", ") .. " from the Legendary Sword Dealer"
			task.wait(5)
			return
		end
		if (dataValue("Beli") or 0) < 2000000 then
			S.Status = "TTK: needs $2,000,000"
			task.wait(5)
			return
		end
		if not near(MYSTERIOUS_MAN, 10) then
			S.Status = "TTK: going to the Mysterious Man (Cafe roof)"
			go(CFrame.new(MYSTERIOUS_MAN + Vector3.new(0, 3, 4)), keep)
			return
		end
		S.Status = "TTK: buying from the Mysterious Man"
		local check = invoke("MysteriousMan", "1")
		local buy = invoke("MysteriousMan", "2")
		V3.log("TTK MysteriousMan 1=" .. tostring(check) .. " 2=" .. tostring(buy))
		skipDialogue()
		task.wait(2)
		ttkTries += 1
		if ttkTries >= 3 and not hasItem("True Triple Katana") then
			V3.notify("TTK", "Mysterious Man didn't sell it (needs 300 mastery on all 3 swords?). Switch turned off", 10)
			S.AutoTTK = false
			ttkTries = 0
		end
	end
	V3.register("AutoTTK", stepTTK, function() return Sea == 2 end, true)
end)
if not okSw then logError("v3 swords", errSw) end
end

-- ===== 97_ken.lua =====
---------------------------------------------------------------------
-- v3 · Observation (Ken) dodge service: جاخالی برای بالا بردن هاکی مشاهده
-- منطق از Banana (Auto UP Observation V2، بخش خوانا):
--   امتیاز مشاهده = عددهای متن CommF_ "KenTalk" "Status" (5000 = می‌شه V2 گرفت)
--   هاکی روشن = Lighting.Blur.Enabled؛ روشن: چسبیده به Marine Commodore (CFrame * 0,0,3) کتک بخور
--   خاموش (تموم شد): دور شو و E بزن تا دوباره روشن بشه
-- کار برای هر اکانت جدا توی BMHub_ken.json ذخیره میشه: شروع، تعداد سفارش، تا بعد از ری‌جوین ادامه بده
---------------------------------------------------------------------
do
local okKen, errKen = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ KenFarm = false, KenRest = 30, KenRejoin = false }) do
		if S[k] == nil then S[k] = v end
	end
	local Ken = { V2_AT = 5000, FILE = "BMHub_ken.json" }
	V3.Ken = Ken

	-----------------------------------------------------------------
	-- خالص (برای تست)
	-----------------------------------------------------------------
	-- امتیاز از متن سرور: مثل Banana همه‌ی غیر عددها حذف میشن
	function Ken.parse(text)
		if type(text) == "number" then return text end
		if type(text) ~= "string" then return nil end
		return tonumber((text:gsub("%D", "")))
	end

	-- پیشرفت کار: done/left از امتیاز فعلی و امتیاز شروع
	function Ken.progress(job, points)
		if not job or not points then return nil end
		local done = math.max(0, points - job.start)
		return { done = done, left = math.max(0, job.goal - done), finished = done >= job.goal }
	end

	-- تصمیم هر دور: "finish" | "rest" | "turnOn" | "dodge"
	-- rest: هاکی خاموشه و هنوز وقت پر شدنش نشده، یا جون کمه
	function Ken.decide(ctx)
		if ctx.finished then return "finish" end
		if ctx.hpFrac < 0.35 then return "rest" end
		-- وقت پر شدن همیشه کامل صبر میشه، حتی اگه Blur روشن بشه: Blur بازی با افکت‌های دیگه
		-- (مثلاً Kitsune) هم روشن میشه و لاگ واقعی نشون داد وسط استراحت شیرجه می‌زد
		if ctx.resting and (ctx.now < ctx.restUntil or ctx.hpFrac < 0.8) then return "rest" end
		if ctx.kenOn then return "dodge" end
		return "turnOn"
	end

	-----------------------------------------------------------------
	-- ذخیره‌ی کار برای هر اکانت
	-----------------------------------------------------------------
	local function userKey() return tostring(player.UserId) end
	local function readAll()
		local ok, d = pcall(function()
			if isfile and not isfile(Ken.FILE) then return nil end
			return Svc.Http:JSONDecode(readfile(Ken.FILE))
		end)
		return ok and type(d) == "table" and d or {}
	end
	local function writeAll(all)
		pcall(function() writefile(Ken.FILE, Svc.Http:JSONEncode(all)) end)
	end
	function Ken.job()
		local j = readAll()[userKey()]
		if type(j) == "table" and tonumber(j.start) and tonumber(j.goal) then return j end
		return nil
	end
	function Ken.saveJob(job)
		local all = readAll()
		all[userKey()] = job
		writeAll(all)
	end

	-- امتیاز فعلی از سرور. هیچ‌وقت منتظر سرور نمی‌مونه: لاگ واقعی نشون داد اگه جواب سرور
	-- گیر کنه کل کار یخ می‌زنه (وضعیت یه دقیقه روی "refilling 9s" موند). پس توی پس‌زمینه
	-- گرفته میشه و آخرین عدد برمی‌گرده؛ force فقط تا 5 ثانیه صبر می‌کنه
	local cached, cachedAt, fetching = nil, -100, false
	local function fetch()
		if fetching then return end
		fetching = true
		task.spawn(function()
			local p = Ken.parse(invoke("KenTalk", "Status"))
			if p then cached = p end
			cachedAt, fetching = tick(), false
		end)
	end
	function Ken.points(force)
		if force or tick() - cachedAt > 4 then
			local before = cachedAt
			fetch()
			if force then
				local t0 = tick()
				while cachedAt == before and tick() - t0 < 5 do task.wait(0.1) end
			end
		end
		return cached
	end

	-- سفارش جدید: از امتیاز همین الان n تا جاخالی
	function Ken.newJob(n)
		n = math.floor(tonumber(n) or 0)
		if n <= 0 then return false, "Type a number of dodges, like 1000" end
		local p = Ken.points(true)
		if not p then return false, "Couldn't read your Observation points, try again" end
		Ken.saveJob({ start = p, goal = n, at = os.time() })
		return true
	end
	function Ken.clearJob() Ken.saveJob(nil) end

	-----------------------------------------------------------------
	-- بازی
	-----------------------------------------------------------------
	local function kenOn()
		local b = Lighting:FindFirstChild("Blur")
		return b ~= nil and b.Enabled == true
	end
	Ken.kenOn = kenOn

	local function hpFrac()
		local h = getHum()
		return h and h.MaxHealth > 0 and h.Health / h.MaxHealth or 0
	end

	-- بهترین ماب هر دریا: فقط ضربه‌ی ساده‌ی نزدیک، بدون تفنگ/پرتاب/گرفتن
	-- (لاگ واقعی: Pirate Millionaire توی Port Town از دور می‌زد و حتی 200 بالاتر هم کشتمون)
	--   دریای 1: Monkey (جنگل؛ ضربه‌های تند پشت سر هم، راهنماها هم میگن)
	--   دریای 2: Zombie (Graveyard؛ فقط پنجه از نزدیک)
	--   دریای 3: Marine Commodore (Great Tree؛ انتخاب Banana)
	local BEST = {
		[1] = { name = "Monkey", spot = Vector3.new(-1598.09, 35.55, 153.38) },
		[2] = { name = "Zombie", spot = Vector3.new(-5497.06, 47.59, -795.23) },
		[3] = { name = "Marine Commodore", spot = Vector3.new(2180.54, 27.82, -6741.55) },
	}
	Ken.BEST = BEST
	function Ken.bestFor(sea) return BEST[sea] or BEST[3] end
	local function dodgeMob()
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not root or not enemies then return nil end
		local want = Ken.bestFor(Sea).name
		local best, bestD
		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) and mobBaseName(m.Name) == want then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bestD or d < bestD then best, bestD = m, d end
			end
		end
		return best
	end
	local function dodgeSpot()
		local b = Ken.bestFor(Sea)
		local cf = mobSpawn(b.name)
		return (cf and cf.Position or b.spot) + Vector3.new(0, 60, 0)
	end

	-- ری‌جوین وقتی هاکی تموم شد (پیشنهاد کاربر): همین سرور (JobId) دوباره، هاب خودش برمی‌گرده
	-- (queue_on_teleport + فایل autoexec سولارا) و کار از فایل BMHub_ken.json ادامه پیدا می‌کنه.
	-- مستقیم خالی‌ترین سرور عمومی جدید. اگه هیچ‌کدوم نشد ری‌جوین برای این بار بازی خاموش میشه و مثل قبل صبر می‌کنه
	local tpFailed = false
	pcall(function()
		Svc.Teleport.TeleportInitFailed:Connect(function(p) if p == player then tpFailed = true end end)
	end)
	Ken.rejoinOff = false
	-- سرورهای خالی‌تر اول؛ سرور فعلی، پر، یا قبلاً رفته حذف (خالص، برای تست)
	function Ken.pickServers(list, visited, current)
		local seen = {}
		for _, id in ipairs(visited or {}) do seen[id] = true end
		local out = {}
		for _, sv in ipairs(list or {}) do
			local playing, max = tonumber(sv.playing) or 99, tonumber(sv.maxPlayers) or 0
			if sv.id and sv.id ~= current and not seen[sv.id] and playing < max then table.insert(out, sv) end
		end
		table.sort(out, function(a, b) return (tonumber(a.playing) or 99) < (tonumber(b.playing) or 99) end)
		return out
	end

	local function serverPage(cursor)
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			.. (cursor and ("&cursor=" .. cursor) or "")
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if not ok or type(body) ~= "string" then return nil end
		local ok2, d = pcall(function() return Svc.Http:JSONDecode(body) end)
		return ok2 and type(d) == "table" and d or nil
	end

	-- هاکی تموم شد: مستقیم میره خالی‌ترین سرور جدید (کاربر: باید بره سرورهای خالی، نه همین سرور).
	-- سرورهای رفته توی کار ذخیره میشن تا دوباره همونا نره. اگه یکی نشد بعدی، تا 4 تا
	function Ken.rejoin(job)
		if Ken.rejoinOff or os.time() - (tonumber(job.lastRejoin) or 0) < 20 then return false end
		S.Status = "Observation: Ken ran out, finding an empty server"
		local visited = type(job.visited) == "table" and job.visited or {}
		local list, cursor = {}, nil
		for _ = 1, 2 do
			local d = serverPage(cursor)
			if not d then break end
			for _, sv in ipairs(d.data or {}) do table.insert(list, sv) end
			cursor = d.nextPageCursor
			if not cursor or #Ken.pickServers(list, visited, game.JobId) >= 4 then break end
		end
		local picks = Ken.pickServers(list, visited, game.JobId)
		if #picks == 0 then
			Ken.rejoinOff = true
			V3.notify("Observation", "No empty server found, waiting for the refill instead", 8)
			return false
		end
		if Hub.QueueReload then Hub.QueueReload() elseif Hub.SaveSettings then Hub.SaveSettings() end
		table.insert(visited, game.JobId)
		for i = 1, math.min(4, #picks) do
			local sv = picks[i]
			table.insert(visited, sv.id)
			while #visited > 40 do table.remove(visited, 1) end
			job.visited, job.lastRejoin, job.rejoins = visited, os.time(), (tonumber(job.rejoins) or 0) + 1
			Ken.saveJob(job)
			S.Status = ("Observation: joining a server with %d players"):format(tonumber(sv.playing) or 0)
			tpFailed = false
			pcall(function() Svc.Teleport:TeleportToPlaceInstance(game.PlaceId, sv.id, player) end)
			local t0 = tick()
			repeat task.wait(0.5) until tpFailed or tick() - t0 > 15
			-- خطا نداد یعنی داره میره؛ تا 30 ثانیه صبر، بعد اگه هنوز اینجاییم سرور بعدی
			if not tpFailed then
				t0 = tick()
				repeat task.wait(0.5) until tpFailed or not Hub.Running or tick() - t0 > 30
			end
			if not Hub.Running then return true end
		end
		-- هنوز اینجاییم یعنی هیچ‌کدوم نشد
		Ken.rejoinOff = true
		if Hub.ReloadFailed then Hub.ReloadFailed() end
		V3.notify("Observation", "Couldn't change server, waiting for the refill instead", 8)
		return false
	end

	local restUntil, resting = 0, false
	Ken.state = { sessionDodges = 0 }
	local lastPoints

	local function finish(job, prog)
		S.KenFarm = false
		Hub.HoldAttackUntil = 0
		job.doneAt = os.time()
		Ken.saveJob(job)
		S.Status = ("Observation job done: %d dodges"):format(prog.done)
		V3.notify("Observation", ("Done ✔ %d / %d dodges"):format(prog.done, job.goal), 10)
		V3.webhook("Observation job done", ("%d / %d dodges • points now %s"):format(prog.done, job.goal, tostring(Ken.points())))
	end

	local function stepKen(keep)
		local job = Ken.job()
		if not job then
			S.KenFarm = false
			return V3.notify("Observation", "Type how many dodges first", 5)
		end
		local p = Ken.points()
		local prog = Ken.progress(job, p)
		if not prog then
			S.Status = "Observation: reading your points..."
			return task.wait(1)
		end
		if lastPoints and p > lastPoints then Ken.state.sessionDodges += p - lastPoints end
		lastPoints = p

		local mob = dodgeMob()
		local root = getRoot()
		local on = kenOn()
		local act = Ken.decide({ finished = prog.finished, kenOn = on, hpFrac = hpFrac(), now = tick(), restUntil = restUntil, resting = resting })
		if act == "finish" then return finish(job, prog) end
		Hub.HoldAttackUntil = tick() + 2 -- Auto Click نباید ماب رو بکشه

		if not mob then
			S.Status = ("Observation: %d / %d • going to the %ss"):format(prog.done, job.goal, Ken.bestFor(Sea).name)
			setFloat(true)
			local spot = dodgeSpot()
			if (root.Position - spot).Magnitude > 30 then tweenTo(CFrame.new(spot), keep) end
			return task.wait(1)
		end
		local hrp = mob.HumanoidRootPart

		if act == "dodge" then
			resting = false
			S.Status = ("Observation: dodging %s • %d / %d (left %d)"):format(mobBaseName(mob.Name), prog.done, job.goal, prog.left)
			if (root.Position - hrp.Position).Magnitude > 150 then
				return tweenTo(CFrame.new(hrp.Position + Vector3.new(0, 30, 0)), keep)
			end
			local t0, checkAt, gained = tick(), tick(), false
			local startPts = p
			while keep() and alive() and kenOn() and isAliveMob(mob) and hpFrac() >= 0.35 and tick() - t0 < 6 do
				Hub.HoldAttackUntil = tick() + 2
				-- هر ثانیه شمارش: به عدد سفارش که رسید همون موقع وایسه، نه چند جاخالی بعد
				if tick() - checkAt >= 1 then
					checkAt = tick()
					local cur = Ken.points(true)
					if cur and cur > startPts then gained = true end
					local now = Ken.progress(job, cur)
					if now and now.finished then break end
				end
				-- شناور کنار ماب: بدون float کاراکتر بین هر قدم می‌افتاد و بالا پایین می‌پرید
				setFloat(true)
				root = getRoot()
				if root then root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
				task.wait(0.1)
			end
			-- هاکی تموم شد، یا 6 ثانیه کتک خوردیم و یه جاخالی هم ثبت نشد (یعنی Blur الکی روشن بود):
			-- از الان وقت پر شدن حساب میشه
			if not kenOn() or (tick() - t0 >= 5.5 and not gained) then
				restUntil, resting = tick() + S.KenRest, true
				if S.KenRejoin then Ken.rejoin(job) end
			end
			return
		end

		-- استراحت یا روشن کردن: بالای سر ماب، دور از دسترس
		setFloat(true)
		local safe = CFrame.new(hrp.Position + Vector3.new(0, 300, 0))
		if (root.Position - safe.Position).Magnitude > 20 then tweenTo(safe, keep) end
		if act == "rest" then
			local why = hpFrac() < 0.8 and "healing" or ("refilling %ds"):format(math.max(0, math.ceil(restUntil - tick())))
			S.Status = ("Observation: %s • %d / %d (left %d)"):format(why, prog.done, job.goal, prog.left)
			return task.wait(1)
		end
		S.Status = ("Observation: turning it on (E) • %d / %d"):format(prog.done, job.goal)
		-- مثل دکمه‌ی قدیمی Auto Observation: ریموت خود بازی؛ اگه نشد کلید E
		if not (CommE and pcall(CommE.FireServer, CommE, "Ken", true)) then V3.key(Enum.KeyCode.E, 0.05) end
		task.wait(1.5)
		if not kenOn() then V3.key(Enum.KeyCode.E, 0.05) task.wait(1) end
		if kenOn() then
			resting = false
		else
			restUntil = tick() + 3 -- هنوز پر نشده، کمی بعد دوباره
		end
	end
	V3.register("KenFarm", stepKen)
	V3.stepKen = stepKen
	Ken.ready = true
end)
if not okKen then logError("v3 Ken", errKen) end
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
Hub.TabUI = { apis = {}, groups = {}, order = { Home = 1, Brain = 2, Farm = 3, Quests = 4, Bosses = 5, Sea = 6, Items = 7, Combat = 8, Teleport = 9, Settings = 10 } }
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
	-- اسم تکراری = بخش‌های جدید به انتهای همون صفحه اضافه میشن
	if Hub.TabUI.apis[name] then return Hub.TabUI.apis[name] end
	tabCount += 1
	local btn = new("TextButton", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = Theme.Card, BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, LayoutOrder = Hub.TabUI.order[name] or tabCount + 20, Parent = tabList,
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
	local groups, group = {}, nil
	Hub.TabUI.apis[name], Hub.TabUI.groups[name] = api, groups

	local function card(h)
		order += 1
		local c = new("Frame", {
			Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Theme.Card, LayoutOrder = order, Parent = page,
		}, { corner(9) })
		if group then table.insert(group.items, c) end
		return c
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
		local g = { items = {} }
		function g.show(on)
			g.open = on
			l.Text = (on and "–  " or "+  ") .. string.upper(text)
			for _, c in ipairs(g.items) do c.Visible = on end
		end
		local hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = l })
		hit.Activated:Connect(function() g.show(not g.open) end)
		g.show(true)
		group = g
		table.insert(groups, g)
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

	function api:Input(placeholder, cb)
		local c = card(38)
		local box = new("TextBox", {
			Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), BackgroundColor3 = Theme.Panel,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), PlaceholderText = placeholder,
			PlaceholderColor3 = Theme.SubText, Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = c,
		}, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		box.FocusLost:Connect(function(enter)
			if enter and box.Text ~= "" then task.spawn(cb, box.Text) end
		end)
		return box
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

for k in pairs(Hub.V3SkipSave or {}) do SKIP_SAVE[k] = true end

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
if not S.HeightDefault then
	S.HeightDefault = true
	if S.FarmHeight < 25 then S.FarmHeight = 25 end
end
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

-- ===== 50_brain.lua (UI) =====
do
-- @top
local Brain = Hub.Brain
if Brain and Brain.ready then
	local T = createTab("Brain", "✺")
	T:Section("Autopilot")
	T:Toggle("Brain (picks the best job by itself)", "BrainOn")
	T:Dropdown("Main Goal", Brain.goalNames, "BrainGoal")
	T:Label(function()
		local cur = Brain.current
		if not S.BrainOn then return "Doing: off" end
		return "Doing: " .. (cur and cur.label or "...") .. ("  (%ds)"):format(cur and math.floor(tick() - Brain.since) or 0)
	end)
	T:Label(function() return "Why: " .. Brain.why end)
	T:Section("What Brain May Interrupt The Goal For")
	T:Toggle("Bosses (special + any boss you can beat)", "BrainBosses")
	T:Toggle("Server Events (Factory, Pirate Raid)", "BrainEvents")
	if Sea == 3 then T:Toggle("Elite Hunter", "BrainElite") end
	T:Toggle("Fruits On The Map", "BrainFruits")
	if Sea == 1 or Sea == 2 then T:Toggle("Move To The Next Sea (at 700 / 1500)", "BrainSeas") end
	T:Slider("Avoid A Target After N Deaths", 1, 5, "BrainDeaths")
	T:Label(function() return "Switches listed here are controlled by Brain while it is on" end)
	T:Section("Decision Log")
	for i = 1, 5 do
		T:Label(function() return Brain.log[i] or "-" end)
	end
	T:Section("Session Income")
	T:Label(function() return "XP / hour: " .. formatNumber(math.floor(Brain.perHour("Exp"))) end)
	T:Label(function() return "Beli / hour: " .. formatNumber(math.floor(Brain.perHour("Beli"))) end)
	T:Label(function() return "Fragments / hour: " .. formatNumber(math.floor(Brain.perHour("Fragments"))) end)
	T:Button("Reset Income Stats", function() Brain.resetStats() end)
end
end

-- ===== 60_planner.lua (UI) =====
do
-- @top
local Planner, Brain = Hub.Planner, Hub.Brain
if Planner and Planner.ready then
	local T = createTab("Brain", "✺")
	T:Section("Account Plan (Brain goal: Account Plan)")
	for i = 1, 6 do
		if Planner.stepLine(i) then
			T:Label(function() return Planner.stepLine(i) or "-" end)
		end
	end
	T:Slider("Give Up On A Step After (minutes)", 10, 120, "PlanStepMax")
	T:Section("Best Income (Brain goal: Best Income)")
	T:Dropdown("Measure", function() return { "Beli", "Exp", "Fragments" } end, "BrainMetric", function()
		Planner.activeUntil = 0
	end)
	T:Slider("Test Each Job For (minutes)", 3, 15, "BestTrial")
	for i = 1, 5 do
		T:Label(function()
			local j = Planner.topJobs()[i]
			if not j then return "-" end
			return ("%d. %s: %s/h  (%d min measured)"):format(i, j.label, formatNumber(math.floor(j.rate)), math.floor(j.mins))
		end)
	end
end
end

-- Farm: فارم لول/ماب، مستری، اسکیل‌ها (همه‌ی دریاها)
do
	local T = createTab("Farm", "☰")
	T:Section("Auto Farm")
	T:Toggle("Auto Farm", "AutoFarm", stopOff)
	T:Dropdown("Farm Mode", function() return { "Level", "Nearest Mob", "Selected Mob" } end, "FarmMode")
	T:Dropdown("Select Mob", mobOptions, "SelectedMob")
	T:Toggle("Take Quest", "TakeQuest")
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
	T:Section("Halloween")
	T:Toggle("Auto Pumpkins (breaks them with melee, kills what spawns)", "AutoPumpkin", stopOff)
	T:Input("Pumpkin Name contains (default: pumpkin), press Enter", function(text)
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then text = "pumpkin" end
		S.PumpkinPattern = text
		notify("Halloween", "Looking for objects named *" .. text .. "*", 4)
	end)
	T:Label(function() return "Searching for: *" .. tostring(S.PumpkinPattern) .. "*" end)
	T:Button("Scan Pumpkins Now", function()
		task.spawn(function()
			local list = Hub.ScanPumpkins(true)
			if #list == 0 then return notify("Halloween", "No pumpkins found with that name", 5) end
			local names = {}
			for i, p in ipairs(list) do
				if i > 4 then break end
				table.insert(names, p.obj.Name)
			end
			notify("Halloween", #list .. " found: " .. table.concat(names, ", "), 6)
		end)
	end)
	T:Button("Save Pumpkin List To File (bmscan/pumpkins.txt)", function()
		task.spawn(function()
			local ok, n = Hub.DumpPumpkins()
			notify("Halloween", ok and ("Saved " .. n .. " objects ✔") or "Could not write the file", 5)
		end)
	end)
	T:Section("Auto Stats")
	T:Dropdown("Stat", function() return { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType")
	T:Dropdown("Split With", function() return { "None", "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType2")
	T:Slider("Points Per Tick", 1, 100, "StatAmount")
	T:Toggle("Auto Stats", "AutoStats")
end

-- دریای فعلی: فقط فارم‌ها، آیتم‌ها و پیشرفت همین دریا
do
	local T = createTab("Quests", "≋")
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
	local T = createTab("Sea", "⚓")
	T:Section("Sea Beasts")
	T:Toggle("Auto Sea Beast (hunts + fights, uses the Sea Event settings)", "AutoSeaBeast", stopOff)
	T:Label(function() return "Attack mode, weapon and heights: Sea Event section" end)
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

-- ===== 10_sea.lua (UI) =====
do
if Sea >= 2 then
	local T = createTab("Sea", "⚓")
	T:Section("Boat")
	T:Toggle("Auto Buy Boat (spends beli!)", "AutoBuyBoat")
	T:Toggle("Respawn Near Dealer When Far (saves flight time)", "ResetForBoat")
	T:Slider("Boat Speed (150 safe, 250+ may get pulled back)", 50, 400, "BoatSpeed")
	T:Toggle("Set Boat Max Speed (manual driving)", "BoatMaxSpeedOn")
	T:Slider("Boat Max Speed", 50, 400, "BoatMaxSpeed")
	T:Label(function()
		local b = Hub.V3.myBoat and Hub.V3.myBoat()
		return "Your boat: " .. (b and b.Name or "none")
	end)
	if Sea == 3 then
		T:Section("Leviathan & Prehistoric (new Sea 3 map)")
		T:Dropdown("Leviathan Boat", function() return { "Beast Hunter", "PirateBrigade", "PirateGrandBrigade" } end, "BoatChoice")
		T:Dropdown("Prehistoric Boat", function() return { "PirateBrigade", "PirateGrandBrigade", "Beast Hunter" } end, "EventBoat")
		T:Toggle("Auto Find Leviathan (sail until Frozen Dimension)", "AutoFindLeviathan", stopOff)
		T:Toggle("Auto Find Prehistoric Island", "AutoFindPrehistoric", stopOff)
		T:Toggle("Turn Back When Over 10km", "WillBack")
		T:Toggle("Auto Fire Harpoon At Frozen Heart", "AutoFireHeart", stopOff)
		T:Label(function()
			local V = Hub.V3
			return "Frozen Dimension: " .. (V.leviathanUp and V.leviathanUp() and "SPAWNED ✔" or "no")
				.. "  •  Prehistoric: " .. (V.prehistoricUp and V.prehistoricUp() and "SPAWNED ✔" or "no")
		end)
	end
	T:Section("Sea Event")
	T:Toggle("Auto Sea Event", "AutoSeaEvent", stopOff)
	T:Dropdown("Attack Mode", function() return { "All Fast", "M1 Spam" } end, "SeaAttack")
	T:Label(function() return S.SeaAttack == "M1 Spam" and "M1 Spam: Blox Fruit with M1 = Banana fruit M1 (under boats, fast, no clicks); other weapons click nonstop" or "All Fast: every weapon + Z X C V, very quick" end)
	T:Dropdown("Event Boat", function() return { "PirateBrigade", "PirateGrandBrigade", "Beast Hunter" } end, "EventBoat")
	T:Toggle("Hunt In Deep Sea When Nothing Is Around", "SeaHunt")
	T:Slider("Danger Level To Hunt At", 1, 6, "SeaDanger")
	T:Label(function()
		local V = Hub.V3
		local lvl = V.dangerLevel and V.dangerLevel()
		-- با and فقط اولین جواب برمی‌گرده و فاصله همیشه nil می‌شد
		local d
		if V.nearestIsland and getRoot() then _, d = V.nearestIsland(getRoot().Position) end
		return ("Danger now: %s  •  Nearest island: %s"):format(tostring(lvl or "?"), d and (math.floor(d) .. " studs") or "?")
	end)
	T:Toggle("Fight Sea Beasts", "SeaHitBeasts")
	T:Toggle("Fight Terrorshark (first)", "SeaHitShark")
	T:Toggle("Fight Enemy Boats", "SeaHitBoats")
	T:Toggle("Fight Sea Mobs (sharks, piranhas, crews)", "SeaHitSmall")
	T:Toggle("All Fast: Rotate All Weapons", "SeaRotate")
	T:Dropdown("Weapon (M1 Spam / no rotation)", function() return { "Blox Fruit", "Sword", "Gun", "Melee", "Dragonstorm", "Skull Guitar" } end, "SeaWeapon")
	T:Slider("Height Above Sea Beast", 60, 250, "SeaBeastHover")
	T:Slider("Height Above Boats", 20, 120, "SeaHover")
	T:Toggle("Heal Up High When Low HP", "SeaRetreat")
	T:Toggle("Auto Repair Boat (hammer)", "RepairBoat")
	T:Button("Set Waiting Spot = My Boat's Position", function()
		local b = Hub.V3.myBoat and Hub.V3.myBoat()
		if not b then return notify("Sea Event", "Sit on your boat first") end
		local p = b.VehicleSeat.Position
		S.SeaSpotX, S.SeaSpotZ, S.SeaSpotSet = p.X, p.Z, true
		notify("Sea Event", ("Spot saved (%d, %d)"):format(p.X, p.Z), 4)
	end)
	T:Button("Clear Waiting Spot", function() S.SeaSpotSet = false end)
	T:Label(function()
		local list = Hub.V3.seaTargets and Hub.V3.seaTargets() or {}
		return "Targets now: " .. (#list > 0 and (list[1].label .. " (" .. #list .. ")") or "none")
	end)
	T:Label(function()
		local parts = {}
		for k, n in pairs(Hub.V3.seaKills or {}) do table.insert(parts, k .. " " .. n) end
		table.sort(parts)
		return "Killed this session: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing yet")
	end)
	T:Button("Scan The Sea Around Me (bmscan/sea_scan.txt)", function()
		local ok, n = Hub.V3.seaScan()
		notify("Sea Scan", ok and ("Saved " .. n .. " things ✔ - tell Claude") or "Could not write the file", 5)
	end)
end
end

-- ===== 20_volcano.lua (UI) =====
do
if Sea == 3 then
	local T = createTab("Sea", "⚓")
	T:Section("Prehistoric Island (full event)")
	T:Toggle("Auto Prehistoric Event (craft magnet → find → run event)", "AutoVolcano", stopOff)
	T:Toggle("Auto Buy Boat (needed if you have no boat here, spends beli!)", "AutoBuyBoat")
	T:Toggle("I Already Have The Magnet (skip crafting)", "IgnoreMagnet")
	T:Toggle("Remove Lava Damage (local only)", "RemoveLava")
	T:Dropdown("Golem Weapon", function() return { "Melee", "Sword", "Blox Fruit", "Gun" } end, "GolemWeapon")
	T:Dropdown("Lava Rock Weapon", function() return { "Blox Fruit", "Sword", "Gun", "Melee" } end, "VolcanoWeapon")
	T:Label(function()
		local V = Hub.V3
		return "Island: " .. (V.prehistoricUp and V.prehistoricUp() and "SPAWNED ✔" or "not spawned")
	end)
	T:Section("Volcanic Magnet")
	T:Toggle("Auto Craft Volcanic Magnet", "AutoCraftMagnet", stopOff)
	T:Toggle("Auto Quest Dragon Hunter (Blaze Ember: mobs + trees)", "AutoDragonHunter", stopOff)
	T:Button("Scan Trees (writes bmscan/trees.txt)", function()
		local n = Hub.V3.scanTrees and Hub.V3.scanTrees()
		notify("Dragon Hunter", ("Saved %d trees"):format(n or 0), 5)
	end)
	T:Label(function()
		local V = Hub.V3
		if not V.volcanoCount then return "" end
		return ("Scrap Metal %d/10  •  Blaze Ember %d/15  •  Magnet: %s"):format(
			V.volcanoCount("Scrap Metal"), V.volcanoCount("Blaze Ember"), (hasItem("Volcanic Magnet") and "✔" or "✖"))
	end)
end
end

-- ===== 30_trials.lua (UI) =====
do
if Sea >= 2 then
	local T = createTab("Quests", "≋")
	if Sea == 3 then
		T:Section("Race V4 (Temple of Time)")
		T:Toggle("Auto Trial (go to the door, fight your race trial)", "AutoTrial", stopOff)
		T:Toggle("Press T At The Door (race ability)", "TrialPressT")
		T:Toggle("Auto Race V4 Quest (Begin / Teleport / Continue)", "AutoRaceV4", stopOff)
		T:Toggle("Auto Pull Lever (Valkyrie Helm + Mirror Fractal)", "AutoPullLever", stopOff)
		T:Label(function()
			local V = Hub.V3
			return "Race: " .. tostring(dataValue("Race") or "?") .. "  •  Trial running: " .. (V.raidTimer and V.raidTimer() and "YES" or "no")
		end)
		T:Section("Observation & Haki")
		T:Toggle("Auto Observation V2 Quest (Citizen quest)", "AutoKenQuest", stopOff)
		T:Toggle("Auto Rainbow Haki (Horned Man)", "AutoRainbowHaki", stopOff)
	end
	if Sea == 2 then
		T:Section("Ghoul")
		T:Toggle("Auto Get Ghoul (100 Ectoplasm + Hellfire Torch)", "AutoGetGhoul", stopOff)
		T:Label(function() return "Ectoplasm: " .. formatNumber(materialCount("Ectoplasm") or 0) .. "  •  Race: " .. tostring(dataValue("Race") or "?") end)
	end
end
end

-- ===== 40_extras.lua (UI) =====
do
if Sea == 3 then
	local T = createTab("Sea", "⚓")
	T:Section("Kitsune Island")
	T:Dropdown("Boat", function() return { "PirateBrigade", "PirateGrandBrigade", "Beast Hunter" } end, "EventBoat")
	T:Toggle("Auto Spawn Kitsune Island (full moon night)", "AutoKitsuneSpawn", stopOff)
	T:Toggle("Auto Pray At Kitsune Statue (needs Azure Ember)", "AutoKitsunePray")
	T:Slider("Azure Ember Needed", 1, 20, "AzureEmberNeed")
	T:Label(function()
		return "Kitsune Island: " .. (Hub.Events and Hub.Events.kitsune and "SPAWNED ✔" or "no") .. "  •  Azure Ember: " .. tostring(materialCount("Azure Ember") or 0)
	end)
end
end

-- ===== 70_styles.lua (UI) =====
do
local Styles = Hub.Styles
if Styles and Styles.ready then
	local T = createTab("Quests", "≋")
	T:Section("Fighting Style Plan")
	T:Dropdown("Target Style", function() return Styles.TARGETS end, "StyleTarget")
	T:Toggle("Auto Get Target Style (farms mastery + materials)", "AutoStylePlan", stopOff)
	T:Toggle("Allow Buying (spends Beli / Fragments)", "StyleBuy")
	T:Label(function()
		if not S.AutoStylePlan then return "Next: (off)" end
		return "Next: " .. (Styles.step and Styles.step.why or "...")
	end)
	local cache, cacheAt = {}, 0
	for i = 1, 9 do
		T:Label(function()
			if tick() - cacheAt > 5 then
				cacheAt = tick()
				local ok, res = pcall(function() return Styles.lines(S.StyleTarget, Styles.state()) end)
				cache = ok and res or {}
			end
			return cache[i] or ""
		end)
	end
	T:Button("Save Inventory Report (bmscan/inventory.txt)", function()
		notify("Styles", Styles.report() and "Saved ✔ - tell Claude" or "Could not write the file", 4)
	end)
end
end

-- ===== 90_draco.lua (UI) =====
do
if Sea == 3 then
	local T = createTab("Quests", "≋")
	T:Section("Draco Race (Dragon Wizard)")
	T:Toggle("Auto Draco V2 → V3 (Fire Flowers, then a Terrorshark)", "AutoDraco", stopOff)
	T:Label(function()
		local D = Hub.V3.Draco
		if not D then return "" end
		return ("Race: %s  •  Wizard: %s  •  Flowers: %d/%d  •  Sharks killed: %d"):format(
			tostring(dataValue("Race") or "?"), tostring(D.state.quest or "?"), D.state.flowers, D.FLOWERS_NEEDED, Hub.V3.sharkKills or 0)
	end)
end
end

-- ===== 95_swords.lua (UI) =====
do
if Sea == 2 then
	local T = createTab("Items", "◆")
	T:Section("True Triple Katana (auto)")
	T:Toggle("Auto TTK (buys the 3 Legendary swords, then the Mysterious Man)", "AutoTTK", stopOff)
	T:Label(function() return "TTK spends $2M per Legendary sword + $2M for TTK" end)
elseif Sea == 3 then
	local T = createTab("Items", "◆")
	T:Section("CDK (Cursed Dual Katana)")
	T:Toggle("Hop Servers For Cake Queen / Soul Reaper", "CDKHop")
	T:Label(function()
		local C = Hub.V3.CDK
		local l = C and C.last
		if not l then return "CDK progress: turn on Auto CDK to read it" end
		return ("Good %s • Evil %s • %s"):format(tostring(l.good), tostring(l.evil), C.LABEL[l.stage] or l.stage)
	end)
end
end

-- ===== 97_ken.lua (UI) =====
do
if Hub.V3.Ken and Hub.V3.Ken.ready then
	local Ken = Hub.V3.Ken
	local T = createTab("Combat", "⚔")
	T:Section("Observation Haki (Ken) Dodge Service")
	T:Label(function()
		local p = Ken.points()
		return ("Observation points: %s / %d (Ken V2 at %d)"):format(p and tostring(p) or "?", Ken.V2_AT, Ken.V2_AT)
	end)
	T:Label(function()
		local job = Ken.job()
		if not job then return "No job yet: type how many dodges below" end
		local prog = Ken.progress(job, Ken.points())
		if not prog then return ("Job: %d dodges"):format(job.goal) end
		return ("Job: %d / %d dodges done • left %d%s"):format(prog.done, job.goal, prog.left, prog.finished and "  ✔ finished" or "")
	end)
	T:Input("Dodges to farm (e.g. 1000) + Enter", function(text)
		local ok, err = Ken.newJob(text)
		if not ok then return notify("Observation", err, 5) end
		S.KenFarm = true
		notify("Observation", ("New job: %s dodges, starting now"):format(tostring(Ken.job().goal)), 5)
	end)
	T:Toggle("Auto Dodge (keeps going after rejoin)", "KenFarm", stopOff)
	T:Slider("Wait For Refill (seconds)", 0, 120, "KenRest")
	T:Toggle("Join An Empty Server When Ken Runs Out (instead of waiting)", "KenRejoin")
	T:Label(function()
		local job = Ken.job()
		local n = job and tonumber(job.rejoins) or 0
		if Ken.rejoinOff then return "Rejoin didn't work, so it waits for the refill" end
		return ("Server changes this job: %d  •  always the emptiest new server"):format(n)
	end)
	T:Label(function() return ("Dodge mob here: %s (Sea 1 Monkey, Sea 2 Zombie, Sea 3 Marine Commodore). Auto Click pauses while dodging."):format(Ken.bestFor(Sea).name) end)
	T:Button("Clear Job", function()
		S.KenFarm = false
		Ken.clearJob()
		notify("Observation", "Job cleared", 3)
	end)
end
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
	T:Slider("Attack Range", 10, 150, "AttackRange")
	T:Toggle("Bring Mobs", "BringMobs")
	T:Slider("Bring Range", 50, 500, "BringRange")
	T:Slider("Max Mobs Brought", 1, 30, "BringMax")
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
	T:Slider("Farm Height (above mobs)", 0, 100, "FarmHeight")
	T:Slider("Tween Speed (max 300 safe)", 100, 300, "TweenSpeed")
	T:Section("Speed & Jump (real)")
	T:Toggle("Walk Speed", "SpeedOn", function(on)
		if not on then local h = getHum() if h then h.WalkSpeed = 16 end end
	end)
	T:Slider("Speed", 16, 300, "WalkSpeed")
	T:Label(function() return ("Real speed now: %d studs/s"):format(Hub.Move and math.floor(Hub.Move.speed) or 0) end)
	T:Toggle("Jump Power", "JumpOn", function(on)
		if not on then local h = getHum() if h then h.JumpPower = 50 end end
	end)
	T:Slider("Jump", 50, 300, "JumpPower")
	T:Label(function() return ("Jump height: about %d studs"):format(Hub.Move and Hub.Move.jumpHeight() or 0) end)
	T:Toggle("Infinite Jump", "InfJump")
end

-- Shop
do
	local T = createTab("Items", "◆")
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
	T:Section("Quick Find (one click, hops until found)")
	local quick = { { "Find Fruit Server", "Any Fruit" }, { "Find Full Moon Server", "Full Moon" } }
	if Sea == 2 then table.insert(quick, { "Find Legendary Sword Dealer", "Legendary Sword Dealer" }) end
	if Sea == 3 then
		for _, q in ipairs({
			{ "Find Mirage Island Server", "Mirage Island" },
			{ "Find Mirage + Full Moon (Race V4)", "Mirage + Full Moon" },
			{ "Find Kitsune Island Server", "Kitsune Island" },
			{ "Find Prehistoric Island Server", "Prehistoric Island" },
			{ "Find Frozen Dimension Server", "Frozen Dimension" },
		}) do table.insert(quick, q) end
	end
	for _, q in ipairs(quick) do
		T:Button(q[1], function()
			if Hub.HuntFind(q[2]) then return notify("Server Finder", q[2] .. " is already in this server ✔", 6) end
			Hub.HuntStart(q[2])
			notify("Server Finder", "Searching for " .. q[2] .. "...", 5)
			if not Hub.CanQueue then
				notify("Server Finder", "Your executor can't auto re-run after hop: put the loader in its autoexec folder", 10)
			end
		end)
	end
	T:Button("Stop Finder", function()
		Hub.HuntStop()
		notify("Server Finder", "Stopped", 3)
	end)
	T:Label(function() return "Target: " .. tostring(S.HuntTarget or "None") .. "  •  " .. tostring(Hub.HuntStatus) end)
	T:Section("Join by Job ID (from Discord notifiers)")
	local jobBox
	jobBox = T:Input("Paste Job ID or join script, press Enter", function(text)
		local ok, err = Hub.JoinJob(text)
		if not ok then notify("Join Server", err, 6) end
		jobBox.Text = ""
	end)
	if getclipboard then
		T:Button("Join Job ID From Clipboard", function()
			local ok, err = Hub.JoinJob(getclipboard())
			if not ok then notify("Join Server", err, 6) end
		end)
	end
	T:Button("Copy This Server's Job ID", function()
		local copied = pcall(function() (setclipboard or toclipboard)(game.JobId) end)
		notify("Job ID", copied and "Copied ✔" or game.JobId, 6)
	end)
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

-- ESP
do
	local T = createTab("Settings", "✦")
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
	local T = createTab("Settings", "✦")
	T:Section("Team")
	T:Dropdown("Team", function() return { "Pirates", "Marines" } end, "TeamChoice")
	T:Toggle("Auto Pick Team", "AutoTeam")
	T:Section("Player")
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
-- ===== 40_extras.lua (UI late) =====
do
do
	local T = createTab("Settings", "✦")
	T:Section("Discord Webhook")
	T:Input("Paste your Discord webhook URL, press Enter", function(text)
		S.WebhookUrl = (text:gsub("%s+", ""))
		notify("Webhook", "URL saved", 3)
	end)
	T:Toggle("Send Alerts To Discord (events, Leviathan, Prehistoric, finds)", "WebhookOn")
	T:Button("Send Test Message", function()
		if S.WebhookUrl == "" then return notify("Webhook", "Paste the URL first") end
		Hub.V3.webhook("BM Hub", "Test message ✔ — " .. player.Name)
		notify("Webhook", "Test sent (if nothing arrives, check the URL)", 4)
	end)
	T:Label(function() return "Webhook: " .. (S.WebhookUrl ~= "" and "saved ✔" or "not set") end)
end
end

-- ===== 50_brain.lua (UI late) =====
do
local Brain = Hub.Brain
if Brain and Brain.ready then
	local T = createTab("Combat", "⚔")
	T:Section("Fruit M1")
	T:Toggle("Fruit M1 (no screen clicks, no animation)", "FruitM1")
	T:Label(function() return "Hold the fruit. While farming: Farm Weapon = Blox Fruit" end)
	T:Label(function()
		local tool = Brain.heldFruitM1()
		return "In your hand: " .. (tool and tool.Name .. " has M1 ✔" or "no fruit with M1")
	end)
	T:Label(function()
		local tool = Brain.heldFruitM1()
		return "Mode: " .. (tool and Brain.fruitStatus(tool) or "-")
	end)
	T:Button("Test This Fruit Again", function()
		local tool = Brain.heldFruitM1()
		if not tool then return notify("Fruit M1", "Hold a fruit with M1 first", 4) end
		Brain.retestFruit(tool)
		notify("Fruit M1", "Fight mobs for about 30 seconds", 4)
	end)
	T:Section("Skills")
	T:Toggle("Use Skills", "UseSkills")
	T:Toggle("Skill Z", "SkillZ")
	T:Toggle("Skill X", "SkillX")
	T:Toggle("Skill C", "SkillC")
	T:Toggle("Skill V", "SkillV")
	T:Section("Smart Combat")
	T:Toggle("Smart Skills (bosses and groups of 3+)", "SmartSkills")
	T:Toggle("Smart Race Transform (energy full + worthy fight)", "SmartRace")
	T:Toggle("Smart Retreat (leaves before you die, uses Auto Retreat)", "SmartRetreat")
	T:Slider("Retreat If Dead In N Seconds", 1, 8, "DeathTime")
	T:Section("Learned Dodge (bosses only)")
	T:Toggle("Learn And Dodge Boss Attacks", "SmartDodge")
	T:Slider("Lift Height While Dodging", 30, 75, "DodgeHeight")
	T:Slider("Heavy Hit = % Of Max HP", 5, 40, "DodgeLearn")
	T:Slider("Dodge After Seeing It N Times", 1, 5, "DodgeAfter")
	T:Label(function() return ("Learned attacks: %d  •  Dodges this session: %d"):format(Brain.learnedCount(), Brain.dodges) end)
	T:Button("Forget Learned Attacks", function()
		Brain.forget()
		notify("Learned Dodge", "Cleared", 3)
	end)

	T = createTab("Items", "◆")
	T:Section("Chest Hop")
	T:Toggle("Chest Hop", "ChestHop")
	T:Slider("Hop After N Chests", 5, 60, "ChestHopAt")
	T:Toggle("Safe Carry (no chests with Fist / Chalice)", "SafeCarry")
	T:Label(function() return "Chests this server: " .. Hub.ChestsTaken .. (Hub.CanQueue and "" or "  •  hub won't restart after a hop here") end)

	T = createTab("Settings", "✦")
	T:Section("Stuck Guard")
	T:Toggle("Fix Stuck Farms By Itself", "Watchdog")
	T:Slider("Stuck After (seconds)", 30, 180, "WatchdogSec")
	T:Label(function()
		local function v(k) return S[k] >= 100 and "-" or tostring(S[k]) end
		return ("Learned max height  Melee %s • Sword %s • Fruit %s • Gun %s"):format(v("HeightCapMelee"), v("HeightCapSword"), v("HeightCapFruit"), v("HeightCapGun"))
	end)
	T:Button("Forget Learned Heights (try Farm Height again)", function()
		if Hub.ResetHeightCaps then Hub.ResetHeightCaps() end
		if Hub.SaveSettings then pcall(Hub.SaveSettings) end
		notify("Farm Height", "Learned heights cleared", 4)
	end)
	T:Label(function() return ("Rescues: %d  •  Deaths: %d"):format(Brain.rescues, Brain.deathTotal) end)
end
end

-- ===== 60_planner.lua (UI late) =====
do
local Planner = Hub.Planner
if Planner and Planner.ready then
	local T = createTab("Farm", "☰")
	T:Section("Smart Mastery (with Auto Farm)")
	T:Toggle("Train Swords One By One", "SmartMastery")
	T:Slider("Target Mastery", 50, 600, "MasteryTarget")
	T:Label(function()
		if not Planner.masteryName then return "Training: nothing" end
		return ("Training: %s  (%s)"):format(Planner.masteryName, tostring(Planner.mastery[Planner.masteryName] or "?"))
	end)
	T = createTab("Settings", "✦")
	T:Section("Alerts")
	T:Toggle("Tell Me About New Items", "LootWatch")
	T:Toggle("Hourly Report To Discord", "HourlyReport")
	T:Button("Send Report Now", function()
		Hub.V3.webhook("Session Report", Planner.report())
		notify("Report", S.WebhookOn and "Sent" or "Turn on the webhook in Extras first", 4)
	end)
	T:Section("Safety")
	T:Toggle("Restart Hub After Teleports", "AutoReload")
	T:Toggle("PK Guard (hop when a player keeps hitting you)", "PKGuard")
end
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

minBtn.Activated:Connect(function() showMain(false) end)
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
