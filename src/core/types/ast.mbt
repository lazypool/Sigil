///|
/// A source span in the original markup, using byte offsets.
#derive(Eq)
pub(all) struct SourceSpan {
  start : Int32
  end : Int32
}

///|
/// Inline content. Only normal text, strong, big, links, and icons exist.
#derive(Eq)
pub(all) enum Inline {
  Text(String)
  Strong(Array[Inline])
  Big(Array[Inline])
  Link(String, Array[Inline])
  Icon(String)
}

///|
/// Lists support only one level.
#derive(Eq)
pub(all) enum ListKind {
  Unordered
  Ordered(Int32)
}

///|
/// Block content in a Sigil document.
#derive(Eq)
pub(all) enum Block {
  Paragraph(Array[Inline])
  Divider
  ListBlock(ListKind, Array[Array[Inline]])
  Image(String)
  Signature(String)
  Formula(String)
  Chart(String, String)
  PlainText(String)
}

///|
/// A parsed Sigil document.
#derive(Eq)
pub(all) struct Document {
  theme : String?
  footer : String?
  split : String?
  letter : String?
  blocks : Array[Block]
}

///|
/// Parser and linter diagnostic severity.
#derive(Eq)
pub(all) enum Severity {
  Error
  Warning
}

///|
/// A locatable parser diagnostic. Lines are 1-based.
#derive(Eq)
pub(all) struct Diagnostic {
  severity : Severity
  message : String
  line : Int32
}

///|
/// Parser output: an AST plus diagnostics. Parsing is best-effort so the
/// preview can still render valid parts of an incomplete document.
#derive(Eq)
pub(all) struct ParseResult {
  document : Document
  diagnostics : Array[Diagnostic]
}

///|
pub fn Document::empty() -> Document {
  { theme: None, footer: None, split: None, letter: None, blocks: [], }
}
