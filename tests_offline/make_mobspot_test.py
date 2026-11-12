# 5.10: فارم وقتی ماب نیست جایی منتظر می‌مونه که ماب آخرین بار بود (اسکای: Royal Squad توی EnemySpawns نیست)
import pathlib, sys
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8")
a = src[src.index("Hub.MobSeenAt = {}"):src.index("---------------------------------------------------------------------\n-- Quest data")]
P = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local CFrame = { new = function(p) return { Position = p } end }
local NOW = 0
local function tick() return NOW end
local Hub = {}
local root = { Position = vec(0, 0, 0) }
local function getRoot() return root end
local function mobBaseName(n) return (n:gsub("%s*%[.-%]", "")) end
local function isAliveMob(m) return m.alive end
local function part(name, p) return { Name = name, Position = p, CFrame = { Position = p }, IsA = function(_, c) return c == "BasePart" end } end
local enemyList, spawnList = {}, {}
local workspace = {
  FindFirstChild = function(_, n)
    if n == "Enemies" then return { GetChildren = function() return enemyList end } end
    if n == "_WorldOrigin" then return { FindFirstChild = function() return { GetChildren = function() return spawnList end } end } end
  end,
}
local ReplicatedStorage = { GetChildren = function() return {} end }
local function mob(name, p) return { Name = name, alive = true, HumanoidRootPart = { Position = p } } end
'''
T = r'''
-- مثل اسکای: هیچ نقطه‌ی spawn برای Royal Squad نیست
check("no spawn point, never seen: nil (falls back to quest NPC)", mobSpawn("Royal Squad") == nil)
local m = mob("Royal Squad [Lv. 525]", vec(-6900, 5575, 1100))
enemyList = { m }
root.Position = vec(-6900, 5600, 1100)
check("findMob finds it", findMob("Royal Squad") == m)
m.alive = false
check("all dead: findMob nil", findMob("Royal Squad") == nil)
local sp = mobSpawn("Royal Squad")
check("waits where the mob was, not at the NPC", sp and sp.Position.X == -6900 and sp.Position.Z == 1100)
-- منتظر کنار همون جا؛ کمتر از ۶۰ ثانیه هنوز همون جا
NOW = 30
check("still waiting there after 30s", mobSpawn("Royal Squad") ~= nil)
NOW = 55
check("still there just under 60s of waiting", mobSpawn("Royal Squad") ~= nil)
NOW = 95
check("60s at the spot with no mob: forgets it", mobSpawn("Royal Squad") == nil and Hub.MobSeenAt["Royal Squad"] == nil)
-- ماب برگشت: دوباره یادش می‌مونه و تایمر از نو
m.alive = true
findMob("Royal Squad")
m.alive = false
NOW = 150
check("seen again: waits there again", mobSpawn("Royal Squad") ~= nil)
-- تا وقتی نرسیدیم اونجا تایمر شروع نمیشه (پرواز طولانی)
root.Position = vec(-7900, 5634, -1400)
NOW = 400
check("far away (went to take a quest): memory kept", mobSpawn("Royal Squad") ~= nil)
root.Position = vec(-6900, 5600, 1100)
check("back at the spot after a long trip: waits again (timer restarted)", mobSpawn("Royal Squad") ~= nil)
NOW = 450
check("50s after coming back: still waiting", mobSpawn("Royal Squad") ~= nil)
root.Position = vec(-7900, 5634, -1400)
NOW = 800
check("memory expires after 10 min", mobSpawn("Royal Squad") == nil)
-- چند نقطه‌ی spawn: نزدیک‌ترین
spawnList = { part("Bandit", vec(1000, 0, 0)), part("Bandit [Lv. 5]", vec(10, 0, 0)), part("Monkey", vec(1, 0, 0)) }
root.Position = vec(0, 0, 0)
local b = mobSpawn("Bandit")
check("nearest of several spawn points", b and b.Position.X == 10)
check("other mob names ignored", mobSpawn("Pirate") == nil)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(P + a + T, encoding="utf-8")
