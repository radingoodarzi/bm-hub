import pathlib, sys
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\97_ken.lua").read_text(encoding="utf-8")
mod = src[:src.index("--@@UI@@")]
P = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local NOW = 0
local function tick() return NOW end
local os = { time = function() return 1000 end }
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local Vector3 = { new = vec }
local cm = {}
local function cf(p) return setmetatable({Position=p}, cm) end
cm.__mul = function(a,b) return cf(a.Position + b.Position) end
local CFrame = { new = function(x,y,z) if type(x)=="table" then return cf(x) end return cf(vec(x,y,z)) end }
local Enum = { KeyCode = { E = "E" } }
local FILES = {}
local function isfile(n) return FILES[n] ~= nil end
local function readfile(n) return FILES[n] end
local function writefile(n, s) FILES[n] = s end
local JSON = {}
local TP_CALLS, TP_FAIL_CB, TP_SHOULD_FAIL = {}, nil, true
local SERVERS = { { id = "full", playing = 12, maxPlayers = 12 }, { id = "busy", playing = 9, maxPlayers = 12 },
	{ id = "empty1", playing = 1, maxPlayers = 12 }, { id = "job-123", playing = 1, maxPlayers = 12 }, { id = "two", playing = 2, maxPlayers = 12 } }
local game = { PlaceId = 7449423635, JobId = "job-123", HttpGet = function() return "LIST" end }
local HOPS = 0
local function serverHop(lowest) HOPS += 1; if TP_SHOULD_FAIL and TP_FAIL_CB then TP_FAIL_CB(player) end; return true end
local Svc = { Teleport = {
	TeleportInitFailed = { Connect = function(_, f) TP_FAIL_CB = f end },
	TeleportToPlaceInstance = function(_, place, job, plr) table.insert(TP_CALLS, { place, job }); if TP_SHOULD_FAIL and TP_FAIL_CB then TP_FAIL_CB(plr) elseif not TP_SHOULD_FAIL then LEAVE() end end },
	Http = { JSONEncode = function(_, t) local id = #JSON + 1; JSON[id] = t; return "J" .. id end,
	JSONDecode = function(_, s) if s == "LIST" then return { data = SERVERS } end local v = JSON[tonumber(s:sub(2))]; local c = {} for k, x in pairs(v) do c[k] = type(x)=="table" and table.clone(x) or x end return c end } }
local player = { UserId = 111 }
local S = { Status = "" }
local Hub = { Running = true, V3 = {} }
function LEAVE() Hub.Running = false end
local QUEUED = 0
Hub.QueueReload = function() QUEUED += 1 end
Hub.ReloadFailed = function() end
local notes = {}
local tasks = {}
Hub.V3.register = function(flag, step) if S[flag] == nil then S[flag] = false end tasks[flag] = step end
Hub.V3.notify = function(t, m) table.insert(notes, m) end
Hub.V3.webhook = function() end
local keys = 0
Hub.V3.key = function(k) keys += 1; if KEN_FULL then BLUR.Enabled = true end end
local POINTS = 1200
local function invoke(a, b) if a == "KenTalk" and b == "Status" then return "You have " .. POINTS .. " points" end end
BLUR = { Enabled = false }
KEN_FULL = true
local Lighting = { FindFirstChild = function(_, n) if n == "Blur" then return BLUR end end }
local HP = 100
local function getHum() return { Health = HP, MaxHealth = 100 } end
local root = { Position = vec(0, 0, 0) }
setmetatable(root, { __newindex = function(t, k, v) if k == "CFrame" then rawset(t, "Position", v.Position) end end })
local function getRoot() return root end
local function alive() return true end
local mob = { Name = "Marine Commodore", Parent = true, HumanoidRootPart = { Position = vec(10, 0, 0), CFrame = cf(vec(10, 0, 0)) } }
local function isAliveMob(m) return m.Parent end
local function mobBaseName(n) return n end
local other = { Name = "Pirate Millionaire", Parent = true, HumanoidRootPart = { Position = vec(2, 0, 0), CFrame = cf(vec(2, 0, 0)) } }
local MOBS = { other, mob }
local workspace = { FindFirstChild = function(_, n) if n == "Enemies" then return { GetChildren = function() return MOBS end } end end }
local Sea = 3
local floating
local function setFloat(v) floating = v end
local function tweenTo(c) root.Position = c.Position end
local function logError(w, e) print("ERR", w, e); fails += 1 end
local HANG = false
local function mobSpawn(n) if n == "Monkey" then return cf(vec(500, 0, 0)) end end
local task = { spawn = function(f) if not HANG then f() end end, wait = function(s) NOW += (s or 0.03)
	-- while on: each tick of standing next to the mob = 1 dodge; after 30 dodges Ken runs out
	if BLUR.Enabled and (root.Position - mob.HumanoidRootPart.Position).Magnitude < 5 then
		if KEN_COUNTS ~= false then POINTS += 1 end; DODGES_THIS_BAR = (DODGES_THIS_BAR or 0) + 1
		if DODGES_THIS_BAR >= 30 then BLUR.Enabled = false; DODGES_THIS_BAR = 0 end
	end
end }
'''
T = r'''
local Ken = Hub.V3.Ken
check("parse: digits only (Banana)", Ken.parse("Observation: 4,321") == 4321 and Ken.parse(nil) == nil)
local pr = Ken.progress({ start = 1000, goal = 1000 }, 1650)
check("progress: done 650, left 350", pr.done == 650 and pr.left == 350 and not pr.finished)
check("progress: finished at goal", Ken.progress({ start = 1000, goal = 1000 }, 2000).finished)
local base = { finished = false, kenOn = false, hpFrac = 1, now = 10, restUntil = 0, resting = false }
local function d(t) local c = table.clone(base) for k, v in pairs(t) do c[k] = v end return Ken.decide(c) end
check("decide: Ken on -> dodge", d({ kenOn = true }) == "dodge")
check("decide: Ken off and refilled -> turn on", d({}) == "turnOn")
check("decide: refill time not over -> rest", d({ restUntil = 20, resting = true }) == "rest")
check("decide: low HP -> rest even with Ken on", d({ kenOn = true, hpFrac = 0.2 }) == "rest")
check("decide: done -> finish", d({ finished = true, kenOn = true }) == "finish")
check("decide: Blur turns on mid-refill -> still waits (real log bug)", d({ kenOn = true, resting = true, restUntil = 20 }) == "rest")
check("decide: refill over and Ken on -> dodge", d({ kenOn = true, resting = true, restUntil = 5 }) == "dodge")

-- job is per account and survives a rejoin
check("no job yet", Ken.job() == nil)
check("bad input refused", Ken.newJob("abc") == false)
check("new job 100 dodges", Ken.newJob("100") == true and Ken.job().start == 1200 and Ken.job().goal == 100)
player.UserId = 222
check("other account sees no job", Ken.job() == nil)
player.UserId = 111
check("same account still has it (rejoin)", Ken.job() and Ken.job().goal == 100)

-- full run: dodge, Ken runs out, rest, turn on again, until 100 dodges
S.KenFarm = true
S.KenRest = 5
local step = tasks.KenFarm
local sawRest, sawDodge, attackHeld = false, false, false
for i = 1, 400 do
	if not S.KenFarm then break end
	step(function() return S.KenFarm end)
	if S.Status:find("refilling") then sawRest = true end
	if S.Status:find("dodging") then sawDodge = true end
	if (Hub.HoldAttackUntil or 0) > NOW then attackHeld = true end
	task.wait(0.1)
end
local job = Ken.job()
check("dodged next to the Marine Commodore", sawDodge)
check("rested while Ken refilled", sawRest)
check("pressed E to turn Ken back on", keys >= 3)
check("Auto Click was held while dodging", attackHeld)
check("stopped by itself at 100 dodges", S.KenFarm == false and POINTS - 1200 >= 100 and job.doneAt ~= nil)
check("told you it is done", notes[#notes]:find("Done") ~= nil)
check("Auto Click released at the end", (Hub.HoldAttackUntil or 0) == 0)
print("status: " .. S.Status)

-- low HP: goes up out of reach
S.KenFarm = true
Ken.newJob("50")
HP = 20
BLUR.Enabled = true
step(function() return true end)
check("low HP: rests 300 above the mob", root.Position.Y >= 299 and floating == true)
check("picked the Marine Commodore, not the closer Pirate Millionaire", S.Status:find("healing") ~= nil and root.Position.X == 10)
-- server never answers: the job must not freeze
HP = 100
HANG = true
NOW += 10
local t0 = NOW
step(function() return true end)
check("server not answering: step still returns quickly", NOW - t0 < 8)
HANG = false
-- Sea 1: only Monkeys; none loaded -> flies to the Monkey spawn
Sea = 1
MOBS = { other }
step(function() return true end)
check("Sea 1 wants Monkeys and flies to their spawn", S.Status:find("Monkeys") ~= nil and root.Position.X == 500 and root.Position.Y == 60)
check("best mobs: Monkey / Zombie / Marine Commodore", Ken.bestFor(1).name == "Monkey" and Ken.bestFor(2).name == "Zombie" and Ken.bestFor(3).name == "Marine Commodore")
-- Blur stuck on (other effect) but no dodges count: must not keep diving, goes to rest
Sea = 3
MOBS = { mob }
S.KenFarm = true
Ken.newJob("50")
HP = 100
BLUR.Enabled = true
KEN_COUNTS = false
root.Position = vec(10, 0, 3)
local function stepOnce() step(function() return true end) end
-- make dodges not count: freeze POINTS while Blur is on
local savedP = POINTS
stepOnce()
POINTS = savedP
check("Blur on but no dodge counted for 6s -> rests instead of diving again", S.KenFarm and (function() stepOnce() return S.Status:find("refilling") ~= nil end)())
check("floats next to the mob (no bouncing)", floating == true)

-- pure server picking
local picks = Ken.pickServers(SERVERS, { "empty1" }, "job-123")
check("server pick: emptiest first, skips current/full/visited", #picks == 2 and picks[1].id == "two" and picks[2].id == "busy")

-- Ken runs out -> straight to the emptiest NEW server (not this one)
KEN_COUNTS = true
BLUR.Enabled = true
DODGES_THIS_BAR = 0
HP = 100
Ken.newJob("500")
S.KenFarm, S.KenRejoin = true, true
TP_CALLS = {}
TP_SHOULD_FAIL = false
NOW += 100
for i = 1, 30 do step(function() return true end); if #TP_CALLS > 0 then break end end
Hub.Running = true
check("joins the emptiest server, never the same one", TP_CALLS[1] and TP_CALLS[1][2] == "empty1")
check("visited servers saved (current + target) and change counted", Ken.job().rejoins >= 1 and table.find(Ken.job().visited, "empty1") and table.find(Ken.job().visited, "job-123"))

-- next time: empty1 already visited -> goes to "two"
TP_CALLS = {}
Ken.rejoinOff = false
local j = Ken.job(); j.lastRejoin = 0; Ken.saveJob(j)
Ken.rejoin(Ken.job())
Hub.Running = true
check("doesn't go back to a visited server", TP_CALLS[1] and TP_CALLS[1][2] == "two")

-- every teleport fails -> tries up to 4, then waits for refill
TP_CALLS = {}
Ken.rejoinOff = false
j = Ken.job(); j.lastRejoin = 0; j.visited = {}; Ken.saveJob(j)
TP_SHOULD_FAIL = true
Ken.rejoin(Ken.job())
check("teleport keeps failing -> tries the other servers", #TP_CALLS == 3)
check("all failed -> waits for the refill instead", Ken.rejoinOff == true and S.KenFarm == true)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(P + mod + T, encoding="utf-8")
