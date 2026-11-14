///|
test "preview shell keeps the 640px reading column and has no scripts" {
  let html = @render.build_preview_shell("<p>Preview area</p>")
  assert_true(html.contains("max-width:640px"))
  assert_true(html.contains("font-size:16px"))
  assert_true(html.contains("line-height:1.7"))
  assert_true(html.contains("<p>Preview area</p>"))
  assert_false(html.contains("<script>"))
  assert_false(html.contains("<script"))
}
