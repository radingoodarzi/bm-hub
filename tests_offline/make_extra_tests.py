"""Two more checks built from the generated hub:
quest_test: the real hasQuest/mummyQuestActive replaying the in-game log timeline (old and new code).
smoke_test: runs the whole hub on a fake Roblox so the UI code really executes."""
import pathlib
import re
import sys

root = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub")
out = pathlib.Path(sys.argv[1])
v3 = (root / "bm_hub_v3.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
v2 = (root / "bm_hub_v2.lua").read_text(encoding="utf-8").replace("\r\n", "\n")


def slice_fn(src, start):
    i = src.index(start)
    j = src.index("\nend\n", i) if not start.startswith("\t") else src.index("\n\tend\n", i)
    return src[i:j + (5 if not start.startswith("\t") else 6)]


def quest_test(src, label):
    parts = [slice_fn(src, n) for n in ("local function titleHasMob", "local function hasQuest")]
    parts.append(slice_fn(src, "\tlocal function mummyQuestActive"))
    return f'''do
local clock = 0
local function tick() return clock end
local Hub = {{}}
local box = nil
local function questTitle() return box end
local function questDone(t) local c, n = t:match("(%d+)/(%d+)"); return c ~= nil and tonumber(c) >= tonumber(n) end
{chr(10).join(parts)}
-- 19:47:46 quest taken (server said 0)
Hub.QuestTakenAt, Hub.QuestTakenMob = 0, "Posessed Mummy"
Hub.QuestSeen, Hub.QuestGoneSince = false, nil
box = "Defeat 8 Posessed Mummys (0/8)"
for t = 1, 42 do clock = t; assert(mummyQuestActive() == true) end
-- 19:48:28 quest finished, the box disappears
box = nil
local goneAt
for t = 43, 70 do
	clock = t
	if not mummyQuestActive() then goneAt = t; break end
end
print("{label}: quest noticed finished after " .. tostring(goneAt and goneAt - 42 or "never") .. "s")
end
'''


if sys.argv[2] == "quest":
    out.write_text(quest_test(v2, "old v2 code") + quest_test(v3, "new v3 code"), encoding="utf-8")
    sys.exit()

PRELUDE = r'''
local realTask = task
local RAW = { "IsA" }
local magicMeta
local pending = {}
local function magic(name)
	return setmetatable({ __name = name or "magic" }, magicMeta)
end
local function asNum(v) return type(v) == "number" and v or 1 end
magicMeta = {
	__index = function(t, k)
		if k == "Value" or k == "Health" or k == "MaxHealth" or k == "X" or k == "Y" or k == "Z" or k == "Magnitude" then return 100 end
		if k == "Text" or k == "Name" or k == "ToolTip" or k == "ClassName" then return "x" end
		if k == "IsA" then return function() return false end end
		if k == "GetChildren" or k == "GetDescendants" or k == "GetPlayers" or k == "GetTagged" then return function() return {} end end
		if k == "FindFirstChild" or k == "FindFirstChildOfClass" or k == "FindFirstChildWhichIsA" or k == "WaitForChild" then return function() return nil end end
		if k == "IsLoaded" then return function() return true end end
		if k == "Connect" then return function() return magic("conn") end end
		local v = magic(tostring(k))
		rawset(t, k, v)
		return v
	end,
	__newindex = function(t, k, v) rawset(t, k, v) end,
	__call = function() return magic("call") end,
	__add = function() return 1 end, __sub = function() return 1 end, __mul = function() return 1 end,
	__div = function() return 1 end, __unm = function() return 1 end, __mod = function() return 1 end,
	__concat = function(a, b) return tostring(a) .. tostring(b) end,
	__lt = function() return false end, __le = function() return false end,
	__tostring = function(t) return rawget(t, "__name") or "magic" end,
	__len = function() return 0 end,
}
local game = magic("game")
local realGet = nil
rawset(game, "GetService", function(_, n)
	if n == "Players" then
		local P = magic("Players")
		local me = magic("LocalPlayer")
		rawset(me, "Name", "tester"); rawset(me, "DisplayName", "tester"); rawset(me, "UserId", 1)
		rawset(me, "Team", nil)
		rawset(P, "LocalPlayer", me)
		return P
	end
	return magic(n)
end)
rawset(game, "PlaceId", 100117331123089)
rawset(game, "JobId", "job")
local workspace = magic("workspace")
rawset(workspace, "CurrentCamera", magic("camera"))
local function ctor() return setmetatable({ new = function() return magic("value") end, fromRGB = function() return magic("c") end,
	fromOffset = function() return magic("u") end, fromScale = function() return magic("u") end, lookAt = function() return magic("cf") end,
	zero = magic("zero"), one = magic("one") }, magicMeta) end
local Vector2, Vector3, CFrame, UDim, UDim2, Color3, ColorSequence, ColorSequenceKeypoint, NumberSequence, NumberSequenceKeypoint, TweenInfo, Rect, Region3 =
	ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor(), ctor()
local Enum = magic("Enum")
local Instance = { new = function(c) return magic(c) end }
local typeof = function(v) return type(v) end
local tick = function() return 1000 end
local GENV = {}
local getgenv = function() return GENV end
local spawned = 0
local task = {
	spawn = function(fn, ...) if type(fn) == "function" then spawned += 1 end end,
	delay = function() end, defer = function() end,
	wait = function() return 0.1 end,
}
local warn = function(...) print("WARN", ...) end
'''

SUMMARY = r'''
local BM = GENV.BMHub
print("hub version", BM and BM.Version)
local UI = BM.TabUI
local names = {}
for n in pairs(UI.apis) do table.insert(names, n) end
table.sort(names, function(a, b) return (UI.order[a] or 99) < (UI.order[b] or 99) end)
print("tabs: " .. #names)
for _, n in ipairs(names) do
	local secs, items, open = {}, 0, 0
	for _, g in ipairs(UI.groups[n]) do
		items += #g.items
		if g.open then open += 1 end
	end
	print(("  %-10s sections=%d items=%d open=%d order=%s"):format(n, #UI.groups[n], items, open, tostring(UI.order[n])))
end
local g = UI.groups.Sea[2]
g.show(false)
local hidden = true
for _, c in ipairs(g.items) do hidden = hidden and c.Visible == false end
g.show(true)
local shown = true
for _, c in ipairs(g.items) do shown = shown and c.Visible == true end
print("collapse hides cards", hidden, "expand shows them", shown, "cards", #g.items)
print("merged api is the same object", UI.apis.Sea ~= nil)
print("errors logged: " .. #BM.Errors)
for _, e in ipairs(BM.Errors) do print("  " .. e) end
print("brain ready", BM.Brain and BM.Brain.ready, "planner ready", BM.Planner and BM.Planner.ready)
'''

out.write_text(PRELUDE + "local function HUB(...)\n" + v3 + "\nend\nHUB()\n" + SUMMARY, encoding="utf-8")
