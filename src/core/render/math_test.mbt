///|
test "formula renders fractions and scripts" {
  let html = @render.render_formula_html("\\frac{a}{b} + x^2 + y_1")
  assert_true(html.contains("border-bottom:1px solid #222833"))
  assert_true(html.contains("<i>a</i>"))
  assert_true(html.contains("<sup style=\"font-size:0.7em;line-height:1;\">2</sup>"))
  assert_true(html.contains("<sub style=\"font-size:0.7em;line-height:1;\">1</sub>"))
}

///|
test "formula renders roots, greek letters, and operators" {
  let html = @render.render_formula_html("\\sqrt[3]{x} \\le \\alpha \\times \\beta")
  assert_true(html.contains("√"))
  assert_true(html.contains("α"))
  assert_true(html.contains("β"))
  assert_true(html.contains("≤"))
  assert_true(html.contains("×"))
}

///|
test "formula escapes source and emits no scripts" {
  let html = @render.render_formula_html("a < b \\text{<script>alert(1)</script>}")
  assert_true(html.contains("&lt;"))
  assert_false(html.contains("<script>"))
  assert_false(html.contains("<script"))
}

///|
test "formula block uses the math renderer" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    blocks: [@types.Block::Formula("\\frac{1}{2}")],
  }
  let html = @render.render_document(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("border-bottom:1px solid #222833"))
  assert_false(html.contains("white-space:pre-wrap"))
}
