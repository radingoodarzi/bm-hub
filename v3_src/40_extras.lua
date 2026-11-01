---------------------------------------------------------------------
-- v3 · Extras: وبهوک دیسکورد + اعلان رویدادها، Kitsune Island، Azure Ember
-- ماهی‌گیری و آپگرید اینونتوری Banana Cat به UI خود بازی وابسته‌ان و پورت نشدن
---------------------------------------------------------------------
do
local okEx, errEx = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ AutoKitsunePray = false, AzureEmberNeed = 1 }) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.AutoKitsunePray = true -- Azure Ember مصرف می‌کنه

	-- هر چیز جدیدی که توی سرور ظاهر بشه (رویدادها، ماه کامل، Sea Beast) یک بار به دیسکورد میره
	task.spawn(function()
		local seen, first = {}, true
		while Hub.Running do
			pcall(function()
				local now = {}
				for _, obj in pairs(Hub.Events or {}) do now[obj.Name] = true end
				if Hub.FullMoonNight and Hub.FullMoonNight() then now["Full Moon Night"] = true end
				if V3.leviathanUp and V3.leviathanUp() then now["Frozen Dimension (Leviathan)"] = true end
				local sb = workspace:FindFirstChild("SeaBeasts")
				if sb and #sb:GetChildren() > 0 then now["Sea Beast"] = true end
				for label in pairs(now) do
					if not seen[label] and not first then V3.webhook("World Event", label .. " is in this server") end
				end
				seen, first = now, false
			end)
			task.wait(5)
		end
	end)

	-----------------------------------------------------------------
	-- Kitsune Island: شب ماه کامل با قایق میری نقطه‌ی مشخص و منتظر می‌مونی
	-----------------------------------------------------------------
	local SPOT = Vector3.new(-32975.99, 0, 25963.71 + 1000)
	local function kitsuneUp() return Hub.Events ~= nil and Hub.Events.kitsune ~= nil end

	local function stepKitsune(keep)
		if V3.newMap and not V3.newMap() then
			V3.notify("Kitsune Island", "Needs the new Sea 3 map (Tiki Outpost)", 6)
			S.AutoKitsuneSpawn = false
			return
		end
		if kitsuneUp() then
			V3.notify("Kitsune Island", "Spawned! (switch turned off)", 8)
			V3.webhook("Kitsune Island", "Spawned in this server")
			S.AutoKitsuneSpawn = false
			return
		end
		if not (Hub.FullMoonNight and Hub.FullMoonNight()) then
			S.Status = "Kitsune: waiting for a full moon night"
			task.wait(2)
			return
		end
		local t = Lighting.ClockTime
		local nightNow = t >= 18 or t < 5
		local b = V3.myBoat and V3.myBoat()
		local nearSpot = b ~= nil and V3.flatDist(b.VehicleSeat.Position, SPOT) <= 200
		if nearSpot and not nightNow then
			-- قبل از ساعت 18: بالای نقطه توی آسمون منتظر می‌مونیم (از هیولاهای دریا دوریم)
			S.Status = "Kitsune: waiting in the sky for 18:00"
			tweenTo(CFrame.new(SPOT + Vector3.new(0, 2000, 0)), keep)
			task.wait(1)
			return
		end
		local boat = V3.ensureBoat(S.EventBoat, keep)
		if not boat then return end
		if V3.flatDist(boat.VehicleSeat.Position, SPOT) > 200 then
			S.Status = "Kitsune: sailing to the spawn spot"
			V3.sail(boat, SPOT, keep, kitsuneUp)
		else
			S.Status = "Kitsune: waiting at the spot"
			task.wait(1)
		end
	end
	V3.register("AutoKitsuneSpawn", stepKitsune, function() return Sea == 3 end)

	-- Pray کردن کنار مجسمه وقتی Trial فعاله و Azure Ember کافی داری
	task.spawn(function()
		while Hub.Running do
			task.wait(5)
			if S.AutoKitsunePray and alive() and V3.raidTimer and V3.raidTimer()
				and (materialCount("Azure Ember") or 0) >= S.AzureEmberNeed then
				local rf = Net and Net:FindFirstChild("RF/KitsuneStatuePray")
				if rf then
					pcall(function() rf:InvokeServer() end)
					task.wait(5)
				end
			end
		end
	end)
end)
if not okEx then logError("v3 extras", errEx) end
end

--@@UI@@
if Sea == 3 then
	local T = createTab("Sea", "⚓")
	T:Section("Kitsune Island")
	T:Dropdown("Boat", function() return { "PirateBrigade", "PirateGrandBrigade", "Beast Hunter" } end, "EventBoat")
	T:Toggle("Auto Spawn Kitsune Island (full moon night)", "AutoKitsuneSpawn", stopOff)
	T:Toggle("Auto Pray At Kitsune Statue (needs Azure Ember)", "AutoKitsunePray")
	T:Slider("Azure Ember Needed", 1, 20, "AzureEmberNeed")
	T:Label(function()
		return "Kitsune Island: " .. (Hub.Events and Hub.Events.kitsune and "SPAWNED ✔" or "no") .. "  •  Azure Ember: " .. tostring(materialCount("Azure Ember") or 0)
	end)
end

--@@UI-LATE@@
do
	local T = createTab("Settings", "✦")
	T:Section("Discord Webhook")
	T:Input("Paste your Discord webhook URL, press Enter", function(text)
		S.WebhookUrl = (text:gsub("%s+", ""))
		notify("Webhook", "URL saved", 3)
	end)
	T:Toggle("Send Alerts To Discord (events, Leviathan, Prehistoric, finds)", "WebhookOn")
	T:Button("Send Test Message", function()
		if S.WebhookUrl == "" then return notify("Webhook", "Paste the URL first") end
		Hub.V3.webhook("BM Hub", "Test message ✔ — " .. player.Name)
		notify("Webhook", "Test sent (if nothing arrives, check the URL)", 4)
	end)
	T:Label(function() return "Webhook: " .. (S.WebhookUrl ~= "" and "saved ✔" or "not set") end)
end
