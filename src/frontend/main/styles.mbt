///|
#derive(Eq)
enum StyleKind {
  LetterStyle
  FooterStyle
  SplitStyle
  SignatureStyle
}

///|
fn style_options(kind : StyleKind) -> Array[String] {
  match kind {
    LetterStyle => ["minimal", "card"]
    FooterStyle => ["legal", "unsubscribe", "blank"]
    SplitStyle => ["line", "wave", "ornament"]
    SignatureStyle => ["classic", "minimal", "academic", "compact"]
  }
}

///|
fn style_kind_label(lang : Lang, kind : StyleKind) -> String {
  match kind {
    LetterStyle => tr(lang, "Letter", "信纸")
    FooterStyle => tr(lang, "Footer", "页脚")
    SplitStyle => tr(lang, "Divider", "分隔符")
    SignatureStyle => tr(lang, "Signature", "签名")
  }
}

///|
fn style_label(lang : Lang, kind : StyleKind, id : String) -> String {
  match kind {
    LetterStyle =>
      match id {
        "minimal" => tr(lang, "Minimal", "极简")
        "card" => tr(lang, "Card", "卡片")
        _ => id
      }
    FooterStyle =>
      match id {
        "legal" => tr(lang, "Legal", "法律")
        "unsubscribe" => tr(lang, "Unsubscribe", "退订")
        "blank" => tr(lang, "Blank", "空白")
        _ => id
      }
    SplitStyle =>
      match id {
        "line" => tr(lang, "Line", "实线")
        "dotted" => tr(lang, "Dotted", "点线")
        "wave" => tr(lang, "Wave", "波浪")
        "space" => tr(lang, "Space", "留白")
        "ornament" => tr(lang, "Ornament", "装饰")
        _ => id
      }
    SignatureStyle =>
      match id {
        "classic" => tr(lang, "Classic", "经典")
        "minimal" => tr(lang, "Minimal", "极简")
        "academic" => tr(lang, "Academic", "学术")
        "compact" => tr(lang, "Compact", "紧凑")
        _ => id
      }
  }
}

///|
fn style_default(kind : StyleKind) -> String {
  match kind {
    LetterStyle => "card"
    FooterStyle => "legal"
    SplitStyle => "wave"
    SignatureStyle => "classic"
  }
}

///|
fn split_source_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
fn source_line_trimmed(line : String) -> String {
  line.trim().to_owned()
}

///|
fn header_key(line : String) -> String? {
  let text = source_line_trimmed(line)
  if !text.has_prefix("@") {
    return None
  }
  match text.find(" ") {
    Some(position) => Some(text[:position].to_owned())
    None => Some(text)
  }
}

///|
fn current_header_value(source : String, key : String) -> String? {
  let lines = split_source_lines(source)
  let mut index = 0
  while index < lines.length() {
    let text = source_line_trimmed(lines[index])
    if text == "" {
      break
    }
    if !text.has_prefix("@") {
      break
    }
    match header_key(lines[index]) {
      Some(found) if found == key =>
        match text.find(" ") {
          Some(position) => {
            let value = source_line_trimmed(text[position + 1:].to_owned())
            if value != "" {
              return Some(value)
            }
          }
          None => ()
        }
      _ => ()
    }
    index = index + 1
  }
  None
}

///|
fn set_header_value(source : String, key : String, value : String) -> String {
  let lines = split_source_lines(source)
  let mut header_end = 0
  while header_end < lines.length() &&
        source_line_trimmed(lines[header_end]) != "" &&
        source_line_trimmed(lines[header_end]).has_prefix("@") {
    header_end = header_end + 1
  }
  let result : Array[String] = []
  let mut found = false
  for index = 0; index < header_end; index = index + 1 {
    match header_key(lines[index]) {
      Some(found_key) if found_key == key => {
        result.push(key + " " + value)
        found = true
      }
      _ => result.push(lines[index])
    }
  }
  if !found {
    result.push(key + " " + value)
  }
  let mut body_start = header_end
  while body_start < lines.length() &&
        source_line_trimmed(lines[body_start]) == "" {
    body_start = body_start + 1
  }
  if body_start < lines.length() {
    result.push("")
  }
  for index = body_start; index < lines.length(); index = index + 1 {
    result.push(lines[index])
  }
  result.join("\n")
}

///|
fn current_signature_value(source : String) -> String? {
  for line in split_source_lines(source) {
    let text = source_line_trimmed(line)
    if text.has_prefix("<sig:") && text.has_suffix(">") {
      return Some(text[5:text.length() - 1].to_owned())
    }
  }
  None
}

///|
fn set_signature_value(source : String, value : String) -> String {
  let lines = split_source_lines(source)
  let result : Array[String] = []
  let mut replaced = false
  for line in lines {
    let text = source_line_trimmed(line)
    if !replaced && text.has_prefix("<sig:") && text.has_suffix(">") {
      result.push("<sig:" + value + ">")
      replaced = true
    } else {
      result.push(line)
    }
  }
  if !replaced {
    let base = if source.has_suffix("\n") { source } else { source + "\n" }
    return base + "<sig:" + value + ">\n"
  }
  result.join("\n")
}

///|
fn normalized_style(kind : StyleKind, value : String) -> String {
  for option in style_options(kind) {
    if option == value {
      return value
    }
  }
  style_default(kind)
}

///|
fn current_style(source : String, kind : StyleKind) -> String {
  match kind {
    LetterStyle =>
      match current_header_value(source, "@letter") {
        Some(value) => value
        None => style_default(kind)
      }
    FooterStyle =>
      match current_header_value(source, "@footer") {
        Some(value) => value
        None => style_default(kind)
      }
    SplitStyle =>
      match current_header_value(source, "@split") {
        Some(value) => value
        None => style_default(kind)
      }
    SignatureStyle =>
      match current_signature_value(source) {
        Some(value) => value
        None => style_default(kind)
      }
  }
}

///|
fn apply_style(source : String, kind : StyleKind, value : String) -> String {
  match kind {
    LetterStyle => set_header_value(source, "@letter", value)
    FooterStyle => set_header_value(source, "@footer", value)
    SplitStyle => set_header_value(source, "@split", value)
    SignatureStyle => set_signature_value(source, value)
  }
}

///|
fn style_preview_source(target : EmailDoc) -> String {
  let parsed = @parser.parse(target.source)
  let theme = match parsed.document.theme {
    Some(value) => value
    None => "#2563EB"
  }
  let footer = current_style(target.source, FooterStyle)
  let split = current_style(target.source, SplitStyle)
  let letter = current_style(target.source, LetterStyle)
  let signature = current_style(target.source, SignatureStyle)
  "@theme " +
  theme +
  "\n@footer " +
  footer +
  "\n@split " +
  split +
  "\n@letter " +
  letter +
  "\n\nA quiet reading column makes long emails easier to read, with a single accent color and neutral gray supporting text.\n\n---\n\nThis preview uses your current profile, theme color, and workspace images.\n\n<sig:" +
  signature +
  ">\n"
}

///|
fn style_preview_html(model : Model, target : EmailDoc) -> String {
  let result = @parser.parse(style_preview_source(target))
  @render.render_email_html(
    result.document,
    to_core_profile(model.profile),
    asset_map(model.assets),
  )
}
