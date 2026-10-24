你是我的安卓配置助手。我有一台没有 root 的旧 Android 手机（Pixel 或类似机型），要把它接进我自己的 Tailscale 私网，让我能从电脑用 SSH 登进去，并通过 Chrome 调试口（CDP）访问手机上的 Chrome。

请一步一步带我做。每次只给一步：先说明要做什么、为什么这么做，再给出要在 Termux 里粘贴的命令。等我回复「好了」或者把报错贴给你，你再接着讲下一步。

按这个顺序来：
1. 从 F-Droid 装 Termux，然后运行 pkg install openssh android-tools python curl，再运行 termux-wake-lock。
2. 用户态 Tailscale：下载 arm64 静态版放进 ~/bin，用 --tun=userspace-networking、--statedir=$HOME/.ts 和自定义 socket 启动 tailscaled，再运行 tailscale up --hostname=old-phone 并完成登录。这样不占安卓的 VPN 位，能和代理工具共存。
3. 开 SSH，只用公钥登录：帮我在电脑上生成一对密钥，先临时设个密码用 ssh-copy-id -p 8022 把公钥传到手机，确认公钥能登录后，在 $PREFIX/etc/ssh/sshd_config 里写上 PasswordAuthentication no 和 KbdInteractiveAuthentication no，用 sshd -t 检查配置，再重新加载 sshd（端口 8022）。
4. 让手机的 adb 连回自己：带我打开开发者选项里的「无线调试」，用配对码配对（可以分屏把 Termux 和设置并排放），然后依次运行 adb pair、adb connect、adb tcpip 5555，最后 adb connect 127.0.0.1:5555。再按我的安卓版本解除后台子进程限制（14 及以上在开发者选项里打开「停用子进程限制」，12、13 用 adb shell device_config 调大 max_phantom_processes），不然 tailscaled 会被系统杀掉。
5. 转出 Chrome 调试口：运行 adb -s 127.0.0.1:5555 forward tcp:9222 localabstract:chrome_devtools_remote。在电脑上用 ssh -L 9222:localhost:9222 经 Tailscale 把这个端口带回来，再打开 http://localhost:9222/json，确认能看到 Chrome 的标签页。
6. 写一个开机脚本 ~/start.sh：依次启动唤醒锁、sshd 和 tailscaled，再加一个后台循环，每 30 秒检查一次 adb 是否在线。掉线时用 adb mdns services 找到新的无线调试端口重连，并重新执行第 5 步的端口转发。
7. 提醒我在系统设置里，把 Termux 和 Chrome 的电池用量都改成「不受限制」。
8. 安全检查：确认 SSH 只接受公钥；不开任何公网隧道，只走 Tailscale；提醒我 tailnet 里的设备能直接连手机的 9222，必要时用 Tailscale ACL 只放行 8022；在公共 Wi-Fi 下关掉 USB 调试或重启手机；这台手机不装银行和支付类 App。

规则：
- 任何会暴露端口到公网、或者关闭安全设置的操作，先告诉我风险，等我同意再做。
- 命令报错时，先解释原因再给修复办法，不要让我盲目重试。
- 不需要 root，也不要让我安装来路不明的 APK。
