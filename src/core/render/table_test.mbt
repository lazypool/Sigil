///|
test "csv parser handles quotes, commas, and newlines" {
  let csv = "name,note\r\n\"Doe, Jane\",\"line one\nline two\"\r\n"
  let (rows, columns) = @render.csv_dimensions(csv)
  assert_eq(rows, 2)
  assert_eq(columns, 2)
}

///|
test "table block renders an email-safe html table" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: None,
    blocks: [@types.Block::Table("stats.csv")],
    lang: None,
  }
  let tables : Map[String, String] = Map([
    ("stats.csv", "Name,Value\n\"<Ada>\",42\n"),
  ])
  let html = @render.render_document_with_tables(
    document,
    @types.Profile::empty(),
    Map([]),
    tables,
  )
  assert_true(html.contains("<table role=\"presentation\" align=\"center\""))
  assert_true(html.contains("margin:0 auto"))
  assert_true(html.contains("width:100%;max-width:100%"))
  assert_true(html.contains("table-layout:fixed"))
  assert_true(html.contains("<th style=\"border:1px solid #E2E5EA"))
  assert_true(html.contains("background:#DEE8FC"))
  assert_true(html.contains("&lt;Ada&gt;"))
  assert_false(html.contains("<script"))
}

///|
test "missing table asset renders a readable placeholder" {
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: None,
    blocks: [@types.Block::Table("missing.csv")],
    lang: None,
  }
  let html = @render.render_document(document, @types.Profile::empty(), Map([]))
  assert_true(html.contains("[table:missing.csv]"))
}

///|
test "csv preview limits rows and columns" {
  let preview = @render.csv_preview("a,b,c,d\n1,2,3,4\n5,6,7,8", 2, 3)
  assert_eq(preview.length(), 2)
  assert_eq(preview[0].length(), 3)
  assert_eq(preview[1][2], "3")
}

///|
test "csv can be edited and extended" {
  let edited = @render.csv_set_cell("a,b\r\n1,2", 1, 1, "x,y")
  assert_true(edited.contains("\"x,y\""))
  let appended_row = @render.csv_append_row(edited)
  assert_eq(@render.csv_dimensions(appended_row), (3, 2))
  let appended_column = @render.csv_append_column(appended_row, "Note")
  assert_eq(@render.csv_dimensions(appended_column), (3, 3))
  assert_true(appended_column.contains("Note"))
}

///|
test "csv limits columns and cell length" {
  let limited = @render.csv_limit_table(
    "a,b,c,d,e,f\r\n1,2,3,4,5,very long value",
    5,
    4,
  )
  assert_eq(limited, "a,b,c,d,e\r\n1,2,3,4,5")
  assert_eq(@render.csv_dimensions(limited), (2, 5))
}
