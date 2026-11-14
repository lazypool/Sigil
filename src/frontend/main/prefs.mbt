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
}

///|
let accent_palette : ReadOnlyArray[String] = [
  "#007acc", "#0e8a6e", "#8e44ad", "#b7791f", "#c0392b",
]

///|
let editor_font_sizes : Array[Int32] = [12, 13, 14, 15, 16]

///|
fn default_prefs() -> Prefs {
  {
    theme: Dark,
    accent: "#007acc",
    density: Comfortable,
    editor_font_size: 13,
  }
}

///|
fn valid_accent(value : String) -> String {
  for color in accent_palette {
    if color == value {
      return color
    }
  }
  "#007acc"
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
  {
    theme,
    accent: valid_accent(storage_get("sigil.prefs.accent")),
    density,
    editor_font_size,
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
