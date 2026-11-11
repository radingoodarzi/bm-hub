import pathlib, sys
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\10_sea.lua").read_text(encoding="utf-8")
a = src[src.index("\tlocal NEAR_FRUITS"):src.index("\tfunction V3.seaStand")]
b = src[src.index("\tlocal fruitTarget, fruitUntil"):src.index("\tlocal function m1Attack")]
b = b.replace("\ttask.spawn(function()\n\t\twhile Hub.Running do", "\tlocal _unused = (function()\n\t\twhile false do")
P = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) local m = math.sqrt(v.X^2+v.Y^2+v.Z^2)
  if k=="Magnitude" then return m end if k=="Unit" then return vec(v.X/m,v.Y/m,v.Z/m) end end
local Vector3 = { new = vec }
local cm = {}
local function cf(p) return setmetatable({Position=p}, cm) end
cm.__mul = function(a,b) return cf(a.Position + b.Position) end
local CFrame = { new = function(x,y,z) return cf(vec(x,y,z)) end }
local NOW = 0
local function tick() return NOW end
local S = { SeaAttack = "M1 Spam", SeaWeapon = "Blox Fruit" }
local Hub = { Running = true, Brain = { store = { fruit = { ["Dragon-Dragon"] = { gap = 0.3 } } } } }
local fired = {}
local char = {}
local fruit = { Name = "Dragon-Dragon", Parent = char }
local remote = { FireServer = function(_, d, c) table.insert(fired, { d = d, c = c }) end }
fruit.FindFirstChild = function(_, n) if n == "LeftClickRemote" then return remote end end
local V3 = { toolByTip = function(t) return t == "Blox Fruit" and fruit or nil end }
local root = { Position = vec(0, 0, 0) }
local function getRoot() return root end
local function getChar() return char end
'''
T = r'''
local engine = { Name = "Engine", Position = vec(100, 5, 100), CFrame = cf(vec(100, 5, 100)) }
local boat = { obj = { Parent = {} }, part = engine, kind = "boat" }
local stand, aim = fruitStand(boat, fruit, 0)
check("boat: stands 25 under the Engine", stand.Y == -20 and stand.X == 100)
check("boat: aims 35 under the Engine", aim.Y == -30)
local beastPart = { Name = "HumanoidRootPart", Position = vec(0, -50, 0) }
local beast = { obj = { Parent = {} }, part = beastPart, kind = "beast" }
check("beast + Dragon: 200 above, straight over it", (fruitStand(beast, fruit, 0)).Y == 150 and (fruitStand(beast, fruit, 0)).Z == 0)
fruit.Name = "Dough-Dough"
check("beast + Dough: 30 above", (fruitStand(beast, fruit, 0)).Y == -20)
fruit.Name = "Kitsune-Kitsune"
check("Kitsune: no fruit M1 on boats", seaFruitM1(boat) == nil)
check("Kitsune: fruit M1 on sea beasts", seaFruitM1(beast) == fruit)
fruit.Name = "Dragon-Dragon"
S.SeaWeapon = "Sword"
check("weapon not Blox Fruit: off", seaFruitM1(boat) == nil)
S.SeaWeapon = "Blox Fruit"
check("no target: not firing", fireFruitM1() == 0.1 and #fired == 0)
root.Position = vec(100, -20, 100)
V3.setFruitTarget(boat, 1)
local gap = fireFruitM1()
check("fires at the learned gap", gap == 0.3 and #fired == 1)
check("fires straight down", fired[1].d.Y == -1 and fired[1].c == 1)
fireFruitM1(); fireFruitM1(); fireFruitM1(); fireFruitM1()
check("combo goes 1..4 and wraps", fired[4].c == 4 and fired[5].c == 1)
Hub.Brain.store.fruit = {}
check("unknown fruit: 0.2 gap", fireFruitM1() == 0.2)
NOW = 2
check("target expires", fireFruitM1() == 0.1)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(P + a + b + T, encoding="utf-8")
