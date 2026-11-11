"""اعلان‌ها (بدون تکرار، حداکثر 3 تا، خلاصه‌ی 10 ثانیه‌ی اول) و ورود به آرنای Cake Prince از آینه (کد واقعی)."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
a = hub.index("local notifSeen, notifSlots, startBuffer, startFlushed")
b = hub.index("notifyHook = notify", a)
notify_src = hub[a:b]
c = hub.index("\tdo\n\t\tlocal arena = Vector3.new(-1990.67, 4532.97, -14973.67)")
d = hub.index("\tlocal dist = (root.Position - cf.Position).Magnitude", c)
mirror_src = hub[c:d]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
NOW = 0
local function tick() return NOW end
local DELAYS = {}
local task = { delay = function(t, f) table.insert(DELAYS, { at = NOW + t, f = f }) end, wait = function() end }
local function runDelays()
	local keep = {}
	local due = {}
	for _, d in ipairs(DELAYS) do if d.at <= NOW then table.insert(due, d) else table.insert(keep, d) end end
	DELAYS = keep
	for _, d in ipairs(due) do d.f() end
end
local Hub = { Running = true, StartedAt = 0 }
local SHOWN, ALIVE = {}, 0
local function new(class, props)
	local o = { Destroyed = false }
	function o:Destroy() if not self.Destroyed then self.Destroyed = true; if self.isSlot then ALIVE -= 1 end end end
	if props and props.Text then table.insert(SHOWN, props.Text) end
	if class == "Frame" and props and props.LayoutOrder then o.isSlot = true; ALIVE += 1 end
	return o
end
local function corner() return {} end
local function gradient() return {} end
local function animated(g) return g end
local function tween() end
local UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
local Theme = {}
local Color3 = { new = function() return {} end }
local Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end })
local notifHolder = {}
local notifCount = 0
''' + notify_src + r'''
-- startup: everything in the first 10 s becomes one summary
notify("BM Hub", "Loaded ✔", 4)
check("'BM Hub Loaded' is shown right away", SHOWN[#SHOWN] == "Loaded ✔")
local before = #SHOWN
for i = 1, 6 do notify("Notice " .. i, "text " .. i, 5) end
check("startup notices are held back (no flood)", #SHOWN == before)
NOW = 10; runDelays()
check("...then shown as ONE summary", SHOWN[#SHOWN]:find("6 notices while loading", 1, true) ~= nil and #SHOWN == before + 2)
-- after startup: duplicates and the 3-on-screen cap
NOW = 20
local n0 = #SHOWN
notify("Fruit", "Kitsune spawned", 5)
notify("Fruit", "Kitsune spawned", 5)
check("same notice twice within 60 s: shown once", #SHOWN == n0 + 2)
NOW = 90
notify("Fruit", "Kitsune spawned", 5)
check("after 60 s it can show again", #SHOWN == n0 + 4)
for i = 1, 5 do notify("Boss " .. i, "alive", 30) end
check("never more than 3 on screen at once", ALIVE <= 3)
NOW = 200; runDelays()
check("closed ones are removed from the list", ALIVE == 0)

-- Cake Prince mirror redirect (real snippet from tweenTo)
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, { __sub = function(p, q)
	local dx, dy, dz = p.X - q.X, p.Y - q.Y, p.Z - q.Z
	return { Magnitude = math.sqrt(dx * dx + dy * dy + dz * dz) } end }) end
local Vector3 = { new = vec }
local S = { Status = "" }
local MIRROR = { CFrame = { Position = vec(-2100, 70, -12400), tag = "mirror" } }
local workspace = { Map = { CakeLoaf = { BigMirror = { Main = MIRROR } } } }
local function go(from, to)
	local root = { Position = from }
	local cf = { Position = to }
''' + mirror_src + r'''
	return cf
end
local prince = vec(-1990, 4540, -14970)
check("far from the arena + target inside it: flies to the big mirror, not the sky", go(vec(-2000, 40, -12000), prince).tag == "mirror")
check("status says so", S.Status:find("mirror", 1, true) ~= nil)
check("already inside the arena: goes straight to the boss", go(vec(-1995, 4535, -14900), prince).Position == prince)
check("normal targets are not touched", go(vec(0, 0, 0), vec(-2000, 40, -12000)).tag == nil)
workspace.Map.CakeLoaf = nil
check("no mirror (boss not spawned): falls back to the old path", go(vec(-2000, 40, -12000), prince).Position == prince)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
