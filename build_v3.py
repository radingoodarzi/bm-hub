"""
bm_hub_v3.lua = bm_hub_v2.lua + ماژول‌های v3_src (به ترتیب شماره‌ی فایل).

هر فایل v3_src/NN_name.lua دو بخش داره که با خط `--@@UI@@` جدا میشن:
  بالا: منطق (قبل از بخش UI فایل اصلی درج میشه)
  پایین: تب‌های UI (بین تب‌های Bosses و Items درج میشه)

اجرا:  python build_v3.py
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent
BASE = ROOT / "bm_hub_v2.lua"
OUT = ROOT / "bm_hub_v3.lua"
VERSION = "3.0"


def patch(src, old, new, count=1):
    n = src.count(old)
    if n != count:
        sys.exit(f"anchor found {n}x (expected {count}): {old[:70]!r}")
    return src.replace(old, new)


src = BASE.read_text(encoding="utf-8")  # \r\n -> \n

src = patch(src, 'Version = "1.75"', f'Version = "{VERSION}"')
src = patch(src, "loader_v2.lua", "loader_v3.lua", 2)

# فارم‌های جدید جزو «کار اصلی» حساب بشن (صندوق/میوه صبر کنن)
busy_old = "or (Hub.SpecialAny ~= nil and Hub.SpecialAny())"
src = patch(src, busy_old, busy_old + "\n\t\tor (Hub.V3Busy ~= nil and Hub.V3Busy())", 2)

# گزینه‌هایی که پول خرج می‌کنن توی ذخیره‌سازی نمیان
src = patch(
    src,
    "local function saveSettings()",
    "for k in pairs(Hub.V3SkipSave or {}) do SKIP_SAVE[k] = true end\n\nlocal function saveSettings()",
)

logic, ui = [], []
for m in sorted((ROOT / "v3_src").glob("[0-9][0-9]_*.lua")):
    head, _, tail = m.read_text(encoding="utf-8").partition("--@@UI@@\n")
    logic.append(f"-- ===== {m.name} =====\n{head.rstrip()}\n")
    if tail.strip():
        ui.append(f"-- ===== {m.name} (UI) =====\ndo\n{tail.rstrip()}\nend\n")

ui_banner = "---------------------------------------------------------------------\n-- UI\n"
src = patch(src, ui_banner, "\n".join(logic) + "\n" + ui_banner)

# تب‌های جدید قبل از تب Items
items_at = src.index("-- Items:")
src = src[:items_at] + "\n".join(ui) + "\n" + src[items_at:]

OUT.write_text(src, encoding="utf-8", newline="\r\n")
print(f"wrote {OUT.name}: {len(src.splitlines())} lines, {len(logic)} modules")
