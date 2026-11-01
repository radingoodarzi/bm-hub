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
	local LOADER = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()'
	for k, v in pairs({
		BrainOn = false, BrainGoal = "Auto Farm", BrainBosses = true, BrainEvents = true, BrainElite = true, BrainFruits = true,
		BrainSeas = false, BrainDeaths = 2,
		Watchdog = true, WatchdogSec = 45,
		SmartDodge = true, DodgeHeight = 70, DodgeLearn = 12, DodgeAfter = 2,
		SmartSkills = true, SmartRace = false, SmartRetreat = true, DeathTime = 3,
		ChestHop = false, ChestHopAt = 20, SafeCarry = true,
	}) do
		if S[k] == nil then S[k] = v end
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
		"AutoRaceV2", "AutoRaceV3", "AutoSoulGuitar", "AutoStyles", "AutoSeaBeast", "AutoMaterial" }
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
		local wasOn = false
		while Hub.Running do
			task.wait(1.5)
			if S.BrainOn and not wasOn then
				savedFlags = { SelectedBoss = S.SelectedBoss }
				for f in pairs(managed) do savedFlags[f] = S[f] == true end
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
			wasOn = S.BrainOn
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
	Brain.store = { danger = danger, ledger = {} } -- هر چیزی که مغز یاد می‌گیره و باید بمونه
	pcall(function()
		if isfile and not isfile(BRAIN_FILE) then return end
		local d = Svc.Http:JSONDecode(readfile(BRAIN_FILE))
		for id, v in pairs(type(d) == "table" and d.danger or {}) do danger[id] = v end
		if type(d.ledger) == "table" then Brain.store.ledger = d.ledger end
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

	local watched = setmetatable({}, { __mode = "k" })
	function Hub.WatchMob(mob, hum)
		if not S.SmartDodge or not hum or watched[hum] then return end
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
				if m.Name:find("[Boss]", 1, true) then return true end
				n += 1
			end
		end
		return n >= 3
	end
	Brain.fightWorthIt = fightWorthIt

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

--@@UI@@
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
	T:Section("Learned Dodge")
	T:Toggle("Learn And Dodge Boss Attacks", "SmartDodge")
	T:Slider("Lift Height While Dodging", 30, 75, "DodgeHeight")
	T:Slider("Heavy Hit = % Of Max HP", 5, 40, "DodgeLearn")
	T:Slider("Dodge After Seeing It N Times", 1, 5, "DodgeAfter")
	T:Label(function() return ("Learned attacks: %d  •  Dodges this session: %d"):format(Brain.learnedCount(), Brain.dodges) end)
	T:Button("Forget Learned Attacks", function()
		Brain.forget()
		notify("Learned Dodge", "Cleared", 3)
	end)
	T:Section("Smart Combat")
	T:Toggle("Smart Skills (bosses and groups of 3+)", "SmartSkills")
	T:Toggle("Smart Race Transform (energy full + worthy fight)", "SmartRace")
	T:Toggle("Smart Retreat (leaves before you die, uses Auto Retreat)", "SmartRetreat")
	T:Slider("Retreat If Dead In N Seconds", 1, 8, "DeathTime")
	T:Section("Stuck Guard")
	T:Toggle("Fix Stuck Farms By Itself", "Watchdog")
	T:Slider("Stuck After (seconds)", 30, 180, "WatchdogSec")
	T:Label(function() return ("Rescues: %d  •  Deaths: %d"):format(Brain.rescues, Brain.deathTotal) end)
	T:Section("Chests")
	T:Toggle("Chest Hop", "ChestHop")
	T:Slider("Hop After N Chests", 5, 60, "ChestHopAt")
	T:Toggle("Safe Carry (no chests with Fist / Chalice)", "SafeCarry")
	T:Label(function() return "Chests this server: " .. Hub.ChestsTaken .. (Hub.CanQueue and "" or "  •  hub won't restart after a hop here") end)
	T:Section("Session Income")
	T:Label(function() return "XP / hour: " .. formatNumber(math.floor(Brain.perHour("Exp"))) end)
	T:Label(function() return "Beli / hour: " .. formatNumber(math.floor(Brain.perHour("Beli"))) end)
	T:Label(function() return "Fragments / hour: " .. formatNumber(math.floor(Brain.perHour("Fragments"))) end)
	T:Button("Reset Income Stats", function() Brain.resetStats() end)
end
