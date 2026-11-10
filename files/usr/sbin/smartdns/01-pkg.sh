#!/bin/sh
# smartdns/01-pkg.sh —— 步骤①：装本体（含依赖树）
#
# 拆分自 pkg-restore-smartdns.sh 的 _sd_pkg()。
# 走通用恢复的 --tree：smartdns 的两个依赖都是普通包，递归即可。
# 不联网：pkg-restore.sh 从 /rom 的包库装。
#
# 退出码：0 装好（或本来就齐）/ 1 失败

_here=$(cd "$(dirname "$0")" && pwd)
. "$_here/_lib.sh"

[ -x "$RESTORE_BIN" ] || { log "找不到 $RESTORE_BIN"; exit 1; }
"$RESTORE_BIN" --tree smartdns && exit 0 || exit 1
