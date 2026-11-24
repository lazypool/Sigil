///|
/// Pure normalization helpers for AI-produced charts and tables.
///
/// Every function here is side-effect free. Tables are clamped to the editor
/// limits (5 columns, 60 chars per cell, 200 data rows) before they may enter a
/// document; charts are reduced to a valid `kind` and a `:::chart` body.

///|
/// Convert JSON (array of objects, 2D array, or a single object) to RFC-4180 CSV.
pub fn json_to_csv(text : String) -> String {
  let value = @json.parse(text) catch { _ => return "" }
  encode_rows(json_rows(value))
}

///|
/// Normalize CSV input: drop blank lines and unify the delimiter to comma,
/// re-encoding the result as RFC-4180 CSV.
pub fn csv_to_csv(text : String) -> String {
  let delimiter = detect_delimiter(text)
  encode_rows(parse_delimited(text, delimiter))
}

///|
/// Sniff whether the input is JSON or CSV and return normalized CSV.
pub fn json_or_csv_to_csv(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  let first = trimmed[0]
  if first == '[' || first == '{' {
    json_to_csv(trimmed)
  } else {
    csv_to_csv(trimmed)
  }
}

///|
/// Convert CSV into a `:::chart` body made of `title`, `labels`, and `series`
/// directives. The first column becomes the category labels and every remaining
/// column becomes one series named after its header cell.
pub fn csv_to_chart_body(text : String, kind : String) -> String {
  ignore(kind)
  let rows = parse_delimited(text, detect_delimiter(text))
  chart_body_from_rows(rows)
}

///|
/// Clamp a table to the editor limits: at most 5 columns, 60 characters per
/// cell, and 200 data rows.
pub fn limit_table(csv : String) -> String {
  let limited = @render.csv_limit_table(csv, 5, 60)
  limit_rows(limited, 201)
}

///|
/// Whether the given kind is one of the 9 supported chart kinds.
pub fn valid_chart_kind(kind : String) -> Bool {
  match kind.trim().to_owned().to_lower() {
    "bar" | "stacked" | "line" | "area" | "pie" | "donut" | "scatter" |
    "radar" | "heatmap" => true
    _ => false
  }
}

///|
fn json_rows(value : @json.Json) -> Array[Array[String]] {
  match value {
    @json.Json::Array(items) => array_rows(items)
    @json.Json::Object(map) => object_rows(map)
    _ => []
  }
}

///|
fn array_rows(items : Array[@json.Json]) -> Array[Array[String]] {
  if items.is_empty() {
    return []
  }
  match items[0] {
    @json.Json::Object(_) => object_array_rows(items)
    @json.Json::Array(_) => nested_array_rows(items)
    _ => []
  }
}

///|
fn object_array_rows(items : Array[@json.Json]) -> Array[Array[String]] {
  let header = match items[0] {
    @json.Json::Object(map) => sorted_keys(map)
    _ => []
  }
  if header.is_empty() {
    return []
  }
  let rows : Array[Array[String]] = [header]
  for item in items {
    match item {
      @json.Json::Object(map) => {
        let row : Array[String] = []
        for key in header {
          match map.get(key) {
            Some(value) => row.push(json_to_string(value))
            None => row.push("")
          }
        }
        rows.push(row)
      }
      _ => ()
    }
  }
  rows
}

///|
fn nested_array_rows(items : Array[@json.Json]) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for item in items {
    match item {
      @json.Json::Array(cells) => {
        let row : Array[String] = []
        for cell in cells {
          row.push(json_to_string(cell))
        }
        rows.push(row)
      }
      _ => ()
    }
  }
  rows
}

///|
fn object_rows(map : Map[String, @json.Json]) -> Array[Array[String]] {
  let keys = sorted_keys(map)
  let rows : Array[Array[String]] = [["key", "value"]]
  for key in keys {
    match map.get(key) {
      Some(value) => rows.push([key, json_to_string(value)])
      None => rows.push([key, ""])
    }
  }
  rows
}

///|
fn sorted_keys(map : Map[String, @json.Json]) -> Array[String] {
  let keys : Array[String] = []
  for key, _ in map {
    keys.push(key)
  }
  keys.sort()
  keys
}

///|
fn json_to_string(value : @json.Json) -> String {
  match value {
    @json.Json::Null => ""
    @json.Json::True => "true"
    @json.Json::False => "false"
    @json.Json::Number(number, repr~) => match repr {
      Some(raw) => raw
      None => number.to_string()
    }
    @json.Json::String(text) => text
    @json.Json::Array(_) | @json.Json::Object(_) => value.stringify()
  }
}

///|
fn detect_delimiter(text : String) -> Char {
  let mut commas = 0
  let mut tabs = 0
  let mut semicolons = 0
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    for ch in trimmed {
      match ch {
        ',' => commas = commas + 1
        '\t' => tabs = tabs + 1
        ';' => semicolons = semicolons + 1
        _ => ()
      }
    }
    if commas > 0 || tabs > 0 || semicolons > 0 {
      break
    }
  }
  if tabs > commas && tabs >= semicolons {
    '\t'
  } else if semicolons > commas {
    ';'
  } else {
    ','
  }
}

///|
fn parse_delimited(
  text : String,
  delimiter : Char,
) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let row : Array[String] = []
  let field = StringBuilder()
  let chars = text.to_array()
  let length = chars.length()
  let mut index = 0
  let mut in_quotes = false
  let mut field_empty = true
  while index < length {
    let ch = chars[index]
    if in_quotes {
      if ch == '"' {
        if index + 1 < length && chars[index + 1] == '"' {
          field.write_char('"')
          index = index + 2
        } else {
          in_quotes = false
          index = index + 1
        }
      } else {
        field.write_char(ch)
        index = index + 1
      }
      continue
    }
    if ch == '"' && field_empty {
      in_quotes = true
      field_empty = false
      index = index + 1
      continue
    }
    if ch == delimiter {
      row.push(field.to_string())
      ignore(field.reset())
      field_empty = true
      index = index + 1
      continue
    }
    if ch == '\r' {
      if index + 1 < length && chars[index + 1] == '\n' {
        index = index + 1
        continue
      }
      row.push(field.to_string())
      ignore(field.reset())
      field_empty = true
      push_row(rows, row)
      row.clear()
      index = index + 1
      continue
    }
    if ch == '\n' {
      row.push(field.to_string())
      ignore(field.reset())
      field_empty = true
      push_row(rows, row)
      row.clear()
      index = index + 1
      continue
    }
    field.write_char(ch)
    field_empty = false
    index = index + 1
  }
  if !field_empty || !row.is_empty() {
    row.push(field.to_string())
    push_row(rows, row)
  }
  rows
}

///|
fn push_row(rows : Array[Array[String]], row : Array[String]) -> Unit {
  let mut blank = true
  for cell in row {
    if cell.trim() != "" {
      blank = false
    }
  }
  if blank {
    return
  }
  rows.push(row.copy())
}

///|
fn encode_field(value : String) -> String {
  if value.contains(",") ||
    value.contains("\"") ||
    value.contains("\n") ||
    value.contains("\r") {
    "\"" + value.replace_all(old="\"", new="\"\"") + "\""
  } else {
    value
  }
}

///|
fn encode_rows(rows : Array[Array[String]]) -> String {
  let lines : Array[String] = []
  for row in rows {
    let cells : Array[String] = []
    for cell in row {
      cells.push(encode_field(cell))
    }
    lines.push(cells.join(","))
  }
  lines.join("\r\n")
}

///|
fn limit_rows(csv : String, max_rows : Int32) -> String {
  let rows = parse_delimited(csv, ',')
  if rows.length() <= max_rows {
    return csv
  }
  let kept : Array[Array[String]] = []
  let mut index = 0
  while index < max_rows && index < rows.length() {
    kept.push(rows[index])
    index = index + 1
  }
  encode_rows(kept)
}

///|
fn chart_body_from_rows(rows : Array[Array[String]]) -> String {
  let title = "Chart"
  if rows.is_empty() {
    return "title: " + title + "\nlabels: \nseries: "
  }
  let header = rows[0]
  let mut columns = 0
  for row in rows {
    if row.length() > columns {
      columns = row.length()
    }
  }
  let labels : Array[String] = []
  let mut index = 1
  while index < rows.length() {
    let row = rows[index]
    labels.push(if row.length() > 0 { row[0] } else { "" })
    index = index + 1
  }
  let builder = StringBuilder()
  builder.write_string("title: " + title + "\n")
  builder.write_string("labels: " + labels.join(", ") + "\n")
  let mut column = 1
  while column < columns {
    let name = if column < header.length() && header[column] != "" {
      header[column]
    } else {
      "Series " + column.to_string()
    }
    let values : Array[String] = []
    let mut row_index = 1
    while row_index < rows.length() {
      let row = rows[row_index]
      values.push(if column < row.length() { row[column] } else { "" })
      row_index = row_index + 1
    }
    builder.write_string("series: " + name + " = " + values.join(", ") + "\n")
    column = column + 1
  }
  builder.to_string()
}
