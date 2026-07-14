from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
chars = (ROOT / "assets/fonts/ui_preload_chars.txt").read_text(encoding="utf-8")
escaped = chars.replace("\\", "\\\\").replace('"', '\\"')
preload = (
    "preload=[{\n"
    f'"chars": "{escaped}",\n'
    '"compress": false,\n'
    '"glyphs": PackedInt32Array(),\n'
    '"names": PackedStringArray(),\n'
    '"ranges": PackedInt32Array(32, 126)\n'
    "}]"
)
import_path = ROOT / "assets/fonts/simhei.ttf.import"
text = import_path.read_text(encoding="utf-8")
text = re.sub(r"preload=\[\{.*?\}\]", preload, text, count=1, flags=re.S)
import_path.write_text(text, encoding="utf-8")
print(f"updated font preload with {len(chars)} chars")
