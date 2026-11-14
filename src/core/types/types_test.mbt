///|
test "empty profile and document defaults" {
  assert_true(@types.Profile::empty().is_empty())
  assert_eq(@types.Profile::empty().display_name(), "")
  assert_eq(@types.Document::empty().blocks.length(), 0)
}
