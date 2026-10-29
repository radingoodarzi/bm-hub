--[[
	BM Hub - تست ضربه‌ی ریموت (آزمایشی)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/test_remote.lua?t=" .. os.time()))()

	چند شکل مختلف آرگومان رو روی CombatUtil.SendHitsToServer (خود بازی توکن رو میسازه) امتحان میکنه
	و جون ماب رو قبل و بعد هر کدوم میسنجه. تکون نمیخوره و تلپورت نمیکنه.

	روش تست:
	1) یه سلاح (ملی/شمشیر) دستت بگیر.
	2) اول کنار ماب (کمتر از 8 استاد) اجرا کن  -> کدوم شکل کار میکنه (شاهد).
	3) بعد 25-40 استاد دورتر از ماب اجرا کن     -> سرور ضربه‌ی دور رو قبول میکنه یا نه.
	نتیجه روی صفحه (کادر متنی) + کلیپ‌بورد + bmscan/remote.txt
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM REMOTE HIT TEST ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end

-- ارسال خودکار گزارش (فقط متن تست) به کانال ntfy تا Claude مستقیم بخونه
local function upload(title, text)
	local req = (syn and syn.request) or http_request or request or (http and http.request)
	if not req then return add("upload: no http function in this executor") end
	local ok2, res = pcall(req, {
		Url = "https://ntfy.sh/bmhub-4628905e9720ae22ecf77f9b",
		Method = "POST",
		Headers = { ["Title"] = title },
		Body = text:sub(1, 3800),
	})
	add("upload:", ok2 and (res and res.StatusCode or "?") or tostring(res))
end

local function finish()
	local text = table.concat(out, "\n")
	pcall(upload, "remote-test", text)
	text = table.concat(out, "\n")
	pcall(function() writefile("bmscan/remote.txt", text) end)
	pcall(function() setclipboard(text) end)
	pcall(function()
		local old = player.PlayerGui:FindFirstChild("BMRemoteTest")
		if old then old:Destroy() end
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn = "BMRemoteTest", false
		gui.Parent = player.PlayerGui
		local box = Instance.new("TextBox")
		box.Size, box.Position = UDim2.new(0.9, 0, 0.5, 0), UDim2.new(0.05, 0, 0.05, 0)
		box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(20, 20, 24), Color3.fromRGB(235, 235, 235)
		box.TextXAlignment, box.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		box.TextSize, box.Font = 14, Enum.Font.Code
		box.ClearTextOnFocus, box.MultiLine, box.TextWrapped = false, true, true
		box.Text = text
		box.Parent = gui
		local close = Instance.new("TextButton")
		close.Size, close.Position = UDim2.new(0, 70, 0, 30), UDim2.new(0.95, -70, 0.05, -34)
		close.Text, close.Parent = "Close", gui
		close.MouseButton1Click:Connect(function() gui:Destroy() end)
	end)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Remote Test", Text = "Done - tell Claude", Duration = 8 })
	end)
end

local ok, err = pcall(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChildOfClass("Tool")
	add("tool:", tool and (tool.Name .. " / " .. tostring(tool.ToolTip)) or "NONE (equip a melee/sword first)")
	if not root then return add("no character") end

	-- نزدیک‌ترین ماب زنده
	local mob, dist
	for _, m in ipairs(workspace.Enemies:GetChildren()) do
		local hrp, hum = m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - root.Position).Magnitude
			if d < 150 and (not dist or d < dist) then mob, dist = m, d end
		end
	end
	if not mob then return add("no mob within 150 studs") end
	local hum = mob:FindFirstChildOfClass("Humanoid")
	local part = mob:FindFirstChild("Head") or mob:FindFirstChild("UpperTorso") or mob.HumanoidRootPart
	add(("mob: %s  dist=%.1f  hp=%.0f/%.0f  hitPart=%s"):format(mob.Name, dist, hum.Health, hum.MaxHealth, part.Name))

	local CU = require(ReplicatedStorage.Modules.CombatUtil)
	add("require CombatUtil ->", typeof(CU), " SendHitsToServer ->", typeof(CU and CU.SendHitsToServer))
	if type(CU) ~= "table" or type(CU.SendHitsToServer) ~= "function" then return end

	local RA
	pcall(function()
		for _, d in ipairs(ReplicatedStorage.Modules.Net:GetDescendants()) do
			if d:IsA("RemoteEvent") and d.Name:find("RegisterAttack", 1, true) then RA = d end
		end
	end)

	local shapes = {
		{ "{part}", function() return { part } end },
		{ "{{mob,part}}", function() return { { mob, part } } end },
		{ "part,{{mob,part}}", function() return part, { { mob, part } } end },
		{ "part,{part}", function() return part, { part } end },
	}

	for _, withAttack in ipairs({ false, true }) do
		for _, sh in ipairs(shapes) do
			if not mob.Parent or hum.Health <= 0 then
				add("mob died - stop")
				return
			end
			local before = hum.Health
			local callErr
			for i = 1, 3 do
				if withAttack and RA then pcall(function() RA:FireServer(0) end) end
				local okc, e = pcall(function() CU.SendHitsToServer(sh[2]()) end)
				if not okc then callErr = e end
				task.wait(0.25)
			end
			task.wait(0.6)
			add(("%-20s attack=%-5s  hp %.0f -> %.0f  %s%s"):format(
				sh[1], tostring(withAttack), before, hum.Health,
				hum.Health < before and "DAMAGE" or "none",
				callErr and ("  err=" .. tostring(callErr)) or ""
			))
			task.wait(0.5)
		end
	end
end)
if not ok then add("ERROR:", err) end
add("== done ==")
finish()
