"""Auto Cake: همه‌ی ماب‌های جزیره‌ی کیک، کوئست اختیاری (CakeQuest)."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
fl = hub[hub.index("\tlocal function farmList(list, keep, waitPos, anyMob)"):hub.index("\tlocal function stepElite(keep)")]
src = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local function vec(x) return { X = x, Magnitude = math.abs(x) } end
local vm = { __sub = function(a, b) return vec(a.X - b.X) end }
local function P(x) return setmetatable({ X = x }, vm) end
local root = { Position = P(0) }
local function getRoot() return root end
local S = { TakeQuest = true, Status = "" }
local Hub = {}
local QUEST = nil
local function activeQuestMob() return QUEST end
local MOBS = {}
local function findMob(n) return MOBS[n] end
local function mobBaseName(n) return n end
local function questForMob(n) return { quest = "CakeQuest", mob = n } end
local function questBlocked() return false end
local function hasQuest(n) return QUEST == n end
local TAKEN = {}
local function takeQuest(q) table.insert(TAKEN, q.mob) end
local KILLED, GROUP = {}, nil
local function killMob(m) table.insert(KILLED, m.Name); GROUP = Hub.BringGroup end
local function tweenTo() end
local task = { wait = function() end }
local CFrame = { new = function() return {} end }
local Vector3 = { new = function() return P(0) end }
''' + fl + r'''
local CAKE = { "Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker" }
local function mob(n, x) return { Name = n, HumanoidRootPart = { Position = P(x) } } end
MOBS = { ["Cookie Crafter"] = mob("Cookie Crafter", 300), ["Cake Guard"] = mob("Cake Guard", 50), ["Head Baker"] = mob("Head Baker", 900) }

-- Cake Quest off (default)
QUEST = "Cookie Crafter"
farmList(CAKE, nil, P(0), true)
check("quest is for Cookie Crafter, but the nearest cake mob (Cake Guard) is fought", KILLED[1] == "Cake Guard")
check("no quest is taken", #TAKEN == 0)
check("Bring Mobs gathers all 4 cake mob types together", GROUP and GROUP["Cookie Crafter"] and GROUP["Cake Guard"] and GROUP["Baking Staff"] and GROUP["Head Baker"])
check("bring group is cleared after the fight", Hub.BringGroup == nil)
MOBS["Cake Guard"] = nil
farmList(CAKE, nil, P(0), true)
check("Cake Guards gone: moves on to the next type (Cookie Crafter)", KILLED[2] == "Cookie Crafter")

-- Cake Quest on (old behaviour)
KILLED, TAKEN, GROUP = {}, {}, nil
MOBS["Cake Guard"] = mob("Cake Guard", 50)
QUEST = "Cookie Crafter"
farmList(CAKE, nil, P(0), false)
check("Take Quests on + Cookie Crafter quest: only Cookie Crafter", KILLED[1] == "Cookie Crafter" and GROUP == nil)
QUEST = nil
farmList(CAKE, nil, P(0), false)
check("Take Quests on + no quest: takes the quest first", TAKEN[1] == "Cake Guard" and #KILLED == 1)

-- error inside the fight still clears the bring group
killMob = function() error("boom") end
local ok = pcall(farmList, CAKE, nil, P(0), true)
check("a crash in the fight is passed on and the bring group is cleared", not ok and Hub.BringGroup == nil)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
