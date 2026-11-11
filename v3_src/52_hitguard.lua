-- نگهبان ضربه (5.9): لاگ واقعی: با شمشیر (Yama) ضربه‌ی ریموت چند ثانیه دمیج داد و بعد سرور دیگه هیچ
-- ضربه‌ای قبول نکرد (dmg/s=0 حتی با 1 ماب در هر ضربه و از 10 استادی)؛ tool:Activate هم برای شمشیر
-- هیچ دمیجی نداد (activates=123، dmg=0). پس اگه حمله میشه ولی دمیجی ثبت نمیشه، هر 2 ثانیه یه پله پایین:
--   1) 15 ماب هر ضربه  2) 5 ماب  3) 1 ماب  4) ضربه‌ی آروم‌تر + کلیک واقعی  5) فقط کلیک واقعی (بدون ریموت)
-- بعد از 90 ثانیه دمیج پشت سر هم یه پله برمی‌گرده بالا (اگه باز نخورد دوباره پایین میاد)؛
-- اگه پله‌ی آخر هم 10 ثانیه نخورد از اول امتحان میشه (شاید جریمه‌ی سرور تموم شده باشه)
-- 5.9: ماب رو فقط وقتی جابه‌جا می‌کنیم که کنترلش (network owner) دست خودمون باشه. لاگ اکانت دوستمون:
-- روی باس‌ها (که جمع نمیشن) دمیج داشت ولی روی Cookie Crafter / Cake Guard هیچی؛ جمع کردن فقط توی
-- صفحه‌ی خودمون بود، ماب روی سرور جای دیگه بود، ضربه‌ها «دور» رد می‌شدن و ماب‌های واقعی می‌زدنمون
function Hub.OwnsPart(p)
	if isnetworkowner then
		local ok, r = pcall(isnetworkowner, p)
		if ok and type(r) == "boolean" then return r end
	end
	local ok, age = pcall(function() return p.ReceiveAge end)
	if ok and type(age) == "number" then return age == 0 end
	return true -- نمی‌شه فهمید: مثل قبل
end

do
	local LADDER = {
		{ limit = 15, gap = 0.1 },
		{ limit = 5, gap = 0.1 },
		{ limit = 1, gap = 0.1 },
		{ limit = 1, gap = 0.4, swing = true },
		{ limit = 1, gap = 0.4, swing = true, noRemote = true },
	}
	local HG = { step = 1, sentAt = -1e9, quietSince = nil, goodSince = nil }
	Hub.HitGuard = HG
	HG.LADDER = LADDER

	local function note(msg)
		if Hub.LiveLog then Hub.LiveLog("HITS " .. msg) end
	end

	function HG.set(step)
		local s = LADDER[step]
		HG.step, HG.limit, HG.gap, HG.swing, HG.noRemote = step, s.limit, s.gap, s.swing == true, s.noRemote == true
	end
	HG.set(1)

	function HG.describe()
		if HG.noRemote then return "clicks-only" end
		return tostring(HG.limit) .. (HG.gap > 0.1 and "/slow" or "") .. (HG.swing and "+clicks" or "")
	end

	function HG.sent()
		HG.sentAt = tick()
	end

	-- همه‌ی پله‌ها امتحان شد؟ (تا اون موقع ارتفاع عوض نمیشه)
	function HG.exhausted()
		return HG.step >= #LADDER
	end

	-- now: زمان، dmg: دمیج این نیم ثانیه روی ماب‌های نزدیک
	function HG.update(now, dmg)
		if now - HG.sentAt > 1 then
			HG.quietSince = nil
			return
		end
		if dmg > 0 then
			HG.quietSince = nil
			HG.goodSince = HG.goodSince or now
			if now - HG.goodSince >= 30 and HG.step > 1 then
				HG.set(HG.step - 1)
				HG.goodSince = now
				note("steady damage, trying faster again: " .. HG.describe())
			end
			return
		end
		HG.goodSince = nil
		HG.quietSince = HG.quietSince or now
		if HG.step < #LADDER then
			if now - HG.quietSince < 4 then return end
			HG.quietSince = now
			HG.set(HG.step + 1)
			note("no damage, the server is ignoring hits: now " .. HG.describe())
		elseif now - HG.quietSince >= 10 then
			HG.quietSince = now
			HG.set(1)
			note("nothing worked for 10s, starting over: " .. HG.describe())
		end
	end

	-- دمیج واقعی هر نیم ثانیه: کم شدن جون ماب‌های نزدیک
	local hp = setmetatable({}, { __mode = "k" })
	task.spawn(function()
		while Hub.Running do
			task.wait(0.5)
			pcall(function()
				local root = getRoot()
				local enemies = workspace:FindFirstChild("Enemies")
				if not root or not enemies then return end
				local drop = 0
				for _, m in ipairs(enemies:GetChildren()) do
					local hum, hrp = m:FindFirstChildOfClass("Humanoid"), m:FindFirstChild("HumanoidRootPart")
					if hum and hrp and (hrp.Position - root.Position).Magnitude <= S.AttackRange + 20 then
						if hp[hum] and hum.Health < hp[hum] then drop += hp[hum] - hum.Health end
						hp[hum] = hum.Health
					end
				end
				HG.update(tick(), drop)
			end)
		end
	end)
end
