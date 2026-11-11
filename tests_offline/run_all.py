"""همه‌ی تست‌های آفلاین BM Hub رو اجرا می‌کنه (بدون Roblox).

هر make_*.py از bm_hub_v3.lua (یا v3_src) یه فایل تست Luau می‌سازه و luau.exe اجراش می‌کنه.
اجرا:  python tests_offline/run_all.py      (اول python build_v3.py تا bm_hub_v3.lua تازه باشه)
"""
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).parent
LUAU = pathlib.Path(r"D:\claude work\02-BM-Hub\banana cat hub\my_banana_cat_tools\luau\luau.exe")


def run(gen, out, *extra):
    g = subprocess.run([sys.executable, str(gen), str(out), *extra], capture_output=True, text=True, encoding="utf-8")
    if g.returncode != 0:
        return None, g.stderr.strip().splitlines()[-1:] or ["generator failed"]
    r = subprocess.run([str(LUAU), str(out)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout.splitlines(), r.stderr.strip().splitlines()[-3:]


def main():
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bmhub_tests_"))
    total_ok = total_fail = 0
    for gen in sorted(HERE.glob("make_*.py")):
        jobs = [("quest",), ("smoke",)] if gen.name == "make_extra_tests.py" else [()]
        for extra in jobs:
            name = gen.stem[5:] + ("_" + extra[0] if extra else "")
            lines, err = run(gen, tmp / (name + ".luau"), *extra)
            if lines is None:
                print(f"{name:<22} GENERATOR ERROR: {err}")
                total_fail += 1
                continue
            ok = sum(1 for l in lines if l.startswith("ok"))
            fail = [l for l in lines if l.startswith("FAIL")]
            total_ok += ok
            total_fail += len(fail)
            extra_info = ""
            if name == "extra_tests_smoke":
                extra_info = " | " + next((l for l in lines if "errors logged" in l), "no smoke summary")
            print(f"{name:<22} {ok:>4} ok  {len(fail)} fail{extra_info}")
            for l in fail + ([e for e in err if e] if fail else []):
                print("    " + l)
    print(f"\nTOTAL: {total_ok} ok, {total_fail} fail")
    sys.exit(1 if total_fail else 0)


if __name__ == "__main__":
    main()
