---
id: REQ-001
title: 双 token 轮换网关
status: draft
priority: must
trace: null
---

# REQ-001:双 token 轮换网关

## Scenario

舰队 agent 经 lan-mac 网关(overcast)用智谱 GLM:单 token 限流或额度尽即断供,需要双 token failover 稳定轮换。按上游 CLIProxyAPI 配置态优先达成(ADR-0001),本 REQ 登记验收判据。2026-10-12 用户裁定 scope 收敛为两能力:本 REQ 双 token 轮换,加观测道改道 REQ-002(vector 采集原始请求日志入 ClickHouse);原 prompt 注入热改(能力二)剔除。

## Criteria

### 判据:双 token failover 轮换

判据实写,依据 research-01 已落节。

- [x] 智谱两组各挂两把 key:openai-compatibility(chat 面,base `https://open.bigmodel.cn/api/paas/v4`)用 `api-key-entries` 两行;claude-api-key(messages 面,base `https://open.bigmodel.cn/api/anthropic`)拆两条目、每条一个 `api-key`(实测该组不认 `api-key-entries`);两组显式 `disable-cooling: false`(2026-10-11 lan-mac 部署实测,起服日志 2 Claude API keys 加 2 OpenAI-compat;另补 responses 面 xai-api-key 组 2 keys,见 design-001 §1.2)
- [x] 第一把故意配错(401)加第二把有效:非流式请求得 200,日志可见先失败后换 key(2026-10-11 单 ov-03 实测:chat 组第一把尾位改错重启,同一请求 id `[98c55a49]` 先 401 warn 后 200,客户端 200;还原重启后两发干净 200)
- [x] 第一把额度尽(429)加第二把有效:同请求换 key,客户端 200(2026-10-12 15:35 生产实事件:claude 组 key `4da8...5E1N` 撞智谱 5 小时窗限,429 code 1308 带重置时间与 rate-limit headers,请求 `[216049cb]` 346ms 得 conductor 429 warn,同 id 客户端面 200(4.872s),后续 `[69183086]`/`[76ca4b00]` 持续 200;智谱额度形 = 标准 429 + rate_limit_error,落 conductor 内建 429 规则,冷却按 header 重置时间解析,无需 request-scoped-errors)
- [x] 400 坏请求停在第一把,不打第二把(请求错误不轮转)(2026-10-12 08:05 实测:max_tokens 越界 400,请求 `[4feb9f1d]` 单发 262ms,零 conductor 换 key 与冷却痕迹;对照 401 实测窗口必现 conductor warn;2026-10-11 夜 3h 窗 15 次 400 亦零轮转痕迹)
- [ ] 流式在首个内容块之后掐断上游:客户端看到错误,且不会从第二把 key 续写后半段(未测:需可控的上游中途断流手段;不重放语义继承上游,见 ADR-0001)
- [x] 客户端只见网关自己的访问 key(`access.api-keys`),两把智谱 key 不出网关(2026-10-12 核:客户端 settings.json 与 config.toml 智谱 key 形态计数 0、网关 access key 形态计数各 1;仓内全历史秘密审计零命中;智谱 key 只存部署 config,0600)
- [x] 断 lan-mac 网络再恢复:容器起来后两把 key 仍在(配置卷与 auths 卷外置),冷却状态丢属可接受(2026-10-12 08:06 实测:docker network disconnect 3 秒后恢复,存活探针 200;历次重启六客户端全载入,冷却态清零属预期)
- [x] 同机已有别的 CPA 时,本网关不与它同时当同一批 agent 的上游(部署批核对)(2026-10-12 08:05 核:docker ps -a 仅 overcast 一容器,进程面无第二 cli-proxy 实例)

## 演进与退役

- 2026-10-11 立项登记(单 ov-01);failover 判据源自 research-01 部署节验收清单,注入与 CH 判据随研究档落节回填
- 2026-10-11 单 ov-03:判据 1 形制修正(claude 组拆条目形)并实测过,判据 2 实测过;判据 3 至 5 未测,判据 1 的 responses 面(xai 组)为同期新增配置面
- 2026-10-12 余账推进轮 2(总台令):400 不轮转、key 隔离、断网恢复、同机 CPA 四项实测勾验;余流式掐断一项,待可控断流手段
- 2026-10-12 生产实事件归档:429 额度尽(智谱 5h 窗限 code 1308)同请求换 key 勾验,trace `[216049cb]`;智谱额度尽形态确认为标准 429 面,design-001 §1.3 怪形态风险对窗限形排除
- 2026-10-12 用户裁定 scope 收敛:剔除 prompt 注入热改(原能力二 v1,payload 配置态、X-Overcast-Debug 头门控),已实测三判据证据随本条归档(git 史 9dd25ae/2166adb/7bfb2c8);CH 回溯观测(原能力三留位)改道 REQ-002 承接;模板 requests 段、手册 §8、接入页注入通道同步剔除
