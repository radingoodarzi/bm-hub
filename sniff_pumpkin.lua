--[[
	BM Hub - شنود کدوی هالووین (فقط لاگ؛ چیزی به سرور نمی‌فرسته و چیزی تغییر نمیده)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/sniff_pumpkin.lua?t=" .. os.time()))()

	کار: اجرا کن (همون لحظه یه اعلان "started" میاد)، برو کنار یه کدوی PumpkinHunt، با ملی بزنش تا بشکنه،
	بعد 120 ثانیه صبر کن تا اعلان "Done" بیاد.
	ثبت می‌کنه: وضعیت کدوها (PumpkinState / PumpkinHits)، شکستنشون، ماب‌هایی که اسپان میشن،
	رویدادهای سرور، آرگومان ضربه‌ی M1، تغییر Data و کیف.
	خروجی: bmscan/pumpkin_sniff.txt (هر چند ثانیه ذخیره میشه) + کلیپ‌بورد
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local DURATION = 120
local t0 = os.clock()

local out = { "== BM PUMPKIN SNIFFER ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, ("[%5.1f] "):format(os.clock() - t0) .. table.concat(parts, " "))
end
local function save()
	pcall(function() writefile("bmscan/pumpkin_sniff.txt", table.concat(out, "\n")) end)
end
local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Pumpkin Sniffer", Text = text, Duration = 8 })
	end)
end

notify("started - hit a pumpkin with melee (" .. DURATION .. "s)")

local function ser(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then return ("%q"):format(v) end
	if t == "Instance" then return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">" end
	if t == "Vector3" then return ("V3(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
	if t == "CFrame" then return ("CF(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
	if t == "table" then
		if depth > 3 then return "{...}" end
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 25 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function attrs(o)
	local list = {}
	for k, v in pairs(o:GetAttributes()) do list[#list + 1] = k .. "=" .. tostring(v) end
	table.sort(list)
	return table.concat(list, ", ")
end

local function posOf(o)
	if o:IsA("BasePart") then return o.Position end
	local ok, p = pcall(function() return o:GetPivot().Position end)
	return ok and p or nil
end
local function fmt(p) return p and ("%.0f,%.0f,%.0f"):format(p.X, p.Y, p.Z) or "?" end

local conns = {}
local function keep(c) conns[#conns + 1] = c end

-- ① وضعیت کدوها
local hunt = workspace:FindFirstChild("PumpkinHunt")
add("PumpkinHunt folder:", hunt and "found" or "NOT FOUND")
save()

local watched = {}
local function watch(o)
	if watched[o] then return end
	watched[o] = true
	keep(o.AttributeChanged:Connect(function(a)
		add("PUMPKIN ATTR", o.Name, fmt(posOf(o)), a, "=", tostring(o:GetAttribute(a)))
	end))
	keep(o.AncestryChanged:Connect(function(_, parent)
		if not parent then add("PUMPKIN REMOVED", o.Name, fmt(posOf(o)), "last attrs:", attrs(o)) end
	end))
	keep(o.ChildAdded:Connect(function(c) add("PUMPKIN child+", c.Name, c.ClassName) end))
	keep(o.ChildRemoved:Connect(function(c) add("PUMPKIN child-", c.Name, c.ClassName) end))
end

if hunt then
	local kids = hunt:GetChildren()
	add("pumpkins in folder:", #kids)
	for i, o in ipairs(kids) do
		if i <= 40 then add("  ", o.Name, o.ClassName, "pos", fmt(posOf(o)), "attrs:", attrs(o)) end
		watch(o)
	end
	keep(hunt.ChildAdded:Connect(function(o)
		add("PUMPKIN SPAWNED", o.Name, o.ClassName, "pos", fmt(posOf(o)), "attrs:", attrs(o))
		watch(o)
	end))
	keep(hunt.ChildRemoved:Connect(function(o) add("PUMPKIN folder child removed:", o.Name) end))
end
save()

-- ② ماب‌هایی که اسپان میشن
pcall(function()
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		keep(enemies.ChildAdded:Connect(function(m)
			task.wait(0.2)
			add("ENEMY SPAWNED", m.Name, "pos", fmt(posOf(m)))
		end))
		keep(enemies.ChildRemoved:Connect(function(m) add("ENEMY REMOVED", m.Name) end))
	end
end)
save()

-- ③ آرگومان ضربه‌ی M1 (فقط لاگ، همون رو به سرور میده)
-- require ممکنه برای همیشه منتظر بمونه؛ پس جدا و با تایم‌اوت 5 ثانیه (بقیه‌ی شنود منتظرش نمیمونه)
local m1Done = false
task.spawn(function()
	pcall(function()
		local mod = ReplicatedStorage.Modules:FindFirstChild("CombatUtil")
		local CU = mod and require(mod)
		local orig = type(CU) == "table" and CU.SendHitsToServer
		if type(orig) == "function" then
			local calls = 0
			CU.SendHitsToServer = function(...)
				calls += 1
				if calls <= 25 then
					local args = table.pack(...)
					local parts = {}
					for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
					add("M1 SendHitsToServer", calls, table.concat(parts, " | "):sub(1, 600))
				end
				return orig(...)
			end
			add("M1 hook installed")
		else
			add("M1 hook: SendHitsToServer not found")
		end
	end)
	m1Done = true
end)
task.delay(5, function()
	if not m1Done then add("M1 hook: require(CombatUtil) is stuck - skipped") end
end)
save()

-- ④ Data و کیف (کندی، آیتم...)
pcall(function()
	local data = player:FindFirstChild("Data")
	if data then
		for _, v in ipairs(data:GetDescendants()) do
			if v:IsA("ValueBase") then
				keep(v.Changed:Connect(function(val) add("DATA", v.Name, "->", tostring(val)) end))
			end
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		keep(bp.ChildAdded:Connect(function(c) add("BACKPACK +", c.Name, c.ClassName) end))
		keep(bp.ChildRemoved:Connect(function(c) add("BACKPACK -", c.Name, c.ClassName) end))
	end
end)
save()

-- ⑤ رویدادهایی که سرور به کلاینت میفرسته (حداکثر 5 تا از هر کدوم، 100 تا کل)
pcall(function()
	local per, total = {}, 0
	for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
		if r:IsA("RemoteEvent") then
			keep(r.OnClientEvent:Connect(function(...)
				per[r] = (per[r] or 0) + 1
				total += 1
				if per[r] <= 5 and total <= 100 then
					local args = table.pack(...)
					local parts = {}
					for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
					add("SERVER->ME", r:GetFullName(), table.concat(parts, " | "):sub(1, 300))
				end
			end))
		end
	end
	add("listening to server events")
end)

add("--- LIVE: hit a pumpkin with melee now")
save()

while os.clock() - t0 < DURATION do
	task.wait(2)
	save()
end

for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
add("== done ==")
save()
pcall(function() setclipboard(table.concat(out, "\n")) end)
notify("Done - tell Claude")
