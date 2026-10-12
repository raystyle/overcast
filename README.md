# overcast

lan-mac 上的 LLM 网关:智谱双 token failover 稳定轮换;预留 vector 采集原始请求日志入 ClickHouse 的观测道。两能力网关的配置、部署与设计资产仓。

## 形态

薄资产仓,无自有网关代码:上游 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)(Go,MIT)官方 Docker 镜像钉 tag 运行,本仓持配置模板、compose、部署手册与设计案。不 fork 上游(裁定见 [ADR-0001](docs/adr/ADR-0001-上游选型CLIProxyAPI配置态双key不fork.md));failover 首版纯配置态达成,二开仅留条件句。

- 需求:[REQ-001 双 token 轮换网关](docs/requirements/REQ-001-三能力网关.md)(draft;7 判据已测 6,余流式掐断)+ [REQ-002 vector 采集请求日志入 ClickHouse](docs/requirements/REQ-002-vector采集请求日志入ClickHouse.md)(draft 留位)
- 设计:[design-001 三能力首版设计](docs/design/design-001-三能力首版设计.md)(failover 实写;注入节 2026-10-12 剔除作废,CH 节由 REQ-002 承接)
- 部署:[lan-mac 部署手册](docs/operations/lan-mac部署手册.md) + [deploy/](deploy/)
- 接入:[客户端接入](docs/operations/客户端接入.md)(Claude Code settings env 形、codex config.toml 加 models.json)
- 协同:本项目按 herdr + s5 双栈协同,[协同范式](docs/collaboration/README.md)

## 快览

```bash
# lan-mac 上,部署批执行工位只读
colima start
cd ~/overcast && docker compose up -d     # 镜像 eceasy/cli-proxy-api:v8.0.23,钉 tag

# 客户端
base-url: http://192.168.88.10:8317      # CC 走 /v1/messages(zp-cc-glm53 / zp-cc-glm53fh)
                                          # codex 走 /v1/responses(zp-cx-glm53 / zp-cx-glm5t)
                                          # chat 走 /v1/chat/completions,别名 zp-cx-chat
```

config.yaml 由金库渲染(占位符模板见 [deploy/config.example.yaml](deploy/config.example.yaml)),智谱 key 与网关访问 key 永不进仓。

## 边界

- 上游 CLIProxyAPI 仓只读;fork 与否的裁定归 ADR-0001,不急推
- lan-mac 只读探测;部署由部署批执行
- 发布面不动
