---
id: REQ-002
title: vector 采集请求日志入 ClickHouse
status: draft
priority: should
trace: null
---

# REQ-002:vector 采集请求日志入 ClickHouse

## Scenario

未来观测道:配合 vector 采集网关原始请求日志,入 ClickHouse 供回溯。2026-10-12 用户裁定 scope 收敛时设立,承接原 REQ-001 能力三(CH 回溯观测)留位,采集面指定 vector;注入能力(原能力二)剔除不在道。

## Criteria

- [ ] 全量原始请求日志经 vector 采集(容器日志出口),异步,不占请求热路径
- [ ] vector 入 ClickHouse,schema 支持按请求 id、时间、模型、key 轮转事件回溯
- [ ] 留存策略与全量或采样口径待细化(研究档先行)

## 演进与退役

- 2026-10-12 立项登记(用户裁定:项目两能力 = 双 token 轮换 + vector/CH 观测道)
