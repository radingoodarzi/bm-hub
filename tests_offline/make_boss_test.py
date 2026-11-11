"""Auto Click روی باس‌ها: فاصله تا لبه‌ی ماب، ماب «گیر کرده»ی فارم هم زده میشه (کد واقعی bm_hub_v3.lua)."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
helpers = hub[hub.index("local function hittableMob(m)"):hub.index("local cooldown = { remote = 0, click = 0, skill = 0 }")]
nearest = hub[hub.index("local function nearestMobInRange()"):]
nearest = nearest[:nearest.index("\nend\n") + 5]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x) return setmetatable({ X = x }, vm) end
vm.__sub = function(a, b) return vec(a.X - b.X) end
vm.__index = function(v, k) if k == "Magnitude" then return math.abs(rawget(v, "X")) end end
local root = { Position = vec(0) }
local function getRoot() return root end
local S = { AttackRange = 31 }
local Hub = {}
local mobs = {}
local workspace = { FindFirstChild = function() return { GetChildren = function() return mobs end } end }
local function mob(name, x, size, hp)
	local hrp = { Position = vec(x) }
	local hum = { Health = hp or 100 }
	return { Name = name, Parent = true,
		FindFirstChildOfClass = function() return hum end,
		FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return hrp end end,
		GetExtentsSize = function() return { Magnitude = size } end }
end
''' + helpers + nearest + r'''
local cookie = mob("Cookie Crafter", 50, 6)
local boss = mob("Dough King", 60, 80)
mobs = { cookie, boss }
check("big boss (center 60 away, 80 studs big) counts as in range 31", nearestMobInRange() == boss)
mobs = { cookie }
check("a normal mob 50 studs away is still out of range", nearestMobInRange() == nil)
local near = mob("Cake Guard", 10, 6)
mobs = { cookie, near, boss }
check("nearest edge wins: the boss (edge 20) loses to a mob 7 away", nearestMobInRange() == near)
local dead = mob("Cake Guard", 2, 6, 0)
mobs = { dead }
check("dead mobs are ignored", nearestMobInRange() == nil)
local huge = mob("Sea Beast", 70, 500)
mobs = { huge }
check("size bonus is capped at 40 (70 - 40 = 30 -> in range)", nearestMobInRange() == huge)
huge = mob("Sea Beast", 80, 500)
mobs = { huge }
check("...but 80 - 40 = 40 is out of range", nearestMobInRange() == nil)
-- the farm's "stuck, skip for 45s" list is not used here any more
check("a mob the farm skipped is still hittable (no skip check)", helpers:find("mobSkipUntil") == nil and nearestMobInRange ~= nil)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''.replace('helpers:find("mobSkipUntil") == nil', "true" if "mobSkipUntil" not in helpers + nearest else "false")
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
