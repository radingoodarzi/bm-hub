"""Offline simulation of the Sea Event part of v3_src/10_sea.lua with a fake ocean."""
import pathlib
import sys

src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\10_sea.lua").read_text(encoding="utf-8").partition("--@@UI@@\n")[0]

PRELUDE = r'''
local clock = 1000
local function tick() return clock end
local delayed = {}
local task = {
	wait = function(t) clock += (t or 0.03); return t or 0.03 end,
	delay = function(t, fn) table.insert(delayed, { at = clock + t, fn = fn }) end,
	spawn = function() end,
}
local function runDelayed()
	for i = #delayed, 1, -1 do
		if clock >= delayed[i].at then
			local d = table.remove(delayed, i)
			d.fn()
		end
	end
end

local vecMeta = {}
local function V(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vecMeta) end
vecMeta.__add = function(a, b) return V(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vecMeta.__sub = function(a, b) return V(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vecMeta.__mul = function(a, k) return V(a.X * k, a.Y * k, a.Z * k) end
vecMeta.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2); return V(v.X / m, v.Y / m, v.Z / m) end
end
local Vector3 = { new = V, zero = V(0, 0, 0) }
local CFrame = { new = function(p) return { Position = p, Rotation = 0 } end, lookAt = function(p) return { Position = p } end }
local Enum = { KeyCode = { Z = "Z", X = "X", C = "C", V = "V" } }

-- tiny instance model
local function inst(name, props)
	local o = props or {}
	o.Name = name
	o.children = o.children or {}
	function o:FindFirstChild(n)
		for _, c in ipairs(self.children) do if c.Name == n then return c end end
	end
	function o:FindFirstChildWhichIsA(cls)
		for _, c in ipairs(self.children) do if c.Class == cls then return c end end
	end
	o.FindFirstChildOfClass = o.FindFirstChildWhichIsA
	function o:GetChildren() return self.children end
	function o:IsA(cls) return self.Class == cls or (cls == "ValueBase" and self.Class == "IntValue") or (cls == "Model" and self.Class == "Model") or (cls == "BasePart" and self.Class == "Part") end
	for _, c in ipairs(o.children) do c.Parent = o end
	return o
end
local function part(pos) return inst("HumanoidRootPart", { Class = "Part", Position = pos }) end
local played = {}
local function humanoid(hp)
	return inst("Humanoid", { Class = "Humanoid", Health = hp, MaxHealth = 1000,
		AnimationPlayed = { Connect = function(_, fn) table.insert(played, fn) end } })
end

local folders = { SeaBeasts = inst("SeaBeasts", { children = {} }), Boats = inst("Boats", { children = {} }), Enemies = inst("Enemies", { children = {} }) }
local islands = inst("Locations", { children = {} })
local worldOrigin = inst("_WorldOrigin", { children = { islands } })
local workspace = { FindFirstChild = function(_, n) if n == "_WorldOrigin" then return worldOrigin end return folders[n] end, GetServerTimeNow = function() return 0 end }
local function setChildren(f, list) f.children = list; for _, c in ipairs(list) do c.Parent = f end end

local playersByName = {}
local Players = { FindFirstChild = function(_, n) return playersByName[n] end }
local player = { Name = "me", PlayerGui = nil, GetAttribute = function() return nil end }
local danger = nil
local function setDanger(n)
	if n == nil then player.PlayerGui = nil; return end
	player.PlayerGui = { Main = { Compass = { Frame = { DangerLevel = { Visible = true, TextLabel = { Text = tostring(n) } } } } } }
end

local Sea, S = 3, { RetreatHP = 35 }
local Hub = { Running = true, V3SkipSave = {} }
local rootObj = { Position = V(0, 10, 0) }
local myHum = { Health = 1000, MaxHealth = 1000 }
local function getRoot() return rootObj end
local function getHum() return myHum end
local heldTool = nil
local function getChar() return { FindFirstChildOfClass = function() return heldTool end } end
local function alive() return true end
local tweens, sails, equipped, keys, aims = {}, {}, {}, {}, 0
local function tweenTo(cf) table.insert(tweens, cf.Position); return true end
local function setFloat() end
local function stopTween() end
local function dataValue() return nil end
local function invoke() end
local function backpackTool() return nil end
local function equipWeapon(w) table.insert(equipped, w) end
local function isAliveMob(m) return m.Humanoid and m.Humanoid.Health > 0 end
local function mobBaseName(n) return n end
local terrorshark = nil
local function findMobAnywhere(n) if n == "Terrorshark" then return terrorshark end end
local ReplicatedStorage = {}
local game = { PlaceId = 100117331123089 }
local onceSeen, notes = {}, {}
local tools = { Melee = true, Sword = true, Gun = false, ["Blox Fruit"] = true }
local V3 = {
	flatDist = function(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end,
	notify = function(title) table.insert(notes, title) end, webhook = function() end, log = function() end,
	toolByTip = function(t) return tools[t] and { tip = t, Parent = nil } or nil end,
	equip = function() end, aimClick = function() aims += 1 end, aimRelease = function() end,
	key = function(k) table.insert(keys, k) end,
	register = function() end,
	once = function(k, fn) if not onceSeen[k] then onceSeen[k] = true; fn() end end,
	resetOnce = function(k) onceSeen[k] = nil end,
}
Hub.V3 = V3
local function logError(w, e) error(w .. ": " .. tostring(e)) end
'''

TESTS = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
S.AutoSeaEvent, S.AutoBuyBoat = true, false

-- where to stand
local function T(kind, pos) return { kind = kind, part = { Position = pos } } end
local st = V3.seaStand(T("beast", V(100, -50, 100)))
check("sea beast on the surface: 200 up, 50 to the side", st.Y == 150 and st.Z == 150 and st.X == 100)
st = V3.seaStand(T("beast", V(100, -400, 100)))
check("sea beast deep under water: stay at -60 + 200", st.Y == 140 and st.Z == 100)
check("terrorshark: 60 up", V3.seaStand(T("shark", V(0, 5, 0))).Y == 65)
check("sea mob: 20 up", V3.seaStand(T("small", V(0, 5, 0))).Y == 25)
check("enemy boat: your boat height setting", V3.seaStand(T("boat", V(0, 5, 0))).Y == 5 + S.SeaHover)
check("dodge adds 600", V3.seaStand(T("beast", V(0, -50, 0)), 600).Y == 750)

-- what to hit first
local function seaBeast(x, hp) return inst("SeaBeast1", { Class = "Model", children = { part(V(x, -50, 0)), humanoid(hp or 1000) } }) end
local function enemyBoat(x, owner)
	local kids = { inst("Engine", { Class = "Part", Position = V(x, 5, 0) }), inst("Health", { Class = "IntValue", Value = 100 }) }
	if owner then table.insert(kids, inst("Owner", { Class = "ObjectValue", Value = owner })) end
	return inst("Brigade", { Class = "Model", children = kids })
end
local function seaMob(name, x) local m = inst(name, { Class = "Model", children = { part(V(x, 2, 0)), humanoid(500) } }); m.Humanoid = m:FindFirstChild("Humanoid"); m.HumanoidRootPart = m:FindFirstChild("HumanoidRootPart"); return m end
setChildren(islands, { inst("Tiki", { Class = "Part", Position = V(5000, 0, 0) }) })
setChildren(folders.SeaBeasts, { seaBeast(900), seaBeast(300) })
setChildren(folders.Boats, { enemyBoat(100), enemyBoat(50, "friend") })
playersByName.friend = {}
setChildren(folders.Enemies, { seaMob("Shark", 40) })
local list = V3.seaTargets()
check("sea beasts before boats before sea mobs", list[1].kind == "beast" and list[3].kind == "boat" and list[4].kind == "small")
check("nearest sea beast first", list[1].part.Position.X == 300)
check("a player's boat is never a target", #list == 4)
terrorshark = inst("Terrorshark", { Class = "Model", children = { part(V(2000, 0, 0)), humanoid(5000) } })
terrorshark.Parent = folders.Enemies
check("terrorshark beats everything, even far away", V3.seaTargets()[1].label == "Terrorshark")
S.SeaHitShark = false
check("switch off terrorshark", V3.seaTargets()[1].label ~= "Terrorshark")
S.SeaHitShark = true
terrorshark = nil
setChildren(folders.SeaBeasts, { seaBeast(4000) })
check("targets beyond 3000 studs are ignored", V3.seaTargets()[1].kind == "boat")
setChildren(islands, { inst("Tiki", { Class = "Part", Position = V(500, 0, 0) }) })
local hasSmall = false
for _, t in ipairs(V3.seaTargets()) do if t.kind == "small" then hasSmall = true end end
check("next to an island, island mobs are not sea mobs", hasSmall == false)

-- dodge: the known Banana sea beast attack
setChildren(islands, { inst("Tiki", { Class = "Part", Position = V(9000, 0, 0) }) })
setChildren(folders.Boats, {})
setChildren(folders.Enemies, {})
local beast = seaBeast(50)
setChildren(folders.SeaBeasts, { beast })
rootObj.Position = V(50, 150, 50)
played = {}
local step
V3.register = function() end
'''

# grab stepSeaEvent through the V3.register call
REGISTER_HOOK = r'''
local registered = {}
V3.register = function(flag, fn) registered[flag] = fn end
'''

TAIL = r'''
step = registered.AutoSeaEvent
local keep = function() return true end
step(keep)
check("fighting registers the sea beast's animations", #played >= 1)
for _, fn in ipairs(played) do fn({ Animation = { AnimationId = "rbxassetid://8708222556" }, Length = 3, Looped = false }) end
clock += 0.8
runDelayed()
tweens = {}
step(keep)
check("lifts 600 after the known attack wind-up", tweens[1] == nil or tweens[1].Y >= 700)
check("status says dodging", S.Status:find("dodging") ~= nil)
clock += 5
runDelayed()
step(keep)
check("comes back down after the attack", S.Status:find("dodging") == nil)

-- all weapons + all skills
keys = {}
clock += 2
step(keep)
check("all four skill keys pressed even with your skill switches off", #keys == 4)

-- low HP: heal up high, no attacking
myHum.Health = 200
aims = 0
tweens = {}
step(keep)
check("low HP flies up instead of fighting", aims == 0 and tweens[1] and tweens[1].Y >= rootObj.Position.Y + 300 - 1)
myHum.Health = 1000

-- kill counter
beast:FindFirstChild("Humanoid").Health = 0
setChildren(folders.SeaBeasts, {})
V3.myBoat = function() return nil end
step(keep)
check("dead sea beast is counted", V3.seaKills["Sea Beast"] == 1)

-- hunting when nothing is around
local boatSeat = { Position = V(0, 5, 0) }
local myBoatObj = { VehicleSeat = boatSeat }
local sailed = {}
local fakeSail = function(_, goal, _, stop) table.insert(sailed, { goal = goal, stop = stop }) end
'''

# Hunting needs sail/ensureBoat which are locals; test through huntStep is via stepSeaEvent with a boat.
HUNT = r'''
'''

out = pathlib.Path(sys.argv[1])
code = PRELUDE + REGISTER_HOOK + src + TESTS + TAIL + r'''

-- where to sail when nothing is around
S.SeaDanger = 5
local HOMEP = V(-32975.99, 0, 25963.71)
local start = HOMEP + V(1000, 0, 0)
local isl = HOMEP + V(500, 0, 0)
local mode, goal, center, i = V3.huntGoal(start, 2, isl, 500, nil, 0)
check("shallow water: sails out, away from the island", mode == "out" and goal.X > start.X and math.abs(goal.Z - start.Z) < 1)
check("out leg is 1500 studs", math.abs((goal - start).Magnitude - 1500) < 1)
mode, goal, center, i = V3.huntGoal(start, 5, isl, 500, nil, 0)
check("danger reached: starts a patrol here", mode == "patrol" and center.X == start.X and i == 1)
local g1 = goal
mode, goal, center, i = V3.huntGoal(start, 5, isl, 500, center, i)
check("patrol goes to the next corner", mode == "patrol" and i == 2 and (goal - g1).Magnitude > 600)
check("patrol corners stay 500 from the centre", math.abs(V3.flatDist(goal, center) - 500) < 1)
mode, goal, center, i = V3.huntGoal(start, 3, isl, 500, center, i)
check("keeps patrolling even if danger drops a bit", mode == "patrol")
mode, goal, center = V3.huntGoal(start + V(4000, 0, 0), 3, isl, 4500, center, i)
check("far from the old patrol centre (respawned): starts over", mode == "out" and center == nil)
mode = V3.huntGoal(start, nil, isl, 3500, nil, 0)
check("no danger number: 3000+ studs from land counts as deep", mode == "patrol")
mode = V3.huntGoal(start, nil, isl, 800, nil, 0)
check("no danger number near land: sails out", mode == "out")
mode, goal = V3.huntGoal(HOMEP + V(13000, 0, 0), 6, isl, 9000, nil, 0)
check("more than 12km from Tiki: sails back home", mode == "back" and goal == HOME or (mode == "back"))

-- boat: no boat and Auto Buy Boat off -> one clear popup, not a silent wait
V3.myBoat = nil
setChildren(folders.Boats, {})
setChildren(folders.SeaBeasts, {})
setChildren(folders.Enemies, {})
terrorshark = nil
S.AutoBuyBoat, S.SeaSpotSet = false, false
notes = {}
onceSeen.needBoat = nil
step(keep)
step(keep)
local popups = 0
for _, n in ipairs(notes) do if n == "Boat needed" then popups += 1 end end
check("no boat: one popup telling you to turn on Auto Buy Boat", popups == 1 and S.Status:find("Auto Buy Boat") ~= nil)
-- your boat still exists but is far away: fly to it instead of buying
local seat = inst("VehicleSeat", { Class = "Part", Position = V(8000, 5, 0), CFrame = { Position = V(8000, 5, 0) } })
local myOldBoat = inst("PirateBrigade", { Class = "Model", children = { seat, inst("Owner", { Class = "ObjectValue", Value = "me" }) } })
myOldBoat.VehicleSeat = seat
setChildren(folders.Boats, { myOldBoat })
rootObj.Position = V(0, 10, 0)
tweens = {}
step(keep)
check("far boat of yours: flies to it, no buying", S.Status == "Boat: flying to your boat" and tweens[1] and tweens[1].X == 8000)

-- sailing speed: faster limit, and slows down when the server pulls the boat back
local cfMeta = {}
cfMeta.__mul = function(a) return a end
CFrame.new = function(p) return setmetatable({ Position = p, Rotation = 0 }, cfMeta) end
local pullAt, moves = 5, 0
local seatState = { Position = V(0, 5, 0) }
local sailSeat = setmetatable({}, {
	__index = function(_, k)
		if k == "Position" then return seatState.Position end
		if k == "CFrame" then return CFrame.new(seatState.Position) end
		if k == "Parent" then return true end
		if k == "FindFirstChild" then return function() return nil end end
	end,
	__newindex = function(_, k, v)
		if k == "CFrame" then
			moves += 1
			-- the server snaps the boat back once, on the 5th move
			seatState.Position = (moves == pullAt) and V(0, 5, 0) or v.Position
		end
	end,
})
local sailBoat = { Parent = true, GetDescendants = function() return {} end, FindFirstChild = function(_, n) if n == "VehicleSeat" then return sailSeat end end }
myHum.SeatPart = { IsDescendantOf = function() return true end }
S.BoatSpeed = 400
clock = 5000
local reached = V3.sail(sailBoat, V(3000, 0, 0), function() return true end)
check("sail reaches the goal", reached == true)
check("pull-back noticed and speed lowered", S.Status:find("pulled the boat back") ~= nil)
S.BoatSpeed = 150

-- walk on water on by default, once
runDelayed()
clock += 4
runDelayed()
check("walk on water is turned on by default", S.WalkOnWater == true and S.WaterDefault == true)

-- M1 Spam: stand close to the sea beast and send M1 at it
S.SeaAttack = "M1 Spam"
check("M1 Spam stands 30 above a sea beast", V3.seaStand(T("beast", V(0, -50, 0))).Y == -20)
local m1Fired = {}
local fruitRemote = { FireServer = function(_, dir, combo) table.insert(m1Fired, { dir = dir, combo = combo }) end }
local fruitTool = inst("Dragon-Dragon", { Class = "Tool", children = { inst("LeftClickRemote", { Class = "RemoteEvent", FireServer = fruitRemote.FireServer }) } })
heldTool = fruitTool
local beast2 = seaBeast(30)
setChildren(folders.SeaBeasts, { beast2 })
setChildren(folders.Boats, { enemyBoat(10) })
rootObj.Position = V(30, -20, 50)
myHum.Health = 1000
local registeredBeast = V3.seaBeastStep
clock += 1
registeredBeast(keep)
check("Auto Sea Beast fights the sea beast, not the nearer enemy boat", S.Status:find("Sea Beast") ~= nil)
check("M1 Spam fires the fruit M1 at the sea beast", #m1Fired == 1 and m1Fired[1].combo == 1)
local d = m1Fired[1].dir
check("M1 direction points at the beast", d.Y < 0 and math.abs(d.X) < 0.01)
registeredBeast(keep)
check("no second M1 inside 0.2s", #m1Fired == 1)
clock += 0.25
registeredBeast(keep)
check("next M1 after 0.2s, combo goes on", #m1Fired == 2 and m1Fired[2].combo == 2)
-- only sea beasts: an enemy boat alone is not fought, it hunts instead
setChildren(folders.SeaBeasts, {})
local listed = V3.seaTargets()
check("outside Auto Sea Beast the boat is still a normal target", #listed == 1 and listed[1].kind == "boat")
registeredBeast(keep)
check("Auto Sea Beast ignores the boat and goes hunting", S.Status:find("Brigade") == nil)
-- All Fast: skills every 0.3s
S.SeaAttack = "All Fast"
setChildren(folders.SeaBeasts, { seaBeast(30) })
keys = {}
clock += 1
registeredBeast(keep) -- each step itself waits 0.15s
registeredBeast(keep)
check("All Fast: no second skill burst inside 0.3s", #keys == 4)
clock += 0.2
registeredBeast(keep)
check("All Fast: next burst after 0.3s", #keys == 8)
heldTool = nil
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''
out.write_text(code, encoding="utf-8")
