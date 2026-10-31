--[[
	BM Hub - اسکنر کدو هالووین (فقط خواندنی؛ چیزی به سرور نمی‌فرسته و چیزی تغییر نمیده)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_pumpkin.lua?t=" .. os.time()))()

	کار: اجرا کن، برو کنار یه کدو، با ملی بزنش تا بشکنه (یه چندتا هم روش کلیک کن)، 90 ثانیه صبر کن.
	ثبت می‌کنه: کدوهای نزدیک، چیزی که زیر موس بوده، هر چیزی که اضافه/حذف/عوض شده، رویدادهایی که
	سرور به کلاینت فرستاده، تغییر Data و کیف، و آرگومان ضربه‌ی M1.
	خروجی: bmscan/pumpkin.txt + کلیپ‌بورد
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local DURATION = 90
local PATTERNS = { "pumpkin", "halloween", "candy", "lantern", "gourd", "spooky" }
local t0 = os.clock()

local out = { "== BM PUMPKIN SCANNER ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, ("[%5.1f] "):format(os.clock() - t0) .. table.concat(parts, " "))
end

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
	pcall(function() writefile("bmscan/pumpkin.txt", table.concat(out, "\n")) end)
end

local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function posOf(o)
	if o:IsA("BasePart") then return o.Position end
	if o:IsA("Model") then
		local ok, p = pcall(function() return o:GetPivot().Position end)
		if ok then return p end
	end
end

local function distTo(o)
	local r, p = getRoot(), posOf(o)
	return r and p and (r.Position - p).Magnitude or math.huge
end

local function describe(o)
	local attrs, kids = {}, {}
	for k, v in pairs(o:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
	for i, c in ipairs(o:GetChildren()) do
		if i > 14 then
			kids[#kids + 1] = "..."
			break
		end
		kids[#kids + 1] = c.Name .. "[" .. c.ClassName .. "]"
	end
	local p = posOf(o)
	local size = ""
	if o:IsA("BasePart") then size = (" size=%.1f,%.1f,%.1f transp=%.2f collide=%s"):format(o.Size.X, o.Size.Y, o.Size.Z, o.Transparency, tostring(o.CanCollide)) end
	return ("%s <%s> pos=%s%s attrs{%s} tags{%s} kids{%s}"):format(
		o:GetFullName(), o.ClassName, p and ("%.0f,%.0f,%.0f"):format(p.X, p.Y, p.Z) or "?", size,
		table.concat(attrs, ","), table.concat(CollectionService:GetTags(o), ","), table.concat(kids, ","))
end

local function excluded(o)
	return o:FindFirstAncestor("Enemies") ~= nil or o:FindFirstAncestor("Characters") ~= nil
end

local okRun, runErr = pcall(function()
	local root = getRoot()
	add("player pos:", root and tostring(root.Position) or "none")
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	add("held tool:", tool and (tool.Name .. " / " .. tostring(tool.ToolTip)) or "none")

	---------------------------------------------------------------- 1) snapshot
	add("--- A) objects whose name matches", table.concat(PATTERNS, "/"), "(closest 60)")
	local found, n = {}, 0
	for _, o in ipairs(workspace:GetDescendants()) do
		n += 1
		if n % 3000 == 0 then task.wait() end
		if (o:IsA("Model") or o:IsA("BasePart")) and not excluded(o) then
			local l = o.Name:lower()
			for _, pat in ipairs(PATTERNS) do
				if l:find(pat, 1, true) then
					table.insert(found, o)
					break
				end
			end
		end
	end
	table.sort(found, function(a, b) return distTo(a) < distTo(b) end)
	add("matches in workspace:", #found)
	for i = 1, math.min(#found, 60) do add(("d=%.0f"):format(distTo(found[i])), describe(found[i])) end

	add("--- B) parts within 25 studs of you (no mobs/players)")
	pcall(function()
		local r = getRoot()
		if not r then return add("no character root") end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local parts = workspace:GetPartBoundsInRadius(r.Position, 25, params)
		table.sort(parts, function(a, b) return (a.Position - r.Position).Magnitude < (b.Position - r.Position).Magnitude end)
		local shown = 0
		for _, part in ipairs(parts) do
			if not excluded(part) then
				shown += 1
				if shown > 40 then break end
				local chain, cur = {}, part
				while cur and cur ~= workspace do
					chain[#chain + 1] = cur.Name
					cur = cur.Parent
				end
				add(("d=%.0f"):format((part.Position - r.Position).Magnitude), describe(part))
				add("  chain:", table.concat(chain, " < "))
			end
		end
		if shown == 0 then add("(nothing within 25 studs - stand NEXT TO a pumpkin)") end
	end)
	save()

	---------------------------------------------------------------- 2) live watch
	-- أ) هر چیزی که نزدیک (80 استاد) اضافه یا حذف میشه
	local addCount, remCount, logged = {}, {}, {}
	local function note(kind, o, counts)
		local key = o.Name .. "|" .. o.ClassName
		counts[key] = (counts[key] or 0) + 1
		if (logged[kind .. key] or 0) < 3 and distTo(o) <= 80 then
			logged[kind .. key] = (logged[kind .. key] or 0) + 1
			add(kind, describe(o))
		end
	end
	local conns = {}
	table.insert(conns, workspace.DescendantAdded:Connect(function(o)
		if o:IsA("Model") or o:IsA("BasePart") or o:IsA("Tool") or o:IsA("ParticleEmitter") then pcall(note, "ADDED", o, addCount) end
	end))
	table.insert(conns, workspace.DescendantRemoving:Connect(function(o)
		if o:IsA("Model") or o:IsA("BasePart") or o:IsA("Tool") then pcall(note, "REMOVED", o, remCount) end
	end))

	-- ب) تغییر ویژگی/اندازه/شفافیت روی 25 تا از نزدیک‌ترین کدوها
	for i = 1, math.min(#found, 25) do
		local o, hits = found[i], 0
		local function ch(what)
			hits += 1
			if hits <= 12 then add("CHANGED", what, o:GetFullName()) end
		end
		table.insert(conns, o.AttributeChanged:Connect(function(a) ch("attr " .. a .. "=" .. tostring(o:GetAttribute(a))) end))
		table.insert(conns, o.ChildAdded:Connect(function(c) ch("child+ " .. c.Name .. "[" .. c.ClassName .. "]") end))
		table.insert(conns, o.ChildRemoved:Connect(function(c) ch("child- " .. c.Name .. "[" .. c.ClassName .. "]") end))
		if o:IsA("BasePart") then
			table.insert(conns, o.Changed:Connect(function(prop) ch("prop " .. prop) end))
		end
	end

	-- ج) رویدادهایی که سرور به کلاینت میفرسته (فقط گوش میدیم)
	local remoteLogs, totalRemote = {}, 0
	for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
		if r:IsA("RemoteEvent") then
			pcall(function()
				table.insert(conns, r.OnClientEvent:Connect(function(...)
					remoteLogs[r] = (remoteLogs[r] or 0) + 1
					totalRemote += 1
					if remoteLogs[r] <= 6 and totalRemote <= 160 then
						local args = table.pack(...)
						local parts = {}
						for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
						add("SERVER->ME", r:GetFullName(), table.concat(parts, " | "):sub(1, 300))
					end
				end))
			end)
		end
	end

	-- د) Data (کندی/امتیاز...) و کیف
	local data = player:FindFirstChild("Data")
	if data then
		for _, v in ipairs(data:GetDescendants()) do
			if v:IsA("ValueBase") then
				table.insert(conns, v.Changed:Connect(function(val) add("DATA", v.Name, "->", tostring(val)) end))
			end
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		table.insert(conns, bp.ChildAdded:Connect(function(c) add("BACKPACK +", c.Name, c.ClassName) end))
		table.insert(conns, bp.ChildRemoved:Connect(function(c) add("BACKPACK -", c.Name, c.ClassName) end))
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") then
				table.insert(conns, v.Changed:Connect(function(val) add("LEADERSTAT", v.Name, "->", tostring(val)) end))
			end
		end
	end

	-- هـ) هر کلیک: چی زیر موسه
	local mouse = player:GetMouse()
	local clicks = 0
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		clicks += 1
		if clicks > 30 then return end
		local tgt = mouse.Target
		if not tgt then return add("CLICK", clicks, "nothing under the mouse") end
		local chain, cur = {}, tgt
		while cur and cur ~= workspace do
			chain[#chain + 1] = cur.Name .. "[" .. cur.ClassName .. "]"
			cur = cur.Parent
		end
		add("CLICK", clicks, "d=" .. ("%.0f"):format(distTo(tgt)), "target:", describe(tgt))
		add("  chain:", table.concat(chain, " < "))
		local model = tgt:FindFirstAncestorOfClass("Model")
		if model and model ~= player.Character then add("  model:", describe(model)) end
	end))

	-- و) آرگومان ضربه‌ی M1 (فقط لاگ، همون رو به سرور میده)
	pcall(function()
		local mod = ReplicatedStorage.Modules:FindFirstChild("CombatUtil")
		local CU = mod and require(mod)
		local orig = type(CU) == "table" and CU.SendHitsToServer
		if type(orig) == "function" then
			local calls = 0
			CU.SendHitsToServer = function(...)
				calls += 1
				if calls <= 20 then
					local args = table.pack(...)
					local parts = {}
					for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
					add("M1 SendHitsToServer", calls, table.concat(parts, " | "):sub(1, 500))
				end
				return orig(...)
			end
			add("M1 hook installed")
		else
			add("M1 hook: SendHitsToServer not found")
		end
	end)

	add("--- LIVE: go hit a pumpkin with melee now (" .. DURATION .. "s)")
	save()
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Pumpkin Scanner", Text = "Hit a pumpkin with melee for " .. DURATION .. "s", Duration = 8 })
	end)

	while os.clock() - t0 < DURATION do
		task.wait(3)
		save()
	end

	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	local function summary(title, counts)
		local list = {}
		for k, v in pairs(counts) do list[#list + 1] = k .. " x" .. v end
		table.sort(list)
		add(title, #list == 0 and "(none)" or table.concat(list, "; "):sub(1, 1500))
	end
	summary("--- summary ADDED near you:", addCount)
	summary("--- summary REMOVED near you:", remCount)
end)
if not okRun then add("ERROR:", runErr) end

add("== done ==")
save()
pcall(function() setclipboard(table.concat(out, "\n")) end)
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Pumpkin Scanner", Text = "Done - tell Claude", Duration = 8 })
end)
