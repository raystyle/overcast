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
  docker-compose.yml    # 从本仓 deploy/ 拷或 git 拉取
  config.yaml           # 金库渲染(源:deploy/config.example.yaml 占位符),0600,不进仓
  auths/                # 凭据卷(OAuth 类凭据落点),不进仓
```

渲染纪律:两把智谱 key 必须同种产品;渲染完 `stat -f %Lp config.yaml` 核 0600;`access.api-keys` 发给客户端的网关 key 与智谱 key 分离管理。

## 3. 起服

```bash
cd ~/overcast
docker compose up -d
docker logs overcast --tail 50           # 起服无错;管理面应保持远程关闭
```

镜像钉 tag(`eceasy/cli-proxy-api:v8.0.23`,arm64 层已有),**不用 latest**。

## 4. 验收清单(REQ-001 能力一判据,逐条实测)

| # | 操作 | 期望 |
| --- | --- | --- |
| 1 | 第一把 key 故意配错(401),第二把有效,发非流式请求 | 得 200;日志可见先失败后换 key(auth id 变过) |
| 2 | 发 400 坏请求 | 停在第一把,不打第二把 |
| 3 | 流式请求,首个内容块之后掐断上游 | 客户端看到错误;不从第二把 key 续写后半段 |
| 4 | 拔 lan-mac 网络再恢复 | 容器起来后两把 key 仍在(卷外置);冷却状态丢属可接受(默认内存态) |
| 5 | 核对同机其他 CPA | 不与本网关同时当同一批 agent 的上游(两套冷却各算各的) |

## 5. 客户端接法

```text
base-url:  http://lan-mac:8317
Claude Code 走 /v1/messages;codex 走 /v1/responses;chat 走 /v1/chat/completions
模型名用别名:zp-glm53-claude(Claude 面)、zp-glm53-codex(codex/chat 面)
key:网关发的 access key,不是智谱 key
```

## 6. 运维

- **升级**:改 compose 里 tag 跟 v8 补丁号(上游几乎按天发版),`docker compose up -d` 重建;config 与 auths 卷外置不动
- **秘密轮换**:金库重渲染 config.yaml → `docker compose restart`;key 失效期间冷却表不迁移(内存态,重启清零)
- **日志**:`docker logs overcast`;换 key 与冷却在日志有 auth id 痕迹,验收与排障先看这里
- **升降级回退**:tag 改回上一版 `up -d` 即回(无状态迁移)
- **停服**:`cd ~/overcast && docker compose down`(保卷);`colima stop` 连运行时一起停

## 7. 已知边界

- 流式首包后断流不换 key 不重放,agent 侧重开一轮(ADR-0001 继承上游语义)
- 冷却态默认不落盘(`save-cooldown-status` 默认 false);若后续观测(REQ-001 能力三)显示重启风暴导致冷却抖动,再评估开它,首版不开
- 智谱失败形态若落在 body(400 文案限流、200 带业务失败),按 design-001 §1.3 升级阶梯先配 `request-scoped-errors`,不改代码
