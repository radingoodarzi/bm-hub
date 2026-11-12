"""بعد از هاپ هاب فقط یه بار اجرا میشه، هر چند بار هم صف شده باشه (متن واقعی LOADER از bm_hub_v3.lua)."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
a = hub.index("\tlocal LOADER = ")
b = hub.index("\tlocal queueTp = queue_on_teleport", a)
loader = hub[a:b]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
RUNS = 0
local GENV = {}
getgenv = function() return GENV end
readfile = function(f) if f == "bm.lua" then return "RUNS += 1" end error("no file " .. f) end
local function isfile(f) return f == "bm.lua" end
local Hub = {} -- 5.10: بدون کلید، KeyLoader نیست و مثل قبل bm.lua
local function pcall2(f, ...) return pcall(f, ...) end
''' + loader + r'''
local QUEUE = {}
local function queue(s) table.insert(QUEUE, s) end
local function arrive()
	GENV = {}
	for _, s in ipairs(QUEUE) do loadstring(s)() end
	QUEUE = {}
end

check("queued text still starts the hub from bm.lua", LOADER:find('loadstring(readfile("bm.lua"))()', 1, true) ~= nil)
queue(LOADER); queue(LOADER)
arrive()
check("Join Job + Restart After Teleports both queued: hub runs once", RUNS == 1)
queue(LOADER); queue(LOADER); queue(LOADER)
arrive()
check("next hop (new server, fresh state): runs once again", RUNS == 2)
queue(LOADER)
arrive()
check("queued once: runs once", RUNS == 3)
GENV = {}
loadstring(LOADER)()
loadstring('loadstring(readfile("bm.lua"))()')()
check("you running bm.lua yourself is never blocked", RUNS == 5)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
