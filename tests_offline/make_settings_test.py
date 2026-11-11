import pathlib, sys
hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
block = hub[hub.index("local SHARED_SETTINGS"):hub.index("Hub.SaveSettings = saveSettings")]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local FILES = {}
local function isfile(f) return FILES[f] ~= nil end
local function readfile(f) if FILES[f] == nil then error("no file") end return FILES[f] end
local function writefile(f, d) FILES[f] = d end
-- tiny JSON for flat tables
local Svc = { Http = {
	JSONEncode = function(_, t) local p = {} for k, v in pairs(t) do p[#p+1] = string.format("%q:%s", k, type(v) == "string" and string.format("%q", v) or tostring(v)) end return "{" .. table.concat(p, ",") .. "}" end,
	JSONDecode = function(_, s) local t = {} for k, v in s:gmatch('"([^"]+)":([^,}]+)') do
		if v == "true" then t[k] = true elseif v == "false" then t[k] = false elseif tonumber(v) then t[k] = tonumber(v) else t[k] = v:sub(2, -2) end end return t end } }
local Hub = {}
local player = { UserId = 111 }
local S = { AutoClick = true, AttackMethod = "Auto", AutoFarm = false, Status = "" }
''' + block + r'''
FILES["BMHub_settings.json"] = '{"AutoClick":false,"AttackMethod":"Remote","AutoFarm":true}'
check("new account: takes the old shared settings", loadSettings() and S.AttackMethod == "Remote" and S.AutoFarm == true)
check("...but Auto Click stays ON even though the old file had it off", S.AutoClick == true)
S.AutoFarm = false; S.AutoClick = false
saveSettings()
check("saves into its own file, not the shared one", FILES["BMHub_settings_111.json"] ~= nil and FILES["BMHub_settings.json"]:find('"AutoFarm":true') ~= nil)
check("Auto Click is never written to the file", not FILES["BMHub_settings_111.json"]:find("AutoClick"))
S.AutoFarm = true; S.AutoClick = true
loadSettings()
check("same account next time: loads its own file", S.AutoFarm == false and S.AutoClick == true)
player.UserId = 222; SETTINGS_FILE = "BMHub_settings_222.json"
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
