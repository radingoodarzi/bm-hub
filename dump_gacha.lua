--[[
	BM Hub Gacha Scanner - نحوه‌ی کار خرید میوه‌ی رندوم (Gacha) رو پیدا می‌کنه و کپی می‌کنه
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_gacha.lua"))()
	هیچ خریدی انجام نمیده.
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

local gui = Instance.new("ScreenGui")
gui.Name = "BMGachaScanner"
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
	print("[BM Gacha Scanner] " .. t)
end

section("CAPS")
add("getconnections=", type(getconnections), "firesignal=", type(firesignal), "fireproximityprompt=", type(fireproximityprompt),
	"fireclickdetector=", type(fireclickdetector), "decompile=", type(decompile), "getsenv=", type(getsenv))

local function isGachaName(s)
	local l = s:lower()
	return l:find("gacha") or l:find("cousin") or l:find("randomfruit") or l:find("spin")
end

---------------------------------------------------------------------
status("Looking for gacha remotes and scripts...")
section("REMOTES")
for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
	if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and isGachaName(d.Name) then add(d.ClassName, d:GetFullName()) end
end

section("SCRIPTS")
local scripts = {}
for _, root in ipairs({ player:FindFirstChild("PlayerGui"), player:FindFirstChild("PlayerScripts"), ReplicatedStorage }) do
	if root then
		for _, d in ipairs(root:GetDescendants()) do
			if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and isGachaName(d:GetFullName()) then
				table.insert(scripts, d)
				add(d.ClassName, d:GetFullName())
			end
		end
	end
end

section("NPC")
for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
	local npc = folder and folder:FindFirstChild("Blox Fruit Gacha")
	if npc then
		local ok, cf = pcall(function() return npc:GetPivot() end)
		add("Blox Fruit Gacha |", folder:GetFullName(), "|", ok and tostring(cf.Position) or "?")
		for _, d in ipairs(npc:GetDescendants()) do
			if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("Dialog") or d:IsA("DialogChoice") then
				local extra = d:IsA("ProximityPrompt") and (" action=" .. d.ActionText .. " object=" .. d.ObjectText) or ""
				add("  ", d.ClassName, d:GetFullName(), extra)
			end
		end
	end
end

section("GACHA UI")
local pg = player:FindFirstChild("PlayerGui")
local uiCount = 0
if pg then
	for _, d in ipairs(pg:GetDescendants()) do
		if uiCount >= 80 then break end
		if (d:IsA("GuiButton") or d:IsA("ScreenGui")) and isGachaName(d:GetFullName()) then
			uiCount += 1
			local txt = d:IsA("TextButton") and (" text=" .. ("%q"):format(d.Text)) or ""
			local conns = ""
			if d:IsA("GuiButton") and getconnections then
				local ok, c = pcall(function() return #getconnections(d.Activated) .. "/" .. #getconnections(d.MouseButton1Click) end)
				conns = " conns(Activated/Click)=" .. (ok and c or "?")
			end
			add(d.ClassName, d:GetFullName():gsub("^.-PlayerGui%.", ""), "| visible:", d.Visible, txt, conns)
		end
	end
end

---------------------------------------------------------------------
-- همین الان کپی می‌کنیم که اگه decompile گیر کرد، اطلاعات از دست نره
local function copyNow(final)
	local text = table.concat(out, "\n")
	local copied = pcall(function() (setclipboard or toclipboard)(text) end)
	return copied, text
end
copyNow()
status("Part 1 copied ✔  Now decompiling small gacha scripts...")

section("DECOMPILE")
local KEYS = { "FireServer", "InvokeServer", "Gacha", "Cousin", "Spin", "Buy", "Roll" }
local MAX_BYTECODE = 25000 -- اسکریپت‌های بزرگ decompile رو قفل می‌کنن
local started = os.clock()
if type(decompile) == "function" then
	for i, s in ipairs(scripts) do
		if os.clock() - started > 60 then
			add("(time limit reached)")
			break
		end
		local size = -1
		pcall(function() size = #getscriptbytecode(s) end)
		if size > MAX_BYTECODE or size == 0 then
			add("--- skip (bytecode " .. size .. "): " .. s:GetFullName())
			continue
		end
		status(("Decompiling %d/%d: %s (%d bytes)"):format(i, #scripts, s.Name, size))
		task.wait()
		local ok, src = pcall(decompile, s)
		if ok and type(src) == "string" then
			add("--- " .. s:GetFullName() .. " (" .. #src .. " chars)")
			local lines = src:split("\n")
			local shown = 0
			for ln, line in ipairs(lines) do
				for _, k in ipairs(KEYS) do
					if line:find(k, 1, true) then
						shown += 1
						add(("[%d] %s"):format(ln, line:gsub("^%s+", ""):sub(1, 240)))
						break
					end
				end
				if shown >= 60 then break end
			end
		else
			add("--- " .. s:GetFullName() .. " decompile failed: " .. tostring(src))
		end
		copyNow()
	end
end

local copied, text = copyNow()
status(("Done ✔  copied: %s  |  tell Claude 'copied'"):format(copied and "yes" or "no"))
print(text)
task.delay(20, function() gui:Destroy() end)
