# AGENTS.md: 给在本仓工作的 agent

## 这是什么仓

overcast:lan-mac 上智谱双 token failover + prompt 实时注入 + ClickHouse 回溯观测的 LLM 网关资产仓。**薄资产仓,无网关代码**:上游 CLIProxyAPI 官方镜像钉 tag 运行,本仓管配置模板、compose、手册、设计与需求登记。若发现自己在写 Go 网关代码,停下来,先读 ADR-0001 与 design-001 的裁定与条件句。

## 三边界(立项单 ov-01 固化)

1. 上游 router-for-me/CLIProxyAPI 仓只读;补丁走小提交往上游提,不留分叉分支
2. lan-mac 只读探测;部署执行归部署批,不代跑
3. 发布面不动

## 秘密纪律

智谱 token 与网关访问 key 永不进仓:`config.yaml` 由金库渲染(0600),仓内只有 `deploy/config.example.yaml` 占位符模板;`auths/` 凭据卷不进仓。研究档与设计案同样只引占位符名,不引真值。

## 文档框架(evo-doc doc-gov)

- 新需求先立 REQ 再实现(`docs/requirements/`,draft 到 implemented 回填 trace;判据必须是可检验句)
- 不可逆技术选择先立 ADR(`docs/adr/`,proposed 到 accepted 到 superseded 互指)
- 课题证据走研究档(`docs/research/`,S 编号一题一篇,结论标六态;「没验证」不写成「已验证」)
- 部署与运维面在 `docs/operations/`;设计案在 `docs/design/`

## 协同范式(herdr + s5 双栈)

本项目跨机协同按 herdr 飞轮协议跑:总台派单走 herdr,轮次档三件套(brief/state/receipt)按 [协同范式](docs/collaboration/README.md) 落盘。凡收到派单:先读 brief,无歧义写 state 已接,按检查点自更,收工落 receipt 逐件对账;s5 CLI 首版前轮次档走本机路径过渡。

## 提交纪律

- 提交信息一句话讲清改了什么;REQ/ADR 变更与对应实现同提交
- 改公开行为同步改文档面(README/手册是投影,单一权威源在 docs/ 与 deploy/)
