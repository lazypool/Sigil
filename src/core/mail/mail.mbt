///|
using @json {type Json}

///|
/// Provider connection details used to build a delivery request.
pub(all) struct DeliveryConfig {
  provider : String
  endpoint : String
  from_name : String
  from_address : String
  api_key : String
}

///|
/// One inline image extracted from a `data:` URL in rendered HTML.
pub(all) struct InlineImage {
  content_id : String
  filename : String
  mime : String
  base64 : String
}

///|
/// One user-selected file attachment, base64-encoded.
pub(all) struct Attachment {
  filename : String
  mime : String
  base64 : String
}

///|
/// Normalizes the provider identifier; unknown values fall back to Resend.
pub fn normalize_provider(provider : String) -> String {
  match provider.trim().to_lower() {
    "sendgrid" => "sendgrid"
    _ => "resend"
  }
}

///|
/// Returns the built-in API endpoint for a provider.
pub fn default_endpoint(provider : String) -> String {
  match normalize_provider(provider) {
    "sendgrid" => "https://api.sendgrid.com/v3/mail/send"
    _ => "https://api.resend.com/emails"
  }
}

///|
/// Returns the configured endpoint, or the provider default when unset.
pub fn endpoint_for(config : DeliveryConfig) -> String {
  let endpoint = config.endpoint.trim()
  if endpoint == "" {
    default_endpoint(config.provider)
  } else {
    endpoint.to_owned()
  }
}

///|
fn extension_for(mime : String) -> String {
  match mime {
    "image/jpeg" => ".jpg"
    "image/gif" => ".gif"
    "image/webp" => ".webp"
    "image/svg+xml" => ".svg"
    _ => ".png"
  }
}

///|
priv struct ParsedDataUrl {
  mime : String
  base64 : String
}

///|
fn parse_data_url(url : StringView) -> ParsedDataUrl? {
  guard url.has_prefix("data:") else { return None }
  match url[5:].split_once(";base64,") {
    Some((mime, data)) => {
      guard mime.has_prefix("image/") && data.length() > 0 else { return None }
      Some({ mime: mime.to_owned(), base64: data.to_owned(), })
    }
    None => None
  }
}

///|
/// Replaces base64 `data:` image URLs with `cid:` references and returns the
/// extracted images so they can be sent as inline attachments.
pub fn extract_inline_images(html : String) -> (String, Array[InlineImage]) {
  let output = StringBuilder(capacity=html.length())
  let images : Array[InlineImage] = []
  let mut cursor = 0
  while cursor < html.length() {
    let rest = html[cursor:]
    let found = rest.find("src=\"data:")
    match found {
      None => {
        output.write_view(rest)
        cursor = html.length()
      }
      Some(position) => {
        let start = cursor + position + 5
        output.write_view(html[cursor:start])
        let data_rest = html[start:]
        match data_rest.find("\"") {
          None => {
            output.write_view(data_rest)
            cursor = html.length()
          }
          Some(end) => {
            let data_url = data_rest[:end]
            match parse_data_url(data_url) {
              None => output.write_view(data_url)
              Some(parsed) => {
                let index = images.length() + 1
                let content_id = "sigil-inline-" +
                  index.to_string() +
                  "@sigil.local"
                let filename = "sigil-inline-" +
                  index.to_string() +
                  extension_for(parsed.mime)
                images.push({
                  content_id,
                  filename,
                  mime: parsed.mime,
                  base64: parsed.base64,
                })
                output.write_string("cid:" + content_id)
              }
            }
            cursor = start + end
          }
        }
      }
    }
  }
  (output.to_string(), images)
}

///|
fn resend_attachments(
  images : Array[InlineImage],
  attachments : Array[Attachment],
) -> Json {
  let entries : Array[Json] = []
  for image in images {
    entries.push(
      Json::object(
        Map([
          ("filename", Json::string(image.filename)),
          ("content", Json::string(image.base64)),
          ("content_id", Json::string(image.content_id)),
        ]),
      ),
    )
  }
  for attachment in attachments {
    entries.push(
      Json::object(
        Map([
          ("filename", Json::string(attachment.filename)),
          ("content", Json::string(attachment.base64)),
        ]),
      ),
    )
  }
  Json::array(entries)
}

///|
fn sendgrid_attachments(
  images : Array[InlineImage],
  attachments : Array[Attachment],
) -> Json {
  let entries : Array[Json] = []
  for image in images {
    entries.push(
      Json::object(
        Map([
          ("content", Json::string(image.base64)),
          ("filename", Json::string(image.filename)),
          ("type", Json::string(image.mime)),
          ("disposition", Json::string("inline")),
          ("content_id", Json::string(image.content_id)),
        ]),
      ),
    )
  }
  for attachment in attachments {
    entries.push(
      Json::object(
        Map([
          ("content", Json::string(attachment.base64)),
          ("filename", Json::string(attachment.filename)),
          ("type", Json::string(attachment.mime)),
          ("disposition", Json::string("attachment")),
        ]),
      ),
    )
  }
  Json::array(entries)
}

///|
fn envelope_from(config : DeliveryConfig) -> String {
  let name = config.from_name.trim()
  let address = config.from_address.trim()
  if name == "" {
    address.to_owned()
  } else {
    name.to_owned() + " <" + address.to_owned() + ">"
  }
}

///|
/// Builds the provider-specific JSON body for one message.
///
/// Inline `data:` images are converted to attachments and referenced through
/// `cid:` URLs so Gmail and other clients keep displaying them. User-selected
/// files are appended as regular `attachment`-disposition entries.
pub fn build_delivery_payload(
  config : DeliveryConfig,
  to : Array[String],
  subject : String,
  html : String,
  attachments : Array[Attachment],
) -> Json {
  let (html, images) = extract_inline_images(html)
  if normalize_provider(config.provider) == "sendgrid" {
    let recipients = to.map(fn(address) {
      Json::object(Map([("email", Json::string(address))]))
    })
    let fields : Map[String, Json] = Map([])
    fields["personalizations"] = Json::array([
      Json::object(Map([("to", Json::array(recipients))])),
    ])
    fields["from"] = Json::object(
      Map([
        ("email", Json::string(config.from_address.trim().to_owned())),
        ("name", Json::string(config.from_name.trim().to_owned())),
      ]),
    )
    fields["subject"] = Json::string(subject)
    fields["content"] = Json::array([
      Json::object(
        Map([("type", Json::string("text/html")), ("value", Json::string(html))]),
      ),
    ])
    if !images.is_empty() || !attachments.is_empty() {
      fields["attachments"] = sendgrid_attachments(images, attachments)
    }
    Json::object(fields)
  } else {
    let fields : Map[String, Json] = Map([])
    fields["from"] = Json::string(envelope_from(config))
    fields["to"] = Json::array(to.map(fn(address) { Json::string(address) }))
    fields["subject"] = Json::string(subject)
    fields["html"] = Json::string(html)
    if !images.is_empty() || !attachments.is_empty() {
      fields["attachments"] = resend_attachments(images, attachments)
    }
    Json::object(fields)
  }
}
