#!/usr/bin/env bash
set -euo pipefail

echo "[PRIVATE.sh] profile=${WRT_PROFILE:-unknown}, pwd=$(pwd)" >&2

python3 - <<'PY'
import glob
import re
import sys
from pathlib import Path

targets = (
    glob.glob("package/**/root/usr/share/rpcd/ucode/luci.adguardhome", recursive=True)
    + glob.glob("feeds/**/root/usr/share/rpcd/ucode/luci.adguardhome", recursive=True)
)

if not targets:
    print("[PRIVATE.sh] 未找到 luci.adguardhome，跳过修补", file=sys.stderr, flush=True)
    raise SystemExit(0)

helper = """
function mkdtemp(template) {
\tlet tpl = (type(template) == 'string' && length(template) > 0) ? template : '/tmp/tmp.XXXXXX';
\tlet safe = replace(tpl, "'", "'\\\\''");
\tlet p = popen("/bin/mktemp -d '" + safe + "' 2>/dev/null", 'r');
\tif (!p)
\t\treturn null;
\tlet dir = trim(p.read('all') || '');
\tp.close();
\treturn length(dir) > 0 ? dir : null;
}
"""

pattern = re.compile(r"(import\s*\{)([^}]*)(\}\s*from\s*['\"]fs['\"]\s*;?)")

for path_str in sorted(set(targets)):
    p = Path(path_str)
    content = p.read_text(encoding="utf-8")

    if "function mkdtemp(" in content:
        print(f"[PRIVATE.sh] 已包含 mkdtemp 兼容实现，跳过: {p}", file=sys.stderr, flush=True)
        continue

    def repl(match):
        imports = [x.strip() for x in match.group(2).split(",") if x.strip()]
        if "mkdtemp" not in imports:
            return match.group(0)
        imports = [x for x in imports if x != "mkdtemp"]
        if "popen" not in imports:
            imports.append("popen")
        return f"{match.group(1)} {', '.join(imports)} {match.group(3)}\n{helper}"

    new_content, _ = pattern.subn(repl, content, count=1)
    if new_content != content:
        p.write_text(new_content, encoding="utf-8")
        print(f"[PRIVATE.sh] 已修补 {p}", file=sys.stderr, flush=True)
    else:
        print(f"[PRIVATE.sh] {p} 无需修补", file=sys.stderr, flush=True)
PY
