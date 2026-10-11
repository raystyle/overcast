---
id: ADR-0001
title: 上游选型CLIProxyAPI配置态双key不fork
status: proposed
date: 2026-10-11
deciders:
  - raystyle
supersedes: []
superseded_by:
tags: ['定位', '上游', 'failover']
---

# ADR-0001:上游选型 CLIProxyAPI 配置态双 key,不 fork

## Context

overcast 立项(单 ov-01,2026-10-11)要智谱双 token failover。候选四案对照见研究档 research-01(总台在途,已落「网关五件」节):CLIProxyAPI v8.0.23、LiteLLM、new-api、自研薄层。关键事实:上游 v8 的 conductor(`sdk/cliproxy/auth/conductor_execution.go` 的 `executeMixedOnce`)已会在同一次请求里换下一把 key,并按状态码冷却失败 key(`conductor_cooldown.go`):401/402/403 冷却 30 分钟,429 尊重 Retry-After,408 与 5xx 短冷却,400 类请求错误不换 key 不惩罚。GLM 无原生执行器,走 openai-compatibility(智谱 OpenAI 兼容 base `https://open.bigmodel.cn/api/paas/v4/`),Claude Code 面走 claude-api-key(base `https://open.bigmodel.cn/api/anthropic`)。舰队现模板把 `disable-cooling` 全局开 true 且只挂一把 key,备份账户实际用不上——是配置问题,不是能力缺失。上游发版极密(v8 几乎按天),长期 fork 会在 conductor 上反复冲突。

## Decision

主案:lan-mac 跑上游官方镜像 `eceasy/cli-proxy-api` 钉 tag(v8.0.23),双 token failover **纯配置态达成**:同一 provider 同一 base-url 下 `api-key-entries` 挂两把 key 进 round-robin,智谱两组(openai-compatibility 与 claude-api-key)显式 `disable-cooling: false`。不 fork,不自研薄层,不引入 LiteLLM/new-api 第二套网关。LiteLLM 只留作条件备胎(客户端只走 OpenAI chat 且不能改 CPA 配置时);二开只留条件句:智谱失败形态对不上 HTTP 状态码、且 `request-scoped-errors` 按 body 规则盖不住时,补一个很小的分类函数让 conductor 现有循环换 key,以小提交往上游提,不留分叉分支,镜像 tag 加构建参数打补丁随 v8 补丁号升。

## Consequences

- 本仓形态由此定为薄资产仓:配置模板、compose、部署手册、设计与需求登记,无 Go 网关代码;「写网关代码」先回本 ADR 的条件句对表
- 流式语义继承上游:首包之前失败可换 key 重试;首包已转给客户端后不换 key 不重放,断流由 agent 重开一轮;中途接续半段 SSE 会计费两次,不做
- 冷却态默认只在内存(`save-cooldown-status` 默认 false),容器重启冷却清零可接受;升级 = 换镜像 tag 重启,配置卷与 auths 卷外置
- 舰队现有模板的全局 `disable-cooling: true`(旧版 count_tokens 规避,v7.1.16 起症状已消失)在升 v8 后应退役;同机已有别的 CPA 时不得两台同时当同一批 agent 的上游(两套冷却各算各的)
- 注入与 CH 两能力若需代码,优先侧车(sidecar)或上游小补丁形态,不改本裁定的「不 fork」主干

状态说明:proposed;验收门槛 = research-01 总台评审过 + 部署批双 key 实测验收过(判据见 REQ-001),过门槛转 accepted。
