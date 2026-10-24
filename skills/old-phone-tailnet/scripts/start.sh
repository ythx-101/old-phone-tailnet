#!/data/data/com.termux/files/usr/bin/bash
# 一键拉起：唤醒锁 + sshd + 用户态 Tailscale + adb 掉线重连 + Chrome 调试口转发
# 用法：bash start.sh            （日常）
#      bash start.sh IP:端口     （重启手机后第一次：传入「无线调试」页面显示的 IP 和端口）
TS_DIR=$HOME/.ts
SOCK=$TS_DIR/tailscaled.sock
CDP_PORT=${CDP_PORT:-9222}

termux-wake-lock 2>/dev/null

# 1. sshd（Termux 默认端口 8022）
pgrep -x sshd >/dev/null || sshd

# 2. 用户态 Tailscale：不占安卓的 VPN 位
mkdir -p "$TS_DIR"
if ! ~/bin/tailscale --socket="$SOCK" status >/dev/null 2>&1; then
  setsid nohup ~/bin/tailscaled --tun=userspace-networking --statedir="$TS_DIR" \
    --socket="$SOCK" --port=0 >"$TS_DIR/log" 2>&1 </dev/null &
  sleep 3
fi

# 3. 可选：重启后第一次，先连上无线调试端口，再把 adb 固定到 5555
if [ -n "$1" ]; then
  adb connect "$1" && adb -s "$1" tcpip 5555 && sleep 3
fi

# 4. 守护循环：每 30 秒检查 adb，掉线就用 mDNS 找无线调试端口重连，并重新转发 Chrome 调试口
pkill -f "opt_adb_keeper[.]sh" 2>/dev/null
cat > "$PREFIX/tmp/opt_adb_keeper.sh" <<KEEP
while true; do
  if ! adb devices | grep -q '127.0.0.1:5555[[:space:]]*device'; then
    P=\$(adb mdns services 2>/dev/null | grep -m1 _adb-tls-connect | grep -o '[0-9.]*:[0-9]*\$')
    [ -n "\$P" ] && adb connect "\$P" >/dev/null 2>&1 && adb -s "\$P" tcpip 5555 >/dev/null 2>&1 && sleep 3
    adb connect 127.0.0.1:5555 >/dev/null 2>&1
  fi
  adb -s 127.0.0.1:5555 forward tcp:$CDP_PORT localabstract:chrome_devtools_remote >/dev/null 2>&1
  sleep 30
done
KEEP
setsid nohup bash "$PREFIX/tmp/opt_adb_keeper.sh" >/dev/null 2>&1 </dev/null &

sleep 2
echo "Tailscale 地址：$(~/bin/tailscale --socket="$SOCK" ip -4 2>/dev/null || echo '还没登录，运行 ~/bin/tailscale --socket='"$SOCK"' up --hostname=old-phone')"
adb devices
echo "好了，Termux 可以切到后台。"
