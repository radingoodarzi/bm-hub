--[[
	BM Hub - تست WorldTeleporter (فقط خواندنی)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_wt.lua?t=" .. os.time()))()
	فقط لیست جزیره‌های سفر سریع رو از سرور می‌پرسه. هیچ تلپورتی انجام نمیده.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM WORLD TELEPORTER TEST ==" }
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
			if n > 60 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local okRun, runErr = pcall(function()
	add("place:", game.PlaceId)
	add("--- player attributes")
	for k, v in pairs(player:GetAttributes()) do add(k, "=", ser(v)) end

	local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
	local rf = net and net:FindFirstChild("RF/WorldTeleporter")
	add("--- RF/WorldTeleporter:", rf and rf:GetFullName() or "not found")
	if rf then
		local ok, res = pcall(rf.InvokeServer, rf, { Type = "GetLocations" })
		add("GetLocations -> ok:", ok)
		add("result:", ser(res))
	end
end)
if not okRun then add("TEST ERROR:", runErr) end

pcall(function() writefile("bmscan/wt.txt", table.concat(out, "\n")) end)
for i, line in ipairs(out) do print(("[BMWT %03d] %s"):format(i, line)) end
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM WorldTeleporter Test", Text = "Done ✔ - tell Claude", Duration = 8 })
end)
