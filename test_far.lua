--[[
	BM Hub - تست ضربه‌ی دور (آزمایشی، کم‌حجم)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/test_far.lua?t=" .. os.time()))()

	1) ملی/شمشیر بگیر دستت، کنار ماب یه M1 دستی بزن -> توکن از ضربه‌ی واقعی خودت گرفته میشه (جعل نیست).
	2) بعد از اعلان "token captured" خودت رو کم‌کم از ماب دور کن: حدود 12، 25، 45 استاد.
	3) برای هر بازه‌ی فاصله فقط یک بار تست میکنه (RegisterAttack + 2 تا RegisterHit) و جون ماب رو میسنجه.
	گزارش بعد از هر تست خودکار میره.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM FAR HIT TEST ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end

local function upload(title)
	local text = table.concat(out, "\n")
	pcall(function() writefile("bmscan/far.txt", text) end)
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
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Far Test", Text = t, Duration = 5 })
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
	return upload("far-test")
end

-- توکن از ضربه‌ی واقعی خودت
local token, attackArgs
local nA, nH, lastHitArgs = 0, 0, nil
local function onFire(self, args)
	if rawequal(self, RH) then
		nH += 1
		local tys = {}
		for i = 1, args.n do tys[#tys + 1] = typeof(args[i]) end
		lastHitArgs = "n=" .. args.n .. " types=" .. table.concat(tys, ",")
	else
		nA += 1
	end
	if rawequal(self, RH) and type(args[4]) == "string" and not token then
		token = args[4]
		add("token captured (len " .. #token .. ")")
		notify("token captured - now back away from the mob")
		upload("far-test")
	elseif rawequal(self, RA) then
		attackArgs = args
	end
end

local okHook, errHook = pcall(function()
	local old
	old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		if getnamecallmethod() == "FireServer" and (rawequal(self, RH) or rawequal(self, RA)) then
			local args = table.pack(...)
			task.defer(onFire, self, args)
		end
		return old(self, ...)
	end))
end)
add("hook:", okHook and "ok" or tostring(errHook))
upload("far-test")
if not okHook then return end
notify("Hit a mob once with M1")

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

-- گزارش دوره‌ای: هوک چند تا ریموت دیده؟
local t0 = os.clock()
task.spawn(function()
	local lastN = -1
	while os.clock() - t0 < 240 do
		task.wait(10)
		if nA + nH ~= lastN then
			lastN = nA + nH
			add(("[%.0fs] seen: attack=%d hit=%d lastHit=%s token=%s"):format(os.clock() - t0, nA, nH, tostring(lastHitArgs), tostring(token ~= nil)))
			upload("far-test")
		end
	end
end)

local BUCKETS ={ { 0, 10, "near" }, { 10, 20, "10-20" }, { 20, 35, "20-35" }, { 35, 60, "35-60" } }
local done = {}
local tests = 0

task.spawn(function()
	while os.clock() - t0 < 180 and tests < #BUCKETS do
		task.wait(1)
		if token then
			local mob, d = nearestMob()
			if mob then
				for _, b in ipairs(BUCKETS) do
					if d >= b[1] and d < b[2] and not done[b[3]] then
						done[b[3]] = true
						tests += 1
						local hum = mob:FindFirstChildOfClass("Humanoid")
						local part = mob:FindFirstChild("UpperTorso") or mob:FindFirstChild("HumanoidRootPart")
						local before = hum.Health
						local atkDelay = (attackArgs and attackArgs[1]) or 0.4
						for i = 1, 2 do
							pcall(function() RA:FireServer(atkDelay, 1) end)
							task.wait(0.15)
							pcall(function() RH:FireServer(part, {}, nil, token) end)
							task.wait(0.3)
						end
						task.wait(0.8)
						add(("bucket %-6s d=%.1f  %s  hp %.0f -> %.0f  %s"):format(
							b[3], d, mob.Name, before, hum.Health, hum.Health < before and "DAMAGE" or "none"
						))
						upload("far-test")
						notify(b[3] .. ": " .. (hum.Health < before and "DAMAGE" or "none"))
						break
					end
				end
			end
		end
	end
	add(("== finished: tests=%d token=%s =="):format(tests, tostring(token ~= nil)))
	upload("far-test")
	notify("Done - tell Claude")
end)
