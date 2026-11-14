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
  option,
  select,
  span,
  textarea,
}

///|
#derive(Eq)
struct Model {
  documents : Array[EmailDoc]
  assets : Array[ImageAsset]
  open_tabs : Array[String]
  active_tab : String
  split_pct : Double
  dragging : Bool
  sidebar_open : Bool
  folders : Array[String]
  image_folder : String
  creating_folder : Bool
  folder_draft : String
  profile : Profile
  profile_draft : Profile
  lang : Lang
  prefs : Prefs
  style_view : StyleKind
  style_doc_id : String
}

///|
enum Msg {
  SourceChanged(String)
  RenameDocument(String)
  SelectFolder(String)
  ToggleNewFolder
  FolderDraftChanged(String)
  CreateFolder
  MoveAsset(String, String)
  BeginDrag
  DragMoved(Double)
  EndDrag
  SelectTab(String)
  OpenDocument(String)
  CloseTab(String)
  NewDocument
  ToggleSidebar
  OpenProfile
  OpenImages
  RevertProfile
  ProfileFieldChanged(ProfileField, String)
  SaveProfile
  ImportImages
  AssetsImported(String)
  InsertAsset(String)
  DeleteAsset(String)
  ToggleLanguage
  OpenSettings
  SetTheme(AppTheme)
  SetAccent(String)
  SetDensity(Density)
  SetEditorFontSize(Int32)
  ResetPrefs
  SetLang(Lang)
  ImportAvatar
  AvatarImported(String)
  RemoveAvatar
  OpenStyles
  SelectStyleKind(StyleKind)
  ApplyStyle(String)
}

///|
fn initial_model() -> Model {
  let lang = load_lang()
  let workspace = load_workspace(lang)
  let profile = load_profile()
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
    assets: load_assets(),
    open_tabs: workspace.open_tabs,
    active_tab: workspace.active_tab,
    split_pct: workspace.split_pct,
    dragging: false,
    sidebar_open: workspace.sidebar_open,
    folders: workspace.folders,
    image_folder: workspace.image_folder,
    creating_folder: false,
    folder_draft: "",
    profile,
    profile_draft: profile,
    lang,
    prefs: load_prefs(),
    style_view: LetterStyle,
    style_doc_id,
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
    folders: model.folders,
    image_folder: model.image_folder,
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
fn target_document_id(model : Model) -> String? {
  match active_document(model) {
    Some(document) => Some(document.id)
    None =>
      if model.documents.is_empty() {
        None
      } else {
        Some(model.documents[0].id)
      }
  }
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
    SelectFolder(folder) =>
      if folder == "" || contains_id(model.folders, folder) {
        let next = { ..model, image_folder: folder, }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    ToggleNewFolder =>
      (
        { ..model, creating_folder: !model.creating_folder, folder_draft: "", },
        @rabbita.none,
      )
    FolderDraftChanged(value) =>
      ({ ..model, folder_draft: value, }, @rabbita.none)
    CreateFolder =>
      match folder_path(model.image_folder, model.folder_draft) {
        None => (model, @rabbita.none)
        Some(path) =>
          if contains_id(model.folders, path) {
            (model, @rabbita.none)
          } else {
            let folders = model.folders.copy()
            folders.push(path)
            let next = {
              ..model,
              folders,
              image_folder: path,
              creating_folder: false,
              folder_draft: "",
            }
            persist(next)
            (next, @rabbita.none)
          }
      }
    MoveAsset(id, folder) => {
      let assets = move_asset(model.assets, id, folder)
      save_assets(assets)
      ({ ..model, assets, }, @rabbita.none)
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
        let next = { ..model, active_tab: id, }
        persist(next)
        (next, @rabbita.none)
      } else {
        (model, @rabbita.none)
      }
    OpenDocument(id) => {
      let valid = id == profile_tab_id ||
        id == images_tab_id ||
        id == settings_tab_id ||
        id == styles_tab_id ||
        find_document(model.documents, id) is Some(_)
      if valid {
        let next = {
          ..model,
          open_tabs: ensure_tab(model.open_tabs, id),
          active_tab: id,
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
      let next = { ..model, open_tabs, active_tab, }
      persist(next)
      (next, @rabbita.none)
    }
    NewDocument => {
      let document = new_document(
        tr(model.lang, "Untitled ", "未命名 ") +
        (model.documents.length() + 1).to_string(),
        model.lang,
      )
      let documents = model.documents.copy()
      documents.push(document)
      let next = {
        ..model,
        documents,
        open_tabs: ensure_tab(model.open_tabs, document.id),
        active_tab: document.id,
      }
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
      (next, @rabbita.none)
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
    AssetsImported(json) => {
      let imported = parse_assets(json)
      if imported.is_empty() {
        (model, @rabbita.none)
      } else {
        let assets = merge_assets(model.assets, imported, model.image_folder)
        save_assets(assets)
        let next = {
          ..model,
          assets,
          open_tabs: ensure_tab(model.open_tabs, images_tab_id),
          active_tab: images_tab_id,
        }
        persist(next)
        (next, @rabbita.none)
      }
    }
    InsertAsset(id) =>
      match find_asset(model.assets, id) {
        None => (model, @rabbita.none)
        Some(asset) =>
          match target_document_id(model) {
            None => (model, @rabbita.none)
            Some(document_id) =>
              match find_document(model.documents, document_id) {
                None => (model, @rabbita.none)
                Some(document) => {
                  let markup = asset_markup(asset.name)
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
                      document_id,
                      source,
                    ),
                    open_tabs: ensure_tab(model.open_tabs, document_id),
                    active_tab: document_id,
                  }
                  persist(next)
                  (next, @rabbita.none)
                }
              }
          }
      }
    DeleteAsset(id) => {
      let assets = remove_asset(model.assets, id)
      save_assets(assets)
      ({ ..model, assets, }, @rabbita.none)
    }
    ToggleLanguage => {
      let lang = other_lang(model.lang)
      save_lang(lang)
      ({ ..model, lang, }, @rabbita.none)
    }
  }
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
  header(class="sigil-titlebar", [
    div(class="sigil-titlebar-left", [
      div(class="sigil-logo", [span("S")]),
      span(class="sigil-wordmark", "Sigil"),
      span(class="sigil-titlebar-divider", "/"),
      span(
        class="sigil-document-title",
        tr(model.lang, "Local Workspace", "本地工作区"),
      ),
    ]),
    div(class="sigil-titlebar-actions", [
      button(
        type_="button",
        class="sigil-lang-button",
        title=tr(model.lang, "Switch language", "切换语言"),
        on_click=emit(ToggleLanguage),
        [span(lang_label(model.lang))],
      ),
      div(class="sigil-theme-control", [
        span(class="sigil-control-label", tr(model.lang, "Theme", "主题色")),
        input(
          input_type=@html.InputType::Color,
          class="sigil-theme-color",
          value="#2563EB",
          attrs=@html.Attrs::build().disabled(true),
        ),
        span(class="sigil-theme-value", "#2563EB"),
      ]),
      export_button(model),
      button(
        type_="button",
        class="sigil-send",
        disabled=true,
        tr(model.lang, "Send", "发送"),
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
  children.push(div(class="sigil-tabs-spacer", ([] : Array[Html])))
  children.push(
    div(class="sigil-tab-meta", [
      span(tr(model.lang, "Autosaved", "已自动保存")),
      span(class="sigil-tab-meta-sep", "/"),
      span(model.profile.completeness() + tr(model.lang, " profile", " 资料")),
    ]),
  )
  div(class="sigil-tabs", children)
}

///|
fn folder_label(lang : Lang, path : String) -> String {
  if path == "" {
    tr(lang, "Workspace", "工作区")
  } else {
    folder_leaf(path)
  }
}

///|
fn folder_asset_count(model : Model, folder : String) -> Int32 {
  assets_in_folder(model.assets, folder).length()
}

///|
fn folder_row(emit : Emit[Msg], model : Model, path : String) -> Html {
  let selected = model.image_folder == path
  let indent = (7 + folder_depth(path) * 12).to_string()
  button(
    type_="button",
    class=if selected {
      "sigil-folder-row is-active"
    } else {
      "sigil-folder-row"
    },
    title=if path == "" {
      tr(model.lang, "Workspace root", "工作区根目录")
    } else {
      path
    },
    style=["padding-left:" + indent + "px"],
    on_click=emit(SelectFolder(path)),
    [
      span(class="sigil-folder-name", folder_label(model.lang, path)),
      span(
        class="sigil-folder-count",
        folder_asset_count(model, path).to_string(),
      ),
    ],
  )
}

///|
fn folder_rows(emit : Emit[Msg], model : Model) -> Array[Html] {
  let rows : Array[Html] = []
  rows.push(folder_row(emit, model, ""))
  for folder in model.folders {
    rows.push(folder_row(emit, model, folder))
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
      button(
        type_="button",
        class=if active { "sigil-doc-row is-active" } else { "sigil-doc-row" },
        title=document.title,
        on_click=emit(OpenDocument(document.id)),
        [
          span(class="sigil-doc-dot", ([] : Array[Html])),
          span(class="sigil-doc-name", document.title),
          span(class="sigil-doc-chars", document.source.length().to_string()),
        ],
      ),
    )
  }
  let thumbs : Array[Html] = []
  for asset in assets_in_folder(model.assets, model.image_folder) {
    thumbs.push(
      button(
        type_="button",
        class="sigil-side-thumb",
        title=tr(model.lang, "Insert ", "插入 ") + asset.name,
        on_click=emit(InsertAsset(asset.id)),
        [
          img(
            src=asset.data_url,
            alt=asset.name,
            class="sigil-side-thumb-image",
          ),
        ],
      ),
    )
  }
  let image_content = if thumbs.is_empty() {
    div(
      class="sigil-sidebar-empty",
      tr(model.lang, "No images in this folder.", "此文件夹暂无图片。"),
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
          "sigil-sidebar-action",
          tr(model.lang, "Import", "导入"),
        ),
      ]),
      div(class="sigil-folder-list", folder_rows(emit, model)),
      div(
        class="sigil-sidebar-folder-label",
        folder_label(model.lang, model.image_folder),
      ),
      image_content,
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
        span(
          class="sigil-pane-meta",
          document.source.length().to_string() +
          tr(model.lang, " chars", " 字符"),
        ),
      ]),
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
fn preview_pane(lang : Lang, preview_html : String) -> Html {
  let preview_attrs = @html.Attrs::build().srcdoc(preview_html)
  div(class="sigil-preview", [
    div(class="sigil-pane-bar", [
      span(class="sigil-pane-title", tr(lang, "Preview", "预览")),
      span(
        class="sigil-pane-meta",
        tr(lang, "640px reading column", "640px 阅读栏"),
      ),
    ]),
    div(class="sigil-preview-stage", [
      iframe(
        class="sigil-preview-frame",
        title=tr(lang, "Sigil preview", "Sigil 预览"),
        sandbox="allow-same-origin",
        attrs=preview_attrs,
      ),
    ]),
  ])
}

///|
fn compose_workspace(
  emit : Emit[Msg],
  model : Model,
  document : EmailDoc,
) -> Html {
  let result = @parser.parse(document.source)
  let preview_html = @render.render_email_html(
    result.document,
    to_core_profile(model.profile),
    asset_map(model.assets),
  )
  div(class="sigil-workspace", [
    editor_pane(emit, model, document, result.diagnostics),
    div(
      class="sigil-splitter",
      title=tr(model.lang, "Drag to resize", "拖动调整宽度"),
      on_mousedown=emit.map(_ => BeginDrag),
      [div(class="sigil-splitter-grip", ([] : Array[Html]))],
    ),
    preview_pane(model.lang, preview_html),
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
            "Stored in the workspace and reused by signature and footer themes. The document never stores personal data.",
            "资料保存在工作区中，供签名和页脚主题复用。文档本身不保存个人资料。",
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
              "The profile belongs to this workspace and stays available on every launch.",
              "资料属于当前工作区，每次启动应用时都可用。",
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
                "Shown in the title bar, profile summary, and signature themes.",
                "用于标题栏、资料摘要和签名主题。",
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
            "Changes apply to signature and footer themes. Profile fields are optional.",
            "更改会用于签名和页脚主题。资料字段均为可选项。",
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
fn import_images_button(class : String, label : String) -> Html {
  button(
    type_="button",
    class~,
    attrs=@html.Attrs::build().on_click(_ => {
      open_image_picker()
      @rabbita.none
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
fn folder_select(emit : Emit[Msg], model : Model, asset : ImageAsset) -> Html {
  let options : Array[Html] = []
  options.push(
    option(value="", selected=asset.folder == "", folder_label(model.lang, "")),
  )
  for folder in model.folders {
    options.push(
      option(value=folder, selected=asset.folder == folder, folder_leaf(folder)),
    )
  }
  select(
    class="sigil-folder-select",
    title=tr(model.lang, "Move image to folder", "移动到文件夹"),
    on_change=emit.map(folder => MoveAsset(asset.id, folder)),
    options,
  )
}

///|
fn images_tab(emit : Emit[Msg], model : Model) -> Html {
  let cards : Array[Html] = []
  for asset in assets_in_folder(model.assets, model.image_folder) {
    cards.push(
      div(class="sigil-asset-card", [
        img(src=asset.data_url, alt=asset.name, class="sigil-asset-image"),
        div(class="sigil-asset-meta", [
          span(class="sigil-asset-name", asset.name),
          folder_select(emit, model, asset),
          div(class="sigil-asset-actions", [
            button(
              type_="button",
              class="sigil-button is-small",
              on_click=emit(InsertAsset(asset.id)),
              tr(model.lang, "Insert", "插入"),
            ),
            button(
              type_="button",
              class="sigil-button is-small is-danger",
              on_click=emit(DeleteAsset(asset.id)),
              tr(model.lang, "Remove", "删除"),
            ),
          ]),
        ]),
      ]),
    )
  }
  let content = if cards.is_empty() {
    div(class="sigil-assets-empty", [
      span(
        class="sigil-assets-empty-title",
        tr(model.lang, "No images in this folder", "此文件夹暂无图片"),
      ),
      span(
        class="sigil-assets-empty-text",
        tr(
          model.lang,
          "Import images into this folder, or move existing images here with the folder menu on each card.",
          "可将图片导入此文件夹，或用每张图片卡片上的文件夹菜单移动到这里。",
        ),
      ),
    ])
  } else {
    div(class="sigil-asset-grid", cards)
  }
  let folder_create = if model.creating_folder {
    div(class="sigil-folder-create", [
      input(
        class="sigil-field-input sigil-folder-input",
        value=model.folder_draft,
        placeholder=tr(model.lang, "Folder name", "文件夹名称"),
        on_input=emit.map(value => FolderDraftChanged(value)),
      ),
      button(
        type_="button",
        class="sigil-button is-small is-primary",
        on_click=emit(CreateFolder),
        tr(model.lang, "Create", "创建"),
      ),
      button(
        type_="button",
        class="sigil-button is-small",
        on_click=emit(ToggleNewFolder),
        tr(model.lang, "Cancel", "取消"),
      ),
      span(
        class="sigil-folder-create-hint",
        tr(model.lang, "Created inside ", "创建于 ") +
        folder_label(model.lang, model.image_folder),
      ),
    ])
  } else {
    @html.nothing
  }
  div(class="sigil-images-tab", [
    div(class="sigil-images-header", [
      div(class="sigil-images-heading", [
        span(
          class="sigil-profile-kicker",
          tr(model.lang, "Workspace / Images", "工作区 / 图片"),
        ),
        span(
          class="sigil-profile-title",
          tr(model.lang, "Image library", "图片库"),
        ),
        span(
          class="sigil-profile-subtitle",
          tr(
            model.lang,
            "Images are organized into workspace folders, not stored as absolute paths. Inserting one adds an <image:...> line to the active email.",
            "图片按工作区文件夹组织，不使用绝对路径。插入图片会向当前邮件添加一行 <image:...> 标记。",
          ),
        ),
      ]),
      div(class="sigil-images-actions", [
        button(
          type_="button",
          class="sigil-button",
          on_click=emit(ToggleNewFolder),
          tr(model.lang, "New folder", "新建文件夹"),
        ),
        import_images_button(
          "sigil-button is-primary",
          tr(model.lang, "Import images", "导入图片"),
        ),
      ]),
    ]),
    folder_create,
    div(class="sigil-images-body", [
      div(class="sigil-folder-tree", [
        div(
          class="sigil-folder-tree-title",
          tr(model.lang, "Folders", "文件夹"),
        ),
        div(class="sigil-folder-list", folder_rows(emit, model)),
      ]),
      div(class="sigil-images-content", [
        div(class="sigil-folder-header", [
          span(
            class="sigil-folder-title",
            folder_label(model.lang, model.image_folder),
          ),
          span(
            class="sigil-folder-subtitle",
            folder_asset_count(model, model.image_folder).to_string() +
            tr(model.lang, " images", " 张图片"),
          ),
        ]),
        content,
      ]),
    ]),
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
            "Customize how the Sigil workspace looks. These settings never change the email theme color.",
            "自定义 Sigil 工作区的外观。这些设置不会改变邮件的主题色。",
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
                "Switch between dark and light application chrome.",
                "在深色和浅色应用界面之间切换。",
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
                "Used by the application chrome and status bar.",
                "用于应用界面和状态栏。",
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
                "Compact mode reduces padding across the workspace.",
                "紧凑模式会减少工作区各处的留白。",
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
                "Only the markup editor changes. The email preview keeps its 16px reading size.",
                "仅改变标记编辑器；邮件预览仍保持 16px 阅读字号。",
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
                "Application interface language. Document content is never translated.",
                "应用界面语言。文档内容不会被翻译。",
              ),
            ),
          ]),
          div(class="sigil-choice-row", language_choices),
        ]),
      ]),
      div(class="sigil-profile-footer", [
        span(
          class="sigil-profile-hint",
          tr(
            model.lang,
            "Appearance settings are stored locally and restored on launch.",
            "外观设置保存在本地，下次启动时自动恢复。",
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
              "Preview and apply the basic letter, footer, divider, and signature styles to the selected email.",
              "预览并应用信纸、页脚、分隔符和签名的基础样式。",
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
  if model.active_tab == profile_tab_id {
    profile_tab(emit, model)
  } else if model.active_tab == images_tab_id {
    images_tab(emit, model)
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
    avatar_picker(emit),
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
  @rabbita.new(sigil_app).mount("app")
}
