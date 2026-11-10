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
