///|
/// Global writer profile reused by signature and footer themes.
#derive(Eq)
pub(all) struct Profile {
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
pub fn Profile::empty() -> Profile {
  {
    name: "",
    nickname: "",
    email: "",
    phone: "",
    title: "",
    company: "",
    website: "",
    education: "",
    avatar: "",
  }
}

///|
pub fn Profile::display_name(self : Profile) -> String {
  if self.name != "" {
    self.name
  } else if self.nickname != "" {
    self.nickname
  } else if self.email != "" {
    self.email
  } else {
    ""
  }
}

///|
pub fn Profile::is_empty(self : Profile) -> Bool {
  self.name == "" &&
  self.nickname == "" &&
  self.email == "" &&
  self.phone == "" &&
  self.title == "" &&
  self.company == "" &&
  self.website == "" &&
  self.education == "" &&
  self.avatar == ""
}
