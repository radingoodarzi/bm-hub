---------------------------------------------------------------------
-- v3 · Swords: Tushita، CDK (Cursed Dual Katana) و TTK (True Triple Katana) با مراحل دقیق
-- منطق از Banana Cat (بخش‌های خوانا):
--   Tushita: ریموت TushitaProgress (OpenedDoor، Torch 1..5)، بعد Longma
--   CDK: ریموت CDKQuest Progress "Good" → Good/Evil؛ -3/-4/-5 = تریال 3/5، 4/5، 5/5؛ 4 = اون طرف تموم
--        Pedestal1/2 بین دو طرف، Pedestal3 + Cursed Skeleton Boss آخرش
--        Good 5 (Cake Queen → Heavenly Dimension) و Evil 5 (Soul Reaper → Hell Dimension) کامل از Banana
--   Good 3/4 و Evil 3/4 توی بخش قفل‌شده‌ی Banana بود؛ از تحقیق (TheGamer، RobloxDen، Alphr) ساخته شدن:
--   Tushita: Dock Legend (3 فروشنده‌ی قایق) → Sense of Duty (Pirate Raid) → Soulless (Cake Queen، Heaven)
--   Yama: Pain and Suffering (با Yama کتک بخور) → Haze of Misery (ماب‌های بنفش) → Fear the Reaper (Hell)
--   TTK: Saddi + Shisui + Wando (Legendary Sword Dealer) → Mysterious Man (دانش بازی، تأیید نشده)
---------------------------------------------------------------------
do
local okSw, errSw = pcall(function()
	local V3 = Hub.V3
	for k, v in pairs({ CDKHop = false, AutoTTK = false }) do
		if S[k] == nil then S[k] = v end
	end
	local CDK = {}
	V3.CDK = CDK

	-----------------------------------------------------------------
	-- مرحله‌ی CDK از روی دو عدد سرور (خالص، برای تست)
	-----------------------------------------------------------------
	function CDK.stage(good, evil)
		if good == nil or evil == nil then return "noProgress" end
		if good == 4 and evil == 4 then return "final" end
		if good == 4 and evil == 3 then return "pedestal2" end
		if good == 3 and evil == 4 then return "pedestal1" end
		if good ~= 4 and good ~= -2 then
			if good == -3 then return "good3" end
			if good == -4 then return "good4" end
			if good == -5 then return "good5" end
			return "goodStart"
		end
		if evil == -3 then return "evil3" end
		if evil == -4 then return "evil4" end
		if evil == -5 then return "evil5" end
		return "evilStart"
	end
	CDK.LABEL = {
		noProgress = "can't read progress (need Yama + Tushita)", final = "final: Pedestal3 + Cursed Skeleton Boss",
		pedestal1 = "placing the sword at Pedestal1", pedestal2 = "placing the sword at Pedestal2",
		goodStart = "starting the Tushita scroll", good3 = "Tushita 1: Dock Legend (3 boat dealers)",
		good4 = "Tushita 2: Sense of Duty (Pirate Raid, Castle on the Sea)", good5 = "Tushita 3: Soulless (Cake Queen → Heaven)",
		evilStart = "starting the Yama scroll", evil3 = "Yama 1: Pain and Suffering (take damage with Yama)",
		evil4 = "Yama 2: Haze of Misery (purple-marked mobs)", evil5 = "Yama 3: Fear the Reaper (Soul Reaper → Hell)",
	}

	-----------------------------------------------------------------
	-- ابزارها
	-----------------------------------------------------------------
	local function ownTool(name)
		local c, bp = getChar(), player:FindFirstChild("Backpack")
		return (c and c:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
	end
	local function equip(name)
		local t, h = ownTool(name), getHum()
		if t and h and t.Parent ~= getChar() then pcall(function() h:EquipTool(t) end) end
		return t
	end
	local function swordLevel(name)
		local t = ownTool(name)
		local lv = t and t:FindFirstChild("Level")
		return lv and tonumber(lv.Value)
	end
	-- دعوا با شمشیر (مثل Banana: Cake Queen، ماب‌های Dimension، باس آخر) و برگردوندن سلاح خودت
	local function withSword(fn, ...)
		local saved = S.Weapon
		S.Weapon = "Sword"
		local ok, err = pcall(fn, ...)
		S.Weapon = saved
		if not ok then error(err, 0) end
	end
	local function go(cf, keep)
		if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
		tweenTo(cf, keep)
	end
	local function near(pos, d)
		local r = getRoot()
		return r and (r.Position - pos).Magnitude <= d
	end
	local function location(name)
		local wo = workspace:FindFirstChild("_WorldOrigin")
		local l = wo and wo:FindFirstChild("Locations")
		return l and l:FindFirstChild(name)
	end
	local function skipDialogue()
		pcall(function()
			if player.PlayerGui.Main.Dialogue.Visible then
				local vu = game:GetService("VirtualUser")
				vu:Button1Down(Vector2.new(0, 0))
				vu:Button1Up(Vector2.new(0, 0))
			end
		end)
	end
	local function hopFor(what)
		if S.CDKHop and Hub.Brain and Hub.Brain.hop then
			S.Status = "CDK: hopping to find " .. what
			V3.log("CDK hop for " .. what)
			pcall(Hub.Brain.hop)
			task.wait(10)
		else
			S.Status = "CDK: waiting for " .. what .. " (turn on Hop to look in other servers)"
			task.wait(4)
		end
	end
	-- نزدیک‌ترین ماب زنده دور یه نقطه
	local function mobNear(center, radius)
		local enemies = workspace:FindFirstChild("Enemies")
		local root, best, bd = getRoot(), nil, nil
		for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
			if isAliveMob(m) and (m.HumanoidRootPart.Position - center).Magnitude <= radius then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if not bd or d < bd then best, bd = m, d end
			end
		end
		return best
	end
	local function promptOf(o) return o and o:FindFirstChildWhichIsA("ProximityPrompt", true) end

	-----------------------------------------------------------------
	-- Dimension (Hell / Heavenly): خروجی رنگی = تموم؛ ماب = بکش؛ مشعل روشن‌نشده = روشن کن
	-----------------------------------------------------------------
	local function stepDimension(mapName, locName, doneColor, keep)
		local dim = workspace.Map:FindFirstChild(mapName)
		local loc = location(locName)
		local center = loc and loc.Position
		if not center and dim then
			local ok, pv = pcall(function() return dim:GetPivot().Position end)
			center = ok and pv or nil
		end
		if not dim or not center then
			S.Status = "CDK: waiting for the " .. locName .. " to load"
			task.wait(1)
			return
		end
		local exit = dim:FindFirstChild("Exit")
		if exit and exit:IsA("BasePart") and exit.BrickColor == BrickColor.new(doneColor) then
			S.Status = "CDK: " .. locName .. " cleared, leaving"
			go(exit.CFrame, keep)
			touchPart(exit)
			task.wait(1)
			return
		end
		local mob = mobNear(center, 1000)
		if mob then
			S.Status = "CDK: clearing the " .. locName .. " (" .. mobBaseName(mob.Name) .. ")"
			withSword(killMob, mob, keep)
			return
		end
		for i = 1, 3 do
			local t = dim:FindFirstChild("Torch" .. i)
			local pp = promptOf(t)
			if t and pp and pp.Enabled then
				S.Status = ("CDK: lighting torch %d in the %s"):format(i, locName)
				local pos = t:IsA("BasePart") and t.Position or t:GetPivot().Position
				if not near(pos, 5) then
					go(CFrame.new(pos), keep)
				end
				V3.activate(pp)
				local t0 = tick()
				while keep() and tick() - t0 < 5 and not mobNear(center, 1000) do task.wait(0.3) end
				local r = getRoot()
				if r then r.CFrame = r.CFrame * CFrame.new(0, 50, 0) end
				return
			end
		end
		S.Status = "CDK: waiting for mobs / torches in the " .. locName
		task.wait(1)
	end

	-----------------------------------------------------------------
	-- مرحله‌ها
	-----------------------------------------------------------------
	-- Tushita 1 «Dock Legend» (تحقیق): با 3 تا Boat Dealer / Luxury Boat Dealer روی 3 جزیره‌ی مختلف حرف بزنی
	-- (گزینه‌ی "Pardon me"). Banana اینجا ریموت CDKQuest BoatQuest رو با خود NPC صدا می‌زنه.
	-- همه‌ی فروشنده‌های قایق رو از لیست NPCهای بازی پیدا می‌کنیم و یکی‌یکی سر می‌زنیم
	local FALLBACK_DOCKS = { Vector3.new(-9550, 21, 4690), Vector3.new(-6120, 16, -2250), Vector3.new(-9530, 7, -8370) }
	local visitedDock = {}
	local function dockKey(p) return math.floor(p.X / 200) .. "," .. math.floor(p.Z / 200) end
	local function boatDealers()
		local out, seen = {}, {}
		for _, f in ipairs({ workspace:FindFirstChild("NPCs"), ReplicatedStorage:FindFirstChild("NPCs") }) do
			for _, n in ipairs(f and f:GetChildren() or {}) do
				if n.Name:find("Boat Dealer", 1, true) then
					local ok, pv = pcall(function() return n:GetPivot().Position end)
					if ok and pv.Y > -500 and not seen[dockKey(pv)] then
						seen[dockKey(pv)] = true
						table.insert(out, { npc = n, pos = pv })
					end
				end
			end
		end
		if #out == 0 then
			for _, p in ipairs(FALLBACK_DOCKS) do table.insert(out, { pos = p }) end
		end
		return out
	end
	local function good3(keep)
		local list = boatDealers()
		local target
		for _, d in ipairs(list) do
			if not visitedDock[dockKey(d.pos)] then target = d break end
		end
		if not target then
			-- همه رو دیدیم ولی سرور هنوز Good -3 میگه: از اول
			visitedDock = {}
			target = list[1]
		end
		local count = 0
		for _ in pairs(visitedDock) do count += 1 end
		if not near(target.pos, 25) then
			S.Status = ("CDK Good 3/5 (Dock Legend): boat dealer %d/3"):format(math.min(count + 1, 3))
			go(CFrame.new(target.pos + Vector3.new(0, 5, 4)), keep)
			return
		end
		local npc = target.npc
		if not npc then
			for _, d in ipairs(boatDealers()) do
				if d.npc and (d.pos - target.pos).Magnitude < 50 then npc = d.npc end
			end
		end
		if npc then
			invoke("CDKQuest", "BoatQuest", npc)
			V3.log("CDK BoatQuest " .. npc.Name .. " at " .. dockKey(target.pos))
		end
		skipDialogue()
		visitedDock[dockKey(target.pos)] = true
		task.wait(1)
	end

	local CASTLE = Vector3.new(-5100, 315, -3000)
	local function good4(keep)
		local mob = mobNear(CASTLE, 900)
		if mob then
			S.Status = "CDK Good 4/5: Pirate Raid – " .. mobBaseName(mob.Name)
			killMob(mob, keep)
		else
			S.Status = "CDK Good 4/5: waiting for the raid at Castle on the Sea"
			go(CFrame.new(CASTLE + Vector3.new(0, 60, 0)), keep)
			task.wait(2)
		end
	end

	local function good5(keep)
		local loc = location("Heavenly Dimension")
		if loc and near(loc.Position, 1000) then
			return stepDimension("HeavenlyDimension", "Heavenly Dimension", "Cloudy grey", keep)
		end
		local queen = findMobAnywhere("Cake Queen")
		if queen then
			S.Status = "CDK Good 5/5: fighting Cake Queen"
			withSword(fightBoss, "Cake Queen", keep)
			return
		end
		hopFor("Cake Queen")
	end

	-- Yama 1 «Pain and Suffering» (تحقیق: TheGamer، RobloxDen، Alphr): با Yama توی دست حدود 10,000 دمیج
	-- بخوری (یا تقریباً بمیری). حمله نمی‌کنیم؛ کنار یه ماب قوی وایمیستیم تا بزنتمون.
	-- Banana اینجا Marine Commodore (جزیره‌ی Great Tree) رو استفاده می‌کنه
	local COMMODORE_SPOT = Vector3.new(2180.54, 27.82, -6741.55)
	local function evil3(keep)
		equip("Yama")
		local mob = findMob("Marine Commodore")
		if not mob then
			local root = getRoot()
			local enemies = workspace:FindFirstChild("Enemies")
			for _, m in ipairs(enemies and enemies:GetChildren() or {}) do
				if isAliveMob(m) and (m.HumanoidRootPart.Position - root.Position).Magnitude < 300 then mob = m break end
			end
		end
		if not mob then
			S.Status = "CDK Evil 3/5 (Pain and Suffering): going to the Marine Commodores"
			go(CFrame.new(COMMODORE_SPOT + Vector3.new(0, 10, 0)), keep)
			task.wait(1)
			return
		end
		S.Status = "CDK Evil 3/5 (Pain and Suffering): letting " .. mobBaseName(mob.Name) .. " hit you (Yama in hand)"
		local t0 = tick()
		while keep() and alive() and mob.Parent and isAliveMob(mob) and tick() - t0 < 10 do
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if not hrp then break end
			Hub.HoldAttackUntil = tick() + 2 -- Auto Click نباید ماب رو بکشه، باید کتک بخوریم
			setFloat(false)
			local root = getRoot()
			if root then root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
			equip("Yama")
			task.wait(0.3)
		end
	end

	local function evil4(keep)
		local haze = player:FindFirstChild("QuestHaze")
		local pick
		for _, v in ipairs(haze and haze:GetChildren() or {}) do
			if v:IsA("ValueBase") and (tonumber(v.Value) or 0) > 0 then pick = v.Name break end
		end
		if not pick then
			S.Status = "CDK Evil 4/5: waiting for the haze list"
			task.wait(1.5)
			return
		end
		local m = findMob(pick)
		if m then
			S.Status = ("CDK Evil 4/5: haze %s (%s left)"):format(pick, tostring(haze[pick].Value))
			killMob(m, keep)
			return
		end
		local sp
		pcall(function() sp = ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder[pick].Position end)
		sp = sp or (spawnCentroid and spawnCentroid(pick))
		S.Status = "CDK Evil 4/5: going to " .. pick
		if sp then go(CFrame.new(sp + Vector3.new(0, 30, 0)), keep) else task.wait(2) end
	end

	local BONE_MOBS = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
	local gambleAt = 0
	local function evil5(keep)
		local loc = location("Hell Dimension")
		if loc and near(loc.Position, 1000) then
			return stepDimension("HellDimension", "Hell Dimension", "Olivine", keep)
		end
		local reaper = findMobAnywhere("Soul Reaper")
		if reaper then
			-- با Soul Reaper دعوا نمی‌کنیم: کنارش می‌مونیم تا ما رو ببره توی Hell Dimension (مثل Banana)
			S.Status = "CDK Evil 5/5: letting Soul Reaper take you to Hell"
			local t0 = tick()
			while keep() and alive() and tick() - t0 < 60 do
				local hrp = reaper:FindFirstChild("HumanoidRootPart")
				if not hrp or not reaper.Parent then break end
				tweenTo(hrp.CFrame * CFrame.new(0, 0, 3), keep)
				local l = location("Hell Dimension")
				if l and near(l.Position, 1000) then break end
				task.wait(0.2)
			end
			return
		end
		if ownTool("Hallow Essence") then
			local det
			pcall(function() det = workspace.Map["Haunted Castle"].Summoner.Detection end)
			if det then
				S.Status = "CDK Evil 5/5: summoning Soul Reaper (Hallow Essence)"
				if not near(det.Position, 8) then go(det.CFrame, keep) end
				equip("Hallow Essence")
				touchPart(det)
			else
				S.Status = "CDK Evil 5/5: going to Haunted Castle"
				go(CFrame.new(-9515, 194, 5786), keep)
			end
			task.wait(1)
			return
		end
		-- Hallow Essence: از ماب‌های Bone یا قمار Death King (50 بون)، مثل Banana
		if tick() - gambleAt > 5 then
			gambleAt = tick()
			task.spawn(function() invoke("Bones", "Buy", 1, 1) end)
		end
		local m
		for _, n in ipairs(BONE_MOBS) do m = m or findMob(n) end
		if m then
			S.Status = "CDK Evil 5/5: bones for Hallow Essence (" .. mobBaseName(m.Name) .. ")"
			killMob(m, keep)
		else
			S.Status = "CDK Evil 5/5: going to Haunted Castle for bones"
			go(CFrame.new(-9515, 194, 5786), keep)
		end
	end

	local BOSS_WAIT = Vector3.new(-12341.67, 603.35, -6550.61)
	local function cursed() local t = workspace.Map:FindFirstChild("Turtle"); return t and t:FindFirstChild("Cursed") end
	local function pedestal(name, keep)
		local c = cursed()
		local p = c and c:FindFirstChild(name)
		if not p then
			S.Status = "CDK: going to the Cursed room (Floating Turtle)"
			go(CFrame.new(BOSS_WAIT), keep)
			return false
		end
		if not near(p.Position, 10) then
			go(p.CFrame, keep)
			return false
		end
		V3.activate(promptOf(p))
		skipDialogue()
		task.wait(1)
		return true
	end
	local function final(keep)
		local c = cursed()
		local p3 = c and c:FindFirstChild("Pedestal3")
		if not p3 then return pedestal("Pedestal3", keep) end
		if not near(p3.Position, 10) and not findMob("Cursed Skeleton Boss") then
			S.Status = "CDK final: going to Pedestal3"
			go(p3.CFrame, keep)
			return
		end
		local gem = c:FindFirstChild("PlacedGem")
		if gem and gem.Transparency == 0 then
			local boss = findMob("Cursed Skeleton Boss")
			if boss then
				S.Status = "CDK final: fighting Cursed Skeleton Boss"
				withSword(killMob, boss, keep)
			else
				S.Status = "CDK final: waiting for Cursed Skeleton Boss"
				go(CFrame.new(BOSS_WAIT), keep)
				task.wait(1)
			end
		else
			S.Status = "CDK final: placing the gem at Pedestal3"
			V3.activate(promptOf(p3))
			skipDialogue()
			task.wait(1)
		end
	end

	local function readProgress()
		local r = invoke("CDKQuest", "Progress", "Good")
		if type(r) ~= "table" then r = invoke("CDKQuest", "Progress") end
		if type(r) == "table" then return tonumber(r.Good), tonumber(r.Evil) end
	end

	local lastStage
	function V3.cdkStep(keep)
		if hasItem("Cursed Dual Katana") then
			S.AutoCDK = false
			V3.notify("CDK", "You have Cursed Dual Katana ✔", 8)
			return
		end
		if not (hasItem("Yama") and hasItem("Tushita")) then
			V3.notify("CDK", "Needs both Yama and Tushita first (switch turned off)", 8)
			S.AutoCDK = false
			return
		end
		for _, sw in ipairs({ "Yama", "Tushita" }) do
			local lv = swordLevel(sw)
			if lv and lv < 350 then
				V3.notify("CDK", ("%s mastery is %d/350 (use Smart Mastery). Switch turned off"):format(sw, lv), 8)
				S.AutoCDK = false
				return
			end
		end
		-- یکی از دو شمشیر باید دستت باشه (Banana: اگه هیچ‌کدوم نبود Tushita رو لود کن)
		if not ownTool("Tushita") and not ownTool("Yama") then
			S.Status = "CDK: loading Tushita"
			invoke("LoadItem", "Tushita")
			task.wait(1)
			return
		end
		skipDialogue()
		local good, evil = readProgress()
		local stage = CDK.stage(good, evil)
		if stage ~= lastStage then
			V3.log(("CDK stage %s (Good=%s Evil=%s)"):format(stage, tostring(good), tostring(evil)))
			lastStage = stage
		end
		CDK.last = { good = good, evil = evil, stage = stage }
		S.Status = "CDK: " .. (CDK.LABEL[stage] or stage)
		if stage == "noProgress" then
			if invoke("CDKQuest", "OpenDoor") == "can" then invoke("CDKQuest", "OpenDoor", true) end
			task.wait(4)
			return
		end
		-- هر طرف با شمشیر خودش (تحقیق: Alphr/RobloxDen): Good = Tushita، Evil = Yama؛ باس آخر با هر کدوم
		local want = (stage:find("^good") or stage == "pedestal1") and "Tushita"
			or ((stage:find("^evil") or stage == "pedestal2") and "Yama") or nil
		if want and not ownTool(want) then
			S.Status = "CDK: loading " .. want .. " for this trial"
			invoke("LoadItem", want)
			task.wait(1)
			return
		end
		if want then equip(want) end
		if stage == "final" then return final(keep) end
		if stage == "pedestal1" then
			if not pedestal("Pedestal1", keep) then return end
		elseif stage == "pedestal2" then
			if not pedestal("Pedestal2", keep) then return end
		end
		-- مثل Banana هر دور StartTrial همون طرف رو صدا می‌زنیم، بعد کار مرحله
		local side = (good ~= 4 and good ~= -2) and "Good" or "Evil"
		invoke("CDKQuest", "StartTrial", side)
		if stage == "good3" then good3(keep)
		elseif stage == "good4" then good4(keep)
		elseif stage == "good5" then good5(keep)
		elseif stage == "evil3" then evil3(keep)
		elseif stage == "evil4" then evil4(keep)
		elseif stage == "evil5" then evil5(keep)
		else task.wait(1.5) end
	end

	-----------------------------------------------------------------
	-- Tushita (از Banana): TushitaProgress → اگه در باز شده Longma، وگرنه مشعل مقدس + 5 مشعل
	-----------------------------------------------------------------
	local TUSHITA_DOOR = Vector3.new(5677.54, 28.53, 357.95)
	local function doorHitbox()
		local h
		pcall(function() h = workspace.Map.Waterfall.SecretRoom.Room.Door.Door.Hitbox end)
		return h
	end
	function V3.tushitaStep(keep)
		if hasItem("Tushita") then
			S.AutoTushita = false
			V3.notify("Tushita", "You have Tushita ✔", 6)
			return
		end
		local p = invoke("TushitaProgress")
		if type(p) == "table" and p.OpenedDoor then
			if findMobAnywhere("Longma") then
				S.Status = "Tushita: fighting Longma"
				fightBoss("Longma", keep)
			else
				S.Status = "Tushita: door open, waiting for Longma"
				task.wait(3)
			end
			return
		end
		local hit = doorHitbox()
		if not hit then
			S.Status = "Tushita: going to the secret room"
			go(CFrame.new(TUSHITA_DOOR), keep)
			return
		end
		if not hit:FindFirstChild("TouchInterest") then
			S.Status = "Tushita: rip_indra must be spawned in this server"
			task.wait(5)
			return
		end
		if not ownTool("Holy Torch") then
			S.Status = "Tushita: taking the Holy Torch"
			go(hit.CFrame, keep)
			touchPart(hit)
			task.wait(1)
			return
		end
		S.Status = "Tushita: lighting the 5 torches"
		equip("Holy Torch")
		for i = 1, 5 do invoke("TushitaProgress", "Torch", i) end
		task.wait(2)
	end

	-----------------------------------------------------------------
	-- TTK (دریای 2): سه شمشیر Legendary (خریدش با Auto Buy Legendary) → Mysterious Man
	-----------------------------------------------------------------
	local MYSTERIOUS_MAN = Vector3.new(-2573.5, 1620.7, -3745.2)
	local ttkTries = 0
	local function stepTTK(keep)
		if hasItem("True Triple Katana") then
			S.AutoTTK = false
			V3.notify("TTK", "You have True Triple Katana ✔", 8)
			return
		end
		local missing = {}
		for _, sw in ipairs({ "Saddi", "Shisui", "Wando" }) do
			if not hasItem(sw) then table.insert(missing, sw) end
		end
		if #missing > 0 then
			if not S.AutoLegendary then S.AutoLegendary = true end
			S.Status = "TTK: buying " .. table.concat(missing, ", ") .. " from the Legendary Sword Dealer"
			task.wait(5)
			return
		end
		if (dataValue("Beli") or 0) < 2000000 then
			S.Status = "TTK: needs $2,000,000"
			task.wait(5)
			return
		end
		if not near(MYSTERIOUS_MAN, 10) then
			S.Status = "TTK: going to the Mysterious Man (Cafe roof)"
			go(CFrame.new(MYSTERIOUS_MAN + Vector3.new(0, 3, 4)), keep)
			return
		end
		S.Status = "TTK: buying from the Mysterious Man"
		local check = invoke("MysteriousMan", "1")
		local buy = invoke("MysteriousMan", "2")
		V3.log("TTK MysteriousMan 1=" .. tostring(check) .. " 2=" .. tostring(buy))
		skipDialogue()
		task.wait(2)
		ttkTries += 1
		if ttkTries >= 3 and not hasItem("True Triple Katana") then
			V3.notify("TTK", "Mysterious Man didn't sell it (needs 300 mastery on all 3 swords?). Switch turned off", 10)
			S.AutoTTK = false
			ttkTries = 0
		end
	end
	V3.register("AutoTTK", stepTTK, function() return Sea == 2 end, true)
end)
if not okSw then logError("v3 swords", errSw) end
end

--@@UI@@
if Sea == 2 then
	local T = createTab("Items", "◆")
	T:Section("True Triple Katana (auto)")
	T:Toggle("Auto TTK (buys the 3 Legendary swords, then the Mysterious Man)", "AutoTTK", stopOff)
	T:Label(function() return "TTK spends $2M per Legendary sword + $2M for TTK" end)
elseif Sea == 3 then
	local T = createTab("Items", "◆")
	T:Section("CDK (Cursed Dual Katana)")
	T:Toggle("Hop Servers For Cake Queen / Soul Reaper", "CDKHop")
	T:Label(function()
		local C = Hub.V3.CDK
		local l = C and C.last
		if not l then return "CDK progress: turn on Auto CDK to read it" end
		return ("Good %s • Evil %s • %s"):format(tostring(l.good), tostring(l.evil), C.LABEL[l.stage] or l.stage)
	end)
end
