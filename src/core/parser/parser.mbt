///|
using @types {
  type Block,
  type Diagnostic,
  type Inline,
  type ListKind,
  type ParseResult,
  type Severity,
}

///|
priv enum ListMarker {
  Unordered(String)
  Ordered(Int32, String)
}

///|
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
fn trimmed(line : String) -> String {
  line.trim().to_owned()
}

///|
fn is_blank(line : String) -> Bool {
  line.trim().is_empty()
}

///|
fn chars_text(chars : Array[Char], start : Int32, end : Int32) -> String {
  let builder = StringBuilder()
  let mut i = start
  while i < end && i < chars.length() {
    builder.write_char(chars[i])
    i = i + 1
  }
  builder.to_string()
}

///|
fn is_latin_or_digit(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit()
}

///|
fn is_han(ch : Char) -> Bool {
  let code = ch.to_uint()
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn needs_join_space(left : Char?, right : Char?) -> Bool {
  match (left, right) {
    (Some(l), Some(r)) => {
      let l_han = is_han(l)
      let r_han = is_han(r)
      let l_latin = is_latin_or_digit(l)
      let r_latin = is_latin_or_digit(r)
      (l_han && r_latin) || (l_latin && r_han) || (l_latin && r_latin)
    }
    _ => false
  }
}

///|
fn join_lines(lines : Array[String]) -> String {
  let builder = StringBuilder()
  let mut first = true
  let mut previous : Char? = None
  for raw in lines {
    let line = trimmed(raw)
    if line == "" {
      continue
    }
    if first {
      builder.write_string(line)
      first = false
    } else {
      let first_char = line.get_char(0)
      if needs_join_space(previous, first_char) {
        builder.write_char(' ')
      }
      builder.write_string(line)
    }
    previous = line.get_char(line.length() - 1)
  }
  builder.to_string()
}

///|
fn valid_hex_color(value : String) -> Bool {
  if !value.has_prefix("#") {
    return false
  }
  let chars = value.to_array()
  let length = chars.length()
  if length != 4 && length != 7 {
    return false
  }
  for index = 1; index < length; index = index + 1 {
    if !chars[index].is_ascii_hexdigit() {
      return false
    }
  }
  true
}

///|
fn safe_link(value : String) -> Bool {
  if value == "" || value.contains(" ") || value.contains("|") {
    return false
  }
  value.has_prefix("http://") ||
  value.has_prefix("https://") ||
  value.has_prefix("mailto:")
}

///|
fn has_leading_space(line : String) -> Bool {
  match line.get_char(0) {
    Some(ch) => ch == ' ' || ch == '\t'
    None => false
  }
}

///|
fn list_marker(line : String) -> ListMarker? {
  let text = trimmed(line)
  if text.has_prefix("- ") {
    return Some(Unordered(text[2:].to_owned()))
  }
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  if index > 0 &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    let number_text = chars_text(chars, 0, index)
    let start = @string.parse_int(number_text[:]) catch { _ => 1 }
    let body = chars_text(chars, index + 2, chars.length())
    return Some(Ordered(start, body))
  }
  None
}

///|
fn push_diagnostic(
  diagnostics : Array[Diagnostic],
  severity : Severity,
  message : String,
  line : Int32,
) -> Unit {
  diagnostics.push({ severity, message, line, })
}

///|
fn flush_paragraph(
  paragraph : Array[String],
  blocks : Array[Block],
  diagnostics : Array[Diagnostic],
  line : Int32,
) -> Unit {
  if paragraph.is_empty() {
    return
  }
  let text = join_lines(paragraph)
  let inline = parse_inline(text, line, diagnostics)
  if !inline.is_empty() {
    blocks.push(Paragraph(inline))
  }
  paragraph.clear()
}

///|
fn parse_inline(
  text : String,
  line : Int32,
  diagnostics : Array[Diagnostic],
  allow_block_tags~ : Bool = true,
) -> Array[Inline] {
  parse_inline_inner(text, line, diagnostics, true, allow_block_tags)
}

///|
fn parse_inline_inner(
  text : String,
  line : Int32,
  diagnostics : Array[Diagnostic],
  allow_emphasis : Bool,
  allow_block_tags : Bool,
) -> Array[Inline] {
  let chars = text.to_array()
  let length = chars.length()
  let result : Array[Inline] = []
  let builder = StringBuilder()
  let mut has_text = false
  let mut i = 0

  fn flush_text() -> Unit {
    if has_text {
      result.push(Text(builder.to_string()))
      ignore(builder.reset())
      has_text = false
    }
  }

  while i < length {
    let ch = chars[i]
    if ch == '\\' && i + 1 < length {
      let next = chars[i + 1]
      if next == '*' || next == '\\' || next == '<' || next == '>' {
        builder.write_char(next)
        has_text = true
        i = i + 2
        continue
      }
    }
    if allow_emphasis && ch == '*' {
      let double = i + 1 < length && chars[i + 1] == '*'
      let delimiter_length = if double { 2 } else { 1 }
      let opening_valid = i + delimiter_length < length &&
        !chars[i + delimiter_length].is_whitespace() &&
        (i == 0 || !is_latin_or_digit(chars[i - 1]))
      if opening_valid {
        let mut closing = -1
        let mut scan = i + delimiter_length
        while scan < length {
          if double {
            if scan + 1 < length &&
              chars[scan] == '*' &&
              chars[scan + 1] == '*' &&
              scan > i + delimiter_length &&
              !chars[scan - 1].is_whitespace() {
              closing = scan
              break
            }
          } else if chars[scan] == '*' &&
            scan > i + delimiter_length &&
            !chars[scan - 1].is_whitespace() &&
            (scan + 1 >= length || chars[scan + 1] != '*') {
            closing = scan
            break
          }
          scan = scan + 1
        }
        if closing >= 0 {
          flush_text()
          let inner_text = chars_text(chars, i + delimiter_length, closing)
          if inner_text.contains("*") {
            push_diagnostic(
              diagnostics,
              Error,
              "Nested emphasis is not allowed.",
              line,
            )
          }
          let inner = parse_inline_inner(
            inner_text,
            line,
            diagnostics,
            false,
            allow_block_tags,
          )
          if double {
            result.push(Big(inner))
          } else {
            result.push(Strong(inner))
          }
          i = closing + delimiter_length
          continue
        } else {
          push_diagnostic(
            diagnostics,
            Warning,
            if double {
              "Unclosed ** delimiter."
            } else {
              "Unclosed * delimiter."
            },
            line,
          )
        }
      }
    }
    if ch == '<' {
      let mut close = -1
      let mut scan = i + 1
      while scan < length {
        if chars[scan] == '>' {
          close = scan
          break
        }
        scan = scan + 1
      }
      if close >= 0 {
        let tag = chars_text(chars, i + 1, close)
        if tag.has_prefix("link:") {
          flush_text()
          let rest = tag[5:].to_owned()
          let (url, label) = match rest.find("|") {
            Some(position) =>
              (rest[:position].to_owned(), rest[position + 1:].to_owned())
            None => (rest, rest)
          }
          if safe_link(url) {
            let label = if label == "" { url } else { label }
            let inline = parse_inline_inner(
              label,
              line,
              diagnostics,
              true,
              allow_block_tags,
            )
            result.push(Link(url, inline))
          } else {
            push_diagnostic(
              diagnostics,
              Error,
              "Link URL must start with http://, https://, or mailto: and must not contain spaces or |.",
              line,
            )
            result.push(Text("<" + tag + ">"))
          }
          i = close + 1
          continue
        } else if tag.has_prefix("icon:") {
          flush_text()
          let name = tag[5:].to_owned()
          if name == "" {
            push_diagnostic(diagnostics, Error, "Icon name is empty.", line)
            result.push(Text("<" + tag + ">"))
          } else {
            result.push(Icon(name))
          }
          i = close + 1
          continue
        } else if tag.has_prefix("image:") ||
          tag.has_prefix("sig:") ||
          tag.has_prefix("table:") ||
          tag.has_prefix("chart:") {
          if allow_block_tags {
            push_diagnostic(
              diagnostics,
              Error,
              "Image, signature, table, and chart insertions must occupy their own line.",
              line,
            )
          }
          flush_text()
          result.push(Text("<" + tag + ">"))
          i = close + 1
          continue
        } else {
          push_diagnostic(
            diagnostics,
            Error,
            if tag.contains(":") {
              "Unknown insertion prefix. Use sig:, image:, table:, chart:, icon:, or link:."
            } else {
              "Insertions must carry an explicit prefix."
            },
            line,
          )
          result.push(Text("<" + tag + ">"))
          i = close + 1
          continue
        }
      }
    }
    builder.write_char(ch)
    has_text = true
    i = i + 1
  }
  flush_text()
  result
}

///|
pub fn parse(source : String) -> ParseResult {
  let lines = split_lines(source)
  let diagnostics : Array[Diagnostic] = []
  let mut theme : String? = None
  let mut footer : String? = None
  let mut split : String? = None
  let mut letter : String? = None
  let mut palette : String? = None
  let mut index = 0
  let line_count = lines.length()

  let mut header_count = 0
  while index < line_count &&
        !is_blank(lines[index]) &&
        lines[index].trim().has_prefix("@") {
    let line = trimmed(lines[index])
    let line_number = index + 1
    let (key, value) = match line.find(" ") {
      Some(position) =>
        (
          line[:position].to_owned(),
          trimmed(line[position + 1:].to_owned()),
        )
      None => (line, "")
    }
    if value == "" {
      push_diagnostic(
        diagnostics,
        Error,
        "Missing value for header directive " + key + ".",
        line_number,
      )
    } else {
      match key {
        "@theme" =>
          if theme is Some(_) {
            push_diagnostic(
              diagnostics,
              Error,
              "Duplicate @theme directive.",
              line_number,
            )
          } else if !valid_hex_color(value) {
            push_diagnostic(
              diagnostics,
              Error,
              "@theme must be a hex color such as #2563EB.",
              line_number,
            )
          } else {
            theme = Some(value)
          }
        "@footer" =>
          if footer is Some(_) {
            push_diagnostic(
              diagnostics,
              Error,
              "Duplicate @footer directive.",
              line_number,
            )
          } else {
            footer = Some(value)
          }
        "@split" =>
          if split is Some(_) {
            push_diagnostic(
              diagnostics,
              Error,
              "Duplicate @split directive.",
              line_number,
            )
          } else {
            split = Some(value)
          }
        "@letter" =>
          if letter is Some(_) {
            push_diagnostic(
              diagnostics,
              Error,
              "Duplicate @letter directive.",
              line_number,
            )
          } else {
            letter = Some(value)
          }
        "@palette" =>
          if palette is Some(_) {
            push_diagnostic(
              diagnostics,
              Error,
              "Duplicate @palette directive.",
              line_number,
            )
          } else if !@types.chart_palette_valid(value) {
            push_diagnostic(
              diagnostics,
              Error,
              "@palette must be one of: " +
              @types.chart_palette_names.join(", ") +
              ".",
              line_number,
            )
          } else {
            palette = Some(value)
          }
        _ =>
          push_diagnostic(
            diagnostics,
            Error,
            "Unknown header directive " +
            key +
            ". Allowed directives are @theme, @footer, @split, @letter, and @palette.",
            line_number,
          )
      }
    }
    header_count = header_count + 1
    index = index + 1
  }
  if header_count > 0 {
    if index < line_count && is_blank(lines[index]) {
      index = index + 1
    } else {
      push_diagnostic(
        diagnostics,
        Warning,
        "Header directives must be followed by a blank line.",
        index + 1,
      )
    }
  }

  let blocks : Array[Block] = []
  let paragraph : Array[String] = []
  let mut i = index
  while i < line_count {
    let raw = lines[i]
    let line = trimmed(raw)
    let line_number = i + 1
    if line == "" {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      i = i + 1
      continue
    }
    if line == "---" {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      if blocks.is_empty() || !(blocks[blocks.length() - 1] is Divider) {
        blocks.push(Divider)
      }
      i = i + 1
      continue
    }
    if line.has_prefix("<image:") && line.has_suffix(">") {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let name = line[7:line.length() - 1].to_owned()
      if name == "" {
        push_diagnostic(diagnostics, Error, "Image path is empty.", line_number)
      } else {
        blocks.push(Image(name))
      }
      i = i + 1
      continue
    }
    if line.has_prefix("<table:") && line.has_suffix(">") {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let name = line[7:line.length() - 1].to_owned()
      if name == "" {
        push_diagnostic(diagnostics, Error, "Table file name is empty.", line_number)
      } else {
        blocks.push(Table(name))
      }
      i = i + 1
      continue
    }
    if line.has_prefix("<chart:") && line.has_suffix(">") {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let name = line[7:line.length() - 1].to_owned()
      if name == "" {
        push_diagnostic(diagnostics, Error, "Chart name is empty.", line_number)
      } else {
        blocks.push(ChartRef(name))
      }
      i = i + 1
      continue
    }
    if line.has_prefix("<sig:") && line.has_suffix(">") {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let name = line[5:line.length() - 1].to_owned()
      if name == "" {
        push_diagnostic(
          diagnostics,
          Error,
          "Signature theme id is empty.",
          line_number,
        )
      } else {
        blocks.push(Signature(name))
      }
      i = i + 1
      continue
    }
    if line == "```" {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let content : Array[String] = []
      i = i + 1
      while i < line_count && trimmed(lines[i]) != "```" {
        content.push(lines[i])
        i = i + 1
      }
      if i >= line_count {
        push_diagnostic(
          diagnostics,
          Error,
          "Unclosed plain text block. Add a closing ``` line.",
          line_number,
        )
      } else {
        i = i + 1
      }
      blocks.push(PlainText(content.join("\n")))
      continue
    }
    if line == "$$" {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let content : Array[String] = []
      i = i + 1
      while i < line_count && trimmed(lines[i]) != "$$" {
        content.push(lines[i])
        i = i + 1
      }
      if i >= line_count {
        push_diagnostic(
          diagnostics,
          Error,
          "Unclosed formula block. Add a closing $$ line.",
          line_number,
        )
      } else {
        i = i + 1
      }
      blocks.push(Formula(content.join("\n")))
      continue
    }
    if line.has_prefix(":::chart ") {
      flush_paragraph(paragraph, blocks, diagnostics, line_number)
      let chart_type = trimmed(line[9:].to_owned())
      let content : Array[String] = []
      i = i + 1
      while i < line_count && trimmed(lines[i]) != ":::" {
        content.push(lines[i])
        i = i + 1
      }
      if i >= line_count {
        push_diagnostic(
          diagnostics,
          Error,
          "Unclosed chart block. Add a closing ::: line.",
          line_number,
        )
      } else {
        i = i + 1
      }
      blocks.push(Chart(chart_type, content.join("\n")))
      continue
    }
    match list_marker(raw) {
      Some(marker) => {
        flush_paragraph(paragraph, blocks, diagnostics, line_number)
        let items : Array[Array[Inline]] = []
        let kind : ListKind = match marker {
          Unordered(_) => ListKind::Unordered
          Ordered(start, _) => ListKind::Ordered(start)
        }
        let mut expected = match kind {
          ListKind::Unordered => 0
          ListKind::Ordered(start) => start
        }
        let mut first_item = true
        while i < line_count {
          match list_marker(lines[i]) {
            Some(item) => {
              if has_leading_space(lines[i]) {
                push_diagnostic(
                  diagnostics,
                  Error,
                  "Lists support only one level.",
                  i + 1,
                )
              }
              let (item_kind, item_text) : (ListKind, String) = match item {
                Unordered(text) => (ListKind::Unordered, text)
                Ordered(start, text) => (ListKind::Ordered(start), text)
              }
              match (kind, item_kind) {
                (ListKind::Unordered, ListKind::Ordered(_))
                | (ListKind::Ordered(_), ListKind::Unordered) =>
                  push_diagnostic(
                    diagnostics,
                    Error,
                    "Ordered and unordered items must not be mixed in one list.",
                    i + 1,
                  )
                _ => ()
              }
              match (kind, item_kind) {
                (ListKind::Ordered(_), ListKind::Ordered(start)) =>
                  if !first_item && start != expected {
                    push_diagnostic(
                      diagnostics,
                      Warning,
                      "Ordered list numbers will be renumbered.",
                      i + 1,
                    )
                  }
                _ => ()
              }
              if item_text.trim().is_empty() {
                push_diagnostic(
                  diagnostics,
                  Error,
                  "List items must not be empty.",
                  i + 1,
                )
              }
              items.push(
                parse_inline(
                  item_text,
                  i + 1,
                  diagnostics,
                  allow_block_tags=false,
                ),
              )
              expected = match kind {
                ListKind::Unordered => 0
                ListKind::Ordered(_) => expected + 1
              }
              first_item = false
              i = i + 1
            }
            None => break
          }
        }
        blocks.push(ListBlock(kind, items))
        continue
      }
      None => ()
    }
    if line.has_prefix("@") {
      push_diagnostic(
        diagnostics,
        Warning,
        "Header directives are only valid at the beginning of the document.",
        line_number,
      )
    }
    paragraph.push(raw)
    i = i + 1
  }
  flush_paragraph(paragraph, blocks, diagnostics, line_count)
  { document: { theme, footer, split, letter, palette, blocks, }, diagnostics, }
}
