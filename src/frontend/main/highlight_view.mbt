///|
extern "js" fn sync_editor_scroll() -> Unit = "( ) => { const input = document.getElementById('sigil-editor'); const layer = document.getElementById('sigil-highlight'); if (!input || !layer) return; layer.scrollTop = input.scrollTop; layer.scrollLeft = input.scrollLeft; }"

///|
extern "js" fn schedule_editor_scroll_sync() -> Unit = "( ) => { requestAnimationFrame(() => { const input = document.getElementById('sigil-editor'); const layer = document.getElementById('sigil-highlight'); if (!input || !layer) return; layer.scrollTop = input.scrollTop; layer.scrollLeft = input.scrollLeft; }); }"

///|
fn highlight_class(kind : @highlight.HighlightKind) -> String {
  match kind {
    Plain => ""
    HeaderKey => "sigil-tok-header-key"
    HeaderValue => "sigil-tok-header-value"
    Divider => "sigil-tok-divider"
    ListMarker => "sigil-tok-list"
    StrongMarker => "sigil-tok-strong-marker"
    StrongText => "sigil-tok-strong"
    BigMarker => "sigil-tok-big-marker"
    BigText => "sigil-tok-big"
    InsertionPrefix => "sigil-tok-insertion"
    InsertionTarget => "sigil-tok-insertion-target"
    LinkUrl => "sigil-tok-link"
    Escape => "sigil-tok-escape"
    Fence => "sigil-tok-fence"
    FormulaText => "sigil-tok-formula"
    ChartKey => "sigil-tok-chart-key"
    ChartValue => "sigil-tok-chart-value"
    PlainText => "sigil-tok-plaintext"
    Invalid => "sigil-tok-invalid"
  }
}

///|
fn highlight_span_view(span : @highlight.HighlightSpan) -> @rabbita.Html {
  let class_name = highlight_class(span.kind)
  if class_name == "" {
    @html.text(span.text)
  } else {
    @html.span(class=class_name, [@html.text(span.text)])
  }
}

///|
fn highlighted_source(source : String) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = []
  for span in @highlight.highlight(source) {
    children.push(highlight_span_view(span))
  }
  if source.has_suffix("\n") {
    children.push(@html.text("\n"))
  }
  @html.pre(
    id="sigil-highlight",
    class="sigil-highlight",
    attrs=@html.Attrs::build().aria_hidden("true"),
    children,
  )
}

///|
fn editor_input_attrs() -> @html.Attrs {
  @html.Attrs::build()
  .spellcheck(false)
  .autocapitalize("off")
  .autocorrect("off")
  .on_scroll(_ => {
    sync_editor_scroll()
    @rabbita.none
  })
}

///|
fn source_changed(value : String) -> Msg {
  schedule_editor_scroll_sync()
  SourceChanged(value)
}
