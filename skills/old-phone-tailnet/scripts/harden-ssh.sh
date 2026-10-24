#!/data/data/com.termux/files/usr/bin/bash
# 关闭 Termux sshd 的密码登录，只认公钥。先确认公钥已经能登录，再运行这个脚本。
set -e
K=~/.ssh/authorized_keys
[ -s "$K" ] || { echo "~/.ssh/authorized_keys 是空的。先放好公钥并测试能登录，再关密码。"; exit 1; }
C=$PREFIX/etc/ssh/sshd_config
[ -f "$C.bak" ] || cp "$C" "$C.bak"
sed -i -E '/^[#[:space:]]*(PasswordAuthentication|KbdInteractiveAuthentication)[[:space:]]/d' "$C"
printf '\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' >> "$C"
sshd -t
# 重新加载配置，不会断开当前会话
PID=$(cat "$PREFIX/var/run/sshd.pid" 2>/dev/null || true)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then kill -HUP "$PID"
elif pgrep -x sshd >/dev/null; then echo "找不到 sshd 主进程，请手动重启 sshd 让配置生效（pkill sshd; sshd，会断开当前 SSH）"; exit 1
else sshd; fi
echo "已改为只认公钥。原配置备份在 $C.bak"
