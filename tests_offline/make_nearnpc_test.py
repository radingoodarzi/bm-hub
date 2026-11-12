# 5.10: کوئست از NPC نزدیک ماب‌ها؛ اگه نداد برمی‌گرده سراغ NPC ذخیره‌شده
import pathlib, sys
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8")
a = "local takeQuest\ndo\n" + src[src.index("-- 5.10: NPC کوئست نزدیک ماب‌ها"):src.index("-" * 69 + "\n-- Combat\n")]
P = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local function CF(x,y,z) return { Position = vec(x,y,z) } end
local NOW = 0
local function tick() return NOW end
local logs = {}
local Hub = { MobSeenAt = {}, LiveLog = function(m) table.insert(logs, m) end }
local root = { Position = vec(0,0,0) }
local function getRoot() return root end
local questFailures, questBlockedUntil = {}, {}
local OLD = CF(-7907, 5634, -1412)
local NEAR = CF(-6950, 5570, 1000)
local givers = { OLD, NEAR, CF(-4800, 716, -2600) }
local function questGivers() return givers end
local centroid = nil
local function spawnCentroid() return centroid end
-- NPC ای که واقعاً این کوئست رو میده
local REAL = NEAR
local visits = {}
local function takeQuestRaw(q, keepGoing)
  if q.blockedLevel then return end
  NOW += 1
  table.insert(visits, q.npc)
  root.Position = q.npc.Position
  if q.npc == REAL then Hub.QuestTakenAt = NOW; return end
  questFailures[q.quest .. q.index] = (questFailures[q.quest .. q.index] or 0) + 1
end
'''
T = r'''
local q = { quest = "SkyExp2Quest", index = 2, mob = "Royal Soldier", npc = OLD }
-- هنوز ماب رو ندیدیم و spawn هم نداره: مثل قبل
takeQuest(q, function() return true end)
check("mobs never seen: saved NPC like before", #visits == 1 and visits[1] == OLD)
-- ماب‌ها کنار NEAR دیده شدن
Hub.MobSeenAt["Royal Soldier"] = { pos = vec(-6900, 5575, 1100), t = 0 }
visits = {}
root.Position = vec(-6900, 5600, 1100)
takeQuest(q, function() return true end)
check("tries the quest NPC next to the mobs first", visits[1] == NEAR)
check("it gave the quest: no trip to the far NPC", #visits == 1)
check("saved NPC left unchanged", q.npc == OLD)
check("logged", logs[#logs]:find("works") ~= nil)
visits = {}
takeQuest(q, function() return true end)
check("remembered next time", #visits == 1 and visits[1] == NEAR)
-- کوئست دیگه: NPC نزدیک کوئست رو نمیده → برمی‌گرده سراغ ذخیره‌شده، بدون شمردن شکست
REAL = OLD
local q2 = { quest = "SkyExp2Quest", index = 1, mob = "Royal Squad", npc = OLD }
Hub.MobSeenAt["Royal Squad"] = { pos = vec(-6900, 5575, 1100), t = 0 }
visits = {}
takeQuest(q2, function() return true end)
check("refused: falls back to the saved NPC", #visits == 2 and visits[1] == NEAR and visits[2] == OLD)
check("refusal near the mobs is not counted as a failure", (questFailures["SkyExp2Quest1"] or 0) == 0)
visits = {}
takeQuest(q2, function() return true end)
check("refused NPC is not tried again", #visits == 1 and visits[1] == OLD)
-- NPC ذخیره‌شده خودش نزدیک ماب‌هاست: هیچ تغییری
local q3 = { quest = "BanditQuest1", index = 1, mob = "Bandit", npc = CF(1059, 15, 1550) }
Hub.MobSeenAt["Bandit"] = { pos = vec(1100, 15, 1600), t = 0 }
REAL = q3.npc
visits = {}
takeQuest(q3, function() return true end)
check("saved NPC already close: used directly", #visits == 1 and visits[1] == q3.npc)
-- لول کم: هیچی یاد نمی‌گیره و دوباره سراغ NPC دور نمیره
local q4 = { quest = "X", index = 1, mob = "Royal Soldier", npc = OLD, blockedLevel = true }
visits = {}
takeQuest(q4, function() return true end)
check("level too low: no extra trip", #visits == 0)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text(P + a + T, encoding="utf-8")
