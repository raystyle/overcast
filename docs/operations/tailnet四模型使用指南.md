# tailnet 四模型使用指南

> 类型: how-to(快速上手卡,面向 tailnet 内新机器与新用户,自包含可单独转发)
> 事实源: deploy/config.example.yaml;完整步骤、坑与提速旋钮见 [客户端接入](客户端接入.md)
> 现态口径: 2026-10-13 起鉴权关(任意非空 token 或无 Authorization 头均可)

## 1. 网关与四模型

- 地址:`http://10.10.10.9:8317`(tailnet 形;LAN 形 `http://192.168.88.10:8317` 等效)
- 鉴权:无。token 填任意非空串(示例统一用 `overcast`)
- 四模型与各端别名(同名不跨端,按客户端用对应列):

| 模型 | 定位 | Claude Code(/v1/messages) | Codex(/v1/responses) | 通用 chat(/v1/chat/completions) |
|---|---|---|---|---|
| 智谱 glm-5.3 | 旗舰主力 | `zp-cc-glm53` | `zp-cx-glm53` | `zp-cx-chat` |
| 智谱 glm-5.3-flash | 快速轻量 | `zp-cc-glm53fh` | 无,同档用 `ds-cx-flash` | 无,同档用 `ds-cx-flash` |
| DeepSeek v4 pro | 深度推理 | `ds-cc-pro` | `ds-cx-pro` | `ds-cx-pro` |
| DeepSeek flash | 快速廉价 | `ds-cc-flash` | `ds-cx-flash` | `ds-cx-flash` |

## 2. Claude Code

`~/.claude/settings.json` 的 env 段(推荐形:主力智谱 + haiu 档 DeepSeek flash):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://10.10.10.9:8317",
    "ANTHROPIC_AUTH_TOKEN": "overcast",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "ds-cc-flash",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "zp-cc-glm53[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "zp-cc-glm53[1m]",
    "CLAUDE_CODE_SUBAGENT_MODEL": "ds-cc-flash",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
    "API_TIMEOUT_MS": "3000000"
  }
}
```

- DEFAULT 三件套必须全填(漏档位会漏流量);换池就换这三件:全 DeepSeek 形 = `ds-cc-flash` / `ds-cc-pro` / `ds-cc-pro`
- `[1m]` 后缀**只配智谱 CC 别名**(1M 上下文参数,CC 发请求前自剥);DeepSeek 别名一律不带后缀
- token 用 `ANTHROPIC_AUTH_TOKEN`(任意非空串即可,现态不校验)

## 3. Codex

`~/.codex/config.toml`:

```toml
model = "ds-cx-pro"                # 或 zp-cx-glm53
model_provider = "overcast"
model_reasoning_effort = "high"    # 日常 high,硬任务 max
model_catalog_json = "~/.codex/models.json"

[model_providers.overcast]
name = "overcast-gateway"
base_url = "http://10.10.10.9:8317/v1"
wire_api = "responses"
experimental_bearer_token = "overcast"
```

`~/.codex/models.json`(四条目全字段,**不可精简**,codex 反序列化缺字段即报错;DeepSeek 两条的 context_window 按 128K 保守申报,官方未核实,该值只影响 codex 侧显示与截断档,不影响网关转发):

```json
{
  "models": [
    {
      "slug": "zp-cx-glm53",
      "display_name": "zp-cx-glm53",
      "description": "Zhipu GLM-5.3 flagship",
      "default_reasoning_level": "max",
      "supported_reasoning_levels": [
        {"effort": "low", "description": "Light reasoning"},
        {"effort": "high", "description": "Enhanced reasoning"},
        {"effort": "max", "description": "Deep reasoning"}
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 0,
      "base_instructions": "",
      "supports_reasoning_summaries": true,
      "default_reasoning_summary": "none",
      "support_verbosity": false,
      "apply_patch_tool_type": "freeform",
      "truncation_policy": {"mode": "bytes", "limit": 10000},
      "context_window": 1048576,
      "max_context_window": 1048576,
      "effective_context_window_percent": 95,
      "supports_parallel_tool_calls": true,
      "experimental_supported_tools": [],
      "input_modalities": ["text"]
    },
    {
      "slug": "zp-cx-glm5t",
      "display_name": "zp-cx-glm5t",
      "description": "Zhipu GLM-5-turbo, agent-optimized",
      "default_reasoning_level": "max",
      "supported_reasoning_levels": [],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 1,
      "base_instructions": "",
      "supports_reasoning_summaries": true,
      "default_reasoning_summary": "none",
      "support_verbosity": false,
      "apply_patch_tool_type": "freeform",
      "truncation_policy": {"mode": "bytes", "limit": 10000},
      "context_window": 204800,
      "max_context_window": 204800,
      "effective_context_window_percent": 95,
      "supports_parallel_tool_calls": true,
      "experimental_supported_tools": [],
      "input_modalities": ["text"]
    },
    {
      "slug": "ds-cx-pro",
      "display_name": "ds-cx-pro",
      "description": "DeepSeek V4 Pro",
      "default_reasoning_level": "max",
      "supported_reasoning_levels": [
        {"effort": "low", "description": "Light reasoning"},
        {"effort": "high", "description": "Enhanced reasoning"},
        {"effort": "max", "description": "Deep reasoning"}
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 2,
      "base_instructions": "",
      "supports_reasoning_summaries": true,
      "default_reasoning_summary": "none",
      "support_verbosity": false,
      "apply_patch_tool_type": "freeform",
      "truncation_policy": {"mode": "bytes", "limit": 10000},
      "context_window": 131072,
      "max_context_window": 131072,
      "effective_context_window_percent": 95,
      "supports_parallel_tool_calls": true,
      "experimental_supported_tools": [],
      "input_modalities": ["text"]
    },
    {
      "slug": "ds-cx-flash",
      "display_name": "ds-cx-flash",
      "description": "DeepSeek Flash, fast and cheap",
      "default_reasoning_level": "high",
      "supported_reasoning_levels": [
        {"effort": "low", "description": "Light reasoning"},
        {"effort": "high", "description": "Enhanced reasoning"}
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 3,
      "base_instructions": "",
      "supports_reasoning_summaries": true,
      "default_reasoning_summary": "none",
      "support_verbosity": false,
      "apply_patch_tool_type": "freeform",
      "truncation_policy": {"mode": "bytes", "limit": 10000},
      "context_window": 131072,
      "max_context_window": 131072,
      "effective_context_window_percent": 95,
      "supports_parallel_tool_calls": true,
      "experimental_supported_tools": [],
      "input_modalities": ["text"]
    }
  ]
}
```

说明:DeepSeek 官方无 /responses 端点,codex 的 responses 请求由网关翻译成 chat 发上游,已实测;`base_url` 写到 `/v1` 为止。

## 4. 通用 OpenAI SDK / curl

```bash
# chat 面,任何 OpenAI 兼容客户端
curl -s http://10.10.10.9:8317/v1/chat/completions \
  -H "Authorization: Bearer overcast" -H 'Content-Type: application/json' \
  -d '{"model":"ds-cx-flash","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}'

# messages 面,Anthropic SDK 形
curl -s http://10.10.10.9:8317/v1/messages \
  -H "Authorization: Bearer overcast" -H 'anthropic-version: 2023-06-01' \
  -H 'Content-Type: application/json' \
  -d '{"model":"ds-cc-pro","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}'
```

OpenAI SDK 形:base_url `http://10.10.10.9:8317/v1`,api_key 任意非空串。

## 5. 验活,新机器两发 200 即通

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://10.10.10.9:8317/v1/messages \
  -H 'Authorization: Bearer overcast' -H 'anthropic-version: 2023-06-01' \
  -H 'Content-Type: application/json' \
  -d '{"model":"ds-cc-flash","max_tokens":8,"messages":[{"role":"user","content":"ping"}]}'

curl -s -o /dev/null -w '%{http_code}\n' http://10.10.10.9:8317/v1/responses \
  -H 'Authorization: Bearer overcast' -H 'Content-Type: application/json' \
  -d '{"model":"ds-cx-flash","input":"ping","max_output_tokens":8}'
```

## 6. 边界与注意

- 需在 tailnet 内(或 LAN 可达);两形地址等效,任选
- 智谱池有 5 小时窗限(429 code 1308):网关自动换 key 与备池,客户端无感;DeepSeek 池额度独立
- `[1m]` 是智谱 CC 面 1M 上下文参数:日常会话不开(长尾延迟),长仓调查再开
- 思考是延迟主体:DeepSeek flash 与智谱 glm5t 自行决定思考,适合短工具循环;pro/glm53 强制思考,首答偏慢属正常
- 网关鉴权现为关闭态(内网裁定):任何可达本机的设备均可使用,请勿把地址外发到不可信网络
