"""Offline test of v5.1: raid start (late teleport), tween breaking on a game teleport, smart farm height."""
import pathlib
import sys

hub = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
helpers = hub[hub.index("\tlocal function raidIsland()"):hub.index("\ttask.spawn(function()\n\t\twhile Hub.Running do\n\t\t\ttask.wait(0.3)\n\t\t\tif S.AutoRaid")]
body_start = hub.index("\t\t\t\tlocal keep = function() return S.AutoRaid end\n\t\t\t\tlocal keepOut")
body_end = hub.index('\t\t\t\tif not ok then logError("AutoRaid", err) end')
body = hub[body_start:body_end]
tween = hub[hub.index("tweenTo = function(cf, keepGoing, manual)"):hub.index("\n---------------------------------------------------------------------\n-- Enemies")]
brain = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\50_brain.lua").read_text(encoding="utf-8")
height = brain[brain.index("\tlocal CAP_KEY"):brain.index("\tlocal Brain = {")]

PRELUDE = r'''
local fails = 0
local function check(name, cond)
	print((cond and "ok   " or "FAIL ") .. name)
	if not cond then fails += 1 end
end
local NOW = 0
local G = {}
local function tick() return NOW end
local vmeta = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vmeta) end
vmeta.__sub = function(a, b) return vec(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vmeta.__add = function(a, b) return vec(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
vmeta.__mul = function(a, s) return vec(a.X*s, a.Y*s, a.Z*s) end
vmeta.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
	if k == "Unit" then local m = math.sqrt(v.X^2 + v.Y^2 + v.Z^2); return vec(v.X/m, v.Y/m, v.Z/m) end
end
local Vector3 = { new = vec }
local cfmeta = {}
local function cf(p) return setmetatable({ Position = p, Rotation = 0 }, cfmeta) end
cfmeta.__mul = function(a, b) if type(b) == "number" then return a end return cf(a.Position + (b.Position or vec(0,0,0))) end
local CFrame = { new = function(x, y, z) if type(x) == "table" then return cf(x) end return cf(vec(x or 0, y or 0, z or 0)) end }
local function typeof(v) return (getmetatable(v) == vmeta) and "Vector3" or "CFrame" end
local S = { Status = "", TweenSpeed = 300, AutoRaid = true, AutoBuyChip = true, RaidType = "Flame", FarmHeight = 25 }
local Hub = { Running = true }
local MAX_SAFE_SPEED = 300
local activeTween
local function stopTween() end
local function setFloat() end
local function portalHop() end
local root = setmetatable({ Position = vec(0, 0, 0) }, {
	__index = function(t, k) if k == "CFrame" then return cf(rawget(t, "Position")) end end,
	__newindex = function(t, k, v) if k == "CFrame" then rawset(t, "Position", v.Position) else rawset(t, k, v) end end })
local function getRoot() return root end
local DEAD = false
local function alive() return not DEAD end
local tweenTo
-- world
local SCI = vec(-6561.4, 309.3, -4749.1)
local SCIENTIST = SCI
local RAID_AT = nil         -- time when the game teleports us in
local RAID_POS = vec(-5000, 300, 20000)
local CHIP = true
local clicked = false
local tweens = {}
local onTick = {}
local task = { wait = function(s)
	NOW += (s or 1/60)
	for _, f in ipairs(onTick) do f() end
	return s or 1/60
end, spawn = function() end }
table.insert(onTick, function()
	if RAID_AT and NOW >= RAID_AT and not G.TELEPORTED then
		G.TELEPORTED = true
		root.CFrame = cf(RAID_POS)   -- the game moves us
	end
end)
local function islandPart(i) return { CFrame = cf(RAID_POS + vec(i * 300, 0, 0)), Position = RAID_POS + vec(i * 300, 0, 0) } end
local ISLANDS = {}
local workspace = {
	_WorldOrigin = { Locations = { FindFirstChild = function(_, n) local i = tonumber(n:match("Island (%d)")); return i and ISLANDS[i] end } },
	FindFirstChild = function(self, n) if n == "_WorldOrigin" then return self._WorldOrigin end end,
	Map = { CircleIsland = { GetChildren = function() return {} end } },
}
workspace._WorldOrigin.FindFirstChild = function(self, n) if n == "Locations" then return self.Locations end end
local TIMER = false
local player = { PlayerGui = setmetatable({}, { __index = function() return { TopHUDList = { RaidTimer = { Visible = TIMER } } } end }) }
setmetatable(player.PlayerGui, { __index = function() return { TopHUDList = { RaidTimer = { Visible = TIMER } } } end })
local function getChar() return { GetChildren = function() return CHIP and { { Name = "Microchip", IsA = function() return true end } } or {} end, FindFirstChildOfClass = function() return nil end } end
player.FindFirstChild = function() return nil end
local BUTTON = { Position = vec(-6400, 300, -4700), CFrame = cf(vec(-6400, 300, -4700)), FindFirstChildOfClass = function() return {} end }
local function fireclickdetector() clicked = true; CHIP = false; RAID_AT = NOW + 8 end
local function dataValue() return 1500 end
local function invoke() CHIP = true end
local function isAliveMob() return false end
local function mobBaseName(n) return n end
local function killMob() end
local function logError(w, e) print("ERR", w, e); fails += 1 end
'''

TESTS = r'''
-- raid button found right away
local function raidButtonStub() return BUTTON end
local trace = {}
local function step()
	local ok, err = pcall(function()
''' + "\n".join("\t\t" + l for l in body.split("\n")) + r'''
	end)
	if not ok then print("STEP ERR", err); fails += 1 end
end
'''

TAIL = r'''
-- scenario: chip in hand, button reachable; raid teleport happens 8 s after the click, islands load 3 s later
raidButton = function() return BUTTON end
local wentToScientistAfterClick, minDistToSci = false, math.huge
local inRaidAt
for i = 1, 200 do
	if RAID_AT and NOW >= RAID_AT + 3 and not ISLANDS[1] then ISLANDS[1] = islandPart(1) end
	step()
	task.wait(0.3)
	if G.TELEPORTED then
		inRaidAt = inRaidAt or NOW
		local d = (root.Position - SCI).Magnitude
		if d < minDistToSci then minDistToSci = d end
	end
	if NOW > 80 then break end
end
check("clicked the raid button", clicked)
check("got teleported into the raid", G.TELEPORTED == true)
check("never flew back toward the Scientist after entering the raid", minDistToSci > 15000)
check("ended up at island 1", (root.Position - (ISLANDS[1].Position + vec(0, 60, 0))).Magnitude < 5)
check("waits on an empty island (patient status)", S.Status:find("waiting") ~= nil)
print("status: " .. S.Status)

-- tween: a game teleport mid-flight stops the tween instead of flying back
G.TELEPORTED = false
root.CFrame = cf(vec(0, 0, 0))
RAID_AT = NOW + 1
RAID_POS = vec(50000, 0, 0)
local reached = tweenTo(cf(vec(-3000, 0, 0)), function() return true end)
check("tween stops after a teleport (did not continue to the old goal)", not reached and (root.Position - RAID_POS).Magnitude < 50)
'''

HEIGHT = r'''
do
local held = { ToolTip = "Melee", Name = "Fishman Karate" }
local logs = {}
Hub.LiveLog = function(m) table.insert(logs, m) end
local function getChar() return { FindFirstChildOfClass = function() return held end } end
for k, v in pairs({ HeightCapMelee = 100, HeightCapSword = 100, HeightCapFruit = 100, HeightCapGun = 100 }) do S[k] = v end
''' + height + r'''
S.FarmHeight = 25
check("starts at Farm Height", math.min(S.FarmHeight, Hub.HeightCap()) == 25)
check("5.9: no damage never lowers the height, the mob is skipped", Hub.LowerHeight() == false and Hub.HeightCap() == 100)
held = { ToolTip = "Blox Fruit", Name = "Dragon-Dragon" }
check("other weapon types keep the full height", Hub.HeightCap() == 100)
Hub.ResetHeightCaps()
held = { ToolTip = "Melee", Name = "Fishman Karate" }
check("forget button resets", Hub.HeightCap() == 100)
print(logs[1])
end
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
'''

src = PRELUDE + "tweenTo = nil\n" + tween + "\n" + helpers + TESTS + TAIL + HEIGHT
pathlib.Path(sys.argv[1]).write_text(src, encoding="utf-8")
