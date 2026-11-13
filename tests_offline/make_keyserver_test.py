# 5.10: سیستم کلید. ۱) تست‌های Node خود سرور (keyserver/test.mjs روی dist/worker.js)
# ۲) لودر کوتاهی که سرور میده، توی Luau با بازی شبیه‌سازی‌شده  ۳) بخش کلید خود هاب
import pathlib, subprocess, sys, tempfile
ROOT = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub")
out_lines = []
subprocess.run([sys.executable, str(ROOT / "keyserver" / "build.py")], check=True, capture_output=True)
boot_file = pathlib.Path(tempfile.mkdtemp()) / "boot.lua"
r = subprocess.run(["node", str(ROOT / "keyserver" / "test.mjs"), str(boot_file)], capture_output=True, text=True, encoding="utf-8")
for l in r.stdout.splitlines():
    if l.startswith("ok") or l.startswith("FAIL"):
        status, rest = l[:5], l[5:]
        out_lines.append("print(%s)" % ('"' + (status + "server: " + rest).replace(chr(92), "/").replace('"', "'") + '"'))
if r.returncode != 0 and not any("FAIL" in l for l in out_lines):
    out_lines.append('print("FAIL server tests crashed")')
boot = boot_file.read_text(encoding="utf-8") if boot_file.exists() else 'error("no bootstrap")'
hub = (ROOT / "bm_hub_v3.lua").read_text(encoding="utf-8")
a = hub.index("-- 5.10: سیستم کلید.")
b = hub.index("\nend)\n", a) + len("\nend)\n")
keyhub = hub[a:b]

L = r'''
local fails = 0
local function check(n, c) print((c and "ok   " or "FAIL ") .. n); if not c then fails += 1 end end
-- بازی شبیه‌سازی‌شده
local GENV, NOTES, URLS = {}, {}, {}
local RESPONSE = "RAN_HUB = true"
local HTTP_FAIL = false
getgenv = function() return GENV end
local players = { LocalPlayer = { UserId = 4242 } }
game = {
  IsLoaded = function() return true end,
  GetService = function(_, n)
    if n == "Players" then return players end
    return { SetCore = function(_, _, t) table.insert(NOTES, t.Text) end }
  end,
  HttpGet = function(_, url) table.insert(URLS, url); if HTTP_FAIL then error("Curl error") end; return RESPONSE end,
}
local BOOT = [==[
''' + boot + r''']==]
local function runBoot() return assert(loadstring(BOOT))() end

-- بدون کلید
runBoot()
check("loader: no key -> message, nothing downloaded", #URLS == 0 and NOTES[#NOTES]:find("No key") ~= nil)
-- با کلید
GENV.BM_KEY = "BM-ABCD-EFGH-JKLM-NPQR"
runBoot()
check("loader: sends key, Roblox UserId and an empty device id when the executor has none", URLS[1] == "https://keys.example.workers.dev/load?key=BM-ABCD-EFGH-JKLM-NPQR&uid=4242&dev=")
check("loader: runs what the server sent", RAN_HUB == true)
check("loader: remembers the server for teleports", GENV.BM_SERVER == "https://keys.example.workers.dev")
-- 5.11: کلید به دستگاه قفله
gethwid = function() return "HW-77{x}" end
URLS = {}
runBoot()
check("loader: sends the executor's device id, cleaned for the URL", URLS[1] == "https://keys.example.workers.dev/load?key=BM-ABCD-EFGH-JKLM-NPQR&uid=4242&dev=HW-77x" and GENV.BM_DEV == "HW-77x")
gethwid = nil
-- کلید با کاراکتر عجیب (جلوی دستکاری آدرس)
GENV.BM_KEY = "BM-AB&uid=1"
URLS = {}
runBoot()
check("loader: key with strange characters refused", #URLS == 0)
GENV.BM_KEY = "BM-ABCD-EFGH-JKLM-NPQR"
-- سرور در دسترس نیست
HTTP_FAIL = true
runBoot()
check("loader: server down -> clear message, no crash", NOTES[#NOTES]:find("Could not reach") ~= nil)
HTTP_FAIL = false
-- جواب رد سرور (اسکریپت پیام) هم اجرا میشه و فقط پیام میده
RESPONSE = 'game:GetService("StarterGui"):SetCore("SendNotification", { Text = "BM Hub: This key has expired" })'
runBoot()
check("loader: server refusal shows the reason", NOTES[#NOTES]:find("expired") ~= nil)

-- بخش کلید خود هاب
local spawned, waits = nil, {}
task = { spawn = function(f) spawned = f end, wait = function(s) table.insert(waits, s); if #waits > 6 then error("stop") end end }
local destroyed = false
local Hub = { Running = true, Destroy = function() destroyed = true end }
GENV.BM_KEY, GENV.BM_SERVER = nil, nil
''' + keyhub + r'''
check("hub: no key -> no key loader (your own bm.lua keeps working)", Hub.KeyLoader() == nil)
GENV.BM_KEY, GENV.BM_SERVER = "BM-ABCD-EFGH-JKLM-NPQR", "https://keys.example.workers.dev"
local ld = Hub.KeyLoader()
check("hub: teleport reload uses the key loader", ld == 'getgenv().BM_KEY = "BM-ABCD-EFGH-JKLM-NPQR"; loadstring(game:HttpGet("https://keys.example.workers.dev/l"))()')
check("hub: key loader is valid Lua", loadstring(ld) ~= nil)
GENV.BM_SERVER = 'https://x.dev")) evil(("'
check("hub: odd server address refused", Hub.KeyLoader() == nil)
GENV.BM_SERVER = "https://keys.example.workers.dev"
-- چک دوره‌ای
URLS = {}
RESPONSE = "ok"
local co = coroutine.create(spawned)
waits = {}
pcall(spawned)
check("hub: checks the key with the server", URLS[1] == "https://keys.example.workers.dev/check?key=BM-ABCD-EFGH-JKLM-NPQR&uid=4242")
check("hub: key ok -> keeps running", not destroyed)
check("hub: first check after 2 min, then every 10 min", waits[1] == 120 and waits[2] == 600)
GENV.BM_DEV = "HW-77x"
URLS, waits = {}, {}
pcall(spawned)
check("hub: periodic check also sends the device id", URLS[1] == "https://keys.example.workers.dev/check?key=BM-ABCD-EFGH-JKLM-NPQR&uid=4242&dev=HW-77x")
GENV.BM_DEV = nil
HTTP_FAIL = true
waits = {}
pcall(spawned)
check("hub: server unreachable -> keeps running (no kicking customers)", not destroyed)
HTTP_FAIL = false
RESPONSE = "no:This key was turned off by the admin"
waits = {}
pcall(spawned)
check("hub: key turned off -> hub stops itself", destroyed and NOTES[#NOTES]:find("turned off") ~= nil)
print(fails == 0 and "ALL PASSED" or fails .. " FAILED")
'''
pathlib.Path(sys.argv[1]).write_text("\n".join(out_lines) + "\n" + L, encoding="utf-8")
