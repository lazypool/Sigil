///|
/// Interface language. Content (documents, profile values, image names) is
/// never translated; only application chrome is.
#derive(Eq)
enum Lang {
  En
  Zh
}

///|
fn load_lang() -> Lang {
  match storage_get("sigil.lang") {
    "zh" | "cn" => Zh
    _ => En
  }
}

///|
fn save_lang(lang : Lang) -> Unit {
  match lang {
    En => storage_set("sigil.lang", "en")
    Zh => storage_set("sigil.lang", "zh")
  }
}

///|
fn other_lang(lang : Lang) -> Lang {
  match lang {
    En => Zh
    Zh => En
  }
}

///|
fn lang_label(lang : Lang) -> String {
  match lang {
    En => "中文"
    Zh => "EN"
  }
}

///|
fn tr(lang : Lang, en : String, zh : String) -> String {
  match lang {
    En => en
    Zh => zh
  }
}
