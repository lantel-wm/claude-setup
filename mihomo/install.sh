#!/usr/bin/env bash
# mihomo 一键安装脚本（Claude Code 防封方案）
#
# 功能：
#   1. 下载 mihomo 二进制到 ~/.local/bin（免 sudo）
#   2. 下载 GeoIP 数据库（GEOIP,CN 规则需要）
#   3. 安装 systemd 用户服务并设为自启
#   4. 部署配置模板（已存在则跳过，不覆盖你的节点配置）
#
# 用法：
#   ./install.sh
#   MIHOMO_VERSION=v1.19.33 ./install.sh    # 指定版本
#
# 注意：GitHub 直连失败时，先设置代理再跑本脚本：
#   export https_proxy=http://127.0.0.1:7890

set -euo pipefail

MIHOMO_VERSION="${MIHOMO_VERSION:-v1.19.32}"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/mihomo"
SERVICE_DIR="$HOME/.config/systemd/user"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 架构判断 ──
case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *) echo "不支持的架构: $(uname -m)"; exit 1 ;;
esac

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "本脚本仅支持 Linux（WSL2 原生 Linux 同样适用）"; exit 1
fi

echo "==> mihomo ${MIHOMO_VERSION} linux-${ARCH}"

# ── 1. 下载二进制 ──
mkdir -p "$BIN_DIR" "$CONF_DIR" "$SERVICE_DIR"
if [[ -x "$BIN_DIR/mihomo" ]] && "$BIN_DIR/mihomo" -v 2>/dev/null | grep -q "$MIHOMO_VERSION"; then
  echo "==> mihomo 已是 ${MIHOMO_VERSION}，跳过下载"
else
  url="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${ARCH}-${MIHOMO_VERSION}.gz"
  echo "==> 下载 $url"
  curl -fSL -o /tmp/mihomo.gz "$url"
  gunzip -f /tmp/mihomo.gz
  chmod +x /tmp/mihomo
  mv /tmp/mihomo "$BIN_DIR/mihomo"
fi
"$BIN_DIR/mihomo" -v | head -1

# ── 2. GeoIP 数据库 ──
if [[ ! -s "$CONF_DIR/geoip.metadb" ]]; then
  echo "==> 下载 GeoIP 数据库"
  curl -fSL -o "$CONF_DIR/geoip.metadb" \
    "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb"
else
  echo "==> GeoIP 数据库已存在，跳过"
fi

# ── 3. 配置模板 ──
if [[ ! -f "$CONF_DIR/config.yaml" ]]; then
  cp "$REPO_DIR/config.template.yaml" "$CONF_DIR/config.yaml"
  echo "==> 已部署配置模板到 $CONF_DIR/config.yaml"
  echo "    ★ 接下来必须编辑它：填入你的节点信息（搜 {{ 占位符 }}）"
else
  echo "==> $CONF_DIR/config.yaml 已存在，不覆盖"
fi

# ── 4. systemd 用户服务 ──
cat > "$SERVICE_DIR/mihomo.service" << EOF
[Unit]
Description=mihomo Proxy Daemon
After=network.target

[Service]
Type=simple
ExecStart=$BIN_DIR/mihomo -d $CONF_DIR
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now mihomo.service
sleep 2
systemctl --user --no-pager status mihomo.service | head -4

cat << 'EOF'

==> 完成。下一步：
  1. 编辑 ~/.config/mihomo/config.yaml 填入节点（若刚部署模板）
  2. systemctl --user restart mihomo
  3. 验证出口：curl -x http://127.0.0.1:7890 https://ipinfo.io
     （应显示你选定的支持地区 IP）
  4. 把 shell/zshrc.snippet 追加到 ~/.zshrc
EOF
