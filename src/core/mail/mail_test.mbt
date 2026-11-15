///|
/// Mail delivery helpers.
///
/// Rendered HTML carries images as base64 `data:` URLs. Email clients such as
/// Gmail block those, so delivery converts each one into a CID attachment.

///|
test "base64 data urls become cid references" {
  let source = "<p><img src=\"data:image/png;base64,AAAA\" alt=\"\"></p>"
  let (html, images) = @mail.extract_inline_images(source)
  assert_eq(images.length(), 1)
  assert_eq(images[0].content_id, "sigil-inline-1@sigil.local")
  assert_eq(images[0].filename, "sigil-inline-1.png")
  assert_eq(images[0].mime, "image/png")
  assert_eq(images[0].base64, "AAAA")
  assert_eq(
    html, "<p><img src=\"cid:sigil-inline-1@sigil.local\" alt=\"\"></p>",
  )
}

///|
test "remote image urls stay untouched" {
  let source = "<img src=\"https://example.com/a.png\">"
  let (html, images) = @mail.extract_inline_images(source)
  assert_eq(images.length(), 0)
  assert_eq(html, source)
}

///|
test "non base64 data urls stay untouched" {
  let source = "<img src=\"data:image/svg+xml;charset=utf-8,<svg></svg>\">"
  let (html, images) = @mail.extract_inline_images(source)
  assert_eq(images.length(), 0)
  assert_eq(html, source)
}

///|
test "resend payload embeds inline images" {
  let config = @mail.DeliveryConfig::{
    provider: "resend",
    endpoint: "",
    from_name: "Sigil",
    from_address: "hi@example.com",
    api_key: "key",
  }
  let payload = @mail.build_delivery_payload(
    config,
    ["reader@example.com"],
    "Hello",
    "<img src=\"data:image/png;base64,AAAA\">",
  )
  let text = payload.stringify()
  assert_true(text.contains("\"from\":\"Sigil <hi@example.com>\""))
  assert_true(text.contains("\"reader@example.com\""))
  assert_true(text.contains("cid:sigil-inline-1@sigil.local"))
  assert_true(text.contains("\"content_id\":\"sigil-inline-1@sigil.local\""))
}

///|
test "sendgrid payload uses personalizations and inline disposition" {
  let config = @mail.DeliveryConfig::{
    provider: "sendgrid",
    endpoint: "",
    from_name: "Sigil",
    from_address: "hi@example.com",
    api_key: "key",
  }
  let payload = @mail.build_delivery_payload(
    config,
    ["reader@example.com"],
    "Hello",
    "<img src=\"data:image/png;base64,AAAA\">",
  )
  let text = payload.stringify()
  assert_true(text.contains("\"personalizations\""))
  assert_true(text.contains("\"disposition\":\"inline\""))
  assert_true(text.contains("\"type\":\"image/png\""))
}

///|
test "unknown providers fall back to resend" {
  assert_eq(@mail.normalize_provider("mailgun"), "resend")
  assert_eq(
    @mail.default_endpoint("sendgrid"),
    "https://api.sendgrid.com/v3/mail/send",
  )
  assert_eq(@mail.default_endpoint("resend"), "https://api.resend.com/emails")
}
