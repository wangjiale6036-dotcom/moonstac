# 验证记录

截至 2026-11-10，本地执行：

- `moon test --target js`、`moon test --target wasm-gc`、`moon test --target native`：各 14 个测试通过，包含资产元数据和 GeoJSON `intersects` 查询。
- `npm test`：11 个 Node.js 集成测试通过。测试使用可检查 HTTP 请求的模拟传输，覆盖入口发现、集合分页、GET、POST、按 Item ID 查询、相对分页、POST 请求体/请求头合并、CQL2 JSON、GeoJSON `intersects`、资产相对地址解析与角色筛选、无效查询、循环与跨源分页。
- 真实服务：[Element 84 Earth Search](https://earth-search.aws.element84.com/v1) 的 `/search`，bbox=`120,30,121,31`、collection=`sentinel-2-l2a`、limit=`1`、max-pages=`2`。2026-11-10 GET 与 POST 各返回两页、两个不同 Item ID：`S2A_50RQU_20261110_0_L2A`、`S2A_51RTP_20261110_0_L2A`；达到本地页数上限时 `hasMore=true`。这是运行观察，不代表该服务所有集合和分页情形都兼容。
- 同日读取 Earth Search 根目录：ID 为 `earth-search-aws`，发现 `/v1/search` 与 `/v1/collections`，读取到 14 条 `conformsTo`；集合接口返回 9 个集合，首个 ID 为 `sentinel-2-pre-c1-l2a`。
- 同日以 `eo:cloud_cover <= 20` 的 CQL2 JSON 对 Earth Search 发送 POST 查询，返回 `S2A_50RQU_20261110_0_L2A`，Item 属性中的 `eo:cloud_cover=0.151473`。
- 同日以 `test-fixtures/search-area.geojson` 中的 Polygon 做真实 POST `intersects` 查询，collection=`sentinel-2-l2a`、limit=`1`、max-pages=`1`，返回 `S2A_50RQU_20261110_0_L2A`；将该结果按 `data` 角色整理，得到 32 个资产，其中 `aot` 指向绝对 HTTPS 地址。这是实时查询观察，目录更新后结果可能变化。
- [GitHub Actions 线上 CI](https://github.com/wangjiale6036-dotcom/moonstac/actions/runs/42810697952)：Ubuntu 下 JS、Wasm-GC、Native 的 MoonBit 测试与 Node.js 集成测试全部通过，结果为 `success`。
- [Mooncakes 0.1.0](https://mooncakes.io/docs/wangjiale6036-dotcom/moonstac@0.1.0) 已发布；远端 `resource.json` 中包名、版本、仓库和许可证与源码一致。独立临时项目执行 `moon add wangjiale6036-dotcom/moonstac@0.1.0`、`moon check`、`moon run cmd/main --target js` 均成功，输出包含 `"status":"ok"` 的查询体。
- 测试夹具为合成 STAC ItemCollection，没有使用真实遥感数据。

尚未验证：macOS/Windows 线上 CI、完整 Schema 一致性、其他 STAC 服务及认证服务。
