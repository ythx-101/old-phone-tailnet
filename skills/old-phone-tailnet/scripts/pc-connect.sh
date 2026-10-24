#!/usr/bin/env bash
# 电脑端：经 Tailscale 登进手机，并把手机的 Chrome 调试口带到本机
# 用法：bash pc-connect.sh <手机的 Tailscale IP 或机器名> [私钥路径]
set -e
HOST=${1:?用法：bash pc-connect.sh <手机的 Tailscale IP 或机器名> [私钥路径]}
KEY=${2:-$HOME/.ssh/id_ed25519}
PORT=${CDP_PORT:-9222}
echo "转发 localhost:$PORT -> 手机 Chrome。保持这个窗口开着，另开一个终端运行："
echo "  curl http://localhost:$PORT/json"
exec ssh -i "$KEY" -p 8022 -N -L "$PORT:localhost:$PORT" -o ServerAliveInterval=30 "$HOST"
