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
- 2026-10-12 可行性研究吸收(S005):现 tag 的 `request-log` 一请求一文件且流式同步写盘在热路径,不作验收路径;推荐主线 = 上游小补丁(进程内异步 JSONL,有界队列满只丢观测事件)+ vector file source 尾随 + ClickHouse 头表加块表;判据细化候六项裁定(补丁路线、CH 落机、TTL 天数、正文访问面、auth_id 稳定性核、commercial-mode 与 WRITABLE_PATH 现状),裁定后按 S005 判据建议五条替换本页留位判据
- 2026-10-12 用户裁定:补丁路线准行(S005 主线,补丁以小提交往上游提不留分叉);ClickHouse 落机、TTL 三数、正文访问面延后到补丁验证毕再裁;commercial-mode 与 WRITABLE_PATH 现状已核均未设(日志目录落容器层,补丁部署须配独立卷);补丁阶段验证面 = JSONL 卷写出质量与热路径旁路性,CH 入库与 vector 管道随后
- 2026-10-12 补丁上线并验证:分支 `feat/dialog-observation`(commit `4e464508`),镜像 `v8.0.23-dialog1` 部署 lan-mac,dialoglogs 卷出流。S005 判据建议五条中三条实测过:判据 1(JSONL 卷全量事件,vector 只读该卷)、判据 2(队列满丢事件不挡请求:并发单测 + 线上延迟分布与补丁前同区间)、判据 5(单行 64KiB 内,超长分块);判据 3 与 4(CH 回放与 TTL)候库就绪。回放实证:729KB 请求体重组合法 JSON,135 SSE 事件完整。余项:vector 管道、CH 落机与 TTL 裁定(补丁 PR 往上游提一项经同日用户裁定撤销,转入二开自维护,见 ADR-0001 裁定注)
