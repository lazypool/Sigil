///|

///|
test "h/j/k/l move the cursor" {
  assert_true(
    @keymap.vim_dispatch(Normal, "h", false, false, false) == MoveColumn(-1),
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "l", false, false, false) == MoveColumn(1),
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "j", false, false, false) == MoveLine(1),
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "k", false, false, false) == MoveLine(-1),
  )
}

///|
test "x deletes a character" {
  assert_true(
    @keymap.vim_dispatch(Normal, "x", false, false, false) == DeleteChar,
  )
}

///|
test "i/a/A/o/O switch into insert" {
  assert_true(
    @keymap.vim_dispatch(Normal, "i", false, false, false) == InsertAtCursor,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "a", false, false, false) == InsertAfterCursor,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "A", false, false, false) == InsertAtLineEnd,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "o", false, false, false) == OpenLineBelow,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "O", false, false, false) == OpenLineAbove,
  )
}

///|
test "escape switches into normal mode" {
  assert_true(
    @keymap.vim_dispatch(Insert, "Escape", false, false, false) ==
    SetMode(Normal),
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "Escape", false, false, false) ==
    SetMode(Normal),
  )
}

///|
test "ctrl or meta always maps to noop" {
  assert_true(
    @keymap.vim_dispatch(Normal, "h", true, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "j", false, true, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "Escape", true, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "Escape", false, true, false) == Noop,
  )
}

///|
test "insert mode ignores everything except escape" {
  assert_true(
    @keymap.vim_dispatch(Insert, "h", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "j", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "i", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "x", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Insert, "0", false, false, false) == Noop,
  )
}

///|
test "text-dependent keys are left to the frontend" {
  assert_true(
    @keymap.vim_dispatch(Normal, "w", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "b", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "0", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "$", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "g", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "G", false, false, false) == Noop,
  )
  assert_true(
    @keymap.vim_dispatch(Normal, "d", false, false, false) == Noop,
  )
}
