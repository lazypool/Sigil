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
  document : EmailDoc,
) -> (String, Array[@types.Diagnostic]) {
  let result = @parser.parse(document.source)
  let library = library_for_document(model, document.id)
  let html = @render.render_email_html_with_libraries(
    result.document,
    to_core_profile(model.profile),
    asset_map(library.images),
    table_map(library.tables),
    chart_map(library.charts),
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
/// Installs the shared export helper on `globalThis`.
///
/// Formulas and charts render as live SVG in the preview but email clients need
/// raster images. The helper copies the live preview nodes into a canvas and
/// replaces the matching nodes in the exported HTML with PNG data URLs.
extern "js" fn init_email_export() -> Unit =
  #| () => {
  #|   if (globalThis.__sigilPrepareEmailHtml) return;
  #|   const prepare = async (html) => {
  #|     const frame = document.querySelector('.sigil-preview-frame');
  #|     let live = [];
  #|     try {
  #|       if (frame && frame.contentDocument) {
  #|         live = Array.from(
  #|           frame.contentDocument.querySelectorAll('[data-sigil-math],[data-sigil-chart],[data-sigil-icon]')
  #|         );
  #|       }
  #|     } catch (error) {
  #|       live = [];
  #|     }
  #|     let doc = null;
  #|     let targets = [];
  #|     try {
  #|       doc = new DOMParser().parseFromString(html, 'text/html');
  #|       targets = Array.from(
  #|         doc.querySelectorAll('[data-sigil-math],[data-sigil-chart],[data-sigil-icon]')
  #|       );
  #|     } catch (error) {
  #|       doc = null;
  #|     }
  #|     if (!doc || live.length === 0 || targets.length === 0) {
  #|       return html;
  #|     }
  #|     const rasterize = (element) => new Promise((resolve, reject) => {
  #|       try {
  #|         const isIcon = element.hasAttribute('data-sigil-icon');
  #|         const rect = element.getBoundingClientRect();
  #|         if (isIcon) {
  #|           const scale = 3;
  #|           const width = Math.max(1, Math.ceil(rect.width));
  #|           const height = Math.max(1, Math.ceil(rect.height));
  #|           const image = new Image();
  #|           image.onload = () => {
  #|             try {
  #|               const canvas = document.createElement('canvas');
  #|               canvas.width = Math.max(1, Math.round(width * scale));
  #|               canvas.height = Math.max(1, Math.round(height * scale));
  #|               const context = canvas.getContext('2d');
  #|               context.scale(scale, scale);
  #|               context.drawImage(image, 0, 0, width, height);
  #|               resolve({ dataUrl: canvas.toDataURL('image/png'), width, height });
  #|             } catch (error) {
  #|               reject(error);
  #|             }
  #|           };
  #|           image.onerror = () => reject(new Error('icon image failed'));
  #|           const clean = element.cloneNode(true);
  #|           clean.style.margin = '0';
  #|           image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(clean.outerHTML);
  #|           return;
  #|         }
  #|         const pad = 8;
  #|         const scale = 2;
  #|         const width = Math.max(1, Math.ceil(rect.width)) + pad * 2;
  #|         const height = Math.max(1, Math.ceil(rect.height)) + pad * 2;
  #|         const wrapper = '<div xmlns="http://www.w3.org/1999/xhtml" style="width:' + width +
  #|           'px;height:' + height +
  #|           'px;display:flex;align-items:center;justify-content:center;box-sizing:border-box;padding:' +
  #|           pad + 'px;background:#ffffff;color:#222833;">' + element.innerHTML + '</div>';
  #|         const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + width +
  #|           '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height +
  #|           '"><foreignObject x="0" y="0" width="100%" height="100%">' + wrapper +
  #|           '</foreignObject></svg>';
  #|         const image = new Image();
  #|         image.onload = () => {
  #|           try {
  #|             const canvas = document.createElement('canvas');
  #|             canvas.width = Math.max(1, Math.round(width * scale));
  #|             canvas.height = Math.max(1, Math.round(height * scale));
  #|             const context = canvas.getContext('2d');
  #|             context.scale(scale, scale);
  #|             context.fillStyle = '#ffffff';
  #|             context.fillRect(0, 0, width, height);
  #|             context.drawImage(image, 0, 0, width, height);
  #|             resolve({ dataUrl: canvas.toDataURL('image/png'), width, height });
  #|           } catch (error) {
  #|             reject(error);
  #|           }
  #|         };
  #|         image.onerror = () => reject(new Error('math or chart image failed'));
  #|         image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  #|       } catch (error) {
  #|         reject(error);
  #|       }
  #|     });
  #|     try {
  #|       const count = Math.min(live.length, targets.length);
  #|       for (let index = 0; index < count; index = index + 1) {
  #|         const shot = await rasterize(live[index]);
  #|         const image = doc.createElement('img');
  #|         image.setAttribute('src', shot.dataUrl);
  #|         if (live[index].hasAttribute('data-sigil-icon')) {
  #|           image.setAttribute('alt', '');
  #|           image.setAttribute('width', shot.width);
  #|           image.setAttribute('height', shot.height);
  #|           image.setAttribute(
  #|             'style',
  #|             'display:inline-block;vertical-align:-3px;width:' + shot.width +
  #|             'px;height:' + shot.height + 'px;margin:0 2px;border:0;'
  #|           );
  #|         } else {
  #|           image.setAttribute('alt', (live[index].textContent || 'formula').trim());
  #|           image.setAttribute(
  #|             'style',
  #|             'display:block;width:' + shot.width +
  #|             'px;max-width:100%;height:auto;margin:20px auto;border:0;'
  #|           );
  #|         }
  #|         targets[index].replaceWith(image);
  #|       }
  #|       return '<!doctype html>\n' + doc.documentElement.outerHTML;
  #|     } catch (error) {
  #|       return html;
  #|     }
  #|   };
  #|   globalThis.__sigilPrepareEmailHtml = prepare;
  #| }

///|
/// Resolves the final email-safe HTML, rasterizing formulas and charts when the
/// live preview is available.
extern "js" fn prepare_email_html(html : String) -> @js_async.Promise[String] =
  #| (html) => {
  #|   const prepare = globalThis.__sigilPrepareEmailHtml;
  #|   if (typeof prepare === 'function') return prepare(html);
  #|   return Promise.resolve(html);
  #| }

///|
extern "js" fn save_html_file(filename : String, html : String) -> Unit =
  #| async (filename, html) => {
  #|   const picker = (() => {
  #|     if (typeof window.showSaveFilePicker !== 'function') return null;
  #|     try {
  #|       return window.showSaveFilePicker({
  #|         suggestedName: filename,
  #|         types: [{ description: 'HTML document', accept: { 'text/html': ['.html'] } }]
  #|       });
  #|     } catch (error) {
  #|       return null;
  #|     }
  #|   })();
  #|   const fallback = (output) => {
  #|     const blob = new Blob([output], { type: 'text/html;charset=utf-8' });
  #|     const url = URL.createObjectURL(blob);
  #|     const anchor = document.createElement('a');
  #|     anchor.href = url;
  #|     anchor.download = filename;
  #|     document.body.appendChild(anchor);
  #|     anchor.click();
  #|     anchor.remove();
  #|     setTimeout(() => URL.revokeObjectURL(url), 0);
  #|   };
  #|   const save = async (output) => {
  #|     if (picker) {
  #|       try {
  #|         const handle = await picker;
  #|         const writable = await handle.createWritable();
  #|         await writable.write(output);
  #|         await writable.close();
  #|         return;
  #|       } catch (error) {
  #|         if (error && error.name === 'AbortError') return;
  #|       }
  #|     }
  #|     fallback(output);
  #|   };
  #|   const frame = document.querySelector('.sigil-preview-frame');
  #|   let live = [];
  #|   try {
  #|     if (frame && frame.contentDocument) {
  #|       live = Array.from(frame.contentDocument.querySelectorAll('[data-sigil-math],[data-sigil-chart],[data-sigil-icon]'));
  #|     }
  #|   } catch (error) {
  #|     live = [];
  #|   }
  #|   let doc = null;
  #|   let targets = [];
  #|   try {
  #|     doc = new DOMParser().parseFromString(html, 'text/html');
  #|     targets = Array.from(doc.querySelectorAll('[data-sigil-math],[data-sigil-chart],[data-sigil-icon]'));
  #|   } catch (error) {
  #|     doc = null;
  #|   }
  #|   if (!doc || live.length === 0 || targets.length === 0) {
  #|     save(html);
  #|     return;
  #|   }
  #|   const rasterize = (element) => new Promise((resolve, reject) => {
  #|     try {
  #|       const isIcon = element.hasAttribute('data-sigil-icon');
  #|       const rect = element.getBoundingClientRect();
  #|       if (isIcon) {
  #|         const scale = 3;
  #|         const width = Math.max(1, Math.ceil(rect.width));
  #|         const height = Math.max(1, Math.ceil(rect.height));
  #|         const image = new Image();
  #|         image.onload = () => {
  #|           try {
  #|             const canvas = document.createElement('canvas');
  #|             canvas.width = Math.max(1, Math.round(width * scale));
  #|             canvas.height = Math.max(1, Math.round(height * scale));
  #|             const context = canvas.getContext('2d');
  #|             context.scale(scale, scale);
  #|             context.drawImage(image, 0, 0, width, height);
  #|             resolve({ dataUrl: canvas.toDataURL('image/png'), width, height });
  #|           } catch (error) {
  #|             reject(error);
  #|           }
  #|         };
  #|         image.onerror = () => reject(new Error('icon image failed'));
  #|         const clean = element.cloneNode(true);
  #|         clean.style.margin = '0';
  #|         image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(clean.outerHTML);
  #|         return;
  #|       }
  #|       const pad = 8;
  #|       const scale = 2;
  #|       const width = Math.max(1, Math.ceil(rect.width)) + pad * 2;
  #|       const height = Math.max(1, Math.ceil(rect.height)) + pad * 2;
  #|       const wrapper = '<div xmlns="http://www.w3.org/1999/xhtml" style="width:' + width +
  #|         'px;height:' + height +
  #|         'px;display:flex;align-items:center;justify-content:center;box-sizing:border-box;padding:' +
  #|         pad + 'px;background:#ffffff;color:#222833;">' + element.innerHTML + '</div>';
  #|       const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + width +
  #|         '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height +
  #|         '"><foreignObject x="0" y="0" width="100%" height="100%">' + wrapper +
  #|         '</foreignObject></svg>';
  #|       const image = new Image();
  #|       image.onload = () => {
  #|         try {
  #|           const canvas = document.createElement('canvas');
  #|           canvas.width = Math.max(1, Math.round(width * scale));
  #|           canvas.height = Math.max(1, Math.round(height * scale));
  #|           const context = canvas.getContext('2d');
  #|           context.scale(scale, scale);
  #|           context.fillStyle = '#ffffff';
  #|           context.fillRect(0, 0, width, height);
  #|           context.drawImage(image, 0, 0, width, height);
  #|           resolve({ dataUrl: canvas.toDataURL('image/png'), width, height });
  #|         } catch (error) {
  #|           reject(error);
  #|         }
  #|       };
  #|       image.onerror = () => reject(new Error('math or chart image failed'));
  #|       image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  #|     } catch (error) {
  #|       reject(error);
  #|     }
  #|   });
  #|   try {
  #|     const count = Math.min(live.length, targets.length);
  #|     for (let index = 0; index < count; index = index + 1) {
  #|       const shot = await rasterize(live[index]);
  #|       const image = doc.createElement('img');
  #|       image.setAttribute('src', shot.dataUrl);
  #|       if (live[index].hasAttribute('data-sigil-icon')) {
  #|         image.setAttribute('alt', '');
  #|         image.setAttribute('width', shot.width);
  #|         image.setAttribute('height', shot.height);
  #|         image.setAttribute(
  #|           'style',
  #|           'display:inline-block;vertical-align:-3px;width:' + shot.width +
  #|           'px;height:' + shot.height + 'px;margin:0 2px;border:0;'
  #|         );
  #|       } else {
  #|         image.setAttribute('alt', (live[index].textContent || 'formula').trim());
  #|         image.setAttribute(
  #|           'style',
  #|           'display:block;width:' + shot.width +
  #|           'px;max-width:100%;height:auto;margin:20px auto;border:0;'
  #|         );
  #|       }
  #|       targets[index].replaceWith(image);
  #|     }
  #|     save('<!doctype html>\n' + doc.documentElement.outerHTML);
  #|   } catch (error) {
  #|     save(html);
  #|   }
  #| }

///|
fn export_active_document(model : Model) -> Unit {
  match active_document(model) {
    Some(document) => {
      let (html, _) = render_source(model, document)
      save_html_file(safe_filename(document.title), html)
    }
    None => ()
  }
}
