--[[
	BM Hub - شنود ضربه‌ی M1 (فقط خواندنی)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_hits.lua?t=" .. os.time()))()
	چیزی به سرور نمی‌فرسته. فقط وقتی خودت با دست M1 میزنی، آرگومان‌هایی که ماژول CombatUtil
	به سرور میده (SendHitsToServer) رو با فاصله‌ی ماب و جونش ثبت می‌کنه.
	کار: برو کنار یه ماب، 5-6 تا ضربه‌ی معمولی بزن (چندتاش رو از فاصله‌ی دورتر هم بزن)، بعد 40 ثانیه صبر کن.
	خروجی: bmscan/hits.txt + کلیپ‌بورد
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM HIT SNIFFER ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end

local function ser(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then return ("%q"):format(v) end
	if t == "Instance" then return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">" end
	if t == "Vector3" then return ("V3(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
	if t == "CFrame" then return ("CF(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
	if t == "table" then
		if depth > 4 then return "{...}" end
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 40 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function save()
	pcall(function() writefile("bmscan/hits.txt", table.concat(out, "\n")) end)
end

local okRun, runErr = pcall(function()
	local mod = ReplicatedStorage.Modules:FindFirstChild("CombatUtil")
	add("CombatUtil:", mod and mod:GetFullName() or "not found")
	local CU = mod and require(mod)
	add("require ->", typeof(CU))
	if type(CU) ~= "table" then return end

	add("--- fields")
	for k, v in pairs(CU) do
		if type(v) == "function" then add("fn", tostring(k)) end
	end

	local orig = CU.SendHitsToServer
	add("SendHitsToServer:", typeof(orig))
	if type(orig) ~= "function" then return end

	local count = 0
	CU.SendHitsToServer = function(...)
		count += 1
		if count <= 25 then
			local args = table.pack(...)
			local parts = {}
			for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
			add(("--- call %d  t=%.1f  nargs=%d"):format(count, os.clock() % 1000, args.n))
			add("args:", table.concat(parts, " | "))
			pcall(function()
				local root = player.Character.HumanoidRootPart
				for _, m in ipairs(workspace.Enemies:GetChildren()) do
					local hrp, hum = m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 and (hrp.Position - root.Position).Magnitude < 60 then
						add(("mob %s dist=%.1f hp=%.0f/%.0f"):format(m.Name, (hrp.Position - root.Position).Magnitude, hum.Health, hum.MaxHealth))
					end
				end
				local tool = player.Character:FindFirstChildOfClass("Tool")
				add("tool:", tool and (tool.Name .. " / " .. tool.ToolTip) or "none")
			end)
			save()
		end
		return orig(...)
	end
	add("hook installed - hit a mob with M1 now")
end)
if not okRun then add("ERROR:", runErr) end
save()

task.delay(60, function()
	add("== done ==")
	save()
	pcall(function() setclipboard(table.concat(out, "\n")) end)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hit Sniffer", Text = "Done - tell Claude", Duration = 8 })
	end)
end)
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hit Sniffer", Text = "Hit a mob with M1 for 60s", Duration = 6 })
end)
