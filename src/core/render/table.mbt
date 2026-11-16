///|
/// Parse RFC 4180-style CSV, including quoted fields and embedded newlines.
fn csv_parse(text : String) -> Array[Array[String]] {
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
    if ch == ',' {
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
      rows.push(row.copy())
      row.clear()
      index = index + 1
      continue
    }
    if ch == '\n' {
      row.push(field.to_string())
      ignore(field.reset())
      field_empty = true
      rows.push(row.copy())
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
    rows.push(row.copy())
  }
  rows
}

///|
fn csv_encode_field(value : String) -> String {
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
fn csv_encode_rows(rows : Array[Array[String]]) -> String {
  let lines : Array[String] = []
  for row in rows {
    let cells : Array[String] = []
    for cell in row {
      cells.push(csv_encode_field(cell))
    }
    lines.push(cells.join(","))
  }
  lines.join("\r\n")
}

///|
fn csv_columns(rows : Array[Array[String]]) -> Int32 {
  let mut columns = 0
  for row in rows {
    if row.length() > columns {
      columns = row.length()
    }
  }
  columns
}

///|
/// Update one cell and return the re-encoded CSV.
pub fn csv_set_cell(
  csv : String,
  row_index : Int32,
  column_index : Int32,
  value : String,
) -> String {
  let rows = csv_parse(csv)
  if rows.is_empty() {
    rows.push([])
  }
  while rows.length() <= row_index {
    rows.push([])
  }
  let row = rows[row_index]
  while row.length() <= column_index {
    row.push("")
  }
  row[column_index] = value
  csv_encode_rows(rows)
}

///|
/// Append an empty row and return the re-encoded CSV.
pub fn csv_append_row(csv : String) -> String {
  let rows = csv_parse(csv)
  let columns = if rows.is_empty() { 1 } else { csv_columns(rows) }
  let row : Array[String] = []
  for _ in 0..<columns {
    row.push("")
  }
  rows.push(row)
  let encoded = csv_encode_rows(rows)
  if encoded == "" && !rows.is_empty() {
    "\r\n"
  } else {
    encoded
  }
}

///|
/// Append a column with a header label and return the re-encoded CSV.
pub fn csv_append_column(csv : String, name : String) -> String {
  let rows = csv_parse(csv)
  if rows.is_empty() {
    rows.push([name])
    return csv_encode_rows(rows)
  }
  let columns = csv_columns(rows)
  for row in rows {
    while row.length() < columns {
      row.push("")
    }
    row.push("")
  }
  rows[0][columns] = name
  csv_encode_rows(rows)
}

///|
fn truncate_chars(value : String, max_chars : Int32) -> String {
  let builder = StringBuilder()
  let mut count = 0
  for ch in value {
    if count >= max_chars {
      break
    }
    builder.write_char(ch)
    count = count + 1
  }
  builder.to_string()
}

///|
/// Clamp a table to the editor limits: at most `max_columns` columns and
/// `max_chars` characters per cell.
pub fn csv_limit_table(
  csv : String,
  max_columns : Int32,
  max_chars : Int32,
) -> String {
  let rows = csv_parse(csv)
  let result : Array[Array[String]] = []
  for row in rows {
    let cells : Array[String] = []
    let mut index = 0
    while index < row.length() && index < max_columns {
      cells.push(truncate_chars(row[index], max_chars))
      index = index + 1
    }
    result.push(cells)
  }
  csv_encode_rows(result)
}

///|
/// Render a CSV asset to the table HTML used in emails, for library previews.
pub fn render_csv_table_html(csv : String, accent : String) -> String {
  csv_table_html(accent, csv_parse(csv))
}

///|
/// Number of rows and the widest row in a CSV asset.
pub fn csv_dimensions(csv : String) -> (Int32, Int32) {
  let rows = csv_parse(csv)
  let mut columns = 0
  for row in rows {
    if row.length() > columns {
      columns = row.length()
    }
  }
  (rows.length(), columns)
}

///|
fn hex_char(value : Int32) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    _ => 'F'
  }
}

///|
fn hex_byte(value : Int32) -> String {
  let builder = StringBuilder()
  builder.write_char(hex_char(value / 16))
  builder.write_char(hex_char(value % 16))
  builder.to_string()
}

///|
fn hex_digit(ch : Char) -> Int32 {
  let code = ch.to_uint()
  if code >= 48 && code <= 57 {
    (code - 48).reinterpret_as_int()
  } else if code >= 65 && code <= 70 {
    (code - 55).reinterpret_as_int()
  } else if code >= 97 && code <= 102 {
    (code - 87).reinterpret_as_int()
  } else {
    -1
  }
}

///|
fn hex_channel(chars : Array[Char], start : Int32) -> Int32? {
  let high = hex_digit(chars[start])
  let low = hex_digit(chars[start + 1])
  if high < 0 || low < 0 {
    None
  } else {
    Some(high * 16 + low)
  }
}

///|
fn blend_channel(value : Int32, percent : Int32) -> Int32 {
  (value * percent + 255 * (100 - percent) + 50) / 100
}

///|
/// Blend the theme color with white so table headers stay light but tinted.
fn tint_color(accent : String, percent : Int32) -> String {
  let chars = accent.to_array()
  if chars.length() != 7 || chars[0] != '#' {
    return "#F5F7FA"
  }
  let red = match hex_channel(chars, 1) {
    Some(value) => value
    None => return "#F5F7FA"
  }
  let green = match hex_channel(chars, 3) {
    Some(value) => value
    None => return "#F5F7FA"
  }
  let blue = match hex_channel(chars, 5) {
    Some(value) => value
    None => return "#F5F7FA"
  }
  "#" +
  hex_byte(blend_channel(red, percent)) +
  hex_byte(blend_channel(green, percent)) +
  hex_byte(blend_channel(blue, percent))
}

///|
fn csv_cell(cell : String) -> String {
  escape_html(cell)
}

///|
fn csv_table_html(accent : String, rows : Array[Array[String]]) -> String {
  if rows.is_empty() {
    return ""
  }
  let mut columns = 0
  for row in rows {
    if row.length() > columns {
      columns = row.length()
    }
  }
  let header_bg = tint_color(accent, 15)
  let builder = StringBuilder()
  builder.write_string(
    "<div class=\"sigil-table-scroll\" style=\"margin:20px 0;max-width:100%;text-align:center;overflow-x:auto;-webkit-overflow-scrolling:touch;\">" +
    "<table role=\"presentation\" align=\"center\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" " +
    "style=\"width:100%;max-width:100%;margin:0 auto;border-collapse:collapse;table-layout:fixed;font-size:14px;line-height:1.5;color:#222833;\">",
  )
  builder.write_string("<thead><tr>")
  let header = rows[0]
  for index = 0; index < columns; index = index + 1 {
    let value = if index < header.length() {
      header[index]
    } else {
      ""
    }
    builder.write_string(
      "<th style=\"border:1px solid #E2E5EA;padding:8px 10px;background:" +
      header_bg +
      ";text-align:left;vertical-align:top;font-weight:600;word-break:break-word;\">" +
      csv_cell(value) +
      "</th>",
    )
  }
  builder.write_string("</tr></thead><tbody>")
  let mut row_index = 1
  while row_index < rows.length() {
    let row = rows[row_index]
    let row_background = if row_index % 2 == 0 {
      "background:#F7F8FA;"
    } else {
      ""
    }
    builder.write_string("<tr>")
    for index = 0; index < columns; index = index + 1 {
      let value = if index < row.length() { row[index] } else { "" }
      builder.write_string(
        "<td style=\"border:1px solid #E2E5EA;padding:8px 10px;text-align:left;vertical-align:top;word-break:break-word;" +
        row_background +
        "\">" +
        csv_cell(value) +
        "</td>",
      )
    }
    builder.write_string("</tr>")
    row_index = row_index + 1
  }
  builder.write_string("</tbody></table></div>")
  builder.to_string()
}

///|
fn render_table(
  name : String,
  tables : Map[String, String],
  accent : String,
) -> String {
  match tables.get(name) {
    Some(csv) => {
      let html = csv_table_html(accent, csv_parse(csv))
      if html == "" {
        "<p style=\"margin:0 0 14px;color:#8a8a8a;\">[table:" +
        escape_html(name) +
        "]</p>"
      } else {
        html
      }
    }
    None =>
      "<p style=\"margin:0 0 14px;color:#8a8a8a;\">[table:" +
      escape_html(name) +
      "]</p>"
  }
}

///|
/// Return the first few rows and columns of a CSV asset for card previews.
pub fn csv_preview(
  csv : String,
  max_rows : Int32,
  max_columns : Int32,
) -> Array[Array[String]] {
  let rows = csv_parse(csv)
  let result : Array[Array[String]] = []
  let row_limit = if max_rows < rows.length() { max_rows } else { rows.length() }
  let mut row_index = 0
  while row_index < row_limit {
    let source = rows[row_index]
    let cells : Array[String] = []
    let column_limit = if max_columns < source.length() {
      max_columns
    } else {
      source.length()
    }
    let mut column_index = 0
    while column_index < column_limit {
      cells.push(source[column_index])
      column_index = column_index + 1
    }
    result.push(cells)
    row_index = row_index + 1
  }
  result
}
