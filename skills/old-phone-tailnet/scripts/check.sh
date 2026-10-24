#!/data/data/com.termux/files/usr/bin/bash
# 自检：只读，不改任何东西
SOCK=$HOME/.ts/tailscaled.sock
CDP_PORT=${CDP_PORT:-9222}
ok(){ echo "  [OK]  $1"; }; bad(){ echo "  [!!]  $1"; }
echo "== 旧手机私网接入自检 =="
pgrep -x sshd >/dev/null && ok "sshd 在运行（端口 8022）" || bad "sshd 没运行：执行 sshd"
C=$PREFIX/etc/ssh/sshd_config
grep -q '^PasswordAuthentication no' "$C" && ok "SSH 只认公钥" || bad "SSH 还允许密码登录：运行 harden-ssh.sh"
N=$(grep -c . ~/.ssh/authorized_keys 2>/dev/null); N=${N:-0}
if [ "$N" -gt 0 ]; then ok "authorized_keys 里有 $N 把公钥（确认每一把你都认识）"; else bad "authorized_keys 是空的：先放好公钥"; fi
if ~/bin/tailscale --socket="$SOCK" status >/dev/null 2>&1; then
  ok "Tailscale 在线：$(~/bin/tailscale --socket="$SOCK" ip -4 2>/dev/null)"
else bad "Tailscale 不在线：运行 start.sh，或 ~/bin/tailscale --socket=$SOCK up --hostname=old-phone 登录"; fi
adb devices 2>/dev/null | grep -q '127.0.0.1:5555[[:space:]]*device' && ok "adb 已连回本机 5555" || bad "adb 没连上：去开发者选项打开「无线调试」，再运行 start.sh IP:端口"
if curl -fs -m 5 "http://127.0.0.1:$CDP_PORT/json/version" >/dev/null; then ok "Chrome 调试口 $CDP_PORT 可用"
else bad "Chrome 调试口不通：先打开一次 Chrome，等 30 秒再查"; fi
PUB=$(pgrep -fa "pinggy|ngrok|frpc|cloudflared|serveo|localhost.run" | grep -v pgrep)
[ -z "$PUB" ] && ok "没发现公网隧道进程" || bad "发现公网隧道进程，确认是你自己开的：$PUB"
echo "提示：tailnet 里的设备能直接连本机 9222，必要时用 Tailscale ACL 只放行 8022；在公共 Wi-Fi 下请关掉「USB 调试」或重启手机；这台手机不要装银行和支付类 App。"
