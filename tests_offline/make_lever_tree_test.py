"""Offline test of the Pull Lever block (30_trials) and the tree block (20_volcano)."""
import pathlib
import sys

root = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src")
tr = (root / "30_trials.lua").read_text(encoding="utf-8")
vo = (root / "20_volcano.lua").read_text(encoding="utf-8")
lever = tr[tr.index("\tlocal leverTries = 0"):tr.index("\t-----------------------------------------------------------------\n\t-- Observation V2")]
trees = vo[vo.index("\t-- همه‌ی اسکیل‌ها"):vo.index("\tlocal function stepQuest(keep)")]

PRELUDE = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local NOW = 0
local function tick() return NOW end
local vmeta = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vmeta) end
vmeta.__sub = function(a, b) local d = vec(a.X-b.X, a.Y-b.Y, a.Z-b.Z); return d end
vmeta.__add = function(a, b) return vec(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vmeta.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end end
local Vector3 = { new = vec }
local function cf(p, look) return setmetatable({ Position = p, LookVector = look or vec(0, 0, -1) }, { __mul = function(a, b) return cf(a.Position + (b.Position or vec(0,0,0))) end }) end
local CFrame = { new = function(x, y, z) if type(x) == "table" then return cf(x) end return cf(vec(x or 0, y or 0, z or 0)) end }
local S = { Status = "" }
local Hub = { V3 = {}, Running = true }
local V3 = Hub.V3
local notes, logs, keys, aims = {}, {}, 0, 0
V3.notify = function(t, m) table.insert(notes, m) end
V3.log = function(m) table.insert(logs, m) end
V3.key = function() keys += 1 end
V3.aimClick = function() aims += 1 end
V3.aimRelease = function() end
local root = { Position = vec(0, 0, 0) }
local function getRoot() return root end
local function alive() return true end
local function setFloat() end
local function equipWeapon() end
local function tweenTo(c) root.Position = c.Position end
local TEMPLE_POS = vec(28282, 14896, 105)
local ITEMS = {}
local function hasItem(n) return ITEMS[n] == true end
local DOOR, V4 = true, nil
local function invoke(a) if a == "CheckTempleDoor" then return DOOR end if a == "RaceV4Progress" then return V4 end end
local v4steps = 0
local function stepV4() v4steps += 1 end

-- fake instances
local function inst(name, class, kids, props)
	local o = { Name = name, ClassName = class, _kids = kids or {}, Parent = nil, _attr = {} }
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(o._kids) do c.Parent = o end
	function o:IsA(c) return self.ClassName == c or (c == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart")) end
	function o:FindFirstChild(n, rec)
		for _, c in ipairs(self._kids) do if c.Name == n then return c end end
		if rec then for _, c in ipairs(self._kids) do local r = c:FindFirstChild(n, true); if r then return r end end end
	end
	function o:FindFirstChildWhichIsA(cl, rec)
		for _, c in ipairs(self._kids) do if c:IsA(cl) then return c end end
		if rec then for _, c in ipairs(self._kids) do local r = c:FindFirstChildWhichIsA(cl, true); if r then return r end end end
	end
	function o:GetDescendants()
		local out = {}
		for _, c in ipairs(self._kids) do table.insert(out, c); for _, d in ipairs(c:GetDescendants()) do table.insert(out, d) end end
		return out
	end
	function o:FindFirstAncestorWhichIsA(cl) local p = self.Parent while p do if p:IsA(cl) then return p end p = p.Parent end end
	function o:GetAttribute(k) return self._attr[k] end
	function o:GetPivot() return self.pivot or cf(vec(0,0,0)) end
	function o:GetFullName() return self.Name end
	return o
end
V3.findDesc = function(r, n) return r and r:FindFirstChild(n, true) end
local prompt = inst("ProximityPrompt", "ProximityPrompt", {}, { Enabled = true })
local handle = inst("Lever", "Part", {}, { CFrame = cf(vec(10, 0, 0)) })
local leverPart = inst("Part", "Part", {}, { Position = vec(10, 0, 0), CFrame = cf(vec(10, 0, 0)) })
local leverModel = inst("Lever", "Model", { handle, leverPart, inst("Prompt", "Model", { prompt }) })
local templeModel = inst("Temple of Time", "Model", { leverModel })
local TEMPLE_LOADED = false
local function temple() return TEMPLE_LOADED and templeModel or nil end
local PULL_MOVES = true
V3.activate = function(p) if PULL_MOVES then handle.CFrame = cf(vec(10, 0, 3)) end return true end
Hub.MirageModel = function() return nil end
local task = { wait = function(s) NOW += (s or 0.03) end }
local workspace
'''

TESTS = r'''
local keep = function() return true end
-- lever
S.AutoPullLever = true
stepLever(keep)
check("no Valkyrie Helm -> off with a message", S.AutoPullLever == false and notes[#notes]:find("Valkyrie") ~= nil)
ITEMS["Valkyrie Helm"] = true
S.AutoPullLever = true
stepLever(keep)
check("door open, temple not loaded -> flies to the temple", root.Position.X == 28282)
TEMPLE_LOADED = true
stepLever(keep)
check("goes to the lever", (root.Position - leverPart.Position).Magnitude < 1)
stepLever(keep)
check("pulls it, lever moved -> done and off", S.AutoPullLever == false and notes[#notes]:find("pulled") ~= nil)
-- lever that does not move: 3 tries then gives up
handle.CFrame = cf(vec(10, 0, 0)); PULL_MOVES = false; S.AutoPullLever = true
local pf = prompt
V3.activate = function() return true end
for i = 1, 3 do stepLever(keep) end
check("3 tries without movement -> off with a hint", S.AutoPullLever == false and notes[#notes]:find("3 times") ~= nil)
-- prompt disabled = already pulled
prompt.Enabled = false; S.AutoPullLever = true
stepLever(keep)
check("prompt gone -> already pulled", S.AutoPullLever == false and notes[#notes]:find("already") ~= nil)
-- door closed: Race V4 progress first
DOOR, V4 = false, 2; S.AutoPullLever = true
stepLever(keep)
check("door closed + V4 step pending -> runs the V4 step", v4steps == 1)
V4 = 0
stepLever(keep)
check("door closed, no Mirage -> waits with a hint", S.Status:find("Mirage") ~= nil and S.AutoPullLever == true)

-- trees
local leafy = inst("Tree1", "Model", { inst("Meshes/plant1_Icosphere", "MeshPart") }, { pivot = cf(vec(100, 0, 0)) })
local far = inst("Tree2", "Model", { inst("Meshes/plant1_Icosphere", "MeshPart") }, { pivot = cf(vec(900, 0, 0)) })
local broken = inst("Tree3", "Model", { inst("Meshes/plant1_Icosphere", "MeshPart") }, { pivot = cf(vec(50, 0, 0)) })
broken._attr.AlreadyDestroyedClient = true
local map = inst("Map", "Folder", { leafy, far, broken })
workspace = map
root.Position = vec(0, 0, 0)
local t = findTree()
check("nearest standing tree (skips destroyed)", t == leafy)
-- chop: tree breaks after a while
local calls = 0
local oldAim = V3.aimClick
V3.aimClick = function(p) aims += 1; calls += 1; if calls >= 4 then leafy._attr.AlreadyDestroyedClient = true end end
chopTree(leafy, keep)
check("chops with skills until it breaks", keys > 0 and calls >= 4 and leafy._attr.AlreadyDestroyedClient)
check("next tree is the far one", findTree() == far)
-- a tree that never breaks: stops after 15 s
NOW = 0
V3.aimClick = function() end
local t0 = NOW
chopTree(far, keep)
check("gives up a stuck tree after ~15 s", NOW - t0 >= 15 and NOW - t0 < 17)
check("no more trees", findTree() == nil)
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

pathlib.Path(sys.argv[1]).write_text(PRELUDE + "do\n" + lever + trees + TESTS + "\nend\n", encoding="utf-8")
