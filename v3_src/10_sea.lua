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
	-- 5.10: طول کمبویی که مغز یاد گرفته (ضربه‌ی ۴ مکث میاره)
	local function fruitComboLen(fruit)
		local ok, n = pcall(function() return Hub.Brain.store.fruit[fruit.Name].combo end)
		n = ok and tonumber(n)
		return (n and n >= 1 and n <= 4) and math.floor(n) or 4
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
		fruitCombo = fruitCombo % fruitComboLen(fruit) + 1
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

--@@UI@@
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
