///|
/// Validate fields needed to use an Item safely as a search result.
/// This is intentionally smaller than the full STAC JSON Schemas.
fn validate_item_shape(v : Json, collection : String?) -> Unit raise StacError {
  validate_extensions(v)
  let has_collection_link = validate_links(v, "item")
  match collection {
    Some(name) =>
      if name == "" || !has_collection_link {
        raise Invalid("collection requires collection link")
      }
    None =>
      if has_collection_link {
        raise Invalid("collection link requires collection id")
      }
  }
  let geometry = match field(v, "geometry") {
    Some(value) => value
    None => raise Invalid("missing geometry")
  }
  match geometry {
    Null =>
      if field(v, "bbox") != None {
        raise Invalid("bbox must be absent when geometry is null")
      }
    Object(_) => {
      validate_geometry(geometry)
      validate_bbox(v)
    }
    _ => raise Invalid("invalid geometry")
  }
  let properties = match field(v, "properties") {
    Some(Object(m)) => Json::object(m)
    _ => raise Invalid("invalid properties")
  }
  validate_item_time(properties)
  validate_assets(v)
}

///|
fn validate_extensions(v : Json) -> Unit raise StacError {
  match field(v, "stac_extensions") {
    None => ()
    Some(Array(xs)) => {
      let seen : Map[String, Bool] = Map([])
      for value in xs {
        match value {
          String(name) if name != "" => {
            if seen.contains(name) {
              raise Invalid("duplicate stac_extension")
            }
            seen[name] = true
          }
          _ => raise Invalid("invalid stac_extensions")
        }
      }
    }
    _ => raise Invalid("invalid stac_extensions")
  }
}

///|
fn validate_links(v : Json, context : String) -> Bool raise StacError {
  let links = match field(v, "links") {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid " + context + " links")
  }
  let mut has_collection = false
  for link in links {
    let rel = string_field(link, "rel")
    ignore(string_field(link, "href"))
    if rel == "collection" {
      has_collection = true
    }
  }
  has_collection
}

///|
fn validate_bbox(v : Json) -> Unit raise StacError {
  let bbox = match field(v, "bbox") {
    Some(Array(xs)) => xs
    _ => raise Invalid("missing bbox")
  }
  if bbox.length() != 4 && bbox.length() != 6 {
    raise Invalid("invalid bbox length")
  }
  for value in bbox {
    match value {
      Number(_, ..) => ()
      _ => raise Invalid("invalid bbox value")
    }
  }
}

///|
fn validate_geometry(v : Json) -> Unit raise StacError {
  let kind = string_field(v, "type")
  if kind == "GeometryCollection" {
    let parts = match field(v, "geometries") {
      Some(Array(xs)) => xs
      _ => raise Invalid("invalid geometries")
    }
    for part in parts {
      validate_geometry(part)
    }
  } else {
    if kind != "Point" &&
      kind != "MultiPoint" &&
      kind != "LineString" &&
      kind != "MultiLineString" &&
      kind != "Polygon" &&
      kind != "MultiPolygon" {
      raise Invalid("invalid geometry type")
    }
    let coordinates = match field(v, "coordinates") {
      Some(value) => value
      None => raise Invalid("missing coordinates")
    }
    validate_coordinates(coordinates, 0)
  }
}

///|
fn validate_coordinates(value : Json, depth : Int) -> Unit raise StacError {
  if depth > 8 {
    raise Invalid("coordinates too deeply nested")
  }
  match value {
    Array(xs) => {
      if xs.length() == 0 {
        raise Invalid("empty coordinates")
      }
      for part in xs {
        validate_coordinates(part, depth + 1)
      }
    }
    Number(_, ..) => ()
    _ => raise Invalid("invalid coordinates")
  }
}

///|
fn validate_item_time(properties : Json) -> Unit raise StacError {
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
}

///|
fn validate_assets(v : Json) -> Unit raise StacError {
  let assets = match field(v, "assets") {
    Some(Object(m)) => m
    _ => raise Invalid("invalid assets")
  }
  for key, asset in assets {
    if key == "" {
      raise Invalid("empty asset key")
    }
    ignore(string_field(asset, "href"))
    validate_asset_string(asset, "title")
    validate_asset_string(asset, "description")
    validate_asset_string(asset, "type")
    match field(asset, "roles") {
      None => ()
      Some(Array(roles)) =>
        for role in roles {
          match role {
            String(s) if s != "" => ()
            _ => raise Invalid("invalid asset role")
          }
        }
      _ => raise Invalid("invalid asset roles")
    }
  }
}

///|
fn validate_asset_string(asset : Json, name : String) -> Unit raise StacError {
  match field(asset, name) {
    None | Some(String(_)) => ()
    _ => raise Invalid("invalid asset " + name)
  }
}
