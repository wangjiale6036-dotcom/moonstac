///|
/// Translate the conjunction-only CQL2 subset into the STAC Query extension.
/// Return unsupported for expressions that cannot be represented exactly.
pub fn query_fallback(input : String) -> String {
  query_fallback_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn query_fallback_checked(input : String) -> String raise StacError {
  let filter = @json.parse(input) catch { _ => raise Invalid("invalid JSON") }
  validate_cql2_filter(filter, 0)
  let query : Map[String, Json] = Map([])
  if !translate_query_filter(filter, query) {
    let output : Json = { "status": "unsupported" }
    return output.stringify()
  }
  let output : Json = { "status": "ok", "query": Json::object(query) }
  output.stringify()
}

///|
fn translate_query_filter(
  expr : Json,
  query : Map[String, Json],
) -> Bool raise StacError {
  let op = string_field(expr, "op")
  let args = match field(expr, "args") {
    Some(Array(values)) => values
    _ => raise Invalid("CQL2 filter requires args")
  }
  match op {
    "and" => {
      for arg in args {
        if !translate_query_filter(arg, query) {
          return false
        }
      }
      true
    }
    "between" => {
      let property = string_field(args[0], "property")
      add_query_comparison(query, property, "gte", args[1]) &&
      add_query_comparison(query, property, "lte", args[2])
    }
    "=" | "<>" | "<" | "<=" | ">" | ">=" => {
      let property = string_field(args[0], "property")
      let query_op = match op {
        "=" => "eq"
        "<>" => "neq"
        "<" => "lt"
        "<=" => "lte"
        ">" => "gt"
        _ => "gte"
      }
      add_query_comparison(query, property, query_op, args[1])
    }
    _ => false
  }
}

///|
fn add_query_comparison(
  query : Map[String, Json],
  property : String,
  op : String,
  literal : Json,
) -> Bool {
  match literal {
    String(_) | Number(_, ..) | True | False => ()
    _ => return false
  }
  let key = if property.has_prefix("properties.") {
    property[11:].to_owned()
  } else {
    property
  }
  let comparisons : Map[String, Json] = Map([])
  match query.get(key) {
    Some(Object(values)) =>
      for name, value in values {
        comparisons[name] = value
      }
    _ => ()
  }
  if comparisons.contains(op) {
    return false
  }
  comparisons[op] = literal
  query[key] = Json::object(comparisons)
  true
}
