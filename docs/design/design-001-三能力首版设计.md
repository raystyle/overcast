# design-001:三能力首版设计

- 时点:2026-10-11;状态:failover 节实写定稿候选;注入与 CH 两节留位
- 依据:research-01(总台在途,`/tmp/herdr-flywheel/2026-10-11-智谱网关调研/research-01.md`)已落「网关五件」节;注入三件与 CH 四件在写,落节后回填本档并随总台评审修订
- 关联:ADR-0001(上游选型裁定)、REQ-001(验收判据)、`deploy/`(配置与 compose)、`docs/operations/lan-mac部署手册.md`

## 0. 总体形态与裁定:不 fork、不薄层,配置态优先

overcast 不是网关代码仓。总体形态 = 上游 CLIProxyAPI 官方镜像钉 tag 运行 + 本仓薄资产(配置模板、compose、手册、设计、需求登记)。裁定依据(详见 ADR-0001 与 research-01 对照节):

| 候选 | 裁定 | 一句话依据 |
| --- | --- | --- |
| CLIProxyAPI v8 配置态双 key | **主案** | conductor 已支持同请求换 key 加按状态码冷却;双 key 是配置问题不是能力缺失;无数据库、单容器、arm64 官方镜像 |
| LiteLLM | 条件备胎 | 能力够但属第二套网关,舰队 cc/cx 别名要重接;仅当客户端只走 OpenAI chat 且不能改 CPA 配置时 |
| new-api | 不选 | 面板与数据库组件重,两把 key 用不上;渠道市场出现需求再议 |
| 自研薄层 | 不选 | Claude messages 与 Codex responses 翻译要重做;多一跳反代只为换 key 不值 |
| fork 上游 | 不选 | v8 几乎按天发版,conductor 上会反复冲突;补丁以小提交往上游提,不留分叉分支 |

**二开条件句**(唯一允许动代码的路径):智谱把余额不足/限流放在 HTTP 400、HTTP 200 body、或 `request-scoped-errors` 匹配不到的形态时,先配 `request-scoped-errors` 四档动作(stop/stop-and-cooldown/continue/continue-and-cooldown)按 body 子串分类;配置盖不住再补一个很小的分类函数(`IsRequestFault` 与 `matchRequestScopedErrorAction` 是现成钩子),让 conductor 现有循环换 key。**不在 HTTP 层再包重试**(会与 `request-retry` 叠成双倍请求),不动 round-robin 与冷却状态机。

## 1. 能力一:failover 双 token(实写)

### 1.1 机制(上游既有,不新造)

- 换 key 循环:`executeMixedOnce` 在一个请求内循环 `pickNextMixed`;当前 key 失败后,只要不是请求本身的错误(判定在 `internal/clienterror/client_error.go` 的 `IsRequestFault`),就选下一把
- 选择器:`RoundRobinSelector` 在未冷却 key 间轮转(FillFirst 与加权是备选策略);冷却中的 key 在 `isAuthBlockedForModel` 被跳过
- 冷却表(`applyAuthFailureState`,冷却开启时):

| 上游状态 | 同一次请求 | 冷却 |
| --- | --- | --- |
| 400、409、413、422 及 body 判为请求错误 | 不换 key,原样返回 | 不惩罚 |
| 401 | 换下一把 | 30 分钟 |
| 402、403 | 换下一把 | 30 分钟 |
| 429 | 换下一把 | 配额退避,尊重 Retry-After,有下限 |
| 408、500、502、503、504、520 至 526 | 换下一把 | 瞬时冷却(配置 0 沿用 60 秒,-1 关闭此类) |
| 拨号、TLS、连接重置 | 换下一把 | 另标传输错误,不按请求错误停转 |

- 流式语义:首包之前失败,模型池与下一把 key 都能接(`executeStreamWithModelPool` 读 bootstrap);首包已转给客户端后,`wrapStreamResult` 只把错误转发客户端,**不换 key 不重放**。断流由 agent 重开一轮(中途接半段 SSE 上下文对不齐且双计费,不做)
- 冷却态默认只在内存,容器重启清零(`save-cooldown-status` 默认 false),对双 key 场景可接受

### 1.2 配置形(两组、双 entries、冷却开)

形态与占位符见 `deploy/config.example.yaml`,要点:

1. **chat 面**:openai-compatibility 条目,name `glm`,base `https://open.bigmodel.cn/api/paas/v4`(执行器自接 `/chat/completions`,base 里不写这段),`api-key-entries` 两行两把 key,`disable-cooling: false`,`request-retry: 3`
2. **messages 面**:claude-api-key 条目,base `https://open.bigmodel.cn/api/anthropic`,同样两把 key 拆两条、冷却开;chat 池与 messages 池互不代替
3. 两把 key 必须同种产品(通用开放平台 key 用 `paas/v4`;编码套餐 key 用 `https://open.bigmodel.cn/api/coding/paas/v4`,不混填);**不要把两把 key 配成两个模型别名**——别名池是换上游模型名,不是换账户
4. 全局 `routing`:strategy round-robin,`session-affinity: false`,冷却不全局关(旧版 count_tokens 规避已随 v7.1.16 消失,不继承舰队旧模板的全局 `disable-cooling: true`)
5. 网关自己的访问 key 在 `access.api-keys`,与智谱 key 分离;管理面 `management.allow-remote: false`,secret 留空

字段名以部署批渲染前对照上游 `config.example.yaml` 为准(research-01 引的是上游 main 分支形制,未逐字段核验)。

### 1.3 升级阶梯(问题出现时的处置序)

1. 换 key 不生效 → 先查冷却与配置(两组 `disable-cooling: false` 是否真渲染进去)
2. 智谱错误形态在 body(如 HTTP 200 带业务失败、400 带限流文案)→ 配 `request-scoped-errors` 按 body 子串改 `continue-and-cooldown`
3. 配置盖不住 → 二开条件句(分类函数小提交往上游提,见 0 节)
4. 流式中断 → 客户端重开一轮,网关侧无动作(语义继承上游)

### 1.4 验收

判据在 REQ-001 能力一(401 换 key、400 不换、流式掐断、key 分离、断网恢复、同机无双上游),由部署批在 lan-mac 实测执行。

## 2. 能力二:system prompt 实时注入(留位)

> **留位**:本节待 research-01「注入三件」落节后回填设计;以下只固化已知边界与开放问题,不是设计结论。

已知输入:

- 上游参考:qiontoo/cliproxyapi-system-prompt-injection(prompt 注入补丁参考,license 与可合入性待核)
- 需求语义:注入要**热改**——不重启容器、不断在跑流;注入生效面(at request 入口)与热改通道(配置 reload 或独立控制面)是两个正交决定

开放问题(研究档落节后逐条对答):

- [ ] 注入面粒度:全局、按模型别名、按客户端(cc 与 codex 面不同 system 结构)、按 access key?
- [ ] 注入位置:prepend 到既有 system、append、还是替换?与客户端自带 system prompt 的合并语义?
- [ ] 热改通道:上游有无 config 热加载;无则侧车(独立注入代理层)或上游小补丁,谁改谁持有?
- [ ] 与能力一叠加:注入后的请求若触发换 key 重试,注入是否随重试保留(同一请求体重放应天然保留,需实测确认)?
- [ ] 与能力三叠加:注入内容是否入 CH 回溯(审计面要能回放当轮生效的 prompt)?

## 3. 能力三:ClickHouse 全量回溯观测(留位)

> **留位**:本节待 research-01「CH 四件」落节后回填设计;以下只固化立项单给的形态约束与开放问题。

已固化约束(来自立项单与研究档部署节):

- 出口**异步批写**,不占请求热路径(failover 是第一优先级能力,观测不得成为新故障面)
- 全量回溯(不是采样),留存策略与表结构待定;CH 实例落 lan-mac docker(Colima),与网关同 compose 或独立 compose 待裁

开放问题(研究档落节后逐条对答):

- [ ] 数据面:取上游访问日志、网关出口 tap、还是侧车镜像流?各自漏流式 token 计的风险?
- [ ] schema:请求/响应/时延/所用 key/冷却事件/注入内容,哪些进首版表?
- [ ] 批写通道:缓冲在哪(容器内 sidecar、宿主 agent、CH 侧物化),失败退避与丢批容忍?
- [ ] 冷却事件与换 key 事件如何入表(与能力一的观测联动:回溯要能回答「这一轮为什么换了 key」)?
- [ ] 留存:TTL、分区键、盘容上限(lan-mac 本地盘)?

## 4. 部署形态概要

lan-mac Colima 加 docker compose,镜像钉 tag,config 与 auths 卷外置,宿主端口 8317;细则与验收步骤见 `docs/operations/lan-mac部署手册.md`。CH 与注入侧车(若裁侧车形态)进同一 compose 项目的扩展面,首版只带网关单服务。

## 5. 未决与依赖

| 项 | 阻塞什么 | 谁 |
| --- | --- | --- |
| research-01 注入三件落节 | 本档 2 节回填、REQ-001 能力二判据细化 | 总台(在写) |
| research-01 CH 四件落节 | 本档 3 节回填、REQ-001 能力三判据细化 | 总台(在写) |
| research-01 总台评审 | ADR-0001 转 accepted | 总台 |
| 部署批实测 | REQ-001 能力一勾验、ADR-0001 验收门槛 | 部署批(另派) |
