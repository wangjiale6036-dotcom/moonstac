///|
test "filter numeric Item properties and reject missing values" {
  let input = "{\"filter\":{\"op\":\"<=\",\"args\":[{\"property\":\"eo:cloud_cover\"},20]},\"items\":[{\"properties\":{\"eo:cloud_cover\":99}},{\"properties\":{\"eo:cloud_cover\":5}},{\"properties\":{}}]}"
  let result = @moonstac.filter_items(input)
  assert_true(result.contains("\"matches\":[false,true,false]"))
}

///|
test "filter logical and between expressions" {
  let input = "{\"filter\":{\"op\":\"and\",\"args\":[{\"op\":\"between\",\"args\":[{\"property\":\"properties.eo:cloud_cover\"},5,15]},{\"op\":\"not\",\"args\":[{\"op\":\"=\",\"args\":[{\"property\":\"id\"},\"excluded\"]}]}]},\"items\":[{\"id\":\"good\",\"properties\":{\"eo:cloud_cover\":10}},{\"id\":\"excluded\",\"properties\":{\"eo:cloud_cover\":10}},{\"id\":\"missing\",\"properties\":{}}]}"
  let result = @moonstac.filter_items(input)
  assert_true(result.contains("\"matches\":[true,false,false]"))
}

///|
test "filter compares timestamp literals across offsets" {
  let input = "{\"filter\":{\"op\":\"=\",\"args\":[{\"property\":\"datetime\"},{\"timestamp\":\"2026-11-01T00:00:00Z\"}]},\"items\":[{\"properties\":{\"datetime\":\"2026-11-01T08:00:00+08:00\"}},{\"properties\":{\"datetime\":\"2026-11-01T00:00:00.001Z\"}}]}"
  let result = @moonstac.filter_items(input)
  assert_true(result.contains("\"matches\":[true,false]"))
}

///|
test "filter rejects unsupported operators" {
  let result = @moonstac.filter_items(
    "{\"filter\":{\"op\":\"eval\",\"args\":[]},\"items\":[]}",
  )
  assert_true(result.contains("unsupported CQL2 operator"))
}

///|
test "filter or accepts a matching string or boolean" {
  let input = "{\"filter\":{\"op\":\"or\",\"args\":[{\"op\":\"=\",\"args\":[{\"property\":\"status\"},\"ready\"]},{\"op\":\"=\",\"args\":[{\"property\":\"verified\"},true]}]},\"items\":[{\"properties\":{\"status\":\"ready\"}},{\"properties\":{\"verified\":true}},{\"properties\":{\"status\":\"pending\",\"verified\":false}}]}"
  let result = @moonstac.filter_items(input)
  assert_true(result.contains("\"matches\":[true,true,false]"))
}
