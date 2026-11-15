# 验证记录

截至 2026-11-10，本地执行：

- `moon test --target js`、`moon test --target wasm-gc`、`moon test --target native`：各 14 个测试通过，包含资产元数据和 GeoJSON `intersects` 查询。
- `npm test`：11 个 Node.js 集成测试通过。测试使用可检查 HTTP 请求的模拟传输，覆盖入口发现、集合分页、GET、POST、按 Item ID 查询、相对分页、POST 请求体/请求头合并、CQL2 JSON、GeoJSON `intersects`、资产相对地址解析与角色筛选、无效查询、循环与跨源分页。
- 真实服务：[Element 84 Earth Search](https://earth-search.aws.element84.com/v1) 的 `/search`，bbox=`120,30,121,31`、collection=`sentinel-2-l2a`、limit=`1`、max-pages=`2`。2026-11-10 GET 与 POST 各返回两页、两个不同 Item ID：`S2A_50RQU_20261110_0_L2A`、`S2A_51RTP_20261110_0_L2A`；达到本地页数上限时 `hasMore=true`。这是运行观察，不代表该服务所有集合和分页情形都兼容。
- 同日读取 Earth Search 根目录：ID 为 `earth-search-aws`，发现 `/v1/search` 与 `/v1/collections`，读取到 14 条 `conformsTo`；集合接口返回 9 个集合，首个 ID 为 `sentinel-2-pre-c1-l2a`。
- 2026-11-10 以 `eo:cloud_cover <= 20` 的 CQL2 JSON 对 Earth Search 发送 POST 查询，返回场景云量为 0.151473；**这一条结果不能证明过滤生效**。2026-11-15 复核发现 Earth Search 根目录的 `conformsTo` 不声明 Filter 扩展，发送同样过滤请求时返回云量 99.883515 的场景，超过阈值。Earth Search 仅用于验证请求被接收，不能作为 CQL2 过滤正确性的在线验收服务。
- 同日以 `test-fixtures/search-area.geojson` 中的 Polygon 做真实 POST `intersects` 查询，collection=`sentinel-2-l2a`、limit=`1`、max-pages=`1`，返回 `S2A_50RQU_20261110_0_L2A`；将该结果按 `data` 角色整理，得到 32 个资产，其中 `aot` 指向绝对 HTTPS 地址。这是实时查询观察，目录更新后结果可能变化。
- [GitHub Actions 线上 CI](https://github.com/wangjiale6036-dotcom/moonstac/actions/runs/42814903211)：`c050a11` 提交在 Ubuntu 下的 JS、Wasm-GC、Native MoonBit 测试与 Node.js 集成测试全部通过，结果为 `success`。
- [Mooncakes 0.1.0](https://mooncakes.io/docs/wangjiale6036-dotcom/moonstac@0.1.0) 已发布；远端 `resource.json` 中包名、版本、仓库和许可证与源码一致。独立临时项目执行 `moon add wangjiale6036-dotcom/moonstac@0.1.0`、`moon check`、`moon run cmd/main --target js` 均成功，输出包含 `"status":"ok"` 的查询体。
- 测试夹具为合成 STAC ItemCollection，没有使用真实遥感数据。

2026-11-15 复验：本地三目标各 14/14，Node.js 11/11，`validate` 样例成功。Earth Search 根目录仍有 14 条 `conformsTo`、集合接口返回 9 个集合；GET 与 POST 两页搜索各得到两个 Item；GeoJSON `intersects` 查询返回一个 Item，CLI `assets --role data` 输出 32 个资产。Microsoft Planetary Computer 的根目录声明 CQL2 JSON 与 Item Search Filter；对它执行 `eo:cloud_cover <= 20` 的 CLI POST 查询，返回三个场景，云量分别为 0.197159、9.893282、4.810465，均满足阈值。该验证只覆盖所列查询，不等于完整过滤表达式兼容。

尚未验证：macOS/Windows 线上 CI、完整 Schema 一致性、认证服务以及多个服务的复杂 GeoJSON/分页组合。
