"""Offline simulation of v3_src/50_brain.lua: fake game state, real Brain code."""
import pathlib
import sys

src_path = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\50_brain.lua")
out = pathlib.Path(sys.argv[1])
logic = src_path.read_text(encoding="utf-8").partition("--@@UI@@\n")[0]
logic += src_path.with_name("60_planner.lua").read_text(encoding="utf-8").partition("--@@UI@@\n")[0]
logic += src_path.with_name("70_styles.lua").read_text(encoding="utf-8").partition("--@@UI@@\n")[0]

PRELUDE = r'''
local clock = 1000
local function tick() return clock end
local spawned = {}
local task = { wait = function() end, delay = function(_, fn) spawned.delayed = fn end, spawn = function(fn, ...)
	if fn == nil then return end
	-- background loops are skipped; hookCharacter is not needed here
end }
local Sea = 3
local levelValue = 2800
local items, fruits, mobsAnywhere, bossList = {}, {}, {}, {}
local S = { AttackRange = 60, UseSkills = true, SkillZ = true, SkillX = true }
local Hub = { Running = true, V3Tasks = {}, V3 = {}, AttackInfo = {}, V3SkipSave = {} }
local stopped = 0
Hub.V3.log = function() end
Hub.V3.notify = function() end
Hub.V3.once = function(_, fn) fn() end
Hub.V3.resetOnce = function() end
Hub.V3.key = function() end
Hub.V3.webhook = function() end
Hub.Special = {
	{ id = "SoulReaper", label = "Soul Reaper", names = { "Soul Reaper" }, sea = 3 },
	{ id = "CursedCaptain", label = "Cursed Captain", names = { "Cursed Captain" }, sea = 2 },
}
Hub.SpecialSpawned = function(b) return mobsAnywhere[b.names[1]] and b.names[1] or nil end
local function dataValue(k) if k == "Level" then return levelValue end end
local function backpackTool(n) return items[n] end
local function serverHop() end
local function isAliveMob() return false end
local function findMobAnywhere(n) return mobsAnywhere[n] end
local function bossNames() return bossList end
local function mobLevel(b) return b.level end
local function getWorldFruits() return fruits end
local function stopTween() stopped += 1 end
local function setFloat() end
local function alive() return true end
local rootObj = nil
local function getRoot() return rootObj end
local weaponList, owned = {}, {}
local function invoke(cmd) if cmd == "getInventoryWeapons" then return weaponList end end
local function hasItem(n) return owned[n] == true end
local function inventoryNames() return owned end
local function formatNumber(n) return tostring(n) end
local bought = {}
local function buyStyle(n) table.insert(bought, n); return "ok" end
local function findNPC() return nil end
local matCounts = {}
local function materialCount(n) return matCounts[n] or 0 end
local CFrame = { new = function() return {} end }
local playerList = {}
local Players = { GetPlayers = function() return playerList end }
local Enum = { TeleportState = { Failed = "Failed" }, KeyCode = {} }
local function getHum() return nil end
local charObj, nearMob = nil, nil
local function getChar() return charObj end
local function nearestMobInRange() return nearMob end
local function mobBaseName(n) return n end
local function mainFarmBusy() return false end
local function logError(w, e) error(w .. ": " .. tostring(e)) end
local function connect() end
local camera, VIM = {}, nil
local Svc = { Http = { JSONDecode = function() return {} end, JSONEncode = function() return "{}" end } }
local player = { CharacterAdded = {}, Character = nil, Name = "tester", OnTeleport = {}, FindFirstChild = function() return nil end }
local workspace = { FindFirstChild = function() return nil end }
local vecMeta = {}
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vecMeta) end }
vecMeta.__sub = function(a, b)
	local v = Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	return { Magnitude = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2), Unit = v }
end
local isfile = function() return false end
local os = { date = function() return "00:00:00 " end }
'''

TESTS = r'''
local Brain = Hub.Brain
assert(Brain.ready, "module did not finish")
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local function step(dt) clock += dt or 2; Brain.tick() end
local cur = function() return Brain.current and Brain.current.id end

S.BrainOn = true
step()
check("no opportunity -> goal Auto Farm", cur() == "GoalAuto Farm" and S.AutoFarm == true)

fruits[1] = {}
step()
check("urgent fruit interrupts the goal, goal flag off", cur() == "Fruit" and S.AutoFruit == true and S.AutoFarm == false)
check("switching stopped the tween", stopped >= 1)
fruits[1] = nil
step()
check("back to goal when fruit gone", cur() == "GoalAuto Farm" and S.AutoFruit == false and S.AutoFarm == true)

mobsAnywhere["Diablo"] = {}
step()
check("Elite picked", cur() == "Elite" and S.AutoElite == true)
bossList[1] = "Weak Boss"
mobsAnywhere["Weak Boss"] = { level = 100 }
mobsAnywhere["Diablo"] = nil
step()
check("WorldBoss picked and SelectedBoss set", cur() == "WorldBoss" and S.SelectedBoss == "Weak Boss" and S.AutoBoss == true)

bossList[2] = "Other Boss"
mobsAnywhere["Other Boss"] = { level = 200 }
mobsAnywhere["Weak Boss"] = nil
bossList[1] = "Other Boss"; bossList[2] = nil
step(20)
check("target replaced after the boss died", S.SelectedBoss == "Other Boss")

S.BrainDeaths = 2
Brain.onDeath()
clock += 5
Brain.onDeath()
step()
check("boss that killed twice is avoided, back to goal", cur() == "GoalAuto Farm" and Brain.ban["Other Boss"] ~= nil)
clock += 901
step()
check("ban expires after 15 min", cur() == "WorldBoss")
mobsAnywhere["Other Boss"] = nil
step()

local strong = { level = 9999 }
mobsAnywhere["Too Strong"] = strong
bossList[1] = "Too Strong"
step(20)
check("boss far above your level ignored", cur() == "GoalAuto Farm")
mobsAnywhere["Too Strong"] = nil

mobsAnywhere["Soul Reaper"] = {}
step()
check("special boss flag used", cur() == "SoulReaper" and S.KillSoulReaper == true and S.AutoFarm == false)
mobsAnywhere["Soul Reaper"] = nil
step()

fruits[1] = {}
step()
check("fruit job started", cur() == "Fruit")
clock += 61
step()
check("stuck fruit job rested after maxRun", cur() == "GoalAuto Farm" and Brain.ban.Fruit ~= nil)
fruits[1] = nil

S.AutoCDK = true
step()
check("long job pauses Brain, flags off", Brain.current == nil and S.AutoFarm == false and Brain.why:find("AutoCDK") ~= nil)
S.AutoCDK = false
step()
check("resumes after long job", cur() == "GoalAuto Farm")

S.BrainGoal = "Bones"
step()
check("goal change applied", S.AutoBone == true and S.AutoFarm == false)
S.BrainGoal = "Ectoplasm"
step()
check("goal of another sea falls back", cur() == "GoalAuto Farm")

-- learned dodge
local normalWatched = false
Hub.WatchMob({ Name = "Demonic Soul" }, { AnimationPlayed = { Connect = function() normalWatched = true end } })
check("normal mobs are never watched for dodging", normalWatched == false)
local mob, played = { Name = "Stone [Lv. 2000] [Boss]" }, nil
local hum = { AnimationPlayed = { Connect = function(_, fn) played = fn end } }
Hub.WatchMob(mob, hum)
local track = { Looped = false, Length = 2, Animation = { AnimationId = "rbxassetid://1" } }
played(track)
Brain.learnHit()
check("one hit is not enough", Brain.learnedCount() == 0)
clock += 3
played(track)
check("no dodge yet", Hub.DodgeY == 0)
Brain.learnHit()
check("learned after two hits", Brain.learnedCount() == 1)
clock += 3
played(track)
check("dodges on the third time", Hub.DodgeY == S.DodgeHeight and Brain.dodges == 1)
clock += 2
spawned.delayed()
check("comes back down after the attack", Hub.DodgeY == 0)
played({ Looped = true, Length = 2, Animation = { AnimationId = "rbxassetid://2" } })
Brain.learnHit()
check("looped animations are never learned", Brain.danger["rbxassetid://2"] == nil)

-- carry
items["Fist of Darkness"] = { Name = "Fist of Darkness" }
check("Safe Carry blocks chests", Hub.CarryBlock() == true)
S.SafeCarry = false
check("Safe Carry off", Hub.CarryBlock() == false)

-- smart retreat
check("no hits, no danger", Hub.InDanger(1000) == false)
Brain.recordHit(600)
check("3s of 600 damage leaves 1000 HP 5s: safe", Hub.InDanger(1000) == false)
Brain.recordHit(600)
check("doubled damage: dead in 2.5s, retreat", Hub.InDanger(1000) == true)
clock += 4
check("old hits expire", Hub.InDanger(1000) == false)

-- rest doubling
fruits[1] = {}
S.BrainGoal = "Auto Farm"
clock += 2000
step()
check("fruit job again", cur() == "Fruit")
clock += 61
step()
local firstBan = Brain.ban.Fruit - clock
clock += firstBan + 1
step()
clock += 61
step()
local secondBan = Brain.ban.Fruit - clock
check("rest time grows when a job keeps failing", secondBan > firstBan)
fruits[1] = nil
Brain.ban.Fruit = nil

-- account plan
local P = Hub.Planner
assert(P and P.ready, "planner did not finish")
weaponList = { { Name = "Yama", Type = "Sword", Mastery = 100, Rarity = 3 }, { Name = "Katana", Type = "Sword", Mastery = 10, Rarity = 0 },
	{ Name = "Tushita", Type = "Sword", Mastery = 400, Rarity = 3 }, { Name = "Pole", Type = "Gun", Mastery = 1 } }
owned = { Yama = false }
check("scan works", P.scan() == true)
S.BrainGoal = "Account Plan"
step()
check("plan starts at Yama and claims its flag", cur() == "PlanYama" and S.AutoYama == true and S.AutoFarm == false)
check("claimed step does not pause Brain", Brain.why:find("Paused") == nil)
mobsAnywhere["Soul Reaper"] = {}
step()
check("urgent boss interrupts the plan", cur() == "SoulReaper" and S.AutoYama == false)
mobsAnywhere["Soul Reaper"] = nil
step()
check("plan resumes", cur() == "PlanYama" and S.AutoYama == true)
S.AutoYama = false -- the step finished and switched itself off
owned.Yama = true
step()
check("next step after self-off", cur() == "PlanTushita" and S.AutoTushita == true)
owned.Tushita = true
P.scan()
step()
check("CDK blocked by mastery falls back to farm", cur() == "GoalAuto Farm" and P.needMastery.Yama == 350 and P.needMastery.Tushita == nil)
check("plan line explains the block", P.stepLine(3):find("350 mastery on Yama") ~= nil)
check("mastery trains the sword the plan needs", P.pickMastery().Name == "Yama")
S.AutoFarm = true
P.runMastery()
check("mastery farm enabled with the sword", S.MasteryFarm == true and S.MasteryWeapon == "Sword" and P.masteryName == "Yama")
weaponList[1].Mastery = 350
P.scan()
step()
check("mastery done -> CDK step", cur() == "PlanCDK" and S.AutoCDK == true)
P.runMastery()
check("mastery farm off when nothing left (target 350, Katana excluded when not asked)", S.MasteryFarm == false)
S.SmartMastery = true
S.MasteryTarget = 350
P.scan()
check("smart mastery picks the remaining sword", P.pickMastery().Name == "Katana")
S.SmartMastery = false

-- real game data: getInventoryWeapons has no Mastery, the Level child of a loaded tool does
local savedWeapons = weaponList
weaponList = { { Name = "Shizu", Type = "Sword", Rarity = 3 }, { Name = "Koko", Type = "Sword", Rarity = 3 }, { Name = "Pipe", Type = "Sword", Rarity = 2 } }
P.mastery, P.loadTries = {}, {}
S.SmartMastery, S.MasteryTarget, S.AutoFarm = true, 350, true
P.scan()
check("missing Mastery field is unknown, not 0", P.mastery.Shizu == nil)
local loaded = {}
invoke = invoke
local pick = P.pickMastery()
check("unknown sword is picked to be checked (highest rarity first)", pick.Name == "Shizu" or pick.Name == "Koko")
local shizuTool = { Name = "Shizu", IsA = function() return true end, FindFirstChild = function(_, n) return n == "Level" and { Value = 600 } or nil end }
player.FindFirstChild = function(_, n) return n == "Backpack" and { GetChildren = function() return { shizuTool } end } or nil end
P.scan()
check("mastery read from the tool's Level", P.mastery.Shizu == 600)
check("maxed sword is skipped", P.pickMastery().Name ~= "Shizu")
P.loadTries.Koko, P.loadTries.Pipe = 3, 3
check("a sword that never loads is given up after 3 tries", P.pickMastery() == nil)
player.FindFirstChild = function() return nil end
P.mastery, P.loadTries = {}, {}
S.SmartMastery = false
weaponList = savedWeapons
P.scan()

-- best income
S.BrainGoal = "Best Income"
S.BestTrial = 5
S.BrainMetric = "Beli"
local tried = {}
for _ = 1, 40 do
	local n = P.bestGoal()
	tried[n] = true
	P.addTime(n, 300)
	local e = P.entry(n)
	e.Beli += n == "Bones" and 900000 or 100000
	clock += 300
end
check("every candidate was tried", tried["Auto Farm"] and tried.Chests and tried.Bones and tried["Cake Prince"])
check("elite and sea events stay out of the test", not tried["Elite Hunter"] and not tried["Sea Events"])
P.activeUntil = 0
P.checkedAt = clock
check("exploits the best job", P.bestGoal() == "Bones")
step()
check("Best Income drives the flags", S.AutoBone == true and Brain.current.label == "Bones")
check("ledger ranks it first", P.topJobs()[1].label == "Bones")
clock += 1801
P.activeUntil = 0
check("re-checks another job every 30 min", P.bestGoal() ~= "Bones")

-- fruit M1
local fired = {}
local remote = { FireServer = function(_, dir, combo) table.insert(fired, { dir = dir, combo = combo }) end }
local fruitTool = { Name = "Dragon-Dragon", FindFirstChild = function(_, n) return n == "LeftClickRemote" and remote or nil end }
local meleeTool = { Name = "Sanguine Art", FindFirstChild = function() return nil end }
local held = meleeTool
charObj = { FindFirstChildOfClass = function() return held end }
local me = { Position = Vector3.new(0, 12, 0) }
nearMob = { HumanoidRootPart = { Position = Vector3.new(10, 0, 0) } }
Brain.store.fruit["Dragon-Dragon"] = { gap = 0.1, v = 2 }
check("melee in hand: no fruit mode", Hub.FruitM1(me) == nil and #fired == 0)
held = fruitTool
check("saved mode is returned", Hub.FruitM1(me).gap == 0.1)
check("fruit with M1 fires", #fired == 1)
check("direction points from you to the mob", fired[1].dir.X == 10 and fired[1].dir.Y == -12 and fired[1].combo == 1)
Hub.FruitM1(me)
check("no second hit inside the gap", #fired == 1)
clock += 0.05
Hub.FruitM1(me)
check("still inside the 0.1s gap", #fired == 1)
clock += 0.06
Hub.FruitM1(me)
check("same speed as the melee hit (0.1s)", #fired == 2)
for i = 1, 3 do
	clock += 0.11
	Hub.FruitM1(me)
end
check("combo runs 1 to 4 and starts over", fired[2].combo == 2 and fired[4].combo == 4 and fired[5].combo == 1)
nearMob = nil
clock += 1
local count = #fired
Hub.FruitM1(me)
check("no mob in range: nothing is sent", #fired == count)
nearMob = { HumanoidRootPart = { Position = Vector3.new(10, 0, 0) } }
S.FruitM1 = false
Hub.FruitM1(me)
check("switch off sends nothing", #fired == count)
S.FruitM1 = true
remote.FireServer = function() error("boom") end
clock += 1
Hub.FruitM1(me)
check("a remote error does not break the attack loop", Hub.AttackInfo.lastError:find("boom") ~= nil)

-- fruit test: mode 3 (gap 0.5, no animation) deals the most
local newRemote = { FireServer = function() end }
local kitsune = { Name = "Kitsune-Kitsune", FindFirstChild = function(_, n) return n == "LeftClickRemote" and newRemote or nil end }
held = kitsune
check("status before first fight", Brain.fruitStatus(kitsune):find("first fight") ~= nil)
local function fightMode(dmgPerSample, mobs)
	for _ = 1, 16 do Brain.tuneStep(dmgPerSample, mobs) end
end
local first = Hub.FruitM1(me)
check("first mode is 0.2s", first.gap == 0.2)
check("no mode uses clicks or the melee hit", first.click == nil and first.hit == nil)
check("status shows the test", Brain.fruitStatus(kitsune):find("1/8") ~= nil)
fightMode(500, 5)
check("moves to the next mode", Hub.FruitM1(me).gap == 0.3)
Brain.tuneStep(1000, 0)
check("time without mobs is not counted", Brain.fruitStatus(kitsune):find("2/8") ~= nil)
fightMode(800, 5)
check("mode 3 is 0.5s", Hub.FruitM1(me).gap == 0.5)
fightMode(1500, 5)
check("5.9: no slow 0.8s step any more", Hub.FruitM1(me).gap ~= 0.8)
-- 5.10: چهار حالت کمبوی کوتاه‌تر قبل از ضربه‌ی ملی
for _ = 1, 4 do
	local cm = Hub.FruitM1(me)
	check("5.10: combo step " .. tostring(cm.combo), cm.combo ~= nil and cm.combo < 4)
	fightMode(300, 5)
end
check("last mode is the melee hit", Hub.FruitM1(me).melee == true)
fightMode(200, 5)
local best = Brain.store.fruit["Kitsune-Kitsune"]
check("best mode saved (0.5s)", best and best.gap == 0.5)
check("test uses the saved mode from now on", Hub.FruitM1(me) == best)
check("status says no screen clicks", Brain.fruitStatus(kitsune):find("no screen clicks") ~= nil)
-- the click result saved by v3.8 must be thrown away
Brain.store.fruit["Old-Old"] = { click = true }
held = { Name = "Old-Old", FindFirstChild = kitsune.FindFirstChild }
check("old click result is not used", Hub.FruitM1(me).gap == 0.2)
check("old click result starts a new test", Brain.fruitStatus(held):find("1/8") ~= nil)
Brain.retestFruit(held)
-- more mobs must not beat better damage per mob
held = { Name = "Rumble-Rumble", FindFirstChild = kitsune.FindFirstChild }
Hub.FruitM1(me)
fightMode(1000, 10)
fightMode(600, 2)
for _ = 1, 6 do fightMode(100, 5) end
check("score is per mob, not per crowd", Brain.store.fruit["Rumble-Rumble"].gap == 0.3)
Brain.retestFruit(held)
check("re-test clears the saved mode", Brain.store.fruit["Rumble-Rumble"] == nil)
charObj, nearMob = nil, nil

-- real damage measurement
local hp = { Health = 1000 }
local dmgMob = { FindFirstChildOfClass = function() return hp end, FindFirstChild = function() return { Position = Vector3.new(5, 0, 0) } end }
local realWorkspaceFind = workspace.FindFirstChild
workspace.FindFirstChild = function() return { GetChildren = function() return { dmgMob } end } end
rootObj = { Position = Vector3.new(0, 0, 0) }
Hub.DamageRate()
Brain.sampleDamage()
clock += 1
hp.Health = 700
Brain.sampleDamage()
clock += 1
hp.Health = 900
Brain.sampleDamage()
check("damage per second counts HP lost, ignores healing", Hub.DamageRate() == 150)
workspace.FindFirstChild = realWorkspaceFind
rootObj = nil

-- fighting style plan (pure)
local St = Hub.Styles
assert(St and St.ready, "styles did not finish")
local function state(o)
	local st = { owned = o.owned or {}, mastery = o.mastery or {}, beli = o.beli or 0, frag = o.frag or 0, sea = o.sea or 3 }
	st.mats = function(n) return (o.mats or {})[n] or 0 end
	st.items = function(n) return (o.items or {})[n] == true end
	st.teacherSea = function() return nil end
	return st
end
local all5 = { Superhuman = true, ["Death Step"] = true, ["Sharkman Karate"] = true, ["Electric Claw"] = true, ["Dragon Talon"] = true }
local m400 = { Superhuman = 400, ["Death Step"] = 400, ["Sharkman Karate"] = 400, ["Electric Claw"] = 400, ["Dragon Talon"] = 400 }
local fullMats = { ["Fish Tail"] = 20, ["Magma Ore"] = 20, ["Dragon Scale"] = 10, ["Mystic Droplet"] = 10 }
check("owned target: nothing to do", St.plan("Godhuman", state({ owned = { Godhuman = true } })) == nil)
local s1 = St.plan("Godhuman", state({}))
check("from zero: starts with Black Leg", s1.kind == "money" and s1.style == "Black Leg")
local s2 = St.plan("Godhuman", state({ beli = 1e9, frag = 1e9 }))
check("with money: buys Black Leg first", s2.kind == "buy" and s2.style == "Black Leg")
local s3 = St.plan("Godhuman", state({ owned = { ["Black Leg"] = true }, mastery = { ["Black Leg"] = 120 }, beli = 1e9, frag = 1e9 }))
check("owned Black Leg is trained to 300 first", s3.kind == "mastery" and s3.style == "Black Leg" and s3.need == 300)
local s3b = St.plan("Godhuman", state({ owned = { ["Black Leg"] = true }, mastery = { ["Black Leg"] = 300 }, beli = 1e9, frag = 1e9 }))
check("then Electro is bought", s3b.kind == "buy" and s3b.style == "Electro")
local four = { ["Black Leg"] = true, Electro = true, ["Fishman Karate"] = true, ["Dragon Claw"] = true }
local s4 = St.plan("Godhuman", state({ owned = four, mastery = { ["Black Leg"] = 300, Electro = 250, ["Fishman Karate"] = 300, ["Dragon Claw"] = 300 }, beli = 1e9, frag = 1e9 }))
check("mastery gap found", s4.kind == "mastery" and s4.style == "Electro" and s4.need == 300 and s4.have == 250)
local s5 = St.plan("Godhuman", state({ owned = four, mastery = { ["Black Leg"] = 300, Electro = 300, ["Fishman Karate"] = 300, ["Dragon Claw"] = 300 }, beli = 1e9, frag = 1e9 }))
check("all four at 300: buy Superhuman", s5.kind == "buy" and s5.style == "Superhuman")
local own = { Superhuman = true, ["Black Leg"] = true }
local s6 = St.plan("Godhuman", state({ owned = own, mastery = { Superhuman = 400, ["Black Leg"] = 400 }, beli = 1e9, frag = 1e9 }))
check("Death Step needs the Library Key", s6.kind == "item" and s6.item == "Library Key" and s6.why:find("Ice Admiral") ~= nil)
local s7 = St.plan("Godhuman", state({ owned = own, mastery = { Superhuman = 400, ["Black Leg"] = 300 }, beli = 1e9, frag = 1e9 }))
check("Death Step needs Black Leg 400 before the key", s7.kind == "mastery" and s7.style == "Black Leg" and s7.need == 400)
local s8 = St.plan("Godhuman", state({ owned = all5, mastery = { Superhuman = 400, ["Death Step"] = 400, ["Sharkman Karate"] = 400, ["Electric Claw"] = 399, ["Dragon Talon"] = 400 } }))
check("one style at 399 is caught", s8.kind == "mastery" and s8.style == "Electric Claw")
local s9 = St.plan("Godhuman", state({ owned = all5, mastery = m400, mats = { ["Fish Tail"] = 20, ["Magma Ore"] = 5 } }))
check("materials checked after mastery", s9.kind == "material" and s9.mat == "Magma Ore" and s9.have == 5)
local s10 = St.plan("Godhuman", state({ owned = all5, mastery = m400, mats = fullMats, beli = 4999999, frag = 9000 }))
check("money is checked before buying", s10.kind == "money")
local s11 = St.plan("Godhuman", state({ owned = all5, mastery = m400, mats = fullMats, beli = 5e6, frag = 5000, sea = 2 }))
check("Godhuman only in Sea 3", s11.kind == "sea" and s11.sea == 3)
local s12 = St.plan("Godhuman", state({ owned = all5, mastery = m400, mats = fullMats, beli = 5e6, frag = 5000 }))
check("everything ready: buy Godhuman", s12.kind == "buy" and s12.style == "Godhuman")
local s13 = St.plan("Godhuman", state({ owned = all5, mastery = { Superhuman = 400 } }))
check("unknown mastery stops instead of guessing", s13.kind == "unknown" and s13.why:find("Death Step") ~= nil)
local s14 = St.plan("Electric Claw", state({ owned = { Electro = true }, mastery = { Electro = 400 }, beli = 1e9, frag = 1e9 }))
check("Electric Claw mentions its quest", s14.kind == "buy" and s14.why:find("Previous Hero") ~= nil)
local lines = St.lines("Godhuman", state({ owned = all5, mastery = m400, mats = { ["Fish Tail"] = 20 } }))
check("checklist lists 5 styles and 4 materials", #lines == 9 and lines[1]:find("✔ Superhuman") ~= nil and lines[7]:find("· Magma Ore") ~= nil)

-- running the plan in the game
Hub.Planner.weapons = {}
owned = {}
player.FindFirstChild = function() return nil end
S.StyleTarget, S.AutoFarm, S.AutoMaterial, S.StyleBuy = "Godhuman", false, false, false
St.tick()
check("no style data from the game: does nothing", St.step.kind == "unknown" and S.AutoFarm == false and #bought == 0)
Hub.Planner.weapons = { { Name = "Superhuman", Type = "Melee", Mastery = 120 } }
local meleeHeld = { Name = "Superhuman", ToolTip = "Melee", IsA = function() return true end, FindFirstChild = function() return nil end }
charObj = { GetChildren = function() return { meleeHeld } end, FindFirstChildOfClass = function() return meleeHeld end }
player.FindFirstChild = function() return nil end
St.tick()
check("mastery step farms with the style in hand", St.step.kind == "mastery" and S.AutoFarm == true and S.Weapon == "Melee" and #bought == 0)
Hub.Planner.weapons = { { Name = "Superhuman", Type = "Melee", Mastery = 400 }, { Name = "Black Leg", Type = "Melee", Mastery = 400 } }
St.tick()
check("item missing: stops farming, nothing bought", St.step.kind == "item" and S.AutoFarm == false and #bought == 0)
charObj = nil

-- sword-like fruits (Light, Ice) hit like melee from the start
local lightRemote = { FireServer = function() error("must not fire") end }
local light = { Name = "Light-Light", FindFirstChild = function(_, n) return n == "LeftClickRemote" and lightRemote or nil end }
held = light
charObj = { FindFirstChildOfClass = function() return held end }
nearMob = { HumanoidRootPart = { Position = Vector3.new(10, 0, 0) } }
local lm = Hub.FruitM1(me)
check("Light starts in melee mode, no fruit M1 sent", lm and lm.melee == true)
check("status says melee", Brain.fruitStatus(light):find("melee") ~= nil)
Brain.retestFruit(light)
check("re-test really tests (starts at mode 1)", Hub.FruitM1(me).gap == 0.2 and Brain.fruitStatus(light):find("1/8") ~= nil)
Brain.retestFruit(light)
Brain.store.fruit["Light-Light"] = nil
charObj, nearMob = nil, nil

-- boss detection by known names
bossList[1] = "Named Boss"
clock += 31
check("boss found by name without the [Boss] tag", Brain.isBoss({ Name = "Named Boss" }) == true)
check("elite counts as boss", Brain.isBoss({ Name = "Diablo" }) == true)
check("normal mob is not a boss", Brain.isBoss({ Name = "Living Zombie" }) == false)

-- loot
P.watchLoot({ A = true })
local before = #Brain.log
P.watchLoot({ A = true, ["Dark Blade"] = true })
check("new item noticed", Brain.log[1]:find("Dark Blade") ~= nil)

-- pk guard
S.PKGuard = true
rootObj = { Position = Vector3.new(0, 0, 0) }
local hopCount = 0
Brain.hop = function() hopCount += 1 end
task.spawn = function(fn) if fn == Brain.hop then fn() end end
items = {}
local function nearby(dist)
	return { Name = "rival", Character = { FindFirstChild = function() return { Position = Vector3.new(dist, 0, 0) } end } }
end
playerList = { nearby(500) }
Brain.onHeavyHit(30)
Brain.onHeavyHit(30)
check("far player is not blamed", hopCount == 0)
playerList = { nearby(50) }
Brain.onHeavyHit(30)
check("one hit does not hop", hopCount == 0)
clock += 2
Brain.onHeavyHit(30)
check("second hit hops", hopCount == 1)
clock += 2
Brain.onHeavyHit(30)
Brain.onHeavyHit(30)
check("no hop spam within 30s", hopCount == 1)
items["God's Chalice"] = { Name = "God's Chalice" }
clock += 40
Brain.onHeavyHit(30)
Brain.onHeavyHit(30)
check("never hops with a rare item", hopCount == 1)

print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

out.write_text(PRELUDE + logic + TESTS, encoding="utf-8")
