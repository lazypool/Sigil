///|
/// One chart stored in a document's chart library.
pub(all) struct ChartSpec {
  kind : String
  text : String
}

///|
/// Available chart palette presets. The first entry is the default.
pub let chart_palette_names : Array[String] = [
  "default",
  "ocean",
  "sunset",
  "forest",
  "berry",
  "earth",
  "mono",
]

///|
pub fn chart_palette_default() -> String {
  "default"
}

///|
pub fn chart_palette_valid(name : String) -> Bool {
  for palette in chart_palette_names {
    if palette == name {
      return true
    }
  }
  false
}
