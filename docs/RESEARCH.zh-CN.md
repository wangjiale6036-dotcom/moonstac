# 选题与风险记录（2026-11-10）

## 问题与价值

STAC API 为遥感影像等时空资产提供标准化的搜索结果和资产链接。MoonBit 应用若要消费目录数据，需要构造 Item Search 请求、解释 ItemCollection 和处理分页。MoonSTAC 以这条流程为最小可用范围，核心在 MoonBit，HTTP 传输置于 Node.js 适配层。

## 公开查重范围

检索过 [MoonBit 生态索引](https://moonbit-ecosystem-index.pages.dev/#/) 的 STAC API / SpatioTemporal Asset Catalog 相关词，以及公开网页和 GitHub 搜索。索引快照约为 2026-11-09，未见直接同类的 MoonBit STAC API 客户端。相似检索有遗漏风险；本记录无法核查组委会尚未公开的 11 月报名项目，也不构成“无人申报”的保证。MoonPMTiles 与该项目处理的标准和使用场景不同。

## 标准与实现边界

- [OGC STAC API 1.0 社区标准](https://docs.ogc.org/cs/25-005/25-005.html)：`/search` 的 GET、可选 POST、ItemCollection 结果、`next` 分页；`next` 可包含 `method`、`headers`、`body`、`merge`。
- [STAC Item 1.0.0 Schema](https://schemas.stacspec.org/v1.0.0/item-spec/json-schema/item.json) 与 [1.1.0 Schema](https://schemas.stacspec.org/v1.1.0/item-spec/json-schema/item.json)：当前只实现关键字段的结构检查，完整校验需扩展 GeoJSON、属性约束和扩展 Schema 支持。

## 初审风险

1. 当前只是开发预览版，功能和测试证据不足以声称完整 STAC 客户端或完整标准验证器。
2. 已在 Earth Search 上跑通一组 bbox 的 GET/POST 两页查询，但更多服务、认证 API 和极端分页形式仍待验证。
3. 公开查重无法覆盖未发布项目。申报前应再次核对公开报名名单、实际运行记录、源码比例和官方 11 月规则。
