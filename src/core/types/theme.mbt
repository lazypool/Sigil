///|
/// Single source of truth for email theme id whitelists.
///
/// Every rendering module and the frontend style panel must read from these
/// constants instead of hardcoding ids. New minimal theme packs append their
/// ids here and are rendered by `xiao/sigil/core/themes`.
pub let signature_theme_ids : Array[String] = [
  "classic",
  "minimal",
  "academic",
  "compact",
  "mono",
  "line",
]

///|
pub let footer_theme_ids : Array[String] = [
  "legal",
  "unsubscribe",
  "blank",
  "minimal",
  "contact",
]

///|
pub let divider_theme_ids : Array[String] = [
  "line",
  "dotted",
  "wave",
  "space",
  "ornament",
  "dots",
  "minimal",
]

///|
pub let letter_theme_ids : Array[String] = [
  "minimal",
  "card",
  "plain",
  "border",
]

///|
pub fn signature_theme_valid(id : String) -> Bool {
  for theme in signature_theme_ids {
    if theme == id {
      return true
    }
  }
  false
}

///|
pub fn footer_theme_valid(id : String) -> Bool {
  for theme in footer_theme_ids {
    if theme == id {
      return true
    }
  }
  false
}

///|
pub fn divider_theme_valid(id : String) -> Bool {
  for theme in divider_theme_ids {
    if theme == id {
      return true
    }
  }
  false
}

///|
pub fn letter_theme_valid(id : String) -> Bool {
  for theme in letter_theme_ids {
    if theme == id {
      return true
    }
  }
  false
}
