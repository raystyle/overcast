# lan-mac 部署手册

> 类型: how-to
> 读者: 部署者
> 事实源: deploy/config.example.yaml

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
messages 面(Claude Code):zp-cc-glm53、zp-cc-glm53fh,另保留裸名 glm-5.3(旧会话剥掉 [1m] 后仍发这个)
responses 面(Codex):zp-cx-glm53、zp-cx-glm5t;chat 面:zp-cx-chat
key:网关发的 access key,不是智谱 key
```

base-url 口径(2026-10-12 cfg-01 F1 修):统一写 `http://192.168.88.10:8317`(本网客户端实测路径)。主机名形 `http://lan-mac:8317` 经 ts 域解析到同机另一网口(10.10.10.9),docker 全接口监听,实测等效可用;前提是客户端具备该域解析,不具备则一律用 IP 形。

逐客户端配置(Claude settings env 形、codex config.toml 加 models.json)见 [客户端接入](客户端接入.md)。

## 6. 运维

- **升级**:改 up.sh 里 tag 跟 v8 补丁号(上游几乎按天发版),`./down.sh && ./up.sh` 重建;config 与 auths 卷外置不动(compose 插件可用时同义改 deploy/docker-compose.yml)
- **秘密轮换**:金库重渲染 config.yaml 落部署目录(0600),再 `docker restart overcast`;key 失效期间冷却表不迁移(内存态,重启清零);改 config 的热通道:file watcher 在盯配置变化,轻改可不重启,大改建议重启收口
- **日志**:`docker logs overcast`;换 key 与冷却在日志有 auth id 痕迹,验收与排障先看这里
- **升降级回退**:tag 改回上一版 `up -d` 即回(无状态迁移)
- **停服**:`cd ~/overcast && ./down.sh`(保卷);`colima stop` 连运行时一起停

## 7. 已知边界

边界、冷却与换 key 行为的事实表统一在 [网关行为参考](../reference/网关行为参考.md) 维护,本节不重复第二份;客户端可见的别名与端口速查在 [客户端速查](../reference/客户端速查.md)。

## 8. 已剔除能力:思考块调试注入

2026-10-12 用户裁定剔除(原能力二 v1,payload 配置态、`X-Overcast-Debug` 头门控、零代码):scope 收敛为稳定双 token 轮换 + vector/CH 观测道。模板 requests 段已删,部署目录 inject.sh 已清,实测证据归档 REQ-001 演进与 git 史;历史用法与门控嵌套坑详解见 git 史 7bfb2c8 版手册 §8。
