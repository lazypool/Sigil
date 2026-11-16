///|
test "formula renders fractions and scripts" {
  let html = @render.render_formula_html("\\frac{a}{b} + x^2 + y_1")
  assert_true(html.contains("border-bottom:1px solid #222833"))
  assert_true(html.contains("<i>a</i>"))
  assert_true(html.contains("<sup style=\"font-size:0.7em;line-height:1;\">2</sup>"))
  assert_true(html.contains("<sub style=\"font-size:0.7em;line-height:1;\">1</sub>"))
}

///|
test "formula block scrolls instead of overflowing narrow screens" {
  let html = @render.render_formula_html("\\frac{a}{b}")
  assert_true(html.contains("overflow-x:auto"))
  assert_true(html.contains("display:table"))
  assert_true(html.contains("white-space:nowrap"))
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
test "formula renders aligned environments as rows and cells" {
  let html = @render.render_formula_html(
    "\\begin{aligned}\na &= b + c \\\\\nc &= a + b \\\\\n\\end{aligned}",
  )
  assert_true(html.contains("display:inline-table"))
  assert_true(html.contains("display:table-row"))
  assert_true(html.contains("display:table-cell"))
  assert_false(html.contains("aligned"))
  assert_false(html.contains("&amp;"))
  assert_true(html.contains("<i>a</i>"))
  assert_true(html.contains("<i>c</i>"))
}

///|
test "formula supports blackboard, bold, italic, script, and fraktur text" {
  let html = @render.render_formula_html(
    "\\mathbb{R} \\mathbf{v} \\mathit{x} \\mathcal{L} \\mathfrak{g}",
  )
  assert_true(html.contains("ℝ"))
  assert_true(html.contains("font-weight:700;\">v<"))
  assert_true(html.contains("font-style:italic;\"><i>x</i>"))
  assert_true(html.contains("ℒ"))
  assert_true(html.contains("𝔤"))
  assert_false(html.contains("mathbb"))
  assert_false(html.contains("mathbf"))
}

///|
test "aligned formulas keep nested commands" {
  let html = @render.render_formula_html(
    "\\begin{aligned}\n\\mathbb{R} &= \\frac{a}{b} \\\\\n\\mathbf{v} &= x\n\\end{aligned}",
  )
  assert_true(html.contains("ℝ"))
  assert_true(html.contains("border-bottom:1px solid #222833"))
  assert_true(html.contains("font-weight:700;\">v<"))
  assert_false(html.contains("begin"))
  assert_false(html.contains("end"))
}

///|
test "formula supports matrices, accents, and font commands without braces" {
  let html = @render.render_formula_html(
    "\\begin{pmatrix} a & b \\\\[6pt] c & d \\end{pmatrix}" +
    "\\begin{matrix} a_1,a_2\\\\ b_1,b_2 \\end{matrix}" +
    "\\left\\|x-\\bar{x}\\right\\|_{\\mathbf{\\Sigma}^{-1}}^2" +
    "\\mathsf T \\vdots \\ddots",
  )
  assert_true(html.contains("display:inline-table"))
  assert_true(html.contains("‖"))
  assert_true(html.contains("⋮"))
  assert_true(html.contains("⋱"))
  assert_true(html.contains("Σ"))
  assert_true(html.contains("text-decoration:overline;"))
  assert_true(html.contains("font-family:'Helvetica Neue'"))
  assert_false(html.contains("begin"))
  assert_false(html.contains("end"))
  assert_false(html.contains("pmatrix"))
  assert_false(html.contains("matrix"))
  assert_false(html.contains("mathbf"))
  assert_false(html.contains("mathsf"))
  assert_false(html.contains("bar"))
  assert_false(html.contains("vdots"))
}

///|
test "formula block uses the math renderer" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: None,
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
