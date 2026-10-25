--[[
	BM Hub  -  Blox Fruits
	Executors: Solara / Delta (PC + Mobile)

	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/bm_hub.lua"))()

	کلید RightControl یا دکمه‌ی شناور BM = باز/بسته کردن پنل
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if genv.BMHub and genv.BMHub.Destroy then pcall(genv.BMHub.Destroy) end
local Hub = { Connections = {}, Running = true, Version = "1.10" }
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
local SEA_BY_PLACE = { [2753915549] = 1, [4442272183] = 2, [7449423635] = 3, [79091703265657] = 2 }
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
	FarmDistance = 20, TweenSpeed = 300, AutoClick = true, AttackRange = 60,
	MasteryFarm = false, MasteryWeapon = "Blox Fruit", MasteryHealth = 25,
	UseSkills = true, SkillZ = true, SkillX = true, SkillC = false, SkillV = false,
	AutoFactory = false, AutoEcto = false, AutoRengoku = false, AutoTrident = false, DealerNotify = true,
	AutoHopNear = false, HopDistance = 300, SelectedStyle = nil, AutoSave = true,
	AutoKen = false, AutoRace = false, BossESP = false, BossNotify = true, FruitNotify = true,
	CPUSaver = false, FPSCapOn = false, FPSCap = 30, AutoRejoin = true, StatType2 = "None",
	SelectedBossSpawn = nil,
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
	return S.AutoFarm or S.AutoBoss or S.AutoChest or S.AutoFruit or S.AutoFactory or S.AutoEcto
		or S.AutoRengoku or S.AutoTrident
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
-- تلپورت فوری با سیستم ورودی‌های خود بازی (requestEntrance)؛ سرور اینو قانونی می‌دونه
local FastTP = {
	Entrances = {
		-- inside = ورودی کشتی، outside = خروجی به خشکی
		{ name = "Cursed Ship", sea = 2, inside = Vector3.new(923.21, 126.98, 32852.83), outside = Vector3.new(-6508.56, 89.03, -132.84) },
	},
}

function FastTP.entrance(pos)
	local root = getRoot()
	if not root then return false end
	local before = root.Position
	stopTween()
	invoke("requestEntrance", pos)
	-- اگه تا 2 ثانیه جابجا شدیم یعنی کار کرد
	local t = 0
	while t < 2 do
		t += task.wait(0.1)
		local r = getRoot()
		if r and (r.Position - before).Magnitude > 300 then return true end
	end
	return false
end

-- اگه مسیر از یه ورودی رد میشه، اول با ورودی میریم (فوری) بعد بقیه‌ی راه رو پرواز
function FastTP.hop(target)
	local root = getRoot()
	if not root then return false end
	for _, e in ipairs(FastTP.Entrances) do
		if e.sea == Sea then
			local targetInside = (target - e.inside).Magnitude < 2000
			local amInside = (root.Position - e.inside).Magnitude < 2000
			if targetInside and not amInside then
				S.Status = "Entering " .. e.name .. " (instant)"
				return FastTP.entrance(e.inside)
			elseif amInside and not targetInside then
				S.Status = "Leaving " .. e.name .. " (instant)"
				return FastTP.entrance(e.outside)
			end
		end
	end
	return false
end

local function tweenTo(cf, keepGoing)
	local root = getRoot()
	if not root or not cf then return false end
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	if (root.Position - cf.Position).Magnitude > 3000 and FastTP.hop(cf.Position) then
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
-- "Smoke Admiral [Lv. 1150] [Boss]" -> "Smoke Admiral"
local function mobBaseName(name)
	return (name:gsub("%s*%[.-%]", ""):gsub("^%s+", ""):gsub("%s+$", ""))
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
	local cur, total = txt:match("%((%d+)%s*/%s*(%d+)%)")
	return cur ~= nil and tonumber(cur) >= tonumber(total)
end

local function hasQuest(mob)
	local q = questGui()
	if not q or not q.Visible then return false end
	local ok, txt = pcall(function() return q.Container.QuestTitle.Title.Text end)
	if not ok then return mob == nil end
	if questDone(txt) then return false end
	if not mob then return true end
	return txt:lower():find(mob:lower(), 1, true) ~= nil
end

-- اگه کوئستی چند بار گرفته نشد، یه مدت بدون کوئست فارم می‌کنیم
local questFailures, questBlockedUntil = {}, {}
local function questBlocked(q)
	return (questBlockedUntil[q.quest .. q.index] or 0) > tick()
end

local function takeQuest(q, keepGoing)
	local started = tick()
	local g = questGui()
	-- فقط کوئست یه ماب دیگه رو ول می‌کنیم؛ کوئست تموم‌شده (8/8) خودش تحویل میشه
	if g and g.Visible and not hasQuest(q.mob) then
		local title = ""
		pcall(function() title = g.Container.QuestTitle.Title.Text end)
		if not questDone(title) then invoke("AbandonQuest") end
	end
	S.Status = "Taking quest: " .. q.mob
	if not tweenTo(q.npc, keepGoing) then return end
	-- سرور موقعیت جدید رو با کمی تاخیر می‌بینه
	setFloat(true)
	task.wait(0.3)
	local key = q.quest .. q.index
	local res
	for attempt = 1, 4 do
		if (keepGoing and not keepGoing()) or not alive() then return end
		S.Status = ("Taking quest: %s (try %d/4)"):format(q.mob, attempt)
		local root = getRoot()
		if root then root.CFrame = q.npc end
		res = invoke("StartQuest", q.quest, q.index)
		local waited = 0
		while waited < 0.9 and not hasQuest(q.mob) do
			waited += task.wait(0.1)
		end
		if hasQuest(q.mob) then
			questFailures[key] = 0
			Hub.LastQuestTime = tick() - started
			S.Status = ("Quest taken in %.1fs: %s"):format(Hub.LastQuestTime, q.mob)
			return
		end
	end
	questFailures[key] = (questFailures[key] or 0) + 1
	logError("StartQuest " .. key, "not accepted (" .. tostring(res) .. ")")
	if questFailures[key] >= 2 then
		-- مدت کوتاه بدون کوئست، بعد دوباره تلاش
		questBlockedUntil[key] = tick() + 30
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
		VirtualUser:CaptureController()
		VirtualUser:Button1Down(pos, camera.CFrame)
		VirtualUser:Button1Up(pos, camera.CFrame)
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

local lastRemote = 0
local function remoteAttack(root)
	if not (RegisterAttack and RegisterHit) then return end
	if tick() - lastRemote < 0.1 then return end
	lastRemote = tick()
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

local lastClick = 0
local function attack()
	local root = getRoot()
	if not root then return end
	local m = S.AttackMethod
	if S.FastAttack and (m == "Auto" or m == "Remote") then remoteAttack(root) end
	if tick() - lastClick < 0.12 then return end
	lastClick = tick()
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
local lastSkill = 0
local function useSkills()
	if not S.UseSkills or not VIM or tick() - lastSkill < 0.6 then return end
	lastSkill = tick()
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
	while Hub.Running and keepGoing() and alive() and mob.Parent and hum and hum.Health > 0 do
		local root = getRoot()
		local target = CFrame.new(hrp.Position + Vector3.new(0, S.FarmDistance, 0))
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
		attack()
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
	local g = questGui()
	if not g or not g.Visible then return nil end
	local title
	pcall(function() title = g.Container.QuestTitle.Title.Text end)
	if not title then
		pcall(function()
			for _, d in ipairs(g:GetDescendants()) do
				if d:IsA("TextLabel") and d.Text:lower():find("defeat") then
					title = d.Text
					break
				end
			end
		end)
	end
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
					return
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

-- Sea 2: Factory (Core) و Ectoplasm (ماب‌های Cursed Ship)
local FACTORY_POS = Vector3.new(431, 238, -433)
local CURSED_SHIP_POS = Vector3.new(900.9, 144, 33072.6)
local ECTO_MOBS = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" }

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
				local best, bestDist
				local root = getRoot()
				for _, name in ipairs(ECTO_MOBS) do
					local m = findMob(name)
					if m then
						local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
						if not bestDist or d < bestDist then best, bestDist = m, d end
					end
				end
				if best then
					killMob(best, keep)
				else
					S.Status = "Going to Cursed Ship"
					tweenTo(CFrame.new(CURSED_SHIP_POS + Vector3.new(0, 40, 0)), function() return S.AutoEcto end)
				end
			end)
			if not ok then logError("AutoEcto", err) end
		end
	end
end)

---------------------------------------------------------------------
-- Sea 2 items (Rengoku, Dragon Trident, Legendary Sword Dealer)
---------------------------------------------------------------------
local RENGOKU_CHEST = Vector3.new(6571.2, 299.4, -6967.4)
local ICE_CASTLE = Vector3.new(6062.3, 155.3, -6880.9)
local FORGOTTEN_ISLAND = Vector3.new(-3194.2, 155.3, -10795.3)
local EL_ADMIN = Vector3.new(1321.0, 121.8, 33134.8)
local MYSTERIOUS_MAN = Vector3.new(-2573.5, 1620.7, -3745.2)

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
				if type(item) == "table" and item.Name then set[item.Name] = true end
			end
		end
	end
	inventoryCache, inventoryTime = set, tick()
	return set
end

local function hasItem(name)
	return backpackTool(name) ~= nil or inventoryNames()[name] == true
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
					tweenTo(CFrame.new(RENGOKU_CHEST), keep)
					local det
					pcall(function() det = workspace.Map.IceCastle.RengokuChest.Detection end)
					touchPart(det)
					task.wait(1.5)
					return
				end
				-- Awakened Ice Admiral شانس بیشتری داره (حدود 5%)
				if not fightBoss("Awakened Ice Admiral", keep) then
					farmNearestOf({ "Arctic Warrior", "Snow Lurker" }, keep, ICE_CASTLE)
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
					tweenTo(CFrame.new(FORGOTTEN_ISLAND + Vector3.new(0, 60, 0)), keep)
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

task.spawn(function()
	local delay = 30
	while Hub.Running do
		if S.AutoRandomFruit then
			local ok, info = buyRandomFruit()
			S.Status = "Random fruit: " .. info
			-- اگه نشد کم‌کم صبر بیشتر (تا 5 دقیقه)
			delay = ok and 30 or math.min(delay * 2, 300)
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

-- Auto Rejoin وقتی از بازی بیرون انداخته میشی
pcall(function()
	connect(game:GetService("GuiService").ErrorMessageChanged, function(msg)
		if S.AutoRejoin and msg and msg ~= "" then
			task.wait(3)
			pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
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
-- lowest = true: کم‌جمعیت‌ترین سرور
local function serverHop(lowest)
	local order = lowest and "Asc" or "Desc"
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100")
	end)
	if ok then
		local data = HttpService:JSONDecode(body)
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
			TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, player)
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
	local g = questGui()
	local title = "?"
	pcall(function() title = g.Container.QuestTitle.Title.Text end)
	add("quest gui:", g and g:GetFullName() or "nil", "| visible:", g and g.Visible, "| title:", title)
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
		local function render()
			local on = S[key]
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
local SKIP_SAVE = { Status = true }

local function saveSettings()
	local data = {}
	for k, v in pairs(S) do
		local t = type(v)
		if not SKIP_SAVE[k] and (t == "boolean" or t == "number" or t == "string") then data[k] = v end
	end
	return pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(data)) end)
end

local function loadSettings()
	local ok, data = pcall(function()
		if isfile and not isfile(SETTINGS_FILE) then return nil end
		return HttpService:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if not ok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		if S[k] ~= nil and type(S[k]) == type(v) and not SKIP_SAVE[k] then S[k] = v end
	end
	return true
end

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
do -- صفحه‌ها (متغیرهاشون فقط همین‌جا لازمن)
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
Home:Section("Debug")
Home:Label(function()
	local a = Hub.AttackInfo
	return ("Attacks  remote:%d  click:%d  tool:%d"):format(a.remote, a.click, a.tool)
end)
Home:Button("Copy Debug Report", function()
	local report = debugReport()
	local copied = pcall(function() (setclipboard or toclipboard)(report) end)
	print(report)
	notify("Debug Report", copied and "Copied ✔ — paste it to Claude" or "Printed to console (F9)", 5)
end)

local Farm = createTab("Main Farm", "⚔")
Farm:Section("Auto Farm")
Farm:Toggle("Auto Farm", "AutoFarm", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
Farm:Dropdown("Farm Mode", function() return { "Level", "Nearest Mob", "Selected Mob" } end, "FarmMode")
Farm:Dropdown("Select Mob", mobOptions, "SelectedMob")
Farm:Toggle("Take Quest", "TakeQuest")
Farm:Section("Combat")
Farm:Dropdown("Weapon", function() return { "Melee", "Sword", "Blox Fruit", "Gun" } end, "Weapon")
Farm:Dropdown("Attack Method", function() return { "Auto", "Remote", "Click", "Tool" } end, "AttackMethod")
Farm:Toggle("Auto Click (always attack nearby)", "AutoClick")
Farm:Slider("Attack Range", 10, 150, "AttackRange")
Farm:Toggle("Fast Attack", "FastAttack")
Farm:Toggle("Bring Mobs", "BringMobs")
Farm:Toggle("Auto Haki (Buso)", "AutoHaki")
Farm:Toggle("Auto Observation (Ken)", "AutoKen")
Farm:Toggle("Auto Race Skill (T)", "AutoRace")
Farm:Slider("Farm Height", 0, 60, "FarmDistance")
Farm:Slider("Tween Speed", 100, 350, "TweenSpeed")

local Mastery = createTab("Mastery", "✪")
Mastery:Section("Mastery Farm")
Mastery:Toggle("Mastery Farm (with Auto Farm)", "MasteryFarm")
Mastery:Dropdown("Mastery Weapon", function() return { "Blox Fruit", "Sword", "Gun" } end, "MasteryWeapon")
Mastery:Slider("Switch at Mob HP %", 5, 90, "MasteryHealth")
Mastery:Section("Skills")
Mastery:Toggle("Use Skills", "UseSkills")
Mastery:Toggle("Skill Z", "SkillZ")
Mastery:Toggle("Skill X", "SkillX")
Mastery:Toggle("Skill C", "SkillC")
Mastery:Toggle("Skill V", "SkillV")
Mastery:Label(function() return "Turn on Auto Farm too. Weak mobs get finished with your mastery weapon." end)

local SeaFarm = createTab("Sea Farms", "⚓")
SeaFarm:Section("Second Sea")
SeaFarm:Toggle("Auto Factory (Core)", "AutoFactory", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
SeaFarm:Toggle("Auto Ectoplasm (Cursed Ship)", "AutoEcto", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
local Items = createTab("Items", "✧")
Items:Section("Rengoku")
Items:Toggle("Auto Rengoku (key + chest)", "AutoRengoku", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
Items:Label(function()
	local key = backpackTool("Hidden Key") and "✔ have key" or "no key yet"
	return "Hidden Key: " .. key .. "  •  drops from Ice Admiral / Ice Castle mobs"
end)
Items:Section("Dragon Trident")
Items:Toggle("Auto Dragon Trident (Tide Keeper)", "AutoTrident", function(on)
	if not on then stopTween() S.Status = "Idle" end
end)
Items:Section("Midnight Blade")
Items:Label(function() return "Ectoplasm: " .. formatNumber(invokeCached("ectoCount", 15, "Ectoplasm", "Check") or 0) .. "  •  needs 100" end)
Items:Button("Go to El Admin (buy Midnight Blade)", function()
	tweenTo(CFrame.new(EL_ADMIN + Vector3.new(0, 3, 4)))
	notify("Midnight Blade", "Click El Admin and buy it (100 Ectoplasm)", 6)
end)
Items:Section("True Triple Katana")
Items:Label(function()
	return "Sword Dealer: " .. (dealerPosition() and "<font color=\"#7CFF9B\">SPAWNED</font>" or "not spawned")
end)
Items:Toggle("Sword Dealer Spawn Alert", "DealerNotify")
Items:Button("Go to Legendary Sword Dealer", function()
	local cf = dealerPosition()
	if not cf then return notify("Sword Dealer", "Not spawned right now") end
	tweenTo(cf * CFrame.new(0, 0, 4))
end)
Items:Button("Go to Mysterious Man (TTK)", function()
	tweenTo(CFrame.new(MYSTERIOUS_MAN + Vector3.new(0, 3, 4)))
end)
Items:Label(function() return "TTK: Saddi + Shisui + Wando (300 mastery each) + $2M" end)

-- کلکسیون: کدوم آیتم‌های مهم رو داری و کدوم‌ها مونده (از اینونتوری خود بازی)
local COLLECTION = {
	{ "Sea 1", { "Saber", "Pole (1st Form)", "Gravity Cane", "Trident", "Warden's Sword", "Longsword", "Bisento", "Soul Cane", "Shark Saw", "Jitte" } },
	{ "Sea 2", { "Rengoku", "Dragon Trident", "Midnight Blade", "True Triple Katana", "Koko", "Dual-Headed Blade", "Kabucha", "Bizarre Revolver", "Acidum Rifle" } },
	{ "Sea 3", { "Yama", "Tushita", "Cursed Dual Katana", "Hallow Scythe", "Shark Anchor", "Canvander", "Buddy Sword", "Twin Hooks", "Spikey Trident", "Dark Dagger", "Skull Guitar", "Fox Lamp", "Venom Bow", "Dragonstorm" } },
}
Items:Section("Collection")
for _, group in ipairs(COLLECTION) do
	local seaName, list = group[1], group[2]
	local function missing()
		local out = {}
		for _, item in ipairs(list) do
			if not hasItem(item) then table.insert(out, item) end
		end
		return out
	end
	Items:Label(function()
		local m = #missing()
		local color = m == 0 and "#7CFF9B" or "#FFD166"
		return ("%s:  <font color=\"%s\">%d/%d owned</font>"):format(seaName, color, #list - m, #list)
	end)
	Items:Dropdown("Missing (" .. seaName .. ")", function()
		local m = missing()
		return #m > 0 and m or { "Nothing missing ✔" }
	end, "ViewMissing" .. seaName:gsub(" ", ""))
end

SeaFarm:Label(function()
	return "Ectoplasm: " .. formatNumber(invokeCached("ectoCount", 15, "Ectoplasm", "Check") or 0) .. "  •  Sea " .. (Sea > 0 and Sea or "?")
end)

local Shop = createTab("Shop", "$")
Shop:Section("Codes")
Shop:Button("Redeem All Codes", function()
	notify("Codes", "Redeeming " .. #CODES .. " codes...", 3)
	local n, err = redeemAllCodes()
	notify("Codes", err or ("Sent " .. n .. " codes ✔ (expired ones are ignored)"), 5)
end)
Shop:Section("Fighting Styles")
Shop:Dropdown("Style", styleNames, "SelectedStyle")
Shop:Button("Buy Selected Style", function()
	if not S.SelectedStyle then return notify("Shop", "Select a style first") end
	local r = buyStyle(S.SelectedStyle)
	notify(S.SelectedStyle, r ~= nil and tostring(r) or "Request sent (need beli/fragments + requirements)", 5)
end)
Shop:Section("Abilities")
local function shopButton(label, ...)
	local args = { ... }
	Shop:Button(label, function()
		local r
		for _, a in ipairs(args) do
			r = invoke(table.unpack(a))
			task.wait(0.2)
		end
		notify(label, r ~= nil and tostring(r) or "Request sent", 4)
	end)
end
shopButton("Buy Geppo (Sky Jump)", { "BuyHaki", "Geppo" })
shopButton("Buy Buso Haki", { "BuyHaki", "Buso" })
shopButton("Buy Soru (Flash Step)", { "BuyHaki", "Soru" })
shopButton("Buy Observation (Ken)", { "KenTalk", "Start" }, { "KenTalk", "Buy" })
shopButton("Buy Random Haki Color", { "ColorsDealer", "2" })
Shop:Section("Second Sea")
shopButton("Legendary Sword Dealer (1)", { "LegendarySwordDealer", "1" })
shopButton("Legendary Sword Dealer (2)", { "LegendarySwordDealer", "2" })
shopButton("Legendary Sword Dealer (3)", { "LegendarySwordDealer", "3" })

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
Boss:Button("List Spawned Bosses", function()
	local alive_ = {}
	for _, n in ipairs(bossNames()) do
		if findMobAnywhere(n) then table.insert(alive_, n) end
	end
	notify("Spawned Bosses (" .. #alive_ .. ")", #alive_ > 0 and table.concat(alive_, ", ") or "None right now", 7)
end)
Boss:Section("Boss Locations")
Boss:Dropdown("Boss Spawn", function()
	local out = {}
	for _, b in ipairs(bossSpawns()) do table.insert(out, b.name) end
	return out
end, "SelectedBossSpawn")
Boss:Button("Teleport to Boss Spawn", function()
	for _, b in ipairs(bossSpawns()) do
		if b.name == S.SelectedBossSpawn then return tweenTo(b.cf * CFrame.new(0, 40, 0)) end
	end
	notify("Boss", "Select a boss spawn first")
end)
Boss:Section("Alerts")
Boss:Toggle("Boss Spawn Alert", "BossNotify")
Boss:Toggle("Boss ESP", "BossESP")

local Fruit = createTab("Fruits", "◆")
Fruit:Section("Devil Fruits")
Fruit:Toggle("Auto Collect Fruits", "AutoFruit", function(on)
	if not on then stopTween() end
end)
Fruit:Toggle("Auto Store Fruits", "AutoStore")
Fruit:Toggle("Auto Random Fruit (Cousin)", "AutoRandomFruit")
Fruit:Toggle("Fruit ESP", "FruitESP")
Fruit:Toggle("Fruit Spawn Alert", "FruitNotify")
Fruit:Button("Buy Random Fruit", function()
	local _, info = buyRandomFruit()
	notify("Random Fruit", info, 6)
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
}
Tp:Section("Instant (game entrances)")
Tp:Button("Cursed Ship ⚡ instant", function()
	if Sea ~= 2 then return notify("Teleport", "Cursed Ship is in Sea 2") end
	local ok = FastTP.entrance(FastTP.Entrances[1].inside)
	notify("Cursed Ship", ok and "Teleported ✔" or "Entrance didn't respond, flying instead", 4)
	if not ok then tweenTo(CFrame.new(900.9, 184, 33072.6)) end
end)
Tp:Button("Leave Cursed Ship ⚡ instant", function()
	local ok = FastTP.entrance(FastTP.Entrances[1].outside)
	notify("Cursed Ship", ok and "Back on land ✔" or "Exit didn't respond", 4)
end)
Tp:Section("Quick Places (Sea " .. (Sea > 0 and Sea or "?") .. ")")
for _, place in ipairs(QUICK_PLACES[Sea] or {}) do
	Tp:Button(place[1], function()
		tweenTo(CFrame.new(place[2] + Vector3.new(0, 40, 0)))
	end)
end
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
	local cf = S.SelectedNPC and findNPC(S.SelectedNPC)
	if not cf then return notify("Teleport", "NPC not found") end
	tweenTo(cf * CFrame.new(0, 0, 4))
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
Stats:Dropdown("Split With", function() return { "None", "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType2")
Stats:Slider("Points Per Tick", 1, 100, "StatAmount")
Stats:Toggle("Auto Stats", "AutoStats")

local Visual = createTab("ESP", "◉")
Visual:Section("ESP")
Visual:Toggle("Player ESP", "PlayerESP")
Visual:Toggle("Fruit ESP", "FruitESP")
Visual:Toggle("Chest ESP", "ChestESP")
Visual:Toggle("Boss ESP", "BossESP")

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
Misc:Button("Hop to Low Player Server", function()
	if not serverHop(true) then notify("Server Hop", "No server found") end
end)
Misc:Toggle("Auto Hop When Player Near", "AutoHopNear")
Misc:Slider("Hop Distance", 50, 1000, "HopDistance")
Misc:Button("Rejoin", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
Misc:Button("FPS Boost", function()
	fpsBoost()
	notify("FPS Boost", "Done ✔")
end)
Misc:Section("AFK")
Misc:Toggle("CPU Saver (no 3D render)", "CPUSaver", function(on)
	pcall(function() RunService:Set3dRenderingEnabled(not on) end)
end)
Misc:Toggle("FPS Cap", "FPSCapOn", function(on)
	if not setfpscap then return notify("FPS Cap", "Executor has no setfpscap") end
	setfpscap(on and S.FPSCap or 0)
end)
Misc:Slider("Max FPS", 10, 120, "FPSCap", function(v)
	if S.FPSCapOn and setfpscap then pcall(setfpscap, v) end
end)
Misc:Toggle("Auto Rejoin On Kick", "AutoRejoin")
Misc:Section("Settings")
Misc:Toggle("Auto Save Settings", "AutoSave")
Misc:Button("Save Settings", function()
	notify("Settings", saveSettings() and "Saved ✔" or "Save failed (executor has no writefile)", 3)
end)
Misc:Button("Load Settings", function()
	notify("Settings", loadSettings() and "Loaded ✔  re-run the hub to refresh the UI" or "No saved settings", 4)
end)
Misc:Button("Destroy Hub", function() Hub.Destroy() end)
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
