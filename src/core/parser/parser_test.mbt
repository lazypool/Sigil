///|
test "template headers, divider, and signature parse" {
  let source =
    #|@theme #2563EB
    #|@footer legal
    #|@split wave
    #|@letter card
    #|@palette ocean
    #|
    #|---
    #|
    #|<sig:classic>
  let result = @parser.parse(source)
  assert_eq(result.document.theme, Some("#2563EB"))
  assert_eq(result.document.footer, Some("legal"))
  assert_eq(result.document.split, Some("wave"))
  assert_eq(result.document.letter, Some("card"))
  assert_eq(result.document.palette, Some("ocean"))
  assert_eq(result.document.blocks.length(), 2)
  assert_true(result.document.blocks[0] is Divider)
  assert_true(result.document.blocks[1] is Signature("classic"))
  assert_eq(result.diagnostics.length(), 0)
}


///|
test "chart library references parse and invalid palettes are rejected" {
  let result = @parser.parse("@palette sunset\n\n<chart:sales>\n")
  assert_eq(result.document.palette, Some("sunset"))
  assert_eq(result.document.blocks.length(), 1)
  assert_true(result.document.blocks[0] is ChartRef("sales"))
  let invalid = @parser.parse("@palette neon\n\nHello\n")
  assert_eq(invalid.document.palette, None)
  assert_eq(invalid.diagnostics.length(), 1)
  assert_true(invalid.diagnostics[0].severity is Error)
}

///|
test "plain text block keeps raw lines and is not parsed as markup" {
  let result = @parser.parse(
    "```\n**Hello** <sig:classic>\nSecond line\n```\n",
  )
  assert_eq(result.document.blocks.length(), 1)
  match result.document.blocks[0] {
    PlainText(text) =>
      assert_eq(text, "**Hello** <sig:classic>\nSecond line")
    _ => fail("expected plain text block")
  }
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "unclosed plain text block is an error" {
  let result = @parser.parse("```\ntranslation\n")
  assert_eq(result.diagnostics.length(), 1)
  assert_true(result.diagnostics[0].severity is Error)
}

///|
test "paragraph lines join CJK and Latin correctly" {
  let result = @parser.parse("使用\nPython 开发\n年发布")
  assert_eq(result.document.blocks.length(), 1)
  match result.document.blocks[0] {
    Paragraph(inlines) => {
      assert_eq(inlines.length(), 1)
      match inlines[0] {
        Text(text) => assert_eq(text, "使用 Python 开发年发布")
        _ => fail("expected text")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "emphasis, links, and lists parse" {
  let result = @parser.parse(
    "This is *strong* and **big** and <link:https://example.com|Site>.\n\n- First item\n- Second item",
  )
  assert_eq(result.document.blocks.length(), 2)
  match result.document.blocks[0] {
    Paragraph(inlines) => {
      let mut has_strong = false
      let mut has_big = false
      let mut has_link = false
      for inline in inlines {
        if inline is Strong(_) {
          has_strong = true
        }
        if inline is Big(_) {
          has_big = true
        }
        if inline is Link(href, _) {
          has_link = true
          assert_eq(href, "https://example.com")
        }
      }
      assert_true(has_strong)
      assert_true(has_big)
      assert_true(has_link)
    }
    _ => fail("expected paragraph")
  }
  match result.document.blocks[1] {
    ListBlock(kind, items) => {
      assert_true(kind is @types.ListKind::Unordered)
      assert_eq(items.length(), 2)
    }
    _ => fail("expected list")
  }
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "list items keep block insertions as literal text" {
  let result = @parser.parse(
    "- <sig:classic> signature\n- <image:name> image",
  )
  assert_eq(result.diagnostics.length(), 0)
  match result.document.blocks[0] {
    ListBlock(_, items) => assert_eq(items.length(), 2)
    _ => fail("expected list")
  }
}

///|
test "unsafe links produce an error diagnostic" {
  let result = @parser.parse("<link:ftp://example.com>")
  assert_eq(result.diagnostics.length(), 1)
  assert_true(result.diagnostics[0].severity is Error)
}

///|
test "unclosed emphasis is a warning and stays literal" {
  let result = @parser.parse("This is *unclosed")
  assert_true(result.diagnostics.length() > 0)
  match result.document.blocks[0] {
    Paragraph(inlines) =>
      match inlines[0] {
        Text(text) => assert_true(text.contains("*unclosed"))
        _ => fail("expected text")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "table insertion parses as a block" {
  let result = @parser.parse("<table:report.csv>")
  assert_eq(result.document.blocks.length(), 1)
  assert_true(result.document.blocks[0] is Table("report.csv"))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "inline table insertion is an error" {
  let result = @parser.parse("See <table:report.csv> above.")
  assert_true(result.diagnostics.length() > 0)
  assert_true(result.diagnostics[0].severity is Error)
}

///|
test "built-in icons parse and unknown icons are rejected" {
  let result = @parser.parse("Reach me at <icon:mail> or <icon:phone>.")
  assert_eq(result.diagnostics.length(), 0)
  match result.document.blocks[0] {
    Paragraph(inlines) => {
      let mut has_mail = false
      let mut has_phone = false
      for inline in inlines {
        if inline is Icon("mail") {
          has_mail = true
        }
        if inline is Icon("phone") {
          has_phone = true
        }
      }
      assert_true(has_mail)
      assert_true(has_phone)
    }
    _ => fail("expected paragraph")
  }
  let unknown = @parser.parse("<icon:rocket>")
  assert_eq(unknown.diagnostics.length(), 1)
  assert_true(unknown.diagnostics[0].severity is Error)
  assert_true(unknown.diagnostics[0].message.contains("Unknown icon"))
}
