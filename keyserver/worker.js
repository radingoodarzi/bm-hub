// BM Hub - سرور کلید (Cloudflare Worker)
//
// هر کلید مال یه نفره: اولین بار که استفاده بشه به اکانت (یا اکانت‌های) روبلاکس همون نفر قفل میشه.
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
//   GET  /load?key&uid    اسکریپت اصلی، فقط با کلید معتبر
//   GET  /check?key&uid   "ok" یا "no:دلیل" (هاب هر چند دقیقه چک می‌کنه)
//   GET  /admin           پنل مدیریت
//   POST /api             کارهای پنل (ورود با نام کاربری و رمز، بعد با توکن جلسه)
//
// محدودیت پلن رایگان KV: روزی ۱۰۰۰ نوشتن. برای همین /check چیزی نمی‌نویسه و هر اجرای هاب فقط یه نوشتن داره.

import { ADMIN_HTML } from "./admin.js";

const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // بدون 0/O و 1/I که با هم قاطی نشن
const KEY_RE = /^BM-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
const UID_RE = /^[0-9]{1,20}$/;
const USER_RE = /^[a-z0-9_.-]{3,24}$/;
const SCRIPT_TTL_MS = 60 * 1000;
const MAX_FAILS = 10; // رمز اشتباه پشت هم از یه IP
const FAIL_WINDOW_S = 600;
const SESSION_TTL_S = 12 * 3600;
const AUDIT_TTL_S = 90 * 86400;
const DENY_WRITE_GAP_MS = 60 * 1000; // ثبت تلاش اکانت دیگه حداکثر دقیقه‌ای یه بار (نوشتن KV محدوده)
const MAX_UIDS = 10;
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

// رکوردهای قدیمی (یه uid) به شکل جدید (لیست uid) تبدیل میشن
export function normalize(rec) {
	if (!rec) return rec;
	if (!Array.isArray(rec.uids)) rec.uids = rec.uid ? [String(rec.uid)] : [];
	delete rec.uid;
	rec.maxUids = Math.min(MAX_UIDS, Math.max(1, Number(rec.maxUids) || 1));
	rec.note = rec.note || "";
	rec.uses = rec.uses || 0;
	rec.denied = rec.denied || 0;
	return rec;
}

// دلیل رد شدن کلید، یا null یعنی معتبره
export function keyProblem(rec, uid, now) {
	if (!rec) return "This key does not exist";
	if (rec.revoked) return "This key was turned off by the admin";
	if (rec.expires && now > rec.expires) return "This key has expired";
	const uids = rec.uids || (rec.uid ? [String(rec.uid)] : []);
	if (uid && !uids.includes(String(uid)) && uids.length >= (rec.maxUids || 1)) return "This key belongs to another Roblox account";
	return null;
}

export function keyStatus(rec, now) {
	if (rec.revoked) return "revoked";
	if (rec.expires && now > rec.expires) return "expired";
	if (!rec.uids || rec.uids.length === 0) return "unused";
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

// لودر کوتاه: کلید از getgenv().BM_KEY، UserId از خود بازی
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
local ok, src = pcall(function() return game:HttpGet(SERVER .. "/load?key=" .. key .. "&uid=" .. tostring(lp.UserId)) end)
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
			const maxUids = Math.min(MAX_UIDS, Math.max(1, Math.floor(Number(body.maxUids) || 1)));
			const expires = daysToExpiry(body.days, now);
			const made = [];
			for (let i = 0; i < count; i++) {
				let key;
				do key = newKey(); while (await env.KEYS.get("key:" + key));
				const rec = normalize({ key, name: count > 1 ? `${name} #${i + 1}` : name, note, created: now, createdBy: me.user, expires, uids: [], maxUids, revoked: false, lastUse: null, uses: 0 });
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
			if (body.maxUids !== undefined) {
				rec.maxUids = Math.min(MAX_UIDS, Math.max(1, Math.floor(Number(body.maxUids) || 1)));
				if (rec.uids.length > rec.maxUids) rec.uids = rec.uids.slice(-rec.maxUids);
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
					if (action === "reset") rec.uids = [];
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

	if (req.method === "GET" && path === "/l") return text(bootstrapLua(url.origin));

	if (req.method === "GET" && (path === "/load" || path === "/check")) {
		if (!UID_RE.test(uid)) return text(path === "/load" ? denyLua("Bad request") : "no:bad request");
		const rec = await getRec(env, key);
		const problem = keyProblem(rec, uid, now);
		if (problem) {
			// اکانت دیگه با کلید یکی دیگه: برای پنل ثبت میشه (حداکثر دقیقه‌ای یه بار)
			if (rec && path === "/load" && problem.includes("another") && now - (rec.lastDenied || 0) > DENY_WRITE_GAP_MS) {
				rec.denied = (rec.denied || 0) + 1;
				rec.lastDenied = now;
				rec.lastDeniedUid = uid;
				await putRec(env, rec);
			}
			return text(path === "/load" ? denyLua(problem) : "no:" + problem);
		}
		if (path === "/check") return text("ok");
		const script = await getScript(env, fetchFn);
		if (!script) return text(denyLua("Server could not get the script right now, try again in a minute"));
		// اولین استفاده (یا اکانت جدید تا سقف مجاز): کلید به همین اکانت قفل میشه
		if (!rec.uids.includes(uid)) rec.uids.push(uid);
		rec.lastUse = now;
		rec.lastUid = uid;
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
