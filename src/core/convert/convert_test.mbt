///|
test "json object array becomes csv" {
  let csv = @convert.json_to_csv(
    "[{\"name\":\"Ada\",\"age\":36},{\"name\":\"Bob\",\"age\":42}]",
  )
  let (rows, columns) = @render.csv_dimensions(csv)
  assert_eq(rows, 3)
  assert_eq(columns, 2)
  assert_true(csv.contains("Ada"))
  assert_true(csv.contains("Bob"))
  assert_true(csv.contains("age"))
}

///|
test "json two-dimensional array becomes csv" {
  let csv = @convert.json_to_csv("[[\"a\",\"b\"],[\"1\",\"2\"]]")
  let (rows, columns) = @render.csv_dimensions(csv)
  assert_eq(rows, 2)
  assert_eq(columns, 2)
  assert_true(csv.contains("a"))
}

///|
test "json single object becomes key value csv" {
  let csv = @convert.json_to_csv("{\"x\":1,\"y\":2}")
  let (rows, columns) = @render.csv_dimensions(csv)
  assert_eq(rows, 3)
  assert_eq(columns, 2)
  assert_true(csv.contains("key"))
  assert_true(csv.contains("value"))
}

///|
test "limit table clamps to five columns" {
  let csv = @convert.limit_table("a,b,c,d,e,f\n1,2,3,4,5,6")
  let (_, columns) = @render.csv_dimensions(csv)
  assert_eq(columns, 5)
}

///|
test "limit table truncates cells to 60 characters" {
  let long = "1234567890123456789012345678901234567890123456789012345678901"
  let csv = @convert.limit_table("a,b\n" + long + ",x")
  let (_, _) = @render.csv_dimensions(csv)
  assert_true(csv.contains("123456789012345678901234567890123456789012345678901234567890"))
  assert_false(csv.contains(long))
}

///|
test "csv to chart body has title labels and series" {
  let body = @convert.csv_to_chart_body("Month,Sales\nJan,10\nFeb,20\nMar,15", "bar")
  assert_true(body.contains("title:"))
  assert_true(body.contains("labels:"))
  assert_true(body.contains("series:"))
  assert_true(body.contains("Sales"))
}

///|
test "valid chart kind accepts the nine kinds only" {
  for kind in ["bar", "stacked", "line", "area", "pie", "donut", "scatter", "radar", "heatmap"] {
    assert_true(@convert.valid_chart_kind(kind))
  }
  assert_false(@convert.valid_chart_kind("bogus"))
  assert_false(@convert.valid_chart_kind("column"))
  assert_false(@convert.valid_chart_kind(""))
}

///|
test "invalid chart kind falls back to bar" {
  let fallback = fn(kind : String) -> String {
    if @convert.valid_chart_kind(kind) {
      kind
    } else {
      "bar"
    }
  }
  assert_eq(fallback("bogus"), "bar")
  assert_eq(fallback("column"), "bar")
  assert_eq(fallback("line"), "line")
  assert_eq(fallback("heatmap"), "heatmap")
}

///|
test "csv to csv drops blank lines and unifies delimiter" {
  let csv = @convert.csv_to_csv("a;b\n\n1;2\n")
  assert_true(csv.contains("a,b"))
  assert_true(csv.contains("1,2"))
  assert_false(csv.contains("\n\n"))
}

///|
test "json or csv sniffs the format" {
  let from_json = @convert.json_or_csv_to_csv("[{\"a\":1}]")
  assert_true(from_json.contains("a"))
  let from_csv = @convert.json_or_csv_to_csv("a,b\n1,2")
  assert_true(from_csv.contains("a,b"))
}
