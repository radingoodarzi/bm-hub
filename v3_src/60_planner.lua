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

--@@UI@@
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

--@@UI-LATE@@
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
