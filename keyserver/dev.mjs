// سرور محلی فقط برای دیدن پنل (KV توی حافظه، رمز تست). اجرا: node keyserver/dev.mjs
// نام کاربری owner، رمز: dev-password
import http from "node:http";
import { handle } from "./dist/worker.js";

const m = new Map();
const KV = {
	async get(k) { const v = m.get(k); return v ? v.value : null; },
	async put(k, value, o = {}) { m.set(k, { value, metadata: o.metadata || null }); },
	async delete(k) { m.delete(k); },
	async list({ prefix, limit = 1000 }) { return { keys: [...m.keys()].filter((k) => k.startsWith(prefix)).sort().slice(0, limit).map((name) => ({ name, metadata: m.get(name).metadata })), list_complete: true }; },
};
const env = { KEYS: KV, ADMIN_PASSWORD: "dev-password", GITHUB_TOKEN: "x", REPO: "o/r" };
const fakeFetch = async () => new Response('-- BM Hub\nlocal Hub = { Version = "5.10" }\n' + "x".repeat(6000));
const PORT = Number(process.env.PORT || 8787);
http.createServer(async (req, res) => {
	let body = "";
	for await (const c of req) body += c;
	const r = await handle(new Request("http://localhost:" + PORT + req.url, { method: req.method, headers: req.headers, body: req.method === "POST" ? body : undefined }), env, fakeFetch);
	res.writeHead(r.status, Object.fromEntries(r.headers));
	res.end(await r.text());
}).listen(PORT, () => console.log("dev panel: http://localhost:" + PORT + "/admin"));
