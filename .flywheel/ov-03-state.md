# ov-03 state

- 单:ov-03(failover 强测 / Responses 协议面 / 接入手册 / 驻留注记,四件)
- 2026-10-11 16:1x 已接,在办
- 2026-10-11 16:2x 四件齐,收尾中:件1 failover 证据在(请求 98c55a49 同 id 401 转 200,还原后干净);件2 /api/v1 走 xai-api-key 组,/v1/responses 双模型 200;件3 接入页已写并背书实测;件4 真源注记入手册 §2
- 2026-10-11 16:3x 已交:四件全过,详见 ov-03-receipt.md;payload commit 1ca8d63,回执笔随后,push origin main
- 2026-10-11 23 时段追加:能力二 v1(思考块调试注入,配置态 payload + X-Overcast-Debug 头门控)。直探已证:effort 认(low/high 差异显著)、budget 不认、system 全换。部署 config 已落 requests.payload 三规则并重启载入;仓内模板/design §2/REQ 判据/手册 §8 已回写。剩:网关门控对照实测(分类器临时不可用,Bash 被卡),过测后 REQ 勾验 + receipt 追记七 + commit
- 2026-10-11 深夜追加:源码比对(config_types.go + 上游 v8.0.23 官方样例)发现并修复**门控嵌套坑**:headers/from-protocol 必须嵌在每个 models 条目内,写规则层被 Go yaml 静默丢弃,首版三规则实为无门控裸规则。已修:部署 config 与仓内模板同形重写(双名字兜底 + from-protocol 标来源;protocol 枚举 openai/gemini/claude/codex/antigravity,xai 执行器用 codex 确认无误);design §2.1 与手册 §8 回填坑记载;新增 anchor 假 thinking 锚注入规则(override-raw)。门控对照实测仍待跑
- 2026-10-11 深夜用户改令:能力二暂停,优先保 failover 稳定不卡。诊断:6 clients 全载入、近3h 零换key警告零冷却,自愈稳态;卡=305/317 请求是 /v1/messages 的 glm-5.3 思考模型大上下文固有延迟,17 个 499 是客户端超时断开。已把部署 config 的 requests 段整段撤下(模板保留修正形),待 docker restart 收口(分类器抖动卡了 Bash,重启未执行)
- 2026-10-11 23:55 用户 `!` 执行重启完成:六客户端全载入,flash 存活探针 200,网关回到纯 failover 干净面。延迟画像(近2h 232 请求):>=1s 占 203,>=10s 占 111,证实卡=模型固有延迟非网关故障。附记:CC auto 权限模式的分类器走 zp-cc-glm53[1m] 主模型(思考模型),网关一忙分类器就超时,卡 Bash;ops 重会话建议手动权限模式。glm-5.3-flash 默认也开思考,haiku 面不快。仓内能力二相关改动(template/design/REQ/手册/state)仍未 commit,待稳
- 秘密纪律提醒(自警):ov-03 全程智谱 key 与网关 access key 不进 argv 回显、不进 transcript、不进仓
