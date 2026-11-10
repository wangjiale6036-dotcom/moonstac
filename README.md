# MoonSTAC

MoonBit 编写的 STAC Item Search 核心与 Node.js 命令行工具。输入空间范围、时间和集合，向 STAC API `/search` 发送 GET 或 POST 请求，逐页读取 ItemCollection，提取 Item ID、集合、时间和资产链接。JSON 解析、结构检查、查询体构造及 `next` 链接解释由 MoonBit 完成；Node.js 负责 HTTP 和文件 I/O。

**状态：公开开发预览。** 源码已发布在 [GitHub](https://github.com/wangjiale6036-dotcom/moonstac)，MoonBit 库已发布为 [Mooncakes 0.1.0](https://mooncakes.io/docs/wangjiale6036-dotcom/moonstac@0.1.0)。当前实现支持 STAC Item 1.0.0/1.1.0 的一部分核心结构检查，不是完整 JSON Schema 验证器，也未获得 OGC 认证。已在 Earth Search 公网 API 验证入口发现、集合浏览、GET、POST 和两页查询，详见[验证记录](docs/VALIDATION.zh-CN.md)。

参赛说明与 MVP 验收证据见[Markdown 项目申报书](docs/PROJECT_PROPOSAL.zh-CN.md)。Mooncakes 0.1.0 是早期预览版；仓库中新增的 GeoJSON 查询和资产清单功能尚未发布到该版本。

## 快速开始

需要 MoonBit 工具链与 Node.js 20 或更新版本。

作为库使用：`moon add wangjiale6036-dotcom/moonstac@0.1.0`。独立消费项目已成功调用 `search_request`。

```sh
moon test
npm test
node cli.mjs validate test-fixtures/one-page.json
node cli.mjs discover --url https://earth-search.aws.element84.com/v1/
node cli.mjs collections --url https://earth-search.aws.element84.com/v1/collections
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --bbox 120,30,121,31 --collection sentinel-2-l2a --limit 2 --max-pages 2
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --bbox 120,30,121,31 --collection sentinel-2-l2a --method POST --filter-file test-fixtures/cloud-cover-filter.json --limit 1
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --intersects-file test-fixtures/search-area.geojson --collection sentinel-2-l2a --method POST --limit 1
node cli.mjs assets --url https://earth-search.aws.element84.com/v1/search --bbox 120,30,121,31 --collection sentinel-2-l2a --limit 1 --role data
```

`npm test` 会先编译 MoonBit JS 桥接模块。首次单独运行 CLI 之前先执行 `npm run build`。上面的在线查询已实际执行过。`search` 输出 JSON，其中 `items` 为扁平列表，`pages` 为实际读取页数，`hasMore` 表示达到页数上限时仍有下一页。

`search` 可用参数：`--url`、`--bbox west,south,east,north`、`--intersects-file geometry.json`、`--datetime`、可重复的 `--collection`、可重复的 `--id`、`--filter-file`、`--limit`、`--method GET|POST`、`--max-pages`。`--bbox` 可省略，例如仅按 Item ID 查询；与 `--intersects-file` 互斥。`--intersects-file` 接收 GeoJSON **Geometry**（不是 Feature），需搭配 `--method POST`。`--filter-file` 读取 CQL2 JSON 表达式，也需搭配 POST。默认 GET、每页 10 条、最多 5 页。`--url` 指向具体的 `/search` 端点。`collections` 使用 `--url` 和可选 `--max-pages`。分页默认只允许同源 URL；如确需访问跨源 `next` 链接，可显式指定 `--allow-cross-origin true`。命令不会下载资产文件。

`assets` 命令接受相同搜索参数，并额外支持可重复的 `--asset <key>` 和 `--role <role>`；输出匹配的 Item ID、集合、时间、资产 key、标题、媒体类型、角色和绝对 URL。相对资产地址先以 Item 的 `self` 链接为基准；缺少 `self` 时以返回该 Item 的搜索页地址为基准。输出仅是清单，不下载数据。`search` 同时保留资产的原始 `href`，并给出 `resolvedHref`。

## 支持范围

- 解析 ItemCollection / STAC Item，检查 `stac_version`、`type`、`id`、GeoJSON 几何坐标层级与多边形闭合、`bbox`、RFC 3339 时间或时间区间、`links`、`assets[*].href` 等关键结构；输出保留几何和完整 `properties`。
- 解析 STAC API 根目录与 Collections 页，发现搜索/集合入口并列出集合 ID、标题、说明、许可。
- 生成包含可选 `bbox`、GeoJSON `intersects`、`datetime`、`collections`、`ids`、`limit` 的 Item Search 请求；验证经纬度范围、边界框顺序与 GeoJSON 几何结构。
- 支持一组明确的 CQL2 JSON 操作符（比较、`between`、`and`、`or`、`not`），可按 `eo:cloud_cover` 等 Item 属性过滤；不支持的操作符会明确报错。
- 处理 GET/POST `next` 链接、相对地址、`body`、`headers` 和 `merge`；限制页数并检测重复请求。
- 从资产中提取标题、媒体类型、角色及 Item `self` 链接，生成可筛选的资产清单。
- MoonBit 公共 API：`parse_item`、`parse_page`、`parse_landing`、`parse_collections`、`search_body`；JS 桥接 API：`search_request`、`page_summary`、`landing_summary`、`collections_summary`。

当前不检查 GeoJSON 自交与环方向、扩展 Schema、所有 STAC Item 字段语义，也不支持完整 CQL2、排序或字段选择。`validate` 输出的资产链接仍是原始值；`search` 和 `assets` 增加绝对地址解析。API 认证及速率限制由调用环境处理。不要把 `validate` 的通过结果视为完整 STAC 合规证明。

## 选题与依据

STAC 是地理空间影像和其他时空资产的目录规范；Item Search API 定义跨集合搜索和分页。项目价值在于给 MoonBit 应用提供可复用的数据目录入口，并让查询与解析核心跨目标复用。2026-11-10 对 MoonBit 生态索引和公开搜索的初步检索未找到同名或直接等价的 MoonBit STAC API 客户端；公开检索不涵盖未公开申报或未被索引的项目，不能保证赛事查重通过。详见[选题与风险记录](docs/RESEARCH.zh-CN.md)。

规范来源：[OGC STAC API 1.0](https://docs.ogc.org/cs/25-005/25-005.html)、[STAC Filter 扩展](https://github.com/stac-api-extensions/filter)、[STAC Item 1.0.0 Schema](https://schemas.stacspec.org/v1.0.0/item-spec/json-schema/item.json)、[STAC Item 1.1.0 Schema](https://schemas.stacspec.org/v1.1.0/item-spec/json-schema/item.json)。许可：Apache-2.0。
