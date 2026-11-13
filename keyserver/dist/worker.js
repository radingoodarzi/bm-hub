// BM Hub - سرور کلید (Cloudflare Worker)
//
// هر کلید مال یه دستگاهه: اولین بار که استفاده بشه به همون دستگاه (کامپیوتر/گوشی) قفل میشه؛ هر اکانت روبلاکسی
// روی همون دستگاه کار می‌کنه، دستگاه دیگه رد میشه. اکانت‌ها فقط برای دیدن توی پنل ثبت میشن.
// اسکریپت اصلی فقط با کلید درست داده میشه و از مخزن خصوصی گیت‌هاب خونده میشه
// (توکن گیت‌هاب فقط روی سرور می‌مونه، هیچ‌وقت به کاربر نمیرسه).
//
// تنظیمات Worker (توی داشبورد Cloudflare):
//   KV binding:  KEYS
//   Secrets:     ADMIN_PASSWORD (رمز صاحب هاب، نام کاربری: owner)، GITHUB_TOKEN
//   Variables:   REPO (مثلاً radingoodarzi/bm-hub)، FILE (bm_hub_v3.lua)، BRANCH (main)
//
// آدرس‌ها:
//   GET  /l               لودر کوتاه (کلید رو از getgenv().BM_KEY می‌خونه)
//   GET  /load?key&uid&dev    اسکریپت اصلی، فقط با کلید معتبر (dev = شناسه‌ی دستگاه؛ فقط هش‌ش ذخیره میشه)
//   GET  /check?key&uid&dev   "ok" یا "no:دلیل" (هاب هر چند دقیقه چک می‌کنه؛ هاب قدیمی بدون dev فقط خاموش/انقضا رو چک می‌کنه)
//   GET  /admin           پنل مدیریت
//   POST /api             کارهای پنل (ورود با نام کاربری و رمز، بعد با توکن جلسه)
//
// محدودیت پلن رایگان KV: روزی ۱۰۰۰ نوشتن. برای همین /check چیزی نمی‌نویسه و هر اجرای هاب فقط یه نوشتن داره.

const ADMIN_HTML = "<!doctype html>\n<html lang=\"fa\" dir=\"rtl\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n<meta name=\"robots\" content=\"noindex, nofollow\">\n<meta name=\"theme-color\" content=\"#0b0d17\">\n<title>BM Hub — پنل کلیدها</title>\n<link rel=\"icon\" href=\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Cdefs%3E%3ClinearGradient id='g' x1='0' y1='0' x2='1' y2='1'%3E%3Cstop offset='0' stop-color='%237c5cff'/%3E%3Cstop offset='1' stop-color='%233fa9ff'/%3E%3C/linearGradient%3E%3C/defs%3E%3Crect width='64' height='64' rx='16' fill='url(%23g)'/%3E%3Ctext x='32' y='42' font-family='Arial' font-weight='800' font-size='26' text-anchor='middle' fill='white'%3EBM%3C/text%3E%3C/svg%3E\">\n<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n<link href=\"https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;700;800&display=swap\" rel=\"stylesheet\">\n<style>\n:root {\n\t--bg: #0b0d17; --bg2: #10131f; --card: #151927; --card2: #1b2032; --line: #262c43; --line2: #323a57;\n\t--text: #e9ecf8; --dim: #98a0bf; --dim2: #6d7596;\n\t--accent: #7c5cff; --accent2: #3fa9ff; --grad: linear-gradient(135deg, #7c5cff, #3fa9ff);\n\t--ok: #33c983; --okbg: rgba(51,201,131,.12); --bad: #ff5c6c; --badbg: rgba(255,92,108,.12);\n\t--warn: #ffb547; --warnbg: rgba(255,181,71,.12); --info: #3fa9ff; --infobg: rgba(63,169,255,.12);\n\t--radius: 14px; --shadow: 0 10px 30px rgba(0,0,0,.35);\n\t--font: \"Vazirmatn\", Tahoma, \"Segoe UI\", sans-serif; --mono: \"JetBrains Mono\", Consolas, \"Courier New\", monospace;\n}\n* { box-sizing: border-box; }\nhtml, body { margin: 0; height: 100%; }\nbody { background: var(--bg); color: var(--text); font: 14.5px/1.65 var(--font); -webkit-font-smoothing: antialiased; }\nbody::before { content: \"\"; position: fixed; inset: -20% -10% auto auto; width: 60vw; height: 60vw; background: radial-gradient(closest-side, rgba(124,92,255,.16), transparent); pointer-events: none; z-index: 0; }\nbutton, input, select, textarea { font: inherit; color: inherit; }\nsvg { width: 18px; height: 18px; flex: none; }\n.card h3 svg { color: #a99bff; }\na { color: var(--accent2); text-decoration: none; }\n.mono { font-family: var(--mono); direction: ltr; unicode-bidi: isolate; letter-spacing: .3px; }\n.hidden { display: none !important; }\n.dim { color: var(--dim); } .dim2 { color: var(--dim2); } .small { font-size: 12.5px; }\n\n/* دکمه‌ها و فرم */\n.btn { display: inline-flex; align-items: center; justify-content: center; gap: 7px; border: 1px solid transparent; border-radius: 10px; padding: 9px 15px; cursor: pointer; background: var(--card2); border-color: var(--line2); transition: .15s; white-space: nowrap; }\n.btn:hover { border-color: var(--accent); }\n.btn.primary { background: var(--grad); border: 0; color: #fff; font-weight: 700; box-shadow: 0 6px 18px rgba(124,92,255,.35); }\n.btn.primary:hover { filter: brightness(1.08); }\n.btn.danger { background: var(--badbg); color: var(--bad); border-color: rgba(255,92,108,.35); }\n.btn.ghost { background: transparent; }\n.btn.sm { padding: 6px 11px; font-size: 13px; border-radius: 9px; }\n.btn:disabled { opacity: .5; cursor: default; }\n.btn svg { width: 16px; height: 16px; }\n.input, select.input, textarea.input { width: 100%; background: var(--bg2); border: 1px solid var(--line2); border-radius: 10px; padding: 10px 12px; outline: none; transition: .15s; }\n.input:focus { border-color: var(--accent); box-shadow: 0 0 0 3px rgba(124,92,255,.18); }\ntextarea.input { resize: vertical; min-height: 70px; }\nlabel.f { display: block; margin-bottom: 14px; }\nlabel.f > span { display: block; font-size: 13px; color: var(--dim); margin-bottom: 6px; }\n.row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }\n.grow { flex: 1 1 200px; min-width: 0; }\n.chips { display: flex; gap: 6px; flex-wrap: wrap; }\n.chip { padding: 6px 12px; border-radius: 999px; border: 1px solid var(--line2); background: var(--bg2); cursor: pointer; font-size: 13px; transition: .15s; }\n.chip.on { background: var(--grad); border-color: transparent; color: #fff; font-weight: 700; }\n.chip .n { opacity: .75; margin-inline-start: 4px; }\n\n/* چیدمان */\n.app { position: relative; z-index: 1; display: grid; grid-template-columns: 240px 1fr; min-height: 100vh; }\n.side { position: sticky; top: 0; height: 100vh; background: rgba(16,19,31,.85); backdrop-filter: blur(10px); border-inline-end: 1px solid var(--line); padding: 18px 14px; display: flex; flex-direction: column; gap: 6px; }\n.brand { display: flex; align-items: center; gap: 10px; padding: 4px 8px 18px; }\n.logo { width: 38px; height: 38px; border-radius: 11px; background: var(--grad); display: grid; place-items: center; font-weight: 800; color: #fff; box-shadow: 0 6px 18px rgba(124,92,255,.4); }\n.brand b { display: block; font-size: 16px; } .brand small { color: var(--dim); }\n.nav { display: flex; align-items: center; gap: 11px; padding: 10px 12px; border-radius: 11px; color: var(--dim); cursor: pointer; transition: .15s; border: 1px solid transparent; }\n.nav:hover { color: var(--text); background: var(--card); }\n.nav.on { color: #fff; background: linear-gradient(135deg, rgba(124,92,255,.22), rgba(63,169,255,.12)); border-color: rgba(124,92,255,.35); }\n.nav svg { width: 19px; height: 19px; flex: none; }\n.side .foot { margin-top: auto; padding: 10px; border-top: 1px solid var(--line); }\n.me { display: flex; align-items: center; gap: 9px; }\n.avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--card2); border: 1px solid var(--line2); display: grid; place-items: center; font-weight: 700; }\n.main { padding: 26px 30px 90px; max-width: 1180px; width: 100%; }\n.head { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 20px; }\n.head h1 { font-size: 22px; margin: 0; font-weight: 800; }\n.head p { margin: 2px 0 0; color: var(--dim); }\n.card { background: var(--card); border: 1px solid var(--line); border-radius: var(--radius); padding: 18px; }\n.card h3 { margin: 0 0 12px; font-size: 15px; display: flex; align-items: center; gap: 8px; }\n.grid { display: grid; gap: 14px; }\n.stats { grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); }\n.two { grid-template-columns: 1fr 1fr; }\n.stat { position: relative; overflow: hidden; }\n.stat .v { font-size: 28px; font-weight: 800; line-height: 1.2; }\n.stat .l { color: var(--dim); font-size: 13px; }\n.stat .ic { position: absolute; inset-inline-end: 14px; top: 14px; width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center; }\n.stat .ic svg { width: 19px; height: 19px; }\n.c-ok { color: var(--ok); background: var(--okbg); } .c-bad { color: var(--bad); background: var(--badbg); }\n.c-warn { color: var(--warn); background: var(--warnbg); } .c-info { color: var(--info); background: var(--infobg); }\n.c-acc { color: #b6a6ff; background: rgba(124,92,255,.14); }\n.mini { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 9px 0; border-bottom: 1px dashed var(--line); }\n.mini:last-child { border-bottom: 0; }\n.empty { color: var(--dim2); text-align: center; padding: 26px 10px; }\n\n/* لیست کلیدها */\n.toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; margin-bottom: 12px; }\n.search { position: relative; flex: 1 1 260px; }\n.search svg { position: absolute; inset-inline-start: 11px; top: 50%; transform: translateY(-50%); width: 17px; height: 17px; color: var(--dim2); }\n.search .input { padding-inline-start: 36px; }\n.bulk { position: sticky; top: 10px; z-index: 5; display: flex; gap: 8px; flex-wrap: wrap; align-items: center; background: rgba(27,32,50,.95); backdrop-filter: blur(8px); border: 1px solid rgba(124,92,255,.45); border-radius: 12px; padding: 10px 12px; margin-bottom: 12px; box-shadow: var(--shadow); }\n.list { display: grid; gap: 9px; }\n.item { display: grid; grid-template-columns: 26px 1fr auto; gap: 12px; align-items: center; background: var(--card); border: 1px solid var(--line); border-radius: 13px; padding: 12px 14px; cursor: pointer; transition: .15s; }\n.item:hover { border-color: var(--line2); background: var(--card2); }\n.item.sel { border-color: var(--accent); }\n.item .t { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }\n.item .t b { font-size: 15px; }\n.item .m { display: flex; gap: 14px; flex-wrap: wrap; color: var(--dim); font-size: 12.5px; margin-top: 3px; }\n.item .m span { display: inline-flex; align-items: center; gap: 5px; }\n.item .m svg { width: 13px; height: 13px; }\n.cb { width: 18px; height: 18px; accent-color: var(--accent); cursor: pointer; }\n.badge { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; padding: 2px 9px; border-radius: 999px; font-weight: 700; }\n.badge::before { content: \"\"; width: 6px; height: 6px; border-radius: 50%; background: currentColor; }\n.b-active { color: var(--ok); background: var(--okbg); } .b-unused { color: var(--info); background: var(--infobg); }\n.b-expired { color: var(--warn); background: var(--warnbg); } .b-revoked { color: var(--bad); background: var(--badbg); }\n.tag { font-size: 11.5px; padding: 1px 8px; border-radius: 6px; background: var(--bg2); border: 1px solid var(--line2); color: var(--dim); }\n\n/* مودال، توست */\n.overlay { position: fixed; inset: 0; background: rgba(5,6,12,.65); backdrop-filter: blur(4px); z-index: 50; display: grid; place-items: center; padding: 16px; animation: fade .15s; }\n.modal { width: min(560px, 100%); max-height: 90vh; overflow: auto; background: var(--card); border: 1px solid var(--line2); border-radius: 18px; box-shadow: var(--shadow); padding: 22px; animation: pop .18s; }\n.modal h2 { margin: 0 0 14px; font-size: 18px; }\n.modal .acts { display: flex; gap: 8px; justify-content: flex-start; flex-wrap: wrap; margin-top: 18px; }\n.kv { display: grid; grid-template-columns: 130px 1fr; gap: 8px 12px; margin: 10px 0 4px; font-size: 13.5px; }\n.kv > div:nth-child(odd) { color: var(--dim); }\n.keybox { display: flex; align-items: center; justify-content: space-between; gap: 10px; background: var(--bg2); border: 1px dashed var(--line2); border-radius: 11px; padding: 10px 12px; margin-bottom: 10px; }\n.keybox .mono { font-size: 15px; }\npre.code { background: var(--bg2); border: 1px solid var(--line); border-radius: 11px; padding: 12px; overflow: auto; font: 12.5px/1.6 var(--mono); direction: ltr; text-align: left; margin: 0; white-space: pre-wrap; word-break: break-all; }\n.toasts { position: fixed; bottom: 18px; inset-inline-start: 18px; display: grid; gap: 8px; z-index: 80; }\n.toast { background: var(--card2); border: 1px solid var(--line2); border-inline-start: 4px solid var(--ok); border-radius: 11px; padding: 10px 14px; box-shadow: var(--shadow); min-width: 220px; max-width: 360px; animation: pop .2s; }\n.toast.err { border-inline-start-color: var(--bad); }\n.uid { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 7px 10px; background: var(--bg2); border-radius: 9px; margin-bottom: 6px; }\n.step { display: inline-flex; align-items: center; border: 1px solid var(--line2); border-radius: 10px; overflow: hidden; }\n.step button { width: 36px; height: 38px; background: var(--card2); border: 0; cursor: pointer; font-size: 18px; }\n.step input { width: 56px; text-align: center; border: 0; background: var(--bg2); height: 38px; outline: none; }\n.audit { display: grid; grid-template-columns: 34px 1fr auto; gap: 12px; align-items: center; padding: 11px 0; border-bottom: 1px solid var(--line); }\n.audit:last-child { border-bottom: 0; }\n.aic { width: 34px; height: 34px; border-radius: 10px; display: grid; place-items: center; }\n.aic svg { width: 17px; height: 17px; }\n.spin { width: 18px; height: 18px; border: 2px solid rgba(255,255,255,.25); border-top-color: #fff; border-radius: 50%; animation: rot .7s linear infinite; }\n@keyframes rot { to { transform: rotate(360deg); } }\n@keyframes pop { from { transform: translateY(6px) scale(.98); opacity: 0; } }\n@keyframes fade { from { opacity: 0; } }\n\n/* ورود */\n.login { min-height: 100vh; display: grid; place-items: center; padding: 18px; position: relative; z-index: 1; }\n.login .card { width: min(400px, 100%); padding: 28px; box-shadow: var(--shadow); }\n.login .logo { width: 52px; height: 52px; font-size: 20px; margin: 0 auto 12px; }\n.login h1 { text-align: center; margin: 0 0 4px; font-size: 21px; }\n.login p { text-align: center; color: var(--dim); margin: 0 0 20px; }\n\n.mnav { display: none; }\n@media (max-width: 860px) {\n\t.app { grid-template-columns: 1fr; }\n\t.side { display: none; }\n\t.main { padding: 18px 14px 96px; }\n\t.two { grid-template-columns: 1fr; }\n\t.mnav { display: flex; position: fixed; bottom: 0; left: 0; right: 0; z-index: 40; background: rgba(16,19,31,.96); backdrop-filter: blur(10px); border-top: 1px solid var(--line); padding: 6px 6px calc(6px + env(safe-area-inset-bottom)); justify-content: space-around; }\n\t.mnav .nav { flex-direction: column; gap: 2px; padding: 6px 8px; font-size: 11px; }\n\t.item { grid-template-columns: 24px 1fr; }\n\t.item .r { grid-column: 2; }\n\t.kv { grid-template-columns: 110px 1fr; }\n\t.stat .v { font-size: 24px; }\n}\n</style>\n</head>\n<body>\n\n<div id=\"login\" class=\"login hidden\">\n\t<div class=\"card\">\n\t\t<div class=\"logo\">BM</div>\n\t\t<h1>پنل کلیدهای BM Hub</h1>\n\t\t<p>برای ادامه وارد شو</p>\n\t\t<form id=\"loginForm\">\n\t\t\t<label class=\"f\"><span>نام کاربری</span><input class=\"input mono\" id=\"lUser\" autocomplete=\"username\" placeholder=\"owner\" autocapitalize=\"off\" spellcheck=\"false\"></label>\n\t\t\t<label class=\"f\"><span>رمز</span><input class=\"input\" id=\"lPass\" type=\"password\" autocomplete=\"current-password\"></label>\n\t\t\t<button class=\"btn primary\" style=\"width:100%\" id=\"lBtn\">ورود</button>\n\t\t\t<div class=\"small dim2\" style=\"margin-top:12px;text-align:center\">صاحب هاب: نام کاربری <span class=\"mono\">owner</span> یا خالی</div>\n\t\t</form>\n\t</div>\n</div>\n\n<div id=\"app\" class=\"app hidden\">\n\t<aside class=\"side\">\n\t\t<div class=\"brand\"><div class=\"logo\">BM</div><div><b>BM Hub</b><small>مدیریت کلیدها</small></div></div>\n\t\t<div id=\"nav\"></div>\n\t\t<div class=\"foot\">\n\t\t\t<div class=\"me\"><div class=\"avatar\" id=\"meAv\">?</div><div class=\"grow\"><div id=\"meName\" style=\"font-weight:700\">—</div><div class=\"small dim\" id=\"meRole\">—</div></div>\n\t\t\t<button class=\"btn ghost sm\" data-act=\"logout\" title=\"خروج\">خروج</button></div>\n\t\t</div>\n\t</aside>\n\t<main class=\"main\" id=\"main\"></main>\n\t<nav class=\"mnav\" id=\"mnav\"></nav>\n</div>\n\n<div id=\"modalRoot\"></div>\n<div class=\"toasts\" id=\"toasts\"></div>\n\n<script>\n\"use strict\";\nvar ICONS = {\n\tdash: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"3\" y=\"3\" width=\"7\" height=\"9\" rx=\"2\"/><rect x=\"14\" y=\"3\" width=\"7\" height=\"5\" rx=\"2\"/><rect x=\"14\" y=\"12\" width=\"7\" height=\"9\" rx=\"2\"/><rect x=\"3\" y=\"16\" width=\"7\" height=\"5\" rx=\"2\"/></svg>',\n\tkey: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"7.5\" cy=\"15.5\" r=\"4.5\"/><path d=\"M10.7 12.3 20 3\"/><path d=\"m16 7 3 3\"/><path d=\"m18 5 2 2\"/></svg>',\n\tplus: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><path d=\"M12 5v14M5 12h14\"/></svg>',\n\tlog: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 8v4l3 2\"/><circle cx=\"12\" cy=\"12\" r=\"9\"/></svg>',\n\tteam: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"9\" cy=\"8\" r=\"3.5\"/><path d=\"M2.5 20a6.5 6.5 0 0 1 13 0\"/><path d=\"M16 4.5a3.5 3.5 0 0 1 0 7\"/><path d=\"M18 14.5a6.5 6.5 0 0 1 3.5 5.5\"/></svg>',\n\tgear: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"3\"/><path d=\"M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z\"/></svg>',\n\tcheck: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M20 6 9 17l-5-5\"/></svg>',\n\toff: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"m5.7 5.7 12.6 12.6\"/></svg>',\n\tclock: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 7v5l3 2\"/></svg>',\n\tplay: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linejoin=\"round\"><path d=\"M7 4v16l13-8z\"/></svg>',\n\tuser: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><circle cx=\"12\" cy=\"8\" r=\"4\"/><path d=\"M4 21a8 8 0 0 1 16 0\"/></svg>',\n\tglobe: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18\"/></svg>',\n\tshield: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linejoin=\"round\"><path d=\"M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z\"/></svg>',\n\tsearch: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><circle cx=\"11\" cy=\"11\" r=\"7\"/><path d=\"m20 20-4-4\"/></svg>',\n\tcopy: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"8\" y=\"8\" width=\"13\" height=\"13\" rx=\"2\"/><path d=\"M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3\"/></svg>',\n\ttrash: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><path d=\"M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3\"/></svg>',\n\trefresh: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><path d=\"M20 11a8 8 0 1 0-2.3 5.7\"/><path d=\"M20 4v7h-7\"/></svg>',\n\tdown: '<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\"><path d=\"M12 4v12m0 0-5-5m5 5 5-5M4 20h16\"/></svg>'\n};\n\nvar S = { session: null, user: null, role: null, page: \"dash\", keys: [], stats: null, script: null, skew: 0, audit: null, admins: null,\n\tq: \"\", filter: \"all\", sort: \"new\", sel: {}, created: null, loading: false };\ntry { S.session = sessionStorage.getItem(\"bm_s\"); S.page = sessionStorage.getItem(\"bm_p\") || \"dash\"; } catch (e) {}\n\n// ---------------------------------------------------------------- کمکی‌ها\nfunction $(id) { return document.getElementById(id); }\nfunction esc(s) { return String(s == null ? \"\" : s).replace(/[&<>\"']/g, function (c) { return { \"&\": \"&amp;\", \"<\": \"&lt;\", \">\": \"&gt;\", '\"': \"&quot;\", \"'\": \"&#39;\" }[c]; }); }\nfunction fa(n) { return Number(n || 0).toLocaleString(\"fa-IR\"); }\nfunction now() { return Date.now() + S.skew; }\nfunction ago(t) {\n\tif (!t) return \"هرگز\";\n\tvar s = Math.max(0, (now() - t) / 1000);\n\tif (s < 60) return \"همین الان\";\n\tif (s < 3600) return fa(Math.floor(s / 60)) + \" دقیقه پیش\";\n\tif (s < 86400) return fa(Math.floor(s / 3600)) + \" ساعت پیش\";\n\tif (s < 86400 * 30) return fa(Math.floor(s / 86400)) + \" روز پیش\";\n\treturn new Date(t).toLocaleDateString(\"fa-IR\");\n}\nfunction left(t) {\n\tif (!t) return \"دائمی\";\n\tvar s = (t - now()) / 1000;\n\tif (s <= 0) return \"تموم شده\";\n\tif (s < 3600) return fa(Math.ceil(s / 60)) + \" دقیقه مونده\";\n\tif (s < 86400) return fa(Math.ceil(s / 3600)) + \" ساعت مونده\";\n\treturn fa(Math.ceil(s / 86400)) + \" روز مونده\";\n}\nfunction dateFa(t) { return t ? new Date(t).toLocaleString(\"fa-IR\", { dateStyle: \"medium\", timeStyle: \"short\" }) : \"—\"; }\nfunction status(k) {\n\tif (k.revoked) return \"revoked\";\n\tif (k.expires && now() > k.expires) return \"expired\";\n\tif ((!k.devs || !k.devs.length) && (!k.uids || !k.uids.length)) return \"unused\";\n\treturn \"active\";\n}\nvar STATUS_FA = { active: \"فعال\", unused: \"استفاده نشده\", expired: \"تموم شده\", revoked: \"خاموش\" };\nfunction badge(k) { var s = status(k); return '<span class=\"badge b-' + s + '\">' + STATUS_FA[s] + \"</span>\"; }\nfunction soon(k) { return !k.revoked && k.expires && k.expires > now() && k.expires - now() < 3 * 86400000; }\nfunction loaderFor(key) { return 'getgenv().BM_KEY = \"' + key + '\"\\nloadstring(game:HttpGet(\"' + location.origin + '/l\"))()'; }\nvar FLAGS = {};\nfunction flag(cc) {\n\tif (!cc || cc.length !== 2) return \"\";\n\tif (FLAGS[cc]) return FLAGS[cc];\n\tvar f = String.fromCodePoint(127397 + cc.charCodeAt(0), 127397 + cc.charCodeAt(1));\n\treturn (FLAGS[cc] = f + \" \" + cc);\n}\n\nfunction toast(msg, err) {\n\tvar t = document.createElement(\"div\");\n\tt.className = \"toast\" + (err ? \" err\" : \"\");\n\tt.textContent = msg;\n\t$(\"toasts\").appendChild(t);\n\tsetTimeout(function () { t.style.transition = \".3s\"; t.style.opacity = \"0\"; setTimeout(function () { t.remove(); }, 300); }, err ? 4500 : 2600);\n}\nfunction copy(text, msg) {\n\tfunction ok() { toast(msg || \"کپی شد\"); }\n\tif (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(ok, fallback); else fallback();\n\tfunction fallback() {\n\t\tvar ta = document.createElement(\"textarea\"); ta.value = text; ta.style.position = \"fixed\"; ta.style.opacity = \"0\";\n\t\tdocument.body.appendChild(ta); ta.select();\n\t\ttry { document.execCommand(\"copy\"); ok(); } catch (e) { toast(\"کپی نشد، دستی کپی کن\", true); }\n\t\tta.remove();\n\t}\n}\n\nfunction api(action, data) {\n\tvar body = Object.assign({ action: action }, data || {});\n\treturn fetch(\"/api\", { method: \"POST\", headers: { \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + (S.session || \"\") }, body: JSON.stringify(body) })\n\t\t.then(function (r) {\n\t\t\treturn r.json().catch(function () { return {}; }).then(function (d) {\n\t\t\t\tif (r.status === 401 && d.relogin) { logout(true); throw new Error(d.error || \"دوباره وارد شو\"); }\n\t\t\t\tif (!r.ok) throw new Error(d.error || (\"خطا \" + r.status));\n\t\t\t\treturn d;\n\t\t\t});\n\t\t});\n}\n\n// ---------------------------------------------------------------- مودال\nfunction modal(html, onMount) {\n\tvar o = document.createElement(\"div\");\n\to.className = \"overlay\";\n\to.innerHTML = '<div class=\"modal\">' + html + \"</div>\";\n\to.addEventListener(\"mousedown\", function (e) { if (e.target === o) close(); });\n\tfunction close() { o.remove(); document.removeEventListener(\"keydown\", onKey); }\n\tfunction onKey(e) { if (e.key === \"Escape\") close(); }\n\tdocument.addEventListener(\"keydown\", onKey);\n\t$(\"modalRoot\").appendChild(o);\n\tif (onMount) onMount(o.firstChild, close);\n\tvar f = o.querySelector(\"[autofocus]\"); if (f) f.focus();\n\treturn close;\n}\nfunction confirmBox(title, text, okLabel, danger) {\n\treturn new Promise(function (res) {\n\t\tmodal('<h2>' + esc(title) + '</h2><div class=\"dim\">' + text + '</div><div class=\"acts\"><button class=\"btn ' + (danger ? \"danger\" : \"primary\") + '\" data-ok>' + esc(okLabel || \"باشه\") + '</button><button class=\"btn ghost\" data-no>انصراف</button></div>',\n\t\t\tfunction (m, close) {\n\t\t\t\tm.querySelector(\"[data-ok]\").onclick = function () { close(); res(true); };\n\t\t\t\tm.querySelector(\"[data-no]\").onclick = function () { close(); res(false); };\n\t\t\t});\n\t});\n}\nfunction daysBox(title, hint, allowAdd) {\n\treturn new Promise(function (res) {\n\t\tmodal('<h2>' + esc(title) + '</h2><div class=\"dim small\" style=\"margin-bottom:12px\">' + esc(hint) + '</div>' +\n\t\t\t'<div class=\"chips\" style=\"margin-bottom:12px\">' + [1, 7, 30, 90].map(function (d) { return '<span class=\"chip\" data-d=\"' + d + '\">' + fa(d) + ' روز</span>'; }).join(\"\") + '<span class=\"chip\" data-d=\"0\">دائمی</span></div>' +\n\t\t\t'<label class=\"f\"><span>تعداد روز (۰ = دائمی)</span><input class=\"input\" type=\"number\" min=\"0\" id=\"dIn\" value=\"30\" autofocus></label>' +\n\t\t\t(allowAdd ? '<label class=\"row small\" style=\"gap:8px;cursor:pointer\"><input type=\"checkbox\" class=\"cb\" id=\"dAdd\" checked> به روزهای باقی‌مونده اضافه بشه (نه از امروز)</label>' : \"\") +\n\t\t\t'<div class=\"acts\"><button class=\"btn primary\" data-ok>تمدید</button><button class=\"btn ghost\" data-no>انصراف</button></div>',\n\t\t\tfunction (m, close) {\n\t\t\t\tm.querySelectorAll(\"[data-d]\").forEach(function (c) { c.onclick = function () { m.querySelector(\"#dIn\").value = c.dataset.d; }; });\n\t\t\t\tm.querySelector(\"[data-ok]\").onclick = function () { var a = m.querySelector(\"#dAdd\"); close(); res({ days: Number(m.querySelector(\"#dIn\").value) || 0, mode: a && a.checked ? \"add\" : \"set\" }); };\n\t\t\t\tm.querySelector(\"[data-no]\").onclick = function () { close(); res(null); };\n\t\t\t});\n\t});\n}\n\n// ---------------------------------------------------------------- داده\nfunction load(silent) {\n\tif (S.loading) return Promise.resolve();\n\tS.loading = true;\n\treturn api(\"list\").then(function (d) {\n\t\tS.keys = d.keys; S.stats = d.stats; S.script = d.script; S.skew = d.now - Date.now();\n\t\tvar alive = {}; S.keys.forEach(function (k) { alive[k.key] = 1; });\n\t\tObject.keys(S.sel).forEach(function (k) { if (!alive[k]) delete S.sel[k]; });\n\t\trender();\n\t}).catch(function (e) { if (!silent) toast(e.message, true); }).then(function () { S.loading = false; });\n}\n\nfunction act(action, keys, extra, okMsg) {\n\treturn api(action, Object.assign({ keys: keys }, extra || {})).then(function (d) {\n\t\ttoast(okMsg || \"انجام شد\");\n\t\tS.audit = null;\n\t\treturn load(true).then(function () { return d; });\n\t}).catch(function (e) { toast(e.message, true); });\n}\n\n// ---------------------------------------------------------------- صفحه‌ها\nvar PAGES = [\n\t{ id: \"dash\", name: \"داشبورد\", icon: \"dash\" },\n\t{ id: \"keys\", name: \"کلیدها\", icon: \"key\" },\n\t{ id: \"new\", name: \"ساخت کلید\", icon: \"plus\" },\n\t{ id: \"log\", name: \"فعالیت‌ها\", icon: \"log\" },\n\t{ id: \"team\", name: \"ادمین‌ها\", icon: \"team\", owner: true },\n\t{ id: \"settings\", name: \"تنظیمات\", icon: \"gear\" }\n];\nfunction navHtml() {\n\treturn PAGES.filter(function (p) { return !p.owner || S.role === \"owner\"; }).map(function (p) {\n\t\treturn '<div class=\"nav' + (S.page === p.id ? \" on\" : \"\") + '\" data-page=\"' + p.id + '\">' + ICONS[p.icon] + \"<span>\" + p.name + \"</span></div>\";\n\t}).join(\"\");\n}\nfunction go(p) {\n\tS.page = p;\n\ttry { sessionStorage.setItem(\"bm_p\", p); } catch (e) {}\n\tif (p === \"log\" && !S.audit) loadAudit();\n\tif (p === \"team\" && !S.admins) loadAdmins();\n\trender();\n\twindow.scrollTo(0, 0);\n}\n\nfunction render() {\n\t$(\"nav\").innerHTML = navHtml();\n\t$(\"mnav\").innerHTML = navHtml();\n\t$(\"meName\").textContent = S.user || \"—\";\n\t$(\"meRole\").textContent = S.role === \"owner\" ? \"صاحب هاب\" : \"ادمین\";\n\t$(\"meAv\").textContent = (S.user || \"?\").charAt(0).toUpperCase();\n\tvar fn = { dash: pDash, keys: pKeys, \"new\": pNew, log: pLog, team: pTeam, settings: pSettings }[S.page] || pDash;\n\tif (S.page === \"team\" && S.role !== \"owner\") fn = pDash;\n\t$(\"main\").innerHTML = fn();\n\tif (S.page === \"keys\") { var s = $(\"q\"); if (s && document.activeElement !== s && S.focusQ) { s.focus(); s.setSelectionRange(s.value.length, s.value.length); } }\n}\n\nfunction head(title, sub, right) {\n\treturn '<div class=\"head\"><div><h1>' + title + \"</h1>\" + (sub ? \"<p>\" + sub + \"</p>\" : \"\") + \"</div>\" + (right || \"\") + \"</div>\";\n}\n\nfunction pDash() {\n\tvar st = S.stats || {};\n\tfunction card(v, l, ic, c) { return '<div class=\"card stat\"><div class=\"ic ' + c + '\">' + ICONS[ic] + '</div><div class=\"v\">' + fa(v) + '</div><div class=\"l\">' + l + \"</div></div>\"; }\n\tvar soonList = S.keys.filter(soon).sort(function (a, b) { return a.expires - b.expires; }).slice(0, 6);\n\tvar recent = S.keys.filter(function (k) { return k.lastUse; }).sort(function (a, b) { return b.lastUse - a.lastUse; }).slice(0, 7);\n\tvar denied = S.keys.filter(function (k) { return k.lastDenied; }).sort(function (a, b) { return b.lastDenied - a.lastDenied; }).slice(0, 5);\n\tfunction row(k, right) { return '<div class=\"mini\" data-open=\"' + esc(k.key) + '\" style=\"cursor:pointer\"><div><b>' + esc(k.name) + '</b> <span class=\"dim small mono\">' + esc(k.key.slice(0, 8)) + '…</span></div><div class=\"small dim\">' + right + \"</div></div>\"; }\n\treturn head(\"داشبورد\", \"سلام \" + esc(S.user) + \"! وضعیت کلیدها در یک نگاه\", '<button class=\"btn primary\" data-page=\"new\">' + ICONS.plus + \"کلید جدید</button>\") +\n\t\t'<div class=\"grid stats\" style=\"margin-bottom:14px\">' +\n\t\tcard(st.total, \"همه‌ی کلیدها\", \"key\", \"c-acc\") + card(st.active, \"فعال\", \"check\", \"c-ok\") + card(st.unused, \"هنوز استفاده نشده\", \"user\", \"c-info\") +\n\t\tcard(st.expired, \"تموم شده\", \"clock\", \"c-warn\") + card(st.revoked, \"خاموش\", \"off\", \"c-bad\") + card(st.usedToday, \"استفاده در ۲۴ ساعت\", \"play\", \"c-ok\") +\n\t\t\"</div>\" +\n\t\t'<div class=\"grid two\">' +\n\t\t'<div class=\"card\"><h3>' + ICONS.clock + \"نزدیک انقضا (۳ روز)</h3>\" + (soonList.length ? soonList.map(function (k) { return row(k, '<span style=\"color:var(--warn)\">' + left(k.expires) + \"</span>\"); }).join(\"\") : '<div class=\"empty\">هیچ کلیدی نزدیک انقضا نیست</div>') + \"</div>\" +\n\t\t'<div class=\"card\"><h3>' + ICONS.play + \"آخرین اجراها</h3>\" + (recent.length ? recent.map(function (k) { return row(k, (k.lastCountry ? flag(k.lastCountry) + \" · \" : \"\") + ago(k.lastUse)); }).join(\"\") : '<div class=\"empty\">هنوز کسی هاب رو با کلید اجرا نکرده</div>') + \"</div>\" +\n\t\t'<div class=\"card\"><h3>' + ICONS.shield + \"تلاش دستگاه‌های دیگه</h3>\" + (denied.length ? denied.map(function (k) { return row(k, '<span style=\"color:var(--bad)\">' + fa(k.denied) + \" بار</span> · \" + ago(k.lastDenied)); }).join(\"\") : '<div class=\"empty\">کسی سعی نکرده کلید کس دیگه‌ای رو استفاده کنه</div>') + \"</div>\" +\n\t\t'<div class=\"card\"><h3>' + ICONS.globe + \"هاب</h3>\" + scriptInfo() + '<div class=\"mini\"><span class=\"dim\">مجموع اجراها</span><b>' + fa(st.runs) + '</b></div><div class=\"mini\"><span class=\"dim\">نزدیک انقضا</span><b>' + fa(st.expiringSoon) + \"</b></div></div>\" +\n\t\t\"</div>\";\n}\nfunction scriptInfo() {\n\tvar s = S.script || {};\n\tvar st = s.ok === true ? '<span class=\"badge b-active\">سالم</span>' : s.ok === false ? '<span class=\"badge b-revoked\">' + esc(s.error || \"خطا\") + \"</span>\" : '<span class=\"badge b-unused\">هنوز گرفته نشده</span>';\n\treturn '<div class=\"mini\"><span class=\"dim\">نسخه‌ای که داده میشه</span><b class=\"mono\">' + esc(s.version || \"—\") + '</b></div><div class=\"mini\"><span class=\"dim\">گیت‌هاب</span>' + st + \"</div>\";\n}\n\nfunction filtered() {\n\tvar q = S.q.trim().toLowerCase();\n\tvar list = S.keys.filter(function (k) {\n\t\tif (S.filter === \"soon\") { if (!soon(k)) return false; }\n\t\telse if (S.filter !== \"all\" && status(k) !== S.filter) return false;\n\t\tif (!q) return true;\n\t\treturn [k.name, k.note, k.key, k.createdBy, (k.uids || []).join(\" \"), (k.devs || []).join(\" \")].some(function (v) { return String(v || \"\").toLowerCase().indexOf(q) >= 0; });\n\t});\n\tvar by = {\n\t\t\"new\": function (a, b) { return (b.created || 0) - (a.created || 0); },\n\t\told: function (a, b) { return (a.created || 0) - (b.created || 0); },\n\t\tuse: function (a, b) { return (b.lastUse || 0) - (a.lastUse || 0); },\n\t\truns: function (a, b) { return (b.uses || 0) - (a.uses || 0); },\n\t\texp: function (a, b) { return (a.expires || 9e15) - (b.expires || 9e15); },\n\t\tname: function (a, b) { return String(a.name).localeCompare(String(b.name), \"fa\"); }\n\t}[S.sort];\n\treturn list.sort(by);\n}\nfunction pKeys() {\n\tvar counts = { all: S.keys.length, active: 0, unused: 0, expired: 0, revoked: 0, soon: 0 };\n\tS.keys.forEach(function (k) { counts[status(k)]++; if (soon(k)) counts.soon++; });\n\tvar F = [[\"all\", \"همه\"], [\"active\", \"فعال\"], [\"unused\", \"استفاده نشده\"], [\"soon\", \"نزدیک انقضا\"], [\"expired\", \"تموم شده\"], [\"revoked\", \"خاموش\"]];\n\tvar list = filtered();\n\tvar selN = Object.keys(S.sel).length;\n\tvar allSel = list.length && list.every(function (k) { return S.sel[k.key]; });\n\treturn head(\"کلیدها\", fa(S.keys.length) + \" کلید\", '<div class=\"row\"><button class=\"btn\" data-act=\"reload\">' + ICONS.refresh + 'تازه کردن</button><button class=\"btn primary\" data-page=\"new\">' + ICONS.plus + \"کلید جدید</button></div>\") +\n\t\t'<div class=\"toolbar\"><div class=\"search\">' + ICONS.search + '<input class=\"input\" id=\"q\" placeholder=\"جستجو: اسم، یادداشت، کلید، آیدی اکانت، دستگاه، سازنده\" value=\"' + esc(S.q) + '\"></div>' +\n\t\t'<select class=\"input\" id=\"sort\" style=\"width:auto\">' + [[\"new\", \"جدیدترین\"], [\"old\", \"قدیمی‌ترین\"], [\"use\", \"آخرین استفاده\"], [\"runs\", \"بیشترین اجرا\"], [\"exp\", \"نزدیک‌ترین انقضا\"], [\"name\", \"اسم\"]].map(function (o) { return '<option value=\"' + o[0] + '\"' + (S.sort === o[0] ? \" selected\" : \"\") + \">\" + o[1] + \"</option>\"; }).join(\"\") + \"</select></div>\" +\n\t\t'<div class=\"chips\" style=\"margin-bottom:14px\">' + F.map(function (f) { return '<span class=\"chip' + (S.filter === f[0] ? \" on\" : \"\") + '\" data-filter=\"' + f[0] + '\">' + f[1] + '<span class=\"n\">' + fa(counts[f[0]]) + \"</span></span>\"; }).join(\"\") + \"</div>\" +\n\t\t(selN ? '<div class=\"bulk\"><b>' + fa(selN) + ' انتخاب شده</b><span class=\"grow\"></span>' +\n\t\t\t'<button class=\"btn sm\" data-bulk=\"copy\">' + ICONS.copy + 'کپی لودرها</button><button class=\"btn sm\" data-bulk=\"extend\">' + ICONS.clock + 'تمدید</button>' +\n\t\t\t'<button class=\"btn sm\" data-bulk=\"revoke\">' + ICONS.off + 'خاموش</button><button class=\"btn sm\" data-bulk=\"unrevoke\">' + ICONS.check + 'روشن</button>' +\n\t\t\t'<button class=\"btn sm\" data-bulk=\"reset\">' + ICONS.user + 'آزاد کردن دستگاه</button><button class=\"btn sm danger\" data-bulk=\"delete\">' + ICONS.trash + 'حذف</button>' +\n\t\t\t'<button class=\"btn sm ghost\" data-bulk=\"none\">لغو</button></div>' : \"\") +\n\t\t(list.length ? '<div class=\"row small dim\" style=\"margin:0 4px 8px\"><label class=\"row\" style=\"gap:8px;cursor:pointer\"><input type=\"checkbox\" class=\"cb\" data-selall' + (allSel ? \" checked\" : \"\") + '> انتخاب همه‌ی ' + fa(list.length) + \" مورد</label></div>\" : \"\") +\n\t\t'<div class=\"list\">' + (list.length ? list.map(itemHtml).join(\"\") : '<div class=\"card empty\">' + (S.keys.length ? \"چیزی پیدا نشد\" : 'هنوز کلیدی نساختی. <a href=\"#\" data-page=\"new\">اولین کلید رو بساز</a>') + \"</div>\") + \"</div>\";\n}\nfunction itemHtml(k) {\n\tvar u = (k.devs || []).length;\n\treturn '<div class=\"item' + (S.sel[k.key] ? \" sel\" : \"\") + '\" data-open=\"' + esc(k.key) + '\">' +\n\t\t'<input type=\"checkbox\" class=\"cb\" data-sel=\"' + esc(k.key) + '\"' + (S.sel[k.key] ? \" checked\" : \"\") + \">\" +\n\t\t'<div style=\"min-width:0\"><div class=\"t\"><b>' + esc(k.name) + \"</b>\" + badge(k) + (soon(k) ? '<span class=\"tag\" style=\"color:var(--warn)\">' + left(k.expires) + \"</span>\" : \"\") + (k.denied ? '<span class=\"tag\" style=\"color:var(--bad)\">' + fa(k.denied) + \" تلاش مشکوک</span>\" : \"\") + \"</div>\" +\n\t\t'<div class=\"m\"><span class=\"mono\">' + esc(k.key) + \"</span>\" +\n\t\t\"<span>\" + ICONS.user + fa(u) + \"/\" + fa(k.maxDevs) + \" دستگاه</span>\" +\n\t\t\"<span>\" + ICONS.clock + left(k.expires) + \"</span>\" +\n\t\t\"<span>\" + ICONS.play + fa(k.uses) + \" اجرا · \" + ago(k.lastUse) + \"</span>\" +\n\t\t(k.createdBy ? \"<span>سازنده: \" + esc(k.createdBy) + \"</span>\" : \"\") + \"</div>\" +\n\t\t(k.note ? '<div class=\"small dim2\" style=\"margin-top:3px\">' + esc(k.note) + \"</div>\" : \"\") + \"</div>\" +\n\t\t'<div class=\"r row\"><button class=\"btn sm\" data-copy=\"' + esc(k.key) + '\" title=\"کپی لودر\">' + ICONS.copy + \"لودر</button></div></div>\";\n}\n\nfunction openKey(key) {\n\tvar k = S.keys.filter(function (x) { return x.key === key; })[0];\n\tif (!k) return;\n\tvar mine = S.role === \"owner\" || k.createdBy === S.user;\n\tmodal('<div class=\"row\" style=\"justify-content:space-between;margin-bottom:6px\"><h2 style=\"margin:0\">' + esc(k.name) + \"</h2>\" + badge(k) + \"</div>\" +\n\t\t'<div class=\"keybox\"><span class=\"mono\">' + esc(k.key) + '</span><button class=\"btn sm\" data-c=\"key\">' + ICONS.copy + \"کلید</button></div>\" +\n\t\t'<pre class=\"code\">' + esc(loaderFor(k.key)) + '</pre><div class=\"row\" style=\"margin:8px 0 14px\"><button class=\"btn sm primary\" data-c=\"loader\">' + ICONS.copy + \"کپی لودر</button></div>\" +\n\t\t'<div class=\"kv\">' +\n\t\t\"<div>ساخته شده</div><div>\" + dateFa(k.created) + (k.createdBy ? \" · \" + esc(k.createdBy) : \"\") + \"</div>\" +\n\t\t\"<div>انقضا</div><div>\" + (k.expires ? dateFa(k.expires) + \" · <b>\" + left(k.expires) + \"</b>\" : \"دائمی\") + \"</div>\" +\n\t\t\"<div>اجراها</div><div>\" + fa(k.uses) + \" بار · آخرین: \" + ago(k.lastUse) + (k.lastCountry ? \" · \" + flag(k.lastCountry) : \"\") + \"</div>\" +\n\t\t\"<div>تلاش دستگاه دیگه</div><div>\" + (k.denied ? '<span style=\"color:var(--bad)\">' + fa(k.denied) + \" بار</span> · آخرین: \" + ago(k.lastDenied) + (k.lastDeniedDev ? ' · <span class=\"mono\">' + esc(k.lastDeniedDev) + \"</span>\" : \"\") + (k.lastDeniedUid ? ' · <a class=\"mono\" target=\"_blank\" rel=\"noopener\" href=\"https://www.roblox.com/users/' + esc(k.lastDeniedUid) + '/profile\">' + esc(k.lastDeniedUid) + \"</a>\" : \"\") : \"نه\") + \"</div>\" +\n\t\t\"</div>\" +\n\t\t'<h3 style=\"margin:16px 0 8px;font-size:14px\">دستگاه‌ها (' + fa((k.devs || []).length) + \" از \" + fa(k.maxDevs) + \")</h3>\" +\n\t\t((k.devs || []).length ? k.devs.map(function (d) { return '<div class=\"uid\"><span class=\"mono\">' + esc(d) + \"</span>\" + (d === k.lastDev ? '<span class=\"tag\">آخرین</span>' : \"\") + \"</div>\"; }).join(\"\") : '<div class=\"dim small\">هنوز به هیچ دستگاهی قفل نشده؛ اولین اجرا قفلش می‌کنه.</div>') +\n\t\t'<h3 style=\"margin:16px 0 8px;font-size:14px\">اکانت‌های روبلاکس که استفاده کردن (' + fa((k.uids || []).length) + \")</h3>\" +\n\t\t((k.uids || []).length ? k.uids.map(function (u) { return '<div class=\"uid\"><a class=\"mono\" target=\"_blank\" rel=\"noopener\" href=\"https://www.roblox.com/users/' + esc(u) + '/profile\">' + esc(u) + \"</a>\" + (u === k.lastUid ? '<span class=\"tag\">آخرین</span>' : \"\") + \"</div>\"; }).join(\"\") : '<div class=\"dim small\">هنوز هیچ اکانتی اجرا نکرده.</div>') +\n\t\t'<h3 style=\"margin:16px 0 8px;font-size:14px\">ویرایش</h3>' +\n\t\t'<label class=\"f\"><span>اسم</span><input class=\"input\" id=\"eName\" value=\"' + esc(k.name) + '\" maxlength=\"60\"></label>' +\n\t\t'<label class=\"f\"><span>یادداشت</span><textarea class=\"input\" id=\"eNote\" maxlength=\"200\" placeholder=\"مثلاً دیسکورد، قیمت، تاریخ پرداخت…\">' + esc(k.note) + \"</textarea></label>\" +\n\t\t'<label class=\"f\"><span>حداکثر تعداد دستگاه</span><div class=\"step\"><button type=\"button\" data-st=\"-1\">−</button><input id=\"eMax\" type=\"number\" min=\"1\" max=\"10\" value=\"' + k.maxDevs + '\"><button type=\"button\" data-st=\"1\">+</button></div></label>' +\n\t\t'<div class=\"acts\"><button class=\"btn primary\" data-a=\"save\">ذخیره</button><button class=\"btn\" data-a=\"extend\">' + ICONS.clock + \"تمدید</button>\" +\n\t\t(k.revoked ? '<button class=\"btn\" data-a=\"unrevoke\">' + ICONS.check + \"روشن کردن</button>\" : '<button class=\"btn\" data-a=\"revoke\">' + ICONS.off + \"خاموش کردن</button>\") +\n\t\t'<button class=\"btn\" data-a=\"reset\">' + ICONS.user + \"آزاد کردن دستگاه‌ها</button>\" +\n\t\t(mine ? '<button class=\"btn danger\" data-a=\"delete\">' + ICONS.trash + \"حذف</button>\" : \"\") + '<button class=\"btn ghost\" data-a=\"close\">بستن</button></div>',\n\t\tfunction (m, close) {\n\t\t\tm.querySelector('[data-c=\"key\"]').onclick = function () { copy(k.key, \"کلید کپی شد\"); };\n\t\t\tm.querySelector('[data-c=\"loader\"]').onclick = function () { copy(loaderFor(k.key), \"لودر کپی شد، برای همون نفر بفرست\"); };\n\t\t\tm.querySelectorAll(\"[data-st]\").forEach(function (b) { b.onclick = function () { var i = m.querySelector(\"#eMax\"); i.value = Math.min(10, Math.max(1, (Number(i.value) || 1) + Number(b.dataset.st))); }; });\n\t\t\tm.querySelectorAll(\"[data-a]\").forEach(function (b) {\n\t\t\t\tb.onclick = function () {\n\t\t\t\t\tvar a = b.dataset.a;\n\t\t\t\t\tif (a === \"close\") return close();\n\t\t\t\t\tif (a === \"save\") {\n\t\t\t\t\t\tb.disabled = true;\n\t\t\t\t\t\tapi(\"update\", { key: k.key, name: m.querySelector(\"#eName\").value, note: m.querySelector(\"#eNote\").value, maxDevs: Number(m.querySelector(\"#eMax\").value) || 1 })\n\t\t\t\t\t\t\t.then(function () { toast(\"ذخیره شد\"); close(); S.audit = null; return load(true); })\n\t\t\t\t\t\t\t.catch(function (e) { toast(e.message, true); b.disabled = false; });\n\t\t\t\t\t\treturn;\n\t\t\t\t\t}\n\t\t\t\t\tclose();\n\t\t\t\t\tsingle(a, k);\n\t\t\t\t};\n\t\t\t});\n\t\t});\n}\nfunction single(a, k) {\n\tif (a === \"extend\") return daysBox(\"تمدید «\" + k.name + \"»\", \"از امروز یا اضافه به روزهای باقی‌مونده\", !!k.expires).then(function (r) { if (r) act(\"extend\", [k.key], r, \"تمدید شد\"); });\n\tif (a === \"revoke\") return confirmBox(\"خاموش کردن کلید\", \"هاب روشنِ «\" + esc(k.name) + \"» حداکثر ۱۰ دقیقه بعد بسته میشه. هر وقت خواستی می‌تونی دوباره روشنش کنی.\", \"خاموش کن\", true).then(function (ok) { if (ok) act(\"revoke\", [k.key], null, \"خاموش شد\"); });\n\tif (a === \"unrevoke\") return act(\"unrevoke\", [k.key], null, \"روشن شد\");\n\tif (a === \"reset\") return confirmBox(\"آزاد کردن دستگاه‌ها\", \"قفل دستگاه‌های فعلی برداشته میشه و اجرای بعدی به دستگاه جدید قفل میشه.\", \"آزاد کن\").then(function (ok) { if (ok) act(\"reset\", [k.key], null, \"آزاد شد\"); });\n\tif (a === \"delete\") return confirmBox(\"حذف همیشگی\", \"کلید «\" + esc(k.name) + \"» برای همیشه پاک میشه و برنمی‌گرده. اگه فقط می‌خوای کار نکنه، «خاموش کردن» بهتره.\", \"حذف کن\", true).then(function (ok) { if (ok) act(\"delete\", [k.key], null, \"حذف شد\"); });\n}\nfunction bulk(a) {\n\tvar keys = Object.keys(S.sel);\n\tif (a === \"none\") { S.sel = {}; return render(); }\n\tif (!keys.length) return;\n\tvar n = fa(keys.length);\n\tif (a === \"copy\") {\n\t\tvar map = {}; S.keys.forEach(function (k) { map[k.key] = k; });\n\t\treturn copy(keys.map(function (k) { return \"-- \" + (map[k] ? map[k].name : \"\") + \"\\n\" + loaderFor(k); }).join(\"\\n\\n\"), n + \" لودر کپی شد\");\n\t}\n\tif (a === \"extend\") return daysBox(\"تمدید \" + n + \" کلید\", \"برای کلیدهای دائمی «اضافه کردن» معنی نداره و دائمی می‌مونن\", true).then(function (r) { if (r) act(\"extend\", keys, r, n + \" کلید تمدید شد\"); });\n\tvar texts = {\n\t\trevoke: [\"خاموش کردن \" + n + \" کلید\", \"هاب این افراد حداکثر ۱۰ دقیقه بعد بسته میشه.\", \"خاموش کن\", true],\n\t\tunrevoke: [\"روشن کردن \" + n + \" کلید\", \"این کلیدها دوباره کار می‌کنن.\", \"روشن کن\", false],\n\t\treset: [\"آزاد کردن دستگاه \" + n + \" کلید\", \"اجرای بعدی هر کلید به دستگاه جدید قفل میشه.\", \"آزاد کن\", false],\n\t\t\"delete\": [\"حذف همیشگی \" + n + \" کلید\", \"برنمی‌گردن. ادمین‌ها فقط کلیدهای خودشون رو می‌تونن پاک کنن.\", \"حذف کن\", true]\n\t}[a];\n\tconfirmBox(texts[0], texts[1], texts[2], texts[3]).then(function (ok) {\n\t\tif (ok) act(a, keys, null, \"انجام شد\").then(function () { if (a === \"delete\") { S.sel = {}; render(); } });\n\t});\n}\n\nfunction pNew() {\n\tvar c = S.created;\n\treturn head(\"ساخت کلید\", \"برای هر نفر یه کلید اختصاصی\") +\n\t\t'<div class=\"grid two\"><div class=\"card\"><form id=\"newForm\">' +\n\t\t'<label class=\"f\"><span>کلید برای کیه؟</span><input class=\"input\" id=\"nName\" maxlength=\"60\" placeholder=\"مثلاً اسم یا آیدی دیسکورد\" autofocus></label>' +\n\t\t'<label class=\"f\"><span>یادداشت (اختیاری)</span><textarea class=\"input\" id=\"nNote\" maxlength=\"200\" placeholder=\"مثلاً مبلغ، تاریخ پرداخت، راه ارتباطی…\"></textarea></label>' +\n\t\t'<label class=\"f\"><span>مدت</span><div class=\"chips\" id=\"nDays\">' + [[1, \"۱ روز\"], [7, \"۷ روز\"], [30, \"۳۰ روز\"], [90, \"۹۰ روز\"], [0, \"دائمی\"], [\"c\", \"دلخواه\"]].map(function (d) { return '<span class=\"chip' + (d[0] === 30 ? \" on\" : \"\") + '\" data-d=\"' + d[0] + '\">' + d[1] + \"</span>\"; }).join(\"\") + \"</div>\" +\n\t\t'<input class=\"input hidden\" id=\"nCustom\" type=\"number\" min=\"1\" placeholder=\"تعداد روز\" style=\"margin-top:8px\"></label>' +\n\t\t'<div class=\"row\" style=\"gap:24px;margin-bottom:14px\"><label class=\"f\" style=\"margin:0\"><span>چند دستگاه؟</span><div class=\"step\"><button type=\"button\" data-st=\"nMax:-1\">−</button><input id=\"nMax\" type=\"number\" min=\"1\" max=\"10\" value=\"1\"><button type=\"button\" data-st=\"nMax:1\">+</button></div></label>' +\n\t\t'<label class=\"f\" style=\"margin:0\"><span>چند تا کلید؟</span><div class=\"step\"><button type=\"button\" data-st=\"nCount:-1\">−</button><input id=\"nCount\" type=\"number\" min=\"1\" max=\"50\" value=\"1\"><button type=\"button\" data-st=\"nCount:1\">+</button></div></label></div>' +\n\t\t'<button class=\"btn primary\" style=\"width:100%\" id=\"nBtn\">' + ICONS.key + \"ساخت کلید</button></form>\" +\n\t\t'<div class=\"small dim2\" style=\"margin-top:12px\">کلید با اولین اجرا به دستگاه (کامپیوتر یا گوشی) همون نفر قفل میشه. هر اکانت روبلاکسی روی همون دستگاه کار می‌کنه؛ دستگاه دیگه رد میشه. اگه چند دستگاه مجاز باشه، تا همون تعداد قبول می‌کنه.</div></div>' +\n\t\t'<div class=\"card\"><h3>' + ICONS.check + \"کلیدهای ساخته شده</h3>\" +\n\t\t(c && c.length ? (c.length > 1 ? '<div class=\"row\" style=\"margin-bottom:10px\"><button class=\"btn sm primary\" data-act=\"copyAllNew\">' + ICONS.copy + \"کپی همه‌ی لودرها</button></div>\" : \"\") +\n\t\t\tc.map(function (k) { return '<div class=\"keybox\"><div style=\"min-width:0\"><div><b>' + esc(k.name) + '</b></div><div class=\"mono small\">' + esc(k.key) + '</div></div><button class=\"btn sm\" data-copy=\"' + esc(k.key) + '\">' + ICONS.copy + \"لودر</button></div>\"; }).join(\"\") +\n\t\t\t'<div class=\"small dim2\">لودر رو برای همون نفر بفرست. توی Solara اجراش می‌کنه.</div>'\n\t\t\t: '<div class=\"empty\">بعد از ساختن، کلیدها و لودرهاشون اینجا میان</div>') + \"</div></div>\";\n}\n\nfunction loadAudit() {\n\tapi(\"audit\").then(function (d) { S.audit = d.entries; if (S.page === \"log\") render(); }).catch(function (e) { toast(e.message, true); });\n}\nvar AUDIT_FA = {\n\tcreate: [\"ساخت کلید\", \"plus\", \"c-ok\"], update: [\"ویرایش\", \"gear\", \"c-info\"], revoke: [\"خاموش کرد\", \"off\", \"c-bad\"], unrevoke: [\"روشن کرد\", \"check\", \"c-ok\"],\n\treset: [\"آزاد کردن دستگاه\", \"user\", \"c-info\"], extend: [\"تمدید\", \"clock\", \"c-warn\"], \"delete\": [\"حذف\", \"trash\", \"c-bad\"], refresh: [\"نسخه‌ی جدید هاب\", \"refresh\", \"c-info\"],\n\t\"export\": [\"پشتیبان\", \"down\", \"c-info\"], addAdmin: [\"ادمین جدید\", \"team\", \"c-acc\"], adminPassword: [\"رمز ادمین عوض شد\", \"shield\", \"c-acc\"],\n\tremoveAdmin: [\"حذف ادمین\", \"trash\", \"c-bad\"], disableAdmin: [\"ادمین غیرفعال شد\", \"off\", \"c-bad\"], enableAdmin: [\"ادمین فعال شد\", \"check\", \"c-ok\"]\n};\nfunction pLog() {\n\tvar list = S.audit;\n\treturn head(\"فعالیت‌ها\", \"کارهای ادمین‌ها در ۹۰ روز اخیر\", '<button class=\"btn\" data-act=\"reloadAudit\">' + ICONS.refresh + \"تازه کردن</button>\") +\n\t\t'<div class=\"card\">' + (!list ? '<div class=\"empty\">در حال خوندن…</div>' : !list.length ? '<div class=\"empty\">هنوز فعالیتی ثبت نشده</div>' :\n\t\t\tlist.map(function (e) {\n\t\t\t\tvar a = AUDIT_FA[e.action] || [e.action, \"log\", \"c-info\"];\n\t\t\t\treturn '<div class=\"audit\"><div class=\"aic ' + a[2] + '\">' + ICONS[a[1]] + '</div><div style=\"min-width:0\"><b>' + esc(e.who) + \"</b> · \" + a[0] + '<div class=\"small dim\" style=\"overflow-wrap:anywhere\">' + esc(e.detail) + '</div></div><div class=\"small dim2\" title=\"' + esc(dateFa(e.at)) + '\">' + ago(e.at) + \"</div></div>\";\n\t\t\t}).join(\"\")) + \"</div>\";\n}\n\nfunction loadAdmins() {\n\tapi(\"admins\").then(function (d) { S.admins = d.admins; if (S.page === \"team\") render(); }).catch(function (e) { toast(e.message, true); });\n}\nfunction pTeam() {\n\tvar list = S.admins;\n\treturn head(\"ادمین‌ها\", \"هر ادمین با نام کاربری و رمز خودش وارد میشه. می‌تونه کلید بسازه و مدیریت کنه، ولی فقط کلیدهای خودش رو پاک می‌کنه و به این صفحه دسترسی نداره.\") +\n\t\t'<div class=\"grid two\"><div class=\"card\"><h3>' + ICONS.plus + \"ادمین جدید / عوض کردن رمز</h3><form id=\\\"adminForm\\\">\" +\n\t\t'<label class=\"f\"><span>نام کاربری (انگلیسی کوچیک)</span><input class=\"input mono\" id=\"aUser\" maxlength=\"24\" autocapitalize=\"off\" spellcheck=\"false\" placeholder=\"ali\"></label>' +\n\t\t'<label class=\"f\"><span>رمز (حداقل ۸ حرف)</span><div class=\"row\"><input class=\"input mono grow\" id=\"aPass\" type=\"text\" autocomplete=\"new-password\"><button type=\"button\" class=\"btn sm\" data-act=\"genPass\">رمز تصادفی</button></div></label>' +\n\t\t'<button class=\"btn primary\" style=\"width:100%\">ذخیره‌ی ادمین</button>' +\n\t\t'<div class=\"small dim2\" style=\"margin-top:10px\">اگه نام کاربری از قبل باشه، فقط رمزش عوض میشه. نام کاربری و رمز رو خودت به ادمین بده.</div></form></div>' +\n\t\t'<div class=\"card\"><h3>' + ICONS.team + \"ادمین‌ها</h3>\" + (!list ? '<div class=\"empty\">در حال خوندن…</div>' : !list.length ? '<div class=\"empty\">هنوز ادمینی نساختی</div>' :\n\t\t\tlist.map(function (a) {\n\t\t\t\treturn '<div class=\"mini\"><div><b class=\"mono\">' + esc(a.user) + \"</b> \" + (a.disabled ? '<span class=\"badge b-revoked\">غیرفعال</span>' : '<span class=\"badge b-active\">فعال</span>') + '<div class=\"small dim2\">از ' + ago(a.created) + '</div></div><div class=\"row\">' +\n\t\t\t\t\t'<button class=\"btn sm\" data-admin=\"' + esc(a.user) + '\" data-dis=\"' + (a.disabled ? \"0\" : \"1\") + '\">' + (a.disabled ? \"فعال کن\" : \"غیرفعال کن\") + \"</button>\" +\n\t\t\t\t\t'<button class=\"btn sm danger\" data-admin=\"' + esc(a.user) + '\" data-rm=\"1\">' + ICONS.trash + \"</button></div></div>\";\n\t\t\t}).join(\"\")) + \"</div></div>\";\n}\n\nfunction pSettings() {\n\treturn head(\"تنظیمات\") +\n\t\t'<div class=\"grid two\"><div class=\"card\"><h3>' + ICONS.globe + \"نسخه‌ی هاب</h3>\" + scriptInfo() +\n\t\t'<div class=\"small dim2\" style=\"margin:10px 0\">سرور هر ۱ دقیقه نسخه‌ی جدید رو از گیت‌هاب می‌گیره. بعد از push اگه فوری می‌خوای، این دکمه رو بزن.</div>' +\n\t\t'<div class=\"row\"><button class=\"btn\" data-act=\"refresh\">' + ICONS.refresh + 'گرفتن نسخه‌ی جدید هاب</button><button class=\"btn\" data-act=\"testGithub\">' + ICONS.shield + \"آزمایش اتصال گیت‌هاب</button></div>\" +\n\t\t'<div id=\"ghResult\" style=\"margin-top:12px\"></div></div>' +\n\t\t'<div class=\"card\"><h3>' + ICONS.key + \"شکل لودر</h3><pre class=\\\"code\\\">\" + esc(loaderFor(\"BM-XXXX-XXXX-XXXX-XXXX\")) + \"</pre></div>\" +\n\t\t(S.role === \"owner\" ? '<div class=\"card\"><h3>' + ICONS.down + 'پشتیبان</h3><div class=\"small dim\" style=\"margin-bottom:10px\">همه‌ی کلیدها به‌صورت فایل JSON. جای امن نگهش دار.</div><button class=\"btn\" data-act=\"export\">' + ICONS.down + \"دانلود پشتیبان</button></div>\" : \"\") +\n\t\t'<div class=\"card\"><h3>' + ICONS.user + 'حساب</h3><div class=\"mini\"><span class=\"dim\">وارد شده با</span><b class=\"mono\">' + esc(S.user) + '</b></div><div class=\"mini\"><span class=\"dim\">نقش</span><b>' + (S.role === \"owner\" ? \"صاحب هاب\" : \"ادمین\") + '</b></div><button class=\"btn danger\" style=\"margin-top:10px\" data-act=\"logout\">خروج</button></div></div>';\n}\n\n// ---------------------------------------------------------------- رویدادها\ndocument.addEventListener(\"click\", function (e) {\n\tvar t = e.target.closest(\"[data-page],[data-act],[data-copy],[data-sel],[data-selall],[data-open],[data-filter],[data-bulk],[data-st],[data-d],[data-admin]\");\n\tif (!t || t.closest(\".overlay\")) return;\n\tif (t.matches(\"[data-sel]\")) { e.stopPropagation(); if (t.checked) S.sel[t.dataset.sel] = 1; else delete S.sel[t.dataset.sel]; render(); return; }\n\tif (t.matches(\"[data-selall]\")) { var on = t.checked; filtered().forEach(function (k) { if (on) S.sel[k.key] = 1; else delete S.sel[k.key]; }); render(); return; }\n\tif (t.matches(\"[data-copy]\")) { e.stopPropagation(); copy(loaderFor(t.dataset.copy), \"لودر کپی شد، برای همون نفر بفرست\"); return; }\n\tif (t.matches(\"[data-page]\")) { e.preventDefault(); go(t.dataset.page); return; }\n\tif (t.matches(\"[data-filter]\")) { S.filter = t.dataset.filter; render(); return; }\n\tif (t.matches(\"[data-bulk]\")) { bulk(t.dataset.bulk); return; }\n\tif (t.matches(\"[data-st]\")) {\n\t\tvar p = t.dataset.st.split(\":\"), inp = $(p[0]);\n\t\tinp.value = Math.min(Number(inp.max), Math.max(1, (Number(inp.value) || 1) + Number(p[1]))); return;\n\t}\n\tif (t.matches(\"[data-d]\")) {\n\t\tdocument.querySelectorAll(\"#nDays .chip\").forEach(function (c) { c.classList.toggle(\"on\", c === t); });\n\t\t$(\"nCustom\").classList.toggle(\"hidden\", t.dataset.d !== \"c\"); if (t.dataset.d === \"c\") $(\"nCustom\").focus(); return;\n\t}\n\tif (t.matches(\"[data-admin]\")) {\n\t\tvar u = t.dataset.admin;\n\t\tif (t.dataset.rm) {\n\t\t\tconfirmBox(\"حذف ادمین\", \"«\" + esc(u) + \"» دیگه نمی‌تونه وارد بشه. کلیدهایی که ساخته سر جاشون می‌مونن.\", \"حذف کن\", true).then(function (ok) {\n\t\t\t\tif (ok) api(\"setAdmin\", { user: u, remove: true }).then(function () { toast(\"حذف شد\"); S.admins = null; S.audit = null; loadAdmins(); }).catch(function (er) { toast(er.message, true); });\n\t\t\t});\n\t\t} else api(\"setAdmin\", { user: u, disabled: t.dataset.dis === \"1\" }).then(function () { toast(\"انجام شد\"); S.admins = null; S.audit = null; loadAdmins(); }).catch(function (er) { toast(er.message, true); });\n\t\treturn;\n\t}\n\tif (t.matches(\"[data-open]\")) { openKey(t.dataset.open); return; }\n\tvar a = t.dataset.act;\n\tif (a === \"logout\") logout();\n\telse if (a === \"reload\") load().then(function () { toast(\"به‌روز شد\"); });\n\telse if (a === \"reloadAudit\") { S.audit = null; render(); loadAudit(); }\n\telse if (a === \"testGithub\") {\n\t\tvar box = $(\"ghResult\"); box.innerHTML = '<div class=\"dim small\">در حال آزمایش…</div>';\n\t\tapi(\"testGithub\").then(function (d) {\n\t\t\tvar why = \"\";\n\t\t\tif (!d.ok) {\n\t\t\t\tvar e = String(d.error || \"\");\n\t\t\t\tif (!d.hasToken) why = \"GITHUB_TOKEN توی تنظیمات Worker نیست.\";\n\t\t\t\telse if (e.indexOf(\"401\") >= 0) why = \"توکن گیت‌هاب اشتباهه یا باطل شده (مثلاً بعد از Regenerate). توکن جدید رو توی GITHUB_TOKEN بذار.\";\n\t\t\t\telse if (e.indexOf(\"403\") >= 0) why = \"توکن اجازه‌ی خوندن نداره: Contents باید Read-only باشه و مخزن bm-hub انتخاب شده باشه.\";\n\t\t\t\telse if (e.indexOf(\"404\") >= 0) why = \"فایل یا مخزن پیدا نشد: REPO / FILE / BRANCH رو چک کن، یا توکن به این مخزن دسترسی نداره.\";\n\t\t\t\telse why = e || \"خطای ناشناخته\";\n\t\t\t}\n\t\t\tbox.innerHTML = d.ok\n\t\t\t\t? '<div class=\"badge b-active\">وصله</div> <span class=\"small\">نسخه‌ی <b class=\"mono\">' + esc(d.version) + \"</b> از \" + esc(d.repo) + \"</span>\"\n\t\t\t\t: '<div class=\"badge b-revoked\">' + esc(d.error || \"خطا\") + '</div><div class=\"small\" style=\"margin-top:6px\">' + esc(why) + \"</div>\";\n\t\t\tS.script = { version: d.version, ok: d.ok, error: d.error };\n\t\t}).catch(function (er) { box.innerHTML = \"\"; toast(er.message, true); });\n\t}\n\telse if (a === \"refresh\") api(\"refresh\").then(function () { toast(\"از این به بعد آخرین نسخه داده میشه\"); S.audit = null; }).catch(function (er) { toast(er.message, true); });\n\telse if (a === \"export\") api(\"export\").then(function (d) {\n\t\tvar blob = new Blob([JSON.stringify(d, null, 2)], { type: \"application/json\" });\n\t\tvar link = document.createElement(\"a\"); link.href = URL.createObjectURL(blob);\n\t\tlink.download = \"bmhub-keys-\" + new Date().toISOString().slice(0, 10) + \".json\"; link.click();\n\t\tsetTimeout(function () { URL.revokeObjectURL(link.href); }, 2000); toast(\"پشتیبان دانلود شد\");\n\t}).catch(function (er) { toast(er.message, true); });\n\telse if (a === \"genPass\") {\n\t\tvar ch = \"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789\", b = new Uint8Array(14), s = \"\";\n\t\tcrypto.getRandomValues(b); for (var i = 0; i < b.length; i++) s += ch[b[i] % ch.length];\n\t\t$(\"aPass\").value = s; copy(s, \"رمز تصادفی ساخته و کپی شد\");\n\t}\n\telse if (a === \"copyAllNew\" && S.created) copy(S.created.map(function (k) { return \"-- \" + k.name + \"\\n\" + loaderFor(k.key); }).join(\"\\n\\n\"), \"همه‌ی لودرها کپی شد\");\n});\ndocument.addEventListener(\"input\", function (e) {\n\tif (e.target.id === \"q\") { S.q = e.target.value; S.focusQ = true; render(); S.focusQ = false; }\n});\ndocument.addEventListener(\"change\", function (e) { if (e.target.id === \"sort\") { S.sort = e.target.value; render(); } });\ndocument.addEventListener(\"submit\", function (e) {\n\te.preventDefault();\n\tvar f = e.target;\n\tif (f.id === \"loginForm\") return doLogin();\n\tif (f.id === \"newForm\") {\n\t\tvar name = $(\"nName\").value.trim();\n\t\tif (!name) { toast(\"بنویس کلید برای کیه\", true); $(\"nName\").focus(); return; }\n\t\tvar chip = document.querySelector(\"#nDays .chip.on\"), d = chip ? chip.dataset.d : \"30\";\n\t\tvar days = d === \"c\" ? Number($(\"nCustom\").value) || 0 : Number(d);\n\t\tif (d === \"c\" && !(days > 0)) { toast(\"تعداد روز رو بنویس\", true); return; }\n\t\tvar btn = $(\"nBtn\"); btn.disabled = true; btn.innerHTML = '<span class=\"spin\"></span>در حال ساخت…';\n\t\tapi(\"create\", { name: name, note: $(\"nNote\").value, days: days, maxDevs: Number($(\"nMax\").value) || 1, count: Number($(\"nCount\").value) || 1 }).then(function (r) {\n\t\t\tS.created = r.keys; S.audit = null;\n\t\t\tif (r.keys.length === 1) copy(loaderFor(r.keys[0].key), \"کلید ساخته شد و لودرش کپی شد\");\n\t\t\telse toast(fa(r.keys.length) + \" کلید ساخته شد\");\n\t\t\treturn load(true);\n\t\t}).catch(function (er) { toast(er.message, true); render(); });\n\t\treturn;\n\t}\n\tif (f.id === \"adminForm\") {\n\t\tapi(\"addAdmin\", { user: $(\"aUser\").value, password: $(\"aPass\").value }).then(function () { toast(\"ادمین ذخیره شد\"); S.admins = null; S.audit = null; loadAdmins(); }).catch(function (er) { toast(er.message, true); });\n\t}\n});\n\n// ---------------------------------------------------------------- ورود / خروج\nfunction showApp() { $(\"login\").classList.add(\"hidden\"); $(\"app\").classList.remove(\"hidden\"); }\nfunction showLogin() { $(\"app\").classList.add(\"hidden\"); $(\"login\").classList.remove(\"hidden\"); setTimeout(function () { ($(\"lUser\").value ? $(\"lPass\") : $(\"lUser\")).focus(); }, 30); }\nfunction doLogin() {\n\tvar btn = $(\"lBtn\"); btn.disabled = true; btn.innerHTML = '<span class=\"spin\"></span>';\n\tapi(\"login\", { user: $(\"lUser\").value, password: $(\"lPass\").value }).then(function (d) {\n\t\tS.session = d.session; S.user = d.user; S.role = d.role;\n\t\ttry { sessionStorage.setItem(\"bm_s\", d.session); localStorage.setItem(\"bm_u\", d.user); } catch (e) {}\n\t\t$(\"lPass\").value = \"\";\n\t\tshowApp(); render(); return load();\n\t}).catch(function (e) { toast(e.message, true); }).then(function () { btn.disabled = false; btn.textContent = \"ورود\"; });\n}\nfunction logout(expired) {\n\tif (S.session && !expired) api(\"logout\").catch(function () {});\n\tS.session = null; S.keys = []; S.audit = null; S.admins = null; S.sel = {};\n\ttry { sessionStorage.removeItem(\"bm_s\"); } catch (e) {}\n\tif (expired) toast(\"جلسه تموم شده، دوباره وارد شو\", true);\n\tshowLogin();\n}\ntry { $(\"lUser\").value = localStorage.getItem(\"bm_u\") || \"\"; } catch (e) {}\nif (S.session) {\n\tapi(\"me\").then(function (d) { S.user = d.user; S.role = d.role; showApp(); render(); load(); }).catch(function () { showLogin(); });\n} else showLogin();\n// تازه کردن خودکار؛ وقتی داری چیزی تایپ می‌کنی یا صفحه‌ی ساخت/ادمین بازه نه (فرم پاک میشه)\nsetInterval(function () {\n\tvar ae = document.activeElement, typing = ae && /^(INPUT|TEXTAREA|SELECT)$/.test(ae.tagName);\n\tif (S.session && !document.hidden && !typing && !document.querySelector(\".overlay\") && S.page !== \"new\" && S.page !== \"team\") load(true);\n}, 60000);\n</script>\n</body>\n</html>\n";

const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // بدون 0/O و 1/I که با هم قاطی نشن
const KEY_RE = /^BM-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
const UID_RE = /^[0-9]{1,20}$/;
const DEV_RE = /^[A-Za-z0-9{}_.:-]{4,128}$/; // gethwid() یا RbxAnalyticsService:GetClientId()
const USER_RE = /^[a-z0-9_.-]{3,24}$/;
const SCRIPT_TTL_MS = 60 * 1000;
const MAX_FAILS = 10; // رمز اشتباه پشت هم از یه IP
const FAIL_WINDOW_S = 600;
const SESSION_TTL_S = 12 * 3600;
const AUDIT_TTL_S = 90 * 86400;
const DENY_WRITE_GAP_MS = 60 * 1000; // ثبت تلاش اکانت دیگه حداکثر دقیقه‌ای یه بار (نوشتن KV محدوده)
const MAX_DEVS = 10;
const MAX_SEEN_UIDS = 20; // اکانت‌هایی که روی کلید دیده شدن (فقط برای پنل)
const MAX_BULK = 50;
const PBKDF2_ITER = 20000;
const OWNER = "owner";

let scriptCache = null; // { text, at, version }
let scriptStatus = { ok: null, at: null, error: null };

// ---------------------------------------------------------------- کمکی‌ها

export function newKey(rand = crypto.getRandomValues.bind(crypto)) {
	const bytes = new Uint8Array(16);
	rand(bytes);
	let s = "";
	for (let i = 0; i < 16; i++) {
		if (i > 0 && i % 4 === 0) s += "-";
		s += KEY_ALPHABET[bytes[i] % KEY_ALPHABET.length];
	}
	return "BM-" + s;
}

function hex(bytes) {
	return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
// شناسه‌ی خام دستگاه ذخیره نمیشه؛ فقط یه برچسب کوتاه از هش‌ش
export async function deviceTag(dev) {
	const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("bmhub-dev:" + dev));
	return "D-" + hex(d).slice(0, 12).toUpperCase();
}
function randomHex(n) {
	const b = new Uint8Array(n);
	crypto.getRandomValues(b);
	return hex(b);
}

export async function hashPassword(password, saltHex) {
	const enc = new TextEncoder();
	const base = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
	const salt = new Uint8Array(saltHex.match(/../g).map((h) => parseInt(h, 16)));
	const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: PBKDF2_ITER }, base, 256);
	return hex(bits);
}

function sameString(a, b) {
	if (typeof a !== "string" || typeof b !== "string" || !b) return false;
	let diff = a.length ^ b.length;
	for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
	return diff === 0;
}

// رکوردهای قدیمی: uid تکی → لیست uid؛ «حداکثر اکانت» قدیمی → «حداکثر دستگاه». کلید قدیمی که هنوز دستگاه نداره
// با اولین اجرای بعد از آپدیت به همون دستگاه قفل میشه
export function normalize(rec) {
	if (!rec) return rec;
	if (!Array.isArray(rec.uids)) rec.uids = rec.uid ? [String(rec.uid)] : [];
	delete rec.uid;
	if (!Array.isArray(rec.devs)) rec.devs = [];
	rec.maxDevs = Math.min(MAX_DEVS, Math.max(1, Number(rec.maxDevs) || Number(rec.maxUids) || 1));
	delete rec.maxUids;
	rec.note = rec.note || "";
	rec.uses = rec.uses || 0;
	rec.denied = rec.denied || 0;
	return rec;
}

// دلیل رد شدن کلید، یا null یعنی معتبره
// dev = برچسب دستگاه (deviceTag)، یا null یعنی دستگاه چک نشه (هاب قدیمی که توی /check دستگاه نمی‌فرسته)
export function keyProblem(rec, dev, now) {
	if (!rec) return "This key does not exist";
	if (rec.revoked) return "This key was turned off by the admin";
	if (rec.expires && now > rec.expires) return "This key has expired";
	const devs = rec.devs || [];
	if (dev && !devs.includes(dev) && devs.length >= (rec.maxDevs || 1)) return "This key is locked to another device";
	return null;
}

export function keyStatus(rec, now) {
	if (rec.revoked) return "revoked";
	if (rec.expires && now > rec.expires) return "expired";
	if ((!rec.devs || rec.devs.length === 0) && (!rec.uids || rec.uids.length === 0)) return "unused";
	return "active";
}

function luaString(s) {
	return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r?\n/g, " ") + '"';
}

// اسکریپتی که به‌جای هاب برمی‌گرده وقتی کلید رد شد: فقط پیام میده
export function denyLua(msg) {
	const m = luaString("BM Hub: " + msg);
	return `print(${m})\npcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hub", Text = ${m}, Duration = 12 }) end)\n`;
}

// لودر کوتاه: کلید از getgenv().BM_KEY، UserId از خود بازی، شناسه‌ی دستگاه از executor
export function bootstrapLua(origin) {
	return `local g = (getgenv and getgenv()) or _G
local SERVER = ${luaString(origin)}
g.BM_SERVER = SERVER
local function note(t)
	print("[BM Hub] " .. t)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BM Hub", Text = t, Duration = 12 }) end)
end
local key = g.BM_KEY
if type(key) ~= "string" or not key:match("^BM%-[%w%-]+$") then
	return note("No key: put your key in getgenv().BM_KEY first")
end
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
while not lp do task.wait(0.1) lp = Players.LocalPlayer end
local dev
pcall(function() if gethwid then dev = tostring(gethwid()) end end)
if type(dev) ~= "string" or #dev < 4 then
	pcall(function() dev = game:GetService("RbxAnalyticsService"):GetClientId() end)
end
dev = (tostring(dev or ""):gsub("[^%w%-_%.:]", ""))
if #dev > 128 then dev = dev:sub(1, 128) end
g.BM_DEV = dev
local ok, src = pcall(function() return game:HttpGet(SERVER .. "/load?key=" .. key .. "&uid=" .. tostring(lp.UserId) .. "&dev=" .. dev) end)
if not ok or type(src) ~= "string" or #src == 0 then
	return note("Could not reach the key server: " .. tostring(src):sub(1, 120))
end
local fn, err = loadstring(src)
if not fn then return note("Load error: " .. tostring(err):sub(1, 150)) end
fn()
`;
}

// توکن گیت‌هاب هیچ‌وقت فاصله یا کاراکتر نامرئی نداره؛ موقع چسباندن (مخصوصاً با کیبورد فارسی) علامت جهت
// (RLM/LRM)، فاصله‌ی صفر یا خط جدید میاد و هدر رو خراب می‌کنه، پس پاک میشن
export function cleanToken(t) {
	return String(t || "").replace(/[\s\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/g, "");
}
export function tokenShape(t) {
	const c = cleanToken(t);
	return {
		length: c.length,
		prefix: c.startsWith("github_pat_") ? "github_pat_" : c.startsWith("ghp_") ? "ghp_" : "other",
		removed: String(t || "").length - c.length,
		badChars: [...c].filter((ch) => ch.charCodeAt(0) < 33 || ch.charCodeAt(0) > 126).length,
	};
}

async function getScript(env, fetchFn) {
	if (scriptCache && Date.now() - scriptCache.at < SCRIPT_TTL_MS) return scriptCache.text;
	const url = `https://api.github.com/repos/${env.REPO}/contents/${env.FILE || "bm_hub_v3.lua"}?ref=${env.BRANCH || "main"}`;
	try {
		const r = await fetchFn(url, {
			headers: {
				// فاصله یا خط جدیدی که موقع چسباندن توکن میاد هدر رو خراب می‌کنه
				Authorization: `Bearer ${cleanToken(env.GITHUB_TOKEN)}`,
				Accept: "application/vnd.github.raw",
				"User-Agent": "bmhub-keyserver",
			},
		});
		if (r.ok) {
			const text = await r.text();
			if (text.length > 5000 && text.includes("BM Hub")) {
				const m = text.match(/Version = "([\d.]+)"/);
				scriptCache = { text, at: Date.now(), version: m ? m[1] : "?" };
				scriptStatus = { ok: true, at: Date.now(), error: null };
				return text;
			}
			scriptStatus = { ok: false, at: Date.now(), error: "GitHub file does not look like BM Hub" };
		} else {
			scriptStatus = { ok: false, at: Date.now(), error: "GitHub answered " + r.status };
		}
	} catch (e) {
		// متن خطا برای پیدا کردن مشکل؛ توکن اگه توش بود حذف میشه
		const tok = cleanToken(env.GITHUB_TOKEN);
		let msg = String((e && e.message) || e).slice(0, 160);
		if (tok) msg = msg.split(tok).join("***");
		scriptStatus = { ok: false, at: Date.now(), error: "GitHub unreachable: " + msg };
	}
	// گیت‌هاب در دسترس نبود: آخرین نسخه‌ی سالم بهتر از هیچی
	return scriptCache ? scriptCache.text : null;
}

export function resetScriptCache() {
	scriptCache = null;
	scriptStatus = { ok: null, at: null, error: null };
}

function text(body, status = 200, type = "text/plain; charset=utf-8") {
	return new Response(body, { status, headers: { "Content-Type": type, "Cache-Control": "no-store" } });
}
// اسکریپت هاب بدون فشرده‌سازی: Cloudflare متن رو با zstd فشرده می‌کنه و دانلودر Solara اون رو
// نمی‌فهمه (حدود ۶۰ ثانیه گیر می‌کرد و هیچی اجرا نمی‌شد). octet-stream هیچ‌وقت فشرده نمیشه
export function scriptResponse(body) {
	return new Response(body, { status: 200, headers: { "Content-Type": "application/octet-stream", "Cache-Control": "no-store, no-transform" } });
}
function json(obj, status = 200) {
	return text(JSON.stringify(obj), status, "application/json; charset=utf-8");
}

// ---------------------------------------------------------------- KV

async function getRec(env, key) {
	if (!KEY_RE.test(key || "")) return null;
	const raw = await env.KEYS.get("key:" + key);
	return raw ? normalize(JSON.parse(raw)) : null;
}
// رکورد کامل هم به‌عنوان metadata ذخیره میشه تا لیست کردن بدون خوندن تک‌تک کلیدها باشه
// (سقف metadata توی KV ۱۰۲۴ بایته؛ اسم و یادداشت فارسی جای بیشتری می‌گیره، پس اگه بزرگ بود بدون metadata)
async function putRec(env, rec) {
	const body = JSON.stringify(rec);
	const small = new TextEncoder().encode(body).length <= 1000;
	await env.KEYS.put("key:" + rec.key, body, small ? { metadata: rec } : { metadata: { key: rec.key, partial: true } });
}

async function listRecs(env) {
	const out = [];
	let cursor;
	do {
		const page = await env.KEYS.list({ prefix: "key:", cursor });
		for (const k of page.keys) {
			if (k.metadata && k.metadata.key && !k.metadata.partial) out.push(normalize({ ...k.metadata }));
			else {
				const raw = await env.KEYS.get(k.name);
				if (raw) out.push(normalize(JSON.parse(raw)));
			}
		}
		cursor = page.list_complete ? undefined : page.cursor;
	} while (cursor);
	out.sort((a, b) => (b.created || 0) - (a.created || 0));
	return out;
}

async function audit(env, now, who, action, detail) {
	const entry = { at: now, who, action, detail: String(detail || "").slice(0, 200) };
	// کلید معکوس زمان: list جدیدترین‌ها رو اول میده
	const id = "audit:" + String(1e13 - now).padStart(14, "0") + ":" + randomHex(3);
	await env.KEYS.put(id, "1", { expirationTtl: AUDIT_TTL_S, metadata: entry });
}

async function listAudit(env, limit = 200) {
	const page = await env.KEYS.list({ prefix: "audit:", limit });
	return page.keys.map((k) => k.metadata).filter(Boolean);
}

// ---------------------------------------------------------------- ورود و جلسه

async function login(env, user, password, now) {
	user = String(user || "").trim().toLowerCase();
	if (user === OWNER || user === "") {
		return sameString(password, env.ADMIN_PASSWORD) ? { user: OWNER, role: "owner" } : null;
	}
	if (!USER_RE.test(user)) return null;
	const raw = await env.KEYS.get("admin:" + user);
	if (!raw) return null;
	const a = JSON.parse(raw);
	if (a.disabled) return null;
	const h = await hashPassword(String(password || ""), a.salt);
	return sameString(h, a.hash) ? { user, role: "admin" } : null;
}

async function newSession(env, who, now) {
	const token = randomHex(32);
	await env.KEYS.put("sess:" + token, JSON.stringify({ ...who, at: now }), { expirationTtl: SESSION_TTL_S });
	return token;
}

async function sessionFrom(env, req) {
	const h = req.headers.get("Authorization") || "";
	const token = h.startsWith("Bearer ") ? h.slice(7).trim() : "";
	if (!/^[0-9a-f]{64}$/.test(token)) return null;
	const raw = await env.KEYS.get("sess:" + token);
	if (!raw) return null;
	const s = JSON.parse(raw);
	// ادمینی که خاموش شده، جلسه‌ی باز هم نداره
	if (s.role === "admin") {
		const a = await env.KEYS.get("admin:" + s.user);
		if (!a || JSON.parse(a).disabled) return null;
	}
	return { ...s, token };
}

// ---------------------------------------------------------------- API پنل

function cleanName(v, max) {
	return String(v || "").replace(/[\u0000-\u001f]/g, " ").trim().slice(0, max);
}
function daysToExpiry(days, now) {
	const d = Number(days);
	return Number.isFinite(d) && d > 0 ? now + Math.round(d * 86400000) : null;
}

export function computeStats(recs, now) {
	const s = { total: recs.length, active: 0, unused: 0, expired: 0, revoked: 0, usedToday: 0, runs: 0, expiringSoon: 0, deniedToday: 0 };
	for (const r of recs) {
		s[keyStatus(r, now)]++;
		s.runs += r.uses || 0;
		if (r.lastUse && now - r.lastUse < 86400000) s.usedToday++;
		if (r.lastDenied && now - r.lastDenied < 86400000) s.deniedToday++;
		if (!r.revoked && r.expires && r.expires > now && r.expires - now < 3 * 86400000) s.expiringSoon++;
	}
	return s;
}

async function adminApi(req, env, now, fetchFn) {
	const ip = req.headers.get("CF-Connecting-IP") || "?";
	let body;
	try {
		body = await req.json();
	} catch (_) {
		return json({ error: "درخواست خراب" }, 400);
	}
	const action = String(body.action || "");

	if (action === "login") {
		const failKey = "fail:" + ip;
		const fails = Number((await env.KEYS.get(failKey)) || 0);
		if (fails >= MAX_FAILS) return json({ error: "رمز اشتباه زیاد زدی، ۱۰ دقیقه صبر کن" }, 429);
		const who = await login(env, body.user, body.password, now);
		if (!who) {
			await env.KEYS.put(failKey, String(fails + 1), { expirationTtl: FAIL_WINDOW_S });
			return json({ error: "نام کاربری یا رمز اشتباهه" }, 401);
		}
		const session = await newSession(env, who, now);
		return json({ ok: true, session, user: who.user, role: who.role });
	}

	const me = await sessionFrom(env, req);
	if (!me) return json({ error: "دوباره وارد شو", relogin: true }, 401);
	const owner = me.role === "owner";
	const keysIn = (Array.isArray(body.keys) ? body.keys : [body.key]).map((k) => String(k || "").trim().toUpperCase()).filter((k) => KEY_RE.test(k)).slice(0, 500);

	switch (action) {
		case "me":
			return json({ user: me.user, role: me.role });
		case "logout":
			await env.KEYS.delete("sess:" + me.token);
			return json({ ok: true });
		case "list": {
			const recs = await listRecs(env);
			return json({ keys: recs, stats: computeStats(recs, now), now, script: { version: scriptCache ? scriptCache.version : null, ...scriptStatus } });
		}
		case "create": {
			const name = cleanName(body.name, 60);
			if (!name) return json({ error: "بنویس کلید برای کیه" }, 400);
			const count = Math.min(MAX_BULK, Math.max(1, Math.floor(Number(body.count) || 1)));
			const note = cleanName(body.note, 200);
			const maxDevs = Math.min(MAX_DEVS, Math.max(1, Math.floor(Number(body.maxDevs ?? body.maxUids) || 1)));
			const expires = daysToExpiry(body.days, now);
			const made = [];
			for (let i = 0; i < count; i++) {
				let key;
				do key = newKey(); while (await env.KEYS.get("key:" + key));
				const rec = normalize({ key, name: count > 1 ? `${name} #${i + 1}` : name, note, created: now, createdBy: me.user, expires, uids: [], devs: [], maxDevs, revoked: false, lastUse: null, uses: 0 });
				await putRec(env, rec);
				made.push(rec);
			}
			await audit(env, now, me.user, "create", `${count} کلید برای «${name}»` + (expires ? ` (${Number(body.days)} روز)` : " (دائمی)"));
			return json({ ok: true, keys: made });
		}
		case "update": {
			const rec = await getRec(env, keysIn[0]);
			if (!rec) return json({ error: "کلید پیدا نشد" }, 404);
			if (body.name !== undefined) {
				const n = cleanName(body.name, 60);
				if (!n) return json({ error: "اسم خالی نمیشه" }, 400);
				rec.name = n;
			}
			if (body.note !== undefined) rec.note = cleanName(body.note, 200);
			if (body.maxDevs !== undefined || body.maxUids !== undefined) {
				rec.maxDevs = Math.min(MAX_DEVS, Math.max(1, Math.floor(Number(body.maxDevs ?? body.maxUids) || 1)));
				if (rec.devs.length > rec.maxDevs) rec.devs = rec.devs.slice(-rec.maxDevs);
			}
			await putRec(env, rec);
			await audit(env, now, me.user, "update", `${rec.key} (${rec.name})`);
			return json({ ok: true, key: rec });
		}
		case "revoke":
		case "unrevoke":
		case "reset":
		case "extend":
		case "delete": {
			if (!keysIn.length) return json({ error: "کلیدی انتخاب نشده" }, 400);
			const done = [];
			for (const k of keysIn) {
				const rec = await getRec(env, k);
				if (!rec) continue;
				if (action === "delete") {
					// ادمین فقط کلیدهای خودش رو پاک می‌کنه؛ صاحب هاب همه رو
					if (!owner && rec.createdBy !== me.user) continue;
					await env.KEYS.delete("key:" + k);
				} else {
					if (action === "revoke") rec.revoked = true;
					if (action === "unrevoke") rec.revoked = false;
					if (action === "reset") rec.devs = [];
					if (action === "extend") {
						if (body.mode === "add" && rec.expires) {
							const base = Math.max(rec.expires, now);
							const d = Number(body.days);
							rec.expires = Number.isFinite(d) && d > 0 ? base + Math.round(d * 86400000) : null;
						} else rec.expires = daysToExpiry(body.days, now);
					}
					await putRec(env, rec);
				}
				done.push(k);
			}
			if (!done.length) return json({ error: action === "delete" && !owner ? "فقط کلیدهایی که خودت ساختی رو می‌تونی پاک کنی" : "کلید پیدا نشد" }, 404);
			const extra = action === "extend" ? (Number(body.days) > 0 ? ` (${body.mode === "add" ? "+" : ""}${Number(body.days)} روز)` : " (دائمی)") : "";
			await audit(env, now, me.user, action, (done.length === 1 ? done[0] : `${done.length} کلید`) + extra);
			return json({ ok: true, count: done.length });
		}
		case "audit":
			return json({ entries: await listAudit(env) });
		case "testGithub": {
			// همین الان از گیت‌هاب می‌گیره و نتیجه رو دقیق میگه (توکن هیچ‌وقت برنمی‌گرده)
			resetScriptCache();
			const ok = !!(await getScript(env, fetchFn));
			return json({ ok, version: scriptCache ? scriptCache.version : null, error: scriptStatus.error, hasToken: !!env.GITHUB_TOKEN, token: tokenShape(env.GITHUB_TOKEN), repo: env.REPO || null, file: env.FILE || "bm_hub_v3.lua", branch: env.BRANCH || "main" });
		}
		case "refresh":
			resetScriptCache();
			await audit(env, now, me.user, "refresh", "نسخه‌ی جدید هاب از گیت‌هاب");
			return json({ ok: true });
		case "export": {
			if (!owner) return json({ error: "فقط صاحب هاب" }, 403);
			await audit(env, now, me.user, "export", "پشتیبان کلیدها");
			return json({ exportedAt: now, keys: await listRecs(env) });
		}
		case "admins": {
			if (!owner) return json({ error: "فقط صاحب هاب" }, 403);
			const page = await env.KEYS.list({ prefix: "admin:" });
			const out = [];
			for (const k of page.keys) {
				const raw = await env.KEYS.get(k.name);
				if (raw) {
					const a = JSON.parse(raw);
					out.push({ user: a.user, created: a.created, disabled: !!a.disabled });
				}
			}
			return json({ admins: out });
		}
		case "addAdmin": {
			if (!owner) return json({ error: "فقط صاحب هاب" }, 403);
			const user = String(body.user || "").trim().toLowerCase();
			if (!USER_RE.test(user) || user === OWNER) return json({ error: "نام کاربری: ۳ تا ۲۴ حرف انگلیسی کوچیک، عدد، _ . -" }, 400);
			const pw = String(body.password || "");
			if (pw.length < 8) return json({ error: "رمز حداقل ۸ حرف باشه" }, 400);
			const existed = !!(await env.KEYS.get("admin:" + user));
			const salt = randomHex(16);
			await env.KEYS.put("admin:" + user, JSON.stringify({ user, salt, hash: await hashPassword(pw, salt), created: now, disabled: false }));
			await audit(env, now, me.user, existed ? "adminPassword" : "addAdmin", user);
			return json({ ok: true });
		}
		case "setAdmin": {
			if (!owner) return json({ error: "فقط صاحب هاب" }, 403);
			const user = String(body.user || "").trim().toLowerCase();
			const raw = await env.KEYS.get("admin:" + user);
			if (!raw) return json({ error: "ادمین پیدا نشد" }, 404);
			if (body.remove) {
				await env.KEYS.delete("admin:" + user);
				await audit(env, now, me.user, "removeAdmin", user);
			} else {
				const a = JSON.parse(raw);
				a.disabled = !!body.disabled;
				await env.KEYS.put("admin:" + user, JSON.stringify(a));
				await audit(env, now, me.user, a.disabled ? "disableAdmin" : "enableAdmin", user);
			}
			return json({ ok: true });
		}
		default:
			return json({ error: "کار ناشناخته" }, 400);
	}
}

// ---------------------------------------------------------------- مسیرها

export async function handle(req, env, fetchFn = fetch, now = Date.now()) {
	const url = new URL(req.url);
	const path = url.pathname.replace(/\/+$/, "") || "/";
	const key = (url.searchParams.get("key") || "").trim().toUpperCase();
	const uid = (url.searchParams.get("uid") || "").trim();
	const devRaw = (url.searchParams.get("dev") || "").trim();

	if (req.method === "GET" && path === "/l") return text(bootstrapLua(url.origin));

	if (req.method === "GET" && (path === "/load" || path === "/check")) {
		if (!UID_RE.test(uid) || (devRaw && !DEV_RE.test(devRaw))) return text(path === "/load" ? denyLua("Bad request") : "no:bad request");
		const rec = await getRec(env, key);
		// executor هیچ شناسه‌ای نداد: اکانت به‌جای دستگاه (مثل قبل). /check هاب قدیمی بدون dev: دستگاه چک نمیشه
		const dev = devRaw ? await deviceTag(devRaw) : path === "/load" ? "U-" + uid : null;
		const problem = keyProblem(rec, dev, now);
		if (problem) {
			// دستگاه دیگه با کلید یکی دیگه: برای پنل ثبت میشه (حداکثر دقیقه‌ای یه بار)
			if (rec && path === "/load" && problem.includes("another") && now - (rec.lastDenied || 0) > DENY_WRITE_GAP_MS) {
				rec.denied = (rec.denied || 0) + 1;
				rec.lastDenied = now;
				rec.lastDeniedUid = uid;
				rec.lastDeniedDev = dev;
				await putRec(env, rec);
			}
			return text(path === "/load" ? denyLua(problem) : "no:" + problem);
		}
		if (path === "/check") return text("ok");
		const script = await getScript(env, fetchFn);
		if (!script) return text(denyLua("Server could not get the script right now, try again in a minute"));
		// اولین استفاده (یا دستگاه جدید تا سقف مجاز): کلید به همین دستگاه قفل میشه؛ اکانت فقط ثبت میشه
		if (!rec.devs.includes(dev)) rec.devs.push(dev);
		rec.uids = rec.uids.filter((u) => u !== uid).concat(uid).slice(-MAX_SEEN_UIDS);
		rec.lastUse = now;
		rec.lastUid = uid;
		rec.lastDev = dev;
		rec.lastCountry = (req.cf && req.cf.country) || req.headers.get("CF-IPCountry") || null;
		rec.uses = (rec.uses || 0) + 1;
		await putRec(env, rec);
		return scriptResponse(script);
	}

	if (req.method === "GET" && path === "/admin") return text(ADMIN_HTML, 200, "text/html; charset=utf-8");
	if (req.method === "POST" && path === "/api") return adminApi(req, env, now, fetchFn);
	return text("Not found", 404);
}

export default {
	fetch(req, env) {
		return handle(req, env);
	},
};
