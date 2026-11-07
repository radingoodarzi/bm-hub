---------------------------------------------------------------------
-- v3 · Draco: ارتقای نژاد Draco به V2 و V3 از Dragon Wizard (منطق از Banana Cat)
-- V2 = 5 تا Fire Flower (گل‌ها رو جمع می‌کنه؛ گل نبود Forest Pirate می‌کشه)
-- V3 = کشتن یه Terrorshark (با موتور Sea Event). Trial Draco (V4) عمداً نیست: نصفش توی VM بنانا‌ست.
---------------------------------------------------------------------
do
local okDr, errDr = pcall(function()
	local V3 = Hub.V3
	local Draco = {}
	V3.Draco = Draco

	-- وضعیت‌هایی که سرور برمی‌گردونه (AvailableVQuest)
	local ACTIVE = { V2InProgress = true, V3InProgress = true, V2TurnInReady = true, V3TurnInReady = true }
	Draco.FLOWERS_NEEDED = 5

	-- تصمیم خالص (بدون بازی، برای تست): چی کار کنیم با این وضعیت
	-- ctx = { race, done, quest, flowers, sharkKills, sharkBase }
	function Draco.decide(ctx)
		if ctx.race ~= "Draco" then return "notDraco" end
		if ctx.done then return "done" end
		local q = ctx.quest
		if not q or not ACTIVE[q] then
			if q == "V2" or q == "V3" then return "begin" end
			return "speak"
		end
		if q == "V2TurnInReady" or q == "V3TurnInReady" then return "complete" end
		if q == "V2InProgress" then
			return (ctx.flowers or 0) >= Draco.FLOWERS_NEEDED and "complete" or "flowers"
		end
		-- V3InProgress
		return (ctx.sharkKills or 0) > (ctx.sharkBase or 0) and "complete" or "shark"
	end

	local function rf()
		return Net and Net:FindFirstChild("RF/InteractDragonQuest")
	end
	local function talk(args)
		local r = rf()
		if not r then return nil end
		local ok, res = pcall(function() return r:InvokeServer(args) end)
		if ok then return res end
	end

	local state = { quest = nil, flowers = 0, sharkBase = nil, unknown = 0, lastSpeak = 0, lastTry = 0 }
	Draco.state = state

	local function speak()
		local res = talk({ NPC = "Dragon Wizard", Command = "Speak" })
		state.lastSpeak = tick()
		state.quest = type(res) == "table" and res.AvailableVQuest or nil
		V3.log("DRACO speak -> " .. tostring(state.quest))
		return state.quest
	end

	local function wizard() return V3.npcPart and V3.npcPart("Dragon Wizard") end
	-- کنار NPC؟ نه = داره میره (true یعنی رسیدیم)
	local function atWizard(keep)
		local npc = wizard()
		if not npc then
			S.Status = "Draco: Dragon Wizard not found (go near Tiki Outpost / Hydra)"
			task.wait(3)
			return false
		end
		if (getRoot().Position - npc.Position).Magnitude > 8 then
			S.Status = "Draco: going to the Dragon Wizard"
			tweenTo(npc.CFrame * CFrame.new(0, 4, 4), keep)
			return false
		end
		return true
	end

	-- گل‌های آتش: هر ProximityPrompt که پدرش اسمش flower داره (اسم دقیق مدل تأیید نشده)
	local flowers = setmetatable({}, { __mode = "k" })
	local listener
	local function watchFlowers(on)
		if on and not listener then
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Parent and d.Parent.Name:lower():find("flower", 1, true) then flowers[d] = true end
			end
			listener = workspace.DescendantAdded:Connect(function(d)
				if d:IsA("ProximityPrompt") then
					task.defer(function()
						if d.Parent and d.Parent.Name:lower():find("flower", 1, true) then flowers[d] = true end
					end)
				end
			end)
		elseif not on and listener then
			listener:Disconnect()
			listener = nil
		end
	end
	local function nearestFlower()
		local root, best, bd = getRoot(), nil, nil
		for p in pairs(flowers) do
			local holder = p.Parent
			local part = holder and (holder:IsA("BasePart") and holder or holder.PrimaryPart or holder:FindFirstChildWhichIsA("BasePart", true))
			if part and p.Enabled then
				local d = (part.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = { prompt = p, part = part }, d end
			else
				flowers[p] = nil
			end
		end
		return best
	end

	local function pickFlower(f, keep)
		if (getRoot().Position - f.part.Position).Magnitude > 8 then
			S.Status = "Draco V2: going to a Fire Flower"
			tweenTo(f.part.CFrame, keep)
			return
		end
		S.Status = "Draco V2: picking a Fire Flower"
		V3.activate(f.prompt)
		task.wait(1)
		if not f.prompt.Parent or not f.prompt.Enabled then
			state.flowers += 1
			flowers[f.prompt] = nil
			V3.log("DRACO flower picked " .. state.flowers)
		end
	end

	local function stepDraco(keep)
		local action = Draco.decide({
			race = dataValue("Race"),
			done = hasItem("Primordial Reign"),
			quest = state.quest,
			flowers = state.flowers,
			sharkKills = V3.sharkKills,
			sharkBase = state.sharkBase,
		})
		watchFlowers(action == "flowers")
		if action == "notDraco" then
			V3.notify("Draco", "Your race isn't Draco (switch turned off)", 6)
			S.AutoDraco = false
		elseif action == "done" then
			V3.notify("Draco", "You already have Draco V3 (Primordial Reign) ✔", 6)
			S.AutoDraco = false
		elseif action == "speak" or action == "begin" then
			if not atWizard(keep) then return end
			if action == "begin" then
				S.Status = "Draco: starting the " .. state.quest .. " quest"
				talk({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Begin" })
				state.flowers, state.sharkBase = 0, nil
				task.wait(1)
			end
			local q = speak()
			if not q or (not ACTIVE[q] and q ~= "V2" and q ~= "V3") then
				state.unknown += 1
				S.Status = "Draco: Wizard says " .. tostring(q)
				if state.unknown >= 3 then
					V3.notify("Draco", "Nothing to do now (Wizard: " .. tostring(q) .. "). Switch turned off", 8)
					S.AutoDraco = false
					state.unknown = 0
				end
				task.wait(3)
			else
				state.unknown = 0
			end
		elseif action == "complete" then
			if not atWizard(keep) then return end
			S.Status = "Draco: turning in"
			talk({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
			task.wait(1)
			local before = state.quest
			speak()
			V3.log("DRACO complete " .. tostring(before) .. " -> " .. tostring(state.quest))
			if state.quest == before then
				-- هنوز کافی نیست (مثلاً گلی که شمردیم واقعاً نرفته بود توی کیف)
				state.flowers = math.max(0, Draco.FLOWERS_NEEDED - 1)
				if before == "V3InProgress" then state.sharkBase = V3.sharkKills or 0 end
			else
				V3.notify("Draco", tostring(before) .. " done ✔", 6)
				V3.webhook("Draco", tostring(before) .. " done")
				state.flowers, state.sharkBase = 0, nil
				if before == "V3InProgress" or before == "V3TurnInReady" then
					V3.notify("Draco", "Draco V3 finished ✔ (switch turned off)", 8)
					S.AutoDraco = false
				end
			end
		elseif action == "flowers" then
			local f = nearestFlower()
			if f then return pickFlower(f, keep) end
			S.Status = ("Draco V2: Forest Pirates for Fire Flowers (%d/%d)"):format(state.flowers, Draco.FLOWERS_NEEDED)
			if not (V3.farmMobs and V3.farmMobs({ "Forest Pirate" }, keep)) then
				S.Status = "Draco V2: Forest Pirates not found"
				task.wait(3)
			end
			-- هر 3 دقیقه یه بار از سرور می‌پرسیم شاید تموم شده (شمارش گل‌ها از بیرون قابل‌خوندن نیست)
			if tick() - state.lastSpeak > 180 then state.flowers = Draco.FLOWERS_NEEDED end
		elseif action == "shark" then
			if state.sharkBase == nil then state.sharkBase = V3.sharkKills or 0 end
			if not V3.sharkStep then
				S.Status = "Draco V3: Sea module not loaded"
				task.wait(3)
				return
			end
			V3.sharkStep(keep)
			if S.Status:find("^Sea Event") then S.Status = "Draco V3 · " .. S.Status end
		end
	end

	V3.register("AutoDraco", function(keep)
		local ok, err = pcall(stepDraco, keep)
		if not ok then
			watchFlowers(false)
			error(err, 0)
		end
	end, function() return Sea == 3 end, true)

	-- وقتی خاموش شد شنونده‌ی گل‌ها رو قطع کن
	task.spawn(function()
		while Hub.Running do
			task.wait(2)
			if not S.AutoDraco then watchFlowers(false) end
		end
		watchFlowers(false)
	end)
end)
if not okDr then logError("v3 draco", errDr) end
end

--@@UI@@
if Sea == 3 then
	local T = createTab("Quests", "≋")
	T:Section("Draco Race (Dragon Wizard)")
	T:Toggle("Auto Draco V2 → V3 (Fire Flowers, then a Terrorshark)", "AutoDraco", stopOff)
	T:Label(function()
		local D = Hub.V3.Draco
		if not D then return "" end
		return ("Race: %s  •  Wizard: %s  •  Flowers: %d/%d  •  Sharks killed: %d"):format(
			tostring(dataValue("Race") or "?"), tostring(D.state.quest or "?"), D.state.flowers, D.FLOWERS_NEEDED, Hub.V3.sharkKills or 0)
	end)
end
