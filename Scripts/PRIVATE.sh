#!/usr/bin/env bash
set -euo pipefail

echo "[PRIVATE.sh] profile=${WRT_PROFILE:-unknown}, pwd=$(pwd)" >&2

# 1. 将 Lucky 核心版本和下载地址切换到官网最新 Release（v3.8.1）
python3 - <<'PY'
import glob
import re
import sys
from pathlib import Path

LUCKY_VER = "3.8.1"
# 如需全功能“万吉”版，将下行的 _lucky 改为 _wanji（并确认官网对应压缩包文件名一致）
LUCKY_URL = "https://release.66666.host/v$(PKG_VERSION)/$(PKG_VERSION)_lucky"

targets = (
    glob.glob("package/**/lucky/Makefile", recursive=True)
    + glob.glob("feeds/**/lucky/Makefile", recursive=True)
)

if not targets:
    print("[PRIVATE.sh] 未找到 lucky/Makefile，跳过版本更新", file=sys.stderr, flush=True)
    raise SystemExit(0)

for path_str in sorted(set(targets)):
    p = Path(path_str)
    content = p.read_text(encoding="utf-8")
    if "PKG_NAME:=lucky" not in content:
        continue

    new_content = re.sub(r"^PKG_VERSION:=.*$", f"PKG_VERSION:={LUCKY_VER}", content, flags=re.M)
    new_content = re.sub(r"^PKG_SOURCE_URL:=.*$", f"PKG_SOURCE_URL:={LUCKY_URL}", new_content, flags=re.M)

    if new_content != content:
        p.write_text(new_content, encoding="utf-8")
        print(f"[PRIVATE.sh] 已将 {p} 更新为 v{LUCKY_VER} ({LUCKY_URL})", file=sys.stderr, flush=True)
    else:
        print(f"[PRIVATE.sh] {p} 已是 v{LUCKY_VER}，无需更新", file=sys.stderr, flush=True)
PY
