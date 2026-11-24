///|
using @types {
  type Block,
  type Document,
  type Inline,
  type ListKind,
  type Profile,
}

///|
pub fn escape_html(text : String) -> String {
  let builder = StringBuilder()
  for ch in text {
    if ch == '<' {
      builder.write_string("&lt;")
    } else if ch == '>' {
      builder.write_string("&gt;")
    } else if ch == '&' {
      builder.write_string("&amp;")
    } else if ch == '"' {
      builder.write_string("&quot;")
    } else if ch == '\'' {
      builder.write_string("&#39;")
    } else {
      builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn safe_http_url(value : String) -> Bool {
  value.has_prefix("http://") || value.has_prefix("https://")
}

///|
fn theme_color(document : Document) -> String {
  match document.theme {
    Some(color) => color
    None => "#2563EB"
  }
}

///|
fn render_inline(inline : Inline, accent : String) -> String {
  match inline {
    Text(text) => escape_html(text)
    Strong(children) =>
      "<strong style=\"font-weight:600;\">" +
      render_inlines(children, accent) +
      "</strong>"
    Big(children) =>
      "<strong style=\"font-size:22px;font-weight:700;\">" +
      render_inlines(children, accent) +
      "</strong>"
    Link(href, children) => {
      let label = render_inlines(children, accent)
      "<a href=\"" +
      escape_html(href) +
      "\" style=\"color:" +
      accent +
      ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
      label +
      "</a>"
    }
    Icon(name) => render_icon(name, accent)
  }
}

///|
fn render_inlines(inlines : Array[Inline], accent : String) -> String {
  let builder = StringBuilder()
  for inline in inlines {
    builder.write_string(render_inline(inline, accent))
  }
  builder.to_string()
}

///|
fn divider_html(split : String?, accent : String) -> String {
  match split {
    Some(id) =>
      match @themes.render_divider_pack(id, accent) {
        Some(html) => return html
        None => ()
      }
    None => ()
  }
  match split {
    Some("wave") =>
      "<div style=\"margin:26px 0;text-align:center;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:13px;letter-spacing:2px;line-height:1;\">" +
      "<span style=\"color:#CBD5E1;\">-----</span> " +
      "<span style=\"color:" +
      accent +
      ";\">&#9601;&#9602;&#9603;&#9605;&#9607;&#9605;&#9603;&#9602;&#9601;</span> " +
      "<span style=\"color:#CBD5E1;\">-----</span></div>"
    Some("ornament") =>
      "<div style=\"margin:26px 0;text-align:center;color:" +
      accent +
      ";opacity:0.55;font-size:12px;letter-spacing:0.4em;\">...</div>"
    _ =>
      "<div style=\"margin:26px 0;border-top:1px solid " +
      accent +
      ";opacity:0.28;\"></div>"
  }
}

///|
fn render_list(
  kind : ListKind,
  items : Array[Array[Inline]],
  accent : String,
) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"margin:0 0 14px;\">",
  )
  let mut number = match kind {
    ListKind::Ordered(start) => start
    ListKind::Unordered => 0
  }
  for item in items {
    builder.write_string("<tr>")
    match kind {
      ListKind::Unordered =>
        builder.write_string(
          "<td style=\"vertical-align:top;padding:0 8px 6px 0;\">&#8226;</td>",
        )
      ListKind::Ordered(_) =>
        builder.write_string(
          "<td style=\"vertical-align:top;padding:0 8px 6px 0;\">" +
          number.to_string() +
          ".</td>",
        )
    }
    builder.write_string(
      "<td style=\"vertical-align:top;padding:0 0 6px;\">" +
      render_inlines(item, accent) +
      "</td>",
    )
    builder.write_string("</tr>")
    number = number + 1
  }
  builder.write_string("</table>")
  builder.to_string()
}

///|
fn profile_initial(profile : Profile) -> String {
  let name = if profile.name != "" {
    profile.name
  } else if profile.nickname != "" {
    profile.nickname
  } else {
    ""
  }
  match name.get_char(0) {
    Some(ch) => ch.to_string().to_upper()
    None => "S"
  }
}

///|
fn render_signature(
  theme : String,
  profile : Profile,
  accent : String,
) -> String {
  match @themes.render_signature_pack(theme, profile, accent) {
    Some(html) => return html
    None => ()
  }
  ignore(theme)
  let name = if profile.name != "" {
    profile.name
  } else if profile.nickname != "" {
    profile.nickname
  } else {
    "[Name]"
  }
  let title_line = if profile.title != "" && profile.company != "" {
    escape_html(profile.title) + " · " + escape_html(profile.company)
  } else if profile.title != "" {
    escape_html(profile.title)
  } else if profile.company != "" {
    escape_html(profile.company)
  } else {
    ""
  }
  let email = if profile.email != "" {
    "<a href=\"mailto:" +
    escape_html(profile.email) +
    "\" style=\"color:" +
    accent +
    ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
    escape_html(profile.email) +
    "</a>"
  } else {
    "[Email]"
  }
  let phone = if profile.phone != "" {
    "<div style=\"color:#666;\">" + escape_html(profile.phone) + "</div>"
  } else {
    ""
  }
  let website = if profile.website != "" {
    if safe_http_url(profile.website) {
      "<div><a href=\"" +
      escape_html(profile.website) +
      "\" style=\"color:" +
      accent +
      ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
      escape_html(profile.website) +
      "</a></div>"
    } else {
      "<div style=\"color:#666;\">" + escape_html(profile.website) + "</div>"
    }
  } else {
    ""
  }
  let education = if profile.education != "" {
    "<div style=\"color:#666;\">" + escape_html(profile.education) + "</div>"
  } else {
    ""
  }
  let title_html = if title_line != "" {
    "<div style=\"color:#555;margin-top:2px;\">" + title_line + "</div>"
  } else {
    ""
  }
  if theme == "compact" {
    let compact_title = if title_line != "" { " · " + title_line } else { "" }
    "<div class=\"sigil-signature\" style=\"margin:18px 0;max-width:100%;font-size:13px;line-height:1.6;color:#555;overflow-wrap:anywhere;word-break:break-word;\">" +
    "<strong style=\"color:#222833;\">" +
    escape_html(name) +
    "</strong>" +
    compact_title +
    " · " +
    email +
    "</div>"
  } else if theme == "minimal" {
    "<div class=\"sigil-signature\" style=\"margin:24px 0;padding-top:18px;border-top:1px solid #e5e5e5;max-width:100%;font-size:14px;line-height:1.6;color:#333;overflow-wrap:anywhere;word-break:break-word;\">" +
    "<div style=\"font-weight:600;font-size:15px;\">" +
    escape_html(name) +
    "</div>" +
    title_html +
    "<div>" +
    email +
    "</div>" +
    phone +
    website +
    "</div>"
  } else if theme == "academic" {
    "<div class=\"sigil-signature\" style=\"margin:24px 0;padding-top:18px;border-top:1px solid #e5e5e5;max-width:100%;font-size:14px;line-height:1.6;color:#333;overflow-wrap:anywhere;word-break:break-word;\">" +
    "<div style=\"font-weight:600;font-size:15px;\">" +
    escape_html(name) +
    "</div>" +
    title_html +
    education +
    "<div>" +
    email +
    "</div>" +
    phone +
    website +
    "</div>"
  } else {
    let avatar = if profile.avatar != "" {
      "<img src=\"" +
      escape_html(profile.avatar) +
      "\" alt=\"\" width=\"40\" height=\"40\" style=\"display:block;width:40px;height:40px;border-radius:20px;object-fit:cover;border:0;\">"
    } else {
      "<div style=\"width:40px;height:40px;border-radius:20px;background:" +
      accent +
      ";color:#ffffff;text-align:center;line-height:40px;font-weight:700;font-size:16px;\">" +
      escape_html(profile_initial(profile)) +
      "</div>"
    }
    "<div class=\"sigil-signature\" style=\"margin:24px 0;padding-top:18px;border-top:1px solid #e5e5e5;max-width:100%;overflow-wrap:anywhere;word-break:break-word;\">" +
    "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"width:100%;max-width:100%;border-collapse:collapse;table-layout:fixed;\"><tr>" +
    "<td style=\"width:40px;padding-right:14px;vertical-align:top;\">" +
    avatar +
    "</td>" +
    "<td style=\"vertical-align:top;font-size:14px;line-height:1.5;color:#333;overflow-wrap:anywhere;word-break:break-word;\">" +
    "<div style=\"font-weight:600;\">" +
    escape_html(name) +
    "</div>" +
    title_html +
    "<div>" +
    email +
    "</div>" +
    phone +
    website +
    education +
    "</td></tr></table></div>"
  }
}

///|
fn render_footer(
  footer : String?,
  profile : Profile,
  accent : String,
) -> String {
  match footer {
    Some(id) =>
      match @themes.render_footer_pack(id, profile, accent) {
        Some(html) => return html
        None => ()
      }
    None => ()
  }
  match footer {
    Some("legal") => {
      let company = if profile.company != "" {
        escape_html(profile.company)
      } else {
        "Sigil"
      }
      let email = if profile.email != "" {
        "<a href=\"mailto:" +
        escape_html(profile.email) +
        "\" style=\"color:" +
        accent +
        ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
        escape_html(profile.email) +
        "</a>"
      } else {
        ""
      }
      "<div style=\"margin-top:28px;padding:16px 0 4px;border-top:1px solid #ECEEF2;max-width:100%;text-align:center;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:12px;line-height:1.9;letter-spacing:1px;color:" +
      accent +
      ";overflow-wrap:anywhere;word-break:break-word;\">" +
      company +
      " / " +
      email +
      "<br><span style=\"color:#8a8a8a;font-size:11px;letter-spacing:0.5px;\">Sent with Sigil</span></div>"
    }
    Some("unsubscribe") =>
      "<div style=\"margin-top:28px;padding:16px 0 4px;border-top:1px solid #ECEEF2;max-width:100%;text-align:center;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:12px;line-height:1.9;letter-spacing:1px;color:#8a8a8a;overflow-wrap:anywhere;word-break:break-word;\">" +
      "You received this email because you subscribed. " +
      "<a href=\"mailto:" +
      escape_html(profile.email) +
      "?subject=Unsubscribe\" style=\"color:" +
      accent +
      ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">Unsubscribe</a></div>"
    Some("blank") => ""
    _ => ""
  }
}

///|
fn render_image(name : String, assets : Map[String, String]) -> String {
  let source = match assets.get(name) {
    Some(data) => data
    None => name
  }
  "<p style=\"margin:0 0 18px;text-align:center;\">" +
  "<img src=\"" +
  escape_html(source) +
  "\" alt=\"\" style=\"display:block;margin:0 auto;max-width:100%;height:auto;border:0;\">" +
  "</p>"
}

///|
fn chart_palette_name(document : Document) -> String {
  match document.palette {
    Some(value) => value
    None => @types.chart_palette_default()
  }
}

///|
fn render_chart_ref(
  name : String,
  charts : Map[String, @types.ChartSpec],
  palette : String,
) -> String {
  match charts.get(name) {
    Some(spec) => render_chart_html(spec.kind, spec.text, palette)
    None =>
      "<div style=\"margin:20px auto;padding:12px 14px;border:1px solid #e5e5e5;border-radius:4px;background:#fafafa;max-width:100%;box-sizing:border-box;text-align:center;color:#8a8a8a;font-size:13px;overflow-wrap:anywhere;word-break:break-word;\">" +
      "Chart not found: " +
      escape_html(name) +
      "</div>"
  }
}

///|
fn render_block(
  block : Block,
  document : Document,
  profile : Profile,
  assets : Map[String, String],
  tables : Map[String, String],
  charts : Map[String, @types.ChartSpec],
  accent : String,
) -> String {
  match block {
    Paragraph(inlines) =>
      "<p style=\"margin:0 0 14px;\">" +
      render_inlines(inlines, accent) +
      "</p>"
    Divider => divider_html(document.split, accent)
    ListBlock(kind, items) => render_list(kind, items, accent)
    Image(name) => render_image(name, assets)
    Signature(theme) => render_signature(theme, profile, accent)
    Formula(text) => render_formula_html(text)
    Table(name) => render_table(name, tables, accent)
    Chart(kind, text) => render_chart_html(kind, text, chart_palette_name(document))
    ChartRef(name) => render_chart_ref(name, charts, chart_palette_name(document))
    PlainText(text) =>
      "<div style=\"margin:18px 0;max-width:100%;color:#8a8a8a;font-size:14px;line-height:1.7;white-space:pre-wrap;overflow-wrap:anywhere;word-break:break-word;\">" +
      escape_html(text) +
      "</div>"
  }
}

///|
pub fn render_document(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
) -> String {
  render_document_with_tables(document, profile, assets, Map([]))
}

///|
pub fn render_document_with_tables(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
  tables : Map[String, String],
) -> String {
  render_document_with_libraries(document, profile, assets, tables, Map([]))
}

///|
pub fn render_document_with_libraries(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
  tables : Map[String, String],
  charts : Map[String, @types.ChartSpec],
) -> String {
  let accent = theme_color(document)
  let builder = StringBuilder()
  for block in document.blocks {
    builder.write_string(
      render_block(block, document, profile, assets, tables, charts, accent),
    )
  }
  builder.write_string(render_footer(document.footer, profile, accent))
  builder.to_string()
}

///|
pub fn render_email_html(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
) -> String {
  render_email_html_with_tables(document, profile, assets, Map([]))
}

///|
pub fn render_email_html_with_tables(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
  tables : Map[String, String],
) -> String {
  render_email_html_with_libraries(
    document, profile, assets, tables, Map([]),
  )
}

///|
pub fn render_email_html_with_libraries(
  document : Document,
  profile : Profile,
  assets : Map[String, String],
  tables : Map[String, String],
  charts : Map[String, @types.ChartSpec],
) -> String {
  let body = render_document_with_libraries(
    document, profile, assets, tables, charts,
  )
  let accent = theme_color(document)
  let letter = match document.letter {
    Some(letter) => letter
    None => "minimal"
  }
  build_letter_shell(body, accent, letter)
}
