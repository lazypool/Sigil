///|
test "theme packs return Some for owned ids and None for built-ins" {
  let profile = @types.Profile::{
    name: "Ada Lovelace",
    nickname: "",
    email: "ada@example.com",
    phone: "+1 555 0100",
    title: "Mathematician",
    company: "Analytical Engines",
    website: "https://example.com",
    education: "",
    avatar: "",
  }
  let accent = "#2563EB"
  for id in ["mono", "line"] {
    assert_true(@themes.render_signature_pack(id, profile, accent) is Some(_))
  }
  for id in ["classic", "minimal", "academic", "compact"] {
    assert_true(@themes.render_signature_pack(id, profile, accent) is None)
  }
  for id in ["minimal", "contact"] {
    assert_true(@themes.render_footer_pack(id, profile, accent) is Some(_))
  }
  for id in ["legal", "unsubscribe", "blank"] {
    assert_true(@themes.render_footer_pack(id, profile, accent) is None)
  }
  for id in ["dots", "minimal"] {
    assert_true(@themes.render_divider_pack(id, accent) is Some(_))
  }
  for id in ["line", "dotted", "wave", "space", "ornament"] {
    assert_true(@themes.render_divider_pack(id, accent) is None)
  }
  for id in ["plain", "border"] {
    assert_true(@themes.render_letter_pack(id, "<p>body</p>", accent) is Some(_))
  }
  for id in ["minimal", "card"] {
    assert_true(@themes.render_letter_pack(id, "<p>body</p>", accent) is None)
  }
}

///|
test "theme pack output is single-accent, inline and script-free" {
  let profile = @types.Profile::{
    name: "Ada",
    nickname: "",
    email: "ada@example.com",
    phone: "+1 555 0100",
    title: "Engineer",
    company: "Analytical Engines",
    website: "https://example.com",
    education: "",
    avatar: "",
  }
  let accent = "#2563EB"
  let body = "<p style=\"color:#2563EB;\">body</p>"
  let outputs : Array[String] = []
  outputs.push(@themes.render_signature_pack("mono", profile, accent).unwrap())
  outputs.push(@themes.render_signature_pack("line", profile, accent).unwrap())
  outputs.push(@themes.render_footer_pack("minimal", profile, accent).unwrap())
  outputs.push(@themes.render_footer_pack("contact", profile, accent).unwrap())
  outputs.push(@themes.render_divider_pack("dots", accent).unwrap())
  outputs.push(@themes.render_divider_pack("minimal", accent).unwrap())
  outputs.push(@themes.render_letter_pack("plain", body, accent).unwrap())
  outputs.push(@themes.render_letter_pack("border", body, accent).unwrap())
  for html in outputs {
    assert_true(html.contains(accent))
    assert_false(html.contains("background-image"))
    assert_false(html.contains("<script"))
    assert_false(html.contains("font-face"))
    assert_false(html.contains("flex"))
    assert_false(html.contains("grid"))
  }
}

///|
test "theme whitelists validate ids from the single source of truth" {
  for id in @types.signature_theme_ids {
    assert_true(@types.signature_theme_valid(id))
  }
  for id in @types.footer_theme_ids {
    assert_true(@types.footer_theme_valid(id))
  }
  for id in @types.divider_theme_ids {
    assert_true(@types.divider_theme_valid(id))
  }
  for id in @types.letter_theme_ids {
    assert_true(@types.letter_theme_valid(id))
  }
  assert_false(@types.signature_theme_valid(""))
  assert_false(@types.footer_theme_valid(""))
  assert_false(@types.divider_theme_valid(""))
  assert_false(@types.letter_theme_valid(""))
}
