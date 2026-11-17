///|
/// Built-in inline icon whitelist. `<icon:name>` may only reference one of
/// these ids; any other name is a parser error. Icons are grouped by purpose;
/// all are stroke-style glyphs colored with the document accent.
pub let icon_names : Array[String] = [
  // Contact & identity
  "mail",
  "phone",
  "location",
  "user",
  "clock",
  "globe",
  // Links & navigation
  "link",
  "external-link",
  "arrow-right",
  // Files & data
  "file",
  "download",
  "folder",
  "copy",
  "trash",
  // Calendar
  "calendar",
  // Email actions
  "send",
  "reply",
  "forward",
  "attach",
  "share",
  // Social
  "github",
  "linkedin",
  "twitter",
  "instagram",
  "facebook",
  "youtube",
  // Status & feedback
  "check",
  "info",
  "alert",
  "star",
  "heart",
  "bell",
  "bookmark",
  "flag",
  "tag",
  // Security
  "lock",
  "unlock",
  "key",
  // Media
  "camera",
  "image",
  "video",
  "music",
  "mic",
  // General
  "home",
  "map",
  "search",
  "edit",
  "refresh",
  "settings",
  "gift",
  "credit-card",
]

///|
pub fn icon_valid(name : String) -> Bool {
  for icon in icon_names {
    if icon == name {
      return true
    }
  }
  false
}
