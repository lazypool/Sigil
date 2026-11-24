///|
/// Vim keymap state machine.
///
/// This is a pure key -> instruction mapper. It never touches parsing,
/// rendering, or diagnostics: it only produces cursor-movement and text-editing
/// instructions that the frontend translates into `#sigil-editor` textarea
/// operations.
///
/// Keys that depend on editor text (`w`/`b` word motion, `0`/`$` line
/// boundaries, `gg`/`G` document boundaries, `dd` line deletion) are resolved
/// by the frontend in `vim.mbt`, because this function is pure and has no
/// access to the textarea value. `vim_dispatch` therefore maps the
/// text-independent subset and returns `Noop` for everything else.
#derive(Eq)
pub(all) enum VimMode {
  Normal
  Insert
}

///|
/// A single instruction produced from one or more key presses.
#derive(Eq)
pub(all) enum VimOp {
  Noop
  // Absolute character offset (`0`/`$`/`gg`/`G`/`w`/`b` resolved by the
  // frontend and passed back through this variant).
  MoveCursor(Int32)
  // Relative line count (`j`/`k`, positive moves down).
  MoveLine(Int32)
  // Relative character count (`h`/`l`, positive moves right).
  MoveColumn(Int32)
  DeleteChar
  DeleteLine
  InsertAtCursor
  InsertAfterCursor
  InsertAtLineEnd
  OpenLineBelow
  OpenLineAbove
  SetMode(VimMode)
}

///|
/// Map a single key press to an instruction.
///
/// `ctrl` or `meta` always yields `Noop` so system shortcuts are left alone.
/// In `Insert` mode only `Escape` (switch to `Normal`) is handled.
pub fn vim_dispatch(
  mode : VimMode,
  key : String,
  ctrl : Bool,
  meta : Bool,
  shift : Bool,
) -> VimOp {
  ignore(shift)
  if ctrl || meta {
    return Noop
  }
  match mode {
    Insert =>
      match key {
        "Escape" => SetMode(Normal)
        _ => Noop
      }
    Normal =>
      match key {
        "h" => MoveColumn(-1)
        "l" => MoveColumn(1)
        "j" => MoveLine(1)
        "k" => MoveLine(-1)
        "x" => DeleteChar
        "i" => InsertAtCursor
        "a" => InsertAfterCursor
        "A" => InsertAtLineEnd
        "o" => OpenLineBelow
        "O" => OpenLineAbove
        "Escape" => SetMode(Normal)
        _ => Noop
      }
  }
}
