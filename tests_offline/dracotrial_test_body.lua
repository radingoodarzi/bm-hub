local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
local NOW = 0
local function tick() return NOW end
local os = { date = function() return "00:00:00" end }
local vm = {}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vm) end
vm.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__index = function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local Vector3 = { new = vec }
local cm = {}
local function cf(p) return setmetatable({Position=p, X=p.X, Y=p.Y, Z=p.Z}, cm) end
cm.__mul = function(a,b) return cf(a.Position + b.Position) end
local CFrame = { new = function(x,y,z) if type(x)=="table" then return cf(x) end return cf(vec(x,y,z)) end }
local function inst(name, class, props)
	local o = { Name = name, ClassName = class or "Model", _kids = {}, _attrs = {} }
	for k, v in pairs(props or {}) do o[k] = v end
	function o:GetChildren() return self._kids end
	function o:GetDescendants() local out = {} local function r(x) for _, c in ipairs(x._kids) do table.insert(out, c); r(c) end end r(self) return out end
	function o:FindFirstChild(n, rec)
		for _, c in ipairs(self._kids) do if c.Name == n then return c end end
		if rec then for _, d in ipairs(self:GetDescendants()) do if d.Name == n then return d end end end
	end
	function o:FindFirstChildWhichIsA(cl, rec) for _, d in ipairs(rec and self:GetDescendants() or self._kids) do if d.ClassName == cl then return d end end end
	function o:IsA(cl) return self.ClassName == cl or (cl == "BasePart" and self.ClassName == "Part") end
	function o:GetPivot() return self._cf end
	function o:GetAttributes() return self._attrs end
	return o
end
local function add(parent, child) table.insert(parent._kids, child); child.Parent = parent; return child end
local root = { Position = vec(0, 0, 0) }
local function getRoot() return root end
local ON_TWEEN
local function tweenTo(c) root.Position = c.Position; if ON_TWEEN then ON_TWEEN(c) end end
local S = { Status = "" }
local Hub = { Running = true, V3 = {} }
local notes = {}
local tasks = {}
Hub.V3.register = function(flag, step) tasks[flag] = step end
Hub.V3.notify = function(t, m) table.insert(notes, m) end
Hub.V3.webhook = function() end
Hub.V3.log = function() end
local TIMER = false
local player = { PlayerGui = { Main = { TopHUDList = setmetatable({}, { __index = function(_, k) return { Visible = (k == "RaidTimer" and TIMER) } end }) } } }
local RACE = "Draco"
local function dataValue(k) if k == "Race" then return RACE end end
local Sea = 3
local function writefile() end
local function logError(w, e) print("ERR", w, e); fails += 1 end
local task = { wait = function(s) NOW += (s or 0.03) end }
local Map = inst("Map", "Folder")
local workspace = inst("Workspace", "Workspace")
add(workspace, Map)
local WO = add(workspace, inst("_WorldOrigin", "Folder"))
local LOCS = add(WO, inst("Locations", "Folder"))
add(LOCS, inst("Trial of Flames", "Part", { Position = vec(10000, 0, 0) }))
local Trial = add(Map, inst("DracoTrial", "Model", { _cf = cf(vec(10000, 0, 0)) }))
local Door = add(Trial, inst("TrialDoor", "Model"))
local DoorTouch = add(Door, inst("DoorTouch", "Part", { CFrame = cf(vec(10050, 0, 0)), Position = vec(10050, 0, 0) }))
local CARRY
for i = 1, 3 do
	local pick = add(Trial, inst("Relic" .. i, "Model", { _cf = cf(vec(10000 + i * 100, 0, 100)) }))
	local pp = add(pick, inst("ProximityPrompt", "ProximityPrompt", { Enabled = true }))
	local place = add(Trial, inst("EndRelic" .. i, "Model", { _cf = cf(vec(10000 + i * 100, 0, -100)) }))
	local ep = add(place, inst("ProximityPrompt", "ProximityPrompt", { Enabled = false }))
	add(Trial, inst("RelicModel" .. i, "Model", { _cf = cf(vec(10000 + i * 100, 0, 100)) }))
	pp._idx, ep._idx, pp._kind, ep._kind = i, i, "pick", "place"
end
local function allPlaced()
	for i = 1, 3 do
		if (Trial:FindFirstChild("RelicModel" .. i)._cf.Position - Trial:FindFirstChild("EndRelic" .. i)._cf.Position).Magnitude > 1 then return false end
	end
	return true
end
local function fireprompt(p)
	local i = p._idx
	if (root.Position - p.Parent._cf.Position).Magnitude >= 12 then return end
	if p._kind == "pick" and p.Enabled and not CARRY then
		CARRY = i; p.Enabled = false
		Trial:FindFirstChild("EndRelic" .. i):FindFirstChild("ProximityPrompt").Enabled = true
	elseif p._kind == "place" and p.Enabled and CARRY == i then
		Trial:FindFirstChild("RelicModel" .. i)._cf = Trial:FindFirstChild("EndRelic" .. i)._cf
		p.Enabled = false; CARRY = nil
		if allPlaced() then add(DoorTouch, inst("TouchInterest", "TouchTransmitter")) end
	end
end
local STARTS = 0
local START_WORKS = true
local ReplicatedStorage = { Remotes = { DracoTrial = { InvokeServer = function() STARTS += 1; if START_WORKS then TIMER = true end end } } }
local ISL
local volcanoSteps = 0
Hub.V3.prehistoricIsland = function() return ISL end
Hub.V3.stepVolcano = function() volcanoSteps += 1; S.Status = "Volcano: fighting the golem" end
Hub.V3.activate = function(p) if p and p.ClassName == "ProximityPrompt" then fireprompt(p) return true end return false end
--@@MODULE@@
local DT = Hub.V3.DracoTrial
check("index from names", DT.index("RelicModel3") == 3 and DT.index("EndRelic12") == 12)
local a, i = DT.next({ { i = 1, placed = true }, { i = 2, pickOn = true }, { i = 3, placeOn = true } }, nil)
check("next: carrying (place prompt on) -> place first", a == "place" and i == 3)
a, i = DT.next({ { i = 1, placed = true }, { i = 2, pickOn = true } }, nil)
check("next: then pick the next one", a == "pick" and i == 2)
a, i = DT.next({ { i = 1, placed = false } }, 1)
check("next: remembers what we picked even if prompts look off", a == "place" and i == 1)
a = DT.next({ { i = 1, placed = true }, { i = 2, placed = true } }, nil)
check("next: all placed -> wait", a == "wait")

local step = tasks.AutoDracoTrial
local keep = function() return S.AutoDracoTrial end

RACE = "Human"; S.AutoDracoTrial = true
step(keep)
check("not Draco race -> turns itself off", S.AutoDracoTrial == false)
RACE = "Draco"

S.AutoDracoTrial = true
step(keep)
check("no island -> runs the Prehistoric event (magnet/find/golems)", volcanoSteps == 1)

ISL = inst("PrehistoricIsland", "Model")
local Rock = add(ISL, inst("TrialRock", "Part", { Transparency = 0 }))
local TP = add(ISL, inst("TrialTeleport", "Part", { CFrame = cf(vec(500, 0, 500)), Position = vec(500, 0, 500) }))
step(keep)
check("rock closed -> keeps doing the event", volcanoSteps == 2 and S.Status:find("not open") ~= nil)

Rock.Transparency = 1
ON_TWEEN = function(c) if (c.Position - TP.Position).Magnitude < 1 then root.Position = vec(10000, 0, 0) end end
step(keep)
check("rock open -> uses the Trial Teleport", (root.Position - vec(10000, 0, 0)).Magnitude < 1)
ON_TWEEN = nil

for n = 1, 60 do
	if not S.AutoDracoTrial then break end
	step(keep)
end
check("started the trial with the remote", STARTS >= 1)
check("all 3 relics placed", allPlaced())
check("left through the door and turned off", S.AutoDracoTrial == false and DT.state.done)
check("said it is finished", notes[#notes]:find("finished") ~= nil)
print("status: " .. S.Status)

TIMER = false; START_WORKS = false; STARTS = 0
DoorTouch._kids = {}
for k = 1, 3 do Trial:FindFirstChild("RelicModel" .. k)._cf = Trial:FindFirstChild("Relic" .. k)._cf end
DT.state = { carrying = nil, placed = 0, started = 0, done = false }
root.Position = vec(10000, 0, 0)
S.AutoDracoTrial = true
for n = 1, 40 do if not S.AutoDracoTrial then break end step(keep) end
check("trial never starts -> stops with a reason", S.AutoDracoTrial == false and notes[#notes]:find("trained") ~= nil)

Sea = 1; S.AutoDracoTrial = true
step(keep)
check("not Sea 3 -> off", S.AutoDracoTrial == false)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
