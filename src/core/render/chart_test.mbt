///|
test "bar chart renders key-value data" {
  let html = @render.render_chart_html(
    "bar",
    "title: Monthly growth\nJan: 10\nFeb: 20",
    "default",
  )
  assert_true(html.contains("<svg"))
  assert_true(html.contains("Monthly growth"))
  assert_true(html.contains("<rect"))
  assert_true(html.contains(">Jan<"))
  assert_true(html.contains(">Feb<"))
}

///|
test "stacked and grouped bar charts support series" {
  let stacked = @render.render_chart_html(
    "stacked",
    "labels: Mon, Tue\nseries: A = 1, 2\nseries: B = 3, 4",
    "default",
  )
  assert_true(stacked.contains(">A<"))
  assert_true(stacked.contains(">B<"))
  assert_true(stacked.contains(">Mon<"))
  let grouped = @render.render_chart_html(
    "bar",
    "labels: Mon, Tue\nseries: A = 1, 2\nseries: B = 3, 4",
    "default",
  )
  assert_true(grouped.contains("<rect"))
  assert_true(grouped.contains(">Tue<"))
}

///|
test "line and area charts render polylines and fills" {
  let line = @render.render_chart_html(
    "line",
    "labels: Q1, Q2, Q3\nseries: A = 1, 3, 2",
    "default",
  )
  assert_true(line.contains("<polyline"))
  assert_true(line.contains("<circle"))
  assert_true(line.contains(">Q1<"))
  let area = @render.render_chart_html(
    "area",
    "labels: Q1, Q2, Q3\nseries: A = 1, 3, 2",
    "default",
  )
  assert_true(area.contains("<path"))
  assert_true(area.contains("fill-opacity=\"0.16\""))
}

///|
test "pie and donut charts render slices and percentages" {
  let pie = @render.render_chart_html("pie", "A: 60\nB: 40", "default")
  assert_true(pie.contains("<path"))
  assert_true(pie.contains(" L 220 215 Z"))
  assert_true(pie.contains("60%"))
  assert_true(pie.contains("40%"))
  let donut = @render.render_chart_html("donut", "A: 60\nB: 40", "default")
  assert_true(donut.contains("<path"))
  assert_true(donut.contains(" 0 0 "))
  assert_false(donut.contains(" L 220 215 Z"))
}

///|
test "scatter charts render numeric points" {
  let html = @render.render_chart_html(
    "scatter",
    "title: Samples\nseries: A = 1,2; 3,4; 5,3",
    "default",
  )
  assert_true(html.contains("Samples"))
  assert_true(html.contains("r=\"4\""))
  assert_true(html.contains("<circle"))
}

///|
test "radar charts render grid and series polygons" {
  let html = @render.render_chart_html(
    "radar",
    "labels: Speed, Power, Range, Defense\nseries: A = 1, 2, 3, 4",
    "default",
  )
  assert_true(html.contains("<polygon"))
  assert_true(html.contains(">Speed<"))
  assert_true(html.contains(">Defense<"))
}

///|
test "heatmaps render a labeled value grid" {
  let html = @render.render_chart_html(
    "heatmap",
    "labels: Mon, Tue\nseries: AM = 1, 2\nseries: PM = 3, 4",
    "default",
  )
  assert_true(html.contains("fill-opacity"))
  assert_true(html.contains(">AM<"))
  assert_true(html.contains(">Mon<"))
}

///|
test "chart blocks render through the document renderer" {
  let document = @types.Document::{
    theme: Some("#123456"),
    footer: None,
    split: None,
    letter: None,
    palette: Some("ocean"),
    blocks: [@types.Block::Chart("bar", "title: Growth\nA: 10\nB: 20")],
  }
  let html = @render.render_document(
    document,
    @types.Profile::empty(),
    Map([]),
  )
  assert_true(html.contains("data-sigil-chart"))
  assert_true(html.contains("<svg"))
  assert_true(html.contains("#0F766E"))
  assert_false(html.contains("#123456"))
  assert_false(html.contains("white-space:pre-wrap"))
}

///|
test "chart palettes are independent presets" {
  let source = "labels: A\nseries: X = 1\nseries: Y = 2"
  let default_palette = @render.render_chart_html("bar", source, "default")
  let ocean = @render.render_chart_html("bar", source, "ocean")
  assert_true(default_palette.contains("#2563EB"))
  assert_true(ocean.contains("#0F766E"))
  assert_false(default_palette.contains("#0F766E"))
  assert_false(default_palette == ocean)
}

///|
test "chart references render from the chart library" {
  let charts : Map[String, @types.ChartSpec] = Map([
    ("growth", { kind: "bar", text: "title: Growth\nA: 10\nB: 20" }),
  ])
  let document = @types.Document::{
    theme: None,
    footer: None,
    split: None,
    letter: None,
    palette: Some("sunset"),
    blocks: [@types.Block::ChartRef("growth")],
  }
  let html = @render.render_document_with_libraries(
    document,
    @types.Profile::empty(),
    Map([]),
    Map([]),
    charts,
  )
  assert_true(html.contains("data-sigil-chart"))
  assert_true(html.contains("#EA580C"))
  assert_false(html.contains("Chart not found"))
}

///|
test "unknown chart types render a friendly placeholder" {
  let html = @render.render_chart_html("unknown", "A: 1", "default")
  assert_true(html.contains("Unsupported chart type"))
}
