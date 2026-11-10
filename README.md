# MoonSTAC

MoonBit 编写的 STAC Item Search 核心与 Node.js 命令行工具。输入空间范围、时间和集合，向 STAC API `/search` 发送 GET 或 POST 请求，逐页读取 ItemCollection，提取 Item ID、集合、时间和资产链接。JSON 解析、结构检查、查询体构造及 `next` 链接解释由 MoonBit 完成；Node.js 负责 HTTP 和文件 I/O。

**状态：公开开发预览。** 源码已发布在 [GitHub](https://github.com/wangjiale6036-dotcom/moonstac)。当前实现支持 STAC Item 1.0.0/1.1.0 的一部分核心结构检查，不是完整 JSON Schema 验证器，也未获得 OGC 认证。已在 Earth Search 公网 API 验证入口发现、集合浏览、GET、POST 和两页查询，详见[验证记录](docs/VALIDATION.zh-CN.md)。

## 快速开始

需要 MoonBit 工具链与 Node.js 20 或更新版本。

```sh
moon test
npm test
node cli.mjs validate test-fixtures/one-page.json
node cli.mjs discover --url https://earth-search.aws.element84.com/v1/
node cli.mjs collections --url https://earth-search.aws.element84.com/v1/collections
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --bbox 120,30,121,31 --collection sentinel-2-l2a --limit 2 --max-pages 2
```

`npm test` 会先编译 MoonBit JS 桥接模块。首次单独运行 CLI 之前先执行 `npm run build`。上面的在线查询已实际执行过。`search` 输出 JSON，其中 `items` 为扁平列表，`pages` 为实际读取页数，`hasMore` 表示达到页数上限时仍有下一页。

`search` 可用参数：`--url`、`--bbox west,south,east,north`、`--datetime`、可重复的 `--collection`、可重复的 `--id`、`--limit`、`--method GET|POST`、`--max-pages`。`--bbox` 可省略，例如仅按 Item ID 查询。默认 GET、每页 10 条、最多 5 页。`--url` 指向具体的 `/search` 端点。`collections` 使用 `--url` 和可选 `--max-pages`。命令不会下载资产文件。

## 支持范围

- 解析 ItemCollection / STAC Item，检查 `stac_version`、`type`、`id`、`geometry`/`bbox`、`properties.datetime` 或时间区间、`links`、`assets[*].href` 等关键结构。
- 解析 STAC API 根目录与 Collections 页，发现搜索/集合入口并列出集合 ID、标题、说明、许可。
- 生成包含可选 `bbox`、`datetime`、`collections`、`ids`、`limit` 的 Item Search 请求；验证经纬度范围和边界框顺序。
- 处理 GET/POST `next` 链接、相对地址、`body`、`headers` 和 `merge`；限制页数并检测重复请求。
- MoonBit 公共 API：`parse_item`、`parse_page`、`parse_landing`、`parse_collections`、`search_body`；JS 桥接 API：`search_request`、`page_summary`、`landing_summary`、`collections_summary`。

当前不检查完整 GeoJSON 坐标结构、扩展 Schema、所有 STAC Item 字段语义、日期字符串格式，也不支持 Filter/CQL2、intersects、排序或字段选择。资产链接保持 API 原始值，可能是相对路径。API 认证及速率限制由调用环境处理。不要把 `validate` 的通过结果视为完整 STAC 合规证明。

## 选题与依据

STAC 是地理空间影像和其他时空资产的目录规范；Item Search API 定义跨集合搜索和分页。项目价值在于给 MoonBit 应用提供可复用的数据目录入口，并让查询与解析核心跨目标复用。2026-11-10 对 MoonBit 生态索引和公开搜索的初步检索未找到同名或直接等价的 MoonBit STAC API 客户端；公开检索不涵盖未公开申报或未被索引的项目，不能保证赛事查重通过。详见[选题与风险记录](docs/RESEARCH.zh-CN.md)。

规范来源：[OGC STAC API 1.0](https://docs.ogc.org/cs/25-005/25-005.html)、[STAC Item 1.0.0 Schema](https://schemas.stacspec.org/v1.0.0/item-spec/json-schema/item.json)、[STAC Item 1.1.0 Schema](https://schemas.stacspec.org/v1.1.0/item-spec/json-schema/item.json)。许可：Apache-2.0。
