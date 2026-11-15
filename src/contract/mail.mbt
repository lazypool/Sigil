///|
/// Mail delivery settings safe to hand back to the renderer.
///
/// The API key never leaves the native backend; `api_key_set` only reports
/// whether one has been stored.
#derive(ToJson, FromJson)
pub(all) struct MailSettings {
  provider : String
  endpoint : String
  from_name : String
  from_address : String
  api_key_set : Bool
}

///|
/// A settings update sent from the renderer.
///
/// An empty `api_key` means "keep the stored key".
#derive(ToJson, FromJson)
pub(all) struct MailSettingsUpdate {
  provider : String
  endpoint : String
  from_name : String
  from_address : String
  api_key : String
}

///|
/// One send request. `html` is the fully rendered, email-safe document.
#derive(ToJson, FromJson)
pub(all) struct SendEmailRequest {
  to : Array[String]
  subject : String
  html : String
}

///|
/// A settings test request. The test message goes to `to`, which is usually
/// the user's own inbox.
#derive(ToJson, FromJson)
pub(all) struct TestMailSettingsRequest {
  settings : MailSettingsUpdate
  to : String
}

///|
/// The outcome of a send attempt.
#derive(ToJson, FromJson)
pub(all) struct SendEmailReply {
  ok : Bool
  message : String
}

///|
/// The outcome of a settings save.
#derive(ToJson, FromJson)
pub(all) struct SaveMailSettingsReply {
  ok : Bool
  message : String
  api_key_set : Bool
}

///|
pub extend MailSettings with @json.ToJson::{to_json}

///|
pub extend MailSettings with @json.FromJson::{from_json}

///|
pub extend MailSettingsUpdate with @json.ToJson::{to_json}

///|
pub extend MailSettingsUpdate with @json.FromJson::{from_json}

///|
pub extend TestMailSettingsRequest with @json.ToJson::{to_json}

///|
pub extend TestMailSettingsRequest with @json.FromJson::{from_json}

///|
pub extend SendEmailRequest with @json.ToJson::{to_json}

///|
pub extend SendEmailRequest with @json.FromJson::{from_json}

///|
pub extend SendEmailReply with @json.ToJson::{to_json}

///|
pub extend SendEmailReply with @json.FromJson::{from_json}

///|
pub extend SaveMailSettingsReply with @json.ToJson::{to_json}

///|
pub extend SaveMailSettingsReply with @json.FromJson::{from_json}
