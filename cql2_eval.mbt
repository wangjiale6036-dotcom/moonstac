///|
/// Recheck returned Items when a STAC service silently ignores a Filter request.
/// Missing or incomparable properties follow CQL2 unknown semantics and do not match.
pub fn filter_items(input : String) -> String {
  filter_items_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn filter_items_checked(input : String) -> String raise StacError {
  let request = @json.parse(input) catch { _ => raise Invalid("invalid JSON") }
  let filter = match field(request, "filter") {
    Some(value) => value
    None => raise Invalid("missing filter")
  }
  validate_cql2_filter(filter, 0)
  let items = match field(request, "items") {
    Some(Array(values)) => values
    _ => raise Invalid("invalid filter items")
  }
  let matches : Array[Json] = []
  for item in items {
    matches.push(Json::boolean(eval_cql2_filter(filter, item) == Some(true)))
  }
  let output : Json = { "status": "ok", "matches": Json::array(matches) }
  output.stringify()
}

///|
fn eval_cql2_filter(expr : Json, item : Json) -> Bool? raise StacError {
  let op = string_field(expr, "op")
  let args = match field(expr, "args") {
    Some(Array(values)) => values
    _ => raise Invalid("CQL2 filter requires args")
  }
  match op {
    "and" => {
      let mut unknown = false
      for arg in args {
        match eval_cql2_filter(arg, item) {
          Some(false) => return Some(false)
          None => unknown = true
          _ => ()
        }
      }
      if unknown {
        None
      } else {
        Some(true)
      }
    }
    "or" => {
      let mut unknown = false
      for arg in args {
        match eval_cql2_filter(arg, item) {
          Some(true) => return Some(true)
          None => unknown = true
          _ => ()
        }
      }
      if unknown {
        None
      } else {
        Some(false)
      }
    }
    "not" =>
      match eval_cql2_filter(args[0], item) {
        Some(value) => Some(!value)
        None => None
      }
    "between" => {
      let value = filter_property(item, string_field(args[0], "property"))
      let lower = compare_cql2_values(value, args[1], ">=")
      let upper = compare_cql2_values(value, args[2], "<=")
      match (lower, upper) {
        (Some(false), _) | (_, Some(false)) => Some(false)
        (Some(true), Some(true)) => Some(true)
        _ => None
      }
    }
    _ =>
      compare_cql2_values(
        filter_property(item, string_field(args[0], "property")),
        args[1],
        op,
      )
  }
}

///|
fn filter_property(item : Json, name : String) -> Json? {
  if name == "id" || name == "collection" {
    return field(item, name)
  }
  let properties = match field(item, "properties") {
    Some(value) => value
    None => return None
  }
  let key = if name.has_prefix("properties.") {
    name[11:].to_owned()
  } else {
    name
  }
  field(properties, key)
}

///|
fn compare_cql2_values(
  left : Json?,
  right : Json,
  op : String,
) -> Bool? raise StacError {
  match (left, right) {
    (Some(Number(a, ..)), Number(b, ..)) =>
      compare_cql2_order(if a < b { -1 } else if a > b { 1 } else { 0 }, op)
    (Some(String(a)), String(b)) => compare_cql2_order(a.compare(b), op)
    (Some(String(a)), Object(_)) =>
      compare_cql2_order(
        compare_timestamps(a, string_field(right, "timestamp")),
        op,
      )
    (Some(True), True) | (Some(False), False) => compare_cql2_boolean(true, op)
    (Some(True), False) | (Some(False), True) => compare_cql2_boolean(false, op)
    _ => None
  }
}

///|
fn compare_cql2_boolean(equal : Bool, op : String) -> Bool? {
  match op {
    "=" => Some(equal)
    "<>" => Some(!equal)
    _ => None
  }
}

///|
fn compare_cql2_order(order : Int, op : String) -> Bool? {
  match op {
    "=" => Some(order == 0)
    "<>" => Some(order != 0)
    "<" => Some(order < 0)
    "<=" => Some(order <= 0)
    ">" => Some(order > 0)
    ">=" => Some(order >= 0)
    _ => None
  }
}

///|
fn compare_timestamps(left : String, right : String) -> Int raise StacError {
  let (a, af) = timestamp_order_key(left)
  let (b, bf) = timestamp_order_key(right)
  if a < b {
    return -1
  }
  if a > b {
    return 1
  }
  let length = if af.length() > bf.length() { af.length() } else { bf.length() }
  for i in 0..<length {
    let ac = if i < af.length() { af[i] } else { '0' }
    let bc = if i < bf.length() { bf[i] } else { '0' }
    if ac < bc {
      return -1
    }
    if ac > bc {
      return 1
    }
  }
  0
}

///|
fn timestamp_order_key(value : String) -> (Int64, Array[Char]) raise StacError {
  validate_timestamp(value)
  let chars = value.iter().to_array()
  let year = timestamp_digits(chars, 0, 4)
  let month = timestamp_digits(chars, 5, 2)
  let day = timestamp_digits(chars, 8, 2)
  let hour = timestamp_digits(chars, 11, 2)
  let minute = timestamp_digits(chars, 14, 2)
  let second = timestamp_digits(chars, 17, 2)
  let previous_year = (year - 1).to_int64()
  let mut days = previous_year * 365L +
    previous_year / 4L -
    previous_year / 100L +
    previous_year / 400L
  for m in 1..<month {
    days += days_in_month(year, m).to_int64()
  }
  days += (day - 1).to_int64()
  let fraction : Array[Char] = []
  let mut zone = 19
  if chars[zone] == '.' {
    zone += 1
    while zone < chars.length() && is_digit(chars[zone]) {
      fraction.push(chars[zone])
      zone += 1
    }
  }
  let mut offset_minutes = 0
  if chars[zone] == '+' || chars[zone] == '-' {
    offset_minutes = timestamp_digits(chars, zone + 1, 2) * 60 +
      timestamp_digits(chars, zone + 4, 2)
    if chars[zone] == '-' {
      offset_minutes = -offset_minutes
    }
  }
  let seconds = days * 86400L +
    hour.to_int64() * 3600L +
    minute.to_int64() * 60L +
    second.to_int64() -
    offset_minutes.to_int64() * 60L
  (seconds, fraction)
}
