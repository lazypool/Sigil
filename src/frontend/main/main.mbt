///|
using @rabbita {type Cmd, type Emit, type Html}

///|
using @html {
  button,
  div,
  footer,
  header,
  iframe,
  img,
  input,
  label,
  span,
  textarea,
}

///|
#derive(Eq)
enum PreviewKind {
  NoPreview
  ImagePreview
  TablePreview
  ChartPreview
}

///|
#derive(Eq)
struct Model {
  documents : Array[EmailDoc]
  assets : Array[ImageAsset]
  tables : Array[TableAsset]
  charts : Array[ChartAsset]
  library_doc_id : String
  import_doc_id : String
  preview_kind : PreviewKind
  preview_doc_id : String
  preview_item_id : String
  table_draft : String
  chart_kind_draft : String
  chart_text_draft : String
  workspace_preview_kind : PreviewKind
  workspace_preview_doc_id : String
  workspace_preview_item_id : String
  pending_delete_doc_id : String
  table_notice : String
  open_tabs : Array[String]
  active_tab : String
  split_pct : Double
  dragging : Bool
  sidebar_open : Bool
  profile : Profile
  profile_draft : Profile
  lang : Lang
  prefs : Prefs
  ai : AiConfig
  ai_target_doc_id : String
  ai_error : String
  ai_status : AiStatus
  ai_asset_status : AiStatus
  ai_asset_error : String
  ai_asset_prompt : String
  ai_asset_target_doc_id : String
  style_view : StyleKind
  style_doc_id : String
  mail : MailForm
  mail_notice : String
  mail_notice_ok : Bool
  mail_advanced_open : Bool
  mail_test_to : String
  send_open : Bool
  send_to : String
  send_subject : String
  send_busy : Bool
  send_notice : String
  send_notice_ok : Bool
}

///|
enum Msg {
  SourceChanged(String)
  RenameDocument(String)
  BeginDrag
  DragMoved(Double)
  EndDrag
  SelectTab(String)
  OpenDocument(String)
  CloseTab(String)
  RequestDeleteDocument(String)
  CancelDeleteDocument
  NewDocument
  ToggleSidebar
  OpenProfile
  OpenImages
  RevertProfile
  ProfileFieldChanged(ProfileField, String)
  SaveProfile
  ImportImages
  PrepareImageImport(String)
  AssetsImported(String)
  InsertAsset(String, String)
  DeleteAsset(String, String)
  OpenImagePreview(String, String)
  OpenWorkspaceImagePreview(String, String)
  CloseWorkspacePreview
  ClosePreview
  DeleteDocument(String)
  OpenTables
  ImportTables
  PrepareTableImport(String)
  TablesImported(String)
  InsertTable(String, String)
  DeleteTable(String, String)
  OpenTablePreview(String, String)
  OpenWorkspaceTablePreview(String, String)
  EditTableCell(Int32, Int32, String)
  AddTableRow
  AddTableColumn
  DismissTableNotice
  OpenCharts
  ImportCharts
  PrepareChartImport(String)
  ChartsImported(String)
  InsertChart(String, String)
  DeleteChart(String, String)
  OpenChartPreview(String, String)
  OpenWorkspaceChartPreview(String, String)
  NewChart(String)
  EditChartKind(String)
  EditChartText(String)
  ToggleLanguage
  OpenSettings
  SetTheme(AppTheme)
  SetAccent(String)
  SetDensity(Density)
  SetEditorFontSize(Int32)
  ResetPrefs
  SetLang(Lang)
  SetAiEndpoint(String)
  SetAiModel(String)
  SetAiApiKey(String)
  PolishAiEmail
  AiEmailPolished(String)
  GenerateAiAsset
  AiAssetPromptChanged(String)
  AiAssetGenerated(String)
  ImportAvatar
  AvatarImported(String)
  RemoveAvatar
  OpenStyles
  SelectStyleKind(StyleKind)
  ApplyStyle(String)
  OpenSend
  CloseSend
  SendToChanged(String)
  SendSubjectChanged(String)
  BeginSend
  SendFinished(String)
  OpenDeliverySettings
  MailLoaded(String)
  MailFieldChanged(MailField, String)
  SaveMailSettings
  MailSaved(String)
  TestMailSettings
  MailTested(String)
  MailTestToChanged(String)
  ToggleMailAdvanced
  CopyMailHelpLink
}

///|
fn initial_model() -> Model {
  clear_legacy_libraries()
  let lang = load_lang()
  let workspace = load_workspace(lang)
  let profile = load_profile()
  let stored_context = load_library_context()
  let library_doc_id = if
    find_document(workspace.documents, workspace.active_tab) is Some(_) {
    workspace.active_tab
  } else if stored_context != "" &&
    find_document(workspace.documents, stored_context) is Some(_) {
    stored_context
  } else {
    library_context_id(
      workspace.documents,
      workspace.active_tab,
      workspace.open_tabs,
    )
  }
  let library = load_library(library_doc_id)
  save_library_context(library_doc_id)
  let style_doc_id = match
    find_document(workspace.documents, workspace.active_tab) {
    Some(document) => document.id
    None =>
      if workspace.documents.is_empty() {
        ""
      } else {
        workspace.documents[0].id
      }
  }
  {
    documents: workspace.documents,
    assets: library.images,
    tables: library.tables,
    charts: library.charts,
    library_doc_id,
    import_doc_id: "",
    preview_kind: NoPreview,
    preview_doc_id: "",
    preview_item_id: "",
    table_draft: "",
    chart_kind_draft: "",
    chart_text_draft: "",
    workspace_preview_kind: NoPreview,
    workspace_preview_doc_id: "",
    workspace_preview_item_id: "",
    pending_delete_doc_id: "",
    table_notice: "",
    open_tabs: workspace.open_tabs,
    active_tab: workspace.active_tab,
    split_pct: workspace.split_pct,
    dragging: false,
    sidebar_open: workspace.sidebar_open,
    profile,
    profile_draft: profile,
    lang,
    prefs: load_prefs(),
    ai: load_ai_config(),
    ai_target_doc_id: "",
    ai_error: "",
    ai_status: AiIdle,
    ai_asset_status: AiIdle,
    ai_asset_error: "",
    ai_asset_prompt: "",
    ai_asset_target_doc_id: "",
    style_view: LetterStyle,
    style_doc_id,
    mail: default_mail_form(),
    mail_notice: "",
    mail_notice_ok: false,
    mail_advanced_open: false,
    mail_test_to: "",
    send_open: false,
    send_to: "",
    send_subject: "",
    send_busy: false,
    send_notice: "",
    send_notice_ok: false,
  }
}

///|
fn persist(model : Model) -> Unit {
  save_workspace({
    documents: model.documents,
    open_tabs: model.open_tabs,
    active_tab: model.active_tab,
    split_pct: model.split_pct,
    sidebar_open: model.sidebar_open,
    folders: [],
    image_folder: "",
  })
}

///|
fn active_document(model : Model) -> EmailDoc? {
  find_document(model.documents, model.active_tab)
}

///|
fn active_source(model : Model) -> String {
  match active_document(model) {
    Some(document) => document.source
    None => ""
  }
}

///|
fn without_previews(model : Model) -> Model {
  {
    ..model,
    preview_kind: NoPreview,
    preview_doc_id: "",
    preview_item_id: "",
    table_draft: "",
    chart_kind_draft: "",
    chart_text_draft: "",
    workspace_preview_kind: NoPreview,
    workspace_preview_doc_id: "",
    workspace_preview_item_id: "",
  }
}

///|
fn truncate_text(value : String, max_chars : Int32) -> String {
  let builder = StringBuilder()
  let mut count = 0
  for ch in value {
    if count >= max_chars {
      break
    }
    builder.write_char(ch)
    count = count + 1
  }
  builder.to_string()
}

///|
fn clamp_split(pct : Double) -> Double {
  if pct < 24.0 {
    24.0
  } else if pct > 76.0 {
    76.0
  } else {
    pct
  }
}

///|
fn split_at(client_x : Double) -> Double {
  let width = @dom.window().inner_width()
  let pct = if width <= 0.0 { 58.0 } else { client_x / width * 100.0 }
  clamp_split(pct)
}

///|
fn update(model : Model, msg : Msg, emit : Emit[Msg]) -> (Model, Cmd) {
  match msg {
    SourceChanged(source) => {
      let next = {
        ..model,
        documents: with_document_source(
          model.documents,
          model.active_tab,
          source,
        ),
        ai_status: if model.ai_status is AiLoading {
          AiLoading
        } else {
          AiIdle
        },
        ai_error: if model.ai_status is AiLoading { model.ai_error } else { "" },
      }
      persist(next)
      (next, @rabbita.none)
    }
    RenameDocument(title) => {
      let next = {
        ..model,
        documents: with_document_title(model.documents, model.active_tab, title),
      }
      persist(next)
      (next, @rabbita.none)
    }
    BeginDrag => ({ ..model, dragging: true, }, @rabbita.none)
    DragMoved(client_x) =>
      if model.dragging {
        ({ ..model, split_pct: split_at(client_x), }, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    EndDrag => ({ ..model, dragging: false, }, @rabbita.none)
    SelectTab(id) =>
      if contains_id(model.open_tabs, id) {
        let base = if find_document(model.documents, id) is Some(_) {
          without_previews({ ..model, active_tab: id })
        } else {
          { ..model, active_tab: id }
        }
        let next = if id != model.library_doc_id &&
          find_document(model.documents, id) is Some(_) {
          switch_library(base, id)
        } else {
          base
        }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    OpenDocument(id) => {
      let valid = id == profile_tab_id ||
        id == images_tab_id ||
        id == tables_tab_id ||
        id == charts_tab_id ||
        id == settings_tab_id ||
        id == styles_tab_id ||
        find_document(model.documents, id) is Some(_)
      if valid {
        let base = {
          ..model,
          open_tabs: ensure_tab(model.open_tabs, id),
          active_tab: id,
        }
        let base = if find_document(model.documents, id) is Some(_) {
          without_previews(base)
        } else {
          base
        }
        let next = if id != model.library_doc_id &&
          find_document(model.documents, id) is Some(_) {
          switch_library(base, id)
        } else {
          base
        }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    }
    CloseTab(id) => {
      let open_tabs = remove_tab(model.open_tabs, id)
      let active_tab = if model.active_tab == id {
        if open_tabs.is_empty() {
          ""
        } else {
          open_tabs[open_tabs.length() - 1]
        }
      } else {
        model.active_tab
      }
      let base = { ..model, open_tabs, active_tab, }
      let next = if active_tab != model.active_tab &&
        find_document(model.documents, active_tab) is Some(_) &&
        active_tab != model.library_doc_id {
        switch_library(base, active_tab)
      } else {
        base
      }
      persist(next)
      (next, @rabbita.none)
    }
    NewDocument => {
      let document = new_document(
        next_document_title(model.documents, model.lang),
        model.lang,
      )
      let documents = model.documents.copy()
      documents.push(document)
      save_active_library(model)
      let base = {
        ..model,
        documents,
        open_tabs: ensure_tab(model.open_tabs, document.id),
        active_tab: document.id,
      }
      let next = model_with_library(base, document.id, empty_library())
      let next = without_previews(next)
      persist(next)
      (next, @rabbita.none)
    }
    ToggleSidebar => {
      let next = { ..model, sidebar_open: !model.sidebar_open, }
      persist(next)
      (next, @rabbita.none)
    }
    OpenProfile => {
      let next = {
        ..model,
        open_tabs: ensure_tab(model.open_tabs, profile_tab_id),
        active_tab: profile_tab_id,
        profile_draft: model.profile,
      }
      persist(next)
      (next, @rabbita.none)
    }
    OpenImages => {
      let next = {
        ..model,
        open_tabs: ensure_tab(model.open_tabs, images_tab_id),
        active_tab: images_tab_id,
      }
      persist(next)
      (next, @rabbita.none)
    }
    RevertProfile => ({ ..model, profile_draft: model.profile, }, @rabbita.none)
    ProfileFieldChanged(field, value) =>
      (
        {
          ..model,
          profile_draft: model.profile_draft.with_field(field, value),
        },
        @rabbita.none,
      )
    SaveProfile => {
      save_profile(model.profile_draft)
      ({ ..model, profile: model.profile_draft, }, @rabbita.none)
    }
    OpenSettings => {
      let next = {
        ..model,
        open_tabs: ensure_tab(model.open_tabs, settings_tab_id),
        active_tab: settings_tab_id,
      }
      persist(next)
      (
        next,
        @rabbita.perform(data => emit(MailLoaded(data)), load_mail_task),
      )
    }
    OpenSend => {
      let subject = match active_document(model) {
        Some(document) => document.title
        None => ""
      }
      let next = {
        ..model,
        send_open: true,
        send_subject: subject,
        send_notice: "",
        send_notice_ok: false,
        send_busy: false,
      }
      (
        next,
        @rabbita.perform(data => emit(MailLoaded(data)), load_mail_task),
      )
    }
    CloseSend => (
      {
        ..model,
        send_open: false,
        send_busy: false,
        send_notice: "",
        send_notice_ok: false,
      },
      @rabbita.none,
    )
    SendToChanged(value) => ({ ..model, send_to: value, }, @rabbita.none)
    SendSubjectChanged(value) =>
      ({ ..model, send_subject: value, }, @rabbita.none)
    BeginSend =>
      match active_document(model) {
        None => (model, @rabbita.none)
        Some(document) => {
          let recipients = parse_recipients(model.send_to)
          let subject = model.send_subject.trim().to_owned()
          let result = @parser.parse(document.source)
          let mut has_errors = false
          for diagnostic in result.diagnostics {
            if diagnostic.severity is @types.Error {
              has_errors = true
            }
          }
          let notice = if recipients is None {
            tr(
              model.lang,
              "Add at least one valid recipient.",
              "请填写至少一个有效收件人。",
            )
          } else if subject == "" {
            tr(model.lang, "Add a subject.", "请填写邮件主题。")
          } else if has_errors {
            tr(
              model.lang,
              "Fix the errors in this email before sending.",
              "请先修复邮件中的错误再发送。",
            )
          } else if !model.mail.api_key_set ||
            model.mail.from_address.trim() == "" {
            tr(
              model.lang,
              "Configure mail delivery before sending.",
              "请先完成邮件发送设置。",
            )
          } else {
            ""
          }
          if notice != "" {
            (
              { ..model, send_notice: notice, send_notice_ok: false },
              @rabbita.none,
            )
          } else {
            let (html, _) = render_source(model, document)
            let next = {
              ..model,
              send_busy: true,
              send_notice: "",
              send_notice_ok: false,
            }
            (
              next,
              @rabbita.perform(data => emit(SendFinished(data)), async fn() -> String noraise {
                send_mail_task(html, model.send_to, subject)
              }),
            )
          }
        }
      }
    SendFinished(json) => {
      let (ok, message) = parse_send_reply(json)
      (
        {
          ..model,
          send_busy: false,
          send_notice: message,
          send_notice_ok: ok,
        },
        @rabbita.none,
      )
    }
    OpenDeliverySettings => {
      let next = {
        ..model,
        send_open: false,
        send_busy: false,
        send_notice_ok: false,
        open_tabs: ensure_tab(model.open_tabs, settings_tab_id),
        active_tab: settings_tab_id,
      }
      persist(next)
      (
        next,
        @rabbita.perform(data => emit(MailLoaded(data)), load_mail_task),
      )
    }
    MailLoaded(json) => {
      let loaded = parse_mail_settings(json)
      let suggestion = profile_delivery_email(model.profile)
      let mail = {
        ..loaded,
        from_name: if loaded.from_name == "" && suggestion != "" {
          model.profile.name
        } else {
          loaded.from_name
        },
        from_address: if loaded.from_address == "" {
          suggestion
        } else {
          loaded.from_address
        },
      }
      (
        {
          ..model,
          mail,
          mail_notice: "",
          mail_notice_ok: false,
          mail_test_to: if model.mail_test_to == "" {
            suggestion
          } else {
            model.mail_test_to
          },
        },
        @rabbita.none,
      )
    }
    MailFieldChanged(field, value) =>
      (
        {
          ..model,
          mail: model.mail.with_field(field, value),
          mail_notice: "",
          mail_notice_ok: false,
        },
        @rabbita.none,
      )
    SaveMailSettings => {
      let payload = mail_update_json(model.mail)
      (
        {
          ..model,
          mail_notice: tr(model.lang, "Saving...", "保存中..."),
          mail_notice_ok: false,
        },
        @rabbita.perform(data => emit(MailSaved(data)), async fn() -> String noraise {
          save_mail_task(payload)
        }),
      )
    }
    MailSaved(json) => {
      let (ok, message, api_key_set) = parse_save_reply(json)
      let mail = if ok {
        { ..model.mail, api_key: "", api_key_set, }
      } else {
        { ..model.mail, api_key_set, }
      }
      (
        { ..model, mail, mail_notice: message, mail_notice_ok: ok },
        @rabbita.none,
      )
    }
    TestMailSettings => {
      let test_to = model.mail_test_to.trim().to_owned()
      if test_to == "" || !test_to.contains("@") {
        (
          {
            ..model,
            mail_notice: tr(
              model.lang,
              "Enter a test recipient email address.",
              "请填写测试收件邮箱。",
            ),
            mail_notice_ok: false,
          },
          @rabbita.none,
        )
      } else {
        let payload = test_mail_json(model.mail, test_to)
        (
          {
            ..model,
            mail_notice: tr(
              model.lang,
              "Saving and sending a test email...",
              "正在保存并发送测试邮件...",
            ),
            mail_notice_ok: false,
          },
          @rabbita.perform(data => emit(MailTested(data)), async fn() -> String noraise {
            test_mail_task(payload)
          }),
        )
      }
    }
    MailTestToChanged(value) =>
      (
        { ..model, mail_test_to: value },
        @rabbita.none,
      )
    MailTested(json) => {
      let (ok, message, api_key_set) = parse_save_reply(json)
      let mail = if ok {
        { ..model.mail, api_key: "", api_key_set, }
      } else {
        { ..model.mail, api_key_set, }
      }
      (
        { ..model, mail, mail_notice: message, mail_notice_ok: ok },
        @rabbita.none,
      )
    }
    ToggleMailAdvanced =>
      (
        { ..model, mail_advanced_open: !model.mail_advanced_open },
        @rabbita.none,
      )
    CopyMailHelpLink => {
      copy_text(help_link(model.mail.provider))
      (
        {
          ..model,
          mail_notice: tr(model.lang, "Link copied.", "链接已复制。"),
          mail_notice_ok: true,
        },
        @rabbita.none,
      )
    }
    SetTheme(theme) => {
      let prefs = { ..model.prefs, theme, }
      save_prefs(prefs)
      ({ ..model, prefs, }, @rabbita.none)
    }
    SetAccent(accent) => {
      let prefs = { ..model.prefs, accent: valid_accent(accent), }
      save_prefs(prefs)
      ({ ..model, prefs, }, @rabbita.none)
    }
    SetDensity(density) => {
      let prefs = { ..model.prefs, density, }
      save_prefs(prefs)
      ({ ..model, prefs, }, @rabbita.none)
    }
    SetEditorFontSize(size) => {
      let prefs = { ..model.prefs, editor_font_size: size, }
      save_prefs(prefs)
      ({ ..model, prefs, }, @rabbita.none)
    }
    ResetPrefs => {
      let prefs = default_prefs()
      save_prefs(prefs)
      ({ ..model, prefs, }, @rabbita.none)
    }
    SetLang(lang) => {
      save_lang(lang)
      ({ ..model, lang, }, @rabbita.none)
    }
    SetAiEndpoint(endpoint) => {
      let ai = { ..model.ai, endpoint, }
      save_ai_config(ai)
      ({ ..model, ai, }, @rabbita.none)
    }
    SetAiModel(model_name) => {
      let ai = { ..model.ai, model: model_name, }
      save_ai_config(ai)
      ({ ..model, ai, }, @rabbita.none)
    }
    SetAiApiKey(api_key) => {
      let ai = { ..model.ai, api_key, }
      save_ai_config(ai)
      ({ ..model, ai, }, @rabbita.none)
    }
    PolishAiEmail => {
      match active_document(model) {
        None =>
          (
            {
              ..model,
              ai_status: AiError,
              ai_error: tr(
                model.lang,
                "Open an email before polishing.",
                "请先打开一封邮件，再进行润色。",
              ),
            },
            @rabbita.none,
          )
        Some(document) =>
          if model.ai_status is AiLoading {
            (model, @rabbita.none)
          } else if model.ai.endpoint.trim() == "" ||
            model.ai.model.trim() == "" {
            (
              {
                ..model,
                ai_status: AiError,
                ai_error: tr(
                  model.lang,
                  "Set the AI endpoint and model in Settings.",
                  "请先在设置中填写 AI 接口和模型。",
                ),
              },
              @rabbita.none,
            )
          } else {
            let request = ai_build_request(model, document)
            storage_set(
              "sigil.ai.pending",
              @json.ToJson::to_json(request).stringify(),
            )
            (
              {
                ..model,
                ai_target_doc_id: document.id,
                ai_status: AiLoading,
                ai_error: "",
              },
              @rabbita.perform(
                json => emit(AiEmailPolished(json)),
                ai_compose_task,
              ),
            )
          }
      }
    }
    AiEmailPolished(json) => {
      let reply = parse_ai_reply(json)
      if !reply.ok {
        (
          {
            ..model,
            ai_status: AiError,
            ai_error: reply.error,
          },
          @rabbita.none,
        )
      } else {
        let markup = strip_ai_instruction_lines(
          extract_ai_markup(reply.content),
        )
        if markup == "" || ai_is_markdown_output(markup) {
          (
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
        } else {
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
                documents: with_document_source(
                  model.documents,
                  document.id,
                  markup,
                ),
                ai_status: AiDone,
                ai_error: "",
              }
              persist(next)
              (next, @rabbita.none)
            }
          }
        }
      }
    }
    GenerateAiAsset => {
      match active_document(model) {
        None =>
          (
            {
              ..model,
              ai_asset_status: AiError,
              ai_asset_error: tr(
                model.lang,
                "Open an email before generating an asset.",
                "请先打开一封邮件，再生成图表或表格。",
              ),
            },
            @rabbita.none,
          )
        Some(document) =>
          if model.ai_asset_status is AiLoading {
            (model, @rabbita.none)
          } else if model.ai.endpoint.trim() == "" ||
            model.ai.model.trim() == "" {
            (
              {
                ..model,
                ai_asset_status: AiError,
                ai_asset_error: tr(
                  model.lang,
                  "Set the AI endpoint and model in Settings.",
                  "请先在设置中填写 AI 接口和模型。",
                ),
              },
              @rabbita.none,
            )
          } else if model.ai_asset_prompt.trim() == "" {
            (
              {
                ..model,
                ai_asset_status: AiError,
                ai_asset_error: tr(
                  model.lang,
                  "Describe the chart or table you want, or paste JSON/CSV.",
                  "请描述你想要的图表或表格，或粘贴 JSON/CSV。",
                ),
              },
              @rabbita.none,
            )
          } else {
            let request = ai_asset_build_request(
              model,
              document,
              model.ai_asset_prompt,
            )
            storage_set(
              "sigil.ai.assets.pending",
              @json.ToJson::to_json(request).stringify(),
            )
            (
              {
                ..model,
                ai_asset_target_doc_id: document.id,
                ai_asset_status: AiLoading,
                ai_asset_error: "",
              },
              @rabbita.perform(
                json => emit(AiAssetGenerated(json)),
                ai_asset_task,
              ),
            )
          }
      }
    }
    AiAssetPromptChanged(prompt) =>
      ({ ..model, ai_asset_prompt: prompt, }, @rabbita.none)
    AiAssetGenerated(json) => {
      let (next, error) = ai_asset_apply(model, json)
      if error == "" {
        (
          {
            ..next,
            ai_asset_status: AiDone,
            ai_asset_error: "",
          },
          @rabbita.none,
        )
      } else {
        (
          {
            ..next,
            ai_asset_status: AiError,
            ai_asset_error: error,
          },
          @rabbita.none,
        )
      }
    }
    ImportAvatar =>
      (
        model,
        @rabbita.perform(data => emit(AvatarImported(data)), import_avatar_task),
      )
    AvatarImported(data) =>
      if data == "" {
        (model, @rabbita.none)
      } else {
        (
          {
            ..model,
            profile_draft: model.profile_draft.with_field(Avatar, data),
          },
          @rabbita.none,
        )
      }
    RemoveAvatar =>
      (
        { ..model, profile_draft: model.profile_draft.with_field(Avatar, ""), },
        @rabbita.none,
      )
    OpenStyles => {
      let style_doc_id = match active_document(model) {
        Some(document) => document.id
        None => model.style_doc_id
      }
      let next = {
        ..model,
        style_doc_id,
        open_tabs: ensure_tab(model.open_tabs, styles_tab_id),
        active_tab: styles_tab_id,
      }
      persist(next)
      (next, @rabbita.none)
    }
    SelectStyleKind(kind) => ({ ..model, style_view: kind, }, @rabbita.none)
    ApplyStyle(value) =>
      match find_document(model.documents, model.style_doc_id) {
        Some(document) => {
          let source = apply_style(document.source, model.style_view, value)
          let next = {
            ..model,
            documents: with_document_source(
              model.documents,
              document.id,
              source,
            ),
          }
          persist(next)
          (next, @rabbita.none)
        }
        None => (model, @rabbita.none)
      }
    ImportImages =>
      (
        model,
        @rabbita.perform(json => emit(AssetsImported(json)), import_images_task),
      )
    PrepareImageImport(doc_id) =>
      if find_document(model.documents, doc_id) is Some(_) {
        ({ ..model, import_doc_id: doc_id, }, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    AssetsImported(json) => {
      let imported = parse_assets(json)
      let target = import_target_id(model)
      if imported.is_empty() || target == "" {
        ({ ..model, import_doc_id: "", }, @rabbita.none)
      } else {
        let library = library_for_document(model, target)
        let assets = merge_assets(library.images, imported)
        let next = commit_library(
          model,
          target,
          { ..library, images: assets },
        )
        let next = {
          ..next,
          import_doc_id: "",
          open_tabs: ensure_tab(model.open_tabs, images_tab_id),
          active_tab: images_tab_id,
        }
        persist(next)
        (next, @rabbita.none)
      }
    }
    InsertAsset(doc_id, id) =>
      match find_document(model.documents, doc_id) {
        None => (model, @rabbita.none)
        Some(document) => {
          let library = library_for_document(model, doc_id)
          match find_asset(library.images, id) {
            None => (model, @rabbita.none)
            Some(asset) => {
              let markup = asset_markup(asset.name)
              let inserted = insert_at_cursor(markup)
              let source = if inserted == "" {
                document.source + markup
              } else {
                inserted
              }
              let base = {
                ..model,
                documents: with_document_source(
                  model.documents,
                  doc_id,
                  source,
                ),
                open_tabs: ensure_tab(model.open_tabs, doc_id),
                active_tab: doc_id,
              }
              let next = if model.library_doc_id != doc_id {
                switch_library(base, doc_id)
              } else {
                base
              }
              persist(next)
              (next, @rabbita.none)
            }
          }
        }
      }
    DeleteAsset(doc_id, id) => {
      if find_document(model.documents, doc_id) is None {
        (model, @rabbita.none)
      } else {
        let library = library_for_document(model, doc_id)
        let assets = remove_asset(library.images, id)
        let next = commit_library(model, doc_id, { ..library, images: assets })
        let next = if model.preview_kind is ImagePreview &&
          model.preview_item_id == id {
          {
            ..next,
            preview_kind: NoPreview,
            preview_doc_id: "",
            preview_item_id: "",
            table_draft: "",
          }
        } else {
          next
        }
        let next = if model.workspace_preview_kind is ImagePreview &&
          model.workspace_preview_item_id == id {
          {
            ..next,
            workspace_preview_kind: NoPreview,
            workspace_preview_doc_id: "",
            workspace_preview_item_id: "",
          }
        } else {
          next
        }
        (next, @rabbita.none)
      }
    }
    OpenImagePreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) &&
        find_asset(library_for_document(model, doc_id).images, id) is Some(_) {
        (
          {
            ..model,
            open_tabs: ensure_tab(model.open_tabs, images_tab_id),
            active_tab: images_tab_id,
            preview_kind: ImagePreview,
            preview_doc_id: doc_id,
            preview_item_id: id,
            table_draft: "",
          },
          @rabbita.none,
        )
      } else {
        (model, @rabbita.none)
      }
    OpenWorkspaceImagePreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) &&
        find_asset(library_for_document(model, doc_id).images, id) is Some(_) {
        let next = {
          ..model,
          open_tabs: ensure_tab(model.open_tabs, doc_id),
          active_tab: doc_id,
          workspace_preview_kind: ImagePreview,
          workspace_preview_doc_id: doc_id,
          workspace_preview_item_id: id,
        }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    CloseWorkspacePreview =>
      (
        {
          ..model,
          workspace_preview_kind: NoPreview,
          workspace_preview_doc_id: "",
          workspace_preview_item_id: "",
        },
        @rabbita.none,
      )
    ClosePreview =>
      (
        {
          ..model,
          preview_kind: NoPreview,
          preview_doc_id: "",
          preview_item_id: "",
          table_draft: "",
          chart_kind_draft: "",
          chart_text_draft: "",
        },
        @rabbita.none,
      )
    OpenTables => {
      let next = {
        ..model,
        open_tabs: ensure_tab(model.open_tabs, tables_tab_id),
        active_tab: tables_tab_id,
      }
      persist(next)
      (next, @rabbita.none)
    }
    ImportTables =>
      (
        model,
        @rabbita.perform(json => emit(TablesImported(json)), import_tables_task),
      )
    PrepareTableImport(doc_id) =>
      if find_document(model.documents, doc_id) is Some(_) {
        ({ ..model, import_doc_id: doc_id, }, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    TablesImported(json) => {
      let imported = parse_tables(json)
      let target = import_target_id(model)
      if imported.is_empty() || target == "" {
        ({ ..model, import_doc_id: "", }, @rabbita.none)
      } else {
        let mut row_split = false
        let mut column_split = false
        let mut split_parts = 0
        let mut long_cells = 0
        for table in imported {
          if table.split {
            split_parts = split_parts + 1
          }
          if table.row_split {
            row_split = true
          }
          if table.column_split {
            column_split = true
          }
          long_cells = long_cells + table.long_cells
        }
        let library = library_for_document(model, target)
        let tables = merge_tables(library.tables, imported)
        let messages : Array[String] = []
        if row_split && column_split {
          messages.push(
            tr(
              model.lang,
              "Table too large and too wide — split into ",
              "表格过大且列数过多，已拆分为 ",
            ) +
            split_parts.to_string() +
            tr(model.lang, " tables.", " 个表。"),
          )
        } else if column_split {
          messages.push(
            tr(model.lang, "Table too wide — split into ", "表格列数过多，已拆分为 ") +
            split_parts.to_string() +
            tr(model.lang, " tables.", " 个表。"),
          )
        } else if row_split {
          messages.push(
            tr(model.lang, "Table too large — split into ", "表格过大，已拆分为 ") +
            split_parts.to_string() +
            tr(model.lang, " tables.", " 个表。"),
          )
        }
        if long_cells == 1 {
          messages.push(
            tr(
              model.lang,
              "1 cell was truncated to 60 characters.",
              "1 个单元格已截断为 60 个字符。",
            ),
          )
        } else if long_cells > 1 {
          messages.push(
            long_cells.to_string() +
            tr(
              model.lang,
              " cells were truncated to 60 characters.",
              " 个单元格已截断为 60 个字符。",
            ),
          )
        }
        let table_notice = messages.join("\n")
        let next = commit_library(
          model,
          target,
          { ..library, tables },
        )
        let next = {
          ..next,
          import_doc_id: "",
          table_notice,
          open_tabs: ensure_tab(model.open_tabs, tables_tab_id),
          active_tab: tables_tab_id,
        }
        persist(next)
        (next, @rabbita.none)
      }
    }
    InsertTable(doc_id, id) =>
      match find_document(model.documents, doc_id) {
        None => (model, @rabbita.none)
        Some(document) => {
          let library = library_for_document(model, doc_id)
          match find_table(library.tables, id) {
            None => (model, @rabbita.none)
            Some(table) => {
              let markup = table_markup(table.name)
              let inserted = insert_at_cursor(markup)
              let source = if inserted == "" {
                document.source + markup
              } else {
                inserted
              }
              let base = {
                ..model,
                documents: with_document_source(
                  model.documents,
                  doc_id,
                  source,
                ),
                open_tabs: ensure_tab(model.open_tabs, doc_id),
                active_tab: doc_id,
              }
              let next = if model.library_doc_id != doc_id {
                switch_library(base, doc_id)
              } else {
                base
              }
              persist(next)
              (next, @rabbita.none)
            }
          }
        }
      }
    DeleteTable(doc_id, id) => {
      if find_document(model.documents, doc_id) is None {
        (model, @rabbita.none)
      } else {
        let library = library_for_document(model, doc_id)
        let tables = remove_table(library.tables, id)
        let next = commit_library(model, doc_id, { ..library, tables })
        let next = if model.preview_kind is TablePreview &&
          model.preview_item_id == id {
          {
            ..next,
            preview_kind: NoPreview,
            preview_doc_id: "",
            preview_item_id: "",
            table_draft: "",
          }
        } else {
          next
        }
        let next = if model.workspace_preview_kind is TablePreview &&
          model.workspace_preview_item_id == id {
          {
            ..next,
            workspace_preview_kind: NoPreview,
            workspace_preview_doc_id: "",
            workspace_preview_item_id: "",
          }
        } else {
          next
        }
        (next, @rabbita.none)
      }
    }
    OpenTablePreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) {
        match find_table(library_for_document(model, doc_id).tables, id) {
          Some(table) => {
            let limited = @render.csv_limit_table(table.csv, 5, 60)
            let base = {
              ..model,
              open_tabs: ensure_tab(model.open_tabs, tables_tab_id),
              active_tab: tables_tab_id,
              preview_kind: TablePreview,
              preview_doc_id: doc_id,
              preview_item_id: id,
              table_draft: limited,
            }
            let next = if limited == table.csv {
              base
            } else {
              commit_table_draft(base)
            }
            (next, @rabbita.none)
          }
          None => (model, @rabbita.none)
        }
      } else {
        (model, @rabbita.none)
      }
    OpenWorkspaceTablePreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) &&
        find_table(library_for_document(model, doc_id).tables, id) is Some(_) {
        let next = {
          ..model,
          open_tabs: ensure_tab(model.open_tabs, doc_id),
          active_tab: doc_id,
          workspace_preview_kind: TablePreview,
          workspace_preview_doc_id: doc_id,
          workspace_preview_item_id: id,
        }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    EditTableCell(row_index, column_index, value) =>
      if model.preview_kind is TablePreview {
        let next = {
          ..model,
          table_draft: @render.csv_set_cell(
            model.table_draft,
            row_index,
            column_index,
            truncate_text(value, 60),
          ),
        }
        let next = commit_table_draft(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    AddTableRow =>
      if model.preview_kind is TablePreview {
        let (rows, _) = @render.csv_dimensions(model.table_draft)
        if rows >= 200 {
          (model, @rabbita.none)
        } else {
          let next = {
            ..model,
            table_draft: @render.csv_append_row(model.table_draft),
          }
          let next = commit_table_draft(next)
          (next, @rabbita.none)
        }
      } else {
        (model, @rabbita.none)
      }
    AddTableColumn =>
      if model.preview_kind is TablePreview {
        let (_, columns) = @render.csv_dimensions(model.table_draft)
        if columns >= 5 {
          (model, @rabbita.none)
        } else {
          let name = tr(model.lang, "Column ", "列 ") + (columns + 1).to_string()
          let next = {
            ..model,
            table_draft: @render.csv_append_column(model.table_draft, name),
          }
          let next = commit_table_draft(next)
          (next, @rabbita.none)
        }
      } else {
        (model, @rabbita.none)
      }
    DismissTableNotice => ({ ..model, table_notice: "", }, @rabbita.none)
    OpenCharts => {
      let next = {
        ..model,
        open_tabs: ensure_tab(model.open_tabs, charts_tab_id),
        active_tab: charts_tab_id,
      }
      persist(next)
      (next, @rabbita.none)
    }
    ImportCharts =>
      (
        model,
        @rabbita.perform(json => emit(ChartsImported(json)), import_charts_task),
      )
    PrepareChartImport(doc_id) =>
      if find_document(model.documents, doc_id) is Some(_) {
        ({ ..model, import_doc_id: doc_id, }, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    ChartsImported(json) => {
      let imported = parse_charts(json)
      let target = import_target_id(model)
      if imported.is_empty() || target == "" {
        ({ ..model, import_doc_id: "", }, @rabbita.none)
      } else {
        let library = library_for_document(model, target)
        let charts = merge_charts(library.charts, imported)
        let next = commit_library(model, target, { ..library, charts })
        let next = {
          ..next,
          import_doc_id: "",
          open_tabs: ensure_tab(model.open_tabs, charts_tab_id),
          active_tab: charts_tab_id,
        }
        persist(next)
        (next, @rabbita.none)
      }
    }
    InsertChart(doc_id, id) =>
      match find_document(model.documents, doc_id) {
        None => (model, @rabbita.none)
        Some(document) => {
          let library = library_for_document(model, doc_id)
          match find_chart(library.charts, id) {
            None => (model, @rabbita.none)
            Some(chart) => {
              let markup = chart_markup(chart.name)
              let inserted = insert_at_cursor(markup)
              let source = if inserted == "" {
                document.source + markup
              } else {
                inserted
              }
              let base = {
                ..model,
                documents: with_document_source(
                  model.documents,
                  doc_id,
                  source,
                ),
                open_tabs: ensure_tab(model.open_tabs, doc_id),
                active_tab: doc_id,
              }
              let next = if model.library_doc_id != doc_id {
                switch_library(base, doc_id)
              } else {
                base
              }
              persist(next)
              (next, @rabbita.none)
            }
          }
        }
      }
    DeleteChart(doc_id, id) => {
      if find_document(model.documents, doc_id) is None {
        (model, @rabbita.none)
      } else {
        let library = library_for_document(model, doc_id)
        let charts = remove_chart(library.charts, id)
        let next = commit_library(model, doc_id, { ..library, charts })
        let next = if model.preview_kind is ChartPreview &&
          model.preview_item_id == id {
          {
            ..next,
            preview_kind: NoPreview,
            preview_doc_id: "",
            preview_item_id: "",
            chart_kind_draft: "",
            chart_text_draft: "",
          }
        } else {
          next
        }
        let next = if model.workspace_preview_kind is ChartPreview &&
          model.workspace_preview_item_id == id {
          {
            ..next,
            workspace_preview_kind: NoPreview,
            workspace_preview_doc_id: "",
            workspace_preview_item_id: "",
          }
        } else {
          next
        }
        (next, @rabbita.none)
      }
    }
    OpenChartPreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) {
        match find_chart(library_for_document(model, doc_id).charts, id) {
          Some(chart) =>
            (
              {
                ..model,
                open_tabs: ensure_tab(model.open_tabs, charts_tab_id),
                active_tab: charts_tab_id,
                preview_kind: ChartPreview,
                preview_doc_id: doc_id,
                preview_item_id: id,
                chart_kind_draft: chart.kind,
                chart_text_draft: if chart.text.trim() == "" {
                  chart_template(chart.kind, model.lang)
                } else {
                  chart.text
                },
              },
              @rabbita.none,
            )
          None => (model, @rabbita.none)
        }
      } else {
        (model, @rabbita.none)
      }
    OpenWorkspaceChartPreview(doc_id, id) =>
      if find_document(model.documents, doc_id) is Some(_) &&
        find_chart(library_for_document(model, doc_id).charts, id) is Some(_) {
        let next = {
          ..model,
          open_tabs: ensure_tab(model.open_tabs, doc_id),
          active_tab: doc_id,
          workspace_preview_kind: ChartPreview,
          workspace_preview_doc_id: doc_id,
          workspace_preview_item_id: id,
        }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    NewChart(doc_id) => {
      if find_document(model.documents, doc_id) is None {
        (model, @rabbita.none)
      } else {
        let library = library_for_document(model, doc_id)
        let chart = new_chart(library.charts, model.lang)
        let charts = library.charts.copy()
        charts.push(chart)
        let next = commit_library(model, doc_id, { ..library, charts })
        let next = if model.library_doc_id != doc_id {
          switch_library(next, doc_id)
        } else {
          next
        }
        let next = {
          ..next,
          open_tabs: ensure_tab(next.open_tabs, charts_tab_id),
          active_tab: charts_tab_id,
          preview_kind: ChartPreview,
          preview_doc_id: doc_id,
          preview_item_id: chart.id,
          chart_kind_draft: chart.kind,
          chart_text_draft: chart.text,
        }
        persist(next)
        (next, @rabbita.none)
      }
    }
    EditChartKind(kind) =>
      if model.preview_kind is ChartPreview {
        let text = if model.chart_text_draft.trim() == "" {
          chart_template(kind, model.lang)
        } else {
          model.chart_text_draft
        }
        let next = { ..model, chart_kind_draft: kind, chart_text_draft: text }
        (commit_chart_draft(next), @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    EditChartText(text) =>
      if model.preview_kind is ChartPreview {
        let next = { ..model, chart_text_draft: text }
        (commit_chart_draft(next), @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    RequestDeleteDocument(id) =>
      if find_document(model.documents, id) is Some(_) {
        ({ ..model, pending_delete_doc_id: id, }, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    CancelDeleteDocument =>
      ({ ..model, pending_delete_doc_id: "", }, @rabbita.none)
    DeleteDocument(id) => {
        let documents : Array[EmailDoc] = []
        for document in model.documents {
          if document.id != id {
            documents.push(document)
          }
        }
        let open_tabs = remove_tab(model.open_tabs, id)
        let active_tab = if model.active_tab == id {
          if open_tabs.is_empty() {
            ""
          } else {
            open_tabs[open_tabs.length() - 1]
          }
        } else {
          model.active_tab
        }
        let style_doc_id = if model.style_doc_id == id {
          if documents.is_empty() {
            ""
          } else {
            documents[0].id
          }
        } else {
          model.style_doc_id
        }
        delete_library(id)
        let base = {
          ..model,
          documents,
          open_tabs,
          active_tab,
          style_doc_id,
        }
        let next = if id == model.library_doc_id {
          let context = if active_tab != "" &&
            find_document(documents, active_tab) is Some(_) {
            active_tab
          } else {
            first_open_document_id(open_tabs, documents)
          }
          if context == "" {
            clear_library_model(base)
          } else {
            load_library_model(base, context)
          }
        } else if active_tab != model.active_tab &&
          find_document(documents, active_tab) is Some(_) &&
          active_tab != model.library_doc_id {
          switch_library(base, active_tab)
        } else {
          base
        }
        let next = if model.preview_doc_id == id {
          {
            ..next,
            preview_kind: NoPreview,
            preview_doc_id: "",
            preview_item_id: "",
            pending_delete_doc_id: "",
          }
        } else if model.pending_delete_doc_id == id {
          { ..next, pending_delete_doc_id: "", }
        } else {
          next
        }
        let next = if model.workspace_preview_doc_id == id {
          {
            ..next,
            workspace_preview_kind: NoPreview,
            workspace_preview_doc_id: "",
            workspace_preview_item_id: "",
          }
        } else {
          next
        }
        persist(next)
        (next, @rabbita.none)
      }
    ToggleLanguage => {
      let lang = other_lang(model.lang)
      save_lang(lang)
      ({ ..model, lang, }, @rabbita.none)
    }
  }
}

///|
fn sigil_mark() -> Html {
  @svg.svg(
    class="sigil-logo-mark",
    view_box="0 0 24 24",
    width=18,
    height=18,
    attrs=@svg.Attrs::build()
      .fill("none")
      .stroke("currentColor")
      .stroke_width("2")
      .stroke_linecap("round")
      .stroke_linejoin("round"),
    [
      @svg.path(d="M4 20l4.2-1.1L19 8.1a2.2 2.2 0 0 0-3.1-3.1L5.1 15.8 4 20z"),
      @svg.path(d="M13.8 6.9l3.3 3.3"),
    ],
  )
}

///|
fn icon_svg(children : Array[@svg.Svg]) -> Html {
  @svg.svg(
    class="sigil-icon",
    view_box="0 0 24 24",
    width=20,
    height=20,
    attrs=@svg.Attrs::build()
      .fill("none")
      .stroke("currentColor")
      .stroke_width("1.7")
      .stroke_linecap("round")
      .stroke_linejoin("round"),
    children,
  )
}

///|
fn icon_files() -> Html {
  icon_svg([
    @svg.path(
      d="M4 7V5.5A1.5 1.5 0 0 1 5.5 4H10l2 2h6.5A1.5 1.5 0 0 1 20 7.5V8",
    ),
    @svg.path(d="M4 8h16v9.5a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"),
  ])
}

///|
fn icon_plus() -> Html {
  icon_svg([@svg.path(d="M12 5v14M5 12h14")])
}

///|
fn icon_user() -> Html {
  icon_svg([
    @svg.circle(cx=12, cy=8, r=4),
    @svg.path(d="M5 20c0-3.6 3.1-6.5 7-6.5s7 2.9 7 6.5"),
  ])
}

///|
fn icon_image() -> Html {
  icon_svg([
    @svg.rect(x=4, y=5, width=16, height=14, rx=2),
    @svg.circle(cx=9, cy=10, r=1),
    @svg.path(d="M4 17l4.5-4.5 3.5 3 3-2.5L20 18"),
  ])
}

///|
fn icon_table() -> Html {
  icon_svg([
    @svg.rect(x=4, y=5, width=16, height=14, rx=2),
    @svg.path(d="M4 10h16M4 14.5h16M9.5 5v14M14.5 5v14"),
  ])
}

///|
fn icon_chart() -> Html {
  icon_svg([
    @svg.path(d="M4 19h16"),
    @svg.rect(x=5, y=11, width=3, height=6, rx=1),
    @svg.rect(x=10, y=7, width=4, height=10, rx=1),
    @svg.rect(x=16, y=9, width=3, height=8, rx=1),
  ])
}

///|
fn icon_styles() -> Html {
  icon_svg([
    @svg.circle(cx=12, cy=12, r=8),
    @svg.circle(cx=9, cy=9, r=1),
    @svg.circle(cx=15, cy=9, r=1),
    @svg.circle(cx=9, cy=15, r=1),
    @svg.path(d="M15.5 15.5h1a2.5 2.5 0 0 1 0 5h-5"),
  ])
}

///|
fn icon_gear() -> Html {
  icon_svg([
    @svg.path(d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z"),
    @svg.path(
      d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09A1.65 1.65 0 0 0 15 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z",
    ),
  ])
}

///|
fn avatar_view(profile : Profile, classes : String) -> Html {
  if profile.avatar != "" {
    img(src=profile.avatar, alt="", class=classes + " sigil-avatar-image")
  } else {
    span(class=classes, profile.initial())
  }
}

///|
fn avatar_picker(emit : Emit[Msg]) -> Html {
  input(
    input_type=@html.InputType::File,
    id="sigil-avatar-input",
    accept="image/*",
    class="sigil-file-input",
    on_change=emit.map(_ => ImportAvatar),
  )
}

///|
fn avatar_upload_button(label : String) -> Html {
  button(
    type_="button",
    class="sigil-button is-small",
    attrs=@html.Attrs::build().on_click(_ => {
      open_avatar_picker()
      @rabbita.none
    }),
    [span(label)],
  )
}

///|
fn export_button(model : Model) -> Html {
  button(
    type_="button",
    class="sigil-export",
    title=tr(model.lang, "Export HTML", "导出 HTML"),
    disabled=active_document(model) is None,
    attrs=@html.Attrs::build().on_click(_ => {
      export_active_document(model)
      @rabbita.none
    }),
    [span(tr(model.lang, "Export", "导出"))],
  )
}

///|
fn titlebar(emit : Emit[Msg], model : Model) -> Html {
  let current = if model.active_tab == "" {
    tr(model.lang, "Workspace", "工作区")
  } else {
    tab_title(model, model.active_tab)
  }
  header(class="sigil-titlebar", [
    div(class="sigil-titlebar-left", [
      div(class="sigil-logo", [sigil_mark()]),
      span(class="sigil-wordmark", "Sigil"),
      span(class="sigil-titlebar-divider", "/"),
      span(class="sigil-document-title", current),
    ]),
    div(class="sigil-titlebar-actions", [
      button(
        type_="button",
        class="sigil-lang-button",
        title=tr(model.lang, "Switch language", "切换语言"),
        on_click=emit(ToggleLanguage),
        [span(lang_label(model.lang))],
      ),
      button(
        type_="button",
        class="sigil-avatar-button",
        title=tr(model.lang, "Profile", "个人资料"),
        on_click=emit(OpenProfile),
        [avatar_view(model.profile, "sigil-avatar")],
      ),
    ]),
  ])
}

///|
fn activity_bar(emit : Emit[Msg], model : Model) -> Html {
  let profile_active = model.active_tab == profile_tab_id
  let images_active = model.active_tab == images_tab_id
  let tables_active = model.active_tab == tables_tab_id
  let styles_active = model.active_tab == styles_tab_id
  div(class="sigil-activitybar", [
    div(class="sigil-activity-group", [
      button(
        type_="button",
        class=if model.sidebar_open {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Workspace", "工作区"),
        on_click=emit(ToggleSidebar),
        [icon_files()],
      ),
      button(
        type_="button",
        class="sigil-activity-button",
        title=tr(model.lang, "New email", "新建邮件"),
        on_click=emit(NewDocument),
        [icon_plus()],
      ),
      button(
        type_="button",
        class=if profile_active {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Profile", "个人资料"),
        on_click=emit(OpenProfile),
        [icon_user()],
      ),
      button(
        type_="button",
        class=if images_active {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Images", "图片"),
        on_click=emit(OpenImages),
        [icon_image()],
      ),
      button(
        type_="button",
        class=if tables_active {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Tables", "表格"),
        on_click=emit(OpenTables),
        [icon_table()],
      ),
      button(
        type_="button",
        class=if model.active_tab == charts_tab_id {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Charts", "图表"),
        on_click=emit(OpenCharts),
        [icon_chart()],
      ),
      button(
        type_="button",
        class=if styles_active {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Styles", "样式"),
        on_click=emit(OpenStyles),
        [icon_styles()],
      ),
      button(
        type_="button",
        class=if model.active_tab == settings_tab_id {
          "sigil-activity-button is-active"
        } else {
          "sigil-activity-button"
        },
        title=tr(model.lang, "Settings", "设置"),
        on_click=emit(OpenSettings),
        [icon_gear()],
      ),
    ]),
  ])
}

///|
fn tab_title(model : Model, id : String) -> String {
  if id == profile_tab_id {
    tr(model.lang, "Profile", "个人资料")
  } else if id == images_tab_id {
    tr(model.lang, "Images", "图片")
  } else if id == tables_tab_id {
    tr(model.lang, "Tables", "表格")
  } else if id == charts_tab_id {
    tr(model.lang, "Charts", "图表")
  } else if id == settings_tab_id {
    tr(model.lang, "Settings", "设置")
  } else if id == styles_tab_id {
    tr(model.lang, "Styles", "样式")
  } else {
    match find_document(model.documents, id) {
      Some(document) => document.title
      None => tr(model.lang, "Missing document", "找不到文档")
    }
  }
}

///|
fn tab_dot_class(id : String) -> String {
  if id == profile_tab_id {
    "sigil-tab-dot is-profile"
  } else if id == images_tab_id {
    "sigil-tab-dot is-image"
  } else if id == tables_tab_id {
    "sigil-tab-dot is-table"
  } else if id == charts_tab_id {
    "sigil-tab-dot is-chart"
  } else if id == settings_tab_id {
    "sigil-tab-dot is-settings"
  } else if id == styles_tab_id {
    "sigil-tab-dot is-styles"
  } else {
    "sigil-tab-dot"
  }
}

///|
fn tabbar(emit : Emit[Msg], model : Model) -> Html {
  let children : Array[Html] = []
  for id in model.open_tabs {
    let active = model.active_tab == id
    children.push(
      div(
        class=if active { "sigil-tab is-active" } else { "sigil-tab" },
        on_click=emit(SelectTab(id)),
        [
          span(class=tab_dot_class(id), ([] : Array[Html])),
          span(class="sigil-tab-label", tab_title(model, id)),
          button(
            type_="button",
            class="sigil-tab-close",
            title=tr(model.lang, "Close tab", "关闭标签页"),
            on_click=emit(CloseTab(id)),
            [span("x")],
          ),
        ],
      ),
    )
  }
  children.push(
    button(
      type_="button",
      class="sigil-tab-new",
      title=tr(model.lang, "New email", "新建邮件"),
      on_click=emit(NewDocument),
      [span("+")],
    ),
  )
  div(class="sigil-tabs", children)
}

///|
fn library_context_title(model : Model) -> String {
  match find_document(model.documents, model.library_doc_id) {
    Some(document) => document.title
    None => tr(model.lang, "No email", "无邮件")
  }
}

///|
fn sidebar_table_rows(emit : Emit[Msg], model : Model) -> Array[Html] {
  let rows : Array[Html] = []
  for table in model.tables {
    let (row_count, column_count) = @render.csv_dimensions(table.csv)
    rows.push(
      div(class="sigil-side-table-row", [
        button(
          type_="button",
          class="sigil-side-table-open",
          title=tr(model.lang, "Preview ", "预览 ") + table.name,
          on_click=emit(OpenWorkspaceTablePreview(model.library_doc_id, table.id)),
          [
            icon_table(),
            span(class="sigil-side-table-name", table.name),
            span(
              class="sigil-side-table-meta",
              row_count.to_string() + "×" + column_count.to_string(),
            ),
          ],
        ),
        button(
          type_="button",
          class="sigil-side-table-insert",
          title=tr(model.lang, "Insert table", "插入表格"),
          on_click=emit(InsertTable(model.library_doc_id, table.id)),
          [span("+")],
        ),
      ]),
    )
  }
  rows
}

///|
fn sidebar_chart_rows(emit : Emit[Msg], model : Model) -> Array[Html] {
  let rows : Array[Html] = []
  for chart in model.charts {
    rows.push(
      div(class="sigil-side-table-row", [
        button(
          type_="button",
          class="sigil-side-table-open",
          title=tr(model.lang, "Preview ", "预览 ") + chart.name,
          on_click=emit(OpenWorkspaceChartPreview(model.library_doc_id, chart.id)),
          [
            icon_chart(),
            span(class="sigil-side-table-name", chart.name),
            span(
              class="sigil-side-table-meta",
              chart_kind_label(model.lang, chart.kind),
            ),
          ],
        ),
        button(
          type_="button",
          class="sigil-side-table-insert",
          title=tr(model.lang, "Insert chart", "插入图表"),
          on_click=emit(InsertChart(model.library_doc_id, chart.id)),
          [span("+")],
        ),
      ]),
    )
  }
  rows
}

///|
fn sidebar(emit : Emit[Msg], model : Model) -> Html {
  guard model.sidebar_open else { return @html.nothing }
  let documents : Array[Html] = []
  for document in model.documents {
    let active = model.active_tab == document.id
    documents.push(
      div(
        class=if active { "sigil-doc-row is-active" } else { "sigil-doc-row" },
        [
          button(
            type_="button",
            class="sigil-doc-open",
            title=document.title,
            on_click=emit(OpenDocument(document.id)),
            [
              span(class="sigil-doc-dot", ([] : Array[Html])),
              span(class="sigil-doc-name", document.title),
              span(class="sigil-doc-chars", document.source.length().to_string()),
            ],
          ),
          button(
            type_="button",
            class="sigil-doc-delete",
            title=tr(model.lang, "Delete email", "删除邮件"),
            on_click=emit(RequestDeleteDocument(document.id)),
            [span("×")],
          ),
        ],
      ),
    )
    if model.pending_delete_doc_id == document.id {
      documents.push(
        div(class="sigil-doc-confirm", [
          span(
            class="sigil-doc-confirm-text",
            tr(model.lang, "Delete this email?", "删除这封邮件？"),
          ),
          button(
            type_="button",
            class="sigil-button is-small is-danger",
            on_click=emit(DeleteDocument(document.id)),
            tr(model.lang, "Delete", "删除"),
          ),
          button(
            type_="button",
            class="sigil-button is-small",
            on_click=emit(CancelDeleteDocument),
            tr(model.lang, "Cancel", "取消"),
          ),
        ]),
      )
    }
  }
  let thumbs : Array[Html] = []
  for asset in model.assets {
    thumbs.push(
      div(class="sigil-side-thumb-item", [
        button(
          type_="button",
          class="sigil-side-thumb",
          title=tr(model.lang, "Preview ", "预览 ") + asset.name,
          on_click=emit(OpenWorkspaceImagePreview(model.library_doc_id, asset.id)),
          [
            img(
              src=asset.data_url,
              alt=asset.name,
              class="sigil-side-thumb-image",
            ),
          ],
        ),
        button(
          type_="button",
          class="sigil-side-thumb-insert",
          title=tr(model.lang, "Insert image", "插入图片"),
          on_click=emit(InsertAsset(model.library_doc_id, asset.id)),
          [span("+")],
        ),
      ]),
    )
  }
  let image_content = if thumbs.is_empty() {
    div(
      class="sigil-sidebar-empty",
      tr(model.lang, "No images yet.", "暂无图片。"),
    )
  } else {
    div(class="sigil-side-thumbs", thumbs)
  }
  div(class="sigil-sidebar", [
    div(class="sigil-sidebar-header", [
      span(
        class="sigil-sidebar-heading",
        tr(model.lang, "Workspace", "工作区"),
      ),
      button(
        type_="button",
        class="sigil-sidebar-new",
        title=tr(model.lang, "New email", "新建邮件"),
        on_click=emit(NewDocument),
        [span(tr(model.lang, "+ New", "+ 新建"))],
      ),
    ]),
    div(class="sigil-sidebar-context", [
      span(
        class="sigil-sidebar-context-label",
        tr(model.lang, "Email", "邮件"),
      ),
      span(class="sigil-sidebar-context-name", library_context_title(model)),
    ]),
    div(class="sigil-sidebar-section", [
      div(class="sigil-sidebar-title", [
        span(tr(model.lang, "Documents", "文档")),
        span(class="sigil-sidebar-count", model.documents.length().to_string()),
      ]),
      div(class="sigil-doc-list", documents),
    ]),
    div(class="sigil-sidebar-section sigil-sidebar-images", [
      div(class="sigil-sidebar-title", [
        span(tr(model.lang, "Images", "图片")),
        import_images_button(
          emit,
          model.library_doc_id,
          "sigil-sidebar-action",
          tr(model.lang, "Import", "导入"),
        ),
      ]),
      image_content,
    ]),
    div(class="sigil-sidebar-section sigil-sidebar-images", [
      div(class="sigil-sidebar-title", [
        span(tr(model.lang, "Tables", "表格")),
        import_tables_button(
          emit,
          model.library_doc_id,
          "sigil-sidebar-action",
          tr(model.lang, "Import", "导入"),
        ),
      ]),
      if model.tables.is_empty() {
        div(
          class="sigil-sidebar-empty",
          tr(model.lang, "No tables yet.", "暂无表格。"),
        )
      } else {
        div(class="sigil-side-table-list", sidebar_table_rows(emit, model))
      },
    ]),
    div(class="sigil-sidebar-section sigil-sidebar-images", [
      div(class="sigil-sidebar-title", [
        span(tr(model.lang, "Charts", "图表")),
        import_charts_button(
          emit,
          model.library_doc_id,
          "sigil-sidebar-action",
          tr(model.lang, "Import", "导入"),
        ),
      ]),
      if model.charts.is_empty() {
        div(
          class="sigil-sidebar-empty",
          tr(model.lang, "No charts yet.", "暂无图表。"),
        )
      } else {
        div(class="sigil-side-table-list", sidebar_chart_rows(emit, model))
      },
    ]),
  ])
}

///|
fn diagnostics_panel(
  diagnostics : Array[@types.Diagnostic],
  lang : Lang,
) -> Html {
  if diagnostics.is_empty() {
    return @html.nothing
  }
  let shown = if diagnostics.length() > 4 { 4 } else { diagnostics.length() }
  let rows : Array[Html] = []
  for index = 0; index < shown; index = index + 1 {
    let diagnostic = diagnostics[index]
    rows.push(
      div(
        class=if diagnostic.severity is @types.Error {
          "sigil-diagnostic is-error"
        } else {
          "sigil-diagnostic is-warning"
        },
        [
          span(
            class="sigil-diagnostic-line",
            tr(lang, "Line ", "第 ") + diagnostic.line.to_string(),
          ),
          span(class="sigil-diagnostic-message", diagnostic.message),
        ],
      ),
    )
  }
  div(class="sigil-diagnostics", [
    div(
      class="sigil-diagnostics-header",
      tr(lang, "Problems", "问题") + " " + diagnostics.length().to_string(),
    ),
    div(class="sigil-diagnostics-list", rows),
  ])
}

///|
fn ai_status_strip(model : Model) -> Html {
  if model.ai_status is AiLoading {
    div(
      class="sigil-ai-strip",
      [span(class="sigil-ai-status", tr(model.lang, "Polishing...", "润色中..."))],
    )
  } else if model.ai_error != "" {
    div(class="sigil-ai-strip", [
      span(class="sigil-ai-error", model.ai_error),
    ])
  } else if model.ai_status is AiDone {
    div(class="sigil-ai-strip", [
      span(
        class="sigil-ai-status",
        tr(
          model.lang,
          "Polished. Editor content replaced.",
          "润色完成，已覆盖编辑器内容。",
        ),
      ),
    ])
  } else {
    @html.nothing
  }
}

///|
fn ai_asset_status_strip(model : Model) -> Html {
  if model.ai_asset_status is AiLoading {
    div(
      class="sigil-ai-strip",
      [
        span(
          class="sigil-ai-status",
          tr(model.lang, "Generating...", "生成中..."),
        ),
      ],
    )
  } else if model.ai_asset_error != "" {
    div(class="sigil-ai-strip", [
      span(class="sigil-ai-error", model.ai_asset_error),
    ])
  } else if model.ai_asset_status is AiDone {
    div(class="sigil-ai-strip", [
      span(
        class="sigil-ai-status",
        tr(
          model.lang,
          "Generated. Asset inserted at the cursor.",
          "生成完成，已在光标处插入。",
        ),
      ),
    ])
  } else {
    @html.nothing
  }
}

///|
fn editor_pane(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
  diagnostics : Array[@types.Diagnostic],
) -> Html {
  div(
    class="sigil-editor",
    style=["flex:0 0 " + model.split_pct.to_string() + "%"],
    [
      div(class="sigil-pane-bar", [
        input(
          class="sigil-document-input",
          value=document.title,
          on_input=emit.map(title => RenameDocument(title)),
        ),
        div(class="sigil-pane-actions", [
          span(
            class="sigil-pane-meta",
            document.source.length().to_string() +
            tr(model.lang, " chars", " 字符"),
          ),
          button(
            type_="button",
            class="sigil-button is-small is-primary",
            disabled=model.ai_status is AiLoading,
            title=tr(
              model.lang,
              "Polish the current email with an AI model",
              "让模型润色当前邮件",
            ),
            on_click=emit(PolishAiEmail),
            if model.ai_status is AiLoading {
              tr(model.lang, "Polishing...", "润色中...")
            } else {
              tr(model.lang, "AI polish", "AI 润色")
            },
          ),
          button(
            type_="button",
            class="sigil-button is-small",
            disabled=model.ai_asset_status is AiLoading,
            title=tr(
              model.lang,
              "Generate a chart or table from the AI asset prompt",
              "根据 AI 资产提示词生成图表或表格",
            ),
            on_click=emit(GenerateAiAsset),
            if model.ai_asset_status is AiLoading {
              tr(model.lang, "Generating...", "生成中...")
            } else {
              tr(model.lang, "AI chart/table", "AI 图表/表格")
            },
          ),
        ]),
      ]),
      ai_status_strip(model),
      ai_asset_status_strip(model),
      div(class="sigil-editor-field", [
        highlighted_source(document.source),
        textarea(
          id="sigil-editor",
          class="sigil-editor-input",
          value=document.source,
          placeholder=tr(
            model.lang,
            "Write your email markup here...",
            "在此输入邮件标记...",
          ),
          on_input=emit.map(source_changed),
          attrs=editor_input_attrs(),
          ([] : Array[Html]),
        ),
      ]),
      diagnostics_panel(diagnostics, model.lang),
    ],
  )
}

///|
fn preview_pane(
  emit : Emit[Msg],
  model : Model,
  preview_html : String,
) -> Html {
  let preview_attrs = @html.Attrs::build().srcdoc(preview_html)
  div(class="sigil-preview", [
    div(class="sigil-pane-bar", [
      span(class="sigil-pane-title", tr(model.lang, "Preview", "预览")),
      div(class="sigil-pane-actions", [
        span(
          class="sigil-pane-meta",
          tr(model.lang, "Responsive column", "自适应阅读栏"),
        ),
        send_button(emit, model),
        export_button(model),
      ]),
    ]),
    div(class="sigil-preview-stage", [
      iframe(
        class="sigil-preview-frame",
        title=tr(model.lang, "Sigil preview", "Sigil 预览"),
        sandbox="allow-same-origin",
        attrs=preview_attrs,
      ),
    ]),
  ])
}

///|
fn document_accent(document : EmailDoc) -> String {
  let parsed = @parser.parse(document.source)
  match parsed.document.theme {
    Some(color) => color
    None => "#2563EB"
  }
}

///|
fn workspace_preview_pane(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let library = library_for_document(model, document.id)
  let (title, body) = match model.workspace_preview_kind {
    NoPreview => ("", @html.nothing)
    ImagePreview =>
      match find_asset(library.images, model.workspace_preview_item_id) {
        Some(asset) =>
          (
            asset.name,
            div(class="sigil-workspace-preview-stage", [
              img(
                src=asset.data_url,
                alt=asset.name,
                class="sigil-workspace-preview-image",
              ),
            ]),
          )
        None =>
          (
            tr(model.lang, "Image", "图片"),
            div(
              class="sigil-workspace-preview-empty",
              tr(model.lang, "Image not found.", "找不到图片。"),
            ),
          )
      }
    TablePreview =>
      match find_table(library.tables, model.workspace_preview_item_id) {
        Some(table) => {
          let accent = document_accent(document)
          let table_html = @render.render_csv_table_html(table.csv, accent)
          let preview_html = "<!doctype html><html><head><meta charset=\"utf-8\">" +
            "<style>body{margin:0;padding:24px;background:#ffffff;font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;}</style>" +
            "</head><body>" +
            table_html +
            "</body></html>"
          (
            table.name,
            div(class="sigil-workspace-preview-stage is-table", [
              iframe(
                class="sigil-workspace-preview-frame",
                title=table.name,
                sandbox="allow-same-origin",
                attrs=@html.Attrs::build().srcdoc(preview_html),
              ),
            ]),
          )
        }
        None =>
          (
            tr(model.lang, "Table", "表格"),
            div(
              class="sigil-workspace-preview-empty",
              tr(model.lang, "Table not found.", "找不到表格。"),
            ),
          )
      }
    ChartPreview =>
      match find_chart(library.charts, model.workspace_preview_item_id) {
        Some(chart) => {
          let palette = chart_document_palette(document)
          (
            chart.name,
            div(class="sigil-workspace-preview-stage is-table", [
              iframe(
                class="sigil-workspace-preview-frame",
                title=chart.name,
                sandbox="allow-same-origin",
                attrs=@html.Attrs::build().srcdoc(
                  chart_srcdoc(chart.kind, chart.text, palette),
                ),
              ),
            ]),
          )
        }
        None =>
          (
            tr(model.lang, "Chart", "图表"),
            div(
              class="sigil-workspace-preview-empty",
              tr(model.lang, "Chart not found.", "找不到图表。"),
            ),
          )
      }
  }
  div(class="sigil-preview", [
    div(class="sigil-pane-bar", [
      span(class="sigil-pane-title", tr(model.lang, "Preview", "预览")),
      div(class="sigil-pane-actions", [
        span(class="sigil-pane-meta", title),
        button(
          type_="button",
          class="sigil-button is-small",
          on_click=emit(CloseWorkspacePreview),
          tr(model.lang, "Back to email", "返回邮件"),
        ),
      ]),
    ]),
    body,
  ])
}

///|
fn compose_workspace(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let result = @parser.parse(document.source)
  let preview_html = @render.render_email_html_with_libraries(
    result.document,
    to_core_profile(model.profile),
    asset_map(model.assets),
    table_map(model.tables),
    chart_map(model.charts),
  )
  let right_pane = if model.workspace_preview_kind != NoPreview &&
    model.workspace_preview_doc_id == document.id {
    workspace_preview_pane(emit, model, document)
  } else {
    preview_pane(emit, model, preview_html)
  }
  div(class="sigil-workspace", [
    editor_pane(emit, model, document, result.diagnostics),
    div(
      class="sigil-splitter",
      title=tr(model.lang, "Drag to resize", "拖动调整宽度"),
      on_mousedown=emit.map(_ => BeginDrag),
      [div(class="sigil-splitter-grip", ([] : Array[Html]))],
    ),
    right_pane,
  ])
}

///|
fn profile_field(
  emit : Emit[Msg],
  label_text : String,
  field : ProfileField,
  value : String,
  kind : @html.InputType,
  placeholder : String,
  wide~ : Bool = false,
) -> Html {
  label(class=if wide { "sigil-field is-wide" } else { "sigil-field" }, [
    span(class="sigil-field-label", label_text),
    input(
      input_type=kind,
      class="sigil-field-input",
      value~,
      placeholder~,
      on_input=emit.map(text => ProfileFieldChanged(field, text)),
    ),
  ])
}

///|
fn profile_section(title : String, fields : Array[Html]) -> Html {
  div(class="sigil-settings-section", [
    span(class="sigil-settings-title", title),
    div(class="sigil-field-grid", fields),
  ])
}

///|
fn profile_tab(emit : Emit[Msg], model : Model) -> Html {
  div(class="sigil-profile-panel", [
    div(class="sigil-profile-sheet", [
      div(class="sigil-profile-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Tab / Settings", "标签页 / 设置"),
        ),
        span(
          class="sigil-profile-title",
          tr(model.lang, "Profile", "个人资料"),
        ),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Personal details used by signatures and footers.",
            "用于签名和页脚的个人信息。",
          ),
        ),
      ]),
      div(class="sigil-profile-summary", [
        avatar_view(model.profile_draft, "sigil-avatar sigil-avatar-large"),
        div(class="sigil-profile-summary-text", [
          span(
            class="sigil-profile-summary-name",
            if model.profile_draft.name != "" {
              model.profile_draft.name
            } else if model.profile_draft.nickname != "" {
              model.profile_draft.nickname
            } else if model.profile_draft.email != "" {
              model.profile_draft.email
            } else {
              tr(model.lang, "Unnamed profile", "未命名资料")
            },
          ),
          span(
            class="sigil-profile-summary-meta",
            tr(
              model.lang,
              "Saved with this workspace.",
              "随当前工作区一起保存。",
            ),
          ),
        ]),
        span(class="sigil-profile-progress", model.profile_draft.completeness()),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Avatar", "头像"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Shown in the title bar and signatures.",
                "显示在标题栏和签名中。",
              ),
            ),
          ]),
          div(class="sigil-avatar-control", [
            avatar_view(model.profile_draft, "sigil-avatar sigil-avatar-large"),
            avatar_upload_button(
              tr(model.lang, "Upload avatar", "上传头像"),
            ),
            if model.profile_draft.avatar != "" {
              button(
                type_="button",
                class="sigil-button is-small is-danger",
                on_click=emit(RemoveAvatar),
                tr(model.lang, "Remove", "移除"),
              )
            } else {
              @html.nothing
            },
          ]),
        ]),
      ]),
      profile_section(tr(model.lang, "Identity", "身份"), [
        profile_field(
          emit,
          tr(model.lang, "Name", "姓名"),
          Name,
          model.profile_draft.name,
          @html.InputType::Text,
          tr(model.lang, "Zhang San", "张三"),
        ),
        profile_field(
          emit,
          tr(model.lang, "Alias", "别名"),
          Alias,
          model.profile_draft.nickname,
          @html.InputType::Text,
          tr(model.lang, "San", "三"),
        ),
        profile_field(
          emit,
          tr(model.lang, "Title", "职位"),
          Title,
          model.profile_draft.title,
          @html.InputType::Text,
          tr(model.lang, "Product Manager", "产品经理"),
        ),
      ]),
      profile_section(tr(model.lang, "Contact", "联系方式"), [
        profile_field(
          emit,
          tr(model.lang, "Email", "邮箱"),
          Email,
          model.profile_draft.email,
          @html.InputType::Email,
          "zhangsan@example.com",
        ),
        profile_field(
          emit,
          tr(model.lang, "Phone", "电话"),
          Phone,
          model.profile_draft.phone,
          @html.InputType::Tel,
          "+86 138 0000 0000",
        ),
        profile_field(
          emit,
          tr(model.lang, "Website", "网站"),
          Website,
          model.profile_draft.website,
          @html.InputType::Url,
          "https://example.com",
        ),
      ]),
      profile_section(tr(model.lang, "Background", "背景"), [
        profile_field(
          emit,
          tr(model.lang, "Company", "公司"),
          Company,
          model.profile_draft.company,
          @html.InputType::Text,
          tr(model.lang, "Example Inc.", "示例公司"),
        ),
        profile_field(
          emit,
          tr(model.lang, "Education", "教育背景"),
          Education,
          model.profile_draft.education,
          @html.InputType::Text,
          tr(
            model.lang,
            "Example University / Computer Science",
            "示例大学 / 计算机科学",
          ),
          wide=true,
        ),
      ]),
      div(class="sigil-profile-footer", [
        span(
          class="sigil-profile-hint",
          tr(
            model.lang,
            "All fields are optional.",
            "所有字段均为可选。",
          ),
        ),
        div(class="sigil-profile-actions", [
          button(
            type_="button",
            class="sigil-button",
            on_click=emit(RevertProfile),
            tr(model.lang, "Revert", "还原"),
          ),
          button(
            type_="button",
            class="sigil-button is-primary",
            on_click=emit(SaveProfile),
            tr(model.lang, "Save profile", "保存资料"),
          ),
        ]),
      ]),
    ]),
  ])
}

///|
fn import_images_button(
  emit : Emit[Msg],
  doc_id : String,
  class : String,
  label : String,
) -> Html {
  button(
    type_="button",
    class~,
    attrs=@html.Attrs::build().on_click(_ => {
      let command = emit(PrepareImageImport(doc_id))
      open_image_picker()
      command
    }),
    [span(label)],
  )
}

///|
fn image_picker(emit : Emit[Msg]) -> Html {
  input(
    input_type=@html.InputType::File,
    id="sigil-image-input",
    multiple=true,
    accept="image/*",
    class="sigil-file-input",
    on_change=emit.map(_ => ImportImages),
  )
}

///|
fn table_picker(emit : Emit[Msg]) -> Html {
  input(
    input_type=@html.InputType::File,
    id="sigil-table-input",
    multiple=true,
    accept=".csv,.tsv,.xlsx,.xls,.ods,.json",
    class="sigil-file-input",
    on_change=emit.map(_ => ImportTables),
  )
}

///|
fn image_card(
  emit : Emit[Msg],
  model : Model,
  doc_id : String,
  asset : ImageAsset,
) -> Html {
  div(class="sigil-asset-card", [
    img(src=asset.data_url, alt=asset.name, class="sigil-asset-image"),
    div(class="sigil-asset-meta", [
      span(class="sigil-asset-name", asset.name),
      div(class="sigil-asset-actions", [
        button(
          type_="button",
          class="sigil-button is-small",
          on_click=emit(OpenImagePreview(doc_id, asset.id)),
          tr(model.lang, "Preview", "预览"),
        ),
        button(
          type_="button",
          class="sigil-button is-small is-danger",
          on_click=emit(DeleteAsset(doc_id, asset.id)),
          tr(model.lang, "Remove", "删除"),
        ),
      ]),
    ]),
  ])
}

///|
enum LibraryKind {
  ImageLibrary
  TableLibrary
}

///|
fn library_group_header(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
  count : Int32,
  kind : LibraryKind,
) -> Html {
  let import_button = match kind {
    ImageLibrary =>
      import_images_button(
        emit,
        document.id,
        "sigil-sidebar-action",
        tr(model.lang, "Import", "导入"),
      )
    TableLibrary =>
      import_tables_button(
        emit,
        document.id,
        "sigil-sidebar-action",
        tr(model.lang, "Import", "导入"),
      )
  }
  div(class="sigil-library-group-header", [
    div(class="sigil-library-group-title", [
      span(class="sigil-library-group-name", document.title),
      if document.id == model.library_doc_id {
        span(class="sigil-library-current", tr(model.lang, "Current", "当前"))
      } else {
        @html.nothing
      },
      span(
        class="sigil-library-group-count",
        count.to_string() +
        (if kind is ImageLibrary {
          (if count == 1 {
            tr(model.lang, " image", " 张图片")
          } else {
            tr(model.lang, " images", " 张图片")
          })
        } else if count == 1 {
          tr(model.lang, " table", " 个表格")
        } else {
          tr(model.lang, " tables", " 个表格")
        }),
      ),
    ]),
    import_button,
  ])
}

///|
fn image_group(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let library = library_for_document(model, document.id)
  let cards : Array[Html] = []
  for asset in library.images {
    cards.push(image_card(emit, model, document.id, asset))
  }
  let body = if cards.is_empty() {
    div(
      class="sigil-library-empty",
      tr(model.lang, "No images yet.", "暂无图片。"),
    )
  } else {
    div(class="sigil-asset-grid", cards)
  }
  div(class="sigil-library-group", [
    library_group_header(
      emit,
      model,
      document,
      library.images.length(),
      ImageLibrary,
    ),
    body,
  ])
}

///|
fn images_tab(emit : Emit[Msg], model : Model) -> Html {
  let groups : Array[Html] = []
  for document in model.documents {
    groups.push(image_group(emit, model, document))
  }
  let content = if groups.is_empty() {
    div(
      class="sigil-assets-empty",
      tr(model.lang, "Create an email to add images.", "新建邮件后可添加图片。"),
    )
  } else {
    div(class="sigil-library-groups", groups)
  }
  div(class="sigil-images-tab", [
    div(class="sigil-images-header", [
      div(class="sigil-images-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Libraries / Images", "资源库 / 图片"),
        ),
        span(
          class="sigil-profile-title",
          tr(model.lang, "Image library", "图片库"),
        ),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Images are grouped by the email they belong to.",
            "图片按所属邮件分组展示。",
          ),
        ),
      ]),
    ]),
    content,
  ])
}

///|
fn import_tables_button(
  emit : Emit[Msg],
  doc_id : String,
  class : String,
  label : String,
) -> Html {
  button(
    type_="button",
    class~,
    attrs=@html.Attrs::build().on_click(_ => {
      let command = emit(PrepareTableImport(doc_id))
      open_table_picker()
      command
    }),
    [span(label)],
  )
}

///|
fn table_preview(csv : String) -> Html {
  let preview = @render.csv_preview(csv, 3, 4)
  let rows : Array[Html] = []
  let mut row_index = 0
  for row in preview {
    let cells : Array[Html] = []
    for cell in row {
      cells.push(span(class="sigil-table-mini-cell", cell))
    }
    rows.push(
      div(
        class=if row_index == 0 {
          "sigil-table-mini-row is-header"
        } else {
          "sigil-table-mini-row"
        },
        cells,
      ),
    )
    row_index = row_index + 1
  }
  div(class="sigil-table-mini", rows)
}

///|
fn table_card(
  emit : Emit[Msg],
  model : Model,
  doc_id : String,
  table : TableAsset,
) -> Html {
  let (rows, columns) = @render.csv_dimensions(table.csv)
  div(class="sigil-table-card", [
    table_preview(table.csv),
    div(class="sigil-table-card-main", [
      span(class="sigil-table-name", table.name),
      span(
        class="sigil-table-meta",
        rows.to_string() +
        tr(model.lang, " rows × ", " 行 × ") +
        columns.to_string() +
        tr(model.lang, " cols", " 列"),
      ),
    ]),
    div(class="sigil-table-actions", [
      button(
        type_="button",
        class="sigil-button is-small",
        on_click=emit(OpenTablePreview(doc_id, table.id)),
        tr(model.lang, "Preview", "预览"),
      ),
      button(
        type_="button",
        class="sigil-button is-small is-danger",
        on_click=emit(DeleteTable(doc_id, table.id)),
        tr(model.lang, "Remove", "删除"),
      ),
    ]),
  ])
}

///|
fn table_group(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let library = library_for_document(model, document.id)
  let cards : Array[Html] = []
  for table in library.tables {
    cards.push(table_card(emit, model, document.id, table))
  }
  let body = if cards.is_empty() {
    div(
      class="sigil-library-empty",
      tr(model.lang, "No tables yet.", "暂无表格。"),
    )
  } else {
    div(class="sigil-table-grid", cards)
  }
  div(class="sigil-library-group", [
    library_group_header(
      emit,
      model,
      document,
      library.tables.length(),
      TableLibrary,
    ),
    body,
  ])
}

///|
fn tables_tab(emit : Emit[Msg], model : Model) -> Html {
  let groups : Array[Html] = []
  for document in model.documents {
    groups.push(table_group(emit, model, document))
  }
  let content = if groups.is_empty() {
    div(
      class="sigil-assets-empty",
      tr(model.lang, "Create an email to add tables.", "新建邮件后可添加表格。"),
    )
  } else {
    div(class="sigil-library-groups", groups)
  }
  let notice = if model.table_notice == "" {
    @html.nothing
  } else {
    div(class="sigil-table-notice", [
      span(class="sigil-table-notice-text", model.table_notice),
      button(
        type_="button",
        class="sigil-table-notice-close",
        title=tr(model.lang, "Dismiss", "关闭"),
        on_click=emit(DismissTableNotice),
        [span("×")],
      ),
    ])
  }
  div(class="sigil-tables-tab", [
    div(class="sigil-images-header", [
      div(class="sigil-images-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Libraries / Tables", "资源库 / 表格"),
        ),
        span(
          class="sigil-profile-title",
          tr(model.lang, "Table library", "表格库"),
        ),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Tables are grouped by the email they belong to. Wide tables and long rows are split on import.",
            "表格按所属邮件分组展示；过宽或过长的表格会在导入时拆分。",
          ),
        ),
      ]),
    ]),
    notice,
    content,
  ])
}

///|
fn import_charts_button(
  emit : Emit[Msg],
  doc_id : String,
  class : String,
  label : String,
) -> Html {
  button(
    type_="button",
    class~,
    attrs=@html.Attrs::build().on_click(_ => {
      let command = emit(PrepareChartImport(doc_id))
      open_chart_picker()
      command
    }),
    [span(label)],
  )
}

///|
fn chart_picker(emit : Emit[Msg]) -> Html {
  input(
    input_type=@html.InputType::File,
    id="sigil-chart-input",
    multiple=true,
    accept=".txt,.chart,.sigil,text/plain",
    class="sigil-file-input",
    on_change=emit.map(_ => ImportCharts),
  )
}

///|
fn chart_card(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
  chart : ChartAsset,
) -> Html {
  let palette = chart_document_palette(document)
  div(class="sigil-table-card", [
    iframe(
      class="sigil-chart-mini-frame",
      title=chart.name,
      sandbox="allow-same-origin",
      attrs=@html.Attrs::build().srcdoc(
        chart_srcdoc(chart.kind, chart.text, palette, compact=true),
      ),
    ),
    div(class="sigil-table-card-main", [
      span(class="sigil-table-name", chart.name),
      span(class="sigil-table-meta", chart_kind_label(model.lang, chart.kind)),
    ]),
    div(class="sigil-table-actions", [
      button(
        type_="button",
        class="sigil-button is-small",
        on_click=emit(OpenChartPreview(document.id, chart.id)),
        tr(model.lang, "Edit", "编辑"),
      ),
      button(
        type_="button",
        class="sigil-button is-small is-danger",
        on_click=emit(DeleteChart(document.id, chart.id)),
        tr(model.lang, "Remove", "删除"),
      ),
    ]),
  ])
}

///|
fn chart_group(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let library = library_for_document(model, document.id)
  let cards : Array[Html] = []
  for chart in library.charts {
    cards.push(chart_card(emit, model, document, chart))
  }
  let body = if cards.is_empty() {
    div(
      class="sigil-library-empty",
      tr(model.lang, "No charts yet.", "暂无图表。"),
    )
  } else {
    div(class="sigil-table-grid", cards)
  }
  div(class="sigil-library-group", [
    div(class="sigil-library-group-header", [
      div(class="sigil-library-group-title", [
        span(class="sigil-library-group-name", document.title),
        if document.id == model.library_doc_id {
          span(class="sigil-library-current", tr(model.lang, "Current", "当前"))
        } else {
          @html.nothing
        },
        span(
          class="sigil-library-group-count",
          library.charts.length().to_string() +
          tr(model.lang, " charts", " 个图表"),
        ),
      ]),
      div(class="sigil-library-group-actions", [
        import_charts_button(
          emit,
          document.id,
          "sigil-sidebar-action",
          tr(model.lang, "Import", "导入"),
        ),
        button(
          type_="button",
          class="sigil-sidebar-action",
          on_click=emit(NewChart(document.id)),
          tr(model.lang, "+ New", "+ 新建"),
        ),
      ]),
    ]),
    body,
  ])
}

///|
fn charts_tab(emit : Emit[Msg], model : Model) -> Html {
  let groups : Array[Html] = []
  for document in model.documents {
    groups.push(chart_group(emit, model, document))
  }
  let content = if groups.is_empty() {
    div(
      class="sigil-assets-empty",
      tr(model.lang, "Create an email to add charts.", "新建邮件后可添加图表。"),
    )
  } else {
    div(class="sigil-library-groups", groups)
  }
  let palette_name = match find_document(model.documents, model.library_doc_id) {
    Some(document) => chart_document_palette(document)
    None => @types.chart_palette_default()
  }
  div(class="sigil-tables-tab", [
    div(class="sigil-images-header", [
      div(class="sigil-images-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Libraries / Charts", "资源库 / 图表"),
        ),
        span(
          class="sigil-profile-title",
          tr(model.lang, "Chart library", "图表库"),
        ),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Charts are plain-text files inserted with <chart:name>. Current palette: ",
            "图表是纯文本文件，通过 <chart:name> 插入。当前配色：",
          ) + palette_name,
        ),
      ]),
    ]),
    content,
  ])
}

///|
fn choice_button(selected : Bool, on_click : Cmd, label : String) -> Html {
  button(
    type_="button",
    class=if selected { "sigil-choice is-selected" } else { "sigil-choice" },
    on_click~,
    [span(label)],
  )
}

///|
fn accent_swatch(emit : Emit[Msg], model : Model, color : String) -> Html {
  button(
    type_="button",
    class=if model.prefs.accent == color {
      "sigil-swatch is-selected"
    } else {
      "sigil-swatch"
    },
    title=color,
    style=["background:" + color],
    on_click=emit(SetAccent(color)),
    ([] : Array[Html]),
  )
}

///|
fn settings_tab(emit : Emit[Msg], model : Model) -> Html {
  let theme_choices : Array[Html] = []
  theme_choices.push(
    choice_button(
      model.prefs.theme is Dark,
      emit(SetTheme(Dark)),
      tr(model.lang, "Dark", "深色"),
    ),
  )
  theme_choices.push(
    choice_button(
      model.prefs.theme is Light,
      emit(SetTheme(Light)),
      tr(model.lang, "Light", "浅色"),
    ),
  )
  let accents : Array[Html] = []
  for color in accent_palette {
    accents.push(accent_swatch(emit, model, color))
  }
  let density_choices : Array[Html] = []
  density_choices.push(
    choice_button(
      model.prefs.density is Comfortable,
      emit(SetDensity(Comfortable)),
      tr(model.lang, "Comfortable", "舒适"),
    ),
  )
  density_choices.push(
    choice_button(
      model.prefs.density is Compact,
      emit(SetDensity(Compact)),
      tr(model.lang, "Compact", "紧凑"),
    ),
  )
  let font_choices : Array[Html] = []
  for size in editor_font_sizes {
    font_choices.push(
      choice_button(
        model.prefs.editor_font_size == size,
        emit(SetEditorFontSize(size)),
        size.to_string() + " px",
      ),
    )
  }
  let language_choices : Array[Html] = []
  language_choices.push(
    choice_button(model.lang is En, emit(SetLang(En)), "English"),
  )
  language_choices.push(
    choice_button(model.lang is Zh, emit(SetLang(Zh)), "中文"),
  )
  div(class="sigil-settings-tab", [
    div(class="sigil-profile-sheet", [
      div(class="sigil-profile-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Application / Settings", "应用 / 设置"),
        ),
        span(class="sigil-profile-title", tr(model.lang, "Settings", "设置")),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Adjust how the workspace looks.",
            "调整工作区的外观。",
          ),
        ),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Appearance", "外观"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Choose a dark or light workspace.",
                "选择深色或浅色界面。",
              ),
            ),
          ]),
          div(class="sigil-choice-row", theme_choices),
        ]),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Accent color", "强调色"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Changes buttons and the status bar.",
                "改变按钮和状态栏的颜色。",
              ),
            ),
          ]),
          div(class="sigil-swatch-row", accents),
        ]),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Density", "界面密度"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Compact tightens spacing.",
                "紧凑模式减少留白。",
              ),
            ),
          ]),
          div(class="sigil-choice-row", density_choices),
        ]),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Editor font size", "编辑器字号"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Markup editor only; preview stays 16px.",
                "仅影响编辑器；预览保持 16px。",
              ),
            ),
          ]),
          div(class="sigil-choice-row", font_choices),
        ]),
      ]),
      div(class="sigil-settings-section", [
        div(class="sigil-settings-row", [
          div(class="sigil-settings-copy", [
            span(
              class="sigil-settings-title",
              tr(model.lang, "Language", "语言"),
            ),
            span(
              class="sigil-settings-description",
              tr(
                model.lang,
                "Interface language only.",
                "仅影响界面语言。",
              ),
            ),
          ]),
          div(class="sigil-choice-row", language_choices),
        ]),
      ]),
      div(class="sigil-settings-section", [
        span(
          class="sigil-settings-title",
          tr(model.lang, "AI model", "大模型"),
        ),
        div(class="sigil-field-grid", [
          label(class="sigil-field is-wide", [
            span(
              class="sigil-field-label",
              tr(model.lang, "API endpoint", "API 接口"),
            ),
            input(
              input_type=@html.InputType::Text,
              class="sigil-field-input",
              value=model.ai.endpoint,
              placeholder="https://api.openai.com/v1/chat/completions",
              on_input=emit.map(endpoint => SetAiEndpoint(endpoint)),
            ),
          ]),
          label(class="sigil-field", [
            span(
              class="sigil-field-label",
              tr(model.lang, "Model", "模型"),
            ),
            input(
              input_type=@html.InputType::Text,
              class="sigil-field-input",
              value=model.ai.model,
              placeholder="gpt-4o-mini",
              on_input=emit.map(name => SetAiModel(name)),
            ),
          ]),
          label(class="sigil-field", [
            span(
              class="sigil-field-label",
              tr(model.lang, "API key", "API 密钥"),
            ),
            input(
              input_type=@html.InputType::Password,
              class="sigil-field-input",
              value=model.ai.api_key,
              placeholder=tr(
                model.lang,
                "Optional for local models",
                "本地模型可留空",
              ),
              on_input=emit.map(key => SetAiApiKey(key)),
            ),
          ]),
          label(class="sigil-field is-wide", [
            span(
              class="sigil-field-label",
              tr(model.lang, "Asset prompt", "资产提示词"),
            ),
            textarea(
              class="sigil-field-input",
              style=["height:96px;padding:10px 12px;resize:vertical;"],
              value=model.ai_asset_prompt,
              placeholder=tr(
                model.lang,
                "Describe a chart or table, or paste JSON/CSV.",
                "描述图表或表格，或粘贴 JSON/CSV。",
              ),
              on_input=emit.map(prompt => AiAssetPromptChanged(prompt)),
              ([] : Array[Html]),
            ),
          ]),
        ]),
        div(
          class="sigil-settings-description",
          tr(
            model.lang,
            "OpenAI-compatible chat completions endpoint. The key is saved only in this browser's local storage.",
            "兼容 OpenAI 的对话补全接口。密钥仅保存在当前浏览器的本地存储中。",
          ),
        ),
      ]),
      mail_settings_section(emit, model),
      div(class="sigil-profile-footer", [
        span(
          class="sigil-profile-hint",
          tr(
            model.lang,
            "Appearance is saved locally; delivery settings are stored by the desktop backend.",
            "外观保存在本地；发送设置由桌面后端保存。",
          ),
        ),
        div(class="sigil-profile-actions", [
          button(
            type_="button",
            class="sigil-button",
            on_click=emit(ResetPrefs),
            tr(model.lang, "Reset appearance", "重置外观"),
          ),
        ]),
      ]),
    ]),
  ])
}

///|
fn styles_tab(emit : Emit[Msg], model : Model) -> Html {
  let target = match find_document(model.documents, model.style_doc_id) {
    Some(document) => Some(document)
    None =>
      if model.documents.is_empty() {
        None
      } else {
        Some(model.documents[0])
      }
  }
  match target {
    None =>
      div(class="sigil-styles-tab", [
        div(class="sigil-empty", [
          span(
            class="sigil-empty-title",
            tr(
              model.lang,
              "No document to style",
              "没有可设置样式的文档",
            ),
          ),
        ]),
      ])
    Some(target) => {
      let kinds : Array[StyleKind] = [
        LetterStyle,
        FooterStyle,
        SplitStyle,
        ChartStyle,
        SignatureStyle,
      ]
      let kind_buttons : Array[Html] = []
      for kind in kinds {
        let selected = model.style_view == kind
        kind_buttons.push(
          button(
            type_="button",
            class=if selected {
              "sigil-style-kind is-selected"
            } else {
              "sigil-style-kind"
            },
            on_click=emit(SelectStyleKind(kind)),
            [span(style_kind_label(model.lang, kind))],
          ),
        )
      }
      let current = normalized_style(
        model.style_view,
        current_style(target.source, model.style_view),
      )
      let option_buttons : Array[Html] = []
      for id in style_options(model.style_view) {
        let selected = current == id
        option_buttons.push(
          button(
            type_="button",
            class=if selected {
              "sigil-style-option is-selected"
            } else {
              "sigil-style-option"
            },
            title=style_label(model.lang, model.style_view, id),
            on_click=emit(ApplyStyle(id)),
            [
              span(
                class="sigil-style-option-name",
                style_label(model.lang, model.style_view, id),
              ),
              span(class="sigil-style-option-id", id),
            ],
          ),
        )
      }
      let preview_html = style_preview_html(model, target)
      div(class="sigil-styles-tab", [
        div(class="sigil-profile-heading", [
          span(
            class="sigil-profile-kicker",
            tr(model.lang, "Document / Styles", "文档 / 样式"),
          ),
          span(class="sigil-profile-title", tr(model.lang, "Styles", "样式")),
          span(
            class="sigil-profile-subtitle",
            tr(
              model.lang,
              "Preview and apply letter, footer, divider, and signature styles.",
              "预览并应用信纸、页脚、分隔符和签名样式。",
            ),
          ),
        ]),
        div(class="sigil-style-kind-tabs", kind_buttons),
        div(class="sigil-style-layout", [
          div(class="sigil-style-options", [
            div(
              class="sigil-style-options-title",
              style_kind_label(model.lang, model.style_view) +
              tr(model.lang, " styles", " 样式"),
            ),
            div(class="sigil-style-option-list", option_buttons),
          ]),
          div(class="sigil-style-preview", [
            div(class="sigil-style-preview-bar", [
              span(
                class="sigil-style-preview-title",
                tr(model.lang, "Live preview", "实时预览"),
              ),
              span(class="sigil-style-preview-doc", target.title),
            ]),
            iframe(
              class="sigil-style-preview-frame",
              title=tr(model.lang, "Style preview", "样式预览"),
              sandbox="allow-same-origin",
              attrs=@html.Attrs::build().srcdoc(preview_html),
            ),
          ]),
        ]),
      ])
    }
  }
}

///|
fn empty_workspace(emit : Emit[Msg], model : Model) -> Html {
  div(class="sigil-empty", [
    span(class="sigil-empty-kicker", tr(model.lang, "Workspace", "工作区")),
    span(
      class="sigil-empty-title",
      tr(model.lang, "No open tabs", "没有打开的标签页"),
    ),
    span(
      class="sigil-empty-text",
      tr(
        model.lang,
        "Open a document from the sidebar, or create a new email.",
        "从侧边栏打开文档，或新建一封邮件。",
      ),
    ),
    button(
      type_="button",
      class="sigil-button is-primary",
      on_click=emit(NewDocument),
      tr(model.lang, "New email", "新建邮件"),
    ),
  ])
}

///|
fn main_content(emit : Emit[Msg], model : Model) -> Html {
  if model.active_tab == images_tab_id && model.preview_kind is ImagePreview {
    preview_page(emit, model)
  } else if model.active_tab == tables_tab_id &&
    model.preview_kind is TablePreview {
    preview_page(emit, model)
  } else if model.active_tab == charts_tab_id &&
    model.preview_kind is ChartPreview {
    preview_page(emit, model)
  } else if model.active_tab == profile_tab_id {
    profile_tab(emit, model)
  } else if model.active_tab == images_tab_id {
    images_tab(emit, model)
  } else if model.active_tab == tables_tab_id {
    tables_tab(emit, model)
  } else if model.active_tab == charts_tab_id {
    charts_tab(emit, model)
  } else if model.active_tab == settings_tab_id {
    settings_tab(emit, model)
  } else if model.active_tab == styles_tab_id {
    styles_tab(emit, model)
  } else {
    match active_document(model) {
      Some(document) => compose_workspace(emit, model, document)
      None => empty_workspace(emit, model)
    }
  }
}

///|
fn preview_page(emit : Emit[Msg], model : Model) -> Html {
  let document = find_document(model.documents, model.preview_doc_id)
  let library = library_for_document(model, model.preview_doc_id)
  let email_title = match document {
    Some(value) => value.title
    None => tr(model.lang, "Missing email", "找不到邮件")
  }
  let (title, subtitle, body) = match model.preview_kind {
    NoPreview => (
      "",
      "",
      div(class="sigil-preview-empty", tr(model.lang, "Nothing to preview.", "没有可预览的内容。")),
    )
    ImagePreview =>
      match find_asset(library.images, model.preview_item_id) {
        Some(asset) =>
          (
            asset.name,
            email_title + " · " + tr(model.lang, "Image", "图片"),
            div(class="sigil-inline-preview-body", [
              img(
                src=asset.data_url,
                alt=asset.name,
                class="sigil-inline-image",
              ),
            ]),
          )
        None =>
          (
            tr(model.lang, "Image", "图片"),
            email_title,
            div(
              class="sigil-preview-empty",
              tr(model.lang, "Image not found.", "找不到图片。"),
            ),
          )
      }
    TablePreview =>
      match find_table(library.tables, model.preview_item_id) {
        Some(table) => {
          let draft = model.table_draft
          let preview_rows = @render.csv_preview(draft, 400, 64)
          let (row_count, column_count) = @render.csv_dimensions(draft)
          let widths : Array[Int32] = []
          let mut total_width = 0
          let mut column_index = 0
          while column_index < column_count {
            let mut max_length = 6
            for row in preview_rows {
              if column_index < row.length() {
                let length = row[column_index].length()
                if length > max_length {
                  max_length = length
                }
              }
            }
            let clamped = if max_length > 26 { 26 } else { max_length }
            let width = (if clamped < 8 { 8 } else { clamped }) * 10 + 24
            widths.push(width)
            total_width = total_width + width
            column_index = column_index + 1
          }
          let width_parts : Array[String] = []
          for width in widths {
            width_parts.push(width.to_string() + "px")
          }
          let grid_style = ["grid-template-columns:" + width_parts.join(" ")]
          let can_add_column = column_count < 5
          let can_add_row = row_count < 200
          let row_blocks : Array[Html] = []
          let mut row_index = 0
          for row in preview_rows {
            let row_cells : Array[Html] = []
            let mut cell_index = 0
            while cell_index < column_count {
              let value = if cell_index < row.length() {
                row[cell_index]
              } else {
                ""
              }
              let class_name = if row_index == 0 {
                "sigil-table-editor-cell is-header"
              } else {
                "sigil-table-editor-cell"
              }
              let cell_row = row_index
              let cell_column = cell_index
              row_cells.push(
                input(
                  input_type=@html.InputType::Text,
                  class=class_name,
                  value~,
                  maxlength=60,
                  on_input=emit.map(text => EditTableCell(
                    cell_row,
                    cell_column,
                    text,
                  )),
                ),
              )
              cell_index = cell_index + 1
            }
            let row_class = if row_index == 0 {
              "sigil-table-editor-row is-header"
            } else if row_index % 2 == 0 {
              "sigil-table-editor-row is-alternate"
            } else {
              "sigil-table-editor-row"
            }
            row_blocks.push(div(class=row_class, style=grid_style, row_cells))
            row_index = row_index + 1
          }
          let editor = if row_count == 0 {
            div(
              class="sigil-table-editor-empty",
              tr(model.lang, "This table is empty. Add a row to begin.", "此表格为空，添加一行开始编辑。"),
            )
          } else {
            div(class="sigil-table-editor-scroll", [
              div(class="sigil-table-editor", row_blocks),
            ])
          }
          let column_limit_hint = if can_add_column {
            tr(model.lang, "Add a column", "添加一列")
          } else {
            tr(model.lang, "Maximum 5 columns", "最多 5 列")
          }
          let toolbar = div(class="sigil-table-editor-toolbar", [
            div(class="sigil-table-editor-chips", [
              span(
                class="sigil-table-editor-chip",
                column_count.to_string() +
                " / 5" +
                tr(model.lang, " columns", " 列"),
              ),
              span(
                class="sigil-table-editor-chip",
                total_width.to_string() + "px",
              ),
              span(
                class="sigil-table-editor-chip",
                tr(model.lang, "60 chars / cell", "每格 60 字符"),
              ),
            ]),
            div(class="sigil-table-editor-controls", [
              button(
                type_="button",
                class="sigil-button is-small",
                title=tr(model.lang, "Add a row", "添加一行"),
                disabled=!can_add_row,
                on_click=emit(AddTableRow),
                [span(tr(model.lang, "+ Row", "+ 行"))],
              ),
              button(
                type_="button",
                class="sigil-button is-small is-primary",
                title=column_limit_hint,
                disabled=!can_add_column,
                on_click=emit(AddTableColumn),
                [span(tr(model.lang, "+ Column", "+ 列"))],
              ),
            ]),
          ])
          let footer = div(class="sigil-table-editor-footer", [
            span(class="sigil-table-editor-dot", ([] : Array[Html])),
            span(
              tr(
                model.lang,
                "Changes save automatically.",
                "修改会自动保存。",
              ),
            ),
          ])
          let panel = div(class="sigil-table-editor-panel", [
            toolbar,
            editor,
            footer,
          ])
          (
            table.name,
            email_title +
            " · " +
            row_count.to_string() +
            "×" +
            column_count.to_string(),
            div(class="sigil-inline-preview-body is-table", [
              div(class="sigil-table-editor-wrap", [panel]),
            ]),
          )
        }
        None =>
          (
            tr(model.lang, "Table", "表格"),
            email_title,
            div(
              class="sigil-preview-empty",
              tr(model.lang, "Table not found.", "找不到表格。"),
            ),
          )
      }
    ChartPreview =>
      match find_chart(library.charts, model.preview_item_id) {
        Some(chart) => {
          let palette = match document {
            Some(value) => chart_document_palette(value)
            None => @types.chart_palette_default()
          }
          let kind_buttons : Array[Html] = []
          for kind in chart_kinds() {
            kind_buttons.push(
              button(
                type_="button",
                class=if model.chart_kind_draft == kind {
                  "sigil-choice is-selected"
                } else {
                  "sigil-choice"
                },
                on_click=emit(EditChartKind(kind)),
                [span(chart_kind_label(model.lang, kind))],
              ),
            )
          }
          let preview_html = chart_srcdoc(
            model.chart_kind_draft,
            model.chart_text_draft,
            palette,
          )
          let panel = div(class="sigil-chart-editor-panel", [
            div(class="sigil-chart-editor-kinds", kind_buttons),
            textarea(
              class="sigil-chart-editor-textarea",
              value=model.chart_text_draft,
              placeholder=tr(
                model.lang,
                "title: Chart title\nlabels: A, B, C\nseries: Series 1 = 1, 2, 3",
                "title: 图表标题\nlabels: A, B, C\nseries: 系列 1 = 1, 2, 3",
              ),
              on_input=emit.map(text => EditChartText(text)),
              ([] : Array[Html]),
            ),
            div(class="sigil-chart-editor-preview", [
              iframe(
                class="sigil-chart-editor-preview-frame",
                title=chart.name,
                sandbox="allow-same-origin",
                attrs=@html.Attrs::build().srcdoc(preview_html),
              ),
            ]),
          ])
          (
            chart.name,
            email_title + " · " + chart_kind_label(model.lang, model.chart_kind_draft),
            div(class="sigil-inline-preview-body is-table", [
              div(class="sigil-table-editor-wrap", [panel]),
            ]),
          )
        }
        None =>
          (
            tr(model.lang, "Chart", "图表"),
            email_title,
            div(
              class="sigil-preview-empty",
              tr(model.lang, "Chart not found.", "找不到图表。"),
            ),
          )
      }
  }
  div(class="sigil-inline-preview", [
    div(class="sigil-inline-preview-bar", [
      button(
        type_="button",
        class="sigil-inline-preview-back",
        on_click=emit(ClosePreview),
        [span(tr(model.lang, "← Back", "← 返回"))],
      ),
      div(class="sigil-inline-preview-heading", [
        span(class="sigil-inline-preview-title", title),
        span(class="sigil-inline-preview-subtitle", subtitle),
      ]),
    ]),
    body,
  ])
}

///|
fn statusbar(model : Model) -> Html {
  let source = active_source(model)
  footer(class="sigil-statusbar", [
    div(class="sigil-status-group", [
      span(class="sigil-status-item is-strong", "Sigil"),
      span(
        class="sigil-status-item",
        tr(model.lang, "Local workspace", "本地工作区"),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Autosaved", "已自动保存"),
      ),
    ]),
    div(class="sigil-status-group", [
      span(
        class="sigil-status-item",
        tr(model.lang, "Docs ", "文档 ") +
        model.documents.length().to_string(),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Images ", "图片 ") + model.assets.length().to_string(),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Tables ", "表格 ") + model.tables.length().to_string(),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Charts ", "图表 ") + model.charts.length().to_string(),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Chars ", "字符 ") + source.length().to_string(),
      ),
      span(
        class="sigil-status-item",
        tr(model.lang, "Profile ", "资料 ") + model.profile.completeness(),
      ),
    ]),
  ])
}

///|
fn view(emit : Emit[Msg], model : Model) -> Html {
  let shell_attrs = @html.Attrs::build()
    .on_mousemove(event => emit(DragMoved(event.get_client_x())))
    .on_mouseup(_ => emit(EndDrag))
  let theme_class = prefs_theme_class(model.prefs)
  let density_class = prefs_density_class(model.prefs)
  let shell_class = if model.dragging {
    "sigil-app " + theme_class + " " + density_class + " is-dragging"
  } else {
    "sigil-app " + theme_class + " " + density_class
  }
  let shell_style = [
    "--sigil-accent:" + model.prefs.accent,
    "--sigil-theme:" + model.prefs.accent,
    "--sigil-editor-font-size:" +
    model.prefs.editor_font_size.to_string() +
    "px",
  ]
  div(class=shell_class, style=shell_style, attrs=shell_attrs, [
    titlebar(emit, model),
    image_picker(emit),
    table_picker(emit),
    chart_picker(emit),
    avatar_picker(emit),
    send_dialog(emit, model),
    div(class="sigil-body", [
      activity_bar(emit, model),
      sidebar(emit, model),
      div(class="sigil-main", [tabbar(emit, model), main_content(emit, model)]),
    ]),
    statusbar(model),
  ])
}

///|
fn sigil_app() -> @rabbita.Val[Html] {
  let (model, emit) = @rabbita.create_state(initial_model(), update=(
    model,
    msg,
    emit,
  ) => update(model, msg, emit))
  model.map(model => view(emit, model))
}

///|
#warnings("-alert_unstable")
fn main {
  init_email_export()
  @rabbita.new(sigil_app).mount("app")
}
