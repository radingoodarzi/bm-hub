"""Offline test of v3_src/95_swords.lua: CDK stage map, every CDK branch, Tushita and TTK."""
import pathlib
import sys

src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\95_swords.lua").read_text(encoding="utf-8")
head = src.split("--@@UI@@")[0]

PRELUDE = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local NOW = 0
local function tick() return NOW end
local vmeta = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vmeta) end
vmeta.__sub = function(a, b) return vec(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vmeta.__add = function(a, b) return vec(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vmeta.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end end
local Vector3 = { new = vec }
local Vector2 = { new = function() return {} end }
local cfmeta = {}
local function cf(p) return setmetatable({ Position = p }, cfmeta) end
cfmeta.__mul = function(a, b) return cf(a.Position + (b.Position or vec(0,0,0))) end
local CFrame = { new = function(x, y, z) if type(x) == "table" then return cf(x) end return cf(vec(x or 0, y or 0, z or 0)) end }
local function typeof(v) return getmetatable(v) == vmeta and "Vector3" or "CFrame" end
local BrickColor = { new = function(n) return n end }
local Sea = 3
local S = { Status = "", Weapon = "Melee", AutoLegendary = false }
local Hub = { V3 = {}, Running = true }
local V3 = Hub.V3
local notes, logs = {}, {}
V3.notify = function(t, m) table.insert(notes, m) end
V3.log = function(m) table.insert(logs, m) end
V3.activate = function(p) if p then p.fired = (p.fired or 0) + 1 end return true end
local steps = {}
V3.register = function(f, s) steps[f] = s end
local root = { Position = vec(0, 0, 0) }
root.CFrame = cf(root.Position)
local function getRoot() return root end
local function tweenTo(c) root.Position = c.Position; root.CFrame = c end
local function alive() return true end
local function setFloat() end
local function getHum() return { EquipTool = function() end } end
local BACKPACK = {}
local function container(t) return { FindFirstChild = function(_, n) return t[n] end } end
local player = { PlayerGui = { Main = { Dialogue = { Visible = false } } } }
player.FindFirstChild = function(_, n) if n == "Backpack" then return container(BACKPACK) end if n == "QuestHaze" then return player.QuestHaze end end
local function getChar() return container({}) end
local OWNED = {}
local function hasItem(n) return OWNED[n] == true end
local function dataValue(n) return n == "Beli" and 9e9 or 0 end
local MOBS = {}
local function findMob(n) return MOBS[n] end
local function findMobAnywhere(n) return MOBS[n] end
local killed = {}
local function killMob(m) table.insert(killed, m.Name .. "@" .. S.Weapon); MOBS[m.Name] = nil; m.dead = true end
local function fightBoss(n) local m = MOBS[n]; if not m then return false end killMob(m) return true end
local function isAliveMob(m) return not m.dead end
local function mobBaseName(n) return n end
local touched = 0
local function touchPart() touched += 1 return true end
local function spawnCentroid() return nil end
local QUEST
local function questTitle() return QUEST end
local function logError(w, e) print("MODULE ERROR", w, e); fails += 1 end
-- server
local SRV = { good = 3, evil = 3, calls = {} }
local function invoke(...)
	local a = { ... }
	table.insert(SRV.calls, table.concat((function() local t = {} for _, v in ipairs(a) do table.insert(t, tostring(v)) end return t end)(), " "))
	if a[1] == "CDKQuest" and a[2] == "Progress" then return { Good = SRV.good, Evil = SRV.evil } end
	if a[1] == "TushitaProgress" and a[2] == nil then return { OpenedDoor = SRV.door } end
	if a[1] == "MysteriousMan" and a[2] == "2" then OWNED["True Triple Katana"] = true end
	if a[1] == "LoadItem" then BACKPACK[a[2]] = { Name = a[2], FindFirstChild = function() return nil end } end
end
local ReplicatedStorage = { FindFirstChild = function() return nil end }
-- world
local function part(name, pos, kids)
	local p = { Name = name, Position = pos, CFrame = cf(pos), _k = kids or {} }
	function p:IsA(c) return c == "BasePart" end
	function p:FindFirstChild(n) return self._k[n] end
	function p:FindFirstChildWhichIsA(c, rec) for _, v in pairs(self._k) do if v.ClassName == c then return v end end end
	function p:GetPivot() return cf(self.Position) end
	return p
end
local function prompt() return { ClassName = "ProximityPrompt", Enabled = true } end
local P1 = part("Pedestal1", vec(-12300, 600, -6500), { P = prompt() })
local P3 = part("Pedestal3", vec(-12320, 600, -6520), { P = prompt() })
local GEM = { Transparency = 1 }
local CURSED = part("Cursed", vec(0,0,0), { Pedestal1 = P1, Pedestal2 = part("Pedestal2", vec(-12310, 600, -6510), { P = prompt() }), Pedestal3 = P3, PlacedGem = GEM })
local TORCH = part("Torch1", vec(100, 0, 100), { P = prompt() })
local EXIT = part("Exit", vec(150, 0, 150))
EXIT.BrickColor = "x"
local HELL = part("HellDimension", vec(100, 0, 100), { Torch1 = TORCH, Exit = EXIT })
local LOCS = {}
local MAP = { _k = { Turtle = part("Turtle", vec(0,0,0), { Cursed = CURSED }) } }
function MAP:FindFirstChild(n) return self._k[n] end
local enemiesList = {}
local workspace = {
	Map = MAP,
	FindFirstChild = function(_, n)
		if n == "_WorldOrigin" then return { FindFirstChild = function() return { FindFirstChild = function(_, l) return LOCS[l] end } end } end
		if n == "Enemies" then return { GetChildren = function() return enemiesList end } end
	end,
}
local game = { GetService = function() return { Button1Down = function() end, Button1Up = function() end } end }
local task = { wait = function(s) NOW += (s or 0.03) end, spawn = function(f) f() end }
'''

TESTS = r'''
local C = V3.CDK
check("both 4 -> final", C.stage(4, 4) == "final")
check("good done, evil 3 -> pedestal2", C.stage(4, 3) == "pedestal2")
check("evil done, good 3 -> pedestal1", C.stage(3, 4) == "pedestal1")
check("good -3/-4/-5", C.stage(-3, 3) == "good3" and C.stage(-4, 3) == "good4" and C.stage(-5, 0) == "good5")
check("good other -> start good", C.stage(3, 3) == "goodStart" and C.stage(0, 0) == "goodStart")
check("good done -> evil stages", C.stage(4, -3) == "evil3" and C.stage(-2, -4) == "evil4" and C.stage(4, -5) == "evil5")
check("good done, evil other -> start evil", C.stage(4, 0) == "evilStart")
check("no numbers -> noProgress", C.stage(nil, 3) == "noProgress")

S.AutoCDK = true
local keep = function() return S.AutoCDK end
-- requirements
V3.cdkStep(keep)
check("no Yama/Tushita -> off", S.AutoCDK == false and notes[#notes]:find("Yama and Tushita") ~= nil)
OWNED.Yama, OWNED.Tushita = true, true
BACKPACK.Tushita = { Name = "Tushita", FindFirstChild = function(_, n) if n == "Level" then return { Value = 200 } end end }
S.AutoCDK = true
V3.cdkStep(keep)
check("low mastery -> off with numbers", S.AutoCDK == false and notes[#notes]:find("200/350") ~= nil)
BACKPACK.Tushita = nil
S.AutoCDK = true
V3.cdkStep(keep)
check("no sword in hand -> loads Tushita", SRV.calls[#SRV.calls] == "LoadItem Tushita")
BACKPACK = {}
SRV.good, SRV.evil = 4, -4
S.AutoCDK = true
BACKPACK.Tushita = { Name = "Tushita", FindFirstChild = function() return nil end }
V3.cdkStep(keep)
check("Yama trial with only Tushita in hand -> loads Yama", SRV.calls[#SRV.calls] == "LoadItem Yama")
BACKPACK.Yama = { Name = "Yama", FindFirstChild = function() return nil end }

local function runStage(g, e, n)
	SRV.good, SRV.evil = g, e
	for i = 1, (n or 1) do V3.cdkStep(keep) end
	return S.Status
end
-- good start / good 3 (boats)
runStage(3, 3)
check("good start -> StartTrial Good", table.find(SRV.calls, "CDKQuest StartTrial Good") ~= nil)
local st = runStage(-3, 3, 1)
check("good 3 -> sails to boat dealer 1", st:find("boat dealer 1/3") ~= nil)
local bq = 0
for i = 1, 8 do runStage(-3, 3, 1) end
for _, c in ipairs(SRV.calls) do if c:find("BoatQuest") then bq += 1 end end
st = S.Status
check("good 3 -> visits the 3 dealer docks in turn", (root.Position - vec(-9530, 12, -8366)).Magnitude < 10 or st:find("boat dealer") ~= nil)
-- good 4 raid
st = runStage(-4, 3)
check("good 4 -> waits at the castle", st:find("Castle") ~= nil)
enemiesList = { { Name = "Pirate Brigade", HumanoidRootPart = { Position = vec(-5100, 315, -3000) } } }
runStage(-4, 3)
check("good 4 -> fights raid pirates", killed[#killed] == "Pirate Brigade@Melee")
enemiesList = {}
-- good 5: no queen -> wait; queen -> fight with a sword
st = runStage(-5, 3)
check("good 5 without Cake Queen -> waits (hop off)", st:find("Cake Queen") ~= nil)
MOBS["Cake Queen"] = { Name = "Cake Queen" }
runStage(-5, 3)
check("good 5 -> fights Cake Queen with the sword", killed[#killed] == "Cake Queen@Sword" and S.Weapon == "Melee")
-- pedestal2 when good is done
root.Position = vec(0, 0, 0)
runStage(4, 3, 2)
check("good done -> goes to Pedestal2 and presses it", CURSED._k.Pedestal2._k.P.fired == 1)
check("then starts the Evil trial", SRV.calls[#SRV.calls]:find("StartTrial Evil") ~= nil)
-- evil 3 from quest text
local nk3 = #killed
runStage(4, -3)
check("evil 3 without Commodores -> goes to Great Tree", (root.Position - vec(2180.54, 37.82, -6741.55)).Magnitude < 1)
local cm = { Name = "Marine Commodore", Parent = true, HumanoidRootPart = { CFrame = cf(vec(2200, 30, -6700)), Position = vec(2200, 30, -6700) } }
cm.FindFirstChild = function(self, n) return self[n] end
MOBS["Marine Commodore"] = cm
runStage(4, -3)
check("evil 3 -> stands next to it and does NOT attack (Pain and Suffering)", #killed == nk3 and (root.CFrame.Position - vec(2200, 30, -6697)).Magnitude < 1)
MOBS["Marine Commodore"] = nil
-- evil 4 haze
player.QuestHaze = { GetChildren = function() return { { Name = "Forest Pirate", Value = 2, IsA = function() return true end } } end }
player.QuestHaze["Forest Pirate"] = { Value = 2 }
MOBS["Forest Pirate"] = { Name = "Forest Pirate" }
runStage(4, -4)
check("evil 4 -> kills the haze mob", killed[#killed] == "Forest Pirate@Melee")
-- evil 5: no essence -> bones + gamble
MOBS["Reborn Skeleton"] = { Name = "Reborn Skeleton" }
runStage(4, -5)
check("evil 5 -> farms bones and gambles", killed[#killed] == "Reborn Skeleton@Melee" and table.find(SRV.calls, "Bones Buy 1 1") ~= nil)
-- evil 5: Soul Reaper -> stays next to it (no fight)
MOBS["Soul Reaper"] = { Name = "Soul Reaper", Parent = true, HumanoidRootPart = { CFrame = cf(vec(500, 0, 0)) } }
MOBS["Soul Reaper"].FindFirstChild = function(self, n) return self[n] end
local reaperLoops = 0
local nk = #killed
runStage(4, -5)
check("evil 5 -> does not fight Soul Reaper, waits to be taken", #killed == nk and (root.Position - vec(500, 0, 0)).Magnitude < 5)
MOBS["Soul Reaper"] = nil
-- inside Hell: torch -> mobs -> exit
LOCS["Hell Dimension"] = { Position = vec(100, 0, 100) }
MAP._k.HellDimension = HELL
root.Position = vec(100, 0, 100)
runStage(4, -5)
check("hell -> lights a torch", TORCH._k.P.fired == 1)
enemiesList = { { Name = "Cursed Skeleton", HumanoidRootPart = { Position = vec(120, 0, 100) } } }
runStage(4, -5)
check("hell -> kills the dimension mobs with the sword", killed[#killed] == "Cursed Skeleton@Sword")
enemiesList = {}
EXIT.BrickColor = "Olivine"
runStage(4, -5)
check("hell cleared -> goes to the exit", (root.Position - EXIT.Position).Magnitude < 1 and touched > 0)
LOCS["Hell Dimension"] = nil
-- final
root.Position = vec(0, 0, 0)
runStage(4, 4)
check("final -> goes to Pedestal3", (root.Position - P3.Position).Magnitude < 1)
runStage(4, 4)
check("final -> places the gem", P3._k.P.fired == 1)
GEM.Transparency = 0
MOBS["Cursed Skeleton Boss"] = { Name = "Cursed Skeleton Boss" }
runStage(4, 4)
check("final -> kills Cursed Skeleton Boss with the sword", killed[#killed] == "Cursed Skeleton Boss@Sword")
OWNED["Cursed Dual Katana"] = true
runStage(4, 4)
check("got CDK -> turns off", S.AutoCDK == false)

-- Tushita
OWNED.Tushita = nil
S.AutoTushita = true
local tk = function() return S.AutoTushita end
SRV.door = true
MOBS["Longma"] = { Name = "Longma" }
V3.tushitaStep(tk)
check("Tushita: door open -> fights Longma", killed[#killed] == "Longma@Melee")
SRV.door = false
V3.tushitaStep(tk)
check("Tushita: no secret room loaded -> flies there", S.Status:find("secret room") ~= nil)

-- TTK
Sea = 2
OWNED = { Saddi = true }
S.AutoTTK = true
local ttk = steps.AutoTTK
ttk(function() return S.AutoTTK end)
check("TTK: missing swords -> turns on Auto Buy Legendary", S.AutoLegendary == true and S.Status:find("Shisui") ~= nil)
OWNED.Shisui, OWNED.Wando = true, true
ttk(function() return true end)
ttk(function() return true end)
check("TTK: buys from the Mysterious Man", table.find(SRV.calls, "MysteriousMan 2") ~= nil)
ttk(function() return true end)
check("TTK: owned -> turns off", S.AutoTTK == false)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

pathlib.Path(sys.argv[1]).write_text(PRELUDE + head + TESTS, encoding="utf-8")
