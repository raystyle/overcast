# design-001:首版设计

- 时点:2026-10-11 立;2026-10-12 起拆分退役(产品文档规范批,S004),各节去向见本页末去向表
- 2026-10-12 用户裁定:注入节作废剔除(证据归档 REQ-001 演进);CH 观测改道 REQ-002(vector 采集原始请求日志入库)承接;现 scope = 双 token 轮换 + vector/CH 观测道两能力
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

## 1. 能力一:failover 双 token 实写

### 1.1 机制,上游既有不新造

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

### 1.2 配置形,两组双 entries 冷却开

形态、字段与占位符以 `deploy/config.example.yaml` 顶部注释与条目为事实源;供应池现行三上游(两把智谱 key 加 zyuncs 备),条目形制见模板,本节不留第二份字段清单。

### 1.3 升级阶梯,问题出现时的处置序

1. 换 key 不生效:先查冷却与配置(两组 `disable-cooling: false` 是否真渲染进去)
2. 智谱错误形态在 body(如 HTTP 200 带业务失败、400 带限流文案):配 `request-scoped-errors` 按 body 子串改 `continue-and-cooldown`
3. 配置盖不住:走二开条件句(分类函数小提交往上游提,见 0 节)
4. 流式中断:客户端重开一轮,网关侧无动作(语义继承上游)

### 1.4 验收

判据在 REQ-001 能力一(401 换 key、400 不换、流式掐断、key 分离、断网恢复、同机无双上游),由部署批在 lan-mac 实测执行。

## 2. 已剔除:system prompt 实时注入

2026-10-12 用户裁定剔除(原能力二 v1)。证据与实测归档:REQ-001 演进节 + git 史(9dd25ae/2166adb/7bfb2c8)。v1 形态、门控嵌套坑与直探旋钮数字不再当现役通道引用;门控嵌套坑若日后重启 payload 规则仍适用,见 git 史 7bfb2c8 版本档第 2 节。

## 3. 已改道:ClickHouse 全量回溯观测

2026-10-12 用户裁定改道 REQ-002(vector 采集原始请求日志入 ClickHouse)承接;本节留位作废,方案等 REQ-002 离开留位再写。

## 4. 部署形态概要

lan-mac Colima 加 docker compose,镜像钉 tag,config 与 auths 卷外置,宿主端口 8317;细则与验收步骤见 `docs/operations/lan-mac部署手册.md`。首版只带网关单服务。

## 5. 未决与依赖

| 项 | 阻塞什么 | 谁 |
| --- | --- | --- |
| research-01 网关五件评审收尾 | ADR-0001 转 accepted | 总台 |
| 部署批实测 | REQ-001 勾验、ADR-0001 验收门槛 | 部署批(另派) |
