"""Offline test of bm.lua (fast local launcher)."""
import pathlib
import sys

src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm.lua").read_text(encoding="utf-8")

PRELUDE = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local function hubSource(v) return "-- BM Hub\nlocal Hub = { Version = \"" .. v .. "\" }\nRAN = (RAN or \"\") .. \"" .. v .. ";\"\n" .. string.rep("-- pad\n", 900) end
local function scenario(files, web)
	RAN, NOTES, DOWNLOADS = "", {}, 0
	local fs = files
	local env = {
		isfile = function(n) return fs[n] ~= nil end,
		readfile = function(n) return fs[n] end,
		writefile = function(n, c) fs[n] = c end,
		print = function() end,
		pcall = pcall, type = type, tostring = tostring, tonumber = tonumber, math = math, os = os, string = string,
		loadstring = function(s)
			if s:find("BROKEN", 1, true) then return nil, "syntax" end
			return function() RAN = RAN .. s:match('Version = "([^"]+)"') .. ";" end
		end,
		task = { spawn = function(fn) fn() end },
		game = {
			HttpGet = function(_, url) DOWNLOADS += 1; if web then return web end; error("Connection was reset") end,
			GetService = function() return { SetCore = function(_, _, t) table.insert(NOTES, t.Text) end } end,
		},
	}
	env.game.HttpGet = env.game.HttpGet
	local fn = loadstring(LAUNCHER)
	setfenv(fn, env)
	fn()
	return fs
end
'''

TESTS = r'''
local cache = hubSource("4.7")
local fs = scenario({ ["BMHub_cache.lua"] = cache }, hubSource("4.8"))
check("saved copy runs right away", RAN:find("4.7") == 1)
check("new version saved for next time, not run now", fs["BMHub_cache.lua"]:find('4.8', 1, true) ~= nil and RAN == "4.7;")
check("tells you an update is ready", NOTES[1] and NOTES[1]:find("4.8") ~= nil)

fs = scenario({ ["BMHub_cache.lua"] = cache }, cache)
check("same version online: no update message", #NOTES == 0 and RAN == "4.7;")

fs = scenario({ ["BMHub_cache.lua"] = cache }, nil)
check("internet down: saved copy still runs", RAN == "4.7;")

fs = scenario({}, hubSource("4.8"))
check("first run: downloads, saves and runs", RAN == "4.8;" and fs["BMHub_cache.lua"] ~= nil)

fs = scenario({}, nil)
check("first run without internet: clear message, nothing runs", RAN == "" and NOTES[#NOTES]:find("Download failed") ~= nil)

fs = scenario({ ["BMHub_cache.lua"] = "BROKEN " .. cache }, hubSource("4.8"))
check("broken saved copy: falls back to a fresh download", RAN == "4.8;")

fs = scenario({ ["BMHub_cache.lua"] = "tiny" }, hubSource("4.8"))
check("bad saved file is ignored", RAN == "4.8;")

-- what broke the dodge test: saved 5.7 (not pushed yet), GitHub still has 5.6
fs = scenario({ ["BMHub_cache.lua"] = hubSource("5.7") }, hubSource("5.6"))
check("newer saved copy is NOT replaced by an older GitHub copy", fs["BMHub_cache.lua"]:find("5.7", 1, true) ~= nil and RAN == "5.7;")
check("says it kept the saved copy", NOTES[1] and NOTES[1]:find("Keeping") ~= nil)
fs = scenario({ ["BMHub_cache.lua"] = hubSource("5.9") }, hubSource("5.10"))
check("5.10 counts as newer than 5.9", fs["BMHub_cache.lua"]:find("5.10", 1, true) ~= nil)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

out = pathlib.Path(sys.argv[1])
out.write_text("local LAUNCHER = [==========[" + src + "]==========]\n" + PRELUDE + TESTS, encoding="utf-8")
