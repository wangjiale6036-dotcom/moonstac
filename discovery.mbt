///|
pub(all) struct Landing {
  id : String
  description : String
  search : String?
  collections : String?
  conforms_to : Array[String]
} derive(Debug, Eq)

///|
pub fn parse_landing(text : String) -> Landing raise StacError {
  let v = @json.parse(text) catch { _ => raise Invalid("invalid JSON") }
  let version = string_field(v, "stac_version")
  if version != "1.0.0" && version != "1.1.0" {
    raise Invalid("unsupported stac_version")
  }
  if string_field(v, "type") != "Catalog" {
    raise Invalid("expected Catalog")
  }
  let id = string_field(v, "id")
  let description = string_field(v, "description")
  ignore(validate_links(v, "landing"))
  let links = match field(v, "links") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid links")
  }
  let mut search : String? = None
  let mut collections : String? = None
  for link in links {
    let rel = string_field(link, "rel")
    if rel == "search" && search == None {
      search = Some(string_field(link, "href"))
    }
    if rel == "data" && collections == None {
      collections = Some(string_field(link, "href"))
    }
  }
  let conforms_to : Array[String] = []
  match field(v, "conformsTo") {
    None => ()
    Some(Array(values)) =>
      for value in values {
        match value {
          String(uri) if uri != "" => conforms_to.push(uri)
          _ => raise Invalid("invalid conformsTo")
        }
      }
    _ => raise Invalid("invalid conformsTo")
  }
  { id, description, search, collections, conforms_to }
}

///|
pub fn landing_summary(input : String) -> String {
  landing_summary_checked(input) catch {
    Invalid(message) => error_json(message)
  }
}

///|
fn landing_summary_checked(input : String) -> String raise StacError {
  let landing = parse_landing(input)
  let conforms : Array[Json] = []
  for uri in landing.conforms_to {
    conforms.push(Json::string(uri))
  }
  let output : Json = {
    "status": "ok",
    "id": landing.id,
    "description": landing.description,
    "search": match landing.search {
      Some(uri) => Json::string(uri)
      None => Json::null()
    },
    "collections": match landing.collections {
      Some(uri) => Json::string(uri)
      None => Json::null()
    },
    "conformsTo": Json::array(conforms),
  }
  output.stringify()
}
