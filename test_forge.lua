--[[
	BM Hub - تست ضربه‌ی ریموت بدون هوک (آزمایشی، کم‌حجم)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/test_forge.lua?t=" .. os.time()))()

	فرض (از روی بایت‌کد CombatUtil، مطمئن نیستیم): توکن = 3 رقم از UserId + 5 حرف هگز.
	بازی یک بار RegisterHit:FireServer(token) میزنه (دست‌دهی) و بعد هر ضربه (part, {}, nil, token).
	این اسکریپت همین رو بدون هوک و بدون M1 دستی انجام میده و جون ماب رو میسنجه.

	نکته: بعد از تست توکن سمت سرور عوض شده، پس M1 دستی خودت شاید تا ریجوین کار نکنه.

	روش: ملی/شمشیر دستت باشه. اول کنار ماب (کمتر از 10 استاد) اجرا کن  -> شاهد (اگه اینجا جون کم نشد، فرض غلطه).
	بعد خودت رو دور کن (حدود 15، 28، 45 استاد)؛ برای هر بازه فقط یک تست.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM FORGE TEST ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end

local function upload(title)
	local text = table.concat(out, "\n")
	pcall(function() writefile("bmscan/forge.txt", text) end)
	local req = (syn and syn.request) or http_request or request or (http and http.request)
	if req then
		pcall(req, {
			Url = "https://ntfy.sh/bmhub-4628905e9720ae22ecf77f9b",
			Method = "POST",
			Headers = { ["Title"] = title },
			Body = text:sub(1, 3800),
		})
	end
end

local function notify(t)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Forge Test", Text = t, Duration = 5 })
	end)
end

local function findRemote(key)
	local hit
	pcall(function()
		for _, d in ipairs(ReplicatedStorage.Modules.Net:GetDescendants()) do
			if d:IsA("RemoteEvent") and d.Name:find(key, 1, true) then hit = d end
		end
	end)
	return hit
end
local RH, RA = findRemote("RegisterHit"), findRemote("RegisterAttack")
if not (RH and RA) then
	add("remotes not found")
	return upload("forge-test")
end

-- توکن: 3 رقم UserId (کاراکتر 2 تا 4) + 5 حرف هگز
local token = tostring(player.UserId):sub(2, 4) .. string.format("%05x", math.random(0, 0xfffff))
add("forged token len", #token)
local handshaked = false

local function nearestMob()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local best, bestD
	for _, m in ipairs(workspace.Enemies:GetChildren()) do
		local hrp, hum = m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - root.Position).Magnitude
			if not bestD or d < bestD then best, bestD = m, d end
		end
	end
	return best, bestD
end

local BUCKETS = { { 0, 10, "near" }, { 10, 20, "10-20" }, { 20, 35, "20-35" }, { 35, 60, "35-60" } }
local done, tests = {}, 0
local t0 = os.clock()
add("tool:", (function()
	local t = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return t and (t.Name .. " / " .. tostring(t.ToolTip)) or "NONE"
end)())
upload("forge-test")
notify("Stand near a mob first (control test)")

while os.clock() - t0 < 240 and tests < #BUCKETS do
	task.wait(1)
	local mob, d = nearestMob()
	if mob then
		for _, b in ipairs(BUCKETS) do
			if d >= b[1] and d < b[2] and not done[b[3]] then
				done[b[3]] = true
				tests += 1
				if not handshaked then
					handshaked = true
					pcall(function() RH:FireServer(token) end)
					task.wait(0.3)
				end
				local hum = mob:FindFirstChildOfClass("Humanoid")
				local part = mob:FindFirstChild("UpperTorso") or mob:FindFirstChild("HumanoidRootPart")
				local before = hum.Health
				for i = 1, 2 do
					pcall(function() RA:FireServer(0.4, 1) end)
					task.wait(0.15)
					pcall(function() RH:FireServer(part, {}, nil, token) end)
					task.wait(0.3)
				end
				task.wait(0.8)
				add(("bucket %-6s d=%.1f  %s  hp %.0f -> %.0f  %s"):format(
					b[3], d, mob.Name, before, hum.Health, hum.Health < before and "DAMAGE" or "none"
				))
				upload("forge-test")
				notify(b[3] .. ": " .. (hum.Health < before and "DAMAGE" or "none"))
				break
			end
		end
	end
end
add(("== finished: tests=%d =="):format(tests))
upload("forge-test")
notify("Done - tell Claude")
