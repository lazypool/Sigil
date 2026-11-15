///|
/// One editable field in the delivery settings form.
enum MailField {
  Provider
  Endpoint
  FromName
  FromAddress
  ApiKey
}

///|
/// Renderer-side mirror of the backend delivery settings.
///
/// `api_key` is an input buffer only; `api_key_set` reports whether the backend
/// already holds a key, and an empty buffer means "keep the stored key".
#derive(Eq)
struct MailForm {
  provider : String
  endpoint : String
  from_name : String
  from_address : String
  api_key : String
  api_key_set : Bool
}

///|
fn default_mail_form() -> MailForm {
  {
    provider: "resend",
    endpoint: "",
    from_name: "",
    from_address: "",
    api_key: "",
    api_key_set: false,
  }
}

///|
fn MailForm::default_endpoint(self : MailForm) -> String {
  match self.provider {
    "sendgrid" => "https://api.sendgrid.com/v3/mail/send"
    _ => "https://api.resend.com/emails"
  }
}

///|
fn help_link(provider : String) -> String {
  match provider {
    "sendgrid" => "https://app.sendgrid.com/settings/api_keys"
    _ => "https://resend.com/api-keys"
  }
}

///|
fn profile_delivery_email(profile : Profile) -> String {
  let email = profile.email.trim()
  if email == "" || email.has_suffix("@example.com") {
    ""
  } else {
    email.to_owned()
  }
}

///|
fn parse_mail_settings(json : String) -> MailForm {
  let parsed = @json.parse(json) catch { _ => return default_mail_form() }
  let settings : @contract.MailSettings = @json.from_json(parsed) catch {
    _ => return default_mail_form()
  }
  {
    provider: settings.provider,
    endpoint: settings.endpoint,
    from_name: settings.from_name,
    from_address: settings.from_address,
    api_key: "",
    api_key_set: settings.api_key_set,
  }
}

///|
fn mail_update_json(form : MailForm) -> String {
  @json.ToJson::to_json(@contract.MailSettingsUpdate::{
    provider: form.provider,
    endpoint: form.endpoint,
    from_name: form.from_name,
    from_address: form.from_address,
    api_key: form.api_key,
  }).stringify()
}

///|
fn send_request_json(
  to : Array[String],
  subject : String,
  html : String,
) -> String {
  @json.ToJson::to_json(@contract.SendEmailRequest::{
    to,
    subject,
    html,
  }).stringify()
}

///|
/// A permissive reply shape. Command failures arrive as `{ code, message }`
/// without `api_key_set`, so decoding strictly would hide the real error.
#derive(FromJson)
struct MailReplyEnvelope {
  ok : Bool?
  message : String?
  api_key_set : Bool?
}

///|
fn parse_reply(json : String) -> (Bool, String, Bool) {
  let parsed = @json.parse(json) catch {
    _ => return (false, "Unexpected reply from the backend.", false)
  }
  let envelope : MailReplyEnvelope = @json.from_json(parsed) catch {
    _ => return (false, "Unexpected reply from the backend.", false)
  }
  let ok = match envelope.ok {
    Some(value) => value
    None => false
  }
  let message = match envelope.message {
    Some(value) => value
    None => "Unexpected reply from the backend."
  }
  let api_key_set = match envelope.api_key_set {
    Some(value) => value
    None => false
  }
  (ok, message, api_key_set)
}

///|
fn parse_send_reply(json : String) -> (Bool, String) {
  let (ok, message, _) = parse_reply(json)
  (ok, message)
}

///|
fn parse_save_reply(json : String) -> (Bool, String, Bool) {
  parse_reply(json)
}

///|
fn test_mail_json(form : MailForm, to : String) -> String {
  @json.ToJson::to_json(@contract.TestMailSettingsRequest::{
    settings: @contract.MailSettingsUpdate::{
      provider: form.provider,
      endpoint: form.endpoint,
      from_name: form.from_name,
      from_address: form.from_address,
      api_key: form.api_key,
    },
    to,
  }).stringify()
}

///|
fn parse_recipients(input : String) -> Array[String]? {
  let result : Array[String] = []
  let normalized = input.replace_all(old=";", new=",")
  for part in normalized.split(",") {
    let address = part.trim()
    if address == "" {
      continue
    }
    guard address.contains("@") else { return None }
    result.push(address.to_owned())
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
extern "js" fn invoke_bridge_promise(
  op : String,
  payload : String,
) -> @js_async.Promise[String] =
  #| (op, payload) => {
  #|   return (async () => {
  #|     try {
  #|       const bridge = globalThis.__MoonBit__;
  #|       if (!bridge || !bridge.core || typeof bridge.core.invokeOp !== 'function') {
  #|         return JSON.stringify({
  #|           ok: false,
  #|           message: 'The native bridge is unavailable. Run Sigil as the desktop app.'
  #|         });
  #|       }
  #|       const reply = await bridge.core.invokeOp(op, JSON.parse(payload));
  #|       return JSON.stringify(reply);
  #|     } catch (error) {
  #|       const base = String((error && error.message) || error);
  #|       const detail = error && error.detail ? ': ' + String(error.detail) : '';
  #|       return JSON.stringify({ ok: false, message: base + detail });
  #|     }
  #|   })();
  #| }

///|
extern "js" fn copy_text(text : String) -> Unit =
  #| (text) => {
  #|   try {
  #|     if (navigator.clipboard && navigator.clipboard.writeText) {
  #|       navigator.clipboard.writeText(text);
  #|       return;
  #|     }
  #|   } catch (error) {}
  #|   try {
  #|     const area = document.createElement('textarea');
  #|     area.value = text;
  #|     area.style.position = 'fixed';
  #|     area.style.opacity = '0';
  #|     document.body.appendChild(area);
  #|     area.select();
  #|     document.execCommand('copy');
  #|     area.remove();
  #|   } catch (error) {}
  #| }

///|
async fn bridge_task(op : String, payload : String) -> String noraise {
  @js_async.run_promise(_ => invoke_bridge_promise(op, payload)) catch {
    _ => "{\"ok\":false,\"message\":\"The native bridge is unavailable.\"}"
  }
}

///|
async fn load_mail_task() -> String noraise {
  bridge_task("app:get_mail_settings", "{}")
}

///|
async fn save_mail_task(payload : String) -> String noraise {
  bridge_task("app:save_mail_settings", payload)
}

///|
async fn test_mail_task(payload : String) -> String noraise {
  bridge_task("app:test_mail_settings", payload)
}

///|
async fn send_mail_task(
  html : String,
  to : String,
  subject : String,
) -> String noraise {
  let prepared = @js_async.run_promise(_ => prepare_email_html(html)) catch {
    _ => html
  }
  match parse_recipients(to) {
    None => "{\"ok\":false,\"message\":\"Add at least one valid recipient.\"}"
    Some(addresses) => {
      let payload = send_request_json(addresses, subject, prepared)
      bridge_task("app:send_email", payload)
    }
  }
}

///|
fn mail_field(
  emit : Emit[Msg],
  text : String,
  field : MailField,
  value : String,
  kind : @html.InputType,
  placeholder : String,
  hint : String,
  wide~ : Bool = false,
) -> Html {
  label(class=if wide { "sigil-field is-wide" } else { "sigil-field" }, [
    span(class="sigil-field-label", text),
    input(
      input_type=kind,
      class="sigil-field-input",
      value~,
      placeholder~,
      on_input=emit.map(input => MailFieldChanged(field, input)),
    ),
    if hint == "" {
      @html.nothing
    } else {
      span(class="sigil-field-hint", hint)
    },
  ])
}

///|
fn test_recipient_field(emit : Emit[Msg], model : Model) -> Html {
  label(class="sigil-field is-wide", [
    span(
      class="sigil-field-label",
      tr(model.lang, "Test recipient", "测试收件人"),
    ),
    input(
      input_type=@html.InputType::Email,
      class="sigil-field-input",
      value=model.mail_test_to,
      placeholder="you@example.com",
      on_input=emit.map(text => MailTestToChanged(text)),
    ),
    span(
      class="sigil-field-hint",
      tr(
        model.lang,
        "The test email is sent here. Use an inbox you can check.",
        "测试邮件会发到这里，请填写你能收到的邮箱。",
      ),
    ),
  ])
}

///|
fn mail_status(model : Model) -> Html {
  let ready = model.mail.api_key_set && model.mail.from_address.trim() != ""
  div(
    class=if ready {
      "sigil-mail-status is-ready"
    } else {
      "sigil-mail-status is-missing"
    },
    [
      span(class="sigil-mail-status-dot", ([] : Array[Html])),
      span(
        class="sigil-mail-status-text",
        if ready {
          tr(model.lang, "Ready to send", "可以发送")
        } else {
          tr(model.lang, "Not set up yet", "尚未设置")
        },
      ),
    ],
  )
}

///|
fn provider_card(
  emit : Emit[Msg],
  model : Model,
  value : String,
  title : String,
  description : String,
) -> Html {
  button(
    type_="button",
    class=if model.mail.provider == value {
      "sigil-mail-provider is-selected"
    } else {
      "sigil-mail-provider"
    },
    on_click=emit(MailFieldChanged(Provider, value)),
    [
      span(class="sigil-mail-provider-title", title),
      span(class="sigil-mail-provider-description", description),
    ],
  )
}

///|
fn setup_steps(lang : Lang, provider : String) -> Array[String] {
  if provider == "sendgrid" {
    [
      tr(lang, "Create a free SendGrid account.", "注册免费的 SendGrid 账号。"),
      tr(
        lang,
        "Verify your email under Settings > Sender Authentication > Single Sender.",
        "在 Settings > Sender Authentication > Single Sender 中验证你的邮箱。",
      ),
      tr(
        lang,
        "Create an API key with Mail Send permission.",
        "创建一个拥有 Mail Send 权限的 API 密钥。",
      ),
      tr(
        lang,
        "Paste the key below and click Save & test.",
        "把密钥粘贴到下方，然后点击“保存并测试”。",
      ),
    ]
  } else {
    [
      tr(lang, "Create a free Resend account.", "注册免费的 Resend 账号。"),
      tr(
        lang,
        "Add a domain you own under Domains and finish DNS verification.",
        "在 Domains 中添加你拥有的域名并完成 DNS 验证。",
      ),
      tr(
        lang,
        "Create an API key under API Keys.",
        "在 API Keys 中创建一个 API 密钥。",
      ),
      tr(
        lang,
        "Paste the key below and click Save & test.",
        "把密钥粘贴到下方，然后点击“保存并测试”。",
      ),
    ]
  }
}

///|
fn mail_settings_section(emit : Emit[Msg], model : Model) -> Html {
  let provider_choices : Array[Html] = [
    provider_card(
      emit,
      model,
      "resend",
      "Resend",
      tr(
        model.lang,
        "Recommended if you own a domain. onboarding@resend.dev only tests your own Resend account email.",
        "拥有域名时推荐。onboarding@resend.dev 只能测试你自己的 Resend 账号邮箱。",
      ),
    ),
    provider_card(
      emit,
      model,
      "sendgrid",
      "SendGrid",
      tr(
        model.lang,
        "Good if you only have an email address. Verify a single sender.",
        "只有邮箱地址时可用，验证单个发件人即可。",
      ),
    ),
  ]
  let step_rows : Array[Html] = []
  let mut step_number = 1
  for step in setup_steps(model.lang, model.mail.provider) {
    step_rows.push(
      div(class="sigil-mail-step", [
        span(class="sigil-mail-step-number", step_number.to_string()),
        span(class="sigil-mail-step-text", step),
      ]),
    )
    step_number = step_number + 1
  }
  let key_placeholder = if model.mail.api_key_set {
    tr(model.lang, "Stored - leave blank to keep", "已保存 - 留空保持不变")
  } else {
    tr(model.lang, "Paste your API key", "粘贴 API 密钥")
  }
  let notice = if model.mail_notice == "" {
    @html.nothing
  } else {
    div(
      class=if model.mail_notice_ok {
        "sigil-mail-notice is-success"
      } else {
        "sigil-mail-notice is-error"
      },
      model.mail_notice,
    )
  }
  let advanced = model.mail_advanced_open
  div(class="sigil-settings-section", [
    div(class="sigil-settings-row", [
      div(class="sigil-settings-copy", [
        span(
          class="sigil-settings-title",
          tr(model.lang, "Send email", "邮件发送"),
        ),
        span(
          class="sigil-settings-description",
          tr(
            model.lang,
            "Sigil has no mail server of its own. Connect a free transactional email service once, then send from the preview.",
            "Sigil 本身不带邮件服务器。只需连接一次免费的第三方发信服务，之后就能从预览栏直接发送。",
          ),
        ),
      ]),
      mail_status(model),
    ]),
    div(class="sigil-mail-guide", [
      span(
        class="sigil-mail-guide-title",
        tr(model.lang, "How to connect", "如何连接"),
      ),
      div(class="sigil-mail-provider-row", provider_choices),
      span(
        class="sigil-mail-guide-note",
        tr(
          model.lang,
          "No domain? Choose SendGrid and verify your existing email address instead.",
          "没有域名？改选 SendGrid，验证你现有的邮箱即可。",
        ),
      ),
      div(class="sigil-mail-steps", step_rows),
      div(class="sigil-mail-link-row", [
        span(class="sigil-mail-link", help_link(model.mail.provider)),
        button(
          type_="button",
          class="sigil-button is-small",
          on_click=emit(CopyMailHelpLink),
          tr(model.lang, "Copy link", "复制链接"),
        ),
      ]),
    ]),
    div(class="sigil-field-grid", [
      mail_field(
        emit,
        tr(model.lang, "From name", "发件人名称"),
        FromName,
        model.mail.from_name,
        @html.InputType::Text,
        "Sigil",
        tr(model.lang, "Shown in the recipient's inbox.", "收件人看到的显示名。"),
      ),
      mail_field(
        emit,
        tr(model.lang, "From address", "发件邮箱"),
        FromAddress,
        model.mail.from_address,
        @html.InputType::Email,
        "hello@example.com",
        if model.mail.provider == "sendgrid" {
          tr(
            model.lang,
            "Must be the email you verified in SendGrid.",
            "必须是在 SendGrid 中验证过的邮箱。",
          )
        } else {
          tr(
            model.lang,
            "Must use your verified domain. onboarding@resend.dev only works for your own account email.",
            "必须使用你已验证的域名。onboarding@resend.dev 只能发到你自己的 Resend 账号邮箱。",
          )
        },
      ),
      mail_field(
        emit,
        tr(model.lang, "API key", "API 密钥"),
        ApiKey,
        model.mail.api_key,
        @html.InputType::Password,
        key_placeholder,
        tr(
          model.lang,
          "Stored on this computer only.",
          "只保存在这台电脑上。",
        ),
      ),
    ]),
    div(class="sigil-field-grid", [
      test_recipient_field(emit, model),
    ]),
    div(class="sigil-mail-advanced", [
      button(
        type_="button",
        class="sigil-mail-advanced-toggle",
        on_click=emit(ToggleMailAdvanced),
        if advanced {
          tr(model.lang, "Hide advanced", "隐藏高级设置")
        } else {
          tr(model.lang, "Advanced", "高级设置")
        },
      ),
      if advanced {
        div(class="sigil-field-grid", [
          mail_field(
            emit,
            tr(model.lang, "Endpoint", "接口地址"),
            Endpoint,
            model.mail.endpoint,
            @html.InputType::Url,
            model.mail.default_endpoint(),
            tr(
              model.lang,
              "Leave blank unless you use a custom gateway.",
              "除非使用自建网关，否则留空。",
            ),
            wide=true,
          ),
        ])
      } else {
        @html.nothing
      },
    ]),
    notice,
    div(class="sigil-mail-actions", [
      button(
        type_="button",
        class="sigil-button",
        on_click=emit(SaveMailSettings),
        tr(model.lang, "Save", "保存"),
      ),
      button(
        type_="button",
        class="sigil-button is-primary",
        on_click=emit(TestMailSettings),
        tr(model.lang, "Save & test", "保存并测试"),
      ),
    ]),
  ])
}

///|
fn send_button(emit : Emit[Msg], model : Model) -> Html {
  button(
    type_="button",
    class="sigil-send",
    title=tr(model.lang, "Send this email", "发送这封邮件"),
    disabled=active_document(model) is None,
    on_click=emit(OpenSend),
    [span(tr(model.lang, "Send", "发送"))],
  )
}

///|
fn send_dialog(emit : Emit[Msg], model : Model) -> Html {
  if !model.send_open {
    return @html.nothing
  }
  let ready = model.mail.api_key_set && model.mail.from_address.trim() != ""
  let warning = if ready {
    @html.nothing
  } else {
    div(class="sigil-modal-warning", [
      span(
        class="sigil-modal-warning-title",
        tr(model.lang, "One-time setup required", "需要先完成一次设置"),
      ),
      span(
        class="sigil-modal-warning-text",
        tr(
          model.lang,
          "Choose a provider, paste an API key, and verify your from address. Sigil walks you through it in Settings > Mail delivery.",
          "选择服务商、粘贴 API 密钥并验证发件邮箱。Sigil 会在“设置 > 邮件发送”中一步步引导你完成。",
        ),
      ),
    ])
  }
  let notice = if model.send_notice == "" {
    @html.nothing
  } else {
    div(
      class=if model.send_notice_ok {
        "sigil-modal-notice is-success"
      } else {
        "sigil-modal-notice is-error"
      },
      model.send_notice,
    )
  }
  let send_label = if model.send_busy {
    tr(model.lang, "Sending...", "发送中...")
  } else {
    tr(model.lang, "Send", "发送")
  }
  let actions = if ready {
    [
      button(
        type_="button",
        class="sigil-button",
        on_click=emit(OpenDeliverySettings),
        tr(model.lang, "Delivery settings", "发送设置"),
      ),
      div(class="sigil-modal-spacer", ([] : Array[Html])),
      button(
        type_="button",
        class="sigil-button",
        on_click=emit(CloseSend),
        tr(model.lang, "Cancel", "取消"),
      ),
      button(
        type_="button",
        class="sigil-button is-primary",
        disabled=model.send_busy,
        on_click=emit(BeginSend),
        [span(send_label)],
      ),
    ]
  } else {
    [
      div(class="sigil-modal-spacer", ([] : Array[Html])),
      button(
        type_="button",
        class="sigil-button",
        on_click=emit(CloseSend),
        tr(model.lang, "Cancel", "取消"),
      ),
      button(
        type_="button",
        class="sigil-button is-primary",
        on_click=emit(OpenDeliverySettings),
        tr(model.lang, "Set up sending", "设置发送"),
      ),
    ]
  }
  div(class="sigil-modal-backdrop", [
    div(class="sigil-modal", [
      div(class="sigil-modal-heading", [
        span(
          class="sigil-modal-title",
          tr(model.lang, "Send email", "发送邮件"),
        ),
        span(
          class="sigil-modal-subtitle",
          tr(
            model.lang,
            "Exports the rendered HTML and sends it in one step.",
            "自动导出渲染后的 HTML 并直接发送。",
          ),
        ),
      ]),
      warning,
      label(class="sigil-field", [
        span(class="sigil-field-label", tr(model.lang, "To", "收件人")),
        input(
          input_type=@html.InputType::Text,
          class="sigil-field-input",
          value=model.send_to,
          placeholder="reader@example.com, team@example.com",
          on_input=emit.map(text => SendToChanged(text)),
        ),
      ]),
      label(class="sigil-field", [
        span(
          class="sigil-field-label",
          tr(model.lang, "Subject", "主题"),
        ),
        input(
          input_type=@html.InputType::Text,
          class="sigil-field-input",
          value=model.send_subject,
          on_input=emit.map(text => SendSubjectChanged(text)),
        ),
      ]),
      notice,
      div(class="sigil-modal-actions", actions),
    ]),
  ])
}

///|
fn MailForm::with_field(
  self : MailForm,
  field : MailField,
  value : String,
) -> MailForm {
  match field {
    Provider => { ..self, provider: value, endpoint: "", }
    Endpoint => { ..self, endpoint: value, }
    FromName => { ..self, from_name: value, }
    FromAddress => { ..self, from_address: value, }
    ApiKey => { ..self, api_key: value, }
  }
}
