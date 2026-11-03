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

	connect(RunService.Heartbeat, function(dt)
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end
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
