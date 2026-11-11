"""
bm_hub_v3.lua = bm_hub_v2.lua + ماژول‌های v3_src (به ترتیب شماره‌ی فایل).

هر فایل v3_src/NN_name.lua دو بخش داره که با خط `--@@UI@@` جدا میشن:
  بالا: منطق (قبل از بخش UI فایل اصلی درج میشه)
  پایین: تب‌های UI (بین تب‌های Bosses و Items درج میشه)
اگه UI با `-- @top` شروع بشه درست بعد از Home میاد. بخشی که بعد از خط `--@@UI-LATE@@` بیاد
آخر همه‌ی صفحه‌ها درج میشه (برای اضافه کردن بخش به انتهای تب‌های موجود مثل Combat).

اجرا:  python build_v3.py
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent
BASE = ROOT / "bm_hub_v2.lua"
OUT = ROOT / "bm_hub_v3.lua"
VERSION = "5.9"


def patch(src, old, new, count=1):
    n = src.count(old)
    if n != count:
        sys.exit(f"anchor found {n}x (expected {count}): {old[:70]!r}")
    return src.replace(old, new)


src = BASE.read_text(encoding="utf-8")  # \r\n -> \n

src = patch(src, 'Version = "1.75"', f'Version = "{VERSION}"')
src = patch(src, "loader_v2.lua", "loader_v3.lua", 2)

# --- v5.6: مکث Auto Click وقتی باید کتک بخوریم (جاخالی مشاهده، CDK Yama 1) ---
src = patch(src, "\t\tif S.AutoClick and alive() then\n\t\t\tlocal mob = nearestMobInRange()",
	"\t\tif S.AutoClick and alive() and not S.KenFarm and tick() >= (Hub.HoldAttackUntil or 0) then\n\t\t\tlocal mob = nearestMobInRange()")

# Auto Observation قدیمی هر 5 ثانیه Ken رو روشن می‌کرد و نمی‌ذاشت سرویس جاخالی صبر کنه تا پر بشه
src = patch(src, 'if S.AutoKen and CommE then', 'if S.AutoKen and not S.KenFarm and CommE then')

# --- v5.9: Auto Click توی بعضی اکانت‌ها کار نمی‌کرد ---
# همه‌ی اکانت‌های یه کامپیوتر یه فایل تنظیمات داشتن (و چند پنجره‌ی هم‌زمان روی هم می‌نوشتن)؛ لاگ واقعی:
# AutoClick=false ذخیره شده بود و هر اکانتی که بعدش باز می‌شد بدون Auto Click شروع می‌کرد.
# حالا هر اکانت فایل خودش رو داره (اولین بار از فایل قدیمی مشترک کپی میشه) و Auto Click ذخیره نمیشه:
# همیشه روشن شروع میشه
src = patch(src, 'local SETTINGS_FILE = "BMHub_settings.json"\n',
	'''local SHARED_SETTINGS = "BMHub_settings.json"
local SETTINGS_FILE = "BMHub_settings_" .. tostring(player.UserId) .. ".json"
''')
src = patch(src, 'SummonSoulReaper = true, SummonDoughKing = true }\n\nlocal function saveSettings()',
	'SummonSoulReaper = true, SummonDoughKing = true, AutoClick = true }\n\nlocal function saveSettings()')
src = patch(src, '''local function loadSettings()
	local ok, data = pcall(function()
		if isfile and not isfile(SETTINGS_FILE) then return nil end
		return Svc.Http:JSONDecode(readfile(SETTINGS_FILE))
	end)
	if not ok or type(data) ~= "table" then return false end
''', '''local function readSettings(file)
	local ok, data = pcall(function()
		if isfile and not isfile(file) then return nil end
		return Svc.Http:JSONDecode(readfile(file))
	end)
	return ok and type(data) == "table" and data or nil
end

local function loadSettings()
	local data = readSettings(SETTINGS_FILE) or readSettings(SHARED_SETTINGS)
	if not data then return false end
''')
# Attack Test اگه وسطش ماب می‌مرد خطا می‌داد و Auto Click خاموش می‌موند
src = patch(src, '\t\t\tlocal savedClick = S.AutoClick\n\t\t\tS.AutoClick = false\n',
	'\t\t\tlocal savedClick = S.AutoClick\n\t\t\tS.AutoClick = false\n\t\t\tlocal testOk, testErr = pcall(function()\n')
src = patch(src, '\t\t\tS.AutoClick = savedClick\n\t\t\tnotify("Attack Test", "Done ✔ - tell Claude", 6)\n',
	'''\t\t\tend)
\t\t\tS.AutoClick = savedClick
\t\t\tif not testOk then log("ATTACK TEST stopped: " .. tostring(testErr)) end
\t\t\tnotify("Attack Test", "Done ✔ - tell Claude", 6)
''')

# --- v5.8: دکمه‌ی «برو دریای بعد» وقتی همون دریایی فقط اسماً روشنه ---
# لاگ واقعی: AutoSea3 توی دریای 3 روشن مونده بود (اونجا کاری نمی‌کنه) ولی چون «فارم روشنه» حساب می‌شد
# سرعت راه رفتن هیچ‌وقت کار نمی‌کرد. فقط توی دریای قبل از مقصد حساب میشه
src = patch(src, "or S.AutoSea2 or S.AutoBartilo or S.AutoSea3 or S.AutoSaber",
	"or (S.AutoSea2 and Sea == 1) or S.AutoBartilo or (S.AutoSea3 and Sea == 2) or S.AutoSaber", 2)

# --- v5.5: ریموت‌های حمله توی دریای 3 ---
# دریای 3 سنگین‌ترین نقشه‌ست و دیرتر لود میشه؛ اگه هاب زودتر اجرا بشه Modules/Net هنوز نیومده و
# RegisterAttack/RegisterHit برای کل بازی nil می‌موند: هیچ ضربه‌ای زده نمی‌شد و خطایی هم نشون داده نمی‌شد
src = patch(src, 'local Modules = ReplicatedStorage:FindFirstChild("Modules")\nlocal Net = Modules and Modules:FindFirstChild("Net")',
	'local Modules = ReplicatedStorage:WaitForChild("Modules", 20)\nlocal Net = Modules and Modules:WaitForChild("Net", 20)')
src = patch(src, 'local RegisterAttack = findRemote("RegisterAttack")\nlocal RegisterHit = findRemote("RegisterHit")\n',
	'''local RegisterAttack = findRemote("RegisterAttack")
local RegisterHit = findRemote("RegisterHit")
-- اگه هنوز پیدا نشدن (یا بازی عوضشون کرد) هر 2 ثانیه دوباره گشته میشه
local remotesCheckedAt = 0
local function attackRemotes()
	if RegisterAttack and RegisterAttack.Parent and RegisterHit and RegisterHit.Parent then return true end
	Hub.AttackInfo.lastError = "attack remotes not found yet"
	if tick() - remotesCheckedAt < 2 then return false end
	remotesCheckedAt = tick()
	if not Net then
		Modules = ReplicatedStorage:FindFirstChild("Modules")
		Net = Modules and Modules:FindFirstChild("Net")
	end
	RegisterAttack, RegisterHit = findRemote("RegisterAttack"), findRemote("RegisterHit")
	if RegisterAttack and RegisterHit then return true end
	Hub.AttackInfo.lastError = "attack remotes not found yet"
	return false
end
''')
src = patch(src, '\tif not (RegisterAttack and RegisterHit) then return end\n\tif tick() - cooldown.remote < 0.1 then return end',
	'\tif not attackRemotes() then return end\n\tif tick() - cooldown.remote < 0.1 then return end')

# v5.2 شمشیرها: Tushita و CDK با موتور جدید ماژول 95_swords (مراحل از Banana)
src = patch(
    src,
    'if S.AutoTushita and Sea == 3 then step, flag = stepTushita, "AutoTushita"\n'
    '\t\t\t\telseif S.AutoCDK and Sea == 3 then step, flag = stepCDK, "AutoCDK"\n',
    'if S.AutoTushita and Sea == 3 then step, flag = Hub.V3.tushitaStep or stepTushita, "AutoTushita"\n'
    '\t\t\t\telseif S.AutoCDK and Sea == 3 then step, flag = Hub.V3.cdkStep or stepCDK, "AutoCDK"\n',
)
# Yama (از Banana): زیر 30 خودش Elite می‌زنه؛ کنار شمشیر اگه Ghost اومد اول اونا رو می‌کشه
src = patch(
    src,
    '\t\t\tS.Status = ("Yama: elites %d/30 (turn on Auto Elite)"):format(prog)\n'
    '\t\t\ttask.wait(5)\n'
    '\t\t\treturn\n',
    '\t\t\tS.Status = ("Yama: elites %d/30"):format(prog)\n'
    '\t\t\tstepElite(keep)\n'
    '\t\t\treturn\n',
)
src = patch(
    src,
    '\t\tS.Status = "Yama: pulling the sword"\n'
    '\t\ttweenTo(hit.CFrame * CFrame.new(0, 3, 0), keep)\n',
    '\t\tlocal ghost = findMob("Ghost")\n'
    '\t\tif ghost and (ghost.HumanoidRootPart.Position - hit.Position).Magnitude < 300 then\n'
    '\t\t\tS.Status = "Yama: killing the Ghosts"\n'
    '\t\t\tkillMob(ghost, keep)\n'
    '\t\t\treturn\n'
    '\t\tend\n'
    '\t\tS.Status = "Yama: pulling the sword"\n'
    '\t\ttweenTo(hit.CFrame * CFrame.new(0, 3, 0), keep)\n',
)

# v5.1 تویین: اگه بازی خودش تلپورتمون کرد (ورود به Raid، Trial، پورتال) مسیر قبلی رو ادامه نده.
# قبلاً این پرش رو «پس زدن سرور» حساب می‌کرد و از توی Raid دوباره سمت مقصد قدیمی پرواز می‌کرد
src = patch(
    src,
    "\t\tif (pos - expected).Magnitude > 25 then\n",
    "\t\tif (pos - expected).Magnitude > 1000 then\n"
    "\t\t\tbreak -- بازی تلپورتمون کرد؛ مسیر قبلی دیگه معنی نداره\n"
    "\t\tend\n"
    "\t\tif (pos - expected).Magnitude > 25 then\n",
)

# v5.1 Raid: بعد از زدن دکمه چیپ مصرف میشه ولی هنوز توی Raid نیستیم؛ قبلاً میرفت چیپ بخره (سمت Scientist)
# و بعد از تلپورت به Raid همون مسیر رو ادامه می‌داد. حالا تا Raid شروع بشه صبر می‌کنه و هر حرکت بیرونی
# به محض شروع Raid قطع میشه. روی جزیره‌ی خالی هم «منتظر ماب» می‌مونه (Watchdog ریستت نمی‌کنه)
src = patch(
    src,
    "\tlocal function raidChip()\n",
    "\tlocal raidClickedAt = 0\n"
    "\tlocal function inRaid()\n"
    "\t\tif raidIsland() then return true end\n"
    "\t\tlocal ok, vis = pcall(function() return player.PlayerGui.Main.TopHUDList.RaidTimer.Visible end)\n"
    "\t\treturn ok and vis == true\n"
    "\tend\n"
    "\tHub.InRaid = inRaid\n\n"
    "\tlocal function raidChip()\n",
)
src = patch(
    src,
    "\t\t\t\tlocal keep = function() return S.AutoRaid end\n"
    "\t\t\t\tlocal ok, err = pcall(function()\n"
    "\t\t\t\t\tlocal island, idx = raidIsland()\n"
    "\t\t\t\t\tif island then\n",
    "\t\t\t\tlocal keep = function() return S.AutoRaid end\n"
    "\t\t\t\tlocal keepOut = function() return S.AutoRaid and not inRaid() end\n"
    "\t\t\t\tlocal ok, err = pcall(function()\n"
    "\t\t\t\t\tlocal island, idx = raidIsland()\n"
    "\t\t\t\t\tif not island and inRaid() then\n"
    "\t\t\t\t\t\tS.Status = \"Raid: waiting for the islands to load\"\n"
    "\t\t\t\t\t\ttask.wait(1)\n"
    "\t\t\t\t\t\treturn\n"
    "\t\t\t\t\tend\n"
    "\t\t\t\t\tif island then\n",
)
src = patch(
    src,
    "\t\t\t\t\t\t\tS.Status = \"Raid: going to island \" .. idx\n"
    "\t\t\t\t\t\t\ttweenTo(island.CFrame * CFrame.new(0, 60, 0), keep)\n",
    "\t\t\t\t\t\t\tlocal spot = island.CFrame * CFrame.new(0, 60, 0)\n"
    "\t\t\t\t\t\t\tif (root.Position - spot.Position).Magnitude > 30 then\n"
    "\t\t\t\t\t\t\t\tS.Status = \"Raid: going to island \" .. idx\n"
    "\t\t\t\t\t\t\t\ttweenTo(spot, keep)\n"
    "\t\t\t\t\t\t\telse\n"
    "\t\t\t\t\t\t\t\tS.Status = \"Raid: waiting for mobs on island \" .. idx\n"
    "\t\t\t\t\t\t\t\tsetFloat(true)\n"
    "\t\t\t\t\t\t\t\ttask.wait(0.5)\n"
    "\t\t\t\t\t\t\tend\n",
)
src = patch(
    src,
    "\t\t\t\t\tlocal chip = raidChip()\n"
    "\t\t\t\t\tif chip then\n",
    "\t\t\t\t\tlocal chip = raidChip()\n"
    "\t\t\t\t\tif not chip and tick() - raidClickedAt < 30 then\n"
    "\t\t\t\t\t\tS.Status = \"Raid: waiting for the raid to start\"\n"
    "\t\t\t\t\t\ttask.wait(1)\n"
    "\t\t\t\t\t\treturn\n"
    "\t\t\t\t\tend\n"
    "\t\t\t\t\tif chip then\n",
)
src = patch(src, "tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 20, 0)), keep)", "tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 20, 0)), keepOut)")
src = patch(src, "tweenTo(btn.CFrame * CFrame.new(0, 3, 0), keep)", "tweenTo(btn.CFrame * CFrame.new(0, 3, 0), keepOut)")
src = patch(src, "tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 3, 4)), keep)", "tweenTo(CFrame.new(SCIENTIST + Vector3.new(0, 3, 4)), keepOut)")
src = patch(
    src,
    "\t\t\t\t\t\tif fireclickdetector then pcall(fireclickdetector, btn:FindFirstChildOfClass(\"ClickDetector\")) end\n"
    "\t\t\t\t\t\ttask.wait(5)\n",
    "\t\t\t\t\t\tif fireclickdetector then pcall(fireclickdetector, btn:FindFirstChildOfClass(\"ClickDetector\")) end\n"
    "\t\t\t\t\t\traidClickedAt = tick()\n"
    "\t\t\t\t\t\tlocal t0 = tick()\n"
    "\t\t\t\t\t\twhile keep() and not inRaid() and tick() - t0 < 20 do\n"
    "\t\t\t\t\t\t\tS.Status = \"Raid: waiting for the raid to start\"\n"
    "\t\t\t\t\t\t\ttask.wait(0.5)\n"
    "\t\t\t\t\t\tend\n",
)

# فارم‌های جدید جزو «کار اصلی» حساب بشن (صندوق/میوه صبر کنن)
busy_old = "or (Hub.SpecialAny ~= nil and Hub.SpecialAny())"
src = patch(src, busy_old, busy_old + "\n\t\tor (Hub.V3Busy ~= nil and Hub.V3Busy())", 2)

# گزینه‌هایی که پول خرج می‌کنن توی ذخیره‌سازی نمیان
src = patch(
    src,
    "local function saveSettings()",
    "for k in pairs(Hub.V3SkipSave or {}) do SKIP_SAVE[k] = true end\n\nlocal function saveSettings()",
)

# قلاب‌های مغز توی killMob (جاخالی، اسکیل هوشمند، نشونه‌ی پیشرفت برای نگهبان)
src = patch(
    src,
    'S.Status = "Farming: " .. name\n\tlocal lastHp, lastHit',
    'S.Status = "Farming: " .. name\n\tif Hub.WatchMob then Hub.WatchMob(mob, hum) end\n\tlocal lastHp, lastHit',
)
src = patch(
    src,
    "\t\t\tlastHp, lastHit = hum.Health, tick()\n",
    "\t\t\tlastHp, lastHit = hum.Health, tick()\n\t\t\tHub.LastProgress = lastHit\n",
)
src = patch(
    src,
    "local h = math.clamp(S.FarmHeight, 0, 40)\n",
    # v5.1: ارتفاع یادگرفته‌ی هر نوع سلاح (Hub.HeightCap) سقف Farm Height میشه
    "local h = math.min(math.clamp(S.FarmHeight, 0, 100), Hub.HeightCap and Hub.HeightCap() or 100) + (Hub.DodgeY or 0)\n",
)
src = patch(
    src,
    "\t\tattack(mob)\n",
    "\t\tattack(mob)\n\t\tif Hub.SmartSkill then Hub.SmartSkill(mob, hum) end\n",
)

# فرار هوشمند: علاوه بر درصد ثابت، وقتی با این سرعت دمیج چند ثانیه‌ی دیگه می‌میریم
src = patch(
    src,
    "me.Health / me.MaxHealth * 100 < S.RetreatHP then",
    "(me.Health / me.MaxHealth * 100 < S.RetreatHP or (Hub.InDanger and Hub.InDanger(me.Health))) then",
)

# Auto Click سلاح رو عوض نمی‌کنه: هر فارم سلاح خودش رو می‌گیره، و بدون فارم با چیزی که دستته می‌زنه
src = patch(
    src,
    "equipWeapon()\n\t\t\t\t\t-- وقتی فارم روشنه خودش جای کاراکتر",
    'local held = getChar() and getChar():FindFirstChildOfClass("Tool")\n'
    "\t\t\t\t\tif not held then\n"
    "\t\t\t\t\t\tif not mainFarmBusy() then return end\n"
    "\t\t\t\t\t\tequipWeapon()\n"
    "\t\t\t\t\tend\n"
    "\t\t\t\t\t-- وقتی فارم روشنه خودش جای کاراکتر",
)

# Auto Click با میوه‌هایی که M1 دارن (50_brain)
src = patch(
    src,
    'if m == "Auto" or m == "Remote" then remoteAttack(root) end\n',
    '-- میوه‌ی M1 دار: بدون کلیک روی صفحه و انیمیشن\n'
    '\tlocal fruit = (m == "Auto" or m == "Remote") and Hub.FruitM1 and Hub.FruitM1(root)\n'
    '\tif fruit then\n'
    '\t\t-- میوه‌ی شمشیری (melee) ضربه‌ی چندهدفه‌ی ملی می‌خوره، بقیه M1 خودشون؛ هیچ‌کدوم کلیک روی صفحه نداره\n'
    '\t\tif fruit.melee then remoteAttack(root) end\n'
    '\t\treturn\n'
    '\tend\n'
    '\tif m == "Auto" or m == "Remote" then remoteAttack(root) end\n',
)
# لاگ حمله: دمیج واقعی در ثانیه و تعداد M1 میوه، برای مقایسه‌ی سلاح‌ها
src = patch(
    src,
    '"ATTACK held=%s near=%d target=%s hp=%d dist=%d | clicks=%d',
    '"ATTACK held=%s near=%d target=%s hp=%d dist=%d dmg/s=%d fruitM1=%d | clicks=%d',
)
src = patch(
    src,
    "math.floor(best.Humanoid.Health), math.floor(bestD), a.click, a.tool,",
    "math.floor(best.Humanoid.Health), math.floor(bestD), math.floor(Hub.DamageRate and Hub.DamageRate() or 0), a.fruit or 0, a.click, a.tool,",
)

# مکان معلم‌های فایتینگ استایل برای 70_styles
src = patch(src, "\tlocal styleTried = {}\n", "\tlocal styleTried = {}\n\tHub.StyleChain = STYLE_CHAIN\n")

# Auto Sea Beast با موتور Sea Event جدید (10_sea): شکار، جاخالی، دو حالت حمله
src = patch(src, 'step, flag = stepSeaBeast, "AutoSeaBeast"', 'step, flag = (Hub.V3 and Hub.V3.seaBeastStep) or stepSeaBeast, "AutoSeaBeast"')
src = patch(src, 'T:Toggle("Auto Sea Beast (fly over it + skills)", "AutoSeaBeast", stopOff)', 'T:Toggle("Auto Sea Beast (hunts + fights, uses the Sea Event settings)", "AutoSeaBeast", stopOff)')
src = patch(
    src,
    'T:Dropdown("Sea Beast Weapon", function() return { "Blox Fruit", "Sword", "Gun", "Melee" } end, "SeaBeastWeapon")',
    'T:Label(function() return "Attack mode, weapon and heights: Sea Event section" end)',
)
# ایستادن روی آب برای نصب تازه هم پیش‌فرض روشن
src = patch(src, "WalkOnWater = false,", "WalkOnWater = true,")

# سرعت و پرش از Settings به Combat (منطق واقعی‌شون توی 80_move)
src = patch(
    src,
    '\tT:Toggle("WalkSpeed", "SpeedOn", function(on)\n'
    "\t\tif not on then local h = getHum() if h then h.WalkSpeed = 16 end end\n"
    "\tend)\n"
    '\tT:Slider("Speed", 16, 300, "WalkSpeed")\n'
    '\tT:Toggle("JumpPower", "JumpOn", function(on)\n'
    "\t\tif not on then local h = getHum() if h then h.JumpPower = 50 end end\n"
    "\tend)\n"
    '\tT:Slider("Jump", 50, 300, "JumpPower")\n',
    "",
)
src = patch(
    src,
    '\tT:Slider("Tween Speed (max 300 safe)", 100, 300, "TweenSpeed")\nend\n',
    '\tT:Slider("Tween Speed (max 300 safe)", 100, 300, "TweenSpeed")\n'
    '\tT:Section("Speed & Jump (real)")\n'
    '\tT:Toggle("Walk Speed", "SpeedOn", function(on)\n'
    "\t\tif not on then local h = getHum() if h then h.WalkSpeed = 16 end end\n"
    "\tend)\n"
    '\tT:Slider("Speed", 16, 300, "WalkSpeed")\n'
    '\tT:Label(function() return ("Real speed now: %d studs/s"):format(Hub.Move and math.floor(Hub.Move.speed) or 0) end)\n'
    '\tT:Toggle("Jump Power", "JumpOn", function(on)\n'
    "\t\tif not on then local h = getHum() if h then h.JumpPower = 50 end end\n"
    "\tend)\n"
    '\tT:Slider("Jump", 50, 300, "JumpPower")\n'
    '\tT:Label(function() return ("Jump height: about %d studs"):format(Hub.Move and Hub.Move.jumpHeight() or 0) end)\n'
    '\tT:Toggle("Infinite Jump", "InfJump")\n'
    "end\n",
)
src = patch(src, '\tT:Toggle("Infinite Jump", "InfJump")\n\tT:Toggle("Noclip", "Noclip")\n', '\tT:Toggle("Noclip", "Noclip")\n')

# ماب‌ها با ضربه عقب میرن و کل دسته رو با خودشون می‌کشن؛ پس دسته روی یه نقطه‌ی ثابت قفل میشه
src = patch(src, "\tlocal name = mobBaseName(mob.Name)\n\tS.Status", "\tlocal name = mobBaseName(mob.Name)\n\tlocal stackAt = hrp and hrp.CFrame\n\tS.Status")
src = patch(src, "if S.BringMobs then bringMobs(name, hrp.CFrame) end", "if S.BringMobs then bringMobs(name, stackAt or hrp.CFrame) end")

# فاصله از ماب‌ها موقع فارم تا 100؛ برد ضربه همراهش بیشتر میشه وگرنه از بالا هیچ مابی توی برد نیست
src = patch(src, 'T:Slider("Farm Height (above mobs)", 0, 40, "FarmHeight")', 'T:Slider("Farm Height (above mobs)", 0, 100, "FarmHeight")')
src = patch(
    src,
    "\t\t\t\tif d <= S.AttackRange then\n\t\t\t\t\ttable.insert(found",
    "\t\t\t\tif d <= math.max(S.AttackRange, S.FarmHeight + 20) then\n\t\t\t\t\ttable.insert(found",
)

# موقع زدن کمی بالاتر از ماب‌ها: پیش‌فرض 12 → 25؛ تنظیم ذخیره‌شده‌ی قدیمی یک بار بالا میره
# (درست بعد از لود تنظیمات و قبل از ساخت UI، تا اسلایدر عدد درست رو نشون بده)
src = patch(src, "FarmHeight = 12,", "FarmHeight = 25,")
src = patch(
    src,
    "local settingsLoaded = loadSettings()\n",
    "local settingsLoaded = loadSettings()\n"
    "if not S.HeightDefault then\n"
    "\tS.HeightDefault = true\n"
    "\tif S.FarmHeight < 25 then S.FarmHeight = 25 end\n"
    "end\n"
    # 5.9: ارتفاع‌های 10 که نسخه‌های قبل اشتباهی یاد گرفته بودن پاک میشن (کاراکتر چسبیده به NPC ها بود)
    # (یادگیری ارتفاع کلاً خاموشه؛ عددهای قدیمی فایل تنظیمات هر بار پاک میشن)
    "if Hub.ResetHeightCaps then Hub.ResetHeightCaps() end\n",
)

# Server Finder هم بعد از تلپورت اگه لانچر سریع محلی هست از همون استفاده کنه
src = patch(
    src,
    "\tlocal LOADER = 'loadstring(game:HttpGet(\"https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua\"))()'\n",
    "\tlocal LOADER = (isfile and select(2, pcall(isfile, \"bm.lua\")) == true) and 'loadstring(readfile(\"bm.lua\"))()'\n"
    "\t\tor 'loadstring(game:HttpGet(\"https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua\"))()'\n",
)

# صندوق‌ها: Safe Carry و شمارش برای Chest Hop
src = patch(
    src,
    "if S.AutoChest and alive() and not mainFarmBusy() then",
    "if S.AutoChest and alive() and not mainFarmBusy() and not (Hub.CarryBlock and Hub.CarryBlock()) then",
)
src = patch(
    src,
    'S.Status = "Collecting chest"\n',
    'S.Status = "Collecting chest"\n\t\t\t\tHub.ChestsTaken = (Hub.ChestsTaken or 0) + 1\n',
)

# Bone: سه مشکلی که لاگ بازی نشون داد
# 1) hasQuest هر بار صدا زده بشه: فقط همون یادش می‌مونه کادر کوئست دیده شده؛ وگرنه بعد از تموم
#    شدن کوئست تا 60 ثانیه فعال حساب میشد و کوئست بعدی گرفته نمیشد
src = patch(
    src,
    '\t\tlocal title = questTitle()\n\t\tif not title then return hasQuest("Posessed Mummy") end\n',
    '\t\tlocal active = hasQuest("Posessed Mummy")\n\t\tlocal title = questTitle()\n\t\tif not title then return active end\n',
)
# 2) اول ماب‌های اطراف تموم میشن؛ مومیایی دور و تحویل کوئست وقتی اطراف خالی شد
src = patch(
    src,
    "\tlocal function stepBone(keep)\n",
    "\tlocal BONE_CLEAR = 150\n"
    "\tlocal function boneScan()\n"
    "\t\tlocal root = getRoot()\n"
    "\t\tlocal nearest, nearestDist, mummy, mummyDist\n"
    "\t\tfor _, n in ipairs(BONE_MOBS) do\n"
    "\t\t\tlocal m = findMob(n)\n"
    "\t\t\tif m then\n"
    "\t\t\t\tlocal d = (m.HumanoidRootPart.Position - root.Position).Magnitude\n"
    "\t\t\t\tif not nearestDist or d < nearestDist then nearest, nearestDist = m, d end\n"
    '\t\t\t\tif n == "Posessed Mummy" then mummy, mummyDist = m, d end\n'
    "\t\t\tend\n"
    "\t\tend\n"
    "\t\treturn nearest, nearestDist, mummy, mummyDist\n"
    "\tend\n\n"
    "\tlocal function boneTarget()\n"
    "\t\tlocal nearest, nearestDist, mummy, mummyDist = boneScan()\n"
    "\t\tif not nearest then return nil end\n"
    "\t\tlocal quest = mummyQuestActive()\n"
    "\t\tif nearestDist <= BONE_CLEAR then\n"
    "\t\t\treturn quest and mummy and mummyDist <= BONE_CLEAR and mummy or nearest\n"
    "\t\tend\n"
    "\t\treturn quest and mummy or nearest\n"
    "\tend\n\n"
    "\tlocal function stepBone(keep)\n",
)
src = patch(
    src,
    'local target = findMob("Posessed Mummy")\n'
    "\t\t-- وقتی مومیایی نیست، بقیه‌ی ماب‌های Bone رو می‌زنیم (بدون کوئست، فقط برای Bone)\n"
    "\t\tif not target then\n"
    "\t\t\tlocal root = getRoot()\n"
    "\t\t\tlocal bestDist\n"
    "\t\t\tfor _, n in ipairs(BONE_MOBS) do\n"
    "\t\t\t\tlocal m = findMob(n)\n"
    "\t\t\t\tif m then\n"
    "\t\t\t\t\tlocal d = (m.HumanoidRootPart.Position - root.Position).Magnitude\n"
    "\t\t\t\t\tif not bestDist or d < bestDist then target, bestDist = m, d end\n"
    "\t\t\t\tend\n"
    "\t\t\tend\n"
    "\t\tend\n",
    "local target = boneTarget()\n",
)
# گرفتن کوئست هم صبر می‌کنه تا اطراف تمیز بشه، ولی حداکثر 20 ثانیه تا کوئست یادش نره
src = patch(
    src,
    "\t\t\tif tick() - Hub.MummyGoneAt >= 1.5 then\n\t\t\t\ttakeQuest(q, keep)\n",
    "\t\t\tlocal _, nearDist = boneScan()\n"
    "\t\t\tlocal clear = not nearDist or nearDist > BONE_CLEAR\n"
    "\t\t\tif tick() - Hub.MummyGoneAt >= 1.5 and (clear or tick() - Hub.MummyGoneAt >= 20) then\n"
    "\t\t\t\ttakeQuest(q, keep)\n",
)
# 3) هر چهار نوع ماب Bone یک‌جا جمع بشن تا ضربه به همه بخوره، و سقف جمع کردن برای Bone حداقل 15 باشه
src = patch(
    src,
    '\t\tif mobBaseName(m.Name) == name and isAliveMob(m) then\n\t\t\tlocal d = (m.HumanoidRootPart.Position - root.Position).Magnitude\n\t\t\tif d <= S.BringRange then',
    '\t\tlocal base = mobBaseName(m.Name)\n\t\tif (base == name or (Hub.BringGroup and Hub.BringGroup[base])) and isAliveMob(m) then\n\t\t\tlocal d = (m.HumanoidRootPart.Position - root.Position).Magnitude\n\t\t\tif d <= S.BringRange then',
)
src = patch(
    src,
    "\tfor i = 1, math.min(#list, S.BringMax) do\n",
    "\tfor i = 1, math.min(#list, Hub.BringGroup and math.max(S.BringMax, 15) or S.BringMax) do\n",
)
# v5.1 ارتفاع هوشمند: قبل از رد کردن ماب بی‌آسیب، اول پایین‌تر امتحان می‌کنه
src = patch(
    src,
    "\t\telseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120 then\n"
    "\t\t\tmobSkipUntil[mob] = tick() + 45\n",
    "\t\telseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120\n"
    "\t\t\tand (root.Position.Y - hrp.Position.Y) > 11 and Hub.LowerHeight and Hub.LowerHeight() then\n"
    "\t\t\tlastHit = tick()\n"
    "\t\telseif tick() - lastHit > 8 and (root.Position - hrp.Position).Magnitude < 120 then\n"
    "\t\t\tmobSkipUntil[mob] = tick() + 45\n",
)
# لاگ: ببینیم ردشدن 45 ثانیه‌ای واقعاً رخ میده یا نه
src = patch(
    src,
    "\t\t\tmobSkipUntil[mob] = tick() + 45\n",
    "\t\t\tmobSkipUntil[mob] = tick() + 45\n"
    '\t\t\tif Hub.LiveLog then Hub.LiveLog(("SKIP %s for 45s: no damage in 8s, hp=%d dist=%d"):format(name, hum.Health, (root.Position - hrp.Position).Magnitude)) end\n',
)
src = patch(
    src,
    '(mummyQuestActive() and " (mummy quest)" or "")\n\t\tkillMob(target, keep)\n',
    '(mummyQuestActive() and " (mummy quest)" or "")\n'
    '\t\tHub.BringGroup = { ["Reborn Skeleton"] = true, ["Living Zombie"] = true, ["Demonic Soul"] = true, ["Posessed Mummy"] = true }\n'
    '\t\tlocal fought, fightErr = pcall(killMob, target, keep)\n'
    '\t\tHub.BringGroup = nil\n'
    '\t\tif not fought then error(fightErr, 0) end\n',
)

# منو: تب‌های هم‌موضوع یکی میشن و هر بخش با کلیک جمع و باز میشه
src = patch(
    src,
    "local Pages, Tabs, tabCount = {}, {}, 0\n",
    "local Pages, Tabs, tabCount = {}, {}, 0\n"
    "Hub.TabUI = { apis = {}, groups = {}, order = { Home = 1, Brain = 2, Farm = 3, Quests = 4, Bosses = 5, Sea = 6, Items = 7, Combat = 8, Teleport = 9, Settings = 10 } }\n",
)
src = patch(
    src,
    "local function createTab(name, icon)\n\ttabCount += 1\n",
    "local function createTab(name, icon)\n\t-- اسم تکراری = بخش‌های جدید به انتهای همون صفحه اضافه میشن\n\tif Hub.TabUI.apis[name] then return Hub.TabUI.apis[name] end\n\ttabCount += 1\n",
)
src = patch(
    src,
    "AutoButtonColor = false, LayoutOrder = tabCount, Parent = tabList,",
    "AutoButtonColor = false, LayoutOrder = Hub.TabUI.order[name] or tabCount + 20, Parent = tabList,",
)
src = patch(
    src,
    "\tlocal order = 0\n\tlocal api = {}\n",
    "\tlocal order = 0\n\tlocal api = {}\n\tlocal groups, group = {}, nil\n\tHub.TabUI.apis[name], Hub.TabUI.groups[name] = api, groups\n",
)
src = patch(
    src,
    '\t\torder += 1\n\t\treturn new("Frame", {\n\t\t\tSize = UDim2.new(1, 0, 0, h), BackgroundColor3 = Theme.Card, LayoutOrder = order, Parent = page,\n\t\t}, { corner(9) })\n',
    '\t\torder += 1\n\t\tlocal c = new("Frame", {\n\t\t\tSize = UDim2.new(1, 0, 0, h), BackgroundColor3 = Theme.Card, LayoutOrder = order, Parent = page,\n\t\t}, { corner(9) })\n'
    "\t\tif group then table.insert(group.items, c) end\n\t\treturn c\n",
)
src = patch(
    src,
    "\t\tgradient().Parent = l\n\tend\n",
    "\t\tgradient().Parent = l\n"
    "\t\tlocal g = { items = {} }\n"
    "\t\tfunction g.show(on)\n"
    "\t\t\tg.open = on\n"
    '\t\t\tl.Text = (on and "–  " or "+  ") .. string.upper(text)\n'
    "\t\t\tfor _, c in ipairs(g.items) do c.Visible = on end\n"
    "\t\tend\n"
    '\t\tlocal hit = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = l })\n'
    "\t\thit.Activated:Connect(function() g.show(not g.open) end)\n"
    "\t\tg.show(true)\n"
    "\t\tgroup = g\n"
    "\t\ttable.insert(groups, g)\n"
    "\tend\n",
)
# همه‌ی بخش‌ها از اول بازن (کاربر نمی‌خواد بازشون کنه)؛ با کلیک روی عنوان هنوز جمع میشن

# دکمه‌ی «–» پنل رو کامل قایم می‌کنه؛ دایره‌ی BM (یا RightControl) دوباره میارتش
src = patch(
    src,
    "minBtn.Activated:Connect(function()\n"
    "\tminimized = not minimized\n"
    '\tminBtn.Text = minimized and "+" or "–"\n'
    "\ttween(main, 0.35, { Size = minimized and UDim2.fromOffset(FULL.X.Offset, 50) or FULL })\n"
    "end)\n",
    "minBtn.Activated:Connect(function() showMain(false) end)\n",
)
src = patch(src, 'createTab(SEA_NAME, "≋")', 'createTab("Quests", "≋")')
src = patch(src, 'createTab("Sea Events", "⚓")', 'createTab("Sea", "⚓")')
src = patch(src, 'createTab("Shop", "$")', 'createTab("Items", "◆")')
src = patch(src, 'createTab("ESP", "◉")', 'createTab("Settings", "✦")')
src = patch(src, 'createTab("Misc", "✦")', 'createTab("Settings", "✦")')
# تکراری‌ها: تب Stats همون بخش Auto Stats توی Farm بود؛ Auto Click و Bring Mobs توی Combat هم هستن
src = patch(
    src,
    '-- Stats\ndo\n\tlocal T = createTab("Stats", "▲")\n\tT:Section("Auto Stats")\n'
    '\tT:Dropdown("Stat", function() return { "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType")\n'
    '\tT:Dropdown("Split With", function() return { "None", "Melee", "Defense", "Sword", "Gun", "Demon Fruit" } end, "StatType2")\n'
    '\tT:Slider("Points Per Tick", 1, 100, "StatAmount")\n\tT:Toggle("Auto Stats", "AutoStats")\nend\n\n',
    "",
)
src = patch(
    src,
    '\tT:Toggle("Auto Click (attacks with the weapon in your hand)", "AutoClick")\n\tT:Toggle("Bring Mobs", "BringMobs")\n\tT:Toggle("Auto Retreat When Low HP", "AutoRetreat")\n',
    '\tT:Toggle("Auto Retreat When Low HP", "AutoRetreat")\n',
)
# اسکیل‌ها به تب Combat رفتن (50_brain)
src = patch(
    src,
    '\tT:Section("Skills")\n\tT:Toggle("Use Skills", "UseSkills")\n\tT:Toggle("Skill Z", "SkillZ")\n\tT:Toggle("Skill X", "SkillX")\n\tT:Toggle("Skill C", "SkillC")\n\tT:Toggle("Skill V", "SkillV")\n',
    "",
)

# --- v5.9: شمشیر وسط چند ماب دمیج نمی‌داد (نگهبان ضربه: 52_hitguard) ---
src = patch(src, "for i = 1, math.min(#found, 15) do",
	"for i = 1, math.min(#found, Hub.HitGuard and Hub.HitGuard.limit or 15) do")
src = patch(src, "\t\tHub.AttackInfo.remote += 1\n",
	"\t\tHub.AttackInfo.remote += 1\n\t\tif Hub.HitGuard then Hub.HitGuard.sent() end\n")
src = patch(src, '\tif m == "Auto" or m == "Tool" then\n',
	'\tif m == "Auto" or m == "Tool" or (Hub.HitGuard and Hub.HitGuard.swing) then\n')
# لاگ: tool:Activate برای شمشیر دمیج نداشت؛ پله‌های آخر نگهبان کلیک واقعی هم می‌زنن (حتی با Attack Method = Remote)
src = patch(src, '\tif m == "Auto" or m == "Click" then clickScreen() end\n',
	'\tif m == "Auto" or m == "Click" or (Hub.HitGuard and Hub.HitGuard.swing) then clickScreen() end\n')
src = patch(src, "\tif tick() - cooldown.remote < 0.1 then return end\n",
	"\tif tick() - cooldown.remote < (Hub.HitGuard and Hub.HitGuard.gap or 0.1) then return end\n")
src = patch(src, "\tif #hits == 0 then return end\n",
	"\tif #hits == 0 then return end\n\tif Hub.HitGuard and Hub.HitGuard.noRemote then Hub.HitGuard.sent() return end\n")
# Attack Test: ضربه‌ی ریموت با سرعت‌های مختلف هم امتحان میشه تا علت دقیق دمیج نخوردن شمشیر معلوم بشه
src = patch(src, '''					VIM:SendMouseButtonEvent(free.X, free.Y, 0, false, game, 0)
				end },
			}
''', '''					VIM:SendMouseButtonEvent(free.X, free.Y, 0, false, game, 0)
				end },
				{ "remote hit 1 mob every 0.25s", function()
					local head = best:FindFirstChild("Head") or best.HumanoidRootPart
					RegisterAttack:FireServer(0)
					RegisterHit:FireServer(head, { { best, head } })
				end },
				{ "remote hit 1 mob every 1s", function()
					local head = best:FindFirstChild("Head") or best.HumanoidRootPart
					RegisterAttack:FireServer(0)
					RegisterHit:FireServer(head, { { best, head } })
				end, 1 },
			}
''')
src = patch(src, '\t\t\t\t\tif not ok then err = tostring(e) end\n\t\t\t\t\ttask.wait(0.25)\n',
	'\t\t\t\t\tif not ok then err = tostring(e) end\n\t\t\t\t\ttask.wait(m[3] or 0.25)\n')
src = patch(src, '"Testing 3 methods (12 s)... don\'t touch the mouse"', '"Testing 5 methods (20 s)... don\'t touch the mouse"')
src = patch(src, '"ATTACK held=%s near=%d target=',
	'"ATTACK held=%s near=%d maxHits=%s target=')
src = patch(src, '"none", near, mobBaseName(best.Name),',
	'"none", near, (Hub.HitGuard and Hub.HitGuard.describe() or "?") .. (" bring=%d/skip=%d"):format(Hub.BringMoved or 0, Hub.BringSkipped or 0), mobBaseName(best.Name),')
# Bring Mobs فقط ماب‌هایی که کنترلشون دست ماست (52_hitguard: Hub.OwnsPart)
src = patch(src, '''			local hrp, hum = m.HumanoidRootPart, m.Humanoid
			hrp.CanCollide = false
			hrp.CFrame = cf
''', '''			local hrp, hum = m.HumanoidRootPart, m.Humanoid
			if Hub.OwnsPart and not Hub.OwnsPart(hrp) then
				Hub.BringSkipped = (Hub.BringSkipped or 0) + 1
				return
			end
			Hub.BringMoved = (Hub.BringMoved or 0) + 1
			hrp.CanCollide = false
			hrp.CFrame = cf
''')
# ارتفاع: پایین اومدن فقط با دمیج واقعی ذخیره میشه (50_brain)
src = patch(src, "\t\t\tlastHp, lastHit = hum.Health, tick()\n",
	"\t\t\tlastHp, lastHit = hum.Health, tick()\n\t\t\tif Hub.HeightWorked then Hub.HeightWorked() end\n")
src = patch(src, "\t\t\tmobSkipUntil[mob] = tick() + 45\n",
	"\t\t\tmobSkipUntil[mob] = tick() + 45\n\t\t\tif Hub.HeightGaveUp then Hub.HeightGaveUp() end\n")

# --- v5.9: Auto Cake همه‌ی ماب‌های جزیره‌ی کیک رو می‌زنه؛ کوئست اختیاری (CakeQuest) ---
# قبلاً کوئست یکی از ماب‌ها (مثلاً Cookie Crafter) رو خودش می‌گرفت و بعد فقط همون یه نوع رو می‌زد،
# Bring Mobs هم فقط هم‌اسم‌ها رو جمع می‌کرد
src = patch(src, "AutoCake = false,", "AutoCake = false, CakeQuest = false,")
src = patch(src, "local function farmList(list, keep, waitPos)", "local function farmList(list, keep, waitPos, anyMob)")
src = patch(src, "local questMob = activeQuestMob()", "local questMob = not anyMob and activeQuestMob() or nil")
src = patch(src, "if S.TakeQuest and q and not inList and not questBlocked(q) and not hasQuest(name) then",
	"if not anyMob and S.TakeQuest and q and not inList and not questBlocked(q) and not hasQuest(name) then")
src = patch(src, '\t\tS.Status = "Farming " .. name .. (inList and " (quest)" or "")\n\t\tkillMob(best, keep)\n',
	'''\t\tS.Status = "Farming " .. name .. (inList and " (quest)" or "")
\t\tif anyMob then
\t\t\t-- همه‌ی ماب‌های لیست با هم جمع میشن (مثل Bone)
\t\t\tHub.BringGroup = {}
\t\t\tfor _, n in ipairs(list) do Hub.BringGroup[n] = true end
\t\tend
\t\tlocal fought, fightErr = pcall(killMob, best, keep)
\t\tif anyMob then Hub.BringGroup = nil end
\t\tif not fought then error(fightErr, 0) end
''')
src = patch(src, "farmList(CAKE_MOBS, keep, CAKE_ISLAND)", "farmList(CAKE_MOBS, keep, CAKE_ISLAND, not S.CakeQuest)", 3)
src = patch(src, 'T:Toggle("Auto Cake Prince (cake mobs + boss)", "AutoCake", stopOff)',
	'T:Toggle("Auto Cake Prince (all cake mobs + boss)", "AutoCake", stopOff)\n'
	'\t\tT:Toggle("Cake: Take Quests (then only the quest mob)", "CakeQuest")')

# --- v5.9: بعد از هاپ هاب دو بار اجرا می‌شد ---
# چند جا هر کدوم جدا صف می‌کردن (Join Job خودش + «Restart Hub After Teleports» توی OnTeleport، Server Finder،
# سرویس Ken). حالا متن صف‌شده توی سرور جدید فقط بار اول اجرا میشه، هر چند بار هم صف شده باشه
src = patch(src, '''\t\tor 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()'
''', '''\t\tor 'loadstring(game:HttpGet("https://raw.githubusercontent.com/radingoodarzi/bm-hub/main/loader_v3.lua"))()'
\tLOADER = 'local g = (getgenv and getgenv()) or _G; if g.BMHubQueuedRun then return end; g.BMHubQueuedRun = true; ' .. LOADER
''')

# --- v5.9: اسکریپت کلاً فقط یه بار اجرا میشه؛ اجرای دوم خودش متوقف میشه ---
# قبلاً اجرای دوم اولی رو می‌بست و از اول شروع می‌کرد (هاب دو بار لود می‌شد). حالا اگه یه هاب روشنه
# (کامل لود شده، یا همین 90 ثانیه‌ی اخیر شروع به لود کرده) اجرای جدید پیام میده و برمی‌گرده.
# هابی که موقع لود خطا داده و 90 ثانیه گذشته، یا با Destroy Hub بسته شده، جلوی اجرای تازه رو نمی‌گیره
src = patch(src, "if genv.BMHub and genv.BMHub.Destroy then pcall(genv.BMHub.Destroy) end\n", '''local oldHub = genv.BMHub
if oldHub and oldHub.Running and (oldHub.Loaded or tick() - (tonumber(oldHub.StartedAt) or 0) < 90) then
	print("[BM Hub] already running - this second run was stopped")
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hub",
			Text = "Already running (v" .. tostring(oldHub.Version) .. "). To restart: Settings > Destroy Hub, then run it again.", Duration = 6 })
	end)
	return
end
if oldHub and oldHub.Destroy then pcall(oldHub.Destroy) end
''')
src = patch(src, f'local Hub = {{ Connections = {{}}, Running = true, Version = "{VERSION}" }}',
	f'local Hub = {{ Connections = {{}}, Running = true, Version = "{VERSION}", StartedAt = tick() }}')
src = patch(src, "\tpcall(function() espFolder:Destroy() end)\nend\n",
	"\tpcall(function() espFolder:Destroy() end)\nend\n\n-- تا اینجا رسید یعنی کامل لود شد (اجرای دوم از این به بعد همیشه متوقف میشه)\nHub.Loaded = true\n")

# --- v5.9: Auto Click روی باس‌ها کار نمی‌کرد ---
# 1) فاصله تا مرکز ماب حساب می‌شد؛ باس بزرگ مرکزش دوره و با Attack Range کم «بیرون از برد» بود → فاصله تا لبه
# 2) ماب/باسی که فارم «گیر کرده» حسابش کرده بود (8 ثانیه بی‌دمیج) 45 ثانیه از Auto Click و ضربه‌ها هم حذف می‌شد
# 3) M1 میوه همیشه سمت نزدیک‌ترین ماب می‌زد، نه هدفی که فارم داره می‌زنه
BOSS_HELPERS = '''-- برای ضربه زدن (نه انتخاب هدف فارم): ماب زنده، حتی اگه فارم «گیر کرده» ردش کرده باشه
local function hittableMob(m)
	local h = m:FindFirstChildOfClass("Humanoid")
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if h and h.Health > 0 and hrp then return hrp end
	return nil
end
-- فاصله تا لبه‌ی ماب (نصف اندازه‌ی مدل کم میشه، حداکثر 40) تا باس‌های بزرگ هم توی برد حساب بشن
local mobRadius = setmetatable({}, { __mode = "k" })
local function edgeDistance(m, hrp, pos)
	local r = mobRadius[m]
	if not r then
		local ok, size = pcall(function() return m:GetExtentsSize() end)
		r = ok and size and math.min(size.Magnitude / 2, 40) or 3
		mobRadius[m] = r
	end
	return math.max(0, (hrp.Position - pos).Magnitude - r)
end
Hub.EdgeDistance = edgeDistance

'''

OLD_NEAREST = '''local function nearestMobInRange()
	local root = getRoot()
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then return nil end
	local best, bestD
	for _, m in ipairs(enemies:GetChildren()) do
		if isAliveMob(m) then
			local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
			if d <= S.AttackRange and (not bestD or d < bestD) then best, bestD = m, d end
		end
	end
	return best
end'''

NEW_NEAREST = '''local function nearestMobInRange()
	local root = getRoot()
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then return nil end
	local best, bestD
	for _, m in ipairs(enemies:GetChildren()) do
		local hrp = hittableMob(m)
		if hrp then
			local d = edgeDistance(m, hrp, root.Position)
			if d <= S.AttackRange and (not bestD or d < bestD) then best, bestD = m, d end
		end
	end
	return best
end'''
src = patch(src, OLD_NEAREST, NEW_NEAREST)
# کمک‌ها باید قبل از remoteAttack تعریف بشن (اون توی فایل بالاتر از nearestMobInRange هست)
COOLDOWN_LINE = "local cooldown = { remote = 0, click = 0, skill = 0 }\n"
src = patch(src, COOLDOWN_LINE, BOSS_HELPERS + COOLDOWN_LINE)
src = patch(src, '''		for _, m in ipairs(enemies:GetChildren()) do
			if isAliveMob(m) then
				local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
				if d <= math.max(S.AttackRange, S.FarmHeight + 20) then''', '''		for _, m in ipairs(enemies:GetChildren()) do
			local hrp = hittableMob(m)
			if hrp then
				local d = edgeDistance(m, hrp, root.Position)
				if d <= math.max(S.AttackRange, S.FarmHeight + 20) then''')
src = patch(src, "local function attack()\n\tlocal root = getRoot()", "local function attack(target)\n\tlocal root = getRoot()")
src = patch(src, 'Hub.FruitM1 and Hub.FruitM1(root)\n', 'Hub.FruitM1 and Hub.FruitM1(root, target)\n')

# --- v5.9: آرنای Cake Prince / Dough King بالای آسمونه (حدود Y=4533)؛ هاب مستقیم می‌رفت تو آسمون.
# مثل Banana: وقتی مقصد توی آرناست و ما بیشتر از 1000 استاد دوریم، میریم سمت آینه‌ی بزرگ توی کیک
# (Map.CakeLoaf.BigMirror.Main) که خودش می‌برتمون داخل؛ دفعه‌ی بعد که نزدیکیم عادی میریم سراغ باس
CAKE_TWEEN_ANCHOR = "\tlocal dist = (root.Position - cf.Position).Magnitude\n\tif dist <= 10 then\n\t\troot.CFrame = cf\n"
src = patch(src, CAKE_TWEEN_ANCHOR, '''\tdo
\t\tlocal arena = Vector3.new(-1990.67, 4532.97, -14973.67)
\t\tif (cf.Position - arena).Magnitude <= 1000 and (root.Position - arena).Magnitude > 1000 then
\t\t\tlocal main
\t\t\tpcall(function() main = workspace.Map.CakeLoaf.BigMirror.Main end)
\t\t\tif main then
\t\t\t\tcf = main.CFrame
\t\t\t\tS.Status = "Cake Prince: going in through the big mirror"
\t\t\tend
\t\tend
\tend
''' + CAKE_TWEEN_ANCHOR)

# --- v5.9: موقع بالا اومدن هاب کلی اعلان پشت هم میومد ---
# همون اعلان تا 60 ثانیه فقط یه بار، حداکثر 3 تا روی صفحه (تازه‌ها جای قدیمی‌ها)، و اعلان‌های 10 ثانیه‌ی
# اول (به‌جز «BM Hub») یکجا توی یه اعلان خلاصه گفته میشن
src = patch(src, "local function notify(title, text, dur)\n\tif not Hub.Running then return end\n\tnotifCount += 1\n\tlocal slot = new(",
	'''local notifSeen, notifSlots, startBuffer, startFlushed = {}, {}, nil, false
local function notify(title, text, dur)
	if not Hub.Running then return end
	local key = tostring(title) .. "|" .. tostring(text)
	if notifSeen[key] and tick() - notifSeen[key] < 60 then return end
	notifSeen[key] = tick()
	local age = tick() - (tonumber(Hub.StartedAt) or 0)
	if title ~= "BM Hub" and not startFlushed and age < 10 then
		if not startBuffer then
			startBuffer = {}
			task.delay(math.max(1, 10 - age), function()
				local list = startBuffer
				startFlushed, startBuffer = true, nil
				if #list == 1 then return notify(list[1][1], list[1][2], list[1][3]) end
				local names = {}
				for i, n in ipairs(list) do if i <= 4 then names[#names + 1] = tostring(n[1]) end end
				notify("BM Hub", ("%d notices while loading: %s%s"):format(#list, table.concat(names, ", "), #list > 4 and ", ..." or ""), 8)
			end)
		end
		table.insert(startBuffer, { title, text, dur })
		return
	end
	while #notifSlots >= 3 do
		local old = table.remove(notifSlots, 1)
		pcall(function() old:Destroy() end)
	end
	notifCount += 1
	local slot = new(''')
src = patch(src, "\ttask.delay(dur or 3, function()\n\t\ttween(card, 0.35, { Position = UDim2.new(1.2, 0, 0, 0) })\n\t\ttask.wait(0.4)\n\t\tslot:Destroy()\n\tend)\nend\n\nnotifyHook = notify",
	'''\ttable.insert(notifSlots, slot)
\ttask.delay(dur or 3, function()
\t\ttween(card, 0.35, { Position = UDim2.new(1.2, 0, 0, 0) })
\t\ttask.wait(0.4)
\t\tslot:Destroy()
\t\tfor i, s in ipairs(notifSlots) do
\t\t\tif s == slot then table.remove(notifSlots, i) break end
\t\tend
\tend)
end

notifyHook = notify''')

logic, ui, top_ui, late_ui = [], [], [], []
for m in sorted((ROOT / "v3_src").glob("[0-9][0-9]_*.lua")):
    head, _, tail = m.read_text(encoding="utf-8").partition("--@@UI@@\n")
    tail, _, late = tail.partition("--@@UI-LATE@@\n")
    logic.append(f"-- ===== {m.name} =====\n{head.rstrip()}\n")
    if tail.strip():
        # فایلی که UI اش با «-- @top» شروع بشه، تبش درست بعد از Home میاد
        (top_ui if tail.startswith("-- @top") else ui).append(f"-- ===== {m.name} (UI) =====\ndo\n{tail.rstrip()}\nend\n")
    if late.strip():
        late_ui.append(f"-- ===== {m.name} (UI late) =====\ndo\n{late.rstrip()}\nend\n")

ui_banner = "---------------------------------------------------------------------\n-- UI\n"
src = patch(src, ui_banner, "\n".join(logic) + "\n" + ui_banner)

# تب‌های جدید قبل از تب Items
items_at = src.index("-- Items:")
src = src[:items_at] + "\n".join(ui) + "\n" + src[items_at:]

if top_ui:
    farm_at = src.index("-- Farm: فارم")
    src = src[:farm_at] + "\n".join(top_ui) + "\n" + src[farm_at:]

pages_end = "end -- صفحه‌ها\n"
src = patch(src, pages_end, "\n".join(late_ui) + pages_end)

OUT.write_text(src, encoding="utf-8", newline="\r\n")
print(f"wrote {OUT.name}: {len(src.splitlines())} lines, {len(logic)} modules")
