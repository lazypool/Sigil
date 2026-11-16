///|
/// Email-safe SVG charts.
///
/// Chart blocks stay plain text: directive lines configure the chart and simple
/// `label: value` lines provide the data. Multi-series charts use
/// `series: name = value, value, ...`; scatter points use `x,y; x,y`.
priv struct ChartSeries {
  name : String
  xs : Array[Double]
  ys : Array[Double]
}

///|
priv struct ChartData {
  title : String
  labels : Array[String]
  series : Array[ChartSeries]
}

///|
fn chart_parse_number(text : String) -> Double? {
  let value = text.trim().to_owned()
  if value == "" {
    return None
  }
  let chars = value.to_array()
  let length = chars.length()
  let mut index = 0
  let mut sign = 1.0
  if chars[0] == '-' {
    sign = -1.0
    index = 1
  } else if chars[0] == '+' {
    index = 1
  }
  let mut number = 0.0
  let mut seen = false
  while index < length && chars[index].is_ascii_digit() {
    number = number * 10.0 + Double::from_int(chars[index].to_int() - 48)
    seen = true
    index = index + 1
  }
  if index < length && chars[index] == '.' {
    index = index + 1
    let mut factor = 0.1
    while index < length && chars[index].is_ascii_digit() {
      number = number + Double::from_int(chars[index].to_int() - 48) * factor
      factor = factor / 10.0
      seen = true
      index = index + 1
    }
  }
  if !seen {
    return None
  }
  if index < length && (chars[index] == 'e' || chars[index] == 'E') {
    index = index + 1
    let mut exponent_sign = 1
    if index < length && chars[index] == '-' {
      exponent_sign = -1
      index = index + 1
    } else if index < length && chars[index] == '+' {
      index = index + 1
    }
    let mut exponent = 0
    while index < length && chars[index].is_ascii_digit() {
      exponent = exponent * 10 + (chars[index].to_int() - 48)
      index = index + 1
    }
    let mut factor = 1.0
    for step = 0; step < exponent; step = step + 1 {
      factor = factor * 10.0
    }
    if exponent_sign < 0 {
      number = number / factor
    } else {
      number = number * factor
    }
  }
  Some(sign * number)
}

///|
fn chart_split_values(raw : String) -> Array[Double] {
  let values : Array[Double] = []
  for part in raw.split(",") {
    match chart_parse_number(part.to_owned()) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  values
}

///|
fn chart_parse_series_values(
  kind : String,
  raw : String,
) -> (Array[Double], Array[Double]) {
  let xs : Array[Double] = []
  let ys : Array[Double] = []
  if kind == "scatter" {
    if raw.contains(";") {
      for point in raw.split(";") {
        let values = chart_split_values(point.to_owned())
        if values.length() >= 2 {
          xs.push(values[0])
          ys.push(values[1])
        }
      }
    } else {
      let values = chart_split_values(raw)
      let mut index = 0
      while index + 1 < values.length() {
        xs.push(values[index])
        ys.push(values[index + 1])
        index = index + 2
      }
    }
  } else {
    let values = chart_split_values(raw)
    for index = 0; index < values.length(); index = index + 1 {
      xs.push(Double::from_int(index))
      ys.push(values[index])
    }
  }
  (xs, ys)
}

///|
fn chart_parse_data(kind : String, text : String) -> ChartData {
  let mut title = ""
  let labels : Array[String] = []
  let series : Array[ChartSeries] = []
  let fallback_labels : Array[String] = []
  let fallback_values : Array[Double] = []
  for raw_line in text.split("\n") {
    let line = raw_line.to_owned().trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    match line.find(":") {
      Some(position) => {
        let key = line[0:position].trim().to_owned()
        let value = line[position + 1:].trim().to_owned()
        let lower = key.to_lower()
        if lower == "title" {
          title = value
        } else if lower == "labels" {
          for part in value.split(",") {
            labels.push(part.to_owned().trim().to_owned())
          }
        } else if lower == "series" {
          let (name, raw_values) = match value.find("=") {
            Some(equal) => (
              value[0:equal].trim().to_owned(),
              value[equal + 1:].trim().to_owned(),
            )
            None => (
              "Series " + (series.length() + 1).to_string(),
              value,
            )
          }
          let (xs, ys) = chart_parse_series_values(kind, raw_values)
          series.push({ name, xs, ys })
        } else {
          match chart_parse_number(value) {
            Some(number) => {
              fallback_labels.push(key)
              fallback_values.push(number)
            }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  if series.is_empty() && !fallback_values.is_empty() {
    let xs : Array[Double] = []
    for index = 0; index < fallback_values.length(); index = index + 1 {
      xs.push(Double::from_int(index))
    }
    series.push({ name: "Values", xs, ys: fallback_values })
    if labels.is_empty() {
      for label in fallback_labels {
        labels.push(label)
      }
    }
  }
  { title, labels, series }
}

///|
fn chart_palette(palette : String) -> Array[String] {
  match palette {
    "ocean" => [
      "#0F766E", "#0891B2", "#2563EB", "#4F46E5", "#06B6D4", "#14B8A6",
      "#3B82F6", "#0EA5E9",
    ]
    "sunset" => [
      "#EA580C", "#F59E0B", "#EF4444", "#EC4899", "#F97316", "#D946EF",
      "#FBBF24", "#BE123C",
    ]
    "forest" => [
      "#15803D", "#65A30D", "#0D9488", "#166534", "#84CC16", "#059669",
      "#4D7C0F", "#10B981",
    ]
    "berry" => [
      "#9333EA", "#DB2777", "#7C3AED", "#BE185D", "#C026D3", "#E11D48",
      "#8B5CF6", "#EC4899",
    ]
    "earth" => [
      "#92400E", "#B45309", "#78716C", "#A16207", "#57534E", "#D97706",
      "#854D0E", "#A8A29E",
    ]
    "mono" => [
      "#334155", "#64748B", "#1E293B", "#94A3B8", "#475569", "#0F172A",
      "#CBD5E1", "#6B7280",
    ]
    _ => [
      "#2563EB", "#F59E0B", "#10B981", "#8B5CF6", "#EF4444", "#06B6D4",
      "#EC4899", "#84CC16",
    ]
  }
}

///|
fn chart_number(value : Double) -> String {
  (Double::round(value * 100.0) / 100.0).to_string()
}

///|
fn chart_format_number(value : Double) -> String {
  (Double::round(value * 100.0) / 100.0).to_string()
}

///|
fn chart_label(
  x : Double,
  y : Double,
  text : String,
  size : Int,
  anchor : String,
  fill : String,
) -> String {
  "<text x=\"" +
  chart_number(x) +
  "\" y=\"" +
  chart_number(y) +
  "\" text-anchor=\"" +
  anchor +
  "\" font-size=\"" +
  size.to_string() +
  "\" fill=\"" +
  fill +
  "\">" +
  escape_html(text) +
  "</text>"
}

///|
fn chart_title_svg(title : String) -> String {
  if title == "" {
    return ""
  }
  "<text x=\"360\" y=\"30\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"600\" fill=\"#222833\">" +
  escape_html(title) +
  "</text>"
}

///|
fn chart_frame(title : String, body : String) -> String {
  let label = if title == "" { "Chart" } else { title }
  "<div class=\"sigil-chart\" data-sigil-chart=\"1\" style=\"margin:20px auto;width:100%;max-width:720px;box-sizing:border-box;\">" +
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 720 400\" width=\"100%\" role=\"img\" aria-label=\"" +
  escape_html(label) +
  "\" style=\"display:block;width:100%;max-width:100%;height:auto;font-family:'Helvetica Neue',Arial,sans-serif;\">" +
  "<title>" +
  escape_html(label) +
  "</title>" +
  chart_title_svg(title) +
  body +
  "</svg></div>"
}

///|
fn chart_empty(title : String, message : String) -> String {
  chart_frame(
    title,
    "<text x=\"360\" y=\"200\" text-anchor=\"middle\" font-size=\"14\" fill=\"#8a8a8a\">" +
    escape_html(message) +
    "</text>",
  )
}

///|
fn chart_bounds(series : Array[ChartSeries], include_zero : Bool) -> (Double, Double) {
  let mut min = 0.0
  let mut max = 0.0
  let mut has_value = false
  for item in series {
    for value in item.ys {
      if value.is_nan() || value.is_inf() {
        continue
      }
      if !has_value {
        min = value
        max = value
        has_value = true
      } else {
        if value < min {
          min = value
        }
        if value > max {
          max = value
        }
      }
    }
  }
  if !has_value {
    return (0.0, 1.0)
  }
  if include_zero {
    if min > 0.0 {
      min = 0.0
    }
    if max < 0.0 {
      max = 0.0
    }
  }
  if max <= min {
    max = min + 1.0
  }
  let padding = (max - min) * 0.08
  let lower = if min < 0.0 { min - padding } else { min }
  let upper = if max > 0.0 { max + padding } else { max }
  (lower, upper)
}

///|
fn chart_stacked_bounds(
  series : Array[ChartSeries],
  count : Int,
) -> (Double, Double) {
  let positive = Array::make(count, 0.0)
  let negative = Array::make(count, 0.0)
  for item in series {
    for index = 0; index < count && index < item.ys.length(); index = index + 1 {
      let value = item.ys[index]
      if value >= 0.0 {
        positive[index] = positive[index] + value
      } else {
        negative[index] = negative[index] + value
      }
    }
  }
  let mut min = 0.0
  let mut max = 0.0
  let mut has_value = false
  for index = 0; index < count; index = index + 1 {
    if positive[index] > max {
      max = positive[index]
    }
    if negative[index] < min {
      min = negative[index]
    }
    has_value = true
  }
  if !has_value {
    return (0.0, 1.0)
  }
  if max <= min {
    max = min + 1.0
  }
  let padding = (max - min) * 0.08
  let lower = if min < 0.0 { min - padding } else { min }
  let upper = if max > 0.0 { max + padding } else { max }
  (lower, upper)
}

///|
fn chart_scale_y(
  value : Double,
  min : Double,
  max : Double,
  top : Double,
  height : Double,
) -> Double {
  top + (max - value) / (max - min) * height
}

///|
fn chart_y_grid(
  left : Double,
  top : Double,
  width : Double,
  height : Double,
  min : Double,
  max : Double,
) -> String {
  let builder = StringBuilder()
  for index = 0; index <= 4; index = index + 1 {
    let ratio = Double::from_int(index) / 4.0
    let y = top + height * ratio
    let value = max - (max - min) * ratio
    builder.write_string(
      "<line x1=\"" +
      chart_number(left) +
      "\" y1=\"" +
      chart_number(y) +
      "\" x2=\"" +
      chart_number(left + width) +
      "\" y2=\"" +
      chart_number(y) +
      "\" stroke=\"#e5e7eb\" stroke-width=\"1\"/>",
    )
    builder.write_string(
      chart_label(left - 10.0, y + 4.0, chart_format_number(value), 11, "end", "#6b7280"),
    )
  }
  builder.to_string()
}

///|
fn chart_axis_baseline(
  value : Double,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
  min : Double,
  max : Double,
) -> String {
  if value < min || value > max {
    return ""
  }
  let y = chart_scale_y(value, min, max, top, height)
  "<line x1=\"" +
  chart_number(left) +
  "\" y1=\"" +
  chart_number(y) +
  "\" x2=\"" +
  chart_number(left + width) +
  "\" y2=\"" +
  chart_number(y) +
  "\" stroke=\"#9ca3af\" stroke-width=\"1\"/>"
}

///|
fn chart_category_labels(
  labels : Array[String],
  count : Int,
  left : Double,
  width : Double,
  y : Double,
) -> String {
  let builder = StringBuilder()
  let step = if count > 16 { count / 12 } else { 1 }
  for index = 0; index < count; index = index + 1 {
    if step > 1 && index % step != 0 {
      continue
    }
    let x = left + (Double::from_int(index) + 0.5) * width / Double::from_int(count)
    let text = if index < labels.length() {
      labels[index]
    } else {
      (index + 1).to_string()
    }
    builder.write_string(chart_label(x, y, text, 11, "middle", "#6b7280"))
  }
  builder.to_string()
}

///|
fn chart_x_grid(
  left : Double,
  top : Double,
  width : Double,
  height : Double,
  min : Double,
  max : Double,
) -> String {
  let builder = StringBuilder()
  for index = 0; index <= 4; index = index + 1 {
    let ratio = Double::from_int(index) / 4.0
    let x = left + width * ratio
    let value = min + (max - min) * ratio
    builder.write_string(
      "<line x1=\"" +
      chart_number(x) +
      "\" y1=\"" +
      chart_number(top) +
      "\" x2=\"" +
      chart_number(x) +
      "\" y2=\"" +
      chart_number(top + height) +
      "\" stroke=\"#eef0f3\" stroke-width=\"1\"/>",
    )
    builder.write_string(
      chart_label(x, top + height + 18.0, chart_format_number(value), 11, "middle", "#6b7280"),
    )
  }
  builder.to_string()
}

///|
fn chart_legend(
  series : Array[ChartSeries],
  palette : Array[String],
  left : Double,
  width : Double,
  y : Double,
) -> String {
  if series.length() <= 1 {
    return ""
  }
  let builder = StringBuilder()
  let slot = width / Double::from_int(series.length())
  for index = 0; index < series.length(); index = index + 1 {
    let x = left + Double::from_int(index) * slot
    builder.write_string(
      "<rect x=\"" +
      chart_number(x) +
      "\" y=\"" +
      chart_number(y - 9.0) +
      "\" width=\"10\" height=\"10\" rx=\"2\" fill=\"" +
      palette[index % palette.length()] +
      "\"/>",
    )
    builder.write_string(
      chart_label(x + 15.0, y, series[index].name, 11, "start", "#555555"),
    )
  }
  builder.to_string()
}

///|
fn chart_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill : String,
  opacity : Double,
) -> String {
  let safe_height = if height < 0.0 { 0.0 } else { height }
  "<rect x=\"" +
  chart_number(x) +
  "\" y=\"" +
  chart_number(y) +
  "\" width=\"" +
  chart_number(width) +
  "\" height=\"" +
  chart_number(safe_height) +
  "\" rx=\"2\" fill=\"" +
  fill +
  "\" fill-opacity=\"" +
  chart_number(opacity) +
  "\"/>"
}

///|
fn chart_category_count(data : ChartData) -> Int {
  let mut count = data.labels.length()
  for item in data.series {
    if item.ys.length() > count {
      count = item.ys.length()
    }
  }
  count
}

///|
fn chart_render_bars(data : ChartData, palette_name : String, stacked : Bool) -> String {
  let count = chart_category_count(data)
  if data.series.is_empty() || count == 0 {
    return chart_empty(data.title, "No chart data")
  }
  let palette = chart_palette(palette_name)
  let left = 64.0
  let top = 70.0
  let width = 600.0
  let height = 240.0
  let (min, max) = if stacked {
    chart_stacked_bounds(data.series, count)
  } else {
    chart_bounds(data.series, true)
  }
  let builder = StringBuilder()
  builder.write_string(chart_y_grid(left, top, width, height, min, max))
  builder.write_string(chart_axis_baseline(0.0, left, top, width, height, min, max))
  let group_width = width / Double::from_int(count)
  if stacked {
    let positive = Array::make(count, 0.0)
    let negative = Array::make(count, 0.0)
    let bar_width = group_width * 0.72
    for series_index = 0; series_index < data.series.length(); series_index = series_index + 1 {
      let item = data.series[series_index]
      let color = palette[series_index % palette.length()]
      for index = 0; index < count && index < item.ys.length(); index = index + 1 {
        let value = item.ys[index]
        let base = if value >= 0.0 {
          let start = positive[index]
          positive[index] = start + value
          start
        } else {
          let start = negative[index]
          negative[index] = start + value
          start
        }
        let y1 = chart_scale_y(base, min, max, top, height)
        let y2 = chart_scale_y(base + value, min, max, top, height)
        let rect_y = if y1 < y2 { y1 } else { y2 }
        let rect_height = if y1 < y2 { y2 - y1 } else { y1 - y2 }
        let x = left + Double::from_int(index) * group_width + group_width * 0.14
        builder.write_string(chart_rect(x, rect_y, bar_width, rect_height, color, 1.0))
      }
    }
  } else {
    let series_count = data.series.length()
    let bar_width = group_width * 0.72 / Double::from_int(series_count)
    for series_index = 0; series_index < series_count; series_index = series_index + 1 {
      let item = data.series[series_index]
      let color = palette[series_index % palette.length()]
      for index = 0; index < count && index < item.ys.length(); index = index + 1 {
        let value = item.ys[index]
        let y = chart_scale_y(value, min, max, top, height)
        let zero = chart_scale_y(0.0, min, max, top, height)
        let rect_y = if y < zero { y } else { zero }
        let rect_height = if y < zero { zero - y } else { y - zero }
        let x = left +
          Double::from_int(index) * group_width +
          group_width * 0.14 +
          Double::from_int(series_index) * bar_width
        builder.write_string(chart_rect(x, rect_y, bar_width, rect_height, color, 1.0))
      }
    }
  }
  builder.write_string(
    chart_category_labels(data.labels, count, left, width, top + height + 20.0),
  )
  builder.write_string(chart_legend(data.series, palette, left, width, 374.0))
  chart_frame(data.title, builder.to_string())
}

///|
fn chart_line_points(
  item : ChartSeries,
  count : Int,
  left : Double,
  width : Double,
  top : Double,
  height : Double,
  min : Double,
  max : Double,
) -> Array[(Double, Double)] {
  let points : Array[(Double, Double)] = []
  for index = 0; index < item.ys.length(); index = index + 1 {
    let x = if count <= 1 {
      left + width / 2.0
    } else {
      left + Double::from_int(index) * width / Double::from_int(count - 1)
    }
    let y = chart_scale_y(item.ys[index], min, max, top, height)
    points.push((x, y))
  }
  points
}

///|
fn chart_render_line(data : ChartData, palette_name : String, area : Bool) -> String {
  let count = chart_category_count(data)
  if data.series.is_empty() || count == 0 {
    return chart_empty(data.title, "No chart data")
  }
  let palette = chart_palette(palette_name)
  let left = 64.0
  let top = 70.0
  let width = 600.0
  let height = 240.0
  let (min, max) = chart_bounds(data.series, area)
  let builder = StringBuilder()
  builder.write_string(chart_y_grid(left, top, width, height, min, max))
  if area {
    builder.write_string(chart_axis_baseline(0.0, left, top, width, height, min, max))
  }
  for series_index = 0; series_index < data.series.length(); series_index = series_index + 1 {
    let item = data.series[series_index]
    let color = palette[series_index % palette.length()]
    let points = chart_line_points(item, count, left, width, top, height, min, max)
    if area && points.length() > 0 {
      let zero = chart_scale_y(0.0, min, max, top, height)
      let path = StringBuilder()
      path.write_string(
        "M " +
        chart_number(points[0].0) +
        " " +
        chart_number(zero) +
        " L " +
        chart_number(points[0].0) +
        " " +
        chart_number(points[0].1),
      )
      for index = 1; index < points.length(); index = index + 1 {
        path.write_string(
          " L " +
          chart_number(points[index].0) +
          " " +
          chart_number(points[index].1),
        )
      }
      path.write_string(
        " L " +
        chart_number(points[points.length() - 1].0) +
        " " +
        chart_number(zero) +
        " Z",
      )
      builder.write_string(
        "<path d=\"" +
        path.to_string() +
        "\" fill=\"" +
        color +
        "\" fill-opacity=\"0.16\" stroke=\"none\"/>",
      )
    }
    if points.length() > 0 {
      let polyline = StringBuilder()
      for index = 0; index < points.length(); index = index + 1 {
        if index > 0 {
          polyline.write_string(" ")
        }
        polyline.write_string(
          chart_number(points[index].0) +
          "," +
          chart_number(points[index].1),
        )
      }
      builder.write_string(
        "<polyline fill=\"none\" stroke=\"" +
        color +
        "\" stroke-width=\"2.5\" stroke-linejoin=\"round\" stroke-linecap=\"round\" points=\"" +
        polyline.to_string() +
        "\"/>",
      )
      for point in points {
        builder.write_string(
          "<circle cx=\"" +
          chart_number(point.0) +
          "\" cy=\"" +
          chart_number(point.1) +
          "\" r=\"3.5\" fill=\"" +
          color +
          "\" stroke=\"#ffffff\" stroke-width=\"1.5\"/>",
        )
      }
    }
  }
  builder.write_string(
    chart_category_labels(data.labels, count, left, width, top + height + 20.0),
  )
  builder.write_string(chart_legend(data.series, palette, left, width, 374.0))
  chart_frame(data.title, builder.to_string())
}

///|
fn chart_render_scatter(data : ChartData, palette_name : String) -> String {
  if data.series.is_empty() {
    return chart_empty(data.title, "No chart data")
  }
  let palette = chart_palette(palette_name)
  let left = 64.0
  let top = 70.0
  let width = 600.0
  let height = 240.0
  let (min, max) = chart_bounds(data.series, false)
  let mut x_min = 0.0
  let mut x_max = 1.0
  let mut has_x = false
  for item in data.series {
    for value in item.xs {
      if !has_x {
        x_min = value
        x_max = value
        has_x = true
      } else {
        if value < x_min {
          x_min = value
        }
        if value > x_max {
          x_max = value
        }
      }
    }
  }
  if x_max <= x_min {
    x_max = x_min + 1.0
  }
  let builder = StringBuilder()
  builder.write_string(chart_y_grid(left, top, width, height, min, max))
  builder.write_string(chart_x_grid(left, top, width, height, x_min, x_max))
  for series_index = 0; series_index < data.series.length(); series_index = series_index + 1 {
    let item = data.series[series_index]
    let color = palette[series_index % palette.length()]
    for index = 0; index < item.xs.length() && index < item.ys.length(); index = index + 1 {
      let x = left + (item.xs[index] - x_min) / (x_max - x_min) * width
      let y = chart_scale_y(item.ys[index], min, max, top, height)
      builder.write_string(
        "<circle cx=\"" +
        chart_number(x) +
        "\" cy=\"" +
        chart_number(y) +
        "\" r=\"4\" fill=\"" +
        color +
        "\" fill-opacity=\"0.82\" stroke=\"#ffffff\" stroke-width=\"1\"/>",
      )
    }
  }
  builder.write_string(chart_legend(data.series, palette, left, width, 374.0))
  chart_frame(data.title, builder.to_string())
}

///|
fn chart_render_pie(data : ChartData, palette_name : String, donut : Bool) -> String {
  let labels : Array[String] = []
  let values : Array[Double] = []
  if data.labels.length() > 0 && data.series.length() > 0 {
    for index = 0; index < data.labels.length() && index < data.series[0].ys.length(); index = index + 1 {
      labels.push(data.labels[index])
      values.push(data.series[0].ys[index])
    }
  } else {
    for item in data.series {
      labels.push(if item.name == "" { "Value" } else { item.name })
      values.push(if item.ys.length() > 0 { item.ys[0] } else { 0.0 })
    }
  }
  let mut total = 0.0
  let mut positive_count = 0
  for value in values {
    if value > 0.0 {
      total = total + value
      positive_count = positive_count + 1
    }
  }
  if total <= 0.0 {
    return chart_empty(data.title, "No positive values to plot")
  }
  let palette = chart_palette(palette_name)
  let center_x = 220.0
  let center_y = 215.0
  let radius = 120.0
  let inner = if donut { 64.0 } else { 0.0 }
  let builder = StringBuilder()
  if positive_count == 1 {
    let color = palette[0]
    builder.write_string(
      "<circle cx=\"" +
      chart_number(center_x) +
      "\" cy=\"" +
      chart_number(center_y) +
      "\" r=\"" +
      chart_number(radius) +
      "\" fill=\"" +
      color +
      "\"/>",
    )
    if donut {
      builder.write_string(
        "<circle cx=\"" +
        chart_number(center_x) +
        "\" cy=\"" +
        chart_number(center_y) +
        "\" r=\"" +
        chart_number(inner) +
        "\" fill=\"#ffffff\"/>",
      )
    }
  } else {
    let mut angle = -@math.PI / 2.0
    for index = 0; index < values.length(); index = index + 1 {
      let value = values[index]
      if value <= 0.0 {
        continue
      }
      let sweep = value / total * 2.0 * @math.PI
      let start = angle
      let end = angle + sweep
      angle = end
      let x1 = center_x + radius * @math.cos(start)
      let y1 = center_y + radius * @math.sin(start)
      let x2 = center_x + radius * @math.cos(end)
      let y2 = center_y + radius * @math.sin(end)
      let large = if sweep > @math.PI { "1" } else { "0" }
      let color = palette[index % palette.length()]
      let path = StringBuilder()
      path.write_string(
        "M " +
        chart_number(x1) +
        " " +
        chart_number(y1) +
        " A " +
        chart_number(radius) +
        " " +
        chart_number(radius) +
        " 0 " +
        large +
        " 1 " +
        chart_number(x2) +
        " " +
        chart_number(y2),
      )
      if donut {
        let ix1 = center_x + inner * @math.cos(start)
        let iy1 = center_y + inner * @math.sin(start)
        let ix2 = center_x + inner * @math.cos(end)
        let iy2 = center_y + inner * @math.sin(end)
        path.write_string(
          " L " +
          chart_number(ix2) +
          " " +
          chart_number(iy2) +
          " A " +
          chart_number(inner) +
          " " +
          chart_number(inner) +
          " 0 " +
          large +
          " 0 " +
          chart_number(ix1) +
          " " +
          chart_number(iy1),
        )
      } else {
        path.write_string(
          " L " + chart_number(center_x) + " " + chart_number(center_y),
        )
      }
      path.write_string(" Z")
      builder.write_string(
        "<path d=\"" +
        path.to_string() +
        "\" fill=\"" +
        color +
        "\" stroke=\"#ffffff\" stroke-width=\"2\"/>",
      )
    }
  }
  for index = 0; index < labels.length() && index < values.length(); index = index + 1 {
    if values[index] <= 0.0 {
      continue
    }
    let y = 96.0 + Double::from_int(index) * 26.0
    builder.write_string(
      "<rect x=\"400\" y=\"" +
      chart_number(y - 10.0) +
      "\" width=\"12\" height=\"12\" rx=\"2\" fill=\"" +
      palette[index % palette.length()] +
      "\"/>",
    )
    builder.write_string(
      chart_label(420.0, y, labels[index], 12, "start", "#444444"),
    )
    let percent = values[index] / total * 100.0
    builder.write_string(
      chart_label(
        664.0,
        y,
        chart_format_number(percent) + "%",
        12,
        "end",
        "#6b7280",
      ),
    )
  }
  chart_frame(data.title, builder.to_string())
}

///|
fn chart_dimension_count(data : ChartData) -> Int {
  let mut count = data.labels.length()
  for item in data.series {
    if item.ys.length() > count {
      count = item.ys.length()
    }
  }
  count
}

///|
fn chart_render_radar(data : ChartData, palette_name : String) -> String {
  let count = chart_dimension_count(data)
  if data.series.is_empty() || count < 3 {
    return chart_empty(data.title, "Radar charts need at least three dimensions")
  }
  let palette = chart_palette(palette_name)
  let center_x = 360.0
  let center_y = 215.0
  let radius = 128.0
  let mut maximum = 1.0
  for item in data.series {
    for value in item.ys {
      if value > maximum {
        maximum = value
      }
    }
  }
  let angle_at = fn(index : Int) -> Double {
    -@math.PI / 2.0 + 2.0 * @math.PI * Double::from_int(index) / Double::from_int(count)
  }
  let builder = StringBuilder()
  for level = 1; level <= 4; level = level + 1 {
    let level_radius = radius * Double::from_int(level) / 4.0
    let points = StringBuilder()
    for index = 0; index < count; index = index + 1 {
      if index > 0 {
        points.write_string(" ")
      }
      let angle = angle_at(index)
      points.write_string(
        chart_number(center_x + level_radius * @math.cos(angle)) +
        "," +
        chart_number(center_y + level_radius * @math.sin(angle)),
      )
    }
    builder.write_string(
      "<polygon points=\"" +
      points.to_string() +
      "\" fill=\"none\" stroke=\"#e5e7eb\" stroke-width=\"1\"/>",
    )
  }
  for index = 0; index < count; index = index + 1 {
    let angle = angle_at(index)
    builder.write_string(
      "<line x1=\"" +
      chart_number(center_x) +
      "\" y1=\"" +
      chart_number(center_y) +
      "\" x2=\"" +
      chart_number(center_x + radius * @math.cos(angle)) +
      "\" y2=\"" +
      chart_number(center_y + radius * @math.sin(angle)) +
      "\" stroke=\"#e5e7eb\" stroke-width=\"1\"/>",
    )
    let label_x = center_x + (radius + 24.0) * @math.cos(angle)
    let label_y = center_y + (radius + 24.0) * @math.sin(angle) + 4.0
    let text = if index < data.labels.length() {
      data.labels[index]
    } else {
      "D" + (index + 1).to_string()
    }
    builder.write_string(chart_label(label_x, label_y, text, 11, "middle", "#555555"))
  }
  for series_index = 0; series_index < data.series.length(); series_index = series_index + 1 {
    let item = data.series[series_index]
    let color = palette[series_index % palette.length()]
    let points = StringBuilder()
    for index = 0; index < count; index = index + 1 {
      let value = if index < item.ys.length() { item.ys[index] } else { 0.0 }
      let ratio = if value > 0.0 { value / maximum } else { 0.0 }
      let angle = angle_at(index)
      if index > 0 {
        points.write_string(" ")
      }
      points.write_string(
        chart_number(center_x + radius * ratio * @math.cos(angle)) +
        "," +
        chart_number(center_y + radius * ratio * @math.sin(angle)),
      )
    }
    builder.write_string(
      "<polygon points=\"" +
      points.to_string() +
      "\" fill=\"" +
      color +
      "\" fill-opacity=\"0.14\" stroke=\"" +
      color +
      "\" stroke-width=\"2\"/>",
    )
  }
  builder.write_string(chart_legend(data.series, palette, 64.0, 600.0, 382.0))
  chart_frame(data.title, builder.to_string())
}

///|
fn chart_render_heatmap(data : ChartData, palette_name : String) -> String {
  let columns = data.labels.length()
  if data.series.is_empty() || columns == 0 {
    return chart_empty(data.title, "Heatmaps need labels and series rows")
  }
  let rows = data.series.length()
  let palette = chart_palette(palette_name)
  let mut minimum = 0.0
  let mut maximum = 0.0
  let mut has_value = false
  for item in data.series {
    for value in item.ys {
      if !has_value {
        minimum = value
        maximum = value
        has_value = true
      } else {
        if value < minimum {
          minimum = value
        }
        if value > maximum {
          maximum = value
        }
      }
    }
  }
  if !has_value {
    return chart_empty(data.title, "No chart data")
  }
  if maximum <= minimum {
    maximum = minimum + 1.0
  }
  let left = 160.0
  let top = 92.0
  let width = 530.0
  let cell_width = width / Double::from_int(columns)
  let cell_height = if rows > 8 { 280.0 / Double::from_int(rows) } else { 32.0 }
  let builder = StringBuilder()
  for column = 0; column < columns; column = column + 1 {
    let x = left + (Double::from_int(column) + 0.5) * cell_width
    builder.write_string(chart_label(x, top - 12.0, data.labels[column], 11, "middle", "#555555"))
  }
  for row = 0; row < rows; row = row + 1 {
    let item = data.series[row]
    let y = top + Double::from_int(row) * cell_height
    builder.write_string(
      chart_label(left - 12.0, y + cell_height / 2.0 + 4.0, item.name, 11, "end", "#555555"),
    )
    for column = 0; column < columns; column = column + 1 {
      let value = if column < item.ys.length() { item.ys[column] } else { minimum }
      let ratio = (value - minimum) / (maximum - minimum)
      let opacity = 0.08 + ratio * 0.82
      let x = left + Double::from_int(column) * cell_width
      builder.write_string(
        "<rect x=\"" +
        chart_number(x) +
        "\" y=\"" +
        chart_number(y) +
        "\" width=\"" +
        chart_number(cell_width) +
        "\" height=\"" +
        chart_number(cell_height) +
        "\" fill=\"" +
        palette[0] +
        "\" fill-opacity=\"" +
        chart_number(opacity) +
        "\" stroke=\"#ffffff\" stroke-width=\"2\"/>",
      )
      let text_fill = if ratio > 0.55 { "#ffffff" } else { "#222833" }
      builder.write_string(
        chart_label(
          x + cell_width / 2.0,
          y + cell_height / 2.0 + 4.0,
          chart_format_number(value),
          11,
          "middle",
          text_fill,
        ),
      )
    }
  }
  chart_frame(data.title, builder.to_string())
}

///|
/// Render a `:::chart` block to email-safe SVG.
pub fn render_chart_html(kind : String, text : String, palette_name : String) -> String {
  let normalized = kind.trim().to_owned().to_lower()
  let data = chart_parse_data(normalized, text)
  match normalized {
    "bar" | "column" => chart_render_bars(data, palette_name, false)
    "stacked" | "stacked-bar" | "stacked_bar" =>
      chart_render_bars(data, palette_name, true)
    "line" => chart_render_line(data, palette_name, false)
    "area" => chart_render_line(data, palette_name, true)
    "pie" => chart_render_pie(data, palette_name, false)
    "donut" | "doughnut" => chart_render_pie(data, palette_name, true)
    "scatter" | "points" => chart_render_scatter(data, palette_name)
    "radar" | "spider" => chart_render_radar(data, palette_name)
    "heatmap" | "heat-map" | "heat_map" => chart_render_heatmap(data, palette_name)
    _ => chart_empty(data.title, "Unsupported chart type: " + normalized)
  }
}
