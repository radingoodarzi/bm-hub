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
	}) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.AutoBuyBoat = true -- پول خرج می‌کنه؛ هر بار باید دستی روشن بشه

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
		local speed = math.clamp(S.BoatSpeed, 50, 300)
		local reached, lastNoclip = false, tick()
		while keep() and Hub.Running and boat.Parent and seat.Parent and alive() do
			if not seatedOn(boat) then break end
			if stop and stop() then break end
			local dt = math.min(task.wait(), 0.1)
			local p = seat.Position
			local flat = Vector3.new(goal.X - p.X, 0, goal.Z - p.Z)
			local step = speed * dt
			if flat.Magnitude <= step + 3 then
				reached = true
				break
			end
			local np = Vector3.new(p.X, y, p.Z) + flat.Unit * step
			seat.CFrame = CFrame.new(np) * seat.CFrame.Rotation
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
		local far = boat == nil or (root.Position - boat.VehicleSeat.Position).Magnitude >= 4000
		if far then
			if not S.AutoBuyBoat then
				S.Status = "Boat: no boat nearby (turn on Auto Buy Boat)"
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
	-- Sea Event: هیولاهای دریا (SeaBeast، Terrorshark) و قایق‌های دشمن
	-----------------------------------------------------------------
	local function aliveSea(o)
		if not o or not o.Parent then return false end
		local hv = o:FindFirstChild("Health")
		if hv and hv:IsA("ValueBase") then return hv.Value > 0 end
		local h = o:FindFirstChildWhichIsA("Humanoid")
		return h ~= nil and h.Health > 0
	end

	local function seaTargets()
		local out, root = {}, getRoot()
		if not root then return out end
		local function add(o, kind)
			local part = o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Engine") or o.PrimaryPart
			if part and aliveSea(o) then
				table.insert(out, { obj = o, part = part, kind = kind, d = (part.Position - root.Position).Magnitude })
			end
		end
		local sb = workspace:FindFirstChild("SeaBeasts")
		if sb then
			for _, o in ipairs(sb:GetChildren()) do add(o, o.Name) end
		end
		local ts = findMobAnywhere("Terrorshark")
		if ts then add(ts, "Terrorshark") end
		local boats = workspace:FindFirstChild("Boats")
		if boats then
			for _, b in ipairs(boats:GetChildren()) do
				local owner = b:FindFirstChild("Owner")
				-- قایق بازیکن‌ها رو نمی‌زنیم؛ فقط قایق‌های دشمن (Engine + Health و بدون صاحب بازیکن)
				if b:IsA("Model") and b:FindFirstChild("Engine") and b:FindFirstChild("Health")
					and not (owner and Players:FindFirstChild(tostring(owner.Value))) then
					add(b, b.Name)
				end
			end
		end
		table.sort(out, function(a, b) return a.d < b.d end)
		return out
	end
	V3.seaTargets = seaTargets

	local function attackSea(t)
		local w = S.SeaWeapon
		if w == "Dragonstorm" or w == "Skull Guitar" then
			if not backpackTool(w) then
				invoke("LoadItem", w)
				task.wait(0.4)
			end
			V3.equip(w)
		else
			equipWeapon(w)
		end
		V3.aimClick(t.part.Position)
		local savedSkills = S.UseSkills
		S.UseSkills = true
		useSkills()
		S.UseSkills = savedSkills
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

	local seenKinds = {}
	local function stepSeaEvent(keep)
		local list = seaTargets()
		local root = getRoot()
		if #list == 0 then
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
					sail(boat, spot, keep)
					return
				end
			end
			S.Status = "Sea Event: waiting for an event"
			task.wait(1)
			return
		end
		local t = list[1]
		if not seenKinds[t.obj] then
			seenKinds[t.obj] = true
			V3.webhook("Sea Event: " .. t.kind, "Fighting it now")
		end
		S.Status = "Sea Event: " .. t.kind
		local pos = t.part.Position
		local stand = CFrame.new(pos + Vector3.new(0, S.SeaHover, 0))
		if (root.Position - stand.Position).Magnitude > 90 then
			tweenTo(stand, keep)
		else
			setFloat(true)
			root.CFrame = CFrame.lookAt(stand.Position, pos)
		end
		attackSea(t)
		task.wait(0.15)
	end

	local sea3 = function() return Sea == 3 end
	local findPrehistoric = stepFind("AutoFindPrehistoric", "Prehistoric Island", "EventBoat", prehistoricUp)
	V3.findPrehistoric = findPrehistoric -- ماژول Volcano وقتی جزیره نیست ازش برای گشت استفاده می‌کنه
	V3.register("AutoFireHeart", stepHeart, sea3)
	V3.register("AutoSeaEvent", stepSeaEvent, function() return Sea == 2 or Sea == 3 end)
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
	T:Slider("Boat Speed (150 safe, higher = risk)", 50, 300, "BoatSpeed")
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
	T:Dropdown("Event Boat", function() return { "PirateBrigade", "PirateGrandBrigade", "Beast Hunter" } end, "EventBoat")
	T:Dropdown("Weapon", function() return { "Blox Fruit", "Sword", "Gun", "Melee", "Dragonstorm", "Skull Guitar" } end, "SeaWeapon")
	T:Slider("Hover Height Above Target", 20, 120, "SeaHover")
	T:Toggle("Auto Sea Event (sea beasts, Terrorshark, enemy boats)", "AutoSeaEvent", stopOff)
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
		return "Targets now: " .. (#list > 0 and (list[1].kind .. " (" .. #list .. ")") or "none")
	end)
end
