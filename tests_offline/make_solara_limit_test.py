# 5.10: Solara فقط 200 local (رجیستر) توی بدنه‌ی اصلی قبول می‌کنه. luau-compile معمولی (-O1) بعضی local ها رو
# حذف می‌کنه و خطا رو نشون نمیده؛ -O0 سخت‌گیرتر از خود Solaraست. باید با ۵ local اضافه هم کامپایل بشه تا جا بمونه
import pathlib, subprocess, sys, tempfile
ROOT = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub")
COMPILER = pathlib.Path(r"D:\claude work\02-BM-Hub\banana cat hub\my_banana_cat_tools\luau\luau-compile.exe")
src = (ROOT / "bm_hub_v3.lua").read_text(encoding="utf-8")
anchor = 'print("[BM Hub] loading v" .. Hub.Version)\n'
results = []

def compiles(text):
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(text)
    r = subprocess.run([str(COMPILER), "--binary", "-O0", f.name], capture_output=True)
    pathlib.Path(f.name).unlink()
    return r.returncode == 0, r.stderr.decode("utf-8", "replace").strip().splitlines()[-1:] 

ok, err = compiles(src)
results.append(("compiles with -O0 (as strict as Solara or stricter)", ok, err))
pad = "local " + ",".join(f"_pad{i}" for i in range(5)) + " = nil\n"
ok2, err2 = compiles(src.replace(anchor, anchor + pad, 1)) if anchor in src else (False, ["anchor missing"])
results.append(("at least 5 spare main-body locals for future changes", ok2, err2))
out = []
for name, good, e in results:
    msg = name if good else name + " :: " + (e[0] if e else "")
    out.append('print(%r)' % (("ok   " if good else "FAIL ") + msg))
pathlib.Path(sys.argv[1]).write_text("\n".join(out).replace("'", '"') + "\n", encoding="utf-8")
