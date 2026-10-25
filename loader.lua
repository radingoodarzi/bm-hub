--[[
	BM Hub Loader - همیشه آخرین نسخه رو می‌گیره و اگه خطا بود دقیق میگه کجاست
	loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader.lua"))()
]]

-- کش گیت‌هاب گاهی چند دقیقه نسخه‌ی قدیمی رو میده؛ با شناسه‌ی آخرین commit مستقیم جدیدترین رو می‌گیریم
local URL = "https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/bm_hub.lua?t=" .. tostring(os.time())
pcall(function()
	local body = game:HttpGet("https://api.github.com/repos/radingoodarzi/bm-hub/commits/main")
	local sha = body:match('"sha"%s*:%s*"(%x+)"')
	if sha then URL = "https://raw.githubusercontent.com/radingoodarzi/bm-hub/" .. sha .. "/bm_hub.lua" end
end)

local function note(text)
	print("[BM Hub loader] " .. text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hub", Text = text, Duration = 10 })
	end)
	pcall(function() (setclipboard or toclipboard)("[BM Hub loader] " .. text) end)
end

local ok, src = pcall(function() return game:HttpGet(URL) end)
if not ok or type(src) ~= "string" then
	return note("Download failed: " .. tostring(src):sub(1, 150))
end
if #src < 5000 or not src:find("BM Hub", 1, true) then
	return note("Bad download (" .. #src .. " bytes): " .. src:sub(1, 150))
end

local fn, err = loadstring(src)
if not fn then
	return note("Compile error: " .. tostring(err):sub(1, 200))
end

local runOk, runErr = pcall(fn)
if not runOk then
	note("Runtime error: " .. tostring(runErr):sub(1, 200))
end
