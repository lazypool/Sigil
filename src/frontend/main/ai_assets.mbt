///|
/// AI chart/table generation: builds the request, parses the reply, normalizes
/// the result into a Sigil-safe asset, then commits it to the library and
/// inserts the markup at the cursor.
///
/// Reuses the AiConfig/AiRequest/AiReply structures and the fetch helper from
/// `ai.mbt` without modifying them.

///|
enum AiAssetKind {
  Chart
  Table
}

///|
struct AiAssetDraft {
  kind : AiAssetKind
  chart_kind : String
  chart_body : String
  table_csv : String
}

///|
fn ai_asset_system_prompt() -> String {
  (
    #|You are the asset generator for Sigil, a minimal markup language for email.
    #|Given a natural-language request or pasted JSON/CSV data, produce exactly one
    #|structured asset as a single JSON object and return nothing else.
    #|
    #|RESPONSE SHAPE
    #|Return exactly one of these JSON objects, with no Markdown fences, no HTML,
    #|and no commentary:
    #|  {"kind":"chart","chart_kind":"bar","chart_body":"..."}
    #|  {"kind":"table","table_csv":"..."}
    #|
    #|RULES
    #|- "kind" must be "chart" or "table".
    #|- For a chart, "chart_kind" must be one of: bar, stacked, line, area, pie,
    #|  donut, scatter, radar, heatmap. "chart_body" uses these directives, one per
    #|  line:
    #|    title: <text>
    #|    labels: <a, b, c>
    #|    series: <Name> = <v1, v2, v3>
    #|- For a table, "table_csv" is RFC-4180 CSV with at most 5 columns and at most
    #|  60 characters per cell. Do not emit a Markdown table (no | or - grid).
    #|- Never invent asset names; the app names the asset itself.
    #|- Do not output anything outside the single JSON object.
  )
}

///|
fn ai_asset_build_request(
  model : Model,
  document : EmailDoc,
  user_input : String,
) -> AiRequest {
  let user_prompt = "Document title: " +
    document.title +
    "\n\nUser request:\n" +
    user_input
  {
    endpoint: model.ai.endpoint.trim().to_owned(),
    api_key: model.ai.api_key.trim().to_owned(),
    model: model.ai.model.trim().to_owned(),
    system: ai_asset_system_prompt(),
    prompt: user_prompt,
    temperature: 0.4,
  }
}

///|
fn json_string_field(map : Map[String, @json.Json], key : String) -> String {
  match map.get(key) {
    Some(value) => match value {
      @json.Json::String(text) => text
      _ => ""
    }
    None => ""
  }
}

///|
/// Parse a raw JSON reply into a normalized asset draft, clamping the table to
/// the editor limits and falling back to a valid chart kind.
fn normalize_ai_asset(raw_json : String) -> AiAssetDraft? {
  let parsed = @json.parse(raw_json) catch { _ => return None }
  match parsed {
    @json.Json::Object(map) => {
      let kind = json_string_field(map, "kind").trim().to_owned().to_lower()
      if kind == "table" {
        let csv = json_string_field(map, "table_csv")
        let table_csv = @convert.limit_table(
          @convert.json_or_csv_to_csv(csv),
        )
        Some({ kind: Table, chart_kind: "", chart_body: "", table_csv, })
      } else if kind == "chart" {
        let raw_kind = json_string_field(map, "chart_kind")
        let chart_kind = if @convert.valid_chart_kind(raw_kind) {
          raw_kind.trim().to_owned().to_lower()
        } else {
          "bar"
        }
        let chart_body = json_string_field(map, "chart_body")
        let html = @render.render_chart_html(
          chart_kind,
          chart_body,
          @types.chart_palette_default(),
        )
        if html == "" {
          None
        } else {
          Some({ kind: Chart, chart_kind, chart_body, table_csv: "", })
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Read and clear the pending AI asset request, then run the fetch helper.
async fn ai_asset_task() -> String noraise {
  let request = storage_get("sigil.ai.assets.pending")
  if request == "" {
    return "{\"ok\":false,\"content\":\"\",\"error\":\"No AI asset request is pending.\"}"
  }
  storage_remove("sigil.ai.assets.pending")
  @js_async.run_promise(_ => ai_fetch_promise(request)) catch {
    _ => "{\"ok\":false,\"content\":\"\",\"error\":\"AI request failed.\"}"
  }
}

///|
/// Commit a normalized draft into the document library and insert the markup at
/// the cursor. Returns the updated model and an error string (empty on success).
fn ai_asset_apply(model : Model, json : String) -> (Model, String) {
  let reply = parse_ai_reply(json)
  if !reply.ok {
    return (model, reply.error)
  }
  let raw = extract_ai_markup(reply.content)
  let draft = match normalize_ai_asset(raw) {
    Some(draft) => draft
    None =>
      return (
        model,
        tr(
          model.lang,
          "The model did not return a valid chart or table.",
          "模型未返回有效的图表或表格。",
        ),
      )
  }
  let target = if model.ai_asset_target_doc_id != "" &&
    find_document(model.documents, model.ai_asset_target_doc_id) is Some(_) {
    model.ai_asset_target_doc_id
  } else {
    model.active_tab
  }
  match find_document(model.documents, target) {
    None =>
      (
        model,
        tr(
          model.lang,
          "The email being edited was closed.",
          "正在编辑的邮件已被关闭。",
        ),
      )
    Some(document) => match draft.kind {
      Table => {
        let library = library_for_document(model, target)
        let name = unique_table_name(library.tables, "table.csv")
        let table : TableAsset = {
          id: new_id("tbl"),
          name,
          csv: draft.table_csv,
          folder: "",
        }
        let tables = library.tables.copy()
        tables.push(table)
        let next = commit_library(model, target, { ..library, tables })
        let markup = table_markup(name)
        let inserted = insert_at_cursor(markup)
        let source = if inserted == "" {
          document.source + markup
        } else {
          inserted
        }
        let base = {
          ..next,
          documents: with_document_source(
            next.documents,
            document.id,
            source,
          ),
        }
        let next = if next.library_doc_id != target {
          switch_library(base, target)
        } else {
          base
        }
        persist(next)
        (next, "")
      }
      Chart => {
        let markup = "\n:::chart " +
          draft.chart_kind +
          "\n" +
          draft.chart_body +
          "\n:::\n"
        let inserted = insert_at_cursor(markup)
        let source = if inserted == "" {
          document.source + markup
        } else {
          inserted
        }
        let next = {
          ..model,
          documents: with_document_source(
            model.documents,
            document.id,
            source,
          ),
        }
        persist(next)
        (next, "")
      }
    }
  }
}
