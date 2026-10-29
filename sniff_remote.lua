--[[
	BM Hub - شنود RegisterAttack / RegisterHit (فقط لاگ، چیزی تغییر نمیده و نمیفرسته)
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/sniff_remote.lua?t=" .. os.time()))()

	ملی یا شمشیر بگیر دستت، بعد از اجرا 8-10 تا M1 معمولی به یه ماب بزن (چندتاش از کمی دورتر).
	خودش بعد از 8 ضربه یا 60 ثانیه گزارش رو میفرسته. روی صفحه هم نشون میده.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local out = { "== BM REMOTE SNIFFER ==" }
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

local function upload(title)
	local text = table.concat(out, "\n")
	pcall(function() writefile("bmscan/sniff.txt", text) end)
	pcall(function() setclipboard(text) end)
	local req = (syn and syn.request) or http_request or request or (http and http.request)
	if req then
		pcall(req, {
			Url = "https://ntfy.sh/bmhub-4628905e9720ae22ecf77f9b",
			Method = "POST",
			Headers = { ["Title"] = title },
			Body = text:sub(1, 3800),
		})
	end
	pcall(function()
		local old = player.PlayerGui:FindFirstChild("BMSniff")
		if old then old:Destroy() end
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.ResetOnSpawn = "BMSniff", false
		gui.Parent = player.PlayerGui
		local box = Instance.new("TextBox")
		box.Size, box.Position = UDim2.new(0.9, 0, 0.5, 0), UDim2.new(0.05, 0, 0.05, 0)
		box.BackgroundColor3, box.TextColor3 = Color3.fromRGB(20, 20, 24), Color3.fromRGB(235, 235, 235)
		box.TextXAlignment, box.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		box.TextSize, box.Font = 13, Enum.Font.Code
		box.ClearTextOnFocus, box.MultiLine, box.TextWrapped = false, true, true
		box.Text = text
		box.Parent = gui
		local close = Instance.new("TextButton")
		close.Size, close.Position = UDim2.new(0, 70, 0, 30), UDim2.new(0.95, -70, 0.05, -34)
		close.Text, close.Parent = "Close", gui
		close.MouseButton1Click:Connect(function() gui:Destroy() end)
	end)
end

local function findRemote(key)
	local hit
	pcall(function()
		for _, d in ipairs(ReplicatedStorage.Modules.Net:GetDescendants()) do
			if d:IsA("RemoteEvent") and d.Name:find(key, 1, true) then hit = d end
		end
	end)
	return hit
end

local RH, RA = findRemote("RegisterHit"), findRemote("RegisterAttack")
add("exec:", (identifyexecutor and identifyexecutor()) or "?", " uid:", player.UserId)
add("RegisterHit:", RH and RH:GetFullName() or "nil", " RegisterAttack:", RA and RA:GetFullName() or "nil")
add("hookmetamethod:", typeof(hookmetamethod), " hookfunction:", typeof(hookfunction), " getnamecallmethod:", typeof(getnamecallmethod))

local nHit, nAtk, lastAtk = 0, 0, nil
local sent = false

local function record(self, args)
	local isHit = rawequal(self, RH)
	if isHit then nHit += 1 else nAtk += 1 end
	if (isHit and nHit > 12) or (not isHit and nAtk > 12) then return end
	local now = os.clock()
	local parts = {}
	for i = 1, args.n do parts[#parts + 1] = ser(args[i]) end
	local extra = ""
	pcall(function()
		local root = player.Character.HumanoidRootPart
		local bestD, bestM
		for _, m in ipairs(workspace.Enemies:GetChildren()) do
			local hrp, hum = m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - root.Position).Magnitude
				if not bestD or d < bestD then bestD, bestM = d, m end
			end
		end
		if bestM then extra = ("  nearest=%s d=%.1f"):format(bestM.Name, bestD) end
	end)
	local gap = lastAtk and ("  +%.3fs after attack"):format(now - lastAtk) or ""
	if not isHit then lastAtk = now end
	add(("[%s #%d] n=%d%s%s"):format(isHit and "HIT" or "ATK", isHit and nHit or nAtk, args.n, extra, isHit and gap or ""))
	add("  args: " .. table.concat(parts, " | "))
	if nHit >= 8 and not sent then
		sent = true
		add("== 8 hits captured ==")
		upload("sniff-remote")
	end
end

local installed
if hookmetamethod and getnamecallmethod and RH then
	local okH, errH = pcall(function()
		local old
		old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(function(self, ...)
			if getnamecallmethod() == "FireServer" and (rawequal(self, RH) or rawequal(self, RA)) then
				local args = table.pack(...)
				task.defer(record, self, args)
			end
			return old(self, ...)
		end) or function(self, ...)
			if getnamecallmethod() == "FireServer" and (rawequal(self, RH) or rawequal(self, RA)) then
				local args = table.pack(...)
				task.defer(record, self, args)
			end
			return old(self, ...)
		end)
	end)
	installed = okH and "hookmetamethod/__namecall" or nil
	if not okH then add("hookmetamethod failed:", errH) end
end
if not installed and hookfunction and RH then
	local okF, errF = pcall(function()
		local old
		old = hookfunction(RH.FireServer, function(self, ...)
			if rawequal(self, RH) or rawequal(self, RA) then
				local args = table.pack(...)
				task.defer(record, self, args)
			end
			return old(self, ...)
		end)
	end)
	installed = okF and "hookfunction/FireServer" or nil
	if not okF then add("hookfunction failed:", errF) end
end
add("hook:", installed or "NONE")

pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Sniffer", Text = installed and "Hit a mob with M1 (8+ hits)" or "Hook failed - see report", Duration = 6 })
end)
if not installed then
	upload("sniff-remote")
	return
end

task.delay(60, function()
	if sent then return end
	sent = true
	add("== timeout: hits=" .. nHit .. " attacks=" .. nAtk .. " ==")
	upload("sniff-remote")
end)
