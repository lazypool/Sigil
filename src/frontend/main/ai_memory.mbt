///|
/// One entry in the local AI-memory store: a writer preference, fact, or note.
#derive(Eq, ToJson, FromJson)
struct AiMemoryEntry {
  key : String
  value : String
  kind : String
  updated : Int64
}

///|
/// Local-only writer preferences, facts, and notes available to the AI flow.
#derive(Eq, ToJson, FromJson)
struct AiMemory {
  entries : Array[AiMemoryEntry]
}

///|
/// Single storage key holding the whole memory list as one JSON document.
let ai_memory_storage_key = "sigil.ai.memory"

///|
extern "js" fn now_ms() -> Int64 = "() => Date.now()"

///|
fn default_ai_memory() -> AiMemory {
  { entries: [] }
}

///|
fn normalize_ai_memory_kind(kind : String) -> String {
  match kind {
    "preference" => "preference"
    "fact" => "fact"
    "note" => "note"
    _ => "note"
  }
}

///|
fn load_ai_memory() -> AiMemory {
  let raw = storage_get(ai_memory_storage_key)
  if raw == "" {
    return default_ai_memory()
  }
  let parsed = @json.parse(raw) catch { _ => return default_ai_memory() }
  let memory : AiMemory = @json.from_json(parsed) catch {
    _ => return default_ai_memory()
  }
  memory
}

///|
fn save_ai_memory(memory : AiMemory) -> Unit {
  storage_set(
    ai_memory_storage_key,
    @json.ToJson::to_json(memory).stringify(),
  )
}

///|
fn ai_memory_put(
  memory : AiMemory,
  key : String,
  value : String,
  kind : String,
) -> AiMemory {
  let normalized_kind = normalize_ai_memory_kind(kind)
  let updated = now_ms()
  let entries : Array[AiMemoryEntry] = []
  let mut replaced = false
  for entry in memory.entries {
    if entry.key == key {
      entries.push({ key, value, kind: normalized_kind, updated })
      replaced = true
    } else {
      entries.push(entry)
    }
  }
  if !replaced {
    entries.push({ key, value, kind: normalized_kind, updated })
  }
  { entries, }
}

///|
fn ai_memory_forget(memory : AiMemory, key : String) -> AiMemory {
  let entries : Array[AiMemoryEntry] = []
  for entry in memory.entries {
    if entry.key != key {
      entries.push(entry)
    }
  }
  { entries, }
}

///|
fn ai_memory_clear() -> AiMemory {
  storage_remove(ai_memory_storage_key)
  default_ai_memory()
}

///|
/// Stable plain-text fragment that other AI flows may append to their system
/// prompt. Empty memory yields an empty string.
pub fn ai_memory_section(memory : AiMemory) -> String {
  if memory.entries.is_empty() {
    return ""
  }
  let lines : Array[String] = []
  lines.push("WRITER PREFERENCES AND FACTS")
  for entry in memory.entries {
    lines.push("- " + entry.kind + ": " + entry.key + " = " + entry.value)
  }
  lines.join("\n")
}

///|
fn ai_memory_settings_section(emit : Emit[Msg], model : Model) -> Html {
  let rows : Array[Html] = []
  for entry in model.ai_memory.entries {
    rows.push(
      div(class="sigil-settings-row", [
        div(class="sigil-settings-copy", [
          span(class="sigil-settings-title", entry.key),
          span(
            class="sigil-settings-description",
            entry.kind + ": " + entry.value,
          ),
        ]),
        button(
          type_="button",
          class="sigil-button is-small is-danger",
          on_click=emit(AiMemoryForget(entry.key)),
          tr(model.lang, "Delete", "删除"),
        ),
      ]),
    )
  }
  let entries_view = if rows.is_empty() {
    div(
      class="sigil-settings-description",
      tr(model.lang, "No memories saved.", "尚未保存任何记忆。"),
    )
  } else {
    div(rows)
  }
  div(class="sigil-settings-section", [
    div(class="sigil-settings-row", [
      div(class="sigil-settings-copy", [
        span(
          class="sigil-settings-title",
          tr(model.lang, "AI memory", "AI 记忆"),
        ),
        span(
          class="sigil-settings-description",
          tr(
            model.lang,
            "Writing preferences, facts, and notes stored only in this browser and shared with the AI polish prompt.",
            "写作偏好、事实与备注仅保存在此浏览器中，并用于 AI 润色提示词。",
          ),
        ),
      ]),
      if model.ai_memory.entries.is_empty() {
        @html.nothing
      } else {
        button(
          type_="button",
          class="sigil-button is-small",
          on_click=emit(AiMemoryClear),
          tr(model.lang, "Clear all", "全部清空"),
        )
      },
    ]),
    entries_view,
    div(class="sigil-field-grid", [
      label(class="sigil-field", [
        span(class="sigil-field-label", tr(model.lang, "Key", "键")),
        input(
          input_type=@html.InputType::Text,
          class="sigil-field-input",
          value=model.ai_memory_key,
          placeholder=tr(model.lang, "e.g. tone", "例如：语气"),
          on_input=emit.map(key => AiMemoryKeyChanged(key)),
        ),
      ]),
      label(class="sigil-field", [
        span(class="sigil-field-label", tr(model.lang, "Value", "值")),
        input(
          input_type=@html.InputType::Text,
          class="sigil-field-input",
          value=model.ai_memory_value,
          placeholder=tr(model.lang, "e.g. concise", "例如：简洁"),
          on_input=emit.map(value => AiMemoryValueChanged(value)),
        ),
      ]),
      label(class="sigil-field", [
        span(class="sigil-field-label", tr(model.lang, "Kind", "类型")),
        input(
          input_type=@html.InputType::Text,
          class="sigil-field-input",
          value=model.ai_memory_kind,
          placeholder="preference / fact / note",
          on_input=emit.map(kind => AiMemoryKindChanged(kind)),
        ),
      ]),
    ]),
    div(class="sigil-profile-actions", [
      button(
        type_="button",
        class="sigil-button is-primary",
        on_click=emit(AiMemoryAdd),
        tr(model.lang, "Add memory", "添加记忆"),
      ),
    ]),
  ])
}
