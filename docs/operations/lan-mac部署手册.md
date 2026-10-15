# lan-mac 部署手册

> 类型: how-to
> 读者: 部署者
> 事实源: deploy/config.example.yaml

- 依据:research-01 部署节 + [上游选型](../explanation/上游选型.md);执行归**部署批**(单 ov-01 边界:其余工位对 lan-mac 只读)
- 实况探测(2026-10-11,只读):Apple Silicon arm64,macOS 26.6.2,colima 与 docker 均已装(/opt/homebrew/bin),宿主 8317 空闲。立项单记「Colima 未装」已过时,部署批无需再装运行时(仍需实查 `colima status`)

## 1. 前提核对

```bash
colima status || colima start            # 运行时已在,起停参数按需(--cpu/--memory)
docker context show                      # 应指 colima
lsof -nP -iTCP:8317 -sTCP:LISTEN         # 应空闲
```

## 2. 目录与秘密

lan-mac 部署目录建议 `~/overcast/`(部署批定,三件同目录):

```
~/overcast/
  up.sh / down.sh       # 起停(compose 等价形,2026-10-11 部署批落)
  docker-compose.yml    # 仓内 deploy/ 持,compose 插件可用时同义用
  config.yaml           # 金库渲染(源:deploy/config.example.yaml 占位符),0600,不进仓
  auths/                # 凭据卷(OAuth 类凭据落点),不进仓
  config.yaml.bak-*     # 部署批修正留档(port 修正、claude 组改形)
```

渲染纪律:两把智谱 key 必须同种产品;渲染完 `stat -f %Lp config.yaml` 核 0600;`access.api-keys` 发给客户端的网关 key 与智谱 key 分离管理。鉴权开关 `deploy/auth-toggle.sh on|off|status`:off 把 access.api-keys 条目全注释(零条目=零 provider 放行,任意 token 与无头均可)、on 还原,均重启容器并以 401/200 探活自检;现态 off(2026-10-13 用户裁定,内网免鉴权)。

**驻留注记(真源关系)**:仓内 `deploy/` 与 `docs/` 是形制真源,部署目录 `~/overcast` 的运行态(config.yaml 金库渲染实例、auths/ 凭据卷、bak-* 留档、容器本身)只是它的部署投影;形制变更先进仓、再渲染进部署目录,部署目录里的手改不回写仓即视为漂移。

## 3. 起服

lan-mac 实况无 docker compose 插件、无 docker-compose 二进制(2026-10-11 实测;装 brew 包越「只动部署目录」界),部署目录内用 compose 等价形:

```bash
cd ~/overcast
./up.sh                                  # docker run 等价形,参数与仓内 deploy/docker-compose.yml 逐项同
./down.sh                                # 停服回滚(容器删,config 与 auths 留档)
docker logs overcast --tail 50
```

起服必核两行日志(2026-10-11 实测坑):

- `API server started successfully on: :8317`;若是 `:0`,config 漏了根级 `port: 8317`,上游缺省监听随机端口,宿主映射落空(三发 curl 全 000 的根因)
- `... N clients (... 2 Claude API keys ... 2 OpenAI-compat)`:claude 组与 openai 组各两把;若 Claude 记 1,该组多 key 形制错了(见 §7)

镜像钉 tag(`eceasy/cli-proxy-api:v8.0.23`,arm64 层已有),**不用 latest**。

## 4. 验收清单

REQ-001 判据,逐条实测。

| # | 操作 | 期望 |
| --- | --- | --- |
| 1 | 第一把 key 故意配错(401),第二把有效,发非流式请求 | 得 200;日志可见先失败后换 key(auth id 变过) |
| 2 | 发 400 坏请求 | 停在第一把,不打第二把 |
| 3 | 流式请求,首个内容块之后掐断上游 | 客户端看到错误;不从第二把 key 续写后半段 |
| 4 | 拔 lan-mac 网络再恢复 | 容器起来后两把 key 仍在(卷外置);冷却状态丢属可接受(默认内存态) |
| 5 | 核对同机其他 CPA | 不与本网关同时当同一批 agent 的上游(两套冷却各算各的) |

进度(2026-10-11,单 ov-03):判据 1 与 2 已实测,判据 1 形制修正为 chat 组 `api-key-entries` 两行、claude 组拆两条目(见 §7);判据 2 实测证据:改错第一把 key 后,同一请求 id 日志先 401(`conductor_execution` warn,provider=openai-compatible-glm)后 200,客户端全程 200,还原重启后两发干净 200。2026-10-12 余账推进:表行 2(400 不轮转,单发 `[4feb9f1d]` 零换 key 痕迹)、行 4(断网恢复,docker 断接 3 秒后探针 200)、行 5(同机无第二 CPA,容器与进程双核)实测过;key 隔离核验过(客户端配置零智谱 key 形态,网关 key 各 1)。表行 3(流式掐断)未测,余可控断流手段。2026-10-12 15:35 生产实事件:表行 1 的 429 真实形态落地,第一把撞智谱 5 小时窗限(429 code 1308,限额 17:33:27 重置),请求 `[216049cb]` 同请求换 key,客户端 200(4.872s),后续两发持续 200,冷却按 rate-limit header 解析;两把同窗尽时双冷却、客户端见 429,属容量边界非切换故障。

## 5. 客户端接法

端点与模型名速查:

```text
base-url:  http://192.168.88.10:8317
Claude Code 走 /v1/messages;codex 走 /v1/responses;chat 走 /v1/chat/completions
messages 面(Claude Code):zp-cc-glm53、zp-cc-glm53fh,另保留裸名 glm-5.3(旧会话剥掉 [1m] 后仍发这个);DeepSeek:ds-cc-pro、ds-cc-flash
responses 面(Codex):zp-cx-glm53、zp-cx-glm53fh、zp-cx-glm5t;chat 面:zp-cx-chat;DeepSeek:ds-cx-pro、ds-cx-flash(responses 经翻译,chat 直通)
key:现态鉴权关,任意非空串即可;开态用网关发的 access key(不是智谱 key),开关见 §2 渲染纪律
```

base-url 口径(2026-10-12 cfg-01 F1 修):统一写 `http://192.168.88.10:8317`(本网客户端实测路径)。主机名形 `http://lan-mac:8317` 经 ts 域解析到同机另一网口(10.10.10.9),docker 全接口监听,实测等效可用;前提是客户端具备该域解析,不具备则一律用 IP 形。

逐客户端配置(Claude settings env 形、codex config.toml 加 models.json)见 [客户端接入](客户端接入.md)。

## 6. 运维

- **升级**:改 up.sh 里 tag 跟 v8 补丁号(上游几乎按天发版),`./down.sh && ./up.sh` 重建;config 与 auths 卷外置不动(compose 插件可用时同义改 deploy/docker-compose.yml)

### 升级阶梯,问题出现时的处置序

1. 换 key 不生效:先查冷却与配置(各组 `disable-cooling: false` 是否真渲染进去)
2. 智谱错误形态在 body:分两形。**HTTP 200 的 SSE 流内嵌 `event: error`**(2026-10-15 15:53 生产实事件:1308 限流装在 200 体内,原样透传不轮换不冷却):`request-scoped-errors` 盖不住(它只评估已成 error 对象的路径,200 体内嵌错误不产生 error 对象,旁路实测无效),由 dialog5 执行器「流开局 hold」兜住(扣住前导事件至首个内容块,hold 期内 error 帧映射 429 转流错误,字节未到客户端即轮转)。**400 带限流文案等带状态码形态**仍走 `request-scoped-errors` 按 body 子串改 `continue-and-cooldown`
3. 配置盖不住:走二开条件句(分类函数小提交往上游提,见 [上游选型](../explanation/上游选型.md) 与 ADR-0001)
4. 流式中断:客户端重开一轮,网关侧无动作(语义继承上游)

### 对话观测道,REQ-002 补丁态

镜像 `cli-proxy-api:v8.0.23-dialog6`(本地构建自 `~/repos/CLIProxyAPI` 分支 `feat/dialog-observation`,commit `4c365fdd`;二开长期自维护,2026-10-12 用户裁定,不往上游提 PR;2026-10-14 dialog2 起 AI 路径响应头回写 `X-Request-Id`,与 stdout 末 8 位及 dialog JSONL 同一 UUIDv7,无值才补写不覆盖上游转发值,客户端凭此串联;同日 dialog3 起 request_end 增补 agent/session_id/alias 与 usage 五列 input/output/cache_read/cache_creation/thinking,agent 从 User-Agent 映射 claude/codex/grok/kimi、session 支持 CC metadata.user_id 剥 uuid 与 codex 顶层 session_id、超 256KiB body 跳过留空,全 omitempty 不回填,对接 gw_logs.head vector transform;2026-10-15 dialog4 起 payload 单事件超 8MiB 截断打 `payload_truncated` 标、分块编出行超 64KiB 改二分不丢字节、文件开写失败丢行计入 dropped 计数、热重载任一 dialog 键变化即重建观测通道;同日 dialog5 起 claude 面透传执行器加流开局 hold,200 体内嵌 error 帧不再透传,映射 429 走 conductor 轮转;同日 dialog6 起补 fleet 会话采集缺口:实测 GLM Claude Code 客户端发的 metadata.user_id 是 JSON 串 `{"device_id","account_uuid","session_id"}`(串形与对象形都解析),dialog3 只认 CC 官方 `session_` 形致 session_id 恒空、且 256KiB 预算把约 88% 多轮大 body 跳过,现改 gjson 加标记预扫无尺寸预算(顺带补全大 body 的 alias/model);agent 列升级为客户端身份:`X-Client-Name` 头优先(各台可经 ANTHROPIC_CUSTOM_HEADERS 配,实核存在)、次选 UA 家族加 device 指纹 `claude@7fcd982e`(blob 自带,免客户端配置)、兜底原 UA 映射;历史行不回填,切换后新流量生效)。配置键 `dialog-log: true` 加 `dialog-log-max-total-size-mb: 512`,JSONL 落 `dialoglogs/` 卷(小时文件 `dialog-YYYYMMDD-HH.jsonl`,一行一事件,四类:client_request / sse / upstream_attempt / request_end;大请求体分块,单行不超 64KiB,单事件超 8MiB 截断打 `payload_truncated`;完整 UUIDv7 的 request_id 可对 stdout 末 8 位)。2026-10-12 20:47 上线实测:10 请求全量落流,729KB 请求体分块重组回放合法,135 SSE 事件带 message_stop,延迟分布与补丁前同区间(7 至 34 秒),热路径零损;队列满丢事件有单测。

**查数据(2026-10-14 实测定稿)**:id 从客户端响应头 `X-Request-Id` 拿;档按小时滚动,请求跨档拆两文件,查询一律 `dialog-*.jsonl` 全档通配;zsh 勿经 `echo "$VAR"` 转手(会展开反斜杠毁 JSON),用直 pipe。

```bash
# 按 id 取全事件,先看全景
grep -h <id> ~/overcast/dialoglogs/dialog-*.jsonl | jq .

# 重组原始请求体,64KiB 分块拼接回原文
grep -h <id> ~/overcast/dialoglogs/dialog-*.jsonl \
  | jq -sr 'map(select(.kind=="client_request"))|map(.payload)|join("")'

# 助手回答全文,anthropic 面,-j 连排
grep -h <id> ~/overcast/dialoglogs/dialog-*.jsonl \
  | jq -r 'select(.kind=="sse")|.payload' | grep '^data: ' | sed 's/^data: //' \
  | jq -j 'select(.type=="content_block_delta")|.delta.text // empty'

# usage token,message_delta 含全量 input/output/cache_read/thinking
grep -h <id> ~/overcast/dialoglogs/dialog-*.jsonl \
  | jq -r 'select(.kind=="sse")|.payload' | grep '^data: ' | sed 's/^data: //' \
  | jq -c 'select(.type=="message_delta").usage'

# 慢请求榜,当前档 >15s
grep '"kind":"request_end"' ~/overcast/dialoglogs/dialog-$(date +%Y%m%d-%H).jsonl \
  | jq -r 'select(.duration_ms>15000)|[.ts,.request_id,.duration_ms]|@tsv'
```

错误原文也在 sse 事件里(智谱 HTTP 200 带错误 body 的已知边界,按 id 查即得原文与换 key 过程)。**留存硬界**:盘容预算 512MB 对 ~350MB/时 = 约 1.5 小时,超窗即删;超窗历史查询走 CH(lan-linux2 gw_logs:head 头表检索筛 id + gwlog 全量行含 body,TTL 180/365 天,见 REQ-002 演进,SELECT 授权在 lan-linux dctl 侧)。
- **秘密轮换**:金库重渲染 config.yaml 落部署目录(0600),再 `docker restart overcast`;key 失效期间冷却表不迁移(内存态,重启清零);改 config 的热通道:file watcher 在盯配置变化,轻改可不重启,大改建议重启收口
- **安全事件登记**:2026-10-12 网关 access key 明文曾入 lan-mac 本机会话 transcript(模板形状对比脚本脱敏遗漏,未入仓未入 commit);用户裁定 LAN 内低风险,不轮换,本条留档
- **鉴权开关与 2026-10-13 事故**:用户裁定内网免鉴权并开关化(`deploy/auth-toggle.sh`,off=api-keys 零条目放行)。首版脚本 awk 还原时剥掉行缩进,config 形坏致容器 crash-loop 数分钟(本机客户端全体 Connection lost/ECONNREFUSED 即此),`config.yaml.bak-20261013-authoff` 备份恢复后修 bug;现行版实切前离线对拍全绿(off/on 往返字节一致、off 幂等、开态 on 无操作不变)
- **日志**:`docker logs overcast`;换 key 与冷却在日志有 auth id 痕迹,验收与排障先看这里
- **升降级回退**:tag 改回上一版 `up -d` 即回(无状态迁移)
- **停服**:`cd ~/overcast && ./down.sh`(保卷);`colima stop` 连运行时一起停

## 7. 已知边界

边界、冷却与换 key 行为的事实表统一在 [网关行为参考](../reference/网关行为参考.md) 维护,本节不重复第二份;客户端可见的别名与端口速查在 [客户端速查](../reference/客户端速查.md)。

## 8. 已剔除能力:思考块调试注入

2026-10-12 用户裁定剔除(原能力二 v1,payload 配置态、`X-Overcast-Debug` 头门控、零代码):scope 收敛为稳定双 token 轮换 + vector/CH 观测道。模板 requests 段已删,部署目录 inject.sh 已清,实测证据归档 REQ-001 演进与 git 史;历史用法与门控嵌套坑详解见 git 史 7bfb2c8 版手册 §8。
