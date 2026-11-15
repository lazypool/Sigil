///|
fn has_span(
  spans : Array[@highlight.HighlightSpan],
  kind : @highlight.HighlightKind,
  text : String,
) -> Bool {
  for span in spans {
    if span.kind == kind && span.text == text {
      return true
    }
  }
  false
}

///|
test "highlight spans reconstruct the original source" {
  let source =
    #|@theme #2563EB
    #|@footer legal
    #|
    #|---
    #|
    #|- First *item* and <link:https://example.com|Site>
    #|- <icon:mail>
    #|
    #|```
    #|**literal** <sig:classic>
    #|```
    #|
    #|$$
    #|E = mc^2
    #|$$
    #|
    #|:::chart bar
    #|title: Monthly growth
    #|A: 10
    #|:::
    #|
  let spans = @highlight.highlight(source)
  let mut rebuilt = ""
  for span in spans {
    rebuilt = rebuilt + span.text
  }
  assert_eq(rebuilt, source)
}

///|
test "highlight classifies directives, blocks, and inline syntax" {
  let source =
    #|@theme #2563EB
    #|
    #|---
    #|
    #|- First *item* and <link:https://example.com|Site>
    #|- <icon:mail>
    #|
    #|```
    #|**literal** <sig:classic>
    #|```
    #|
    #|$$
    #|E = mc^2
    #|$$
    #|
    #|:::chart bar
    #|title: Monthly growth
    #|A: 10
    #|:::
  let spans = @highlight.highlight(source)
  assert_true(has_span(spans, HeaderKey, "@theme"))
  assert_true(has_span(spans, HeaderValue, "#2563EB"))
  assert_true(has_span(spans, Divider, "---"))
  assert_true(has_span(spans, ListMarker, "- "))
  assert_true(has_span(spans, StrongMarker, "*"))
  assert_true(has_span(spans, StrongText, "item"))
  assert_true(has_span(spans, InsertionPrefix, "<link:"))
  assert_true(has_span(spans, LinkUrl, "https://example.com"))
  assert_true(has_span(spans, InsertionPrefix, "<icon:"))
  assert_true(has_span(spans, InsertionTarget, "mail"))
  assert_true(has_span(spans, Fence, "```"))
  assert_true(has_span(spans, PlainText, "**literal** <sig:classic>"))
  assert_true(has_span(spans, Fence, "$$"))
  assert_true(has_span(spans, FormulaText, "E = mc^2"))
  assert_true(has_span(spans, ChartKey, "title"))
  assert_true(has_span(spans, ChartValue, "Monthly growth"))
  assert_true(has_span(spans, Fence, ":::"))
}

///|
test "highlight marks unknown insertions and directives as invalid" {
  let spans = @highlight.highlight("@unknown value\n\nHello <thing>")
  assert_true(has_span(spans, Invalid, "@unknown"))
  assert_true(has_span(spans, Invalid, "<thing>"))
  assert_false(has_span(spans, HeaderKey, "@unknown"))
}

///|
test "highlight recognizes chart palette directives and chart insertions" {
  let spans = @highlight.highlight("@palette ocean\n\n<chart:sales>")
  assert_true(has_span(spans, HeaderKey, "@palette"))
  assert_true(has_span(spans, HeaderValue, "ocean"))
  assert_true(has_span(spans, InsertionPrefix, "<chart:"))
  assert_true(has_span(spans, InsertionTarget, "sales"))
}
