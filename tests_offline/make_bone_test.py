"""Runs the real boneScan/boneTarget/bringMobs from the generated hub on the situations seen in the log."""
import pathlib
import sys

v3 = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")


def piece(start, end_marker):
    i = v3.index(start)
    return v3[i:v3.index(end_marker, i) + len(end_marker)]


scan = piece("\tlocal BONE_CLEAR = 150\n", "\tlocal function stepBone(keep)\n").replace("\tlocal function stepBone(keep)\n", "")
# 5.10: bringMobs توی do با lastSimRadius خودش
bring = "local lastSimRadius = 0\nlocal " + piece("function bringMobs(name, cf)", "\nend\n")

TEST = r'''
local clock = 1000
local function tick() return clock end
local vecMeta = {}
local function V(x) return setmetatable({ x = x }, vecMeta) end
vecMeta.__sub = function(a, b) return { Magnitude = math.abs(a.x - b.x) } end
local Vector3 = { zero = 0 }
local Hub, S = {}, { BringMax = 7, BringRange = 291 }
local BONE_MOBS = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
local rootObj = { Position = V(0) }
local function getRoot() return rootObj end
local mobs, questOn = {}, false
local function mobBaseName(n) return n end
local function isAliveMob() return true end
local function mummyQuestActive() return questOn end
local function findMob(name)
	local best
	for _, m in ipairs(mobs) do
		if m.Name == name and (not best or math.abs(m.HumanoidRootPart.Position.x) < math.abs(best.HumanoidRootPart.Position.x)) then best = m end
	end
	return best
end
local workspace = { FindFirstChild = function() return { GetChildren = function() return mobs end } end }
local player, lastSimRadius = {}, 0
local function mob(name, x)
	return { Name = name, HumanoidRootPart = { Position = V(x) }, Humanoid = {} }
end
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
'''

CASES = r'''
-- 19:56:56 in the log: three mobs still next to you, a mummy 500 studs away, quest active
questOn = true
mobs = { mob("Reborn Skeleton", 12), mob("Demonic Soul", 30), mob("Posessed Mummy", 500) }
check("nearby stack is finished before the far mummy", boneTarget().Name == "Reborn Skeleton")
mobs = { mob("Posessed Mummy", 500) }
check("far mummy once the area is clear", boneTarget().Name == "Posessed Mummy")
mobs = { mob("Reborn Skeleton", 10), mob("Posessed Mummy", 100) }
check("mummy close by still comes first for the quest", boneTarget().Name == "Posessed Mummy")
mobs = { mob("Reborn Skeleton", 400), mob("Posessed Mummy", 700) }
check("area empty, quest active: goes for the mummy", boneTarget().Name == "Posessed Mummy")
questOn = false
mobs = { mob("Reborn Skeleton", 400), mob("Posessed Mummy", 700) }
check("no quest: simply the nearest", boneTarget().Name == "Reborn Skeleton")
mobs = {}
check("no mobs: nil", boneTarget() == nil)

mobs = {}
for i = 1, 20 do table.insert(mobs, mob("Living Zombie", i * 10)) end
local function moved()
	local n = 0
	for _, m in ipairs(mobs) do
		if m.HumanoidRootPart.CFrame then n += 1; m.HumanoidRootPart.CFrame = nil end
	end
	return n
end
bringMobs("Living Zombie", "here")
check("normal farm keeps your slider (7)", moved() == 7)
Hub.BringGroup = { ["Living Zombie"] = true }
bringMobs("Reborn Skeleton", "here")
check("Bone brings at least 15 and other types", moved() == 15)
S.BringMax = 25
bringMobs("Reborn Skeleton", "here")
check("a higher slider still wins", moved() == 20)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

pathlib.Path(sys.argv[1]).write_text(TEST + scan + bring + CASES, encoding="utf-8")
