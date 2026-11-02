---------------------------------------------------------------------
-- v3 · Styles: برنامه‌ی فایتینگ استایل تا Godhuman
-- هر بار حساب می‌کنه چی کمه (سبک پیش‌نیاز، Mastery، متریال، آیتم، پول) و همون رو انجام میده
-- پیش‌نیازها و قیمت‌ها از اطلاعات بازی؛ جواب واقعی سرور موقع خرید توی لاگ میره
-- خرید فقط با کلید Allow Buying؛ Mastery و متریال فقط فارم می‌کنن
---------------------------------------------------------------------
do
local okStyles, errStyles = pcall(function()
	local V3, Brain = Hub.V3, Hub.Brain
	if not (Brain and Brain.ready) then return end
	for k, v in pairs({ AutoStylePlan = false, StyleTarget = "Godhuman", StyleBuy = false }) do
		if S[k] == nil then S[k] = v end
	end
	Hub.V3SkipSave.StyleBuy = true -- پول خرج می‌کنه

	local Styles = {}
	Hub.Styles = Styles

	-- needs: سبک‌های پیش‌نیاز و Mastery لازم، mats: متریال، item: آیتم لازم، note: شرط دیگه
	local DEF = {
		["Black Leg"] = { beli = 150000 },
		["Electro"] = { beli = 500000 },
		["Fishman Karate"] = { beli = 750000 },
		["Dragon Claw"] = { frag = 1500 },
		["Superhuman"] = { beli = 3000000,
			needs = { { "Black Leg", 300 }, { "Electro", 300 }, { "Fishman Karate", 300 }, { "Dragon Claw", 300 } } },
		["Death Step"] = { beli = 2500000, frag = 5000, needs = { { "Black Leg", 400 } }, item = "Library Key" },
		["Sharkman Karate"] = { beli = 2500000, frag = 5000, needs = { { "Fishman Karate", 400 } }, item = "Water Key" },
		["Electric Claw"] = { beli = 3000000, frag = 5000, needs = { { "Electro", 400 } }, note = "also needs the Previous Hero quest" },
		["Dragon Talon"] = { beli = 3000000, frag = 5000, needs = { { "Dragon Claw", 400 } }, item = "Fire Essence" },
		["Godhuman"] = { beli = 5000000, frag = 5000, sea = 3, npc = "Ancient Monk",
			needs = { { "Superhuman", 400 }, { "Death Step", 400 }, { "Sharkman Karate", 400 }, { "Electric Claw", 400 }, { "Dragon Talon", 400 } },
			mats = { { "Fish Tail", 20 }, { "Magma Ore", 20 }, { "Dragon Scale", 10 }, { "Mystic Droplet", 10 } } },
	}
	Styles.DEF = DEF
	Styles.TARGETS = { "Superhuman", "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon", "Godhuman" }
	local ITEM_HINT = { ["Library Key"] = "drops from Awakened Ice Admiral (Sea 2)", ["Water Key"] = "drops from Tide Keeper (Sea 2)" }
	-- متریال‌هایی که توی هر دریا فارم میشن (از جدول Materials خود BM)
	local MAT_SEA = { ["Magma Ore"] = "Sea 1 or 2", ["Mystic Droplet"] = "Sea 2", ["Fish Tail"] = "Sea 1 or 3", ["Dragon Scale"] = "Sea 3" }

	-----------------------------------------------------------------
	-- قدم بعدی (تابع خالص؛ st همه‌ی داده‌ها رو داره تا بشه آفلاین تستش کرد)
	-- st = { owned = {}, mastery = {}, beli, frag, sea, mats(name), items(name), teacherSea(name) }
	-----------------------------------------------------------------
	function Styles.plan(name, st)
		if st.owned[name] then return nil end
		local def = DEF[name]
		if not def then return { kind = "unknown", style = name, why = "no data for " .. name } end
		for _, need in ipairs(def.needs or {}) do
			local n, level = need[1], need[2]
			if not st.owned[n] then return Styles.plan(n, st) end
			local m = st.mastery[n]
			if m == nil then return { kind = "unknown", style = n, why = "can't read the mastery of " .. n } end
			if m < level then return { kind = "mastery", style = n, need = level, have = m, why = ("%s mastery %d/%d"):format(n, m, level) } end
		end
		for _, mat in ipairs(def.mats or {}) do
			local have = st.mats(mat[1])
			if have < mat[2] then
				return { kind = "material", mat = mat[1], need = mat[2], have = have, why = ("%s %d/%d"):format(mat[1], have, mat[2]) }
			end
		end
		if def.item and not st.items(def.item) then
			return { kind = "item", item = def.item, why = "needs " .. def.item .. (ITEM_HINT[def.item] and " (" .. ITEM_HINT[def.item] .. ")" or "") }
		end
		if st.beli < (def.beli or 0) or st.frag < (def.frag or 0) then
			return { kind = "money", style = name, why = ("%s needs %s Beli + %s Fragments"):format(name, formatNumber(def.beli or 0), formatNumber(def.frag or 0)) }
		end
		local sea = def.sea or st.teacherSea(name)
		if sea and sea ~= st.sea then return { kind = "sea", sea = sea, why = ("buy %s in Sea %d"):format(name, sea) } end
		return { kind = "buy", style = name, why = "ready to buy " .. name .. (def.note and " (" .. def.note .. ")" or "") }
	end

	-- همه‌ی پیش‌نیازها برای نمایش (✔ / عدد)
	function Styles.lines(name, st)
		local out, seen = {}, {}
		local function walk(n)
			local def = DEF[n]
			for _, need in ipairs(def and def.needs or {}) do
				if not seen[need[1]] then
					seen[need[1]] = true
					local m = st.mastery[need[1]]
					local mark = st.owned[need[1]] and ((m or 0) >= need[2] and "✔" or "·") or "✖"
					table.insert(out, ("%s %s  %s/%d"):format(mark, need[1], st.owned[need[1]] and tostring(m or "?") or "not owned", need[2]))
					if not st.owned[need[1]] then walk(need[1]) end
				end
			end
		end
		walk(name)
		for _, mat in ipairs(DEF[name] and DEF[name].mats or {}) do
			local have = st.mats(mat[1])
			table.insert(out, ("%s %s  %d/%d"):format(have >= mat[2] and "✔" or "·", mat[1], have, mat[2]))
		end
		return out
	end

	-----------------------------------------------------------------
	-- داده‌ی واقعی از بازی
	-----------------------------------------------------------------
	local function meleeTool()
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			if cont then
				for _, t in ipairs(cont:GetChildren()) do
					if t:IsA("Tool") and t.ToolTip == "Melee" then return t end
				end
			end
		end
	end
	Styles.meleeTool = meleeTool

	function Styles.state()
		local st = { owned = {}, mastery = {}, sea = Sea, beli = dataValue("Beli") or 0, frag = dataValue("Fragments") or 0, confirmed = {} }
		local P = Hub.Planner
		for _, w in ipairs(P and P.weapons or {}) do
			if DEF[w.Name] then
				st.owned[w.Name], st.confirmed[w.Name] = true, true
				st.mastery[w.Name] = tonumber(w.Mastery)
			end
		end
		local inv = inventoryNames()
		for n in pairs(DEF) do
			if inv[n] then st.owned[n], st.confirmed[n] = true, true end
		end
		local t = meleeTool()
		if t and DEF[t.Name] then
			st.owned[t.Name] = true
			local lv = t:FindFirstChild("Level")
			if st.mastery[t.Name] == nil and lv and type(lv.Value) == "number" then st.mastery[t.Name] = lv.Value end
		end
		st.mats = function(n) return materialCount(n) or 0 end
		st.items = function(n) return hasItem(n) end
		st.teacherSea = function(n)
			for _, c in ipairs(Hub.StyleChain or {}) do
				if c[1] == n then
					if c[3][Sea] then return nil end
					for s = 3, 1, -1 do
						if c[3][s] then return s end
					end
				end
			end
		end
		return st
	end

	-----------------------------------------------------------------
	-- گزارش اینونتوری: فیلدهای واقعی‌ای که بازی برمی‌گردونه (برای اطمینان از Mastery سبک‌ها)
	-----------------------------------------------------------------
	function Styles.report()
		local lines = { os.date("%Y-%m-%d %H:%M:%S") .. "  level " .. tostring(dataValue("Level")) }
		for _, cmd in ipairs({ "getInventoryWeapons", "getInventory" }) do
			local r = invoke(cmd)
			table.insert(lines, ("== %s: %s (%d entries)"):format(cmd, type(r), type(r) == "table" and #r or 0))
			for _, item in pairs(type(r) == "table" and r or {}) do
				if type(item) == "table" then
					local parts = {}
					for k, v in pairs(item) do table.insert(parts, tostring(k) .. "=" .. tostring(v)) end
					table.sort(parts)
					table.insert(lines, "  " .. table.concat(parts, ", "))
				end
			end
		end
		table.insert(lines, "== tools")
		for _, cont in ipairs({ getChar(), player:FindFirstChild("Backpack") }) do
			for _, t in ipairs(cont and cont:GetChildren() or {}) do
				if t:IsA("Tool") then
					local vals = {}
					for _, v in ipairs(t:GetChildren()) do
						if v:IsA("ValueBase") then table.insert(vals, v.Name .. "=" .. tostring(v.Value)) end
					end
					table.insert(lines, ("  %s [%s] %s"):format(t.Name, t.ToolTip, table.concat(vals, ", ")))
				end
			end
		end
		return pcall(function() writefile("bmscan/inventory.txt", table.concat(lines, "\n")) end)
	end
	task.delay(15, function() pcall(Styles.report) end)

	-----------------------------------------------------------------
	-- اجرا
	-----------------------------------------------------------------
	local switchAt, buyAt = 0, 0

	-- عوض کردن سبک فقط برای سبکی که اینونتوری میگه داری؛ اگه پول کم شد کار متوقف میشه
	function Styles.switchTo(name, st)
		local t = meleeTool()
		if t and t.Name == name then return true end
		if not st.confirmed[name] or tick() - switchAt < 20 then return false end
		switchAt = tick()
		local before = dataValue("Beli") or 0
		local r = buyStyle(name)
		task.wait(1)
		local spent = before - (dataValue("Beli") or 0)
		V3.log(("STYLE switch to %s -> %s (beli change %d)"):format(name, tostring(r), -spent))
		if spent > 0 and not S.StyleBuy then
			S.AutoStylePlan = false
			Brain.note("Switching to " .. name .. " cost " .. formatNumber(spent) .. " Beli, plan stopped")
			V3.notify("Fighting Styles", "Switching cost Beli, plan stopped", 8)
		end
		return false
	end

	function Styles.buy(name)
		if tick() - buyAt < 60 then return end
		buyAt = tick()
		local def = DEF[name]
		local spot
		for _, c in ipairs(Hub.StyleChain or {}) do
			if c[1] == name then spot = c[3][Sea] end
		end
		local npc = def.npc and findNPC(def.npc)
		if npc then spot = npc.Position end
		if spot then
			S.Status = "Styles: going to the " .. name .. " teacher"
			tweenTo(CFrame.new(spot + Vector3.new(0, 3, 0)), function() return S.AutoStylePlan end)
			task.wait(0.5)
		end
		local before = { beli = dataValue("Beli") or 0, frag = dataValue("Fragments") or 0 }
		local r = buyStyle(name)
		task.wait(1)
		V3.log(("STYLE buy %s -> %s (beli %d, frag %d)"):format(name, tostring(r),
			(dataValue("Beli") or 0) - before.beli, (dataValue("Fragments") or 0) - before.frag))
		Brain.note("Tried to buy " .. name .. ": " .. tostring(r))
	end

	local function setFarm(farm, material)
		S.AutoFarm, S.AutoMaterial = farm, material ~= nil
		if material then S.Material = material end
	end

	function Styles.tick()
		local st = Styles.state()
		local step = Styles.plan(S.StyleTarget, st)
		-- اگه اینونتوری هیچ سبکی نشون نده، «نداری» با «نمی‌تونم بخونم» یکی میشه؛ پس هیچ کاری نمی‌کنیم
		if next(st.confirmed) == nil then
			step = { kind = "unknown", why = "can't read your fighting styles from the game inventory (send bmscan/inventory.txt)" }
		end
		Styles.step = step
		if not step then
			S.AutoStylePlan = false
			Brain.note("You have " .. S.StyleTarget .. " ✔")
			V3.notify("Fighting Styles", "You have " .. S.StyleTarget .. " ✔", 8)
			return
		end
		S.Status = "Styles: " .. step.why
		if step.kind == "mastery" then
			-- Mastery سبک با فارم معمولی و همون سبک توی دست بالا میره
			if Styles.switchTo(step.style, st) then
				S.Weapon = "Melee"
				setFarm(true)
			else
				setFarm(false)
			end
		elseif step.kind == "material" then
			local entry
			for _, m in ipairs(Hub.Materials or {}) do
				if m[1] == step.mat then entry = m end
			end
			if entry then
				setFarm(false, entry[1] .. " (" .. table.concat(entry[2], ", ") .. ")")
			else
				setFarm(false)
				S.Status = ("Styles: %s - farm it in %s"):format(step.why, MAT_SEA[step.mat] or "another sea")
			end
		elseif step.kind == "money" then
			setFarm(true)
		elseif step.kind == "buy" then
			setFarm(false)
			if S.StyleBuy then
				Styles.buy(step.style)
			else
				S.Status = "Styles: " .. step.why .. " - turn on Allow Buying"
			end
		else
			-- آیتم، دریای دیگه یا داده‌ی نامعلوم: کاری نمی‌کنیم که اشتباه نکنیم
			setFarm(false)
		end
	end

	task.spawn(function()
		local saved
		while Hub.Running do
			task.wait(2)
			if S.AutoStylePlan and alive() then
				saved = saved or { AutoFarm = S.AutoFarm, AutoMaterial = S.AutoMaterial, Weapon = S.Weapon, Material = S.Material }
				local ok, err = pcall(Styles.tick)
				if not ok then logError("Styles", err) end
			elseif saved then
				for k, v in pairs(saved) do S[k] = v end
				saved = nil
				stopTween()
			end
		end
	end)

	Styles.ready = true
end)
if not okStyles then logError("v3 styles", errStyles) end
end

--@@UI@@
local Styles = Hub.Styles
if Styles and Styles.ready then
	local T = createTab("Quests", "≋")
	T:Section("Fighting Style Plan")
	T:Dropdown("Target Style", function() return Styles.TARGETS end, "StyleTarget")
	T:Toggle("Auto Get Target Style (farms mastery + materials)", "AutoStylePlan", stopOff)
	T:Toggle("Allow Buying (spends Beli / Fragments)", "StyleBuy")
	T:Label(function()
		if not S.AutoStylePlan then return "Next: (off)" end
		return "Next: " .. (Styles.step and Styles.step.why or "...")
	end)
	local cache, cacheAt = {}, 0
	for i = 1, 9 do
		T:Label(function()
			if tick() - cacheAt > 5 then
				cacheAt = tick()
				local ok, res = pcall(function() return Styles.lines(S.StyleTarget, Styles.state()) end)
				cache = ok and res or {}
			end
			return cache[i] or ""
		end)
	end
	T:Button("Save Inventory Report (bmscan/inventory.txt)", function()
		notify("Styles", Styles.report() and "Saved ✔ - tell Claude" or "Could not write the file", 4)
	end)
end
