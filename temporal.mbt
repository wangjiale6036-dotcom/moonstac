///|
/// Check the RFC 3339 timestamp form used by STAC Item datetime fields.
fn validate_timestamp(value : String) -> Unit raise StacError {
  let chars = value.iter().to_array()
  if chars.length() < 20 {
    raise Invalid("invalid datetime length")
  }
  let year = timestamp_digits(chars, 0, 4)
  let month = timestamp_digits(chars, 5, 2)
  let day = timestamp_digits(chars, 8, 2)
  let hour = timestamp_digits(chars, 11, 2)
  let minute = timestamp_digits(chars, 14, 2)
  let second = timestamp_digits(chars, 17, 2)
  if chars[4] != '-' ||
    chars[7] != '-' ||
    (chars[10] != 'T' && chars[10] != 't') ||
    chars[13] != ':' ||
    chars[16] != ':' {
    raise Invalid("invalid datetime separators")
  }
  if year < 1 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > days_in_month(year, month) ||
    hour > 23 ||
    minute > 59 ||
    second > 60 {
    raise Invalid("datetime component out of range")
  }
  let mut zone_start = 19
  if chars[zone_start] == '.' {
    zone_start += 1
    let fraction_start = zone_start
    while zone_start < chars.length() && is_digit(chars[zone_start]) {
      zone_start += 1
    }
    if zone_start == fraction_start {
      raise Invalid("empty datetime fraction")
    }
  }
  if zone_start >= chars.length() {
    raise Invalid("datetime requires timezone")
  }
  if chars[zone_start] == 'Z' || chars[zone_start] == 'z' {
    if zone_start + 1 != chars.length() {
      raise Invalid("invalid datetime suffix")
    }
  } else if chars[zone_start] == '+' || chars[zone_start] == '-' {
    if zone_start + 6 != chars.length() || chars[zone_start + 3] != ':' {
      raise Invalid("invalid timezone offset")
    }
    let offset_hour = timestamp_digits(chars, zone_start + 1, 2)
    let offset_minute = timestamp_digits(chars, zone_start + 4, 2)
    if offset_hour > 23 || offset_minute > 59 {
      raise Invalid("timezone offset out of range")
    }
  } else {
    raise Invalid("invalid timezone marker")
  }
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn timestamp_digits(
  chars : Array[Char],
  start : Int,
  count : Int,
) -> Int raise StacError {
  if start + count > chars.length() {
    raise Invalid("short datetime")
  }
  let mut value = 0
  for i in start..<(start + count) {
    if !is_digit(chars[i]) {
      raise Invalid("invalid datetime digit")
    }
    value = value * 10 + chars[i].to_int() - '0'.to_int()
  }
  value
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    4 | 6 | 9 | 11 => 30
    2 =>
      if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
        29
      } else {
        28
      }
    _ => 31
  }
}
