///|
pub(all) suberror StacError {
  Invalid(String)
} derive(Debug)

///|
pub(all) struct Asset {
  key : String
  href : String
} derive(Debug, Eq)

///|
pub(all) struct Item {
  id : String
  collection : String?
  datetime : String?
  assets : Array[Asset]
} derive(Debug, Eq)

///|
pub(all) struct NextLink {
  href : String
  http_method : String
  body : Json?
  headers : Json?
  merge : Bool
} derive(Debug, Eq)

///|
pub(all) struct ItemPage {
  items : Array[Item]
  next : NextLink?
} derive(Debug, Eq)

///|
fn field(v : Json, name : String) -> Json? {
  match v {
    Object(fields) => fields.get(name)
    _ => None
  }
}

///|
fn string_field(v : Json, name : String) -> String raise StacError {
  match field(v, name) {
    Some(String(s)) if s != "" => s
    _ => raise Invalid("invalid " + name)
  }
}

///|
fn optional_string(v : Json, name : String) -> String? raise StacError {
  match field(v, name) {
    None | Some(Null) => None
    Some(String(s)) => Some(s)
    _ => raise Invalid("invalid " + name)
  }
}

///|
pub fn parse_item_json(v : Json) -> Item raise StacError {
  let version = string_field(v, "stac_version")
  if version != "1.0.0" && version != "1.1.0" {
    raise Invalid("unsupported stac_version")
  }
  if string_field(v, "type") != "Feature" {
    raise Invalid("expected Feature")
  }
  let id = string_field(v, "id")
  let collection = optional_string(v, "collection")
  match field(v, "geometry") {
    Some(Null) =>
      if field(v, "bbox") != None {
        raise Invalid("bbox must be absent when geometry is null")
      }
    Some(Object(_)) => {
      let bbox = match field(v, "bbox") {
        Some(Array(xs)) => xs
        _ => raise Invalid("missing bbox")
      }
      if bbox.length() != 4 && bbox.length() != 6 {
        raise Invalid("invalid bbox")
      }
      for value in bbox {
        match value {
          Number(_, ..) => ()
          _ => raise Invalid("invalid bbox")
        }
      }
    }
    _ => raise Invalid("invalid geometry")
  }
  match field(v, "links") {
    Some(Array(_)) => ()
    _ => raise Invalid("invalid links")
  }
  let properties = match field(v, "properties") {
    Some(Object(m)) => Json::object(m)
    _ => raise Invalid("invalid properties")
  }
  let datetime = optional_string(properties, "datetime")
  match datetime {
    Some(s) if s != "" => ()
    _ =>
      if !(field(properties, "datetime") is Some(Null)) ||
        optional_string(properties, "start_datetime") == None ||
        optional_string(properties, "end_datetime") == None {
        raise Invalid("missing datetime or interval")
      }
  }
  let entries = match field(v, "assets") {
    Some(Object(m)) => m
    _ => raise Invalid("invalid assets")
  }
  let assets : Array[Asset] = []
  for key, data in entries {
    assets.push({ key, href: string_field(data, "href") })
  }
  { id, collection, datetime, assets }
}

///|
pub fn parse_item(text : String) -> Item raise StacError {
  let v = @json.parse(text) catch { _ => raise Invalid("invalid JSON") }
  parse_item_json(v)
}

///|
pub fn parse_page(text : String) -> ItemPage raise StacError {
  let v = @json.parse(text) catch { _ => raise Invalid("invalid JSON") }
  if string_field(v, "type") != "FeatureCollection" {
    raise Invalid("expected FeatureCollection")
  }
  let features = match field(v, "features") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid features")
  }
  let items : Array[Item] = []
  for feature in features {
    items.push(parse_item_json(feature))
  }
  let mut next : NextLink? = None
  match field(v, "links") {
    Some(Array(links)) =>
      for link in links {
        if optional_string(link, "rel") == Some("next") {
          if next != None {
            raise Invalid("multiple next links")
          }
          let http_method = optional_string(link, "method").unwrap_or("GET")
          if http_method != "GET" && http_method != "POST" {
            raise Invalid("unsupported next method")
          }
          let body = field(link, "body")
          match body {
            None | Some(Object(_)) => ()
            _ => raise Invalid("invalid next body")
          }
          let headers = field(link, "headers")
          match headers {
            None | Some(Object(_)) => ()
            _ => raise Invalid("invalid next headers")
          }
          let merge = match field(link, "merge") {
            None | Some(False) => false
            Some(True) => true
            _ => raise Invalid("invalid next merge")
          }
          next = Some({
            href: string_field(link, "href"),
            http_method,
            body,
            headers,
            merge,
          })
        }
      }
    None => ()
    _ => raise Invalid("invalid links")
  }
  { items, next }
}

///|
pub fn search_body(
  bbox : Array[Double],
  datetime : String?,
  collections : Array[String],
  limit : Int,
) -> String raise StacError {
  if limit < 1 || limit > 1000 || bbox.length() != 4 {
    raise Invalid("invalid search limit or bbox")
  }
  if bbox[0] > bbox[2] ||
    bbox[1] > bbox[3] ||
    bbox[0] < -180.0 ||
    bbox[2] > 180.0 ||
    bbox[1] < -90.0 ||
    bbox[3] > 90.0 {
    raise Invalid("invalid bbox")
  }
  let nums : Array[Json] = []
  for n in bbox {
    nums.push(Json::number(n))
  }
  let names : Array[Json] = []
  for name in collections {
    names.push(Json::string(name))
  }
  let out : Map[String, Json] = Map([])
  out["bbox"] = Json::array(nums)
  out["limit"] = Json::number(limit.to_double())
  if names.length() > 0 {
    out["collections"] = Json::array(names)
  }
  match datetime {
    Some(s) if s != "" => out["datetime"] = Json::string(s)
    _ => ()
  }
  Json::object(out).stringify()
}

///|
pub fn search_request(input : String) -> String {
  search_request_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn search_request_checked(input : String) -> String raise StacError {
  let v = @json.parse(input) catch { _ => raise Invalid("invalid JSON") }
  let raw_bbox = match field(v, "bbox") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid bbox")
  }
  let bbox : Array[Double] = []
  for value in raw_bbox {
    match value {
      Number(n, ..) => bbox.push(n)
      _ => raise Invalid("invalid bbox value")
    }
  }
  let collections : Array[String] = []
  match field(v, "collections") {
    None => ()
    Some(Array(xs)) =>
      for value in xs {
        match value {
          String(name) if name != "" => collections.push(name)
          _ => raise Invalid("invalid collection")
        }
      }
    _ => raise Invalid("invalid collections")
  }
  let limit = match field(v, "limit") {
    Some(Number(n, ..)) => {
      let parsed = n.to_int()
      if parsed.to_double() != n {
        raise Invalid("invalid limit")
      }
      parsed
    }
    _ => 10
  }
  let body = search_body(
    bbox,
    optional_string(v, "datetime"),
    collections,
    limit,
  )
  let output : Json = { "status": "ok", "body": body }
  output.stringify()
}

///|
fn error_json(message : String) -> String {
  let output : Json = { "status": "invalid", "message": message }
  output.stringify()
}

///|
pub fn page_summary(input : String) -> String {
  page_summary_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn page_summary_checked(input : String) -> String raise StacError {
  let page = parse_page(input)
  let items : Array[Json] = []
  for item in page.items {
    let assets : Array[Json] = []
    for asset in item.assets {
      let entry : Json = { "key": asset.key, "href": asset.href }
      assets.push(entry)
    }
    let entry : Json = {
      "id": item.id,
      "collection": match item.collection {
        Some(s) => Json::string(s)
        None => Json::null()
      },
      "datetime": match item.datetime {
        Some(s) => Json::string(s)
        None => Json::null()
      },
      "assets": Json::array(assets),
    }
    items.push(entry)
  }
  let next : Json = match page.next {
    None => Json::null()
    Some(link) =>
      {
        "href": link.href,
        "method": link.http_method,
        "body": match link.body {
          Some(v) => v
          None => Json::null()
        },
        "headers": match link.headers {
          Some(v) => v
          None => Json::null()
        },
        "merge": link.merge,
      }
  }
  let output : Json = {
    "status": "ok",
    "items": Json::array(items),
    "next": next,
  }
  output.stringify()
}
