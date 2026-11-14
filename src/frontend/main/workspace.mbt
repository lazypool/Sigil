///|
/// One email document in the local workspace.
#derive(Eq, ToJson, FromJson)
struct EmailDoc {
  id : String
  title : String
  source : String
}

///|
/// One image stored in the local workspace.
#derive(Eq, ToJson, FromJson)
struct ImageAsset {
  id : String
  name : String
  data_url : String
  folder : String
}

///|
/// Shape returned by the image picker before we place it in a folder.
#derive(Eq, FromJson)
struct IncomingImageAsset {
  id : String
  name : String
  data_url : String
}

///|
/// Workspace metadata persisted across launches. Image payloads live under a
/// separate key so ordinary typing does not rewrite large data URLs.
#derive(Eq, ToJson, FromJson)
struct WorkspaceMeta {
  documents : Array[EmailDoc]
  open_tabs : Array[String]
  active_tab : String
  split_pct : Double
  sidebar_open : Bool
  folders : Array[String]
  image_folder : String
}

///|
/// Previous workspace shape without image folders, kept for migration.
#derive(FromJson)
struct LegacyWorkspaceMeta {
  documents : Array[EmailDoc]
  open_tabs : Array[String]
  active_tab : String
  split_pct : Double
  sidebar_open : Bool
}

///|
/// Previous image shape without folder placement, kept for migration.
#derive(FromJson)
struct LegacyImageAsset {
  id : String
  name : String
  data_url : String
}

///|
let profile_tab_id = "@profile"

///|
let images_tab_id = "@images"

///|
let settings_tab_id = "@settings"

///|
let styles_tab_id = "@styles"

///|
extern "js" fn new_id(prefix : String) -> String = "(prefix) => prefix + '-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8)"

///|
fn document_template(lang : Lang) -> String {
  match lang {
    Zh =>
      (
        #|@theme #2563EB
        #|@footer legal
        #|@split wave
        #|@letter card
        #|
        #|**你好，Sigil！**
        #|
        #|Sigil 是一款基于 Markdown 的邮件排版标记语言，用简单的标记写出结构清晰、兼容邮件客户端的 HTML 邮件。它把内容与样式分开处理，让你专注写作，同时用统一的主题色、信纸、分隔符、页脚和签名保持整封邮件的视觉一致；生成的 HTML 不依赖脚本或外部字体，适合直接发送或导出。
        #|
        #|---
        #|
        #|Sigil 有如下的几个特点：
        #|
        #|1. *单一主题色*：整封邮件只使用一个强调色，其余文字和分隔保持中性灰。
        #|2. *内容与样式分离*：正文只关注内容，主题色、信纸、分隔符、页脚和签名由文档头部的指令统一控制。
        #|3. *邮件安全输出*：所有样式都内联为邮件客户端可识别的 HTML，不依赖脚本或外部字体。
        #|
        #|Sigil 额外的使用方法如下：
        #|
        #|- @theme 设置主题色，@letter 选择信纸，@split 选择分隔符，@footer 追加页脚。
        #|- <sig:classic> 插入个人签名，签名内容来自你的 Profile。
        #|- <link:https://example.com|示例链接> 生成主题色链接，<icon:mail> 插入内置图标。
        #|- <image:name> 插入图片库中的图片，$$ 块排版公式，:::chart 块绘制简单图表。
        #|
        #|你可以直接修改这段文字，或从左侧新建一封邮件开始写作。
        #|
        #|<sig:classic>
        #|
        #|```
        #|Hello, Sigil!
        #|
        #|Sigil is a Markdown-based markup language for email layout that produces clean, email-safe HTML.
        #|
        #|It uses one accent color and neutral grays, keeps content separate from style, and inlines all CSS without scripts or external fonts. Define the theme, letter, divider, footer, and signature at the top, then write the body with simple text, links, images, formulas, and charts. You can change the words directly, or create a new email from the sidebar to start writing.
        #|```
        #|
      )
    En =>
      (
        #|@theme #2563EB
        #|@footer legal
        #|@split wave
        #|@letter card
        #|
        #|**Hello, Sigil!**
        #|
        #|Sigil is a Markdown-based markup language for laying out email. It turns simple markup into clean, email-safe HTML with a clear structure. Content and style are handled separately, so you can focus on writing while a consistent theme color, letter, divider, footer, and signature keep the email visually coherent; the generated HTML uses no scripts or external fonts and is ready to send or export.
        #|
        #|---
        #|
        #|Sigil has the following features:
        #|
        #|1. *One theme color*: the whole email uses a single accent color, with neutral gray for all other text and dividers.
        #|2. *Content and style are separate*: the body only carries content, while the theme color, letter style, divider, footer, and signature are controlled by directives at the top of the document.
        #|3. *Email-safe output*: all styles are inlined into HTML that email clients understand, with no scripts or external fonts.
        #|
        #|Additional ways to use Sigil:
        #|
        #|- @theme sets the theme color, @letter selects the letter style, @split selects the divider, and @footer appends the footer.
        #|- <sig:classic> inserts the personal signature from your Profile.
        #|- <link:https://example.com|Example link> creates a theme-colored link, and <icon:mail> inserts a built-in icon.
        #|- <image:name> inserts an image from the library, $$ blocks typeset formulas, and :::chart blocks draw simple charts.
        #|
        #|Edit this text directly, or create a new email from the sidebar to start writing.
        #|
        #|<sig:classic>
        #|
        #|```
        #|你好，Sigil！
        #|
        #|Sigil 是一款基于 Markdown 的邮件排版标记语言，可生成简洁、兼容邮件客户端的 HTML。
        #|
        #|它只使用一个强调色和中性灰，内容与样式分离，所有 CSS 内联，不依赖脚本或外部字体。在文档开头设置主题色、信纸、分隔符、页脚和签名，然后用简单文本、链接、图片、公式和图表写正文。你可以直接修改文字，或从左侧新建一封邮件开始写作。
        #|```
        #|
      )
  }
}

///|
fn new_document(title : String, lang : Lang) -> EmailDoc {
  { id: new_id("doc"), title, source: document_template(lang), }
}

///|
fn default_workspace(lang : Lang) -> WorkspaceMeta {
  let doc = new_document(tr(lang, "Untitled Email", "未命名邮件"), lang)
  {
    documents: [doc],
    open_tabs: [doc.id],
    active_tab: doc.id,
    split_pct: 58.0,
    sidebar_open: true,
    folders: [],
    image_folder: "",
  }
}

///|
fn contains_id(ids : Array[String], id : String) -> Bool {
  for item in ids {
    if item == id {
      return true
    }
  }
  false
}

///|
fn ensure_tab(ids : Array[String], id : String) -> Array[String] {
  let result = ids.copy()
  if !contains_id(result, id) {
    result.push(id)
  }
  result
}

///|
fn remove_tab(ids : Array[String], id : String) -> Array[String] {
  let result : Array[String] = []
  for item in ids {
    if item != id {
      result.push(item)
    }
  }
  result
}

///|
fn find_document(documents : Array[EmailDoc], id : String) -> EmailDoc? {
  for document in documents {
    if document.id == id {
      return Some(document)
    }
  }
  None
}

///|
fn with_document_source(
  documents : Array[EmailDoc],
  id : String,
  source : String,
) -> Array[EmailDoc] {
  let result : Array[EmailDoc] = []
  for document in documents {
    if document.id == id {
      result.push({ ..document, source, })
    } else {
      result.push(document)
    }
  }
  result
}

///|
fn with_document_title(
  documents : Array[EmailDoc],
  id : String,
  title : String,
) -> Array[EmailDoc] {
  let result : Array[EmailDoc] = []
  for document in documents {
    if document.id == id {
      result.push({ ..document, title, })
    } else {
      result.push(document)
    }
  }
  result
}

///|
fn normalize_workspace(workspace : WorkspaceMeta, lang : Lang) -> WorkspaceMeta {
  let workspace = if workspace.documents.is_empty() {
    default_workspace(lang)
  } else {
    workspace
  }
  let documents = workspace.documents
  let first_doc = documents[0].id
  let open_tabs : Array[String] = []
  for id in workspace.open_tabs {
    let valid = id == profile_tab_id ||
      id == images_tab_id ||
      id == settings_tab_id ||
      id == styles_tab_id ||
      find_document(documents, id) is Some(_)
    if valid && !contains_id(open_tabs, id) {
      open_tabs.push(id)
    }
  }
  if open_tabs.is_empty() {
    open_tabs.push(first_doc)
  }
  let active_tab = if contains_id(open_tabs, workspace.active_tab) {
    workspace.active_tab
  } else {
    open_tabs[0]
  }
  let folders : Array[String] = []
  for folder in workspace.folders {
    if folder != "" && !contains_id(folders, folder) {
      folders.push(folder)
    }
  }
  let image_folder = if workspace.image_folder == "" ||
    contains_id(folders, workspace.image_folder) {
    workspace.image_folder
  } else {
    ""
  }
  {
    documents,
    open_tabs,
    active_tab,
    split_pct: workspace.split_pct,
    sidebar_open: workspace.sidebar_open,
    folders,
    image_folder,
  }
}

///|
fn load_workspace(lang : Lang) -> WorkspaceMeta {
  let raw = storage_get("sigil.workspace")
  if raw == "" {
    return default_workspace(lang)
  }
  let parsed = @json.parse(raw) catch { _ => return default_workspace(lang) }
  let workspace : WorkspaceMeta = @json.from_json(parsed) catch {
    _ => {
      let legacy : LegacyWorkspaceMeta = @json.from_json(parsed) catch {
        _ => return default_workspace(lang)
      }
      {
        documents: legacy.documents,
        open_tabs: legacy.open_tabs,
        active_tab: legacy.active_tab,
        split_pct: legacy.split_pct,
        sidebar_open: legacy.sidebar_open,
        folders: [],
        image_folder: "",
      }
    }
  }
  normalize_workspace(workspace, lang)
}

///|
fn save_workspace(workspace : WorkspaceMeta) -> Unit {
  storage_set("sigil.workspace", @json.ToJson::to_json(workspace).stringify())
}

///|
fn load_assets() -> Array[ImageAsset] {
  let raw = storage_get("sigil.assets")
  if raw == "" {
    return []
  }
  let parsed = @json.parse(raw) catch { _ => return [] }
  let assets : Array[ImageAsset] = @json.from_json(parsed) catch {
    _ => {
      let legacy : Array[LegacyImageAsset] = @json.from_json(parsed) catch {
        _ => return []
      }
      let migrated : Array[ImageAsset] = []
      for asset in legacy {
        migrated.push({
          id: asset.id,
          name: asset.name,
          data_url: asset.data_url,
          folder: "",
        })
      }
      return migrated
    }
  }
  assets
}

///|
fn save_assets(assets : Array[ImageAsset]) -> Unit {
  storage_set("sigil.assets", @json.ToJson::to_json(assets).stringify())
}

///|
fn find_asset(assets : Array[ImageAsset], id : String) -> ImageAsset? {
  for asset in assets {
    if asset.id == id {
      return Some(asset)
    }
  }
  None
}

///|
fn has_asset_name(assets : Array[ImageAsset], name : String) -> Bool {
  for asset in assets {
    if asset.name == name {
      return true
    }
  }
  false
}

///|
fn unique_asset_name(assets : Array[ImageAsset], name : String) -> String {
  let base = if name == "" { "image" } else { name }
  let mut candidate = base
  let mut suffix = 2
  while has_asset_name(assets, candidate) {
    candidate = base + "-" + suffix.to_string()
    suffix = suffix + 1
  }
  candidate
}

///|
fn merge_assets(
  existing : Array[ImageAsset],
  imported : Array[IncomingImageAsset],
  folder : String,
) -> Array[ImageAsset] {
  let result = existing.copy()
  for asset in imported {
    let name = unique_asset_name(result, asset.name)
    result.push({ id: asset.id, name, data_url: asset.data_url, folder, })
  }
  result
}

///|
fn move_asset(
  assets : Array[ImageAsset],
  id : String,
  folder : String,
) -> Array[ImageAsset] {
  let result : Array[ImageAsset] = []
  for asset in assets {
    if asset.id == id {
      result.push({ ..asset, folder, })
    } else {
      result.push(asset)
    }
  }
  result
}

///|
fn assets_in_folder(
  assets : Array[ImageAsset],
  folder : String,
) -> Array[ImageAsset] {
  let result : Array[ImageAsset] = []
  for asset in assets {
    if asset.folder == folder {
      result.push(asset)
    }
  }
  result
}

///|
fn folder_leaf(path : String) -> String {
  match path.rev_split_once("/") {
    Some((_, leaf)) => leaf.to_owned()
    None => if path == "" { "Workspace" } else { path }
  }
}

///|
fn folder_depth(path : String) -> Int32 {
  if path == "" {
    return 0
  }
  let mut depth = 1
  for ch in path {
    if ch == '/' {
      depth = depth + 1
    }
  }
  depth
}

///|
fn folder_path(parent : String, name : String) -> String? {
  let name = name.trim().to_owned()
  if name == "" {
    return None
  }
  let name = name.replace_all(old="/", new="-")
  if parent == "" {
    Some(name)
  } else {
    Some(parent + "/" + name)
  }
}

///|
fn remove_asset(assets : Array[ImageAsset], id : String) -> Array[ImageAsset] {
  let result : Array[ImageAsset] = []
  for asset in assets {
    if asset.id != id {
      result.push(asset)
    }
  }
  result
}

///|
fn asset_markup(name : String) -> String {
  "\n<image:" + name + ">\n"
}

///|
extern "js" fn open_image_picker() -> Unit = "() => { const el = document.getElementById('sigil-image-input'); if (!el) return; el.value = ''; el.click(); }"

///|
extern "js" fn read_image_input_promise() -> @js_async.Promise[String] =
  #| () => new Promise((resolve) => {
  #|   const input = document.getElementById('sigil-image-input');
  #|   if (!input || !input.files || input.files.length === 0) {
  #|     resolve('[]');
  #|     return;
  #|   }
  #|   const files = Array.from(input.files);
  #|   (async () => {
  #|     const items = [];
  #|     for (const file of files) {
  #|       const data = await new Promise((res) => {
  #|         const reader = new FileReader();
  #|         reader.onload = () => res(String(reader.result || ''));
  #|         reader.onerror = () => res('');
  #|         reader.readAsDataURL(file);
  #|       });
  #|       if (data) {
  #|         items.push({
  #|           id: 'img-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8),
  #|           name: file.name || 'image',
  #|           data_url: data
  #|         });
  #|       }
  #|     }
  #|     input.value = '';
  #|     resolve(JSON.stringify(items));
  #|   })();
  #| })

///|
async fn import_images_json() -> String noraise {
  @js_async.run_promise(_ => read_image_input_promise()) catch {
    _ => "[]"
  }
}

///|
async fn import_images_task() -> String noraise {
  import_images_json()
}

///|
fn parse_assets(json : String) -> Array[IncomingImageAsset] {
  let parsed = @json.parse(json) catch { _ => return [] }
  let assets : Array[IncomingImageAsset] = @json.from_json(parsed) catch {
    _ => return []
  }
  assets
}

///|
extern "js" fn insert_at_cursor(markup : String) -> String = "(markup) => { const el = document.getElementById('sigil-editor'); if (!el) return ''; const start = el.selectionStart ?? el.value.length; const end = el.selectionEnd ?? start; const next = el.value.slice(0, start) + markup + el.value.slice(end); el.value = next; el.selectionStart = el.selectionEnd = start + markup.length; el.focus(); return next; }"
