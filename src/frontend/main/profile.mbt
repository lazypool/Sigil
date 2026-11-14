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
}

///|
let profile_field_count = 8

///|
extern "js" fn storage_get(key : String) -> String = "(key) => { try { return localStorage.getItem(key) ?? '' } catch (e) { return '' } }"

///|
extern "js" fn storage_set(key : String, value : String) -> Unit = "(key, value) => { try { localStorage.setItem(key, value) } catch (e) {} }"

///|
fn load_profile() -> Profile {
  {
    name: storage_get("sigil.profile.name"),
    nickname: storage_get("sigil.profile.alias"),
    email: storage_get("sigil.profile.email"),
    phone: storage_get("sigil.profile.phone"),
    title: storage_get("sigil.profile.title"),
    company: storage_get("sigil.profile.company"),
    website: storage_get("sigil.profile.website"),
    education: storage_get("sigil.profile.education"),
  }
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
