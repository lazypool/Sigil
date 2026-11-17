///|
test "empty profile and document defaults" {
  assert_true(@types.Profile::empty().is_empty())
  assert_eq(@types.Profile::empty().display_name(), "")
  assert_eq(@types.Document::empty().blocks.length(), 0)
}

///|
test "built-in icon whitelist validates known and unknown names" {
  assert_true(@types.icon_valid("mail"))
  assert_true(@types.icon_valid("phone"))
  assert_true(@types.icon_valid("arrow-right"))
  assert_false(@types.icon_valid(""))
  assert_false(@types.icon_valid("rocket"))
}

///|
test "every whitelisted icon name is valid and unique" {
  assert_true(@types.icon_names.length() >= 50)
  for name in @types.icon_names {
    assert_true(@types.icon_valid(name))
  }
  for index = 0; index < @types.icon_names.length(); index = index + 1 {
    for other = index + 1; other < @types.icon_names.length(); other = other + 1 {
      assert_true(@types.icon_names[index] != @types.icon_names[other])
    }
  }
}
