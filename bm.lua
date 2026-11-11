--[[
	BM Hub - لانچر سریع (فایل محلی توی workspace خود Solara)
	loadstring(readfile("bm.lua"))()

	دانلود از GitHub توی Solara گاهی 20 ثانیه گیر می‌کنه (Curl: Connection was reset).
	این لانچر نسخه‌ی ذخیره‌شده رو بدون اینترنت همون لحظه اجرا می‌کنه و همزمان نسخه‌ی جدید رو
	بی‌صدا می‌گیره و برای دفعه‌ی بعد ذخیره می‌کنه (وسط بازی هاب رو عوض نمی‌کنه).
]]

local CACHE = "BMHub_cache.lua"
local URL = "https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/bm_hub_v3.lua"

local function note(text)
	print("[BM Hub] " .. text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hub", Text = text, Duration = 8 })
	end)
end

local function version(src) return src and src:match('Version = "([%d%.]+)"') or "?" end
-- "5.10" > "5.9": عدد به عدد مقایسه میشه
local function newer(a, b)
	local x, y = {}, {}
	for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
	for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
	for i = 1, math.max(#x, #y) do
		if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
	end
	return false
end
local function valid(src) return type(src) == "string" and #src > 5000 and src:find("BM Hub", 1, true) ~= nil end

-- کش گیت‌هاب گاهی نسخه‌ی قدیمی رو میده؛ با شناسه‌ی آخرین commit مستقیم جدیدترین رو می‌گیریم (مثل loader_v3)
local function download()
	local url = URL .. "?t=" .. tostring(os.time())
	pcall(function()
		local body = game:HttpGet("https://api.github.com/repos/radingoodarzi/bm-hub/commits/main")
		local sha = body:match('"sha"%s*:%s*"(%x+)"')
		if sha then url = "https://raw.githubusercontent.com/radingoodarzi/bm-hub/" .. sha .. "/bm_hub_v3.lua" end
	end)
	local ok, src = pcall(function() return game:HttpGet(url) end)
	if ok and valid(src) then return src end
end

local function run(src, from)
	local fn, err = loadstring(src)
	if not fn then
		note(from .. ": compile error " .. tostring(err):sub(1, 150))
		return false
	end
	local ok, runErr = pcall(fn)
	if not ok then note(from .. ": runtime error " .. tostring(runErr):sub(1, 150)) end
	return true
end

local cached
pcall(function() if isfile(CACHE) then cached = readfile(CACHE) end end)

if valid(cached) then
	-- آپدیت توی پس‌زمینه؛ نسخه‌ی جدید از اجرای بعدی استفاده میشه
	task.spawn(function()
		local fresh = download()
		if not fresh then
			note(("Couldn't check for updates (running saved v%s)"):format(version(cached)))
		elseif newer(version(cached), version(fresh)) then
			-- نسخه‌ی ذخیره‌شده جدیدتره (مثلاً تست قبل از push): با نسخه‌ی قدیمی GitHub عوضش نکن
			note(("Keeping saved v%s (GitHub has older v%s)"):format(version(cached), version(fresh)))
		elseif fresh ~= cached then
			pcall(writefile, CACHE, fresh)
			note(("Update v%s downloaded - to use it: Settings > Destroy Hub, then run again"):format(version(fresh)))
		end
	end)
	if run(cached, "saved v" .. version(cached)) then return end
end

note("Downloading BM Hub (first time can take a bit)...")
local fresh = download()
if not fresh then return note("Download failed - check your internet and run again") end
pcall(writefile, CACHE, fresh)
run(fresh, "v" .. version(fresh))
