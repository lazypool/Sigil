///|
test "rendered document escapes text and uses the theme accent" {
  let document = @types.Document::{
    theme: Some("#123456"),
    footer: None,
    split: Some("wave"),
    letter: None,
    palette: None,
    blocks: [
      @types.Block::Paragraph([
        @types.Inline::Text("<hello> & goodbye"),
        @types.Inline::Strong([@types.Inline::Text("bold")]),
      ]),
      @types.Block::Divider,
      @types.Block::Signature("classic"),
    ],
    lang: None,
  }
  let profile = @types.Profile::{
    name: "Ada Lovelace",
    nickname: "",
    email: "ada@example.com",
    phone: "",
    title: "Mathematician",
    company: "Analytical Engines",
    website: "https://example.com",
    education: "",
    avatar: "",
  }
  let html = @render.render_document(document, profile, Map([]))
  assert_true(html.contains("&lt;hello&gt; &amp; goodbye"))
  assert_true(html.contains("<strong style=\"font-weight:600;\">bold</strong>"))
  assert_true(html.contains("#123456"))
  assert_true(html.contains("Ada Lovelace"))
  assert_true(html.contains("mailto:ada@example.com"))
  assert_true(html.contains("class=\"sigil-signature\""))
  assert_true(html.contains("table-layout:fixed"))
  assert_true(html.contains("overflow-wrap:anywhere"))
  assert_true(html.contains("<script") == false)
}

///|
test "plain text block renders escaped gray text" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: None,
    blocks: [@types.Block::PlainText("<hello> & goodbye")],
    lang: None,
  }
  let html = @render.render_document(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("color:#8a8a8a"))
  assert_true(html.contains("&lt;hello&gt; &amp; goodbye"))
  assert_false(html.contains("<hello>"))
}

///|
test "full email HTML keeps the reading column and has no scripts" {
  let document = @types.Document::empty()
  let html = @render.render_email_html(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("max-width:640px"))
  assert_true(html.contains("@media (max-width: 640px)"))
  assert_true(html.contains("overflow-wrap: break-word"))
  assert_false(html.contains("<script"))
}

///|
test "built-in icon renders as a theme-colored inline svg" {
  let document = @types.Document::{
    theme: Some("#123456"),
    footer: None,
    split: None,
    letter: None,
    palette: None,
    blocks: [@types.Block::Paragraph([@types.Inline::Icon("mail")])],
    lang: None,
  }
  let html = @render.render_document(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("<svg"))
  assert_true(html.contains("viewBox=\"-2 -2 28 28\""))
  assert_true(html.contains("stroke:#123456"))
  assert_true(html.contains("aria-label=\"mail\""))
  assert_true(html.contains("data-sigil-icon"))
  assert_false(html.contains("<script"))
}

///|
test "every whitelisted icon renders as an svg glyph" {
  for name in @types.icon_names {
    let html = @render.render_icon(name, "#2563EB")
    assert_true(html.contains("<svg"))
    assert_true(html.contains("data-sigil-icon"))
  }
  assert_false(@render.render_icon("rocket", "#2563EB").contains("<svg"))
}

///|
test "lists render as table rows with explicit markers" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: None,
    blocks: [
      @types.Block::ListBlock(
        @types.ListKind::Unordered,
        [
          [@types.Inline::Text("first")],
          [@types.Inline::Text("second")],
        ],
      ),
      @types.Block::ListBlock(
        @types.ListKind::Ordered(3),
        [
          [@types.Inline::Text("three")],
          [@types.Inline::Text("four")],
        ],
      ),
    ],
    lang: None,
  }
  let html = @render.render_document(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("&#8226;"))
  assert_true(html.contains("3."))
  assert_true(html.contains("4."))
  assert_false(html.contains("<ul"))
  assert_false(html.contains("<ol"))
  assert_false(html.contains("<li"))
}
