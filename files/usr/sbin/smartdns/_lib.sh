#!/bin/sh
# smartdns/_lib.sh —— 本目录公共定义（被 01~90 各步骤 source）
#
# 拆分来源：pkg-restore-smartdns.sh（538 行 / 15 个函数，2026-11-10 拆）
# 原则：只搬不改。变量名、判据、退出码、注释口径全部照原样，
#       唯一新增的是 _sd_discard（原脚本已有，搬来这里供各步骤共用）。
#
# 调用方式（每个步骤脚本开头两行）：
#   _here=$(cd "$(dirname "$0")" && pwd)
#   . "$_here/_lib.sh"

set -u
ROMDIR="${ROMDIR:-/rom}"
PKGROOT="${PKGROOT:-}"

# 通用恢复脚本的查找顺序（原 v.180.147）：
#   ① 显式 RESTORE_BIN
#   ② /usr/sbin/pkg-restore.sh —— 固件里的正式位置
#   ③ 与本脚本同目录 —— 两个脚本一起被拷到 /tmp 单独验时的情况。
RESTORE_BIN="${RESTORE_BIN:-}"
if [ -z "$RESTORE_BIN" ]; then
    if [ -x /usr/sbin/pkg-restore.sh ]; then
        RESTORE_BIN=/usr/sbin/pkg-restore.sh
    else
        RESTORE_BIN="$(dirname "$0")/pkg-restore.sh"
    fi
fi

log() { printf '[PKG] %s\n' "$*"; }

# /etc/smartdns/ 下必须存在的规则文件（与构建期固化进固件的那批一致）
SD_CONF_FILES="address.conf blacklist-ip.conf custom.conf domain-block.list domain-forwarding.list"

# localhost 本地解析 —— adblock 探活的活路（原 L83-99 依据整段保留在原脚本，
# 这里只留判据用的整行文本）。落点是 custom.conf 而不是 uci：
# uci 的 domain-rule 段 init 不认，写了也白写；init 生成的 smartdns.conf 里
# 有 `conf-file /etc/smartdns/custom.conf`，往该文件追加整行才生效。
_SD_LOCALRULE="address /localhost/127.0.0.1"

# 包在不在：二进制 + init 可执行，再做一次冒烟抓动态库缺口。
# 判据取向不变：只有明确加载错误才判缺，其余异常一律放过。
_sd_pkg_ok() {
    [ -x "$PKGROOT/usr/sbin/smartdns" ] && [ -x "$PKGROOT/etc/init.d/smartdns" ] || return 1
    case "$("$PKGROOT/usr/sbin/smartdns" -v 2>&1)" in
        *"Error loading"*|*"No such file"*|*"not found"*|*"cannot open shared object"*)
            return 1 ;;
    esac
    return 0
}

# 服务生不生效：pidof + 「53 的 socket inode 反查属主」。
# 只读判定，不启动、不重启。重启只发生在 06-apply.sh。
# 为什么不能只用 netstat 判 :53 —— dnsmasq 占着 53 时旧判据照样通过（2026-11-10 实测）。
_sd_serve() {
    _ss_pid=$(pidof smartdns 2>/dev/null | awk '{print $1}')
    [ -n "$_ss_pid" ] || return 1
    _ss_ino=$(awk 'NR>1 && $4=="07" { n=split($2,a,":"); if (a[n]=="0035") print $10 }' \
        /proc/net/udp /proc/net/udp6 2>/dev/null)
    [ -n "$_ss_ino" ] || return 1
    for _ss_i in $_ss_ino; do
        for _ss_f in /proc/"$_ss_pid"/fd/*; do
            [ "$(readlink "$_ss_f" 2>/dev/null)" = "socket:[$_ss_i]" ] && return 0
        done
    done
    return 1
}

# 丢弃尚未 commit 的 smartdns 改动。/tmp/.uci 是 uci 的暂存目录，
# 本进程 exit 后脏数据仍在，下次任何人 commit smartdns 都会把它带进去。
# 只 revert smartdns —— dhcp 由 smartdns 的 init 改，碰它会误伤 LuCI 里未提交的改动。
_sd_discard() {
    uci -q revert smartdns 2>/dev/null
    return 0
}
