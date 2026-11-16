///|
/// One plain-text chart stored in the local workspace.
#derive(Eq, ToJson, FromJson)
struct ChartAsset {
  id : String
  name : String
  kind : String
  text : String
  folder : String
}

///|
/// Shape returned by the chart text picker.
#derive(Eq, FromJson)
struct IncomingChartAsset {
  id : String
  name : String
  kind : String
  text : String
}

///|
fn find_chart(charts : Array[ChartAsset], id : String) -> ChartAsset? {
  for chart in charts {
    if chart.id == id {
      return Some(chart)
    }
  }
  None
}

///|
fn has_chart_name(charts : Array[ChartAsset], name : String) -> Bool {
  for chart in charts {
    if chart.name == name {
      return true
    }
  }
  false
}

///|
fn unique_chart_name(charts : Array[ChartAsset], name : String) -> String {
  let base = if name == "" { "chart.chart" } else { name }
  let mut candidate = base
  let mut suffix = 2
  while has_chart_name(charts, candidate) {
    match base.rev_split_once(".") {
      Some((stem, extension)) =>
        candidate = stem.to_owned() +
          "-" +
          suffix.to_string() +
          "." +
          extension.to_owned()
      None => candidate = base + "-" + suffix.to_string()
    }
    suffix = suffix + 1
  }
  candidate
}

///|
fn merge_charts(
  existing : Array[ChartAsset],
  imported : Array[IncomingChartAsset],
) -> Array[ChartAsset] {
  let result = existing.copy()
  for chart in imported {
    let name = unique_chart_name(result, chart.name)
    result.push({
      id: chart.id,
      name,
      kind: chart.kind,
      text: chart.text,
      folder: "",
    })
  }
  result
}

///|
fn remove_chart(charts : Array[ChartAsset], id : String) -> Array[ChartAsset] {
  let result : Array[ChartAsset] = []
  for chart in charts {
    if chart.id != id {
      result.push(chart)
    }
  }
  result
}

///|
fn with_chart(
  charts : Array[ChartAsset],
  id : String,
  kind : String,
  text : String,
) -> Array[ChartAsset] {
  let result : Array[ChartAsset] = []
  for chart in charts {
    if chart.id == id {
      result.push({ ..chart, kind, text, })
    } else {
      result.push(chart)
    }
  }
  result
}

///|
fn chart_map(charts : Array[ChartAsset]) -> Map[String, @types.ChartSpec] {
  let result : Map[String, @types.ChartSpec] = Map([])
  for chart in charts {
    result[chart.name] = { kind: chart.kind, text: chart.text }
  }
  result
}

///|
fn chart_document_palette(document : EmailDoc) -> String {
  let parsed = @parser.parse(document.source)
  match parsed.document.palette {
    Some(value) => value
    None => @types.chart_palette_default()
  }
}

///|
fn chart_srcdoc(
  kind : String,
  text : String,
  palette : String,
  compact~ : Bool = false,
) -> String {
  let extra = if compact {
    ".sigil-chart{margin:0 auto !important;max-width:100% !important;}" +
    "svg{max-height:150px;max-width:100% !important;width:auto !important;margin:0 auto;display:block;}"
  } else {
    ""
  }
  "<!doctype html><html><head><meta charset=\"utf-8\">" +
  "<style>html,body{margin:0;padding:" +
  (if compact { "8px" } else { "12px" }) +
  ";background:#ffffff;font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;}" +
  extra +
  "</style>" +
  "</head><body>" +
  @render.render_chart_html(kind, text, palette) +
  "</body></html>"
}

///|
fn chart_markup(name : String) -> String {
  "\n<chart:" + name + ">\n"
}

///|
fn chart_kind_label(lang : Lang, kind : String) -> String {
  match kind {
    "bar" => tr(lang, "Bar", "柱状图")
    "stacked" => tr(lang, "Stacked bar", "堆积柱状图")
    "line" => tr(lang, "Line", "折线图")
    "area" => tr(lang, "Area", "面积图")
    "pie" => tr(lang, "Pie", "饼图")
    "donut" => tr(lang, "Donut", "环形图")
    "scatter" => tr(lang, "Scatter", "散点图")
    "radar" => tr(lang, "Radar", "雷达图")
    "heatmap" => tr(lang, "Heatmap", "热力图")
    _ => kind
  }
}

///|
fn chart_kinds() -> Array[String] {
  ["bar", "stacked", "line", "area", "pie", "donut", "scatter", "radar", "heatmap"]
}

///|
fn chart_template(kind : String, lang : Lang) -> String {
  let title = tr(lang, "New chart", "新图表")
  let first = tr(lang, "Series 1", "系列 1")
  let second = tr(lang, "Series 2", "系列 2")
  match kind.to_lower() {
    "pie" | "donut" =>
      "title: " + title + "\nA: 40\nB: 35\nC: 25"
    "scatter" =>
      "title: " +
      title +
      "\nseries: " +
      first +
      " = 1,2; 2,4; 3,3; 4,6"
    "radar" =>
      "title: " +
      title +
      "\nlabels: A, B, C, D, E\nseries: " +
      first +
      " = 8, 6, 7, 9, 5\nseries: " +
      second +
      " = 6, 8, 5, 9, 7"
    "heatmap" =>
      "title: " +
      title +
      "\nlabels: Mon, Tue, Wed, Thu, Fri\nseries: " +
      first +
      " = 1, 2, 3, 4, 5\nseries: " +
      second +
      " = 5, 4, 3, 2, 1"
    _ =>
      "title: " +
      title +
      "\nlabels: A, B, C, D\nseries: " +
      first +
      " = 10, 20, 15, 25\nseries: " +
      second +
      " = 8, 14, 18, 12"
  }
}

///|
fn new_chart(charts : Array[ChartAsset], lang : Lang) -> ChartAsset {
  let base = tr(lang, "New chart", "新图表") + ".chart"
  {
    id: new_id("chart"),
    name: unique_chart_name(charts, base),
    kind: "bar",
    text: chart_template("bar", lang),
    folder: "",
  }
}

///|
extern "js" fn open_chart_picker() -> Unit = "() => { const el = document.getElementById('sigil-chart-input'); if (!el) return; el.value = ''; el.click(); }"

///|
extern "js" fn read_chart_input_promise() -> @js_async.Promise[String] =
  #| () => new Promise((resolve) => {
  #|   const input = document.getElementById('sigil-chart-input');
  #|   if (!input || !input.files || input.files.length === 0) {
  #|     resolve('[]');
  #|     return;
  #|   }
  #|   const files = Array.from(input.files);
  #|   const newId = () => 'chart-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
  #|   (async () => {
  #|     const results = [];
  #|     for (const file of files) {
  #|       try {
  #|         const text = await file.text();
  #|         const lines = text.replace(/\r/g, '').split('\n');
  #|         const firstIndex = lines.findIndex((line) => line.trim() !== '');
  #|         if (firstIndex < 0) continue;
  #|         const first = lines[firstIndex].trim();
  #|         let kind = 'bar';
  #|         let bodyLines = lines;
  #|         const fence = first.match(/^:::chart\s+([A-Za-z][\w-]*)/);
  #|         if (fence) {
  #|           kind = fence[1].toLowerCase();
  #|           let close = lines.length;
  #|           for (let index = firstIndex + 1; index < lines.length; index = index + 1) {
  #|             if (lines[index].trim() === ':::') {
  #|               close = index;
  #|               break;
  #|             }
  #|           }
  #|           bodyLines = lines.slice(firstIndex + 1, close);
  #|         } else {
  #|           const directive = first.match(/^(?:kind|chart)\s*:\s*([A-Za-z][\w-]*)/i);
  #|           if (directive) {
  #|             kind = directive[1].toLowerCase();
  #|             bodyLines = lines.slice(firstIndex + 1);
  #|           }
  #|         }
  #|         const body = bodyLines.join('\n').trim();
  #|         if (body === '') continue;
  #|         const base = (file.name.replace(/\.[^.]+$/, '') || 'chart').trim() || 'chart';
  #|         results.push({
  #|           id: newId(),
  #|           name: base + '.chart',
  #|           kind,
  #|           text: body
  #|         });
  #|       } catch (error) {
  #|         // Unreadable files are skipped.
  #|       }
  #|     }
  #|     input.value = '';
  #|     resolve(JSON.stringify(results));
  #|   })();
  #| })

///|
async fn import_charts_task() -> String noraise {
  @js_async.run_promise(_ => read_chart_input_promise()) catch {
    _ => "[]"
  }
}

///|
fn parse_charts(json : String) -> Array[IncomingChartAsset] {
  let parsed = @json.parse(json) catch { _ => return [] }
  let charts : Array[IncomingChartAsset] = @json.from_json(parsed) catch {
    _ => return []
  }
  charts
}
