---------------------------------------------------------------------
-- v3 · Core: وبهوک، ابزارهای مشترک و یک صف مرکزی برای کارهای جدید
-- هر کار فقط یک «قدم» می‌نویسه؛ لوپ مرکزی اولین کار روشن رو اجرا می‌کنه تا سر حرکت دعوا نشه
---------------------------------------------------------------------
do
local okCore, errCore = pcall(function()
	if S.WebhookUrl == nil then S.WebhookUrl = "" end
	if S.WebhookOn == nil then S.WebhookOn = false end

	local V3 = { aiming = false, seen = {} }
	Hub.V3 = V3
	Hub.V3Tasks = {}
	Hub.V3SkipSave = {} -- گزینه‌هایی که پول/آیتم خرج می‌کنن و نباید خودکار روشن بشن

	local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

	function V3.log(msg)
		if Hub.LiveLog then pcall(Hub.LiveLog, msg) end
	end

	function V3.notify(title, text, dur)
		if notifyHook then notifyHook(title, text, dur or 5) end
	end

	-- پیام دیسکورد (وبهوک خود کاربر)؛ Job ID هم میره تا از v2 با Join Job ID وصل بشی
	function V3.webhook(title, desc)
		if not S.WebhookOn or S.WebhookUrl == "" or not httpRequest then return end
		task.spawn(function()
			pcall(httpRequest, {
				Url = S.WebhookUrl,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = Svc.Http:JSONEncode({
					username = "BM Hub",
					embeds = { { title = title, description = desc, color = 53503, footer = { text = "Job ID: " .. game.JobId } } },
				}),
			})
		end)
	end

	-- هر پیام فقط یک بار برای هر کلید (مثلاً «جزیره اسپاون شد») تا اسپم نشه
	function V3.once(key, fn)
		if V3.seen[key] then return end
		V3.seen[key] = true
		fn()
	end
	function V3.resetOnce(key) V3.seen[key] = nil end

	function V3.flatDist(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	-- ابزار با اسم دقیق از Backpack/Character برمی‌داره و توی دست می‌ذاره
	function V3.equip(name)
		local t, h = backpackTool(name), getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end

	-- ابزاری که ToolTip اون نوعه (Blox Fruit / Sword / Gun / Melee)
	function V3.toolByTip(tip)
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.ToolTip == tip then return t end
				end
			end
		end
	end

	function V3.key(code, hold)
		if not VIM then return end
		pcall(function()
			VIM:SendKeyEvent(true, code, false, game)
			task.wait(hold or 0.05)
			VIM:SendKeyEvent(false, code, false, game)
		end)
	end

	-- دوربین رو سمت هدف می‌چرخونه و وسط صفحه کلیک می‌کنه (برای اسلحه‌هایی که با موس نشونه می‌گیرن)
	function V3.aimClick(pos)
		V3.aiming = true
		pcall(function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(camera.CFrame.Position, pos)
		end)
		local vs = camera.ViewportSize
		local x, y = vs.X * 0.5, vs.Y * 0.5
		if VIM then
			pcall(function()
				VIM:SendMouseMoveEvent(x, y, game)
				VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
				task.wait(0.03)
				VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
			end)
		else
			pcall(function()
				Svc.VirtualUser:CaptureController()
				Svc.VirtualUser:Button1Down(Vector2.new(x, y), camera.CFrame)
				Svc.VirtualUser:Button1Up(Vector2.new(x, y), camera.CFrame)
			end)
		end
	end

	function V3.aimRelease()
		if not V3.aiming then return end
		V3.aiming = false
		pcall(function() camera.CameraType = Enum.CameraType.Custom end)
	end

	-- ProximityPrompt / ClickDetector با یه تابع (هر کدوم executor پشتیبانی کنه)
	function V3.activate(obj)
		if not obj then return false end
		local ok = false
		pcall(function()
			if obj:IsA("ProximityPrompt") and fireproximityprompt then
				fireproximityprompt(obj, 1)
				ok = true
			elseif obj:IsA("ClickDetector") and fireclickdetector then
				fireclickdetector(obj)
				ok = true
			end
		end)
		return ok
	end

	function V3.findDesc(root, name)
		if not root then return nil end
		local ok, res = pcall(function() return root:FindFirstChild(name, true) end)
		return ok and res or nil
	end

	-- flag: اسم کلید توی S، step(keep): یک مرحله، cond(): شرط فعال بودن (مثلاً دریای مناسب)
	function V3.register(flag, step, cond, skipSave)
		if S[flag] == nil then S[flag] = false end
		if skipSave then Hub.V3SkipSave[flag] = true end
		table.insert(Hub.V3Tasks, { flag = flag, step = step, cond = cond })
	end

	function Hub.V3Busy()
		for _, t in ipairs(Hub.V3Tasks) do
			if S[t.flag] and (not t.cond or t.cond()) then return true end
		end
		return false
	end

	task.spawn(function()
		while Hub.Running do
			task.wait(0.3)
			local ran = false
			if alive() then
				for _, t in ipairs(Hub.V3Tasks) do
					if S[t.flag] and (not t.cond or t.cond()) then
						ran = true
						local flag = t.flag
						local ok, err = pcall(t.step, function() return S[flag] and Hub.Running end)
						if not ok then
							logError(flag, err)
							task.wait(2)
						end
						break
					end
				end
			end
			if not ran then V3.aimRelease() end
		end
		V3.aimRelease()
	end)
end)
if not okCore then logError("v3 core", errCore) end
end
