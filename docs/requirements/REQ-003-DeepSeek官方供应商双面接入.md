---
id: REQ-003
title: DeepSeek 官方供应商双面接入
status: implemented
priority: should
trace: 2026-10-13 部署位渲染上线,六路探活(ds-cc-pro/ds-cc-flash on messages,ds-cx-pro/ds-cx-flash on responses 与 chat)全 200,智谱别名回归 200;实现与模板/脚本/文档同日提交
---

# REQ-003:DeepSeek 官方供应商双面接入

## Scenario

内网网关扩第三供应商:DeepSeek 官方 API(2026-10-13 用户需求,官方文档口径)。双模型:pro(`deepseek-v4-pro`)与 flash(`deepseek-flash`,旧名 deepseek-v4-flash / deepseek-v4 已弃用)。面拆分:Anthropic 兼容面 `https://api.deepseek.com/anthropic` 供 Claude Code(messages);OpenAI 面 `https://api.deepseek.com` 供 codex 与 chat 客户端(codex 的 responses 请求经网关 openai-compatibility 执行器翻译成 chat 发上游;上游是 chat-only,与智谱 /api/v1 Responses-only 情形相反,翻译路径在该上游是正道)。别名按仓规分调用方:CC 面 `ds-cc-pro` / `ds-cc-flash`,codex 与 chat 面 `ds-cx-pro` / `ds-cx-flash`。

## Criteria

- [x] /v1/messages 以 ds-cc-pro 与 ds-cc-flash 各一发 200 且应答合法(实测 200,body 合法:pro 带 thinking 块,flash 直答)
- [x] /v1/responses 以 ds-cx-pro 与 ds-cx-flash 各一发 200(Responses→chat 翻译路径在 chat-only 上游实测 200)
- [x] /v1/chat/completions 以 ds-cx-pro 与 ds-cx-flash 各一发 200
- [x] 回归:智谱别名(zp-cc-glm53 / zp-cx-glm53 / zp-cx-chat)仍 200
- [x] DeepSeek key 不入仓不入 transcript(录入走 GUI 隐藏框 ds-token-entry.sh,渲染后临时件已删)

## 演进与退役

- 2026-10-13 立项(用户提出接入 DeepSeek 官方供应商,pro+flash 双模型,不同 agent api 不同别名;官方口径 base_url 与模型名以用户当日贴文档为准)
- 2026-10-13 上线。弯路留档:首渲染锚模板组序假设,而部署位组序为 openai-compatibility → xai → claude(与模板不同),两组插反:chat 条目落 xai 组(legacy 形读不到 api-key-entries,空 key 上游 401),claude 条目落 openai 组(OpenAI 执行器打 /anthropic 面 401),chat 面 503 无主。回滚备份后 v2 渲染锚实际文件组界,并加 YAML 结构断言(组归属、api-key 在位、xai 组无 deepseek 污染)才落盘,九发探活全绿。渲染纪律沉淀:部署位组序可与模板不同,渲染脚本必须锚实件+渲染后结构断言
