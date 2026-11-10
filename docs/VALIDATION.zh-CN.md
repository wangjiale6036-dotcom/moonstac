# 验证记录

截至 2026-11-10，本地执行：

- `moon test`：6 个 MoonBit 测试通过。
- `moon test --target js`、`moon test --target wasm-gc`、`moon test --target native`：各 6 个测试通过。
- `npm test`：8 个 Node.js 集成测试通过。测试使用可检查 HTTP 请求的模拟传输，覆盖入口发现、集合分页、GET、POST、按 Item ID 查询、相对分页、POST 请求体/请求头合并、无效查询与循环分页。
- 真实服务：[Element 84 Earth Search](https://earth-search.aws.element84.com/v1) 的 `/search`，bbox=`120,30,121,31`、collection=`sentinel-2-l2a`、limit=`1`、max-pages=`2`。2026-11-10 GET 与 POST 各返回两页、两个不同 Item ID：`S2A_50RQU_20261110_0_L2A`、`S2A_51RTP_20261110_0_L2A`；达到本地页数上限时 `hasMore=true`。这是运行观察，不代表该服务所有集合和分页情形都兼容。
- 同日读取 Earth Search 根目录：ID 为 `earth-search-aws`，发现 `/v1/search` 与 `/v1/collections`，读取到 14 条 `conformsTo`；集合接口返回 9 个集合，首个 ID 为 `sentinel-2-pre-c1-l2a`。
- [GitHub Actions 线上 CI](https://github.com/wangjiale6036-dotcom/moonstac/actions/runs/42809527800)：Ubuntu 下 JS、Wasm-GC、Native 的 MoonBit 测试与 Node.js 集成测试全部通过，结果为 `success`。
- 测试夹具为合成 STAC ItemCollection，没有使用真实遥感数据。

尚未验证：macOS/Windows 线上 CI、完整 Schema 一致性、其他 STAC 服务及认证服务。
