---------------------------------------------------------------------
-- v3 · Move: سرعت و پرش واقعی
-- بازی WalkSpeed / JumpPower رو هر لحظه برمی‌گردونه؛ پس عدد Humanoid تنها کافی نیست.
-- سرعت: سرعت واقعی کاراکتر اندازه گرفته میشه و هر چقدر کمتر از عدد تو بود، همون‌قدر به حرکت اضافه میشه.
-- پرش: لحظه‌ی پرش سرعت عمودی مستقیم تنظیم میشه (ارتفاع ≈ JumpPower² / 392)
---------------------------------------------------------------------
do
local okMove, errMove = pcall(function()
	local Move = { speed = 0 }
	Hub.Move = Move

	-- چقدر باید اضافه کنیم (تابع خالص): هدف منهای سرعت واقعی، فقط وقتی کاربر داره راه میره
	function Move.extra(target, measured, moving)
		if not moving then return 0 end
		return math.max(0, target - measured)
	end

	if S.BoatDrive == nil then S.BoatDrive = true end

	-- سرعت قایق وقتی خودت می‌رونی (تابع خالص): جهت جلوی صندلی × سرعت، سرعت عمودی دست نمی‌خوره.
	-- اگه قایق خودش تندتر از عدد تو میره کم نمیشه
	function Move.boatVelocity(look, vel, throttle, speed)
		if not throttle or throttle == 0 then return nil end
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.01 then return nil end
		local cur = Vector3.new(vel.X, 0, vel.Z).Magnitude
		if cur >= speed - 1 then return nil end
		local dir = flat.Unit * (throttle > 0 and 1 or -1)
		return Vector3.new(dir.X * speed, vel.Y, dir.Z * speed)
	end

	local function driveBoat(seat)
		-- خود هاب داره قایق رو می‌بره (سی ایونت، پیدا کردن جزیره): دخالت نکن
		if not S.BoatDrive or activeTween or (Hub.V3Busy and Hub.V3Busy()) then return end
		local thr = seat.ThrottleFloat
		if thr == 0 then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then thr = 1
			elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then thr = -1 end
		end
		local v = Move.boatVelocity(seat.CFrame.LookVector, seat.AssemblyLinearVelocity, thr, math.clamp(S.BoatSpeed or 150, 50, 400))
		if v then seat.AssemblyLinearVelocity = v end
	end

	connect(RunService.Heartbeat, function(dt)
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end
		local seat = hum.SeatPart
		if seat and seat:IsA("VehicleSeat") then pcall(driveBoat, seat) end
		local v = root.AssemblyLinearVelocity
		Move.speed = Vector3.new(v.X, 0, v.Z).Magnitude
		-- موقع پرواز خود هاب، نشستن روی قایق یا فارم کاری نداریم
		if not S.SpeedOn or hum.SeatPart or activeTween or anyFarm() then return end
		local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		local add = Move.extra(S.WalkSpeed, Move.speed, dir.Magnitude > 0.1)
		if add > 0 then
			root.CFrame = root.CFrame + dir.Unit * add * math.min(dt, 0.1)
		end
	end)

	-- لحظه‌ی پرش: فقط روی زمین (یا با Infinite Jump)
	function Move.jump()
		if not S.JumpOn then return false end
		local root, hum = getRoot(), getHum()
		if not root or not hum or hum.SeatPart then return false end
		if hum.FloorMaterial == Enum.Material.Air and not S.InfJump then return false end
		task.defer(function()
			local r = getRoot()
			if not r then return end
			local vel = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = Vector3.new(vel.X, S.JumpPower, vel.Z)
		end)
		return true
	end
	connect(UserInputService.JumpRequest, Move.jump)

	function Move.jumpHeight() return math.floor(S.JumpPower ^ 2 / (2 * workspace.Gravity)) end
end)
if not okMove then logError("v3 move", errMove) end
end
--@@UI@@
if Hub.Move and Hub.Move.boatVelocity then
	local T = createTab("Combat", "⚔")
	T:Section("Boat Driving")
	T:Toggle("Fast Boat When You Drive (W / S)", "BoatDrive")
	T:Slider("Boat Speed (150 safe, 250+ may get pulled back)", 50, 400, "BoatSpeed")
	T:Label(function() return "Also used by the hub's own sailing. Walk speed is in Speed & Jump above." end)
end
