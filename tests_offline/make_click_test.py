"""Runs the real Auto Click step from the generated hub in the situations from the log."""
import pathlib
import sys

v3 = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
start = v3.index('local held = getChar() and getChar():FindFirstChildOfClass("Tool")')
end = v3.index("attack()\n", start) + len("attack()\n")
body = v3[start:end]

TEST = r'''
local S, equips, attacks, busy, heldTool = { BringMobs = false }, 0, 0, false, nil
local function getChar() return { FindFirstChildOfClass = function() return heldTool end } end
local function equipWeapon() equips += 1 end
local function attack() attacks += 1 end
local function mainFarmBusy() return busy end
local function getRoot() return { Position = { X = 0, Y = 0, Z = 0 } } end
local function bringMobs() end
local function mobBaseName(n) return n end
local CFrame = { lookAt = function() return {} end, new = function() return {} end }
local Vector3 = { new = function() return {} end }
local mob = { Name = "Zombie", HumanoidRootPart = { Position = { X = 1, Y = 1, Z = 1 } } }
local function step()
''' + body + r'''
end
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local function run() equips, attacks = 0, 0; step() end

heldTool = { Name = "Dragon-Dragon" }
run()
check("no farm, fruit in hand: keeps the fruit and attacks", equips == 0 and attacks == 1)
heldTool = nil
run()
check("no farm, empty hand: does not pull out melee", equips == 0 and attacks == 0)
busy = true
run()
check("farm on, empty hand: equips so the farm can hit", equips == 1 and attacks == 1)
heldTool = { Name = "Dragon-Dragon" }
run()
check("farm on, tool in hand (mastery weapon): not swapped", equips == 0 and attacks == 1)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

pathlib.Path(sys.argv[1]).write_text(TEST, encoding="utf-8")
