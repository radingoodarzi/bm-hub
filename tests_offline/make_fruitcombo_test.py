# 5.10: تست کمبوی M1 میوه (50_brain): چرخه‌ی کوتاه‌تر از ۴، تست دوباره‌ی نتیجه‌های قدیمی، ذخیره‌ی کمبو
import pathlib, sys
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\50_brain.lua").read_text(encoding="utf-8")
a = src[src.index("\tlocal FRUIT_MODES"):src.index("\t-- دمیج واقعی برای لاگ")]
P = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) local m = math.sqrt(v.X^2+v.Y^2+v.Z^2)
  if k=="Magnitude" then return m end if k=="Unit" then return vec(v.X/m,v.Y/m,v.Z/m) end end
local NOW = 100
local function tick() return NOW end
local S = { FruitM1 = true }
local notes = {}
local Brain = { store = { fruit = {} }, markDirty = function() end, note = function(t) table.insert(notes, t) end }
local Hub = { AttackInfo = {} }
local V3 = { notify = function() end, log = function() end }
local fired = {}
local remote = { FireServer = function(_, d, c) table.insert(fired, c) end }
local tool = { Name = "Kitsune-Kitsune" }
tool.FindFirstChild = function(_, n) if n == "LeftClickRemote" then return remote end end
local char = { FindFirstChildOfClass = function() return tool end }
local function getChar() return char end
local mob = { Parent = {}, HumanoidRootPart = { Position = vec(10, 0, 0) } }
mob.FindFirstChild = function(_, n) return mob[n] end
local function nearestMobInRange() return mob end
local root = { Position = vec(0, 0, 0) }
local function shoot(n) for _ = 1, n do NOW += 1; Hub.FruitM1(root, mob) end end
'''
T = r'''
-- نتیجه‌ی قدیمی Kitsune (gap 0.3 بدون کمبو) باید یه بار دوباره تست بشه
Brain.store.fruit["Kitsune-Kitsune"] = { gap = 0.3, tested = true }
local m = Hub.FruitM1(root, mob)
check("old saved result (no combo test) is retested", Brain.store.fruit["Kitsune-Kitsune"] == nil and m.gap == 0.2)
check("status shows testing", Brain.fruitStatus(tool):find("testing 1/") ~= nil)
-- ۸ ثانیه برای هر حالت؛ حالت combo=1 بیشترین دمیج رو بده
local modes = {}
for i = 1, 12 do
  local cur = Hub.FruitM1(root, mob)
  if not cur then break end
  table.insert(modes, cur)
  local dmg = (cur.combo == 1) and 5000 or 1000
  for _ = 1, 16 do Brain.tuneStep(dmg, 1) end
  if Brain.store.fruit["Kitsune-Kitsune"] then break end
end
local saved = Brain.store.fruit["Kitsune-Kitsune"]
local hasCombo = false
for _, md in ipairs(modes) do if md.combo then hasCombo = true end end
check("tuner tries shorter combos", hasCombo)
check("best combo saved", saved and saved.combo == 1 and saved.gap == 0.3 and saved.v == 2)
check("status shows combo", Brain.fruitStatus(tool):find("combo 1") ~= nil)
-- بعد از ذخیره دیگه دوباره تست نمیشه
fired = {}
shoot(5)
check("saved v2 result is kept", Brain.store.fruit["Kitsune-Kitsune"] == saved)
check("combo 1: every hit is hit 1 (no finisher pause)", #fired == 5 and fired[1] == 1 and fired[5] == 1)
Brain.store.fruit["Kitsune-Kitsune"] = { gap = 0.3, combo = 3, v = 2, tested = true }
fired = {}
shoot(7)
local mx = 0 for _, c in ipairs(fired) do mx = math.max(mx, c) end
check("combo 3: never sends hit 4", mx == 3 and #fired == 7)
Brain.store.fruit["Kitsune-Kitsune"] = { gap = 0.3, v = 2, tested = true }
fired = {}
shoot(8)
mx = 0 for _, c in ipairs(fired) do mx = math.max(mx, c) end
check("no combo saved: full 1..4 like before", mx == 4)
-- melee ذخیره‌شده دوباره تست نمیشه
Brain.store.fruit["Kitsune-Kitsune"] = { melee = true }
check("saved melee untouched", Hub.FruitM1(root, mob).melee and Brain.store.fruit["Kitsune-Kitsune"].melee)
-- gap رعایت میشه
Brain.store.fruit["Kitsune-Kitsune"] = { gap = 0.3, combo = 2, v = 2, tested = true }
fired = {}
NOW += 1; Hub.FruitM1(root, mob); NOW += 0.1; Hub.FruitM1(root, mob)
check("gap respected", #fired == 1)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(P + a + T, encoding="utf-8")
