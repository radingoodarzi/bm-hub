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
	for k, v in pairs({ KenFarm = false, KenRest = 30 }) do
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
		if ctx.kenOn then return "dodge" end
		if ctx.resting and ctx.hpFrac < 0.8 then return "rest" end
		if ctx.now < ctx.restUntil then return "rest" end
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
			local t0, checkAt = tick(), tick()
			while keep() and alive() and kenOn() and isAliveMob(mob) and hpFrac() >= 0.35 and tick() - t0 < 6 do
				Hub.HoldAttackUntil = tick() + 2
				-- هر ثانیه شمارش: به عدد سفارش که رسید همون موقع وایسه، نه چند جاخالی بعد
				if tick() - checkAt >= 1 then
					checkAt = tick()
					local now = Ken.progress(job, Ken.points(true))
					if now and now.finished then break end
				end
				setFloat(false)
				root = getRoot()
				if root then root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
				task.wait(0.1)
			end
			-- هاکی همین الان تموم شد: از الان وقت پر شدن حساب میشه
			if not kenOn() then restUntil, resting = tick() + S.KenRest, true end
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
--@@UI@@
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
	T:Label(function() return ("Dodge mob here: %s (Sea 1 Monkey, Sea 2 Zombie, Sea 3 Marine Commodore). Auto Click pauses while dodging."):format(Ken.bestFor(Sea).name) end)
	T:Button("Clear Job", function()
		S.KenFarm = false
		Ken.clearJob()
		notify("Observation", "Job cleared", 3)
	end)
end
