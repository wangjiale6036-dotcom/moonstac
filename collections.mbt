///|
pub(all) struct Collection {
  id : String
  title : String?
  description : String
  license : String
} derive(Debug, Eq)

///|
pub(all) struct CollectionPage {
  collections : Array[Collection]
  next : String?
} derive(Debug, Eq)

///|
pub fn parse_collections(text : String) -> CollectionPage raise StacError {
  let v = @json.parse(text) catch { _ => raise Invalid("invalid JSON") }
  let values = match field(v, "collections") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid collections")
  }
  let collections : Array[Collection] = []
  for value in values {
    if string_field(value, "type") != "Collection" {
      raise Invalid("expected Collection")
    }
    let version = string_field(value, "stac_version")
    if version != "1.0.0" && version != "1.1.0" {
      raise Invalid("unsupported stac_version")
    }
    let id = string_field(value, "id")
    let title = optional_string(value, "title")
    let description = string_field(value, "description")
    let license = string_field(value, "license")
    ignore(validate_links(value, "collection"))
    validate_extent(value)
    collections.push({ id, title, description, license })
  }
  ignore(validate_links(v, "collection page"))
  let links = match field(v, "links") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid links")
  }
  let mut next : String? = None
  for link in links {
    if optional_string(link, "rel") == Some("next") {
      if next != None {
        raise Invalid("multiple next links")
      }
      next = Some(string_field(link, "href"))
    }
  }
  { collections, next }
}

///|
fn validate_extent(value : Json) -> Unit raise StacError {
  let extent = match field(value, "extent") {
    Some(Object(m)) => Json::object(m)
    _ => raise Invalid("invalid extent")
  }
  let spatial = match field(extent, "spatial") {
    Some(Object(m)) => Json::object(m)
    _ => raise Invalid("invalid spatial extent")
  }
  let temporal = match field(extent, "temporal") {
    Some(Object(m)) => Json::object(m)
    _ => raise Invalid("invalid temporal extent")
  }
  match field(spatial, "bbox") {
    Some(Array(xs)) if xs.length() > 0 => ()
    _ => raise Invalid("invalid spatial bbox")
  }
  match field(temporal, "interval") {
    Some(Array(xs)) if xs.length() > 0 => ()
    _ => raise Invalid("invalid temporal interval")
  }
}

///|
pub fn collections_summary(input : String) -> String {
  collections_summary_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn collections_summary_checked(input : String) -> String raise StacError {
  let page = parse_collections(input)
  let collections : Array[Json] = []
  for collection in page.collections {
    let entry : Json = {
      "id": collection.id,
      "title": match collection.title {
        Some(s) => Json::string(s)
        None => Json::null()
      },
      "description": collection.description,
      "license": collection.license,
    }
    collections.push(entry)
  }
  let output : Json = {
    "status": "ok",
    "collections": Json::array(collections),
    "next": match page.next {
      Some(s) => Json::string(s)
      None => Json::null()
    },
  }
  output.stringify()
}
