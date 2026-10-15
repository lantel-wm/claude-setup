# 风控机制与逆向发现

> 本文解释"为什么这么配"。技术细节来自社区对 Claude Code 的逆向分析，
> 主要来源见文末。结论按可信度标注。

## 一、Anthropic 封号的判定维度

| 维度 | 说明 | 官方是否明说 |
|---|---|---|
| **地区** | 出口 IP 所在国家不在支持列表（中国大陆/香港/澳门均不在） | ✅ 唯一官方明说的触发条件 |
| **IP 类型** | 住宅 ≫ 机房；共享/免费 VPN、代理池高危 | ❌ 未明说，但社区案例高度一致 |
| **IP 稳定性** | 出口频繁跳动、注册地与常用地不一致 | ❌ 未明说 |
| **支付** | 虚拟卡/代充/异常卡段；账单地区与 IP 不一致 | ❌ 未明说 |
| **设备指纹** | device_id 跨账号关联（连坐） | 部分（"共享账号"是官方封禁理由） |
| **行为** | 高并发轰炸、批量注册特征 | 部分（"滥用"） |

## 二、Claude Code 实际采集了什么（v2.1.280 逆向审计，可信度高）

### 确认采集
- `device_id`：`~/.claude.json` 的 userID，**加密随机数生成，非硬件**，但持久存在
- `machineID`：随机字节，用于错误报告关联
- 账户/组织 UUID（登录后部分事件携带）
- **Git HEAD SHA**（部分事件携带，可定位具体仓库）
- `additional_metadata`：Base64 JSON（提示词长度、耗时、hook、模型提供商）
- 主机名（OTel 探测器、远程控制设备名）
- 事件系统规模：代码内 1,700+ 种事件名、2,600+ 调用点

### 确认不采集（审计者专门验证过）
- ❌ MAC 地址、机身序列号（JS 层未发现读取调用）
- ❌ 默认遥测不发送完整提示词、源码正文、原始 bash 命令
- ❌ 截屏/录音原生扩展存在，但无后台自动录制上传的证据

### 条件性采集（默认关闭）
- OpenTelemetry 组件会读 Linux `/etc/machine-id`（macOS 为 IOPlatformUUID），
  但仅在启用 OTLP 导出时发送 → **别设置任何 `OTEL_*` 环境变量**
- `OTEL_LOG_USER_PROMPTS` / `OTEL_LOG_RAW_API_BODIES` 可记录提示词原文，默认关

## 三、时区隐写事件（v2.1.91 ~ 2.1.196，已移除）

2026 年 6 月被逆向发现（thereallo.dev，有完整反混淆代码）：

```
Today's date is 2026-06-30.
     ↑                ↑
  4 种撇号 Unicode     中国时区时 - 变 /
  （标记 API 网关类型）  （标记 Asia/Shanghai）
```

- 触发条件：`ANTHROPIC_BASE_URL` 被设置（指向中转/镜像时激活）
- 名单：XOR+Base64 混淆的域名表（国内企业域名 + 中转站域名）和关键词表
  （deepseek/moonshot/zhipu 等）
- **v2.1.201 起移除**，v2.1.280 复核确认日期行为固定格式

对本方案的启示：即使已移除，`ANTHROPIC_BASE_URL` 不设置依然是铁律——
中转本身就是高危信号，且无法保证未来版本不再引入类似机制。

## 四、官方遥测开关（合法、文档记载）

```bash
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1   # 总开关：指标+错误报告+功能标志检查
DISABLE_TELEMETRY=1                           # 仅关使用指标
DISABLE_ERROR_REPORTING=1                     # 仅关错误报告
CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1  # 关插件市场自动安装
```

注意：总开关不影响 WebFetch 域名预检（有独立设置 `skipWebFetchPreflight`）。

## 五、残余风险（本方案无法消除）

1. **机房 IP**：国内可用的代理多为机房 IP。风控若严查 IP 类型，无解。
   升级路线：静态住宅 IP（与账号地区一致）
2. **活跃时段**：北京时间白天 = 美国深夜。服务端时间戳，无法伪装。
   "夜猫子程序员"在洛杉矶也正常，属弱信号
3. **账号历史地区**：注册/付款时的出口与当前不一致，存在历史跳变记录
4. **KYC**：可能被要求身份验证，需与账号地区匹配的证件
5. **模型请求内容本身**：对话、代码上下文必然发往 Anthropic 服务器（产品功能）

## 参考资料

- thereallo.dev — Claude Code prompt steganography 逆向（一手代码分析）
- blog.silencestar.com — Claude Code 遥测审计（v2.1.280，含方法与哈希，最严谨）
- Anthropic 官方文档 — Data usage / Network config（遥测开关与出站域名）
- 社区经验帖（LINUX DO 等）— 多账号实测，IP/支付两因素结论
