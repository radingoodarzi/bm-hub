"""Offline test of v3_src/80_move.lua (real speed and jump)."""
import pathlib
import sys

src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\80_move.lua").read_text(encoding="utf-8").partition("--@@UI@@\n")[0]

PRELUDE = r'''
local vecMeta = {}
local function V(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vecMeta) end
vecMeta.__add = function(a, b) return V(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vecMeta.__mul = function(a, k) return V(a.X * k, a.Y * k, a.Z * k) end
vecMeta.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2); return V(v.X / m, v.Y / m, v.Z / m) end
end
local Vector3 = { new = V }
local Enum = { Material = { Air = "Air", Grass = "Grass" } }
local workspace = { Gravity = 196.2 }
local task = { defer = function(fn) fn() end }
local S, Hub = { WalkSpeed = 100, JumpPower = 80 }, {}
local root = { AssemblyLinearVelocity = V(16, 0, 0), CFrame = V(0, 0, 0) }
local hum = { MoveDirection = V(1, 0, 0), SeatPart = nil, FloorMaterial = "Grass" }
local function getRoot() return root end
local function getHum() return hum end
local activeTween = nil
local farming = false
local function anyFarm() return farming end
local beat, jumpFn
local RunService = { Heartbeat = "hb" }
local UserInputService = { JumpRequest = "jr" }
local function connect(sig, fn) if sig == "hb" then beat = fn else jumpFn = fn end end
local function logError(w, e) error(w .. ": " .. tostring(e)) end
'''

TESTS = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local M = Hub.Move
check("extra = target minus real speed", M.extra(100, 16, true) == 84)
check("nothing added when standing still", M.extra(100, 16, false) == 0)
check("never slows you down", M.extra(100, 140, true) == 0)

S.SpeedOn = false
beat(0.1)
check("switch off: no extra movement", root.CFrame.X == 0)
check("real speed is measured", M.speed == 16)
S.SpeedOn = true
beat(0.1)
check("game holds you at 16: pushed forward to reach 100", math.abs(root.CFrame.X - 8.4) < 1e-6)
root.CFrame = V(0, 0, 0)
root.AssemblyLinearVelocity = V(100, 0, 0)
beat(0.1)
check("already at 100: nothing added", root.CFrame.X == 0)
root.AssemblyLinearVelocity = V(16, 0, 0)
hum.SeatPart = { IsA = function() return false end }
beat(0.1)
check("sitting on a boat: untouched", root.CFrame.X == 0)
hum.SeatPart = nil
activeTween = {}
beat(0.1)
check("while the hub is flying: untouched", root.CFrame.X == 0)
activeTween = nil
farming = true
beat(0.1)
check("while a farm runs: untouched", root.CFrame.X == 0)
farming = false
hum.MoveDirection = V(0, 0, -1)
beat(0.1)
check("follows the direction you walk", root.CFrame.Z < 0 and root.CFrame.X == 0)

S.JumpOn = false
check("jump switch off: normal jump", jumpFn() == false)
S.JumpOn = true
root.AssemblyLinearVelocity = V(5, 0, 0)
check("on the ground: jump boosted", jumpFn() == true and root.AssemblyLinearVelocity.Y == 80 and root.AssemblyLinearVelocity.X == 5)
hum.FloorMaterial = "Air"
root.AssemblyLinearVelocity = V(0, -10, 0)
check("in the air: no extra jump", jumpFn() == false and root.AssemblyLinearVelocity.Y == -10)
S.InfJump = true
check("in the air with Infinite Jump: boosted", jumpFn() == true and root.AssemblyLinearVelocity.Y == 80)
check("jump height shown (80 -> 16 studs)", M.jumpHeight() == 16)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

pathlib.Path(sys.argv[1]).write_text(PRELUDE + src + TESTS, encoding="utf-8")
