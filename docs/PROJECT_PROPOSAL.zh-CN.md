# MoonSTAC 项目申报书（详细版）

> 2026 年 11 月 MoonBit 黑客松。本文说明当前已实现的 MVP，供申报与项目评审参考。赛事报名表由参赛者本人填写；截至本文更新时，**尚未提交官方报名表**。

## 1. 项目基本信息

| 项目 | 内容 |
| --- | --- |
| 名称 | MoonSTAC：MoonBit 原生 STAC 搜索核心与资产清单工具 |
| 申报人 | 王嘉乐，GitHub ID `wangjiale6036-dotcom`，个人项目 |
| 代码仓库 | <https://github.com/wangjiale6036-dotcom/moonstac> |
| Mooncakes | <https://mooncakes.io/docs/wangjiale6036-dotcom/moonstac@0.1.0>（早期预览版；GitHub 的新增功能尚未发布到该版本） |
| 许可证 | Apache-2.0 |
| 实现语言 | MoonBit 核心；Node.js 仅承担 HTTP 和文件读写 |

## 2. 要解决什么问题

遥感影像、土地覆盖、环境监测等数据通常分散在不同目录服务中。STAC（SpatioTemporal Asset Catalog）用统一的 Item、Collection、Asset 结构描述这些数据，STAC API Item Search 则提供按空间、时间、集合和属性发现数据的接口。MoonBit 开发者若要使用这些公开目录，需要处理查询构造、ItemCollection 解析、分页、相对链接和异常数据等工作。

MoonSTAC 提供一条完整的最小工作链：**连接 STAC API → 发现搜索和集合入口 → 构造查询 → 分页获取场景 → 提取可用资产地址**。这让下游 MoonBit 程序可以把检索到的资产交给影像分析、下载或展示模块；本项目自身不下载影像。

目标用户是编写地理空间或遥感应用的 MoonBit 开发者，以及需要用 CLI 快速检索开放 STAC 服务的使用者。项目目前聚焦 Item Search，不宣称实现整个 STAC 标准族。

## 3. MVP 已完成的能力

### 3.1 服务发现与集合浏览

- 解析 STAC API landing page，从 `links` 中取得搜索入口和集合列表入口，处理相对 URL。
- 分页读取 Collections，提取集合 ID、标题、描述、许可证等基础信息。
- 对 HTTP 错误、无效 JSON、字段缺失及集合分页循环给出明确错误。

### 3.2 查询构造与分页搜索

- 支持 GET/POST Item Search；参数包括经纬度 `bbox`、GeoJSON `intersects`、时间、集合、Item ID、每页条数。
- `intersects` 由 MoonBit 检查 GeoJSON 几何结构，并与 `bbox` 互斥；CLI 通过 `--intersects-file` 读取几何文件，用 POST 发送。
- 支持 CQL2 JSON 的比较、`between`、`and`、`or`、`not` 子集，可按 `eo:cloud_cover` 等属性过滤；不支持的操作符会拒绝。
- 解析 GET/POST `next` 链接，包括相对 URL、后续请求的 body、headers 和 `merge` 标志；限制最大页数并检测循环。默认阻止跨源分页，需显式允许。

### 3.3 Item 读取与资产清单

- 解析 ItemCollection 与 STAC Item 1.0.0/1.1.0 的核心字段：ID、Collection、时间、Geometry、BBox、Properties、Assets 和 Item 的 `self` 链接。
- 检查必需字段、GeoJSON 坐标层级与多边形闭合、RFC 3339 时间、资产地址与角色等关键结构；输出保留完整 `properties` 和 `geometry`。
- 提取资产 key、原始地址、标题、媒体类型和角色。`search` 附加解析后的绝对地址；`assets` 命令按 key 或 role 筛选，并输出含场景来源的资产清单。
- 相对资产地址以 Item `self` 链接为基准；缺少 `self` 时以响应页 URL 为基准。工具只给出 URL，不访问或下载资产。

## 4. 技术结构与实现取舍

```text
STAC API 公开服务
   │ HTTP 响应
   ▼
Node.js CLI ── 请求、文件输入、URL 解析、分页调度、结果输出
   │ JSON 字符串
   ▼
MoonBit 核心 ── STAC 结构解析、GeoJSON/时间检查、查询构造、next 解释
   │
   └── JS / Wasm-GC / Native 三目标测试
```

MoonBit 负责可复用的标准相关逻辑，避免把业务规则留在 CLI。Node.js 仅负责运行环境相关的 I/O 与 URL 处理。项目提供 MoonBit 公共解析 API，以及供 CLI 使用的 JS 桥接模块。当前桥接采用 JSON 字符串边界，便于跨目标测试，但并非零拷贝接口；这是 MVP 在实现复杂度和可移植性之间的取舍。

分页请求不能只取下一页 URL：STAC API 的 `next` 可能要求 POST，且附带新的 body 或 headers。因此 CLI 记录上一请求体和请求头，按 `merge` 语义产生下一请求，并以方法、URL、请求体和请求头组合检测循环。资产地址解析不改变原始 `href`，便于调用者对照服务返回值。

## 5. 可复现演示

环境：MoonBit 工具链、Node.js 20+。在仓库根目录运行：

```sh
moon test --target js
moon test --target wasm-gc
moon test --target native
npm test
node cli.mjs discover --url https://earth-search.aws.element84.com/v1/
node cli.mjs collections --url https://earth-search.aws.element84.com/v1/collections
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --intersects-file test-fixtures/search-area.geojson --collection sentinel-2-l2a --method POST --limit 1 --max-pages 1
node cli.mjs assets --url https://earth-search.aws.element84.com/v1/search --bbox 120,30,121,31 --collection sentinel-2-l2a --limit 1 --max-pages 1 --role data
```

已在本机运行的验证：三目标 MoonBit 测试各 **14/14** 通过；Node.js 集成测试 **11/11** 通过；公开 Earth Search 服务上，GeoJSON POST 查询返回场景 `S2A_50RQU_20261110_0_L2A`，该页用 `--role data` 可得到 32 个资产记录。此前版本还在该服务验证过 GET/POST 两页搜索与 CQL2 云量过滤。以上公网结果会随服务与目录数据变化，不作为固定测试断言。完整命令和记录见 [验证文档](VALIDATION.zh-CN.md)。

## 6. MVP 验收标准与现状

| 验收点 | 当前证据 |
| --- | --- |
| 能根据空间范围、集合查到真实 Item | Earth Search 的 bbox GET 和 GeoJSON POST 已运行 |
| 能处理多页和 POST next | 合成集成测试覆盖 GET、POST、body、headers、merge 与循环；真实服务已跑通两页 |
| 能从 Item 得到可用资产地址 | `assets` 清单含绝对 URL、媒体类型和角色；真实服务返回 32 个 data 资产 |
| 可作为 MoonBit 库复用 | Mooncakes 0.1.0 可在独立项目安装与调用；新增功能暂在 GitHub 源码 |
| 在多个 MoonBit 目标下编译测试 | JS、Wasm-GC、Native 各 14 项通过 |
| 公开、可检查的提交 | GitHub 仓库包含源码、测试、夹具、文档、CI 与 Apache-2.0 许可 |

## 7. 独立性与选题风险

项目依据 OGC STAC API、STAC Item Schema 和公开扩展规范独立实现，没有照搬现有客户端。MoonPMTiles 处理 PMTiles 归档格式，MoonSTAC 处理 STAC 目录搜索；两者标准、输入输出与使用场景不同。已有其他语言的 STAC 客户端，本项目不主张 STAC 搜索或分页技术为全球首创。

截至 2026-11-10，对 MoonBit 生态索引和公开页面的检索未发现直接等价的 MoonBit STAC API 客户端。这只是公开信息范围内的初步查重，无法证明没有未公开申报，也不能保证赛事内部查重通过。证据与检索边界见[选题记录](RESEARCH.zh-CN.md)。

## 8. 明确的边界与下一阶段

当前校验针对 MVP 使用的关键结构，**不是完整 STAC Item JSON Schema 验证器，也没有 OGC 认证**。尚未覆盖 GeoJSON 自交、全部扩展 Schema、完整 CQL2、排序、字段选择和更多服务的认证/限流机制。公网服务的资产地址可能需要额外权限，清单工具不保证地址可下载。

下一阶段按价值排序：一是扩展真实服务兼容性测试并改进错误定位；二是增加常用查询扩展和更丰富的结构校验；三是完善库级 API 文档与版本发布。若参赛评审要求更广的工程规模，应以这些真实能力和测试扩充代码，不以无功能的行数填充仓库。

## 9. 参考依据

- [OGC STAC API 1.0 社区标准](https://docs.ogc.org/cs/25-005/25-005.html)
- [STAC Item 1.0.0 JSON Schema](https://schemas.stacspec.org/v1.0.0/item-spec/json-schema/item.json)
- [STAC Item 1.1.0 JSON Schema](https://schemas.stacspec.org/v1.1.0/item-spec/json-schema/item.json)
- [STAC API Filter 扩展](https://github.com/stac-api-extensions/filter)
- [MoonBit 生态索引](https://moonbit-ecosystem-index.pages.dev/#/)
