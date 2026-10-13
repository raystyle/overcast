#!/usr/bin/env bash
# overcast 网关鉴权开关(2026-10-13 用户裁定:内网免鉴权,可随时切回)
# 语义源:CLIProxyAPI 零 access provider 即放行(sdk/access/manager.go len(providers)==0 -> allow),
# 故 access.api-keys 条目全注释/置空 = 关鉴权,任意 token 与无 Authorization 头均可;有条目 = 开鉴权。
# 用法:auth-toggle.sh on|off|status
#   on  :恢复 api-keys 条目,重启容器,探活预期 401(垃圾 token)
#   off :注释 api-keys 条目,重启容器,探活预期 200(垃圾 token)
#   status:报配置态(条目数,不显 key 值)与运行态(探活码)
# 纪律:不打印任何 key 明文;改后保持 config 0600。
set -euo pipefail

CFG="${OVERCAST_CONFIG:-$HOME/overcast/config.yaml}"
CONTAINER="${OVERCAST_CONTAINER:-overcast}"
PROBE_URL="http://127.0.0.1:8317/v1/models"

die() { echo "错误:$1" >&2; exit 1; }

[ -f "$CFG" ] || die "config 不存在:$CFG"

# 仅操作 access: 块内的条目行;on/off 用 # auth-off 前缀标记,幂等,不碰其他注释
toggle() {
  awk -v mode="$1" '
    /^access:/ {inaccess=1}
    inaccess && /^[^ ]/ && !/^access:/ {inaccess=0}
    inaccess {
      if (mode=="off" && /^    - "/) { print "    # auth-off " substr($0, 5); next }
      if (mode=="on" && /^    # auth-off - "/) { sub(/^    # auth-off /, "    "); print; next }
    }
    { print }
  ' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  chmod 600 "$CFG"
}

active_keys() { awk '/^access:/{f=1} f&&/^[^ ]/&&!/^access:/{f=0} f&&/^    - "/{n++} END{print n+0}' "$CFG"; }

# 探活带重试:容器冷启动有数秒不监听窗,curl 连接拒绝(退出码 7)须重试而非即败
probe() {
  local code=000 i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$PROBE_URL" -H 'Authorization: Bearer auth-toggle-probe') || true
    [ "$code" != 000 ] && [ "$code" != 502 ] && [ "$code" != 503 ] && break
    sleep 3
  done
  echo "$code"
}

case "${1:-}" in
  on|off)
    toggle "$1"
    docker restart "$CONTAINER" >/dev/null
    sleep 4
    code="$(probe)"
    want=$([ "$1" = on ] && echo 401 || echo 200)
    [ "$code" = "$want" ] \
      && echo "PASS:鉴权 $1,探活 $code(条目数 $(active_keys))" \
      || die "切换后探活 $code 与预期 $want 不符,查容器日志:docker logs $CONTAINER"
    ;;
  status)
    n="$(active_keys)"
    cfg=$([ "$n" -gt 0 ] && echo "on($n 把 key)" || echo "off(零条目)")
    echo "配置态:$cfg;运行态探活:$(probe)($([ "$n" -gt 0 ] && echo '预期 401' || echo '预期 200'))"
    ;;
  *)
    die "用法:$0 on|off|status"
    ;;
esac
