"""اسکریپت فقط یه بار اجرا میشه؛ اجرای دوم متوقف میشه (کد واقعی شروع bm_hub_v3.lua)."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
a = hub.index("local genv = (getgenv and getgenv()) or _G\n")
b = hub.index("genv.BMHub = Hub\n", a) + len("genv.BMHub = Hub\n")
start = hub[a:b]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
NOW = 1000
tick = function() return NOW end
GENV = {}
getgenv = function() return GENV end
NOTES = {}
game = { GetService = function() return { SetCore = function(_, _, t) table.insert(NOTES, t.Text) end } end }
STARTS = 0
local START = [==[
''' + start + r''']==]
-- each "run" = the real start code + the hub counting itself as started
local function run()
	local f = assert(loadstring(START .. "\nSTARTS += 1\nreturn Hub"))
	return f()
end
local function finishLoading(h) h.Loaded = true end
local function destroy(h) h.Running = false end

local h1 = run()
check("first run starts the hub", STARTS == 1 and GENV.BMHub == h1)
finishLoading(h1)
local h2 = run()
check("second run while it is running: stopped", STARTS == 1 and h2 == nil and GENV.BMHub == h1)
check("...and it says why (and how to restart)", NOTES[#NOTES]:find("Already running", 1, true) ~= nil and NOTES[#NOTES]:find("Destroy Hub", 1, true) ~= nil)
check("the first hub keeps running", h1.Running == true)
NOW += 3600
run()
check("an hour later it is still blocked", STARTS == 1)

destroy(h1)
local h3 = run()
check("after Destroy Hub: runs again", STARTS == 2 and GENV.BMHub == h3)

-- two runs at almost the same moment (the second starts while the first is still loading)
GENV = {}
STARTS = 0
local a1 = run()
NOW += 5
run()
check("double start while still loading: second stopped", STARTS == 1)

-- a hub that crashed while loading (never finished) does not block forever
NOW += 120
local a3 = run()
check("hub that crashed 2 minutes ago while loading: a new run replaces it", STARTS == 2 and GENV.BMHub == a3 and a1.Running == true)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
