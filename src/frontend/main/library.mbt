///|
/// The images, tables, and folder tree owned by one email document.
#derive(Eq, ToJson, FromJson)
struct EmailLibrary {
  images : Array[ImageAsset]
  tables : Array[TableAsset]
  charts : Array[ChartAsset]
  folders : Array[String]
  image_folder : String
  table_folder : String
}

///|
/// Older library shape without charts, kept for migration.
#derive(FromJson)
struct LegacyEmailLibrary {
  images : Array[ImageAsset]
  tables : Array[TableAsset]
  folders : Array[String]
  image_folder : String
  table_folder : String
}

///|
fn empty_library() -> EmailLibrary {
  {
    images: [],
    tables: [],
    charts: [],
    folders: [],
    image_folder: "",
    table_folder: "",
  }
}

///|
fn library_key(doc_id : String) -> String {
  "sigil.library." + doc_id
}

///|
fn load_library_context() -> String {
  storage_get("sigil.library.context")
}

///|
fn save_library_context(doc_id : String) -> Unit {
  storage_set("sigil.library.context", doc_id)
}

///|
fn load_library(doc_id : String) -> EmailLibrary {
  if doc_id == "" {
    return empty_library()
  }
  let raw = storage_get(library_key(doc_id))
  if raw == "" {
    return empty_library()
  }
  let parsed = @json.parse(raw) catch { _ => return empty_library() }
  let library : EmailLibrary = @json.from_json(parsed) catch {
    _ => {
      let legacy : LegacyEmailLibrary = @json.from_json(parsed) catch {
        _ => return empty_library()
      }
      {
        images: legacy.images,
        tables: legacy.tables,
        charts: [],
        folders: legacy.folders,
        image_folder: legacy.image_folder,
        table_folder: legacy.table_folder,
      }
    }
  }
  let tables : Array[TableAsset] = []
  for table in library.tables {
    tables.push({
      ..table,
      csv: @render.csv_limit_table(table.csv, 5, 60),
    })
  }
  { ..library, tables }
}

///|
fn save_library(doc_id : String, library : EmailLibrary) -> Unit {
  if doc_id == "" {
    return
  }
  storage_set(library_key(doc_id), @json.ToJson::to_json(library).stringify())
}

///|
extern "js" fn storage_remove(key : String) -> Unit = "(key) => { try { localStorage.removeItem(key) } catch (e) {} }"

///|
fn clear_legacy_libraries() -> Unit {
  storage_remove("sigil.assets")
  storage_remove("sigil.tables")
  storage_remove("sigil.tables.folder")
}

///|
fn delete_library(doc_id : String) -> Unit {
  if doc_id == "" {
    return
  }
  storage_remove(library_key(doc_id))
}

///|
fn active_library(model : Model) -> EmailLibrary {
  {
    images: model.assets,
    tables: model.tables,
    charts: model.charts,
    folders: [],
    image_folder: "",
    table_folder: "",
  }
}

///|
fn save_active_library(model : Model) -> Unit {
  save_library(model.library_doc_id, active_library(model))
}

///|
fn commit_library(
  model : Model,
  doc_id : String,
  library : EmailLibrary,
) -> Model {
  save_library(doc_id, library)
  if doc_id == model.library_doc_id {
    {
      ..model,
      assets: library.images,
      tables: library.tables,
      charts: library.charts,
    }
  } else {
    model
  }
}

///|
fn commit_table_draft(model : Model) -> Model {
  let doc_id = model.preview_doc_id
  let table_id = model.preview_item_id
  if doc_id == "" || table_id == "" ||
    find_document(model.documents, doc_id) is None {
    return model
  }
  let library = library_for_document(model, doc_id)
  match find_table(library.tables, table_id) {
    None => model
    Some(_) =>
      commit_library(
        model,
        doc_id,
        {
          ..library,
          tables: with_table_csv(library.tables, table_id, model.table_draft),
        },
      )
  }
}

///|
fn commit_chart_draft(model : Model) -> Model {
  let doc_id = model.preview_doc_id
  let chart_id = model.preview_item_id
  if doc_id == "" || chart_id == "" ||
    find_document(model.documents, doc_id) is None {
    return model
  }
  let library = library_for_document(model, doc_id)
  match find_chart(library.charts, chart_id) {
    None => model
    Some(_) =>
      commit_library(
        model,
        doc_id,
        {
          ..library,
          charts: with_chart(
            library.charts,
            chart_id,
            model.chart_kind_draft,
            model.chart_text_draft,
          ),
        },
      )
  }
}

///|
fn import_target_id(model : Model) -> String {
  if model.import_doc_id != "" &&
    find_document(model.documents, model.import_doc_id) is Some(_) {
    model.import_doc_id
  } else {
    model.library_doc_id
  }
}

///|
fn library_for_document(model : Model, doc_id : String) -> EmailLibrary {
  if doc_id == model.library_doc_id {
    active_library(model)
  } else {
    load_library(doc_id)
  }
}

///|
fn model_with_library(
  model : Model,
  doc_id : String,
  library : EmailLibrary,
) -> Model {
  save_library_context(doc_id)
  {
    ..model,
    library_doc_id: doc_id,
    assets: library.images,
    tables: library.tables,
    charts: library.charts,
    table_notice: "",
  }
}

///|
fn load_library_model(model : Model, doc_id : String) -> Model {
  model_with_library(model, doc_id, load_library(doc_id))
}

///|
fn clear_library_model(model : Model) -> Model {
  model_with_library(model, "", empty_library())
}

///|
fn switch_library(model : Model, doc_id : String) -> Model {
  save_active_library(model)
  load_library_model(model, doc_id)
}

///|
fn first_open_document_id(
  open_tabs : Array[String],
  documents : Array[EmailDoc],
) -> String {
  for id in open_tabs {
    if find_document(documents, id) is Some(_) {
      return id
    }
  }
  if documents.is_empty() {
    ""
  } else {
    documents[0].id
  }
}

///|
fn library_context_id(
  documents : Array[EmailDoc],
  active_tab : String,
  open_tabs : Array[String],
) -> String {
  if find_document(documents, active_tab) is Some(_) {
    active_tab
  } else {
    first_open_document_id(open_tabs, documents)
  }
}
