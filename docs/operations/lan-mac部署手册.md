# lan-mac 部署手册(operations 面)

- 依据:research-01 部署节 + design-001;执行归**部署批**(单 ov-01 边界:其余工位对 lan-mac 只读)
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

渲染纪律:两把智谱 key 必须同种产品;渲染完 `stat -f %Lp config.yaml` 核 0600;`access.api-keys` 发给客户端的网关 key 与智谱 key 分离管理。

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

## 4. 验收清单(REQ-001 能力一判据,逐条实测)

| # | 操作 | 期望 |
| --- | --- | --- |
| 1 | 第一把 key 故意配错(401),第二把有效,发非流式请求 | 得 200;日志可见先失败后换 key(auth id 变过) |
| 2 | 发 400 坏请求 | 停在第一把,不打第二把 |
| 3 | 流式请求,首个内容块之后掐断上游 | 客户端看到错误;不从第二把 key 续写后半段 |
| 4 | 拔 lan-mac 网络再恢复 | 容器起来后两把 key 仍在(卷外置);冷却状态丢属可接受(默认内存态) |
| 5 | 核对同机其他 CPA | 不与本网关同时当同一批 agent 的上游(两套冷却各算各的) |

进度(2026-10-11,单 ov-03):判据 1 与 2 已实测,判据 1 形制修正为 chat 组 `api-key-entries` 两行、claude 组拆两条目(见 §7);判据 2 实测证据:改错第一把 key 后,同一请求 id 日志先 401(`conductor_execution` warn,provider=openai-compatible-glm)后 200,客户端全程 200,还原重启后两发干净 200。判据 3 至 5 未测。

## 5. 客户端接法

端点与模型名速查:

```text
base-url:  http://lan-mac:8317
Claude Code 走 /v1/messages;codex 走 /v1/responses;chat 走 /v1/chat/completions
messages 面(Claude Code):zp-cc-glm53、zp-cc-glm53fh,另保留裸名 glm-5.3(旧会话剥掉 [1m] 后仍发这个)
responses 面(Codex):zp-cx-glm53、zp-cx-glm5t;chat 面:zp-cx-chat
key:网关发的 access key,不是智谱 key
```

逐客户端配置(Claude settings env 形、codex config.toml 加 models.json)见 [客户端接入](客户端接入.md)。

## 6. 运维

- **升级**:改 up.sh 里 tag 跟 v8 补丁号(上游几乎按天发版),`./down.sh && ./up.sh` 重建;config 与 auths 卷外置不动(compose 插件可用时同义改 deploy/docker-compose.yml)
- **秘密轮换**:金库重渲染 config.yaml 落部署目录(0600),再 `docker restart overcast`;key 失效期间冷却表不迁移(内存态,重启清零);改 config 的热通道:file watcher 在盯配置变化,轻改可不重启,大改建议重启收口
- **日志**:`docker logs overcast`;换 key 与冷却在日志有 auth id 痕迹,验收与排障先看这里
- **升降级回退**:tag 改回上一版 `up -d` 即回(无状态迁移)
- **停服**:`cd ~/overcast && ./down.sh`(保卷);`colima stop` 连运行时一起停

## 7. 已知边界

- 流式首包后断流不换 key 不重放,agent 侧重开一轮(ADR-0001 继承上游语义)
- 冷却态默认不落盘(`save-cooldown-status` 默认 false);若后续观测(REQ-001 能力三)显示重启风暴导致冷却抖动,再评估开它,首版不开
- 智谱失败形态若落在 body(400 文案限流、200 带业务失败),按 design-001 §1.3 升级阶梯先配 `request-scoped-errors`,不改代码
- **多 key 形制两组不同**(2026-10-11 实测):openai-compatibility 组用 `api-key-entries` 列表;claude-api-key 组必须每把 key 一个条目(`api-key:` 单数),在该组用 `api-key-entries` 会载入 1 个空 key 客户端,上游 401 报「Header中未收到Authorization参数」,日志痕迹 `auth=api_key=`(空值)
- **`[1m]` 后缀是纯客户端参数,网关别名不带这段**(2026-10-11 对照实测):Claude Code settings 写 `zp-cc-glm53[1m]` / `zp-cc-glm53fh[1m]` 开 1M 上下文,CC 发请求前自己剥后缀,网关收到 `zp-cc-glm53` / `zp-cc-glm53fh`;带 `[1m]` 的名字直打网关会 400 unknown provider
- **port 必写**:config 缺根级 `port: 8317` 时上游监听 `:0` 随机端口,起服日志可见,外部一律连不上
- **responses 面必须走 xai-api-key 组**(2026-10-11 实测):智谱 `/api/v1` 是 Responses-only 面(chat/completions 双模型 403 model_access_denied,responses 双模型 200),openai-compatibility 执行器把 Responses 请求翻译成 chat 发上游必 403;xai-api-key 组走原生 Responses 执行器直通上游 /responses,legacy 形每条目一把 key

## 8. 思考块调试注入(能力二 v1,2026-10-11)

形态:配置态 `requests.payload.override` / `override-raw`,请求头 `X-Overcast-Debug` 门控,不带头零改动;规则见 config 的 requests 段(仓内模板同形)。

```bash
# effort 档调试(responses 面,/v1/responses):
curl -H 'X-Overcast-Debug: low'  ... # 低推理档(响应无 reasoning 项,快)
curl -H 'X-Overcast-Debug: high' ... # 高推理档(带 reasoning 项)

# 净室调试(claude 面,/v1/messages):全换 system 为调试沙盒提示词
curl -H 'X-Overcast-Debug: cleanroom' ...

# 假 thinking 锚注入(claude 面):messages[1] 放 assistant 占位轮,头带 anchor,
# 网关把该轮 content 整块换成伪造 thinking 块(智谱不校验 signature)
curl -H 'X-Overcast-Debug: anchor' ...
```

- **门控嵌套坑**(2026-10-11 源码比对实证):`headers`/`from-protocol` 等门控字段必须嵌在每个 models 条目内(与 name/protocol 同级);写在规则层会被静默丢弃,规则变成无门控裸规则,首版部署曾中坑已修
- 旋钮边界(直探上游实证):responses 面 `reasoning.effort` 认;claude 面 `thinking.budget_tokens` 不认(不作旋钮);`system`/`instructions` 全换语义,prepend 合并留 v2 侧车
- 热改:改 requests.payload 段 params 值存盘即热加载(轻改);新增规则或新根级段重启收口
- 热改脚本:`sh ~/overcast/inject.sh '<新 system 文本>'` 直改 cleanroom 规则的 system 行
- CC 加头法:settings.json env `ANTHROPIC_CUSTOM_HEADERS`(逗号分隔多对);curl/codex 直接加
- 外部无 key 探 `GET /v1/models` 得 401 属预期(鉴权墙在);带网关 key 的 200 实测在 lan-mac 本机做(key 不出机)
