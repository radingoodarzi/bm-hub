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
		else
			-- نوع «trees» و بقیه فعلاً خودکار نیست؛ کوئست رو دوباره می‌گیریم
			S.Status = "Dragon Hunter: unsupported quest, re-requesting"
			questText = nil
			task.wait(3)
		end
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
				local savedSkills = S.UseSkills
				S.UseSkills = true
				useSkills()
				S.UseSkills = savedSkills
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
end)
if not okVol then logError("v3 volcano", errVol) end
end

--@@UI@@
if Sea == 3 then
	local T = createTab("Volcano", "▲")
	T:Section("Prehistoric Island (full event)")
	T:Toggle("Auto Prehistoric Event (craft magnet → find → run event)", "AutoVolcano", stopOff)
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
	T:Toggle("Auto Quest Dragon Hunter (Blaze Ember only)", "AutoDragonHunter", stopOff)
	T:Label(function()
		local V = Hub.V3
		if not V.volcanoCount then return "" end
		return ("Scrap Metal %d/10  •  Blaze Ember %d/15  •  Magnet: %s"):format(
			V.volcanoCount("Scrap Metal"), V.volcanoCount("Blaze Ember"), (hasItem("Volcanic Magnet") and "✔" or "✖"))
	end)
end
