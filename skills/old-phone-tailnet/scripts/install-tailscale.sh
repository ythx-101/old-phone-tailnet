#!/data/data/com.termux/files/usr/bin/bash
# 在 Termux 里安装 Tailscale 官方静态版（arm64 / arm / amd64，自动识别），放进 ~/bin
set -e
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) TA=arm64 ;;
  armv7l|armv8l) TA=arm ;;
  x86_64) TA=amd64 ;;
  *) echo "不支持的架构：$ARCH"; exit 1 ;;
esac
command -v curl >/dev/null || pkg install -y curl
VER=$(curl -fsSL "https://pkgs.tailscale.com/stable/?mode=json" | grep -o '"TarballsVersion": *"[^"]*"' | grep -o '[0-9][0-9.]*')
[ -n "$VER" ] || { echo "拿不到 Tailscale 最新版本号，检查网络"; exit 1; }
echo "下载 tailscale $VER ($TA) ..."
cd "${TMPDIR:-$PREFIX/tmp}"
curl -fL -o ts.tgz "https://pkgs.tailscale.com/stable/tailscale_${VER}_${TA}.tgz"
tar xzf ts.tgz
mkdir -p ~/bin ~/.ts
cp "tailscale_${VER}_${TA}/tailscale" "tailscale_${VER}_${TA}/tailscaled" ~/bin/
chmod +x ~/bin/tailscale ~/bin/tailscaled
rm -rf ts.tgz "tailscale_${VER}_${TA}"
echo "装好了：$(~/bin/tailscale version | head -1)"
