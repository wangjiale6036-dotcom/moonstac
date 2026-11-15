///|
test "translate a CQL2 cloud comparison to STAC Query" {
  let result = @moonstac.query_fallback(
    "{\"op\":\"<=\",\"args\":[{\"property\":\"eo:cloud_cover\"},20]}",
  )
  assert_true(result.contains("\"status\":\"ok\""))
  assert_true(result.contains("\"eo:cloud_cover\""))
  assert_true(result.contains("\"lte\":20"))
}

///|
test "translate between and conjunction without widening results" {
  let result = @moonstac.query_fallback(
    "{\"op\":\"and\",\"args\":[{\"op\":\"between\",\"args\":[{\"property\":\"properties.eo:cloud_cover\"},0,20]},{\"op\":\"=\",\"args\":[{\"property\":\"platform\"},\"sentinel-2\"]}]}",
  )
  assert_true(result.contains("\"status\":\"ok\""))
  assert_true(result.contains("\"gte\":0"))
  assert_true(result.contains("\"lte\":20"))
  assert_true(result.contains("\"platform\""))
}

///|
test "do not translate an or expression" {
  let result = @moonstac.query_fallback(
    "{\"op\":\"or\",\"args\":[{\"op\":\"=\",\"args\":[{\"property\":\"a\"},1]},{\"op\":\"=\",\"args\":[{\"property\":\"b\"},2]}]}",
  )
  assert_true(result.contains("\"status\":\"unsupported\""))
}
