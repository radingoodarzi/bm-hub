// تست سرور کلید (روی همون فایلی که دیپلوی میشه: dist/worker.js). اجرا: node keyserver/test.mjs
import { scriptResponse, cleanToken, tokenShape, handle, newKey, keyProblem, bootstrapLua, denyLua, resetScriptCache, normalize, computeStats, hashPassword, deviceTag } from "./dist/worker.js";
import { writeFileSync } from "node:fs";

let fails = 0;
const check = (name, cond) => {
	console.log((cond ? "ok   " : "FAIL ") + name);
	if (!cond) fails++;
};

function makeKV() {
	const m = new Map(); // name -> { value, metadata }
	let writes = 0;
	return {
		m,
		get writes() { return writes; },
		async get(k) { return m.has(k) ? m.get(k).value : null; },
		async put(k, v, opts = {}) {
			if (opts.metadata && new TextEncoder().encode(JSON.stringify(opts.metadata)).length > 1024) throw new Error("metadata too large");
			writes++;
			m.set(k, { value: v, metadata: opts.metadata || null });
		},
		async delete(k) { writes++; m.delete(k); },
		async list({ prefix, limit = 1000 }) {
			const keys = [...m.keys()].filter((k) => k.startsWith(prefix)).sort().slice(0, limit).map((name) => ({ name, metadata: m.get(name).metadata }));
			return { keys, list_complete: true };
		},
	};
}
const SCRIPT = '-- BM Hub test script\nlocal Hub = { Version = "5.10" }\n' + "x".repeat(6000);
let ghCalls = 0, ghUp = true, lastAuth = null;
const fakeFetch = async (url, opts) => {
	ghCalls++;
	lastAuth = opts.headers.Authorization;
	if (!ghUp) throw new Error("down");
	return new Response(SCRIPT, { status: 200 });
};
const env = { KEYS: makeKV(), ADMIN_PASSWORD: "s3cret-pass", GITHUB_TOKEN: "ghp_test", REPO: "o/r", FILE: "bm_hub_v3.lua", BRANCH: "main" };
const O = "https://keys.example.workers.dev";
let NOW = 1_800_000_000_000;
const get = (p, headers = {}) => handle(new Request(O + p, { headers }), env, fakeFetch, NOW);
const raw = (body, session, ip = "1.1.1.1") => handle(new Request(O + "/api", {
	method: "POST", headers: { "Content-Type": "application/json", "CF-Connecting-IP": ip, ...(session ? { Authorization: "Bearer " + session } : {}) }, body: JSON.stringify(body),
}), env, fakeFetch, NOW);
const call = async (session, body) => { const r = await raw(body, session); return { status: r.status, data: await r.json() }; };

// شکل کلید
const k1 = newKey();
check("key format BM-XXXX-XXXX-XXXX-XXXX", /^BM-[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$/.test(k1));
check("no confusing 0/O/1/I in keys", !/[01OI]/.test(k1.slice(3)));
check("keys are random (500 all different)", new Set(Array.from({ length: 500 }, () => newKey())).size === 500);

// ورود
let r = await call(null, { action: "list" });
check("API without login refused", r.status === 401 && r.data.relogin);
r = await call(null, { action: "login", user: "owner", password: "wrong" });
check("wrong owner password refused", r.status === 401);
r = await call(null, { action: "login", user: "", password: env.ADMIN_PASSWORD });
check("owner login (empty username) works", r.status === 200 && r.data.role === "owner" && /^[0-9a-f]{64}$/.test(r.data.session));
const OWN = r.data.session;
r = await call(OWN, { action: "me" });
check("session works", r.data.user === "owner" && r.data.role === "owner");
r = await call("f".repeat(64), { action: "me" });
check("fake session refused", r.status === 401);

// ساخت
r = await call(OWN, { action: "create", name: "  " });
check("key needs a name", r.status === 400);
r = await call(OWN, { action: "create", name: "Ali <b>", note: "paid 5$", days: 30 });
const made = r.data.keys[0];
check("create key with 30 days + note", r.status === 200 && made.name === "Ali <b>" && made.note === "paid 5$" && made.expires === NOW + 30 * 86400000 && made.uids.length === 0 && made.createdBy === "owner");
r = await call(OWN, { action: "create", name: "Reza", days: 0, maxDevs: 2 });
const two = r.data.keys[0];
check("permanent key with 2 devices", two.expires === null && two.maxDevs === 2 && two.devs.length === 0);
r = await call(OWN, { action: "create", name: "Shop", count: 5, days: 7 });
check("bulk: 5 keys, numbered names", r.data.keys.length === 5 && r.data.keys[4].name === "Shop #5" && new Set(r.data.keys.map((k) => k.key)).size === 5);
r = await call(OWN, { action: "create", name: "Too many", count: 999 });
check("bulk capped at 50", r.data.keys.length === 50);
const bulkKeys = r.data.keys.map((k) => k.key);
r = await call(OWN, { action: "delete", keys: bulkKeys });
check("bulk delete", r.data.count === 50);
r = await call(OWN, { action: "create", name: "ن".repeat(60), note: "یادداشت فارسی ".repeat(20) });
check("long Persian name+note saved (no metadata overflow)", r.status === 200);
const big = r.data.keys[0];
r = await call(OWN, { action: "list" });
check("list shows all 8 keys incl. the big one", r.data.keys.length === 8 && r.data.keys.some((k) => k.key === big.key && k.note.length > 100));
check("stats: 8 unused", r.data.stats.total === 8 && r.data.stats.unused === 8);

// لودر
r = await get("/l");
const boot = await r.text();
check("loader knows the server address", boot.includes('"' + O + '"') && boot.includes("/load?key="));
check("loader sends a device id (gethwid, else RbxAnalyticsService) and keeps it for the hub", boot.includes("&dev=") && boot.includes("gethwid") && boot.includes("GetClientId") && boot.includes("g.BM_DEV = dev"));
writeFileSync(process.argv[2] || "bootstrap.lua", boot);

// استفاده
const w0 = env.KEYS.writes;
const PC_A = "PC-AAAA-1111", PC_B = "PC-BBBB-2222";
const TAG_A = await deviceTag(PC_A), TAG_B = await deviceTag(PC_B);
r = await get(`/load?key=${made.key}&uid=111&dev=${PC_A}`, { "CF-IPCountry": "DE" });
let body = await r.text();
check("valid key gets the script", body === SCRIPT);
check("one KV write per run (free plan limit)", env.KEYS.writes - w0 === 1);
check("GitHub token stays on the server", lastAuth === "Bearer ghp_test" && !body.includes("ghp_test") && !boot.includes("ghp_test"));
r = await call(OWN, { action: "list" });
let rec = r.data.keys.find((k) => k.key === made.key);
check("first use locks to that device, account and country saved", rec.devs.length === 1 && rec.devs[0] === TAG_A && rec.uids[0] === "111" && rec.uses === 1 && rec.lastCountry === "DE");
check("raw device id is never stored, only a short hash tag", !JSON.stringify(rec).includes(PC_A) && /^D-[0-9A-F]{12}$/.test(TAG_A));
check("panel sees the hub version", r.data.script.version === "5.10" && r.data.script.ok === true);
r = await get(`/load?key=${made.key}&uid=222&dev=${PC_A}`);
check("another Roblox account on the SAME device works", (await r.text()) === SCRIPT);
r = await call(OWN, { action: "list" });
rec = r.data.keys.find((k) => k.key === made.key);
check("both accounts listed for the panel, still one device", rec.uids.join(",") === "111,222" && rec.devs.length === 1);
r = await get(`/load?key=${made.key}&uid=111&dev=${PC_B}`);
check("same account on ANOTHER device refused", (await r.text()).includes("locked to another device"));
r = await call(OWN, { action: "list" });
rec = r.data.keys.find((k) => k.key === made.key);
check("attempt from another device is recorded", rec.denied === 1 && rec.lastDeniedDev === TAG_B && rec.lastDeniedUid === "111");
const w1 = env.KEYS.writes;
await get(`/load?key=${made.key}&uid=333&dev=PC-CCCC-3333`);
check("spam from other devices: max one write per minute", env.KEYS.writes === w1);
const w2 = env.KEYS.writes;
r = await get(`/check?key=${made.key}&uid=999&dev=${PC_A}`);
check("check: ok on the owner's device (any account), and writes nothing", (await r.text()) === "ok" && env.KEYS.writes === w2);
r = await get(`/check?key=${made.key}&uid=111&dev=${PC_B}`);
check("check: no on another device", (await r.text()).startsWith("no:"));
r = await get(`/check?key=${made.key}&uid=555`);
check("check from an old hub build (no device id): not kicked", (await r.text()) === "ok");
r = await get(`/load?key=${made.key.toLowerCase()}&uid=111&dev=${PC_A}`);
check("lowercase key still works", (await r.text()) === SCRIPT);
r = await get(`/load?key=${made.key}&uid=111&dev=bad%20id!`);
check("strange device id refused", (await r.text()).includes("Bad request"));

// دو دستگاه
await get(`/load?key=${two.key}&uid=10&dev=PC-X-0001`);
r = await get(`/load?key=${two.key}&uid=20&dev=PC-Y-0002`);
check("2-device key: second device accepted", (await r.text()) === SCRIPT);
r = await get(`/load?key=${two.key}&uid=30&dev=PC-Z-0003`);
check("2-device key: third device refused", (await r.text()).includes("another device"));
r = await call(OWN, { action: "update", key: two.key, maxDevs: 1 });
check("lowering max devices keeps the latest one", r.data.key.devs.length === 1 && r.data.key.devs[0] === (await deviceTag("PC-Y-0002")));
r = await call(OWN, { action: "update", key: two.key, name: "Reza VIP", note: "alt account" });
check("edit name and note", r.data.key.name === "Reza VIP" && r.data.key.note === "alt account");

// executor بدون شناسه: مثل قبل به اکانت قفل میشه
r = await call(OWN, { action: "create", name: "NoHwid", days: 0 });
const nohw = r.data.keys[0];
check("no device id from the executor: still loads", (await (await get(`/load?key=${nohw.key}&uid=77`)).text()) === SCRIPT);
check("...locked to that account instead", (await (await get(`/load?key=${nohw.key}&uid=78`)).text()).includes("another device"));

// کلید اشتباه
r = await get(`/load?key=BM-AAAA-BBBB-CCCC-DDDD&uid=111`);
check("unknown key refused", (await r.text()).includes("does not exist"));
r = await get(`/load?key=${made.key}&uid=abc&dev=${PC_A}`);
check("bad uid refused", (await r.text()).includes("Bad request"));

// خاموش، روشن، ریست، تمدید
await call(OWN, { action: "revoke", key: made.key });
r = await get(`/check?key=${made.key}&uid=111&dev=${PC_A}`);
check("revoked: check says no (running hub stops)", (await r.text()).includes("turned off"));
await call(OWN, { action: "unrevoke", keys: [made.key] });
check("turned back on works", (await (await get(`/load?key=${made.key}&uid=111&dev=${PC_A}`)).text()) === SCRIPT);
await call(OWN, { action: "reset", key: made.key });
check("after reset it locks to the new device", (await (await get(`/load?key=${made.key}&uid=222&dev=${PC_B}`)).text()) === SCRIPT);
check("...and the old device is now refused", (await (await get(`/load?key=${made.key}&uid=222&dev=${PC_A}`)).text()).includes("another device"));
NOW += 31 * 86400000;
check("expired key refused", (await (await get(`/load?key=${made.key}&uid=222&dev=${PC_B}`)).text()).includes("expired"));
check("permanent key still works a month later", (await (await get(`/load?key=${two.key}&uid=20&dev=PC-Y-0002`)).text()) === SCRIPT);
await call(OWN, { action: "extend", key: made.key, days: 7 });
check("extend from today works again", (await (await get(`/load?key=${made.key}&uid=222&dev=${PC_B}`)).text()) === SCRIPT);
r = await call(OWN, { action: "list" });
const exp1 = r.data.keys.find((k) => k.key === made.key).expires;
await call(OWN, { action: "extend", key: made.key, days: 10, mode: "add" });
r = await call(OWN, { action: "list" });
check("extend 'add' adds to the remaining days", r.data.keys.find((k) => k.key === made.key).expires === exp1 + 10 * 86400000);

// ادمین‌ها
r = await call(OWN, { action: "addAdmin", user: "Ali", password: "short" });
check("admin password needs 8+ chars", r.status === 400);
r = await call(OWN, { action: "addAdmin", user: "owner", password: "longenough1" });
check("can't make an admin called owner", r.status === 400);
r = await call(OWN, { action: "addAdmin", user: "ali", password: "ali-pass-123" });
check("owner adds admin", r.status === 200);
const stored = JSON.parse(env.KEYS.m.get("admin:ali").value);
check("admin password stored hashed, not plain", !JSON.stringify(stored).includes("ali-pass-123") && stored.hash.length === 64);
r = await call(null, { action: "login", user: "ali", password: "wrong-pass" });
check("admin wrong password refused", r.status === 401);
r = await call(null, { action: "login", user: "ALI", password: "ali-pass-123" });
check("admin login (username not case sensitive)", r.status === 200 && r.data.role === "admin");
const ALI = r.data.session;
r = await call(ALI, { action: "admins" });
check("admin can't see admin list", r.status === 403);
r = await call(ALI, { action: "export" });
check("admin can't export", r.status === 403);
r = await call(ALI, { action: "create", name: "Ali's customer" });
const aliKey = r.data.keys[0];
check("admin creates keys (createdBy = ali)", aliKey.createdBy === "ali");
r = await call(ALI, { action: "delete", key: two.key });
check("admin can't delete owner's key", r.status === 404 && r.data.error.includes("خودت"));
r = await call(ALI, { action: "delete", key: aliKey.key });
check("admin deletes own key", r.data.count === 1);
r = await call(OWN, { action: "setAdmin", user: "ali", disabled: true });
r = await call(ALI, { action: "list" });
check("disabled admin's open session stops working", r.status === 401);
r = await call(null, { action: "login", user: "ali", password: "ali-pass-123" });
check("disabled admin can't log in", r.status === 401);
await call(OWN, { action: "setAdmin", user: "ali", disabled: false });
await call(OWN, { action: "addAdmin", user: "ali", password: "new-pass-456" });
r = await call(null, { action: "login", user: "ali", password: "ali-pass-123" });
check("owner changed admin password: old one fails", r.status === 401);
r = await call(null, { action: "login", user: "ali", password: "new-pass-456" });
check("new admin password works", r.status === 200);
r = await call(OWN, { action: "admins" });
check("admin list (no hashes sent)", r.data.admins.length === 1 && r.data.admins[0].user === "ali" && !JSON.stringify(r.data).includes("hash"));
NOW += 1000;
await call(OWN, { action: "setAdmin", user: "ali", remove: true });
r = await call(OWN, { action: "admins" });
check("remove admin", r.data.admins.length === 0);

// گزارش فعالیت
r = await call(OWN, { action: "audit" });
const acts = r.data.entries.map((e) => e.action);
check("activity log has the admin actions, newest first", acts[0] === "removeAdmin" && acts.includes("create") && acts.includes("revoke") && acts.includes("addAdmin") && r.data.entries.some((e) => e.who === "ali"));
check("activity log does not contain passwords", !JSON.stringify(r.data).includes("pass-"));

// پشتیبان، خروج
r = await call(OWN, { action: "export" });
check("owner export", r.status === 200 && Array.isArray(r.data.keys) && r.data.keys.length >= 3);
r = await call(OWN, { action: "logout" });
r = await call(OWN, { action: "me" });
check("logout ends the session", r.status === 401);

// آزمایش گیت‌هاب از پنل
{
	const L = await call(null, { action: "login", user: "owner", password: env.ADMIN_PASSWORD });
	let t = await call(L.data.session, { action: "testGithub" });
	check("testGithub: ok + version, token never returned", t.data.ok === true && t.data.version === "5.10" && t.data.hasToken === true && !JSON.stringify(t.data).includes("ghp_test"));
	ghUp = false;
	t = await call(L.data.session, { action: "testGithub" });
	check("testGithub: reports the failure", t.data.ok === false && t.data.error);
	ghUp = true;
	await call(L.data.session, { action: "testGithub" }); // کش دوباره پر میشه
}
// گیت‌هاب
const before = ghCalls;
await get(`/load?key=${two.key}&uid=20&dev=PC-Y-0002`);
check("script is cached (no GitHub call every run)", ghCalls === before);
ghUp = false;
resetScriptCache();
check("GitHub down, nothing cached: clear message", (await (await get(`/load?key=${two.key}&uid=20&dev=PC-Y-0002`)).text()).includes("could not get the script"));
ghUp = true;
resetScriptCache();

// رمز اشتباه زیاد
for (let i = 0; i < 10; i++) await raw({ action: "login", user: "owner", password: "nope" + i }, null, "9.9.9.9");
r = await raw({ action: "login", user: "owner", password: env.ADMIN_PASSWORD }, null, "9.9.9.9");
check("10 wrong passwords from one IP: locked for a while", r.status === 429);
r = await raw({ action: "login", user: "owner", password: env.ADMIN_PASSWORD }, null, "8.8.8.8");
check("other IPs not affected", r.status === 200);

// صفحه
r = await get("/admin");
const html = await r.text();
check("panel served", r.status === 200 && html.includes("BM Hub") && html.includes("function esc("));
check("panel does not contain the password", !html.includes(env.ADMIN_PASSWORD));
check("unknown path 404", (await get("/nothing")).status === 404);

// تابع‌های خالص
check("old account-locked keys: first device after the update takes the lock", keyProblem(normalize({ uid: 5 }), "D-AAAAAAAAAAAA", 0) === null && normalize({ uids: ["5"], maxUids: 3 }).maxDevs === 3);
check("old record keeps working once a device is set", keyProblem(normalize({ uids: ["5"], devs: ["D-1"] }), "D-2", 0) !== null && keyProblem(normalize({ devs: ["D-1"] }), null, 0) === null);
check("stats count", computeStats([normalize({ revoked: true }), normalize({ uids: ["1"], lastUse: 0 })], 1).revoked === 1);
check("deny message escapes quotes", denyLua('a"b\\c').includes('a\\"b\\\\c'));
check("password hash is stable", (await hashPassword("x", "00ff")) === (await hashPassword("x", "00ff")) && (await hashPassword("x", "00ff")) !== (await hashPassword("y", "00ff")));

// توکن با فاصله / خط جدید (از چسباندن) هم کار می‌کنه
{
	const env2 = { ...env, GITHUB_TOKEN: "  ghp_spaced" + String.fromCharCode(10) };
	resetScriptCache();
	let seen = null;
	const f2 = async (u, o) => { seen = o.headers.Authorization; return new Response(SCRIPT); };
	const r2 = await handle(new Request(O + `/load?key=${two.key}&uid=20&dev=PC-Y-0002`), env2, f2, NOW);
	check("token with spaces/newline is trimmed", seen === "Bearer ghp_spaced" && (await r2.text()) === SCRIPT);
	resetScriptCache();
	const f3 = async () => { throw new Error("bad header Bearer ghp_spaced here"); };
	await handle(new Request(O + `/load?key=${two.key}&uid=20&dev=PC-Y-0002`), env2, f3, NOW);
	const L = await call(null, { action: "login", user: "owner", password: env.ADMIN_PASSWORD });
	resetScriptCache();
	const t3 = await handle(new Request(O + "/api", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + L.data.session }, body: JSON.stringify({ action: "testGithub" }) }), env2, f3, NOW);
	const d3 = await t3.json();
	check("error text is shown but the token is hidden", d3.error.includes("bad header") && !d3.error.includes("ghp_spaced") && d3.error.includes("***"));
}
check("invisible RLM/LRM/zero-width/newline removed from token", cleanToken(String.fromCharCode(0x200F) + "github_pat_AB" + String.fromCharCode(0x200B, 10) + "CD ") === "github_pat_ABCD");
check("token shape: length/prefix/odd chars, never the token", JSON.stringify(tokenShape(" github_pat_ABCDé")) === JSON.stringify({ length: 16, prefix: "github_pat_", removed: 1, badChars: 1 }));
{
	const rr = await get(`/load?key=${two.key}&uid=20&dev=PC-Y-0002`);
	check("hub script sent uncompressible (no zstd for Solara)", rr.headers.get("Content-Type") === "application/octet-stream" && rr.headers.get("Cache-Control").includes("no-transform") && (await rr.text()) === SCRIPT);
}
console.log(fails === 0 ? "ALL PASSED" : fails + " FAILED");
process.exit(fails ? 1 : 0);
