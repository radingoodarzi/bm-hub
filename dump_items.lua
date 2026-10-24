--[[
	BM Hub Item Scanner (Sea 2) - اطلاعات زنجیره‌ی آیتم‌ها رو جمع می‌کنه و کپی می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_items.lua"))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = {}
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function section(name) add("") add("===== " .. name .. " =====") end
local function fmtVec(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end

local function ser(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then return ("%q"):format(v) end
	if t == "Instance" then return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">" end
	if t == "Vector3" then return "V3" .. fmtVec(v) end
	if t == "CFrame" then return "CF" .. fmtVec(v.Position) end
	if t == "table" then
		if depth > 2 then return "{...}" end
		local parts, n = {}, 0
		for k, val in pairs(v) do
			n += 1
			if n > 15 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, "[" .. ser(k, depth + 1) .. "]=" .. ser(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local gui = Instance.new("ScreenGui")
gui.Name = "BMItemScanner"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(460, 70)
label.Position = UDim2.new(0.5, -230, 0, 60)
label.BackgroundColor3 = Color3.fromRGB(18, 19, 28)
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
local function status(t)
	label.Text = t
	print("[BM Item Scanner] " .. t)
end

local CommF = ReplicatedStorage.Remotes:FindFirstChild("CommF_")
local function invoke(...)
	local ok, r = pcall(CommF.InvokeServer, CommF, ...)
	return ok, r
end

---------------------------------------------------------------------
section("CAPS")
add("fireclickdetector=", type(fireclickdetector), "firetouchinterest=", type(firetouchinterest),
	"fireproximityprompt=", type(fireproximityprompt), "decompile=", type(decompile),
	"getscripts=", type(getscripts), "getloadedmodules=", type(getloadedmodules), "getscriptbytecode=", type(getscriptbytecode))
local data = player:FindFirstChild("Data")
add("Level:", data and data.Level.Value, "| Beli:", data and data.Beli.Value, "| Fragments:", data and data.Fragments.Value)

---------------------------------------------------------------------
status("Reading inventory...")
section("INVENTORY")
local ok, inv = invoke("getInventory")
add("getInventory ok:", ok, "type:", typeof(inv))
if ok and type(inv) == "table" then
	for _, item in pairs(inv) do
		if type(item) == "table" then
			add(tostring(item.Type), "|", tostring(item.Name), "| count:", tostring(item.Count), "| mastery:", tostring(item.Mastery), "| rarity:", tostring(item.Rarity))
		else
			add(ser(item))
		end
	end
end
local tools = {}
for _, cont in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
	if cont then
		for _, t in ipairs(cont:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, t.Name .. "[" .. t.ToolTip .. "]") end
		end
	end
end
add("backpack:", table.concat(tools, ", "))

-- فقط دستورهای چک/پیشرفت؛ هیچ دستوری که ممکنه خرید کنه فرستاده نمیشه
section("SAFE QUERIES")
for _, args in ipairs({
	{ "Ectoplasm", "Check" },
	{ "ProQuestProgress" },
	{ "BartiloQuestProgress" },
}) do
	local qok, r = invoke(table.unpack(args))
	add(table.concat(args, ","), "->", qok, ser(r))
	task.wait(0.2)
end

---------------------------------------------------------------------
status("Decompiling game scripts (can take a minute)...")
section("DECOMPILE SEARCH")
local KEYWORDS = {
	"Ectoplasm", "Midnight", "Rengoku", "Hidden Key", "HiddenKey", "LegendarySwordDealer", "MysteriousMan",
	"Triple Katana", "TrueTripleKatana", "Trident", "Experimic", "BlackbeardReward", "Bartilo", "Tide Keeper",
}
local function hasKeyword(line)
	for _, k in ipairs(KEYWORDS) do
		if line:find(k, 1, true) then return k end
	end
end

local scripts = {}
local seenScript = {}
local function addScript(s)
	if s and not seenScript[s] and (s:IsA("LocalScript") or s:IsA("ModuleScript")) then
		seenScript[s] = true
		table.insert(scripts, s)
	end
end
-- اول ماژول‌هایی که احتمال داره دیالوگ‌ها و خریدها توشون باشه
for _, name in ipairs({ "DialoguesList", "DialogueController", "NPCManager", "NPCTable", "Shop", "Global", "GlobalUtil", "ValDeliveryDialogue" }) do
	addScript(ReplicatedStorage:FindFirstChild(name))
end
for _, root in ipairs({ player:FindFirstChild("PlayerScripts"), player:FindFirstChild("PlayerGui"), ReplicatedStorage }) do
	if root then
		for _, d in ipairs(root:GetDescendants()) do
			if #scripts >= 120 then break end
			addScript(d)
		end
	end
end

local matches, decompiled, failed = 0, 0, 0
local started = os.clock()
if type(decompile) == "function" then
	for i, s in ipairs(scripts) do
		if matches >= 250 or os.clock() - started > 90 then break end
		if i % 5 == 0 then
			status(("Decompiling %d/%d  (matches: %d)"):format(i, #scripts, matches))
			task.wait()
		end
		local dok, src = pcall(decompile, s)
		if dok and type(src) == "string" then
			decompiled += 1
			local lines = src:split("\n")
			for ln, line in ipairs(lines) do
				local k = hasKeyword(line)
				if k then
					matches += 1
					add(("[%s:%d] %s"):format(s:GetFullName(), ln, line:gsub("^%s+", ""):sub(1, 220)))
					-- یک خط قبل و بعد برای فهمیدن آرگومان‌ها
					if lines[ln + 1] then add("      + " .. lines[ln + 1]:gsub("^%s+", ""):sub(1, 220)) end
					if matches >= 250 then break end
				end
			end
		else
			failed += 1
		end
	end
end
add("scripts:", #scripts, "decompiled:", decompiled, "failed:", failed, "matches:", matches, "time:", math.floor(os.clock() - started))

---------------------------------------------------------------------
status("Scanning map objects...")
section("INTERACTIVES NEAR POINTS")
local POIS = {
	{ "Ice Castle", Vector3.new(6062, 155, -6880), 700 },
	{ "Cursed Ship", Vector3.new(900, 144, 33072), 700 },
	{ "Mysterious Man", Vector3.new(-2573, 1620, -3745), 300 },
	{ "Forgotten Island", Vector3.new(-3194, 155, -10795), 900 },
}
local found = 0
for i, d in ipairs(workspace:GetDescendants()) do
	if i % 20000 == 0 then task.wait() end
	if found >= 200 then break end
	local isInteractive = d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("TouchTransmitter")
	local nameHit = d:IsA("BasePart") and (d.Name:find("Key") or d.Name:find("Door") or d.Name:find("Rengoku") or d.Name:find("Hidden"))
	if isInteractive or nameHit then
		local part = isInteractive and d.Parent or d
		if part and part:IsA("BasePart") then
			for _, poi in ipairs(POIS) do
				if (part.Position - poi[2]).Magnitude <= poi[3] then
					found += 1
					local extra = d:IsA("ProximityPrompt") and (" action=" .. d.ActionText .. " object=" .. d.ObjectText) or ""
					add(poi[1], "|", d.ClassName, "|", d:GetFullName(), "|", fmtVec(part.Position), extra)
					break
				end
			end
		end
	end
end
add("found:", found)

section("NPCS OF INTEREST")
for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
	if folder then
		for _, n in ipairs(folder:GetChildren()) do
			local nm = n.Name
			if nm:find("Experimic") or nm:find("Mysterious") or nm:find("Legendary") or nm:find("Bartilo") or nm:find("Sword")
				or nm:find("Ectoplasm") or nm:find("Blackbeard") or nm:find("Trevor") or nm:find("Daigrock") then
				local pok, cf = pcall(function() return n:GetPivot() end)
				add(nm, "|", folder:GetFullName(), "|", pok and fmtVec(cf.Position) or "?")
			end
		end
	end
end

---------------------------------------------------------------------
local text = table.concat(out, "\n")
local copied = pcall(function() (setclipboard or toclipboard)(text) end)
status(("Done ✔  copied: %s  |  tell Claude 'copied'"):format(copied and "yes" or "no"))
print(text)
task.delay(20, function() gui:Destroy() end)
