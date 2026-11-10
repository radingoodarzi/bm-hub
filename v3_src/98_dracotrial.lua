---------------------------------------------------------------------
-- v3 · Draco Trial (Race V4, Trial of Flames)
-- مسیر از Banana (Fully Trial Draco، بخش خوانا):
--   1) جزیره‌ی Prehistoric: ایونت (Golem، صخره‌ی گدازه) تا TrialRock شفاف بشه (Transparency 1)
--   2) TrialTeleport → Trial of Flames (Map.DracoTrial)
--   3) تایمر RaidTimer نیست: Remotes.DracoTrial:InvokeServer() شروعش می‌کنه
--   4) توی تریال: هر RelicModelN رو از RelicN برمی‌داری (پرامپت) و توی EndRelicN می‌ذاری (پرامپت)
--   5) DoorTouch پرامپت TouchInterest گرفت = تموم شد، از در بیرون
-- سه تابع Banana (وضعیت Ancient One، پیدا کردن مدل، کدوم رلیک دستته) توی بخش قفل‌شده بود؛
-- اینجا از نشونه‌های خود بازی ساخته شدن (پرامپت روشن، فاصله‌ی رلیک تا جاش) و ساختار تریال
-- هر بار توی bmscan/draco_trial.txt ثبت میشه تا اگه چیزی فرق داشت از روی واقعیت درست بشه
---------------------------------------------------------------------
do
local okDT, errDT = pcall(function()
	local V3 = Hub.V3
	local DT = { state = { carrying = nil, placed = 0, started = 0, done = false } }
	V3.DracoTrial = DT

	-----------------------------------------------------------------
	-- خالص (برای تست)
	-----------------------------------------------------------------
	-- شماره‌ی رلیک از اسم: "RelicModel3" / "Relic3" / "EndRelic3" → 3
	function DT.index(name)
		return tonumber(tostring(name):match("(%d+)$"))
	end

	-- تصمیم توی تریال. relics: لیست { i, placed, pickOn, placeOn } ؛ carrying: شماره‌ای که برداشتیم
	-- خروجی: "place", i | "pick", i | "wait"
	function DT.next(relics, carrying)
		-- چیزی دستمونه: اول بذاریمش
		for _, r in ipairs(relics) do
			if not r.placed and (r.placeOn or r.i == carrying) then return "place", r.i end
		end
		for _, r in ipairs(relics) do
			if not r.placed and r.pickOn then return "pick", r.i end
		end
		-- پرامپت‌ها خاموش ولی هنوز سر جاش نیست: بریم برش داریم (شاید پرامپت همیشه خاموش نشون داده بشه)
		for _, r in ipairs(relics) do
			if not r.placed then return "pick", r.i end
		end
		return "wait"
	end

	-----------------------------------------------------------------
	-- بازی
	-----------------------------------------------------------------
	local function timerVisible(name)
		local ok, vis = pcall(function() return player.PlayerGui.Main.TopHUDList[name].Visible end)
		return ok and vis == true
	end
	local function location(name)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local l = wo and wo:FindFirstChild("Locations")
		return l and l:FindFirstChild(name)
	end
	local function trialMap()
		local m = workspace:FindFirstChild("Map")
		return m and m:FindFirstChild("DracoTrial")
	end
	local function inTrialArea()
		local loc, root = location("Trial of Flames"), getRoot()
		if loc and root then return (root.Position - loc.Position).Magnitude <= 3000 end
		local tm = trialMap()
		return tm ~= nil and root ~= nil and (root.Position - tm:GetPivot().Position).Magnitude <= 3000
	end

	-- مدلی که رلیک‌ها توشن: هر چیزی که بچه‌ی "EndRelic1" داره (اول توی Map.DracoTrial)
	function DT.model()
		local tm = trialMap()
		if tm then
			if tm:FindFirstChild("EndRelic1") then return tm end
			for _, d in ipairs(tm:GetDescendants()) do
				if d.Name == "EndRelic1" then return d.Parent end
			end
		end
		return nil
	end

	local function promptOf(obj)
		return obj and obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	local function pivot(obj)
		local ok, cf = pcall(function() return obj:GetPivot() end)
		if ok then return cf end
		return obj:IsA("BasePart") and obj.CFrame or nil
	end

	function DT.relics(model)
		local out = {}
		for _, c in ipairs(model:GetChildren()) do
			local i = c.Name:match("^RelicModel(%d+)$")
			i = tonumber(i)
			if i then
				local pick, place = model:FindFirstChild("Relic" .. i), model:FindFirstChild("EndRelic" .. i)
				local rp, ep = pivot(c), place and pivot(place)
				local pp, ppl = promptOf(pick), promptOf(place)
				table.insert(out, {
					i = i, model = c, pick = pick, place = place,
					placed = rp ~= nil and ep ~= nil and (rp.Position - ep.Position).Magnitude < 6,
					pickOn = pp ~= nil and pp.Enabled, placeOn = ppl ~= nil and ppl.Enabled,
					pickPrompt = pp, placePrompt = ppl,
				})
			end
		end
		table.sort(out, function(a, b) return a.i < b.i end)
		return out
	end

	-- ساختار تریال برای عیب‌یابی (هر 20 ثانیه حداکثر یه بار)
	local dumpedAt = 0
	function DT.dump(model)
		if tick() - dumpedAt < 20 then return end
		dumpedAt = tick()
		local lines = { os.date("%H:%M:%S") .. "  Draco trial  timer=" .. tostring(timerVisible("RaidTimer")) .. "  carrying=" .. tostring(DT.state.carrying) }
		local root = getRoot()
		local function add(o, depth)
			if depth > 4 or #lines > 400 then return end
			local extra = ""
			local cf = pivot(o)
			if cf and root then extra = (" pos(%d,%d,%d) d=%d"):format(cf.X, cf.Y, cf.Z, (cf.Position - root.Position).Magnitude) end
			if o:IsA("ProximityPrompt") then extra ..= " enabled=" .. tostring(o.Enabled) .. " text=" .. tostring(o.ActionText) end
			if o:IsA("BasePart") then extra ..= " transp=" .. tostring(o.Transparency) end
			for k, v in pairs(o:GetAttributes()) do extra ..= (" @%s=%s"):format(k, tostring(v)) end
			table.insert(lines, string.rep("  ", depth) .. o.Name .. " [" .. o.ClassName .. "]" .. extra)
			for _, c in ipairs(o:GetChildren()) do add(c, depth + 1) end
		end
		local tm = trialMap()
		if tm then add(tm, 0) else table.insert(lines, "Map.DracoTrial not found") end
		pcall(function() writefile("bmscan/draco_trial.txt", table.concat(lines, "\n")) end)
	end

	local function goNear(obj, keep)
		local cf = pivot(obj)
		if not cf then return false end
		local root = getRoot()
		if (root.Position - cf.Position).Magnitude > 6 then
			tweenTo(cf * CFrame.new(0, 3, 0), keep)
		end
		return (getRoot().Position - cf.Position).Magnitude <= 10
	end

	local function trialRock(isl)
		return isl and isl:FindFirstChild("TrialRock", true)
	end

	local function finish(msg)
		S.AutoDracoTrial = false
		DT.state.done = true
		S.Status = "Draco Trial: " .. msg
		V3.notify("Draco Trial", msg, 10)
		V3.webhook("Draco Trial", msg)
	end

	local function stepTrial(keep)
		local tm = trialMap()
		local doorM = tm and tm:FindFirstChild("TrialDoor")
		local door = doorM and doorM:FindFirstChild("DoorTouch")
		-- در باز شد = تریال تموم شد؛ از در رد شو
		if door and door:FindFirstChild("TouchInterest") then
			S.Status = "Draco Trial: done, leaving through the door"
			tweenTo(door.CFrame, keep)
			task.wait(2)
			if DT.state.placed > 0 or DT.state.started > 0 then
				finish("Trial finished ✔ (buy your gear at the Ancient One / Dragon Wizard)")
			end
			return
		end
		if not timerVisible("RaidTimer") then
			-- هنوز شروع نشده
			if DT.state.started >= 3 and tick() - (DT.state.startedAt or 0) > 60 then
				return finish("Trial didn't start: is your Draco race V3 and trained? (switch turned off)")
			end
			S.Status = "Draco Trial: starting the trial"
			local ok, res = pcall(function() return ReplicatedStorage.Remotes.DracoTrial:InvokeServer() end)
			DT.state.started += 1
			DT.state.startedAt = DT.state.startedAt or tick()
			if not ok then V3.log("DRACO TRIAL start error: " .. tostring(res)) end
			task.wait(3)
			return
		end
		DT.state.startedAt = nil
		local model = DT.model()
		DT.dump(model)
		if not model then
			S.Status = "Draco Trial: waiting for the relics to load"
			return task.wait(1)
		end
		local relics = DT.relics(model)
		DT.state.placed = 0
		for _, r in ipairs(relics) do if r.placed then DT.state.placed += 1 end end
		local act, i = DT.next(relics, DT.state.carrying)
		local r
		for _, x in ipairs(relics) do if x.i == i then r = x end end
		if act == "place" and r then
			S.Status = ("Draco Trial: placing relic %d (%d/%d placed)"):format(i, DT.state.placed, #relics)
			if goNear(r.place, keep) then
				task.wait(0.5)
				V3.activate(r.placePrompt or promptOf(r.place))
				task.wait(1.5)
				local again = DT.relics(model)
				for _, x in ipairs(again) do
					if x.i == i and x.placed then DT.state.carrying = nil end
				end
			end
		elseif act == "pick" and r then
			S.Status = ("Draco Trial: picking up relic %d (%d/%d placed)"):format(i, DT.state.placed, #relics)
			if goNear(r.pick or r.model, keep) then
				task.wait(0.5)
				V3.activate(r.pickPrompt or promptOf(r.pick) or promptOf(r.model))
				DT.state.carrying = i
				task.wait(1.5)
			end
		else
			S.Status = ("Draco Trial: all %d relics placed, waiting for the door"):format(#relics)
			task.wait(1)
		end
	end

	local function stepDracoTrial(keep)
		if Sea ~= 3 then
			S.AutoDracoTrial = false
			return V3.notify("Draco Trial", "Only in Sea 3", 5)
		end
		if dataValue("Race") ~= "Draco" then
			S.AutoDracoTrial = false
			return V3.notify("Draco Trial", "Your race is not Draco", 6)
		end
		Hub.HoldAttackUntil = 0
		if inTrialArea() then return stepTrial(keep) end
		DT.state.carrying = nil
		local isl = V3.prehistoricIsland and V3.prehistoricIsland()
		local rock = trialRock(isl)
		if isl and rock and rock.Transparency >= 1 then
			local tp = isl:FindFirstChild("TrialTeleport", true)
			if tp then
				S.Status = "Draco Trial: Trial Rock is open, going in"
				tweenTo(tp.CFrame, keep)
				task.wait(2)
				return
			end
		end
		-- جزیره نیست یا صخره هنوز بازه نشده: ایونت Prehistoric (Magnet، پیدا کردن جزیره، Golem، گدازه)
		if V3.stepVolcano then
			V3.stepVolcano(keep)
			if isl and rock then S.Status = S.Status .. " • trial rock not open yet" end
		else
			S.Status = "Draco Trial: Prehistoric module missing"
			task.wait(2)
		end
	end
	V3.register("AutoDracoTrial", stepDracoTrial, function() return Sea == 3 end, true)
	V3.stepDracoTrial = stepDracoTrial
	DT.ready = true
end)
if not okDT then logError("v3 Draco Trial", errDT) end
end
--@@UI@@
if Sea == 3 and Hub.V3.DracoTrial and Hub.V3.DracoTrial.ready then
	local DT = Hub.V3.DracoTrial
	local T = createTab("Quests", "≋")
	T:Section("Draco Trial (Race V4 • Trial of Flames)")
	T:Toggle("Auto Draco Trial (Prehistoric → Trial Rock → relics → door)", "AutoDracoTrial", stopOff)
	T:Label(function()
		return ("Race: %s  •  relics placed: %d  •  %s"):format(tostring(dataValue("Race") or "?"), DT.state.placed, DT.state.done and "finished ✔" or "not done yet")
	end)
	T:Label(function() return "Uses the Volcano settings (Magnet, Golem weapon). Needs Draco V3 and a trained race." end)
end
