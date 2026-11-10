///|
test "search body emits STAC core parameters" {
  let body = @moonstac.search_body(
    [120.0, 30.0, 121.0, 31.0],
    Some("2026-11-01/2026-11-30"),
    ["sentinel-2-l2a"],
    12,
  )
  assert_true(body.contains("\"bbox\""))
  assert_true(body.contains("\"collections\""))
  assert_true(body.contains("2026-11-01/2026-11-30"))
}

///|
test "reject reversed bounding box" {
  let result = @moonstac.search_request("{\"bbox\":[121,30,120,31]}")
  assert_true(result.contains("\"status\":\"invalid\""))
}

///|
test "parse item collection and next link" {
  let text = "{\"type\":\"FeatureCollection\",\"features\":[{\"stac_version\":\"1.0.0\",\"type\":\"Feature\",\"id\":\"scene-1\",\"geometry\":null,\"properties\":{\"datetime\":\"2026-11-01T00:00:00Z\"},\"links\":[],\"assets\":{\"visual\":{\"href\":\"image.tif\"}}}],\"links\":[{\"rel\":\"next\",\"href\":\"?page=2\"}]}"
  let page = @moonstac.parse_page(text)
  assert_eq(page.items.length(), 1)
  assert_eq(page.items[0].id, "scene-1")
  assert_eq(page.items[0].assets[0].href, "image.tif")
  assert_true(page.next is Some(_))
}

///|
test "valid point item with collection link" {
  let text = "{\"stac_version\":\"1.1.0\",\"type\":\"Feature\",\"id\":\"scene\",\"collection\":\"c\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[120,30]},\"bbox\":[120,30,120,30],\"properties\":{\"datetime\":\"2026-11-01T00:00:00Z\"},\"links\":[{\"rel\":\"collection\",\"href\":\"/collections/c\"}],\"assets\":{\"visual\":{\"href\":\"image.tif\",\"roles\":[\"data\"]}}}"
  let item = @moonstac.parse_item(text)
  assert_eq(item.collection, Some("c"))
}

///|
test "reject item with null geometry and bbox" {
  let text = "{\"stac_version\":\"1.0.0\",\"type\":\"Feature\",\"id\":\"scene\",\"geometry\":null,\"bbox\":null,\"properties\":{\"datetime\":\"2026-11-01T00:00:00Z\"},\"links\":[],\"assets\":{}}"
  let result = @moonstac.page_summary(
    "{\"type\":\"FeatureCollection\",\"features\":[" + text + "],\"links\":[]}",
  )
  assert_true(result.contains("\"status\":\"invalid\""))
}

///|
test "reject collection id without collection link" {
  let text = "{\"stac_version\":\"1.0.0\",\"type\":\"Feature\",\"id\":\"scene\",\"collection\":\"c\",\"geometry\":null,\"properties\":{\"datetime\":\"2026-11-01T00:00:00Z\"},\"links\":[],\"assets\":{}}"
  let result = @moonstac.page_summary(
    "{\"type\":\"FeatureCollection\",\"features\":[" + text + "],\"links\":[]}",
  )
  assert_true(result.contains("\"status\":\"invalid\""))
}
