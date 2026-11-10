///|
/// Validate a practical, explicit subset of CQL2 JSON for STAC Filter.
/// Unsupported operators fail rather than passing an unexamined expression.
fn validate_cql2_filter(expr : Json, depth : Int) -> Unit raise StacError {
  if depth > 16 {
    raise Invalid("CQL2 filter too deeply nested")
  }
  let op = string_field(expr, "op")
  let args = match field(expr, "args") {
    Some(Array(xs)) => xs
    _ => raise Invalid("CQL2 filter requires args")
  }
  match op {
    "and" | "or" => {
      if args.length() < 2 {
        raise Invalid("CQL2 logical operator needs two args")
      }
      for arg in args {
        validate_cql2_filter(arg, depth + 1)
      }
    }
    "not" => {
      if args.length() != 1 {
        raise Invalid("CQL2 not needs one arg")
      }
      validate_cql2_filter(args[0], depth + 1)
    }
    "=" | "<>" | "<" | "<=" | ">" | ">=" => {
      if args.length() != 2 {
        raise Invalid("CQL2 comparison needs two args")
      }
      validate_cql2_property(args[0])
      validate_cql2_literal(args[1])
    }
    "between" => {
      if args.length() != 3 {
        raise Invalid("CQL2 between needs three args")
      }
      validate_cql2_property(args[0])
      validate_cql2_literal(args[1])
      validate_cql2_literal(args[2])
    }
    _ => raise Invalid("unsupported CQL2 operator")
  }
}

///|
fn validate_cql2_property(value : Json) -> Unit raise StacError {
  ignore(string_field(value, "property"))
}

///|
fn validate_cql2_literal(value : Json) -> Unit raise StacError {
  match value {
    String(_) | Number(_, ..) | True | False | Null => ()
    Object(_) => {
      let timestamp = string_field(value, "timestamp")
      validate_timestamp(timestamp)
    }
    _ => raise Invalid("invalid CQL2 literal")
  }
}
