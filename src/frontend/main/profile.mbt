///|
/// The global writer profile. Stage 0 keeps it in browser storage until the
/// backend storage stage provides native persistence.
#derive(Eq)
struct Profile {
  name : String
  nickname : String
  email : String
  phone : String
  title : String
  company : String
  website : String
  education : String
  avatar : String
}

///|
enum ProfileField {
  Name
  Alias
  Email
  Phone
  Title
  Company
  Website
  Education
  Avatar
}

///|
let profile_field_count = 8

///|
extern "js" fn storage_get(key : String) -> String = "(key) => { try { return localStorage.getItem(key) ?? '' } catch (e) { return '' } }"

///|
extern "js" fn storage_set(key : String, value : String) -> Unit = "(key, value) => { try { localStorage.setItem(key, value) } catch (e) {} }"

///|
/// Meaningful, clearly fictional values used when the writer has not filled in a
/// profile field yet. `example.com` is reserved for documentation, so these are
/// safe placeholders that keep signatures and footers rendering correctly.
fn profile_placeholders() -> Profile {
  {
    name: "Zhang San",
    nickname: "San",
    email: "zhangsan@example.com",
    phone: "+86 138 0000 0000",
    title: "Product Manager",
    company: "Example Inc.",
    website: "https://example.com",
    education: "Example University · Computer Science",
    avatar: "",
  }
}

///|
fn placeholder_text(value : String, fallback : String) -> String {
  if value.trim() == "" {
    fallback
  } else {
    value
  }
}

///|
fn Profile::with_placeholders(self : Profile) -> Profile {
  let defaults = profile_placeholders()
  {
    ..self,
    name: placeholder_text(self.name, defaults.name),
    nickname: placeholder_text(self.nickname, defaults.nickname),
    email: placeholder_text(self.email, defaults.email),
    phone: placeholder_text(self.phone, defaults.phone),
    title: placeholder_text(self.title, defaults.title),
    company: placeholder_text(self.company, defaults.company),
    website: placeholder_text(self.website, defaults.website),
    education: placeholder_text(self.education, defaults.education),
  }
}

///|
fn load_profile() -> Profile {
  let stored = {
    name: storage_get("sigil.profile.name"),
    nickname: storage_get("sigil.profile.alias"),
    email: storage_get("sigil.profile.email"),
    phone: storage_get("sigil.profile.phone"),
    title: storage_get("sigil.profile.title"),
    company: storage_get("sigil.profile.company"),
    website: storage_get("sigil.profile.website"),
    education: storage_get("sigil.profile.education"),
    avatar: storage_get("sigil.profile.avatar"),
  }
  stored.with_placeholders()
}

///|
fn save_profile(profile : Profile) -> Unit {
  storage_set("sigil.profile.name", profile.name)
  storage_set("sigil.profile.alias", profile.nickname)
  storage_set("sigil.profile.email", profile.email)
  storage_set("sigil.profile.phone", profile.phone)
  storage_set("sigil.profile.title", profile.title)
  storage_set("sigil.profile.company", profile.company)
  storage_set("sigil.profile.website", profile.website)
  storage_set("sigil.profile.education", profile.education)
  storage_set("sigil.profile.avatar", profile.avatar)
}

///|
fn Profile::with_field(
  self : Profile,
  field : ProfileField,
  value : String,
) -> Profile {
  match field {
    Name => { ..self, name: value, }
    Alias => { ..self, nickname: value, }
    Email => { ..self, email: value, }
    Phone => { ..self, phone: value, }
    Title => { ..self, title: value, }
    Company => { ..self, company: value, }
    Website => { ..self, website: value, }
    Education => { ..self, education: value, }
    Avatar => { ..self, avatar: value, }
  }
}

///|
fn Profile::initial(self : Profile) -> String {
  let source = if self.name != "" {
    self.name
  } else if self.nickname != "" {
    self.nickname
  } else {
    self.email
  }
  match source.get_char(0) {
    Some(ch) => ch.to_string().to_upper()
    None => "P"
  }
}

///|
fn Profile::filled_fields(self : Profile) -> Int32 {
  let values = [
    self.name,
    self.nickname,
    self.email,
    self.phone,
    self.title,
    self.company,
    self.website,
    self.education,
  ]
  let mut count = 0
  for value in values {
    if value != "" {
      count = count + 1
    }
  }
  count
}

///|
fn Profile::completeness(self : Profile) -> String {
  self.filled_fields().to_string() + "/" + profile_field_count.to_string()
}

///|
fn to_core_profile(profile : Profile) -> @types.Profile {
  let resolved = profile.with_placeholders()
  {
    name: resolved.name,
    nickname: resolved.nickname,
    email: resolved.email,
    phone: resolved.phone,
    title: resolved.title,
    company: resolved.company,
    website: resolved.website,
    education: resolved.education,
    avatar: resolved.avatar,
  }
}

///|
extern "js" fn open_avatar_picker() -> Unit = "() => { const el = document.getElementById('sigil-avatar-input'); if (!el) return; el.value = ''; el.click(); }"

///|
extern "js" fn read_avatar_promise() -> @js_async.Promise[String] =
  #| () => new Promise((resolve) => {
  #|   const input = document.getElementById('sigil-avatar-input');
  #|   if (!input || !input.files || input.files.length === 0) {
  #|     resolve('');
  #|     return;
  #|   }
  #|   const file = input.files[0];
  #|   const reader = new FileReader();
  #|   reader.onload = () => {
  #|     input.value = '';
  #|     resolve(String(reader.result || ''));
  #|   };
  #|   reader.onerror = () => {
  #|     input.value = '';
  #|     resolve('');
  #|   };
  #|   reader.readAsDataURL(file);
  #| })

///|
async fn import_avatar_task() -> String noraise {
  @js_async.run_promise(_ => read_avatar_promise()) catch {
    _ => ""
  }
}
