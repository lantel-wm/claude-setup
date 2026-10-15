# OAuth 登录指南

Claude Code 首次运行需要浏览器完成 OAuth 授权。登录会话的
**IP、时区、语言**必须与之后的日常 API 使用完全一致，否则登录本身就是风控信号。

## 方案 A：本机 GUI 浏览器（推荐，WSL2/Linux 桌面）

用 `claude-browser`（见 shell/claude-env.sh / claude-env.fish）：独立 Chrome profile +
`TZ` 注入 + 继承 mihomo 代理。浏览器 JS 上报的时区/语言与出口 IP 天然一致。

```bash
# 终端 1
claude            # 选登录方式，复制授权 URL

# 终端 2
claude-browser    # 弹出 Chrome 窗口
# 地址栏粘贴授权 URL → 登录 → 授权 → 回调自动完成
```

依赖安装（Ubuntu/Debian）：

```bash
curl -L -o /tmp/google-chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo apt install -y /tmp/google-chrome.deb fonts-noto-cjk
```

WSL2 需要 WSLg（`echo $DISPLAY` 有值即可）。

验证浏览器人设（headless 自查）：

```bash
TZ=America/Los_Angeles google-chrome --headless=new --no-sandbox \
  --user-data-dir=/tmp/c \
  --dump-dom 'data:text/html,<script>document.write(Intl.DateTimeFormat().resolvedOptions().timeZone + " | " + navigator.language)</script>'
# 期望: America/Los_Angeles | en-US（按你的出口地区调整）
```

## 方案 B：无 GUI 服务器

两种做法：

1. **凭证拷贝**（简单）：在有 GUI 的机器上完成登录，把
   `~/.claude/.credentials.json` 拷到服务器同路径（`chmod 600`）。
   凭证与设备绑定不严格，跨机器可用
2. **手动 code 流程**：服务器跑 `claude`，选手动授权方式，把 URL 贴到
   任意设备的浏览器完成。注意那台浏览器同样要满足"人设一致"要求

## 方案 C：Windows 宿主机浏览器（WSL2 备选）

如果不想在 WSL 里装浏览器，登录前在 Windows 上临时做三件事：

1. Windows VPN 切到与 mihomo 出口同国家的节点
2. Windows 时区临时改为出口地区时区（如太平洋时间），改完重启浏览器
3. 用无痕窗口完成授权

登录完成后 Windows 时区改回来即可（之后不再用网页版）。

## 登录后

- 凭证在 `~/.claude/.credentials.json`：不外传、不进 git
- `claude` 里跑 `/status` 确认账号
- 登录专用浏览器 profile 只用于 Claude，不混日常浏览

## 反面清单（登录时不要做的事）

- ❌ 用手机流量/手机代理打开授权链接（出口不一致）
- ❌ 用日常浏览器（cookie/指纹混杂）
- ❌ 登录时挂着与出口地区不同的 VPN
- ❌ 时区没改就登录（浏览器 JS 上报 Asia/Shanghai + 美国 IP = 明牌）
