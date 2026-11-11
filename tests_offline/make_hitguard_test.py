import pathlib, sys
root = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub")
hg = (root / "v3_src" / "52_hitguard.lua").read_text(encoding="utf-8")
brain = (root / "v3_src" / "50_brain.lua").read_text(encoding="utf-8")
hub = (root / "bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
h = brain[brain.index("\tlocal CAP_KEY"):brain.index("\tlocal Brain = {")]
bring = hub[hub.index("local lastSimRadius = 0"):hub.index("-- کلیک خودکار")]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local NOW = 0
local function tick() return NOW end
local LOG = {}
local Hub = { Running = false, LiveLog = function(m) table.insert(LOG, m) end }
local task = { spawn = function() end, wait = function(s) NOW += (s or 0.03) end }
local S = { FarmHeight = 25, HeightCapMelee = 100, HeightCapSword = 100, HeightCapFruit = 100, HeightCapGun = 100, AttackRange = 60 }
local SAVES = 0
Hub.SaveSettings = function() SAVES += 1 end
local TOOL = { Name = "Yama", ToolTip = "Sword" }
local char = { FindFirstChildOfClass = function() return TOOL end }
local function getChar() return char end
''' + hg + "\n" + h + r'''
local HG = Hub.HitGuard
-- 1) hit guard
local t = 0
local function run(sec, dmg, sending) for i = 1, sec * 2 do t += 0.5; if sending ~= false then HG.sentAt = t end; HG.update(t, dmg) end end
run(5, 500)
check("damage landing: 15 mobs per hit, fast, no clicks", HG.limit == 15 and HG.gap == 0.1 and not HG.swing and not HG.noRemote)
run(3, 0)
check("a 3s gap (server bursts / healing) does not slow us down", HG.limit == 15)
run(5, 500)
run(4.5, 0)
check("4s no damage: 5 mobs per hit", HG.limit == 5)
run(4, 0); run(4, 0)
check("12s: slower hits + real clicks", HG.gap > 0.1 and HG.swing and not HG.noRemote)
run(4, 0)
check("16s: clicks only", HG.noRemote and HG.exhausted())
run(31, 400)
check("30s steady damage: one step faster", HG.step == #HG.LADDER - 1)
run(4.5, 0); run(10.5, 0)
check("nothing works on the last step: starts over", HG.step == 1)

-- 2) height: always the Farm Height now
S.HeightCapMelee, S.HeightCapSword = 10, 10
check("old saved 10 studs is ignored", Hub.HeightCap() == 100)
check("no damage never lowers the height (mob is skipped instead)", Hub.LowerHeight() == false and Hub.HeightCap() == 100)
Hub.HeightWorked(); Hub.HeightGaveUp()
check("damage never saves a lower height", Hub.HeightCap() == 100 and SAVES == 0)
Hub.ResetHeightCaps()
check("saved file values cleaned on start", S.HeightCapMelee == 100 and S.HeightCapSword == 100)
-- 3) bring only mobs we control
check("ReceiveAge 0 = ours", Hub.OwnsPart({ ReceiveAge = 0 }) == true)
check("ReceiveAge > 0 = the server's", Hub.OwnsPart({ ReceiveAge = 0.2 }) == false)
check("can't tell = old behaviour", Hub.OwnsPart(setmetatable({}, { __index = function() error("no") end })) == true)
local Vector3 = { zero = "zero" }
local player = {}
local function mobBaseName(n) return n end
local function isAliveMob() return true end
local function getRoot() return { Position = { X = 0 } } end
local sub = function(a, b) return { Magnitude = 5 } end
local mobs = {}
for i = 1, 3 do
	local hrp = setmetatable({ ReceiveAge = (i == 2) and 0.3 or 0, CFrame = "home" .. i }, { __sub = sub })
	hrp.Position = hrp
	mobs[i] = { Name = "Cookie Crafter", HumanoidRootPart = hrp, Humanoid = {} }
end
local workspace = { FindFirstChild = function() return { GetChildren = function() return mobs end } end }
S.BringRange, S.BringMax = 300, 15
''' + bring + r'''
bringMobs("Cookie Crafter", "STACK")
check("our mobs are pulled to the stack", mobs[1].HumanoidRootPart.CFrame == "STACK" and mobs[3].HumanoidRootPart.CFrame == "STACK")
check("the server's mob is left where it really is", mobs[2].HumanoidRootPart.CFrame == "home2")
check("counted for the log", Hub.BringMoved == 2 and Hub.BringSkipped == 1)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
