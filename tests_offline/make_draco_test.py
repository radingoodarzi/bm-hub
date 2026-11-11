"""Offline test of v3_src/90_draco.lua: pure decide() and a full V2 -> V3 run against a fake Dragon Wizard."""
import pathlib
import sys

src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\90_draco.lua").read_text(encoding="utf-8")
head = src.split("--@@UI@@")[0]

PRELUDE = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local NOW = 0
local function tick() return NOW end
local function V(x, y, z) return { X = x, Y = y, Z = z } end
local function sub(a, b) return { Magnitude = math.sqrt((a.X-b.X)^2 + (a.Y-b.Y)^2 + (a.Z-b.Z)^2) } end
local vmeta = { __sub = function(a, b) return sub(a, b) end }
local function vec(x, y, z) return setmetatable(V(x, y, z), vmeta) end
local CFrame = { new = function() return {} end }
local Sea = 3
local S = { Status = "" }
local Hub = { Running = true, V3 = {} }
local V3 = Hub.V3
local logs, notes = {}, {}
V3.log = function(m) table.insert(logs, m) end
V3.notify = function(t, m) table.insert(notes, m) end
V3.webhook = function() end
V3.activate = function(p) p.Enabled = false; p.Parent = nil; return true end
local steps = {}
V3.register = function(flag, step) steps[flag] = step end
local root = { Position = vec(0, 0, 0) }
local function getRoot() return root end
local function tweenTo(cf) root.Position = cf.__pos or root.Position end
local npc = { Position = vec(1000, 0, 0) }
npc.CFrame = setmetatable({ __pos = npc.Position }, { __mul = function(a) return { __pos = npc.Position } end })
V3.npcPart = function(n) return n == "Dragon Wizard" and npc or nil end
local farmed = 0
V3.farmMobs = function(names) farmed += 1; return names[1] == "Forest Pirate" end
local sharkSteps = 0
V3.sharkStep = function() sharkSteps += 1; S.Status = "Sea Event: Terrorshark" end
local RACE, HAVE = "Draco", {}
local function dataValue(n) return n == "Race" and RACE or nil end
local function hasItem(n) return HAVE[n] == true end
-- fake server: Speak returns the quest state
local SERVER = { q = "V2", calls = {} }
local Net = { FindFirstChild = function(_, n)
	if n ~= "RF/InteractDragonQuest" then return nil end
	return { InvokeServer = function(_, a)
		table.insert(SERVER.calls, a.Command .. (a.Action and (":" .. a.Action) or ""))
		if a.Command == "Speak" then return { AvailableVQuest = SERVER.q } end
		if a.Action == "Begin" then SERVER.q = SERVER.q .. "InProgress" end
		if a.Action == "Complete" then
			if SERVER.q == "V2InProgress" and SERVER.flowers >= 5 then SERVER.q = "V3" end
			if SERVER.q == "V3InProgress" and SERVER.shark then SERVER.q = "Done" end
			if SERVER.q:find("TurnInReady") then SERVER.q = SERVER.q:sub(1, 2) == "V2" and "V3" or "Done" end
		end
	end }
end }
SERVER.flowers = 0
local workspace = { GetDescendants = function() return {} end, DescendantAdded = { Connect = function() return { Disconnect = function() end } end } }
local task = { wait = function(s) NOW += (s or 0.03) end, spawn = function() end, defer = function(f) f() end }
local function logError(w, e) print("MODULE ERROR", w, e); fails += 1 end
'''

TESTS = r'''
local D = V3.Draco
check("not Draco race", D.decide({ race = "Human" }) == "notDraco")
check("already V3", D.decide({ race = "Draco", done = true }) == "done")
check("unknown state -> speak", D.decide({ race = "Draco" }) == "speak")
check("V2 offered -> begin", D.decide({ race = "Draco", quest = "V2" }) == "begin")
check("V2 in progress, 2 flowers -> flowers", D.decide({ race = "Draco", quest = "V2InProgress", flowers = 2 }) == "flowers")
check("V2 in progress, 5 flowers -> complete", D.decide({ race = "Draco", quest = "V2InProgress", flowers = 5 }) == "complete")
check("V3 shark not killed -> shark", D.decide({ race = "Draco", quest = "V3InProgress", sharkKills = 3, sharkBase = 3 }) == "shark")
check("V3 shark killed -> complete", D.decide({ race = "Draco", quest = "V3InProgress", sharkKills = 4, sharkBase = 3 }) == "complete")
check("turn-in ready -> complete", D.decide({ race = "Draco", quest = "V3TurnInReady" }) == "complete")

-- full run
S.AutoDraco = true
local keep = function() return S.AutoDraco end
local step = steps.AutoDraco
local function run(n, hook) for i = 1, n do if not S.AutoDraco then break end; if hook then hook(i) end; step(keep) end end
run(3)
check("walks to the wizard, then begins V2", table.find(SERVER.calls, "Ascension:Begin") ~= nil and D.state.quest == "V2InProgress")
-- no flowers in the world yet: farms Forest Pirates
local f0 = farmed
run(3)
check("no flower -> farms Forest Pirates", farmed > f0 and S.Status:find("Forest Pirates") ~= nil)
-- flowers appear: picks them
D.state.flowers = 0
for i = 1, 5 do SERVER.flowers += 1; D.state.flowers += 1 end
run(2)
check("5 flowers -> turns in, server moves to V3", SERVER.q == "V3" or SERVER.q == "V3InProgress")
run(3)
check("begins V3", SERVER.q == "V3InProgress" and D.state.quest == "V3InProgress")
local s0 = sharkSteps
run(3)
check("V3 -> hunts a Terrorshark with the sea engine", sharkSteps > s0 and S.Status:find("^Draco V3") ~= nil)
V3.sharkKills = (V3.sharkKills or 0) + 1
SERVER.shark = true
run(3)
check("shark killed -> turns in V3", SERVER.q == "Done")
check("then stops itself (wizard has nothing)", S.AutoDraco == false)
print("notes: " .. table.concat(notes, " | "))

-- complete that the server refuses: flower count drops to 4 and it keeps picking
SERVER.q, SERVER.flowers = "V2InProgress", 0
D.state.quest, D.state.flowers = "V2InProgress", 5
S.AutoDraco = true
run(1)
check("refused turn-in -> back to collecting", D.state.flowers == 4 and D.state.quest == "V2InProgress")

RACE = "Human"; S.AutoDraco = true; run(1)
check("wrong race -> turns itself off", S.AutoDraco == false)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

body = head.replace("\tlocal V3 = Hub.V3\n", "\tlocal V3 = Hub.V3\n", 1)
pathlib.Path(sys.argv[1]).write_text(PRELUDE + body + TESTS, encoding="utf-8")
