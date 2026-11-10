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

///|
fn page_with_geometry(geometry : String) -> String {
  "{\"type\":\"FeatureCollection\",\"features\":[{\"stac_version\":\"1.0.0\",\"type\":\"Feature\",\"id\":\"g\",\"geometry\":" +
  geometry +
  ",\"bbox\":[0,0,1,1],\"properties\":{\"datetime\":\"2026-11-01T00:00:00Z\"},\"links\":[],\"assets\":{}}],\"links\":[]}"
}

///|
test "accept closed GeoJSON polygon" {
  let text = page_with_geometry(
    "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}",
  )
  let result = @moonstac.page_summary(text)
  assert_true(result.contains("\"status\":\"ok\""))
}

///|
test "reject open GeoJSON polygon ring" {
  let text = page_with_geometry(
    "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,1]]]}",
  )
  let result = @moonstac.page_summary(text)
  assert_true(result.contains("linear ring is not closed"))
}

///|
test "reject malformed GeoJSON point coordinates" {
  let text = page_with_geometry("{\"type\":\"Point\",\"coordinates\":[[0,0]]}")
  let result = @moonstac.page_summary(text)
  assert_true(result.contains("position must have two or three numbers"))
}

///|
fn page_with_datetime(datetime : String) -> String {
  "{\"type\":\"FeatureCollection\",\"features\":[{\"stac_version\":\"1.0.0\",\"type\":\"Feature\",\"id\":\"t\",\"geometry\":null,\"properties\":{\"datetime\":\"" +
  datetime +
  "\"},\"links\":[],\"assets\":{}}],\"links\":[]}"
}

///|
test "accept leap day RFC3339 datetime" {
  let result = @moonstac.page_summary(
    page_with_datetime("2024-02-29T23:59:59.123+08:00"),
  )
  assert_true(result.contains("\"status\":\"ok\""))
}

///|
test "reject invalid calendar date" {
  let result = @moonstac.page_summary(
    page_with_datetime("2026-02-29T00:00:00Z"),
  )
  assert_true(result.contains("datetime component out of range"))
}

///|
test "reject datetime without timezone" {
  let result = @moonstac.page_summary(page_with_datetime("2026-11-01T00:00:00"))
  assert_true(result.contains("invalid datetime length"))
}
