///|
/// Vim keymap layer, frontend half.
///
/// The core `xiao/sigil/core/keymap` package is a pure key -> instruction
/// state machine. This file wires it to the `#sigil-editor` textarea: it reads
/// the cursor, applies instructions as textarea operations, and routes edited
/// sources back through the normal `SourceChanged` persistence path.
///
/// It only interacts with the editor through its exposed `selection` and
/// `value`; it never writes `document.source` directly.

///|
extern "js" fn vim_cursor() -> String =
  #| () => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return JSON.stringify({ start: 0, end: 0, value: '' });
  #|   const start = el.selectionStart ?? el.value.length;
  #|   const end = el.selectionEnd ?? start;
  #|   return JSON.stringify({ start, end, value: el.value });
  #| }

///|
/// Apply one instruction to the editor textarea and return the new source.
/// Movement instructions leave the source unchanged and only move the cursor;
/// editing instructions return the modified source.
extern "js" fn vim_apply(op_json : String) -> String =
  #| (opJson) => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return '';
  #|   const value = el.value;
  #|   const start = el.selectionStart ?? value.length;
  #|   const clamp = (n, lo, hi) => (n < lo ? lo : (n > hi ? hi : n));
  #|   const lineStart = (p) => {
  #|     const i = value.lastIndexOf('\n', p - 1);
  #|     return i < 0 ? 0 : i + 1;
  #|   };
  #|   const lineEnd = (p) => {
  #|     const i = value.indexOf('\n', p);
  #|     return i < 0 ? value.length : i;
  #|   };
  #|   let op;
  #|   try {
  #|     op = JSON.parse(opJson);
  #|   } catch (e) {
  #|     return value;
  #|   }
  #|   let next = value;
  #|   let cursor = start;
  #|   switch (op.kind) {
  #|     case 'cursor':
  #|       cursor = clamp(op.n | 0, 0, value.length);
  #|       break;
  #|     case 'column':
  #|       cursor = clamp(start + (op.n | 0), 0, value.length);
  #|       break;
  #|     case 'line': {
  #|       const lines = value.split('\n');
  #|       let index = 0;
  #|       let offset = 0;
  #|       for (let i = 0; i < lines.length; i++) {
  #|         const len = lines[i].length;
  #|         if (start <= offset + len) {
  #|           index = i;
  #|           break;
  #|         }
  #|         offset += len + 1;
  #|       }
  #|       const column = start - offset;
  #|       const target = clamp(index + (op.n | 0), 0, lines.length - 1);
  #|       let targetOffset = 0;
  #|       for (let i = 0; i < target; i++) targetOffset += lines[i].length + 1;
  #|       cursor = targetOffset + Math.min(column, lines[target].length);
  #|       break;
  #|     }
  #|     case 'delete_char':
  #|       if (start < value.length) {
  #|         next = value.slice(0, start) + value.slice(start + 1);
  #|         cursor = start;
  #|       }
  #|       break;
  #|     case 'delete_line': {
  #|       const ls = lineStart(start);
  #|       const le = lineEnd(start);
  #|       if (le < value.length) {
  #|         next = value.slice(0, ls) + value.slice(le + 1);
  #|         cursor = ls;
  #|       } else if (ls > 0) {
  #|         next = value.slice(0, ls - 1);
  #|         cursor = ls - 1;
  #|       } else {
  #|         next = '';
  #|         cursor = 0;
  #|       }
  #|       break;
  #|     }
  #|     case 'insert_cursor':
  #|       cursor = start;
  #|       break;
  #|     case 'insert_after':
  #|       cursor = clamp(start + 1, 0, value.length);
  #|       break;
  #|     case 'insert_line_end':
  #|       cursor = lineEnd(start);
  #|       break;
  #|     case 'open_below': {
  #|       const le = lineEnd(start);
  #|       next = value.slice(0, le) + '\n' + value.slice(le);
  #|       cursor = le + 1;
  #|       break;
  #|     }
  #|     case 'open_above': {
  #|       const ls = lineStart(start);
  #|       next = value.slice(0, ls) + '\n' + value.slice(ls);
  #|       cursor = ls + 1;
  #|       break;
  #|     }
  #|     default:
  #|       return value;
  #|   }
  #|   el.value = next;
  #|   cursor = clamp(cursor, 0, next.length);
  #|   el.selectionStart = el.selectionEnd = cursor;
  #|   const desired = cursor;
  #|   const applied = next;
  #|   requestAnimationFrame(() => {
  #|     const e = document.getElementById('sigil-editor');
  #|     if (e && e.value === applied) {
  #|       const p = clamp(desired, 0, e.value.length);
  #|       e.selectionStart = e.selectionEnd = p;
  #|     }
  #|   });
  #|   el.focus();
  #|   return next;
  #| }

///|
extern "js" fn vim_line_start() -> Int32 =
  #| () => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return 0;
  #|   const p = el.selectionStart ?? el.value.length;
  #|   const i = el.value.lastIndexOf('\n', p - 1);
  #|   return i < 0 ? 0 : i + 1;
  #| }

///|
extern "js" fn vim_line_end() -> Int32 =
  #| () => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return 0;
  #|   const p = el.selectionStart ?? el.value.length;
  #|   const i = el.value.indexOf('\n', p);
  #|   return i < 0 ? el.value.length : i;
  #| }

///|
extern "js" fn vim_word_forward() -> Int32 =
  #| () => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return 0;
  #|   const value = el.value;
  #|   const p = el.selectionStart ?? value.length;
  #|   const isWord = (ch) => /[A-Za-z0-9_]/.test(ch);
  #|   let i = p;
  #|   while (i < value.length && isWord(value[i])) i++;
  #|   while (i < value.length && !isWord(value[i])) i++;
  #|   return i;
  #| }

///|
extern "js" fn vim_word_backward() -> Int32 =
  #| () => {
  #|   const el = document.getElementById('sigil-editor');
  #|   if (!el) return 0;
  #|   const value = el.value;
  #|   const p = el.selectionStart ?? value.length;
  #|   const isWord = (ch) => /[A-Za-z0-9_]/.test(ch);
  #|   let i = p;
  #|   while (i > 0 && !isWord(value[i - 1])) i--;
  #|   while (i > 0 && isWord(value[i - 1])) i--;
  #|   return i;
  #| }

///|
extern "js" fn vim_pending_key() -> String =
  #| () => (globalThis.__sigil_vim_pending__ ?? '')

///|
extern "js" fn vim_set_pending_key(key : String) -> Unit =
  #| (key) => {
  #|   globalThis.__sigil_vim_pending__ = key;
  #| }

///|
#derive(FromJson)
struct VimCursorState {
  value : String
}

///|
fn vim_read_cursor() -> VimCursorState {
  let raw = vim_cursor()
  let parsed = @json.parse(raw) catch {
    _ => return { value: "" }
  }
  @json.from_json(parsed) catch {
    _ => { value: "" }
  }
}

///|
/// Decide whether the keydown should be intercepted (prevent the browser's
/// default insertion) for the given model state.
fn vim_should_intercept(
  model : Model,
  ctrl : Bool,
  meta : Bool,
) -> Bool {
  model.prefs.vim && !ctrl && !meta && model.vim_mode is @keymap.Normal
}

///|
/// Resolve a key press to a `VimOp`. Multi-key prefixes (`gg`, `dd`) and
/// text-dependent motions (`w`/`b`/`0`/`$`/`G`) are resolved here because the
/// core dispatcher is pure and has no editor text.
fn vim_resolve_op(
  model : Model,
  key : String,
  ctrl : Bool,
  meta : Bool,
  shift : Bool,
) -> @keymap.VimOp {
  if ctrl || meta {
    vim_set_pending_key("")
    return @keymap.Noop
  }
  let pending = vim_pending_key()
  if pending != "" {
    vim_set_pending_key("")
    if pending == "g" && key == "g" {
      return @keymap.MoveCursor(0)
    }
    if pending == "d" && key == "d" {
      return @keymap.DeleteLine
    }
  }
  if model.vim_mode is @keymap.Insert {
    return @keymap.vim_dispatch(model.vim_mode, key, ctrl, meta, shift)
  }
  if key == "g" || key == "d" {
    vim_set_pending_key(key)
    return @keymap.Noop
  }
  match key {
    "w" => @keymap.MoveCursor(vim_word_forward())
    "b" => @keymap.MoveCursor(vim_word_backward())
    "0" => @keymap.MoveCursor(vim_line_start())
    "$" => @keymap.MoveCursor(vim_line_end())
    "G" => @keymap.MoveCursor(vim_read_cursor().value.length())
    _ => @keymap.vim_dispatch(model.vim_mode, key, ctrl, meta, shift)
  }
}

///|
fn vim_op_json(op : @keymap.VimOp) -> String {
  match op {
    @keymap.Noop => "{}"
    @keymap.MoveCursor(n) => "{\"kind\":\"cursor\",\"n\":" + n.to_string() + "}"
    @keymap.MoveLine(n) => "{\"kind\":\"line\",\"n\":" + n.to_string() + "}"
    @keymap.MoveColumn(n) => "{\"kind\":\"column\",\"n\":" + n.to_string() + "}"
    @keymap.DeleteChar => "{\"kind\":\"delete_char\"}"
    @keymap.DeleteLine => "{\"kind\":\"delete_line\"}"
    @keymap.InsertAtCursor => "{\"kind\":\"insert_cursor\"}"
    @keymap.InsertAfterCursor => "{\"kind\":\"insert_after\"}"
    @keymap.InsertAtLineEnd => "{\"kind\":\"insert_line_end\"}"
    @keymap.OpenLineBelow => "{\"kind\":\"open_below\"}"
    @keymap.OpenLineAbove => "{\"kind\":\"open_above\"}"
    @keymap.SetMode(_) => "{}"
  }
}

///|
/// Badge showing the current vim mode when vim is enabled; empty when off.
fn vim_mode_badge(model : Model) -> Html {
  if !model.prefs.vim {
    return @html.nothing
  }
  let (label, color, bg) = match model.vim_mode {
    @keymap.Normal => ("NORMAL", "#0f172a", "#e2e8f0")
    @keymap.Insert => ("INSERT", "#ffffff", "#10b981")
  }
  @html.span(
    class="sigil-vim-badge",
    style=[
      "display:inline-block;margin-left:8px;padding:1px 6px;border-radius:3px;font-size:10px;font-weight:600;letter-spacing:0.5px;color:" +
      color +
      ";background:" +
      bg +
      ";",
    ],
    [@html.text(label)],
  )
}

///|
/// Handle a `VimKey` message. Disabled (`prefs.vim == false`) keys are a pure
/// no-op with no side effects.
fn vim_update(
  model : Model,
  key : String,
  ctrl : Bool,
  meta : Bool,
  shift : Bool,
  emit : Emit[Msg],
) -> (Model, Cmd) {
  if !model.prefs.vim {
    return (model, @rabbita.none)
  }
  if active_document(model) is None {
    return (model, @rabbita.none)
  }
  match vim_resolve_op(model, key, ctrl, meta, shift) {
    @keymap.Noop => (model, @rabbita.none)
    @keymap.SetMode(mode) => ({ ..model, vim_mode: mode }, @rabbita.none)
    op => {
      let new_source = vim_apply(vim_op_json(op))
      let next_mode = match op {
        @keymap.InsertAtCursor
        | @keymap.InsertAfterCursor
        | @keymap.InsertAtLineEnd
        | @keymap.OpenLineBelow
        | @keymap.OpenLineAbove => @keymap.Insert
        _ => model.vim_mode
      }
      let next = { ..model, vim_mode: next_mode }
      if new_source == active_source(model) {
        (next, @rabbita.none)
      } else {
        (next, emit(SourceChanged(new_source)))
      }
    }
  }
}
