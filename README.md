# Claude Code 防封号环境配置

在中国大陆网络环境使用官方 Claude 订阅（Pro/Max）跑 Claude Code 的完整防封方案。
基于社区对 Claude Code 的逆向分析（v2.1.280 审计）和实测验证整理。

> **免责声明**：Anthropic 官方不支持中国大陆地区，本方案只能降低风控触发概率，无法保证不封号。账号天然处于高风险状态，请勿在账号里存放不可替代的数据。

## 核心原则（按重要性排序）

1. **出口固定**：所有 Claude 流量永远走同一个节点、同一个 IP。选一个 Anthropic 支持地区（推荐美国）的节点后锁死，绝不更换、绝不自动测速
2. **时区一致**：Claude 相关进程注入 `TZ` 与出口 IP 所在地一致（如洛杉矶 → `America/Los_Angeles`）。Claude Code 的 Node Intl 和登录浏览器的 JS 都会上报时区
3. **官方直连**：绝不使用中转/镜像（`ANTHROPIC_BASE_URL` 必须不设置）。中转域名是逆向确认的高危标记
4. **遥测最小化**：`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`（官方合法开关）
5. **单安装单账号**：`~/.claude.json` 里的 device_id 会跨账号关联（连坐机制）。被封换号前必须删除 `~/.claude` 和 `~/.claude.json`

## 目录结构

```
├── README.md                 # 本文件
├── mihomo/
│   ├── install.sh            # 一键安装 mihomo + systemd 用户服务（无需 sudo）
│   ├── config.template.yaml  # 通用配置模板（占位符，适配任意代理订阅）
│   └── mihomo.service        # systemd 用户服务单元
├── shell/
│   └── zshrc.snippet         # 代理开关 + claude 防护 alias + 登录浏览器
└── docs/
    ├── risk-model.md         # 风控机制与逆向发现（为什么这么配）
    ├── setup-guide.md        # 分步搭建指南（含节点选择决策）
    └── login-guide.md        # OAuth 登录流程与浏览器人设
```

## 快速开始

```bash
cd mihomo && ./install.sh          # 安装 mihomo（二进制装到 ~/.local/bin，免 sudo）
cp config.template.yaml ~/.config/mihomo/config.yaml
vim ~/.config/mihomo/config.yaml   # 填入你自己的节点信息（见文件内注释）
systemctl --user restart mihomo

# 把 shell/zshrc.snippet 的内容追加到 ~/.zshrc，然后：
npm 或官方脚本安装 claude code
claude                              # alias 自动注入防护环境变量
```

详细步骤和决策点见 [docs/setup-guide.md](docs/setup-guide.md)。

## 你的代理需要满足什么

本方案不绑定任何代理服务商。你的代理需要满足：

| 要求 | 说明 |
|---|---|
| 出口在 Anthropic 支持地区 | 推荐美国；日本也可（与账号注册地区一致即可） |
| **能锁定单个固定节点** | 机场用户：选一个节点手动固定，别用自动测速 |
| IP 类型 | 住宅/ISP 最好；机房 IP 可用但风险更高；免费/公共 VPN 基本必死 |
| 支持转成 mihomo 配置 | Clash 订阅链接、或手动 ss/vless/vmess/trojan 节点信息均可 |

## 使用纪律（背下来）

1. 节点永远不换、不跳地区
2. 一个安装只登一个账号；被封后先删 `~/.claude` + `~/.claude.json` 再换号
3. 重要代码随时 push 到远端 git
4. 收到 KYC 验证邮件尽快处理
5. 别让任何工具设置 `ANTHROPIC_BASE_URL` / `OTEL_*` 环境变量
6. 登录专用浏览器只用于 Claude，不混用日常浏览

## 残余风险（无法消除，要有预期）

- 机房 IP：多数国内可用代理是机房 IP，风控严查 IP 类型时无解
- 活跃时段：北京时间白天 = 美国深夜，服务端时间戳无法伪装（弱信号）
- 账号历史：注册/付款时的出口地区与当前不一致，存在历史跳变
- KYC：可能被要求身份验证，需与账号地区匹配的证件

详见 [docs/risk-model.md](docs/risk-model.md)。
