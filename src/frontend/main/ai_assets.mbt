///|
/// Tool execution for the unified AI agent. Turns a `create_table` or
/// `create_chart` tool call into a committed library asset (or chart block)
/// plus a result string the model can reference in its final document.

///|
fn tool_arg_string(arguments_json : String, key : String) -> String {
  let parsed = @json.parse(arguments_json) catch { _ => return "" }
  match parsed {
    @json.Json::Object(map) => match map.get(key) {
      Some(@json.Json::String(text)) => text
      _ => ""
    }
    _ => ""
  }
}

///|
/// Execute one tool call and return the updated model plus a result message.
fn ai_execute_tool(
  model : Model,
  doc_id : String,
  name : String,
  arguments : String,
) -> (Model, String) {
  match name {
    "create_table" =>
      ai_tool_create_table(
        model,
        doc_id,
        tool_arg_string(arguments, "data"),
      )
    "create_chart" =>
      (model, ai_tool_create_chart(tool_arg_string(arguments, "kind"), tool_arg_string(arguments, "data")))
    _ => (model, "Unknown tool: " + name)
  }
}

///|
fn ai_tool_create_table(
  model : Model,
  doc_id : String,
  data : String,
) -> (Model, String) {
  let csv = @convert.limit_table(@convert.json_or_csv_to_csv(data))
  if csv.trim() == "" {
    return (model, "Table data was empty or invalid.")
  }
  match find_document(model.documents, doc_id) {
    None => (model, "The email being edited was closed.")
    Some(_) => {
      let library = library_for_document(model, doc_id)
      let name = unique_table_name(library.tables, "table.csv")
      let table : TableAsset = {
        id: new_id("tbl"),
        name,
        csv,
        folder: "",
      }
      let tables = library.tables.copy()
      tables.push(table)
      let next = commit_library(model, doc_id, { ..library, tables })
      (
        next,
        "Table created and saved to the library. Insert this exact reference in your final document: <table:" +
        name +
        ">",
      )
    }
  }
}

///|
fn ai_tool_create_chart(kind : String, data : String) -> String {
  let chart_kind = if @convert.valid_chart_kind(kind) {
    kind.trim().to_owned().to_lower()
  } else {
    "bar"
  }
  let csv = @convert.json_or_csv_to_csv(data)
  let body = @convert.csv_to_chart_body(csv, chart_kind)
  let html = @render.render_chart_html(
    chart_kind,
    body,
    @types.chart_palette_default(),
  )
  if html == "" {
    return "Chart data was invalid."
  }
  let markup = "\n:::chart " + chart_kind + "\n" + body + "\n:::\n"
  "Chart created. Insert this exact block in your final document:\n" + markup
}

///|
/// Execute the model's tool calls, append the results to the conversation, and
/// run the next agent round.
fn ai_agent_tool_turn(
  model : Model,
  tool_calls_json : String,
  emit : Emit[Msg],
) -> (Model, Cmd) {
  let calls = ai_parse_tool_calls(tool_calls_json)
  if calls.is_empty() {
    return (
      {
        ..model,
        ai_status: AiError,
        ai_error: tr(
          model.lang,
          "The model asked for tools, but none could be parsed.",
          "模型请求了工具，但无法解析。",
        ),
      },
      @rabbita.none,
    )
  }
  let doc_id = model.ai_target_doc_id
  let results : Array[String] = []
  let mut next = model
  for call in calls {
    let (m, result) = ai_execute_tool(next, doc_id, call.name, call.arguments)
    next = m
    results.push(result)
  }
  let turn = ai_build_tool_turn(calls, results)
  let messages = storage_get("sigil.ai.messages")
  storage_set(
    "sigil.ai.messages",
    ai_agent_append_tool_turn(messages, turn),
  )
  (
    next,
    @rabbita.perform(json => emit(AiAgentReplied(json)), ai_agent_task),
  )
}

///|
/// Apply the model's final answer as the polished document.
fn ai_agent_finish(model : Model, content : String) -> (Model, Cmd) {
  let markup = strip_ai_instruction_lines(extract_ai_markup(content))
  if markup == "" || ai_is_markdown_output(markup) {
    return (
      {
        ..model,
        ai_status: AiError,
        ai_error: tr(
          model.lang,
          "The model returned Markdown instead of Sigil markup. Please try again.",
          "模型返回了 Markdown 而不是 Sigil 标记，请重试。",
        ),
      },
      @rabbita.none,
    )
  }
  match find_document(model.documents, model.ai_target_doc_id) {
    None =>
      (
        {
          ..model,
          ai_status: AiError,
          ai_error: tr(
            model.lang,
            "The email being polished was closed.",
            "正在润色的邮件已被关闭。",
          ),
        },
        @rabbita.none,
      )
    Some(document) => {
      let next = {
        ..model,
        documents: with_document_source(model.documents, document.id, markup),
        ai_status: AiDone,
        ai_error: "",
      }
      persist(next)
      (next, @rabbita.none)
    }
  }
}
