"""keyserver/worker.js + admin.html -> dist/worker.js (یه فایل، برای چسباندن توی داشبورد Cloudflare)."""
import json
import pathlib

HERE = pathlib.Path(__file__).parent
worker = (HERE / "worker.js").read_text(encoding="utf-8")
html = (HERE / "admin.html").read_text(encoding="utf-8")
imp = 'import { ADMIN_HTML } from "./admin.js";\n'
assert worker.count(imp) == 1, "import line missing"
# json.dumps: هر کاراکتری (بک‌تیک، ${، بک‌اسلش) بدون دردسر توی رشته‌ی JS میره
const = "const ADMIN_HTML = " + json.dumps(html, ensure_ascii=False) + ";\n"
out = HERE / "dist" / "worker.js"
out.parent.mkdir(exist_ok=True)
out.write_text(worker.replace(imp, const), encoding="utf-8")
print("wrote", out, len(out.read_text(encoding="utf-8")), "chars")
