# Requirements 索引

> 需求登记:新需求先立 REQ 再实现,实现后回填 trace(测试或验收命令)。新建拷 0000-template.md,编号接当前最大号。状态 draft 到 implemented 到 rejected。

| id | 状态 | 优先级 | 标题 | trace |
|---|---|---|---|---|
| REQ-001 | draft | must | 双 token 轮换网关(原三能力网关,2026-10-12 收敛) | 7 判据已测 6,余流式掐断;429 额度尽换 key 生产实证 `[216049cb]`(commit ab6a080) |
| REQ-002 | draft | should | vector 采集请求日志入 ClickHouse | 留位判据;2026-10-12 立项,承接原能力三改道 |
