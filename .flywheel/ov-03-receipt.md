# ov-03 receipt

- 单:ov-03,四件;接收与执行均在 lan-mac 本机,2026-10-11;payload commit `1ca8d63`,回执 commit 本笔
- 三态:过 / 缺 / 不适用;证据均为自取(请求 id、http 状态码、上游源码行),无对方陈述

## 件 1:failover 强测(过)

- 改错:部署 config(~/overcast/config.yaml)chat 组第一把 key 尾位换字符(长度 49 不变,值不回显),`docker restart overcast`,起服载入 4 clients(2 Claude API keys + 2 OpenAI-compat)
- 切换证据(同一客户端请求内换 key):请求 id `[98c55a49]`,16:13:47 warn 401 `provider=openai-compatible-glm model=glm-5.3 err={"code":"1000","message":"身份验证失败。"}`(坏 key),同一 id 16:13:49 gin_logger 200 POST /v1/chat/completions(1.874s);客户端全程 200,响应体有真实模型输出(reasoning_content 非空,usage 85,finish=length)
- 轮转旁证:首发 `[6760d9b5]` 直接 200(round-robin 起点先落在好 key 上),第二发落坏 key 触发切换;冷却开后坏 key 401 进 30 分钟冷却
- 恢复:config 自 bak-ov03-failover 还原,重启(4 clients),两发干净 200(`[157d3846]` 1.533s、`[f8fbe232]` 2.211s),还原窗口内无新 401
- 判据对应:REQ-001 能力一判据 1、2 勾验回填(判据 1 形制修正:claude 组拆条目形);判据 3 至 5 本单未测,未勾

## 件 2:Responses 协议面(过)

- 上游直探(open.bigmodel.cn,智谱 key 运行时取自部署 config):
  - `/api/v1/responses` glm-5.3 200、glm-5-turbo 200(object=response,真 Responses wire,id 形 resp_...)
  - `/api/v1/chat/completions` 双模型均 403 `model_access_denied`
  - `/api/paas/v4/responses` 404
  - 结论:上游 /api/v1 是 Responses-only 面
- 首试弃用路径:openai-compatibility 组指 /api/v1,经网关 /v1/responses 得 403(provider=openai-compatible-glm-responses,两把 key 各试一次),CPA 把 Responses 请求翻译成 chat 发上游,上游拒;该组已删
- 正解:上游 v8.0.23 `internal/config/config_types.go` 核验 `xai-api-key` 组(CodexKey 形,legacy 每条目一把 key,无 name 字段)走原生 Responses 执行器;部署 config 落 xai-api-key 双条目(base `https://open.bigmodel.cn/api/v1`,models glm-5.3 与 glm-5-turbo),起服日志 `2 xAI keys`
- 实测:经网关 `/v1/responses` glm-5.3 200(`[93bf0bea]`,object=response,status=completed,输出文本「中国的首都是北京。」);glm-5-turbo 200(`[213b7fab]`)
- 模型面:/v1/models 露 glm-5.3、glm-5-turbo、zp-glm53-claude、zp-glm53-codex;glm-5.3 直名确定性路由 xai 组(老组只露别名,无冲突)

## 件 3:接入手册(过)

- 新页 `docs/operations/客户端接入.md`:
  - Claude:settings.json env 形,ANTHROPIC_BASE_URL=http://192.168.88.10:8317,ANTHROPIC_AUTH_TOKEN 占位(值见密码管理器),DEFAULT 模型对 ANTHROPIC_MODEL=glm-5.3 加 ANTHROPIC_SMALL_FAST_MODEL=glm-5.3-flash
  - Codex:~/.codex/config.toml `[model_providers.zai]`(base_url=http://192.168.88.10:8317/v1,wire_api="responses",env_key=OVERCAST_GATEWAY_KEY)+ models.json 精简形(model_catalog_json 指向)
  - 附通用 chat 客户端与两发验活 curl
- 写前背书实测:上游 anthropic 面 glm-5.3-flash 与 glm-5.3 直探均 200;glm-5.3-flash 已注册进部署 config claude 组(两条目),经网关 /v1/messages 实测 glm-5.3-flash 200、别名 zp-glm53-claude 200、真名 glm-5.3 200
- 部署目录与仓同步:deploy/config.example.yaml 同形更新(xai 组占位符、claude 组补 flash、纪律注);手册 §5 与 README 加接入页链接
- 注意事项报总台:本仓 raystyle/overcast 为 public,内网地址按派单明示入库;若需改角色名写法,另立单裁定
- 追记(2026-10-11,总台通知):网关地址由 192.168.88.169 变更为 192.168.88.10(本机 en0 现值;新址实测 /v1/models 200,旧址已 000),本页与接入页已同步替换
- 追记二(2026-10-11,本机客户端切换实测):Claude Code settings.json 落 env 四键(BASE_URL/AUTH_TOKEN/MODEL=glm-5.3[1m]/SMALL_FAST_MODEL=glm-5.3-flash),裸 `claude -p` 两发通(15,4.2s;5,20.9s);`[1m]` 是客户端 1M 变体名,上游 400,网关加 claude 组别名映射后经网关 200(model 回显 glm-5.3)。Codex config.toml 切 model=glm-5.3 加 zai provider(wire responses,env_key),models.json 以既有条目为模板补 glm-5.3(codex 反序列化要求全套字段,缺 shell_type 报 parse 错,精简形不可用),codex exec 实测通(19,65s 首轮)。两侧原配置均备份(.bak-ov03 后缀)
- 追记三(2026-10-11,对齐官方配置参考):settings.json 改 DEFAULT 三件套形(HAIKU=glm-5.3-flash[1m]、SONNET/OPUS=glm-5.3[1m],旧 MODEL/SMALL_FAST 两键删),AUTO_COMPACT_WINDOW=1000000 补;官方原始 API 模型名仍是 glm-5.3 / glm-5.3-flash(直探复核),[1m] 只在客户端 settings 侧,网关补 flash[1m] 别名映射;codex 侧对齐官方元数据(models.json 官方形:glm-5.3 带 max 档、glm-5-turbo 200k 窗;config.toml 补 model_reasoning_effort=max),key 仍走 env_key 环境变量不落文件明文。复测:claude 裸测 25(3.8s),codex exec 50(11.8s)
- 追记四(2026-10-11,[1m] 剥离位置裁定,纠追记三的网关别名形):对照实验证明 CC 客户端在发请求前自己剥 [1m] 后缀:网关撤除全部 [1m] 别名后,裸 `claude -p` 照样通(70,6.7s,网关三连 200);而带 [1m] 的裸 curl 直打网关 400 unknown provider(网关不剥不识别)。故网关 [1m] 别名无必要,已从部署 config 与仓内模板删,接入页与手册纠偏:[1m] 是纯客户端参数,网关与上游只见原始名
- 追记五(2026-10-11 夜,稳定性排障与命名 rollout):用户侧报 "Server error mid-response",定位两条根因。一:模型名路由劫持,xai 组曾以裸名 glm-5.3 注册,CC 的 messages 流量全部被 xai 执行器抢走(`/v1/messages` 日志带 `xai_executor_request.go` 翻译层,发智谱 /api/v1 Responses 面),多一层翻译;二:上游断流 `[fa4e5d98]` 61 秒处 unexpected EOF,网关按流式语义转发截断(首包后不重放),客户端显示 mid-response 错。修正:模型名按调用方拆开(CC 面 zp-cc-glm53 / zp-cc-glm53fh,codex 面 zp-cx-glm53 / zp-cx-glm5t / zp-cx-chat;裸 glm-5.3 在 claude 组保留别名兜底),CC messages 回 claude 组原生面,codex responses 走 xai 组;部署 config 经 file watcher 热加载,仓内四文件同形改。复测:CC 90(4.7s,claude 执行器),codex 120(12.4s,xai 执行器);裸 glm-5.3-flash 已死(400,新方案用 zp-cc-glm53fh)。client settings 同步:CC DEFAULT 三件套 zp-cc 名加 [1m],codex model=zp-cx-glm53 加 models.json slug 同改
- commit 已推远端:payload `1ca8d63` 加本回执笔,push 结果见会话摘要

## 件 4:驻留注记(过)

- 手册 §2 末新增「驻留注记(真源关系)」:仓内 deploy/ 与 docs/ 是形制真源,~/overcast 运行态(config.yaml 金库渲染实例、auths/ 凭据卷、bak-* 留档、容器)是部署投影;形制变更先进仓再渲染,部署目录手改不回写即视为漂移

## 连带变更(与件 2/3 同提交 1ca8d63)

- REQ-001:判据 1/2 勾验加 trace,演进注记补 ov-03 行
- design-001 §1.2:补 responses 面(xai 组)配置要点;§1.2 两把 key 产品说明补 /api/v1
- 手册:§4 判据进度注记、§7 补 responses 面边界条
- 存量禁字清理(编辑触发的 md-guard 拦截,一并修):部署手册与 design-001 的 Unicode 箭头与破折号;collaboration/README 与 ADR-0001、AGENTS.md 尚有存量禁字,本轮未动该三文件,留给总台
- 部署目录留档:config.yaml.bak-ov03-failover(0600,改错前快照,按部署目录 bak 惯例留)

## 零改动与不适用

- 无缺件;判据 3 至 5(400 不轮转、流式掐断、断网恢复、同机 CPA 核对)不在本单四件内,未执行,REQ-001 未勾
- 协同 README 的 s5 键空间仍处本机路径过渡期,本单回执按派单指定落仓内 .flywheel/ 并 push(总台经 git 取)
