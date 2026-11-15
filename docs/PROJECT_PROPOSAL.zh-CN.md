# MoonSTAC 项目申报书

**状态：2026 年 11 月黑客松待提交稿。** 本文按此前 MoonSHACL、MoonPMTiles 申报书的八节结构编写。GitHub 已有可运行 MVP、测试与持续集成；赛事表单由申报人本人填写，目前尚未提交。Mooncakes 0.1.0 是早期预览版，新增的 GeoJSON 区域查询和资产清单只在 GitHub 当前源码中。

## 一、项目名称与申报人

项目名称：**MoonSTAC——MoonBit 原生 STAC Item Search 核心与资产清单工具**。

申报人：王嘉乐；GitHub ID：`wangjiale6036-dotcom`。本公开版本不收录私人联系方式。

参赛类型：拟申报 2026 年 11 月 MoonBit 黑客松，新项目、个人参赛。项目自有代码采用 Apache-2.0 许可证。[公开仓库][repo]已包含当前 MVP；[Mooncakes 0.1.0][package]对应较早的开发预览，不代表本次新增功能已发行。

## 二、项目简介

STAC（SpatioTemporal Asset Catalog）用标准化的 Item、Collection 和 Asset 描述遥感影像及其他时空数据。使用者通常需要先发现可用集合，再按空间、时间或属性检索 Item，最后从 Item 找到数据资产。不同 STAC API 的分页链接可能是 GET 或 POST，地址可能是相对路径，下一页请求还可能携带请求体和请求头。这些细节使一次目录查询变成多步处理。

MoonSTAC 提供可嵌入 MoonBit 程序的解析与查询核心，以及可直接操作公开 STAC 服务的 Node.js 命令行工具。用户可以发现 API 入口、浏览集合、进行 `bbox` 或 GeoJSON 区域搜索、加上时间、集合、Item ID 与 CQL2 属性条件，跨页读取结果，并按资产 key 或 role 输出含绝对 URL 的清单。工具只返回目录元数据和地址，不下载影像内容。

STAC 结构检查、GeoJSON 与时间边界检查、查询体构造以及 `next` 链接解释由 MoonBit 完成，并在 JavaScript、Wasm-GC、Native 三目标下测试。Node.js 负责网络和文件 I/O、URL 解析及 CLI 接线。当前是 Item Search 的可运行子集，不是完整 STAC Schema 验证器。

## 三、方向、通用性与独立价值

方向为 MoonBit 基础工具库与地理空间数据目录接入。STAC 是跨机构使用的公开目录接口；如果 MoonBit 应用需要查找卫星场景，使用统一查询和 Item 结构比为单个服务编写固定字段适配更容易复用。典型下游包括遥感影像筛选、地理分析流水线、数据浏览器和公开数据目录的自动化检查。MoonSTAC 提供“找到哪份数据及其地址”的前置能力，后续下载、影像解码或渲染由其他组件承担。

项目的具体贡献是 MoonBit 实现的 Item / ItemCollection 解析、常用搜索参数与 CQL2 JSON 子集检查，以及可跨请求方法的分页解释。CLI 把这些能力串成一条实际工作流，并输出可按 role 筛选的资产清单。相对资产地址先以 Item 的 `self` 链接为基准，缺失时以响应页地址为基准；同时保留原始 `href`，便于排查服务数据。默认阻止跨源分页、限制最大页数并检测重复请求，避免错误 `next` 链接导致无界抓取。

MoonPMTiles 处理 PMTiles 归档内的瓦片定位，MoonSTAC 处理 STAC 目录服务的场景发现和资产提取，两者的输入、标准与核心任务不同。已有成熟的其他语言 STAC 客户端；STAC 规范、API、分页和 CQL2 均非本项目首创。2026-11-10 对 MoonBit 生态索引和公开页面进行的初步复查未发现直接等价的 MoonBit STAC API 客户端；该检索无法覆盖未公开申报，不能保证赛事内部查重通过。[选题记录][research]列出检索边界。

## 四、完整使用场景

1. **公开目录发现与集合选择。** 对 Element 84 Earth Search 的 STAC API 根地址执行 `discover`，读取搜索和集合入口；`collections` 遍历集合列表。2026-11-10 本地运行观察到根目录 ID `earth-search-aws`、14 条 `conformsTo` 和 9 个集合。这些是当时的服务响应，不固定为规范要求。
2. **按空间和属性筛选场景。** 在 `sentinel-2-l2a` 集合中，用 `bbox=120,30,121,31` 做 GET/POST 搜索，按 `eo:cloud_cover <= 20` 的 CQL2 JSON 过滤，或把合成 Polygon 文件作为 `intersects` POST 请求。真实服务的 GeoJSON 查询返回 `S2A_50RQU_20261110_0_L2A`；GET/POST 两页搜索与 CQL2 过滤也已运行。服务目录会更新，实际场景 ID 不作为永久承诺。
3. **从场景提取影像资产。** 对同一查询结果执行 `assets --role data`，按 key、媒体类型与 role 查看候选资产 URL。真实查询中得到 32 个 `data` 角色资产，第一个示例资产 key 为 `aot`，地址是 HTTPS。输出是可供后续程序使用的资产清单；MoonSTAC 不验证远端资产是否公开可下载，也不把资产内容纳入仓库。
4. **处理异常服务响应。** 合成测试覆盖缺失 Item 字段、错误 GeoJSON、多边形未闭合、非法时间、`bbox` 与 `intersects` 冲突、分页循环和跨源跳转。错误会明确返回，不能把“只解析出部分结果”当作成功。

前三个场景的命令见[运行说明][readme]，观察与测试边界见[验证记录][validation]。网络演示依赖公开服务可用性；自动化测试使用仓库夹具和模拟传输，不依赖该公网服务。

## 五、范围、当前结果与 11 月交付安排

**当前 MVP 范围：** 解析 STAC Item 1.0.0/1.1.0 的核心字段和 ItemCollection；读取 landing page 与 Collections；构造 `bbox`、GeoJSON `intersects`、时间、集合、Item ID、limit 和一组 CQL2 JSON 属性过滤条件；跟随 GET/POST `next`，处理相对链接、body、headers 与 `merge`；提取资产标题、媒体类型、role、原始及解析后地址。CLI 提供 `discover`、`collections`、`validate`、`search`、`assets` 五个命令。

| 阶段 | 当前实际结果 | 11 月后续工作或复核 |
| --- | --- | --- |
| S0 方向与公开复查 | 记录 STAC 规范、相邻 MoonBit 项目与公开检索边界 | 由赛事方核对无法公开查询的申报重复风险 |
| S1 MoonBit 核心 | Item、ItemCollection、目录和集合解析；查询构造与核心结构检查；三目标编译测试 | 扩展错误定位与更多真实响应边界 |
| S2 运行适配 | Node.js CLI 支持 HTTP、文件输入、GET/POST 分页、同源保护和资产清单 | 增加认证与速率限制场景前先取得可公开复现样本 |
| S3 独立验证 | 三目标各 14/14、Node.js 集成测试 11/11；Earth Search 的真实查询已运行；[最新 GitHub CI][ci] 成功 | 增加第二个独立 STAC 服务和更多复杂 GeoJSON/分页样本 |
| S4 开源交付 | Apache-2.0、README、夹具、验证记录、Markdown 申报书和公开提交已具备 | 申报人核对个人信息与赛事规则并自行填写官方表单 |

**范围边界：** 当前只对使用路径所需的关键 STAC 结构做检查，未逐项实施完整 Item JSON Schema；不检查 GeoJSON 自交或环方向，不支持完整 CQL2、排序、字段选择及全部 STAC 扩展。资产输出不等于下载权限验证。Mooncakes 0.1.0 尚未包含本次 MVP 新增功能，使用最新功能应从 GitHub 当前源码构建。后续扩展以真实需求和可复现测试驱动，不靠无功能的代码或提交数量堆砌工程规模。

## 六、项目性质与原创说明

MoonSTAC 是依据公开 STAC 规范独立编写的 MoonBit 生态实现，不是把现有 Python/JavaScript 客户端封装为 MoonBit 接口。可复用核心由 MoonBit 编写，Node.js 负责 I/O 和命令行环境。开发、测试和文档使用 AI 辅助，申报人应自行检查源码、实测命令与最终材料。

项目不主张 STAC、GeoJSON、CQL2、URL 解析或分页技术的原创发明，也不声称获得 OGC 认证、外部用户采用、性能领先或赛事查重通过。公开服务验证只证明记录的命令在当时响应上运行成功，不能外推为对所有 STAC 服务的完整兼容。

## 七、参考来源及许可证

实现依据 [OGC STAC API 1.0][ogc]、[STAC Item 1.0.0 JSON Schema][item10]、[STAC Item 1.1.0 JSON Schema][item11]和 [STAC API Filter 扩展][filter]。项目自有代码采用 [Apache-2.0][license]。Earth Search 仅作为在线查询对象；仓库保存合成夹具和查询观察，不分发其遥感影像。项目没有运行时 npm 依赖；MoonBit 与 Node.js 工具链属于构建和执行环境。

公开规范和测试服务是技术依据，不是项目的原创成果。若后续加入第三方测试数据或代码，应另记来源、许可和版本，再扩大分发范围。

## 八、仓库、测试与交付

[GitHub 仓库][repo]保留源码和[提交历史][commits]；本轮 MVP 功能提交为 [`45f89e0`][feature-commit]，申报材料提交为 [`785fcf9`][docs-commit]。[最新 CI][ci] 对 `785fcf9` 的结果为 `success`。可运行命令如下：

```sh
moon test --target js
moon test --target wasm-gc
moon test --target native
npm test
node cli.mjs search --url https://earth-search.aws.element84.com/v1/search --intersects-file test-fixtures/search-area.geojson --collection sentinel-2-l2a --method POST --limit 1 --max-pages 1
node cli.mjs assets --url https://earth-search.aws.element84.com/v1/search --intersects-file test-fixtures/search-area.geojson --collection sentinel-2-l2a --method POST --limit 1 --max-pages 1 --role data
```

本地三目标 MoonBit 测试各 **14/14**，Node.js 集成测试 **11/11**；线上 CI 同一提交成功。完整路径、服务观察和已知缺口见[验证记录][validation]。这些测试支持 MVP 所列功能，不等于完整 STAC 合规或赛事验收。当前公开源码与 Mooncakes 0.1.0 的版本范围不同；本稿为 Markdown 待提交材料，**官方报名表尚未填写**，最终资格及赛期提交认定由主办方决定。

[repo]: https://github.com/wangjiale6036-dotcom/moonstac
[commits]: https://github.com/wangjiale6036-dotcom/moonstac/commits/main/
[package]: https://mooncakes.io/docs/wangjiale6036-dotcom/moonstac@0.1.0
[readme]: https://github.com/wangjiale6036-dotcom/moonstac/blob/main/README.md
[validation]: https://github.com/wangjiale6036-dotcom/moonstac/blob/main/docs/VALIDATION.zh-CN.md
[research]: https://github.com/wangjiale6036-dotcom/moonstac/blob/main/docs/RESEARCH.zh-CN.md
[license]: https://github.com/wangjiale6036-dotcom/moonstac/blob/main/LICENSE
[ci]: https://github.com/wangjiale6036-dotcom/moonstac/actions/runs/42813989349
[feature-commit]: https://github.com/wangjiale6036-dotcom/moonstac/commit/45f89e0
[docs-commit]: https://github.com/wangjiale6036-dotcom/moonstac/commit/785fcf9
[ogc]: https://docs.ogc.org/cs/25-005/25-005.html
[item10]: https://schemas.stacspec.org/v1.0.0/item-spec/json-schema/item.json
[item11]: https://schemas.stacspec.org/v1.1.0/item-spec/json-schema/item.json
[filter]: https://github.com/stac-api-extensions/filter
