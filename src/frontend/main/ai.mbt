///|
/// User-configured OpenAI-compatible chat completion endpoint.
#derive(Eq)
struct AiConfig {
  endpoint : String
  model : String
  api_key : String
}

///|
#derive(Eq)
enum AiStatus {
  AiIdle
  AiLoading
  AiDone
  AiError
}

///|
/// Normalized answer returned by the browser-side fetch helper. `tool_calls`
/// is a JSON array of `{id, name, arguments}` when the model asked for tools.
#derive(FromJson)
struct AiReply {
  ok : Bool
  content : String
  tool_calls : String
  error : String
}

///|
fn default_ai_config() -> AiConfig {
  {
    endpoint: "https://api.openai.com/v1/chat/completions",
    model: "gpt-4o-mini",
    api_key: "",
  }
}

///|
fn load_ai_config() -> AiConfig {
  let defaults = default_ai_config()
  let endpoint = storage_get("sigil.ai.endpoint")
  let model = storage_get("sigil.ai.model")
  {
    endpoint: if endpoint == "" { defaults.endpoint } else { endpoint },
    model: if model == "" { defaults.model } else { model },
    api_key: storage_get("sigil.ai.api_key"),
  }
}

///|
fn save_ai_config(config : AiConfig) -> Unit {
  storage_set("sigil.ai.endpoint", config.endpoint)
  storage_set("sigil.ai.model", config.model)
  storage_set("sigil.ai.api_key", config.api_key)
}

///|
fn ai_markup_guide() -> String {
  (
    #|You are the polishing engine for Sigil, a minimal markup language for long-form email.
    #|You receive one existing Sigil email document. Improve it without changing its
    #|facts, asset names, or overall structure, then return exactly the completed
    #|document and nothing else. Do not use Markdown fences, HTML, or commentary.
    #|
    #|YOUR TASK
    #|- Lines whose trimmed text starts with %% are private instructions from the writer.
    #|  They are not email content.
    #|- Apply each %% instruction to the nearby paragraph or to the whole document, then
    #|  remove that %% line from the output.
    #|- If there are no %% lines, polish the entire email: fix grammar, spelling,
    #|  punctuation, clarity, flow, and tone while preserving the writer's voice,
    #|  meaning, and layout.
    #|- Never leave %% markers or instruction text in the returned document.
    #|- Do not add a Subject line or commentary.
    #|
    #|DOCUMENT SHAPE
    #|- Optional header directives come first, one per line:
    #|  @theme #2563EB
    #|  @footer legal
    #|  @split wave
    #|  @letter card
    #|  @palette ocean
    #|- A blank line separates the header from the body.
    #|- Body paragraphs are separated by blank lines. Consecutive lines in one
    #|  paragraph are joined into a single line.
    #|- A line containing only --- is a divider.
    #|
    #|CRITICAL FORMAT RULES
    #|- Sigil is not Markdown. Never output Markdown headings, Markdown tables,
    #|  HTML, or fenced code blocks. The only allowed triple-backtick block is the
    #|  Sigil translation/summary block at the very end of the email. It is rendered
    #|  as neutral gray text, not as code.
    #|- Never draw a table with |, -, +, or grid characters. There is no inline
    #|  table syntax in Sigil.
    #|- A valid answer starts with header directives such as @theme, or with the
    #|  first body paragraph. Do not add any preamble or explanation.
    #|
    #|INLINE
    #|- *strong* produces bold text at the same size.
    #|- **big** produces bold, larger text.
    #|- There is no italic, underline, strikethrough, nested emphasis, or triple emphasis.
    #|- <icon:name> inserts a built-in icon. Choose only from: mail, phone, location,
    #|  user, clock, globe, link, external-link, arrow-right, file, download, folder,
    #|  copy, trash, calendar, send, reply, forward, attach, share, github, linkedin,
    #|  twitter, instagram, facebook, youtube, check, info, alert, star, heart, bell,
    #|  bookmark, flag, tag, lock, unlock, key, camera, image, video, music, mic, home,
    #|  map, search, edit, refresh, settings, gift, credit-card.
    #|- <link:https://example.com> or <link:https://example.com|Read more> creates a link.
    #|  URLs must start with http://, https://, or mailto:.
    #|
    #|BLOCKS (each must occupy its own line)
    #|- <sig:classic> inserts the writer's signature. Use it at most once.
    #|  Allowed ids: classic, minimal, academic, compact.
    #|- <image:NAME> inserts an image from the current email library.
    #|- <table:NAME> inserts a CSV table from the current email library. There is
    #|  no inline table syntax, so a table must use this exact form.
    #|- <chart:NAME> inserts a chart from the current email library.
    #|- A pair of $$ lines encloses one block formula. Inline formulas are not allowed.
    #|- A chart may also be written inline:
    #|  :::chart bar
    #|  title: Monthly growth
    #|  labels: A, B, C
    #|  series: North = 10, 20, 30
    #|  :::
    #|  Chart kinds: bar, stacked, line, area, pie, donut, scatter, radar, heatmap.
    #|- A translation/summary block starts and ends with a line of three backticks.
    #|  It is a dedicated neutral-gray style for the translation or summary at the
    #|  end of the email, not a code block. It must be the final block.
    #|
    #|LISTS
    #|- Only one level is allowed. Use "- item" for unordered lists or "1. item" for
    #|  ordered lists. Never mix the two kinds in one block.
    #|- Use at least 2 items. Keep each item between 4 and 34 display columns, and keep
    #|  item lengths within 20 columns of each other.
    #|
    #|ASSETS
    #|- Only use asset names from the inventory below. Never invent image, table, or
    #|  chart names.
    #|- If the email does not need an asset, omit it rather than fabricating one.
    #|
    #|POLISHING
    #|- Preserve the email's existing structure, length, facts, and asset names unless a
    #|  %% instruction explicitly asks for a change.
    #|- Improve grammar, spelling, punctuation, clarity, flow, and tone.
    #|- Keep the existing language; do not translate unless a %% instruction asks for it.
    #|- Every polished document must end with the translation/summary block.
    #|  If one already exists, keep it as the final block and preserve its line breaks.
    #|  Never move it earlier or convert it to Markdown.
    #|- If the block is missing, add a concise translation summary at the end. Use the
    #|  other language when the email is clearly Chinese or English; otherwise use the
    #|  email's language.
    #|- Use one accent color and restrained formatting. Use *strong* sparingly.
    #|- Do not add a Subject line: the document is the email body markup.
    #|
    #|EXAMPLE
    #|@theme #2563EB
    #|@footer legal
    #|@split wave
    #|@letter card
    #|
    #|Hello Ada,
    #|
    #|Thank you for reviewing the draft. The **main takeaway** is that the launch is
    #|on track, with *one dependency* still open.
    #|
    #|---
    #|
    #|Next steps:
    #|
    #|1. Confirm the release date.
    #|2. Share the final checklist.
    #|
    #|<sig:classic>
    #|
    #|```
    #|Translation / 翻译摘要: 感谢你审阅草稿。发布按计划推进，仍需确认一个依赖项。
    #|```
  )
}

///|
fn ai_asset_inventory(model : Model) -> String {
  let library = match active_document(model) {
    Some(document) => library_for_document(model, document.id)
    None => library_for_document(model, model.library_doc_id)
  }
  let lines : Array[String] = [
    "ASSET INVENTORY FOR THE CURRENT EMAIL",
    "Use these exact names. Never invent assets.",
    "",
    "Images (insert as <image:NAME>):",
  ]
  if library.images.is_empty() {
    lines.push("- none")
  } else {
    for asset in library.images {
      lines.push("- " + asset.name)
    }
  }
  lines.push("")
  lines.push("Tables (insert as <table:NAME>):")
  if library.tables.is_empty() {
    lines.push("- none")
  } else {
    for table in library.tables {
      let (rows, columns) = @render.csv_dimensions(table.csv)
      lines.push(
        "- " +
        table.name +
        " (" +
        rows.to_string() +
        " rows x " +
        columns.to_string() +
        " columns)",
      )
    }
  }
  lines.push("")
  lines.push("Charts (insert as <chart:NAME>):")
  if library.charts.is_empty() {
    lines.push("- none")
  } else {
    for chart in library.charts {
      lines.push("- " + chart.name + " (" + chart.kind + " chart)")
    }
  }
  lines.join("\n")
}

///|
fn ai_document_lang(document : EmailDoc) -> String {
  match @parser.parse(document.source).document.lang {
    Some(lang) => lang
    None => "unknown"
  }
}

///|
fn ai_system_prompt(model : Model, document : EmailDoc) -> String {
  let memory = ai_memory_section(model.ai_memory)
  let lang = ai_document_lang(document)
  let lang_note = if lang == "zh" {
    "The document is declared Chinese (@lang zh). Keep the body in Chinese and write the translation/summary block in English."
  } else if lang == "en" {
    "The document is declared English (@lang en). Keep the body in English and write the translation/summary block in Chinese."
  } else {
    ""
  }
  let base = ai_markup_guide() + "\n\n" + ai_asset_inventory(model)
  let with_lang = if lang_note == "" {
    base
  } else {
    base + "\n\n" + lang_note
  }
  if memory == "" {
    with_lang
  } else {
    with_lang + "\n\n" + memory
  }
}

///|
fn ai_json_escape(text : String) -> String {
  let builder = StringBuilder()
  for ch in text {
    if ch == '"' {
      builder.write_string("\\\"")
    } else if ch == '\\' {
      builder.write_string("\\\\")
    } else if ch == '\n' {
      builder.write_string("\\n")
    } else if ch == '\r' {
      builder.write_string("\\r")
    } else if ch == '\t' {
      builder.write_string("\\t")
    } else {
      builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn ai_system_message(content : String) -> String {
  "{\"role\":\"system\",\"content\":\"" + ai_json_escape(content) + "\"}"
}

///|
fn ai_user_message(content : String) -> String {
  "{\"role\":\"user\",\"content\":\"" + ai_json_escape(content) + "\"}"
}

///|
fn ai_tool_message(id : String, content : String) -> String {
  "{\"role\":\"tool\",\"tool_call_id\":\"" +
  ai_json_escape(id) +
  "\",\"content\":\"" +
  ai_json_escape(content) +
  "\"}"
}

///|
fn ai_tool_definitions() -> String {
  "[{\"type\":\"function\",\"function\":{\"name\":\"create_table\",\"description\":\"Create a table asset from CSV/JSON data, save it to the library, and return the <table:NAME> reference to place in the email. Use for tabular data.\",\"parameters\":{\"type\":\"object\",\"properties\":{\"data\":{\"type\":\"string\",\"description\":\"CSV or JSON data (array of objects, 2D array, or key/value object).\"}},\"required\":[\"data\"]}}},{\"type\":\"function\",\"function\":{\"name\":\"create_chart\",\"description\":\"Create a chart and return the inline :::chart block to place in the email.\",\"parameters\":{\"type\":\"object\",\"properties\":{\"kind\":{\"type\":\"string\",\"enum\":[\"bar\",\"stacked\",\"line\",\"area\",\"pie\",\"donut\",\"scatter\",\"radar\",\"heatmap\"]},\"data\":{\"type\":\"string\",\"description\":\"CSV or JSON data for the chart.\"}},\"required\":[\"kind\",\"data\"]}}}]"
}

///|
#derive(Eq)
struct AiToolCall {
  id : String
  name : String
  arguments : String
}

///|
/// Parse the JSON array of tool calls returned by the model.
fn ai_parse_tool_calls(tool_calls_json : String) -> Array[AiToolCall] {
  let result : Array[AiToolCall] = []
  let parsed = @json.parse(tool_calls_json) catch { _ => return result }
  match parsed {
    @json.Json::Array(items) =>
      for item in items {
        match item {
          @json.Json::Object(map) => {
            let id = match map.get("id") {
              Some(@json.Json::String(s)) => s
              _ => ""
            }
            let name = match map.get("name") {
              Some(@json.Json::String(s)) => s
              _ => ""
            }
            let arguments = match map.get("arguments") {
              Some(@json.Json::String(s)) => s
              _ => "{}"
            }
            result.push({ id, name, arguments, })
          }
          _ => ()
        }
      }
    _ => ()
  }
  result
}

///|
/// Build the assistant tool-call message plus one tool result per call, to be
/// appended to the running conversation.
fn ai_build_tool_turn(
  calls : Array[AiToolCall],
  results : Array[String],
) -> String {
  let call_json : Array[String] = []
  for call in calls {
    call_json.push(
      "{\"id\":\"" +
      ai_json_escape(call.id) +
      "\",\"type\":\"function\",\"function\":{\"name\":\"" +
      ai_json_escape(call.name) +
      "\",\"arguments\":\"" +
      ai_json_escape(call.arguments) +
      "\"}}",
    )
  }
  let assistant = "{\"role\":\"assistant\",\"content\":null,\"tool_calls\":[" +
    call_json.join(",") +
    "]"
  let builder = StringBuilder()
  builder.write_string(assistant)
  let mut index = 0
  for call in calls {
    let content = if index < results.length() { results[index] } else { "" }
    builder.write_string("," + ai_tool_message(call.id, content))
    index = index + 1
  }
  builder.to_string()
}

///|
fn ai_agent_initial_messages(model : Model, document : EmailDoc) -> String {
  let user_prompt = "Document title: " +
    document.title +
    "\n\nCurrent Sigil source:\n" +
    document.source +
    "\n\nPolish this document according to the rules and apply every %% instruction. If the email needs a table or chart, create it with a tool and place its reference in the final document. Return the complete final Sigil document and nothing else."
  "[" +
  ai_system_message(ai_system_prompt(model, document)) +
  "," +
  ai_user_message(user_prompt) +
  "]"
}

///|
/// Append an assistant tool-call message plus its tool results onto the running
/// message array (a JSON array string).
fn ai_agent_append_tool_turn(messages : String, turn : String) -> String {
  messages[0: messages.length() - 1].to_owned() + "," + turn + "]"
}

///|
fn ai_fenced_body(text : String, start : Int32) -> String {
  let after_open = text[start + 3:].to_owned()
  let body = match after_open.find("\n") {
    Some(newline) => after_open[newline + 1:].to_owned()
    None => after_open
  }
  match body.find("```") {
    Some(close) => body[:close].trim().to_owned()
    None => body.trim().to_owned()
  }
}

///|
fn ai_looks_like_sigil(text : String) -> Bool {
  text.contains("@theme") ||
  text.contains("@footer") ||
  text.contains("@letter") ||
  text.contains("@split") ||
  text.contains("@palette") ||
  text.contains("<sig:") ||
  text.contains("<image:") ||
  text.contains("<table:") ||
  text.contains("<chart:") ||
  text.contains(":::chart") ||
  text.contains("$$")
}

///|
fn ai_is_markdown_output(markup : String) -> Bool {
  let text = markup.trim().to_owned()
  if text == "" || ai_looks_like_sigil(text) {
    return false
  }
  text.contains("|") &&
  (text.contains("---") || text.contains(":--") || text.contains("-|-"))
}

///|
/// Keep only the Sigil markup, dropping optional markdown fences and prose.
fn extract_ai_markup(raw : String) -> String {
  let text = raw.trim().to_owned()
  match text.find("```sigil") {
    Some(start) => return ai_fenced_body(text, start)
    None => ()
  }
  match text.find("```Sigil") {
    Some(start) => return ai_fenced_body(text, start)
    None => ()
  }
  if !text.contains("```") {
    return text
  }
  match text.find("```") {
    Some(start) => {
      let block = ai_fenced_body(text, start)
      if ai_looks_like_sigil(block) {
        block
      } else {
        text.replace_all(old="```", new="").trim().to_owned()
      }
    }
    None => text
  }
}

///|
fn parse_ai_reply(raw : String) -> AiReply {
  let parsed = @json.parse(raw) catch {
    _ => return { ok: false, content: "", tool_calls: "", error: "Invalid response from the model." }
  }
  @json.from_json(parsed) catch {
    _ => { ok: false, content: "", tool_calls: "", error: "Invalid response from the model." }
  }
}

///|
/// Remove any `%%` instruction lines the model forgot to delete.
fn strip_ai_instruction_lines(markup : String) -> String {
  let builder = StringBuilder()
  let mut wrote = false
  for line in markup.split("\n") {
    let text = line.to_owned()
    if text.trim().to_owned().has_prefix("%%") {
      continue
    }
    if wrote {
      builder.write_char('\n')
    }
    builder.write_string(text)
    wrote = true
  }
  builder.to_string().trim().to_owned()
}

///|
extern "js" fn ai_fetch_promise(request_json : String) -> @js_async.Promise[String] =
  #| (requestJson) => new Promise((resolve) => {
  #|   const finish = (ok, content, tool_calls, error) => resolve(JSON.stringify({
  #|     ok: ok,
  #|     content: content || '',
  #|     tool_calls: tool_calls || '',
  #|     error: error || ''
  #|   }));
  #|   let request;
  #|   try {
  #|     request = JSON.parse(requestJson);
  #|   } catch (error) {
  #|     finish(false, '', '', 'Invalid AI request.');
  #|     return;
  #|   }
  #|   const endpoint = String(request.endpoint || '').trim();
  #|   const model = String(request.model || '').trim();
  #|   if (!endpoint) {
  #|     finish(false, '', '', 'Set an API endpoint in Settings.');
  #|     return;
  #|   }
  #|   if (!model) {
  #|     finish(false, '', '', 'Set a model name in Settings.');
  #|     return;
  #|   }
  #|   const headers = { 'Content-Type': 'application/json' };
  #|   if (request.api_key) {
  #|     headers['Authorization'] = 'Bearer ' + request.api_key;
  #|   }
  #|   let messages = [];
  #|   try {
  #|     const raw = request.messages || '[]';
  #|     messages = Array.isArray(raw) ? raw : JSON.parse(raw);
  #|   } catch (error) {
  #|     finish(false, '', '', 'Invalid messages.');
  #|     return;
  #|   }
  #|   let tools = [];
  #|   try {
  #|     const rawTools = request.tools || '[]';
  #|     tools = Array.isArray(rawTools) ? rawTools : JSON.parse(rawTools);
  #|   } catch (error) {
  #|     tools = [];
  #|   }
  #|   const body = {
  #|     model: model,
  #|     messages: messages,
  #|     temperature: typeof request.temperature === 'number' ? request.temperature : 0.4,
  #|     stream: false
  #|   };
  #|   if (tools.length > 0) {
  #|     body.tools = tools;
  #|   }
  #|   fetch(endpoint, {
  #|     method: 'POST',
  #|     headers: headers,
  #|     body: JSON.stringify(body)
  #|   })
  #|     .then(async (response) => {
  #|       const text = await response.text();
  #|       let data = null;
  #|       try {
  #|         data = JSON.parse(text);
  #|       } catch (error) {
  #|         data = null;
  #|       }
  #|       if (!response.ok) {
  #|         let detail = text.slice(0, 400);
  #|         if (data && data.error) {
  #|           detail = data.error.message || String(data.error);
  #|         }
  #|         finish(false, '', '', 'HTTP ' + response.status + ': ' + detail);
  #|         return;
  #|       }
  #|       const choice = data && data.choices && data.choices[0];
  #|       const message = choice && choice.message;
  #|       const tool_calls = message && Array.isArray(message.tool_calls) ? message.tool_calls : [];
  #|       if (tool_calls.length > 0) {
  #|         const normalized = tool_calls.map((tc) => ({
  #|           id: tc.id || ('call_' + Math.random().toString(36).slice(2)),
  #|           name: (tc.function && tc.function.name) || '',
  #|           arguments: (tc.function && tc.function.arguments) || '{}'
  #|         }));
  #|         finish(true, '', JSON.stringify(normalized), '');
  #|         return;
  #|       }
  #|       let content = message && message.content;
  #|       if (Array.isArray(content)) {
  #|         content = content.map((part) => {
  #|           if (typeof part === 'string') return part;
  #|           return part && part.text ? part.text : '';
  #|         }).join('');
  #|       }
  #|       if (typeof content !== 'string' || content.trim() === '') {
  #|         finish(false, '', '', 'The model returned an empty response.');
  #|         return;
  #|       }
  #|       finish(true, content, '', '');
  #|     })
  #|     .catch((error) => {
  #|       const message = error && error.message ? error.message : String(error);
  #|       finish(false, '', '', 'Network error: ' + message);
  #|     });
  #| })

///|
/// Read the pending agent conversation and send one round to the model.
async fn ai_agent_task() -> String noraise {
  let messages = storage_get("sigil.ai.messages")
  if messages == "" {
    return "{\"ok\":false,\"content\":\"\",\"tool_calls\":\"\",\"error\":\"No AI request is pending.\"}"
  }
  let endpoint = storage_get("sigil.ai.endpoint")
  let model = storage_get("sigil.ai.model")
  let api_key = storage_get("sigil.ai.api_key")
  let request = "{\"endpoint\":\"" +
    ai_json_escape(endpoint) +
    "\",\"api_key\":\"" +
    ai_json_escape(api_key) +
    "\",\"model\":\"" +
    ai_json_escape(model) +
    "\",\"temperature\":0.4,\"messages\":" +
    messages +
    ",\"tools\":" +
    ai_tool_definitions() +
    "}"
  @js_async.run_promise(_ => ai_fetch_promise(request)) catch {
    _ => "{\"ok\":false,\"content\":\"\",\"tool_calls\":\"\",\"error\":\"AI request failed.\"}"
  }
}
