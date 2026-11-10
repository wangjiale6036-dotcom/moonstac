///|
/// Validate GeoJSON coordinate nesting and minimum geometry cardinalities.
/// It does not test ring self-intersections or winding order.
fn validate_geojson_geometry(v : Json, depth : Int) -> Unit raise StacError {
  if depth > 8 {
    raise Invalid("geometry too deeply nested")
  }
  let kind = string_field(v, "type")
  if kind == "GeometryCollection" {
    let geometries = array_field(v, "geometries")
    if geometries.length() == 0 {
      raise Invalid("empty GeometryCollection")
    }
    for geometry in geometries {
      validate_geojson_geometry(geometry, depth + 1)
    }
    return
  }
  let coordinates = match field(v, "coordinates") {
    Some(value) => value
    None => raise Invalid("missing coordinates")
  }
  match kind {
    "Point" => ignore(position_coords(coordinates))
    "MultiPoint" => {
      let points = required_array(coordinates, "MultiPoint")
      if points.length() == 0 {
        raise Invalid("empty MultiPoint")
      }
      for point in points {
        ignore(position_coords(point))
      }
    }
    "LineString" => validate_line(coordinates)
    "MultiLineString" => {
      let lines = required_array(coordinates, "MultiLineString")
      if lines.length() == 0 {
        raise Invalid("empty MultiLineString")
      }
      for line in lines {
        validate_line(line)
      }
    }
    "Polygon" => validate_polygon(coordinates)
    "MultiPolygon" => {
      let polygons = required_array(coordinates, "MultiPolygon")
      if polygons.length() == 0 {
        raise Invalid("empty MultiPolygon")
      }
      for polygon in polygons {
        validate_polygon(polygon)
      }
    }
    _ => raise Invalid("invalid geometry type")
  }
}

///|
fn required_array(v : Json, label : String) -> Array[Json] raise StacError {
  match v {
    Array(xs) => xs
    _ => raise Invalid("invalid " + label + " coordinates")
  }
}

///|
fn array_field(v : Json, name : String) -> Array[Json] raise StacError {
  match field(v, name) {
    Some(Array(xs)) => xs
    _ => raise Invalid("invalid " + name)
  }
}

///|
fn position_coords(v : Json) -> Array[Double] raise StacError {
  let values = required_array(v, "position")
  if values.length() != 2 && values.length() != 3 {
    raise Invalid("position must have two or three numbers")
  }
  let coords : Array[Double] = []
  for value in values {
    match value {
      Number(n, ..) => coords.push(n)
      _ => raise Invalid("non-numeric position coordinate")
    }
  }
  coords
}

///|
fn validate_line(v : Json) -> Unit raise StacError {
  let points = required_array(v, "LineString")
  if points.length() < 2 {
    raise Invalid("LineString requires two positions")
  }
  for point in points {
    ignore(position_coords(point))
  }
}

///|
fn validate_polygon(v : Json) -> Unit raise StacError {
  let rings = required_array(v, "Polygon")
  if rings.length() == 0 {
    raise Invalid("Polygon requires a ring")
  }
  for ring in rings {
    validate_ring(ring)
  }
}

///|
fn validate_ring(v : Json) -> Unit raise StacError {
  let points = required_array(v, "linear ring")
  if points.length() < 4 {
    raise Invalid("linear ring requires four positions")
  }
  let first = position_coords(points[0])
  for point in points {
    ignore(position_coords(point))
  }
  let last = position_coords(points[points.length() - 1])
  if first.length() != last.length() {
    raise Invalid("linear ring is not closed")
  }
  for i in 0..<first.length() {
    if first[i] != last[i] {
      raise Invalid("linear ring is not closed")
    }
  }
}
