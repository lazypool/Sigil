///|
/// Mail delivery state owned by the native backend.
///
/// The API key is persisted here and is never returned to the renderer.

///|
#derive(ToJson, FromJson)
struct StoredMailSettings {
  provider : String
  endpoint : String
  from_name : String
  from_address : String
  api_key : String
}

///|
fn empty_stored_settings() -> StoredMailSettings {
  {
    provider: "resend",
    endpoint: "",
    from_name: "",
    from_address: "",
    api_key: "",
  }
}

///|
fn mail_config_path(app : @proton.App) -> String {
  let data_dir = app.path(@proton.AppPathKind::UserData) catch {
    _ => @proton.app_path()
  }
  data_dir + "/mail.json"
}

///|
async fn load_stored_settings(path : String) -> StoredMailSettings {
  if !@fs.exists(path) {
    return empty_stored_settings()
  }
  let text = @fs.read_text(path) catch { _ => return empty_stored_settings() }
  let parsed = @json.parse(text) catch { _ => return empty_stored_settings() }
  @json.from_json(parsed) catch {
    _ => empty_stored_settings()
  }
}

///|
async fn store_settings(path : String, settings : StoredMailSettings) -> Unit {
  let json = @json.ToJson::to_json(settings)
  @fs.write_text(
    path,
    json.stringify(),
    create_mode=@fs.CreateMode::CreateOrTruncate,
    permission=384,
  )
  @fs.chmod(path, 384) catch {
    _ => ()
  }
}

///|
fn public_settings(settings : StoredMailSettings) -> @contract.MailSettings {
  {
    provider: @mail.normalize_provider(settings.provider),
    endpoint: settings.endpoint,
    from_name: settings.from_name,
    from_address: settings.from_address,
    api_key_set: settings.api_key != "",
  }
}

///|
async fn get_mail_settings(
  path : String,
  _request : @proton_contract.EmptyRequest,
) -> @contract.MailSettings {
  let settings = load_stored_settings(path)
  public_settings(settings)
}

///|
async fn save_mail_settings(
  path : String,
  update : @contract.MailSettingsUpdate,
) -> @contract.SaveMailSettingsReply {
  let existing = load_stored_settings(path)
  let api_key = if update.api_key.trim() == "" {
    existing.api_key
  } else {
    update.api_key.trim().to_owned()
  }
  let settings = StoredMailSettings::{
    provider: @mail.normalize_provider(update.provider),
    endpoint: update.endpoint.trim().to_owned(),
    from_name: update.from_name.trim().to_owned(),
    from_address: update.from_address.trim().to_owned(),
    api_key,
  }
  if settings.from_address == "" {
    return {
      ok: false,
      message: "A from address is required.",
      api_key_set: settings.api_key != "",
    }
  }
  store_settings(path, settings) catch {
    error =>
      return {
        ok: false,
        message: "Could not save settings: " + error.to_string(),
        api_key_set: existing.api_key != "",
      }
  }
  {
    ok: true,
    message: "Delivery settings saved.",
    api_key_set: settings.api_key != "",
  }
}

///|
fn authorization_headers(api_key : String) -> @http.Headers {
  Map([
    (@http.CaseInsensitiveString("Authorization"), "Bearer " + api_key),
    (@http.CaseInsensitiveString("Content-Type"), "application/json"),
  ])
}

///|
fn response_error(provider : String, status : Int32, body : String) -> String {
  let trimmed = body.trim()
  let detail = if trimmed.length() == 0 {
    "no response body"
  } else if trimmed.length() > 400 {
    trimmed[:400].to_owned()
  } else {
    trimmed.to_owned()
  }
  let hint = match status {
    401 =>
      "The API key was rejected. Create a new key and paste it again."
    403 =>
      "The from address is not verified, or the key lacks Mail Send permission."
    404 =>
      "The endpoint was not found. Leave the endpoint blank unless you use a custom gateway."
    422 =>
      "The provider rejected the message. Check the from address and recipients."
    429 => "Too many requests. Wait a moment and try again."
    _ =>
      if status >= 500 {
        "The provider is temporarily unavailable. Try again later."
      } else {
        "The provider rejected the request."
      }
  }
  provider.to_upper() +
  " error " +
  status.to_string() +
  ": " +
  hint +
  " (" +
  detail +
  ")"
}

///|
async fn deliver(
  stored : StoredMailSettings,
  to : Array[String],
  subject : String,
  html : String,
) -> @contract.SendEmailReply {
  if stored.api_key == "" {
    return {
      ok: false,
      message: "Add an API key under Settings / Mail delivery first.",
    }
  }
  if stored.from_address == "" {
    return {
      ok: false,
      message: "Add a from address under Settings / Mail delivery first.",
    }
  }
  if to.is_empty() {
    return { ok: false, message: "Add at least one recipient.", }
  }
  let config = @mail.DeliveryConfig::{
    provider: stored.provider,
    endpoint: stored.endpoint,
    from_name: stored.from_name,
    from_address: stored.from_address,
    api_key: stored.api_key,
  }
  let endpoint = @mail.endpoint_for(config)
  let payload = @mail.build_delivery_payload(config, to, subject, html)
  let response = @http.post_text(
    endpoint,
    payload.stringify(),
    headers=authorization_headers(stored.api_key),
  ) catch {
    error =>
      return { ok: false, message: "Network error: " + error.to_string(), }
  }
  let (header, body) = response
  if header.code >= 200 && header.code < 300 {
    { ok: true, message: "Email sent.", }
  } else {
    let body_text = body.text() catch { _ => "" }
    {
      ok: false,
      message: response_error(stored.provider, header.code, body_text),
    }
  }
}

///|
async fn send_email_inner(
  path : String,
  request : @contract.SendEmailRequest,
) -> @contract.SendEmailReply {
  let stored = load_stored_settings(path)
  deliver(stored, request.to, request.subject, request.html)
}

///|
async fn send_email(
  path : String,
  request : @contract.SendEmailRequest,
) -> @contract.SendEmailReply {
  send_email_inner(path, request) catch {
    error => {
      ok: false,
      message: "Send failed: " + error.to_string(),
    }
  }
}

///|
fn test_email_html(provider : String) -> String {
  "<div style=\"font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:15px;line-height:1.6;color:#222833;\">" +
  "<p style=\"margin:0 0 12px;\"><strong>Sigil test email</strong></p>" +
  "<p style=\"margin:0;\">If you can read this, " +
  provider +
  " delivery is working. You can go back to Sigil and send your email.</p>" +
  "</div>"
}

///|
async fn test_mail_settings_inner(
  path : String,
  request : @contract.TestMailSettingsRequest,
) -> @contract.SaveMailSettingsReply {
  let recipient = request.to.trim()
  if recipient == "" || !recipient.contains("@") {
    let existing = load_stored_settings(path)
    return {
      ok: false,
      message: "Enter a test recipient email address.",
      api_key_set: existing.api_key != "",
    }
  }
  let saved = save_mail_settings(path, request.settings)
  if !saved.ok {
    return saved
  }
  let stored = load_stored_settings(path)
  let reply = deliver(
    stored,
    [recipient.to_owned()],
    "Sigil test email",
    test_email_html(stored.provider),
  )
  {
    ok: reply.ok,
    message: reply.message,
    api_key_set: stored.api_key != "",
  }
}

///|
async fn test_mail_settings(
  path : String,
  request : @contract.TestMailSettingsRequest,
) -> @contract.SaveMailSettingsReply {
  test_mail_settings_inner(path, request) catch {
    error => {
      ok: false,
      message: "Test failed: " + error.to_string(),
      api_key_set: false,
    }
  }
}

///|
let get_mail_settings_command : @proton_contract.Command[
  @proton_contract.EmptyRequest,
  @contract.MailSettings,
] = @proton_contract.command("get_mail_settings")

///|
let save_mail_settings_command : @proton_contract.Command[
  @contract.MailSettingsUpdate,
  @contract.SaveMailSettingsReply,
] = @proton_contract.command("save_mail_settings")

///|
let send_email_command : @proton_contract.Command[
  @contract.SendEmailRequest,
  @contract.SendEmailReply,
] = @proton_contract.command("send_email")

///|
let test_mail_settings_command : @proton_contract.Command[
  @contract.TestMailSettingsRequest,
  @contract.SaveMailSettingsReply,
] = @proton_contract.command("test_mail_settings")
