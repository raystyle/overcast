#!/usr/bin/env bash
# DeepSeek API key 录入(REQ-003):弹 GUI 隐藏输入框,值不回显、不入 transcript,
# 落 0600 临时件供渲染进 ~/overcast/config.yaml,渲染完成即删(一次性投递纪律)。
# 用法:ds-token-entry.sh [输出文件]   重跑覆盖旧值。
set -euo pipefail

OUT="${1:-$HOME/overcast/.dskey-entry}"

ANS=$(osascript -e 'text returned of (display dialog "录入 DeepSeek API key(输入内容隐藏):" default answer "" with hidden answer buttons {"取消","OK"} default button 2 with title "overcast: DeepSeek key 录入")') || { echo "已取消"; exit 1; }

[ -n "$ANS" ] || { echo "空输入,未落盘"; exit 1; }

case "$ANS" in
  sk-*) echo "OK:已写入 $OUT(0600),长度 ${#ANS},sk- 形,值不回显" ;;
  *) echo "注意:非 sk- 开头,长度 ${#ANS};已落盘,若抄错重跑本脚本覆盖" ;;
esac

printf '%s' "$ANS" > "$OUT"
chmod 600 "$OUT"
