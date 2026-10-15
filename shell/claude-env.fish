# >>> claude-setup 代理与防护环境（fish 版）>>>
# 来源: claude-setup repo (shell/claude-env.fish)
# 启用: cp 到 ~/.config/fish/conf.d/claude-setup.fish

# ── 代理开关 ──
function proxy_on --description "开启 mihomo 代理"
    set -gx http_proxy http://127.0.0.1:7890
    set -gx https_proxy http://127.0.0.1:7890
    set -gx HTTP_PROXY $http_proxy
    set -gx HTTPS_PROXY $https_proxy
    # ↓ 按需修改：公司内网域名/网段加进来
    set -gx no_proxy "localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    set -gx NO_PROXY $no_proxy
    echo "proxy on -> 127.0.0.1:7890"
end

function proxy_off --description "关闭代理"
    set -e http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
    echo "proxy off"
end

# 默认开启
proxy_on >/dev/null

# ── Claude Code 防护启动（覆盖 claude 命令）──
# TZ 按出口 IP 地区改；遥测总开关是官方合法选项
function claude --wraps claude --description "claude code with anti-ban env"
    env TZ=America/Los_Angeles LANG=en_US.UTF-8 \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1 \
        command claude $argv
end

# ── OAuth 登录专用浏览器 ──
function claude-browser --description "login-only browser (US exit + LA timezone)"
    env TZ=America/Los_Angeles LANG=en_US.UTF-8 \
        google-chrome \
        --user-data-dir="$HOME/.config/chrome-claude-profile" \
        --no-first-run --no-default-browser-check $argv >/dev/null 2>&1 &
    disown
end

# <<< claude-setup <<<
