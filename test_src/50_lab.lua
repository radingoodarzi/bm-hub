---------------------------------------------------------------------
-- Lab · آزمایش A/B: تلپورت و اتو کلیک «Banana» در مقابل «BM»
-- هر دو موتور کنار هم هستن و با یک سوییچ عوض میشن؛ آمار هر ترکیب جدا ثبت میشه
-- موتور Banana نوشته‌ی خودمونه بر اساس رفتار Banana Cat: سقف سرعت تطبیقی و ماندگار، تشخیص رول‌بک سرور،
-- نوکلیپ هنگام حرکت، و بالا رفتن از موانع (raycast). تابع ClickM1 خود Banana بازیابی نشده؛ فقط روش هدف‌گیری و
-- جای ایستادنش (CombatUtil، 7 کنار / 20 بالا) پیاده شده.
---------------------------------------------------------------------
do
local okLab, errLab = pcall(function()
	for k, v in pairs({
		TweenEngine = "Banana", ClickEngine = "Banana", BananaClickMs = 100, BananaHitCount = 1, BananaLift = 70,
		BananaToolClick = false, ABMinutes = 3, ABRun = false,
	}) do
		if S[k] == nil then S[k] = v end
	end

	local Lab = { stats = {}, abLabel = "idle" }
	Hub.Lab = Lab

	local function key() return tostring(S.TweenEngine) .. "/" .. tostring(S.ClickEngine) end
	local function cur()
		local k = key()
		local s = Lab.stats[k]
		if not s then
			s = { sec = 0, kills = 0, killTime = 0, tweens = 0, tweenTime = 0, tweenDist = 0, tweenFail = 0, snaps = 0 }
			Lab.stats[k] = s
		end
		return s
	end
	function Hub.LabSnap() cur().snaps += 1 end

	-----------------------------------------------------------------
	-- موتور تلپورت Banana
	-----------------------------------------------------------------
	local CFG = { SpeedFloor = 60, SnapDrift = 45, ProbeEvery = 0.5, StallSeconds = 2.5, DescendDist = 250, Eps = 2.5 }
	local E = { char = nil, cap = 200, nextRaise = 0 }
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local function obstacleAhead(pos, aim, char)
		local d = aim - pos
		local len = math.min(d.Magnitude, 500)
		if len < 8 then return nil end
		local skip = { char }
		for _, name in ipairs({ "Enemies", "Boats", "SeaBeasts", "Characters" }) do
			local f = workspace:FindFirstChild(name)
			if f then table.insert(skip, f) end
		end
		if workspace.CurrentCamera then table.insert(skip, workspace.CurrentCamera) end
		rayParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(pos, d.Unit * len, rayParams)
		if hit and hit.Instance and (hit.Instance.CanCollide or hit.Instance:IsA("Terrain")) then return hit end
	end

	local function bananaTween(cf, keepGoing)
		local root = getRoot()
		if not root or not cf then return false end
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		if (root.Position - cf.Position).Magnitude > 1500 then
			pcall(portalHop, cf.Position, keepGoing)
			root = getRoot()
			if not root then return false end
		end
		local goal = cf.Position
		if (root.Position - goal).Magnitude <= 10 then
			root.CFrame = cf
			return true
		end
		stopTween()
		setFloat(true)
		local char = getChar()
		local speedMax = math.clamp(S.TweenSpeed, 50, MAX_SAFE_SPEED)
		-- سقف سرعت برای هر کاراکتر یادش می‌مونه؛ بعد از ریسپاون از 75٪ شروع و پله‌پله بالا میاد
		if E.char ~= char then
			E.char, E.cap, E.nextRaise = char, speedMax * 0.75, 0
		end
		E.cap = math.clamp(E.cap, CFG.SpeedFloor, speedMax)

		local cancelled = false
		local handle = { Cancel = function() cancelled = true end }
		activeTween = handle

		local parts = {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(parts, d) end
		end
		local noclip = RunService.Stepped:Connect(function()
			for _, p in ipairs(parts) do p.CanCollide = false end
		end)

		local t0 = tick()
		local maxTime = (root.Position - goal).Magnitude / CFG.SpeedFloor + 20
		local lift, replans, windowAt = nil, 0, tick()
		local expected = root.Position
		local driftN, driftSum = 0, 0
		local bestDist, bestAt = math.huge, tick()
		local nextProbe = 0

		local function pushback(why)
			E.cap = math.max(E.cap * 0.8, CFG.SpeedFloor)
			E.nextRaise = tick() + 2
			Hub.LabSnap()
			S.Status = ("Banana tween: %s - cap %d"):format(why, E.cap)
		end

		while not cancelled and tick() - t0 < maxTime do
			if (keepGoing and not keepGoing()) or not alive() or not Hub.Running then break end
			root = getRoot()
			if not root then break end
			local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
			local pos = root.Position

			-- رول‌بک سرور: جای واقعی با جایی که خودمون گذاشتیم فرق داره
			local off = (pos - expected).Magnitude
			if off >= CFG.SnapDrift then
				pushback("rollback")
				driftN, driftSum = 0, 0
			elseif off > 3 then
				driftN += 1
				driftSum += off
				if driftN >= 3 and driftSum >= 12 then
					pushback("drift")
					driftN, driftSum = 0, 0
				end
			else
				driftN, driftSum = 0, 0
			end

			local horiz = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude
			if lift and horiz <= CFG.DescendDist then lift = nil end
			local aim = goal
			if lift then
				aim = pos.Y < lift - 5 and Vector3.new(pos.X, lift, pos.Z) or Vector3.new(goal.X, lift, goal.Z)
			end

			-- هر نیم ثانیه جلو رو چک می‌کنیم؛ مانع بود از بالاش رد میشیم (حداکثر 6 بار برنامه‌ریزی توی هر 6 ثانیه)
			if tick() >= nextProbe then
				nextProbe = tick() + CFG.ProbeEvery
				if tick() - windowAt > 6 then replans, windowAt = 0, tick() end
				local hit = replans < 6 and obstacleAhead(pos, aim, char)
				if hit then
					local want = math.max(hit.Position.Y, pos.Y, goal.Y) + S.BananaLift
					if not lift or want > lift + 5 then
						lift = want
						replans += 1
					end
				end
			end

			-- پیشرفت: 2.5 ثانیه بدون نزدیک شدن = گیر کردیم؛ آروم‌تر و از بالا
			local dist = (goal - pos).Magnitude
			if dist < bestDist - 5 then
				bestDist, bestAt = dist, tick()
			elseif tick() - bestAt > CFG.StallSeconds then
				E.cap = math.max(E.cap * 0.75, CFG.SpeedFloor)
				E.nextRaise = tick() + 3
				lift = lift or (math.max(pos.Y, goal.Y) + S.BananaLift)
				bestDist, bestAt = dist, tick()
			end

			if tick() >= E.nextRaise and E.cap < speedMax then
				E.cap = math.min(E.cap * 1.08, speedMax)
				E.nextRaise = tick() + 1.5
			end

			local remaining = aim - pos
			local step = math.min(E.cap, speedMax) * dt
			local nextPos = remaining.Magnitude <= step and aim or pos + remaining.Unit * step
			root.CFrame = CFrame.new(nextPos) * root.CFrame.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			expected = nextPos
			if not lift and (nextPos - goal).Magnitude <= CFG.Eps then
				root.CFrame = cf
				break
			end
		end

		noclip:Disconnect()
		if activeTween == handle then activeTween = nil end
		local r = getRoot()
		return r ~= nil and (r.Position - cf.Position).Magnitude < 20
	end

	-----------------------------------------------------------------
	-- سوییچ تلپورت + ثبت آمار هر حرکت
	-----------------------------------------------------------------
	local bmTween = tweenTo
	tweenTo = function(cf, keepGoing, manual)
		local root = getRoot()
		local target = typeof(cf) == "CFrame" and cf.Position or (typeof(cf) == "Vector3" and cf or nil)
		local dist = root and target and (root.Position - target).Magnitude or 0
		local t0 = tick()
		local ok
		if S.TweenEngine == "Banana" then
			ok = bananaTween(cf, keepGoing)
		else
			ok = bmTween(cf, keepGoing, manual)
		end
		if dist > 60 then
			local s = cur()
			s.tweens += 1
			s.tweenDist += dist
			s.tweenTime += tick() - t0
			if not ok then s.tweenFail += 1 end
		end
		return ok
	end

	-----------------------------------------------------------------
	-- موتور اتو کلیک Banana: هدف‌گیری با خود CombatUtil بازی، جای ایستادن 7 کنار / 20 بالا
	-----------------------------------------------------------------
	local CombatUtil = safeRequire(Modules and Modules:FindFirstChild("CombatUtil"))
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	local lastShot = 0

	local function rigOf(part, enemies)
		if CombatUtil and CombatUtil.GetRigOfHitPart then
			local ok, rig = pcall(CombatUtil.GetRigOfHitPart, CombatUtil, part)
			if ok then return rig end
		end
		local m = part
		while m and m.Parent ~= enemies do m = m.Parent end
		return m
	end

	local function bananaAttack()
		local root = getRoot()
		local enemies = workspace:FindFirstChild("Enemies")
		if not root or not enemies or not (RegisterAttack and RegisterHit) then return end
		if tick() - lastShot < S.BananaClickMs / 1000 then return end
		lastShot = tick()
		overlap.FilterDescendantsInstances = { getChar() }
		local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, root.Position, S.AttackRange, overlap)
		if not ok then return end
		local best = {} -- rig -> { part, dist }
		for _, p in ipairs(parts) do
			if p:IsDescendantOf(enemies) then
				local rig = rigOf(p, enemies)
				if rig and rig.Parent == enemies then
					local vulnerable = true
					if CombatUtil and CombatUtil.IsVulnerable then
						local okV, v = pcall(CombatUtil.IsVulnerable, CombatUtil, rig)
						vulnerable = not okV or v
					end
					local h = rig:FindFirstChildOfClass("Humanoid")
					if vulnerable and h and h.Health > 0 then
						local d = (root.Position - p.Position).Magnitude
						if not best[rig] or d < best[rig].dist then best[rig] = { part = p, dist = d } end
					end
				end
			end
		end
		local list = {}
		for rig, b in pairs(best) do table.insert(list, { rig = rig, part = b.part, dist = b.dist }) end
		if #list == 0 then return end
		table.sort(list, function(a, b) return a.dist < b.dist end)
		local hits = {}
		for i = 1, math.min(#list, S.BananaHitCount) do hits[i] = { list[i].rig, list[i].part } end
		pcall(function()
			RegisterAttack:FireServer(0)
			RegisterHit:FireServer(hits[1][2], hits)
		end)
		if S.BananaToolClick then
			local tool = getChar() and getChar():FindFirstChildOfClass("Tool")
			if tool then pcall(function() tool:Activate() end) end
		end
	end

	local bmAttack = attack
	attack = function(...)
		if S.ClickEngine == "Banana" then return bananaAttack() end
		return bmAttack(...)
	end

	-- جای ایستادن روی ماب (killMob از این هوک استفاده می‌کنه): Banana = 7 کنار و 20 بالا نسبت به ماب
	function Hub.StandAt(hrp)
		if S.ClickEngine ~= "Banana" then return nil end
		local fruit = S.Weapon == "Blox Fruit"
		return (hrp.CFrame * CFrame.new(fruit and -7 or 7, 20, 0)).Position
	end

	-----------------------------------------------------------------
	-- شمارش کشته‌ها و زمان فارم برای هر ترکیب
	-----------------------------------------------------------------
	local bmKill = killMob
	killMob = function(mob, keepGoing)
		local hum = mob and mob:FindFirstChildOfClass("Humanoid")
		local t0 = tick()
		local ok, err = pcall(bmKill, mob, keepGoing)
		if hum and hum.Health <= 0 then
			local s = cur()
			s.kills += 1
			s.killTime += tick() - t0
		end
		if not ok then error(err, 0) end
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			if S.AutoFarm and alive() then cur().sec += 1 end
		end
	end)

	-----------------------------------------------------------------
	-- گزارش و تست خودکار A/B
	-----------------------------------------------------------------
	function Lab.report()
		local out = { "BM Hub A/B report  " .. os.date("%Y-%m-%d %H:%M:%S") .. "  sea " .. tostring(Sea) .. "  tweenSpeed " .. tostring(S.TweenSpeed) }
		table.insert(out, "combo(tp/click) | farm min | kills | kills/min | s/kill | tweens | studs/s | fail% | snaps")
		local keys = {}
		for k in pairs(Lab.stats) do table.insert(keys, k) end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local s = Lab.stats[k]
			local min = s.sec / 60
			table.insert(out, ("%-15s | %8.1f | %5d | %9.2f | %6.1f | %6d | %7.0f | %5.0f | %5d"):format(
				k, min, s.kills, min > 0 and s.kills / min or 0, s.kills > 0 and s.killTime / s.kills or 0,
				s.tweens, s.tweenTime > 0 and s.tweenDist / s.tweenTime or 0, s.tweens > 0 and s.tweenFail / s.tweens * 100 or 0, s.snaps))
		end
		return table.concat(out, "\n")
	end

	function Lab.save()
		local text = Lab.report()
		pcall(function()
			if makefolder and not (isfolder and isfolder("bmscan")) then makefolder("bmscan") end
			writefile("bmscan/ab_test.txt", text)
		end)
		pcall(function() (setclipboard or toclipboard)(text) end)
		print(text)
		return text
	end

	function Lab.line()
		local s = cur()
		local min = s.sec / 60
		return ("%s  •  %.1f min  •  %d kills  •  %.2f/min  •  snaps %d"):format(key(), min, s.kills, min > 0 and s.kills / min or 0, s.snaps)
	end

	local COMBOS = { { "BM", "BM" }, { "Banana", "BM" }, { "BM", "Banana" }, { "Banana", "Banana" } }
	task.spawn(function()
		while Hub.Running do
			task.wait(1)
			if S.ABRun then
				if not S.AutoFarm then
					if notifyHook then notifyHook("A/B test", "Turn Auto Farm on first", 5) end
					S.ABRun = false
				else
					local savedTp, savedClick = S.TweenEngine, S.ClickEngine
					for i, c in ipairs(COMBOS) do
						if not S.ABRun or not Hub.Running then break end
						S.TweenEngine, S.ClickEngine = c[1], c[2]
						Lab.abLabel = ("combo %d/%d: %s/%s"):format(i, #COMBOS, c[1], c[2])
						local endAt = tick() + S.ABMinutes * 60
						while S.ABRun and S.AutoFarm and Hub.Running and tick() < endAt do task.wait(1) end
						if not S.AutoFarm then break end
					end
					S.TweenEngine, S.ClickEngine = savedTp, savedClick
					Lab.abLabel = "idle"
					if S.ABRun then
						S.ABRun = false
						Lab.save()
						if notifyHook then notifyHook("A/B test", "Done - report saved + copied", 8) end
					end
				end
			end
		end
	end)
end)
if not okLab then logError("lab", errLab) end
end

--@@UI@@
do
	local T = createTab("A/B Lab", "⚗")
	T:Section("Engines (switch any time, even while farming)")
	T:Dropdown("Teleport Engine", function() return { "BM", "Banana" } end, "TweenEngine")
	T:Dropdown("Auto Click Engine", function() return { "BM", "Banana" } end, "ClickEngine")
	T:Label(function()
		return "Now: teleport = " .. tostring(S.TweenEngine) .. "  •  click = " .. tostring(S.ClickEngine)
			.. (S.ClickEngine == "Banana" and "  •  stands 7 side / 20 up" or "")
	end)
	T:Section("Banana tuning")
	T:Slider("Click Interval (ms)", 30, 300, "BananaClickMs")
	T:Slider("Targets Per Hit (1 = nearest only)", 1, 15, "BananaHitCount")
	T:Slider("Lift Over Obstacles (studs)", 20, 200, "BananaLift")
	T:Toggle("Banana Click Also Taps The Tool", "BananaToolClick")
	T:Label(function() return "Tween speed uses the Tween Speed slider in Combat (max 300)" end)
	T:Section("Live numbers (current combo)")
	T:Label(function() return Hub.Lab and Hub.Lab.line() or "" end)
	T:Button("Save + Copy Full Report", function()
		Hub.Lab.save()
		notify("A/B report", "Saved to bmscan/ab_test.txt and copied", 5)
	end)
	T:Button("Reset All Numbers", function()
		Hub.Lab.stats = {}
		notify("A/B", "Numbers reset", 3)
	end)
	T:Section("Automatic A/B farm test")
	T:Slider("Minutes Per Combo", 1, 10, "ABMinutes")
	T:Toggle("Run A/B Test (turn Auto Farm on first)", "ABRun")
	T:Label(function() return "Test: " .. tostring(Hub.Lab and Hub.Lab.abLabel or "idle") end)
	T:Label(function() return "Order: BM/BM → Banana/BM → BM/Banana → Banana/Banana. Stand in the same farm spot." end)
end
