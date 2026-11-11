import pathlib, sys
here = pathlib.Path(__file__).parent
src = pathlib.Path(r"D:\claude work\02-BM-Hub\bm-hub\v3_src\98_dracotrial.lua").read_text(encoding="utf-8")
mod = src[:src.index("--@@UI@@")]
body = (here / "dracotrial_test_body.lua").read_text(encoding="utf-8")
pathlib.Path(sys.argv[1]).write_text(body.replace("--@@MODULE@@", mod), encoding="utf-8")
