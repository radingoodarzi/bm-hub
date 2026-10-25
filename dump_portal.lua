--[[
	BM Hub Portal Scanner - پورتال‌های سفر سریع بازی و منوی مقصدهاش رو پیدا می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_portal.lua?t=" .. os.time()))()
	قبلش Auto Farm و بقیه‌ی فارم‌های BM Hub رو خاموش کن. خرید یا تلپورتی انجام نمیده.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local out = { "== BM PORTAL SCAN ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function fmt(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function notify(t)
	print("[BM Portal Scanner] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Portal Scanner", Text = t, Duration = 8 }) end)
end
local function posOf(x)
	local ok, p = pcall(function()
		if x:IsA("Model") then return x:GetPivot().Position end
		if x:IsA("BasePart") then return x.Position end
	end)
	return ok and p or nil
end
local function attrs(x)
	local a = {}
	for k, v in pairs(x:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
	return table.concat(a, ",")
end

local function describe(obj, depth)
	add(string.rep("  ", depth) .. obj.ClassName, obj:GetFullName(), posOf(obj) and fmt(posOf(obj)) or "", "| attrs:", attrs(obj))
	if depth < 2 then
		for i, c in ipairs(obj:GetChildren()) do
			if i > 25 then break end
			describe(c, depth + 1)
		end
	end
end

local okRun, runErr = pcall(function()
	notify("Scanning portals...")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	add("start:", root and fmt(root.Position) or "?", "| place:", game.PlaceId)

	-- 1) پورتال‌ها
	local candidates = {}
	add("--- WORLD_TELEPORTER tagged:", #CollectionService:GetTagged("WORLD_TELEPORTER"))
	for _, inst in ipairs(CollectionService:GetTagged("WORLD_TELEPORTER")) do
		describe(inst, 0)
		if posOf(inst) then table.insert(candidates, inst) end
	end
	add("--- portal-like objects")
	local n = 0
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 4000 == 0 then task.wait() end
		if n >= 30 then break end
		local l = d.Name:lower()
		if (d:IsA("Model") or d:IsA("BasePart")) and (l:find("portal") or l:find("worldtele") or l:find("fasttravel")) then
			n += 1
			add(d.ClassName, d:GetFullName(), posOf(d) and fmt(posOf(d)) or "", "| attrs:", attrs(d))
			if posOf(d) then table.insert(candidates, d) end
		end
	end

	-- 2) نزدیک‌ترین پورتال
	root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local target, best
	for _, c in ipairs(candidates) do
		local d = (posOf(c) - root.Position).Magnitude
		if not best or d < best then target, best = c, d end
	end
	if not target then
		add("no portal found")
		return
	end
	add("--- target:", target:GetFullName(), "distance:", math.floor(best))
	describe(target, 0)

	-- 3) پرواز با سرعت عادی تا پورتال و ایستادن روش
	local goal = posOf(target)
	if best > 3000 then
		add("portal too far, not flying (", math.floor(best), ")")
	else
		notify("Flying to portal (" .. math.floor(best) .. " studs)...")
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bv.Velocity = Vector3.zero
		bv.Parent = root
		local tw = TweenService:Create(root, TweenInfo.new(best / 250, Enum.EasingStyle.Linear), { CFrame = CFrame.new(goal + Vector3.new(0, 3, 0)) })
		tw:Play()
		tw.Completed:Wait()
		root.CFrame = CFrame.new(goal + Vector3.new(0, 1, 0))
		task.wait(0.5)
		bv:Destroy()
		-- لمس همه‌ی قطعه‌های لمسی پورتال
		local touched = 0
		for _, d in ipairs((target:IsA("Model") and target or target.Parent):GetDescendants()) do
			if d:IsA("TouchTransmitter") and d.Parent:IsA("BasePart") and firetouchinterest then
				touched += 1
				pcall(function()
					firetouchinterest(root, d.Parent, 0)
					task.wait(0.1)
					firetouchinterest(root, d.Parent, 1)
				end)
			end
		end
		add("touch parts fired:", touched)
		task.wait(3)
	end

	-- 4) پرامپت‌ها و کلیک‌ها نزدیک پورتال
	add("--- prompts/clickers near portal")
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("ProximityPrompt") or d:IsA("ClickDetector")) and d.Parent then
			local p = posOf(d.Parent)
			if p and (p - goal).Magnitude < 80 then
				local extra = d:IsA("ProximityPrompt") and (" action=" .. d.ActionText .. " object=" .. d.ObjectText .. " key=" .. tostring(d.KeyboardKeyCode)) or ""
				add(d.ClassName, d:GetFullName(), extra)
			end
		end
	end

	-- 5) منوی مقصدها (دکمه‌ها و متن‌های قابل دیدن)
	add("--- visible UI matching destinations")
	local KEYS = { "mansion", "cafe", "castle", "hydra", "tiki", "teleport", "travel", "portal", "kingdom", "port town", "great tree", "turtle", "haunted", "island", "sea of", "colosseum", "graveyard", "snow", "factory", "ice", "forgotten", "dark arena" }
	local function visible(g)
		local x = g
		while x and x:IsA("GuiObject") do
			if not x.Visible then return false end
			x = x.Parent
		end
		if x and x:IsA("ScreenGui") and not x.Enabled then return false end
		return true
	end
	local inset = Vector2.zero
	pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)
	add("gui inset:", tostring(inset))
	local shown = 0
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if shown >= 150 then break end
		if d:IsA("GuiObject") and visible(d) then
			local text = (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text or ""
			local hay = (d.Name .. " " .. text):lower()
			for _, k in ipairs(KEYS) do
				if hay:find(k, 1, true) then
					shown += 1
					add(d.ClassName, (d:GetFullName():gsub("^.-PlayerGui%.", "")), ("%q"):format(text:sub(1, 40)),
						"| pos:", tostring(d.AbsolutePosition), "size:", tostring(d.AbsoluteSize))
					break
				end
			end
		end
	end
	add("ui matches:", shown)
end)

if not okRun then add("SCAN ERROR:", runErr) end
pcall(function() (setclipboard or toclipboard)(table.concat(out, "\n")) end)
for i, line in ipairs(out) do
	print(("[BMPT %03d] %s"):format(i, line))
	if i % 50 == 0 then task.wait() end
end
notify("Done ✔ - tell Claude")
