///|
/// Minimal theme packs.
///
/// Each function returns `Some(html)` only for the pack ids this package owns
/// and `None` for every other id, handing control back to the built-in
/// renderer. Every pack uses a single accent color plus neutral gray, inline
/// styles, no scripts, no flex/grid, no external fonts, and no image
/// backgrounds.
using @types {
  type Profile,
}

///|
fn escape(text : String) -> String {
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
fn profile_name(profile : Profile) -> String {
  let name = if profile.name != "" {
    profile.name
  } else if profile.nickname != "" {
    profile.nickname
  } else {
    "[Name]"
  }
  escape(name)
}

///|
fn profile_title_line(profile : Profile) -> String {
  if profile.title != "" && profile.company != "" {
    escape(profile.title) + " · " + escape(profile.company)
  } else if profile.title != "" {
    escape(profile.title)
  } else if profile.company != "" {
    escape(profile.company)
  } else {
    ""
  }
}

///|
fn email_link(profile : Profile, accent : String) -> String {
  if profile.email != "" {
    "<a href=\"mailto:" +
    escape(profile.email) +
    "\" style=\"color:" +
    accent +
    ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
    escape(profile.email) +
    "</a>"
  } else {
    ""
  }
}

///|
fn phone_html(profile : Profile) -> String {
  if profile.phone != "" {
    "<div style=\"color:#666;\">" + escape(profile.phone) + "</div>"
  } else {
    ""
  }
}

///|
fn website_html(profile : Profile, accent : String) -> String {
  if profile.website != "" {
    if safe_http_url(profile.website) {
      "<div><a href=\"" +
      escape(profile.website) +
      "\" style=\"color:" +
      accent +
      ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
      escape(profile.website) +
      "</a></div>"
    } else {
      "<div style=\"color:#666;\">" + escape(profile.website) + "</div>"
    }
  } else {
    ""
  }
}

///|
fn join_parts(parts : Array[String], sep : String) -> String {
  let non_empty : Array[String] = []
  for part in parts {
    if part != "" {
      non_empty.push(part)
    }
  }
  non_empty.join(sep)
}

///|
fn signature_pack_mono(profile : Profile, accent : String) -> String {
  let title_line = profile_title_line(profile)
  let email = email_link(profile, accent)
  let title_html = if title_line != "" {
    "<div style=\"color:#666;\">" + title_line + "</div>"
  } else {
    ""
  }
  let email_html = if email != "" {
    "<div>" + email + "</div>"
  } else {
    ""
  }
  "<div class=\"sigil-signature\" style=\"margin:20px 0;max-width:100%;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:13px;line-height:1.7;color:#555;overflow-wrap:anywhere;word-break:break-word;\">" +
  "<div style=\"font-weight:700;color:#222833;font-size:14px;\">" +
  profile_name(profile) +
  "</div>" +
  title_html +
  email_html +
  phone_html(profile) +
  website_html(profile, accent) +
  "</div>"
}

///|
fn signature_pack_line(profile : Profile, accent : String) -> String {
  let title_line = profile_title_line(profile)
  let email = email_link(profile, accent)
  let title_html = if title_line != "" {
    " <span style=\"color:#666;\">· " + title_line + "</span>"
  } else {
    ""
  }
  let email_html = if email != "" {
    "<div style=\"margin-top:4px;\">" + email + "</div>"
  } else {
    ""
  }
  "<div class=\"sigil-signature\" style=\"margin:22px 0;max-width:100%;font-size:14px;line-height:1.6;color:#333;overflow-wrap:anywhere;word-break:break-word;\">" +
  "<div style=\"border-top:1px solid " +
  accent +
  ";padding-top:12px;\">" +
  "<span style=\"font-weight:600;color:#222833;\">" +
  profile_name(profile) +
  "</span>" +
  title_html +
  "</div>" +
  email_html +
  "</div>"
}

///|
fn footer_pack_minimal(profile : Profile, accent : String) -> String {
  ignore(profile)
  "<div style=\"margin-top:28px;padding:12px 0 4px;border-top:1px solid #ECEEF2;max-width:100%;text-align:center;font-size:11px;line-height:1.8;letter-spacing:0.5px;color:#8a8a8a;overflow-wrap:anywhere;word-break:break-word;\">" +
  "<span style=\"color:" +
  accent +
  ";\">&#8212;</span>" +
  "</div>"
}

///|
fn footer_pack_contact(profile : Profile, accent : String) -> String {
  let parts : Array[String] = []
  if profile.company != "" {
    parts.push(escape(profile.company))
  }
  let email = email_link(profile, accent)
  if email != "" {
    parts.push(email)
  }
  if profile.phone != "" {
    parts.push(escape(profile.phone))
  }
  if profile.website != "" {
    if safe_http_url(profile.website) {
      parts.push(
        "<a href=\"" +
        escape(profile.website) +
        "\" style=\"color:" +
        accent +
        ";text-decoration:none;overflow-wrap:anywhere;word-break:break-word;\">" +
        escape(profile.website) +
        "</a>",
      )
    } else {
      parts.push(escape(profile.website))
    }
  }
  let content = join_parts(parts, " &#183; ")
  "<div style=\"margin-top:28px;padding:14px 0 4px;border-top:1px solid #ECEEF2;max-width:100%;text-align:center;font-size:12px;line-height:1.8;color:#8a8a8a;overflow-wrap:anywhere;word-break:break-word;\">" +
  content +
  "</div>"
}

///|
fn divider_pack_dots(accent : String) -> String {
  "<div style=\"margin:26px 0;text-align:center;font-size:16px;line-height:1;letter-spacing:10px;\"><span style=\"color:#CBD5E1;\">&#183;&#183;&#183;</span> <span style=\"color:" +
  accent +
  ";\">&#183;</span> <span style=\"color:#CBD5E1;\">&#183;&#183;&#183;</span></div>"
}

///|
fn divider_pack_minimal(accent : String) -> String {
  "<div style=\"margin:26px 0;text-align:center;\"><span style=\"display:inline-block;width:48px;border-top:1px solid " +
  accent +
  ";opacity:0.5;\"></span></div>"
}

///|
fn letter_pack_shell(
  body : String,
  accent : String,
  column_style : String,
  outer_bg : String,
) -> String {
  ignore(accent)
  "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Sigil Preview</title></head>" +
  "<body style=\"margin:0;padding:0;background:" +
  outer_bg +
  ";color:#222833;font-family:-apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei','Segoe UI',Helvetica,Arial,sans-serif;\">" +
  "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"width:100%;table-layout:fixed;background:" +
  outer_bg +
  ";\"><tr>" +
  "<td align=\"center\" style=\"padding:28px 12px;\">" +
  "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"" +
  column_style +
  "\"><tr>" +
  "<td style=\"padding:32px 36px;font-size:16px;line-height:1.7;color:#222833;box-sizing:border-box;overflow-wrap:break-word;word-break:break-word;\">" +
  body +
  "</td></tr></table>" +
  "</td></tr></table>" +
  "</body></html>"
}

///|
pub fn render_signature_pack(
  id : String,
  profile : Profile,
  accent : String,
) -> String? {
  match id {
    "mono" => Some(signature_pack_mono(profile, accent))
    "line" => Some(signature_pack_line(profile, accent))
    _ => None
  }
}

///|
pub fn render_footer_pack(
  id : String,
  profile : Profile,
  accent : String,
) -> String? {
  match id {
    "minimal" => Some(footer_pack_minimal(profile, accent))
    "contact" => Some(footer_pack_contact(profile, accent))
    _ => None
  }
}

///|
pub fn render_divider_pack(id : String, accent : String) -> String? {
  match id {
    "dots" => Some(divider_pack_dots(accent))
    "minimal" => Some(divider_pack_minimal(accent))
    _ => None
  }
}

///|
pub fn render_letter_pack(
  id : String,
  body : String,
  accent : String,
) -> String? {
  match id {
    "plain" =>
      Some(
        letter_pack_shell(
          body,
          accent,
          "width:100%;max-width:640px;margin:0 auto;background:#FFFFFF;table-layout:fixed;box-sizing:border-box;",
          "#FFFFFF",
        ),
      )
    "border" =>
      Some(
        letter_pack_shell(
          body,
          accent,
          "width:100%;max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;table-layout:fixed;box-sizing:border-box;",
          "#F4F4F4",
        ),
      )
    _ => None
  }
}
