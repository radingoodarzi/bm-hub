import pathlib, re, sys
hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
move = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\80_move.lua").read_text(encoding="utf-8")
bv = move[move.index("\tfunction Move.boatVelocity"):move.index("\tlocal function driveBoat")]
busy = hub[hub.index("local function mainFarmBusy()"):hub.index("\n---------------------------------------------------------------------\n-- Movement (tween + float)")]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__mul = function(a,s) return vec(a.X*s,a.Y*s,a.Z*s) end
vm.__index = function(v,k) local m = math.sqrt(v.X^2+v.Y^2+v.Z^2)
	if k=="Magnitude" then return m end if k=="Unit" then return vec(v.X/m,v.Y/m,v.Z/m) end end
local Vector3 = { new = vec }
local Move = {}
local S = {}
local Hub = {}
local Sea = 3
''' + bv + "\n" + busy + r'''
local v = Move.boatVelocity(vec(0, 0, -1), vec(0, 2, -20), 1, 200)
check("W pressed: boat pushed forward at Boat Speed, keeps its up/down", v and math.abs(v.Z + 200) < 0.01 and v.Y == 2 and v.X == 0)
v = Move.boatVelocity(vec(0, 0, -1), vec(0, 0, 0), -1, 150)
check("S pressed: backwards", v and math.abs(v.Z - 150) < 0.01)
check("no key: boat left alone", Move.boatVelocity(vec(0, 0, -1), vec(0, 0, -50), 0, 200) == nil)
check("already faster than the setting: not slowed down", Move.boatVelocity(vec(0, 0, -1), vec(0, 0, -300), 1, 200) == nil)
check("tilted seat: still flat on the water", (function() local r = Move.boatVelocity(vec(0, -0.5, -0.8), vec(0, 0, 0), 1, 100) return r and r.Y == 0 and math.abs(math.sqrt(r.X^2 + r.Z^2) - 100) < 0.01 end)())

S.AutoSea3 = true
check("Auto Sea 3 left on while already in Sea 3: not a running farm (walk speed works)", not anyFarm() and not mainFarmBusy())
Sea = 2
check("Auto Sea 3 in Sea 2: still counts (it is travelling)", anyFarm() and mainFarmBusy())
S.AutoSea3 = false; S.AutoSea2 = true; Sea = 2
check("Auto Sea 2 left on in Sea 2: not a running farm", not anyFarm())
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
