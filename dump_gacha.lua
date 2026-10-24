--[[
	BM Hub Gacha Scanner v2 - سریع، بدون decompile. هیچ خریدی انجام نمیده.
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/dump_gacha.lua?t=" .. os.time()))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM GACHA SCAN v2 ==" }
local function add(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	table.insert(out, table.concat(parts, " "))
end
local function copyNow()
	return pcall(function() (setclipboard or toclipboard)(table.concat(out, "\n")) end)
end

local okRun, runErr = pcall(function()
	add("caps: getconnections=", type(getconnections), "firesignal=", type(firesignal), "getconstants=", type(getconstants),
		"debug.getconstants=", type(debug.getconstants), "getupvalues=", type(getupvalues), "fireproximityprompt=", type(fireproximityprompt))
	copyNow()

	local function isGacha(s)
		local l = s:lower()
		return l:find("gacha") or l:find("cousin") or l:find("spin") or l:find("roll")
	end

	add("--- remotes")
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and isGacha(d.Name) then add(d.ClassName, d:GetFullName()) end
	end
	copyNow()

	add("--- npc")
	for _, folder in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
		local npc = folder and folder:FindFirstChild("Blox Fruit Gacha")
		if npc then
			add("Blox Fruit Gacha in", folder:GetFullName())
			for _, d in ipairs(npc:GetDescendants()) do
				if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then add("  ", d.ClassName, d:GetFullName()) end
			end
		end
	end
	copyNow()

	-- ثابت‌های رشته‌ای تابع‌های وصل به دکمه (بدون decompile)
	local getK = getconstants or (debug and debug.getconstants)
	local function dumpFunction(fn, indent)
		if not getK then return end
		local ok, consts = pcall(getK, fn)
		if ok and type(consts) == "table" then
			local strs = {}
			for _, c in pairs(consts) do
				if type(c) == "string" and #c < 60 then table.insert(strs, c) end
			end
			add(indent .. "consts:", table.concat(strs, " | "))
		end
	end

	add("--- gacha ui (open the gacha menu before scanning!)")
	local pg = player:FindFirstChild("PlayerGui")
	local n = 0
	for _, d in ipairs(pg:GetDescendants()) do
		if n >= 60 then break end
		if d:IsA("GuiButton") and isGacha(d:GetFullName()) then
			n += 1
			local txt = d:IsA("TextButton") and (" text=" .. ("%q"):format(d.Text)) or ""
			add(d.ClassName, (d:GetFullName():gsub("^.-PlayerGui%.", "")), "| visible:", d.Visible, txt)
			if getconnections then
				for _, sig in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
					local ok, conns = pcall(getconnections, d[sig])
					if ok and type(conns) == "table" and #conns > 0 then
						add("   " .. sig .. " connections:", #conns)
						for _, c in ipairs(conns) do
							local fn = c.Function or (type(c) == "table" and c.func)
							if fn then dumpFunction(fn, "     ") end
						end
					end
				end
			end
			copyNow()
		end
	end
	add("gacha buttons found:", n)
end)

if not okRun then add("SCAN ERROR:", runErr) end
local copied = copyNow()
print(table.concat(out, "\n"))
print("[BM Gacha Scanner] done, copied:", copied)
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Gacha Scanner", Text = copied and "Done ✔ copied - tell Claude" or "Done, check F9", Duration = 8 })
end)
