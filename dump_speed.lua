--[[
	BM Hub - تست سرعت پرواز: بیشترین سرعتی که سرور قبول می‌کنه رو پیدا می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_speed.lua?t=" .. os.time()))()
	قبلش فارم‌های BM Hub رو خاموش کن و یه جای باز بایست. با اولین رد شدن متوقف میشه.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local SPEEDS = { 800, 1200, 1800, 2500, 3500, 5000 }
local DISTANCE = 700
local SAFE_BACK_SPEED = 250

local out = { "== BM SPEED TEST ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function notify(t)
	print("[BMS] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Speed Test", Text = t, Duration = 5 }) end)
end
local function getRoot()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

-- پرواز با سرعت مشخص و چک کردن مسیر؛ اگه سرور برگردونه یا بکشه false
local function flyTest(from, to, speed)
	local root = getRoot()
	if not root then return false, "dead before start" end
	local bv = root:FindFirstChild("BMSpeedFloat") or Instance.new("BodyVelocity")
	bv.Name = "BMSpeedFloat"
	bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bv.Velocity = Vector3.zero
	bv.Parent = root
	local duration = (to - from).Magnitude / speed
	local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to) })
	local started = os.clock()
	tw:Play()
	local worst = 0
	while tw.PlaybackState == Enum.PlaybackState.Playing do
		task.wait(0.05)
		local r = getRoot()
		if not r then
			tw:Cancel()
			return false, "character died"
		end
		local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
		local expected = from:Lerp(to, alpha)
		worst = math.max(worst, (r.Position - expected).Magnitude)
	end
	task.wait(0.6)
	local r = getRoot()
	if not r then return false, "character died after arrival" end
	local final = (r.Position - to).Magnitude
	if final > 30 then return false, ("pulled back (%.0f studs off)"):format(final) end
	return true, ("ok (max drift %.0f)"):format(worst)
end

local best = 0
local okRun, runErr = pcall(function()
	local root = getRoot()
	assert(root, "no character")
	local start = root.Position + Vector3.new(0, 30, 0)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then look = Vector3.new(1, 0, 0) end
	local far = start + look.Unit * DISTANCE
	add("start:", tostring(start), "| distance:", DISTANCE)

	-- بلند شدن آروم تا ارتفاع شروع
	flyTest(root.Position, start, SAFE_BACK_SPEED)
	for _, speed in ipairs(SPEEDS) do
		notify("Testing speed " .. speed .. "...")
		local ok, info = flyTest(start, far, speed)
		add("speed", speed, "->", ok and "ACCEPTED" or "REJECTED", "|", info)
		if not ok then break end
		best = speed
		-- برگشت با سرعت امن
		local backOk = flyTest(far, start, SAFE_BACK_SPEED)
		if not backOk then
			add("return flight failed, stopping")
			break
		end
		task.wait(1)
	end
	add("max accepted speed:", best)
end)
if not okRun then add("TEST ERROR:", runErr) end
pcall(function()
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bv = r and r:FindFirstChild("BMSpeedFloat")
	if bv then bv:Destroy() end
end)

pcall(function() writefile("bmscan/speed.txt", table.concat(out, "\n")) end)
for i, line in ipairs(out) do print(("[BMS %03d] %s"):format(i, line)) end
notify(("Done ✔ max safe speed: %d - tell Claude"):format(best))
