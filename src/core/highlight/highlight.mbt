///|
/// A syntax category used by the editor's highlighting layer.
#derive(Eq)
pub(all) enum HighlightKind {
  Plain
  HeaderKey
  HeaderValue
  Divider
  ListMarker
  StrongMarker
  StrongText
  BigMarker
  BigText
  InsertionPrefix
  InsertionTarget
  LinkUrl
  Escape
  Fence
  FormulaText
  ChartKey
  ChartValue
  PlainText
  Invalid
}

///|
/// One contiguous piece of source text with a syntax category.
#derive(Eq)
pub(all) struct HighlightSpan {
  text : String
  kind : HighlightKind
}

///|
priv enum BlockState {
  Normal
  PlainTextBlock
  FormulaBlock
  ChartBlock
}

///|
fn push_span(
  spans : Array[HighlightSpan],
  kind : HighlightKind,
  text : String,
) -> Unit {
  if text == "" {
    return
  }
  spans.push({ text, kind, })
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
fn trim_bounds(
  chars : Array[Char],
  start : Int32,
  end : Int32,
) -> (Int32, Int32) {
  let mut first = start
  while first < end && chars[first].is_whitespace() {
    first = first + 1
  }
  let mut last = end
  while last > first && chars[last - 1].is_whitespace() {
    last = last - 1
  }
  (first, last)
}

///|
fn push_trimmed(
  spans : Array[HighlightSpan],
  chars : Array[Char],
  start : Int32,
  end : Int32,
  kind : HighlightKind,
) -> Unit {
  let (first, last) = trim_bounds(chars, start, end)
  push_span(spans, Plain, chars_text(chars, start, first))
  push_span(spans, kind, chars_text(chars, first, last))
  push_span(spans, Plain, chars_text(chars, last, end))
}

///|
fn list_marker_end(chars : Array[Char], start : Int32, end : Int32) -> Int32? {
  if start < end &&
    chars[start] == '-' &&
    start + 1 < end &&
    chars[start + 1] == ' ' {
    return Some(start + 2)
  }
  let mut i = start
  while i < end && chars[i].is_ascii_digit() {
    i = i + 1
  }
  if i > start && i + 1 < end && chars[i] == '.' && chars[i + 1] == ' ' {
    return Some(i + 2)
  }
  None
}

///|
fn known_header_key(key : String) -> Bool {
  key == "@theme" ||
  key == "@footer" ||
  key == "@split" ||
  key == "@letter" ||
  key == "@palette"
}

///|
fn highlight_directive(
  chars : Array[Char],
  start : Int32,
  end : Int32,
  spans : Array[HighlightSpan],
) -> Unit {
  let (first, last) = trim_bounds(chars, start, end)
  push_span(spans, Plain, chars_text(chars, start, first))
  let mut key_end = first
  while key_end < last && !chars[key_end].is_whitespace() {
    key_end = key_end + 1
  }
  let key = chars_text(chars, first, key_end)
  push_span(spans, if known_header_key(key) { HeaderKey } else { Invalid }, key)
  if key_end < last {
    let mut value_start = key_end
    while value_start < last && chars[value_start].is_whitespace() {
      value_start = value_start + 1
    }
    push_span(spans, Plain, chars_text(chars, key_end, value_start))
    push_span(spans, HeaderValue, chars_text(chars, value_start, last))
  }
  push_span(spans, Plain, chars_text(chars, last, end))
}

///|
fn highlight_chart_line(
  chars : Array[Char],
  start : Int32,
  end : Int32,
  spans : Array[HighlightSpan],
) -> Unit {
  let (first, last) = trim_bounds(chars, start, end)
  push_span(spans, Plain, chars_text(chars, start, first))
  let mut colon : Int32 = -1
  let mut scan = first
  while scan < last {
    if chars[scan] == ':' {
      colon = scan
      break
    }
    scan = scan + 1
  }
  if colon >= 0 {
    push_span(spans, ChartKey, chars_text(chars, first, colon))
    push_span(spans, Plain, chars_text(chars, colon, colon + 1))
    let mut value_start = colon + 1
    while value_start < last && chars[value_start].is_whitespace() {
      value_start = value_start + 1
    }
    push_span(spans, Plain, chars_text(chars, colon + 1, value_start))
    push_span(spans, ChartValue, chars_text(chars, value_start, last))
  } else {
    push_span(spans, Plain, chars_text(chars, first, last))
  }
  push_span(spans, Plain, chars_text(chars, last, end))
}

///|
fn highlight_inline(
  chars : Array[Char],
  start : Int32,
  end : Int32,
  allow_emphasis : Bool,
  spans : Array[HighlightSpan],
) -> Unit {
  let builder = StringBuilder()
  let mut has_text = false
  let mut i = start

  fn flush_text() -> Unit {
    if has_text {
      push_span(spans, Plain, builder.to_string())
      ignore(builder.reset())
      has_text = false
    }
  }

  while i < end {
    let ch = chars[i]
    if ch == '\\' && i + 1 < end {
      let next = chars[i + 1]
      if next == '*' || next == '\\' || next == '<' || next == '>' {
        flush_text()
        push_span(spans, Escape, chars_text(chars, i, i + 2))
        i = i + 2
        continue
      }
    }
    if allow_emphasis && ch == '*' {
      let double = i + 1 < end && chars[i + 1] == '*'
      let delimiter_length : Int32 = if double { 2 } else { 1 }
      let after = i + delimiter_length
      let opening_valid = after < end &&
        !chars[after].is_whitespace() &&
        (i == start || !is_latin_or_digit(chars[i - 1]))
      if opening_valid {
        let mut closing : Int32 = -1
        let mut scan = after
        while scan < end {
          if double {
            if scan + 1 < end &&
              chars[scan] == '*' &&
              chars[scan + 1] == '*' &&
              scan > after &&
              !chars[scan - 1].is_whitespace() {
              closing = scan
              break
            }
          } else if chars[scan] == '*' &&
            scan > after &&
            !chars[scan - 1].is_whitespace() &&
            (scan + 1 >= end || chars[scan + 1] != '*') {
            closing = scan
            break
          }
          scan = scan + 1
        }
        if closing >= 0 {
          flush_text()
          let marker_kind = if double { BigMarker } else { StrongMarker }
          let text_kind = if double { BigText } else { StrongText }
          push_span(spans, marker_kind, chars_text(chars, i, after))
          push_span(spans, text_kind, chars_text(chars, after, closing))
          push_span(
            spans,
            marker_kind,
            chars_text(chars, closing, closing + delimiter_length),
          )
          i = closing + delimiter_length
          continue
        }
      }
    }
    if ch == '<' {
      let mut closing : Int32 = -1
      let mut scan = i + 1
      while scan < end {
        if chars[scan] == '>' {
          closing = scan
          break
        }
        scan = scan + 1
      }
      if closing >= 0 {
        let tag = chars_text(chars, i + 1, closing)
        let mut prefix_length : Int32 = -1
        if tag.has_prefix("link:") {
          prefix_length = 5
        } else if tag.has_prefix("icon:") {
          prefix_length = 5
        } else if tag.has_prefix("image:") {
          prefix_length = 6
        } else if tag.has_prefix("table:") {
          prefix_length = 6
        } else if tag.has_prefix("chart:") {
          prefix_length = 6
        } else if tag.has_prefix("sig:") {
          prefix_length = 4
        }
        flush_text()
        if prefix_length < 0 {
          push_span(spans, Invalid, chars_text(chars, i, closing + 1))
        } else {
          let target_start = i + 1 + prefix_length
          push_span(spans, InsertionPrefix, chars_text(chars, i, target_start))
          if tag.has_prefix("link:") {
            let mut pipe : Int32 = -1
            let mut url_scan = target_start
            while url_scan < closing {
              if chars[url_scan] == '|' {
                pipe = url_scan
                break
              }
              url_scan = url_scan + 1
            }
            let url_end = if pipe >= 0 { pipe } else { closing }
            push_span(spans, LinkUrl, chars_text(chars, target_start, url_end))
            if pipe >= 0 {
              push_span(spans, Plain, "|")
              highlight_inline(chars, pipe + 1, closing, true, spans)
            }
          } else {
            push_span(
              spans,
              InsertionTarget,
              chars_text(chars, target_start, closing),
            )
          }
          push_span(spans, InsertionPrefix, ">")
        }
        i = closing + 1
        continue
      }
    }
    builder.write_char(ch)
    has_text = true
    i = i + 1
  }
  flush_text()
}

///|
/// Split source into contiguous spans covering every character, classifying
/// header directives, block fences, emphasis, insertions, and list markers.
pub fn highlight(source : String) -> Array[HighlightSpan] {
  let spans : Array[HighlightSpan] = []
  let chars = source.to_array()
  let length = chars.length()
  let mut block : BlockState = Normal
  let mut header_open = true
  let mut i : Int32 = 0
  while i < length {
    let start = i
    while i < length && chars[i] != '\n' {
      i = i + 1
    }
    let end = i
    let (first, last) = trim_bounds(chars, start, end)
    let line = chars_text(chars, first, last)
    if block is PlainTextBlock {
      if line == "```" {
        push_trimmed(spans, chars, start, end, Fence)
        block = Normal
      } else {
        push_span(spans, PlainText, chars_text(chars, start, end))
      }
    } else if block is FormulaBlock {
      if line == "$$" {
        push_trimmed(spans, chars, start, end, Fence)
        block = Normal
      } else {
        push_span(spans, FormulaText, chars_text(chars, start, end))
      }
    } else if block is ChartBlock {
      if line == ":::" {
        push_trimmed(spans, chars, start, end, Fence)
        block = Normal
      } else {
        highlight_chart_line(chars, start, end, spans)
      }
    } else if line == "" {
      header_open = false
      push_span(spans, Plain, chars_text(chars, start, end))
    } else if header_open && chars[first] == '@' {
      highlight_directive(chars, start, end, spans)
    } else {
      header_open = false
      if line == "---" {
        push_trimmed(spans, chars, start, end, Divider)
      } else if line == "```" {
        push_trimmed(spans, chars, start, end, Fence)
        block = PlainTextBlock
      } else if line == "$$" {
        push_trimmed(spans, chars, start, end, Fence)
        block = FormulaBlock
      } else if line.has_prefix(":::chart ") {
        push_span(spans, Plain, chars_text(chars, start, first))
        push_span(spans, Fence, chars_text(chars, first, first + 8))
        push_span(spans, Plain, chars_text(chars, first + 8, first + 9))
        push_span(spans, ChartValue, chars_text(chars, first + 9, last))
        push_span(spans, Plain, chars_text(chars, last, end))
        block = ChartBlock
      } else {
        match list_marker_end(chars, first, last) {
          Some(marker_end) => {
            push_span(spans, Plain, chars_text(chars, start, first))
            push_span(spans, ListMarker, chars_text(chars, first, marker_end))
            highlight_inline(chars, marker_end, last, true, spans)
            push_span(spans, Plain, chars_text(chars, last, end))
          }
          None => highlight_inline(chars, start, end, true, spans)
        }
      }
    }
    if i < length {
      push_span(spans, Plain, "\n")
      i = i + 1
    }
  }
  spans
}
