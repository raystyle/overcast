# overcast

lan-mac 上的多池 LLM 网关:智谱 GLM 双 key 轮换,zyuncs 与 DeepSeek 官方备池,预留 vector 采集请求日志入 ClickHouse 的观测道。薄资产仓,无网关代码:上游 CLIProxyAPI 官方镜像钉 tag 运行,本仓管配置模板、部署与文档(裁定见 [ADR-0001](docs/adr/ADR-0001-上游选型CLIProxyAPI配置态双key不fork.md))。

## 快览

```bash
# lan-mac 上,部署批执行工位只读
colima start
cd ~/overcast && ./up.sh                             # 镜像 eceasy/cli-proxy-api:v8.0.23,钉 tag

# 客户端
base-url: http://192.168.88.10:8317      # CC 走 /v1/messages,codex 走 /v1/responses
                                         # 别名与端口速查见 docs/reference/客户端速查.md
```

## 下一步

- 部署:[lan-mac 部署手册](docs/operations/lan-mac部署手册.md)(how-to,含验收清单)
- 接入:[客户端接入](docs/operations/客户端接入.md)(how-to)+ [客户端速查](docs/reference/客户端速查.md)
- 查行为:[网关行为参考](docs/reference/网关行为参考.md)(状态码、换 key、冷却、已知边界)
- 判据与进度:[REQ-001 双 token 轮换](docs/requirements/REQ-001-双token轮换网关.md)、[REQ-002 观测道](docs/requirements/REQ-002-vector采集请求日志入ClickHouse.md)、[REQ-003 DeepSeek 双面接入](docs/requirements/REQ-003-DeepSeek官方供应商双面接入.md)
- 选型为什么:[上游选型](docs/explanation/上游选型.md)、[ADR-0001](docs/adr/ADR-0001-上游选型CLIProxyAPI配置态双key不fork.md)
- 维护者:[AGENTS.md](AGENTS.md)、[协同范式](docs/collaboration/README.md)

## 秘密

config.yaml 由金库渲染(占位符模板见 [deploy/config.example.yaml](deploy/config.example.yaml)),智谱与 zyuncs key、DeepSeek key、网关访问 key 永不进仓。

## 边界

- 上游 CLIProxyAPI 仓只读;fork 与否的裁定归 ADR-0001,不急推
- lan-mac 只读探测;部署由部署批执行
- 发布面不动
