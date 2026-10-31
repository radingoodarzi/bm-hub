"""
bm_hub_v3.lua = bm_hub_v2.lua + ماژول‌های v3_src (به ترتیب شماره‌ی فایل).
bm_hub_test.lua = همون v3 + ماژول‌های test_src (آزمایشگاه A/B تلپورت و اتو کلیک) + loader_test.lua

هر فایل NN_name.lua دو بخش داره که با خط `--@@UI@@` جدا میشن:
  بالا: منطق (قبل از بخش UI فایل اصلی درج میشه)
  پایین: تب‌های UI (v3_src: بین تب‌های Bosses و Items، test_src: اولین تب)

اجرا:  python build_v3.py          -> bm_hub_v3.lua
       python build_v3.py --test   -> bm_hub_test.lua + loader_test.lua
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent
BASE = ROOT / "bm_hub_v2.lua"
TEST = "--test" in sys.argv
OUT = ROOT / ("bm_hub_test.lua" if TEST else "bm_hub_v3.lua")
VERSION = "3.0-test" if TEST else "3.0"
LOADER = "loader_test.lua" if TEST else "loader_v3.lua"


def patch(src, old, new, count=1):
    n = src.count(old)
    if n != count:
        sys.exit(f"anchor found {n}x (expected {count}): {old[:70]!r}")
    return src.replace(old, new)


def read_modules(folder):
    logic, ui = [], []
    for m in sorted((ROOT / folder).glob("[0-9][0-9]_*.lua")):
        head, _, tail = m.read_text(encoding="utf-8").partition("--@@UI@@\n")
        logic.append(f"-- ===== {m.name} =====\n{head.rstrip()}\n")
        if tail.strip():
            ui.append(f"-- ===== {m.name} (UI) =====\ndo\n{tail.rstrip()}\nend\n")
    return logic, ui


src = BASE.read_text(encoding="utf-8")  # \r\n -> \n

src = patch(src, 'Version = "1.75"', f'Version = "{VERSION}"')
src = patch(src, "loader_v2.lua", LOADER, 2)

# فارم‌های جدید جزو «کار اصلی» حساب بشن (صندوق/میوه صبر کنن)
busy_old = "or (Hub.SpecialAny ~= nil and Hub.SpecialAny())"
src = patch(src, busy_old, busy_old + "\n\t\tor (Hub.V3Busy ~= nil and Hub.V3Busy())", 2)

# گزینه‌هایی که پول خرج می‌کنن توی ذخیره‌سازی نمیان
src = patch(
    src,
    "local function saveSettings()",
    "for k in pairs(Hub.V3SkipSave or {}) do SKIP_SAVE[k] = true end\n\nlocal function saveSettings()",
)

v3_logic, v3_ui = read_modules("v3_src")
test_logic, test_ui = read_modules("test_src") if TEST else ([], [])

if TEST:
    # هوک‌های آزمایشگاه: شمارش رول‌بک موتور BM و جای ایستادن روی ماب
    src = patch(src, "snaps += 1", "snaps += 1\n\t\t\tif Hub.LabSnap then Hub.LabSnap() end")
    src = patch(
        src,
        "local standAt = hrp.Position + away * 3 + Vector3.new(0, h, 0)",
        "local standAt = (Hub.StandAt and Hub.StandAt(hrp, root, h, away)) or (hrp.Position + away * 3 + Vector3.new(0, h, 0))",
    )
    src = patch(src, 'selectPage("Home")', 'selectPage("A/B Lab")')

ui_banner = "---------------------------------------------------------------------\n-- UI\n"
src = patch(src, ui_banner, "\n".join(v3_logic + test_logic) + "\n" + ui_banner)

# تب‌های v3 قبل از تب Items؛ تب‌های آزمایشگاه اولین تب
items_at = src.index("-- Items:")
src = src[:items_at] + "\n".join(v3_ui) + "\n" + src[items_at:]
if test_ui:
    home_at = src.index("-- Home:")
    src = src[:home_at] + "\n".join(test_ui) + "\n" + src[home_at:]

OUT.write_text(src, encoding="utf-8", newline="\r\n")
print(f"wrote {OUT.name}: {len(src.splitlines())} lines, {len(v3_logic) + len(test_logic)} modules")

if TEST:
    loader = (ROOT / "loader_v3.lua").read_text(encoding="utf-8")
    loader = loader.replace("bm_hub_v3.lua", "bm_hub_test.lua").replace("loader_v3.lua", "loader_test.lua")
    loader = loader.replace("BM Hub v3 Loader", "BM Hub TEST Loader")
    (ROOT / "loader_test.lua").write_text(loader, encoding="utf-8", newline="\r\n")
    print("wrote loader_test.lua")
