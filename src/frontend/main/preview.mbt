///|
fn asset_map(assets : Array[ImageAsset]) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  for asset in assets {
    result[asset.name] = asset.data_url
  }
  result
}

///|
fn render_source(
  model : Model,
  source : String,
) -> (String, Array[@types.Diagnostic]) {
  let result = @parser.parse(source)
  let html = @render.render_email_html(
    result.document,
    to_core_profile(model.profile),
    asset_map(model.assets),
  )
  (html, result.diagnostics)
}

///|
fn safe_filename(title : String) -> String {
  let base = title.trim().to_owned()
  let base = if base == "" { "sigil-email" } else { base }
  let base = base
    .replace_all(old="/", new="-")
    .replace_all(old="\\", new="-")
    .replace_all(old=":", new="-")
    .replace_all(old="*", new="-")
    .replace_all(old="?", new="-")
    .replace_all(old="\"", new="-")
    .replace_all(old="<", new="-")
    .replace_all(old=">", new="-")
    .replace_all(old="|", new="-")
  base + ".html"
}

///|
extern "js" fn save_html_file(filename : String, html : String) -> Unit =
  #| (filename, html) => {
  #|   const fallback = () => {
  #|     const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  #|     const url = URL.createObjectURL(blob);
  #|     const anchor = document.createElement('a');
  #|     anchor.href = url;
  #|     anchor.download = filename;
  #|     document.body.appendChild(anchor);
  #|     anchor.click();
  #|     anchor.remove();
  #|     setTimeout(() => URL.revokeObjectURL(url), 0);
  #|   };
  #|   if (typeof window.showSaveFilePicker === 'function') {
  #|     window.showSaveFilePicker({
  #|       suggestedName: filename,
  #|       types: [{ description: 'HTML document', accept: { 'text/html': ['.html'] } }]
  #|     }).then(async (handle) => {
  #|       const writable = await handle.createWritable();
  #|       await writable.write(html);
  #|       await writable.close();
  #|     }).catch((error) => {
  #|       if (error && error.name !== 'AbortError') fallback();
  #|     });
  #|   } else {
  #|     fallback();
  #|   }
  #| }

///|
fn export_active_document(model : Model) -> Unit {
  match active_document(model) {
    Some(document) => {
      let (html, _) = render_source(model, document.source)
      save_html_file(safe_filename(document.title), html)
    }
    None => ()
  }
}
