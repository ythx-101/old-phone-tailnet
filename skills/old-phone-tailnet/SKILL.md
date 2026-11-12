---
name: old-phone-tailnet
description: 带用户把一台没有 root 的旧安卓手机接进自己的 Tailscale 私网：Termux + 用户态 Tailscale + 只认公钥的 SSH + 本机无线 ADB + Chrome 调试口（CDP）。用户说「把旧手机接进私网」「远程登录手机」「连手机上的 Chrome 调试口」「Termux 配 Tailscale」时使用。 Use when the user wants to connect an old non-rooted Android phone to Tailscale via Termux, SSH into it, or access its Chrome over CDP.
---

# 旧手机接进私网

目标：用户在电脑上能 `ssh` 进手机里的 Termux，并能通过 `localhost:9222` 用 CDP 访问手机上的 Chrome。全程不需要 root。

脚本都在本 skill 的 `scripts/` 目录。手机端脚本也可以在 Termux 里直接下载：
`curl -fsSLO https://raw.githubusercontent.com/ythx-101/old-phone-tailnet/main/skills/old-phone-tailnet/scripts/<脚本名>`

## 工作方式

- 在 SSH 打通之前，你碰不到手机。手机上的每一步都由用户在 Termux 里粘贴命令，所以每次只给一步：先用一两句话说明做什么、为什么，再给命令，然后等用户回「好了」或贴报错。
- SSH 打通以后（第 3 步之后），可以直接在电脑上通过 `ssh -p 8022 <手机>` 替用户执行手机端命令，但每条会改配置的命令先告诉用户。
- 报错时先解释原因，再给修复办法，不要让用户盲目重试。
- 任何会把端口暴露到公网、或者放宽安全设置的操作（公网隧道、开密码登录、关掉授权），先讲清风险，等用户同意。
- 不要让用户 root，也不要让用户装来路不明的 APK。Termux 只从 F-Droid 或官方 GitHub Releases 装。

## 步骤

### 0. 先确认三件事
- 手机系统是 Android 11 或更新（无线调试从 11 开始才有）。
- 电脑上已经装好 Tailscale 并登录。
- 用户有没有现成的 SSH 密钥（`~/.ssh/id_ed25519.pub`）。没有的话，在电脑上运行 `ssh-keygen -t ed25519`。

### 1. 装 Termux 和基础包
从 F-Droid 装 Termux（不要用 Play 商店的旧版）。打开后运行：
```
pkg update -y && pkg install -y openssh android-tools python curl
termux-wake-lock
```

### 2. 用户态 Tailscale
```
curl -fsSLO https://raw.githubusercontent.com/ythx-101/old-phone-tailnet/main/skills/old-phone-tailnet/scripts/install-tailscale.sh
bash install-tailscale.sh
mkdir -p ~/.ts
setsid nohup ~/bin/tailscaled --tun=userspace-networking --statedir=$HOME/.ts --socket=$HOME/.ts/tailscaled.sock --port=0 > ~/.ts/log 2>&1 < /dev/null &
~/bin/tailscale --socket=$HOME/.ts/tailscaled.sock up --hostname=old-phone
```
一定要带 `--hostname`：安卓的主机名是 `localhost`，不改的话节点会注册成这个名字，电脑上用机器名连会连回自己。
`up` 会打印一个登录链接，让用户在手机浏览器里打开，用和电脑同一个 Tailscale 账号登录。之后用 `~/bin/tailscale --socket=$HOME/.ts/tailscaled.sock ip -4` 拿到手机的 100.x 地址。
为什么用 userspace：它不占安卓唯一的 VPN 位，所以能和代理工具同时开。代价是手机自己的 App 不能主动访问私网里的其他机器，但别人连进手机没问题，我们要的正是这个。

### 3. SSH，只认公钥
在手机上：
```
passwd          # 临时设一个密码，只用来传公钥
sshd
whoami          # 记下用户名，比如 u0_a123
```
在电脑上：
```
ssh-copy-id -p 8022 <用户名>@<手机的 100.x 地址>
ssh -p 8022 <用户名>@<手机的 100.x 地址>     # 确认不再要密码
```
Windows 自带的 OpenSSH 没有 `ssh-copy-id`，在 PowerShell 里用：
```
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh -p 8022 <用户名>@<手机的 100.x 地址> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```
确认公钥能登录以后，在手机上关掉密码登录：
```
curl -fsSLO https://raw.githubusercontent.com/ythx-101/old-phone-tailnet/main/skills/old-phone-tailnet/scripts/harden-ssh.sh
bash harden-ssh.sh
```
（脚本先检查 `authorized_keys` 不是空的，改完配置用 `sshd -t` 校验，再用 HUP 重新加载，不会断开当前会话。）

### 4. 手机的 adb 连回自己
1. 设置 → 关于手机 → 连点「版本号」7 次，打开开发者选项。
2. 开发者选项 → 打开「USB 调试」和「无线调试」。手机要连着 Wi-Fi。
3. 进入「无线调试」→「使用配对码配对设备」。这个弹窗一切走就会关，所以让用户用分屏，把 Termux 和设置并排放。
4. 在 Termux 里：
```
adb pair <IP>:<配对端口> <六位配对码>
adb connect <IP>:<无线调试页面上的端口>
adb -s <IP>:<无线调试页面上的端口> tcpip 5555
adb connect 127.0.0.1:5555
adb devices      # 应该看到 127.0.0.1:5555  device
```
手机上如果弹出「允许 USB 调试吗」，让用户点允许并勾选「始终允许」。

然后解除后台进程限制。Android 12 起，系统会杀掉 Termux 在后台起的子进程，tailscaled 和守护循环会莫名其妙消失，光改电池设置不够：
- Android 14 及以上：开发者选项 → 打开「停用子进程限制」（Disable child process restrictions）。
- Android 12、13：在 Termux 里运行
```
adb -s 127.0.0.1:5555 shell device_config set_sync_disabled_for_tests persistent
adb -s 127.0.0.1:5555 shell device_config put activity_manager max_phantom_processes 2147483647
```

### 5. 转出 Chrome 调试口
先在手机上打开一次 Chrome。然后在 Termux 里：
```
adb -s 127.0.0.1:5555 forward tcp:9222 localabstract:chrome_devtools_remote
curl -s http://127.0.0.1:9222/json/version
```
在电脑上（或用 `scripts/pc-connect.sh <手机地址>`）：
```
ssh -p 8022 -N -L 9222:localhost:9222 <用户名>@<手机的 100.x 地址>
```
另开一个终端运行 `curl http://localhost:9222/json`，能看到 Chrome 的标签页列表就成功了。之后 Playwright 可以用 `chromium.connectOverCDP("http://localhost:9222")` 连上，Puppeteer 用 `puppeteer.connect({browserURL: "http://localhost:9222"})`。

### 6. 一键脚本
```
curl -fsSLO https://raw.githubusercontent.com/ythx-101/old-phone-tailnet/main/skills/old-phone-tailnet/scripts/start.sh
bash start.sh
```
`start.sh` 会依次拉起唤醒锁、sshd 和 Tailscale，再起一个守护循环：每 30 秒检查一次 adb，掉线时用 `adb mdns services` 找到新的无线调试端口重连，并重新转发 9222。
重启手机以后，「无线调试」会自动关掉。让用户重新打开它，然后运行 `bash start.sh <IP>:<端口>`。
想开机就自动运行，可以装 F-Droid 上的 Termux:Boot，装好后先打开一次 Termux:Boot，再运行 `mkdir -p ~/.termux/boot && cp start.sh ~/.termux/boot/ && chmod +x ~/.termux/boot/start.sh`。

### 7. 关掉省电限制
设置 → 应用 → Termux 和 Chrome → 电池 → 选「不受限制」。不改的话，手机进入深度休眠后会切断 Chrome 的网络，看起来像卡死，SSH 也会时断时续。

### 8. 自检和安全收尾
```
curl -fsSLO https://raw.githubusercontent.com/ythx-101/old-phone-tailnet/main/skills/old-phone-tailnet/scripts/check.sh
bash check.sh
```
逐项确认：
- SSH 只认公钥，`authorized_keys` 里的每一把公钥用户都认识。
- 只走 Tailscale，不开任何公网隧道。
- **Tailscale 访问控制**：用户态 tailscaled 会把发到手机 100.x 地址的连接转给手机本机的 127.0.0.1。所以 tailnet 里的任何设备，不用 SSH 也能直接连 `100.x:9222` 操作 Chrome，还能连 `100.x:5555` 的 adb（adb 仍要授权）。tailnet 里只有用户自己的设备、而且没把手机共享给别人时，风险可控；有别人的设备时，一定要在 Tailscale 后台的 Access controls 里只放行 8022，让 9222 只能经 SSH 转发访问（示例见下）。
- `adb tcpip 5555` 让 adbd 在 Wi-Fi 网卡上监听 5555，只关「无线调试」不一定能关掉它。在公共 Wi-Fi 下要关掉「USB 调试」，或者重启手机。
- 这台手机不装银行和支付类 App。

ACL 示例。顺序：先把下面的策略保存（`tagOwners` 里有了 `tag:phone`，后台才能打这个标签），再到 Machines 页面给手机加上 `tag:phone`。邮箱换成用户自己的登录身份（用 GitHub 登录的写 `用户名@github`）：
```json
{
  "tagOwners": { "tag:phone": ["autogroup:admin"] },
  "acls": [
    { "action": "accept", "src": ["you@example.com"], "dst": ["tag:phone:8022"] },
    { "action": "accept", "src": ["autogroup:member"], "dst": ["autogroup:self:*"] }
  ]
}
```
放行规则是取并集，所以要把默认的「全部互通」规则删掉：`acls` 里 `"dst": ["*:*"]` 那条，以及较新 tailnet 里写在 `grants` 下 `"ip": ["*"]` 那条，都要删；其他自己加过的放行规则照旧保留。改完在另一台设备上运行 `nc -zv <手机的 100.x 地址> 9222`，连不上才算生效，8022 应该仍然能连。

最后提醒用户：能 SSH 进来的人，也能通过 adb 和 Chrome 调试口操作这台手机和手机上已经登录的网页。所以私钥要保管好，最好用一台专门的旧手机。

## 常见问题
- `tailscale up` 一直没反应：先看 `~/.ts/log`。最常见的原因是 tailscaled 没起来，或者手机网络访问不到 Tailscale 的控制服务器。
- `adb pair` 失败：配对码 60 秒左右就会过期，而且配对窗口必须一直开着。重新点「使用配对码配对设备」再试。
- `adb devices` 显示 `unauthorized`：手机上没点允许。撤销 USB 调试授权，再连一次。
- 9222 有时连得上、有时连不上：Chrome 被系统冻结了。把 Chrome 的电池用量改成「不受限制」，再把它切到前台一次。
- tailscaled 或守护循环过一会儿就没了：多半是后台子进程被系统杀了，回到第 4 步末尾解除限制。
- 电脑 ssh 超时：先确认两边都在线，在电脑上运行 `tailscale ping <手机地址>`。
