--[[
	BM Hub Teleport Scanner - تلپورترهای بازی رو پیدا می‌کنه (سریع، بدون decompile)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_tp.lua?t=" .. os.time()))()
	نکته: یه بار ورودی Cursed Ship رو امتحان می‌کنه، ممکنه بری توی کشتی.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local out = { "== BM TP SCAN ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function copyNow()
	return pcall(function() (setclipboard or toclipboard)(table.concat(out, "\n")) end)
end
local function fmt(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function notify(t)
	print("[BM TP Scanner] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM TP Scanner", Text = t, Duration = 8 }) end)
end

local okRun, runErr = pcall(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	add("position:", root and fmt(root.Position) or "?", "| place:", game.PlaceId)

	add("--- tags")
	local okTags, tags = pcall(function() return CollectionService:GetAllTags() end)
	if okTags then
		local hits = {}
		for _, t in ipairs(tags) do
			local l = t:lower()
			if l:find("tele") or l:find("portal") or l:find("pad") or l:find("door") or l:find("entr") or l:find("travel") then
				table.insert(hits, t .. "(" .. #CollectionService:GetTagged(t) .. ")")
			end
		end
		add(table.concat(hits, ", "))
	end
	copyNow()

	add("--- teleport-like parts")
	local count, promptCount = 0, 0
	local prompts = {}
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 4000 == 0 then task.wait() end
		if d:IsA("BasePart") and count < 200 then
			local l = d.Name:lower()
			local nameHit = l:find("tele") or l:find("portal") or l:find("entrance") or l:find("exit") or l:find("pad") or l:find("warp")
			local parentHit = d.Parent and d.Parent.Name:lower():find("tele")
			if (nameHit or parentHit) and not d:IsDescendantOf(player.Character or game) then
				count += 1
				local touch = d:FindFirstChildOfClass("TouchTransmitter") and " [TOUCH]" or ""
				add(d:GetFullName(), fmt(d.Position), touch)
			end
		elseif d:IsA("ProximityPrompt") and promptCount < 80 then
			promptCount += 1
			local p = d.Parent
			local pos = p and p:IsA("BasePart") and fmt(p.Position) or "?"
			table.insert(prompts, d:GetFullName() .. " | " .. d.ActionText .. " / " .. d.ObjectText .. " | " .. pos)
		end
	end
	add("teleport parts:", count)
	add("--- proximity prompts")
	for _, p in ipairs(prompts) do add(p) end
	copyNow()

	-- تست ورودی Cursed Ship با دو مختصات (قدیمی و قطعه‌ی تلپورت داخل کشتی)
	add("--- requestEntrance test")
	local CommF = ReplicatedStorage.Remotes:FindFirstChild("CommF_")
	for _, pos in ipairs({ Vector3.new(923.21, 126.98, 32852.83), Vector3.new(920.5, 154.9, 32839.0) }) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local before = r and r.Position
		local ok, res = pcall(CommF.InvokeServer, CommF, "requestEntrance", pos)
		task.wait(2)
		r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local moved = before and r and (r.Position - before).Magnitude or -1
		add("requestEntrance", fmt(pos), "-> ok:", ok, "res:", tostring(res), "| moved:", math.floor(moved))
		copyNow()
		if moved > 300 then break end
	end

	add("--- Net teleport remotes")
	for _, d in ipairs(ReplicatedStorage.Modules.Net:GetChildren()) do
		local l = d.Name:lower()
		if l:find("tele") or l:find("travel") or l:find("portal") or l:find("pad") then add(d.ClassName, d.Name) end
	end
end)

if not okRun then add("SCAN ERROR:", runErr) end
local copied = copyNow()
-- هر خط جدا چاپ میشه چون لاگ Roblox پیام‌های بلند رو کوتاه می‌کنه
for i, line in ipairs(out) do
	print(("[BMTP %03d] %s"):format(i, line))
	if i % 50 == 0 then task.wait() end
end
notify(copied and "Done ✔ - tell Claude" or "Done, tell Claude")
