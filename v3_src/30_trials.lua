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
	-- بلی/آیتم خرج می‌کنن؛ ذخیره نمیشن تا خودکار روشن نشن
	V3.register("AutoKenQuest", stepKenQuest, sea3, true)
	V3.register("AutoRainbowHaki", stepRainbow, sea3, true)
	V3.register("AutoGetGhoul", stepGhoul, function() return Sea == 2 end, true)
end)
if not okTr then logError("v3 trials", errTr) end
end

--@@UI@@
if Sea >= 2 then
	local T = createTab("Trials", "✦")
	if Sea == 3 then
		T:Section("Race V4 (Temple of Time)")
		T:Toggle("Auto Trial (go to the door, fight your race trial)", "AutoTrial", stopOff)
		T:Toggle("Press T At The Door (race ability)", "TrialPressT")
		T:Toggle("Auto Race V4 Quest (Begin / Teleport / Continue)", "AutoRaceV4", stopOff)
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
