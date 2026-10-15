# 分步搭建指南

从零搭建 Claude Code 防封环境。适用于中国大陆 Linux / WSL2。
（如果你在海外服务器上，跳过全部代理步骤，只做第 6、7 步并按当地时区设 TZ。）

## 第 0 步：节点选择决策（最重要，先想清楚再动手）

选定一个节点后**永久锁定**，所以一开始就要选对：

1. **地区**：优先美国；日本也可以。关键是和账号注册/付款时的浏览器出口同国家。
   记不清注册时的地区 → 查 claude.ai 账单，或默认选美国
2. **节点类型**：
   - 有静态住宅/ISP 代理最好（风险最低）
   - 机场节点可用：选一个延迟稳定、丢包低的支持地区节点，手动固定
   - 避免：免费 VPN、公共代理池、自动测速轮换
3. **拿到节点参数**：Clash 订阅链接（问机场要 clash 格式）、或 ss/vless/vmess/trojan 手动参数

## 第 1 步：安装 mihomo

```bash
cd mihomo
./install.sh
```

脚本做四件事：装二进制到 `~/.local/bin`（免 sudo）、下 GeoIP 库、
部署 systemd 用户服务、复制配置模板。

## 第 2 步：填配置

```bash
vim ~/.config/mihomo/config.yaml
```

按文件内注释操作：
- 有 Clash 订阅 → 用 `proxy-providers` 方式（方式 B）
- 手动节点参数 → 填方式 A 的模板，删掉不用的协议段
- 有公司内网域名 → 加进 `fake-ip-filter` + `nameserver-policy` + DIRECT 规则
  （漏了这步内网服务会莫名连不上，这是个高频坑）

```bash
systemctl --user restart mihomo
```

## 第 3 步：验证出口

```bash
curl -x http://127.0.0.1:7890 https://ipinfo.io   # 应显示你选定的地区
curl -x http://127.0.0.1:7890 -o /dev/null -w "%{http_code}\n" https://api.anthropic.com/api/hello
# 期望 200；claude.ai 对 curl 返回 403 是 Cloudflare 拦 curl 指纹，属正常，浏览器没事
```

锁定节点（假设节点名叫 `us-01`）：

```bash
curl -X PUT http://127.0.0.1:9090/proxies/Claude -d '{"name":"us-01"}'
```

`store-selected: true` 会记住选择。也可以直接把节点名写在配置里 Claude 组的第一位。

## 第 4 步：Shell 环境

bash / zsh（加一行 source，或直接把文件内容拷进 rc 文件）：

```bash
echo "source $(pwd)/shell/claude-env.sh" >> ~/.bashrc   # bash
echo "source $(pwd)/shell/claude-env.sh" >> ~/.zshrc    # zsh
```

fish：

```bash
cp shell/claude-env.fish ~/.config/fish/conf.d/claude-setup.fish
```

然后重开终端或 `exec $SHELL`，确认：

```bash
proxy_on    # 输出 proxy on -> 127.0.0.1:7890
type claude # 应显示 TZ= 注入的完整命令（bash/zsh 为 alias，fish 为函数）
```

检查冲突：rc 文件里若有别的代理管理钩子（企业代理脚本等），删掉避免互相覆盖。

## 第 5 步：检查泄露面

```bash
# 时区与出口一致性（关键检查）
date +%Z                          # 应与出口地区一致（claude 进程内由 alias 保证）
curl -x http://127.0.0.1:7890 https://ipinfo.io | grep timezone
# IPv6（应为 0）
ip -6 addr show scope global | grep -c inet6
# 无中转残留
env | grep -i anthropic           # 应为空
```

## 第 6 步：安装 Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash   # 推荐：官方脚本，装到 ~/.local/bin
# 或 npm install -g @anthropic-ai/claude-code（需要 Node 18+，建议 20+）
claude --version
```

确认 alias 生效（`type claude` 应显示 TZ= 注入的完整命令）。

## 第 7 步：OAuth 登录

见 [login-guide.md](login-guide.md)。

## 第 8 步：登录后自检

```bash
claude
# 进入后：
/status     # 确认账号类型（Pro）和登录身份
```

## 日常运维

```bash
systemctl --user status mihomo     # 代理服务状态
journalctl --user -u mihomo -f     # 实时日志（排查节点故障）
proxy_off                          # 临时直连（排查问题时用，用完记得 proxy_on）
```

节点故障只能手动切到备用节点，切完固定住。**绝不让 Claude 组自动测速。**
