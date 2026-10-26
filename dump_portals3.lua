--[[
	BM Hub - اسکنر پورتال‌های Sea 3 (Mansion، Castle، Hydra و ...)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_portals3.lua?t=" .. os.time()))()
	فقط می‌خونه. تنها درخواست به سرور GetUnlockables هست که فقط وضعیت باز بودن پورتال‌ها رو برمی‌گردونه.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local out = { "== BM SEA 3 PORTAL SCAN ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function fmt(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function posOf(x)
	local ok, p = pcall(function()
		if x:IsA("Model") then return x:GetPivot().Position end
		if x:IsA("BasePart") then return x.Position end
		if x:IsA("Attachment") then return x.WorldPosition end
	end)
	return ok and p and fmt(p) or ""
end
local function ser(v, d)
	d = d or 0
	local t = typeof(v)
	if t == "Vector3" then return "V3" .. fmt(v) end
	if t == "CFrame" then return "CF" .. fmt(v.Position) end
	if t == "Instance" then return "<" .. v:GetFullName() .. ">" end
	if t == "table" then
		if d > 2 then return "{...}" end
		local p = {}
		for k, val in pairs(v) do table.insert(p, tostring(k) .. "=" .. ser(val, d + 1)) end
		return "{" .. table.concat(p, ", ") .. "}"
	end
	return tostring(v)
end
-- ویژگی‌ها و مقدارهای داخلی (ممکنه مقصد پورتال توشون باشه)
local function extras(x)
	local e = {}
	for k, v in pairs(x:GetAttributes()) do table.insert(e, "@" .. k .. "=" .. ser(v)) end
	for _, c in ipairs(x:GetChildren()) do
		if c:IsA("ValueBase") then table.insert(e, c.Name .. "=" .. ser(c.Value)) end
		if c:IsA("TouchTransmitter") then table.insert(e, "[TOUCH]") end
		if c:IsA("ProximityPrompt") then table.insert(e, "[PROMPT " .. c.ActionText .. "]") end
		if c:IsA("ClickDetector") then table.insert(e, "[CLICK]") end
	end
	return table.concat(e, " ")
end

local okRun, runErr = pcall(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	add("place:", game.PlaceId, "| position:", root and fmt(root.Position) or "?")
	local ok, unlock = pcall(function()
		return ReplicatedStorage.Remotes.CommF_:InvokeServer("GetUnlockables")
	end)
	add("GetUnlockables:", ok and ser(unlock) or tostring(unlock))

	add("--- tags")
	for _, t in ipairs(CollectionService:GetAllTags()) do
		local l = t:lower()
		if l:find("portal") or l:find("tele") or l:find("gate") or l:find("door") then
			add(t, #CollectionService:GetTagged(t))
		end
	end

	add("--- map objects (portal / teleport / entrance)")
	local n = 0
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 5000 == 0 then task.wait() end
		if n >= 200 then break end
		if d:IsA("BasePart") or d:IsA("Model") then
			local l = d.Name:lower()
			if l:find("portal") or l:find("teleport") or l:find("entrance") or l:find("exit") or l:find("hitbox") and d.Parent and d.Parent.Name:lower():find("portal") then
				n += 1
				add(d.ClassName, d:GetFullName(), posOf(d), extras(d))
			end
		end
	end
	add("objects:", n)
end)
if not okRun then add("SCAN ERROR:", runErr) end

pcall(function() writefile("bmscan/portals3.txt", table.concat(out, "\n")) end)
for i, line in ipairs(out) do print(("[BMP3 %03d] %s"):format(i, line)) end
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Portal Scanner", Text = "Done ✔ - tell Claude", Duration = 8 })
end)
