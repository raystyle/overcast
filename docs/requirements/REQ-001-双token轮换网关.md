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

- [x] 智谱两组各挂两把 key:openai-compatibility(chat 面,base `https://open.bigmodel.cn/api/paas/v4`)用 `api-key-entries` 两行;claude-api-key(messages 面,base `https://open.bigmodel.cn/api/anthropic`)拆两条目、每条一个 `api-key`(实测该组不认 `api-key-entries`);两组显式 `disable-cooling: false`(2026-10-11 lan-mac 部署实测,起服日志 2 Claude API keys 加 2 OpenAI-compat;另补 responses 面 xai-api-key 组 2 keys,形制见 config.example.yaml xai 组)
- [x] 第一把故意配错(401)加第二把有效:非流式请求得 200,日志可见先失败后换 key(2026-10-11 单 ov-03 实测:chat 组第一把尾位改错重启,同一请求 id `[98c55a49]` 先 401 warn 后 200,客户端 200;还原重启后两发干净 200)
- [x] 第一把额度尽(429)加第二把有效:同请求换 key,客户端 200(2026-10-12 15:35 生产实事件:claude 组 key `4da8...5E1N` 撞智谱 5 小时窗限,429 code 1308 带重置时间与 rate-limit headers,请求 `[216049cb]` 346ms 得 conductor 429 warn,同 id 客户端面 200(4.872s),后续 `[69183086]`/`[76ca4b00]` 持续 200;智谱额度形 = 标准 429 + rate_limit_error,落 conductor 内建 429 规则,冷却按 header 重置时间解析,无需 request-scoped-errors)
- [x] 400 坏请求停在第一把,不打第二把(请求错误不轮转)(2026-10-12 08:05 实测:max_tokens 越界 400,请求 `[4feb9f1d]` 单发 262ms,零 conductor 换 key 与冷却痕迹;对照 401 实测窗口必现 conductor warn;2026-10-11 夜 3h 窗 15 次 400 亦零轮转痕迹)
- [x] 流式在首个内容块之后掐断上游:客户端看到错误,且不会从第二把 key 续写后半段(2026-10-15 旁路实测过:同镜像 v8.0.23-dialog4 独立实例 + mock 上游两把测试 key,mock 在首个内容块后硬断 TCP;客户端恰收 3 事件无 message_stop 无拼接,断后 35 秒过 30s 重试窗 mock 零第二次 POST,对照试验同请求 401 时连打两 key 证明 mock 能抓轮转,零轮转结论成立;旁路法不触生产容器)
- [x] 客户端只见网关自己的访问 key(`access.api-keys`),两把智谱 key 不出网关(2026-10-12 核:客户端 settings.json 与 config.toml 智谱 key 形态计数 0、网关 access key 形态计数各 1;仓内全历史秘密审计零命中;智谱 key 只存部署 config,0600)
- [x] 断 lan-mac 网络再恢复:容器起来后两把 key 仍在(配置卷与 auths 卷外置),冷却状态丢属可接受(2026-10-12 08:06 实测:docker network disconnect 3 秒后恢复,存活探针 200;历次重启六客户端全载入,冷却态清零属预期)
- [x] 同机已有别的 CPA 时,本网关不与它同时当同一批 agent 的上游(部署批核对)(2026-10-12 08:05 核:docker ps -a 仅 overcast 一容器,进程面无第二 cli-proxy 实例)

## 演进与退役

- 2026-10-11 立项登记(单 ov-01);failover 判据源自 research-01 部署节验收清单,注入与 CH 判据随研究档落节回填
- 2026-10-11 单 ov-03:判据 1 形制修正(claude 组拆条目形)并实测过,判据 2 实测过;判据 3 至 5 未测,判据 1 的 responses 面(xai 组)为同期新增配置面
- 2026-10-12 余账推进轮 2(总台令):400 不轮转、key 隔离、断网恢复、同机 CPA 四项实测勾验;余流式掐断一项,待可控断流手段
- 2026-10-12 生产实事件归档:429 额度尽(智谱 5h 窗限 code 1308)同请求换 key 勾验,trace `[216049cb]`;智谱额度尽形态确认为标准 429 面,升级阶梯的怪形态风险对窗限形排除
- 2026-10-12 用户裁定 scope 收敛:剔除 prompt 注入热改(原能力二 v1,payload 配置态、X-Overcast-Debug 头门控),已实测三判据证据随本条归档(git 史 9dd25ae/2166adb/7bfb2c8);CH 回溯观测(原能力三留位)改道 REQ-002 承接;模板 requests 段、手册 §8、接入页注入通道同步剔除
- 2026-10-12 供应池扩至三上游:grok 增 zyuncs 备供应商(llm.api.zyuncs.com,xai 与 claude 两组各一条目,模型名 z-ai/glm-5.3 形);17:16 载入 8 clients;同窗双智谱 key 相继 429(1308,重置 17:33/18:55)期间 zyuncs 接力,四笔双 429 请求(`a19fb3b2`/`0ffe62b1`/`6accbe40`/`f8cb6fd2`)客户端面全 200,messages 与 responses 双面验证;模板同步回填(SHAPE_MATCH,commit f08bc90)
- 2026-10-15 表行 3(流式掐断)旁路实测勾验,判据全绿收官;同日 15:53 生产实事件暴露智谱新错误形态:1308 限流装在 HTTP 200 的 SSE 流内(`event: error`)原样透传,不判失败不冷却不轮换,客户端直渲染上游原文;旁路复现证实并证实 `request-scoped-errors` 对该形态无效(只评估已成 error 对象路径);二开补丁 `1757fbf0`(dialog5)执行器流开局 hold 兜住:前导事件扣至首个内容块,hold 期 error 帧映射 429 转流错误,conductor bootstrap 判失败冷却轮转,字节未到客户端;旁路验证撞限 key 的请求同请求内换健康 key 得完整流,撞后流量全走健康 key
