///|
/// Application appearance, separate from the email theme color in the document.
#derive(Eq)
enum AppTheme {
  Dark
  Light
}

///|
#derive(Eq)
enum Density {
  Comfortable
  Compact
}

///|
#derive(Eq)
struct Prefs {
  theme : AppTheme
  accent : String
  density : Density
  editor_font_size : Int32
  vim : Bool
}

///|
let accent_palette : ReadOnlyArray[String] = [
  "#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ef4444",
]

///|
let editor_font_sizes : Array[Int32] = [12, 13, 14, 15, 16]

///|
fn default_prefs() -> Prefs {
  {
    theme: Dark,
    accent: "#3b82f6",
    density: Comfortable,
    editor_font_size: 13,
    vim: false,
  }
}

///|
fn valid_accent(value : String) -> String {
  for color in accent_palette {
    if color == value {
      return color
    }
  }
  "#3b82f6"
}

///|
fn load_prefs() -> Prefs {
  let theme = match storage_get("sigil.prefs.theme") {
    "light" => Light
    _ => Dark
  }
  let density = match storage_get("sigil.prefs.density") {
    "compact" => Compact
    _ => Comfortable
  }
  let editor_font_size = match storage_get("sigil.prefs.editor_font_size") {
    "12" => 12
    "14" => 14
    "15" => 15
    "16" => 16
    _ => 13
  }
  let vim = match storage_get("sigil.prefs.vim") {
    "on" => true
    _ => false
  }
  {
    theme,
    accent: valid_accent(storage_get("sigil.prefs.accent")),
    density,
    editor_font_size,
    vim,
  }
}

///|
fn save_prefs(prefs : Prefs) -> Unit {
  storage_set(
    "sigil.prefs.theme",
    match prefs.theme {
      Dark => "dark"
      Light => "light"
    },
  )
  storage_set("sigil.prefs.accent", prefs.accent)
  storage_set(
    "sigil.prefs.density",
    match prefs.density {
      Comfortable => "comfortable"
      Compact => "compact"
    },
  )
  storage_set(
    "sigil.prefs.editor_font_size",
    prefs.editor_font_size.to_string(),
  )
  storage_set(
    "sigil.prefs.vim",
    if prefs.vim { "on" } else { "off" },
  )
}

///|
fn prefs_theme_class(prefs : Prefs) -> String {
  match prefs.theme {
    Dark => "theme-dark"
    Light => "theme-light"
  }
}

///|
fn prefs_density_class(prefs : Prefs) -> String {
  match prefs.density {
    Comfortable => "density-comfortable"
    Compact => "density-compact"
  }
}
